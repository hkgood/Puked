# 🎉 Puked Web 镜像推送成功

## 📦 镜像信息

### Docker Hub 仓库
- **仓库地址**: https://hub.docker.com/r/rocky8848/puked-web
- **用户名**: rocky8848
- **仓库名**: puked-web

### 已推送的镜像标签
- ✅ `rocky8848/puked-web:2.4.6`
- ✅ `rocky8848/puked-web:latest`

### 镜像详情
- **Digest**: `sha256:7d5c2722b4a9b444bba642e78326f18c1e52d1abd4ec977374c7e0257112683b`
- **大小**: 190 MB
- **架构**: linux/amd64 (当前平台)
- **基础镜像**: 
  - Node.js: `node:20-alpine`
  - Nginx: `nginx:stable-alpine`

## 🔧 镜像包含的组件

1. **前端应用** (Puked Web)
   - React 19.2.0 + TypeScript
   - Vite 6.4.1 构建
   - TailwindCSS 4.1.18
   - 位置: `/usr/share/nginx/html`

2. **Nginx Web 服务器**
   - 版本: stable-alpine
   - 端口: 80
   - 配置: `/etc/nginx/conf.d/default.conf`

3. **任务处理器** (Task Processor)
   - Node.js 后台服务
   - 自动处理数据归纳任务
   - 位置: `/app/processor`

4. **Supervisor 进程管理器**
   - 管理 Nginx 和任务处理器
   - 自动重启失败进程
   - 日志管理

## 🚀 使用方法

### 基础使用

```bash
docker pull rocky8848/puked-web:2.4.6
```

### 运行容器

```bash
docker run -d \
  --name puked-web \
  -p 3001:80 \
  -e PB_URL=https://pb.osglab.com \
  -e ADMIN_EMAIL=rocky.hk@gmail.com \
  -e ADMIN_PASSWORD=your_password \
  -e CHECK_INTERVAL=10000 \
  -e BATCH_SIZE=10 \
  -e CONCURRENCY=3 \
  --restart unless-stopped \
  rocky8848/puked-web:2.4.6
```

### 环境变量说明

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `PB_URL` | PocketBase 服务地址 | `https://pb.osglab.com` |
| `ADMIN_EMAIL` | 管理员邮箱 | `rocky.hk@gmail.com` |
| `ADMIN_PASSWORD` | 管理员密码 | `gz203799` |
| `CHECK_INTERVAL` | 任务检查间隔（毫秒） | `10000` |
| `BATCH_SIZE` | 每批处理行程数 | `10` |
| `CONCURRENCY` | 并发处理数 | `3` |

## 📊 验证部署

### 检查容器状态

```bash
docker ps | grep puked-web
```

### 检查进程状态

```bash
docker exec puked-web supervisorctl status
```

**预期输出：**
```
nginx                            RUNNING   pid 7, uptime 0:05:23
task-processor                   RUNNING   pid 8, uptime 0:05:23
```

### 查看任务处理器日志

```bash
docker exec puked-web cat /var/log/supervisor/task_processor.log | tail -n 20
```

**预期输出：**
```
🚀 [TaskProcessor] 引擎正在启动...
✅ [TaskProcessor] 超级用户 (Superuser) 登录成功
🔄 [TaskProcessor] 开始监听任务队列 (每 10 秒检查一次)
✨ [TaskProcessor] 运行中...
```

### 测试前端访问

```bash
curl http://localhost:3001
```

## 🌐 生产环境部署

### 步骤 1: 在服务器上拉取镜像

```bash
docker pull rocky8848/puked-web:2.4.6
```

### 步骤 2: 停止旧容器（如果有）

```bash
docker stop puked-web
docker rm puked-web
```

### 步骤 3: 启动新容器

```bash
docker run -d \
  --name puked-web \
  -p 3001:80 \
  -e PB_URL=https://pb.osglab.com \
  -e ADMIN_EMAIL=rocky.hk@gmail.com \
  -e ADMIN_PASSWORD=your_secure_password \
  --restart unless-stopped \
  rocky8848/puked-web:2.4.6
```

### 步骤 4: 验证部署

```bash
# 检查容器状态
docker ps | grep puked-web

# 检查进程
docker exec puked-web supervisorctl status

# 查看日志
docker logs puked-web
```

## 🔧 管理命令

### 重启容器

```bash
docker restart puked-web
```

### 重启任务处理器（不重启容器）

```bash
docker exec puked-web supervisorctl restart task-processor
```

### 查看实时日志

```bash
# 所有日志
docker logs -f puked-web

# 只看任务处理器
docker exec puked-web tail -f /var/log/supervisor/task_processor.log

# 只看错误日志
docker exec puked-web tail -f /var/log/supervisor/task_processor_error.log
```

### 进入容器

```bash
docker exec -it puked-web /bin/sh
```

## 🆕 更新记录

### v2.4.6 (2026-02-01)

**主要改进：**
1. ✅ 修复任务处理器在 Docker 中不启动的问题
2. ✅ 优化 Supervisor 配置，使用独立配置文件
3. ✅ 改进环境变量传递机制
4. ✅ 增强日志管理（自动滚动，50MB × 10 备份）
5. ✅ 添加进程优雅关闭机制
6. ✅ 完善健康检查

**技术改进：**
- 使用独立的 `supervisord.conf` 配置文件
- 移除 Supervisor 环境变量扩展语法
- 改进多阶段构建流程
- 优化镜像层缓存

## 🐛 故障排查

### 问题：任务处理器未运行

**检查：**
```bash
docker exec puked-web ps aux | grep task_processor
```

**修复：**
```bash
docker exec puked-web supervisorctl restart task-processor
```

### 问题：环境变量未生效

**检查：**
```bash
docker exec puked-web printenv | grep -E "PB_URL|ADMIN"
```

**修复：**
重新创建容器并确保传递所有环境变量。

### 问题：PocketBase 认证失败

**症状：** 任务处理器日志显示认证错误

**检查：**
```bash
docker exec puked-web cat /var/log/supervisor/task_processor_error.log
```

**修复：**
1. 确认 `PB_URL` 可访问
2. 确认 `ADMIN_EMAIL` 和 `ADMIN_PASSWORD` 正确
3. 检查 PocketBase 服务状态

## 📚 相关资源

- **源代码**: `/Users/rocky/Documents/PukedMaster/Puked_web`
- **Dockerfile**: `Dockerfile.allinone.v2`
- **Supervisor 配置**: `supervisord.conf`
- **任务处理器**: `scripts/task_processor.pb.js`
- **修复指南**: `TASK_PROCESSOR_FIX_GUIDE.md`

## 🎯 下一步

1. ✅ 镜像已推送到 Docker Hub
2. 📋 在生产服务器上部署测试
3. 📊 监控任务处理器运行状态
4. 🔄 如需更新，重复构建和推送流程

---

**推送时间**: 2026-02-01  
**版本**: 2.4.6  
**镜像大小**: 190 MB  
**状态**: ✅ 已验证可用
