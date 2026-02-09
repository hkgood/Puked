/**
 * 算法 B 审计引擎 (Web 适配版)
 * 用于对历史行程数据进行合理性扫描
 */

export interface AuditResult {
  isUnreasonable: boolean;
  reason?: string;
}

export class AlgorithmBAuditor {
  /**
   * 审计单个事件
   * @param event 行程中的事件对象
   * @param tripStartTime 行程开始时间
   * @returns 审计结果
   */
  static auditEvent(event: any, tripStartTime: string): AuditResult {
    const eventTime = event.timestamp;
    const tripStart = new Date(tripStartTime).getTime() / 1000;
    
    // 1. 校验启动保护期 (5秒)
    if (eventTime - tripStart < 5) {
      return { isUnreasonable: true, reason: '启动保护期内触发' };
    }

    const sensorData = event.sensor_fragment?.data || [];
    if (sensorData.length === 0) {
      return { isUnreasonable: true, reason: '无传感器数据' };
    }

    // 3. 校验物理阈值合理性 (基于第一性原理常数)
    let maxAbsX = 0;
    let maxAbsY = 0;
    let maxAbsZ = 0;

    for (let i = 0; i < sensorData.length; i++) {
      const d = sensorData[i];
      const accel = d.accel || d;
      let ax = 0, ay = 0, az = 0;
      
      if (Array.isArray(accel)) {
        ax = Math.abs(accel[0] || 0);
        ay = Math.abs(accel[1] || 0);
        az = Math.abs(accel[2] || 0);
      } else {
        ax = Math.abs(accel.x || accel.ax || 0);
        ay = Math.abs(accel.y || accel.ay || 0);
        az = Math.abs(accel.z || accel.az || 0);
      }
      
      if (ax > maxAbsX) maxAbsX = ax;
      if (ay > maxAbsY) maxAbsY = ay;
      if (az > maxAbsZ) maxAbsZ = az;
    }

    // 4. 事件合理性判定
    if (event.type === 'rapidAcceleration') {
      if (maxAbsY < 2.3) return { isUnreasonable: true, reason: `加速度不足 (实际: ${maxAbsY.toFixed(2)}, 阈值: 2.3)` };
    }

    if (event.type === 'rapidDeceleration') {
      if (maxAbsY < 2.4) return { isUnreasonable: true, reason: `减速度不足 (实际: ${maxAbsY.toFixed(2)}, 阈值: 2.4)` };
    }

    if (event.type === 'bump') {
      if (maxAbsZ < 3.8) return { isUnreasonable: true, reason: `颠簸强度不足 (实际: ${maxAbsZ.toFixed(2)}, 阈值: 3.8)` };
    }

    if (event.type === 'wobble') {
      if (maxAbsX < 2.0) return { isUnreasonable: true, reason: `摆动强度不足 (实际: ${maxAbsX.toFixed(2)}, 阈值: 2.0)` };
    }

    // 5. 轴间耦合压制 (防止过坑误判为加减速)
    if (event.type === 'rapidAcceleration' || event.type === 'rapidDeceleration') {
      if (maxAbsZ > maxAbsY * 1.5) {
        return { isUnreasonable: true, reason: '垂直耦合干扰 (疑似过坑)' };
      }
    }

    return { isUnreasonable: false };

    return { isUnreasonable: false };
  }
}

