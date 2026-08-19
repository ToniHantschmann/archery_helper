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

  /// Faktor auf die eingepasste Größe; 1.0 ist der Zustand, den die `FittedBox`
  /// von sich aus findet.
  ///
  /// Kommt wie [uiStateProvider] von außen herein: die Größe ist eine
  /// Einstellung der Ampel, und Wettkampf und LED-Wand dürfen sie nicht
  /// mitbekommen — die eine hat ihre eigene Fläche, die andere ein festes
  /// Pixelraster.
  ///
  /// Über 1.0 wächst die Uhr über ihren Kasten hinaus und wird an dessen Kante
  /// beschnitten. Das ist Absicht: was von der Schießlinie aus lesbar ist, weiß
  /// nur, wer davorsteht, und die Zeilenbox der Schrift ist ohnehin höher als
  /// die Ziffern darin.
  final double scale;

  const TimerDisplay({
    super.key,
    required this.uiStateProvider,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(uiStateProvider);

    // Ampel-Modus: es gibt keine Zeit, also übernimmt das Signalwort den
    // Uhren-Platz und wird so groß wie die Fläche es zulässt. Ein zweites,
    // kleineres Wort darüber wäre nur eine Wiederholung.
    if (!uiState.showTime) {
      return ClipRect(
        child: Center(
          child: Transform.scale(
            scale: scale,
            child: FittedBox(
              fit: BoxFit.contain,
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.medium,
                curve: AppMotion.curve,
                style: AppType.clock.copyWith(color: uiState.phaseColor),
                child: Text(uiState.phaseText.toUpperCase(), maxLines: 1),
              ),
            ),
          ),
        ),
      );
    }

    // Der Schnitt sitzt außen, an der Anzeigefläche: eine vergrößerte Uhr darf
    // an deren Kante enden, aber niemals in die Status- oder Tastenleiste
    // hineinlaufen — die stehen für sich und nicht hinter der Zeit.
    return ClipRect(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Phase word ──
          //
          // Hier wächst die Schriftgröße selbst statt eines Transforms: das Wort
          // steckt in einer `scaleDown`-Box, wird also von sich aus nie breiter
          // als die Fläche — es kann mitwachsen, ohne beschnitten zu werden.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: AnimatedDefaultTextStyle(
              duration: AppMotion.medium,
              curve: AppMotion.curve,
              style: AppType.headline.copyWith(
                color: uiState.phaseColor,
                fontSize: AppType.headline.fontSize! * scale,
                fontWeight: uiState.isWarning
                    ? FontWeight.w800
                    : FontWeight.w600,
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
          // On its own layer: the digits change once a second and are the
          // largest thing on the screen, and without the boundary every change
          // repaints the tinted background behind them as well — which is
          // expensive enough on the web build to be visible.
          //
          // Der Transform sitzt innerhalb der Boundary, nicht darum herum:
          // außen läge die Boundary in Layoutgröße und würde erst danach
          // hochskaliert — die Ziffern kämen unscharf heraus.
          Expanded(
            child: Center(
              child: RepaintBoundary(
                child: Transform.scale(
                  scale: scale,
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
          ),
        ],
      ),
    );
  }
}
