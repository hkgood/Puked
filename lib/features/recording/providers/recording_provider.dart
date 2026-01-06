import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/features/recording/domain/sensor_engine.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/models/sensor_data.dart';
import 'package:puked/models/trip_event.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:puked/features/recording/domain/ins_engine.dart';
import 'package:puked/services/amap_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';
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

enum AlgorithmMode {
  standard, // 库 A: 精简优化
  expert // 库 B: 顶级动态 (卡尔曼)
}

class RecordingState {
  final bool isRecording;
  final bool isCalibrating;
  final Trip? currentTrip;
  final List<RecordedEvent> events;
  final List<TrajectoryPoint> trajectory; // 增加内存中的轨迹缓存，加速 UI 渲染
  final double currentDistance; // 当前行程里程 (米)
  final double maxGForce; // 本次行程的最大 G 值
  final double currentGForce; // 当前实时的 G 值
  final Position? currentPosition; // 实时位置
  final DateTime? lastLocationTime; // 上一次位置更新时间
  final int locationUpdateCount; // 位置更新计数
  final String debugMessage; // 调试信息
  final LocationPermission? permissionStatus; // 权限状态
  final bool isLowConfidenceGPS; // 是否处于弱信号/地库模式
  final AlgorithmMode algorithmMode; // 算法模式
  final bool isSensorFrozen; // 传感器是否假死/停流
  final DateTime? lastSensorTime; // 最后一个真实的传感器时间
  final LatLng? lastInsLocation; // 惯导推算的最后一个位置
  final bool isInsActive; // 是否正在使用惯导推算
  final DateTime? lastHardwareTimestamp; // 上一次 GPS 硬件时间戳
  final String? alertMessage; // 新增：用于在 UI 弹出警告窗口的信息

  RecordingState({
    required this.isRecording,
    this.isCalibrating = false,
    this.currentTrip,
    this.events = const [],
    this.trajectory = const [],
    this.currentDistance = 0.0,
    this.maxGForce = 0.0,
    this.currentGForce = 0.0,
    this.currentPosition,
    this.lastLocationTime,
    this.locationUpdateCount = 0,
    this.debugMessage = '',
    this.permissionStatus,
    this.isLowConfidenceGPS = false,
    this.algorithmMode = AlgorithmMode.expert, // 将默认值改为 expert
    this.isSensorFrozen = false,
    this.lastSensorTime,
    this.lastInsLocation,
    this.isInsActive = false,
    this.lastHardwareTimestamp,
    this.alertMessage,
  });

  RecordingState copyWith({
    bool? isRecording,
    bool? isCalibrating,
    Trip? currentTrip,
    List<RecordedEvent>? events,
    List<TrajectoryPoint>? trajectory,
    double? currentDistance,
    double? maxGForce,
    double? currentGForce,
    Position? currentPosition,
    DateTime? lastLocationTime,
    int? locationUpdateCount,
    String? debugMessage,
    LocationPermission? permissionStatus,
    bool? isLowConfidenceGPS,
    AlgorithmMode? algorithmMode,
    bool? isSensorFrozen,
    DateTime? lastSensorTime,
    LatLng? lastInsLocation,
    bool? isInsActive,
    DateTime? lastHardwareTimestamp,
    String? alertMessage,
  }) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
      isCalibrating: isCalibrating ?? this.isCalibrating,
      currentTrip: currentTrip ?? this.currentTrip,
      events: events ?? this.events,
      trajectory: trajectory ?? this.trajectory,
      currentDistance: currentDistance ?? this.currentDistance,
      maxGForce: maxGForce ?? this.maxGForce,
      currentGForce: currentGForce ?? this.currentGForce,
      currentPosition: currentPosition ?? this.currentPosition,
      lastLocationTime: lastLocationTime ?? this.lastLocationTime,
      locationUpdateCount: locationUpdateCount ?? this.locationUpdateCount,
      debugMessage: debugMessage ?? this.debugMessage,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isLowConfidenceGPS: isLowConfidenceGPS ?? this.isLowConfidenceGPS,
      algorithmMode: algorithmMode ?? this.algorithmMode,
      isSensorFrozen: isSensorFrozen ?? this.isSensorFrozen,
      lastSensorTime: lastSensorTime ?? this.lastSensorTime,
      lastInsLocation: lastInsLocation ?? this.lastInsLocation,
      isInsActive: isInsActive ?? this.isInsActive,
      lastHardwareTimestamp:
          lastHardwareTimestamp ?? this.lastHardwareTimestamp,
      alertMessage: alertMessage ?? this.alertMessage,
    );
  }
}

class RecordingNotifier extends StateNotifier<RecordingState>
    with WidgetsBindingObserver {
  final SensorEngine _engine;
  final StorageService _storage;
  final Ref _ref;
  final InertialNavigationEngine _insEngine = InertialNavigationEngine();
  final AmapService _amapService = AmapService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<Position>? _positionSub;
  ProviderSubscription<AsyncValue<SensorData>>? _sensorSub;

  // 隧道模式判定逻辑
  DateTime? _lastGpsTime;
  static const Duration _gpsTimeout = Duration(seconds: 5); // 延长到5秒，防止高架下频繁切换
  static const double _insTriggerAccuracy = 120.0; // 精度大于120米才允许INS介入显示
  int _gpsStabilityCounter = 0; // 信号稳定性计数器
  Position? _lastReliableGpsPosition; // 专门用于 GPS 连续性校验，不被 INS 污染

  // ... (保持原有常量定义)
  // 事件检测阈值 (m/s²) - 第一性原理物理常数
  static const double _thresholdAccel = 2.3; // 急加速 (0.23G)
  static const double _thresholdDecel = -2.4; // 急刹车 (0.24G) - 适配 L2 幽灵制动
  static const double _thresholdWobbleSpan = 2.0; // 摆动 (横向)
  static const double _thresholdBump = 3.8; // 颠簸 (垂直)
  static const double _thresholdJerk = 8.0; // 顿挫 (加速度变化率)

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

  // --- 聚合引擎相关成员 ---
  final List<_PendingEvent> _pendingEvents = [];
  Timer? _fusionTimer;
  static const Duration _fusionWindow = Duration(milliseconds: 3000);

  RecordingNotifier(this._engine, this._storage, this._ref)
      : super(RecordingState(
          isRecording: false,
          algorithmMode: AlgorithmMode.expert, // 默认改为算法 B (专家模式)
        )) {
    // 注册生命周期监听
    WidgetsBinding.instance.addObserver(this);
    // 延迟启动定位初始化，避免 Android 12+ 启动时的前台服务限制
    Future.microtask(() => _startLocationUpdates());
    // 确保引擎启动，以便缓冲区开始填充数据
    _engine.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('App lifecycle changed to: $state');
    // 当 App 回到前台时
    if (state == AppLifecycleState.resumed) {
      // 无论是否在录制，回到前台都要开启定位，以便 UI 显示
      _startLocationUpdates();
      if (this.state.isRecording) {
        debugPrint('App resumed, re-enabling Wakelock');
        WakelockPlus.enable();
      }
    }
    // 当 App 进入后台（暂停或失去焦点）时
    else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // 如果没有在录制行程，则停止定位流以省电
      if (!this.state.isRecording) {
        debugPrint(
            'App backgrounded and not recording, stopping location updates');
        _stopLocationUpdates();
      } else {
        debugPrint('App backgrounded but recording, keeping location updates');
      }
    }
  }

  Future<void> _startLocationUpdates() async {
    if (_positionSub != null) {
      debugPrint('Location updates already running');
      return;
    }

    try {
      state = state.copyWith(debugMessage: 'Checking Permission...');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      state = state.copyWith(permissionStatus: permission);

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        state = state.copyWith(debugMessage: 'Starting GPS Stream...');

        // 1. 获取最近一次位置（如果 stream 还没出点）
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && state.currentPosition == null) {
          state = state.copyWith(
              currentPosition: lastKnown, debugMessage: 'Initial GPS OK');
        }

        // 2. 启动定位流
        late LocationSettings locationSettings;
        if (defaultTargetPlatform == TargetPlatform.android) {
          locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 2),
            forceLocationManager: true,
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
            _stopLocationUpdates(); // 出错时尝试清理，以便后续重启
          },
        );

        // 异步尝试获取更高精度的起始点 (仅在 stream 还没稳定时)
        if (state.locationUpdateCount == 0) {
          Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          ).timeout(const Duration(seconds: 5)).then((pos) {
            if (state.locationUpdateCount == 0) _handlePositionUpdate(pos);
          }).catchError((_) {});
        }
      }
    } catch (e) {
      state = state.copyWith(debugMessage: 'Start Location Error: $e');
    }
  }

  void _stopLocationUpdates() {
    if (_positionSub != null) {
      debugPrint('Stopping location updates');
      _positionSub?.cancel();
      _positionSub = null;
      state = state.copyWith(debugMessage: 'GPS Stopped (Eco Mode)');
    }
  }

  void _handlePositionUpdate(Position position) {
    // 调试打印原始精度
    debugPrint('GPS Raw Update: Acc:${position.accuracy}');

    final now = DateTime.now();
    final hwTimestamp = position.timestamp;

    // --- 守卫 1: 时间单调性守卫 (Monotonicity Guard) ---
    if (state.lastHardwareTimestamp != null &&
        !hwTimestamp.isAfter(state.lastHardwareTimestamp!)) {
      return;
    }

    // --- 状态独占逻辑：信号恢复锁定 ---
    // 只有连续 3 个点精度 < 30m，或者当前点精度极佳 (< 15m)，才允许解除 INS 显示模式
    if (position.accuracy < 30.0) {
      _gpsStabilityCounter++;
    } else {
      _gpsStabilityCounter = 0;
    }

    bool isGpsTrulyStable =
        _gpsStabilityCounter >= 3 || position.accuracy < 15.0;

    // 如果当前正在 INS 模式且新来的 GPS 点依然很烂，则继续无视这个 GPS 点
    if (state.isInsActive && !isGpsTrulyStable && position.accuracy > 60.0) {
      debugPrint('GPS ignored: INS is active and signal is still poor');
      return;
    }

    // 判断是否在“行程起始宽容期”
    bool isInGracePeriod = false;
    if (state.isRecording && _recordingStartTime != null) {
      isInGracePeriod = now.difference(_recordingStartTime!).inSeconds < 60;
    }

    final bool isReliable =
        position.accuracy <= (isInGracePeriod ? 200.0 : 50.0);
    final bool isLowConfidence = position.accuracy > 40.0;

    // --- 守卫 2: 物理速度守卫 (基于纯 GPS 历史) ---
    if (state.isRecording && _lastReliableGpsPosition != null && isReliable) {
      final double distance = Geolocator.distanceBetween(
          _lastReliableGpsPosition!.latitude,
          _lastReliableGpsPosition!.longitude,
          position.latitude,
          position.longitude);

      final double timeDiff = hwTimestamp
          .difference(state.lastHardwareTimestamp ?? now)
          .inSeconds
          .toDouble();
      if (timeDiff > 0 && (distance / timeDiff) > 80.0 && !isInGracePeriod) {
        debugPrint('Guard 2 Triggered: Impossible GPS jump ($distance m)');
        return;
      }
    }

    // 通过所有守卫，更新状态
    if (isReliable) {
      _lastReliableGpsPosition = position;
    }

    // 更新 UI 坐标 (小圆点移动)
    state = state.copyWith(
      currentPosition: position,
      lastLocationTime: now,
      lastHardwareTimestamp: hwTimestamp,
      locationUpdateCount: state.locationUpdateCount + 1,
      isLowConfidenceGPS: isLowConfidence,
      isInsActive: !isGpsTrulyStable && position.accuracy > _insTriggerAccuracy,
    );

    _lastGpsTime = now;

    // --- 惯导引擎观察 ---
    if (isReliable) {
      if (!_insEngine.isInitialized) {
        _insEngine.initialize(
          LatLng(position.latitude, position.longitude),
          Vector3.zero(),
          initialHeading: position.heading,
        );
      } else {
        _insEngine.observeGPS(
          LatLng(position.latitude, position.longitude),
          position.speed,
          position.accuracy,
        );
      }
    }

    // --- 物理记录隔离 (只有真实可靠的点才进入轨迹库) ---
    if (state.isRecording && state.currentTrip != null && isReliable) {
      // 距离过滤：如果相对于上一个真实点位移过小，不记入轨迹
      double addedDistance = 0;
      if (state.trajectory.isNotEmpty) {
        final lastPoint = state.trajectory.last;
        addedDistance = Geolocator.distanceBetween(lastPoint.lat, lastPoint.lng,
            position.latitude, position.longitude);
      }

      if (addedDistance < 2.0 && state.trajectory.isNotEmpty) return;

      final point = TrajectoryPoint()
        ..lat = position.latitude
        ..lng = position.longitude
        ..altitude = position.altitude
        ..speed = position.speed
        ..timestamp = hwTimestamp
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

    final currentSpeedKmh = (state.currentPosition?.speed ?? 0) * 3.6;

    // 启动保护期校验 (5秒内，若检测到明显运动则提前退出)
    if (_recordingStartTime != null) {
      final elapsed = now.difference(_recordingStartTime!);
      if (elapsed < _startProtectionDuration) {
        if (currentSpeedKmh < 5.0 && data.processedAccel.length < 1.5) {
          return;
        }
      }
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

    bool isDebounced(String type) {
      final last = _lastTriggered[type];
      if (last == null) return false;
      return now.difference(last) < _debounceDuration;
    }

    // --- 1. 急加速/急减速检测 ---
    // 采用第一性原理：不再依赖敏感度设置，直接使用物理常数，并加入持续性校验
    final recentY = _yHistory
        .where((e) => now.difference(e.key).inMilliseconds < 150)
        .toList();
    if (recentY.length >= 3) {
      bool isConsistentlyDecel =
          recentY.every((e) => e.value < _thresholdDecel);
      bool isConsistentlyAccel =
          recentY.every((e) => e.value > _thresholdAccel);

      if (isConsistentlyDecel && !isDebounced('rapidDeceleration')) {
        _lastTriggered['rapidDeceleration'] = now;
        _enqueueEvent(EventType.rapidDeceleration, now);
      } else if (isConsistentlyAccel && !isDebounced('rapidAcceleration')) {
        _lastTriggered['rapidAcceleration'] = now;
        _enqueueEvent(EventType.rapidAcceleration, now);
      }
    }

    // --- 2. Jerk (顿挫/点刹) 检测 ---
    if (!isDebounced('jerk') && _yHistory.length > 5) {
      // 计算最近 100ms 的加速度变化率
      final recentPoints = _yHistory
          .where((e) => now.difference(e.key).inMilliseconds < 100)
          .toList();
      if (recentPoints.length >= 2) {
        final deltaA = recentPoints.last.value - recentPoints.first.value;
        final deltaT = recentPoints.last.key
                .difference(recentPoints.first.key)
                .inMilliseconds /
            1000.0;
        if (deltaT > 0) {
          final jerk = deltaA / deltaT;
          if (jerk.abs() > _thresholdJerk) {
            _lastTriggered['jerk'] = now;
            _enqueueEvent(EventType.jerk, now);
          }
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
          _enqueueEvent(EventType.jerk, now);
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

      if (span > _thresholdWobbleSpan && !isTurning) {
        if (maxX > 0.4 && minX < -0.4) {
          if (minTime != null && maxTime != null) {
            final jumpDuration = maxTime.difference(minTime).abs();
            if (jumpDuration < const Duration(milliseconds: 800)) {
              _lastTriggered['wobble'] = now;
              _enqueueEvent(EventType.wobble, now);
            }
          }
        }
      }
    }

    if (accel.z.abs() > _thresholdBump && !isDebounced('bump')) {
      _lastTriggered['bump'] = now;
      _enqueueEvent(EventType.bump, now);
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
      final trip = await _storage.startTrip(
          carModel: carModel,
          notes: notes,
          algorithm: state.algorithmMode.name);
      _recordingStartTime = DateTime.now();
      _lastGpsTime = DateTime.now(); // 强制刷新 GPS 时间，防止启动瞬间触发 INS
      _gpsStabilityCounter = 0;
      _insEngine.reset(); // 确保引擎状态完全清空

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
              // 心跳检测：检查底层引擎最后一次收到硬件中断的时间
              final now = DateTime.now();
              final lastActual = _engine.lastSensorEventTime;
              final isFrozen = now.difference(lastActual).inMilliseconds > 500;

              // 更新状态，如果传感器假死，则在 UI 提示，并在算法中熔断
              if (state.isSensorFrozen != isFrozen) {
                state = state.copyWith(
                  isSensorFrozen: isFrozen,
                  debugMessage: isFrozen ? 'SENSOR FROZEN' : 'Recording Active',
                );
              }

              if (isFrozen) {
                return; // 假死状态，不进行任何自动打标，保护滤波器
              }

              // --- 惯导引擎预测 (核心) ---
              if (state.isRecording) {
                _insEngine.predict(sensorData);

                // 检查是否进入“隧道/弱信号模式”
                final now = DateTime.now();

                // 触发惯导显示的物理条件 (严格限制)：
                // 1. GPS 信号完全中断超过 5 秒 (5秒未收到任何点)
                // 2. 精度极差且未进入信号恢复锁定
                final bool isGpsMissing = _lastGpsTime != null &&
                    now.difference(_lastGpsTime!) > _gpsTimeout;
                final bool isGpsUnreliable =
                    (state.currentPosition?.accuracy ?? 0) >
                        _insTriggerAccuracy;

                // 只有当惯导已初始化（拿到过好点）且满足触发条件时，才激活 INS 显示
                if (_insEngine.isInitialized &&
                    (isGpsMissing || isGpsUnreliable)) {
                  // 额外的物理熔断：如果丢信号超过 60 秒，惯导也不再可信，停止更新
                  final bool isInsTooOld = _lastGpsTime != null &&
                      now.difference(_lastGpsTime!).inSeconds > 60;

                  if (isInsTooOld) {
                    if (state.isInsActive) {
                      state = state.copyWith(
                          isInsActive: false, debugMessage: 'GPS SIGNAL LOST');
                    }
                  } else {
                    if (!state.isInsActive) {
                      state = state.copyWith(
                        isInsActive: true,
                        debugMessage: 'INS ACTIVE (Display Only)',
                      );
                    }
                    // 仅更新实时位置，用于小圆点平滑移动
                    _handleInsTick();
                  }
                } else {
                  // GPS 信号正常，强制关闭 INS，并清除稳定性计数器
                  if (state.isInsActive) {
                    state = state.copyWith(isInsActive: false);
                  }
                }
              }

              final accelForPeak = sensorData.filteredAccel;
              final rawG = accelForPeak.length / 9.80665;

              // 实时平滑处理
              _realtimeGHistory.addLast(rawG);
              if (_realtimeGHistory.length > (Platform.isIOS ? 6 : 3)) {
                _realtimeGHistory.removeFirst();
              }

              final smoothedG = _realtimeGHistory.reduce((a, b) => a + b) /
                  _realtimeGHistory.length;

              state = state.copyWith(
                currentGForce: smoothedG,
                maxGForce:
                    smoothedG > state.maxGForce ? smoothedG : state.maxGForce,
              );

              // 统一调用专家引擎，内部已适配 iOS/Android 物理差异
              _detectAutoEventsExpert(sensorData);
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
          isRecording: false,
          isCalibrating: false,
          debugMessage: 'FAILED',
          alertMessage: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void clearAlert() {
    state = state.copyWith(alertMessage: null);
  }

  Future<void> stopRecording() async {
    if (state.currentTrip != null) {
      await _storage.endTrip(state.currentTrip!.id);
    }
    _sensorSub?.close();
    _sensorSub = null;
    await WakelockPlus.disable();

    final isResumed =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

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

    // 如果行程结束时 App 已经处于后台，则立即停止定位以省电
    if (!isResumed) {
      debugPrint('Trip ended in background, stopping location updates');
      _stopLocationUpdates();
    }
  }

  /// 惯导模式下的实时显示更新 (仅用于驱动 UI，不存入正式轨迹)
  void _handleInsTick() {
    final now = DateTime.now();

    // 获取惯导预测的经纬度
    final LatLng insLatLng = _insEngine.getCurrentLatLng();

    // 第一性原理：惯导点只影响实时位置显示，不进入 trajectory 列表
    // 这样就不会在地图上产生黄绿混画或线条叠加
    state = state.copyWith(
      currentPosition: Position(
        latitude: insLatLng.latitude,
        longitude: insLatLng.longitude,
        timestamp: now,
        accuracy: 100.0, // 标记为低精度
        altitude: state.currentPosition?.altitude ?? 0,
        heading: state.currentPosition?.heading ?? 0,
        speed: state.currentPosition?.speed ?? 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      ),
      lastInsLocation: insLatLng,
      debugMessage: 'INS ACTIVE (Display Only)',
    );
  }

  /// GPS 恢复瞬间的“二次修正”与“地图抓路”
  Future<void> _handleGpsRecovery(Position newPosition) async {
    final prevInsLocation = state.lastInsLocation;
    if (prevInsLocation == null) return;

    state = state.copyWith(isInsActive: false, debugMessage: 'GPS RECOVERED');

    // 1. 地图纠偏：利用高德“抓路”服务修正隧道内的轨迹
    // 我们可以取隧道内的最后 10 个点进行修正
    final tunnelPoints =
        state.trajectory.where((p) => p.isLowConfidence == true).toList();

    if (tunnelPoints.length > 2) {
      final List<LatLng> rawPts =
          tunnelPoints.map((p) => LatLng(p.lat, p.lng)).toList();
      await _amapService.grabRoad(rawPts);

      // 更新内存中的轨迹（这里可以做更复杂的平滑，目前先直接替换）
      // ... 逻辑略 ...
    }

    debugPrint('INS Drift Corrected by GPS');
  }

  Future<void> tagEvent(EventType type,
      {String source = 'MANUAL', String? notes}) async {
    if (!state.isRecording || state.currentTrip == null) return;

    final now = DateTime.now();
    // iOS 使用下采样存储 (20Hz)，Android 维持原样
    final fragment =
        _engine.getLookbackBuffer(10, targetHz: Platform.isIOS ? 20 : 30);

    final event = RecordedEvent()
      ..uuid = const Uuid().v4()
      ..timestamp = now
      ..type = type.name
      ..source = source
      ..notes = notes ?? "" // 使用传入的备注
      ..sensorData = fragment
          .map((d) => SensorPointEmbedded()
            ..ax = d.processedAccel.x
            ..ay = d.processedAccel.y
            ..az = d.processedAccel.z
            ..gx = d.processedGyro.x
            ..gy = d.processedGyro.y
            ..gz = d.processedGyro.z
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

    // 播放负体验音效：仅在非手动标记且设置开启时播放
    if (type != EventType.manual &&
        _ref.read(settingsProvider).isEventSoundEnabled) {
      _audioPlayer.play(AssetSource('sound/events.mp3'));
    }
  }

  void setAlgorithmMode(AlgorithmMode mode) {
    state = state.copyWith(algorithmMode: mode);
  }

  double _getFinalMultiplier() {
    final sensitivity = _ref.read(settingsProvider).sensitivity;
    double sensitivityMultiplier = 1.0;
    if (sensitivity == SensitivityLevel.medium) {
      sensitivityMultiplier = 0.8;
    } else if (sensitivity == SensitivityLevel.high) {
      sensitivityMultiplier = 0.6;
    }

    double speedMultiplier = 1.0;
    final currentSpeedKmh = (state.currentPosition?.speed ?? 0) * 3.6;

    if (currentSpeedKmh < 10.0) {
      speedMultiplier = 0.8;
    } else if (currentSpeedKmh < 60.0) {
      speedMultiplier = 0.8 + 0.2 * ((currentSpeedKmh - 10.0) / 50.0);
    } else if (currentSpeedKmh > 80.0) {
      speedMultiplier = 1.2;
    }
    return sensitivityMultiplier * speedMultiplier;
  }

  // --- 库 A: iOS 精简优化版 (Refined Standard) ---
  void _detectAutoEventsStandard(SensorData data) {
    final now = DateTime.now();
    // 1. 启动保护期校验 (5秒内，若检测到明显运动则提前退出)
    if (_recordingStartTime != null) {
      final elapsed = now.difference(_recordingStartTime!);
      if (elapsed < _startProtectionDuration) {
        final currentSpeedKmh = (state.currentPosition?.speed ?? 0) * 3.6;
        if (currentSpeedKmh < 5.0 && data.processedAccel.length < 1.5) {
          return;
        }
      }
    }

    final accel = data.filteredAccel;
    final gyro = data.processedGyro;

    _xHistory.addLast(MapEntry(now, accel.x));
    _yHistory.addLast(MapEntry(now, accel.y));
    _yawRateHistory.addLast(MapEntry(now, gyro.z));

    // 窗口清理 (iOS 60Hz 需保留更多点)
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

    bool isDebounced(String type) {
      final last = _lastTriggered[type];
      return last != null && now.difference(last) < _debounceDuration;
    }

    // 1. 急加减速 + Jerk 物理熔断
    // 逻辑：如果 Y 轴变化率极其恐怖 (> 40m/s³)，视为传感器跳变噪声，熔断
    final recentY =
        _yHistory.where((e) => now.difference(e.key) < _jerkWindow).toList();
    double jerk = 0;
    if (recentY.length >= 3) {
      final deltaA = recentY.last.value - recentY.first.value;
      final deltaT =
          recentY.last.key.difference(recentY.first.key).inMilliseconds /
              1000.0;
      if (deltaT > 0) jerk = deltaA / deltaT;
    }

    if (jerk.abs() < 40.0) {
      // 只有在物理合理的范围内才检测
      if (accel.y < _thresholdDecel && !isDebounced('rapidDeceleration')) {
        _lastTriggered['rapidDeceleration'] = now;
        _enqueueEvent(EventType.rapidDeceleration, now);
      } else if (accel.y > _thresholdAccel &&
          !isDebounced('rapidAcceleration')) {
        _lastTriggered['rapidAcceleration'] = now;
        _enqueueEvent(EventType.rapidAcceleration, now);
      }
    }

    // 2. 摆动检测 + 零点交叉 (Zero-crossing)
    if (!isDebounced('wobble') && _xHistory.length > 20) {
      double minX = 0;
      double maxX = 0;
      int crossCount = 0;
      double? lastVal;

      for (var entry in _xHistory) {
        if (entry.value < minX) minX = entry.value;
        if (entry.value > maxX) maxX = entry.value;

        // 统计过零点次数
        if (lastVal != null &&
            ((lastVal <= 0 && entry.value > 0) ||
                (lastVal >= 0 && entry.value < 0))) {
          crossCount++;
        }
        lastVal = entry.value;
      }

      final span = maxX - minX;
      // 摆动必须满足：幅度够大 + 至少有一次完整的往返 (过零点次数 >= 2)
      if (span > _thresholdWobbleSpan && crossCount >= 2) {
        // Z 轴联动过滤：如果此时 Z 轴也在剧烈跳变 (> 3.0)，说明是手晃
        if (accel.z.abs() < 3.0) {
          _lastTriggered['wobble'] = now;
          _enqueueEvent(EventType.wobble, now);
        }
      }
    }

    // 3. 颠簸检测
    if (accel.z.abs() > _thresholdBump && !isDebounced('bump')) {
      _lastTriggered['bump'] = now;
      _enqueueEvent(EventType.bump, now);
    }
  }

  // --- 库 B: iOS 专家引擎 (World-Class Expert) ---
  // --- 库 B: iOS 精简专家版 ---
  void _detectAutoEventsExpert(SensorData data) {
    final now = DateTime.now();
    // 1. 启动保护期校验 (5秒内，若未检测到车动则不检测)
    if (_recordingStartTime != null) {
      final elapsed = now.difference(_recordingStartTime!);
      if (elapsed < _startProtectionDuration) {
        final currentSpeedKmh = (state.currentPosition?.speed ?? 0) * 3.6;
        // 如果速度 < 5km/h 且 瞬间力不大，则继续保护，防止点击按钮时的手抖误报
        if (currentSpeedKmh < 5.0 && data.processedAccel.length < 1.5) {
          return;
        }
      }
    }

    // 2. 获取数据 (相信校准，回归物理本质)
    final accel = data.processedAccel;

    bool isDebounced(String type) {
      final last = _lastTriggered[type];
      return last != null && now.difference(last) < _debounceDuration;
    }

    // 3. 执行纵向检测 (纯物理阈值 + 持续时间校验)
    // 第一性原理：瞬时抖动不是负体验，持续的力才是。要求连续 150ms 超过阈值。
    final recentY = _yHistory
        .where((e) => now.difference(e.key).inMilliseconds < 150)
        .toList();

    final multiplier = _getFinalMultiplier();

    if (recentY.length >= 3) {
      // 算法 B (Android) 灵敏度调优：将 every 改为 count 判定，放宽滤波严苛度
      int decelCount =
          recentY.where((e) => e.value < (_thresholdDecel * multiplier)).length;
      int accelCount =
          recentY.where((e) => e.value > (_thresholdAccel * multiplier)).length;

      if (decelCount >= 2 && !isDebounced('rapidDeceleration')) {
        _lastTriggered['rapidDeceleration'] = now;
        _enqueueEvent(EventType.rapidDeceleration, now);
      } else if (accelCount >= 2 && !isDebounced('rapidAcceleration')) {
        _lastTriggered['rapidAcceleration'] = now;
        _enqueueEvent(EventType.rapidAcceleration, now);
      }
    }

    // 4. 摆动检测 (X轴持续性)
    if (!isDebounced('wobble')) {
      final recentX = _xHistory
          .where((e) => now.difference(e.key).inMilliseconds < 200)
          .toList();
      if (recentX.length >= 4) {
        double minX = 0, maxX = 0;
        for (var e in recentX) {
          if (e.value < minX) minX = e.value;
          if (e.value > maxX) maxX = e.value;
        }
        if ((maxX - minX) > (_thresholdWobbleSpan * multiplier)) {
          _lastTriggered['wobble'] = now;
          _enqueueEvent(EventType.wobble, now);
        }
      }
    }

    // 5. 颠簸检测 (Z轴瞬时冲击)
    if (accel.z.abs() > (_thresholdBump * multiplier) && !isDebounced('bump')) {
      _lastTriggered['bump'] = now;
      _enqueueEvent(EventType.bump, now);
    }

    // 6. 顿挫检测 (Jerk)
    if (!isDebounced('jerk') && _yHistory.length > 5) {
      final recentPoints = _yHistory
          .where((e) => now.difference(e.key).inMilliseconds < 100)
          .toList();
      if (recentPoints.length >= 2) {
        final deltaA = recentPoints.last.value - recentPoints.first.value;
        final deltaT = recentPoints.last.key
                .difference(recentPoints.first.key)
                .inMilliseconds /
            1000.0;
        if (deltaT > 0) {
          final jerk = deltaA / deltaT;
          if (jerk.abs() > _thresholdJerk) {
            _lastTriggered['jerk'] = now;
            _enqueueEvent(EventType.jerk, now);
          }
        }
      }
    }
  }

  // --- 库 B (Android 适配版): 专家引擎 ---
  // --- 库 B (Android 适配版): 专家引擎 ---
  void _detectAutoEventsExpertAndroid(SensorData data) {
    // Android 版与 iOS 版使用相同的物理常数逻辑，实现平台一致性
    _detectAutoEventsExpert(data);
  }

  // --- 聚合引擎核心逻辑 ---

  /// 将事件放入缓冲区待定
  void _enqueueEvent(EventType type, DateTime timestamp) {
    if (!state.isRecording) return;

    _pendingEvents.add(_PendingEvent(
      type: type,
      timestamp: timestamp,
      source: 'AUTO',
      position: state.currentPosition,
      speed: state.currentPosition?.speed ?? 0,
    ));

    // 如果计时器没启动，则启动它 (第一个入队的事件决定了窗口起始)
    _fusionTimer ??= Timer(_fusionWindow, _processPendingEvents);
  }

  /// 处理缓冲区中的待定事件
  void _processPendingEvents() {
    _fusionTimer = null;
    if (_pendingEvents.isEmpty) return;

    // 1. 优先级定义 (数值越小优先级越高)
    final priority = {
      EventType.rapidAcceleration: 1,
      EventType.rapidDeceleration: 1,
      EventType.jerk: 2,
      EventType.bump: 3,
      EventType.wobble: 4,
    };

    // 按照优先级排序
    _pendingEvents.sort(
        (a, b) => (priority[a.type] ?? 99).compareTo(priority[b.type] ?? 99));

    // 2. 选取优先级最高的作为“主事件”
    var mainEvent = _pendingEvents.first;

    // 3. 执行特殊的物理规则校验 (如车速门槛)
    final speedKmh = mainEvent.speed * 3.6;
    var finalType = mainEvent.type;

    if (finalType == EventType.rapidDeceleration && speedKmh < 5.0) {
      // 场景：极低速下的剧烈减速信号，通常是停稳瞬间的“点头”或过坎
      // 决策：将其修正为“顿挫 (Jerk)”，因为此时不具备“危险驾驶”的急刹性质
      finalType = EventType.jerk;
    }

    // 4. 构建备注信息 (不再显示聚合特征，保持界面干净)
    String? extraNotes;
    // if (otherTypes.isNotEmpty) {
    //   extraNotes = "聚合特征: ${otherTypes.join(', ')}";
    // }

    // 5. 最终上报/落库
    tagEvent(finalType, source: mainEvent.source, notes: extraNotes);

    // 6. 清空缓冲区，等待下一轮
    _pendingEvents.clear();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
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

/// 聚合引擎使用的待定事件实体
class _PendingEvent {
  final EventType type;
  final DateTime timestamp;
  final String source;
  final Position? position;
  final double speed;

  _PendingEvent({
    required this.type,
    required this.timestamp,
    required this.source,
    this.position,
    required this.speed,
  });
}
