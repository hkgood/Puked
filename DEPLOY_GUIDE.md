# Puked.osglab.com 快速部署指南

## 📦 文件清单

我已经为你准备了以下文件：

1. **puked.osglab.com.conf** - 主配置文件（基于你的原配置优化）
2. **puked-web.conf** - 反向代理配置（新增）
3. **deploy.sh** - 自动部署脚本（一键部署）

---

## 🚀 快速部署（3步）

### 方法 1：使用自动脚本（推荐）

```bash
# 1. 进入目录
cd /Users/maxliu/Documents/PukedMaster

# 2. 运行部署脚本
./deploy.sh
```

脚本会自动完成：
- ✅ 备份现有配置
- ✅ 部署新配置
- ✅ 测试 Nginx 配置
- ✅ 重新加载 Nginx
- ✅ 重新部署 Docker 容器
- ✅ 验证部署结果

---

### 方法 2：手动部署

#### 步骤 1：备份现有配置

```bash
# 创建备份目录
mkdir -p /www/sites/puked.osglab.com/backup_$(date +%Y%m%d)

# 备份主配置（找到你的实际配置文件位置）
cp /etc/nginx/conf.d/puked.osglab.com.conf /www/sites/puked.osglab.com/backup_$(date +%Y%m%d)/

# 或者
cp /etc/nginx/sites-enabled/puked.osglab.com /www/sites/puked.osglab.com/backup_$(date +%Y%m%d)/
```

#### 步骤 2：部署新配置

```bash
# 创建 proxy 目录
mkdir -p /www/sites/puked.osglab.com/proxy

# 复制代理配置
cp /Users/maxliu/Documents/PukedMaster/puked-web.conf \
   /www/sites/puked.osglab.com/proxy/

# 更新主配置文件
# 方式A：直接替换（如果路径一致）
cp /Users/maxliu/Documents/PukedMaster/puked.osglab.com.conf \
   /etc/nginx/conf.d/puked.osglab.com.conf

# 方式B：手动编辑
nano /etc/nginx/conf.d/puked.osglab.com.conf
# 按照 puked.osglab.com.conf 的内容更新
```

#### 步骤 3：重新加载 Nginx

```bash
# 测试配置
nginx -t

# 如果测试通过，重新加载
nginx -s reload
```

#### 步骤 4：重新部署 Docker

```bash
cd /Users/maxliu/Documents/PukedMaster/Puked_web

# 停止旧容器
docker stop puked-web && docker rm puked-web

# 删除旧镜像
docker rmi puked-web:latest

# 重新构建
docker build --no-cache -t puked-web:latest .

# 启动新容器
docker run -d \
  --name puked-web \
  -p 3001:80 \
  --restart unless-stopped \
  puked-web:latest
```

---

## 🔍 验证部署

### 1. 检查容器状态

```bash
docker ps | grep puked-web
```

应该看到容器正在运行。

### 2. 测试本地访问

```bash
curl -I http://127.0.0.1:3001
```

应该返回 `200 OK` 或 `301`。

### 3. 测试反向代理

```bash
curl -I https://puked.osglab.com
```

应该返回 `200 OK`。

### 4. 浏览器测试

1. **清除浏览器缓存**（重要！）
   - Chrome: `Ctrl+Shift+Delete` → 清除全部
   - 或使用无痕模式

2. **打开开发者工具**
   - 按 `F12`
   - 切换到 Network 面板
   - 勾选 "Disable cache"

3. **访问网站**
   - 打开 `https://puked.osglab.com`
   - 检查所有资源是否正常加载
   - 不应该看到 `ERR_HTTP2_PROTOCOL_ERROR`

---

## 📊 配置对比

### 你的原配置 vs 新配置

#### 原配置的问题：
```nginx
# ❌ 这些在 server 块中不起作用
proxy_buffer_size 128k;
proxy_buffers 4 256k;
proxy_busy_buffers_size 256k;
```

#### 新配置的修复：
```nginx
# ✅ 移到 location 块中
location / {
    proxy_buffer_size 128k;
    proxy_buffers 8 256k;        # 增大到 8 个
    proxy_busy_buffers_size 512k; # 增大到 512k
    proxy_http_version 1.1;       # 🔑 关键：禁用到后端的 HTTP/2
}
```

---

## 🔧 关键修改点

### 1. 主配置文件变化

```diff
server {
    # ...现有配置保持不变...
    
+   # 🆕 增加客户端缓冲区
+   client_body_buffer_size 256k;
+   client_max_body_size 50m;
+   client_header_buffer_size 32k;
+   large_client_header_buffers 4 128k;
    
    http2 on;
+   # 🆕 HTTP/2 优化参数
+   http2_max_field_size 128k;
+   http2_max_header_size 128k;
+   http2_max_requests 1000;
    
-   # ❌ 移除这些（移到 location 块）
-   proxy_buffer_size 128k;
-   proxy_buffers 4 256k;
-   proxy_busy_buffers_size 256k;
-   proxy_set_header Host $host;
-   # ... 其他 proxy_set_header ...
    
    # 引入代理配置
    include /www/sites/puked.osglab.com/proxy/*.conf;
}
```

### 2. 新增代理配置文件

**位置**：`/www/sites/puked.osglab.com/proxy/puked-web.conf`

**核心内容**：
```nginx
location / {
    proxy_pass http://127.0.0.1:3001;
    proxy_http_version 1.1;  # 🔑 关键配置
    
    # 缓冲区配置
    proxy_buffer_size 128k;
    proxy_buffers 8 256k;
    proxy_busy_buffers_size 512k;
    
    # 请求头传递
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    # ... 其他 headers ...
}
```

---

## 🚨 故障排查

### 问题 1：Nginx 配置测试失败

```bash
# 查看详细错误
nginx -t

# 检查语法
nginx -T | grep -A 5 -B 5 "error"

# 如果需要回滚
cp /www/sites/puked.osglab.com/backup_*/puked.osglab.com.conf \
   /etc/nginx/conf.d/
nginx -s reload
```

### 问题 2：容器无法访问

```bash
# 查看容器日志
docker logs puked-web

# 进入容器检查
docker exec -it puked-web sh
ls -la /usr/share/nginx/html/
cat /etc/nginx/conf.d/default.conf

# 测试容器内部
docker exec puked-web curl -I http://localhost:80
```

### 问题 3：反向代理不工作

```bash
# 检查代理配置是否加载
nginx -T | grep "proxy_pass"

# 应该看到：
# proxy_pass http://127.0.0.1:3001;

# 检查端口是否监听
netstat -tlnp | grep 3001

# 查看 Nginx 错误日志
tail -f /www/sites/puked.osglab.com/log/error.log
```

---

## ✅ 部署成功标志

- [ ] `nginx -t` 测试通过
- [ ] `nginx -s reload` 成功
- [ ] `docker ps` 显示 puked-web 运行
- [ ] `curl http://127.0.0.1:3001` 返回 200
- [ ] `curl https://puked.osglab.com` 返回 200
- [ ] 浏览器访问正常
- [ ] Network 面板所有资源加载成功
- [ ] 无 `ERR_HTTP2_PROTOCOL_ERROR` 错误

---

## 📞 需要帮助？

如果部署过程中遇到问题：

1. **查看日志**
   ```bash
   # Nginx 日志
   tail -f /www/sites/puked.osglab.com/log/error.log
   
   # Docker 日志
   docker logs -f puked-web
   ```

2. **检查配置**
   ```bash
   # 查看生效的配置
   nginx -T
   
   # 检查代理配置
   cat /www/sites/puked.osglab.com/proxy/puked-web.conf
   ```

3. **回滚**
   ```bash
   # 恢复备份
   cp /www/sites/puked.osglab.com/backup_*/puked.osglab.com.conf \
      /etc/nginx/conf.d/
   nginx -s reload
   ```

---

**准备好了就运行 `./deploy.sh` 开始部署！** 🚀
