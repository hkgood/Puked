#!/bin/bash
# ============================================
# Docker Hub 网络问题临时解决方案
# ============================================

echo "=========================================="
echo "🌐 Docker Hub 网络问题诊断与解决"
echo "=========================================="

echo ""
echo "检测到 Docker Hub 连接超时，提供以下解决方案："
echo ""

echo "方案 1️⃣: 配置 Docker 镜像加速器（推荐）"
echo "----------------------------------------"
echo "编辑 Docker Desktop 配置："
echo "  1. 打开 Docker Desktop"
echo "  2. 进入 Settings -> Docker Engine"
echo "  3. 添加以下配置："
echo ""
cat << 'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.mirrors.sjtug.sjtu.edu.cn",
    "https://docker.nju.edu.cn"
  ]
}
EOF
echo ""
echo "  4. 点击 Apply & Restart"
echo ""

echo "方案 2️⃣: 使用系统代理"
echo "----------------------------------------"
echo "如果你有代理，设置 Docker Desktop 使用系统代理："
echo "  Settings -> Resources -> Proxies"
echo "  启用 'Manual proxy configuration'"
echo ""

echo "方案 3️⃣: 使用已构建的镜像（如果有）"
echo "----------------------------------------"
echo "如果 Docker Hub 上已有镜像："
echo "  docker pull rocky8848/puked-web:2.4.5"
echo ""

echo "方案 4️⃣: 等待网络恢复后重试"
echo "----------------------------------------"
echo "  bash Puked_web/fix_task_processor.sh"
echo ""

echo "=========================================="
echo "⚙️  推荐操作步骤"
echo "=========================================="
echo ""
echo "1. 配置镜像加速器（方案1）"
echo "2. 重启 Docker Desktop"
echo "3. 验证连接："
echo "   docker pull node:20-alpine"
echo "4. 重新执行修复："
echo "   bash Puked_web/fix_task_processor.sh"
echo ""
