import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/competition_texts.dart';
import '../core/l10n/settings_texts.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_typography.dart';
import '../models/competition_state.dart';
import '../models/keyboard_config.dart';
import '../providers/app_actions_provider.dart';
import '../providers/competition_ui_providers.dart';
import '../providers/hint_navigation_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ui_providers.dart';
import '../widgets/key_hint_rail.dart';
import '../widgets/led_corner.dart';
import 'competition_led_screen.dart';
import '../widgets/status_chip.dart';
import '../widgets/timer_display.dart';

/// Die Ampel einer Qualifikationsrunde.
///
/// Derselbe Schirm wie [TimerScreen] — getönter Hintergrund als Signal, Uhr in
/// der Mitte, Tastenlegende unten — plus die zwei Dinge, die eine Runde von
/// einem einzelnen Countdown unterscheiden: in welcher Passe wir sind, und
/// welche Gruppe gerade an der Schießlinie steht.
///
/// Steht die Anzeige auf LED-Wand, übernimmt [CompetitionLedScreen] — dieselbe
/// Runde, nur auf 192 × 128 Pixel eingedampft. Die Verzweigung sitzt hier und
/// nicht im `AppNavigator`, damit [AppScreen.competition] *ein* Screen bleibt:
/// Tastenbelegung, Herkunft der Einstellungen und die Layout-Tests hängen alle
/// daran, und eine zweite Zeile im Navigator würde sie auseinanderziehen.
///
/// Keyboard handling is app-wide in KeyboardScope (see app.dart); nothing here
/// listens for keys. Jeder Tap löst genau die [AppAction] aus, die seine Taste
/// auslösen würde.
class CompetitionScreen extends ConsumerWidget {
  const CompetitionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(competitionDisplayProvider);
    if (display == CompetitionDisplay.led ||
        display == CompetitionDisplay.ledPreview) {
      return CompetitionLedScreen(
        isPreview: display == CompetitionDisplay.ledPreview,
      );
    }

    final gradient = ref.watch(competitionBackgroundGradientProvider);

    final view = Scaffold(
      body: AnimatedContainer(
        duration: AppMotion.slow,
        curve: AppMotion.curve,
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            children: [
              const _CompetitionStatusRail(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: TimerDisplay(
                    uiStateProvider: competitionUIStateProvider,
                  ),
                ),
              ),
              const _GroupRail(),
              const _CompetitionHintRail(),
            ],
          ),
        ),
      ),
    );

    if (display != CompetitionDisplay.ledWithControl) return view;

    // Die Ecke zuletzt, damit sie über allem liegt: nur so ist der Ausschnitt
    // unabhängig davon, was das Layout darunter gerade tut.
    return Stack(
      alignment: Alignment.topLeft,
      children: [view, const LedCorner()],
    );
  }
}

/// Passenzähler und Aufstellung.
///
/// Beides steht oben und nicht bei der Uhr: es entscheidet nichts an der
/// Schießlinie, sondern beantwortet nur, wo in der Runde wir sind.
class _CompetitionStatusRail extends ConsumerWidget {
  const _CompetitionStatusRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endText = ref.watch(competitionEndTextProvider);
    final settingsTexts = ref.watch(settingsTextsProvider);
    final discipline = ref.watch(competitionDisciplineProvider);

    // Der Passenzähler steht dort, wo im Wandmodus die Ecke liegt — also weicht
    // er ihr aus, statt unter ihr zu verschwinden.
    final reserved =
        ref.watch(competitionDisplayProvider) ==
            CompetitionDisplay.ledWithControl
        ? ledCornerSize(context).width + AppSpacing.md
        : 0.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl + reserved,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          StatusChip(label: endText),
          const Spacer(),
          StatusChip(label: settingsTexts.getDisciplineName(discipline)),
        ],
      ),
    );
  }
}

/// Wer dran ist.
///
/// Die Gruppen dieser Passe in Schussreihenfolge, die aktive in der
/// Signalfarbe. Damit läuft „wer ist dran" auf dieselbe Farbe hinaus wie „darf
/// geschossen werden" — auf die Entfernung ist das eine Aussage, nicht zwei.
///
/// Nur die Farbe wird animiert, nie die Größe: eine Schrift, die beim Wechsel
/// wächst, würde die ganze Zeile neu umbrechen (siehe `AppTheme.selectablePanel`
/// und die Begründung dort).
class _GroupRail extends ConsumerWidget {
  const _GroupRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(competitionHasGroupsProvider)) {
      return const SizedBox.shrink();
    }

    final rail = ref.watch(competitionGroupRailProvider);
    final signalColor = ref.watch(competitionSignalColorProvider);

    final labels = rail.lineup.orderedLabels(reversed: rail.reversed);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text('·', style: AppType.headline),
              ),
            AnimatedDefaultTextStyle(
              duration: AppMotion.medium,
              curve: AppMotion.curve,
              style: AppType.headline.copyWith(
                color: i == rail.groupIndex
                    ? signalColor
                    : AppPalette.textMuted,
              ),
              child: Text(labels[i], maxLines: 1),
            ),
          ],
        ],
      ),
    );
  }
}

/// Keyboard legend. Labels come from the live key bindings, so a remapped key
/// is shown correctly.
class _CompetitionHintRail extends ConsumerWidget {
  const _CompetitionHintRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(competitionTextsProvider);
    final actions = ref.read(appActionsProvider);

    // Built from competitionHintActionsProvider rather than a fixed list, so
    // this stays the order left/right steps through in CompetitionScreenActions.
    final hintActions = ref.watch(competitionHintActionsProvider);

    KeyHint hintFor(int index) {
      final action = hintActions[index];
      final label = switch (action) {
        AppAction.next => ref.watch(competitionNextLabelProvider),
        // Label follows the state (Start / Pause / Fortsetzen) — the binding is
        // a toggle, so a fixed word would be wrong half the time.
        AppAction.previous => texts.hintPrevious,
        AppAction.forward => texts.hintForward,
        AppAction.toggleTimer => ref.watch(competitionToggleLabelProvider),
        AppAction.resetTimer => texts.hintReset,
        AppAction.toggleSettings => texts.hintSettings,
        AppAction.back => texts.hintMenu,
        _ => '',
      };

      return KeyHint(
        keys: [ref.watch(actionKeyLabelProvider(action))],
        label: label,
        emphasised: action == AppAction.next,
        isSelected: ref.watch(isCompetitionHintSelectedProvider(index)),
        onTap: () => actions.handleAction(action),
      );
    }

    return KeyHintRail(
      hints: [for (var i = 0; i < hintActions.length; i++) hintFor(i)],
    );
  }
}
