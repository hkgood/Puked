#!/bin/bash

echo "🔍 检查最新 Archive 中的 dSYM 文件..."
echo ""

# 找到最新的 Archive
LATEST_ARCHIVE=$(ls -t ~/Library/Developer/Xcode/Archives/*/*/*.xcarchive 2>/dev/null | head -1)

if [ -z "$LATEST_ARCHIVE" ]; then
    echo "❌ 未找到 Archive 文件"
    echo "   请先在 Xcode 中执行 Product → Archive"
    exit 1
fi

echo "📦 Archive: $(basename "$LATEST_ARCHIVE")"
echo "📂 路径: $LATEST_ARCHIVE"
echo ""

DSYM_DIR="$LATEST_ARCHIVE/dSYMs"

if [ ! -d "$DSYM_DIR" ]; then
    echo "❌ dSYMs 文件夹不存在"
    exit 1
fi

echo "📂 dSYM 文件列表："
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ls -lh "$DSYM_DIR" | tail -n +2 | awk '{print $9, "("$5")"}'
echo ""

# 检查关键框架
echo "🔍 检查关键框架的 dSYM..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MISSING_COUNT=0

for framework in "objective_c.framework" "sherpa_onnx.framework"; do
    DSYM_FILE="$DSYM_DIR/${framework}.dSYM"
    if [ -d "$DSYM_FILE" ]; then
        echo "✅ $framework.dSYM 存在"
        UUID=$(dwarfdump --uuid "$DSYM_FILE" 2>/dev/null | grep UUID | head -1)
        if [ -n "$UUID" ]; then
            echo "   $UUID"
        else
            echo "   ⚠️ 无法读取 UUID"
        fi
    else
        echo "❌ $framework.dSYM 缺失"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
    echo ""
done

# 总结
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $MISSING_COUNT -eq 0 ]; then
    echo "🎉 所有关键 dSYM 文件都存在！"
    echo ""
    echo "✅ 可以安全上传到 TestFlight"
    echo ""
    echo "上传步骤："
    echo "1. 打开 Xcode → Window → Organizer"
    echo "2. 选择这个 Archive"
    echo "3. 点击 'Distribute App'"
    echo "4. 确保勾选 'Upload your app's symbols' ✅"
    echo "5. 点击 'Upload'"
    exit 0
else
    echo "⚠️ 缺失 $MISSING_COUNT 个关键 dSYM 文件"
    echo ""
    echo "请执行以下步骤："
    echo "1. cd ios && pod install"
    echo "2. flutter clean"
    echo "3. 在 Xcode 中重新 Archive"
    echo "4. 再次运行此脚本验证"
    exit 1
fi
