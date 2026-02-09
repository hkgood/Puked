import { useState, useCallback } from 'react';
import { pb } from '../../../services/pocketbase';
import { useI18n } from '../../../common/utils/i18n';

export const useStatsSync = (loadBasicStats: () => void, loadSummaryData: () => void, showAlert: (title: string, message: string, type?: any) => void) => {
  const { t } = useI18n();
  const [syncing, setSyncing] = useState(false);
  const [currentTaskId, setCurrentTaskId] = useState<string | null>(null);

  /**
   * 🆕 开始轮询任务状态（提取为独立函数）
   */
  const startPollingTask = useCallback((taskId: string) => {
    const pollTaskStatus = async () => {
      try {
        const taskRecord = await pb.collection('sync_tasks').getOne(taskId, { requestKey: null });
        
        if (taskRecord.status === 'success') {
          // 刷新数据
          await loadBasicStats();
          await loadSummaryData();
          
          const summary = taskRecord.result_summary || {};
          const tripsCount = summary.new_trips_processed || 0;
          const duration = summary.duration_seconds || 0;
          
          showAlert(
            t('sync_complete') || '同步完成', 
            `成功处理 ${tripsCount} 个行程，耗时 ${duration} 秒`, 
            'success'
          );
          
          setTimeout(() => {
            setSyncing(false);
            setCurrentTaskId(null);
          }, 5000);
          
          return; // 停止轮询
        } else if (taskRecord.status === 'failed') {
          showAlert(
            t('sync_failed') || '同步失败', 
            taskRecord.error_message || '未知错误', 
            'error'
          );
          
          setSyncing(false);
          setCurrentTaskId(null);
          return; // 停止轮询
        } else if (taskRecord.status === 'cancelled') {
          setSyncing(false);
          setCurrentTaskId(null);
          return; // 停止轮询
        }
        
        // 继续轮询（任务仍在进行中）
        setTimeout(pollTaskStatus, 2000);
        
      } catch (e: any) {
        console.error('[useStatsSync] 轮询任务状态失败:', e);
        setTimeout(pollTaskStatus, 3000);
      }
    };

    setTimeout(pollTaskStatus, 2000);
  }, [loadBasicStats, loadSummaryData, showAlert, t]);

  /**
   * 🆕 检查是否有正在运行的任务（页面加载时调用）
   */
  const checkExistingTask = useCallback(async () => {
    try {
      const existingTask = await pb.collection('sync_tasks').getFirstListItem(
        'task_type = "batch_sync" && (status = "pending" || status = "running")',
        { 
          requestKey: null,
          sort: '-created'
        }
      ).catch(() => null);

      if (existingTask) {
        console.log('[useStatsSync] 🔍 发现正在运行的任务:', existingTask.id);
        setCurrentTaskId(existingTask.id);
        startPollingTask(existingTask.id);
      }
    } catch (e) {
      console.error('[useStatsSync] 检查现有任务失败:', e);
    }
  }, [startPollingTask]);

  /**
   * 创建新任务并开始处理
   */
  const performBatchSync = async () => {
    // 1. 检查是否已有任务在运行
    try {
      const existingTask = await pb.collection('sync_tasks').getFirstListItem(
        'task_type = "batch_sync" && (status = "pending" || status = "running")',
        { requestKey: null }
      ).catch(() => null);

      if (existingTask) {
        showAlert(
          t('sync_in_progress') || '任务进行中', 
          t('sync_already_running') || '已有同步任务正在进行，请等待完成', 
          'info'
        );
        return;
      }
    } catch (e) {
      console.error('[useStatsSync] Failed to check existing tasks:', e);
    }

    // 2. 创建新任务
    setSyncing(true);  // ✅ 显示进度窗口
    
    try {
      const task = await pb.collection('sync_tasks').create({
        task_type: 'batch_sync',
        status: 'pending',
        progress: 0,
        created_by: pb.authStore.model?.id
      }, { requestKey: null });

      setCurrentTaskId(task.id);
      
      console.log('[useStatsSync] ✅ 任务已创建:', task.id);
      showAlert(
        t('task_created') || '任务已创建', 
        t('task_queued') || '任务已加入队列，正在等待处理...', 
        'info'
      );

      // 3. 开始轮询任务状态
      startPollingTask(task.id);

    } catch (e: any) {
      console.error('[useStatsSync] 创建任务失败:', e);
      showAlert(
        t('task_create_failed') || '创建任务失败', 
        e.message || '未知错误', 
        'error'
      );
      setSyncing(false);
      setCurrentTaskId(null);
    }
  };

  /**
   * 🆕 取消/停止任务
   */
  const cancelTask = async () => {
    if (!currentTaskId) {
      showAlert(
        t('no_task') || '无任务',
        t('no_running_task') || '当前没有正在运行的任务',
        'info'
      );
      return;
    }

    try {
      // 将任务状态更新为 cancelled
      await pb.collection('sync_tasks').update(currentTaskId, {
        status: 'cancelled'
      }, { requestKey: null });

      showAlert(
        t('task_cancelled') || '任务已取消',
        t('task_cancel_success') || '任务已标记为取消，后台处理器会在当前批次完成后停止',
        'info'
      );

      // 重置状态
      setSyncing(false);
      setCurrentTaskId(null);
      
    } catch (e: any) {
      showAlert(
        '取消失败',
        e.message || '未知错误',
        'error'
      );
    }
  };

  return { 
    syncing, 
    currentTaskId,
    performBatchSync, 
    cancelTask,
    checkExistingTask,
    setSyncing
  };
};
