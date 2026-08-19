/// Welcher Satz Signaltöne gespielt wird.
///
/// Dieselben Signale in zwei Klangbildern, nicht zwei Sätze von Signalen: die
/// Melodie, die Längen und die Bedeutung sind identisch, [tone2] liegt nur eine
/// Quinte höher und hat Obertöne. Deshalb steht hier auch nur der Ordner —
/// welche Datei ein Signal ist, weiß weiterhin `AudioSignal`.
///
/// Erzeugt werden beide Sätze von `tool/generate_signal_sounds.dart`; dort steht
/// auch, warum der hellere draußen weiter trägt.
enum SignalTone {
  /// Reine Sinustöne. Im Tunnel tragen die harten Wände sie mühelos.
  tone1('tone1'),

  /// Höher und mit Obertönen — für draußen, wo es keinen Nachhall gibt und Wind
  /// einen schmalbandigen Ton zudeckt.
  tone2('tone2');

  const SignalTone(this.folder);

  /// Der Unterordner in `assets/sounds/`.
  final String folder;
}
