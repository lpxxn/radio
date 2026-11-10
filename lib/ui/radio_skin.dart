import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../platform/startup_appearance.dart';

/// 皮肤只管理视觉，不影响播放。新增皮肤在枚举中补充颜色即可。
enum RadioSkin {
  walnut('胡桃木', Color(0xFF171512), Color(0xFF24211C), Color(0xFF25211D), [
    Color(0xFF916B46),
    Color(0xFF48301F),
    Color(0xFF765132),
  ]),
  midnight('午夜蓝', Color(0xFF101822), Color(0xFF1B2A3B), Color(0xFF172536), [
    Color(0xFF65869E),
    Color(0xFF233A52),
    Color(0xFF385974),
  ]),
  forest('森林绿', Color(0xFF111C18), Color(0xFF20332B), Color(0xFF1C2C24), [
    Color(0xFF7F9972),
    Color(0xFF304A38),
    Color(0xFF4B6750),
  ]);

  const RadioSkin(
    this.label,
    this.background,
    this.panel,
    this.receiver,
    this.frame,
  );
  final String label;
  final Color background, panel, receiver;
  final List<Color> frame;
}

final skinProvider = NotifierProvider<SkinNotifier, RadioSkin>(
  SkinNotifier.new,
);

class SkinNotifier extends Notifier<RadioSkin> {
  @override
  RadioSkin build() {
    final name = ref.watch(preferencesProvider).getString('skin');
    return RadioSkin.values.where((s) => s.name == name).firstOrNull ??
        RadioSkin.walnut;
  }

  Future<void> select(RadioSkin skin) async {
    state = skin;
    await ref.read(preferencesProvider).setString('skin', skin.name);
    await StartupAppearance.apply(skin.name);
  }
}
