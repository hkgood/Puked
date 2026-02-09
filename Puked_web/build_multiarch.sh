#!/bin/bash
# ============================================
# 多架构镜像构建脚本
# 支持 linux/amd64 和 linux/arm64
# ============================================

set -e

VERSION="2.4.6"
DOCKER_USER="rocky8848"
IMAGE_NAME="puked-web"
FULL_IMAGE="${DOCKER_USER}/${IMAGE_NAME}"

echo "=========================================="
echo "🔨 多架构镜像构建 (amd64 + arm64)"
echo "=========================================="

# 1. 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker 未运行，请先启动 Docker Desktop"
    exit 1
fi

# 2. 检查登录状态
if ! docker info 2>&1 | grep -q "Username: ${DOCKER_USER}"; then
    echo "📝 请先登录 Docker Hub..."
    docker login
fi

# 3. 创建/使用多架构构建器
BUILDER_NAME="puked-multiarch"

if docker buildx ls | grep -q "$BUILDER_NAME"; then
    echo "✅ 使用现有构建器: $BUILDER_NAME"
    docker buildx use "$BUILDER_NAME"
else
    echo "📦 创建多架构构建器: $BUILDER_NAME"
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap --use
fi

# 4. 验证构建器
echo ""
echo "🔍 验证构建器支持的平台..."
docker buildx inspect "$BUILDER_NAME" | grep "Platforms:"

# 5. 构建并推送多架构镜像
echo ""
echo "🚀 开始构建多架构镜像..."
echo "   平台: linux/amd64, linux/arm64"
echo "   标签: ${FULL_IMAGE}:${VERSION}, ${FULL_IMAGE}:latest"
echo ""

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --file Dockerfile.allinone.v2 \
  --tag "${FULL_IMAGE}:${VERSION}" \
  --tag "${FULL_IMAGE}:latest" \
  --push \
  .

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ 多架构镜像构建并推送成功！"
    echo "=========================================="
    echo ""
    echo "📦 镜像信息："
    echo "   仓库: https://hub.docker.com/r/${DOCKER_USER}/${IMAGE_NAME}"
    echo "   版本: ${VERSION}"
    echo "   架构: linux/amd64, linux/arm64"
    echo ""
    echo "🚀 使用方法："
    echo "   docker pull ${FULL_IMAGE}:${VERSION}"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "❌ 构建失败！"
    echo "=========================================="
    echo ""
    echo "可能的原因："
    echo "  1. Docker Hub 网络连接问题"
    echo "  2. 未登录 Docker Hub"
    echo "  3. 基础镜像拉取失败"
    echo ""
    echo "解决方案："
    echo "  1. 检查网络连接"
    echo "  2. 配置 Docker 镜像加速器（Docker Desktop -> Settings -> Docker Engine）"
    echo "  3. 使用代理（Docker Desktop -> Settings -> Resources -> Proxies）"
    echo "  4. 重试: bash build_multiarch.sh"
    echo ""
    exit 1
fi
