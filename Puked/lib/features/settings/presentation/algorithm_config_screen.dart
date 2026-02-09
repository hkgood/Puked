import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/services/algorithm_config_service.dart';
import 'package:puked/features/recording/domain/algorithm_config.dart';

import 'package:puked/features/auth/providers/auth_provider.dart';

class AlgorithmConfigScreen extends ConsumerWidget {
  const AlgorithmConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final config = ref.watch(algorithmConfigProvider);
    final authState = ref.watch(authProvider);
    final isSuperUser = authState.isSuperUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 进入页面时尝试静默刷新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(algorithmConfigProvider.notifier).fetchAndSync();
    });

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          i18n.t('algorithm_settings_title'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: colorScheme.primary, size: 22),
            onPressed: () => _handleSync(context, ref, i18n, config),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildVersionStatus(context, config, i18n),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildGroup(
                  context,
                  i18n.t('trigger_sensitivity'),
                  [
                    _buildItem(
                      i18n.t('threshold_accel_label'),
                      config.thresholdAccel,
                      'm/s²',
                      subtitle: i18n.t('threshold_accel_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'thresholdAccel', config.thresholdAccel)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('threshold_decel_label'),
                      config.thresholdDecel,
                      'm/s²',
                      subtitle: i18n.t('threshold_decel_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'thresholdDecel', config.thresholdDecel)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('threshold_wobble_span_label'),
                      config.thresholdWobbleSpan,
                      'm/s²',
                      subtitle: i18n.t('threshold_wobble_span_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'thresholdWobbleSpan', config.thresholdWobbleSpan)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('threshold_bump_label'),
                      config.thresholdBump,
                      'm/s²',
                      subtitle: i18n.t('threshold_bump_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'thresholdBump', config.thresholdBump)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('threshold_jerk_label'),
                      config.thresholdJerk,
                      'm/s³',
                      subtitle: i18n.t('threshold_jerk_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'thresholdJerk', config.thresholdJerk)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('min_accel_for_jerk_label'),
                      config.minAccelForJerk,
                      'm/s²',
                      subtitle: i18n.t('min_accel_for_jerk_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'minAccelForJerk', config.minAccelForJerk)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('threshold_pitch_label'),
                      config.thresholdPitch,
                      '°/s',
                      subtitle: i18n.t('threshold_pitch_hint'),
                      isLast: true,
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'thresholdPitch', config.thresholdPitch)
                          : null,
                    ),
                  ],
                ),
                _buildGroup(
                  context,
                  i18n.t('trigger_duration'),
                  [
                    _buildItem(
                      i18n.t('jerk_window_ms_label'),
                      config.jerkWindowMs,
                      'ms',
                      subtitle: i18n.t('jerk_window_ms_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'jerkWindowMs', config.jerkWindowMs)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('accel_decel_window_ms_label'),
                      config.accelDecelWindowMs,
                      'ms',
                      subtitle: i18n.t('accel_decel_window_ms_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'accelDecelWindowMs', config.accelDecelWindowMs)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('wobble_window_ms_label'),
                      config.wobbleWindowMs,
                      'ms',
                      subtitle: i18n.t('wobble_window_ms_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'wobbleWindowMs', config.wobbleWindowMs)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('fusion_window_ms_label'),
                      config.fusionWindowMs,
                      'ms',
                      subtitle: i18n.t('fusion_window_ms_hint'),
                      isLast: true,
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'fusionWindowMs', config.fusionWindowMs)
                          : null,
                    ),
                  ],
                ),
                _buildGroup(
                  context,
                  i18n.t('false_positive_suppression'),
                  [
                    _buildItem(
                      i18n.t('max_jerk_allowed_label'),
                      config.maxJerkAllowed,
                      'm/s³',
                      subtitle: i18n.t('max_jerk_allowed_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'maxJerkAllowed', config.maxJerkAllowed)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('max_accel_allowed_label'),
                      config.maxAccelAllowed,
                      'm/s²',
                      subtitle: i18n.t('max_accel_allowed_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'maxAccelAllowed', config.maxAccelAllowed)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('max_wobble_span_allowed_label'),
                      config.maxWobbleSpanAllowed,
                      'm/s²',
                      subtitle: i18n.t('max_wobble_span_allowed_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(
                              context,
                              ref,
                              i18n,
                              'maxWobbleSpanAllowed',
                              config.maxWobbleSpanAllowed)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('max_bump_allowed_label'),
                      config.maxBumpAllowed,
                      'm/s²',
                      subtitle: i18n.t('max_bump_allowed_hint'),
                      isLast: true,
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'maxBumpAllowed', config.maxBumpAllowed)
                          : null,
                    ),
                  ],
                ),
                _buildGroup(
                  context,
                  i18n.t('logic_section'),
                  [
                    _buildItem(
                      i18n.t('zy_interference_threshold_label'),
                      config.zyInterferenceThreshold,
                      'G',
                      subtitle: i18n.t('zy_interference_threshold_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(
                              context,
                              ref,
                              i18n,
                              'zyInterferenceThreshold',
                              config.zyInterferenceThreshold)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('zx_interference_threshold_label'),
                      config.zxInterferenceThreshold,
                      'G',
                      subtitle: i18n.t('zx_interference_threshold_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(
                              context,
                              ref,
                              i18n,
                              'zxInterferenceThreshold',
                              config.zxInterferenceThreshold)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('coupling_curve_index_label'),
                      config.couplingCurveIndex,
                      '',
                      subtitle: i18n.t('coupling_curve_index_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'couplingCurveIndex', config.couplingCurveIndex)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('coupling_strength_y_label'),
                      config.couplingStrengthY,
                      '',
                      subtitle: i18n.t('coupling_strength_y_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'couplingStrengthY', config.couplingStrengthY)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('coupling_strength_x_label'),
                      config.couplingStrengthX,
                      '',
                      subtitle: i18n.t('coupling_strength_x_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'couplingStrengthX', config.couplingStrengthX)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('turn_comp_multiplier_label'),
                      config.turnCompMultiplier,
                      '',
                      subtitle: i18n.t('turn_comp_multiplier_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'turnCompMultiplier', config.turnCompMultiplier)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('turn_comp_max_label'),
                      config.turnCompMax,
                      'x',
                      subtitle: i18n.t('turn_comp_max_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'turnCompMax', config.turnCompMax)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('event_window_coverage_label'),
                      config.eventWindowCoverage,
                      '',
                      subtitle: i18n.t('event_window_coverage_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'eventWindowCoverage', config.eventWindowCoverage)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('low_speed_jerk_limit_label'),
                      config.lowSpeedJerkLimit,
                      'km/h',
                      subtitle: i18n.t('low_speed_jerk_limit_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'lowSpeedJerkLimit', config.lowSpeedJerkLimit)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('pitch_validation_enabled_label'),
                      config.pitchValidationEnabled ? 'ON' : 'OFF',
                      '',
                      subtitle: i18n.t('pitch_validation_enabled_hint'),
                      onTap: isSuperUser
                          ? () {
                              final newConfig = config.copyWith(
                                  pitchValidationEnabled:
                                      !config.pitchValidationEnabled);
                              ref
                                  .read(algorithmConfigProvider.notifier)
                                  .updateConfig(newConfig);
                            }
                          : null,
                    ),
                    _buildItem(
                      i18n.t('speed_low_factor_label'),
                      config.speedLowFactor,
                      'x',
                      subtitle: i18n.t('speed_low_factor_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'speedLowFactor', config.speedLowFactor)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('speed_high_factor_label'),
                      config.speedHighFactor,
                      'x',
                      subtitle: i18n.t('speed_high_factor_hint'),
                      isLast: true,
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'speedHighFactor', config.speedHighFactor)
                          : null,
                    ),
                  ],
                ),
                _buildGroup(
                  context,
                  i18n.t('trend_filter_section'),
                  [
                    _buildItem(
                      i18n.t('enable_trend_filter_label'),
                      config.enableTrendFilter ? 'ON' : 'OFF',
                      '',
                      subtitle: i18n.t('enable_trend_filter_hint'),
                      onTap: isSuperUser
                          ? () {
                              final newConfig = config.copyWith(
                                  enableTrendFilter: !config.enableTrendFilter);
                              ref
                                  .read(algorithmConfigProvider.notifier)
                                  .updateConfig(newConfig);
                            }
                          : null,
                    ),
                    _buildItem(
                      i18n.t('trend_change_threshold_label'),
                      config.trendChangeThreshold,
                      '',
                      subtitle: i18n.t('trend_change_threshold_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(
                              context,
                              ref,
                              i18n,
                              'trendChangeThreshold',
                              config.trendChangeThreshold)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('min_std_dev_threshold_label'),
                      config.minStdDevThreshold,
                      '',
                      subtitle: i18n.t('min_std_dev_threshold_hint'),
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'minStdDevThreshold', config.minStdDevThreshold)
                          : null,
                    ),
                    _buildItem(
                      i18n.t('min_range_threshold_label'),
                      config.minRangeThreshold,
                      'm/s²',
                      subtitle: i18n.t('min_range_threshold_hint'),
                      isLast: true,
                      onTap: isSuperUser
                          ? () => _showEditDialog(context, ref, i18n,
                              'minRangeThreshold', config.minRangeThreshold)
                          : null,
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref, I18n i18n,
      String field, dynamic currentValue) async {
    final controller = TextEditingController(text: currentValue.toString());
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${i18n.t('edit')} ${field}"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: i18n.t('value'),
            hintText: currentValue.toString(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(i18n.t('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(i18n.t('save')),
          ),
        ],
      ),
    );

    if (result == true) {
      final newValue = double.tryParse(controller.text);
      if (newValue != null) {
        try {
          final config = ref.read(algorithmConfigProvider);
          AlgorithmConfig newConfig;
          switch (field) {
            case 'thresholdAccel':
              newConfig = config.copyWith(thresholdAccel: newValue);
              break;
            case 'thresholdDecel':
              newConfig = config.copyWith(thresholdDecel: newValue);
              break;
            case 'thresholdWobbleSpan':
              newConfig = config.copyWith(thresholdWobbleSpan: newValue);
              break;
            case 'thresholdBump':
              newConfig = config.copyWith(thresholdBump: newValue);
              break;
            case 'thresholdJerk':
              newConfig = config.copyWith(thresholdJerk: newValue);
              break;
            case 'thresholdPitch':
              newConfig = config.copyWith(thresholdPitch: newValue);
              break;
            case 'jerkWindowMs':
              newConfig = config.copyWith(jerkWindowMs: newValue.toInt());
              break;
            case 'accelDecelWindowMs':
              newConfig = config.copyWith(accelDecelWindowMs: newValue.toInt());
              break;
            case 'wobbleWindowMs':
              newConfig = config.copyWith(wobbleWindowMs: newValue.toInt());
              break;
            case 'fusionWindowMs':
              newConfig = config.copyWith(fusionWindowMs: newValue.toInt());
              break;
            case 'maxJerkAllowed':
              newConfig = config.copyWith(maxJerkAllowed: newValue);
              break;
            case 'maxAccelAllowed':
              newConfig = config.copyWith(maxAccelAllowed: newValue);
              break;
            case 'maxWobbleSpanAllowed':
              newConfig = config.copyWith(maxWobbleSpanAllowed: newValue);
              break;
            case 'maxBumpAllowed':
              newConfig = config.copyWith(maxBumpAllowed: newValue);
              break;
            case 'zyInterferenceThreshold':
              newConfig = config.copyWith(zyInterferenceThreshold: newValue);
              break;
            case 'zxInterferenceThreshold':
              newConfig = config.copyWith(zxInterferenceThreshold: newValue);
              break;
            case 'couplingCurveIndex':
              newConfig = config.copyWith(couplingCurveIndex: newValue);
              break;
            case 'couplingStrengthY':
              newConfig = config.copyWith(couplingStrengthY: newValue);
              break;
            case 'couplingStrengthX':
              newConfig = config.copyWith(couplingStrengthX: newValue);
              break;
            case 'turnCompMultiplier':
              newConfig = config.copyWith(turnCompMultiplier: newValue);
              break;
            case 'turnCompMax':
              newConfig = config.copyWith(turnCompMax: newValue);
              break;
            case 'eventWindowCoverage':
              newConfig = config.copyWith(eventWindowCoverage: newValue);
              break;
            case 'lowSpeedJerkLimit':
              newConfig = config.copyWith(lowSpeedJerkLimit: newValue);
              break;
            case 'speedLowFactor':
              newConfig = config.copyWith(speedLowFactor: newValue);
              break;
            case 'speedHighFactor':
              newConfig = config.copyWith(speedHighFactor: newValue);
              break;
            case 'minAccelForJerk':
              newConfig = config.copyWith(minAccelForJerk: newValue);
              break;
            case 'trendChangeThreshold':
              newConfig = config.copyWith(trendChangeThreshold: newValue);
              break;
            case 'minStdDevThreshold':
              newConfig = config.copyWith(minStdDevThreshold: newValue);
              break;
            case 'minRangeThreshold':
              newConfig = config.copyWith(minRangeThreshold: newValue);
              break;
            default:
              return;
          }
          await ref
              .read(algorithmConfigProvider.notifier)
              .updateConfig(newConfig);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(i18n.t('save_success')),
                  backgroundColor: Colors.green),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(i18n.t('algorithm_update_failed')),
                  backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  Future<void> _handleSync(BuildContext context, WidgetRef ref, I18n i18n,
      AlgorithmConfig config) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(i18n.t('syncing')),
          behavior: SnackBarBehavior.floating),
    );
    try {
      await ref.read(algorithmConfigProvider.notifier).fetchAndSync();
      // 获取同步后的最新状态
      final updatedConfig = ref.read(algorithmConfigProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(i18n.t('algorithm_update_success',
                args: ['${updatedConfig.version}'])),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(i18n.t('algorithm_update_failed')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildVersionStatus(
      BuildContext context, AlgorithmConfig config, I18n i18n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done_rounded,
                    size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  "Version ${config.version}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "${i18n.t('algorithm_updated_at')}: ${config.updatedAt.split('T')[0]}",
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.4),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, String title, List<Widget> items) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8, top: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Column(children: items),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildItem(String label, dynamic value, String unit,
      {String? subtitle, bool isLast = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "$value",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 2),
                      Text(
                        unit,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                    if (onTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.edit_rounded,
                          size: 14, color: Colors.grey.withOpacity(0.5)),
                    ],
                  ],
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
            if (!isLast)
              Transform.translate(
                offset: const Offset(0, 15),
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.grey.withOpacity(0.15),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
