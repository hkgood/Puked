// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settings => '设置';

  @override
  String get preferences => '偏好设置';

  @override
  String get theme => '主题';

  @override
  String get themeAuto => '自动';

  @override
  String get themeLight => '白天';

  @override
  String get themeDark => '黑夜';

  @override
  String get language => '语言';

  @override
  String get chinese => '中文';

  @override
  String get english => '英文';

  @override
  String get event_sound => '负体验音效';

  @override
  String get event_sound_desc => '发生急加速、急减速等事件时播放提示音';

  @override
  String get current_version => '当前版本';

  @override
  String get algorithm_version => '算法版本';

  @override
  String get check_update => '检查更新';

  @override
  String get privacy_policy => '隐私政策';

  @override
  String get unknown => '未知';

  @override
  String get user => '用户';

  @override
  String get logout => '退出登录';

  @override
  String get login => '登录';

  @override
  String get login_to_sync => '登录以同步数据并分享行程';

  @override
  String get model_hint => '输入车型 (如 Model 3)';

  @override
  String get version_hint => '输入软件版本 (如 v12.5)';

  @override
  String get verification_sent => '验证邮件已发送';

  @override
  String get verification_success => '验证成功！';

  @override
  String get not_verified => '账号未验证 (点击验证)';

  @override
  String get approved => '已认证';

  @override
  String get pending => '认证中';

  @override
  String get rejected => '认证失败';

  @override
  String get unverified => '未认证';

  @override
  String get my_car => '我的爱车';

  @override
  String get my_data_uploaded => '我的数据 (已上传)';

  @override
  String get uploaded_mileage => '上传里程';

  @override
  String get mileage_contribution => '里程贡献度';

  @override
  String get my_puked_rank => '我的 PUKED 排名';

  @override
  String get my_puked_value => '我的 PUKED 值';

  @override
  String get brand_distribution_desc => '里程分布';

  @override
  String uploaded_mileage_val(Object value) {
    return '$value KM';
  }

  @override
  String mileage_contribution_val(Object value) {
    return '$value%';
  }

  @override
  String my_puked_rank_val(Object rank, Object total) {
    return '第 $rank / $total 名';
  }

  @override
  String my_puked_value_val(Object value) {
    return '$value 公里/次';
  }

  @override
  String get account_and_car => '账号与车辆';

  @override
  String get realtime_g => '实时 G';

  @override
  String get peak_g => '峰值 G';

  @override
  String get longitudinal => '纵向加速度';

  @override
  String get lateral => '横向加速度';

  @override
  String get trip_summary => '行程摘要';

  @override
  String get total_events => '事件总数';

  @override
  String get duration => '持续时间';

  @override
  String get distance => '行驶里程';

  @override
  String get avg_speed => '平均车速';

  @override
  String get calibrate => '传感器校准';

  @override
  String get recorded_msg => '已记录 (包含过去10秒数据)';

  @override
  String get no_trips => '暂无行程记录';

  @override
  String get exporting => '正在导出数据...';

  @override
  String get pro => 'Pro';

  @override
  String get submit_trip => '提交行程';

  @override
  String get uploading => '正在上传...';

  @override
  String get upload_success => '上传成功';

  @override
  String get upload_failed => '上传失败';

  @override
  String get neg_exp => '负体验';

  @override
  String get gps_strong => '强';

  @override
  String get gps_fair => '中';

  @override
  String get gps_weak => '弱';

  @override
  String get gps_no_signal => '无信号';

  @override
  String get share_card => '生成分享卡片';

  @override
  String get trip_analysis => '行程数据分析';

  @override
  String get event_breakdown => '负体验分布';

  @override
  String get trigger_sensitivity => '触发敏感度';

  @override
  String get trigger_duration => '触发时长';

  @override
  String get false_positive_suppression => '误报抑制';

  @override
  String get download => '下载';

  @override
  String get downloading => '正在同步下载...';

  @override
  String get download_success => '同步下载成功';

  @override
  String get download_failed => '同步下载失败';

  @override
  String get cloud_trip => '云端行程';

  @override
  String get pulling_cloud_trips => '正在拉取云端记录...';

  @override
  String cloud_sync_result(Object count) {
    return '同步完成，发现 $count 条新行程';
  }

  @override
  String get select_version => '选择版本号';

  @override
  String get custom_version_input => '自行输入';

  @override
  String get confirm => '确认';

  @override
  String get cancel => '取消';

  @override
  String get ok => '确定';

  @override
  String get edit => '编辑';

  @override
  String get save => '保存';

  @override
  String get skip => '跳过';

  @override
  String get software_version => '软件版本';

  @override
  String get car_model => '车型';

  @override
  String get vehicle_info => '车辆信息';

  @override
  String get modify_vehicle_info => '修改车辆信息';

  @override
  String get arena_top10_title => '舒适度 TOP10';

  @override
  String get arena_total_mileage_title => '总里程';

  @override
  String get arena_total_mileage_subtitle => '目前所有品牌提交的智能驾驶里程';

  @override
  String arena_brand_evolution_title(Object brand) {
    return '$brand 版本舒适度';
  }

  @override
  String get arena_details_title => '症状分布';

  @override
  String get arena_leaderboard_title => '里程贡献榜';

  @override
  String get low_speed_ranking => '低速场景舒适度排名';

  @override
  String get high_speed_ranking => '高速场景舒适度排名';

  @override
  String get low_speed_desc => '时速小于50公里每小时行程的负体验，公里/次，总里程 > 300';

  @override
  String get high_speed_desc => '时速大于50公里每小时行程的负体验，公里/次，总里程 > 300';

  @override
  String get city => '市区';

  @override
  String get highway => '高速';

  @override
  String get weekly_rank => '周榜';

  @override
  String get total_rank => '总榜';

  @override
  String get user_mileage_unit => '公里';

  @override
  String get km_per_event => '公里/次';

  @override
  String get km_per_event_long => '平均发生一次负体验的公里数，总里程 > 300';

  @override
  String get km_per_version_event_long => '每个软件版本平均发生一次负体验的公里数';

  @override
  String get by_brand => '按品牌';

  @override
  String get by_version => '分版本';

  @override
  String get all_versions => '全版本';

  @override
  String get select_brand => '选择品牌';

  @override
  String get mileage_label => '累计里程';

  @override
  String trips_count(Object count) {
    return '$count 行程历史';
  }

  @override
  String events_count(Object count) {
    return '$count 次体验';
  }

  @override
  String get app_name => '吐槽';

  @override
  String get history => '历史行程';

  @override
  String get arena => 'Arena';

  @override
  String get start_trip => '开始行程';

  @override
  String get stop_trip => '结束行程';

  @override
  String get calibrating => '校准中，请保持手机静止...';

  @override
  String get calibrated => '校准完成！';

  @override
  String get calibration_failed => '校准失败';

  @override
  String get calibration_failed_desc => '请确保校准时车辆和手机处于静止状态。';

  @override
  String get rapid_accel => '急加速';

  @override
  String get rapid_decel => '急刹';

  @override
  String get jerk => '顿挫';

  @override
  String get rapidAcceleration => '急加速';

  @override
  String get rapidDeceleration => '急刹';

  @override
  String get jerk_event => '顿挫';

  @override
  String get bump => '颠簸';

  @override
  String get wobble => '摆动';

  @override
  String get manual => '手动标记';

  @override
  String get calibration_tip => '请保持车辆静止，手机已固定';

  @override
  String get no_data_for_brand => '暂无数据';

  @override
  String connected_as(Object name) {
    return '已连接为: $name';
  }

  @override
  String get car_cert_banner => '完成爱车认证，开启行程提交功能';

  @override
  String get upload_cert_photos => '爱车认证';

  @override
  String get upload_hint => '请上传包含车牌号或 VIN 码的照片';

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

  @override
  String agree_privacy_link(Object policy) {
    return '勾选同意$policy';
  }

  @override
  String get onboarding_step1 => '固定手机，与车头方向一致';

  @override
  String get onboarding_step2 => '保持静止，点击“开始行程”校准传感器';

  @override
  String get onboarding_step3 => '开始测试，避免中途拿起手机';

  @override
  String get onboarding_step4 => '停下车辆，点击“结束行程”再拿起手机';

  @override
  String get onboarding_step5 => '点击分享行程，与大家一起共享数据';

  @override
  String get onboarding_start => '开始体验';

  @override
  String get onboarding_welcome => '欢迎使用吐槽';

  @override
  String get saving_image => '正在保存为图片...';

  @override
  String get save_success => '图片已保存至相册';

  @override
  String get save_failed => '保存图片失败';

  @override
  String get error_no_photo_permission => '请开启相册访问权限';

  @override
  String algorithm_update_success(Object version) {
    return '算法参数同步成功 (v$version)';
  }

  @override
  String get algorithm_update_failed => '参数同步失败，请检查网络';

  @override
  String get algorithm_settings_title => '在线算法参数';

  @override
  String get algorithm_updated_at => '最后更新';

  @override
  String get threshold_accel_label => '急加速敏感度';

  @override
  String get threshold_decel_label => '急减速敏感度';

  @override
  String get threshold_wobble_span_label => '横向摆动敏感度';

  @override
  String get threshold_bump_label => '颠簸敏感度';

  @override
  String get threshold_jerk_label => '顿挫敏感度';

  @override
  String get threshold_pitch_label => '俯仰角阈值';

  @override
  String get jerk_window_ms_label => '顿挫检测时长';

  @override
  String get accel_decel_window_ms_label => '加减速持续时长';

  @override
  String get wobble_window_ms_label => '摆动检测时长';

  @override
  String get fusion_window_ms_label => '事件聚合时长';

  @override
  String get zy_interference_threshold_label => '垂直轴干扰抑制';

  @override
  String get zx_interference_threshold_label => '颠簸干扰抑制';

  @override
  String get pitch_validation_enabled_label => '俯仰保护开关';

  @override
  String get speed_low_factor_label => '低速灵敏度系数';

  @override
  String get speed_high_factor_label => '高速灵敏度系数';

  @override
  String get max_jerk_allowed_label => '最大允许冲击';

  @override
  String get max_accel_allowed_label => '最大允许加速度';

  @override
  String get max_wobble_span_allowed_label => '最大允许摆动';

  @override
  String get max_bump_allowed_label => '最大允许颠簸';

  @override
  String get min_accel_for_jerk_label => '顿挫起征加速度';

  @override
  String get threshold_accel_hint => '触发“急加速”所需的最小加速度门槛';

  @override
  String get threshold_decel_hint => '触发“急刹车”所需的最小减速度门槛';

  @override
  String get threshold_wobble_span_hint => '触发“横摆/晃动”所需的最小横轴跨度';

  @override
  String get threshold_bump_hint => '触发“颠簸”所需的最小垂直冲击力';

  @override
  String get threshold_jerk_hint => '触发“顿挫/冲击”所需的最小加速度变化率';

  @override
  String get threshold_pitch_hint => '触发“抬头/点头”所需的最小俯仰角速度';

  @override
  String get jerk_window_ms_hint => '计算顿挫冲击率的时间探测窗口';

  @override
  String get accel_decel_window_ms_hint => '判定急加减速所需的最小持续动作时长';

  @override
  String get wobble_window_ms_hint => '检测左右横摆晃动的时间观测周期';

  @override
  String get fusion_window_ms_hint => '决策引擎合并多项特征并判定前的等待时长';

  @override
  String get max_jerk_allowed_hint => '过滤因手机掉落或剧烈晃动产生的虚假冲击';

  @override
  String get max_accel_allowed_hint => '过滤非行车产生的极端物理加速度噪声';

  @override
  String get max_wobble_span_allowed_hint => '过滤因操作手机产生的超大幅度横摆噪声';

  @override
  String get max_bump_allowed_hint => '过滤手机跌落等非路面引起的极端垂直冲击';

  @override
  String get min_accel_for_jerk_hint => '只有加速度超过此值时才计算顿挫';

  @override
  String get zy_interference_threshold_hint => '垂直活跃到何种程度时开始压制纵向顿挫检测';

  @override
  String get zx_interference_threshold_hint => '路面垂直颠簸活跃到何种程度时开始压制纵向(X轴)顿挫检测';

  @override
  String get pitch_validation_enabled_hint => '配合陀螺仪校验车辆真实的抬头/点头动作';

  @override
  String get speed_low_factor_hint => '低速（<10km/h）场景下的灵敏度修正系数';

  @override
  String get speed_high_factor_hint => '高速（>80km/h）场景下的灵敏度修正系数';

  @override
  String get sync_now => '立即同步';

  @override
  String get error_invalid_credentials => '邮箱或密码错误';

  @override
  String get login_failed => '登录失败';

  @override
  String get forgot_password => '忘记密码';

  @override
  String get reset_email_sent => '重置邮件已发送';

  @override
  String get password => '密码';

  @override
  String get no_account => '没有账号？立即注册';

  @override
  String get error_email_taken => '该邮箱已被占用';

  @override
  String get error_password_too_short => '密码至少需要8位';

  @override
  String get register_failed => '注册失败';

  @override
  String get register => '注册';

  @override
  String get name => '昵称';

  @override
  String get has_account => '已有账号？立即登录';

  @override
  String get about => '关于';

  @override
  String get delete_trips => '删除行程';

  @override
  String delete_trips_confirm(Object count) {
    return '确认删除这 $count 条行程吗？';
  }

  @override
  String get delete => '删除';

  @override
  String get select_items => '选择项目';

  @override
  String get sync_cloud_status => '云端同步';

  @override
  String bulk_upload_confirm(Object count) {
    return '确认批量上传这 $count 条行程吗？';
  }

  @override
  String get upload => '上传';

  @override
  String get insufficient_data_title => '数据不足';

  @override
  String get insufficient_data_message =>
      '部分行程数据不足（里程太短），无法上传竞技场。建议继续行驶一段距离后再提交。';

  @override
  String get syncing => '正在同步中...';

  @override
  String get no_trips_yet => '暂无历史行程';

  @override
  String get submit_trip_confirm => '确认提交该行程到竞技场么？';

  @override
  String get car_cert_banner_approved => '爱车已认证';

  @override
  String get car_cert_banner_pending => '爱车认证中';

  @override
  String get car_cert_banner_rejected => '爱车认证失败';

  @override
  String get upload_cert_photos_new => '重新上传认证资料';

  @override
  String get upload_cert_photos_submitted => '认证资料已提交';

  @override
  String get upload_hint_new => '请重新上传包含车牌号或 VIN 码的照片';

  @override
  String get event_list => '事件详情';

  @override
  String get min => '分钟';

  @override
  String get value => '数值';

  @override
  String get app_tagline => '量化自动驾驶行驶舒适度';

  @override
  String get algo_a => '算法 A';

  @override
  String get algo_b => '算法 B';

  @override
  String get sensor_frozen => '传感器异常';

  @override
  String get ins_active => '惯导已激活';

  @override
  String get fetching_arena_data => '正在获取竞技场数据...';

  @override
  String get no_records => '暂无记录';

  @override
  String get arena_mileage_requirement => '排名品牌里程必须大于 300 公里';

  @override
  String get share_failed => '分享失败';

  @override
  String get retry => '重试';

  @override
  String get avatar_updated => '头像已更新';

  @override
  String get passwords_not_match => '两次输入的密码不一致';

  @override
  String get required => '必填';

  @override
  String get email => '邮箱';

  @override
  String get invalid_email => '无效的邮箱格式';

  @override
  String get password_too_short_hint => '密码至少需要 8 位';

  @override
  String get repeat_password => '重复密码';

  @override
  String get crop_avatar => '裁剪头像';

  @override
  String get update_avatar_failed => '更新头像失败';
}
