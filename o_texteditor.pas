unit o_TextEditor;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , StrUtils
  , LCLType
  , LazUTF8
  , Menus
  , ATSynEdit
  , o_FindAndReplace

  ;

(*
/home/teo/.lazarus/onlinepackagemanager/packages/BGRABitmap/bgrabitmap
/home/teo/Dev/Lazarus/Packages/EncConv-2024.12.15/encconv
/home/teo/Dev/Lazarus/Packages/ATFlatControls-2026.02.06/atflatcontrols
/home/teo/Dev/Lazarus/Packages/ATSynEdit-2026.02.21/atsynedit
*)

type
  TEdText = UnicodeString;

  TUtf8CharInfo = record
    ByteIndex0: Integer; // 0-based byte offset in string
    ByteLen: Integer;    // 1..4
    CodePoint: Cardinal;
  end;

  { TTextEditor }

  TTextEditor = class(TComponent, IFindAndReplaceHandler)
  private
    fEditor: TATSynEdit;
    function GetBorderVisible: Boolean;
    function GetCaretX: Integer;
    function GetCaretY: Integer;
    function GetEnabled: Boolean;
    function GetFont: TFont;
    function GetGutterVisible: Boolean;
    function GetMarginRight: Integer;
    function GetMinimapTooltipVisible: Boolean;
    function GetMinimapVisible: Boolean;
    function GetModified: Boolean;
    function GetOnChange: TNotifyEvent;
    function GetOnMouseDown: TMouseEvent;
    function GetParent: TWinControl;
    function GetPopupMenu: TPopupMenu;
    function GetReadOnly: Boolean;
    function GetRulerVisible: Boolean;
    function GetShowCurLine: Boolean;
    function GetText: TEdText;
    function GetVisible: Boolean;
    function GetWordWrap: Boolean;
    procedure SetBorderVisible(AValue: Boolean);
    procedure SetCaretX(AValue: Integer);
    procedure SetCaretY(AValue: Integer);
    procedure SetEnabled(AValue: Boolean);
    procedure SetGutterVisible(AValue: Boolean);
    procedure SetMarginRight(AValue: Integer);
    procedure SetMinimapTooltipVisible(AValue: Boolean);
    procedure SetMinimapVisible(AValue: Boolean);
    procedure SetModified(AValue: Boolean);
    procedure SetOnChange(AValue: TNotifyEvent);

    procedure SetOnMouseDown(AValue: TMouseEvent);
    procedure SetParent(AValue: TWinControl);
    procedure SetPopupMenu(AValue: TPopupMenu);
    procedure SetReadOnly(AValue: Boolean);
    procedure SetRulerVisible(AValue: Boolean);

    procedure SetShowCurLine(AValue: Boolean);

    procedure SetText(AValue: TEdText);

    procedure SetVisible(AValue: Boolean);
    procedure SetWordWrap(AValue: Boolean);
  private
    fFindAndReplace: TFindAndReplace;

    fOnKeyDown: TKeyEvent;

    function GetEditorText: string;
    function GetOnCaretChanged: TNotifyEvent;
    function GetOnModifiedChanged: TNotifyEvent;
    procedure SetEditorText(AValue: string);
    procedure SetOnCaretChanged(AValue: TNotifyEvent);
    procedure SetOnModifiedChanged(AValue: TNotifyEvent);

    procedure Editor_OnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    class function Utf8NextChar(const S: string; var ByteIndex0: Integer; out Info: TUtf8CharInfo): Boolean; static;
    class function IsWordCodePoint(CP: Cardinal): Boolean; static;
    class function Utf8CharCount(const S: string): Integer; static;
    class function Utf8CharIndex0ToByteIndex0(const S: string; CharIndex0: Integer): Integer; static;
    class function Utf8CopyChars(const S: string; StartChar0, LenChars: Integer): string; static;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure SetFocus();

    class function IsWordChar(const Ch: WideChar): Boolean;
    function GetWordAtCaret(out Word: TEdText; out WordStartXChar0, WordLenChars: Integer): Boolean; overload;
    function GetWordAtCaret(): TEdText;

    function FindNext(Backward: Boolean): Integer;
    function FindAndHighlightAll(): Integer;
    function ReplaceNext(Backward: Boolean): Integer;
    function ReplaceAll(): Integer;

    procedure HighlightAll();
    procedure ClearHighlights();

    procedure AppSettingsChanged();

    property Editor: TATSynEdit read fEditor;
    property FindAndReplace: TFindAndReplace read fFindAndReplace;

    property Parent: TWinControl read GetParent write SetParent;
    property Font: TFont read GetFont;
    property WordWrap: Boolean read GetWordWrap write SetWordWrap;

    property Visible: Boolean read GetVisible write SetVisible;
    property Enabled: Boolean read GetEnabled write SetEnabled;
    property ReadOnly: Boolean read GetReadOnly write SetReadOnly;
    property Modified: Boolean read GetModified write SetModified;
    property GutterVisible: Boolean read GetGutterVisible write SetGutterVisible;
    property RulerVisible: Boolean read GetRulerVisible write SetRulerVisible;
    property MarginRight: Integer read GetMarginRight write SetMarginRight;
    property ShowCurLine: Boolean read GetShowCurLine write SetShowCurLine;
    property MinimapVisible: Boolean read GetMinimapVisible write SetMinimapVisible;
    property MinimapTooltipVisible: Boolean read GetMinimapTooltipVisible write SetMinimapTooltipVisible;
    property BorderVisible: Boolean read GetBorderVisible write SetBorderVisible;
    property PopupMenu: TPopupMenu read GetPopupMenu write SetPopupMenu;

    property Text: TEdText read GetText write SetText;
    property EditorText: string read GetEditorText write SetEditorText ;

    property CaretX: Integer read GetCaretX write SetCaretX;
    property CaretY: Integer read GetCaretY write SetCaretY;

    property OnChange: TNotifyEvent read GetOnChange write SetOnChange;
    property OnKeyDown: TKeyEvent read fOnKeyDown write fOnKeyDown;
    property OnMouseDown: TMouseEvent read GetOnMouseDown write SetOnMouseDown;
    property OnModifiedChanged: TNotifyEvent read GetOnModifiedChanged write SetOnModifiedChanged;
    property OnCaretChanged: TNotifyEvent read GetOnCaretChanged  write SetOnCaretChanged;
  end;

(*
Editor.OptWrapMode := TATEditorWrapMode.ModeOn;
Editor.Font.Name:= 'Times New Roman';
Editor.Font.Size := 13;
*)

implementation

uses
  Math
  ,ATSynEdit_Carets
  ,o_App
  ;





procedure Exchange(var A, B: Integer); inline;
var
  T: Integer;
begin
  T := A; A := B; B := T;
end;

function NormU(const S: UnicodeString; MatchCase: Boolean): UnicodeString;
begin
  if MatchCase then
    Result := S
  else
    Result := LowerCase(S);
end;

function IsWordCharU(const Ch: WideChar): Boolean;
var
  U: Word;
begin
  U := Ord(Ch);

  if (Ch >= 'a') and (Ch <= 'z') then Exit(True);
  if (Ch >= 'A') and (Ch <= 'Z') then Exit(True);
  if (Ch >= '0') and (Ch <= '9') then Exit(True);
  if Ch = '_' then Exit(True);

  if (U >= $0370) and (U <= $03FF) then Exit(True); // Greek
  if (U >= $1F00) and (U <= $1FFF) then Exit(True); // Greek Extended
  if (U >= $00C0) and (U <= $024F) then Exit(True); // Latin accented

  Result := False;
end;

function IsWholeWordAt(const Line: UnicodeString; Start1, Len: Integer): Boolean;
var
  L, R: Integer;
begin
  // Start1 is 1-based
  Result := True;
  if Len <= 0 then Exit(False);

  L := Start1;
  R := Start1 + Len - 1;

  if (L > 1) and IsWordCharU(Line[L-1]) then Exit(False);
  if (R < Length(Line)) and IsWordCharU(Line[R+1]) then Exit(False);
end;

// βάλε αυτά κοντά στα άλλα helpers σου (implementation section)

function CaretHasSel(const Ed: TATSynEdit; out X1,Y1,X2,Y2: Integer): Boolean;
var
  C: TATCaretItem;
begin
  Result := False;
  X1 := 0; Y1 := 0; X2 := 0; Y2 := 0;
  if (Ed = nil) or (Ed.Carets.Count = 0) then Exit;

  C := Ed.Carets[0];

  // TATCaretItem έχει PosX/PosY σίγουρα (τα χρησιμοποιείς ήδη).
  // Στο ATSynEdit, το selection άκρο είναι EndX/EndY (αυτά περνάς στο Carets.Add).
  if (C.EndX < 0) or (C.EndY < 0) then Exit;

  X1 := C.PosX; Y1 := C.PosY;
  X2 := C.EndX; Y2 := C.EndY;

  // normalize
  if (Y2 < Y1) or ((Y2 = Y1) and (X2 < X1)) then
  begin
    Exchange(X1, X2);
    Exchange(Y1, Y2);
  end;

  Result := not ((X1 = X2) and (Y1 = Y2));
end;

function RPosExU(const Needle, Hay: UnicodeString; Start1: Integer): Integer;
var
  P, NextFrom: Integer;
begin
  // last occurrence with P <= Start1 (1-based)
  Result := 0;
  if (Needle = '') or (Hay = '') then Exit;
  if Start1 > Length(Hay) then Start1 := Length(Hay);
  if Start1 < 1 then Exit;

  NextFrom := 1;
  while True do
  begin
    P := PosEx(Needle, Hay, NextFrom);
    if (P <= 0) or (P > Start1) then Break;
    Result := P;
    NextFrom := P + 1;
  end;
end;

function ReplaceAllInSegmentU(const Segment, FindU, ReplU: UnicodeString;
  MatchCase, WholeWord: Boolean; out NewSeg: UnicodeString): Integer;
var
  HayN, NeedleN: UnicodeString;
  P, Start1, LFind: Integer;
begin
  Result := 0;
  NewSeg := Segment;

  if FindU = '' then Exit;
  LFind := Length(FindU);

  HayN := NormU(NewSeg, MatchCase);
  NeedleN := NormU(FindU, MatchCase);

  Start1 := 1;
  while True do
  begin
    P := PosEx(NeedleN, HayN, Start1);
    if P <= 0 then Break;

    if WholeWord and (not IsWholeWordAt(NewSeg, P, LFind)) then
    begin
      Start1 := P + 1;
      Continue;
    end;

    // apply replace
    NewSeg := Copy(NewSeg, 1, P-1) + ReplU + Copy(NewSeg, P+LFind, MaxInt);

    // refresh normalized hay (simple & safe)
    HayN := NormU(NewSeg, MatchCase);

    Inc(Result);
    Start1 := P + Length(ReplU);
    if Start1 < 1 then Start1 := 1;
  end;
end;

function Utf8CharIndex0ToByteIndex0(const S: string; CharIndex0: Integer): Integer;
var
  iChar: Integer;
  iByte: Integer; // 1-based index in Pascal strings
  b: Byte;
  step: Integer;
begin
  if CharIndex0 <= 0 then Exit(0);

  iChar := 0;
  iByte := 1;

  while (iByte <= Length(S)) and (iChar < CharIndex0) do
  begin
    b := Byte(S[iByte]);

    // Determine UTF-8 sequence length from the leading byte
    if (b and $80) = 0 then
      step := 1                           // 0xxxxxxx
    else if (b and $E0) = $C0 then
      step := 2                           // 110xxxxx
    else if (b and $F0) = $E0 then
      step := 3                           // 1110xxxx
    else if (b and $F8) = $F0 then
      step := 4                           // 11110xxx
    else
      step := 1;                          // invalid leading byte -> advance 1 (robust)

    Inc(iByte, step);
    Inc(iChar);
  end;

  // return 0-based byte offset (clamped)
  Result := iByte - 1;
  if Result < 0 then Result := 0;
  if Result > Length(S) then Result := Length(S);
end;






procedure SelectRangeXY(fEditor: TATSynEdit; X1, Y1, X2, Y2: Integer; HasSel: Boolean);
begin
  fEditor.Carets.Clear;

  if HasSel then
    fEditor.Carets.Add(X1, Y1, X2, Y2, True)
  else
    fEditor.Carets.Add(X1, Y1, -1, -1, True);

  fEditor.Carets.Sort(True);
  fEditor.Carets.DoChanged;
end;



{ TTextEditor }

class function TTextEditor.Utf8NextChar(const S: string; var ByteIndex0: Integer; out Info: TUtf8CharInfo): Boolean; static;
var
  L: Integer;
  B1, B2, B3, B4: Byte;
begin
  L := Length(S);
  if (ByteIndex0 < 0) then ByteIndex0 := 0;
  if (ByteIndex0 >= L) then Exit(False);

  Info.ByteIndex0 := ByteIndex0;

  B1 := Byte(S[ByteIndex0 + 1]);
  if (B1 and $80) = 0 then
  begin
    Info.ByteLen := 1;
    Info.CodePoint := B1;
  end
  else if (B1 and $E0) = $C0 then
  begin
    if ByteIndex0 + 2 > L then Exit(False);
    B2 := Byte(S[ByteIndex0 + 2]);
    Info.ByteLen := 2;
    Info.CodePoint := Cardinal(B1 and $1F) shl 6 or Cardinal(B2 and $3F);
  end
  else if (B1 and $F0) = $E0 then
  begin
    if ByteIndex0 + 3 > L then Exit(False);
    B2 := Byte(S[ByteIndex0 + 2]);
    B3 := Byte(S[ByteIndex0 + 3]);
    Info.ByteLen := 3;
    Info.CodePoint := Cardinal(B1 and $0F) shl 12 or
                      Cardinal(B2 and $3F) shl 6 or
                      Cardinal(B3 and $3F);
  end
  else if (B1 and $F8) = $F0 then
  begin
    if ByteIndex0 + 4 > L then Exit(False);
    B2 := Byte(S[ByteIndex0 + 2]);
    B3 := Byte(S[ByteIndex0 + 3]);
    B4 := Byte(S[ByteIndex0 + 4]);
    Info.ByteLen := 4;
    Info.CodePoint := Cardinal(B1 and $07) shl 18 or
                      Cardinal(B2 and $3F) shl 12 or
                      Cardinal(B3 and $3F) shl 6 or
                      Cardinal(B4 and $3F);
  end
  else
  begin
    // invalid lead byte, treat as single byte
    Info.ByteLen := 1;
    Info.CodePoint := B1;
  end;

  Inc(ByteIndex0, Info.ByteLen);
  Result := True;
end;

class function TTextEditor.IsWordCodePoint(CP: Cardinal): Boolean; static;
begin
  // ASCII letters/digits/underscore
  if (CP >= Ord('a')) and (CP <= Ord('z')) then Exit(True);
  if (CP >= Ord('A')) and (CP <= Ord('Z')) then Exit(True);
  if (CP >= Ord('0')) and (CP <= Ord('9')) then Exit(True);
  if CP = Ord('_') then Exit(True);

  // Greek (basic + extended)
  if (CP >= $0370) and (CP <= $03FF) then Exit(True); // Greek and Coptic
  if (CP >= $1F00) and (CP <= $1FFF) then Exit(True); // Greek Extended

  // Latin-1 Supplement + Latin Extended-A/B (for accented)
  if (CP >= $00C0) and (CP <= $024F) then Exit(True);

  Result := False;
end;

class function TTextEditor.Utf8CharCount(const S: string): Integer; static;
var
  i: Integer;
  Info: TUtf8CharInfo;
begin
  Result := 0;
  i := 0;
  while Utf8NextChar(S, i, Info) do
    Inc(Result);
end;

class function TTextEditor.Utf8CharIndex0ToByteIndex0(const S: string; CharIndex0: Integer): Integer; static;
var
  i, c: Integer;
  Info: TUtf8CharInfo;
begin
  if CharIndex0 <= 0 then Exit(0);
  i := 0;
  c := 0;
  while (c < CharIndex0) and Utf8NextChar(S, i, Info) do
    Inc(c);
  Result := i;
end;

class function TTextEditor.Utf8CopyChars(const S: string; StartChar0, LenChars: Integer): string; static;
var
  B0, B1: Integer;
begin
  if LenChars <= 0 then Exit('');
  if StartChar0 < 0 then StartChar0 := 0;

  B0 := Utf8CharIndex0ToByteIndex0(S, StartChar0);
  B1 := Utf8CharIndex0ToByteIndex0(S, StartChar0 + LenChars);
  Result := Copy(S, B0 + 1, B1 - B0);
end;





{ TTextEditor }
constructor TTextEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fEditor := TATSynEdit.Create(Self);
  fEditor.OptUnprintedVisible := False;   // hide non-printable characters
  fEditor.OptRulerVisible:= False;
  fEditor.OptMarginRight := 100000;
  fEditor.OptShowCurLine := False;
  fEditor.OptGutterVisible := False;
  fEditor.OptBorderVisible := True;
  fEditor.OptMinimapVisible := False;
  fEditor.OptMinimapTooltipVisible := False;

  AppSettingsChanged();

  fEditor.OnKeyDown := Editor_OnKeyDown;



  fFindAndReplace := TFindAndReplace.Create(Self);
  fFindAndReplace.Handler := Self;
end;

destructor TTextEditor.Destroy();
begin
  FreeAndNil(fFindAndReplace);
  inherited Destroy();
end;

procedure TTextEditor.AppSettingsChanged();
begin
  fEditor.Font.Name := App.Settings.FontName;
  fEditor.Font.Size := App.Settings.FontSize;
end;

procedure TTextEditor.SetFocus();
begin
  if fEditor.CanFocus then
    fEditor.SetFocus;
end;

function TTextEditor.GetParent: TWinControl;
begin
  Result := fEditor.Parent;
end;

procedure TTextEditor.SetParent(AValue: TWinControl);
begin
  if fEditor.Parent <> AValue then
  begin
    fEditor.Parent := AValue;
    fEditor.Align := alClient;
  end;
end;

function TTextEditor.GetFont: TFont;
begin
  Result := fEditor.Font;
end;

function TTextEditor.GetGutterVisible: Boolean;
begin
  Result := fEditor.OptGutterVisible;
end;

procedure TTextEditor.SetGutterVisible(AValue: Boolean);
begin
  fEditor.OptGutterVisible := AValue;
end;

function TTextEditor.GetMarginRight: Integer;
begin
  Result := fEditor.OptMarginRight;
end;

procedure TTextEditor.SetMarginRight(AValue: Integer);
begin
  fEditor.OptMarginRight := AValue;
end;

function TTextEditor.GetMinimapVisible: Boolean;
begin
  Result := fEditor.OptMinimapVisible;
end;

procedure TTextEditor.SetMinimapVisible(AValue: Boolean);
begin
  fEditor.OptMinimapVisible := AValue;;
end;

function TTextEditor.GetMinimapTooltipVisible: Boolean;
begin
  Result := fEditor.OptMinimapTooltipVisible;
end;

procedure TTextEditor.SetMinimapTooltipVisible(AValue: Boolean);
begin
  fEditor.OptMinimapTooltipVisible := AValue;
end;

function TTextEditor.GetRulerVisible: Boolean;
begin
  Result := fEditor.OptRulerVisible
end;

procedure TTextEditor.SetRulerVisible(AValue: Boolean);
begin
  fEditor.OptRulerVisible := AValue;
end;



function TTextEditor.GetShowCurLine: Boolean;
begin
  Result := fEditor.OptShowCurLine
end;

procedure TTextEditor.SetShowCurLine(AValue: Boolean);
begin
  fEditor.OptShowCurLine := AValue;
end;

function TTextEditor.GetWordWrap: Boolean;
begin
  Result := fEditor.OptWrapMode = TATEditorWrapMode.ModeOn;
end;

procedure TTextEditor.SetWordWrap(AValue: Boolean);
begin
  if AValue then
    fEditor.OptWrapMode := TATEditorWrapMode.ModeOn
  else
    fEditor.OptWrapMode := TATEditorWrapMode.ModeOff;
end;

function TTextEditor.GetOnModifiedChanged: TNotifyEvent;
begin
  Result := fEditor.OnChangeModified;
end;

function TTextEditor.GetOnCaretChanged: TNotifyEvent;
begin
  Result := fEditor.Carets.OnCaretChanged;
end;

procedure TTextEditor.SetOnCaretChanged(AValue: TNotifyEvent);
begin
  fEditor.Carets.OnCaretChanged := AValue;
end;

procedure TTextEditor.SetOnModifiedChanged(AValue: TNotifyEvent);
begin
  fEditor.OnChangeModified := AValue;
end;

function TTextEditor.GetBorderVisible: Boolean;
begin
  Result := fEditor.OptBorderVisible;
end;

procedure TTextEditor.SetBorderVisible(AValue: Boolean);
begin
  fEditor.OptBorderVisible := AValue;
end;

function TTextEditor.GetVisible: Boolean;
begin
  Result := fEditor.Visible;
end;

procedure TTextEditor.SetVisible(AValue: Boolean);
begin
  fEditor.Visible := AValue;
end;

function TTextEditor.GetEnabled: Boolean;
begin
  Result := fEditor.Enabled;
end;

procedure TTextEditor.SetEnabled(AValue: Boolean);
begin
  fEditor.Enabled := AValue;
end;

function TTextEditor.GetPopupMenu: TPopupMenu;
begin
  Result := fEditor.PopupMenu;
end;

procedure TTextEditor.SetPopupMenu(AValue: TPopupMenu);
begin
  fEditor.PopupMenu := AValue;
end;

function TTextEditor.GetText: TEdText;
begin
  Result := fEditor.Text;
end;

procedure TTextEditor.SetText(AValue: TEdText);
begin
  fEditor.Text := AValue;
end;

function TTextEditor.GetEditorText: string;
begin
  Result := UTF8Encode(fEditor.Text);
end;

procedure TTextEditor.SetEditorText(AValue: string);
begin
  fEditor.Text := UTF8Decode(AValue);
end;

function TTextEditor.GetModified: Boolean;
begin
  Result := fEditor.Modified;
end;

procedure TTextEditor.SetModified(AValue: Boolean);
begin
  fEditor.Modified := AValue;
end;

function TTextEditor.GetReadOnly: Boolean;
begin
  Result := fEditor.ModeReadOnly;
end;

procedure TTextEditor.SetReadOnly(AValue: Boolean);
begin
  fEditor.ModeReadOnly := AValue;
end;

function TTextEditor.GetOnChange: TNotifyEvent;
begin
  Result := fEditor.OnChange;
end;

procedure TTextEditor.SetOnChange(AValue: TNotifyEvent);
begin
  fEditor.OnChange := AValue;
end;

function TTextEditor.GetOnMouseDown: TMouseEvent;
begin
  Result := fEditor.OnMouseDown;
end;

procedure TTextEditor.SetOnMouseDown(AValue: TMouseEvent);
begin
  fEditor.OnMouseDown := AValue;
end;

function TTextEditor.GetCaretX: Integer;
begin
  Result := fEditor.Carets[0].PosX;
end;

procedure TTextEditor.SetCaretX(AValue: Integer);
begin
  fEditor.Carets[0].PosX := AValue;
  fEditor.Update;
end;

function TTextEditor.GetCaretY: Integer;
begin
  Result := fEditor.Carets[0].PosY;
end;

procedure TTextEditor.SetCaretY(AValue: Integer);
begin
  fEditor.Carets[0].PosY := AValue;
  fEditor.Update;
end;

class function TTextEditor.IsWordChar(const Ch: WideChar): Boolean;
var
  U: Word;
begin
  U := Ord(Ch);

  // ASCII
  if (Ch >= 'a') and (Ch <= 'z') then Exit(True);
  if (Ch >= 'A') and (Ch <= 'Z') then Exit(True);
  if (Ch >= '0') and (Ch <= '9') then Exit(True);
  if Ch = '_' then Exit(True);

  // Greek (basic + extended)
  if (U >= $0370) and (U <= $03FF) then Exit(True);
  if (U >= $1F00) and (U <= $1FFF) then Exit(True);

  // Latin accented ranges (good enough for European text)
  if (U >= $00C0) and (U <= $024F) then Exit(True);

  Result := False;
end;

function TTextEditor.GetWordAtCaret(out Word: TEdText; out WordStartXChar0, WordLenChars: Integer): Boolean;
var
  Y0, X0: Integer;
  Line: TEdText;
  LenU: Integer;
  I, L, R: Integer;

  function Clamp(V, AMin, AMax: Integer): Integer;
  begin
    if V < AMin then Exit(AMin);
    if V > AMax then Exit(AMax);
    Result := V;
  end;

begin
  Word := '';
  WordStartXChar0 := 0;
  WordLenChars := 0;
  Result := False;

  Y0 := fEditor.Carets[0].PosY;
  X0 := fEditor.Carets[0].PosX;

  if (Y0 < 0) or (Y0 >= fEditor.Strings.Count) then Exit;

  Line := fEditor.Strings.Lines[Y0]; // ✅ no warning (UnicodeString -> UnicodeString)
  LenU := Length(Line);
  if LenU = 0 then Exit;

  // clamp X0 to [0..LenU]
  X0 := Clamp(X0, 0, LenU);

  // if caret at end of line, look left
  I := X0;
  if (I = LenU) then Dec(I);
  if (I < 0) or (I >= LenU) then Exit;

  // In Pascal strings are 1-based. Convert:
  Inc(I); // now 1-based index into Line

  if not IsWordChar(Line[I]) then Exit(False);

  L := I;
  while (L > 1) and IsWordChar(Line[L-1]) do Dec(L);

  R := I;
  while (R < LenU) and IsWordChar(Line[R+1]) do Inc(R);

  WordStartXChar0 := L - 1;            // back to 0-based
  WordLenChars := R - L + 1;
  Word := Copy(Line, L, WordLenChars);
  Result := WordLenChars > 0;
end;

function TTextEditor.GetWordAtCaret(): TEdText;
var
  WU: TEdText;
  SX, SL: Integer;
begin
  if GetWordAtCaret(WU, SX, SL) then
    Result := WU
  else
    Result := '';
end;

procedure TTextEditor.Editor_OnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Term: UnicodeString;
begin
  if (Shift = [ssCtrl]) and (Key = VK_F) then
  begin
    Key := 0;
    Term := GetWordAtCaret();
    FindAndReplace.ShowDialog(Term);
    Exit;
  end else if (Shift = [ssCtrl]) and (Key = VK_S) then
  begin
    //Key := 0;
    //Save();
  end else if Key = VK_ESCAPE then
  begin
    ClearHighlights();
  end
  else if Key = VK_F3 then
  begin
    if Shift = [ssShift] then
       FindNext(True)
    else
       FindNext(False);
    Exit;
  end;

  if Assigned(OnKeyDown) then
    OnKeyDown(Self, Key, Shift);
end;

function TTextEditor.FindNext(Backward: Boolean): Integer;
var
  FindU, NeedleN: UnicodeString;
  Opt: TFindAndReplaceOptions;
  SelX1, SelY1, SelX2, SelY2: Integer;
  HasSel: Boolean;

  procedure SelectHit(ALine, P1, Len: Integer);
  var
    X1, X2: Integer;
  begin
    X1 := P1 - 1;          // 0-based
    X2 := X1 + Len;
    SelectRangeXY(fEditor, X1, ALine, X2, ALine, True);
    fEditor.Update;
  end;

  function FindForward: Boolean;
  var
    iy, y0, y1, y2, startX0: Integer;
    Line, HayN: UnicodeString;
    P, Start1, LFind: Integer;
  begin
    Result := False;
    LFind := Length(FindU);

    y1 := 0;
    y2 := fEditor.Strings.Count - 1;

    startX0 := fEditor.Carets[0].PosX;
    y0 := fEditor.Carets[0].PosY;

    if HasSel then
    begin
      // forward: continue after current match
      if (y0 = SelY2) then
        startX0 := Max(startX0, SelX2);
    end;

    if Opt.SelectionOnly then
    begin
      if not HasSel then Exit(False);
      y1 := SelY1; y2 := SelY2;

      if y0 < y1 then y0 := y1;
      if y0 > y2 then y0 := y1;

      if y0 = SelY1 then
        startX0 := Max(startX0, SelX1)
      else if y0 < SelY1 then
        startX0 := SelX1;

      // skip current selection (single line selection case)
      if (fEditor.Carets[0].PosY = SelY1) and (SelY1 = SelY2) then
        startX0 := Max(startX0, SelX2);
    end;

    for iy := y0 to y2 do
    begin
      Line := fEditor.Strings.Lines[iy];
      HayN := NormU(Line, Opt.MatchCase);

      if iy = y0 then
        Start1 := startX0 + 1
      else
        Start1 := 1;

      while True do
      begin
        P := PosEx(NeedleN, HayN, Start1);
        if P <= 0 then Break;

        if Opt.WholeWord and (not IsWholeWordAt(Line, P, LFind)) then
        begin
          Start1 := P + 1;
          Continue;
        end;

        if Opt.SelectionOnly then
        begin
          if (iy = SelY1) and ((P-1) < SelX1) then
          begin
            Start1 := P + 1;
            Continue;
          end;
          if (iy = SelY2) and ((P-1 + LFind) > SelX2) then
            Break;
        end;

        SelectHit(iy, P, LFind);
        Exit(True);
      end;
    end;
  end;

  function FindBackwardLocal: Boolean;
  var
    iy, y0, y1, y2, startX0: Integer;
    Line, HayN: UnicodeString;
    P, Start1, LFind: Integer;
  begin
    Result := False;
    LFind := Length(FindU);

    y1 := 0;
    y2 := fEditor.Strings.Count - 1;

    startX0 := fEditor.Carets[0].PosX;
    y0 := fEditor.Carets[0].PosY;

    if HasSel then
    begin
      // backward: continue before current match
      if (y0 = SelY1) then
        startX0 := Min(startX0, SelX1);
    end;

    if Opt.SelectionOnly then
    begin
      if not HasSel then Exit(False);
      y1 := SelY1; y2 := SelY2;

      if y0 < y1 then y0 := y2;
      if y0 > y2 then y0 := y2;

      if y0 = SelY2 then
        startX0 := Min(startX0, SelX2)
      else if y0 > SelY2 then
        startX0 := SelX2;

      // skip current selection (single line selection case)
      if (fEditor.Carets[0].PosY = SelY1) and (SelY1 = SelY2) then
        startX0 := Min(startX0, SelX1);
    end;

    for iy := y0 downto y1 do
    begin
      Line := fEditor.Strings.Lines[iy];
      HayN := NormU(Line, Opt.MatchCase);

      if iy = y0 then
        Start1 := startX0
      else
        Start1 := Length(Line);

      while True do
      begin
        P := RPosExU(NeedleN, HayN, Start1);
        if P <= 0 then Break;

        if Opt.WholeWord and (not IsWholeWordAt(Line, P, LFind)) then
        begin
          Start1 := P - 1;
          Continue;
        end;

        if Opt.SelectionOnly then
        begin
          if (iy = SelY1) and ((P-1) < SelX1) then Break;
          if (iy = SelY2) and ((P-1 + LFind) > SelX2) then
          begin
            Start1 := P - 1;
            Continue;
          end;
        end;

        SelectHit(iy, P, LFind);
        Exit(True);
      end;
    end;
  end;

begin
  Result := 0;
  if fEditor = nil then Exit;

  Opt := fFindAndReplace.Options;
  FindU := Opt.TextToFindU;
  if FindU = '' then Exit;

  HasSel := CaretHasSel(fEditor, SelX1, SelY1, SelX2, SelY2);
  if Opt.SelectionOnly and (not HasSel) then Exit(0);

  NeedleN := NormU(FindU, Opt.MatchCase);

  if Backward then
  begin
    if FindBackwardLocal() then Result := 1;
  end
  else
  begin
    if FindForward() then Result := 1;
  end;
end;

function TTextEditor.FindAndHighlightAll(): Integer;
begin
  Result := FindNext(False);
  HighlightAll();
end;

function TTextEditor.ReplaceNext(Backward: Boolean): Integer;
var
  Opt: TFindAndReplaceOptions;
  FindU, ReplU, Line: UnicodeString;
  X1,Y1,X2,Y2: Integer;
  HasSel: Boolean;
  Start1, LFind: Integer;
begin
  Result := 0;
  if fEditor = nil then Exit;

  Opt := fFindAndReplace.Options;
  FindU := Opt.TextToFindU;
  ReplU := Opt.ReplaceWithU;
  if FindU = '' then Exit;

  // 1) Find next
  if FindNext(Backward) <= 0 then Exit(0);

  // 2) Replace current selection (expected single-line match)
  HasSel := CaretHasSel(fEditor, X1,Y1,X2,Y2);
  if (not HasSel) or (Y1 <> Y2) then Exit(0);

  Line := fEditor.Strings.Lines[Y1];
  LFind := X2 - X1;
  if LFind <= 0 then Exit(0);

  Start1 := X1 + 1; // 1-based
  Line := Copy(Line, 1, Start1-1) + ReplU + Copy(Line, Start1 + LFind, MaxInt);
  fEditor.Strings.Lines[Y1] := Line;

  // select replaced text
  SelectRangeXY(fEditor, X1, Y1, X1 + Length(ReplU), Y1, True);
  fEditor.Update;

  Result := 1;
end;

function TTextEditor.ReplaceAll(): Integer;
var
  Opt: TFindAndReplaceOptions;
  FindU, ReplU: UnicodeString;
  SelX1, SelY1, SelX2, SelY2: Integer;
  HasSel: Boolean;
  y: Integer;
  Line, Prefix, Seg, Suffix, NewSeg: UnicodeString;
  Cnt: Integer;
begin
  Result := 0;
  if fEditor = nil then Exit;

  Opt := fFindAndReplace.Options;
  FindU := Opt.TextToFindU;
  ReplU := Opt.ReplaceWithU;
  if FindU = '' then Exit;

  HasSel := CaretHasSel(fEditor, SelX1, SelY1, SelX2, SelY2);
  if Opt.SelectionOnly and (not HasSel) then Exit(0);

  if not Opt.SelectionOnly then
  begin
    for y := 0 to fEditor.Strings.Count - 1 do
    begin
      Line := fEditor.Strings.Lines[y];
      Cnt := ReplaceAllInSegmentU(Line, FindU, ReplU, Opt.MatchCase, Opt.WholeWord, NewSeg);
      if Cnt > 0 then
      begin
        fEditor.Strings.Lines[y] := NewSeg;
        Inc(Result, Cnt);
      end;
    end;
    Exit;
  end;

  // SelectionOnly: replace only inside selected text (per-line segments)
  for y := SelY1 to SelY2 do
  begin
    Line := fEditor.Strings.Lines[y];

    if (y = SelY1) and (y = SelY2) then
    begin
      Prefix := Copy(Line, 1, SelX1);
      Seg    := Copy(Line, SelX1+1, SelX2 - SelX1);
      Suffix := Copy(Line, SelX2+1, MaxInt);
    end
    else if y = SelY1 then
    begin
      Prefix := Copy(Line, 1, SelX1);
      Seg    := Copy(Line, SelX1+1, MaxInt);
      Suffix := '';
    end
    else if y = SelY2 then
    begin
      Prefix := '';
      Seg    := Copy(Line, 1, SelX2);
      Suffix := Copy(Line, SelX2+1, MaxInt);
    end
    else
    begin
      Prefix := '';
      Seg    := Line;
      Suffix := '';
    end;

    Cnt := ReplaceAllInSegmentU(Seg, FindU, ReplU, Opt.MatchCase, Opt.WholeWord, NewSeg);
    if Cnt > 0 then
    begin
      fEditor.Strings.Lines[y] := Prefix + NewSeg + Suffix;
      Inc(Result, Cnt);
    end;
  end;

  fEditor.Update;
end;

procedure TTextEditor.ClearHighlights();
var
  X, Y: Integer;
begin
  if fEditor = nil then Exit;
  X := fEditor.Carets[0].PosX;
  Y := fEditor.Carets[0].PosY;
  SelectRangeXY(fEditor, X, Y, -1, -1, False); // keep caret, no selection
  fEditor.Update;
end;


procedure TTextEditor.HighlightAll();
var
  Opt: TFindAndReplaceOptions;
  FindU, NeedleN: UnicodeString;
  SelX1, SelY1, SelX2, SelY2: Integer;
  HasSel: Boolean;
  y, Start1, P, LFind: Integer;
  Line, HayN: UnicodeString;
  CaretX, CaretY: Integer;
  Added: Integer;
begin
  if fEditor = nil then Exit;

  Opt := fFindAndReplace.Options;
  FindU := Opt.TextToFindU;
  if FindU = '' then begin ClearHighlights; Exit; end;

  HasSel := CaretHasSel(fEditor, SelX1, SelY1, SelX2, SelY2);
  if Opt.SelectionOnly and (not HasSel) then Exit;

  NeedleN := NormU(FindU, Opt.MatchCase);
  LFind := Length(FindU);

  // keep main caret
  CaretX := fEditor.Carets[0].PosX;
  CaretY := fEditor.Carets[0].PosY;

  fEditor.Carets.Clear;
  fEditor.Carets.Add(CaretX, CaretY, -1, -1, True);

  Added := 0;

  for y := 0 to fEditor.Strings.Count - 1 do
  begin
    if Opt.SelectionOnly and ((y < SelY1) or (y > SelY2)) then Continue;

    Line := fEditor.Strings.Lines[y];
    HayN := NormU(Line, Opt.MatchCase);

    Start1 := 1;
    while True do
    begin
      P := PosEx(NeedleN, HayN, Start1);
      if P <= 0 then Break;

      if Opt.WholeWord and (not IsWholeWordAt(Line, P, LFind)) then
      begin
        Start1 := P + 1;
        Continue;
      end;

      if Opt.SelectionOnly then
      begin
        if (y = SelY1) and ((P-1) < SelX1) then
        begin
          Start1 := P + 1;
          Continue;
        end;
        if (y = SelY2) and ((P-1 + LFind) > SelX2) then
          Break;
      end;

      fEditor.Carets.Add(P-1, y, (P-1)+LFind, y, True);
      Inc(Added);
      if Added > 2000 then Break; // safety cap
      Start1 := P + 1;
    end;

    if Added > 2000 then Break;
  end;

  fEditor.Carets.Sort(True);
  fEditor.Carets.DoChanged;
  fEditor.Update;
end;


end.

