import React, { useEffect, useState } from 'react';
import { X, RefreshCcw, CheckCircle2, AlertCircle, Clock, Calendar, Layers, TrendingUp, XCircle, Activity, MapPin } from 'lucide-react';
import { useI18n } from '../../../../../common/utils/i18n';
import { pb } from '../../../../../services/pocketbase';

interface TaskDetailModalProps {
  task?: any;
  taskId?: string;
  onClose: () => void;
  onCancel: () => void;
}

const TaskDetailModal: React.FC<TaskDetailModalProps> = ({
  task: externalTask,
  taskId,
  onClose,
  onCancel
}) => {
  const { t } = useI18n();
  const [task, setTask] = useState<any>(externalTask || null);

  // 自动获取任务数据
  useEffect(() => {
    if (externalTask) {
      setTask(externalTask);
      return;
    }

    if (!taskId) return;

    const fetchTask = async () => {
      try {
        const taskRecord = await pb.collection('sync_tasks').getOne(taskId, { requestKey: null });
        setTask(taskRecord);
      } catch (e) {
        console.error('[TaskDetailModal] Failed to fetch task:', e);
      }
    };

    fetchTask();
    const interval = setInterval(fetchTask, 2000); // 每2秒更新

    return () => clearInterval(interval);
  }, [externalTask, taskId]);

  if (!task) return null;

  const getStatusIcon = () => {
    // 🆕 默认大小32，通过 cloneElement 可以动态修改
    if (task.status === 'success') return <CheckCircle2 className="text-green-500" />;
    if (task.status === 'failed') return <AlertCircle className="text-red-500" />;
    return <RefreshCcw className="animate-spin text-[#007AFF]" />;
  };

  const getStatusText = () => {
    if (task.status === 'pending') return t('task_queued') || '任务排队中';
    if (task.status === 'running') return t('sync_analyzing') || '数据分析中';
    if (task.status === 'success') return t('sync_complete') || '同步完成';
    if (task.status === 'failed') return t('sync_failed') || '同步失败';
    if (task.status === 'cancelled') return '已取消';
    return t('global_processing') || '处理中';
  };

  const getStatusColor = () => {
    if (task.status === 'success') return 'text-green-500 bg-green-50 border-green-200';
    if (task.status === 'failed') return 'text-red-500 bg-red-50 border-red-200';
    if (task.status === 'cancelled') return 'text-gray-500 bg-gray-50 border-gray-200';
    return 'text-[#007AFF] bg-blue-50 border-blue-200';
  };

  const formatDate = (dateString: string) => {
    if (!dateString) return '-';
    try {
      return new Date(dateString).toLocaleString('zh-CN', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      });
    } catch {
      return dateString;
    }
  };

  const handleCancel = () => {
    if (window.confirm(t('task_cancel_confirm') || '确定要取消当前任务吗？')) {
      onCancel();
      onClose();
    }
  };

  return (
    <div className="fixed inset-0 z-[5000] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="relative w-full max-w-xl bg-white rounded-[2rem] shadow-2xl border border-gray-100 animate-in zoom-in duration-300">
        
        {/* 🆕 关闭按钮 - 与左侧padding保持一致 */}
        <button
          onClick={onClose}
          className="absolute top-5 right-5 p-1.5 rounded-full hover:bg-gray-100 transition-colors z-10"
        >
          <X size={20} className="text-gray-500" />
        </button>

        {/* 🆕 简化头部 - 移除进度百分比 */}
        <div className="p-5 pb-4 border-b border-gray-100">
          <div className="flex items-center gap-3">
            <div className={`p-2.5 rounded-xl border ${getStatusColor()}`}>
              {React.cloneElement(getStatusIcon() as any, { size: 32 })}
            </div>
            <div className="flex-1">
              <h2 className="text-lg font-black text-[#1D1D1F]">
                {t('task_details') || '任务详情'}
              </h2>
              <p className="text-muted text-xs font-semibold">{getStatusText()}</p>
            </div>
          </div>
        </div>

        {/* 🆕 主要进度区 - 三列布局 */}
        <div className="p-5 py-4 border-b border-gray-100">
          <div className="h-2.5 bg-gray-100 rounded-full overflow-hidden mb-4">
            <div
              className="h-full bg-gradient-to-r from-[#007AFF] to-[#5856D6] transition-all duration-500"
              style={{ width: `${task.progress || 0}%` }}
            ></div>
          </div>

          <div className="grid grid-cols-3 gap-4 mb-3">
            {/* 🆕 进度百分比 */}
            <div className="flex items-center gap-3">
              <div className="p-2 bg-gradient-to-br from-blue-50 to-purple-50 rounded-lg">
                <Activity size={20} className="text-[#007AFF]" />
              </div>
              <div className="flex-1">
                <p className="text-muted text-[9px] font-bold uppercase tracking-wider">
                  {t('progress') || '进度'}
                </p>
                <p className="text-base font-black text-[#007AFF]">
                  {task.progress || 0}%
                </p>
              </div>
            </div>

            {/* 处理行程 */}
            <div className="flex items-center gap-3">
              <div className="p-2 bg-green-50 rounded-lg">
                <MapPin size={20} className="text-green-600" />
              </div>
              <div className="flex-1">
                <p className="text-muted text-[9px] font-bold uppercase tracking-wider">
                  {t('processing_trips') || '处理行程'}
                </p>
                <p className="text-base font-black text-[#1D1D1F]">
                  {task.processed_count || 0} <span className="text-muted text-[10px]">/ {task.total_count || 0}</span>
                </p>
              </div>
            </div>

            {/* 批次进度 */}
            <div className="flex items-center gap-3">
              <div className="p-2 bg-purple-50 rounded-lg">
                <Layers size={20} className="text-[#5856D6]" />
              </div>
              <div className="flex-1">
                <p className="text-muted text-[9px] font-bold uppercase tracking-wider">
                  {t('batch_progress') || '批次进度'}
                </p>
                <p className="text-base font-black text-[#1D1D1F]">
                  {task.current_batch || 0} <span className="text-muted text-[10px]">/ {task.total_batches || 0}</span>
                </p>
              </div>
            </div>
          </div>

          {/* 正在处理的数据日期 */}
          {task.last_processed_time && (
            <div className="bg-gradient-to-r from-blue-50 to-purple-50 rounded-xl p-3 border border-blue-100">
              <div className="flex items-center gap-2">
                <div className="p-1.5 bg-white rounded-lg">
                  <Calendar size={16} className="text-[#007AFF]" />
                </div>
                <div className="flex-1">
                  <p className="text-muted text-[9px] font-bold uppercase tracking-wider">
                    正在处理的数据日期
                  </p>
                  <p className="text-sm font-black text-[#1D1D1F]">
                    {formatDate(task.last_processed_time)}
                  </p>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* 🆕 紧凑时间信息 */}
        <div className="p-5 py-3 border-b border-gray-100">
          <div className="grid grid-cols-2 gap-3">
            <div className="flex items-center gap-3">
              <Calendar size={18} className="text-muted" />
              <div>
                <p className="text-muted text-[9px] font-bold uppercase">创建时间</p>
                <p className="text-[11px] font-semibold text-[#1D1D1F]">{formatDate(task.created)}</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Clock size={18} className="text-muted" />
              <div>
                <p className="text-muted text-[9px] font-bold uppercase">最后更新</p>
                <p className="text-[11px] font-semibold text-[#1D1D1F]">{formatDate(task.updated)}</p>
              </div>
            </div>
          </div>
        </div>

        {/* 🆕 紧凑日志信息（如果有） */}
        {task.detail_log && task.detail_log.length > 0 && (
          <div className="p-5 py-3 border-b border-gray-100 max-h-32 overflow-y-auto">
            <p className="text-muted text-[9px] font-bold uppercase mb-2">处理日志</p>
            <div className="space-y-1">
              {task.detail_log.slice(-5).map((log: any, index: number) => (
                <div key={index} className="flex items-start gap-2 text-[10px]">
                  <span className="text-muted font-mono">{log.timestamp}</span>
                  <span className="text-[#1D1D1F] font-semibold">{log.message}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* 🆕 紧凑操作按钮 */}
        <div className="p-5 flex items-center gap-2">
          {task.status !== 'success' && task.status !== 'failed' && task.status !== 'cancelled' && (
            <button
              onClick={handleCancel}
              className="flex-1 flex items-center justify-center gap-2 px-6 py-3 bg-red-50 text-red-600 rounded-xl text-xs font-black uppercase tracking-wider hover:bg-red-100 transition-all active:scale-95"
            >
              <XCircle size={16} />
              {t('cancel_task') || '取消任务'}
            </button>
          )}

          <button
            onClick={onClose}
            className="flex-1 flex items-center justify-center gap-2 px-6 py-3 bg-gray-100 text-[#1D1D1F] rounded-xl text-xs font-black uppercase tracking-wider hover:bg-gray-200 transition-all active:scale-95"
          >
            关闭
          </button>
        </div>

        {/* 🆕 紧凑提示信息（无边框） */}
        <div className="px-5 pb-5 pt-0">
          <p className="text-muted text-[9px] font-medium text-center">
            {t('can_close_page') || '您可以关闭页面，任务将在后台继续执行'}
          </p>
        </div>
      </div>
    </div>
  );
};

export default TaskDetailModal;
