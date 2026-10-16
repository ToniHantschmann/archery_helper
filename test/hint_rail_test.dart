import 'package:archery_helper/app/app.dart';
import 'package:archery_helper/models/competition_state.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/app_state_provider.dart';
import 'package:archery_helper/providers/competition_provider.dart';
import 'package:archery_helper/providers/hint_navigation_provider.dart';
import 'package:archery_helper/providers/timer_provider.dart';
import 'package:archery_helper/widgets/key_hint_rail.dart';
import 'package:archery_helper/widgets/status_chip.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Die Tastenleiste fährt weg, solange eine Uhr läuft, und kommt zurück, sobald
/// sie steht. Ampel und Ruheanzeige haben gar keine.
void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  Future<void> pumpApp(WidgetTester tester, AppScreen startAt) async {
    // Die 800x600 des Testschirms sind zu klein für die Leisten (siehe
    // keyboard_navigation_test.dart).
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    container.read(appStateProvider.notifier).navigateToScreen(startAt);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ArcheryHelperApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Ob die Leiste gerade aus dem Bild gefahren ist — abgelesen am Ziel der
  /// Slide-Animation, nicht an einem Zwischenstand.
  bool railHidden(WidgetTester tester) {
    final slide = tester.widget<AnimatedSlide>(
      find.descendant(
        of: find.byType(KeyHintRail),
        matching: find.byType(AnimatedSlide),
      ),
    );
    return slide.offset != Offset.zero;
  }

  /// Dasselbe für einen Statuschip oben: ob er weggefahren ist, `null` wenn
  /// er gar nicht wegfahren kann (kein [AnimatedSlide] über ihm).
  bool? chipHidden(WidgetTester tester, Finder chip) {
    final slides = find.ancestor(
      of: chip,
      matching: find.byType(AnimatedSlide),
    );
    if (slides.evaluate().isEmpty) return null;
    return tester.widget<AnimatedSlide>(slides.first).offset != Offset.zero;
  }

  /// Timer: der Moduschip; Wettkampf: der Passenchip. Beide stehen links.
  Finder leftChip() => find.byType(StatusChip).first;

  /// Wettkampf: der Disziplinchip rechts.
  Finder rightChip() => find.byType(StatusChip).last;

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  group('timer', () {
    testWidgets('rail hides while the clock runs and returns on pause', (
      tester,
    ) async {
      await pumpApp(tester, AppScreen.timer);
      expect(railHidden(tester), isFalse);

      await press(tester, LogicalKeyboardKey.space);
      expect(container.read(timerProvider).isRunning, isTrue);
      expect(railHidden(tester), isTrue);

      await press(tester, LogicalKeyboardKey.keyP);
      expect(container.read(timerProvider).isPaused, isTrue);
      expect(railHidden(tester), isFalse);

      await press(tester, LogicalKeyboardKey.keyP);
      expect(railHidden(tester), isTrue);

      await press(tester, LogicalKeyboardKey.keyR);
      expect(container.read(timerProvider).isRunning, isFalse);
      expect(railHidden(tester), isFalse);
    });

    testWidgets('mode chip hides with the rail', (tester) async {
      await pumpApp(tester, AppScreen.timer);
      expect(chipHidden(tester, leftChip()), isFalse);

      await press(tester, LogicalKeyboardKey.space);
      expect(chipHidden(tester, leftChip()), isTrue);

      await press(tester, LogicalKeyboardKey.keyP);
      expect(chipHidden(tester, leftChip()), isFalse);

      await press(tester, LogicalKeyboardKey.keyR);
    });
  });

  group('keys on a hidden rail', () {
    testWidgets('timer: arrows and Enter do nothing while the clock runs', (
      tester,
    ) async {
      await pumpApp(tester, AppScreen.timer);
      await press(tester, LogicalKeyboardKey.space);
      final focused = container.read(timerHintNavigationProvider);

      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(container.read(timerHintNavigationProvider), focused);

      await press(tester, LogicalKeyboardKey.enter);
      expect(container.read(timerProvider).isRunning, isTrue);

      // Paused, the rail is back and so are its keys.
      await press(tester, LogicalKeyboardKey.keyP);
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(container.read(timerHintNavigationProvider), isNot(focused));

      await press(tester, LogicalKeyboardKey.keyR);
    });

    testWidgets('competition: arrows and Enter do nothing during the round', (
      tester,
    ) async {
      await pumpApp(tester, AppScreen.competition);
      await press(tester, LogicalKeyboardKey.space);
      final focused = container.read(competitionHintNavigationProvider);
      // Was ein ausgelöster Hinweis ändern würde — nicht der ganze Zustand,
      // dessen Restzeit beim Pumpen weiterlaufen darf.
      (TimerPhase, int, int, bool, bool) snapshot() {
        final s = container.read(competitionProvider);
        return (s.phase, s.currentEnd, s.groupIndex, s.isRunning, s.showClock);
      }

      final before = snapshot();

      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(container.read(competitionHintNavigationProvider), focused);

      await press(tester, LogicalKeyboardKey.enter);
      expect(snapshot(), before);

      container.read(competitionProvider.notifier).reset();
      await tester.pumpAndSettle();
    });

    AppScreen screen() => container.read(currentScreenProvider);

    testWidgets('timer: Esc cannot leave a running clock', (tester) async {
      await pumpApp(tester, AppScreen.timer);
      await press(tester, LogicalKeyboardKey.space);

      await press(tester, LogicalKeyboardKey.escape);
      expect(screen(), AppScreen.timer);
      expect(container.read(timerProvider).isRunning, isTrue);

      // Pausiert darf man gehen — es läuft dann ja nichts mehr.
      await press(tester, LogicalKeyboardKey.keyP);
      await press(tester, LogicalKeyboardKey.escape);
      expect(screen(), AppScreen.menu);

      container.read(timerProvider.notifier).resetTimer();
      await tester.pumpAndSettle();
    });

    testWidgets('competition: Esc cannot leave a running round', (
      tester,
    ) async {
      await pumpApp(tester, AppScreen.competition);
      await press(tester, LogicalKeyboardKey.space);

      await press(tester, LogicalKeyboardKey.escape);
      expect(screen(), AppScreen.competition);
      expect(container.read(competitionProvider).isRunning, isTrue);

      await press(tester, LogicalKeyboardKey.keyR);
      await press(tester, LogicalKeyboardKey.escape);
      expect(screen(), AppScreen.menu);
    });

    testWidgets('competition: Esc cannot leave a running countdown', (
      tester,
    ) async {
      await pumpApp(tester, AppScreen.competition);
      await press(tester, LogicalKeyboardKey.keyC);
      expect(container.read(competitionProvider).isCountingDown, isTrue);

      await press(tester, LogicalKeyboardKey.escape);
      expect(screen(), AppScreen.competition);

      await press(tester, LogicalKeyboardKey.keyC);
      await press(tester, LogicalKeyboardKey.escape);
      expect(screen(), AppScreen.menu);
    });
  });

  group('competition', () {
    CompetitionState round() => container.read(competitionProvider);

    testWidgets('rail hides during the round and returns between ends', (
      tester,
    ) async {
      await pumpApp(tester, AppScreen.competition);
      expect(railHidden(tester), isFalse);

      await press(tester, LogicalKeyboardKey.space);
      expect(round().isRunning, isTrue);
      expect(railHidden(tester), isTrue);

      // Alle Phasen der ersten Passe überspringen, bis die Runde aufs
      // Pfeileholen wartet.
      while (!round().isWaitingBetweenEnds) {
        container.read(competitionProvider.notifier).skipPhase();
        await tester.pumpAndSettle();
      }
      expect(railHidden(tester), isFalse);

      container.read(competitionProvider.notifier).reset();
      await tester.pumpAndSettle();
    });

    testWidgets('discipline chip hides with the rail, the end chip stays', (
      tester,
    ) async {
      await pumpApp(tester, AppScreen.competition);
      expect(chipHidden(tester, rightChip()), isFalse);
      expect(chipHidden(tester, leftChip()), isNull);

      await press(tester, LogicalKeyboardKey.space);
      expect(chipHidden(tester, rightChip()), isTrue);
      expect(chipHidden(tester, leftChip()), isNull);

      container.read(competitionProvider.notifier).reset();
      await tester.pumpAndSettle();
      expect(chipHidden(tester, rightChip()), isFalse);
    });

    testWidgets('rail hides during the countdown to the start', (
      tester,
    ) async {
      await pumpApp(tester, AppScreen.competition);

      container.read(competitionProvider.notifier).toggleCountdown();
      await tester.pumpAndSettle();
      expect(round().isCountingDown, isTrue);
      expect(railHidden(tester), isTrue);

      container.read(competitionProvider.notifier).stopCountdown();
      await tester.pumpAndSettle();
      expect(railHidden(tester), isFalse);
    });
  });

  testWidgets('traffic light and idle screen have no rail', (tester) async {
    await pumpApp(tester, AppScreen.trafficLight);
    expect(find.byType(KeyHintRail), findsNothing);

    container.read(appStateProvider.notifier).navigateToScreen(AppScreen.idle);
    await tester.pumpAndSettle();
    expect(find.byType(KeyHintRail), findsNothing);
  });
}
