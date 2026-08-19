import 'package:archery_helper/app/app.dart';
import 'package:archery_helper/models/settings_section.dart';
import 'package:archery_helper/providers/app_state_provider.dart';
import 'package:archery_helper/providers/settings_navigation_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Jede Einstellung ändern und danach jeden Schirm ansehen.
///
/// Der Fehler, den das verhindert: ein abgeleiteter Provider, den niemand mehr
/// hört, während sein Wert sich ändert, holt das erst beim nächsten Lesen nach
/// — und das nächste Lesen ist der Aufbau des Schirms, der ihn wieder braucht.
/// Meldet er dabei einem *anderen* dauerhaften Provider einen neuen Wert, wird
/// der Provider-Scope mitten im Build als „muss neu bauen" markiert, und
/// Flutter wirft `setState() called during build`. Die Anzeige-Provider sind
/// deshalb `autoDispose` (siehe `ui_providers.dart`): mit dem Schirm entsorgt,
/// gibt es nichts Verspätetes mehr nachzuholen.
///
/// Das ist keine Testkosmetik, sondern der Weg durch die App, den es im Tunnel
/// wirklich gibt: S, einen Wert verstellen, Esc — und der Schirm über der
/// Schießlinie darf dabei nicht ausfallen.
void main() {
  // Auf dem Werkzeug anfangen und die Einstellungen mit S öffnen: nur dann
  // leben dessen Anzeige-Provider schon, wenn der Wert sich ändert — und genau
  // darauf beruht der Fehler.
  const sectionOrigin = {
    SettingsSection.timer: AppScreen.timer,
    SettingsSection.competition: AppScreen.competition,
    SettingsSection.general: AppScreen.menu,
  };

  const visitable = [
    AppScreen.timer,
    AppScreen.competition,
    AppScreen.trafficLight,
    AppScreen.menu,
    AppScreen.idle,
  ];

  for (final item in SettingsItem.values.where(
    // Die Reset-Zeilen sind keine Werte, sondern eine Bestätigung in zwei
    // Schritten — die stehen in `keyboard_navigation_test.dart`.
    (item) => !item.name.startsWith('reset'),
  )) {
    testWidgets('${item.name} ändern, dann jeden Schirm ansehen', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigator = container.read(appStateProvider.notifier);
      navigator.navigateToScreen(sectionOrigin[item.section]!);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ArcheryHelperApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();

      container.read(settingsNavigationProvider.notifier).select(item);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      for (final screen in visitable) {
        navigator.navigateToScreen(screen);
        await tester.pumpAndSettle();
      }

      // Die Einstellungen werden entprellt geschrieben; den Timer noch
      // ablaufen lassen, sonst meldet das Testframework ihn als Leck.
      await tester.pump(const Duration(milliseconds: 400));
    });
  }
}
