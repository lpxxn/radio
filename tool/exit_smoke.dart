// 手动验证 Windows 原生退出 API：flutter run -d windows -t tool/exit_smoke.dart
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shiguang_radio/main.dart' as app;

Future<void> main() async {
  await app.main();
  await Future<void>.delayed(const Duration(seconds: 2));
  debugPrint('NATIVE_EXIT_REQUEST');
  final response = await ServicesBinding.instance.exitApplication(
    ui.AppExitType.required,
  );
  debugPrint('NATIVE_EXIT_RESPONSE: $response');
}
