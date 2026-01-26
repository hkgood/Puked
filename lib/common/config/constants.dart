class AppConstants {
  // 物理常量
  static const double gravity = 9.80665;
  static const double msToKmh = 3.6;
  static const double kmhToMs = 1 / 3.6;

  // 定时与持续时间
  static const Duration gpsTimeout = Duration(seconds: 5);
  static const Duration startProtectionDuration = Duration(seconds: 5);
  static const Duration eventDebounceDuration = Duration(seconds: 2);
  static const Duration uiPopupDuration = Duration(seconds: 5);

  // 阈值与配置
  static const double insTriggerAccuracy = 120.0;
  static const int sensorHistoryLimit = 100;
  static const int lookbackBufferSeconds = 3;
  static const int targetSensorHz = 25;

  // UI 布局常量
  static const double defaultBorderRadius = 24.0;
  static const double smallBorderRadius = 12.0;
  static const double glassBlurSigma = 10.0;
  static const double heavyBlurSigma = 20.0;
}
