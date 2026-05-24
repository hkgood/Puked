import React, { useState, useEffect, useRef } from 'react';
import { useI18n } from '../../../common/utils/i18n';
import { ArrowRight, Github, Smartphone, Video, Apple, PlayCircle } from 'lucide-react';
import AndroidDownloadModal from '../../../common/components/AndroidDownloadModal';
import MacOSDownloadModal from '../../../common/components/MacOSDownloadModal';

interface HomePageProps {
  onEnterArena: () => void;
  onLogin?: () => void;
  onNavigateDashboard?: () => void;
  isAuthenticated?: boolean;
}

const HomePage: React.FC<HomePageProps> = ({ onEnterArena, onLogin, onNavigateDashboard, isAuthenticated }) => {
  const { t } = useI18n();
  const [latestTag, setLatestTag] = useState<string>('2.3.4'); // Default fallback
  const [callbackTag, setCallbackTag] = useState<string>('v1.0.4'); // Default fallback
  const [isDownloadModalOpen, setIsDownloadModalOpen] = useState(false);
  const [isMacDownloadModalOpen, setIsMacDownloadModalOpen] = useState(false);
  const appSectionRef = useRef<HTMLDivElement>(null);
  
  // 用于防止重复请求的标志
  const hasFetchedRef = useRef(false);

  const scrollToApp = () => {
    appSectionRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  /**
   * 检查 GitHub API 速率限制状态
   * @returns 是否可以发起请求（true: 可以，false: 已达限制）
   */
  const checkRateLimit = (): boolean => {
    try {
      const rateLimitKey = 'github-rate-limit-exceeded';
      const cached = localStorage.getItem(rateLimitKey);
      
      if (!cached) return true;
      
      const { resetTime } = JSON.parse(cached);
      const now = Date.now();
      
      // 如果还在速率限制期内
      if (now < resetTime) {
        const resetDate = new Date(resetTime);
        console.info(
          `[HomePage] GitHub API 速率限制中，将在 ${resetDate.toLocaleTimeString()} 重置。使用默认版本。`
        );
        return false;
      }
      
      // 速率限制已重置，清除标记
      localStorage.removeItem(rateLimitKey);
      return true;
    } catch (error) {
      console.warn('[HomePage] 速率限制检查失败:', error);
      return true; // 出错时允许尝试
    }
  };

  /**
   * 记录 GitHub API 速率限制
   * @param resetTimestamp UNIX 时间戳（秒）
   */
  const recordRateLimit = (resetTimestamp?: string): void => {
    try {
      const rateLimitKey = 'github-rate-limit-exceeded';
      // 如果服务器提供了重置时间，使用它；否则默认 1 小时后
      const resetTime = resetTimestamp 
        ? parseInt(resetTimestamp) * 1000 
        : Date.now() + 60 * 60 * 1000;
      
      localStorage.setItem(rateLimitKey, JSON.stringify({ resetTime }));
    } catch (error) {
      console.warn('[HomePage] 记录速率限制失败:', error);
    }
  };

  /**
   * 从 localStorage 获取缓存的版本信息
   * @param key 缓存键名
   * @param maxAgeMs 最大缓存时间（毫秒）
   * @param allowStale 是否允许使用过期缓存（在无法获取新数据时作为降级方案）
   */
  const getCachedVersion = (key: string, maxAgeMs: number = 30 * 60 * 1000, allowStale: boolean = false): string | null => {
    try {
      const cached = localStorage.getItem(key);
      if (!cached) return null;

      const { version, timestamp } = JSON.parse(cached);
      const now = Date.now();
      const age = now - timestamp;

      // 检查缓存是否过期
      if (age > maxAgeMs) {
        if (allowStale) {
          // 允许使用过期缓存（但标记为陈旧）
          const ageMinutes = Math.floor(age / 60000);
          console.info(`[HomePage] 使用过期缓存 (${key}，已过期 ${ageMinutes} 分钟): ${version}`);
          return version;
        } else {
          // 不允许过期缓存，但不删除（保留作为降级方案）
          return null;
        }
      }

      return version;
    } catch (error) {
      console.warn(`[HomePage] 读取缓存失败 (${key}):`, error);
      return null;
    }
  };

  /**
   * 将版本信息缓存到 localStorage
   * @param key 缓存键名
   * @param version 版本号
   */
  const setCachedVersion = (key: string, version: string): void => {
    try {
      const data = {
        version,
        timestamp: Date.now()
      };
      localStorage.setItem(key, JSON.stringify(data));
    } catch (error) {
      console.warn(`Failed to cache version for ${key}:`, error);
    }
  };

  /**
   * 从 GitHub API 获取最新版本（延迟到浏览器空闲时执行，避免阻塞首屏）
   * @param repo 仓库名称
   * @param cacheKey 缓存键名
   * @param setTag 设置状态的函数
   * @param removePrefix 是否移除版本前缀 'v'
   */
  const fetchLatestRelease = (
    repo: string,
    cacheKey: string,
    setTag: (tag: string) => void,
    removePrefix: boolean = false
  ): void => {
    // 首先尝试从缓存读取（只读取未过期的）
    const cachedVersion = getCachedVersion(cacheKey, 30 * 60 * 1000, false);
    if (cachedVersion) {
      console.log(`[HomePage] 使用缓存版本 ${repo}: ${cachedVersion}`);
      setTag(cachedVersion);
      return;
    }

    // 检查速率限制状态，如果已达限制，尝试使用过期缓存
    if (!checkRateLimit()) {
      const staleVersion = getCachedVersion(cacheKey, 30 * 60 * 1000, true);
      if (staleVersion) {
        console.info(`[HomePage] 速率限制中，使用过期缓存版本 ${repo}: ${staleVersion}`);
        setTag(staleVersion);
      } else {
        console.info(`[HomePage] 跳过 ${repo} 的 API 请求（速率限制中），使用默认版本。`);
      }
      return;
    }

    // 🔥 关键修复：使用 requestIdleCallback 延迟到浏览器空闲时执行，避免阻塞首屏
    // 如果 requestIdleCallback 不可用（Safari < 15.4），fallback 到 setTimeout 0
    const defer = typeof requestIdleCallback !== 'undefined'
      ? (cb: () => void) => requestIdleCallback(cb, { timeout: 3000 })
      : (cb: () => void) => setTimeout(cb, 0);

    defer(async () => {
      // 缓存未命中且未达速率限制，从 API 获取
      try {
        const response = await fetch(`https://api.github.com/repos/hkgood/${repo}/releases/latest`, {
          cache: 'no-cache',
        });

        if (response.status === 403) {
          const remaining = response.headers.get('X-RateLimit-Remaining');
          const resetTime = response.headers.get('X-RateLimit-Reset');
          recordRateLimit(resetTime || undefined);

          const staleVersion = getCachedVersion(cacheKey, 30 * 60 * 1000, true);
          if (staleVersion) {
            console.info(
              `[HomePage] GitHub API 速率限制已达到，使用过期缓存版本 ${repo}: ${staleVersion}`
            );
            setTag(staleVersion);
          }
          return;
        }

        if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);

        const data = await response.json();
        if (data.tag_name) {
          let version = data.tag_name;
          if (removePrefix && version.startsWith('v')) version = version.substring(1);
          setTag(version);
          setCachedVersion(cacheKey, version);
          console.log(`[HomePage] 已获取并缓存版本 ${repo}: ${version}`);
        }
      } catch (error) {
        if (error instanceof Error && !error.message.includes('403')) {
          console.warn(`[HomePage] 获取 ${repo} 最新版本失败:`, error.message, '- 使用默认版本');
        }
      }
    });
  };

  useEffect(() => {
    // 处理从 App 跳转过来的自动下载逻辑
    if (window.location.hash === '#download') {
      setIsDownloadModalOpen(true);
      // 清除 hash 避免刷新页面时反复弹出
      window.history.replaceState(null, '', window.location.pathname);
    }

    // 防止 React StrictMode 导致的重复请求
    if (hasFetchedRef.current) {
      return;
    }
    hasFetchedRef.current = true;

    // 串行获取两个仓库的最新版本（已改为 requestIdleCallback 延迟执行，不阻塞首屏）
    // 如果第一个请求遇到速率限制，第二个会自动跳过
    fetchLatestRelease('Puked', 'puked-version', setLatestTag, true);
    fetchLatestRelease('Puked-Callback', 'callback-version', setCallbackTag, false);
  }, []);

  const androidDownloadUrl = `https://download.osglab.com/PukedAPK/Puked-${latestTag}.apk`;
  const macDownloadUrl = `https://download.osglab.com/PukedAPK/Puked_Callback_${callbackTag}.dmg`;

  return (
    <div className="min-h-full bg-[#F5F5F7] overflow-y-auto custom-scrollbar relative">
      {/* Abstract Background Animation */}
      <div className="absolute top-0 inset-x-0 h-[800px] overflow-hidden pointer-events-none z-0">
        <div className="blur-blob w-[500px] h-[500px] bg-blue-400 -top-24 -left-24 animate-drift" />
        <div className="blur-blob w-[600px] h-[600px] bg-purple-300 top-48 -right-24 animate-drift animation-delay-2000" style={{ animationDirection: 'reverse', animationDuration: '25s' }} />
        <div className="blur-blob w-[400px] h-[400px] bg-blue-200 bottom-0 left-1/3 animate-float" />
      </div>

      {/* Hero Section */}
      <section className="relative pt-20 pb-16 px-6 md:pt-32 md:pb-24 max-w-7xl mx-auto text-center z-10">
        <div className="mb-8 animate-in fade-in zoom-in duration-1000 delay-100 group/logo">
          <img 
            src="/logo.png" 
            className="w-24 h-24 md:w-32 md:h-32 mx-auto object-contain transition-all duration-500 hover:scale-110 drop-shadow-[0_20px_25px_rgba(0,0,0,0.15)] hover:drop-shadow-[0_30px_35px_rgba(0,0,0,0.25)]" 
            alt="Puked Logo" 
          />
        </div>
        
        <div className="mb-4 animate-in fade-in slide-in-from-bottom-4 duration-1000 delay-100">
          <h1 className="text-3xl md:text-5xl font-black text-[#1D1D1F] tracking-tight">{t('home_brand')}</h1>
        </div>
        
        <h2 className="text-sm md:text-base text-muted font-medium max-w-2xl mx-auto mb-12 leading-relaxed animate-in fade-in slide-in-from-bottom-6 duration-1000 delay-200">
          {t('home_slogan')}
        </h2>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-4 animate-in fade-in slide-in-from-bottom-10 duration-1000 delay-300">
          <button
            onClick={scrollToApp}
            className="group flex items-center gap-3 bg-[#1D1D1F] text-white px-8 py-4 rounded-full text-sm font-black tracking-tight hover:bg-[#007AFF] transition-all active:scale-95 shadow-xl shadow-black/10"
          >
            {t('home_download_app')}
            <ArrowRight size={18} className="group-hover:translate-x-1 transition-transform" />
          </button>
          
          <a
            href="https://github.com/hkgood/Puked"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-3 bg-white text-[#1D1D1F] px-8 py-4 rounded-full text-sm font-black tracking-tight hover:bg-[#F5F5F7] transition-all border border-gray-100 shadow-sm"
          >
            <Github size={18} />
            {t('home_view_github')}
          </a>
        </div>
      </section>

      {/* App Sections */}
      <section className="px-6 pb-4 max-w-7xl mx-auto space-y-8">
        {/* Puked App Card */}
        <div ref={appSectionRef} className="bg-white rounded-[3rem] p-8 md:py-12 md:px-16 border border-gray-100 shadow-sm group hover:shadow-2xl hover:shadow-black/5 transition-all duration-500 flex flex-col md:flex-row gap-0 md:gap-12 overflow-hidden relative min-h-[500px] md:min-h-[550px]">
          <div className="flex-1 flex flex-col justify-center relative z-20">
            <div className="w-14 h-14 bg-[#007AFF]/5 rounded-2xl flex items-center justify-center mb-8">
              <Smartphone className="text-[#007AFF]" size={32} />
            </div>
            <h2 className="text-2xl md:text-3xl lg:text-5xl font-black text-[#1D1D1F] mb-4 lg:mb-6">{t('app_puked_title')}</h2>
            <p className="text-muted text-sm md:text-base font-medium leading-relaxed mb-6 lg:mb-8">{t('app_puked_desc')}</p>

            {/* Download Buttons */}
            <div className="flex flex-wrap gap-4 mt-2">
              <button
                onClick={() => setIsDownloadModalOpen(true)}
                className="flex items-center gap-2.5 bg-[#1D1D1F] text-white px-5 py-3 rounded-full text-sm font-black transition-all hover:bg-[#007AFF] active:scale-95 shadow-lg shadow-black/5"
              >
                <div className="p-1 bg-white/10 rounded-lg">
                  <PlayCircle size={18} />
                </div>
                <div className="flex flex-col items-start leading-none">
                  <span className="text-[10px] opacity-60 uppercase tracking-wider mb-0.5">{t('download_for')}</span>
                  <span>Android {latestTag}</span>
                </div>
              </button>

              <a 
                href="https://apps.apple.com/us/app/puked-by-rocky/id6757263264"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2.5 bg-white text-[#1D1D1F] px-5 py-3 rounded-full text-sm font-black transition-all hover:bg-[#F5F5F7] active:scale-95 border border-gray-100 shadow-sm"
              >
                <div className="p-1 bg-gray-100 rounded-lg">
                  <Apple size={18} />
                </div>
                <div className="flex flex-col items-start leading-none">
                  <span className="text-[10px] opacity-60 uppercase tracking-wider mb-0.5">App Store</span>
                  <span className="text-[11px]">iOS 下载</span>
                </div>
              </a>
            </div>
          </div>
          
          <div className="flex-1 min-h-[300px] md:min-h-[350px] relative mt-0 md:mt-0 perspective-[1500px] flex items-center justify-center">
            <div className="relative w-full h-full transform-style-3d transition-transform duration-1000 flex items-center justify-center -translate-y-20 md:translate-y-8">
              {/* Bottom Image (A02) */}
              <div className="absolute top-24 md:top-32 right-[25%] md:right-48 w-[35%] rounded-[1.2rem] overflow-hidden shadow-2xl transition-all duration-700 delay-200 translate-x-24 md:translate-x-32 translate-y-[-30px] md:translate-y-[-40px] group-hover:translate-x-32 md:group-hover:translate-x-36 group-hover:translate-y-[-40px] md:group-hover:translate-y-[-45px] z-10 border border-black/5">
                <img 
                  src="/assets/home/A02.jpg" 
                  className="w-full h-auto block" 
                  alt="Puked Interface 3" 
                />
              </div>
              
              {/* Middle Image (A01) */}
              <div className="absolute top-12 md:top-16 right-[35%] md:right-60 w-[40%] rounded-[1.2rem] overflow-hidden shadow-2xl transition-all duration-700 delay-100 translate-x-12 md:translate-x-16 translate-y-[-15px] md:translate-y-[-20px] group-hover:translate-x-16 md:group-hover:translate-x-20 group-hover:translate-y-[-20px] md:group-hover:translate-y-[-25px] z-20 border border-black/5">
                <img 
                  src="/assets/home/A01.jpg" 
                  className="w-full h-auto block" 
                  alt="Puked Interface 2" 
                />
              </div>
              
              {/* Top Image (A00) */}
              <div className="absolute top-0 right-[45%] md:right-72 w-[45%] rounded-[1.2rem] overflow-hidden shadow-2xl transition-all duration-700 translate-x-[-8px] md:translate-x-[-10px] translate-y-[-4px] md:translate-y-[-5px] group-hover:translate-x-[-12px] md:group-hover:translate-x-[-14px] group-hover:translate-y-[-6px] md:group-hover:translate-y-[-7px] z-30 ring-2 ring-white border border-black/5">
                <img 
                  src="/assets/home/A00.jpg" 
                  className="w-full h-auto block" 
                  alt="Puked Interface 1" 
                />
              </div>
            </div>
          </div>
        </div>

        {/* CallBack Card */}
        <div className="bg-[#1D1D1F] rounded-[3rem] p-8 md:py-12 md:px-16 border border-white/5 shadow-2xl group flex flex-col md:flex-row-reverse gap-12 overflow-hidden relative min-h-[500px] md:min-h-[550px]">
          <div className="flex-1 flex flex-col justify-center relative z-10">
            <div className="w-14 h-14 bg-white/10 rounded-2xl flex items-center justify-center mb-8">
              <Video className="text-white" size={32} />
            </div>
            <h2 className="text-2xl md:text-3xl lg:text-5xl font-black text-white mb-4 lg:mb-6">{t('app_callback_title')}</h2>
            <p className="text-gray-400 text-sm md:text-base font-medium leading-relaxed mb-8 lg:mb-10">{t('app_callback_desc')}</p>
            
            {/* Download Buttons for CallBack */}
            <div className="flex flex-wrap gap-4 mt-2">
              <button
                onClick={() => setIsMacDownloadModalOpen(true)}
                className="flex items-center gap-2.5 bg-white text-[#1D1D1F] px-5 py-3 rounded-full text-sm font-black transition-all hover:bg-[#F5F5F7] active:scale-95 shadow-lg shadow-black/5"
              >
                <div className="p-1 bg-gray-100 rounded-lg">
                  <Apple size={18} />
                </div>
                <div className="flex flex-col items-start leading-none">
                  <span className="text-[10px] opacity-60 uppercase tracking-wider mb-0.5">{t('download_macos')}</span>
                  <span>macOS {callbackTag}</span>
                </div>
              </button>
            </div>
          </div>

          <div className="flex-1 min-h-[300px] md:min-h-[350px] flex items-center justify-center relative perspective-[1000px]">
            <div className="relative w-full h-full flex items-center justify-center group-hover:scale-[1.05] transition-all duration-700 ease-out">
              {/* 背景发光效果 */}
              <div className="absolute w-2/3 h-2/3 bg-[#007AFF] opacity-0 group-hover:opacity-20 blur-[100px] transition-opacity duration-1000" />
              
              <img 
                src="/assets/home/Callback.png" 
                className="w-full h-auto md:max-h-[130%] object-contain opacity-90 group-hover:opacity-100 transition-all duration-700 group-hover:[transform:translateZ(20px)] drop-shadow-[0_0_30px_rgba(0,0,0,0.3)] group-hover:drop-shadow-[0_20px_50px_rgba(0,0,0,0.5)]" 
                alt="CallBack Rendering" 
              />
            </div>
          </div>

          <div className="absolute top-0 left-0 w-96 h-96 bg-[#007AFF] opacity-10 blur-[120px] -ml-48 -mt-48" />
        </div>

        {/* Web App Card */}
        <div className="bg-[#007AFF] rounded-[3rem] pt-10 md:pt-16 px-8 md:px-16 border border-[#007AFF] shadow-xl group flex flex-col items-center text-center overflow-hidden relative">
           <div className="relative z-10 flex flex-col items-center w-full">
            <h2 className="text-2xl md:text-3xl lg:text-5xl font-black text-white mb-2 md:mb-4">{t('app_web_title')}</h2>
            <p className="text-white/80 text-sm md:text-base font-medium mb-6 md:mb-8 max-w-lg">{t('app_web_subtitle')}</p>
            
            <button 
              onClick={() => isAuthenticated ? onNavigateDashboard?.() : onLogin?.()}
              className="px-8 py-4 bg-white/10 backdrop-blur-md rounded-full text-sm md:text-base font-black text-white border border-white/20 hover:bg-white/20 transition-all active:scale-95 shadow-lg mb-2 md:mb-4"
            >
              {isAuthenticated ? t('dashboard') : t('admin_login')}
            </button>

            {/* 3 Images Stacked/Overlapping - Bleeding at bottom */}
            <div className="relative w-full max-w-6xl mt-auto translate-y-12 md:translate-y-24 transition-transform duration-700 group-hover:translate-y-10 md:group-hover:translate-y-20">
              <div className="flex items-center justify-center -space-x-24 md:-space-x-28 lg:-space-x-36 w-full px-4">
                {/* Side Left (web2) */}
                <div className="w-[45%] md:w-[32%] z-0 opacity-40 scale-95 transition-all duration-1000 group-hover:opacity-70 group-hover:scale-105 group-hover:-translate-x-12 group-hover:-rotate-6">
                  <img src="/assets/home/web2.png" className="w-full h-auto rounded-xl md:rounded-3xl shadow-xl border border-white/10" alt="Web Feature 2" />
                </div>
                
                {/* Middle Main (web1) */}
                <div className="w-[75%] md:w-[48%] z-20 scale-105 transition-all duration-1000 group-hover:scale-115">
                  <img src="/assets/home/web1.png" className="w-full h-auto rounded-xl md:rounded-3xl shadow-[0_30px_60px_rgba(0,0,0,0.4)] border border-white/20" alt="Web Feature 1" />
                </div>
                
                {/* Side Right (web3) */}
                <div className="w-[45%] md:w-[32%] z-0 opacity-40 scale-95 transition-all duration-1000 group-hover:opacity-70 group-hover:scale-105 group-hover:translate-x-12 group-hover:rotate-6">
                  <img src="/assets/home/web3.png" className="w-full h-auto rounded-xl md:rounded-3xl shadow-xl border border-white/10" alt="Web Feature 3" />
                </div>
              </div>
            </div>
          </div>

          <div className="absolute bottom-0 right-0 w-96 h-96 bg-black/10 rounded-full blur-[80px] -mb-48 -mr-48" />
        </div>
      </section>

      {/* Footer Branding */}
      <footer className="py-4 px-6 text-center border-t border-gray-100">
        <div className="flex items-center justify-center gap-2 mb-4">
          <img src="/logo.png" className="w-6 h-6 opacity-50" alt="Logo" />
          <span className="text-xl font-black tracking-tighter text-[#1D1D1F] opacity-30">Puked.</span>
        </div>
        <p className="text-xs font-bold text-muted uppercase tracking-[0.2em]">© 2024 Puked Team. All rights reserved.</p>
      </footer>

      {/* Android Download Modal */}
      <AndroidDownloadModal
        isOpen={isDownloadModalOpen}
        onClose={() => setIsDownloadModalOpen(false)}
        version={latestTag}
        directDownloadUrl={androidDownloadUrl}
      />

      {/* macOS Download Modal */}
      <MacOSDownloadModal
        isOpen={isMacDownloadModalOpen}
        onClose={() => setIsMacDownloadModalOpen(false)}
        version={callbackTag}
        directDownloadUrl={macDownloadUrl}
      />
    </div>
  );
};

export default HomePage;
