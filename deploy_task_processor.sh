#!/bin/bash
# ============================================
# 任务处理器快速部署脚本
# ============================================

set -e  # 遇到错误立即退出

echo "=========================================="
echo "🔄 Puked 任务处理器部署脚本"
echo "=========================================="

# 配置
PB_URL="https://pb.osglab.com"
ADMIN_EMAIL="rocky.hk@gmail.com"
ADMIN_PASSWORD="gz203799"

# ========== 1. 停止现有容器 ==========
echo ""
echo "🛑 1. 停止现有容器..."
if docker ps -a | grep -q puked-task-processor; then
    docker stop puked-task-processor 2>/dev/null || true
    docker rm puked-task-processor 2>/dev/null || true
    echo "✅ 旧容器已删除"
else
    echo "ℹ️  没有现有容器"
fi

# ========== 2. 删除旧镜像 ==========
echo ""
echo "🗑️  2. 删除旧镜像..."
if docker images | grep -q "puked-task-processor"; then
    docker rmi puked-task-processor:latest 2>/dev/null || true
    echo "✅ 旧镜像已删除"
else
    echo "ℹ️  没有旧镜像"
fi

# ========== 3. 构建新镜像 ==========
echo ""
echo "🔨 3. 构建新镜像..."
cd /Users/maxliu/Documents/PukedMaster/Puked_web/scripts

if docker build -f Dockerfile.task-processor -t puked-task-processor:latest .; then
    echo "✅ 镜像构建成功"
else
    echo "❌ 镜像构建失败！"
    exit 1
fi

# ========== 4. 启动新容器 ==========
echo ""
echo "🚀 4. 启动新容器..."
if docker run -d \
    --name puked-task-processor \
    --restart unless-stopped \
    -e NODE_ENV=production \
    -e PB_URL="$PB_URL" \
    -e ADMIN_EMAIL="$ADMIN_EMAIL" \
    -e ADMIN_PASSWORD="$ADMIN_PASSWORD" \
    -e CHECK_INTERVAL=10000 \
    -e BATCH_SIZE=10 \
    -e CONCURRENCY=3 \
    puked-task-processor:latest; then
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
if docker ps | grep -q puked-task-processor; then
    echo "✅ 容器运行正常"
else
    echo "❌ 容器未运行！"
    docker logs puked-task-processor
    exit 1
fi

# ========== 7. 完成 ==========
echo ""
echo "=========================================="
echo "✅ 部署完成！"
echo "=========================================="
echo ""
echo "📋 部署信息："
echo "   容器名称：puked-task-processor"
echo "   PocketBase：$PB_URL"
echo "   检查间隔：10 秒"
echo "   批次大小：10 个行程/批次"
echo "   并发数：3"
echo ""
echo "📝 下一步："
echo "   1. 查看日志确认正常运行"
echo "   2. 打开 Web 应用点击统计按钮"
echo "   3. 观察任务从 pending → running → success"
echo ""
echo "🔍 查看日志（Ctrl+C 退出）："
echo "   docker logs -f puked-task-processor"
echo ""
echo "🔍 查看容器状态："
echo "   docker ps | grep task-processor"
echo ""

# 显示最近的日志
echo "📋 最近日志（自动显示 30 秒）："
timeout 30 docker logs -f puked-task-processor 2>/dev/null || docker logs --tail 50 puked-task-processor
