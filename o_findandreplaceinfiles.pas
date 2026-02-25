unit o_FindAndReplaceInFiles;

{$mode Delphi}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , StrUtils
  , Generics.Collections
  , ComCtrls
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
    fSearchInSubFolders: Boolean;
    fTerm: string;
    fTermLenChars: Integer;
    fTermU: UnicodeString;
    fWholeWord: Boolean;
    procedure SetReplaceWith(AValue: string);
    procedure SetTerm(AValue: string);
  public
    constructor Create();

    procedure Clear();

    property Term: string read fTerm write SetTerm;
    property ReplaceWith: string read fReplaceWith write SetReplaceWith;

    property MatchCase   : Boolean read fMatchCase   write fMatchCase  ;
    property WholeWord   : Boolean read fWholeWord   write fWholeWord  ;
    property ReplaceFlag : Boolean read fReplaceFlag write fReplaceFlag;

    property Filters     : string read fFilters    write fFilters   ;
    property FolderPath  : string read fFolderPath write fFolderPath;
    property SearchInSubFolders: Boolean read fSearchInSubFolders write fSearchInSubFolders;

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

  { TFindAndReplaceInFiles }

  TFindAndReplaceInFiles = class(TComponent)
  private
    fFindResult: TFindAndReplaceInFilesResult;
    fOptions: TFindAndReplaceInFilesOptions;
    procedure FindAll();
    procedure ReplaceAll();
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    function ShowDialog(): Integer;
    procedure LoadTo(tv: TTreeView);

    property Options: TFindAndReplaceInFilesOptions read fOptions;
    property FindResult: TFindAndReplaceInFilesResult read fFindResult;
  end;


implementation

uses
  o_App
  ,f_FindAndReplaceInFilesDialog
  ;

type
  TUnicodeLineList = TList<UnicodeString>;

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
  Result := False;
  if Len <= 0 then Exit;
  if (Start1 < 1) or (Start1 > Length(Line)) then Exit;

  L := Start1;
  R := Start1 + Len - 1;
  if R > Length(Line) then Exit;

  if (L > 1) and IsWordCharU(Line[L-1]) then Exit(False);
  if (R < Length(Line)) and IsWordCharU(Line[R+1]) then Exit(False);

  Result := True;
end;

function NormU(const S: UnicodeString; MatchCase: Boolean): UnicodeString;
begin
  if MatchCase then Result := S else Result := LowerCase(S);
end;

function ExtractExtFromFilterToken(const Tok: string): string;
var
  T: string;
begin
  T := Trim(Tok);
  if T = '' then Exit('');

  T := StringReplace(T, '*', '', [rfReplaceAll]);
  T := Trim(T);

  if (T <> '') and (T[1] <> '.') then
    T := '.' + T;

  Result := LowerCase(T);
end;

function BuildExtList(const Filters: string): TStringList;
var
  SL: TStringList;
  i: Integer;
  E: string;
begin
  SL := TStringList.Create;
  SL.StrictDelimiter := True;
  SL.Delimiter := ';';
  SL.DelimitedText := Filters;

  for i := SL.Count-1 downto 0 do
  begin
    E := ExtractExtFromFilterToken(SL[i]);
    if E = '' then
      SL.Delete(i)
    else
      SL[i] := E;
  end;

  SL.Sorted := True;
  SL.Duplicates := dupIgnore;
  SL.Sorted := False;

  Result := SL;
end;

function ExtAllowed(const FileName: string; Exts: TStrings): Boolean;
var
  E: string;
begin
  if (Exts = nil) or (Exts.Count = 0) then Exit(False);
  E := LowerCase(ExtractFileExt(FileName));
  Result := Exts.IndexOf(E) >= 0;
end;

function ReadFileUtf8(const FilePath: string; out TextU: UnicodeString; out EOL: UnicodeString): Boolean;
var
  FS: TFileStream;
  Buf: RawByteString;
  L: Int64;
  U: UnicodeString;
begin
  Result := False;
  TextU := '';
  EOL := #10;
  Buf := '';

  if not FileExists(FilePath) then Exit;

  FS := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
  try
    L := FS.Size;
    SetLength(Buf, L);
    if L > 0 then
      FS.ReadBuffer(Buf[1], L);

    U := UTF8Decode(string(Buf)); // assume UTF-8
    if Pos(#13#10, U) > 0 then
      EOL := #13#10
    else
      EOL := #10;

    TextU := U;
    Result := True;
  finally
    FS.Free;
  end;
end;

function WriteFileUtf8(const FilePath: string; const TextU: UnicodeString): Boolean;
var
  FS: TFileStream;
  S8: string;
begin
  Result := False;
  S8 := UTF8Encode(TextU);

  FS := TFileStream.Create(FilePath, fmCreate);
  try
    if Length(S8) > 0 then
      FS.WriteBuffer(S8[1], Length(S8));
    Result := True;
  finally
    FS.Free;
  end;
end;

procedure SplitLines_KeepText(const TextU: UnicodeString; Lines: TUnicodeLineList);
var
  i, n, start1: Integer;
  S: UnicodeString;
begin
  Lines.Clear;
  S := TextU;
  n := Length(S);
  start1 := 1;

  for i := 1 to n do
    if S[i] = #10 then
    begin
      Lines.Add(Copy(S, start1, i - start1));
      start1 := i + 1;
    end;

  if start1 <= n + 1 then
    Lines.Add(Copy(S, start1, n - start1 + 1));

  // trim trailing #13 (CRLF)
  for i := 0 to Lines.Count-1 do
    if (Lines[i] <> '') and (Lines[i][Length(Lines[i])] = #13) then
      Lines[i] := Copy(Lines[i], 1, Length(Lines[i]) - 1);
end;

procedure SplitLines_WithTrailingEol(const TextU: UnicodeString; Lines: TUnicodeLineList; out HadTrailingEol: Boolean);
var
  i, n, start1: Integer;
  S: UnicodeString;
begin
  Lines.Clear;
  S := TextU;
  n := Length(S);
  start1 := 1;
  HadTrailingEol := (n > 0) and (S[n] = #10);

  for i := 1 to n do
    if S[i] = #10 then
    begin
      Lines.Add(Copy(S, start1, i - start1));
      start1 := i + 1;
    end;

  if start1 <= n then
    Lines.Add(Copy(S, start1, n - start1 + 1))
  else if (start1 = n + 1) and HadTrailingEol then
    Lines.Add('');

  for i := 0 to Lines.Count-1 do
    if (Lines[i] <> '') and (Lines[i][Length(Lines[i])] = #13) then
      Lines[i] := Copy(Lines[i], 1, Length(Lines[i]) - 1);
end;

function JoinLines(const Lines: TUnicodeLineList; const EOL: UnicodeString; HadTrailingEol: Boolean): UnicodeString;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Lines.Count-1 do
  begin
    if i > 0 then Result := Result + EOL;
    Result := Result + Lines[i];
  end;
  if HadTrailingEol then
    Result := Result + EOL;
end;

function ReplaceAllInLine(var LineU: UnicodeString; const FindU, ReplU: UnicodeString;
  MatchCase, WholeWord: Boolean; TermLen: Integer): Integer;
var
  HayN, NeedleN: UnicodeString;
  P, Start1: Integer;
begin
  Result := 0;
  if FindU = '' then Exit;

  NeedleN := NormU(FindU, MatchCase);
  HayN := NormU(LineU, MatchCase);

  Start1 := 1;
  while True do
  begin
    P := PosEx(NeedleN, HayN, Start1);
    if P <= 0 then Break;

    if WholeWord and (not IsWholeWordAt(LineU, P, TermLen)) then
    begin
      Start1 := P + 1;
      Continue;
    end;

    LineU := Copy(LineU, 1, P-1) + ReplU + Copy(LineU, P+TermLen, MaxInt);
    Inc(Result);

    HayN := NormU(LineU, MatchCase);
    Start1 := P + Length(ReplU);
    if Start1 < 1 then Start1 := 1;
  end;
end;

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

constructor TFindAndReplaceInFilesOptions.Create();
begin
  inherited Create;
  Clear();
end;

procedure TFindAndReplaceInFilesOptions.Clear();
begin
  Term             := '';
  ReplaceWith      := '';

  MatchCase   := False;
  WholeWord   := False;
  ReplaceFlag := False;

  Filters     := '*.*';
  FolderPath  := '';

  SearchInSubFolders := True;
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

{ TFindAndReplaceInFiles }

constructor TFindAndReplaceInFiles.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fOptions := TFindAndReplaceInFilesOptions.Create;
  fFindResult := TFindAndReplaceInFilesResult.Create(fOptions);
end;

destructor TFindAndReplaceInFiles.Destroy();
begin
  FreeAndNil(fFindResult);
  FreeAndNil(fOptions);
  inherited Destroy();
end;

function TFindAndReplaceInFiles.ShowDialog(): Integer;
begin
  Result := -1;  // user hits the cancel button

  fFindResult.FileMatchList.Clear();

  if not TFindAndReplaceInFilesDialog.ShowDialog(Options) then
    Exit;

  if (Options.Term = '')
  or (Options.FolderPath = '')
  or (not DirectoryExists(Options.FolderPath))
  or (Options.Filters = '')
  then
    Exit;

  App.Settings.LastFilter := Options.Filters;
  App.Settings.LastFolderPath := Options.FolderPath;
  App.Settings.Save();

  FindAll();

  if Options.ReplaceFlag then
    ReplaceAll();

  Result := fFindResult.FileMatchList.Count;
 end;

procedure TFindAndReplaceInFiles.FindAll();
var
  Opt: TFindAndReplaceInFilesOptions;
  Exts: TStringList;

  FileTextU, EOL: UnicodeString;
  ULines: TUnicodeLineList;

  NeedleN: UnicodeString;
  TermLen: Integer;

  y, Start1, P: Integer;
  LineU, HayN: UnicodeString;

  FM: TFileMatch;

  procedure ScanFolder(const AFolder: string);
  var
    SR: TSearchRec;
    Folder, Name, FullPath: string;
    iy: Integer;   // <<< πρόσθεσε αυτό
  begin
    Folder := IncludeTrailingPathDelimiter(AFolder);

    if FindFirst(Folder + '*', faAnyFile, SR) = 0 then
    try
      repeat
        Name := SR.Name;
        if (Name = '.') or (Name = '..') then
          Continue;

        FullPath := Folder + Name;

        // sub-folder
        if (SR.Attr and faDirectory) <> 0 then
        begin
          if Opt.SearchInSubFolders then
            ScanFolder(FullPath);
          Continue;
        end;

        // file
        if not ExtAllowed(Name, Exts) then
          Continue;

        if not ReadFileUtf8(FullPath, FileTextU, EOL) then
          Continue;

        SplitLines_KeepText(FileTextU, ULines);

        FM := nil;

        for iy := 0 to ULines.Count - 1 do
        begin
          LineU := ULines[iy];
          HayN := NormU(LineU, Opt.MatchCase);

          Start1 := 1;
          while True do
          begin
            P := PosEx(NeedleN, HayN, Start1);
            if P <= 0 then Break;

            if Opt.WholeWord and (not IsWholeWordAt(LineU, P, TermLen)) then
            begin
              Start1 := P + 1;
              Continue;
            end;

            if FM = nil then
            begin
              FM := TFileMatch.Create(fFindResult, FullPath);
              fFindResult.FileMatchList.Add(FM);
            end;

            FM.TermMatchList.Add(TTermMatch.Create(FM, iy, P-1, UTF8Encode(LineU)));
            Start1 := P + 1;
          end;
        end;

      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;

var
  Folder: string;
begin
  Opt := Options;
  if Opt.TermU = '' then Exit;

  Folder := Trim(Opt.FolderPath);
  if (Folder = '') or (not DirectoryExists(Folder)) then Exit;

  Exts := BuildExtList(Opt.Filters);
  try
    fFindResult.FileMatchList.Clear;

    NeedleN := NormU(Opt.TermU, Opt.MatchCase);
    TermLen := Opt.TermLenChars;

    ULines := TUnicodeLineList.Create;
    try
      ScanFolder(Folder);
    finally
      ULines.Free;
    end;
  finally
    Exts.Free;
  end;
end;

procedure TFindAndReplaceInFiles.ReplaceAll();
var
  Opt: TFindAndReplaceInFilesOptions;
  FilesDone: TStringList;
  ULines: TUnicodeLineList;

  i, y: Integer;
  FM: TFileMatch;
  FilePath: string;

  TextU, EOL: UnicodeString;
  HadTrailingEol: Boolean;

  Changed: Boolean;
  TermLen: Integer;
  Cnt: Integer;

  LineU: UnicodeString;
begin
  Opt := Options;
  if Opt.TermU = '' then Exit;

  FilesDone := TStringList.Create;
  try
    FilesDone.Sorted := True;
    FilesDone.Duplicates := dupIgnore;

    TermLen := Opt.TermLenChars;

    ULines := TUnicodeLineList.Create;
    try
      for i := 0 to fFindResult.FileMatchList.Count - 1 do
      begin
        FM := fFindResult.FileMatchList[i];
        if FM = nil then Continue;

        FilePath := FM.FilePath;
        if FilePath = '' then Continue;

        if FilesDone.IndexOf(FilePath) >= 0 then Continue;
        FilesDone.Add(FilePath);

        if not ReadFileUtf8(FilePath, TextU, EOL) then Continue;

        SplitLines_WithTrailingEol(TextU, ULines, HadTrailingEol);

        Changed := False;
        for y := 0 to ULines.Count - 1 do
        begin
          LineU := ULines[y];

          Cnt := ReplaceAllInLine(LineU, Opt.TermU, Opt.ReplaceWithU,
                                  Opt.MatchCase, Opt.WholeWord, TermLen);

          if Cnt > 0 then
          begin
            ULines[y] := LineU;
            Changed := True;
          end;
        end;

        if Changed then
        begin
          TextU := JoinLines(ULines, EOL, HadTrailingEol);
          WriteFileUtf8(FilePath, TextU);
        end;
      end;
    finally
      ULines.Free;
    end;
  finally
    FilesDone.Free;
  end;
end;

procedure TFindAndReplaceInFiles.LoadTo(tv: TTreeView);
var
  RootNode, FileNode, MatchNode: TTreeNode;
  i, j: Integer;
  FM: TFileMatch;
  TM: TTermMatch;
  S: string;
begin
  if tv = nil then Exit;

  tv.BeginUpdate;
  try
    tv.Items.Clear;

    // Root
    S := Format('Search "%s" in %s',  [Options.Term, Options.FolderPath]);

    RootNode := tv.Items.Add(nil, S);

    for i := 0 to fFindResult.FileMatchList.Count - 1 do
    begin
      FM := fFindResult.FileMatchList[i];
      if FM = nil then Continue;

      S := Format('%s (%d)',
        [ExtractFileName(FM.FilePath), FM.TermMatchList.Count]);

      FileNode := tv.Items.AddChild(RootNode, S);
      FileNode.Data := FM;

      for j := 0 to FM.TermMatchList.Count - 1 do
      begin
        TM := FM.TermMatchList[j];
        if TM = nil then Continue;

        S := Format('%d,%d: %s', [TM.Line, TM.Column, TM.LineText]);

        MatchNode := tv.Items.AddChild(FileNode, S);
        MatchNode.Data := TM;
      end;
    end;

    RootNode.Expand(True);

  finally
    tv.EndUpdate;
  end;
end;

end.

