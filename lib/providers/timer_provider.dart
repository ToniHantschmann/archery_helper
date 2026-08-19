import 'package:archery_helper/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/audio/audio_signal.dart';
import '../models/timer_state.dart';
import 'phase_clock.dart';
import 'sound_provider.dart';

// Business Logic Klasse
class TimerNotifier extends Notifier<TimerState> with PhaseClock<TimerState> {
  @override
  Duration get storedRemaining => state.remainingTime;

  /// Die letzte Sekunde, die auf dem Schirm gestanden hat.
  ///
  /// Gebraucht für das Ticken der letzten Sekunden: [onRemainingChanged] kommt
  /// im Millisekundenmodus zehnmal pro Sekunde, der Tick soll aber einmal pro
  /// Sekunde fallen. `null`, solange keine Zahl gestanden hat.
  int? _lastShownSecond;

  /// Die letzten Sekunden, in denen die Trainingsampel vorwarnt.
  ///
  /// Nur sie: im Wettkampf ist die Warnung nach WA-Regel rein optisch (gelb in
  /// den letzten 30 Sekunden, ohne Ton), und daran soll das Training nichts
  /// anderes gewöhnen.
  static const _warningTicks = 3;

  void _playSignal(AudioSignal signal) =>
      ref.read(signalSoundsProvider).play(signal);

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
    final toGreen = state.phase != TimerPhase.active;

    state = state.copyWith(
      phase: toGreen ? TimerPhase.active : TimerPhase.preparation,
    );
    // Auch von Hand geschaltet geht ein Signal an die Linie: dass keine Uhr
    // läuft, ändert nichts an der Aussage.
    _playSignal(toGreen ? AudioSignal.start : AudioSignal.stop);
  }

  void _startPreparationPhase() {
    state = state.copyWith(
      phase: TimerPhase.preparation,
      remainingTime: state.preparationTime,
      isRunning: true,
      isPaused: false,
    );
    _playSignal(AudioSignal.toTheLine);
    startTicking(state.remainingTime);
  }

  void _startMainPhase({DateTime? anchor}) {
    state = state.copyWith(
      phase: TimerPhase.active,
      remainingTime: state.mainTime,
    );
    _lastShownSecond = null;
    _playSignal(AudioSignal.start);
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
    _playSignal(AudioSignal.stop);
  }

  void _resumeTimer() {
    state = state.copyWith(isRunning: true, isPaused: false);
    startTicking(state.remainingTime);
  }

  @override
  void onRemainingChanged(Duration remaining) {
    state = state.copyWith(remainingTime: remaining);

    // Genau die Rundung aus [TimerTexts.formatTime]: der Tick soll in dem
    // Moment fallen, in dem die Zahl auf dem Schirm umspringt, und nicht
    // daneben. Der Vergleich mit der zuletzt gezeigten Sekunde ist nötig, weil
    // dieser Haken im Millisekundenmodus zehnmal pro Sekunde kommt.
    final shown = (remaining.inMilliseconds / 1000).ceil();
    if (shown == _lastShownSecond) return;
    _lastShownSecond = shown;

    // Kein Ton bei 0 — dort läuft [onPhaseElapsed], und die 0 ist schon der
    // Schlusston beziehungsweise die Übergabe an den nächsten Schützen.
    final isTicking = shown >= 1 && shown <= _warningTicks;
    if (state.phase == TimerPhase.active && isTicking) {
      _playSignal(AudioSignal.warningTick);
    }
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
