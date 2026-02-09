import React, { useState, useEffect } from 'react';
import { RefreshCcw, CheckCircle2, AlertCircle, TrendingUp } from 'lucide-react';
import { useI18n } from '../../../../../common/utils/i18n';
import { pb } from '../../../../../services/pocketbase';
import TaskDetailModal from './TaskDetailModal';

interface TaskStatusCardProps {
  currentTaskId: string | null;
  onCancel: () => void;
}

const TaskStatusCard: React.FC<TaskStatusCardProps> = ({
  currentTaskId,
  onCancel
}) => {
  const { t } = useI18n();
  const [task, setTask] = useState<any>(null);
  const [showDetailModal, setShowDetailModal] = useState(false);

  // 定期获取任务详情
  useEffect(() => {
    if (!currentTaskId) {
      setTask(null);
      return;
    }

    const fetchTask = async () => {
      try {
        const taskRecord = await pb.collection('sync_tasks').getOne(currentTaskId, { requestKey: null });
        setTask(taskRecord);
      } catch (e) {
        console.error('[TaskStatusCard] Failed to fetch task:', e);
      }
    };

    fetchTask();
    const interval = setInterval(fetchTask, 3000); // 每3秒更新

    return () => clearInterval(interval);
  }, [currentTaskId]);

  if (!currentTaskId || !task) {
    return null; // 没有任务时不显示
  }

  const getStatusIcon = () => {
    if (task.status === 'success') return <CheckCircle2 size={32} className="text-green-500" />;
    if (task.status === 'failed') return <AlertCircle size={32} className="text-red-500" />;
    if (task.status === 'cancelled') return <AlertCircle size={32} className="text-gray-500" />;
    return <RefreshCcw size={32} className="animate-spin text-[#007AFF]" />;
  };

  const getStatusText = () => {
    if (task.status === 'pending') return t('task_queued') || '任务排队中';
    if (task.status === 'running') return t('sync_analyzing') || '数据分析中';
    if (task.status === 'success') return t('sync_complete') || '同步完成';
    if (task.status === 'failed') return t('sync_failed') || '同步失败';
    if (task.status === 'cancelled') return '已取消';
    return t('global_processing') || '处理中';
  };

  // 任务长时间处于 pending 且无进度时，提示可能是后台服务未运行
  const createdMs = task.created ? new Date(task.created).getTime() : 0;
  const stuckPending = task.status === 'pending' && (task.progress || 0) === 0 && createdMs && (Date.now() - createdMs > 90000);

  return (
    <>
      <div
        className="bg-white p-6 rounded-[2rem] shadow-sm border border-gray-100 md:col-span-2 cursor-pointer hover:shadow-lg transition-all active:scale-[0.98] relative overflow-hidden group flex flex-col"
        onClick={() => setShowDetailModal(true)}
      >
        {/* 背景装饰 */}
        <div className="absolute top-0 right-0 p-4 opacity-5 group-hover:scale-110 transition-transform">
          <TrendingUp size={80} />
        </div>

        {/* 🆕 顶部标题 - 与其他卡片对齐 */}
        <p className="text-muted text-[10px] font-black uppercase tracking-widest mb-2">
          {t('task_processor') || '后台任务处理器'}
        </p>

        {/* 状态行 */}
        <div className="flex justify-between items-center mb-4">
          <div className="flex items-center gap-3">
            <div className="bg-blue-50 p-3 rounded-xl">
              {getStatusIcon()}
            </div>
            <h3 className="text-lg font-black text-[#1D1D1F] leading-tight">{getStatusText()}</h3>
          </div>
          <div className="text-right">
            <p className="text-muted text-[9px] font-bold uppercase tracking-wider mb-1">进度</p>
            <p className="text-3xl font-black text-[#007AFF]">{task.progress || 0}%</p>
          </div>
        </div>

        {/* 进度条 */}
        <div className="relative h-2 bg-[#F5F5F7] rounded-full overflow-hidden">
          <div
            className="h-full bg-gradient-to-r from-[#007AFF] to-[#5856D6] transition-all duration-500"
            style={{ width: `${task.progress || 0}%` }}
          ></div>
        </div>

        {/* 长时间无进度时提示：后台服务可能未运行 */}
        {stuckPending && (
          <div className="mt-3 px-3 py-2 rounded-xl bg-amber-50 border border-amber-200 text-amber-800 text-xs font-medium">
            {t('task_processor_stuck_hint') || '任务一直未开始，可能是后台任务服务未运行。请检查部署环境中的 task-processor 日志（如 task_processor_error.log）或联系管理员。'}
          </div>
        )}

        {/* 🆕 使用 flex-grow 推到底部 */}
        <div className="flex-grow"></div>

        {/* 🆕 底部信息 - 确保与其他卡片对齐 */}
        <div className="h-[23px] flex items-center justify-between text-[10px] font-bold text-muted">
          <div className="flex items-center gap-2">
            <span>
              {t('processing_trips') || '处理行程'}: <span className="text-[#1D1D1F]">{task.processed_count || 0}/{task.total_count || 0}</span>
            </span>
            <span className="text-gray-300">|</span>
            <span>
              {t('batch_progress') || '批次进度'}: <span className="text-[#1D1D1F]">{task.current_batch || 0}/{task.total_batches || 0}</span>
            </span>
          </div>
          <div className="uppercase tracking-tighter">
            点击查看详情
          </div>
        </div>
      </div>

      {/* 详情弹窗 */}
      {showDetailModal && (
        <TaskDetailModal
          task={task}
          onClose={() => setShowDetailModal(false)}
          onCancel={onCancel}
        />
      )}
    </>
  );
};

export default TaskStatusCard;
