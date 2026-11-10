import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiguang_radio/data/station_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('损坏的目录缓存回退内置国内电台', () async {
    SharedPreferences.setMockInitialValues({
      StationRepository.cacheKey: '{broken',
    });
    final repository = StationRepository(await SharedPreferences.getInstance());
    addTearDown(repository.dispose);
    expect((await repository.load()).any((s) => s.name == '中国之声'), true);
  });
  test('镜像失败后回退、过滤无效地址并持久化', () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    final repository = StationRepository(
      await SharedPreferences.getInstance(),
      client: MockClient((request) async {
        calls++;
        if (calls == 1) return http.Response('unavailable', 503);
        return http.Response(
          jsonEncode([
            {
              'stationuuid': 'demo',
              'name': '国内音乐',
              'url_resolved': 'https://example.com/live',
              'state': '北京',
              'tags': 'music',
            },
            {
              'stationuuid': 'bad',
              'name': '无效',
              'url_resolved': 'file:///tmp/audio',
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(repository.dispose);
    final stations = await repository.refresh();
    expect(calls, 2);
    expect(stations.any((s) => s.id == 'demo'), true);
    expect(stations.any((s) => s.id == 'bad'), false);
    expect((await repository.load()).any((s) => s.id == 'demo'), true);
  });
}
