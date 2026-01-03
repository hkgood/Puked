# Changelog

All notable changes to this project will be documented in this file.

## [2.0.3] - 2026-01-03

### Added
- **Splash教学页面**：新增 App 首次启动的教学说明页。
- **双源更新支持**：安卓版本现在支持从 GitHub 和 Gitea 双向获取更新，并支持 App 内直接热更新。
- **地图引擎优化**：增加地理位置自动判断，国内自动切换至高德地图，海外维持使用 OpenStreetMap，大幅提升国内加载速度与稳定性。
- **舒适度卡片重构**：优化版本舒适度卡片设计，采用更直观的 Bar Chart 展示。
- **GPS 信号显示**：改善左上角 GPS 状态显示，界面更加简洁清爽。
- **iOS 交互优化**：优化了 iOS 端的算法切换按钮位置和大小，操作更顺手。
- **Arena 页面优化**：改进了 Arena 排行榜的视觉表现与图表展示。
- **响应式 Web 支持**：网页版现已支持完整的响应式设计，完美适配不同尺寸屏幕。

## [2.0.2] - 2026-01-02

### Changed
- Version bump to 2.0.2 for both iOS and Android.

## [2.0.1] - 2026-01-01

### Changed
- **Algorithm Tuning**: Adjusted rapid acceleration/deceleration threshold to 0.32G and optimized low-speed speed multiplier (0.8) to reduce false positives during vehicle startup.
- **Jerk Detection**: Optimized jerk threshold and added sensitivity level support.

## [2.0.0] - 2025-12-31

### Added
- **The Arena**: Global leaderboard for autonomous driving brands (Tesla, Xpeng, Nio, Huawei, etc.).
- **Cloud Sync**: PocketBase integration for trip backup, multi-device sync, and public sharing.
- **Landscape HUD**: Dedicated UI layout for car-mounted usage with full-screen map and real-time HUD.
- **GitHub Actions**: Automated APK build pipeline (`puked-apk-build.yml`).
- **Enhanced Visuals**: Material 3 integration with Glassmorphism effects and haptic feedback.

### Changed
- **Minimum Requirements**: Updated to Flutter 3.16+ and Dart 3.2+.
- **Android Target**: Updated `compileSdk` and `targetSdk` to 36.
- **Sensor Engine**: Refactored coordinate system transformation (Phone -> Vehicle) for better accuracy.
- **Build Optimization**: Adjusted JVM memory settings in `gradle.properties` for CI compatibility.

### Fixed
- **Code Quality**: Fixed 37 lint warnings including unused imports, unused variables, and deprecated API calls.
- **API Updates**: Migrated PocketBase SDK calls from `getDataValue` to `get<T>`.
- **Formatting**: Standardized code formatting across the entire project.

