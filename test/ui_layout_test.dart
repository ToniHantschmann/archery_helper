import 'package:archery_helper/app/app.dart';
import 'package:archery_helper/core/l10n/menu_texts.dart';
import 'package:archery_helper/core/l10n/settings_texts.dart';
import 'package:archery_helper/core/l10n/timer_texts.dart';
import 'package:archery_helper/core/theme/timer_theme.dart';
import 'package:archery_helper/core/window/window_service.dart';
import 'package:archery_helper/models/competition_state.dart';
import 'package:archery_helper/models/settings.dart';
import 'package:archery_helper/models/signal_state.dart';
import 'package:archery_helper/models/timer_state.dart';
import 'package:archery_helper/providers/app_actions_provider.dart';
import 'package:archery_helper/providers/app_state_provider.dart';
import 'package:archery_helper/providers/competition_provider.dart';
import 'package:archery_helper/providers/menu_navigation_provider.dart';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:archery_helper/providers/timer_provider.dart';
import 'package:archery_helper/providers/traffic_light_provider.dart';
import 'package:archery_helper/widgets/led_panel.dart';
import 'package:archery_helper/widgets/timer_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layout guards for the redesign.
///
/// There is no display on the build machine, so "it looks right" cannot be
/// checked here. What can be checked is that every screen lays out without a
/// RenderFlex overflow at the sizes it actually runs at — the two tunnel
/// monitors and a windowed session on a laptop.
void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  /// Sizes the app runs at: 1080p and 1440p kiosk monitors, plus a small
  /// window for development.
  const sizes = <String, Size>{
    '1920x1080': Size(1920, 1080),
    '2560x1440': Size(2560, 1440),
    '1280x720': Size(1280, 720),
  };

  Future<void> pumpScreen(
    WidgetTester tester,
    Size size,
    AppScreen screen,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    container.read(appStateProvider.notifier).navigateToScreen(screen);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ArcheryHelperApp(),
      ),
    );

    // Let the implicit animations (lamp crossfade, gradient, selection) run out
    // without waiting for the idle screen's clock timer, which pumpAndSettle
    // would chase for a full minute.
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Leaves the current screen so widgets holding a timer (the idle clock) are
  /// disposed before the test ends.
  Future<void> leaveScreen(WidgetTester tester) async {
    container.read(appStateProvider.notifier).navigateToScreen(AppScreen.menu);
    await tester.pump();
  }

  group('screens lay out without overflow', () {
    for (final entry in sizes.entries) {
      for (final screen in AppScreen.values) {
        testWidgets('${screen.name} at ${entry.key}', (tester) async {
          await pumpScreen(tester, entry.value, screen);

          expect(
            tester.takeException(),
            isNull,
            reason: '${screen.name} must fit into ${entry.key}',
          );

          await leaveScreen(tester);
        });
      }
    }

    testWidgets('the running timer screen fits while counting down', (
      tester,
    ) async {
      await pumpScreen(tester, const Size(1280, 720), AppScreen.timer);

      container.read(timerProvider.notifier).startTimer();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);

      container.read(timerProvider.notifier).resetTimer();
      await tester.pump();
    });

    /// Die Anzeigegröße wirkt bewusst nur beim Malen: eine vergrößerte Uhr
    /// wird beschnitten, statt das Layout auseinanderzudrücken. Was dieser
    /// Test sichert, ist genau das — das Beschneiden selbst sieht er nicht,
    /// und soll er auch nicht, das entscheidet das Auge im Tunnel.
    for (final entry in sizes.entries) {
      testWidgets('an extreme display scale keeps the layout at ${entry.key}', (
        tester,
      ) async {
        for (final scale in [Settings.maxTimerScale, Settings.minTimerScale]) {
          container.read(settingsProvider.notifier).setTimerScale(scale);
          await pumpScreen(tester, entry.value, AppScreen.timer);

          container.read(timerProvider.notifier).startTimer();
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          expect(
            tester.takeException(),
            isNull,
            reason: 'timer at ${(scale * 100).round()}% must fit ${entry.key}',
          );

          container.read(timerProvider.notifier).resetTimer();
          await tester.pump();
        }

        container.read(settingsProvider.notifier).setTimerScale(1.0);
        // Der Debounce der Einstellungen darf den Test nicht überleben.
        await tester.pump(const Duration(milliseconds: 400));
      });
    }

    /// Die Größe wirkt nur beim Malen, also sagt keine Layoutgröße etwas über
    /// sie aus. `getRect` rechnet die Transformationen der Vorfahren mit und
    /// misst damit genau das, was auf dem Monitor steht.
    testWidgets('the display scale reaches the clock, and only the Ampel', (
      tester,
    ) async {
      // Die Uhr ist der letzte Text der Anzeige; davor steht das Phasenwort.
      final clock = find
          .descendant(
            of: find.byType(TimerDisplay),
            matching: find.byType(Text),
          )
          .last;

      await pumpScreen(tester, const Size(1920, 1080), AppScreen.timer);
      final unscaled = tester.getRect(clock).size;

      container.read(settingsProvider.notifier).setTimerScale(1.5);
      await tester.pump();
      final scaled = tester.getRect(clock).size;

      expect(scaled.height, closeTo(unscaled.height * 1.5, 0.5));
      expect(scaled.width, closeTo(unscaled.width * 1.5, 0.5));

      // Der Wettkampf hat seine eigene Fläche und eine feste LED-Wand daneben;
      // er darf von dieser Einstellung nichts mitbekommen.
      container
          .read(appStateProvider.notifier)
          .navigateToScreen(AppScreen.competition);
      await tester.pump(const Duration(milliseconds: 600));
      final competition = tester.getRect(clock).size;

      container.read(settingsProvider.notifier).setTimerScale(1.0);
      await tester.pump();
      expect(tester.getRect(clock).size, competition);

      // Der Debounce der Einstellungen darf den Test nicht überleben.
      await tester.pump(const Duration(milliseconds: 400));
    });

    for (final entry in sizes.entries) {
      testWidgets('the traffic light screen fits at ${entry.key}', (
        tester,
      ) async {
        // The signal word takes the whole clock area here, so it is scaled up
        // much further than a countdown ever is.
        await pumpScreen(tester, entry.value, AppScreen.trafficLight);

        expect(tester.takeException(), isNull);

        container.read(trafficLightProvider.notifier).toggle();
        await tester.pump(const Duration(milliseconds: 600));

        expect(tester.takeException(), isNull);
      });
    }

    for (final entry in sizes.entries) {
      testWidgets('the alternating screen fits mid-round at ${entry.key}', (
        tester,
      ) async {
        // Widest case of this mode: the long phase word ("Vorbereitung A")
        // next to the arrow chip in the status rail.
        container.read(timerProvider.notifier).setMode(TimerMode.alternating);
        await pumpScreen(tester, entry.value, AppScreen.timer);

        container.read(timerProvider.notifier).startTimer();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);

        // And once the duel is running, on the second archer.
        await tester.pump(const Duration(seconds: 30));
        expect(tester.takeException(), isNull);

        container.read(timerProvider.notifier).resetTimer();
        await tester.pump();
      });
    }

    for (final entry in sizes.entries) {
      testWidgets('the competition screen fits mid-round at ${entry.key}', (
        tester,
      ) async {
        // Widest case: the group rail only has content once a round is running,
        // and the status rail carries the end counter next to the discipline.
        await pumpScreen(tester, entry.value, AppScreen.competition);

        container.read(competitionProvider.notifier).start();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);

        // And on the second group of the end, after the changeover.
        container.read(competitionProvider.notifier).skipPhase();
        container.read(competitionProvider.notifier).skipPhase();
        await tester.pump(const Duration(milliseconds: 600));

        expect(container.read(competitionProvider).groupIndex, 1);
        expect(tester.takeException(), isNull);

        container.read(competitionProvider.notifier).reset();
        await tester.pump();
      });
    }
  });

  /// Die LED-Wand am Außenstand ist 192 × 128 Pixel groß. Der übliche
  /// Overflow-Test greift dort nur halb: eine zu große Schrift *clippt*, und
  /// das ist kein RenderFlex-Overflow. Geprüft wird deshalb, dass die Strings
  /// selbst in ihre Zellen passen — und zwar unabhängig davon, welche Schrift
  /// gerade rechnet (der Testlauf benutzt eine andere als die App).
  group('the LED panel fits its 192x128 grid', () {
    double widthOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

      return painter.width;
    }

    test('every time the round can show fits the clock cell', () {
      // Alle Werte, die eine Runde durchläuft: die Freiluft-Schusszeit, die
      // Hallen-Schusszeit, die Vorbereitung und der Ablauf.
      const durations = [
        Duration(seconds: 240),
        Duration(seconds: 120),
        Duration(seconds: 61),
        Duration(seconds: 60),
        Duration(seconds: 10),
        Duration(seconds: 9),
        Duration.zero,
      ];

      for (final duration in durations) {
        final text = TimerTexts.formatTime(duration);

        expect(
          widthOf(text, LedPanelSpec.timeStyle),
          lessThanOrEqualTo(LedPanelSpec.timeWidth),
          reason: '"$text" muss in die Uhrenzelle passen',
        );
      }
    });

    test('the samples the font size is derived from stay the widest case', () {
      // Die Schriftgröße wird an [timeSamples] bemessen, und die Liste muss
      // jedes Format abdecken — sonst clippt die Umschaltung von „4:00" auf
      // „240" die Anzeige, ohne dass ein Test anschlägt.
      for (final format in TimeFormat.values) {
        expect(LedPanelSpec.timeSamplesByFormat, contains(format));
      }

      for (final sample in LedPanelSpec.timeSamples) {
        expect(
          widthOf(sample, LedPanelSpec.timeStyle),
          lessThanOrEqualTo(LedPanelSpec.timeWidth + 0.01),
          reason: '"$sample" muss in die Uhrenzelle passen',
        );
      }
    });

    test('every format starts centred, and none of them spills out', () {
      // Rechtsbündig steht nur das Format mittig, an dem die Schriftgröße
      // bemessen wurde. Geprüft wird deshalb für *jedes* Format, dass links und
      // rechts gleich viel Luft bleibt — und dass die Verschiebung dabei nie
      // über den Rand des Bandes hinausschiebt.
      for (final format in TimeFormat.values) {
        final sample = LedPanelSpec.timeSamplesByFormat[format]!;
        final width = widthOf(sample, LedPanelSpec.timeStyle);
        final shift = LedPanelSpec.timeShiftX(format);

        // Die Kanten des Blocks im Band: rechtsbündig, dann verschoben.
        final right = LedPanelSpec.timeWidth + shift;
        final left = right - width;

        expect(
          left,
          closeTo(LedPanelSpec.timeWidth - right, 0.01),
          reason: '"$sample" muss mittig im Band stehen',
        );
        expect(shift, lessThanOrEqualTo(0.01));
        expect(left, greaterThanOrEqualTo(-0.01));
      }
    });

    test('the stretched clock fills its band without spilling over it', () {
      expect(
        LedPanelSpec.timeFontSize * LedPanelSpec.timeScaleY,
        closeTo(LedPanelSpec.timeHeight, 0.01),
      );
    });

    test('nothing takes width from the clock', () {
      // Der Anlass des ganzen Rasters: die Streckung ist umgekehrt
      // proportional zur Uhrenbreite, und mit Roboto sind das über die volle
      // Wand nur noch rund 1,10 statt der 2,0 einer Seitenspalte. Die Zahl
      // selbst steht hier bewusst nicht: der Testlauf rechnet mit einer
      // Ersatzschrift, deren Ziffern quadratisch sind, und käme damit auf einen
      // ganz anderen Wert. Prüfbar ist die Ursache — dass der Uhr niemand
      // Breite wegnimmt außer ihren beiden Rändern.
      expect(
        LedPanelSpec.timeWidth,
        LedPanelSpec.width - 2 * LedPanelSpec.timeInset,
      );
      // Und dass sie nach unten wirkt: eine Streckung kleiner als 1 wäre eine
      // Stauchung und hieße, dass die Zelle zu niedrig ist.
      expect(LedPanelSpec.timeScaleY, greaterThanOrEqualTo(1));
    });

    test('the cells add up to the panel', () {
      // Auf einem Pixelraster ist die Summe die Zusicherung, die man nicht im
      // Kopf mitführt: ein Pixel zu viel ist ein halber Zentimeter Wand, der
      // irgendwo abgeschnitten wird.
      expect(
        LedPanelSpec.timeHeight +
            LedPanelSpec.rowGutter +
            LedPanelSpec.rowHeight,
        LedPanelSpec.height,
      );
      // Drei gleiche Zellen gehen nur auf, solange die Wand durch drei teilbar
      // ist — bei einer anderen Panelbreite bliebe sonst ein Pixel offen.
      expect(3 * LedPanelSpec.cellWidth, LedPanelSpec.width);
    });

    test('both labels of the info row are the same size', () {
      // Nebeneinander in einer Zeile liest sich ein Größenunterschied nicht als
      // Rangfolge, sondern als Versehen — vorher war die Gruppe von der
      // Zeilenhöhe begrenzt und der Passenzähler von seiner Zellenbreite, und
      // genau diesen Zufall darf niemand wieder einbauen.
      expect(LedPanelSpec.groupStyle.fontSize, LedPanelSpec.endStyle.fontSize);
    });

    test('every group label fits its cell', () {
      for (final lineup in CompetitionLineup.values) {
        for (final label in lineup.groupLabels) {
          expect(
            widthOf(label, LedPanelSpec.groupStyle),
            lessThanOrEqualTo(LedPanelSpec.labelWidth + 0.01),
            reason: '"$label" muss in die Infozeile passen',
          );
        }
      }
    });

    test('every end counter the round can reach fits its cell', () {
      // Nicht nur die Samples, sondern jede Zahl, die eine Runde annehmen kann:
      // die Zahl mit der breitesten Ziffernfolge ist nicht zwingend die größte.
      for (var current = 1; current <= Settings.maxCompetitionEnds; current++) {
        final text = '$current';

        expect(
          widthOf(text, LedPanelSpec.endStyle),
          lessThanOrEqualTo(LedPanelSpec.labelWidth + 0.01),
          reason: '"$text" muss in die Infozeile passen',
        );
      }
    });

    test('the end sample stays tied to the settings limit', () {
      // Die Schriftgröße ist an [endSamples] bemessen. Wird die Obergrenze in
      // den Einstellungen heraufgesetzt, muss der Zähler mitschrumpfen — der
      // Test schlägt an, wenn das Sample stattdessen stehen bleibt.
      expect(
        LedPanelSpec.endSamples,
        contains('${Settings.maxCompetitionEnds}'),
      );
    });

    test('the nudged clock keeps its digits inside its band', () {
      // Die Versalhöhe steckt in [LedPanelSpec] als Konstante — hier wird
      // nachgerechnet, dass die verschobene Zahl mit ihr oben wie unten noch
      // in der Wand steht.
      final baseline = TextPainter(
        text: TextSpan(text: '4:00', style: LedPanelSpec.timeStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final b = baseline.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );

      final capHeight = 0.711 * LedPanelSpec.timeFontSize;
      final top =
          (b - capHeight) * LedPanelSpec.timeScaleY + LedPanelSpec.timeNudgeY;
      final bottom = b * LedPanelSpec.timeScaleY + LedPanelSpec.timeNudgeY;

      expect(top, greaterThanOrEqualTo(0));
      expect(bottom, lessThanOrEqualTo(LedPanelSpec.timeHeight));
      // Und zwar mittig: oben und unten gleich viel Luft.
      expect(top, closeTo(LedPanelSpec.timeHeight - bottom, 0.01));
    });

    for (final display in [
      CompetitionDisplay.led,
      CompetitionDisplay.ledStretched,
    ]) {
      for (final entry in sizes.entries) {
        testWidgets('${display.name} lays out at ${entry.key}', (tester) async {
          container
              .read(settingsProvider.notifier)
              .setCompetitionDisplay(display);

          await pumpScreen(tester, entry.value, AppScreen.competition);

          container.read(competitionProvider.notifier).start();
          await tester.pump(const Duration(milliseconds: 600));

          expect(tester.takeException(), isNull);
          expect(find.byKey(ledTimeKey), findsOneWidget);
          expect(find.byKey(ledGroupKey), findsOneWidget);
          expect(find.byKey(ledEndKey), findsOneWidget);

          container.read(competitionProvider.notifier).reset();
          // Der Debounce der Einstellungen darf den Test nicht überleben.
          await tester.pump(const Duration(milliseconds: 400));
        });
      }
    }

    testWidgets('the seconds format sits centred on the wall', (tester) async {
      // Die Rechnung oben prüft die Spec, dieser Test die Anzeige: das
      // `Transform` verschiebt erst beim Zeichnen, also muss die gezeichnete
      // Zahl auch wirklich in der Mitte des Panels landen.
      container.read(settingsProvider.notifier)
        ..setTimeFormat(TimeFormat.seconds)
        ..setCompetitionDisplay(CompetitionDisplay.led);

      await pumpScreen(tester, const Size(1920, 1080), AppScreen.competition);

      final panel = tester.getRect(find.byType(LedPanel));
      final time = tester.getRect(find.byKey(ledTimeKey));

      // Gegen die Mitte des gefundenen Panels, nicht gegen 96: das Panel ist
      // aufs Fenster skaliert und sitzt nicht mehr an seinen eigenen Maßen.
      expect(time.center.dx, closeTo(panel.center.dx, 1));

      container
          .read(settingsProvider.notifier)
          .setTimeFormat(TimeFormat.minutesSeconds);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('all together shows no group and no empty cell', (
      tester,
    ) async {
      container.read(settingsProvider.notifier)
        ..setCompetitionLineup(CompetitionLineup.single)
        ..setCompetitionDisplay(CompetitionDisplay.led);

      await pumpScreen(tester, const Size(1920, 1080), AppScreen.competition);

      expect(tester.takeException(), isNull);
      expect(find.byKey(ledTimeKey), findsOneWidget);
      expect(find.byKey(ledGroupKey), findsNothing);
      // Der Passenzähler bleibt: die freigewordene Zelle fällt an die
      // Ampelfläche, sie schiebt nicht die ganze Zeile zur Seite.
      expect(find.byKey(ledEndKey), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  /// Die Steuerkarte überträgt das ganze Monitorbild, also muss das Panel das
  /// Fenster füllen — und zwar genau so, wie der gewählte Wert es verspricht.
  /// Welcher der beiden richtig ist, zeigt sich erst auf der Wand; dass sie
  /// sich unterscheiden, muss hier feststehen, sonst schaltet am Stand jemand
  /// um und sieht keinen Unterschied.
  group('the LED panel fills the window', () {
    for (final entry in sizes.entries) {
      testWidgets('stretched covers the whole window at ${entry.key}', (
        tester,
      ) async {
        container
            .read(settingsProvider.notifier)
            .setCompetitionDisplay(CompetitionDisplay.ledStretched);

        await pumpScreen(tester, entry.value, AppScreen.competition);

        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.byType(LedPanel)),
          Offset.zero & entry.value,
        );

        await leaveScreen(tester);
        await tester.pump(const Duration(milliseconds: 400));
      });

      testWidgets('unstretched keeps 3:2, centred, at ${entry.key}', (
        tester,
      ) async {
        container
            .read(settingsProvider.notifier)
            .setCompetitionDisplay(CompetitionDisplay.led);

        await pumpScreen(tester, entry.value, AppScreen.competition);

        expect(tester.takeException(), isNull);

        final panel = tester.getRect(find.byType(LedPanel));
        final window = Offset.zero & entry.value;

        // Alle drei Fenster sind breiter als 3:2, also gibt die Höhe den
        // Ausschlag und links wie rechts bleibt gleich viel schwarz.
        expect(panel.height, entry.value.height);
        expect(
          panel.width / panel.height,
          closeTo(LedPanelSpec.width / LedPanelSpec.height, 0.01),
        );
        expect(panel.center.dx, closeTo(window.center.dx, 0.01));
        expect(panel.width, lessThanOrEqualTo(entry.value.width));

        await leaveScreen(tester);
        await tester.pump(const Duration(milliseconds: 400));
      });
    }
  });

  /// Die Ausgabe-Zeile trägt den längsten Wert der Wettkampf-Einstellungen.
  /// Der Reihen-Stepper ist nicht dehnbar, ein zu langer Name schiebt die Zeile
  /// also über den Rand — und zwar erst dann, wenn jemand den Wert wählt.
  testWidgets('the longest output value still fits the settings row', (
    tester,
  ) async {
    container
        .read(settingsProvider.notifier)
        .setCompetitionDisplay(CompetitionDisplay.ledStretched);

    await pumpScreen(
      tester,
      const Size(1280, 720),
      AppScreen.competitionSettings,
    );

    expect(tester.takeException(), isNull);

    await leaveScreen(tester);
    await tester.pump(const Duration(milliseconds: 400));
  });

  /// Der Tastenhinweis erscheint erst, wenn eine LED-Variante gewählt ist — er
  /// wächst also in einen Bereich hinein, der ohne ihn schon gemessen war. Die
  /// Zeile ist Fließtext und damit die einzige im Bereich, die mit der Sprache
  /// länger wird; geprüft wird deshalb auf allen drei Größen und mit der
  /// Sichtprüfung, dass der Satz wirklich hängt und der Test nicht ins Leere
  /// läuft.
  group('the LED key note grows the competition settings', () {
    for (final entry in sizes.entries) {
      testWidgets('the note fits below the output row at ${entry.key}', (
        tester,
      ) async {
        container
            .read(settingsProvider.notifier)
            .setCompetitionDisplay(CompetitionDisplay.led);

        await pumpScreen(tester, entry.value, AppScreen.competitionSettings);

        // Auf dem kleinen Fenster liegt die Zeile unter dem Rand und ist damit
        // gar nicht gebaut — die Liste muss erst hin, sonst prüft der Test auf
        // der Größe, auf der es am ehesten klemmt, überhaupt nichts.
        await tester.scrollUntilVisible(
          find.text(container.read(settingsTextsProvider).ledKeysNote),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);

        await leaveScreen(tester);
        await tester.pump(const Duration(milliseconds: 400));
      });
    }

    // Auf 1080p passt der Bereich ohne Scrollen, ein Fehlen ist dort also
    // wirklich ein Fehlen und nicht bloß eine ungebaute Zeile.
    testWidgets('and stays away on the monitor', (tester) async {
      await pumpScreen(
        tester,
        const Size(1920, 1080),
        AppScreen.competitionSettings,
      );

      expect(
        find.text(container.read(settingsTextsProvider).ledKeysNote),
        findsNothing,
      );

      await leaveScreen(tester);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  /// Das Panel bemisst seine Schriftgrößen selbst und rechnet dabei mit einer
  /// bekannten Schrift. Übernähme es Stil aus seiner Umgebung, wäre die Uhr
  /// eine andere als die ausgemessene — abgeschnittene Ziffern fallen aber
  /// erst auf der Wand auf, und dort niemandem, der sie noch ändern kann.
  group('the LED panel ignores the text style around it', () {
    testWidgets('no ancestor decoration leaks into the panel', (tester) async {
      container
          .read(settingsProvider.notifier)
          .setCompetitionDisplay(CompetitionDisplay.led);

      await pumpScreen(tester, const Size(1920, 1080), AppScreen.competition);

      for (final key in [ledTimeKey, ledGroupKey, ledEndKey]) {
        final style = tester.widget<Text>(find.byKey(key)).style!;
        expect(style.inherit, isFalse, reason: '$key erbt vom Umfeld');
        expect(style.decoration ?? TextDecoration.none, TextDecoration.none);
      }

      await leaveScreen(tester);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('the rendered cells still fit their bands', (tester) async {
      container
          .read(settingsProvider.notifier)
          .setCompetitionDisplay(CompetitionDisplay.led);

      await pumpScreen(tester, const Size(1920, 1080), AppScreen.competition);

      // Nicht die Messung aus [LedPanelSpec], sondern was wirklich gezeichnet
      // wurde: nur so schlägt der Test an, wenn die Schrift eine andere ist.
      // [WidgetTester.getSize] misst im Raster des Panels, also unskaliert —
      // in derselben Einheit, in der die Zellen definiert sind.
      expect(
        tester.getSize(find.byKey(ledTimeKey)).width,
        lessThanOrEqualTo(LedPanelSpec.timeWidth + 0.01),
      );
      expect(
        tester.getSize(find.byKey(ledGroupKey)).width,
        lessThanOrEqualTo(LedPanelSpec.labelWidth + 0.01),
      );
      expect(
        tester.getSize(find.byKey(ledEndKey)).width,
        lessThanOrEqualTo(LedPanelSpec.labelWidth + 0.01),
      );

      await leaveScreen(tester);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('menu keyboard wiring', () {
    testWidgets('arrow keys move the selection and Enter opens the entry', (
      tester,
    ) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);

      expect(container.read(menuNavigationProvider).selected, MenuItem.timer);

      // At 1920px the grid is three wide, so down lands on the second row —
      // the standby tile below the timer tile.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(container.read(menuNavigationProvider).selected, MenuItem.idle);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        container.read(menuNavigationProvider).selected,
        MenuItem.generalSettings,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(container.read(currentScreenProvider), AppScreen.generalSettings);
    });

    testWidgets('Esc does nothing — the menu is the home screen', (
      tester,
    ) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(container.read(currentScreenProvider), AppScreen.menu);
    });

    testWidgets('left and right step through a three-column grid', (
      tester,
    ) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);

      expect(
        container.read(menuColumnsProvider),
        3,
        reason: '1920px is wide enough for three tiles in one row',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        container.read(menuNavigationProvider).selected,
        MenuItem.competition,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(container.read(menuNavigationProvider).selected, MenuItem.timer);

      // Left wraps around the flat order, so the last tile is reachable from
      // the first without going through the grid.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(container.read(menuNavigationProvider).selected, MenuItem.quit);
    });

    testWidgets('down moves a whole row once the grid wraps', (tester) async {
      await pumpScreen(tester, const Size(1280, 720), AppScreen.menu);

      expect(
        container.read(menuColumnsProvider),
        2,
        reason: '1280px is too narrow for three readable tiles',
      );

      // Two columns: the tile below the timer is the third entry, not the
      // second.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        container.read(menuNavigationProvider).selected,
        MenuItem.trafficLight,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(container.read(menuNavigationProvider).selected, MenuItem.timer);
    });

    /// Kein Pfeil darf ins Leere gehen: hoch aus der ersten Zeile landet in der
    /// letzten — in derselben Spalte, so wie links/rechts in der Reihenfolge
    /// herumläuft.
    testWidgets('up from the first row wraps within the column', (
      tester,
    ) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(container.read(menuNavigationProvider).selected, MenuItem.idle);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(container.read(menuNavigationProvider).selected, MenuItem.timer);
    });
  });

  /// Beenden ist die einzige Aktion der App, die man nicht rückgängig machen
  /// kann — über der Schießlinie hängt danach ein schwarzer Monitor. Diese
  /// Gruppe hält fest, dass ein einzelner Tastendruck sie nie auslöst.
  group('quit tile', () {
    late _FakeWindowService window;

    setUp(() {
      window = _FakeWindowService();
      container.dispose();
      container = ProviderContainer(
        overrides: [windowServiceProvider.overrideWithValue(window)],
      );
    });

    /// Bringt die Auswahl auf die Beenden-Kachel: sie steht als letzte in der
    /// flachen Reihenfolge, also ist sie einen Schritt links von der ersten.
    Future<void> selectQuit(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(container.read(menuNavigationProvider).selected, MenuItem.quit);
    }

    testWidgets('the first Enter only arms the tile', (tester) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);
      await selectQuit(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(isQuitArmedProvider), isTrue);
      expect(window.quitCount, 0);

      // Und die Kachel sagt es auch: die Abfrage steht dort, wo sonst der Name
      // steht, statt in einem Dialog, den die Tastatur nicht sähe.
      final texts = container.read(menuTextsProvider);
      expect(find.text(texts.quitConfirmTitle), findsOneWidget);
    });

    testWidgets('the second Enter closes the window', (tester) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);
      await selectQuit(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 400));

      expect(window.quitCount, 1);
      expect(container.read(isQuitArmedProvider), isFalse);
    });

    testWidgets('Esc cancels the armed tile', (tester) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);
      await selectQuit(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(isQuitArmedProvider), isFalse);
      expect(window.quitCount, 0);
      expect(container.read(currentScreenProvider), AppScreen.menu);
    });

    /// Wer weiterblättert, hat es sich anders überlegt: die scharfe Kachel darf
    /// nicht scharf bleiben, bis man zufällig wieder auf ihr landet.
    testWidgets('moving the selection cancels the armed tile', (tester) async {
      await pumpScreen(tester, const Size(1920, 1080), AppScreen.menu);
      await selectQuit(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(isQuitArmedProvider), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        window.quitCount,
        0,
        reason: 'das Enter danach stellt wieder nur scharf',
      );
    });
  });

  group('signal semantics', () {
    SignalState stateFor(
      TimerPhase phase, {
      Duration remaining = const Duration(seconds: 60),
    }) {
      return TimerState(
        remainingTime: remaining,
        phase: phase,
        mode: TimerMode.indoor,
        preparationTime: const Duration(seconds: 10),
        mainTime: const Duration(seconds: 120),
      ).signal;
    }

    test('red while nobody may shoot', () {
      expect(
        TimerTheme.signalFor(stateFor(TimerPhase.idle)),
        TrafficSignal.red,
      );
      expect(
        TimerTheme.signalFor(stateFor(TimerPhase.preparation)),
        TrafficSignal.red,
      );
      expect(
        TimerTheme.signalFor(stateFor(TimerPhase.ended)),
        TrafficSignal.red,
        reason: 'a screen with no signal would read as a broken display',
      );
    });

    test('green during the shooting time', () {
      expect(
        TimerTheme.signalFor(stateFor(TimerPhase.active)),
        TrafficSignal.green,
      );
    });

    test('amber once the warning threshold is reached', () {
      expect(
        TimerTheme.signalFor(
          stateFor(TimerPhase.active, remaining: const Duration(seconds: 25)),
        ),
        TrafficSignal.amber,
      );
    });

    test('the hand-switched signal is only ever red or green', () {
      final light = ProviderContainer();
      addTearDown(light.dispose);

      SignalState signal() => light.read(trafficLightSignalProvider);

      expect(TimerTheme.signalFor(signal()), TrafficSignal.red);

      light.read(trafficLightProvider.notifier).toggle();
      expect(
        TimerTheme.signalFor(signal()),
        TrafficSignal.green,
        reason: 'the hand-switched light has no remaining time to warn about',
      );
    });
  });
}

/// Ein Fenster, das sich nur merkt, dass es zumachen sollte. Das echte
/// `destroy()` im Test wäre kein Ergebnis, sondern ein abgebrochener Lauf.
class _FakeWindowService extends WindowService {
  int quitCount = 0;

  @override
  Future<void> quit() async => quitCount++;
}
