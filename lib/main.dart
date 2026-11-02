import 'dart:async';

import 'package:archery_helper/app/led_window_app.dart';
import 'package:archery_helper/core/window/led_window.dart';
import 'package:archery_helper/core/window/window_service.dart';
import 'package:archery_helper/providers/competition_provider.dart';
import 'package:archery_helper/providers/keyboard_config_provider.dart';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:archery_helper/providers/sound_provider.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dieselbe `main` startet auch das LED-Fenster — eine eigene Engine, die
  // nur an ihren Argumenten erkennt, wer sie ist.
  if (windowService.isSupported) {
    final window = await WindowController.fromCurrentEngine();
    final led = LedWindowArguments.tryDecode(window.arguments);
    if (led != null) return runLedWindow(window, led);
  }

  final container = ProviderContainer();

  await container.read(settingsProvider.notifier).loadSettings();
  await container.read(keyboardConfigProvider.notifier).loadConfig();

  // Vollbild ist ein Fenster-Effekt, kein Screen-Effekt: es hängt deshalb am
  // Container und nicht an einem Widget, das mit seinem Screen verschwindet.
  // Der Listener bleibt für die ganze Laufzeit bestehen — ungehörte
  // Zustandsänderungen würden sonst erst im nächsten Build nachgeholt.
  await windowService.init(container.read(fullscreenProvider));
  container.listen(
    fullscreenProvider,
    (_, fullscreen) => windowService.setFullscreen(fullscreen),
  );

  // Die Signale vorladen, damit nicht ausgerechnet der erste Ton der langsamste
  // ist. Bewusst ohne `await`: das Bild über der Schießlinie soll deswegen
  // nicht später kommen, und bis der erste Ton fällt, ist das längst
  // durchgelaufen. Nicht an `soundEnabled` gebunden — Vorladen ist still, und
  // der Ton kann jederzeit eingeschaltet werden.
  //
  // Nur die eingestellte Klangvariante, und beim Umschalten die neue: geladen
  // ist auf Linux gleichbedeutend mit "steht im Lautstärkemixer" (siehe
  // `SoundPlayer.preload`). Der Listener hängt wie der für das Vollbild am
  // Container, weil er die ganze Laufzeit über gelten muss.
  final soundPlayer = container.read(soundPlayerProvider);
  unawaited(soundPlayer.preload(container.read(signalToneProvider)));
  container.listen(
    signalToneProvider,
    (_, tone) => unawaited(soundPlayer.preload(tone)),
  );

  // Das LED-Fenster folgt der Ausgabe-Einstellung des Wettkampfs und bekommt
  // jede Änderung von Runde und Einstellungen geschickt. Wie die Listener
  // darüber am Container, für die ganze Laufzeit.
  await ledWindow.attach(
    () => LedSnapshot(
      competition: container.read(competitionProvider),
      settings: container.read(settingsProvider),
    ),
  );
  void syncLedWindow(bool open) =>
      unawaited(open ? ledWindow.show() : ledWindow.hide());
  syncLedWindow(container.read(competitionDisplayProvider).ledFit != null);
  container.listen(
    competitionDisplayProvider.select((display) => display.ledFit != null),
    (_, open) => syncLedWindow(open),
  );
  container.listen(competitionProvider, (_, _) => ledWindow.push());
  container.listen(settingsProvider, (_, _) => ledWindow.push());

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ArcheryHelperApp(),
    ),
  );
}
