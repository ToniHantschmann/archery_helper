import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state_provider.dart';

/// Entries of the menu screen, in visual order — the order navigateUp and
/// navigateDown step through.
enum MenuItem {
  timer(AppScreen.timer),
  settings(AppScreen.settings),
  idle(AppScreen.idle);

  const MenuItem(this.target);

  /// Screen this entry opens.
  final AppScreen target;
}

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

  void moveUp() => _move(-1);

  void moveDown() => _move(1);

  void _move(int delta) {
    const items = MenuItem.values;
    final nextIndex =
        (items.indexOf(state) + delta + items.length) % items.length;
    state = items[nextIndex];
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
