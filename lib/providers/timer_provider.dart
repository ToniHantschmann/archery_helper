import 'dart:async';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timer_state.dart';

// Business Logic Klasse
class TimerNotifier extends Notifier<TimerState> {
  Timer? _timer;

  @override
  TimerState build() {
    ref.onDispose(() => _timer?.cancel());

    ref.listen(settingsProvider, (previous, next) {
      // Nur reagieren wenn custom Zeiten sich geändert haben und custom Modus aktiv ist
      if (state.mode == TimerMode.custom &&
          (previous?.customPrepTime != next.customPrepTime ||
              previous?.customMainTime != next.customMainTime)) {
        _timer?.cancel();
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
    state = state.copyWith(isPaused: true, isRunning: false);
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
      _timer?.cancel();
      _handlePhaseTransition();
    }
  }

  void setMode(TimerMode mode) {
    _timer?.cancel();
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
    _timer?.cancel();
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

  void _startTicking() {
    _timer?.cancel();
    // do one iteration of timer with one second duration
    _timer = Timer(const Duration(seconds: 1), () {
      final newTime = Duration(
        milliseconds: state.remainingTime.inMilliseconds - 100,
      );

      if (newTime.inMilliseconds <= 0) {
        _handlePhaseTransition();
      } else {
        state = state.copyWith(remainingTime: newTime);

        // now start periodic timer with 100ms intervall
        // enables us to show milliseconds in the timer
        _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          final newTime = Duration(
            milliseconds: state.remainingTime.inMilliseconds - 100,
          );

          if (newTime.inMilliseconds <= 0) {
            _handlePhaseTransition();
          } else {
            state = state.copyWith(remainingTime: newTime);
          }
        });
      }
    });
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
