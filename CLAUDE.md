# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Archery Helper (Bogenampel) — a Flutter app for a target archery club's indoor shooting tunnel, which has two monitors mounted above the shooting line. It currently implements a shot-clock/traffic-light timer for olympic recurve practice, and is meant to grow into a small collection of helper tools for that setup. This is a private hobby project; the author restarted work on it after a longer break (git history goes back further than the recent activity).

The app is built as a desktop-first, keyboard-controlled kiosk display (no mouse/touch interaction expected) — all navigation and timer control flows through `KeyboardConfig`/`AppActionsNotifier`, not widget taps.

## Commands

```bash
flutter pub get              # install dependencies
flutter run -d linux         # run on Linux desktop (or -d windows/macos/chrome)
flutter analyze              # static analysis (flutter_lints via analysis_options.yaml)
flutter test                 # run tests (no test/ directory exists yet)
flutter build linux          # release build; also windows/macos/web as needed
```

Run a single test file with `flutter test test/path/to/file_test.dart`. Widget tests must enlarge the test surface (`tester.view.physicalSize`) — the timer screen's button row overflows the 800x600 default, since the app targets large tunnel monitors. See `test/keyboard_navigation_test.dart`.

## Architecture

State management is **Riverpod** (`flutter_riverpod`), using the newer `Notifier`/`NotifierProvider` API (not `StateNotifier`). The app is bootstrapped in `lib/main.dart` with a manually created `ProviderContainer` so that `settingsProvider` and `keyboardConfigProvider` can be loaded from persistence (`SharedPreferences`) *before* `runApp`, avoiding a flash of default settings.

### Layering

- `lib/models/` — plain immutable data classes (`copyWith`, `toJson`/`fromJson`). No Flutter/Riverpod imports except where enums need `LogicalKeyboardKey` (`keyboard_config.dart`).
- `lib/repositories/` — persistence only, one per model, backed by `shared_preferences` with JSON encoding. Always fall back to defaults on missing/corrupt data rather than throwing.
- `lib/providers/` — Riverpod notifiers holding app state, plus many small derived `Provider`s ("convenience providers") that select a single field out of a bigger state object to minimize widget rebuilds. This pattern is used consistently (`timer_provider.dart`, `settings_provider.dart`, `ui_providers.dart`) — prefer adding a derived provider over watching the whole state object in a widget.
- `lib/core/l10n/` — hand-rolled localization (no `intl`/ARB files). Each screen has its own `*Texts` class (`TimerTexts`, `SettingsTexts`) holding `LocalizedText(de:, en:)` pairs and a `get`/getter API, exposed via a `Provider` that watches `languageProvider` from `settings_provider.dart`. Follow this pattern for new screens rather than introducing `intl`.
- `lib/core/theme/` — the design system. `app_palette.dart` (colour vocabulary), `app_typography.dart` (type scale for distance viewing), `app_dimens.dart` (`AppSpacing`/`AppRadius`/`AppMotion`), `app_theme.dart` (`ThemeData` plus the shared `panel`/`selectedPanel`/`glow` treatments) and `timer_theme.dart` (pure functions mapping `TimerState` to lamp, gradient and colours), exposed via providers in `lib/providers/ui_providers.dart`. Keep visual logic here, not inline in widgets — widgets ask for a decoration, they do not invent colours.
- `lib/screens/`, `lib/widgets/` — UI. One file per screen (`timer_screen.dart`, `settings_screen.dart`, `menu_screen.dart`, `idle_screen.dart`); `app.dart` only holds `MaterialApp` and `AppNavigator`. Shared widgets: `traffic_light.dart` (CustomPainter lamps), `timer_display.dart`, `key_hint_rail.dart` (`KeyCap`/`KeyHint`/`KeyHintRail`), `status_chip.dart`, `debug_panel.dart`. Screens never handle raw key events themselves (see `KeyboardScope` below).

### Central pieces

- **`AppStateNotifier`** (`lib/providers/app_state_provider.dart`) owns which `AppScreen` is shown (`AppNavigator` in `lib/app/app.dart` switches on it) and fullscreen state. This file holds state only — action dispatch lives in `app_actions_provider.dart`, which keeps the dependency one-way and avoids an import cycle.
- **`AppActionsNotifier`** (`lib/providers/app_actions_provider.dart`) is the single dispatch point for all keyboard-driven actions (`AppAction` enum from `keyboard_config.dart`). It handles *global* actions itself (timer controls, screen toggles, fullscreen) and delegates the *screen-dependent* ones (`navigate*`, `confirm`, `next`, `back`, `resetTimer`) to a **`ScreenActionHandler`**. Note `toggleTimer` (play/pause toggle, bound to `P`) and `next` (context-sensitive advance — start/skip/reset, bound to Space) are deliberately separate actions with different semantics, not duplicates.
- **`ScreenActionHandler`** (same file) has one subclass per `AppScreen`; `screenActionHandlerProvider` picks it via an exhaustive switch, so adding an `AppScreen` forces a decision about its key handling. Add screen-specific key behavior by overriding a method there — never with an `if (screen == ...)` inside `AppActionsNotifier`. Base-class defaults mean "this screen ignores it". Arrow keys arrive as a `NavigationDirection` (not an `AppAction`) so handlers switch over four compiler-checked cases without a `default` clause.
- **`TimerNotifier`** (`lib/providers/timer_provider.dart`) runs the actual countdown using a one-shot `Timer` (first tick) followed by a `Timer.periodic` at 100ms resolution, moving through `TimerPhase` (`idle → preparation → active → ended`). `TimerMode` (indoor/outdoor/custom/alternating/trafficLight) determines default prep/main durations; for `custom` mode, prep/main duration come from `settingsProvider` (`customPrepTime`/`customMainTime`) instead of the enum defaults, and the notifier listens to `settingsProvider` to rebuild its state live when those custom values change.
- **`KeyboardConfig`** is a remappable `LogicalKeyboardKey → AppAction` table, persisted like settings; defaults live in `KeyboardConfig.defaults()`. Besides timer/screen actions it also defines `navigateUp/Down/Left/Right` (arrow keys) for in-screen UI navigation.
- **`KeyboardScope`** (`lib/widgets/keyboard_scope.dart`) wraps `AppNavigator` in `app.dart` and is the *only* place raw key events enter the app — every screen is keyboard operable because of it, which matters for a kiosk with no mouse. It re-requests focus on screen changes and forwards `KeyRepeatEvent` so holding an arrow key keeps stepping a value (`AppActionsNotifier._repeatableActions` decides which actions may repeat). Its child is wrapped in `ExcludeFocus`, so no button below can take focus and swallow Space/Enter — the scope structurally keeps the keyboard. Anything pushed as a separate route (dialogs, dropdown overlays) is outside this subtree and needs its own key handling; prefer in-place UI over dialogs for that reason.
- **`SettingsNavigationNotifier`** (`lib/providers/settings_navigation_provider.dart`) owns which settings row is focused (`SettingsItem` enum, in visual order) and translates navigate*/confirm into `settingsProvider` calls. `SettingsScreen` only renders that state; mouse interaction selects the row it acts on so both input paths stay in sync. Rows that cannot be used are skipped while stepping (volume while sound is off). Reset uses a two-step inline confirmation (`resetArmed`) instead of a dialog — a modal route would be invisible to `KeyboardScope`, and arming is real state rather than a one-shot event.
- `SettingsScreen` builds each row as its own small `ConsumerWidget` watching a single convenience provider (plus `isSettingsItemSelectedProvider(item)` for the highlight), so a value change or a moved selection rebuilds only the affected rows. Follow that when adding rows; do not watch the whole `settingsProvider` at screen level.
- **`MenuNavigationNotifier`** (`lib/providers/menu_navigation_provider.dart`) is the same pattern for the menu: it owns the focused `MenuItem`, each item carries the `AppScreen` it opens, and `MenuScreenActions` translates navigate/confirm into it.

### Design constraints that are easy to break

- **No routes.** Dialogs, `DropdownButton` overlays and anything else pushed on the Navigator sit outside `KeyboardScope` and become keyboard-invisible. That is why the settings screen builds its controls (stepper, toggle pill, volume blocks) from plain containers instead of Material's `DropdownButton`/`Switch`/`Slider`, and why reset confirms inline.
- **Distance readability.** The display hangs several meters above the shooting line: the smallest type in use is 20sp, body copy is 26sp+, and the countdown is scaled by a `FittedBox` rather than given a fixed size. Prefer size and contrast over decoration.
- **No looping animation.** Every animation is a finite implicit one (lamp crossfade, selection, gradient). Nothing may move while an archer is at full draw — and a repeating controller would also make `pumpAndSettle` hang in tests.
- **Beware per-tick rebuilds.** The countdown ticks every 100ms. Derived providers must return values that compare equal between ticks (that is why `phaseProgress` is quantised to whole seconds); a provider that changes on every tick repaints the screen ten times a second *and* makes `pumpAndSettle` in the widget tests run until it times out.
- `test/ui_layout_test.dart` pumps every screen at 1920x1080, 2560x1440 and 1280x720 and fails on any `RenderFlex` overflow. Note that a `BoxDecoration` border is laid out as padding — see the diameter maths in `traffic_light.dart`.

### Conventions to note

- German is the default/primary language (`AppLanguage.german`); English is the secondary, always-present translation. Keep both in sync when adding `LocalizedText` entries.
- Some code comments and identifiers are in German (this mirrors the club/domain context); don't feel obligated to translate existing German comments when editing nearby code.
- `flutter analyze` is expected to be clean (zero issues) — keep it that way rather than letting lint noise accumulate.
