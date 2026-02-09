# 🎨 事件图标显示问题修复

## 🔍 问题描述

部分负体验事件的图标在应用中无法正常显示，表现为：
- 图标位置显示空白或占位符
- 某些事件类型的视觉标识缺失

根据你提供的截图：
- ✅ 第一张图：多个事件图标正常显示（绿色和红色圆圈）
- ❌ 第二张图：单个蓝色圆圈，但图标可能缺失

---

## 🎯 根本原因

使用了**较新的 SF Symbols 图标**，这些图标在某些 macOS 版本中不存在：

| 旧图标名称 | 系统要求 | 问题 |
|----------|---------|------|
| `chart.line.trend.down` | macOS 14.0+ | 在旧系统不存在 |
| `chart.line.trend.up` | macOS 14.0+ | 在旧系统不存在 |
| `vibrate.waves` | macOS 14.0+ / iOS 17.0+ | 新增图标，兼容性差 |

即使应用设置了 `macOS 15.0+` 最低要求，以下情况仍可能导致图标缺失：

1. **图标名称拼写错误**
2. **系统图标库缓存问题**
3. **渲染引擎降级处理**
4. **审核设备环境差异**

---

## ✅ 修复方案

### 替换为更稳定、通用的 SF Symbols 图标

| 事件类型 | 旧图标 | 新图标 | 语义 |
|---------|--------|--------|------|
| 急刹车 | `chart.line.trend.down` | **`arrow.down.circle.fill`** | ⬇️ 向下箭头（减速） |
| 急加速 | `chart.line.trend.up` | **`arrow.up.circle.fill`** | ⬆️ 向上箭头（加速） |
| 顿挫 | `bolt.fill` | `bolt.fill` | ⚡ 保持不变 |
| 颠簸 | `vibrate.waves` | **`triangle.fill`** | ⚠️ 警告三角形 |
| 摆动 | `arrow.left.and.right` | `arrow.left.and.right` | ↔️ 保持不变 |
| 手动标记 | `hand.tap.fill` | `hand.tap.fill` | 👆 保持不变 |
| 其他 | `exclamationmark.circle.fill` | `exclamationmark.circle.fill` | ❗ 保持不变 |

---

## 📊 新图标的优势

### 1. **兼容性极佳**
所有替换图标都是 **macOS 11.0+** / **iOS 14.0+** 就已支持的基础图标，稳定性极高。

### 2. **语义清晰**
- `arrow.down.circle.fill`：明确表达"减速/下降"
- `arrow.up.circle.fill`：明确表达"加速/上升"
- `triangle.fill`：通用的警告/异常符号

### 3. **视觉统一**
- 圆形背景图标（急刹/急加速）保持视觉一致性
- 填充样式让图标在小尺寸下更清晰

### 4. **保持色彩区分**
```swift
case .rapidDeceleration: return .red        // 红色 + ⬇️
case .rapidAcceleration: return .green      // 绿色 + ⬆️
case .jerk: return .indigo                  // 靛蓝 + ⚡
case .bump: return .blue                    // 蓝色 + ⚠️
case .wobble: return .orange                // 橙色 + ↔️
```

---

## 🧪 测试建议

### 1. 在 Xcode Preview 中测试
```swift
// 快速预览所有图标
ForEach(EventType.allCases, id: \.rawValue) { type in
    HStack {
        Image(systemName: type.iconName ?? "")
            .foregroundColor(.white)
            .frame(width: 22, height: 22)
            .background(Circle().fill(type.eventColor))
        Text(type.displayName)
    }
}
```

### 2. 导入实际数据测试
- ✅ 使用 Trip Backup 中的文件测试
- ✅ 检查各种事件类型是否都能正常显示
- ✅ 在播放和导出视频时验证图标渲染

### 3. 检查日志
如果图标仍无法加载，查看控制台输出：
```swift
// 在 VideoExportEngine.swift 第 94 行附近
if let name = type.iconName, let img = NSImage(systemSymbolName: name, ...) {
    eventIcons[name] = SendableImage(image: img)
} else {
    print("⚠️ 无法加载图标: \(type.iconName ?? "nil") for \(type.displayName)")
}
```

---

## 📝 修改文件

**文件**: `Sources/Models/TripModels.swift`

**修改内容**: `EventType` 枚举的 `iconName` 属性

**影响范围**:
- ✅ 实时预览界面 (`WaveformChartView.swift`)
- ✅ 视频导出引擎 (`VideoExportEngine.swift`)
- ✅ 所有使用事件图标的地方

---

## 🎯 预期效果

修复后，所有事件图标应该都能正常显示：

| 场景 | 修复前 | 修复后 |
|------|--------|--------|
| 急刹车事件 | ❌ 空白或不显示 | ✅ 红色圆圈 + 向下箭头 |
| 急加速事件 | ❌ 空白或不显示 | ✅ 绿色圆圈 + 向上箭头 |
| 颠簸事件 | ❌ 空白或不显示 | ✅ 蓝色圆圈 + 警告三角 |
| 其他事件 | ✅ 正常 | ✅ 保持不变 |

---

## 🚀 部署建议

1. **立即测试**：在本地 Xcode 中运行并验证
2. **检查所有事件类型**：确保 9 种事件类型都能正常显示
3. **导出测试视频**：验证导出的视频中图标是否正确渲染
4. **随 1.0.1 版本一起提交审核**

---

## 📚 参考资料

- [SF Symbols Browser](https://developer.apple.com/sf-symbols/)
- [SF Symbols 兼容性表](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)

**最保险的做法**: 只使用 SF Symbols 1.0 和 2.0 的图标（macOS 11+ 全覆盖）

---

**修复日期**: 2026年2月1日  
**影响版本**: 1.0.1+
