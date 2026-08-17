import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_typography.dart';

/// Small all-caps outlined pill used for permanent secondary labels — the mode
/// indicator, the screen breadcrumbs.
///
/// Deliberately has no colour, icon or filled variant: a chip never carries
/// state you have to react to. Those used to exist for the paused badge, which
/// is gone — the phase word says it in type you can read from the shooting
/// line, and a chip in a signal colour would compete with the tinted
/// background that *is* the signal.
class StatusChip extends StatelessWidget {
  final String label;

  const StatusChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.65),
        borderRadius: AppRadius.pill,
        border: Border.all(color: AppPalette.outline, width: 1.5),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppType.label.copyWith(color: AppPalette.textSecondary),
      ),
    );
  }
}
