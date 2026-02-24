unit fr_FramePage;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , ComCtrls
  , Controls
  , LCLType
  , Tripous.Broadcaster
  ;

type

  { TFramePage }

  TFramePage = class(TFrame)
  private
    fCloseableByUser: Boolean;
    fId: string;
    fInfo: TObject;
  protected
    TitleText: string;
    fBroadcasterToken: TBroadcastToken;
    function GetParentTabPage: TTabSheet; virtual;

    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ControlInitialize(); virtual;
    procedure ControlInitializeAfter(); virtual;
    procedure Close(); virtual;
    function CanClosePage(): Boolean; virtual;

    procedure TitleChanged(); virtual;
    procedure AdjustTabTitle(); virtual;

    // ● editor handler
    procedure SaveEditorText(TextEditor: TObject); virtual;

    // ● toolbar
    function AddButton(AToolBar: TToolBar; const AIconName: string; const AHint: string; AOnClick: TNotifyEvent): TToolButton;
    function AddSeparator(AToolBar: TToolBar): TToolButton;

    // ● properties
    property Id : string read fId write fId;
    property CloseableByUser: Boolean read fCloseableByUser write fCloseableByUser;
    property Info: TObject read fInfo write fInfo;

    property ParentTabPage: TTabSheet read GetParentTabPage;
  end;

implementation

{$R *.lfm}

uses
   Tripous.IconList
  ,o_App
  ;


{ TFramePage }

constructor TFramePage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fBroadcasterToken := Broadcaster.Register(OnBroadcasterEvent);
end;

destructor TFramePage.Destroy;
begin
  Broadcaster.Unregister(fBroadcasterToken);
  inherited Destroy;
end;

procedure TFramePage.ControlInitialize();
begin
end;

procedure TFramePage.ControlInitializeAfter();
begin
end;

function TFramePage.GetParentTabPage: TTabSheet;
begin
  if Self.Parent is TTabSheet then
     Result := Self.Parent as TTabSheet
  else
    Result := nil;
end;

procedure TFramePage.TitleChanged();
begin
  AdjustTabTitle();
end;

procedure TFramePage.AdjustTabTitle();
begin
end;

procedure TFramePage.OnBroadcasterEvent(Args: TBroadcasterArgs);
begin
end;

procedure TFramePage.Close();
begin
  // nothing
end;

function TFramePage.CanClosePage(): Boolean;
begin
  Result := True;
end;

procedure TFramePage.SaveEditorText(TextEditor: TObject);
begin
end;

function TFramePage.AddButton(AToolBar: TToolBar; const AIconName: string; const AHint: string; AOnClick: TNotifyEvent): TToolButton;
begin
  Result := IconList.AddButton(AToolBar, AIconName, AHint, AOnClick);
end;

function TFramePage.AddSeparator(AToolBar: TToolBar): TToolButton;
begin
  Result := IconList.AddSeparator(AToolBar);
end;



end.

