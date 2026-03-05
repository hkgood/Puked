import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:puked/models/db_models.dart';

/// 从 app [Locale] 得到分数短评语言
ScoreLabelLanguage scoreLabelLanguageFromLocale(dynamic locale) {
  if (locale == null) return ScoreLabelLanguage.zh;
  final code = locale is Locale ? locale.languageCode : locale.toString();
  return code == 'en' ? ScoreLabelLanguage.en : ScoreLabelLanguage.zh;
}

/// 用于分数短评的显示语言（与 app 设置一致）
enum ScoreLabelLanguage { zh, en }

/// 行程舒适度评分结果
class TripScore {
  final int score; // 0～100
  final String label; // 留几手风格短评
  final Color color; // 根据分数平滑插值的颜色

  const TripScore({
    required this.score,
    required this.label,
    required this.color,
  });
}

/// 行程舒适度评分计算器（全本地、全确定性）
///
/// ══ 仅统计自动检测的舒适度事件 ══════════════════════════════════════
///   顿挫(jerk)、急刹(rapidDeceleration)、急加速(rapidAcceleration)、
///   颠簸(bump)、摇摆(wobble)
///   接管 / 违规 / 差体验 / manual 为手动触发，不影响舒适度评分。
///
/// ══ 评分公式 ═══════════════════════════════════════════════════════
///
/// 【分量 1】事件扣分（最多 80 分）
///   rawPenalty   = Σ (count × weight)
///   ──────────────────────────────────────────────────────────────
///   关键设计：用「平方根距离归一化」而非线性除以距离。
///   线性归一化在长途行程（60+ km）中过于宽容——8个颠簸在 66km 只
///   产生 0.74/km 密度，扣分极少。
///   改为 rawPenalty / √distanceKm × K，宽容度随里程增加，但比线性慢，
///   长途行程仍会受到合理惩罚。
///   ──────────────────────────────────────────────────────────────
///   eventPenalty = clamp(rawPenalty / √(max(distanceKm,1)) × 6.5, 0, 80)
///
/// 【分量 2】加速度波动率扣分（最多 20 分，需轨迹数据）
///   从轨迹点 ay（纵向加速度）计算 MAD（平均绝对偏差）
///   基线 0.18 m/s²，每超 0.1 扣 3 分，最多扣 20 分
///   ay 点 < 30 个时跳过
///
/// finalScore = clamp(100 − eventPenalty − smoothnessPenalty, 0, 100)
///
/// ══ 典型场景验证（K=6.5） ════════════════════════════════════════════
///   30km，8 颠簸，          MAD≈0.20  →  eventP≈47，smooth≈1   → ~52
///   300km，8 颠簸，         MAD≈0.20  →  eventP≈15，smooth≈1   → ~84
///   66km，8 颠簸+1急刹，    MAD≈0.20  →  eventP≈39，smooth≈1   → ~60
///   62km，3 急减速，        MAD≈0.18  →  eventP≈22，smooth≈0   → ~78
///   10km，1 顿挫，          MAD≈0.25  →  eventP≈24，smooth≈2   → ~74
///   10km，5 顿挫，          MAD≈0.50  →  eventP≈78，smooth≈10  → ~12
class TripScoreCalculator {
  // ─── 舒适度事件权重 ──────────────────────────────────────────────
  static const Map<String, int> _weights = {
    'jerk': 12, // 顿挫：非预期抖动，乘客最难受
    'rapidDeceleration': 9, // 急刹
    'rapidAcceleration': 7, // 急加速
    'bump': 5, // 颠簸（路面因素居多）
    'wobble': 5, // 摇摆
  };

  // ─── 事件扣分系数 ─────────────────────────────────────────────────
  // √归一化基准：以 10km 行程为直觉参考，K=6.5 时：
  //   10km + 1 顿挫 → rawP=12, penalty=12/√10×6.5=24.7 → 75分
  //   10km + 5 顿挫 → rawP=60, penalty=60/√10×6.5=123→cap80 → ~20分
  //   30km + 8 颠簸 → rawP=40, penalty=40/√30×6.5=47.5 → ~52分（符合预期）
  //   300km + 8 颠簸 → rawP=40, penalty=40/√300×6.5=15.0 → ~85分（合理）
  //   66km + 8 颠簸+1急刹 → rawP=49, penalty=49/√66×6.5=39.2 → ~61分
  static const double _sqrtK = 6.5;
  static const double _eventPenaltyCap = 80.0;

  // ─── 平滑度参数 ───────────────────────────────────────────────────
  static const double _madBaseline = 0.18; // m/s²，低于此值不扣分
  static const double _madFactor = 30.0; // 每超 1 m/s² MAD 扣 30 分
  static const double _madPenaltyCap = 20.0; // 平滑度扣分上限
  static const int _minAyPoints = 30; // ay 点数门槛
  static const int _maxAySamples = 300; // 降采样上限（避免卡顿）

  // ─── 对外接口 ────────────────────────────────────────────────────

  /// [language] 为 null 时默认中文。可用 [languageFromLocale] 从 app locale 转换。
  static TripScore calculate(Trip trip, {ScoreLabelLanguage? language}) {
    final distanceKm = trip.displayDistance;
    final breakdown = _extractBreakdown(trip.eventStats);
    final eventPenalty = _calcEventPenalty(breakdown, distanceKm);
    final smoothnessPenalty = trip.trajectory.isLoaded
        ? _calcSmoothnessPenalty(trip.trajectory.toList())
        : 0.0;
    return _build(eventPenalty + smoothnessPenalty, language ?? ScoreLabelLanguage.zh);
  }

  // ─── 内部实现 ────────────────────────────────────────────────────

  static Map<String, int> _extractBreakdown(Map<String, dynamic>? stats) {
    final breakdown = <String, int>{};
    if (stats == null) return breakdown;
    final auto = stats['auto'] as Map<String, dynamic>? ?? {};
    auto.forEach((k, v) => breakdown[k] = (v as num?)?.toInt() ?? 0);
    // pro / manual 不参与舒适度评分，跳过
    return breakdown;
  }

  static double _calcEventPenalty(
      Map<String, int> breakdown, double distanceKm) {
    double rawPenalty = 0;
    breakdown.forEach((type, count) {
      rawPenalty += count * (_weights[type] ?? 0);
    });
    if (rawPenalty == 0) return 0;
    // 平方根距离归一化：比线性更保真——长途宽容，但宽容度收敛
    final sqrtDist = math.sqrt(math.max(distanceKm, 1.0));
    return (rawPenalty / sqrtDist * _sqrtK).clamp(0.0, _eventPenaltyCap);
  }

  static double _calcSmoothnessPenalty(List<TrajectoryPoint> points) {
    final ayRaw = <double>[];
    for (final p in points) {
      final ay = p.ay;
      if (ay != null && ay.abs() < 6.0) ayRaw.add(ay);
    }
    if (ayRaw.length < _minAyPoints) return 0.0;

    final sampled = _downsample(ayRaw, _maxAySamples);
    final mean = sampled.fold(0.0, (s, v) => s + v) / sampled.length;
    final mad =
        sampled.fold(0.0, (s, v) => s + (v - mean).abs()) / sampled.length;

    return ((mad - _madBaseline) * _madFactor).clamp(0.0, _madPenaltyCap);
  }

  static List<double> _downsample(List<double> src, int maxCount) {
    if (src.length <= maxCount) return src;
    final step = src.length / maxCount;
    final result = <double>[];
    for (int i = 0; i < maxCount; i++) {
      result.add(src[(i * step).round().clamp(0, src.length - 1)]);
    }
    return result;
  }

  static TripScore _build(double totalPenalty, ScoreLabelLanguage language) {
    final score = (100.0 - totalPenalty).clamp(0.0, 100.0).round();
    return TripScore(
      score: score,
      label: _label(score, language),
      color: _color(score),
    );
  }

  // ─── Puked 留几手风格「吐了没有」判决（中/英）──────────────────
  // 以「没吐→差点吐→吐了」的递进，配上留几手的干燥毒舌口吻
  static String _label(int score, ScoreLabelLanguage language) {
    if (language == ScoreLabelLanguage.en) {
      if (score >= 95) return 'Stomach never considered its options, not even once';
      if (score >= 87) return 'Stomach filed zero complaints, not even in draft';
      if (score >= 78) return 'Stomach had a thought, swallowed it, moved on';
      if (score >= 67) return 'Stomach started a complaint but gave up halfway';
      if (score >= 55) return 'Stomach is warming up — a few more bumps and it\'ll commit';
      if (score >= 40) return 'Stomach officially protested, didn\'t puke but it was close';
      if (score >= 25) return 'Stomach is drafting its resignation, not looking great';
      return 'Already puked, no further questions';
    }
    if (score >= 95) return '没吐，甚至连想都没想过，这趟坐得很有尊严';
    if (score >= 87) return '没吐，胃表示这趟出行它全程没有工作';
    if (score >= 78) return '没吐，但胃考虑了一下，最后咽了回去';
    if (score >= 67) return '没吐，胃憋了半天投诉信，最终没投出去';
    if (score >= 55) return '没吐，但胃已经在热身了，再来几下可能就不一定了';
    if (score >= 40) return '差点吐，胃正式提出了抗议，目前还在可控范围内';
    if (score >= 25) return '差点吐，胃说它在认真考虑辞职，建议备好纸袋';
    return '吐了，不接受任何辩解';
  }

  // ─── 平滑颜色插值：绿(100) → 黄(70) → 红(0) ─────────────────────
  static Color _color(int score) {
    const green = Color(0xFF34C759);
    const yellow = Color(0xFFFFD60A);
    const red = Color(0xFFFF3B30);

    if (score >= 70) {
      // 70~100：黄色渐变到绿色
      final t = (score - 70) / 30.0;
      return Color.lerp(yellow, green, t)!;
    } else {
      // 0~70：红色渐变到黄色
      final t = score / 70.0;
      return Color.lerp(red, yellow, t)!;
    }
  }
}
