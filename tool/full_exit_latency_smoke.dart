// 完整应用的退出计时，不改变用户电台选择或播放意图。
// 原生退出开始/进程结束之间的时间由外部进程读取 build/full-exit-trace.log 测量。
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiguang_radio/main.dart' as app;
import 'package:shiguang_radio/providers.dart';
import 'package:shiguang_radio/ui/radio_page.dart';

void trace(String message) {
  final line = '${DateTime.now().millisecondsSinceEpoch} $message';
  File('build/full-exit-trace.log').writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  debugPrint(line);
}

Future<void> main() async {
  File('build/full-exit-trace.log').writeAsStringSync('');
  await app.main();
  await Future<void>.delayed(const Duration(seconds: 2));
  BuildContext? page;
  void findPage(Element element) {
    if (element.widget is RadioPage) page = element;
    element.visitChildren(findPage);
  }
  findPage(WidgetsBinding.instance.rootElement!);
  final handler = ProviderScope.containerOf(page!, listen: false).read(radioProvider);
  trace('full.close.begin phase=${handler.snapshot.phase}');
  handler.sleep(null);
  await handler.stop();
  trace('full.player.stopped');
  await handler.flushSession();
  trace('full.preferences.flushed');
  trace('full.native.exit.begin');
  await ServicesBinding.instance.exitApplication(ui.AppExitType.required);
  trace('full.native.exit.response');
}
