import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:puked/features/history/presentation/trip_detail_screen.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/services/storage/storage_service.dart';

class VehicleInfoScreen extends ConsumerStatefulWidget {
  final int? tripId;
  final bool isEdit;
  final bool isSettingsMode;

  const VehicleInfoScreen({
    super.key,
    this.tripId,
    this.isEdit = false,
    this.isSettingsMode = false,
  });

  @override
  ConsumerState<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends ConsumerState<VehicleInfoScreen> {
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _versionController = TextEditingController();
  String? _selectedBrand;
  bool _isLoading = true;

  final List<String> _brands = [
    'Tesla',
    'Xpeng',
    'LiAuto',
    'Nio',
    'Xiaomi',
    'Huawei',
    'Zeekr',
    'Onvo',
    'ApolloGo',
    'PONYai',
    'WeRide',
    'Waymo',
    'Zoox',
    'Wayve',
    'Momenta',
    'Nvidia',
    'Horizon',
    'Deeproute',
    'Leapmotor'
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialInfo();
  }

  Future<void> _loadInitialInfo() async {
    if (widget.isSettingsMode) {
      final settings = ref.read(settingsProvider);
      setState(() {
        _modelController.text = settings.carModel ?? '';
        _versionController.text = settings.softwareVersion ?? '';
        _selectedBrand = settings.brand;
        _isLoading = false;
      });
    } else if (widget.tripId != null) {
      final storage = ref.read(storageServiceProvider);
      final trips = await storage.getAllTrips();
      final trip = trips.firstWhere((t) => t.id == widget.tripId);

      // 如果是新纪录且未设置过，优先使用设置中的默认值
      final settings = ref.read(settingsProvider);

      setState(() {
        _modelController.text = trip.carModel ?? settings.carModel ?? '';
        _versionController.text =
            trip.softwareVersion ?? settings.softwareVersion ?? '';
        _selectedBrand = trip.brand ?? settings.brand;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _modelController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _saveInfo(bool skip) async {
    if (widget.isSettingsMode) {
      if (!skip) {
        await ref.read(settingsProvider.notifier).setVehicleInfo(
              brand: _selectedBrand,
              model: _modelController.text.trim(),
              version: _versionController.text.trim(),
            );
      }
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (widget.tripId == null) return;

    final storage = ref.read(storageServiceProvider);

    if (!skip) {
      await storage.updateTripVehicleInfo(
        widget.tripId!,
        brand: _selectedBrand,
        carModel: _modelController.text.trim(),
        softwareVersion: _versionController.text.trim(),
      );
    }

    if (mounted) {
      if (widget.isEdit) {
        Navigator.of(context).pop(true);
      } else {
        final trips = await storage.getAllTrips();
        final trip = trips.firstWhere((t) => t.id == widget.tripId);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => TripDetailScreen(trip: trip),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String title;
    if (widget.isSettingsMode) {
      title = i18n.t('my_car');
    } else {
      title = widget.isEdit
          ? i18n.t('modify_vehicle_info')
          : i18n.t('vehicle_info');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        automaticallyImplyLeading: widget.isEdit || widget.isSettingsMode,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    MediaQuery.of(context).orientation == Orientation.landscape
                        ? 8
                        : 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: _brands.length,
              itemBuilder: (context, index) {
                final brand = _brands[index];
                final isSelected = _selectedBrand == brand;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBrand = isSelected ? null : brand;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: isSelected
                          ? Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.1)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            child: SvgPicture.asset(
                              'assets/logos/$brand.svg',
                              colorFilter: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const ColorFilter.mode(
                                      Colors.white, BlendMode.srcIn)
                                  : null,
                              placeholderBuilder: (context) => const Icon(
                                  Icons.help_outline,
                                  color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          brand,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isSelected ? FontWeight.w900 : FontWeight.w500,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _modelController,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.95)
                    : Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                labelText: i18n.t('car_model'),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                hintText: i18n.t('model_hint'),
                hintStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.3)
                      : null,
                ),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.directions_car),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _versionController,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.95)
                    : Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                labelText: i18n.t('software_version'),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                hintText: i18n.t('version_hint'),
                hintStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.3)
                      : null,
                ),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.code),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _saveInfo(true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    i18n.t('skip'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _saveInfo(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: Text(
                    i18n.t('save'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
