import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:puked/services/export/export_service.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/features/history/presentation/trip_detail_screen.dart';
import 'package:puked/common/widgets/brand_logo.dart';
import 'package:puked/services/cloud_trip_service.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/features/recording/providers/vehicle_provider.dart';
import 'package:puked/features/history/providers/trip_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _isDeleteMode = false;
  final Set<int> _selectedIds = {};

  void _toggleDeleteMode() {
    setState(() {
      _isDeleteMode = !_isDeleteMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final i18n = ref.read(i18nProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Text(
              i18n.t('delete_trips'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          i18n.t('delete_trips_confirm',
              args: [_selectedIds.length.toString()]),
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              i18n.t('cancel'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .errorContainer
                  .withValues(alpha: 0.8),
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              i18n.t('delete'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(storageServiceProvider).deleteTrips(_selectedIds.toList());
      setState(() {
        _selectedIds.clear();
        _isDeleteMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsProvider);
    final i18n = ref.watch(i18nProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isDeleteMode ? i18n.t('select_items') : i18n.t('history')),
        actions: [
          if (!_isDeleteMode) ...[
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () async {
                final cloudService = ref.read(cloudTripServiceProvider);
                final storage = ref.read(storageServiceProvider);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(i18n.t('pulling_cloud_trips'))),
                );

                try {
                  final newCount = await cloudService.syncCloudToLocal(storage);

                  if (!context.mounted) return;
                  setState(() {});

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(i18n
                          .t('cloud_sync_result', args: [newCount.toString()])),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  debugPrint('Sync error: $e');
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(i18n.t('sync_failed')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              tooltip: i18n.t('sync_cloud_status'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _toggleDeleteMode,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ] else ...[
            if (ref.watch(authProvider).isPro)
              TextButton(
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(i18n.t('submit_trip')),
                            content: Text(i18n.t('bulk_upload_confirm',
                                args: [_selectedIds.length.toString()])),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(i18n.t('cancel')),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(i18n.t('upload')),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          if (!context.mounted) return;

                          final storage = ref.read(storageServiceProvider);
                          final cloudService =
                              ref.read(cloudTripServiceProvider);

                          // 数据充足性校验
                          bool allSufficient = true;
                          final List<int> validIds = [];

                          for (final id in _selectedIds) {
                            final trip = await storage.getTripById(id);
                            if (trip != null) {
                              if (!trip.isDataSufficient) {
                                allSufficient = false;
                              } else {
                                validIds.add(id);
                              }
                            }
                          }

                          if (!allSufficient) {
                            if (!context.mounted) return;
                            final proceed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(i18n.t('insufficient_data_title')),
                                content:
                                    Text(i18n.t('insufficient_data_message')),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(i18n.t('cancel')),
                                  ),
                                  if (validIds.isNotEmpty)
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(i18n.t('upload')),
                                    ),
                                ],
                              ),
                            );
                            if (proceed != true) return;
                          }

                          final idsToUpload =
                              allSufficient ? _selectedIds : validIds;
                          if (idsToUpload.isEmpty) return;

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(i18n.t('uploading'))),
                          );

                          int successCount = 0;
                          for (final id in idsToUpload) {
                            try {
                              final trip = await storage.getTripById(id);
                              if (trip != null && !trip.isUploaded) {
                                final result =
                                    await cloudService.uploadTrip(trip);
                                final cloudId = result['id'] as String;
                                final metrics =
                                    result['metrics'] as Map<String, dynamic>?;

                                await storage.updateTripCloudId(
                                    trip.id, cloudId,
                                    metrics: metrics);
                                successCount++;
                              } else if (trip != null && trip.isUploaded) {
                                successCount++; // Already uploaded counts as success for bulk selection
                              }
                            } catch (e) {
                              debugPrint('Bulk upload error for id $id: $e');
                            }
                          }

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(successCount == _selectedIds.length
                                  ? i18n.t('upload_success')
                                  : i18n.t('upload_failed')),
                              backgroundColor:
                                  successCount == _selectedIds.length
                                      ? Colors.green
                                      : Colors.orange,
                            ),
                          );

                          if (successCount > 0) {
                            setState(() {
                              _selectedIds.clear();
                              _isDeleteMode = false;
                            });
                          }
                        }
                      },
                child: Text(
                  i18n.t('upload'),
                  style: TextStyle(
                      color: _selectedIds.isEmpty
                          ? Colors.grey
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
              ),
            TextButton(
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
              child: Text(
                "${i18n.t('delete')} (${_selectedIds.length})",
                style: TextStyle(
                    color: _selectedIds.isEmpty
                        ? Colors.grey
                        : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleDeleteMode,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ]
        ],
        scrolledUnderElevation: 0,
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          final errStr = err.toString();
          // 如果是 Isar 竞态错误，显示一个更友好的重试界面，而不是直接报错
          if (errStr.contains('already been opened') ||
              errStr.contains('IllegalArg')) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(i18n.t('syncing')),
                ],
              ),
            );
          }
          return Center(child: Text('${i18n.t('error')}: $err'));
        },
        data: (trips) {
          final i18n = ref.watch(i18nProvider);

          if (trips.isEmpty) {
            return Center(
              child: Text(
                i18n.t('no_trips'),
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            );
          }

          return SafeArea(
            left: true,
            right: true,
            top: false,
            bottom: false,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: trips.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final trip = trips[index];
                return _TripCard(
                  trip: trip,
                  isDeleteMode: _isDeleteMode,
                  isSelected: _selectedIds.contains(trip.id),
                  onTap: _isDeleteMode ? () => _toggleSelection(trip.id) : null,
                  onSelectChanged: (val) => _toggleSelection(trip.id),
                  onRefresh: () => setState(() {}),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TripCard extends ConsumerStatefulWidget {
  final Trip trip;
  final bool isDeleteMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onSelectChanged;
  final VoidCallback? onRefresh;

  const _TripCard({
    required this.trip,
    this.isDeleteMode = false,
    this.isSelected = false,
    this.onTap,
    this.onSelectChanged,
    this.onRefresh,
  });

  @override
  ConsumerState<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends ConsumerState<_TripCard> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final isSelected = widget.isSelected;
    final isDeleteMode = widget.isDeleteMode;
    final onSelectChanged = widget.onSelectChanged;
    final onTap = widget.onTap;
    final onRefresh = widget.onRefresh;

    final i18n = ref.watch(i18nProvider);
    final datePattern = i18n.locale.languageCode == 'zh'
        ? 'yyyy-MM-dd HH:mm'
        : 'MMM dd, yyyy HH:mm';
    final dateStr = DateFormat(datePattern).format(trip.startTime);
    // 核心逻辑修改：使用 isLocalMissing 字段判断是否为纯云端行程
    final isCloudOnly = trip.isLocalMissing;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isCloudOnly
            ? (isDarkMode
                ? Colors.white.withAlpha(26) // 暗色模式：微弱的半透明白色（呈现深灰色感）
                : Colors.white.withAlpha(153)) // 亮色模式：明显的半透明白色
            : (isSelected
                ? Theme.of(context).colorScheme.primary.withAlpha(38)
                : (isDarkMode
                    ? Theme.of(context).cardTheme.color
                    : Colors.white)), // 本地有 JSON 时设为纯白（或深色模式卡片色）
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(
                color: Theme.of(context).colorScheme.primary.withAlpha(128))
            : null, // 去掉云端行程的描边，保持纯粹的半透明感
        boxShadow: isCloudOnly
            ? null // 云端行程不带阴影，显得更“薄”
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isCloudOnly
                ? null // 核心逻辑：本地没 JSON 不可点击
                : (onTap ??
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TripDetailScreen(trip: trip)),
                      ).then((_) => onRefresh?.call());
                    }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (isDeleteMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: onSelectChanged,
                      activeColor: Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Opacity(
                    opacity: isCloudOnly ? 0.3 : 1.0, // 纯云端 Logo 进一步变淡
                    child: BrandLogo(
                      brandName: trip.brand_ref ?? trip.brand ?? '',
                      size: 52,
                      padding: 10,
                      showBackground: !isCloudOnly, // 只有本地行程才显示 Logo 背景圆圈
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              (trip.carModel != null &&
                                      trip.carModel!.isNotEmpty)
                                  ? trip.carModel!
                                  : i18n.t('car_model'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: isCloudOnly
                                    ? (isDarkMode
                                        ? Colors.white.withAlpha(128)
                                        : Colors.black
                                            .withAlpha(128)) // 适配黑白天的灰色
                                    : (isDarkMode
                                        ? Colors.white.withAlpha(242)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface),
                              ),
                            ),
                            if (trip.software_version_ref != null ||
                                (trip.softwareVersion != null &&
                                    trip.softwareVersion!.isNotEmpty))
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isCloudOnly
                                      ? (isDarkMode
                                          ? Colors.white.withAlpha(26)
                                          : Colors.black.withAlpha(13))
                                      : Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withAlpha(38),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ref.watch(versionNameProvider(
                                      trip.software_version_ref ??
                                          trip.softwareVersion ??
                                          '')),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isCloudOnly
                                        ? (isDarkMode
                                            ? Colors.white.withAlpha(102)
                                            : Colors.black.withAlpha(102))
                                        : Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isCloudOnly
                              ? "${i18n.t('cloud_trip')} · $dateStr"
                              : dateStr,
                          style: TextStyle(
                            color: isCloudOnly
                                ? (isDarkMode
                                    ? Colors.white.withAlpha(77)
                                    : Colors.black.withAlpha(77))
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Icon(Icons.event_note_outlined,
                                  size: 12,
                                  color: isCloudOnly
                                      ? (isDarkMode
                                          ? Colors.white.withAlpha(51)
                                          : Colors.black.withAlpha(51))
                                      : Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withAlpha(153)),
                              const SizedBox(width: 4),
                              Text(
                                i18n.t('events_count',
                                    args: [trip.eventCount.toString()]),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isCloudOnly
                                        ? (isDarkMode
                                            ? Colors.white.withAlpha(51)
                                            : Colors.black.withAlpha(51))
                                        : Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withAlpha(153)),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.straighten_outlined,
                                  size: 12,
                                  color: isCloudOnly
                                      ? (isDarkMode
                                          ? Colors.white.withAlpha(51)
                                          : Colors.black.withAlpha(51))
                                      : Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withAlpha(153)),
                              const SizedBox(width: 4),
                              Text(
                                trip.getDistanceDisplay(),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isCloudOnly
                                        ? (isDarkMode
                                            ? Colors.white.withAlpha(51)
                                            : Colors.black.withAlpha(51))
                                        : Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withAlpha(153)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDeleteMode)
                    const SizedBox(width: 8)
                  else ...[
                    if (isCloudOnly)
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: _isDownloading
                            ? const Padding(
                                padding: EdgeInsets.all(10.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue),
                                ),
                              )
                            : IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  setState(() => _isDownloading = true);

                                  final cloudService =
                                      ref.read(cloudTripServiceProvider);
                                  final storage =
                                      ref.read(storageServiceProvider);

                                  try {
                                    final cloudId = trip.cloudId;
                                    if (cloudId == null) return;

                                    final pb = ref.read(pbServiceProvider).pb;
                                    final record = await pb
                                        .collection('trips')
                                        .getOne(cloudId);
                                    final fileName =
                                        record.getStringValue('raw_log_file');

                                    if (fileName.isEmpty) {
                                      throw Exception(
                                          'No log file found on cloud');
                                    }

                                    final data =
                                        await cloudService.downloadTripData(
                                            record.id,
                                            fileName); // 传入 record.id 保证一致性
                                    debugPrint(
                                        '[PukedSync] UI: Final step - calling completePlaceholderTrip');
                                    if (data != null) {
                                      await storage.completePlaceholderTrip(
                                          trip.id, data);
                                      debugPrint(
                                          '[PukedSync] UI: completePlaceholderTrip finished');
                                      if (!context.mounted) return;
                                      setState(() => _isDownloading = false);
                                      onRefresh?.call();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text(i18n.t('download_success')),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      debugPrint(
                                          '[PukedSync] UI: Download returned null data');
                                      throw Exception(
                                          'Download returned null data');
                                    }
                                  } catch (e, stack) {
                                    debugPrint(
                                        '[PukedSync] UI Layer ERROR: $e');
                                    debugPrint(
                                        '[PukedSync] UI Layer STACKTRACE: $stack');
                                    if (!context.mounted) return;
                                    setState(() => _isDownloading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text(i18n.t('download_failed')),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.file_download_outlined,
                                    color: Colors.blue),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.blue.withAlpha(25),
                                ),
                              ),
                      )
                    else ...[
                      // 只有本地存在数据时，才显示云端图标和分享按钮
                      if (ref.watch(authProvider).isPro)
                        trip.isUploaded
                            ? Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.cloud_done,
                                  color: Colors.green,
                                  size: 24,
                                ),
                              )
                            : SizedBox(
                                width: 40,
                                height: 40,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    if (!trip.isDataSufficient) {
                                      if (context.mounted) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(i18n
                                                .t('insufficient_data_title')),
                                            content: Text(i18n.t(
                                                'insufficient_data_message')),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text(i18n.t('save')),
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
                                        content:
                                            Text(i18n.t('submit_trip_confirm')),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text(i18n.t('cancel')),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text(i18n.t('upload')),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(i18n.t('uploading'))),
                                      );
                                      try {
                                        final result = await ref
                                            .read(cloudTripServiceProvider)
                                            .uploadTrip(trip);

                                        final cloudId = result['id'] as String;
                                        final metrics = result['metrics']
                                            as Map<String, dynamic>?;

                                        await ref
                                            .read(storageServiceProvider)
                                            .updateTripCloudId(trip.id, cloudId,
                                                metrics: metrics);

                                        onRefresh?.call();

                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text(i18n.t('upload_success')),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text(i18n.t('upload_failed')),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: Icon(Icons.cloud_upload_outlined,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withAlpha(13),
                                  ),
                                ),
                              ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(i18n.t('exporting')),
                                  duration: const Duration(seconds: 1)),
                            );

                            final RenderBox? box =
                                context.findRenderObject() as RenderBox?;
                            final Rect? rect = box != null
                                ? box.localToGlobal(Offset.zero) & box.size
                                : null;

                            await ref
                                .read(exportServiceProvider)
                                .exportTrip(trip, sharePositionOrigin: rect);
                          },
                          icon: Icon(Icons.share_outlined,
                              color: Theme.of(context).colorScheme.onSurface),
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(13),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
