import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:puked/models/db_models.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  /// 将单个行程导出为 JSON 文件并触发分享
  Future<void> exportTrip(Trip trip) async {
    final Map<String, dynamic> exportData = {
      "version": "1.0.0",
      "trip_id": trip.uuid,
      "metadata": {
        "start_time": trip.startTime.toIso8601String(),
        "end_time": trip.endTime?.toIso8601String(),
        "car_model": trip.carModel ?? "Unknown",
        "notes": trip.notes ?? "",
        "event_count": trip.eventCount,
      },
      "trajectory": trip.trajectory
          .map((p) => {
                "ts": p.timestamp.millisecondsSinceEpoch / 1000.0,
                "lat": p.lat,
                "lng": p.lng,
                "speed": p.speed,
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

    // 1. 生成 JSON 字符串
    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    // 2. 写入临时文件
    final directory = await getTemporaryDirectory();
    final file =
        File('${directory.path}/Trip_${trip.uuid.substring(0, 8)}.json');
    await file.writeAsString(jsonString);

    // 3. 调用分享
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Puked Trip Report: ${trip.startTime}',
    );
  }
}
