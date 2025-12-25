import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/services/export/export_service.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/features/history/presentation/trip_detail_screen.dart';

final exportServiceProvider = Provider((ref) => ExportService());

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
        surfaceTintColor: Colors.transparent, // 禁用 M3 的紫色叠加
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
              backgroundColor:
                  Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.8),
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
    final storage = ref.watch(storageServiceProvider);
    final i18n = ref.watch(i18nProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isDeleteMode ? i18n.t('select_items') : i18n.t('history'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            )),
        actions: [
          if (!_isDeleteMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _toggleDeleteMode,
            )
          else ...[
            TextButton(
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
              child: Text(
                "${i18n.t('delete')} (${_selectedIds.length})",
                style: TextStyle(
                    color: _selectedIds.isEmpty
                        ? Colors.grey
                        : Theme.of(context).colorScheme.error),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleDeleteMode,
            ),
          ]
        ],
        backgroundColor: Colors.transparent,
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: FutureBuilder<List<Trip>>(
        future: storage.getAllTrips(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final trips = snapshot.data ?? [];
          if (trips.isEmpty) {
            return Center(
              child: Text(
                i18n.t('no_trips'),
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return _TripCard(
                trip: trip,
                isDeleteMode: _isDeleteMode,
                isSelected: _selectedIds.contains(trip.id),
                onTap: _isDeleteMode ? () => _toggleSelection(trip.id) : null,
                onSelectChanged: (val) => _toggleSelection(trip.id),
              );
            },
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

  const _TripCard({
    required this.trip,
    this.isDeleteMode = false,
    this.isSelected = false,
    this.onTap,
    this.onSelectChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(trip.startTime);
    final i18n = ref.watch(i18nProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                : Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.3)),
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
                  );
                },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (isDeleteMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: onSelectChanged,
                      shape: const CircleBorder(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.route,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${trip.carModel ?? i18n.t('car_model')} · ${i18n.t('events_count', args: [
                                trip.eventCount.toString()
                              ])} · ${(trip.distance / 1000).toStringAsFixed(2)} km",
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isDeleteMode)
                    IconButton(
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(i18n.t('exporting')),
                              duration: const Duration(seconds: 1)),
                        );
                        await ref.read(exportServiceProvider).exportTrip(trip);
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
