import React from 'react';
import { Search, ShieldCheck, TrendingUp, Database, AlertCircle, ArrowRight } from 'lucide-react';
import { ArenaService } from '../../../../arena/services/arenaService';
import { useI18n } from '../../../../../common/utils/i18n';

interface DataExplorerTableProps {
  dataItems: any[];
  activePeriod: 'all' | 'monthly' | 'weekly';
  setActivePeriod: (period: 'all' | 'monthly' | 'weekly') => void;
  brands: any[];
  syncedTotal: number;
  onLoadMore: () => void;
}

const DataExplorerTable: React.FC<DataExplorerTableProps> = ({
  dataItems,
  activePeriod,
  setActivePeriod,
  brands,
  syncedTotal,
  onLoadMore
}) => {
  const { t } = useI18n();

  return (
    <div className="bg-white rounded-[2.5rem] shadow-sm border border-gray-100 overflow-hidden">
      <div className="p-8 border-b border-gray-50 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Search className="text-muted" size={20} />
          <h2 className="text-xl font-black text-[#1D1D1F] tracking-tight">{t('data_explorer')}.</h2>
        </div>

        <div className="flex bg-[#F5F5F7] p-1 rounded-2xl">
          {(['all', 'monthly', 'weekly'] as const).map((p) => (
            <button
              key={p}
              onClick={() => setActivePeriod(p)}
              className={`px-6 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${activePeriod === p ? 'bg-white shadow-md text-[#007AFF] scale-105' : 'text-muted hover:text-[#1D1D1F]'}`}
            >
              {t(p as any) || p}
            </button>
          ))}
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full text-left border-collapse">
          <thead>
            <tr className="bg-[#F5F5F7]/50 text-muted text-[10px] font-black uppercase tracking-widest">
              <th className="px-8 py-5">{t('entity_brand_version')}</th>
              <th className="px-8 py-5 text-center">{t('version_short')}</th>
              <th className="px-8 py-5">{t('inducted_distance')}</th>
              <th className="px-8 py-5">{t('inducted_events')}</th>
              <th className="px-8 py-5">{t('mpi_analysis')}</th>
              <th className="px-8 py-5">{t('status')}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {dataItems.map((item) => {
              const mpi = item.total_distance / (item.total_events || 1);
              const isLowMpi = mpi < 5;

              const brandDisplayName = item.expand?.brand?.name || item.brandName || item.brand || 'Unknown';
              const logoUrl = ArenaService.getLogoUrl(brands, brandDisplayName);

              return (
                <tr key={item.id} className="hover:bg-[#F5F5F7]/30 transition-colors group">
                  <td className="px-8 py-6">
                    <div className="flex items-center gap-4">
                      <div className="w-10 h-10 bg-[#F5F5F7] rounded-xl flex items-center justify-center shrink-0 group-hover:scale-110 transition-transform">
                        {logoUrl ? (
                          <img src={logoUrl} className="w-6 h-6 object-contain grayscale opacity-50 group-hover:grayscale-0 group-hover:opacity-100" />
                        ) : <ShieldCheck size={16} className="text-gray-300" />}
                      </div>
                      <div>
                        <div className="font-black text-[#1D1D1F] uppercase">{brandDisplayName}</div>
                        <div className="text-[10px] font-bold text-muted">{item.expand?.software_version?.versionString || item.expand?.software_version?.version_name || item.versionName || '---'}</div>
                      </div>
                    </div>
                  </td>
                  <td className="px-8 py-6 text-center font-mono text-[11px] font-bold text-muted">
                    {item.period_value}
                  </td>
                  <td className="px-8 py-6">
                    <div className="font-bold text-[#1D1D1F]">{item.total_distance.toFixed(2)} km</div>
                    <div className="w-24 h-1 bg-gray-100 rounded-full mt-1">
                      <div className="h-full bg-black/10 rounded-full" style={{ width: `${Math.min(100, (item.total_distance / 1000) * 100)}%` }}></div>
                    </div>
                  </td>
                  <td className="px-8 py-6 font-bold text-[#1D1D1F]">
                    {item.total_events} <span className="text-[10px] text-muted ml-1">{t('events')}</span>
                  </td>
                  <td className="px-8 py-6">
                    <div className={`flex items-center gap-2 font-black ${isLowMpi ? 'text-[#FF3B30]' : 'text-[#007AFF]'}`}>
                      <TrendingUp size={14} className={isLowMpi ? 'rotate-180' : ''} />
                      {mpi.toFixed(2)} <span className="text-[10px] uppercase">km/evt</span>
                    </div>
                  </td>
                  <td className="px-8 py-6">
                    {isLowMpi ? (
                      <div className="flex items-center gap-1 text-[10px] font-black text-amber-500">
                        <AlertCircle size={14} /> {t('reject').toUpperCase()}
                      </div>
                    ) : (
                      <div className="flex items-center gap-1 text-[10px] font-black text-green-500">
                        <ShieldCheck size={14} /> {t('verified').toUpperCase()}
                      </div>
                    )}
                  </td>
                </tr>
              );
            })}
            {dataItems.length === 0 && (
              <tr>
                <td colSpan={6} className="px-8 py-20 text-center">
                  <div className="flex flex-col items-center gap-4">
                    <Database className="text-gray-200" size={48} />
                    <p className="text-muted font-bold uppercase tracking-widest text-[10px]">{t('no_induction_data')}</p>
                  </div>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="p-6 bg-[#F5F5F7]/50 border-t border-gray-50 flex items-center justify-between">
        <p className="text-[10px] font-bold text-muted uppercase tracking-widest">
          {t('display_top_records').replace('{count}', dataItems.length.toString())}
        </p>
        {syncedTotal > dataItems.length && (
          <button
            onClick={onLoadMore}
            className="flex items-center gap-2 text-[10px] font-black text-[#007AFF] uppercase hover:gap-3 transition-all"
          >
            {t('view_all_records')} <ArrowRight size={12} />
          </button>
        )}
      </div>
    </div>
  );
};

export default DataExplorerTable;
