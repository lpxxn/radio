import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Windows 原生无边框窗口桥接；手机端不发送窗口命令。
abstract final class DesktopWindow {
  static const channel = MethodChannel('cn.shiguang.radio/window');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static void move() {
    if (supported) unawaited(channel.invokeMethod<void>('move'));
  }

  static void minimize() {
    if (supported) unawaited(channel.invokeMethod<void>('minimize'));
  }

  static void toggleMaximize() {
    if (supported) unawaited(channel.invokeMethod<void>('toggleMaximize'));
  }

  static (Rect, double)? _shape;

  /// 以实际绘制后的面板边界裁剪原生 HWND，不需要整窗透明渲染。
  static void shape(Rect bounds, double radius) {
    if (!supported || _shape == (bounds, radius)) return;
    _shape = (bounds, radius);
    unawaited(
      channel.invokeMethod<void>('shape', <double>[
        bounds.left,
        bounds.top,
        bounds.right,
        bounds.bottom,
        radius,
      ]),
    );
  }
}

/// 只包裹顶部空白区，避免拖动手势抢走菜单/选台/退出按钮的点击。
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => DesktopWindow.supported
      ? GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanDown: (_) => DesktopWindow.move(),
          child: child,
        )
      : child;
}
