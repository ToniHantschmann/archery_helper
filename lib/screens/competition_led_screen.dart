import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../widgets/led_panel.dart';

/// Der Wettkampfmodus für die LED-Wand am Außenstand.
///
/// Die Steuerkarte der Wand überträgt das ganze Monitorbild, also füllt das
/// [LedPanel] das Fenster — auf dem Laptop, der die Wand speist, ist es damit
/// zugleich die Kontrollansicht. Dass der Schießleiter dabei die Tastenleiste
/// verliert, ist Absicht: er soll dasselbe sehen wie die Anzeigetafel.
///
/// Wie 16:9 auf die 3:2 der Wand kommt, entscheidet die Steuerkarte, nicht die
/// App — deshalb kommt die Einpassung als [fit] von außen (siehe
/// `CompetitionDisplay.ledFit`) und ist hier keine Annahme.
class CompetitionLedScreen extends ConsumerWidget {
  /// Wie das Panel ins Fenster gelegt wird: [BoxFit.contain] proportionsgetreu,
  /// [BoxFit.fill] gestreckt. Als Parameter und nicht aus den Einstellungen
  /// gelesen: der Schirm muss nicht wissen, *warum* er so aussieht.
  final BoxFit fit;

  const CompetitionLedScreen({super.key, required this.fit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Das Panel misst feste 192 × 128 und wird erst beim Zeichnen skaliert —
    // eine kleinere oder größere Box würde die Zellen im Inneren verschieben.
    // `SizedBox.expand` ist dabei nicht schmückend: der Rumpf eines `Scaffold`
    // bekommt lose Constraints, und ohne den Zwang aufs volle Bild bliebe die
    // `FittedBox` genau so groß wie ihr Kind und würde nichts skalieren.
    // Kein Mauszeiger, und zwar unabhängig davon, ob gerade getippt wurde: auf
    // der Anzeigetafel wäre er ein heller Fleck mitten im Bild. Die innerste
    // `MouseRegion` bestimmt den Zeiger, also überstimmt diese hier den
    // `_PointerScope` um den ganzen `AppNavigator`.
    return MouseRegion(
      cursor: SystemMouseCursors.none,
      child: Scaffold(
        backgroundColor: AppPalette.ledBlack,
        body: SizedBox.expand(
          child: FittedBox(fit: fit, child: const LedPanel()),
        ),
      ),
    );
  }
}
