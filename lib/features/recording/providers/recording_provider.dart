import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart'; // 显式导入 widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:puked/common/config/constants.dart';
import 'package:puked/common/config/enums.dart';
import 'package:puked/features/recording/domain/algorithm_config.dart';
import 'package:puked/features/recording/domain/ins_engine.dart';
import 'package:puked/features/recording/domain/motion_processor.dart';
import 'package:puked/features/recording/domain/sensor_engine.dart';
import 'package:puked/features/recording/providers/voice_recording_provider.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/models/sensor_data.dart';
import 'package:puked/services/amap_service.dart';
import 'package:puked/services/location_service.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/services/algorithm_config_service.dart';
import 'package:puked/services/video_recording_service.dart';
import 'package:puked/common/utils/i18n.dart';

// 实时传感器流
final sensorStreamProvider = StreamProvider<SensorData>((ref) {
  final engine = ref.watch(sensorEngineProvider);
  engine.start();
  return engine.sensorStream;
});

final inertialNavigationEngineProvider =
    Provider<InertialNavigationEngine>((ref) => InertialNavigationEngine());
final amapServiceProvider = Provider<AmapService>((ref) => AmapService());

// 用于区分"未传参"和"传入null"的哨兵对象
const _undefined = Object();

class RecordingState {
  final bool isRecording;
  final bool isCalibrating;
  final Trip? currentTrip;
  final List<RecordedEvent> events;
  final List<TrajectoryPoint> trajectory;
  final double currentDistance;
  final double currentSpeed;
  final double maxGForce;
  final double currentGForce;
  final Position? currentPosition;
  final bool isLowConfidenceGPS;
  final AlgorithmMode algorithmMode;
  final bool isSensorFrozen;
  final DateTime? lastSensorTime;
  final LatLng? lastInsLocation;
  final bool isInsActive;
  final String? alertMessage;

  RecordingState({
    required this.isRecording,
    this.isCalibrating = false,
    this.currentTrip,
    this.events = const [],
    this.trajectory = const [],
    this.currentDistance = 0.0,
    this.currentSpeed = 0.0,
    this.maxGForce = 0.0,
    this.currentGForce = 0.0,
    this.currentPosition,
    this.isLowConfidenceGPS = false,
    this.algorithmMode = AlgorithmMode.expert,
    this.isSensorFrozen = false,
    this.lastSensorTime,
    this.lastInsLocation,
    this.isInsActive = false,
    this.alertMessage,
  });

  RecordingState copyWith({
    bool? isRecording,
    bool? isCalibrating,
    Trip? currentTrip,
    List<RecordedEvent>? events,
    List<TrajectoryPoint>? trajectory,
    double? currentDistance,
    double? currentSpeed,
    double? maxGForce,
    double? currentGForce,
    Position? currentPosition,
    bool? isLowConfidenceGPS,
    AlgorithmMode? algorithmMode,
    bool? isSensorFrozen,
    DateTime? lastSensorTime,
    LatLng? lastInsLocation,
    bool? isInsActive,
    Object? alertMessage = _undefined, // 使用哨兵对象来区分"未传参"和"传入null"
  }) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
      isCalibrating: isCalibrating ?? this.isCalibrating,
      currentTrip: currentTrip ?? this.currentTrip,
      events: events ?? this.events,
      trajectory: trajectory ?? this.trajectory,
      currentDistance: currentDistance ?? this.currentDistance,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      maxGForce: maxGForce ?? this.maxGForce,
      currentGForce: currentGForce ?? this.currentGForce,
      currentPosition: currentPosition ?? this.currentPosition,
      isLowConfidenceGPS: isLowConfidenceGPS ?? this.isLowConfidenceGPS,
      algorithmMode: algorithmMode ?? this.algorithmMode,
      isSensorFrozen: isSensorFrozen ?? this.isSensorFrozen,
      lastSensorTime: lastSensorTime ?? this.lastSensorTime,
      lastInsLocation: lastInsLocation ?? this.lastInsLocation,
      isInsActive: isInsActive ?? this.isInsActive,
      alertMessage: alertMessage == _undefined
          ? this.alertMessage
          : alertMessage as String?, // 允许真正设置为 null
    );
  }
}

class RecordingNotifier extends StateNotifier<RecordingState>
    with WidgetsBindingObserver {
  final SensorEngine _engine;
  final StorageService _storage;
  final Ref _ref;
  late final InertialNavigationEngine _insEngine;
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<Position>? _positionSub;
  ProviderSubscription<AsyncValue<SensorData>>? _sensorSub;

  // 内部状态变量
  int _locationUpdateCount = 0;
  DateTime? _lastHardwareTimestamp;

  late final LocationService _locationService;
  late final MotionProcessor _motionProcessor;

  DateTime? _lastGpsTime;
  DateTime? _recordingStartTime;

  // 高帧率记录相关
  DateTime? _lastSensorRecordTime;

  // 缓存最新的传感器数据，用于附加到GPS轨迹点
  SensorData? _latestSensorData;

  // ✅ 缓存最后一个有效的GPS位置，用于高频记录时的坐标填充
  Position? _lastValidGpsPosition;

  // 速度平滑：GPS 作为目标，显示速度为指数平滑向目标收敛（避免 INS 融合导致的跳变）
  double _targetSpeed = 0.0; // m/s，来自 GPS
  double _smoothedSpeed = 0.0; // m/s，用于显示的平滑速度
  DateTime? _lastSpeedUpdate; // 上次更新 _targetSpeed 的时间

  static const double _speedSmoothAlpha = 0.15; // 平滑系数
  static const double _speedSmoothAlphaFast = 0.3; // 首帧/刚收 GPS 时略大，加快收敛
  static const double _speedUpdateThreshold = 0.01; // 仅变化超过此值才写 state，减少重建
  static const double _maxValidSpeedMs = 150.0; // ~540 km/h，过滤异常 GPS

  AlgorithmConfig get _config => _ref.read(algorithmConfigProvider);

  RecordingNotifier(this._engine, this._storage, this._ref)
      : super(RecordingState(
          isRecording: false,
          algorithmMode: AlgorithmMode.expert,
        )) {
    _locationService = _ref.read(locationServiceProvider);
    _insEngine = _ref.read(inertialNavigationEngineProvider);

    // 配置音效播放器，支持 iOS 静音模式播放及与其它音频混音
    _audioPlayer.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.mixWithOthers,
        },
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.assistanceSonification,
        audioFocus: AndroidAudioFocus.none,
      ),
    ));

    _motionProcessor = MotionProcessor(
      config: _config,
      isIos: defaultTargetPlatform == TargetPlatform.iOS,
      onEventDetected: (type, ts, pos, speed) => tagEvent(
        type,
        source: 'AUTO',
        timestamp: ts,
        speed: speed,
        lat: pos?.latitude,
        lng: pos?.longitude,
      ),
      onGForceUpdated: (g) => state = state.copyWith(
          currentGForce: g, maxGForce: math.max(state.maxGForce, g)),
    );

    WidgetsBinding.instance.addObserver(this);

    _ref.listen<AlgorithmConfig>(algorithmConfigProvider, (prev, next) {
      debugPrint('🔔 Algorithm config updated to v${next.version}');
      _motionProcessor.config = next;
    });

    Future.microtask(() {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == AppLifecycleState.resumed || lifecycle == null) {
        _startLocationUpdates();
        _engine.start();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      _startLocationUpdates();
      _engine.start();
      if (state.isRecording) WakelockPlus.enable();
    } else if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.inactive) {
      if (!state.isRecording) {
        _stopLocationUpdates();
        _engine.stop();
      }
    }
  }

  Future<void> _startLocationUpdates() async {
    if (_positionSub != null) return;
    try {
      final permission = await _locationService.checkAndRequestPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final lastKnown = await _locationService.getLastKnownPosition();
        if (lastKnown != null && state.currentPosition == null) {
          state = state.copyWith(currentPosition: lastKnown);
        }
        _positionSub = _locationService.getPositionStream().listen(
              _handlePositionUpdate,
              onError: (e) => _stopLocationUpdates(),
            );
        if (_locationUpdateCount == 0) {
          _locationService
              .getCurrentPosition()
              .timeout(const Duration(seconds: 5))
              .then((pos) {
            if (_locationUpdateCount == 0) _handlePositionUpdate(pos);
          }).catchError((_) {});
        }
      }
    } catch (e) {
      debugPrint('Start location error: $e');
    }
  }

  void _stopLocationUpdates() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  int _gpsStabilityCounter = 0;
  Position? _lastReliableGpsPosition;

  void _handlePositionUpdate(Position position) {
    final now = DateTime.now();
    if (_lastHardwareTimestamp != null &&
        !position.timestamp.isAfter(_lastHardwareTimestamp!)) return;

    if (position.accuracy < 30.0) {
      _gpsStabilityCounter++;
    } else {
      _gpsStabilityCounter = 0;
    }

    bool isGpsTrulyStable =
        _gpsStabilityCounter >= 3 || position.accuracy < 15.0;

    if (state.isInsActive && !isGpsTrulyStable && position.accuracy > 60.0)
      return;

    bool isInGrace = state.isRecording &&
        _recordingStartTime != null &&
        now.difference(_recordingStartTime!).inSeconds < 60;

    final bool isReliable = position.accuracy <= (isInGrace ? 200.0 : 50.0);

    if (state.isRecording && _lastReliableGpsPosition != null && isReliable) {
      final d = _locationService.calculateDistance(
          _lastReliableGpsPosition!.latitude,
          _lastReliableGpsPosition!.longitude,
          position.latitude,
          position.longitude);
      final dt = position.timestamp
              .difference(_lastReliableGpsPosition!.timestamp)
              .inMilliseconds /
          1000.0;
      if (dt > 0.1 && (d / dt) > 80.0) return;
    }

    // 速度平滑：仅用 GPS 更新目标速度，不直接写 state.currentSpeed（由 _handleSensorData 平滑更新）
    final newIsInsActive = !isGpsTrulyStable &&
        position.accuracy > AppConstants.insTriggerAccuracy;
    if (state.isInsActive && !newIsInsActive) {
      _smoothedSpeed = state.currentSpeed; // 退出 INS 时从当前显示速度向新 GPS 收敛
    }
    final speedMs = position.speed;
    if (speedMs.isFinite && speedMs >= 0 && speedMs <= _maxValidSpeedMs) {
      _targetSpeed = speedMs;
      if (_lastSpeedUpdate == null) {
        _smoothedSpeed = _targetSpeed; // 首次 GPS：避免从 0 跳变
      }
    }
    _lastSpeedUpdate = now;

    state = state.copyWith(
      currentPosition: position,
      isInsActive: newIsInsActive,
      isLowConfidenceGPS: position.accuracy > 40.0,
    );

    _lastGpsTime = now;
    _lastHardwareTimestamp = position.timestamp;
    _locationUpdateCount++;

    // ✅ 关键修复：先计算里程，再更新位置变量（避免"先更新后使用"错误）
    if (state.isRecording && state.currentTrip != null) {
      if (_lastReliableGpsPosition != null && isReliable) {
        // 使用【旧的】可靠位置和【新的】当前位置计算距离
        final d = _locationService.calculateDistance(
            _lastReliableGpsPosition!.latitude,
            _lastReliableGpsPosition!.longitude,
            position.latitude,
            position.longitude);
        if (d < 100) {
          // 过滤异常跳变（>100米）
          state = state.copyWith(currentDistance: state.currentDistance + d);
          debugPrint(
              '📏 [Distance] Updated: ${(state.currentDistance / 1000).toStringAsFixed(3)} km (+${d.toStringAsFixed(1)}m)');
        } else {
          debugPrint(
              '⚠️ [Distance] Rejected abnormal jump: ${d.toStringAsFixed(1)}m');
        }
      }
    }

    // ✅ 里程计算完成后，才更新位置变量
    if (isReliable) {
      _insEngine.observeGPS(
        LatLng(position.latitude, position.longitude),
        position.speed,
        position.accuracy,
      );
      _lastReliableGpsPosition = position;

      // ✅ 同时更新有效GPS缓存（用于高频传感器记录）
      if (position.latitude.abs() > 0.001 && position.longitude.abs() > 0.001) {
        _lastValidGpsPosition = position;
      }
    }

    if (state.isRecording && state.currentTrip != null) {
      if (isReliable || isInGrace) {
        final lastPoint =
            state.trajectory.isEmpty ? null : state.trajectory.last;
        if (lastPoint == null ||
            _locationService.calculateDistance(lastPoint.lat, lastPoint.lng,
                    position.latitude, position.longitude) >
                2.0 ||
            now.difference(lastPoint.timestamp).inSeconds > 2) {
          final point = TrajectoryPoint()
            ..lat = position.latitude
            ..lng = position.longitude
            ..altitude = position.altitude
            ..speed = position.speed
            ..timestamp = now
            ..isLowConfidence = position.accuracy > 40.0;

          // ✅ 1Hz 传感器数据记录：将最新的传感器数据附加到GPS轨迹点
          if (_latestSensorData != null) {
            point.ax = _latestSensorData!.processedAccel.x;
            point.ay = _latestSensorData!.processedAccel.y;
            point.az = _latestSensorData!.processedAccel.z;
            point.gx = _latestSensorData!.processedGyro.x;
            point.gy = _latestSensorData!.processedGyro.y;
            point.gz = _latestSensorData!.processedGyro.z;

            debugPrint('🗺️ [1Hz GPS] Trajectory point with sensor data saved');
            debugPrint(
                '   ax=${point.ax?.toStringAsFixed(3)}, ay=${point.ay?.toStringAsFixed(3)}, az=${point.az?.toStringAsFixed(3)}');
            debugPrint(
                '   gx=${point.gx?.toStringAsFixed(3)}, gy=${point.gy?.toStringAsFixed(3)}, gz=${point.gz?.toStringAsFixed(3)}');
          } else {
            debugPrint(
                '⚠️ [1Hz GPS] Trajectory point saved WITHOUT sensor data (sensor not ready)');
          }

          // ✅ 保存轨迹点时同时更新数据库中的distance字段
          debugPrint(
              '💾 [DB Write] Saving trajectory point with distance=${(state.currentDistance / 1000).toStringAsFixed(3)}km');
          _storage.addTrajectoryPoint(state.currentTrip!.id, point,
              distance: state.currentDistance / 1000);
          state = state.copyWith(trajectory: [...state.trajectory, point]);
        }
      }
    }
  }

  void _handleInsTick() {
    if (!state.isInsActive) return;
    final insLatLng = _insEngine.getCurrentLatLng();
    state = state.copyWith(
      currentPosition: Position(
        latitude: insLatLng.latitude,
        longitude: insLatLng.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: state.currentPosition?.altitude ?? 0,
        heading: state.currentPosition?.heading ?? 0,
        speed: _insEngine.currentSpeed,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      ),
      currentSpeed: _insEngine.currentSpeed,
      lastInsLocation: insLatLng,
    );
  }

  Future<void> tagEvent(EventType type,
      {String source = 'MANUAL',
      String? notes,
      String? voiceText,
      DateTime? timestamp,
      double? speed,
      double? lat,
      double? lng}) async {
    if (!state.isRecording || state.currentTrip == null) return;

    final eventTime = timestamp ?? DateTime.now();
    final fragment = _engine.getLookbackBuffer(
        AppConstants.lookbackBufferSeconds,
        targetHz: AppConstants.targetSensorHz,
        endTime: eventTime);

    final event = RecordedEvent()
      ..uuid = const Uuid().v4()
      ..timestamp = eventTime
      ..type = type.name
      ..source = source
      ..speed = speed ?? _insEngine.currentSpeed
      ..gForce = state.currentGForce
      ..notes = notes ?? ""
      ..voiceText = voiceText
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
            ..offsetMs = d.timestamp.difference(eventTime).inMilliseconds)
          .toList();

    if (lat != null && lng != null) {
      event.lat = lat;
      event.lng = lng;
    } else if (state.currentPosition != null) {
      event.lat = state.currentPosition!.latitude;
      event.lng = state.currentPosition!.longitude;
    }

    await _storage.saveEvent(state.currentTrip!.id, event);
    state = state.copyWith(events: [...state.events, event]);

    // 🎥 视频录制：如果启用了视频录制，保存前5秒视频
    final settings = _ref.read(settingsProvider);
    if (settings.isVideoRecordingEnabled) {
      final videoService = _ref.read(videoRecordingServiceProvider);
      final videoPath = await videoService.captureEventVideo(
        eventId: event.uuid,
        duration: 5,
      );

      if (videoPath != null) {
        debugPrint(
            '[Recording] 🎥 Video saved for event ${event.uuid}: $videoPath');
        // TODO: 将视频路径保存到 RecordedEvent 中（需要扩展数据模型）
        // event.videoPath = videoPath;
      } else {
        debugPrint(
            '[Recording] ⚠️ Failed to save video for event ${event.uuid}');
      }
    }

    // 播放提示音 (所有来源均遵守设置开关)
    if (settings.isEventSoundEnabled) {
      debugPrint(
          '[Recording] 🔊 Playing event sound. Source: $source, Volume: 1.0');
      _audioPlayer.play(
        AssetSource('sound/events.mp3'),
        volume: 1.0, // 统一调大音量
      );
    }
  }

  void setAlgorithmMode(AlgorithmMode mode) =>
      state = state.copyWith(algorithmMode: mode);

  Future<void> startRecording({String? carModel, String? notes}) async {
    if (state.isCalibrating || state.isRecording) return;
    try {
      state = state.copyWith(isCalibrating: true);
      await WakelockPlus.enable();
      await _engine.calibrate(
          currentSpeedMs: state.currentPosition?.speed ?? 0.0);
      await _storage.init();
      final trip = await _storage.startTrip(
          carModel: carModel,
          notes: notes,
          algorithm: state.algorithmMode.name);

      // ✅ 初始化所有关键时间戳和位置变量
      _recordingStartTime = DateTime.now();
      _lastGpsTime = DateTime.now();
      _lastSensorRecordTime = null; // 重置传感器记录时间
      _gpsStabilityCounter = 0;
      _insEngine.reset();

      // ✅ 初始化位置变量，用于里程计算
      if (state.currentPosition != null) {
        _lastReliableGpsPosition = state.currentPosition;
        _lastValidGpsPosition = state.currentPosition;
      }

      // 速度平滑：新行程从当前 GPS 速度开始，避免上一行程残留
      final initialSpeed = state.currentPosition?.speed ?? 0.0;
      _targetSpeed =
          initialSpeed.isFinite && initialSpeed >= 0 ? initialSpeed : 0.0;
      _smoothedSpeed = _targetSpeed;
      _lastSpeedUpdate = DateTime.now();

      if (state.currentPosition != null) {
        final startPoint = TrajectoryPoint()
          ..lat = state.currentPosition!.latitude
          ..lng = state.currentPosition!.longitude
          ..altitude = state.currentPosition!.altitude
          ..speed = state.currentPosition!.speed
          ..timestamp = DateTime.now();
        _storage.addTrajectoryPoint(trip.id, startPoint, distance: 0);
        state = state.copyWith(trajectory: [startPoint]);
      }

      _sensorSub?.close();
      _sensorSub = _ref.listen<AsyncValue<SensorData>>(sensorStreamProvider,
          (prev, next) => next.whenData(_handleSensorData),
          fireImmediately: true);

      _engine.setRecording(true);

      // ✅ 初始化行程状态，重置所有计数器
      state = state.copyWith(
        isRecording: true,
        isCalibrating: false,
        currentTrip: trip,
        events: [],
        currentDistance: 0.0, // 重置里程
        maxGForce: 0.0, // 重置峰值G力
      );

      // 🎥 如果启用了视频录制，启动视频录制服务
      final settings = _ref.read(settingsProvider);
      if (settings.isVideoRecordingEnabled) {
        final videoService = _ref.read(videoRecordingServiceProvider);
        final started = await videoService.startRecording(
          resolution: '1080p',
          fps: 60,
          bufferDuration: 10,
        );

        if (started) {
          debugPrint('[Recording] 🎥 Video recording started');
        } else {
          debugPrint('[Recording] ⚠️ Failed to start video recording');
        }
      }
    } catch (e) {
      // 提取错误消息的key（去除 "Exception: " 前缀）
      String errorKey = e.toString();
      debugPrint('[Recording] Caught calibration error: $errorKey');
      if (errorKey.startsWith('Exception: ')) {
        errorKey = errorKey.substring('Exception: '.length);
      }
      debugPrint('[Recording] Cleaned error key: $errorKey');
      state = state.copyWith(isCalibrating: false, alertMessage: errorKey);
    }
  }

  void _handleSensorData(SensorData sensorData) {
    if (!state.isRecording) return;
    final now = DateTime.now();
    final lastActual = _engine.lastSensorEventTime;
    final isFrozen = now.difference(lastActual).inMilliseconds > 500;

    if (state.isSensorFrozen != isFrozen) {
      state = state.copyWith(isSensorFrozen: isFrozen);
    }
    if (isFrozen) return;

    // 缓存最新的传感器数据，供GPS轨迹点使用（1Hz记录）
    _latestSensorData = sensorData;

    // 🔍 DEBUG: 验证传感器数据缓存
    debugPrint(
        '🔄 [Sensor Cache] Updated: ax=${sensorData.processedAccel.x.toStringAsFixed(3)}, ay=${sensorData.processedAccel.y.toStringAsFixed(3)}, az=${sensorData.processedAccel.z.toStringAsFixed(3)}');

    _insEngine.predict(sensorData);

    // 速度平滑：仅当非 INS 时用平滑值更新 state.currentSpeed（INS 时由 _handleInsTick 写入）
    if (!state.isInsActive) {
      final dtMs = _lastSpeedUpdate != null
          ? now.difference(_lastSpeedUpdate!).inMilliseconds
          : 0;
      final alpha = dtMs < 100 ? _speedSmoothAlphaFast : _speedSmoothAlpha;
      _smoothedSpeed = _smoothedSpeed * (1.0 - alpha) + _targetSpeed * alpha;
      if ((state.currentSpeed - _smoothedSpeed).abs() > _speedUpdateThreshold) {
        state = state.copyWith(currentSpeed: _smoothedSpeed);
      }
    }

    if (state.isInsActive) {
      final bool isTooOld =
          _lastGpsTime != null && now.difference(_lastGpsTime!).inSeconds > 60;
      if (isTooOld) {
        state = state.copyWith(isInsActive: false);
      } else {
        _handleInsTick();
      }
    } else {
      final bool isMissing = _lastGpsTime != null &&
          now.difference(_lastGpsTime!) > AppConstants.gpsTimeout;
      final bool isUnreliable = (state.currentPosition?.accuracy ?? 0) >
          AppConstants.insTriggerAccuracy;
      if (_insEngine.isInitialized && (isMissing || isUnreliable)) {
        state = state.copyWith(isInsActive: true);
      }
    }

    // 静止判断只用 GPS 速度，避免 INS 在手机角度变化时误报 1～5 导致「无法校准」的死循环
    final speedForStationary = (state.isInsActive || _lastSpeedUpdate == null)
        ? 999.0 // INS 或无 GPS：视为非静止，不触发自动校准
        : _targetSpeed;
    _engine.updateSpeed(speedForStationary);

    _motionProcessor.process(sensorData, state.currentSpeed,
        state.currentPosition, state.isInsActive);

    // --- 传感器数据记录 ---
    // 高帧率模式 (10Hz) 或 普通模式 (1Hz)
    final settings = _ref.read(settingsProvider);
    final recordIntervalMs = settings.isHighFrameRateEnabled ? 100 : 1000;

    if (state.currentTrip != null) {
      if (_lastSensorRecordTime == null ||
          now.difference(_lastSensorRecordTime!).inMilliseconds >=
              recordIntervalMs) {
        _lastSensorRecordTime = now;

        // 创建包含传感器数据的轨迹点
        // 注意：为了防止内存溢出和 UI 卡顿，高频点仅持久化，不进入 state.trajectory
        final displaySpeed = state.isInsActive
            ? _insEngine.currentSpeed
            : (state.currentPosition?.speed ?? 0.0);

        // ✅ 使用最后有效的GPS位置，如果当前GPS无效
        final gpsToUse = (state.currentPosition != null &&
                state.currentPosition!.latitude.abs() > 0.001 &&
                state.currentPosition!.longitude.abs() > 0.001)
            ? state.currentPosition
            : _lastValidGpsPosition;

        // ✅ 只有在有有效GPS时才记录轨迹点
        if (gpsToUse != null) {
          final sensorPoint = TrajectoryPoint()
            ..timestamp = now
            ..lat = gpsToUse.latitude
            ..lng = gpsToUse.longitude
            ..altitude = gpsToUse.altitude
            ..speed = displaySpeed
            ..isLowConfidence = state.isLowConfidenceGPS
            ..ax = sensorData.processedAccel.x
            ..ay = sensorData.processedAccel.y
            ..az = sensorData.processedAccel.z
            ..gx = sensorData.processedGyro.x
            ..gy = sensorData.processedGyro.y
            ..gz = sensorData.processedGyro.z;

          _storage.addTrajectoryPointBatched(
              state.currentTrip!.id, sensorPoint);

          if (settings.isHighFrameRateEnabled) {
            debugPrint(
                '📡 [10Hz] Queued sensor data with GPS: lat=${gpsToUse.latitude.toStringAsFixed(6)}');
          } else {
            debugPrint(
                '📡 [1Hz] Queued sensor data with GPS: lat=${gpsToUse.latitude.toStringAsFixed(6)}');
          }
        } else {
          // GPS完全丢失，跳过此次记录
          debugPrint(
              '⚠️ [${settings.isHighFrameRateEnabled ? "10Hz" : "1Hz"}] Skipped: No valid GPS available');
        }
      }
    }
  }

  Future<void> stopRecording() async {
    if (!state.isRecording) return;

    // 🎥 如果启用了视频录制，停止视频录制服务
    final settings = _ref.read(settingsProvider);
    if (settings.isVideoRecordingEnabled) {
      final videoService = _ref.read(videoRecordingServiceProvider);
      final stopped = await videoService.stopRecording();

      if (stopped) {
        debugPrint('[Recording] 🎥 Video recording stopped');
      } else {
        debugPrint('[Recording] ⚠️ Failed to stop video recording');
      }
    }

    _sensorSub?.close();
    _sensorSub = null;

    _engine.setRecording(false);

    // 确保所有待写入的批量数据被flush
    if (state.currentTrip != null) {
      await _storage.flushPendingPoints(state.currentTrip!.id);
    }

    await _storage.endTrip(state.currentTrip!.id);
    await WakelockPlus.disable();

    // ✅ 完全清理所有状态，准备下一次行程
    state = state.copyWith(
      isRecording: false,
      currentTrip: null,
      trajectory: [], // 清空轨迹列表
      events: [], // 清空事件列表
      currentDistance: 0.0, // 重置里程
      currentSpeed: 0.0, // 重置速度
      maxGForce: 0.0, // 重置峰值G力
      currentGForce: 0.0, // 重置当前G力
      isInsActive: false, // 重置INS状态
      lastInsLocation: null, // 清空INS位置
    );

    // ✅ 清理内部缓存变量
    _lastValidGpsPosition = null;
    _lastReliableGpsPosition = null;
    _lastSensorRecordTime = null;
    _latestSensorData = null;
    _targetSpeed = 0.0;
    _smoothedSpeed = 0.0;
    _lastSpeedUpdate = null;

    debugPrint('✅ [Recording] Stopped and cleaned up all state');
  }

  void clearAlert() {
    debugPrint(
        '[Recording] clearAlert called, current alertMessage: ${state.alertMessage}');
    state = state.copyWith(alertMessage: null);
    debugPrint('[Recording] alertMessage after clear: ${state.alertMessage}');
  }

  @override
  void dispose() {
    _motionProcessor.dispose();
    _audioPlayer.dispose();
    _positionSub?.cancel();
    _sensorSub?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final recordingProvider =
    StateNotifierProvider<RecordingNotifier, RecordingState>((ref) {
  final engine = ref.watch(sensorEngineProvider);
  final storage = ref.watch(storageServiceProvider);
  return RecordingNotifier(engine, storage, ref);
});
