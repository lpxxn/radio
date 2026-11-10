import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 页面颜色由 Riverpod 驱动；Android 的进程启动画面由系统先于 Dart 绘制。
/// 选色时通知原生层，持久化下次启动使用的主题，避免启动时闪回默认色。
abstract final class StartupAppearance {
  static const channel = MethodChannel('cn.shiguang.radio/appearance');
  static Future<void> apply(String skin) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await channel.invokeMethod<void>('setSkin', skin);
    } on MissingPluginException {
      // Widget 测试没有 Android Activity；正式工程由 MainActivity 注册桥接。
    }
  }
}
