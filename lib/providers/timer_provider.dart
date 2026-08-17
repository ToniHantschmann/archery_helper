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
  /// down tick by tick. A periodic Timer is only a request: if the platform
  /// delivers a callback late — or drops it, which is what a busy or
  /// backgrounded browser tab does — then subtracting a fixed 100ms per
  /// callback makes the countdown lag behind real time, and a shot clock that
  /// runs slow is a shot clock that is wrong.
  ///
  /// `null` whenever nothing is ticking (idle, paused, ended).
  DateTime? _phaseEnd;

  /// Resolution of the countdown. Fine enough for the tenths the display can
  /// show; the value shown is quantised to the same step so a late callback
  /// cannot produce a jittery number.
  static const Duration _tick = Duration(milliseconds: 100);

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
      }
    });

    final settings = ref.read(settingsProvider);
    return _stateForMode(settings.defaultMode);
  }

  void startTimer() {
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
    if (state.canStart || state.isPaused) {
      startTimer();
    } else if (state.isRunning) {
      pauseTimer();
    }
  }

  /// Context-sensitive "one step further": start, skip the running phase, or
  /// reset once finished. Distinct from [toggle], which never skips or resets.
  void advance() {
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

  void _startPreparationPhase() {
    state = state.copyWith(
      phase: TimerPhase.preparation,
      remainingTime: state.preparationTime,
      isRunning: true,
      isPaused: false,
    );
    _startTicking();
  }

  void _startMainPhase() {
    state = state.copyWith(
      phase: TimerPhase.active,
      remainingTime: state.mainTime,
    );
    _startTicking();
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

  /// Ticks at 100ms so the display can show tenths of a second. That the
  /// starting value stays readable for a full second is handled by
  /// [TimerTexts.formatTime], which rounds up — the countdown itself runs
  /// exactly as long as the phase is configured for.
  ///
  /// Each callback only *reads* the clock (see [_phaseEnd]), so a skipped or
  /// delayed callback costs a display update, never countdown time.
  void _startTicking() {
    _timer?.cancel();
    _phaseEnd = clock.now().add(state.remainingTime);
    _timer = Timer.periodic(_tick, (timer) {
      final remaining = _remaining();

      if (remaining <= Duration.zero) {
        _handlePhaseTransition();
      } else {
        state = state.copyWith(remainingTime: remaining);
      }
    });
  }

  void _stopTicking() {
    _timer?.cancel();
    _phaseEnd = null;
  }

  /// Time left in the running phase, quantised to whole [_tick] steps.
  ///
  /// Quantising keeps the displayed tenths stable: without it a callback that
  /// arrives 7ms late would show 9.9 twice or skip a tenth. Falls back to the
  /// stored value when nothing is running.
  Duration _remaining() {
    final end = _phaseEnd;
    if (end == null) return state.remainingTime;

    final left = end.difference(clock.now());
    if (left <= Duration.zero) return Duration.zero;

    final steps = (left.inMicroseconds / _tick.inMicroseconds).round();
    return _tick * steps;
  }

  void _handlePhaseTransition() {
    switch (state.phase) {
      case TimerPhase.preparation:
        _startMainPhase();
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
