import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/station.dart';

/// 一次收听的上下文：当前台与有序队列一起保存，避免重启后跳回全部电台。
/// 不保存播放意图或睡眠计时；重新打开时展示上次电台，等待用户点击播放。
class PlaybackSession {
  const PlaybackSession({
    required this.station,
    required this.queueIds,
    required this.label,
    required this.scoped,
    required this.favorites,
  });
  final Station station;
  final List<String> queueIds;
  final String label;
  final bool scoped, favorites;

  Map<String, dynamic> toJson() => {
    'station': station.toJson(),
    'queueIds': queueIds,
    'label': label,
    'scoped': scoped,
    'favorites': favorites,
  };
}

class PlaybackSessionStore {
  PlaybackSessionStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'playback.session.v1';
  Future<void> _pending = Future.value();

  PlaybackSession? read() {
    try {
      final raw = preferences.getString(key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final station = Station.fromJson(json['station'] as Map<String, dynamic>);
      if (station.urls.isEmpty) return null;
      return PlaybackSession(
        station: station,
        queueIds: List<String>.from(json['queueIds'] as List),
        label: json['label'] as String,
        scoped: json['scoped'] as bool,
        favorites: json['favorites'] as bool,
      );
    } on Object {
      // 旧版本或损坏数据不能阻止应用启动；目录和收藏仍然可用。
      return null;
    }
  }

  Future<void> save(PlaybackSession session) {
    final encoded = jsonEncode(session.toJson());
    // 串行写入，快速连续换台时不会被较早的异步写入覆盖。
    _pending = _pending.then((_) async {
      await preferences.setString(key, encoded);
    });
    return _pending;
  }

  Future<void> flush() => _pending;
}
