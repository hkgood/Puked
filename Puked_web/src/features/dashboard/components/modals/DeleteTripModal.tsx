import React from 'react';
import { Trash2 } from 'lucide-react';
import BaseModal from './BaseModal';
import { useI18n } from '../../../../common/utils/i18n';

interface DeleteTripModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  tripName: string;
  isSubmitting: boolean;
}

const DeleteTripModal: React.FC<DeleteTripModalProps> = ({
  isOpen,
  onClose,
  onConfirm,
  tripName,
  isSubmitting
}) => {
  const { t } = useI18n();

  return (
    <BaseModal
      isOpen={isOpen}
      onClose={onClose}
      title={t('delete_trip')}
      subtitle={tripName}
      icon={<Trash2 size={24} className="text-[#FF3B30]" />}
      isSubmitting={isSubmitting}
      footer={
        <>
          <button 
            onClick={onClose} 
            disabled={isSubmitting}
            className="flex-1 py-4 rounded-xl text-[11px] font-black uppercase text-muted hover:text-[#1D1D1F]"
          >
            {t('cancel')}
          </button>
          <button 
            onClick={onConfirm} 
            disabled={isSubmitting} 
            className="flex-1 py-4 bg-[#FF3B30] text-white rounded-xl text-[11px] font-black uppercase shadow-lg flex items-center justify-center gap-2 active:scale-95 transition-all"
          >
            {isSubmitting ? (
              <div className="w-4 h-4 border-2 border-white/20 border-t-white rounded-full animate-spin" />
            ) : (
              <>
                <Trash2 size={14} />
                {t('delete')}
              </>
            )}
          </button>
        </>
      }
    >
      <p className="text-sm text-[#1D1D1F] leading-relaxed">
        {t('confirm_delete_trip')}
      </p>
    </BaseModal>
  );
};

export default DeleteTripModal;
