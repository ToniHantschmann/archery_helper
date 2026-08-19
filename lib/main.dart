import 'dart:async';

import 'package:archery_helper/core/window/window_service.dart';
import 'package:archery_helper/providers/keyboard_config_provider.dart';
import 'package:archery_helper/providers/settings_provider.dart';
import 'package:archery_helper/providers/sound_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ArcheryHelperApp(),
    ),
  );
}
