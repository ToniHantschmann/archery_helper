import 'package:flutter/material.dart';

/// Spacing scale. One step is 8dp; the halves exist for the inside of small
/// elements (key caps, chips) only.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double huge = 64;
}

/// Corner radii. The app uses fairly generous rounding — on a big panel small
/// radii read as "sharp corners" from a distance and look accidental.
class AppRadius {
  const AppRadius._();

  static const Radius smRadius = Radius.circular(10);
  static const Radius mdRadius = Radius.circular(18);
  static const Radius lgRadius = Radius.circular(28);

  static const BorderRadius sm = BorderRadius.all(smRadius);
  static const BorderRadius md = BorderRadius.all(mdRadius);
  static const BorderRadius lg = BorderRadius.all(lgRadius);
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Motion tokens.
///
/// Deliberately short and deliberately finite: nothing in this app loops. A
/// display above the shooting line must never draw attention while somebody is
/// aiming, so animation is only ever used to make a *state change* legible —
/// it starts, it settles, it stops.
class AppMotion {
  const AppMotion._();

  /// Selection highlights, hover-less feedback.
  static const Duration fast = Duration(milliseconds: 160);

  /// Lamp crossfades, phase colour changes.
  static const Duration medium = Duration(milliseconds: 260);

  /// Background gradient between phases.
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve curve = Curves.easeOutCubic;
}
