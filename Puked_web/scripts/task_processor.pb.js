/**
 * 🔄 Puked 批量同步任务处理器
 * 
 * 功能：后台处理统计任务，分批处理数据，实时更新进度
 * 架构：任务队列 + Worker轮询 + 进度反馈
 * 
 * 运行方式：
 *   node task_processor.pb.js
 * 
 * 部署方式：
 *   使用 pm2 或 systemd 守护进程
 *   pm2 start task_processor.pb.js --name "puked-task-processor"
 */

import PocketBase from 'pocketbase';

// ==================== 配置区 ====================
const PB_URL = process.env.PB_URL || 'https://pb.osglab.com';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'rocky.hk@gmail.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'gz203799';

// 性能配置
const BATCH_SIZE = parseInt(process.env.BATCH_SIZE) || 10;              // 每批处理10个行程
const CHECK_INTERVAL = parseInt(process.env.CHECK_INTERVAL) || 60000;   // 60秒检查一次任务队列（默认1分钟）
const HEARTBEAT_INTERVAL = parseInt(process.env.HEARTBEAT_INTERVAL) || 300000; // 300秒更新一次心跳（默认5分钟）
const BATCH_DELAY = 100;            // 批次之间延迟100ms，避免数据库压力
const CONCURRENCY = parseInt(process.env.CONCURRENCY) || 3;              // 并发处理3个行程（下载JSON文件）

// 启动阶段重试：云端环境可能短暂不可达，避免一次失败就退出
const STARTUP_AUTH_RETRIES = parseInt(process.env.STARTUP_AUTH_RETRIES) || 3;
const STARTUP_AUTH_RETRY_DELAY_MS = parseInt(process.env.STARTUP_AUTH_RETRY_DELAY_MS) || 5000;

// ==================== 全局变量 ====================
const pb = new PocketBase(PB_URL);

/** 带延迟的重试执行 async 函数，失败时抛出最后一次错误 */
async function retryAsync(fn, retries = STARTUP_AUTH_RETRIES, delayMs = STARTUP_AUTH_RETRY_DELAY_MS) {
  let lastErr;
  for (let i = 0; i < retries; i++) {
    try {
      return await fn();
    } catch (e) {
      lastErr = e;
      if (i < retries - 1) {
        console.warn(`[TaskProcessor] 第 ${i + 1}/${retries} 次尝试失败: ${e.message}，${delayMs / 1000} 秒后重试...`);
        await new Promise(r => setTimeout(r, delayMs));
      }
    }
  }
  throw lastErr;
}
let isProcessing = false;           // 防止并发执行

// ==================== 工具函数 ====================

/**
 * 计算 ISO 周数
 */
function getYearWeek(dateStr) {
  const d = new Date(dateStr.replace(' ', 'T'));
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + 4 - (d.getDay() || 7));
  const yearStart = new Date(d.getFullYear(), 0, 1);
  const weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  return `${d.getFullYear()}-W${weekNo.toString().padStart(2, '0')}`;
}

/**
 * 分析轨迹数据，计算速度分布
 */
function analyzeTrajectory(jsonData) {
  const trajectory = jsonData.trajectory || [];
  const buckets = { highway: 0, smooth: 0, urban: 0, congested: 0 };
  let totalSpeedSum = 0;
  let validPoints = 0;

  if (trajectory.length < 2) return { ...buckets, avg: 0 };

  const getDistance = (lat1, lon1, lat2, lon2) => {
    const R = 6371e3;
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
      Math.cos(φ1) * Math.cos(φ2) *
      Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  };

  for (let i = 0; i < trajectory.length - 1; i++) {
    const p1 = trajectory[i];
    const p2 = trajectory[i + 1];
    const dist = getDistance(p1.lat, p1.lng, p2.lat, p2.lng) / 1000;
    const speedKmh = (p1.speed || 0) * 3.6;

    if (dist > 0 && dist < 1) {
      if (speedKmh >= 80) buckets.highway += dist;
      else if (speedKmh >= 50) buckets.smooth += dist;
      else if (speedKmh >= 20) buckets.urban += dist;
      else buckets.congested += dist;

      totalSpeedSum += speedKmh;
      validPoints++;
    }
  }

  return {
    highway: parseFloat(buckets.highway.toFixed(3)),
    smooth: parseFloat(buckets.smooth.toFixed(3)),
    urban: parseFloat(buckets.urban.toFixed(3)),
    congested: parseFloat(buckets.congested.toFixed(3)),
    avg: validPoints > 0 ? parseFloat((totalSpeedSum / validPoints).toFixed(2)) : 0
  };
}

/**
 * 记录任务日志
 */
async function appendTaskLog(taskId, message, level = 'info') {
  try {
    const task = await pb.collection('sync_tasks').getOne(taskId);
    const logs = task.detail_log || [];
    logs.push({
      time: new Date().toISOString(),
      message: message,
      level: level
    });
    await pb.collection('sync_tasks').update(taskId, {
      detail_log: logs
    });
  } catch (e) {
    console.error(`[TaskProcessor] ❌ Failed to append log:`, e.message);
  }
}

/**
 * 更新任务进度
 */
async function updateTaskProgress(taskId, updates) {
  try {
    await pb.collection('sync_tasks').update(taskId, updates);
  } catch (e) {
    console.error(`[TaskProcessor] ❌ Failed to update progress:`, e.message);
  }
}

/**
 * 富集行程数据（补充 brand_ref 和 software_version_ref）
 */
async function enrichTrips(trips) {
  if (trips.length === 0) return;
  
  try {
    const [brands, versions] = await Promise.all([
      pb.collection('brands').getFullList({ fields: 'id,name', requestKey: null }),
      pb.collection('software_versions').getFullList({ 
        fields: 'id,versionString,version_name', 
        requestKey: null 
      })
    ]);

    const brandMap = new Map(brands.map(b => [b.name.toLowerCase(), b.id]));
    const versionMap = new Map();
    versions.forEach(v => {
      if (v.versionString) versionMap.set(v.versionString.toLowerCase(), v.id);
      if (v.version_name) versionMap.set(v.version_name.toLowerCase(), v.id);
    });

    for (const trip of trips) {
      let needsUpdate = false;
      const updateData = {};
      
      if (!trip.brand_ref && trip.brand) {
        const matchedId = brandMap.get(trip.brand.toLowerCase());
        if (matchedId) {
          updateData.brand_ref = matchedId;
          needsUpdate = true;
        }
      }
      
      if (!trip.software_version_ref && (trip.software_version || trip.version)) {
        const vStr = (trip.software_version || trip.version).toLowerCase();
        const matchedId = versionMap.get(vStr);
        if (matchedId) {
          updateData.software_version_ref = matchedId;
          needsUpdate = true;
        }
      }
      
      if (needsUpdate) {
        await pb.collection('trips').update(trip.id, updateData, { requestKey: null });
      }
    }
  } catch (e) {
    console.warn('[TaskProcessor] ⚠️ Enrich trips failed:', e.message);
  }
}

/**
 * 处理单个批次的行程
 */
async function processBatch(trips, taskId) {
  const incrementalSummaryMap = new Map();

  // 并发处理当前批次的行程
  const processTrip = async (trip) => {
    const userId = trip.user || trip.owner;
    const brandId = trip.brand_ref;
    const versionId = trip.software_version_ref;

    if (!userId || !brandId || !versionId) {
      return; // 跳过不完整的行程
    }

    let analysis = { highway: 0, smooth: 0, urban: 0, congested: 0, avg: 0 };
    const dataFile = trip.raw_log_file || trip.data_file;

    // 尝试下载并分析轨迹数据
    if (dataFile) {
      try {
        const fileUrl = pb.files.getURL(trip, dataFile);
        const response = await fetch(fileUrl, { timeout: 10000 });
        const jsonData = await response.json();
        analysis = analyzeTrajectory(jsonData);
      } catch (e) {
        // 如果下载失败，回退到使用 metrics 中的数据
        const metrics = typeof trip.metrics === 'string' 
          ? JSON.parse(trip.metrics || '{}') 
          : (trip.metrics || {});
        const avg = parseFloat(metrics.avg_speed_kmh || 0);
        const dist = parseFloat(metrics.distance_km || 0);
        
        if (avg >= 80) analysis.highway = dist;
        else if (avg >= 50) analysis.smooth = dist;
        else if (avg >= 20) analysis.urban = dist;
        else analysis.congested = dist;
        analysis.avg = avg;
      }
    }

    const metrics = typeof trip.metrics === 'string' 
      ? JSON.parse(trip.metrics || '{}') 
      : (trip.metrics || {});
    const dist = parseFloat(metrics.distance_km || 0);
    const eb = metrics.event_breakdown || {};
    const original_events = parseInt(metrics.event_count || 0);
    const bumps = parseInt(eb.bump || 0);
    const events = Math.max(0, original_events - bumps);
    const scenario = analysis.avg >= 50 ? 'highway' : 'city';

    const date = new Date(trip.created.replace(' ', 'T'));
    const monthStr = trip.created.slice(0, 7);
    const weekStr = getYearWeek(trip.created);

    const periods = [
      { type: 'all', value: 'total' },
      { type: 'monthly', value: monthStr },
      { type: 'weekly', value: weekStr }
    ];

    periods.forEach(p => {
      const key = `${userId}_${brandId}_${versionId}_${scenario}_${p.type}_${p.value}`;
      if (!incrementalSummaryMap.has(key)) {
        incrementalSummaryMap.set(key, {
          dist: 0, events: 0, count: 0,
          event_breakdown: {},
          speed_dist: { highway: 0, smooth: 0, urban: 0, congested: 0, avg: 0 },
          meta: { userId, brandId, versionId, scenario, p },
          last_trip_id: trip.id
        });
      }
      const s = incrementalSummaryMap.get(key);
      s.dist += dist;
      s.events += events;
      s.count += 1;
      s.last_trip_id = trip.id;
      s.speed_dist.highway += analysis.highway;
      s.speed_dist.smooth += analysis.smooth;
      s.speed_dist.urban += analysis.urban;
      s.speed_dist.congested += analysis.congested;
      const currentTotalSpeed = (s.speed_dist.avg || 0) * (s.count - 1);
      s.speed_dist.avg = parseFloat(((currentTotalSpeed + analysis.avg) / s.count).toFixed(2));

      if (metrics.event_breakdown) {
        Object.entries(metrics.event_breakdown).forEach(([k, v]) => {
          s.event_breakdown[k] = (s.event_breakdown[k] || 0) + (v || 0);
        });
      }
    });
  };

  // 并发处理（每次处理 CONCURRENCY 个）
  for (let i = 0; i < trips.length; i += CONCURRENCY) {
    const chunk = trips.slice(i, i + CONCURRENCY);
    await Promise.all(chunk.map(processTrip));
  }

  // 保存汇总数据到数据库
  const summaryChanges = Array.from(incrementalSummaryMap.entries());
  for (const [key, change] of summaryChanges) {
    try {
      const existing = await pb.collection('trip_stats_summary')
        .getFirstListItem(`key="${key}"`, { requestKey: null })
        .catch(() => null);

      if (existing) {
        // 更新现有记录
        const totalCount = (existing.trip_count || 0) + change.count;
        const existingAvg = existing.speed_dist?.avg || 0;
        const newAvg = parseFloat((
          ((existingAvg * (existing.trip_count || 0)) + (change.speed_dist.avg * change.count)) 
          / totalCount
        ).toFixed(2));

        const new_speed_dist = {
          highway: (existing.speed_dist?.highway || 0) + change.speed_dist.highway,
          smooth: (existing.speed_dist?.smooth || 0) + change.speed_dist.smooth,
          urban: (existing.speed_dist?.urban || 0) + change.speed_dist.urban,
          congested: (existing.speed_dist?.congested || 0) + change.speed_dist.congested,
          avg: newAvg
        };

        const new_event_breakdown = existing.event_breakdown || {};
        Object.keys(change.event_breakdown).forEach(k => {
          new_event_breakdown[k] = (new_event_breakdown[k] || 0) + (change.event_breakdown[k] || 0);
        });

        await pb.collection('trip_stats_summary').update(existing.id, {
          total_distance: (existing.total_distance || 0) + change.dist,
          total_events: (existing.total_events || 0) + change.events,
          trip_count: totalCount,
          speed_dist: new_speed_dist,
          event_breakdown: new_event_breakdown
        }, { requestKey: null });
      } else {
        // 创建新记录
        await pb.collection('trip_stats_summary').create({
          key, 
          user: change.meta.userId, 
          brand: change.meta.brandId, 
          software_version: change.meta.versionId,
          scenario: change.meta.scenario, 
          period_type: change.meta.p.type, 
          period_value: change.meta.p.value,
          total_distance: change.dist, 
          total_events: change.events, 
          trip_count: change.count,
          speed_dist: change.speed_dist, 
          event_breakdown: change.event_breakdown
        }, { requestKey: null });
      }
    } catch (e) {
      console.warn(`[TaskProcessor] ⚠️ Failed to update summary for key ${key}:`, e.message);
    }
  }

  return summaryChanges.length;
}

/**
 * 更新用户统计数据
 */
async function aggregateUserStats() {
  try {
    console.log('[TaskProcessor] 📊 开始更新用户统计...');
    
    const [users, allTrips] = await Promise.all([
      pb.collection('users').getFullList({ fields: 'id,name,username', requestKey: null }),
      pb.collection('trips').getFullList({
        filter: 'is_public = true',
        fields: 'id,user,owner,metrics,brand',
        requestKey: null
      })
    ]);

    const userAggregates = new Map();

    allTrips.forEach(trip => {
      const userId = trip.user || trip.owner;
      if (!userId) return;
      
      if (!userAggregates.has(userId)) {
        userAggregates.set(userId, { 
          userId, 
          totalMileage: 0, 
          totalEvents: 0, 
          brandDistribution: {} 
        });
      }
      
      const agg = userAggregates.get(userId);
      const metrics = typeof trip.metrics === 'string' 
        ? JSON.parse(trip.metrics || '{}') 
        : (trip.metrics || {});
      const dist = parseFloat(metrics.distance_km || metrics.distance || 0);
      const original_events = parseInt(metrics.event_count || 0);
      const eb = metrics.event_breakdown || {};
      const bumps = parseInt(eb.bump || 0);
      const events = Math.max(0, original_events - bumps);

      agg.totalMileage += dist;
      agg.totalEvents += events;
      const brandName = trip.brand || 'Others';
      agg.brandDistribution[brandName] = (agg.brandDistribution[brandName] || 0) + dist;
    });

    const sortedUsers = Array.from(userAggregates.values()).map(u => ({
      ...u,
      pukedValue: u.totalEvents > 0 ? u.totalMileage / u.totalEvents : u.totalMileage
    })).sort((a, b) => b.pukedValue - a.pukedValue);

    const totalUserCount = sortedUsers.length;
    const globalTotalMileage = Array.from(userAggregates.values())
      .reduce((acc, u) => acc + u.totalMileage, 0);

    for (let i = 0; i < sortedUsers.length; i++) {
      const u = sortedUsers[i];
      const payload = {
        totalMileage: parseFloat(u.totalMileage.toFixed(2)),
        globalTotalMileage: parseFloat(globalTotalMileage.toFixed(2)),
        totalEvents: u.totalEvents,
        brandDistribution: Object.fromEntries(
          Object.entries(u.brandDistribution).map(([k, v]) => [k, parseFloat(v.toFixed(2))])
        ),
        pukedValue: parseFloat(u.pukedValue.toFixed(2)),
        rank: i + 1,
        totalUsers: totalUserCount,
        updated_at: new Date().toISOString()
      };

      const existing = await pb.collection('user_stats')
        .getFirstListItem(`user_id = "${u.userId}"`, { requestKey: null })
        .catch(() => null);
        
      if (existing) {
        await pb.collection('user_stats').update(existing.id, { payload: payload }, { requestKey: null });
      } else {
        await pb.collection('user_stats').create({ user_id: u.userId, payload: payload }, { requestKey: null });
      }
    }
    
    console.log(`[TaskProcessor] ✅ 用户统计更新完成 (${sortedUsers.length} 个用户)`);
  } catch (e) {
    console.error('[TaskProcessor] ❌ 用户统计更新失败:', e.message);
    throw e;
  }
}

// ==================== 核心任务处理 ====================

/**
 * 处理批量同步任务
 */
async function processBatchSyncTask(taskRecord) {
  const taskId = taskRecord.id;
  const startTime = Date.now();
  
  try {
    console.log(`[TaskProcessor] 🚀 开始处理任务: ${taskId}`);
    
    // 1. 更新任务状态为 running
    await updateTaskProgress(taskId, {
      status: 'running',
      started_at: new Date().toISOString()
    });
    await appendTaskLog(taskId, '开始批量同步任务...', 'info');

    // 2. 获取上次同步时间戳
    let lastTimestamp = "2000-01-01 00:00:00";
    const stateRecord = await pb.collection('stats_state')
      .getFirstListItem('key="current"', { requestKey: null })
      .catch(() => null);
    
    if (stateRecord) {
      lastTimestamp = stateRecord.last_timestamp;
    }
    
    await appendTaskLog(taskId, `上次同步时间: ${lastTimestamp}`, 'info');

    // 3. 获取需要处理的新行程
    const allNewTrips = await pb.collection('trips').getFullList({
      filter: `is_public = true && created > "${lastTimestamp}"`,
      sort: 'created',
      requestKey: null
    });

    if (allNewTrips.length === 0) {
      await updateTaskProgress(taskId, {
        status: 'success',
        progress: 100,
        completed_at: new Date().toISOString()
      });
      await appendTaskLog(taskId, '没有新数据需要同步', 'info');
      console.log(`[TaskProcessor] ✅ 任务完成: ${taskId} (无新数据)`);
      return;
    }

    await appendTaskLog(taskId, `发现 ${allNewTrips.length} 个新行程`, 'info');
    console.log(`[TaskProcessor] 📦 处理 ${allNewTrips.length} 个新行程...`);

    // 4. 富集行程数据
    await enrichTrips(allNewTrips);
    await appendTaskLog(taskId, '行程数据富集完成', 'info');

    // 5. 计算批次
    const totalBatches = Math.ceil(allNewTrips.length / BATCH_SIZE);
    await updateTaskProgress(taskId, {
      total_batches: totalBatches,
      total_count: allNewTrips.length,
      current_batch: 0,
      processed_count: 0
    });

    let latestProcessedTime = lastTimestamp;
    let totalSummaryRecords = 0;

    // 6. 分批处理
    for (let batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
      // 🆕 检查任务是否被取消
      const currentTask = await pb.collection('sync_tasks').getOne(taskId, { requestKey: null });
      if (currentTask.status === 'cancelled') {
        console.log(`[TaskProcessor] ⚠️ 任务被用户取消，停止处理`);
        await appendTaskLog(taskId, `任务在批次 ${batchIndex + 1}/${totalBatches} 时被用户取消`, 'warning');
        return; // 退出处理
      }

      const batchStartIdx = batchIndex * BATCH_SIZE;
      const batchEndIdx = Math.min((batchIndex + 1) * BATCH_SIZE, allNewTrips.length);
      const batch = allNewTrips.slice(batchStartIdx, batchEndIdx);

      console.log(`[TaskProcessor] 🔄 处理批次 ${batchIndex + 1}/${totalBatches} (${batch.length} 个行程)...`);

      // 处理当前批次
      const summaryCount = await processBatch(batch, taskId);
      totalSummaryRecords += summaryCount;

      // 更新最新处理时间
      const lastTrip = batch[batch.length - 1];
      if (new Date(lastTrip.created) > new Date(latestProcessedTime)) {
        latestProcessedTime = lastTrip.created;
      }

      // 更新进度
      const progress = Math.floor(((batchIndex + 1) / totalBatches) * 90); // 留10%给后处理
      await updateTaskProgress(taskId, {
        current_batch: batchIndex + 1,
        processed_count: batchEndIdx,
        progress: progress,
        last_processed_time: latestProcessedTime  // 🆕 添加正在处理的数据时间
      });
      await appendTaskLog(taskId, `完成批次 ${batchIndex + 1}/${totalBatches}`, 'info');

      // 批次间延迟，避免数据库压力
      if (batchIndex < totalBatches - 1) {
        await new Promise(resolve => setTimeout(resolve, BATCH_DELAY));
      }
    }

    console.log(`[TaskProcessor] ✅ 所有批次处理完成`);
    await appendTaskLog(taskId, '开始更新同步状态...', 'info');

    // 7. 更新全局同步状态
    const newState = { key: 'current', last_timestamp: latestProcessedTime };
    if (stateRecord) {
      await pb.collection('stats_state').update(stateRecord.id, newState, { requestKey: null });
    } else {
      await pb.collection('stats_state').create(newState, { requestKey: null });
    }

    await updateTaskProgress(taskId, { progress: 95 });
    await appendTaskLog(taskId, '开始更新用户统计...', 'info');

    // 8. 更新用户统计
    await aggregateUserStats();

    const duration = Math.floor((Date.now() - startTime) / 1000);

    // 9. 完成任务
    await updateTaskProgress(taskId, {
      status: 'success',
      progress: 100,
      completed_at: new Date().toISOString(),
      result_summary: {
        new_trips_processed: allNewTrips.length,
        summary_records_updated: totalSummaryRecords,
        duration_seconds: duration
      }
    });
    await appendTaskLog(taskId, `任务完成！处理了 ${allNewTrips.length} 个行程，耗时 ${duration} 秒`, 'success');

    console.log(`[TaskProcessor] ✨ 任务完成: ${taskId} (${allNewTrips.length} trips, ${duration}s)`);

  } catch (error) {
    console.error(`[TaskProcessor] ❌ 任务失败: ${taskId}`, error);
    
    await updateTaskProgress(taskId, {
      status: 'failed',
      error_message: error.message,
      completed_at: new Date().toISOString()
    });
    await appendTaskLog(taskId, `任务失败: ${error.message}`, 'error');
  }
}

/**
 * 处理用户统计任务
 */
async function processUserStatsTask(taskRecord) {
  const taskId = taskRecord.id;
  const startTime = Date.now();
  
  try {
    console.log(`[TaskProcessor] 🚀 开始处理用户统计任务: ${taskId}`);
    
    await updateTaskProgress(taskId, {
      status: 'running',
      started_at: new Date().toISOString()
    });
    await appendTaskLog(taskId, '开始用户统计任务...', 'info');

    await aggregateUserStats();

    const duration = Math.floor((Date.now() - startTime) / 1000);

    await updateTaskProgress(taskId, {
      status: 'success',
      progress: 100,
      completed_at: new Date().toISOString(),
      result_summary: {
        duration_seconds: duration
      }
    });
    await appendTaskLog(taskId, `用户统计完成，耗时 ${duration} 秒`, 'success');

    console.log(`[TaskProcessor] ✨ 用户统计任务完成: ${taskId} (${duration}s)`);

  } catch (error) {
    console.error(`[TaskProcessor] ❌ 用户统计任务失败: ${taskId}`, error);
    
    await updateTaskProgress(taskId, {
      status: 'failed',
      error_message: error.message,
      completed_at: new Date().toISOString()
    });
    await appendTaskLog(taskId, `任务失败: ${error.message}`, 'error');
  }
}

/**
 * 任务分发器
 */
async function dispatchTask(taskRecord) {
  switch (taskRecord.task_type) {
    case 'batch_sync':
      await processBatchSyncTask(taskRecord);
      break;
    case 'user_stats':
      await processUserStatsTask(taskRecord);
      break;
    default:
      console.warn(`[TaskProcessor] ⚠️ 未知任务类型: ${taskRecord.task_type}`);
      await updateTaskProgress(taskRecord.id, {
        status: 'failed',
        error_message: `Unsupported task type: ${taskRecord.task_type}`
      });
  }
}

// ==================== 主循环 ====================

/**
 * 检查并处理待执行任务
 */
async function checkAndProcessTasks() {
  if (isProcessing) {
    console.log('[TaskProcessor] ⏳ 上一个任务仍在处理中，跳过本次检查');
    return;
  }

  try {
    isProcessing = true;

    // 🆕 验证认证状态
    if (!pb.authStore.isValid) {
      console.warn('[TaskProcessor] ⚠️ 认证状态无效，尝试重新登录...');
      await reAuthenticate();
    }

    // 查找待处理任务（按创建时间排序，先进先出）
    const pendingTasks = await pb.collection('sync_tasks').getFullList({
      filter: 'status = "pending"',
      sort: 'created',
      requestKey: null
    });

    if (pendingTasks.length === 0) {
      // console.log('[TaskProcessor] ✅ 当前无待处理任务');
      return;
    }

    console.log(`[TaskProcessor] 📋 发现 ${pendingTasks.length} 个待处理任务`);

    // 逐个处理任务（避免并发导致数据冲突）
    for (const task of pendingTasks) {
      try {
        await dispatchTask(task);
      } catch (err) {
        console.error(`[TaskProcessor] ❌ 处理任务 ${task.id} 时出错:`, err.message);
        // 继续处理下一个任务，不中断循环
      }
    }

  } catch (error) {
    console.error('[TaskProcessor] ❌ 检查任务时出错:', error.message);
    console.error(error.stack);
    // 🆕 如果是网络或认证问题，尝试重新连接
    if (error.message.includes('401') || error.message.includes('403') || error.message.includes('Unauthorized')) {
      console.warn('[TaskProcessor] 🔐 检测到认证问题，尝试重新登录...');
      try {
        await reAuthenticate();
      } catch (reAuthError) {
        console.error('[TaskProcessor] ❌ 重新认证失败:', reAuthError.message);
      }
    }
  } finally {
    isProcessing = false;
  }
}

// ==================== 启动 ====================

async function updateHeartbeat() {
  try {
    const stateRecord = await pb.collection('stats_state').getFirstListItem('key="current"', { requestKey: null }).catch(() => null);
    const data = { 
      engine_heartbeat: new Date().toISOString(),
      engine_status: isProcessing ? 'busy' : 'online'
    };
    if (stateRecord) {
      await pb.collection('stats_state').update(stateRecord.id, data, { requestKey: null });
    }
  } catch (e) {
    console.warn('[TaskProcessor] 💓 心跳更新失败:', e.message);
  }
}

async function init() {
  try {
    console.log('==========================================');
    console.log('🚀 [TaskProcessor] 引擎正在启动...');
    console.log(`📍 [TaskProcessor] 目标地址: ${PB_URL}`);
    console.log(`📋 [TaskProcessor] 任务检查间隔: ${CHECK_INTERVAL / 1000} 秒`);
    console.log(`💓 [TaskProcessor] 心跳更新间隔: ${HEARTBEAT_INTERVAL / 1000} 秒`);
    console.log(`📦 [TaskProcessor] 批次大小: ${BATCH_SIZE}`);
    console.log(`🔢 [TaskProcessor] 并发数: ${CONCURRENCY}`);
    console.log('==========================================');
    
    // 登录 PocketBase（带重试，兼容云端网络延迟或短暂不可达）
    await retryAsync(async () => {
      try {
        await pb.collection('_superusers').authWithPassword(ADMIN_EMAIL, ADMIN_PASSWORD);
        console.log('✅ [TaskProcessor] 超级用户 (Superuser) 登录成功');
        return;
      } catch (e) {
        try {
          await pb.admins.authWithPassword(ADMIN_EMAIL, ADMIN_PASSWORD);
          console.log('✅ [TaskProcessor] 管理员 (Admin) 登录成功');
          return;
        } catch (e2) {
          throw new Error(`认证失败: ${e.message || e2.message}，请检查 PB_URL 可访问性及 ADMIN_EMAIL/ADMIN_PASSWORD`);
        }
      }
    });

    // 🆕 监听 authStore 变化，确保认证状态
    pb.authStore.onChange(() => {
      console.log('[TaskProcessor] 🔐 认证状态变化，当前有效:', pb.authStore.isValid);
      if (!pb.authStore.isValid) {
        console.warn('[TaskProcessor] ⚠️ 认证失效，尝试重新登录...');
        reAuthenticate().catch(err => {
          console.error('[TaskProcessor] ❌ 重新认证失败:', err.message);
        });
      }
    });

    // 启动心跳 (立即执行一次，随后定期执行)
    await updateHeartbeat();
    setInterval(() => {
      updateHeartbeat().catch(err => {
        console.error('[TaskProcessor] ❌ 心跳更新失败:', err.message);
      });
    }, HEARTBEAT_INTERVAL);
    console.log(`💓 [TaskProcessor] 心跳间隔: ${HEARTBEAT_INTERVAL / 1000} 秒`);

    // 启动定时检查
    console.log(`🔄 [TaskProcessor] 开始监听任务队列 (每 ${CHECK_INTERVAL / 1000} 秒检查一次)`);
    
    // 立即执行一次检查
    await checkAndProcessTasks();
    
    // 🆕 使用更健壮的定时检查，避免异常导致定时器失效
    setInterval(() => {
      checkAndProcessTasks().catch(err => {
        console.error('[TaskProcessor] ❌ 任务检查循环出错:', err.message);
        console.error('[TaskProcessor] 🔄 将在下个周期继续尝试...');
      });
    }, CHECK_INTERVAL);

    console.log('✨ [TaskProcessor] 运行中...');
    console.log('💡 [TaskProcessor] 进程保持运行，等待任务队列...');

  } catch (error) {
    const msg = error && (error.message || String(error));
    // 单行输出便于云端日志聚合搜索（如 grep TASK_PROCESSOR_STARTUP_FAILED）
    console.error('TASK_PROCESSOR_STARTUP_FAILED:', msg);
    console.error('❌ [TaskProcessor] 启动阶段致命错误:', error.message);
    if (error && error.stack) console.error(error.stack);
    process.exit(1);
  }
}

// 🆕 重新认证函数
async function reAuthenticate() {
  try {
    await pb.collection('_superusers').authWithPassword(ADMIN_EMAIL, ADMIN_PASSWORD);
    console.log('✅ [TaskProcessor] 重新认证成功 (Superuser)');
  } catch (e) {
    await pb.admins.authWithPassword(ADMIN_EMAIL, ADMIN_PASSWORD);
    console.log('✅ [TaskProcessor] 重新认证成功 (Admin)');
  }
}

// ==================== 全局错误保护 ====================

// 捕获未处理的 Promise rejection，防止进程退出
process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ [TaskProcessor] 未处理的 Promise 异常:', reason);
  console.error('Promise:', promise);
  // 不退出进程，继续运行
});

// 捕获未捕获的异常
process.on('uncaughtException', (error) => {
  console.error('❌ [TaskProcessor] 未捕获的异常:', error);
  // 不退出进程，继续运行（但这通常不是最佳实践，应该修复代码）
});

// 优雅关闭
process.on('SIGINT', () => {
  console.log('\n👋 [TaskProcessor] 收到停止信号 (SIGINT)，正在关闭...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n👋 [TaskProcessor] 收到停止信号 (SIGTERM)，正在关闭...');
  process.exit(0);
});

// 启动程序
init().catch(err => {
  const msg = err && (err.message || String(err));
  console.error('TASK_PROCESSOR_STARTUP_FAILED:', msg);
  console.error('❌ [TaskProcessor] 初始化失败:', err);
  if (err && err.stack) console.error(err.stack);
  process.exit(1);
});
