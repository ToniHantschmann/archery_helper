/// Supported languages in the app
enum AppLanguage {
  german('de'),
  english('en');

  final String code;

  const AppLanguage(this.code);

  /// Parse language from code (e.g., "de" -> german)
  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.german,
    );
  }
}

/// Base class for localized texts
/// Each text constant stores translations for German and English
class LocalizedText {
  final String de;
  final String en;

  const LocalizedText({required this.de, required this.en});

  /// Get text for a specific language
  String get(AppLanguage language) {
    switch (language) {
      case AppLanguage.german:
        return de;
      case AppLanguage.english:
        return en;
    }
  }
}
