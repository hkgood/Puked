import React, { useMemo } from 'react';
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
  ReferenceDot
} from 'recharts';
import { format } from 'date-fns';
import {
  Navigation,
  Zap,
  Activity,
  AlertTriangle,
  ArrowDownCircle,
  AlertOctagon,
  AlertCircle,
  SearchCode,
  CheckCircle2,
  XCircle,
  Trash2,
  Calendar,
  User,
  Box,
  ChevronLeft,
  RefreshCw,
  Image as ImageIcon,
  Download
} from 'lucide-react';
import { useI18n } from '../../../../common/utils/i18n';
import TripMapView, { getEventConfig } from '../../../../common/components/TripMapView';
import LoadingOverlay from '../../../../common/components/LoadingOverlay';
import {
  G_FORCE,
  type ChartScale,
  EVENT_STYLES,
  DEFAULT_EVENT_STYLE
} from '../../config/dashboardConstants';
import {
  parseMetrics,
  getEvents,
  parseTrajectory,
  calculateHeading,
  getSensorVal
} from '../../utils/tripDataUtils';

interface TripAnalysisViewProps {
  selectedTrip: any;
  fullTripData: any;
  loadedTripId: string | null;
  isDataLoading: boolean;
  loadingProgress: number;
  loadError: string | null;
  supplementalEvents: any[];
  chartScale: ChartScale;
  scrollPosition: number;
  isSuperAdmin: boolean;
  currentUser: any;
  isSubmitting: boolean;
  isAuditing: boolean;
  unreasonableEvents: Record<string, string>;
  showMobileDetail: boolean;
  onBack: () => void;
  onApprove: () => void;
  onReject: () => void;
  onUnpublish: () => void;
  onDeleteTrip: () => void;
  onSingleAudit: () => void;
  onDeleteEvent: (index: number) => void;
  onAddSupplemental: (event: any) => void;
  focusLocation: any;
  setFocusLocation: (loc: any) => void;
  onForceRefresh: () => void;
  onCompressImages: () => void;
  isCompressing: boolean;
  onLoadTripDetails: () => void;
  onChartScaleChange: (scale: ChartScale) => void;
  onScrollPositionChange: (pos: number) => void;
}

const TripAnalysisView: React.FC<TripAnalysisViewProps> = ({
  selectedTrip,
  fullTripData,
  loadedTripId,
  isDataLoading,
  loadingProgress,
  loadError,
  supplementalEvents,
  chartScale,
  scrollPosition,
  isSuperAdmin,
  currentUser,
  isSubmitting,
  isAuditing,
  unreasonableEvents,
  showMobileDetail,
  onBack,
  onApprove,
  onReject,
  onUnpublish,
  onDeleteTrip,
  onSingleAudit,
  onDeleteEvent,
  onAddSupplemental,
  focusLocation,
  setFocusLocation,
  onForceRefresh,
  onCompressImages,
  isCompressing,
  onLoadTripDetails,
  onChartScaleChange,
  onScrollPositionChange
}) => {
  const { t } = useI18n();

  // 判断是否已加载详情数据
  const isDetailLoaded = loadedTripId === selectedTrip?.id && fullTripData;

  // 下载行程 JSON 数据
  const handleDownloadTripData = () => {
    if (!fullTripData || !selectedTrip) return;

    // 构造文件名：trip_品牌_车型_日期.json
    const date = selectedTrip.created ? format(new Date(selectedTrip.created), 'yyyyMMdd') : 'unknown';
    const brand = selectedTrip.brand || 'unknown';
    const model = selectedTrip.car_model?.replace(/\s+/g, '_') || 'unknown';
    const fileName = `trip_${brand}_${model}_${date}.json`;

    // 创建 Blob 并触发下载
    const jsonStr = JSON.stringify(fullTripData, null, 2);
    const blob = new Blob([jsonStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = fileName;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  // 获取事件配置（包含标签）
  const getEventLabel = (type: string): string => {
    const typeMap: Record<string, string> = {
      'rapid_accel': t('rapid_accel'),
      'rapidAcceleration': t('accel'),
      'accel': t('accel'),
      'rapid_decel': t('brake'),
      'rapidDeceleration': t('brake'),
      'brake': t('brake'),
      'jerk': t('jerk'),
      'bump': t('bump'),
      'wobble': t('wobble'),
      'proDisengagement': t('proDisengagement'),
      'proViolation': t('proViolation'),
      'proExperience': t('proExperience'),
      'manual': t('manual')
    };
    return typeMap[type] || type;
  };

  const events = useMemo(() =>
    getEvents(selectedTrip, isDetailLoaded ? fullTripData?.events : undefined),
    [selectedTrip, fullTripData, isDetailLoaded]
  );

  const trajectory = useMemo(() =>
    parseTrajectory(selectedTrip, isDetailLoaded ? fullTripData?.trajectory : undefined),
    [selectedTrip, fullTripData, isDetailLoaded]
  );

  const metrics = useMemo(() =>
    parseMetrics(selectedTrip, fullTripData?.metadata),
    [selectedTrip, fullTripData]
  );

  const chartData = useMemo(() => {
    if (!selectedTrip) return [];

    const allDisplayEvents = [
      ...events,
      ...supplementalEvents.map((se, i) => ({
        ...se,
        event_id: `temp_supp_${i}`,
        isPendingSupplemental: true
      }))
    ].sort((a, b) => a.timestamp - b.timestamp);

    const eventsWithData = allDisplayEvents.filter((e: any) => e.sensor_fragment?.data?.length > 0);

    if (eventsWithData.length > 0) {
      const combinedData: any[] = [];
      let globalIndex = 0;
      eventsWithData.forEach((event: any) => {
        const fragment = event.sensor_fragment.data;
        if (!fragment?.length) return;

        let maxG = -1;
        let peakIdx = 0;
        const processedFragment = fragment.slice(0, 300).map((d: any, i: number) => {
          const lat = getSensorVal(d, 'accel', 0) / G_FORCE;
          const lon = getSensorVal(d, 'accel', 1) / G_FORCE;
          const totalG = Math.sqrt(lat * lat + lon * lon);
          if (totalG > maxG) {
            maxG = totalG;
            peakIdx = i;
          }
          return { d, i };
        });

        processedFragment.forEach(({ d, i }: { d: any, i: number }) => {
          // 确保 timestamp 有效
          const eventTimestamp = event.timestamp || 0;
          const offsetSec = (d.offset_ms || 0) / 1000;
          combinedData.push({
            index: globalIndex++,
            timestamp: eventTimestamp + offsetSec,
            lat: event.lat || 0,
            lng: event.lng || 0,
            longitudinal: Number((getSensorVal(d, 'accel', 1) / G_FORCE).toFixed(4)),
            lateral: Number((getSensorVal(d, 'accel', 0) / G_FORCE).toFixed(4)),
            isEventPoint: i === peakIdx,
            eventType: i === peakIdx ? event.type : null,
            isSupplemental: !!event.isPendingSupplemental
          });
        });
        // 添加间隔点（使用最后一个有效 timestamp）
        const lastValidTimestamp = (event.timestamp || 0) + ((processedFragment[processedFragment.length - 1]?.d?.offset_ms || 0) / 1000);
        for (let j = 0; j < 10; j++) combinedData.push({
          index: globalIndex++,
          timestamp: lastValidTimestamp + j * 0.1, // 每个间隔点增加 0.1 秒
          longitudinal: 0,
          lateral: 0,
          gap: true
        });
      });
      return combinedData;
    }

    if (trajectory && trajectory.length >= 3) {
      const results: any[] = [];
      const eventToIdxMap = new Map();
      allDisplayEvents.forEach(e => {
        let minDiff = Infinity;
        let bestIdx = -1;
        trajectory.forEach((p: any, idx: number) => {
          const diff = Math.abs(e.timestamp - (p.ts || 0));
          if (diff < minDiff) { minDiff = diff; bestIdx = idx; }
        });
        if (bestIdx !== -1 && minDiff < 1.0) eventToIdxMap.set(bestIdx, e);
      });

      for (let i = 1; i < trajectory.length - 1; i++) {
        const p1 = trajectory[i - 1]; const p2 = trajectory[i]; const p3 = trajectory[i + 1];
        const dt = (p2.ts || 0) - (p1.ts || 0);
        if (dt <= 0 || dt > 300) continue;

        const unitFactor = ((p1.speed || 0) > 100 || (p2.speed || 0) > 100) ? (1 / 3.6) : 1;
        const dv = ((p2.speed || 0) - (p1.speed || 0)) * unitFactor;
        const longAcc = dv / dt;
        const h1 = calculateHeading(p1, p2); const h2 = calculateHeading(p2, p3);
        let dTheta = h2 - h1;
        if (dTheta > Math.PI) dTheta -= 2 * Math.PI; if (dTheta < -Math.PI) dTheta += 2 * Math.PI;
        const latAcc = ((((p1.speed || 0) + (p2.speed || 0)) / 2.0) * unitFactor) * (dTheta / dt);

        const eventAtThisPoint = eventToIdxMap.get(i);
        results.push({
          index: i,
          timestamp: p2.ts || 0,
          lat: p2.lat || 0,
          lng: p2.lng || 0,
          longitudinal: isNaN(longAcc) ? 0 : Number((longAcc / G_FORCE).toFixed(4)),
          lateral: isNaN(latAcc) ? 0 : Number((latAcc / G_FORCE).toFixed(4)),
          isEventPoint: !!eventAtThisPoint,
          eventType: eventAtThisPoint?.type,
          isSupplemental: !!eventAtThisPoint?.isPendingSupplemental
        });
      }
      return results;
    }
    return [];
  }, [events, trajectory, supplementalEvents]);

  const visibleChartData = useMemo(() => {
    if (chartScale === 'full' || chartData.length === 0) return chartData;
    const totalKm = metrics.distanceKm;
    const windowSizeKm = parseInt(chartScale);
    if (!totalKm || totalKm <= 0) return chartData;
    const ratio = windowSizeKm / totalKm;
    if (ratio >= 1) return chartData;
    const pts = Math.floor(chartData.length * ratio);
    const startIdx = Math.floor((scrollPosition / 100) * (chartData.length - pts));
    return chartData.slice(startIdx, startIdx + pts);
  }, [chartData, chartScale, scrollPosition, metrics.distanceKm]);

  if (!selectedTrip) {
    return (
      <div className="flex-1 flex flex-col items-center justify-center opacity-20 h-full">
        <Navigation size={64} />
        <span className="mt-4 text-[10px] font-black uppercase tracking-[0.2em]">{t('select_trip_hint')}</span>
      </div>
    );
  }

  return (
    <div className={`flex-1 h-full overflow-y-auto ${showMobileDetail ? 'flex' : 'hidden md:flex'} flex-col bg-white relative`}>
      {isSubmitting && <LoadingOverlay message={t('save')} />}

      {isDataLoading && loadingProgress > 0 && loadingProgress < 100 && (
        <div className="absolute top-0 left-0 right-0 h-0.5 bg-gray-100 z-[1001]">
          <div className="h-full bg-[#007AFF] transition-all duration-300" style={{ width: `${loadingProgress}%` }} />
        </div>
      )}

      <div className="p-4 sm:p-6 lg:p-10">
        <div className="max-w-5xl mx-auto w-full">
          {/* 移动端返回按钮 - 放在 header 上方 */}
          {showMobileDetail && (
            <button
              onClick={onBack}
              className="md:hidden mb-4 inline-flex items-center gap-2 p-2 px-3 bg-[#007AFF] text-white rounded-xl shadow-lg active:scale-95 transition-all"
            >
              <ChevronLeft size={20} strokeWidth={2.5} />
              <span className="text-sm font-semibold">{t('back')}</span>
            </button>
          )}

          <header className="mb-8 flex flex-col sm:flex-row justify-between sm:items-center gap-6">
            <div>
              <div className={`inline-flex items-center gap-2 ${selectedTrip.is_public ? 'bg-green-50 text-green-600' : 'bg-amber-50 text-amber-600'} px-3 py-1 rounded-full text-[9px] font-black uppercase mb-3`}>
                {selectedTrip.is_public ? t('data_verified') : t('awaiting_moderation')}
              </div>
              <h1 className="text-3xl font-black text-[#1D1D1F] tracking-tighter">
                {selectedTrip.brand} <span className="font-light text-muted">{selectedTrip.car_model}</span>
              </h1>
            </div>

            <div className="flex gap-3 items-center">
              {isSuperAdmin && (
                <div className="flex gap-2">
                  {!selectedTrip.is_public ? (
                    <>
                      <button onClick={onReject} className="bg-[#FF3B30] text-white px-6 py-2.5 rounded-2xl text-xs font-black uppercase shadow-lg shadow-red-500/20 active:scale-95 transition-all">{t('reject')}</button>
                      <button onClick={onApprove} className="bg-[#248A3D] text-white px-6 py-2.5 rounded-2xl text-xs font-black uppercase shadow-lg shadow-green-500/20 active:scale-95 transition-all">{t('approve')}</button>
                    </>
                  ) : (
                    <button onClick={onUnpublish} className="bg-white border border-gray-100 text-muted px-6 py-2.5 rounded-2xl text-xs font-black uppercase shadow-sm active:scale-95 transition-all">{t('unpublish')}</button>
                  )}
                </div>
              )}

              <div className="flex items-center gap-2 border-l border-gray-100 ml-2 pl-4">
                {/* 下载按钮：只有数据加载完成时才显示 */}
                {loadedTripId === selectedTrip?.id && fullTripData && (
                  <button
                    onClick={handleDownloadTripData}
                    className="p-2.5 text-gray-400 hover:text-green-600 hover:bg-green-50 rounded-xl transition-all"
                    title={t('export_json')}
                  >
                    <Download size={20} />
                  </button>
                )}
                <button onClick={onSingleAudit} disabled={isAuditing} className="p-2.5 text-gray-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-xl transition-all" title={t('reanalyze_trip')}>
                  <SearchCode size={20} className={isAuditing ? 'animate-pulse' : ''} />
                </button>
                <button onClick={onForceRefresh} className="p-2.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-xl transition-all" title={t('force_refresh')}>
                  <RefreshCw size={20} className={isDataLoading ? 'animate-spin' : ''} />
                </button>
                <button onClick={onDeleteTrip} className="p-2.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-xl transition-all" title={t('delete_trip')}>
                  <Trash2 size={20} />
                </button>
              </div>
            </div>
          </header>

          {/* 行程概览卡片 */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
            {[
              { label: t('distance'), value: `${metrics.distanceKm.toFixed(1)}km`, icon: <Activity size={16} />, color: 'text-green-600' },
              { label: t('avg_speed'), value: `${metrics.avgSpeed}km/h`, icon: <Zap size={16} />, color: 'text-blue-600' },
              { label: t('duration'), value: `${metrics.durationMin}min`, icon: <Calendar size={16} />, color: 'text-purple-600' },
              { label: t('total_events'), value: metrics.eventCount, icon: <AlertCircle size={16} />, color: 'text-red-600' },
            ].map((s, i) => (
              <div key={i} className="bg-[#F5F5F7]/50 p-4 rounded-3xl border border-gray-100/50">
                <div className={`flex items-center gap-2 mb-1 ${s.color}`}>
                  {s.icon}
                  <span className="text-[10px] font-black uppercase tracking-widest">{s.label}</span>
                </div>
                <div className="text-xl font-black text-[#1D1D1F]">{s.value}</div>
              </div>
            ))}
          </div>

          {/* 地图视图 */}
          <div className="h-[450px] mb-8 rounded-[2.5rem] overflow-hidden shadow-2xl shadow-gray-200 border border-gray-100 relative group">
            <TripMapView
              trajectory={trajectory}
              events={events}
              focusLocation={focusLocation}
              isLoading={isDataLoading}
              showLoadButton={!isDetailLoaded}
              onLoadDetails={onLoadTripDetails}
            />
          </div>

          {/* 图表分析 - 只有加载完成后才显示 */}
          {isDetailLoaded && (
            <div className="bg-white p-6 rounded-[2.5rem] border border-gray-100 shadow-sm">
              <div className="flex items-center justify-between mb-8">
                <h3 className="text-sm font-black uppercase tracking-[0.2em] text-[#1D1D1F]">{t('trip_analysis')}</h3>
                <div className="flex bg-[#F5F5F7] p-1 rounded-xl">
                  {(['full', '5km', '10km', '50km'] as ChartScale[]).map(s => (
                    <button
                      key={s}
                      onClick={() => onChartScaleChange(s)}
                      className={`px-4 py-1.5 rounded-lg text-[10px] font-black uppercase transition-all ${chartScale === s ? 'bg-white shadow-sm text-blue-600' : 'text-muted'}`}
                    >
                      {s}
                    </button>
                  ))}
                </div>
              </div>

              <div style={{ height: '300px', width: '100%', minHeight: '300px' }}>
                <ResponsiveContainer width="100%" height={300} minHeight={300}>
                  <AreaChart data={visibleChartData}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#F5F5F7" />
                    <XAxis dataKey="index" hide />
                    <YAxis domain={[-1.5, 1.5]} hide />
                    <Tooltip
                      content={({ active, payload }) => {
                        if (!active || !payload?.length) return null;
                        const d = payload[0].payload;
                        // 确保 timestamp 有效
                        if (!d.timestamp || typeof d.timestamp !== 'number') return null;
                        return (
                          <div className="bg-black/90 backdrop-blur-md p-3 rounded-2xl border border-white/10 text-white shadow-2xl">
                            <div className="text-[10px] font-black opacity-50 mb-2 uppercase tracking-widest">{format(d.timestamp * 1000, 'HH:mm:ss.SSS')}</div>
                            <div className="space-y-1">
                              <div className="flex justify-between gap-8 text-[11px] font-bold">
                                <span className="text-amber-400">{t('longitudinal_full')}</span>
                                <span>{d.longitudinal}G</span>
                              </div>
                              <div className="flex justify-between gap-8 text-[11px] font-bold">
                                <span className="text-blue-400">{t('lateral_full')}</span>
                                <span>{d.lateral}G</span>
                              </div>
                            </div>
                          </div>
                        );
                      }}
                    />
                    <Area type="monotone" dataKey="longitudinal" stroke="#F59E0B" fill="#F59E0B" fillOpacity={0.1} strokeWidth={2} isAnimationActive={false} />
                    <Area type="monotone" dataKey="lateral" stroke="#007AFF" fill="#007AFF" fillOpacity={0.1} strokeWidth={2} isAnimationActive={false} />

                    {visibleChartData.filter((d: any) => d.isEventPoint).map((d: any, i: number) => {
                      const config = getEventConfig(d.eventType);
                      const iconColor = d.isSupplemental ? '#34C759' : config.color;
                      return (
                        <React.Fragment key={`event-group-${i}`}>
                          <ReferenceLine
                            x={d.index}
                            stroke={iconColor}
                            strokeWidth={2}
                            strokeDasharray="3 3"
                          />
                          <ReferenceDot
                            x={d.index}
                            y={d.longitudinal > 0 ? 1.2 : -1.2}
                            r={12}
                            fill="white"
                            stroke={iconColor}
                            strokeWidth={2}
                            isAnimationActive={false}
                            shape={(props: any) => {
                              const { cx, cy } = props;
                              return (
                                <g transform={`translate(${cx - 12}, ${cy - 12})`}>
                                  <circle 
                                    cx="12" 
                                    cy="12" 
                                    r="12" 
                                    fill={iconColor} 
                                    stroke="white" 
                                    strokeWidth="1.5" 
                                    style={{ filter: 'drop-shadow(0px 1px 3px rgba(0,0,0,0.3))' }}
                                  />
                                  <g transform="translate(4.8, 4.8) scale(0.6)">
                                    <path
                                      d={config.icon.replace('<path d="', '').replace('"/>', '')}
                                      fill="white"
                                    />
                                  </g>
                                </g>
                              );
                            }}
                          />
                        </React.Fragment>
                      );
                    })}
                  </AreaChart>
                </ResponsiveContainer>
              </div>

              {/* 滚动条 */}
              {chartScale !== 'full' && (
                <div className="mt-4 px-2">
                  <div className="flex justify-between text-[9px] font-black uppercase text-muted mb-2 tracking-widest">
                    <span>{t('start_of_trip') || 'Start'}</span>
                    <span>{t('scroll_to_view_more') || 'Scroll to explore'}</span>
                    <span>{t('end_of_trip') || 'End'}</span>
                  </div>
                  <input
                    type="range"
                    min="0"
                    max="100"
                    step="0.1"
                    value={scrollPosition}
                    onChange={(e) => onScrollPositionChange(parseFloat(e.target.value))}
                    className="w-full h-1.5 bg-[#F5F5F7] rounded-lg appearance-none cursor-pointer accent-blue-600"
                  />
                </div>
              )}
            </div>
          )}

          {/* 事件时间轴 - 只有加载完成后才显示 */}
          {isDetailLoaded && events.length > 0 && (
            <div className="bg-white p-6 rounded-[2.5rem] border border-gray-100 shadow-sm mt-8">
              <h3 className="text-sm font-black uppercase tracking-[0.2em] text-[#1D1D1F] mb-6">{t('timeline')}</h3>
              <div className="space-y-3">
                {events.map((evt: any, idx: number) => {
                  const config = getEventConfig(evt.type);
                  const isUnreasonable = unreasonableEvents[evt.event_id];

                  return (
                    <div
                      key={idx}
                      onClick={() => setFocusLocation({ lat: evt.lat, lng: evt.lng })}
                      className="flex items-center gap-4 p-4 bg-[#F5F5F7]/30 hover:bg-[#F5F5F7] rounded-2xl cursor-pointer transition-all group relative"
                    >
                      <div
                        className="p-3 rounded-2xl shadow-sm flex items-center justify-center"
                        style={{ backgroundColor: `${config.color}15`, color: config.color }}
                      >
                        <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
                          <path d={config.icon.replace('<path d="', '').replace('"/>', '')} />
                        </svg>
                      </div>

                      <div className="flex-1 min-w-0">
                        <div className="font-black text-[#1D1D1F] text-sm mb-1">
                          {getEventLabel(evt.type)}
                          {isUnreasonable && (
                            <span className="ml-2 text-[9px] bg-amber-100 text-amber-600 px-2 py-0.5 rounded-full">
                              {t('unreasonable')}
                            </span>
                          )}
                        </div>
                        <div className="text-[10px] text-muted font-bold">
                          {format(new Date(evt.timestamp * 1000), 'HH:mm:ss')}
                          {evt.description && (
                            <span className="ml-2 text-[9px] opacity-60">• {evt.description}</span>
                          )}
                        </div>
                      </div>

                      {isSuperAdmin && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            onDeleteEvent(idx);
                          }}
                          className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-xl transition-all opacity-0 group-hover:opacity-100"
                        >
                          <Trash2 size={16} />
                        </button>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* 补充事件 - 只有加载完成后才显示 */}
          {isDetailLoaded && supplementalEvents.length > 0 && (
            <div className="bg-green-50 p-6 rounded-[2.5rem] border border-green-100 shadow-sm mt-8">
              <h3 className="text-sm font-black uppercase tracking-[0.2em] text-green-600 mb-6">{t('suggested_events')}</h3>
              <div className="space-y-3">
                {supplementalEvents.map((evt: any, idx: number) => {
                  const config = getEventConfig(evt.type);

                  return (
                    <div
                      key={idx}
                      onClick={() => setFocusLocation({ lat: evt.lat, lng: evt.lng })}
                      className="flex items-center gap-4 p-4 bg-white hover:bg-green-50 rounded-2xl cursor-pointer transition-all group"
                    >
                      <div
                        className="p-3 rounded-2xl shadow-sm flex items-center justify-center"
                        style={{ backgroundColor: `${config.color}15`, color: config.color }}
                      >
                        <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
                          <path d={config.icon.replace('<path d="', '').replace('"/>', '')} />
                        </svg>
                      </div>

                      <div className="flex-1 min-w-0">
                        <div className="font-black text-[#1D1D1F] text-sm mb-1">{getEventLabel(evt.type)}</div>
                        <div className="text-[10px] text-muted font-bold">
                          {format(new Date(evt.timestamp * 1000), 'HH:mm:ss')}
                          {evt.description && (
                            <span className="ml-2 text-[9px] opacity-60">• {evt.description}</span>
                          )}
                        </div>
                      </div>

                      {isSuperAdmin && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            onAddSupplemental(evt);
                          }}
                          className="px-4 py-2 bg-green-600 text-white rounded-xl text-[10px] font-black uppercase shadow-sm hover:bg-green-700 transition-all opacity-0 group-hover:opacity-100"
                        >
                          {t('add')}
                        </button>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* 无事件提示 - 只有加载完成后才显示 */}
          {isDetailLoaded && events.length === 0 && supplementalEvents.length === 0 && (
            <div className="bg-[#F5F5F7]/30 p-8 rounded-[2.5rem] border border-gray-100 text-center mt-8">
              <CheckCircle2 size={48} className="text-green-600 mx-auto mb-4 opacity-20" />
              <p className="text-sm text-muted font-bold">{t('perfect_trip')}</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default React.memo(TripAnalysisView);
