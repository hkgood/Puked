import React, { useState, useEffect, useRef } from 'react';
import { BrandVersionService } from '../../../brand_version/services/brandVersionService';
import { UserService } from '../../services/userService';
import type { UserRecord, SoftwareVersionRecord, BrandRecord } from '../../../../models/types';
import { Check, Plus, Search, X, Loader2, ChevronDown } from 'lucide-react';
import { useI18n } from '../../../../common/utils/i18n';

interface VersionQuickEditorProps {
  user: UserRecord;
  onUpdate: (updatedUser: UserRecord) => void;
}

const VersionQuickEditor: React.FC<VersionQuickEditorProps> = ({ user, onUpdate }) => {
  const { t } = useI18n();
  const [isEditing, setIsEditing] = useState(false);
  const [inputValue, setInputValue] = useState(user.software_version || '');
  const [allVersions, setAllVersions] = useState<SoftwareVersionRecord[]>([]);
  const [brands, setBrands] = useState<BrandRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (isEditing) {
      fetchData();
    }
  }, [isEditing]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsEditing(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [versionsData, brandsData] = await Promise.all([
        BrandVersionService.getAllVersions(),
        BrandVersionService.getAllBrands()
      ]);
      setAllVersions(versionsData);
      setBrands(brandsData);
    } catch (e) {
      console.error("Failed to fetch versions:", e);
    } finally {
      setLoading(false);
    }
  };

  const handleSelectVersion = async (versionStr: string) => {
    if (versionStr === user.software_version) {
      setIsEditing(false);
      return;
    }

    setIsSubmitting(true);
    try {
      const updatedUser = await UserService.updateSoftwareVersion(user.id, versionStr);
      onUpdate(updatedUser);
      setIsEditing(false);
    } catch (e) {
      alert(t('failed_to_update'));
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleAddNewVersion = async () => {
    const newVersionStr = inputValue.trim();
    if (!newVersionStr) return;

    setIsSubmitting(true);
    try {
      // 1. 鲁棒性检查：先看看字典里是否已经存在同名版本（忽略大小写和前后空格）
      const normalizedNewVersion = newVersionStr.trim().toLowerCase();
      const existingVersion = allVersions.find(v =>
        v.versionString.trim().toLowerCase() === normalizedNewVersion
      );

      if (existingVersion) {
        // 如果已经存在，直接使用已有的版本，不再重复创建
        const updatedUser = await UserService.updateSoftwareVersion(user.id, existingVersion.versionString);
        onUpdate(updatedUser);
        setIsEditing(false);
        return;
      }

      // 2. 尝试根据用户的品牌名查找匹配的品牌 ID
      const userBrandName = (user.brand || user.adas_brand || '').toLowerCase();
      const userBrandRef = user.brand_ref;

      let matchedBrand = brands.find(b =>
        (userBrandRef && b.id === userBrandRef) ||
        b.name.toLowerCase() === userBrandName ||
        b.displayName.toLowerCase() === userBrandName
      );

      // 如果找不到匹配品牌，默认关联到第一个品牌（PocketBase 限制必须有品牌）
      // 或者我们可以弹窗让用户选品牌，但为了“快速编辑”，我们先尝试自动匹配
      const brandId = matchedBrand?.id || (brands.length > 0 ? brands[0].id : '');

      if (!brandId) {
        throw new Error("No brand found to associate with new version");
      }

      // 1. 创建新版本到字典
      await BrandVersionService.createVersion(newVersionStr, brandId);

      // 2. 更新用户信息
      const updatedUser = await UserService.updateSoftwareVersion(user.id, newVersionStr);
      onUpdate(updatedUser);
      setIsEditing(false);
    } catch (e) {
      console.error(e);
      alert(t('failed_to_create_version'));
    } finally {
      setIsSubmitting(false);
    }
  };

  // 过滤建议列表
  const suggestions = allVersions
    .filter(v => v.versionString.toLowerCase().includes(inputValue.toLowerCase()))
    .filter((v, i, self) => self.findIndex(t => t.versionString === v.versionString) === i) // 去重
    .slice(0, 8);

  const exactMatch = allVersions.find(v => v.versionString.toLowerCase() === inputValue.toLowerCase().trim());

  if (!isEditing) {
    return (
      <div
        onClick={() => setIsEditing(true)}
        className="group flex items-center gap-2 cursor-pointer hover:bg-gray-50 p-1 -m-1 rounded-lg transition-all"
      >
        <div className="font-black text-[#1D1D1F]">{user.software_version || t('unknown')}</div>
        <div className="opacity-0 group-hover:opacity-100 text-[#007AFF] transition-opacity">
          <Plus size={14} />
        </div>
      </div>
    );
  }

  return (
    <div className="relative w-full max-w-[240px]" ref={dropdownRef}>
      <div className="flex items-center gap-2 bg-[#F5F5F7] rounded-xl px-3 py-2 border-2 border-[#007AFF] shadow-sm">
        <input
          autoFocus
          value={inputValue}
          onChange={(e) => setInputValue(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !exactMatch && inputValue.trim()) {
              handleAddNewVersion();
            }
          }}
          placeholder={t('version_name')}
          className="flex-1 bg-transparent border-none outline-none text-sm font-bold text-[#1D1D1F]"
        />
        {isSubmitting ? (
          <Loader2 size={14} className="animate-spin text-[#007AFF]" />
        ) : (
          <X
            size={14}
            className="text-muted cursor-pointer hover:text-[#1D1D1F]"
            onClick={() => setIsEditing(false)}
          />
        )}
      </div>

      <div className="absolute top-full left-0 right-0 mt-2 bg-white rounded-2xl shadow-2xl border border-gray-100 overflow-hidden z-[100] animate-in slide-in-from-top-2 duration-200">
        <div className="max-h-[240px] overflow-y-auto p-1.5 custom-scrollbar">
          {loading ? (
            <div className="p-4 text-center">
              <Loader2 size={16} className="animate-spin mx-auto text-muted opacity-50" />
            </div>
          ) : (
            <>
              {suggestions.map((v) => (
                <div
                  key={v.id}
                  onClick={() => handleSelectVersion(v.versionString)}
                  className="flex items-center justify-between px-3 py-2.5 hover:bg-[#F5F5F7] rounded-xl cursor-pointer transition-colors group"
                >
                  <span className="text-xs font-bold text-[#1D1D1F]">{v.versionString}</span>
                  {v.versionString === user.software_version && <Check size={12} className="text-[#248A3D]" />}
                </div>
              ))}

              {!exactMatch && inputValue.trim() && (
                <div
                  onClick={handleAddNewVersion}
                  className="flex items-center gap-2 px-3 py-2.5 hover:bg-[#007AFF]/5 text-[#007AFF] rounded-xl cursor-pointer transition-colors border-t border-gray-50 mt-1"
                >
                  <Plus size={14} />
                  <span className="text-xs font-black uppercase tracking-wider">{t('add_new_version').replace('{name}', inputValue)}</span>
                </div>
              )}

              {suggestions.length === 0 && !inputValue.trim() && (
                <div className="p-4 text-center text-[10px] font-bold text-muted uppercase italic opacity-50">
                  {t('type_to_search_or_add')}
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default VersionQuickEditor;

