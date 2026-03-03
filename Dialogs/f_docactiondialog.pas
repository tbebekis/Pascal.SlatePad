unit f_DocActionDialog;

{$mode DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls
  ,o_Docs
  ;

type

  { TDocActionDialog }

  TDocActionDialog = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    lblMessage: TLabel;
    gboOptions: TRadioGroup;
  private
    IsDeleted : Boolean;
    FilePath: string;
    DocAction : TDocAction;
  protected
    procedure AnyClick(Sender: TObject);
    procedure FormInitialize();
    procedure ItemToControls();
    procedure ControlsToItem();
    procedure DoShow; override;
  public
    class function ShowDialog(AIsDeleted: Boolean; const AFilePath: string; var ADocAction: TDocAction): Boolean;
  end;



implementation

{$R *.lfm}


{ TDocActionDialog }

class function TDocActionDialog.ShowDialog(AIsDeleted: Boolean; const AFilePath: string; var ADocAction: TDocAction): Boolean;
var
  Dlg: TDocActionDialog;
begin
  Result := False;

  Dlg := TDocActionDialog.Create(nil);
  try
    Dlg.IsDeleted := AIsDeleted;
    Dlg.FilePath := AFilePath;
    Result := Dlg.ShowModal() = mrOk;
    if Result then
      ADocAction := Dlg.DocAction;
  finally
    Dlg.Free;
  end;
end;

procedure TDocActionDialog.DoShow;
begin
  inherited DoShow;
  FormInitialize();
end;

procedure TDocActionDialog.FormInitialize();
begin
  btnOK.Default := True;
  btnCancel.Cancel := True;
  btnOK.OnClick := AnyClick;

  ItemToControls();
end;

procedure TDocActionDialog.ItemToControls();
begin
  if IsDeleted then
    lblMessage.Caption :=
      Format('File %s%sis deleted in disk.%sPlease select an action.',
        [FilePath, LineEnding, LineEnding])
  else
    lblMessage.Caption :=
      Format('File %s%sis modified by another application.%sPlease select an action.',
        [FilePath, LineEnding, LineEnding]);

  //TDocAction = (daClose, daSaveAs, daKeep, daReload);
  gboOptions.Items.Add('Close');
  gboOptions.Items.Add('Save As');
  gboOptions.Items.Add('Keep it open');
  if not IsDeleted then
    gboOptions.Items.Add('Reload');

  gboOptions.ItemIndex := 0;
end;

procedure TDocActionDialog.ControlsToItem();
begin
  DocAction := TDocAction(gboOptions.ItemIndex);
  Self.ModalResult := mrOK;
end;

procedure TDocActionDialog.AnyClick(Sender: TObject);
begin
  if btnOK = Sender then
    ControlsToItem()

end;

end.

