/**
 * Puked Arena 统计同步脚本 (Node.js 版)
 */
import PocketBase from 'pocketbase';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

// --- 配置区 ---
const PB_URL = 'https://pb.osglab.com';
const ADMIN_EMAIL = 'rocky.hk@gmail.com'; 
const ADMIN_PASSWORD = 'gz203799'; 

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// 确保这个路径在你的 Web App 容器中是对应到 public 目录的
const OUTPUT_PATH = path.join(__dirname, '../public/arena_stats.json');

/**
 * 计算 ISO 周数
 */
function getYearWeek(dateStr) {
    const d = new Date(dateStr);
    d.setHours(0, 0, 0, 0);
    d.setDate(d.getDate() + 4 - (d.getDay() || 7));
    const yearStart = new Date(d.getFullYear(), 0, 1);
    const weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    return `${d.getFullYear()}-W${weekNo.toString().padStart(2, '0')}`;
}

async function run() {
    const pb = new PocketBase(PB_URL);
    
    try {
        console.log('🚀 正在登录 pb.osglab.com ...');
        await pb.admins.authWithPassword(ADMIN_EMAIL, ADMIN_PASSWORD);
        console.log('✅ 管理员登录成功');

        // 1. 获取上次同步进度
        let lastTimestamp = "";
        try {
            const state = await pb.collection('stats_state').getFirstListItem('key="current"');
            lastTimestamp = state.last_timestamp;
        } catch (e) {
            console.log('ℹ️ 未发现同步状态，将进行全量统计。');
        }

        // 2. 捞取新产生的 trips
        const resultList = await pb.collection('trips').getList(1, 500, {
            filter: `created > "${lastTimestamp}"`,
            sort: 'created',
            requestKey: null
        });

        if (resultList.items.length === 0) {
            console.log('✅ 数据已是最新，无需同步。');
            await exportArenaJson(pb);
            return;
        }

        console.log(`📦 正在处理 ${resultList.items.length} 条新行程...`);

        // 3. 聚合处理
        for (const trip of resultList.items) {
            // 解析 metrics
            let metrics = {};
            try {
                metrics = typeof trip.metrics === 'string' ? JSON.parse(trip.metrics) : (trip.metrics || {});
            } catch (e) {
                console.warn(`⚠️ Trip ${trip.id} metrics 解析失败`);
            }
            
            const dist = parseFloat(metrics.distance_km || 0);
            const events = parseInt(metrics.event_count || 0);
            const speed_dist = metrics.speed_dist || {};
            const event_breakdown = metrics.event_breakdown || {};
            
            const userId = trip.user;
            const brandId = trip.brand;
            const versionId = trip.software_version;
            const created = trip.created;

            const month = created.slice(0, 7);
            const week = getYearWeek(created);

            // 需要同步的维度
            const periods = [
                { type: 'all', value: 'total' },
                { type: 'monthly', value: month },
                { type: 'weekly', value: week }
            ];

            for (const p of periods) {
                const key = `${userId}_${brandId}_${versionId}_${p.type}_${p.value}`;
                
                try {
                    // 尝试更新现有记录
                    const existing = await pb.collection('trip_stats_summary').getFirstListItem(`key="${key}"`);
                    
                    const new_speed_dist = existing.speed_dist || {};
                    Object.keys(speed_dist).forEach(k => {
                        new_speed_dist[k] = (new_speed_dist[k] || 0) + (speed_dist[k] || 0);
                    });

                    const new_event_breakdown = existing.event_breakdown || {};
                    Object.keys(event_breakdown).forEach(k => {
                        new_event_breakdown[k] = (new_event_breakdown[k] || 0) + (event_breakdown[k] || 0);
                    });

                    await pb.collection('trip_stats_summary').update(existing.id, {
                        total_distance: (existing.total_distance || 0) + dist,
                        total_events: (existing.total_events || 0) + events,
                        trip_count: (existing.trip_count || 0) + 1,
                        last_trip_id: trip.id,
                        speed_dist: new_speed_dist,
                        event_breakdown: new_event_breakdown
                    });
                } catch (e) {
                    // 创建新记录
                    await pb.collection('trip_stats_summary').create({
                        key: key,
                        user: userId,
                        brand: brandId,
                        version: versionId,
                        period_type: p.type,
                        period_value: p.value,
                        total_distance: dist,
                        total_events: events,
                        trip_count: 1,
                        last_trip_id: trip.id,
                        speed_dist: speed_dist,
                        event_breakdown: event_breakdown
                    });
                }
            }
            lastTimestamp = created;
        }

        // 4. 更新同步状态
        try {
            const state = await pb.collection('stats_state').getFirstListItem('key="current"');
            await pb.collection('stats_state').update(state.id, { last_timestamp: lastTimestamp });
        } catch (e) {
            await pb.collection('stats_state').create({ key: 'current', last_timestamp: lastTimestamp });
        }

        // 5. 导出最终的静态 JSON
        await exportArenaJson(pb);

        console.log(`✨ 同步任务完成，进度已更新至: ${lastTimestamp}`);

    } catch (err) {
        console.error('❌ 同步失败:', err.message);
        process.exit(1);
    }
}

/**
 * 导出 Arena 竞技场所需的静态 JSON
 */
async function exportArenaJson(pb) {
    console.log('📊 正在生成静态排行榜...');
    
    try {
        const allStats = await pb.collection('trip_stats_summary').getFullList({
            filter: 'period_type="all"',
            expand: 'brand,version',
            requestKey: null
        });

        const rankingAggregation = {};
        const mileageAggregation = {};
        const brandOptions = [];
        const seenBrands = new Set();

        allStats.forEach(s => {
            const brandId = s.brand;
            const bName = s.expand?.brand?.name || 'Unknown';
            const vName = s.expand?.software_version?.version_name || s.expand?.software_version?.versionString || 'Unknown';
            const groupKey = `${bName} | ${vName}`;
            
            // 1. 聚合排行榜 (Brand + Version)
            if (!rankingAggregation[groupKey]) {
                rankingAggregation[groupKey] = {
                    label: groupKey,
                    brand: bName,
                    brandId: brandId,
                    version: vName,
                    total_distance: 0,
                    total_events: 0
                };
            }
            rankingAggregation[groupKey].total_distance += s.total_distance;
            rankingAggregation[groupKey].total_events += s.total_events;

            // 2. 聚合里程分布 (Brand only)
            if (!mileageAggregation[brandId]) {
                mileageAggregation[brandId] = {
                    brand: bName,
                    brandKey: brandId,
                    totalKm: 0,
                    breakdown: { highway: 0, smooth: 0, urban: 0, congested: 0 }
                };
            }
            mileageAggregation[brandId].totalKm += s.total_distance;
            if (s.speed_dist) {
                Object.keys(s.speed_dist).forEach(k => {
                    mileageAggregation[brandId].breakdown[k] = (mileageAggregation[brandId].breakdown[k] || 0) + (s.speed_dist[k] || 0);
                });
            }

            // 3. 收集品牌选项
            if (!seenBrands.has(brandId)) {
                seenBrands.add(brandId);
                brandOptions.push({ key: brandId, name: bName });
            }
        });

        const ranking_brand = Object.values(rankingAggregation).map(item => ({
            label: item.brand,
            brand: item.brand,
            brandId: item.brandId,
            totalKm: item.total_distance,
            totalEvents: item.total_events,
            kmPerEvent: item.total_events > 0 ? item.total_distance / item.total_events : item.total_distance
        })).sort((a, b) => b.kmPerEvent - a.kmPerEvent);

        const mileage = Object.values(mileageAggregation)
            .sort((a, b) => b.totalKm - a.totalKm);

        const payload = {
            updated_at: new Date().toISOString(),
            ranking_brand: ranking_brand,
            mileage: mileage,
            brand_options: brandOptions,
            // 保持对旧版本的兼容
            data: ranking_brand 
        };

        fs.writeFileSync(OUTPUT_PATH, JSON.stringify(payload, null, 2));
        console.log(`💾 静态 JSON 已保存至: ${OUTPUT_PATH}`);
    } catch (e) {
        console.error('❌ 导出 JSON 失败:', e.message);
    }
}

run();
