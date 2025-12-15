import 'package:flutter/services.dart';

/// defines all possible app actions
enum AppAction {
  toggleTimer, // start/pause timer
  resetTimer, // reset timer
  nextMode, // next mode
  previousMode, // previous mode
  toggleMenu, // toggle menu
  toggleSettings, // toggle settings
  back, // back
  confirm,
  toggleFullscreen,
  skipTimer,
  next,
}

class KeyboardConfig {
  final Map<LogicalKeyboardKey, AppAction> keyBindings;

  const KeyboardConfig({required this.keyBindings});

  /// default keys
  factory KeyboardConfig.defaults() {
    return KeyboardConfig(
      keyBindings: {
        LogicalKeyboardKey.space: AppAction.next,
        LogicalKeyboardKey.enter: AppAction.resetTimer,
        LogicalKeyboardKey.escape: AppAction.back,
        LogicalKeyboardKey.keyR: AppAction.resetTimer,
        LogicalKeyboardKey.keyN: AppAction.nextMode,
        LogicalKeyboardKey.keyP: AppAction.toggleTimer,
        LogicalKeyboardKey.keyS: AppAction.toggleSettings,
        LogicalKeyboardKey.keyM: AppAction.toggleMenu,
        LogicalKeyboardKey.f11: AppAction.toggleFullscreen,
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

  /// returns string for given action
  ///TODO: move to l10n
  static String getActionName(AppAction action) {
    switch (action) {
      case AppAction.toggleTimer:
        return 'Timer pausieren/starten';
      case AppAction.resetTimer:
        return 'Timer zurücksetzen';
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
      case AppAction.skipTimer:
        return 'Timer überspringen';
      case AppAction.next:
        return 'Timer weiter';
    }
  }

  /// returns string for the given key
  static String getKeyName(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) return 'Leertaste';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.f11) return 'F11';

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
}
