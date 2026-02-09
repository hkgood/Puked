# 🏎️ Puked Callback

<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/Mask group-1.png" width="128" alt="Puked Callback Icon">
</p>

**Puked Callback** 是一款专为自动驾驶（ADAS）数据分析设计的 macOS 工具。它可以将复杂的传感器 JSON 数据转化为精美的透明背景回放视频，支持高频插值、动态量程图表以及负体验事件标注。

---

## ✨ 核心特性

- **🎬 透明视频导出**：支持 HEVC with Alpha 编码，导出的视频可以直接叠放在任意行车记录仪画面上。
- **📈 动态心电图表**：
  - 自动适配行程数据的加速度量程（G-Force）。
  - 支持稀疏数据 30FPS 平滑插值。
  - 具备侧边实时刻度与 X/Y 轴图例。
- **⚠️ 事件标注系统**：
  - 自动识别并展示急加、急刹、横摆、颠簸等负体验事件。
  - 矢量勋章样式，图标与 App 原生设计高度对齐。
- **⚡️ 极致画质**：支持高达 160Mbps 码率的无损级导出，分辨率锁定在 1200x800 (2x Retina)。
- **✂️ 片段导出**：支持选择任意时间区间进行精准局部导出。

---

## 🛠️ 技术方案

- **SwiftUI + Canvas**：基于 Metal 硬件加速的实时波形预览。
- **Core Graphics (Parallel)**：多线程并发渲染导出引擎，极速编码。
- **AVFoundation**：支持 HEVC 透明通道的专业视频合成。
- **Data Interpolation**：基于 Catmull-Rom 算法的物理量平滑引擎。

---

## 🚀 快速开始

### 1. 运行环境
- macOS 15.0+
- Xcode 16.0+ (仅限开发者)

### 2. 导出步骤
1. 点击 **“导入数据”**，选择 Puked App 生成的轨迹 JSON 文件。
2. 使用进度条拖动预览，或点击 **播放** 查看实时波形。
3. 点击 **“片段”** 设置需要导出的时间范围。
4. 点击 **“导出”**，选择存储位置，静候高清透明视频生成。

---

## ⚙️ 设置选项

在主界面点击 **设置图标** ⚙️：
- **显示负体验事件**：一键控制视频中是否包含事件标注。
- **导出视频质量**：
  - **普通**：16Mbps (平衡画质与体积)
  - **高**：50Mbps (专业剪辑推荐)
  - **无损**：160Mbps (All-Intra 全关键帧编码)

---

## 📦 自动构建

本项目支持 GitHub Actions 自动构建。每当发布一个新的 Tag (如 `v1.0.0`)，Actions 会自动打包生成 `.dmg` 安装包并发布到 GitHub Release。

---

## 📄 开源协议

本项目采用 MIT 协议。由 **[hkgood](https://github.com/hkgood)** 开发并维护。
