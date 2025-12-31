import 'package:flutter/material.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/common/widgets/brand_logo.dart';

/// 统一的品牌选择列表项
class BrandSelectionItem extends StatelessWidget {
  final Brand brand;
  final bool isSelected;
  final VoidCallback onTap;

  const BrandSelectionItem({
    super.key,
    required this.brand,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
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
              child: BrandLogo(
                brandName: brand.name,
                size: double.infinity,
                padding: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              brand.displayName ?? brand.name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// 统一的品牌选择网格
class BrandSelectionGrid extends StatelessWidget {
  final List<Brand> brands;
  final String? selectedBrandName;
  final Function(Brand) onBrandSelected;
  final ScrollController? scrollController;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const BrandSelectionGrid({
    super.key,
    required this.brands,
    this.selectedBrandName,
    required this.onBrandSelected,
    this.scrollController,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return GridView.builder(
      controller: scrollController,
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isLandscape ? 8 : 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: brands.length,
      itemBuilder: (context, index) {
        final brand = brands[index];
        final isSelected = selectedBrandName == brand.name;
        return BrandSelectionItem(
          brand: brand,
          isSelected: isSelected,
          onTap: () => onBrandSelected(brand),
        );
      },
    );
  }
}
