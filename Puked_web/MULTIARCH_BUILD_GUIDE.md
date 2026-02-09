# 🔧 多架构镜像构建指南

## 问题说明

生产服务器报错：`exec /docker-entrypoint.sh: exec format error`

**原因：** 在 Mac (ARM64) 上构建的镜像无法在 x86_64 服务器上运行

**解决方案：** 构建支持多架构的镜像 (linux/amd64 + linux/arm64)

---

## 🚀 快速构建（推荐）

### 方法 1: 使用自动化脚本

```bash
cd /Users/rocky/Documents/PukedMaster/Puked_web
bash build_multiarch.sh
```

脚本会自动：
- ✅ 检查 Docker 状态
- ✅ 创建多架构构建器
- ✅ 构建 amd64 和 arm64 镜像
- ✅ 推送到 Docker Hub

---

## 🌐 网络问题解决方案

如果遇到网络超时错误，按以下步骤解决：

### 1. 配置 Docker 镜像加速器

打开 Docker Desktop：
```
Settings -> Docker Engine
```

添加以下配置：
```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.mirrors.sjtug.sjtu.edu.cn",
    "https://docker.nju.edu.cn"
  ]
}
```

点击 `Apply & Restart`

### 2. 配置系统代理（如果有）

```
Docker Desktop -> Settings -> Resources -> Proxies
启用 "Manual proxy configuration"
```

### 3. 预拉取基础镜像

```bash
# 拉取 amd64 架构
docker pull --platform linux/amd64 node:20-alpine
docker pull --platform linux/amd64 nginx:stable-alpine

# 拉取 arm64 架构  
docker pull --platform linux/arm64 node:20-alpine
docker pull --platform linux/arm64 nginx:stable-alpine
```

---

## 📋 手动构建步骤

如果自动化脚本失败，可以手动执行：

### Step 1: 创建多架构构建器

```bash
docker buildx create --name puked-multiarch --driver docker-container --bootstrap --use
```

### Step 2: 验证构建器

```bash
docker buildx inspect puked-multiarch
```

确认输出包含：
```
Platforms: linux/arm64, linux/amd64, ...
```

### Step 3: 构建并推送

```bash
cd /Users/rocky/Documents/PukedMaster/Puked_web

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --file Dockerfile.allinone.v2 \
  --tag rocky8848/puked-web:2.4.6 \
  --tag rocky8848/puked-web:latest \
  --push \
  .
```

---

## 🔄 分步构建方案（网络不稳定时）

如果网络持续失败，可以分别构建两个架构：

### 1. 构建 amd64 镜像

```bash
docker buildx build \
  --platform linux/amd64 \
  --file Dockerfile.allinone.v2 \
  --tag rocky8848/puked-web:2.4.6-amd64 \
  --load \
  .
```

### 2. 构建 arm64 镜像

```bash
docker buildx build \
  --platform linux/arm64 \
  --file Dockerfile.allinone.v2 \
  --tag rocky8848/puked-web:2.4.6-arm64 \
  --load \
  .
```

### 3. 推送镜像

```bash
docker push rocky8848/puked-web:2.4.6-amd64
docker push rocky8848/puked-web:2.4.6-arm64
```

### 4. 创建 manifest

```bash
docker manifest create rocky8848/puked-web:2.4.6 \
  rocky8848/puked-web:2.4.6-amd64 \
  rocky8848/puked-web:2.4.6-arm64

docker manifest push rocky8848/puked-web:2.4.6
```

---

## ✅ 验证多架构镜像

### 检查镜像支持的架构

```bash
docker buildx imagetools inspect rocky8848/puked-web:2.4.6
```

**预期输出：**
```
Name:      docker.io/rocky8848/puked-web:2.4.6
MediaType: application/vnd.docker.distribution.manifest.list.v2+json
Digest:    sha256:...
           
Manifests: 
  Name:      docker.io/rocky8848/puked-web:2.4.6@sha256:...
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  linux/amd64
             
  Name:      docker.io/rocky8848/puked-web:2.4.6@sha256:...
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  linux/arm64
```

### 在 x86_64 服务器上测试

```bash
# SSH 到生产服务器
docker pull rocky8848/puked-web:2.4.6

# 应该自动拉取 amd64 架构的镜像
docker run -d \
  --name puked-web \
  -p 3001:80 \
  -e PB_URL=https://pb.osglab.com \
  -e ADMIN_EMAIL=rocky.hk@gmail.com \
  -e ADMIN_PASSWORD=your_password \
  --restart unless-stopped \
  rocky8848/puked-web:2.4.6

# 验证
docker exec puked-web uname -m  # 应该输出: x86_64
docker exec puked-web supervisorctl status
```

---

## 🐛 常见错误排查

### 错误 1: `exec format error`

**原因：** 架构不匹配

**解决：** 确保使用多架构镜像，或在服务器上指定平台：
```bash
docker pull --platform linux/amd64 rocky8848/puked-web:2.4.6
```

### 错误 2: `failed to fetch oauth token`

**原因：** Docker Hub 网络连接问题

**解决：**
1. 配置镜像加速器（见上文）
2. 使用代理
3. 重试构建

### 错误 3: `Multi-platform build is not supported`

**原因：** 使用了错误的构建器

**解决：**
```bash
docker buildx use puked-multiarch
```

### 错误 4: 构建器状态为 `inactive`

**解决：**
```bash
docker buildx rm puked-multiarch
docker buildx create --name puked-multiarch --driver docker-container --bootstrap --use
```

---

## 📚 参考资源

- **Docker 多平台构建文档**: https://docs.docker.com/build/building/multi-platform/
- **Docker Buildx 文档**: https://docs.docker.com/buildx/working-with-buildx/
- **构建脚本**: `build_multiarch.sh`
- **Dockerfile**: `Dockerfile.allinone.v2`

---

## 🎯 下一步

1. ✅ 配置 Docker 镜像加速器
2. ✅ 重启 Docker Desktop
3. ✅ 运行 `bash build_multiarch.sh`
4. ✅ 等待构建完成（可能需要 5-10 分钟）
5. ✅ 验证镜像支持多架构
6. ✅ 在生产服务器上部署测试

---

**状态：** 等待网络问题解决后重新构建  
**版本：** 2.4.6  
**目标架构：** linux/amd64, linux/arm64
