import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';

/// Alles, was das echte Fenster betrifft — an genau einer Stelle.
///
/// Der Rest der App kennt nur das Setting `fullscreen`; dass daraus ein
/// Fensteraufruf wird, weiß nur diese Datei. Auf Web und Mobil gibt es kein
/// Fenster, das man umschalten könnte, deshalb ist dort jeder Aufruf ein
/// No-op statt eines Absturzes im Plugin.
class WindowService {
  const WindowService();

  bool get isSupported =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  /// Bringt das Fenster im gewünschten Zustand hoch, bevor der erste Frame
  /// sichtbar wird — sonst blitzt beim Start kurz ein Fensterrahmen auf.
  Future<void> init(bool fullscreen) async {
    if (!isSupported) return;

    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(title: 'Archery Helper'),
      () async {
        await windowManager.setFullScreen(fullscreen);
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  Future<void> setFullscreen(bool value) async {
    if (!isSupported) return;
    await windowManager.setFullScreen(value);
  }

  /// Beendet die App — der einzige Weg aus dem Kiosk heraus.
  ///
  /// `destroy` statt `close`: ein Schließen-Ereignis, auf das noch jemand
  /// hören könnte, gibt es hier nicht, und der Aufruf kommt ohnehin schon aus
  /// einer bestätigten Abfrage. Auf Web und Mobil gibt es kein Fenster, das man
  /// zumachen könnte — dort passiert wie überall in dieser Datei nichts.
  Future<void> quit() async {
    if (!isSupported) return;
    await windowManager.destroy();
  }
}

const windowService = WindowService();
