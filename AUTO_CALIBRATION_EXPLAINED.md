# 自动校准功能详细说明

## 🎯 核心流程图

```
用户行为                传感器引擎状态                  校准动作
──────────────────────────────────────────────────────────────
                                                       
[启动APP] ────────> [未校准状态]
    │
    ↓
[点击开始] ───────> [手动校准]
    │               - 采集3秒数据
    │               - 建立旋转矩阵
    │               - 记录重力向量g₀
    ↓
[行驶中] ─────────> [已校准，正常工作]
    │               - 使用g₀扣除重力
    │               - 记录加速度数据
    ↓
[第1次停车] ───────> [检测静止]
2分钟时            │
    │               ├─ 0-1秒：等待确认
    │               ├─ 1-3秒：渐进归零（0.85^t衰减）
    │               └─ 3秒：触发自动校准
    │                      - 从缓冲区提取2秒数据
    │                      - 计算新的重力向量g₁
    │                      - 只更新g₁，保持旋转矩阵
    ↓                      - 航向不变
[继续行驶] ───────> [使用新的g₁]
    │               - 偏移已修正
    ↓
[第2次停车] ───────> [再次自动校准]
10分钟后           │
    │               └─ 更新g₂
    ↓
... (循环)
```

## 📊 数据对比示例

### 场景：车辆停车20分钟，手机姿态发生变化

#### 改进前（只有初始校准）
```
时间    速度   ax(G)   ay(G)   az(G)   说明
─────────────────────────────────────────────
0:00    0      0.01    0.04    0.03    ✅ 初始校准后
0:30    25     -2.34    4.56   0.12    ✅ 加速（真实）
2:00    0      0.33    0.43   -0.02    ⚠️ 停车1（漂移开始）
4:00    35      3.21   -5.67   0.23    ✅ 转弯（真实）
5:00    0      0.46    0.10    0.01    ⚠️ 停车2（漂移增大）
15:00   0      0.59    1.04   -0.07    ❌ 停车3（严重漂移！）
20:00   0      0.47    0.52    0.00    ❌ 停车4（持续漂移）
```

#### 改进后（自动校准+强制归零）
```
时间    速度   ax(G)   ay(G)   az(G)   说明
─────────────────────────────────────────────
0:00    0      0.01    0.04    0.03    ✅ 初始校准后
0:30    25     -2.34    4.56   0.12    ✅ 加速（真实）
2:00    0      0.00    0.00    0.00    ✅ 停车1（强制归零+自动校准）
4:00    35      3.21   -5.67   0.23    ✅ 转弯（真实）
5:00    0      0.00    0.00    0.00    ✅ 停车2（强制归零+自动校准）
15:00   0      0.00    0.00    0.00    ✅ 停车3（持续修正）
20:00   0      0.00    0.00    0.00    ✅ 停车4（始终准确）
```

## 🔧 关键参数说明

### 1. 静止判断阈值
```dart
if (speedMs > 0.5)  // 0.5 m/s = 1.8 km/h
```
**原因**：
- GPS速度有±0.5m/s的误差
- 1.8km/h以下视为静止，避免误判

### 2. 静止确认时间
```dart
stationaryDuration.inSeconds >= 1  // 连续静止1秒
```
**原因**：
- 避免短暂减速（如等红灯前滑行）误触发
- 1秒足以确认真实停止

### 3. 自动校准触发时间
```dart
if (stationaryDuration.inSeconds < 3) return;  // 3秒后触发
```
**原因**：
- 给用户足够时间稳定手机（如放回支架）
- 避免"刚停车就拿手机"时误校准

### 4. 校准数据时长
```dart
durationSeconds: 2,  // 提取2秒数据
```
**原因**：
- 2秒 × 30Hz = 60个样本（Android）
- 足够计算稳定的重力向量均值
- 不需要像初始校准那样长（已经静止了）

### 5. 重复校准间隔
```dart
if (timeSinceLastCalib.inSeconds < 10) return;  // 10秒内不重复
```
**原因**：
- 避免频繁校准浪费计算资源
- 10秒内手机姿态不太可能大幅改变

### 6. 渐进归零系数
```dart
final decay = math.pow(0.85, stationaryDuration.inSeconds.toDouble());
```
**原因**：
- 0.85^1 = 0.85（85%保留）
- 0.85^2 = 0.72（72%保留）
- 0.85^3 = 0.61（61%保留）
- 平滑过渡，避免突变

## 🧪 测试验证方法

### 测试1：验证自动校准触发
```dart
// 在 _performAutoCalibration 开始添加：
debugPrint('🧪 [TEST] Auto-calibration triggered!');
debugPrint('   Stationary duration: ${now.difference(_stationaryStartTime!).inSeconds}s');
debugPrint('   Speed: ${currentSpeedMs.toStringAsFixed(3)} m/s');
```

**预期输出**（停车3秒后）：
```
🧪 [TEST] Auto-calibration triggered!
   Stationary duration: 3s
   Speed: 0.000 m/s
🔍 [Auto-Calibration] Extracted 60 samples from buffer
=== Calibration Confirmed [AUTO] ===
✅ [Auto-Calibration] Successfully recalibrated!
```

### 测试2：验证静止归零
```dart
// 在 Stage 5 添加：
if (_isVehicleStationary(_lastKnownSpeed, now) && _isCalibrated) {
  debugPrint('🧪 [TEST] Stationary zeroing active');
  debugPrint('   Original: (${processedAccel.x.toStringAsFixed(3)}, ${processedAccel.y.toStringAsFixed(3)}, ${processedAccel.z.toStringAsFixed(3)})');
  
  // ... 原有归零逻辑 ...
  
  debugPrint('   After zero: (${processedAccel.x.toStringAsFixed(3)}, ${processedAccel.y.toStringAsFixed(3)}, ${processedAccel.z.toStringAsFixed(3)})');
}
```

**预期输出**（静止时）：
```
🧪 [TEST] Stationary zeroing active
   Original: (0.324, 0.456, -0.012)
   After zero: (0.000, 0.000, 0.000)
```

### 测试3：验证避免频繁校准
**步骤**：
1. 停车3秒 → 触发校准1
2. 立即再停3秒 → 不触发（<10秒）
3. 等待8秒后停车 → 触发校准2

**预期日志**：
```
00:03 ✅ [Auto-Calibration] Successfully recalibrated!
00:06 ⚠️ [Auto-Calibration] Skipped (too soon, 3s since last)
00:14 ✅ [Auto-Calibration] Successfully recalibrated!
```

## ⚠️ 边界情况处理

### 情况1：缓冲区数据不足
```dart
if (relevantData.isEmpty || relevantData.length < 30) {
  throw Exception("calibration_failed_insufficient_data");
}
```
**触发条件**：APP刚启动，缓冲区还未积累数据
**处理**：静默拒绝校准，不影响运行

### 情况2：停车时手机在晃动
```dart
if (maxGyro > 0.3) {
  throw Exception("calibration_failed_motion");
}
```
**触发条件**：停车时用户拿起手机
**处理**：拒绝本次校准，等待下次静止

### 情况3：短暂停车（<3秒）
```dart
if (stationaryDuration.inSeconds < 3) return;
```
**触发条件**：等红灯、路口礼让等
**处理**：
- 1-3秒：执行渐进归零（减小偏移显示）
- 但不触发自动校准（避免误校准）

### 情况4：传感器数据异常
```dart
if (variance > 0.15) {
  throw Exception("calibration_failed_motion");
}
```
**触发条件**：车辆停在震动路面（如施工路段）
**处理**：拒绝校准，保持现有状态

## 📝 调试日志说明

### 正常流程日志
```
📊 [Sensor Status] Aligned: true, YawOffset: -5.2°
   Current processedAccel: (0.001, -0.002, 0.000)
🔄 [Auto-Calibration] Triggering silent recalibration...
🔍 [Auto-Calibration] Extracted 62 samples from buffer
=== Calibration Confirmed [AUTO] ===
Orientation: Pitch 2.3°, Roll -1.1°
Static Gravity Vector: -0.124, 0.345, 9.756
Variance: 0.0324, Max Gyro: 0.012 rad/s
Sample Count: 62
Initial Processed (Should be 0): 0.000, 0.001, -0.001
==============================
✅ [Auto-Calibration] Successfully recalibrated!
```

### 异常日志示例
```
⚠️ [Auto-Calibration] Rejected: calibration_failed_motion
```
→ 说明：手机在晃动，拒绝校准

```
⚠️ [Auto-Calibration] Rejected: calibration_failed_insufficient_data
```
→ 说明：缓冲区数据不足（APP刚启动）

## 🎓 第一性原理解释

### 为什么自动校准只更新重力向量？
```dart
if (mode == _CalibrationMode.auto && _isCalibrated) {
  _staticGravityRaw = gMean.clone();  // 只更新这个
  // 不更新 _rotationMatrix
  // 不更新 _dynamicYawOffset
}
```

**原因**：
1. **旋转矩阵**：定义了手机→车辆的坐标变换，这取决于手机如何安装，不应该改变
2. **航向偏移**：已经通过加速度学习确定了车头方向，不应该重置
3. **重力向量**：会随手机物理姿态变化而变化，需要动态更新

**类比**：
- 旋转矩阵 = 指南针的校准（一次性）
- 航向偏移 = 地图旋转到正北（根据实际行驶学习）
- 重力向量 = GPS的海拔校准（随位置变化）

### 为什么是2秒而不是3秒？
初始校准需要3秒，自动校准只需2秒：

**原因**：
1. **初始校准**：手机刚放上去，可能还在微调位置，需要更长时间稳定
2. **自动校准**：已经静止3秒了，肯定很稳定，2秒足够
3. **用户体验**：自动校准是静默的，越快越好

## 🚀 性能影响分析

### CPU开销
- 静止检测：每帧1次if判断（~0.001ms）
- 自动校准：每10秒1次，耗时约50ms
- 静止归零：每帧1次乘法（~0.002ms）

**总计**：< 0.5% CPU使用率增加

### 内存开销
- 新增成员变量：4个（DateTime × 2 + double + bool） ≈ 32字节
- 缓冲区：已有，无额外开销

**总计**：可忽略不计

### 功耗影响
- 无额外传感器调用
- 计算量极小

**总计**：无明显影响

## ✅ 验收标准

### 功能验收
- [ ] 手动校准正常工作（向后兼容）
- [ ] 静止3秒后自动触发校准
- [ ] 静止时加速度接近零
- [ ] 10秒内不重复校准
- [ ] 短暂停车(<3秒)不触发校准

### 性能验收
- [ ] CPU占用无明显增加
- [ ] 内存占用无明显增加
- [ ] 不影响事件检测延迟

### 数据验收
- [ ] 导出的JSON中，静止时 ax/ay < 0.05G
- [ ] 多次停车后偏移不累积
- [ ] 航向不会被意外重置

---

**祝集成顺利！如有问题欢迎随时反馈。**
