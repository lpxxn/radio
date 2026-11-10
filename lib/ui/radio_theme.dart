import 'package:flutter/material.dart';
import 'radio_skin.dart';

class RadioPalette {
  const RadioPalette(this.background, this.accent, this.art, this.ink);
  final Color background, accent, art, ink;
  static RadioPalette of(RadioSkin skin) => switch (skin) {
    RadioSkin.walnut => const RadioPalette(
      Color(0xFFF8F6F2),
      Color(0xFFD96145),
      Color(0xFFECC3A7),
      Color(0xFF292C30),
    ),
    RadioSkin.midnight => const RadioPalette(
      Color(0xFFF2F5FA),
      Color(0xFF506EC4),
      Color(0xFFB9C8E9),
      Color(0xFF252E43),
    ),
    RadioSkin.forest => const RadioPalette(
      Color(0xFFF3F6F1),
      Color(0xFF447964),
      Color(0xFFBDCFB3),
      Color(0xFF273A32),
    ),
  };
}

ThemeData radioTheme(RadioSkin skin) {
  final palette = RadioPalette.of(skin);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: palette.background,
    // 内置开源字体，避免厂商主题的手写字体改变布局和文字层级。
    fontFamily: 'RadioSans',
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.accent,
      primary: palette.accent,
      surface: palette.background,
      onSurface: palette.ink,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.background,
      showDragHandle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      isDense: true,
    ),
  );
}
