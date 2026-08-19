// Erzeugt die Signaltöne in `assets/sounds/` — aufzurufen mit
// `dart run tool/generate_signal_sounds.dart`.
//
// Warum synthetisch und nicht aufgenommen: ein Signalton muss laut, kurz und
// über einer Halle voller Nebengeräusche eindeutig sein, und genau das lässt
// sich am Sinus exakt einstellen. Nebenbei hat die Datei keine Lizenz und keine
// Herkunft, um die sich jemand kümmern müsste. Die erzeugten WAVs sind
// eingecheckt, damit ein frischer Clone ohne diesen Lauf baut — dieses Skript
// ist die Quelle, falls sie einmal anders klingen sollen.
//
// Die Mehrfachsignale (zweimal, dreimal) sind *eine* Datei mit Pausen darin und
// nicht mehrere Wiedergaben hintereinander. Zur Laufzeit aneinandergehängt
// bräuchte es eine zweite Timer-Kette neben `PhaseClock`, die sich mit dem
// 3-2-1-Ticken verschränken könnte; in der Datei ist der Abstand exakt und
// kostet keine Zeile Programm.
//
// Es gibt jeden Ton zweimal, in `tone1/` und `tone2/` — im Tunnel und auf dem
// Freifeld hört sich derselbe Ton nicht gleich gut. Drinnen tragen die harten
// Wände den reinen Sinus; draußen gibt es keinen Nachhall, dafür Wind und
// Nebengeräusche, und ein Sinus legt seine ganze Energie auf eine einzige
// schmale Frequenz, die sich leicht zudecken lässt. `tone2` liegt deshalb eine
// Quinte höher — gleiche Intervalle, gleiche Längen, also derselbe Ton, nur
// höher — und bekommt zusätzlich Obertöne. Die sind der eigentliche Hebel: sie
// ändern die Tonhöhe nicht, legen aber Energie in den Bereich um 2 bis 4 kHz,
// in dem das Gehör am empfindlichsten ist.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sampleRate = 44100;

/// Kopf für den Hallenverstärker: nicht bis an die Vollaussteuerung, damit ein
/// aufgedrehter Kanal den Ton nicht verzerrt.
const _amplitude = 0.85;

/// An- und Ausschwingen jedes Tons. Ohne diese wenigen Millisekunden beginnt
/// und endet der Sinus an einem Sprung, und das knackt hörbar.
const _fade = Duration(milliseconds: 8);

/// Ein Klangbild: wie die Tabelle unten transponiert wird und aus welchen
/// Teiltönen jeder einzelne Ton besteht.
///
/// [harmonics] sind die Amplituden der Teiltöne, beginnend beim Grundton:
/// `[1.0]` ist der reine Sinus, `[1.0, 0.4, 0.2]` nimmt die doppelte und die
/// dreifache Frequenz leiser dazu.
class _Voice {
  const _Voice({
    required this.folder,
    required this.transpose,
    required this.harmonics,
  });

  /// Der Unterordner in `assets/sounds/` — derselbe Name wie in `SignalTone`.
  final String folder;

  final double transpose;
  final List<double> harmonics;
}

/// Ton 1 ist der Satz für den Tunnel, Ton 2 der fürs Freifeld (siehe oben).
const _voices = <_Voice>[
  _Voice(folder: 'tone1', transpose: 1.0, harmonics: [1.0]),
  _Voice(folder: 'tone2', transpose: 1.5, harmonics: [1.0, 0.4, 0.2]),
];

/// Ein Stück Klang: ein Ton mit [hertz], oder eine Pause wenn [hertz] `null`
/// ist.
class _Segment {
  const _Segment.tone(this.hertz, int ms) : millis = ms;
  const _Segment.silence(int ms) : hertz = null, millis = ms;

  final double? hertz;
  final int millis;
}

/// Die Töne, die die App kennt — dieselben Namen wie `AudioSignal`.
///
/// 880 Hz (a'') ist die Ansage, 1320 Hz der spitze Tick darüber, 587 Hz (d'')
/// der tiefere Schlussstrich: fallende Tonhöhe hört man auch ohne Hinsehen als
/// "vorbei".
///
/// Die Tabelle beschreibt Melodie und Rhythmus, nicht den Klang: sie gilt für
/// beide Sätze, jeder [_Voice] transponiert sie geschlossen.
const _signals = <String, List<_Segment>>{
  'to_the_line': [
    _Segment.tone(880, 150),
    _Segment.silence(200),
    _Segment.tone(880, 150),
  ],
  'start': [_Segment.tone(880, 400)],
  'warning_tick': [_Segment.tone(1320, 80)],
  'stop': [_Segment.tone(587, 900)],
  'collect': [
    _Segment.tone(880, 150),
    _Segment.silence(200),
    _Segment.tone(880, 150),
    _Segment.silence(200),
    _Segment.tone(880, 150),
  ],
};

void main() {
  for (final voice in _voices) {
    final directory = Directory('assets/sounds/${voice.folder}');
    directory.createSync(recursive: true);

    for (final entry in _signals.entries) {
      final file = File('${directory.path}/${entry.key}.wav');
      file.writeAsBytesSync(_wav(_render(entry.value, voice)));
      stdout.writeln('${file.path} (${file.lengthSync()} Bytes)');
    }
  }
}

/// Rechnet die Segmente in Samples zwischen -1 und 1 um.
List<double> _render(List<_Segment> segments, _Voice voice) {
  // Durch die Summe der Teiltöne teilen, bevor [_amplitude] wirkt: im
  // schlimmsten Fall stehen alle Teiltöne gleichzeitig am Maximum, und ein
  // Überlauf käme als Knacken zurück statt als lauterer Ton. Der Gewinn von
  // Ton 2 liegt ohnehin nicht im Pegel, sondern in der Frequenzlage.
  final norm = voice.harmonics.reduce((a, b) => a + b);
  final samples = <double>[];

  for (final segment in segments) {
    final count = _sampleRate * segment.millis ~/ 1000;
    final hertz = segment.hertz;

    if (hertz == null) {
      samples.addAll(List.filled(count, 0));
      continue;
    }

    final fade = math.min(
      _sampleRate * _fade.inMilliseconds ~/ 1000,
      count ~/ 2,
    );
    for (var i = 0; i < count; i++) {
      // Die Hüllkurve gilt pro Ton, nicht pro Datei: bei zwei Tönen mit Pause
      // dazwischen muss jeder einzelne sauber an- und ausschwingen.
      final envelope = fade == 0
          ? 1.0
          : math.min(1.0, math.min(i / fade, (count - 1 - i) / fade));

      var wave = 0.0;
      for (var harmonic = 0; harmonic < voice.harmonics.length; harmonic++) {
        final frequency = hertz * voice.transpose * (harmonic + 1);
        wave +=
            voice.harmonics[harmonic] *
            math.sin(2 * math.pi * frequency * i / _sampleRate);
      }

      samples.add(_amplitude * envelope * wave / norm);
    }
  }

  return samples;
}

/// Packt die Samples als 16-bit-PCM-Mono-WAV.
Uint8List _wav(List<double> samples) {
  const bitsPerSample = 16;
  const channels = 1;
  final dataBytes = samples.length * 2;

  final bytes = ByteData(44 + dataBytes);
  var offset = 0;

  void ascii(String value) {
    for (final code in value.codeUnits) {
      bytes.setUint8(offset++, code);
    }
  }

  void uint32(int value) {
    bytes.setUint32(offset, value, Endian.little);
    offset += 4;
  }

  void uint16(int value) {
    bytes.setUint16(offset, value, Endian.little);
    offset += 2;
  }

  ascii('RIFF');
  uint32(36 + dataBytes);
  ascii('WAVE');
  ascii('fmt ');
  uint32(16); // Länge des fmt-Blocks
  uint16(1); // PCM, unkomprimiert
  uint16(channels);
  uint32(_sampleRate);
  uint32(_sampleRate * channels * bitsPerSample ~/ 8); // Bytes pro Sekunde
  uint16(channels * bitsPerSample ~/ 8); // Bytes pro Sample-Block
  uint16(bitsPerSample);
  ascii('data');
  uint32(dataBytes);

  for (final sample in samples) {
    // Auf den darstellbaren Bereich begrenzen, bevor gerundet wird: ein
    // Überlauf würde als Knacken zurückkommen, nicht als lauterer Ton.
    final value = (sample * 32767).round().clamp(-32768, 32767);
    bytes.setInt16(offset, value, Endian.little);
    offset += 2;
  }

  return bytes.buffer.asUint8List();
}
