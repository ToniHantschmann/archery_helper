import 'package:archery_helper/core/window/window_service.dart';
import 'package:archery_helper/providers/keyboard_config_provider.dart';
import 'package:archery_helper/providers/settings_provider.dart';
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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ArcheryHelperApp(),
    ),
  );
}
