import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:puked/common/widgets/trip_map_view.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:puked/common/widgets/trip_acceleration_chart.dart';
import 'package:puked/features/recording/presentation/vehicle_info_screen.dart';
import 'package:puked/services/export/export_service.dart';
import 'package:puked/services/storage/storage_service.dart';

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
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        backgroundColor: Colors.transparent,
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 0. 车辆信息卡片
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: trip.brand != null
                        ? SvgPicture.asset(
                            'assets/logos/${trip.brand}.svg',
                            colorFilter:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const ColorFilter.mode(
                                        Colors.white, BlendMode.srcIn)
                                    : null,
                          )
                        : const Icon(Icons.help_outline, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              (trip.carModel != null &&
                                      trip.carModel!.isNotEmpty)
                                  ? trip.carModel!
                                  : i18n.t('car_model'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.95)
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        if (trip.softwareVersion != null &&
                            trip.softwareVersion!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              trip.softwareVersion!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _editVehicleInfo,
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: Text(
                      i18n.t('edit'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),

            // 1. 轨迹地图展示 (进一步压缩高度)
            Container(
              height: 240, // 从 300 压缩到 240
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12), // 减小页边距
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), // 稍小的圆角更硬朗
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: TripMapView(
                  trajectory: trajectory,
                  events: events,
                  isLive: false,
                  focusPoint: _focusedLocation,
                ),
              ),
            ),

            // 2. 数据概览 (移除统一的 horizontal padding，改为内部组件单独控制)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(i18n.t('trip_summary'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            )),
                        Text(
                          "${(trip.distance / 1000).toStringAsFixed(2)} km",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: _StatItem(
                              label: i18n.t('total_events'),
                              value: "${trip.eventCount}"),
                        ),
                        Expanded(
                          child: _StatItem(
                            label: i18n.t('avg_speed'),
                            value: trip.endTime != null && trip.distance > 0
                                ? "${(trip.distance / 1000 / (trip.endTime!.difference(trip.startTime).inSeconds / 3600)).toStringAsFixed(1)} km/h"
                                : "--",
                          ),
                        ),
                        Expanded(
                          child: _StatItem(
                              label: i18n.t('duration'),
                              value: trip.endTime != null
                                  ? "${trip.endTime!.difference(trip.startTime).inMinutes} ${i18n.t('min')}"
                                  : "--"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 事件比例分布条
                  if (events.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildEventDistributionBar(events),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 3. 加速度图表展示
                  TripAccelerationChart(
                    trajectory: trajectory,
                    label: i18n.t('longitudinal'),
                    color: Colors.blue,
                    isLongitudinal: true,
                  ),
                  const SizedBox(height: 16),
                  TripAccelerationChart(
                    trajectory: trajectory,
                    label: i18n.t('lateral'),
                    color: Colors.green,
                    isLongitudinal: false,
                  ),
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                        height: 24,
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.5)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(i18n.t('event_list'),
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                  const SizedBox(height: 4),
                  // 事件列表
                  if (events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 20),
                      child: Center(
                          child: Text(i18n.t('no_trips'),
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.outline))),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: events.length,
                      separatorBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.5),
                            height: 1),
                      ),
                      itemBuilder: (context, index) {
                        final e = events[index];
                        // 统一使用 i18nProvider 提供的方法进行翻译
                        final typeLabel = i18n.t(e.type);

                        // 定义不同事件类型的颜色和图标
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
                          double maxVal = 0;
                          for (var p in e.sensorData) {
                            if (e.type == 'rapidAcceleration' ||
                                e.type == 'rapidDeceleration') {
                              if (p.ay != null && p.ay!.abs() > maxVal.abs()) {
                                maxVal = p.ay!;
                              }
                            } else if (e.type == 'wobble') {
                              if (p.ax != null && p.ax!.abs() > maxVal.abs()) {
                                maxVal = p.ax!;
                              }
                            } else if (e.type == 'bump') {
                              if (p.az != null && p.az!.abs() > maxVal.abs()) {
                                maxVal = p.az!;
                              }
                            } else {
                              // 其他类型取合力加速度
                              final g = (p.ax ?? 0) * (p.ax ?? 0) +
                                  (p.ay ?? 0) * (p.ay ?? 0) +
                                  (p.az ?? 0) * (p.az ?? 0);
                              if (g > maxVal) maxVal = g;
                            }
                          }
                          // 如果是合力，记得开方。如果是单轴，直接取绝对值并转为 G
                          double finalG =
                              e.type == 'manual' ? 0 : (maxVal.abs() / 9.80665);
                          parameter = "${finalG.toStringAsFixed(2)} G";
                        }

                        return ListTile(
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
                            child: Icon(
                              eventIcon,
                              color: eventColor,
                              size: 24,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                typeLabel,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                parameter,
                                style: TextStyle(
                                  color: eventColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.6)),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('HH:mm:ss').format(e.timestamp),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    e.source,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventDistributionBar(List<dynamic> events) {
    final counts = <String, int>{};
    for (var e in events) {
      counts[e.type] = (counts[e.type] ?? 0) + 1;
    }

    final types = [
      {'type': 'rapidAcceleration', 'color': const Color(0xFFFF9500)},
      {'type': 'rapidDeceleration', 'color': const Color(0xFFFF3B30)},
      {'type': 'jerk', 'color': const Color(0xFF5856D6)},
      {'type': 'bump', 'color': const Color(0xFFAF52DE)},
      {'type': 'wobble', 'color': const Color(0xFF007AFF)},
      {'type': 'manual', 'color': const Color(0xFF34C759)},
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 8,
        child: Row(
          children: types.map((config) {
            final count = counts[config['type']] ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return Expanded(
              flex: count,
              child: Container(color: config['color'] as Color),
            );
          }).toList(),
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
