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
    Object? alertMessage = _undefined,  // 使用哨兵对象来区分"未传参"和"传入null"
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
          : alertMessage as String?,  // 允许真正设置为 null
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
  DateTime? _lastLocationTime;
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

    bool isGpsTrulyStable = _gpsStabilityCounter >= 3 || position.accuracy < 15.0;

    if (state.isInsActive && !isGpsTrulyStable && position.accuracy > 60.0) return;

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

    state = state.copyWith(
      currentPosition: position,
      isInsActive:
          !isGpsTrulyStable && position.accuracy > AppConstants.insTriggerAccuracy,
      isLowConfidenceGPS: position.accuracy > 40.0,
    );

    _lastGpsTime = now;
    _lastHardwareTimestamp = position.timestamp;
    _lastLocationTime = now;
    _locationUpdateCount++;

    if (isReliable) {
      _insEngine.observeGPS(
        LatLng(position.latitude, position.longitude),
        position.speed,
        position.accuracy,
      );
      _lastReliableGpsPosition = position;
    }

    if (state.isRecording && state.currentTrip != null) {
      if (_lastLocationTime != null && _lastReliableGpsPosition != null) {
        final d = _locationService.calculateDistance(
            _lastReliableGpsPosition!.latitude,
            _lastReliableGpsPosition!.longitude,
            position.latitude,
            position.longitude);
        if (isReliable && d < 100) {
          state = state.copyWith(currentDistance: state.currentDistance + d);
        }
      }

      if (isReliable || isInGrace) {
        final lastPoint = state.trajectory.isEmpty ? null : state.trajectory.last;
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
            debugPrint('   ax=${point.ax?.toStringAsFixed(3)}, ay=${point.ay?.toStringAsFixed(3)}, az=${point.az?.toStringAsFixed(3)}');
            debugPrint('   gx=${point.gx?.toStringAsFixed(3)}, gy=${point.gy?.toStringAsFixed(3)}, gz=${point.gz?.toStringAsFixed(3)}');
          } else {
            debugPrint('⚠️ [1Hz GPS] Trajectory point saved WITHOUT sensor data (sensor not ready)');
          }
          
          debugPrint('💾 [DB Write] Saving trajectory point to database (ax=${point.ax}, ay=${point.ay})');
          _storage.addTrajectoryPoint(state.currentTrip!.id, point);
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
    final fragment = _engine.getLookbackBuffer(AppConstants.lookbackBufferSeconds,
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

    // 播放提示音 (所有来源均遵守设置开关)
    final settings = _ref.read(settingsProvider);
    if (settings.isEventSoundEnabled) {
      debugPrint('[Recording] 🔊 Playing event sound. Source: $source, Volume: 1.0');
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
      await _engine.calibrate(currentSpeedMs: state.currentPosition?.speed ?? 0.0);
      await _storage.init();
      final trip = await _storage.startTrip(
          carModel: carModel, notes: notes, algorithm: state.algorithmMode.name);

      _recordingStartTime = DateTime.now();
      _lastGpsTime = DateTime.now();
      _gpsStabilityCounter = 0;
      _insEngine.reset();

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

      state = state.copyWith(
          isRecording: true, isCalibrating: false, currentTrip: trip, events: []);
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
    debugPrint('🔄 [Sensor Cache] Updated: ax=${sensorData.processedAccel.x.toStringAsFixed(3)}, ay=${sensorData.processedAccel.y.toStringAsFixed(3)}, az=${sensorData.processedAccel.z.toStringAsFixed(3)}');

    _insEngine.predict(sensorData);
    _motionProcessor.process(
        sensorData, _insEngine.currentSpeed, state.currentPosition, state.isInsActive);

    // --- KOL 专属：高帧率数据记录 (10Hz) ---
    final settings = _ref.read(settingsProvider);
    if (settings.isHighFrameRateEnabled && state.currentTrip != null) {
      if (_lastSensorRecordTime == null ||
          now.difference(_lastSensorRecordTime!).inMilliseconds >= 100) {
        _lastSensorRecordTime = now;

        // 创建包含传感器数据的轨迹点
        // 注意：为了防止内存溢出和 UI 卡顿，高频点仅持久化，不进入 state.trajectory
        final displaySpeed = state.isInsActive
            ? _insEngine.currentSpeed
            : (state.currentPosition?.speed ?? 0.0);

        final sensorPoint = TrajectoryPoint()
          ..timestamp = now
          ..lat = state.currentPosition?.latitude ?? 0
          ..lng = state.currentPosition?.longitude ?? 0
          ..altitude = state.currentPosition?.altitude ?? 0
          ..speed = displaySpeed
          ..isLowConfidence = state.isLowConfidenceGPS
          ..ax = sensorData.processedAccel.x
          ..ay = sensorData.processedAccel.y
          ..az = sensorData.processedAccel.z
          ..gx = sensorData.processedGyro.x
          ..gy = sensorData.processedGyro.y
          ..gz = sensorData.processedGyro.z;

        _storage.addTrajectoryPointBatched(state.currentTrip!.id, sensorPoint);
        
        debugPrint('📡 [10Hz] Queued sensor data: ay=${sensorData.processedAccel.y.toStringAsFixed(3)}');
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
      final bool isMissing =
          _lastGpsTime != null && now.difference(_lastGpsTime!) > AppConstants.gpsTimeout;
      final bool isUnreliable =
          (state.currentPosition?.accuracy ?? 0) > AppConstants.insTriggerAccuracy;
      if (_insEngine.isInitialized && (isMissing || isUnreliable)) {
        state = state.copyWith(isInsActive: true);
      }
    }
  }

  Future<void> stopRecording() async {
    if (!state.isRecording) return;
    _sensorSub?.close();
    _sensorSub = null;
    
    // 确保所有待写入的批量数据被flush
    if (state.currentTrip != null) {
      await _storage.flushPendingPoints(state.currentTrip!.id);
    }
    
    await _storage.endTrip(state.currentTrip!.id);
    await WakelockPlus.disable();
    state = state.copyWith(isRecording: false, currentTrip: null);
  }

  void clearAlert() {
    debugPrint('[Recording] clearAlert called, current alertMessage: ${state.alertMessage}');
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
