import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // 用于 kDebugMode
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:puked/models/db_models.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';
import 'package:puked/common/utils/i18n.dart';

final exportServiceProvider = Provider((ref) {
  final i18n = ref.watch(i18nProvider);
  return ExportService(i18n);
});

class ExportService {
  final I18n _i18n;
  ExportService(this._i18n);

  /// 将单个行程导出为 JSON 文件并触发分享
  /// [sharePositionOrigin] 用于在 iPad 或大屏 iPhone 上定位分享菜单的弹出起点
  Future<void> exportTrip(Trip trip, {Rect? sharePositionOrigin}) async {
    debugPrint(
        "DEBUG: [ExportService] Start exportTrip for UUID: ${trip.uuid}");
    try {
      // 自动选择日期格式
      final datePattern = _i18n.locale.languageCode == 'zh'
          ? 'yyyy-MM-dd HH:mm'
          : 'MMM dd, yyyy HH:mm';
      final dateStr = DateFormat(datePattern).format(trip.startTime);

      // ... 保持原有加载逻辑 ...
      if (!trip.trajectory.isLoaded) {
        debugPrint("DEBUG: [ExportService] Loading trajectory links...");
        await trip.trajectory.load();
      }
      if (!trip.events.isLoaded) {
        debugPrint("DEBUG: [ExportService] Loading events links...");
        await trip.events.load();
      }

      debugPrint("DEBUG: [ExportService] Preparing data map...");

      // 🔍 DEBUG: 检查轨迹点数量和传感器数据
      debugPrint(
          "DEBUG: [ExportService] Total trajectory points: ${trip.trajectory.length}");
      int pointsWithSensorData = 0;
      for (var p in trip.trajectory) {
        if (p.ax != null || p.ay != null || p.az != null) {
          pointsWithSensorData++;
        }
      }
      debugPrint(
          "DEBUG: [ExportService] Points with sensor data: $pointsWithSensorData / ${trip.trajectory.length}");

      // 🔧 关键修复：按时间戳排序轨迹点（解决批量写入导致的时间戳乱序问题）
      // 原因：10Hz高频传感器数据通过批量写入，可能因为Timer延迟导致写入顺序与时间戳顺序不一致
      final sortedTrajectory = trip.trajectory.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      debugPrint(
          "DEBUG: [ExportService] Total trajectory points: ${sortedTrajectory.length}");

      // 验证排序后的时间戳顺序（仅在Debug模式下）
      if (kDebugMode && sortedTrajectory.length > 1) {
        int outOfOrderCount = 0;
        for (int i = 0; i < sortedTrajectory.length - 1; i++) {
          if (sortedTrajectory[i]
              .timestamp
              .isAfter(sortedTrajectory[i + 1].timestamp)) {
            outOfOrderCount++;
          }
        }
        if (outOfOrderCount > 0) {
          debugPrint(
              "⚠️ [ExportService] Found $outOfOrderCount out-of-order timestamps before sorting");
        } else {
          debugPrint(
              "✅ [ExportService] All timestamps are now in correct order");
        }
      }

      final Map<String, dynamic> exportData = {
        "version": "1.0.0",
        "trip_id": trip.uuid,
        "metadata": {
          "start_time": trip.startTime.toIso8601String(),
          "end_time": trip.endTime?.toIso8601String(),
          "car_model": trip.carModel ?? "Others",
          "app_version": trip.appVersion ?? "Others",
          "platform": trip.platform ?? "Others",
          "algorithm": trip.algorithm ?? "Others",
          "notes": trip.notes ?? "",
          "event_count": trip.eventCount,
          // ✅ 新增：导出metrics信息
          "distance_km": (trip.distance / 1000).toStringAsFixed(2),
          "duration_min": trip.endTime != null
              ? trip.endTime!.difference(trip.startTime).inMinutes
              : 0,
          "avg_speed_kmh": trip.endTime != null && trip.distance > 0
              ? ((trip.distance / 1000) /
                      (trip.endTime!.difference(trip.startTime).inSeconds /
                          3600))
                  .toStringAsFixed(1)
              : "0.0",
        },
        "trajectory": sortedTrajectory
            .map((p) => {
                  "ts": p.timestamp.millisecondsSinceEpoch / 1000.0,
                  "lat": p.lat,
                  "lng": p.lng,
                  "speed": p.speed,
                  "low_conf": p.isLowConfidence,
                  if (p.ax != null)
                    "ax": double.parse(p.ax!.toStringAsFixed(3)),
                  if (p.ay != null)
                    "ay": double.parse(p.ay!.toStringAsFixed(3)),
                  if (p.az != null)
                    "az": double.parse(p.az!.toStringAsFixed(3)),
                  if (p.gx != null)
                    "gx": double.parse(p.gx!.toStringAsFixed(3)),
                  if (p.gy != null)
                    "gy": double.parse(p.gy!.toStringAsFixed(3)),
                  if (p.gz != null)
                    "gz": double.parse(p.gz!.toStringAsFixed(3)),
                })
            .toList(),
        "events": trip.events
            .map((e) => {
                  "event_id": e.uuid,
                  "timestamp": e.timestamp.millisecondsSinceEpoch / 1000.0,
                  "type": e.type,
                  "source": e.source,
                  "voice_text": e.voiceText,
                  "notes": e.notes,
                  "location": {
                    "lat": e.lat,
                    "lng": e.lng,
                    "speed": e.speed, // 导出事件发生时的融合速度
                  },
                  "sensor_fragment": {
                    "sampling_rate": "25Hz", // 配合 recording_provider 的抽稀
                    "data": e.sensorData
                        .map((s) => {
                              "offset_ms": s.offsetMs,
                              // 采用扁平化结构并限制小数位数，大幅减小 JSON 体积
                              "accel": [
                                double.parse(s.ax?.toStringAsFixed(3) ?? "0"),
                                double.parse(s.ay?.toStringAsFixed(3) ?? "0"),
                                double.parse(s.az?.toStringAsFixed(3) ?? "0")
                              ],
                              "gyro": [
                                double.parse(s.gx?.toStringAsFixed(3) ?? "0"),
                                double.parse(s.gy?.toStringAsFixed(3) ?? "0"),
                                double.parse(s.gz?.toStringAsFixed(3) ?? "0")
                              ],
                              "mag": [
                                double.parse(s.mx?.toStringAsFixed(1) ?? "0"),
                                double.parse(s.my?.toStringAsFixed(1) ?? "0"),
                                double.parse(s.mz?.toStringAsFixed(1) ?? "0")
                              ],
                            })
                        .toList(),
                  }
                })
            .toList(),
      };

      debugPrint("DEBUG: [ExportService] Converting to JSON string...");
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      debugPrint(
          "DEBUG: [ExportService] JSON created, length: ${jsonString.length} chars");

      final directory = await getTemporaryDirectory();
      final String shortId =
          trip.uuid.length >= 8 ? trip.uuid.substring(0, 8) : trip.uuid;
      final file = File('${directory.path}/Trip_$shortId.json');

      debugPrint("DEBUG: [ExportService] Writing to file: ${file.path}");
      await file.writeAsString(jsonString);

      debugPrint(
          "DEBUG: [ExportService] Triggering Share.shareXFiles with origin: $sharePositionOrigin");
      final String shareText = _i18n.t('share_msg_body', args: [dateStr]);
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        text: shareText,
        sharePositionOrigin: sharePositionOrigin, // 使用位置参数
      );

      debugPrint(
          "DEBUG: [ExportService] Share result status: ${result.status}");
    } catch (e, stack) {
      debugPrint("DEBUG: [ExportService] ERROR during export: $e");
      debugPrint("DEBUG: [ExportService] StackTrace: $stack");
    }
  }
}
