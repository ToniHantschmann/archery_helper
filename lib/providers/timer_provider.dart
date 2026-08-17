import 'dart:async';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timer_state.dart';

// Business Logic Klasse
class TimerNotifier extends Notifier<TimerState> {
  Timer? _timer;

  /// When the running phase ends, on the wall clock.
  ///
  /// The remaining time is always derived from this instead of being counted
  /// down step by step. A Timer is only a request: if the platform delivers a
  /// callback late — or drops it, which is what a busy or backgrounded browser
  /// tab does — then subtracting a fixed amount per callback makes the
  /// countdown lag behind real time, and a shot clock that runs slow is a shot
  /// clock that is wrong.
  ///
  /// `null` whenever nothing is ticking (idle, paused, ended).
  DateTime? _phaseEnd;

  /// The grid the shown number changes on: whole seconds, or tenths while the
  /// settings ask for milliseconds. The countdown is scheduled onto this grid
  /// (see [_scheduleNextStep]), so it is the update rate as well.
  Duration get _displayStep =>
      ref.read(settingsProvider).showMilliseconds
          ? const Duration(milliseconds: 100)
          : const Duration(seconds: 1);

  @override
  TimerState build() {
    ref.onDispose(() => _timer?.cancel());

    ref.listen(settingsProvider, (previous, next) {
      // Nur reagieren wenn custom Zeiten sich geändert haben und custom Modus aktiv ist
      if (state.mode == TimerMode.custom &&
          (previous?.customPrepTime != next.customPrepTime ||
              previous?.customMainTime != next.customMainTime)) {
        _stopTicking();
        state = _stateForMode(TimerMode.custom);
        return;
      }

      // Das Anzeigeraster hängt an showMilliseconds. Wird es umgeschaltet
      // während der Countdown läuft, muss sofort auf dem neuen Raster neu
      // armiert werden — sonst käme das nächste Update erst zur alten Kante.
      if (previous?.showMilliseconds != next.showMilliseconds &&
          _phaseEnd != null) {
        _onStep();
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

    _timer?.cancel();
    // Freeze on the clock-derived value, not on the last tick: pausing between
    // two callbacks would otherwise hand back up to 100ms of shooting time.
    final remaining = _remaining();
    _phaseEnd = null;
    state = state.copyWith(
      remainingTime: remaining,
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
      _stopTicking();
      _handlePhaseTransition();
    }
  }

  void setMode(TimerMode mode) {
    _stopTicking();
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
    final prepTime =
        mode == TimerMode.custom
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
    _startTicking();
  }

  void _startMainPhase({DateTime? anchor}) {
    state = state.copyWith(
      phase: TimerPhase.active,
      remainingTime: state.mainTime,
    );
    _startTicking(anchor: anchor);
  }

  void _endTimer() {
    _stopTicking();
    state = state.copyWith(
      phase: TimerPhase.ended,
      isRunning: false,
      remainingTime: Duration.zero,
    );
  }

  void _resumeTimer() {
    state = state.copyWith(isRunning: true, isPaused: false);
    _startTicking();
  }

  /// Anchors the phase on the wall clock and arms the first update.
  ///
  /// [anchor] is the moment the phase conceptually starts. It is only passed
  /// when one phase follows another on its own: the callback that ends the
  /// preparation can arrive a few milliseconds late, and anchoring the main
  /// phase on the planned end instead of on "now" keeps that lateness from
  /// being added to the round. A skipped phase has no such anchor — there
  /// "now" is exactly right.
  void _startTicking({DateTime? anchor}) {
    _phaseEnd = (anchor ?? clock.now()).add(state.remainingTime);
    _scheduleNextStep(_remaining());
  }

  /// Arms a single timer for the exact moment the shown number changes.
  ///
  /// The countdown used to poll on a fixed 100ms grid and round the measured
  /// remainder onto the same grid — which is where the display changes too.
  /// A callback that arrived a few milliseconds late therefore rounded a whole
  /// step too far down and flipped the second early, leaving the next one on
  /// screen too long. Waiting for the boundary itself cannot make that error:
  /// a timer never fires *before* its deadline. And because the delay is
  /// recomputed from [_phaseEnd] at every step, lateness never accumulates.
  void _scheduleNextStep(Duration remaining) {
    _timer?.cancel();

    if (remaining <= Duration.zero) {
      _handlePhaseTransition();
      return;
    }

    // The delay is always within (0, step] and never longer than [remaining],
    // so the timer cannot overshoot the end of the phase: once less than one
    // step is left it fires exactly on [_phaseEnd]. The phase therefore still
    // lasts exactly as long as it is configured for.
    final step = _displayStep;
    final steps = (remaining.inMicroseconds / step.inMicroseconds).ceil();
    _timer = Timer(remaining - step * (steps - 1), _onStep);
  }

  void _onStep() {
    final remaining = _remaining();

    if (remaining <= Duration.zero) {
      _handlePhaseTransition(anchor: _phaseEnd);
      return;
    }

    state = state.copyWith(remainingTime: remaining);
    _scheduleNextStep(remaining);
  }

  void _stopTicking() {
    _timer?.cancel();
    _phaseEnd = null;
  }

  /// Time left in the running phase, straight off the clock.
  ///
  /// Deliberately not quantised: the update is already scheduled onto the
  /// display grid, and rounding the measured value onto that same grid is what
  /// used to let a late callback jump a step early. Falls back to the stored
  /// value when nothing is running.
  Duration _remaining() {
    final end = _phaseEnd;
    if (end == null) return state.remainingTime;

    final left = end.difference(clock.now());
    return left <= Duration.zero ? Duration.zero : left;
  }

  void _handlePhaseTransition({DateTime? anchor}) {
    switch (state.phase) {
      case TimerPhase.preparation:
        _startMainPhase(anchor: anchor);
        break;
      case TimerPhase.active:
        _endTimer();
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
