# Cloudflare Workers 部署步骤（详细版）

## 📋 前置条件

- ✅ 一个 Cloudflare 账号（免费版即可）
- ✅ 已经有域名在 Cloudflare 托管（如 osglab.com）

---

## 🚀 部署步骤

### 步骤 1: 登录 Cloudflare Dashboard

1. 打开浏览器，访问：https://dash.cloudflare.com/
2. 使用你的账号登录
3. 登录后会看到你的域名列表

---

### 步骤 2: 进入 Workers & Pages

1. 在左侧菜单中找到 **"Workers & Pages"**
2. 点击进入 Workers 管理页面

或者直接访问：https://dash.cloudflare.com/?to=/:account/workers

---

### 步骤 3: 创建新的 Worker

1. 点击右上角的 **"Create application"** 或 **"Create"** 按钮
2. 选择 **"Create Worker"**
3. 会看到一个默认的 Worker 名称，例如：`worker-silent-brook-1234`
4. **修改名称**为有意义的名字，例如：`github-proxy` 或 `puked-release-proxy`
5. 点击 **"Deploy"** 按钮

此时 Cloudflare 会创建一个默认的 Worker，并分配一个 URL，例如：
```
https://github-proxy.your-account.workers.dev
```

---

### 步骤 4: 编辑 Worker 代码

1. 部署完成后，点击 **"Edit code"** 按钮
2. 你会看到一个在线代码编辑器，里面有默认的示例代码
3. **全选删除**默认代码（Ctrl+A / Cmd+A，然后 Delete）
4. 复制我准备好的代码：

**代码位置**: `cloudflare-worker/github-proxy.js`

5. **粘贴**到编辑器中
6. 点击右上角的 **"Save and Deploy"** 按钮

---

### 步骤 5: 测试 Worker

部署成功后，你会得到一个 Worker URL，例如：
```
https://github-proxy.your-account.workers.dev
```

#### 测试 1: 访问首页

在浏览器中打开这个 URL，你应该看到一个漂亮的使用说明页面。

#### 测试 2: 测试下载加速

在浏览器中访问（替换成你的 Worker URL）：
```
https://github-proxy.your-account.workers.dev/hkgood/Puked/releases/download/v2.4.0/Puked-2.4.0.apk
```

如果一切正常，会开始下载 APK 文件。

#### 测试 3: 命令行测试

```bash
# 测试响应速度
curl -I https://github-proxy.your-account.workers.dev/hkgood/Puked/releases/download/v2.4.0/Puked-2.4.0.apk

# 实际下载测试
wget https://github-proxy.your-account.workers.dev/hkgood/Puked/releases/download/v2.4.0/Puked-2.4.0.apk
```

---

### 步骤 6: 绑定自定义域名（推荐）

使用默认的 `*.workers.dev` 域名也可以，但绑定自定义域名更专业。

#### 6.1 添加自定义域名

1. 在 Worker 详情页面，找到 **"Settings"** → **"Triggers"** 标签
2. 在 **"Custom Domains"** 部分，点击 **"Add Custom Domain"**
3. 输入你想要的子域名，例如：`gh-proxy.osglab.com`
4. 点击 **"Add Custom Domain"**

Cloudflare 会自动：
- 创建 DNS 记录
- 配置 SSL 证书
- 绑定到你的 Worker

#### 6.2 测试自定义域名

等待几分钟后，访问：
```
https://gh-proxy.osglab.com
```

应该能看到使用说明页面。

---

### 步骤 7: 更新 Flutter 代码

现在需要把这个新的加速源添加到你的应用中。

打开文件：`Puked/lib/services/update_service.dart`

找到这段代码（大约在第 20 行）：

```dart
// GitHub 镜像加速服务（国内优化）
static const List<Map<String, String>> _githubMirrors = [
  {
    'name': 'GHProxy镜像',
    'prefix': 'https://mirror.ghproxy.com/',
  },
  // ... 其他镜像
];
```

在列表**最前面**添加你的 Cloudflare Worker：

```dart
static const List<Map<String, String>> _githubMirrors = [
  {
    'name': 'Cloudflare CDN',
    'prefix': 'https://gh-proxy.osglab.com/',  // 替换成你的域名
  },
  {
    'name': 'GHProxy镜像',
    'prefix': 'https://mirror.ghproxy.com/',
  },
  // ... 其他镜像
];
```

**注意**：
- 如果使用自定义域名，填 `https://gh-proxy.osglab.com/`
- 如果使用默认域名，填 `https://github-proxy.your-account.workers.dev/`
- 末尾的 `/` 不要忘记

---

### 步骤 8: 重新编译应用

```bash
cd /Users/maxliu/Documents/PukedMaster/Puked

# 构建 APK
flutter build apk --release
```

---

## 🎯 完成！验证效果

### 在应用中测试

1. 安装新编译的 APK
2. 进入【设置】→【检查更新】
3. 查看日志，应该能看到：

```
🔍 Testing download mirrors...
✅ Fastest: Cloudflare CDN (150ms)  ← 你的 Worker
⏱️ Fallback: OSGLab镜像 (320ms)
📊 Other available mirrors: 5
```

### 查看 Cloudflare 统计

1. 回到 Cloudflare Dashboard
2. 进入你的 Worker 详情页
3. 点击 **"Metrics"** 标签
4. 可以看到：
   - 请求次数
   - 响应时间
   - 错误率
   - 流量统计

---

## 📊 监控和维护

### 查看实时日志

1. 在 Worker 详情页，点击 **"Logs"** 标签
2. 点击 **"Begin log stream"**
3. 会实时显示所有请求

### 免费额度

Cloudflare Workers 免费版：
- ✅ 每天 100,000 次请求
- ✅ 每次请求最多 10ms CPU 时间
- ✅ 无流量限制

对于 Puked 这样的应用，**完全够用**！

---

## 🔧 故障排查

### 问题 1: Worker 返回 403 Forbidden

**原因**: 代码中的仓库白名单限制

**解决**: 检查代码中的 `allowedRepos` 数组，确保包含你的仓库路径

### 问题 2: 下载速度没有提升

**原因**: 
1. 首次请求还没缓存
2. Cloudflare CDN 节点需要预热

**解决**: 多请求几次，让 CDN 缓存文件

### 问题 3: 无法绑定自定义域名

**原因**: 域名没有托管在 Cloudflare

**解决**: 
1. 确保域名在 Cloudflare 管理
2. 或使用默认的 `*.workers.dev` 域名

---

## 📝 下一步优化

### 可选：添加访问统计

在 Worker 代码中添加：
```javascript
// 记录下载次数到 KV 存储
await env.ANALYTICS.put('downloads', downloadCount)
```

### 可选：添加访问限制

```javascript
// 限制每个 IP 的请求频率
const rateLimit = 100 // 每小时100次
```

### 可选：添加 Webhook 通知

```javascript
// 下载量达到阈值时发送通知
if (downloadCount > 1000) {
  await fetch('https://your-webhook-url', {
    method: 'POST',
    body: JSON.stringify({ downloads: downloadCount })
  })
}
```

---

## 🎉 总结

完成以上步骤后，你就拥有了：

✅ **一个完全免费的 GitHub Release 加速服务**
✅ **自动跟随 GitHub 更新，无需维护**
✅ **全球 CDN 加速，国内访问速度提升明显**
✅ **每天 10 万次请求的免费额度**

你的应用会自动选择最快的下载源，用户体验将显著提升！
