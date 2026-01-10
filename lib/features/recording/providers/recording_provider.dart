import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/features/recording/domain/sensor_engine.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/models/sensor_data.dart';
import 'package:puked/models/trip_event.dart';
import 'package:puked/features/recording/domain/algorithm_config.dart';
import 'package:puked/services/algorithm_config_service.dart';
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

  // 事件检测配置 (优先从云端获取)
  AlgorithmConfig get _config => _ref.read(algorithmConfigProvider);

  // 保护期和检测窗口
  static const Duration _startProtectionDuration = Duration(seconds: 5);
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
  // 移除硬编码，统一使用 _config.fusionWindowMs

  RecordingNotifier(this._engine, this._storage, this._ref)
      : super(RecordingState(
          isRecording: false,
          algorithmMode: AlgorithmMode.expert, // 默认改为算法 B (专家模式)
        )) {
    // 注册生命周期监听
    WidgetsBinding.instance.addObserver(this);

    // 【调试】监听算法配置更新
    _ref.listen<AlgorithmConfig>(algorithmConfigProvider, (previous, next) {
      debugPrint('🔔 [RecordingNotifier] 算法配置已动态更新: v${next.version}');
      debugPrint('   - 加速阈值: ${next.thresholdAccel}');
      debugPrint('   - 减速阈值: ${next.thresholdDecel}');
      debugPrint('   - 颠簸阈值: ${next.thresholdBump}');
    });

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
            accuracy: LocationAccuracy.bestForNavigation,
            activityType: ActivityType.automotiveNavigation,
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

  // ignore: unused_element
  // ignore: unused_element
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
    // 缩短回溯时间为 3 秒，并进行抽稀 (25Hz)，大幅减小存储体积
    final fragment = _engine.getLookbackBuffer(3, targetHz: 25);

    // 获取当前的融合车速 (m/s)
    final currentFusedSpeed = _insEngine.currentSpeed;

    final event = RecordedEvent()
      ..uuid = const Uuid().v4()
      ..timestamp = now
      ..type = type.name
      ..source = source
      ..speed = currentFusedSpeed // 存入融合车速
      ..gForce = state.currentGForce // 存入实时 G 值
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

  Future<void> startRecording({String? carModel, String? notes}) async {
    if (state.isCalibrating || state.isRecording) return;

    try {
      state =
          state.copyWith(isCalibrating: true, debugMessage: 'Calibrating...');
      await WakelockPlus.enable();

      // 传入当前速度进行静止守卫校验
      await _engine.calibrate(
          currentSpeedMs: state.currentPosition?.speed ?? 0.0);

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

              // 统一使用专家级物理引擎，内部已针对跨平台和速度做了鲁棒性适配
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

  // --- 跨平台核心逻辑：自适应物理倍率 ---
  // 用于平衡高速与低速、以及不同平台的硬件差异
  double _getPlatformAdaptabilityFactor(double currentSpeedKmh) {
    double speedMultiplier = 1.0;

    if (currentSpeedKmh < 10.0) {
      // 低速场景：稍微提高门槛，压制手机操作误报
      speedMultiplier = _config.speedLowFactor;
    } else if (currentSpeedKmh > 80.0) {
      // 高速场景：降低门槛，提高对危险动作的敏感度
      speedMultiplier = _config.speedHighFactor;
    }

    return speedMultiplier;
  }

  // --- 统一物理检测引擎 (2.1.5 ES-KF 增强版) ---
  // 该引擎融合了 ES-KF 惯导系统的速度反馈，实现了全局车速熔断和轴间干扰抑制
  void _detectAutoEventsExpert(SensorData data) {
    final now = DateTime.now();
    if (state.isCalibrating) return;

    // --- 第一性原理：多源车速联合熔断 ---
    // 1. 获取惯导推算速度 (高频、实时)
    final insSpeedKmh = _insEngine.currentSpeed * 3.6;
    // 2. 获取 GPS 原始速度 (低频、准确)
    final gpsSpeedKmh = (state.currentPosition?.speed ?? 0) * 3.6;
    final gpsAccuracy = state.currentPosition?.accuracy ?? 999.0;

    // 逻辑决策：
    // - 如果 GPS 信号好 (accuracy < 20) 且 GPS 显示车速极低 (< 2.0 km/h)
    //   此时即使惯导因为手机晃动产生了漂移速度，也应强制以 GPS 为准（判定为静止）。
    // - 如果 GPS 信号差，则完全信任惯导。
    double currentSpeedKmh = insSpeedKmh;
    if (gpsAccuracy < 20.0 && gpsSpeedKmh < 2.0) {
      currentSpeedKmh = gpsSpeedKmh;
    }

    // 静止/极低速物理隔离：将 5.0 km/h 降低至 3.0 km/h 以捕捉起步/停车瞬间
    if (currentSpeedKmh < 3.0) {
      // 即使不打标，也要更新历史记录，保持滤波器的连续性
      _xHistory.addLast(MapEntry(now, data.processedAccel.x));
      _yHistory.addLast(MapEntry(now, data.processedAccel.y));
      return;
    }

    // 2. 启动保护期 (5秒内，除非车速已稳定)
    if (_recordingStartTime != null) {
      final elapsed = now.difference(_recordingStartTime!);
      if (elapsed < _startProtectionDuration && currentSpeedKmh < 10.0) {
        return;
      }
    }

    final accel = data.processedAccel;
    final gyro = data.processedGyro;
    final config = _config;

    // 更新历史记录
    _xHistory.addLast(MapEntry(now, accel.x));
    _yHistory.addLast(MapEntry(now, accel.y));
    _yawRateHistory.addLast(MapEntry(now, gyro.z));

    // 清理历史窗
    while (_xHistory.isNotEmpty &&
        now.difference(_xHistory.first.key).inMilliseconds >
            config.wobbleWindowMs) {
      _xHistory.removeFirst();
    }
    while (_yHistory.isNotEmpty &&
        now.difference(_yHistory.first.key).inMilliseconds >
            config.accelDecelWindowMs * 2) {
      _yHistory.removeFirst();
    }

    final factor = _getPlatformAdaptabilityFactor(currentSpeedKmh);

    bool isDebounced(String type) {
      final last = _lastTriggered[type];
      return last != null && now.difference(last) < _debounceDuration;
    }

    // --- 核心逻辑 0: Z-Axis 动态阈值抑制 (耦合防御) ---
    // 第一性原理：垂直方向的剧烈运动（过坎）会向 X/Y 轴泄露能量。
    // 改进：使用更强的非线性抑制，确保在大冲击下顿挫检测被严格压制
    double couplingSuppressionY = 1.0;
    double couplingSuppressionX = 1.0;
    final double az = accel.z.abs();

    if (az > config.zyInterferenceThreshold) {
      // Y轴抑制（针对急加减速/摆动）
      couplingSuppressionY =
          1.0 + math.pow(az - config.zyInterferenceThreshold, 1.2) * 0.5;
      couplingSuppressionY = couplingSuppressionY.clamp(1.0, 3.5);
    }

    if (az > config.zxInterferenceThreshold) {
      // X轴抑制（专门针对纵向顿挫/Jerk）
      couplingSuppressionX =
          1.0 + math.pow(az - config.zxInterferenceThreshold, 1.2) * 0.8;
      couplingSuppressionX =
          couplingSuppressionX.clamp(1.0, 5.0); // 纵向顿挫对颠簸更敏感，给更高抑制上限
    }

    // --- 核心逻辑 0.1: 转向动态补偿 (Turning Context Awareness) ---
    // 第一性原理：转向时离心力会导致 X 轴读数偏移，且弯道减速是合理动作。
    double turnCompensation = 1.0;
    final double yawRate = gyro.z.abs();
    if (yawRate > 0.1) {
      // 当角速度超过 0.1 rad/s 时开始补偿
      turnCompensation = 1.0 + (yawRate * 1.5); // 线性增加减速阈值，最高约 2-3 倍
      turnCompensation = turnCompensation.clamp(1.0, 2.5);
    }

    // --- 逻辑 1: 持续性检测 (急加速/急刹车) ---
    final recentLongitudinal = _yHistory
        .where((e) =>
            now.difference(e.key).inMilliseconds < config.accelDecelWindowMs)
        .toList();

    if (recentLongitudinal.length >= (Platform.isIOS ? 10 : 5)) {
      int decelCount = recentLongitudinal
          .where((e) =>
              e.value <
              (config.thresholdDecel *
                  factor *
                  couplingSuppressionY *
                  turnCompensation))
          .length;
      int accelCount = recentLongitudinal
          .where((e) =>
              e.value > (config.thresholdAccel * factor * couplingSuppressionY))
          .length;

      bool isPitching = gyro.x.abs() > (config.thresholdPitch / 10.0);

      if (decelCount >= (recentLongitudinal.length * 0.75).floor() &&
          !isDebounced('rapidDeceleration')) {
        // 物理上限过滤
        final avgDecel =
            recentLongitudinal.map((e) => e.value).reduce((a, b) => a + b) /
                recentLongitudinal.length;
        if (avgDecel.abs() < config.maxAccelAllowed) {
          if (!config.pitchValidationEnabled || isPitching) {
            _lastTriggered['rapidDeceleration'] = now;
            _enqueueEvent(EventType.rapidDeceleration, now);
          }
        }
      } else if (accelCount >= (recentLongitudinal.length * 0.75).floor() &&
          !isDebounced('rapidAcceleration')) {
        // 物理上限过滤
        final avgAccel =
            recentLongitudinal.map((e) => e.value).reduce((a, b) => a + b) /
                recentLongitudinal.length;
        if (avgAccel.abs() < config.maxAccelAllowed) {
          if (!config.pitchValidationEnabled || isPitching) {
            _lastTriggered['rapidAcceleration'] = now;
            _enqueueEvent(EventType.rapidAcceleration, now);
          }
        }
      }
    }

    // --- 逻辑 2: 瞬时冲击检测 (顿挫) ---
    if (!isDebounced('jerk')) {
      final recentJerkPoints = _yHistory
          .where(
              (e) => now.difference(e.key).inMilliseconds < config.jerkWindowMs)
          .toList();

      // 改进：使用 100ms 跨点积分算法，平滑高频噪声
      if (recentJerkPoints.length >= 5) {
        double maxWindowedJerk = 0;
        const int integrationMs = 100; // 100ms 跨度

        for (int i = 0; i < recentJerkPoints.length; i++) {
          final currentPoint = recentJerkPoints[i];
          // 寻找约 100ms 前的点
          final targetTime = currentPoint.key
              .subtract(const Duration(milliseconds: integrationMs));

          // 在窗口内找最接近 100ms 前的点
          MapEntry<DateTime, double>? prevPoint;
          for (int j = i - 1; j >= 0; j--) {
            if (recentJerkPoints[j].key.isBefore(targetTime)) {
              prevPoint = recentJerkPoints[j];
              break;
            }
          }

          if (prevPoint != null) {
            final dt =
                currentPoint.key.difference(prevPoint.key).inMicroseconds /
                    1000000.0;
            if (dt > 0.05) {
              // 至少确保有 50ms 的跨度才计算，防止 dt 过小
              final windowedJerk = (currentPoint.value - prevPoint.value) / dt;
              if (windowedJerk.abs() > maxWindowedJerk.abs()) {
                maxWindowedJerk = windowedJerk;
              }
            }
          }
        }

        // 物理合理性过滤
        if (maxWindowedJerk.abs() >
                (config.thresholdJerk * factor * couplingSuppressionX) &&
            maxWindowedJerk.abs() < config.maxJerkAllowed) {
          // 绝对加速度门槛校验：窗口内必须有显著的加速度幅值
          final peakAy =
              recentJerkPoints.map((e) => e.value.abs()).reduce(math.max);
          if (peakAy > config.minAccelForJerk) {
            _lastTriggered['jerk'] = now;
            _enqueueEvent(EventType.jerk, now);
          }
        }
      }
    }

    // --- 逻辑 3: 摆动检测 (横摆) ---
    if (!isDebounced('wobble') &&
        currentSpeedKmh > 10.0 &&
        _xHistory.length > 10) {
      final recentX = _xHistory
          .where((e) =>
              now.difference(e.key).inMilliseconds < config.wobbleWindowMs)
          .toList();
      final recentYaw = _yawRateHistory
          .where((e) =>
              now.difference(e.key).inMilliseconds < config.wobbleWindowMs)
          .toList();

      final minPoints = Platform.isIOS ? 8 : 4;
      if (recentX.length >= minPoints) {
        double minX = 0, maxX = 0;
        for (var e in recentX) {
          if (e.value < minX) minX = e.value;
          if (e.value > maxX) maxX = e.value;
        }
        final span = maxX - minX;

        // 改进：增加航向角速度（Yaw Rate）切换检测，区分平滑变道与左右晃动
        int yawSignSwitches = 0;
        for (int i = 1; i < recentYaw.length; i++) {
          if (recentYaw[i].value.sign != recentYaw[i - 1].value.sign &&
              recentYaw[i].value.abs() > 0.05) {
            yawSignSwitches++;
          }
        }

        // 只有当加速度跨度够大，且存在航向切换（摆动特征）时才触发
        if (span >
                (config.thresholdWobbleSpan * factor * couplingSuppressionY) &&
            span < config.maxWobbleSpanAllowed &&
            yawSignSwitches >= 1) {
          _lastTriggered['wobble'] = now;
          _enqueueEvent(EventType.wobble, now);
        }
      }
    }

    // --- 逻辑 4: 颠簸检测 (垂直冲击) ---
    final azAbs = accel.z.abs();
    if (azAbs > config.thresholdBump &&
        azAbs < config.maxBumpAllowed && // 物理上限过滤
        !isDebounced('bump')) {
      _lastTriggered['bump'] = now;
      _enqueueEvent(EventType.bump, now);
    }
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
    // 核心改进：移除硬编码的 3000ms，改用云端配置的 fusionWindowMs
    _fusionTimer ??= Timer(
        Duration(milliseconds: _config.fusionWindowMs), _processPendingEvents);
  }

  /// 处理缓冲区中的待定事件
  void _processPendingEvents() {
    _fusionTimer = null;
    if (_pendingEvents.isEmpty) return;

    // 1. 优先级定义 (数值越小优先级越高)
    // 核心改进：将 bump 优先级提升到 jerk 之上。
    // 第一性原理：在自动驾驶测评中，路面颠簸属于“环境噪声”，规控顿挫属于“系统信号”。
    // 当两者同时发生时，应优先判定为环境干扰导致的误报。
    final priority = {
      EventType.rapidAcceleration: 1,
      EventType.rapidDeceleration: 1,
      EventType.bump: 2, // 提升至 2，拦截由于颠簸引起的伴生冲击
      EventType.jerk: 3, // 降至 3
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

    // 核心改进：低速点头转换门槛由 3.0km/h 降至 2.0km/h，减少对极重刹的误杀
    if (finalType == EventType.rapidDeceleration && speedKmh < 2.0) {
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
