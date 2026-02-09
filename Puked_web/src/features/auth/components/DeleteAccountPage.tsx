import React, { useState, useEffect } from 'react';
import { pb } from '../../../services/pocketbase';
import { useI18n } from '../../../common/utils/i18n';
import { Trash2, AlertTriangle, LogIn, CheckCircle2 } from 'lucide-react';

const DeleteAccountPage = () => {
  const { t } = useI18n();
  const [isAuthenticated, setIsAuthenticated] = useState(pb.authStore.isValid);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [tripCount, setTripCount] = useState<number | null>(null);
  const [isDeleted, setIsDeleted] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isAuthenticated && pb.authStore.model) {
      fetchTripCount();
    }
  }, [isAuthenticated]);

  const fetchTripCount = async () => {
    try {
      const result = await pb.collection('trips').getList(1, 1, {
        filter: `user = "${pb.authStore.model?.id}"`,
        fields: 'id',
      });
      setTripCount(result.totalItems);
    } catch (e) {
      console.error('Fetch trip count error:', e);
    }
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      await pb.collection('users').authWithPassword(email, password);
      setIsAuthenticated(true);
    } catch (e: any) {
      setError(e.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteAccount = async () => {
    if (!window.confirm(t('confirm_delete_account'))) return;

    setLoading(true);
    setError(null);
    try {
      const userId = pb.authStore.model?.id;
      if (!userId) throw new Error('User not found');

      // 1. 获取所有相关的行程并删除
      // 注意：PocketBase 允许通过 API Rules 批量删除，或者循环删除
      // 这里为了简单直接循环删除，如果数据量极大可能需要后端处理
      const trips = await pb.collection('trips').getFullList({
        filter: `user = "${userId}"`,
        fields: 'id',
      });

      for (const trip of trips) {
        await pb.collection('trips').delete(trip.id);
      }

      // 2. 删除用户自己
      await pb.collection('users').delete(userId);

      // 3. 清理本地状态
      pb.authStore.clear();
      setIsDeleted(true);
    } catch (e: any) {
      setError(e.message || 'Deletion failed');
    } finally {
      setLoading(false);
    }
  };

  if (isDeleted) {
    return (
      <div className="min-h-screen flex items-center justify-center p-6 bg-[#F5F5F7]">
        <div className="bg-white rounded-[2.5rem] p-12 shadow-2xl border border-gray-100 w-full max-w-md text-center animate-in fade-in zoom-in duration-500">
          <div className="w-20 h-20 bg-green-50 text-green-500 rounded-full flex items-center justify-center mx-auto mb-8">
            <CheckCircle2 size={40} />
          </div>
          <h2 className="text-3xl font-black text-[#1D1D1F] tracking-tighter mb-4">{t('delete_success')}</h2>
          <p className="text-muted font-medium mb-8">{t('delete_account_desc')}</p>
          <button
            onClick={() => window.location.href = '/'}
            className="w-full bg-[#1D1D1F] text-white py-4 rounded-2xl text-[14px] font-black uppercase tracking-widest hover:bg-[#007AFF] transition-all active:scale-95 shadow-lg shadow-black/5"
          >
            {t('ok')}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-6 bg-[#F5F5F7]">
      <div className="bg-white rounded-[2.5rem] p-10 shadow-2xl border border-gray-100 w-full max-w-md animate-in fade-in zoom-in duration-300">
        <div className="mb-8 text-center">
          <div className="w-16 h-16 bg-red-50 text-red-500 rounded-2xl flex items-center justify-center mx-auto mb-6">
            <Trash2 size={32} />
          </div>
          <h1 className="text-2xl font-black text-[#1D1D1F] tracking-tighter mb-2">{t('delete_account')}</h1>
          <p className="text-muted text-sm font-medium">{t('delete_account_desc')}</p>
        </div>

        {!isAuthenticated ? (
          <form onSubmit={handleLogin} className="space-y-4">
            <div className="space-y-3">
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder={t('email')}
                className="w-full bg-[#F5F5F7] rounded-2xl px-6 py-4 text-lg font-bold outline-none border-2 border-transparent focus:border-[#007AFF] transition-all"
                required
              />
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder={t('password')}
                className="w-full bg-[#F5F5F7] rounded-2xl px-6 py-4 text-lg font-bold outline-none border-2 border-transparent focus:border-[#007AFF] transition-all"
                required
              />
            </div>
            {error && <p className="text-red-500 text-sm font-bold px-2">{error}</p>}
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-[#1D1D1F] text-white py-4 rounded-2xl text-[14px] font-black uppercase tracking-widest hover:bg-[#007AFF] disabled:opacity-50 transition-all flex items-center justify-center gap-2"
            >
              <LogIn size={18} />
              {loading ? '...' : t('sign_in')}
            </button>
          </form>
        ) : (
          <div className="space-y-6">
            <div className="bg-red-50 rounded-2xl p-6 border border-red-100">
              <div className="flex items-start gap-4 text-red-600 mb-4">
                <AlertTriangle className="shrink-0" size={24} />
                <p className="font-bold text-sm leading-relaxed">
                  {t('delete_account_warning')}
                </p>
              </div>
              
              <div className="flex justify-between items-center py-3 border-t border-red-100">
                <span className="text-sm font-bold text-red-900/60">{t('trips_to_be_deleted')}</span>
                <span className="text-xl font-black text-red-600">{tripCount !== null ? tripCount : '...'}</span>
              </div>
            </div>

            <div className="space-y-3">
              <button
                onClick={handleDeleteAccount}
                disabled={loading}
                className="w-full bg-red-500 text-white py-4 rounded-2xl text-[14px] font-black uppercase tracking-widest hover:bg-red-600 disabled:opacity-50 transition-all shadow-lg shadow-red-500/20 active:scale-95"
              >
                {loading ? t('deleting') : t('confirm_delete_account')}
              </button>
              <button
                onClick={() => window.location.href = '/'}
                disabled={loading}
                className="w-full bg-gray-100 text-muted py-4 rounded-2xl text-[14px] font-black uppercase tracking-widest hover:bg-gray-200 transition-all active:scale-95"
              >
                {t('cancel')}
              </button>
            </div>
            {error && <p className="text-red-500 text-sm font-bold text-center">{error}</p>}
          </div>
        )}
      </div>
    </div>
  );
};

export default DeleteAccountPage;
