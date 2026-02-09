#!/bin/bash
# ============================================
# Puked Web 2.4.4 紧急修复并重新部署
# 修复：Supervisor 配置问题
# ============================================

set -e

VERSION="2.4.4"
IMAGE_NAME="rocky8848/puked-web"

echo "=========================================="
echo "🚀 Puked Web ${VERSION} 紧急修复部署"
echo "=========================================="
echo ""
echo "修复内容："
echo "  ✅ 添加 supervisorctl 配置"
echo "  ✅ 添加 unix_http_server 配置"
echo "  ✅ 添加 rpcinterface 配置"
echo ""

cd /Users/maxliu/Documents/PukedMaster/Puked_web

# ==================== 1. 停止旧容器 ====================
echo "🛑 1. 停止旧容器..."
docker stop Puked 2>/dev/null || true
docker rm Puked 2>/dev/null || true
echo "✅ 完成"
echo ""

# ==================== 2. 删除旧镜像 ====================
echo "🗑️  2. 删除旧镜像..."
docker rmi ${IMAGE_NAME}:${VERSION} 2>/dev/null || true
docker rmi ${IMAGE_NAME}:latest 2>/dev/null || true
echo "✅ 完成"
echo ""

# ==================== 3. 构建新镜像 ====================
echo "🔨 3. 构建新镜像（${VERSION}）..."
echo ""

docker build \
  --file Dockerfile.allinone \
  --tag ${IMAGE_NAME}:${VERSION} \
  --tag ${IMAGE_NAME}:latest \
  --no-cache \
  .

if [ $? -ne 0 ]; then
    echo "❌ 镜像构建失败！"
    exit 1
fi

echo ""
echo "✅ 镜像构建成功"
echo ""

# ==================== 4. 启动新容器 ====================
echo "🚀 4. 启动新容器..."

docker run -d \
  --name Puked \
  -p 3001:80 \
  -e PB_URL=https://pb.osglab.com \
  -e ADMIN_EMAIL=rocky.hk@gmail.com \
  -e ADMIN_PASSWORD=gz203799 \
  -e CHECK_INTERVAL=10000 \
  -e BATCH_SIZE=10 \
  -e CONCURRENCY=3 \
  --restart unless-stopped \
  ${IMAGE_NAME}:${VERSION}

if [ $? -ne 0 ]; then
    echo "❌ 容器启动失败！"
    exit 1
fi

echo "✅ 容器启动成功"
echo ""

# ==================== 5. 等待容器启动 ====================
echo "⏳ 5. 等待容器启动（10秒）..."
sleep 10
echo "✅ 完成"
echo ""

# ==================== 6. 验证部署 ====================
echo "🔍 6. 验证部署..."
echo ""

# 检查容器状态
if docker ps | grep -q Puked; then
    echo "✅ 容器运行正常"
else
    echo "❌ 容器未运行！"
    docker logs Puked
    exit 1
fi

echo ""
echo "📋 进程状态："
docker exec Puked supervisorctl status || echo "⚠️  等待 supervisor 启动..."
echo ""

sleep 3

echo "📋 再次检查进程状态："
docker exec Puked supervisorctl status
echo ""

# ==================== 7. 显示日志 ====================
echo "📝 任务处理器日志（最后 20 行）："
docker exec Puked tail -20 /var/log/supervisor/task_processor.log 2>/dev/null || echo "⚠️  日志文件尚未创建，请稍等..."
echo ""

# ==================== 8. 完成 ====================
echo "=========================================="
echo "✅ 部署完成！"
echo "=========================================="
echo ""
echo "🔍 验证命令："
echo "   # 查看进程状态"
echo "   docker exec Puked supervisorctl status"
echo ""
echo "   # 查看任务处理器日志"
echo "   docker exec Puked tail -f /var/log/supervisor/task_processor.log"
echo ""
echo "   # 查看容器日志"
echo "   docker logs -f Puked"
echo ""
echo "🌐 访问 Web 界面："
echo "   https://puked.osglab.com"
echo ""
