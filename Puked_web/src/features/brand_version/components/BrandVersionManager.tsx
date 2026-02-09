import React, { useState, useEffect, useMemo } from 'react';
import { BrandVersionService } from '../services/brandVersionService';
import { getFileUrl } from '../../../services/pocketbase';
import LoadingOverlay from '../../../common/components/LoadingOverlay';
import type { BrandRecord, SoftwareVersionRecord } from '../../../models/types';
import { 
  Plus, 
  Trash2, 
  Car, 
  Box, 
  Eye, 
  EyeOff
} from 'lucide-react';
import { useI18n } from '../../../common/utils/i18n';

// Components
import BrandVersionCard from './sections/BrandVersionCard';
import BrandEditModal from './modals/BrandEditModal';

const BrandVersionManager = () => {
  const { t } = useI18n();
  const responsivePadding = "p-5 sm:p-8";

  const [brands, setBrands] = useState<BrandRecord[]>([]);
  const [brandVersions, setBrandVersions] = useState<Record<string, SoftwareVersionRecord[]>>({});
  const [versionsLoading, setVersionsLoading] = useState<Record<string, boolean>>({});
  const [loading, setLoading] = useState(true);
  
  // Brand Modal States
  const [showBrandModal, setShowBrandModal] = useState(false);
  const [selectedBrand, setSelectedBrand] = useState<BrandRecord | null>(null);
  const [brandFormData, setBrandFormData] = useState({
    displayName: '',
    isEnabled: true,
    order: 0,
    logoFile: null as File | null,
    logoPreview: ''
  });

  // Version States
  const [editingVersion, setEditingVersion] = useState<string | null>(null);
  const [versionInput, setVersionInput] = useState('');
  const [isAddingVersion, setIsAddingVersion] = useState(false);
  const [selectedBrandForVersion, setSelectedBrandForVersion] = useState<string>('');

  const [searchQuery] = useState('');

  const fetchData = async (showLoading = true) => {
    if (showLoading) setLoading(true);
    try {
      const brandsData = await BrandVersionService.getAllBrands();
      setBrands(brandsData);
      if (brandsData.length > 0 && !selectedBrandForVersion) {
        setSelectedBrandForVersion(brandsData[0].id);
      }
    } catch (e) {
      console.error("Failed to fetch brand data:", e);
    } finally {
      setLoading(false);
    }
  };

  const fetchVersionsForBrand = async (brandId: string) => {
    if (brandVersions[brandId] || versionsLoading[brandId]) return;
    
    setVersionsLoading(prev => ({ ...prev, [brandId]: true }));
    try {
      const data = await BrandVersionService.getVersionsByBrand(brandId);
      setBrandVersions(prev => ({ ...prev, [brandId]: data }));
    } catch (e) {
      console.error(`Failed to fetch versions for brand ${brandId}:`, e);
    } finally {
      setVersionsLoading(prev => ({ ...prev, [brandId]: false }));
    }
  };

  useEffect(() => {
    fetchData(true);
    
    const unsubBrands = BrandVersionService.subscribeToBrands(() => fetchData(false));
    const unsubVersions = BrandVersionService.subscribeToVersions(() => {
      // 重新获取所有版本数据以简化逻辑
      BrandVersionService.getAllVersions().then(allVersions => {
        const grouped: Record<string, SoftwareVersionRecord[]> = {};
        allVersions.forEach(v => {
          if (v.brand) {
            if (!grouped[v.brand]) grouped[v.brand] = [];
            grouped[v.brand].push(v);
          }
        });
        setBrandVersions(grouped);
      });
    });
    
    return () => {
      unsubBrands.then(unsub => unsub?.()?.catch?.(() => {})).catch(() => {});
      unsubVersions.then(unsub => unsub?.()?.catch?.(() => {})).catch(() => {});
    };
  }, []);

  // Brand Modal Handlers
  const openAddBrandModal = () => {
    setSelectedBrand(null);
    setBrandFormData({
      displayName: '',
      isEnabled: true,
      order: brands.length > 0 ? Math.max(...brands.map(b => b.order || 0)) + 1 : 0,
      logoFile: null,
      logoPreview: ''
    });
    setShowBrandModal(true);
  };

  const openEditBrandModal = (brand: BrandRecord) => {
    setSelectedBrand(brand);
    setBrandFormData({
      displayName: brand.displayName || brand.name,
      isEnabled: brand.isEnabled,
      order: brand.order || 0,
      logoFile: null,
      logoPreview: brand.logo ? getFileUrl(brand, brand.logo) || '' : ''
    });
    setShowBrandModal(true);
  };

  const handleLogoChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setBrandFormData(prev => ({
        ...prev,
        logoFile: file,
        logoPreview: URL.createObjectURL(file)
      }));
    }
  };

  const handleSaveBrand = async () => {
    if (!brandFormData.displayName.trim()) return;
    
    setLoading(true);
    try {
      const data = {
        displayName: brandFormData.displayName.trim(),
        isEnabled: brandFormData.isEnabled,
        order: brandFormData.order,
        logo: brandFormData.logoFile || undefined
      };

      if (selectedBrand) {
        await BrandVersionService.updateBrand(selectedBrand.id, data);
      } else {
        await BrandVersionService.createBrand(data);
      }
      setShowBrandModal(false);
    } catch (e) {
      alert("Failed to save brand");
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteBrand = async (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    if (!confirm(t('confirm_delete') + "\n" + t('delete_brand_warning'))) return;
    try {
      await BrandVersionService.deleteBrand(id);
    } catch (e) {
      alert("Failed to delete brand");
    }
  };

  const handleToggleBrandEnable = async (e: React.MouseEvent, brand: BrandRecord) => {
    e.stopPropagation();
    try {
      await BrandVersionService.updateBrand(brand.id, { isEnabled: !brand.isEnabled });
    } catch (e) {
      alert("Failed to toggle brand status");
    }
  };

  // Version Handlers
  const handleAddVersion = async () => {
    if (!versionInput.trim() || !selectedBrandForVersion) return;
    try {
      await BrandVersionService.createVersion(versionInput.trim(), selectedBrandForVersion);
      setVersionInput('');
      setIsAddingVersion(false);
    } catch (e) {
      alert("Failed to add version");
    }
  };

  const handleUpdateVersion = async (id: string) => {
    if (!versionInput.trim()) return;
    try {
      await BrandVersionService.updateVersion(id, { name: versionInput.trim() });
      setEditingVersion(null);
      setVersionInput('');
    } catch (e) {
      alert("Failed to update version");
    }
  };

  const handleDeleteVersion = async (id: string) => {
    if (!confirm(t('confirm_delete'))) return;
    try {
      await BrandVersionService.deleteVersion(id);
    } catch (e) {
      alert("Failed to delete version");
    }
  };

  const filteredBrands = useMemo(() => brands.filter(b => 
    (b.displayName || b.name).toLowerCase().includes(searchQuery.toLowerCase())
  ), [brands, searchQuery]);

  return (
    <div className="flex-1 overflow-y-auto p-4 sm:p-6 lg:px-10 lg:pb-10 bg-[#F5F5F7] pt-4">
      <div className="max-w-5xl mx-auto">
        <div className="flex flex-col gap-6 sm:gap-10 pb-10">
          {/* Brands Section */}
          <section className={`bg-white rounded-[1.5rem] sm:rounded-[2rem] ${responsivePadding} shadow-2xl shadow-black/[0.03] border border-gray-50 flex flex-col min-h-[400px]`}>
            <div className="flex items-center justify-between mb-6 sm:mb-8">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 sm:w-10 sm:h-10 bg-[#007AFF]/10 text-[#007AFF] rounded-lg sm:rounded-xl flex items-center justify-center">
                  <Car className="w-[18px] h-[18px] sm:w-5 sm:h-5" />
                </div>
                <h2 className="text-lg sm:text-xl font-black text-[#1D1D1F] tracking-tight">{t('brands')}</h2>
              </div>
              <button 
                onClick={openAddBrandModal}
                className="p-1.5 sm:p-2 bg-[#F5F5F7] text-muted hover:text-[#007AFF] hover:bg-[#007AFF]/5 rounded-lg sm:rounded-xl transition-all active:scale-95"
              >
                <Plus className="w-[18px] h-[18px] sm:w-5 sm:h-5" />
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-3 sm:gap-4">
              {loading && brands.length === 0 ? (
                <div className="col-span-full relative h-64">
                  <LoadingOverlay />
                </div>
              ) : filteredBrands.length === 0 ? (
                <div className="col-span-full py-10 text-center text-muted font-bold opacity-30 italic">{t('no_brands')}</div>
              ) : (
                filteredBrands.map(brand => (
                  <div 
                    key={brand.id} 
                    onClick={() => openEditBrandModal(brand)}
                    className="group p-3 sm:p-4 bg-[#F2F2F7] rounded-2xl border border-transparent hover:border-gray-100 hover:bg-white hover:shadow-xl hover:shadow-black/[0.02] transition-all flex items-center justify-between cursor-pointer"
                  >
                    <div className="flex items-center gap-3 sm:gap-4 flex-1 min-w-0">
                      <div className="w-10 h-10 sm:w-12 sm:h-12 bg-white rounded-lg sm:rounded-xl flex items-center justify-center border border-gray-100 group-hover:scale-110 transition-transform p-2 overflow-hidden flex-shrink-0">
                        {brand.logo ? (
                          <img src={getFileUrl(brand, brand.logo) || ''} alt={brand.displayName} className="w-full h-full object-contain" />
                        ) : (
                          <span className="text-[10px] sm:text-xs font-black text-muted uppercase">{(brand.displayName || brand.name).substring(0,2)}</span>
                        )}
                      </div>
                      <div className="truncate">
                        <div className="font-black text-[#1D1D1F] tracking-tight text-base sm:text-lg truncate">{brand.displayName || brand.name}</div>
                        <div className={`flex items-center gap-1.5 text-[9px] sm:text-[10px] font-black uppercase tracking-widest ${brand.isEnabled ? 'text-[#248A3D]' : 'text-muted opacity-50'}`}>
                          {brand.isEnabled ? <Eye className="w-2.5 h-2.5 sm:w-3 sm:h-3" /> : <EyeOff className="w-2.5 h-2.5 sm:w-3 sm:h-3" />}
                          {brand.isEnabled ? 'Enabled' : 'Disabled'}
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex items-center gap-2 sm:gap-3">
                      <button 
                        onClick={(e) => handleToggleBrandEnable(e, brand)}
                        className={`w-9 h-5 sm:w-10 sm:h-6 rounded-full transition-all relative flex-shrink-0 ${brand.isEnabled ? 'bg-[#248A3D]' : 'bg-gray-300'}`}
                      >
                        <div className={`absolute top-0.5 left-0.5 w-4 h-4 sm:w-5 sm:h-5 bg-white rounded-full transition-all shadow-sm transform ${brand.isEnabled ? 'translate-x-4' : 'translate-x-0'}`} />
                      </button>

                      <div className="flex items-center md:opacity-0 group-hover:opacity-100 transition-opacity">
                        <button 
                          onClick={(e) => handleDeleteBrand(e, brand.id)}
                          className="p-1.5 sm:p-2 text-muted hover:text-[#FF3B30] hover:bg-[#FF3B30]/5 rounded-lg transition-colors"
                        >
                          <Trash2 className="w-4 h-4 sm:w-[18px] sm:h-[18px]" />
                        </button>
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>
          </section>

          {/* Versions Section */}
          <section className={`bg-white rounded-[1.5rem] sm:rounded-[2rem] ${responsivePadding} shadow-2xl shadow-black/[0.03] border border-gray-50 flex flex-col min-h-[400px]`}>
            <div className="flex items-center justify-between mb-6 sm:mb-8">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 sm:w-10 sm:h-10 bg-[#248A3D]/10 text-[#248A3D] rounded-lg sm:rounded-xl flex items-center justify-center">
                  <Box className="w-[18px] h-[18px] sm:w-5 sm:h-5" />
                </div>
                <h2 className="text-lg sm:text-xl font-black text-[#1D1D1F] tracking-tight">{t('software_versions')}</h2>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
              {loading && brands.length === 0 ? (
                [...Array(6)].map((_, i) => (
                  <div key={i} className="bg-[#F5F5F7]/30 rounded-3xl p-5 h-[320px] animate-pulse flex flex-col">
                    <div className="flex justify-between items-center mb-4">
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 bg-gray-200 rounded-lg" />
                        <div className="h-4 bg-gray-200 rounded w-24" />
                      </div>
                      <div className="w-6 h-6 bg-gray-100 rounded-lg" />
                    </div>
                    <div className="flex-1 space-y-2">
                      <div className="h-10 bg-white/50 rounded-xl" />
                      <div className="h-10 bg-white/50 rounded-xl" />
                      <div className="h-10 bg-white/50 rounded-xl" />
                    </div>
                  </div>
                ))
              ) : brands.map(brand => (
                <BrandVersionCard 
                  key={brand.id}
                  brand={brand}
                  versions={brandVersions[brand.id] || []}
                  loading={versionsLoading[brand.id] || false}
                  onLoad={() => fetchVersionsForBrand(brand.id)}
                  isAddingVersion={isAddingVersion && selectedBrandForVersion === brand.id}
                  onAddClick={() => {
                    setSelectedBrandForVersion(brand.id);
                    setIsAddingVersion(true);
                    setVersionInput('');
                    setEditingVersion(null);
                  }}
                  editingVersionId={editingVersion}
                  versionInput={versionInput}
                  onVersionInputChange={setVersionInput}
                  onEditVersion={(v: any) => {
                    setEditingVersion(v.id);
                    setVersionInput(v.versionString);
                    setIsAddingVersion(false);
                  }}
                  onCancelEdit={() => setEditingVersion(null)}
                  onUpdateVersion={handleUpdateVersion}
                  onDeleteVersion={handleDeleteVersion}
                  onAddVersion={handleAddVersion}
                  onCancelAdd={() => setIsAddingVersion(false)}
                />
              ))}
            </div>
          </section>
        </div>
      </div>

      <BrandEditModal 
        isOpen={showBrandModal}
        onClose={() => setShowBrandModal(false)}
        selectedBrand={selectedBrand}
        brandFormData={brandFormData}
        setBrandFormData={setBrandFormData}
        handleLogoChange={handleLogoChange}
        handleSaveBrand={handleSaveBrand}
        loading={loading}
      />
    </div>
  );
};

export default BrandVersionManager;
