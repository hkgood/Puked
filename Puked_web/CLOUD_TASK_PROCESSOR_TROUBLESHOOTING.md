# 云端部署后 Web 打不开 / task-processor 退出排查

## 从你提供的 Log 能看出什么

- **supervisord** 在管理两个进程：`nginx` 和 `task-processor`。
- **nginx** 启动成功并保持 RUNNING，所以**静态前端（Nginx 提供的页面）在容器内是起来的**。
- **task-processor** 每次启动后很快以 **exit status 1** 退出，supervisor 多次重试后放弃，进入 **FATAL**。

因此：  
**“打不开”的直接原因是 task-processor 一直在崩溃，而真正原因在 task-processor 自己的日志里，不在你贴的这段 supervisor 日志里。**

---

## 1. 先确认“打不开”具体指什么

- **情况 A**：浏览器访问域名完全打不开（超时、连接被拒等）  
  → 多半是**入口/网络/端口**问题（负载均衡、安全组、端口映射），和 task-processor 无直接关系。
- **情况 B**：首页能打开，但某些功能（例如仪表盘、任务状态）不工作或报错  
  → 很可能和 **task-processor 没起来**有关（前端依赖它提供的接口或 PocketBase 里由它更新的数据）。

你当前日志说明的是 **task-processor 起不来**，所以至少情况 B 会存在。

---

## 2. task-processor 为什么 exit 1（必看真实错误）

`task_processor.pb.js` 里只有在**启动阶段失败**时才会 `process.exit(1)`，例如：

- 登录 PocketBase 失败（认证错误或网络不可达）。
- 启动时访问 PocketBase 失败（例如第一次心跳或首轮任务检查前的请求就挂了）。

**真实错误信息**会写在容器内的：

- `stderr` → `/var/log/supervisor/task_processor_error.log`
- stdout → `/var/log/supervisor/task_processor.log`

**在部署了该容器的机器上执行**（把 `你的容器名或ID` 换成实际值，例如 `puked-web`）：

```bash
# 看最近错误（最重要）
docker exec 你的容器名或ID cat /var/log/supervisor/task_processor_error.log

# 看最近标准输出（会有启动日志和 “认证失败” 等提示）
docker exec 你的容器名或ID cat /var/log/supervisor/task_processor.log
```

如果你用的是云平台的“应用运行时”（如 Cloud Run、App Engine、某云“Web 应用”），到该服务的 **日志/日志聚合** 里找**对应容器或实例的 stderr/stdout**，通常就能看到同上面两个文件一样的内容。

---

## 3. 常见原因与对应处理

| 可能原因 | 说明 | 处理建议 |
|----------|------|----------|
| **云端无法访问 PB_URL** | 容器内访问不到 `https://pb.osglab.com`（DNS、防火墙、出网策略）。登录或第一次请求就超时/失败，init 里抛错并 `process.exit(1)`。 | 在云上放通出网 443；同一 VPC 内若有 PocketBase，改用内网地址；或在能访问 PB 的机器上先 `docker exec ... node /app/processor/task_processor.pb.js` 看报错。 |
| **ADMIN_EMAIL / ADMIN_PASSWORD 错误** | 和本地/测试环境不一致；或 supervisord 里写死了错误的值。 | 核对 `supervisord.conf` 或部署时注入的环境变量，与 PocketBase 后台一致；必要时在镜像中改为从环境变量读取（见下）。 |
| **PocketBase 版本/API 变化** | 脚本里先试 `_superusers` 再试 `admins`，若两边都失败会抛“认证失败”并退出。 | 查看 `task_processor_error.log` 里的具体报错；确认 PB 版本与脚本兼容。 |
| **镜像里没有正确复制 node_modules 或脚本** | 少见，但会导致 require/import 报错或找不到文件，启动即退出。 | 本地用同版本 Dockerfile 构建并 `docker run` 一次，看是否同样 exit 1。 |

---

## 4. 建议立刻做的两件事

1. **在部署该镜像的机器上**执行上面两条 `docker exec ... cat ...` 命令，把 **task_processor_error.log 和 task_processor.log 的最后几十行**贴出来，才能精确定位 exit 1 的原因。
2. **在云端测试容器能否访问 PocketBase**（可选）：  
   `docker exec 你的容器名 wget -q -O- --timeout=5 https://pb.osglab.com/api/health 2>&1`  
   若超时或连接失败，说明是网络/出网问题。

---

## 5. 关于“打不开”的入口问题（若整站都打不开）

若你确认是**整站都打不开**（不是仅功能异常）：

- 你贴的日志里 **nginx 是 RUNNING**，所以容器内 80 端口应有服务。
- 需要检查：云平台的**公网入口**是否指向该容器的 80 端口（端口映射、Ingress、负载均衡、安全组是否放通 80/443）。

---

## 6. 小结

- **现象**：task-processor 反复退出（exit 1），进入 FATAL；nginx 正常。
- **原因**：在 `init()` 或 `init().catch` 里发生错误并 `process.exit(1)`，真实原因在 **task_processor_error.log / task_processor.log**（或云平台等价 stderr/stdout）。
- **下一步**：在部署环境执行 `docker exec ... cat /var/log/supervisor/task_processor_error.log`（以及 .log），根据报错信息再针对网络、认证或配置修改。

如果你把 `task_processor_error.log` 和 `task_processor.log` 的末尾内容发出来，我可以根据具体报错帮你写改法或改 supervisord/环境变量的示例。
