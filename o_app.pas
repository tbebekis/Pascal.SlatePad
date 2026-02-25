unit o_App;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Controls
  , Dialogs
  , Graphics
  , StdCtrls
  , System.UITypes
  , o_PageHandler
  , o_AppSettings
  , o_Docs
  ;

type

  { App }

  App = class
  private
    class var fPageHandler: TPagerHandler;
    class var fDocs: TDocuments;
    class var fSettings: TAppSettings;
  public
    // ● construction
    class constructor Create();
    class destructor Destroy();

    // ● message boxes
    class procedure ErrorBox(const Message: string);
    class procedure WarningBox(const Message: string);
    class procedure InfoBox(const Message: string);
    class function QuestionBox(const Message: string): Boolean;

    class function GetExeFolderPath: string;
    class function GetBufferFolderPath: string;

    // ● UI
    class procedure DisplayFileExplorer(const FileOrFolderPath: string);
    class function ShowFolderDialog(var FolderPath: string): Boolean;

    class function  GetEditBoxIntValue(Box: TEdit; DefaultValue: Integer): Integer;
    class procedure ClosePage(const PageId: string);

    // ● properties
    class property Settings: TAppSettings read fSettings;
    class property Docs: TDocuments read fDocs;
    class property PageHandler : TPagerHandler read fPageHandler write fPageHandler;
  end;




implementation

uses
   process
  ,Tripous
  ;

{ App }

class constructor App.Create;
begin
  fSettings := TAppSettings.Create();
  fSettings.Load();
  fDocs := TDocuments.Create();
  fDocs.Load();
end;

class destructor App.Destroy;
begin
  FreeAndNil(fDocs);
  FreeAndNil(fSettings);
end;

class function App.GetExeFolderPath: string;
begin
  Result := ExtractFilePath(ParamStr(0));
  Result := IncludeTrailingPathDelimiter(Result);
end;

class function App.GetBufferFolderPath: string;
begin
  Result := Sys.CombinePath(GetExeFolderPath, 'Buffer');
  if not Sys.FolderExists(Result) then
    Sys.CreateFolders(Result);
end;

/// <summary>
/// Shows an error message box
/// </summary>
class procedure App.ErrorBox(const Message: string);
begin
  MessageDlg('Error', Message, mtError, [mbOK], 0);
end;

/// <summary>
/// Shows a warning message box
/// </summary>
class procedure App.WarningBox(const Message: string);
begin
  MessageDlg('Warning', Message, mtWarning, [mbOK], 0);
end;

/// <summary>
/// Shows an information message box
/// </summary>
class procedure App.InfoBox(const Message: string);
begin
  MessageDlg('Information', Message, mtInformation, [mbOK], 0);
end;

/// <summary>
/// Shows a Yes/No question message box
/// </summary>
class function App.QuestionBox(const Message: string): Boolean;
begin
  Result :=
    MessageDlg(
      'Question',
      Message,
      mtConfirmation,
      [mbYes, mbNo],
      0
    ) = mrYes;
end;


class procedure App.DisplayFileExplorer(const FileOrFolderPath: string);
var
  P: TProcess;
  Path: string;
begin
  if not FileExists(FileOrFolderPath) and not DirectoryExists(FileOrFolderPath) then
    Exit;

  Path := ExpandFileName(FileOrFolderPath);

  P := TProcess.Create(nil);
  try
    {$IFDEF WINDOWS}
    P.Executable := 'explorer.exe';
    P.Parameters.Add('/select,');
    P.Parameters.Add(Path);
    {$ENDIF}

    {$IFDEF LINUX}
    // αν είναι φάκελος -> άνοιξε τον
    // αν είναι αρχείο -> άνοιξε τον φάκελο που τον περιέχει
    if FileExists(Path) then
      Path := ExtractFileDir(Path);

    P.Executable := 'xdg-open';
    P.Parameters.Add(Path);
    {$ENDIF}

    P.Options := [poNoConsole, poWaitOnExit];
    P.Execute;
  finally
    P.Free;
  end;
end;

class function App.ShowFolderDialog(var FolderPath: string): Boolean;
var
  D: TSelectDirectoryDialog;
begin
  Result := False;

  D := TSelectDirectoryDialog.Create(nil);
  try
    D.InitialDir := FolderPath;

    if D.Execute then
    begin
      if Trim(D.FileName) <> '' then
      begin
        FolderPath := D.FileName;
        Result := True;
      end;
    end;
  finally
    D.Free;
  end;

end;

class function App.GetEditBoxIntValue(Box: TEdit; DefaultValue: Integer): Integer;
var
  N: Integer;
begin
  Result := DefaultValue;
  if not TryStrToInt(Trim(Box.Text), N) then
    App.ErrorBox(Format('Cannot convert this value to integer: %s', [Box.Text]))
  else
    Result := N;
end;

class procedure App.ClosePage(const PageId: string);
begin
  PageHandler.ClosePage(PageId);
end;


end.

