import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state_provider.dart';

/// Entries of the menu screen, in visual order — the order navigateUp and
/// navigateDown step through.
/// Erste Zeile sind die Werkzeuge, zweite Zeile deren Einstellungen — bei drei
/// Spalten fällt das genau so auseinander, und die Einstellungen stehen unter
/// dem Werkzeug, zu dem sie gehören.
enum MenuItem {
  timer(AppScreen.timer),
  competition(AppScreen.competition),
  idle(AppScreen.idle),
  timerSettings(AppScreen.timerSettings),
  competitionSettings(AppScreen.competitionSettings),
  generalSettings(AppScreen.generalSettings);

  const MenuItem(this.target);

  /// Screen this entry opens.
  final AppScreen target;
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

/// Owns which menu entry is focused.
///
/// Same split as the settings navigation notifier: the notifier holds the
/// selection, the screen only renders it, and the keyboard path and the mouse
/// path both go through here — a menu whose entries could only be reached with
/// a mouse would be unusable on this kiosk.
class MenuNavigationNotifier extends Notifier<MenuItem> {
  @override
  MenuItem build() => MenuItem.timer;

  void select(MenuItem item) => state = item;

  void moveLeft() => _step(-1);

  void moveRight() => _step(1);

  void moveUp() => _stepRow(-1);

  void moveDown() => _stepRow(1);

  /// One tile along the flat order, wrapping around at both ends.
  void _step(int delta) {
    const items = MenuItem.values;
    final nextIndex =
        (items.indexOf(state) + delta + items.length) % items.length;
    state = items[nextIndex];
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

    final index = items.indexOf(state);
    final column = index % columns;
    final rows = (items.length / columns).ceil();

    // Die Spalte bleibt stehen, die Zeile wandert — und läuft am Rand rundum.
    // Eine unvollständige letzte Zeile hat in dieser Spalte keine Kachel; dann
    // geht es in derselben Richtung eine Zeile weiter.
    for (var step = 1; step <= rows; step++) {
      final row = (index ~/ columns + delta * step) % rows;
      final target = row * columns + column;
      if (target < items.length) {
        state = items[target];
        return;
      }
    }
  }
}

final menuNavigationProvider =
    NotifierProvider<MenuNavigationNotifier, MenuItem>(
      () => MenuNavigationNotifier(),
    );

/// Whether a single entry is focused — watched per row so moving the selection
/// rebuilds only the two entries involved.
final isMenuItemSelectedProvider = Provider.family<bool, MenuItem>((ref, item) {
  return ref.watch(menuNavigationProvider) == item;
});
