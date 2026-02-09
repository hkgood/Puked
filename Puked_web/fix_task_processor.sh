#!/bin/bash
# ============================================
# Puked 任务处理器快速修复脚本
# ============================================

set -e

echo "=========================================="
echo "🔧 Puked 任务处理器快速修复"
echo "=========================================="

# 配置
VERSION="2.4.6"
IMAGE_NAME="puked-web"
CONTAINER_NAME="puked-web"

# 1. 检查当前容器状态
echo ""
echo "📋 1. 检查当前容器状态..."
if docker ps -a | grep -q "$CONTAINER_NAME"; then
    echo "ℹ️  发现现有容器: $CONTAINER_NAME"
    
    echo ""
    echo "🛑 停止并删除旧容器..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    echo "✅ 旧容器已删除"
else
    echo "ℹ️  未发现现有容器"
fi

# 2. 删除旧镜像
echo ""
echo "🗑️  2. 删除旧镜像..."
docker rmi "${IMAGE_NAME}:${VERSION}" 2>/dev/null || true
docker rmi "${IMAGE_NAME}:latest" 2>/dev/null || true
echo "✅ 完成"

# 3. 构建新镜像（使用改进版 Dockerfile）
echo ""
echo "🔨 3. 构建新镜像（使用改进版配置）..."
cd "$(dirname "$0")"

# 检查是否使用新版 Dockerfile
if [ -f "Dockerfile.allinone.v2" ]; then
    DOCKERFILE="Dockerfile.allinone.v2"
    echo "✅ 使用改进版 Dockerfile: $DOCKERFILE"
else
    DOCKERFILE="Dockerfile.allinone"
    echo "⚠️  使用原版 Dockerfile: $DOCKERFILE"
fi

docker build \
  --file "$DOCKERFILE" \
  --tag "${IMAGE_NAME}:${VERSION}" \
  --tag "${IMAGE_NAME}:latest" \
  --no-cache \
  .

if [ $? -eq 0 ]; then
    echo "✅ 镜像构建成功"
else
    echo "❌ 镜像构建失败！"
    exit 1
fi

# 4. 启动新容器
echo ""
echo "🚀 4. 启动新容器..."

docker run -d \
  --name "$CONTAINER_NAME" \
  -p 3001:80 \
  -e PB_URL=https://pb.osglab.com \
  -e ADMIN_EMAIL=rocky.hk@gmail.com \
  -e ADMIN_PASSWORD=gz203799 \
  -e CHECK_INTERVAL=10000 \
  -e BATCH_SIZE=10 \
  -e CONCURRENCY=3 \
  --restart unless-stopped \
  "${IMAGE_NAME}:${VERSION}"

if [ $? -eq 0 ]; then
    echo "✅ 容器启动成功"
else
    echo "❌ 容器启动失败！"
    exit 1
fi

# 5. 等待容器启动
echo ""
echo "⏳ 5. 等待容器初始化..."
sleep 10

# 6. 验证部署
echo ""
echo "✅ 6. 验证部署..."

# 检查容器状态
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo "✅ 容器运行正常"
else
    echo "❌ 容器未运行！"
    exit 1
fi

# 检查 Supervisor 进程
echo ""
echo "📊 检查 Supervisor 状态..."
docker exec "$CONTAINER_NAME" supervisorctl status || echo "⚠️  无法获取 Supervisor 状态"

# 检查任务处理器进程
echo ""
echo "🔍 检查任务处理器进程..."
if docker exec "$CONTAINER_NAME" ps aux | grep -q "task_processor.pb.js"; then
    echo "✅ 任务处理器正在运行"
else
    echo "❌ 任务处理器未运行！"
    echo ""
    echo "查看任务处理器日志："
    docker exec "$CONTAINER_NAME" cat /var/log/supervisor/task_processor.log 2>/dev/null | tail -n 30
    echo ""
    echo "查看任务处理器错误日志："
    docker exec "$CONTAINER_NAME" cat /var/log/supervisor/task_processor_error.log 2>/dev/null | tail -n 30
fi

# 7. 提供访问信息
echo ""
echo "=========================================="
echo "✅ 修复完成！"
echo "=========================================="
echo ""
echo "📊 访问信息："
echo "   前端：http://localhost:3001"
echo "   PocketBase：https://pb.osglab.com"
echo ""
echo "🔍 查看日志："
echo "   实时日志：docker logs -f $CONTAINER_NAME"
echo "   任务处理器：docker exec $CONTAINER_NAME cat /var/log/supervisor/task_processor.log"
echo ""
echo "🔧 管理命令："
echo "   重启容器：docker restart $CONTAINER_NAME"
echo "   Supervisor 状态：docker exec $CONTAINER_NAME supervisorctl status"
echo "   手动重启任务处理器："
echo "     docker exec $CONTAINER_NAME supervisorctl restart task-processor"
echo ""
