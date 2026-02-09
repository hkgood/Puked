/**
 * 快速统计重建脚本（跳过轨迹分析，直接使用 metrics 数据）
 * 
 * 用于快速重建统计数据，不进行轨迹深度分析
 * 适合在数据清理后快速恢复统计
 */
import PocketBase from 'pocketbase';

const CONFIG = {
    PB_URL: 'https://pb.osglab.com',
    ADMIN_EMAIL: 'rocky.hk@gmail.com',
    ADMIN_PASSWORD: 'gz203799',
    BATCH_SIZE: 500 // 增大批次大小，因为不需要下载文件
};

const pb = new PocketBase(CONFIG.PB_URL);

function getYearWeek(d) {
    const tempDate = new Date(d.getTime());
    tempDate.setHours(0, 0, 0, 0);
    tempDate.setDate(tempDate.getDate() + 4 - (tempDate.getDay() || 7));
    const yearStart = new Date(tempDate.getFullYear(), 0, 1);
    const weekNo = Math.ceil((((tempDate.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
    return `${tempDate.getFullYear()}-W${weekNo.toString().padStart(2, '0')}`;
}

async function quickRebuild() {
    console.log('╔════════════════════════════════════════════════════════════╗');
    console.log('║         Puked 快速统计重建工具                            ║');
    console.log('╚════════════════════════════════════════════════════════════╝\n');

    await pb.admins.authWithPassword(CONFIG.ADMIN_EMAIL, CONFIG.ADMIN_PASSWORD);
    console.log('✅ 已登录\n');

    // 获取所有公开行程
    console.log('📦 正在获取所有公开行程...');
    const allTrips = await pb.collection('trips').getFullList({
        filter: 'is_public = true',
        sort: 'created'
    });

    console.log(`   找到 ${allTrips.length} 条公开行程\n`);

    // 用于聚合的Map
    const summaryMap = new Map();
    let processedCount = 0;
    const startTime = Date.now();

    console.log('⏳ 开始处理行程...\n');

    for (const trip of allTrips) {
        processedCount++;

        const userId = trip.user || trip.owner;
        const brandId = trip.brand_ref;
        const versionId = trip.software_version_ref;

        if (!userId || !brandId || !versionId) {
            if (processedCount % 100 === 0) {
                console.log(`   进度: ${processedCount}/${allTrips.length} (${(processedCount / allTrips.length * 100).toFixed(1)}%)`);
            }
            continue;
        }

        // 解析 metrics
        const metrics = typeof trip.metrics === 'string'
            ? JSON.parse(trip.metrics || '{}')
            : (trip.metrics || {});

        const dist = parseFloat(metrics.distance_km || 0);
        const avgSpeed = parseFloat(metrics.avg_speed_kmh || 0);

        // 排除 bump 事件
        const original_events = parseInt(metrics.event_count || 0);
        const eb = metrics.event_breakdown || {};
        const bumps = parseInt(eb.bump || 0);
        const events = Math.max(0, original_events - bumps);

        // 根据平均速度判断场景
        const scenario = avgSpeed >= 50 ? 'highway' : 'city';

        // 时间周期
        const date = new Date(trip.created.replace(' ', 'T'));
        const monthStr = trip.created.slice(0, 7);
        const weekStr = getYearWeek(date);

        // 速度分布（简化版）
        const speed_dist = metrics.speed_dist || {};
        if (Object.keys(speed_dist).length === 0) {
            // 如果没有速度分布，根据平均速度估算
            if (avgSpeed >= 80) speed_dist.highway = dist;
            else if (avgSpeed >= 50) speed_dist.smooth = dist;
            else if (avgSpeed >= 20) speed_dist.urban = dist;
            else speed_dist.congested = dist;
        }

        // 为三个周期类型生成统计
        [
            { type: 'all', value: 'total' },
            { type: 'monthly', value: monthStr },
            { type: 'weekly', value: weekStr }
        ].forEach(p => {
            const key = `${userId}_${brandId}_${versionId}_${scenario}_${p.type}_${p.value}`;

            if (!summaryMap.has(key)) {
                summaryMap.set(key, {
                    key,
                    user: userId,
                    brand: brandId,
                    software_version: versionId,
                    scenario,
                    period_type: p.type,
                    period_value: p.value,
                    total_distance: 0,
                    total_events: 0,
                    trip_count: 0,
                    speed_dist: { highway: 0, smooth: 0, urban: 0, congested: 0 },
                    event_breakdown: {}
                });
            }

            const summary = summaryMap.get(key);
            summary.total_distance += dist;
            summary.total_events += events;
            summary.trip_count += 1;

            // 累加速度分布
            Object.keys(speed_dist).forEach(k => {
                summary.speed_dist[k] = (summary.speed_dist[k] || 0) + (speed_dist[k] || 0);
            });

            // 累加事件分布
            Object.entries(eb).forEach(([k, v]) => {
                summary.event_breakdown[k] = (summary.event_breakdown[k] || 0) + (v || 0);
            });
        });

        // 每处理100条显示进度
        if (processedCount % 100 === 0) {
            const elapsed = (Date.now() - startTime) / 1000;
            const rate = processedCount / elapsed;
            const remaining = ((allTrips.length - processedCount) / rate / 60).toFixed(1);
            console.log(`   进度: ${processedCount}/${allTrips.length} (${(processedCount / allTrips.length * 100).toFixed(1)}%) - 速度: ${rate.toFixed(1)}条/秒 - 预计剩余: ${remaining}分钟`);
        }
    }

    console.log(`\n✅ 行程处理完成！共处理 ${processedCount} 条\n`);
    console.log(`📊 生成了 ${summaryMap.size} 条统计记录\n`);
    console.log('💾 正在保存到数据库...\n');

    // 批量创建统计记录
    let savedCount = 0;
    const totalRecords = summaryMap.size;

    for (const summary of summaryMap.values()) {
        try {
            await pb.collection('trip_stats_summary').create(summary);
            savedCount++;

            if (savedCount % 50 === 0) {
                console.log(`   保存进度: ${savedCount}/${totalRecords} (${(savedCount / totalRecords * 100).toFixed(1)}%)`);
            }
        } catch (e) {
            console.error(`   ❌ 保存失败: ${summary.key} - ${e.message}`);
        }
    }

    console.log(`\n✅ 统计记录保存完成！成功 ${savedCount} 条\n`);

    // 更新水位线
    const lastTrip = allTrips[allTrips.length - 1];
    const stateRecord = await pb.collection('stats_state').getFirstListItem('key="current"');
    await pb.collection('stats_state').update(stateRecord.id, {
        last_timestamp: lastTrip.created
    });

    console.log(`📍 水位线已更新到: ${lastTrip.created}\n`);

    // 重建用户统计
    console.log('👥 正在重建用户统计...\n');
    const userAggregates = new Map();

    allTrips.forEach(trip => {
        const userId = trip.user || trip.owner;
        if (!userId) return;

        if (!userAggregates.has(userId)) {
            userAggregates.set(userId, { userId, totalMileage: 0, totalEvents: 0, brandDistribution: {} });
        }

        const agg = userAggregates.get(userId);
        const metrics = typeof trip.metrics === 'string' ? JSON.parse(trip.metrics || '{}') : (trip.metrics || {});
        const dist = parseFloat(metrics.distance_km || 0);
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

        await pb.collection('user_stats').create({ user_id: u.userId, payload });
    }

    console.log(`✅ 用户统计重建完成！共 ${sortedUsers.length} 个用户\n`);

    const totalTime = ((Date.now() - startTime) / 1000 / 60).toFixed(1);

    console.log('╔════════════════════════════════════════════════════════════╗');
    console.log('║              🎉 统计重建完成！                            ║');
    console.log('╚════════════════════════════════════════════════════════════╝\n');
    console.log(`   总耗时: ${totalTime} 分钟`);
    console.log(`   行程数: ${allTrips.length}`);
    console.log(`   统计记录: ${savedCount}`);
    console.log(`   用户数: ${sortedUsers.length}\n`);
}

quickRebuild().catch(e => {
    console.error('❌ 重建失败:', e.message);
    process.exit(1);
});
