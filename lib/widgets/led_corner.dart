import 'package:flutter/material.dart';

import 'led_panel.dart';

/// Die Kantenlängen der Ecke in *logischen* Pixeln.
///
/// Das Panel misst feste 120 × 80 Gerätepixel; wie viel Platz das im Layout
/// daneben wegnimmt, hängt daher am Pixelverhältnis. Wer unter der Ecke etwas
/// freihalten muss, fragt hier — statt die Rechnung ein zweites Mal
/// hinzuschreiben.
Size ledCornerSize(BuildContext context) {
  final ratio = MediaQuery.devicePixelRatioOf(context);
  return Size(LedPanelSpec.width / ratio, LedPanelSpec.height / ratio);
}

/// Legt [LedPanel] in echten Gerätepixeln auf die linke obere Ecke des Bildes.
///
/// Der Mediaplayer schneidet genau dieses Rechteck aus dem HDMI-Signal; alles
/// daneben existiert für die Wand nicht. Daraus folgt die ganze Bauweise dieses
/// Modus: die Ecke wird als *letztes* Kind eines [Stack] über die
/// Bedienansicht gelegt, und damit kann kein Layout darunter den Ausschnitt
/// verderben. Was neben der Ecke steht, geht die Wand nichts an.
///
/// Bewusst außerhalb der `SafeArea` des Wettkampfschirms: die Ecke muss die
/// echte Bildecke treffen und nicht die des nutzbaren Bereichs.
class LedCorner extends StatelessWidget {
  const LedCorner({super.key});

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);

    assert(() {
      if (ratio != ratio.roundToDouble()) {
        debugPrint(
          'LedCorner: devicePixelRatio $ratio ist nicht ganzzahlig — das Panel '
          'wird umgerechnet und die Ziffern verwischen auf der Wand. '
          'Anzeigeskalierung auf 100 % stellen.',
        );
      }
      return true;
    }());

    // Kein `SizedBox` darum: das Panel soll seine natürlichen 120 × 80 messen
    // und erst beim *Zeichnen* auf Gerätepixel geschrumpft werden. Eine feste,
    // kleinere Box würde die Zellen im Inneren zusammendrücken.
    return Transform.scale(
      scale: 1 / ratio,
      alignment: Alignment.topLeft,
      child: const LedPanel(),
    );
  }
}
