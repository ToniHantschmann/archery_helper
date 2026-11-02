import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../models/keyboard_config.dart';
import '../providers/app_actions_provider.dart';

// Die Bauteile der Einstellungs-Screens, geteilt von `settings_screen.dart` und
// `keyboard_settings_screen.dart`. Sie wissen nicht, welche Zeile sie sind:
// Auswahl und Taps kommen vom Aufrufer, damit beide Screens gleich aussehen,
// ohne dass einer den Navigations-Provider des anderen kennt.

// ===== CHROME =====

class SettingsHeader extends ConsumerWidget {
  final String title;

  const SettingsHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                ref.read(appActionsProvider).handleAction(AppAction.back),
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: AppRadius.md,
                border: Border.all(color: AppPalette.outline, width: 1.5),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 32,
                color: AppPalette.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Der Titel darf schrumpfen, aber nicht umbrechen: „Wettkampf-
          // Einstellungen" passt bei 56sp nicht in ein 1280px-Fenster, und auf
          // den Tunnelmonitoren bleibt es bei der vollen Größe.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                style: AppType.display.copyWith(fontSize: 56),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
        left: AppSpacing.xxs,
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 26,
            decoration: const BoxDecoration(
              color: AppPalette.accent,
              borderRadius: AppRadius.pill,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title.toUpperCase(),
            style: AppType.label.copyWith(color: AppPalette.accentSoft),
          ),
        ],
      ),
    );
  }
}

// ===== ROW SCAFFOLDING =====

/// Shell of a settings row: selection affordance, label block, control.
///
/// The selected row is not merely tinted — it gets a thick accent border, a
/// coloured halo and a filled marker bar. From the shooting line a subtle
/// highlight is simply not there, and this screen is operated by somebody
/// standing at the display, reading it from a few steps away.
///
/// Knows nothing about which row it is: the caller says whether it is
/// selected and what a tap does, so the settings and the key binding screen
/// share one look (and one [AppTheme.selectablePanel]).
class SettingsRowShell extends StatelessWidget {
  final GlobalKey rowKey;
  final bool isSelected;
  final String title;
  final String? subtitle;
  final Widget control;

  /// Disabled rows stay visible but are dimmed and cannot be selected — the
  /// keyboard skips them (volume while sound is off).
  final bool enabled;

  /// Selects the row — only called while [enabled].
  final VoidCallback onTap;

  const SettingsRowShell({
    super.key,
    required this.rowKey,
    required this.isSelected,
    required this.onTap,
    required this.title,
    required this.control,
    this.subtitle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: rowKey,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: AppTheme.selectablePanel(isSelected: isSelected),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: Row(
              children: [
                SelectionMarker(isSelected: isSelected),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppType.body),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(subtitle!, style: AppType.bodySecondary),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                control,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar in front of the selected row. Always occupies its slot so a moving
/// selection does not shift the labels around.
///
/// Fixed size on purpose: animating the height would relayout the row (and the
/// list) in every frame of the highlight, for the same reason the border width
/// is constant — see [AppTheme.selectablePanel]. Only the colour moves.
class SelectionMarker extends StatelessWidget {
  final bool isSelected;

  const SelectionMarker({super.key, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      width: 8,
      height: 56,
      decoration: BoxDecoration(
        color: isSelected ? AppPalette.accent : AppPalette.outline,
        borderRadius: AppRadius.pill,
      ),
    );
  }
}

// ===== RESET =====

class SettingsResetRowShell extends StatelessWidget {
  final GlobalKey rowKey;
  final bool isSelected;

  /// True while the row waits for its second confirmation.
  final bool armed;

  final String label;
  final String confirmTitle;
  final String confirmContent;
  final String cancelLabel;
  final String confirmLabel;

  /// Selects the row and confirms — arms it first, resets on the second call.
  final VoidCallback onActivate;
  final VoidCallback onCancel;

  const SettingsResetRowShell({
    super.key,
    required this.rowKey,
    required this.isSelected,
    required this.armed,
    required this.label,
    required this.confirmTitle,
    required this.confirmContent,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onActivate,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: rowKey,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: armed ? null : onActivate,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          padding: const EdgeInsets.all(AppSpacing.lg),
          // Armed reads as selected in the warning colour, so the row cannot
          // change size between its three states either.
          decoration: AppTheme.selectablePanel(
            isSelected: armed || isSelected,
            color: armed ? AppPalette.caution : AppPalette.accent,
          ),
          child: armed
              ? _ResetConfirmation(
                  title: confirmTitle,
                  content: confirmContent,
                  cancelLabel: cancelLabel,
                  confirmLabel: confirmLabel,
                  onCancel: onCancel,
                  onConfirm: onActivate,
                )
              : Row(
                  children: [
                    SelectionMarker(isSelected: isSelected),
                    const SizedBox(width: AppSpacing.md),
                    const Icon(
                      Icons.restore_rounded,
                      size: 34,
                      color: AppPalette.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(label, style: AppType.body)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ResetConfirmation extends StatelessWidget {
  final String title;
  final String content;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ResetConfirmation({
    required this.title,
    required this.content,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 40,
              color: AppPalette.caution,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: AppType.title.copyWith(color: AppPalette.caution),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(content, style: AppType.bodySecondary),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: onCancel, child: Text(cancelLabel)),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.restore_rounded),
              label: Text(confirmLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.caution,
                foregroundColor: AppPalette.abyss,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
