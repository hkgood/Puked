#!/bin/bash
# ============================================
# 多架构镜像构建 - 使用 Daemon 缓存（第一性原理方案）
# 原理：docker driver 使用 daemon 的镜像缓存，无需 buildkit 容器访问外网
# 支持：linux/amd64 + linux/arm64
# ============================================

set -e

VERSION="2.4.7"
DOCKER_USER="rocky8848"
IMAGE_NAME="puked-web-allinone"
FULL_IMAGE="${DOCKER_USER}/${IMAGE_NAME}"
DOCKERFILE="Dockerfile.allinone.v2"

echo "=========================================="
echo "🔨 多架构构建 (daemon 缓存方案)"
echo "   原理: docker driver = 使用本地镜像缓存，不经过 buildkit 容器拉取"
echo "=========================================="

# 1. 检查 Docker
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker 未运行"
    exit 1
fi

# 2. 检查登录
if ! docker info 2>&1 | grep -q "Username"; then
    echo "📝 请先登录: docker login"
    docker login
fi

# 3. 预拉取基础镜像到 daemon 缓存（避免构建时访问外网）
echo ""
echo "📥 Step 1: 预拉取基础镜像到 daemon（两平台）..."
for plat in linux/amd64 linux/arm64; do
    echo "   拉取 node:20-alpine ($plat)"
    docker pull --platform "$plat" node:20-alpine
    echo "   拉取 nginx:stable-alpine ($plat)"
    docker pull --platform "$plat" nginx:stable-alpine
done
echo "   ✅ 基础镜像已在 daemon 缓存"
echo ""

# 4. 使用当前 builder（先预拉取可减少构建时外网请求，任一 builder 均可）
echo "📦 使用当前 buildx builder..."
if docker buildx ls | grep -q 'puked-multiarch'; then
    docker buildx use puked-multiarch 2>/dev/null || true
elif docker buildx ls | grep -q 'multiarch-proxy'; then
    docker buildx use multiarch-proxy-v2 2>/dev/null || true
fi
echo ""

# 5. 分别构建两平台并 load 到 daemon（单平台构建，走 daemon 缓存）
echo "🔨 Step 2: 构建 linux/amd64..."
docker buildx build \
  --platform linux/amd64 \
  --file "$DOCKERFILE" \
  --tag "${FULL_IMAGE}:${VERSION}-amd64" \
  --load \
  .

echo ""
echo "🔨 Step 3: 构建 linux/arm64..."
docker buildx build \
  --platform linux/arm64 \
  --file "$DOCKERFILE" \
  --tag "${FULL_IMAGE}:${VERSION}-arm64" \
  --load \
  .

echo ""
echo "📤 Step 4: 推送两个架构镜像..."
docker push "${FULL_IMAGE}:${VERSION}-amd64"
docker push "${FULL_IMAGE}:${VERSION}-arm64"

echo ""
echo "📋 Step 5: 创建并推送多架构 manifest..."
docker manifest rm "${FULL_IMAGE}:${VERSION}" 2>/dev/null || true
docker manifest create "${FULL_IMAGE}:${VERSION}" \
  "${FULL_IMAGE}:${VERSION}-amd64" \
  "${FULL_IMAGE}:${VERSION}-arm64"
docker manifest push "${FULL_IMAGE}:${VERSION}"

docker manifest rm "${FULL_IMAGE}:latest" 2>/dev/null || true
docker manifest create "${FULL_IMAGE}:latest" \
  "${FULL_IMAGE}:${VERSION}-amd64" \
  "${FULL_IMAGE}:${VERSION}-arm64"
docker manifest push "${FULL_IMAGE}:latest"

echo ""
echo "=========================================="
echo "✅ 多架构镜像构建并推送完成"
echo "=========================================="
echo "   镜像: ${FULL_IMAGE}:${VERSION} 与 ${FULL_IMAGE}:latest"
echo "   架构: linux/amd64, linux/arm64"
echo "   验证: docker buildx imagetools inspect ${FULL_IMAGE}:${VERSION}"
echo ""
