#!/bin/bash

# 实时监控更新日志
echo "🔍 开始监控应用更新日志..."
echo "请在手机上操作：设置 → 检查更新 → 立即更新"
echo "=========================================="
echo ""

adb logcat -c  # 清空旧日志

# 实时显示关键日志
adb logcat | grep --line-buffered -iE "update|ota|sha256|download|mirror|permission|install|📥|✅|❌|🔍|⚠️|FileProvider" | while read line; do
    # 高亮显示关键字
    echo "$line" | sed \
        -e 's/\(OTA\)/\x1b[33m\1\x1b[0m/g' \
        -e 's/\(SHA256\)/\x1b[36m\1\x1b[0m/g' \
        -e 's/\(ERROR\|FAILED\|❌\)/\x1b[31m\1\x1b[0m/g' \
        -e 's/\(SUCCESS\|✅\)/\x1b[32m\1\x1b[0m/g' \
        -e 's/\(permission\|PERMISSION\)/\x1b[35m\1\x1b[0m/g'
done
