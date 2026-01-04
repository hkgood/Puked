import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart'; // 增加这行
import 'package:path_provider/path_provider.dart';
import 'package:puked/models/db_models.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exportServiceProvider = Provider((ref) => ExportService());

class ExportService {
  /// 将单个行程导出为 JSON 文件并触发分享
  /// [sharePositionOrigin] 用于在 iPad 或大屏 iPhone 上定位分享菜单的弹出起点
  Future<void> exportTrip(Trip trip, {Rect? sharePositionOrigin}) async {
    debugPrint(
        "DEBUG: [ExportService] Start exportTrip for UUID: ${trip.uuid}");
    try {
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
      // ... 原有 exportData 构建逻辑 ...
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
        },
        "trajectory": trip.trajectory
            .map((p) => {
                  "ts": p.timestamp.millisecondsSinceEpoch / 1000.0,
                  "lat": p.lat,
                  "lng": p.lng,
                  "speed": p.speed,
                  "low_conf": p.isLowConfidence ?? false,
                })
            .toList(),
        "events": trip.events
            .map((e) => {
                  "event_id": e.uuid,
                  "timestamp": e.timestamp.millisecondsSinceEpoch / 1000.0,
                  "type": e.type,
                  "source": e.source,
                  "location": {"lat": e.lat, "lng": e.lng},
                  "sensor_fragment": {
                    "sampling_rate": "30Hz",
                    "data": e.sensorData
                        .map((s) => {
                              "offset_ms": s.offsetMs,
                              "accel": {"x": s.ax, "y": s.ay, "z": s.az},
                              "gyro": {"x": s.gx, "y": s.gy, "z": s.gz},
                              "mag": {"x": s.mx, "y": s.my, "z": s.mz},
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
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        text: 'Puked Trip Report: ${trip.startTime}',
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
