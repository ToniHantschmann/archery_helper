import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_typography.dart';
import '../providers/ui_providers.dart';

/// The countdown block: phase word, clock, and the rail showing how much of
/// the current phase is left.
///
/// The clock is wrapped in a `FittedBox`, so it always takes the largest size
/// the available space allows — a fixed point size would either waste half the
/// panel on a 2560px monitor or overflow in a windowed 1280px session.
class TimerDisplay extends ConsumerWidget {
  const TimerDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(timerUIStateProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Phase word ──
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.medium,
            curve: AppMotion.curve,
            style: AppType.headline.copyWith(
              color: uiState.phaseColor,
              fontWeight: uiState.isWarning ? FontWeight.w800 : FontWeight.w600,
            ),
            child: Text(
              uiState.phaseText.toUpperCase(),
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Clock ──
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.medium,
                curve: AppMotion.curve,
                style: AppType.clock.copyWith(color: uiState.timeColor),
                child: Text(uiState.formattedTime, maxLines: 1),
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        const PhaseProgressRail(),
      ],
    );
  }
}

/// Horizontal bar showing the remaining share of the running phase.
///
/// Its own [ConsumerWidget] watching a single provider, so a progress step
/// repaints a 14px bar and not the countdown above it. The underlying value is
/// quantised to whole seconds — at five meters nobody resolves more than that,
/// and a bar creeping in 100ms steps would be exactly the kind of motion this
/// screen must not have while somebody is aiming.
class PhaseProgressRail extends ConsumerWidget {
  const PhaseProgressRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(phaseProgressProvider).clamp(0.0, 1.0);
    final accent = ref.watch(timerAccentColorProvider);

    return SizedBox(
      height: 14,
      child: ClipRRect(
        borderRadius: AppRadius.pill,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: AppPalette.surfaceRaised),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progress),
                duration: AppMotion.fast,
                curve: Curves.linear,
                builder: (context, value, _) {
                  return FractionallySizedBox(
                    widthFactor: value.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.55),
                            accent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
