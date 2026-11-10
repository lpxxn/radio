import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

const muted = Color(0xFF85898B);

class StationLibrary extends ConsumerWidget {
  const StationLibrary({
    required this.refreshing,
    required this.onRefresh,
    this.onSelected,
    this.embedded = false,
    super.key,
  });
  final bool refreshing, embedded;
  final VoidCallback onRefresh;
  final VoidCallback? onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    const secondary = muted;
    final all = ref.watch(catalogProvider);
    final stations = ref.watch(filteredStationsProvider);
    final current = ref.watch(playbackProvider).asData?.value.station?.id;
    final regions = [
      '全部',
      ...{...all.asData?.value.map((s) => s.region) ?? <String>[]},
    ];
    Widget buildStation(BuildContext context, int i) {
      final station = stations[i];
      final selected = station.id == current;
      return Material(
        key: ValueKey(station.id),
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          selected: selected,
          selectedTileColor: accent.withValues(alpha: .08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              station.frequency == '--' ? 'FM' : station.frequency,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            station.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13),
          ),
          subtitle: Text(
            '${station.region} · ${station.category}',
            style: TextStyle(color: secondary, fontSize: 11),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (library.tab == 1)
                ReorderableDragStartListener(
                  index: i,
                  child: Tooltip(
                    message: '拖动调整收藏顺序',
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.drag_handle,
                        size: 20,
                        color: secondary,
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: library.favorites.contains(station.id)
                    ? '取消收藏'
                    : '收藏电台',
                icon: Icon(
                  library.favorites.contains(station.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  size: 18,
                  color: library.favorites.contains(station.id)
                      ? accent
                      : secondary,
                ),
                onPressed: () =>
                    ref.read(libraryProvider.notifier).favorite(station.id),
              ),
            ],
          ),
          onTap: () {
            ref
                .read(radioProvider)
                .selectFromList(
                  station,
                  stations,
                  label: library.tab == 1
                      ? '我的收藏'
                      : library.tab == 2
                      ? '最近收听'
                      : library.query.isNotEmpty
                      ? '${library.region} · 搜索结果'
                      : library.region == '全部'
                      ? '全部电台'
                      : library.region,
                  favorites: library.tab == 1,
                );
            onSelected?.call();
          },
        ),
      );
    }

    final stationList = all.isLoading
        ? const Center(child: CircularProgressIndicator())
        : stations.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radio_outlined, color: secondary, size: 36),
                const SizedBox(height: 12),
                Text(
                  library.tab == 1
                      ? '还没有收藏，点亮喜欢电台的爱心吧'
                      : library.tab == 2
                      ? '还没有收听记录'
                      : '没有找到电台，试试其他关键词',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondary, fontSize: 12),
                ),
              ],
            ),
          )
        : library.tab == 1
        ? ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: stations.length,
            onReorderItem: (oldIndex, newIndex) => ref
                .read(libraryProvider.notifier)
                .reorderFavorites(
                  stations.map((s) => s.id).toList(),
                  oldIndex,
                  newIndex,
                ),
            itemBuilder: buildStation,
          )
        : ListView.separated(
            itemCount: stations.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: const Color(0xFFEAECE8)),
            itemBuilder: buildStation,
          );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: embedded ? Colors.white : scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '寻找你的频率',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                tooltip: '刷新国内电台目录',
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh, size: 20, color: secondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (index, name, icon) in [
                (0, '全部', Icons.radio),
                (1, '收藏', Icons.favorite_border),
                (2, '最近', Icons.history),
              ])
                Expanded(
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.read(libraryProvider.notifier).filter(tab: index),
                    style: TextButton.styleFrom(
                      backgroundColor: library.tab == index
                          ? accent.withValues(alpha: .10)
                          : Colors.transparent,
                      foregroundColor: library.tab == index
                          ? accent
                          : secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: Icon(icon, size: 16),
                    label: Text(name),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: ValueKey('search-${library.tab}-${library.region}'),
            initialValue: library.query,
            onChanged: (q) =>
                ref.read(libraryProvider.notifier).filter(query: q),
            decoration: const InputDecoration(
              hintText: '搜索台名、地区、频率…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: regions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, i) => ChoiceChip(
                label: Text(regions[i], style: TextStyle(fontSize: 11)),
                selected: library.region == regions[i],
                showCheckmark: false,
                onSelected: (_) => ref
                    .read(libraryProvider.notifier)
                    .filter(region: regions[i]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${stations.length} 个电台  /  找到此刻的陪伴',
            style: TextStyle(color: secondary, fontSize: 11),
          ),
          if (library.tab == 1)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '拖动右侧手柄调整收藏顺序',
                style: TextStyle(color: secondary, fontSize: 11),
              ),
            ),
          const SizedBox(height: 8),
          if (embedded)
            Expanded(child: stationList)
          else
            SizedBox(
              height: mobile
                  ? (MediaQuery.sizeOf(context).height * .42).clamp(
                      180.0,
                      400.0,
                    )
                  : 360,
              child: stationList,
            ),
          const SizedBox(height: 8),
          Text(
            '内置央广 · 在线目录 Radio Browser',
            style: TextStyle(color: secondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
