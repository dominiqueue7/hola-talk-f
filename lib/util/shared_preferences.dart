import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreferences {
  static const String prefKey = "theme_mode";

  setThemeMode(ThemeMode themeMode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt(prefKey, themeMode.index);
  }

  Future<ThemeMode> getThemeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int index = prefs.getInt(prefKey) ?? ThemeMode.system.index;
    return ThemeMode.values[index];
  }
}
