import React, { useState, useEffect, useRef } from 'react';
import type { UserRecord } from '../../../../models/types';
import { Check, Plus, X, Loader2 } from 'lucide-react';
import { useI18n } from '../../../../common/utils/i18n';

interface CarModelQuickEditorProps {
  user: UserRecord;
  onUpdate: (updatedUser: UserRecord) => void;
}

/**
 * 车辆型号快速编辑器
 * 
 * 功能：
 * 1. 只编辑车型，不涉及品牌
 * 2. 提供常用车型建议
 */
const CarModelQuickEditor: React.FC<CarModelQuickEditorProps> = ({ user, onUpdate }) => {
  const { t } = useI18n();
  const [isEditing, setIsEditing] = useState(false);
  const [modelInput, setModelInput] = useState(user.car_model || '');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [suggestions, setSuggestions] = useState<string[]>([]);
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

  // 加载车型建议
  useEffect(() => {
    if (isEditing) {
      loadSuggestions();
    }
  }, [isEditing, modelInput]);

  const loadSuggestions = async () => {
    try {
      const { pb } = await import('../../../../services/pocketbase');

      // 获取当前用户品牌下的车型
      const currentBrand = user.brand || user.adas_brand || user.brand_ref;
      if (!currentBrand) return;

      const users = await pb.collection('users').getFullList<UserRecord>({
        filter: `brand ~ "${currentBrand}" || adas_brand ~ "${currentBrand}"`,
        fields: 'car_model',
        requestKey: null,
      });

      // 提取唯一车型
      const models = new Set<string>();
      users.forEach(u => {
        if (u.car_model && u.car_model.trim()) {
          models.add(u.car_model.trim());
        }
      });

      // 过滤匹配输入
      const filtered = Array.from(models)
        .filter(model => !modelInput || model.toLowerCase().includes(modelInput.toLowerCase()))
        .sort()
        .slice(0, 6);

      setSuggestions(filtered);
    } catch (e) {
      console.error('Failed to load suggestions:', e);
    }
  };

  const handleCancel = () => {
    setIsEditing(false);
    setModelInput(user.car_model || '');
  };

  const handleSave = async () => {
    const newModel = modelInput.trim();

    // 检查是否有修改
    if (newModel === (user.car_model || '')) {
      setIsEditing(false);
      return;
    }

    setIsSubmitting(true);
    try {
      const { pb } = await import('../../../../services/pocketbase');

      // 只更新车型
      const updatedUser = await pb.collection('users').update<UserRecord>(user.id, {
        car_model: newModel,
      });

      onUpdate(updatedUser);
      setIsEditing(false);
    } catch (e) {
      console.error('Failed to update car model:', e);
      alert(t('failed_to_update'));
    } finally {
      setIsSubmitting(false);
    }
  };

  // 显示模式
  if (!isEditing) {
    const displayBrand = user.brand || user.adas_brand || user.brand_ref || t('unknown');
    const displayModel = user.car_model || t('unknown');

    return (
      <div
        onClick={() => setIsEditing(true)}
        className="group flex items-center gap-2 cursor-pointer hover:bg-gray-50 p-1 -m-1 rounded-lg transition-all"
      >
        <div className="font-black text-[#1D1D1F]">{displayBrand} {displayModel}</div>
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
        {/* 车型输入框 */}
        <input
          autoFocus
          value={modelInput}
          onChange={(e) => setModelInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              handleSave();
            } else if (e.key === 'Escape') {
              handleCancel();
            }
          }}
          placeholder={t('car_model_placeholder')}
          className="w-full bg-white rounded-lg px-3 py-2 text-sm font-bold text-[#1D1D1F] outline-none border-2 border-transparent focus:border-[#007AFF] transition-colors"
        />

        {/* 操作按钮 */}
        <div className="flex items-center gap-2">
          {isSubmitting ? (
            <Loader2 size={16} className="animate-spin text-[#007AFF] mx-auto" />
          ) : (
            <>
              <button
                onClick={handleSave}
                className="flex-1 bg-[#248A3D] text-white rounded-lg px-3 py-2 text-xs font-black uppercase flex items-center justify-center gap-1.5 hover:bg-[#1f7433] transition-colors"
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

      {/* 车型建议 */}
      {suggestions.length > 0 && modelInput && (
        <div className="absolute top-full left-0 right-0 mt-2 bg-white rounded-2xl shadow-2xl border border-gray-100 overflow-hidden z-[100] animate-in slide-in-from-top-2 duration-200">
          <div className="max-h-[180px] overflow-y-auto p-1.5 custom-scrollbar">
            <div className="px-3 py-1.5 text-[9px] font-black text-muted uppercase tracking-wider">
              {t('popular_models')}
            </div>
            {suggestions.map((model, index) => (
              <div
                key={`${model}-${index}`}
                onClick={() => setModelInput(model)}
                className="flex items-center justify-between px-3 py-2.5 hover:bg-[#F5F5F7] rounded-xl cursor-pointer transition-colors"
              >
                <span className="text-sm font-bold text-[#1D1D1F]">{model}</span>
                {model === user.car_model && (
                  <Check size={12} className="text-[#248A3D]" />
                )}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default CarModelQuickEditor;
