import React, { useState, useEffect } from 'react';
import { pb } from './services/pocketbase';
import ArenaPage from './features/arena/components/ArenaPage';
import DashboardView from './features/dashboard/components/DashboardView';
import DeleteAccountPage from './features/auth/components/DeleteAccountPage';
import HomePage from './features/home/components/HomePage';
import { UserRoundCog, LogOut, LayoutDashboard, Trophy, Home } from 'lucide-react';
import { useI18n } from './common/utils/i18n';

// 从 package.json 读取版本号
const APP_VERSION = '2.4.4';

const App = () => {
  const { t, lang, setLang } = useI18n();
  const [isAuthenticated, setIsAuthenticated] = useState(pb.authStore.isValid);
  const [view, setView] = useState<'home' | 'arena' | 'dashboard' | 'delete-account'>('home');
  const [loading, setLoading] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  // 处理 URL 路径，支持直接访问页面
  useEffect(() => {
    const path = window.location.pathname;
    if (path === '/delete-account') {
      setView('delete-account');
    } else if (path === '/arena') {
      setView('arena');
    }
  }, []);

  const handleLogin = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!email || !password) return;

    setLoading(true);
    try {
      await pb.collection('users').authWithPassword(email, password);
      setIsAuthenticated(true);
      setView('dashboard');
      setShowLoginModal(false);
      setEmail('');
      setPassword('');
    } catch (e) {
      alert(t('login_failed') + ': ' + (e as any).message);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    pb.authStore.clear();
    setIsAuthenticated(false);
    setView('home');
  };

  return (
    <div className="h-screen flex flex-col bg-[#F5F5F7]">
      {view !== 'delete-account' && (
        <nav className="flex-shrink-0 h-16 sm:h-20 border-b border-gray-100 bg-white/80 backdrop-blur-md sticky top-0 z-[2000] px-4 sm:px-8 flex items-center justify-between">
          {/* 左侧：Logo */}
          <div className="flex items-center gap-2 sm:gap-3 cursor-pointer group" onClick={() => setView('home')}>
            <div className="w-8 h-8 sm:w-10 sm:h-10 flex items-center justify-center transition-transform group-hover:scale-110">
              <img src="/logo.png" className="w-6 h-6 sm:w-8 sm:h-8 object-contain" alt="Logo" />
            </div>
            <span className="text-xl sm:text-2xl font-black tracking-tighter text-[#1D1D1F]">Puked.</span>
          </div>

          {/* 中间：导航按钮 - 桌面端显示，移动端隐藏 */}
          <div className="hidden md:flex items-center gap-12">
            <button 
              onClick={() => setView('home')}
              className={`flex items-center gap-2.5 text-[15px] font-black uppercase tracking-widest transition-all ${view === 'home' ? 'text-[#007AFF]' : 'text-muted hover:text-[#1D1D1F]'}`}
            >
              <Home size={20} />
              <span>{t('home')}</span>
            </button>

            <button 
              onClick={() => setView('arena')}
              className={`flex items-center gap-2.5 text-[15px] font-black uppercase tracking-widest transition-all ${view === 'arena' ? 'text-[#007AFF]' : 'text-muted hover:text-[#1D1D1F]'}`}
            >
              <Trophy size={20} />
              <span>{t('arena')}</span>
            </button>
            
            {isAuthenticated && (
              <button 
                onClick={() => setView('dashboard')}
                className={`flex items-center gap-2.5 text-[15px] font-black uppercase tracking-widest transition-all ${view === 'dashboard' ? 'text-[#007AFF]' : 'text-muted hover:text-[#1D1D1F]'}`}
              >
                <LayoutDashboard size={20} />
                <span>{t('dashboard')}</span>
              </button>
            )}
          </div>

          {/* 右侧：工具区 */}
          <div className="flex items-center gap-3 sm:gap-6">
            {!isAuthenticated ? (
              <button 
                onClick={() => setShowLoginModal(true)}
                disabled={loading}
                className="p-2 sm:p-3 bg-gray-100 text-muted hover:text-[#007AFF] hover:bg-white hover:shadow-sm rounded-xl transition-all active:scale-95"
                title={t('sign_in')}
              >
                <UserRoundCog size={20} />
              </button>
            ) : (
              <button 
                onClick={handleLogout} 
                className="text-muted hover:text-warning transition-colors p-2 hover:bg-warning/5 rounded-full"
                title={t('sign_out')}
              >
                <LogOut size={20} />
              </button>
            )}

            <div className="flex bg-gray-100 p-1 rounded-xl items-center scale-90 sm:scale-100">
              <button 
                onClick={() => setLang('zh')}
                className={`px-3 sm:px-4 py-1.5 rounded-lg text-[10px] sm:text-[11px] font-black transition-all ${lang === 'zh' ? 'bg-white shadow-sm text-[#007AFF]' : 'text-muted'}`}
              >中</button>
              <button 
                onClick={() => setLang('en')}
                className={`px-3 sm:px-4 py-1.5 rounded-lg text-[10px] sm:text-[11px] font-black transition-all ${lang === 'en' ? 'bg-white shadow-sm text-[#007AFF]' : 'text-muted'}`}
              >EN</button>
            </div>
          </div>
        </nav>
      )}

      <main className="flex-1 overflow-hidden pb-16 md:pb-0">
        {view === 'home' ? (
          <div className="h-full overflow-y-auto custom-scrollbar">
            <HomePage 
              onEnterArena={() => setView('arena')} 
              onLogin={() => setShowLoginModal(true)}
              onNavigateDashboard={() => setView('dashboard')}
              isAuthenticated={isAuthenticated}
            />
          </div>
        ) : view === 'arena' ? (
          <div className="h-full overflow-y-auto custom-scrollbar">
            <ArenaPage />
          </div>
        ) : view === 'dashboard' ? (
          <div className="h-full">
            <DashboardView />
          </div>
        ) : (
          <div className="h-full overflow-y-auto custom-scrollbar">
            <DeleteAccountPage />
          </div>
        )}
      </main>

      {/* 移动端底部 Tab Bar */}
      {view !== 'delete-account' && (
        <nav className="md:hidden fixed bottom-0 inset-x-0 h-16 bg-white/80 backdrop-blur-xl border-t border-gray-100 flex items-center justify-around px-6 z-[2000]">
          <button 
            onClick={() => setView('home')}
            className={`flex flex-col items-center gap-1 transition-all ${view === 'home' ? 'text-[#007AFF]' : 'text-muted'}`}
          >
            <Home size={20} className={view === 'home' ? 'scale-110' : ''} />
            <span className="text-[10px] font-black uppercase tracking-widest">{t('home')}</span>
          </button>

          <button 
            onClick={() => setView('arena')}
            className={`flex flex-col items-center gap-1 transition-all ${view === 'arena' ? 'text-[#007AFF]' : 'text-muted'}`}
          >
            <Trophy size={20} className={view === 'arena' ? 'scale-110' : ''} />
            <span className="text-[10px] font-black uppercase tracking-widest">{t('arena')}</span>
          </button>

          {isAuthenticated && (
            <button 
              onClick={() => setView('dashboard')}
              className={`flex flex-col items-center gap-1 transition-all ${view === 'dashboard' ? 'text-[#007AFF]' : 'text-muted'}`}
            >
              <LayoutDashboard size={20} className={view === 'dashboard' ? 'scale-110' : ''} />
              <span className="text-[10px] font-black uppercase tracking-widest">{t('dashboard')}</span>
            </button>
          )}
        </nav>
      )}

      {/* 登录弹窗 */}
      {showLoginModal && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-black/20 backdrop-blur-sm" onClick={() => !loading && setShowLoginModal(false)} />
          <div className="relative bg-white rounded-[2.5rem] p-10 shadow-2xl border border-gray-100 w-full max-w-md animate-in fade-in zoom-in duration-300">
            <div className="mb-8">
              <h3 className="text-2xl font-black text-[#1D1D1F] tracking-tighter mb-2">{t('admin_login')}</h3>
              <p className="text-muted text-sm font-medium">{t('enter_credentials')}</p>
            </div>
            
            <form onSubmit={handleLogin}>
              <div className="space-y-4 mb-6">
                <input
                  autoFocus
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder={t('email')}
                  className="w-full bg-[#F5F5F7] rounded-2xl px-6 py-4 text-lg font-bold outline-none border-2 border-transparent focus:border-[#007AFF] transition-all"
                  disabled={loading}
                />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder={t('password')}
                  className="w-full bg-[#F5F5F7] rounded-2xl px-6 py-4 text-lg font-bold outline-none border-2 border-transparent focus:border-[#007AFF] transition-all"
                  disabled={loading}
                />
              </div>
              
              <div className="flex gap-4">
                <button
                  type="button"
                  onClick={() => setShowLoginModal(false)}
                  disabled={loading}
                  className="flex-1 py-4 rounded-2xl text-[14px] font-black uppercase tracking-widest text-muted hover:bg-gray-100 transition-all active:scale-95"
                >
                  {t('cancel')}
                </button>
                <button
                  type="submit"
                  disabled={loading || !email || !password}
                  className="flex-1 bg-[#1D1D1F] text-white py-4 rounded-2xl text-[14px] font-black uppercase tracking-widest hover:bg-[#007AFF] disabled:opacity-50 disabled:hover:bg-[#1D1D1F] transition-all active:scale-95 shadow-lg shadow-black/5"
                >
                  {loading ? '...' : t('sign_in')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* 版本号显示 */}
      {view !== 'delete-account' && (
        <div className="fixed bottom-2 left-1/2 -translate-x-1/2 md:bottom-4 text-[10px] text-gray-400 font-medium tracking-wide z-10 pointer-events-none mb-16 md:mb-0">
          v{APP_VERSION}
        </div>
      )}
    </div>
  );
};

export default App;
