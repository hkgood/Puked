import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:puked/features/settings/providers/settings_provider.dart';

class I18n {
  final Locale locale;
  I18n(this.locale);

  static const _localizedValues = {
    'en': {
      'app_name': 'Puked',
      'history': 'History',
      'start_trip': 'Start Trip',
      'stop_trip': 'End Trip',
      'calibrate': 'Calibrate',
      'calibrating': 'Calibrating, stay still...',
      'calibrated': 'Calibrated!',
      'rapid_accel': 'Rapid Accel',
      'rapid_decel': 'Rapid Decel',
      'rapidAcceleration': 'Rapid Accel',
      'rapidDeceleration': 'Rapid Decel',
      'bump': 'Bump',
      'wobble': 'Wobble',
      'manual': 'Manual Mark',
      'recorded_msg': 'Recorded (Last 10s data)',
      'calibration_tip':
          'Please keep the vehicle stationary and the phone fixed',
      'no_trips': 'No trip records',
      'exporting': 'Exporting data...',
      'car_model': 'Car Model',
      'peak_g': 'Peak G',
      'longitudinal': 'LONGITUDINAL',
      'lateral': 'LATERAL',
      'trip_summary': 'Trip Summary',
      'total_events': 'Total Events',
      'events_count': '{} Events',
      'trajectory_points': 'Trajectory Points',
      'duration': 'Duration',
      'event_list': 'Event List',
      'min': 'min',
      'distance': 'Distance',
      'avg_speed': 'Avg Speed',
      'delete_trips': 'Delete Trips',
      'delete_trips_confirm': 'Are you sure you want to delete {} trips?',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'select_items': 'Select Items',
      'edit': 'Edit',
      'modifyVehicleInfo': 'Modify Vehicle Info',
      'vehicleInfo': 'Vehicle Info',
      'softwareVersion': 'Software Version',
      'modelHint': 'Enter model (e.g. Model 3)',
      'versionHint': 'Enter version (e.g. v12.5)',
      'skip': 'Skip',
      'save': 'Save',
    },
    'zh': {
      'app_name': '吐槽',
      'history': '历史行程',
      'start_trip': '开始行程',
      'stop_trip': '结束行程',
      'calibrate': '传感器校准',
      'calibrating': '校准中，请保持手机静止...',
      'calibrated': '校准完成！',
      'rapid_accel': '急加速',
      'rapid_decel': '急减速',
      'rapidAcceleration': '急加速',
      'rapidDeceleration': '急减速',
      'bump': '颠簸',
      'wobble': '摆动',
      'manual': '手动标记',
      'recorded_msg': '已记录 (包含过去10秒数据)',
      'calibration_tip': '请保持车辆静止，手机已固定',
      'no_trips': '暂无行程记录',
      'exporting': '正在导出数据...',
      'car_model': '车型',
      'peak_g': '峰值 G',
      'longitudinal': '纵向加速度',
      'lateral': '横向加速度',
      'trip_summary': '行程摘要',
      'total_events': '事件总数',
      'events_count': '{} 个事件',
      'trajectory_points': '轨迹点',
      'duration': '持续时间',
      'event_list': '事件列表',
      'min': '分钟',
      'distance': '行驶里程',
      'avg_speed': '平均车速',
      'delete_trips': '删除行程',
      'delete_trips_confirm': '确定要删除这 {} 条行程吗？',
      'cancel': '取消',
      'delete': '删除',
      'select_items': '选择项目',
      'edit': '编辑',
      'modifyVehicleInfo': '修改车辆信息',
      'vehicleInfo': '车辆信息',
      'softwareVersion': '软件版本',
      'modelHint': '输入车型 (如 Model 3)',
      'versionHint': '输入软件版本 (如 v12.5)',
      'skip': '跳过',
      'save': '保存',
    },
  };

  String t(String key, {List<String>? args}) {
    // 兼容 zh-CN, en-US 等格式，只取前两个字符
    final lang = locale.languageCode.split('-')[0].split('_')[0];
    String value = _localizedValues[lang]?[key] ?? key;
    if (args != null) {
      for (var arg in args) {
        value = value.replaceFirst('{}', arg);
      }
    }
    return value;
  }
}

// 国际化实例 Provider
final i18nProvider = Provider<I18n>((ref) {
  final settings = ref.watch(settingsProvider);
  // 如果 settings.locale 为空，则回退到系统默认语言（这里简单处理为 zh）
  return I18n(settings.locale ?? const Locale('zh'));
});
