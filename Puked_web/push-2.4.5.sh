#!/bin/bash
# ============================================
# Puked Web 2.4.5 推送到 Docker Hub
# 仓库：rocky8848/puked-web
# 支持：x86_64 (amd64) + ARM64 (arm64)
# ============================================

set -e

VERSION="2.4.5"
DOCKER_USER="rocky8848"
IMAGE_NAME="puked-web"
FULL_IMAGE="${DOCKER_USER}/${IMAGE_NAME}"

echo "=========================================="
echo "🚀 Puked Web ${VERSION} 构建并推送到 Docker Hub"
echo "=========================================="

# 1. 检查 Docker 登录状态
echo "🔍 1. 检查 Docker 登录状态..."
if ! docker info 2>&1 | grep -q "Username: ${DOCKER_USER}"; then
    echo "⚠️  未登录或登录用户不匹配，请确保已登录 ${DOCKER_USER}"
    # 如果在交互式环境下可以尝试 docker login，但在自动化脚本中可能失败
fi

# 2. 配置 Buildx 构建器
echo "🔧 2. 配置 Buildx 构建器..."
BUILDER_NAME="puked-multiarch-builder"
if ! docker buildx ls | grep -q "$BUILDER_NAME"; then
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
fi
docker buildx use "$BUILDER_NAME"

# 3. 构建并推送
echo "🔨 3. 构建并推送多架构镜像..."
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag "${FULL_IMAGE}:${VERSION}" \
  --tag "${FULL_IMAGE}:latest" \
  --file Dockerfile.allinone \
  --push \
  .

echo "=========================================="
echo "✅ 推送完成！版本: ${VERSION}"
echo "=========================================="
