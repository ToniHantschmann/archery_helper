import 'package:flutter/material.dart';

/// The colour vocabulary of the app.
///
/// Two rules shaped these values:
///
/// * The screens hang several meters above the shooting line, so everything is
///   built for contrast. There is no "subtle grey on grey" here — the dimmest
///   text tone still sits far above the background.
/// * The three signal colours (red / amber / green) belong to the traffic
///   light and to nothing else. The interaction accent is therefore a cyan
///   that can never be mistaken for a shooting signal.
///
/// Neutrals are a cool slate rather than flat black: on a large panel a pure
/// `#000` reads as a hole, while a deep blue-grey keeps the surfaces legible
/// and makes the signal colours look brighter than they are.
class AppPalette {
  const AppPalette._();

  // ===== NEUTRALS =====

  /// Darkest tone, used for the outer edges of the background gradients.
  static const Color abyss = Color(0xFF04070C);

  /// Default scaffold background.
  static const Color base = Color(0xFF0A1018);

  /// Panels and cards sitting on [base].
  static const Color surface = Color(0xFF141D2B);

  /// Panels that need to stand out from [surface] (key caps, selected rows).
  static const Color surfaceRaised = Color(0xFF1E2A3B);

  static const Color outline = Color(0xFF2F3F55);
  static const Color outlineStrong = Color(0xFF48607D);

  // ===== TEXT =====

  static const Color textPrimary = Color(0xFFF3F7FF);
  static const Color textSecondary = Color(0xFFC3D0E2);

  /// The dimmest tone we allow. Still ~7:1 against [base] — anything lighter
  /// in weight or darker in tone would disappear from the shooting line.
  static const Color textMuted = Color(0xFF8FA3BC);

  // ===== ACCENT =====

  /// Selection / focus / interactive accent.
  static const Color accent = Color(0xFF32D6F5);
  static const Color accentSoft = Color(0xFF7FE7FB);
  static const Color accentDeep = Color(0xFF0E5C71);

  // ===== SIGNAL COLOURS =====
  //
  // Each lamp comes as a triple: the lit core, the bloom around it, and the
  // colour of the unlit socket (a very dark version of the same hue, so the
  // housing still reads as a traffic light when the lamp is off).

  static const Color redCore = Color(0xFFFF3B2F);
  static const Color redGlow = Color(0xFFFF7A63);
  static const Color redOff = Color(0xFF2E0A0A);

  static const Color amberCore = Color(0xFFFFB114);
  static const Color amberGlow = Color(0xFFFFD166);
  static const Color amberOff = Color(0xFF2C1D04);

  static const Color greenCore = Color(0xFF22D964);
  static const Color greenGlow = Color(0xFF74F2A3);
  static const Color greenOff = Color(0xFF06291A);

  // ===== STATUS =====

  /// Warnings inside the UI chrome (armed reset, disabled hints). Kept
  /// distinct from [amberCore] so a UI warning never looks like a lamp.
  static const Color caution = Color(0xFFFFC24B);
}
