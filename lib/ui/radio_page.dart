import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/radio_handler.dart';
import '../providers.dart';
import '../platform/app_exit.dart';
import '../platform/desktop_window.dart';

import 'mobile_radio_player.dart';
import 'station_library.dart';
import 'desktop_radio_player.dart';

const gold = Color(0xFFE4C68A);
const muted = Color(0xFFA99C86);

class RadioPage extends ConsumerStatefulWidget {
  const RadioPage({super.key});
  @override
  ConsumerState<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends ConsumerState<RadioPage> {
  bool _refreshing = false;
  final _panelKey = GlobalKey();
  void _syncWindowShape() {
    if (!DesktopWindow.supported) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _panelKey.currentContext?.findRenderObject();
      if (!mounted || box is! RenderBox || !box.hasSize) return;
      final bounds = Rect.fromPoints(
        box.localToGlobal(Offset.zero),
        box.localToGlobal(box.size.bottomRight(Offset.zero)),
      );
      DesktopWindow.shape(bounds, 20);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    ref.watch(connectivityProvider);
    ref.watch(catalogProvider);
    final playback =
        ref.watch(playbackProvider).asData?.value ??
        ref.read(radioProvider).snapshot;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
            ref.read(radioProvider).toggle(),
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () =>
            ref.read(radioProvider).skipToNext(),
        const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): () =>
            ref.read(radioProvider).skipToPrevious(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            top: !mobile,
            bottom: !mobile,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (mobile) {
                  return MobileRadioPlayer(
                    playback: playback,
                    onBrowse: _browse,
                    onFavorites: () {
                      ref
                          .read(libraryProvider.notifier)
                          .filter(tab: 1, region: '全部', query: '');
                      _browse();
                    },
                    onAbout: _about,
                    onExit: _exit,
                    onSleep: () => _showSleep(context, ref.read(radioProvider)),
                  );
                }
                _syncWindowShape();
                return DesktopRadioPlayer(
                  key: _panelKey,
                  playback: playback,
                  onBrowse: _browse,
                  onAbout: _about,
                  onExit: _exit,
                  onSleep: () => _showSleep(context, ref.read(radioProvider)),
                  library: StationLibrary(
                    embedded: true,
                    refreshing: _refreshing,
                    onRefresh: _refresh,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  bool _exiting = false;
  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    try {
      await ref.read(exitAppProvider)();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('退出失败：$error')));
      }
    } finally {
      _exiting = false;
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(catalogProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('国内电台目录已更新')));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _browse() {
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (mobile) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .86,
          child: _picker(sheetContext),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.sizeOf(context).height - 64,
          ),
          child: _picker(dialogContext),
        ),
      ),
    );
  }

  Widget _picker(BuildContext dialogContext) => StatefulBuilder(
    builder: (context, setDialogState) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 20),
            const Expanded(
              child: Text(
                '电台',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: '关闭选台窗口',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: StationLibrary(
              refreshing: _refreshing,
              onRefresh: () async {
                final future = _refresh();
                setDialogState(() {});
                await future;
                if (context.mounted) setDialogState(() {});
              },
              onSelected: () => Navigator.pop(dialogContext),
            ),
          ),
        ),
      ],
    ),
  );
  void _about() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('给声音一点时间'),
      content: const SingleChildScrollView(
        child: Text(
          '时光收音机 1.0\n\n点击电台即可收听。系统媒体键可切换上一台、下一台，换台顺序跟随选台时的列表，收藏可拖动排序。\n\n弱网时使用播放器内存缓冲；耗尽后自动重连。主动暂停、睡眠定时到点会取消重连。直播恢复后回到当前直播，不提供录音回放。\n\n内置央广电台，点击刷新可获取 Radio Browser 国内目录。电台链接可能变更或存在地域限制。\n\nICCOA CarLink：已实现标准 Android 媒体会话控制；完整车机接入仍需合作方要求与实车验证。\n\nWindows 支持窗口内媒体键；Android 支持后台通知栏与锁屏控制。',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

void _showSleep(BuildContext context, RadioHandler handler) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('伴你入眠', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 12),
              for (final minutes in [15, 30, 60, 90])
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: Text('$minutes 分钟后停止'),
                  onTap: () {
                    handler.sleep(Duration(minutes: minutes));
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                title: const Text('取消定时'),
                onTap: () {
                  handler.sleep(null);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
