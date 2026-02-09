# Cloudflare Workers - GitHub Release 加速代理

## 📁 文件说明

```
cloudflare-worker/
├── github-proxy.js          # Worker 代码（复制到 Cloudflare）
├── DEPLOYMENT_GUIDE.md      # 详细部署教程
├── QUICK_START.md           # 快速开始指南（推荐）
└── README.md                # 本文件
```

## 🚀 快速开始

### 1. 打开 Cloudflare Dashboard
访问: https://dash.cloudflare.com/?to=/:account/workers

### 2. 创建 Worker
点击 **Create** → **Create Worker**

### 3. 部署代码
1. 点击 **Edit code**
2. 复制 `github-proxy.js` 的内容
3. 粘贴到编辑器
4. 点击 **Save and Deploy**

### 4. 获取 URL
你会得到类似这样的 URL：
```
https://github-proxy.YOUR_ACCOUNT.workers.dev
```

### 5. 测试
浏览器打开上面的 URL，应该看到使用说明页面。

测试下载：
```
https://github-proxy.YOUR_ACCOUNT.workers.dev/hkgood/Puked/releases/download/v2.4.0/Puked-2.4.0.apk
```

## 📚 文档

- **新手推荐**: 先看 `QUICK_START.md`（快速参考卡片）
- **详细教程**: 看 `DEPLOYMENT_GUIDE.md`（一步步指导）

## 🎯 使用方法

### 原始 GitHub URL
```
https://github.com/hkgood/Puked/releases/download/v2.4.0/Puked-2.4.0.apk
```

### 加速后的 URL
```
https://YOUR_WORKER_URL/hkgood/Puked/releases/download/v2.4.0/Puked-2.4.0.apk
```

## 🔧 自定义域名（可选）

如果你想使用自己的域名（如 `gh-proxy.osglab.com`）：

1. Worker 详情页 → **Settings** → **Triggers**
2. **Custom Domains** → **Add Custom Domain**
3. 输入: `gh-proxy.osglab.com`
4. Cloudflare 会自动配置 DNS 和 SSL

## 📊 监控

Worker 部署后，可以在 Cloudflare Dashboard 查看：

- **Metrics**: 请求次数、响应时间、成功率
- **Logs**: 实时日志流
- **Analytics**: 流量统计

## 💰 费用

**完全免费！**

- 免费额度: 每天 100,000 次请求
- 流量限制: 无
- 存储空间: 不需要（Worker 是代理，不存储文件）

对于 Puked 应用的更新需求，免费额度**绰绰有余**。

## ✨ 特性

- ✅ **零成本**: 完全免费
- ✅ **零维护**: 自动跟随 GitHub Release
- ✅ **全球 CDN**: Cloudflare 的全球节点
- ✅ **国内加速**: 显著提升国内下载速度
- ✅ **大文件支持**: 无大小限制
- ✅ **自动缓存**: 减少源站压力

## 🔐 安全性

Worker 代码包含白名单机制，只允许访问：
```javascript
const allowedRepos = [
  '/hkgood/Puked/',
  // 可以添加其他需要加速的仓库
]
```

这样可以防止你的 Worker 被滥用。

## 🎉 效果

部署后，你的应用会自动选择最快的下载源：

```
🔍 Testing download mirrors...
✅ Fastest: Cloudflare CDN (150ms)  ← 你的 Worker
⏱️ Fallback: OSGLab镜像 (320ms)
⏱️ Other: GHProxy镜像 (280ms)
⏱️ Other: GitHub直连 (1200ms)
```

国内用户下载速度预计提升 **5-10 倍**！

## 📞 问题反馈

如果部署过程中遇到问题，请查看：
1. `DEPLOYMENT_GUIDE.md` 的故障排查部分
2. Cloudflare Workers 日志（实时查看错误）

## 🔗 相关链接

- [Cloudflare Workers 文档](https://developers.cloudflare.com/workers/)
- [Cloudflare Dashboard](https://dash.cloudflare.com/)
- [GitHub Release 文档](https://docs.github.com/en/repositories/releasing-projects-on-github)
