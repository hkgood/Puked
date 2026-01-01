import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:puked/common/widgets/trip_map_view.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/common/widgets/brand_logo.dart';
import 'package:puked/common/widgets/trip_acceleration_chart.dart';
import 'package:puked/features/recording/presentation/vehicle_info_screen.dart';
import 'package:puked/services/export/export_service.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/services/cloud_trip_service.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  LatLng? _focusedLocation;
  late Trip _currentTrip;

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _loadData();
  }

  Future<void> _loadData() async {
    // 确保轨迹和事件数据已加载
    if (!_currentTrip.trajectory.isLoaded || !_currentTrip.events.isLoaded) {
      await _currentTrip.trajectory.load();
      await _currentTrip.events.load();
      if (mounted) setState(() {});
    }
  }

  Future<void> _editVehicleInfo() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VehicleInfoScreen(tripId: _currentTrip.id, isEdit: true),
      ),
    );

    if (result == true && mounted) {
      // 重新加载数据
      final storage = ref.read(storageServiceProvider);
      final trips = await storage.getAllTrips();
      setState(() {
        _currentTrip = trips.firstWhere((t) => t.id == _currentTrip.id);
      });
    }
  }

  // 统一的标题样式
  TextStyle _headerStyle(BuildContext context) => TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 17,
        color: Theme.of(context).colorScheme.onSurface,
      );

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final trip = _currentTrip;
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(trip.startTime);
    final trajectory = trip.trajectory.toList();
    final events = trip.events.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          dateStr,
        ),
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          if (ref.watch(authProvider).isPro)
            _currentTrip.isUploaded
                ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_done,
                      color: Colors.green,
                      size: 24,
                    ),
                  )
                : IconButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(i18n.t('submit_trip')),
                          content: Text(i18n.t('submit_trip_confirm')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(i18n.t('cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(i18n.t('upload')),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(i18n.t('uploading'))),
                        );
                        try {
                          final cloudId = await ref
                              .read(cloudTripServiceProvider)
                              .uploadTrip(_currentTrip);
                          await ref
                              .read(storageServiceProvider)
                              .updateTripCloudId(_currentTrip.id, cloudId);

                          // 刷新本地状态
                          final updatedTrip = await ref
                              .read(storageServiceProvider)
                              .getTripById(_currentTrip.id);
                          if (updatedTrip != null && mounted) {
                            setState(() {
                              _currentTrip = updatedTrip;
                            });
                          }

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(i18n.t('upload_success')),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(i18n.t('upload_failed')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      Icons.cloud_upload_outlined,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
          IconButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(i18n.t('exporting')),
                  duration: const Duration(seconds: 1),
                ),
              );
              await ref.read(exportServiceProvider).exportTrip(trip);
            },
            icon: Icon(
              Icons.share_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        left: true,
        right: true,
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            children: [
              // 0. 车辆信息区域 (放入卡片)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Row(
                    children: [
                      BrandLogo(
                        brandName: trip.brand,
                        size: 52,
                        padding: 10,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (trip.carModel != null &&
                                      trip.carModel!.isNotEmpty)
                                  ? trip.carModel!
                                  : i18n.t('car_model'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            if (trip.softwareVersion != null &&
                                trip.softwareVersion!.isNotEmpty)
                              Text(
                                trip.softwareVersion!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _editVehicleInfo,
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: Text(i18n.t('edit'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 1. 轨迹地图展示 (移除卡片背景和描边，保持原样)
              Container(
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: TripMapView(
                    trajectory: trajectory,
                    events: events,
                    isLive: false,
                    focusPoint: _focusedLocation,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. 数据概览与图表合入同一张卡片
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: SizedBox(
                          height: 32, // 统一标题高度
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(i18n.t('trip_summary'),
                                  style: _headerStyle(context)),
                              Text(
                                "${(trip.distance / 1000).toStringAsFixed(2)} km",
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                              label: i18n.t('total_events'),
                              value: "${trip.eventCount}"),
                          _StatItem(
                            label: i18n.t('avg_speed'),
                            value: trip.endTime != null && trip.distance > 0
                                ? "${(trip.distance / 1000 / (trip.endTime!.difference(trip.startTime).inSeconds / 3600)).toStringAsFixed(1)} km/h"
                                : "--",
                          ),
                          _StatItem(
                              label: i18n.t('duration'),
                              value: trip.endTime != null
                                  ? "${trip.endTime!.difference(trip.startTime).inMinutes} ${i18n.t('min')}"
                                  : "--"),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TripAccelerationChart(
                        trajectory: trajectory,
                        label: i18n.t('longitudinal'),
                        color: Theme.of(context).colorScheme.primary,
                        isLongitudinal: true,
                      ),
                      const SizedBox(height: 16),
                      TripAccelerationChart(
                        trajectory: trajectory,
                        label: i18n.t('lateral'),
                        color: Theme.of(context).colorScheme.secondary,
                        isLongitudinal: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. 事件列表 (放入独立卡片)
              if (events.isNotEmpty)
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: SizedBox(
                          height: 32, // 统一标题高度
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(i18n.t('event_list'),
                                style: _headerStyle(context)),
                          ),
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: events.length,
                        separatorBuilder: (context, index) =>
                            const Divider(indent: 20, endIndent: 20, height: 1),
                        itemBuilder: (context, index) {
                          final e = events[index];
                          final typeLabel = i18n.t(e.type);
                          Color eventColor;
                          IconData eventIcon;

                          switch (e.type) {
                            case 'rapidAcceleration':
                              eventColor = const Color(0xFFFF9500);
                              eventIcon = Icons.speed;
                              break;
                            case 'rapidDeceleration':
                              eventColor = const Color(0xFFFF3B30);
                              eventIcon = Icons.trending_down;
                              break;
                            case 'jerk':
                              eventColor = const Color(0xFF5856D6);
                              eventIcon = Icons.priority_high;
                              break;
                            case 'bump':
                              eventColor = const Color(0xFFAF52DE);
                              eventIcon = Icons.vibration;
                              break;
                            case 'wobble':
                              eventColor = const Color(0xFF007AFF);
                              eventIcon = Icons.waves;
                              break;
                            case 'manual':
                              eventColor = const Color(0xFF34C759);
                              eventIcon = Icons.stars;
                              break;
                            default:
                              eventColor = Colors.grey;
                              eventIcon = Icons.event;
                          }

                          // 计算事件参数 (G值)
                          String parameter = "--";
                          if (e.sensorData.isNotEmpty) {
                            final magnitudes = e.sensorData.map((p) {
                              if (e.type == 'rapidAcceleration' ||
                                  e.type == 'rapidDeceleration') {
                                return (p.ay ?? 0).abs();
                              } else if (e.type == 'wobble') {
                                return (p.ax ?? 0).abs();
                              } else if (e.type == 'bump') {
                                return (p.az ?? 0).abs();
                              } else {
                                return math.sqrt((p.ax ?? 0) * (p.ax ?? 0) +
                                    (p.ay ?? 0) * (p.ay ?? 0) +
                                    (p.az ?? 0) * (p.az ?? 0));
                              }
                            }).toList();

                            double maxSmoothedVal = 0;
                            const windowSize = 3;

                            if (magnitudes.length >= windowSize) {
                              for (int i = 0;
                                  i <= magnitudes.length - windowSize;
                                  i++) {
                                double sum = 0;
                                for (int j = 0; j < windowSize; j++) {
                                  sum += magnitudes[i + j];
                                }
                                final avg = sum / windowSize;
                                if (avg > maxSmoothedVal) maxSmoothedVal = avg;
                              }
                            } else if (magnitudes.isNotEmpty) {
                              maxSmoothedVal =
                                  magnitudes.reduce((a, b) => a + b) /
                                      magnitudes.length;
                            }

                            double finalG = e.type == 'manual'
                                ? 0
                                : (maxSmoothedVal / 9.80665);
                            parameter = "${finalG.toStringAsFixed(2)} G";
                          }

                          return GestureDetector(
                            onLongPressStart: (_) async {
                              // 隐藏功能：长按 3 秒触发删除确认
                              final startTime = DateTime.now();
                              bool triggered = false;

                              // 使用 Timer 检查长按时长
                              Timer.periodic(const Duration(milliseconds: 500),
                                  (timer) async {
                                if (!triggered &&
                                    DateTime.now()
                                            .difference(startTime)
                                            .inSeconds >=
                                        3) {
                                  timer.cancel();
                                  triggered = true;

                                  // 触发触感反馈（如果可用）
                                  if (!context.mounted) return;

                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(i18n.t('delete_event_title')),
                                      content:
                                          Text(i18n.t('delete_event_desc')),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text(i18n.t('cancel')),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                              foregroundColor: Colors.red),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: Text(i18n.t('delete')),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true && context.mounted) {
                                    await ref
                                        .read(storageServiceProvider)
                                        .deleteEvent(_currentTrip.id, e.id);
                                    // 刷新页面数据
                                    final updatedTrip = await ref
                                        .read(storageServiceProvider)
                                        .getTripById(_currentTrip.id);
                                    if (updatedTrip != null && mounted) {
                                      setState(() {
                                        _currentTrip = updatedTrip;
                                      });
                                    }
                                  }
                                }
                              });
                            },
                            child: ListTile(
                              onTap: () {
                                if (e.lat != null && e.lng != null) {
                                  setState(() {
                                    _focusedLocation = LatLng(e.lat!, e.lng!);
                                  });
                                }
                              },
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 20),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: eventColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(eventIcon,
                                    color: eventColor, size: 24),
                              ),
                              title: Row(
                                children: [
                                  Text(typeLabel,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  const Spacer(),
                                  Text(parameter,
                                      style: TextStyle(
                                          color: eventColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14)),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('HH:mm:ss').format(e.timestamp),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  if (e.notes != null &&
                                      e.notes!.isNotEmpty &&
                                      !e.notes!.contains('聚合特征'))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        e.notes!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: -0.5,
            )),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.8),
            )),
      ],
    );
  }
}
