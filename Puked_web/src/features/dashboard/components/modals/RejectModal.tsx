import React from 'react';
import { Mail, Send } from 'lucide-react';
import BaseModal from './BaseModal';
import { useI18n } from '../../../../common/utils/i18n';

interface RejectModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (reason: string) => void;
  email: string;
  isSubmitting: boolean;
}

const RejectModal: React.FC<RejectModalProps> = ({
  isOpen,
  onClose,
  onConfirm,
  email,
  isSubmitting
}) => {
  const { t } = useI18n();
  const [reason, setReason] = React.useState('');

  return (
    <BaseModal
      isOpen={isOpen}
      onClose={onClose}
      title={t('confirm_reject')}
      subtitle={email}
      icon={<Mail size={24} className="text-[#FF3B30]" />}
      isSubmitting={isSubmitting}
      footer={
        <>
          <button 
            onClick={onClose} 
            className="flex-1 py-4 rounded-xl text-[11px] font-black uppercase text-muted hover:text-[#1D1D1F]"
          >
            {t('cancel')}
          </button>
          <button 
            onClick={() => onConfirm(reason)} 
            disabled={isSubmitting || !reason.trim()} 
            className="flex-1 py-4 bg-[#FF3B30] text-white rounded-xl text-[11px] font-black uppercase shadow-lg flex items-center justify-center gap-2"
          >
            {isSubmitting ? (
              <div className="w-4 h-4 border-2 border-white/20 border-t-white rounded-full animate-spin" />
            ) : (
              <>
                <Send size={14} /> 
                {t('confirm_reject')}
              </>
            )}
          </button>
        </>
      }
    >
      <textarea 
        value={reason} 
        onChange={e => setReason(e.target.value)} 
        placeholder={t('enter_rejection_reason')} 
        className="w-full h-32 p-4 bg-[#F5F5F7] border-none rounded-2xl text-sm transition-all resize-none outline-none focus:ring-2 focus:ring-[#FF3B30]/20"
      />
    </BaseModal>
  );
};

export default RejectModal;
