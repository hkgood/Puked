# Web App 版本号显示更新

## 📅 更新时间
2026-02-05

## ✅ 已完成的修改

### 1. 添加版本号显示
在 Web App 的页面底部中央位置添加了版本号显示。

**文件：** `Puked_web/src/App.tsx`

**位置：** 页面底部中央，固定定位

**样式特点：**
- 小字体（10px）
- 灰色文本（text-gray-400）
- 水平居中
- 移动端在底部导航栏上方（mb-16）
- 桌面端在页面底部（md:mb-0）
- 不影响点击交互（pointer-events-none）

### 2. 版本号管理
当前版本号：**v2.4.4**

版本号定义在文件顶部常量：
```typescript
const APP_VERSION = '2.4.4';
```

**更新版本号方法：**
1. 更新 `package.json` 中的 `version` 字段
2. 更新 `App.tsx` 中的 `APP_VERSION` 常量

### 3. 显示位置
- ✅ 在所有页面显示（Home、Arena、Dashboard）
- ❌ 在 Delete Account 页面隐藏
- ✅ 移动端在底部导航栏上方
- ✅ 桌面端在页面底部

### 4. 响应式设计
```tsx
<div className="fixed bottom-2 left-1/2 -translate-x-1/2 md:bottom-4 text-[10px] text-gray-400 font-medium tracking-wide z-10 pointer-events-none mb-16 md:mb-0">
  v{APP_VERSION}
</div>
```

**样式说明：**
- `fixed bottom-2 md:bottom-4`: 移动端距底部 0.5rem，桌面端 1rem
- `left-1/2 -translate-x-1/2`: 水平居中
- `text-[10px]`: 小字体
- `text-gray-400`: 灰色文本
- `mb-16 md:mb-0`: 移动端下边距避开底部导航栏

## 🎯 效果预览

**移动端：**
```
┌─────────────────────┐
│                     │
│   主要内容区域      │
│                     │
│      v2.4.4         │ ← 版本号
├─────────────────────┤
│ Home  Arena  Dash   │ ← 底部导航栏
└─────────────────────┘
```

**桌面端：**
```
┌─────────────────────┐
│                     │
│   主要内容区域      │
│                     │
│      v2.4.4         │ ← 版本号
└─────────────────────┘
```

## 🔧 技术细节

### 条件渲染
```tsx
{view !== 'delete-account' && (
  <div>v{APP_VERSION}</div>
)}
```

只在非删除账户页面显示版本号。

### Z-index 层级
`z-10` 确保版本号在内容之上，但不会遮挡弹窗（弹窗 z-index 为 200）。

## 📝 附加优化

同时修复了一个未使用导入的问题：
- 移除了 `Languages` 图标的导入（未使用）

## 🚀 后续建议

如果需要自动化版本号更新，可以考虑：

1. **使用构建时注入：**
```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import pkg from './package.json';

export default defineConfig({
  define: {
    __APP_VERSION__: JSON.stringify(pkg.version)
  }
});

// App.tsx
declare const __APP_VERSION__: string;
const APP_VERSION = __APP_VERSION__;
```

2. **使用环境变量：**
```typescript
const APP_VERSION = import.meta.env.VITE_APP_VERSION || '2.4.4';
```

目前使用硬编码的方式是最简单直接的方案。

---

**最后更新：** 2026-02-05  
**维护者：** Rocky
