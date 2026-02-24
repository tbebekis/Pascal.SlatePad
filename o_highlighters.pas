unit o_Highlighters;

{$mode delphi}
{$H+}

interface

uses
  Classes, SysUtils, Contnrs, Dialogs,
  ATSynEdit,
  atsynedit_adapter_econtrol,
  ec_SyntAnal; // TecSyntAnalyzer

type
  THighlighters = class
  strict private
    class var FLexlibPath: string;

    // ext -> lexer base name (e.g. '.pas'='Pascal', '.md'='Markdown')
    class var FExtMap: TStringList;

    // lexer base name -> TecSyntAnalyzer (cached)
    class var FLexerCache: TStringList;

    // list of editor links (owns objects)
    class var FEditorLinks: TObjectList;

    class procedure EnsureInit; static;

    class function NormalizeExt(const S: string): string; static;
    class function NormalizeLexerName(const S: string): string; static;
    class function LexerFileName(const LexerName: string): string; static;
    class function GetOrLoadAnalyzer(const LexerName: string): TecSyntAnalyzer; static;

    class function FindLink(Editor: TATSynEdit): TObject; static;
  public
    class procedure Initialize(const ALexlibPath: string); static;
    class procedure Finalize; static;

    class procedure RegisterExt(const Ext, LexerName: string); static;
    class procedure RegisterDefaults; static;

    class function GetLexerNameByFileName(const FileName: string): string; static;

    // returns True if a lexer was applied, False if cleared/plain
    class function ApplyToEditor(Editor: TATSynEdit; const FileName: string): Boolean; static;

    // disable highlighting but keep link
    class procedure ClearFromEditor(Editor: TATSynEdit); static;

    // remove adapter link entirely (call before freeing editor, or when closing tab)
    class procedure UnregisterEditor(Editor: TATSynEdit); static;
  end;

implementation

type
  TEditorAdapterLink = class
  public
    Editor: TATSynEdit;
    Adapter: TATAdapterEControl;
    constructor Create(AEditor: TATSynEdit);
    destructor Destroy; override;
  end;

{ TEditorAdapterLink }

constructor TEditorAdapterLink.Create(AEditor: TATSynEdit);
begin
  inherited Create;
  Editor := AEditor;
  Adapter := TATAdapterEControl.Create(Editor);
  Adapter.AddEditor(Editor);
  Editor.AdapterForHilite := Adapter;
end;

destructor TEditorAdapterLink.Destroy;
begin
  //Adapter.Free;   // NO, raises exception
  inherited Destroy;
end;

{ THighlighters }

class procedure THighlighters.EnsureInit;
begin
  if FExtMap <> nil then Exit;

  FExtMap := TStringList.Create;
  FExtMap.CaseSensitive := False;
  FExtMap.Sorted := True;
  FExtMap.Duplicates := dupIgnore;

  FLexerCache := TStringList.Create;
  FLexerCache.CaseSensitive := False;
  FLexerCache.Sorted := True;
  FLexerCache.Duplicates := dupIgnore;

  FEditorLinks := TObjectList.Create(True);
end;

class function THighlighters.NormalizeExt(const S: string): string;
var
  T: string;
begin
  T := Trim(LowerCase(S));
  if T = '' then Exit('');
  if T[1] <> '.' then T := '.' + T;
  Result := T;
end;

class function THighlighters.NormalizeLexerName(const S: string): string;
begin
  Result := Trim(S);
end;

class function THighlighters.LexerFileName(const LexerName: string): string;
begin
  // Τα lexers σου είναι τύπου "Pascal.lcf", "Markdown.lcf", "Bash script.lcf" κλπ.
  Result := IncludeTrailingPathDelimiter(FLexlibPath) + LexerName + '.lcf';
end;

class function THighlighters.GetOrLoadAnalyzer(const LexerName: string): TecSyntAnalyzer;
var
  Idx: Integer;
  FN: string;
  An: TecSyntAnalyzer;
begin
  EnsureInit;

  if LexerName = '' then Exit(nil);

  Idx := FLexerCache.IndexOf(LexerName);
  if Idx >= 0 then
    Exit(TecSyntAnalyzer(FLexerCache.Objects[Idx]));

  FN := LexerFileName(LexerName);
  if not FileExists(FN) then
    Exit(nil);

  An := TecSyntAnalyzer.Create(nil);
  try
    An.LoadFromFile(FN);
  except
    An.Free;
    raise;
  end;

  FLexerCache.AddObject(LexerName, An);
  Result := An;
end;

class function THighlighters.FindLink(Editor: TATSynEdit): TObject;
var
  I: Integer;
begin
  Result := nil;
  if (Editor = nil) or (FEditorLinks = nil) then Exit;

  for I := 0 to FEditorLinks.Count - 1 do
    if TEditorAdapterLink(FEditorLinks[I]).Editor = Editor then
      Exit(FEditorLinks[I]);
end;

class procedure THighlighters.Initialize(const ALexlibPath: string);
begin
  EnsureInit;
  FLexlibPath := ExcludeTrailingPathDelimiter(ALexlibPath);
end;

class procedure THighlighters.Finalize;
var
  I: Integer;
begin
  if FLexerCache <> nil then
  begin
    // free cached analyzers
    for I := 0 to FLexerCache.Count - 1 do
      FLexerCache.Objects[I].Free;
  end;

  FreeAndNil(FEditorLinks);
  FreeAndNil(FLexerCache);
  FreeAndNil(FExtMap);
  FLexlibPath := '';
end;

class procedure THighlighters.RegisterExt(const Ext, LexerName: string);
var
  E, L: string;
  Idx: Integer;
begin
  EnsureInit;
  E := NormalizeExt(Ext);
  if E = '' then Exit;

  L := NormalizeLexerName(LexerName);

  Idx := FExtMap.IndexOfName(E);
  if Idx >= 0 then
    FExtMap.ValueFromIndex[Idx] := L
  else
    FExtMap.Add(E + '=' + L);
end;

class procedure THighlighters.RegisterDefaults;
begin
  RegisterExt('.pas', 'Pascal');
  RegisterExt('.pp',  'Pascal');
  RegisterExt('.lpr', 'Pascal');
  RegisterExt('.lfm', 'Pascal');
  RegisterExt('.dfm', 'Pascal');
  RegisterExt('.lpk', 'Pascal');
  RegisterExt('.inc', 'Pascal');

  RegisterExt('.md',  'Markdown');
  RegisterExt('.json','JSON');
  RegisterExt('.xml', 'XML');
  RegisterExt('.html','HTML');
  RegisterExt('.htm', 'HTML');
  RegisterExt('.css', 'CSS');
  RegisterExt('.js',  'JavaScript');
  RegisterExt('.yaml','YAML');
  RegisterExt('.yml', 'YAML');

  // Στο lexlib σου το filename είναι "Bash script.lcf"
  RegisterExt('.sh',  'Bash script');
end;

class function THighlighters.GetLexerNameByFileName(const FileName: string): string;
var
  Ext: string;
  Idx: Integer;
begin
  EnsureInit;

  Ext := NormalizeExt(ExtractFileExt(FileName));
  if Ext = '' then Exit('');

  Idx := FExtMap.IndexOfName(Ext);
  if Idx < 0 then Exit('');

  Result := Trim(FExtMap.ValueFromIndex[Idx]);
end;

class function THighlighters.ApplyToEditor(Editor: TATSynEdit; const FileName: string): Boolean;
var
  LexerName: string;
  LinkObj: TObject;
  Link: TEditorAdapterLink;
  An: TecSyntAnalyzer;
begin
  Result := False;
  if Editor = nil then Exit;

  EnsureInit;
  if FLexlibPath = '' then Exit;

  LexerName := GetLexerNameByFileName(FileName);

  LinkObj := FindLink(Editor);
  if LinkObj = nil then
  begin
    Link := TEditorAdapterLink.Create(Editor);
    FEditorLinks.Add(Link);
  end
  else
    Link := TEditorAdapterLink(LinkObj);

  if LexerName = '' then
  begin
    Link.Adapter.Lexer := nil; // plain text
    Exit(False);
  end;

  An := GetOrLoadAnalyzer(LexerName);
  Link.Adapter.Lexer := An;

  Result := Assigned(An);

  //ShowMessage('Lexer: ' + LexerName);
  //ShowMessage(LexerFileName(LexerName));

  if Assigned(An) then
  begin
    Link.Adapter.Lexer := An;
    Link.Adapter.ParseFromLine(0, True);
  end;
end;

class procedure THighlighters.ClearFromEditor(Editor: TATSynEdit);
var
  LinkObj: TObject;
begin
  LinkObj := FindLink(Editor);
  if LinkObj <> nil then
    TEditorAdapterLink(LinkObj).Adapter.Lexer := nil;
end;

class procedure THighlighters.UnregisterEditor(Editor: TATSynEdit);
var
  I: Integer;
begin
  if (Editor = nil) or (FEditorLinks = nil) then Exit;

  for I := FEditorLinks.Count - 1 downto 0 do
    if TEditorAdapterLink(FEditorLinks[I]).Editor = Editor then
    begin
      FEditorLinks.Delete(I); // frees link (owns objects = True)
      Exit;
    end;
end;

initialization

finalization
  THighlighters.Finalize;

end.
