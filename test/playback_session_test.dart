import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiguang_radio/audio/radio_handler.dart';
import 'package:shiguang_radio/data/playback_session.dart';
import 'radio_handler_test.dart' show FakeEngine, stations;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('冷启动恢复收藏电台、有序队列，且不自动出声', () async {
    SharedPreferences.setMockInitialValues({
      'favorites': ['two', 'one'],
    });
    final prefs = await SharedPreferences.getInstance();
    final first = RadioHandler(
      FakeEngine(),
      sessionStore: PlaybackSessionStore(prefs),
    );
    first.setStations(stations);
    await first.selectFromList(
      stations.first,
      stations.reversed.toList(),
      label: '我的收藏',
      favorites: true,
    );
    await first.stop();
    await first.flushSession();
    await first.dispose();

    final engine = FakeEngine();
    final reopened = RadioHandler(
      engine,
      sessionStore: PlaybackSessionStore(prefs),
    );
    addTearDown(reopened.dispose);
    reopened.setStations(stations);
    expect(reopened.snapshot.station?.id, 'one');
    expect(reopened.snapshot.queueLabel, '我的收藏');
    expect(reopened.queue.value.map((s) => s.id), ['two', 'one']);
    expect(reopened.snapshot.phase, RadioPhase.paused);
    expect(reopened.snapshot.wantPlay, false);
    expect(engine.opens, 0);
    expect(engine.plays, 0);
    await reopened.skipToNext();
    expect(reopened.snapshot.station?.id, 'two');
    await reopened.skipToPrevious();
    expect(reopened.snapshot.station?.id, 'one');
  });

  test('地区单台队列重启后不扩大为全部电台', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final handler = RadioHandler(
      FakeEngine(),
      sessionStore: PlaybackSessionStore(prefs),
    );
    handler.setStations(stations);
    await handler.selectFromList(stations.first, [stations.first], label: '北京');
    await handler.flushSession();
    await handler.dispose();
    final restored = RadioHandler(
      FakeEngine(),
      sessionStore: PlaybackSessionStore(prefs),
    );
    addTearDown(restored.dispose);
    restored.setStations(stations);
    restored.setStations(stations); // 后续目录刷新也保持已恢复范围。
    await restored.skipToNext();
    expect(restored.snapshot.station?.id, 'one');
    expect(restored.snapshot.queueLength, 1);
    expect(restored.snapshot.queueLabel, '北京');
  });

  test('收藏重排立即保存，缺失目录项保留当前台，损坏缓存不阻塞启动', () async {
    SharedPreferences.setMockInitialValues({
      'favorites': ['one', 'two'],
    });
    final prefs = await SharedPreferences.getInstance();
    final handler = RadioHandler(
      FakeEngine(),
      sessionStore: PlaybackSessionStore(prefs),
    );
    handler.setStations(stations);
    await handler.selectFromList(
      stations.first,
      stations,
      label: '我的收藏',
      favorites: true,
    );
    handler.updateFavoriteQueue(stations.reversed.toList());
    await prefs.setStringList('favorites', ['two', 'one']);
    await handler.flushSession();
    await handler.dispose();
    final restored = RadioHandler(
      FakeEngine(),
      sessionStore: PlaybackSessionStore(prefs),
    );
    addTearDown(restored.dispose);
    restored.setStations([stations.last]);
    expect(restored.snapshot.station?.name, '音乐之声');
    expect(restored.queue.value.map((s) => s.id), ['two', 'one']);
    await restored.skipToNext();
    expect(restored.snapshot.station?.id, 'two');
    await restored.flushSession();
    await prefs.setString(PlaybackSessionStore.key, '{broken');
    expect(PlaybackSessionStore(prefs).read(), isNull);
  });
}
