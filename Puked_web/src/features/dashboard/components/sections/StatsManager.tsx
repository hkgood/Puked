import { useState, useEffect, useCallback } from 'react';
import { pb } from '../../../../services/pocketbase';
import { useI18n } from '../../../../common/utils/i18n';
import LoadingOverlay from '../../../../common/components/LoadingOverlay';
import { ArenaService } from '../../../arena/services/arenaService';
import { UserService } from '../../services/userService';

// Sub-components
import StatsSettingsModal, { type StatsSettingsPayload } from './stats/StatsSettingsModal';
import TaskDetailModal from './stats/TaskDetailModal';
import GlobalAlertModal, { type ModalState } from './stats/GlobalAlertModal';
import ImageCompressModal from './stats/ImageCompressModal';
import StatsHeader from './stats/StatsHeader';
import StatsInfoCards from './stats/StatsInfoCards';
import DataExplorerTable from './stats/DataExplorerTable';

// Hooks
import { useStatsSync } from '../../hooks/useStatsSync';

const StatsManager = () => {
  const { t } = useI18n();
  const [loading, setLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [activePeriod, setActivePeriod] = useState<'all' | 'monthly' | 'weekly'>('all');

  // Modal State
  const [modal, setModal] = useState<ModalState>({
    isOpen: false,
    title: '',
    message: '',
    type: 'info'
  });

  const showAlert = useCallback((title: string, message: string, type: ModalState['type'] = 'info') => {
    setModal({ isOpen: true, title, message, type });
  }, []);

  const showConfirm = useCallback((title: string, message: string, onConfirm: () => void, type: ModalState['type'] = 'confirm') => {
    setModal({
      isOpen: true,
      title,
      message,
      type,
      onConfirm,
      confirmText: t('global_confirm') || 'Confirm',
      cancelText: t('global_cancel') || 'Cancel'
    });
  }, [t]);

  const [dashboardStats, setDashboardStats] = useState({
    rawTotal: 0,
    syncedTotal: 0,
    inductedTrips: 0,
    lastSyncTime: '',
    totalDistance: 0,
    // 🆕 新增自动同步相关状态
    enableAutoSync: true,
    lastAutoSyncTime: null as string | null,
    lastAutoSyncStatus: 'pending' as 'success' | 'failed' | 'running' | 'pending',
  });

  const [dataItems, setDataItems] = useState<any[]>([]);
  const [brands, setBrands] = useState<any[]>([]);
  const [limit, setLimit] = useState(20);

  // Settings State
  const [showSettingsModal, setShowSettingsModal] = useState(false);
  const [scanInterval, setScanInterval] = useState(30);

  // Compression State
  const [showCompressModal, setShowCompressModal] = useState(false);
  const [isCompressing, setIsCompressing] = useState(false);
  const [compressProgress, setCompressProgress] = useState({ current: 0, total: 0 });
  const [compressAbortController, setCompressAbortController] = useState<AbortController | null>(null);

  // 1. 加载基础统计信息
  const loadBasicStats = useCallback(async () => {
    try {
      const [rawCount, syncState, allAggregates, library] = await Promise.all([
        ArenaService.getRawTripsCount(),
        ArenaService.getSyncState(),
        pb.collection('trip_stats_summary').getFullList({
          filter: 'period_type="all"',
          fields: 'total_distance,trip_count',
          requestKey: null
        }),
        ArenaService.getBaseLibrary()
      ]);

      setBrands(library.brands);
      const totalDist = allAggregates.reduce((acc, cur) => acc + (cur.total_distance || 0), 0);

      // 计算已归纳行程数量：使用 last_timestamp 统计在此时间点之前的行程
      let inductedCount = 0;
      if (syncState?.last_timestamp) {
        try {
          // 统计 created <= last_timestamp 的行程数量
          const result = await pb.collection('trips').getList(1, 1, {
            filter: `created <= "${syncState.last_timestamp}"`,
            fields: 'id',
            requestKey: null
          });
          inductedCount = result.totalItems;
        } catch (e) {
          console.error('Failed to count inducted trips:', e);
          // 如果失败，回退到使用聚合表的 trip_count
          inductedCount = allAggregates.reduce((acc, cur) => acc + (cur.trip_count || 0), 0);
        }
      }

      setDashboardStats(prev => ({
        ...prev,
        rawTotal: rawCount,
        lastSyncTime: syncState?.last_timestamp || '',
        totalDistance: totalDist,
        inductedTrips: inductedCount,
        // 🆕 读取自动同步状态
        enableAutoSync: syncState?.enable_auto_sync !== false,
        lastAutoSyncTime: syncState?.last_sync_time || null,
        lastAutoSyncStatus: syncState?.last_sync_status || 'pending',
      }));

      if (syncState?.sync_interval) {
        setScanInterval(syncState.sync_interval);
      }
    } catch (e) {
      console.error("Load basic stats failed:", e);
    }
  }, []);

  // 2. 加载明细列表
  const loadSummaryData = useCallback(async () => {
    if (dataItems.length === 0) {
      setLoading(true);
    }
    try {
      const summaryList = await pb.collection('trip_stats_summary').getList(1, limit, {
        filter: `period_type="${activePeriod}"`,
        sort: '-total_distance',
        expand: 'brand,software_version',
        fields: '*,expand.brand.name,expand.brand.logo,expand.software_version.versionString,expand.software_version.version_name',
        requestKey: null
      });

      setDataItems(summaryList.items);
      setDashboardStats(prev => ({
        ...prev,
        syncedTotal: summaryList.totalItems
      }));
    } catch (e) {
      console.error("Load summary data failed:", e);
    } finally {
      setLoading(false);
    }
  }, [activePeriod, limit, dataItems.length]);

  // Sync Hook
  const { syncing, currentTaskId, performBatchSync, cancelTask, checkExistingTask, setSyncing } = useStatsSync(loadBasicStats, loadSummaryData, showAlert);

  // 🆕 页面加载时检查是否有正在运行的任务
  useEffect(() => {
    checkExistingTask();
  }, [checkExistingTask]);

  // 🆕 监听关闭弹窗事件
  useEffect(() => {
    const handleCloseOverlay = () => {
      setSyncing(false);
    };

    window.addEventListener('closeSyncOverlay', handleCloseOverlay);
    return () => window.removeEventListener('closeSyncOverlay', handleCloseOverlay);
  }, [setSyncing]);

  useEffect(() => {
    loadBasicStats();
  }, [loadBasicStats]);

  useEffect(() => {
    loadSummaryData();
  }, [loadSummaryData]);

  const saveScanSettings = async (payload: StatsSettingsPayload) => {
    try {
      setIsSubmitting(true);
      const { scanInterval: nextInterval, enableAutoSync: nextEnableAutoSync } = payload;
      const stateRecord = await pb.collection('stats_state').getFirstListItem('key="current"', { requestKey: null }).catch(() => null);

      const updateData = {
        sync_interval: nextInterval,
        enable_auto_sync: nextEnableAutoSync,
      };

      if (stateRecord) {
        await pb.collection('stats_state').update(stateRecord.id, updateData, { requestKey: null });
      } else {
        await pb.collection('stats_state').create({
          key: 'current',
          ...updateData,
          last_sync_time: null,
          last_sync_status: 'pending',
          last_timestamp: '2000-01-01 00:00:00',
        }, { requestKey: null });
      }

      setScanInterval(nextInterval);
      setDashboardStats(prev => ({ ...prev, enableAutoSync: nextEnableAutoSync }));
      setShowSettingsModal(false);
      showAlert(t('success'), t('settings_saved'), 'success');
    } catch (e: any) {
      showAlert(t('error'), e.message, 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleRepairData = async () => {
    const confirmRepair = await showConfirm(
      t('repair_confirm_title'),
      t('repair_confirm_msg'),
      t('confirm') || '确认',
      t('cancel') || '取消'
    );
    if (!confirmRepair) return;

    try {
      setSyncing(true);
      await ArenaService.repairData(() => { });
      await loadBasicStats();
      await loadSummaryData();
      showAlert(t('repair_complete'), t('repair_summary'), 'success');
    } catch (e: any) {
      console.error(e);
      showAlert(t('error'), e.message, 'error');
    } finally {
      setSyncing(false);
    }
  };

  const handleReset = async () => {
    showConfirm(
      t('reset_warning_title') || "DANGEROUS ACTION",
      t('reset_confirm'),
      async () => {
        setLoading(true);
        try {
          const items = await pb.collection('trip_stats_summary').getFullList({ fields: 'id', requestKey: null });
          for (const item of items) {
            await pb.collection('trip_stats_summary').delete(item.id);
          }
          const states = await pb.collection('stats_state').getFullList({ requestKey: null });
          for (const s of states) {
            await pb.collection('stats_state').delete(s.id);
          }
          const userStats = await pb.collection('user_stats').getFullList({ fields: 'id', requestKey: null });
          for (const us of userStats) {
            await pb.collection('user_stats').delete(us.id);
          }
          await Promise.all([loadBasicStats(), loadSummaryData()]);
          showAlert(t('success'), t('data_cleared'), 'success');
        } catch (e: any) {
          console.error(e);
          showAlert(t('error'), e.message, 'error');
        } finally {
          setLoading(false);
        }
      },
      'warning'
    );
  };

  const handleUserStatsAggregation = async () => {
    const confirmSync = await showConfirm(
      t('user_stats_confirm_title'),
      t('user_stats_confirm_msg'),
      t('confirm') || '确认',
      t('cancel') || '取消'
    );
    if (!confirmSync) return;

    try {
      setSyncing(true);
      await ArenaService.aggregateAllUserStats(() => { });
      showAlert(t('success'), t('user_stats_success'), 'success');
    } catch (e: any) {
      console.error(e);
      showAlert(t('error'), e.message, 'error');
    } finally {
      setSyncing(false);
    }
  };

  const handleCompressAllImages = async () => {
    setShowCompressModal(false);
    setIsCompressing(true);
    setCompressProgress({ current: 0, total: 0 });
    const controller = new AbortController();
    setCompressAbortController(controller);

    try {
      const result = await UserService.compressAllCertificationImages(
        (current, total) => setCompressProgress({ current, total }),
        controller.signal
      );

      if (result.cancelled) {
        showAlert(t('global_cancel'), t('compress_cancel_summary').replace('{processed}', result.totalProcessed.toString()).replace('{compressed}', result.totalCompressed.toString()), 'info');
      } else {
        showAlert(t('success'), t('compress_success').replace('{processed}', result.totalProcessed.toString()).replace('{compressed}', result.totalCompressed.toString()).replace('{skipped}', result.totalSkipped.toString()).replace('{failed}', result.totalFailed.toString()), 'success');
      }
    } catch (e: any) {
      if (e.name === 'AbortError') {
        showAlert(t('global_cancel'), t('compress_cancelled'), 'info');
      } else {
        console.error('压缩失败:', e);
        showAlert(t('error'), t('compress_failed') + ': ' + (e.message || '未知错误'), 'error');
      }
    } finally {
      setIsCompressing(false);
      setCompressProgress({ current: 0, total: 0 });
      setCompressAbortController(null);
    }
  };

  const handleCancelCompress = () => {
    showConfirm(
      t('global_cancel'),
      t('confirm_cancel_compress'),
      () => {
        if (compressAbortController) {
          compressAbortController.abort();
          setIsCompressing(false);
          setCompressProgress({ current: 0, total: 0 });
          setCompressAbortController(null);
        }
      },
      'warning'
    );
  };

  if (loading && !syncing && dataItems.length === 0) {
    return <div className="flex-1 relative"><LoadingOverlay /></div>;
  }

  return (
    <div className="flex-1 overflow-y-auto bg-[#F5F5F7] custom-scrollbar p-4 sm:p-8 pt-4">

      {/* 🆕 使用统一的 TaskDetailModal */}
      {syncing && currentTaskId && (
        <TaskDetailModal
          taskId={currentTaskId}
          onClose={() => setSyncing(false)}
          onCancel={cancelTask}
        />
      )}

      <StatsSettingsModal
        isOpen={showSettingsModal}
        onClose={() => setShowSettingsModal(false)}
        scanInterval={scanInterval}
        setScanInterval={setScanInterval}
        onSave={(payload) => saveScanSettings(payload)}
        isSubmitting={isSubmitting}
        enableAutoSync={dashboardStats.enableAutoSync}
        lastAutoSyncTime={dashboardStats.lastAutoSyncTime}
        lastAutoSyncStatus={dashboardStats.lastAutoSyncStatus}
      />

      <GlobalAlertModal modal={modal} onClose={() => setModal({ ...modal, isOpen: false })} />

      <ImageCompressModal
        showConfirmModal={showCompressModal}
        setShowConfirmModal={setShowCompressModal}
        isCompressing={isCompressing}
        compressProgress={compressProgress}
        onConfirm={handleCompressAllImages}
        onCancel={handleCancelCompress}
      />

      <div className="max-w-6xl mx-auto space-y-8">
        <StatsHeader
          onRepairData={handleRepairData}
          onUserStatsAggregation={handleUserStatsAggregation}
          onCompressModalOpen={() => setShowCompressModal(true)}
          onReset={handleReset}
          onBatchSync={performBatchSync}
          onSettingsModalOpen={() => setShowSettingsModal(true)}
          syncing={syncing}
          isCompressing={isCompressing}
        />

        <StatsInfoCards
          dashboardStats={dashboardStats}
          activePeriod={activePeriod}
          currentTaskId={currentTaskId}
          onCancelTask={cancelTask}
        />

        <DataExplorerTable
          dataItems={dataItems}
          activePeriod={activePeriod}
          setActivePeriod={setActivePeriod}
          brands={brands}
          syncedTotal={dashboardStats.syncedTotal}
          onLoadMore={() => setLimit(prev => prev + 50)}
        />
      </div>
    </div>
  );
};

export default StatsManager;
