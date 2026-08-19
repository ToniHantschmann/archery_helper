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

  /// Bereitet alle Signale vor, damit der erste Ton nicht der langsamste ist.
  ///
  /// Standardmäßig nichts zu tun: Vorladen ist eine Beschleunigung, die diese
  /// Schnittstelle erlaubt und nicht verlangt — eine Attrappe im Test hat
  /// nichts zu laden.
  Future<void> preload() async {}

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

  @override
  Future<void> preload() async {
    // Nacheinander und nicht mit `Future.wait`: das sind zehn kleine Dateien,
    // und der Start soll die Audio-Ausgabe nicht mit zehn gleichzeitigen
    // Anläufen begrüßen. Fehler landen im Log, nicht im Aufrufer — wer nicht
    // vorladen kann, kann es beim ersten Ton nochmal versuchen.
    //
    // Beide Sätze, nicht nur der eingestellte: welcher gilt, weiß hier niemand
    // (das ist `SignalSounds`), und ein Umschalten in den Einstellungen soll
    // sofort zu hören sein statt beim ersten Mal zu stocken.
    for (final tone in SignalTone.values) {
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
  }

  @override
  Future<void> play(AudioSignal signal, double volume, SignalTone tone) async {
    // Ton ist die Zugabe, die Uhr ist die Funktion. Ein fehlendes
    // GStreamer-Plugin oder eine stumme Soundkarte darf im Tunnel niemals den
    // Ablauf der Schusszeit anhalten, deshalb endet hier jeder Fehler.
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
