import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/settings_texts.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../models/keyboard_config.dart';
import '../models/settings_section.dart';
import '../providers/app_actions_provider.dart';
import '../providers/settings_navigation_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ui_providers.dart';
import '../widgets/key_hint_rail.dart';

/// Settings screen for one [SettingsSection].
///
/// Es gibt drei davon — Allgemein, Ampel, Wettkampf — und alle drei sind dieser
/// Screen mit einem anderen [section]. Die Zeilen selbst wissen nichts von der
/// Aufteilung: welcher Bereich welche Zeilen hat, steht einmal in
/// [SettingsItem.section], und [_rowsFor] baut daraus die Liste.
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
  final SettingsSection section;

  const SettingsScreen({super.key, required this.section});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// One key per row of this section so the selected row can be scrolled into
  /// view.
  late final Map<SettingsItem, GlobalKey> _itemKeys = {
    for (final item in SettingsItem.of(widget.section)) item: GlobalKey(),
  };

  // Kein Zurücksetzen der Auswahl von hier aus: welcher Bereich offen ist,
  // leitet SettingsNavigationNotifier selbst aus dem Screen ab
  // (openSettingsSectionProvider) und fängt dabei oben an. Von hier aus wäre es
  // ohnehin zu spät — dieser Screen baut sich gerade auf, und ein
  // Zustandswechsel mittendrin ist ein Fehler.

  /// Scrolls the selected row into view — but only when it is not already
  /// there.
  ///
  /// Scrolling unconditionally used to start a fresh centring animation on
  /// every step. Held down, a new one began every ~33ms and was abandoned after
  /// a fraction of its way, so the list crawled behind the selection and kept
  /// easing after the key was released. On the usual monitors every row is
  /// visible anyway, so this now does nothing at all most of the time.
  void _ensureVisible(SettingsItem item) {
    final itemContext = _itemKeys[item]?.currentContext;
    if (itemContext == null) return;

    if (_isFullyVisible(itemContext)) return;

    Scrollable.ensureVisible(
      itemContext,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      alignment: 0.5,
    );
  }

  /// Whether the row sits inside the viewport with a little room to spare, so
  /// a row that is only just clipped still counts as needing a scroll.
  bool _isFullyVisible(BuildContext itemContext) {
    final scrollable = Scrollable.maybeOf(itemContext);
    if (scrollable == null) return false;

    final box = itemContext.findRenderObject();
    final scrollableBox = scrollable.context.findRenderObject();
    if (box is! RenderBox || scrollableBox is! RenderBox) return false;
    if (!box.hasSize || !scrollableBox.hasSize) return false;

    final top = box.localToGlobal(Offset.zero, ancestor: scrollableBox).dy;
    final bottom = top + box.size.height;

    const margin = AppSpacing.lg;
    return top >= margin && bottom <= scrollableBox.size.height - margin;
  }

  /// Die Zeilen des offenen Bereichs, mit ihren Zwischenüberschriften.
  ///
  /// Die Reset-Zeile steht in jedem Bereich am Ende und fasst nur diesen
  /// Bereich an — siehe [SettingsNotifier.resetSection].
  List<Widget> _rowsFor(SettingsTexts texts) {
    switch (widget.section) {
      case SettingsSection.general:
        return [
          _SectionHeader(texts.languageSection),
          _LanguageRow(rowKey: _itemKeys[SettingsItem.language]!),

          _SectionHeader(texts.displaySection),
          _FullscreenRow(rowKey: _itemKeys[SettingsItem.fullscreen]!),

          _SectionHeader(texts.soundSection),
          _SoundEnabledRow(rowKey: _itemKeys[SettingsItem.soundEnabled]!),
          _SignalToneRow(rowKey: _itemKeys[SettingsItem.signalTone]!),
          _VolumeRow(rowKey: _itemKeys[SettingsItem.volume]!),

          const SizedBox(height: AppSpacing.lg),
          _ResetRow(
            item: SettingsItem.resetGeneral,
            rowKey: _itemKeys[SettingsItem.resetGeneral]!,
          ),
        ];

      case SettingsSection.timer:
        return [
          _SectionHeader(texts.timerSection),
          _DefaultModeRow(rowKey: _itemKeys[SettingsItem.defaultMode]!),
          _ShowMillisecondsRow(
            rowKey: _itemKeys[SettingsItem.showMilliseconds]!,
          ),
          _TimeFormatRow(
            item: SettingsItem.timeFormat,
            rowKey: _itemKeys[SettingsItem.timeFormat]!,
          ),
          _TimerScaleRow(rowKey: _itemKeys[SettingsItem.timerScale]!),
          _AlternatingArrowsRow(
            rowKey: _itemKeys[SettingsItem.alternatingArrows]!,
          ),

          _SectionHeader(texts.customTimesSection),
          _PrepTimeRow(rowKey: _itemKeys[SettingsItem.customPrepTime]!),
          _MainTimeRow(rowKey: _itemKeys[SettingsItem.customMainTime]!),

          const SizedBox(height: AppSpacing.lg),
          _ResetRow(
            item: SettingsItem.resetTimer,
            rowKey: _itemKeys[SettingsItem.resetTimer]!,
          ),
        ];

      case SettingsSection.competition:
        return [
          _SectionHeader(texts.roundSection),
          _DisciplineRow(
            rowKey: _itemKeys[SettingsItem.competitionDiscipline]!,
          ),
          _EndsRow(rowKey: _itemKeys[SettingsItem.competitionEnds]!),
          _PracticeEndsRow(
            rowKey: _itemKeys[SettingsItem.competitionPracticeEnds]!,
          ),

          _SectionHeader(texts.targetSection),
          _LineupRow(rowKey: _itemKeys[SettingsItem.competitionLineup]!),

          _SectionHeader(texts.countdownSection),
          _CountdownTimeRow(
            rowKey: _itemKeys[SettingsItem.competitionCountdownTime]!,
          ),
          _CountdownAutoStartRow(
            rowKey: _itemKeys[SettingsItem.competitionCountdownAutoStart]!,
          ),

          _SectionHeader(texts.displaySection),
          _DisplayRow(rowKey: _itemKeys[SettingsItem.competitionDisplay]!),
          const _LedKeysNote(),
          _TimeFormatRow(
            item: SettingsItem.competitionTimeFormat,
            rowKey: _itemKeys[SettingsItem.competitionTimeFormat]!,
          ),

          const SizedBox(height: AppSpacing.lg),
          _ResetRow(
            item: SettingsItem.resetCompetition,
            rowKey: _itemKeys[SettingsItem.resetCompetition]!,
          ),
        ];
    }
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
              _SettingsHeader(title: texts.sectionTitle(widget.section)),

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
                      children: _rowsFor(texts),
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

    String keyFor(AppAction action) =>
        ref.watch(actionKeyLabelProvider(action));

    return KeyHintRail(
      hints: [
        KeyHint(
          keys: [keyFor(AppAction.navigateUp), keyFor(AppAction.navigateDown)],
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
        onTap: enabled
            ? () => ref.read(settingsNavigationProvider.notifier).select(item)
            : null,
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
///
/// Fixed size on purpose: animating the height would relayout the row (and the
/// list) in every frame of the highlight, for the same reason the border width
/// is constant — see [AppTheme.selectablePanel]. Only the colour moves.
class _SelectionMarker extends StatelessWidget {
  final bool isSelected;

  const _SelectionMarker({required this.isSelected});

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
          color: highlighted
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
                color: value ? AppPalette.accent : AppPalette.textMuted,
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
              color: value
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
                    onTap: enabled
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
                          color: index <= filled
                              ? AppPalette.accent
                              : AppPalette.surfaceRaised,
                          borderRadius: AppRadius.sm,
                          border: Border.all(
                            color: index <= filled
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

class _FullscreenRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _FullscreenRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final fullscreen = ref.watch(fullscreenProvider);

    return _SettingsRow(
      item: SettingsItem.fullscreen,
      rowKey: rowKey,
      title: texts.fullscreen,
      subtitle: texts.fullscreenNote,
      control: _TogglePill(item: SettingsItem.fullscreen, value: fullscreen),
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

class _SignalToneRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _SignalToneRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final signalTone = ref.watch(signalToneProvider);
    final enabled = ref.watch(soundEnabledProvider);

    return _SettingsRow(
      item: SettingsItem.signalTone,
      rowKey: rowKey,
      title: texts.signalTone,
      subtitle: enabled ? texts.signalToneSubtitle : texts.soundOffNote,
      enabled: enabled,
      control: _ValueStepper(
        item: SettingsItem.signalTone,
        value: texts.getSignalToneName(signalTone),
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

/// Ob die Uhr „4:00" oder „240" zeigt.
///
/// Steht in beiden Uhr-Bereichen, weil die Einstellung für beide gilt und man
/// sie dort erwartet, wo man gerade ist. [item] sagt nur, welche der beiden
/// Zeilen gerade gebaut wird — der Wert kommt in beiden Fällen aus demselben
/// Provider, ein Wechsel hier steht also sofort auch drüben.
class _TimeFormatRow extends ConsumerWidget {
  final GlobalKey rowKey;
  final SettingsItem item;

  const _TimeFormatRow({required this.rowKey, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final format = ref.watch(timeFormatProvider);

    return _SettingsRow(
      item: item,
      rowKey: rowKey,
      title: texts.timeFormat,
      control: _ValueStepper(
        item: item,
        value: texts.getTimeFormatName(format),
      ),
    );
  }
}

/// Anzeigegröße der Ampel.
///
/// Beurteilen lässt sich der Wert nur auf dem Timer selbst — die Zeile steht
/// deshalb bewusst weit oben im Bereich, damit der Weg Esc → schauen → S kurz
/// bleibt und die Auswahl beim Zurückkommen wieder in Sichtweite liegt.
class _TimerScaleRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _TimerScaleRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final scale = ref.watch(timerScaleProvider);

    return _SettingsRow(
      item: SettingsItem.timerScale,
      rowKey: rowKey,
      title: texts.displayScale,
      subtitle: texts.displayScaleSubtitle,
      control: _ValueStepper(
        item: SettingsItem.timerScale,
        value: texts.formatPercentage(scale),
      ),
    );
  }
}

/// Pfeile pro Schütze im Wechselmodus — steht bei den Timer-Einstellungen und
/// nicht bei den Zeiten, weil es keine Zeit ist.
class _AlternatingArrowsRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _AlternatingArrowsRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final arrows = ref.watch(alternatingArrowsProvider);

    return _SettingsRow(
      item: SettingsItem.alternatingArrows,
      rowKey: rowKey,
      title: texts.arrowsPerArcher,
      subtitle: texts.arrowsPerArcherSubtitle,
      control: _ValueStepper(
        item: SettingsItem.alternatingArrows,
        value: '$arrows',
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
      subtitle: texts.preparationTimeSubtitle,
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

/// Disziplin — Halle oder Freiluft. Die Unterzeile zeigt, was das konkret
/// heißt, statt einer festen Erklärung.
class _DisciplineRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _DisciplineRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final discipline = ref.watch(competitionDisciplineProvider);

    return _SettingsRow(
      item: SettingsItem.competitionDiscipline,
      rowKey: rowKey,
      title: texts.discipline,
      subtitle: texts.getDisciplineDetail(discipline),
      control: _ValueStepper(
        item: SettingsItem.competitionDiscipline,
        value: texts.getDisciplineName(discipline),
      ),
    );
  }
}

class _EndsRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _EndsRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final ends = ref.watch(competitionEndsProvider);

    return _SettingsRow(
      item: SettingsItem.competitionEnds,
      rowKey: rowKey,
      title: texts.ends,
      subtitle: texts.endsSubtitle,
      control: _ValueStepper(
        item: SettingsItem.competitionEnds,
        value: '$ends',
      ),
    );
  }
}

class _PracticeEndsRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _PracticeEndsRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final ends = ref.watch(competitionPracticeEndsProvider);

    return _SettingsRow(
      item: SettingsItem.competitionPracticeEnds,
      rowKey: rowKey,
      title: texts.practiceEnds,
      subtitle: texts.practiceEndsSubtitle,
      control: _ValueStepper(
        item: SettingsItem.competitionPracticeEnds,
        value: '$ends',
      ),
    );
  }
}

class _LineupRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _LineupRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final lineup = ref.watch(competitionLineupProvider);

    return _SettingsRow(
      item: SettingsItem.competitionLineup,
      rowKey: rowKey,
      title: texts.lineup,
      subtitle: texts.lineupSubtitle,
      control: _ValueStepper(
        item: SettingsItem.competitionLineup,
        value: texts.getLineupName(lineup),
      ),
    );
  }
}

/// Wie lange der Countdown vor dem Turnierstart läuft — die Zeit der Ansage,
/// nicht die einer Phase der Runde.
class _CountdownTimeRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _CountdownTimeRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final duration = ref.watch(competitionCountdownTimeProvider);

    return _SettingsRow(
      item: SettingsItem.competitionCountdownTime,
      rowKey: rowKey,
      title: texts.countdownTime,
      subtitle: texts.countdownTimeSubtitle,
      control: _ValueStepper(
        item: SettingsItem.competitionCountdownTime,
        value: texts.formatDurationDisplay(duration),
      ),
    );
  }
}

class _CountdownAutoStartRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _CountdownAutoStartRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final autoStart = ref.watch(competitionCountdownAutoStartProvider);

    return _SettingsRow(
      item: SettingsItem.competitionCountdownAutoStart,
      rowKey: rowKey,
      title: texts.countdownAutoStart,
      subtitle: texts.countdownAutoStartSubtitle,
      control: _TogglePill(
        item: SettingsItem.competitionCountdownAutoStart,
        value: autoStart,
      ),
    );
  }
}

/// Auf welchem Schirm der Wettkampf läuft — Monitor oder die LED-Wand am
/// Außenstand. Eine Eigenschaft des Aufstellungsorts, deshalb persistiert und
/// nicht auf einer Taste.
class _DisplayRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _DisplayRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final display = ref.watch(competitionDisplayProvider);

    return _SettingsRow(
      item: SettingsItem.competitionDisplay,
      rowKey: rowKey,
      title: texts.display,
      subtitle: texts.displaySubtitle,
      control: _ValueStepper(
        item: SettingsItem.competitionDisplay,
        value: texts.getDisplayName(display),
      ),
    );
  }
}

/// Der Hinweis, dass die Pfeiltasten auf der LED-Wand etwas anderes tun.
///
/// Steht unter der Ausgabe-Zeile und nur, solange eine LED-Variante gewählt
/// ist: dort fehlt die Tastenleiste, die es sonst selbst zeigen würde, also
/// muss die Einstellung es sagen, die den Schirm umschaltet. Keine eigene
/// [SettingsItem] — es ist nichts zum Auswählen, nur ein Satz.
class _LedKeysNote extends ConsumerWidget {
  const _LedKeysNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(competitionDisplayProvider).ledFit == null) {
      return const SizedBox.shrink();
    }

    final texts = ref.watch(settingsTextsProvider);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xs,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
      ),
      child: Text(
        texts.ledKeysNote,
        style: AppType.bodySecondary.copyWith(color: AppPalette.accentSoft),
      ),
    );
  }
}

/// Reset needs a confirmation, but a modal dialog would be a separate route the
/// app-wide keyboard scope cannot reach. Instead the row arms itself on the
/// first confirm and performs the reset on the second — same flow for keyboard
/// and mouse, and cancellable with Esc or by moving the selection away.
class _ResetRow extends ConsumerWidget {
  /// Welche der drei Reset-Zeilen das ist — sie unterscheiden sich nur darin,
  /// welchen Bereich sie zurücksetzen.
  final SettingsItem item;
  final GlobalKey rowKey;

  const _ResetRow({required this.item, required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);
    final armed = ref.watch(isResetArmedProvider);
    final isSelected = ref.watch(isSettingsItemSelectedProvider(item));
    final navigation = ref.read(settingsNavigationProvider.notifier);

    void activate() {
      navigation.select(item);
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
          // Armed reads as selected in the warning colour, so the row cannot
          // change size between its three states either.
          decoration: AppTheme.selectablePanel(
            isSelected: armed || isSelected,
            color: armed ? AppPalette.caution : AppPalette.accent,
          ),
          child: armed
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
