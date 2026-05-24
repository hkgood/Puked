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
   * 策略：
   * - 用户名搜索部分（需要查 users 表）由调用方预先拉取，传入 matchedUserIds
   * - 这样 buildFilters 保持同步，避免 3 次并发调用时重复查 users 表
   *
   * @param extraCondition 额外条件
   * @param matchedUserIds 预先查好的用户 ID 列表（来自用户名搜索）
   */
  const buildFilters = useCallback((extraCondition?: string, matchedUserIds?: string[]) => {
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

      // 如果调用方已经预先查好了用户 ID，直接用；否则跳过 users 表搜索
      if (matchedUserIds && matchedUserIds.length > 0) {
        const userConditions = matchedUserIds.map((uid, i) => {
          const key = `u${i}`;
          params[key] = uid;
          return `user = {:${key}}`;
        });
        searchParts.push(...userConditions);
      } else {
        // 没有预查用户时，只搜品牌和车型（避免 400）
        console.warn('[buildFilters] 未传入 matchedUserIds，仅搜索品牌/车型');
      }

      conditions.push(`(${searchParts.join(' || ')})`);
    }

    if (conditions.length === 0) return undefined;
    return pb.filter(conditions.join(' && '), params);
  }, [isSuperAdmin, currentUser?.id, tripFilter, filterBrand, filterVersion, filterStartDate, filterEndDate, tripSearchQuery]);

  /**
   * 预搜索用户名（避免每次 buildFilters 重复查 users 表）
   * @returns matchedUserIds 或 null（无搜索词或搜索失败）
   */
  const prefetchMatchedUserIds = useCallback(async (): Promise<string[] | null> => {
    if (!tripSearchQuery || !tripSearchQuery.trim()) return null;

    const q = tripSearchQuery.trim();
    try {
      const matchedUsers = await pb.collection('users').getFullList({
        filter: pb.filter('name ~ {:q} || username ~ {:q}', { q }),
        fields: 'id',
        requestKey: null
      });
      return matchedUsers.map(u => u.id);
    } catch (e) {
      console.warn('[Search] Failed to fetch matched users, fallback to text search only.');
      return null;
    }
  }, [tripSearchQuery]);

  const refreshTripStats = useCallback(async () => {
    try {
      const options = { expand: 'user', requestKey: null };

      // 关键优化：只查一次 users 表，避免 3× async buildFilters 导致的重复查询
      const matchedUserIds = await prefetchMatchedUserIds();

      const [allFilter, pubFilter, pendingFilter] = [
        buildFilters(undefined, matchedUserIds),
        buildFilters('is_public = true', matchedUserIds),
        buildFilters('is_public = false', matchedUserIds),
      ];

      const [all, pub, pending] = await Promise.all([
        pb.collection('trips').getList(1, 1, { ...options, filter: allFilter }),
        pb.collection('trips').getList(1, 1, { ...options, filter: pubFilter }),
        pb.collection('trips').getList(1, 1, { ...options, filter: pendingFilter }),
      ]);
      setTripStats({ all: all.totalItems, public: pub.totalItems, pending: pending.totalItems });
    } catch (e) {
      console.error('[refreshTripStats] Error:', e);
    }
  }, [buildFilters, prefetchMatchedUserIds]);

  const loadTrips = useCallback(async (page: number, isMore = false) => {
    if (activeTab !== 'trips') return;

    if (isMore) setIsLoadingMore(true);
    else setLoading(true);

    try {
      // 同样预查用户，避免 loadTrips 中 buildFilters 也产生重复查询
      const matchedUserIds = await prefetchMatchedUserIds();
      const filterStr = buildFilters(undefined, matchedUserIds);
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
  }, [activeTab, buildFilters, prefetchMatchedUserIds, refreshTripStats]);

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
