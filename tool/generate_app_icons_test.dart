// 资源生成工具，不是业务测试：flutter test tool/generate_app_icons_test.dart
// 用同一组矢量几何生成 Android / Apple / Windows 资源，不依赖图片处理软件。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _cream = Color(0xFFFFF3DF);
const _coral = Color(0xFFD96246);

class _Shape {
  const _Shape(this.path, this.svg, this.color, [this.stroke = 0]);
  final Path path;
  final String svg;
  final Color color;
  final double stroke;
}

_Shape _circle(
  double x,
  double y,
  double r,
  Color color, [
  double stroke = 0,
]) => _Shape(
  Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r)),
  'M ${x - r},$y a $r,$r 0 1,0 ${r * 2},0 a $r,$r 0 1,0 ${-r * 2},0',
  color,
  stroke,
);

_Shape _line(
  double x1,
  double y1,
  double x2,
  double y2,
  Color color,
  double stroke,
) => _Shape(
  Path()
    ..moveTo(x1, y1)
    ..lineTo(x2, y2),
  'M $x1,$y1 L $x2,$y2',
  color,
  stroke,
);

final _body = _Shape(
  Path()..addRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(236, 380, 552, 354),
      const Radius.circular(86),
    ),
  ),
  'M322,380 H702 Q788,380 788,466 V648 Q788,734 702,734 H322 Q236,734 236,648 V466 Q236,380 322,380 Z',
  _cream,
);

List<_Shape> _shapes({bool monochrome = false}) {
  if (monochrome) {
    return [
      _line(365, 388, 561, 219, const Color(0xFFFFFFFF), 26),
      _Shape(_body.path, _body.svg, const Color(0xFFFFFFFF), 28),
      _circle(394, 555, 67, const Color(0xFFFFFFFF), 22),
      _line(536, 494, 680, 494, const Color(0xFFFFFFFF), 22),
      _line(536, 544, 622, 544, const Color(0xFFFFFFFF), 22),
      _circle(648, 630, 25, const Color(0xFFFFFFFF)),
    ];
  }
  return [
    _line(365, 388, 561, 219, _cream, 26),
    _circle(561, 219, 13, _cream),
    _body,
    _circle(394, 555, 88, const Color(0xFFF1D7BE)),
    _circle(394, 555, 64, _coral, 17),
    _circle(394, 555, 29, _coral),
    _line(536, 494, 680, 494, _coral, 22),
    _line(536, 544, 622, 544, _coral, 22),
    _circle(648, 630, 25, _coral),
  ];
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

Future<Uint8List> _png(
  int size, {
  bool rounded = false,
  String skin = 'walnut',
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(size / 1024);
  const bounds = Rect.fromLTWH(0, 0, 1024, 1024);
  if (rounded) {
    canvas.clipRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(224)),
    );
  }
  canvas.drawRect(
    bounds,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: switch (skin) {
          'midnight' => [
            const Color(0xFFB9C8E9),
            const Color(0xFF7895D1),
            const Color(0xFF506EC4),
          ],
          'forest' => [
            const Color(0xFFBDCFB3),
            const Color(0xFF78A88B),
            const Color(0xFF447964),
          ],
          _ => [
            const Color(0xFFF1A27B),
            const Color(0xFFE77755),
            const Color(0xFFCE513B),
          ],
        },
      ).createShader(bounds),
  );
  // 很轻的光晕让小图标仍清晰，不加入在小尺寸下难以辨认的文字。
  canvas.drawCircle(
    const Offset(210, 160),
    590,
    Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x24FFF3DF), Color(0x00FFF3DF)],
      ).createShader(const Rect.fromLTWH(-380, -430, 1180, 1180)),
  );
  canvas.save();
  canvas.translate(512, 512);
  canvas.scale(1.12);
  canvas.translate(-512, -512);
  canvas.drawPath(
    _body.path.shift(const Offset(0, 15)),
    Paint()
      ..color = const Color(0x22000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 15),
  );
  for (final shape in _shapes()) {
    canvas.drawPath(
      shape.path,
      Paint()
        ..color = shape.color == _coral
            ? switch (skin) {
                'midnight' => const Color(0xFF506EC4),
                'forest' => const Color(0xFF447964),
                _ => _coral,
              }
            : shape.color == const Color(0xFFF1D7BE) && skin != 'walnut'
            ? (skin == 'forest'
                  ? const Color(0xFFD6E0CC)
                  : const Color(0xFFD5DEF1))
            : shape.color
        ..style = shape.stroke == 0 ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = shape.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }
  canvas.restore();
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  final bytes = data.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}

Future<void> _write(String path, List<int> bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
}

String _vector({bool monochrome = false}) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_app_icons_test.dart; foreground stays within the adaptive safe zone. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="1024" android:viewportHeight="1024">
${_shapes(monochrome: monochrome).map((s) => '    <path android:pathData="${s.svg}" android:fillColor="${s.stroke == 0 ? _hex(s.color) : '#00000000'}"${s.stroke == 0 ? '' : ' android:strokeColor="${_hex(s.color)}" android:strokeWidth="${s.stroke}" android:strokeLineCap="round" android:strokeLineJoin="round"'}/>').join('\n')}
</vector>
''';

Future<void> _ico() async {
  const sizes = [16, 24, 32, 48, 64, 128, 256];
  final images = [for (final size in sizes) await _png(size, rounded: true)];
  final header = ByteData(6 + sizes.length * 16);
  header.setUint16(2, 1, Endian.little);
  header.setUint16(4, sizes.length, Endian.little);
  var offset = header.lengthInBytes;
  for (var i = 0; i < sizes.length; i++) {
    final p = 6 + i * 16;
    header.setUint8(p, sizes[i] == 256 ? 0 : sizes[i]);
    header.setUint8(p + 1, sizes[i] == 256 ? 0 : sizes[i]);
    header.setUint16(p + 4, 1, Endian.little);
    header.setUint16(p + 6, 32, Endian.little);
    header.setUint32(p + 8, images[i].length, Endian.little);
    header.setUint32(p + 12, offset, Endian.little);
    offset += images[i].length;
  }
  await _write('windows/runner/resources/app_icon.ico', [
    ...header.buffer.asUint8List(),
    for (final bytes in images) ...bytes,
  ]);
}

void main() {
  testWidgets('生成时光收音机平台图标资源', (tester) async {
    await tester.runAsync(() async {
      await _write('assets/branding/app_icon.png', await _png(1024));
      await _write(
        'assets/branding/app_icon_preview.png',
        await _png(512, rounded: true),
      );
      final svg =
          '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
<defs><linearGradient id="bg" x2="1" y2="1"><stop stop-color="#F1A27B"/><stop offset=".5" stop-color="#E77755"/><stop offset="1" stop-color="#CE513B"/></linearGradient></defs>
<rect width="1024" height="1024" fill="url(#bg)"/>
<g transform="translate(512 512) scale(1.12) translate(-512 -512)">
${_shapes().map((s) => '<path d="${s.svg}" fill="${s.stroke == 0 ? _hex(s.color) : 'none'}"${s.stroke == 0 ? '' : ' stroke="${_hex(s.color)}" stroke-width="${s.stroke}" stroke-linecap="round" stroke-linejoin="round"'}/>').join('\n')}
</g></svg>
''';
      await _write('assets/branding/app_icon.svg', utf8.encode(svg));
      for (final (skin, accent, tint, gradient) in [
        ('walnut', '#D96246', '#F1D7BE', ['#F1A27B', '#E77755', '#CE513B']),
        ('midnight', '#506EC4', '#D5DEF1', ['#B9C8E9', '#7895D1', '#506EC4']),
        ('forest', '#447964', '#D6E0CC', ['#BDCFB3', '#78A88B', '#447964']),
      ]) {
        await _write(
          'android/app/src/main/res/drawable-nodpi/splash_logo_$skin.png',
          await _png(448, rounded: true, skin: skin),
        );
        await _write(
          'android/app/src/main/res/drawable/ic_radio_foreground_$skin.xml',
          utf8.encode(
            _vector().replaceAll('#D96246', accent).replaceAll('#F1D7BE', tint),
          ),
        );
        await _write(
          'android/app/src/main/res/drawable/ic_radio_background_$skin.xml',
          utf8.encode(
            '''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><gradient android:angle="315" android:startColor="${gradient[0]}" android:centerColor="${gradient[1]}" android:endColor="${gradient[2]}" /></shape>''',
          ),
        );
        await _write(
          'android/app/src/main/res/mipmap-anydpi-v26/ic_splash_$skin.xml',
          utf8.encode(
            '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@drawable/ic_radio_background_$skin"/><foreground android:drawable="@drawable/ic_radio_foreground_$skin"/></adaptive-icon>''',
          ),
        );
        final background = skin == 'midnight'
            ? 'radio_launch_blue'
            : skin == 'forest'
            ? 'radio_launch_green'
            : 'radio_launch_background';
        await _write(
          'android/app/src/main/res/drawable/launch_$skin.xml',
          utf8.encode(
            '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android"><item android:drawable="@color/$background"/><item android:width="112dp" android:height="112dp" android:gravity="center"><bitmap android:gravity="fill" android:src="@drawable/splash_logo_$skin"/></item></layer-list>''',
          ),
        );
      }
      for (final (density, size) in [
        ('mdpi', 48),
        ('hdpi', 72),
        ('xhdpi', 96),
        ('xxhdpi', 144),
        ('xxxhdpi', 192),
      ]) {
        await _write(
          'android/app/src/main/res/mipmap-$density/ic_launcher.png',
          await _png(size, rounded: true),
        );
      }
      await _write(
        'android/app/src/main/res/drawable/ic_radio_foreground.xml',
        utf8.encode(_vector()),
      );
      await _write(
        'android/app/src/main/res/drawable/ic_radio_monochrome.xml',
        utf8.encode(_vector(monochrome: true)),
      );
      await _write(
        'android/app/src/main/res/drawable-nodpi/splash_logo.png',
        await _png(448, rounded: true),
      );
      for (final platform in ['ios', 'macos']) {
        final directory = '$platform/Runner/Assets.xcassets/AppIcon.appiconset';
        final json =
            jsonDecode(await File('$directory/Contents.json').readAsString())
                as Map<String, dynamic>;
        for (final icon
            in (json['images'] as List).cast<Map<String, dynamic>>()) {
          final size = double.parse((icon['size'] as String).split('x').first);
          final scale = double.parse(
            (icon['scale'] as String).replaceAll('x', ''),
          );
          await _write(
            '$directory/${icon['filename']}',
            await _png((size * scale).round(), rounded: platform == 'macos'),
          );
        }
      }
      for (final (suffix, scale) in [('', 1), ('@2x', 2), ('@3x', 3)]) {
        await _write(
          'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
          await _png(112 * scale, rounded: true),
        );
      }
      await _ico();
    });
  });
}
