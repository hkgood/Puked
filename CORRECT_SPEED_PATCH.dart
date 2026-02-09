// ================================================================
// 速度优化正确方案 - 消除跳变版本
// ================================================================

// ========== 核心原理 ==========
// GPS提供"目标速度"（低频，500ms）
// 指数平滑滤波器提供"显示速度"（高频，30-60Hz）
// 完全消除INS依赖，避免漂移导致的跳变

// ========== 修改1：location_service.dart ==========
// 文件路径：Puked/lib/services/location_service.dart
// 修改行号：第32行

// 原始代码：
        intervalDuration: const Duration(seconds: 2),

// 修改为：
        intervalDuration: const Duration(milliseconds: 500),

// ========== 修改2：recording_provider.dart 添加成员变量 ==========
// 文件路径：Puked/lib/features/recording/providers/recording_provider.dart
// 修改位置：第157行（在 Position? _lastValidGpsPosition; 之后）

// 添加代码：
  // ✅ 速度平滑管理（消除GPS噪声和跳变）
  double _targetSpeed = 0.0;      // GPS给定的目标速度
  double _smoothedSpeed = 0.0;    // 平滑后的显示速度
  DateTime? _lastSpeedUpdate;

// ========== 修改3：recording_provider.dart GPS更新逻辑 ==========
// 修改位置：第301-307行

// 原始代码：
    state = state.copyWith(
      currentPosition: position,
      currentSpeed: position.speed,  // ❌ 删除这行
      isInsActive:
          !isGpsTrulyStable && position.accuracy > AppConstants.insTriggerAccuracy,
      isLowConfidenceGPS: position.accuracy > 40.0,
    );

// 修改为：
    state = state.copyWith(
      currentPosition: position,
      // ✅ 不在这里直接更新速度，避免跳变
      isInsActive:
          !isGpsTrulyStable && position.accuracy > AppConstants.insTriggerAccuracy,
      isLowConfidenceGPS: position.accuracy > 40.0,
    );

    // ✅ 设置目标速度（不立即显示，交给平滑滤波器处理）
    _targetSpeed = position.speed;
    _lastSpeedUpdate = now;

// ========== 修改4：recording_provider.dart 传感器数据处理 ==========
// 修改位置：第584行之后

// 原始代码：
    _insEngine.predict(sensorData);
    _motionProcessor.process(
        sensorData, state.currentSpeed, state.currentPosition, state.isInsActive);

// 修改为：
    _insEngine.predict(sensorData);
    
    // ✅ 平滑速度更新策略（消除跳变）
    if (!state.isSensorFrozen) {
      // 基础平滑系数（alpha越小越平滑，但响应越慢）
      double alpha = 0.15;  // 推荐值：6-7帧收敛到63%
      
      // 自适应策略：GPS刚更新时加快收敛
      if (_lastSpeedUpdate != null && 
          now.difference(_lastSpeedUpdate!).inMilliseconds < 100) {
        alpha = 0.3;  // GPS刚更新，快速跟随
      }
      
      // 指数移动平均：平滑地向目标速度靠近
      _smoothedSpeed = _smoothedSpeed * (1 - alpha) + _targetSpeed * alpha;
      
      // 更新state（始终更新，保证高频刷新）
      // 阈值降低到0.01 m/s（0.036 km/h），保证足够流畅
      if ((state.currentSpeed - _smoothedSpeed).abs() > 0.01) {
        state = state.copyWith(currentSpeed: _smoothedSpeed);
      }
    }
    
    _motionProcessor.process(
        sensorData, state.currentSpeed, state.currentPosition, state.isInsActive);

// ========== 修改5（可选）：初始化速度变量 ==========
// 修改位置：startRecording() 函数中（第500-510行附近）

// 在现有初始化代码后添加：
      // ✅ 初始化速度平滑变量
      _targetSpeed = state.currentPosition?.speed ?? 0.0;
      _smoothedSpeed = _targetSpeed;
      _lastSpeedUpdate = DateTime.now();

// ========== 修改6（可选）：清理速度变量 ==========
// 修改位置：stopRecording() 函数末尾（第705行附近）

// 在现有清理代码后添加：
    // ✅ 清理速度平滑变量
    _targetSpeed = 0.0;
    _smoothedSpeed = 0.0;
    _lastSpeedUpdate = null;

// ================================================================
// 参数调优指南
// ================================================================

// alpha 值调优：
// - 0.1: 非常平滑，响应慢（τ ≈ 330ms @30Hz）
// - 0.15: 平滑且响应快（τ ≈ 220ms @30Hz）✅ 推荐
// - 0.2: 响应快，略有抖动（τ ≈ 165ms @30Hz）
// - 0.3: GPS刚更新时使用（快速收敛）

// GPS快速跟随窗口：
// - 100ms: 约3帧（推荐）
// - 200ms: 约6帧（更平滑）

// ================================================================
// 测试验证
// ================================================================

// 测试1：加速场景
// 预期：速度从0平滑上升到30km/h，无跳变，耗时约0.5秒

// 测试2：减速场景
// 预期：速度从30km/h平滑下降到0，无跳变

// 测试3：匀速场景
// 预期：速度在目标值±0.2 km/h范围内微波动，无大幅跳变

// 测试4：GPS信号差
// 预期：速度仍保持平滑，不会因GPS丢失而跳变

// ================================================================
// 关键：为什么不用INS？
// ================================================================

/*
原因1：INS漂移严重
  - 加速度零偏：±0.02G
  - 5秒累积漂移：1 m/s
  - 导致融合值不稳定

原因2：GPS+INS耦合导致跳变
  - GPS更新时"拉回"INS
  - 每次拉回都是一次跳变
  
原因3：用户感知：平滑>快速
  - 人眼对"平滑"更敏感
  - 宁可慢50ms，也不要跳变

结论：纯GPS+平滑滤波器是最鲁棒的方案！
*/

// ================================================================
// 极端场景处理
// ================================================================

// 场景1：GPS长时间丢失（>3秒）
// 当前方案：速度保持最后的平滑值（可接受）
// 改进方案（可选）：添加零速检测
if (_lastSpeedUpdate != null && 
    now.difference(_lastSpeedUpdate!).inSeconds > 3) {
  // GPS丢失超过3秒，可能在隧道
  // 如果加速度接近零，可以假设匀速或减速
  if (sensorData.processedAccel.length < 0.5) {
    _targetSpeed *= 0.98;  // 缓慢衰减（模拟阻力）
  }
}

// 场景2：GPS速度突变（>5 m/s）
// 过滤异常GPS数据
if ((_targetSpeed - position.speed).abs() > 5.0) {
  debugPrint('⚠️ [Speed] GPS anomaly detected, ignored');
  // 不更新 _targetSpeed
} else {
  _targetSpeed = position.speed;
}

// ================================================================
// 电池优化（可选）
// ================================================================

// 添加用户设置：省电模式
final settings = _ref.read(settingsProvider);
final gpsInterval = settings.isPowerSavingMode 
    ? Duration(seconds: 1)      // 省电：1Hz
    : Duration(milliseconds: 500);  // 正常：2Hz

// 动态调整平滑系数
final alpha = settings.isPowerSavingMode 
    ? 0.1   // 省电模式：更平滑（补偿低频GPS）
    : 0.15;  // 正常模式

// ================================================================
// 调试日志（可选添加）
// ================================================================

// 在平滑更新代码中添加：
if (_sensorEventCount % 60 == 0) {  // 每秒输出一次
  debugPrint('🏃 [Speed] Target=${_targetSpeed.toStringAsFixed(2)} m/s, '
             'Smoothed=${_smoothedSpeed.toStringAsFixed(2)} m/s, '
             'Display=${state.currentSpeed.toStringAsFixed(2)} m/s, '
             'Alpha=$alpha');
}
