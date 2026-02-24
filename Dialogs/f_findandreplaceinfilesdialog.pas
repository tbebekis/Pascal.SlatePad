unit f_FindAndReplaceInFilesDialog;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , StdCtrls
  , o_FindAndReplaceInFiles
  ;

type

  { TFindAndReplaceInFilesDialog }

  TFindAndReplaceInFilesDialog = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    btnSelectFolder: TButton;
    chSearchInSubFolders: TCheckBox;
    chMatchCase: TCheckBox;
    chReplace: TCheckBox;
    chWholeWord: TCheckBox;
    cboFilters: TComboBox;
    edtReplaceWith: TEdit;
    edtFolderPath: TEdit;
    edtTerm: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
  private
    class var fFilterAutocompleteList: TStringList;
    Options: TFindAndReplaceInFilesOptions;
  protected
    procedure AnyClick(Sender: TObject);
    procedure FormInitialize();
    procedure ItemToControls();
    procedure ControlsToItem();
    procedure DoShow; override;
  public
    { construction }
    class constructor Create();
    class destructor Destroy();

    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    class function ShowDialog(AOptions: TFindAndReplaceInFilesOptions): Boolean;
    class property FilterAutocompleteList: TStringList read fFilterAutocompleteList;
  end;



implementation

{$R *.lfm}

uses
  o_App
  ;

{ TFindAndReplaceInFilesDialog }

class function TFindAndReplaceInFilesDialog.ShowDialog(AOptions: TFindAndReplaceInFilesOptions): Boolean;
var
  Dlg: TFindAndReplaceInFilesDialog;
begin
  Result := False;

  Dlg := TFindAndReplaceInFilesDialog.Create(nil);
  try
    Dlg.Options := AOptions;
    Result := Dlg.ShowModal() = mrOk;
  finally
    Dlg.Free;
  end;

end;

class constructor TFindAndReplaceInFilesDialog.Create();
begin
  fFilterAutocompleteList := TStringList.Create;
  fFilterAutocompleteList.Add('*.*');
  fFilterAutocompleteList.Add('*.txt');
  fFilterAutocompleteList.Add('*.md');
end;

class destructor TFindAndReplaceInFilesDialog.Destroy();
begin
  fFilterAutocompleteList.Free;
end;

constructor TFindAndReplaceInFilesDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  cboFilters.AutoComplete := True;
  cboFilters.Items.AddStrings(fFilterAutocompleteList);
  cboFilters.ItemIndex := 0;
end;

destructor TFindAndReplaceInFilesDialog.Destroy();
begin
  inherited Destroy();
end;

procedure TFindAndReplaceInFilesDialog.DoShow;
begin
  inherited DoShow;
  FormInitialize();
end;

procedure TFindAndReplaceInFilesDialog.FormInitialize();
begin
  btnOK.Default := True;
  btnCancel.Cancel := True;
  btnOK.OnClick := AnyClick;
  btnSelectFolder.OnClick := AnyClick;
  ItemToControls();
end;

procedure TFindAndReplaceInFilesDialog.ItemToControls();
begin
  edtTerm.Text := Options.Term;
  edtReplaceWith.Text := Options.ReplaceWith;
  chMatchCase.Checked := Options.MatchCase;
  chWholeWord.Checked := Options.WholeWord;
  chReplace.Checked := Options.ReplaceFlag;

  cboFilters.Text := Options.Filters;
  edtFolderPath.Text := Options.FolderPath;
  chSearchInSubFolders.Checked := Options.SearchInSubFolders;
end;

procedure TFindAndReplaceInFilesDialog.ControlsToItem();
var
  S: string;
begin
  S := Trim(edtTerm.Text);
  if S = '' then
    Exit;

  Options.Term := edtTerm.Text;
  Options.ReplaceWith := edtReplaceWith.Text;
  Options.MatchCase := chMatchCase.Checked;
  Options.WholeWord := chWholeWord.Checked;

  Options.ReplaceFlag := chReplace.Checked;
  Options.Filters := Trim(cboFilters.Text);
  if (Options.Filters <> '') and (fFilterAutocompleteList.IndexOf(Options.Filters) = -1) then
    fFilterAutocompleteList.Add(Options.Filters);
  Options.FolderPath := Trim(edtFolderPath.Text);
  Options.SearchInSubFolders := chSearchInSubFolders.Checked;

  Self.ModalResult := mrOK;
end;

procedure TFindAndReplaceInFilesDialog.AnyClick(Sender: TObject);
var
  FolderPath: string;
begin
  if btnOK = Sender then
    ControlsToItem()
  else if btnSelectFolder = Sender then
  begin
    FolderPath := Trim(edtFolderPath.Text);
    if App.ShowFolderDialog(FolderPath) then
      edtFolderPath.Text := FolderPath;
  end;
end;

end.

