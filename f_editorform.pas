unit f_EditorForm;

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
  { TEditorForm }
  TEditorForm = class(TPageForm)
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
    fFindAndReplaceOptions: TFindAndReplaceOptions;
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
    procedure Editor_MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Editor_CaretChangedPos(Sender: TObject);
    procedure Editor_ChangeZoom(Sender: TObject);

    procedure Form_MouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);

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

    procedure UpdateStatusBar();

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
  ,o_Filer
  ;

{ TEditorForm }

constructor TEditorForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  fFindAndReplaceOptions := TFindAndReplaceOptions.Create;

  fTextEditor := TTextEditor.Create(Self);
  TextEditor.Parent := Self;

  Self.OnMouseWheel := Form_MouseWheel;
end;

destructor TEditorForm.Destroy();
begin
  if IsHighlighterRegistered then
     THighlighters.UnregisterEditor(TextEditor.Editor);

  fFindAndReplaceOptions.Free();
  inherited Destroy();
end;

procedure TEditorForm.ContainerInitialize;
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

  TitleText := Doc.Title;

  FAutoSaveIdleMs := 1000 * 3;
  FAutoSaveDirty := False;
  FLastEditTick := GetTickCount64;

  FAutoSaveTimer := TTimer.Create(Self);
  FAutoSaveTimer.Enabled := False;
  FAutoSaveTimer.OnTimer := AutoSaveTimerTick;

  FAutoSaveTimer.Interval := App.Settings.AutoSaveSecondsInterval * 1000;
  FAutoSaveTimer.Enabled := App.Settings.AutoSave;

  PrepareToolBar();

  TextEditor.OnKeyDown := Editor_KeyDown;
  TextEditor.OnMouseDown := Editor_MouseDown;
  TextEditor.OnChange := Editor_Change;
  TextEditor.OnModifiedChanged := Editor_ModifiedChanged;
  TextEditor.OnChangeCaretPos := Editor_CaretChangedPos;
  TextEditor.OnChangeZoom := Editor_ChangeZoom;

  TextEditor.SetFocus();

  TextEditor.CaretY := Max(0, Doc.CaretY);
  TextEditor.CaretX := Max(0, Doc.CaretX);

  if App.Settings.UseHighlighters and FileExists(Doc.FilePath) then
  begin
    THighlighters.ApplyToEditor(TextEditor.Editor, Doc.FilePath);
    TextEditor.Editor.Invalidate;
    TextEditor.Editor.Update;
    IsHighlighterRegistered := True;
  end;

  UpdateStatusBar();

end;

function TEditorForm.CanCloseContainer(): Boolean;
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

procedure TEditorForm.DoClose(var CloseAction: TCloseAction);
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

procedure TEditorForm.AdjustTabTitle();
begin
  if TextEditor.Modified and (not Doc.IsBuffer)  then
    ParentTabPage.Caption := TitleText + '*'
  else
    ParentTabPage.Caption := TitleText;
end;

procedure TEditorForm.UpdateDoc();
begin
  Doc.CaretX := TextEditor.CaretX;
  Doc.CaretY := TextEditor.CaretY;
end;

procedure TEditorForm.SaveBuffer();
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

procedure TEditorForm.Save();
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

procedure TEditorForm.SaveAs();
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
      TitleChanged();
      TextEditor.Modified := False;
      UpdateStatusBar();
    end;
  finally
    Dlg.Free;
  end;

end;

procedure TEditorForm.AnyClick(Sender: TObject);
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

procedure TEditorForm.Editor_Change(Sender: TObject);
begin
  if not App.Settings.AutoSave then
    if not Doc.IsBuffer then
      Exit;

  FAutoSaveDirty := True;              // something is written, start "idle countdown"
  FLastEditTick := GetTickCount64;
end;

procedure TEditorForm.Editor_ModifiedChanged(Sender: TObject);
begin
  TitleChanged();
end;

procedure TEditorForm.Editor_KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Shift = [ssCtrl]) and (Key = VK_S) then
  begin
    Key := 0;
    Save();
  end

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

procedure TEditorForm.Editor_MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
end;

procedure TEditorForm.Editor_CaretChangedPos(Sender: TObject);
begin
  UpdateStatusBarLineColumn();
  UpdateDoc();
end;

procedure TEditorForm.Editor_ChangeZoom(Sender: TObject);
begin
  UpdateStatusBar();
end;

procedure TEditorForm.Form_MouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if (ssCtrl in Shift) then
  begin
    TextEditor.Editor.OptScaleFont := TextEditor.Editor.OptScaleFont;
    TextEditor.Editor.Update;
    TextEditor.Editor.Invalidate;
  end;
end;

procedure TEditorForm.AutoSaveTimerTick(Sender: TObject);
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

procedure TEditorForm.PrepareToolBar();
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

procedure TEditorForm.UpdateStatusBarLineColumn();
begin
  StatusBar.Panels[0].Text := Format(' Ln: %d, Col: %d', [TextEditor.CaretY, TextEditor.CaretX]);
end;

procedure TEditorForm.UpdateStatusBar();
  function GetZoom(): string;
  var
    V: Integer;
  begin
    V := 100;
    if TextEditor.Editor.OptScaleFont <> 0 then
      V := TextEditor.Editor.OptScaleFont;
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




