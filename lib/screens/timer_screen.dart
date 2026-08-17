import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/timer_texts.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../models/keyboard_config.dart';
import '../providers/app_actions_provider.dart';
import '../providers/timer_hint_navigation_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/ui_providers.dart';
import '../widgets/debug_panel.dart';
import '../widgets/key_hint_rail.dart';
import '../widgets/status_chip.dart';
import '../widgets/timer_display.dart';

/// The shot clock.
///
/// Layout is one column: a thin status rail on top, the countdown in the
/// middle, the keyboard legend at the bottom. The signal itself is carried by
/// the tinted background — there is no drawn traffic light. From the shooting
/// line the whole panel changing colour reads faster than three lamps on it,
/// and it leaves the entire width to the clock.
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
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.md,
                      ),
                      child: TimerDisplay(),
                    ),
                  ),
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

/// Mode indicator.
///
/// The paused state is deliberately not shown here: the phase word above the
/// countdown already says it, in type you can read from the shooting line.
class _StatusRail extends ConsumerWidget {
  const _StatusRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeText = ref.watch(timerModeTextProvider);
    final arrowText = ref.watch(alternatingArrowTextProvider);
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

          // Der Pfeilzähler steht bewusst hier und nicht bei der Uhr: welcher
          // Pfeil gerade dran ist, entscheidet nichts an der Schießlinie — es
          // beantwortet nur die Frage, wie lange die Passe noch dauert.
          if (arrowText != null) StatusChip(label: arrowText),
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

/// Keyboard legend. Labels come from the live key bindings, so a remapped key
/// is shown correctly.
class _TimerHintRail extends ConsumerWidget {
  const _TimerHintRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(timerTextsProvider);
    final actions = ref.read(appActionsProvider);

    String keyFor(AppAction action) => ref.watch(actionKeyLabelProvider(action));

    // Ohne Uhr fallen Weiter und Start/Pause zur selben Handlung zusammen, und
    // zwei Tasten mit demselben Wort nebeneinander wären nur Rauschen.
    final isManual = ref.watch(isManualModeProvider);

    // Built from timerHintActionsProvider rather than a fixed list, so this
    // stays the same order left/right steps through in TimerScreenActions —
    // duplicating the order here would let the two drift apart.
    final hintActions = ref.watch(timerHintActionsProvider);

    KeyHint hintFor(int index) {
      final action = hintActions[index];
      final label = switch (action) {
        AppAction.next =>
          isManual ? texts.hintToggleSignal : texts.hintStartNext,
        // Label follows the state (Start / Pause / Fortsetzen) — the binding
        // is a toggle, so a fixed word would be wrong half the time.
        AppAction.toggleTimer => ref.watch(startButtonTextProvider),
        AppAction.resetTimer => texts.hintReset,
        AppAction.nextMode => texts.hintMode,
        AppAction.toggleSettings => texts.hintSettings,
        AppAction.toggleMenu => texts.hintMenu,
        _ => '',
      };

      return KeyHint(
        keys: [keyFor(action)],
        label: label,
        emphasised: action == AppAction.next,
        isSelected: ref.watch(isTimerHintSelectedProvider(index)),
        onTap: () => actions.handleAction(action),
      );
    }

    // The rail keeps the neutral cyan accent even though the screen is tinted
    // by the phase: the signal colours mean "shoot / do not shoot", and a red
    // key cap would be borrowing that meaning for a piece of chrome.
    return KeyHintRail(
      hints: [for (var i = 0; i < hintActions.length; i++) hintFor(i)],
    );
  }
}
