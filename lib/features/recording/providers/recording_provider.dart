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
    this.algorithmMode = AlgorithmMode.expert, // 将默认值改为 expert
    this.isSensorFrozen = false,
    this.lastSensorTime,
    this.lastInsLocation,
    this.isInsActive = false,
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
    AlgorithmMode? algorithmMode,
    bool? isSensorFrozen,
    DateTime? lastSensorTime,
    LatLng? lastInsLocation,
    bool? isInsActive,
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
      algorithmMode: algorithmMode ?? this.algorithmMode,
      isSensorFrozen: isSensorFrozen ?? this.isSensorFrozen,
      lastSensorTime: lastSensorTime ?? this.lastSensorTime,
      lastInsLocation: lastInsLocation ?? this.lastInsLocation,
      isInsActive: isInsActive ?? this.isInsActive,
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

  StreamSubscription<Position>? _positionSub;
  ProviderSubscription<AsyncValue<SensorData>>? _sensorSub;

  // 隧道模式判定逻辑
  DateTime? _lastGpsTime;
  static const Duration _gpsTimeout = Duration(seconds: 4); // 4秒没GPS视为进入隧道/弱信号
  Timer? _insTimer;

  // ... (保持原有常量定义)
  // 事件检测阈值 (m/s²)
  static const double _thresholdAccel = 3.14; // 急加速 (约 0.32G)
  static const double _thresholdDecel = -3.14; // 急刹车 (约 0.32G)
  static const double _thresholdWobbleSpan = 1.8; // 摆动跨度阈值
  static const double _thresholdBump = 2.5; // 颠簸 (Z轴突变)
  static const double _thresholdJerk =
      6.0; // 顿挫阈值 (m/s³) - 加速度变化率 (调低基准以补偿速度系数增加)

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
    Future.microtask(() => _initializeLocation());
    // 确保引擎启动，以便缓冲区开始填充数据
    _engine.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当 App 回到前台时，如果正在录制，确保 Wakelock 依然开启
    if (state == AppLifecycleState.resumed && this.state.isRecording) {
      debugPrint('App resumed, re-enabling Wakelock');
      WakelockPlus.enable();
    }
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
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        ).timeout(const Duration(seconds: 5)).then((pos) {
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

    _lastGpsTime = now;

    // --- 惯导系统修正 ---
    if (isReliable) {
      if (!_insEngine.isInitialized) {
        _insEngine.initialize(
          LatLng(position.latitude, position.longitude),
          Vector3.zero(),
          initialHeading: position.heading, // 使用 GPS 航向初始化惯导
        );
      } else {
        _insEngine.observeGPS(
          LatLng(position.latitude, position.longitude),
          position.speed,
          position.accuracy,
        );
      }

      // 如果之前是惯导模式，现在恢复了，触发“二次修正”
      if (state.isInsActive) {
        _handleGpsRecovery(position);
      }
    }

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
      speedMultiplier = 0.8; // 从 0.6 提高到 0.8，减少低速起步误报
    } else if (currentSpeedKmh < 60.0) {
      // 10km/h 到 60km/h 线性从 0.8 增长到 1.0
      speedMultiplier = 0.8 + 0.2 * ((currentSpeedKmh - 10.0) / 50.0);
    } else if (currentSpeedKmh > 80.0) {
      speedMultiplier = 1.2;
    }

    final finalMultiplier = sensitivityMultiplier * speedMultiplier;

    bool isDebounced(String type) {
      final last = _lastTriggered[type];
      if (last == null) return false;
      return now.difference(last) < _debounceDuration;
    }

    // --- 1. 急加速/急减速检测 (结合动态阈值 + 硬性物理保底) ---
    // 强制保底：在高敏感度且低速下，门槛也不得低于 1.8 (加速) / 2.1 (减速)
    final double currentAccelThreshold =
        (_thresholdAccel * finalMultiplier).clamp(1.8, 10.0);
    final double currentDecelThreshold =
        (_thresholdDecel * finalMultiplier).clamp(-10.0, -2.1);

    if (accel.y < currentDecelThreshold && !isDebounced('rapidDeceleration')) {
      _lastTriggered['rapidDeceleration'] = now;
      _enqueueEvent(EventType.rapidDeceleration, now);
    } else if (accel.y > currentAccelThreshold &&
        !isDebounced('rapidAcceleration')) {
      _lastTriggered['rapidAcceleration'] = now;
      _enqueueEvent(EventType.rapidAcceleration, now);
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
        // 修正：将 sensitivityMultiplier 引入 Jerk 检测，使其支持高中低三档设置
        if (jerk.abs() >
            (_thresholdJerk * speedMultiplier * sensitivityMultiplier)) {
          _lastTriggered['jerk'] = now;
          _enqueueEvent(EventType.jerk, now);
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

      if (span > (_thresholdWobbleSpan * sensitivityMultiplier) && !isTurning) {
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

    if (accel.z.abs() > (_thresholdBump * sensitivityMultiplier) &&
        !isDebounced('bump')) {
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

              if (isFrozen) return; // 假死状态，不进行任何自动打标，保护滤波器

              // --- 惯导引擎预测 (核心) ---
              if (state.isRecording) {
                _insEngine.predict(sensorData);

                // 检查是否进入“隧道/弱信号模式”
                final now = DateTime.now();
                if (_lastGpsTime != null &&
                    now.difference(_lastGpsTime!) > _gpsTimeout) {
                  if (!state.isInsActive) {
                    state = state.copyWith(
                      isInsActive: true,
                      debugMessage: 'INS ACTIVE (Tunnel)',
                    );
                  }

                  // 在惯导模式下，定时将推算出的位置存入轨迹
                  _handleInsTick();
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

              if (smoothedG > state.maxGForce) {
                state = state.copyWith(maxGForce: smoothedG);
              }

              if (Platform.isIOS) {
                if (state.algorithmMode == AlgorithmMode.standard) {
                  _detectAutoEventsStandard(sensorData);
                } else {
                  _detectAutoEventsExpert(sensorData);
                }
              } else {
                // Android 根据模式选择算法
                if (state.algorithmMode == AlgorithmMode.standard) {
                  _detectAutoEvents(sensorData);
                } else {
                  _detectAutoEventsExpertAndroid(sensorData);
                }
              }
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

  /// 惯导模式下的轨迹记录点
  void _handleInsTick() {
    final now = DateTime.now();
    // 限制惯导点记录频率 (例如每 1 秒记一个点)
    if (state.lastLocationTime != null &&
        now.difference(state.lastLocationTime!).inMilliseconds < 1000) {
      return;
    }

    final LatLng insLatLng = _insEngine.getCurrentLatLng();

    // 记录惯导轨迹点
    final point = TrajectoryPoint()
      ..lat = insLatLng.latitude
      ..lng = insLatLng.longitude
      ..speed = 0 // 速度可由 insEngine 估算
      ..timestamp = now
      ..isLowConfidence = true;

    if (state.currentTrip != null) {
      _storage.addTrajectoryPoint(state.currentTrip!.id, point);
      state = state.copyWith(
        trajectory: [...state.trajectory, point],
        lastLocationTime: now,
        lastInsLocation: insLatLng,
      );
    }
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
      final correctedPts = await _amapService.grabRoad(rawPts);

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
  }

  void setAlgorithmMode(AlgorithmMode mode) {
    state = state.copyWith(algorithmMode: mode);
  }

  // --- 库 A: iOS 精简优化版 (Refined Standard) ---
  void _detectAutoEventsStandard(SensorData data) {
    final now = DateTime.now();
    // 1. 启动保护期校验
    if (_recordingStartTime != null &&
        now.difference(_recordingStartTime!) < _startProtectionDuration) {
      return;
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

    final multiplier = _getFinalMultiplier();

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
      if (accel.y < (_thresholdDecel * multiplier) &&
          !isDebounced('rapidDeceleration')) {
        _lastTriggered['rapidDeceleration'] = now;
        _enqueueEvent(EventType.rapidDeceleration, now);
      } else if (accel.y > (_thresholdAccel * multiplier) &&
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
      if (span > (_thresholdWobbleSpan * multiplier) && crossCount >= 2) {
        // Z 轴联动过滤：如果此时 Z 轴也在剧烈跳变 (> 3.0)，说明是手晃
        if (accel.z.abs() < 3.0) {
          _lastTriggered['wobble'] = now;
          _enqueueEvent(EventType.wobble, now);
        }
      }
    }

    // 3. 颠簸检测
    if (accel.z.abs() > (_thresholdBump * multiplier) && !isDebounced('bump')) {
      _lastTriggered['bump'] = now;
      _enqueueEvent(EventType.bump, now);
    }
  }

  // --- 库 B: iOS 专家引擎 (World-Class Expert) ---
  void _detectAutoEventsExpert(SensorData data) {
    final now = DateTime.now();
    // 1. 启动保护期校验
    if (_recordingStartTime != null &&
        now.difference(_recordingStartTime!) < _startProtectionDuration) {
      return;
    }

    final accel = data.filteredAccel;

    // 专家级额外逻辑：多轴 Jerk 能量评估
    // 计算 X, Y, Z 三轴的综合跳变能量
    final recentPoints =
        _engine.getLookbackBuffer(1, targetHz: 60); // 获取最近 1 秒高频原始点
    double totalJerkEnergy = 0;
    if (recentPoints.length > 2) {
      for (int i = 1; i < recentPoints.length; i++) {
        final dA = (recentPoints[i].processedAccel -
                recentPoints[i - 1].processedAccel)
            .length;
        totalJerkEnergy += dA;
      }
    }

    // 如果总能量异常高 (> 50)，判定为“剧烈非匀速运动场景”（如手抖、掉落、越野）
    // 此时将灵敏度倍率降低 2.0 倍 (即门槛提高 2 倍)，防止误报
    double expertMultiplier = 1.0;
    if (totalJerkEnergy > 50.0) {
      expertMultiplier = 2.0;
    }

    final baseMultiplier = _getFinalMultiplier();
    final finalMultiplier = baseMultiplier * expertMultiplier;

    bool isDebounced(String type) {
      final last = _lastTriggered[type];
      return last != null && now.difference(last) < _debounceDuration;
    }

    // 轴间相关性压制逻辑：如果 Z 轴也在剧烈抖动，说明是路面原因
    bool isVerticalSuppressed = accel.z.abs() > (accel.y.abs() * 1.5);

    // 执行检测 (带上专家倍率 + 轴间压制)
    if (accel.y < (_thresholdDecel * finalMultiplier) &&
        !isDebounced('rapidDeceleration')) {
      if (!isVerticalSuppressed) {
        _lastTriggered['rapidDeceleration'] = now;
        _enqueueEvent(EventType.rapidDeceleration, now);
      }
    } else if (accel.y > (_thresholdAccel * finalMultiplier) &&
        !isDebounced('rapidAcceleration')) {
      if (!isVerticalSuppressed) {
        _lastTriggered['rapidAcceleration'] = now;
        _enqueueEvent(EventType.rapidAcceleration, now);
      }
    }

    // 摆动检测：专家模式要求更严苛的零点交叉 (3次以上)
    if (!isDebounced('wobble') && _xHistory.length > 30) {
      double minX = 0;
      double maxX = 0;
      int crossCount = 0;
      double? lastVal;
      for (var entry in _xHistory) {
        if (entry.value < minX) minX = entry.value;
        if (entry.value > maxX) maxX = entry.value;
        if (lastVal != null &&
            ((lastVal <= 0 && entry.value > 0) ||
                (lastVal >= 0 && entry.value < 0))) {
          crossCount++;
        }
        lastVal = entry.value;
      }

      final span = maxX - minX;
      if (span > (_thresholdWobbleSpan * finalMultiplier) && crossCount >= 3) {
        if (accel.z.abs() < 2.0) {
          // 更严的 Z 轴约束
          _lastTriggered['wobble'] = now;
          _enqueueEvent(EventType.wobble, now);
        }
      }
    }

    if (accel.z.abs() > (_thresholdBump * finalMultiplier) &&
        !isDebounced('bump')) {
      _lastTriggered['bump'] = now;
      _enqueueEvent(EventType.bump, now);
    }
  }

  // --- 库 B (Android 适配版): 专家引擎 ---
  void _detectAutoEventsExpertAndroid(SensorData data) {
    final now = DateTime.now();
    // 1. 启动保护期校验 (前 5 秒不检测自动打标)
    if (_recordingStartTime != null &&
        now.difference(_recordingStartTime!) < _startProtectionDuration) {
      return;
    }

    // 2. 专家级滤波：获取平滑后的数据 (由 SensorEngine 的级联滤波矩阵提供)
    final accel = data.filteredAccel;

    // 3. 动态能量评估与物理熔断 (归一化适配 Android 30Hz)
    final recentPoints = _engine.getLookbackBuffer(1, targetHz: 30);
    double totalJerkEnergy = 0;
    if (recentPoints.length > 2) {
      for (int i = 1; i < recentPoints.length; i++) {
        // 计算相邻点的变化率矢量模长
        final dA = (recentPoints[i].processedAccel -
                recentPoints[i - 1].processedAccel)
            .length;
        totalJerkEnergy += dA;
      }
    }

    final double meanEnergy =
        recentPoints.isNotEmpty ? totalJerkEnergy / recentPoints.length : 0;

    double expertMultiplier = 1.0;
    // 物理熔断门槛：如果点均能量超过 0.85，判定为极端环境（手抖、手机跌落、剧烈颠簸）
    if (meanEnergy > 0.85) {
      expertMultiplier = 2.0;
    }

    // 4. 唤醒/异常跳变熔断 (Brake Spike Filter)
    if (recentPoints.length >= 2) {
      final instantJerk = (recentPoints.last.processedAccel -
                  recentPoints[recentPoints.length - 2].processedAccel)
              .length /
          0.033;
      if (instantJerk > 40.0) {
        expertMultiplier = 5.0; // 封死由于传感器唤醒包产生的虚假信号
      }
    }

    final baseMultiplier = _getFinalMultiplier();
    final finalMultiplier = baseMultiplier * expertMultiplier;

    bool isDebounced(String type) {
      final last = _lastTriggered[type];
      return last != null && now.difference(last) < _debounceDuration;
    }

    // 5. 执行纵向检测 (带上专家倍率 + 硬性物理保底 + 轴间压制)
    final double currentAccelThreshold =
        (_thresholdAccel * finalMultiplier).clamp(1.8, 15.0);
    final double currentDecelThreshold =
        (_thresholdDecel * finalMultiplier).clamp(-15.0, -2.1);

    // 轴间相关性压制逻辑：如果 Z 轴也在剧烈抖动，说明是路面原因
    bool isVerticalSuppressed = accel.z.abs() > (accel.y.abs() * 1.5);

    if (accel.y < currentDecelThreshold && !isDebounced('rapidDeceleration')) {
      if (!isVerticalSuppressed) {
        _lastTriggered['rapidDeceleration'] = now;
        _enqueueEvent(EventType.rapidDeceleration, now);
      }
    } else if (accel.y > currentAccelThreshold &&
        !isDebounced('rapidAcceleration')) {
      if (!isVerticalSuppressed) {
        _lastTriggered['rapidAcceleration'] = now;
        _enqueueEvent(EventType.rapidAcceleration, now);
      }
    }

    // 6. 摆动检测：专家模式要求更严苛的零点交叉 (3次以上)
    if (!isDebounced('wobble') && _xHistory.length > 20) {
      double minX = 0;
      double maxX = 0;
      int crossCount = 0;
      double? lastVal;
      for (var entry in _xHistory) {
        if (entry.value < minX) minX = entry.value;
        if (entry.value > maxX) maxX = entry.value;
        if (lastVal != null &&
            ((lastVal <= 0 && entry.value > 0) ||
                (lastVal >= 0 && entry.value < 0))) {
          crossCount++;
        }
        lastVal = entry.value;
      }

      final span = maxX - minX;
      // 专家模式：幅度 + 过零点 (左-右-左) + Z轴静默
      if (span > (_thresholdWobbleSpan * finalMultiplier) &&
          crossCount >= 3 &&
          accel.z.abs() < 2.0) {
        _lastTriggered['wobble'] = now;
        _enqueueEvent(EventType.wobble, now);
      }
    }

    // 7. 颠簸检测
    if (accel.z.abs() > (_thresholdBump * finalMultiplier) &&
        !isDebounced('bump')) {
      _lastTriggered['bump'] = now;
      _enqueueEvent(EventType.bump, now);
    }
  }

  double _getFinalMultiplier() {
    final sensitivity = _ref.read(settingsProvider).sensitivity;
    double sensitivityMultiplier = 1.0;
    if (sensitivity == SensitivityLevel.medium) sensitivityMultiplier = 0.8;
    if (sensitivity == SensitivityLevel.high) sensitivityMultiplier = 0.6;

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
