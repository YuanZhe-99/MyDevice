[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName=MyDevice!!!!!
AppVersion=0.4.1
AppPublisher=yuanzhe
AppPublisherURL=https://github.com/yuanzhe
DefaultDirName={autopf}\MyDevice!!!!!
DefaultGroupName=MyDevice!!!!!
UninstallDisplayIcon={app}\my_device.exe
OutputDir=build\installer
#ifdef ARM64
OutputBaseFilename=MyDevice_0.4.1_arm64_Setup
#else
OutputBaseFilename=MyDevice_0.4.1_Setup
#endif
Compression=lzma2
SolidCompression=yes
#ifdef ARM64
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
WizardStyle=modern
SetupIconFile=windows\runner\resources\app_icon.ico
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
#ifdef ARM64
Source: "build\windows\arm64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
#else
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
#endif

[Icons]
Name: "{group}\MyDevice!!!!!"; Filename: "{app}\my_device.exe"
Name: "{group}\{cm:UninstallProgram,MyDevice!!!!!}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\MyDevice!!!!!"; Filename: "{app}\my_device.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\my_device.exe"; Description: "{cm:LaunchProgram,MyDevice!!!!!}"; Flags: nowait postinstall skipifsilent
