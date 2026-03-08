unit o_DocMonitor;

{$mode DELPHI}{$H+}

interface

uses
  Classes, SysUtils, ExtCtrls, o_Docs;

type
  TDocDiskChangeKind = (ddcModified, ddcDeleted, ddcCreated);

  TDocDiskChangeEvent = procedure(Sender: TObject; Doc: TTextDocument; Kind: TDocDiskChangeKind) of object;

  { TDocMonitor }
  TDocMonitor = class
  private
    FDocs: TDocuments;
    FTimer: TTimer;
    FOnDiskChange: TDocDiskChangeEvent;
    FEnabled: Boolean;
    procedure TimerTick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; ADocs: TDocuments);
    destructor Destroy; override;

    procedure Start(IntervalMs: Integer = 2000);
    procedure Stop;

    property OnDiskChange: TDocDiskChangeEvent read FOnDiskChange write FOnDiskChange;
    property Enabled: Boolean read FEnabled;
  end;

implementation

constructor TDocMonitor.Create(AOwner: TComponent; ADocs: TDocuments);
begin
  inherited Create;
  FDocs := ADocs;

  FTimer := TTimer.Create(AOwner);
  FTimer.Enabled := False;
  FTimer.Interval := 2000;
  FTimer.OnTimer := TimerTick;
end;

destructor TDocMonitor.Destroy;
begin
  FTimer.Free;
  inherited Destroy;
end;

procedure TDocMonitor.Start(IntervalMs: Integer);
var
  i: Integer;
  Doc: TTextDocument;
begin
  FTimer.Interval := IntervalMs;
  FEnabled := True;

  // αρχικοποίηση signature ώστε να μην βαρέσει event αμέσως
  for i := 0 to FDocs.List.Count - 1 do
  begin
    Doc := FDocs.List[i];
    if (Doc <> nil) and (not Doc.IsBuffer) then
      Doc.UpdateDiskState();
  end;

  FTimer.Enabled := True;
end;

procedure TDocMonitor.Stop;
begin
  FTimer.Enabled := False;
  FEnabled := False;
end;

procedure TDocMonitor.TimerTick(Sender: TObject);
var
  i: Integer;
  Doc: TTextDocument;
  NewExists: Boolean;
  NewMTimeUtc: TDateTime;
  NewSize: Int64;
  Kind: TDocDiskChangeKind;
begin
  if not Assigned(FDocs) then Exit;

  for i := 0 to FDocs.List.Count - 1 do
  begin
    Doc := FDocs.List[i];
    if (Doc = nil) or Doc.IsBuffer then
      Continue;

    if Doc.DiskSignatureChanged(NewExists, NewMTimeUtc, NewSize) then
    begin

      // Αν το αρχείο μόλις γράφτηκε από το SlatePad, μην το περάσεις για external change
      if Doc.IsDiskEventSuppressed then
      begin
        Doc.UpdateDiskState();
        Continue;
      end;

      // αποφάσισε kind
      if (Doc.DiskExists = True) and (NewExists = False) then
        Kind := ddcDeleted
      else if (Doc.DiskExists = False) and (NewExists = True) then
        Kind := ddcCreated
      else
        Kind := ddcModified;

      // update stored signature ΠΡΙΝ καλέσεις UI, για να μην loop-άρει
      Doc.UpdateDiskState();

      if Assigned(FOnDiskChange) then
        FOnDiskChange(Self, Doc, Kind);
    end;
  end;
end;

end.
