import { ArenaService } from '../../arena/services/arenaService';
import { G_FORCE } from '../config/dashboardConstants';

/**
 * 解析行程统计指标
 */
export const parseMetrics = (trip: any, detailMetadata?: any) => {
  console.log('[parseMetrics] Input:', { trip, detailMetadata });

  if (!trip) return { eventCount: 0, distanceKm: 0, durationMin: 0, avgSpeed: 0 };

  // 首先尝试解析 metrics 字段（PocketBase 可能返回字符串或对象）
  let metrics: any = {};
  if (trip.metrics) {
    if (typeof trip.metrics === 'string') {
      try { metrics = JSON.parse(trip.metrics); } catch (e) { metrics = {}; }
    } else {
      metrics = trip.metrics;
    }
  }
  console.log('[parseMetrics] Parsed metrics:', metrics);

  // 确定 metadata 数据源：优先使用加载的详细数据，否则使用 trip 自带的 metadata
  const metadata = detailMetadata || trip.metadata || {};
  console.log('[parseMetrics] Metadata source:', metadata);

  // 使用 ArenaService 计算距离和速度（支持多种数据格式）
  const dataToUse = detailMetadata ? { ...trip, metadata: detailMetadata } : trip;
  const distanceKm = ArenaService.getKm(dataToUse.metrics || dataToUse);
  const avgSpeed = ArenaService.getAvgSpeed(dataToUse.metrics || dataToUse);

  // 事件数量：优先从 metadata，回退到 metrics
  const eventCount = metadata.event_count ?? metrics.event_count ?? 0;

  // 时长计算：优先使用 start_time 和 end_time 计算精确时长
  let durationMin = 0;
  if (metadata.start_time && metadata.end_time) {
    const start = new Date(metadata.start_time).getTime();
    const end = new Date(metadata.end_time).getTime();
    durationMin = Math.max(0, (end - start) / (1000 * 60));
    console.log('[parseMetrics] Duration from timestamps:', { start_time: metadata.start_time, end_time: metadata.end_time, durationMin });
  } else if (metrics.duration_min) {
    // PocketBase 中直接存储为 duration_min（分钟）
    const minutes = parseFloat(String(metrics.duration_min));
    durationMin = isNaN(minutes) ? 0 : minutes;
    console.log('[parseMetrics] Duration from duration_min:', minutes);
  } else {
    // 回退到 duration_seconds 字段（秒）
    const durationSeconds =
      metadata.duration_seconds ||
      metadata.duration_sec ||
      metadata.duration_s ||
      metrics.duration_seconds ||
      metrics.duration_sec ||
      metrics.duration_s ||
      0;

    console.log('[parseMetrics] Duration from seconds field:', durationSeconds);

    // 转换为数字（可能是字符串）
    const seconds = parseFloat(String(durationSeconds));
    durationMin = isNaN(seconds) ? 0 : seconds / 60;
  }

  const result = {
    eventCount: Number(eventCount) || 0,
    distanceKm: Number(distanceKm) || 0,
    durationMin: Math.round(durationMin),
    avgSpeed: avgSpeed > 0 ? Number(avgSpeed.toFixed(1)) : 0
  };

  console.log('[parseMetrics] Result:', result);
  return result;
};

/**
 * 归一化轨迹数据
 */
export const parseTrajectory = (trip: any, fullTrajectory?: any[]) => {
  if (fullTrajectory) return fullTrajectory;
  if (!trip) return [];

  const raw = trip.trajectory || trip.route_summary || trip.points;
  if (!raw) return [];

  try {
    const parsed = typeof raw === 'string' ? JSON.parse(raw) : (Array.isArray(raw) ? raw : []);
    return parsed.map((p: any) => ({
      ts: p.ts || p.timestamp || p.time || 0,
      lat: p.lat || p.latitude || 0,
      lng: p.lng || p.longitude || 0,
      speed: p.speed !== undefined ? p.speed : (p.v || 0)
    }));
  } catch {
    return [];
  }
};

/**
 * 获取行程事件并归一化坐标
 */
export const getEvents = (trip: any, fullEvents?: any[]) => {
  const rawEvents = fullEvents || trip?.events;
  if (!rawEvents) return [];
  let events = [];
  try {
    events = typeof rawEvents === 'string' ? JSON.parse(rawEvents) : (Array.isArray(rawEvents) ? rawEvents : []);
  } catch {
    return [];
  }
  return events.map((e: any) => ({
    ...e,
    lat: e.lat ?? e.location?.lat,
    lng: e.lng ?? e.location?.lng
  }));
};

/**
 * 计算两个坐标点之间的航向角（弧度）
 */
export const calculateHeading = (p1: any, p2: any) => {
  const lat1 = ((p1.lat || 0) * Math.PI) / 180.0;
  const lon1 = ((p1.lng || 0) * Math.PI) / 180.0;
  const lat2 = ((p2.lat || 0) * Math.PI) / 180.0;
  const lon2 = ((p2.lng || 0) * Math.PI) / 180.0;
  const dLon = lon2 - lon1;
  const y = Math.sin(dLon) * Math.cos(lat2);
  const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
  return Math.atan2(y, x);
};

/**
 * 辅助函数：安全地提取传感器值
 */
export const getSensorVal = (obj: any, key: 'accel' | 'gyro' | 'mag', index: number) => {
  if (!obj || !obj[key]) return 0;
  const data = obj[key];
  if (Array.isArray(data)) return data[index] || 0;
  const map = { 0: 'x', 1: 'y', 2: 'z' };
  const char = map[index as keyof typeof map];
  return data[char] || 0;
};
