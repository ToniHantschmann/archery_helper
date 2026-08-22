import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/audio/audio_signal.dart';
import '../core/audio/signal_tone.dart';
import '../core/l10n/app_language.dart';
import '../models/competition_state.dart';
import '../models/settings.dart';
import '../models/settings_section.dart';
import '../models/timer_state.dart';
import 'app_state_provider.dart';
import 'settings_provider.dart';
import 'sound_provider.dart';

/// All keyboard-selectable rows of the settings screens, in visual order,
/// grouped by the screen they appear on.
///
/// The order defines what navigateUp/navigateDown step through — within one
/// [SettingsSection], because a screen only ever shows its own rows. Jeder
/// Eintrag gehört zu genau einem Bereich; deshalb hat jeder Bereich auch seine
/// eigene Reset-Zeile.
enum SettingsItem {
  // ── Allgemein ──────────────────────────────────────────
  language(SettingsSection.general),
  fullscreen(SettingsSection.general),
  soundEnabled(SettingsSection.general),
  signalTone(SettingsSection.general),
  volume(SettingsSection.general),
  resetGeneral(SettingsSection.general),
  // ── Ampel ──────────────────────────────────────────────
  defaultMode(SettingsSection.timer),
  showMilliseconds(SettingsSection.timer),
  timeFormat(SettingsSection.timer),
  timerScale(SettingsSection.timer),
  alternatingArrows(SettingsSection.timer),
  customPrepTime(SettingsSection.timer),
  customMainTime(SettingsSection.timer),
  resetTimer(SettingsSection.timer),
  // ── Wettkampf ──────────────────────────────────────────
  competitionDiscipline(SettingsSection.competition),
  competitionEnds(SettingsSection.competition),
  competitionPracticeEnds(SettingsSection.competition),
  competitionLineup(SettingsSection.competition),
  competitionCountdownTime(SettingsSection.competition),
  competitionCountdownAutoStart(SettingsSection.competition),
  competitionDisplay(SettingsSection.competition),
  // Zweite Zeile auf dasselbe Feld wie [timeFormat]: ein SettingsItem ist eine
  // Zeile, keine Einstellung. Das Zeitformat gilt für beide Uhren, und wer vor
  // der Wettkampfampel steht, soll es dort umstellen können, ohne erst in die
  // Ampel-Einstellungen zu wechseln. Beide Zeilen rufen setTimeFormat.
  competitionTimeFormat(SettingsSection.competition),
  resetCompetition(SettingsSection.competition);

  const SettingsItem(this.section);

  /// Auf welchem Einstellungs-Screen die Zeile steht.
  final SettingsSection section;

  /// Ob die Zeile den Bereich zurücksetzt. Die drei Reset-Zeilen verhalten sich
  /// gleich und unterscheiden sich nur darin, welchen Bereich sie anfassen.
  bool get isReset =>
      this == resetGeneral || this == resetTimer || this == resetCompetition;

  /// Alle Zeilen eines Bereichs, in Anzeigereihenfolge.
  static List<SettingsItem> of(SettingsSection section) =>
      values.where((item) => item.section == section).toList();
}

/// Step widths used when adjusting a duration with navigateLeft/navigateRight,
/// from the first press to a key held down for a while.
///
/// Without acceleration a duration moves 1s per key repeat, so 4:00 would take
/// ~240 repeats — roughly ten seconds of holding the key. The thresholds below
/// are counted in repeats, and auto-repeat runs at ~30Hz: the second step width
/// kicks in after about a quarter second, the third after about one second.
const _durationSteps = [
  (afterRepeats: 0, step: Duration(seconds: 1)),
  (afterRepeats: 8, step: Duration(seconds: 5)),
  (afterRepeats: 24, step: Duration(seconds: 15)),
];

/// Duration values are kept inside this range (1 hour is far beyond any
/// sensible shooting time, but keeps key repeat from running away).
const _maxDurationSeconds = 3600;

/// Volume moves in the same 10 steps the slider offers.
const _volumeSteps = 10;

/// Zeilen, die ohne Ton nichts einstellen: welcher Ton wie laut käme, ist keine
/// Frage, solange gar keiner kommt.
const _needsSound = {SettingsItem.signalTone, SettingsItem.volume};

class SettingsNavState {
  final SettingsItem selected;

  /// True while the reset row awaits a second confirmation.
  ///
  /// This is genuine state, not a one-shot event: the row renders differently
  /// while armed, and it is cleared by confirming, by Esc, or by moving away.
  /// That keeps the confirmation entirely inside the provider — no dialog
  /// route, no BuildContext, and the same flow for mouse and keyboard.
  final bool resetArmed;

  const SettingsNavState({
    this.selected = SettingsItem.language,
    this.resetArmed = false,
  });

  /// Welcher Bereich offen ist. Keine eigene Angabe: jede Zeile gehört zu genau
  /// einem Bereich, also sagt die ausgewählte Zeile es schon.
  SettingsSection get section => selected.section;

  SettingsNavState copyWith({SettingsItem? selected, bool? resetArmed}) {
    return SettingsNavState(
      selected: selected ?? this.selected,
      resetArmed: resetArmed ?? this.resetArmed,
    );
  }
}

/// Owns which settings row is focused and translates the navigate* actions
/// into changes on [settingsProvider]. Kept separate from the widget so the
/// keyboard path (AppActionsNotifier) and the mouse path (taps in
/// SettingsScreen) drive exactly the same state.
class SettingsNavigationNotifier extends Notifier<SettingsNavState> {
  /// How many auto-repeat events the current adjust run has seen. Held-down
  /// keys widen the duration step (see [_durationSteps]); anything that ends
  /// the run — a real key down, a different row, the other direction — puts it
  /// back to zero. This is deliberately not derived from timestamps: a key down
  /// event ends a run unambiguously, a guessed timeout does not.
  int _repeatRun = 0;

  /// The direction the current run is going in, so reversing starts over.
  int _repeatDelta = 0;

  /// Welcher Bereich offen ist, entscheidet der Screen — der Notifier folgt
  /// ihm, statt dass der Screen es ihm nach dem ersten Frame nachreicht. Damit
  /// ist die Auswahl schon im ersten Frame die richtige, und es gibt keinen
  /// Moment, in dem hier die Zeilen eines anderen Bereichs stehen.
  ///
  /// Der Bereich wird *beobachtet* und nicht in einem `ref.listen` nachgezogen:
  /// ein Listener, der `state` setzt, feuert genau dann, wenn der neue Screen
  /// diesen Provider zum ersten Mal liest — also mitten im Aufbau des
  /// Widget-Baums, was Riverpod zu Recht als Fehler meldet. Ein neuer Build ist
  /// derselbe Neustart, nur an der Stelle, an der er erlaubt ist: ein
  /// Bereichswechsel fängt oben an, statt dort, wo der letzte Screen verlassen
  /// wurde. Beobachten allein reicht aber nicht — siehe die Begründung für
  /// `autoDispose` bei [settingsNavigationProvider], ohne die das Verlassen
  /// dieselbe Meldung erzeugt, nur einen Screenwechsel später.
  @override
  SettingsNavState build() {
    final section = ref.watch(openSettingsSectionProvider);
    // Die einzige Stelle, an der dieser Build etwas außerhalb seines
    // Rückgabewerts anfasst: bei einem Bereichswechsel im laufenden Betrieb
    // überlebt das Notifier-Objekt den Rebuild, also muss eine angefangene
    // Wiederholungsserie hier von Hand enden.
    _endRepeatRun();

    return SettingsNavState(
      selected: _firstItemOf(section ?? SettingsSection.general),
    );
  }

  SettingsItem _firstItemOf(SettingsSection section) =>
      SettingsItem.of(section).first;

  void select(SettingsItem item) {
    if (item != state.selected) _endRepeatRun();

    // Moving away from an armed reset cancels it.
    state = state.copyWith(
      selected: item,
      resetArmed: item == state.selected && state.resetArmed,
    );
  }

  void moveUp() => _move(-1);

  void moveDown() => _move(1);

  void adjustLeft({bool isRepeat = false}) => _adjust(-1, isRepeat: isRepeat);

  void adjustRight({bool isRepeat = false}) => _adjust(1, isRepeat: isRepeat);

  /// Confirm/next on the focused row: toggles switches, arms and then performs
  /// the reset.
  void activate() {
    final notifier = ref.read(settingsProvider.notifier);

    switch (state.selected) {
      case SettingsItem.fullscreen:
        notifier.toggleFullscreen();

      case SettingsItem.soundEnabled:
        notifier.toggleSound();
        _previewSound();

      case SettingsItem.showMilliseconds:
        notifier.toggleShowMilliseconds();

      case SettingsItem.competitionCountdownAutoStart:
        notifier.toggleCompetitionCountdownAutoStart();

      case SettingsItem.resetGeneral:
      case SettingsItem.resetTimer:
      case SettingsItem.resetCompetition:
        if (state.resetArmed) {
          notifier.resetSection(state.selected.section);
          state = state.copyWith(resetArmed: false);
        } else {
          state = state.copyWith(resetArmed: true);
        }

      // Enums and numbers cycle forward, so confirm behaves like navigateRight.
      case SettingsItem.language:
      case SettingsItem.defaultMode:
      case SettingsItem.timeFormat:
      case SettingsItem.competitionTimeFormat:
      case SettingsItem.signalTone:
      case SettingsItem.volume:
      case SettingsItem.timerScale:
      case SettingsItem.alternatingArrows:
      case SettingsItem.customPrepTime:
      case SettingsItem.customMainTime:
      case SettingsItem.competitionDiscipline:
      case SettingsItem.competitionEnds:
      case SettingsItem.competitionPracticeEnds:
      case SettingsItem.competitionDisplay:
      case SettingsItem.competitionLineup:
      case SettingsItem.competitionCountdownTime:
        _adjust(1);
    }
  }

  /// Cancels a pending reset confirmation.
  /// Returns whether there was one — the caller uses that to decide whether
  /// Esc was consumed here or should leave the screen.
  bool disarmReset() {
    if (!state.resetArmed) return false;

    state = state.copyWith(resetArmed: false);
    return true;
  }

  void _move(int delta) {
    final items = _selectableItems();
    final currentIndex = items.indexOf(state.selected);

    // The current row can be unselectable (volume with sound off) if the value
    // changed after selection — fall back to the start of the list.
    if (currentIndex == -1) {
      select(items.first);
      return;
    }

    final nextIndex = (currentIndex + delta + items.length) % items.length;
    select(items[nextIndex]);
  }

  /// Rows that can currently hold focus: the ones on the open screen, minus the
  /// ones that cannot be used. Bei ausgeschaltetem Ton sind das die beiden
  /// Zeilen darunter — sie sind ausgegraut und wären beim Durchsteppen tote
  /// Stopps.
  List<SettingsItem> _selectableItems() {
    final soundEnabled = ref.read(settingsProvider).soundEnabled;

    return SettingsItem.of(
      state.section,
    ).where((item) => soundEnabled || !_needsSound.contains(item)).toList();
  }

  /// Lässt hören, was gerade eingestellt wird.
  ///
  /// Zehn Kästchen für die Lautstärke sind ohne Rückmeldung nur zehn Kästchen —
  /// und dass der Ton wieder an ist, merkt man am besten daran, dass es tönt.
  /// Läuft absichtlich durch [SignalSounds], also mit der eben gesetzten
  /// Lautstärke und still, sobald der Ton aus ist.
  void _previewSound() =>
      ref.read(signalSoundsProvider).play(AudioSignal.warningTick);

  void _adjust(int delta, {bool isRepeat = false}) {
    _trackRepeatRun(delta, isRepeat: isRepeat);

    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    switch (state.selected) {
      case SettingsItem.language:
        notifier.setLanguage(
          _cycle(AppLanguage.values, settings.language, delta),
        );

      case SettingsItem.fullscreen:
        if (settings.fullscreen != (delta > 0)) {
          notifier.toggleFullscreen();
        }

      case SettingsItem.soundEnabled:
        if (settings.soundEnabled != (delta > 0)) {
          notifier.toggleSound();
          _previewSound();
        }

      case SettingsItem.signalTone:
        if (!settings.soundEnabled) return;
        notifier.setSignalTone(
          _cycle(SignalTone.values, settings.signalTone, delta),
        );
        // Der Preview-Tick ist genau der Ton, an dem der Unterschied am
        // deutlichsten zu hören ist.
        _previewSound();

      case SettingsItem.volume:
        if (!settings.soundEnabled) return;
        // Work in whole slider steps to avoid floating point drift.
        final steps = (settings.volume * _volumeSteps).round() + delta;
        final volume = steps.clamp(0, _volumeSteps) / _volumeSteps;
        // Am Anschlag nichts tun: sonst tickt ein gehaltener Pfeil weiter, ohne
        // dass sich etwas ändert.
        if (volume == settings.volume) return;
        notifier.setVolume(volume);
        _previewSound();

      case SettingsItem.defaultMode:
        notifier.setDefaultMode(
          _cycle(TimerMode.values, settings.defaultMode, delta),
        );

      case SettingsItem.showMilliseconds:
        if (settings.showMilliseconds != (delta > 0)) {
          notifier.toggleShowMilliseconds();
        }

      // Beide Zeilen, ein Feld — deshalb derselbe Zweig.
      case SettingsItem.timeFormat:
      case SettingsItem.competitionTimeFormat:
        notifier.setTimeFormat(
          _cycle(TimeFormat.values, settings.timeFormat, delta),
        );

      // In ganzen Prozent gerechnet, wie die Lautstärke in ganzen Blöcken:
      // 5 % als Kommazahl aufzuaddieren würde die 100 % irgendwann verfehlen.
      case SettingsItem.timerScale:
        final percent =
            (settings.timerScale * 100).round() +
            delta * Settings.timerScaleStepPercent;
        notifier.setTimerScale(percent / 100);

      // Ohne Beschleunigung: bei einem Bereich von 1 bis 6 wäre eine
      // wachsende Schrittweite nur im Weg.
      case SettingsItem.alternatingArrows:
        notifier.setAlternatingArrows(settings.alternatingArrows + delta);

      case SettingsItem.customPrepTime:
        notifier.setCustomPrepTime(_step(settings.customPrepTime, delta));

      case SettingsItem.customMainTime:
        notifier.setCustomMainTime(_step(settings.customMainTime, delta));

      // Ohne Beschleunigung: der Bereich ist klein genug, und eine wachsende
      // Schrittweite würde die 20 der Halle nur überspringen.
      case SettingsItem.competitionEnds:
        notifier.setCompetitionEnds(settings.competitionEnds + delta);

      case SettingsItem.competitionPracticeEnds:
        notifier.setCompetitionPracticeEnds(
          settings.competitionPracticeEnds + delta,
        );

      case SettingsItem.competitionDiscipline:
        notifier.setCompetitionDiscipline(
          _cycle(
            CompetitionDiscipline.values,
            settings.competitionDiscipline,
            delta,
          ),
        );

      case SettingsItem.competitionLineup:
        notifier.setCompetitionLineup(
          _cycle(CompetitionLineup.values, settings.competitionLineup, delta),
        );

      // Mit Beschleunigung wie die Ampelzeiten: von zehn Sekunden auf zehn
      // Minuten wäre es sonst ein langer Weg.
      case SettingsItem.competitionCountdownTime:
        notifier.setCompetitionCountdownTime(
          _step(settings.competitionCountdownTime, delta),
        );

      case SettingsItem.competitionCountdownAutoStart:
        if (settings.competitionCountdownAutoStart != (delta > 0)) {
          notifier.toggleCompetitionCountdownAutoStart();
        }

      case SettingsItem.competitionDisplay:
        notifier.setCompetitionDisplay(
          _cycle(CompetitionDisplay.values, settings.competitionDisplay, delta),
        );

      case SettingsItem.resetGeneral:
      case SettingsItem.resetTimer:
      case SettingsItem.resetCompetition:
        // Nothing to adjust — only confirm acts on these rows.
        break;
    }
  }

  /// Counts the repeats of an uninterrupted adjust run. A real key down
  /// (`isRepeat == false`) or a reversal starts a new one.
  void _trackRepeatRun(int delta, {required bool isRepeat}) {
    if (!isRepeat || delta != _repeatDelta) {
      _repeatRun = 0;
      _repeatDelta = delta;
      return;
    }

    _repeatRun++;
  }

  void _endRepeatRun() {
    _repeatRun = 0;
    _repeatDelta = 0;
  }

  Duration _step(Duration current, int delta) {
    final step = _durationSteps
        .lastWhere((entry) => _repeatRun >= entry.afterRepeats)
        .step
        .inSeconds;

    // Snap onto the step width while accelerating, so a held key lands on round
    // numbers instead of carrying an offset from the 1s phase along.
    final seconds = ((current.inSeconds / step).round() + delta) * step;
    return Duration(seconds: seconds.clamp(0, _maxDurationSeconds));
  }

  T _cycle<T>(List<T> values, T current, int delta) {
    final index = values.indexOf(current);
    final nextIndex = (index + delta + values.length) % values.length;
    return values[nextIndex];
  }
}

/// Die Auswahl lebt genau so lange wie der Einstellungs-Screen, der sie zeigt.
///
/// `autoDispose` ist hier kein Aufräumen, sondern Notwehr: ohne es überlebt der
/// Provider das Verlassen des Screens, sein Bereich wird dabei `null`, und der
/// fällige Rebuild wird erst beim nächsten Lesen nachgeholt — beim nächsten
/// Betreten also mitten im Aufbau des Screens. Ändert sich dabei ein
/// abgeleiteter Wert (die ausgewählte Zeile, die geöffnete Reset-Bestätigung),
/// meldet Riverpod den Provider-Scope während eines Builds als „muss neu
/// bauen", und Flutter bricht ab. Wird der Provider stattdessen mit dem Screen
/// weggeräumt, gibt es nichts Veraltetes mehr nachzuholen: der nächste Besuch
/// baut ihn frisch auf, mit dem Bereich, der dann offen ist.
///
/// Die drei Provider, die davon *abgeleitet* sind, hängen deshalb mit dran: ein
/// dauerhafter Provider, der einen `autoDispose`-Provider beobachtet, würde ihn
/// am Leben halten. [openSettingsSectionProvider] steht oberhalb und bleibt
/// dauerhaft — es hängt nur am Screen und hält hier nichts fest.
final settingsNavigationProvider =
    NotifierProvider.autoDispose<SettingsNavigationNotifier, SettingsNavState>(
      () => SettingsNavigationNotifier(),
    );

/// Welcher Einstellungsbereich gerade offen ist, oder `null`, wenn gar keiner
/// offen ist.
///
/// Abgeleitet aus dem aktuellen Screen, nicht daneben gehalten: die drei
/// Einstellungs-Screens *sind* die drei Bereiche.
final openSettingsSectionProvider = Provider<SettingsSection?>((ref) {
  return switch (ref.watch(currentScreenProvider)) {
    AppScreen.generalSettings => SettingsSection.general,
    AppScreen.timerSettings => SettingsSection.timer,
    AppScreen.competitionSettings => SettingsSection.competition,
    _ => null,
  };
});

/// Convenience provider: the currently focused row.
final selectedSettingsItemProvider = Provider.autoDispose<SettingsItem>((ref) {
  return ref.watch(settingsNavigationProvider).selected;
});

/// Whether a single row is focused. Used per row so that moving the selection
/// only rebuilds the two rows involved instead of the whole screen.
final isSettingsItemSelectedProvider = Provider.autoDispose
    .family<bool, SettingsItem>((ref, item) {
      return ref.watch(selectedSettingsItemProvider) == item;
    });

/// Whether the reset row currently awaits confirmation.
final isResetArmedProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(settingsNavigationProvider).resetArmed;
});
