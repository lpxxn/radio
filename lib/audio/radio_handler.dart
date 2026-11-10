import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import '../models/station.dart';
import '../data/playback_session.dart';
import 'audio_engine.dart';

enum RadioPhase { idle, connecting, playing, paused, buffering, retrying }

/// UI 读的不可变快照。wantPlay 是用户意图，不能用引擎 playing 代替：
/// 网络故障时引擎可能停止，但用户仍然希望联网后继续收听。
class RadioSnapshot {
  const RadioSnapshot({
    this.station,
    this.phase = RadioPhase.idle,
    this.wantPlay = false,
    this.retry = 0,
    this.buffer = Duration.zero,
    this.message = '选一个电台，让声音陪伴你',
    this.volume = .75,
    this.sleepAt,
    this.queueLabel = '全部电台',
    this.queueLength = 0,
  });
  final Station? station;
  final RadioPhase phase;
  final bool wantPlay;
  final int retry;
  final Duration buffer;
  final String message;
  final double volume;
  final DateTime? sleepAt;
  final String queueLabel;
  final int queueLength;
}

/// 唯一的播放控制入口。通知栏、耳机、车机、Flutter 按钮都调用这里。
class RadioHandler extends BaseAudioHandler with QueueHandler {
  RadioHandler(
    this.engine, {
    this.retryUnit = const Duration(seconds: 2),
    this.stallTimeout = const Duration(seconds: 25),
    this.sessionStore,
  }) {
    _subscriptions.add(engine.phases.listen(_onPhase));
    _subscriptions.add(engine.errors.listen((_) => _retryLater()));
    _subscriptions.add(
      engine.positions.listen((position) {
        if (position != _lastPosition) {
          _lastPosition = position;
          _lastProgress = DateTime.now();
        }
        _emit();
      }),
    );
    // 部分原生后端在断流后仍报告 ready，用位置停滞兜底。
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_wantPlay &&
          _phase == RadioPhase.playing &&
          DateTime.now().difference(_lastProgress) > stallTimeout) {
        _retryLater();
      }
    });
  }
  final AudioEngine engine;
  final PlaybackSessionStore? sessionStore;
  bool _sessionRestored = false;
  final Duration retryUnit, stallTimeout;
  final _events = StreamController<RadioSnapshot>.broadcast();
  Stream<RadioSnapshot> get snapshots => _events.stream;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<Station> _stations = [];
  List<Station> _playQueue = [];
  String _queueLabel = '全部电台';
  bool _scopedQueue = false;
  bool _favoriteQueue = false;
  Station? _station;
  RadioPhase _phase = RadioPhase.idle;
  bool _wantPlay = false, _disposed = false, _loading = false;
  int _attempt = 0, _generation = 0;
  double _volume = .75;
  Timer? _retryTimer, _stallTimer, _sleepTimer;
  DateTime? _sleepAt;
  Timer? _progressTimer;
  DateTime _lastProgress = DateTime.now();
  Duration _lastPosition = Duration.zero;
  RadioSnapshot get snapshot => RadioSnapshot(
    station: _station,
    phase: _phase,
    wantPlay: _wantPlay,
    retry: _attempt,
    volume: _volume,
    sleepAt: _sleepAt,
    queueLabel: _queueLabel,
    queueLength: _playQueue.length,
    buffer: _station == null || !_wantPlay
        ? Duration.zero
        : Duration(
            milliseconds: max(
              0,
              engine.bufferedPosition.inMilliseconds -
                  engine.position.inMilliseconds,
            ),
          ),
    message: switch (_phase) {
      RadioPhase.idle => '选一个电台，让声音陪伴你',
      RadioPhase.connecting => '正在连接电台…',
      RadioPhase.playing => '正在直播 · 好声音，此刻相伴',
      RadioPhase.paused => '已暂停',
      RadioPhase.buffering => '正在缓冲，稍等片刻…',
      RadioPhase.retrying => '信号暂时中断 · 自动重连第 $_attempt 次',
    },
  );

  void setStations(List<Station> stations) {
    _stations = List.unmodifiable(stations);
    // 目录来自本地缓存或内置列表；完成加载后按 ID 恢复，优先使用最新流地址。
    if (!_sessionRestored) {
      _sessionRestored = true;
      final saved = sessionStore?.read();
      if (_station == null && saved != null) {
        final byId = {for (final s in stations) s.id: s};
        _station = byId[saved.station.id] ?? saved.station;
        _scopedQueue = saved.scoped;
        _favoriteQueue = saved.favorites;
        _queueLabel = saved.label;
        _playQueue = [
          for (final id in saved.queueIds)
            if (byId.containsKey(id))
              byId[id]!
            else if (id == saved.station.id)
              _station!,
        ];
        // 收藏可能在上次退出前变化，仍按已持久化的收藏顺序取交集。
        if (_favoriteQueue) {
          final ids = sessionStore!.preferences.getStringList('favorites');
          if (ids != null) {
            final selected = {for (final s in _playQueue) s.id: s};
            _playQueue = [
              for (final id in ids)
                if (selected.containsKey(id)) selected[id]!,
            ];
          }
        }
        _phase = RadioPhase.paused;
        mediaItem.add(_item(_station!));
      }
    }
    if (!_scopedQueue) {
      _playQueue = _stations;
    } else {
      final updated = {for (final s in stations) s.id: s};
      _station = updated[_station?.id] ?? _station;
      _playQueue = [
        for (final s in _playQueue)
          if (updated.containsKey(s.id))
            updated[s.id]!
          else if (s.id == _station?.id)
            _station!,
      ];
    }
    _publishQueue();
    _saveSession();
  }

  /// 播放列表在选台时确定；仅浏览其他地区不影响正在收听的队列。
  Future<void> selectFromList(
    Station station,
    List<Station> stations, {
    required String label,
    bool favorites = false,
  }) async {
    if (!stations.any((s) => s.id == station.id)) return;
    _scopedQueue = true;
    _favoriteQueue = favorites;
    _queueLabel = label;
    _playQueue = List.unmodifiable(stations);
    _publishQueue();
    await select(station);
  }

  /// 收藏排序/删除立即同步到正在播放的收藏队列，保持原选台范围。
  void updateFavoriteQueue(List<Station> favorites) {
    if (!_favoriteQueue) return;
    final selectedIds = _playQueue.map((s) => s.id).toSet();
    _playQueue = favorites.where((s) => selectedIds.contains(s.id)).toList();
    _publishQueue();
    _saveSession();
  }

  Future<void> _saveSession() async {
    final station = _station;
    if (station == null) return;
    await sessionStore?.save(
      PlaybackSession(
        station: station,
        queueIds: _playQueue.map((s) => s.id).toList(),
        label: _queueLabel,
        scoped: _scopedQueue,
        favorites: _favoriteQueue,
      ),
    );
  }

  Future<void> flushSession() async => sessionStore?.flush();

  void _publishQueue() {
    queue.add(_playQueue.map(_item).toList());
    queueTitle.add(_queueLabel);
    _emit();
  }

  MediaItem _item(Station s) => MediaItem(
    id: s.id,
    title: s.name,
    artist: '${s.region} · ${s.category}',
    album: '时光收音机',
    isLive: true,
    playable: true,
  );

  /// 来电/其他应用抢占音频、耳机拔出都取消播放意图。
  /// 不在打断结束后抢播；用户可手动恢复，网络重连不能绕过音频焦点。
  void bindAudioSession(AudioSession session) {
    _subscriptions.add(
      session.interruptionEventStream.listen((event) {
        if (event.begin && _wantPlay) unawaited(pause());
      }),
    );
    _subscriptions.add(
      session.becomingNoisyEventStream.listen((_) {
        if (_wantPlay) unawaited(pause());
      }),
    );
  }

  Future<void> select(Station station) async {
    _station = station;
    _wantPlay = true;
    _attempt = 0;
    final generation = ++_generation;
    _loading = true;
    _cancelRecovery();
    mediaItem.add(_item(station));
    // 在网络请求之前落盘；保存期间暂停或再次换台，由 generation 作废旧操作。
    await _saveSession();
    if (!_valid(generation)) return;
    // stop 会中止旧的 setUrl，generation 会丢弃旧 Future 的结果。
    await engine.stop();
    await _connect(generation);
  }

  Future<void> _connect(int generation) async {
    if (!_valid(generation) || _station == null) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _loading = true;
    _phase = RadioPhase.connecting;
    _lastProgress = DateTime.now();
    _emit();
    _armStall();
    try {
      final urls = _station!.urls;
      await engine.open(urls[_attempt % urls.length]).timeout(stallTimeout);
      if (!_valid(generation)) return;
      _loading = false;
      _phase = RadioPhase.playing;
      _stallTimer?.cancel();
      _emit();
      // just_audio.play() 的 Future 直到暂停/结束才返回，不能在这里 await。
      unawaited(
        engine.play().catchError((Object _) {
          if (_valid(generation)) _retryLater();
        }),
      );
    } on Object {
      if (_valid(generation)) {
        _loading = false;
        _retryLater();
      }
    }
  }

  bool _valid(int generation) =>
      !_disposed && _wantPlay && generation == _generation;

  void _onPhase(EnginePhase phase) {
    if (_disposed || !_wantPlay) return;
    if (phase == EnginePhase.buffering) {
      _phase = RadioPhase.buffering;
      _armStall();
    } else if (phase == EnginePhase.ready) {
      _phase = RadioPhase.playing;
      _stallTimer?.cancel();
      _retryTimer?.cancel();
      _retryTimer = null;
      // 连接就绪不清零重试次数，避免反复断流时只以最短间隔重试。
    } else if (phase == EnginePhase.completed ||
        (phase == EnginePhase.idle && !_loading)) {
      _retryLater();
    }
    _emit();
  }

  void _armStall() {
    if (_stallTimer?.isActive ?? false) return;
    _stallTimer = Timer(stallTimeout, () {
      _stallTimer = null;
      _retryLater();
    });
  }

  void _retryLater() {
    if (_disposed || !_wantPlay || (_retryTimer?.isActive ?? false)) return;
    _stallTimer?.cancel();
    _stallTimer = null;
    _attempt++;
    _phase = RadioPhase.retrying;
    _emit();
    // 2、4、8、16、30 秒封顶。持续重试，不因短时断网永久停止。
    final ms = min(
      30000,
      retryUnit.inMilliseconds * pow(2, min(_attempt - 1, 4)).toInt(),
    );
    _retryTimer = Timer(Duration(milliseconds: ms), () async {
      if (!_wantPlay || _disposed) return;
      final generation = ++_generation;
      _loading = true;
      await engine.stop();
      await _connect(generation);
    });
  }

  /// 网络类型变化只是重试提示，Wi-Fi 连上不等于互联网可用。
  void networkAvailable() {
    if (_wantPlay && !_loading && _phase == RadioPhase.retrying) {
      _retryTimer?.cancel();
      _retryTimer = Timer(Duration.zero, () => _connect(++_generation));
    }
  }

  @override
  Future<void> play() async {
    if (_station == null) {
      if (_playQueue.isNotEmpty) await select(_playQueue.first);
      return;
    }
    _wantPlay = true;
    _attempt = 0;
    await _connect(++_generation); // 直播恢复时重新连接到当前直播点。
  }

  @override
  Future<void> pause() async {
    _wantPlay = false;
    _generation++;
    _loading = false;
    _cancelRecovery();
    _phase = RadioPhase.paused;
    _emit();
    await engine.stop(); // 释放网络连接，恢复时重新取直播流。
  }

  @override
  Future<void> stop() async {
    await pause();
    await super.stop();
  }

  Future<void> toggle() => _wantPlay ? pause() : play();
  @override
  Future<void> skipToNext() => _skip(1);
  @override
  Future<void> skipToPrevious() => _skip(-1);
  Future<void> _skip(int delta) async {
    if (_playQueue.isEmpty) return;
    final index = _playQueue.indexWhere((s) => s.id == _station?.id);
    final next = index < 0
        ? (delta > 0 ? 0 : _playQueue.length - 1)
        : (index + delta) % _playQueue.length;
    await select(_playQueue[next]);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _playQueue.length) {
      await select(_playQueue[index]);
    }
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async => queue.value;
  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final index = _stations.indexWhere((s) => s.id == mediaId);
    if (index >= 0) {
      if (!_playQueue.any((s) => s.id == mediaId)) {
        _scopedQueue = false;
        _favoriteQueue = false;
        _queueLabel = '全部电台';
        _playQueue = _stations;
        _publishQueue();
      }
      await select(_stations[index]);
    }
  }

  Future<void> random() async {
    if (_playQueue.isNotEmpty) {
      await select(_playQueue[Random().nextInt(_playQueue.length)]);
    }
  }

  Future<void> volume(double value) async {
    _volume = value.clamp(0, 1);
    await engine.setVolume(_volume);
    _emit();
  }

  void sleep(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepAt = duration == null ? null : DateTime.now().add(duration);
    if (duration != null) {
      _sleepTimer = Timer(duration, () {
        _sleepAt = null;
        unawaited(pause());
      });
    }
    _emit();
  }

  void _cancelRecovery() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _stallTimer?.cancel();
    _stallTimer = null;
  }

  void _emit() {
    if (_disposed) return;
    _events.add(snapshot);
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          _wantPlay ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (_phase) {
          RadioPhase.idle => AudioProcessingState.idle,
          RadioPhase.connecting => AudioProcessingState.loading,
          RadioPhase.buffering ||
          RadioPhase.retrying => AudioProcessingState.buffering,
          _ => AudioProcessingState.ready,
        },
        playing: _wantPlay,
        queueIndex: _playQueue.indexWhere((s) => s.id == _station?.id) < 0
            ? null
            : _playQueue.indexWhere((s) => s.id == _station?.id),
      ),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    _cancelRecovery();
    _sleepTimer?.cancel();
    _progressTimer?.cancel();
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await engine.dispose();
    await _events.close();
  }
}
