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
import 'package:puked/features/auth/providers/auth_provider.dart';
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
                  SnackBar(content: Text(i18n.t('syncing'))),
                );

                final cloudUuids = await cloudService.getUploadedLocalUuids();
                final syncedCount = await storage.syncTripsStatus(cloudUuids);

                if (!context.mounted) return;
                setState(() {});

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(i18n
                        .t('sync_complete', args: [syncedCount.toString()])),
                    backgroundColor: Colors.green,
                  ),
                );
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(i18n.t('uploading'))),
                          );

                          int successCount = 0;
                          final storage = ref.read(storageServiceProvider);
                          final cloudService =
                              ref.read(cloudTripServiceProvider);

                          for (final id in _selectedIds) {
                            try {
                              final trip = await storage.getTripById(id);
                              if (trip != null && !trip.isUploaded) {
                                final cloudId =
                                    await cloudService.uploadTrip(trip);
                                await storage.updateTripCloudId(
                                    trip.id, cloudId);
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
          // 如果是 Isar 竞态错误，显示一个更友好的重试界面，而不是直接报错
          if (err.toString().contains('already been opened')) {
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
          return Center(child: Text('Error: $err'));
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

class _TripCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(trip.startTime);
    final i18n = ref.watch(i18nProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.5))
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap ??
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TripDetailScreen(trip: trip)),
                  ).then((_) => onRefresh?.call());
                },
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
                  BrandLogo(
                    brandName: trip.brand,
                    size: 52,
                    padding: 10,
                    showBackground: true,
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
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.95)
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            if (trip.softwareVersion != null &&
                                trip.softwareVersion!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  trip.softwareVersion!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                              Text(
                                i18n.t('events_count',
                                    args: [trip.eventCount.toString()]),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.6)),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.straighten_outlined,
                                  size: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                              Text(
                                "${(trip.distance / 1000).toStringAsFixed(2)} km",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.6)),
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
                    if (ref.watch(authProvider).isPro)
                      trip.isUploaded
                          ? Container(
                              width: 40, // 增加固定宽度对齐
                              height: 40, // 增加固定高度对齐
                              alignment: Alignment.center,
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
                          : SizedBox(
                              width: 40,
                              height: 40,
                              child: IconButton(
                                padding: EdgeInsets.zero, // 消除默认内边距
                                constraints: const BoxConstraints(), // 消除默认限制
                                onPressed: () async {
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(i18n.t('uploading'))),
                                    );
                                    try {
                                      final cloudId = await ref
                                          .read(cloudTripServiceProvider)
                                          .uploadTrip(trip);
                                      await ref
                                          .read(storageServiceProvider)
                                          .updateTripCloudId(trip.id, cloudId);

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
                                      .withValues(alpha: 0.05),
                                ),
                              ),
                            ),
                    const SizedBox(width: 8), // 增加一点间距
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
                          await ref
                              .read(exportServiceProvider)
                              .exportTrip(trip);
                        },
                        icon: Icon(Icons.share_outlined,
                            color: Theme.of(context).colorScheme.onSurface),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.05),
                        ),
                      ),
                    ),
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
