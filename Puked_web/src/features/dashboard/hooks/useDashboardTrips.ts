import { useState, useEffect, useCallback } from 'react';
import { TripService } from '../services/tripService';
import { pb } from '../../../services/pocketbase';

export const useDashboardTrips = (
  activeTab: string,
  isSuperAdmin: boolean,
  currentUser: any,
  tripFilter: string,
  tripSearchQuery: string,
  filterBrand: string,
  filterVersion: string,
  filterSpeedRange: string,
  filterStartDate: string,
  filterEndDate: string
) => {
  const [trips, setTrips] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [tripPage, setTripPage] = useState(1);
  const [hasMoreTrips, setHasMoreTrips] = useState(true);
  const [tripStats, setTripStats] = useState({ all: 0, public: 0, pending: 0 });
  const PER_PAGE = 20;

  /**
   * 核心函数：构建过滤条件
   * 现在的策略：如果存在搜索词，先查用户 ID，再组合成不带 '.' 的扁平过滤语句，彻底规避 400 错误
   */
  const buildFilters = useCallback(async (extraCondition?: string) => {
    const params: any = {};
    const conditions: string[] = [];

    // 1. 基础权限条件
    if (!isSuperAdmin) {
      conditions.push('user = {:currUserId}');
      params.currUserId = currentUser?.id;
    }

    // 2. 状态条件
    if (extraCondition) {
      conditions.push(extraCondition);
    } else if (tripFilter === 'public') {
      conditions.push('is_public = true');
    } else if (tripFilter === 'pending') {
      conditions.push('is_public = false');
    }

    // 3. 基础属性过滤 (brand, version, date)
    if (filterBrand !== 'all') {
      conditions.push('brand = {:brand}');
      params.brand = filterBrand;
    }
    if (filterVersion !== 'all') {
      conditions.push('software_version = {:version}');
      params.version = filterVersion;
    }
    if (filterStartDate) {
      conditions.push('created >= {:start}');
      params.start = `${filterStartDate} 00:00:00`;
    }
    if (filterEndDate) {
      conditions.push('created <= {:end}');
      params.end = `${filterEndDate} 23:59:59`;
    }

    // 4. 处理搜索词 (关键修复)
    if (tripSearchQuery && tripSearchQuery.trim()) {
      const q = tripSearchQuery.trim();
      params.q = q;
      
      const searchParts = ['brand ~ {:q}', 'car_model ~ {:q}'];

      try {
        // 先查符合的用户名 ID，避免直接在 trips 过滤里穿透 user.name (这是 400 的根源)
        const matchedUsers = await pb.collection('users').getFullList({
          filter: pb.filter('name ~ {:q} || username ~ {:q}', { q }),
          fields: 'id',
          requestKey: null
        });

        if (matchedUsers.length > 0) {
          const userConditions = matchedUsers.map((u, i) => {
            const key = `u${i}`;
            params[key] = u.id;
            return `user = {:${key}}`;
          });
          searchParts.push(...userConditions);
        }
      } catch (e) {
        console.warn('[Search] Failed to fetch matched users, fallback to text search only.');
      }

      conditions.push(`(${searchParts.join(' || ')})`);
    }

    if (conditions.length === 0) return undefined;
    return pb.filter(conditions.join(' && '), params);
  }, [isSuperAdmin, currentUser?.id, tripFilter, filterBrand, filterVersion, filterStartDate, filterEndDate, tripSearchQuery]);

  const refreshTripStats = useCallback(async () => {
    try {
      const options = { expand: 'user', requestKey: null };
      
      // 这里的 buildFilters 现在是 async 了
      const [allFilter, pubFilter, pendingFilter] = await Promise.all([
        buildFilters(),
        buildFilters('is_public = true'),
        buildFilters('is_public = false')
      ]);

      const [all, pub, pending] = await Promise.all([
        pb.collection('trips').getList(1, 1, { ...options, filter: allFilter }),
        pb.collection('trips').getList(1, 1, { ...options, filter: pubFilter }),
        pb.collection('trips').getList(1, 1, { ...options, filter: pendingFilter }),
      ]);
      setTripStats({ all: all.totalItems, public: pub.totalItems, pending: pending.totalItems });
    } catch (e) {
      console.error('[refreshTripStats] Error:', e);
    }
  }, [buildFilters]);

  const loadTrips = useCallback(async (page: number, isMore = false) => {
    if (activeTab !== 'trips') return;

    if (isMore) setIsLoadingMore(true);
    else setLoading(true);

    try {
      const filterStr = await buildFilters();
      const [result] = await Promise.all([
        TripService.getTripsList(page, PER_PAGE, filterStr),
        refreshTripStats()
      ]);

      if (isMore) setTrips(prev => [...prev, ...result.items]);
      else setTrips(result.items);

      setHasMoreTrips(result.items.length < result.totalItems);
      setTripPage(page);
    } catch (e) {
      console.error('[useDashboardTrips] Failed to load trips:', e);
    } finally {
      setLoading(false);
      setIsLoadingMore(false);
    }
  }, [activeTab, buildFilters, refreshTripStats]);

  useEffect(() => {
    setTrips([]);
    loadTrips(1);
  }, [loadTrips]);

  const loadMore = useCallback(() => {
    if (hasMoreTrips && !isLoadingMore) {
      loadTrips(tripPage + 1, true);
    }
  }, [hasMoreTrips, isLoadingMore, loadTrips, tripPage]);

  const refresh = useCallback(() => loadTrips(1), [loadTrips]);

  return {
    trips,
    loading,
    isLoadingMore,
    hasMoreTrips,
    tripStats,
    loadMore,
    refresh,
    setTrips
  };
};
