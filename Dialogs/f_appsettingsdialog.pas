unit f_AppSettingsDialog;

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
  , o_AppSettings
  ;

type

  { TAppSettingsDialog }

  TAppSettingsDialog = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    chAutoSave: TCheckBox;
    chUseHighlighters: TCheckBox;
    chRulerVisible: TCheckBox;
    chShowCurLine: TCheckBox;
    chMinimapVisible: TCheckBox;
    chMinimapTooltipVisible: TCheckBox;
    chGutterVisible: TCheckBox;
    edtAutoSaveSecondsInterval: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    lblFont: TLabel;
  private
    Settings: TAppSettings;
  protected
    procedure AnyClick(Sender: TObject);
    procedure FormInitialize();
    procedure ItemToControls();
    procedure ControlsToItem();
    procedure DoShow; override;

    procedure ShowFontDialog();
    procedure UpdateFontLabel();
  public
    class function ShowDialog(): Boolean;
  end;



implementation

{$R *.lfm}

uses
  o_App
  ;

{ TAppSettingsDialog }

class function TAppSettingsDialog.ShowDialog: Boolean;
var
  Dlg: TAppSettingsDialog;
begin
  Result := False;

  Dlg := TAppSettingsDialog.Create(nil);
  try
    Result := Dlg.ShowModal() = mrOk;
  finally
    Dlg.Free;
  end;
end;

procedure TAppSettingsDialog.DoShow;
begin
  inherited DoShow;
  FormInitialize();
end;

procedure TAppSettingsDialog.ShowFontDialog();
var
  Dlg: TFontDialog;
begin
  Dlg := TFontDialog.Create(nil);
  try
    Dlg.Font.Name := Settings.FontName;
    Dlg.Font.Size := Settings.FontSize;
    if Dlg.Execute then
    begin
      Settings.FontName := Dlg.Font.Name;
      Settings.FontSize := Dlg.Font.Size;

      UpdateFontLabel();
    end;

  finally
    Dlg.Free;
  end;
end;

procedure TAppSettingsDialog.UpdateFontLabel();
begin
  if Trim(Settings.FontName) = '' then
    Settings.FontName := Self.Font.Name;
  if Settings.FontSize <= 0 then
    Settings.FontSize := Self.Font.Size;

  lblFont.Caption := Format('%s, %d', [Settings.FontName, Settings.FontSize]);
end;

procedure TAppSettingsDialog.FormInitialize();
begin
  btnOK.Default := True;
  btnCancel.Cancel := True;
  btnOK.OnClick := AnyClick;

  lblFont.OnClick := AnyClick;

  ItemToControls();
end;

procedure TAppSettingsDialog.ItemToControls();
begin
  Settings := App.Settings;

  UpdateFontLabel();

  chAutoSave.Checked := Settings.AutoSave;

  chUseHighlighters.Checked := Settings.UseHighlighters;
  chGutterVisible.Checked := Settings.GutterVisible;
  chRulerVisible.Checked := Settings.RulerVisible;
  chShowCurLine.Checked := Settings.ShowCurLine;
  chMinimapVisible.Checked := Settings.MinimapVisible;
  chMinimapTooltipVisible.Checked := Settings.MinimapTooltipVisible;

  edtAutoSaveSecondsInterval.Text := IntToStr(Settings.AutoSaveSecondsInterval);
end;

procedure TAppSettingsDialog.ControlsToItem();
begin
  Settings.AutoSave := chAutoSave.Checked;

  Settings.UseHighlighters := chUseHighlighters.Checked;
  Settings.GutterVisible := chGutterVisible.Checked;
  Settings.RulerVisible := chRulerVisible.Checked;
  Settings.ShowCurLine := chShowCurLine.Checked;
  Settings.MinimapVisible := chMinimapVisible.Checked;
  Settings.MinimapTooltipVisible := chMinimapTooltipVisible.Checked;

  Settings.AutoSaveSecondsInterval := App.GetEditBoxIntValue(edtAutoSaveSecondsInterval, Settings.AutoSaveSecondsInterval);

  App.Settings.Save();
  Self.ModalResult := mrOK;
end;

procedure TAppSettingsDialog.AnyClick(Sender: TObject);
begin
  if btnOK = Sender then
    ControlsToItem()
  else if lblFont = Sender then
    ShowFontDialog();
end;


end.

