import 'package:flutter/services.dart';

/// defines all possible app actions
enum AppAction {
  // ── Timer ──────────────────────────────────────────────
  toggleTimer, // start/pause timer
  resetTimer, // reset timer
  skipTimer, // skip current timer phase
  next, // context-sensitive next action
  previous, // context-sensitive step back
  forward, // context-sensitive step ahead, without starting anything
  // ── Modi ───────────────────────────────────────────────
  nextMode, // next timer mode
  previousMode, // previous timer mode
  // ── Navigation (Screens) ───────────────────────────────
  toggleMenu, // toggle menu
  toggleSettings, // toggle settings
  back, // back / close
  confirm, // confirm / select
  toggleFullscreen, // toggle fullscreen
  // ── Navigation (innerhalb Screens) ────────────────────
  navigateUp, // move focus up
  navigateDown, // move focus down
  navigateLeft, // move focus left / decrease value
  navigateRight, // move focus right / increase value
}

class KeyboardConfig {
  final Map<LogicalKeyboardKey, AppAction> keyBindings;

  const KeyboardConfig({required this.keyBindings});

  /// default keys
  factory KeyboardConfig.defaults() {
    return KeyboardConfig(
      keyBindings: {
        // Timer controls
        LogicalKeyboardKey.space: AppAction.next,
        // Das Spiegelbild der Leertaste: sie geht vor, Backspace zurück.
        LogicalKeyboardKey.backspace: AppAction.previous,
        // Und das Spiegelbild von Backspace. ⌫/⌦ sind das Tastenpaar zum
        // Umstellen der Runde — beide bewegen nur die Position und lassen die
        // Uhr stehen. Die Leertaste ist deshalb kein Ersatz dafür: sie ist das
        // Startsignal und lässt die Phase wirklich ablaufen.
        LogicalKeyboardKey.delete: AppAction.forward,
        LogicalKeyboardKey.enter: AppAction.confirm,
        LogicalKeyboardKey.keyR: AppAction.resetTimer,
        LogicalKeyboardKey.keyN: AppAction.nextMode,
        LogicalKeyboardKey.keyP: AppAction.toggleTimer,

        // Screen navigation
        LogicalKeyboardKey.escape: AppAction.back,
        LogicalKeyboardKey.keyS: AppAction.toggleSettings,
        LogicalKeyboardKey.keyM: AppAction.toggleMenu,
        LogicalKeyboardKey.f11: AppAction.toggleFullscreen,

        // UI navigation (Pfeiltasten)
        LogicalKeyboardKey.arrowUp: AppAction.navigateUp,
        LogicalKeyboardKey.arrowDown: AppAction.navigateDown,
        LogicalKeyboardKey.arrowLeft: AppAction.navigateLeft,
        LogicalKeyboardKey.arrowRight: AppAction.navigateRight,
      },
    );
  }

  /// gets action for pressed key
  AppAction? getAction(LogicalKeyboardKey key) {
    return keyBindings[key];
  }

  /// change/add key binding for key
  KeyboardConfig addKeyBinding(LogicalKeyboardKey key, AppAction action) {
    final newBindings = Map<LogicalKeyboardKey, AppAction>.from(keyBindings);
    newBindings[key] = action;
    return KeyboardConfig(keyBindings: newBindings);
  }

  /// removes key binding
  KeyboardConfig removeKeyBinding(LogicalKeyboardKey key) {
    final newBindings = Map<LogicalKeyboardKey, AppAction>.from(keyBindings);
    newBindings.remove(key);
    return KeyboardConfig(keyBindings: newBindings);
  }

  /// returns all keys for specific action
  List<LogicalKeyboardKey> getKeysForAction(AppAction action) {
    return keyBindings.entries
        .where((entry) => entry.value == action)
        .map((entry) => entry.key)
        .toList();
  }

  /// returns localized display name for an action
  /// TODO: move to l10n
  static String getActionName(AppAction action) {
    switch (action) {
      case AppAction.toggleTimer:
        return 'Timer pausieren/starten';
      case AppAction.resetTimer:
        return 'Timer zurücksetzen';
      case AppAction.skipTimer:
        return 'Timer überspringen';
      case AppAction.next:
        return 'Timer weiter';
      case AppAction.previous:
        return 'Eine Position zurück';
      case AppAction.forward:
        return 'Eine Position vor';
      case AppAction.nextMode:
        return 'Nächster Modus';
      case AppAction.previousMode:
        return 'Vorheriger Modus';
      case AppAction.toggleMenu:
        return 'Menü öffnen';
      case AppAction.toggleSettings:
        return 'Einstellungen öffnen';
      case AppAction.back:
        return 'Zurück';
      case AppAction.confirm:
        return 'Bestätigen';
      case AppAction.toggleFullscreen:
        return 'Vollbild umschalten';
      case AppAction.navigateUp:
        return 'Navigation: Hoch';
      case AppAction.navigateDown:
        return 'Navigation: Runter';
      case AppAction.navigateLeft:
        return 'Navigation: Links / Wert verringern';
      case AppAction.navigateRight:
        return 'Navigation: Rechts / Wert erhöhen';
    }
  }

  /// returns display name for a key
  static String getKeyName(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) return 'Leertaste';
    if (key == LogicalKeyboardKey.backspace) return '⌫';
    if (key == LogicalKeyboardKey.delete) return '⌦';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.f11) return 'F11';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';

    // for character keys (N, P, etc.) return in UpperCase
    final label = key.keyLabel;

    if (label.length == 1 && _isLetter(label)) {
      return label.toUpperCase();
    }

    return label;
  }

  /// helper method to detect letters
  static bool _isLetter(String char) {
    return char.toUpperCase() != char.toLowerCase();
  }

  /// convert keyboard config to json
  Map<String, dynamic> toJson() {
    final Map<String, String> serializable = {};
    keyBindings.forEach((key, action) {
      serializable[key.keyId.toString()] = action.name;
    });
    return serializable;
  }

  /// create keyboard config from json
  factory KeyboardConfig.fromJson(Map<String, dynamic> json) {
    final Map<LogicalKeyboardKey, AppAction> bindings = {};

    json.forEach((keyIdString, actionName) {
      final keyId = int.tryParse(keyIdString);
      final action = _parseAction(actionName as String);

      if (keyId != null && action != null) {
        bindings[LogicalKeyboardKey(keyId)] = action;
      }
    });

    // Falls keine gültigen Bindings gefunden wurden, nutze Defaults
    if (bindings.isEmpty) {
      return KeyboardConfig.defaults();
    }

    return KeyboardConfig(keyBindings: _withMissingDefaults(bindings));
  }

  /// Ergänzt Standardbelegungen, die in einer gespeicherten Konfiguration noch
  /// gar nicht vorkommen konnten.
  ///
  /// Eine vor einer neuen [AppAction] gespeicherte Konfiguration kennt deren
  /// Taste nicht, und ohne diesen Schritt bliebe die Aktion für den Nutzer für
  /// immer unerreichbar. Ergänzt wird nur, wo weder die Taste noch die Aktion
  /// belegt ist — eine bewusst umgelegte oder entfernte Belegung bleibt damit,
  /// wie sie ist.
  static Map<LogicalKeyboardKey, AppAction> _withMissingDefaults(
    Map<LogicalKeyboardKey, AppAction> stored,
  ) {
    final merged = Map<LogicalKeyboardKey, AppAction>.from(stored);
    final boundActions = stored.values.toSet();

    KeyboardConfig.defaults().keyBindings.forEach((key, action) {
      if (!merged.containsKey(key) && !boundActions.contains(action)) {
        merged[key] = action;
      }
    });

    return merged;
  }

  /// helper method to convert strings to appActions
  static AppAction? _parseAction(String actionName) {
    try {
      return AppAction.values.firstWhere((action) => action.name == actionName);
    } catch (e) {
      return null;
    }
  }
}
