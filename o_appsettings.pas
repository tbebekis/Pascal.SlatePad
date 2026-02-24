unit o_AppSettings;

{$mode DELPHI}{$H+}

interface

uses
  Classes, SysUtils;

type

  { TAppSettings }

  TAppSettings = class(TPersistent)
  private
    FAutoSave: Boolean;
    FAutoSaveSecondsInterval: Integer;
    fFontName: string;
    fFontSize: Integer;
    fLastFilter: string;
    fLastFolderPath: string;
    fWordWrap: Boolean;
    function GetFilePath: string;
  public
    constructor Create;

    procedure Load;
    procedure Save;

    property FilePath: string read GetFilePath;
  published
    property AutoSave: Boolean read FAutoSave write FAutoSave;
    property AutoSaveSecondsInterval: Integer read FAutoSaveSecondsInterval write FAutoSaveSecondsInterval;
    property WordWrap: Boolean read fWordWrap write fWordWrap;
    property FontName: string read fFontName write fFontName;
    property FontSize: Integer read fFontSize write fFontSize;

    property LastFilter: string read fLastFilter write fLastFilter;
    property LastFolderPath: string read fLastFolderPath write fLastFolderPath;
  end;

implementation

uses
  Tripous
  ;

{ TAppSettings }

constructor TAppSettings.Create;
begin
  inherited Create;

  AutoSave := True;
  AutoSaveSecondsInterval := 5;
  WordWrap := True;
end;

function TAppSettings.GetFilePath: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'AppSettings.json';
end;

procedure TAppSettings.Load;
begin
  if FileExists(FilePath) then
    Json.LoadFromFile(FilePath, Self);
end;

procedure TAppSettings.Save;
begin
  Json.SaveToFile(FilePath, Self);
end;

end.

