/**
 * Puked 自动化归纳 Worker (Algorithm B & User Stats 版)
 * 功能：每 30 分钟增量扫描新行程，执行轨迹深度分析，更新排行榜及用户统计。
 * 部署：在 Node.js 18+ 环境下通过 `node scripts/auto_induction.js` 运行。
 */
import PocketBase from 'pocketbase';

// --- 基础配置 ---
const CONFIG = {
    PB_URL: 'https://pb.osglab.com', 
    ADMIN_EMAIL: 'rocky.hk@gmail.com',
    ADMIN_PASSWORD: 'gz203799',
    INTERVAL_MS: 30 * 60 * 1000, // 30 分钟
    BATCH_SIZE: 50 // 每批处理数量，防止内存溢出
};

const pb = new PocketBase(CONFIG.PB_URL);

/**
 * 哈弗辛公式：计算地球表面两点间距离 (米)
 */
function getDistance(lat1, lon1, lat2, lon2) {
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
}

/**
 * 轨迹分析 (Algorithm B)
 */
function analyzeTrajectory(jsonData) {
    const trajectory = jsonData.trajectory || [];
    const buckets = { highway: 0, smooth: 0, urban: 0, congested: 0 };
    let totalSpeedSum = 0;
    let validPoints = 0;

    if (trajectory.length < 2) return { ...buckets, avg: 0 };

    for (let i = 0; i < trajectory.length - 1; i++) {
        const p1 = trajectory[i];
        const p2 = trajectory[i + 1];
        if (!p1.lat || !p1.lng || !p2.lat || !p2.lng) continue;

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
 * 周期计算辅助
 */
function getYearWeek(d) {
    const tempDate = new Date(d.getTime());
    tempDate.setHours(0, 0, 0, 0);
    tempDate.setDate(tempDate.getDate() + 4 - (tempDate.getDay() || 7));
    const yearStart = new Date(tempDate.getFullYear(), 0, 1);
    const weekNo = Math.ceil((((tempDate.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
    return `${tempDate.getFullYear()}-W${weekNo.toString().padStart(2, '0')}`;
}

/**
 * 补全行程缺失的品牌/版本关联
 */
async function enrichTrips(trips) {
    if (trips.length === 0) return;
    try {
        const [brands, versions] = await Promise.all([
            pb.collection('brands').getFullList({ fields: 'id,name' }),
            pb.collection('software_versions').getFullList({ fields: 'id,versionString,version_name' })
        ]);

        const brandMap = new Map(brands.map(b => [b.name.toLowerCase(), b.id]));
        const versionMap = new Map();
        versions.forEach(v => {
            if (v.versionString) versionMap.set(v.versionString.toLowerCase(), v.id);
            if (v.version_name) versionMap.set(v.version_name.toLowerCase(), v.id);
        });

        for (const trip of trips) {
            const updateData = {};
            if (!trip.brand_ref && trip.brand) {
                const matchedId = brandMap.get(trip.brand.toLowerCase());
                if (matchedId) updateData.brand_ref = matchedId;
            }
            if (!trip.software_version_ref && (trip.software_version || trip.version)) {
                const vStr = (trip.software_version || trip.version).toLowerCase();
                const matchedId = versionMap.get(vStr);
                if (matchedId) updateData.software_version_ref = matchedId;
            }
            if (Object.keys(updateData).length > 0) {
                await pb.collection('trips').update(trip.id, updateData);
            }
        }
    } catch (e) {
        console.error("❌ Enrichment failed:", e.message);
    }
}

/**
 * 全量用户统计归纳
 */
async function aggregateAllUserStats() {
    console.log("📊 正在刷新全量用户统计与排行榜...");
    try {
        const allTrips = await pb.collection('trips').getFullList({ filter: 'is_public = true' });
        const userAggregates = new Map();
        
        allTrips.forEach(trip => {
            const userId = trip.user || trip.owner;
            if (!userId) return;

            if (!userAggregates.has(userId)) {
                userAggregates.set(userId, { userId, totalMileage: 0, totalEvents: 0, brandDistribution: {} });
            }

            const agg = userAggregates.get(userId);
            const metrics = typeof trip.metrics === 'string' ? JSON.parse(trip.metrics || '{}') : (trip.metrics || {});
            const dist = parseFloat(metrics.distance_km || metrics.distance || 0);
            const events = parseInt(metrics.event_count || 0);

            agg.totalMileage += dist;
            agg.totalEvents += events;
            const brandName = trip.brand || 'Others';
            agg.brandDistribution[brandName] = (agg.brandDistribution[brandName] || 0) + dist;
        });

        const sortedUsers = Array.from(userAggregates.values()).map(u => ({
            ...u,
            pukedValue: u.totalEvents > 0 ? u.totalMileage / u.totalEvents : u.totalMileage
        })).sort((a, b) => b.pukedValue - a.pukedValue);

        const globalTotalMileage = Array.from(userAggregates.values()).reduce((acc, u) => acc + u.totalMileage, 0);

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
                totalUsers: sortedUsers.length,
                updated_at: new Date().toISOString()
            };

            const existing = await pb.collection('user_stats').getFirstListItem(`user_id = "${u.userId}"`).catch(() => null);
            if (existing) {
                await pb.collection('user_stats').update(existing.id, { payload });
            } else {
                await pb.collection('user_stats').create({ user_id: u.userId, payload });
            }
        }
    } catch (e) {
        console.error("❌ Global user aggregation failed:", e.message);
    }
}

/**
 * 主归纳逻辑
 */
async function performInduction() {
    console.log(`\n🚀 [${new Date().toLocaleString()}] 启动增量归纳...`);
    
    try {
        await pb.admins.authWithPassword(CONFIG.ADMIN_EMAIL, CONFIG.ADMIN_PASSWORD);
        
        let lastTimestamp = "2000-01-01 00:00:00";
        const stateRecord = await pb.collection('stats_state').getFirstListItem('key="current"').catch(() => null);
        if (stateRecord) lastTimestamp = stateRecord.last_timestamp;

        const resultList = await pb.collection('trips').getList(1, CONFIG.BATCH_SIZE, {
            filter: `is_public = true && created > "${lastTimestamp}"`,
            sort: 'created'
        });

        if (resultList.items.length === 0) {
            console.log("✅ 无新行程，系统已同步。");
            return;
        }

        console.log(`📦 正在处理 ${resultList.items.length} 条新行程...`);
        await enrichTrips(resultList.items);

        const incrementalSummaryMap = new Map();
        let latestProcessedTime = lastTimestamp;

        for (const trip of resultList.items) {
            // 记录处理时间，无论是否跳过，防止重复拉取
            latestProcessedTime = trip.created;

            const userId = trip.user || trip.owner;
            const brandId = trip.brand_ref;
            const versionId = trip.software_version_ref;

            if (!userId || !brandId || !versionId) {
                console.log(`⚠️ 跳过行程 ${trip.id}: 缺少关键关联 (User/Brand/Version)`);
                continue;
            }

            let analysis = { highway: 0, smooth: 0, urban: 0, congested: 0, avg: 0 };
            const dataFile = trip.raw_log_file || trip.data_file;
            if (dataFile) {
                try {
                    const fileUrl = pb.files.getURL(trip, dataFile);
                    const response = await fetch(fileUrl);
                    const jsonData = await response.json();
                    analysis = analyzeTrajectory(jsonData);
                } catch (e) {
                    console.warn(`⚠️ 轨迹分析失败 ${trip.id}: ${e.message}`);
                    const metrics = typeof trip.metrics === 'string' ? JSON.parse(trip.metrics || '{}') : (trip.metrics || {});
                    const avg = parseFloat(metrics.avg_speed_kmh || 0);
                    const dist = parseFloat(metrics.distance_km || 0);
                    if (avg >= 80) analysis.highway = dist;
                    else if (avg >= 50) analysis.smooth = dist;
                    else if (avg >= 20) analysis.urban = dist;
                    else analysis.congested = dist;
                    analysis.avg = avg;
                }
            }

            const metrics = typeof trip.metrics === 'string' ? JSON.parse(trip.metrics || '{}') : (trip.metrics || {});
            const dist = parseFloat(metrics.distance_km || 0);
            
            // 方案 2：排除 Bump 事件数
            const original_events = parseInt(metrics.event_count || 0);
            const eb = metrics.event_breakdown || {};
            const bumps = parseInt(eb.bump || 0);
            const events = Math.max(0, original_events - bumps);

            const scenario = analysis.avg >= 50 ? 'highway' : 'city';

            const date = new Date(trip.created.replace(' ', 'T'));
            const monthStr = trip.created.slice(0, 7);
            const weekStr = getYearWeek(date);

            [{ type: 'all', value: 'total' }, { type: 'monthly', value: monthStr }, { type: 'weekly', value: weekStr }].forEach(p => {
                const key = `${userId}_${brandId}_${versionId}_${scenario}_${p.type}_${p.value}`;
                if (!incrementalSummaryMap.has(key)) {
                    incrementalSummaryMap.set(key, {
                        dist: 0, events: 0, count: 0,
                        event_breakdown: {}, 
                        speed_dist: { highway: 0, smooth: 0, urban: 0, congested: 0, avg: 0 }, 
                        meta: { userId, brandId, versionId, scenario, p }
                    });
                }
                const s = incrementalSummaryMap.get(key);
                s.dist += dist;
                s.events += events;
                s.count += 1;
                s.speed_dist.highway += analysis.highway;
                s.speed_dist.smooth += analysis.smooth;
                s.speed_dist.urban += analysis.urban;
                s.speed_dist.congested += analysis.congested;
                s.speed_dist.avg = parseFloat((( (s.speed_dist.avg * (s.count - 1)) + analysis.avg ) / s.count).toFixed(2));
                
                if (metrics.event_breakdown) {
                    Object.entries(metrics.event_breakdown).forEach(([k, v]) => {
                        s.event_breakdown[k] = (s.event_breakdown[k] || 0) + (v || 0);
                    });
                }
            });

            latestProcessedTime = trip.created;
        }

        for (const [key, change] of incrementalSummaryMap) {
            const existing = await pb.collection('trip_stats_summary').getFirstListItem(`key="${key}"`).catch(() => null);
            if (existing) {
                const totalCount = (existing.trip_count || 0) + change.count;
                const newAvg = parseFloat((( (existing.speed_dist?.avg || 0) * (existing.trip_count || 0)) + (change.speed_dist.avg * change.count) ) / totalCount).toFixed(2);
                
                await pb.collection('trip_stats_summary').update(existing.id, {
                    total_distance: (existing.total_distance || 0) + change.dist,
                    total_events: (existing.total_events || 0) + change.events,
                    trip_count: totalCount,
                    speed_dist: {
                        highway: (existing.speed_dist?.highway || 0) + change.speed_dist.highway,
                        smooth: (existing.speed_dist?.smooth || 0) + change.speed_dist.smooth,
                        urban: (existing.speed_dist?.urban || 0) + change.speed_dist.urban,
                        congested: (existing.speed_dist?.congested || 0) + change.speed_dist.congested,
                        avg: newAvg
                    },
                    event_breakdown: Object.fromEntries(
                        Object.keys({ ...existing.event_breakdown, ...change.event_breakdown }).map(k => [
                            k, (existing.event_breakdown?.[k] || 0) + (change.event_breakdown[k] || 0)
                        ])
                    )
                });
            } else {
                await pb.collection('trip_stats_summary').create({
                    key, user: change.meta.userId, brand: change.meta.brandId, software_version: change.meta.versionId,
                    scenario: change.meta.scenario, period_type: change.meta.p.type, period_value: change.meta.p.value,
                    total_distance: change.dist, total_events: change.events, trip_count: change.count,
                    speed_dist: change.speed_dist, event_breakdown: change.event_breakdown
                });
            }
        }

        const newState = { key: 'current', last_timestamp: latestProcessedTime };
        if (stateRecord) await pb.collection('stats_state').update(stateRecord.id, newState);
        else await pb.collection('stats_state').create(newState);

        console.log(`✨ 归纳成功！水位线更新至: ${latestProcessedTime}`);
        await aggregateAllUserStats();
        
    } catch (e) {
        console.error("❌ 归纳任务失败:", e.message);
    }
}

/**
 * 启动 Worker
 */
async function startWorker() {
    console.log("🛠 Puked Auto-Induction Worker 已启动");
    while (true) {
        await performInduction();
        
        // 动态读取扫描周期
        let currentIntervalMs = CONFIG.INTERVAL_MS;
        try {
            const stateRecord = await pb.collection('stats_state').getFirstListItem('key="current"').catch(() => null);
            if (stateRecord && stateRecord.sync_interval) {
                currentIntervalMs = stateRecord.sync_interval * 60 * 1000;
                console.log(`⏱ 当前扫描周期已同步: ${stateRecord.sync_interval} 分钟`);
            }
        } catch (e) {}

        console.log(`😴 等待 ${currentIntervalMs / 60000} 分钟后进行下一次扫描...`);
        await new Promise(resolve => setTimeout(resolve, currentIntervalMs));
    }
}

startWorker();
