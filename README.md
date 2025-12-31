<p align="center">
  <img src="assets/images/Puked.png" width="120" />
</p>

# Puked - Ride Comfort Quantification Tool 🚗💨

[![Version](https://img.shields.io/badge/version-2.0.0-orange.svg)](https://github.com/YOUR_USERNAME/Puked)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Flutter](https://img.shields.io/badge/Flutter-v3.16+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)

<p align="center">
  <img src="assets/images/01.jpg" width="30%" />
  <img src="assets/images/02.jpg" width="30%" />
  <img src="assets/images/03.jpg" width="30%" />
</p>

[简体中文](./README.md) | [English](./README_EN.md)

> **Puked** (吐槽) 是一款专为自动驾驶产品经理 (PM) 和工程师设计的行驶舒适度量化工具。通过手机传感器捕捉高频数据，结合重力对齐算法，将主观感受转化为客观、可追溯的数据。

---

## 🌟 核心特性 (Core Features)

### 1. 传感器引擎 (Sensor Engine)
- **稳定采样**: 30Hz 稳定提取加速度计与陀螺仪原始数据，兼顾实时显示平顺度与数据精度。
- **静态重力校准 (Gravity Alignment)**: 自动识别手机摆放角度，建立旋转矩阵，将数据从手机坐标系实时转换至车辆坐标系（纵向 $a_x$, 横向 $a_y$, 垂向 $a_z$）。

### 2. 智驾竞技场 (The Arena) 🏆
- **全球排行榜**: 实时统计各品牌及软件版本的“平均无负面体验里程 (km/Event)”。
- **版本进化趋势**: 可视化展示同一品牌在不同软件版本下的舒适度演进曲线。
- **症状深度拆解**: 详细分析急加、急减、顿挫、颠簸、晃动五大维度的表现。

### 3. 横屏驾驶模式 (Landscape HUD) 📱
- **全屏地图体验**: 针对车载手机支架优化的横屏布局。
- **动态 HUD**: 在导航的同时，实时呈现 G-Force 球与 6 轴示波器波形。

### 4. 云端同步 (Cloud Support) ☁️
- **账号备份**: 支持 PocketBase 认证，行程数据多端同步，永不丢失。
- **公开分享**: 一键分享行程，参与全球智驾舒适度大数据建设。

### 5. 负体验回溯式标定 (Retroactive Tagging)
- **15秒循环缓冲区**: 系统始终保存过去 15 秒的原始数据。
- **真值标定**: 当用户感到不适时，点击记录即可截取“点击前 10 秒 + 点击后 5 秒”的数据片段，用于后续算法迭代。

### 6. 数据管理 (Data Management)
- **本地存储**: 完整的行程历史管理。
- **标准导出**: 导出包含元数据、GPS 轨迹流及事件传感器片段的结构化 JSON。

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
- Flutter SDK (>= 3.16.0)
- Dart SDK (>= 3.2.0)
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

**Puked** (吐槽) is a professional quantification tool for Autonomous Driving PMs and Engineers. Version 2.0 introduces **The Arena** and **Cloud Integration**, transforming it into a platform for comparing AD systems globally.

### Key Highlights:
- **The Arena**: Global leaderboard for AD systems (Tesla, Xpeng, Nio, etc.) based on real-world comfort metrics.
- **Cloud Sync**: Securely backup and sync your trips via PocketBase.
- **Landscape HUD**: Optimized UI for car-mounted displays with real-time G-Force and waveform analysis.
- **Retroactive Tagging**: Capture high-frequency sensor data around moments of discomfort.
- **Standardized Export**: Structured JSON for professional data analysis.

Licensed under **GPL-3.0**.
