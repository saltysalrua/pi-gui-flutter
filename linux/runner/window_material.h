#ifndef PI_GUI_WINDOW_MATERIAL_H_
#define PI_GUI_WINDOW_MATERIAL_H_

#include <flutter_linux/flutter_linux.h>
#include <wayland-client.h>

#include "ext-background-effect-v1-client-protocol.h"

// Owns the window's native material channel and Wayland protocol objects.
class WindowMaterial {
public:
  WindowMaterial(GtkWindow *window, FlView *view);
  ~WindowMaterial();
  WindowMaterial(const WindowMaterial &) = delete;
  WindowMaterial &operator=(const WindowMaterial &) = delete;

private:
  enum class MaterialStatus {
    active,
    disabled,
    unsupported,
    system_disabled,
    unavailable
  };
  struct Result {
    MaterialStatus status;
    const char *code;
    const char *message;
  };

  static const char *StatusName(MaterialStatus status);
  static void LogFailure(const char *code, const char *message);
  void HandleCall(FlMethodCall *call);
  void RespondToApply(FlMethodCall *call);
  void Respond(FlMethodCall *call, Result result);
  void CompleteInitialization();
  Result Apply();
  void Refresh();
  void ReleaseSurface();
  void Publish(Result result);

  GtkWindow *window_;
  FlView *view_;
  FlMethodChannel *channel_;
  FlMethodCall *pending_call_ = nullptr;
  wl_registry *registry_ = nullptr;
  wl_callback *sync_ = nullptr;
  wl_compositor *compositor_ = nullptr;
  ext_background_effect_manager_v1 *manager_ = nullptr;
  ext_background_effect_surface_v1 *effect_ = nullptr;
  wl_surface *surface_ = nullptr;
  uint32_t manager_name_ = 0;
  uint32_t capabilities_ = 0;
  guint initialization_timeout_ = 0;
  bool registry_done_ = false;
  bool capabilities_seen_ = false;
  bool ready_ = false;
  bool enabled_ = false;
  MaterialStatus status_ = MaterialStatus::disabled;
  const char *initialization_error_ = nullptr;
};

#endif // PI_GUI_WINDOW_MATERIAL_H_
