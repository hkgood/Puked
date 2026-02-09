import React, { useRef } from 'react';
import { X, Upload } from 'lucide-react';
import { useI18n } from '../../../../common/utils/i18n';
import type { BrandRecord } from '../../../../models/types';

interface BrandEditModalProps {
  isOpen: boolean;
  onClose: () => void;
  selectedBrand: BrandRecord | null;
  brandFormData: {
    displayName: string;
    isEnabled: boolean;
    order: number;
    logoFile: File | null;
    logoPreview: string;
  };
  setBrandFormData: React.Dispatch<React.SetStateAction<any>>;
  handleLogoChange: (e: React.ChangeEvent<HTMLInputElement>) => void;
  handleSaveBrand: () => Promise<void>;
  loading: boolean;
}

const BrandEditModal: React.FC<BrandEditModalProps> = ({
  isOpen,
  onClose,
  selectedBrand,
  brandFormData,
  setBrandFormData,
  handleLogoChange,
  handleSaveBrand,
  loading
}) => {
  const { t } = useI18n();
  const fileInputRef = useRef<HTMLInputElement>(null);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[200] flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={() => !loading && onClose()} />
      <div className="relative bg-white rounded-t-[2rem] sm:rounded-[2.5rem] p-6 sm:p-10 shadow-2xl border border-gray-100 w-full max-w-lg animate-in slide-in-from-bottom sm:slide-in-from-bottom-0 sm:zoom-in duration-300">
        <div className="flex justify-between items-start mb-6 sm:mb-8">
          <div>
            <h3 className="text-xl sm:text-2xl font-black text-[#1D1D1F] tracking-tighter mb-1 sm:mb-2">
              {selectedBrand ? t('edit_brand') : t('add_brand')}
            </h3>
            <p className="text-[9px] sm:text-[10px] font-bold text-muted uppercase tracking-widest opacity-60">{t('brand_profile_settings')}</p>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-full transition-colors">
            <X className="w-5 h-5 sm:w-6 sm:h-6 text-muted" />
          </button>
        </div>
        
        <div className="space-y-6 sm:space-y-8">
          {/* Logo Upload Section */}
          <div className="flex flex-col items-center gap-3 sm:gap-4">
            <div 
              onClick={() => fileInputRef.current?.click()}
              className="w-20 h-20 sm:w-24 sm:h-24 bg-[#F5F5F7] rounded-2xl sm:rounded-3xl border-2 border-dashed border-gray-200 flex items-center justify-center cursor-pointer hover:border-[#007AFF] hover:bg-[#007AFF]/5 transition-all overflow-hidden relative group"
            >
              {brandFormData.logoPreview ? (
                <>
                  <img src={brandFormData.logoPreview} alt="Preview" className="w-full h-full object-contain p-2" />
                  <div className="absolute inset-0 bg-black/40 md:opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                    <Upload className="w-5 h-5 sm:w-6 sm:h-6 text-white" />
                  </div>
                </>
              ) : (
                <Upload className="w-6 h-6 sm:w-8 sm:h-8 text-muted opacity-40" />
              )}
              <input 
                type="file" 
                ref={fileInputRef} 
                onChange={handleLogoChange} 
                accept="image/svg+xml,image/png,image/jpeg"
                className="hidden" 
              />
            </div>
            <span className="text-[9px] sm:text-[10px] font-black text-muted uppercase tracking-[0.2em]">{t('logo')}</span>
          </div>

          <div className="space-y-4 sm:space-y-6">
            <div>
              <label className="text-[9px] sm:text-[10px] font-black text-muted uppercase tracking-[0.2em] mb-1.5 sm:mb-2 block">{t('display_name')}</label>
              <input
                type="text"
                value={brandFormData.displayName}
                onChange={(e) => setBrandFormData((prev: any) => ({ ...prev, displayName: e.target.value }))}
                placeholder="e.g. Tesla"
                className="w-full bg-[#F5F5F7] rounded-2xl px-5 sm:px-6 py-3 sm:py-4 text-base sm:text-lg font-bold outline-none border-2 border-transparent focus:border-[#007AFF] transition-all"
              />
            </div>

            <div>
              <label className="text-[9px] sm:text-[10px] font-black text-muted uppercase tracking-[0.2em] mb-1.5 sm:mb-2 block">{t('display_order')}</label>
              <input
                type="number"
                value={brandFormData.order}
                onChange={(e) => setBrandFormData((prev: any) => ({ ...prev, order: parseInt(e.target.value) || 0 }))}
                placeholder="0"
                className="w-full bg-[#F5F5F7] rounded-2xl px-5 sm:px-6 py-3 sm:py-4 text-base sm:text-lg font-bold outline-none border-2 border-transparent focus:border-[#007AFF] transition-all"
              />
            </div>
            
            <div className="flex items-center justify-between bg-[#F5F5F7] p-4 sm:p-6 rounded-2xl">
              <div>
                <div className="text-sm sm:text-base font-black text-[#1D1D1F] tracking-tight">{t('is_enabled')}</div>
                <div className="text-[9px] sm:text-[10px] font-bold text-muted uppercase tracking-widest mt-0.5">{t('visible_in_app')}</div>
              </div>
              <button 
                onClick={() => setBrandFormData((prev: any) => ({ ...prev, isEnabled: !prev.isEnabled }))}
                className={`w-12 h-7 sm:w-14 sm:h-8 rounded-full transition-all relative ${brandFormData.isEnabled ? 'bg-[#248A3D]' : 'bg-gray-300'}`}
              >
                <div className={`absolute top-0.5 sm:top-1 w-6 h-6 bg-white rounded-full transition-all shadow-sm ${brandFormData.isEnabled ? 'left-5 sm:left-7' : 'left-1'}`} />
              </button>
            </div>
          </div>
          
          <div className="flex gap-3 sm:gap-4 pt-4 pb-6 sm:pb-0">
            <button
              onClick={onClose}
              disabled={loading}
              className="flex-1 py-3 sm:py-4 rounded-2xl text-[11px] sm:text-[12px] font-black uppercase tracking-widest text-muted hover:bg-gray-100 transition-all active:scale-95"
            >
              {t('cancel')}
            </button>
            <button
              onClick={handleSaveBrand}
              disabled={loading || !brandFormData.displayName}
              className="flex-1 bg-[#1D1D1F] text-white py-3 sm:py-4 rounded-2xl text-[11px] sm:text-[12px] font-black uppercase tracking-widest hover:bg-[#007AFF] disabled:opacity-50 transition-all active:scale-95 shadow-lg shadow-black/5"
            >
              {loading ? '...' : t('save')}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default React.memo(BrandEditModal);
