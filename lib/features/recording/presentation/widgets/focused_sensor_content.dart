import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/common/config/constants.dart';
import 'package:puked/common/widgets/g_force_ball.dart';
import 'package:puked/common/widgets/sensor_waveform.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'dart:collection';

class FocusedSensorContent extends ConsumerWidget {
  final bool noMargin;
  final bool isLandscape;
  final VoidCallback onTap;

  const FocusedSensorContent({
    super.key,
    this.noMargin = false,
    this.isLandscape = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorDataAsync = ref.watch(sensorStreamProvider);
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      key: ValueKey('focused_sensor_${isLandscape ? 'land' : 'port'}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: AppConstants.glassBlurSigma,
              sigmaY: AppConstants.glassBlurSigma),
          child: Container(
            margin: noMargin
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(isLandscape ? 12 : 16),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white)
                  .withValues(alpha: 0.5),
              borderRadius:
                  BorderRadius.circular(AppConstants.defaultBorderRadius),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1), width: 0.5),
              boxShadow: [
                if (isLandscape)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
              ],
            ),
            child: sensorDataAsync.maybeWhen(
              data: (data) {
                final gX = data.processedAccel.x / AppConstants.gravity;
                final gY = data.processedAccel.y / AppConstants.gravity;
                final gZ = (data.processedAccel.z - AppConstants.gravity) /
                    AppConstants.gravity;

                return Column(
                  children: [
                    Row(
                      children: [
                        GForceBall(
                          acceleration: data.processedAccel,
                          gyroscope: data.gyroscope,
                          size: isLandscape ? 56 : 64,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildGValueRow(
                                  "X (LAT)", gX, const Color(0xFFE57373)),
                              const SizedBox(height: 2),
                              _buildGValueRow(
                                  "Y (LONG)", gY, const Color(0xFF81C784)),
                              const SizedBox(height: 2),
                              _buildGValueRow(
                                  "Z (VERT)", gZ, const Color(0xFF64B5F6)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isLandscape ? 8 : 12),
                    Expanded(
                      flex: 6,
                      child: SensorWaveformSection(
                        data: data,
                        l10n: l10n,
                        showAxes: true,
                        isLandscape: isLandscape,
                      ),
                    ),
                  ],
                );
              },
              orElse: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGValueRow(String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.7),
                letterSpacing: 0.5)),
        Text("${value >= 0 ? '+' : ''}${value.toStringAsFixed(3)}G",
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
                fontFamily: 'monospace')),
      ],
    );
  }
}

class SensorWaveformSection extends StatefulWidget {
  final dynamic data;
  final AppLocalizations l10n;
  final bool isLandscape;
  final bool showAxes;

  const SensorWaveformSection({
    super.key,
    required this.data,
    required this.l10n,
    this.isLandscape = false,
    this.showAxes = false,
  });

  @override
  State<SensorWaveformSection> createState() => _SensorWaveformSectionState();
}

class _SensorWaveformSectionState extends State<SensorWaveformSection> {
  final ListQueue<double> _accelXHistory = ListQueue<double>();
  final ListQueue<double> _accelYHistory = ListQueue<double>();

  @override
  void didUpdateWidget(SensorWaveformSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_accelXHistory.length >= AppConstants.sensorHistoryLimit) {
      _accelXHistory.removeFirst();
    }
    if (_accelYHistory.length >= AppConstants.sensorHistoryLimit) {
      _accelYHistory.removeFirst();
    }
    _accelXHistory.add(widget.data.processedAccel.x / AppConstants.gravity);
    _accelYHistory.add(widget.data.processedAccel.y / AppConstants.gravity);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: SensorWaveform(
            data: _accelYHistory.toList(),
            color: Theme.of(context).colorScheme.primary,
            label: widget.isLandscape ? '' : widget.l10n.longitudinal,
            limit: 1.5,
            showAxes: widget.showAxes,
          ),
        ),
        SizedBox(height: widget.showAxes ? 16 : 8),
        Expanded(
          child: SensorWaveform(
            data: _accelXHistory.toList(),
            color: Theme.of(context).colorScheme.secondary,
            label: widget.isLandscape ? '' : widget.l10n.lateral,
            limit: 1.5,
            showAxes: widget.showAxes,
          ),
        ),
      ],
    );
  }
}
