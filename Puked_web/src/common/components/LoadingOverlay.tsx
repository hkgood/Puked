import React from 'react';
import { useI18n } from '../utils/i18n';

interface LoadingOverlayProps {
  message?: string;
  className?: string;
}

/**
 * 统一的全屏加载蒙层组件
 * 居中显示，带模糊背景
 */
const LoadingOverlay: React.FC<LoadingOverlayProps> = ({ 
  message, 
  className = '' 
}) => {
  const { t } = useI18n();

  return (
    <div className={`absolute inset-0 z-[1002] backdrop-blur-xl flex items-center justify-center animate-in fade-in duration-500 ${className}`}>
      <div className="flex flex-col items-center gap-4 scale-110">
        <div className="w-12 h-12 border-4 border-[#007AFF]/10 border-t-[#007AFF] rounded-full animate-spin"></div>
        <div className="text-[11px] font-black uppercase tracking-widest text-[#1D1D1F] antialiased">
          {message || t('loading_data')}
        </div>
      </div>
    </div>
  );
};

export default LoadingOverlay;
