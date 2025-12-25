import 'dart:async';
import 'dart:collection';
import 'package:puked/models/sensor_data.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart';

class SensorEngine {
  // 30Hz 采集周期 (33.33ms)
  static const Duration samplingPeriod = Duration(milliseconds: 33);

  // 15秒缓冲区长度 (15s * 30Hz = 450 points)
  static const int bufferLimit = 450;

  final ListQueue<SensorData> _buffer = ListQueue<SensorData>(bufferLimit);

  // 校准矩阵 (Identity matrix by default)
  Matrix3 _rotationMatrix = Matrix3.identity();
  bool _isCalibrated = false;
  double _gravityMagnitude = 9.80665; // 标准重力加速度

  // 低通滤波器系数 (0.0 ~ 1.0, 越小越平滑)
  static const double _lpfCoeff = 0.1;
  static const double _rampFilterCoeff = 0.02; // 更慢的滤波用于估计重力偏移 (斜坡优化)
  Vector3 _filteredAccel = Vector3.zero();
  Vector3 _gravityEstimate = Vector3.zero(); // 实时估计重力方向 (用于坡道补偿)

  // 临时存储最新的传感器原始值
  final Vector3 _latestAccel = Vector3.zero();
  final Vector3 _latestGyro = Vector3.zero();
  final Vector3 _latestMag = Vector3.zero();

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _magSub;
  Timer? _samplingTimer;

  // 广播流，供 UI 订阅
  final _dataController = StreamController<SensorData>.broadcast();
  Stream<SensorData> get sensorStream => _dataController.stream;

  void start() {
    // 监听原始传感器流
    _accelSub = accelerometerEventStream()
        .listen((e) => _latestAccel.setValues(e.x, e.y, e.z));
    _gyroSub = gyroscopeEventStream()
        .listen((e) => _latestGyro.setValues(e.x, e.y, e.z));
    _magSub = magnetometerEventStream()
        .listen((e) => _latestMag.setValues(e.x, e.y, e.z));

    // 启动 30Hz 定时采样
    _samplingTimer = Timer.periodic(samplingPeriod, (timer) {
      _processTick();
    });
  }

  void _processTick() {
    final now = DateTime.now();

    // 1. 应用旋转矩阵对齐设备坐标到车辆坐标
    final rotatedAccel = _rotationMatrix.transformed(_latestAccel);

    // 2. 实时估计重力分量 (坡道/斜坡优化)
    // 在平稳行驶时，长期加速度的平均值方向就是重力方向
    // 如果在坡道上，重力会在 X/Y 轴产生分量，我们通过极慢的滤波来捕捉这个变化并抵消它
    if (_isCalibrated) {
      _gravityEstimate = _gravityEstimate * (1.0 - _rampFilterCoeff) +
          rotatedAccel * _rampFilterCoeff;
    } else {
      _gravityEstimate = rotatedAccel.clone();
    }

    // 3. 低通滤波处理 (用于平滑显示和 Peak G)
    _filteredAccel =
        _filteredAccel * (1.0 - _lpfCoeff) + rotatedAccel * _lpfCoeff;

    // 4. 扣除实时估计的重力 (坡道补偿后的净加速度)
    // 这样在坡道平稳行驶时，processedAccel 会趋向于 0
    final processedAccel = rotatedAccel - _gravityEstimate;

    // 5. 经过低通滤波平滑后的净加速度 (用于稳定显示和 Peak G)
    final processedFilteredAccel = _filteredAccel - _gravityEstimate;

    final data = SensorData(
      timestamp: now,
      accelerometer: _latestAccel.clone(),
      gyroscope: _latestGyro.clone(),
      magnetometer: _latestMag.clone(),
      processedAccel: processedAccel,
      filteredAccel: processedFilteredAccel,
    );

    // 更新缓冲区
    if (_buffer.length >= bufferLimit) {
      _buffer.removeFirst();
    }
    _buffer.addLast(data);

    // 推送到 UI 层
    _dataController.add(data);
  }

  /// 鲁棒性校准逻辑：将当前重力方向映射为 Z 轴，并扣除重力
  Future<void> calibrate() async {
    // 1. 采样一段时间获取稳定的重力向量
    Vector3 gravitySum = Vector3.zero();
    const int samples = 10; // 减少采样次数到 10 次，缩短阻塞时间

    for (int i = 0; i < samples; i++) {
      gravitySum += _latestAccel;
      await Future.delayed(
          const Duration(milliseconds: 100)); // 增加单次间隔，保持总时长 1s 左右但减少循环频率
    }

    final gMean = gravitySum / samples.toDouble();
    _gravityMagnitude = gMean.length;

    if (_gravityMagnitude < 0.1) return; // 异常情况

    // 2. 构建旋转矩阵
    // 我们需要将 gMean 向量旋转到 (0, 0, _gravityMagnitude)
    // 目标 Z 轴就是重力方向
    final unitZ = gMean.normalized();

    // 选择一个不与 unitZ 平行的参考向量来构建 X 轴
    // 如果 unitZ 接近 (0, 1, 0)，说明手机是垂直放置的
    Vector3 reference = Vector3(0, 1, 0);
    if (unitZ.dot(reference).abs() > 0.9) {
      reference = Vector3(1, 0, 0);
    }

    final unitX = reference.cross(unitZ).normalized();
    final unitY = unitZ.cross(unitX).normalized();

    // 旋转矩阵将设备坐标系转换到世界/车辆坐标系
    final rot = Matrix3.columns(unitX, unitY, unitZ);
    // 这里我们需要逆矩阵来执行从设备到车辆的转换
    _rotationMatrix = rot.isIdentity() ? rot : Matrix3.copy(rot)
      ..invert();
    _gravityEstimate = _rotationMatrix.transformed(gMean); // 初始化重力估计为校准时的均值
    _isCalibrated = true;

    // 强制触发一次数据清理，确保 UI 立即归零
    _processTick();
  }

  /// 获取回溯数据片段 (过去 N 秒)
  List<SensorData> getLookbackBuffer(int seconds) {
    int pointsToTake = (seconds * 30).clamp(0, _buffer.length);
    return _buffer.toList().sublist(_buffer.length - pointsToTake);
  }

  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
    _samplingTimer?.cancel();
    _dataController.close();
  }
}
