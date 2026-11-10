import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/radio_handler.dart';
import '../providers.dart';
import '../platform/desktop_window.dart';
import 'radio_artwork.dart';
import 'radio_skin.dart';
import 'radio_theme.dart';

/// 桌面在宽窗口内并排展示播放器和资料库，窄窗口保留完整播放操作。
/// 只读取共享状态和发命令，换台范围与手机/媒体键完全一致。
class DesktopRadioPlayer extends ConsumerWidget {
  const DesktopRadioPlayer({
    super.key,
    required this.playback,
    required this.library,
    required this.onBrowse,
    required this.onAbout,
    required this.onExit,
    required this.onSleep,
  });
  final RadioSnapshot playback;
  final Widget library;
  final VoidCallback onBrowse, onAbout, onExit, onSleep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinProvider);
    final palette = RadioPalette.of(skin);
    final handler = ref.read(radioProvider);
    final libraryState = ref.watch(libraryProvider);
    final favorite = libraryState.favorites.contains(playback.station?.id);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        key: const ValueKey('radio-surface'),
        color: palette.background,
        child: LayoutBuilder(
          builder: (context, size) {
            final wide = size.maxWidth >= 900 && size.maxHeight >= 560;
            final sidebar = size.maxWidth >= 1120 && size.maxHeight >= 600;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          color: palette.accent,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (size.maxWidth >= 480)
                        Text(
                          '时光收音机',
                          style: TextStyle(
                            color: palette.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const Expanded(
                        child: WindowDragArea(child: SizedBox(height: 40)),
                      ),
                      PopupMenuButton<String>(
                        tooltip: '收音机菜单',
                        icon: Icon(
                          Icons.palette_outlined,
                          color: palette.accent,
                          size: 21,
                        ),
                        onSelected: (action) {
                          if (action == 'about') {
                            onAbout();
                          } else {
                            ref
                                .read(skinProvider.notifier)
                                .select(RadioSkin.values.byName(action));
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            enabled: false,
                            child: Text('更换配色'),
                          ),
                          for (final (option, name) in [
                            (RadioSkin.walnut, '暖日珊瑚'),
                            (RadioSkin.midnight, '晴空蓝'),
                            (RadioSkin.forest, '松间绿'),
                          ])
                            PopupMenuItem(
                              value: option.name,
                              child: Row(
                                children: [
                                  Icon(
                                    option == skin
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    color: RadioPalette.of(option).accent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(name),
                                ],
                              ),
                            ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'about',
                            child: Text('关于与使用说明'),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: '最小化',
                        onPressed: DesktopWindow.minimize,
                        icon: const Icon(Icons.remove_rounded, size: 19),
                      ),
                      IconButton(
                        tooltip: '最大化或还原',
                        onPressed: DesktopWindow.toggleMaximize,
                        icon: const Icon(Icons.crop_square_rounded, size: 17),
                      ),
                      IconButton(
                        tooltip: '退出',
                        onPressed: onExit,
                        style: IconButton.styleFrom(
                          hoverColor: const Color(0xFFFBE2DD),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(sidebar ? 20 : 24, 12, 24, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (sidebar) ...[
                          SizedBox(
                            width: 158,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(12, 16, 0, 18),
                                  child: Text(
                                    '声音资料库',
                                    style: TextStyle(
                                      color: Color(0xFF85898B),
                                      fontSize: 11,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                for (final (tab, label, icon) in [
                                  (0, '发现电台', Icons.explore_outlined),
                                  (1, '我的收藏', Icons.favorite_border_rounded),
                                  (2, '最近收听', Icons.history_rounded),
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: TextButton.icon(
                                      onPressed: () => ref
                                          .read(libraryProvider.notifier)
                                          .filter(
                                            tab: tab,
                                            query: '',
                                            region: '全部',
                                          ),
                                      style: TextButton.styleFrom(
                                        alignment: Alignment.centerLeft,
                                        foregroundColor: libraryState.tab == tab
                                            ? palette.accent
                                            : const Color(0xFF767C7D),
                                        backgroundColor: libraryState.tab == tab
                                            ? palette.accent.withValues(
                                                alpha: .09,
                                              )
                                            : Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(icon, size: 19),
                                      label: Text(
                                        label,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    '日常有声\n时光有伴',
                                    style: TextStyle(
                                      color: palette.accent.withValues(
                                        alpha: .65,
                                      ),
                                      fontSize: 18,
                                      height: 1.7,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                        ],
                        Expanded(
                          flex: 5,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: LayoutBuilder(
                              builder: (context, panel) {
                                final compact =
                                    panel.maxHeight < 620 &&
                                    panel.maxWidth >= 420;
                                final art = math.min(
                                  panel.maxWidth - 64,
                                  compact
                                      ? (panel.maxHeight * .27).clamp(
                                          96.0,
                                          140.0,
                                        )
                                      : (panel.maxHeight * .34).clamp(
                                          104.0,
                                          248.0,
                                        ),
                                );
                                return SingleChildScrollView(
                                  child: Padding(
                                    padding: EdgeInsets.all(compact ? 16 : 24),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                '正在收听',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF85898B),
                                                ),
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: onBrowse,
                                              icon: const Icon(
                                                Icons.queue_music_rounded,
                                                size: 17,
                                              ),
                                              label: const Text(
                                                '选台',
                                                style: TextStyle(fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        if (compact)
                                          Row(
                                            children: [
                                              _DesktopCover(
                                                palette: palette,
                                                art: art,
                                              ),
                                              const SizedBox(width: 24),
                                              Expanded(
                                                child: _StationInfo(
                                                  playback: playback,
                                                  palette: palette,
                                                  compact: true,
                                                ),
                                              ),
                                            ],
                                          )
                                        else ...[
                                          _DesktopCover(
                                            palette: palette,
                                            art: art,
                                          ),
                                          const SizedBox(height: 24),
                                          _StationInfo(
                                            playback: playback,
                                            palette: palette,
                                          ),
                                        ],
                                        const SizedBox(height: 18),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              tooltip: '上一台',
                                              onPressed: handler.skipToPrevious,
                                              icon: const Icon(
                                                Icons.skip_previous_rounded,
                                                size: 32,
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            Tooltip(
                                              message: playback.wantPlay
                                                  ? '暂停'
                                                  : '播放',
                                              child: Material(
                                                color: palette.accent,
                                                shape: const CircleBorder(),
                                                child: InkWell(
                                                  customBorder:
                                                      const CircleBorder(),
                                                  onTap: handler.toggle,
                                                  child: SizedBox.square(
                                                    dimension: compact
                                                        ? 60
                                                        : 68,
                                                    child: Icon(
                                                      playback.wantPlay
                                                          ? Icons.pause_rounded
                                                          : Icons
                                                                .play_arrow_rounded,
                                                      color: Colors.white,
                                                      size: 38,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            IconButton(
                                              tooltip: '下一台',
                                              onPressed: handler.skipToNext,
                                              icon: const Icon(
                                                Icons.skip_next_rounded,
                                                size: 32,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 12,
                                          children: [
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                minimumSize: const Size(0, 32),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              onPressed: () {
                                                final id = playback.station?.id;
                                                if (id != null) {
                                                  ref
                                                      .read(
                                                        libraryProvider
                                                            .notifier,
                                                      )
                                                      .favorite(id);
                                                }
                                              },
                                              icon: Icon(
                                                favorite
                                                    ? Icons.favorite_rounded
                                                    : Icons
                                                          .favorite_border_rounded,
                                                size: 18,
                                              ),
                                              label: Text(
                                                favorite ? '已收藏' : '收藏',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                minimumSize: const Size(0, 32),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              onPressed: handler.random,
                                              icon: const Icon(
                                                Icons.shuffle_rounded,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                '随便听',
                                                style: TextStyle(fontSize: 11),
                                              ),
                                            ),
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                minimumSize: const Size(0, 32),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              onPressed: onSleep,
                                              icon: const Icon(
                                                Icons.bedtime_outlined,
                                                size: 18,
                                              ),
                                              label: Text(
                                                playback.sleepAt == null
                                                    ? '睡眠定时'
                                                    : '定时中',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: palette.background,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.repeat_rounded,
                                                color: palette.accent,
                                                size: 17,
                                              ),
                                              const SizedBox(width: 9),
                                              Expanded(
                                                child: Text(
                                                  '换台范围：${playback.queueLabel} · ${playback.queueLength} 台',
                                                  maxLines: 2,
                                                  style: const TextStyle(
                                                    color: Color(0xFF767C7D),
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        if (wide) ...[
                          const SizedBox(width: 20),
                          Expanded(flex: 5, child: library),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 0, 24, 14),
                  child: Row(
                    children: [
                      Icon(
                        playback.phase == RadioPhase.playing
                            ? Icons.graphic_eq_rounded
                            : Icons.radio_outlined,
                        color: palette.accent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          playback.wantPlay
                              ? '直播缓冲 ${playback.buffer.inSeconds}s'
                              : '好声音，随时继续',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF85898B),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.volume_down_rounded,
                        size: 20,
                        color: Color(0xFF85898B),
                      ),
                      SizedBox(
                        width: size.maxWidth < 600 ? 100 : 132,
                        child: Slider(
                          value: playback.volume,
                          onChanged: handler.volume,
                          onChangeEnd: (value) => ref
                              .read(preferencesProvider)
                              .setDouble('volume', value),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${(playback.volume * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF85898B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DesktopCover extends StatelessWidget {
  const _DesktopCover({required this.palette, required this.art});
  final RadioPalette palette;
  final double art;
  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox.square(
      dimension: art,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: .16),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: CustomPaint(
            painter: RadioArtwork(palette),
            child: Padding(
              padding: EdgeInsets.all(art * .1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SHIGUANG',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: art * .045,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '好声音\n一直在',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: art * .125,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _StationInfo extends StatelessWidget {
  const _StationInfo({
    required this.playback,
    required this.palette,
    this.compact = false,
  });
  final RadioSnapshot playback;
  final RadioPalette palette;
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        playback.station?.name ?? '让喜欢的声音，陪着你',
        textAlign: compact ? TextAlign.left : TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 22 : 25,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: palette.ink,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        playback.station == null
            ? '从一座城市，听见一种生活'
            : '${playback.station!.region}  ·  ${playback.station!.category}',
        textAlign: compact ? TextAlign.left : TextAlign.center,
        style: const TextStyle(color: Color(0xFF85898B), fontSize: 12),
      ),
      const SizedBox(height: 12),
      Text(
        playback.message,
        textAlign: compact ? TextAlign.left : TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: playback.wantPlay ? palette.accent : const Color(0xFF85898B),
        ),
      ),
    ],
  );
}
