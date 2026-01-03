import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Corrected import
import 'package:puked/models/db_models.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:puked/common/utils/coordinate_converter.dart';

class RetryTileProvider extends TileProvider {
  final int maxRetries;
  final Duration retryDelay;
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5); // 缩短连接超时时间，避免长时间挂起 UI

  RetryTileProvider({
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 300),
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

        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return await decode(buffer);
      } catch (e) {
        attempt++;
        if (e is SocketException || e is HttpException) {
          // 网络连接问题或 DNS 解析失败，不应导致崩溃
          debugPrint('Network error loading tile: $e');
          if (attempt >= maxRetries) {
            // 达到最大重试次数，静默失败，返回一个透明占位图或重新抛出
            // 这里我们抛出一个特定的异常，让 Flutter 的图片流水线处理
            throw Exception('Tile network error after $maxRetries retries');
          }
        } else if (attempt >= maxRetries) {
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
  bool _isInChina = true; // 默认国内，避免首屏加载 OSM 失败

  @override
  void initState() {
    super.initState();
    _checkLocation();
  }

  void _checkLocation() {
    double? lat;
    double? lon;

    if (widget.currentPosition != null) {
      lat = widget.currentPosition!.latitude;
      lon = widget.currentPosition!.longitude;
    } else if (widget.trajectory.isNotEmpty) {
      lat = widget.trajectory.first.lat;
      lon = widget.trajectory.first.lng;
    } else {
      return;
    }

    if (lat.abs() < 0.1 && lon.abs() < 0.1) return;

    final outOfChina = CoordinateConverter.outOfChina(lat, lon);
    final inChina = !outOfChina;

    // 逻辑修正：如果当前状态与实际地理位置不符，则更新
    if (inChina != _isInChina) {
      debugPrint(
          ">>> Map Engine Switch: Now ${inChina ? 'IN' : 'OUT'} China (lat:$lat, lon:$lon)");
      setState(() {
        _isInChina = inChina;
      });
    }
  }

  LatLng _toDisplay(double lat, double lon) {
    if (_isInChina) {
      return CoordinateConverter.wgs84ToGcj02(lat, lon);
    }
    return LatLng(lat, lon);
  }

  // 辅助方法：确保任何移动都不超过 18 级
  void _safeMove(LatLng dest, double zoom) {
    _mapController.move(dest, zoom.clamp(0.0, 18.0));
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final displayDest = _isInChina
        ? CoordinateConverter.wgs84ToGcj02(
            destLocation.latitude, destLocation.longitude)
        : destLocation;

    final double safeZoom = destZoom.clamp(0.0, 18.0);
    final camera = _mapController.camera;

    final latTween =
        Tween<double>(begin: camera.center.latitude, end: displayDest.latitude);
    final lngTween = Tween<double>(
        begin: camera.center.longitude, end: displayDest.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: safeZoom);

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

  List<Polyline> _buildPolylines() {
    if (widget.trajectory.isEmpty) return [];

    final List<Polyline> lines = [];
    List<LatLng> currentSegment = [];
    bool currentIsLowConf = widget.trajectory.first.isLowConfidence ?? false;

    for (var i = 0; i < widget.trajectory.length; i++) {
      final p = widget.trajectory[i];
      final isLow = p.isLowConfidence ?? false;
      final displayLatLng = _toDisplay(p.lat, p.lng);

      if (isLow != currentIsLowConf) {
        // 状态切换，保存当前段
        if (currentSegment.length >= 2) {
          lines.add(Polyline(
            points: List.from(currentSegment),
            color: currentIsLowConf
                ? Colors.orange.withValues(alpha: 0.5)
                : Colors.greenAccent,
            strokeWidth: 4,
          ));
        }
        // 开始新的一段，为了线段连续，需要包含上一个点的终点
        currentSegment = [
          currentSegment.isNotEmpty ? currentSegment.last : displayLatLng,
          displayLatLng
        ];
        currentIsLowConf = isLow;
      } else {
        currentSegment.add(displayLatLng);
      }
    }

    // 添加最后一段
    if (currentSegment.length >= 2) {
      lines.add(Polyline(
        points: currentSegment,
        color: currentIsLowConf
            ? Colors.orange.withValues(alpha: 0.5)
            : Colors.greenAccent,
        strokeWidth: 4,
      ));
    }

    return lines;
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
      final displayLatLng = _toDisplay(
          widget.currentPosition!.latitude, widget.currentPosition!.longitude);
      _safeMove(displayLatLng, _mapController.camera.zoom);
    } else if (widget.trajectory.isNotEmpty) {
      final last = widget.trajectory.last;
      final displayLatLng = _toDisplay(last.lat, last.lng);
      _safeMove(displayLatLng, _mapController.camera.zoom);
    }
  }

  @override
  void didUpdateWidget(TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkLocation();

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

  Widget _buildAmapLayer(bool isDarkMode) {
    final layer = TileLayer(
      urlTemplate:
          'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}&key=f318df2044b0aecab275729566e861f2',
      subdomains: const ['1', '2', '3', '4'],
      maxZoom: 22, // 允许图层级别超过 18 级而不被卸载，防止变白
      maxNativeZoom: 18, // 服务器上限是 18 级，超过后拉伸 18 级的图
      tileProvider: RetryTileProvider(maxRetries: 5),
      retinaMode: RetinaMode.isHighDensity(context),
    );

    if (!isDarkMode) return layer;

    // 深色模式：通过颜色矩阵实现底图反转
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -1.0, 0.0, 0.0, 0.0, 255.0, // R
        0.0, -1.0, 0.0, 0.0, 255.0, // G
        0.0, 0.0, -1.0, 0.0, 255.0, // B
        0.0, 0.0, 0.0, 1.0, 0.0, // A
      ]),
      child: ColorFiltered(
        // 饱和度减半矩阵
        colorFilter: const ColorFilter.matrix([
          0.606,
          0.358,
          0.036,
          0,
          0,
          0.107,
          0.858,
          0.036,
          0,
          0,
          0.107,
          0.358,
          0.536,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: ColorFiltered(
          // 叠加一层淡淡的蓝色调，增加科技感
          colorFilter: ColorFilter.mode(
            Colors.blueAccent.withValues(alpha: 0.08),
            BlendMode.hardLight,
          ),
          child: layer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 初始中心点逻辑 (WGS-84)
    LatLng rawCenter = const LatLng(31.2304, 121.4737);
    if (widget.currentPosition != null) {
      rawCenter = LatLng(
          widget.currentPosition!.latitude, widget.currentPosition!.longitude);
    } else if (widget.trajectory.isNotEmpty) {
      if (widget.isLive) {
        rawCenter =
            LatLng(widget.trajectory.last.lat, widget.trajectory.last.lng);
      } else {
        final points =
            widget.trajectory.map((p) => LatLng(p.lat, p.lng)).toList();
        final bounds = LatLngBounds.fromPoints(points);
        rawCenter = bounds.center;
      }
    }

    // 转换为显示坐标
    final displayCenter = _toDisplay(rawCenter.latitude, rawCenter.longitude);

    return Container(
      color: isDarkMode ? Colors.black : const Color(0xFFF5F5F5),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: displayCenter,
          initialZoom: 15,
          minZoom: 3.0,
          maxZoom: 18.0, // 核心：交互层级死锁
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
                final List<LatLng> points = widget.trajectory
                    .map((p) => _toDisplay(p.lat, p.lng))
                    .toList();
                if (points.isNotEmpty) {
                  final bounds = LatLngBounds.fromPoints(points);
                  _mapController.fitCamera(
                    CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(50),
                      maxZoom: 16.0,
                    ),
                  );
                }
              });
            }
          },
        ),
        children: [
          // 1. 瓦片源选择
          if (_isInChina)
            _buildAmapLayer(isDarkMode)
          else
            // CartoDB 瓦片源 (WGS-84)
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/${isDarkMode ? 'dark_all' : 'light_all'}/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              maxZoom: 22, // 允许图层级别超过限制而不被卸载，防止变白
              maxNativeZoom: 20, // 海外 OSM 支持到 20 级
              tileProvider: RetryTileProvider(maxRetries: 5),
              retinaMode: RetinaMode.isHighDensity(context),
              tileDisplay: const TileDisplay.fadeIn(
                  duration: Duration(milliseconds: 300)),
              errorTileCallback: (tile, error, stackTrace) {
                debugPrint("Tile load error: $error");
              },
              evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
              keepBuffer: 3,
              panBuffer: 1,
            ),

          // 2. 轨迹线
          PolylineLayer(
            polylines: _buildPolylines(),
          ),

          // 3. 事件标记
          MarkerLayer(
            markers: widget.events
                .map((e) {
                  if (e.lat != null && e.lng != null) {
                    final config = _getEventConfig(e.type);
                    return Marker(
                      point: _toDisplay(e.lat!, e.lng!),
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: config.color.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
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
                          size: 10,
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
                  point: _toDisplay(
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
                    point: _toDisplay(
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
                  point: displayCenter,
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
