/**
 * Puked Arena 核心引擎 (v35 - 真实数据最终版)
 */

routerAdd("GET", "/api/arena-sync-trigger", (c) => {
    try {
        console.log("[Arena] >>> 启动数据同步 v35...");

        const arenaColl = $app.findCollectionByNameOrId("arena_stats");
        // 限制增加到 2000，确保覆盖所有公开数据
        const trips = $app.findRecordsByFilter("trips", "is_public = true", "-created", 2000, 0);
        const brands = $app.findRecordsByFilter("brands", "1=1", "order", 100, 0);
        const users = $app.findRecordsByFilter("users", "1=1", "", 500, 0);

        const stats = {
            ranking_brand: {}, ranking_version: {}, ranking_city: {}, ranking_highway: {},
            mileage: {}, user_leaderboard: {}
        };
        const brandDetails = {};

        trips.forEach(t => {
            const bId = t.get("brand_ref") || t.get("brand");
            const bRec = brands.find(b => b.id === bId || b.get("name") === bId);
            if (!bRec) return;

            const bKey = bRec.id;
            const bName = bRec.get("displayName") || bRec.get("name");
            
            // --- 鲁棒解析 metrics ---
            let mRaw = t.get("metrics");
            let m = (typeof mRaw === 'string') ? JSON.parse(mRaw || "{}") : (mRaw || {});
            let km = parseFloat(m.distance_km || 0) || (parseFloat(m.distance || 0) / 1000.0);
            let sec = parseFloat(m.duration_seconds || m.duration_sec || (m.duration_minutes * 60) || 0);
            let speed = sec > 10 ? (km / (sec / 3600.0)) : -1;
            let eb = m.event_breakdown || {};
            let evts = (parseInt(eb.rapidAcceleration || 0) + parseInt(eb.rapidDeceleration || 0) + 
                        parseInt(eb.jerk || 0) + parseInt(eb.bump || 0) + parseInt(eb.wobble || 0));
            let ver = (t.get("software_version") || "Unknown").trim();
            const uId = t.get("user") || t.get("owner");

            // 1. 聚合排行
            const add = (group, key, label) => {
                if (!group[key]) group[key] = { label, brand: bKey, km: 0, evts: 0 };
                group[key].km += km; group[key].evts += evts;
            };
            add(stats.ranking_brand, bKey, bName);
            if (ver !== "Unknown") add(stats.ranking_version, bKey + "|" + ver, bName + " " + ver);
            if (speed > 0) {
                if (speed < 50) add(stats.ranking_city, bKey, bName);
                else add(stats.ranking_highway, bKey, bName);
            }

            // 2. 里程分布
            if (!stats.mileage[bKey]) stats.mileage[bKey] = { brand: bName, brandKey: bKey, totalKm: 0, breakdown: { highway: 0, smooth: 0, urban: 0, congested: 0 }};
            stats.mileage[bKey].totalKm += km;
            if (speed > 80) stats.mileage[bKey].breakdown.highway += km;
            else if (speed > 50) stats.mileage[bKey].breakdown.smooth += km;
            else if (speed > 20) stats.mileage[bKey].breakdown.urban += km;
            else stats.mileage[bKey].breakdown.congested += km;

            // 3. 详情图表数据
            if (!brandDetails[bKey]) brandDetails[bKey] = { symptoms: { counts: {}, totalKm: 0 }, evolution: {} };
            brandDetails[bKey].symptoms.totalKm += km;
            ["rapidAcceleration", "rapidDeceleration", "jerk", "bump", "wobble"].forEach(k => {
                brandDetails[bKey].symptoms.counts[k] = (brandDetails[bKey].symptoms.counts[k] || 0) + parseInt(eb[k] || 0);
            });
            if (ver !== "Unknown") {
                if (!brandDetails[bKey].evolution[ver]) brandDetails[bKey].evolution[ver] = { km: 0, evts: 0 };
                brandDetails[bKey].evolution[ver].km += km;
                brandDetails[bKey].evolution[ver].evts += evts;
            }

            // 4. 用户贡献
            if (uId) {
                if (!stats.user_leaderboard[uId]) {
                    const uRec = users.find(u => u.id === uId);
                    stats.user_leaderboard[uId] = { userName: uRec ? (uRec.get("name") || uRec.get("username") || "Driver") : "Driver", totalKm: 0 };
                }
                stats.user_leaderboard[uId].totalKm += km;
            }
        });

        // --- 最终处理与写入 ---
        const rankingThreshold = 300.0;
        const finalize = (obj, threshold) => Object.values(obj).filter(v => v.km >= (threshold || 0)).map(v => ({
            label: v.label, brand: v.brand, totalKm: v.km, totalEvents: v.evts,
            // 真实舒适度算法：每事件公里数。若无事件，给予里程驱动的评分（最高100）
            kmPerEvent: v.evts === 0 ? Math.min(100, v.km * 5) : v.km / v.evts
        })).sort((a, b) => b.kmPerEvent - a.kmPerEvent);

        const save = (key, payload) => {
            const existing = $app.findRecordsByFilter("arena_stats", "stat_key = {:k}", "", 1, 0, { k: key });
            let r = existing.length > 0 ? existing[0] : new Record(arenaColl);
            r.set("stat_key", key); r.set("payload", payload); $app.save(r);
        };

        save("ranking_brand", finalize(stats.ranking_brand, rankingThreshold));
        save("ranking_version", finalize(stats.ranking_version, rankingThreshold));
        save("ranking_city", finalize(stats.ranking_city, rankingThreshold / 2));
        save("ranking_highway", finalize(stats.ranking_highway, rankingThreshold / 2));
        save("mileage_distribution", Object.values(stats.mileage).sort((a, b) => b.totalKm - a.totalKm));
        save("leaderboard_total", Object.values(stats.user_leaderboard).sort((a, b) => b.totalKm - a.totalKm).slice(0, 10));
        save("brand_options", Object.values(stats.ranking_brand).map(v => ({ key: v.brand, name: v.label })));
        save("global_summary", { totalMileage: Object.values(stats.ranking_brand).reduce((s, b) => s + b.km, 0), trips: trips.length });

        Object.keys(brandDetails).forEach(bk => {
            const d = brandDetails[bk];
            const symDetails = {};
            Object.keys(d.symptoms.counts).forEach(k => {
                symDetails[k] = d.symptoms.counts[k] === 0 ? 100 : d.symptoms.totalKm / d.symptoms.counts[k];
            });
            save("symptoms_" + bk, { details: symDetails, counts: d.symptoms.counts, totalKm: d.symptoms.totalKm });
            const evo = Object.entries(d.evolution).map(([v, val]) => ({
                version: v, kmPerEvent: val.evts === 0 ? 100 : val.km / val.evts
            })).sort((a, b) => a.version.localeCompare(b.version, undefined, { numeric: true }));
            save("evolution_" + bk, evo);
        });

        return c.json(200, { "status": "success" });
    } catch (err) {
        return c.json(500, { "error": err.message });
    }
});