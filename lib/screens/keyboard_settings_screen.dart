import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/keyboard_texts.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_typography.dart';
import '../models/keyboard_config.dart';
import '../providers/app_actions_provider.dart';
import '../providers/keyboard_navigation_provider.dart';
import '../providers/ui_providers.dart';
import '../widgets/key_hint_rail.dart';
import '../widgets/settings_row.dart';

/// Die Abschnitte des Screens, entlang der Gruppen im [AppAction]-Enum.
///
/// Zusammen müssen sie genau [keyboardRows] ohne die Reset-Zeile ergeben —
/// in derselben Reihenfolge, sonst liefe die Auswahl beim Durchsteppen
/// sprunghaft über den Schirm. `test/keyboard_bindings_test.dart` prüft das.
List<(String, List<AppAction>)> keyboardSections(KeyboardTexts texts) => [
  (
    texts.clockSection,
    const [
      AppAction.toggleTimer,
      AppAction.resetTimer,
      AppAction.skipTimer,
      AppAction.next,
      AppAction.previous,
      AppAction.forward,
      AppAction.toggleClock,
      AppAction.toggleCountdown,
    ],
  ),
  (texts.modeSection, const [AppAction.nextMode, AppAction.previousMode]),
  (
    texts.screenSection,
    const [
      AppAction.toggleSettings,
      AppAction.back,
      AppAction.confirm,
      AppAction.toggleFullscreen,
    ],
  ),
  (
    texts.navigationSection,
    const [
      AppAction.navigateUp,
      AppAction.navigateDown,
      AppAction.navigateLeft,
      AppAction.navigateRight,
    ],
  ),
];

/// Die Tastenbelegung: pro Aktion die festen Standardtasten und die
/// Zusatztasten, die man dazu aufnehmen kann.
///
/// Wie der Einstellungs-Screen nur Anzeige: Auswahl und Aufnahme leben in
/// [keyboardNavigationProvider], die Tasten kommen über
/// `KeyboardSettingsScreenActions`. Eine aufzunehmende Taste geht dort durch
/// `textInput`, an der Belegung vorbei — sonst ließe sich nichts aufnehmen,
/// was schon eine Aktion hat.
class KeyboardSettingsScreen extends ConsumerStatefulWidget {
  const KeyboardSettingsScreen({super.key});

  @override
  ConsumerState<KeyboardSettingsScreen> createState() =>
      _KeyboardSettingsScreenState();
}

class _KeyboardSettingsScreenState
    extends ConsumerState<KeyboardSettingsScreen> {
  late final Map<AppAction?, GlobalKey> _rowKeys = {
    for (final row in keyboardRows) row: GlobalKey(),
  };

  /// Wie in `SettingsScreen._ensureVisible`: nur scrollen, wenn die Zeile
  /// nicht ohnehin zu sehen ist — hier passt die Liste fast nie ganz auf den
  /// Schirm, aber ein gehaltener Pfeil soll trotzdem nicht hinterherkriechen.
  void _ensureVisible(AppAction? row) {
    final rowContext = _rowKeys[row]?.currentContext;
    if (rowContext == null || _isFullyVisible(rowContext)) return;

    Scrollable.ensureVisible(
      rowContext,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      alignment: 0.5,
    );
  }

  bool _isFullyVisible(BuildContext rowContext) {
    final scrollable = Scrollable.maybeOf(rowContext);
    if (scrollable == null) return false;

    final box = rowContext.findRenderObject();
    final scrollableBox = scrollable.context.findRenderObject();
    if (box is! RenderBox || scrollableBox is! RenderBox) return false;
    if (!box.hasSize || !scrollableBox.hasSize) return false;

    final top = box.localToGlobal(Offset.zero, ancestor: scrollableBox).dy;
    final bottom = top + box.size.height;

    const margin = AppSpacing.lg;
    return top >= margin && bottom <= scrollableBox.size.height - margin;
  }

  @override
  Widget build(BuildContext context) {
    final texts = ref.watch(keyboardTextsProvider);

    ref.listen(selectedKeyboardRowProvider, (_, next) {
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
              SettingsHeader(title: texts.title),

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
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.xxs,
                            bottom: AppSpacing.xs,
                          ),
                          child: Text(
                            texts.intro,
                            style: AppType.bodySecondary,
                          ),
                        ),
                        for (final (title, actions) in keyboardSections(
                          texts,
                        )) ...[
                          SettingsSectionHeader(title),
                          for (final action in actions)
                            _BindingRow(
                              action: action,
                              rowKey: _rowKeys[action]!,
                            ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        _ClearRow(rowKey: _rowKeys[null]!),
                      ],
                    ),
                  ),
                ),
              ),

              const _KeyboardHintRail(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eine Aktion mit ihren Tasten: Standardtasten gedämpft, Zusatztasten in der
/// Akzentfarbe, dahinter die Kappe zum Hinzufügen — oder, während auf die
/// neue Taste gewartet wird, die Aufforderung dazu.
class _BindingRow extends ConsumerWidget {
  final AppAction action;
  final GlobalKey rowKey;

  const _BindingRow({required this.action, required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(keyboardTextsProvider);
    final bindings = ref.watch(actionBindingsProvider(action));
    final capturing = ref.watch(isKeyboardRowCapturingProvider(action));
    final notice = ref.watch(keyboardRowNoticeProvider(action));
    final navigation = ref.read(keyboardNavigationProvider.notifier);

    return SettingsRowShell(
      rowKey: rowKey,
      isSelected: ref.watch(isKeyboardRowSelectedProvider(action)),
      title: texts.actionName(action),
      subtitle: notice == null ? null : texts.notice(notice),
      onTap: () => navigation.select(action),
      // Flexible, damit eine Zeile mit vielen Zusatztasten umbricht statt
      // über den Rand zu laufen.
      control: Flexible(
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          alignment: WrapAlignment.end,
          children: [
            for (final key in bindings.defaults)
              KeyCap(label: texts.keyName(key)),
            for (final key in bindings.extras)
              KeyCap(label: texts.keyName(key), color: AppPalette.accent),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                navigation.select(action);
                if (!capturing) navigation.activate();
              },
              child: capturing
                  ? KeyCap(label: texts.pressKey, color: AppPalette.caution)
                  : const KeyCap(label: '+'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearRow extends ConsumerWidget {
  final GlobalKey rowKey;

  const _ClearRow({required this.rowKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(keyboardTextsProvider);
    final navigation = ref.read(keyboardNavigationProvider.notifier);

    return SettingsResetRowShell(
      rowKey: rowKey,
      isSelected: ref.watch(isKeyboardRowSelectedProvider(null)),
      armed: ref.watch(isKeyboardResetArmedProvider),
      label: texts.reset,
      confirmTitle: texts.resetTitle,
      confirmContent: texts.resetContent,
      cancelLabel: texts.resetCancel,
      confirmLabel: texts.resetConfirm,
      onActivate: () {
        navigation.select(null);
        navigation.activate();
      },
      onCancel: navigation.disarmReset,
    );
  }
}

class _KeyboardHintRail extends ConsumerWidget {
  const _KeyboardHintRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(keyboardTextsProvider);
    final actions = ref.read(appActionsProvider);

    String keyFor(AppAction action) =>
        ref.watch(actionKeyLabelProvider(action));

    // Während der Aufnahme tut keine Taste, was die Belegung sagt — nur Esc
    // bricht ab, und das fest, deshalb die Kappe ohne Nachschlagen.
    if (ref.watch(isKeyboardCapturingProvider)) {
      return KeyHintRail(
        hints: [
          KeyHint(
            keys: const ['…'],
            label: texts.hintCapture,
            emphasised: true,
          ),
          KeyHint(
            keys: const ['Esc'],
            label: texts.hintCancel,
            onTap: ref.read(keyboardNavigationProvider.notifier).cancelCapture,
          ),
        ],
      );
    }

    return KeyHintRail(
      hints: [
        KeyHint(
          keys: [keyFor(AppAction.navigateUp), keyFor(AppAction.navigateDown)],
          label: texts.hintSelect,
        ),
        KeyHint(
          keys: [keyFor(AppAction.confirm)],
          label: texts.hintAdd,
          emphasised: true,
          onTap: () => actions.handleAction(AppAction.confirm),
        ),
        KeyHint(
          keys: [keyFor(AppAction.forward)],
          label: texts.hintRemove,
          onTap: () => actions.handleAction(AppAction.forward),
        ),
        KeyHint(
          keys: [keyFor(AppAction.back)],
          label: texts.hintBack,
          onTap: () => actions.handleAction(AppAction.back),
        ),
      ],
    );
  }
}
