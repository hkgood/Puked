import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Corrected import
import 'package:puked/models/db_models.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

class RetryTileProvider extends TileProvider {
  final int maxRetries;
  final Duration retryDelay;
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  RetryTileProvider({
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 500),
  });

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return RetryNetworkImage(url,
        maxRetries: maxRetries,
        retryDelay: retryDelay,
        httpClient: _httpClient);
  }
}

class RetryNetworkImage extends ImageProvider<RetryNetworkImage> {
  final String url;
  final int maxRetries;
  final Duration retryDelay;
  final HttpClient httpClient;

  RetryNetworkImage(this.url,
      {required this.maxRetries,
      required this.retryDelay,
      required this.httpClient});

  @override
  Future<RetryNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<RetryNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      RetryNetworkImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: url,
      informationCollector: () => [
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<RetryNetworkImage>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
      RetryNetworkImage key, ImageDecoderCallback decode) async {
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        final request = await httpClient.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }
        final bytes = await consolidateHttpClientResponseBytes(response);
        if (bytes.lengthInBytes == 0) throw Exception('Empty image');

        // 使用 decode 回调而不是直接调用 ui.instantiateImageCodec
        // 这样可以更好地集成到 Flutter 的图片流水线中
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return await decode(buffer);
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          rethrow;
        }
        await Future.delayed(retryDelay * attempt); // 指数退避
      }
    }
    throw Exception('Failed to load image after $maxRetries attempts');
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is RetryNetworkImage && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}

class TripMapView extends StatefulWidget {
  final List<TrajectoryPoint> trajectory;
  final List<RecordedEvent> events;
  final bool isLive;
  final Position? currentPosition;
  final LatLng? focusPoint; // 新增：聚焦坐标

  const TripMapView({
    super.key,
    required this.trajectory,
    required this.events,
    this.isLive = true,
    this.currentPosition,
    this.focusPoint,
  });

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  Timer? _recenterTimer;
  bool _isUserInteracting = false;

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final camera = _mapController.camera;
    final latTween = Tween<double>(
        begin: camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);

    final controller = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    final Animation<double> animation =
        CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

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

    // 1. 处理详情模式下的手动聚焦
    if (widget.focusPoint != null &&
        widget.focusPoint != oldWidget.focusPoint) {
      _animatedMapMove(widget.focusPoint!, 17.0);
    }

    // 2. 实时模式下，如果没有用户交互，地图跟随当前位置
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
    LatLng center = const LatLng(31.2304, 121.4737);
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

    return Container(
      color: isDarkMode ? Colors.black : const Color(0xFFF5F5F5), // 夜间模式背景设为黑色
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
          onPointerDown: (_, __) {
            if (widget.isLive) {
              setState(() => _isUserInteracting = true);
              _startRecenterTimer();
            }
          },
          onMapReady: () {
            if (!widget.isLive && widget.trajectory.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final points =
                    widget.trajectory.map((p) => LatLng(p.lat, p.lng)).toList();
                if (points.isNotEmpty) {
                  final bounds = LatLngBounds.fromPoints(points);
                  _mapController.fitCamera(
                    CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(50),
                      maxZoom: 16,
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
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/${isDarkMode ? 'dark_all' : 'light_all'}/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            tileProvider: RetryTileProvider(maxRetries: 5), // 使用带重试机制的 Provider
            retinaMode: RetinaMode.isHighDensity(context),
            // 瓦片显示优化
            tileDisplay:
                const TileDisplay.fadeIn(duration: Duration(milliseconds: 300)),
            // 错误处理与自动重试策略
            errorTileCallback: (tile, error, stackTrace) {
              debugPrint("Tile load error: $error");
            },
            // 当瓦片加载错误时，不缓存错误，以便下次重试
            evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
            // 增加缓冲区
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
                      width: 20, // 缩小至 20
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: config.color.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 1.5), // 细描边
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          config.icon,
                          color: Colors.white,
                          size: 10, // 图标随比例缩小
                        ),
                      ),
                    );
                  }
                  return null;
                })
                .whereType<Marker>()
                .toList(),
          ),

          // 4. 起终点标记
          if (widget.trajectory.isNotEmpty)
            MarkerLayer(
              markers: [
                // 起点
                Marker(
                  point: LatLng(
                      widget.trajectory.first.lat, widget.trajectory.first.lng),
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4)
                      ],
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 12),
                  ),
                ),
                // 终点
                if (!widget.isLive)
                  Marker(
                    point: LatLng(
                        widget.trajectory.last.lat, widget.trajectory.last.lng),
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4)
                        ],
                      ),
                      child:
                          const Icon(Icons.stop, color: Colors.white, size: 12),
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
      ),
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
                    .withValues(alpha: 0.4 * (1 - _controller.value)),
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
                    color: Colors.blueAccent.withValues(alpha: 0.5),
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
