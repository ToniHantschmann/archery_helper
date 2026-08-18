import 'timer_state.dart';

/// Alles, was die Optik des Signals bestimmt — und nichts weiter.
///
/// Ampel und Wettkampf haben verschiedene Zustände (Modi und Pfeile hier,
/// Passen und Gruppen dort), sehen aber gleich aus: rot heißt nicht schießen,
/// grün heißt schießen, gelb heißt gleich ist Schluss. Damit diese Regel *eine*
/// Stelle bleibt (`TimerTheme`), reichen beide Zustände dieses kleine Objekt
/// dorthin — statt dass das Theme zwei Zustandsklassen kennen müsste.
///
/// Mit Wertgleichheit, weil die Theme-Provider daran hängen: ein Objekt, das
/// sich im Sekundentakt für „ungleich" hält, würde den getönten Schirm
/// sekündlich neu zeichnen lassen.
class SignalState {
  final TimerPhase phase;

  /// Ob die Restzeit als knapp gilt (Gelb).
  final bool isWarning;

  final bool isPaused;

  /// Ob das Signal von Hand geschaltet wird — dann läuft keine Uhr.
  final bool isManual;

  const SignalState({
    required this.phase,
    this.isWarning = false,
    this.isPaused = false,
    this.isManual = false,
  });

  @override
  bool operator ==(Object other) =>
      other is SignalState &&
      other.phase == phase &&
      other.isWarning == isWarning &&
      other.isPaused == isPaused &&
      other.isManual == isManual;

  @override
  int get hashCode => Object.hash(phase, isWarning, isPaused, isManual);
}
