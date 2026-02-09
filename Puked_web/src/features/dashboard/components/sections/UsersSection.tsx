import React, { useState, useEffect } from 'react';
import {
  Users,
  Search,
  ChevronDown,
  Car,
  Calendar,
  Shield,
  Box,
  AlertCircle,
  Mail,
  RefreshCw
} from 'lucide-react';
import { format } from 'date-fns';
import { useI18n } from '../../../../common/utils/i18n';
import type { UserRecord } from '../../../../models/types';
import { UserService } from '../../services/userService';
import BrandQuickEditor from '../editors/BrandQuickEditor';
import CarModelQuickEditor from '../editors/CarModelQuickEditor';
import VersionQuickEditor from '../editors/VersionQuickEditor';
import CertificationImage from '../CertificationImage';
import UserStatsCard from '../UserStatsCard';
import LoadingOverlay from '../../../../common/components/LoadingOverlay';

interface UsersSectionProps {
  users: UserRecord[];
  selectedUser: UserRecord | null;
  setSelectedUser: (user: UserRecord | null) => void;
  userFilter: string;
  setUserFilter: (filter: any) => void;
  userSearchQuery: string;
  setUserSearchQuery: (query: string) => void;
  userStats: any;
  isSuperAdmin: boolean;
  isLoading: boolean;
  isUserLoading: boolean;
  isSubmitting: boolean;
  hasMoreUsers: boolean;
  isLoadingMore: boolean;
  onLoadMore: () => void;
  onApprove: (user: UserRecord) => void;
  onReject: () => void;
  onUpdateUserSettings: (field: string, value: any) => void;
  onUpdateUser: (user: UserRecord) => void;
  debouncedPreload: (user: UserRecord) => void;
  showMobileDetail: boolean;
  setShowMobileDetail: (show: boolean) => void;
}

const UsersSection: React.FC<UsersSectionProps> = ({
  users,
  selectedUser,
  setSelectedUser,
  userFilter,
  setUserFilter,
  userSearchQuery,
  setUserSearchQuery,
  userStats,
  isSuperAdmin,
  isLoading,
  isUserLoading,
  isSubmitting,
  hasMoreUsers,
  isLoadingMore,
  onLoadMore,
  onApprove,
  onReject,
  onUpdateUserSettings,
  onUpdateUser,
  debouncedPreload,
  showMobileDetail,
  setShowMobileDetail
}) => {
  const { t } = useI18n();
  const [localSearchQuery, setLocalSearchQuery] = useState(userSearchQuery);

  // 当外部搜索词变化时（如重置），同步到本地
  useEffect(() => {
    setLocalSearchQuery(userSearchQuery);
  }, [userSearchQuery]);

  const handleScroll = (e: React.UIEvent<HTMLDivElement>) => {
    const { scrollTop, scrollHeight, clientHeight } = e.currentTarget;
    if (scrollHeight - scrollTop - clientHeight < 100) {
      onLoadMore();
    }
  };

  const renderUserItem = (user: UserRecord) => (
    <div
      key={user.id}
      onClick={() => { setSelectedUser(user); setShowMobileDetail(true); }}
      onMouseEnter={() => debouncedPreload(user)}
      className={`p-4 mb-2 rounded-xl cursor-pointer transition-all relative group ${selectedUser?.id === user.id ? 'bg-white shadow-lg scale-[1.01]' : 'hover:bg-white/50'}`}
    >
      <div className="flex justify-between items-start mb-2">
        <div className="font-black text-[#1D1D1F] text-base tracking-tight truncate pr-2">{user.username || user.name || user.email?.split('@')[0] || 'User'}</div>
        <span className={`text-[9px] font-black px-2 py-0.5 rounded-full uppercase ${user.audit_status === 'approved' ? 'bg-[#248A3D]/10 text-[#248A3D]' : 'bg-[#007AFF]/10 text-[#007AFF]'}`}>
          {user.audit_status?.toLowerCase() === 'approved' ? t('approved') :
            user.audit_status?.toLowerCase() === 'rejected' ? t('reject') :
              t('pending_audit')}
        </span>
      </div>
      <div className="flex flex-col gap-0.5 text-[10px] font-bold text-muted">
        <div className="flex items-center gap-1.5 uppercase tracking-wider">
          <Car size={12} className="text-[#007AFF]" />
          {user.brand || user.adas_brand || user.brand_ref || 'Unknown'} {user.car_model || ''}
        </div>
        <div className="flex items-center gap-1.5 opacity-60"><Calendar size={12} />{format(new Date(user.created), 'yyyy-MM-dd HH:mm')}</div>
      </div>
    </div>
  );

  if (isLoading && users.length === 0) {
    return <div className="flex-1 relative"><LoadingOverlay /></div>;
  }

  return (
    <>
      <div className={`w-full md:w-[360px] border-r border-gray-100 flex flex-col h-full bg-[#F5F5F7]/30 ${showMobileDetail ? 'hidden md:flex' : 'flex'}`}>
        <div className="px-4 pt-6 pb-4 border-b border-gray-100 bg-white/80 backdrop-blur-md sticky top-0 z-10">
          <div className="flex items-center justify-between mb-4">
            <span className="text-[11px] font-black text-[#1D1D1F] uppercase tracking-widest flex items-center gap-2">
              <Users size={14} className="text-[#007AFF]" />
              {t('user_list')}
            </span>
          </div>

          <div className="relative group mb-3">
            <input
              type="text"
              value={localSearchQuery}
              onChange={(e) => setLocalSearchQuery(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  setUserSearchQuery(localSearchQuery);
                }
              }}
              onBlur={() => {
                if (localSearchQuery !== userSearchQuery) {
                  setUserSearchQuery(localSearchQuery);
                }
              }}
              placeholder={t('search_users')}
              className="w-full bg-[#F5F5F7] rounded-xl pl-8 pr-3 py-2 text-[10px] font-black text-[#1D1D1F] outline-none hover:bg-gray-200 transition-colors"
            />
            <Search 
              className="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted cursor-pointer hover:text-[#007AFF] transition-colors" 
              size={12} 
              onClick={() => setUserSearchQuery(localSearchQuery)}
            />
          </div>

          <div className="relative group">
            <select
              value={userFilter}
              onChange={(e) => setUserFilter(e.target.value)}
              className="w-full appearance-none bg-[#F5F5F7] rounded-xl px-3 py-2 pr-8 text-[10px] font-black text-[#1D1D1F] outline-none cursor-pointer hover:bg-gray-200 transition-colors"
            >
              <option value="pending">{t('user_status_pending')} ({userStats.pending})</option>
              <option value="approved">{t('user_status_approved')} ({userStats.approved})</option>
              <option value="rejected">{t('user_status_rejected')} ({userStats.rejected})</option>
              <option value="kol">{t('user_status_kol')} ({userStats.kol})</option>
              <option value="admin">{t('user_status_admin')} ({userStats.admin})</option>
              <option value="all">{t('user_status_all')} ({userStats.all})</option>
            </select>
            <ChevronDown className="absolute right-2 top-1/2 -translate-y-1/2 text-muted pointer-events-none" size={10} />
          </div>
        </div>

        <div className="flex-1 overflow-y-auto px-3 pb-8 pt-4" onScroll={handleScroll}>
          {users.map(renderUserItem)}
          {isLoadingMore && (
            <div className="py-4 flex flex-col items-center gap-2">
              <div className="w-5 h-5 border-2 border-[#007AFF]/20 border-t-[#007AFF] rounded-full animate-spin"></div>
              <span className="text-[10px] font-black text-muted uppercase tracking-widest">{t('loading')}</span>
            </div>
          )}
        </div>
      </div>

      <div className={`flex-1 h-full overflow-y-auto ${showMobileDetail ? 'flex' : 'hidden md:flex'} flex-col bg-white relative`}>
        {isSubmitting && <LoadingOverlay message={t('save')} />}
        {selectedUser ? (
          <div className="p-4 sm:p-6 lg:p-10">
            <div className="max-w-4xl mx-auto w-full">
              <header className="mb-8 flex flex-col sm:flex-row justify-between sm:items-center gap-6">
                <div>
                  <h1 className="text-3xl font-black text-[#1D1D1F] tracking-tighter mb-2">
                    {selectedUser.username || selectedUser.name || 'User'}
                  </h1>
                  <p className="text-muted font-bold text-xs uppercase tracking-widest flex items-center gap-2">
                    <Mail size={12} /> {selectedUser.email}
                  </p>
                </div>

                {selectedUser.audit_status === 'pending' && (
                  <div className="flex gap-3">
                    <button onClick={onReject} className="bg-[#FF3B30] text-white px-8 py-3 rounded-2xl text-[13px] font-black uppercase shadow-lg shadow-red-500/20 active:scale-95 transition-all">{t('reject')}</button>
                    <button onClick={() => onApprove(selectedUser)} className="bg-[#248A3D] text-white px-8 py-3 rounded-2xl text-[13px] font-black uppercase shadow-lg shadow-green-500/20 active:scale-95 transition-all">{t('approve')}</button>
                  </div>
                )}
              </header>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                <div className="space-y-6">
                  {/* 车辆信息编辑器组 */}
                  <div className="bg-[#F5F5F7]/50 p-6 rounded-[2rem] border border-gray-100">
                    <div className="text-[10px] font-black text-muted uppercase mb-6 tracking-widest">{t('vehicle_info')}</div>
                    <div className="space-y-4">
                      <div className="flex items-center gap-4">
                        <div className="p-3 bg-white rounded-2xl shadow-sm"><Shield size={20} className="text-[#007AFF]" /></div>
                        <div className="flex-1">
                          <div className="text-[9px] font-black text-muted uppercase mb-1">{t('brand')}</div>
                          <BrandQuickEditor user={selectedUser} onUpdate={onUpdateUser} />
                        </div>
                      </div>
                      <div className="flex items-center gap-4">
                        <div className="p-3 bg-white rounded-2xl shadow-sm"><Car size={20} className="text-[#248A3D]" /></div>
                        <div className="flex-1">
                          <div className="text-[9px] font-black text-muted uppercase mb-1">{t('car_model')}</div>
                          <CarModelQuickEditor user={selectedUser} onUpdate={onUpdateUser} />
                        </div>
                      </div>
                      <div className="flex items-center gap-4">
                        <div className="p-3 bg-white rounded-2xl shadow-sm"><Box size={20} className="text-[#AF52DE]" /></div>
                        <div className="flex-1">
                          <div className="text-[9px] font-black text-muted uppercase mb-1">{t('software_version')}</div>
                          <VersionQuickEditor user={selectedUser} onUpdate={onUpdateUser} />
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* 用户权限设置 */}
                  {isSuperAdmin && (
                    <div className="bg-[#F5F5F7]/50 p-6 rounded-[2rem] border border-gray-100">
                      <div className="text-[10px] font-black text-muted uppercase mb-6 tracking-widest">{t('user_permissions')}</div>
                      <div className="space-y-3">
                        <div className="flex items-center justify-between p-4 bg-white rounded-2xl shadow-sm">
                          <div>
                            <div className="font-black text-xs text-[#1D1D1F] mb-0.5">{t('kol_user')}</div>
                            <div className="text-[9px] text-muted font-bold uppercase">{t('kol_user_desc')}</div>
                          </div>
                          <button
                            onClick={() => onUpdateUserSettings('KOL', !selectedUser.KOL)}
                            className={`relative w-10 h-5 rounded-full transition-all ${selectedUser.KOL ? 'bg-[#248A3D]' : 'bg-gray-200'}`}
                          >
                            <div className={`absolute top-0.5 w-4 h-4 bg-white rounded-full transition-all shadow-sm ${selectedUser.KOL ? 'translate-x-5' : 'translate-x-0.5'}`} />
                          </button>
                        </div>
                      </div>
                    </div>
                  )}
                </div>

                {/* 右侧：根据用户状态显示不同内容 */}
                {selectedUser.audit_status === 'approved' ? (
                  // 已通过用户：显示统计数据
                  <UserStatsCard user={selectedUser} />
                ) : (
                  // 待审核/已拒绝用户：显示认证截图
                  <div className="bg-[#F5F5F7]/50 p-6 rounded-[2rem] border border-gray-100 flex flex-col">
                    <div className="text-[10px] font-black text-muted uppercase mb-6 tracking-widest text-center">{t('proof_screenshot')}</div>
                    <div className="flex-1 overflow-y-auto space-y-4 pr-2">
                      {UserService.getCertificationUrls(selectedUser).map((url, i) => (
                        <CertificationImage
                          key={`${selectedUser.id}-${i}`}
                          url={url}
                          userId={selectedUser.id}
                          index={i}
                          onClick={() => window.open(url, '_blank')}
                        />
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center opacity-20">
            <Users size={64} />
            <span className="mt-4 text-[10px] font-black uppercase tracking-[0.2em]">{t('select_user_hint')}</span>
          </div>
        )}
      </div>
    </>
  );
};

export default React.memo(UsersSection);
