unit o_FindAnReplaceInFiles;

{$mode Delphi}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , Generics.Collections
  ;

type
  { forward declarations }
  TFindAndReplaceInFilesResult = class;
  TFileMatch = class;
  TTermMatch = class;

  { TFindAndReplaceInFilesOptions }
  TFindAndReplaceInFilesOptions = class
  private
    fFilters: string;
    fFolderPath: string;
    fMatchCase: Boolean;
    fReplaceFlag: Boolean;
    fReplaceWith: string;
    fReplaceWithU: UnicodeString;
    fTerm: string;
    fTermLenChars: Integer;
    fTermU: UnicodeString;
    fWholeWord: Boolean;
    procedure SetReplaceWith(AValue: string);
    procedure SetTerm(AValue: string);
  public
    property Term: string read fTerm write SetTerm;
    property ReplaceWith: string read fReplaceWith write SetReplaceWith;

    property MatchCase   : Boolean read fMatchCase   write fMatchCase  ;
    property WholeWord   : Boolean read fWholeWord   write fWholeWord  ;
    property ReplaceFlag : Boolean read fReplaceFlag write fReplaceFlag;

    property Filters     : string read fFilters    write fFilters   ;
    property FolderPath  : string read fFolderPath write fFolderPath;

    property TermU       : UnicodeString read fTermU;
    property ReplaceWithU: UnicodeString read fReplaceWithU;

    property TermLenChars: Integer read fTermLenChars;  //Length(TermU)
  end;


  { TFindAndReplaceInFilesResult }

  TFindAndReplaceInFilesResult = class
  private
    fFileMatchList: TObjectList<TFileMatch>;
    fOptions: TFindAndReplaceInFilesOptions;
  public
     constructor Create(AOptions: TFindAndReplaceInFilesOptions);
     destructor Destroy(); override;

     property Options: TFindAndReplaceInFilesOptions read fOptions;  // ref only
     property FileMatchList: TObjectList<TFileMatch> read fFileMatchList;
  end;

  { TFileMatch }

  TFileMatch = class
  private
    fFilePath: string;
    fOwner: TFindAndReplaceInFilesResult;
    fTermMatchList: TObjectList<TTermMatch>;
  public
     constructor Create(AOwner: TFindAndReplaceInFilesResult; const AFilePath: string);
     destructor Destroy(); override;

     property Owner: TFindAndReplaceInFilesResult read fOwner;       // ref only
     property FilePath: string read fFilePath;
     property TermMatchList: TObjectList<TTermMatch> read fTermMatchList;
  end;

  { TTermMatch }

  TTermMatch = class
  private
    fOwner: TFileMatch;
    fColumn: Integer;
    fLine: Integer;
    fLineText: string;
  public
    constructor Create(AOwner: TFileMatch; ALine, AColumn: Integer; const ALineText: string);
    destructor Destroy(); override;

    property Owner: TFileMatch read fOwner;       // ref only
    property Line: Integer read fLine;            // 0-based
    property Column: Integer read fColumn;        // 0-based
    property LineText: string read fLineText;
  end;

  { TFindAnReplaceInFiles }

  TFindAnReplaceInFiles = class(TComponent)
  private
    fFindResult: TFindAndReplaceInFilesResult;
    fOptions: TFindAndReplaceInFilesOptions;
    procedure FindAll();
    procedure ReplaceAll();
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure ShowDialog();

    property Options: TFindAndReplaceInFilesOptions read fOptions;
    property FindResult: TFindAndReplaceInFilesResult read fFindResult;
  end;


implementation

{ TFindAndReplaceInFilesOptions }

procedure TFindAndReplaceInFilesOptions.SetTerm(AValue: string);
begin
  if fTerm <> AValue then
  begin
    fTerm := AValue;
    fTermU := UTF8Decode(fTerm);
    fTermLenChars := Length(fTermU);
  end;
end;

procedure TFindAndReplaceInFilesOptions.SetReplaceWith(AValue: string);
begin
  if fReplaceWith <> AValue then
  begin
    fReplaceWith := AValue;
    fReplaceWithU := UTF8Decode(fReplaceWith);
  end;
end;

{ TFindAndReplaceInFilesResult }

constructor TFindAndReplaceInFilesResult.Create(AOptions: TFindAndReplaceInFilesOptions);
begin
  inherited Create();
  fOptions := AOptions;
  fFileMatchList := TObjectList<TFileMatch>.Create(True);
end;

destructor TFindAndReplaceInFilesResult.Destroy();
begin
  fFileMatchList.Free();
  inherited Destroy();
end;

{ TFileMatch }

constructor TFileMatch.Create(AOwner: TFindAndReplaceInFilesResult; const AFilePath: string);
begin
  inherited Create();
  fOwner := AOwner;
  fFilePath := AFilePath;
  fTermMatchList := TObjectList<TTermMatch>.Create(True);
end;

destructor TFileMatch.Destroy();
begin
  fTermMatchList.Free();
  inherited Destroy();
end;

{ TTermMatch }

constructor TTermMatch.Create(AOwner: TFileMatch; ALine, AColumn: Integer; const ALineText: string);
begin
  inherited Create();
  fOwner := AOwner;
  fLine := ALine;
  fColumn := AColumn;
  fLineText := ALineText;
end;

destructor TTermMatch.Destroy();
begin
  inherited Destroy();
end;

{ TFindAnReplaceInFiles }



constructor TFindAnReplaceInFiles.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fOptions := TFindAndReplaceInFilesOptions.Create;
  fFindResult := TFindAndReplaceInFilesResult.Create(fOptions);
end;

destructor TFindAnReplaceInFiles.Destroy();
begin
  FreeAndNil(fFindResult);
  FreeAndNil(fOptions);
  inherited Destroy();
end;

procedure TFindAnReplaceInFiles.ShowDialog();
begin
  fFindResult.FileMatchList.Clear();

  // ΕΔΩ: δείχνουμε το dialog, δεν έχει γίνει ακόμα.

  if Term = '' then
    Exit;

  if FolderPath = '' then
    Exit;

  if not DirectoryExists(FolderPath) then
    Exit;

  if Filters = '' then
    Exit;

  FindAll();

  if ReplaceFlag then
    ReplaceAll();

  property Term: string read fTerm write SetTerm;
  property ReplaceWith: string read fReplaceWith write SetReplaceWith;

  property MatchCase   : Boolean read fMatchCase   write fMatchCase  ;
  property WholeWord   : Boolean read fWholeWord   write fWholeWord  ;
  property ReplaceFlag : Boolean read fReplaceFlag write fReplaceFlag;

  property Filters     : string read fFilters    write fFilters   ;
  property FolderPath  : string read fFolderPath write fFolderPath;
end;

procedure TFindAnReplaceInFiles.FindAll();
begin

end;

procedure TFindAnReplaceInFiles.ReplaceAll();
begin

end;

end.

