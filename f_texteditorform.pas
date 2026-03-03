unit f_TextEditorForm;

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

  , f_PageForm
  , o_Docs
  , o_TextEditor
  , o_FindAndReplace
  ;



type
  { TTextEditorForm }
  TTextEditorForm = class(TPageForm)
    StatusBar: TStatusBar;
    ToolBar: TToolBar;
  private
    btnSave: TToolButton;
    btnSaveAs: TToolButton;
    btnFind: TToolButton;
    btnToggleWordWrap: TToolButton;
    btnShowFolder: TToolButton;
    btnClose: TToolButton;

    FAutoSaveTimer: TTimer;
    fDoc: TTextDocument;
    FLastEditTick: QWord;
    FAutoSaveDirty: Boolean;
    FAutoSaveIdleMs: Integer;
    fTextEditor: TTextEditor;

    IsHighlighterRegistered: Boolean;

    // ● event handler
    procedure AnyClick(Sender: TObject);

    procedure Editor_Change(Sender: TObject);
    procedure Editor_ModifiedChanged(Sender: TObject);
    procedure Editor_KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Editor_CaretChangedPos(Sender: TObject);
    procedure Editor_ChangeZoom(Sender: TObject);

    procedure AutoSaveTimerTick(Sender: TObject);

    procedure PrepareToolBar();

    procedure UpdateStatusBarLineColumn();
    procedure UpdateDoc();
  protected
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure ContainerInitialize; override;
    function CanCloseContainer(): Boolean; override;
    procedure AdjustTabTitle(); override;

    procedure SaveBuffer();
    procedure Save();
    procedure SaveAs();
    procedure ReLoadDoc();

    procedure UpdateStatusBar();

    property Doc : TTextDocument read fDoc write fDoc;
    property TextEditor: TTextEditor read fTextEditor;
  end;


implementation

{$R *.lfm}

uses
  Math
  ,o_App
  ,o_Highlighters
  ,o_Filer
  ;

{ TTextEditorForm }

constructor TTextEditorForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  fTextEditor := TTextEditor.Create(Self);
  TextEditor.Parent := Self;
end;

destructor TTextEditorForm.Destroy();
begin
  if IsHighlighterRegistered then
     THighlighters.UnregisterEditor(TextEditor);

  inherited Destroy();
end;

procedure TTextEditorForm.ContainerInitialize;
var
  DocText: string;
begin
  inherited ContainerInitialize;

  Self.CloseableByUser := True;

  Doc := TTextDocument(Info);

  DocText := Doc.Load();

  TextEditor.EditorText := DocText;
  TextEditor.Modified := False;
  TextEditor.WordWrap := True;

  FAutoSaveIdleMs := 1000 * 3;
  FAutoSaveDirty := False;
  FLastEditTick := GetTickCount64;

  FAutoSaveTimer := TTimer.Create(Self);
  FAutoSaveTimer.Enabled := False;
  FAutoSaveTimer.OnTimer := AutoSaveTimerTick;

  FAutoSaveTimer.Interval := App.Settings.AutoSaveSecondsInterval * 1000;
  FAutoSaveTimer.Enabled := App.Settings.AutoSave;

  TextEditor.OnKeyDown := Editor_KeyDown;
  TextEditor.OnChange := Editor_Change;
  TextEditor.OnChangeCaretPos := Editor_CaretChangedPos;
  TextEditor.OnChangeZoom := Editor_ChangeZoom;
  TextEditor.OnChangeModified := Editor_ModifiedChanged;

  TextEditor.SetFocus();

  TextEditor.CaretY := Max(0, Doc.CaretY);
  TextEditor.CaretX := Max(0, Doc.CaretX);

  if App.Settings.UseHighlighters and FileExists(Doc.FilePath) then
  begin
    THighlighters.ApplyToEditor(TextEditor, Doc.FilePath);
    TextEditor.Invalidate;
    TextEditor.Update;
    IsHighlighterRegistered := True;
  end;

  PrepareToolBar();
  UpdateStatusBar();

  TitleText := Doc.Title;

end;

function TTextEditorForm.CanCloseContainer(): Boolean;
begin
  Result := True;

  if (not Doc.IsBuffer) and TextEditor.Modified then
  begin
    if App.QuestionBox(Format('Discard changes to "%s" ?', [Doc.RealFilePath])) then
      Result := True
    else
      Result := False;
  end;
end;

procedure TTextEditorForm.DoClose(var CloseAction: TCloseAction);
begin
  if (not Doc.IsBuffer) then
  begin
    if TextEditor.Modified then
      if App.QuestionBox(Format('Save changes to "%s" ??', [Doc.RealFilePath]))then
        Save();
    App.Docs.List.Remove(Doc);
    App.Docs.Save();
  end;

  inherited DoClose(CloseAction);
end;

procedure TTextEditorForm.AdjustTabTitle();
begin
  if TextEditor.Modified and (not Doc.IsBuffer)  then
    ParentTabPage.Caption := TitleText + '*'
  else
    ParentTabPage.Caption := TitleText;
end;

procedure TTextEditorForm.UpdateDoc();
begin
  Doc.CaretX := TextEditor.CaretX;
  Doc.CaretY := TextEditor.CaretY;
end;

procedure TTextEditorForm.SaveBuffer();
var
  DocText: string;
begin
  DocText := TextEditor.EditorText;
  Doc.Save(DocText);

  TextEditor.Modified := False;
  UpdateDoc();
  UpdateStatusBar();

  App.Docs.Save();
end;

procedure TTextEditorForm.Save();
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

procedure TTextEditorForm.SaveAs();
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
    if not Doc.IsBuffer then
    begin
      Dlg.FileName := Doc.FilePath;
    end;

    if Dlg.Execute() then
    begin
      DocText := TextEditor.EditorText;
      FilePath := Dlg.FileName;
      Doc.SaveAs(DocText, FilePath);
      App.Docs.Save();
      TitleText := Doc.Title;
      TextEditor.Modified := False;
      UpdateStatusBar();
    end;
  finally
    Dlg.Free;
  end;

end;

procedure TTextEditorForm.ReLoadDoc();
var
  DocText: string;
begin
  DocText := Doc.Load();

  TextEditor.EditorText := DocText;
  TextEditor.Modified := False;
end;

procedure TTextEditorForm.AnyClick(Sender: TObject);
begin
  if btnSave = Sender then
    Save()
  else if btnSaveAs = Sender then
    SaveAs()
  else if btnFind = Sender then
    TextEditor.ShowFindAndReplaceDialog()
  else if btnShowFolder = Sender then
    App.DisplayFileExplorer(Doc.RealFilePath)
  else if btnToggleWordWrap = Sender then
    TextEditor.WordWrap := not TextEditor.WordWrap
  else if btnClose = Sender then
    App.ClosePage(Id);

end;

procedure TTextEditorForm.Editor_Change(Sender: TObject);
begin
  if not App.Settings.AutoSave then
    if not Doc.IsBuffer then
      Exit;

  FAutoSaveDirty := True;              // something is written, start "idle countdown"
  FLastEditTick := GetTickCount64;
end;

procedure TTextEditorForm.Editor_ModifiedChanged(Sender: TObject);
begin
  TitleChanged();
end;

procedure TTextEditorForm.Editor_KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Shift = [ssCtrl]) and (Key = VK_S) then
  begin
    Key := 0;
    Save();
  end
end;

procedure TTextEditorForm.Editor_CaretChangedPos(Sender: TObject);
begin
  UpdateStatusBarLineColumn();
  UpdateDoc();
end;

procedure TTextEditorForm.Editor_ChangeZoom(Sender: TObject);
begin
  UpdateStatusBar();
end;

procedure TTextEditorForm.AutoSaveTimerTick(Sender: TObject);
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

procedure TTextEditorForm.PrepareToolBar();
var
  P: TWinControl;
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  P := ToolBar.Parent;
  ToolBar.Parent := nil;
  try
    btnSave  := AddButton(ToolBar, 'DISK', 'Save', AnyClick);
    btnSaveAs := AddButton(ToolBar, 'DISK_MULTIPLE', 'Save As', AnyClick);
    btnFind := AddButton(ToolBar, 'PAGE_FIND', 'Find', AnyClick);
    btnToggleWordWrap := AddButton(ToolBar, 'TEXT_DOCUMENT_WRAP', 'Word Wrap', AnyClick);
    btnShowFolder := AddButton(ToolBar, 'FOLDER_GO', 'Show in folder', AnyClick);
    btnClose := AddButton(ToolBar, 'DOOR_OUT', 'Close', AnyClick);
    //AddSeparator(ToolBar);
  finally
    ToolBar.Parent := P;
  end;

end;

procedure TTextEditorForm.UpdateStatusBarLineColumn();
begin
  StatusBar.Panels[0].Text := Format(' Ln: %d, Col: %d', [TextEditor.CaretY, TextEditor.CaretX]);
end;

procedure TTextEditorForm.UpdateStatusBar();
  function GetZoom(): string;
  var
    V: Integer;
  begin
    V := 100;
    if TextEditor.OptScaleFont <> 0 then
      V := TextEditor.OptScaleFont;
    Result := IntToStr(V) + '%';
  end;

begin
  UpdateStatusBarLineColumn();
  StatusBar.Panels[1].Text := Format('      %s', [Filer.EncodingToStr(Doc.FileReadInfo.Encoding)]);
  StatusBar.Panels[2].Text := Format('      %s', [Filer.EolToStr(Doc.FileReadInfo.Eol)]);
  StatusBar.Panels[3].Text := Format('      %s', [GetZoom()]);
  StatusBar.Panels[4].Text := Format('      %s', [Doc.RealFilePath]);
end;



end.




