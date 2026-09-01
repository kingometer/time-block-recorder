#include "flutter_window.h"

#include <optional>
#include <string>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

// 获取当前前台窗口标题（UTF-8）。
std::string GetForegroundWindowTitle() {
  HWND hwnd = ::GetForegroundWindow();
  if (hwnd == nullptr) return "";
  int length = ::GetWindowTextLengthW(hwnd);
  if (length <= 0) return "";
  std::wstring title(static_cast<size_t>(length), L'\0');
  ::GetWindowTextW(hwnd, title.data(), length + 1);
  title.resize(static_cast<size_t>(length));
  if (title.empty()) return "";
  int size = ::WideCharToMultiByte(CP_UTF8, 0, title.c_str(),
                                   static_cast<int>(title.size()), nullptr, 0,
                                   nullptr, nullptr);
  std::string utf8(static_cast<size_t>(size), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, title.c_str(),
                        static_cast<int>(title.size()), utf8.data(), size,
                        nullptr, nullptr);
  return utf8;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  window_monitor_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "time_block_recorder/app_monitor",
          &flutter::StandardMethodCodec::GetInstance());
  window_monitor_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getForegroundApp") {
          result->Success(flutter::EncodableValue(GetForegroundWindowTitle()));
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
