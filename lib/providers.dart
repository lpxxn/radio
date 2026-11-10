import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio/radio_handler.dart';
import 'data/station_repository.dart';
import 'models/station.dart';

// main 中 override 已初始化的依赖；Widget 不负责创建插件或读磁盘。
final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);
final radioProvider = Provider<RadioHandler>(
  (ref) => throw UnimplementedError(),
);
final repositoryProvider = Provider((ref) {
  final repository = StationRepository(ref.watch(preferencesProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

// 直接订阅广播流；首帧从 handler.snapshot 读取，避免 async* 转发层的
// 暂停/取消语义延迟释放底层订阅。
final playbackProvider = StreamProvider<RadioSnapshot>(
  (ref) => ref.watch(radioProvider).snapshots,
);

final catalogProvider = AsyncNotifierProvider<CatalogNotifier, List<Station>>(
  CatalogNotifier.new,
);

class CatalogNotifier extends AsyncNotifier<List<Station>> {
  @override
  Future<List<Station>> build() async {
    final stations = await ref.watch(repositoryProvider).load();
    ref.read(radioProvider).setStations(stations);
    return stations;
  }

  Future<void> refresh() async {
    // 刷新失败继续保留旧数据，让 UI 可以显示提示并继续播放。
    final stations = await ref.read(repositoryProvider).refresh();
    ref.read(radioProvider).setStations(stations);
    state = AsyncData(stations);
  }
}

class LibraryState {
  const LibraryState({
    this.favorites = const [],
    this.recent = const [],
    this.query = '',
    this.region = '全部',
    this.tab = 0,
  });
  final List<String> favorites;
  final List<String> recent;
  final String query, region;
  final int tab;
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);

class LibraryNotifier extends Notifier<LibraryState> {
  @override
  LibraryState build() {
    final prefs = ref.watch(preferencesProvider);
    final subscription = ref.watch(radioProvider).snapshots.listen((snapshot) {
      final id = snapshot.station?.id;
      if (id == null || (state.recent.isNotEmpty && state.recent.first == id)) {
        return;
      }
      final recent = [
        id,
        ...state.recent.where((v) => v != id),
      ].take(30).toList();
      state = LibraryState(
        favorites: state.favorites,
        recent: recent,
        query: state.query,
        region: state.region,
        tab: state.tab,
      );
      unawaited(prefs.setStringList('recent', recent));
    });
    ref.onDispose(subscription.cancel);
    return LibraryState(
      favorites: (prefs.getStringList('favorites') ?? []).toSet().toList(),
      recent: prefs.getStringList('recent') ?? [],
    );
  }

  void filter({String? query, String? region, int? tab}) =>
      state = LibraryState(
        favorites: state.favorites,
        recent: state.recent,
        query: query ?? state.query,
        region: region ?? state.region,
        tab: tab ?? state.tab,
      );
  Future<void> favorite(String id) async {
    final favorites = [...state.favorites];
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    state = LibraryState(
      favorites: favorites,
      recent: state.recent,
      query: state.query,
      region: state.region,
      tab: state.tab,
    );
    await ref
        .read(preferencesProvider)
        .setStringList('favorites', favorites.toList());
    _syncFavoriteQueue();
  }

  /// 部分筛选结果排序时，只替换这些收藏原来占据的位置，隐藏项不乱序。
  Future<void> reorderFavorites(
    List<String> visibleIds,
    int oldIndex,
    int newIndex,
  ) async {
    final visible = [...visibleIds];
    if (oldIndex < 0 ||
        oldIndex >= visible.length ||
        newIndex < 0 ||
        newIndex >= visible.length) {
      return;
    }

    visible.insert(newIndex, visible.removeAt(oldIndex));
    final visibleSet = visibleIds.toSet();
    var cursor = 0;
    final ordered = [
      for (final id in state.favorites)
        if (visibleSet.contains(id)) visible[cursor++] else id,
    ];
    state = LibraryState(
      favorites: List.unmodifiable(ordered),
      recent: state.recent,
      query: state.query,
      region: state.region,
      tab: state.tab,
    );
    _syncFavoriteQueue();
    await ref.read(preferencesProvider).setStringList('favorites', ordered);
  }

  void _syncFavoriteQueue() {
    final catalog = ref.read(catalogProvider).asData?.value ?? <Station>[];
    final byId = {for (final s in catalog) s.id: s};
    ref.read(radioProvider).updateFavoriteQueue([
      for (final id in state.favorites)
        if (byId.containsKey(id)) byId[id]!,
    ]);
  }
}

final filteredStationsProvider = Provider<List<Station>>((ref) {
  final all = ref.watch(catalogProvider).asData?.value ?? [];
  final library = ref.watch(libraryProvider);
  final stations = all
      .where(
        (s) =>
            s.matches(library.query) &&
            (library.region == '全部' || s.region == library.region) &&
            (library.tab != 1 || library.favorites.contains(s.id)) &&
            (library.tab != 2 || library.recent.contains(s.id)),
      )
      .toList();
  if (library.tab == 1) {
    stations.sort(
      (a, b) => library.favorites
          .indexOf(a.id)
          .compareTo(library.favorites.indexOf(b.id)),
    );
  } else if (library.tab == 2) {
    stations.sort(
      (a, b) =>
          library.recent.indexOf(a.id).compareTo(library.recent.indexOf(b.id)),
    );
  }
  return stations;
});

/// 监听网络变化只是加快恢复；真正可用与否仍由播放器连接结果决定。
final connectivityProvider = Provider<void>((ref) {
  final subscription = Connectivity().onConnectivityChanged.listen((results) {
    if (results.any((r) => r != ConnectivityResult.none)) {
      ref.read(radioProvider).networkAvailable();
    }
  });
  ref.onDispose(subscription.cancel);
});
