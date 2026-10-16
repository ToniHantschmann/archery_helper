import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import 'app_language.dart';

/// Localized texts for the hand-switched traffic light.
///
/// Eines der beiden Signalwörter ersetzt hier die ganze Anzeige, es steht also
/// formatfüllend im Tunnel. Beide sind kurz gehalten, damit die `FittedBox` sie
/// gleich groß skaliert — ein langes Wort auf einer Seite würde den Wechsel
/// auch als Größensprung lesen lassen.
class TrafficLightTexts {
  final AppLanguage _language;

  const TrafficLightTexts(this._language);

  static const _shoot = LocalizedText(de: 'Schießen', en: 'Shoot');

  static const _stop = LocalizedText(de: 'Stopp', en: 'Stop');

  String get shoot => _shoot.get(_language);
  String get stop => _stop.get(_language);
}

// ===== PROVIDER =====

final trafficLightTextsProvider = Provider<TrafficLightTexts>((ref) {
  return TrafficLightTexts(ref.watch(languageProvider));
});
