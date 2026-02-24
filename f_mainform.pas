unit f_MainForm;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , Menus
  , Buttons
  , LCLType
  , ComCtrls, ExtCtrls, StdCtrls
  , Generics.Collections
  , o_PageHandler
  , o_Docs
  , o_FindAndReplaceInFiles
  //, fr_EditorPage
  ,f_EditorForm
  ;

type

  { TMainForm }

  TMainForm = class(TForm)
    MainMenu: TMainMenu;
    edtLog: TMemo;
    mnuAppSettings: TMenuItem;
    Separator2: TMenuItem;
    mnuBottom: TMenuItem;
    mnuExit: TMenuItem;
    BottomPager: TPageControl;
    Pager: TPageControl;
    Separator1: TMenuItem;
    mnuSaveAs: TMenuItem;
    mnuSave: TMenuItem;
    mnuOpen: TMenuItem;
    mnuNew: TMenuItem;
    mnuView: TMenuItem;
    mnuEdit: TMenuItem;
    mnuFile: TMenuItem;
    Splitter: TSplitter;
    TabSheet1: TTabSheet;
    tabLog: TTabSheet;
    tabFindResults: TTabSheet;
    tvFindResults: TTreeView;

  private
    PageHandler : TPagerHandler;
    FindAndReplaceInFiles: TFindAndReplaceInFiles;

    procedure FormInitialize();
    procedure FormFinalize();
    function GetBottomPagerVisible: Boolean;

    procedure LoadDocuments();
    procedure PerformFindInFiles();

    // ● event handler
    procedure AnyClick(Sender: TObject);
    procedure PagerOnChange(Sender: TObject);
    procedure PageHandlerOnPagesArranged(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of string);
    procedure tvFindResults_DoubleClick(Sender: TObject);

    procedure NewDoc();
    procedure OpenDoc();

    function GetActiveEditorPage(): TEditorForm;
    procedure SetBottomPagerVisible(AValue: Boolean);

    procedure AppSettingsChanged();
  protected
    procedure DoCreate; override;
    procedure DoDestroy; override;
    procedure DoShow; override;
    procedure DoClose(var CloseAction: TCloseAction); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;

    property BottomPagerVisible : Boolean read GetBottomPagerVisible write SetBottomPagerVisible;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function CloseQuery: Boolean; override;
  end;

var
  MainForm: TMainForm;

implementation

uses
   Tripous
  ,Tripous.IconList
  ,Tripous.Logs
  ,o_Consts
  ,o_App

  ,f_AppSettingsDialog
  ,o_Highlighters

  ;

{$R *.lfm}

{ TMainForm }

constructor TMainForm.Create(AOwner: TComponent);
var
  Folder: string;
begin
  inherited Create(AOwner);

  KeyPreview := True;
  LogBox.Initialize(edtLog);

  //fBroadcasterToken := Broadcaster.Register(OnBroadcasterEvent);
  IconList.SetResourceNames(IconResourceNames);

  FindAndReplaceInFiles:= TFindAndReplaceInFiles.Create(Self);
  FindAndReplaceInFiles.Options.Filters := App.Settings.LastFilter;
  FindAndReplaceInFiles.Options.FolderPath := App.Settings.LastFolderPath;

  Pager.Clear();
  PageHandler := TPagerHandler.Create(Pager);
  PageHandler.OnTabPagesArranged := PageHandlerOnPagesArranged;

  Pager.OnChange := PagerOnChange;

  AllowDropFiles := True;
  OnDropFiles := FormDropFiles;

  Application.Icon := MainForm.Icon;
  tvFindResults.ReadOnly := True;

  Folder := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  Folder := Sys.CombinePath(Folder, 'ATLexers');
  THighlighters.Initialize(Folder);
  THighlighters.RegisterDefaults;
end;

destructor TMainForm.Destroy;
begin
  //Broadcaster.Unregister(fBroadcasterToken);
  FreeAndNil(PageHandler);
  inherited Destroy;
end;

procedure TMainForm.DoCreate;
begin
  inherited DoCreate;
  FormInitialize();
end;

procedure TMainForm.DoDestroy;
begin
  FormFinalize();
  inherited DoDestroy;
end;

procedure TMainForm.DoShow;
begin
  inherited DoShow;

  BottomPagerVisible := False;
end;

procedure TMainForm.DoClose(var CloseAction: TCloseAction);
begin
  App.Docs.Save();
  LogBox.Finalize();
  inherited DoClose(CloseAction);
end;

procedure TMainForm.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if (Shift = [ssCtrl]) and (Key = VK_R) then
  begin
    Key := 0;
    PerformFindInFiles();

    Exit;
  end;

  inherited KeyDown(Key, Shift);
end;



function TMainForm.GetBottomPagerVisible: Boolean;
begin
  Result := Splitter.Visible;
end;

procedure TMainForm.SetBottomPagerVisible(AValue: Boolean);
begin
  BottomPager.Visible:= AValue;
  Splitter.Visible := AValue;
  Splitter.BringToFront();
end;

procedure TMainForm.AppSettingsChanged();
var
  i : Integer;
  TabPage: TTabSheet;
  EditorPage: TEditorForm;
begin

  for i := 0 to Pager.PageCount - 1 do
  begin
    TabPage := Pager.Pages[i];
    if TabPage.Tag > 0 then
    begin
      EditorPage := TEditorForm(TabPage.Tag);
      EditorPage.TextEditor.AppSettingsChanged();
    end;
  end;
end;


procedure TMainForm.FormInitialize();
begin
  mnuNew.OnClick := AnyClick;
  mnuOpen.OnClick := AnyClick;
  mnuSave.OnClick := AnyClick;
  mnuSaveAs.OnClick := AnyClick;
  mnuExit.OnClick := AnyClick;

  mnuBottom.OnClick := AnyClick;
  mnuAppSettings.OnClick := AnyClick;

  tvFindResults.OnDblClick := tvFindResults_DoubleClick;

  LoadDocuments();
end;

procedure TMainForm.FormFinalize();
begin
end;

procedure TMainForm.LoadDocuments();
var
  Item: TCollectionItem;
  Doc: TTextDocument;
begin
  for Item in App.Docs.List do
  begin
    Doc := TTextDocument(Item);
    PageHandler.ShowPage(TEditorForm, Doc.Id, Doc);
  end;

  if (Pager.PageCount > 0) and (App.Docs.ActivePageIndex <> -1) and (App.Docs.ActivePageIndex <= Pager.PageCount -1) then
    Pager.ActivePageIndex := App.Docs.ActivePageIndex;
end;

procedure TMainForm.AnyClick(Sender: TObject);
var
  EditorPage: TEditorForm;
begin
  if mnuNew = Sender then
    NewDoc()
  else if mnuOpen = Sender then
    OpenDoc()
  else if mnuSave = Sender then
  begin
    EditorPage := GetActiveEditorPage();
    if Assigned(EditorPage) then
      EditorPage.Save();
  end else if mnuSaveAs = Sender then
  begin
    EditorPage := GetActiveEditorPage();
    if Assigned(EditorPage) then
      EditorPage.SaveAs();
  end else if mnuExit = Sender then
  begin
    Close();
  end else if mnuBottom = Sender then
    BottomPagerVisible := not BottomPagerVisible
  else if mnuAppSettings = Sender then
  begin
    if TAppSettingsDialog.ShowDialog() then
      AppSettingsChanged();
  end;
end;

procedure TMainForm.PagerOnChange(Sender: TObject);
begin
  if Pager.PageCount > 0 then
    App.Docs.ActivePageIndex := Pager.ActivePageIndex
  else
    App.Docs.ActivePageIndex := -1;
end;

procedure TMainForm.PageHandlerOnPagesArranged(Sender: TObject);
var
  SourceList: TObjectList<TTextDocument>;
  i : Integer;
  TabPage: TTabSheet;
  EditorPage: TEditorForm;
begin
  SourceList := TObjectList<TTextDocument>.Create(False);
  try
    for i := 0 to Pager.PageCount - 1 do
    begin
      TabPage := Pager.Pages[i];
      if TabPage.Tag > 0 then
      begin
        EditorPage := TEditorForm(TabPage.Tag);
        SourceList.Add(EditorPage.Doc);
      end;
    end;

    if SourceList.Count > 0 then
      App.Docs.Rearrange(SourceList);
  finally
    SourceList.Free();
  end;

end;

procedure TMainForm.FormDropFiles(Sender: TObject; const FileNames: array of string);
var
  FilePath: string;
  Doc: TTextDocument;
begin
  for FilePath in FileNames do
  begin
    if not App.Docs.ContainsDocument(FilePath) then
    begin
      Doc := App.Docs.OpenDoc(FilePath);
      PageHandler.ShowPage(TEditorForm, Doc.Id, Doc);
    end;
  end;
end;

procedure TMainForm.tvFindResults_DoubleClick(Sender: TObject);
var
  Node: TTreeNode;
  FM: TFileMatch;
  TM: TTermMatch;
  FilePath: string;
  Doc : TTextDocument;
  TabPage: TTabSheet;
  EditorPage: TEditorForm;
begin

  FilePath := '';

  Node := tvFindResults.Selected;

  if Assigned(Node) and Assigned(Node.Data) then
  begin
    // Αν είναι file node
    if TObject(Node.Data) is TFileMatch then
    begin
      FM := TFileMatch(Node.Data);
      FilePath := FM.FilePath;
    end else  if TObject(Node.Data) is TTermMatch then
    begin
      TM := TTermMatch(Node.Data);
      FilePath := TM.Owner.FilePath;
    end;
  end;

  if (FilePath <> '') and FileExists(FilePath) then
  begin
    Doc := App.Docs.FindDocument(FilePath);
    if not Assigned(Doc) then
       Doc := App.Docs.OpenDoc(FilePath);

    TabPage := PageHandler.ShowPage(TEditorForm, Doc.Id, Doc);
    if Assigned(TabPage) and (TabPage.Tag > 0) then
    begin
      EditorPage:= TEditorForm(TabPage.Tag);
      EditorPage.TextEditor.FindAndReplace.Options.Clear();
      EditorPage.TextEditor.FindAndReplace.Options.TextToFind := FindAndReplaceInFiles.Options.Term;
      EditorPage.TextEditor.HighlightAll();
    end;
  end;

end;

procedure TMainForm.NewDoc();
var
  Doc: TTextDocument;
begin
  Doc := App.Docs.CreateNewBufferDocument();
  PageHandler.ShowPage(TEditorForm, Doc.Id, Doc);
end;

procedure TMainForm.OpenDoc();
var
  Dlg: TOpenDialog;
  Doc: TTextDocument;
begin
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Title := 'Open';
    Dlg.Filter :=
      'Text files (*.txt)|*.txt|' +
      'Markdown (*.md)|*.md|' +
      'All files (*.*)|*.*';

    Dlg.DefaultExt := 'txt';
    Dlg.Options := [ofFileMustExist, ofPathMustExist];

    if Dlg.Execute() then
    begin
      Doc := App.Docs.OpenDoc(Dlg.FileName);
      PageHandler.ShowPage(TEditorForm, Doc.Id, Doc);
    end;
  finally
    Dlg.Free;
  end;
end;

function TMainForm.GetActiveEditorPage(): TEditorForm;
var
  TabPage: TTabSheet;
begin
  Result := nil;

  TabPage := Pager.ActivePage;
  if (not Assigned(TabPage)) or (TabPage.Tag = 0) then
    Exit;

  Result := TEditorForm(TabPage.Tag);
end;

function TMainForm.CloseQuery: Boolean;
begin
  Result := inherited CloseQuery;
end;

procedure TMainForm.PerformFindInFiles();
var
  Count: Integer;
  Message: string;
begin
  Count := FindAndReplaceInFiles.ShowDialog();
  if Count = 0 then
  begin
    Message := Format('Found 0 files for Term: %s', [FindAndReplaceInFiles.Options.Term]);
    App.InfoBox(Message);
    LogBox.AppendLine(Message);
  end else if Count > 0 then
  begin
    BottomPagerVisible := True;
    FindAndReplaceInFiles.LoadTo(tvFindResults);
    BottomPager.ActivePage := tabFindResults;
  end;
end;

end.

