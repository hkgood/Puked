import { 
  Zap, 
  ArrowDownCircle, 
  AlertTriangle, 
  Activity, 
  Navigation, 
  AlertOctagon,
  AlertCircle
} from 'lucide-react';
import React from 'react';

/**
 * 物理常量
 */
export const G_FORCE = 9.80665;

/**
 * 页面标签定义
 */
export type DashboardTab = 'users' | 'trips' | 'brands' | 'stats';

/**
 * 图表缩放级别
 */
export type ChartScale = 'full' | '5km' | '10km' | '50km';

/**
 * 事件类型定义与样式映射
 */
export interface EventStyle {
  icon: React.ReactNode;
  color: string;
  rawColor: string;
  lineColor: string;
  bg: string;
  labelKey: string;
}

export const EVENT_STYLES: Record<string, EventStyle> = {
  rapidAcceleration: { 
    icon: <Zap size={20} />, 
    color: 'text-amber-500', 
    rawColor: '#F59E0B', 
    lineColor: 'rgba(245, 158, 11, 0.4)', 
    bg: 'bg-amber-50', 
    labelKey: 'rapid_accel' 
  },
  rapid_accel: { 
    icon: <Zap size={20} />, 
    color: 'text-amber-500', 
    rawColor: '#F59E0B', 
    lineColor: 'rgba(245, 158, 11, 0.4)', 
    bg: 'bg-amber-50', 
    labelKey: 'rapid_accel' 
  },
  accel: { 
    icon: <Zap size={20} />, 
    color: 'text-amber-500', 
    rawColor: '#F59E0B', 
    lineColor: 'rgba(245, 158, 11, 0.4)', 
    bg: 'bg-amber-50', 
    labelKey: 'rapid_accel' 
  },
  rapidDeceleration: { 
    icon: <ArrowDownCircle size={20} />, 
    color: 'text-red-500', 
    rawColor: '#EF4444', 
    lineColor: 'rgba(239, 68, 68, 0.4)', 
    bg: 'bg-red-50', 
    labelKey: 'rapid_decel' 
  },
  rapid_decel: { 
    icon: <ArrowDownCircle size={20} />, 
    color: 'text-red-500', 
    rawColor: '#EF4444', 
    lineColor: 'rgba(239, 68, 68, 0.4)', 
    bg: 'bg-red-50', 
    labelKey: 'rapid_decel' 
  },
  brake: { 
    icon: <ArrowDownCircle size={20} />, 
    color: 'text-red-500', 
    rawColor: '#EF4444', 
    lineColor: 'rgba(239, 68, 68, 0.4)', 
    bg: 'bg-red-50', 
    labelKey: 'rapid_decel' 
  },
  jerk: { 
    icon: <AlertTriangle size={20} />, 
    color: 'text-indigo-500', 
    rawColor: '#6366F1', 
    lineColor: 'rgba(99, 102, 241, 0.4)', 
    bg: 'bg-indigo-50', 
    labelKey: 'jerk' 
  },
  bump: { 
    icon: <Activity size={20} />, 
    color: 'text-orange-500', 
    rawColor: '#FF9500', 
    lineColor: 'rgba(255, 149, 0, 0.4)', 
    bg: 'bg-orange-50', 
    labelKey: 'bump' 
  },
  wobble: { 
    icon: <Activity size={20} />, 
    color: 'text-purple-500', 
    rawColor: '#AF52DE', 
    lineColor: 'rgba(175, 82, 222, 0.4)', 
    bg: 'bg-purple-50', 
    labelKey: 'wobble' 
  },
  proDisengagement: { 
    icon: <Navigation size={20} />, 
    color: 'text-red-500', 
    rawColor: '#EF4444', 
    lineColor: 'rgba(239, 68, 68, 0.4)', 
    bg: 'bg-red-50', 
    labelKey: 'proDisengagement' 
  },
  proViolation: { 
    icon: <AlertOctagon size={20} />, 
    color: 'text-indigo-500', 
    rawColor: '#6366F1', 
    lineColor: 'rgba(99, 102, 241, 0.4)', 
    bg: 'bg-indigo-50', 
    labelKey: 'proViolation' 
  },
  proExperience: { 
    icon: <Activity size={20} />, 
    color: 'text-blue-500', 
    rawColor: '#007AFF', 
    lineColor: 'rgba(0, 122, 255, 0.4)', 
    bg: 'bg-blue-50', 
    labelKey: 'proExperience' 
  },
};

export const DEFAULT_EVENT_STYLE: EventStyle = { 
  icon: <AlertCircle size={20} />, 
  color: 'text-muted', 
  rawColor: '#86868B', 
  lineColor: 'rgba(134, 134, 139, 0.2)', 
  bg: 'bg-gray-50', 
  labelKey: '' 
};
