import React from 'react';
import { Database, Activity, User, Image as ImageIcon, Trash2, Zap, RefreshCcw, Clock } from 'lucide-react';
import { useI18n } from '../../../../../common/utils/i18n';

interface StatsHeaderProps {
  onRepairData: () => void;
  onUserStatsAggregation: () => void;
  onCompressModalOpen: () => void;
  onReset: () => void;
  onBatchSync: () => void;
  onSettingsModalOpen: () => void;
  syncing: boolean;
  isCompressing: boolean;
}

const StatsHeader: React.FC<StatsHeaderProps> = ({
  onRepairData,
  onUserStatsAggregation,
  onCompressModalOpen,
  onReset,
  onBatchSync,
  onSettingsModalOpen,
  syncing,
  isCompressing
}) => {
  const { t } = useI18n();

  return (
    <div className="flex flex-row items-center justify-between gap-4">
      <div className="flex items-center gap-2 sm:gap-3">
        <Database className="text-[#007AFF] shrink-0 w-6 h-6 sm:w-7 sm:h-7" />
        <h1 className="text-xl sm:text-3xl font-black text-[#1D1D1F] tracking-tighter truncate">
          {t('arena_data_management')}.
        </h1>
      </div>

      <div className="flex items-center gap-2">
        <button
          onClick={onRepairData}
          className="p-2 sm:p-3 bg-white text-amber-500 rounded-xl sm:rounded-2xl hover:bg-amber-50 transition-all shadow-sm active:scale-95"
          title="Repair Average Speed Data"
        >
          <Activity className="w-[18px] h-[18px] sm:w-5 sm:h-5" />
        </button>
        <button
          onClick={onUserStatsAggregation}
          className="p-2 sm:p-3 bg-white text-[#007AFF] rounded-xl sm:rounded-2xl hover:bg-[#007AFF]/5 transition-all shadow-sm active:scale-95"
          title="Aggregate All User Stats"
        >
          <User className="w-[18px] h-[18px] sm:w-5 sm:h-5" />
        </button>
        <button
          onClick={onCompressModalOpen}
          className="p-2 sm:p-3 bg-white text-blue-500 rounded-xl sm:rounded-2xl hover:bg-blue-50 transition-all shadow-sm active:scale-95"
          title={t('compress_images')}
          disabled={isCompressing}
        >
          {isCompressing ? (
            <div className="w-[18px] h-[18px] sm:w-5 sm:h-5 border-2 border-blue-200 border-t-blue-500 rounded-full animate-spin"></div>
          ) : (
            <ImageIcon className="w-[18px] h-[18px] sm:w-5 sm:h-5" />
          )}
        </button>
        <button
          onClick={onReset}
          className="p-2 sm:p-3 bg-white text-[#FF3B30] rounded-xl sm:rounded-2xl hover:bg-[#FF3B30]/5 transition-all shadow-sm active:scale-95"
          title={t('reset_data')}
        >
          <Trash2 className="w-[18px] h-[18px] sm:w-5 sm:h-5" />
        </button>
        <button
          onClick={onBatchSync}
          disabled={syncing}
          className="flex items-center gap-2 px-4 sm:px-8 py-3 sm:py-4 bg-[#1D1D1F] text-white rounded-xl sm:rounded-2xl font-black uppercase tracking-widest text-[10px] sm:text-[12px] hover:bg-[#007AFF] transition-all shadow-xl active:scale-95 disabled:opacity-50 whitespace-nowrap"
        >
          {syncing ? <RefreshCcw className="w-3.5 h-3.5 sm:w-[18px] sm:h-[18px] animate-spin" /> : <Zap className="w-3.5 h-3.5 sm:w-[18px] sm:h-[18px]" fill="currentColor" />}
          <span>{syncing ? t('computing') : t('trigger_induction')}</span>
        </button>
        <button
          onClick={onSettingsModalOpen}
          className="p-2 sm:p-3 bg-white text-[#1D1D1F] rounded-xl sm:rounded-2xl hover:bg-gray-50 transition-all shadow-sm active:scale-95"
          title={t('auto_scan_settings')}
        >
          <Clock className="w-[18px] h-[18px] sm:w-5 sm:h-5" />
        </button>
      </div>
    </div>
  );
};

export default StatsHeader;
