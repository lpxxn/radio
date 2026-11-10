import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_radio/audio/radio_handler.dart';
import 'package:shiguang_radio/platform/app_exit.dart';
import 'package:shiguang_radio/providers.dart';
import 'radio_handler_test.dart' show FakeEngine, stations;

// 测试框架默认拒绝退出请求；在绑定层捕获，真实退出另有 Windows 探针验证。
class ExitTestBinding extends AutomatedTestWidgetsFlutterBinding {
  VoidCallback? onDesktopExit;
  @override
  Future<ui.AppExitResponse> exitApplication(
    ui.AppExitType exitType, [
    int exitCode = 0,
  ]) async {
    onDesktopExit?.call();
    return ui.AppExitResponse.exit;
  }
}

void main() {
  final binding = ExitTestBinding();
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('$platform 退出前停止播放并取消定时', (tester) async {
      final handler = RadioHandler(FakeEngine());
      final container = ProviderContainer(
        overrides: [radioProvider.overrideWithValue(handler)],
      );
      var requested = false;
      void checkStopped() {
        requested = true;
        expect(handler.snapshot.wantPlay, false);
        expect(handler.snapshot.sleepAt, null);
      }

      try {
        debugDefaultTargetPlatformOverride = platform;
        binding.onDesktopExit = checkStopped;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'SystemNavigator.pop') checkStopped();
            return null;
          },
        );
        await handler.select(stations.first);
        handler.sleep(const Duration(minutes: 30));
        await tester.runAsync(() => container.read(exitAppProvider)());
        expect(requested, true);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        binding.onDesktopExit = null;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
        container.dispose();
        await tester.runAsync(handler.dispose);
      }
    });
  }
}
