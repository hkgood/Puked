import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Corrected import
import 'package:puked/models/db_models.dart';
import 'package:puked/common/utils/coordinate_converter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class TripMapView extends StatefulWidget {
  final List<TrajectoryPoint> trajectory;
  final List<RecordedEvent> events;
  final bool isLive;
  final Position? currentPosition;

  const TripMapView({
    super.key,
    required this.trajectory,
    required this.events,
    this.isLive = true,
    this.currentPosition,
  });

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView> {
  final MapController _mapController = MapController();
  Timer? _recenterTimer;
  bool _isUserInteracting = false;

  @override
  void dispose() {
    _recenterTimer?.cancel();
    super.dispose();
  }

  void _startRecenterTimer() {
    _recenterTimer?.cancel();
    _recenterTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && widget.isLive) {
        setState(() => _isUserInteracting = false);
        _recenterToCurrentLocation();
      }
    });
  }

  void _recenterToCurrentLocation() {
    if (widget.currentPosition != null) {
      _mapController.move(
          LatLng(widget.currentPosition!.latitude,
              widget.currentPosition!.longitude),
          _mapController.camera.zoom);
    } else if (widget.trajectory.isNotEmpty) {
      final last = widget.trajectory.last;
      _mapController.move(
          LatLng(last.lat, last.lng), _mapController.camera.zoom);
    }
  }

  @override
  void didUpdateWidget(TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 实时模式下，如果没有用户交互，地图跟随当前位置
    if (widget.isLive && !_isUserInteracting) {
      if (widget.currentPosition != oldWidget.currentPosition ||
          widget.trajectory.length != oldWidget.trajectory.length) {
        _recenterToCurrentLocation();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 初始中心点逻辑
    LatLng center = LatLng(31.2304, 121.4737);
    if (widget.currentPosition != null) {
      center = LatLng(
          widget.currentPosition!.latitude, widget.currentPosition!.longitude);
    } else if (widget.trajectory.isNotEmpty) {
      if (widget.isLive) {
        // 实时模式：跟随最新点
        center = LatLng(widget.trajectory.last.lat, widget.trajectory.last.lng);
      } else {
        // 详情模式：初始中心点设为轨迹的几何中心，减少 fitCamera 时的视野跳变
        final points =
            widget.trajectory.map((p) => LatLng(p.lat, p.lng)).toList();
        final bounds = LatLngBounds.fromPoints(points);
        center = bounds.center;
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all, // 允许所有交互 (缩放、拖动等)
        ),
        onPointerDown: (_, __) {
          if (widget.isLive) {
            setState(() => _isUserInteracting = true);
            _startRecenterTimer();
          }
        },
        onMapReady: () {
          if (!widget.isLive && widget.trajectory.isNotEmpty) {
            // 延迟一帧确保地图容器尺寸已稳定，防止 fitCamera 计算出的视野出现灰色空白
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final points =
                  widget.trajectory.map((p) => LatLng(p.lat, p.lng)).toList();
              if (points.isNotEmpty) {
                final bounds = LatLngBounds.fromPoints(points);
                _mapController.fitCamera(
                  CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(50), // 稍微增加边距
                    maxZoom: 16, // 降低最大缩放，防止视野过窄
                  ),
                );
              }
            });
          }
        },
      ),
      children: [
        // 1. CartoDB 瓦片源 (WGS-84)
        TileLayer(
          // dark_all 为深灰样式，light_all 为浅灰样式
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/${isDarkMode ? 'dark_all' : 'light_all'}/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          retinaMode: RetinaMode.isHighDensity(context),
          // 优化瓦片显示逻辑，减少灰色区域
          tileDisplay:
              const TileDisplay.fadeIn(duration: Duration(milliseconds: 300)),
          errorTileCallback: (tile, error, stackTrace) {
            debugPrint("Tile load error: $error");
          },
          // 增加缓冲区，提前加载视野外的瓦片
          keepBuffer: 3,
          panBuffer: 1,
        ),

        // 2. 轨迹线 (WGS-84)
        PolylineLayer(
          polylines: [
            Polyline(
              points:
                  widget.trajectory.map((p) => LatLng(p.lat, p.lng)).toList(),
              color: Colors.greenAccent,
              strokeWidth: 4,
            ),
          ],
        ),

        // 3. 事件标记 (根据类型差异化图标和颜色)
        MarkerLayer(
          markers: widget.events
              .map((e) {
                if (e.lat != null && e.lng != null) {
                  final config = _getEventConfig(e.type);
                  return Marker(
                    point: LatLng(e.lat!, e.lng!),
                    width: 28, // 缩小图标尺寸 (从 32 缩小到 28)
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: config.color.withOpacity(0.95),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        config.icon,
                        color: Colors.white,
                        size: 14, // 图标随比例缩小
                      ),
                    ),
                  );
                }
                return null;
              })
              .whereType<Marker>()
              .toList(),
        ),

        // 4. 起终点标记 (仅非实时模式显示)
        if (!widget.isLive && widget.trajectory.isNotEmpty)
          MarkerLayer(
            markers: [
              // 起点
              Marker(
                point: LatLng(
                    widget.trajectory.first.lat, widget.trajectory.first.lng),
                width: 28,
                height: 28,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4)
                    ],
                  ),
                  child: const Icon(Icons.play_circle_fill,
                      color: Colors.green, size: 24),
                ),
              ),
              // 终点
              Marker(
                point: LatLng(
                    widget.trajectory.last.lat, widget.trajectory.last.lng),
                width: 28,
                height: 28,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4)
                    ],
                  ),
                  child: const Icon(Icons.stop_circle,
                      color: Colors.red, size: 24),
                ),
              ),
            ],
          ),

        // 5. 当前位置点 (仅实时录制显示)
        if (widget.isLive &&
            (widget.currentPosition != null || widget.trajectory.isNotEmpty))
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 40,
                height: 40,
                child: _CurrentLocationMarker(),
              ),
            ],
          ),
      ],
    );
  }

  _EventUIConfig _getEventConfig(String type) {
    if (type.contains('Acceleration')) {
      return const _EventUIConfig(Icons.speed, Color(0xFFFF9500));
    } else if (type.contains('Deceleration')) {
      return const _EventUIConfig(Icons.trending_down, Color(0xFFFF3B30));
    } else if (type.contains('bump')) {
      return const _EventUIConfig(Icons.vibration, Color(0xFF5856D6));
    } else if (type.contains('wobble')) {
      return const _EventUIConfig(Icons.waves, Color(0xFF007AFF));
    }
    return const _EventUIConfig(Icons.warning, Colors.grey);
  }
}

class _EventUIConfig {
  final IconData icon;
  final Color color;
  const _EventUIConfig(this.icon, this.color);
}

class _CurrentLocationMarker extends StatefulWidget {
  @override
  State<_CurrentLocationMarker> createState() => _CurrentLocationMarkerState();
}

class _CurrentLocationMarkerState extends State<_CurrentLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // 呼吸光晕
            Container(
              width: 12 + (28 * _controller.value),
              height: 12 + (28 * _controller.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent
                    .withOpacity(0.4 * (1 - _controller.value)),
              ),
            ),
            // 中心点
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
