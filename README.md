# Archery Helper

Schießzeit-Ampel und Wettkampf-Uhr für den Bogensport — gebaut für den
Hallen-Schießtunnel eines Vereins, wo zwei Monitore über der Schießlinie hängen.

Die App ist als **Kiosk-Anzeige** gedacht: groß genug, um aus mehreren Metern
Entfernung gelesen zu werden, und vollständig über die Tastatur bedienbar. Maus
oder Touch werden nicht gebraucht.

## Werkzeuge

- **Ampel** — die Schießzeit-Uhr für das Training. Vorbereitungszeit,
  Schießzeit, Ende; Hallen- und Feldvorgaben, frei einstellbare Zeiten sowie ein
  1-gegen-1-Modus mit abwechselnden Passagen.
- **Wettkampf** — eine WA-Qualifikationsrunde: Passen, Gruppenwechsel (AB/CD),
  Pfeilzahl und Schießzeit nach Halle oder Freiluft.
- **Ampel manuell** — Rot und Grün von Hand geschaltet, ohne Uhr.
- **Ruhebild** — eine große Uhr für die Zeit zwischen den Runden.

Signaltöne für Start, Ende und Pfeilabholung sind eingebaut, in zwei Klangfarben:
eine reine Sinus-Variante für die Halle und eine obertonreichere, die im Freien
trägt.

Anzeigesprache: Deutsch oder Englisch.

## Bedienung

Alles läuft über die Tastatur — es gibt keine Bedienelemente, die man anklicken
müsste.

| Taste | Wirkung |
|---|---|
| `Leertaste` | Weiter — starten, Phase überspringen, nächste Passe |
| `P` | Uhr anhalten / weiterlaufen lassen |
| `R` | Uhr zurücksetzen |
| `⌫` / `⌦` | Eine Position zurück bzw. vor, ohne die Uhr zu starten |
| `M` | Nächster Modus (Ampel) |
| `S` | Einstellungen des aktuellen Werkzeugs |
| `Esc` | Zurück — ins Hauptmenü, aus den Einstellungen zum Werkzeug |
| `Enter` | Auswählen / bestätigen |
| `↑ ↓ ← →` | Navigieren, Werte verstellen |
| `F11` | Vollbild |

Die Tastenbelegung ist änderbar und wird gespeichert.

## Installation

Fertige Pakete liegen unter
[Releases](https://github.com/ToniHantschmann/archery_helper/releases).

### Linux

Zwei Wege, beide für x86-64:

- **`.deb`** (Debian, Ubuntu, Mint):
  ```bash
  sudo apt install ./archery-helper_1.0.0_amd64.deb
  ```
  Danach steht der Eintrag im Startmenü; auf der Kommandozeile heißt das
  Programm `archery_helper`.

- **AppImage** (jede Distribution):
  ```bash
  chmod +x Archery_Helper-1.0.0-x86_64.AppImage
  ./Archery_Helper-1.0.0-x86_64.AppImage
  ```

**Systemvoraussetzungen:** GTK 3 sowie GStreamer mit den „good“-Plugins — ohne
die bleiben die Signaltöne stumm. Auf den meisten Desktop-Installationen ist
beides vorhanden; das `.deb` zieht es als Abhängigkeit selbst nach. Beim AppImage
gegebenenfalls von Hand:

```bash
sudo apt install libgtk-3-0 gstreamer1.0-plugins-good   # Debian/Ubuntu
sudo dnf install gtk3 gstreamer1-plugins-good           # Fedora
```

Gebaut wird auf Ubuntu 22.04, die Pakete laufen also ab glibc 2.35 (Ubuntu 22.04,
Debian 12 und neuer).

### Windows

`archery-helper-1.0.0-windows-setup.exe` herunterladen und ausführen. Der
Installer ist nicht signiert, deshalb meldet sich SmartScreen: „Weitere
Informationen“ → „Trotzdem ausführen“.

## Aus dem Quellcode bauen

Es braucht das [Flutter SDK](https://docs.flutter.dev/get-started/install)
(Version 3.38 oder neuer) mit aktivierter Desktop-Unterstützung.

```bash
flutter pub get
flutter run -d linux            # oder -d windows
flutter build linux --release   # Ergebnis in build/linux/x64/release/bundle
```

Entwicklung:

```bash
flutter analyze   # muss ohne Befund durchlaufen
flutter test
```

Auf Linux werden zusätzlich `clang`, `cmake`, `ninja-build`, `pkg-config`,
`libgtk-3-dev`, `liblzma-dev` und die GStreamer-Entwicklungspakete gebraucht.

Die Paketierungs-Rezepte liegen unter `packaging/`, der Release-Workflow unter
`.github/workflows/release.yml`.

## Lizenz

Privates Vereinsprojekt, ohne Gewähr.
