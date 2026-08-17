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

  /// A panel that can hold the keyboard selection — a settings row, a menu
  /// entry. Both states come from this one function on purpose.
  ///
  /// The affordance is deliberately loud: a faint tint is invisible from the
  /// shooting line, so the selected panel gets a clearly lifted background plus
  /// the accent border.
  ///
  /// Two performance rules are baked in here rather than left to the call
  /// sites, because both are invisible until someone notices the app "feels
  /// sluggish":
  ///
  /// * **The border width never changes.** A border is laid out like padding,
  ///   so a width that grew with the selection would relayout the panel — and
  ///   with it the whole list — in every frame of the 160ms highlight. Same
  ///   width, different colour, and the state change stays a repaint.
  /// * **No blurred halo.** The selected panel used to carry a 32px shadow,
  ///   lerped onto two large panels on every selection step. A blur is the most
  ///   expensive thing these screens can paint and ruinous on a software
  ///   rasteriser. Fill and border carry the same meaning for a fraction of the
  ///   cost — the same trade the timer screen made when the drawn traffic light
  ///   gave way to a tinted background.
  ///
  /// [color] is the accent the selected state is drawn in; the reset row uses
  /// [AppPalette.caution] to mark an armed confirmation.
  static BoxDecoration selectablePanel({
    required bool isSelected,
    Color color = AppPalette.accent,
    BorderRadius radius = AppRadius.lg,
  }) {
    return BoxDecoration(
      color:
          isSelected
              ? Color.alphaBlend(
                color.withValues(alpha: 0.22),
                AppPalette.surface,
              )
              : AppPalette.surface,
      borderRadius: radius,
      border: Border.all(
        color: isSelected ? color : AppPalette.outline,
        width: _selectableBorderWidth,
      ),
    );
  }

  /// Shared by both states of [selectablePanel]; see the rule in its docs.
  static const double _selectableBorderWidth = 3;
}
