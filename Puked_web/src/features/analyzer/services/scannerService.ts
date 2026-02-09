import { ConfigService } from './configService';

export interface ScanResult {
  isUnreasonable: boolean;
  reason?: string;
  suggestedType?: string;
  confidence: number; // 0.0 - 1.0
}

export interface SupplementalEvent {
  timestamp: number;
  type: string;
  reason: string;
  confidence: number;
  lat?: number;
  lng?: number;
  speed?: number;
  accel?: number;
  sensor_fragment?: any;
  score?: number; // 特征强度得分
}

export class ScannerService {
  /**
   * 审计现有事件 (Ported from recording_provider.dart & ins_engine.dart logic)
   */
  static async auditEvent(event: any, _tripStartTime: string): Promise<ScanResult> {
    const config = await ConfigService.getLatestConfig();
    const sensorData = event.sensor_fragment?.data || [];
    const speed = event.location?.speed ?? event.speed ?? 0;
    const speedKmh = speed * 3.6;

    // 1. 车速熔断 (安卓最新逻辑: 3.0 km/h)
    if (speedKmh < 3.0) {
      return { 
        isUnreasonable: true, 
        reason: `静止状态干扰 (车速: ${speedKmh.toFixed(1)} km/h)`, 
        confidence: 1.0,
        suggestedType: undefined
      };
    }

    if (sensorData.length === 0 && !event.gps_accel) {
      return { isUnreasonable: true, reason: '无传感器数据', confidence: 1.0 };
    }

    // 2. 物理指标提取
    const ayList = sensorData.map((d: any) => (Array.isArray(d.accel) ? d.accel[1] : (d.accel?.y ?? d.ay ?? 0)));
    const axList = sensorData.map((d: any) => (Array.isArray(d.accel) ? d.accel[0] : (d.accel?.x ?? d.ax ?? 0)));
    const azList = sensorData.map((d: any) => (Array.isArray(d.accel) ? d.accel[2] : (d.accel?.z ?? d.az ?? 0)));
    const gxList = sensorData.map((d: any) => (Array.isArray(d.gyro) ? d.gyro[0] : (d.gyro?.x ?? d.gx ?? 0)));
    const gzList = sensorData.map((d: any) => (Array.isArray(d.gyro) ? d.gyro[2] : (d.gyro?.z ?? d.gz ?? 0)));
    
    const maxAy = sensorData.length > 0 ? Math.max(...ayList) : (event.gps_accel || 0);
    const minAy = sensorData.length > 0 ? Math.min(...ayList) : (event.gps_accel || 0);
    const maxAz = sensorData.length > 0 ? Math.max(...azList.map(Math.abs)) : 0;
    const spanAx = sensorData.length > 0 ? (Math.max(...axList) - Math.min(...axList)) : (event.gps_accel ? Math.abs(event.gps_accel) : 0);
    const maxGx = sensorData.length > 0 ? Math.max(...gxList.map(Math.abs)) : 0;

    // 3. 计算 Jerk (安卓最新: 窗口内点对点最大跳变)
    let maxJerk = 0;
    if (sensorData.length >= 2) {
      for (let i = 1; i < sensorData.length; i++) {
        const dt = (sensorData[i].offset_ms - sensorData[i - 1].offset_ms) / 1000.0;
        if (dt > 0) {
          const jerk = Math.abs((ayList[i] - ayList[i - 1]) / dt);
          if (jerk > maxJerk) maxJerk = jerk;
        }
      }
    }

    // 4. 跨平台适配因子
    let factor = 1.0;
    if (speedKmh < 10) factor = config.speed_low_factor;
    else if (speedKmh > 80) factor = config.speed_high_factor;

    // 5. Z-Y 轴间抑制 (过坎保护) - 安卓最新: 幂函数增强
    let couplingSuppression = 1.0;
    if (maxAz > config.zy_interference_threshold) {
      couplingSuppression = 1.0 + Math.pow(maxAz - config.zy_interference_threshold, 1.2) * 0.5;
      couplingSuppression = Math.min(couplingSuppression, 3.5);
    }

    const type = event.type;
    const thresholdFactor = factor * couplingSuppression;

    // 6. 物理上限过滤 (Sanity Check)
    if (Math.abs(maxAy) > config.max_accel_allowed || Math.abs(minAy) > config.max_accel_allowed) {
        return { isUnreasonable: true, reason: '超越物理极限的加速度 (手机晃动)', confidence: 0.95 };
    }
    if (maxJerk > config.max_jerk_allowed) {
        return { isUnreasonable: true, reason: '超越物理极限的冲击 (Jerk)', confidence: 0.95 };
    }

    // 7. 具体类型校验
    switch (type) {
      case 'rapidAcceleration':
        if (maxAy < config.threshold_accel * thresholdFactor) {
          return { isUnreasonable: true, reason: `加速度不足 (实际: ${maxAy.toFixed(2)}, 阈值: ${(config.threshold_accel * thresholdFactor).toFixed(2)})`, confidence: 0.8 };
        }
        // 俯仰角校验 (如果启用)
        if (config.pitch_validation_enabled && maxGx < (config.threshold_pitch / 10.0)) {
           return { isUnreasonable: true, reason: '缺乏俯仰特征 (点头/抬头不明显)', confidence: 0.6 };
        }
        break;
      case 'rapidDeceleration':
        if (minAy > config.threshold_decel * thresholdFactor) {
          return { isUnreasonable: true, reason: `减速度不足 (实际: ${minAy.toFixed(2)}, 阈值: ${(config.threshold_decel * thresholdFactor).toFixed(2)})`, confidence: 0.8 };
        }
        if (config.pitch_validation_enabled && maxGx < (config.threshold_pitch / 10.0)) {
           return { isUnreasonable: true, reason: '缺乏俯仰特征 (点头/抬头不明显)', confidence: 0.6 };
        }
        break;
      case 'jerk':
        if (maxJerk < config.threshold_jerk * thresholdFactor) {
          return { isUnreasonable: true, reason: `冲击力不足 (实际: ${maxJerk.toFixed(1)}, 阈值: ${(config.threshold_jerk * thresholdFactor).toFixed(1)})`, confidence: 0.7 };
        }
        // Jerk 基准门槛校验
        const peakAy = Math.max(Math.abs(maxAy), Math.abs(minAy));
        if (peakAy < (config.min_accel_for_jerk ?? 0.25)) {
            return { isUnreasonable: true, reason: `Jerk 基准加速度不足 (实际: ${peakAy.toFixed(2)}G)`, confidence: 0.8 };
        }
        break;
      case 'wobble':
        if (spanAx < config.threshold_wobble_span * thresholdFactor) {
          return { isUnreasonable: true, reason: `横向摆动不足 (实际: ${spanAx.toFixed(2)}, 阈值: ${(config.threshold_wobble_span * thresholdFactor).toFixed(2)})`, confidence: 0.8 };
        }
        // 航向切换检测
        let yawSwitches = 0;
        for (let j = 1; j < gzList.length; j++) {
            if (Math.sign(gzList[j]) !== Math.sign(gzList[j-1]) && Math.abs(gzList[j]) > 0.05) {
                yawSwitches++;
            }
        }
        if (yawSwitches < 1) {
            return { isUnreasonable: true, reason: '横向摆动缺乏航向切换特征', confidence: 0.7 };
        }
        break;
      case 'bump':
        if (maxAz < config.threshold_bump) {
          return { isUnreasonable: true, reason: `垂直冲击不足 (实际: ${maxAz.toFixed(2)}, 阈值: ${config.threshold_bump})`, confidence: 0.8 };
        }
        break;
    }

    return { isUnreasonable: false, confidence: 0.9 };
  }

  /**
   * 扫描可能漏掉的事件 (特征强度优先版)
   */
  static async scanForMissingEvents(fullData: any): Promise<SupplementalEvent[]> {
    const config = await ConfigService.getLatestConfig();
    const supplemental: SupplementalEvent[] = [];
    const existingEvents = fullData.events || [];
    const trajectory = fullData.trajectory || [];
    
    const getSpeedAt = (ts: number): number => {
      if (trajectory.length === 0) return 10;
      let closest = trajectory[0];
      for (const p of trajectory) {
        if (Math.abs(p.ts - ts) < Math.abs(closest.ts - ts)) closest = p;
        if (p.ts > ts + 1) break;
      }
      return closest.speed || 0;
    };

    const fullSensorLog = fullData.sensor_logs || fullData.full_sensor_data;
    if (!fullSensorLog || !Array.isArray(fullSensorLog) || fullSensorLog.length < 20) {
      return this.scanGpsOnly(fullData, config);
    }

    // 1. 计算频率和窗口
    const dtAvg = (fullSensorLog[10].offset_ms - fullSensorLog[0].offset_ms) / 10.0 / 1000.0;
    const fs = dtAvg > 0 ? 1.0 / dtAvg : 30.0;
    const startTimeTs = fullData.metadata?.start_time ? (new Date(fullData.metadata.start_time).getTime() / 1000) : 0;

    const rawDetections: SupplementalEvent[] = [];

    // 2. 遍历扫描所有特征点
    for (let i = 0; i < fullSensorLog.length - 20; i += 3) {
      const timestamp = startTimeTs + (fullSensorLog[i].offset_ms / 1000);
      
      // 车速熔断 (安卓最新: 3.0 km/h)
      const currentSpeed = getSpeedAt(timestamp);
      if (currentSpeed * 3.6 < 3.0) continue;
      
      // 冲突过滤：手机端已经有的地方不再建议
      if (existingEvents.some((e: any) => Math.abs(e.timestamp - timestamp) < 1.5)) continue;

      const windowSize = Math.round(fs * 0.8);
      const window = fullSensorLog.slice(i, i + windowSize); 
      const ay = window.map((d: any) => (Array.isArray(d.accel) ? d.accel[1] : (d.accel?.y ?? d.ay ?? 0)));
      const ax = window.map((d: any) => (Array.isArray(d.accel) ? d.accel[0] : (d.accel?.x ?? d.ax ?? 0)));
      const az = window.map((d: any) => (Array.isArray(d.accel) ? d.accel[2] : (d.accel?.z ?? d.az ?? 0)));
      const gx = window.map((d: any) => (Array.isArray(d.gyro) ? d.gyro[0] : (d.gyro?.x ?? d.gx ?? 0)));
      const gz = window.map((d: any) => (Array.isArray(d.gyro) ? d.gyro[2] : (d.gyro?.z ?? d.gz ?? 0)));

      const maxAz = Math.max(...az.map(Math.abs));
      const maxGx = Math.max(...gx.map(Math.abs));

      // 适配因子和抑制
      let factor = 1.0;
      if (currentSpeed * 3.6 < 10) factor = config.speed_low_factor;
      else if (currentSpeed * 3.6 > 80) factor = config.speed_high_factor;

      let suppression = 1.0;
      if (maxAz > config.zy_interference_threshold) {
        suppression = 1.0 + Math.pow(maxAz - config.zy_interference_threshold, 1.2) * 0.5;
        suppression = Math.min(suppression, 3.5);
      }

      const thresholdFactor = factor * suppression;

      // --- 计算各项特征得分 (实际 / 阈值) ---
      
      // A1. 急减速
      const minAy = Math.min(...ay);
      const brakeScore = Math.abs(minAy / (config.threshold_decel * thresholdFactor));
      if (brakeScore >= 1.0 && Math.abs(minAy) < config.max_accel_allowed) {
        // 俯仰角可选验证
        if (!config.pitch_validation_enabled || maxGx > (config.threshold_pitch / 10.0)) {
            rawDetections.push({
                timestamp, type: 'rapidDeceleration', accel: minAy, score: brakeScore, confidence: 0.9,
                reason: `回溯：强减速特征 (${minAy.toFixed(2)}G)`,
                sensor_fragment: { data: window }
            });
        }
      }

      // A2. 顿挫
      let maxJerk = 0;
      for (let j = 1; j < window.length; j++) {
        const dt = (window[j].offset_ms - window[j-1].offset_ms) / 1000.0;
        const jVal = Math.abs((ay[j] - ay[j-1]) / (dt || 0.03));
        if (jVal > maxJerk) maxJerk = jVal;
      }
      const jerkScore = maxJerk / (config.threshold_jerk * thresholdFactor);
      const peakAy = Math.max(Math.abs(Math.max(...ay)), Math.abs(minAy));
      
      if (jerkScore >= 1.0 && maxJerk < config.max_jerk_allowed && peakAy > (config.min_accel_for_jerk ?? 0.25)) {
        rawDetections.push({
          timestamp, type: 'jerk', accel: maxJerk, score: jerkScore, confidence: 0.8,
          reason: `回溯：冲击特征 (Jerk: ${maxJerk.toFixed(1)})`,
          sensor_fragment: { data: window }
        });
      }

      // A3. 横摆
      const spanAx = Math.max(...ax) - Math.min(...ax);
      const wobbleScore = spanAx / (config.threshold_wobble_span * thresholdFactor);
      let yawSwitches = 0;
      for (let j = 1; j < gz.length; j++) {
          if (Math.sign(gz[j]) !== Math.sign(gz[j-1]) && Math.abs(gz[j]) > 0.05) yawSwitches++;
      }

      if (wobbleScore >= 1.0 && spanAx < config.max_wobble_span_allowed && yawSwitches >= 1) {
        rawDetections.push({
          timestamp, type: 'wobble', accel: spanAx, score: wobbleScore, confidence: 0.7,
          reason: `回溯：横向摆动 (${spanAx.toFixed(2)}G)`,
          sensor_fragment: { data: window }
        });
      }

      // A4. 颠簸
      const bumpScore = maxAz / config.threshold_bump;
      if (bumpScore >= 1.0 && maxAz < config.max_bump_allowed) {
        rawDetections.push({
          timestamp, type: 'bump', accel: maxAz, score: bumpScore, confidence: 0.8,
          reason: `回溯：垂直冲击 (${maxAz.toFixed(2)}G)`,
          sensor_fragment: { data: window }
        });
      }
    }

    // 3. 聚合：在 fusion_window 内进行特征优先级排序
    if (rawDetections.length === 0) return [];
    
    const priorityMap: Record<string, number> = {
        'rapidDeceleration': 1,
        'rapidAcceleration': 1,
        'bump': 2,
        'jerk': 3,
        'wobble': 4
    };

    rawDetections.sort((a, b) => a.timestamp - b.timestamp);
    const fused: SupplementalEvent[] = [];
    let currentGroup: SupplementalEvent[] = [];

    for (const d of rawDetections) {
      if (currentGroup.length === 0) {
        currentGroup.push(d);
      } else if (d.timestamp - currentGroup[0].timestamp < (config.fusion_window_ms / 1000.0)) {
        currentGroup.push(d);
      } else {
        fused.push(currentGroup.sort((a, b) => {
            const pa = priorityMap[a.type] || 99;
            const pb = priorityMap[b.type] || 99;
            if (pa !== pb) return pa - pb;
            return (b.score || 0) - (a.score || 0);
        })[0]);
        currentGroup = [d];
      }
    }
    if (currentGroup.length > 0) {
      fused.push(currentGroup.sort((a, b) => {
          const pa = priorityMap[a.type] || 99;
          const pb = priorityMap[b.type] || 99;
          if (pa !== pb) return pa - pb;
          return (b.score || 0) - (a.score || 0);
      })[0]);
    }

    return fused;
  }

  private static scanGpsOnly(fullData: any, config: any): SupplementalEvent[] {
    const trajectory = fullData.trajectory || [];
    const existingEvents = fullData.events || [];
    const results: SupplementalEvent[] = [];
    let lastTime = 0;

    for (let i = 1; i < trajectory.length; i++) {
      const p1 = trajectory[i-1];
      const p2 = trajectory[i];
      if (p2.ts - lastTime < 5.0) continue;
      if (p2.speed * 3.6 < 5.0) continue;

      const acc = (p2.speed - p1.speed) / (p2.ts - p1.ts || 1);
      const accG = acc / 9.80665;

      if (accG < config.threshold_decel || accG > config.threshold_accel) {
        if (!existingEvents.some((e: any) => Math.abs(e.timestamp - p2.ts) < 2.0)) {
          results.push({
            timestamp: p2.ts,
            type: accG < 0 ? 'rapidDeceleration' : 'rapidAcceleration',
            reason: `GPS推算：车速骤变 (${accG.toFixed(2)}G)`,
            confidence: 0.6,
            lat: p2.lat, lng: p2.lng, speed: p2.speed, accel: accG, score: 1.0
          });
          lastTime = p2.ts;
        }
      }
    }
    return results;
  }
}
