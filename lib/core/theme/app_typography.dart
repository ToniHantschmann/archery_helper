import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Type scale for a display that is read from roughly five meters.
///
/// The scale starts where a desktop app would stop: the smallest style still
/// in use is 20sp, and body copy is 26sp. Sizes step by a factor of about 1.3
/// so two neighbouring levels are clearly distinguishable across the tunnel.
///
/// No custom font is bundled (the kiosk must build offline without assets), so
/// everything uses the platform default. The clock switches on tabular figures
/// instead, which keeps the digits from jittering as the countdown runs.
class AppType {
  const AppType._();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// The countdown itself. Always rendered inside a `FittedBox`, so this size
  /// is a starting point for the scale-down, not a final value.
  static const TextStyle clock = TextStyle(
    fontSize: 240,
    fontWeight: FontWeight.w700,
    height: 0.95,
    letterSpacing: -2,
    color: AppPalette.textPrimary,
    fontFeatures: _tabular,
  );

  /// Wall clock on the idle screen. Lighter than the countdown — it is
  /// information, not an instruction.
  static const TextStyle clockSmall = TextStyle(
    fontSize: 260,
    fontWeight: FontWeight.w300,
    height: 1.0,
    color: AppPalette.textPrimary,
    fontFeatures: _tabular,
  );

  /// Screen titles.
  static const TextStyle display = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w700,
    height: 1.05,
    letterSpacing: -1,
    color: AppPalette.textPrimary,
  );

  /// The phase word above the countdown ("Vorbereitung", "Aktiv", ...).
  static const TextStyle headline = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: 6,
    color: AppPalette.textPrimary,
  );

  /// Section headers, menu entries.
  static const TextStyle title = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppPalette.textPrimary,
  );

  /// Settings row labels.
  static const TextStyle body = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppPalette.textPrimary,
  );

  /// Values, secondary lines.
  static const TextStyle bodySecondary = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: AppPalette.textSecondary,
  );

  /// Chips, badges, mode indicator — all caps, widely tracked.
  static const TextStyle label = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 3,
    color: AppPalette.textSecondary,
  );

  /// Keyboard hints. The smallest style in the app.
  static const TextStyle hint = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppPalette.textMuted,
  );

  /// The letter on a key cap.
  static const TextStyle keyCap = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.0,
    color: AppPalette.textPrimary,
  );
}
