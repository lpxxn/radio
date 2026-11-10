import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/radio_handler.dart';
import '../providers.dart';
import 'radio_skin.dart';
import 'radio_theme.dart';
import 'radio_artwork.dart';

/// 手机拥有独立的视觉层，继续共用 Riverpod 和 RadioHandler。
/// 不绘制桌面机身或模拟频率刻度；直播也不显示可拖动的进度条。
class MobileRadioPlayer extends ConsumerWidget {
  const MobileRadioPlayer({
    super.key,
    required this.playback,
    required this.onBrowse,
    required this.onFavorites,
    required this.onAbout,
    required this.onExit,
    required this.onSleep,
  });
  final RadioSnapshot playback;
  final VoidCallback onBrowse, onFavorites, onAbout, onExit, onSleep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinProvider);
    final colors = RadioPalette.of(skin);
    final handler = ref.read(radioProvider);
    final favorite = ref
        .watch(libraryProvider)
        .favorites
        .contains(playback.station?.id);
    final padding = MediaQuery.viewPaddingOf(context);
    final busy = [
      RadioPhase.connecting,
      RadioPhase.buffering,
      RadioPhase.retrying,
    ].contains(playback.phase);
    final playing = playback.phase == RadioPhase.playing;
    return ColoredBox(
      key: const ValueKey('radio-surface'),
      color: colors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 安全区域只留在内容层，背景仍然延伸到挖孔、状态栏和手势区。
          final top = math.max(48.0, padding.top + 18);
          final bottom = math.max(24.0, padding.bottom + 12);
          final artSize = (constraints.maxHeight * .24).clamp(160.0, 232.0);
          return Padding(
            padding: EdgeInsets.only(top: top, bottom: bottom),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              Icons.graphic_eq_rounded,
                              color: colors.accent,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '时光收音机',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: colors.ink,
                                  ),
                                ),
                                const Text(
                                  '日常有声，时光有伴',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF85898B),
                                    height: 1.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: '收音机菜单',
                            icon: const Icon(Icons.more_horiz_rounded),
                            onSelected: (action) {
                              if (action == 'about') {
                                onAbout();
                                return;
                              }
                              ref
                                  .read(skinProvider.notifier)
                                  .select(RadioSkin.values.byName(action));
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem<String>(
                                enabled: false,
                                child: Text('更换配色'),
                              ),
                              for (final (option, label) in [
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
                                        size: 18,
                                        color: RadioPalette.of(option).accent,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(label),
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
                            tooltip: '退出',
                            onPressed: onExit,
                            icon: const Icon(
                              Icons.power_settings_new_rounded,
                              size: 21,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          primary: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 30),
                              Center(
                                child: SizedBox.square(
                                  dimension: artSize,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.accent.withValues(
                                            alpha: .16,
                                          ),
                                          blurRadius: 32,
                                          offset: const Offset(0, 14),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(32),
                                      child: CustomPaint(
                                        painter: RadioArtwork(colors),
                                        child: Padding(
                                          padding: const EdgeInsets.all(22),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'SHIGUANG',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  letterSpacing: 3,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const Spacer(),
                                              const Text(
                                                '好声音\n一直在',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: playing
                                          ? colors.accent
                                          : const Color(0xFFA5A9A8),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    playing
                                        ? '正在直播'
                                        : playback.station == null
                                        ? '发现你的下一份喜欢'
                                        : '上次收听',
                                    style: TextStyle(
                                      color: colors.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                playback.station?.name ?? '让喜欢的声音，陪着你',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  color: colors.ink,
                                  height: 1.3,
                                  letterSpacing: -.5,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                playback.station == null
                                    ? '从一座城市，听见一种生活'
                                    : '${playback.station!.region}  ·  ${playback.station!.category}${playback.station!.frequency == '--' ? '' : '  ·  FM ${playback.station!.frequency}'}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF85898B),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (busy) ...[
                                    SizedBox.square(
                                      dimension: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: colors.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Text(
                                      playback.message,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF85898B),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    tooltip: '上一台',
                                    iconSize: 34,
                                    padding: const EdgeInsets.all(14),
                                    onPressed: handler.skipToPrevious,
                                    icon: const Icon(
                                      Icons.skip_previous_rounded,
                                    ),
                                  ),
                                  Semantics(
                                    button: true,
                                    label: playback.wantPlay ? '暂停' : '播放',
                                    child: Tooltip(
                                      message: playback.wantPlay ? '暂停' : '播放',
                                      child: Material(
                                        color: colors.accent,
                                        shape: const CircleBorder(),
                                        elevation: 0,
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: handler.toggle,
                                          child: SizedBox.square(
                                            dimension: 82,
                                            child: Icon(
                                              playback.wantPlay
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 44,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '下一台',
                                    iconSize: 34,
                                    padding: const EdgeInsets.all(14),
                                    onPressed: handler.skipToNext,
                                    icon: const Icon(Icons.skip_next_rounded),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _QuietAction(
                                    icon: favorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    label: favorite ? '已收藏' : '收藏',
                                    active: favorite,
                                    onTap: () {
                                      final id = playback.station?.id;
                                      if (id != null) {
                                        ref
                                            .read(libraryProvider.notifier)
                                            .favorite(id);
                                      }
                                    },
                                  ),
                                  _QuietAction(
                                    icon: Icons.shuffle_rounded,
                                    label: '随便听',
                                    onTap: handler.random,
                                  ),
                                  _QuietAction(
                                    icon: Icons.bedtime_outlined,
                                    label: playback.sleepAt == null
                                        ? '睡眠定时'
                                        : '${playback.sleepAt!.hour.toString().padLeft(2, '0')}:${playback.sleepAt!.minute.toString().padLeft(2, '0')} 停止',
                                    active: playback.sleepAt != null,
                                    onTap: onSleep,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Tooltip(
                                message: '选台',
                                child: Material(
                                  color: Colors.white.withValues(alpha: .85),
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: onBrowse,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 15,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.queue_music_rounded,
                                            color: colors.accent,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '选台 · ${playback.queueLabel}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  '${playback.queueLength} 个电台 · 按列表顺序换台',
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Color(0xFF85898B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: '我的收藏',
                                            onPressed: onFavorites,
                                            icon: const Icon(
                                              Icons.favorite_border_rounded,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuietAction extends StatelessWidget {
  const _QuietAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: active
          ? Theme.of(context).colorScheme.primary
          : const Color(0xFF6F7779),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 23),
        const SizedBox(height: 7),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    ),
  );
}
