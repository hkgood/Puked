import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:puked/models/sensor_data.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart';

class SensorEngine {
  // 采样周期：iOS 强制 60Hz (约16ms)，Android 维持 30Hz (33ms)
  static final Duration samplingPeriod = Platform.isIOS
      ? const Duration(milliseconds: 16)
      : const Duration(milliseconds: 33);

  // 15秒缓冲区长度 (15s * 60Hz = 900 points for iOS)
  static final int bufferLimit = Platform.isIOS ? 900 : 450;

  final ListQueue<SensorData> _buffer = ListQueue<SensorData>(bufferLimit);

  // 校准矩阵 (Identity matrix by default)
  Matrix3 _rotationMatrix = Matrix3.identity();
  bool _isCalibrated = false;
  double _gravityMagnitude = 9.80665; // 标准重力加速度

  // 滤波器系数
  static const double _lpfCoeff = 0.1;
  static const double _rampFilterCoeff = 0.02;
  Vector3 _filteredAccel = Vector3.zero();
  Vector3 _gravityEstimate = Vector3.zero();

  // 临时存储最新的传感器原始值
  final Vector3 _latestAccel = Vector3.zero();
  final Vector3 _latestGyro = Vector3.zero();
  final Vector3 _latestMag = Vector3.zero();

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _magSub;
  Timer? _samplingTimer;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  // 广播流，供 UI 订阅
  final _dataController = StreamController<SensorData>.broadcast();
  Stream<SensorData> get sensorStream => _dataController.stream;

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // 根据平台选择采样间隔
    final sensorInterval = Platform.isIOS
        ? SensorInterval.uiInterval
        : SensorInterval.gameInterval;

    // 监听原始传感器流
    _accelSub =
        accelerometerEventStream(samplingPeriod: sensorInterval).listen((e) {
      _latestAccel.setValues(e.x, e.y, e.z);
      // iOS 采用“同步驱动”：传感器一更新，立刻触发 tick，消除真空期
      if (Platform.isIOS) _processTick();
    });

    _gyroSub = gyroscopeEventStream(samplingPeriod: sensorInterval)
        .listen((e) => _latestGyro.setValues(e.x, e.y, e.z));
    _magSub = magnetometerEventStream(samplingPeriod: sensorInterval)
        .listen((e) => _latestMag.setValues(e.x, e.y, e.z));

    // Android 依然使用定时器，因为 Android 定位服务需要稳定的心跳
    if (!Platform.isIOS) {
      _samplingTimer = Timer.periodic(samplingPeriod, (timer) {
        _processTick();
      });
    }
  }

  void _processTick() {
    final now = DateTime.now();

    // 1. 应用旋转矩阵
    final rotatedAccel = _rotationMatrix.transformed(_latestAccel);
    final rotatedGyro = _rotationMatrix.transformed(_latestGyro);

    // 2. 实时估计重力分量
    if (_isCalibrated) {
      _gravityEstimate = _gravityEstimate * (1.0 - _rampFilterCoeff) +
          rotatedAccel * _rampFilterCoeff;
    } else {
      _gravityEstimate = rotatedAccel.clone();
    }

    // 3. 低通滤波
    _filteredAccel =
        _filteredAccel * (1.0 - _lpfCoeff) + rotatedAccel * _lpfCoeff;

    // 4. 扣除重力
    final processedAccel = rotatedAccel - _gravityEstimate;
    final processedFilteredAccel = _filteredAccel - _gravityEstimate;

    final data = SensorData(
      timestamp: now,
      accelerometer: _latestAccel.clone(),
      gyroscope: _latestGyro.clone(),
      magnetometer: _latestMag.clone(),
      processedAccel: processedAccel,
      processedGyro: rotatedGyro,
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

  /// 顶级校准逻辑：增加方差校验，确保校准时手机是静止的
  Future<void> calibrate() async {
    List<Vector3> samples = [];
    const int sampleCount = 20;

    for (int i = 0; i < sampleCount; i++) {
      samples.add(_latestAccel.clone());
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // 计算均值
    Vector3 gMean = Vector3.zero();
    for (var s in samples) {
      gMean += s;
    }
    gMean /= samples.length.toDouble();

    // 顶级校验：计算方差 (Variance)
    double variance = 0;
    for (var s in samples) {
      variance += (s - gMean).length2;
    }
    variance /= samples.length;

    // 如果方差 > 0.05 (约 0.22m/s² 的波动)，说明手机在动，拒绝校准
    if (variance > 0.05) {
      throw Exception("校准失败：请确保手机完全静止（检测到波动: ${variance.toStringAsFixed(3)}）");
    }

    _gravityMagnitude = gMean.length;
    if (_gravityMagnitude < 0.1) return;

    final unitZ = gMean.normalized();
    Vector3 reference = Vector3(0, 1, 0);
    if (unitZ.dot(reference).abs() > 0.9) {
      reference = Vector3(1, 0, 0);
    }

    final unitX = reference.cross(unitZ).normalized();
    final unitY = unitZ.cross(unitX).normalized();

    final rot = Matrix3.columns(unitX, unitY, unitZ);
    _rotationMatrix = rot.isIdentity() ? rot : Matrix3.copy(rot)
      ..invert();
    _gravityEstimate = _rotationMatrix.transformed(gMean);
    _isCalibrated = true;

    _processTick();
  }

  /// 获取回溯数据片段 (过去 N 秒)，并进行下采样 (Downsampling to ~20Hz)
  List<SensorData> getLookbackBuffer(int seconds, {int targetHz = 20}) {
    // 计算原始采样率 (iOS 60Hz, Android 30Hz)
    final sourceHz = Platform.isIOS ? 60 : 30;
    final step = (sourceHz / targetHz).round().clamp(1, 10);

    int pointsToTake = (seconds * sourceHz).clamp(0, _buffer.length);
    final rawList = _buffer.toList().sublist(_buffer.length - pointsToTake);

    // 执行跳格采样
    List<SensorData> downsampled = [];
    for (int i = 0; i < rawList.length; i += step) {
      downsampled.add(rawList[i]);
    }
    return downsampled;
  }

  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
    _samplingTimer?.cancel();
    _dataController.close();
  }
}
