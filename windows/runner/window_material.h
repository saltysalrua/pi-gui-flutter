#ifndef RUNNER_WINDOW_MATERIAL_H_
#define RUNNER_WINDOW_MATERIAL_H_

#include <windows.h>
#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <memory>
#include <string>

// GUI-owned DWM bridge. Uses one backdrop; Flutter paints independent tints.
class WindowMaterial {
 public:
  WindowMaterial(HWND window, flutter::BinaryMessenger* messenger);
  ~WindowMaterial();
  void HandleMessage(UINT message);

 private:
  std::string Apply();
  void Disable();
  HWND window_;
  bool enabled_ = false;
  bool dark_ = false;
  bool active_ = false;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_WINDOW_MATERIAL_H_
