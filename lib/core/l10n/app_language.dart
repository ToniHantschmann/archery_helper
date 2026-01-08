/// Supported languages in the app
enum AppLanguage {
  german('de', 'Deutsch'),
  english('en', 'English');

  final String code;
  final String displayName;

  const AppLanguage(this.code, this.displayName);

  /// Parse language from code (e.g., "de" -> german)
  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.german,
    );
  }
}

/// Base class for localized texts
class LocalizedText {
  final String de;
  final String en;

  const LocalizedText({required this.de, required this.en});

  String get(AppLanguage language) {
    switch (language) {
      case AppLanguage.german:
        return de;
      case AppLanguage.english:
        return en;
    }
  }
}
