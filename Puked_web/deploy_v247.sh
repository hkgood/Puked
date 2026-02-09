#!/bin/bash

# Puked Web v2.4.7 部署脚本

set -e

echo "=================================================="
echo "  Puked Web v2.4.7 快速部署"
echo "=================================================="
echo ""

IMAGE="rocky8848/puked-web-allinone:2.4.7"
CONTAINER_NAME="puked-web"
PORT="8080"

# 停止并删除旧容器（如果存在）
if docker ps -a | grep -q $CONTAINER_NAME; then
    echo "🗑️  停止并删除旧容器..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
fi

# 拉取最新镜像
echo "📦 拉取镜像: $IMAGE"
docker pull $IMAGE

# 启动新容器
echo "🚀 启动容器..."
docker run -d \
    -p $PORT:80 \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    $IMAGE

# 等待容器启动
echo "⏳ 等待服务启动..."
sleep 5

# 检查容器状态
if docker ps | grep -q $CONTAINER_NAME; then
    echo ""
    echo "✅ 部署成功！"
    echo ""
    echo "=================================================="
    echo "  访问信息"
    echo "=================================================="
    echo "  Web 应用: http://localhost:$PORT"
    echo "  容器名称: $CONTAINER_NAME"
    echo ""
    echo "=================================================="
    echo "  常用命令"
    echo "=================================================="
    echo "  查看日志: docker logs -f $CONTAINER_NAME"
    echo "  查看状态: docker exec $CONTAINER_NAME supervisorctl status"
    echo "  重启服务: docker restart $CONTAINER_NAME"
    echo "  停止服务: docker stop $CONTAINER_NAME"
    echo ""
    
    # 显示服务状态
    echo "=================================================="
    echo "  服务状态"
    echo "=================================================="
    docker exec $CONTAINER_NAME supervisorctl status
    echo ""
else
    echo ""
    echo "❌ 部署失败！请检查日志："
    echo "   docker logs $CONTAINER_NAME"
    exit 1
fi
