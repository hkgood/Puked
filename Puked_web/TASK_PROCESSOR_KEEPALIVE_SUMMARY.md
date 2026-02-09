# 任务处理器保活问题修复总结

## 🔍 问题现象

从 Docker 日志可以看到：
```
2026-02-01 10:51:06 INFO success: task-processor entered RUNNING state
(之后无任何日志输出，进程静默退出)
```

用户反馈：关闭页面两天后，后台程序似乎停止运行。

## 📋 根本原因

通过代码审查，发现以下关键问题：

### 1. **缺少全局异常捕获**
```javascript
// ❌ 原代码
init();  // 如果 init() 内部抛出异步异常，进程会退出

// ❌ 原代码
setInterval(checkAndProcessTasks, CHECK_INTERVAL);  
// 如果 checkAndProcessTasks 抛出异常，定时器会停止
```

Node.js 15+ 版本中，未捕获的 `Promise rejection` 会导致进程直接退出。

### 2. **认证 Token 可能过期**
- 长时间运行后，PocketBase 的 auth token 会失效
- 没有监听 `authStore.onChange` 事件
- 没有自动重新认证机制

### 3. **单点失败导致全局崩溃**
- 任务队列检查失败会中断整个循环
- 单个任务失败会影响后续任务
- 网络波动可能导致进程退出

## ✅ 修复方案

### 修复 1: 全局异常保护

添加了四层异常保护：

```javascript
// 1. 未处理的 Promise rejection
process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ [TaskProcessor] 未处理的 Promise 异常:', reason);
  // 不退出进程，记录日志后继续运行
});

// 2. 未捕获的异常
process.on('uncaughtException', (error) => {
  console.error('❌ [TaskProcessor] 未捕获的异常:', error);
  // 不退出进程
});

// 3. init() 启动异常
init().catch(err => {
  console.error('❌ [TaskProcessor] 初始化失败:', err);
  process.exit(1);  // 启动失败才退出
});

// 4. 定时器内异常
setInterval(() => {
  checkAndProcessTasks().catch(err => {
    console.error('[TaskProcessor] ❌ 任务检查循环出错:', err.message);
    console.error('[TaskProcessor] 🔄 将在下个周期继续尝试...');
  });
}, CHECK_INTERVAL);
```

### 修复 2: 认证保活机制

```javascript
// 监听认证状态变化
pb.authStore.onChange(() => {
  if (!pb.authStore.isValid) {
    console.warn('[TaskProcessor] ⚠️ 认证失效，尝试重新登录...');
    reAuthenticate().catch(err => {
      console.error('[TaskProcessor] ❌ 重新认证失败:', err.message);
    });
  }
});

// 每次任务检查前验证认证状态
if (!pb.authStore.isValid) {
  await reAuthenticate();
}

// 重新认证函数
async function reAuthenticate() {
  try {
    await pb.collection('_superusers').authWithPassword(ADMIN_EMAIL, ADMIN_PASSWORD);
    console.log('✅ [TaskProcessor] 重新认证成功');
  } catch (e) {
    await pb.admins.authWithPassword(ADMIN_EMAIL, ADMIN_PASSWORD);
    console.log('✅ [TaskProcessor] 重新认证成功 (Admin)');
  }
}
```

### 修复 3: 任务独立处理

```javascript
// 单个任务失败不影响其他任务
for (const task of pendingTasks) {
  try {
    await dispatchTask(task);
  } catch (err) {
    console.error(`[TaskProcessor] ❌ 处理任务 ${task.id} 时出错:`, err.message);
    // 继续处理下一个任务，不中断循环
  }
}
```

### 修复 4: Supervisor 自动重启

更新 `supervisord.conf`：

```ini
[program:task-processor]
startretries=10        ; 允许重启 10 次
startsecs=5            ; 启动后至少运行 5 秒才算成功
stopwaitsecs=30        ; 关闭前等待 30 秒
killasgroup=true       ; 杀死进程组
stopasgroup=true       ; 停止进程组
```

### 修复 5: 增强日志输出

添加了更多诊断信息：

```javascript
console.log('==========================================');
console.log('🚀 [TaskProcessor] 引擎正在启动...');
console.log(`📍 [TaskProcessor] 目标地址: ${PB_URL}`);
console.log(`📋 [TaskProcessor] 检查间隔: ${CHECK_INTERVAL / 1000}秒`);
console.log(`📦 [TaskProcessor] 批次大小: ${BATCH_SIZE}`);
console.log('==========================================');
// ...
console.log('✨ [TaskProcessor] 运行中...');
console.log('💡 [TaskProcessor] 进程保持运行，等待任务队列...');
```

## 🛠️ 新增工具

### 1. 健康检查脚本

**文件**: `scripts/check_processor_health.js`

功能：
- ✅ 检查心跳是否正常（最后心跳时间、距今时长）
- ✅ 检查任务队列状态（待处理任务数量、最早任务等待时间）
- ✅ 检查最近任务执行情况（成功/失败统计）
- ✅ 综合健康评分（0-100 分）

使用方法：
```bash
# 本地测试
node scripts/check_processor_health.js

# Docker 容器内
docker exec puked-web node /app/processor/check_processor_health.js
```

### 2. 快速部署脚本

**文件**: `deploy_keepalive_fix.sh`

功能：
- ✅ 构建 Docker 镜像（支持多架构）
- ✅ 推送到 Docker Hub
- ✅ 本地测试容器
- ✅ 生产环境部署
- ✅ 健康检查验证

使用方法：
```bash
cd Puked_web
./deploy_keepalive_fix.sh
```

## 📁 修改的文件

```
Puked_web/
├── scripts/
│   ├── task_processor.pb.js           ✏️ 主要修改
│   ├── check_processor_health.js      ✨ 新增
├── supervisord.conf                    ✏️ 更新配置
├── deploy_keepalive_fix.sh            ✨ 新增
├── TASK_PROCESSOR_KEEPALIVE_FIX.md    ✨ 新增
└── TASK_PROCESSOR_KEEPALIVE_SUMMARY.md ✨ 新增 (本文件)
```

## 🚀 部署步骤

### 方式 1: 使用自动化脚本（推荐）

```bash
cd Puked_web
./deploy_keepalive_fix.sh
```

### 方式 2: 手动部署

#### Step 1: 本地测试

```bash
cd Puked_web
node scripts/task_processor.pb.js
```

确保看到启动日志和"运行中..."提示。

#### Step 2: 健康检查

```bash
node scripts/check_processor_health.js
```

应该看到健康评分 100/100。

#### Step 3: 构建 Docker 镜像

```bash
# 单架构（本地架构）
docker build -f Dockerfile.allinone.v2 -t rocky8848/puked-web:2.4.7 .

# 或者多架构（推荐）
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f Dockerfile.allinone.v2 \
  -t rocky8848/puked-web:2.4.7 \
  --push \
  .
```

#### Step 4: 本地测试容器

```bash
docker run -d --name puked-web-test -p 8080:80 rocky8848/puked-web:2.4.7

# 检查状态
docker exec puked-web-test supervisorctl status

# 查看日志
docker logs -f puked-web-test
docker exec puked-web-test tail -f /var/log/supervisor/task_processor.log

# 健康检查
docker exec puked-web-test node /app/processor/check_processor_health.js
```

#### Step 5: 生产部署

```bash
# 拉取镜像
docker pull rocky8848/puked-web:2.4.7

# 停止旧容器
docker stop puked-web
docker rm puked-web

# 启动新容器
docker run -d \
  --name puked-web \
  --restart unless-stopped \
  -p 80:80 \
  rocky8848/puked-web:2.4.7

# 验证
docker logs -f puked-web
docker exec puked-web supervisorctl status
docker exec puked-web node /app/processor/check_processor_health.js
```

## 🧪 验证清单

### ✅ 启动验证

```bash
docker logs puked-web | grep TaskProcessor
```

应该看到：
```
🚀 [TaskProcessor] 引擎正在启动...
📍 [TaskProcessor] 目标地址: https://pb.osglab.com
✅ [TaskProcessor] 超级用户 (Superuser) 登录成功
🔄 [TaskProcessor] 开始监听任务队列 (每 10 秒检查一次)
✨ [TaskProcessor] 运行中...
💡 [TaskProcessor] 进程保持运行，等待任务队列...
```

### ✅ 进程验证

```bash
docker exec puked-web supervisorctl status
```

应该看到：
```
nginx                            RUNNING   pid 7, uptime 0:05:23
task-processor                   RUNNING   pid 8, uptime 0:05:23
```

### ✅ 健康检查

```bash
docker exec puked-web node /app/processor/check_processor_health.js
```

应该看到：
```
💓 心跳检查:
   最后心跳时间: 2026-02-03 10:51:30
   距今: 15 秒
   引擎状态: online
   ✅ 心跳正常

📋 任务队列状态:
   待处理任务: 0 个
   ✅ 当前无待处理任务

🏥 健康评分: 100/100
✅ 一切正常！
```

### ✅ 任务执行验证

1. 在前端触发"触发数据归纳"
2. 观察日志：

```bash
docker exec puked-web tail -f /var/log/supervisor/task_processor.log
```

应该看到：
```
[TaskProcessor] 📋 发现 1 个待处理任务
[TaskProcessor] 🚀 开始处理任务: xxx
[TaskProcessor] 📦 处理 100 个新行程...
[TaskProcessor] 🔄 处理批次 1/10 (10 个行程)...
[TaskProcessor] ✅ 所有批次处理完成
[TaskProcessor] 📊 开始更新用户统计...
[TaskProcessor] ✨ 任务完成: xxx (100 trips, 45s)
```

### ✅ 长期稳定性验证

运行 24 小时后，再次检查：

```bash
# 检查容器运行时间
docker ps | grep puked-web

# 检查进程运行时间
docker exec puked-web supervisorctl status

# 检查健康状态
docker exec puked-web node /app/processor/check_processor_health.js
```

## 🎯 关键改进总结

| 问题 | 原因 | 修复方案 |
|------|------|----------|
| 进程静默退出 | 未捕获的 Promise rejection | 添加 `unhandledRejection` 监听器 |
| 定时器失效 | 异步函数异常导致定时器停止 | 每次执行包裹 `.catch()` |
| 认证失效 | 长时间运行后 token 过期 | 添加 `authStore.onChange` 监听和重新认证 |
| 单点失败 | 一个任务失败影响全局 | 独立处理每个任务，捕获异常 |
| 缺少监控 | 无法诊断问题 | 添加健康检查脚本和详细日志 |

## 📊 预期效果

修复后，任务处理器应该：

✅ **启动时**：输出详细日志，成功登录，开始轮询  
✅ **运行中**：每 10 秒检查任务，每 1 分钟更新心跳  
✅ **遇到错误**：记录日志但不退出，自动重试  
✅ **进程崩溃**：Supervisor 自动重启  
✅ **长期运行**：7x24 小时稳定运行，不退出  

## ⚠️ 注意事项

1. **环境变量**：当前密码硬编码在 `supervisord.conf` 中，建议生产环境使用 Docker Secrets
2. **uncaughtException**：添加了全局异常捕获，但仍需修复代码中的异常来源
3. **日志轮转**：已配置日志轮转（50MB x 10 份），但需定期清理旧日志
4. **监控告警**：建议添加外部监控系统（如 Prometheus + Grafana）

## 📚 相关文档

- 详细修复指南：`TASK_PROCESSOR_KEEPALIVE_FIX.md`
- 健康检查脚本：`scripts/check_processor_health.js`
- 部署脚本：`deploy_keepalive_fix.sh`
- 原始问题文档：`TASK_PROCESSOR_FIX_GUIDE.md`

## 🤝 支持

如果遇到问题，请检查：

1. Docker 容器日志：`docker logs -f puked-web`
2. 任务处理器日志：`docker exec puked-web cat /var/log/supervisor/task_processor.log`
3. 错误日志：`docker exec puked-web cat /var/log/supervisor/task_processor_error.log`
4. 运行健康检查：`docker exec puked-web node /app/processor/check_processor_health.js`

---

**修复版本**: 2.4.7  
**修复日期**: 2026-02-03  
**修复人员**: AI Assistant  
**状态**: ✅ 已完成，待部署测试
