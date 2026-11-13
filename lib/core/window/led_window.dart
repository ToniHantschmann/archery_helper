import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';

import '../../models/competition_state.dart';
import '../../models/settings.dart';
import 'window_service.dart';

/// Was das LED-Fenster zum Zeichnen braucht: die Runde und die Einstellungen.
///
/// Das LED-Fenster ist eine eigene Flutter-Engine mit eigenem Isolate, es
/// teilt mit dem Steuerfenster keinen einzigen Provider. Statt die Uhr dort
/// ein zweites Mal laufen zu lassen, bekommt es bei jeder Änderung den ganzen
/// Stand — die Runde ändert sich ohnehin nur einmal pro angezeigter Sekunde.
class LedSnapshot {
  final CompetitionState competition;
  final Settings settings;

  const LedSnapshot({required this.competition, required this.settings});

  String encode() => jsonEncode({
    'competition': competition.toJson(),
    'settings': settings.toJson(),
  });

  factory LedSnapshot.decode(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return LedSnapshot(
      competition: CompetitionState.fromJson(
        json['competition'] as Map<String, dynamic>,
      ),
      settings: Settings.fromJson(json['settings'] as Map<String, dynamic>),
    );
  }
}

/// Die Methodennamen zwischen den beiden Fenstern — an einer Stelle, damit
/// Sender und Empfänger nicht auseinanderlaufen.
abstract final class LedWindowMethods {
  /// Steuerfenster → LED-Fenster: ein neuer [LedSnapshot].
  static const snapshot = 'snapshot';

  /// LED-Fenster → Steuerfenster: „gib mir den aktuellen Stand".
  static const pull = 'pull';

  /// Steuerfenster → LED-Fenster: die App wird beendet.
  static const quit = 'quit';
}

/// Die Argumente, an denen `main` erkennt, dass es das LED-Fenster startet.
class LedWindowArguments {
  static const _type = 'led';

  /// Wohin das LED-Fenster seine [LedWindowMethods.pull]-Anfrage schickt.
  final String mainWindowId;

  const LedWindowArguments(this.mainWindowId);

  String encode() => jsonEncode({'type': _type, 'main': mainWindowId});

  /// `null` für jedes Fenster, das nicht das LED-Fenster ist — vor allem das
  /// Hauptfenster, dessen Argumente leer sind.
  static LedWindowArguments? tryDecode(String arguments) {
    if (arguments.isEmpty) return null;
    final json = jsonDecode(arguments);
    if (json is! Map || json['type'] != _type) return null;
    return LedWindowArguments(json['main'] as String);
  }
}

/// Die Seite des Steuerfensters: öffnet, versteckt und füttert das LED-Fenster.
///
/// Das einzige Stück der App neben dem LED-Fenster selbst, das
/// `desktop_multi_window` kennt. Positioniert wird nichts — der Bediener zieht
/// das Fenster auf den Monitor der Wand und schaltet dort per Doppelklick ins
/// Vollbild. Das Fenster wird einmal erzeugt und danach nur noch gezeigt und
/// versteckt; so bleibt es beim Hin- und Herschalten der Ausgabe auf dem
/// Monitor, auf den es gezogen wurde.
class LedWindowHost {
  LedSnapshot Function()? _snapshot;
  String? _mainWindowId;
  Future<WindowController>? _window;

  /// Meldet das Steuerfenster als Gegenstelle an. Vor allem anderen aufrufen.
  Future<void> attach(LedSnapshot Function() snapshot) async {
    if (!windowService.isSupported) return;

    _snapshot = snapshot;
    final self = await WindowController.fromCurrentEngine();
    _mainWindowId = self.windowId;
    await self.setWindowMethodHandler((call) async {
      if (call.method == LedWindowMethods.pull) return snapshot().encode();
      throw MissingPluginException('LED-Fenster: ${call.method}');
    });
  }

  /// Zeigt das LED-Fenster, beim ersten Mal wird es erzeugt.
  ///
  /// Ein frisch erzeugtes Fenster zeigt sich selbst, sobald sein erster Frame
  /// steht (siehe `runLedWindow`) — vorher wäre es eine leere Fläche.
  Future<void> show() async {
    final mainWindowId = _mainWindowId;
    if (mainWindowId == null) return;

    final existing = _window;
    if (existing != null) {
      await (await existing).show();
      return;
    }
    _window = WindowController.create(
      WindowConfiguration(arguments: LedWindowArguments(mainWindowId).encode()),
    );
    await _window;
  }

  Future<void> hide() async {
    await (await _window)?.hide();
  }

  /// Schickt den aktuellen Stand. Was dabei verloren geht — etwa solange das
  /// Fenster noch hochfährt —, holt es sich beim Start selbst nach.
  void push() {
    final window = _window;
    final snapshot = _snapshot;
    if (window == null || snapshot == null) return;

    unawaited(() async {
      try {
        await (await window).invokeMethod<void>(
          LedWindowMethods.snapshot,
          snapshot().encode(),
        );
      } on WindowChannelException {
        // Noch kein Handler registriert — der Start holt den Stand per pull.
      }
    }());
  }

  /// Schließt das LED-Fenster endgültig — sonst hielte es den Prozess am
  /// Leben, nachdem das Steuerfenster weg ist.
  Future<void> close() async {
    final window = _window;
    if (window == null) return;
    try {
      await (await window).invokeMethod<void>(LedWindowMethods.quit);
    } on WindowChannelException {
      // Fenster ist schon weg.
    }
  }
}

final ledWindow = LedWindowHost();
