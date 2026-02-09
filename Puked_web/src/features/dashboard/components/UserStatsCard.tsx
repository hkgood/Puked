import React, { useState, useEffect } from 'react';
import { pb } from '../../../services/pocketbase';
import { BrandVersionService } from '../../brand_version/services/brandVersionService';
import type { UserRecord, BrandRecord } from '../../../models/types';
import { TrendingUp, Award, BarChart3, Activity, Loader2 } from 'lucide-react';
import { useI18n } from '../../../common/utils/i18n';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';

interface UserStatsCardProps {
  user: UserRecord;
}

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

/**
 * 用户统计信息卡片
 * 
 * 显示已认证用户的统计数据：
 * 1. 上传里程
 * 2. 里程贡献度
 * 3. Puked 排名
 * 4. Puked 值
 * 5. 品牌里程分布图表
 */
const UserStatsCard: React.FC<UserStatsCardProps> = ({ user }) => {
  const { t } = useI18n();
  const [stats, setStats] = useState<UserStatsPayload | null>(null);
  const [brands, setBrands] = useState<BrandRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadData();
  }, [user.id]);

  const loadData = async () => {
    setLoading(true);
    setError(null);

    try {
      // 并行加载统计数据和品牌列表
      const [statsRecord, brandsData] = await Promise.all([
        pb.collection('user_stats').getFirstListItem<UserStatsRecord>(
          `user_id = "${user.id}"`,
          { requestKey: null }
        ),
        BrandVersionService.getAllBrands()
      ]);

      setStats(statsRecord.payload);
      setBrands(brandsData);
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

  // 获取品牌 Logo URL
  const getBrandLogoUrl = (brandName: string): string | null => {
    const brand = brands.find(
      b => b.displayName.toLowerCase() === brandName.toLowerCase() ||
        b.name.toLowerCase() === brandName.toLowerCase()
    );
    return brand && brand.logo ? pb.files.getURL(brand, brand.logo) : null;
  };

  // 计算里程贡献度百分比
  const contributionPercentage = stats
    ? ((stats.totalMileage / stats.globalTotalMileage) * 100).toFixed(2)
    : '0';

  // 计算排名百分位
  const rankPercentile = stats
    ? (((stats.totalUsers - stats.rank + 1) / stats.totalUsers) * 100).toFixed(0)
    : '0';

  // 准备品牌分布图表数据
  const brandChartData = stats
    ? Object.entries(stats.brandDistribution)
      .map(([brand, mileage]) => ({
        name: brand,
        value: parseFloat(mileage.toFixed(2))
      }))
      .sort((a, b) => b.value - a.value)
    : [];

  // 图表颜色
  const COLORS = [
    '#007AFF', // 蓝色
    '#248A3D', // 绿色
    '#FF3B30', // 红色
    '#FF9500', // 橙色
    '#5856D6', // 紫色
    '#34C759', // 浅绿
    '#AF52DE', // 浅紫
    '#FF2D55', // 粉色
  ];

  if (loading) {
    return (
      <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100 flex flex-col items-center justify-center min-h-[400px]">
        <Loader2 size={32} className="text-[#007AFF] animate-spin mb-4" />
        <p className="text-sm text-muted">{t('loading_stats')}</p>
      </div>
    );
  }

  if (error || !stats) {
    return (
      <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100 flex flex-col items-center justify-center min-h-[400px]">
        <Activity size={48} className="text-muted opacity-20 mb-4" />
        <p className="text-sm text-muted">{error || t('no_stats_data')}</p>
        <p className="text-xs text-muted mt-2 opacity-60">{t('user_need_upload')}</p>
      </div>
    );
  }

  return (
    <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100 flex flex-col">
      <div className="text-[10px] font-black text-muted uppercase mb-6 text-center">{t('user_stats')}</div>

      <div className="space-y-6">
        {/* 上传里程 */}
        <div className="flex items-start gap-4">
          <div className="p-3 bg-[#007AFF]/10 rounded-xl">
            <TrendingUp size={20} className="text-[#007AFF]" />
          </div>
          <div className="flex-1">
            <div className="text-[10px] text-muted uppercase tracking-wider mb-1">{t('uploaded_mileage')}</div>
            <div className="font-black text-2xl text-[#1D1D1F]">
              {stats.totalMileage.toLocaleString()}
              <span className="text-sm font-normal text-muted ml-2">km</span>
            </div>
          </div>
        </div>

        {/* 里程贡献度 */}
        <div className="flex items-start gap-4">
          <div className="p-3 bg-[#248A3D]/10 rounded-xl">
            <BarChart3 size={20} className="text-[#248A3D]" />
          </div>
          <div className="flex-1">
            <div className="text-[10px] text-muted uppercase tracking-wider mb-1">{t('mileage_contribution')}</div>
            <div className="font-black text-2xl text-[#1D1D1F]">
              {contributionPercentage}
              <span className="text-sm font-normal text-muted ml-2">%</span>
            </div>
            <div className="text-xs text-muted mt-1">
              {t('global_total_mileage')}：{stats.globalTotalMileage.toLocaleString()} km
            </div>
          </div>
        </div>

        {/* Puked 排名 */}
        <div className="flex items-start gap-4">
          <div className="p-3 bg-[#FF9500]/10 rounded-xl">
            <Award size={20} className="text-[#FF9500]" />
          </div>
          <div className="flex-1">
            <div className="text-[10px] text-muted uppercase tracking-wider mb-1">{t('puked_ranking')}</div>
            <div className="font-black text-2xl text-[#1D1D1F]">
              #{stats.rank}
              <span className="text-sm font-normal text-muted ml-2">/ {stats.totalUsers}</span>
            </div>
            <div className="text-xs text-muted mt-1">
              {t('top_percentage').replace('{percent}', rankPercentile)}
            </div>
          </div>
        </div>

        {/* Puked 值 */}
        <div className="flex items-start gap-4">
          <div className="p-3 bg-[#5856D6]/10 rounded-xl">
            <Activity size={20} className="text-[#5856D6]" />
          </div>
          <div className="flex-1">
            <div className="text-[10px] text-muted uppercase tracking-wider mb-1">{t('puked_value')}</div>
            <div className="font-black text-2xl text-[#1D1D1F]">
              {stats.pukedValue.toFixed(2)}
              <span className="text-sm font-normal text-muted ml-2">km/{t('events')}</span>
            </div>
            <div className="text-xs text-muted mt-1">
              {t('total_events_count')}：{stats.totalEvents.toLocaleString()}
            </div>
          </div>
        </div>

        {/* 品牌里程分布图表 - 圆环图 */}
        {brandChartData.length > 0 && (
          <div className="pt-4 border-t border-gray-100">
            <div className="text-[10px] font-black text-muted uppercase mb-4 text-center">
              {t('brand_mileage_distribution')}
            </div>
            <div style={{ height: '280px', width: '100%', minHeight: '280px' }}>
              <ResponsiveContainer width="100%" height={280} minHeight={280}>
                <PieChart>
                  <Pie
                    data={brandChartData}
                    cx="50%"
                    cy="45%"
                    labelLine={false}
                    label={({ name, percent }) => `${(percent * 100).toFixed(0)}%`}
                    outerRadius={85}
                    innerRadius={55}
                    fill="#8884d8"
                    dataKey="value"
                    paddingAngle={2}
                  >
                    {brandChartData.map((entry, index) => (
                      <Cell
                        key={`cell-${index}`}
                        fill={COLORS[index % COLORS.length]}
                      />
                    ))}
                  </Pie>
                  <Tooltip
                    formatter={(value: number) => `${value.toFixed(2)} km`}
                    contentStyle={{
                      backgroundColor: 'rgba(255, 255, 255, 0.95)',
                      border: '1px solid #E5E5EA',
                      borderRadius: '12px',
                      padding: '8px 12px',
                      fontSize: '11px'
                    }}
                  />
                </PieChart>
              </ResponsiveContainer>
            </div>
            {/* 自定义图例 - 带品牌 Logo */}
            <div className="mt-2 space-y-2">
              {brandChartData.map((item, index) => {
                const logoUrl = getBrandLogoUrl(item.name);
                const percentage = ((item.value / brandChartData.reduce((sum, d) => sum + d.value, 0)) * 100).toFixed(1);

                return (
                  <div
                    key={item.name}
                    className="flex items-center gap-2 px-2 py-1 hover:bg-gray-50 rounded-lg transition-colors"
                  >
                    {/* 颜色指示器 */}
                    <div
                      className="w-3 h-3 rounded-full flex-shrink-0"
                      style={{ backgroundColor: COLORS[index % COLORS.length] }}
                    />

                    {/* 品牌 Logo */}
                    {logoUrl ? (
                      <img
                        src={logoUrl}
                        alt={item.name}
                        className="w-5 h-5 object-contain flex-shrink-0"
                      />
                    ) : (
                      <div className="w-5 h-5 flex-shrink-0" />
                    )}

                    {/* 品牌名称和数据 */}
                    <div className="flex-1 flex items-center justify-between min-w-0">
                      <span className="text-[11px] font-bold text-[#1D1D1F] truncate">
                        {item.name}
                      </span>
                      <span className="text-[10px] text-muted ml-2 flex-shrink-0">
                        {item.value.toFixed(0)} km ({percentage}%)
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* 更新时间 */}
        <div className="text-[9px] text-muted text-center pt-4 border-t border-gray-100">
          {t('updated_at')}：{new Date(stats.updated_at).toLocaleString()}
        </div>
      </div>
    </div>
  );
};

export default UserStatsCard;
