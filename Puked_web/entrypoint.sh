#!/bin/sh
# 1. 启动 Nginx (后台运行)
nginx -g "daemon on;"

echo "🌐 Nginx 已启动..."

# 2. 检查并安装依赖 (如果容器内没有)
if [ ! -d "node_modules" ]; then
    echo "📦 正在安装脚本依赖..."
    npm install pocketbase node-fetch
fi

# 3. 启动归纳 Worker (前台运行，这样日志会输出到 docker logs)
echo "🛠 正在启动 Puked 归纳任务..."
node /usr/share/nginx/html/scripts/auto_induction.js
