import 'package:flutter/material.dart';

import 'app_dimens.dart';
import 'app_palette.dart';
import 'app_typography.dart';

/// Assembles the Material theme and the handful of surface treatments the
/// screens share.
///
/// Widgets are not supposed to invent their own colours or shadows: they ask
/// for a decoration here (or for a phase-dependent one in `TimerTheme`), which
/// keeps the visual language in one place — the same reason the phase colours
/// live in `lib/core/theme` instead of inside the timer widgets.
class AppTheme {
  const AppTheme._();

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: AppPalette.accent,
      onPrimary: AppPalette.abyss,
      secondary: AppPalette.accentSoft,
      onSecondary: AppPalette.abyss,
      surface: AppPalette.surface,
      onSurface: AppPalette.textPrimary,
      error: AppPalette.redCore,
      onError: AppPalette.textPrimary,
      outline: AppPalette.outline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.base,
      canvasColor: AppPalette.base,
      dividerColor: AppPalette.outline,
      textTheme: const TextTheme(
        displayLarge: AppType.display,
        headlineLarge: AppType.headline,
        titleLarge: AppType.title,
        bodyLarge: AppType.body,
        bodyMedium: AppType.bodySecondary,
        labelLarge: AppType.label,
        labelSmall: AppType.hint,
      ),
      iconTheme: const IconThemeData(
        color: AppPalette.textSecondary,
        size: 32,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.surfaceRaised,
          foregroundColor: AppPalette.textPrimary,
          textStyle: AppType.body,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.textSecondary,
          textStyle: AppType.body,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
      ),
    );
  }

  // ===== SHARED SURFACE TREATMENTS =====

  /// A panel on the app background.
  static BoxDecoration panel({
    Color color = AppPalette.surface,
    BorderRadius radius = AppRadius.lg,
    Color borderColor = AppPalette.outline,
    double borderWidth = 1.5,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: radius,
      border: Border.all(color: borderColor, width: borderWidth),
    );
  }

  /// A panel that is currently selected. The affordance is deliberately loud —
  /// a tinted background alone is invisible from the shooting line, so the
  /// selected row also gets a thick accent border and a coloured halo.
  static BoxDecoration selectedPanel({
    Color color = AppPalette.accent,
    BorderRadius radius = AppRadius.lg,
  }) {
    return BoxDecoration(
      color: Color.alphaBlend(color.withValues(alpha: 0.14), AppPalette.surface),
      borderRadius: radius,
      border: Border.all(color: color, width: 3),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 32,
          spreadRadius: 1,
        ),
      ],
    );
  }

  /// Soft coloured halo used behind lamps and around active values.
  static List<BoxShadow> glow(Color color, {double strength = 1.0}) {
    if (strength <= 0) return const [];

    return [
      BoxShadow(
        color: color.withValues(alpha: 0.45 * strength),
        blurRadius: 48 * strength,
        spreadRadius: 2 * strength,
      ),
    ];
  }
}
