# Puked Web v2.4.7 部署说明

## 📦 镜像信息

**版本号**: 2.4.7  
**Docker Hub 仓库**: rocky8848/puked-web-allinone  
**推送时间**: 2026-02-05

### 可用标签

- `rocky8848/puked-web-allinone:2.4.7`
- `rocky8848/puked-web-allinone:2.4.7-arm64`
- `rocky8848/puked-web-allinone:latest`

### 架构支持

**当前状态**: ✅ ARM64 (Apple Silicon)

**说明**: 由于网络环境限制，当前版本暂时只支持 ARM64 架构。AMD64 (x86_64) 版本构建时遇到跨平台编译的网络超时问题（buildkit 无法正确使用代理获取 Docker Hub 认证令牌）。

## 🚀 快速部署

### 拉取镜像

```bash
docker pull rocky8848/puked-web-allinone:2.4.7
```

### 运行容器

```bash
docker run -d \
  -p 8080:80 \
  --name puked-web \
  rocky8848/puked-web-allinone:2.4.7
```

### 查看日志

```bash
# 查看所有服务日志
docker exec puked-web supervisorctl status

# 查看任务处理器日志
docker exec puked-web tail -f /var/log/supervisor/task_processor.log

# 查看 Nginx 日志
docker exec puked-web tail -f /var/log/supervisor/nginx.log
```

## 📋 版本更新内容

### v2.4.7 (2026-02-05)

1. **任务处理器频率优化**
   - CHECK_INTERVAL: 从 10秒 增加到 **60秒** (1分钟)
   - HEARTBEAT_INTERVAL: 从 2分钟 增加到 **300秒** (5分钟)
   - 降低系统资源消耗，更适合生产环境

2. **环境变量配置**
   - `CHECK_INTERVAL`: 任务检查间隔（毫秒），默认 60000
   - `HEARTBEAT_INTERVAL`: 心跳更新间隔（毫秒），默认 300000
   - `BATCH_SIZE`: 批次大小，默认 10
   - `CONCURRENCY`: 并发数，默认 3

3. **包含组件**
   - ✅ 前端 Web 应用 (React + Vite)
   - ✅ 后台任务处理器 (Node.js)
   - ✅ Nginx 服务器
   - ✅ Supervisor 进程管理

## 🔍 验证部署

访问 `http://localhost:8080` 应该能看到 Puked Web 应用界面。

检查后台任务处理器是否正常运行：

```bash
docker exec puked-web supervisorctl status task-processor
```

应该看到 `task-processor RUNNING` 状态。

## ⚠️ 已知限制

1. **架构限制**: 当前版本只支持 ARM64 架构
   - 如需在 x86_64 服务器上部署，建议：
     - 选项 A: 在 x86_64 机器上本地构建镜像
     - 选项 B: 等待网络环境改善后重新构建多架构镜像
     - 选项 C: 使用 Docker 镜像加速器或私有 registry

2. **多架构构建问题**: 
   - Buildkit 在跨平台构建时无法正确使用 HTTP_PROXY 进行 Docker Hub 认证
   - 即使配置了代理环境变量，OAuth token 请求仍会超时
   - 这是一个已知的 buildkit 问题

## 🛠️ 故障排查

### 任务处理器未运行

```bash
# 重启任务处理器
docker exec puked-web supervisorctl restart task-processor

# 查看详细日志
docker exec puked-web tail -100 /var/log/supervisor/task_processor_error.log
```

### 检查健康状态

可以使用项目中的健康检查脚本：

```bash
docker exec puked-web node /app/processor/check_processor_health.js
```

## 📝 后续计划

1. 解决多架构构建的网络问题，支持 AMD64 (x86_64)
2. 考虑使用 GitHub Actions 或其他 CI/CD 平台进行自动构建
3. 探索使用国内镜像加速器作为 base image 源

## 📞 联系方式

如遇到问题，请查看：
- 任务处理器配置文档: `TASK_PROCESSOR_CONFIG.md`
- 健康检查脚本: `scripts/check_processor_health.js`
- Supervisor 配置: `supervisord.conf`
