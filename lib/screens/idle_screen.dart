import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/idle_texts.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_typography.dart';
import '../models/keyboard_config.dart';
import '../providers/app_actions_provider.dart';
import '../providers/ui_providers.dart';
import '../widgets/key_hint_rail.dart';
import '../widgets/wall_clock.dart';

/// Standby display: a wall clock, the club context, and how to get going.
///
/// This is what hangs above the shooting line when nobody is using the timer,
/// so it is deliberately quiet — no signal colours, no motion, one number.
/// Any meaningful key wakes it into the timer (see IdleScreenActions).
class IdleScreen extends ConsumerWidget {
  const IdleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(idleTextsProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [Color(0xFF101A28), AppPalette.abyss],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  0,
                ),
                child: Row(
                  children: [
                    Text(
                      texts.title.toUpperCase(),
                      style: AppType.label.copyWith(
                        color: AppPalette.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppPalette.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      texts.subtitle.toUpperCase(),
                      style: AppType.label.copyWith(
                        color: AppPalette.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                    ),
                    child: const WallClockFace(),
                  ),
                ),
              ),

              _IdleHintRail(texts: texts),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdleHintRail extends ConsumerWidget {
  final IdleTexts texts;

  const _IdleHintRail({required this.texts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KeyHintRail(
      hints: [
        KeyHint(
          keys: [ref.watch(actionKeyLabelProvider(AppAction.next))],
          label: texts.wakeHint,
          emphasised: true,
          onTap: () =>
              ref.read(appActionsProvider).handleAction(AppAction.next),
        ),
      ],
    );
  }
}
