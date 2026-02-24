unit o_FindAndReplace;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  ;

type
  {$interfaces corba}
  IFindAndReplaceHandler = interface
    function FindAndHighlightAll(): Integer;
    function FindNext(Backward: Boolean): Integer;
    function ReplaceNext(Backward: Boolean): Integer;
    function ReplaceAll(): Integer;

    procedure HighlightAll();
    procedure ClearHighlights();
  end;

  { TFindAndReplaceOptions }
  TFindAndReplaceOptions = class
  private
    function GetReplaceWithU: UnicodeString;
    function GetTextToFindU: UnicodeString;
    procedure SetReplaceWithU(AValue: UnicodeString);
    procedure SetTextToFindU(AValue: UnicodeString);
  public
    // ● options
    TextToFind: string;
    ReplaceWith: string;

    MatchCase: Boolean;
    WholeWord: Boolean;
    SelectionOnly: Boolean;

    ReplaceFlag: Boolean;
    ReplaceAllFlag: Boolean;

    procedure Clear();

    property TextToFindU: UnicodeString read GetTextToFindU write SetTextToFindU;
    property ReplaceWithU: UnicodeString read GetReplaceWithU write SetReplaceWithU;
  end;

  TFindAndReplace = class(TComponent)
  private
    fFoundCount: Integer;
    fOptions: TFindAndReplaceOptions;
    fHandler: IFindAndReplaceHandler;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    function ShowDialog(const Term: string): Boolean; overload;
    function ShowDialog(const Term: UnicodeString): Boolean; overload;

    property Handler: IFindAndReplaceHandler read fHandler write fHandler;
    property Options: TFindAndReplaceOptions read fOptions write fOptions;
    property FoundCount: Integer read fFoundCount;
  end;

implementation

uses
  f_FindAndReplaceDialog
  ;

{ TFindAndReplaceOptions }

function TFindAndReplaceOptions.GetTextToFindU: UnicodeString;
begin
  Result := UTF8Decode(TextToFind);
end;

procedure TFindAndReplaceOptions.SetTextToFindU(AValue: UnicodeString);
begin
  TextToFind := UTF8Encode(AValue);
end;

procedure TFindAndReplaceOptions.Clear();
begin
  TextToFind := '';
  ReplaceWith:= '';

  MatchCase := False;
  WholeWord := False;
  SelectionOnly:= False;

  ReplaceFlag:= False;
  ReplaceAllFlag:= False;
end;

function TFindAndReplaceOptions.GetReplaceWithU: UnicodeString;
begin
  Result := UTF8Decode(ReplaceWith);
end;

procedure TFindAndReplaceOptions.SetReplaceWithU(AValue: UnicodeString);
begin
  ReplaceWith := UTF8Encode(AValue);
end;


{ TFindAndReplace }
constructor TFindAndReplace.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fOptions := TFindAndReplaceOptions.Create();
end;

destructor TFindAndReplace.Destroy();
begin
  FreeAndNil(fOptions);
  inherited Destroy();
end;

function TFindAndReplace.ShowDialog(const Term: UnicodeString): Boolean;
begin
  Result := ShowDialog(UTF8Encode(Term));
end;

function TFindAndReplace.ShowDialog(const Term: string): Boolean;
begin
  Result := False;
  fFoundCount := -1;

  if not Assigned(Handler) then
    Exit;

  Handler.ClearHighlights();

  Options.TextToFind := Term;

  if not TFindAndReplaceDialog.ShowDialog(Options) then
    Exit;

  if Options.TextToFind = '' then
    fFoundCount := -1
  else if Options.ReplaceAllFlag then
    fFoundCount := Handler.ReplaceAll()
  else if Options.ReplaceFlag then
    fFoundCount := Handler.ReplaceNext(False)
  else begin
    fFoundCount := Handler.FindAndHighlightAll();
  end;

  Result := fFoundCount > 0;
end;



end.

