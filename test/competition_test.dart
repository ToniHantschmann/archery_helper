import 'package:archery_helper/models/competition_state.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/competition_provider.dart';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests für die Wettkampfrunde: den Ablauf Vorbereitung → Schusszeit →
/// Wechsel → nächste Passe, die Gruppenreihenfolge und das Ende der Runde.
///
/// Wie in `timer_test.dart` ist `testWidgets` hier nur der Weg zur Fake-Clock:
/// `tester.pump(dauer)` stellt die Uhr vor und feuert die Timer des Notifiers,
/// eine ganze Hallenrunde läuft damit in Millisekunden durch.
void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  CompetitionNotifier notifier() =>
      container.read(competitionProvider.notifier);
  CompetitionState round() => container.read(competitionProvider);

  /// Beendet alles Laufende, damit kein Timer den Test überlebt.
  void stop() => notifier().reset();

  /// Kürzt eine Runde auf [ends] Passen, bevor sie gelesen wird.
  void setEnds(int ends) =>
      container.read(settingsProvider.notifier).setCompetitionEnds(ends);

  group('initial state', () {
    test('starts idle on the first end with the shooting time on screen', () {
      final state = round();

      expect(state.phase, TimerPhase.idle);
      expect(state.isRunning, isFalse);
      expect(state.currentEnd, 1);
      expect(state.groupIndex, 0);
      expect(state.totalEnds, 20, reason: 'indoor is the default discipline');
      expect(state.preparationTime, const Duration(seconds: 10));
      expect(state.shootingTime, const Duration(seconds: 120));
      expect(state.remainingTime, const Duration(seconds: 120));
    });

    test('follows the discipline from the settings', () {
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      fresh
          .read(settingsProvider.notifier)
          .setCompetitionDiscipline(CompetitionDiscipline.outdoor);

      final state = fresh.read(competitionProvider);
      expect(state.shootingTime, const Duration(seconds: 240));
      expect(
        state.totalEnds,
        12,
        reason: 'the end count belongs to the discipline',
      );
    });
  });

  group('the course of an end', () {
    testWidgets('every shooting time is preceded by a preparation', (
      tester,
    ) async {
      setEnds(2);
      notifier().start();

      expect(round().phase, TimerPhase.preparation);
      expect(round().isChangeover, isFalse);
      expect(round().currentGroup, 'AB');

      await tester.pump(const Duration(seconds: 10));
      expect(round().phase, TimerPhase.active);
      expect(round().remainingTime, const Duration(seconds: 120));
      expect(round().currentGroup, 'AB');

      // Ende der Schusszeit von AB: nicht direkt CD, sondern erst der Wechsel.
      await tester.pump(const Duration(seconds: 120));
      expect(round().phase, TimerPhase.preparation);
      expect(round().groupIndex, 1);
      expect(round().currentGroup, 'CD');
      expect(
        round().isChangeover,
        isTrue,
        reason: 'the second group gets a changeover, not a fresh end',
      );

      await tester.pump(const Duration(seconds: 10));
      expect(round().phase, TimerPhase.active);
      expect(round().currentGroup, 'CD');

      // Und danach bleibt die Runde stehen: Pfeile holen dauert so lange, wie
      // es dauert.
      await tester.pump(const Duration(seconds: 120));
      expect(round().currentEnd, 2);
      expect(round().groupIndex, 0);
      expect(round().phase, TimerPhase.idle);
      expect(round().isRunning, isFalse);
      expect(round().isWaitingBetweenEnds, isTrue);
      expect(
        round().currentGroup,
        'CD',
        reason: 'the screen already says who is up after collecting arrows',
      );

      // Erst das Startsignal setzt die zweite Passe in Gang.
      notifier().advance();
      expect(round().phase, TimerPhase.preparation);
      expect(round().isChangeover, isFalse);

      stop();
    });

    testWidgets('the wait between two ends does not run down on its own', (
      tester,
    ) async {
      setEnds(2);
      notifier().start();
      await tester.pump(const Duration(seconds: 260));
      expect(round().isWaitingBetweenEnds, isTrue);

      // Zehn Minuten Pfeile holen ändern nichts — es läuft keine Uhr.
      await tester.pump(const Duration(minutes: 10));
      expect(round().phase, TimerPhase.idle);
      expect(round().currentEnd, 2);
      expect(round().remainingTime, const Duration(seconds: 120));
    });

    testWidgets('the group order reverses with every end', (tester) async {
      setEnds(3);
      notifier().start();

      expect(round().groupOrder, ['AB', 'CD']);

      // Eine ganze Passe: Vorbereitung + Schusszeit, zweimal. Danach wartet
      // die Runde, bis der Schießleiter wieder freigibt.
      await tester.pump(const Duration(seconds: 260));
      expect(round().currentEnd, 2);
      expect(
        round().groupOrder,
        ['CD', 'AB'],
        reason: 'after each end the other group starts',
      );
      expect(round().currentGroup, 'CD');

      notifier().advance();
      await tester.pump(const Duration(seconds: 260));
      expect(round().currentEnd, 3);
      expect(round().groupOrder, ['AB', 'CD']);

      stop();
    });

    testWidgets('a single group shoots one passage per end', (tester) async {
      container
          .read(settingsProvider.notifier)
          .setCompetitionLineup(CompetitionLineup.single);
      setEnds(2);

      expect(round().hasGroups, isFalse);

      notifier().start();
      await tester.pump(const Duration(seconds: 130));

      expect(
        round().currentEnd,
        2,
        reason: 'without a second group the end is over after one passage',
      );
      expect(round().isWaitingBetweenEnds, isTrue);

      stop();
    });
  });

  group('the end of the round', () {
    testWidgets('the last passage ends the round', (tester) async {
      setEnds(1);
      notifier().start();

      // Eine Passe mit zwei Gruppen: 2 × (10s + 120s).
      await tester.pump(const Duration(seconds: 260));

      expect(round().phase, TimerPhase.ended);
      expect(round().isRunning, isFalse);
      expect(round().isFinished, isTrue);
      expect(round().remainingTime, Duration.zero);
    });

    testWidgets('advance after the round starts over', (tester) async {
      setEnds(1);
      notifier().start();
      await tester.pump(const Duration(seconds: 260));
      expect(round().isFinished, isTrue);

      notifier().advance();
      expect(round().phase, TimerPhase.idle);
      expect(round().currentEnd, 1);
      expect(round().groupIndex, 0);
    });
  });

  group('pause, resume and skip', () {
    testWidgets('pausing freezes the clock and resuming continues it', (
      tester,
    ) async {
      notifier().start();
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 40));
      expect(round().remainingTime, const Duration(seconds: 80));

      notifier().pause();
      expect(round().isPaused, isTrue);
      expect(round().isRunning, isFalse);

      // Zeit läuft weiter, die Anzeige nicht.
      await tester.pump(const Duration(seconds: 30));
      expect(round().remainingTime, const Duration(seconds: 80));

      notifier().start();
      expect(round().isRunning, isTrue);
      await tester.pump(const Duration(seconds: 20));
      expect(round().remainingTime, const Duration(seconds: 60));

      stop();
    });

    testWidgets('advance drops the rest of the shooting time', (tester) async {
      setEnds(2);
      notifier().start();
      await tester.pump(const Duration(seconds: 10));
      expect(round().phase, TimerPhase.active);

      // Alle Pfeile sind draußen: der Schießleiter übergibt sofort.
      notifier().advance();
      expect(round().phase, TimerPhase.preparation);
      expect(round().currentGroup, 'CD');
      expect(round().remainingTime, const Duration(seconds: 10));

      stop();
    });

    testWidgets('a skipped preparation starts the shooting time now', (
      tester,
    ) async {
      notifier().start();
      notifier().skipPhase();

      expect(round().phase, TimerPhase.active);
      expect(round().remainingTime, const Duration(seconds: 120));

      stop();
    });
  });

  group('rewinding', () {
    testWidgets('goes back to the start of the previous passage', (
      tester,
    ) async {
      setEnds(2);
      notifier().start();

      // Bis mitten in die Schusszeit der zweiten Gruppe.
      await tester.pump(const Duration(seconds: 200));
      expect(round().groupIndex, 1);
      expect(round().phase, TimerPhase.active);

      notifier().rewind();

      expect(round().currentEnd, 1);
      expect(round().groupIndex, 0);
      expect(round().currentGroup, 'AB');
      expect(round().phase, TimerPhase.idle);
      expect(round().isRunning, isFalse);
      expect(round().isPaused, isFalse);
      expect(round().remainingTime, const Duration(seconds: 120));
      expect(
        round().isWaitingBetweenEnds,
        isFalse,
        reason: 'the arrows of the first end are still in the target',
      );
    });

    testWidgets('the rewound passage stands still until the start signal', (
      tester,
    ) async {
      setEnds(2);
      notifier().start();
      await tester.pump(const Duration(seconds: 200));
      notifier().rewind();

      // Zurückspulen ist noch kein Startsignal.
      await tester.pump(const Duration(minutes: 1));
      expect(round().phase, TimerPhase.idle);
      expect(round().remainingTime, const Duration(seconds: 120));

      notifier().advance();
      expect(round().phase, TimerPhase.preparation);
      expect(round().currentGroup, 'AB');

      stop();
    });

    testWidgets('crosses back into the previous end in its own order', (
      tester,
    ) async {
      setEnds(3);
      notifier().start();

      // Passe 1 komplett, dann Passe 2 starten.
      await tester.pump(const Duration(seconds: 260));
      expect(round().currentEnd, 2);
      expect(round().isWaitingBetweenEnds, isTrue);

      // Aus dem Warten heraus zurück: die letzte Gruppe der ersten Passe.
      notifier().rewind();
      expect(round().currentEnd, 1);
      expect(round().groupIndex, 1);
      expect(
        round().currentGroup,
        'CD',
        reason: 'end 1 shoots AB then CD, so its last passage is CD',
      );
      expect(round().phase, TimerPhase.idle);

      // Und weiter zurück bis zum Anfang der Runde.
      notifier().rewind();
      expect(round().currentEnd, 1);
      expect(round().groupIndex, 0);
      expect(round().currentGroup, 'AB');
    });

    testWidgets('stops at the beginning of the round', (tester) async {
      notifier().start();
      await tester.pump(const Duration(seconds: 5));

      notifier().rewind();
      expect(round().currentEnd, 1);
      expect(round().groupIndex, 0);
      expect(round().phase, TimerPhase.idle);

      // Ein weiterer Druck kann nicht vor den Rundenanfang laufen.
      notifier().rewind();
      expect(round().currentEnd, 1);
      expect(round().groupIndex, 0);
      expect(round().remainingTime, const Duration(seconds: 120));
    });

    testWidgets('repeats the last passage after the round is over', (
      tester,
    ) async {
      setEnds(1);
      notifier().start();
      await tester.pump(const Duration(seconds: 260));
      expect(round().isFinished, isTrue);

      notifier().rewind();

      expect(round().phase, TimerPhase.idle);
      expect(round().currentEnd, 1);
      expect(
        round().groupIndex,
        1,
        reason: 'the step back from the end of the round repeats its last '
            'passage, it does not skip one',
      );
      expect(round().currentGroup, 'CD');
      expect(round().remainingTime, const Duration(seconds: 120));

      notifier().advance();
      expect(round().phase, TimerPhase.preparation);

      stop();
    });
  });

  /// Das Gegenstück zum Zurückspulen: die Runde vorstellen, ohne dass dabei
  /// eine Phase abläuft — der Weg zurück in eine laufende Runde, nachdem der
  /// Rechner mitten darin neu gestartet werden musste.
  group('fast-forwarding', () {
    test('hands over to the next group without starting it', () {
      notifier().fastForward();

      expect(round().currentEnd, 1);
      expect(round().groupIndex, 1);
      expect(round().currentGroup, 'CD');
      expect(round().phase, TimerPhase.idle);
      expect(round().isRunning, isFalse);
      expect(round().remainingTime, const Duration(seconds: 120));
    });

    testWidgets('the forwarded passage stands still until the start signal', (
      tester,
    ) async {
      notifier().fastForward();

      // Vorspulen ist so wenig ein Startsignal wie Zurückspulen.
      await tester.pump(const Duration(minutes: 1));
      expect(round().phase, TimerPhase.idle);
      expect(round().groupIndex, 1);

      notifier().advance();
      expect(round().phase, TimerPhase.preparation);

      stop();
    });

    test('crosses into the next end in its own order', () {
      // Über die letzte Gruppe der ersten Passe hinaus: die zweite Passe
      // beginnt mit CD.
      notifier().fastForward();
      notifier().fastForward();

      expect(round().currentEnd, 2);
      expect(round().groupIndex, 0);
      expect(round().currentGroup, 'CD');
      expect(round().phase, TimerPhase.idle);
      expect(
        round().isWaitingBetweenEnds,
        isTrue,
        reason: 'the round waits between two ends, forwarded or shot',
      );
    });

    testWidgets('stops out of a running phase', (tester) async {
      notifier().start();
      await tester.pump(const Duration(seconds: 5));
      expect(round().isRunning, isTrue);

      notifier().fastForward();

      expect(round().phase, TimerPhase.idle);
      expect(round().isRunning, isFalse);
      expect(round().groupIndex, 1);

      stop();
    });

    test('stops at the end of the round instead of finishing it', () {
      setEnds(1);

      notifier().fastForward();
      expect(round().groupIndex, 1);

      // Hinter der letzten Gruppe der letzten Passe liegt nichts mehr — eine
      // Runde beendet man, indem man sie schießt, nicht durch Vorspulen.
      notifier().fastForward();
      expect(round().currentEnd, 1);
      expect(round().groupIndex, 1);
      expect(round().phase, TimerPhase.idle);
      expect(round().isFinished, isFalse);
    });

    testWidgets('does nothing once the round is over', (tester) async {
      setEnds(1);
      notifier().start();
      await tester.pump(const Duration(seconds: 260));
      expect(round().isFinished, isTrue);

      notifier().fastForward();

      expect(round().isFinished, isTrue);
      expect(round().currentEnd, 1);
      expect(round().groupIndex, 1);
    });
  });

  group('settings changes', () {
    testWidgets('changing the round setup starts a fresh round', (
      tester,
    ) async {
      setEnds(5);
      notifier().start();
      await tester.pump(const Duration(seconds: 260));
      notifier().advance();
      await tester.pump(const Duration(seconds: 1));
      expect(round().currentEnd, 2);

      // Mitten in einer Runde die Aufstellung umbauen hat keine Bedeutung — die
      // Runde wird neu aufgesetzt.
      container
          .read(settingsProvider.notifier)
          .setCompetitionLineup(CompetitionLineup.ab);

      expect(round().phase, TimerPhase.idle);
      expect(round().currentEnd, 1);
      expect(round().lineup, CompetitionLineup.ab);
      expect(round().groupOrder, ['A', 'B']);
      expect(round().isRunning, isFalse);

      // Der Schreibvorgang der Einstellungen ist entprellt — laufen lassen,
      // sonst bleibt sein Timer hinter dem Test stehen.
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('the warning period covers the last 30 seconds', (
      tester,
    ) async {
      notifier().start();
      await tester.pump(const Duration(seconds: 10));

      expect(round().isInWarningPeriod, isFalse);

      await tester.pump(const Duration(seconds: 90));
      expect(round().remainingTime, const Duration(seconds: 30));
      expect(round().isInWarningPeriod, isTrue);

      stop();
    });
  });
}
