#ifndef MyAppVersion
  #define MyAppVersion "1.2.0"
#endif
#ifndef MyAppName
  #define MyAppName "IT PDF"
#endif
#ifndef MyAppPublisher
  #define MyAppPublisher "Allrounder687"
#endif
#ifndef MyAppExeFolder
  #define MyAppExeFolder "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\releases"
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename "IT-PDF-x86_64-Setup"
#endif
#ifndef MyAppIcon
  #define MyAppIcon "..\..\windows\runner\resources\app_icon.ico"
#endif

[Setup]
AppId={{8E92D6F4-4B73-4F0E-9F5C-227A54E1C091}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/Allrounder687/it-pdf
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile={#MyAppIcon}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\it_pdf.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyAppExeFolder}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\it_pdf.exe"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\it_pdf.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\it_pdf.exe"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
