# Docker 多架构构建问题总结

## 问题描述

在尝试构建多架构 Docker 镜像（linux/amd64 + linux/arm64）并推送到 Docker Hub 时，遇到了持续的网络超时问题。

## 技术环境

- **主机系统**: macOS 25.3.0 (Apple Silicon / ARM64)
- **Docker**: Docker Desktop for Mac
- **代理**: ClashX (混合代理端口 53785)
- **构建工具**: docker buildx
- **目标镜像**: rocky8848/puked-web-allinone:2.4.7

## 问题时间线

### 1. 初次尝试：用户名不匹配
- **问题**: 尝试推送到 `rockyhk/puked-web-allinone`，但 Docker Hub 登录用户是 `rocky8848`
- **错误**: `push access denied, repository does not exist or may require authorization`
- **解决**: 改用正确的用户名 `rocky8848`

### 2. 网络超时问题开始
- **问题**: Buildx 容器无法连接到 Docker Hub
- **错误**: `failed to fetch oauth token: Post "https://auth.docker.io/token": dial tcp 108.160.161.83:443: i/o timeout`
- **表现**: 即使获取到认证 token，拉取镜像元数据仍然超时

### 3. 尝试解决方案

#### 方案 A: 配置 Buildx Builder 代理
```bash
docker buildx create --name multiarch-proxy \
  --driver docker-container \
  --driver-opt "env.HTTP_PROXY=http://host.docker.internal:53785" \
  --driver-opt "env.HTTPS_PROXY=http://host.docker.internal:53785" \
  --use
```
**结果**: ❌ 失败  
**原因**: Buildkit 在获取 Docker Hub OAuth token 时不使用 HTTP_PROXY

#### 方案 B: 使用 network=host 模式
```bash
docker buildx create --name multiarch-builder-host \
  --driver docker-container \
  --driver-opt "network=host" \
  --driver-opt "env.HTTP_PROXY=http://127.0.0.1:53785" \
  --use
```
**结果**: ❌ 失败  
**原因**: 容器内 127.0.0.1 无法访问主机的代理服务

#### 方案 C: 预拉取基础镜像
```bash
docker pull --platform linux/amd64 node:20-alpine
docker pull --platform linux/arm64 node:20-alpine
docker pull --platform linux/amd64 nginx:stable-alpine
docker pull --platform linux/arm64 nginx:stable-alpine
```
**结果**: ❌ 部分成功  
**说明**: 本地可以成功拉取镜像（使用系统代理），但 buildx 仍然尝试重新获取元数据并超时

#### 方案 D: 使用标准 docker build
```bash
docker build --platform linux/arm64 \
  --file Dockerfile.allinone.v2 \
  --tag rocky8848/puked-web-allinone:2.4.7-arm64 .
```
**结果**: ✅ 成功（ARM64）  
**说明**: 构建本地架构（ARM64）的镜像成功，但跨平台构建（AMD64）仍然失败

## 根本原因分析

### Buildkit 代理问题
Docker Buildkit 在以下场景中**不会**使用 HTTP_PROXY 环境变量：
1. 向 Docker Hub 认证服务器 (auth.docker.io) 请求 OAuth token
2. 解析镜像元数据 (registry-1.docker.io/v2/...)

即使设置了 `HTTP_PROXY` 和 `HTTPS_PROXY`，Buildkit 的底层网络库仍会尝试直接连接，导致在需要代理的网络环境中超时。

### 跨平台构建限制
在 ARM64 Mac 上构建 AMD64 镜像时：
1. Docker 需要使用 QEMU 进行模拟
2. 模拟环境中的网络请求更容易超时
3. 即使基础镜像在本地缓存，Buildkit 仍会尝试验证远程元数据

## 最终解决方案

采用**单架构构建 + 手动推送**的方式：

```bash
# 1. 构建 ARM64 镜像（本地架构）
docker build --platform linux/arm64 \
  --file Dockerfile.allinone.v2 \
  --tag rocky8848/puked-web-allinone:2.4.7-arm64 .

# 2. 推送 ARM64 镜像
docker push rocky8848/puked-web-allinone:2.4.7-arm64

# 3. 标记为主版本
docker tag rocky8848/puked-web-allinone:2.4.7-arm64 rocky8848/puked-web-allinone:2.4.7
docker tag rocky8848/puked-web-allinone:2.4.7-arm64 rocky8848/puked-web-allinone:latest

# 4. 推送主版本标签
docker push rocky8848/puked-web-allinone:2.4.7
docker push rocky8848/puked-web-allinone:latest
```

**状态**: ✅ 成功  
**限制**: 镜像只支持 ARM64 架构

## 建议的后续方案

### 方案 1: 使用 CI/CD 平台
在 GitHub Actions、GitLab CI 或其他云 CI/CD 平台上构建：
- ✅ 这些平台通常有良好的网络连接
- ✅ 可以原生支持多架构构建
- ✅ 可以避免本地网络限制

### 方案 2: 使用 Docker Hub 自动构建
- 配置 Docker Hub 的 Automated Builds
- 直接从 Git 仓库触发构建
- Docker Hub 服务器有良好的网络环境

### 方案 3: 在 x86_64 机器上构建 AMD64 版本
- 在 x86_64 Linux 服务器上单独构建 AMD64 镜像
- 推送到 Docker Hub
- 使用 `docker manifest` 创建多架构清单：

```bash
# 创建 manifest
docker manifest create rocky8848/puked-web-allinone:2.4.7 \
  rocky8848/puked-web-allinone:2.4.7-arm64 \
  rocky8848/puked-web-allinone:2.4.7-amd64

# 推送 manifest
docker manifest push rocky8848/puked-web-allinone:2.4.7
```

### 方案 4: 配置 Docker Daemon 代理
编辑 Docker Desktop 设置或 `/etc/docker/daemon.json`：

```json
{
  "registry-mirrors": ["https://mirror.example.com"],
  "proxies": {
    "default": {
      "httpProxy": "http://127.0.0.1:53785",
      "httpsProxy": "http://127.0.0.1:53785",
      "noProxy": "localhost,127.0.0.1"
    }
  }
}
```

**注意**: 此方案需要重启 Docker Desktop，可能影响其他容器。

## 技术细节

### ClashX 配置
- HTTP 代理端口: 0 (未使用)
- Socks5 代理端口: 0 (未使用)
- 混合代理端口: **53785**
- 设置为系统代理: ✅ 已启用

### Docker Buildx 配置
```bash
# 查看当前 builders
docker buildx ls

# 查看 builder 详情
docker buildx inspect multiarch-proxy-v2

# Builder 环境变量（已配置但无效）
Driver Options: 
  env.HTTPS_PROXY="http://host.docker.internal:53785" 
  env.HTTP_PROXY="http://host.docker.internal:53785"
```

### 测试命令
```bash
# 测试主机代理连通性
curl -x http://127.0.0.1:53785 https://registry-1.docker.io/v2/
# ✅ 成功

# 测试 builder 容器网络
docker exec buildx_buildkit_multiarch-proxy-v20 \
  wget -q -O- --timeout=10 https://registry-1.docker.io/v2/
# ✅ 成功（返回 401 Unauthorized，但网络通）

# 实际 buildx 构建
docker buildx build --platform linux/amd64,linux/arm64 ...
# ❌ 失败（OAuth token 请求超时）
```

## 结论

当前在网络受限环境中使用 Docker Buildx 进行多架构构建存在技术限制。BuildKit 的网络实现没有完全遵守 HTTP_PROXY 环境变量，特别是在与 Docker Hub 认证服务交互时。

**推荐做法**:
1. 短期：使用单架构镜像（ARM64）
2. 中期：在云 CI/CD 平台上构建多架构镜像
3. 长期：等待 BuildKit 改进代理支持，或使用私有 Registry

## 参考资料

- Docker Buildx 文档: https://docs.docker.com/buildx/working-with-buildx/
- BuildKit 代理问题: https://github.com/moby/buildkit/issues/2424
- Docker manifest 命令: https://docs.docker.com/engine/reference/commandline/manifest/
