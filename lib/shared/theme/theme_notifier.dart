import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState {
  final bool isDarkMode;
  final Color sidebarColor;
  final Color topBarColor;

  const ThemeState({
    required this.isDarkMode,
    required this.sidebarColor,
    required this.topBarColor,
  });

  ThemeState copyWith({
    bool? isDarkMode,
    Color? sidebarColor,
    Color? topBarColor,
  }) {
    return ThemeState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      sidebarColor: sidebarColor ?? this.sidebarColor,
      topBarColor: topBarColor ?? this.topBarColor,
    );
  }
}

class AppThemeNotifier extends ValueNotifier<ThemeState> {
  AppThemeNotifier() : super(const ThemeState(
    isDarkMode: false,
    sidebarColor: Color(0xFF0257E6),
    topBarColor: Colors.white,
  ));

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    final sidebarVal = prefs.getInt('sidebarColor') ?? 0xFF0257E6;
    final topBarVal = prefs.getInt('topBarColor') ?? 0xFFFFFFFF;
    
    value = ThemeState(
      isDarkMode: isDark,
      sidebarColor: Color(sidebarVal),
      topBarColor: Color(topBarVal),
    );
  }

  Future<void> updateTheme({bool? isDarkMode, Color? sidebarColor, Color? topBarColor}) async {
    value = value.copyWith(isDarkMode: isDarkMode, sidebarColor: sidebarColor, topBarColor: topBarColor);
    final prefs = await SharedPreferences.getInstance();
    if (isDarkMode != null) await prefs.setBool('isDarkMode', isDarkMode);
    if (sidebarColor != null) await prefs.setInt('sidebarColor', sidebarColor.value);
    if (topBarColor != null) await prefs.setInt('topBarColor', topBarColor.value);
  }
}

final themeNotifier = AppThemeNotifier();
