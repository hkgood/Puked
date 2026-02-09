# 速度平滑修改 - 修改前完整检查清单

## 一、修改范围与依赖关系

### 1.1 涉及文件
| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `Puked/lib/services/location_service.dart` | 1 处 | Android GPS 间隔 2s → 500ms |
| `Puked/lib/features/recording/providers/recording_provider.dart` | 多处 | 增加平滑变量、GPS/传感器逻辑、初始化与清理 |

### 1.2 依赖 `state.currentSpeed` 的所有位置（必须一致）

| 位置 | 用途 | 修改后行为 |
|------|------|------------|
| **recording_provider 303** | `_handlePositionUpdate` 里 `copyWith(currentSpeed: position.speed)` | 删除，改为只设 `_targetSpeed` |
| **recording_provider 386-407** | `_handleInsTick()` 里 `currentSpeed: _insEngine.currentSpeed` | 保留：INS 激活时仍用 INS 速度覆盖 |
| **recording_provider 586** | `_motionProcessor.process(..., state.currentSpeed, ...)` | 改为传入平滑后的速度 |
| **recording_provider 600-602** | `displaySpeed` 写轨迹点 speed | 不改为平滑值，保持「INS 时用 INS，否则用 position.speed」 |
| **recording_provider 694** | `stopRecording` 里 `currentSpeed: 0.0` | 保留 |
| **recording_screen 701** | UI 显示速度 (km/h) | 显示的是 state.currentSpeed，即平滑值 ✅ |
| **stats_capsule 51** | UI 显示速度 (km/h) | 同上 ✅ |
| **tagEvent 429** | `event.speed = speed ?? _insEngine.currentSpeed` | 不直接用 state.currentSpeed，由 MotionProcessor 回调传入的 speed 决定，逻辑不变 ✅ |

结论：  
- 只有「谁写入 `state.currentSpeed`」会变：从「仅 GPS / 仅 INS」改为「非 INS 时=平滑值，INS 时=INS」。  
- 读 currentSpeed 的 UI 和 MotionProcessor 会自然得到平滑或 INS，无需改调用方。

---

## 二、潜在问题与边界情况

### 2.1 首次 GPS 之前（尚未收到任何 position）

- **现象**：`_targetSpeed`、`_smoothedSpeed` 未初始化，或为 0。
- **当前**：未录制的初始 state.currentSpeed = 0，合理。
- **修改后**：  
  - 仅在「开始录制」时做一次初始化：`_targetSpeed = state.currentPosition?.speed ?? 0`，`_smoothedSpeed = _targetSpeed`。  
  - 若用户先开 APP、后点开始，第一次 GPS 可能在 startRecording 之前就触发，此时只更新 `_targetSpeed`，不写 state（因为未录制）；startRecording 里用 `state.currentPosition?.speed ?? 0` 初始化平滑，逻辑一致。
- **风险**：无。需保证 startRecording 里确实做上述初始化。

### 2.2 首次 GPS 在开始录制之后到达

- **现象**：第一次 `_handlePositionUpdate` 时已 isRecording，但尚未有过任何 speed 更新。
- **当前**：copyWith(currentSpeed: position.speed)，显示即 GPS。
- **修改后**：不 copyWith currentSpeed，只设 `_targetSpeed = position.speed`。若之前未初始化过 `_smoothedSpeed`，则第一帧传感器里会用 `_smoothedSpeed * (1-alpha) + _targetSpeed * alpha`，此时 `_smoothedSpeed` 若仍为 0，会从 0 向 target 收敛，首帧会有从 0 到某值的跳变。
- **处理**：在 `_handlePositionUpdate` 里，当「本次是第一次设目标」时（例如用 `_lastSpeedUpdate == null` 判断），同时设 `_smoothedSpeed = position.speed`，避免首帧从 0 跳变。
- **风险**：若不做「首次目标时对齐 _smoothedSpeed」，会有一次 0→GPS 的跳变。

### 2.3 未录制时收到 GPS

- **现象**：未录制时也会调 `_handlePositionUpdate`，会写 `_targetSpeed`、`_lastSpeedUpdate`，但不会跑 `_handleSensorData`，故不会更新 `_smoothedSpeed`。
- **影响**：下次 startRecording 时用 `state.currentPosition?.speed ?? 0` 和显式初始化 `_targetSpeed`/`_smoothedSpeed`，不会用到「未录制期间」的 _smoothedSpeed。
- **结论**：无问题，只需 startRecording 里强制初始化一次。

### 2.4 INS 激活与退出（隧道 / 地库）

- **进入 INS**：  
  - 仍由 `_handleInsTick()` 写 `state.currentSpeed = _insEngine.currentSpeed`。  
  - 平滑逻辑若在「非 INS」分支里更新 currentSpeed，则不会覆盖 INS 的写入；若在同一处写 currentSpeed，必须保证**仅当 !state.isInsActive 时才用平滑值写 state.currentSpeed**，否则会与 _handleInsTick 冲突。
- **退出 INS**：  
  - 第一次 GPS 回来时设 `_targetSpeed = position.speed`。  
  - 此时若直接开始平滑，`_smoothedSpeed` 可能还是「进隧道前」的旧值，会从旧值向新 GPS 收敛；而 state.currentSpeed 当前是 INS 值（偏大或偏小），会有一帧被平滑值覆盖，可能产生从「INS 值」到「旧 _smoothedSpeed」的跳变。
- **处理**：在 `_handlePositionUpdate` 里，当**本次由 INS 变为非 INS**（例如 `wasInsActive == true` 且新 state 里 isInsActive == false）时，在设置 `_targetSpeed` 后，同时设 `_smoothedSpeed = state.currentSpeed`（当前 state.currentSpeed 仍是 INS 值）。这样平滑从「当前显示的 INS 速度」向新 GPS 收敛，避免退出 INS 时的明显跳变。
- **风险**：不处理会有一帧或短时「从 INS 跳到旧平滑值」的负体验。

### 2.5 传感器冻结 (isSensorFrozen)

- **现象**：`_handleSensorData` 里若 `isFrozen` 会 return，不执行平滑更新。
- **影响**：冻结期间 state.currentSpeed 保持上次值，_targetSpeed 仍可能被 GPS 更新。
- **结论**：可接受；解冻后下一帧会用最新 _targetSpeed 继续平滑。无需额外逻辑。

### 2.6 GPS 异常值（NaN、Inf、负值、极大值）

- **现象**：部分设备 `position.speed` 可能 NaN、Inf、负值或极大（如 1000 m/s）。
- **影响**：若直接 `_targetSpeed = position.speed`，会污染 _smoothedSpeed 和 state.currentSpeed。
- **处理**：  
  - 仅当 `position.speed.isFinite()` 且 `position.speed >= 0` 且 `position.speed <= 某上限`（如 150 m/s ≈ 540 km/h）时才更新 `_targetSpeed`；否则保留上一帧的 _targetSpeed 或跳过本次更新。
- **风险**：不校验会导致界面或事件检测出现异常速度。

### 2.7 轨迹点与导出中的 speed 字段

- **当前**：`displaySpeed = state.isInsActive ? _insEngine.currentSpeed : (state.currentPosition?.speed ?? 0.0)`，写入 TrajectoryPoint.speed；1Hz 轨迹点用 `position.speed`。
- **选择**：  
  - A) 存储继续用「原始」GPS/INS，便于事后分析。  
  - B) 存储用 state.currentSpeed（平滑值），与 UI 一致。  
- **建议**：保持 A，不改为平滑值，避免改变导出数据语义；若产品希望「导出与 UI 一致」再改为 B 并单独说明。

### 2.8 SensorEngine 的静止检测与自动校准

- **现状**：SensorEngine 内有 `_lastKnownSpeed` 和 `_checkStationaryAndTriggerAutoCalibration(speedMs, now)`，但 **当前 `_processTick` 并未调用该函数**，RecordingProvider 也未向 Engine 传入速度，因此自动校准逻辑目前未生效。
- **若将来启用自动校准**：  
  - 在 SensorEngine 中增加 `void updateSpeed(double speedMs)`，赋给 `_lastKnownSpeed`；  
  - 在 `_processTick` 末尾调用 `_checkStationaryAndTriggerAutoCalibration(_lastKnownSpeed, timestamp)`；  
  - 在 RecordingProvider 的 `_handleSensorData` 里，在更新完 state.currentSpeed 后调用 `_engine.updateSpeed(state.currentSpeed)`，这样静止判断与 UI 速度一致。
- **本次修改**：速度平滑不依赖 SensorEngine，可暂不实现 updateSpeed 与上述调用；若你已计划启用自动校准，可一并加上。
- **风险**：若将来启用自动校准但未传速，Engine 内 _lastKnownSpeed 会一直为 0，静止判断会错误（一直视为静止或永远不满足 3 秒）。

### 2.9 startRecording / stopRecording 的初始化与清理

- **startRecording**：  
  - 在设置 currentTrip、isRecording 等之后，增加：  
    - `_targetSpeed = state.currentPosition?.speed ?? 0.0`  
    - `_smoothedSpeed = _targetSpeed`  
    - `_lastSpeedUpdate = DateTime.now()`  
  - 这样每次新行程都从「当前 GPS 速度」开始平滑，无上一行程残留。
- **stopRecording**：  
  - 在现有清理（_lastValidGpsPosition、_lastReliableGpsPosition 等）后增加：  
    - `_targetSpeed = 0.0`  
    - `_smoothedSpeed = 0.0`  
    - `_lastSpeedUpdate = null`  
  - 避免下次未录制或下次 startRecording 前误用旧值。
- **风险**：漏初始化会导致首段速度异常；漏清理会导致跨行程状态污染。

### 2.10 与 copyWith 的配合

- **修改**：`_handlePositionUpdate` 里不再 `copyWith(currentSpeed: position.speed)`，即 state 中 currentSpeed 在此处不变。
- **注意**：copyWith 其他字段（currentPosition、isInsActive、isLowConfidenceGPS）照常；仅去掉 currentSpeed 的写入，避免与平滑逻辑冲突。
- **风险**：若误在其他分支再次写入 currentSpeed，可能覆盖平滑结果，需保证「非 INS 时只有 _handleSensorData 里写 currentSpeed」。

### 2.11 平滑只应在「非 INS」时写 state.currentSpeed

- **逻辑**：  
  - 若 `state.isInsActive == true`：由 `_handleInsTick()` 负责写 `state.currentSpeed`，平滑逻辑不应再写。  
  - 若 `state.isInsActive == false`：用 `_smoothedSpeed` 更新 `state.currentSpeed`。
- **实现**：在「计算 _smoothedSpeed 并写 state」的代码块外加 `if (!state.isInsActive) { ... }`，这样 INS 激活时完全由 _handleInsTick 控制速度。
- **风险**：若在 INS 时也写 state.currentSpeed，会与 _handleInsTick 同帧或下一帧覆盖，产生抖动或逻辑混乱。

### 2.12 Location 仅改 Android

- **修改**：仅 AndroidSettings 的 `intervalDuration` 从 2 秒改为 500ms；AppleSettings 无 intervalDuration，不改。
- **风险**：无；iOS 行为保持不变。

### 2.13 平滑系数与更新阈值

- **alpha**：建议 0.15；过大响应快但易抖，过小平滑但迟滞。  
- **更新阈值**：仅当 `(state.currentSpeed - _smoothedSpeed).abs() > 0.01` 才 copyWith(currentSpeed: _smoothedSpeed)，减少无意义重建。  
- **首帧快速收敛**：`_lastSpeedUpdate` 与 now 差 < 100ms 时用更大 alpha（如 0.3），仅影响刚收到 GPS 的几帧，避免长时间滞后感。

---

## 三、执行顺序与代码位置汇总

1. **location_service.dart**  
   - 第 32 行：`intervalDuration: const Duration(seconds: 2)` → `Duration(milliseconds: 500)`（仅 Android）。

2. **recording_provider.dart**  
   - 成员变量（约 157 行后）：增加 `_targetSpeed`、`_smoothedSpeed`、`_lastSpeedUpdate`。  
   - `_handlePositionUpdate`：  
     - 去掉 `currentSpeed: position.speed`；  
     - 对 position.speed 做合法性检查后设 `_targetSpeed`；  
     - 若 `_lastSpeedUpdate == null`，同时设 `_smoothedSpeed = position.speed`；  
     - 若「之前 isInsActive 且本次将变为非 INS」，设 `_smoothedSpeed = state.currentSpeed`；  
     - 设置 `_lastSpeedUpdate = now`。  
   - `_handleSensorData`：  
     - 在 `if (!state.isRecording) return;` 及 isFrozen 之后；  
     - 仅当 `!state.isInsActive` 时：用 _targetSpeed 更新 _smoothedSpeed（含 alpha、首 100ms 加大 alpha），再按阈值更新 state.currentSpeed；  
     - 若已实现 SensorEngine 自动校准：在此处调用 `_engine.updateSpeed(state.currentSpeed)`（需 Engine 暴露 updateSpeed）。  
   - `startRecording`：在现有初始化后增加 _targetSpeed、_smoothedSpeed、_lastSpeedUpdate 的初始化。  
   - `stopRecording`：在现有清理后增加 _targetSpeed、_smoothedSpeed、_lastSpeedUpdate 的清理。

3. **SensorEngine（可选）**  
   - 若自动校准已启用且需要正确静止判断：增加 `void updateSpeed(double speedMs)`，赋给 `_lastKnownSpeed`；RecordingProvider 在更新完 state.currentSpeed 后调用。

---

## 四、确认项（请你逐条确认）

- [ ] **1** 仅 Android 修改 GPS 间隔为 500ms，iOS 不改。  
- [ ] **2** 非 INS 时显示与事件检测统一使用「平滑速度」；INS 时仍完全使用 INS 速度。  
- [ ] **3** 轨迹点/导出的 speed 保持「原始 GPS 或 INS」，不改为平滑值（除非你明确要求一致）。  
- [ ] **4** 首次收到 GPS 时用「首次目标对齐 _smoothedSpeed」避免 0→GPS 跳变。  
- [ ] **5** INS 退出时用「当前 state.currentSpeed（INS）对齐 _smoothedSpeed」避免退出隧道跳变。  
- [ ] **6** 对 position.speed 做 NaN/Inf/负值/上限校验再写 _targetSpeed。  
- [ ] **7** startRecording 时初始化 _targetSpeed、_smoothedSpeed、_lastSpeedUpdate；stopRecording 时清理。  
- [ ] **8** 平滑更新仅当 `!state.isInsActive` 时写 state.currentSpeed，避免与 _handleInsTick 冲突。  
- [ ] **9** 若你已启用或即将启用 SensorEngine 的静止/自动校准，确认是否需要并实现 `updateSpeed(state.currentSpeed)` 的调用。

确认以上无误后，再按本清单逐处修改即可降低负体验与回归风险。
