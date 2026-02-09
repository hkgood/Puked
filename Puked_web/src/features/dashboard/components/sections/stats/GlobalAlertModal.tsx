import React from 'react';
import { CheckCircle2, AlertCircle, TrendingUp } from 'lucide-react';
import { useI18n } from '../../../../../common/utils/i18n';

export interface ModalState {
  isOpen: boolean;
  title: string;
  message: string;
  type: 'info' | 'error' | 'success' | 'confirm' | 'warning';
  onConfirm?: () => void;
  confirmText?: string;
  cancelText?: string;
}

interface GlobalAlertModalProps {
  modal: ModalState;
  onClose: () => void;
}

const GlobalAlertModal: React.FC<GlobalAlertModalProps> = ({ modal, onClose }) => {
  const { t } = useI18n();

  if (!modal.isOpen) return null;

  return (
    <div className="fixed inset-0 z-[5000] flex items-center justify-center p-4">
      <div
        className="absolute inset-0 bg-white/60 backdrop-blur-xl animate-in fade-in duration-300"
        onClick={() => modal.type !== 'confirm' && modal.type !== 'warning' && onClose()}
      ></div>
      <div className="relative w-full max-w-sm bg-white rounded-[2.5rem] shadow-2xl border border-gray-100 p-8 space-y-6 animate-in zoom-in duration-300">
        <div className="flex flex-col items-center text-center space-y-4">
          <div className={`w-16 h-16 rounded-2xl flex items-center justify-center ${modal.type === 'success' ? 'bg-green-50 text-green-500' :
              modal.type === 'error' ? 'bg-red-50 text-red-500' :
                modal.type === 'warning' ? 'bg-amber-50 text-amber-500' :
                  'bg-[#007AFF]/10 text-[#007AFF]'
            }`}>
            {modal.type === 'success' && <CheckCircle2 size={32} />}
            {modal.type === 'error' && <AlertCircle size={32} />}
            {modal.type === 'warning' && <AlertCircle size={32} />}
            {(modal.type === 'info' || modal.type === 'confirm') && <TrendingUp size={32} />}
          </div>

          <div className="space-y-2">
            <h3 className="text-xl font-black text-[#1D1D1F] tracking-tight">{modal.title}</h3>
            <p className="text-sm font-bold text-muted leading-relaxed">{modal.message}</p>
          </div>
        </div>

        <div className="flex gap-3">
          {(modal.type === 'confirm' || modal.type === 'warning') && (
            <button
              onClick={onClose}
              className="flex-1 py-4 bg-[#F5F5F7] text-[#1D1D1F] rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-gray-200 transition-all active:scale-95"
            >
              {modal.cancelText || t('global_cancel') || 'Cancel'}
            </button>
          )}
          <button
            onClick={() => {
              onClose();
              if (modal.onConfirm) modal.onConfirm();
            }}
            className={`flex-1 py-4 text-white rounded-2xl font-black uppercase tracking-widest text-[10px] shadow-lg active:scale-95 transition-all ${modal.type === 'error' || modal.type === 'warning' ? 'bg-[#FF3B30] hover:bg-[#D70015]' : 'bg-[#1D1D1F] hover:bg-[#007AFF]'
              }`}
          >
            {modal.confirmText || (modal.type === 'confirm' || modal.type === 'warning' ? (t('global_confirm') || 'Confirm') : (t('ok') || 'OK'))}
          </button>
        </div>
      </div>
    </div>
  );
};

export default GlobalAlertModal;
