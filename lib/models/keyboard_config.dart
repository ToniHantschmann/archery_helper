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
  toggleClock, // show the wall clock instead of the round
  toggleCountdown, // count down to the start of the tournament
  // ── Modi ───────────────────────────────────────────────
  nextMode, // next timer mode
  previousMode, // previous timer mode
  // ── Navigation (Screens) ───────────────────────────────
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

/// Was beim Hinzufügen einer Zusatztaste herausgekommen ist.
enum KeyAssignmentOutcome {
  /// Die Taste war frei und gehört jetzt zur Aktion.
  added,

  /// Die Taste war Zusatztaste einer anderen Aktion ([KeyAssignment.other])
  /// und ist umgehängt worden.
  moved,

  /// Die Taste ist Standardtaste von [KeyAssignment.other] — fest, abgelehnt.
  fixed,

  /// Die Taste gehört schon zu dieser Aktion; es hat sich nichts geändert.
  unchanged,
}

/// Ergebnis von [KeyboardConfig.withExtraKey]: was passiert ist, mit welcher
/// Taste, und bei [KeyAssignmentOutcome.moved]/[KeyAssignmentOutcome.fixed]
/// die Aktion, der die Taste vorher gehörte.
typedef KeyAssignment = ({
  KeyAssignmentOutcome outcome,
  LogicalKeyboardKey key,
  AppAction? other,
});

/// Die Tastenbelegung: eine feste Standardbelegung plus Zusatztasten.
///
/// Die Standardtasten lassen sich nicht wegnehmen oder umlegen, nur ergänzen.
/// Das ist Absicht: auf einer Anzeige ohne Maus kann sich so niemand aussperren
/// (ohne Esc käme man aus keinem Werkzeug mehr heraus), und weil die
/// Standards im Code stehen und nicht im Speicher, gilt eine geänderte
/// Standardbelegung beim nächsten Start ohne Migration. Gespeichert werden
/// nur die [extraBindings] — gedacht für einen Ziffernblock neben der
/// Tastatur.
class KeyboardConfig {
  /// Die Zusatztasten, in der Reihenfolge, in der sie hinzugefügt wurden.
  /// Enthält nie eine Standardtaste.
  final Map<LogicalKeyboardKey, AppAction> extraBindings;

  const KeyboardConfig({this.extraBindings = const {}});

  /// Die feste Standardbelegung.
  static final Map<LogicalKeyboardKey, AppAction> defaultBindings =
      Map.unmodifiable(<LogicalKeyboardKey, AppAction>{
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
        LogicalKeyboardKey.keyM: AppAction.nextMode,
        LogicalKeyboardKey.keyP: AppAction.toggleTimer,
        // U wie Uhr — die einzige Aktion, die eine Anzeige umschaltet statt
        // eine Uhr zu bedienen.
        LogicalKeyboardKey.keyU: AppAction.toggleClock,
        // C wie Countdown — die zweite Anzeige vor dem Turnierstart, und die
        // einzige davon, hinter der eine Uhr läuft.
        LogicalKeyboardKey.keyC: AppAction.toggleCountdown,

        // Screen navigation
        // Esc ist der einzige Rückweg: aus einem Werkzeug ins Hauptmenü, aus
        // dessen Einstellungen zurück zum Werkzeug. Eine zweite Taste nur fürs
        // Menü gab es einmal (M) — sie tat dasselbe wie Esc und nahm dem
        // Timer-Screen den Buchstaben für den Moduswechsel weg.
        LogicalKeyboardKey.escape: AppAction.back,
        LogicalKeyboardKey.keyS: AppAction.toggleSettings,
        LogicalKeyboardKey.f11: AppAction.toggleFullscreen,

        // UI navigation (Pfeiltasten)
        LogicalKeyboardKey.arrowUp: AppAction.navigateUp,
        LogicalKeyboardKey.arrowDown: AppAction.navigateDown,
        LogicalKeyboardKey.arrowLeft: AppAction.navigateLeft,
        LogicalKeyboardKey.arrowRight: AppAction.navigateRight,
      });

  /// Nur die Standardbelegung, ohne Zusatztasten.
  factory KeyboardConfig.defaults() => const KeyboardConfig();

  /// gets action for pressed key — the default binding wins over an extra key
  AppAction? getAction(LogicalKeyboardKey key) {
    return defaultBindings[key] ?? extraBindings[key];
  }

  /// returns all keys for specific action: default keys first, so the hint
  /// rails (which show the first one) keep showing the familiar key
  List<LogicalKeyboardKey> getKeysForAction(AppAction action) {
    return [...defaultKeysFor(action), ...extraKeysFor(action)];
  }

  List<LogicalKeyboardKey> defaultKeysFor(AppAction action) =>
      _keysOf(defaultBindings, action);

  List<LogicalKeyboardKey> extraKeysFor(AppAction action) =>
      _keysOf(extraBindings, action);

  bool isDefaultKey(LogicalKeyboardKey key) => defaultBindings.containsKey(key);

  static List<LogicalKeyboardKey> _keysOf(
    Map<LogicalKeyboardKey, AppAction> bindings,
    AppAction action,
  ) => [
    for (final entry in bindings.entries)
      if (entry.value == action) entry.key,
  ];

  /// Hängt [key] als Zusatztaste an [action].
  ///
  /// Eine Standardtaste wird abgelehnt, eine Zusatztaste einer anderen Aktion
  /// umgehängt — eine Taste löst immer genau eine Aktion aus.
  (KeyboardConfig, KeyAssignment) withExtraKey(
    LogicalKeyboardKey key,
    AppAction action,
  ) {
    final owner = defaultBindings[key];
    if (owner != null) {
      return (
        this,
        (
          outcome: owner == action
              ? KeyAssignmentOutcome.unchanged
              : KeyAssignmentOutcome.fixed,
          key: key,
          other: owner,
        ),
      );
    }

    final previous = extraBindings[key];
    if (previous == action) {
      return (
        this,
        (outcome: KeyAssignmentOutcome.unchanged, key: key, other: action),
      );
    }

    // Entfernen und neu einfügen, damit eine umgehängte Taste bei ihrer neuen
    // Aktion hinten steht — dort, wo „zuletzt hinzugefügt" sie erwartet.
    final bindings = Map<LogicalKeyboardKey, AppAction>.from(extraBindings)
      ..remove(key)
      ..[key] = action;

    return (
      KeyboardConfig(extraBindings: bindings),
      (
        outcome: previous == null
            ? KeyAssignmentOutcome.added
            : KeyAssignmentOutcome.moved,
        key: key,
        other: previous,
      ),
    );
  }

  /// Entfernt die zuletzt hinzugefügte Zusatztaste von [action] — die
  /// Standardtasten bleiben, sie sind fest.
  KeyboardConfig withoutLastExtraKey(AppAction action) {
    final keys = extraKeysFor(action);
    if (keys.isEmpty) return this;

    final bindings = Map<LogicalKeyboardKey, AppAction>.from(extraBindings)
      ..remove(keys.last);
    return KeyboardConfig(extraBindings: bindings);
  }

  KeyboardConfig withoutExtraKeys() => const KeyboardConfig();

  /// Kurze Beschriftungen für den Ziffernblock: `keyLabel` hieße dort
  /// „Numpad Add", und das passt auf keine Tastenkappe.
  static final Map<LogicalKeyboardKey, String> _numpadNames = {
    LogicalKeyboardKey.numpadAdd: 'Num +',
    LogicalKeyboardKey.numpadSubtract: 'Num −',
    LogicalKeyboardKey.numpadMultiply: 'Num ×',
    LogicalKeyboardKey.numpadDivide: 'Num ÷',
    LogicalKeyboardKey.numpadDecimal: 'Num ,',
    LogicalKeyboardKey.numpadComma: 'Num ,',
    LogicalKeyboardKey.numpadEnter: 'Num ↵',
    LogicalKeyboardKey.numpadEqual: 'Num =',
    LogicalKeyboardKey.numpad0: 'Num 0',
    LogicalKeyboardKey.numpad1: 'Num 1',
    LogicalKeyboardKey.numpad2: 'Num 2',
    LogicalKeyboardKey.numpad3: 'Num 3',
    LogicalKeyboardKey.numpad4: 'Num 4',
    LogicalKeyboardKey.numpad5: 'Num 5',
    LogicalKeyboardKey.numpad6: 'Num 6',
    LogicalKeyboardKey.numpad7: 'Num 7',
    LogicalKeyboardKey.numpad8: 'Num 8',
    LogicalKeyboardKey.numpad9: 'Num 9',
  };

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

    final numpad = _numpadNames[key];
    if (numpad != null) return numpad;

    // for character keys (N, P, etc.) return in UpperCase
    final label = key.keyLabel;

    if (label.length == 1 && _isLetter(label)) {
      return label.toUpperCase();
    }

    // Eine Taste ohne Beschriftung (manche Sondertasten eines Ziffernblocks)
    // braucht trotzdem eine Kappe, sonst stünde dort ein leeres Kästchen.
    if (label.trim().isEmpty) {
      return key.debugName ?? '#${key.keyId.toRadixString(16)}';
    }

    return label;
  }

  /// helper method to detect letters
  static bool _isLetter(String char) {
    return char.toUpperCase() != char.toLowerCase();
  }

  /// Nur die Zusatztasten — die Standardbelegung steht im Code.
  Map<String, dynamic> toJson() {
    return {
      for (final entry in extraBindings.entries)
        entry.key.keyId.toString(): entry.value.name,
    };
  }

  /// create keyboard config from json
  ///
  /// Fällt weg, was sich nicht mehr zuordnen lässt: eine unbekannte Aktion,
  /// und eine Taste, die inzwischen zur Standardbelegung gehört — der Standard
  /// gewinnt ohnehin, als Zusatztaste wäre sie nur noch eine falsche Kappe.
  factory KeyboardConfig.fromJson(Map<String, dynamic> json) {
    final Map<LogicalKeyboardKey, AppAction> bindings = {};

    json.forEach((keyIdString, actionName) {
      final keyId = int.tryParse(keyIdString);
      final action = actionName is String ? _parseAction(actionName) : null;
      if (keyId == null || action == null) return;

      final key = LogicalKeyboardKey(keyId);
      if (defaultBindings.containsKey(key)) return;

      bindings[key] = action;
    });

    return KeyboardConfig(extraBindings: bindings);
  }

  /// helper method to convert strings to appActions
  static AppAction? _parseAction(String actionName) {
    for (final action in AppAction.values) {
      if (action.name == actionName) return action;
    }
    return null;
  }
}
