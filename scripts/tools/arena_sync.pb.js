/**
 * Puked Arena 核心引擎 (v40 - 增量归纳版)
 * 职责：
 * 1. 增量从 trips 表归纳数据到 trip_stats_summary (物理聚合层)
 * 2. 从 trip_stats_summary 生成全量快照到 arena_stats (展示缓存层)
 */

// --- 核心配置 ---
const SETTINGS = {
    BATCH_SIZE: 500,
    FALLBACK_BRAND: "others",
    FALLBACK_VERSION: "others"
};

/**
 * 增量归纳任务
 */
function runInductionTask() {
    console.log("[Induction] >>> 启动增量归纳...");

    // 1. 获取同步状态
    let lastTimestamp = "2000-01-01 00:00:00";
    let stateRecord = null;
    try {
        const states = $app.findRecordsByFilter("stats_state", "key = 'current'", "-created", 1, 0);
        if (states.length > 0) {
            stateRecord = states[0];
            lastTimestamp = stateRecord.get("last_timestamp");
        }
    } catch (e) {
        console.log("[Induction] 获取状态失败: " + e.message);
    }

    // 2. 捞取新产生的公开合法 trips
    const newTrips = $app.findRecordsByFilter(
        "trips",
        "is_public = true && created > {:ts}",
        "created",
        SETTINGS.BATCH_SIZE,
        0,
        { ts: lastTimestamp }
    );

    if (newTrips.length === 0) {
        console.log("[Induction] 无新记录，跳过。");
        return false;
    }

    console.log("[Induction] 发现 " + newTrips.length + " 条新记录，开始处理...");

    // 3. 准备映射表 (优化 IO)
    const brandMap = {};
    const versionMap = {};
    $app.findRecordsByFilter("brands", "1=1").forEach(b => brandMap[b.get("name").toLowerCase()] = b.id);
    $app.findRecordsByFilter("software_versions", "1=1").forEach(v => {
        const vStr = (v.get("versionString") || v.get("version_name") || "").toLowerCase();
        if (vStr) versionMap[vStr] = v.id;
    });

    // 获取兜底 ID
    const getFallbackId = (coll, nameField, val) => {
        try {
            const existing = $app.findRecordsByFilter(coll, nameField + " = {:v}", "", 1, 0, { v: val });
            return existing.length > 0 ? existing[0].id : null;
        } catch (e) { return null; }
    };
    const othersBrandId = brandMap[SETTINGS.FALLBACK_BRAND] || getFallbackId("brands", "name", SETTINGS.FALLBACK_BRAND);
    const othersVersionId = versionMap[SETTINGS.FALLBACK_VERSION] || getFallbackId("software_versions", "versionString", SETTINGS.FALLBACK_VERSION);

    let maxProcessedTime = lastTimestamp;

    // 4. 迭代处理
    newTrips.forEach(trip => {
        const metricsRaw = trip.get("metrics");
        let m = (typeof metricsRaw === 'string') ? JSON.parse(metricsRaw || "{}") : (metricsRaw || {});

        const dist = parseFloat(m.distance_km || 0);
        const events = parseInt(m.event_count || 0);
        const avgSpeed = parseFloat(m.avg_speed_kmh || 0);
        const tripCreated = trip.get("created");
        const scenario = avgSpeed >= 50 ? 'highway' : 'city';
        const userId = trip.get("user") || trip.get("owner");

        // 映射品牌和版本
        const rawBrand = (trip.get("brand") || "Unknown").trim().toLowerCase();
        const rawVersion = (trip.get("software_version") || trip.get("version") || "Unknown").trim().toLowerCase();

        const brandId = brandMap[rawBrand] || othersBrandId;
        const versionId = versionMap[rawVersion] || othersVersionId;

        if (!brandId || !versionId) return;

        // 定义周期
        const date = new Date(tripCreated.replace(' ', 'T'));
        const periods = [
            { type: 'all', value: 'ALL' },
            { type: 'monthly', value: date.getFullYear() + "-" + (date.getMonth() + 1).toString().padStart(2, '0') },
            { type: 'weekly', value: date.getFullYear() + "-W" + Math.ceil(date.getDate() / 7) }
        ];

        periods.forEach(p => {
            const key = userId + "_" + brandId + "_" + versionId + "_" + scenario + "_" + p.type + "_" + p.value;

            try {
                const existing = $app.findRecordsByFilter("trip_stats_summary", "key = {:k}", "", 1, 0, { k: key });
                let summary;
                if (existing.length > 0) {
                    summary = existing[0];
                    const oldDist = summary.get("total_distance");
                    const newDist = oldDist + dist;
                    summary.set("total_distance", newDist);
                    summary.set("total_events", summary.get("total_events") + events);
                    summary.set("trip_count", summary.get("trip_count") + 1);
                    summary.set("last_trip_id", trip.id);

                    // 累加 Breakdown (简单对象处理)
                    const eb = summary.get("event_breakdown") || {};
                    const teb = m.event_breakdown || {};
                    Object.keys(teb).forEach(k => eb[k] = (eb[k] || 0) + (teb[k] || 0));
                    summary.set("event_breakdown", eb);

                    const sd = summary.get("speed_dist") || {};
                    const tsd = m.speed_dist || {};
                    Object.keys(tsd).forEach(k => sd[k] = (sd[k] || 0) + (tsd[k] || 0));
                    summary.set("speed_dist", sd);

                } else {
                    const collection = $app.findCollectionByNameOrId("trip_stats_summary");
                    summary = new Record(collection);
                    summary.set("key", key);
                    summary.set("user", userId);
                    summary.set("brand", brandId);
                    summary.set("software_version", versionId);
                    summary.set("period_type", p.type);
                    summary.set("period_value", p.value);
                    summary.set("total_distance", dist);
                    summary.set("total_events", events);
                    summary.set("trip_count", 1);
                    summary.set("last_trip_id", trip.id);
                    summary.set("event_breakdown", m.event_breakdown || {});
                    summary.set("speed_dist", m.speed_dist || {});
                }
                $app.save(summary);
            } catch (err) {
                console.log("[Induction] 保存汇总失败: " + err.message);
            }
        });

        if (tripCreated > maxProcessedTime) maxProcessedTime = tripCreated;
    });

    // 5. 更新状态
    if (!stateRecord) {
        const col = $app.findCollectionByNameOrId("stats_state");
        stateRecord = new Record(col);
        stateRecord.set("key", "current");
    }
    stateRecord.set("last_timestamp", maxProcessedTime);
    $app.save(stateRecord);

    console.log("[Induction] 归纳完成，进度: " + maxProcessedTime);
    return true;
}

/**
 * 刷新快照任务 (基于汇总层数据)
 */
function refreshSnapshotTask() {
    console.log("[Snapshot] >>> 刷新全量快照...");
    const arenaColl = $app.findCollectionByNameOrId("arena_stats");

    // 只从汇总层获取 "all" 类型的数据
    const summaries = $app.findRecordsByFilter("trip_stats_summary", "period_type = 'all'", "-total_distance", 1000, 0);
    const brands = $app.findRecordsByFilter("brands", "1=1", "order", 100, 0);

    const brandMap = {};
    brands.forEach(b => brandMap[b.id] = { id: b.id, name: b.get("displayName") || b.get("name") });

    const stats = {
        ranking_brand: {}, ranking_version: {}, ranking_city: {}, ranking_highway: {},
        mileage: {}, user_leaderboard: {}, global_summary: { totalMileage: 0, trips: 0 },
        brand_options: []
    };

    summaries.forEach(s => {
        const bId = s.get("brand");
        const bName = brandMap[bId] ? brandMap[bId].name : "Unknown";
        const vId = s.get("software_version");
        // 这里简化处理，实际可能需要更复杂的版本名称查询
        const ver = "v" + vId.slice(-4);

        const dist = s.get("total_distance");
        const evts = s.get("total_events");
        const tripCount = s.get("trip_count");
        const scenario = s.get("scenario") || (s.get("key").includes("_highway_") ? "highway" : "city");

        stats.global_summary.totalMileage += dist;
        stats.global_summary.trips += tripCount;

        const add = (group, key, label) => {
            if (!group[key]) group[key] = { label, brand: bId, km: 0, evts: 0 };
            group[key].km += dist; group[key].evts += evts;
        };

        add(stats.ranking_brand, bId, bName);
        add(stats.ranking_version, bId + "|" + ver, bName + " " + ver);

        if (scenario === 'city') add(stats.ranking_city, bId, bName);
        else add(stats.ranking_highway, bId, bName);

        if (!stats.mileage[bId]) {
            stats.mileage[bId] = { brand: bName, brandKey: bId, totalKm: 0, breakdown: { highway: 0, smooth: 0, urban: 0, congested: 0 } };
        }
        stats.mileage[bId].totalKm += dist;
        const sd = s.get("speed_dist") || {};
        Object.keys(sd).forEach(k => stats.mileage[bId].breakdown[k] = (stats.mileage[bId].breakdown[k] || 0) + sd[k]);
    });

    const finalize = (obj, threshold) => Object.values(obj).filter(v => v.km >= (threshold || 0)).map(v => ({
        label: v.label, brand: v.brand, totalKm: v.km, totalEvents: v.evts,
        kmPerEvent: v.evts === 0 ? v.km : Math.min(100.0, v.km / v.evts)
    })).sort((a, b) => b.kmPerEvent - a.kmPerEvent);

    const save = (key, payload) => {
        const existing = $app.findRecordsByFilter("arena_stats", "stat_key = {:k}", "", 1, 0, { k: key });
        let r = existing.length > 0 ? existing[0] : new Record(arenaColl);
        r.set("stat_key", key);
        r.set("category", "arena_snapshot");
        r.set("payload", payload);
        $app.save(r);
    };

    const rankingThreshold = 300.0;
    save("ranking_brand", finalize(stats.ranking_brand, rankingThreshold));
    save("ranking_version", finalize(stats.ranking_version, rankingThreshold));
    save("ranking_city", finalize(stats.ranking_city, rankingThreshold / 2));
    save("ranking_highway", finalize(stats.ranking_highway, rankingThreshold / 2));
    save("global_summary", stats.global_summary);
    save("brand_options", Object.values(brandMap).map(v => ({ key: v.id, name: v.name })));

    console.log("[Snapshot] 刷新完成。");
}

/**
 * 刷新用户个人统计数据摘要
 */
function refreshUserStatsTask() {
    console.log("[UserStats] >>> 刷新用户数据摘要...");

    // 1. 获取所有 period_type = 'all' 的汇总数据
    const summaries = $app.findRecordsByFilter("trip_stats_summary", "period_type = 'all'", "", 5000, 0);
    const brands = $app.findRecordsByFilter("brands", "1=1", "", 200, 0);
    const brandNameMap = {};
    brands.forEach(b => brandNameMap[b.id] = b.get("name"));

    const userMap = {};

    // 2. 按用户进行内存聚合
    summaries.forEach(s => {
        const userId = s.get("user");
        if (!userId) return;

        if (!userMap[userId]) {
            userMap[userId] = {
                totalMileage: 0,
                totalEvents: 0,
                brandDist: {}
            };
        }

        const u = userMap[userId];
        const dist = s.get("total_distance");
        u.totalMileage += dist;
        u.totalEvents += s.get("total_events");

        const bId = s.get("brand");
        const bName = brandNameMap[bId] || "Others";
        u.brandDist[bName] = (u.brandDist[bName] || 0) + dist;
    });

    const sortedUserIds = Object.keys(userMap).sort((a, b) => userMap[b].totalMileage - userMap[a].totalMileage);
    const totalUsers = sortedUserIds.length;
    const userStatsColl = $app.findCollectionByNameOrId("user_stats");

    // 3. 计算排名并写回
    sortedUserIds.forEach((userId, index) => {
        const u = userMap[userId];
        const rank = index + 1;
        const pukedValue = u.totalEvents > 0 ? (u.totalMileage / u.totalEvents) : u.totalMileage;

        const payload = {
            totalMileage: parseFloat(u.totalMileage.toFixed(2)),
            brandDistribution: u.brandDist,
            rank: rank,
            totalUsers: totalUsers,
            pukedValue: parseFloat(pukedValue.toFixed(2)),
            updated_at: new Date().toISOString()
        };

        try {
            const existing = $app.findRecordsByFilter("user_stats", "user_id = {:uid}", "", 1, 0, { uid: userId });
            let r = existing.length > 0 ? existing[0] : new Record(userStatsColl);

            r.set("user_id", userId);
            r.set("payload", payload);
            $app.save(r);
        } catch (e) {
            console.log("[UserStats] 保存用户 " + userId + " 失败: " + e.message);
        }
    });

    console.log("[UserStats] 刷新完成，处理 " + totalUsers + " 个用户。");
}

/**
 * 外部触发接口
 */
routerAdd("GET", "/api/arena-sync-trigger", (c) => {
    try {
        const updated = runInductionTask();
        if (updated) {
            refreshSnapshotTask();
            refreshUserStatsTask();
        }
        return c.json(200, { "status": "success", "updated": updated });
    } catch (err) {
        return c.json(500, { "error": err.message });
    }
});

/**
 * 定时任务 (智能调度版 - 方案D混合架构)
 * 检查频率：每小时
 * 执行频率：根据 stats_state.sync_interval 配置动态决定
 */

// 获取状态记录的辅助函数
function getStateRecord() {
    try {
        const states = $app.findRecordsByFilter("stats_state", "key = 'current'", "-created", 1, 0);
        return states.length > 0 ? states[0] : null;
    } catch (e) {
        console.log("[AutoSync] 获取状态失败: " + e.message);
        return null;
    }
}

// 更新同步状态
function updateSyncStatus(status, enableAutoSync, syncInterval) {
    try {
        const stateRecord = getStateRecord();
        if (stateRecord) {
            stateRecord.set("last_sync_time", new Date().toISOString().replace('T', ' ').slice(0, 19));
            stateRecord.set("last_sync_status", status);
            if (enableAutoSync !== undefined) stateRecord.set("enable_auto_sync", enableAutoSync);
            if (syncInterval !== undefined) stateRecord.set("sync_interval", syncInterval);
            $app.save(stateRecord);
        }
    } catch (e) {
        console.log("[AutoSync] 更新状态失败: " + e.message);
    }
}

// 定时检查器 - 每小时检查一次
cronAdd("arena_sync_checker", "0 * * * *", () => {
    console.log("[🔍 AutoSync] 启动定时检查器...");

    // 读取配置
    const stateRecord = getStateRecord();
    if (!stateRecord) {
        console.log("[⚠️  AutoSync] 未找到配置记录，跳过");
        return;
    }

    // 检查是否启用自动同步（默认启用）
    const enableAutoSync = stateRecord.get("enable_auto_sync") !== false;
    if (!enableAutoSync) {
        console.log("[⏸️  AutoSync] 自动同步已禁用");
        return;
    }

    // 读取用户配置的同步间隔（分钟）
    const syncInterval = parseInt(stateRecord.get("sync_interval") || 60); // 默认60分钟
    const lastSyncTime = stateRecord.get("last_sync_time");

    // 计算距离上次同步的时间
    let shouldSync = false;
    if (!lastSyncTime) {
        console.log("[✅ AutoSync] 首次运行，立即执行");
        shouldSync = true;
    } else {
        try {
            const lastSync = new Date(lastSyncTime.replace(' ', 'T'));
            const now = new Date();
            const elapsedMinutes = (now - lastSync) / (1000 * 60);

            if (elapsedMinutes >= syncInterval) {
                console.log("[✅ AutoSync] 满足触发条件: 已过 " + Math.floor(elapsedMinutes) + " 分钟 >= 设定间隔 " + syncInterval + " 分钟");
                shouldSync = true;
            } else {
                const remaining = Math.ceil(syncInterval - elapsedMinutes);
                console.log("[⏳ AutoSync] 未到触发时间: 已过 " + Math.floor(elapsedMinutes) + " 分钟 < 设定间隔 " + syncInterval + " 分钟，还需等待 " + remaining + " 分钟");
            }
        } catch (e) {
            console.log("[⚠️  AutoSync] 解析时间失败: " + e.message + "，安全起见尝试同步一次");
            shouldSync = true; // 出错时执行一次
        }
    }

    if (shouldSync) {
        try {
            // 🆕 方案：创建批量任务而不是直接处理
            console.log("[🚀 AutoSync] 创建批量同步任务...");

            // 1. 检查是否已有正在运行的任务
            const runningTasks = $app.findRecordsByFilter(
                "sync_tasks",
                "task_type = 'batch_sync' && (status = 'pending' || status = 'running')",
                "-created",
                1,
                0
            );

            if (runningTasks.length > 0) {
                console.log("[⏸️  AutoSync] 已有任务在队列中，跳过本次");
                return;
            }

            // 2. 创建新的批量同步任务
            const taskColl = $app.findCollectionByNameOrId("sync_tasks");
            const task = new Record(taskColl);
            task.set("task_type", "batch_sync");
            task.set("status", "pending");
            task.set("progress", 0);
            task.set("created_by", "AUTO_SYNC"); // 标记为自动触发
            $app.save(task);

            console.log("[✅ AutoSync] 任务已创建: " + task.id + "，等待后台处理器执行");

            // 3. 更新同步状态为运行中
            updateSyncStatus("running", enableAutoSync, syncInterval);

        } catch (err) {
            console.log("[❌ AutoSync] 创建任务失败: " + err.message);
            updateSyncStatus("failed", enableAutoSync, syncInterval);
        }
    }
});
