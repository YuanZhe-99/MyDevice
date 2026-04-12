[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName=MyDevice!!!!!
AppVersion=0.3.0
AppPublisher=yuanzhe
AppPublisherURL=https://github.com/yuanzhe
DefaultDirName={autopf}\MyDevice!!!!!
DefaultGroupName=MyDevice!!!!!
UninstallDisplayIcon={app}\my_device.exe
OutputDir=build\installer
OutputBaseFilename=MyDevice_0.3.0_Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
SetupIconFile=windows\runner\resources\app_icon.ico
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\MyDevice!!!!!"; Filename: "{app}\my_device.exe"
Name: "{group}\{cm:UninstallProgram,MyDevice!!!!!}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\MyDevice!!!!!"; Filename: "{app}\my_device.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\my_device.exe"; Description: "{cm:LaunchProgram,MyDevice!!!!!}"; Flags: nowait postinstall skipifsilent
