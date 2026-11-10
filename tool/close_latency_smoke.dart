// 独立 Windows 退出诊断：不使用正式应用的偏好，不改用户收藏或上次电台。
// flutter run -d windows -t tool/close_latency_smoke.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shiguang_radio/audio/audio_engine.dart';
import 'package:shiguang_radio/audio/radio_handler.dart';
import 'package:shiguang_radio/models/station.dart';

class TimedEngine extends MediaKitEngine {
  @override
  Future<void> stop() async {
    final watch = Stopwatch()..start();
    debugPrint('CLOSE_TRACE engine.stop.begin');
    await super.stop();
    debugPrint('CLOSE_TRACE engine.stop.end ${watch.elapsedMilliseconds}ms');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('独立关闭耗时诊断')))));
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  // 接受 TCP/HTTP 请求但不返回数据，稳定复现直播连接挂起，不依赖公网。
  final requests = server.listen((_) {});
  try {
    for (final stalled in [false, true]) {
      final engine = TimedEngine();
      final handler = RadioHandler(engine);
      final label = stalled ? 'stalled-network' : 'idle';
      try {
        await engine.setVolume(0);
        if (stalled) {
          await handler.select(Station(id: 'probe', name: '本机诊断源', region: '测试', category: '测试', urls: ['http://127.0.0.1:${server.port}/stall.mp3']));
        }
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final watch = Stopwatch()..start();
        debugPrint('CLOSE_TRACE $label handler.stop.begin');
        await handler.stop().timeout(const Duration(seconds: 12));
        debugPrint('CLOSE_TRACE $label handler.stop.end ${watch.elapsedMilliseconds}ms');
        watch.reset();
        await handler.flushSession();
        debugPrint('CLOSE_TRACE $label flush.end ${watch.elapsedMilliseconds}ms');
      } on Object catch (error) {
        debugPrint('CLOSE_TRACE $label FAILED $error');
      } finally {
        await handler.dispose().timeout(const Duration(seconds: 12));
      }
    }
  } finally {
    await requests.cancel();
    await server.close(force: true);
    debugPrint('CLOSE_TRACE native.exit.begin');
    await ServicesBinding.instance.exitApplication(ui.AppExitType.required);
  }
}
