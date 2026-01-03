import 'dart:math';
import 'package:latlong2/latlong.dart';

/// 坐标转换工具
/// 解决中国境内 WGS-84 (原始 GPS) 与 GCJ-02 (火星坐标系) 之间的偏转问题
class CoordinateConverter {
  static const double pi = 3.1415926535897932384626;
  static const double a = 6378245.0; // 长半轴
  static const double ee = 0.00669342162296594323; // 偏心率平方

  /// WGS-84 转 GCJ-02
  static LatLng wgs84ToGcj02(double lat, double lon) {
    if (outOfChina(lat, lon)) {
      return LatLng(lat, lon);
    }
    double dlat = _transformLat(lon - 105.0, lat - 35.0);
    double dlon = _transformLon(lon - 105.0, lat - 35.0);
    double radLat = lat / 180.0 * pi;
    double magic = sin(radLat);
    magic = 1 - ee * magic * magic;
    double sqrtMagic = sqrt(magic);
    dlat = (dlat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi);
    dlon = (dlon * 180.0) / (a / sqrtMagic * cos(radLat) * pi);
    return LatLng(lat + dlat, lon + dlon);
  }

  static bool outOfChina(double lat, double lon) {
    if (lon < 72.004 || lon > 137.8347) return true;
    if (lat < 0.8293 || lat > 55.8271) return true;
    return false;
  }

  static double _transformLat(double x, double y) {
    double ret = -100.0 +
        2.0 * x +
        3.0 * y +
        0.2 * y * y +
        0.1 * x * y +
        0.2 * sqrt(x.abs());
    ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
    ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
    return ret;
  }

  static double _transformLon(double x, double y) {
    double ret =
        300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(x.abs());
    ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
    ret +=
        (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
    return ret;
  }
}
