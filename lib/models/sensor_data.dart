import 'package:vector_math/vector_math_64.dart';

/// 传感器数据点模型
/// 包含加速度、陀螺仪和磁力计原始及处理后的数据
class SensorData {
  final DateTime timestamp;
  
  // 原始数据 (Raw data from sensors)
  final Vector3 accelerometer;
  final Vector3 gyroscope;
  final Vector3 magnetometer;
  
  // 处理后的数据 (Processed data in vehicle coordinate system)
  // 通过校准矩阵变换后的加速度
  final Vector3 processedAccel;
  
  // 经过低通滤波平滑后的加速度 (用于稳定显示和 Peak G)
  final Vector3 filteredAccel;

  SensorData({
    required this.timestamp,
    required this.accelerometer,
    required this.gyroscope,
    required this.magnetometer,
    Vector3? processedAccel,
    Vector3? filteredAccel,
  }) : processedAccel = processedAccel ?? Vector3.zero(),
       filteredAccel = filteredAccel ?? Vector3.zero();

  Map<String, dynamic> toJson() => {
    'ts': timestamp.millisecondsSinceEpoch / 1000.0,
    'accel': {'x': accelerometer.x, 'y': accelerometer.y, 'z': accelerometer.z},
    'gyro': {'x': gyroscope.x, 'y': gyroscope.y, 'z': gyroscope.z},
    'mag': {'x': magnetometer.x, 'y': magnetometer.y, 'z': magnetometer.z},
    'p_accel': {'x': processedAccel.x, 'y': processedAccel.y, 'z': processedAccel.z},
  };
}

