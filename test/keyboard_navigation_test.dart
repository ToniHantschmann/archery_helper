import 'package:archery_helper/app/app.dart';
import 'package:archery_helper/models/competition_state.dart';
import 'package:archery_helper/models/settings.dart';
import 'package:archery_helper/models/settings_section.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/app_state_provider.dart';
import 'package:archery_helper/providers/competition_provider.dart';
import 'package:archery_helper/providers/settings_navigation_provider.dart';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:archery_helper/providers/timer_provider.dart';
import 'package:archery_helper/providers/traffic_light_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke tests for the app-wide keyboard path:
/// KeyboardScope → AppActionsNotifier → ScreenActionHandler → providers.
void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  /// Pumps the real app so the test exercises the actual widget tree,
  /// including KeyboardScope in app.dart.
  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1920, 1080),
    AppScreen startAt = AppScreen.timer,
  }) async {
    // The default 800x600 test surface is far smaller than the tunnel monitors
    // and makes the timer button row overflow, which would fail every test.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The app itself starts on the menu; most tests here exercise the timer
    // path, so they open it explicitly instead of tapping through the menu.
    container.read(appStateProvider.notifier).navigateToScreen(startAt);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ArcheryHelperApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// S opens the settings of the screen you are on — from the timer screen that
  /// is the Ampel section.
  Future<void> openSettings(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pumpAndSettle();
  }

  /// Settings writes are debounced, so a test that changed a setting leaves a
  /// pending timer behind. Let it run before the test ends.
  Future<void> flushPendingSaves(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  /// A running countdown keeps its periodic Timer alive, which the test
  /// framework flags after teardown. Stop it explicitly.
  Future<void> stopTimer(WidgetTester tester) async {
    container.read(timerProvider.notifier).resetTimer();
    await tester.pumpAndSettle();
  }

  AppScreen currentScreen() => container.read(currentScreenProvider);
  SettingsItem selectedItem() => container.read(selectedSettingsItemProvider);
  Settings settings() => container.read(settingsProvider);
  TimerState timer() => container.read(timerProvider);
  bool resetArmed() => container.read(isResetArmedProvider);

  void select(SettingsItem item) =>
      container.read(settingsNavigationProvider.notifier).select(item);

  group('screen navigation', () {
    testWidgets('S opens the settings screen and Esc leaves it again', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(currentScreen(), AppScreen.timer);

      await openSettings(tester);
      expect(
        currentScreen(),
        AppScreen.timerSettings,
        reason: 'S means "set up what I am looking at"',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        currentScreen(),
        AppScreen.timer,
        reason: 'Esc leads back to the tool the settings belong to',
      );

      // Und wieder hinein: der zweite Besuch ist die Stelle, an der ein
      // Auswahlzustand auffliegt, der das Verlassen überlebt hat und erst im
      // Aufbau des Screens nachgezogen wird (siehe settingsNavigationProvider).
      await openSettings(tester);
      expect(currentScreen(), AppScreen.timerSettings);
      expect(selectedItem(), SettingsItem.defaultMode);
    });

    testWidgets('Esc returns to the menu, and Esc there does nothing', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(currentScreen(), AppScreen.menu);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        currentScreen(),
        AppScreen.menu,
        reason: 'the menu is the home screen — there is nothing above it',
      );
    });

    testWidgets('mode cycling still works on the timer screen', (tester) async {
      await pumpApp(tester);
      expect(currentScreen(), AppScreen.timer);

      final before = timer().mode;

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pumpAndSettle();

      expect(timer().mode, isNot(before));
      expect(TimerMode.values.contains(timer().mode), isTrue);
    });

    testWidgets('space switches the hand-held signal instead of starting it', (
      tester,
    ) async {
      await pumpApp(tester, startAt: AppScreen.trafficLight);

      bool isGreen() => container.read(trafficLightProvider);
      expect(isGreen(), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(isGreen(), isTrue);
      expect(
        timer().isRunning,
        isFalse,
        reason: 'the traffic light has no countdown to run',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(isGreen(), isFalse);
    });

    testWidgets('the traffic light keeps its keys off the Ampel timer', (
      tester,
    ) async {
      await pumpApp(tester, startAt: AppScreen.trafficLight);

      // R, S and the skip key have nothing to act on here. Without the
      // handler's `ignored` they would fall through to the base class and
      // reach into the timer from a screen that does not show it.
      container.read(timerProvider.notifier).startTimer();
      await tester.pumpAndSettle();
      expect(timer().phase, TimerPhase.preparation);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();

      expect(timer().phase, TimerPhase.preparation);
      expect(currentScreen(), AppScreen.trafficLight);

      await stopTimer(tester);
    });

    testWidgets('nothing below the scope can take the keyboard focus', (
      tester,
    ) async {
      await pumpApp(tester);

      final focusManager = tester.binding.focusManager;
      expect(focusManager.primaryFocus?.debugLabel, 'KeyboardScope');

      // Traversal must not hand focus to one of the on-screen buttons —
      // a focused button would swallow Space and Enter.
      focusManager.primaryFocus!.nextFocus();
      await tester.pumpAndSettle();
      expect(focusManager.primaryFocus?.debugLabel, 'KeyboardScope');

      // ...and keys still arrive at the scope.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(timer().isRunning, isTrue);

      await stopTimer(tester);
    });
  });

  /// Der Wettkampfschirm hat seine eigene Uhr. Die Uhr-Tasten müssen deshalb
  /// die meinen, die man vor sich hat — nicht die Ampel, die im Hintergrund
  /// weiterläuft.
  group('competition screen', () {
    CompetitionState round() => container.read(competitionProvider);

    testWidgets('space starts the round, not the Ampel timer', (tester) async {
      await pumpApp(tester, startAt: AppScreen.competition);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(round().phase, TimerPhase.preparation);
      expect(round().isRunning, isTrue);
      expect(
        timer().isRunning,
        isFalse,
        reason: 'the Ampel timer is a different clock',
      );

      container.read(competitionProvider.notifier).reset();
      await tester.pumpAndSettle();
    });

    testWidgets('P pauses the round and R resets it', (tester) async {
      await pumpApp(tester, startAt: AppScreen.competition);

      container.read(competitionProvider.notifier).start();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();
      expect(round().isPaused, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pumpAndSettle();
      expect(round().phase, TimerPhase.idle);
      expect(round().isPaused, isFalse);
    });

    testWidgets('backspace rewinds one passage', (tester) async {
      await pumpApp(tester, startAt: AppScreen.competition);

      // Bis in die Schusszeit der zweiten Gruppe: Vorbereitung, Schusszeit,
      // Wechsel.
      container.read(competitionProvider.notifier).start();
      await tester.pump(const Duration(seconds: 140));
      await tester.pumpAndSettle();
      expect(round().groupIndex, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(round().groupIndex, 0);
      expect(round().phase, TimerPhase.idle);
      expect(round().isRunning, isFalse);
    });

    testWidgets('delete forwards one passage without starting it', (
      tester,
    ) async {
      await pumpApp(tester, startAt: AppScreen.competition);
      expect(round().groupIndex, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(round().groupIndex, 1);
      expect(round().phase, TimerPhase.idle);
      expect(round().isRunning, isFalse);
    });

    testWidgets('backspace and delete do nothing on the Ampel screen', (
      tester,
    ) async {
      await pumpApp(tester);

      container.read(timerProvider.notifier).startTimer();
      await tester.pumpAndSettle();
      final phase = timer().phase;

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(timer().phase, phase);
      expect(timer().isRunning, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(timer().phase, phase);
      expect(timer().isRunning, isTrue);

      await stopTimer(tester);
    });

    testWidgets('S opens the competition settings', (tester) async {
      await pumpApp(tester, startAt: AppScreen.competition);

      await openSettings(tester);
      expect(currentScreen(), AppScreen.competitionSettings);
      expect(selectedItem(), SettingsItem.competitionDiscipline);

      // Und dieselbe Taste führt wieder heraus — zurück in den Wettkampf,
      // nicht ins Hauptmenü.
      await openSettings(tester);
      expect(currentScreen(), AppScreen.competition);
    });
  });

  /// Auf der LED-Wand fehlt die Tastenleiste, durch die links und rechts sonst
  /// laufen — dort spulen die Pfeiltasten selbst.
  group('competition on the LED wall', () {
    CompetitionState round() => container.read(competitionProvider);

    Future<void> pumpLedRound(WidgetTester tester) async {
      container
          .read(settingsProvider.notifier)
          .setCompetitionDisplay(CompetitionDisplay.led);
      await pumpApp(tester, startAt: AppScreen.competition);
    }

    testWidgets('left rewinds and right forwards a passage', (tester) async {
      await pumpLedRound(tester);
      expect(round().groupIndex, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(round().groupIndex, 1);
      expect(
        round().isRunning,
        isFalse,
        reason: 'vorspulen stellt nur vor, es startet nichts',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(round().groupIndex, 0);
      expect(round().phase, TimerPhase.idle);

      await flushPendingSaves(tester);
    });

    testWidgets('the arrows leave the round alone on the standard screen', (
      tester,
    ) async {
      await pumpApp(tester, startAt: AppScreen.competition);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(
        round().groupIndex,
        0,
        reason: 'dort bewegen die Pfeiltasten die Tastenleiste',
      );
    });

    testWidgets('space still advances the round', (tester) async {
      await pumpLedRound(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(round().phase, TimerPhase.preparation);
      expect(round().isRunning, isTrue);

      container.read(competitionProvider.notifier).reset();
      await tester.pumpAndSettle();
      await flushPendingSaves(tester);
    });

    /// Die Ausgabeart wird bei offener Runde umgestellt — vom Wettkampfschirm
    /// aus mit S, und zurück mit Esc. Der Handler-Provider *watcht* sie
    /// deshalb: ein `read` würde den alten Handler stehen lassen, bis der
    /// Screen das nächste Mal wechselt, und die Pfeiltasten liefen dann noch
    /// gegen eine Leiste, die keiner mehr sieht.
    testWidgets('switching the output swaps the keys on the open round', (
      tester,
    ) async {
      await pumpApp(tester, startAt: AppScreen.competition);

      container
          .read(settingsProvider.notifier)
          .setCompetitionDisplay(CompetitionDisplay.led);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        round().groupIndex,
        1,
        reason: 'auf der Wand spulen die Pfeiltasten sofort',
      );

      container
          .read(settingsProvider.notifier)
          .setCompetitionDisplay(CompetitionDisplay.standard);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        round().groupIndex,
        1,
        reason: 'zurück auf dem Monitor gehört die Taste wieder der Leiste',
      );

      await flushPendingSaves(tester);
    });
  });

  /// U hängt die Uhrzeit über die Schießlinie — und wieder ab. Die einzige
  /// Taste, die nur eine Anzeige umschaltet statt eine Uhr zu bedienen, und
  /// deshalb auch die einzige, die außerhalb des Wettkampfs nichts tut.
  group('the wall clock key', () {
    CompetitionState round() => container.read(competitionProvider);

    /// Nach dem Einschalten der Uhr nicht `pumpAndSettle`: das minütliche
    /// Neustellen der Wanduhr planscht sonst bis zur nächsten vollen Minute.
    Future<void> pressClockKey(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('shows the clock on the competition screen and back', (
      tester,
    ) async {
      await pumpApp(tester, startAt: AppScreen.competition);
      expect(round().showClock, isFalse);

      await pressClockKey(tester);
      expect(round().showClock, isTrue);

      await pressClockKey(tester);
      expect(round().showClock, isFalse);
    });

    testWidgets('works on the LED wall too', (tester) async {
      container
          .read(settingsProvider.notifier)
          .setCompetitionDisplay(CompetitionDisplay.led);
      await pumpApp(tester, startAt: AppScreen.competition);

      await pressClockKey(tester);
      expect(round().showClock, isTrue);

      await flushPendingSaves(tester);
    });

    testWidgets('the start signal takes the display back', (tester) async {
      await pumpApp(tester, startAt: AppScreen.competition);

      await pressClockKey(tester);
      expect(round().showClock, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 600));

      expect(round().phase, TimerPhase.preparation);
      expect(round().showClock, isFalse);

      container.read(competitionProvider.notifier).reset();
      await tester.pumpAndSettle();
    });

    testWidgets('does nothing on the Ampel screen', (tester) async {
      await pumpApp(tester, startAt: AppScreen.timer);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.pumpAndSettle();

      expect(container.read(timerProvider).phase, TimerPhase.idle);
      expect(round().showClock, isFalse);
    });
  });

  /// C zählt bis zum Turnierstart herunter — wie U eine reine Anzeige-Taste,
  /// nur mit einer Uhr dahinter, und deshalb ebenfalls nur im Wettkampf.
  group('the countdown key', () {
    CompetitionState round() => container.read(competitionProvider);

    /// Nach dem Start läuft der Countdown; nicht `pumpAndSettle`, das liefe bis
    /// zu seinem Ende durch.
    Future<void> pressCountdownKey(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('starts and cancels the countdown on the competition screen', (
      tester,
    ) async {
      await pumpApp(tester, startAt: AppScreen.competition);
      expect(round().isCountingDown, isFalse);

      await pressCountdownKey(tester);
      expect(round().isCountingDown, isTrue);

      await pressCountdownKey(tester);
      expect(round().isCountingDown, isFalse);
    });

    testWidgets('works on the LED wall too', (tester) async {
      container
          .read(settingsProvider.notifier)
          .setCompetitionDisplay(CompetitionDisplay.led);
      await pumpApp(tester, startAt: AppScreen.competition);

      await pressCountdownKey(tester);
      expect(round().isCountingDown, isTrue);

      await pressCountdownKey(tester);
      await flushPendingSaves(tester);
    });

    testWidgets('does nothing on the Ampel screen', (tester) async {
      await pumpApp(tester, startAt: AppScreen.timer);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();

      expect(container.read(timerProvider).phase, TimerPhase.idle);
      expect(round().isCountingDown, isFalse);
    });
  });

  /// Vollbild gilt für die ganze App: F11 schaltet dasselbe persistierte
  /// Setting wie die Zeile in den allgemeinen Einstellungen — es gibt keinen
  /// zweiten Zustand, der davon abweichen könnte.
  group('fullscreen', () {
    testWidgets('F11 toggles the fullscreen setting from any screen', (
      tester,
    ) async {
      await pumpApp(tester, startAt: AppScreen.competition);
      expect(settings().fullscreen, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pumpAndSettle();
      expect(settings().fullscreen, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pumpAndSettle();
      expect(settings().fullscreen, isTrue);

      await flushPendingSaves(tester);
    });

    testWidgets('confirm on the fullscreen row toggles the same setting', (
      tester,
    ) async {
      await pumpApp(tester, startAt: AppScreen.generalSettings);
      select(SettingsItem.fullscreen);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(settings().fullscreen, isFalse);

      await flushPendingSaves(tester);
    });
  });

  group('settings selection', () {
    testWidgets('arrow down and up move the selection', (tester) async {
      await pumpApp(tester, startAt: AppScreen.generalSettings);

      expect(selectedItem(), SettingsItem.language);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(selectedItem(), SettingsItem.fullscreen);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(selectedItem(), SettingsItem.language);
    });

    /// Jeder Screen zeigt nur seinen Bereich, also darf das Durchsteppen auch
    /// nur in ihm kreisen — eine Zeile eines anderen Bereichs wäre auf diesem
    /// Screen gar nicht sichtbar und die Auswahl damit verschwunden.
    testWidgets('stepping stays inside the open section', (tester) async {
      await pumpApp(tester, startAt: AppScreen.competitionSettings);

      expect(selectedItem(), SettingsItem.competitionDiscipline);

      final seen = <SettingsItem>{};
      for (var i = 0; i < SettingsItem.values.length; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        seen.add(selectedItem());
      }

      expect(seen, SettingsItem.of(SettingsSection.competition).toSet());
    });

    testWidgets('signal tone and volume are skipped while sound is off', (
      tester,
    ) async {
      await pumpApp(tester, startAt: AppScreen.generalSettings);

      container.read(settingsProvider.notifier).toggleSound();
      expect(settings().soundEnabled, isFalse);

      select(SettingsItem.soundEnabled);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        selectedItem(),
        SettingsItem.resetGeneral,
        reason: 'both disabled sound rows would be dead stops',
      );

      // Und mit Ton sind beide wieder erreichbar.
      container.read(settingsProvider.notifier).toggleSound();
      await tester.pumpAndSettle();
      select(SettingsItem.soundEnabled);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(selectedItem(), SettingsItem.signalTone);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(selectedItem(), SettingsItem.volume);

      await flushPendingSaves(tester);
    });

    /// The selected row is scrolled into view, but only when it is not already
    /// visible. Scrolling on every step used to restart a centring animation
    /// faster than it could finish, so the list crawled behind a held arrow
    /// key. A small window is used on purpose — on the tunnel monitors the list
    /// does not scroll at all, so the guard would never be exercised.
    testWidgets('moving between visible rows does not scroll the list', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(1280, 720));
      await openSettings(tester);

      final list = find.byType(Scrollable).last;
      final position = tester.state<ScrollableState>(list).position;
      expect(
        position.maxScrollExtent,
        greaterThan(0),
        reason: 'the guard is only meaningful while the list can scroll',
      );

      final offsetAtTop = position.pixels;

      // The first rows share the viewport with the selection, so stepping
      // between them must leave the scroll offset alone.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(selectedItem(), SettingsItem.showMilliseconds);
      expect(
        position.pixels,
        offsetAtTop,
        reason: 'a row that is already visible must not move the viewport',
      );

      // Stepping on towards the end of the list must still bring the viewport
      // along. Done key by key on purpose: the list builds its children lazily,
      // so a row far outside the viewport has no context to scroll to yet —
      // walking there is what the keyboard actually does.
      while (selectedItem() != SettingsItem.resetTimer) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }

      expect(
        position.pixels,
        greaterThan(offsetAtTop),
        reason: 'a row outside the viewport must still be scrolled into view',
      );
    });
  });

  group('settings value editing', () {
    testWidgets('arrow keys adjust the selected duration', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      select(SettingsItem.customMainTime);
      final before = settings().customMainTime;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(settings().customMainTime, before + const Duration(seconds: 1));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(settings().customMainTime, before - const Duration(seconds: 1));

      await flushPendingSaves(tester);
    });

    /// Die Anzeigegröße hat als einziger Wert einen Sinn oberhalb dessen, was
    /// passt — die Grenzen sind deshalb das eigentlich Prüfenswerte an ihr.
    testWidgets('arrow keys step the display scale within its range', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      select(SettingsItem.timerScale);
      expect(settings().timerScale, 1.0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(settings().timerScale, closeTo(1.05, 0.0001));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(settings().timerScale, closeTo(0.95, 0.0001));

      // Aus dem Bereich abgeleitet statt geraten: eine feste Zahl würde beim
      // nächsten Verschieben der Grenzen still zu klein werden und den Test
      // dann an einer Stelle scheitern lassen, die nichts damit zu tun hat.
      final stepsAcrossRange =
          ((Settings.maxTimerScale - Settings.minTimerScale) *
                  100 /
                  Settings.timerScaleStepPercent)
              .ceil();

      for (var i = 0; i < stepsAcrossRange; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      }
      await tester.pumpAndSettle();
      expect(settings().timerScale, Settings.maxTimerScale);

      for (var i = 0; i < stepsAcrossRange; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      }
      await tester.pumpAndSettle();
      expect(settings().timerScale, Settings.minTimerScale);

      await flushPendingSaves(tester);
    });

    testWidgets('space toggles the selected switch instead of the timer', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      select(SettingsItem.showMilliseconds);
      expect(settings().showMilliseconds, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(settings().showMilliseconds, isTrue);
      expect(
        timer().isRunning,
        isFalse,
        reason: 'space must not start the timer while the settings are open',
      );

      await flushPendingSaves(tester);
    });

    /// Das Zeitformat steht in beiden Uhr-Bereichen, hängt aber an einem Feld.
    /// Zwei Zeilen auf zwei Zustände wären genau der Fehler, den dieser Test
    /// verhindert.
    testWidgets('both time format rows drive the same setting', (tester) async {
      await pumpApp(tester, startAt: AppScreen.competition);
      await openSettings(tester);
      expect(settings().timeFormat, TimeFormat.minutesSeconds);

      select(SettingsItem.competitionTimeFormat);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(settings().timeFormat, TimeFormat.seconds);

      // Die Ampel-Zeile zeigt denselben Wert und schaltet ihn zurück.
      container
          .read(appStateProvider.notifier)
          .navigateToScreen(AppScreen.timer);
      await tester.pumpAndSettle();
      await openSettings(tester);
      expect(currentScreen(), AppScreen.timerSettings);
      expect(settings().timeFormat, TimeFormat.seconds);

      select(SettingsItem.timeFormat);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(settings().timeFormat, TimeFormat.minutesSeconds);

      await flushPendingSaves(tester);
    });
  });

  group('key repeat', () {
    testWidgets('holding an arrow key keeps stepping the value', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      select(SettingsItem.customMainTime);
      final before = settings().customMainTime;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(
        settings().customMainTime,
        before + const Duration(seconds: 3),
        reason: 'one step for the key down plus one per repeat',
      );

      await flushPendingSaves(tester);
    });

    testWidgets('a long hold widens the step, releasing starts over', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      select(SettingsItem.customMainTime);
      final before = settings().customMainTime;

      // One key down plus enough repeats to leave the first step width behind.
      const repeats = 12;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      for (var i = 0; i < repeats; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      final accelerated = settings().customMainTime - before;
      expect(
        accelerated,
        greaterThan(const Duration(seconds: repeats + 1)),
        reason: 'holding the key must move further than one second per repeat',
      );

      // A real key down ends the run, so the next press is a small step again.
      final afterHold = settings().customMainTime;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(
        settings().customMainTime - afterHold,
        const Duration(seconds: 1),
        reason: 'releasing the key must reset the acceleration',
      );

      await flushPendingSaves(tester);
    });

    testWidgets('holding a non-navigation key does not repeat', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      select(SettingsItem.showMilliseconds);
      expect(settings().showMilliseconds, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(
        settings().showMilliseconds,
        isTrue,
        reason: 'repeats must be ignored, otherwise the switch flips back',
      );

      await flushPendingSaves(tester);
    });

    testWidgets('holding space on the timer screen starts it only once', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      final phaseAfterStart = timer().phase;

      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(
        timer().phase,
        phaseAfterStart,
        reason: 'repeats would otherwise skip through the timer phases',
      );

      await stopTimer(tester);
    });
  });

  group('reset confirmation', () {
    testWidgets('reset needs two confirmations', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      container.read(settingsProvider.notifier).setAlternatingArrows(6);
      await tester.pumpAndSettle();
      expect(settings().alternatingArrows, 6);

      select(SettingsItem.resetTimer);

      // First confirm only arms the row.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(resetArmed(), isTrue);
      expect(settings().alternatingArrows, 6);

      // Second confirm performs the reset.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(resetArmed(), isFalse);
      expect(settings().alternatingArrows, const Settings().alternatingArrows);

      await flushPendingSaves(tester);
    });

    testWidgets('Esc cancels the pending reset without leaving the screen', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      container.read(settingsProvider.notifier).setAlternatingArrows(6);
      await tester.pumpAndSettle();
      select(SettingsItem.resetTimer);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(resetArmed(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(resetArmed(), isFalse);
      expect(settings().alternatingArrows, 6, reason: 'nothing was reset');
      expect(
        currentScreen(),
        AppScreen.timerSettings,
        reason: 'the first Esc is consumed by the confirmation',
      );

      // Only the next Esc leaves.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(currentScreen(), AppScreen.timer);

      await flushPendingSaves(tester);
    });

    testWidgets('moving the selection away cancels the pending reset', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      select(SettingsItem.resetTimer);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(resetArmed(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(resetArmed(), isFalse);
      expect(selectedItem(), isNot(SettingsItem.resetTimer));
    });

    testWidgets('leaving the screen cancels the pending reset', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      select(SettingsItem.resetTimer);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(resetArmed(), isTrue);

      // S verlässt den Screen, ohne die Bestätigung anzufassen — anders als
      // Esc, das sie selbst wegräumt. Trotzdem darf sie den Wechsel nicht
      // überleben.
      await openSettings(tester);
      expect(currentScreen(), AppScreen.timer);

      await openSettings(tester);
      expect(
        resetArmed(),
        isFalse,
        reason: 'a half-given confirmation must not survive a screen change',
      );
      expect(selectedItem(), SettingsItem.defaultMode, reason: 'back on top');
    });
  });
}
