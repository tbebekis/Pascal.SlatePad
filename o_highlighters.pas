unit o_Highlighters;

{$mode delphi}{$H+}

interface

uses
  SysUtils,
  Generics.Collections,
  SynEditHighlighter; // TSynCustomHighlighter

type
  Highlighters = class
  private
    class var FMap: TDictionary<string, TSynCustomHighlighter>;
    class var FInited: Boolean;

    class procedure EnsureInit; static;
    class function  NormExt(const FileName: string): string; static;
    class procedure RegisterExt(const Ext: string; HL: TSynCustomHighlighter); static;
    class procedure FreeAll; static;
  public
    // Returns a shared highlighter instance for the file extension, or nil.
    class function GetHighlighter(const FileName: string): TSynCustomHighlighter; static;

    // Optional: call at app shutdown (also called from finalization)
    class procedure Finalize; static;
  end;

implementation

uses
  SynHighlighterPas,     // TSynPasSyn
  SynHighlighterHTML,    // TSynHTMLSyn
  SynHighlighterXML,     // TSynXMLSyn
  SynHighlighterCss,     // TSynCssSyn
  SynHighlighterJScript, // TSynJScriptSyn (js/json)
  SynHighlighterIni,     // TSynIniSyn
  SynHighlighterSQL;     // TSynSQLSyn

class function Highlighters.NormExt(const FileName: string): string;
begin
  Result := LowerCase(ExtractFileExt(FileName));
end;

class procedure Highlighters.RegisterExt(const Ext: string; HL: TSynCustomHighlighter);
var
  K: string;
begin
  K := LowerCase(Ext);
  if (K <> '') and (HL <> nil) then
    FMap.AddOrSetValue(K, HL);
end;

class procedure Highlighters.EnsureInit;
var
  PasHL: TSynPasSyn;
  HtmlHL: TSynHTMLSyn;
  XmlHL: TSynXMLSyn;
  CssHL: TSynCssSyn;
  JsHL: TSynJScriptSyn;
  IniHL: TSynIniSyn;
  SqlHL: TSynSQLSyn;
begin
  if FInited then
    Exit;

  FMap := TDictionary<string, TSynCustomHighlighter>.Create;

  // Create once, reuse everywhere (shared instances)
  PasHL  := TSynPasSyn.Create(nil);
  HtmlHL := TSynHTMLSyn.Create(nil);
  XmlHL  := TSynXMLSyn.Create(nil);
  CssHL  := TSynCssSyn.Create(nil);
  JsHL   := TSynJScriptSyn.Create(nil);
  IniHL  := TSynIniSyn.Create(nil);
  SqlHL  := TSynSQLSyn.Create(nil);

  // Pascal / Lazarus
  RegisterExt('.pas', PasHL);
  RegisterExt('.pp',  PasHL);
  RegisterExt('.inc', PasHL);
  RegisterExt('.lpr', PasHL);
  RegisterExt('.lpi', XmlHL);  // Lazarus project is XML
  RegisterExt('.lfm', PasHL);  // form source is Pascal-ish text

  // Web
  RegisterExt('.htm',  HtmlHL);
  RegisterExt('.html', HtmlHL);
  RegisterExt('.xml',  XmlHL);
  RegisterExt('.xsd',  XmlHL);
  RegisterExt('.xslt', XmlHL);
  RegisterExt('.css',  CssHL);
  RegisterExt('.js',   JsHL);
  RegisterExt('.json', JsHL);  // decent default; if you add a JSON-specific HL later, swap here

  // Config / data
  RegisterExt('.ini', IniHL);
  RegisterExt('.cfg', IniHL);
  RegisterExt('.conf', IniHL);

  // SQL
  RegisterExt('.sql', SqlHL);

  // Markdown: SynEdit doesn't ship a universal markdown HL in all installs.
  // Leave .md as nil (plain text) unless you add your own markdown highlighter.
  // RegisterExt('.md', <your markdown HL>);

  FInited := True;
end;

class function Highlighters.GetHighlighter(const FileName: string): TSynCustomHighlighter;
var
  Ext: string;
begin
  EnsureInit;

  Ext := NormExt(FileName);
  if (Ext <> '') and FMap.TryGetValue(Ext, Result) then
    Exit;

  Result := nil;
end;

class procedure Highlighters.FreeAll;
var
  Pair: TPair<string, TSynCustomHighlighter>;
  Seen: TDictionary<TSynCustomHighlighter, Byte>;
begin
  if FMap = nil then
    Exit;

  // Multiple extensions can map to the same highlighter instance,
  // so we must free each instance only once.
  Seen := TDictionary<TSynCustomHighlighter, Byte>.Create;
  try
    for Pair in FMap do
      if (Pair.Value <> nil) and (not Seen.ContainsKey(Pair.Value)) then
      begin
        Seen.Add(Pair.Value, 1);
        Pair.Value.Free;
      end;
  finally
    Seen.Free;
  end;

  FMap.Free;
  FMap := nil;
  FInited := False;
end;

class procedure Highlighters.Finalize;
begin
  FreeAll;
end;

finalization
  Highlighters.Finalize;

end.
