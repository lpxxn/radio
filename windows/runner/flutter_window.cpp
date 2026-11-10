#include "flutter_window.h"

#include <optional>
#include <commctrl.h>
#include <windowsx.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {
// Flutter 的子 HWND 覆盖客户区；让边缘命中穿透到父窗口，由系统负责缩放。
int ResizeHit(HWND window, LPARAM position) {
  if (IsZoomed(window)) return HTCLIENT;
  RECT bounds;
  GetWindowRect(window, &bounds);
  const int grip = MulDiv(10, GetDpiForWindow(window), 96);
  const int x = GET_X_LPARAM(position), y = GET_Y_LPARAM(position);
  // 裁剪后的可见面板可能位于窗口内部，以可见区域边界作为缩放边缘。
  HRGN region = CreateRectRgn(0, 0, 0, 0);
  RECT visible;
  if (GetWindowRgn(window, region) != ERROR && GetRgnBox(region, &visible) != NULLREGION) {
    bounds = {bounds.left + visible.left, bounds.top + visible.top,
              bounds.left + visible.right, bounds.top + visible.bottom};
  }
  DeleteObject(region);
  const bool left = x < bounds.left + grip, right = x >= bounds.right - grip;
  const bool top = y < bounds.top + grip, bottom = y >= bounds.bottom - grip;
  if (top && left) return HTTOPLEFT;
  if (top && right) return HTTOPRIGHT;
  if (bottom && left) return HTBOTTOMLEFT;
  if (bottom && right) return HTBOTTOMRIGHT;
  if (left) return HTLEFT;
  if (right) return HTRIGHT;
  if (top) return HTTOP;
  if (bottom) return HTBOTTOM;
  return HTCLIENT;
}
LRESULT CALLBACK FlutterResizeProc(HWND child, UINT message, WPARAM wparam,
                                  LPARAM lparam, UINT_PTR, DWORD_PTR parent) {
  if (message == WM_NCHITTEST && ResizeHit(reinterpret_cast<HWND>(parent), lparam) != HTCLIENT) {
    return HTTRANSPARENT;
  }
  return DefSubclassProc(child, message, wparam, lparam);
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
  // System.exitApplication 可能直接结束消息循环，尚未收到父窗口 WM_DESTROY。
  // 必须在成员析构前走 OnDestroy：先清空 controller_ 再释放 Flutter 视图。
  // 否则视图销毁发送的 WM_PARENTNOTIFY 会重入 MessageHandler，访问半析构视图。
  Destroy();
}

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
  SetWindowSubclass(flutter_controller_->view()->GetNativeWindow(),
                    FlutterResizeProc, 1, reinterpret_cast<DWORD_PTR>(GetHandle()));

  // 仅暴露窗口交互，不引入额外桌面依赖。拖动/缩放沿用 Windows 原生循环。
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "cn.shiguang.radio/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "minimize") {
      ShowWindow(GetHandle(), SW_MINIMIZE);
      result->Success();
      return;
    }
    if (call.method_name() == "toggleMaximize") {
      ShowWindow(GetHandle(), IsZoomed(GetHandle()) ? SW_RESTORE : SW_MAXIMIZE);
      result->Success();
      return;
    }
    if (call.method_name() == "shape") {
      const auto* values = call.arguments() ? std::get_if<flutter::EncodableList>(call.arguments()) : nullptr;
      if (!values || values->size() != 5) {
        result->Error("invalid_shape", "Expected left, top, right, bottom, radius");
        return;
      }
      int coordinates[5];
      const double scale = GetDpiForWindow(GetHandle()) / 96.0;
      for (int i = 0; i < 5; ++i) {
        const auto* value = std::get_if<double>(&(*values)[i]);
        if (!value) { result->Error("invalid_shape", "Expected doubles"); return; }
        coordinates[i] = static_cast<int>(*value * scale + 0.5);
      }
      HRGN shape = CreateRoundRectRgn(coordinates[0], coordinates[1], coordinates[2] + 1,
                                     coordinates[3] + 1, coordinates[4] * 2, coordinates[4] * 2);
      // 成功后区域归 Windows 所有，面板外的黑色留白和圆角均不再属于窗口。
      if (!SetWindowRgn(GetHandle(), shape, TRUE)) DeleteObject(shape);
      result->Success();
      return;
    }
    if (call.method_name() == "frameInfo") {
      RECT outer, client;
      GetWindowRect(GetHandle(), &outer);
      GetClientRect(GetHandle(), &client);
      const LONG_PTR style = GetWindowLongPtr(GetHandle(), GWL_STYLE);
      HRGN region = CreateRectRgn(0, 0, 0, 0);
      const bool clipped = GetWindowRgn(GetHandle(), region) != ERROR;
      RECT visible{0, 0, client.right, client.bottom};
      if (clipped) GetRgnBox(region, &visible);
      const bool corner_hidden = clipped && !PtInRegion(region, visible.left, visible.top);
      const bool edge_hit = ResizeHit(GetHandle(), MAKELPARAM(
          outer.left + visible.left + 1, outer.top + (visible.top + visible.bottom) / 2)) == HTLEFT;
      const bool child_passes_edge = SendMessage(flutter_controller_->view()->GetNativeWindow(), WM_NCHITTEST, 0,
          MAKELPARAM(outer.left + visible.left + 1, outer.top + (visible.top + visible.bottom) / 2)) == HTTRANSPARENT;
      DeleteObject(region);
      result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("cornerHidden"), flutter::EncodableValue(corner_hidden)},
        {flutter::EncodableValue("nativeResizeEdge"), flutter::EncodableValue(edge_hit && child_passes_edge)},
        {flutter::EncodableValue("hasCaption"), flutter::EncodableValue((style & WS_CAPTION) != 0)},
        {flutter::EncodableValue("clientFillsWindow"), flutter::EncodableValue(
          outer.right - outer.left == client.right && outer.bottom - outer.top == client.bottom)},
      }));
      return;
    }
    int hit = HTCAPTION;
    if (call.method_name() == "resize") {
      const auto* edge = call.arguments() ? std::get_if<int32_t>(call.arguments()) : nullptr;
      constexpr int edges[] = {HTLEFT, HTRIGHT, HTTOP, HTBOTTOM,
                              HTTOPLEFT, HTTOPRIGHT, HTBOTTOMLEFT, HTBOTTOMRIGHT};
      if (!edge || *edge < 0 || *edge >= 8) {
        result->Error("invalid_edge", "Expected resize edge 0..7");
        return;
      }
      hit = edges[*edge];
    } else if (call.method_name() != "move") {
      result->NotImplemented();
      return;
    }
    POINT cursor;
    GetCursorPos(&cursor);
    ReleaseCapture();
    SendMessage(GetHandle(), WM_NCLBUTTONDOWN, hit, MAKELPARAM(cursor.x, cursor.y));
    result->Success();
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
  window_channel_.reset();
  if (flutter_controller_) {
    RemoveWindowSubclass(flutter_controller_->view()->GetNativeWindow(), FlutterResizeProc, 1);
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_NCHITTEST) {
    const int hit = ResizeHit(hwnd, lparam);
    if (hit != HTCLIENT) return hit;
  }
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
