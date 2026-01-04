import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// 高德地图服务：负责抓路纠偏与路径几何获取
class AmapService {
  final String apiKey = "f318df2044b0aecab275729566e861f2";

  /// 抓路服务：将原始轨迹点吸附到道路中心线上
  Future<List<LatLng>> grabRoad(List<LatLng> points) async {
    if (points.isEmpty) return [];

    final coords = points.map((p) => "${p.longitude},${p.latitude}").join("|");
    final url = "https://restapi.amap.com/v3/assistant/grab?key=$apiKey&coords=$coords";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == '1') {
          final List<dynamic> roadPoints = data['data']['points'];
          return roadPoints.map((p) {
            final parts = p['location'].split(',');
            return LatLng(double.parse(parts[1]), double.parse(parts[0]));
          }).toList();
        }
      }
    } catch (e) {
      print("Amap grabRoad error: $e");
    }
    return points;
  }

  /// 路径规划：获取两点之间的标准导航路径 (用于长隧道建模)
  Future<List<LatLng>> getRouteGeometry(LatLng start, LatLng end) async {
    final origin = "${start.longitude.toStringAsFixed(6)},${start.latitude.toStringAsFixed(6)}";
    final destination = "${end.longitude.toStringAsFixed(6)},${end.latitude.toStringAsFixed(6)}";
    
    final url = "https://restapi.amap.com/v3/direction/driving?key=$apiKey&origin=$origin&destination=$destination&extensions=all";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == '1' && data['route']['paths'].isNotEmpty) {
          final List<LatLng> fullPath = [];
          final steps = data['route']['paths'][0]['steps'];
          for (var step in steps) {
            final polyline = step['polyline'] as String;
            final pts = polyline.split(';');
            for (var pt in pts) {
              final lonlat = pt.split(',');
              fullPath.add(LatLng(double.parse(lonlat[1]), double.parse(lonlat[0])));
            }
          }
          return fullPath;
        }
      }
    } catch (e) {
      print("Amap getRouteGeometry error: $e");
    }
    return [start, end];
  }
}

