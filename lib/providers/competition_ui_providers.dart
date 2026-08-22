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
///
/// `autoDispose` gilt hier aus demselben Grund wie dort — siehe die Erklärung
/// in `ui_providers.dart`.

final competitionPhaseTextProvider = Provider.autoDispose<String>((ref) {
  final state = ref.watch(competitionProvider);
  return ref.watch(competitionTextsProvider).phaseText(state);
});

final competitionFormattedTimeProvider = Provider.autoDispose<String>((ref) {
  return TimerTexts.formatTime(
    ref.watch(competitionRemainingProvider),
    showMilliseconds: ref.watch(showMillisecondsProvider),
    format: ref.watch(timeFormatProvider),
  );
});

/// „Passe 3/20", beim Einschießen „Einschießen 2/4".
final competitionEndTextProvider = Provider.autoDispose<String>((ref) {
  final state = ref.watch(competitionProvider);
  return ref.watch(competitionTextsProvider).endCounter(state);
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

final competitionGroupRailProvider = Provider.autoDispose<CompetitionGroupRail>((ref) {
  final state = ref.watch(competitionProvider);
  return (
    lineup: state.lineup,
    reversed: state.isOrderReversed,
    groupIndex: state.groupIndex,
  );
});

/// Ob es überhaupt eine Gruppenleiste gibt. Schießen alle zusammen, gäbe es
/// nichts zu unterscheiden.
final competitionHasGroupsProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(competitionProvider).hasGroups;
});

/// Beschriftung der Weiter-Taste — sie ist das Startsignal, solange die Runde
/// steht (vor der ersten Passe und beim Pfeileholen).
final competitionNextLabelProvider = Provider.autoDispose<String>((ref) {
  final state = ref.watch(competitionProvider);
  return ref.watch(competitionTextsProvider).nextLabel(state);
});

/// Beschriftung der Start/Pause-Taste in der Hinweisleiste.
final competitionToggleLabelProvider = Provider.autoDispose<String>((ref) {
  final state = ref.watch(competitionProvider);
  return ref.watch(competitionTextsProvider).toggleLabel(state);
});

/// Ob statt der Runde die Uhrzeit angezeigt wird.
final competitionShowClockProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(competitionProvider).showClock;
});

/// Beschriftung der Uhrzeit-Taste. Dieselbe Taste in beide Richtungen, also sagt
/// die Beschriftung, wohin sie führt, und nicht, was gerade zu sehen ist.
final competitionClockLabelProvider = Provider.autoDispose<String>((ref) {
  final showClock = ref.watch(competitionShowClockProvider);
  return ref.watch(competitionTextsProvider).clockLabel(showClock: showClock);
});

/// Die Einträge der unteren Hinweisleiste, in der Reihenfolge, in der
/// links/rechts durch sie läuft.
final competitionHintActionsProvider = Provider.autoDispose<List<AppAction>>((ref) {
  return const [
    AppAction.next,
    // Direkt hinter der Weiter-Taste, aber nicht davor: die Auswahl steht ohne
    // Zutun auf dem ersten Eintrag, und Enter soll dort die Runde weiterführen
    // und nicht zurückspulen.
    AppAction.previous,
    AppAction.forward,
    AppAction.toggleTimer,
    AppAction.resetTimer,
    // Die Uhrzeit ist eine Anzeige-Entscheidung wie die Einstellungen, keine
    // Bedienung der Runde — deshalb hinter dem Zurücksetzen und nicht zwischen
    // den Tasten, die die Runde bewegen.
    AppAction.toggleClock,
    AppAction.toggleSettings,
    // Esc, wie bei der Ampel — siehe timerHintActionsProvider.
    AppAction.back,
  ];
});

// ===== THEME =====

final competitionBackgroundGradientProvider = Provider.autoDispose<LinearGradient>((ref) {
  return TimerTheme.backgroundGradient(ref.watch(competitionProvider).signal);
});

final competitionTimeColorProvider = Provider.autoDispose<Color>((ref) {
  return TimerTheme.timeColor(ref.watch(competitionProvider).signal);
});

final competitionPhaseColorProvider = Provider.autoDispose<Color>((ref) {
  return TimerTheme.phaseColor(ref.watch(competitionProvider).signal);
});

/// Die Signalfarbe der laufenden Phase — die Gruppenleiste hebt die aktive
/// Gruppe damit hervor, damit „wer ist dran" und „darf geschossen werden" auf
/// dieselbe Farbe hinauslaufen.
final competitionSignalColorProvider = Provider.autoDispose<Color>((ref) {
  return TimerTheme.signalFor(ref.watch(competitionProvider).signal).onTint;
});

// ===== LED-WAND =====
//
// Eigene Provider statt der obigen, weil die Wand eine andere Farbtabelle
// braucht (voll gesättigt statt getönt) und ein anderes Zeitformat. Die
// *Entscheidung*, welches Signal gilt, kommt weiterhin aus derselben Quelle.

final competitionLedSignalColorProvider = Provider.autoDispose<Color>((ref) {
  return TimerTheme.signalFor(ref.watch(competitionProvider).signal).led;
});

final competitionLedTimeColorProvider = Provider.autoDispose<Color>((ref) {
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
final competitionLedTimeProvider = Provider.autoDispose<String>((ref) {
  return TimerTexts.formatTime(
    ref.watch(competitionRemainingProvider),
    format: ref.watch(timeFormatProvider),
  );
});

/// Das Kürzel der Gruppe, die gerade dran ist — oder `null`, wenn alle
/// zusammen schießen.
///
/// Auf 46 Pixel Beschriftungsbreite ist für die ganze Leiste kein Platz, und
/// was auf der Schießlinie zählt, ist ohnehin nur „wer ist dran".
final competitionLedGroupProvider = Provider.autoDispose<String?>((ref) {
  final rail = ref.watch(competitionGroupRailProvider);
  if (rail.lineup.groupLabels.length < 2) return null;

  return rail.lineup.orderedLabels(reversed: rail.reversed)[rail.groupIndex];
});

/// Der Passenzähler auf der Wand: „3", beim Einschießen „P1".
///
/// Bewusst nicht über [CompetitionTexts.endCounter]: dessen „Passe 3/20" hat
/// ein Wort, und dafür ist in der Zelle kein Platz. Auch die Gesamtzahl ist
/// keine: sie würde die Zelle um die Hälfte breiter machen, und die anderen
/// beiden Drittel der Zeile müssten das bezahlen. Wie viele Passen die Runde
/// hat, steht in der Bedienansicht — auf der Schießlinie zählt, die wievielte
/// gerade läuft. Was übrig bleibt, ist eine Zahl und damit in jeder Sprache
/// dasselbe; hier gibt es also nichts zu übersetzen.
///
/// Das „P" der Einschießpassen ist die eine Ausnahme davon, und auch das
/// bewusst unübersetzt: Einschießen, Practice und Probe fangen alle damit an,
/// und mehr als ein Zeichen ist neben der Zahl ohnehin nicht frei. Es muss dort
/// stehen, weil die Zelle sonst dieselbe „1" für zwei verschiedene Passen zeigt.
///
/// Hängt am ganzen [competitionProvider] und rechnet damit im Sekundentakt neu,
/// meldet aber nur bei geändertem String: ein `Provider` benachrichtigt auf
/// `!=`, und zwei gleiche Zähler sind gleich.
final competitionLedEndProvider = Provider.autoDispose<String>((ref) {
  final state = ref.watch(competitionProvider);
  return state.isPractice ? 'P${state.endNumber}' : '${state.endNumber}';
});

// ===== COMBINED =====

/// Derselbe Anzeigezustand wie bei der Ampel, damit [TimerDisplay] für beide
/// Schirme reicht.
final competitionUIStateProvider = Provider.autoDispose<TimerUIState>((ref) {
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
