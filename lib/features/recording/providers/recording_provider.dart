import 'package:flutter/foundation.dart';
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
  final DateTime? lastLocationTime; // 上一次位置更新时间
  final int locationUpdateCount; // 位置更新计数
  final String debugMessage; // 调试信息
  final LocationPermission? permissionStatus; // 权限状态
  final bool isLowConfidenceGPS; // 是否处于弱信号/地库模式

  RecordingState({
    required this.isRecording,
    this.isCalibrating = false,
    this.currentTrip,
    this.events = const [],
    this.trajectory = const [],
    this.currentDistance = 0.0,
    this.maxGForce = 0.0,
    this.currentPosition,
    this.lastLocationTime,
    this.locationUpdateCount = 0,
    this.debugMessage = '',
    this.permissionStatus,
    this.isLowConfidenceGPS = false,
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
    DateTime? lastLocationTime,
    int? locationUpdateCount,
    String? debugMessage,
    LocationPermission? permissionStatus,
    bool? isLowConfidenceGPS,
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
      lastLocationTime: lastLocationTime ?? this.lastLocationTime,
      locationUpdateCount: locationUpdateCount ?? this.locationUpdateCount,
      debugMessage: debugMessage ?? this.debugMessage,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isLowConfidenceGPS: isLowConfidenceGPS ?? this.isLowConfidenceGPS,
    );
  }
}

class RecordingNotifier extends StateNotifier<RecordingState> {
  final SensorEngine _engine;
  final StorageService _storage;
  final Ref _ref;
  StreamSubscription<Position>? _positionSub;
  ProviderSubscription<AsyncValue<SensorData>>? _sensorSub;

  // 事件检测阈值 (m/s²)
  static const double _thresholdAccel = 3.0; // 急加速
  static const double _thresholdDecel = -3.5; // 急刹车
  static const double _thresholdWobbleSpan = 1.8; // 摆动跨度阈值
  static const double _thresholdBump = 2.5; // 颠簸 (Z轴突变)
  static const double _thresholdJerk = 8.0; // 顿挫阈值 (m/s³) - 加速度变化率

  // 保护期和检测窗口
  static const Duration _startProtectionDuration = Duration(seconds: 5);
  static const Duration _wobbleWindow = Duration(milliseconds: 1000);
  static const Duration _jerkWindow = Duration(milliseconds: 300); // Jerk 计算窗口
  DateTime? _recordingStartTime;

  // 传感器历史记录
  final ListQueue<MapEntry<DateTime, double>> _xHistory = ListQueue();
  final ListQueue<MapEntry<DateTime, double>> _yHistory =
      ListQueue(); // 增加 Y 轴历史用于检测 Jerk
  final ListQueue<MapEntry<DateTime, double>> _yawRateHistory = ListQueue();
  final ListQueue<double> _realtimeGHistory = ListQueue(); // 增加实时 G 值平滑缓冲区

  // 防抖计时器 (防止短时间内重复触发同一类型事件)
  final Map<String, DateTime> _lastTriggered = {};
  static const Duration _debounceDuration = Duration(seconds: 2);

  RecordingNotifier(this._engine, this._storage, this._ref)
      : super(RecordingState(isRecording: false)) {
    // 延迟启动定位初始化，避免 Android 12+ 启动时的前台服务限制
    Future.microtask(() => _initializeLocation());
    // 确保引擎启动，以便缓冲区开始填充数据
    _engine.start();
  }

  Future<void> _initializeLocation() async {
    try {
      state = state.copyWith(debugMessage: 'Checking Permission...');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      state = state.copyWith(permissionStatus: permission);

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        state = state.copyWith(debugMessage: 'Getting Initial Position...');

        // 1. 获取初始位置作为“启动触发器”
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          state = state.copyWith(
              currentPosition: lastKnown, debugMessage: 'Initial GPS OK');
        }

        // 2. 启动定位流
        _positionSub?.cancel();

        late LocationSettings locationSettings;
        if (defaultTargetPlatform == TargetPlatform.android) {
          locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 2), // 调低频率到 2s 规避拦截
            forceLocationManager:
                true, // 【关键优化】强制使用系统原生 GPS，绕过 Fused Location 的智能合并/延迟
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationText: "Puked 正在记录行程中",
              notificationTitle: "实时记录中",
              enableWakeLock: true,
            ),
          );
        } else {
          locationSettings = AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
          );
        }

        _positionSub =
            Geolocator.getPositionStream(locationSettings: locationSettings)
                .listen(
          (position) {
            _handlePositionUpdate(position);
          },
          onError: (error) {
            state = state.copyWith(debugMessage: 'Stream Error: $error');
          },
        );

        // 异步尝试获取更高精度的起始点
        Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        ).then((pos) {
          if (state.locationUpdateCount == 0) _handlePositionUpdate(pos);
        }).catchError((_) {});
      }
    } catch (e) {
      state = state.copyWith(debugMessage: 'Init Error: $e');
    }
  }

  void _handlePositionUpdate(Position position) {
    // 调试打印原始精度
    debugPrint('GPS Raw Update: Acc:${position.accuracy}');

    // 第一性原理：UI 必须更新
    final prevPosition = state.currentPosition;
    final now = DateTime.now();

    // 判断是否在“行程起始宽容期”（前 60 秒）
    bool isInGracePeriod = false;
    if (state.isRecording && _recordingStartTime != null) {
      isInGracePeriod = now.difference(_recordingStartTime!).inSeconds < 60;
    }

    // 动态精度阈值：宽容期 200m，稳定期 50m
    final double accuracyThreshold = isInGracePeriod ? 200.0 : 50.0;
    final bool isReliable = position.accuracy <= accuracyThreshold;
    final bool isLowConfidence =
        position.accuracy > 40.0; // 只要精度大于 40m，我们就认为是弱信号/室内场景

    state = state.copyWith(
      currentPosition: position,
      lastLocationTime: now,
      locationUpdateCount: state.locationUpdateCount + 1,
      isLowConfidenceGPS: isLowConfidence,
      debugMessage: isReliable
          ? 'GPS OK (${position.accuracy.toStringAsFixed(0)}m)'
          : 'Poor Signal (${position.accuracy.toStringAsFixed(0)}m)',
    );

    // 第二性原理：记录从严 (只有精度达标才进轨迹)
    if (state.isRecording && state.currentTrip != null && isReliable) {
      double addedDistance = 0;
      if (prevPosition != null) {
        addedDistance = Geolocator.distanceBetween(prevPosition.latitude,
            prevPosition.longitude, position.latitude, position.longitude);
      }

      // 距离过滤
      if (addedDistance < 2.0 &&
          prevPosition != null &&
          state.trajectory.isNotEmpty) {
        return;
      }

      final point = TrajectoryPoint()
        ..lat = position.latitude
        ..lng = position.longitude
        ..altitude = position.altitude
        ..speed = position.speed
        ..timestamp = now
        ..isLowConfidence = isLowConfidence;

      final newDistance = state.currentDistance + addedDistance;
      _storage.addTrajectoryPoint(state.currentTrip!.id, point,
          distance: newDistance);
      state = state.copyWith(
        trajectory: [...state.trajectory, point],
        currentDistance: newDistance,
      );
    }
  }

  void _detectAutoEvents(SensorData data) {
    final now = DateTime.now();
    if (state.isCalibrating) return;
    if (_recordingStartTime != null &&
        now.difference(_recordingStartTime!) < _startProtectionDuration) {
      return;
    }

    final accel = data.filteredAccel;
    final gyro = data.processedGyro;

    _xHistory.addLast(MapEntry(now, accel.x));
    _yHistory.addLast(MapEntry(now, accel.y));
    _yawRateHistory.addLast(MapEntry(now, gyro.z));

    while (_xHistory.isNotEmpty &&
        now.difference(_xHistory.first.key) > _wobbleWindow) {
      _xHistory.removeFirst();
    }
    while (_yHistory.isNotEmpty &&
        now.difference(_yHistory.first.key) >
            const Duration(milliseconds: 1500)) {
      _yHistory.removeFirst();
    }
    while (_yawRateHistory.isNotEmpty &&
        now.difference(_yawRateHistory.first.key) > _wobbleWindow) {
      _yawRateHistory.removeFirst();
    }

    final sensitivity = _ref.read(settingsProvider).sensitivity;
    double sensitivityMultiplier = 1.0;
    if (sensitivity == SensitivityLevel.medium) sensitivityMultiplier = 0.8;
    if (sensitivity == SensitivityLevel.high) sensitivityMultiplier = 0.6;

    // --- 动态速度敏感度计算 ---
    double speedMultiplier = 1.0;
    final currentSpeedKmh = (state.currentPosition?.speed ?? 0) * 3.6;

    if (currentSpeedKmh < 10.0) {
      speedMultiplier = 0.6;
    } else if (currentSpeedKmh < 60.0) {
      // 10km/h 到 60km/h 线性从 0.6 增长到 1.0
      speedMultiplier = 0.6 + 0.4 * ((currentSpeedKmh - 10.0) / 50.0);
    } else if (currentSpeedKmh > 80.0) {
      speedMultiplier = 1.2;
    }

    final finalMultiplier = sensitivityMultiplier * speedMultiplier;

    bool isDebounced(String type) {
      final last = _lastTriggered[type];
      if (last == null) return false;
      return now.difference(last) < _debounceDuration;
    }

    // --- 1. 急加速/急减速检测 (结合动态阈值) ---
    if (accel.y < (_thresholdDecel * finalMultiplier) &&
        !isDebounced('rapidDeceleration')) {
      _lastTriggered['rapidDeceleration'] = now;
      tagEvent(EventType.rapidDeceleration, source: 'AUTO');
    } else if (accel.y > (_thresholdAccel * finalMultiplier) &&
        !isDebounced('rapidAcceleration')) {
      _lastTriggered['rapidAcceleration'] = now;
      tagEvent(EventType.rapidAcceleration, source: 'AUTO');
    }

    // --- 2. Jerk (顿挫/点刹) 检测 ---
    if (!isDebounced('jerk') && _yHistory.length > 5) {
      // 计算最近 150ms 的加速度变化率
      final recentY =
          _yHistory.where((e) => now.difference(e.key) < _jerkWindow).toList();
      if (recentY.length >= 3) {
        final deltaA = recentY.last.value - recentY.first.value;
        final deltaT =
            recentY.last.key.difference(recentY.first.key).inMilliseconds /
                1000.0;
        final jerk = deltaA / deltaT;

        // 如果 Jerk 超过阈值 (这里使用绝对值，因为点刹和猛踩都算顿挫)
        // 且由于低速时更敏感，我们也给 Jerk 加上 finalMultiplier (注意：Jerk 越小越容易触发)
        if (jerk.abs() > (_thresholdJerk * speedMultiplier)) {
          _lastTriggered['jerk'] = now;
          tagEvent(EventType.jerk, source: 'AUTO');
        }
      }
    }

    // --- 3. 停车回弹 (点头) 检测 ---
    // 逻辑：如果最近 1 秒内加速度有从明显的负值（刹车）到 0 以上的突变，且当前加速度回归静止
    if (!isDebounced('jerk') && _yHistory.length > 20) {
      // 寻找最近 1 秒内的最小值（最强刹车点）和随后的回弹
      double minAy = 0;
      double maxAfterMin = -999;
      bool foundMin = false;

      for (var entry in _yHistory) {
        if (entry.value < minAy) {
          minAy = entry.value;
          foundMin = true;
          maxAfterMin = -999; // 重置最小值之后的搜索
        }
        if (foundMin && entry.value > maxAfterMin) {
          maxAfterMin = entry.value;
        }
      }

      // 如果最小值小于 -1.5 (说明有刹车动作) 且回弹幅度大于 1.5
      if (minAy < -1.5 && (maxAfterMin - minAy) > 1.8) {
        // 检查是否处于准静止状态 (速度极低或加速度计平稳)
        if (currentSpeedKmh < 2.0 || accel.y.abs() < 0.2) {
          _lastTriggered['jerk'] = now;
          tagEvent(EventType.jerk, source: 'AUTO');
        }
      }
    }

    // --- 4. 摆动检测 ---
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

      // 计算窗口内的累积转角 (弧度)
      double totalYawChange = 0;
      if (_yawRateHistory.length > 1) {
        for (int i = 1; i < _yawRateHistory.length; i++) {
          final dt = _yawRateHistory
                  .elementAt(i)
                  .key
                  .difference(_yawRateHistory.elementAt(i - 1).key)
                  .inMilliseconds /
              1000.0;
          totalYawChange += _yawRateHistory.elementAt(i).value * dt;
        }
      }

      // 如果 1 秒内转角超过 15 度 (约 0.26 弧度)，大概率是正在转弯，过滤掉摆动报警
      bool isTurning = totalYawChange.abs() > 0.26;

      if (span > (_thresholdWobbleSpan * sensitivityMultiplier) && !isTurning) {
        if (maxX > 0.4 && minX < -0.4) {
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

    if (accel.z.abs() > (_thresholdBump * sensitivityMultiplier) &&
        !isDebounced('bump')) {
      _lastTriggered['bump'] = now;
      tagEvent(EventType.bump, source: 'AUTO');
    }
  }

  Future<void> startRecording({String? carModel, String? notes}) async {
    if (state.isCalibrating || state.isRecording) return;

    try {
      state =
          state.copyWith(isCalibrating: true, debugMessage: 'Calibrating...');
      await WakelockPlus.enable();

      await _engine.calibrate();

      state = state.copyWith(debugMessage: 'Initing Storage...');
      await _storage.init();
      final trip = await _storage.startTrip(carModel: carModel, notes: notes);
      _recordingStartTime = DateTime.now();
      _xHistory.clear();
      _yHistory.clear();
      _yawRateHistory.clear();
      _realtimeGHistory.clear();

      // 【核心改进】点击开始瞬间，如果有位置，立即存入作为起点
      List<TrajectoryPoint> initialTrajectory = [];
      if (state.currentPosition != null) {
        final startPoint = TrajectoryPoint()
          ..lat = state.currentPosition!.latitude
          ..lng = state.currentPosition!.longitude
          ..altitude = state.currentPosition!.altitude
          ..speed = state.currentPosition!.speed
          ..timestamp = DateTime.now();
        _storage.addTrajectoryPoint(trip.id, startPoint, distance: 0);
        initialTrajectory.add(startPoint);
      }

      _sensorSub?.close();
      _sensorSub = _ref.listen<AsyncValue<SensorData>>(
        sensorStreamProvider,
        (previous, next) {
          next.whenData((sensorData) {
            if (state.isRecording) {
              final accelForPeak = sensorData.filteredAccel;
              final rawG = accelForPeak.length / 9.80665;

              // 100ms 实时平滑 (30Hz 采样下约 3 帧)
              // 理由：防止单帧高频振动导致实时最大 G 值虚高
              _realtimeGHistory.addLast(rawG);
              if (_realtimeGHistory.length > 3) _realtimeGHistory.removeFirst();

              final smoothedG = _realtimeGHistory.reduce((a, b) => a + b) /
                  _realtimeGHistory.length;

              if (smoothedG > state.maxGForce) {
                state = state.copyWith(maxGForce: smoothedG);
              }
              _detectAutoEvents(sensorData);
            }
          });
        },
        fireImmediately: true,
      );

      state = state.copyWith(
        isRecording: true,
        isCalibrating: false,
        currentTrip: trip,
        events: [],
        trajectory: initialTrajectory, // 包含起始点
        currentDistance: 0.0,
        maxGForce: 0.0,
        debugMessage: 'Recording Active',
      );
    } catch (e, stack) {
      debugPrint('ERROR startRecording: $e');
      debugPrint(stack.toString());
      state = state.copyWith(
          isRecording: false, isCalibrating: false, debugMessage: 'CRASH: $e');
    }
  }

  Future<void> stopRecording() async {
    if (state.currentTrip != null) {
      await _storage.endTrip(state.currentTrip!.id);
    }
    _sensorSub?.close();
    _sensorSub = null;
    await WakelockPlus.disable();
    state = state.copyWith(
      isRecording: false,
      isCalibrating: false,
      currentTrip: null,
      events: [],
      trajectory: [],
      currentDistance: 0.0,
      maxGForce: 0.0,
      currentPosition: state.currentPosition,
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
      ..sensorData = fragment
          .map((d) => SensorPointEmbedded()
            ..ax = d.processedAccel.x
            ..ay = d.processedAccel.y
            ..az = d.processedAccel.z
            ..gx = d.gyroscope.x
            ..gy = d.gyroscope.y
            ..gz = d.gyroscope.z
            ..mx = d.magnetometer.x
            ..my = d.magnetometer.y
            ..mz = d.magnetometer.z
            ..offsetMs = d.timestamp.difference(now).inMilliseconds)
          .toList();

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
    _sensorSub?.close();
    super.dispose();
  }
}

final recordingProvider =
    StateNotifierProvider<RecordingNotifier, RecordingState>((ref) {
  final engine = ref.watch(sensorEngineProvider);
  final storage = ref.watch(storageServiceProvider);
  return RecordingNotifier(engine, storage, ref);
});
