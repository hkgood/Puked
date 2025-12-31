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
  String get history => '历史行程';

  @override
  String get arena => 'Arena';

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
  String get car_model => '车型';

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

  @override
  String get account => '账号';

  @override
  String get login => '登录';

  @override
  String get logout => '退出登录';

  @override
  String get sync_data => '同步数据';

  @override
  String get login_to_sync => '登录以同步数据并分享行程';

  @override
  String connected_as(Object name) {
    return '已连接为: $name';
  }

  @override
  String get brand => '我的智驾';

  @override
  String get my_car => '我的爱车';

  @override
  String get password => '密码';

  @override
  String get name => '昵称';

  @override
  String get register => '注册';

  @override
  String get no_account => '还没有账号？去注册';

  @override
  String get has_account => '已有账号？去登录';

  @override
  String get login_failed => '登录失败';

  @override
  String get register_failed => '注册失败';

  @override
  String get forgot_password => '忘记密码？';

  @override
  String get reset_email_sent => '重置邮件已发送，请检查收件箱';

  @override
  String get verify_email => '验证邮箱';

  @override
  String get verification_sent => '验证邮件已发送';

  @override
  String get not_verified => '账号未验证 (点击验证)';

  @override
  String get error_email_taken => 'Email已被注册';

  @override
  String get error_invalid_credentials => '邮箱或密码错误';

  @override
  String get error_password_too_short => '密码至少需要8位';

  @override
  String get verification_success => '验证成功！';

  @override
  String get syncing => '同步云端状态中...';

  @override
  String sync_complete(Object count) {
    return '同步完成，已标记 $count 条行程';
  }

  @override
  String get no_cloud_records => '云端没有找到相关记录';

  @override
  String get sync_cloud_status => '同步上传状态';

  @override
  String get arena_top10_title => '智驾安全 Top 10';

  @override
  String get km_per_event_long => '无负面体验里程 (越高越稳)';

  @override
  String get by_brand => '按品牌';

  @override
  String get by_version => '按版本';

  @override
  String get arena_total_mileage_title => '智驾里程榜';

  @override
  String get arena_total_mileage_subtitle => '各品牌累计智驾行程里程';

  @override
  String arena_brand_evolution_title(Object brand) {
    return '$brand 进化趋势';
  }

  @override
  String get km_per_version_event_long => '不同软件版本的舒适度表现趋势';

  @override
  String get arena_details_title => '负面体验详情分布';

  @override
  String get km_per_event => '公里/次';

  @override
  String get all_versions => '所有版本';

  @override
  String get select_brand => '选择品牌';

  @override
  String get no_trips_yet => '还没有行程数据，开始一段智驾行程来查看统计吧！';

  @override
  String get no_data_for_brand => '所选品牌或版本暂无数据。';

  @override
  String events_count(Object count) {
    return '$count 次事件';
  }

  @override
  String trips_count(Object count) {
    return '$count 次行程';
  }

  @override
  String get mileage_label => '里程';

  @override
  String get car_cert_banner => '完成爱车认证，开启行程提交功能';

  @override
  String get upload_cert_photos => '爱车认证';

  @override
  String get upload_hint => '请上传包含车牌号或 VIN 码的照片（通常在挡风玻璃左下角或车门柱上）';

  @override
  String get file_limit_hint => '最多 3 张，支持 JPG/PNG，单张 < 5MB';

  @override
  String get submit_for_audit => '提交认证';

  @override
  String get submit_success_tip => '认证资料已提交，我们会尽快完成审核。';

  @override
  String get error_image_limit => '最多只能选择 3 张照片';

  @override
  String get error_image_size => '单张照片不能超过 5MB';

  @override
  String get error_image_type => '仅支持 JPG 或 PNG 格式照片';

  @override
  String get delete_event_title => '确认删除事件';

  @override
  String get delete_event_desc => '删除后无法恢复，请确认删除么？';
}
