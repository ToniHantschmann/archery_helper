import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/timer_texts.dart';
import '../core/theme/timer_theme.dart';
import '../models/keyboard_config.dart';
import '../models/timer_state.dart';
import 'keyboard_config_provider.dart';
import 'settings_provider.dart';
import 'timer_provider.dart';

/// Die Anzeige-Provider des Ampelschirms — abgeleitete Werte, sonst nichts.
///
/// Alle sind `autoDispose`, und das ist wie beim `settingsNavigationProvider`
/// kein Aufräumen, sondern Notwehr. Ein dauerhafter Provider, den niemand mehr
/// hört, holt eine Änderung erst beim nächsten Lesen nach — und das nächste
/// Lesen ist der Aufbau des Schirms, der ihn wieder braucht. Meldet er dabei
/// einem anderen dauerhaften Provider einen neuen Wert (die Kette hier ist
/// zwei Ebenen tief: [timerUIStateProvider] → [formattedTimeProvider] →
/// [remainingTimeProvider]), wird der Provider-Scope mitten im Build dirty und
/// Flutter wirft `setState() called during build`. Genau das ist passiert, wenn
/// man in den Ampel-Einstellungen die Millisekunden umgeschaltet hat und mit
/// Esc zur Uhr zurückgegangen ist.
///
/// Mit dem Schirm entsorgt gibt es nichts Verspätetes mehr nachzuholen: die
/// Provider entstehen beim nächsten Aufbau neu und rechnen ihren Wert aus dem
/// aktuellen Zustand. Kosten hat das keine — es sind reine Rechnungen auf
/// Zustand, der ohnehin am Leben bleibt. `test/settings_change_test.dart` geht
/// den Weg für jede Einstellung ab.
///
/// Neue Anzeige-Provider gehören genauso angelegt.

// ===== TEXT PROVIDERS =====

final timerPhaseTextProvider = Provider.autoDispose<String>((ref) {
  final timerState = ref.watch(timerProvider);
  final texts = ref.watch(timerTextsProvider);
  return texts.getPhaseTextEnhanced(timerState);
});

final timerModeTextProvider = Provider.autoDispose<String>((ref) {
  final timerState = ref.watch(timerProvider);
  final texts = ref.watch(timerTextsProvider);
  return texts.getModeText(timerState.mode);
});

/// Pfeilzähler des Wechselmodus ("Pfeil 2/3"), sonst `null`.
///
/// Liest den ganzen Timer-Zustand, liefert aber innerhalb einer Passage immer
/// denselben String — und ein [Provider] meldet sich nur bei einem geänderten
/// Wert. Der Chip hängt also am Wechsel und nicht am Sekundentakt.
final alternatingArrowTextProvider = Provider.autoDispose<String?>((ref) {
  final timerState = ref.watch(timerProvider);
  if (!timerState.mode.isAlternating) return null;

  final texts = ref.watch(timerTextsProvider);
  return texts.arrowCounter(
    timerState.currentArrow,
    timerState.arrowsPerArcher,
  );
});

final formattedTimeProvider = Provider.autoDispose<String>((ref) {
  final remainingTime = ref.watch(remainingTimeProvider);
  final settings = ref.watch(settingsProvider);
  return TimerTexts.formatTime(
    remainingTime,
    showMilliseconds: settings.showMilliseconds,
    format: settings.timeFormat,
  );
});

/// Label of the start/pause control in the hint rail.
final startButtonTextProvider = Provider.autoDispose<String>((ref) {
  final timerState = ref.watch(timerProvider);
  final texts = ref.watch(timerTextsProvider);

  if (timerState.isPaused) {
    return texts.resumeButton;
  } else if (timerState.canStart) {
    return texts.startButton;
  } else {
    return texts.pauseButton;
  }
});

/// Actions shown in the timer screen's bottom hint rail, in the same order
/// [TimerScreenActions] steps through with left/right — see
/// `hint_navigation_provider.dart`. Kept next to the other hint-rail
/// providers so the two stay in sync; `_TimerHintRail` builds its [KeyHint]s
/// from this list rather than duplicating the order.
final timerHintActionsProvider = Provider.autoDispose<List<AppAction>>((ref) {
  return const [
    AppAction.next,
    AppAction.toggleTimer,
    AppAction.resetTimer,
    AppAction.nextMode,
    AppAction.toggleSettings,
    // Der Rückweg ins Hauptmenü ist Esc, dieselbe Taste, die aus den
    // Einstellungen wieder hierher führt — die Leiste zeigt sie deshalb als
    // [AppAction.back] und nicht als eigene Menü-Taste.
    AppAction.back,
  ];
});

/// The key currently bound to [action], formatted for a key cap.
///
/// The hint rails read the binding instead of hard-coding letters, so a
/// remapped key stays honest on screen. The space bar is special-cased: its
/// proper name ("Leertaste") does not fit on a cap.
final actionKeyLabelProvider = Provider.autoDispose.family<String, AppAction>((
  ref,
  action,
) {
  final keys = ref.watch(keyboardConfigProvider).getKeysForAction(action);
  if (keys.isEmpty) return '–';

  final key = keys.first;
  if (key == LogicalKeyboardKey.space) {
    return ref.watch(timerTextsProvider).keySpaceLabel;
  }

  return KeyboardConfig.getKeyName(key);
});

// ===== THEME PROVIDERS =====

final timerBackgroundGradientProvider = Provider.autoDispose<LinearGradient>((ref) {
  return TimerTheme.backgroundGradient(ref.watch(timerProvider).signal);
});

final timerTextColorProvider = Provider.autoDispose<Color>((ref) {
  return TimerTheme.timeColor(ref.watch(timerProvider).signal);
});

final timerPhaseColorProvider = Provider.autoDispose<Color>((ref) {
  return TimerTheme.phaseColor(ref.watch(timerProvider).signal);
});

final timerPhaseProvider = Provider.autoDispose<TimerPhase>((ref) {
  return ref.watch(timerProvider).phase;
});

// ===== COMBINED UI STATE =====

/// Everything the countdown block needs, in one object.
///
/// Every field comes from a provider that only notifies when its own value
/// really changed, so this is recomputed a handful of times per phase rather
/// than ten times a second — which is also what keeps the display from
/// repainting while somebody is aiming.
class TimerUIState {
  final String formattedTime;
  final String phaseText;
  final Color timeColor;
  final Color phaseColor;
  final bool isWarning;

  /// Ob überhaupt eine Uhr gezeigt wird. Das Ampel-Werkzeug hat keine Zeit,
  /// dort ist das Signalwort die ganze Anzeige.
  final bool showTime;

  const TimerUIState({
    required this.formattedTime,
    required this.phaseText,
    required this.timeColor,
    required this.phaseColor,
    required this.isWarning,
    required this.showTime,
  });
}

final timerUIStateProvider = Provider.autoDispose<TimerUIState>((ref) {
  return TimerUIState(
    formattedTime: ref.watch(formattedTimeProvider),
    phaseText: ref.watch(timerPhaseTextProvider),
    timeColor: ref.watch(timerTextColorProvider),
    phaseColor: ref.watch(timerPhaseColorProvider),
    isWarning: ref.watch(isInWarningProvider),
    showTime: true,
  );
});
