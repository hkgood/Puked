import React, { useState, useEffect } from 'react';
import {
  Navigation,
  Search,
  SearchCode,
  ChevronDown,
  Calendar,
  User,
  Activity
} from 'lucide-react';
import { format } from 'date-fns';
import { useI18n } from '../../../../common/utils/i18n';
import LoadingOverlay from '../../../../common/components/LoadingOverlay';
import { parseMetrics, getEvents } from '../../utils/tripDataUtils';

interface TripsSectionProps {
  trips: any[];
  selectedTrip: any;
  setSelectedTrip: (trip: any) => void;
  tripFilter: string;
  setTripFilter: (filter: any) => void;
  tripSearchQuery: string;
  setTripSearchQuery: (query: string) => void;
  tripStats: any;
  brandOptions: string[];
  versionOptions: string[];
  filterBrand: string;
  setFilterBrand: (val: string) => void;
  filterVersion: string;
  setFilterVersion: (val: string) => void;
  filterSpeedRange: string;
  setFilterSpeedRange: (val: string) => void;
  filterStartDate: string;
  setFilterStartDate: (val: string) => void;
  filterEndDate: string;
  setFilterEndDate: (val: string) => void;
  pendingTrips: any[];
  approvedTrips: any[];
  isPendingCollapsed: boolean;
  setIsPendingCollapsed: (val: boolean) => void;
  isApprovedCollapsed: boolean;
  setIsApprovedCollapsed: (val: boolean) => void;
  isLoading: boolean;
  isDataLoading: boolean;
  isLoadingMore: boolean;
  hasMoreTrips: boolean;
  onLoadMore: () => void;
  showMobileDetail: boolean;
  setShowMobileDetail: (show: boolean) => void;
  suspiciousCountPerTrip: Record<string, number>;
  tripSupplementalCounts: Record<string, number>;
  supplementalEvents: any[];
}

const TripsSection: React.FC<TripsSectionProps> = ({
  trips,
  selectedTrip,
  setSelectedTrip,
  tripFilter,
  setTripFilter,
  tripSearchQuery,
  setTripSearchQuery,
  tripStats,
  brandOptions,
  versionOptions,
  filterBrand,
  setFilterBrand,
  filterVersion,
  setFilterVersion,
  filterSpeedRange,
  setFilterSpeedRange,
  filterStartDate,
  setFilterStartDate,
  filterEndDate,
  setFilterEndDate,
  pendingTrips,
  approvedTrips,
  isPendingCollapsed,
  setIsPendingCollapsed,
  isApprovedCollapsed,
  setIsApprovedCollapsed,
  isLoading,
  isDataLoading,
  isLoadingMore,
  hasMoreTrips,
  onLoadMore,
  showMobileDetail,
  setShowMobileDetail,
  suspiciousCountPerTrip,
  tripSupplementalCounts,
  supplementalEvents
}) => {
  const { t } = useI18n();
  const [localSearchQuery, setLocalSearchQuery] = useState(tripSearchQuery);

  // 当外部搜索词变化时（如重置），同步到本地
  useEffect(() => {
    setLocalSearchQuery(tripSearchQuery);
  }, [tripSearchQuery]);

  const handleScroll = (e: React.UIEvent<HTMLDivElement>) => {
    const { scrollTop, scrollHeight, clientHeight } = e.currentTarget;
    if (scrollHeight - scrollTop - clientHeight < 100) onLoadMore();
  };

  const renderTripItem = (trip: any) => {
    const { distanceKm } = parseMetrics(trip);
    const metrics = typeof trip.metrics === 'string' ? JSON.parse(trip.metrics) : trip.metrics;
    const isSelected = selectedTrip?.id === trip.id;

    const currentEvents = isSelected ? getEvents(selectedTrip) : getEvents(trip);
    // 修复：即使选中状态，也应该回退到 metrics.event_count
    const eventCount = currentEvents.length || metrics?.event_count || 0;
    const supplementalCount = isSelected ? supplementalEvents.length : (tripSupplementalCounts[trip.id] || 0);
    const suspiciousCount = suspiciousCountPerTrip[trip.id] || 0;

    return (
      <div
        key={trip.id}
        onClick={() => { setSelectedTrip(trip); setShowMobileDetail(true); }}
        className={`p-4 mb-2 rounded-xl cursor-pointer transition-all relative group ${isSelected ? 'bg-white shadow-lg scale-[1.01]' : 'hover:bg-white/50'}`}
      >
        <div className="flex justify-between items-start mb-2">
          <div className="font-black text-[#1D1D1F] text-base tracking-tight uppercase truncate pr-2">
            {trip.brand || trip.brand_ref} {trip.car_model}
          </div>
          <div className="flex flex-col items-end gap-1">
            <div className="flex gap-1">
              {eventCount > 0 && <span className="text-[9px] font-black bg-[#FF3B30]/10 text-[#FF3B30] px-2 py-0.5 rounded-full">{eventCount} {t('events_unit')}</span>}
              {supplementalCount > 0 && <span className="text-[9px] font-black bg-green-100 text-green-600 px-2 py-0.5 rounded-full">{supplementalCount} {t('suggested_evts_tag')}</span>}
            </div>
            {suspiciousCount > 0 && <span className="text-[9px] font-black bg-amber-100 text-amber-600 px-2 py-0.5 rounded-full animate-pulse">{suspiciousCount} {t('suspicious_evts')}</span>}
          </div>
        </div>
        <div className="flex items-center gap-3 text-[10px] font-bold text-muted">
          <div className="flex items-center gap-1"><Calendar size={12} className="opacity-50" />{format(new Date(trip.created), 'MM/dd HH:mm')}</div>
          <div className="flex items-center gap-1 text-[#007AFF]"><User size={12} className="opacity-70" /><span className="truncate max-w-[80px]">{trip.expand?.user?.name || trip.expand?.user?.username || t('anonymous')}</span></div>
          <div className="flex items-center gap-1 text-[#248A3D]"><Activity size={12} />{distanceKm.toFixed(1)}km</div>
        </div>
      </div>
    );
  };

  if ((isLoading || isDataLoading) && trips.length === 0) {
    return <div className="flex-1 relative"><LoadingOverlay /></div>;
  }

  return (
    <div className={`w-full md:w-[360px] border-r border-gray-100 flex flex-col h-full bg-[#F5F5F7]/30 ${showMobileDetail ? 'hidden md:flex' : 'flex'}`}>
      <div className="px-4 pb-4 border-b border-gray-100 bg-white/80 backdrop-blur-md sticky top-0 z-10 pt-6">
        <div className="flex items-center justify-between mb-3">
          <span className="text-[11px] font-black text-[#1D1D1F] uppercase tracking-widest flex items-center gap-2">
            <SearchCode size={14} className="text-[#007AFF]" />
            {t('trip_management')}
          </span>
        </div>

        <div className="relative group mb-3">
          <input
            type="text"
            value={localSearchQuery}
            onChange={(e) => setLocalSearchQuery(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                setTripSearchQuery(localSearchQuery);
              }
            }}
            onBlur={() => {
              // 失去焦点时，如果内容发生了变化，也触发搜索
              if (localSearchQuery !== tripSearchQuery) {
                setTripSearchQuery(localSearchQuery);
              }
            }}
            placeholder={t('search_trips')}
            className="w-full bg-[#F5F5F7] rounded-xl pl-8 pr-3 py-2 text-[10px] font-black text-[#1D1D1F] outline-none hover:bg-gray-200 transition-colors"
          />
          <Search 
            className="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted cursor-pointer hover:text-[#007AFF] transition-colors" 
            size={12} 
            onClick={() => setTripSearchQuery(localSearchQuery)}
          />
        </div>

        <div className="relative group mb-3">
          <select
            value={tripFilter}
            onChange={(e) => setTripFilter(e.target.value)}
            className="w-full appearance-none bg-[#F5F5F7] rounded-xl px-3 py-2 pr-8 text-[10px] font-black text-[#1D1D1F] outline-none cursor-pointer hover:bg-gray-200"
          >
            <option value="all">{t('trip_status_all')} ({tripStats.all})</option>
            <option value="public">{t('trip_status_public')} ({tripStats.public})</option>
            <option value="pending">{t('trip_status_pending')} ({tripStats.pending})</option>
          </select>
          <ChevronDown className="absolute right-2 top-1/2 -translate-y-1/2 text-muted pointer-events-none" size={10} />
        </div>

        <div className="grid grid-cols-3 gap-1.5 mb-2">
          <select value={filterBrand} onChange={(e) => setFilterBrand(e.target.value)} className="bg-[#F5F5F7] rounded-xl px-2 py-1.5 text-[9px] font-black outline-none cursor-pointer">
            <option value="all">{t('brand')}</option>
            {brandOptions.map(b => <option key={b} value={b}>{b}</option>)}
          </select>
          <select value={filterVersion} onChange={(e) => setFilterVersion(e.target.value)} className="bg-[#F5F5F7] rounded-xl px-2 py-1.5 text-[9px] font-black outline-none cursor-pointer">
            <option value="all">{t('version')}</option>
            {versionOptions.map(v => <option key={v} value={v}>{v}</option>)}
          </select>
          <select value={filterSpeedRange} onChange={(e) => setFilterSpeedRange(e.target.value)} className="bg-[#F5F5F7] rounded-xl px-2 py-1.5 text-[9px] font-black outline-none cursor-pointer">
            <option value="all">{t('filter_speed')}</option>
            <option value="high">{t('speed_high')}</option>
            <option value="medium">{t('speed_medium')}</option>
            <option value="low">{t('speed_low')}</option>
          </select>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-3 pb-8 pt-4" onScroll={handleScroll}>
        {trips.map(renderTripItem)}
        {isLoadingMore && (
          <div className="py-4 flex flex-col items-center gap-2">
            <div className="w-5 h-5 border-2 border-[#007AFF]/20 border-t-[#007AFF] rounded-full animate-spin"></div>
            <span className="text-[10px] font-black text-muted uppercase tracking-widest">{t('loading')}</span>
          </div>
        )}
      </div>
    </div>
  );
};

export default React.memo(TripsSection);
