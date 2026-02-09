import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/features/recording/providers/vehicle_provider.dart';
import 'package:puked/services/logo_cache_service.dart';
import 'dart:io';

class BrandLogo extends ConsumerWidget {
  final String? brandName;
  final String? overrideLogoUrl; // 新增：支持传入外部指定的 Logo URL (如从 expand 中解析出的)
  final double size;
  final double padding;
  final Color? color;
  final bool showBackground; // 是否显示背景底色

  // 内置已知有本地 SVG 的品牌列表，避免盲目尝试加载不存在的资源
  static const Set<String> _localBrands = {
    'ApolloGo',
    'Deeproute',
    'Horizon',
    'Huawei',
    'Leapmotor',
    'LiAuto',
    'Momenta',
    'Nio',
    'Nvidia',
    'Onvo',
    'PONYai',
    'Tesla',
    'Waymo',
    'Wayve',
    'WeRide',
    'Xiaomi',
    'Xpeng',
    'Zeekr',
    'Zoox',
    'lynk&co',
    'others',
    'zyt',
  };

  const BrandLogo({
    super.key,
    required this.brandName,
    this.overrideLogoUrl,
    this.size = 40,
    this.padding = 6,
    this.color,
    this.showBackground = false, // 默认不显示，避免重复嵌套
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 逻辑：
    // 1. 如果 size 是 infinity，则不设固定宽高，由父容器（如 Expanded）约束。
    // 2. 如果 size 是固定数值，则强制使用 SizedBox 锁定宽高。
    // 3. 内部 SvgPicture 不设固定尺寸，使用 BoxFit.contain 以适配 Padding 后的剩余空间。

    final bool isInfinity = size == double.infinity;

    if ((brandName == null || brandName!.isEmpty) &&
        (overrideLogoUrl == null || overrideLogoUrl!.isEmpty)) {
      return _wrapWithBackground(
        context,
        _buildEmptyBrand(context, isInfinity ? null : size),
        isInfinity,
      );
    }

    final brandsAsync = ref.watch(allBrandsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 如果没有传入 color，黑夜模式下默认使用白色，白天模式下保持原样（null）
    final effectiveColor = color ?? (isDark ? Colors.white : null);

    // 优化：在等待数据库加载期间，如果 brandName 是已知本地品牌，优先尝试直接显示本地资产
    // 这样可以避免在元数据同步期间出现大量问号图标
    if (brandName != null &&
        brandName!.isNotEmpty &&
        _localBrands.contains(brandName)) {
      final assetPath = 'assets/logos/$brandName.svg';
      final localIcon = Padding(
        padding: EdgeInsets.all(padding),
        child: SvgPicture.asset(
          assetPath,
          fit: BoxFit.contain,
          colorFilter: effectiveColor != null
              ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
              : null,
          placeholderBuilder: (context) =>
              _buildFallback(context, isInfinity ? null : size),
        ),
      );
      return _wrapWithBackground(context, localIcon, isInfinity);
    }

    return brandsAsync.maybeWhen(
      data: (brands) {
        final brand = brands.firstWhere(
          (b) =>
              b.cloudId == brandName ||
              b.name.toLowerCase() == brandName?.toLowerCase(),
          orElse: () => Brand()..name = brandName ?? '',
        );

        // 构建图标 Widget (优先尝试 overrideUrl -> 本地 -> 远程)
        Widget buildIcon() {
          // 1. 优先使用传入的覆盖 URL (最高优先级，解决云端同步一致性)
          if (overrideLogoUrl != null && overrideLogoUrl!.isNotEmpty) {
            // 尝试从缓存加载，如果缓存未命中再从网络加载
            return FutureBuilder<String?>(
              future: ref
                  .read(logoCacheServiceProvider)
                  .getCachedLogoPath(brand.name),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  // 从缓存加载（File 或 Asset）
                  final cachedPath = snapshot.data!;
                  if (cachedPath.startsWith('assets/')) {
                    return SvgPicture.asset(
                      cachedPath,
                      fit: BoxFit.contain,
                      colorFilter: effectiveColor != null
                          ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
                          : null,
                    );
                  } else {
                    return SvgPicture.file(
                      File(cachedPath),
                      fit: BoxFit.contain,
                      colorFilter: effectiveColor != null
                          ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
                          : null,
                    );
                  }
                }
                // 缓存未命中，从网络加载
                return SvgPicture.network(
                  overrideLogoUrl!,
                  fit: BoxFit.contain,
                  colorFilter: effectiveColor != null
                      ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
                      : null,
                  placeholderBuilder: (context) =>
                      _buildFallback(context, isInfinity ? null : size),
                );
              },
            );
          }

          // 注意：如果 brandName 是 ID，我们需要使用查找到的 brand.name 来定位本地资源
          final String canonicalName = brand.name;
          final isLocal = _localBrands.contains(canonicalName);
          final assetPath = 'assets/logos/$canonicalName.svg';

          // 2. 如果是已知本地品牌且处于黑夜模式，或者没有远程 URL
          // 优先使用本地资产，因为本地资产的 colorFilter 适配通常更稳定
          if (isLocal &&
              (isDark || brand.logoUrl == null || brand.logoUrl!.isEmpty)) {
            return SvgPicture.asset(
              assetPath,
              fit: BoxFit.contain,
              colorFilter: effectiveColor != null
                  ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
                  : null,
              placeholderBuilder: (context) =>
                  _buildFallback(context, isInfinity ? null : size),
            );
          }

          // 3. 如果有远程 URL，尝试加载网络图片
          if (brand.logoUrl != null && brand.logoUrl!.isNotEmpty) {
            return SvgPicture.network(
              brand.logoUrl!,
              fit: BoxFit.contain,
              colorFilter: effectiveColor != null
                  ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
                  : null,
              placeholderBuilder: (context) => isLocal
                  ? SvgPicture.asset(
                      assetPath,
                      fit: BoxFit.contain,
                      colorFilter: effectiveColor != null
                          ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
                          : null,
                    )
                  : _buildFallback(context, isInfinity ? null : size),
            );
          }

          // 4. 最后的保底：如果是本地品牌尝试加载，否则直接显示问号
          if (isLocal) {
            return SvgPicture.asset(
              assetPath,
              fit: BoxFit.contain,
              colorFilter: effectiveColor != null
                  ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
                  : null,
              placeholderBuilder: (context) =>
                  _buildFallback(context, isInfinity ? null : size),
            );
          }

          return _buildFallback(context, isInfinity ? null : size);
        }

        final iconWidget = Padding(
          padding: EdgeInsets.all(padding),
          child: buildIcon(),
        );

        return _wrapWithBackground(context, iconWidget, isInfinity);
      },
      orElse: () {
        // 在加载过程中，如果提供了 overrideLogoUrl，也可以先尝试显示它
        if (overrideLogoUrl != null && overrideLogoUrl!.isNotEmpty) {
          return _wrapWithBackground(
            context,
            Padding(
              padding: EdgeInsets.all(padding),
              child: SvgPicture.network(
                overrideLogoUrl!,
                fit: BoxFit.contain,
                colorFilter: effectiveColor != null
                    ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
                    : null,
                placeholderBuilder: (context) =>
                    _buildFallback(context, isInfinity ? null : size),
              ),
            ),
            isInfinity,
          );
        }

        final fallback = Padding(
          padding: EdgeInsets.all(padding),
          child: _buildFallback(context, isInfinity ? null : size),
        );
        return _wrapWithBackground(context, fallback, isInfinity);
      },
    );
  }

  Widget _wrapWithBackground(
      BuildContext context, Widget child, bool isInfinity) {
    if (showBackground) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        width: isInfinity ? null : size,
        height: isInfinity ? null : size,
        constraints: isInfinity ? const BoxConstraints.expand() : null,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(isInfinity ? 12 : size * 0.2),
        ),
        child: child,
      );
    }

    return isInfinity
        ? SizedBox.expand(child: child)
        : SizedBox(width: size, height: size, child: child);
  }

  Widget _buildFallback(BuildContext context, double? constrainedSize) {
    return _buildEmptyBrand(context, constrainedSize);
  }

  Widget _buildEmptyBrand(BuildContext context, double? constrainedSize) {
    final iconSize = constrainedSize != null ? constrainedSize * 0.5 : 24.0;
    return Container(
      alignment: const Alignment(0, -0.1), // 关键修复：微调偏移量，解决 '?' 视觉偏下的问题
      child: Text(
        '?',
        style: TextStyle(
          fontSize: iconSize * 1.2,
          fontWeight: FontWeight.w300,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.5),
          height: 1.0, // 强制行高为 1.0，减少字体内部边距干扰
        ),
      ),
    );
  }
}
