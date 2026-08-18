import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/menu_texts.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../models/keyboard_config.dart';
import '../providers/app_actions_provider.dart';
import '../providers/menu_navigation_provider.dart';
import '../providers/ui_providers.dart';
import '../widgets/key_hint_rail.dart';

/// Home screen of the app: pick a tool.
///
/// The screen is a visual shell around [menuNavigationProvider] — it renders
/// the selection and nothing else, exactly like the settings screen. Opening
/// an entry always goes through MenuScreenActions, so keyboard, mouse and
/// touch take the same path.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(menuTextsProvider);

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
              Expanded(
                // Header and tiles share one centred column, so the title
                // sits above the grid instead of drifting to the far edge of
                // a 2560px monitor.
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.lg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MenuHeader(
                            title: texts.title,
                            subtitle: texts.subtitle,
                          ),
                          const _MenuGrid(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const _MenuHintRail(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MenuHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxs,
        bottom: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.display),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: AppType.bodySecondary),
        ],
      ),
    );
  }
}

/// The tile grid, laid out as explicit rows rather than a [GridView].
///
/// A scrollable grid inside a [SingleChildScrollView] would need a fixed
/// extent; with a handful of tiles, chunking the items into rows of
/// [_columnsFor] and letting an [IntrinsicHeight] match the tiles of one row
/// is both simpler and free of a second scroll axis.
class _MenuGrid extends ConsumerStatefulWidget {
  const _MenuGrid();

  @override
  ConsumerState<_MenuGrid> createState() => _MenuGridState();
}

class _MenuGridState extends ConsumerState<_MenuGrid> {
  /// Wide monitors get three tiles side by side; a 1280px display and anything
  /// narrower fall back to two and one, so a tile never gets so narrow that its
  /// 26sp description wraps into a column of single words.
  ///
  /// The upper threshold has to stay below the 1440px content cap minus its
  /// padding, or three columns would never be reached.
  static int _columnsFor(double width) {
    if (width >= 1300) return 3;
    if (width >= 760) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);

        // Arrow keys need the column count, but a provider must not be written
        // to during a build — hence the post-frame hand-off.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(menuColumnsProvider.notifier).setColumns(columns);
        });

        const items = MenuItem.values;
        final rows = <Widget>[];

        for (var start = 0; start < items.length; start += columns) {
          final rowItems = items.skip(start).take(columns).toList();
          final children = <Widget>[];

          for (var column = 0; column < columns; column++) {
            if (column > 0) {
              children.add(const SizedBox(width: AppSpacing.md));
            }
            children.add(
              Expanded(
                child:
                    column < rowItems.length
                        // An incomplete last row keeps its empty slots, so the
                        // tiles above and below stay the same width.
                        ? _MenuTile(item: rowItems[column])
                        : const SizedBox.shrink(),
              ),
            );
          }

          if (rows.isNotEmpty) {
            rows.add(const SizedBox(height: AppSpacing.md));
          }
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          );
        }

        return Column(mainAxisSize: MainAxisSize.min, children: rows);
      },
    );
  }
}

class _MenuTile extends ConsumerWidget {
  final MenuItem item;

  const _MenuTile({required this.item});

  IconData get _icon {
    switch (item) {
      case MenuItem.timer:
        return Icons.traffic_rounded;
      case MenuItem.competition:
        return Icons.emoji_events_rounded;
      case MenuItem.idle:
        return Icons.schedule_rounded;
      case MenuItem.timerSettings:
        return Icons.tune_rounded;
      case MenuItem.competitionSettings:
        return Icons.rule_rounded;
      case MenuItem.generalSettings:
        return Icons.settings_rounded;
    }
  }

  String _title(MenuTexts texts) {
    switch (item) {
      case MenuItem.timer:
        return texts.timer;
      case MenuItem.competition:
        return texts.competition;
      case MenuItem.idle:
        return texts.idle;
      case MenuItem.timerSettings:
        return texts.timerSettings;
      case MenuItem.competitionSettings:
        return texts.competitionSettings;
      case MenuItem.generalSettings:
        return texts.generalSettings;
    }
  }

  String _description(MenuTexts texts) {
    switch (item) {
      case MenuItem.timer:
        return texts.timerDescription;
      case MenuItem.competition:
        return texts.competitionDescription;
      case MenuItem.idle:
        return texts.idleDescription;
      case MenuItem.timerSettings:
        return texts.timerSettingsDescription;
      case MenuItem.competitionSettings:
        return texts.competitionSettingsDescription;
      case MenuItem.generalSettings:
        return texts.generalSettingsDescription;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(isMenuItemSelectedProvider(item));
    final texts = ref.watch(menuTextsProvider);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      // Hovering moves the same selection the arrow keys move: one state, two
      // input paths, and no second highlight treatment to keep in sync.
      onEnter: (_) => ref.read(menuNavigationProvider.notifier).select(item),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(menuNavigationProvider.notifier).select(item);
          ref.read(appActionsProvider).handleAction(AppAction.confirm);
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: AppTheme.selectablePanel(isSelected: isSelected),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _icon,
                size: 64,
                color: isSelected ? AppPalette.accent : AppPalette.textMuted,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(_title(texts), style: AppType.title),
              const SizedBox(height: AppSpacing.xxs),
              Text(_description(texts), style: AppType.bodySecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuHintRail extends ConsumerWidget {
  const _MenuHintRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(menuTextsProvider);
    final actions = ref.read(appActionsProvider);

    // No "back" hint: this is the home screen, there is nothing above it.
    return KeyHintRail(
      hints: [
        KeyHint(
          keys: [
            ref.watch(actionKeyLabelProvider(AppAction.navigateLeft)),
            ref.watch(actionKeyLabelProvider(AppAction.navigateRight)),
            ref.watch(actionKeyLabelProvider(AppAction.navigateUp)),
            ref.watch(actionKeyLabelProvider(AppAction.navigateDown)),
          ],
          label: texts.hintSelect,
        ),
        KeyHint(
          keys: [ref.watch(actionKeyLabelProvider(AppAction.confirm))],
          label: texts.hintOpen,
          emphasised: true,
          onTap: () => actions.handleAction(AppAction.confirm),
        ),
      ],
    );
  }
}
