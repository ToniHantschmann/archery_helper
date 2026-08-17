enum TimerPhase {
  idle,
  preparation,
  active,
  ended;

  bool get isRunningPhase => this == preparation || this == active;
  bool get isFinishedPhase => this == ended;
}

enum TimerMode {
  indoor,
  outdoor,
  custom,
  alternating,
  trafficLight;

  Duration get defaultPrepTime {
    switch (this) {
      case trafficLight:
        return Duration.zero;
      default:
        return Duration(seconds: 10);
    }
  }

  Duration get defaultMainTime {
    switch (this) {
      case indoor:
        return const Duration(seconds: 120);
      case outdoor:
        return const Duration(seconds: 240);
      case custom:
        return const Duration(seconds: 120);
      case alternating:
        return const Duration(seconds: 20);
      case trafficLight:
        return Duration.zero;
    }
  }

  /// Modi ohne Countdown: das Signal wird von Hand geschaltet.
  ///
  /// Die Null-Dauern oben sind deshalb keine Konfiguration, sondern der
  /// Hinweis, dass hier nie eine Uhr läuft — [TimerNotifier] darf in diesem
  /// Fall gar nicht erst mit dem Ticken anfangen.
  bool get isManual => this == trafficLight;
}

class TimerState {
  final Duration remainingTime;
  final TimerPhase phase;
  final TimerMode mode;
  final bool isRunning;
  final bool isPaused;
  final Duration preparationTime;
  final Duration mainTime;
  final Duration warningThreshold;

  const TimerState({
    required this.remainingTime,
    required this.phase,
    required this.mode,
    this.isRunning = false,
    this.isPaused = false,
    required this.preparationTime,
    required this.mainTime,
    this.warningThreshold = const Duration(seconds: 30),
  });

  // Ohne den Modus-Ausschluss wäre die Warnung im Ampel-Modus dauerhaft aktiv:
  // dort ist die Restzeit immer null und damit trivialerweise unter der
  // Schwelle — die grüne Phase käme in Gelb heraus.
  bool get isInWarningPeriod =>
      phase == TimerPhase.active &&
      !mode.isManual &&
      remainingTime <= warningThreshold;

  bool get canStart => phase == TimerPhase.idle;
  bool get canPause => isRunning && !isPaused;
  bool get canResume => isPaused;
  bool get canReset => phase != TimerPhase.idle;
  bool get isFinished => phase == TimerPhase.ended;

  TimerState copyWith({
    Duration? remainingTime,
    TimerPhase? phase,
    TimerMode? mode,
    bool? isRunning,
    bool? isPaused,
    Duration? totalTime,
    Duration? preparationTime,
    Duration? mainTime,
    Duration? warningThreshold,
  }) {
    return TimerState(
      remainingTime: remainingTime ?? this.remainingTime,
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      preparationTime: preparationTime ?? this.preparationTime,
      mainTime: mainTime ?? this.mainTime,
      warningThreshold: warningThreshold ?? this.warningThreshold,
    );
  }
}
