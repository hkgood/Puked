/**
 * Cloudflare Workers - GitHub Release 加速代理
 * 用途: 加速 Puked 应用的 GitHub Release APK 下载
 * 部署: Cloudflare Workers
 */

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  const url = new URL(request.url)
  
  // 记录访问日志（调试用）
  console.log(`[Request] ${url.pathname}`)
  
  // 根路径显示使用说明
  if (url.pathname === '/' || url.pathname === '') {
    return new Response(getUsageHTML(), {
      headers: { 
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'public, max-age=3600'
      }
    })
  }
  
  // 提取 GitHub 路径
  // 支持两种格式:
  // 1. /hkgood/Puked/releases/download/v2.4.0/Puked-2.4.0.apk
  // 2. /https://github.com/hkgood/Puked/releases/download/v2.4.0/Puked-2.4.0.apk
  let githubPath = url.pathname
  
  // 如果路径包含完整的 GitHub URL，提取路径部分
  if (githubPath.includes('github.com')) {
    githubPath = githubPath.split('github.com')[1]
  }
  
  // 确保路径以 / 开头
  if (!githubPath.startsWith('/')) {
    githubPath = '/' + githubPath
  }
  
  // 安全检查：只允许访问特定仓库（可选）
  const allowedRepos = [
    '/hkgood/Puked/',
    // 可以添加其他需要加速的仓库
  ]
  
  const isAllowed = allowedRepos.some(repo => githubPath.startsWith(repo))
  
  if (!isAllowed) {
    return new Response(
      JSON.stringify({
        error: 'Forbidden',
        message: '只允许访问 hkgood/Puked 仓库',
        allowed_repos: allowedRepos
      }), 
      {
        status: 403,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
  
  // 构建 GitHub URL
  const githubUrl = `https://github.com${githubPath}${url.search}`
  console.log(`[Proxy] ${githubUrl}`)
  
  try {
    // 转发请求到 GitHub
    const response = await fetch(githubUrl, {
      method: request.method,
      headers: request.headers,
      redirect: 'follow'  // 自动跟随 GitHub 的重定向
    })
    
    // 创建新的响应，添加缓存和 CORS 头
    const newHeaders = new Headers(response.headers)
    
    // 添加 CORS 支持（如果需要从浏览器访问）
    newHeaders.set('Access-Control-Allow-Origin', '*')
    newHeaders.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
    
    // 添加缓存头（APK 文件可以长期缓存）
    if (githubPath.endsWith('.apk')) {
      newHeaders.set('Cache-Control', 'public, max-age=31536000') // 1年
    }
    
    // 添加自定义头，标识经过了代理
    newHeaders.set('X-Proxy-By', 'Cloudflare Workers')
    newHeaders.set('X-Original-URL', githubUrl)
    
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: newHeaders
    })
    
  } catch (error) {
    console.error('[Error]', error)
    
    return new Response(
      JSON.stringify({
        error: 'Proxy Failed',
        message: error.message,
        github_url: githubUrl
      }), 
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
}

// 返回使用说明的 HTML 页面
function getUsageHTML() {
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Puked GitHub Release 加速代理</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .container {
      background: white;
      border-radius: 16px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      max-width: 800px;
      padding: 40px;
    }
    h1 {
      color: #667eea;
      margin-bottom: 10px;
      font-size: 28px;
    }
    .subtitle {
      color: #666;
      margin-bottom: 30px;
      font-size: 14px;
    }
    .status {
      background: #10b981;
      color: white;
      padding: 12px 20px;
      border-radius: 8px;
      margin-bottom: 30px;
      display: inline-block;
      font-weight: 500;
    }
    .section {
      margin-bottom: 30px;
    }
    h2 {
      color: #333;
      margin-bottom: 15px;
      font-size: 18px;
      display: flex;
      align-items: center;
    }
    h2::before {
      content: "→";
      margin-right: 10px;
      color: #667eea;
    }
    .code-block {
      background: #f7fafc;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 15px;
      margin: 10px 0;
      overflow-x: auto;
      font-family: "Monaco", "Courier New", monospace;
      font-size: 13px;
      line-height: 1.6;
    }
    .original { color: #e53e3e; }
    .proxy { color: #10b981; }
    .example {
      background: #fef3c7;
      border-left: 4px solid #f59e0b;
      padding: 15px;
      margin: 15px 0;
      border-radius: 4px;
    }
    .footer {
      text-align: center;
      color: #999;
      font-size: 12px;
      margin-top: 40px;
      padding-top: 20px;
      border-top: 1px solid #eee;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>🚀 Puked GitHub Release 加速代理</h1>
    <p class="subtitle">通过 Cloudflare 全球 CDN 加速下载</p>
    
    <div class="status">✅ 服务运行正常</div>
    
    <div class="section">
      <h2>使用方法</h2>
      <p>将 GitHub Release 的 URL 替换为代理地址：</p>
      
      <div class="code-block">
        <div class="original">原始地址:</div>
        https://github.com/hkgood/Puked/releases/download/v2.4.0/Puked-2.4.0.apk
        
        <div class="proxy">代理地址:</div>
        <strong>${new URL('https://placeholder.com').origin}</strong>/hkgood/Puked/releases/download/v2.4.0/Puked-2.4.0.apk
      </div>
    </div>
    
    <div class="section">
      <h2>使用示例</h2>
      <div class="example">
        <strong>wget 下载:</strong>
        <div class="code-block">
wget ${new URL('https://placeholder.com').origin}/hkgood/Puked/releases/download/v2.4.0/Puked-2.4.0.apk
        </div>
      </div>
      
      <div class="example">
        <strong>curl 下载:</strong>
        <div class="code-block">
curl -O ${new URL('https://placeholder.com').origin}/hkgood/Puked/releases/download/v2.4.0/Puked-2.4.0.apk
        </div>
      </div>
    </div>
    
    <div class="section">
      <h2>特性</h2>
      <ul style="line-height: 2; color: #555;">
        <li>✅ 全球 CDN 加速，国内访问速度显著提升</li>
        <li>✅ 自动跟随 GitHub Release，无需手动同步</li>
        <li>✅ 支持大文件下载，无大小限制</li>
        <li>✅ 长期缓存，减少源站压力</li>
      </ul>
    </div>
    
    <div class="footer">
      Powered by Cloudflare Workers | Puked © 2024
    </div>
  </div>
</body>
</html>`
}
