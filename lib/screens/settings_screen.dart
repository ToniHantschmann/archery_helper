import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timer_state.dart';
import '../models/keyboard_config.dart';
import '../core/l10n/app_language.dart';
import '../providers/settings_provider.dart';
import '../providers/settings_navigation_provider.dart';
import '../providers/app_actions_provider.dart';
import '../core/l10n/settings_texts.dart';

/// Settings screen.
///
/// Fully keyboard operable: the selected row lives in
/// [settingsNavigationProvider] and is driven by the navigate* actions coming
/// from KeyboardScope → AppActionsNotifier → SettingsScreenActions. The widgets
/// below only render that state; they never handle raw key events themselves.
/// Mouse interaction is kept for testing and always selects the row it acts on,
/// so both input paths stay in sync.
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
      appBar: AppBar(
        title: Text(texts.screenTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed:
              () => ref.read(appActionsProvider).handleAction(AppAction.back),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(texts.languageSection),
                _LanguageRow(rowKey: _itemKeys[SettingsItem.language]!),

                const Divider(height: 40),

                _SectionHeader(texts.soundSection),
                _SoundEnabledRow(rowKey: _itemKeys[SettingsItem.soundEnabled]!),
                _VolumeRow(rowKey: _itemKeys[SettingsItem.volume]!),

                const Divider(height: 40),

                _SectionHeader(texts.timerSection),
                _DefaultModeRow(rowKey: _itemKeys[SettingsItem.defaultMode]!),
                _AutoStartRow(rowKey: _itemKeys[SettingsItem.autoStart]!),
                _ShowMillisecondsRow(
                  rowKey: _itemKeys[SettingsItem.showMilliseconds]!,
                ),

                const Divider(height: 40),

                _SectionHeader(texts.customTimesSection),
                _PrepTimeRow(rowKey: _itemKeys[SettingsItem.customPrepTime]!),
                _MainTimeRow(rowKey: _itemKeys[SettingsItem.customMainTime]!),

                const SizedBox(height: 40),

                _ResetRow(rowKey: _itemKeys[SettingsItem.resetToDefaults]!),
              ],
            ),
          ),

          _KeyboardHint(texts.navigationHint),
        ],
      ),
    );
  }
}

// ===== ROW SCAFFOLDING =====

/// Wraps a row so it can be highlighted and scrolled to when selected.
/// A click selects the row as well, keeping mouse and keyboard in sync.
///
/// Watches only its own selection flag, so moving the selection rebuilds the
/// two frames involved — never the [child], which is passed in as an already
/// built widget and therefore reused untouched.
class _SelectionFrame extends ConsumerWidget {
  final SettingsItem item;
  final GlobalKey rowKey;
  final Widget child;

  const _SelectionFrame({
    required this.item,
    required this.rowKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(isSettingsItemSelectedProvider(item));

    return Container(
      key: rowKey,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.green : Colors.transparent,
          width: 2,
        ),
        color: isSelected ? Colors.green.withValues(alpha: 0.08) : null,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => ref.read(settingsNavigationProvider.notifier).select(item),
        child: child,
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
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    );
  }
}

/// Bottom bar reminding which keys do what — the app runs without a mouse.
class _KeyboardHint extends StatelessWidget {
  final String hint;

  const _KeyboardHint(this.hint);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.black.withValues(alpha: 0.3),
      child: Text(
        hint,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }
}

// ===== REUSABLE TILE SHAPES =====

class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.green,
      ),
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<T> items;
  final String Function(T) itemBuilder;
  final ValueChanged<T> onChanged;

  const _DropdownTile({
    required this.title,
    required this.value,
    required this.items,
    required this.itemBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(title),
        trailing: DropdownButton<T>(
          value: value,
          dropdownColor: Colors.grey[850],
          items:
              items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(itemBuilder(item)),
                    ),
                  )
                  .toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ),
    );
  }
}

/// Duration rows are stepped with the arrow keys (holding a key repeats), so
/// there is no text field to focus — which a keyboard-only kiosk could not
/// leave again anyway.
class _DurationTile extends ConsumerWidget {
  final SettingsItem item;
  final String title;
  final Duration duration;
  final String Function(Duration) formatter;
  final String unitShort;

  const _DurationTile({
    required this.item,
    required this.title,
    required this.duration,
    required this.formatter,
    required this.unitShort,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigation = ref.read(settingsNavigationProvider.notifier);

    void step(void Function() adjust) {
      navigation.select(item);
      adjust();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(title),
        subtitle: Text(formatter(duration)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: '-1 $unitShort',
              onPressed: () => step(navigation.adjustLeft),
            ),
            SizedBox(
              width: 64,
              child: Text(
                '${duration.inSeconds} $unitShort',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: '+1 $unitShort',
              onPressed: () => step(navigation.adjustRight),
            ),
          ],
        ),
      ),
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

    return _SelectionFrame(
      item: SettingsItem.language,
      rowKey: rowKey,
      child: _DropdownTile<AppLanguage>(
        title: texts.language,
        value: language,
        items: AppLanguage.values,
        itemBuilder: texts.getLanguageName,
        onChanged: ref.read(settingsProvider.notifier).setLanguage,
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

    return _SelectionFrame(
      item: SettingsItem.soundEnabled,
      rowKey: rowKey,
      child: _SwitchTile(
        title: texts.soundEnabled,
        value: soundEnabled,
        onChanged: (_) => ref.read(settingsProvider.notifier).toggleSound(),
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

    return _SelectionFrame(
      item: SettingsItem.volume,
      rowKey: rowKey,
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          title: Text(texts.volume),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Slider(
                value: volume,
                onChanged:
                    enabled
                        ? ref.read(settingsProvider.notifier).setVolume
                        : null,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: texts.formatPercentage(volume),
                activeColor: Colors.green,
              ),
              Text(
                texts.formatPercentage(volume),
                style: TextStyle(
                  color: enabled ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
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

    return _SelectionFrame(
      item: SettingsItem.defaultMode,
      rowKey: rowKey,
      child: _DropdownTile<TimerMode>(
        title: texts.defaultMode,
        value: mode,
        items: TimerMode.values,
        itemBuilder: texts.getModeName,
        onChanged: ref.read(settingsProvider.notifier).setDefaultMode,
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

    return _SelectionFrame(
      item: SettingsItem.autoStart,
      rowKey: rowKey,
      child: _SwitchTile(
        title: texts.autoStart,
        subtitle: texts.autoStartSubtitle,
        value: autoStart,
        onChanged: (_) => ref.read(settingsProvider.notifier).toggleAutoStart(),
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

    return _SelectionFrame(
      item: SettingsItem.showMilliseconds,
      rowKey: rowKey,
      child: _SwitchTile(
        title: texts.showMilliseconds,
        value: showMilliseconds,
        onChanged:
            (_) => ref.read(settingsProvider.notifier).toggleShowMilliseconds(),
      ),
    );
  }
}

class _PrepTimeRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _PrepTimeRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(settingsTextsProvider);

    return _SelectionFrame(
      item: SettingsItem.customPrepTime,
      rowKey: rowKey,
      child: _DurationTile(
        item: SettingsItem.customPrepTime,
        title: texts.preparationTime,
        duration: ref.watch(customPrepTimeProvider),
        formatter: texts.formatDurationDisplay,
        unitShort: texts.secondsShort,
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

    return _SelectionFrame(
      item: SettingsItem.customMainTime,
      rowKey: rowKey,
      child: _DurationTile(
        item: SettingsItem.customMainTime,
        title: texts.mainTime,
        duration: ref.watch(customMainTimeProvider),
        formatter: texts.formatDurationDisplay,
        unitShort: texts.secondsShort,
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
    final navigation = ref.read(settingsNavigationProvider.notifier);

    return _SelectionFrame(
      item: SettingsItem.resetToDefaults,
      rowKey: rowKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            if (armed) ...[
              Text(
                texts.resetDialogTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                texts.resetDialogContent,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: navigation.disarmReset,
                    child: Text(texts.cancelButton),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      navigation.select(SettingsItem.resetToDefaults);
                      navigation.activate();
                    },
                    icon: const Icon(Icons.restore),
                    label: Text(texts.resetButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ],
              ),
            ] else
              ElevatedButton.icon(
                onPressed: () {
                  navigation.select(SettingsItem.resetToDefaults);
                  navigation.activate();
                },
                icon: const Icon(Icons.restore),
                label: Text(texts.resetToDefaultsButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.withValues(alpha: 0.8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
