import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_typography.dart';
import '../providers/ui_providers.dart';

/// The countdown block: phase word and clock.
///
/// Nothing else — no progress bar, no badges. The clock is already the largest
/// thing in the tunnel and the tinted screen carries the signal, so a second
/// representation of the same information would only compete with it.
///
/// The clock is wrapped in a `FittedBox`, so it always takes the largest size
/// the available space allows — a fixed point size would either waste half the
/// panel on a 2560px monitor or overflow in a windowed 1280px session.
///
/// Im Ampel-Modus gibt es keine Zeit: dort rückt das Signalwort an die Stelle
/// der Uhr und ist damit die ganze Anzeige.
///
/// Der Zustand kommt als Provider herein statt fest aus [timerUIStateProvider]:
/// Ampel und Wettkampf zeigen dieselbe Anzeige aus verschiedenen Quellen, und
/// zwei Kopien dieses Aufbaus würden zwangsläufig auseinanderlaufen.
class TimerDisplay extends ConsumerWidget {
  final Provider<TimerUIState> uiStateProvider;

  const TimerDisplay({super.key, required this.uiStateProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(uiStateProvider);

    // Ampel-Modus: es gibt keine Zeit, also übernimmt das Signalwort den
    // Uhren-Platz und wird so groß wie die Fläche es zulässt. Ein zweites,
    // kleineres Wort darüber wäre nur eine Wiederholung.
    if (!uiState.showTime) {
      return Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.medium,
            curve: AppMotion.curve,
            style: AppType.clock.copyWith(color: uiState.phaseColor),
            child: Text(uiState.phaseText.toUpperCase(), maxLines: 1),
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Phase word ──
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.medium,
            curve: AppMotion.curve,
            style: AppType.headline.copyWith(
              color: uiState.phaseColor,
              fontWeight: uiState.isWarning ? FontWeight.w800 : FontWeight.w600,
            ),
            child: Text(
              uiState.phaseText.toUpperCase(),
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Clock ──
        //
        // On its own layer: the digits change once a second and are the largest
        // thing on the screen, and without the boundary every change repaints
        // the tinted background behind them as well — which is expensive
        // enough on the web build to be visible.
        Expanded(
          child: Center(
            child: RepaintBoundary(
              child: FittedBox(
                fit: BoxFit.contain,
                child: AnimatedDefaultTextStyle(
                  duration: AppMotion.medium,
                  curve: AppMotion.curve,
                  style: AppType.clock.copyWith(color: uiState.timeColor),
                  child: Text(uiState.formattedTime, maxLines: 1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
