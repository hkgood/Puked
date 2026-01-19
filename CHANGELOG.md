# Changelog

All notable changes to this project will be documented in this file.

## [2.4.1] - 2026-01-19
### Web App
- 首页下载新增多个国内网盘镜像
- 新增管理员审批时可以修改 ADAS 品牌和软件版本，提升格式化
- 用户管理提升加载速度

### iOS & Android App
- 语音标记功能开放给所有认证用户
- 优化自动更新逻辑

## [2.4.0] - 2026-01-19
### Web App
- 全新升级为官方网站，所有软件皆可从 Puked.osglab.com 中下载

### Puked Callback
- 发布 Puked Callback，可以回放行程json文件，并生成透明背景视频以方便视频编辑

### iOS & Android App
1. 新增专家用户，并支持语音标记更多事件种类
2. 新增语音标记：开始标记前点击首页右上角“语音 ON”完成模型下载；行程中支持点击屏幕或使用蓝牙耳机播放/暂停键触发语音记录（专家用户目前为邀请制）
3. 设置：新增高帧率数据记录模式（专家用户）
4. 设置：新增语音打标说明（专家用户）
5. 设置：新增销毁账户功能，支持删除所有个人账号数据
6. 设置：安卓下载镜像更新，支持通过官方镜像下载 Apk
7. 设置：我的数据图表尺寸增大，方便查看

## [2.3.4] - 2026-01-14
### Fixed
- **Android 编译兼容性升级**：解决了 AGP 8.x 环境下 Isar 等老旧插件 `AndroidManifest.xml` 中 `package` 属性导致的编译失败问题。
- **自动化补丁增强**：优化了 Manifest 自动修复脚本，支持对所有依赖插件进行命名空间 (Namespace) 的注入与校验。
... (rest of the file)
