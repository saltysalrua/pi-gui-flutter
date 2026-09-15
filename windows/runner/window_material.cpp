#include "window_material.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

namespace {
// Public DWM attributes, defined numerically to allow older build SDKs.
constexpr DWORD kBackdropAttribute = 38;  // DWMWA_SYSTEMBACKDROP_TYPE
constexpr int kNone = 1;                 // DWMSBT_NONE
constexpr int kAcrylic = 3;              // DWMSBT_TRANSIENTWINDOW
constexpr DWORD kDarkModeAttribute = 20;
constexpr DWORD kBorderColorAttribute = 34;   // DWMWA_BORDER_COLOR
constexpr DWORD kCaptionColorAttribute = 35; // DWMWA_CAPTION_COLOR
constexpr COLORREF kNoChromeColor = 0xFFFFFFFE;  // DWMWA_COLOR_NONE, not an RGB tint

void ConfigureCustomChrome(HWND window) {
  // Flutter owns the visible title bar. Do not let Windows' "accent on title
  // bars and borders" paint a solid strip over the native backdrop. Preserve
  // the frame geometry, resize hit areas, rounded corners and DWM shadow.
  // Older Windows may not support these cosmetic attributes; keep startup safe.
  DwmSetWindowAttribute(window, kCaptionColorAttribute, &kNoChromeColor,
                        sizeof(kNoChromeColor));
  DwmSetWindowAttribute(window, kBorderColorAttribute, &kNoChromeColor,
                        sizeof(kNoChromeColor));
}

bool SystemAllowsTransparency() {
  HIGHCONTRASTW contrast{};
  contrast.cbSize = sizeof(contrast);
  if (SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0) &&
      (contrast.dwFlags & HCF_HIGHCONTRASTON)) return false;
  DWORD transparency = 1;
  DWORD size = sizeof(transparency);
  RegGetValueW(HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
      L"EnableTransparency", RRF_RT_REG_DWORD, nullptr, &transparency, &size);
  if (transparency == 0) return false;
  SYSTEM_POWER_STATUS power{};
  if (GetSystemPowerStatus(&power) && power.SystemStatusFlag == 1) return false;
  BOOL composition = FALSE;
  return SUCCEEDED(DwmIsCompositionEnabled(&composition)) && composition;
}

void ClearLegacyTint(HWND window) {
  // window_manager's transparent background uses a legacy accent gradient.
  // Clear only that policy before applying the public DWM system backdrop.
  struct AccentPolicy { int state; int flags; DWORD color; int animation; };
  struct CompositionData { int attribute; void* data; SIZE_T size; };
  using SetComposition = BOOL(WINAPI*)(HWND, CompositionData*);
  const auto user32 = GetModuleHandleW(L"user32.dll");
  if (!user32) return;
  const auto set = reinterpret_cast<SetComposition>(
      GetProcAddress(user32, "SetWindowCompositionAttribute"));
  if (!set) return;
  AccentPolicy policy{};
  CompositionData data{19, &policy, sizeof(policy)};
  set(window, &data);
}
}  // namespace

WindowMaterial::WindowMaterial(HWND window, flutter::BinaryMessenger* messenger)
    : window_(window),
      channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "pi_gui/window_material",
          &flutter::StandardMethodCodec::GetInstance())) {
  ConfigureCustomChrome(window_);
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "setAcrylic") {
      result->NotImplemented();
      return;
    }
    const auto* args = call.arguments()
        ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
    if (!args) {
      result->Error("invalid_arguments", "Expected enabled and dark flags.");
      return;
    }
    const auto enabled = args->find(flutter::EncodableValue("enabled"));
    const auto dark = args->find(flutter::EncodableValue("dark"));
    if (enabled == args->end() || dark == args->end() ||
        !std::holds_alternative<bool>(enabled->second) ||
        !std::holds_alternative<bool>(dark->second)) {
      result->Error("invalid_arguments", "Expected enabled and dark flags.");
      return;
    }
    enabled_ = std::get<bool>(enabled->second);
    dark_ = std::get<bool>(dark->second);
    result->Success(flutter::EncodableValue(Apply()));
  });
}

WindowMaterial::~WindowMaterial() { channel_->SetMethodCallHandler(nullptr); }

void WindowMaterial::Disable() {
  if (!active_) return;
  DwmSetWindowAttribute(window_, kBackdropAttribute, &kNone, sizeof(kNone));
  const MARGINS margins{0, 0, 0, 0};
  DwmExtendFrameIntoClientArea(window_, &margins);
  active_ = false;
}

std::string WindowMaterial::Apply() {
  // This policy belongs to custom chrome, not to the selected palette or glass
  // toggle. Turning glass off must not bring the system accent strip back.
  ConfigureCustomChrome(window_);
  if (!enabled_) {
    Disable();
    return "disabled";
  }
  if (!SystemAllowsTransparency()) {
    Disable();
    return "systemDisabled";
  }
  if (!active_) ClearLegacyTint(window_);
  const BOOL dark = dark_;
  DwmSetWindowAttribute(window_, kDarkModeAttribute, &dark, sizeof(dark));
  // Unsupported on Windows < 11 22H2. Never fall back to an unblurred window.
  const auto result = DwmSetWindowAttribute(
      window_, kBackdropAttribute, &kAcrylic, sizeof(kAcrylic));
  if (FAILED(result)) {
    Disable();
    return "unsupported";
  }
  active_ = true;
  const MARGINS margins{-1, -1, -1, -1};
  if (FAILED(DwmExtendFrameIntoClientArea(window_, &margins))) {
    Disable();
    return "unavailable";
  }
  return "active";
}

void WindowMaterial::HandleMessage(UINT message) {
  switch (message) {
    case WM_SETTINGCHANGE:
    case WM_THEMECHANGED:
    case WM_DWMCOLORIZATIONCOLORCHANGED:
    case WM_ACTIVATE:
    case WM_DWMCOMPOSITIONCHANGED:
    case WM_POWERBROADCAST:
      if (enabled_) {
        channel_->InvokeMethod("statusChanged",
            std::make_unique<flutter::EncodableValue>(Apply()));
      } else {
        ConfigureCustomChrome(window_);
      }
      break;
  }
}
