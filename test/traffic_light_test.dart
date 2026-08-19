import 'package:archery_helper/core/audio/audio_signal.dart';
import 'package:archery_helper/core/audio/signal_tone.dart';
import 'package:archery_helper/core/audio/sound_player.dart';
import 'package:archery_helper/models/signal_state.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/sound_provider.dart';
import 'package:archery_helper/providers/traffic_light_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the hand-switched traffic light: two states, no clock.
///
/// Der Ton ist hier stummgelegt — welche Signale fallen, prüft `sound_test.dart`;
/// der echte Player käme im Test nur bis zur fehlenden Plattform-Attrappe.
void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [soundPlayerProvider.overrideWithValue(_SilentSoundPlayer())],
    );
  });

  tearDown(() => container.dispose());

  TrafficLightNotifier notifier() =>
      container.read(trafficLightProvider.notifier);
  bool isGreen() => container.read(trafficLightProvider);
  SignalState signal() => container.read(trafficLightSignalProvider);

  test('starts on red', () {
    expect(isGreen(), isFalse);
  });

  test('red is the preparation phase, not the pale idle state', () {
    // `preparation` rather than `idle`: idle is tinted at a tenth of the
    // strength, and a barely-red screen is not a signal.
    expect(signal().phase, TimerPhase.preparation);
    expect(signal().isWarning, isFalse);
    expect(signal().isPaused, isFalse);
  });

  test('toggle switches between red and green', () {
    notifier().toggle();
    expect(isGreen(), isTrue);
    expect(signal().phase, TimerPhase.active);

    notifier().toggle();
    expect(isGreen(), isFalse);
    expect(signal().phase, TimerPhase.preparation);
  });

  testWidgets('never arms a countdown', (tester) async {
    notifier().toggle();

    // Nothing is ticking, so time may pass freely without the signal falling
    // back the way zero durations used to collapse towards `ended`.
    await tester.pump(const Duration(minutes: 5));

    expect(isGreen(), isTrue);
  });
}

/// Ein Player, der nichts tut — siehe `_RecordingSoundPlayer` in
/// `sound_test.dart`, nur ohne Mitschrift.
class _SilentSoundPlayer extends SoundPlayer {
  @override
  Future<void> play(AudioSignal signal, double volume, SignalTone tone) async {}

  @override
  Future<void> dispose() async {}
}
