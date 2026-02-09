#!/bin/bash

# 设置变量
IMAGE_NAME="rocky8848/puked-web"
TAG="2.4.4"
BUILDER_NAME="puke-builder"

echo "🚀 重新开始：构建一体化多架构镜像 (amd64 & arm64) - 包含前端 + 后台任务..."
echo "🌐 依赖系统全局代理配置..."

# 1. 切换到工作目录
cd "$(dirname "$0")"

# 2. 清理并重新创建构建器
if docker buildx ls | grep -q "$BUILDER_NAME"; then
    echo "♻️  正在清理旧的构建器..."
    docker buildx rm "$BUILDER_NAME"
fi

# 3. 创建多架构构建器 (使用默认网络配置)
echo "🛠  正在创建多架构构建器..."
docker buildx create --name "$BUILDER_NAME" --driver docker-container --use

# 4. 初始化构建器
echo "🏗  正在初始化构建器..."
docker buildx inspect --bootstrap

# 5. 执行构建与推送
echo "📦 正在构建并推送 (amd64 + arm64) - 使用 Dockerfile.allinone..."
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f Dockerfile.allinone \
  -t "$IMAGE_NAME:$TAG" \
  -t "$IMAGE_NAME:latest" \
  --push \
  --progress=plain .

if [ $? -eq 0 ]; then
    echo "✅ 构建并推送成功！"
    echo "💡 镜像版本: $TAG (支持 x86 & ARM)"
else
    echo "❌ 构建过程失败。"
fi
