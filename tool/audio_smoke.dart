// 手动集成探针：flutter run -d windows -t tool/audio_smoke.dart
// 静音验证真实播放器的网络连接和解码，不代表人耳听感验收。
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shiguang_radio/audio/audio_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('静音音频解码验证'))),
    ),
  );
  final engine = MediaKitEngine();
  final errors = engine.errors.listen((e) => debugPrint('ENGINE_ERROR: $e'));
  final phases = engine.phases.listen((e) => debugPrint('ENGINE_PHASE: $e'));
  var result = 1;
  try {
    await engine.setVolume(0);
    await engine
        .open(
          Platform.environment['RADIO_SMOKE_URL'] ??
              const String.fromEnvironment(
                'SMOKE_URL',
                defaultValue: 'https://ngcdn002.cnr.cn/live/jjzs/index.m3u8',
              ),
        )
        .timeout(const Duration(seconds: 25));
    unawaited(
      engine.play().catchError((Object error) {
        debugPrint('PLAY_ERROR: $error');
      }),
    );
    await engine.positions
        .firstWhere((p) => p >= const Duration(seconds: 3))
        .timeout(const Duration(seconds: 30));
    debugPrint(
      'AUDIO_SMOKE_OK position=${engine.position} buffered=${engine.bufferedPosition}',
    );
    result = 0;
  } on Object catch (error) {
    debugPrint('AUDIO_SMOKE_FAILED: $error');
  } finally {
    await errors.cancel();
    await phases.cancel();
    await engine.dispose();
    exit(result);
  }
}
