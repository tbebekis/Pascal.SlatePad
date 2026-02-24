unit o_PageHandler;

{$MODE DELPHI}{$H+}
{$WARN 5024 off : Parameter "$1" not used}
interface

uses
  Classes,
  SysUtils,
  Types,
  Controls,
  ComCtrls,
  Forms,
  Tripous,
  fr_FramePage;

type
  TFramePageClass = class of TFramePage;

  { TPagerHandler }
  TPagerHandler = class
  private
    fOnTabPagesArranged: TNotifyEvent;
    FPager: TPageControl;

    FMouseDown: Boolean;
    FDragging: Boolean;
    FDragStartPos: TPoint;
    FDragSource: TTabSheet;

    function  GetPageFrame(Tab: TTabSheet): TFramePage;
    function  FindTabUnderMouse(const P: TPoint): TTabSheet;
    procedure ArrangeTabPages(SourceTab, DestTab: TTabSheet);

    procedure PagerMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PagerMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PagerMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

    function  EnsurePageId(AFrameClass: TFramePageClass; const PageId: string): string;

    function  CreateTabPage(AFrameClass: TFramePageClass; const PageId: string; Info: TObject): TTabSheet;
  public
    constructor Create(APager: TPageControl);
    destructor Destroy; override;

    function  FindTabPagePublic(const PageId: string): TTabSheet;
    procedure ClosePage(const PageId: string);
    function  ShowPage(AFrameClass: TFramePageClass; const PageId: string = ''; Info: TObject = nil): TTabSheet;
    procedure CloseAll;

    function  FindTabPage(const PageId: string): TTabSheet;

    property Pager: TPageControl read FPager;

    property OnTabPagesArranged: TNotifyEvent read fOnTabPagesArranged write fOnTabPagesArranged;
  end;

implementation

{ TPagerHandler }

constructor TPagerHandler.Create(APager: TPageControl);
begin
  inherited Create;

  if not Assigned(APager) then
    raise Exception.Create('APager is nil.');

  FPager := APager;

  FPager.OnMouseDown := PagerMouseDown;
  FPager.OnMouseMove := PagerMouseMove;
  FPager.OnMouseUp   := PagerMouseUp;

  FMouseDown := False;
  FDragging := False;
  FDragSource := nil;
end;

destructor TPagerHandler.Destroy;
begin
  inherited Destroy;
end;

function TPagerHandler.GetPageFrame(Tab: TTabSheet): TFramePage;
begin
  Result := nil;
  if not Assigned(Tab) then Exit;

  if (Tab.Tag <> 0) and (TObject(PtrInt(Tab.Tag)) is TFramePage) then
    Result := TFramePage(TObject(PtrInt(Tab.Tag)));
end;

function TPagerHandler.FindTabUnderMouse(const P: TPoint): TTabSheet;
var
  i: Integer;
  R: TRect;
begin
  Result := nil;

  if not Assigned(FPager) then Exit;
  if FPager.PageCount = 0 then Exit;

  for i := 0 to FPager.PageCount - 1 do
  begin
    R := FPager.TabRect(i);
    if PtInRect(R, P) then
      Exit(FPager.Pages[i]);
  end;
end;

procedure TPagerHandler.ArrangeTabPages(SourceTab, DestTab: TTabSheet);
var
  DestIndex: Integer;
begin
  if (not Assigned(SourceTab)) or (not Assigned(DestTab)) then Exit;
  if SourceTab = DestTab then Exit;

  DestIndex := DestTab.PageIndex;
  SourceTab.PageIndex := DestIndex;

  if Assigned(fOnTabPagesArranged) then
    fOnTabPagesArranged(Self);
end;

procedure TPagerHandler.PagerMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Tab: TTabSheet;
  Frame: TFramePage;
begin
  if (Button <> mbLeft) and (Button <> mbMiddle) then
    Exit;

  Tab := FindTabUnderMouse(Point(X, Y));
  if not Assigned(Tab) then
    Exit;

  if Button = mbMiddle then
  begin
    Frame := GetPageFrame(Tab);
    if Assigned(Frame) and Frame.CloseableByUser then
      ClosePage(Frame.Id);
    Exit;
  end;

  FMouseDown := True;
  FDragging := False;
  FDragStartPos := Point(X, Y);
  FDragSource := Tab;
end;

procedure TPagerHandler.PagerMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
const
  DragThreshold = 6;
var
  Dx, Dy: Integer;
begin
  if not FMouseDown then Exit;
  if not Assigned(FDragSource) then Exit;

  Dx := Abs(X - FDragStartPos.X);
  Dy := Abs(Y - FDragStartPos.Y);

  if (not FDragging) and ((Dx >= DragThreshold) or (Dy >= DragThreshold)) then
    FDragging := True;
end;

procedure TPagerHandler.PagerMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  DestTab: TTabSheet;
begin
  if Button <> mbLeft then
  begin
    FMouseDown := False;
    FDragging := False;
    FDragSource := nil;
    Exit;
  end;

  if FDragging and Assigned(FDragSource) then
  begin
    DestTab := FindTabUnderMouse(Point(X, Y));
    if Assigned(DestTab) then
      ArrangeTabPages(FDragSource, DestTab);
  end;

  FMouseDown := False;
  FDragging := False;
  FDragSource := nil;
end;

function TPagerHandler.EnsurePageId(AFrameClass: TFramePageClass; const PageId: string): string;
begin
  Result := Trim(PageId);
  if Result = '' then
    Result := AFrameClass.ClassName;
end;

function TPagerHandler.FindTabPage(const PageId: string): TTabSheet;
var
  i: Integer;
  Frame: TFramePage;
  IdToFind: string;
begin
  Result := nil;

  IdToFind := Trim(PageId);
  if IdToFind = '' then Exit;

  for i := 0 to FPager.PageCount - 1 do
  begin
    Frame := GetPageFrame(FPager.Pages[i]);
    if Assigned(Frame) and SameText(Frame.Id, IdToFind) then
      Exit(FPager.Pages[i]);
  end;
end;

function TPagerHandler.CreateTabPage(AFrameClass: TFramePageClass; const PageId: string; Info: TObject): TTabSheet;
var
  Tab: TTabSheet;
  Frame: TFramePage;
begin
  Tab := TTabSheet.Create(FPager);
  Tab.PageControl := FPager;
  Tab.Caption := PageId;

  Frame := AFrameClass.Create(Tab);
  Frame.Parent := Tab;
  Frame.Align := alClient;
  Frame.Id := PageId;
  Frame.Info := Info;

  Tab.Tag := PtrInt(Frame);

  FPager.ActivePage := Tab;
  Result := Tab;

  Frame.ControlInitialize();

  Sys.RunOnce(300 * 8, Frame.ControlInitializeAfter);
end;

function TPagerHandler.FindTabPagePublic(const PageId: string): TTabSheet;
begin
  Result := FindTabPage(PageId);
end;

procedure TPagerHandler.ClosePage(const PageId: string);
var
  Tab: TTabSheet;
  Frame: TFramePage;
begin
  Tab := FindTabPage(PageId);
  if not Assigned(Tab) then Exit;

  Frame := GetPageFrame(Tab);
  if Assigned(Frame) then
  begin
    if not Frame.CanClosePage() then
      Exit;
    Frame.Close;
    Frame.Free();
  end;

  Tab.Free;
end;

function TPagerHandler.ShowPage(AFrameClass: TFramePageClass; const PageId: string; Info: TObject): TTabSheet;
var
  Id: string;
  Tab: TTabSheet;
begin
  Id := EnsurePageId(AFrameClass, PageId);

  Tab := FindTabPage(Id);
  if not Assigned(Tab) then
    Tab := CreateTabPage(AFrameClass, Id, Info)
  else
    FPager.ActivePage := Tab;

  Result := Tab;
end;

procedure TPagerHandler.CloseAll;
var
  Tab: TTabSheet;
  Frame: TFramePage;
begin
  while FPager.PageCount > 0 do
  begin
    Tab := FPager.Pages[0];
    Frame := GetPageFrame(Tab);
    if Assigned(Frame) then
    begin
      if not Frame.CanClosePage() then
        Exit;
      Frame.Close;
      Frame.Free();
    end;
    Tab.Free;
  end;

  FPager.Clear;
end;

end.

