import 'package:archery_helper/app/app.dart';
import 'package:archery_helper/models/competition_state.dart';
import 'package:archery_helper/providers/app_state_provider.dart';
import 'package:archery_helper/providers/pointer_hidden_provider.dart';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:archery_helper/screens/competition_led_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Der Mauszeiger an einem Kiosk-Display: weg beim Tippen, zurück beim
/// Bewegen — und auf der LED-Wand grundsätzlich weg.
void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  Future<void> pumpApp(
    WidgetTester tester, {
    AppScreen startAt = AppScreen.menu,
  }) async {
    // Wie in den anderen Widget-Tests: die 800x600 der Testfläche sind viel
    // kleiner als die Tunnelmonitore und würden Zeilen überlaufen lassen.
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

  testWidgets('Zeiger ist beim Start sichtbar', (tester) async {
    await pumpApp(tester);

    expect(container.read(pointerHiddenProvider), isFalse);
  });

  // Getippt wird im Menü, nicht auf der Ampel: eine Taste, die dort eine Uhr
  // startet, hinterlässt einen laufenden Timer, den der Testrahmen als Leck
  // meldet (siehe CLAUDE.md).
  testWidgets('Tastendruck versteckt den Zeiger', (tester) async {
    await pumpApp(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(container.read(pointerHiddenProvider), isTrue);
  });

  testWidgets('auch eine unbelegte Taste versteckt ihn', (tester) async {
    await pumpApp(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.pumpAndSettle();

    expect(container.read(pointerHiddenProvider), isTrue);
  });

  testWidgets('Mausbewegung holt ihn zurück', (tester) async {
    await pumpApp(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(container.read(pointerHiddenProvider), isTrue);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(100, 100));
    await tester.pump();
    await mouse.moveTo(const Offset(400, 400));
    await tester.pumpAndSettle();

    expect(container.read(pointerHiddenProvider), isFalse);
  });

  testWidgets('LED-Wand zeigt nie einen Zeiger', (tester) async {
    container
        .read(settingsProvider.notifier)
        .setCompetitionDisplay(CompetitionDisplay.led);

    await pumpApp(tester, startAt: AppScreen.competition);
    // Das Speichern der Einstellung ist entprellt — abwarten, sonst bleibt
    // sein Timer als vermeintliches Leck stehen.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CompetitionLedScreen), findsOneWidget);

    // Ohne jeden Tastendruck: der Schirm bringt sein eigenes Verstecken mit.
    expect(container.read(pointerHiddenProvider), isFalse);
    final region = tester.widget<MouseRegion>(
      find
          .descendant(
            of: find.byType(CompetitionLedScreen),
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(region.cursor, SystemMouseCursors.none);
  });
}
