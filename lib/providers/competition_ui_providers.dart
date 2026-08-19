import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/competition_texts.dart';
import '../core/l10n/timer_texts.dart';
import '../core/theme/timer_theme.dart';
import '../models/competition_state.dart';
import '../models/keyboard_config.dart';
import 'competition_provider.dart';
import 'settings_provider.dart';
import 'ui_providers.dart';

/// Alles, was der Wettkampfschirm anzeigt — nach demselben Muster wie
/// `ui_providers.dart` für die Ampel: viele kleine Provider, die jeweils nur bei
/// einem wirklich geänderten Wert melden.
///
/// Das ist hier keine Kosmetik: die Uhr aktualisiert sekündlich, und ein
/// Provider, der sich dabei jedes Mal für „geändert" hält, würde den ganzen
/// getönten Schirm im Sekundentakt neu zeichnen lassen.

final competitionPhaseTextProvider = Provider<String>((ref) {
  final state = ref.watch(competitionProvider);
  return ref.watch(competitionTextsProvider).phaseText(state);
});

final competitionFormattedTimeProvider = Provider<String>((ref) {
  return TimerTexts.formatTime(
    ref.watch(competitionRemainingProvider),
    showMilliseconds: ref.watch(showMillisecondsProvider),
    format: ref.watch(timeFormatProvider),
  );
});

/// „Passe 3/20".
final competitionEndTextProvider = Provider<String>((ref) {
  final state = ref.watch(competitionProvider);
  return ref
      .watch(competitionTextsProvider)
      .endCounter(state.currentEnd, state.totalEnds);
});

/// Was die Gruppenleiste braucht — als Record, weil Records strukturelle
/// Gleichheit haben: die Leiste hängt damit am Gruppenwechsel und nicht am
/// Sekundentakt. Die Beschriftungen selbst leitet die Leiste aus [lineup] und
/// [reversed] ab, statt eine Liste durchzureichen (zwei Listen mit gleichem
/// Inhalt sind nicht `==`, und der Provider würde jedes Mal melden).
typedef CompetitionGroupRail = ({
  CompetitionLineup lineup,
  bool reversed,
  int groupIndex,
});

final competitionGroupRailProvider = Provider<CompetitionGroupRail>((ref) {
  final state = ref.watch(competitionProvider);
  return (
    lineup: state.lineup,
    reversed: state.isOrderReversed,
    groupIndex: state.groupIndex,
  );
});

/// Ob es überhaupt eine Gruppenleiste gibt. Schießen alle zusammen, gäbe es
/// nichts zu unterscheiden.
final competitionHasGroupsProvider = Provider<bool>((ref) {
  return ref.watch(competitionProvider).hasGroups;
});

/// Beschriftung der Weiter-Taste — sie ist das Startsignal, solange die Runde
/// steht (vor der ersten Passe und beim Pfeileholen).
final competitionNextLabelProvider = Provider<String>((ref) {
  final state = ref.watch(competitionProvider);
  return ref.watch(competitionTextsProvider).nextLabel(state);
});

/// Beschriftung der Start/Pause-Taste in der Hinweisleiste.
final competitionToggleLabelProvider = Provider<String>((ref) {
  final state = ref.watch(competitionProvider);
  return ref.watch(competitionTextsProvider).toggleLabel(state);
});

/// Die Einträge der unteren Hinweisleiste, in der Reihenfolge, in der
/// links/rechts durch sie läuft.
final competitionHintActionsProvider = Provider<List<AppAction>>((ref) {
  return const [
    AppAction.next,
    // Direkt hinter der Weiter-Taste, aber nicht davor: die Auswahl steht ohne
    // Zutun auf dem ersten Eintrag, und Enter soll dort die Runde weiterführen
    // und nicht zurückspulen.
    AppAction.previous,
    AppAction.forward,
    AppAction.toggleTimer,
    AppAction.resetTimer,
    AppAction.toggleSettings,
    AppAction.toggleMenu,
  ];
});

// ===== THEME =====

final competitionBackgroundGradientProvider = Provider<LinearGradient>((ref) {
  return TimerTheme.backgroundGradient(ref.watch(competitionProvider).signal);
});

final competitionTimeColorProvider = Provider<Color>((ref) {
  return TimerTheme.timeColor(ref.watch(competitionProvider).signal);
});

final competitionPhaseColorProvider = Provider<Color>((ref) {
  return TimerTheme.phaseColor(ref.watch(competitionProvider).signal);
});

/// Die Signalfarbe der laufenden Phase — die Gruppenleiste hebt die aktive
/// Gruppe damit hervor, damit „wer ist dran" und „darf geschossen werden" auf
/// dieselbe Farbe hinauslaufen.
final competitionSignalColorProvider = Provider<Color>((ref) {
  return TimerTheme.signalFor(ref.watch(competitionProvider).signal).onTint;
});

// ===== LED-WAND =====
//
// Eigene Provider statt der obigen, weil die Wand eine andere Farbtabelle
// braucht (voll gesättigt statt getönt) und ein anderes Zeitformat. Die
// *Entscheidung*, welches Signal gilt, kommt weiterhin aus derselben Quelle.

final competitionLedSignalColorProvider = Provider<Color>((ref) {
  return TimerTheme.signalFor(ref.watch(competitionProvider).signal).led;
});

final competitionLedTimeColorProvider = Provider<Color>((ref) {
  return TimerTheme.ledTimeColor(ref.watch(competitionProvider).signal);
});

/// Die Zahl auf der Wand — die einzige Stelle, die sie formatiert.
///
/// Bewusst nicht [competitionFormattedTimeProvider] mitbenutzt: dessen
/// Millisekunden („1:59.8", sechs Zeichen) gehören nicht auf die Wand. Sie
/// würden zwar in die Zelle passen, aber als schmale, hohe Ziffern — und ab
/// fünf Metern Ableseabstand sind Zehntel Unruhe ohne Nutzen, die die
/// Qualifikationsrunde auch gar nicht kennt. Das Zeitformat („4:00" oder
/// „240") folgt dagegen der Einstellung wie überall sonst — dass es dafür genau
/// einen Ort gibt, war der halbe Aufwand.
final competitionLedTimeProvider = Provider<String>((ref) {
  return TimerTexts.formatTime(
    ref.watch(competitionRemainingProvider),
    format: ref.watch(timeFormatProvider),
  );
});

/// Das Kürzel der Gruppe, die gerade dran ist — oder `null`, wenn alle
/// zusammen schießen.
///
/// Auf 38 Pixel Spaltenbreite ist für die ganze Leiste kein Platz, und was
/// auf der Schießlinie zählt, ist ohnehin nur „wer ist dran".
final competitionLedGroupProvider = Provider<String?>((ref) {
  final rail = ref.watch(competitionGroupRailProvider);
  if (rail.lineup.groupLabels.length < 2) return null;

  return rail.lineup.orderedLabels(reversed: rail.reversed)[rail.groupIndex];
});

// ===== COMBINED =====

/// Derselbe Anzeigezustand wie bei der Ampel, damit [TimerDisplay] für beide
/// Schirme reicht.
final competitionUIStateProvider = Provider<TimerUIState>((ref) {
  return TimerUIState(
    formattedTime: ref.watch(competitionFormattedTimeProvider),
    phaseText: ref.watch(competitionPhaseTextProvider),
    timeColor: ref.watch(competitionTimeColorProvider),
    phaseColor: ref.watch(competitionPhaseColorProvider),
    isWarning: ref.watch(isCompetitionInWarningProvider),
    // Im Wettkampf läuft immer eine Uhr — es gibt keinen handgeschalteten Fall.
    showTime: true,
  );
});
