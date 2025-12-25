import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

enum SensitivityLevel { low, medium, high }

class SettingsState {
  final ThemeMode themeMode;
  final Locale? locale;
  final SensitivityLevel sensitivity;

  SettingsState({
    required this.themeMode,
    this.locale,
    this.sensitivity = SensitivityLevel.low,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    SensitivityLevel? sensitivity,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      sensitivity: sensitivity ?? this.sensitivity,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState(themeMode: ThemeMode.system)) {
    _loadSettings();
  }

  static const _themeKey = 'theme_mode';
  static const _localeKey = 'locale_code';
  static const _sensitivityKey = 'sensitivity_level';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 加载主题
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.system.index;
    final themeMode = ThemeMode.values[themeIndex];

    // 加载语言
    final localeCode = prefs.getString(_localeKey);
    Locale? locale;
    if (localeCode != null) {
      locale = Locale(localeCode);
    }

    // 加载敏感度
    final sensitivityIndex =
        prefs.getInt(_sensitivityKey) ?? SensitivityLevel.low.index;
    final sensitivity = SensitivityLevel.values[sensitivityIndex];

    state = SettingsState(
      themeMode: themeMode,
      locale: locale,
      sensitivity: sensitivity,
    );
  }

  Future<void> setSensitivity(SensitivityLevel level) async {
    state = state.copyWith(sensitivity: level);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sensitivityKey, level.index);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  Future<void> setLocale(Locale? locale) async {
    state = state.copyWith(locale: locale);
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, locale.languageCode);
    }
  }
}
