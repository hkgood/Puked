import { pb } from '../../../services/pocketbase';

export class ArenaService {
  static getKm(metrics: any): number {
    if (!metrics) return 0;
    const target = metrics.metrics || metrics;
    const m = typeof target === 'string' ? JSON.parse(target) : target;
    return parseFloat(m.distance_km || m.distance || '0');
  }

  static getAvgSpeed(metrics: any): number {
    if (!metrics) return 0;
    const target = metrics.metrics || metrics;
    const m = typeof target === 'string' ? JSON.parse(target) : target;
    return parseFloat(m.avg_speed_kmh || m.avg_speed || '0');
  }

  static getLogoUrl(brands: any[], brandNameOrId: string): string | null {
    if (!brandNameOrId || brandNameOrId === 'Unknown') return null;

    const brand = brands.find(b =>
      b.name.toLowerCase() === brandNameOrId.toLowerCase() ||
      b.id === brandNameOrId
    );

    if (brand && brand.logo) {
      return pb.files.getURL(brand, brand.logo, { thumb: '100x100' });
    }

    const logos: Record<string, string> = {
      'tesla': '/assets/logos/Tesla.svg',
      'xiaomi': '/assets/logos/Xiaomi.svg',
      'nio': '/assets/logos/Nio.svg',
      'xpeng': '/assets/logos/Xpeng.svg',
      'liauto': '/assets/logos/LiAuto.svg',
      'huawei': '/assets/logos/Huawei.svg',
      'zeekr': '/assets/logos/Zeekr.svg',
      'onvo': '/assets/logos/Onvo.svg',
      'waymo': '/assets/logos/Waymo.svg',
      'zoox': '/assets/logos/Zoox.svg',
      'apollogo': '/assets/logos/ApolloGo.svg',
    };

    return logos[brandNameOrId.toLowerCase()] || null;
  }

  static getYearWeek(d: Date): string {
    const tempDate = new Date(d.getTime());
    tempDate.setHours(0, 0, 0, 0);
    tempDate.setDate(tempDate.getDate() + 4 - (tempDate.getDay() || 7));
    const yearStart = new Date(tempDate.getFullYear(), 0, 1);
    const weekNo = Math.ceil((((tempDate.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
    return `${tempDate.getFullYear()}-W${weekNo.toString().padStart(2, '0')}`;
  }

  static async getBaseLibrary(): Promise<{ brands: any[], versions: any[] }> {
    try {
      const brands = await pb.collection('brands').getFullList({
        sort: 'name',
        fields: 'id,collectionId,name,logo',
        requestKey: null
      });
      return { brands, versions: [] };
    } catch (e) {
      console.error("Fetch base library failed:", e);
      return { brands: [], versions: [] };
    }
  }

  static async getStatsSnapshot(): Promise<any> {
    try {
      const [allSummary, weeklySummaryUser, weeklySummaryBrand] = await Promise.all([
        pb.collection('trip_stats_summary').getFullList({
          filter: 'period_type="all"',
          expand: 'brand,software_version,user',
          fields: 'id,collectionId,key,total_distance,total_events,trip_count,speed_dist,event_breakdown,scenario,brand,software_version,user,expand.brand.id,expand.brand.collectionId,expand.brand.name,expand.brand.logo,expand.software_version.id,expand.software_version.collectionId,expand.software_version.version_name,expand.software_version.versionString,expand.user.id,expand.user.collectionId,expand.user.username,expand.user.name,expand.user.avatar',
          sort: '-total_distance',
          requestKey: null
        }),
        // 周度用户数据（用于用户贡献榜）
        pb.collection('trip_stats_summary').getFullList({
          filter: 'period_type="weekly"',
          expand: 'user',
          fields: 'id,collectionId,total_distance,period_value,user,expand.user.id,expand.user.collectionId,expand.user.username,expand.user.name,expand.user.avatar',
          sort: '-total_distance',
          requestKey: null
        }),
        // 🆕 周度品牌数据（用于品牌周度排名和里程统计）
        pb.collection('trip_stats_summary').getFullList({
          filter: 'period_type="weekly"',
          expand: 'brand',
          fields: 'id,collectionId,key,total_distance,total_events,period_value,scenario,speed_dist,brand,expand.brand.id,expand.brand.collectionId,expand.brand.name,expand.brand.logo',
          sort: '-total_distance',
          requestKey: null
        })
      ]);

      const stats: any = {
        ranking_brand: [],
        ranking_version: [],
        ranking_city: [],
        ranking_highway: [],
        mileage: [],
        leaderboard_total: [],
        leaderboard_weekly: [],
        brand_options: [],
        // 🆕 周度品牌排名数据
        ranking_city_weekly: [],
        ranking_highway_weekly: [],
        mileage_weekly: []
      };

      if (allSummary.length === 0) return stats;

      const brandMap = new Map<string, any>();
      const brandCityMap = new Map<string, any>();
      const brandHighwayMap = new Map<string, any>();
      const versionMap = new Map<string, any>();
      const userTotalMap = new Map<string, any>();
      const userWeeklyMap = new Map<string, any>();
      // 🆕 周度品牌数据的 Map
      const brandWeeklyMap = new Map<string, any>();
      const brandCityWeeklyMap = new Map<string, any>();
      const brandHighwayWeeklyMap = new Map<string, any>();

      const urlCache = new Map<string, string>();
      const getCachedUrl = (record: any, fileName: string) => {
        if (!record || !fileName || !record.id || !record.collectionId) return '';
        const key = `${record.collectionId}_${record.id}_${fileName}`;
        if (!urlCache.has(key)) {
          urlCache.set(key, pb.files.getURL(record, fileName));
        }
        return urlCache.get(key);
      };

      allSummary.forEach(s => {
        const brandId = s.brand;
        const brandName = s.expand?.brand?.name || 'Unknown';
        const versionId = s.software_version;
        const versionName = s.expand?.software_version?.version_name || s.expand?.software_version?.versionString || 'Unknown';
        const userId = s.user;
        const userName = s.expand?.user?.username || s.expand?.user?.name || 'Unknown';
        const avatarUrl = (s.expand?.user && s.expand.user.avatar) ? getCachedUrl(s.expand.user, s.expand.user.avatar) : '';

        let distObj = { highway: 0, smooth: 0, urban: 0, congested: 0 };
        try {
          const rawDist = typeof s.speed_dist === 'string' ? JSON.parse(s.speed_dist) : s.speed_dist;
          if (rawDist) {
            distObj.highway = parseFloat(rawDist.highway || 0);
            distObj.smooth = parseFloat(rawDist.smooth || 0);
            distObj.urban = parseFloat(rawDist.urban || 0);
            distObj.congested = parseFloat(rawDist.congested || 0);
          }
        } catch (e) { }

        if (!brandMap.has(brandId)) {
          brandMap.set(brandId, {
            id: brandId, name: brandName, totalKm: 0, totalEvents: 0, tripCount: 0,
            mileage_buckets: { h80: 0, m5080: 0, l2050: 0, c20: 0 },
            event_breakdown: { rapidAcceleration: 0, rapidDeceleration: 0, jerk: 0, bump: 0, wobble: 0 }
          });
        }
        const b = brandMap.get(brandId);
        b.totalKm += s.total_distance;
        b.totalEvents += s.total_events;
        b.tripCount += s.trip_count || 0;

        b.mileage_buckets.h80 += distObj.highway;
        b.mileage_buckets.m5080 += distObj.smooth;
        b.mileage_buckets.l2050 += distObj.urban;
        b.mileage_buckets.c20 += distObj.congested;

        const scenario = s.scenario || (s.key && s.key.includes('_highway_') ? 'highway' : 'city');
        const targetMap = scenario === 'highway' ? brandHighwayMap : brandCityMap;
        if (!targetMap.has(brandId)) {
          targetMap.set(brandId, { id: brandId, name: brandName, km: 0, events: 0 });
        }
        const scenarioData = targetMap.get(brandId);
        scenarioData.km += s.total_distance;
        scenarioData.events += s.total_events;

        let eb = s.event_breakdown;
        try {
          if (typeof eb === 'string') eb = JSON.parse(eb);
        } catch (e) { }

        if (eb) {
          b.event_breakdown.rapidAcceleration += eb.rapidAcceleration || 0;
          b.event_breakdown.rapidDeceleration += eb.rapidDeceleration || 0;
          b.event_breakdown.jerk += eb.jerk || 0;
          b.event_breakdown.bump += eb.bump || 0;
          b.event_breakdown.wobble += eb.wobble || 0;
        }

        const vKey = `${brandId}_${versionId}`;
        if (!versionMap.has(vKey)) {
          versionMap.set(vKey, { brand: brandId, brandName, version: versionName, totalKm: 0, totalEvents: 0 });
        }
        const v = versionMap.get(vKey);
        v.totalKm += s.total_distance;
        v.totalEvents += s.total_events;

        if (userId) {
          if (!userTotalMap.has(userId)) {
            userTotalMap.set(userId, { userName, avatarUrl, totalKm: 0 });
          }
          userTotalMap.get(userId).totalKm += s.total_distance;
        }
      });

      const weeks = Array.from(new Set(weeklySummaryUser.map(s => s.period_value))).sort().reverse();
      const latestWeek = weeks[0];

      // 处理用户周度数据
      weeklySummaryUser.filter(s => s.period_value === latestWeek).forEach(s => {
        const userId = s.user;
        if (!userId) return;
        const userName = s.expand?.user?.username || s.expand?.user?.name || 'Unknown';
        const avatarUrl = (s.expand?.user && s.expand.user.avatar) ? getCachedUrl(s.expand.user, s.expand.user.avatar) : '';

        if (!userWeeklyMap.has(userId)) {
          userWeeklyMap.set(userId, { userName, avatarUrl, totalKm: 0 });
        }
        userWeeklyMap.get(userId).totalKm += s.total_distance;
      });

      // 🆕 处理品牌周度数据
      const brandWeeks = Array.from(new Set(weeklySummaryBrand.map(s => s.period_value))).sort().reverse();
      const latestBrandWeek = brandWeeks[0];

      weeklySummaryBrand.filter(s => s.period_value === latestBrandWeek).forEach(s => {
        const brandId = s.brand;
        const brandName = s.expand?.brand?.name || 'Unknown';
        
        // 🆕 解析速度分布数据
        let distObj = { highway: 0, smooth: 0, urban: 0, congested: 0 };
        try {
          const rawDist = typeof s.speed_dist === 'string' ? JSON.parse(s.speed_dist) : s.speed_dist;
          if (rawDist) {
            distObj.highway = parseFloat(rawDist.highway || 0);
            distObj.smooth = parseFloat(rawDist.smooth || 0);
            distObj.urban = parseFloat(rawDist.urban || 0);
            distObj.congested = parseFloat(rawDist.congested || 0);
          }
        } catch (e) { }
        
        // 累计品牌总里程（用于周度里程排名）
        if (!brandWeeklyMap.has(brandId)) {
          brandWeeklyMap.set(brandId, { 
            id: brandId, 
            name: brandName, 
            totalKm: 0,
            mileage_buckets: { h80: 0, m5080: 0, l2050: 0, c20: 0 }
          });
        }
        const bWeekly = brandWeeklyMap.get(brandId);
        bWeekly.totalKm += s.total_distance;
        bWeekly.mileage_buckets.h80 += distObj.highway;
        bWeekly.mileage_buckets.m5080 += distObj.smooth;
        bWeekly.mileage_buckets.l2050 += distObj.urban;
        bWeekly.mileage_buckets.c20 += distObj.congested;

        // 按场景分类（用于周度舒适度排名）
        const scenario = s.scenario || (s.key && s.key.includes('_highway_') ? 'highway' : 'city');
        const targetMap = scenario === 'highway' ? brandHighwayWeeklyMap : brandCityWeeklyMap;
        
        if (!targetMap.has(brandId)) {
          targetMap.set(brandId, { id: brandId, name: brandName, km: 0, events: 0 });
        }
        const scenarioData = targetMap.get(brandId);
        scenarioData.km += s.total_distance;
        scenarioData.events += s.total_events;
      });

      const rankingThreshold = 0.1;

      stats.ranking_brand = Array.from(brandMap.values())
        .filter(b => b.totalKm >= rankingThreshold)
        .map(b => ({
          label: b.name, brand: b.name, brandId: b.id,
          kmPerEvent: b.totalEvents > 0 ? b.totalKm / b.totalEvents : b.totalKm
        }))
        .sort((a, b) => b.kmPerEvent - a.kmPerEvent);

      stats.ranking_version = Array.from(versionMap.values())
        .filter(v => v.totalKm >= rankingThreshold)
        .map(v => ({
          label: `${v.brandName} ${v.version}`, brand: v.brandName, brandId: v.brand, version: v.version,
          kmPerEvent: v.totalEvents > 0 ? v.totalKm / v.totalEvents : v.totalKm
        }))
        .sort((a, b) => b.kmPerEvent - a.kmPerEvent);

      stats.ranking_city = Array.from(brandCityMap.values())
        .filter(b => b.km >= rankingThreshold / 2)
        .map(b => ({
          label: b.name, brand: b.name, brandId: b.id,
          kmPerEvent: b.events > 0 ? b.km / b.events : b.km
        }))
        .sort((a, b) => b.kmPerEvent - a.kmPerEvent);

      stats.ranking_highway = Array.from(brandHighwayMap.values())
        .filter(b => b.km >= rankingThreshold / 2)
        .map(b => ({
          label: b.name, brand: b.name, brandId: b.id,
          kmPerEvent: b.events > 0 ? b.km / b.events : b.km
        }))
        .sort((a, b) => b.kmPerEvent - a.kmPerEvent);

      stats.mileage = Array.from(brandMap.values())
        .map(b => ({
          brand: b.name,
          brandKey: b.id,
          totalKm: b.totalKm,
          breakdown: {
            highway: b.mileage_buckets.h80,
            smooth: b.mileage_buckets.m5080,
            urban: b.mileage_buckets.l2050,
            congested: b.mileage_buckets.c20
          }
        }))
        .sort((a, b) => b.totalKm - a.totalKm);

      stats.leaderboard_total = Array.from(userTotalMap.values())
        .sort((a, b) => b.totalKm - a.totalKm)
        .slice(0, 10);

      stats.leaderboard_weekly = Array.from(userWeeklyMap.values())
        .sort((a, b) => b.totalKm - a.totalKm)
        .slice(0, 10);

      // 🆕 周度品牌城区/高速舒适度排名（不限里程）
      stats.ranking_city_weekly = Array.from(brandCityWeeklyMap.values())
        .filter(b => b.km > 0)  // 只要有数据就显示
        .map(b => ({
          label: b.name, brand: b.name, brandId: b.id,
          kmPerEvent: b.events > 0 ? b.km / b.events : b.km
        }))
        .sort((a, b) => b.kmPerEvent - a.kmPerEvent);

      stats.ranking_highway_weekly = Array.from(brandHighwayWeeklyMap.values())
        .filter(b => b.km > 0)  // 只要有数据就显示
        .map(b => ({
          label: b.name, brand: b.name, brandId: b.id,
          kmPerEvent: b.events > 0 ? b.km / b.events : b.km
        }))
        .sort((a, b) => b.kmPerEvent - a.kmPerEvent);

      // 🆕 周度品牌累计里程排名
      stats.mileage_weekly = Array.from(brandWeeklyMap.values())
        .filter(b => b.totalKm > 0)
        .map(b => ({
          brand: b.name,
          brandKey: b.id,
          totalKm: b.totalKm,
          breakdown: {
            highway: b.mileage_buckets.h80,
            smooth: b.mileage_buckets.m5080,
            urban: b.mileage_buckets.l2050,
            congested: b.mileage_buckets.c20
          }
        }))
        .sort((a, b) => b.totalKm - a.totalKm);

      stats.brand_options = Array.from(brandMap.values()).map(b => ({ key: b.id, name: b.name }));

      brandMap.forEach((b, brandId) => {
        stats[`symptoms_${brandId}`] = {
          details: {
            rapidAcceleration: b.event_breakdown.rapidAcceleration > 0 ? b.totalKm / b.event_breakdown.rapidAcceleration : 0,
            rapidDeceleration: b.event_breakdown.rapidDeceleration > 0 ? b.totalKm / b.event_breakdown.rapidDeceleration : 0,
            jerk: b.event_breakdown.jerk > 0 ? b.totalKm / b.event_breakdown.jerk : 0,
            bump: b.event_breakdown.bump > 0 ? b.totalKm / b.event_breakdown.bump : 0,
            wobble: b.event_breakdown.wobble > 0 ? b.totalKm / b.event_breakdown.wobble : 0,
          },
          counts: b.event_breakdown,
          totalKm: b.totalKm,
          tripCount: b.tripCount
        };

        stats[`evolution_${brandId}`] = Array.from(versionMap.values())
          .filter(v => v.brand === brandId)
          .map(v => ({
            version: v.version,
            kmPerEvent: v.totalEvents > 0 ? v.totalKm / v.totalEvents : v.totalKm
          }))
          .sort((a, b) => a.version.localeCompare(b.version, undefined, { numeric: true, sensitivity: 'base' }));
      });

      return stats;
    } catch (e) {
      console.error("Fetch Arena data failed:", e);
      return null;
    }
  }

  static analyzeTrajectory(jsonData: any): { highway: number, smooth: number, urban: number, congested: number, avg: number } {
    const trajectory = jsonData.trajectory || [];
    const buckets = { highway: 0, smooth: 0, urban: 0, congested: 0 };
    let totalDist = 0;
    let totalSpeedSum = 0;
    let validPoints = 0;

    if (trajectory.length < 2) return { ...buckets, avg: 0 };

    const getDistance = (lat1: number, lon1: number, lat2: number, lon2: number) => {
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

        totalDist += dist;
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

  static async repairData(onProgress?: (p: number) => void): Promise<void> {
    try {
      const trips = await pb.collection('trips').getFullList({ requestKey: null });
      if (trips.length === 0) return;

      const globalAcc = new Map<string, any>();
      let analyzedCount = 0;

      for (let i = 0; i < trips.length; i++) {
        const trip = trips[i];
        const userId = trip.user || trip.owner;
        const brandId = trip.brand_ref || trip.brand;
        const versionId = trip.software_version_ref || trip.software_version || trip.version;
        const dataFile = trip.raw_log_file || trip.data_file;

        if (!dataFile || !userId || !brandId || !versionId) continue;

        try {
          const fileUrl = pb.files.getURL(trip, dataFile);
          const response = await fetch(fileUrl);
          const jsonData = await response.json();
          const analysis = this.analyzeTrajectory(jsonData);

          const scenario = analysis.avg >= 50 ? 'highway' : 'city';
          const date = new Date(trip.created.replace(' ', 'T'));
          const monthStr = trip.created.slice(0, 7);
          const weekStr = this.getYearWeek(date);

          const periods = [
            { type: 'all', value: 'total' },
            { type: 'monthly', value: monthStr },
            { type: 'weekly', value: weekStr }
          ];

          periods.forEach(p => {
            const key = `${userId}_${brandId}_${versionId}_${scenario}_${p.type}_${p.value}`;
            if (!globalAcc.has(key)) {
              globalAcc.set(key, {
                highway: 0, smooth: 0, urban: 0, congested: 0,
                total_dist: 0, speed_sum: 0, count: 0
              });
            }
            const acc = globalAcc.get(key);
            acc.highway += analysis.highway;
            acc.smooth += analysis.smooth;
            acc.urban += analysis.urban;
            acc.congested += analysis.congested;
            acc.total_dist += (analysis.highway + analysis.smooth + analysis.urban + analysis.congested);
            acc.speed_sum += analysis.avg;
            acc.count += 1;
          });
          analyzedCount++;
        } catch (e) { }

        if (onProgress) onProgress(Math.floor(((i + 1) / trips.length) * 50));
      }

      const summaryKeys = Array.from(globalAcc.keys());
      for (let j = 0; j < summaryKeys.length; j++) {
        const key = summaryKeys[j];
        const data = globalAcc.get(key);
        const existing = await pb.collection('trip_stats_summary').getFirstListItem(`key="${key}"`, { requestKey: null }).catch(() => null);

        if (existing) {
          await pb.collection('trip_stats_summary').update(existing.id, {
            speed_dist: {
              highway: parseFloat(data.highway.toFixed(2)),
              smooth: parseFloat(data.smooth.toFixed(2)),
              urban: parseFloat(data.urban.toFixed(2)),
              congested: parseFloat(data.congested.toFixed(2)),
              avg: parseFloat((data.speed_sum / data.count).toFixed(2))
            }
          }, { requestKey: null });
        }
        if (onProgress) onProgress(50 + Math.floor(((j + 1) / summaryKeys.length) * 50));
      }
    } catch (e) {
      throw e;
    }
  }

  static async enrichTrips(trips: any[]): Promise<void> {
    if (trips.length === 0) return;
    try {
      const [brands, versions] = await Promise.all([
        pb.collection('brands').getFullList({ fields: 'id,name', requestKey: null }),
        pb.collection('software_versions').getFullList({ fields: 'id,versionString,version_name', requestKey: null })
      ]);

      const brandMap = new Map(brands.map(b => [b.name.toLowerCase(), b.id]));
      const versionMap = new Map();
      versions.forEach(v => {
        if (v.versionString) versionMap.set(v.versionString.toLowerCase(), v.id);
        if (v.version_name) versionMap.set(v.version_name.toLowerCase(), v.id);
      });

      for (const trip of trips) {
        let needsUpdate = false;
        const updateData: any = {};
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
    } catch (e) { }
  }

  static async aggregateAllUserStats(onProgress?: (p: number) => void): Promise<void> {
    try {
      const [users, allTrips] = await Promise.all([
        pb.collection('users').getFullList({ fields: 'id,name,username', requestKey: null }),
        pb.collection('trips').getFullList({
          filter: 'is_public = true',
          fields: 'id,user,owner,metrics,brand',
          requestKey: null
        })
      ]);

      if (onProgress) onProgress(20);
      const userAggregates = new Map<string, any>();

      allTrips.forEach(trip => {
        const userId = trip.user || trip.owner;
        if (!userId) return;
        if (!userAggregates.has(userId)) {
          userAggregates.set(userId, { userId, totalMileage: 0, totalEvents: 0, brandDistribution: {} as Record<string, number> });
        }
        const agg = userAggregates.get(userId);
        const metrics = typeof trip.metrics === 'string' ? JSON.parse(trip.metrics || '{}') : (trip.metrics || {});
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

      if (onProgress) onProgress(50);
      const sortedUsers = Array.from(userAggregates.values()).map(u => ({
        ...u,
        pukedValue: u.totalEvents > 0 ? u.totalMileage / u.totalEvents : u.totalMileage
      })).sort((a, b) => b.pukedValue - a.pukedValue);

      const totalUserCount = sortedUsers.length;
      const globalTotalMileage = Array.from(userAggregates.values()).reduce((acc, u) => acc + u.totalMileage, 0);

      for (let i = 0; i < sortedUsers.length; i++) {
        const u = sortedUsers[i];
        const payload = {
          totalMileage: parseFloat(u.totalMileage.toFixed(2)),
          globalTotalMileage: parseFloat(globalTotalMileage.toFixed(2)),
          totalEvents: u.totalEvents,
          brandDistribution: Object.fromEntries(Object.entries(u.brandDistribution).map(([k, v]) => [k, parseFloat((v as number).toFixed(2))])),
          pukedValue: parseFloat(u.pukedValue.toFixed(2)),
          rank: i + 1,
          totalUsers: totalUserCount,
          updated_at: new Date().toISOString()
        };

        const existing = await pb.collection('user_stats').getFirstListItem(`user_id = "${u.userId}"`, { requestKey: null }).catch(() => null);
        if (existing) {
          await pb.collection('user_stats').update(existing.id, { payload: payload }, { requestKey: null });
        } else {
          await pb.collection('user_stats').create({ user_id: u.userId, payload: payload }, { requestKey: null });
        }
        if (onProgress) onProgress(50 + Math.floor(((i + 1) / sortedUsers.length) * 50));
      }
    } catch (e) {
      throw e;
    }
  }

  static async getRawTripsCount(): Promise<number> {
    try {
      const result = await pb.collection('trips').getList(1, 1, { filter: 'is_public = true', fields: 'id', requestKey: null });
      return result.totalItems;
    } catch (e) {
      return 0;
    }
  }

  static async getSyncState(): Promise<any> {
    try {
      return await pb.collection('stats_state').getFirstListItem('key="current"', { requestKey: null });
    } catch (e) {
      return null;
    }
  }
}
