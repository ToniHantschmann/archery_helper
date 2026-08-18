import 'package:archery_helper/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timer_state.dart';
import 'phase_clock.dart';

// Business Logic Klasse
class TimerNotifier extends Notifier<TimerState> with PhaseClock<TimerState> {
  @override
  Duration get storedRemaining => state.remainingTime;

  @override
  TimerState build() {
    ref.onDispose(stopTicking);
    watchDisplayStep();

    ref.listen(settingsProvider, (previous, next) {
      // Nur reagieren wenn custom Zeiten sich geändert haben und custom Modus aktiv ist
      if (state.mode == TimerMode.custom &&
          (previous?.customPrepTime != next.customPrepTime ||
              previous?.customMainTime != next.customMainTime)) {
        stopTicking();
        state = _stateForMode(TimerMode.custom);
        return;
      }

      // Der Wechselmodus hängt an der Vorbereitungszeit und an der Pfeilzahl.
      // Beides ändert den Aufbau der ganzen Passe, deshalb wird sie — wie im
      // custom-Modus — neu aufgesetzt statt mittendrin umgebaut.
      if (state.mode.isAlternating &&
          (previous?.customPrepTime != next.customPrepTime ||
              previous?.alternatingArrows != next.alternatingArrows)) {
        stopTicking();
        state = _stateForMode(TimerMode.alternating);
        return;
      }
    });

    final settings = ref.read(settingsProvider);
    return _stateForMode(settings.defaultMode);
  }

  void startTimer() {
    if (state.mode.isManual) {
      _toggleSignal();
      return;
    }

    if (state.phase == TimerPhase.idle) {
      _startPreparationPhase();
    } else if (state.isPaused) {
      _resumeTimer();
    } else if (state.isFinished) {
      resetTimer();
      _startPreparationPhase();
    }
  }

  void pauseTimer() {
    // Im Ampel-Modus gibt es nichts anzuhalten — das Signal steht ohnehin.
    if (state.mode.isManual) return;

    // Freeze on the clock-derived value, not on the last tick: pausing between
    // two callbacks would otherwise hand back up to 100ms of shooting time.
    final left = remaining();
    stopTicking();
    state = state.copyWith(
      remainingTime: left,
      isPaused: true,
      isRunning: false,
    );
  }

  /// Play/pause toggle. Lives here because only the notifier knows which
  /// transitions the current state allows — callers should not re-derive that.
  void toggle() {
    if (state.mode.isManual) {
      _toggleSignal();
      return;
    }

    if (state.canStart || state.isPaused) {
      startTimer();
    } else if (state.isRunning) {
      pauseTimer();
    }
  }

  /// Context-sensitive "one step further": start, skip the running phase, or
  /// reset once finished. Distinct from [toggle], which never skips or resets.
  void advance() {
    if (state.mode.isManual) {
      _toggleSignal();
      return;
    }

    if (state.canStart || state.isPaused) {
      startTimer();
    } else if (state.isRunning) {
      skipTimerPhase();
    } else if (state.isFinished) {
      resetTimer();
    }
  }

  void resetTimer() {
    setMode(state.mode);
  }

  void skipTimerPhase() {
    if (state.mode.isManual) return;

    if (state.isRunning) {
      stopTicking();
      onPhaseElapsed();
    }
  }

  void setMode(TimerMode mode) {
    stopTicking();
    state = _stateForMode(mode);
  }

  TimerState _stateForMode(TimerMode mode) {
    // Der Ampel-Modus steigt direkt in `preparation` ein, nicht in `idle`:
    // `idle` ist als "noch nichts los" gedacht und wird deshalb nur ganz
    // schwach getönt. Hier ist Rot aber schon die Aussage — nicht schießen.
    if (mode.isManual) {
      return TimerState(
        remainingTime: Duration.zero,
        phase: TimerPhase.preparation,
        mode: mode,
        preparationTime: Duration.zero,
        mainTime: Duration.zero,
      );
    }

    final settings = ref.read(settingsProvider);

    // Der Wechselmodus teilt sich die Vorbereitungszeit mit dem custom-Modus:
    // sie ist dieselbe Ansage an denselben Schützen, und eine zweite
    // Einstellung für denselben Wert wäre nur eine Stelle mehr, an der er
    // falsch stehen kann. Die Schusszeit bleibt die 20s des Modus.
    final prepTime =
        mode == TimerMode.custom || mode.isAlternating
            ? settings.customPrepTime
            : mode.defaultPrepTime;
    final mainTime =
        mode == TimerMode.custom
            ? settings.customMainTime
            : mode.defaultMainTime;

    return TimerState(
      remainingTime: prepTime + mainTime,
      phase: TimerPhase.idle,
      mode: mode,
      preparationTime: prepTime,
      mainTime: mainTime,
      warningThreshold: mode.defaultWarningThreshold,
      arrowsPerArcher: mode.isAlternating ? settings.alternatingArrows : 1,
    );
  }

  /// Schaltet das handgesteuerte Signal zwischen Rot und Grün um.
  ///
  /// Bewusst ohne [_startTicking]: mit Null-Dauern würde [_scheduleNextStep]
  /// sofort synchron in [_handlePhaseTransition] laufen und die Runde in einem
  /// einzigen Aufruf bis `ended` durchreichen. Hier wird nie ein Timer
  /// armiert — die Phase ist der ganze Zustand.
  void _toggleSignal() {
    state = state.copyWith(
      phase:
          state.phase == TimerPhase.active
              ? TimerPhase.preparation
              : TimerPhase.active,
    );
  }

  void _startPreparationPhase() {
    state = state.copyWith(
      phase: TimerPhase.preparation,
      remainingTime: state.preparationTime,
      isRunning: true,
      isPaused: false,
    );
    startTicking(state.remainingTime);
  }

  void _startMainPhase({DateTime? anchor}) {
    state = state.copyWith(
      phase: TimerPhase.active,
      remainingTime: state.mainTime,
    );
    startTicking(state.remainingTime, anchor: anchor);
  }

  /// Gibt die Schusszeit an den nächsten Schützen weiter.
  ///
  /// Bewusst ohne neue Vorbereitungszeit: im Duell läuft der Wechsel durch,
  /// B steht schon am Schießbalken. Nach B ist der Pfeil durch und A beginnt
  /// mit dem nächsten.
  ///
  /// [anchor] wird durchgereicht, weil hier bis zu sechs Passagen aneinander
  /// hängen — ohne die Verankerung am geplanten Ende würde sich die
  /// Verspätung jedes Callbacks über die ganze Passe aufaddieren.
  void _startNextPassage({DateTime? anchor}) {
    final wasSecond = state.currentArcher == Archer.b;

    state = state.copyWith(
      currentArcher: state.currentArcher.other,
      currentArrow: wasSecond ? state.currentArrow + 1 : state.currentArrow,
    );
    _startMainPhase(anchor: anchor);
  }

  void _endTimer() {
    stopTicking();
    state = state.copyWith(
      phase: TimerPhase.ended,
      isRunning: false,
      remainingTime: Duration.zero,
    );
  }

  void _resumeTimer() {
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
        _startMainPhase(anchor: anchor);
        break;
      case TimerPhase.active:
        if (state.hasNextPassage) {
          _startNextPassage(anchor: anchor);
        } else {
          _endTimer();
        }
        break;
      default:
        _endTimer();
    }
  }
}

// ===== PROVIDER DEFINITIONEN (in derselben Datei) =====

// Haupt-Provider
final timerProvider = NotifierProvider<TimerNotifier, TimerState>(
  () => TimerNotifier(),
);

// Convenience Provider (abgeleitet vom Haupt-Provider)
final currentPhaseProvider = Provider<TimerPhase>((ref) {
  return ref.watch(timerProvider).phase;
});

final remainingTimeProvider = Provider<Duration>((ref) {
  final timerState = ref.watch(timerProvider);

  if (timerState.phase == TimerPhase.idle) {
    return timerState.mainTime;
  }

  return timerState.remainingTime;
});

final isTimerRunningProvider = Provider<bool>((ref) {
  return ref.watch(timerProvider).isRunning;
});

final isInWarningProvider = Provider<bool>((ref) {
  return ref.watch(timerProvider).isInWarningPeriod;
});

/// Ob der aktive Modus von Hand geschaltet wird (Ampel) — dann gibt es keine
/// Uhr anzuzeigen.
final isManualModeProvider = Provider<bool>((ref) {
  return ref.watch(timerProvider).mode.isManual;
});
