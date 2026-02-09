#!/bin/bash

###############################################################################
# 任务处理器保活修复 - 快速部署脚本
# 
# 功能：
#   1. 构建最新的 Docker 镜像（多架构支持）
#   2. 推送到 Docker Hub
#   3. 在生产服务器上部署
#   4. 验证健康状态
###############################################################################

set -e  # 遇到错误立即退出

# 配置
IMAGE_NAME="rocky8848/puked-web"
VERSION="2.4.7"
DOCKERFILE="Dockerfile.allinone.v2"
CONTAINER_NAME="puked-web"

echo "========================================"
echo "🚀 Puked Web - 任务处理器保活修复部署"
echo "========================================"
echo "镜像: ${IMAGE_NAME}:${VERSION}"
echo "========================================"

# 1. 检查是否需要多架构构建
read -p "是否构建多架构镜像 (amd64 + arm64)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    MULTI_ARCH=true
else
    MULTI_ARCH=false
fi

# 2. 构建镜像
if [ "$MULTI_ARCH" = true ]; then
    echo "📦 正在构建多架构镜像..."
    
    # 确保 buildx builder 存在
    if ! docker buildx ls | grep -q "puked-builder"; then
        echo "创建 buildx builder..."
        docker buildx create --name puked-builder --use
    else
        echo "使用现有 buildx builder..."
        docker buildx use puked-builder
    fi
    
    # 构建并推送
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        -f ${DOCKERFILE} \
        -t ${IMAGE_NAME}:${VERSION} \
        -t ${IMAGE_NAME}:latest \
        --push \
        .
    
    echo "✅ 多架构镜像构建并推送成功"
else
    echo "📦 正在构建单架构镜像..."
    docker build -f ${DOCKERFILE} -t ${IMAGE_NAME}:${VERSION} .
    
    # 推送到 Docker Hub
    read -p "是否推送到 Docker Hub? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "📤 正在推送镜像..."
        docker push ${IMAGE_NAME}:${VERSION}
        docker tag ${IMAGE_NAME}:${VERSION} ${IMAGE_NAME}:latest
        docker push ${IMAGE_NAME}:latest
        echo "✅ 镜像推送成功"
    fi
fi

# 3. 本地测试（可选）
read -p "是否在本地测试镜像? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🧪 正在启动本地测试容器..."
    
    # 停止并删除旧的测试容器
    docker stop ${CONTAINER_NAME}-test 2>/dev/null || true
    docker rm ${CONTAINER_NAME}-test 2>/dev/null || true
    
    # 启动新容器
    docker run -d \
        --name ${CONTAINER_NAME}-test \
        -p 8080:80 \
        ${IMAGE_NAME}:${VERSION}
    
    echo "等待容器启动..."
    sleep 5
    
    # 检查容器状态
    echo ""
    echo "📊 容器状态:"
    docker ps | grep ${CONTAINER_NAME}-test
    
    echo ""
    echo "📋 Supervisor 进程状态:"
    docker exec ${CONTAINER_NAME}-test supervisorctl status
    
    echo ""
    echo "📄 任务处理器日志 (最新 20 行):"
    docker exec ${CONTAINER_NAME}-test tail -n 20 /var/log/supervisor/task_processor.log
    
    echo ""
    echo "✅ 本地测试容器启动成功"
    echo "💡 访问 http://localhost:8080 查看前端"
    echo "💡 运行以下命令查看实时日志:"
    echo "   docker logs -f ${CONTAINER_NAME}-test"
    echo "💡 运行以下命令检查健康状态:"
    echo "   docker exec ${CONTAINER_NAME}-test node /app/processor/check_processor_health.js"
    
    read -p "按任意键继续..." -n 1 -r
    echo
fi

# 4. 生产部署（可选）
read -p "是否部署到生产环境? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "请输入生产服务器地址 (例: user@server.com): " SERVER
    
    if [ -z "$SERVER" ]; then
        echo "❌ 未输入服务器地址，跳过生产部署"
    else
        echo "🚀 正在部署到生产环境: $SERVER"
        
        # 通过 SSH 执行部署
        ssh $SERVER << EOF
            set -e
            
            echo "📥 拉取最新镜像..."
            docker pull ${IMAGE_NAME}:${VERSION}
            
            echo "🛑 停止旧容器..."
            docker stop ${CONTAINER_NAME} 2>/dev/null || true
            docker rm ${CONTAINER_NAME} 2>/dev/null || true
            
            echo "🚀 启动新容器..."
            docker run -d \
                --name ${CONTAINER_NAME} \
                --restart unless-stopped \
                -p 80:80 \
                ${IMAGE_NAME}:${VERSION}
            
            echo "等待容器启动..."
            sleep 5
            
            echo ""
            echo "📊 容器状态:"
            docker ps | grep ${CONTAINER_NAME}
            
            echo ""
            echo "📋 Supervisor 进程状态:"
            docker exec ${CONTAINER_NAME} supervisorctl status
            
            echo ""
            echo "📄 任务处理器日志 (最新 20 行):"
            docker exec ${CONTAINER_NAME} tail -n 20 /var/log/supervisor/task_processor.log
            
            echo ""
            echo "✅ 生产部署成功！"
EOF
        
        echo ""
        echo "✅ 生产部署完成"
        echo "💡 运行以下命令查看实时日志:"
        echo "   ssh $SERVER 'docker logs -f ${CONTAINER_NAME}'"
        echo "💡 运行以下命令检查健康状态:"
        echo "   ssh $SERVER 'docker exec ${CONTAINER_NAME} node /app/processor/check_processor_health.js'"
    fi
fi

echo ""
echo "========================================"
echo "✨ 部署流程完成！"
echo "========================================"
echo ""
echo "📚 更多信息请查看: TASK_PROCESSOR_KEEPALIVE_FIX.md"
echo ""
