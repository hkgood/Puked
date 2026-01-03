import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/services/pocketbase_service.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});

enum SensitivityLevel { low, medium, high }

class SettingsState {
  final ThemeMode themeMode;
  final Locale? locale;
  final SensitivityLevel sensitivity;
  final String? brand;
  final String? carModel;
  final String? softwareVersion;
  final bool isFirstLaunch;

  SettingsState({
    required this.themeMode,
    this.locale,
    this.sensitivity = SensitivityLevel.high,
    this.brand,
    this.carModel,
    this.softwareVersion,
    this.isFirstLaunch = false,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    SensitivityLevel? sensitivity,
    String? brand,
    String? carModel,
    String? softwareVersion,
    bool? isFirstLaunch,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      sensitivity: sensitivity ?? this.sensitivity,
      brand: brand ?? this.brand,
      carModel: carModel ?? this.carModel,
      softwareVersion: softwareVersion ?? this.softwareVersion,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;
  SettingsNotifier(this._ref)
      : super(SettingsState(
          themeMode: ThemeMode.system,
          locale: _getInitialLocale(),
        )) {
    _loadSettings();

    // 监听登录状态变化，自动刷新设置
    _ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated == false && next.isAuthenticated) {
        // 仅在从“未登录”变为“已登录”时自动刷新
        _loadSettings();
      }
    });
  }

  static Locale _getInitialLocale() {
    // 初始值探测：非中即英
    final systemLanguageCode =
        PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return systemLanguageCode == 'zh' ? const Locale('zh') : const Locale('en');
  }

  static const _themeKey = 'theme_mode';
  static const _localeKey = 'locale_code';
  static const _sensitivityKey = 'sensitivity_level';
  static const _brandKey = 'default_brand';
  static const _carModelKey = 'default_car_model';
  static const _softwareVersionKey = 'default_software_version';
  static const _firstLaunchKey = 'is_first_launch';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 加载首次启动标志，默认 true
    final isFirstLaunch = prefs.getBool(_firstLaunchKey) ?? true;

    // 加载主题
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.system.index;
    final themeMode = ThemeMode.values[themeIndex];

    // 加载语言
    final localeCode = prefs.getString(_localeKey);
    Locale? locale;
    if (localeCode != null) {
      locale = Locale(localeCode);
    } else {
      // 首次打开：使用初始探测逻辑
      locale = _getInitialLocale();
    }

    // 加载敏感度
    final sensitivityIndex =
        prefs.getInt(_sensitivityKey) ?? SensitivityLevel.high.index;
    final sensitivity = SensitivityLevel.values[sensitivityIndex];

    // 加载品牌和车型
    String? brand = prefs.getString(_brandKey);
    String? carModel = prefs.getString(_carModelKey);
    String? softwareVersion = prefs.getString(_softwareVersionKey);

    // 如果已登录，优先从账号信息加载
    final auth = _ref.read(authProvider);
    if (auth.isAuthenticated) {
      brand = auth.user?.getStringValue('brand').isEmpty == false
          ? auth.user?.getStringValue('brand')
          : brand;
      carModel = auth.user?.getStringValue('car_model').isEmpty == false
          ? auth.user?.getStringValue('car_model')
          : carModel;
      softwareVersion =
          auth.user?.getStringValue('software_version').isEmpty == false
              ? auth.user?.getStringValue('software_version')
              : softwareVersion;
    }

    state = SettingsState(
      themeMode: themeMode,
      locale: locale,
      sensitivity: sensitivity,
      brand: brand,
      carModel: carModel,
      softwareVersion: softwareVersion,
      isFirstLaunch: isFirstLaunch,
    );
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(isFirstLaunch: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
  }

  Future<void> _syncToPocketBase() async {
    final auth = _ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    try {
      final pb = _ref.read(pbServiceProvider).pb;
      await pb.collection('users').update(auth.user!.id, body: {
        'brand': state.brand ?? '',
        'car_model': state.carModel ?? '',
        'software_version': state.softwareVersion ?? '',
      });
      // 更新本地 auth 状态
      await _ref.read(authProvider.notifier).refreshUserFromServer();
    } catch (e) {
      debugPrint('Failed to sync vehicle settings to PocketBase: $e');
    }
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

  Future<void> setVehicleInfo(
      {String? brand, String? model, String? version}) async {
    state = state.copyWith(
      brand: brand,
      carModel: model,
      softwareVersion: version,
    );

    final prefs = await SharedPreferences.getInstance();
    if (brand != null) await prefs.setString(_brandKey, brand);
    if (model != null) await prefs.setString(_carModelKey, model);
    if (version != null) await prefs.setString(_softwareVersionKey, version);

    await _syncToPocketBase();
  }

  Future<void> clearVehicleSettings() async {
    state = state.copyWith(
      brand: null,
      carModel: null,
      softwareVersion: null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_brandKey);
    await prefs.remove(_carModelKey);
    await prefs.remove(_softwareVersionKey);
  }

  @Deprecated('Use setVehicleInfo instead')
  Future<void> setBrand(String? brand) async {
    await setVehicleInfo(brand: brand);
  }

  @Deprecated('Use setVehicleInfo instead')
  Future<void> setCarModel(String? model) async {
    await setVehicleInfo(model: model);
  }
}
