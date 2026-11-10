// 可选视觉检查工具：flutter test tool/render_previews_test.dart
// 在 Windows 载入系统中文字体，输出真实 Widget 渲染图（不是设计稿）。
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiguang_radio/main.dart';
import 'package:shiguang_radio/audio/radio_handler.dart';
import 'package:shiguang_radio/providers.dart';
import 'package:shiguang_radio/ui/radio_skin.dart';
import 'package:shiguang_radio/platform/desktop_window.dart';
import 'package:shiguang_radio/models/station.dart';
import '../test/radio_handler_test.dart' show FakeEngine;

List<Station> _previewStations = [];
class PreviewCatalog extends CatalogNotifier {
  @override
  Future<List<Station>> build() async {
    ref.read(radioProvider).setStations(_previewStations);
    return _previewStations;
  }
}

void main() {
  for (final (name, size, skin) in [
    ('desktop-walnut', const Size(1440, 900), RadioSkin.walnut),
    ('desktop-midnight', const Size(1440, 900), RadioSkin.midnight),
    ('desktop-forest', const Size(1440, 900), RadioSkin.forest),
    ('desktop-compact', const Size(800, 600), RadioSkin.walnut),
    ('mobile', const Size(360, 792), RadioSkin.walnut),
  ]) {
    testWidgets(
      '渲染 $name',
      (tester) async {
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
        await tester.runAsync(() async {
        final json = jsonDecode(await File('assets/stations.json').readAsString()) as List;
        _previewStations = json.map((s) => Station.fromJson(s as Map<String, dynamic>)).toList();
          final file = File('assets/fonts/NotoSansSC-Regular.otf');
          if (file.existsSync()) {
            final loader = FontLoader(
              'RadioSans',
            )..addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
            await loader.load();
          }
          final icons = File(
            'C:/Users/mi_du/dev/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          );
          if (icons.existsSync()) {
            final loader = FontLoader('MaterialIcons')
              ..addFont(
                icons.readAsBytes().then((b) => ByteData.sublistView(b)),
              );
            await loader.load();
          }
        });
        // 此文件使用 flutter test 执行，作为可选的视觉渲染工具。
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues({
          'skin': skin.name,
          'favorites': ['cnr-3', 'cnr-1'],
        });
        final prefs = await SharedPreferences.getInstance();
        final handler = RadioHandler(FakeEngine());
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesProvider.overrideWithValue(prefs),
              radioProvider.overrideWithValue(handler),
              connectivityProvider.overrideWith((ref) {}),
              catalogProvider.overrideWith(PreviewCatalog.new),
            ],
            child: RepaintBoundary(key: boundaryKey, child: const RadioApp()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final current = handler.queue.value.firstWhere(
            (s) => s.id == 'cnr-3',
          );
          await handler.playFromMediaId(current.id);
          await handler.pause();
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final rendered = await boundary.toImage();
          final bytes = (await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await Directory('docs/previews').create(recursive: true);
          await File(
            'docs/previews/$name.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          rendered.dispose();
        });
        if (name == 'desktop-walnut') {
          await tester.tap(find.text('选台'));
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final rendered = await boundary.toImage();
            final bytes = (await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              'docs/previews/station-picker.png',
            ).writeAsBytes(bytes.buffer.asUint8List());
            rendered.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(handler.dispose);
      },
      variant: TargetPlatformVariant({
        name == 'mobile' ? TargetPlatform.android : TargetPlatform.windows,
      }),
    );
  }
}
