import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/services/user_session_manager.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});

class SettingsState {
  final ThemeMode themeMode;
  final Locale? locale;
  final String? brand;
  final String? brandRef;
  final String? carModel;
  final String? softwareVersion;
  final String? softwareVersionRef;
  final bool isFirstLaunch;
  final bool isEventSoundEnabled;
  final bool isHighFrameRateEnabled;
  final bool isVideoRecordingEnabled;

  SettingsState({
    required this.themeMode,
    this.locale,
    this.brand,
    this.brandRef,
    this.carModel,
    this.softwareVersion,
    this.softwareVersionRef,
    this.isFirstLaunch = false,
    this.isEventSoundEnabled = false,
    this.isHighFrameRateEnabled = false,
    this.isVideoRecordingEnabled = false,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    String? brand,
    String? brandRef,
    String? carModel,
    String? softwareVersion,
    String? softwareVersionRef,
    bool? isFirstLaunch,
    bool? isEventSoundEnabled,
    bool? isHighFrameRateEnabled,
    bool? isVideoRecordingEnabled,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      brand: brand ?? this.brand,
      brandRef: brandRef ?? this.brandRef,
      carModel: carModel ?? this.carModel,
      softwareVersion: softwareVersion ?? this.softwareVersion,
      softwareVersionRef: softwareVersionRef ?? this.softwareVersionRef,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      isEventSoundEnabled: isEventSoundEnabled ?? this.isEventSoundEnabled,
      isHighFrameRateEnabled:
          isHighFrameRateEnabled ?? this.isHighFrameRateEnabled,
      isVideoRecordingEnabled:
          isVideoRecordingEnabled ?? this.isVideoRecordingEnabled,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;
  String? _lastLoadedUserDataHash; // 追踪上次加载的用户数据哈希值

  SettingsNotifier(this._ref)
      : super(SettingsState(
          themeMode: ThemeMode.system,
          locale: _getInitialLocale(),
        )) {
    _loadSettings();

    // 🔥 监听会话变更，而非直接监听authProvider
    // 这样可以避免在数据刷新时重复加载设置
    _ref.read(userSessionManagerProvider).sessionChanges.listen((event) {
      debugPrint('[Settings] Session event: $event');

      switch (event.type) {
        case SessionEventType.started:
        case SessionEventType.restored:
          // 新用户登录或会话恢复 - 加载该用户的设置
          _loadSettings();
          break;

        case SessionEventType.logout:
        case SessionEventType.switched:
          // 用户退出或切换 - 清理旧用户的设置
          _clearUserSpecificSettings();
          break;
      }
    });

    // 🔥 【新增】监听 authProvider 的用户数据变化
    // 当用户从服务器刷新数据后（如认证新车型、版本号），自动同步到本地设置
    _ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        // 只在用户已登录且用户数据发生实际变化时才重新加载
        if (next.isAuthenticated && next.user != null) {
          final currentHash = _getUserDataHash(next.user!);

          // 防止重复加载：只有当用户数据真正改变时才重新加载
          if (_lastLoadedUserDataHash != currentHash) {
            debugPrint('[Settings] User data changed, reloading settings...');
            _loadSettings();
          }
        }
      },
    );
  }

  /// 生成用户车辆相关数据的哈希值，用于检测变化
  String _getUserDataHash(dynamic user) {
    // 🔄 数据库迁移：优先使用 _ref 字段生成哈希
    final brandRef = user.getStringValue('brand_ref') ?? '';
    final softwareVersionRef =
        user.getStringValue('software_version_ref') ?? '';
    final carModel = user.getStringValue('car_model') ?? '';

    // 降级：如果 _ref 为空，使用旧字段
    final brand =
        brandRef.isEmpty ? (user.getStringValue('brand') ?? '') : brandRef;
    final softwareVersion = softwareVersionRef.isEmpty
        ? (user.getStringValue('software_version') ?? '')
        : softwareVersionRef;

    return '$brand|$carModel|$softwareVersion';
  }

  static Locale _getInitialLocale() {
    // 初始值探测：非中即英
    final systemLanguageCode =
        PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return systemLanguageCode == 'zh' ? const Locale('zh') : const Locale('en');
  }

  static const _themeKey = 'theme_mode';
  static const _localeKey = 'locale_code';
  static const _brandKey = 'default_brand';
  static const _brandRefKey = 'default_brand_ref';
  static const _carModelKey = 'default_car_model';
  static const _softwareVersionKey = 'default_software_version';
  static const _softwareVersionRefKey = 'default_software_version_ref';
  static const _firstLaunchKey = 'is_first_launch';
  static const _eventSoundKey = 'is_event_sound_enabled';
  static const _highFrameRateKey = 'is_high_frame_rate_enabled';
  static const _videoRecordingKey = 'is_video_recording_enabled';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = _ref.read(authProvider);
    final currentUserId = auth.user?.id;

    debugPrint(
        '[Settings] Loading settings for user: ${currentUserId ?? "guest"}');

    // 加载首次启动标志，默认 true
    final isFirstLaunch = prefs.getBool(_firstLaunchKey) ?? true;

    // 加载负体验音效开关，默认 false
    final isEventSoundEnabled = prefs.getBool(_eventSoundKey) ?? false;

    // 加载高帧率数据记录开关，默认 false
    final isHighFrameRateEnabled = prefs.getBool(_highFrameRateKey) ?? false;

    // 加载视频录制开关，默认 false
    final isVideoRecordingEnabled = prefs.getBool(_videoRecordingKey) ?? false;

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

    // 加载品牌和车型
    String? brand = prefs.getString(_brandKey);
    String? brandRef = prefs.getString(_brandRefKey);
    String? carModel = prefs.getString(_carModelKey);
    String? softwareVersion = prefs.getString(_softwareVersionKey);
    String? softwareVersionRef = prefs.getString(_softwareVersionRefKey);

    // 如果已登录，优先从账号信息加载
    if (auth.isAuthenticated && currentUserId != null) {
      String? cloudBrand = auth.user?.getStringValue('brand');
      String? cloudBrandRef = auth.user?.getStringValue('brand_ref');
      String? cloudCarModel = auth.user?.getStringValue('car_model');
      String? cloudVersion = auth.user?.getStringValue('software_version');
      String? cloudVersionRef =
          auth.user?.getStringValue('software_version_ref');

      // 核心防御逻辑：如果 Cloud 传回来的 string 字段里存的是 15 位 ID
      // 则将其“拨乱反正”到 ref 字段，避免 UI 直接显示 ID
      if (cloudVersion != null &&
          cloudVersion.length == 15 &&
          !cloudVersion.contains('.')) {
        cloudVersionRef = cloudVersion;
        cloudVersion = null;
      }
      if (cloudBrand != null &&
          cloudBrand.length == 15 &&
          !cloudBrand.contains(' ')) {
        cloudBrandRef = cloudBrand;
        cloudBrand = null;
      }

      // 🔄 迁移策略：优先使用 _ref
      brandRef = cloudBrandRef?.isNotEmpty == true ? cloudBrandRef : brandRef;
      brand = cloudBrand?.isNotEmpty == true ? cloudBrand : brand;
      carModel = cloudCarModel?.isNotEmpty == true ? cloudCarModel : carModel;
      softwareVersionRef = cloudVersionRef?.isNotEmpty == true
          ? cloudVersionRef
          : softwareVersionRef;
      softwareVersion =
          cloudVersion?.isNotEmpty == true ? cloudVersion : softwareVersion;
    }

    // --- 【深度清洗】如果本地持久化缓存也是 ID，强制清理并持久化 ---
    bool needsResave = false;
    if (softwareVersion != null &&
        softwareVersion.length == 15 &&
        !softwareVersion.contains('.')) {
      softwareVersionRef = softwareVersion;
      softwareVersion = null;
      needsResave = true;
    }
    if (brand != null && brand.length == 15 && !brand.contains(' ')) {
      brandRef = brand;
      brand = null;
      needsResave = true;
    }

    if (needsResave) {
      if (softwareVersion == null) await prefs.remove(_softwareVersionKey);
      if (brand == null) await prefs.remove(_brandKey);
      if (softwareVersionRef != null) {
        await prefs.setString(_softwareVersionRefKey, softwareVersionRef);
      }
      if (brandRef != null) await prefs.setString(_brandRefKey, brandRef);
    }

    state = SettingsState(
      themeMode: themeMode,
      locale: locale,
      brand: brand,
      brandRef: brandRef,
      carModel: carModel,
      softwareVersion: softwareVersion,
      softwareVersionRef: softwareVersionRef,
      isFirstLaunch: isFirstLaunch,
      isEventSoundEnabled: isEventSoundEnabled,
      isHighFrameRateEnabled: isHighFrameRateEnabled,
      isVideoRecordingEnabled: isVideoRecordingEnabled,
    );

    // 🔥 更新用户数据哈希值
    if (auth.user != null) {
      _lastLoadedUserDataHash = _getUserDataHash(auth.user!);
    }
  }

  /// 清理用户特定的设置（退出登录或切换账号时调用）
  Future<void> _clearUserSpecificSettings() async {
    debugPrint('[Settings] Clearing user-specific settings');

    _lastLoadedUserDataHash = null; // 🔥 清理哈希值

    // 只清空与用户关联的车辆信息，保留主题、语言等全局设置
    state = state.copyWith(
      brand: null,
      brandRef: null,
      carModel: null,
      softwareVersion: null,
      softwareVersionRef: null,
    );

    // 同步清理本地缓存
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_brandKey);
    await prefs.remove(_brandRefKey);
    await prefs.remove(_carModelKey);
    await prefs.remove(_softwareVersionKey);
    await prefs.remove(_softwareVersionRefKey);
  }

  Future<void> setHighFrameRateEnabled(bool enabled) async {
    state = state.copyWith(isHighFrameRateEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highFrameRateKey, enabled);
  }

  Future<void> setVideoRecordingEnabled(bool enabled) async {
    state = state.copyWith(isVideoRecordingEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_videoRecordingKey, enabled);
  }

  Future<void> setEventSoundEnabled(bool enabled) async {
    state = state.copyWith(isEventSoundEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eventSoundKey, enabled);
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
        // 🔄 数据库迁移：优先使用 _ref 字段
        'brand': '', // 清空旧字段
        'brand_ref': state.brandRef ?? '',
        'car_model': state.carModel ?? '',
        'software_version': '', // 清空旧字段
        'software_version_ref': state.softwareVersionRef ?? '',
      });
      // 更新本地 auth 状态
      await _ref.read(authProvider.notifier).refreshUserFromServer();
    } catch (e) {
      debugPrint('Failed to sync vehicle settings to PocketBase: $e');
    }
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
      {String? brand,
      String? brandRef,
      String? model,
      String? version,
      String? versionRef}) async {
    state = state.copyWith(
      brand: brand,
      brandRef: brandRef,
      carModel: model,
      softwareVersion: version,
      softwareVersionRef: versionRef,
    );

    final prefs = await SharedPreferences.getInstance();
    if (brand != null) await prefs.setString(_brandKey, brand);
    if (brandRef != null) await prefs.setString(_brandRefKey, brandRef);
    if (model != null) await prefs.setString(_carModelKey, model);
    if (version != null) await prefs.setString(_softwareVersionKey, version);
    if (versionRef != null) {
      await prefs.setString(_softwareVersionRefKey, versionRef);
    }

    await _syncToPocketBase();
  }

  Future<void> clearVehicleSettings() async {
    state = state.copyWith(
      brand: null,
      brandRef: null,
      carModel: null,
      softwareVersion: null,
      softwareVersionRef: null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_brandKey);
    await prefs.remove(_brandRefKey);
    await prefs.remove(_carModelKey);
    await prefs.remove(_softwareVersionKey);
    await prefs.remove(_softwareVersionRefKey);
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
