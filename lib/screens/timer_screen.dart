import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/timer_texts.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../models/keyboard_config.dart';
import '../providers/app_actions_provider.dart';
import '../providers/ui_providers.dart';
import '../widgets/debug_panel.dart';
import '../widgets/key_hint_rail.dart';
import '../widgets/status_chip.dart';
import '../widgets/timer_display.dart';
import '../widgets/traffic_light.dart';

/// The shot clock.
///
/// Layout is one column: a thin status rail on top, the hero (traffic light +
/// countdown) in the middle, the keyboard legend at the bottom. The hero
/// switches between a side-by-side and a stacked arrangement depending on the
/// aspect ratio, so the two wide tunnel monitors get a vertical traffic light
/// next to a huge clock, while a windowed session still shows both.
///
/// Keyboard handling is app-wide in KeyboardScope (see app.dart); nothing here
/// listens for keys. The taps that exist are a secondary path only — every one
/// of them dispatches exactly the [AppAction] its key would.
class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = ref.watch(timerBackgroundGradientProvider);

    return Scaffold(
      body: AnimatedContainer(
        duration: AppMotion.slow,
        curve: AppMotion.curve,
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  const _StatusRail(),
                  const Expanded(child: _TimerHero()),
                  const _TimerHintRail(),
                ],
              ),
            ),

            // Debug Panel (oben rechts) - nur für Development
            if (kDebugMode)
              const Positioned(
                top: AppSpacing.lg,
                right: AppSpacing.lg,
                child: DebugPanel(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mode indicator and paused badge.
class _StatusRail extends ConsumerWidget {
  const _StatusRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeText = ref.watch(timerModeTextProvider);
    final isPaused = ref.watch(isTimerPausedProvider);
    final texts = ref.watch(timerTextsProvider);
    final actions = ref.read(appActionsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          // The chevrons keep previousMode reachable with the mouse; it has no
          // default key binding.
          _ModeArrow(
            icon: Icons.chevron_left,
            onTap: () => actions.handleAction(AppAction.previousMode),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusChip(label: modeText),
          const SizedBox(width: AppSpacing.sm),
          _ModeArrow(
            icon: Icons.chevron_right,
            onTap: () => actions.handleAction(AppAction.nextMode),
          ),

          const Spacer(),

          if (isPaused)
            StatusChip(
              label: texts.paused,
              color: AppPalette.caution,
              icon: Icons.pause_rounded,
              filled: true,
            ),
        ],
      ),
    );
  }
}

class _ModeArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ModeArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppPalette.surface.withValues(alpha: 0.5),
          borderRadius: AppRadius.sm,
          border: Border.all(color: AppPalette.outline, width: 1.5),
        ),
        child: Icon(icon, size: 28, color: AppPalette.textMuted),
      ),
    );
  }
}

/// Traffic light plus countdown.
class _TimerHero extends ConsumerWidget {
  const _TimerHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lamp = ref.watch(trafficLampProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > constraints.maxHeight * 1.25;

          if (isWide) {
            final lightWidth = (constraints.maxWidth * 0.20).clamp(120.0, 340.0);

            return Row(
              children: [
                SizedBox(
                  width: lightWidth,
                  child: TrafficLight(lit: lamp),
                ),
                const SizedBox(width: AppSpacing.xxl),
                const Expanded(child: TimerDisplay()),
              ],
            );
          }

          final lightHeight = (constraints.maxHeight * 0.26).clamp(80.0, 240.0);

          return Column(
            children: [
              SizedBox(
                height: lightHeight,
                child: TrafficLight(lit: lamp, axis: Axis.horizontal),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Expanded(child: TimerDisplay()),
            ],
          );
        },
      ),
    );
  }
}

/// Keyboard legend. Labels come from the live key bindings, so a remapped key
/// is shown correctly.
class _TimerHintRail extends ConsumerWidget {
  const _TimerHintRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(timerTextsProvider);
    final actions = ref.read(appActionsProvider);

    String keyFor(AppAction action) => ref.watch(actionKeyLabelProvider(action));

    KeyHint hint(AppAction action, String label, {bool emphasised = false}) {
      return KeyHint(
        keys: [keyFor(action)],
        label: label,
        emphasised: emphasised,
        onTap: () => actions.handleAction(action),
      );
    }

    // The rail keeps the neutral cyan accent even though the screen is tinted
    // by the phase: the signal colours mean "shoot / do not shoot", and a red
    // key cap would be borrowing that meaning for a piece of chrome.
    return KeyHintRail(
      hints: [
        hint(AppAction.next, texts.hintStartNext, emphasised: true),
        // Label follows the state (Start / Pause / Fortsetzen) — the binding
        // is a toggle, so a fixed word would be wrong half the time.
        hint(AppAction.toggleTimer, ref.watch(startButtonTextProvider)),
        hint(AppAction.resetTimer, texts.hintReset),
        hint(AppAction.nextMode, texts.hintMode),
        hint(AppAction.toggleSettings, texts.hintSettings),
        hint(AppAction.toggleMenu, texts.hintMenu),
      ],
    );
  }
}
