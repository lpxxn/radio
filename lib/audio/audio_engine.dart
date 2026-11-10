import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'dart:async';

enum EnginePhase { idle, loading, buffering, ready, completed }

/// 把插件包在小接口后面：单元测试不用真正连网、启动声卡。
abstract class AudioEngine {
  Stream<EnginePhase> get phases;
  Stream<Object> get errors;
  Stream<Duration> get positions;
  Duration get position;
  Duration get bufferedPosition;
  Future<void> open(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> setVolume(double value);
  Future<void> dispose();
}

/// Windows 直接使用 media_kit，避免把 HLS 分片误映射成播放队列索引。
class MediaKitEngine implements AudioEngine {
  MediaKitEngine() {
    _subscriptions.add(
      _player.stream.buffering.listen((buffering) {
        _phases.add(buffering ? EnginePhase.buffering : EnginePhase.ready);
      }),
    );
    _subscriptions.add(
      _player.stream.completed.listen((done) {
        if (done) _phases.add(EnginePhase.completed);
      }),
    );
  }
  final mk.Player _player = mk.Player(
    configuration: const mk.PlayerConfiguration(bufferSize: 16 * 1024 * 1024),
  );
  final _phases = StreamController<EnginePhase>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  @override
  Stream<EnginePhase> get phases => _phases.stream;
  @override
  Stream<Object> get errors => _player.stream.error;
  @override
  Stream<Duration> get positions => _player.stream.position;
  @override
  Duration get position => _player.state.position;
  @override
  Duration get bufferedPosition => _player.state.buffer;
  @override
  Future<void> open(String url) async {
    _phases.add(EnginePhase.loading);
    await _player.open(mk.Media(url), play: false);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> setVolume(double value) => _player.setVolume(value * 100);
  @override
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _player.dispose();
    await _phases.close();
  }
}

class JustAudioEngine implements AudioEngine {
  final AudioPlayer _player = AudioPlayer(
    // 由 RadioHandler 统一处理打断，避免状态与自动重连意图不一致。
    handleInterruptions: false,
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(seconds: 30),
        maxBufferDuration: Duration(seconds: 90),
        bufferForPlaybackDuration: Duration(seconds: 3),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 6),
        prioritizeTimeOverSizeThresholds: true,
      ),
      darwinLoadControl: DarwinLoadControl(
        preferredForwardBufferDuration: Duration(seconds: 60),
      ),
    ),
  );
  @override
  Stream<EnginePhase> get phases =>
      _player.processingStateStream.map((s) => EnginePhase.values[s.index]);
  @override
  Stream<Object> get errors => _player.errorStream;
  @override
  Stream<Duration> get positions => _player.positionStream;
  @override
  Duration get position => _player.position;
  @override
  Duration get bufferedPosition => _player.bufferedPosition;
  @override
  Future<void> open(String url) async {
    await _player.setUrl(url);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> setVolume(double value) => _player.setVolume(value);
  @override
  Future<void> dispose() => _player.dispose();
}
