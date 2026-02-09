# 速度跳变问题深度分析 - 第一性原理

## 🚨 **问题重现：为什么会跳变？**

### **场景模拟**

```
时刻     GPS速度    INS速度    融合后     问题
───────────────────────────────────────────────
0.0s     0 m/s      0 m/s      0 m/s      ✅ 初始
0.5s     (无更新)   2 m/s      1.4 m/s    ⚠️ INS漂移
1.0s     (无更新)   4 m/s      3.2 m/s    ⚠️ 继续漂移
1.5s     (无更新)   6 m/s      5.2 m/s    ⚠️ 严重漂移
2.0s     2.5 m/s    6 m/s      3.7 m/s    ❌ GPS拉回，跳变！
         (真值)     (漂移)     (突降)     
```

**跳变量**：5.2 → 3.7 = **-1.5 m/s = -5.4 km/h** 的突然下降！

---

## 🔬 **第一性原理分析：跳变的根本原因**

### **问题1：INS速度漂移严重**

```127:154:Puked/lib/features/recording/domain/ins_engine.dart
      _vel += cappedAccNav * dt;
      
      // 应用自然阻尼
      if (_vel.length > 0.1) {
        _vel *= _velocityDamping;  // 0.95
      }
```

**漂移来源**：
1. **加速度零偏**：±0.02G（你刚发现的静止偏移问题）
   - 0.02G = 0.2 m/s²
   - 5秒累积：0.2 × 5 = **1 m/s 漂移**

2. **阻尼不足**：
   - 0.95^30 = 0.214（1秒后衰减到21%）
   - 但如果持续有加速度输入，衰减无效

---

### **问题2：GPS速度本身有噪声**

```
GPS速度测量：多普勒效应
精度：±0.1-0.5 m/s（高斯白噪声）

真实速度：5.0 m/s
GPS测量：4.8 → 5.2 → 4.9 → 5.1 m/s（来回跳）
```

---

### **问题3：两个噪声源耦合**

```
融合公式：v = v_gps × 0.5 + v_ins × 0.5

当GPS更新时：
t=1.9s: v_gps=5.0(旧), v_ins=6.0(漂移) → fused=5.5
t=2.0s: v_gps=4.8(新), v_ins=6.0(未变) → fused=5.4  ⬇️ 跳变
t=2.1s: v_gps=4.8(旧), v_ins=5.9(被拉回) → fused=5.35 ⬇️ 又跳
```

**每次GPS更新都会引起连锁跳变！**

---

## ✅ **正确的解决方案：目标-平滑分离**

### **核心思想**

```
GPS更新（低频） → 设置目标速度
传感器tick（高频） → 平滑地向目标靠近

不要混合两个不同频率的噪声源！
```

### **代码实现**

#### **修改1：添加成员变量**
```dart
// recording_provider.dart 第157行附近
double _targetSpeed = 0.0;      // GPS给定的目标速度
double _smoothedSpeed = 0.0;    // 平滑后的显示速度
DateTime? _lastSpeedUpdate;
```

#### **修改2：GPS更新时只设目标**
```dart
// recording_provider.dart 第301-307行
state = state.copyWith(
  currentPosition: position,
  // ❌ 删除：currentSpeed: position.speed,
  isInsActive: !isGpsTrulyStable && position.accuracy > AppConstants.insTriggerAccuracy,
  isLowConfidenceGPS: position.accuracy > 40.0,
);

// ✅ 新增：设置目标速度
_targetSpeed = position.speed;
_lastSpeedUpdate = now;
```

#### **修改3：传感器tick中平滑更新**
```dart
// recording_provider.dart 第584行之后
_insEngine.predict(sensorData);

// ✅ 平滑速度更新（消除跳变）
if (!state.isSensorFrozen) {
  // 基础平滑系数
  double alpha = 0.15;
  
  // GPS刚更新时加快收敛
  if (_lastSpeedUpdate != null && 
      now.difference(_lastSpeedUpdate!).inMilliseconds < 100) {
    alpha = 0.3;
  }
  
  // 指数移动平均
  _smoothedSpeed = _smoothedSpeed * (1 - alpha) + _targetSpeed * alpha;
  
  // 更新state
  if ((state.currentSpeed - _smoothedSpeed).abs() > 0.01) {
    state = state.copyWith(currentSpeed: _smoothedSpeed);
  }
}

_motionProcessor.process(
    sensorData, state.currentSpeed, state.currentPosition, state.isInsActive);
```

---

## 📊 **效果对比**

### **原方案（跳变）**
```
速度(m/s)
  6 |     ╱╲
    |    ╱  ╲╱╲
  5 |   ╱      ╲╱╲
    |  ╱          ╲
  4 | ╱            ╲
    |╱______________╲________
  0 └────────────────────────> 时间
    跳动、不平滑
```

### **新方案（平滑）**
```
速度(m/s)
  6 |      ╱──╲
    |     ╱    ╲
  5 |    ╱      ╲
    |   ╱        ╲
  4 |  ╱          ╲
    | ╱____________╲________
  0 └────────────────────────> 时间
    平滑、连续
```

---

## 🎯 **为什么这个方案不会跳变？**

### **数学证明**

**指数移动平均的收敛性：**
```
v[n] = v[n-1] × (1-α) + target × α

设 target 突变：5.0 → 4.8
v[0] = 5.0
v[1] = 5.0 × 0.85 + 4.8 × 0.15 = 4.97  ⬇️ 0.03
v[2] = 4.97 × 0.85 + 4.8 × 0.15 = 4.945 ⬇️ 0.025
v[3] = 4.945 × 0.85 + 4.8 × 0.15 = 4.92 ⬇️ 0.025
...

单调收敛，无跳变！
```

---

## ⚠️ **为什么不用INS？**

### **INS的问题：漂移无法避免**

1. **加速度零偏**：±0.02G（静止偏移）
2. **姿态累积误差**：陀螺仪零偏导致
3. **数值积分误差**：浮点数精度损失

**即使GPS每500ms修正，INS仍会在这500ms内漂移0.1-0.5 m/s**

### **用户感知**

```
场景：匀速行驶30km/h

纯GPS+平滑：
29.8 → 30.0 → 30.1 → 30.0 → 29.9 km/h
感觉：稳定，小幅波动（±0.2 km/h）

GPS+INS融合：
29.5 → 31.2 → 29.8 → 30.5 → 29.3 km/h
感觉：跳动，不稳定（±1 km/h）
```

**结论：平滑>快速**（人眼对平滑更敏感）

---

## 🏆 **最终推荐方案**

### **配置参数**

```dart
// location_service.dart
intervalDuration: Duration(milliseconds: 500)  // GPS间隔

// recording_provider.dart
alpha = 0.15           // 平滑系数（推荐）
updateThreshold = 0.01 // 更新阈值（m/s）
```

### **预期效果**

| 指标 | 优化前 | 优化后 |
|------|--------|--------|
| 响应延迟 | 2000ms | 500ms |
| 速度跳变 | 无（但冻结） | 无（平滑） |
| 刷新率 | 0.5 Hz | 30-60 Hz |
| 视觉平滑度 | 差 | 优秀 |
| 鲁棒性 | 中 | 高 |

---

**总结：不要试图融合INS和GPS，而是让GPS设定目标，平滑滤波器提供连续性！**
