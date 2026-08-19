import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/traffic_light_texts.dart';
import '../core/theme/app_dimens.dart';
import '../models/keyboard_config.dart';
import '../providers/app_actions_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/traffic_light_provider.dart';
import '../providers/ui_providers.dart';
import '../widgets/key_hint_rail.dart';
import '../widgets/timer_display.dart';

/// Die Ampel von Hand — Rot und Grün, ohne Uhr.
///
/// Dasselbe Bild wie beim Timer, nur ohne dessen zwei Randstreifen: es gibt
/// keinen Modus anzuzeigen und keine Pfeile zu zählen. Übrig bleibt der
/// getönte Schirm und das Signalwort darauf, das hier die Stelle der Uhr
/// einnimmt und damit die ganze Anzeige ist.
///
/// Tasten kommen wie überall aus KeyboardScope (siehe app.dart), die Taps in
/// der Hinweisleiste lösen genau die [AppAction] aus, die ihre Taste auslöst.
class TrafficLightScreen extends ConsumerWidget {
  const TrafficLightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = ref.watch(trafficLightGradientProvider);

    return Scaffold(
      body: AnimatedContainer(
        duration: AppMotion.slow,
        curve: AppMotion.curve,
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  child: TimerDisplay(
                    uiStateProvider: trafficLightUIStateProvider,
                    scale: ref.watch(timerScaleProvider),
                  ),
                ),
              ),
              const _TrafficLightHintRail(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keyboard legend. Labels come from the live key bindings, so a remapped key
/// is shown correctly.
class _TrafficLightHintRail extends ConsumerWidget {
  const _TrafficLightHintRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(trafficLightTextsProvider);
    final actions = ref.read(appActionsProvider);

    KeyHint hintFor(AppAction action, String label, {bool emphasised = false}) {
      return KeyHint(
        keys: [ref.watch(actionKeyLabelProvider(action))],
        label: label,
        emphasised: emphasised,
        onTap: () => actions.handleAction(action),
      );
    }

    // Ohne Uhr gibt es nur eine Handlung: umschalten. Start/Pause und
    // Zurücksetzen wären dasselbe Wort ein zweites Mal und stehen deshalb
    // nicht in der Leiste.
    return KeyHintRail(
      hints: [
        hintFor(AppAction.next, texts.hintToggle, emphasised: true),
        hintFor(AppAction.toggleMenu, texts.hintMenu),
      ],
    );
  }
}
