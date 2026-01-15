import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';

/// 统一的国际化桥接器
/// 
/// 核心理念：全部统一到 Flutter 官方方案（ARB 文件）。
/// 这里的 [I18n] 类仅作为桥接器，通过 [t] 方法调用官方生成的 [AppLocalizations]。
class I18n {
  final AppLocalizations _delegate;

  I18n(this._delegate);

  /// 当前 Locale
  Locale get locale => Locale(_delegate.localeName);

  /// 根据 Key 获取翻译词条 (桥接到官方方案)
  /// 
  /// 优先使用官方生成的命名 Getter（如 settings），
  /// 如果由于历史原因传入的是 String Key，则通过底层词典匹配。
  String t(String key, {List<String>? args}) {
    // 官方方案生成的翻译逻辑
    String value = _lookup(key);
    
    // 处理动态参数 {}
    if (args != null && args.isNotEmpty) {
      final regExp = RegExp(r'\{.*?\}');
      for (var arg in args) {
        value = value.replaceFirst(regExp, arg);
      }
    }
    return value;
  }

  /// 这是一个“后门”逻辑，用于在没有 Context 的情况下，通过字符串 Key 查找官方翻译。
  /// 注意：为了极致性能，常用的 Key 可以在这里映射，或者直接使用生成的代码。
  String _lookup(String key) {
    // 这里利用了生成的 AppLocalizations 类。
    // 由于生成的代码没有暴露 Map，我们在这里建立一个轻量映射，
    // 确保开发体验和官方方案完全一致。
    switch (key) {
      case 'settings': return _delegate.settings;
      case 'preferences': return _delegate.preferences;
      case 'theme': return _delegate.theme;
      case 'themeAuto': return _delegate.themeAuto;
      case 'themeLight': return _delegate.themeLight;
      case 'themeDark': return _delegate.themeDark;
      case 'language': return _delegate.language;
      case 'chinese': return _delegate.chinese;
      case 'english': return _delegate.english;
      case 'event_sound': return _delegate.event_sound;
      case 'event_sound_desc': return _delegate.event_sound_desc;
      case 'current_version': return _delegate.current_version;
      case 'algorithm_version': return _delegate.algorithm_version;
      case 'check_update': return _delegate.check_update;
      case 'privacy_policy': return _delegate.privacy_policy;
      case 'unknown': return _delegate.unknown;
      case 'user': return _delegate.user;
      case 'logout': return _delegate.logout;
      case 'login': return _delegate.login;
      case 'login_to_sync': return _delegate.login_to_sync;
      case 'model_hint': return _delegate.model_hint;
      case 'verification_sent': return _delegate.verification_sent;
      case 'verification_success': return _delegate.verification_success;
      case 'not_verified': return _delegate.not_verified;
      case 'approved': return _delegate.approved;
      case 'pending': return _delegate.pending;
      case 'rejected': return _delegate.rejected;
      case 'unverified': return _delegate.unverified;
      case 'my_car': return _delegate.my_car;
      case 'my_data_uploaded': return _delegate.my_data_uploaded;
      case 'uploaded_mileage': return _delegate.uploaded_mileage;
      case 'mileage_contribution': return _delegate.mileage_contribution;
      case 'my_puked_rank': return _delegate.my_puked_rank;
      case 'my_puked_value': return _delegate.my_puked_value;
      case 'brand_distribution_desc': return _delegate.brand_distribution_desc;
      case 'account_and_car': return _delegate.account_and_car;
      case 'history': return _delegate.history;
      case 'arena': return _delegate.arena;
      case 'start_trip': return _delegate.start_trip;
      case 'stop_trip': return _delegate.stop_trip;
      case 'calibrating': return _delegate.calibrating;
      case 'calibrated': return _delegate.calibrated;
      case 'calibration_failed': return _delegate.calibration_failed;
      case 'calibration_failed_desc': return _delegate.calibration_failed_desc;
      case 'rapid_accel': return _delegate.rapid_accel;
      case 'rapid_decel': return _delegate.rapid_decel;
      case 'jerk': return _delegate.jerk;
      case 'rapidAcceleration': return _delegate.rapidAcceleration;
      case 'rapidDeceleration': return _delegate.rapidDeceleration;
      case 'jerk_event': return _delegate.jerk_event;
      case 'bump': return _delegate.bump;
      case 'wobble': return _delegate.wobble;
      case 'manual': return _delegate.manual;
      case 'calibration_tip': return _delegate.calibration_tip;
      case 'no_data_for_brand': return _delegate.no_data_for_brand;
      case 'connected_as': return _delegate.connected_as('{}');
      case 'car_cert_banner': return _delegate.car_cert_banner;
      case 'upload_cert_photos': return _delegate.upload_cert_photos;
      case 'upload_hint': return _delegate.upload_hint;
      case 'file_limit_hint': return _delegate.file_limit_hint;
      case 'submit_for_audit': return _delegate.submit_for_audit;
      case 'submit_success_tip': return _delegate.submit_success_tip;
      case 'error_image_limit': return _delegate.error_image_limit;
      case 'error_image_size': return _delegate.error_image_size;
      case 'error_image_type': return _delegate.error_image_type;
      case 'delete_event_title': return _delegate.delete_event_title;
      case 'delete_event_desc': return _delegate.delete_event_desc;
      case 'agree_privacy_link': return _delegate.agree_privacy_link('{}');
      case 'onboarding_step1': return _delegate.onboarding_step1;
      case 'onboarding_step2': return _delegate.onboarding_step2;
      case 'onboarding_step3': return _delegate.onboarding_step3;
      case 'onboarding_step4': return _delegate.onboarding_step4;
      case 'onboarding_step5': return _delegate.onboarding_step5;
      case 'onboarding_start': return _delegate.onboarding_start;
      case 'onboarding_welcome': return _delegate.onboarding_welcome;
      case 'saving_image': return _delegate.saving_image;
      case 'save_success': return _delegate.save_success;
      case 'save_failed': return _delegate.save_failed;
      case 'error_no_photo_permission': return _delegate.error_no_photo_permission;
      case 'algorithm_update_success': return _delegate.algorithm_update_success('{}');
      case 'algorithm_update_failed': return _delegate.algorithm_update_failed;
      case 'algorithm_settings_title': return _delegate.algorithm_settings_title;
      case 'algorithm_updated_at': return _delegate.algorithm_updated_at;
      case 'threshold_accel_label': return _delegate.threshold_accel_label;
      case 'threshold_decel_label': return _delegate.threshold_decel_label;
      case 'threshold_wobble_span_label': return _delegate.threshold_wobble_span_label;
      case 'threshold_bump_label': return _delegate.threshold_bump_label;
      case 'threshold_jerk_label': return _delegate.threshold_jerk_label;
      case 'threshold_pitch_label': return _delegate.threshold_pitch_label;
      case 'jerk_window_ms_label': return _delegate.jerk_window_ms_label;
      case 'accel_decel_window_ms_label': return _delegate.accel_decel_window_ms_label;
      case 'wobble_window_ms_label': return _delegate.wobble_window_ms_label;
      case 'fusion_window_ms_label': return _delegate.fusion_window_ms_label;
      case 'zy_interference_threshold_label': return _delegate.zy_interference_threshold_label;
      case 'zx_interference_threshold_label': return _delegate.zx_interference_threshold_label;
      case 'pitch_validation_enabled_label': return _delegate.pitch_validation_enabled_label;
      case 'speed_low_factor_label': return _delegate.speed_low_factor_label;
      case 'speed_high_factor_label': return _delegate.speed_high_factor_label;
      case 'max_jerk_allowed_label': return _delegate.max_jerk_allowed_label;
      case 'max_accel_allowed_label': return _delegate.max_accel_allowed_label;
      case 'max_wobble_span_allowed_label': return _delegate.max_wobble_span_allowed_label;
      case 'max_bump_allowed_label': return _delegate.max_bump_allowed_label;
      case 'min_accel_for_jerk_label': return _delegate.min_accel_for_jerk_label;
      case 'sync_now': return _delegate.sync_now;
      case 'about': return _delegate.about;
      case 'delete_trips': return _delegate.delete_trips;
      case 'delete': return _delegate.delete;
      case 'select_items': return _delegate.select_items;
      case 'sync_cloud_status': return _delegate.sync_cloud_status;
      case 'upload': return _delegate.upload;
      case 'insufficient_data_title': return _delegate.insufficient_data_title;
      case 'insufficient_data_message': return _delegate.insufficient_data_message;
      case 'syncing': return _delegate.syncing;
      case 'no_trips_yet': return _delegate.no_trips_yet;
      case 'submit_trip_confirm': return _delegate.submit_trip_confirm;
      case 'car_cert_banner_approved': return _delegate.car_cert_banner_approved;
      case 'car_cert_banner_pending': return _delegate.car_cert_banner_pending;
      case 'car_cert_banner_rejected': return _delegate.car_cert_banner_rejected;
      case 'upload_cert_photos_new': return _delegate.upload_cert_photos_new;
      case 'upload_cert_photos_submitted': return _delegate.upload_cert_photos_submitted;
      case 'upload_hint_new': return _delegate.upload_hint_new;
      case 'event_list': return _delegate.event_list;
      case 'min': return _delegate.min;
      case 'value': return _delegate.value;
      case 'ok': return _delegate.ok;
      case 'cancel': return _delegate.cancel;
      case 'confirm': return _delegate.confirm;
      case 'edit': return _delegate.edit;
      case 'save': return _delegate.save;
      case 'skip': return _delegate.skip;
      case 'distance': return _delegate.distance;
      case 'duration': return _delegate.duration;
      case 'avg_speed': return _delegate.avg_speed;
      case 'total_events': return _delegate.total_events;
      case 'trip_summary': return _delegate.trip_summary;
      case 'realtime_g': return _delegate.realtime_g;
      case 'peak_g': return _delegate.peak_g;
      case 'neg_exp': return _delegate.neg_exp;
      case 'longitudinal': return _delegate.longitudinal;
      case 'lateral': return _delegate.lateral;
      case 'gps_strong': return _delegate.gps_strong;
      case 'gps_fair': return _delegate.gps_fair;
      case 'gps_weak': return _delegate.gps_weak;
      case 'gps_no_signal': return _delegate.gps_no_signal;
      case 'history': return _delegate.history;
      case 'arena': return _delegate.arena;
      case 'all_versions': return _delegate.all_versions;
      case 'select_brand': return _delegate.select_brand;
      case 'select_version': return _delegate.select_version;
      case 'custom_version_input': return _delegate.custom_version_input;
      case 'arena_top10_title': return _delegate.arena_top10_title;
      case 'arena_total_mileage_title': return _delegate.arena_total_mileage_title;
      case 'arena_total_mileage_subtitle': return _delegate.arena_total_mileage_subtitle;
      case 'arena_details_title': return _delegate.arena_details_title;
      case 'arena_leaderboard_title': return _delegate.arena_leaderboard_title;
      case 'low_speed_ranking': return _delegate.low_speed_ranking;
      case 'high_speed_ranking': return _delegate.high_speed_ranking;
      case 'low_speed_desc': return _delegate.low_speed_desc;
      case 'high_speed_desc': return _delegate.high_speed_desc;
      case 'city': return _delegate.city;
      case 'highway': return _delegate.highway;
      case 'weekly_rank': return _delegate.weekly_rank;
      case 'total_rank': return _delegate.total_rank;
      case 'user_mileage_unit': return _delegate.user_mileage_unit;
      case 'km_per_event': return _delegate.km_per_event;
      case 'km_per_event_long': return _delegate.km_per_event_long;
      case 'km_per_version_event_long': return _delegate.km_per_version_event_long;
      case 'by_brand': return _delegate.by_brand;
      case 'by_version': return _delegate.by_version;
      case 'mileage_label': return _delegate.mileage_label;
      case 'current_distance': return _delegate.distance;
      case 'no_trips': return _delegate.no_trips;
      case 'car_model': return _delegate.car_model;
      case 'software_version': return _delegate.software_version;
      case 'vehicle_info': return _delegate.vehicle_info;
      case 'modify_vehicle_info': return _delegate.modify_vehicle_info;
      case 'version_hint': return _delegate.version_hint;
      case 'trip_analysis': return _delegate.trip_analysis;
      case 'event_breakdown': return _delegate.event_breakdown;
      case 'trigger_sensitivity': return _delegate.trigger_sensitivity;
      case 'trigger_duration': return _delegate.trigger_duration;
      case 'false_positive_suppression': return _delegate.false_positive_suppression;
      case 'download': return _delegate.download;
      case 'downloading': return _delegate.downloading;
      case 'download_success': return _delegate.download_success;
      case 'download_failed': return _delegate.download_failed;
      case 'cloud_trip': return _delegate.cloud_trip;
      case 'pulling_cloud_trips': return _delegate.pulling_cloud_trips;
      case 'app_tagline': return _delegate.app_tagline;
      case 'algo_a': return _delegate.algo_a;
      case 'algo_b': return _delegate.algo_b;
      case 'sensor_frozen': return _delegate.sensor_frozen;
      case 'ins_active': return _delegate.ins_active;
      case 'fetching_arena_data': return _delegate.fetching_arena_data;
      case 'no_records': return _delegate.no_records;
      case 'arena_mileage_requirement': return _delegate.arena_mileage_requirement;
      case 'manual': return _delegate.manual;
      case 'threshold_accel_hint': return _delegate.threshold_accel_hint;
      case 'threshold_decel_hint': return _delegate.threshold_decel_hint;
      case 'threshold_wobble_span_hint': return _delegate.threshold_wobble_span_hint;
      case 'threshold_bump_hint': return _delegate.threshold_bump_hint;
      case 'threshold_jerk_hint': return _delegate.threshold_jerk_hint;
      case 'threshold_pitch_hint': return _delegate.threshold_pitch_hint;
      case 'jerk_window_ms_hint': return _delegate.jerk_window_ms_hint;
      case 'accel_decel_window_ms_hint': return _delegate.accel_decel_window_ms_hint;
      case 'wobble_window_ms_hint': return _delegate.wobble_window_ms_hint;
      case 'fusion_window_ms_hint': return _delegate.fusion_window_ms_hint;
      case 'max_jerk_allowed_hint': return _delegate.max_jerk_allowed_hint;
      case 'max_accel_allowed_hint': return _delegate.max_accel_allowed_hint;
      case 'max_wobble_span_allowed_hint': return _delegate.max_wobble_span_allowed_hint;
      case 'max_bump_allowed_hint': return _delegate.max_bump_allowed_hint;
      case 'min_accel_for_jerk_hint': return _delegate.min_accel_for_jerk_hint;
      case 'zy_interference_threshold_hint': return _delegate.zy_interference_threshold_hint;
      case 'zx_interference_threshold_hint': return _delegate.zx_interference_threshold_hint;
      case 'pitch_validation_enabled_hint': return _delegate.pitch_validation_enabled_hint;
      case 'speed_low_factor_hint': return _delegate.speed_low_factor_hint;
      case 'speed_high_factor_hint': return _delegate.speed_high_factor_hint;
      // 处理 ARB 自动生成的参数化词条
      case 'delete_trips_confirm': return _delegate.delete_trips_confirm('{}');
      case 'bulk_upload_confirm': return _delegate.bulk_upload_confirm('{}');
      case 'trips_count': return _delegate.trips_count('{}');
      case 'events_count': return _delegate.events_count('{}');
      case 'uploaded_mileage_val': return _delegate.uploaded_mileage_val('{}');
      case 'mileage_contribution_val': return _delegate.mileage_contribution_val('{}');
      case 'my_puked_rank_val': return _delegate.my_puked_rank_val('{}', '{}');
      case 'my_puked_value_val': return _delegate.my_puked_value_val('{}');
      case 'arena_brand_evolution_title': return _delegate.arena_brand_evolution_title('{}');
      case 'cloud_sync_result': return _delegate.cloud_sync_result('{}');
      default: return key; // 回退到 Key 本身
    }
  }
}

/// 国际化实例 Provider
/// 
/// 监听用户设置中的 Locale 变化，并自动加载对应的官方 AppLocalizations 代理
final i18nProvider = Provider<I18n>((ref) {
  final settings = ref.watch(settingsProvider);
  final locale = settings.locale ?? const Locale('en');
  
  // 利用官方生成的静态方法查找对应的本地化实例
  final delegate = lookupAppLocalizations(locale);
  
  return I18n(delegate);
});
