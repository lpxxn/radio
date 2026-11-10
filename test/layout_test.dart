import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiguang_radio/audio/radio_handler.dart';
import 'package:shiguang_radio/main.dart';
import 'package:shiguang_radio/providers.dart';
import 'package:shiguang_radio/models/station.dart';
import 'package:shiguang_radio/platform/desktop_window.dart';
import 'radio_handler_test.dart' show FakeEngine, stations;

class TestCatalog extends CatalogNotifier {
  @override
  Future<List<Station>> build() async {
    ref.read(radioProvider).setStations(stations);
    return stations;
  }
}

void main() {
  for (final (platform, size) in [
    (TargetPlatform.android, const Size(320, 640)),
    (TargetPlatform.android, const Size(390, 844)),
    (TargetPlatform.iOS, const Size(390, 844)),
    (TargetPlatform.windows, const Size(800, 600)),
    (TargetPlatform.windows, const Size(320, 360)),
    (TargetPlatform.windows, const Size(940, 480)),
    (TargetPlatform.windows, const Size(1440, 900)),
  ]) {
    testWidgets('$platform 响应式布局不溢出 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        DesktopWindow.channel,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          DesktopWindow.channel,
          null,
        ),
      );
      if (platform != TargetPlatform.windows) {
        tester.view.viewPadding = const FakeViewPadding(top: 54, bottom: 24);
        addTearDown(tester.view.resetViewPadding);
      }
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final handler = RadioHandler(FakeEngine());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            radioProvider.overrideWithValue(handler),
            connectivityProvider.overrideWith((ref) {}),
            catalogProvider.overrideWith(TestCatalog.new),
          ],
          child: const RadioApp(),
        ),
      );
      await tester.pumpAndSettle();
      final surface = tester.getRect(
        find.byKey(const ValueKey('radio-surface')),
      );
      final mobile = platform != TargetPlatform.windows;
      if (mobile) {
        expect(surface.top, 0);
        expect(surface.width, size.width);
        expect(surface.height, size.height);
        expect(find.byType(Slider), findsNothing);
        expect(
          tester.getTopLeft(find.text('时光收音机')).dy,
          greaterThanOrEqualTo(72),
        );
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('时光收音机')).dy,
          greaterThanOrEqualTo(72),
        );
      }
      expect(find.byTooltip('收音机菜单'), findsOneWidget);
      expect(find.text('慢一点，听见生活。'), findsNothing);
      expect(find.text('SHIGUANG  /  INTERNET RADIO'), findsNothing);
      expect(find.byTooltip('退出'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final inlineLibrary = !mobile && size.width >= 900 && size.height >= 560;
      expect(
        find.text('寻找你的频率'),
        inlineLibrary ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.byTooltip('收音机菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('晴空蓝'));
      await tester.pumpAndSettle();
      expect(prefs.getString('skin'), 'midnight');
      await tester.tap(find.byTooltip('收音机菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关于与使用说明'));
      await tester.pumpAndSettle();
      expect(find.text('给声音一点时间'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      if (mobile) {
        await tester.ensureVisible(find.byTooltip('选台'));
        await tester.tap(find.byTooltip('选台'));
      } else {
        await tester.tap(find.text('选台'));
      }
      await tester.pumpAndSettle();
      expect(
        find.text('寻找你的频率'),
        inlineLibrary ? findsNWidgets(2) : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭选台窗口'));
      await tester.pumpAndSettle();
      expect(
        find.text('寻找你的频率'),
        inlineLibrary ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(handler.dispose);
    }, variant: TargetPlatformVariant({platform}));
  }
}
