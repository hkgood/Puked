import 'package:puked/models/db_models.dart';

/// 离线行程数据抽稀与摘要服务
///
/// 输入：已加载 trajectory + events 的 Trip 对象
/// 输出：精简后的 Map（约 1 000～2 000 tokens），供 AI 点评使用
///
/// 设计原则（第一性原理）：
///   - 抽稀不丢失「可点评」信息：城市、场景、品牌、事件类型与密度
///   - 不依赖网络，全部在本地 Dart 逻辑中完成
///   - 控制体积：轨迹最多 60 点，事件最多 20 条简要记录，不含 sensor_fragment
class TripSummaryService {
  // ─── 抽稀参数 ───────────────────────────────────────────
  static const int _maxTrajectoryPoints = 60;
  static const int _minIntervalSec = 30;
  static const int _maxEventSamples = 20;

  // ─── 全球城市经纬度区间（粗粒度匹配，仅用于摘要显示；未匹配时传坐标供 AI 推断任意地区） ─
  static const _cityBounds = [
    // 中国
    (name: '上海', latMin: 30.6, latMax: 31.9, lngMin: 120.8, lngMax: 122.2),
    (name: '广州', latMin: 22.4, latMax: 23.9, lngMin: 112.9, lngMax: 114.1),
    (name: '深圳', latMin: 22.4, latMax: 22.9, lngMin: 113.7, lngMax: 114.6),
    (name: '北京', latMin: 39.4, latMax: 41.1, lngMin: 115.4, lngMax: 117.5),
    (name: '杭州', latMin: 29.8, latMax: 30.6, lngMin: 118.9, lngMax: 120.9),
    (name: '成都', latMin: 30.0, latMax: 31.4, lngMin: 103.3, lngMax: 104.9),
    (name: '武汉', latMin: 29.9, latMax: 31.4, lngMin: 113.7, lngMax: 115.1),
    (name: '西安', latMin: 33.4, latMax: 34.7, lngMin: 107.7, lngMax: 109.5),
    // 全球常见区域（示例，可扩展）
    (name: 'Tokyo', latMin: 35.5, latMax: 35.8, lngMin: 139.6, lngMax: 139.9),
    (name: 'San Francisco', latMin: 37.6, latMax: 37.8, lngMin: -122.5, lngMax: -122.3),
    (name: 'Los Angeles', latMin: 33.9, latMax: 34.2, lngMin: -118.4, lngMax: -118.2),
    (name: 'New York', latMin: 40.5, latMax: 40.9, lngMin: -74.0, lngMax: -73.7),
    (name: 'London', latMin: 51.4, latMax: 51.6, lngMin: -0.2, lngMax: 0.1),
    (name: 'Berlin', latMin: 52.4, latMax: 52.6, lngMin: 13.2, lngMax: 13.5),
    (name: 'Paris', latMin: 48.8, latMax: 48.9, lngMin: 2.2, lngMax: 2.4),
    (name: 'Sydney', latMin: -33.9, latMax: -33.8, lngMin: 151.1, lngMax: 151.3),
    (name: 'Singapore', latMin: 1.2, latMax: 1.4, lngMin: 103.7, lngMax: 104.0),
  ];

  /// 生成行程摘要 Map，全部离线计算
  Map<String, dynamic> buildSummary(
    Trip trip, {
    String? brandName,
  }) {
    final trajectory = trip.trajectory.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final events = trip.events.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // ── 基础指标 ─────────────────────────────────────────
    final distanceKm = trip.displayDistance;
    final durationSec = trip.endTime != null
        ? trip.endTime!.difference(trip.startTime).inSeconds
        : 0;
    final durationMin = durationSec ~/ 60;
    final avgSpeedKmh = durationSec > 0 && distanceKm > 0
        ? distanceKm / (durationSec / 3600.0)
        : 0.0;

    // ── 速度分布统计（用于场景推断 + AI 描述） ─────────────
    final drivingStats = _calcDrivingStats(trajectory, avgSpeedKmh);
    final maxSpeedKmh = (drivingStats['max_speed_kmh'] as double?) ?? 0.0;

    // ── 行程质量分类（供 AI 感知异常场景） ─────────────────
    final tripQuality = _classifyTripQuality(
      distanceKm: distanceKm,
      durationSec: durationSec,
      maxSpeedKmh: maxSpeedKmh,
      trajectory: trajectory,
    );

    // ── 城市 & 场景推断 ──────────────────────────────────
    final centerLat = _centerLat(trajectory);
    final centerLng = _centerLng(trajectory);
    final city = _inferCity(centerLat, centerLng);
    final scene = _inferScene(avgSpeedKmh, drivingStats);

    // ── 轨迹抽稀 ──────────────────────────────────────────
    final sampledPoints = _sampleTrajectory(trajectory);

    // ── 事件摘要 ──────────────────────────────────────────
    final eventBreakdown = _buildEventBreakdown(events);
    final eventsSummary = _buildEventsSummary(events, trip.startTime);

    // ── 组装摘要 JSON ────────────────────────────────────
    return {
      'trip_id': trip.uuid.substring(0, 8),
      'metadata': {
        'start_time': _fmtDt(trip.startTime),
        'end_time': trip.endTime != null ? _fmtDt(trip.endTime!) : null,
        'duration_min': durationMin,
        'duration_sec': durationSec,
        'distance_km': distanceKm.toStringAsFixed(2),
        'avg_speed_kmh': avgSpeedKmh.toStringAsFixed(1),
        'car_model': trip.carModel ?? 'Others',
        'brand_name': brandName ?? trip.brand ?? 'Others',
        'city': city,
        'scene': scene,
        'event_count': trip.eventCount,
        'event_breakdown': eventBreakdown,
        'trip_quality': tripQuality,
      },
      'route_summary': {
        'total_points': trajectory.length,
        'sampled_points': sampledPoints.length,
        'points': sampledPoints,
      },
      'events_summary': eventsSummary,
      'driving_stats': drivingStats,
    };
  }

  // ─── 行程质量分类 ──────────────────────────────────────
  // 返回值：
  //   'debug'       - 时间极短且 GPS 静止，极可能是调试/测试
  //   'stationary'  - GPS 基本未移动（停车、挪车等）
  //   'ultra_short' - 距离 < 300m
  //   'short'       - 距离 < 1km
  //   'normal'      - 正常行程
  String _classifyTripQuality({
    required double distanceKm,
    required int durationSec,
    required double maxSpeedKmh,
    required List<TrajectoryPoint> trajectory,
  }) {
    final gpsStationary = _isGpsStationary(trajectory);

    // GPS 完全未移动 + 速度为 0 → 静止
    if (gpsStationary || (distanceKm < 0.05 && maxSpeedKmh < 2)) {
      // 时间极短 → 几乎可以确定是调试/测试启动
      if (durationSec < 60) return 'debug';
      return 'stationary';
    }

    if (distanceKm < 0.3) return 'ultra_short';
    if (distanceKm < 1.0) return 'short';
    return 'normal';
  }

  /// 检测轨迹是否静止（所有点的经纬度偏移 < ~20m）
  bool _isGpsStationary(List<TrajectoryPoint> trajectory) {
    if (trajectory.length < 2) return true;
    final refLat = trajectory.first.lat;
    final refLng = trajectory.first.lng;
    for (final p in trajectory) {
      // 0.0002° ≈ 22m（纬度），约 17m（经度 at 31°N）
      if ((p.lat - refLat).abs() > 0.0002 || (p.lng - refLng).abs() > 0.0002) {
        return false;
      }
    }
    return true;
  }

  // ─── 轨迹均匀抽稀 ──────────────────────────────────────
  List<Map<String, dynamic>> _sampleTrajectory(
      List<TrajectoryPoint> trajectory) {
    if (trajectory.isEmpty) return [];

    final result = <Map<String, dynamic>>[];

    if (trajectory.length <= _maxTrajectoryPoints) {
      // 点数本就不多，全量保留
      return trajectory.map(_pointToMap).toList();
    }

    // 方案：先按时间间隔取，最多取 _maxTrajectoryPoints 点
    DateTime? lastTs;
    for (final p in trajectory) {
      if (lastTs == null ||
          p.timestamp.difference(lastTs).inSeconds >= _minIntervalSec) {
        result.add(_pointToMap(p));
        lastTs = p.timestamp;
        if (result.length >= _maxTrajectoryPoints) break;
      }
    }

    // 确保最后一个点也被包含（用于判断行程终点）
    final last = trajectory.last;
    if (result.isEmpty || result.last['ts'] != last.timestamp.millisecondsSinceEpoch / 1000.0) {
      result.add(_pointToMap(last));
    }

    return result;
  }

  Map<String, dynamic> _pointToMap(TrajectoryPoint p) {
    return {
      'ts': double.parse((p.timestamp.millisecondsSinceEpoch / 1000.0).toStringAsFixed(1)),
      'lat': double.parse(p.lat.toStringAsFixed(4)),
      'lng': double.parse(p.lng.toStringAsFixed(4)),
      'speed': double.parse(p.speed.toStringAsFixed(1)),
    };
  }

  // ─── 事件统计 & 摘要 ────────────────────────────────────
  Map<String, int> _buildEventBreakdown(List<RecordedEvent> events) {
    final breakdown = <String, int>{};
    for (final e in events) {
      breakdown[e.type] = (breakdown[e.type] ?? 0) + 1;
    }
    return breakdown;
  }

  List<Map<String, dynamic>> _buildEventsSummary(
      List<RecordedEvent> events, DateTime tripStart) {
    // 最多取前 N 条（已按时间排好序）
    final sample = events.length <= _maxEventSamples
        ? events
        : events.sublist(0, _maxEventSamples);

    return sample.map((e) {
      final offsetSec = e.timestamp.difference(tripStart).inSeconds;
      return {
        'offset_sec': offsetSec,
        'type': e.type,
        if (e.lat != null) 'lat': double.parse(e.lat!.toStringAsFixed(4)),
        if (e.lng != null) 'lng': double.parse(e.lng!.toStringAsFixed(4)),
        if (e.speed != null) 'speed_kmh': double.parse((e.speed! * 3.6).toStringAsFixed(1)),
      };
    }).toList();
  }

  // ─── 驾驶风格统计 ──────────────────────────────────────
  Map<String, dynamic> _calcDrivingStats(
      List<TrajectoryPoint> trajectory, double avgSpeedKmh) {
    if (trajectory.isEmpty) {
      return {
        'max_speed_kmh': 0.0,
        'low_speed_ratio': 0.0,
        'high_speed_ratio': 0.0,
      };
    }

    double maxSpeed = 0;
    int lowSpeedCount = 0; // < 15 km/h
    int highSpeedCount = 0; // > 80 km/h

    for (final p in trajectory) {
      final kmh = p.speed * 3.6;
      if (kmh > maxSpeed) maxSpeed = kmh;
      if (kmh < 15) lowSpeedCount++;
      if (kmh > 80) highSpeedCount++;
    }

    final n = trajectory.length;
    return {
      'max_speed_kmh': double.parse(maxSpeed.toStringAsFixed(1)),
      'low_speed_ratio': double.parse((lowSpeedCount / n).toStringAsFixed(2)),
      'high_speed_ratio': double.parse((highSpeedCount / n).toStringAsFixed(2)),
    };
  }

  // ─── 城市/地区推断（支持全球 GPS）────────────────────────
  // 先做本地粗匹配；未匹配时返回标准经纬度，供 AI 根据全球任意坐标推断城市/地区名。
  String _inferCity(double? lat, double? lng) {
    if (lat == null || lng == null) return 'Unknown';
    for (final c in _cityBounds) {
      if (lat >= c.latMin &&
          lat <= c.latMax &&
          lng >= c.lngMin &&
          lng <= c.lngMax) {
        return c.name;
      }
    }
    // 全球任意坐标：统一格式供 AI 推断，不写「坐标区域」等地域限定表述
    final latStr = lat.toStringAsFixed(2);
    final lngStr = lng.toStringAsFixed(2);
    return '($latStr, $lngStr)';
  }

  // ─── 场景推断 ──────────────────────────────────────────
  String _inferScene(double avgSpeedKmh, Map<String, dynamic> stats) {
    final lowRatio = (stats['low_speed_ratio'] as double? ?? 0.0);
    final highRatio = (stats['high_speed_ratio'] as double? ?? 0.0);

    if (highRatio > 0.25) return '高速/快速路';
    if (avgSpeedKmh >= 40 && lowRatio < 0.3) return '郊外道路';
    if (avgSpeedKmh < 20 || lowRatio > 0.5) return '城市拥堵路段';
    return '城市道路';
  }

  // ─── 轨迹中心 ────────────────────────────────────────────
  double? _centerLat(List<TrajectoryPoint> trajectory) {
    if (trajectory.isEmpty) return null;
    // 取中间点，比均值更稳定（抗 GPS 漂移）
    return trajectory[trajectory.length ~/ 2].lat;
  }

  double? _centerLng(List<TrajectoryPoint> trajectory) {
    if (trajectory.isEmpty) return null;
    return trajectory[trajectory.length ~/ 2].lng;
  }

  String _fmtDt(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} ${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
