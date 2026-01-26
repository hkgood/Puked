enum EventType {
  rapidAcceleration,
  rapidDeceleration,
  bump,
  wobble,
  jerk, // 顿挫（含点刹、起步突踩、停车点头）
  manual, // 用户手动标记
  proDisengagement, // 接管：安全接管、走错路、卡死、绿灯不走
  proViolation, // 违章：压实线、走错车道、闯红灯
  proExperience, // 体验：误刹车、画龙、过快/过慢、轨迹不自然
}

enum AlgorithmMode {
  standard, // 库 A: 精简优化
  expert // 库 B: 顶级动态 (卡尔曼)
}
