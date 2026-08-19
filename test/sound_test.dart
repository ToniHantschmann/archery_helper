import 'package:archery_helper/core/audio/audio_signal.dart';
import 'package:archery_helper/core/audio/signal_tone.dart';
import 'package:archery_helper/core/audio/sound_player.dart';
import 'package:archery_helper/models/competition_state.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/app_state_provider.dart';
import 'package:archery_helper/providers/competition_provider.dart';
import 'package:archery_helper/providers/settings_navigation_provider.dart';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:archery_helper/providers/sound_provider.dart';
import 'package:archery_helper/providers/timer_provider.dart';
import 'package:archery_helper/providers/traffic_light_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests für die Signaltöne: geprüft wird die *Folge* der Signale, nicht der
/// Klang. Der [SoundPlayer] ist dafür durch eine mitschreibende Attrappe
/// ersetzt — wie `_FakeWindowService` in `ui_layout_test.dart`.
///
/// Wie in `timer_test.dart` läuft alles in `testWidgets` ohne gepumptes Widget,
/// nur um die Fake-Uhr zu bekommen: `tester.pump(duration)` treibt sie vor und
/// feuert die Timer der Notifier, eine ganze Passe läuft also sofort ab.
void main() {
  late ProviderContainer container;
  late _RecordingSoundPlayer player;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = _RecordingSoundPlayer();
    container = ProviderContainer(
      overrides: [soundPlayerProvider.overrideWithValue(player)],
    );
  });

  tearDown(() => container.dispose());

  TimerNotifier timer() => container.read(timerProvider.notifier);
  CompetitionNotifier competition() =>
      container.read(competitionProvider.notifier);
  SettingsNotifier settings() => container.read(settingsProvider.notifier);
  TrafficLightNotifier trafficLight() =>
      container.read(trafficLightProvider.notifier);

  /// Das Speichern der Einstellungen ist entprellt — ein Test, der eine
  /// geändert hat, hinterlässt sonst einen laufenden Timer, den das
  /// Testframework anschließend meldet. Am Ende aufzurufen, wenn keine Uhr mehr
  /// läuft (wie `flushPendingSaves` in `keyboard_navigation_test.dart`).
  Future<void> flushPendingSaves(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  group('Ampel', () {
    testWidgets('an die Linie, Grün, 3-2-1 und Schluss', (tester) async {
      // Kurze Zeiten, damit die Passe im Test überschaubar bleibt; die Töne
      // hängen an den Phasenübergängen, nicht an ihrer Länge.
      settings().setDefaultMode(TimerMode.custom);
      settings().setCustomPrepTime(const Duration(seconds: 5));
      settings().setCustomMainTime(const Duration(seconds: 8));

      timer().startTimer();
      expect(player.taken, [AudioSignal.toTheLine]);

      // Die Vorbereitungszeit tickt nicht — nur die Schusszeit warnt vor.
      await tester.pump(const Duration(seconds: 5));
      expect(player.taken, [AudioSignal.start]);

      // 8s Schusszeit: solange mehr als 3 Sekunden übrig sind, bleibt es still.
      await tester.pump(const Duration(seconds: 4));
      expect(player.taken, isEmpty, reason: 'bei 4 Sekunden noch nicht');

      // Der Tick fällt in dem Moment, in dem die 3 auf dem Schirm erscheint.
      await tester.pump(const Duration(seconds: 1));
      expect(player.taken, [AudioSignal.warningTick]);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(player.taken, [AudioSignal.warningTick, AudioSignal.warningTick]);

      // Die 0 ist kein Tick, sondern der Schlusston.
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(timerProvider).phase, TimerPhase.ended);
      expect(player.taken, [AudioSignal.stop]);

      await flushPendingSaves(tester);
    });

    testWidgets('im Millisekundenmodus trotzdem genau drei Ticks', (
      tester,
    ) async {
      // Der Haken für die Restzeit kommt dann zehnmal pro Sekunde; ein Tick pro
      // Aufruf wären dreißig.
      settings().toggleShowMilliseconds();
      settings().setDefaultMode(TimerMode.custom);
      settings().setCustomPrepTime(const Duration(seconds: 1));
      settings().setCustomMainTime(const Duration(seconds: 6));

      timer().startTimer();
      await tester.pump(const Duration(seconds: 7));

      expect(
        player.signals.where((s) => s == AudioSignal.warningTick).length,
        3,
      );

      await flushPendingSaves(tester);
    });

    testWidgets('Wechselmodus: Grün pro Passage, Schluss nur einmal', (
      tester,
    ) async {
      settings().setDefaultMode(TimerMode.alternating);
      settings().setCustomPrepTime(const Duration(seconds: 5));
      settings().setAlternatingArrows(2);

      timer().startTimer();
      // 5s Vorbereitung, dann 2 Pfeile × 2 Schützen × 20s Passage.
      await tester.pump(const Duration(seconds: 5 + 4 * 20));

      expect(container.read(timerProvider).phase, TimerPhase.ended);
      expect(
        player.signals.where((s) => s == AudioSignal.start).length,
        4,
        reason: 'jede Passage beginnt mit dem Startsignal',
      );
      expect(
        player.signals.where((s) => s == AudioSignal.toTheLine).length,
        1,
        reason: 'nur eine Vorbereitungszeit, B steht schon am Balken',
      );
      expect(
        player.signals.where((s) => s == AudioSignal.stop).length,
        1,
        reason: 'Schluss erst am Ende der ganzen Passe, nicht bei der Übergabe',
      );

      await flushPendingSaves(tester);
    });

    testWidgets('Hand-Ampel tönt bei jedem Umschalten', (tester) async {
      trafficLight().toggle();
      trafficLight().toggle();
      trafficLight().toggle();

      expect(player.signals, [
        AudioSignal.start,
        AudioSignal.stop,
        AudioSignal.start,
      ]);

      await flushPendingSaves(tester);
    });

    testWidgets('Zurücksetzen und Moduswechsel bleiben still', (tester) async {
      timer().resetTimer();
      timer().setMode(TimerMode.outdoor);
      settings().setCustomMainTime(const Duration(seconds: 30));

      expect(player.signals, isEmpty);

      await flushPendingSaves(tester);
    });
  });

  group('Wettkampf', () {
    testWidgets('zwei Töne, ein Ton, drei Töne — und still bei 30 Sekunden', (
      tester,
    ) async {
      settings().setCompetitionEnds(1);

      competition().start();
      expect(player.taken, [AudioSignal.toTheLine], reason: 'an die Linie');

      await tester.pump(competitionPreparationTime);
      expect(player.taken, [AudioSignal.start], reason: 'Grün');

      // Indoor: 120s Schusszeit. Die Warnung bei 30s ist nach WA-Regel rein
      // optisch — hier darf nichts kommen.
      await tester.pump(const Duration(seconds: 90));
      expect(container.read(competitionProvider).isInWarningPeriod, isTrue);
      expect(player.taken, isEmpty, reason: 'keine Vorwarnung im Wettkampf');

      // Gruppenwechsel: kein Schlusston, sondern das Signal an die nächste
      // Gruppe.
      await tester.pump(const Duration(seconds: 30));
      expect(container.read(competitionProvider).groupIndex, 1);
      expect(player.taken, [AudioSignal.toTheLine]);

      await tester.pump(competitionPreparationTime);
      expect(player.taken, [AudioSignal.start]);

      // Nach der letzten Gruppe der Passe: Pfeile holen.
      await tester.pump(const Duration(seconds: 120));
      expect(player.taken, [AudioSignal.collect]);
      expect(container.read(competitionProvider).isFinished, isTrue);

      await flushPendingSaves(tester);
    });

    testWidgets('Spulen und Zurücksetzen bleiben still', (tester) async {
      // Der Wiederanlauf nach einem Absturz stellt die Runde auf die laufende
      // Passe — dabei darf kein Signal in die Halle gehen.
      competition().fastForward();
      competition().fastForward();
      competition().rewind();
      competition().reset();
      settings().setCompetitionDiscipline(CompetitionDiscipline.outdoor);

      expect(player.signals, isEmpty);

      await flushPendingSaves(tester);
    });
  });

  group('Einstellungen', () {
    testWidgets('Ton aus heißt still, obwohl die Uhr normal läuft', (
      tester,
    ) async {
      settings().toggleSound();
      expect(container.read(settingsProvider).soundEnabled, isFalse);

      settings().setDefaultMode(TimerMode.custom);
      settings().setCustomPrepTime(const Duration(seconds: 1));
      settings().setCustomMainTime(const Duration(seconds: 4));

      timer().startTimer();
      await tester.pump(const Duration(seconds: 5));

      expect(container.read(timerProvider).phase, TimerPhase.ended);
      expect(player.signals, isEmpty);

      await flushPendingSaves(tester);
    });

    testWidgets('der eingestellte Tonsatz kommt beim Player an', (
      tester,
    ) async {
      settings().setDefaultMode(TimerMode.custom);
      settings().setCustomPrepTime(const Duration(seconds: 1));

      timer().startTimer();
      expect(player.tones.last, SignalTone.tone1, reason: 'Standard');

      settings().setSignalTone(SignalTone.tone2);
      timer().resetTimer();
      timer().startTimer();
      expect(player.tones.last, SignalTone.tone2);

      timer().resetTimer();
      await flushPendingSaves(tester);
    });

    testWidgets('die Lautstärke lässt sich hören', (tester) async {
      // Die Navigation der Einstellungen ist `autoDispose` und leitet ihren
      // Bereich vom offenen Screen ab: ohne beides — offener Screen und ein
      // Hörer, der sie am Leben hält — würde sie zwischen zwei Aufrufen
      // wegräumen und die Auswahl verlieren.
      container
          .read(appStateProvider.notifier)
          .navigateToScreen(AppScreen.generalSettings);
      final subscription = container.listen(
        settingsNavigationProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final navigation = container.read(settingsNavigationProvider.notifier);
      navigation.select(SettingsItem.volume);

      navigation.adjustLeft();
      expect(player.taken, [AudioSignal.warningTick]);
      expect(player.volumes.last, container.read(settingsProvider).volume);

      // Am Anschlag ändert sich nichts, also tönt auch nichts.
      for (var i = 0; i < 20; i++) {
        navigation.adjustLeft();
      }
      expect(container.read(settingsProvider).volume, 0);
      expect(player.taken.length, 7, reason: '0.7 bis 0.0 in Zehnteln');

      // Und das Einschalten des Tons ist selbst hörbar.
      navigation.select(SettingsItem.soundEnabled);
      navigation.activate();
      expect(player.taken, isEmpty, reason: 'ausgeschaltet: still');

      navigation.activate();
      expect(player.taken, [AudioSignal.warningTick]);

      await flushPendingSaves(tester);
    });
  });
}

/// Schreibt mit, was abgespielt worden wäre.
class _RecordingSoundPlayer extends SoundPlayer {
  final signals = <AudioSignal>[];
  final volumes = <double>[];
  final tones = <SignalTone>[];

  /// Die Signale seit der letzten Abfrage — damit eine Erwartung den Ausschnitt
  /// beschreiben kann, um den es gerade geht, statt die ganze Runde.
  List<AudioSignal> get taken {
    final since = List.of(signals);
    signals.clear();
    return since;
  }

  @override
  Future<void> play(AudioSignal signal, double volume, SignalTone tone) async {
    signals.add(signal);
    volumes.add(volume);
    tones.add(tone);
  }

  @override
  Future<void> dispose() async {}
}
