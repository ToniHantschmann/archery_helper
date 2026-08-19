import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/audio_signal.dart';
import '../core/audio/sound_player.dart';
import 'settings_provider.dart';

/// Der Zugang zu den Signaltönen für alles, was einen ausgeben will.
///
/// Zwei Schichten mit Absicht: [SoundPlayer] weiß, wie ein Ton in die Halle
/// kommt, [SignalSounds] weiß, *ob* er das darf. Das Stummschalten und die
/// Lautstärke stehen damit an einer Stelle, und im Test wird nur die untere
/// Schicht getauscht — die Regel "Ton aus heißt still" ist dann mitgeprüft und
/// nicht mitattrappiert.
class SignalSounds {
  SignalSounds(this._ref);

  final Ref _ref;

  /// Gibt [signal] aus, sofern der Ton eingeschaltet ist.
  ///
  /// `read` und nicht `watch`: es zählt die Einstellung in dem Moment, in dem
  /// der Ton fällt. Das Ergebnis wird nicht abgewartet — die Uhr schaltet ihre
  /// Phase weiter, während der Ton läuft.
  void play(AudioSignal signal) {
    final settings = _ref.read(settingsProvider);
    if (!settings.soundEnabled) return;

    _ref.read(soundPlayerProvider).play(signal, settings.volume);
  }
}

/// Überschreibbar für Tests (wie `windowServiceProvider`); die App benutzt den
/// echten Player.
final soundPlayerProvider = Provider<SoundPlayer>((ref) {
  final player = AudioPlayersSoundPlayer();
  ref.onDispose(player.dispose);
  return player;
});

final signalSoundsProvider = Provider<SignalSounds>((ref) => SignalSounds(ref));
