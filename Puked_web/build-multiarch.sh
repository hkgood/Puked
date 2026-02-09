#!/bin/bash
# ============================================
# Puked Web 2.4.2 多架构镜像构建脚本
# 支持：x86_64 (amd64) + ARM64 (arm64/v8)
# ============================================

set -e

VERSION="2.4.2"
IMAGE_NAME="puked-web"
REGISTRY="docker.io"  # 或改为你的私有仓库
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}"

echo "=========================================="
echo "🚀 Puked Web ${VERSION} 多架构镜像构建"
echo "=========================================="

# ==================== 1. 检查 Docker Buildx ====================
echo ""
echo "🔍 1. 检查 Docker Buildx..."

if ! docker buildx version &> /dev/null; then
    echo "❌ Docker Buildx 未安装！"
    echo "请运行：docker buildx install"
    exit 1
fi

echo "✅ Docker Buildx 已安装"

# ==================== 2. 创建/使用 Buildx 构建器 ====================
echo ""
echo "🔧 2. 配置 Buildx 构建器..."

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

# ==================== 3. 检查构建器状态 ====================
echo ""
echo "🔍 3. 检查构建器状态..."
docker buildx inspect --bootstrap

# ==================== 4. 构建多架构镜像 ====================
echo ""
echo "🔨 4. 开始构建多架构镜像..."
echo "   架构：linux/amd64, linux/arm64"
echo "   镜像：${FULL_IMAGE}:${VERSION}"
echo ""

cd /Users/maxliu/Documents/PukedMaster/Puked_web

# 构建并推送（如果需要推送到仓库）
# 使用 --push 会推送到仓库
# 使用 --load 会加载到本地 Docker（但只支持单架构）
# 使用 --output type=docker,dest=- 会导出为 tar 文件

# 选项 A：构建并推送到 Docker Hub（需要登录）
# docker buildx build \
#   --platform linux/amd64,linux/arm64 \
#   --tag "${FULL_IMAGE}:${VERSION}" \
#   --tag "${FULL_IMAGE}:latest" \
#   --file Dockerfile.allinone \
#   --push \
#   .

# 选项 B：构建并导出为本地文件（推荐）
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag "${IMAGE_NAME}:${VERSION}" \
  --tag "${IMAGE_NAME}:latest" \
  --file Dockerfile.allinone \
  --output type=docker,dest=puked-web-${VERSION}-multiarch.tar \
  .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 镜像构建成功！"
else
    echo ""
    echo "❌ 镜像构建失败！"
    exit 1
fi

# ==================== 5. 查看构建结果 ====================
echo ""
echo "=========================================="
echo "✅ 构建完成！"
echo "=========================================="
echo ""
echo "📦 镜像信息："
echo "   名称：${IMAGE_NAME}"
echo "   版本：${VERSION}"
echo "   架构：linux/amd64, linux/arm64"
echo ""

if [ -f "puked-web-${VERSION}-multiarch.tar" ]; then
    FILE_SIZE=$(du -h "puked-web-${VERSION}-multiarch.tar" | cut -f1)
    echo "📁 导出文件："
    echo "   文件：puked-web-${VERSION}-multiarch.tar"
    echo "   大小：${FILE_SIZE}"
    echo ""
    echo "📋 加载镜像到 Docker："
    echo "   docker load < puked-web-${VERSION}-multiarch.tar"
    echo ""
fi

echo "🚀 运行镜像："
echo "   docker run -d \\"
echo "     --name puked-web \\"
echo "     -p 3001:80 \\"
echo "     -e PB_URL=https://pb.osglab.com \\"
echo "     -e ADMIN_EMAIL=rocky.hk@gmail.com \\"
echo "     -e ADMIN_PASSWORD=your_password \\"
echo "     --restart unless-stopped \\"
echo "     ${IMAGE_NAME}:${VERSION}"
echo ""
echo "🔍 查看日志："
echo "   docker logs -f puked-web"
echo ""
echo "📊 查看进程："
echo "   docker exec puked-web supervisorctl status"
echo ""
