# Release 1.0: Linux- und Windows-Pakete über GitHub Actions

## Context

Die App ist funktional fertig, aber noch nie verteilt worden. Sie soll auf anderen Linux-PCs (Vereins-Tunnel, unbekannte Distribution) und auf Windows-PCs installierbar sein. Aktuell existiert dafür nichts: keine CI, kein `.desktop`, kein Installer, und sämtliche Metadaten stehen noch auf den Flutter-Vorlagenwerten (`com.example.archery_helper`, `"A new Flutter project."`, Version `0.1.0`).

Zwei technische Randbedingungen bestimmen den Aufbau:

1. **Ein auf NixOS gebautes Binary läuft auf keinem anderen Linux.** ELF-Interpreter und Bibliothekspfade zeigen fest nach `/nix/store/…`. Portable Linux-Artefakte müssen auf einem Ubuntu-System entstehen.
2. **Flutter kann Windows nicht cross-kompilieren.** Es braucht eine echte Windows-Maschine mit MSVC-Toolchain.

Beides löst ein GitHub-Actions-Workflow mit zwei parallelen Jobs. Das Repo ist öffentlich, GitHub-gehostete Standard-Runner sind damit kostenlos und ohne Minutenlimit.

**Ergebnis:** Ein `git push` eines Tags `v1.0.0` erzeugt ein GitHub Release mit drei Downloads — `Archery_Helper-1.0.0-x86_64.AppImage`, `archery-helper_1.0.0_amd64.deb` und `archery-helper-1.0.0-windows-setup.exe`.

**Entscheidungen (bestätigt):** Anzeigename `Archery Helper`, App-ID `io.github.tonihantschmann.bogenampel`, kein eigenes Icon vorerst. *Randnotiz: die ID sagt „bogenampel", der Anzeigename „Archery Helper" — funktional egal, aber falls das stören sollte, ist es jetzt der billigste Moment zum Ändern (die ID nachträglich zu wechseln bedeutet für bereits installierte Nutzer einen Neueintrag im Startmenü).*

---

## Teil 1 — Metadaten und Rebranding

| Datei | Änderung |
|---|---|
| `pubspec.yaml` | `description:` auf einen echten Satz; `version: 1.0.0+1` (das `+1` ist der Build-Zähler, den Windows für `FILEVERSION` braucht) |
| `linux/CMakeLists.txt:10` | `APPLICATION_ID` → `io.github.tonihantschmann.bogenampel`. `BINARY_NAME` bleibt `archery_helper` (Pfade im Bundle hängen daran) |
| `linux/runner/my_application.cc:43,47` | Fenstertitel `"archery_helper"` → `"Archery Helper"`, beide Stellen. Beseitigt nebenbei den Titel-Flackerer gegenüber `WindowOptions(title: 'Archery Helper')` in `lib/core/window/window_service.dart:25` |
| `windows/runner/Runner.rc:92-99` | `CompanyName`/`LegalCopyright` → `Toni Hantschmann`; `FileDescription`/`ProductName` → `Archery Helper`; `InternalName`/`OriginalFilename` unverändert lassen (müssen zum Binärnamen passen) |
| `README.md` | Ersetzt die Zweizeiler-Vorlage: was die App ist, Download-Links auf das Release, Tastaturbedienung, Linux-Systemvoraussetzungen. Bei einem öffentlichen Repo ist das faktisch die Produktseite |

`web/index.html` und `web/manifest.json` tragen die Vorlagenbeschreibung ebenfalls — mitziehen, wenn schon dabei; für die Desktop-Auslieferung aber irrelevant.

`macos/`, `android/`, `ios/` bleiben unangetastet (nicht Teil dieses Releases).

---

## Teil 2 — Paketierungs-Artefakte im Repo

Neues Verzeichnis `packaging/`, damit die Rezepte versioniert neben dem Code liegen und der Workflow sie nur noch aufruft:

### `packaging/linux/io.github.tonihantschmann.bogenampel.desktop`
Der Dateiname **muss** exakt die App-ID sein — `my_application.cc:124` ruft `g_set_prgname(APPLICATION_ID)`, und darüber ordnet der Desktop das laufende Fenster seinem Menüeintrag zu. Inhalt: `Name=Archery Helper`, `Exec=archery_helper`, `Categories=Utility;Sports;`, `Terminal=false`, `Icon=io.github.tonihantschmann.bogenampel`.

### `packaging/linux/make_deb.sh`
Baut aus `build/linux/x64/release/bundle` eine `.deb`:
- Bundle nach `/opt/archery_helper`, Symlink `/usr/bin/archery_helper`, `.desktop` nach `/usr/share/applications`
- `DEBIAN/control` mit `Architecture: amd64`, Version aus `pubspec.yaml` gelesen, und **`Depends:`** — das ist der Teil, der über Erfolg oder Fehlschlag auf dem Zielrechner entscheidet:
  `libgtk-3-0, libglib2.0-0, libstdc++6, libgstreamer1.0-0, libgstreamer-plugins-base1.0-0, gstreamer1.0-plugins-good`
  Die drei GStreamer-Einträge sind für `audioplayers` nötig; `plugins-good` enthält `wavparse` und die Audio-Ausgabe, ohne die die Signaltöne stumm bleiben.
- `dpkg-deb --build`

### `packaging/linux/make_appimage.sh`
AppDir-Struktur aufbauen, `appimagetool` herunterladen, packen. AppImages bündeln Flutters `lib/`-Verzeichnis mit, ziehen GTK und GStreamer aber weiterhin vom Wirtssystem — das ist bei GTK-Apps üblich und praktisch überall erfüllt. `appimagetool` braucht auf CI-Runnern `--appimage-extract-and-run`, weil dort kein FUSE verfügbar ist.

**Offener Punkt:** `appimagetool` erwartet ein Icon im AppDir-Wurzelverzeichnis. Da vorerst kein eigenes Icon existiert, kommt ein schlichtes einfarbiges Platzhalter-PNG unter `packaging/linux/icon.png` dazu, das später einfach ausgetauscht wird.

### `packaging/windows/archery_helper.iss`
Inno-Setup-Skript, rund 40 Zeilen:
- `AppId` = die App-ID in geschweiften Klammern, `AppName=Archery Helper`, Version per `/D`-Parameter vom Workflow injiziert
- Ziel `{autopf}\Archery Helper`, Startmenü-Eintrag, optionale Desktop-Verknüpfung, Deinstallation über die Systemsteuerung
- Quelle: alles aus `build\windows\x64\runner\Release\` rekursiv
- **VC++-Runtime:** Flutter legt `msvcp140.dll`, `vcruntime140.dll` und `vcruntime140_1.dll` nicht selbst in den Release-Ordner. Auf Windows 10/11 sind sie meist vorhanden, garantiert ist es nicht. Der Workflow kopiert sie vor dem Packen aus dem VC-Redist-Verzeichnis des Runners dazu — das ist erlaubt (App-lokale Auslieferung) und billiger als ein Redist-Installer im Setup.

---

## Teil 3 — `.github/workflows/release.yml`

```yaml
on:
  push:
    tags: ['v*']
  workflow_dispatch:      # manuell auslösbar — wichtig fürs Einfahren
permissions:
  contents: write         # nötig, damit der Release-Job schreiben darf
```

**Job `build-linux`** — `runs-on: ubuntu-22.04`:
- `apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`
- `subosito/flutter-action@v2` mit `flutter-version: 3.38.3`, `cache: true`
- `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build linux --release`
  Analyze und Test als Torwächter: kein Release aus einem Stand, der die Suite nicht besteht.
- `packaging/linux/make_deb.sh`, `packaging/linux/make_appimage.sh`
- `actions/upload-artifact@v4`

> **Warum 22.04 und nicht `ubuntu-latest`:** glibc ist abwärts-, nicht aufwärtskompatibel. Ein auf 24.04 (glibc 2.39) gebautes Binary startet auf Ubuntu 22.04 oder Debian 12 nicht. Auf 22.04 gebaut läuft es auf beidem. Sollte GitHub das `ubuntu-22.04`-Image inzwischen zurückgezogen haben, ist der Ersatz `runs-on: ubuntu-latest` mit `container: ubuntu:22.04` — dann müssen `git`, `curl`, `unzip` und `xz-utils` zusätzlich installiert werden. Das fällt beim ersten Lauf sofort auf.

**Job `build-windows`** — `runs-on: windows-latest`:
- `subosito/flutter-action@v2`, `flutter pub get`, `flutter build windows --release`
- VC-Runtime-DLLs in den Release-Ordner kopieren
- `iscc packaging\windows\archery_helper.iss /DMyAppVersion=…` (Inno Setup ist auf dem Runner vorinstalliert; `choco install innosetup -y` als Rückfallebene)
- `actions/upload-artifact@v4`

**Job `release`** — `needs: [build-linux, build-windows]`, läuft nur bei Tag-Push:
- `actions/download-artifact@v4`, dann `softprops/action-gh-release@v2` mit dem automatisch vorhandenen `GITHUB_TOKEN`. Kein Secret einzurichten.

---

## Teil 4 — Optional: lokaler Testbuild ohne Push

`packaging/linux/build_in_container.sh` — führt denselben Ablauf in einem `ubuntu:22.04`-Container per Podman/Docker aus. Spart die Push-Warten-Schleife beim Einfahren der Skripte. Nice-to-have; die Skripte funktionieren auch ohne.

---

## Verifikation

1. **Lokal:** `flutter analyze` (muss null Issues zeigen) und `flutter test` nach den Rebranding-Änderungen. `flutter run -d linux` — Fenstertitel muss „Archery Helper" lauten, Signaltöne müssen weiterhin klingen.
2. **CI einfahren:** Workflow per `workflow_dispatch` von Hand starten, *bevor* ein Tag gesetzt wird. Erwartung: die ersten ein bis zwei Läufe schlagen an fehlenden apt-Paketen oder Pfaden fehl — das ist normal, korrigieren und erneut auslösen.
3. **Linux-Artefakte prüfen:**
   - `.deb` in einem frischen `ubuntu:24.04`-Container mit `apt install ./archery-helper_*.deb` installieren; `ldd /opt/archery_helper/archery_helper` darf kein „not found" zeigen.
   - AppImage auf einem Nicht-Ubuntu-System starten (Fedora-Live-USB oder Container mit X11-Weiterleitung). Der eigentliche Test ist ein echter Vereins-PC.
   - **Audio explizit testen** — die GStreamer-Abhängigkeit ist der wahrscheinlichste Bruchpunkt und fällt bei einem reinen Startversuch nicht auf.
4. **Windows:** `setup.exe` aus dem Actions-Artefakt herunterladen, auf deinem Windows-PC installieren. Prüfen: Startmenü-Eintrag, Vollbild per Tastenkürzel, Signaltöne, Deinstallation über die Systemsteuerung. SmartScreen wird bei einem unsignierten Installer warnen („Weitere Informationen" → „Trotzdem ausführen") — das ist ohne Code-Signing-Zertifikat (dreistellig pro Jahr) nicht vermeidbar und für den Vereinsgebrauch zumutbar.
5. **Release scharf schalten:** `git tag v1.0.0 && git push origin v1.0.0`, dann die Release-Seite auf drei Anhänge prüfen.

## Was dieser Plan bewusst auslässt

- Code-Signing für Windows und macOS-Builds
- Flatpak/Flathub-Einreichung
- Autostart-/Kiosk-Unit für den Tunnel-PC (systemd-User-Unit oder Autostart-`.desktop`) — sinnvoll als Folgeschritt, sobald die Pakete stehen
- Ein eigenes Icon (Platzhalter jetzt, Austausch jederzeit ohne Strukturänderung möglich)
