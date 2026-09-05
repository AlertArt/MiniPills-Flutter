// 品牌主题 —— 对应小程序 app.wxss 主题变量
// 温和医疗简约风（浅蓝 + 薄荷绿），支持深色模式。

import 'package:flutter/material.dart';

class AppColors {
  // 品牌色（明暗通用）
  static const Color brandBlue = Color(0xFF4A9FE8);
  static const Color brandBlueDeep = Color(0xFF3A8CD6);
  static const Color brandMint = Color(0xFF3EB489);
  static const Color brandDanger = Color(0xFFF56C6C);
  static const Color brandWarning = Color(0xFFF5A05F);

  // 浅色模式语义色
  static const Color brandBlueBg = Color(0xFFEAF4FB);
  static const Color brandMintBg = Color(0xFFE8F7F1);
  static const Color brandBg = Color(0xFFF4F9FC);
  static const Color brandText = Color(0xFF2E3B47);
  static const Color brandTextSub = Color(0xFF8A9BAD);
  static const Color brandBorder = Color(0xFFE6EEF5);

  // 深色模式语义色
  static const Color darkBg = Color(0xFF10161E);
  static const Color darkCard = Color(0xFF1B2530);
  static const Color darkCardHi = Color(0xFF223042);
  static const Color darkText = Color(0xFFE6EDF4);
  static const Color darkTextSub = Color(0xFF8CA0B3);
  static const Color darkBorder = Color(0xFF2A3643);
}

/// 主题感知的语义色（页面统一经此获取，自动适配深色/浅色）
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// 页面背景
  Color get appBg => Theme.of(this).scaffoldBackgroundColor;

  /// 卡片/面板底色
  Color get appCard => Theme.of(this).colorScheme.surface;

  /// 主文字色
  Color get appText => Theme.of(this).colorScheme.onSurface;

  /// 次要文字色
  Color get appTextSub =>
      Theme.of(this).colorScheme.onSurfaceVariant.withValues(alpha: 0.85);

  /// 分割线/边框
  Color get appBorder => Theme.of(this).dividerColor;

  /// 输入框提示文字
  Color get appHint => Theme.of(this).hintColor;

  /// 浅蓝底（强调用）
  Color get appBlueBg =>
      isDark ? const Color(0xFF1C3750) : AppColors.brandBlueBg;

  /// 薄荷底（强调用）
  Color get appMintBg =>
      isDark ? const Color(0xFF173A30) : AppColors.brandMintBg;
}

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final bg = isDark ? AppColors.darkBg : AppColors.brandBg;
  final card = isDark ? AppColors.darkCard : Colors.white;
  final text = isDark ? AppColors.darkText : AppColors.brandText;
  final textSub = isDark ? AppColors.darkTextSub : AppColors.brandTextSub;
  final border = isDark ? AppColors.darkBorder : AppColors.brandBorder;
  final hint = isDark ? const Color(0xFF5D7083) : const Color(0xFFB9C6D2);

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brandBlue,
    brightness: brightness,
    primary: AppColors.brandBlue,
    secondary: AppColors.brandMint,
    error: AppColors.brandDanger,
    surface: card,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    fontFamily: null,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    dividerTheme: DividerThemeData(color: border),
    hintColor: hint,
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: TextStyle(color: hint),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: card),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF2A3643) : const Color(0xFF323D50),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
    ),
    listTileTheme: ListTileThemeData(textColor: text),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: text, fontSize: 16),
      bodyMedium: TextStyle(color: text, fontSize: 15),
      bodySmall: TextStyle(color: textSub, fontSize: 13),
      titleLarge: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );
}