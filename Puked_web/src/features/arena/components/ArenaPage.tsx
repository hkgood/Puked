import React, { useEffect, useState, useMemo } from 'react';
import { ArenaService } from '../services/arenaService';
import { pb } from '../../../services/pocketbase';
import type { BrandRecord, SoftwareVersionRecord } from '../../../models/types';
import { Trophy, TrendingUp, BarChart3, Activity, Zap, TrendingDown, AlertCircle, Waves, ChevronDown, User, Crown, RefreshCcw } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LabelList } from 'recharts';
import { useI18n } from '../../../common/utils/i18n';

const ArenaPage = () => {
  const { t, lang } = useI18n();
  const [data, setData] = useState<{ brands: BrandRecord[], versions: SoftwareVersionRecord[] } | null>(null);
  const [stats, setStats] = useState<any>(null);
  const [groupByBrand, setGroupByBrand] = useState(true);
  const [leaderboardWeekly, setLeaderboardWeekly] = useState(false);
  const [scenario, setScenario] = useState<'city' | 'highway'>('city');
  // 🆕 周度排名场景状态
  const [weeklyScenario, setWeeklyScenario] = useState<'city' | 'highway'>('city');
  
  // 隔离状态
  const [evoBrand, setEvoBrand] = useState<string>('');
  const [symptomBrand, setSymptomBrand] = useState<string>('');
  const [isRefreshing, setIsRefreshing] = useState(false);

  const [isSyncing, setIsSyncing] = useState(false);
  
  // 🆕 分阶段加载状态
  const [loadingPhase, setLoadingPhase] = useState<'initial' | 'basic' | 'complete'>('initial');
  const [detailsLoading, setDetailsLoading] = useState<Record<string, boolean>>({});

  const fetchData = async (force = false) => {
    if (isRefreshing || isSyncing) return;
    
    setIsRefreshing(true);
    try {
      // 🆕 第一阶段：快速加载基础数据
      setLoadingPhase('basic');
      
      // 并行获取基础库和统计数据
      const [base, snapshot] = await Promise.all([
        ArenaService.getBaseLibrary(),
        ArenaService.getStatsSnapshot()
      ]);

      setData({ brands: base.brands, versions: base.versions });
      setStats(snapshot);
      
      // 🆕 第二阶段：数据加载完成
      setLoadingPhase('complete');

      // 检查数据是否真的有效 (针对新逻辑进行兼容)
      const hasRealData = snapshot && (
        (snapshot.ranking_brand && snapshot.ranking_brand.length > 0) || 
        (snapshot.data && snapshot.data.length > 0)
      );

      if (force || !hasRealData) {
        console.log(hasRealData ? "Force refresh..." : "Empty data found.");
      }
      
      const bOptions = (snapshot && snapshot.brand_options) || [];
      if (bOptions.length > 0) {
        setEvoBrand(prev => prev || bOptions[0].key);
        setSymptomBrand(prev => prev || bOptions[0].key);
      }
    } catch (e) {
      console.error("Critical Arena Error:", e);
      setStats({});
      setLoadingPhase('complete');
    } finally {
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  // 已移除：loadBrandDetails useEffect。
  // 因为现在 stats 对象中已经包含了所有 symptoms_ 和 evolution_ 开头的快照数据。
  
  const brandOptions = stats?.brand_options || [];

  // 直接从 stats 中读取预计算好的品牌详情
  const activeSymptomData = useMemo(() => {
    return stats?.[`symptoms_${symptomBrand}`] || { details: {}, counts: {}, totalKm: 0, tripCount: 0 };
  }, [stats, symptomBrand]);

  const { evolutionData, yAxisDomain, yAxisTicks } = useMemo(() => {
    const evoData = stats?.[`evolution_${evoBrand}`] || [];
    if (evoData.length === 0) {
      return { evolutionData: [], yAxisDomain: [0, 5], yAxisTicks: [0, 1, 2, 3, 4, 5] };
    }
    const realMax = Math.max(...evoData.map((i: any) => i.kmPerEvent), 1.0);
    let interval: number;
    if (realMax <= 3) interval = 0.5;
    else if (realMax <= 10) interval = 1.0;
    else interval = Math.ceil(realMax / 5);
    const niceMax = Math.ceil(realMax / interval) * interval + interval;
    const ticks = [];
    for (let i = 0; i <= niceMax; i += interval) { ticks.push(Number(i.toFixed(1))); }
    return { evolutionData: evoData, yAxisDomain: [0, niceMax], yAxisTicks: ticks };
  }, [stats, evoBrand]);

  const renderSkeleton = () => (
    <div className="min-h-screen bg-[#F5F5F7] pt-6 sm:pt-12 pb-16 md:pb-10 px-3 sm:px-6 max-w-7xl mx-auto flex flex-col items-center animate-pulse">
      <header className="mb-12 text-center w-full">
        <div className="h-12 w-48 bg-gray-200 rounded-xl mx-auto mb-4"></div>
        <div className="h-4 w-64 bg-gray-200 rounded-lg mx-auto"></div>
      </header>
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 w-full mb-6">
        {[1, 2].map(i => (
          <div key={i} className="bg-white rounded-[1.25rem] p-8 h-[400px] border border-gray-100">
            <div className="flex justify-between mb-8">
              <div className="space-y-3">
                <div className="h-6 w-32 bg-gray-100 rounded-lg"></div>
                <div className="h-3 w-48 bg-gray-50 rounded-md"></div>
              </div>
              <div className="h-8 w-24 bg-gray-100 rounded-xl"></div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
  
  // 🆕 卡片内部加载骨架屏
  const renderCardSkeleton = () => (
    <div className="animate-pulse">
      <div className="space-y-3">
        {[1, 2, 3].map(i => (
          <div key={i} className="h-16 bg-gray-100 rounded-xl"></div>
        ))}
      </div>
    </div>
  );

  // 🆕 只在初始加载时显示全屏骨架屏
  if (loadingPhase === 'initial') return renderSkeleton();
  
  // 🆕 安全地访问 stats 属性，避免 null 错误
  const rankingData = (groupByBrand ? stats?.ranking_brand : stats?.ranking_version) || [];
  const scenarioRankingData = (scenario === 'city' ? stats?.ranking_city : stats?.ranking_highway) || [];
  const mileageData = stats?.mileage || [];
  const userLeaderboardData = (leaderboardWeekly ? stats?.leaderboard_weekly : stats?.leaderboard_total) || [];
  const { details: symptomDetails, counts: symptomCounts, totalKm: symptomTotalKm, tripCount: symptomTripCount } = activeSymptomData;
  // 🆕 周度排名数据
  const weeklyScenarioRankingData = (weeklyScenario === 'city' ? stats?.ranking_city_weekly : stats?.ranking_highway_weekly) || [];
  const weeklyMileageData = stats?.mileage_weekly || [];
  
  return (
    <div className="min-h-screen bg-[#F5F5F7] pt-6 sm:pt-12 pb-16 md:pb-10 px-3 sm:px-6 max-w-7xl mx-auto text-left relative">
      {isRefreshing && (
        <div className="fixed top-4 right-4 z-50 bg-white/80 backdrop-blur-md p-2 rounded-full shadow-lg animate-fade-in">
          <RefreshCcw className="text-[#007AFF] animate-spin" size={20} />
        </div>
      )}
      <header className="mb-6 sm:mb-8 text-center">
        <div className="flex items-center justify-center gap-3 mb-2">
          <h1 className="text-3xl sm:text-5xl font-black text-[#1D1D1F] tracking-tighter">Arena.</h1>
        </div>
        <p className="text-muted text-base sm:text-lg font-medium">{t('verified_data')}</p>
        <p className="text-[10px] font-black text-[#007AFF]/50 uppercase tracking-widest mt-2">{t('arena_mileage_requirement')}</p>
      </header>

      {/* 🆕 周度排名区域 - 置顶显示 */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 mb-4 sm:mb-6">
        {/* 周度城区/高速舒适度排名 */}
        <div className="bg-white rounded-[1.25rem] p-5 sm:p-8 card-shadow border border-gray-100">
          <div className="flex justify-between items-start mb-6">
            <div className="min-w-0 flex-1">
              <h2 className="text-sm sm:text-base font-bold text-[#1D1D1F] flex items-center gap-2 mb-1">
                <Activity className="text-[#34C759]" size={18} />
                <span>{t('weekly_comfort_ranking')}</span>
              </h2>
              <p className="text-[10px] font-bold text-muted uppercase tracking-tight ml-6">
                {t('weekly_comfort_desc')}
              </p>
            </div>
            <div className="flex bg-[#F5F5F7] p-1 rounded-xl">
              <button onClick={() => setWeeklyScenario('city')} className={`px-3 py-1.5 rounded-lg text-[10px] font-black ${weeklyScenario === 'city' ? 'bg-white shadow-sm text-[#007AFF]' : 'text-muted'}`}>{t('city').toUpperCase()}</button>
              <button onClick={() => setWeeklyScenario('highway')} className={`px-3 py-1.5 rounded-lg text-[10px] font-black ${weeklyScenario === 'highway' ? 'bg-white shadow-sm text-[#007AFF]' : 'text-muted'}`}>{t('highway').toUpperCase()}</button>
            </div>
          </div>
          <div className="space-y-4 sm:space-y-6">
            {loadingPhase === 'basic' || !stats ? (
              renderCardSkeleton()
            ) : weeklyScenarioRankingData.length > 0 ? (
              weeklyScenarioRankingData.slice(0, 10).map((item: any, index: number) => (
                <div key={item.label} className="flex items-center gap-3">
                  <span className="w-4 text-sm font-black text-muted/30">{index + 1}</span>
                  <div className="w-10 h-10 bg-[#F5F5F7] rounded-xl flex items-center justify-center">
                    {ArenaService.getLogoUrl(data?.brands || [], item.brandId) ? (
                      <img src={ArenaService.getLogoUrl(data?.brands || [], item.brandId)!} className="w-6 h-6 object-contain" alt="" />
                    ) : <span className="text-sm font-black text-gray-300">?</span>}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex justify-between text-[12px] sm:text-[13px] font-black mb-1.5">
                      <span className="truncate mr-2 uppercase">{item.label}</span>
                      <span className="text-muted font-normal">{item.kmPerEvent.toFixed(1)} km/evt</span>
                    </div>
                    <div className="h-1.5 bg-[#F5F5F7] rounded-full overflow-hidden">
                      <div className="h-full bg-[#34C759] rounded-full transition-all" style={{ width: `${(item.kmPerEvent / (weeklyScenarioRankingData[0]?.kmPerEvent || 1)) * 100}%` }}></div>
                    </div>
                  </div>
                </div>
              ))
            ) : (
              <div className="flex flex-col items-center justify-center py-12 text-muted/40">
                <Activity size={40} strokeWidth={1} className="mb-2" />
                <p className="text-[10px] font-black uppercase tracking-widest">{t('no_data_scenario')}</p>
              </div>
            )}
          </div>
        </div>

        {/* 周度品牌累计里程排名 */}
        <div className="bg-white rounded-[1.25rem] p-5 sm:p-8 card-shadow border border-gray-100">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-6 gap-4">
            <div className="min-w-0 flex-1">
              <h2 className="text-sm sm:text-base font-bold text-[#1D1D1F] flex items-center gap-2 mb-1">
                <TrendingUp className="text-[#34C759]" size={18} />
                <span>{t('weekly_mileage_ranking')}</span>
              </h2>
              <p className="text-[10px] font-bold text-muted uppercase tracking-tight ml-6">
                {t('weekly_mileage_desc')}
              </p>
            </div>
            
            {/* 🆕 图例 Legend */}
            <div className="flex flex-wrap gap-3 items-center">
              {[
                { label: '>80', color: '#007AFF' },
                { label: '50-80', color: '#5AC8FA' },
                { label: '20-50', color: '#34C759' },
                { label: '<20', color: '#FFCC00' }
              ].map(item => (
                <div key={item.label} className="flex items-center gap-1.5">
                  <div className="w-2 h-2 rounded-full" style={{ backgroundColor: item.color }}></div>
                  <span className="text-[9px] font-black text-muted uppercase tracking-tighter">{item.label}</span>
                </div>
              ))}
            </div>
          </div>
          <div className="space-y-4 sm:space-y-6">
            {loadingPhase === 'basic' || !stats ? (
              renderCardSkeleton()
            ) : weeklyMileageData.length > 0 ? (
              weeklyMileageData.slice(0, 10).map((item: any, index: number) => {
                const maxTotalKm = weeklyMileageData[0]?.totalKm || 1;
                const relativeWidth = (item.totalKm / maxTotalKm) * 100;
                return (
                  <div key={item.brandKey} className="flex items-center gap-3">
                    <span className="w-4 text-sm font-black text-muted/30">{index + 1}</span>
                    <div className="w-10 h-10 bg-[#F5F5F7] rounded-xl flex items-center justify-center">
                      {ArenaService.getLogoUrl(data?.brands || [], item.brandKey) ? (
                        <img src={ArenaService.getLogoUrl(data?.brands || [], item.brandKey)!} className="w-6 h-6 object-contain" alt="" />
                      ) : <span className="text-sm font-black text-gray-300">?</span>}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex justify-between items-baseline mb-2">
                        <span className="text-[12px] sm:text-[13px] font-black text-[#1D1D1F] uppercase truncate mr-2">{item.brand}</span>
                        <span className="text-[12px] sm:text-[13px] text-muted font-normal">{item.totalKm.toFixed(1)} km</span>
                      </div>
                      {/* 🆕 分段颜色进度条 - 外层控制品牌总长度，内层控制占比 */}
                      <div 
                        className="h-1.5 bg-[#F5F5F7] rounded-full overflow-hidden flex transition-all duration-1000 shadow-inner"
                        style={{ width: `${relativeWidth}%` }}
                      >
                        {item.totalKm > 0 ? (
                          <>
                            <div className="h-full bg-[#007AFF] transition-all" style={{ width: `${((item.breakdown?.highway || 0) / item.totalKm) * 100}%` }}></div>
                            <div className="h-full bg-[#5AC8FA] transition-all" style={{ width: `${((item.breakdown?.smooth || 0) / item.totalKm) * 100}%` }}></div>
                            <div className="h-full bg-[#34C759] transition-all" style={{ width: `${((item.breakdown?.urban || 0) / item.totalKm) * 100}%` }}></div>
                            <div className="h-full bg-[#FFCC00] transition-all" style={{ width: `${((item.breakdown?.congested || 0) / item.totalKm) * 100}%` }}></div>
                          </>
                        ) : (
                          <div className="h-full bg-gray-100 w-full"></div>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })
            ) : (
              <div className="flex flex-col items-center justify-center py-12 text-muted/40">
                <TrendingUp size={40} strokeWidth={1} className="mb-2" />
                <p className="text-[10px] font-black uppercase tracking-widest">No data available</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* 全时段排行区域 */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 mb-4 sm:mb-6">
        {/* 场景排行 */}
        <div className="bg-white rounded-[1.25rem] p-5 sm:p-8 card-shadow border border-gray-100">
          <div className="flex justify-between items-start mb-6">
            <div className="min-w-0 flex-1">
              <h2 className="text-sm sm:text-base font-bold text-[#1D1D1F] flex items-center gap-2 mb-1">
                <Activity className="text-[#007AFF]" size={18} />
                <span>{scenario === 'city' ? t('low_speed_ranking') : t('high_speed_ranking')}</span>
              </h2>
              <p className="text-[10px] font-bold text-muted uppercase tracking-tight ml-6">
                {scenario === 'city' ? t('low_speed_desc') : t('high_speed_desc')}
              </p>
            </div>
            <div className="flex bg-[#F5F5F7] p-1 rounded-xl">
              <button onClick={() => setScenario('city')} className={`px-3 py-1.5 rounded-lg text-[10px] font-black ${scenario === 'city' ? 'bg-white shadow-sm text-[#007AFF]' : 'text-muted'}`}>{t('city').toUpperCase()}</button>
              <button onClick={() => setScenario('highway')} className={`px-3 py-1.5 rounded-lg text-[10px] font-black ${scenario === 'highway' ? 'bg-white shadow-sm text-[#007AFF]' : 'text-muted'}`}>{t('highway').toUpperCase()}</button>
            </div>
          </div>
          <div className="space-y-4 sm:space-y-6">
            {loadingPhase === 'basic' || !stats ? (
              // 🆕 数据加载中，显示骨架屏
              renderCardSkeleton()
            ) : scenarioRankingData.length > 0 ? (
              scenarioRankingData.slice(0, 10).map((item: any, index: number) => (
                <div key={item.label} className="flex items-center gap-3">
                  <span className="w-4 text-sm font-black text-muted/30">{index + 1}</span>
                  <div className="w-10 h-10 bg-[#F5F5F7] rounded-xl flex items-center justify-center">
                    {ArenaService.getLogoUrl(data?.brands || [], item.brandId) ? (
                      <img src={ArenaService.getLogoUrl(data?.brands || [], item.brandId)!} className="w-6 h-6 object-contain" alt="" />
                    ) : <span className="text-sm font-black text-gray-300">?</span>}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex justify-between text-[12px] sm:text-[13px] font-black mb-1.5">
                      <span className="truncate mr-2 uppercase">{item.label}</span>
                      <span className="text-muted font-normal">{item.kmPerEvent.toFixed(1)} km/evt</span>
                    </div>
                    <div className="h-1.5 bg-[#F5F5F7] rounded-full overflow-hidden">
                      <div className="h-full bg-[#007AFF] rounded-full transition-all" style={{ width: `${(item.kmPerEvent / (scenarioRankingData[0]?.kmPerEvent || 1)) * 100}%` }}></div>
                    </div>
                  </div>
                </div>
              ))
            ) : (
              <div className="flex flex-col items-center justify-center py-12 text-muted/40">
                <Activity size={40} strokeWidth={1} className="mb-2" />
                <p className="text-[10px] font-black uppercase tracking-widest">{t('no_data_scenario')}</p>
              </div>
            )}
          </div>
        </div>

        {/* 综合排行 */}
        <div className="bg-white rounded-[1.25rem] p-5 sm:p-8 card-shadow border border-gray-100">
          <div className="flex justify-between items-start mb-6">
            <div className="min-w-0 flex-1">
              <h2 className="text-sm sm:text-base font-bold text-[#1D1D1F] flex items-center gap-2 mb-1">
                <Trophy className="text-[#007AFF]" size={18} />
                <span>{t('ranking')}</span>
              </h2>
              <p className="text-[10px] font-bold text-muted uppercase tracking-tight ml-6">
                {t('km_per_event_long')}
              </p>
            </div>
            <div className="flex bg-[#F5F5F7] p-1 rounded-xl">
              <button onClick={() => setGroupByBrand(true)} className={`px-3 py-1.5 rounded-lg text-[10px] font-black ${groupByBrand ? 'bg-white shadow-sm text-[#007AFF]' : 'text-muted'}`}>{t('brand').toUpperCase()}</button>
              <button onClick={() => setGroupByBrand(false)} className={`px-3 py-1.5 rounded-lg text-[10px] font-black ${!groupByBrand ? 'bg-white shadow-sm text-[#007AFF]' : 'text-muted'}`}>{t('version_short').toUpperCase()}</button>
            </div>
          </div>
          <div className="space-y-4 sm:space-y-6">
            {loadingPhase === 'basic' || !stats ? (
              // 🆕 数据加载中，显示骨架屏
              renderCardSkeleton()
            ) : rankingData.length > 0 ? (
              rankingData.slice(0, 10).map((item: any, index: number) => (
              <div key={item.label} className="flex items-center gap-3">
                <span className="w-4 text-sm font-black text-muted/30">{index + 1}</span>
                <div className="w-10 h-10 bg-[#F5F5F7] rounded-xl flex items-center justify-center">
                  {ArenaService.getLogoUrl(data?.brands || [], item.brand) ? (
                    <img src={ArenaService.getLogoUrl(data?.brands || [], item.brand)!} className="w-6 h-6 object-contain" alt="" />
                  ) : <span className="text-sm font-black text-gray-300">?</span>}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex justify-between text-[12px] sm:text-[13px] font-black mb-1.5">
                    <span className="truncate mr-2 uppercase">
                      {item.version ? (
                        <>
                          <span>{item.brand}</span>
                          <span className="font-normal ml-1.5 text-muted not-italic">{item.version}</span>
                        </>
                      ) : item.label}
                    </span>
                    <span className="text-muted font-normal">{item.kmPerEvent.toFixed(1)} km/evt</span>
                  </div>
                  <div className="h-1.5 bg-[#F5F5F7] rounded-full overflow-hidden">
                    <div className="h-full bg-[#007AFF] rounded-full transition-all" style={{ width: `${(item.kmPerEvent / (rankingData[0]?.kmPerEvent || 1)) * 100}%` }}></div>
                  </div>
                </div>
              </div>
            ))
            ) : (
              <div className="text-center text-muted py-8">No data available</div>
            )}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 mb-4 sm:mb-6">
        {/* 里程分布 */}
        <div className="bg-white rounded-[1.25rem] p-5 sm:p-8 card-shadow border border-gray-100">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-6 gap-4">
            <div>
              <h2 className="text-lg sm:text-xl font-black text-[#1D1D1F] flex items-center gap-2">
                <BarChart3 className="text-[#007AFF]" size={20} />
                <span>{t('mileage')}</span>
              </h2>
              <p className="text-[10px] font-bold text-muted uppercase tracking-tight mt-1">
                目前所有品牌提交的智能驾驶里程
              </p>
            </div>
            
            {/* 图例 Legend */}
            <div className="flex flex-wrap gap-3 items-center">
              {[
                { label: '>80', color: '#007AFF' },
                { label: '50-80', color: '#5AC8FA' },
                { label: '20-50', color: '#34C759' },
                { label: '<20', color: '#FFCC00' }
              ].map(item => (
                <div key={item.label} className="flex items-center gap-1.5">
                  <div className="w-2 h-2 rounded-full" style={{ backgroundColor: item.color }}></div>
                  <span className="text-[9px] font-black text-muted uppercase tracking-tighter">{item.label}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="space-y-4 sm:space-y-6">
            {loadingPhase === 'basic' || !stats ? (
              // 🆕 数据加载中，显示骨架屏
              renderCardSkeleton()
            ) : mileageData.length > 0 ? (
              mileageData.slice(0, 10).map((item: any, index: number) => {
              const maxTotalKm = mileageData[0]?.totalKm || 1;
              const relativeWidth = (item.totalKm / maxTotalKm) * 100;
              return (
                <div key={item.brandKey} className="flex items-center gap-4">
                  <span className="w-4 text-sm font-black text-muted/30">{index + 1}</span>
                  <div className="w-10 h-10 bg-[#F5F5F7] rounded-xl flex items-center justify-center">
                    {ArenaService.getLogoUrl(data?.brands || [], item.brandKey) ? (
                      <img src={ArenaService.getLogoUrl(data?.brands || [], item.brandKey)!} className="w-6 h-6 object-contain" alt="" />
                    ) : <span className="text-sm font-black text-gray-300">?</span>}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex justify-between items-baseline mb-2">
                      <span className="text-[12px] sm:text-[13px] font-black text-[#1D1D1F] uppercase truncate mr-2">{item.brand}</span>
                      <span className="text-[12px] sm:text-[13px] text-muted font-normal">{item.totalKm.toFixed(1)} km</span>
                    </div>
                    {/* 分段颜色进度条 - 外层控制品牌总长度，内层控制占比 */}
                    <div 
                      className="h-1.5 bg-[#F5F5F7] rounded-full overflow-hidden flex transition-all duration-1000 shadow-inner"
                      style={{ width: `${relativeWidth}%` }}
                    >
                      {item.totalKm > 0 ? (
                        <>
                          <div className="h-full bg-[#007AFF] transition-all" style={{ width: `${((item.breakdown?.highway || 0) / item.totalKm) * 100}%` }}></div>
                          <div className="h-full bg-[#5AC8FA] transition-all" style={{ width: `${((item.breakdown?.smooth || 0) / item.totalKm) * 100}%` }}></div>
                          <div className="h-full bg-[#34C759] transition-all" style={{ width: `${((item.breakdown?.urban || 0) / item.totalKm) * 100}%` }}></div>
                          <div className="h-full bg-[#FFCC00] transition-all" style={{ width: `${((item.breakdown?.congested || 0) / item.totalKm) * 100}%` }}></div>
                        </>
                      ) : (
                        <div className="h-full bg-gray-100 w-full"></div>
                      )}
                    </div>
                  </div>
                </div>
              );
            })
            ) : (
              <div className="text-center text-muted py-8">No data available</div>
            )}
          </div>
        </div>

        {/* 贡献榜 */}
        <div className="bg-white rounded-[1.25rem] p-5 sm:p-8 card-shadow border border-gray-100">
          <div className="flex justify-between items-start mb-6">
            <h2 className="text-sm sm:text-base font-bold text-[#1D1D1F] flex items-center gap-2">
              <Crown className="text-[#FF9500]" size={18} />
              <span>{t('contribution')}</span>
            </h2>
            <div className="flex bg-[#F5F5F7] p-1 rounded-xl">
              <button onClick={() => setLeaderboardWeekly(true)} className={`px-3 py-1.5 rounded-lg text-[10px] font-black ${leaderboardWeekly ? 'bg-white shadow-sm text-[#007AFF]' : 'text-muted'}`}>{t('weekly_rank')}</button>
              <button onClick={() => setLeaderboardWeekly(false)} className={`px-3 py-1.5 rounded-lg text-[10px] font-black ${!leaderboardWeekly ? 'bg-white shadow-sm text-[#007AFF]' : 'text-muted'}`}>{t('total_rank')}</button>
            </div>
          </div>
          <div className="space-y-4 sm:space-y-6">
            {loadingPhase === 'basic' || !stats ? (
              // 🆕 数据加载中，显示骨架屏
              renderCardSkeleton()
            ) : userLeaderboardData.length > 0 ? (
              userLeaderboardData.map((item: any, index: number) => (
              <div key={item.userName} className="flex items-center gap-3">
                <span className="w-4 text-sm font-black text-muted/30">{index + 1}</span>
                <div className="w-10 h-10 bg-[#F5F5F7] rounded-xl flex items-center justify-center overflow-hidden">
                  {item.avatarUrl ? (
                    <img src={item.avatarUrl} className="w-full h-full object-cover" alt="" />
                  ) : (
                    <User size={16} className="text-gray-300" />
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex justify-between text-[12px] sm:text-[13px] font-black mb-1.5">
                    <span className="truncate uppercase">{item.userName}</span>
                    <span className="text-muted font-normal">{item.totalKm.toFixed(1)} km</span>
                  </div>
                  <div className="h-1.5 bg-[#F5F5F7] rounded-full overflow-hidden">
                    <div className="h-full bg-[#FF9500] rounded-full" style={{ width: `${(item.totalKm / (userLeaderboardData[0]?.totalKm || 1)) * 100}%` }}></div>
                  </div>
                </div>
              </div>
            ))
            ) : (
              <div className="text-center text-muted py-8">No data available</div>
            )}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6">
        {/* 进化图表 */}
        <div className="bg-white rounded-[1.25rem] p-5 sm:p-8 card-shadow border border-gray-100 flex flex-col">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-sm sm:text-base font-bold text-[#1D1D1F] flex items-center gap-2">
              <TrendingUp className="text-[#007AFF]" size={18} />
              <span>{t('evolution')}</span>
            </h2>
            <select value={evoBrand} onChange={(e) => setEvoBrand(e.target.value)} className="bg-[#F5F5F7] rounded-xl px-3 py-1.5 text-[10px] font-black outline-none cursor-pointer">
              {brandOptions.map((b: any) => <option key={b.key} value={b.key}>{b.name}</option>)}
            </select>
          </div>
          <div className="flex-1 min-h-[250px] sm:min-h-[300px] relative w-full">
            {loadingPhase === 'basic' || !stats ? (
              // 🆕 数据加载中，显示骨架屏
              <div className="w-full h-full flex items-center justify-center">
                <div className="animate-pulse space-y-3 w-full">
                  <div className="h-48 bg-gray-100 rounded-xl"></div>
                  <div className="h-6 bg-gray-100 rounded-lg w-3/4 mx-auto"></div>
                </div>
              </div>
            ) : evolutionData && evolutionData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%" minHeight={250}>
                <BarChart data={evolutionData} barSize={45} margin={{ top: 20, right: 10, left: -20, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#F0F0F0" />
                  <XAxis 
                    dataKey="version" 
                    axisLine={false} 
                    tickLine={false} 
                    tick={{fontSize: 12, fontWeight: 800}}
                    dy={10}
                  />
                  <YAxis axisLine={false} tickLine={false} tick={{fontSize: 12}} domain={yAxisDomain} ticks={yAxisTicks} />
                  <Tooltip 
                    cursor={{ fill: 'transparent' }} 
                    formatter={(value: number) => [`${value.toFixed(1)} ${t('km_per_event')}`, ""]}
                    separator=""
                    contentStyle={{ fontSize: 12, borderRadius: '12px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)', fontWeight: 800 }}
                  />
                  <Bar dataKey="kmPerEvent" fill="#007AFF" radius={[6, 6, 0, 0]}>
                    <LabelList dataKey="kmPerEvent" position="top" formatter={(val: number) => val.toFixed(1)} style={{ fontSize: 12, fontWeight: 800, fill: '#007AFF' }} />
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="w-full h-full flex flex-col items-center justify-center text-muted/40">
                <TrendingUp size={40} strokeWidth={1} className="mb-2" />
                <p className="text-[10px] font-black uppercase tracking-widest">No data for this brand</p>
              </div>
            )}
          </div>
        </div>

        {/* 症状分布 */}
        <div className="bg-white rounded-[1.25rem] p-5 sm:p-8 card-shadow border border-gray-100 flex flex-col">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-sm sm:text-base font-bold text-[#1D1D1F] flex items-center gap-2">
              <Activity className="text-[#FF3B30]" size={18} />
              <span>{t('symptoms')}</span>
            </h2>
            <select value={symptomBrand} onChange={(e) => setSymptomBrand(e.target.value)} className="bg-[#F5F5F7] rounded-xl px-3 py-1.5 text-[10px] font-black outline-none cursor-pointer">
              {brandOptions.map((b: any) => <option key={b.key} value={b.key}>{b.name}</option>)}
            </select>
          </div>
          <div className="flex-1 flex flex-col justify-center">
            {loadingPhase === 'basic' || !stats ? (
              // 🆕 数据加载中，显示骨架屏
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 animate-pulse">
                {[1, 2, 3, 4, 5].map(i => (
                  <div key={i} className="flex flex-col items-center py-4 px-3 bg-gray-100 rounded-2xl h-32"></div>
                ))}
              </div>
            ) : (
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
              {[
                { id: 'rapidAcceleration', label: t('accel'), color: '#FF9500', icon: Zap },
                { id: 'rapidDeceleration', label: t('brake'), color: '#FF3B30', icon: TrendingDown },
                { id: 'jerk', label: t('jerk'), color: '#5856D6', icon: AlertCircle },
                { id: 'bump', label: t('bump'), color: '#AF52DE', icon: Activity },
                { id: 'wobble', label: t('wobble'), color: '#007AFF', icon: Waves }
              ].map(type => (
                <div key={type.id} className="flex flex-col items-center py-4 px-3 bg-[#F5F5F7]/50 rounded-2xl">
                  <div className="w-10 h-10 rounded-full flex items-center justify-center mb-1.5" style={{ backgroundColor: `${type.color}10`, color: type.color }}>
                    <type.icon size={20} />
                  </div>
                  <span className="text-[12px] font-black text-muted uppercase mb-1">{type.label}</span>
                  <span className="text-lg font-black text-[#1D1D1F]">{symptomDetails[type.id] ? symptomDetails[type.id].toFixed(1) : '---'}</span>
                  <span className="text-[11px] font-bold text-[#007AFF]">×{symptomCounts[type.id] || 0}</span>
                </div>
              ))}
            </div>
            )}
          </div>
        </div>
      </div>

      {/* 底部提示文字 */}
      <footer className="mt-12 mb-8 text-center">
        <p className="text-[11px] font-black text-muted/40 uppercase tracking-[0.2em]">
          {t('arena_mileage_requirement')}
        </p>
      </footer>
    </div>
  );
};

export default ArenaPage;
