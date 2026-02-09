import { useState, useEffect, useCallback, useMemo } from 'react';
import { UserService } from '../services/userService';
import type { UserRecord } from '../../../models/types';
import DataCacheService from '../services/DataCacheService';

export const useDashboardUsers = (
  activeTab: string,
  isSuperAdmin: boolean,
  userFilter: string,
  userSearchQuery: string
) => {
  const [users, setUsers] = useState<UserRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [userPage, setUserPage] = useState(1);
  const [hasMoreUsers, setHasMoreUsers] = useState(true);
  const [userStats, setUserStats] = useState({ all: 0, pending: 0, approved: 0, admin: 0, kol: 0, rejected: 0 });
  const PER_PAGE = 20;

  const loadUsers = useCallback(async (page: number, isMore = false) => {
    if (activeTab !== 'users' || !isSuperAdmin) return;

    if (isMore) setIsLoadingMore(true);
    else setLoading(true);

    try {
      let filters: string[] = [`(brand != "" && brand != "Unknown" && brand != "UNKNOWN")`];

      switch (userFilter) {
        case 'pending': filters.push(`audit_status = "pending"`); break;
        case 'approved': filters.push(`audit_status = "approved"`); break;
        case 'admin': filters.push(`audit_status = "approved" && is_superuser = true`); break;
        case 'kol': filters.push(`audit_status = "approved" && KOL = true`); break;
        case 'rejected': filters.push(`audit_status = "rejected"`); break;
      }

      if (userSearchQuery) {
        const q = userSearchQuery.replace(/"/g, '\\"');
        filters.push(`(name ~ "${q}" || username ~ "${q}" || email ~ "${q}")`);
      }

      const filterStr = filters.join(' && ');
      const [result, stats] = await Promise.all([
        UserService.getUsersList(page, PER_PAGE, filterStr),
        UserService.getUserStats(userSearchQuery)
      ]);

      if (isMore) setUsers(prev => [...prev, ...result.items]);
      else setUsers(result.items);

      setHasMoreUsers(result.items.length < result.totalItems);
      setUserStats(stats);
      setUserPage(page);
    } catch (e) {
      console.error('[useDashboardUsers] Failed to load users:', e);
    } finally {
      setLoading(false);
      setIsLoadingMore(false);
    }
  }, [activeTab, isSuperAdmin, userFilter, userSearchQuery]);

  useEffect(() => {
    // 当过滤条件变化时，立即清空列表并显示加载状态
    setUsers([]);
    loadUsers(1);
  }, [loadUsers]);

  const loadMore = useCallback(() => {
    if (hasMoreUsers && !isLoadingMore) {
      loadUsers(userPage + 1, true);
    }
  }, [hasMoreUsers, isLoadingMore, loadUsers, userPage]);

  const refresh = useCallback(() => loadUsers(1), [loadUsers]);

  return {
    users,
    loading,
    isLoadingMore,
    hasMoreUsers,
    userStats,
    loadMore,
    refresh,
    setUsers
  };
};
