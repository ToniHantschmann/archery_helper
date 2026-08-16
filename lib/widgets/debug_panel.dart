import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../providers/timer_provider.dart';

/// Development-only readout of the raw timer state (see `kDebugMode` in
/// TimerScreen). Deliberately small and low contrast: it must not be part of
/// the composition, it just has to be readable when you stand at the desk.
class DebugPanel extends ConsumerWidget {
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppPalette.abyss.withValues(alpha: 0.72),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppPalette.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'DEBUG',
            style: TextStyle(
              color: AppPalette.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _row('Phase', timerState.phase.name),
          _row('Mode', timerState.mode.name),
          _row('Running', '${timerState.isRunning}'),
          _row('Paused', '${timerState.isPaused}'),
          _row('Warning', '${timerState.isInWarningPeriod}'),
          _row('Remaining', '${timerState.remainingTime.inSeconds}s'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
