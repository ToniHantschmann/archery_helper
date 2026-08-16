import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/settings_texts.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../models/keyboard_config.dart';
import '../providers/app_actions_provider.dart';
import '../providers/settings_navigation_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ui_providers.dart';
import '../widgets/key_hint_rail.dart';

/// Settings screen.
///
/// Fully keyboard operable: the selected row lives in
/// [settingsNavigationProvider] and is driven by the navigate* actions coming
/// from KeyboardScope → AppActionsNotifier → SettingsScreenActions. The widgets
/// below only render that state; they never handle raw key events themselves.
/// Mouse interaction is kept for testing and always selects the row it acts on,
/// so both input paths stay in sync.
///
/// Every control is built from plain containers instead of Material's
/// `DropdownButton`, `Switch` or `Slider`. Two reasons, and both matter here:
/// a dropdown opens an overlay route that the app-wide keyboard scope cannot
/// reach, and Material's controls are sized for a mouse at arm's length, not
/// for a monitor five meters above the shooting line.
///
/// Each row is its own [ConsumerWidget] watching a single convenience provider,
/// so changing one value or moving the selection rebuilds only what changed —
/// not the whole list.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// One key per row so the selected row can be scrolled into view.
  final Map<SettingsItem, GlobalKey> _itemKeys = {
    for (final item in SettingsItem.values) item: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    // Always start at the top when the screen is entered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(settingsNavigationProvider.notifier).reset();
    });
  }

  void _ensureVisible(SettingsItem item) {
    final itemContext = _itemKeys[item]?.currentContext;
    if (itemContext == null) return;

    Scrollable.ensureVisible(
      itemContext,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: 0.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only the texts are watched here: a language switch legitimately rebuilds
    // the whole screen, everything else is watched per row.
    final texts = ref.watch(settingsTextsProvider);

    // Keep the keyboard selection inside the viewport.
    ref.listen(selectedSettingsItemProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible(next));
    });

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppPalette.base, AppPalette.abyss],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _SettingsHeader(title: texts.screenTitle),

              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.xs,
                        AppSpacing.xl,
                        AppSpacing.xl,
                      ),
                      children: [
                        _SectionHeader(texts.languageSection),
                        _LanguageRow(rowKey: _itemKeys[SettingsItem.language]!),

                        _SectionHeader(texts.soundSection),
                        _SoundEnabledRow(
                          rowKey: _itemKeys[SettingsItem.soundEnabled]!,
                        ),
                        _VolumeRow(rowKey: _itemKeys[SettingsItem.volume]!),

                        _SectionHeader(texts.timerSection),
                        _DefaultModeRow(
                          rowKey: _itemKeys[SettingsItem.defaultMode]!,
                        ),
                        _AutoStartRow(rowKey: _itemKeys[SettingsItem.autoStart]!),
                        _ShowMillisecondsRow(
                          rowKey: _itemKeys[SettingsItem.showMilliseconds]!,
                        ),

                        _SectionHeader(texts.customTimesSection),
                        _PrepTimeRow(
                          rowKey: _itemKeys[SettingsItem.customPrepTime]!,
                        ),
                        _MainTimeRow(
                          rowKey: _itemKeys[SettingsItem.customMainTime]!,
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        _ResetRow(
                          rowKey: _itemKeys[SettingsItem.resetToDefaults]!,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const _SettingsHintRail(),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== CHROME =====

class _SettingsHeader extends ConsumerWidget {
  final String title;

  const _SettingsHeader({required this.title});

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
            onTap:
                () => ref.read(appActionsProvider).handleAction(AppAction.back),
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
          Text(title, style: AppType.display.copyWith(fontSize: 56)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

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

class _SettingsHintRail extends ConsumerWidget {
  const _SettingsHintRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final actions = ref.read(appActionsProvider);

    String keyFor(AppAction action) => ref.watch(actionKeyLabelProvider(action));

    return KeyHintRail(
      hints: [
        KeyHint(
          keys: [
            keyFor(AppAction.navigateUp),
            keyFor(AppAction.navigateDown),
          ],
          label: texts.labelSelect,
        ),
        KeyHint(
          keys: [
            keyFor(AppAction.navigateLeft),
            keyFor(AppAction.navigateRight),
          ],
          label: texts.labelChange,
        ),
        KeyHint(
          keys: [keyFor(AppAction.confirm)],
          label: texts.labelConfirm,
          emphasised: true,
          onTap: () => actions.handleAction(AppAction.confirm),
        ),
        KeyHint(
          keys: [keyFor(AppAction.back)],
          label: texts.labelBack,
          onTap: () => actions.handleAction(AppAction.back),
        ),
      ],
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
/// Watches only its own selection flag, so moving the selection rebuilds the
/// two rows involved and nothing else.
class _SettingsRow extends ConsumerWidget {
  final SettingsItem item;
  final GlobalKey rowKey;
  final String title;
  final String? subtitle;
  final Widget control;

  /// Disabled rows stay visible but are dimmed and cannot be selected — the
  /// keyboard skips them (volume while sound is off).
  final bool enabled;

  const _SettingsRow({
    required this.item,
    required this.rowKey,
    required this.title,
    required this.control,
    this.subtitle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected =
        enabled && ref.watch(isSettingsItemSelectedProvider(item));

    return Container(
      key: rowKey,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap:
            enabled
                ? () =>
                    ref.read(settingsNavigationProvider.notifier).select(item)
                : null,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: isSelected ? AppTheme.selectedPanel() : AppTheme.panel(),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: Row(
              children: [
                _SelectionMarker(isSelected: isSelected),
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
class _SelectionMarker extends StatelessWidget {
  final bool isSelected;

  const _SelectionMarker({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      width: 8,
      height: isSelected ? 56 : 32,
      decoration: BoxDecoration(
        color: isSelected ? AppPalette.accent : AppPalette.outline,
        borderRadius: AppRadius.pill,
      ),
    );
  }
}

// ===== CONTROLS =====

/// Steps through a value with ‹ / › — the same thing the left/right arrow keys
/// do on the selected row. Replaces the dropdown: an overlay route would be
/// invisible to the app-wide keyboard scope.
class _ValueStepper extends ConsumerWidget {
  final SettingsItem item;
  final String value;

  const _ValueStepper({required this.item, required this.value});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(isSettingsItemSelectedProvider(item));
    final navigation = ref.read(settingsNavigationProvider.notifier);

    void step(void Function() adjust) {
      navigation.select(item);
      adjust();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepArrow(
          icon: Icons.chevron_left_rounded,
          highlighted: isSelected,
          onTap: () => step(navigation.adjustLeft),
        ),
        SizedBox(
          width: 260,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppType.body.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? AppPalette.accent : AppPalette.textPrimary,
              ),
            ),
          ),
        ),
        _StepArrow(
          icon: Icons.chevron_right_rounded,
          highlighted: isSelected,
          onTap: () => step(navigation.adjustRight),
        ),
      ],
    );
  }
}

class _StepArrow extends StatelessWidget {
  final IconData icon;
  final bool highlighted;
  final VoidCallback onTap;

  const _StepArrow({
    required this.icon,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              highlighted
                  ? AppPalette.accent.withValues(alpha: 0.16)
                  : AppPalette.surfaceRaised,
          borderRadius: AppRadius.sm,
          border: Border.all(
            color: highlighted ? AppPalette.accent : AppPalette.outline,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 34,
          color: highlighted ? AppPalette.accent : AppPalette.textMuted,
        ),
      ),
    );
  }
}

/// Boolean control. Large enough to read the knob position from a distance,
/// and labelled in words as well — the position alone is a fifty-fifty guess
/// across a tunnel.
class _TogglePill extends ConsumerWidget {
  final SettingsItem item;
  final bool value;

  const _TogglePill({required this.item, required this.value});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final navigation = ref.read(settingsNavigationProvider.notifier);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        navigation.select(item);
        navigation.activate();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              texts.onOff(value),
              textAlign: TextAlign.right,
              style: AppType.body.copyWith(
                fontWeight: FontWeight.w700,
                color:
                    value ? AppPalette.accent : AppPalette.textMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            width: 104,
            height: 56,
            decoration: BoxDecoration(
              color:
                  value
                      ? AppPalette.accent.withValues(alpha: 0.22)
                      : AppPalette.surfaceRaised,
              borderRadius: AppRadius.pill,
              border: Border.all(
                color: value ? AppPalette.accent : AppPalette.outlineStrong,
                width: 2,
              ),
            ),
            child: AnimatedAlign(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(6),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: value ? AppPalette.accent : AppPalette.outlineStrong,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Volume as ten blocks instead of a slider: a slider thumb on a 2px track is
/// invisible from a distance, ten blocks are countable at a glance. Each block
/// is also a tap target, which keeps the mouse path.
class _VolumeMeter extends ConsumerWidget {
  static const int steps = 10;

  final double volume;
  final bool enabled;

  const _VolumeMeter({required this.volume, required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final filled = (volume * steps).round();
    final navigation = ref.read(settingsNavigationProvider.notifier);
    final settings = ref.read(settingsProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 420,
          child: Row(
            children: [
              for (var index = 1; index <= steps; index++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap:
                        enabled
                            ? () {
                              navigation.select(SettingsItem.volume);
                              settings.setVolume(index / steps);
                            }
                            : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: AppMotion.fast,
                        height: index <= filled ? 44 : 30,
                        decoration: BoxDecoration(
                          color:
                              index <= filled
                                  ? AppPalette.accent
                                  : AppPalette.surfaceRaised,
                          borderRadius: AppRadius.sm,
                          border: Border.all(
                            color:
                                index <= filled
                                    ? AppPalette.accent
                                    : AppPalette.outline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 100,
          child: Text(
            texts.formatPercentage(volume),
            textAlign: TextAlign.right,
            style: AppType.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ===== ROWS =====

class _LanguageRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _LanguageRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final language = ref.watch(languageProvider);

    return _SettingsRow(
      item: SettingsItem.language,
      rowKey: rowKey,
      title: texts.language,
      control: _ValueStepper(
        item: SettingsItem.language,
        value: texts.getLanguageName(language),
      ),
    );
  }
}

class _SoundEnabledRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _SoundEnabledRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);

    return _SettingsRow(
      item: SettingsItem.soundEnabled,
      rowKey: rowKey,
      title: texts.soundEnabled,
      control: _TogglePill(
        item: SettingsItem.soundEnabled,
        value: soundEnabled,
      ),
    );
  }
}

class _VolumeRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _VolumeRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final volume = ref.watch(volumeProvider);
    final enabled = ref.watch(soundEnabledProvider);

    return _SettingsRow(
      item: SettingsItem.volume,
      rowKey: rowKey,
      title: texts.volume,
      subtitle: enabled ? null : texts.soundOffNote,
      enabled: enabled,
      control: _VolumeMeter(volume: volume, enabled: enabled),
    );
  }
}

class _DefaultModeRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _DefaultModeRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final mode = ref.watch(defaultTimerModeProvider);

    return _SettingsRow(
      item: SettingsItem.defaultMode,
      rowKey: rowKey,
      title: texts.defaultMode,
      control: _ValueStepper(
        item: SettingsItem.defaultMode,
        value: texts.getModeName(mode),
      ),
    );
  }
}

class _AutoStartRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _AutoStartRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final autoStart = ref.watch(autoStartProvider);

    return _SettingsRow(
      item: SettingsItem.autoStart,
      rowKey: rowKey,
      title: texts.autoStart,
      subtitle: texts.autoStartSubtitle,
      control: _TogglePill(item: SettingsItem.autoStart, value: autoStart),
    );
  }
}

class _ShowMillisecondsRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _ShowMillisecondsRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final showMilliseconds = ref.watch(showMillisecondsProvider);

    return _SettingsRow(
      item: SettingsItem.showMilliseconds,
      rowKey: rowKey,
      title: texts.showMilliseconds,
      control: _TogglePill(
        item: SettingsItem.showMilliseconds,
        value: showMilliseconds,
      ),
    );
  }
}

/// Duration rows are stepped with the arrow keys (holding a key repeats), so
/// there is no text field to focus — which a keyboard-only kiosk could not
/// leave again anyway.
class _PrepTimeRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _PrepTimeRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final duration = ref.watch(customPrepTimeProvider);

    return _SettingsRow(
      item: SettingsItem.customPrepTime,
      rowKey: rowKey,
      title: texts.preparationTime,
      control: _ValueStepper(
        item: SettingsItem.customPrepTime,
        value: texts.formatDurationDisplay(duration),
      ),
    );
  }
}

class _MainTimeRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _MainTimeRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final duration = ref.watch(customMainTimeProvider);

    return _SettingsRow(
      item: SettingsItem.customMainTime,
      rowKey: rowKey,
      title: texts.mainTime,
      control: _ValueStepper(
        item: SettingsItem.customMainTime,
        value: texts.formatDurationDisplay(duration),
      ),
    );
  }
}

/// Reset needs a confirmation, but a modal dialog would be a separate route the
/// app-wide keyboard scope cannot reach. Instead the row arms itself on the
/// first confirm and performs the reset on the second — same flow for keyboard
/// and mouse, and cancellable with Esc or by moving the selection away.
class _ResetRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _ResetRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final armed = ref.watch(isResetArmedProvider);
    final isSelected = ref.watch(
      isSettingsItemSelectedProvider(SettingsItem.resetToDefaults),
    );
    final navigation = ref.read(settingsNavigationProvider.notifier);

    void activate() {
      navigation.select(SettingsItem.resetToDefaults);
      navigation.activate();
    }

    return Container(
      key: rowKey,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: armed ? null : activate,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration:
              armed
                  ? AppTheme.selectedPanel(color: AppPalette.caution)
                  : isSelected
                  ? AppTheme.selectedPanel()
                  : AppTheme.panel(),
          child:
              armed
                  ? _ResetConfirmation(
                    texts: texts,
                    onCancel: navigation.disarmReset,
                    onConfirm: activate,
                  )
                  : Row(
                    children: [
                      _SelectionMarker(isSelected: isSelected),
                      const SizedBox(width: AppSpacing.md),
                      const Icon(
                        Icons.restore_rounded,
                        size: 34,
                        color: AppPalette.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          texts.resetToDefaultsButton,
                          style: AppType.body,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _ResetConfirmation extends StatelessWidget {
  final SettingsTexts texts;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ResetConfirmation({
    required this.texts,
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
                texts.resetDialogTitle,
                style: AppType.title.copyWith(color: AppPalette.caution),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(texts.resetDialogContent, style: AppType.bodySecondary),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: onCancel, child: Text(texts.cancelButton)),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.restore_rounded),
              label: Text(texts.resetButton),
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
