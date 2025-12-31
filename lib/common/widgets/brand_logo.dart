import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/features/recording/providers/vehicle_provider.dart';

class BrandLogo extends ConsumerWidget {
  final String? brandName;
  final double size;
  final double padding;
  final Color? color;
  final bool showBackground; // 是否显示背景底色

  const BrandLogo({
    super.key,
    required this.brandName,
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

    if (brandName == null || brandName!.isEmpty) {
      return _wrapWithBackground(
        context,
        _buildEmptyBrand(context, isInfinity ? null : size),
        isInfinity,
      );
    }

    final brandsAsync = ref.watch(availableBrandsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 如果没有传入 color，黑夜模式下默认使用白色，白天模式下保持原样（null）
    final effectiveColor = color ?? (isDark ? Colors.white : null);

    return brandsAsync.maybeWhen(
      data: (brands) {
        final brand = brands.firstWhere(
          (b) => b.name.toLowerCase() == brandName!.toLowerCase(),
          orElse: () => Brand()..name = brandName!,
        );

        // 构建图标 Widget (不设固定宽高，由父约束决定)
        Widget buildIcon() {
          if (brand.logoUrl != null && brand.logoUrl!.isNotEmpty) {
            return SvgPicture.network(
              brand.logoUrl!,
              fit: BoxFit.contain,
              colorFilter: effectiveColor != null
                  ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
                  : null,
              placeholderBuilder: (context) => SvgPicture.asset(
                'assets/logos/${brand.name}.svg',
                fit: BoxFit.contain,
                colorFilter: effectiveColor != null
                    ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
                    : null,
                placeholderBuilder: (context) =>
                    _buildFallback(context, isInfinity ? null : size),
              ),
            );
          } else {
            return SvgPicture.asset(
              'assets/logos/${brand.name}.svg',
              fit: BoxFit.contain,
              colorFilter: effectiveColor != null
                  ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
                  : null,
              placeholderBuilder: (context) =>
                  _buildFallback(context, isInfinity ? null : size),
            );
          }
        }

        final iconWidget = Padding(
          padding: EdgeInsets.all(padding),
          child: buildIcon(),
        );

        return _wrapWithBackground(context, iconWidget, isInfinity);
      },
      orElse: () {
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
    if (isInfinity) return child;

    if (showBackground) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(size * 0.2), // 动态圆角，保持比例
        ),
        child: child,
      );
    }

    return SizedBox(width: size, height: size, child: child);
  }

  Widget _buildFallback(BuildContext context, double? constrainedSize) {
    return _buildEmptyBrand(context, constrainedSize);
  }

  Widget _buildEmptyBrand(BuildContext context, double? constrainedSize) {
    final iconSize = constrainedSize != null ? constrainedSize * 0.5 : 24.0;
    return Center(
      child: Text(
        '?',
        style: TextStyle(
          fontSize: iconSize * 1.2,
          fontWeight: FontWeight.w300,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
