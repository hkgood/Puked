#!/bin/bash
# ============================================
# Puked 任务处理器诊断脚本
# ============================================

set -e

echo "=========================================="
echo "🔍 Puked 任务处理器诊断工具"
echo "=========================================="

# 1. 检查容器是否运行
echo ""
echo "📋 1. 检查容器状态..."
if docker ps | grep -q puked-web; then
    echo "✅ 容器正在运行"
    CONTAINER_NAME="puked-web"
elif docker ps | grep -q puked-task-processor; then
    echo "✅ 独立任务处理器容器正在运行"
    CONTAINER_NAME="puked-task-processor"
else
    echo "❌ 未找到运行中的 Puked 容器！"
    echo ""
    echo "请先启动容器："
    echo "  docker-compose up -d"
    echo "  或"
    echo "  bash Puked_web/build_and_deploy.sh"
    exit 1
fi

# 2. 检查容器内进程
echo ""
echo "📋 2. 检查容器内进程..."
echo "正在运行的进程："
docker exec $CONTAINER_NAME ps aux || echo "⚠️  无法获取进程列表"

# 3. 检查 task_processor 是否在运行
echo ""
echo "📋 3. 检查 task_processor.pb.js 是否在运行..."
if docker exec $CONTAINER_NAME ps aux | grep -q "task_processor.pb.js"; then
    echo "✅ task_processor.pb.js 正在运行"
else
    echo "❌ task_processor.pb.js 未运行！"
fi

# 4. 检查环境变量
echo ""
echo "📋 4. 检查环境变量..."
echo "PB_URL:"
docker exec $CONTAINER_NAME printenv PB_URL || echo "❌ PB_URL 未设置"
echo "ADMIN_EMAIL:"
docker exec $CONTAINER_NAME printenv ADMIN_EMAIL || echo "❌ ADMIN_EMAIL 未设置"
echo "ADMIN_PASSWORD:"
if docker exec $CONTAINER_NAME printenv ADMIN_PASSWORD > /dev/null 2>&1; then
    echo "✅ ADMIN_PASSWORD 已设置 (不显示明文)"
else
    echo "❌ ADMIN_PASSWORD 未设置"
fi

# 5. 查看最近的日志
echo ""
echo "📋 5. 任务处理器日志（最近 50 行）..."
echo "----------------------------------------"
docker exec $CONTAINER_NAME cat /var/log/supervisor/task_processor.log 2>/dev/null | tail -n 50 || \
    docker logs $CONTAINER_NAME 2>&1 | grep -i "task\|processor\|engine" | tail -n 50 || \
    echo "⚠️  无法获取日志"
echo "----------------------------------------"

# 6. 查看错误日志
echo ""
echo "📋 6. 任务处理器错误日志（最近 30 行）..."
echo "----------------------------------------"
docker exec $CONTAINER_NAME cat /var/log/supervisor/task_processor_error.log 2>/dev/null | tail -n 30 || \
    echo "⚠️  无错误日志或无法访问"
echo "----------------------------------------"

# 7. 检查 PocketBase 连接
echo ""
echo "📋 7. 测试 PocketBase 连接..."
PB_URL=$(docker exec $CONTAINER_NAME printenv PB_URL 2>/dev/null || echo "https://pb.osglab.com")
if curl -s -o /dev/null -w "%{http_code}" "$PB_URL/api/health" | grep -q "200"; then
    echo "✅ PocketBase ($PB_URL) 可访问"
else
    echo "⚠️  PocketBase ($PB_URL) 可能不可访问"
fi

# 8. 检查任务队列
echo ""
echo "📋 8. 检查 PocketBase 任务队列..."
echo "提示：手动检查 PocketBase 后台 sync_tasks 表"
echo "URL: https://pb.osglab.com/_/"

# 9. 提供修复建议
echo ""
echo "=========================================="
echo "🔧 修复建议"
echo "=========================================="
echo ""
echo "如果任务处理器未运行，可以尝试："
echo ""
echo "1. 重启容器："
echo "   docker restart $CONTAINER_NAME"
echo ""
echo "2. 手动启动任务处理器："
echo "   docker exec -it $CONTAINER_NAME /bin/sh"
echo "   cd /app/processor"
echo "   node task_processor.pb.js"
echo ""
echo "3. 查看 Supervisor 状态："
echo "   docker exec $CONTAINER_NAME supervisorctl status"
echo ""
echo "4. 重新构建并部署："
echo "   bash Puked_web/build_and_deploy.sh"
echo ""
echo "5. 查看实时日志："
echo "   docker logs -f $CONTAINER_NAME"
echo ""
