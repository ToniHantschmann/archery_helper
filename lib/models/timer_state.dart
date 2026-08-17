enum TimerPhase {
  idle,
  preparation,
  active,
  ended;

  bool get isRunningPhase => this == preparation || this == active;
  bool get isFinishedPhase => this == ended;
}

/// Die beiden Schützen eines Wechsel-Duells.
enum Archer {
  a,
  b;

  Archer get other => this == a ? b : a;

  /// Kurzform für die Anzeige. Bewusst sprachneutral — A und B heißen in jeder
  /// Sprache gleich.
  String get letter => this == a ? 'A' : 'B';
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

  /// Ob der Modus zwischen zwei Schützen hin- und herwechselt.
  bool get isAlternating => this == alternating;

  /// Ab wann die Restzeit als knapp gilt (Gelb).
  ///
  /// Die 30s der langen Modi wären bei 20s Schusszeit von der ersten Sekunde
  /// an erfüllt — der Wechselmodus wäre also durchgehend gelb und hätte gar
  /// kein Grün mehr.
  Duration get defaultWarningThreshold {
    switch (this) {
      case trafficLight:
        return Duration.zero;
      case alternating:
        return const Duration(seconds: 5);
      default:
        return const Duration(seconds: 30);
    }
  }
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

  /// Wer gerade schießt. Nur im Wechselmodus von Bedeutung; sonst steht das
  /// Feld auf [Archer.a] und wird nirgends gelesen.
  final Archer currentArcher;

  /// Der wievielte Pfeil gerade geschossen wird, ab 1 gezählt.
  final int currentArrow;

  /// Wie viele Pfeile jeder Schütze in dieser Passe hat — aus den
  /// Einstellungen, siehe `Settings.alternatingArrows`.
  final int arrowsPerArcher;

  const TimerState({
    required this.remainingTime,
    required this.phase,
    required this.mode,
    this.isRunning = false,
    this.isPaused = false,
    required this.preparationTime,
    required this.mainTime,
    this.warningThreshold = const Duration(seconds: 30),
    this.currentArcher = Archer.a,
    this.currentArrow = 1,
    this.arrowsPerArcher = 1,
  });

  // Ohne den Modus-Ausschluss wäre die Warnung im Ampel-Modus dauerhaft aktiv:
  // dort ist die Restzeit immer null und damit trivialerweise unter der
  // Schwelle — die grüne Phase käme in Gelb heraus.
  bool get isInWarningPeriod =>
      phase == TimerPhase.active &&
      !mode.isManual &&
      remainingTime <= warningThreshold;

  /// Ob nach der laufenden Passage noch eine folgt.
  ///
  /// Die einzige Stelle, die die Reihenfolge kennt: A und B schießen denselben
  /// Pfeil nacheinander, danach beginnt A mit dem nächsten. Nach dem letzten
  /// Pfeil von B ist die Passe zu Ende.
  bool get hasNextPassage =>
      mode.isAlternating &&
      (currentArcher == Archer.a || currentArrow < arrowsPerArcher);

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
    Duration? preparationTime,
    Duration? mainTime,
    Duration? warningThreshold,
    Archer? currentArcher,
    int? currentArrow,
    int? arrowsPerArcher,
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
      currentArcher: currentArcher ?? this.currentArcher,
      currentArrow: currentArrow ?? this.currentArrow,
      arrowsPerArcher: arrowsPerArcher ?? this.arrowsPerArcher,
    );
  }
}
