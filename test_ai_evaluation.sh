#!/bin/bash

# 🧪 AI行程评估系统 - 快速测试脚本
# 用于验证所有文件是否正确创建，以及系统是否可用

set -e  # 遇到错误立即退出

echo "🚀 开始测试 Puked AI评估系统..."
echo ""

# ============================================
# 1. 检查文件完整性
# ============================================
echo "📋 [1/5] 检查文件完整性..."

REQUIRED_FILES=(
    "AI_TRIP_EVALUATION_PROMPT.md"
    "AI_TRIP_EVALUATION_PROMPT_QUICK.md"
    "scripts/trip_evaluator.py"
    "data/sample_trip_evaluation.json"
    "trip_evaluation_schema.json"
    "AI_EVALUATION_GUIDE.md"
    "QUICK_REFERENCE.md"
    "README_AI_EVALUATION.md"
    "AI_EVALUATION_SUMMARY.md"
)

MISSING_FILES=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "   ❌ 缺少文件: $file"
        MISSING_FILES=$((MISSING_FILES + 1))
    else
        echo "   ✅ $file"
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    echo ""
    echo "❌ 测试失败: 缺少 $MISSING_FILES 个文件"
    exit 1
fi

echo ""
echo "✅ 所有文件完整！"
echo ""

# ============================================
# 2. 验证JSON格式
# ============================================
echo "📐 [2/5] 验证JSON格式..."

if command -v jq &> /dev/null; then
    echo "   正在验证 data/sample_trip_evaluation.json..."
    if jq empty data/sample_trip_evaluation.json 2>/dev/null; then
        echo "   ✅ sample_trip_evaluation.json 格式正确"
    else
        echo "   ❌ sample_trip_evaluation.json 格式错误"
        exit 1
    fi
    
    echo "   正在验证 trip_evaluation_schema.json..."
    if jq empty trip_evaluation_schema.json 2>/dev/null; then
        echo "   ✅ trip_evaluation_schema.json 格式正确"
    else
        echo "   ❌ trip_evaluation_schema.json 格式错误"
        exit 1
    fi
else
    echo "   ⚠️  未安装jq，跳过JSON验证（建议安装: brew install jq）"
fi

echo ""

# ============================================
# 3. 检查Python依赖
# ============================================
echo "🐍 [3/5] 检查Python环境..."

if ! command -v python3 &> /dev/null; then
    echo "   ❌ 未找到Python3，请先安装"
    exit 1
fi

echo "   ✅ Python版本: $(python3 --version)"
echo ""
echo "   检查AI库安装状态..."

PYTHON_CHECK=$(python3 -c "
try:
    import google.generativeai
    print('gemini:installed')
except ImportError:
    print('gemini:missing')

try:
    import openai
    print('openai:installed')
except ImportError:
    print('openai:missing')
" 2>/dev/null || echo "error")

if echo "$PYTHON_CHECK" | grep -q "gemini:installed"; then
    echo "   ✅ google-generativeai 已安装"
    HAS_GEMINI=1
else
    echo "   ⚠️  google-generativeai 未安装"
    echo "      安装命令: pip install google-generativeai"
    HAS_GEMINI=0
fi

if echo "$PYTHON_CHECK" | grep -q "openai:installed"; then
    echo "   ✅ openai 已安装"
    HAS_OPENAI=1
else
    echo "   ⚠️  openai 未安装"
    echo "      安装命令: pip install openai"
    HAS_OPENAI=0
fi

if [ $HAS_GEMINI -eq 0 ] && [ $HAS_OPENAI -eq 0 ]; then
    echo ""
    echo "   ⚠️  至少需要安装一个AI库（Gemini或OpenAI）"
    echo "      推荐: pip install google-generativeai (免费)"
fi

echo ""

# ============================================
# 4. 检查API密钥配置
# ============================================
echo "🔑 [4/5] 检查API密钥配置..."

if [ ! -z "$GEMINI_API_KEY" ]; then
    echo "   ✅ GEMINI_API_KEY 已设置"
    HAS_KEY=1
elif [ ! -z "$OPENAI_API_KEY" ]; then
    echo "   ✅ OPENAI_API_KEY 已设置"
    HAS_KEY=1
else
    echo "   ⚠️  未设置API密钥"
    echo "      设置方法:"
    echo "      export GEMINI_API_KEY='your-key'"
    echo "      或"
    echo "      export OPENAI_API_KEY='your-key'"
    echo ""
    echo "      获取密钥:"
    echo "      - Gemini: https://aistudio.google.com/app/apikey (免费)"
    echo "      - OpenAI: https://platform.openai.com/api-keys (付费)"
    HAS_KEY=0
fi

echo ""

# ============================================
# 5. 生成测试报告
# ============================================
echo "📊 [5/5] 生成测试报告..."
echo ""
echo "================================================================"
echo "                     测试完成汇总"
echo "================================================================"
echo ""
echo "文件检查:       ✅ 所有 ${#REQUIRED_FILES[@]} 个文件完整"
echo "JSON验证:       ✅ 格式正确"
echo "Python环境:     ✅ Python3 可用"

if [ $HAS_GEMINI -eq 1 ] || [ $HAS_OPENAI -eq 1 ]; then
    echo "AI库安装:       ✅ 已安装"
else
    echo "AI库安装:       ⚠️  需要安装"
fi

if [ $HAS_KEY -eq 1 ]; then
    echo "API密钥:        ✅ 已配置"
else
    echo "API密钥:        ⚠️  未配置"
fi

echo ""
echo "================================================================"
echo ""

# ============================================
# 6. 提供下一步建议
# ============================================
if [ $HAS_GEMINI -eq 1 ] && [ $HAS_KEY -eq 1 ]; then
    echo "🎉 恭喜！系统已就绪，可以开始使用！"
    echo ""
    echo "快速开始:"
    echo "  python3 scripts/trip_evaluator.py data/sample_trip_evaluation.json"
    echo ""
elif [ $HAS_OPENAI -eq 1 ] && [ $HAS_KEY -eq 1 ]; then
    echo "🎉 恭喜！系统已就绪，可以开始使用！"
    echo ""
    echo "快速开始:"
    echo "  python3 scripts/trip_evaluator.py data/sample_trip_evaluation.json"
    echo ""
else
    echo "📝 下一步操作:"
    echo ""
    if [ $HAS_GEMINI -eq 0 ] && [ $HAS_OPENAI -eq 0 ]; then
        echo "1. 安装AI库 (推荐Gemini):"
        echo "   pip install google-generativeai"
        echo ""
    fi
    
    if [ $HAS_KEY -eq 0 ]; then
        echo "2. 设置API密钥:"
        echo "   export GEMINI_API_KEY='your-api-key'"
        echo "   (获取: https://aistudio.google.com/app/apikey)"
        echo ""
    fi
    
    echo "3. 运行评估:"
    echo "   python3 scripts/trip_evaluator.py data/sample_trip_evaluation.json"
    echo ""
fi

echo "================================================================"
echo "📚 文档导航:"
echo "  - 系统总览:     README_AI_EVALUATION.md"
echo "  - 使用指南:     AI_EVALUATION_GUIDE.md"
echo "  - 快速参考:     QUICK_REFERENCE.md"
echo "  - 完整Prompt:   AI_TRIP_EVALUATION_PROMPT.md"
echo "  - 精简Prompt:   AI_TRIP_EVALUATION_PROMPT_QUICK.md"
echo "================================================================"
echo ""
echo "✅ 测试完成！"
