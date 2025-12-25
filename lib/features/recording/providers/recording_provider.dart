import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/features/recording/domain/sensor_engine.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/models/sensor_data.dart';
import 'package:puked/models/trip_event.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'dart:collection';

// Storage Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// 传感器引擎 Provider
final sensorEngineProvider = Provider<SensorEngine>((ref) {
  final engine = SensorEngine();
  ref.onDispose(() => engine.dispose());
  return engine;
});

// 实时传感器流
final sensorStreamProvider = StreamProvider<SensorData>((ref) {
  final engine = ref.watch(sensorEngineProvider);
  engine.start();
  return engine.sensorStream;
});

class RecordingState {
  final bool isRecording;
  final bool isCalibrating;
  final Trip? currentTrip;
  final List<RecordedEvent> events;
  final List<TrajectoryPoint> trajectory; // 增加内存中的轨迹缓存，加速 UI 渲染
  final double currentDistance; // 当前行程里程 (米)
  final double maxGForce; // 本次行程的最大 G 值
  final Position? currentPosition; // 实时位置
  final LocationPermission? permissionStatus; // 权限状态

  RecordingState({
    required this.isRecording,
    this.isCalibrating = false,
    this.currentTrip,
    this.events = const [],
    this.trajectory = const [],
    this.currentDistance = 0.0,
    this.maxGForce = 0.0,
    this.currentPosition,
    this.permissionStatus,
  });

  RecordingState copyWith({
    bool? isRecording,
    bool? isCalibrating,
    Trip? currentTrip,
    List<RecordedEvent>? events,
    List<TrajectoryPoint>? trajectory,
    double? currentDistance,
    double? maxGForce,
    Position? currentPosition,
    LocationPermission? permissionStatus,
  }) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
      isCalibrating: isCalibrating ?? this.isCalibrating,
      currentTrip: currentTrip ?? this.currentTrip,
      events: events ?? this.events,
      trajectory: trajectory ?? this.trajectory,
      currentDistance: currentDistance ?? this.currentDistance,
      maxGForce: maxGForce ?? this.maxGForce,
      currentPosition: currentPosition ?? this.currentPosition,
      permissionStatus: permissionStatus ?? this.permissionStatus,
    );
  }
}

class RecordingNotifier extends StateNotifier<RecordingState> {
  final SensorEngine _engine;
  final StorageService _storage;
  final Ref _ref;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription? _sensorSub;

  // 事件检测阈值 (m/s²)
  static const double _thresholdAccel = 3.0; // 急加速
  static const double _thresholdDecel = -3.5; // 急刹车
  static const double _thresholdWobbleSpan = 1.8; // 摆动跨度阈值
  static const double _thresholdBump = 2.5; // 颠簸 (Z轴突变)

  // 保护期和检测窗口
  static const Duration _startProtectionDuration = Duration(seconds: 5);
  static const Duration _wobbleWindow = Duration(milliseconds: 1000);
  DateTime? _recordingStartTime;

  // X轴历史记录 (用于检测摆动)
  final ListQueue<MapEntry<DateTime, double>> _xHistory = ListQueue();

  // 防抖计时器 (防止短时间内重复触发同一类型事件)
  final Map<String, DateTime> _lastTriggered = {};
  static const Duration _debounceDuration = Duration(seconds: 2);

  RecordingNotifier(this._engine, this._storage, this._ref) : super(RecordingState(isRecording: false)) {
    // 初始化时就请求权限并开始监听位置
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    state = state.copyWith(permissionStatus: permission);

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      // 获取初始位置
      final initialPosition = await Geolocator.getLastKnownPosition() ?? 
                             await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      state = state.copyWith(currentPosition: initialPosition);

      // 启动全局位置监听
      _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, 
          distanceFilter: 2,
        ),
      ).listen((position) {
        _handlePositionUpdate(position);
      });
    }
  }

  void _handlePositionUpdate(Position position) {
    // 如果 GPS 精度太差 (> 20米)，直接忽略该点，防止桥下跳线
    if (position.accuracy > 20) return;

    // 无论是否录制，都更新当前实时位置
    final prevPosition = state.currentPosition;
    state = state.copyWith(currentPosition: position);

    // 如果正在录制，则保存到轨迹中
    if (state.isRecording && state.currentTrip != null) {
      // 距离过滤：如果两点之间距离太短 (< 2米)，不记录，减少原地抖动
      double addedDistance = 0;
      if (prevPosition != null) {
        addedDistance = Geolocator.distanceBetween(
          prevPosition.latitude, 
          prevPosition.longitude, 
          position.latitude, 
          position.longitude
        );
      }
      
      if (addedDistance < 2.0 && prevPosition != null) return;

      final point = TrajectoryPoint()
        ..lat = position.latitude
        ..lng = position.longitude
        ..altitude = position.altitude
        ..speed = position.speed
        ..timestamp = DateTime.now();
      
      final newDistance = state.currentDistance + addedDistance;
      _storage.addTrajectoryPoint(state.currentTrip!.id, point, distance: newDistance);
      state = state.copyWith(
        trajectory: [...state.trajectory, point],
        currentDistance: newDistance,
      );
    }
  }

  void _detectAutoEvents(SensorData data) {
    // 自动判定始终基于已校准且低通滤波平滑后的数据，以确保准确性和排除抖动干扰
    // 如果正在校准中，或处于起步保护期内，不触发任何自动事件
    final now = DateTime.now();
    if (state.isCalibrating) return;
    if (_recordingStartTime != null && now.difference(_recordingStartTime!) < _startProtectionDuration) return;

    final accel = data.filteredAccel;
    
    // 更新 X 轴历史记录
    _xHistory.addLast(MapEntry(now, accel.x));
    while (_xHistory.isNotEmpty && now.difference(_xHistory.first.key) > _wobbleWindow) {
      _xHistory.removeFirst();
    }

    // 获取当前的敏感度倍率
    final sensitivity = _ref.read(settingsProvider).sensitivity;
    double multiplier = 1.0; // Low (默认)
    if (sensitivity == SensitivityLevel.medium) multiplier = 0.8;
    if (sensitivity == SensitivityLevel.high) multiplier = 0.6;

    // 内部帮助函数：检查是否在防抖期内
    bool isDebounced(String type) {
      final last = _lastTriggered[type];
      if (last == null) return false;
      return now.difference(last) < _debounceDuration;
    }

    // 1. 检测急刹车 (Y 轴负向)
    if (accel.y < (_thresholdDecel * multiplier) && !isDebounced('rapidDeceleration')) {
      _lastTriggered['rapidDeceleration'] = now;
      tagEvent(EventType.rapidDeceleration, source: 'AUTO');
    }
    // 2. 检测急加速 (Y 轴正向)
    else if (accel.y > (_thresholdAccel * multiplier) && !isDebounced('rapidAcceleration')) {
      _lastTriggered['rapidAcceleration'] = now;
      tagEvent(EventType.rapidAcceleration, source: 'AUTO');
    }

    // 3. 增强型“摆动”检测逻辑 (Wobble/Snake-like)
    if (!isDebounced('wobble') && _xHistory.length > 10) {
      double minX = 0;
      double maxX = 0;
      DateTime? minTime;
      DateTime? maxTime;

      for (var entry in _xHistory) {
        if (entry.value < minX) {
          minX = entry.value;
          minTime = entry.key;
        }
        if (entry.value > maxX) {
          maxX = entry.value;
          maxTime = entry.key;
        }
      }

      final span = maxX - minX;
      // 限制一：跨度必须超过阈值 (受敏感度调节)
      if (span > (_thresholdWobbleSpan * multiplier)) {
        // 限制二：必须同时存在明显的正向和负向分量 (交叉特征)
        // 这里的 0.4 是一个硬阈值，代表至少向左/向右都有过 0.04G 以上的摆动
        if (maxX > 0.4 && minX < -0.4) {
          // 限制三：这个跨度跳变必须在较短时间内完成 (比如 800ms 内)
          if (minTime != null && maxTime != null) {
            final jumpDuration = maxTime.difference(minTime).abs();
            if (jumpDuration < const Duration(milliseconds: 800)) {
              _lastTriggered['wobble'] = now;
              tagEvent(EventType.wobble, source: 'AUTO');
            }
          }
        }
      }
    }

    // 4. 检测颠簸 (Z 轴)
    if (accel.z.abs() > (_thresholdBump * multiplier) && !isDebounced('bump')) {
      _lastTriggered['bump'] = now;
      tagEvent(EventType.bump, source: 'AUTO');
    }
  }

  Future<void> startRecording({String? carModel, String? notes}) async {
    if (state.isCalibrating || state.isRecording) return;

    // 确保权限已获取
    if (state.permissionStatus == LocationPermission.denied || 
        state.permissionStatus == LocationPermission.deniedForever) {
      await _initializeLocation();
      if (state.permissionStatus == LocationPermission.denied || 
          state.permissionStatus == LocationPermission.deniedForever) {
        return; // 依然没权限，无法开始
      }
    }

    // 1. 开启校准模式
    state = state.copyWith(isCalibrating: true);
    await WakelockPlus.enable(); // 开启屏幕常亮
    await _engine.calibrate(); 
    
    // 2. 开始行程
    await _storage.init();
    final trip = await _storage.startTrip(carModel: carModel, notes: notes);
    _recordingStartTime = DateTime.now();
    _xHistory.clear();
    
    // 启动传感器监听以记录峰值 G 值和自动检测事件
    _sensorSub?.cancel();
    _sensorSub = _ref.read(sensorStreamProvider.stream).listen((sensorData) {
      if (state.isRecording) {
        // 使用经过滤波的加速度来计算 Peak G，避免由于手机架晃动导致的瞬间尖峰
        final accelForPeak = sensorData.filteredAccel;
        final currentG = accelForPeak.length / 9.80665; 
        
        // 峰值追踪逻辑优化：不仅要大于当前峰值，还要有一定的波动阈值
        if (currentG > state.maxGForce) {
          state = state.copyWith(maxGForce: currentG);
        } else if (currentG < state.maxGForce * 0.8 && state.maxGForce > 0.5) {
          // 如果当前 G 值大幅回落，说明之前的峰值已经结束，这里保持峰值不变
          // 仅作为逻辑参考，maxGForce 应该一直保持行程最大值
        }

        // 自动事件检测逻辑 (使用 filteredAccel 以确保坡道优化后的准确性)
        _detectAutoEvents(sensorData);
      }
    });

    state = state.copyWith(
      isRecording: true, 
      isCalibrating: false, 
      currentTrip: trip, 
      events: [],
      trajectory: [],
      currentDistance: 0.0,
      maxGForce: 0.0,
    );
  }

  Future<void> stopRecording() async {
    // 停止录制时，不停止位置监听，只停止写入数据库和轨迹更新逻辑
    if (state.currentTrip != null) {
      await _storage.endTrip(state.currentTrip!.id);
    }
    _sensorSub?.cancel();
    _sensorSub = null;
    await WakelockPlus.disable(); // 关闭屏幕常亮
    state = state.copyWith(
      isRecording: false, 
      isCalibrating: false, 
      currentTrip: null,
      events: [],
      trajectory: [],
      currentDistance: 0.0,
      maxGForce: 0.0,
    );
  }

  Future<void> tagEvent(EventType type, {String source = 'MANUAL'}) async {
    if (!state.isRecording || state.currentTrip == null) return;

    final now = DateTime.now();
    final fragment = _engine.getLookbackBuffer(10);
    
    final event = RecordedEvent()
      ..uuid = const Uuid().v4()
      ..timestamp = now
      ..type = type.name
      ..source = source
      ..sensorData = fragment.map((d) => SensorPointEmbedded()
        ..ax = d.processedAccel.x
        ..ay = d.processedAccel.y
        ..az = d.processedAccel.z
        ..gx = d.gyroscope.x
        ..gy = d.gyroscope.y
        ..gz = d.gyroscope.z
        ..mx = d.magnetometer.x
        ..my = d.magnetometer.y
        ..mz = d.magnetometer.z
        ..offsetMs = d.timestamp.difference(now).inMilliseconds
      ).toList();
    
    // 使用当前实时位置
    if (state.currentPosition != null) {
      event.lat = state.currentPosition!.latitude;
      event.lng = state.currentPosition!.longitude;
    }

    await _storage.saveEvent(state.currentTrip!.id, event);
    state = state.copyWith(events: [...state.events, event]);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _sensorSub?.cancel();
    super.dispose();
  }
}

final recordingProvider = StateNotifierProvider<RecordingNotifier, RecordingState>((ref) {
  final engine = ref.watch(sensorEngineProvider);
  final storage = ref.watch(storageServiceProvider);
  return RecordingNotifier(engine, storage, ref);
});
