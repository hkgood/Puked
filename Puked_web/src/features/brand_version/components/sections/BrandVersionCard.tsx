import React, { useEffect } from 'react';
import { Plus, Trash2, Check, X } from 'lucide-react';
import { useI18n } from '../../../../common/utils/i18n';
import { getFileUrl } from '../../../../services/pocketbase';
import type { BrandRecord, SoftwareVersionRecord } from '../../../../models/types';

interface BrandVersionCardProps {
  brand: BrandRecord;
  versions: SoftwareVersionRecord[];
  loading: boolean;
  onLoad: () => void;
  isAddingVersion: boolean;
  onAddClick: () => void;
  editingVersionId: string | null;
  versionInput: string;
  onVersionInputChange: (val: string) => void;
  onEditVersion: (version: SoftwareVersionRecord) => void;
  onCancelEdit: () => void;
  onUpdateVersion: (id: string) => void;
  onDeleteVersion: (id: string) => void;
  onAddVersion: () => void;
  onCancelAdd: () => void;
}

const BrandVersionCard: React.FC<BrandVersionCardProps> = ({ 
  brand, 
  versions, 
  loading, 
  onLoad, 
  isAddingVersion, 
  onAddClick,
  editingVersionId,
  versionInput,
  onVersionInputChange,
  onEditVersion,
  onCancelEdit,
  onUpdateVersion,
  onDeleteVersion,
  onAddVersion,
  onCancelAdd
}) => {
  const { t } = useI18n();
  
  useEffect(() => {
    onLoad();
  }, []);

  return (
    <div className="bg-[#F2F2F7] rounded-3xl p-5 border border-transparent hover:border-gray-100 hover:bg-white hover:shadow-xl hover:shadow-black/[0.02] transition-all flex flex-col h-[320px]">
      <div className="flex justify-between items-center mb-4">
        <div className="flex items-center gap-2 overflow-hidden">
          <div className="w-8 h-8 bg-white rounded-lg flex items-center justify-center border border-gray-100 flex-shrink-0">
            {brand.logo ? (
              <img src={getFileUrl(brand, brand.logo) || ''} alt={brand.displayName} className="w-full h-full object-contain p-1" />
            ) : (
              <span className="text-[10px] font-black text-muted uppercase">{brand.name.substring(0,2)}</span>
            )}
          </div>
          <h3 className="font-black text-[#1D1D1F] text-sm truncate uppercase tracking-tight">{brand.displayName || brand.name}</h3>
        </div>
        <button 
          onClick={onAddClick}
          className="p-1.5 bg-white text-[#248A3D] hover:bg-[#248A3D] hover:text-white rounded-lg transition-all shadow-sm"
        >
          <Plus size={16} />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto pr-1 space-y-2 custom-scrollbar">
        {loading && versions.length === 0 ? (
          <div className="h-full flex flex-col items-center justify-center gap-2">
            <div className="w-5 h-5 border-2 border-[#248A3D]/20 border-t-[#248A3D] rounded-full animate-spin"></div>
            <span className="text-[10px] font-black text-muted uppercase tracking-widest">{t('loading')}</span>
          </div>
        ) : (
          <>
            {isAddingVersion && (
              <div className="p-2 bg-white rounded-xl border-2 border-[#248A3D] animate-in zoom-in-95 duration-200">
                <input 
                  autoFocus
                  value={versionInput}
                  onChange={(e) => onVersionInputChange(e.target.value)}
                  placeholder={t('version_short')}
                  className="w-full bg-[#F5F5F7] rounded-lg px-3 py-2 text-xs font-bold outline-none mb-2"
                  onKeyDown={(e) => e.key === 'Enter' && onAddVersion()}
                />
                <div className="flex justify-end gap-1">
                  <button onClick={onCancelAdd} className="p-1.5 text-[10px] font-black uppercase text-muted hover:bg-gray-100 rounded-md">
                    <X size={12} />
                  </button>
                  <button onClick={onAddVersion} className="p-1.5 bg-[#248A3D] text-white rounded-md">
                    <Check size={12} />
                  </button>
                </div>
              </div>
            )}

            {versions.length === 0 && !isAddingVersion ? (
              <div className="h-full flex items-center justify-center text-[10px] font-bold text-muted opacity-30 italic">{t('no_versions')}</div>
            ) : (
              versions.map((version: any) => (
                <div key={version.id} className="group/item flex items-center justify-between p-3 bg-white rounded-xl border border-transparent hover:border-gray-100 shadow-sm transition-all">
                  {editingVersionId === version.id ? (
                    <div className="flex-1 flex items-center gap-1">
                      <input 
                        autoFocus
                        value={versionInput}
                        onChange={(e) => onVersionInputChange(e.target.value)}
                        className="flex-1 bg-[#F5F5F7] rounded-lg px-2 py-1 text-xs font-bold outline-none border border-[#248A3D]"
                        onKeyDown={(e) => e.key === 'Enter' && onUpdateVersion(version.id)}
                      />
                      <button onClick={() => onUpdateVersion(version.id)} className="p-1 bg-[#248A3D] text-white rounded-md"><Check size={12}/></button>
                      <button onClick={onCancelEdit} className="p-1 bg-gray-100 text-muted rounded-md"><X size={12}/></button>
                    </div>
                  ) : (
                    <>
                      <span 
                        className="font-bold text-[#1D1D1F] text-xs truncate cursor-pointer"
                        onClick={() => onEditVersion(version)}
                      >
                        {version.versionString}
                      </span>
                      <button 
                        onClick={() => onDeleteVersion(version.id)}
                        className="opacity-0 group-hover/item:opacity-100 p-1 text-muted hover:text-[#FF3B30] transition-all"
                      >
                        <Trash2 size={12} />
                      </button>
                    </>
                  )}
                </div>
              ))
            )}
          </>
        )}
      </div>
    </div>
  );
};

export default React.memo(BrandVersionCard);
