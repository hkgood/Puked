# Sensor Engine 自动校准功能集成指南

## 概述
本次修改实现了"车辆静止时自动校准 + 静止强制归零"的鲁棒性方案。

## 核心设计思路

1. **静止检测**：连续静止1秒后开始计时
2. **自动校准触发**：静止3秒后，从缓冲区提取最近2秒数据进行校准
3. **静止归零**：静止1-3秒渐进式衰减，>3秒强制归零
4. **避免频繁校准**：10秒内不重复校准
5. **统一校准内核**：手动和自动模式复用同一套校准逻辑

## 修改步骤

### 步骤1：在 `_processTick` 中添加静止检测（第144行后）

**位置**：在 `smoothedAccel = prev.clone();` 之后

**添加代码**：
```dart
    // ✅ 新增：静止检测与自动校准触发
    _checkStationaryAndTriggerAutoCalibration(_lastKnownSpeed, now);
```

### 步骤2：添加静止强制归零逻辑（第166行后）

**位置**：在 `processedAccel.y += (rotatedGyro.x * 0.3).clamp(-0.8, 0.8);` 之后

**添加代码**：
```dart
    // ✅ Stage 5: 静止时强制归零（鲁棒性增强）
    if (_isVehicleStationary(_lastKnownSpeed, now) && _isCalibrated) {
      final stationaryDuration = now.difference(_stationaryStartTime!);
      
      // 渐进式归零：静止1-3秒，指数衰减
      if (stationaryDuration.inSeconds < 3) {
        final decay = math.pow(0.85, stationaryDuration.inSeconds.toDouble());
        processedAccel *= decay;
      } 
      // 强制归零：静止超过3秒
      else {
        processedAccel = Vector3.zero();
      }
    }
```

### 步骤3：添加枚举定义（第369行前）

**位置**：在 `/// 顶级校准逻辑...` 注释之前

**添加代码**：
```dart
  /// ✅ 校准模式枚举
  enum _CalibrationMode {
    manual,  // 手动校准：用户点击按钮，等待采集
    auto,    // 自动校准：从缓冲区提取数据
  }
```

### 步骤4：替换 calibrate 函数（第370-472行）

**原始函数签名**：
```dart
Future<void> calibrate({double currentSpeedMs = 0.0}) async {
```

**新的实现**：参见 sensor_engine_additions.dart 文件中第38行开始的完整实现

**关键改动**：
1. 原 `calibrate` 函数变为简单的调用入口
2. 新增 `_calibrateInternal` 函数作为统一内核
3. 支持两种模式：
   - `_CalibrationMode.manual`：实时采集数据（原逻辑）
   - `_CalibrationMode.auto`：从缓冲区提取数据（新增）
4. 自动模式只更新重力向量，不重置航向

## 需要外部传递速度信息

为了让 `_processTick` 能够进行静止检测，需要从外部传入当前速度。

### 修改方案：添加 `updateSpeed` 方法

**在 SensorEngine 类中添加**：
```dart
  /// ✅ 更新当前速度（供静止检测使用）
  void updateSpeed(double speedMs) {
    _lastKnownSpeed = speedMs;
  }
```

### 在 RecordingProvider 中调用

**在 `_onLocationUpdate` 方法中**：
```dart
void _onLocationUpdate(Position position) {
  // ... 现有逻辑 ...
  
  // ✅ 更新传感器引擎的速度状态
  _engine.updateSpeed(position.speed);
  
  // ... 后续逻辑 ...
}
```

## 测试验证

### 测试场景1：手动校准（保持现有行为）
1. 点击"开始"按钮
2. 等待3.5秒
3. 校准完成
4. 验证：日志显示 `[MANUAL]`

### 测试场景2：自动校准
1. 行程中途停车
2. 保持静止3秒
3. 自动触发校准
4. 验证：日志显示 `[AUTO]` + 提取样本数量

### 测试场景3：静止归零
1. 校准后静止
2. 1-3秒：加速度渐进衰减
3. >3秒：加速度归零
4. 验证：JSON导出数据中静止时 ax/ay/az 接近0

### 测试场景4：避免误校准
1. 短暂静止(<3秒)然后移动
2. 验证：不触发自动校准
3. 10秒内多次静止
4. 验证：只执行一次校准

## 预期效果

### 改进前（当前状态）
- 静止时：ax=0.3-0.5G, ay=0.4-1.2G（手机姿态变化导致）
- 漂移：随时间累积，20分钟后可达1.5G

### 改进后
- 静止时：ax≈0G, ay≈0G（强制归零）
- 漂移：每次停车自动修正，始终保持<0.05G

## 回滚方案

如果出现问题，可以：
1. 注释掉步骤1和步骤2的新增代码
2. 保留步骤3和步骤4（不影响现有功能）
3. 系统将退化为原始的单次校准模式

## 备份

原始文件已备份至：
`/Users/rocky/Documents/PukedMaster/Puked/lib/features/recording/domain/sensor_engine.dart.backup`

## 完整代码参考

所有新增代码已整理至：
`/Users/rocky/Documents/PukedMaster/sensor_engine_additions.dart`

请参照该文件进行手动集成。
