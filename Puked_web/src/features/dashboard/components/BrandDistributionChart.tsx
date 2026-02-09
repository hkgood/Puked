import React, { useState, useEffect } from 'react';
import { pb } from '../../../services/pocketbase';
import { BrandVersionService } from '../../../brand_version/services/brandVersionService';
import type { UserRecord, BrandRecord } from '../../../models/types';
import { Loader2, Activity } from 'lucide-react';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';
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

interface BrandDistributionChartProps {
  user: UserRecord;
}

/**
 * 品牌里程分布图表
 * 
 * 显示圆环图和详细图例
 */
const BrandDistributionChart: React.FC<BrandDistributionChartProps> = ({ user }) => {
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
      console.error('Failed to load brand distribution:', e);
      if (e.status === 404) {
        setError(t('no_stats_data'));
      } else {
        setError(t('load_failed'));
      }
    } finally {
      setLoading(false);
    }
  };

  const getBrandLogoUrl = (brandName: string): string | null => {
    const brand = brands.find(
      b => b.displayName.toLowerCase() === brandName.toLowerCase() ||
        b.name.toLowerCase() === brandName.toLowerCase()
    );
    return brand && brand.logo ? pb.files.getURL(brand, brand.logo) : null;
  };

  const brandChartData = stats
    ? Object.entries(stats.brandDistribution)
      .map(([brand, mileage]) => ({
        name: brand,
        value: parseFloat(mileage.toFixed(2))
      }))
      .sort((a, b) => b.value - a.value)
    : [];

  const COLORS = [
    '#007AFF', '#248A3D', '#FF3B30', '#FF9500',
    '#5856D6', '#34C759', '#AF52DE', '#FF2D55',
  ];

  if (loading) {
    return (
      <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100 flex flex-col items-center justify-center min-h-[500px]">
        <Loader2 size={32} className="text-[#007AFF] animate-spin mb-4" />
        <p className="text-sm text-muted">{t('loading_chart_data')}</p>
      </div>
    );
  }

  if (error || !stats || brandChartData.length === 0) {
    return (
      <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100 flex flex-col items-center justify-center min-h-[500px]">
        <Activity size={48} className="text-muted opacity-20 mb-4" />
        <p className="text-sm text-muted">{error || t('no_brand_distribution')}</p>
      </div>
    );
  }

  return (
    <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100 flex flex-col">
      <div className="text-[10px] font-black text-muted uppercase mb-6 text-center">
        {t('brand_mileage_distribution')}
      </div>

      {/* 圆环图 */}
      <div className="h-[320px]">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={brandChartData}
              cx="50%"
              cy="50%"
              labelLine={false}
              label={({ percent }) => `${(percent * 100).toFixed(0)}%`}
              outerRadius={100}
              innerRadius={65}
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
      <div className="mt-4 space-y-2">
        {brandChartData.map((item, index) => {
          const logoUrl = getBrandLogoUrl(item.name);
          const percentage = ((item.value / brandChartData.reduce((sum, d) => sum + d.value, 0)) * 100).toFixed(1);

          return (
            <div
              key={item.name}
              className="flex items-center gap-3 px-3 py-2 hover:bg-gray-50 rounded-xl transition-colors"
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
                  className="w-6 h-6 object-contain flex-shrink-0"
                />
              ) : (
                <div className="w-6 h-6 flex-shrink-0" />
              )}

              {/* 品牌名称和数据 */}
              <div className="flex-1 flex items-center justify-between min-w-0">
                <span className="text-[12px] font-bold text-[#1D1D1F] truncate">
                  {item.name}
                </span>
                <span className="text-[11px] text-muted ml-3 flex-shrink-0">
                  {item.value.toFixed(0)} km ({percentage}%)
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default BrandDistributionChart;
