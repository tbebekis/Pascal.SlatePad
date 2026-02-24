unit f_FindAndReplaceDialog;

{$MODE DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , StdCtrls

  ,o_FindAndReplace
  ;

type
  { TFindAndReplaceDialog }
  TFindAndReplaceDialog = class(TForm)
    btnOK: TButton;
    btnCancel: TButton;
    chReplace: TCheckBox;
    chSelectionOnly: TCheckBox;
    chReplaceAll: TCheckBox;
    chMatchCase: TCheckBox;
    chWholeWord: TCheckBox;
    edtTextToFind: TEdit;
    edtReplaceWith: TEdit;
    Label1: TLabel;
    Label2: TLabel;
  private
    Options: TFindAndReplaceOptions;
  protected
    procedure AnyClick(Sender: TObject);
    procedure FormInitialize();
    procedure ItemToControls();
    procedure ControlsToItem();
    procedure DoShow; override;
  public
    class function ShowDialog(AOptions: TFindAndReplaceOptions): Boolean;
  end;


implementation

{$R *.lfm}

class function TFindAndReplaceDialog.ShowDialog(AOptions: TFindAndReplaceOptions): Boolean;
var
  Dlg: TFindAndReplaceDialog;
begin
  Result := False;

  Dlg := TFindAndReplaceDialog.Create(nil);
  try
    Dlg.Options := AOptions;
    Result := Dlg.ShowModal() = mrOk;
  finally
    Dlg.Free;
  end;
end;

procedure TFindAndReplaceDialog.DoShow;
begin
  inherited DoShow;
  FormInitialize();
end;

procedure TFindAndReplaceDialog.FormInitialize();
begin
  btnOK.Default := True;
  btnCancel.Cancel := True;
  btnOK.OnClick := AnyClick;
  ItemToControls();
end;

procedure TFindAndReplaceDialog.ItemToControls();
begin
  edtTextToFind.Text := Options.TextToFind;
  edtReplaceWith.Text := Options.ReplaceWith;
  chMatchCase.Checked := Options.MatchCase;
  chWholeWord.Checked := Options.WholeWord;
  chSelectionOnly.Checked := Options.SelectionOnly;

  chReplace.Checked := Options.ReplaceFlag;
  chReplaceAll.Checked := Options.ReplaceAllFlag;
end;

procedure TFindAndReplaceDialog.ControlsToItem();
var
  S: string;
begin
  S := Trim(edtTextToFind.Text);
  if S = '' then
    Exit;

  Options.TextToFind := edtTextToFind.Text;
  Options.ReplaceWith := edtReplaceWith.Text;
  Options.MatchCase := chMatchCase.Checked;
  Options.WholeWord := chWholeWord.Checked;
  Options.SelectionOnly := chSelectionOnly.Checked;
  Options.ReplaceFlag := chReplace.Checked;
  Options.ReplaceAllFlag := chReplaceAll.Checked;

  Self.ModalResult := mrOK;
end;

procedure TFindAndReplaceDialog.AnyClick(Sender: TObject);
begin
  if btnOK = Sender then
    ControlsToItem();
end;




end.

