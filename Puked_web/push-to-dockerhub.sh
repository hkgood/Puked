#!/bin/bash
# ============================================
# Puked Web 2.4.2 推送到 Docker Hub
# 仓库：rocky8848/puked-web
# 支持：x86_64 (amd64) + ARM64 (arm64)
# ============================================

set -e

VERSION="2.4.2"
DOCKER_USER="rocky8848"
IMAGE_NAME="puked-web"
FULL_IMAGE="${DOCKER_USER}/${IMAGE_NAME}"

echo "=========================================="
echo "🚀 Puked Web ${VERSION} 推送到 Docker Hub"
echo "=========================================="

# ==================== 1. 检查 Docker 登录状态 ====================
echo ""
echo "🔍 1. 检查 Docker 登录状态..."

if ! docker info 2>&1 | grep -q "Username: ${DOCKER_USER}"; then
    echo "⚠️  未登录或登录用户不匹配"
    echo "📝 请先登录 Docker Hub："
    echo ""
    docker login
    echo ""
else
    echo "✅ 已登录 Docker Hub (${DOCKER_USER})"
fi

# ==================== 2. 检查 Docker Buildx ====================
echo ""
echo "🔍 2. 检查 Docker Buildx..."

if ! docker buildx version &> /dev/null; then
    echo "❌ Docker Buildx 未安装！"
    echo "请运行：docker buildx install"
    exit 1
fi

echo "✅ Docker Buildx 已安装"

# ==================== 3. 创建/使用 Buildx 构建器 ====================
echo ""
echo "🔧 3. 配置 Buildx 构建器..."

BUILDER_NAME="puked-multiarch-builder"

if docker buildx ls | grep -q "$BUILDER_NAME"; then
    echo "ℹ️  构建器 $BUILDER_NAME 已存在"
    docker buildx use "$BUILDER_NAME"
else
    echo "📦 创建新的构建器 $BUILDER_NAME..."
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
    docker buildx use "$BUILDER_NAME"
fi

echo "✅ 构建器已就绪"

# ==================== 4. 检查构建器状态 ====================
echo ""
echo "🔍 4. 检查构建器状态..."
docker buildx inspect --bootstrap

# ==================== 5. 构建并推送多架构镜像 ====================
echo ""
echo "🔨 5. 构建并推送多架构镜像到 Docker Hub..."
echo "   架构：linux/amd64, linux/arm64"
echo "   仓库：${FULL_IMAGE}"
echo "   版本：${VERSION}, latest"
echo ""

cd /Users/maxliu/Documents/PukedMaster/Puked_web

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag "${FULL_IMAGE}:${VERSION}" \
  --tag "${FULL_IMAGE}:latest" \
  --file Dockerfile.allinone \
  --push \
  .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 镜像推送成功！"
else
    echo ""
    echo "❌ 镜像推送失败！"
    exit 1
fi

# ==================== 6. 验证推送结果 ====================
echo ""
echo "🔍 6. 验证推送结果..."

# 尝试拉取镜像验证
echo "正在验证镜像..."
if docker pull "${FULL_IMAGE}:${VERSION}" &> /dev/null; then
    echo "✅ 镜像可以正常拉取"
else
    echo "⚠️  无法拉取镜像，可能需要等待几秒钟"
fi

# ==================== 7. 完成 ====================
echo ""
echo "=========================================="
echo "✅ 推送完成！"
echo "=========================================="
echo ""
echo "📦 镜像信息："
echo "   仓库：https://hub.docker.com/r/${DOCKER_USER}/${IMAGE_NAME}"
echo "   版本：${VERSION}, latest"
echo "   架构：linux/amd64, linux/arm64"
echo ""
echo "🚀 在任何服务器上使用："
echo ""
echo "   # 拉取镜像"
echo "   docker pull ${FULL_IMAGE}:${VERSION}"
echo ""
echo "   # 运行容器"
echo "   docker run -d \\"
echo "     --name puked-web \\"
echo "     -p 3001:80 \\"
echo "     -e PB_URL=https://pb.osglab.com \\"
echo "     -e ADMIN_EMAIL=rocky.hk@gmail.com \\"
echo "     -e ADMIN_PASSWORD=your_password \\"
echo "     --restart unless-stopped \\"
echo "     ${FULL_IMAGE}:${VERSION}"
echo ""
echo "📊 镜像标签："
echo "   ${FULL_IMAGE}:${VERSION}"
echo "   ${FULL_IMAGE}:latest"
echo ""
