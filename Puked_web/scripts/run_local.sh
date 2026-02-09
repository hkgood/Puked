#!/bin/bash

# 确保在脚本所在目录
cd "$(dirname "$0")"

# 设置调试环境变量 (您可以根据需要修改这些值)
export PB_URL="https://pb.osglab.com"
export ADMIN_EMAIL="rocky.hk@gmail.com"
export ADMIN_PASSWORD="your_actual_password_here" # 请在此处填入正确的密码进行本地调试
export CHECK_INTERVAL="5000"
export BATCH_SIZE="10"
export CONCURRENCY="3"

echo "🛠  正在启动本地调试模式..."
echo "📍 连接目标: $PB_URL"

# 检查依赖是否已安装
if [ ! -d "node_modules" ]; then
    echo "📦 正在安装依赖..."
    npm install --omit=dev
fi

# 运行脚本
node task_processor.pb.js
