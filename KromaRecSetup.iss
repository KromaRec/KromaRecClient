; Adapted from the RecFlare master installer workflow at beff81c.
; Build via scripts\Build-Installer.ps1.
#include "stage\checksums.iss"

[Setup]
AppId={{B6032AF7-9C25-49D8-9438-D04386181656}
AppName=KromaRec Client
AppPublisher=KromaRec
AppVersion=0.1.0
AppSupportURL=https://github.com/KromaRec/KromaRecClient
DefaultDirName={userprofile}\Games\KromaRec-20230414
DisableProgramGroupPage=yes
DisableDirPage=no
DirExistsWarning=no
UsePreviousAppDir=yes
PrivilegesRequired=lowest
MinVersion=10.0.17763
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
OutputBaseFilename=KromaRecSetup-20230414
OutputDir=Output
SolidCompression=yes
CloseApplications=yes
CloseApplicationsFilter=RecRoom.exe
RestartApplications=no
AppMutex=KromaRecClientSetup
SetupMutex=KromaRecClientInstaller

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Files]
#include "stage\loader-files.iss"
Source: "stage\loader.owner"; DestDir: "{app}\BepInEx"; DestName: "kromarec-loader.owner"; Flags: ignoreversion; Check: InstallLoader
Source: "stage\loader.sha256"; Flags: dontcopy
Source: "stage\KromaRec.Patch.dll"; DestDir: "{app}\BepInEx\plugins"; Flags: ignoreversion; AfterInstall: VerifyInstalledPatch

[Icons]
Name: "{autoprograms}\KromaRec Client (Screen)"; Filename: "{app}\RecRoom.exe"; Parameters: "+forcemode:screen"; WorkingDir: "{app}"
Name: "{autoprograms}\KromaRec Client (VR)"; Filename: "{app}\RecRoom.exe"; Parameters: "+forcemode:vr"; WorkingDir: "{app}"
Name: "{autodesktop}\KromaRec Client"; Filename: "{app}\RecRoom.exe"; Parameters: "+forcemode:screen"; WorkingDir: "{app}"; Tasks: desktopicon

[Code]
var
  BackendPage, PhotonPage: TInputQueryWizardPage;
  OwnLoader: Boolean;

function InstallLoader: Boolean;
begin
  Result := OwnLoader;
end;

procedure VerifyInstalledPatch;
begin
  if not SameText(GetSHA256OfFile(ExpandConstant('{app}\BepInEx\plugins\KromaRec.Patch.dll')), '{#PatchSHA256}') then
    RaiseException('The installed KromaRec patch failed its SHA-256 check.');
end;

procedure InitializeWizard;
begin
  BackendPage := CreateInputQueryPage(wpSelectDir, 'KromaRec backend',
    'Enter the HTTPS service origins.',
    'Setup preserves the existing KromaRec configuration during repair. Edit that file to change servers after installation.');
  BackendPage.Add('Discovery origin:', False);
  BackendPage.Add('Match origin:', False);
  PhotonPage := CreateInputQueryPage(BackendPage.ID, 'KromaRec Photon',
    'Enter the Luxon server details.', 'Use the values configured by your server operator.');
  PhotonPage.Add('Photon NameServer host:', False);
  PhotonPage.Add('Photon UDP port:', False);
  PhotonPage.Add('Photon region:', False);
  PhotonPage.Add('Photon Realtime UUID:', False);
  BackendPage.Values[0] := 'https://ns.rec.test';
  BackendPage.Values[1] := 'https://match.rec.test';
  PhotonPage.Values[0] := '127.0.0.1';
  PhotonPage.Values[1] := '5058';
  PhotonPage.Values[2] := 'us';
  PhotonPage.Values[3] := '7a6eafd9-8a49-47bd-98da-c743525a3e72';
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := ((PageID = BackendPage.ID) or (PageID = PhotonPage.ID)) and
    FileExists(ExpandConstant('{app}\BepInEx\config\net.kromarec.patch.cfg'));
end;

function ContainsOnly(const Value, Chars: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Value = '' then Exit;
  for I := 1 to Length(Value) do
    if Pos(Value[I], Chars) = 0 then Exit;
  Result := True;
end;

function IsPort(const Value: String): Boolean;
var
  Port: Integer;
begin
  Port := StrToIntDef(Value, 0);
  Result := ContainsOnly(Value, '0123456789') and (Port >= 1) and (Port <= 65535);
end;

function IsHost(const Value: String): Boolean;
var
  Rest, LabelPart: String;
  Dot: Integer;
begin
  Result := False;
  if (Length(Value) < 1) or (Length(Value) > 253) or (Value[Length(Value)] = '.') then Exit;
  Rest := Lowercase(Value);
  repeat
    Dot := Pos('.', Rest);
    if Dot = 0 then begin
      LabelPart := Rest;
      Rest := '';
    end else begin
      LabelPart := Copy(Rest, 1, Dot - 1);
      Delete(Rest, 1, Dot);
    end;
    if not ContainsOnly(LabelPart, 'abcdefghijklmnopqrstuvwxyz0123456789-') then Exit;
    if (Length(LabelPart) > 63) or (LabelPart[1] = '-') or (LabelPart[Length(LabelPart)] = '-') then Exit;
  until Dot = 0;
  Result := True;
end;

function IsHttpsOrigin(const Value: String): Boolean;
var
  Authority: String;
  Colon: Integer;
begin
  Result := False;
  if Pos('https://', Lowercase(Value)) <> 1 then Exit;
  Authority := Copy(Value, 9, Length(Value));
  if Authority = '' then Exit;
  if Authority[Length(Authority)] = '/' then SetLength(Authority, Length(Authority) - 1);
  Colon := Pos(':', Authority);
  if Colon > 0 then begin
    if not IsPort(Copy(Authority, Colon + 1, Length(Authority))) then Exit;
    SetLength(Authority, Colon - 1);
  end;
  Result := IsHost(Authority);
end;

function IsAppId(const Value: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (Length(Value) <> 36) or (Value = '00000000-0000-0000-0000-000000000000') then Exit;
  for I := 1 to Length(Value) do
    if (I = 9) or (I = 14) or (I = 19) or (I = 24) then begin
      if Value[I] <> '-' then Exit;
    end else if Pos(Value[I], '0123456789abcdef') = 0 then Exit;
  Result := True;
end;

function ServerError: String;
begin
  Result := '';
  if not IsHttpsOrigin(BackendPage.Values[0]) or not IsHttpsOrigin(BackendPage.Values[1]) then
    Result := 'Discovery and Match each require an HTTPS origin without a path, query or credentials.'
  else if not IsHost(PhotonPage.Values[0]) or not IsPort(PhotonPage.Values[1]) then
    Result := 'Enter a Photon DNS name or IPv4 address and a UDP port from 1 to 65535.'
  else if (Length(PhotonPage.Values[2]) < 2) or (Length(PhotonPage.Values[2]) > 16) or
          not ContainsOnly(PhotonPage.Values[2], 'abcdefghijklmnopqrstuvwxyz0123456789-') then
    Result := 'Enter a region with 2 to 16 lowercase letters, digits or hyphens.'
  else if not IsAppId(PhotonPage.Values[3]) then
    Result := 'Enter the nonzero lowercase Realtime UUID configured in KromaRec.';
end;

function VerifyGameFile(const RelativePath, Expected: String): String;
var
  Path: String;
begin
  Result := '';
  Path := AddBackslash(ExpandConstant('{app}')) + RelativePath;
  if not FileExists(Path) then
    Result := 'Missing 20230414 game file: ' + RelativePath
  else if not SameText(GetSHA1OfFile(Path), Expected) then
    Result := 'Wrong game build or damaged file: ' + RelativePath + '. Restore Steam depot 471711 manifest 6426603215211043630.';
end;

function VerifyGame: String;
begin
  Result := VerifyGameFile('RecRoom.exe', '{#RecRoomExeSHA1}');
  if Result = '' then Result := VerifyGameFile('GameAssembly.dll', '{#GameAssemblySHA1}');
  if Result = '' then Result := VerifyGameFile('UnityPlayer.dll', '{#UnityPlayerSHA1}');
  if Result = '' then Result := VerifyGameFile('RecRoom_Data\il2cpp_data\Metadata\global-metadata.dat', '{#GlobalMetadataSHA1}');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Problem: String;
begin
  Problem := '';
  if CurPageID = wpSelectDir then Problem := VerifyGame;
  if CurPageID = BackendPage.ID then begin
    if not IsHttpsOrigin(BackendPage.Values[0]) or not IsHttpsOrigin(BackendPage.Values[1]) then
      Problem := 'Enter two HTTPS origins without paths, queries or credentials.';
  end;
  if CurPageID = PhotonPage.ID then Problem := ServerError;
  Result := Problem = '';
  if not Result then SuppressibleMsgBox(Problem, mbError, MB_OK, IDOK);
end;

function VerifyExternalLoader: String;
var
  Lines: TArrayOfString;
  I: Integer;
  RelativePath, FilePath: String;
begin
  Result := 'Could not read the pinned BepInEx checksums.';
  ExtractTemporaryFile('loader.sha256');
  if not LoadStringsFromFile(ExpandConstant('{tmp}\loader.sha256'), Lines) then Exit;
  if GetArrayLength(Lines) = 0 then Exit;
  for I := 0 to GetArrayLength(Lines) - 1 do begin
    RelativePath := Copy(Lines[I], 66, Length(Lines[I]));
    FilePath := AddBackslash(ExpandConstant('{app}')) + RelativePath;
    Result := 'Existing loader differs from BepInEx 6.0.0-pre.2 IL2CPP: ' + RelativePath +
      '. Select a clean 20230414 copy or restore the pinned loader.';
    if not FileExists(FilePath) then Exit;
    if not SameText(GetSHA256OfFile(FilePath), Copy(Lines[I], 1, 64)) then Exit;
  end;
  Result := '';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  AppDir: String;
begin
  OwnLoader := False;
  Result := VerifyGame;
  if Result <> '' then Exit;
  AppDir := AddBackslash(ExpandConstant('{app}'));
  if FileExists(AppDir + 'BepInEx\plugins\RecNetPlugin.dll') or
     FileExists(AppDir + 'BepInEx\plugins\RecFlare.dll') then begin
    Result := 'A RecFlare plugin is installed. Move it out of BepInEx\plugins before continuing.';
    Exit;
  end;

  OwnLoader := FileExists(AppDir + 'BepInEx\kromarec-loader.owner');
  if not OwnLoader then begin
    if FileExists(AppDir + 'winhttp.dll') or FileExists(AppDir + 'doorstop_config.ini') or
       DirExists(AppDir + 'BepInEx\core') or DirExists(AppDir + 'dotnet') then
      Result := VerifyExternalLoader
    else
      OwnLoader := True;
    if Result <> '' then Exit;
  end;

  if not FileExists(AppDir + 'BepInEx\config\net.kromarec.patch.cfg') then
    Result := ServerError;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Cfg, ConfigDir, ConfigPath, Temporary: String;
begin
  if CurStep <> ssPostInstall then Exit;
  ConfigDir := ExpandConstant('{app}\BepInEx\config');
  ConfigPath := AddBackslash(ConfigDir) + 'net.kromarec.patch.cfg';
  if FileExists(ConfigPath) then Exit;
  Cfg := '[General]' + #13#10 + 'Enabled = true' + #13#10 + 'Debug = false' + #13#10#13#10 +
    '[Backend]' + #13#10 + 'BaseUrl = ' + BackendPage.Values[0] + #13#10 +
    'MatchUrl = ' + BackendPage.Values[1] + #13#10#13#10 +
    '[Photon]' + #13#10 + 'NameServerHost = ' + PhotonPage.Values[0] + #13#10 +
    'NameServerPort = ' + PhotonPage.Values[1] + #13#10 + 'Region = ' + PhotonPage.Values[2] + #13#10 +
    'RealtimeAppId = ' + PhotonPage.Values[3] + #13#10#13#10 +
    '[Analytics]' + #13#10 + 'DisableTelemetry = true' + #13#10;
  Temporary := ConfigPath + '.kromarec-setup.tmp';
  if not ForceDirectories(ConfigDir) or not SaveStringToFile(Temporary, Cfg, False) then
    RaiseException('Could not write the KromaRec configuration. Check the game directory permissions.');
  if not RenameFile(Temporary, ConfigPath) then begin
    DeleteFile(Temporary);
    if not FileExists(ConfigPath) then
      RaiseException('Could not finalize the KromaRec configuration.');
  end;
end;
