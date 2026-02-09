#!/bin/bash

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}多架构 Docker 镜像构建与推送脚本${NC}"
echo -e "${GREEN}===========================================${NC}"

# 配置变量
DOCKER_USERNAME="rockyhk"
IMAGE_NAME="puked-web-allinone"
VERSION="2.4.7"

# 代理配置
HTTP_PROXY="http://host.docker.internal:59361"
HTTPS_PROXY="http://host.docker.internal:59361"

echo -e "${YELLOW}📦 镜像信息:${NC}"
echo -e "  用户名: ${DOCKER_USERNAME}"
echo -e "  镜像名: ${IMAGE_NAME}"
echo -e "  版本号: ${VERSION}"
echo -e "  代理地址: ${HTTP_PROXY}"
echo ""

# 1. 检查 Docker 登录状态
echo -e "${YELLOW}🔐 检查 Docker Hub 登录状态...${NC}"
if ! docker info | grep -q "Username"; then
    echo -e "${RED}❌ 未登录 Docker Hub，请先登录${NC}"
    docker login
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Docker 登录失败${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✅ Docker Hub 已登录${NC}"
echo ""

# 2. 检查并创建 buildx builder
echo -e "${YELLOW}🔧 配置 Docker Buildx...${NC}"
BUILDER_NAME="multiarch-builder-proxy"

# 检查 builder 是否存在
if docker buildx inspect $BUILDER_NAME > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Builder '$BUILDER_NAME' 已存在，正在删除...${NC}"
    docker buildx rm $BUILDER_NAME
fi

# 创建新的 builder 并配置代理
echo -e "${YELLOW}📝 创建新的 builder 并配置代理...${NC}"
docker buildx create \
    --name $BUILDER_NAME \
    --driver docker-container \
    --driver-opt "network=host" \
    --driver-opt "env.HTTP_PROXY=${HTTP_PROXY}" \
    --driver-opt "env.HTTPS_PROXY=${HTTPS_PROXY}" \
    --use

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 创建 builder 失败${NC}"
    exit 1
fi

# 启动 builder
echo -e "${YELLOW}🚀 启动 builder...${NC}"
docker buildx inspect --bootstrap

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 启动 builder 失败${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Builder 配置完成${NC}"
echo ""

# 3. 构建并推送多架构镜像
echo -e "${YELLOW}🏗️  开始构建多架构镜像...${NC}"
echo -e "${YELLOW}目标架构: linux/amd64, linux/arm64${NC}"
echo ""

docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --file Dockerfile.allinone.v2 \
    --tag ${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION} \
    --tag ${DOCKER_USERNAME}/${IMAGE_NAME}:latest \
    --push \
    --progress=plain \
    .

BUILD_STATUS=$?

echo ""
if [ $BUILD_STATUS -eq 0 ]; then
    echo -e "${GREEN}===========================================${NC}"
    echo -e "${GREEN}✅ 多架构镜像构建并推送成功！${NC}"
    echo -e "${GREEN}===========================================${NC}"
    echo ""
    echo -e "${GREEN}镜像信息:${NC}"
    echo -e "  ${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
    echo -e "  ${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
    echo ""
    echo -e "${GREEN}支持架构:${NC}"
    echo -e "  - linux/amd64 (x86_64)"
    echo -e "  - linux/arm64 (ARM64)"
    echo ""
    echo -e "${YELLOW}使用方法:${NC}"
    echo -e "  docker pull ${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
    echo -e "  docker run -d -p 8080:80 ${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
    echo ""
else
    echo -e "${RED}===========================================${NC}"
    echo -e "${RED}❌ 镜像构建失败${NC}"
    echo -e "${RED}===========================================${NC}"
    echo ""
    echo -e "${YELLOW}请检查上面的错误日志${NC}"
    exit 1
fi

# 4. 清理（可选）
# echo -e "${YELLOW}🧹 清理 builder...${NC}"
# docker buildx rm $BUILDER_NAME
# echo -e "${GREEN}✅ 清理完成${NC}"
