import React from 'react';
import { X, Cloud, Github, Download } from 'lucide-react';
import { useI18n } from '../utils/i18n';

interface MacOSDownloadModalProps {
  isOpen: boolean;
  onClose: () => void;
  version: string;
  directDownloadUrl: string;
}

const MacOSDownloadModal: React.FC<MacOSDownloadModalProps> = ({
  isOpen,
  onClose,
  version,
  directDownloadUrl,
}) => {
  const { t } = useI18n();

  if (!isOpen) return null;

  const downloadSources = [
    {
      name: t('download_baidu_cloud'),
      url: 'https://pan.baidu.com/s/5rHGMfeFevrg5MA3UerZ0dQ?',
      icon: Cloud,
      tag: t('download_recommended_domestic'),
      tagColor: 'bg-blue-500',
      subtitle: undefined,
    },
    {
      name: t('download_quark_cloud'),
      url: 'https://pan.quark.cn/s/b350393205a0',
      icon: Cloud,
      tag: t('download_recommended_domestic'),
      tagColor: 'bg-blue-500',
      subtitle: undefined,
    },
    {
      name: t('download_github'),
      url: 'https://github.com/hkgood/Puked-Callback/releases',
      icon: Github,
      tag: t('download_official'),
      tagColor: 'bg-gray-600',
      subtitle: undefined,
    },
    {
      name: t('download_local'),
      url: directDownloadUrl,
      icon: Download,
      tag: t('download_mirror'),
      tagColor: 'bg-green-600',
      subtitle: undefined,
    },
  ];

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 animate-in fade-in duration-200"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4 pointer-events-none">
        <div
          className="bg-white rounded-3xl shadow-2xl max-w-md w-full pointer-events-auto animate-in zoom-in-95 fade-in duration-300"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="relative px-8 pt-8 pb-4 border-b border-gray-100">
            <button
              onClick={onClose}
              className="absolute top-6 right-6 p-2 rounded-full hover:bg-gray-100 transition-colors"
              aria-label="Close"
            >
              <X size={20} className="text-gray-500" />
            </button>
            <h2 className="text-2xl font-black text-[#1D1D1F] mb-1">
              {t('download_macos_title')}
            </h2>
            <p className="text-sm text-gray-500 font-medium">
              {t('download_macos_subtitle')} · {version}
            </p>
          </div>

          {/* Download Options */}
          <div className="p-6 space-y-3">
            {downloadSources.map((source, index) => {
              const Icon = source.icon;
              return (
                <a
                  key={index}
                  href={source.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="group flex items-center gap-4 p-4 rounded-2xl border border-gray-200 hover:border-[#007AFF] hover:bg-[#007AFF]/5 transition-all active:scale-[0.98]"
                >
                  {/* Icon */}
                  <div className="flex-shrink-0 w-12 h-12 bg-gray-100 rounded-xl flex items-center justify-center group-hover:bg-[#007AFF]/10 transition-colors">
                    <Icon size={24} className="text-gray-600 group-hover:text-[#007AFF] transition-colors" />
                  </div>

                  {/* Content */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-sm font-bold text-[#1D1D1F]">
                        {source.name}
                      </span>
                      <span className={`text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full text-white ${source.tagColor}`}>
                        {source.tag}
                      </span>
                    </div>
                    {source.subtitle && (
                      <p className="text-xs text-gray-500 font-medium">
                        {source.subtitle}
                      </p>
                    )}
                  </div>

                  {/* Arrow */}
                  <div className="flex-shrink-0">
                    <svg
                      className="w-5 h-5 text-gray-400 group-hover:text-[#007AFF] group-hover:translate-x-1 transition-all"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M9 5l7 7-7 7"
                      />
                    </svg>
                  </div>
                </a>
              );
            })}
          </div>
        </div>
      </div>
    </>
  );
};

export default MacOSDownloadModal;
