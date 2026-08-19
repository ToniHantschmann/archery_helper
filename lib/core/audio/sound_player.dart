import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'audio_signal.dart';
import 'signal_tone.dart';

/// Spielt einen [AudioSignal] ab — die Schnittstelle, die der Rest der App
/// kennt.
///
/// Abstrakt, weil sie im Test durch eine mitschreibende Attrappe ersetzt wird:
/// prüfbar ist die *Folge* der Signale, nicht der Ton. Ob überhaupt getönt
/// werden darf, entscheidet hier niemand — das ist `SignalSounds` in
/// `lib/providers/sound_provider.dart`.
abstract class SoundPlayer {
  Future<void> play(AudioSignal signal, double volume, SignalTone tone);

  /// Hält die Signale in [tone] bereit, damit der erste Ton nicht der
  /// langsamste ist — und nur die: was von einer anderen Klangvariante noch
  /// geladen ist, wird dabei freigegeben.
  ///
  /// Welche Variante gilt, weiß hier weiterhin niemand; sie wird gesagt (von
  /// `main.dart`, das den Einstellungen zuhört).
  ///
  /// Standardmäßig nichts zu tun: Vorladen ist eine Beschleunigung, die diese
  /// Schnittstelle erlaubt und nicht verlangt — eine Attrappe im Test hat
  /// nichts zu laden.
  Future<void> preload(SignalTone tone) async {}

  Future<void> dispose();
}

/// Die einzige Stelle, die `audioplayers` kennt — wie
/// `lib/core/window/window_service.dart` für das Fenster.
class AudioPlayersSoundPlayer extends SoundPlayer {
  /// Ein eigener Player pro Signal *und* Klangvariante, einmal vorbereitet und
  /// behalten.
  ///
  /// Ein gemeinsamer Player müsste bei jedem Ton die Quelle wechseln, und genau
  /// das Nachladen ist die Verzögerung, die man nicht haben will: ein
  /// Startsignal, das 300ms nach dem Grün kommt, ist ein falsches Startsignal.
  /// Aus demselben Grund ist die Variante Teil des Schlüssels und nicht eine
  /// Quelle, die beim Umschalten gewechselt wird.
  ///
  /// Gemerkt wird der *Future*, nicht der fertige Player: [preload] und ein
  /// früher Ton laufen sonst nebeneinander in `_prepare` und legen zwei Player
  /// mit derselben `playerId` an.
  final _players = <(SignalTone, AudioSignal), Future<AudioPlayer>>{};

  /// Die Umbauten am Bestand laufen hintereinander.
  ///
  /// Zweimal schnell umgeschaltet gäbe es sonst zwei Durchläufe gleichzeitig,
  /// von denen der eine freigibt, worauf der andere gerade wartet.
  Future<void> _swapping = Future.value();

  @override
  Future<void> preload(SignalTone tone) {
    return _swapping = _swapping.then((_) => _keepOnly(tone));
  }

  /// Lässt genau [tone] geladen zurück.
  ///
  /// Warum nicht einfach alles vorhalten: auf Linux ist ein `AudioPlayer` eine
  /// eigene GStreamer-Pipeline mit eigenem Ausgang, und die steht ab dem
  /// Laden — mit allen Varianten stünde die App im Lautstärkemixer mit einer
  /// Zeile pro Datei statt mit einer Handvoll. Ungehört ist das trotzdem, und
  /// die Zahl soll nicht mit jeder weiteren Klangvariante mitwachsen.
  Future<void> _keepOnly(SignalTone tone) async {
    for (final key in _players.keys.toList()) {
      if (key.$1 == tone) continue;
      final pending = _players.remove(key)!;
      try {
        await (await pending).dispose();
      } catch (_) {
        // Ein Player, der sich nicht freigeben lässt, war schon vorher keiner,
        // der noch spielt.
      }
    }

    // Nacheinander und nicht mit `Future.wait`: das sind ein paar kleine
    // Dateien, und der Start soll die Audio-Ausgabe nicht mit allen
    // gleichzeitig begrüßen. Fehler landen im Log, nicht im Aufrufer — wer
    // nicht vorladen kann, kann es beim ersten Ton nochmal versuchen.
    for (final signal in AudioSignal.values) {
      try {
        await _player(signal, tone);
      } catch (error) {
        debugPrint(
          'Signalton ${signal.name} (${tone.folder}) konnte nicht '
          'vorgeladen werden: $error',
        );
      }
    }
  }

  @override
  Future<void> play(AudioSignal signal, double volume, SignalTone tone) async {
    // Ton ist die Zugabe, die Uhr ist die Funktion. Ein fehlendes
    // GStreamer-Plugin oder eine stumme Soundkarte darf im Tunnel niemals den
    // Ablauf der Schusszeit anhalten, deshalb endet hier jeder Fehler.
    //
    // Ohne Rückfrage, ob [signal] überhaupt vorgeladen ist: fällt ein Ton
    // genau zwischen Umschalten und Nachladen, legt `_player` ihn wie jeden
    // anderen an — einmal langsam ist besser als einmal still, und der nächste
    // [preload] räumt ihn wieder weg.
    try {
      final player = await _player(signal, tone);
      await player.setVolume(volume);
      // Zurück an den Anfang statt abzuwarten: die Ticks der letzten Sekunden
      // sollen sich ablösen, nicht anstehen.
      await player.stop();
      await player.resume();
    } catch (error) {
      debugPrint(
        'Signalton ${signal.name} konnte nicht abgespielt werden: $error',
      );
    }
  }

  Future<AudioPlayer> _player(AudioSignal signal, SignalTone tone) async {
    final key = (tone, signal);
    final pending = _players[key] ??= _prepare(signal, tone);
    try {
      return await pending;
    } catch (_) {
      // Ein gescheiterter Versuch darf sich nicht einbrennen: sonst wäre ein
      // Signal, dessen Vorladen beim Start schiefging, für die ganze Laufzeit
      // stumm. Nur den eigenen Versuch wegräumen, nicht einen inzwischen neu
      // begonnenen.
      if (identical(_players[key], pending)) _players.remove(key);
      rethrow;
    }
  }

  Future<AudioPlayer> _prepare(AudioSignal signal, SignalTone tone) async {
    final player = AudioPlayer(
      playerId: 'signal_${tone.folder}_${signal.name}',
    );
    await player.setPlayerMode(PlayerMode.lowLatency);
    // `stop` statt `release`: die Quelle bleibt geladen, sonst wäre jeder
    // zweite Ton wieder ein Ladevorgang.
    await player.setReleaseMode(ReleaseMode.stop);
    // `audioplayers` setzt vor jeden Asset-Pfad selbst `assets/` — hier steht
    // deshalb nur der Rest des Pfades.
    await player.setSource(
      AssetSource('sounds/${tone.folder}/${signal.fileName}'),
    );
    return player;
  }

  @override
  Future<void> dispose() async {
    for (final pending in _players.values) {
      try {
        await (await pending).dispose();
      } catch (_) {
        // Beim Herunterfahren ist ein nicht freigegebener Player kein Problem,
        // das jemanden noch erreichen würde.
      }
    }
    _players.clear();
  }
}
