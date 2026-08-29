// 品牌主题 —— 对应小程序 app.wxss 主题变量
// 温和医疗简约风（浅蓝 + 薄荷绿）

import 'package:flutter/material.dart';

class AppColors {
  static const Color brandBlue = Color(0xFF4A9FE8);
  static const Color brandBlueDeep = Color(0xFF3A8CD6);
  static const Color brandMint = Color(0xFF3EB489);
  static const Color brandBlueBg = Color(0xFFEAF4FB);
  static const Color brandMintBg = Color(0xFFE8F7F1);
  static const Color brandBg = Color(0xFFF4F9FC);
  static const Color brandText = Color(0xFF2E3B47);
  static const Color brandTextSub = Color(0xFF8A9BAD);
  static const Color brandBorder = Color(0xFFE6EEF5);
  static const Color brandDanger = Color(0xFFF56C6C);
  static const Color brandWarning = Color(0xFFF5A05F);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brandBlue,
    primary: AppColors.brandBlue,
    secondary: AppColors.brandMint,
    error: AppColors.brandDanger,
    surface: Colors.white,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.brandBg,
    fontFamily: null,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.brandBg,
      foregroundColor: AppColors.brandText,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.brandText,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: TextStyle(color: Color(0xFFB9C6D2)),
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
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}
