import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timer_state.dart';

// Business Logic Klasse
class TimerNotifier extends StateNotifier<TimerState> {
  Timer? _timer;

  TimerNotifier() : super(_initialState());

  static TimerState _initialState() {
    const mode = TimerMode.indoor;
    return TimerState(
      remainingTime: mode.defaultPrepTime + mode.defaultMainTime,
      phase: TimerPhase.idle,
      mode: mode,
      preparationTime: mode.defaultPrepTime,
      mainTime: mode.defaultMainTime,
    );
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

  void resetTimer() {
    _timer?.cancel();
    state = _initialState().copyWith(mode: state.mode);
  }

  void skipTimerPhase() {
    if (state.isRunning) {
      _timer?.cancel();
      _handlePhaseTransition();
    }
    
  }

  void setMode(TimerMode mode) {
    resetTimer();
    state = TimerState(
      remainingTime: mode.defaultPrepTime + mode.defaultMainTime,
      phase: TimerPhase.idle,
      mode: mode,
      preparationTime: mode.defaultPrepTime,
      mainTime: mode.defaultMainTime,
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ===== PROVIDER DEFINITIONEN (in derselben Datei) =====

// Haupt-Provider
final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>(
  (ref) => TimerNotifier(),
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
