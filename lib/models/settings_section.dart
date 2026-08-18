/// Die Einstellungsbereiche der App — je einer pro Screen.
///
/// Es gibt kein globales Einstellungsmenü mehr: was zur Ampel gehört, steht bei
/// der Ampel, was zum Wettkampf gehört, beim Wettkampf, und [general] hält das,
/// was für die ganze App gilt (Sprache, Ton). Der Bereich ist damit die
/// Zuordnung „welcher Wert wird wo eingestellt" — er entscheidet, welche
/// [SettingsItem]s ein Screen zeigt und was seine Reset-Zeile zurücksetzt.
enum SettingsSection { general, timer, competition }
