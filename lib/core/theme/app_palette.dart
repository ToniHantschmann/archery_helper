import 'package:flutter/material.dart';

/// The colour vocabulary of the app.
///
/// Two rules shaped these values:
///
/// * The screens hang several meters above the shooting line, so everything is
///   built for contrast. There is no "subtle grey on grey" here — the dimmest
///   text tone still sits far above the background.
/// * The three signal colours (red / amber / green) belong to the shooting
///   signal and to nothing else. The interaction accent is therefore a cyan
///   that can never be mistaken for it.
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

  /// Reines Weiß, nur für das formatfüllende Signalwort im Ampel-Modus.
  /// Dort trägt der Hintergrund die Farbe allein — das Wort soll ihr nichts
  /// wegnehmen, auch nicht den leichten Blaustich von [textPrimary].
  static const Color textOnSignal = Color(0xFFFFFFFF);

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
  // Each signal comes as a pair: the saturated core, used to tint the screen,
  // and a lighter version of the same hue for type sitting on that tint.

  static const Color redCore = Color(0xFFFF3B2F);
  static const Color redOnTint = Color(0xFFFF7A63);

  static const Color amberCore = Color(0xFFFFB114);
  static const Color amberOnTint = Color(0xFFFFD166);

  static const Color greenCore = Color(0xFF22D964);
  static const Color greenOnTint = Color(0xFF74F2A3);

  // ===== LED-PANEL =====
  //
  // Die Wand am Außenstand ist 120x80 Pixel groß und leuchtet mit 6500 Nits.
  // Dort gelten die Regeln von oben *nicht*: Schwarz ist hier kein Loch,
  // sondern die ausgeschaltete Diode — die einzige Möglichkeit, die Fläche
  // nicht blenden zu lassen. Und die Signalfarben stehen voll gesättigt, weil
  // eine LED-Wand eine ganz andere Gammakurve hat als ein Monitor: die
  // abgetönten [redCore] & Co. werden dort stumpf statt weich.

  static const Color ledBlack = Color(0xFF000000);
  static const Color ledWhite = Color(0xFFFFFFFF);

  /// Die pausierte Uhr. Auf dem Panel steht kein Phasenwort, also ist die
  /// gedimmte Zahl das Einzige, was „pausiert" überhaupt anzeigen kann.
  static const Color ledDim = Color(0xFF707070);

  static const Color ledRed = Color(0xFFFF0000);
  static const Color ledAmber = Color(0xFFFFB000);
  static const Color ledGreen = Color(0xFF00FF00);

  // ===== STATUS =====

  /// Warnings inside the UI chrome (armed reset, disabled hints). Kept
  /// distinct from [amberCore] so a UI warning never looks like a lamp.
  static const Color caution = Color(0xFFFFC24B);
}
