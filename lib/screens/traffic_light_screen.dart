import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_dimens.dart';
import '../providers/settings_provider.dart';
import '../providers/traffic_light_provider.dart';
import '../widgets/timer_display.dart';

/// Die Ampel von Hand — Rot und Grün, ohne Uhr.
///
/// Dasselbe Bild wie beim Timer, nur ohne dessen Randstreifen: es gibt keinen
/// Modus anzuzeigen und keine Pfeile zu zählen, und die Tastenlegende, die beim
/// Timer nur während der laufenden Uhr wegfährt, fehlt hier ganz — ohne Uhr
/// gäbe es keinen Moment, in dem sie wiederkäme. Übrig bleibt der getönte
/// Schirm und das Signalwort darauf, das hier die Stelle der Uhr einnimmt und
/// damit die ganze Anzeige ist.
///
/// Tasten kommen wie überall aus KeyboardScope (siehe app.dart).
class TrafficLightScreen extends ConsumerWidget {
  const TrafficLightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = ref.watch(trafficLightGradientProvider);

    return Scaffold(
      body: AnimatedContainer(
        duration: AppMotion.slow,
        curve: AppMotion.curve,
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  child: TimerDisplay(
                    uiStateProvider: trafficLightUIStateProvider,
                    scale: ref.watch(timerScaleProvider),
                  ),
                ),
              ),            ],
          ),
        ),
      ),
    );
  }
}
