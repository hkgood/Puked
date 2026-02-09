#!/bin/bash
# ============================================
# Puked Web 2.4.2 一体化镜像快速构建部署
# ============================================

set -e

VERSION="2.4.6"
IMAGE_NAME="puked-web"
DOCKERFILE="Dockerfile.allinone"  # 可改为 Dockerfile.allinone.v2

echo "=========================================="
echo "🚀 Puked Web ${VERSION} 一体化部署"
echo "=========================================="

cd /Users/maxliu/Documents/PukedMaster/Puked_web

# ========== 1. 停止旧容器 ==========
echo ""
echo "🛑 1. 停止旧容器..."
docker stop puked-web 2>/dev/null || true
docker rm puked-web 2>/dev/null || true
echo "✅ 完成"

# ========== 2. 删除旧镜像 ==========
echo ""
echo "🗑️  2. 删除旧镜像..."
docker rmi ${IMAGE_NAME}:${VERSION} 2>/dev/null || true
docker rmi ${IMAGE_NAME}:latest 2>/dev/null || true
echo "✅ 完成"

# ========== 3. 构建新镜像（当前架构） ==========
echo ""
echo "🔨 3. 构建新镜像（单架构，快速）..."
echo "   架构：当前系统架构"
echo "   镜像：${IMAGE_NAME}:${VERSION}"
echo ""

docker build \
  --file ${DOCKERFILE} \
  --tag ${IMAGE_NAME}:${VERSION} \
  --tag ${IMAGE_NAME}:latest \
  --no-cache \
  .

if [ $? -eq 0 ]; then
    echo "✅ 镜像构建成功"
else
    echo "❌ 镜像构建失败！"
    exit 1
fi

# ========== 4. 启动新容器 ==========
echo ""
echo "🚀 4. 启动新容器..."

docker run -d \
  --name puked-web \
  -p 3001:80 \
  -e PB_URL=https://pb.osglab.com \
  -e ADMIN_EMAIL=rocky.hk@gmail.com \
  -e ADMIN_PASSWORD=gz203799 \
  -e CHECK_INTERVAL=10000 \
  -e BATCH_SIZE=10 \
  -e CONCURRENCY=3 \
  --restart unless-stopped \
  ${IMAGE_NAME}:${VERSION}

if [ $? -eq 0 ]; then
    echo "✅ 容器启动成功"
else
    echo "❌ 容器启动失败！"
    exit 1
fi

# ========== 5. 等待容器启动 ==========
echo ""
echo "⏳ 5. 等待容器启动..."
sleep 5

# ========== 6. 验证部署 ==========
echo ""
echo "✅ 6. 验证部署..."

# 检查容器状态
if docker ps | grep -q puked-web; then
    echo "✅ 容器运行正常"
else
    echo "❌ 容器未运行！"
    docker logs puked-web
    exit 1
fi

# 检查内部服务
echo ""
echo "🔍 检查内部服务..."
sleep 3
docker exec puked-web supervisorctl status

# ========== 7. 完成 ==========
echo ""
echo "=========================================="
echo "✅ 部署完成！"
echo "=========================================="
echo ""
echo "📋 部署信息："
echo "   镜像：${IMAGE_NAME}:${VERSION}"
echo "   容器：puked-web"
echo "   端口：3001:80"
echo "   版本：${VERSION}"
echo ""
echo "🔍 服务状态："
docker exec puked-web supervisorctl status
echo ""
echo "📝 下一步："
echo "   1. 清除浏览器缓存"
echo "   2. 访问 https://puked.osglab.com"
echo "   3. 点击统计按钮测试任务处理"
echo ""
echo "🔍 查看日志："
echo "   docker logs -f puked-web"
echo ""
echo "📊 查看任务处理器日志："
echo "   docker exec puked-web tail -f /var/log/supervisor/task_processor.log"
echo ""
