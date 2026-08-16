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

/// Entry point of the app: pick a tool.
///
/// The screen is a visual shell around [menuNavigationProvider] — it renders
/// the selection and nothing else, exactly like the settings screen. Opening
/// an entry always goes through MenuScreenActions, so keyboard and mouse take
/// the same path.
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
                // Header and entries share one centred column, so the title
                // sits above the cards instead of drifting to the far edge of
                // a 2560px monitor.
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
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
                          _MenuEntry(
                            item: MenuItem.timer,
                            icon: Icons.traffic_rounded,
                            title: texts.timer,
                            description: texts.timerDescription,
                          ),
                          _MenuEntry(
                            item: MenuItem.settings,
                            icon: Icons.tune_rounded,
                            title: texts.settings,
                            description: texts.settingsDescription,
                          ),
                          _MenuEntry(
                            item: MenuItem.idle,
                            icon: Icons.schedule_rounded,
                            title: texts.idle,
                            description: texts.idleDescription,
                          ),
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

class _MenuEntry extends ConsumerWidget {
  final MenuItem item;
  final IconData icon;
  final String title;
  final String description;

  const _MenuEntry({
    required this.item,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(isMenuItemSelectedProvider(item));

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(menuNavigationProvider.notifier).select(item);
          ref.read(appActionsProvider).handleAction(AppAction.confirm);
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          decoration:
              isSelected ? AppTheme.selectedPanel() : AppTheme.panel(),
          child: Row(
            children: [
              Icon(
                icon,
                size: 52,
                color:
                    isSelected ? AppPalette.accent : AppPalette.textMuted,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.title),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(description, style: AppType.bodySecondary),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 44,
                color:
                    isSelected
                        ? AppPalette.accent
                        : AppPalette.outlineStrong,
              ),
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

    return KeyHintRail(
      hints: [
        KeyHint(
          keys: [
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
        KeyHint(
          keys: [ref.watch(actionKeyLabelProvider(AppAction.back))],
          label: texts.hintBack,
          onTap: () => actions.handleAction(AppAction.back),
        ),
      ],
    );
  }
}
