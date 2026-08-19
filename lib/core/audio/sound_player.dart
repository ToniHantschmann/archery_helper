import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'audio_signal.dart';

/// Spielt einen [AudioSignal] ab — die Schnittstelle, die der Rest der App
/// kennt.
///
/// Abstrakt, weil sie im Test durch eine mitschreibende Attrappe ersetzt wird:
/// prüfbar ist die *Folge* der Signale, nicht der Ton. Ob überhaupt getönt
/// werden darf, entscheidet hier niemand — das ist `SignalSounds` in
/// `lib/providers/sound_provider.dart`.
abstract class SoundPlayer {
  Future<void> play(AudioSignal signal, double volume);

  Future<void> dispose();
}

/// Die einzige Stelle, die `audioplayers` kennt — wie
/// `lib/core/window/window_service.dart` für das Fenster.
class AudioPlayersSoundPlayer extends SoundPlayer {
  /// Ein eigener Player pro Signal, einmal vorbereitet und behalten.
  ///
  /// Ein gemeinsamer Player müsste bei jedem Ton die Quelle wechseln, und genau
  /// das Nachladen ist die Verzögerung, die man nicht haben will: ein
  /// Startsignal, das 300ms nach dem Grün kommt, ist ein falsches Startsignal.
  final _players = <AudioSignal, AudioPlayer>{};

  @override
  Future<void> play(AudioSignal signal, double volume) async {
    // Ton ist die Zugabe, die Uhr ist die Funktion. Ein fehlendes
    // GStreamer-Plugin oder eine stumme Soundkarte darf im Tunnel niemals den
    // Ablauf der Schusszeit anhalten, deshalb endet hier jeder Fehler.
    try {
      final player = _players[signal] ??= await _prepare(signal);
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

  Future<AudioPlayer> _prepare(AudioSignal signal) async {
    final player = AudioPlayer(playerId: 'signal_${signal.name}');
    await player.setPlayerMode(PlayerMode.lowLatency);
    // `stop` statt `release`: die Quelle bleibt geladen, sonst wäre jeder
    // zweite Ton wieder ein Ladevorgang.
    await player.setReleaseMode(ReleaseMode.stop);
    // `audioplayers` setzt vor jeden Asset-Pfad selbst `assets/` — hier steht
    // deshalb nur der Rest des Pfades.
    await player.setSource(AssetSource('sounds/${signal.fileName}'));
    return player;
  }

  @override
  Future<void> dispose() async {
    for (final player in _players.values) {
      try {
        await player.dispose();
      } catch (_) {
        // Beim Herunterfahren ist ein nicht freigegebener Player kein Problem,
        // das jemanden noch erreichen würde.
      }
    }
    _players.clear();
  }
}
