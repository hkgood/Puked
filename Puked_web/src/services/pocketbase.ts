import PocketBase from 'pocketbase';

// 修正：为了本地调试方便，直接指向生产环境
// 这样你在本地启动 npm run dev 也能看到真实的数据
const PB_URL = 'https://pb.osglab.com';

export const pb = new PocketBase(PB_URL);

// 配置 PocketBase 的自动重连和错误处理
pb.autoCancellation(false); // 禁用自动取消，避免 HTTP/2 连接问题

// 修复弃用警告：getUrl -> getURL
export const getFileUrl = (record: any, fileName: string) => {
  if (!fileName) return null;
  return pb.files.getURL(record, fileName);
};

// 添加全局错误处理，捕获 HTTP/2 协议错误
if (typeof window !== 'undefined') {
  // 监听未处理的 Promise 拒绝
  window.addEventListener('unhandledrejection', (event) => {
    const error = event.reason;

    // 1. 处理 HTTP/2 协议错误
    if (error?.message?.includes('ERR_HTTP2_PROTOCOL_ERROR')) {
      console.warn('[PocketBase] HTTP/2 协议错误被捕获', error);
      event.preventDefault();
    }

    // 2. 处理 401 认证过期（自动清理本地存储并提示，或静默清理）
    if (error?.status === 401) {
      console.warn('[PocketBase] 认证失效，正在清理会话...');
      pb.authStore.clear();
      // 这里不强制跳转，由 UI 层根据 pb.authStore.isValid 响应
    }
  });
}

/**
 * 统一 PocketBase 错误包装器
 * 自动提取后端返回的错误消息
 */
export const handlePBError = (error: any): string => {
  console.error('[PocketBase Error]', error);
  if (error?.data?.message) return error.data.message;
  if (error?.message) return error.message;
  return '未知错误';
};
