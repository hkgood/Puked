import React from 'react';

interface BaseModalProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  subtitle?: string;
  icon?: React.ReactNode;
  children: React.ReactNode;
  footer?: React.ReactNode;
  maxWidth?: string;
  isSubmitting?: boolean;
}

const BaseModal: React.FC<BaseModalProps> = ({
  isOpen,
  onClose,
  title,
  subtitle,
  icon,
  children,
  footer,
  maxWidth = 'max-w-lg',
  isSubmitting = false
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[2000] flex items-center justify-center p-4">
      <div 
        className="absolute inset-0 bg-black/40 backdrop-blur-sm" 
        onClick={() => !isSubmitting && onClose()}
      />
      <div className={`relative bg-white rounded-[2rem] shadow-2xl w-full ${maxWidth} overflow-hidden animate-in fade-in zoom-in duration-200`}>
        <div className="p-8">
          <div className="flex items-center gap-4 mb-6">
            {icon && (
              <div className="w-12 h-12 bg-[#F5F5F7] rounded-2xl flex items-center justify-center">
                {icon}
              </div>
            )}
            <div>
              <h3 className="text-xl font-black tracking-tight">{title}</h3>
              {subtitle && <p className="text-xs font-bold text-muted">{subtitle}</p>}
            </div>
          </div>
          {children}
        </div>
        {footer && (
          <div className="p-4 bg-[#F5F5F7] flex gap-3">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
};

export default BaseModal;
