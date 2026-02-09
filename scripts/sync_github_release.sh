#!/bin/bash

# 自动同步 GitHub Release APK 到 OSGLab 镜像服务器
# 用途: 每次发布新版本后，自动下载 APK 并上传到镜像服务器

set -e

REPO_OWNER="hkgood"
REPO_NAME="Puked"
REMOTE_DIR="/var/www/download/PukedAPK"  # OSGLab 服务器路径
REMOTE_HOST="osglab.com"
REMOTE_USER="deploy"

echo "🔍 获取最新 GitHub Release 信息..."

# 获取最新 Release 的 APK 下载链接
LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")
APK_URL=$(echo "$LATEST_RELEASE" | jq -r '.assets[] | select(.name | endswith(".apk")) | .browser_download_url')
APK_NAME=$(echo "$LATEST_RELEASE" | jq -r '.assets[] | select(.name | endswith(".apk")) | .name')
VERSION=$(echo "$LATEST_RELEASE" | jq -r '.tag_name')

if [ -z "$APK_URL" ] || [ "$APK_URL" = "null" ]; then
    echo "❌ 未找到 APK 文件"
    exit 1
fi

echo "📦 找到版本: $VERSION"
echo "📥 APK 文件: $APK_NAME"
echo "🔗 下载链接: $APK_URL"

# 创建临时目录
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo ""
echo "⬇️  下载 APK 到本地..."
wget -O "$TEMP_DIR/$APK_NAME" "$APK_URL" --progress=bar:force

# 计算 SHA256
echo ""
echo "🔐 计算 SHA256..."
SHA256=$(shasum -a 256 "$TEMP_DIR/$APK_NAME" | awk '{print $1}')
echo "$SHA256" > "$TEMP_DIR/$APK_NAME.sha256"
echo "    SHA256: $SHA256"

# 上传到 OSGLab 服务器
echo ""
echo "📤 上传到 OSGLab 镜像服务器..."

# 确保远程目录存在
ssh "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $REMOTE_DIR"

# 上传 APK 和 SHA256
scp "$TEMP_DIR/$APK_NAME" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
scp "$TEMP_DIR/$APK_NAME.sha256" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"

# 创建版本信息文件
cat > "$TEMP_DIR/latest.json" <<EOF
{
  "version": "${VERSION#v}",
  "tag": "$VERSION",
  "apk_name": "$APK_NAME",
  "apk_url": "https://download.osglab.com/PukedAPK/$APK_NAME",
  "sha256": "$SHA256",
  "synced_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

scp "$TEMP_DIR/latest.json" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"

echo ""
echo "✅ 同步完成！"
echo ""
echo "📊 镜像信息:"
echo "   URL: https://download.osglab.com/PukedAPK/$APK_NAME"
echo "   SHA256: $SHA256"
echo ""
echo "🔍 验证下载:"
echo "   curl -I https://download.osglab.com/PukedAPK/$APK_NAME"
