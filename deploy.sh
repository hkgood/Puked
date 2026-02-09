#!/bin/bash
# ============================================
# Puked.osglab.com 快速部署脚本
# ============================================

set -e  # 遇到错误立即退出

echo "=========================================="
echo "🚀 Puked Web 快速部署脚本"
echo "=========================================="

# ========== 1. 备份现有配置 ==========
echo ""
echo "📦 1. 备份现有配置..."
BACKUP_DIR="/www/sites/puked.osglab.com/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 查找并备份主配置文件
if [ -f "/etc/nginx/conf.d/puked.osglab.com.conf" ]; then
    cp /etc/nginx/conf.d/puked.osglab.com.conf "$BACKUP_DIR/"
    echo "✅ 已备份主配置文件"
elif [ -f "/etc/nginx/sites-enabled/puked.osglab.com" ]; then
    cp /etc/nginx/sites-enabled/puked.osglab.com "$BACKUP_DIR/"
    echo "✅ 已备份主配置文件"
else
    echo "⚠️  未找到现有配置文件，跳过备份"
fi

# 备份代理配置
if [ -d "/www/sites/puked.osglab.com/proxy" ]; then
    cp -r /www/sites/puked.osglab.com/proxy "$BACKUP_DIR/"
    echo "✅ 已备份代理配置目录"
fi

echo "📁 备份位置：$BACKUP_DIR"

# ========== 2. 创建代理配置目录 ==========
echo ""
echo "📁 2. 创建代理配置目录..."
mkdir -p /www/sites/puked.osglab.com/proxy
echo "✅ 目录已创建"

# ========== 3. 部署新配置文件 ==========
echo ""
echo "📝 3. 部署新配置文件..."

# 从当前目录复制配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/puked-web.conf" ]; then
    cp "$SCRIPT_DIR/puked-web.conf" /www/sites/puked.osglab.com/proxy/
    echo "✅ 已部署代理配置：puked-web.conf"
else
    echo "❌ 错误：找不到 puked-web.conf"
    exit 1
fi

# 提示用户手动更新主配置文件
echo ""
echo "⚠️  请手动更新主配置文件："
echo "   文件位置：/etc/nginx/conf.d/puked.osglab.com.conf"
echo "   或：/etc/nginx/sites-enabled/puked.osglab.com"
echo "   参考文件：$SCRIPT_DIR/puked.osglab.com.conf"
echo ""
read -p "按回车键继续（更新主配置后）..." 

# ========== 4. 测试 Nginx 配置 ==========
echo ""
echo "🧪 4. 测试 Nginx 配置..."
if nginx -t; then
    echo "✅ Nginx 配置测试通过"
else
    echo "❌ Nginx 配置测试失败！"
    echo "正在回滚..."
    
    # 回滚配置
    if [ -f "$BACKUP_DIR/puked.osglab.com.conf" ]; then
        cp "$BACKUP_DIR/puked.osglab.com.conf" /etc/nginx/conf.d/
    fi
    if [ -d "$BACKUP_DIR/proxy" ]; then
        rm -rf /www/sites/puked.osglab.com/proxy
        cp -r "$BACKUP_DIR/proxy" /www/sites/puked.osglab.com/
    fi
    
    echo "✅ 已回滚到原配置"
    exit 1
fi

# ========== 5. 重新加载 Nginx ==========
echo ""
echo "🔄 5. 重新加载 Nginx..."
if nginx -s reload; then
    echo "✅ Nginx 已重新加载"
else
    echo "❌ Nginx 重新加载失败！"
    exit 1
fi

# ========== 6. 重新部署 Docker 容器 ==========
echo ""
echo "🐳 6. 重新部署 Docker 容器..."

# 停止旧容器
if docker ps -a | grep -q puked-web; then
    echo "🛑 停止旧容器..."
    docker stop puked-web 2>/dev/null || true
    docker rm puked-web 2>/dev/null || true
    echo "✅ 旧容器已删除"
fi

# 删除旧镜像
if docker images | grep -q "puked-web"; then
    echo "🗑️  删除旧镜像..."
    docker rmi puked-web:latest 2>/dev/null || true
    echo "✅ 旧镜像已删除"
fi

# 构建新镜像
echo ""
echo "🔨 构建新镜像..."
cd /Users/maxliu/Documents/PukedMaster/Puked_web

if docker build --no-cache -t puked-web:latest .; then
    echo "✅ 镜像构建成功"
else
    echo "❌ 镜像构建失败！"
    exit 1
fi

# 启动新容器
echo ""
echo "🚀 启动新容器..."
if docker run -d \
    --name puked-web \
    -p 3001:80 \
    --restart unless-stopped \
    puked-web:latest; then
    echo "✅ 容器启动成功"
else
    echo "❌ 容器启动失败！"
    exit 1
fi

# ========== 7. 验证部署 ==========
echo ""
echo "✅ 7. 验证部署..."

# 等待容器启动
sleep 3

# 检查容器状态
if docker ps | grep -q puked-web; then
    echo "✅ 容器运行正常"
else
    echo "❌ 容器未运行！"
    docker logs puked-web
    exit 1
fi

# 测试本地访问
echo ""
echo "🧪 测试本地访问..."
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3001 | grep -q "200\|301\|302"; then
    echo "✅ 本地访问正常"
else
    echo "⚠️  本地访问异常"
fi

# 测试反向代理
echo ""
echo "🧪 测试反向代理..."
if curl -s -o /dev/null -w "%{http_code}" https://puked.osglab.com | grep -q "200\|301\|302"; then
    echo "✅ 反向代理正常"
else
    echo "⚠️  反向代理异常"
fi

# ========== 8. 完成 ==========
echo ""
echo "=========================================="
echo "✅ 部署完成！"
echo "=========================================="
echo ""
echo "📋 部署信息："
echo "   容器名称：puked-web"
echo "   容器端口：3001:80"
echo "   反向代理：https://puked.osglab.com"
echo "   备份位置：$BACKUP_DIR"
echo ""
echo "📝 下一步："
echo "   1. 清除浏览器缓存"
echo "   2. 访问 https://puked.osglab.com"
echo "   3. 检查开发者工具 Network 面板"
echo "   4. 确认所有资源正常加载"
echo ""
echo "🔍 查看日志："
echo "   Docker: docker logs -f puked-web"
echo "   Nginx:  tail -f /www/sites/puked.osglab.com/log/error.log"
echo ""
