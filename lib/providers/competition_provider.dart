import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/competition_state.dart';
import '../models/timer_state.dart';
import 'phase_clock.dart';
import 'settings_provider.dart';

/// Die Uhr einer Qualifikationsrunde.
///
/// Aufgebaut wie [TimerNotifier] und auf derselben [PhaseClock]: jede Phase
/// hängt an einem absoluten Ende auf der Wanduhr, und die nächste wird am
/// geplanten Ende der vorigen verankert. Das ist hier noch wichtiger als bei
/// der Ampel — eine Hallenrunde hat 20 Passen × 2 Gruppen × 2 Phasen, und ohne
/// Verankerung würde sich die Verspätung jedes einzelnen Callbacks über
/// achtzig Phasen aufaddieren.
///
/// Der Ablauf ist immer derselbe: vor *jeder* Schusszeit steht eine
/// Vorbereitungszeit — am Anfang einer Passe die Ansage an die erste Gruppe,
/// danach der Wechsel zur zweiten. Beides ist dieselbe rote Phase; nur
/// [CompetitionState.isChangeover] unterscheidet, was auf dem Schirm steht.
class CompetitionNotifier extends Notifier<CompetitionState>
    with PhaseClock<CompetitionState> {
  @override
  Duration get storedRemaining => state.remainingTime;

  /// Auf der LED-Wand immer ganze Sekunden.
  ///
  /// Auf 120×80 Pixeln ist für „1:59.8" kein Platz, das Panel zeigt also
  /// ohnehin nur ganze Sekunden — und ein Zehntelraster würde die Uhr zehnmal
  /// pro Sekunde für eine Anzeige rechnen lassen, die sich einmal ändert.
  @override
  Duration get displayStep =>
      ref.read(competitionDisplayProvider) == CompetitionDisplay.standard
      ? super.displayStep
      : const Duration(seconds: 1);

  @override
  CompetitionState build() {
    ref.onDispose(stopTicking);
    watchDisplayStep();

    ref.listen(settingsProvider, (previous, next) {
      // Die Anzeigeart wechselt das Raster (siehe [displayStep]), aber nicht
      // die Runde: Passe, Gruppe und Restzeit bleiben stehen. Ohne den Schritt
      // stünde der armierte Timer noch auf dem alten Raster — dieselbe
      // Begründung wie in [PhaseClock.watchDisplayStep].
      if (previous?.competitionDisplay != next.competitionDisplay) {
        if (isTicking) stepNow();
        return;
      }

      // Disziplin, Passenzahl und Aufstellung beschreiben den Aufbau der ganzen
      // Runde. Sie mitten in einer laufenden Runde umzubauen hätte keine
      // Bedeutung — also wird die Runde neu aufgesetzt, wie im custom-Modus der
      // Ampel.
      if (previous?.competitionDiscipline != next.competitionDiscipline ||
          previous?.competitionEnds != next.competitionEnds ||
          previous?.competitionLineup != next.competitionLineup) {
        stopTicking();
        state = _initialState();
        return;
      }
    });

    return _initialState();
  }

  void start() {
    if (state.phase == TimerPhase.idle) {
      _startPreparation();
    } else if (state.isPaused) {
      _resume();
    } else if (state.isFinished) {
      reset();
      _startPreparation();
    }
  }

  void pause() {
    if (!state.canPause) return;

    // Auf dem von der Uhr abgeleiteten Wert einfrieren, nicht auf dem letzten
    // Tick: sonst verschenkt eine Pause zwischen zwei Callbacks Schusszeit.
    final left = remaining();
    stopTicking();
    state = state.copyWith(
      remainingTime: left,
      isPaused: true,
      isRunning: false,
    );
  }

  /// Start/Pause-Umschalter.
  void toggle() {
    if (state.canStart || state.canResume) {
      start();
    } else if (state.isRunning) {
      pause();
    }
  }

  /// Ein Schritt weiter: starten, die laufende Phase abbrechen, oder nach dem
  /// Ende der Runde zurücksetzen.
  ///
  /// Das ist die Taste des Schießleiters: wenn alle Pfeile draußen sind, muss
  /// er die restliche Schusszeit fallen lassen und übergeben können.
  void advance() {
    if (state.canStart || state.canResume) {
      start();
    } else if (state.isRunning) {
      skipPhase();
    } else if (state.isFinished) {
      reset();
    }
  }

  void skipPhase() {
    if (!state.isRunning) return;

    stopTicking();
    onPhaseElapsed();
  }

  /// Einen Schießabschnitt zurück: an den Anfang des vorigen Durchgangs, und
  /// dort angehalten.
  ///
  /// Die Umkehrung von [_handOver] — wer einmal zu oft weitergedrückt hat oder
  /// eine Gruppe wiederholen lassen muss, soll dafür nicht die ganze Runde
  /// zurücksetzen müssen. Die Runde bleibt danach stehen wie beim Pfeileholen:
  /// zurückspulen ist noch kein Startsignal.
  void rewind() {
    // Nach dem Rundenende ist der zuletzt verlassene Abschnitt der aktuelle —
    // der Schritt zurück ist hier, ihn zu wiederholen.
    if (state.isFinished) {
      _awaitSlot();
      return;
    }

    if (state.hasPreviousGroup) {
      _awaitSlot(groupIndex: state.groupIndex - 1);
      return;
    }

    if (state.hasPreviousEnd) {
      _awaitSlot(
        currentEnd: state.currentEnd - 1,
        // Die Gruppenzahl ist über die ganze Runde konstant, nur ihre
        // Reihenfolge dreht sich — der letzte Durchgang einer Passe hat also
        // immer denselben Index.
        groupIndex: state.lineup.groupLabels.length - 1,
      );
      return;
    }

    // Vor der ersten Gruppe der ersten Passe liegt nichts mehr. Die Runde geht
    // an ihren Anfang, statt die Taste ins Leere laufen zu lassen.
    _awaitSlot();
  }

  /// Einen Schießabschnitt vor — lautlos, ohne dass eine Phase dabei abläuft.
  ///
  /// Das Gegenstück zu [rewind] und ausdrücklich *nicht* dasselbe wie
  /// [advance]: weiterdrücken ist das Startsignal und lässt die Uhr laufen.
  /// Gebraucht wird das beim Wiederanlauf — stürzt der Rechner mitten in einer
  /// Runde ab, muss die Runde nach dem Neustart auf die laufende Passe gestellt
  /// werden, und dabei darf weder Zeit vergehen noch (später) ein Signalton in
  /// die Halle gehen.
  ///
  /// Wie [rewind] bleibt die Runde danach stehen: vorspulen ist kein
  /// Startsignal.
  void fastForward() {
    // Nach dem Rundenende liegt nichts mehr vor uns.
    if (state.isFinished) return;

    if (state.hasNextGroup) {
      _awaitSlot(groupIndex: state.groupIndex + 1);
      return;
    }

    if (state.hasNextEnd) {
      _awaitNextEnd();
      return;
    }

    // Hinter der letzten Gruppe der letzten Passe liegt nur das Rundenende, und
    // das ist kein Ziel zum Hinspulen — eine Runde beendet man, indem man sie
    // schießt. Dieselbe Klammer wie in [rewind] am Rundenanfang: die Runde
    // bleibt stehen, wo sie ist.
    _awaitSlot();
  }

  void reset() {
    stopTicking();
    state = _initialState();
  }

  CompetitionState _initialState() {
    final settings = ref.read(settingsProvider);
    final discipline = settings.competitionDiscipline;

    return CompetitionState(
      // Vor dem Start steht die Schusszeit auf dem Schirm: sie ist die Zahl,
      // um die es geht, und die Vorbereitungszeit läuft ohnehin gleich ab.
      remainingTime: discipline.shootingTime,
      phase: TimerPhase.idle,
      totalEnds: settings.competitionEnds,
      lineup: settings.competitionLineup,
      discipline: discipline,
      preparationTime: competitionPreparationTime,
      shootingTime: discipline.shootingTime,
    );
  }

  void _startPreparation({DateTime? anchor}) {
    state = state.copyWith(
      phase: TimerPhase.preparation,
      remainingTime: state.preparationTime,
      isRunning: true,
      isPaused: false,
    );
    startTicking(state.remainingTime, anchor: anchor);
  }

  void _startShooting({DateTime? anchor}) {
    state = state.copyWith(
      phase: TimerPhase.active,
      remainingTime: state.shootingTime,
    );
    startTicking(state.remainingTime, anchor: anchor);
  }

  /// Gibt an die nächste Gruppe oder die nächste Passe weiter.
  ///
  /// Innerhalb einer Passe läuft das durch: die Pfeile bleiben in der Scheibe,
  /// die nächste Gruppe geht direkt an die Schießlinie, also folgt sofort die
  /// Wechselzeit.
  ///
  /// Zwischen zwei Passen nicht: dazwischen wird gepfeilt geholt, und wie lange
  /// das dauert, weiß keine Uhr. Die Runde bleibt deshalb stehen und wartet auf
  /// das nächste Startsignal des Schießleiters — dieselbe Wartestellung wie vor
  /// der ersten Passe, nur mit der neuen Passe schon aufgesetzt, damit auf dem
  /// Schirm steht, wer nach dem Pfeileholen dran ist.
  void _handOver({DateTime? anchor}) {
    if (state.hasNextGroup) {
      state = state.copyWith(groupIndex: state.groupIndex + 1);
      _startPreparation(anchor: anchor);
      return;
    }

    if (state.hasNextEnd) {
      _awaitNextEnd();
      return;
    }

    _end();
  }

  /// Setzt die nächste Passe auf und wartet auf das Startsignal.
  void _awaitNextEnd() =>
      _awaitSlot(currentEnd: state.currentEnd + 1, groupIndex: 0);

  /// Stellt die Runde an den Anfang eines Schießabschnitts und hält sie dort
  /// an — die eine Wartestellung, die sowohl das Pfeileholen als auch das
  /// Zurückspulen herstellt. Ohne Angabe bleibt der Abschnitt, wo er ist.
  void _awaitSlot({int? currentEnd, int? groupIndex}) {
    stopTicking();
    state = state.copyWith(
      currentEnd: currentEnd,
      groupIndex: groupIndex,
      phase: TimerPhase.idle,
      isRunning: false,
      isPaused: false,
      // Wie vor der ersten Passe steht die Schusszeit auf dem Schirm: sie ist
      // die Zahl, um die es im kommenden Durchgang geht.
      remainingTime: state.shootingTime,
    );
  }

  void _end() {
    stopTicking();
    state = state.copyWith(
      phase: TimerPhase.ended,
      isRunning: false,
      remainingTime: Duration.zero,
    );
  }

  void _resume() {
    state = state.copyWith(isRunning: true, isPaused: false);
    startTicking(state.remainingTime);
  }

  @override
  void onRemainingChanged(Duration remaining) {
    state = state.copyWith(remainingTime: remaining);
  }

  @override
  void onPhaseElapsed({DateTime? anchor}) {
    switch (state.phase) {
      case TimerPhase.preparation:
        _startShooting(anchor: anchor);
      case TimerPhase.active:
        _handOver(anchor: anchor);
      case TimerPhase.idle:
      case TimerPhase.ended:
        _end();
    }
  }
}

final competitionProvider =
    NotifierProvider<CompetitionNotifier, CompetitionState>(
      () => CompetitionNotifier(),
    );

// ===== Convenience Provider =====

final competitionPhaseProvider = Provider<TimerPhase>((ref) {
  return ref.watch(competitionProvider).phase;
});

final competitionRemainingProvider = Provider<Duration>((ref) {
  return ref.watch(competitionProvider).remainingTime;
});

final isCompetitionRunningProvider = Provider<bool>((ref) {
  return ref.watch(competitionProvider).isRunning;
});

final isCompetitionInWarningProvider = Provider<bool>((ref) {
  return ref.watch(competitionProvider).isInWarningPeriod;
});
