# Changelog

All notable changes to this project will be documented in this file.

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

