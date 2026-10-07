#include "window_material.h"

#include <cstring>
#include <gdk/gdkwayland.h>

const char *WindowMaterial::StatusName(MaterialStatus status) {
  switch (status) {
  case MaterialStatus::active:
    return "active";
  case MaterialStatus::disabled:
    return "disabled";
  case MaterialStatus::unsupported:
    return "unsupported";
  case MaterialStatus::system_disabled:
    return "systemDisabled";
  case MaterialStatus::unavailable:
    return "unavailable";
  }
  g_assert_not_reached();
}

void WindowMaterial::LogFailure(const char *code, const char *message) {
  g_log_structured("pi_gui", G_LOG_LEVEL_WARNING, "MESSAGE",
                   "Native window material operation failed", "ERROR_CODE",
                   code, "REASON", message);
}

WindowMaterial::WindowMaterial(GtkWindow *window, FlView *view)
    : window_(window), view_(view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  channel_ = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "pi_gui/window_material", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel_,
      [](FlMethodChannel *, FlMethodCall *call, gpointer data) {
        static_cast<WindowMaterial *>(data)->HandleCall(call);
      },
      this, nullptr);

  g_signal_connect(window_, "realize",
                   G_CALLBACK(+[](GtkWidget *, gpointer data) {
                     static_cast<WindowMaterial *>(data)->Refresh();
                   }),
                   this);
  g_signal_connect(window_, "size-allocate",
                   G_CALLBACK(+[](GtkWidget *, GtkAllocation *, gpointer data) {
                     static_cast<WindowMaterial *>(data)->Refresh();
                   }),
                   this);
  g_signal_connect(
      window_, "unrealize", G_CALLBACK(+[](GtkWidget *, gpointer data) {
        auto *self = static_cast<WindowMaterial *>(data);
        self->ReleaseSurface();
        if (self->enabled_)
          self->Publish({MaterialStatus::unavailable, nullptr, nullptr});
      }),
      this);

  GdkDisplay *display = gtk_widget_get_display(GTK_WIDGET(window_));
  if (!GDK_IS_WAYLAND_DISPLAY(display)) {
    ready_ = true;
    return;
  }
  // GTK dispatches this connection's default event queue in its GLib source.
  // Never create a second connection for objects belonging to GTK's surface.
  wl_display *connection = gdk_wayland_display_get_wl_display(display);
  registry_ = wl_display_get_registry(connection);
  static const wl_registry_listener registry_listener = {
      [](void *data, wl_registry *registry, uint32_t name,
         const char *interface, uint32_t) {
        auto *self = static_cast<WindowMaterial *>(data);
        if (std::strcmp(interface, wl_compositor_interface.name) == 0 &&
            !self->compositor_) {
          self->compositor_ = static_cast<wl_compositor *>(
              wl_registry_bind(registry, name, &wl_compositor_interface, 1));
        } else if (std::strcmp(
                       interface,
                       ext_background_effect_manager_v1_interface.name) == 0 &&
                   !self->manager_) {
          self->manager_name_ = name;
          self->capabilities_seen_ = false;
          self->capabilities_ = 0;
          self->manager_ = static_cast<ext_background_effect_manager_v1 *>(
              wl_registry_bind(registry, name,
                               &ext_background_effect_manager_v1_interface, 1));
          static const ext_background_effect_manager_v1_listener listener = {
              [](void *data, ext_background_effect_manager_v1 *,
                 uint32_t flags) {
                auto *self = static_cast<WindowMaterial *>(data);
                self->capabilities_ = flags;
                self->capabilities_seen_ = true;
                self->CompleteInitialization();
                self->Refresh();
              }};
          ext_background_effect_manager_v1_add_listener(self->manager_,
                                                        &listener, self);
        }
      },
      [](void *data, wl_registry *, uint32_t name) {
        auto *self = static_cast<WindowMaterial *>(data);
        if (name != self->manager_name_)
          return;
        self->ReleaseSurface();
        ext_background_effect_manager_v1_destroy(self->manager_);
        self->manager_ = nullptr;
        self->manager_name_ = 0;
        self->capabilities_ = 0;
        self->capabilities_seen_ = false;
        self->CompleteInitialization();
        self->Refresh();
      }};
  wl_registry_add_listener(registry_, &registry_listener, this);

  sync_ = wl_display_sync(connection);
  static const wl_callback_listener sync_listener = {
      [](void *data, wl_callback *callback, uint32_t) {
        auto *self = static_cast<WindowMaterial *>(data);
        wl_callback_destroy(callback);
        self->sync_ = nullptr;
        self->registry_done_ = true;
        self->CompleteInitialization();
      }};
  wl_callback_add_listener(sync_, &sync_listener, this);
  initialization_timeout_ = g_timeout_add_seconds(
      3,
      [](gpointer data) -> gboolean {
        auto *self = static_cast<WindowMaterial *>(data);
        self->initialization_timeout_ = 0;
        self->initialization_error_ =
            "Wayland did not report background-effect capabilities within 3 "
            "seconds.";
        self->ready_ = true;
        if (self->pending_call_) {
          self->RespondToApply(self->pending_call_);
          g_clear_object(&self->pending_call_);
        } else {
          self->Refresh();
        }
        return G_SOURCE_REMOVE;
      },
      this);
}

WindowMaterial::~WindowMaterial() {
  g_signal_handlers_disconnect_by_data(window_, this);
  fl_method_channel_set_method_call_handler(channel_, nullptr, nullptr,
                                            nullptr);
  if (initialization_timeout_)
    g_source_remove(initialization_timeout_);
  if (pending_call_) {
    Respond(pending_call_,
            {MaterialStatus::unavailable, "window_closed",
             "The window closed before native material initialization."});
    g_clear_object(&pending_call_);
  }
  ReleaseSurface();
  if (sync_)
    wl_callback_destroy(sync_);
  if (manager_)
    ext_background_effect_manager_v1_destroy(manager_);
  if (compositor_)
    wl_compositor_destroy(compositor_);
  if (registry_)
    wl_registry_destroy(registry_);
  g_clear_object(&channel_);
}

void WindowMaterial::HandleCall(FlMethodCall *call) {
  if (std::strcmp(fl_method_call_get_name(call), "setBlur") != 0) {
    g_autoptr(GError) error = nullptr;
    if (!fl_method_call_respond_not_implemented(call, &error)) {
      LogFailure("response_failed", error->message);
    }
    return;
  }
  FlValue *args = fl_method_call_get_args(call);
  FlValue *enabled = args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
                         ? fl_value_lookup_string(args, "enabled")
                         : nullptr;
  FlValue *dark = args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
                      ? fl_value_lookup_string(args, "dark")
                      : nullptr;
  if (!enabled || !dark || fl_value_get_type(enabled) != FL_VALUE_TYPE_BOOL ||
      fl_value_get_type(dark) != FL_VALUE_TYPE_BOOL) {
    Respond(call, {MaterialStatus::unavailable, "invalid_arguments",
                   "setBlur requires boolean enabled and dark fields."});
    return;
  }
  if (pending_call_) {
    Respond(call, {MaterialStatus::unavailable, "request_pending",
                   "Wait for the previous setBlur request to complete."});
    return;
  }
  enabled_ = fl_value_get_bool(enabled);
  if (enabled_ && !ready_) {
    pending_call_ = FL_METHOD_CALL(g_object_ref(call));
    return;
  }
  RespondToApply(call);
}

void WindowMaterial::RespondToApply(FlMethodCall *call) {
  const Result result = Apply();
  status_ = result.status;
  Respond(call, result);
}

void WindowMaterial::Respond(FlMethodCall *call, Result result) {
  g_autoptr(GError) error = nullptr;
  gboolean sent;
  if (result.code) {
    LogFailure(result.code, result.message);
    g_autoptr(FlValue) details = fl_value_new_map();
    fl_value_set_string_take(details, "backend",
                             fl_value_new_string("wayland"));
    FlValue *args = fl_method_call_get_args(call);
    const char *keys[] = {"enabled", "dark"};
    for (const char *key : keys) {
      FlValue *value = args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
                           ? fl_value_lookup_string(args, key)
                           : nullptr;
      if (value)
        fl_value_set_string(details, key, value);
    }
    sent = fl_method_call_respond_error(call, result.code, result.message,
                                        details, &error);
  } else {
    g_autoptr(FlValue) value = fl_value_new_string(StatusName(result.status));
    sent = fl_method_call_respond_success(call, value, &error);
  }
  if (!sent)
    LogFailure("response_failed", error->message);
}

void WindowMaterial::CompleteInitialization() {
  if (!registry_done_ || (manager_ && !capabilities_seen_))
    return;
  ready_ = true;
  initialization_error_ = nullptr;
  if (initialization_timeout_) {
    g_source_remove(initialization_timeout_);
    initialization_timeout_ = 0;
  }
  if (pending_call_) {
    RespondToApply(pending_call_);
    g_clear_object(&pending_call_);
  }
}

WindowMaterial::Result WindowMaterial::Apply() {
  if (!enabled_) {
    if (effect_)
      ext_background_effect_surface_v1_set_blur_region(effect_, nullptr);
    gtk_widget_queue_draw(GTK_WIDGET(view_));
    return {MaterialStatus::disabled, nullptr, nullptr};
  }
  if (initialization_error_) {
    return {MaterialStatus::unavailable, "capability_timeout",
            initialization_error_};
  }
  if (!ready_)
    return {MaterialStatus::unavailable, nullptr, nullptr};
  if (!manager_)
    return {MaterialStatus::unsupported, nullptr, nullptr};
  if (!(capabilities_ & EXT_BACKGROUND_EFFECT_MANAGER_V1_CAPABILITY_BLUR)) {
    if (effect_)
      ext_background_effect_surface_v1_set_blur_region(effect_, nullptr);
    gtk_widget_queue_draw(GTK_WIDGET(view_));
    return {MaterialStatus::system_disabled, nullptr, nullptr};
  }
  GdkWindow *window = gtk_widget_get_window(GTK_WIDGET(window_));
  if (!window || !GDK_IS_WAYLAND_WINDOW(window)) {
    return {MaterialStatus::unavailable, "surface_unavailable",
            "The GTK window has no realized Wayland surface."};
  }
  wl_surface *surface = gdk_wayland_window_get_wl_surface(window);
  if (!surface || !compositor_) {
    return {MaterialStatus::unavailable, "surface_unavailable",
            "GTK did not provide a Wayland surface or wl_compositor."};
  }
  if (surface != surface_) {
    ReleaseSurface();
    surface_ = surface;
    effect_ = ext_background_effect_manager_v1_get_background_effect(manager_,
                                                                     surface);
  }
  GtkAllocation allocation;
  gtk_widget_get_allocation(GTK_WIDGET(window_), &allocation);
  wl_region *region = wl_compositor_create_region(compositor_);
  wl_region_add(region, 0, 0, allocation.width, allocation.height);
  ext_background_effect_surface_v1_set_blur_region(effect_, region);
  wl_region_destroy(region);
  // GTK owns wl_surface.commit; the queued draw commits the double-buffered
  // effect and buffer together, without an extra out-of-order surface commit.
  gdk_window_set_opaque_region(window, nullptr);
  gtk_widget_queue_draw(GTK_WIDGET(view_));
  return {MaterialStatus::active, nullptr, nullptr};
}

void WindowMaterial::ReleaseSurface() {
  if (effect_)
    ext_background_effect_surface_v1_destroy(effect_);
  effect_ = nullptr;
  surface_ = nullptr;
}

void WindowMaterial::Refresh() {
  if (!enabled_ || !ready_)
    return;
  Publish(Apply());
}

void WindowMaterial::Publish(Result result) {
  if (result.code)
    LogFailure(result.code, result.message);
  if (status_ == result.status)
    return;
  status_ = result.status;
  g_autoptr(FlValue) value = fl_value_new_string(StatusName(result.status));
  fl_method_channel_invoke_method(
      channel_, "statusChanged", value, nullptr,
      [](GObject *object, GAsyncResult *result, gpointer) {
        g_autoptr(GError) error = nullptr;
        g_autoptr(FlMethodResponse) response =
            fl_method_channel_invoke_method_finish(FL_METHOD_CHANNEL(object),
                                                   result, &error);
        if (response)
          fl_method_response_get_result(response, &error);
        if (error)
          LogFailure("status_delivery_failed", error->message);
      },
      nullptr);
}
