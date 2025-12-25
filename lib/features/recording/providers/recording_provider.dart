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
  final DateTime? lastLocationTime; // 上一次位置更新时间
  final int locationUpdateCount; // 位置更新计数
  final String debugMessage; // 调试信息
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
    this.lastLocationTime,
    this.locationUpdateCount = 0,
    this.debugMessage = '',
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
    DateTime? lastLocationTime,
    int? locationUpdateCount,
    String? debugMessage,
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
      lastLocationTime: lastLocationTime ?? this.lastLocationTime,
      locationUpdateCount: locationUpdateCount ?? this.locationUpdateCount,
      debugMessage: debugMessage ?? this.debugMessage,
      permissionStatus: permissionStatus ?? this.permissionStatus,
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

  // 保护期和检测窗口
  static const Duration _startProtectionDuration = Duration(seconds: 5);
  static const Duration _wobbleWindow = Duration(milliseconds: 1000);
  DateTime? _recordingStartTime;

  // X轴历史记录 (用于检测摆动)
  final ListQueue<MapEntry<DateTime, double>> _xHistory = ListQueue();

  // 防抖计时器 (防止短时间内重复触发同一类型事件)
  final Map<String, DateTime> _lastTriggered = {};
  static const Duration _debounceDuration = Duration(seconds: 2);

  RecordingNotifier(this._engine, this._storage, this._ref)
      : super(RecordingState(isRecording: false)) {
    _initializeLocation();
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

    state = state.copyWith(
      currentPosition: position,
      lastLocationTime: now,
      locationUpdateCount: state.locationUpdateCount + 1,
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
        ..timestamp = now;

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
    _xHistory.addLast(MapEntry(now, accel.x));
    while (_xHistory.isNotEmpty &&
        now.difference(_xHistory.first.key) > _wobbleWindow) {
      _xHistory.removeFirst();
    }

    final sensitivity = _ref.read(settingsProvider).sensitivity;
    double multiplier = 1.0;
    if (sensitivity == SensitivityLevel.medium) multiplier = 0.8;
    if (sensitivity == SensitivityLevel.high) multiplier = 0.6;

    bool isDebounced(String type) {
      final last = _lastTriggered[type];
      if (last == null) return false;
      return now.difference(last) < _debounceDuration;
    }

    if (accel.y < (_thresholdDecel * multiplier) &&
        !isDebounced('rapidDeceleration')) {
      _lastTriggered['rapidDeceleration'] = now;
      tagEvent(EventType.rapidDeceleration, source: 'AUTO');
    } else if (accel.y > (_thresholdAccel * multiplier) &&
        !isDebounced('rapidAcceleration')) {
      _lastTriggered['rapidAcceleration'] = now;
      tagEvent(EventType.rapidAcceleration, source: 'AUTO');
    }

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
      if (span > (_thresholdWobbleSpan * multiplier)) {
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

    if (accel.z.abs() > (_thresholdBump * multiplier) && !isDebounced('bump')) {
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
              final currentG = accelForPeak.length / 9.80665;
              if (currentG > state.maxGForce) {
                state = state.copyWith(maxGForce: currentG);
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
