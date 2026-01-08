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
            icon: Icon(Icons.refresh_rounded, color: colorScheme.primary, size: 22),
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
                      onTap: isSuperUser ? () => _showEditDialog(context, ref, i18n, 'thresholdAccel', config.thresholdAccel) : null,
                    ),
                    _buildItem(
                      i18n.t('threshold_decel_label'),
                      config.thresholdDecel,
                      'm/s²',
                      onTap: isSuperUser ? () => _showEditDialog(context, ref, i18n, 'thresholdDecel', config.thresholdDecel) : null,
                    ),
                    _buildItem(
                      i18n.t('threshold_wobble_span_label'),
                      config.thresholdWobbleSpan,
                      'm/s²',
                      onTap: isSuperUser ? () => _showEditDialog(context, ref, i18n, 'thresholdWobbleSpan', config.thresholdWobbleSpan) : null,
                    ),
                    _buildItem(
                      i18n.t('threshold_bump_label'),
                      config.thresholdBump,
                      'm/s²',
                      onTap: isSuperUser ? () => _showEditDialog(context, ref, i18n, 'thresholdBump', config.thresholdBump) : null,
                    ),
                    _buildItem(
                      i18n.t('threshold_jerk_label'),
                      config.thresholdJerk,
                      'm/s³',
                      onTap: isSuperUser ? () => _showEditDialog(context, ref, i18n, 'thresholdJerk', config.thresholdJerk) : null,
                    ),
                    _buildItem(i18n.t('threshold_pitch_label'), config.thresholdPitch, '°/s', isLast: true),
                  ],
                ),
                _buildGroup(
                  context,
                  i18n.t('trigger_duration'),
                  [
                    _buildItem(i18n.t('jerk_window_ms_label'), config.jerkWindowMs, 'ms'),
                    _buildItem(i18n.t('accel_decel_window_ms_label'), config.accelDecelWindowMs, 'ms'),
                    _buildItem(i18n.t('wobble_window_ms_label'), config.wobbleWindowMs, 'ms'),
                    _buildItem(i18n.t('fusion_window_ms_label'), config.fusionWindowMs, 'ms', isLast: true),
                  ],
                ),
                _buildGroup(
                  context,
                  i18n.t('false_positive_suppression'),
                  [
                    _buildItem(i18n.t('max_jerk_allowed_label'), config.maxJerkAllowed, 'm/s³'),
                    _buildItem(i18n.t('max_accel_allowed_label'), config.maxAccelAllowed, 'm/s²'),
                    _buildItem(i18n.t('max_wobble_span_allowed_label'), config.maxWobbleSpanAllowed, 'm/s²'),
                    _buildItem(i18n.t('max_bump_allowed_label'), config.maxBumpAllowed, 'm/s²', isLast: true),
                  ],
                ),
                _buildGroup(
                  context,
                  i18n.t('核心逻辑 (Logic)'),
                  [
                    _buildItem(i18n.t('zy_interference_threshold_label'), config.zyInterferenceThreshold, 'G'),
                    _buildItem(i18n.t('pitch_validation_enabled_label'), config.pitchValidationEnabled ? 'ON' : 'OFF', ''),
                    _buildItem(i18n.t('speed_low_factor_label'), config.speedLowFactor, 'x'),
                    _buildItem(i18n.t('speed_high_factor_label'), config.speedHighFactor, 'x', isLast: true),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref, I18n i18n, String field, dynamic currentValue) async {
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(i18n.t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
            default:
              return;
          }
          await ref.read(algorithmConfigProvider.notifier).updateConfig(newConfig);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(i18n.t('save_success')), backgroundColor: Colors.green),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(i18n.t('algorithm_update_failed')), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  Future<void> _handleSync(BuildContext context, WidgetRef ref, I18n i18n, AlgorithmConfig config) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(i18n.t('syncing')), behavior: SnackBarBehavior.floating),
    );
    try {
      await ref.read(algorithmConfigProvider.notifier).fetchAndSync();
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(i18n.t('algorithm_update_success', args: ['${config.version}'])),
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

  Widget _buildVersionStatus(BuildContext context, AlgorithmConfig config, I18n i18n) {
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
                Icon(Icons.cloud_done_rounded, size: 16, color: colorScheme.primary),
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
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Column(children: items),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildItem(String label, dynamic value, String unit, {bool isLast = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
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
                        fontWeight: FontWeight.w600,
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
                      Icon(Icons.edit_rounded, size: 14, color: Colors.grey.withOpacity(0.5)),
                    ],
                  ],
                ),
              ],
            ),
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
