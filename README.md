# Puked - Ride Comfort Quantification Tool 🚗💨

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Flutter](https://img.shields.io/badge/Flutter-v3.0+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)

[简体中文](./README.md) | [English](./README_EN.md) (Wait, I will combine them or just write a comprehensive one)

> **Puked** (Picky Passenger) 是一款专为自动驾驶产品经理 (PM) 和工程师设计的行驶舒适度量化工具。通过手机传感器捕捉高频数据，结合重力对齐算法，将主观感受转化为客观、可追溯的数据。

---

## 🌟 核心特性 (Core Features)

### 1. 高频传感器引擎 (High-Frequency Sensor Engine)
- **100Hz 采集**: 深度提取加速度计与陀螺仪原始数据。
- **静态重力校准 (Gravity Alignment)**: 自动识别手机摆放角度，建立旋转矩阵，将数据从手机坐标系实时转换至车辆坐标系（纵向 $a_x$, 横向 $a_y$, 垂向 $a_z$）。

### 2. 负体验回溯式标定 (Retroactive Tagging)
- **15秒循环缓冲区**: 系统始终保存过去 15 秒的原始数据。
- **真值标定**: 当用户感到不适时，点击记录即可截取“点击前 10 秒 + 点击后 5 秒”的数据片段，用于后续自动检测算法的迭代。

### 3. 实时可视化 (Real-time Visualization)
- **G-Force 球**: 实时呈现合力方向与强度。
- **6轴示波器**: 实时监测纵向和横向加速度波形。
- **动态轨迹**: 自动完成 WGS-84 到 GCJ-02 (火星坐标系) 转换，地图匹配更精准。

### 4. 数据管理 (Data Management)
- **本地存储**: 完整的行程历史管理。
- **JSON 导出**: 导出包含元数据、GPS 轨迹流及事件传感器片段的结构化 JSON。

---

## 🎨 视觉设计 (Design Philosophy)

采用 **Sophisticated Minimalism (精致极简主义)** 风格：
- **深色模式 (Dark Mode)** 为主。
- **高对比度配色**: 荧光绿 (平顺) vs 警示红 (负体验)。
- **毛玻璃 (Glassmorphism)** UI 元素。
- **全方位触觉反馈 (Haptic Feedback)**，适合车内弱交互场景。

---

## 🛠 快速开始 (Quick Start)

### 依赖环境
- Flutter SDK (>= 3.0.0)
- Dart SDK (>= 3.0.0)
- Android Studio / Xcode

### 安装步骤
1. 克隆仓库:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Puked.git
   ```
2. 获取依赖:
   ```bash
   flutter pub get
   ```
3. 运行应用:
   ```bash
   flutter run
   ```

---

## 📄 开源协议 (License)

本项目采用 **GPL-3.0** 协议开源。这意味着您可以自由地使用、修改和分发，但任何基于本项目的衍生作品都必须在相同的协议下公开其源代码。

---

## 🤝 贡献与反馈

如果您有任何建议或发现了 Bug，欢迎提交 Issue 或 Pull Request。

---

# Puked - Ride Comfort Quantification Tool (English Summary)

**Puked** is a professional tool for Autonomous Driving PMs and Engineers to quantify ride comfort. It transforms subjective feelings into objective, traceable data using high-frequency sensor capture and gravity alignment algorithms.

### Key Highlights:
- **100Hz Sensor Sampling** with coordinate system transformation.
- **Retroactive Tagging**: Capture 15s data snippets around the moment of discomfort.
- **Glassmorphism UI** with haptic feedback.
- **Standardized Export**: Structured JSON for further analysis.

Licensed under **GPL-3.0**.
