import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/features/history/presentation/trip_detail_screen.dart';
import 'package:puked/common/utils/i18n.dart';

class VehicleInfoScreen extends ConsumerStatefulWidget {
  final int tripId;
  final bool isEdit;

  const VehicleInfoScreen(
      {super.key, required this.tripId, this.isEdit = false});

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
    _loadExistingInfo();
  }

  Future<void> _loadExistingInfo() async {
    final storage = ref.read(storageServiceProvider);
    final trips = await storage.getAllTrips();
    final trip = trips.firstWhere((t) => t.id == widget.tripId);

    setState(() {
      _modelController.text = trip.carModel ?? '';
      _versionController.text = trip.softwareVersion ?? '';
      _selectedBrand = trip.adasBrand;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _modelController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _saveInfo(bool skip) async {
    final storage = ref.read(storageServiceProvider);

    if (!skip) {
      await storage.updateTripVehicleInfo(
        widget.tripId,
        adasBrand: _selectedBrand,
        carModel: _modelController.text.trim(),
        softwareVersion: _versionController.text.trim(),
      );
    }

    if (mounted) {
      if (widget.isEdit) {
        // 编辑模式下直接返回并通知更新
        Navigator.of(context).pop(true);
      } else {
        // 新增模式下跳转到详情页
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEdit ? i18n.t('modifyVehicleInfo') : i18n.t('vehicleInfo'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        automaticallyImplyLeading: widget.isEdit, // 编辑模式允许点击左上角返回
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
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
                            decoration: BoxDecoration(
                              color:
                                  Colors.transparent, // 无论模式，去掉 Logo 下方的二次背景色
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SvgPicture.asset(
                              'assets/logos/$brand.svg',
                              // 深色模式下将黑色 Logo 滤镜为白色，解决可见性问题
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
              decoration: InputDecoration(
                labelText: i18n.t('car_model'),
                labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                hintText: i18n.t('modelHint'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.directions_car),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _versionController,
              decoration: InputDecoration(
                labelText: i18n.t('softwareVersion'),
                labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                hintText: i18n.t('versionHint'),
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
