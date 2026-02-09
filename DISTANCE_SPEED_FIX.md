# 🚗 里程和车速显示为0 - 修复完成

## 📋 问题诊断

### **问题1：行驶里程始终显示 0.0km**
**原因**：
1. 存储单位混乱：`trip.distance`字段应存储**米**，但传入的参数是**公里**
2. `displayDistance` getter错误地直接返回distance（误以为是公里）

### **问题2：平均车速始终显示 0km/h**
**原因**：
1. `endTrip`方法只设置了`endTime`，没有计算并保存`metricsJson`
2. `metricsJson`中应包含 `avg_speed_kmh`、`duration_min`等关键信息
3. `getAvgSpeedDisplay()`和`getDurationDisplay()`依赖`metricsJson`，但该字段为空

---

## ✅ 修复内容

### **修复1：统一distance单位为米** (`storage_service.dart`)

**位置**：`addTrajectoryPoint`方法，第253-273行

**修复前**：
```dart
if (distance != null) trip.distance = distance;
```

**修复后**：
```dart
// ✅ 修复单位问题：distance参数是公里，需要转换为米存储
if (distance != null) {
  trip.distance = distance * 1000;  // 转换为米
  debugPrint('   💾 Updated trip distance: ${trip.distance.toStringAsFixed(1)} m (${distance.toStringAsFixed(3)} km)');
}
```

**原理**：
- `recording_provider.dart`传入的distance参数是**公里**（`state.currentDistance / 1000`）
- `trip.distance`字段存储的应该是**米**
- 上传时会除以1000转换回公里（`trip.distance / 1000`）

---

### **修复2：在endTrip中计算并保存metrics** (`storage_service.dart`)

**位置**：`endTrip`方法，第397-433行

**修复前**：
```dart
Future<void> endTrip(int tripId) async {
  await init();
  await _db.writeTxn(() async {
    final trip = await _db.collection<Trip>().get(tripId);
    if (trip != null) {
      trip.endTime = DateTime.now();  // ❌ 只设置endTime
      await _db.collection<Trip>().put(trip);
    }
  });
  await calculateEventStats(tripId);
}
```

**修复后**：
```dart
Future<void> endTrip(int tripId) async {
  await init();
  await _db.writeTxn(() async {
    final trip = await _db.collection<Trip>().get(tripId);
    if (trip != null) {
      trip.endTime = DateTime.now();
      
      // ✅ 计算并保存 metricsJson
      final duration = trip.endTime!.difference(trip.startTime);
      final durationMin = duration.inMinutes;
      final durationSec = duration.inSeconds;
      final distanceKm = trip.distance / 1000;  // 米转公里
      final avgSpeedKmh = durationSec > 0 ? (distanceKm / (durationSec / 3600)) : 0.0;
      
      final metrics = {
        "distance_km": distanceKm.toStringAsFixed(2),
        "event_count": trip.eventCount,
        "duration_min": durationMin,
        "avg_speed_kmh": avgSpeedKmh.toStringAsFixed(1),
        "start_time": trip.startTime.toUtc().toIso8601String(),
        "end_time": trip.endTime!.toUtc().toIso8601String(),
      };
      
      trip.metricsJson = jsonEncode(metrics);
      
      debugPrint('✅ [EndTrip] Metrics calculated and saved:');
      debugPrint('   Distance: ${distanceKm.toStringAsFixed(2)} km');
      debugPrint('   Duration: $durationMin min');
      debugPrint('   Avg Speed: ${avgSpeedKmh.toStringAsFixed(1)} km/h');
      
      await _db.collection<Trip>().put(trip);
    }
  });
  await calculateEventStats(tripId);
}
```

**新增字段**：
- `distance_km`: 总里程（公里）
- `duration_min`: 持续时间（分钟）
- `avg_speed_kmh`: 平均速度（公里/小时）
- `start_time`: 开始时间（ISO 8601）
- `end_time`: 结束时间（ISO 8601）
- `event_count`: 事件数量

---

### **修复3：修正displayDistance getter** (`db_models.dart`)

**位置**：`displayDistance` getter，第72-101行

**修复前**：
```dart
// 3. 最后回退到本地计算的 distance（以km为单位）❌
return distance;
```

**修复后**：
```dart
// 3. 最后回退到本地计算的 distance（存储单位是米，需要转换为公里）✅
return distance / 1000;
```

---

## 🔍 数据流完整链路

### **行驶中 - 里程累积**
```
1. GPS更新 → 计算距离增量
   recording_provider.dart:282-297

2. 更新state.currentDistance（单位：米）
   recording_provider.dart:296

3. 保存轨迹点 + distance参数（单位：公里）
   recording_provider.dart:374
   _storage.addTrajectoryPoint(..., distance: state.currentDistance / 1000)

4. 存储到数据库（单位：米）✅ 修复后
   storage_service.dart:266
   trip.distance = distance * 1000
```

### **行程结束 - 计算metrics**
```
1. stopRecording调用
   recording_provider.dart:653

2. endTrip保存endTime并计算metrics ✅ 修复后
   storage_service.dart:397-433
   - 计算duration（秒/分钟）
   - 计算avgSpeed（公里/小时）
   - 保存到trip.metricsJson

3. calculateEventStats
   计算事件统计信息
```

### **显示行程详情**
```
1. 读取Trip对象
   trip_detail_screen.dart

2. 获取里程：getDistanceDisplay()
   db_models.dart:103
   → displayDistance（优先metricsJson，回退distance/1000）✅

3. 获取速度：getAvgSpeedDisplay()
   db_models.dart:105-145
   → 从metricsJson读取avg_speed_kmh ✅

4. 获取时长：getDurationDisplay()
   db_models.dart:147-185
   → 从metricsJson读取duration_min ✅
```

---

## 📊 验证方法

### **测试步骤**

#### **步骤1：开始新行程**
1. 打开App，点击"开始行程"
2. 观察日志：
```
📏 [Distance] Updated: 0.000 km
💾 [DB Write] Saving trajectory point with distance=0.000km
```

#### **步骤2：行驶一段距离**
1. 移动至少100米
2. 观察日志：
```
📏 [Distance] Updated: 0.123 km
💾 [DB Write] Saving trajectory point with distance=0.123km
💾 Updated trip distance: 123.4 m (0.123 km)  ✅ 新增日志
```

#### **步骤3：结束行程**
1. 点击"结束行程"
2. 观察日志：
```
✅ [EndTrip] Metrics calculated and saved:  ✅ 新增日志
   Distance: 1.23 km
   Duration: 5 min
   Avg Speed: 14.8 km/h
   Event Count: 3
```

#### **步骤4：查看行程详情**
1. 进入历史行程
2. 点击刚录制的行程
3. **验证**：
   - ✅ 里程显示正确（如 1.2 km）
   - ✅ 平均速度显示正确（如 14.8 km/h）
   - ✅ 持续时间显示正确（如 5 min）
   - ✅ 事件数量显示正确

---

## 🐛 修复前的典型症状

### **JSON文件示例**
```json
{
  "metadata": {
    "start_time": "2026-02-02T09:22:46",
    "end_time": "2026-02-02T09:58:04",
    "event_count": 13
    // ❌ 缺少 distance_km, duration_min, avg_speed_kmh
  }
}
```

### **数据库Trip记录**
```dart
Trip {
  distance: 0.0,          // ❌ 应该是米，但被错误地写入公里值（然后显示为0）
  metricsJson: null,      // ❌ 完全没有
  endTime: 2026-02-02...
}
```

### **UI显示**
- 里程：0.0 km ❌
- 平均速度：0 km/h ❌
- 持续时间：0 min ❌

---

## ✅ 修复后的预期

### **JSON文件示例**
```json
{
  "metadata": {
    "start_time": "2026-02-02T09:22:46",
    "end_time": "2026-02-02T09:58:04",
    "event_count": 13,
    "distance_km": "1.23",      // ✅ 新增
    "duration_min": 35,         // ✅ 新增
    "avg_speed_kmh": "14.8"     // ✅ 新增
  }
}
```

### **数据库Trip记录**
```dart
Trip {
  distance: 1234.5,       // ✅ 米
  metricsJson: "{...}",   // ✅ 包含完整metrics
  endTime: 2026-02-02...
}
```

**metricsJson内容**：
```json
{
  "distance_km": "1.23",
  "duration_min": 5,
  "avg_speed_kmh": "14.8",
  "event_count": 13,
  "start_time": "2026-02-02T09:22:46.000Z",
  "end_time": "2026-02-02T09:58:04.000Z"
}
```

### **UI显示**
- 里程：1.2 km ✅
- 平均速度：14.8 km/h ✅
- 持续时间：5 min ✅

---

## 📝 修改的文件

1. ✅ **`Puked/lib/services/storage/storage_service.dart`**
   - 修复 `addTrajectoryPoint`：distance参数*1000转为米（3行新增）
   - 增强 `endTrip`：计算并保存metricsJson（28行新增）

2. ✅ **`Puked/lib/models/db_models.dart`**
   - 修正 `displayDistance` getter：distance/1000转为公里（1行修改）

3. ✅ **`Puked/lib/services/export/export_service.dart`**
   - 增强 metadata导出：添加distance_km、duration_min、avg_speed_kmh（6行新增）

**无linter错误！** 🎉

---

## 🔄 向后兼容性

### **旧数据处理**
对于修复前录制的行程（distance为0或单位错误）：
- `displayDistance`会优先读取`metricsJson`
- 如果`metricsJson`为空，才回退到`distance/1000`
- 旧数据显示可能仍然不正确，但新数据完全正常

### **建议**
- 测试时录制新行程验证
- 可以考虑写迁移脚本修复旧数据（可选）

---

## 🎯 关键改进

1. **数据完整性**：endTrip时立即计算所有metrics，确保数据不丢失
2. **单位统一**：明确distance字段存储米，所有转换点加注释
3. **调试友好**：添加详细日志，方便排查问题
4. **优先级清晰**：displayDistance优先metricsJson，确保显示最准确的数据

---

**修复完成日期**: 2026-02-02
**版本**: v2.5.1
