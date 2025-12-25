import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:puked/common/widgets/trip_map_view.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/common/utils/i18n.dart';

class TripDetailScreen extends ConsumerWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
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
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
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
                        .withOpacity(0.5)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: TripMapView(
                  trajectory: trajectory,
                  events: events,
                  isLive: false,
                ),
              ),
            ),

            // 2. 数据概览 (更紧凑的内边距)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 16),
                  // 事件比例分布条
                  if (events.isNotEmpty) ...[
                    _buildEventDistributionBar(events),
                    const SizedBox(height: 12),
                  ],
                  Divider(
                      height: 24,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withOpacity(0.5)),
                  Text(i18n.t('event_list'),
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 4),
                  // 事件列表
                  if (events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
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
                      separatorBuilder: (context, index) => Divider(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withOpacity(0.5),
                          height: 1),
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
                          case 'bump':
                            eventColor = const Color(0xFF5856D6);
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
                              if (p.ay != null && p.ay!.abs() > maxVal.abs())
                                maxVal = p.ay!;
                            } else if (e.type == 'wobble') {
                              if (p.ax != null && p.ax!.abs() > maxVal.abs())
                                maxVal = p.ax!;
                            } else if (e.type == 'bump') {
                              if (p.az != null && p.az!.abs() > maxVal.abs())
                                maxVal = p.az!;
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
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 4),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: eventColor.withOpacity(0.1),
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
                                        .withOpacity(0.6)),
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
                                        .surfaceVariant,
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
      {'type': 'bump', 'color': const Color(0xFF5856D6)},
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
                  .withOpacity(0.8),
            )),
      ],
    );
  }
}
