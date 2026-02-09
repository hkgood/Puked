import React, { useState, useEffect } from 'react';
import { pb } from '../../../services/pocketbase';
import type { UserRecord } from '../../../models/types';
import { TrendingUp, Award, BarChart3, Activity, Loader2 } from 'lucide-react';
import { useI18n } from '../../../common/utils/i18n';

interface UserStatsPayload {
  totalMileage: number;
  globalTotalMileage: number;
  totalEvents: number;
  brandDistribution: Record<string, number>;
  pukedValue: number;
  rank: number;
  totalUsers: number;
  updated_at: string;
}

interface UserStatsRecord {
  id: string;
  user_id: string;
  payload: UserStatsPayload;
}

interface UserBasicStatsProps {
  user: UserRecord;
}

/**
 * 用户基本统计卡片
 * 
 * 显示：
 * 1. 上传里程
 * 2. 里程贡献度
 * 3. Puked 排名
 * 4. Puked 值
 */
const UserBasicStats: React.FC<UserBasicStatsProps> = ({ user }) => {
  const { t } = useI18n();
  const [stats, setStats] = useState<UserStatsPayload | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadUserStats();
  }, [user.id]);

  const loadUserStats = async () => {
    setLoading(true);
    setError(null);
    
    try {
      const record = await pb.collection('user_stats').getFirstListItem<UserStatsRecord>(
        `user_id = "${user.id}"`,
        { requestKey: null }
      );
      
      setStats(record.payload);
    } catch (e: any) {
      console.error('Failed to load user stats:', e);
      if (e.status === 404) {
        setError(t('no_stats_data'));
      } else {
        setError(t('load_failed'));
      }
    } finally {
      setLoading(false);
    }
  };

  // 计算里程贡献度百分比
  const contributionPercentage = stats 
    ? ((stats.totalMileage / stats.globalTotalMileage) * 100).toFixed(2)
    : '0';

  // 计算排名百分位
  const rankPercentile = stats
    ? (((stats.totalUsers - stats.rank + 1) / stats.totalUsers) * 100).toFixed(0)
    : '0';

  if (loading) {
    return (
      <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100 flex flex-col items-center justify-center min-h-[320px]">
        <Loader2 size={32} className="text-[#007AFF] animate-spin mb-4" />
        <p className="text-sm text-muted">{t('loading_stats')}</p>
      </div>
    );
  }

  if (error || !stats) {
    return (
      <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100 flex flex-col items-center justify-center min-h-[320px]">
        <Activity size={48} className="text-muted opacity-20 mb-4" />
        <p className="text-sm text-muted">{error || t('no_stats_data')}</p>
        <p className="text-xs text-muted mt-2 opacity-60">{t('user_need_upload')}</p>
      </div>
    );
  }

  return (
    <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100 flex flex-col">
      <div className="text-[10px] font-black text-muted uppercase mb-6 text-center">{t('user_data')}</div>
      
      <div className="grid grid-cols-2 gap-4">
        {/* 上传里程 */}
        <div className="flex flex-col items-center p-4 bg-[#007AFF]/5 rounded-2xl">
          <div className="p-2 bg-[#007AFF]/10 rounded-xl mb-3">
            <TrendingUp size={20} className="text-[#007AFF]" />
          </div>
          <div className="text-[9px] text-muted uppercase tracking-wider mb-2 text-center">{t('uploaded_mileage')}</div>
          <div className="font-black text-xl text-[#1D1D1F] text-center">
            {stats.totalMileage.toLocaleString()}
          </div>
          <div className="text-[10px] font-normal text-muted mt-1">km</div>
        </div>

        {/* 里程贡献度 */}
        <div className="flex flex-col items-center p-4 bg-[#248A3D]/5 rounded-2xl">
          <div className="p-2 bg-[#248A3D]/10 rounded-xl mb-3">
            <BarChart3 size={20} className="text-[#248A3D]" />
          </div>
          <div className="text-[9px] text-muted uppercase tracking-wider mb-2 text-center">{t('mileage_contribution')}</div>
          <div className="font-black text-xl text-[#1D1D1F] text-center">
            {contributionPercentage}
          </div>
          <div className="text-[10px] font-normal text-muted mt-1">%</div>
        </div>

        {/* Puked 排名 */}
        <div className="flex flex-col items-center p-4 bg-[#FF9500]/5 rounded-2xl">
          <div className="p-2 bg-[#FF9500]/10 rounded-xl mb-3">
            <Award size={20} className="text-[#FF9500]" />
          </div>
          <div className="text-[9px] text-muted uppercase tracking-wider mb-2 text-center">{t('puked_ranking')}</div>
          <div className="font-black text-xl text-[#1D1D1F] text-center">
            #{stats.rank}
          </div>
          <div className="text-[10px] font-normal text-muted mt-1">
            / {stats.totalUsers} ({t('top_percentage').replace('{percent}', rankPercentile)})
          </div>
        </div>

        {/* Puked 值 */}
        <div className="flex flex-col items-center p-4 bg-[#5856D6]/5 rounded-2xl">
          <div className="p-2 bg-[#5856D6]/10 rounded-xl mb-3">
            <Activity size={20} className="text-[#5856D6]" />
          </div>
          <div className="text-[9px] text-muted uppercase tracking-wider mb-2 text-center">{t('puked_value')}</div>
          <div className="font-black text-xl text-[#1D1D1F] text-center">
            {stats.pukedValue.toFixed(2)}
          </div>
          <div className="text-[10px] font-normal text-muted mt-1">km/{t('events')}</div>
        </div>
      </div>

      {/* 更新时间 */}
      <div className="text-[9px] text-muted text-center pt-4 mt-4 border-t border-gray-100">
        {t('updated_at')}：{new Date(stats.updated_at).toLocaleString()}
      </div>
    </div>
  );
};

export default UserBasicStats;
