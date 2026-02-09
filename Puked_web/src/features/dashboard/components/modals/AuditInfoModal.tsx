import React from 'react';
import { SearchCode } from 'lucide-react';
import BaseModal from './BaseModal';
import { useI18n } from '../../../../common/utils/i18n';

interface AuditInfoModalProps {
  isOpen: boolean;
  onClose: () => void;
  auditResult: { count: number, new: number, total: number } | null;
}

const AuditInfoModal: React.FC<AuditInfoModalProps> = ({
  isOpen,
  onClose,
  auditResult
}) => {
  const { t } = useI18n();

  return (
    <BaseModal
      isOpen={isOpen}
      onClose={onClose}
      title={t('audit_completed')}
      subtitle={t('audit_engine')}
      icon={<SearchCode size={24} className="text-[#007AFF]" />}
      footer={
        <button 
          onClick={onClose}
          className="flex-1 py-4 bg-[#1D1D1F] text-white rounded-xl text-[11px] font-black uppercase shadow-lg flex items-center justify-center gap-2 active:scale-95 transition-all"
        >
          {t('ok')}
        </button>
      }
    >
      <div className="text-sm text-[#1D1D1F] leading-relaxed font-medium">
        {auditResult?.count === 0 ? (
          t('audit_no_new')
        ) : (
          t('audit_summary')
            .replace('{count}', auditResult?.count.toString() || '0')
            .replace('{new}', auditResult?.new.toString() || '0')
            .replace('{total}', auditResult?.total.toString() || '0')
        )}
      </div>
    </BaseModal>
  );
};

export default AuditInfoModal;
