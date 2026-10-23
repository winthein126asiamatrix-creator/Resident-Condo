import 'package:test/core/utils/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_theme_tokens.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/entities/complaint.dart';

Color complaintStatusColor(ComplaintStatus status, AppThemeTokens tokens) {
  switch (status) {
    case ComplaintStatus.submitted:
      return AppPalette.info;
    case ComplaintStatus.inReview:
      return AppPalette.warning;
    case ComplaintStatus.actionTaken:
      return tokens.brand;
    case ComplaintStatus.resolved:
      return AppPalette.success;
    case ComplaintStatus.withdrawn:
      return tokens.faint;
  }
}

class ComplaintStatusPill extends StatelessWidget {
  const ComplaintStatusPill({
    required this.status,
    this.dense = true,
    super.key,
  });

  final ComplaintStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(
      label: status.label,
      color: complaintStatusColor(status, AppThemeTokens.of(context)),
      dense: dense,
    );
  }
}

class ComplaintCategoryGrid extends StatelessWidget {
  const ComplaintCategoryGrid({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final ComplaintCategory selected;
  final ValueChanged<ComplaintCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 520
            ? 3
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: ComplaintCategory.values.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 108,
          ),
          itemBuilder: (context, index) {
            final category = ComplaintCategory.values[index];
            return _ComplaintCategoryCard(
              category: category,
              selected: category == selected,
              onTap: () => onSelected(category),
            );
          },
        );
      },
    );
  }
}

class _ComplaintCategoryCard extends StatelessWidget {
  const _ComplaintCategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ComplaintCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final radius = BorderRadius.circular(AppRadius.lg);
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? tokens.brandTint : tokens.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? tokens.brandBorder : tokens.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? tokens.cardShadow : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              vibrateNow();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? tokens.brand.withValues(alpha: 0.12)
                              : tokens.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          _categoryIcon(category),
                          size: 20,
                          color: selected ? tokens.brand : tokens.mutedStrong,
                        ),
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? tokens.brand : Colors.transparent,
                          border: Border.all(
                            color: selected ? tokens.brand : tokens.border,
                            width: 1.4,
                          ),
                        ),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          opacity: selected ? 1 : 0,
                          child: Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: tokens.onBrand,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        category.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? tokens.brand : tokens.mutedStrong,
                          fontSize: 13.sp,
                          height: 1.2,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                      ),
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

IconData _categoryIcon(ComplaintCategory category) {
  switch (category) {
    case ComplaintCategory.noise:
      return Icons.volume_up_rounded;
    case ComplaintCategory.cleanliness:
      return Icons.cleaning_services_rounded;
    case ComplaintCategory.parking:
      return Icons.local_parking_rounded;
    case ComplaintCategory.security:
      return Icons.security_rounded;
    case ComplaintCategory.commonArea:
      return Icons.apartment_rounded;
    case ComplaintCategory.pets:
      return Icons.pets_rounded;
    case ComplaintCategory.utilities:
      return Icons.bolt_rounded;
    case ComplaintCategory.other:
      return Icons.more_horiz_rounded;
  }
}
