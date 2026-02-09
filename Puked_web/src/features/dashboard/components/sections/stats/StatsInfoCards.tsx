import React from 'react';
import { Database, BarChart3, ShieldCheck, Clock } from 'lucide-react';
import { useI18n } from '../../../../../common/utils/i18n';
import TaskStatusCard from './TaskStatusCard';

interface StatsInfoCardsProps {
  dashboardStats: {
    rawTotal: number;
    syncedTotal: number;
    inductedTrips: number;
    lastSyncTime: string;
    totalDistance: number;
  };
  activePeriod: string;
  currentTaskId?: string | null;
  onCancelTask?: () => void;
}

const StatsInfoCards: React.FC<StatsInfoCardsProps> = ({
  dashboardStats,
  activePeriod,
  currentTaskId,
  onCancelTask
}) => {
  const { t } = useI18n();

  return (
    <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
      {/* 第1个卡片 - 原始数据 */}
      <div className="bg-white p-6 rounded-[2rem] shadow-sm border border-gray-100 relative overflow-hidden group flex flex-col">
        <div className="absolute top-0 right-0 p-4 opacity-5 group-hover:scale-110 transition-transform"><Database size={80} /></div>
        <p className="text-muted text-[10px] font-black uppercase tracking-widest mb-2">{t('raw_trips')}</p>
        <h3 className="text-4xl font-black text-[#1D1D1F]">{dashboardStats.rawTotal}</h3>
        {/* 🆕 使用 flex-grow 推到底部 */}
        <div className="flex-grow"></div>
        <div className="h-[23px] flex items-center">
          <div className="flex items-center gap-2 text-[10px] font-bold text-green-500 bg-green-50 px-2 py-1 rounded-lg">
            <ShieldCheck size={12} /> {t('verified')}
          </div>
        </div>
      </div>

      {/* 第2个卡片 - 已归纳数据 */}
      <div className="bg-white p-6 rounded-[2rem] shadow-sm border border-gray-100 relative overflow-hidden group flex flex-col">
        <div className="absolute top-0 right-0 p-4 opacity-5 group-hover:scale-110 transition-transform"><BarChart3 size={80} /></div>
        <p className="text-muted text-[10px] font-black uppercase tracking-widest mb-2">{t('inducted_records')}</p>
        <h3 className="text-4xl font-black text-[#1D1D1F]">{dashboardStats.syncedTotal}</h3>
        {/* 🆕 使用 flex-grow 推到底部 */}
        <div className="flex-grow"></div>
        <div className="h-[23px] flex items-center">
          <p className="text-[10px] font-bold text-muted uppercase tracking-tighter">
            {t('grouping_by').replace('{period}', t(activePeriod as any) || activePeriod)}
          </p>
        </div>
      </div>

      {/* 第3-4个卡片（跨2列）- 任务状态（运行时）或 覆盖率健康度（空闲时）*/}
      {currentTaskId && onCancelTask ? (
        <TaskStatusCard currentTaskId={currentTaskId} onCancel={onCancelTask} />
      ) : (
        <div className="bg-white p-6 rounded-[2rem] shadow-sm border border-gray-100 md:col-span-2 flex flex-col">
          <div className="flex justify-between items-start mb-4">
            <div>
              <p className="text-muted text-[10px] font-black uppercase tracking-widest mb-1">{t('coverage_health')}</p>
              <div className="flex items-baseline gap-2">
                <h3 className="text-4xl font-black text-[#1D1D1F]">
                  {dashboardStats.rawTotal > 0 ? ((dashboardStats.inductedTrips / dashboardStats.rawTotal) * 100).toFixed(1) : 0}%
                </h3>
                <span className="text-xs font-bold text-muted uppercase">{t('induction_ratio')}</span>
              </div>
            </div>
            <div className="text-right">
              <p className="text-muted text-[10px] font-black uppercase tracking-widest mb-1">{t('total_distance_summary')}</p>
              <h3 className="text-2xl font-black text-[#007AFF]">{dashboardStats.totalDistance.toFixed(1)} km</h3>
            </div>
          </div>
          <div className="h-2 bg-[#F5F5F7] rounded-full overflow-hidden">
            <div
              className="h-full bg-[#007AFF] transition-all duration-1000"
              style={{ width: `${(dashboardStats.inductedTrips / (dashboardStats.rawTotal || 1)) * 100}%` }}
            ></div>
          </div>
          {/* 🆕 使用 flex-grow 推到底部 */}
          <div className="flex-grow"></div>
          <div className="h-[23px] flex items-center justify-between text-[10px] font-bold text-muted">
            <div className="flex items-center gap-1"><Clock size={12} /> {t('last_sync')}: {dashboardStats.lastSyncTime || t('never_synced')}</div>
            <div className="flex items-center gap-1 uppercase">PROCESS ENGINE V2.0</div>
          </div>
        </div>
      )}
    </div>
  );
};

export default StatsInfoCards;
