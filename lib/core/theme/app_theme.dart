import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 深色主题主色：青绿偏深
  static const Color darkPrimary = Color(0xFF4FB3A9);
  static const Color darkOnPrimary = Color(0xFFFFFFFF);
  static const Color darkPrimaryContainer = Color(0xFF1F3A36);
  static const Color darkOnPrimaryContainer = Color(0xFFE6F5F2);

  // 浅色主题主色：暖青
  static const Color lightPrimary = Color(0xFF0E7C76);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFB6DFDB);
  static const Color lightOnPrimaryContainer = Color(0xFF043633);

  // 常规颜色
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color lightSurface = Color(0xFFF5F5F5);
}

class AppThemes {
  AppThemes._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.lightPrimary,
        onPrimary: AppColors.lightOnPrimary,
        primaryContainer: AppColors.lightPrimaryContainer,
        onPrimaryContainer: AppColors.lightOnPrimaryContainer,
        surface: AppColors.lightSurface,
        onSurface: Colors.black,
        surfaceContainerHighest: Colors.grey.shade200,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedIconTheme: const IconThemeData(color: AppColors.lightPrimary),
        unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
        selectedLabelTextStyle: TextStyle(color: AppColors.lightPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.lightPrimary,
        unselectedItemColor: Colors.grey,
      ),
      scaffoldBackgroundColor: AppColors.lightSurface,
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: AppColors.darkPrimary,
        onPrimary: AppColors.darkOnPrimary,
        primaryContainer: AppColors.darkPrimaryContainer,
        onPrimaryContainer: AppColors.darkOnPrimaryContainer,
        surface: AppColors.darkSurface,
        onSurface: Colors.white,
        surfaceContainerHighest: Colors.grey.shade800,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF2A2A2A),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedIconTheme: const IconThemeData(color: AppColors.darkPrimary),
        unselectedIconTheme: IconThemeData(color: Colors.grey.shade400),
        selectedLabelTextStyle: TextStyle(color: AppColors.darkPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.darkPrimary,
        unselectedItemColor: Colors.grey.shade400,
      ),
      scaffoldBackgroundColor: AppColors.darkSurface,
    );
  }
}
