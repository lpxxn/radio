import 'dart:async';
import 'package:flutter_test/flutter_test.dart' hide EnginePhase;
import 'package:shiguang_radio/audio/audio_engine.dart';
import 'package:shiguang_radio/audio/radio_handler.dart';
import 'package:shiguang_radio/models/station.dart';

class FakeEngine implements AudioEngine {
  final phaseEvents = StreamController<EnginePhase>.broadcast(sync: true);
  final errorEvents = StreamController<Object>.broadcast(sync: true);
  bool fail = false;
  int opens = 0, plays = 0;
  @override
  Stream<EnginePhase> get phases => phaseEvents.stream;
  @override
  Stream<Object> get errors => errorEvents.stream;
  @override
  Stream<Duration> get positions => const Stream.empty();
  @override
  Duration get position => Duration.zero;
  @override
  Duration get bufferedPosition => const Duration(seconds: 8);
  @override
  Future<void> open(String url) async {
    opens++;
    if (fail) throw StateError('模拟断网');
    phaseEvents.add(EnginePhase.ready);
  }

  @override
  Future<void> play() async {
    plays++;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setVolume(double value) async {}
  @override
  Future<void> dispose() async {
    await phaseEvents.close();
    await errorEvents.close();
  }
}

const stations = [
  Station(
    id: 'one',
    name: '音乐之声',
    region: '全国',
    category: '音乐',
    urls: ['https://example.com/1'],
  ),
  Station(
    id: 'two',
    name: '中国之声',
    region: '全国',
    category: '新闻',
    urls: ['https://example.com/2'],
  ),
];
void main() {
  late FakeEngine engine;
  late RadioHandler handler;
  setUp(() {
    engine = FakeEngine();
    handler = RadioHandler(
      engine,
      retryUnit: const Duration(milliseconds: 10),
      stallTimeout: const Duration(milliseconds: 60),
    );
    handler.setStations(stations);
  });
  tearDown(() async => handler.dispose());

  test('断网后恢复自动播放，无须再次按播放', () async {
    engine.fail = true;
    await handler.select(stations.first);
    expect(handler.snapshot.phase, RadioPhase.retrying);
    engine.fail = false;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(engine.plays, 1);
    expect(handler.snapshot.phase, RadioPhase.playing);
  });
  test('主动暂停取消待执行重连，网络恢复不会唤醒', () async {
    engine.fail = true;
    await handler.select(stations.first);
    await handler.pause();
    engine.fail = false;
    handler.networkAvailable();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(engine.opens, 1);
    expect(engine.plays, 0);
    expect(handler.snapshot.wantPlay, false);
  });
  test('未指定列表时媒体换台使用完整目录并循环', () async {
    await handler.select(stations.first);
    await handler.skipToPrevious();
    expect(handler.snapshot.station!.id, 'two');
    await handler.skipToNext();
    expect(handler.snapshot.station!.id, 'one');
    await handler.playFromMediaId('two');
    expect(handler.mediaItem.value!.title, '中国之声');
    expect((await handler.getChildren('root')).length, 2);
  });
  test('地区列表只在选定范围内循环，系统队列也同步', () async {
    await handler.selectFromList(stations.first, [stations.first], label: '北京');
    await handler.skipToNext();
    expect(handler.snapshot.station!.id, 'one');
    await handler.skipToPrevious();
    expect(handler.snapshot.station!.id, 'one');
    handler.setStations(stations); // 刷新目录不能覆盖正在收听的地区队列。
    expect(handler.queue.value.map((s) => s.id), ['one']);
    expect(handler.snapshot.queueLabel, '北京');
  });
  test('收藏重排立即影响上一台/下一台，删除当前台仍可继续切换', () async {
    await handler.selectFromList(
      stations.first,
      stations,
      label: '我的收藏',
      favorites: true,
    );
    handler.updateFavoriteQueue(stations.reversed.toList());
    expect(handler.queue.value.map((s) => s.id), ['two', 'one']);
    await handler.skipToNext();
    expect(handler.snapshot.station!.id, 'two');
    handler.updateFavoriteQueue([stations.first]);
    await handler.skipToPrevious();
    expect(handler.snapshot.station!.id, 'one');
    handler.updateFavoriteQueue([]);
    await handler.skipToNext();
    expect(handler.snapshot.station!.id, 'one');
    expect(handler.queue.value, isEmpty);
  });
  test('缓冲停滞触发重连', () async {
    await handler.select(stations.first);
    engine.phaseEvents.add(EnginePhase.buffering);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(engine.opens, greaterThan(1));
  });
  test('睡眠到点停止并取消恢复意图', () async {
    await handler.select(stations.first);
    handler.sleep(const Duration(milliseconds: 10));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(handler.snapshot.wantPlay, false);
    expect(handler.snapshot.sleepAt, null);
  });
}
