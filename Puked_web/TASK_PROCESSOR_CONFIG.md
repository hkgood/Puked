# 任务处理器配置说明

## 环境变量配置

任务处理器支持通过环境变量进行配置调优。

### 配置参数

| 参数名 | 默认值 | 说明 |
|--------|--------|------|
| `PB_URL` | `https://pb.osglab.com` | PocketBase 服务地址 |
| `ADMIN_EMAIL` | `rocky.hk@gmail.com` | 管理员邮箱 |
| `ADMIN_PASSWORD` | `gz203799` | 管理员密码 |
| `CHECK_INTERVAL` | `60000` (60秒) | 任务队列检查间隔（毫秒） |
| `HEARTBEAT_INTERVAL` | `300000` (5分钟) | 心跳更新间隔（毫秒） |
| `BATCH_SIZE` | `10` | 每批处理的行程数量 |
| `CONCURRENCY` | `3` | 并发下载 JSON 文件的数量 |

### 当前配置（推荐值）

```bash
CHECK_INTERVAL=60000          # 1分钟检查一次任务队列
HEARTBEAT_INTERVAL=300000     # 5分钟更新一次心跳
BATCH_SIZE=10                 # 每批处理10个行程
CONCURRENCY=3                 # 并发处理3个文件
```

### 配置原理

#### 1. **任务检查间隔** (`CHECK_INTERVAL`)

**作用**: 决定多久检查一次是否有新任务需要处理。

**调优建议**:
- **低频场景**（用户较少，任务不频繁）: `60000` (1分钟) 或更长
- **中频场景**（正常使用）: `30000` (30秒)
- **高频场景**（大量用户，任务频繁）: `10000` (10秒)

**权衡**:
- ⬇️ 间隔越短 → 任务响应越快，但数据库查询频率越高
- ⬆️ 间隔越长 → 节省资源，但任务等待时间越长

#### 2. **心跳间隔** (`HEARTBEAT_INTERVAL`)

**作用**: 决定多久更新一次"活跃状态"标记。

**调优建议**:
- **生产环境**: `300000` (5分钟) - 推荐
- **开发环境**: `60000` (1分钟) - 便于调试
- **低频环境**: `600000` (10分钟) - 最小化数据库写入

**权衡**:
- ⬇️ 间隔越短 → 健康检查更准确，但数据库写入频率越高
- ⬆️ 间隔越长 → 节省资源，但故障检测延迟增加

**注意**: 健康检查脚本会将 `> 2倍心跳间隔` 视为异常。

#### 3. **批次大小** (`BATCH_SIZE`)

**作用**: 每次处理多少个行程后暂停并保存进度。

**调优建议**:
- **小数据集**（<100个行程）: `10` - 推荐
- **中等数据集**（100-1000个行程）: `20`
- **大数据集**（>1000个行程）: `50`

**权衡**:
- ⬇️ 批次越小 → 内存占用越少，进度更新越频繁，任务失败时丢失的数据越少
- ⬆️ 批次越大 → 处理效率越高，但内存占用增加，任务失败时需重新处理更多数据

#### 4. **并发数** (`CONCURRENCY`)

**作用**: 同时下载分析多少个 JSON 文件。

**调优建议**:
- **网络较慢**: `2-3` - 推荐
- **网络正常**: `5`
- **网络很快 + 高性能服务器**: `10`

**权衡**:
- ⬇️ 并发越小 → 网络压力越小，但处理速度慢
- ⬆️ 并发越大 → 处理速度快，但可能因网络瓶颈导致超时

## 配置方法

### 方法 1: 修改 `supervisord.conf`（推荐）

编辑 `Puked_web/supervisord.conf`:

```ini
[program:task-processor]
environment=NODE_ENV="production",PB_URL="https://pb.osglab.com",ADMIN_EMAIL="rocky.hk@gmail.com",ADMIN_PASSWORD="gz203799",CHECK_INTERVAL="60000",HEARTBEAT_INTERVAL="300000",BATCH_SIZE="10",CONCURRENCY="3"
```

修改后需要重新构建 Docker 镜像。

### 方法 2: Docker 运行时传递环境变量

```bash
docker run -d \
  --name puked-web \
  -e CHECK_INTERVAL=60000 \
  -e HEARTBEAT_INTERVAL=300000 \
  -e BATCH_SIZE=10 \
  -e CONCURRENCY=3 \
  -p 80:80 \
  rocky8848/puked-web:2.4.7
```

**注意**: Supervisor 的 `environment` 配置优先级高于 Docker 的 `-e`，如果在 `supervisord.conf` 中硬编码了值，则 `-e` 不会生效。

### 方法 3: 修改代码默认值

编辑 `scripts/task_processor.pb.js`:

```javascript
const CHECK_INTERVAL = parseInt(process.env.CHECK_INTERVAL) || 60000;   // 默认60秒
const HEARTBEAT_INTERVAL = parseInt(process.env.HEARTBEAT_INTERVAL) || 300000; // 默认5分钟
const BATCH_SIZE = parseInt(process.env.BATCH_SIZE) || 10;
const CONCURRENCY = parseInt(process.env.CONCURRENCY) || 3;
```

修改后需要重新构建镜像。

## 性能调优场景

### 场景 1: 低流量生产环境（推荐）

适用于：用户数 < 100，每天任务 < 10 个

```bash
CHECK_INTERVAL=60000          # 1分钟
HEARTBEAT_INTERVAL=300000     # 5分钟
BATCH_SIZE=10
CONCURRENCY=3
```

**效果**: 
- ✅ 资源占用最少
- ✅ 任务处理及时（1分钟内响应）
- ✅ 心跳检查准确

### 场景 2: 中等流量环境

适用于：用户数 100-1000，每天任务 10-50 个

```bash
CHECK_INTERVAL=30000          # 30秒
HEARTBEAT_INTERVAL=180000     # 3分钟
BATCH_SIZE=20
CONCURRENCY=5
```

**效果**: 
- ⚖️ 平衡资源和响应速度
- ✅ 任务快速响应（30秒内）
- ✅ 批量处理效率高

### 场景 3: 高流量环境

适用于：用户数 > 1000，每天任务 > 50 个

```bash
CHECK_INTERVAL=10000          # 10秒
HEARTBEAT_INTERVAL=120000     # 2分钟
BATCH_SIZE=50
CONCURRENCY=10
```

**效果**: 
- ⚡ 最快响应速度
- ⚡ 最高处理效率
- ⚠️ 资源占用较高

### 场景 4: 开发/调试环境

```bash
CHECK_INTERVAL=10000          # 10秒 - 快速看到效果
HEARTBEAT_INTERVAL=60000      # 1分钟 - 便于调试
BATCH_SIZE=5                  # 小批次，便于观察日志
CONCURRENCY=2
```

## 健康检查阈值

健康检查脚本使用以下阈值判断系统状态：

| 检查项 | 正常阈值 | 警告阈值 |
|--------|----------|----------|
| 心跳超时 | < 10分钟 | > 10分钟 |
| 任务积压 | < 10分钟 | > 10分钟 |
| 失败率 | < 50% | > 50% |

**注意**: 如果调整了 `HEARTBEAT_INTERVAL`，建议同步调整健康检查脚本中的超时判断（当前为固定 10 分钟）。

## 监控建议

### 关键指标

1. **任务等待时间**: 从创建到开始处理的时间
   - 正常: < `CHECK_INTERVAL`
   - 警告: > `CHECK_INTERVAL * 2`

2. **心跳延迟**: 当前时间 - 最后心跳时间
   - 正常: < `HEARTBEAT_INTERVAL * 2`
   - 警告: > `HEARTBEAT_INTERVAL * 2`

3. **任务处理时长**: 单个任务从开始到完成的时间
   - 正常: 与数据量成正比
   - 警告: 持续超过 10 分钟

### 监控命令

```bash
# 实时查看任务处理日志
docker exec puked-web tail -f /var/log/supervisor/task_processor.log

# 运行健康检查
docker exec puked-web node /app/processor/check_processor_health.js

# 查看进程状态
docker exec puked-web supervisorctl status

# 查看最近的错误
docker exec puked-web tail -n 50 /var/log/supervisor/task_processor_error.log
```

## 故障排查

### 问题 1: 任务积压

**症状**: 大量任务处于 `pending` 状态

**可能原因**:
- `CHECK_INTERVAL` 过长
- 任务处理速度慢（`BATCH_SIZE` 太小或 `CONCURRENCY` 太低）
- 进程已退出

**解决方案**:
1. 检查进程是否运行: `docker exec puked-web supervisorctl status`
2. 查看错误日志: `docker exec puked-web cat /var/log/supervisor/task_processor_error.log`
3. 调整 `CHECK_INTERVAL` 为更短值（如 30000）
4. 增加 `BATCH_SIZE` 和 `CONCURRENCY`

### 问题 2: 心跳超时

**症状**: 健康检查显示心跳超时

**可能原因**:
- 进程已退出
- 网络连接失败
- `HEARTBEAT_INTERVAL` 设置过长

**解决方案**:
1. 检查进程状态
2. 测试 PocketBase 连接: `curl -I https://pb.osglab.com/api/health`
3. 查看日志是否有认证失败
4. 重启容器: `docker restart puked-web`

### 问题 3: 任务处理缓慢

**症状**: 任务长时间处于 `running` 状态

**可能原因**:
- 数据量过大
- `BATCH_SIZE` 过小
- `CONCURRENCY` 过低
- 网络下载 JSON 文件慢

**解决方案**:
1. 查看任务日志，定位慢的步骤
2. 增加 `BATCH_SIZE` (如 20-50)
3. 增加 `CONCURRENCY` (如 5-10)
4. 检查网络连接速度

## 最佳实践

1. **生产环境推荐配置**（已设置）:
   ```
   CHECK_INTERVAL=60000 (1分钟)
   HEARTBEAT_INTERVAL=300000 (5分钟)
   ```

2. **定期监控**: 建议每天运行一次健康检查

3. **日志保留**: 当前配置保留 50MB x 10份，约 500MB 日志

4. **逐步调优**: 不要一次性大幅调整参数，建议每次只调整一个参数

5. **压力测试**: 调整配置后，建议触发一次大批量任务验证效果

---

**当前版本**: 2.4.7  
**最后更新**: 2026-02-03
