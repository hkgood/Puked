import React, { useState, useEffect } from 'react';
import { Clock, Power } from 'lucide-react';
import { useI18n } from '../../../../../common/utils/i18n';
import { formatDistanceToNow } from 'date-fns';
import { zhCN, enUS } from 'date-fns/locale';

export interface StatsSettingsPayload {
  scanInterval: number;
  enableAutoSync: boolean;
}

interface StatsSettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  scanInterval: number;
  setScanInterval: (value: number) => void;
  onSave: (payload: StatsSettingsPayload) => void;
  isSubmitting: boolean;
  enableAutoSync?: boolean;
  lastAutoSyncTime?: string | null;
  lastAutoSyncStatus?: 'success' | 'failed' | 'running' | 'pending';
}

const StatsSettingsModal: React.FC<StatsSettingsModalProps> = ({
  isOpen,
  onClose,
  scanInterval,
  setScanInterval,
  onSave,
  isSubmitting,
  enableAutoSync = true,
  lastAutoSyncTime,
  lastAutoSyncStatus = 'pending'
}) => {
  const { t } = useI18n();
  const [localEnableAutoSync, setLocalEnableAutoSync] = useState(enableAutoSync);

  useEffect(() => {
    setLocalEnableAutoSync(enableAutoSync);
  }, [enableAutoSync]);

  if (!isOpen) return null;

  // 格式化上次同步时间
  const formatSyncTime = () => {
    if (!lastAutoSyncTime) return t('never_synced') || '从未同步';
    try {
      const syncDate = new Date(lastAutoSyncTime.replace(' ', 'T'));
      const locale = t('locale') === 'zh' ? zhCN : enUS;
      return formatDistanceToNow(syncDate, { addSuffix: true, locale });
    } catch (e) {
      return lastAutoSyncTime;
    }
  };

  // 状态图标和文本
  const getStatusInfo = () => {
    switch (lastAutoSyncStatus) {
      case 'success':
        return { icon: '✅', text: t('sync_success') || '同步成功', color: 'text-green-600' };
      case 'failed':
        return { icon: '❌', text: t('sync_failed') || '同步失败', color: 'text-red-600' };
      case 'running':
        return { icon: '🔄', text: t('syncing') || '同步中...', color: 'text-blue-600' };
      default:
        return { icon: '⏸️', text: t('pending_sync') || '等待同步', color: 'text-gray-600' };
    }
  };

  const statusInfo = getStatusInfo();

  return (
    <div className="fixed inset-0 z-[5000] flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-white/60 backdrop-blur-xl animate-in fade-in duration-300" onClick={onClose}></div>
      <div className="relative w-full max-w-sm bg-white rounded-[2.5rem] shadow-2xl border border-gray-100 p-8 space-y-6 animate-in zoom-in duration-300">
        <div className="flex flex-col items-center text-center space-y-4">
          <div className="w-16 h-16 bg-[#F5F5F7] text-[#1D1D1F] rounded-2xl flex items-center justify-center">
            <Clock size={32} />
          </div>
          <div className="space-y-2">
            <h3 className="text-xl font-black text-[#1D1D1F] tracking-tight">{t('auto_scan_settings')}</h3>
            <p className="text-xs font-bold text-muted uppercase tracking-widest">{t('verified_by_engine')}</p>
          </div>
        </div>

        {/* 🆕 自动同步状态显示 */}
        <div className="space-y-3 p-4 bg-[#F5F5F7] rounded-2xl">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-black text-muted uppercase tracking-widest">{t('auto_sync_status')}</span>
            <span className={`text-xs font-bold ${statusInfo.color} flex items-center gap-1`}>
              <span>{statusInfo.icon}</span>
              <span>{statusInfo.text}</span>
            </span>
          </div>
          {lastAutoSyncTime && (
            <div className="text-[10px] font-medium text-muted text-center">
              {t('last_auto_sync')}: {formatSyncTime()}
            </div>
          )}
        </div>

        {/* 🆕 自动同步开关 */}
        <div className="flex items-center justify-between p-4 bg-[#F5F5F7] rounded-2xl">
          <div className="flex items-center gap-2">
            <Power size={16} className="text-muted" />
            <span className="text-xs font-black text-[#1D1D1F]">{t('enable_auto_sync')}</span>
          </div>
          <button
            onClick={() => setLocalEnableAutoSync(!localEnableAutoSync)}
            className={`relative w-12 h-6 rounded-full transition-colors ${
              localEnableAutoSync ? 'bg-[#007AFF]' : 'bg-gray-300'
            }`}
          >
            <div
              className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-transform ${
                localEnableAutoSync ? 'translate-x-7' : 'translate-x-1'
              }`}
            />
          </button>
        </div>

        <div className="space-y-4">
          <div className="space-y-2">
            <label className="text-[10px] font-black text-muted uppercase tracking-widest ml-1">{t('scan_interval')}</label>
            <div className="flex items-center gap-3 bg-[#F5F5F7] p-4 rounded-2xl">
              <input
                type="range"
                min="5"
                max="1440"
                step="5"
                value={scanInterval}
                onChange={(e) => setScanInterval(parseInt(e.target.value))}
                disabled={!localEnableAutoSync}
                className={`flex-1 accent-[#007AFF] ${!localEnableAutoSync ? 'opacity-50' : ''}`}
              />
              <div className="flex items-baseline gap-1 min-w-[60px] justify-end">
                <span className="text-lg font-black text-[#1D1D1F]">{scanInterval}</span>
                <span className="text-[10px] font-bold text-muted uppercase">{t('minutes_unit')}</span>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-4 gap-2">
            {[15, 30, 60, 360].map(val => (
              <button
                key={val}
                onClick={() => setScanInterval(val)}
                disabled={!localEnableAutoSync}
                className={`py-2 rounded-xl text-[10px] font-black transition-all ${
                  scanInterval === val ? 'bg-[#1D1D1F] text-white' : 'bg-[#F5F5F7] text-muted'
                } ${!localEnableAutoSync ? 'opacity-50 cursor-not-allowed' : ''}`}
              >
                {val < 60 ? `${val}m` : `${val / 60}h`}
              </button>
            ))}
          </div>
        </div>

        <div className="flex gap-3 pt-2">
          <button
            onClick={onClose}
            className="flex-1 py-4 bg-[#F5F5F7] text-[#1D1D1F] rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-gray-200 transition-all active:scale-95"
          >
            {t('global_cancel')}
          </button>
          <button
            onClick={() => onSave({ scanInterval, enableAutoSync: localEnableAutoSync })}
            disabled={isSubmitting}
            className="flex-1 py-4 bg-[#1D1D1F] text-white rounded-2xl font-black uppercase tracking-widest text-[10px] shadow-lg active:scale-95 transition-all hover:bg-[#007AFF] disabled:opacity-50"
          >
            {t('save_settings')}
          </button>
        </div>
      </div>
    </div>
  );
};

export default StatsSettingsModal;
