/// Die Signaltöne, die die App kennt — das Tonvokabular beider Uhren.
///
/// Absichtlich nach ihrer *Bedeutung* benannt und nicht nach ihrem Klang: die
/// Ampel und der Wettkampf sagen dasselbe mit demselben Ton, und ein Signal,
/// das später anders klingen soll, ist dann ein Dateitausch und keine Änderung
/// an den Uhren.
///
/// Die Mehrfachtöne stecken in der Datei, nicht in einer Wiederholung zur
/// Laufzeit (siehe `tool/generate_signal_sounds.dart`).
enum AudioSignal {
  /// Zwei Töne: die Gruppe darf an die Schießlinie treten, die
  /// Vorbereitungszeit läuft. Im Wettkampf gleichzeitig das Stoppsignal für die
  /// vorige Gruppe — deshalb steht am Gruppenwechsel kein eigener Schlusston.
  toTheLine('to_the_line.wav'),

  /// Ein Ton: die Schusszeit beginnt, das Signal geht auf Grün.
  start('start.wav'),

  /// Kurzer Tick der letzten Sekunden — nur die Trainingsampel, denn nach WA
  /// ist die Warnung im Wettkampf rein optisch.
  warningTick('warning_tick.wav'),

  /// Langer Ton: Schluss. Ende einer Ampel-Passe und Rot in der Hand-Ampel.
  stop('stop.wav'),

  /// Drei Töne: Pfeile holen. Ende einer Passe im Wettkampf.
  collect('collect.wav');

  const AudioSignal(this.fileName);

  /// Der Dateiname in `assets/sounds/`. Wie der Pfad daraus wird, weiß nur
  /// `sound_player.dart` — dort hängt es an der Konvention von `audioplayers`.
  final String fileName;
}
