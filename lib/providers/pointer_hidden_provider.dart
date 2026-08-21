import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ob der Mauszeiger gerade versteckt ist.
///
/// Bedient wird die App über die Tastatur; die Maus ist an einem Kiosk-Display
/// die Ausnahme. Ein Zeiger, der irgendwo im Bild stehen bleibt, ist über der
/// Schießlinie nur Störbild — er verschwindet deshalb mit dem ersten
/// Tastendruck ([hide], aus `KeyboardScope`) und kommt zurück, sobald die Maus
/// bewegt wird ([reveal], aus dem `MouseRegion` in `app.dart`). Beim Start ist
/// er sichtbar: wer die App gerade erst geöffnet hat, soll sein Fenster noch
/// anklicken können.
///
/// Der ganze Zustand ist ein Bool — wie beim `TrafficLightNotifier` braucht es
/// dafür kein eigenes Modell.
class PointerHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Tastatureingabe: Zeiger weg.
  void hide() {
    if (!state) state = true;
  }

  /// Mausbewegung: Zeiger wieder da.
  void reveal() {
    if (state) state = false;
  }
}

/// Bewusst nicht `autoDispose`: der Zustand gilt für die ganze Laufzeit und
/// hat mit dem `MouseRegion` um den `AppNavigator` einen dauerhaften Zuhörer —
/// eine Änderung wird also sofort ausgeführt und nicht in den nächsten Build
/// verschoben (siehe CLAUDE.md zum manuell erzeugten `ProviderContainer`).
final pointerHiddenProvider =
    NotifierProvider<PointerHiddenNotifier, bool>(
      PointerHiddenNotifier.new,
    );
