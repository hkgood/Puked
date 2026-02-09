import { useState, lazy, Suspense, useCallback, useEffect, useRef, useMemo } from 'react';
import { UserService } from '../services/userService';
import { pb } from '../../../services/pocketbase';
import type { UserRecord } from '../../../models/types';
import { useI18n } from '../../../common/utils/i18n';
import LoadingOverlay from '../../../common/components/LoadingOverlay';

// Hooks
import { useDashboardUsers } from '../hooks/useDashboardUsers';
import { useDashboardTrips } from '../hooks/useDashboardTrips';
import { useTripDetailLoader } from '../hooks/useTripDetailLoader';
import { useDashboardActions } from '../hooks/useDashboardActions';
import { useDashboardFilters } from '../hooks/useDashboardFilters';

// Constants
import { type DashboardTab } from '../config/dashboardConstants';

// Sections (Lazy Loaded)
const UsersSection = lazy(() => import('./sections/UsersSection'));
const TripsSection = lazy(() => import('./sections/TripsSection'));
const TripAnalysisView = lazy(() => import('./sections/TripAnalysisView'));
const BrandVersionManager = lazy(() => import('../../brand_version/components/BrandVersionManager'));
const StatsManager = lazy(() => import('./sections/StatsManager'));

// Modals
import RejectModal from './modals/RejectModal';
import DeleteTripModal from './modals/DeleteTripModal';
import AuditInfoModal from './modals/AuditInfoModal';

const DashboardView = () => {
  const { t } = useI18n();
  const currentUser = pb.authStore.model as unknown as UserRecord;
  const isSuperAdmin = currentUser?.is_superuser === true;

  // 基础状态
  const [activeTab, setActiveTab] = useState<DashboardTab>(isSuperAdmin ? 'stats' : 'trips');
  const [selectedTrip, setSelectedTrip] = useState<any | null>(null);
  const [selectedUser, setSelectedUser] = useState<UserRecord | null>(null);
  const [showMobileDetail, setShowMobileDetail] = useState(false);

  // 弹窗状态
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [showDeleteTripModal, setShowDeleteTripModal] = useState(false);
  const [showAuditInfoModal, setShowAuditInfoModal] = useState(false);
  const [isUserLoading, setIsUserLoading] = useState(false);
  const preloadTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // 图表缩放和位置状态
  const [chartScale, setChartScale] = useState<ChartScale>('full');
  const [scrollPosition, setScrollPosition] = useState(0);

  // 筛选器
  const filters = useDashboardFilters();
  const {
    userFilter, userSearchQuery, tripFilter, tripSearchQuery,
    filterBrand, filterVersion, filterSpeedRange, filterStartDate, filterEndDate
  } = filters;

  // 使用自定义 Hooks
  const {
    users, loading: usersLoading, isLoadingMore: usersLoadingMore, hasMoreUsers,
    userStats, loadMore: loadMoreUsers, refresh: refreshUsers
  } = useDashboardUsers(activeTab, isSuperAdmin, userFilter, userSearchQuery);

  const {
    trips, loading: tripsLoading, isLoadingMore: tripsLoadingMore, hasMoreTrips,
    tripStats, loadMore: loadMoreTrips, refresh: refreshTrips
  } = useDashboardTrips(
    activeTab, isSuperAdmin, currentUser, tripFilter, tripSearchQuery,
    filterBrand, filterVersion, filterSpeedRange, filterStartDate, filterEndDate
  );

  const {
    fullTripData, loadedTripId, isDataLoading, loadingProgress, loadError, supplementalEvents, loadTripDetails
  } = useTripDetailLoader(selectedTrip, false); // autoLoad = false，手动触发加载

  const actions = useDashboardActions(refreshUsers, refreshTrips);
  const {
    isSubmitting, isAuditing, auditResult,
    handleApproveTrip, handleApproveUser, handleRejectUser, handleDeleteTrip, handleForceRefresh, handleUpdateUserSettings,
    handleUnpublishTrip, handleSingleAudit
  } = actions;

  // 存储审核结果（不合理事件）
  const [unreasonableEvents, setUnreasonableEvents] = useState<Record<string, string>>({});

  // 辅助函数：根据当前过滤条件选择下一条记录
  const selectNextTrip = useCallback((currentTripId: string) => {
    const currentIndex = trips.findIndex(t => t.id === currentTripId);
    if (currentIndex === -1) {
      setSelectedTrip(null);
      return;
    }

    // 尝试选择下一条
    if (currentIndex < trips.length - 1) {
      setSelectedTrip(trips[currentIndex + 1]);
    } else if (trips.length > 1) {
      // 如果是最后一条，选择第一条
      setSelectedTrip(trips[0]);
    } else {
      // 如果只有一条，清空选择
      setSelectedTrip(null);
    }
    setUnreasonableEvents({});
  }, [trips]);

  const selectNextUser = useCallback((currentUserId: string) => {
    const currentIndex = users.findIndex(u => u.id === currentUserId);
    if (currentIndex === -1) {
      setSelectedUser(null);
      return;
    }

    // 尝试选择下一条
    if (currentIndex < users.length - 1) {
      setSelectedUser(users[currentIndex + 1]);
    } else if (users.length > 1) {
      // 如果是最后一条，选择第一条
      setSelectedUser(users[0]);
    } else {
      // 如果只有一条，清空选择
      setSelectedUser(null);
    }
  }, [users]);

  // 防抖的图片预加载
  const debouncedPreload = useCallback((user: UserRecord) => {
    if (preloadTimerRef.current) clearTimeout(preloadTimerRef.current);
    preloadTimerRef.current = setTimeout(() => {
      UserService.preloadCertificationImages(user);
    }, 300);
  }, []);

  // 监听用户切换，增加切换时的平滑感
  useEffect(() => {
    if (selectedUser) {
      setIsUserLoading(true);
      const timer = setTimeout(() => setIsUserLoading(false), 400);
      return () => clearTimeout(timer);
    }
  }, [selectedUser?.id]);

  useEffect(() => {
    return () => {
      if (preloadTimerRef.current) clearTimeout(preloadTimerRef.current);
    };
  }, []);

  // 监听过滤条件变化，清空选中项
  useEffect(() => {
    if (activeTab === 'trips') {
      setSelectedTrip(null);
      setUnreasonableEvents({}); // 清空审核结果
      setChartScale('full');
      setScrollPosition(0);
    }
  }, [activeTab, tripFilter, tripSearchQuery, filterBrand, filterVersion, filterSpeedRange, filterStartDate, filterEndDate]);

  useEffect(() => {
    if (activeTab === 'users') {
      setSelectedUser(null);
    }
  }, [activeTab, userFilter, userSearchQuery]);

  // 自动选择第一条记录（trips）
  useEffect(() => {
    if (activeTab === 'trips' && trips.length > 0 && !selectedTrip) {
      setSelectedTrip(trips[0]);
      setUnreasonableEvents({}); // 清空审核结果
      setChartScale('full');
      setScrollPosition(0);
    }
  }, [activeTab, trips, selectedTrip]);

  // 自动选择第一条记录（users）
  useEffect(() => {
    if (activeTab === 'users' && users.length > 0 && !selectedUser) {
      setSelectedUser(users[0]);
    }
  }, [activeTab, users, selectedUser]);

  const brandOptions = useMemo(() => {
    const brands = new Set<string>();
    trips.forEach(t => { if (t.brand && t.brand !== 'Unknown') brands.add(t.brand); });
    return Array.from(brands).sort();
  }, [trips]);

  const versionOptions = useMemo(() => {
    const versions = new Set<string>();
    trips.forEach(t => {
      if (filterBrand === 'all' || t.brand === filterBrand) {
        if (t.software_version && t.software_version !== 'Unknown') versions.add(t.software_version);
      }
    });
    return Array.from(versions).sort();
  }, [trips, filterBrand]);

  return (
    <div className="flex-1 flex flex-col relative h-full bg-white">
      {/* 顶部 Tab 导航 */}
      <div className={`flex-shrink-0 h-16 border-b border-gray-100 flex items-center justify-center px-8 gap-4 bg-white ${showMobileDetail ? 'hidden md:flex' : 'flex'}`}>
        <div className="bg-[#F5F5F7] p-1.5 rounded-2xl flex items-center gap-1 shadow-inner">
          {isSuperAdmin && (
            <button onClick={() => setActiveTab('users')} className={`px-6 py-2 rounded-xl text-xs font-black uppercase transition-all ${activeTab === 'users' ? 'bg-white shadow-sm text-blue-600 scale-105' : 'text-muted hover:text-black'}`}>
              {t('users')}
            </button>
          )}
          <button onClick={() => setActiveTab('trips')} className={`px-6 py-2 rounded-xl text-xs font-black uppercase transition-all ${activeTab === 'trips' ? 'bg-white shadow-sm text-blue-600 scale-105' : 'text-muted hover:text-black'}`}>
            {t('trips')}
          </button>
          {isSuperAdmin && (
            <>
              <button onClick={() => setActiveTab('brands')} className={`px-6 py-2 rounded-xl text-xs font-black uppercase transition-all ${activeTab === 'brands' ? 'bg-white shadow-sm text-blue-600 scale-105' : 'text-muted hover:text-black'}`}>
                {t('brands')}
              </button>
              <button onClick={() => setActiveTab('stats')} className={`px-6 py-2 rounded-xl text-xs font-black uppercase transition-all ${activeTab === 'stats' ? 'bg-white shadow-sm text-blue-600 scale-105' : 'text-muted hover:text-black'}`}>
                {t('stats')}
              </button>
            </>
          )}
        </div>
      </div>

      <div className="flex-1 flex min-h-0 overflow-hidden">
        <Suspense fallback={<LoadingOverlay />}>
          {activeTab === 'users' && isSuperAdmin && (
            <UsersSection
              users={users} selectedUser={selectedUser} setSelectedUser={setSelectedUser}
              userFilter={userFilter} setUserFilter={filters.setUserFilter} userSearchQuery={userSearchQuery} setUserSearchQuery={filters.setUserSearchQuery}
              userStats={userStats} isSuperAdmin={isSuperAdmin} isLoading={usersLoading} isUserLoading={isUserLoading}
              isSubmitting={isSubmitting} hasMoreUsers={hasMoreUsers} isLoadingMore={usersLoadingMore}
              onLoadMore={loadMoreUsers}
              onApprove={async (user) => {
                await handleApproveUser(user);
                selectNextUser(user.id);
              }}
              onReject={() => setShowRejectModal(true)}
              onUpdateUserSettings={async (f, v) => {
                const updated = await handleUpdateUserSettings(selectedUser!.id, f, v);
                if (updated) setSelectedUser(updated);
              }}
              onUpdateUser={(u) => setSelectedUser(u)} debouncedPreload={debouncedPreload}
              showMobileDetail={showMobileDetail} setShowMobileDetail={setShowMobileDetail}
            />
          )}

          {activeTab === 'trips' && (
            <>
              <TripsSection
                trips={trips} selectedTrip={selectedTrip} setSelectedTrip={setSelectedTrip}
                tripFilter={tripFilter} setTripFilter={filters.setTripFilter} tripSearchQuery={tripSearchQuery} setTripSearchQuery={filters.setTripSearchQuery}
                tripStats={tripStats} brandOptions={brandOptions} versionOptions={versionOptions} filterBrand={filterBrand} setFilterBrand={filters.setFilterBrand}
                filterVersion={filterVersion} setFilterVersion={filters.setFilterVersion} filterSpeedRange={filterSpeedRange} setFilterSpeedRange={filters.setFilterSpeedRange}
                filterStartDate={filterStartDate} setFilterStartDate={filters.setFilterStartDate} filterEndDate={filterEndDate} setFilterEndDate={filters.setFilterEndDate}
                pendingTrips={trips.filter(t => !t.is_public)} approvedTrips={trips.filter(t => t.is_public)}
                isPendingCollapsed={false} setIsPendingCollapsed={() => { }}
                isApprovedCollapsed={false} setIsApprovedCollapsed={() => { }}
                isLoading={tripsLoading} isDataLoading={isDataLoading}
                isLoadingMore={tripsLoadingMore} hasMoreTrips={hasMoreTrips} onLoadMore={loadMoreTrips}
                showMobileDetail={showMobileDetail} setShowMobileDetail={setShowMobileDetail}
                suspiciousCountPerTrip={{}} tripSupplementalCounts={{}} supplementalEvents={supplementalEvents}
              />
              <TripAnalysisView
                selectedTrip={selectedTrip}
                fullTripData={fullTripData}
                loadedTripId={loadedTripId}
                isDataLoading={isDataLoading}
                loadingProgress={loadingProgress}
                loadError={loadError}
                supplementalEvents={supplementalEvents}
                chartScale={chartScale}
                scrollPosition={scrollPosition}
                isSuperAdmin={isSuperAdmin}
                currentUser={currentUser}
                isSubmitting={isSubmitting}
                isAuditing={isAuditing}
                unreasonableEvents={unreasonableEvents}
                showMobileDetail={showMobileDetail}
                onBack={() => setShowMobileDetail(false)}
                onApprove={async () => {
                  if (selectedTrip) {
                    const tripId = selectedTrip.id;
                    await handleApproveTrip(tripId);
                    selectNextTrip(tripId);
                  }
                }}
                onReject={() => setShowRejectModal(true)}
                onUnpublish={async () => {
                  if (selectedTrip) {
                    const tripId = selectedTrip.id;
                    const success = await handleUnpublishTrip(tripId);
                    if (success) {
                      selectNextTrip(tripId);
                    }
                  }
                }}
                onDeleteTrip={() => setShowDeleteTripModal(true)}
                onSingleAudit={async () => {
                  if (fullTripData) {
                    const result = await handleSingleAudit(fullTripData);
                    setUnreasonableEvents(result);
                  }
                }}
                onDeleteEvent={(idx) => console.log('Delete event:', idx)}
                onAddSupplemental={(evt) => console.log('Add supplemental:', evt)}
                focusLocation={null}
                setFocusLocation={(loc) => console.log('Focus location:', loc)}
                onForceRefresh={() => selectedTrip && handleForceRefresh(selectedTrip.id)}
                onCompressImages={() => console.log('Compress images')}
                isCompressing={false}
                onLoadTripDetails={loadTripDetails} // 传递手动加载方法
                onChartScaleChange={setChartScale}
                onScrollPositionChange={setScrollPosition}
              />
            </>
          )}

          {activeTab === 'brands' && <BrandVersionManager />}
          {activeTab === 'stats' && <StatsManager />}
        </Suspense>
      </div>

      <RejectModal
        isOpen={showRejectModal} onClose={() => setShowRejectModal(false)}
        onConfirm={async (r) => {
          if (selectedUser) {
            const userId = selectedUser.id;
            const success = await handleRejectUser(userId, r);
            if (success) {
              setShowRejectModal(false);
              selectNextUser(userId);
            }
          }
        }}
        email={selectedUser?.email || ''} isSubmitting={isSubmitting}
      />
      <DeleteTripModal
        isOpen={showDeleteTripModal} onClose={() => setShowDeleteTripModal(false)}
        onConfirm={async () => {
          if (selectedTrip) {
            const tripId = selectedTrip.id;
            const success = await handleDeleteTrip(tripId);
            if (success) {
              setShowDeleteTripModal(false);
              selectNextTrip(tripId);
            }
          }
        }}
        tripName={`${selectedTrip?.brand} ${selectedTrip?.car_model}`} isSubmitting={isSubmitting}
      />
      <AuditInfoModal isOpen={showAuditInfoModal} onClose={() => setShowAuditInfoModal(false)} auditResult={auditResult} />
    </div>
  );
};

export default DashboardView;
