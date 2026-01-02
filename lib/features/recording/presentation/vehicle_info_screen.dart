import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/features/history/presentation/trip_detail_screen.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/common/widgets/brand_selection.dart';
import 'package:puked/features/recording/providers/vehicle_provider.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

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
  bool _isInitialized = false;

  // 图片相关状态
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // 监听输入变化，用于刷新按钮状态 (使用 microtask 避免在 build 期间触发 setState)
    _modelController.addListener(() {
      if (mounted) {
        Future.microtask(() => setState(() {}));
      }
    });
    _versionController.addListener(() {
      if (mounted) {
        Future.microtask(() => setState(() {}));
      }
    });
  }

  Future<void> _loadInitialData() async {
    final storage = ref.read(storageServiceProvider);

    if (widget.isSettingsMode) {
      final settings = ref.read(settingsProvider);
      _modelController.text = settings.carModel ?? '';
      _versionController.text = settings.softwareVersion ?? '';
      _selectedBrand = settings.brand;
    } else if (widget.tripId != null) {
      final trips = await storage.getAllTrips();
      final trip = trips.firstWhere((t) => t.id == widget.tripId);
      final settings = ref.read(settingsProvider);

      _modelController.text = trip.carModel ?? settings.carModel ?? '';
      _versionController.text =
          trip.softwareVersion ?? settings.softwareVersion ?? '';
      _selectedBrand = trip.brand ?? settings.brand;
    }

    setState(() {
      _isInitialized = true;
    });
  }

  // 选择图片
  Future<void> _pickImages() async {
    final auth = ref.read(authProvider);
    final status = auth.user?.getStringValue('audit_status') ?? '';
    if (status == 'pending') return; // 认证中不允许操作

    if (_selectedImages.length >= 3) {
      _showError(ref.read(i18nProvider).t('error_image_limit'));
      return;
    }

    final List<XFile> images = await _picker.pickMultiImage(
      imageQuality: 80,
    );

    if (images.isEmpty) return;

    final i18n = ref.read(i18nProvider);
    for (var image in images) {
      // 校验格式
      final ext = image.path.toLowerCase();
      if (!ext.endsWith('.jpg') &&
          !ext.endsWith('.jpeg') &&
          !ext.endsWith('.png')) {
        _showError(i18n.t('error_image_type'));
        continue;
      }

      // 校验大小 (5MB)
      final size = await image.length();
      if (size > 5 * 1024 * 1024) {
        _showError(i18n.t('error_image_size'));
        continue;
      }

      if (_selectedImages.length < 3) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // 核心逻辑：判断保存按钮是否可点击
  bool _isFormValid() {
    if (widget.isSettingsMode) {
      return _selectedBrand != null &&
          _modelController.text.trim().isNotEmpty &&
          _versionController.text.trim().isNotEmpty &&
          _selectedImages.isNotEmpty;
    } else {
      // 非认证模式，品牌必选即可，其它可选
      return _selectedBrand != null;
    }
  }

  Future<void> _saveInfo(bool skip) async {
    final brand = _selectedBrand;
    final version = _versionController.text.trim();
    final model = _modelController.text.trim();

    if (!skip && brand != null && version.isNotEmpty) {
      final storage = ref.read(storageServiceProvider);
      await storage.addVersion(brand, version, isCustom: true);
    }

    if (widget.isSettingsMode) {
      if (!skip) {
        await ref.read(settingsProvider.notifier).setVehicleInfo(
              brand: brand,
              model: model,
              version: version,
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
        brand: brand,
        carModel: model,
        softwareVersion: version,
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

  Future<void> _saveAndSubmit() async {
    if (!_isFormValid() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final i18n = ref.read(i18nProvider);
      final auth = ref.read(authProvider);
      final pb = ref.read(pbServiceProvider).pb;

      // 1. 准备上传到 PocketBase 的资料
      final Map<String, dynamic> body = {
        'brand': _selectedBrand,
        'car_model': _modelController.text.trim(),
        'software_version': _versionController.text.trim(),
        'audit_status': 'pending', // 提交后重置状态为待审核
      };

      // 2. 处理图片上传
      final List<http.MultipartFile> files = [];
      for (var image in _selectedImages) {
        files.add(await http.MultipartFile.fromPath(
          'certification_images',
          image.path,
        ));
      }

      // 3. 执行更新
      await pb.collection('users').update(
            auth.user!.id,
            body: body,
            files: files,
          );

      // 4. 同步本地设置
      await ref.read(settingsProvider.notifier).setVehicleInfo(
            brand: _selectedBrand,
            model: _modelController.text.trim(),
            version: _versionController.text.trim(),
          );

      // 5. 刷新本地用户状态
      await ref.read(authProvider.notifier).refreshUserFromServer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(i18n.t('submit_success_tip')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      String errorMessage = 'Submit failed';
      if (e is ClientException) {
        final errorData = e.response['data'];
        final i18n = ref.read(i18nProvider);
        if (errorData != null &&
            errorData is Map &&
            errorData.containsKey('certification_images')) {
          errorMessage = i18n.t('error_image_size');
        } else {
          errorMessage = e.response['message'] ?? e.toString();
        }
      } else {
        errorMessage = e.toString();
      }
      _showError(errorMessage);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _onBrandSelected(String? brandName) {
    if (_selectedBrand == brandName) {
      setState(() {
        _selectedBrand = null;
        _versionController.clear();
        _modelController.clear();
      });
      return;
    }

    setState(() {
      _selectedBrand = brandName;
      _versionController.clear();
      _modelController.clear();
    });
  }

  @override
  void dispose() {
    _modelController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  Widget _buildVersionField(BuildContext context, dynamic i18n,
      AsyncValue<List<SoftwareVersion>> presetVersionsAsync) {
    return presetVersionsAsync.when(
      data: (versions) {
        final List<String> options =
            versions.map((v) => v.versionString).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenu<String>(
              controller: _versionController,
              initialSelection: _versionController.text.isNotEmpty
                  ? _versionController.text
                  : null,
              width: constraints.maxWidth,
              hintText: i18n.t('version_hint'),
              label: Text(i18n.t('software_version'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              leadingIcon: const Icon(Icons.code),
              enableSearch: true,
              enableFilter: true,
              requestFocusOnTap: true,
              inputDecorationTheme: InputDecorationTheme(
                border: const OutlineInputBorder(),
                filled: false,
                labelStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              textStyle: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.95)
                    : Theme.of(context).colorScheme.onSurface,
              ),
              dropdownMenuEntries:
                  options.map<DropdownMenuEntry<String>>((String version) {
                return DropdownMenuEntry<String>(
                  value: version,
                  label: version,
                  trailingIcon: const Icon(Icons.history, size: 16),
                );
              }).toList(),
              onSelected: (String? selection) {
                if (selection != null) {
                  setState(() {
                    _versionController.text = selection;
                  });
                }
              },
            );
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, s) => TextField(
        controller: _versionController,
        decoration: InputDecoration(
          labelText: i18n.t('software_version'),
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.code),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final brandsAsync = ref.watch(availableBrandsProvider);

    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return brandsAsync.when(
      data: (brands) => _buildContent(context, i18n, brands),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildContent(BuildContext context, dynamic i18n, List<Brand> brands) {
    final presetVersionsAsync = _selectedBrand != null
        ? ref.watch(presetVersionsProvider(_selectedBrand!))
        : const AsyncValue<List<SoftwareVersion>>.data([]);

    final auth = ref.watch(authProvider);
    final auditStatus = auth.user?.getStringValue('audit_status') ?? '';
    final isPending = auditStatus == 'pending';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isSettingsMode ? i18n.t('my_car') : i18n.t('vehicle_info'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. 顶部 Banner (仅在设置模式显示)
            if (widget.isSettingsMode)
              _buildCertificationBanner(context, i18n, auditStatus),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    BrandSelectionGrid(
                      brands: brands,
                      selectedBrandName: _selectedBrand,
                      onBrandSelected: (brand) => _onBrandSelected(brand.name),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _modelController,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.95)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: i18n.t('car_model'),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        hintText: i18n.t('model_hint'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.directions_car),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildVersionField(context, i18n, presetVersionsAsync),

                    // 2. 图片上传区域 (仅在设置模式显示)
                    if (widget.isSettingsMode) ...[
                      const SizedBox(height: 32),
                      Text(
                        isPending
                            ? i18n.t('upload_cert_photos_submitted')
                            : i18n.t('upload_cert_photos_new'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (!isPending) ...[
                        const SizedBox(height: 8),
                        Text(
                          i18n.t('upload_hint_new'),
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // 图片预览网格
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: _selectedImages.length +
                            (_selectedImages.length < 3 && !isPending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _selectedImages.length) {
                            return GestureDetector(
                              onTap: _pickImages,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant),
                                ),
                                child: Icon(
                                  Icons.add_a_photo_outlined,
                                  color: isDark ? Colors.white70 : Colors.grey,
                                ),
                              ),
                            );
                          }

                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_selectedImages[index].path),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (!isPending)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _selectedImages.removeAt(index)),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.close,
                                          size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      if (!isPending) ...[
                        const SizedBox(height: 8),
                        Text(
                          i18n.t('file_limit_hint'),
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: widget.isSettingsMode
              ? _buildCertificationButton(context, i18n, isPending)
              : _buildOriginalButtons(context, i18n),
        ),
      ),
    );
  }

  Widget _buildCertificationBanner(
      BuildContext context, dynamic i18n, String status) {
    Color bannerColor;
    String bannerText;
    IconData icon;

    switch (status) {
      case 'pending':
        bannerColor = Colors.orange;
        bannerText = i18n.t('car_cert_banner_pending');
        icon = Icons.hourglass_empty;
        break;
      case 'rejected':
        bannerColor = Colors.red;
        bannerText = i18n.t('car_cert_banner_rejected');
        icon = Icons.error_outline;
        break;
      case 'approved':
        bannerColor = Colors.green;
        bannerText = i18n.t('car_cert_banner_approved');
        icon = Icons.verified;
        break;
      default:
        bannerColor = Theme.of(context).colorScheme.primary;
        bannerText = i18n.t('car_cert_banner');
        icon = Icons.verified_user;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: bannerColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(icon, size: 20, color: bannerColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              bannerText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: bannerColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationButton(
      BuildContext context, dynamic i18n, bool isPending) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isFormValid() && !_isSubmitting && !isPending)
            ? _saveAndSubmit
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.grey.shade300,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(
                i18n.t('submit_for_audit'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
      ),
    );
  }

  Widget _buildOriginalButtons(BuildContext context, dynamic i18n) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _saveInfo(true),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            child: Text(
              i18n.t('skip'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isFormValid() ? () => _saveInfo(false) : null,
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
