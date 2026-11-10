import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio/audio_engine.dart';
import 'audio/radio_handler.dart';
import 'data/playback_session.dart';
import 'platform/startup_appearance.dart';
import 'providers.dart';
import 'ui/radio_page.dart';
import 'ui/radio_skin.dart';
import 'ui/radio_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows 使用 libmpv；Android/iOS/macOS 保留 just_audio 原生后端。
  if (Platform.isWindows) {
    MediaKit.ensureInitialized();
  }
  final preferences = await SharedPreferences.getInstance();
  await StartupAppearance.apply(preferences.getString('skin') ?? 'walnut');
  RadioHandler handler;
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    handler = await AudioService.init<RadioHandler>(
      builder: () => RadioHandler(
        JustAudioEngine(),
        sessionStore: PlaybackSessionStore(preferences),
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'cn.shiguang.radio.playback',
        androidNotificationChannelName: '电台播放',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    handler.bindAudioSession(session);
  } else {
    // audio_service 没有 Windows 实现；桌面播放共用 handler，跳过服务初始化。
    handler = RadioHandler(
      MediaKitEngine(),
      sessionStore: PlaybackSessionStore(preferences),
    );
  }
  // 手机音量交给系统音量键；桌面保留应用内音量。
  await handler.volume(
    Platform.isAndroid || Platform.isIOS
        ? 1
        : preferences.getDouble('volume') ?? .75,
  );
  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(preferences),
        radioProvider.overrideWithValue(handler),
      ],
      child: const RadioApp(),
    ),
  );
}

class RadioApp extends ConsumerWidget {
  const RadioApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: '时光收音机',
    debugShowCheckedModeBanner: false,
    theme: radioTheme(ref.watch(skinProvider)),
    home: const RadioPage(),
  );
}
