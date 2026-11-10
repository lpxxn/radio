import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

/// 先结束后台播放，再交给平台正常关闭窗口/Activity，避免直接杀进程。
/// 独立 Provider 让界面测试可以验证退出命令而不关闭测试进程。
final exitAppProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final handler = ref.read(radioProvider);
    handler.sleep(null);
    await handler.stop();
    await handler.flushSession();
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        await ServicesBinding.instance.exitApplication(ui.AppExitType.required);
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        await SystemNavigator.pop();
    }
  },
);
