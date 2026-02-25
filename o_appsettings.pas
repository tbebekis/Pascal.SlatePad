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
    fGutterVisible: Boolean;
    fLastFilter: string;
    fLastFolderPath: string;
    fMinimapTooltipVisible: Boolean;
    fMinimapVisible: Boolean;
    fRulerVisible: Boolean;
    fShowCurLine: Boolean;
    fUseHighlighters: Boolean;

    function GetFilePath: string;
  public
    constructor Create;

    procedure Load;
    procedure Save;

    property FilePath: string read GetFilePath;
  published
    property AutoSave: Boolean read FAutoSave write FAutoSave;
    property AutoSaveSecondsInterval: Integer read FAutoSaveSecondsInterval write FAutoSaveSecondsInterval;

    property UseHighlighters: Boolean read fUseHighlighters write fUseHighlighters;

    property GutterVisible: Boolean read fGutterVisible write fGutterVisible;
    property RulerVisible: Boolean read fRulerVisible write fRulerVisible;
    property ShowCurLine: Boolean read fShowCurLine write fShowCurLine;
    property MinimapVisible: Boolean read fMinimapVisible write fMinimapVisible;
    property MinimapTooltipVisible: Boolean read fMinimapTooltipVisible write fMinimapTooltipVisible;

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

