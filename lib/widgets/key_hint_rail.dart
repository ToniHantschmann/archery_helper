import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_typography.dart';

/// One entry of a [KeyHintRail]: the key(s) to press and what they do.
class KeyHint {
  final List<String> keys;
  final String label;

  /// Optional mouse path. The keyboard is the contract; a tap here only ever
  /// triggers the same action the key would, so both paths stay in sync.
  final VoidCallback? onTap;

  /// Marks the hint as the primary action of the screen.
  final bool emphasised;

  const KeyHint({
    required this.keys,
    required this.label,
    this.onTap,
    this.emphasised = false,
  });
}

/// The strip along the bottom edge that says which keys do what.
///
/// The app has no mouse, so the bindings have to be discoverable — but they
/// must not compete with the countdown, hence the muted tones and the smallest
/// type in the app. It wraps instead of scrolling, so a narrow window loses no
/// hint and never overflows.
class KeyHintRail extends StatelessWidget {
  final List<KeyHint> hints;
  final Color accent;

  const KeyHintRail({
    super.key,
    required this.hints,
    this.accent = AppPalette.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: Color(0x66040810),
        border: Border(top: BorderSide(color: AppPalette.outline, width: 1.5)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xl,
        runSpacing: AppSpacing.sm,
        children: [
          for (final hint in hints) _HintEntry(hint: hint, accent: accent),
        ],
      ),
    );
  }
}

class _HintEntry extends StatelessWidget {
  final KeyHint hint;
  final Color accent;

  const _HintEntry({required this.hint, required this.accent});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final key in hint.keys) ...[
          KeyCap(label: key, color: hint.emphasised ? accent : null),
          const SizedBox(width: AppSpacing.xxs),
        ],
        const SizedBox(width: AppSpacing.xs),
        Text(
          hint.label,
          style: AppType.hint.copyWith(
            color:
                hint.emphasised
                    ? AppPalette.textSecondary
                    : AppPalette.textMuted,
            fontWeight: hint.emphasised ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );

    if (hint.onTap == null) return row;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hint.onTap,
      child: row,
    );
  }
}

/// A single key drawn as a physical cap.
class KeyCap extends StatelessWidget {
  final String label;
  final Color? color;

  const KeyCap({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color;

    return Container(
      constraints: const BoxConstraints(minWidth: 46),
      height: 42,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color:
            tint == null
                ? AppPalette.surfaceRaised
                : Color.alphaBlend(
                  tint.withValues(alpha: 0.18),
                  AppPalette.surfaceRaised,
                ),
        borderRadius: AppRadius.sm,
        border: Border.all(
          color: tint ?? AppPalette.outlineStrong,
          width: tint == null ? 1.5 : 2,
        ),
      ),
      child: Text(
        label,
        style: AppType.keyCap.copyWith(
          color: tint == null ? AppPalette.textSecondary : AppPalette.textPrimary,
        ),
      ),
    );
  }
}
