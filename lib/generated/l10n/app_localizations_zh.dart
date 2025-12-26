// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '吐槽';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get themeAuto => '跟随系统';

  @override
  String get themeLight => '白天模式';

  @override
  String get themeDark => '夜间模式';

  @override
  String get chinese => '中文';

  @override
  String get english => '英文';

  @override
  String get sensitivity => '自动打标敏感度';

  @override
  String get sensitivityLow => '低';

  @override
  String get sensitivityMedium => '中 (更灵敏)';

  @override
  String get sensitivityHigh => '高 (最灵敏, 默认)';

  @override
  String get sensitivityLowDesc => '急加速 > 3.0m/s², 急刹车 > 3.5m/s²';

  @override
  String get sensitivityMediumDesc => '急加速 > 2.4m/s², 急刹车 > 2.8m/s²';

  @override
  String get sensitivityHighDesc => '急加速 > 1.8m/s², 急刹车 > 2.1m/s²';

  @override
  String get sensitivityTip => '敏感度越高，触发急加速、急刹车等事件所需的加速度阈值就越小。';

  @override
  String get rapidAcceleration => '急加速';

  @override
  String get rapidDeceleration => '急减速';

  @override
  String get jerk => '顿挫';

  @override
  String get bump => '颠簸';

  @override
  String get wobble => '摆动';

  @override
  String get start_trip => '开始行程';

  @override
  String get stop_trip => '结束行程';

  @override
  String get calibrating => '校准中...';

  @override
  String get calibration_tip => '请保持手机静止以对齐车辆坐标系';

  @override
  String get edit => '编辑';

  @override
  String get modify_vehicle_info => '修改车辆信息';

  @override
  String get vehicle_info => '车辆信息';

  @override
  String get car_model => '测试车型';

  @override
  String get software_version => '软件版本';

  @override
  String get model_hint => '输入车型 (如 Model 3)';

  @override
  String get version_hint => '输入软件版本 (如 v12.5)';

  @override
  String get skip => '跳过';

  @override
  String get save => '保存';

  @override
  String get about => '关于';

  @override
  String get current_version => '当前版本';

  @override
  String get check_update => '检查更新';
}
