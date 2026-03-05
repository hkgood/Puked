import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/services/trip_score_calculator.dart';
import 'package:puked/services/trip_summary_service.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final aiCommentaryServiceProvider = Provider((ref) {
  final storage = ref.watch(storageServiceProvider);
  final i18n = ref.watch(i18nProvider);
  return AiCommentaryService(storage, i18n);
});

// ─── AI 生成内容（吐感裁决 + 段落点评，双语独立缓存） ──────────────────────────
/// AI 一次性生成两个部分：
///   [label]      — 一句 Puked 风格"吐感裁决"，结合实际行程情况，有温度有梗
///   [commentary] — 2～4 句完整行程点评
///
/// 存储格式（v4）：双语独立缓存，切换语言后自动补充缺失版本，不重复消耗已生成的语言
/// ```json
/// {"v":4,"zh":{"label":"...","commentary":"..."},"en":{"label":"...","commentary":"..."}}
/// ```
class AiContent {
  final String label;
  final String commentary;

  const AiContent({required this.label, required this.commentary});

  // ─── 存储/读取（Trip.aiCommentary 字段）────────────────────────

  /// 将当前 AiContent 合并写入到现有存储字符串的指定语言槽位
  /// （不覆盖另一个语言的缓存）
  static String mergeIntoStored(
      String? existing, AiContent content, String langCode) {
    // 先解析现有数据
    Map<String, dynamic> root = {'v': 4};
    if (existing != null && existing.isNotEmpty) {
      try {
        final s = existing.indexOf('{');
        final e = existing.lastIndexOf('}');
        if (s >= 0 && e > s) {
          final parsed =
              jsonDecode(existing.substring(s, e + 1)) as Map<String, dynamic>;
          // v3 旧格式：单语言，转存到对应槽
          if ((parsed['v'] as int?) == 3) {
            // 无法确定旧格式是哪种语言，保守地不迁移
          } else if ((parsed['v'] as int?) == 4) {
            root = Map<String, dynamic>.from(parsed);
          }
        }
      } catch (_) {}
    }
    root['v'] = 4;
    root[langCode] = {'label': content.label, 'commentary': content.commentary};
    return jsonEncode(root);
  }

  /// 从存储字符串中读取指定语言的 AiContent
  /// - v4 → 按语言代码读取对应槽
  /// - v3 旧格式 → 不管语言，直接返回（兼容旧缓存）
  /// - 纯文本 → 兼容最旧版本
  static AiContent? fromStoredString(String? stored, {String langCode = 'zh'}) {
    if (stored == null || stored.isEmpty) return null;
    try {
      final start = stored.indexOf('{');
      final end = stored.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final parsed = jsonDecode(stored.substring(start, end + 1))
            as Map<String, dynamic>;
        final v = parsed['v'] as int?;

        // v4：按语言槽读取
        if (v == 4) {
          final slot = parsed[langCode] as Map<String, dynamic>?;
          if (slot == null) return null; // 该语言尚未生成
          return AiContent(
            label: slot['label'] as String? ?? '',
            commentary: slot['commentary'] as String? ?? '',
          );
        }

        // v3：单语言旧格式，直接返回（不管当前语言）
        if (v == 3) {
          return AiContent(
            label: parsed['label'] as String? ?? '',
            commentary: parsed['commentary'] as String? ?? '',
          );
        }
      }
    } catch (_) {}
    // 纯文本旧格式
    return AiContent(label: '', commentary: stored);
  }

  /// 检查存储字符串中指定语言是否已有缓存
  static bool hasLanguage(String? stored, String langCode) {
    if (stored == null || stored.isEmpty) return false;
    try {
      final start = stored.indexOf('{');
      final end = stored.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final parsed = jsonDecode(stored.substring(start, end + 1))
            as Map<String, dynamic>;
        if ((parsed['v'] as int?) == 4) {
          return parsed.containsKey(langCode);
        }
        // v3 或纯文本：有内容但不知道语言，保守返回 false 让调用方决定
        return false;
      }
    } catch (_) {}
    return false;
  }
}

/// 通义千问（Qwen）舒适度点评服务
///
/// 职责：
///   1. 调用 [TripSummaryService] 生成离线行程摘要（不依赖网络）
///   2. 构建 prompt 并请求 Qwen 兼容 OpenAI 接口，输出 JSON（label + commentary）
///   3. 将结果序列化后缓存到本地数据库（避免重复 token 消耗）
class AiCommentaryService {
  static const _apiUrl =
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  // API Key 写在这里供 APP 调用，实际生产建议通过后端代理
  static const _apiKey = 'sk-8a4e8b64d7294911baf9fa12414d3bb2';
  static const _model = 'qwen-turbo';
  static const _maxTokens = 450; // label + commentary，留足余量

  final StorageService _storage;
  final dynamic _i18n; // I18n, for locale
  final TripSummaryService _summaryService = TripSummaryService();

  AiCommentaryService(this._storage, this._i18n);

  bool get _isEnglish => _i18n?.locale?.languageCode == 'en';

  // ─── 系统 Prompt（按 app 语言中/英）─────────────────────
  String _getSystemPrompt() {
    if (_isEnglish) {
      return '''You are the "Puked Trip Analyst" for the app Puked — a ride comfort tracker. "Puked" captures the feeling of a rough ride: jerky, stomach-churning, gag-worthy. The name is the brand.

Your job: generate TWO things from the trip data, returned as a single JSON object:

1. "label" — A punchy "Nausea Verdict" (≤ 10 words). The stomach's Yelp review of the trip. Be specific: use actual events (hard brakes, bumps), the brand, the city if relevant. Not a template — make it feel written for THIS trip. Examples: "Stomach declared a national emergency", "Smooth enough to eat soup en route", "Stomach filed for emotional damages after 3 hard brakes", "16-second test run: stomach didn't even show up".

2. "commentary" — 2–4 witty, vivid sentences. Sharp observation, not a stats recitation. Make it feel like something a clever person would say at a dinner party, not a CSV export.

[CRITICAL: trip_quality = what kind of trip is this?]
• debug — Seconds long, GPS frozen. Pure app/dev test. Label + commentary should riff on "algorithm did a dry run", "car stayed parked while the app had feelings", etc. Never invent a road trip that didn't happen.
• stationary — Barely moved. Waiting, parked, forgotten phone. Stillness humor: "stomach enjoyed the parking lot ambiance".
• ultra_short — Under 300 m. Parking lot shuffle. Micro-journey energy.
• short — Under 1 km. Breezy, light.
• normal — Full treatment: city + scenario + comfort verdict.

[Creative Freedom]
Know your car brands, industry news, city driving culture. Use it when it adds flavor. Never invent facts. Never name real people.

[Location]
Coordinates like (37.77, -122.42) → write the city name naturally, as if you just know. No "approximately located at".

[Tone]
Witty and warm. Humor the AI, not the user. Never be cruel.

[Output — CRITICAL]
ONLY output a raw JSON object. No markdown, no explanation, no prefix:
{"label": "...", "commentary": "..."}''';
    }
    return '''你是「Puked」App 的行程吐感分析师。Puked = 吐了，这是这款 App 的核心品牌气质：用"胃"的感受来评判一次出行的质量。差劲的行程会让人想 puke，舒适的行程让胃感谢你。

你的任务：一次性生成两样东西，以 JSON 格式输出：

1. "label" — 「吐感裁决」（≤ 15 字）。这是胃的一句裁决词——要结合实际数据来写，不能每次都是套话。有急刹就说急刹，有颠簸就说颠簸，有好玩的品牌就带进来，是调试行程就调侃调试。要让人看了会心一笑甚至噗嗤出来。好的示例：「三次急刹，胃部已提交辞职报告」「全程丝滑，胃表示白跑一趟」「16秒原地待机，胃：我甚至没上车」「上海高架五次颠簸，胃请求转岗」。

2. "commentary" — 2～4 句行程点评，风趣、有画面感、一针见血。不是数据的复读，是有观点有温度的评价。

【关键：trip_quality 字段定义了这是什么行程】
• debug — 只有几秒且 GPS 未动，是 App 调试记录，绝非真实驾驶。label 和 commentary 要围绕「算法做自检」「车没动，App 动了」来创作，绝不虚构出行场景。
• stationary — 车几乎没动，可能停车等人。label 要幽默反映「原地静止」。
• ultra_short — 不足 300 米，挪车级别的微出行。
• short — 1 公里以内短途，轻快语气。
• normal — 正常行程，完整发挥：城市场景画面感 + 吐感裁决。

【创作自由度】
你熟悉各大汽车品牌的故事、创始人风格、近期新闻、行业热梗。有好角度就自然带进来，没有就别硬凑。绝不写真实人名。

【城市坐标】
若城市字段是坐标（如 (31.20, 121.62)），你知道那是哪里就直接写城市名，不要出现坐标数字，不要用「大概在」「位于」之类的措辞。

【语气】
亲切、幽默、一针见血。若是自动驾驶行程，调侃 AI 算法，不调侃用户。

【输出格式——严格遵守】
只输出原始 JSON，不加 markdown 代码块，不加任何前缀后缀：
{"label": "...", "commentary": "..."}''';
  }

  /// 生成行程 AI 内容（吐感裁决 label + 段落点评 commentary）并持久化到本地
  ///
  /// [forceRefresh] 为 true 时强制重新生成（忽略本地缓存）
  /// [tripScore]   可传入预计算的评分，若为 null 则在内部计算
  ///
  /// 双语缓存策略：每种语言独立生成并缓存，切换语言后调用此方法会自动补充缺失版本，
  /// 而不会覆盖已缓存的另一语言版本。
  Future<AiContent?> generateCommentary(
    Trip trip, {
    String? brandName,
    bool forceRefresh = false,
    TripScore? tripScore,
  }) async {
    final langCode = _isEnglish ? 'en' : 'zh';

    // 优先使用本地缓存（当前语言版本已存在）
    if (!forceRefresh &&
        AiContent.hasLanguage(trip.aiCommentary, langCode)) {
      debugPrint('[AI] Using cached $langCode content for ${trip.uuid.substring(0, 8)}');
      return AiContent.fromStoredString(trip.aiCommentary, langCode: langCode);
    }

    // 确保 trajectory + events 已加载
    if (!trip.trajectory.isLoaded) await trip.trajectory.load();
    if (!trip.events.isLoaded) await trip.events.load();

    // 本地计算评分（确定性，不依赖网络）
    final score = tripScore ?? TripScoreCalculator.calculate(trip);

    // 离线抽稀（不依赖网络）
    final summary = _summaryService.buildSummary(trip, brandName: brandName);
    final userPrompt = _buildUserPrompt(summary, score);

    debugPrint('[AI] Requesting $langCode content for ${trip.uuid.substring(0, 8)}');
    debugPrint('[AI] Prompt size: ${userPrompt.length} chars');

    try {
      final content = await _callQwen(userPrompt);
      if (content != null) {
        // 将此语言版本合并写入（保留另一语言的缓存）
        final stored = AiContent.mergeIntoStored(
            trip.aiCommentary, content, langCode);
        await _storage.saveAiCommentary(trip.id, stored);
        // 同步更新内存中的字段，供 hasLanguage 判断使用
        trip.aiCommentary = stored;
        debugPrint('[AI] Saved $langCode label: "${content.label}"');
        debugPrint('[AI] Saved $langCode commentary: "${content.commentary}"');
      }
      return content;
    } catch (e) {
      debugPrint('[AI] Error generating content: $e');
      return null;
    }
  }

  /// 从 Trip 的缓存字段中解析指定语言的 AiContent（不触发网络请求）
  static AiContent? fromTrip(Trip trip, {String langCode = 'zh'}) =>
      AiContent.fromStoredString(trip.aiCommentary, langCode: langCode);

  // ─── 构建用户侧 Prompt（与 app 语言一致）────────────────────
  String _buildUserPrompt(Map<String, dynamic> summary, TripScore score) {
    final meta = summary['metadata'] as Map<String, dynamic>;
    final stats = summary['driving_stats'] as Map<String, dynamic>;
    final eventBreakdown = meta['event_breakdown'] as Map<String, dynamic>;
    final eventsSummary = summary['events_summary'] as List<dynamic>;

    final tripQuality = meta['trip_quality'] as String? ?? 'normal';
    final durationSec = meta['duration_sec'] as int? ?? 0;
    final distanceKm = meta['distance_km'] as String? ?? '0.00';
    final eventCount = meta['event_count'] as int? ?? 0;

    final sep = _isEnglish ? ', ' : '、';

    // 事件描述（debug/stationary 类型时简化）
    final String eventDesc;
    if (tripQuality == 'debug' || tripQuality == 'stationary') {
      eventDesc = _isEnglish
          ? 'No events (vehicle did not actually move).'
          : '无任何事件（车辆实际未行驶）';
    } else {
      final breakdown = eventBreakdown.entries
          .where((e) => (e.value as int? ?? 0) > 0)
          .map((e) => _isEnglish
              ? '${_eventTypeName(e.key)} ×${e.value}'
              : '${_eventTypeName(e.key)} ${e.value} 次')
          .join(sep);
      eventDesc = eventCount == 0
          ? (_isEnglish
              ? 'No negative comfort events — very smooth.'
              : '全程零负体验事件，非常平稳')
          : (_isEnglish
              ? '$eventCount negative event(s): $breakdown'
              : '共 $eventCount 次负体验：$breakdown');
    }

    // 采样事件（debug/stationary 不显示）
    final sampleEvents = (tripQuality == 'debug' || tripQuality == 'stationary')
        ? ''
        : eventsSummary.take(5).map((e) {
            final offset = e['offset_sec'] as int;
            final min = offset ~/ 60;
            final sec = offset % 60;
            return _isEnglish
                ? '${_eventTypeName(e['type'])} at ${min}m${sec}s'
                : '${_eventTypeName(e['type'])}（第 ${min}m${sec}s）';
          }).join(sep);

    // 评分上下文（debug 类型时用不同措辞）
    final String scoreContext;
    if (tripQuality == 'debug') {
      scoreContext = _isEnglish
          ? '\n[Note: Score is ${score.score}/100 but this trip has no real driving data — treat as a system test.]'
          : '\n【注意：评分 ${score.score} 分，但此行程无真实驾驶数据，请按系统测试场景处理】';
    } else {
      scoreContext = _isEnglish
          ? '\nTrip score: ${score.score}/100. System tag: "${score.label}"'
          : '\n本次行程综合评分：${score.score} 分，系统评语：「${score.label}」';
    }

    // 速度描述（debug/stationary 不调用 _describeSpeed）
    final String speedDesc;
    if (tripQuality == 'debug' || tripQuality == 'stationary') {
      speedDesc = _isEnglish ? 'zero — vehicle was completely stationary' : '全程静止，速度始终为零';
    } else {
      speedDesc = _describeSpeed(
        avgKmh: double.tryParse(meta['avg_speed_kmh'].toString()) ?? 0,
        maxKmh: (stats['max_speed_kmh'] as num?)?.toDouble() ?? 0,
        lowRatio: stats['low_speed_ratio'] as double? ?? 0,
        highRatio: stats['high_speed_ratio'] as double? ?? 0,
      );
    }

    // 行程质量说明文字（传递给 AI 的关键信号）
    final String qualityHint;
    if (_isEnglish) {
      qualityHint = switch (tripQuality) {
        'debug' => '⚠️ trip_quality=debug: Only ${durationSec}s long, GPS never moved, distance=$distanceKm km. Almost certainly a debug/test run, NOT a real drive.',
        'stationary' => '⚠️ trip_quality=stationary: Vehicle barely moved. Distance=$distanceKm km. May be parked, waiting, or a sensor test.',
        'ultra_short' => 'trip_quality=ultra_short: Very short micro-trip ($distanceKm km). Possibly moving a car or a quick errand.',
        'short' => 'trip_quality=short: Short trip ($distanceKm km). Quick neighborhood run.',
        _ => 'trip_quality=normal',
      };
    } else {
      qualityHint = switch (tripQuality) {
        'debug' => '⚠️ trip_quality=debug：行程仅 ${durationSec} 秒，GPS 完全静止，距离 $distanceKm km。极大概率是调试/测试记录，而非真实驾驶。',
        'stationary' => '⚠️ trip_quality=stationary：车辆几乎未移动，距离 $distanceKm km。可能是停车等待或传感器测试。',
        'ultra_short' => 'trip_quality=ultra_short：超短微出行（$distanceKm km），可能是挪车或去附近取个快递。',
        'short' => 'trip_quality=short：短途出行（$distanceKm km），楼下转一圈级别。',
        _ => 'trip_quality=normal',
      };
    }

    if (_isEnglish) {
      return '''Generate label + commentary for this trip. Output: {"label": "...", "commentary": "..."}

$qualityHint

Brand: ${meta['brand_name']}  Model: ${meta['car_model']}
City/Area: ${meta['city']}  Scenario: ${meta['scene']}
Duration: ${durationSec}s (${meta['duration_min']} min)  Distance: $distanceKm km
Speed: $speedDesc
$eventDesc${sampleEvents.isNotEmpty ? '\nSample events: $sampleEvents' : ''}$scoreContext''';
    }
    return '''请根据以下行程摘要生成吐感裁决 + 点评，输出格式：{"label": "...", "commentary": "..."}

$qualityHint

品牌：${meta['brand_name']}  车型：${meta['car_model']}
城市：${meta['city']}  场景：${meta['scene']}
时长：${durationSec} 秒（${meta['duration_min']} 分钟）  距离：$distanceKm km
速度特征：$speedDesc
$eventDesc${sampleEvents.isNotEmpty ? '\n代表事件：$sampleEvents' : ''}$scoreContext''';
  }

  // ─── 调用 Qwen API，解析 JSON 响应为 AiContent ─────────────
  Future<AiContent?> _callQwen(String userPrompt) async {
    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'model': _model,
            'max_tokens': _maxTokens,
            'temperature': 0.88, // 高一点让点评更有趣，但不失准确
            'messages': [
              {'role': 'system', 'content': _getSystemPrompt()},
              {'role': 'user', 'content': userPrompt},
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      debugPrint('[AI] HTTP error ${response.statusCode}: ${response.body}');
      throw Exception('Qwen API error: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final raw = (data['choices']?[0]?['message']?['content'] as String?)?.trim();
    if (raw == null || raw.isEmpty) return null;

    return _parseAiResponse(raw);
  }

  /// 从 AI 返回的原始文本中解析 AiContent
  ///
  /// AI 应输出纯 JSON，但偶尔会加 markdown 代码块或前置文字，做鲁棒解析。
  AiContent? _parseAiResponse(String raw) {
    try {
      // 去掉 markdown 代码块（```json ... ``` 或 ``` ... ```）
      var text = raw
          .replaceAll(RegExp(r'```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'```\s*', multiLine: true), '')
          .trim();

      // 找到 JSON 对象边界
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start < 0 || end <= start) {
        debugPrint('[AI] No JSON object found, raw: $raw');
        // 降级：把整段文字当 commentary，label 为空
        return AiContent(label: '', commentary: raw.trim());
      }

      final parsed = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      final label = (parsed['label'] as String? ?? '').trim();
      final commentary = (parsed['commentary'] as String? ?? '').trim();

      if (commentary.isEmpty) {
        debugPrint('[AI] Empty commentary in JSON: $raw');
        return null;
      }

      return AiContent(label: label, commentary: commentary);
    } catch (e) {
      debugPrint('[AI] JSON parse error: $e, raw: $raw');
      // 降级：把整段文字当 commentary
      return AiContent(label: '', commentary: raw.trim());
    }
  }

  // ─── 速度分布转自然语言描述 ──────────────────────────────────
  // 避免把"低速占比 0%""最高速 115"等数字直接丢给 AI，
  // AI 往往会生硬地把数字嵌进点评，造成读不懂的表达。
  // 注意：debug/stationary 场景由调用方提前处理，此函数只处理有实际行驶的场景。
  String _describeSpeed({
    required double avgKmh,
    required double maxKmh,
    required double lowRatio,
    required double highRatio,
  }) {
    // 速度几乎为零但又不是 debug 场景（如极慢挪车）
    if (avgKmh < 1 && maxKmh < 5) {
      return _isEnglish
          ? 'near-zero speed throughout (${maxKmh.toStringAsFixed(0)} km/h peak)'
          : '全程几乎静止（峰值 ${maxKmh.toStringAsFixed(0)} km/h）';
    }

    final parts = <String>[];
    final hasHighwaySection = maxKmh >= 90;
    final hasMidSpeed = maxKmh >= 60;
    final sep = _isEnglish ? ', ' : '，';

    if (avgKmh < 15) {
      if (hasHighwaySection) {
        parts.add(_isEnglish
            ? 'stop-and-go with highway (avg ${avgKmh.toStringAsFixed(0)} km/h, peak ${maxKmh.toStringAsFixed(0)} km/h)'
            : '走走停停夹着高速路段（均速 ${avgKmh.toStringAsFixed(0)} km/h，峰值 ${maxKmh.toStringAsFixed(0)} km/h）');
      } else {
        parts.add(_isEnglish ? 'low-speed crawl (avg ${avgKmh.toStringAsFixed(0)} km/h)' : '全程低速蠕行（均速 ${avgKmh.toStringAsFixed(0)} km/h）');
        if (hasMidSpeed) parts.add(_isEnglish ? 'occasionally ${maxKmh.toStringAsFixed(0)} km/h' : '偶尔加速到 ${maxKmh.toStringAsFixed(0)} km/h');
      }
    } else if (avgKmh < 35) {
      if (hasHighwaySection) {
        parts.add(_isEnglish
            ? 'urban + highway (avg ${avgKmh.toStringAsFixed(0)} km/h, peak ${maxKmh.toStringAsFixed(0)} km/h)'
            : '城市拥堵夹高速路段（均速 ${avgKmh.toStringAsFixed(0)} km/h，峰值 ${maxKmh.toStringAsFixed(0)} km/h）');
      } else {
        parts.add(_isEnglish ? 'urban stop-and-go (avg ${avgKmh.toStringAsFixed(0)} km/h)' : '城市走走停停（均速 ${avgKmh.toStringAsFixed(0)} km/h）');
        if (hasMidSpeed) parts.add(_isEnglish ? 'max ${maxKmh.toStringAsFixed(0)} km/h' : '最高达 ${maxKmh.toStringAsFixed(0)} km/h');
      }
    } else if (avgKmh < 60) {
      parts.add(_isEnglish ? 'moderate pace (avg ${avgKmh.toStringAsFixed(0)} km/h)' : '节奏尚可（均速 ${avgKmh.toStringAsFixed(0)} km/h）');
      if (hasHighwaySection) parts.add(_isEnglish ? 'peak ${maxKmh.toStringAsFixed(0)} km/h' : '峰值 ${maxKmh.toStringAsFixed(0)} km/h');
      else if (hasMidSpeed) parts.add(_isEnglish ? 'max ${maxKmh.toStringAsFixed(0)} km/h' : '最高 ${maxKmh.toStringAsFixed(0)} km/h');
    } else {
      parts.add(_isEnglish ? 'smooth flow (avg ${avgKmh.toStringAsFixed(0)} km/h)' : '畅行为主（均速 ${avgKmh.toStringAsFixed(0)} km/h）');
      if (hasHighwaySection) parts.add(_isEnglish ? 'peak ${maxKmh.toStringAsFixed(0)} km/h' : '峰值 ${maxKmh.toStringAsFixed(0)} km/h');
    }
    if (avgKmh >= 35) {
      if (lowRatio > 0.5) parts.add(_isEnglish ? 'heavy traffic' : '大半时间在堵车');
      else if (lowRatio > 0.3) parts.add(_isEnglish ? 'noticeable congestion' : '途中有明显拥堵');
    }
    return parts.join(sep);
  }

  // ─── 事件类型名称（中/英）────────────────────────────────────
  String _eventTypeName(String type) {
    if (_isEnglish) {
      return switch (type) {
        'jerk' => 'jerk',
        'rapidDeceleration' => 'hard brake',
        'rapidAcceleration' => 'hard acceleration',
        'bump' => 'bump',
        'wobble' => 'wobble',
        'proDisengagement' => 'disengagement',
        'proViolation' => 'violation',
        'proExperience' => 'bad experience',
        'manual' => 'manual',
        _ => type,
      };
    }
    return switch (type) {
      'jerk' => '顿挫',
      'rapidDeceleration' => '急刹',
      'rapidAcceleration' => '急加速',
      'bump' => '颠簸',
      'wobble' => '摇摆',
      'proDisengagement' => '接管',
      'proViolation' => '违规',
      'proExperience' => '差体验',
      'manual' => '手动标记',
      _ => type,
    };
  }
}
