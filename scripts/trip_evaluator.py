#!/usr/bin/env python3
"""
行程负体验AI评估器
支持调用 Gemini 或 ChatGPT API 进行智能评估
"""

import json
import os
from typing import Dict, Any, Literal
from datetime import datetime

# ============================================
# 配置区
# ============================================

# 选择AI服务商: "gemini" 或 "openai"
AI_PROVIDER: Literal["gemini", "openai"] = "gemini"

# API密钥 (请设置环境变量或直接填写)
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "your-gemini-api-key")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "your-openai-api-key")

# 模型选择
GEMINI_MODEL = "gemini-2.0-flash-exp"  # 或 "gemini-1.5-pro"
OPENAI_MODEL = "gpt-4o"  # 或 "gpt-4-turbo", "gpt-3.5-turbo"

# 使用完整版还是快速版Prompt
USE_QUICK_PROMPT = False  # True: 精简版, False: 完整版

# ============================================
# Prompt加载
# ============================================

def load_prompt() -> str:
    """加载AI评估Prompt"""
    prompt_file = "AI_TRIP_EVALUATION_PROMPT_QUICK.md" if USE_QUICK_PROMPT else "AI_TRIP_EVALUATION_PROMPT.md"
    
    try:
        with open(prompt_file, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        print(f"❌ 未找到Prompt文件: {prompt_file}")
        print("请确保文件在当前目录，或修改脚本中的路径")
        exit(1)

# ============================================
# AI调用函数
# ============================================

def call_gemini(system_prompt: str, user_message: str) -> str:
    """调用 Google Gemini API"""
    try:
        import google.generativeai as genai
    except ImportError:
        print("❌ 请安装 google-generativeai: pip install google-generativeai")
        exit(1)
    
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel(
        model_name=GEMINI_MODEL,
        system_instruction=system_prompt
    )
    
    response = model.generate_content(user_message)
    return response.text


def call_openai(system_prompt: str, user_message: str) -> str:
    """调用 OpenAI ChatGPT API"""
    try:
        from openai import OpenAI
    except ImportError:
        print("❌ 请安装 openai: pip install openai")
        exit(1)
    
    client = OpenAI(api_key=OPENAI_API_KEY)
    
    response = client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message}
        ],
        temperature=0.3,  # 降低随机性，提高一致性
    )
    
    return response.choices[0].message.content


def call_ai(system_prompt: str, user_message: str) -> str:
    """统一AI调用接口"""
    print(f"🤖 正在调用 {AI_PROVIDER.upper()} API...")
    
    if AI_PROVIDER == "gemini":
        return call_gemini(system_prompt, user_message)
    elif AI_PROVIDER == "openai":
        return call_openai(system_prompt, user_message)
    else:
        raise ValueError(f"不支持的AI服务商: {AI_PROVIDER}")

# ============================================
# 数据处理
# ============================================

def load_trip_data(file_path: str) -> Dict[str, Any]:
    """从JSON文件加载行程数据"""
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def format_trip_data(trip_data: Dict[str, Any]) -> str:
    """格式化行程数据为可读的文本"""
    
    # 基础信息
    vehicle = trip_data.get("vehicle", {})
    breakdown = trip_data.get("event_breakdown", {})
    
    total_events = sum(breakdown.values())
    
    formatted = f"""
# 行程数据

## 基础信息
- 行程ID: {trip_data.get('trip_id', 'N/A')}
- 开始时间: {trip_data.get('start_time', 'N/A')}
- 结束时间: {trip_data.get('end_time', 'N/A')}
- 总里程: {trip_data.get('distance', 0):.2f} km
- 总时长: {trip_data.get('duration', 0) // 60} 分钟

## 车辆信息
- 品牌: {vehicle.get('brand', 'Unknown')}
- 车型: {vehicle.get('model', 'Unknown')}
- 软件版本: {vehicle.get('software_version', 'N/A')}
- 自动驾驶: {'是' if vehicle.get('is_autonomous') else '否'}

## 负体验统计
- 总计: {total_events} 次
- 急加速: {breakdown.get('rapidAcceleration', 0)} 次
- 急减速: {breakdown.get('rapidDeceleration', 0)} 次
- 颠簸: {breakdown.get('bump', 0)} 次
- 摆动: {breakdown.get('wobble', 0)} 次
- 顿挫: {breakdown.get('jerk', 0)} 次
- 手动标记: {breakdown.get('manual', 0)} 次

## 环境信息
- 道路类型: {trip_data.get('road_conditions', 'N/A')}
- 天气: {trip_data.get('weather', 'N/A')}
- 时间段: {trip_data.get('time_of_day', 'N/A')}
- 算法版本: {trip_data.get('algorithm_version', 'N/A')}
- 平台: {trip_data.get('platform', 'N/A')}
"""
    
    # 如果有详细事件列表
    if "events" in trip_data and len(trip_data["events"]) > 0:
        formatted += "\n## 详细事件列表 (前10条)\n"
        for i, event in enumerate(trip_data["events"][:10], 1):
            formatted += f"{i}. {event['type']} @ {event['timestamp']}"
            if 'position' in event:
                pos = event['position']
                formatted += f" ({pos.get('lat', 'N/A')}, {pos.get('lng', 'N/A')})"
            if 'speed' in event:
                formatted += f" | 速度: {event['speed']*3.6:.1f} km/h"
            formatted += "\n"
    
    return formatted

# ============================================
# 主函数
# ============================================

def evaluate_trip(trip_data: Dict[str, Any]) -> str:
    """评估单条行程"""
    
    # 加载系统Prompt
    system_prompt = load_prompt()
    
    # 格式化行程数据
    user_message = format_trip_data(trip_data)
    user_message += "\n\n请按照你的专业知识，对这条行程进行全面评估。"
    
    # 调用AI
    evaluation = call_ai(system_prompt, user_message)
    
    return evaluation


def batch_evaluate(trip_files: list[str]) -> None:
    """批量评估多条行程"""
    results = []
    
    for i, file_path in enumerate(trip_files, 1):
        print(f"\n{'='*60}")
        print(f"📊 正在评估第 {i}/{len(trip_files)} 条行程: {file_path}")
        print('='*60)
        
        try:
            trip_data = load_trip_data(file_path)
            evaluation = evaluate_trip(trip_data)
            
            results.append({
                "file": file_path,
                "evaluation": evaluation,
                "timestamp": datetime.now().isoformat()
            })
            
            print("\n" + evaluation)
            
        except Exception as e:
            print(f"❌ 评估失败: {str(e)}")
            continue
    
    # 保存结果
    output_file = f"evaluation_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    
    print(f"\n✅ 评估完成！结果已保存至: {output_file}")


def main():
    """主入口"""
    import sys
    
    if len(sys.argv) < 2:
        print("""
使用方法:
    python trip_evaluator.py <行程JSON文件> [文件2] [文件3] ...

示例:
    python trip_evaluator.py trip_data.json
    python trip_evaluator.py trip1.json trip2.json trip3.json

配置:
    - 修改脚本顶部的 AI_PROVIDER 选择服务商 (gemini/openai)
    - 设置环境变量 GEMINI_API_KEY 或 OPENAI_API_KEY
    - 修改 USE_QUICK_PROMPT 选择完整版或精简版Prompt
        """)
        sys.exit(1)
    
    trip_files = sys.argv[1:]
    
    # 验证文件存在
    for file_path in trip_files:
        if not os.path.exists(file_path):
            print(f"❌ 文件不存在: {file_path}")
            sys.exit(1)
    
    # 开始评估
    if len(trip_files) == 1:
        print(f"📊 评估单条行程: {trip_files[0]}")
        trip_data = load_trip_data(trip_files[0])
        evaluation = evaluate_trip(trip_data)
        print("\n" + evaluation)
    else:
        print(f"📊 批量评估 {len(trip_files)} 条行程")
        batch_evaluate(trip_files)


if __name__ == "__main__":
    main()
