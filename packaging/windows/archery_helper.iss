; Inno-Setup-Skript für den Windows-Installer.
;
;   flutter build windows --release
;   iscc packaging\windows\archery_helper.iss /DMyAppVersion=1.0.0
;
; Ergebnis: dist\archery-helper-<version>-windows-setup.exe
; Ohne /D fällt die Version auf 0.0.0 zurück — dann war es ein Testlauf.

#define MyAppName "Archery Helper"
#define MyAppPublisher "Toni Hantschmann"
#define MyAppURL "https://github.com/ToniHantschmann/archery_helper"
#define MyAppExeName "archery_helper.exe"

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

[Setup]
; Die App-ID identifiziert die Installation gegenüber Windows: über sie findet
; ein Update die Vorgängerversion und die Systemsteuerung den Eintrag. Die
; doppelte Klammer ist Inno-Syntax für eine einzelne führende Klammer.
AppId={{io.github.tonihantschmann.bogenampel}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
VersionInfoVersion={#MyAppVersion}

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
; x64compatible braucht Inno 6.3+; auf älteren Versionen heißt es schlicht x64.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

OutputDir=..\..\dist
OutputBaseFilename=archery-helper-{#MyAppVersion}-windows-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Der komplette Release-Ordner: die Anwendung sucht data\ und ihre DLLs neben
; der exe, die drei Teile dürfen nicht auseinandergezogen werden. Die
; VC++-Runtime-DLLs legt der Workflow vorher mit hinein.
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
