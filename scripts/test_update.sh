#!/bin/bash

# 测试应用内更新功能的脚本

set -e

echo "🧪 Puked 应用内更新功能测试脚本"
echo "=================================="
echo ""

# 检查是否在正确的目录
if [ ! -f "Puked/pubspec.yaml" ]; then
    echo "❌ 错误: 请在项目根目录运行此脚本"
    exit 1
fi

# 1. 备份当前版本号
echo "📋 步骤1: 备份当前版本号..."
ORIGINAL_VERSION=$(grep '^version:' Puked/pubspec.yaml | awk '{print $2}')
echo "   当前版本: $ORIGINAL_VERSION"

# 2. 临时降低版本号
echo ""
echo "📝 步骤2: 临时降低版本号为 2.4.0+240 (用于测试)..."
sed -i.bak 's/^version: .*/version: 2.4.0+240/' Puked/pubspec.yaml

# 3. 构建 APK
echo ""
echo "🔨 步骤3: 构建测试 APK..."
cd Puked
flutter clean > /dev/null 2>&1
flutter pub get > /dev/null 2>&1
flutter build apk --release

# 4. 重命名 APK
echo ""
echo "📦 步骤4: 准备测试文件..."
cd build/app/outputs/flutter-apk
TEST_APK="Puked-2.4.0-test.apk"
mv app-release.apk "$TEST_APK"

# 5. 恢复版本号
echo ""
echo "♻️  步骤5: 恢复原版本号..."
cd ../../../../../..
mv Puked/pubspec.yaml.bak Puked/pubspec.yaml

# 6. 检查设备连接
echo ""
echo "📱 步骤6: 检查 Android 设备连接..."
DEVICE_COUNT=$(adb devices | grep -v "List" | grep "device" | wc -l | xargs)

if [ "$DEVICE_COUNT" -eq "0" ]; then
    echo "   ⚠️  未检测到 Android 设备"
    echo "   请通过 USB 连接设备或启动模拟器"
    echo ""
    echo "   APK 已构建: Puked/build/app/outputs/flutter-apk/$TEST_APK"
    echo "   你可以手动安装: adb install Puked/build/app/outputs/flutter-apk/$TEST_APK"
    exit 0
fi

echo "   ✅ 检测到 $DEVICE_COUNT 个设备"

# 7. 卸载旧版本（如果存在）
echo ""
echo "🗑️  步骤7: 卸载旧版本（如果存在）..."
adb uninstall com.osglab.puked > /dev/null 2>&1 || echo "   (未安装旧版本，跳过)"

# 8. 安装测试 APK
echo ""
echo "📲 步骤8: 安装测试 APK (版本 2.4.0)..."
adb install "Puked/build/app/outputs/flutter-apk/$TEST_APK"

# 9. 启动应用
echo ""
echo "🚀 步骤9: 启动应用..."
adb shell am start -n com.osglab.puked/.MainActivity

# 10. 测试指引
echo ""
echo "✅ 测试准备完成！"
echo "=================================="
echo ""
echo "📋 测试步骤:"
echo ""
echo "1️⃣  在手机上打开 Puked 应用"
echo "2️⃣  进入【设置】→【检查更新】"
echo "3️⃣  应该会检测到新版本 v2.4.1"
echo ""
echo "🔍 验证项:"
echo "   ✅ 是否提示授予【安装未知应用】权限（首次）"
echo "   ✅ 是否显示【正在选择最快下载源】"
echo "   ✅ 下载进度条是否正常显示"
echo "   ✅ 下载完成后是否显示【正在验证文件完整性】"
echo "   ✅ SHA256 校验通过后是否自动弹出安装界面"
echo ""
echo "🧪 额外测试:"
echo "   • 测试权限拒绝场景：拒绝安装权限，看是否有引导提示"
echo "   • 测试网络错误：下载过程中关闭 WiFi/数据"
echo "   • 测试重复下载：在下载过程中再次点击【立即更新】"
echo ""
echo "📊 查看日志:"
echo "   adb logcat | grep -E 'OTA|Update|SHA256'"
echo ""
echo "🔄 重新测试:"
echo "   ./scripts/test_update.sh"
echo ""
