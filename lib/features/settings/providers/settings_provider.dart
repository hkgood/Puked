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
  final String? avatarPath; // 本地头像路径
  final String? nickname;   // 🟢 新增：本地昵称

  SettingsState({
    required this.themeMode,
    this.locale,
    this.sensitivity = SensitivityLevel.high,
    this.brand,
    this.carModel,
    this.softwareVersion,
    this.avatarPath,
    this.nickname, // 🟢 新增
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    SensitivityLevel? sensitivity,
    String? brand,
    String? carModel,
    String? softwareVersion,
    String? avatarPath,
    String? nickname, // 🟢 新增
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      sensitivity: sensitivity ?? this.sensitivity,
      brand: brand ?? this.brand,
      carModel: carModel ?? this.carModel,
      softwareVersion: softwareVersion ?? this.softwareVersion,
      avatarPath: avatarPath ?? this.avatarPath,
      nickname: nickname ?? this.nickname, // 🟢 新增
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;
  SettingsNotifier(this._ref)
      : super(SettingsState(themeMode: ThemeMode.system)) {
    _loadSettings();

    // 监听登录状态变化，自动刷新设置
    _ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated == false && next.isAuthenticated) {
        // 仅在从“未登录”变为“已登录”时自动刷新
        _loadSettings();
      }
    });
  }

  static const _themeKey = 'theme_mode';
  static const _localeKey = 'locale_code';
  static const _sensitivityKey = 'sensitivity_level';
  static const _brandKey = 'default_brand';
  static const _carModelKey = 'default_car_model';
  static const _softwareVersionKey = 'default_software_version';
  static const _avatarPathKey = 'local_avatar_path';
  static const _nicknameKey = 'local_nickname'; // 🟢 新增 Key

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
        prefs.getInt(_sensitivityKey) ?? SensitivityLevel.high.index;
    final sensitivity = SensitivityLevel.values[sensitivityIndex];

    // 加载品牌和车型
    String? brand = prefs.getString(_brandKey);
    String? carModel = prefs.getString(_carModelKey);
    String? softwareVersion = prefs.getString(_softwareVersionKey);
    
    // 加载本地头像
    String? avatarPath = prefs.getString(_avatarPathKey);
    
    // 🟢 加载本地昵称
    String? nickname = prefs.getString(_nicknameKey);

    // 如果已登录，优先从账号信息加载车辆信息（但不覆盖本地昵称）
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
      avatarPath: avatarPath,
      nickname: nickname, // 🟢 赋值
    );
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

  // 设置本地头像
  Future<void> setAvatarPath(String? path) async {
    state = SettingsState(
      themeMode: state.themeMode,
      locale: state.locale,
      sensitivity: state.sensitivity,
      brand: state.brand,
      carModel: state.carModel,
      softwareVersion: state.softwareVersion,
      avatarPath: path,
      nickname: state.nickname,
    );

    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString(_avatarPathKey, path);
    } else {
      await prefs.remove(_avatarPathKey);
    }
  }

  // 🟢 新增：设置本地昵称方法
  Future<void> setNickname(String? name) async {
    // 过滤空白字符，如果为空字符串则视为 null
    final validName = (name != null && name.trim().isEmpty) ? null : name?.trim();

    state = SettingsState(
      themeMode: state.themeMode,
      locale: state.locale,
      sensitivity: state.sensitivity,
      brand: state.brand,
      carModel: state.carModel,
      softwareVersion: state.softwareVersion,
      avatarPath: state.avatarPath,
      nickname: validName, // 更新状态
    );

    final prefs = await SharedPreferences.getInstance();
    if (validName != null) {
      await prefs.setString(_nicknameKey, validName);
    } else {
      await prefs.remove(_nicknameKey);
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
    // 构造新状态，这里我们保留用户偏好（昵称、头像），只清除车辆信息
    state = SettingsState(
      themeMode: state.themeMode,
      locale: state.locale,
      sensitivity: state.sensitivity,
      brand: null,
      carModel: null,
      softwareVersion: null,
      avatarPath: state.avatarPath, 
      nickname: state.nickname, 
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