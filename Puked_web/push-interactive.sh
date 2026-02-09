#!/bin/bash
# ============================================
# Puked Web 2.4.2 推送到 Docker Hub（交互式）
# ============================================

set -e

VERSION="2.4.2"
DOCKER_USER="rocky8848"
IMAGE_NAME="puked-web"
FULL_IMAGE="${DOCKER_USER}/${IMAGE_NAME}"

echo "=========================================="
echo "🚀 Puked Web ${VERSION} 推送到 Docker Hub"
echo "=========================================="
echo ""

# ==================== 1. Docker 登录 ====================
echo "🔐 步骤 1: Docker Hub 登录"
echo ""
echo "请确保已经登录 Docker Hub。"
echo "如果还未登录，请运行: docker login"
echo ""

read -p "是否已登录 Docker Hub? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "📝 请先登录 Docker Hub："
    docker login
    
    if [ $? -ne 0 ]; then
        echo "❌ 登录失败！"
        exit 1
    fi
fi

# 验证登录
if ! docker info 2>&1 | grep -q "Username"; then
    echo "❌ 未检测到 Docker 登录状态"
    echo "请运行: docker login"
    exit 1
fi

echo "✅ Docker 登录状态正常"
echo ""

# ==================== 2. 检查 Buildx ====================
echo "🔍 步骤 2: 检查 Docker Buildx..."

if ! docker buildx version &> /dev/null; then
    echo "❌ Docker Buildx 未安装！"
    exit 1
fi

echo "✅ Docker Buildx 已安装"
echo ""

# ==================== 3. 创建构建器 ====================
echo "🔧 步骤 3: 配置 Buildx 构建器..."

BUILDER_NAME="puked-multiarch-builder"

if docker buildx ls | grep -q "$BUILDER_NAME"; then
    echo "ℹ️  使用现有构建器: $BUILDER_NAME"
    docker buildx use "$BUILDER_NAME"
else
    echo "📦 创建新构建器: $BUILDER_NAME"
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
    docker buildx use "$BUILDER_NAME"
fi

echo "✅ 构建器就绪"
echo ""

# ==================== 4. 确认推送 ====================
echo "📋 准备推送信息："
echo "   用户名: ${DOCKER_USER}"
echo "   仓库: ${FULL_IMAGE}"
echo "   版本: ${VERSION}, latest"
echo "   架构: linux/amd64, linux/arm64"
echo ""

read -p "确认开始构建并推送? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 已取消"
    exit 0
fi

# ==================== 5. 构建并推送 ====================
echo ""
echo "🔨 步骤 4: 构建并推送多架构镜像..."
echo ""

cd /Users/maxliu/Documents/PukedMaster/Puked_web

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag "${FULL_IMAGE}:${VERSION}" \
  --tag "${FULL_IMAGE}:latest" \
  --file Dockerfile.allinone \
  --push \
  --progress=plain \
  .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 镜像推送成功！"
else
    echo ""
    echo "❌ 镜像推送失败！"
    exit 1
fi

# ==================== 6. 完成 ====================
echo ""
echo "=========================================="
echo "✅ 推送完成！"
echo "=========================================="
echo ""
echo "📦 镜像已发布："
echo "   https://hub.docker.com/r/${DOCKER_USER}/${IMAGE_NAME}"
echo ""
echo "🚀 使用方法："
echo "   docker pull ${FULL_IMAGE}:${VERSION}"
echo ""
echo "   docker run -d --name puked-web -p 3001:80 \\"
echo "     -e PB_URL=https://pb.osglab.com \\"
echo "     -e ADMIN_EMAIL=rocky.hk@gmail.com \\"
echo "     -e ADMIN_PASSWORD=your_password \\"
echo "     --restart unless-stopped \\"
echo "     ${FULL_IMAGE}:${VERSION}"
echo ""
