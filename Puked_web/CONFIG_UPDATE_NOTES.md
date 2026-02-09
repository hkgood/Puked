# 配置更新说明

## 📝 已调整的配置

根据你的需求，我已经将任务检查和心跳频率调整为更合理的值：

### 之前的配置（过于频繁）

```javascript
CHECK_INTERVAL = 10000        // 10秒检查一次任务
HEARTBEAT_INTERVAL = 60000    // 1分钟更新一次心跳
```

### 当前配置（推荐值）✅

```javascript
CHECK_INTERVAL = 60000         // 1分钟检查一次任务
HEARTBEAT_INTERVAL = 300000    // 5分钟更新一次心跳
```

## 📊 对比分析

| 指标 | 旧值 | 新值 | 改进 |
|------|------|------|------|
| 任务检查间隔 | 10秒 | 60秒 | ⬇️ 减少数据库查询 83% |
| 心跳更新间隔 | 60秒 | 300秒 | ⬇️ 减少数据库写入 80% |
| 每小时查询次数 | 360次 | 60次 | ⬇️ 减少 300次/小时 |
| 每小时写入次数 | 60次 | 12次 | ⬇️ 减少 48次/小时 |

## ✅ 优点

1. **降低数据库负载**
   - 查询频率从每10秒降至每60秒
   - 心跳写入从每分钟降至每5分钟

2. **降低网络开销**
   - 减少 HTTP 请求数量
   - 节省带宽

3. **更符合实际需求**
   - 对于用户量不大的场景，1分钟响应时间完全可接受
   - 5分钟的心跳间隔足够判断进程健康状态

4. **保持可靠性**
   - 任务仍会在1分钟内被处理
   - 健康检查阈值调整为10分钟，给予充足的容错时间

## 📁 修改的文件

1. **`scripts/task_processor.pb.js`**
   - ✏️ 修改默认值为 60秒 和 5分钟
   - ✏️ 支持通过环境变量配置
   - ✏️ 启动时显示配置信息

2. **`supervisord.conf`**
   - ✏️ 环境变量更新为新值
   - ✏️ 添加 `HEARTBEAT_INTERVAL` 配置

3. **`scripts/check_processor_health.js`**
   - ✏️ 心跳超时阈值从 2分钟调整为 10分钟
   - ✏️ 任务积压阈值从 5分钟调整为 10分钟

4. **`TASK_PROCESSOR_CONFIG.md`**
   - ✨ 新增配置说明文档
   - ✨ 包含调优指南和最佳实践

## 🔍 如何验证配置生效

### 1. 本地测试

```bash
cd Puked_web
node scripts/task_processor.pb.js
```

启动日志应该显示：

```
==========================================
🚀 [TaskProcessor] 引擎正在启动...
📍 [TaskProcessor] 目标地址: https://pb.osglab.com
📋 [TaskProcessor] 任务检查间隔: 60 秒
💓 [TaskProcessor] 心跳更新间隔: 300 秒
📦 [TaskProcessor] 批次大小: 10
🔢 [TaskProcessor] 并发数: 3
==========================================
```

### 2. Docker 容器测试

```bash
# 查看启动日志
docker logs puked-web | grep "任务检查间隔"
docker logs puked-web | grep "心跳更新间隔"

# 应该看到：
# 📋 [TaskProcessor] 任务检查间隔: 60 秒
# 💓 [TaskProcessor] 心跳更新间隔: 300 秒
```

### 3. 观察运行间隔

```bash
# 实时查看日志
docker exec puked-web tail -f /var/log/supervisor/task_processor.log

# 如果没有待处理任务，不会有输出（静默模式）
# 如果触发任务，会看到日志输出
```

## 🎯 下一步操作

### 选项 1: 本地测试（推荐先测试）

```bash
cd Puked_web
node scripts/task_processor.pb.js
```

按 Ctrl+C 退出后，如果看到正确的配置信息，说明修改成功。

### 选项 2: 构建新镜像

```bash
cd Puked_web

# 方式 A: 使用自动化脚本
./deploy_keepalive_fix.sh

# 方式 B: 手动构建
docker build -f Dockerfile.allinone.v2 -t rocky8848/puked-web:2.4.7 .
```

### 选项 3: 动态调整（无需重新构建）

如果你想在不重新构建镜像的情况下测试不同的间隔值：

```bash
docker run -d \
  --name puked-web-test \
  -e CHECK_INTERVAL=120000 \
  -e HEARTBEAT_INTERVAL=600000 \
  -p 8080:80 \
  rocky8848/puked-web:2.4.7
```

**注意**: 这只在 `supervisord.conf` 中没有硬编码环境变量时才生效。当前我们已经硬编码了值，所以需要重新构建镜像。

## 💡 进一步调优建议

如果你觉得当前配置仍不够慢，可以进一步调整：

### 更低频率场景

```bash
CHECK_INTERVAL=120000         # 2分钟检查一次
HEARTBEAT_INTERVAL=600000     # 10分钟更新一次心跳
```

### 极低频率场景

```bash
CHECK_INTERVAL=300000         # 5分钟检查一次
HEARTBEAT_INTERVAL=900000     # 15分钟更新一次心跳
```

**权衡**:
- ⬆️ 间隔越长 → 资源占用越少
- ⬇️ 但任务响应时间会相应增加

对于当前的用户规模，我认为 **1分钟检查 + 5分钟心跳** 是一个很好的平衡点。

## 📚 相关文档

- **配置详细说明**: `TASK_PROCESSOR_CONFIG.md`
- **修复指南**: `TASK_PROCESSOR_KEEPALIVE_FIX.md`
- **总体总结**: `TASK_PROCESSOR_KEEPALIVE_SUMMARY.md`

---

**更新版本**: 2.4.7  
**更新时间**: 2026-02-03  
**更新内容**: 调整任务检查和心跳间隔为更合理的值
