import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/common/widgets/version_selection_dialog.dart';
import 'package:puked/features/history/presentation/trip_detail_screen.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/common/widgets/brand_selection.dart';
import 'package:puked/features/recording/providers/vehicle_provider.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

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
  String? _selectedBrandRef;
  String? _selectedVersionRef;
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
    try {
      final storage = ref.read(storageServiceProvider);
      // 核心修复：确保 Isar 初始化完成后再查询
      await storage.init();

      debugPrint('🔍 [VehicleInfo] Loading initial data...');
      debugPrint('   isSettingsMode: ${widget.isSettingsMode}');
      debugPrint('   tripId: ${widget.tripId}');

      if (widget.isSettingsMode) {
        final settings = ref.read(settingsProvider);
        _modelController.text = settings.carModel ?? '';
        _versionController.text = settings.softwareVersion ?? '';
        _selectedBrand = settings.brand;
        _selectedBrandRef = settings.brandRef;
        _selectedVersionRef = settings.softwareVersionRef;
        debugPrint('   📝 From settings:');
      } else if (widget.tripId != null) {
        final trips = await storage.getAllTrips();
        final trip = trips.firstWhere(
          (t) => t.id == widget.tripId,
          orElse: () => throw Exception('Trip not found'),
        );
        final settings = ref.read(settingsProvider);

        _modelController.text = trip.carModel ?? settings.carModel ?? '';
        _versionController.text =
            trip.softwareVersion ?? settings.softwareVersion ?? '';
        _selectedBrand = trip.brand ?? settings.brand;
        _selectedBrandRef = trip.brand_ref ?? settings.brandRef;
        _selectedVersionRef =
            trip.software_version_ref ?? settings.softwareVersionRef;
        debugPrint('   📝 From trip (fallback to settings):');
        debugPrint('      trip.brand: ${trip.brand}');
        debugPrint('      trip.brand_ref: ${trip.brand_ref}');
        debugPrint('      settings.brand: ${settings.brand}');
        debugPrint('      settings.brandRef: ${settings.brandRef}');
      }

      debugPrint('   ✅ Final values:');
      debugPrint('      _selectedBrand: $_selectedBrand');
      debugPrint('      _selectedBrandRef: $_selectedBrandRef');
      debugPrint('      _selectedVersionRef: $_selectedVersionRef');
      debugPrint('      _versionController.text: ${_versionController.text}');
    } catch (e) {
      debugPrint('[VehicleInfo] Error loading initial data: $e');
      // 如果报错，尽量从 settings 恢复一些基础显示，而不是显示错误页
      final settings = ref.read(settingsProvider);
      _selectedBrand ??= settings.brand;
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  // 选择图片
  Future<void> _pickImages() async {
    final auth = ref.read(authProvider);
    final status = auth.user?.getStringValue('audit_status') ?? '';
    if (status == 'pending') return; // 认证中不允许操作

    final l10n = AppLocalizations.of(context)!;
    if (_selectedImages.length >= 3) {
      _showError(l10n.error_image_limit);
      return;
    }

    final List<XFile> images = await _picker.pickMultiImage(
      imageQuality: 80,
    );

    if (images.isEmpty) return;

    for (var image in images) {
      // 校验格式
      final ext = image.path.toLowerCase();
      if (!ext.endsWith('.jpg') &&
          !ext.endsWith('.jpeg') &&
          !ext.endsWith('.png')) {
        _showError(l10n.error_image_type);
        continue;
      }

      // 校验大小 (5MB)
      final size = await image.length();
      if (size > 5 * 1024 * 1024) {
        _showError(l10n.error_image_size);
        continue;
      }

      if (_selectedImages.length < 3) {
        // 【核心优化】在添加到列表前先压缩图片
        final compressedImage = await _compressImage(image);
        if (compressedImage != null) {
          setState(() {
            _selectedImages.add(compressedImage);
          });
        }
      }
    }
  }

  /// 图片压缩函数：长边2000px，短边自适应，保持原格式和文件名
  Future<XFile?> _compressImage(XFile originalImage) async {
    try {
      final originalFile = File(originalImage.path);
      final originalBytes = await originalFile.readAsBytes();

      // 解码图片以获取原始尺寸
      final decodedImage = await decodeImageFromList(originalBytes);
      final originalWidth = decodedImage.width;
      final originalHeight = decodedImage.height;

      // 判断是否需要压缩
      final longerSide =
          originalWidth > originalHeight ? originalWidth : originalHeight;
      if (longerSide <= 2000) {
        // 尺寸已满足要求，仅做质量压缩
        final ext = path.extension(originalImage.path).toLowerCase();
        final isJpg = ext == '.jpg' || ext == '.jpeg';

        final compressedBytes = await FlutterImageCompress.compressWithFile(
          originalImage.path,
          quality: isJpg ? 90 : 100, // JPG压缩90%，PNG保持100%
        );

        if (compressedBytes == null) return originalImage;

        // 创建临时文件
        final tempDir = Directory.systemTemp;
        final fileName = path.basename(originalImage.path);
        final compressedFile = File('${tempDir.path}/$fileName');
        await compressedFile.writeAsBytes(compressedBytes);

        return XFile(compressedFile.path);
      }

      // 计算目标尺寸（长边2000px，短边自适应）
      int targetWidth, targetHeight;
      if (originalWidth > originalHeight) {
        targetWidth = 2000;
        targetHeight = (originalHeight * 2000 / originalWidth).round();
      } else {
        targetHeight = 2000;
        targetWidth = (originalWidth * 2000 / originalHeight).round();
      }

      // 执行压缩
      final ext = path.extension(originalImage.path).toLowerCase();
      final isJpg = ext == '.jpg' || ext == '.jpeg';

      final compressedBytes = await FlutterImageCompress.compressWithFile(
        originalImage.path,
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: isJpg ? 90 : 100,
      );

      if (compressedBytes == null) return originalImage;

      // 创建临时文件，保持原文件名
      final tempDir = Directory.systemTemp;
      final fileName = path.basename(originalImage.path);
      final compressedFile = File('${tempDir.path}/$fileName');
      await compressedFile.writeAsBytes(compressedBytes);

      debugPrint(
          '[VehicleInfo] 图片压缩成功: ${originalWidth}x${originalHeight} -> ${targetWidth}x${targetHeight}');
      return XFile(compressedFile.path);
    } catch (e) {
      debugPrint('[VehicleInfo] 图片压缩失败: $e');
      return originalImage; // 失败则返回原图
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
    // 即使点击跳过，也记录为 'Others'，避免 Arena 出现 unknown 数据
    final brand = skip ? 'Others' : _selectedBrand;
    final brandRef = skip ? null : _selectedBrandRef;
    final version = skip ? 'Others' : _versionController.text.trim();
    final versionRef = skip ? null : _selectedVersionRef;
    final model = skip ? 'Others' : _modelController.text.trim();

    if (!skip && brand != null && version.isNotEmpty) {
      final storage = ref.read(storageServiceProvider);
      await storage.addVersion(brand, version, isCustom: true);
    }

    if (widget.isSettingsMode) {
      if (!skip) {
        await ref.read(settingsProvider.notifier).setVehicleInfo(
              brand: brand,
              brandRef: brandRef,
              model: model,
              version: version,
              versionRef: versionRef,
            );
      }
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (widget.tripId == null) return;

    final storage = ref.read(storageServiceProvider);

    await storage.updateTripVehicleInfo(
      widget.tripId!,
      brand: brand,
      brandRef: brandRef,
      carModel: model,
      softwareVersion: version,
      softwareVersionRef: versionRef,
    );

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
      final l10n = AppLocalizations.of(context)!;
      final auth = ref.read(authProvider);
      final pb = ref.read(pbServiceProvider).pb;

      // 1. 准备上传到 PocketBase 的资料
      final Map<String, dynamic> body = {
        // 🔄 数据库迁移：优先使用 _ref 字段
        'brand': '', // 清空旧字段
        'brand_ref': _selectedBrandRef ?? '',
        'car_model': _modelController.text.trim(),
        'software_version': '', // 清空旧字段
        'software_version_ref': _selectedVersionRef ?? '',
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
            brandRef: _selectedBrandRef,
            model: _modelController.text.trim(),
            version: _versionController.text.trim(),
            versionRef: _selectedVersionRef,
          );

      // 5. 刷新本地用户状态
      await ref.read(authProvider.notifier).refreshUserFromServer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.submit_success_tip),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      String errorMessage = l10n.upload_failed;
      if (e is ClientException) {
        final errorData = e.response['data'];
        if (errorData != null &&
            errorData is Map &&
            errorData.containsKey('certification_images')) {
          errorMessage = l10n.error_image_size;
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

  void _onBrandSelected(Brand brand) {
    debugPrint('🏷️ [VehicleInfo] Brand selected:');
    debugPrint('   brand.name: ${brand.name}');
    debugPrint('   brand.cloudId: ${brand.cloudId}');

    if (_selectedBrand == brand.name) {
      setState(() {
        _selectedBrand = null;
        _selectedBrandRef = null;
        _selectedVersionRef = null;
        _versionController.clear();
        _modelController.clear();
      });
      debugPrint('   ❌ Brand deselected');
      return;
    }

    setState(() {
      _selectedBrand = brand.name;
      _selectedBrandRef = brand.cloudId;
      _selectedVersionRef = null;
      _versionController.clear();
      _modelController.clear();
    });
    debugPrint('   ✅ _selectedBrand: $_selectedBrand');
    debugPrint('   ✅ _selectedBrandRef: $_selectedBrandRef');
  }

  @override
  void dispose() {
    _modelController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  Widget _buildVersionField(BuildContext context, AppLocalizations l10n,
      AsyncValue<List<SoftwareVersion>> presetVersionsAsync) {
    return presetVersionsAsync.when(
      data: (versions) {
        return TextField(
          controller: _versionController,
          readOnly: true,
          onTap: _selectedBrand == null
              ? null
              : () async {
                  final result = await showDialog<dynamic>(
                    context: context,
                    builder: (context) => VersionSelectionDialog(
                      currentVersion: _versionController.text,
                      presetVersions: versions,
                      brandName: _selectedBrand!,
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      if (result is SoftwareVersion) {
                        _versionController.text = result.versionString;
                        _selectedVersionRef = result.cloudId;
                      } else if (result is String) {
                        _versionController.text = result;
                        _selectedVersionRef = null;
                      }
                    });
                  }
                },
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.95)
                : Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            labelText: l10n.software_version,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.7)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            hintText: l10n.version_hint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.code),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, s) => TextField(
        controller: _versionController,
        decoration: InputDecoration(
          labelText: l10n.software_version,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.code),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brandsAsync = ref.watch(allBrandsProvider);

    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return brandsAsync.when(
      data: (brands) => _buildContent(context, l10n, brands),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildContent(
      BuildContext context, AppLocalizations l10n, List<Brand> brands) {
    // ✅ 修复：使用 brandRef (cloudId) 而不是 brandName 查询版本列表
    debugPrint('🔍 [VehicleInfo] _buildContent called:');
    debugPrint('   _selectedBrandRef: $_selectedBrandRef');

    final presetVersionsAsync = _selectedBrandRef != null
        ? ref.watch(presetVersionsByRefProvider(_selectedBrandRef!))
        : const AsyncValue<List<SoftwareVersion>>.data([]);

    // 打印版本列表加载状态
    presetVersionsAsync.when(
      data: (versions) {
        debugPrint('   ✅ Versions loaded: ${versions.length} versions');
        for (var v in versions) {
          debugPrint('      - ${v.versionString} (cloudId: ${v.cloudId})');
        }
      },
      loading: () => debugPrint('   ⏳ Loading versions...'),
      error: (err, stack) => debugPrint('   ❌ Error loading versions: $err'),
    );

    final auth = ref.watch(authProvider);
    final auditStatus = auth.user?.getStringValue('audit_status') ?? '';
    final isPending = auditStatus == 'pending';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isSettingsMode ? l10n.my_car : l10n.vehicle_info,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. 顶部 Banner (仅在设置模式显示)
            if (widget.isSettingsMode)
              _buildCertificationBanner(context, l10n, auditStatus),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    BrandSelectionGrid(
                      brands: brands,
                      selectedBrandKey: _selectedBrandRef ?? _selectedBrand,
                      onBrandSelected: _onBrandSelected,
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
                        labelText: l10n.car_model,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        hintText: l10n.model_hint,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.directions_car),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildVersionField(context, l10n, presetVersionsAsync),

                    // 2. 图片上传区域 (仅在设置模式显示)
                    if (widget.isSettingsMode) ...[
                      const SizedBox(height: 32),
                      Text(
                        isPending
                            ? l10n.upload_cert_photos_submitted
                            : l10n.upload_cert_photos_new,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (!isPending) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.upload_hint_new,
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
                          l10n.file_limit_hint,
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
              ? _buildCertificationButton(context, l10n, isPending)
              : _buildOriginalButtons(context, l10n),
        ),
      ),
    );
  }

  Widget _buildCertificationBanner(
      BuildContext context, AppLocalizations l10n, String status) {
    Color bannerColor;
    String bannerText;
    IconData icon;

    switch (status) {
      case 'pending':
        bannerColor = Colors.orange;
        bannerText = l10n.car_cert_banner_pending;
        icon = Icons.hourglass_empty;
        break;
      case 'rejected':
        bannerColor = Colors.red;
        bannerText = l10n.car_cert_banner_rejected;
        icon = Icons.error_outline;
        break;
      case 'approved':
        bannerColor = Colors.green;
        bannerText = l10n.car_cert_banner_approved;
        icon = Icons.verified;
        break;
      default:
        bannerColor = Theme.of(context).colorScheme.primary;
        bannerText = l10n.car_cert_banner;
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
      BuildContext context, AppLocalizations l10n, bool isPending) {
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
                l10n.submit_for_audit,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
      ),
    );
  }

  Widget _buildOriginalButtons(BuildContext context, AppLocalizations l10n) {
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
              l10n.skip,
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
              l10n.save,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
