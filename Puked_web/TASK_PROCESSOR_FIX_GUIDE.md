# 🔧 Puked 任务处理器修复方案

## 📋 问题现象

前端触发"数据归纳"任务后，任务一直停留在 `pending` 状态，显示：
```
任务已加入队列，正在等待后台处理...
进度 0%
处理行程: 0/0 | 批次进度: 0/0
```

## 🔍 问题根源

任务处理器 (`task_processor.pb.js`) 未能在 Docker 容器中正常启动，可能原因：

1. **Supervisor 环境变量传递问题** - 环境变量未正确传递给 Node.js 进程
2. **认证失败** - PocketBase 认证凭据不正确
3. **进程启动失败** - Supervisor 配置错误导致进程无法启动

## ✅ 解决方案

### 方案 1：使用诊断脚本（推荐）

快速诊断当前部署状态：

```bash
cd /Users/rocky/Documents/PukedMaster
bash Puked_web/diagnose_task_processor.sh
```

**诊断脚本会检查：**
- ✅ 容器运行状态
- ✅ 进程列表（检查 task_processor.pb.js）
- ✅ 环境变量配置
- ✅ 任务处理器日志
- ✅ PocketBase 连接状态

### 方案 2：快速修复（一键重新部署）

如果诊断发现问题，使用修复脚本：

```bash
cd /Users/rocky/Documents/PukedMaster
bash Puked_web/fix_task_processor.sh
```

**修复脚本会执行：**
1. 停止并删除旧容器
2. 删除旧镜像
3. 使用改进版 Dockerfile 重新构建
4. 启动新容器并验证

### 方案 3：手动修复

#### Step 1: 检查当前容器状态

```bash
# 查看容器列表
docker ps -a | grep puked

# 查看容器日志
docker logs puked-web 2>&1 | grep -i "task\|processor\|engine"

# 查看 Supervisor 状态
docker exec puked-web supervisorctl status
```

#### Step 2: 查看任务处理器日志

```bash
# 标准输出日志
docker exec puked-web cat /var/log/supervisor/task_processor.log

# 错误日志
docker exec puked-web cat /var/log/supervisor/task_processor_error.log
```

#### Step 3: 手动重启任务处理器

```bash
# 重启任务处理器进程
docker exec puked-web supervisorctl restart task-processor

# 查看重启后的状态
docker exec puked-web supervisorctl status task-processor
```

#### Step 4: 如果需要重新构建

```bash
cd /Users/rocky/Documents/PukedMaster/Puked_web

# 停止并删除旧容器
docker stop puked-web
docker rm puked-web

# 使用新版 Dockerfile 构建
docker build -f Dockerfile.allinone.v2 -t puked-web:2.4.6 .

# 启动新容器
docker run -d \
  --name puked-web \
  -p 3001:80 \
  -e PB_URL=https://pb.osglab.com \
  -e ADMIN_EMAIL=rocky.hk@gmail.com \
  -e ADMIN_PASSWORD=gz203799 \
  -e CHECK_INTERVAL=10000 \
  -e BATCH_SIZE=10 \
  -e CONCURRENCY=3 \
  --restart unless-stopped \
  puked-web:2.4.6

# 等待10秒后检查状态
sleep 10
docker exec puked-web supervisorctl status
```

## 🆕 改进内容

### 1. 独立的 Supervisor 配置文件

**旧版问题：** `Dockerfile.allinone` 使用多行 `echo` 构建配置，容易出现语法错误

**新版改进：** `Dockerfile.allinone.v2` + `supervisord.conf`
- 使用独立的配置文件，更易维护
- 增强日志管理（日志滚动、大小限制）
- 改进进程停止机制（killasgroup, stopasgroup）

### 2. 环境变量传递优化

```ini
[program:task-processor]
environment=NODE_ENV="production",PB_URL="%(ENV_PB_URL)s",ADMIN_EMAIL="%(ENV_ADMIN_EMAIL)s",ADMIN_PASSWORD="%(ENV_ADMIN_PASSWORD)s",...
```

确保所有环境变量正确传递给 Node.js 进程。

### 3. 增强的日志记录

```ini
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=10
stderr_logfile_maxbytes=50MB
stderr_logfile_backups=10
```

防止日志文件过大占满磁盘空间。

## 🔄 部署更新流程

### 本地测试部署

```bash
# 1. 构建镜像
bash Puked_web/build_and_deploy.sh

# 2. 验证任务处理器
bash Puked_web/diagnose_task_processor.sh

# 3. 查看实时日志
docker logs -f puked-web
```

### 推送到 Docker Hub

```bash
# 更新版本号
vi Puked_web/push-to-dockerhub.sh  # 修改 VERSION="2.4.6"

# 构建并推送
bash Puked_web/push-to-dockerhub.sh
```

### 生产环境部署

```bash
# 拉取最新镜像
docker pull rocky8848/puked-web:2.4.6

# 停止旧容器
docker stop puked-web
docker rm puked-web

# 启动新容器
docker run -d \
  --name puked-web \
  -p 3001:80 \
  -e PB_URL=https://pb.osglab.com \
  -e ADMIN_EMAIL=rocky.hk@gmail.com \
  -e ADMIN_PASSWORD=your_password \
  -e CHECK_INTERVAL=10000 \
  --restart unless-stopped \
  rocky8848/puked-web:2.4.6

# 验证部署
docker exec puked-web supervisorctl status
docker logs -f puked-web
```

## 🐛 常见问题排查

### Q1: 任务处理器启动后立即退出

**原因：** PocketBase 认证失败

**解决：**
```bash
# 检查环境变量
docker exec puked-web printenv | grep -E "PB_URL|ADMIN_EMAIL|ADMIN_PASSWORD"

# 手动测试认证
docker exec -it puked-web /bin/sh
cd /app/processor
node -e "import('pocketbase').then(m => {const pb = new m.default('https://pb.osglab.com'); pb.collection('_superusers').authWithPassword('rocky.hk@gmail.com', 'gz203799').then(() => console.log('OK')).catch(e => console.error(e))})"
```

### Q2: Supervisor 显示 FATAL 状态

**原因：** Node.js 脚本语法错误或依赖缺失

**解决：**
```bash
# 查看错误日志
docker exec puked-web cat /var/log/supervisor/task_processor_error.log

# 手动运行脚本查看详细错误
docker exec -it puked-web /bin/sh
cd /app/processor
node task_processor.pb.js
```

### Q3: 环境变量未生效

**原因：** Supervisor 环境变量语法错误

**解决：** 使用新版 `Dockerfile.allinone.v2` + `supervisord.conf`

### Q4: 日志文件过大

**新版已修复：** 日志自动滚动，最多保留 50MB × 10 个备份

## 📊 监控与维护

### 实时监控

```bash
# 查看实时日志
docker logs -f puked-web

# 查看任务处理器心跳
docker exec puked-web tail -f /var/log/supervisor/task_processor.log | grep "心跳\|heartbeat"

# 查看 Supervisor 状态
watch -n 5 'docker exec puked-web supervisorctl status'
```

### 日常维护

```bash
# 每周清理旧日志
docker exec puked-web find /var/log/supervisor -name "*.log.*" -mtime +7 -delete

# 检查容器健康
docker inspect puked-web --format='{{.State.Health.Status}}'

# 查看容器资源使用
docker stats puked-web --no-stream
```

## 📦 文件清单

### 核心文件
- `Puked_web/Dockerfile.allinone` - 原版一体化 Dockerfile
- `Puked_web/Dockerfile.allinone.v2` - 改进版 Dockerfile（推荐）
- `Puked_web/supervisord.conf` - Supervisor 配置文件（新增）
- `Puked_web/scripts/task_processor.pb.js` - 任务处理器主程序

### 脚本工具
- `Puked_web/diagnose_task_processor.sh` - 诊断脚本（新增）
- `Puked_web/fix_task_processor.sh` - 快速修复脚本（新增）
- `Puked_web/build_and_deploy.sh` - 构建部署脚本
- `Puked_web/push-to-dockerhub.sh` - 推送到 Docker Hub

### Docker Compose 配置
- `docker-compose.yml` - PocketBase + 任务处理器（独立容器）
- `docker-compose.full.yml` - 前端 + 任务处理器（独立容器）

## ✅ 验证清单

部署完成后，逐项验证：

- [ ] 容器运行状态正常 (`docker ps`)
- [ ] Nginx 进程正常 (`supervisorctl status nginx`)
- [ ] 任务处理器进程正常 (`supervisorctl status task-processor`)
- [ ] 任务处理器日志有 "运行中..." 提示
- [ ] 前端可访问 (`http://localhost:3001`)
- [ ] 触发数据归纳任务，任务状态从 `pending` 变为 `running`
- [ ] 任务进度正常更新
- [ ] 任务完成后状态变为 `success`

## 🆘 紧急恢复

如果所有方案都失败，可以临时使用独立任务处理器：

```bash
# 使用 docker-compose.single.yml
cd /Users/rocky/Documents/PukedMaster
docker-compose -f docker-compose.single.yml up -d task-processor

# 查看日志
docker logs -f puked-task-processor
```

---

**作者：** Puked Team  
**版本：** 2.4.6  
**更新日期：** 2026-02-01
