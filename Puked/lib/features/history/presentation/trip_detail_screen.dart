import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:puked/common/widgets/trip_map_view.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/common/widgets/brand_logo.dart';
import 'package:puked/common/widgets/trip_acceleration_chart.dart';
import 'package:puked/features/recording/presentation/vehicle_info_screen.dart';
import 'package:puked/services/export/export_service.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/services/cloud_trip_service.dart';
import 'package:puked/services/ai_commentary_service.dart';
import 'package:puked/services/trip_score_calculator.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/features/recording/providers/vehicle_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class TripDetailScreen extends ConsumerStatefulWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  LatLng? _focusedLocation;
  late Trip _currentTrip;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _loadData();
  }

  Future<void> _loadData() async {
    // Ensure trajectory and event data is loaded
    if (!_currentTrip.trajectory.isLoaded || !_currentTrip.events.isLoaded) {
      await _currentTrip.trajectory.load();
      await _currentTrip.events.load();
      if (mounted) setState(() {});
    }

    // Lazy load event statistics (for legacy data compatibility)
    if (_currentTrip.eventStatsJson == null && _currentTrip.events.isNotEmpty) {
      debugPrint('[TripDetail] Missing statistics detected, calculating...');
      final storage = ref.read(storageServiceProvider);
      await storage.calculateEventStats(_currentTrip.id);

      // Reload Trip
      final updatedTrip = await storage.getTripById(_currentTrip.id);
      if (updatedTrip != null && mounted) {
        setState(() {
          _currentTrip = updatedTrip;
        });
      }
      debugPrint('[TripDetail] Statistics generated');
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
      // Reload data
      final storage = ref.read(storageServiceProvider);
      final trips = await storage.getAllTrips();
      setState(() {
        _currentTrip = trips.firstWhere((t) => t.id == _currentTrip.id);
      });
    }
  }

  Future<void> _saveAsImage() async {
    final i18n = ref.read(i18nProvider);
    debugPrint("[SaveImage] 🟢 开始保存图片流程...");
    try {
      // 1. Permission Request (iOS Enhancement)
      if (Platform.isIOS) {
        var status = await Permission.photosAddOnly.status;
        debugPrint("[SaveImage] iOS 相册权限状态: $status");
        if (status.isDenied) {
          status = await Permission.photosAddOnly.request();
          debugPrint("[SaveImage] 请求 iOS 权限结果: $status");
        }
        if (!status.isGranted && !status.isLimited) {
          debugPrint("[SaveImage] ❌ 缺少 iOS 相册权限");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(i18n.t('error_no_photo_permission'))),
            );
          }
          return;
        }
      } else {
        if (await Permission.photos.isDenied) {
          final status = await Permission.photos.request();
          debugPrint("[SaveImage] Android 相册权限请求结果: $status");
        }
      }

      if (mounted) {
        setState(() => _isCapturing = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(i18n.t('saving_image')),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Give UI a moment to render the Header
      await Future.delayed(const Duration(milliseconds: 200));

      // Capture detail screenshot
      debugPrint("[SaveImage] 📸 Capturing screenshot...");
      final Uint8List? detailBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
      );

      if (mounted) setState(() => _isCapturing = false);

      if (detailBytes != null) {
        debugPrint(
            "[SaveImage] 💾 Screenshot captured successfully, size: ${detailBytes.length} bytes, saving to gallery...");
        final fileName =
            "${i18n.t('trip_report_title')}_${_currentTrip.id}_${DateTime.now().millisecondsSinceEpoch}";

        final result = await ImageGallerySaverPlus.saveImage(
          detailBytes,
          quality: 100,
          name: fileName,
        );

        debugPrint("[SaveImage] 🏁 插件返回结果: $result");

        if (result != null && result['isSuccess'] == true) {
          debugPrint(
              "[SaveImage] ✅ Image saved successfully! Filename: $fileName");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(i18n.t('save_success')),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          debugPrint("[SaveImage] ❌ Plugin save failed: $result");
          throw Exception("Plugin returned failure");
        }
      } else {
        debugPrint("[SaveImage] ❌ Screenshot capture returned null");
      }
    } catch (e) {
      debugPrint("[SaveImage] 🚨 Exception occurred: $e");
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${i18n.t('save_failed')}: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditEventDialog(RecordedEvent e) async {
    final i18n = ref.read(i18nProvider);
    final storage = ref.read(storageServiceProvider);

    String currentType = e.type;
    final textController =
        TextEditingController(text: e.voiceText ?? e.notes ?? "");

    final Map<String, String> eventTypes = {
      'proDisengagement': i18n.t('proDisengagement'),
      'proViolation': i18n.t('proViolation'),
      'proExperience': i18n.t('proExperience'),
      'manual': i18n.t('manual'),
      'rapidAcceleration': i18n.t('rapidAcceleration'),
      'rapidDeceleration': i18n.t('rapidDeceleration'),
      'jerk': i18n.t('jerk'),
      'bump': i18n.t('bump'),
      'wobble': i18n.t('wobble'),
    };

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(i18n.t('edit_event')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n.t('event_type'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: currentType,
                      items: eventTypes.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null)
                          setDialogState(() => currentType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(i18n.t('event_description'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: textController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: i18n.t('event_description'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(i18n.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                await storage.updateEvent(
                  _currentTrip.id, // Add tripId parameter
                  e.id,
                  type: currentType,
                  voiceText: textController.text,
                  notes: textController.text,
                );

                // Refresh trip details
                final updatedTrip = await storage.getTripById(_currentTrip.id);
                if (updatedTrip != null && mounted) {
                  setState(() {
                    _currentTrip = updatedTrip;
                  });
                }

                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(i18n.t('save_changes')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenshotHeader() {
    final i18n = ref.read(i18nProvider);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/logo.png', width: 48, height: 48),
          const SizedBox(height: 8),
          const Text(
            'Puked',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            i18n.t('app_tagline'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // Unified header style
  TextStyle _headerStyle(BuildContext context) => TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 17,
        color: Theme.of(context).colorScheme.onSurface,
      );

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final l10n = AppLocalizations.of(context)!;
    final trip = _currentTrip;

    // Auto-select date format
    final datePattern =
        l10n.localeName == 'zh' ? 'yyyy-MM-dd HH:mm' : 'MMM dd, yyyy HH:mm';
    final dateStr = DateFormat(datePattern).format(trip.startTime);

    final trajectory = trip.trajectory.toList();
    final events = trip.events.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          dateStr,
          style: const TextStyle(
            fontSize: 12, // Further reduce font size
            letterSpacing: -0.8, // Further reduce letter spacing
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          if (ref.watch(authProvider).isPro)
            _currentTrip.isUploaded
                ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_done,
                      color: Colors.green,
                      size: 24,
                    ),
                  )
                : IconButton(
                    onPressed: () async {
                      if (!_currentTrip.isDataSufficient) {
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(i18n.t('insufficient_data_title')),
                              content:
                                  Text(i18n.t('insufficient_data_message')),
                              actions: [
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(i18n.t('confirm')),
                                ),
                              ],
                            ),
                          );
                        }
                        return;
                      }

                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(i18n.t('submit_trip')),
                          content: Text(i18n.t('submit_trip_confirm')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(i18n.t('cancel')),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(i18n.t('upload')),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(i18n.t('uploading'))),
                        );
                        try {
                          final uploadResult = await ref
                              .read(cloudTripServiceProvider)
                              .uploadTrip(_currentTrip);

                          final cloudId = uploadResult['id'] as String;
                          final metrics =
                              uploadResult['metrics'] as Map<String, dynamic>?;

                          await ref
                              .read(storageServiceProvider)
                              .updateTripCloudId(_currentTrip.id, cloudId,
                                  metrics: metrics);

                          // Refresh local state
                          final updatedTrip = await ref
                              .read(storageServiceProvider)
                              .getTripById(_currentTrip.id);
                          if (updatedTrip != null && mounted) {
                            setState(() {
                              _currentTrip = updatedTrip;
                            });
                          }

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(i18n.t('upload_success')),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(i18n.t('upload_failed')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      Icons.cloud_upload_outlined,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
          // Keep only one image icon - saves trip detail only
          IconButton(
            onPressed: _saveAsImage,
            icon: Icon(
              Icons.image_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          IconButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(i18n.t('exporting')),
                  duration: const Duration(seconds: 1),
                ),
              );
              // Get button position for iPad/large iPhone share menu positioning
              final RenderBox? box = context.findRenderObject() as RenderBox?;
              final Rect? rect = box != null
                  ? box.localToGlobal(Offset.zero) & box.size
                  : null;

              await ref
                  .read(exportServiceProvider)
                  .exportTrip(trip, sharePositionOrigin: rect);
            },
            icon: Icon(
              Icons.share_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        left: true,
        right: true,
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          child: Screenshot(
            controller: _screenshotController,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                children: [
                  if (_isCapturing) _buildScreenshotHeader(),
                  // 0. Vehicle Information Section (in Card)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Row(
                        children: [
                          BrandLogo(
                            brandName: trip.brand_ref ?? trip.brand ?? '',
                            size: 52,
                            padding: 10,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (trip.carModel != null &&
                                          trip.carModel!.isNotEmpty)
                                      ? trip.carModel!
                                      : i18n.t('car_model'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                if (trip.software_version_ref != null ||
                                    (trip.softwareVersion != null &&
                                        trip.softwareVersion!.isNotEmpty))
                                  Text(
                                    ref.watch(versionNameProvider(
                                        trip.software_version_ref ??
                                            trip.softwareVersion ??
                                            '')),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _editVehicleInfo,
                            icon: const Icon(Icons.edit_note, size: 18),
                            label: Text(i18n.t('edit'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.08),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Trajectory Map Display (keep original style without card background)
                  Container(
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: TripMapView(
                        trajectory: trajectory,
                        events: events,
                        isLive: false,
                        focusPoint: _focusedLocation,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1.5. AI 舒适度点评卡片
                  _AiCommentaryCard(trip: _currentTrip),
                  const SizedBox(height: 16),

                  // 2. Data Overview and Charts (combined in one card)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            child: SizedBox(
                              height: 32, // Unified title height
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(i18n.t('trip_summary'),
                                      style: _headerStyle(context)),
                                  Text(
                                    trip.getDistanceDisplay(),
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(
                                  label: i18n.t('total_events'),
                                  value: "${trip.eventCount}"),
                              _StatItem(
                                label: i18n.t('avg_speed'),
                                value: trip.getAvgSpeedDisplay(),
                              ),
                              _StatItem(
                                  label: i18n.t('duration'),
                                  value: trip.getDurationDisplay()),
                            ],
                          ),
                          const SizedBox(height: 24),
                          TripAccelerationChart(
                            trajectory: trajectory,
                            label: i18n.t('longitudinal'),
                            color: Theme.of(context).colorScheme.primary,
                            isLongitudinal: true,
                          ),
                          const SizedBox(height: 16),
                          TripAccelerationChart(
                            trajectory: trajectory,
                            label: i18n.t('lateral'),
                            color: Theme.of(context).colorScheme.secondary,
                            isLongitudinal: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2.5 Event Statistics Card (New Feature)
                  if (trip.eventStats != null)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 0),
                              child: SizedBox(
                                height: 32,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    i18n.t('event_statistics'),
                                    style: _headerStyle(context),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Auto-detected event statistics
                            _buildEventStatSection(
                              title: i18n.t('auto_negative_events'),
                              stats: trip.eventStats!['auto']
                                  as Map<String, dynamic>,
                              totalCount: _sumStats(trip.eventStats!['auto']
                                  as Map<String, dynamic>),
                              color: const Color(0xFFFF9500), // iOS Orange
                              i18n: i18n,
                              context: context,
                            ),

                            const Divider(height: 28),

                            // Manually marked event statistics
                            _buildEventStatSection(
                              title: i18n.t('manual_marked_events'),
                              stats: {
                                'proDisengagement': (trip.eventStats!['pro']
                                            as Map<String, dynamic>)[
                                        'proDisengagement'] ??
                                    0,
                                'proViolation': (trip.eventStats!['pro'] as Map<
                                        String, dynamic>)['proViolation'] ??
                                    0,
                                'proExperience': (trip.eventStats!['pro']
                                            as Map<String, dynamic>)[
                                        'proExperience'] ??
                                    0,
                                'manual': trip.eventStats!['manual'] ?? 0,
                              },
                              totalCount: _sumStats(trip.eventStats!['pro']
                                      as Map<String, dynamic>) +
                                  (trip.eventStats!['manual'] as int? ?? 0),
                              color: const Color(0xFF007AFF), // iOS Blue
                              i18n: i18n,
                              context: context,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (trip.eventStats != null) const SizedBox(height: 16),

                  // 3. Event List (in separate card)
                  if (events.isNotEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                            child: SizedBox(
                              height: 32, // Unified title height
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(i18n.t('event_list'),
                                    style: _headerStyle(context)),
                              ),
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: events.length,
                            separatorBuilder: (context, index) => const Divider(
                                indent: 20, endIndent: 20, height: 1),
                            itemBuilder: (context, index) {
                              final e = events[index];
                              final typeLabel = i18n.t(e.type);
                              Color eventColor;
                              IconData eventIcon;
                              String parameter = "--";

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
                                case 'proDisengagement':
                                  eventColor = const Color(0xFFFF3B30);
                                  eventIcon = Icons.pan_tool;
                                  break;
                                case 'proViolation':
                                  eventColor = const Color(0xFF5856D6);
                                  eventIcon = Icons.gavel;
                                  break;
                                case 'proExperience':
                                  eventColor = const Color(0xFF007AFF);
                                  eventIcon = Icons.sentiment_dissatisfied;
                                  break;
                                case 'manual':
                                  eventColor = const Color(0xFF34C759);
                                  eventIcon = Icons.stars;
                                  break;
                                default:
                                  eventColor = Colors.grey;
                                  eventIcon = Icons.event;
                              }

                              // If it's a PRO mode manual mark, parameter displays voice text, not G value
                              if (e.source == 'PRO' ||
                                  e.type.startsWith('pro')) {
                                parameter = e.voiceText ?? e.notes ?? "";
                              } else if (e.sensorData.isNotEmpty) {
                                final magnitudes = e.sensorData.map((p) {
                                  if (e.type == 'rapidAcceleration' ||
                                      e.type == 'rapidDeceleration') {
                                    return (p.ay ?? 0).abs();
                                  } else if (e.type == 'wobble') {
                                    return (p.ax ?? 0).abs();
                                  } else if (e.type == 'bump') {
                                    return (p.az ?? 0).abs();
                                  } else {
                                    return math.sqrt((p.ax ?? 0) * (p.ax ?? 0) +
                                        (p.ay ?? 0) * (p.ay ?? 0) +
                                        (p.az ?? 0) * (p.az ?? 0));
                                  }
                                }).toList();

                                double maxSmoothedVal = 0;
                                const windowSize = 3;

                                if (magnitudes.length >= windowSize) {
                                  for (int i = 0;
                                      i <= magnitudes.length - windowSize;
                                      i++) {
                                    double sum = 0;
                                    for (int j = 0; j < windowSize; j++) {
                                      sum += magnitudes[i + j];
                                    }
                                    final avg = sum / windowSize;
                                    if (avg > maxSmoothedVal) {
                                      maxSmoothedVal = avg;
                                    }
                                  }
                                } else if (magnitudes.isNotEmpty) {
                                  maxSmoothedVal =
                                      magnitudes.reduce((a, b) => a + b) /
                                          magnitudes.length;
                                }

                                // Smart unit conversion:
                                // If max value > 3.0, likely m/s² (hard to sustain 3G)
                                // Otherwise, if already in 0-2 range, likely G unit
                                double finalG;
                                if (maxSmoothedVal > 3.0) {
                                  finalG = maxSmoothedVal / 9.80665;
                                } else {
                                  finalG = maxSmoothedVal;
                                }

                                if (e.type == 'manual') finalG = 0;
                                parameter =
                                    l10n.g_unit(finalG.toStringAsFixed(2));
                              }

                              return GestureDetector(
                                onLongPressStart: (_) async {
                                  // Hidden feature: Long press for 3 seconds triggers delete confirmation
                                  final startTime = DateTime.now();
                                  bool triggered = false;

                                  // Use Timer to check long press duration
                                  Timer.periodic(
                                      const Duration(milliseconds: 500),
                                      (timer) async {
                                    if (!triggered &&
                                        DateTime.now()
                                                .difference(startTime)
                                                .inSeconds >=
                                            3) {
                                      timer.cancel();
                                      triggered = true;

                                      // Trigger haptic feedback (if available)
                                      if (!context.mounted) return;

                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(
                                              i18n.t('delete_event_title')),
                                          content:
                                              Text(i18n.t('delete_event_desc')),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: Text(i18n.t('cancel')),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor:
                                                      Colors.white),
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: Text(i18n.t('delete')),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed == true &&
                                          context.mounted) {
                                        await ref
                                            .read(storageServiceProvider)
                                            .deleteEvent(_currentTrip.id, e.id);
                                        // Refresh page data
                                        final updatedTrip = await ref
                                            .read(storageServiceProvider)
                                            .getTripById(_currentTrip.id);
                                        if (updatedTrip != null && mounted) {
                                          setState(() {
                                            _currentTrip = updatedTrip;
                                          });
                                        }
                                      }
                                    }
                                  });
                                },
                                child: ListTile(
                                  onTap: () {
                                    if (e.lat != null && e.lng != null) {
                                      setState(() {
                                        _focusedLocation =
                                            LatLng(e.lat!, e.lng!);
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
                                    child: Icon(eventIcon,
                                        color: eventColor, size: 24),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(typeLabel,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      const Spacer(),
                                      if (e.source != 'PRO' &&
                                          !e.type.startsWith('pro'))
                                        Text(parameter,
                                            style: TextStyle(
                                                color: eventColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14)),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('HH:mm:ss')
                                            .format(e.timestamp),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      if ((e.voiceText != null &&
                                              e.voiceText!.isNotEmpty) ||
                                          (e.notes != null &&
                                              e.notes!.isNotEmpty &&
                                              e.source != 'AUTO'))
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            e.voiceText ?? e.notes!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.9),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: (e.source == 'MANUAL' ||
                                          e.source == 'PRO')
                                      ? IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 20),
                                          onPressed: () =>
                                              _showEditEventDialog(e),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
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
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
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

// ─── AI 舒适度点评卡片 ──────────────────────────────────────────────────────
class _AiCommentaryCard extends ConsumerStatefulWidget {
  final Trip trip;
  const _AiCommentaryCard({required this.trip});

  @override
  ConsumerState<_AiCommentaryCard> createState() => _AiCommentaryCardState();
}

class _AiCommentaryCardState extends ConsumerState<_AiCommentaryCard> {
  bool _isLoading = false;
  String? _commentary; // 展示用：纯文本 commentary（已从 AiContent 解析）
  String? _aiLabel;   // AI 生成的吐感裁决（有则覆盖静态 label）
  late TripScore _score;
  String _lastLangCode = 'zh'; // 当前展示内容所属的语言

  // ── 用本地标志位追踪「MAD 分量是否已纳入评分」──────────────
  // 不能靠比较 widget.trip 与 oldWidget.trip 的 trajectory.isLoaded，
  // 因为两者指向同一个 Isar 对象，加载前后该属性在两侧看到的值相同。
  bool _scoreIncludesSmoothing = false;

  /// 展示用 label：AI 生成的优先，加载中时为 null（由 UI 显示占位）
  String? get _displayLabel =>
      (_aiLabel != null && _aiLabel!.isNotEmpty) ? _aiLabel : null;

  String _langCode(String languageCode) =>
      languageCode == 'en' ? 'en' : 'zh';

  @override
  void initState() {
    super.initState();
    _scoreIncludesSmoothing = widget.trip.trajectory.isLoaded;
    final locale = ref.read(i18nProvider).locale;
    _lastLangCode = _langCode(locale.languageCode);
    _score = TripScoreCalculator.calculate(
      widget.trip,
      language: scoreLabelLanguageFromLocale(locale),
    );
    _loadCachedContent(_lastLangCode);
    if (_commentary == null || _commentary!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
    }
  }

  /// 从缓存加载指定语言的内容到 UI 状态
  void _loadCachedContent(String langCode) {
    final cached = AiCommentaryService.fromTrip(widget.trip, langCode: langCode);
    _commentary = cached?.commentary?.isNotEmpty == true
        ? cached!.commentary
        : null;
    _aiLabel = cached?.label?.isNotEmpty == true ? cached!.label : null;
  }

  @override
  void didUpdateWidget(_AiCommentaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tripChanged = widget.trip.id != oldWidget.trip.id;
    // 轨迹刚加载完：之前评分未含 MAD，现在轨迹已可用 → 重算含平滑度的完整分
    final smoothingNowAvailable =
        !_scoreIncludesSmoothing && widget.trip.trajectory.isLoaded;

    if (tripChanged || smoothingNowAvailable) {
      setState(() {
        _scoreIncludesSmoothing = widget.trip.trajectory.isLoaded;
        _score = TripScoreCalculator.calculate(
          widget.trip,
          language: scoreLabelLanguageFromLocale(ref.read(i18nProvider).locale),
        );
        if (tripChanged) {
          _lastLangCode = _langCode(ref.read(i18nProvider).locale.languageCode);
          _loadCachedContent(_lastLangCode);
        }
      });
      if (tripChanged && (_commentary == null || _commentary!.isEmpty)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
      }
    }
  }

  Future<void> _generate({bool forceRefresh = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final service = ref.read(aiCommentaryServiceProvider);
      final result = await service.generateCommentary(
        widget.trip,
        brandName: widget.trip.brand,
        forceRefresh: forceRefresh,
        tripScore: _score,
      );
      if (mounted) {
        setState(() {
          _commentary = result?.commentary;
          _aiLabel = (result?.label.isNotEmpty == true) ? result!.label : null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _commentary = null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final i18n = ref.watch(i18nProvider);
    final currentLangCode = _langCode(i18n.locale.languageCode);

    // 检测语言切换：如果当前语言与上次渲染不同，切换展示内容
    if (currentLangCode != _lastLangCode) {
      _lastLangCode = currentLangCode;
      // 先尝试读取该语言的缓存
      final cached = AiCommentaryService.fromTrip(
          widget.trip, langCode: currentLangCode);
      if (cached != null && cached.commentary.isNotEmpty) {
        // 有缓存：直接切换，无需网络
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _commentary = cached.commentary;
              _aiLabel = cached.label.isNotEmpty ? cached.label : null;
            });
          }
        });
      } else {
        // 无该语言缓存：清空并重新生成
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _commentary = null;
              _aiLabel = null;
            });
            _generate();
          }
        });
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 标题行 ──────────────────────────────────────
            Row(
              children: [
                Text(
                  i18n.t('ai_commentary_card_title'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                if (!_isLoading)
                  IconButton(
                    tooltip: i18n.t('ai_regenerate_tooltip'),
                    icon: Icon(Icons.refresh, size: 20, color: cs.primary),
                    onPressed: () => _generate(forceRefresh: true),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // ── 评分区（永远显示，纯本地计算）────────────────
            _buildScoreSection(cs, i18n),

            const SizedBox(height: 16),

            // ── 分割线 ────────────────────────────────────────
            Divider(color: cs.outlineVariant.withValues(alpha: 0.5), height: 1),

            const SizedBox(height: 14),

            // ── AI 文字点评区 ─────────────────────────────────
            if (_isLoading)
              _buildLoadingState(cs, i18n)
            else if (_commentary != null && _commentary!.isNotEmpty)
              _buildCommentaryText(cs, i18n)
            else
              _buildEmptyState(cs, i18n),
          ],
        ),
      ),
    );
  }

  // ── 评分区：大号分数 + 吐感裁决，水平居中 ──────────────────────
  Widget _buildScoreSection(ColorScheme cs, dynamic i18n) {
    final scoreColor = _score.color;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${_score.score}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 76,
              fontWeight: FontWeight.w800,
              color: scoreColor,
              height: 1.0,
              letterSpacing: -3,
            ),
          ),
          const SizedBox(height: 10),
          if (_displayLabel != null)
            Text(
              '「$_displayLabel」',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: scoreColor.withValues(alpha: 0.82),
                fontStyle: FontStyle.italic,
              ),
            )
          else if (_isLoading)
            Text(
              i18n.t('ai_verdict_pending'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scoreColor.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  // ── 加载中 ─────────────────────────────────────────────────
  Widget _buildLoadingState(ColorScheme cs, dynamic i18n) {
    return Row(
      children: [
        SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Text(
          i18n.t('ai_generating'),
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  // ── 有内容 ────────────────────────────────────────────────
  Widget _buildCommentaryText(ColorScheme cs, dynamic i18n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _commentary!,
          style: TextStyle(
            fontSize: 14,
            height: 1.7,
            color: cs.onSurface.withValues(alpha: 0.9),
          ),
        ),
        if (widget.trip.aiCommentaryGeneratedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              i18n.t('ai_generated_at',
                  args: [_formatDt(widget.trip.aiCommentaryGeneratedAt!)]),
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
      ],
    );
  }

  // ── 空态（未生成） ────────────────────────────────────────
  Widget _buildEmptyState(ColorScheme cs, dynamic i18n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          i18n.t('ai_no_commentary'),
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.tonal(
          onPressed: () => _generate(forceRefresh: true),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(40),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, size: 15),
              const SizedBox(width: 6),
              Text(i18n.t('ai_generate_btn')),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDt(DateTime dt) {
    return '${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// Helper function: Calculate total statistics count
int _sumStats(Map<String, dynamic> stats) {
  int total = 0;
  stats.forEach((key, value) {
    if (value is int) total += value;
  });
  return total;
}

// Helper function: Build event statistics section
Widget _buildEventStatSection({
  required String title,
  required Map<String, dynamic> stats,
  required int totalCount,
  required Color color,
  required I18n i18n,
  required BuildContext context,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              i18n.t('total_count', args: [totalCount.toString()]),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: stats.entries
            .where((e) => (e.value is int && e.value > 0))
            .map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              '${i18n.t(e.key)} ${e.value}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
        }).toList(),
      ),
    ],
  );
}
