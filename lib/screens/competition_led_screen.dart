import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../models/competition_state.dart';
import '../widgets/led_panel.dart';

/// Der Wettkampfmodus für die LED-Wand am Außenstand.
///
/// Zwei Betriebsarten, beide auf demselben [LedPanel]:
///
/// * [CompetitionDisplay.led] setzt das Panel **1:1 in Gerätepixeln** links
///   oben ab. Die Steuerkarte der Wand (HDPlayer/LedShowSuite, also Huidu)
///   greift aus dem HDMI-Signal einen Ausschnitt ab — üblicherweise ab
///   Position 0,0 —, statt sich als 192×128-Monitor zu melden. Exakt 192 × 128
///   echte Pixel in der Ecke passen damit für beide Fälle. Der Rest des Bildes
///   bleibt schwarz und ist der Wand egal.
/// * [CompetitionDisplay.ledPreview] skaliert dasselbe Panel ganzzahlig auf das
///   Fenster, damit sich das Layout auf einem gewöhnlichen Bildschirm
///   überhaupt beurteilen lässt. Ganzzahlig, weil nur so die Proportionen des
///   Rasters erhalten bleiben. Der Text wird dabei in voller Auflösung neu
///   gerastert — die Vorschau zeigt Größenverhältnisse wahrheitsgetreu, aber
///   nicht, wie scharf eine Kante auf der Wand am Ende wirkt.
class CompetitionLedScreen extends ConsumerWidget {
  /// Ob das Panel hochskaliert beurteilt werden soll, statt echte Dioden zu
  /// treffen. Als Parameter und nicht aus den Einstellungen gelesen: der Schirm
  /// muss nicht wissen, *warum* er gezeigt wird — nur, wie er aussehen soll.
  final bool isPreview;

  const CompetitionLedScreen({super.key, required this.isPreview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppPalette.ledBlack,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Logische Pixel sind nur bei einem Verhältnis von 1 auch echte. Der
          // Kehrwert holt die Skalierung des Fensters wieder heraus, damit das
          // Panel wirklich 192 × 128 Dioden trifft und nicht 192 × 128 mal
          // irgendetwas.
          final scale = isPreview
              ? _previewScale(constraints)
              : 1 / MediaQuery.devicePixelRatioOf(context);

          return Align(
            alignment: isPreview ? Alignment.center : Alignment.topLeft,
            child: Transform.scale(
              scale: scale,
              alignment: isPreview ? Alignment.center : Alignment.topLeft,
              child: const LedPanel(),
            ),
          );
        },
      ),
    );
  }

  static double _previewScale(BoxConstraints constraints) {
    final fit = math.min(
      constraints.maxWidth / LedPanelSpec.width,
      constraints.maxHeight / LedPanelSpec.height,
    );

    return math.max(1, fit.floorToDouble());
  }
}
