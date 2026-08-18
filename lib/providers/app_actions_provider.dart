import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/keyboard_config.dart';
import '../models/timer_state.dart';
import 'app_state_provider.dart';
import 'competition_provider.dart';
import 'hint_navigation_provider.dart';
import 'keyboard_config_provider.dart';
import 'menu_navigation_provider.dart';
import 'settings_navigation_provider.dart';
import 'settings_provider.dart';
import 'timer_provider.dart';

/// Direction of an in-screen navigation step.
///
/// Deliberately separate from [AppAction]: the mapping from key binding to
/// direction happens once in [AppActionsNotifier], so every handler switches
/// over four cases the compiler can check exhaustively — no `default` clause
/// that would silently swallow a newly added direction.
enum NavigationDirection { up, down, left, right }

/// Per-screen behaviour of the actions whose meaning depends on where you are.
///
/// Everything else (timer controls, screen toggles, fullscreen) is global and
/// stays in [AppActionsNotifier]. Defaults here mean "this screen does not
/// react", so a new screen only overrides what it actually supports.
abstract class ScreenActionHandler {
  const ScreenActionHandler(this.ref);

  final Ref ref;

  /// Arrow keys — in-screen focus movement or value adjustment.
  ///
  /// [isRepeat] marks an auto-repeat event, i.e. the key was not released since
  /// the last call. Handlers that step a value use it to accelerate; a plain
  /// key down ends a run and starts over.
  KeyEventResult navigate(
    NavigationDirection direction, {
    bool isRepeat = false,
  }) => KeyEventResult.ignored;

  /// Confirm / select the focused element.
  KeyEventResult confirm() => KeyEventResult.ignored;

  /// Context-sensitive "further": advance the timer, activate a row, ...
  KeyEventResult next() => KeyEventResult.ignored;

  /// The step back through whatever [next] steps through. Only screens with a
  /// position to return to implement it.
  KeyEventResult previous() => KeyEventResult.ignored;

  /// Der Schritt vor durch dieselbe Reihe — ohne zu starten, anders als [next].
  /// Nur Schirme mit einer Position, auf die man vorstellen kann, setzen ihn um.
  KeyEventResult forward() => KeyEventResult.ignored;

  /// Leave / close.
  KeyEventResult back() => KeyEventResult.ignored;

  /// Reset. Defaults to resetting the Ampel timer, which is what the key means
  /// on every screen — the timer keeps running while you are elsewhere.
  KeyEventResult resetTimer() {
    ref.read(timerProvider.notifier).resetTimer();
    return KeyEventResult.handled;
  }

  /// Play/pause. Wie [resetTimer] eine Uhr-Taste: sie gehört dem Screen, weil es
  /// zwei Uhren gibt (Ampel und Wettkampf) und die Taste immer die meint, die
  /// man vor sich hat.
  KeyEventResult toggleTimer() {
    ref.read(timerProvider.notifier).toggle();
    return KeyEventResult.handled;
  }

  KeyEventResult skipTimer() {
    ref.read(timerProvider.notifier).skipTimerPhase();
    return KeyEventResult.handled;
  }

  /// Öffnet die Einstellungen, die zu diesem Screen gehören.
  ///
  /// Es gibt kein globales Einstellungsmenü mehr — S bedeutet „stell das ein,
  /// was ich gerade vor mir habe". Ohne eigene Einstellungen bleibt der
  /// allgemeine Bereich.
  KeyEventResult openSettings() {
    goTo(AppScreen.generalSettings);
    return KeyEventResult.handled;
  }

  void goTo(AppScreen screen) =>
      ref.read(appStateProvider.notifier).navigateToScreen(screen);
}

class TimerScreenActions extends ScreenActionHandler {
  const TimerScreenActions(super.ref);

  HintNavigationNotifier get _hints =>
      ref.read(timerHintNavigationProvider.notifier);

  /// Left/right step through the bottom hint rail; up/down are unused here.
  @override
  KeyEventResult navigate(
    NavigationDirection direction, {
    bool isRepeat = false,
  }) {
    switch (direction) {
      case NavigationDirection.left:
        _hints.moveLeft();
      case NavigationDirection.right:
        _hints.moveRight();
      case NavigationDirection.up:
      case NavigationDirection.down:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// Fires whichever hint is focused, rather than a fixed toggle — the hint
  /// rail is what left/right now move through, so Enter has to confirm that
  /// selection instead of a hard-coded action.
  @override
  KeyEventResult confirm() {
    _hints.activate();
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult next() {
    ref.read(timerProvider.notifier).advance();
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult openSettings() {
    goTo(AppScreen.timerSettings);
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult back() {
    goTo(AppScreen.menu);
    return KeyEventResult.handled;
  }
}

/// Der Wettkampfschirm.
///
/// Bis auf die Uhr, an der sie hängen, dieselben Tasten wie bei der Ampel: die
/// Uhr-Tasten sind hier auf [competitionProvider] umgebogen, damit der
/// Schießleiter nicht wissen muss, welche der beiden Uhren die Taste gerade
/// meint.
class CompetitionScreenActions extends ScreenActionHandler {
  const CompetitionScreenActions(super.ref);

  HintNavigationNotifier get _hints =>
      ref.read(competitionHintNavigationProvider.notifier);

  CompetitionNotifier get _competition =>
      ref.read(competitionProvider.notifier);

  @override
  KeyEventResult navigate(
    NavigationDirection direction, {
    bool isRepeat = false,
  }) {
    switch (direction) {
      case NavigationDirection.left:
        _hints.moveLeft();
      case NavigationDirection.right:
        _hints.moveRight();
      case NavigationDirection.up:
      case NavigationDirection.down:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult confirm() {
    _hints.activate();
    return KeyEventResult.handled;
  }

  /// Die Taste des Schießleiters: startet, oder lässt die restliche Schusszeit
  /// fallen und übergibt an die nächste Gruppe.
  @override
  KeyEventResult next() {
    _competition.advance();
    return KeyEventResult.handled;
  }

  /// Die Korrekturtaste dazu: einen Schießabschnitt zurück, falls einmal zu oft
  /// weitergedrückt wurde oder eine Gruppe wiederholen muss.
  @override
  KeyEventResult previous() {
    _competition.rewind();
    return KeyEventResult.handled;
  }

  /// Und in die andere Richtung: die Runde vorstellen, ohne sie laufen zu
  /// lassen — für den Wiederanlauf nach einem Absturz.
  @override
  KeyEventResult forward() {
    _competition.fastForward();
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult toggleTimer() {
    _competition.toggle();
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult skipTimer() {
    _competition.skipPhase();
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult resetTimer() {
    _competition.reset();
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult openSettings() {
    goTo(AppScreen.competitionSettings);
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult back() {
    goTo(AppScreen.menu);
    return KeyEventResult.handled;
  }
}

class SettingsScreenActions extends ScreenActionHandler {
  const SettingsScreenActions(super.ref);

  SettingsNavigationNotifier get _navigation =>
      ref.read(settingsNavigationProvider.notifier);

  /// Der Screen, zu dem dieser Einstellungsbereich gehört — und damit der, auf
  /// den Esc zurückführt. Die bereichsspezifischen Einstellungen werden aus
  /// ihrem Werkzeug heraus geöffnet, also muss man auch dorthin zurückkommen
  /// und nicht ins Hauptmenü.
  ///
  /// Der Wildcard-Zweig lässt sich nicht vermeiden — geschaltet wird über
  /// [AppScreen], nicht über die Einstellungs-Screens allein —, er ist aber
  /// bewusst der Rückweg ins Hauptmenü und keine stille Notbremse: kommt ein
  /// vierter Einstellungsbereich dazu, gehört er in diese Liste, sonst führt
  /// sein Esc ins Menü statt zu seinem Werkzeug.
  AppScreen get _origin => switch (ref.read(currentScreenProvider)) {
    AppScreen.timerSettings => AppScreen.timer,
    AppScreen.competitionSettings => AppScreen.competition,
    _ => AppScreen.menu,
  };

  @override
  KeyEventResult navigate(
    NavigationDirection direction, {
    bool isRepeat = false,
  }) {
    switch (direction) {
      case NavigationDirection.up:
        _navigation.moveUp();
      case NavigationDirection.down:
        _navigation.moveDown();
      case NavigationDirection.left:
        _navigation.adjustLeft(isRepeat: isRepeat);
      case NavigationDirection.right:
        _navigation.adjustRight(isRepeat: isRepeat);
    }
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult confirm() {
    _navigation.activate();
    return KeyEventResult.handled;
  }

  /// Space activates the focused row here rather than advancing the timer.
  @override
  KeyEventResult next() => confirm();

  /// S ist auf einem Einstellungs-Screen der Weg zurück — die Taste, die
  /// hierher geführt hat, führt auch wieder heraus.
  @override
  KeyEventResult openSettings() {
    goTo(_origin);
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult back() {
    // A pending reset confirmation is cancelled first — only a second Esc
    // leaves the screen.
    if (_navigation.disarmReset()) {
      return KeyEventResult.handled;
    }

    goTo(_origin);
    return KeyEventResult.handled;
  }
}

class MenuScreenActions extends ScreenActionHandler {
  const MenuScreenActions(super.ref);

  MenuNavigationNotifier get _navigation =>
      ref.read(menuNavigationProvider.notifier);

  @override
  KeyEventResult navigate(
    NavigationDirection direction, {
    bool isRepeat = false,
  }) {
    switch (direction) {
      case NavigationDirection.up:
        _navigation.moveUp();
      case NavigationDirection.down:
        _navigation.moveDown();
      case NavigationDirection.left:
        _navigation.moveLeft();
      case NavigationDirection.right:
        _navigation.moveRight();
    }
    return KeyEventResult.handled;
  }

  @override
  KeyEventResult confirm() {
    goTo(ref.read(menuNavigationProvider).target);
    return KeyEventResult.handled;
  }

  /// Space opens the focused entry here rather than advancing the timer.
  @override
  KeyEventResult next() => confirm();

  // No back(): the menu is the home screen, so there is nothing above it. The
  // base class default (ignored) is the behaviour we want.
}

class IdleScreenActions extends ScreenActionHandler {
  const IdleScreenActions(super.ref);

  /// The idle screen says "press any key", so anything meaningful wakes it —
  /// into the menu, which is where every screen leads back to.
  @override
  KeyEventResult confirm() => _wake();

  @override
  KeyEventResult next() => _wake();

  @override
  KeyEventResult back() => _wake();

  @override
  KeyEventResult openSettings() => _wake();

  KeyEventResult _wake() {
    goTo(AppScreen.menu);
    return KeyEventResult.handled;
  }
}

/// Picks the handler for the current screen. The switch is exhaustive, so
/// adding an [AppScreen] forces a decision about its key handling instead of
/// silently falling through.
final screenActionHandlerProvider = Provider<ScreenActionHandler>((ref) {
  final screen = ref.watch(currentScreenProvider);

  switch (screen) {
    case AppScreen.timer:
      return TimerScreenActions(ref);
    case AppScreen.competition:
      return CompetitionScreenActions(ref);
    case AppScreen.generalSettings:
    case AppScreen.timerSettings:
    case AppScreen.competitionSettings:
      // Alle drei Einstellungs-Screens verhalten sich gleich; welcher Bereich
      // offen ist, weiß der Navigations-Notifier.
      return SettingsScreenActions(ref);
    case AppScreen.menu:
      return MenuScreenActions(ref);
    case AppScreen.idle:
      return IdleScreenActions(ref);
  }
});

/// Single dispatch point for every keyboard-driven action.
///
/// Global actions are handled here; screen-dependent ones are delegated to the
/// [ScreenActionHandler] of the current screen.
class AppActionsNotifier {
  final Ref ref;

  AppActionsNotifier(this.ref);

  /// Actions that may fire repeatedly while a key is held down. Stepping a
  /// value should repeat; starting the timer must not.
  static const _repeatableActions = {
    AppAction.navigateUp,
    AppAction.navigateDown,
    AppAction.navigateLeft,
    AppAction.navigateRight,
  };

  /// [isRepeat] marks auto-repeat events; see [_repeatableActions].
  KeyEventResult handleKeyPress(
    LogicalKeyboardKey key, {
    bool isRepeat = false,
  }) {
    final action = ref.read(keyboardConfigProvider).getAction(key);

    if (action == null) {
      return KeyEventResult.ignored;
    }

    if (isRepeat && !_repeatableActions.contains(action)) {
      return KeyEventResult.ignored;
    }

    return handleAction(action, isRepeat: isRepeat);
  }

  /// [isRepeat] is only forwarded to the navigate* actions — they are the only
  /// repeatable ones, and the only place where "the key is still held" changes
  /// the behaviour (see [ScreenActionHandler.navigate]).
  KeyEventResult handleAction(AppAction action, {bool isRepeat = false}) {
    final screen = ref.read(screenActionHandlerProvider);

    switch (action) {
      // ── Screen-dependent ────────────────────────────────────
      case AppAction.navigateUp:
        return screen.navigate(NavigationDirection.up, isRepeat: isRepeat);
      case AppAction.navigateDown:
        return screen.navigate(NavigationDirection.down, isRepeat: isRepeat);
      case AppAction.navigateLeft:
        return screen.navigate(NavigationDirection.left, isRepeat: isRepeat);
      case AppAction.navigateRight:
        return screen.navigate(NavigationDirection.right, isRepeat: isRepeat);
      case AppAction.confirm:
        return screen.confirm();
      case AppAction.next:
        return screen.next();
      case AppAction.previous:
        return screen.previous();
      case AppAction.forward:
        return screen.forward();
      case AppAction.back:
        return screen.back();
      case AppAction.resetTimer:
        return screen.resetTimer();
      case AppAction.toggleTimer:
        return screen.toggleTimer();
      case AppAction.skipTimer:
        return screen.skipTimer();
      case AppAction.toggleSettings:
        return screen.openSettings();

      // ── Global ──────────────────────────────────────────────

      case AppAction.nextMode:
        _cycleMode(1);
        return KeyEventResult.handled;

      case AppAction.previousMode:
        _cycleMode(-1);
        return KeyEventResult.handled;

      case AppAction.toggleMenu:
        _toggleScreen(AppScreen.menu);
        return KeyEventResult.handled;

      // Vollbild gilt für die ganze App, nicht für einen Screen: die Aktion
      // bleibt deshalb global und schaltet das persistierte Setting, dem das
      // Fenster folgt (siehe `main.dart`).
      case AppAction.toggleFullscreen:
        ref.read(settingsProvider.notifier).toggleFullscreen();
        return KeyEventResult.handled;
    }
  }

  void _cycleMode(int delta) {
    final modes = TimerMode.values;
    final currentIndex = modes.indexOf(ref.read(timerProvider).mode);
    final nextIndex = (currentIndex + delta + modes.length) % modes.length;

    ref.read(timerProvider.notifier).setMode(modes[nextIndex]);
  }

  /// Toggling a screen you are already on returns home, i.e. to the menu.
  void _toggleScreen(AppScreen screen) {
    final current = ref.read(currentScreenProvider);
    ref
        .read(appStateProvider.notifier)
        .navigateToScreen(current == screen ? AppScreen.menu : screen);
  }
}

final appActionsProvider = Provider<AppActionsNotifier>((ref) {
  return AppActionsNotifier(ref);
});
