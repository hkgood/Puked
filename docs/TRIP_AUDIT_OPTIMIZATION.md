# 行程审核逻辑优化文档

## 📅 更新时间
2026-02-05

## 🎯 优化目标
修复和完善行程上传时的智能审核逻辑，准确识别异常行程，避免将异常数据纳入统计系统。

---

## 🐛 修复的关键问题

### 逻辑错误：负体验密度判断反了
**原来的错误逻辑：**
```dart
// ❌ 错误：过滤了路况好的数据（每5公里少于1次事件）
if (kmPerEvent > 5) {
  isAbnormal = true;
  abnormalReason = '负体验密度过低';
}
```

**修复后的正确逻辑：**
```dart
// ✅ 正确：过滤负体验过于密集的数据（每公里超过2次事件）
final eventsPerKm = eventCount / distanceKm;
if (eventsPerKm > 2.0) {
  isAbnormal = true;
  abnormalReason = '负体验密度异常高 (${eventsPerKm.toStringAsFixed(2)} 次/km)';
}
```

**影响：** 之前的逻辑会错误地将路况良好的行程标记为异常，导致大量高质量数据无法进入统计系统。

---

## ✅ 新增的异常检测规则

### P0 级别检测（逻辑错误修复）

#### 1. 平均时速过高
```dart
if (avgSpeed > 120) {
  isAbnormal = true;
  abnormalReason = '平均时速异常高 (${avgSpeed.toStringAsFixed(1)} km/h)';
}
```
**原因：** GPS 漂移、数据错误、极端驾驶

#### 2. 平均时速过低 ⭐ **新增**
```dart
if (avgSpeed < 5 && distanceKm > 0.5) {
  isAbnormal = true;
  abnormalReason = '平均时速异常低 (${avgSpeed.toStringAsFixed(1)} km/h)';
}
```
**原因：** 停车状态误录、GPS 漂移

#### 3. 负体验密度过高 ⭐ **修复**
```dart
final eventsPerKm = eventCount / distanceKm;
if (eventsPerKm > 2.0) {
  isAbnormal = true;
  abnormalReason = '负体验密度异常高 (${eventsPerKm.toStringAsFixed(2)} 次/km)';
}
```
**阈值：** 每公里超过 2 次事件  
**原因：** 传感器故障、算法过于敏感

---

### P1 级别检测（常见异常场景）

#### 4. 行程距离过短 ⭐ **新增**
```dart
if (distanceKm < 0.5) {
  isAbnormal = true;
  abnormalReason = '行程距离过短 (${distanceKm.toStringAsFixed(2)} km)';
}
```
**阈值：** 小于 0.5 km（500 米）  
**原因：** 测试数据、误触发

#### 5. 行程时长过短 ⭐ **新增**
```dart
if (durationMin < 3 && distanceKm > 0.5) {
  isAbnormal = true;
  abnormalReason = '行程时长过短 (${durationMin} 分钟)';
}
```
**阈值：** 少于 3 分钟  
**原因：** 误触发、不完整数据

#### 6. 长距离零事件 ⭐ **新增**
```dart
if (distanceKm > 10 && eventCount == 0) {
  isAbnormal = true;
  abnormalReason = '长距离零事件 (${distanceKm.toStringAsFixed(1)} km)';
}
```
**阈值：** 超过 10 km 但没有任何事件  
**原因：** 传感器失效、检测算法未运行

#### 7. 短时间内事件爆发 ⭐ **新增**
```dart
if (eventCount > 5) {
  final burstEvents = _detectEventBurst(trip.events.toList());
  if (burstEvents > 5) {
    isAbnormal = true;
    abnormalReason = '短时间内事件爆发 (20秒内${burstEvents}个事件)';
  }
}
```
**阈值：** 连续 20 秒内超过 5 个事件  
**原因：** 传感器故障、算法过于敏感、颠簸路段误检测  
**实现：** 使用滑动窗口算法检测事件密集程度

---

## 🔧 技术实现细节

### 事件爆发检测算法
```dart
int _detectEventBurst(List<RecordedEvent> events) {
  if (events.length < 6) return 0;
  
  // 按时间戳排序事件
  final sortedEvents = events.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  
  int maxBurstCount = 0;
  const burstWindowSeconds = 20;
  
  // 滑动窗口检测
  for (int i = 0; i < sortedEvents.length; i++) {
    final windowStart = sortedEvents[i].timestamp;
    final windowEnd = windowStart.add(const Duration(seconds: burstWindowSeconds));
    
    int burstCount = 0;
    for (int j = i; j < sortedEvents.length; j++) {
      if (sortedEvents[j].timestamp.isBefore(windowEnd)) {
        burstCount++;
      } else {
        break;
      }
    }
    
    if (burstCount > maxBurstCount) {
      maxBurstCount = burstCount;
    }
    
    // 优化：如果已经找到足够大的爆发，提前退出
    if (maxBurstCount > 10) break;
  }
  
  return maxBurstCount;
}
```

**算法特点：**
- 时间复杂度：O(n²) 最坏情况，但通过提前退出优化
- 空间复杂度：O(n) 用于排序
- 使用 20 秒滑动窗口
- 返回窗口内的最大事件数

---

## 📊 异常检测规则汇总表

| 规则 | 类型 | 阈值 | 优先级 | 状态 |
|------|------|------|--------|------|
| 平均时速过高 | 速度异常 | > 120 km/h | P0 | ✅ 已有 |
| 平均时速过低 | 速度异常 | < 5 km/h (且距离>0.5km) | P0 | ⭐ 新增 |
| 负体验密度过高 | 密度异常 | > 2 次/km | P0 | ⭐ 修复 |
| 行程距离过短 | 数据质量 | < 0.5 km | P1 | ⭐ 新增 |
| 行程时长过短 | 数据质量 | < 3 分钟 (且距离>0.5km) | P1 | ⭐ 新增 |
| 长距离零事件 | 传感器异常 | > 10 km 且事件=0 | P1 | ⭐ 新增 |
| 短时间事件爆发 | 密度异常 | 20秒内>5个事件 | P1 | ⭐ 新增 |

---

## 🎯 预期效果

### 修复前的问题：
1. ❌ 高质量路况数据被错误过滤
2. ❌ 低速停车误录数据未被过滤
3. ❌ 测试数据（距离短、时间短）混入统计
4. ❌ 传感器故障数据（事件爆发）未被识别
5. ❌ 传感器失效数据（长距离零事件）未被识别

### 修复后的效果：
1. ✅ 保留路况良好的高质量数据
2. ✅ 过滤低速停车误录数据
3. ✅ 过滤测试数据和不完整数据
4. ✅ 识别传感器故障导致的事件爆发
5. ✅ 识别传感器失效导致的零事件行程
6. ✅ 提高统计数据的准确性和可靠性

---

## 🔄 后续优化建议（可选）

### P2 级别优化（精细化检测）

1. **分场景动态阈值**
   - 高速场景（时速 > 80 km/h）：事件密度阈值调整为 1.0 次/km
   - 城市场景（时速 < 50 km/h）：事件密度阈值保持 2.0 次/km

2. **特定事件类型占比检测**
   - Bump 事件占比过高（> 80%）：可能是颠簸路段检测过敏
   - 急加速/急减速过于频繁（> 3 次/km）

3. **用户信誉度系统**
   - 对已验证可靠用户，自动通过审核
   - 对特定品牌/版本数据，调整审核策略

4. **时速阈值优化**
   - 考虑将 120 km/h 调整为 150 km/h
   - 避免误杀高速公路正常行程

---

## 📝 修改文件清单

- ✅ `/Puked/lib/services/cloud_trip_service.dart`
  - 修复负体验密度逻辑（第 88-96 行）
  - 新增平均时速过低检测（第 81-86 行）
  - 新增行程距离过短检测（第 100-105 行）
  - 新增行程时长过短检测（第 107-112 行）
  - 新增长距离零事件检测（第 114-119 行）
  - 新增短时间事件爆发检测（第 121-129 行）
  - 新增事件爆发检测算法（第 587-621 行）

---

## 🧪 测试建议

### 应该通过审核的行程（is_public = true）：
- ✅ 高速行程：100 km/h，50 km，10 个事件
- ✅ 城市行程：30 km/h，10 km，15 个事件
- ✅ 平稳行程：60 km/h，20 km，5 个事件

### 应该被标记为待审核的行程（is_public = false）：
- ❌ 时速异常高：150 km/h
- ❌ 时速异常低：2 km/h，1 km
- ❌ 事件密度过高：10 km，25 个事件（2.5 次/km）
- ❌ 距离过短：0.3 km
- ❌ 时长过短：2 分钟，1 km
- ❌ 长距离零事件：20 km，0 个事件
- ❌ 事件爆发：20 秒内 8 个事件

---

## 📞 联系与反馈

如发现新的异常行程模式，请及时更新此文档并调整检测规则。

**最后更新：** 2026-02-05  
**版本：** v2.0  
**维护者：** Rocky
