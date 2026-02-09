import React, { useState, useEffect, useRef } from 'react';
import { BrandVersionService } from '../../../brand_version/services/brandVersionService';
import type { UserRecord, BrandRecord } from '../../../../models/types';
import { Check, Plus, X, Loader2, ChevronDown } from 'lucide-react';
import { useI18n } from '../../../../common/utils/i18n';

interface BrandQuickEditorProps {
  user: UserRecord;
  onUpdate: (updatedUser: UserRecord) => void;
}

/**
 * ADAS 品牌快速编辑器
 * 
 * 功能：
 * 1. 只编辑品牌，不涉及车型
 * 2. 下拉选择品牌（从 brands 表获取）
 * 3. 数据标准化，避免拼写错误
 */
const BrandQuickEditor: React.FC<BrandQuickEditorProps> = ({ user, onUpdate }) => {
  const { t } = useI18n();
  const [isEditing, setIsEditing] = useState(false);
  const [brands, setBrands] = useState<BrandRecord[]>([]);
  const [selectedBrandId, setSelectedBrandId] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // 点击外部关闭编辑
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        handleCancel();
      }
    };
    if (isEditing) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [isEditing]);

  // 加载品牌列表
  useEffect(() => {
    if (isEditing) {
      loadBrands();
    }
  }, [isEditing]);

  const loadBrands = async () => {
    try {
      const brandsData = await BrandVersionService.getAllBrands();
      setBrands(brandsData.filter(b => b.isEnabled));

      // 查找用户当前品牌对应的 ID
      const currentBrandName = (user.brand || user.adas_brand || user.brand_ref || '').toLowerCase();
      const matchedBrand = brandsData.find(b =>
        b.name.toLowerCase() === currentBrandName ||
        b.displayName.toLowerCase() === currentBrandName
      );

      if (matchedBrand) {
        setSelectedBrandId(matchedBrand.id);
      } else if (brandsData.length > 0) {
        setSelectedBrandId(brandsData[0].id);
      }
    } catch (e) {
      console.error('Failed to load brands:', e);
    }
  };

  const handleCancel = () => {
    setIsEditing(false);
    setSelectedBrandId('');
  };

  const handleSave = async () => {
    const selectedBrand = brands.find(b => b.id === selectedBrandId);
    if (!selectedBrand) {
      alert(t('please_select_brand'));
      return;
    }

    // 检查是否有修改
    const currentBrand = user.brand || user.adas_brand || user.brand_ref || '';
    if (selectedBrand.displayName === currentBrand) {
      setIsEditing(false);
      return;
    }

    setIsSubmitting(true);
    try {
      const { pb } = await import('../../../../services/pocketbase');

      // 只更新品牌，不改车型
      const updatedUser = await pb.collection('users').update<UserRecord>(user.id, {
        brand: selectedBrand.displayName,
        brand_ref: selectedBrand.id,
        adas_brand: selectedBrand.displayName, // 同步更新 adas_brand
      });

      onUpdate(updatedUser);
      setIsEditing(false);
    } catch (e) {
      console.error('Failed to update brand:', e);
      alert(t('failed_to_update'));
    } finally {
      setIsSubmitting(false);
    }
  };

  // 显示模式
  if (!isEditing) {
    const displayBrand = user.brand || user.adas_brand || user.brand_ref || t('unknown');

    return (
      <div
        onClick={() => setIsEditing(true)}
        className="group flex items-center gap-2 cursor-pointer hover:bg-gray-50 p-1 -m-1 rounded-lg transition-all"
      >
        <div className="font-black text-[#1D1D1F]">{displayBrand}</div>
        <div className="opacity-0 group-hover:opacity-100 text-[#007AFF] transition-opacity">
          <Plus size={14} />
        </div>
      </div>
    );
  }

  // 编辑模式
  return (
    <div className="relative w-full max-w-[280px]" ref={dropdownRef}>
      <div className="flex flex-col gap-3 bg-[#F5F5F7] rounded-xl p-3 border-2 border-[#007AFF] shadow-sm">
        {/* 品牌下拉选择 */}
        <div className="relative">
          <select
            autoFocus
            value={selectedBrandId}
            onChange={(e) => setSelectedBrandId(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                handleSave();
              } else if (e.key === 'Escape') {
                handleCancel();
              }
            }}
            className="w-full appearance-none bg-white rounded-lg px-3 py-2 pr-8 text-sm font-bold text-[#1D1D1F] outline-none border-2 border-transparent focus:border-[#007AFF] transition-colors cursor-pointer"
          >
            <option value="">{t('select_brand_placeholder')}</option>
            {brands.map(brand => (
              <option key={brand.id} value={brand.id}>
                {brand.displayName}
              </option>
            ))}
          </select>
          <ChevronDown size={14} className="absolute right-3 top-1/2 -translate-y-1/2 text-muted pointer-events-none" />
        </div>

        {/* 操作按钮 */}
        <div className="flex items-center gap-2">
          {isSubmitting ? (
            <Loader2 size={16} className="animate-spin text-[#007AFF] mx-auto" />
          ) : (
            <>
              <button
                onClick={handleSave}
                disabled={!selectedBrandId}
                className="flex-1 bg-[#248A3D] text-white rounded-lg px-3 py-2 text-xs font-black uppercase flex items-center justify-center gap-1.5 hover:bg-[#1f7433] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <Check size={14} />
                {t('save')}
              </button>
              <button
                onClick={handleCancel}
                className="flex-1 bg-gray-200 text-[#1D1D1F] rounded-lg px-3 py-2 text-xs font-black uppercase flex items-center justify-center gap-1.5 hover:bg-gray-300 transition-colors"
              >
                <X size={14} />
                {t('cancel')}
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default BrandQuickEditor;
