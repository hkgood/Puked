import React from 'react';
import { Image as ImageIcon } from 'lucide-react';
import { useI18n } from '../../../../../common/utils/i18n';

interface ImageCompressModalProps {
  showConfirmModal: boolean;
  setShowConfirmModal: (value: boolean) => void;
  isCompressing: boolean;
  compressProgress: { current: number; total: number };
  onConfirm: () => void;
  onCancel: () => void;
}

const ImageCompressModal: React.FC<ImageCompressModalProps> = ({
  showConfirmModal,
  setShowConfirmModal,
  isCompressing,
  compressProgress,
  onConfirm,
  onCancel
}) => {
  const { t } = useI18n();

  // 确认压缩弹窗
  if (showConfirmModal && !isCompressing) {
    return (
      <div className="fixed inset-0 z-[5000] flex items-center justify-center p-4">
        <div className="absolute inset-0 bg-white/60 backdrop-blur-xl animate-in fade-in duration-300" onClick={() => setShowConfirmModal(false)}></div>
        <div className="relative w-full max-w-sm bg-white rounded-[2.5rem] shadow-2xl border border-gray-100 p-8 space-y-6 animate-in zoom-in duration-300">
          <div className="flex flex-col items-center text-center space-y-4">
            <div className="w-16 h-16 bg-[#007AFF]/10 text-[#007AFF] rounded-2xl flex items-center justify-center">
              <ImageIcon size={32} />
            </div>
            <div className="space-y-2">
              <h3 className="text-xl font-black text-[#1D1D1F] tracking-tight">{t('compress_confirm_title')}</h3>
              <p className="text-sm font-bold text-muted leading-relaxed">{t('compress_confirm_msg')}</p>
            </div>
          </div>

          <div className="flex gap-3">
            <button
              onClick={() => setShowConfirmModal(false)}
              className="flex-1 py-4 bg-[#F5F5F7] text-[#1D1D1F] rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-gray-200 transition-all active:scale-95"
            >
              {t('global_cancel')}
            </button>
            <button
              onClick={onConfirm}
              className="flex-1 py-4 bg-[#007AFF] text-white rounded-2xl font-black uppercase tracking-widest text-[10px] shadow-lg active:scale-95 transition-all hover:bg-[#0051D5]"
            >
              {t('global_confirm')}
            </button>
          </div>
        </div>
      </div>
    );
  }

  // 压缩进度弹窗
  if (isCompressing) {
    return (
      <div className="fixed inset-0 z-[5000] flex items-center justify-center p-4">
        <div className="absolute inset-0 bg-white/60 backdrop-blur-xl"></div>
        <div className="relative w-full max-w-sm bg-white rounded-[2.5rem] shadow-2xl border border-gray-100 p-8 space-y-6 animate-in zoom-in duration-300">
          <div className="flex flex-col items-center text-center space-y-4">
            <div className="w-16 h-16 bg-[#007AFF]/10 text-[#007AFF] rounded-2xl flex items-center justify-center">
              <ImageIcon size={32} />
            </div>
            <div className="space-y-2">
              <h3 className="text-xl font-black text-[#1D1D1F] tracking-tight">{t('compressing')}</h3>
              <p className="text-sm font-bold text-muted">
                {t('compress_progress')
                  .replace('{current}', compressProgress.current.toString())
                  .replace('{total}', compressProgress.total.toString())}
              </p>
            </div>
          </div>

          <div className="space-y-2">
            <div className="h-4 bg-[#F5F5F7] rounded-full overflow-hidden p-1">
              <div
                className="h-full bg-gradient-to-r from-[#007AFF] to-[#5856D6] rounded-full transition-all duration-300 shadow-sm"
                style={{
                  width: compressProgress.total > 0
                    ? `${(compressProgress.current / compressProgress.total) * 100}%`
                    : '0%'
                }}
              ></div>
            </div>
            <p className="text-xs text-muted text-center font-black">
              {compressProgress.total > 0
                ? `${Math.round((compressProgress.current / compressProgress.total) * 100)}%`
                : '0%'}
            </p>
          </div>

          <div className="flex justify-center">
            <div className="w-8 h-8 border-4 border-blue-200 border-t-blue-500 rounded-full animate-spin"></div>
          </div>

          <div className="flex gap-3">
            <button
              onClick={onCancel}
              className="flex-1 py-4 bg-[#F5F5F7] text-[#1D1D1F] rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-gray-200 transition-all active:scale-95"
            >
              {t('global_cancel')}
            </button>
          </div>
        </div>
      </div>
    );
  }

  return null;
};

export default ImageCompressModal;
