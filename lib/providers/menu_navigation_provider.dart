import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state_provider.dart';

/// Entries of the menu screen, in visual order — the order navigateUp and
/// navigateDown step through.
///
/// Nur die Werkzeuge und die allgemeinen Einstellungen. Die Ampel- und die
/// Wettkampf-Einstellungen stehen bewusst nicht hier: sie gehören zu ihrem
/// Werkzeug und werden von dort aus mit S geöffnet und mit Esc wieder
/// verlassen — im Hauptmenü wären sie ein zweiter Weg zur selben Sache.
enum MenuItem {
  timer(AppScreen.timer),
  competition(AppScreen.competition),
  trafficLight(AppScreen.trafficLight),
  idle(AppScreen.idle),
  generalSettings(AppScreen.generalSettings),
  quit(null);

  const MenuItem(this.target);

  /// Screen this entry opens — `null` für den einen Eintrag, der keiner ist.
  ///
  /// Beenden ist der einzige Menüpunkt, der nirgendwohin führt. Statt einer
  /// zweiten Liste neben [MenuItem.values], durch die die Pfeiltasten dann
  /// nicht mehr liefen, sagt das fehlende Ziel genau das: „das ist kein
  /// Screen" — und [MenuScreenActions.confirm] entscheidet danach.
  final AppScreen? target;
}

/// How many tiles the menu grid currently puts in one row.
///
/// This is a layout fact, so it is owned by the screen (which measures its own
/// width), not by the navigation notifier — but up/down have to know it, which
/// is why it lives in a provider instead of a local variable.
class MenuColumnsNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void setColumns(int columns) {
    final clamped = columns < 1 ? 1 : columns;
    if (clamped != state) {
      state = clamped;
    }
  }
}

final menuColumnsProvider = NotifierProvider<MenuColumnsNotifier, int>(
  () => MenuColumnsNotifier(),
);

/// Was das Menü an Zustand hat: die Auswahl und die scharfe Beenden-Kachel.
///
/// Wie [SettingsNavState] ein Objekt statt zweier Notifier — die Auswahl zu
/// bewegen entschärft das Beenden, und zwei getrennte Zustände müsste man
/// dafür von Hand synchron halten.
class MenuNavState {
  final MenuItem selected;

  /// True, solange [MenuItem.quit] auf die zweite Bestätigung wartet.
  ///
  /// Echter Zustand, kein einmaliges Ereignis: die Kachel sieht so lange
  /// anders aus, und geräumt wird sie durch Bestätigen, durch Esc oder dadurch,
  /// dass die Auswahl weiterwandert.
  final bool quitArmed;

  const MenuNavState({this.selected = MenuItem.timer, this.quitArmed = false});

  MenuNavState copyWith({MenuItem? selected, bool? quitArmed}) {
    return MenuNavState(
      selected: selected ?? this.selected,
      quitArmed: quitArmed ?? this.quitArmed,
    );
  }
}

/// Owns which menu entry is focused.
///
/// Same split as the settings navigation notifier: the notifier holds the
/// selection, the screen only renders it, and the keyboard path and the mouse
/// path both go through here — a menu whose entries could only be reached with
/// a mouse would be unusable on this kiosk.
class MenuNavigationNotifier extends Notifier<MenuNavState> {
  @override
  MenuNavState build() => const MenuNavState();

  void select(MenuItem item) => _selectItem(item);

  void moveLeft() => _step(-1);

  void moveRight() => _step(1);

  void moveUp() => _stepRow(-1);

  void moveDown() => _stepRow(1);

  /// Stellt das Beenden scharf oder führt es aus — die zweite Stufe meldet sich
  /// mit `true`, damit der Aufrufer das Fenster schließen kann.
  bool armOrConfirmQuit() {
    if (state.quitArmed) {
      state = state.copyWith(quitArmed: false);
      return true;
    }

    state = state.copyWith(quitArmed: true);
    return false;
  }

  /// Entschärft eine wartende Beenden-Abfrage. Meldet, ob es etwas zu
  /// entschärfen gab — sonst bedeutet Esc im Menü weiterhin nichts.
  bool disarmQuit() {
    if (!state.quitArmed) return false;

    state = state.copyWith(quitArmed: false);
    return true;
  }

  /// Jede Bewegung der Auswahl räumt die Abfrage mit weg — ein Schritt auf die
  /// Kachel, auf der man schon steht, ist aber keine Bewegung: sonst würde die
  /// Maus, die über der scharfen Beenden-Kachel wieder hereinfährt, die Abfrage
  /// entschärfen, statt sie stehen zu lassen.
  void _selectItem(MenuItem item) {
    if (item == state.selected) return;

    state = MenuNavState(selected: item);
  }

  /// One tile along the flat order, wrapping around at both ends.
  void _step(int delta) {
    const items = MenuItem.values;
    final nextIndex =
        (items.indexOf(state.selected) + delta + items.length) % items.length;
    _selectItem(items[nextIndex]);
  }

  /// One row up or down, wrapping within the column just like [_step] wraps
  /// within the flat order — an arrow key on a keyboard-only kiosk should never
  /// be a dead stop.
  ///
  /// The column count is read, not watched: watching it would rebuild the
  /// notifier and throw the selection away on every resize.
  void _stepRow(int delta) {
    const items = MenuItem.values;
    final columns = ref.read(menuColumnsProvider);

    // A single row has nothing above or below it, so up/down become a second
    // way to step sideways.
    if (columns >= items.length) {
      _step(delta);
      return;
    }

    final index = items.indexOf(state.selected);
    final column = index % columns;
    final rows = (items.length / columns).ceil();

    // Die Spalte bleibt stehen, die Zeile wandert — und läuft am Rand rundum.
    // Eine unvollständige letzte Zeile hat in dieser Spalte keine Kachel; dann
    // geht es in derselben Richtung eine Zeile weiter.
    for (var step = 1; step <= rows; step++) {
      final row = (index ~/ columns + delta * step) % rows;
      final target = row * columns + column;
      if (target < items.length) {
        _selectItem(items[target]);
        return;
      }
    }
  }
}

final menuNavigationProvider =
    NotifierProvider<MenuNavigationNotifier, MenuNavState>(
      () => MenuNavigationNotifier(),
    );

/// Whether a single entry is focused — watched per row so moving the selection
/// rebuilds only the two entries involved.
final isMenuItemSelectedProvider = Provider.family<bool, MenuItem>((ref, item) {
  return ref.watch(menuNavigationProvider).selected == item;
});

/// Ob die Beenden-Kachel gerade auf ihre zweite Bestätigung wartet.
final isQuitArmedProvider = Provider<bool>((ref) {
  return ref.watch(menuNavigationProvider).quitArmed;
});
