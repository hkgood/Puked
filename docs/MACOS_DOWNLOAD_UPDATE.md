# macOS 下载功能更新说明

## 更新内容

为 Puked Web 首页的 **macOS 版本（Puked CallBack）** 下载按钮添加了多源下载选择功能。

## 功能特性

### 1. 下载源列表（按优先级排序）

1. **百度云盘下载** 
   - 链接：https://pan.baidu.com/s/5rHGMfeFevrg5MA3UerZ0dQ?
   - 标签：国内推荐

2. **夸克云盘下载**
   - 链接：https://pan.quark.cn/s/b350393205a0
   - 标签：国内推荐

3. **天翼云盘下载**
   - 链接：https://cloud.189.cn/web/share?code=NJrEfyRzMrmy
   - 访问码：m6z3
   - 标签：国内推荐

4. **Github 下载**
   - 链接：https://github.com/hkgood/Puked-Callback/releases
   - 标签：官方源

5. **本地下载**
   - 链接：https://download.osglab.com/PukedAPK/Puked_Callback_{version}.dmg
   - 标签：镜像源

### 2. 交互设计

- 点击 macOS 下载按钮后弹出精美的模态对话框
- 5 个下载源以卡片形式展示
- 每个卡片包含：
  - 图标（云盘/Github/下载）
  - 下载源名称
  - 标签（推荐/官方/镜像）
  - 访问码（仅天翼云盘）
  - 右箭头图标
- Hover 时卡片边框变蓝色，图标变色，箭头右移
- 支持键盘 ESC 关闭
- 点击遮罩层关闭

### 3. 视觉风格

- 完美融入 Puked Web 现有设计语言
- 黑色主题 `#1D1D1F` + 蓝色强调 `#007AFF`
- 圆角设计（卡片 `rounded-2xl`，弹窗 `rounded-3xl`）
- 流畅的动画效果
  - 遮罩层淡入 + 背景模糊
  - 弹窗缩放淡入动画
  - Hover 状态过渡动画

### 4. 国际化支持

中英文双语支持，新增翻译键：

**中文：**
- `download_macos_title`: 选择下载源
- `download_macos_subtitle`: 请选择最快的下载渠道

**英文：**
- `download_macos_title`: Choose Download Source
- `download_macos_subtitle`: Select the fastest download channel

（其他翻译键与 Android 版共用）

## 技术实现

### 文件变更

1. **新增组件**
   - `src/common/components/MacOSDownloadModal.tsx`
     - macOS 下载模态对话框组件
     - 接受参数：`isOpen`, `onClose`, `version`, `directDownloadUrl`

2. **修改文件**
   - `src/common/utils/i18n.tsx`
     - 添加 2 个新的国际化键值对（中英文）
   
   - `src/features/home/components/HomePage.tsx`
     - 导入 `MacOSDownloadModal` 组件
     - 添加 `isMacDownloadModalOpen` 状态
     - 将 `<a>` 标签改为 `<button>` 触发弹窗
     - 在页面底部渲染 `MacOSDownloadModal`

### 技术栈

- React 19.2.0
- TypeScript
- Tailwind CSS 4.1.18
- Lucide React (图标库)

### 响应式设计

- 移动端优化（padding、间距调整）
- 平板和桌面端完美展示
- 弹窗在小屏幕上自动适配

## 测试建议

### 功能测试
1. ✅ 点击 "macOS v1.0.4" 按钮是否弹出对话框
2. ✅ 5 个下载源链接是否正确跳转
3. ✅ 点击遮罩层是否关闭对话框
4. ✅ 点击 X 按钮是否关闭对话框
5. ✅ 版本号是否正确显示

### 样式测试
1. ✅ Hover 效果是否流畅
2. ✅ 动画是否自然
3. ✅ 移动端布局是否正常
4. ✅ 深色/浅色主题兼容性

### 国际化测试
1. ✅ 切换中英文是否正确显示
2. ✅ 所有文案是否翻译完整

### 浏览器兼容性
1. ✅ Chrome/Edge
2. ✅ Safari
3. ✅ Firefox
4. ✅ 移动端浏览器

## 部署说明

1. 确保所有依赖已安装：
```bash
cd Puked_web
npm install
```

2. 开发环境测试：
```bash
npm run dev
```
访问：http://localhost:5173

3. 生产构建：
```bash
npm run build
```

4. Docker 部署（如需）：
```bash
./deploy_docker.sh
```

## 维护指南

### 如何更新下载链接

修改文件：`src/common/components/MacOSDownloadModal.tsx`

找到 `downloadSources` 数组，修改对应的 `url` 字段：

```typescript
const downloadSources = [
  {
    name: t('download_baidu_cloud'),
    url: 'https://pan.baidu.com/s/新的分享码',  // 👈 在这里修改
    icon: Cloud,
    tag: t('download_recommended_domestic'),
    tagColor: 'bg-blue-500',
  },
  // ... 其他下载源
];
```

### 如何添加新的下载源

在 `downloadSources` 数组中添加新对象：

```typescript
{
  name: t('download_新源名称'),  // 需要先在 i18n.tsx 中添加翻译
  url: 'https://新的下载链接',
  icon: Download,  // 可选：Cloud, Github, Download
  subtitle: '可选的副标题',  // 可选
  tag: t('download_标签'),
  tagColor: 'bg-purple-500',  // Tailwind 颜色类
}
```

### 如何修改弹窗样式

修改 `MacOSDownloadModal.tsx` 中的 Tailwind 类名：

- 弹窗大小：`max-w-md` → `max-w-lg`
- 圆角：`rounded-3xl` → `rounded-2xl`
- 颜色：`bg-[#007AFF]` → `bg-purple-500`

## 代码质量

- ✅ TypeScript 类型安全
- ✅ ESLint 通过（无新增错误）
- ✅ 组件可复用
- ✅ 注释清晰
- ✅ 遵循项目代码规范

## 效果预览

弹窗包含以下元素结构：

```
┌─────────────────────────────────────┐
│  选择下载源              [X]         │
│  请选择最快的下载渠道 · v1.0.4      │
├─────────────────────────────────────┤
│  ☁️  百度云盘下载     [国内推荐] →  │
│  ☁️  夸克云盘下载     [国内推荐] →  │
│  ☁️  天翼云盘下载     [国内推荐] →  │
│      访问码：m6z3                    │
│  📦  Github 下载      [官方源]   →  │
│  ⬇️  本地下载         [镜像源]   →  │
└─────────────────────────────────────┘
```

## 注意事项

1. **网盘链接有效期**：请定期检查百度云盘、夸克云盘、天翼云盘的分享链接是否失效
2. **版本号同步**：确保 Github API 能正常获取最新版本号
3. **CDN 缓存**：如果使用 CDN，更新后需清除缓存
4. **访问码管理**：天翼云盘的访问码 `m6z3` 如有变更，需同步更新

## 与 Android 版本的差异

1. **组件名称**：
   - Android: `AndroidDownloadModal`
   - macOS: `MacOSDownloadModal`

2. **Github 仓库**：
   - Android: `hkgood/Puked`
   - macOS: `hkgood/Puked-Callback`

3. **文件扩展名**：
   - Android: `.apk`
   - macOS: `.dmg`

4. **版本号格式**：
   - Android: `2.4.0`（无 v 前缀）
   - macOS: `v1.0.4`（保留 v 前缀）

## 后续优化建议

1. **智能推荐**：根据用户 IP 地理位置自动推荐最快的下载源
2. **下载统计**：记录各下载源的点击次数
3. **下载速度测试**：实时测试各源的可达性和速度
4. **二维码生成**：为移动用户生成下载二维码
5. **历史版本**：支持下载旧版本 DMG

## 完整功能清单

现在 Puked Web 首页拥有：

- ✅ Android App 多源下载（5个源）
- ✅ macOS App 多源下载（5个源）
- ✅ iOS TestFlight 直接下载
- ✅ 统一的视觉设计语言
- ✅ 完整的国际化支持
- ✅ 响应式布局

---

**开发日期：** 2026-01-19  
**开发者：** Cursor AI Assistant  
**版本：** v1.0.0
