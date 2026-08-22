import 'package:archery_helper/core/l10n/app_language.dart';
import 'package:archery_helper/core/l10n/competition_texts.dart';
import 'package:archery_helper/models/competition_state.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/competition_provider.dart';
import 'package:archery_helper/providers/competition_ui_providers.dart';
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

  /// Kürzt eine Runde auf [ends] Wettkampfpassen und [practice] Einschieß-
  /// passen, bevor sie gelesen wird.
  ///
  /// Ohne Einschießen, obwohl die Einstellung von Haus aus auf vier steht: die
  /// Tests hier beschreiben den Wettkampfblock, und vier vorgeschaltete Passen
  /// wären in jeder Erwartung nur ein Offset. Das Einschießen hat seine eigene
  /// Gruppe.
  void setEnds(int ends, {int practice = 0}) {
    container.read(settingsProvider.notifier)
      ..setCompetitionEnds(ends)
      ..setCompetitionPracticeEnds(practice);
  }

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
      expect(round().groupOrder, [
        'CD',
        'AB',
      ], reason: 'after each end the other group starts');
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
        reason:
            'the step back from the end of the round repeats its last '
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

    test(
      'winding back and forth over an end boundary lands where it began',
      () {
        setEnds(3);

        // Über die Passengrenze hinweg und wieder zurück — dort dreht sich die
        // Gruppenreihenfolge um, also ist das die Stelle, an der ein Schritt zu
        // viel oder zu wenig auffällt.
        notifier().fastForward();
        notifier().fastForward();
        notifier().fastForward();
        expect(round().currentEnd, 2);
        expect(round().groupIndex, 1);
        expect(round().currentGroup, 'AB', reason: 'end 2 shoots CD first');

        notifier().rewind();
        notifier().rewind();
        notifier().rewind();

        expect(round().currentEnd, 1);
        expect(round().groupIndex, 0);
        expect(round().currentGroup, 'AB');
        expect(round().phase, TimerPhase.idle);
        expect(round().isRunning, isFalse);
      },
    );
  });

  /// Die Einschießpassen laufen genau wie die Wettkampfpassen ab und zählen nur
  /// nicht mit. Geprüft wird deshalb vor allem, dass sie *keinen* Sonderfall
  /// bilden: derselbe Ablauf, dasselbe Spulen, nur eine andere Beschriftung.
  group('practice ends', () {
    const texts = CompetitionTexts(AppLanguage.german);

    /// Ein Durchgang weiter, lautlos — mit AB/CD sind zwei davon eine Passe.
    void forward(int passages) {
      for (var i = 0; i < passages; i++) {
        notifier().fastForward();
      }
    }

    test('the round begins in the practice block', () {
      setEnds(20, practice: 2);

      expect(round().practiceEnds, 2);
      expect(round().isPractice, isTrue);
      expect(round().endNumber, 1);
      expect(round().endsInBlock, 2);
      expect(round().lastEnd, 22, reason: 'zwei Einschieß- und 20 Wettkampf');
    });

    test('the counter names the block it is in', () {
      setEnds(20, practice: 2);

      expect(texts.endCounter(round()), 'Einschießen 1/2');
      expect(container.read(competitionLedEndProvider), 'P1');

      forward(4);

      expect(round().currentEnd, 3);
      expect(round().isPractice, isFalse);
      expect(
        texts.endCounter(round()),
        'Passe 1/20',
        reason: 'der Wettkampf zählt wieder bei eins an',
      );
      expect(container.read(competitionLedEndProvider), '1');
    });

    testWidgets('a practice end runs like any other end', (tester) async {
      setEnds(20, practice: 1);
      notifier().start();

      expect(round().isPractice, isTrue);
      expect(round().phase, TimerPhase.preparation);

      // Dieselbe Passe wie im Wettkampf: 2 × (10s + 120s).
      await tester.pump(const Duration(seconds: 260));

      expect(round().currentEnd, 2);
      expect(round().isPractice, isFalse);
      expect(round().endNumber, 1);
      expect(
        round().isWaitingBetweenEnds,
        isTrue,
        reason: 'auch nach dem Einschießen werden erst die Pfeile geholt',
      );

      stop();
    });

    testWidgets('the round ends after the competition block', (tester) async {
      setEnds(1, practice: 1);
      notifier().start();
      await tester.pump(const Duration(seconds: 260));

      expect(round().isFinished, isFalse, reason: 'erst die Einschießpasse');

      notifier().advance();
      await tester.pump(const Duration(seconds: 260));

      expect(round().isFinished, isTrue);
    });

    test('the group order starts over with the competition', () {
      setEnds(20, practice: 3);

      expect(round().groupOrder, ['AB', 'CD']);

      forward(2);
      expect(round().currentEnd, 2);
      expect(
        round().groupOrder,
        ['CD', 'AB'],
        reason: 'innerhalb des Einschießens wechselt die Reihenfolge auch',
      );

      forward(4);
      expect(round().currentEnd, 4);
      expect(round().isPractice, isFalse);
      expect(
        round().groupOrder,
        ['AB', 'CD'],
        reason: 'Passe 1 beginnt mit AB, egal wie oft eingeschossen wurde',
      );
    });

    test('rewinding steps back into the practice ends', () {
      setEnds(20, practice: 2);
      forward(4);
      expect(round().currentEnd, 3);

      notifier().rewind();

      expect(round().currentEnd, 2);
      expect(round().isPractice, isTrue);
      expect(round().endNumber, 2);
      expect(round().currentGroup, 'AB', reason: 'der letzte Durchgang von P2');
    });

    test('without practice ends the round is what it always was', () {
      setEnds(20);

      expect(round().practiceEnds, 0);
      expect(round().isPractice, isFalse);
      expect(round().endNumber, round().currentEnd);
      expect(round().lastEnd, 20);
      expect(texts.endCounter(round()), 'Passe 1/20');
    });

    testWidgets('changing the practice ends starts a fresh round', (
      tester,
    ) async {
      setEnds(20, practice: 2);
      notifier().start();
      await tester.pump(const Duration(seconds: 5));

      container.read(settingsProvider.notifier).setCompetitionPracticeEnds(4);

      expect(round().phase, TimerPhase.idle);
      expect(round().currentEnd, 1);
      expect(round().practiceEnds, 4);
      expect(round().isRunning, isFalse);

      await tester.pump(const Duration(milliseconds: 400));
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

  /// Die Uhrzeitanzeige vor dem Turnierstart: von Hand eingeschaltet, und von
  /// der Runde wieder abgeschaltet, sobald sie die Anzeige braucht.
  group('the wall clock', () {
    test('is off until it is switched on, and toggles back', () {
      expect(round().showClock, isFalse);

      notifier().toggleClock();
      expect(round().showClock, isTrue);
      expect(
        container.read(competitionShowClockProvider),
        isTrue,
        reason: 'der Schirm liest sie über den Anzeige-Provider',
      );

      notifier().toggleClock();
      expect(round().showClock, isFalse);
    });

    testWidgets('the start signal takes the display back', (tester) async {
      notifier().toggleClock();
      notifier().start();

      expect(round().phase, TimerPhase.preparation);
      expect(round().showClock, isFalse);

      // Und auch die Schusszeit dahinter lässt sie aus.
      await tester.pump(const Duration(seconds: 10));
      expect(round().phase, TimerPhase.active);
      expect(round().showClock, isFalse);

      stop();
    });

    testWidgets('resuming from a pause takes it back too', (tester) async {
      notifier().start();
      await tester.pump(const Duration(seconds: 5));
      notifier().pause();

      // Pausiert darf die Uhrzeit an — es läuft ja gerade nichts.
      notifier().toggleClock();
      expect(round().showClock, isTrue);

      notifier().start();
      expect(round().isRunning, isTrue);
      expect(round().showClock, isFalse);

      stop();
    });

    test('a reset clears it', () {
      notifier().toggleClock();
      notifier().reset();

      expect(round().showClock, isFalse);
    });

    testWidgets('spooling the round leaves it alone', (tester) async {
      setEnds(5);
      notifier().start();
      await tester.pump(const Duration(seconds: 260));

      // Zwischen zwei Passen: die Runde wartet, es läuft nichts.
      expect(round().isWaitingBetweenEnds, isTrue);

      notifier().toggleClock();
      notifier().fastForward();
      expect(round().showClock, isTrue, reason: 'vorspulen startet nichts');

      notifier().rewind();
      expect(round().showClock, isTrue, reason: 'zurückspulen auch nicht');

      stop();
    });

    test('the hint label names where the key leads', () {
      expect(container.read(competitionClockLabelProvider), 'Uhrzeit');

      notifier().toggleClock();
      expect(container.read(competitionClockLabelProvider), 'Runde');
    });
  });

  /// Der Countdown vor dem Turnierstart: läuft in `idle` mit, ohne die Runde
  /// anzufassen — und am Ende entscheidet die Einstellung, ob sie anläuft.
  group('the countdown before the start', () {
    void setCountdown(Duration duration) => container
        .read(settingsProvider.notifier)
        .setCompetitionCountdownTime(duration);

    void enableAutoStart() => container
        .read(settingsProvider.notifier)
        .toggleCompetitionCountdownAutoStart();

    testWidgets('counts down without moving the round', (tester) async {
      setCountdown(const Duration(seconds: 30));
      notifier().toggleCountdown();

      expect(round().isCountingDown, isTrue);
      expect(round().remainingTime, const Duration(seconds: 30));
      expect(round().phase, TimerPhase.idle, reason: 'die Runde wartet weiter');
      expect(round().isRunning, isFalse);
      expect(round().currentEnd, 1);

      await tester.pump(const Duration(seconds: 10));
      expect(round().remainingTime, const Duration(seconds: 20));

      stop();
    });

    test('the same key cancels it and puts the shooting time back', () {
      setCountdown(const Duration(seconds: 30));
      notifier().toggleCountdown();
      notifier().toggleCountdown();

      expect(round().isCountingDown, isFalse);
      expect(round().remainingTime, round().shootingTime);
      expect(round().phase, TimerPhase.idle);
    });

    testWidgets('starts the round by itself when that is switched on', (
      tester,
    ) async {
      setCountdown(const Duration(seconds: 20));
      enableAutoStart();
      notifier().toggleCountdown();

      await tester.pump(const Duration(seconds: 20));

      expect(round().isCountingDown, isFalse);
      expect(round().phase, TimerPhase.preparation);
      expect(round().isRunning, isTrue);
      expect(round().remainingTime, round().preparationTime);

      stop();
    });

    testWidgets('otherwise it just hands the display back', (tester) async {
      setCountdown(const Duration(seconds: 20));
      notifier().toggleCountdown();

      await tester.pump(const Duration(seconds: 20));

      expect(round().isCountingDown, isFalse);
      expect(round().phase, TimerPhase.idle);
      expect(round().isRunning, isFalse);
      expect(
        round().remainingTime,
        round().shootingTime,
        reason: 'wieder die Zahl, um die es in der ersten Passe geht',
      );

      stop();
    });

    testWidgets('the start signal ends it early', (tester) async {
      setCountdown(const Duration(seconds: 60));
      notifier().toggleCountdown();
      await tester.pump(const Duration(seconds: 5));

      notifier().advance();

      expect(round().isCountingDown, isFalse);
      expect(round().phase, TimerPhase.preparation);
      expect(round().remainingTime, round().preparationTime);

      stop();
    });

    test('it and the wall clock switch each other off', () {
      notifier().toggleCountdown();
      notifier().toggleClock();

      expect(round().showClock, isTrue);
      expect(round().isCountingDown, isFalse);

      notifier().toggleCountdown();
      expect(round().isCountingDown, isTrue);
      expect(round().showClock, isFalse);

      stop();
    });

    testWidgets('a running round has no use for it', (tester) async {
      notifier().start();
      await tester.pump(const Duration(seconds: 5));

      notifier().toggleCountdown();
      expect(round().isCountingDown, isFalse);
      expect(round().phase, TimerPhase.preparation);

      stop();
    });

    testWidgets('and neither has the wait between two ends', (tester) async {
      setEnds(2);
      notifier().start();
      await tester.pump(const Duration(seconds: 260));
      expect(round().isWaitingBetweenEnds, isTrue);

      notifier().toggleCountdown();
      expect(
        round().isCountingDown,
        isFalse,
        reason: 'dort wird auf die Pfeile gewartet, nicht auf den Start',
      );
      expect(round().remainingTime, round().shootingTime);

      stop();
    });

    testWidgets('rewound to the beginning it works again', (tester) async {
      setEnds(2);
      notifier().start();
      await tester.pump(const Duration(seconds: 260));

      // Zurück durch die erste Passe: an ihren letzten Durchgang, dann an
      // ihren ersten — und dort steht die Runde wieder vor dem Start.
      notifier().rewind();
      notifier().rewind();
      expect(round().isBeforeStart, isTrue);

      notifier().toggleCountdown();
      expect(round().isCountingDown, isTrue);

      stop();
    });

    test('whole seconds, even with milliseconds switched on', () {
      container.read(settingsProvider.notifier).toggleShowMilliseconds();
      expect(notifier().displayStep, const Duration(milliseconds: 100));

      notifier().toggleCountdown();
      expect(
        notifier().displayStep,
        const Duration(seconds: 1),
        reason: 'Zehntel auf einer Minutenansage sind Unruhe ohne Nutzen',
      );

      stop();
    });

    test('the phase word says what the number leads to', () {
      const texts = CompetitionTexts(AppLanguage.german);

      notifier().toggleCountdown();
      expect(texts.phaseText(round()), 'Start in');
      expect(
        container.read(competitionCountdownLabelProvider),
        'Countdown aus',
      );

      notifier().toggleCountdown();
      expect(texts.phaseText(round()), 'Bereit');
      expect(container.read(competitionCountdownLabelProvider), 'Countdown');
    });
  });

  /// Die LED-Wand zeigt ganze Sekunden — auf einer Anzeigetafel gehören
  /// Zehntel nicht hin. Sie ist aber nur eine Anzeige: an der Runde selbst
  /// ändert der Wechsel nichts.
  group('the LED display', () {
    void setDisplay(CompetitionDisplay display) => container
        .read(settingsProvider.notifier)
        .setCompetitionDisplay(display);

    test('keeps whole seconds even while milliseconds are switched on', () {
      container.read(settingsProvider.notifier).toggleShowMilliseconds();
      expect(notifier().displayStep, const Duration(milliseconds: 100));

      setDisplay(CompetitionDisplay.led);
      expect(notifier().displayStep, const Duration(seconds: 1));

      setDisplay(CompetitionDisplay.ledStretched);
      expect(notifier().displayStep, const Duration(seconds: 1));

      // Zurück auf den Monitor gilt wieder die allgemeine Einstellung.
      setDisplay(CompetitionDisplay.standard);
      expect(notifier().displayStep, const Duration(milliseconds: 100));
    });

    testWidgets('switching mid-round leaves end, group and time alone', (
      tester,
    ) async {
      notifier().start();
      await tester.pump(const Duration(seconds: 10));
      notifier().skipPhase();
      await tester.pump(const Duration(seconds: 121));

      // Zweite Gruppe der ersten Passe, Vorbereitung läuft.
      expect(round().groupIndex, 1);
      final before = round().remainingTime;

      setDisplay(CompetitionDisplay.led);
      await tester.pump();

      expect(round().currentEnd, 1);
      expect(round().groupIndex, 1);
      expect(round().remainingTime, before);
      expect(round().isRunning, isTrue);

      stop();
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
