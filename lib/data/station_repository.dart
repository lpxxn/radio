import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/station.dart';

/// 先读本机，再显式刷新网络。目录接口故障不能阻止已有电台播放。
class StationRepository {
  StationRepository(this.preferences, {http.Client? client})
    : _client = client ?? http.Client();
  final SharedPreferences preferences;
  final http.Client _client;
  static const cacheKey = 'stations.v1';

  Future<List<Station>> load() async {
    final bundled = _decode(
      await rootBundle.loadString('assets/stations.json'),
    );
    try {
      final cached = preferences.getString(cacheKey);
      if (cached != null) return _merge(bundled, _decode(cached));
    } on Object {
      /* 损坏的缓存可忽略，内置目录仍可使用。 */
    }
    return bundled;
  }

  Future<List<Station>> refresh() async {
    Object? lastError;
    // 多镜像顺序回退；每个请求有超时，避免弱网下一直等待。
    for (final host in [
      'de1.api.radio-browser.info',
      'nl1.api.radio-browser.info',
    ]) {
      try {
        final uri = Uri.https(host, '/json/stations/bycountrycodeexact/CN', {
          'hidebroken': 'true',
          'limit': '300',
          'order': 'votes',
          'reverse': 'true',
        });
        final response = await _client
            .get(uri, headers: {'User-Agent': 'ShiguangRadio/1.0'})
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) {
          throw Exception('目录服务 ${response.statusCode}');
        }
        final stations = (jsonDecode(utf8.decode(response.bodyBytes)) as List)
            .cast<Map<String, dynamic>>()
            .map(_fromBrowser)
            .whereType<Station>()
            .toList();
        if (stations.isEmpty) throw const FormatException('没有有效的国内电台');
        await preferences.setString(
          cacheKey,
          jsonEncode(stations.map((s) => s.toJson()).toList()),
        );
        await preferences.setString(
          'catalog.updated',
          DateTime.now().toIso8601String(),
        );
        final bundled = _decode(
          await rootBundle.loadString('assets/stations.json'),
        );
        return _merge(bundled, stations);
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw Exception('刷新失败，已保留本机目录。$lastError');
  }

  static Station? _fromBrowser(Map<String, dynamic> row) {
    final url = (row['url_resolved'] as String? ?? row['url'] as String? ?? '')
        .trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return null;
    }
    final id = row['stationuuid'] as String? ?? '';
    final name = (row['name'] as String? ?? '').trim();
    if (id.isEmpty || name.isEmpty) return null;
    final tags = row['tags'] as String? ?? '';
    return Station(
      id: id,
      name: name,
      region: (row['state'] as String? ?? '').isEmpty
          ? '其他'
          : row['state'] as String,
      category: tags.contains('音乐') || tags.contains('music') ? '音乐' : '综合',
      urls: List.unmodifiable([url]),
      homepage: row['homepage'] as String? ?? '',
    );
  }

  static List<Station> _decode(String text) => (jsonDecode(text) as List)
      .map((row) => Station.fromJson(row as Map<String, dynamic>))
      .toList();
  static List<Station> _merge(List<Station> first, List<Station> second) {
    final urls = <String>{};
    return [
      ...first,
      ...second,
    ].where((s) => s.urls.isNotEmpty && urls.add(s.urls.first)).toList();
  }

  void dispose() => _client.close();
}
