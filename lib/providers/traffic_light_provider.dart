import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_signal.dart';
import '../core/l10n/traffic_light_texts.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/timer_theme.dart';
import '../models/signal_state.dart';
import '../models/timer_state.dart';
import 'sound_provider.dart';
import 'ui_providers.dart';

/// Die Ampel von Hand: Rot und Grün, sonst nichts.
///
/// Der ganze Zustand ist „grün ja/nein" — deshalb ein `bool` und keine
/// Zustandsklasse. Was hier fehlt, ist Absicht: keine Dauern, keine Warnstufe
/// und vor allem keine Uhr. Der [PhaseClock] der beiden anderen Werkzeuge wäre
/// hier nicht nur unbenutzt, sondern falsch — mit Null-Dauern liefe er in einem
/// einzigen Aufruf bis ans Ende.
class TrafficLightNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Schaltet zwischen Rot und Grün um.
  void toggle() {
    state = !state;
    // Auch von Hand geschaltet geht ein Signal an die Linie: dass keine Uhr
    // läuft, ändert nichts an der Aussage.
    ref
        .read(signalSoundsProvider)
        .play(state ? AudioSignal.start : AudioSignal.stop);
  }
}

// ===== PROVIDER =====

final trafficLightProvider = NotifierProvider<TrafficLightNotifier, bool>(
  () => TrafficLightNotifier(),
);

/// Das Signal als das, was [TimerTheme] versteht.
///
/// Rot ist bewusst `preparation` und nicht `idle`: `idle` heißt „noch nichts
/// los" und wird deshalb nur ganz schwach getönt. Hier ist Rot aber schon die
/// Aussage — nicht schießen.
final trafficLightSignalProvider = Provider<SignalState>((ref) {
  final isGreen = ref.watch(trafficLightProvider);
  return SignalState(
    phase: isGreen ? TimerPhase.active : TimerPhase.preparation,
  );
});

final trafficLightGradientProvider = Provider<LinearGradient>((ref) {
  return TimerTheme.backgroundGradient(ref.watch(trafficLightSignalProvider));
});

/// Was [TimerDisplay] daraus macht.
///
/// `showTime: false` ist der Grund, warum es dieses Feld gibt: ohne Uhr rückt
/// das Signalwort an ihre Stelle und ist die ganze Anzeige. Es bleibt weiß —
/// die Signalfarbe steht schon flächig dahinter, und ein rotes Wort auf rotem
/// Grund verliert genau den Kontrast, von dem es auf die Distanz lebt.
final trafficLightUIStateProvider = Provider<TimerUIState>((ref) {
  final isGreen = ref.watch(trafficLightProvider);
  final texts = ref.watch(trafficLightTextsProvider);

  return TimerUIState(
    formattedTime: '',
    phaseText: isGreen ? texts.shoot : texts.stop,
    timeColor: AppPalette.textPrimary,
    phaseColor: AppPalette.textOnSignal,
    isWarning: false,
    showTime: false,
  );
});
