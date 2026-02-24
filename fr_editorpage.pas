unit fr_EditorPage;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , ComCtrls
  , ExtCtrls
  , LCLType

  , fr_FramePage
  , o_Docs
  , o_TextEditor
  , o_FindAndReplace

  ;

type

  { TEditorPage }

  TEditorPage = class(TFramePage)
    StatusBar: TStatusBar;
    ToolBar: TToolBar;
  private
    btnToggleWordWrap: TToolButton;

    FAutoSaveTimer: TTimer;
    fDoc: TTextDocument;
    fFindAndReplaceOptions: TFindAndReplaceOptions;
    FLastEditTick: QWord;
    FAutoSaveDirty: Boolean;
    FAutoSaveIdleMs: Integer;
    fTextEditor: TTextEditor;



    // ● event handler
    procedure AnyClick(Sender: TObject);

    procedure EditorChange(Sender: TObject);
    procedure EditorModifiedChanged(Sender: TObject);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

    procedure AutoSaveTimerTick(Sender: TObject);

    procedure PrepareToolBar();
    procedure UpdateStatusBar();
    procedure UpdateDoc();

    procedure ShowFindAndReplaceDialog();
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;

    procedure Close(); override;
    function CanClosePage(): Boolean; override;

    procedure TitleChanged(); override;
    procedure AdjustTabTitle(); override;

    procedure SaveBuffer();
    procedure Save();
    procedure SaveAs();

    property Doc : TTextDocument read fDoc write fDoc;
    property TextEditor: TTextEditor read fTextEditor;
    property FindAndReplaceOptions : TFindAndReplaceOptions read fFindAndReplaceOptions;
  end;

implementation

{$R *.lfm}

uses
  Math
  ,o_App
  ,o_Highlighters

  ;

{ TEditorPage }

constructor TEditorPage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  fFindAndReplaceOptions := TFindAndReplaceOptions.Create;
end;

destructor TEditorPage.Destroy();
begin
  fFindAndReplaceOptions.Free();
  inherited Destroy();
end;

procedure TEditorPage.ControlInitialize;
var
  DocText: string;
begin
  inherited ControlInitialize;

  Self.CloseableByUser := True;

  fTextEditor := TTextEditor.Create(Self);
  TextEditor.Parent := Self;

  Doc := TTextDocument(Info);

  DocText := Doc.Load();
  TextEditor.EditorText := DocText;
  TextEditor.Modified := False;
  TextEditor.WordWrap := App.Settings.WordWrap;

  TitleChanged();

  FAutoSaveIdleMs := 1000 * 3;
  FAutoSaveDirty := False;
  FLastEditTick := GetTickCount64;

  FAutoSaveTimer := TTimer.Create(Self);
  FAutoSaveTimer.Enabled := False;
  FAutoSaveTimer.OnTimer := AutoSaveTimerTick;

  FAutoSaveTimer.Interval := App.Settings.AutoSaveSecondsInterval * 1000;
  FAutoSaveTimer.Enabled := App.Settings.AutoSave;

  PrepareToolBar();
  UpdateStatusBar();

  TextEditor.CaretX := Max(0, Doc.CaretX);
  TextEditor.CaretY := Max(1, Doc.CaretY);

  TextEditor.OnKeyDown := EditorKeyDown;
  TextEditor.OnMouseDown := EditorMouseDown;
  TextEditor.OnChange := EditorChange;
  TextEditor.OnModifiedChanged := EditorModifiedChanged;

  //if not Doc.IsBuffer then
  //  TextEditor.Highlighter := Highlighters.GetHighlighter(Doc.FilePath);
end;

procedure TEditorPage.ControlInitializeAfter();
begin
  inherited ControlInitializeAfter();

  TextEditor.SetFocus();
end;

procedure TEditorPage.Close();
begin
  if (not Doc.IsBuffer) then
  begin
    if TextEditor.Modified then
      if App.QuestionBox('Save changes?') then
        Save();
    App.Docs.List.Remove(Doc);
    App.Docs.Save();
  end;
end;

function TEditorPage.CanClosePage(): Boolean;
begin
  Result := True;
end;

procedure TEditorPage.TitleChanged();
begin
  TitleText := Doc.Title;
  AdjustTabTitle();
end;

procedure TEditorPage.AdjustTabTitle();
begin
  if TextEditor.Modified and (not Doc.IsBuffer)  then
    ParentTabPage.Caption := TitleText + '*'
  else
    ParentTabPage.Caption := TitleText;
end;

procedure TEditorPage.UpdateDoc();
begin
  //Doc.TopLine := TextEditor.TopLine;
  Doc.CaretX := TextEditor.CaretX;
  Doc.CaretY := TextEditor.CaretY;
end;


procedure TEditorPage.ShowFindAndReplaceDialog();
var
  Term: string;

   Ok: Boolean;
   Cnt: Integer;
begin
  (*
  Term := TextEditor.GetWordAtCaret();
  if Term = '' then
    Exit;

   FindAndReplaceOptions.TextToFind := Term;
   if not TFindAndReplaceDialog.ShowDialog(FindAndReplaceOptions) then
     Exit;

   TextEditor.FindOptions.TextToFind    := UTF8Decode(FindAndReplaceOptions.TextToFind);
   TextEditor.FindOptions.ReplaceWith   := UTF8Decode(FindAndReplaceOptions.ReplaceWith);
   TextEditor.FindOptions.MatchCase     := FindAndReplaceOptions.MatchCase;
   TextEditor.FindOptions.WholeWord     := FindAndReplaceOptions.WholeWord;
   TextEditor.FindOptions.SelectionOnly := FindAndReplaceOptions.SelectionOnly;

   if TextEditor.FindOptions.TextToFind = '' then
     Exit;

   if FindAndReplaceOptions.ReplaceAllFlag then
   begin
     Cnt := TextEditor.ReplaceAll();
     Exit;
   end;

   if FindAndReplaceOptions.ReplaceFlag then
   begin
     Ok := TextEditor.ReplaceNext();
     Exit;
   end;

   Ok := TextEditor.Find(False);
   *)
end;

procedure TEditorPage.SaveBuffer();
var
  DocText: string;
begin
  DocText := UTF8Encode(TextEditor.Text);      // edtFind.Text := UTF8Encode(WordU);  // WordU: UnicodeString
  Doc.Save(DocText);

  TextEditor.Modified := False;
  UpdateDoc();
  UpdateStatusBar();

  App.Docs.Save();
end;

procedure TEditorPage.Save();
var
  DocText: string;
begin
  if Doc.IsBuffer then
  begin
    SaveAs();
    Exit;
  end else begin
    DocText := TextEditor.EditorText;
    Doc.Save(DocText);

    TextEditor.Modified := False;
    UpdateStatusBar();
  end;
end;

procedure TEditorPage.SaveAs();
var
  Dlg: TSaveDialog;
  DocText: string;
  FilePath: string;
begin
  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Title := 'Save As';
    Dlg.Filter :=
      'Text files (*.txt)|*.txt|' +
      'Markdown (*.md)|*.md|' +
      'All files (*.*)|*.*';

    Dlg.DefaultExt := 'txt';
    Dlg.Options := [ofOverwritePrompt, ofPathMustExist];

    if Dlg.Execute() then
    begin
      DocText := TextEditor.EditorText;
      FilePath := Dlg.FileName;
      Doc.SaveAs(DocText, FilePath);
      App.Docs.Save();
      TitleChanged();
      TextEditor.Modified := False;
      UpdateStatusBar();
    end;
  finally
    Dlg.Free;
  end;

end;

procedure TEditorPage.AnyClick(Sender: TObject);
begin
  if btnToggleWordWrap = Sender then
    TextEditor.WordWrap := not TextEditor.WordWrap;
end;

procedure TEditorPage.EditorChange(Sender: TObject);
begin
  if not App.Settings.AutoSave then
    if not Doc.IsBuffer then
      Exit;

  FAutoSaveDirty := True;              // something is written, start "idle countdown"
  FLastEditTick := GetTickCount64;
end;

procedure TEditorPage.EditorModifiedChanged(Sender: TObject);
begin
  TitleChanged();
end;

procedure TEditorPage.EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  (*
  if (Shift = [ssCtrl]) and (Key = VK_F) then
  begin
    Key := 0;
    ShowFindAndReplaceDialog();
  end
  else
  if (Shift = [ssCtrl]) and (Key = VK_S) then
  begin
    Key := 0;
    Save();
  end
  else if Key = VK_ESCAPE then
  begin
    //fSearchAndReplace.ClearHighlights();
  end
  else if Key = VK_F3 then
  begin
    if Shift = [ssShift] then
       TextEditor.Find(True)
    else
       TextEditor.Find(False)
  end
  *)
end;

procedure TEditorPage.EditorMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
end;

procedure TEditorPage.AutoSaveTimerTick(Sender: TObject);
var
  NowTick: QWord;
begin
  if not App.Settings.AutoSave then
    if not Doc.IsBuffer then
      Exit;

  if not TextEditor.Modified then
    Exit;
  if not FAutoSaveDirty then
    Exit;

  NowTick := GetTickCount64;

  // save only when no typing is going on
  if (NowTick - FLastEditTick) < QWord(FAutoSaveIdleMs) then
    Exit;

  if Doc.IsBuffer then
    SaveBuffer()
  else
    Save();                  // SaveEditorText() should set Modified := False

  if not TextEditor.Modified then
    FAutoSaveDirty := False;

end;

procedure TEditorPage.PrepareToolBar();
var
  P: TWinControl;
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  P := ToolBar.Parent;
  ToolBar.Parent := nil;
  try
    btnToggleWordWrap := AddButton(ToolBar, 'TEXT_DOCUMENT_WRAP', 'Word Wrap', AnyClick);
    //AddSeparator(ToolBar);
  finally
    ToolBar.Parent := P;
  end;

end;

procedure TEditorPage.UpdateStatusBar();
begin
  StatusBar.Panels[0].Text := Format('%d: %d', [TextEditor.CaretY, TextEditor.CaretX]);
end;




end.

