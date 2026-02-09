# 任务处理器保活机制修复指南

## 问题描述

从 Docker 日志可以看到，任务处理器进程启动成功后没有任何日志输出，说明进程可能遇到了**未捕获的异常而静默退出**。

Docker 日志显示：
```
2026-02-01 10:51:06 INFO success: task-processor entered RUNNING state
(之后无任何日志输出)
```

## 根本原因分析

### 1. **缺少全局错误捕获**
- Node.js 中未捕获的 `Promise rejection` 会导致进程退出（Node 15+）
- `init()` 函数中的异步错误没有被 `.catch()` 捕获
- `setInterval` 中的异步函数异常没有兜底处理

### 2. **认证 Token 可能过期**
- 长时间运行后，PocketBase 的 auth token 可能失效
- 没有监听 `authStore.onChange` 事件
- 没有重新认证机制

### 3. **定时器异常未处理**
- `setInterval(checkAndProcessTasks, ...)` 如果内部抛出异常，定时器会停止
- 没有对每次执行进行独立的错误捕获

## 修复方案

### 修改 1: 添加全局错误保护

**位置**: `task_processor.pb.js` 底部

```javascript
// 捕获未处理的 Promise rejection，防止进程退出
process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ [TaskProcessor] 未处理的 Promise 异常:', reason);
  console.error('Promise:', promise);
  // 不退出进程，继续运行
});

// 捕获未捕获的异常
process.on('uncaughtException', (error) => {
  console.error('❌ [TaskProcessor] 未捕获的异常:', error);
  // 不退出进程，继续运行（但应该修复代码）
});

// 启动程序时使用 .catch()
init().catch(err => {
  console.error('❌ [TaskProcessor] 初始化失败:', err);
  process.exit(1);
});
```

### 修改 2: 添加认证保活机制

**位置**: `init()` 函数内

```javascript
// 监听 authStore 变化，确保认证状态
pb.authStore.onChange(() => {
  console.log('[TaskProcessor] 🔐 认证状态变化，当前有效:', pb.authStore.isValid);
  if (!pb.authStore.isValid) {
    console.warn('[TaskProcessor] ⚠️ 认证失效，尝试重新登录...');
    reAuthenticate().catch(err => {
      console.error('[TaskProcessor] ❌ 重新认证失败:', err.message);
    });
  }
});

// 新增重新认证函数
async function reAuthenticate() {
  try {
    await pb.collection('_superusers').authWithPassword(ADMIN_EMAIL, ADMIN_PASSWORD);
    console.log('✅ [TaskProcessor] 重新认证成功 (Superuser)');
  } catch (e) {
    await pb.admins.authWithPassword(ADMIN_EMAIL, ADMIN_PASSWORD);
    console.log('✅ [TaskProcessor] 重新认证成功 (Admin)');
  }
}
```

### 修改 3: 健壮的定时器错误处理

**位置**: `init()` 函数内

```javascript
// 使用更健壮的定时检查，避免异常导致定时器失效
setInterval(() => {
  checkAndProcessTasks().catch(err => {
    console.error('[TaskProcessor] ❌ 任务检查循环出错:', err.message);
    console.error('[TaskProcessor] 🔄 将在下个周期继续尝试...');
  });
}, CHECK_INTERVAL);

// 心跳也添加错误处理
setInterval(() => {
  updateHeartbeat().catch(err => {
    console.error('[TaskProcessor] ❌ 心跳更新失败:', err.message);
  });
}, 60000);
```

### 修改 4: 增强任务检查的容错性

**位置**: `checkAndProcessTasks()` 函数

```javascript
async function checkAndProcessTasks() {
  if (isProcessing) {
    console.log('[TaskProcessor] ⏳ 上一个任务仍在处理中，跳过本次检查');
    return;
  }

  try {
    isProcessing = true;

    // 验证认证状态
    if (!pb.authStore.isValid) {
      console.warn('[TaskProcessor] ⚠️ 认证状态无效，尝试重新登录...');
      await reAuthenticate();
    }

    // ... 原有逻辑 ...

    // 逐个处理任务，单个任务失败不影响其他任务
    for (const task of pendingTasks) {
      try {
        await dispatchTask(task);
      } catch (err) {
        console.error(`[TaskProcessor] ❌ 处理任务 ${task.id} 时出错:`, err.message);
        // 继续处理下一个任务
      }
    }

  } catch (error) {
    console.error('[TaskProcessor] ❌ 检查任务时出错:', error.message);
    
    // 如果是认证问题，尝试重新连接
    if (error.message.includes('401') || error.message.includes('403')) {
      console.warn('[TaskProcessor] 🔐 检测到认证问题，尝试重新登录...');
      try {
        await reAuthenticate();
      } catch (reAuthError) {
        console.error('[TaskProcessor] ❌ 重新认证失败:', reAuthError.message);
      }
    }
  } finally {
    isProcessing = false;
  }
}
```

### 修改 5: 更新 Supervisor 配置

**位置**: `supervisord.conf`

```ini
[program:task-processor]
command=node /app/processor/task_processor.pb.js
directory=/app/processor
autostart=true
autorestart=true
startretries=10        ; 允许重启 10 次
startsecs=5            ; 启动后至少运行 5 秒才算成功
stdout_logfile=/var/log/supervisor/task_processor.log
stderr_logfile=/var/log/supervisor/task_processor_error.log
environment=NODE_ENV="production",PB_URL="https://pb.osglab.com",...
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=10
stderr_logfile_maxbytes=50MB
stderr_logfile_backups=10
stopwaitsecs=30        ; 关闭前等待 30 秒
killasgroup=true       ; 杀死进程组
stopasgroup=true       ; 停止进程组
```

## 部署步骤

### 1. 本地测试

```bash
cd Puked_web
node scripts/task_processor.pb.js
```

观察日志，确保看到：
- ✅ 登录成功
- 🔄 开始监听任务队列
- ✨ 运行中...
- 💡 进程保持运行，等待任务队列...

### 2. 健康检查

```bash
node scripts/check_processor_health.js
```

这会检查：
- 心跳是否正常
- 任务队列是否积压
- 最近任务执行情况
- 综合健康评分

### 3. Docker 构建

```bash
cd Puked_web
docker build -f Dockerfile.allinone.v2 -t rocky8848/puked-web:2.4.7 .
```

### 4. 本地测试容器

```bash
# 停止旧容器
docker stop puked-web-test
docker rm puked-web-test

# 启动新容器
docker run -d \
  --name puked-web-test \
  -p 8080:80 \
  rocky8848/puked-web:2.4.7

# 查看日志
docker logs -f puked-web-test

# 检查 Supervisor 状态
docker exec puked-web-test supervisorctl status

# 检查任务处理器日志
docker exec puked-web-test tail -n 100 /var/log/supervisor/task_processor.log
```

### 5. 多架构构建并推送

```bash
# 使用 buildx 构建多架构镜像
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f Dockerfile.allinone.v2 \
  -t rocky8848/puked-web:2.4.7 \
  --push \
  .
```

### 6. 生产部署

```bash
# 在生产服务器上
docker pull rocky8848/puked-web:2.4.7

docker stop puked-web
docker rm puked-web

docker run -d \
  --name puked-web \
  --restart unless-stopped \
  -p 80:80 \
  rocky8848/puked-web:2.4.7

# 持续监控日志
docker logs -f puked-web

# 定期检查健康状态
docker exec puked-web node /app/processor/check_processor_health.js
```

## 验证方法

### 1. 进程保活验证

```bash
# 查看进程启动时间
docker exec puked-web ps aux | grep node

# 查看 Supervisor 状态（应该是 RUNNING）
docker exec puked-web supervisorctl status task-processor

# 查看最新日志（应该有定期的心跳日志）
docker exec puked-web tail -n 50 /var/log/supervisor/task_processor.log
```

### 2. 任务执行验证

在前端触发"触发数据归纳"，然后：

```bash
# 实时查看任务处理器日志
docker exec puked-web tail -f /var/log/supervisor/task_processor.log

# 应该看到类似的日志：
# [TaskProcessor] 📋 发现 1 个待处理任务
# [TaskProcessor] 🚀 开始处理任务: xxx
# [TaskProcessor] ✨ 任务完成: xxx
```

### 3. 长期稳定性验证

运行健康检查脚本：

```bash
docker exec puked-web node /app/processor/check_processor_health.js
```

应该看到：
- ✅ 心跳正常
- ✅ 无任务积压
- 🏥 健康评分: 100/100

## 故障排查

### 如果进程仍然退出

1. 查看 stderr 日志：
   ```bash
   docker exec puked-web cat /var/log/supervisor/task_processor_error.log
   ```

2. 查看 supervisord 日志：
   ```bash
   docker exec puked-web cat /var/log/supervisor/supervisord.log
   ```

3. 手动运行进程，查看详细错误：
   ```bash
   docker exec -it puked-web sh
   cd /app/processor
   node task_processor.pb.js
   ```

### 如果任务不执行

1. 检查数据库连接：
   ```bash
   docker exec puked-web node /app/processor/check_processor_health.js
   ```

2. 检查 PocketBase 服务是否正常：
   ```bash
   curl -I https://pb.osglab.com/api/health
   ```

3. 检查任务队列：
   ```sql
   -- 在 PocketBase Admin UI 中执行
   SELECT * FROM sync_tasks WHERE status = 'pending' ORDER BY created DESC
   ```

## 关键改进总结

✅ **全局错误捕获** - 防止未处理的异常导致进程退出  
✅ **认证保活机制** - 自动检测和重新认证  
✅ **健壮的定时器** - 单次执行失败不影响后续执行  
✅ **独立任务处理** - 单个任务失败不影响其他任务  
✅ **详细日志输出** - 便于排查问题  
✅ **健康检查脚本** - 快速诊断系统状态  
✅ **Supervisor 自动重启** - 进程崩溃时自动恢复

## 预期行为

修复后，任务处理器应该：

1. **启动时**：
   - 输出详细的启动日志
   - 成功登录 PocketBase
   - 开始心跳和任务轮询

2. **运行中**：
   - 每 10 秒检查一次任务队列（无任务时不输出日志）
   - 每 1 分钟更新一次心跳
   - 发现任务时立即处理并输出详细日志

3. **遇到错误时**：
   - 打印错误日志但不退出
   - 自动重试认证
   - 继续处理其他任务

4. **进程崩溃时**：
   - Supervisor 自动重启
   - 最多重启 10 次
   - 重启后自动恢复工作

## 监控建议

建议在生产环境中添加以下监控：

1. **进程存活监控**：定期检查 `supervisorctl status task-processor`
2. **心跳监控**：定期运行健康检查脚本
3. **任务积压监控**：检查 `pending` 状态的任务数量
4. **日志监控**：使用 ELK/Loki 收集和分析日志

## 注意事项

⚠️ 这次修复添加了 `uncaughtException` 监听器，这是为了防止进程退出，但**不是最佳实践**。理想情况下，所有异步操作都应该有显式的错误处理。建议在生产环境中持续监控日志，发现未捕获的异常后及时修复代码。

⚠️ 环境变量已硬编码在 `supervisord.conf` 中（包括密码），如果需要更改，需要重新构建镜像。更安全的做法是使用 Docker Secrets 或环境变量注入。
