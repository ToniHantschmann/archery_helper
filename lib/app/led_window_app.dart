import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../core/theme/app_theme.dart';
import '../core/window/led_window.dart';
import '../models/competition_state.dart';
import '../models/settings.dart';
import '../providers/competition_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/competition_led_screen.dart';

/// Startet das LED-Fenster — `main` ruft das statt `runApp` auf, wenn es als
/// zweites Fenster gestartet wurde.
///
/// Das Fenster ist reine Anzeige: keine Uhr, kein Ton, keine Tastatur, keine
/// Persistenz. Es hält eine Kopie von Runde und Einstellungen, die das
/// Steuerfenster bei jeder Änderung schickt, und zeichnet daraus dasselbe
/// [CompetitionLedScreen] wie früher das Hauptfenster. Die Provider dafür sind
/// dieselben — nur `competitionProvider` und `settingsProvider` sind durch
/// Spiegel ersetzt, alles Abgeleitete läuft unverändert.
Future<void> runLedWindow(
  WindowController window,
  LedWindowArguments arguments,
) async {
  await windowManager.ensureInitialized();
  // Das Fenster gehört zur Ausgabe-Einstellung: der Rahmen versteckt es nur,
  // zerstört wird es erst beim Beenden der App (siehe [LedWindowMethods.quit]).
  await windowManager.setPreventClose(true);
  windowManager.addListener(_HideOnClose());

  ProviderContainer? container;
  LedSnapshot? early;

  void apply(LedSnapshot snapshot) {
    final target = container;
    if (target == null) {
      early = snapshot;
      return;
    }
    (target.read(competitionProvider.notifier) as _MirroredCompetitionNotifier)
        .receive(snapshot.competition);
    (target.read(settingsProvider.notifier) as _MirroredSettingsNotifier)
        .receive(snapshot.settings);
  }

  // Erst den Handler, dann den Stand holen: was dazwischen geschickt wird, ist
  // neuer als die Antwort und gewinnt.
  await window.setWindowMethodHandler((call) async {
    switch (call.method) {
      case LedWindowMethods.snapshot:
        apply(LedSnapshot.decode(call.arguments as String));
      case LedWindowMethods.quit:
        await windowManager.destroy();
      default:
        throw MissingPluginException('LED-Fenster: ${call.method}');
    }
  });
  final pulled = await WindowController.fromWindowId(
    arguments.mainWindowId,
  ).invokeMethod<String>(LedWindowMethods.pull);
  final initial = early ?? LedSnapshot.decode(pulled!);

  container = ProviderContainer(
    overrides: [
      competitionProvider.overrideWith(
        () => _MirroredCompetitionNotifier(initial.competition),
      ),
      settingsProvider.overrideWith(
        () => _MirroredSettingsNotifier(initial.settings),
      ),
    ],
  );

  // Nicht abwarten: gezeigt wird erst, wenn der erste Frame steht — sonst
  // blitzt eine leere Fläche auf.
  unawaited(
    windowManager.waitUntilReadyToShow(
      const WindowOptions(title: 'Archery Helper – LED'),
      windowManager.show,
    ),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const LedWindowApp(),
    ),
  );
}

/// Was das LED-Fenster zeigt. Öffentlich nur für die Layout-Tests, die so
/// genau das Bild prüfen, das auf der Wand landet.
class LedWindowApp extends ConsumerStatefulWidget {
  const LedWindowApp({super.key});

  @override
  ConsumerState<LedWindowApp> createState() => LedWindowAppState();
}

class LedWindowAppState extends ConsumerState<LedWindowApp> {
  bool _fullscreen = false;

  /// Doppelklick statt Taste: die Tastatur gehört dem Steuerfenster, und wer
  /// das Fenster eben mit der Maus auf die Wand gezogen hat, hat sie ohnehin
  /// in der Hand.
  Future<void> _toggleFullscreen() async {
    final next = !_fullscreen;
    await windowManager.setFullScreen(next);
    if (mounted) setState(() => _fullscreen = next);
  }

  @override
  Widget build(BuildContext context) {
    final fit = ref.watch(competitionDisplayProvider).ledFit ?? BoxFit.contain;

    return MaterialApp(
      title: 'Archery Helper – LED',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: GestureDetector(
        onDoubleTap: _toggleFullscreen,
        child: CompetitionLedScreen(fit: fit, hideCursor: _fullscreen),
      ),
    );
  }
}

class _HideOnClose with WindowListener {
  @override
  void onWindowClose() => windowManager.hide();
}

/// Die Runde, wie das Steuerfenster sie zuletzt geschickt hat — ohne eigene
/// Uhr und ohne Blick auf die Einstellungen.
class _MirroredCompetitionNotifier extends CompetitionNotifier {
  final CompetitionState _initial;

  _MirroredCompetitionNotifier(this._initial);

  @override
  CompetitionState build() => _initial;

  void receive(CompetitionState next) => state = next;
}

/// Die Einstellungen des Steuerfensters — ohne Laden und Speichern.
class _MirroredSettingsNotifier extends SettingsNotifier {
  final Settings _initial;

  _MirroredSettingsNotifier(this._initial);

  @override
  Settings build() => _initial;

  void receive(Settings next) => state = next;
}
