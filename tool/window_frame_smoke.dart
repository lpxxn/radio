// 验证真实 HWND 无标题栏，且窗口外部尺寸等于 Flutter 客户区尺寸。
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shiguang_radio/main.dart' as app;
import 'package:shiguang_radio/platform/desktop_window.dart';

Future<void> main() async {
  await app.main();
  await Future<void>.delayed(const Duration(seconds: 2));
  final info = await DesktopWindow.channel.invokeMapMethod<String, Object?>(
    'frameInfo',
  );
  if (info?['hasCaption'] != false ||
      info?['clientFillsWindow'] != true ||
      info?['cornerHidden'] != true ||
      info?['nativeResizeEdge'] != true) {
    throw StateError('仍有原生窗口装饰：$info');
  }
  debugPrint('FRAME_SMOKE_OK: $info');
  await ServicesBinding.instance.exitApplication(ui.AppExitType.required);
}
