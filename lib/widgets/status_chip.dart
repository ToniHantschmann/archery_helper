import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_typography.dart';

/// Small all-caps pill used for the mode indicator, the paused badge and the
/// screen breadcrumbs.
///
/// Chips carry secondary information only. They are tinted, never filled with
/// a signal colour at full strength, so nothing on a screen can be confused
/// with a lamp.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  /// Filled chips are used for states that need to be noticed (paused),
  /// outlined ones for permanent labels (the current mode).
  final bool filled;

  const StatusChip({
    super.key,
    required this.label,
    this.color = AppPalette.accent,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color:
            filled
                ? Color.alphaBlend(
                  color.withValues(alpha: 0.22),
                  AppPalette.surface,
                )
                : AppPalette.surface.withValues(alpha: 0.65),
        borderRadius: AppRadius.pill,
        border: Border.all(
          color: filled ? color : AppPalette.outline,
          width: filled ? 2 : 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label.toUpperCase(),
            style: AppType.label.copyWith(
              color: filled ? AppPalette.textPrimary : AppPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
