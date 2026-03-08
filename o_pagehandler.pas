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
  //fr_FramePage
  f_PageForm
  ;

type
  { TPagerHandler }
  TPagerHandler = class
  private
    fOnTabPagesArranged: TNotifyEvent;
    FPager: TPageControl;

    FMouseDown: Boolean;
    FDragging: Boolean;
    FDragStartPos: TPoint;
    FDragSource: TTabSheet;

    function  GetContainer(Tab: TTabSheet): TPageForm;
    function  FindTabUnderMouse(const P: TPoint): TTabSheet;
    procedure ArrangeTabPages(SourceTab, DestTab: TTabSheet);

    procedure PagerMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PagerMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PagerMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

    function  EnsurePageId(ContainerClass: TPageFormClass; const PageId: string): string;

    function  CreateTabPage(ContainerClass: TPageFormClass; const PageId: string; Info: TObject): TTabSheet;
  public
    constructor Create(APager: TPageControl);
    destructor Destroy; override;

    function  FindTabPagePublic(const PageId: string): TTabSheet;
    procedure ClosePage(const PageId: string);
    function  ShowPage(ContainerClass: TPageFormClass; const PageId: string = ''; Info: TObject = nil): TTabSheet;
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

function TPagerHandler.GetContainer(Tab: TTabSheet): TPageForm;
begin
  Result := nil;
  if not Assigned(Tab) then Exit;

  if (Tab.Tag <> 0) and (TObject(PtrInt(Tab.Tag)) is TPageForm) then
    Result := TPageForm(TObject(PtrInt(Tab.Tag)));
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
  Container: TPageForm;
begin
  if (Button <> mbLeft) and (Button <> mbMiddle) then
    Exit;

  Tab := FindTabUnderMouse(Point(X, Y));
  if not Assigned(Tab) then
    Exit;

  if Button = mbMiddle then
  begin
    Container := GetContainer(Tab);
    if Assigned(Container) and Container.CloseableByUser then
      ClosePage(Container.Id);
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

function TPagerHandler.EnsurePageId(ContainerClass: TPageFormClass; const PageId: string): string;
begin
  Result := Trim(PageId);
  if Result = '' then
    Result := ContainerClass.ClassName;
end;

function TPagerHandler.FindTabPage(const PageId: string): TTabSheet;
var
  i: Integer;
  Container: TPageForm;
  IdToFind: string;
begin
  Result := nil;

  IdToFind := Trim(PageId);
  if IdToFind = '' then Exit;

  for i := 0 to FPager.PageCount - 1 do
  begin
    Container := GetContainer(FPager.Pages[i]);
    if Assigned(Container) and SameText(Container.Id, IdToFind) then
      Exit(FPager.Pages[i]);
  end;
end;

function TPagerHandler.CreateTabPage(ContainerClass: TPageFormClass; const PageId: string; Info: TObject): TTabSheet;
var
  Tab: TTabSheet;
  Container: TPageForm;
begin
  Tab := TTabSheet.Create(FPager);
  Tab.PageControl := FPager;
  Tab.Caption := PageId;

  Container := ContainerClass.Create(Tab);
  Container.Visible := False;
  Container.Parent := Tab;
  Container.Align := alClient;
  Container.Id := PageId;
  Container.Info := Info;

  Tab.Tag := PtrInt(Container);

  FPager.ActivePage := Tab;
  Result := Tab;

  Container.Visible := True;

  //Container.ContainerInitialize();

  //Sys.RunOnce(300 * 8, Container.PageInitializeAfter);
end;

function TPagerHandler.FindTabPagePublic(const PageId: string): TTabSheet;
begin
  Result := FindTabPage(PageId);
end;

procedure TPagerHandler.ClosePage(const PageId: string);
var
  Tab: TTabSheet;
  Container: TPageForm;
begin
  Tab := FindTabPage(PageId);
  if not Assigned(Tab) then Exit;

  Container := GetContainer(Tab);
  if Assigned(Container) then
  begin
    if not Container.CanCloseContainer() then
      Exit;
    Container.ClosePage();
    Container.Free();
  end;

  Tab.Free;
end;

function TPagerHandler.ShowPage(ContainerClass: TPageFormClass; const PageId: string; Info: TObject): TTabSheet;
var
  Id: string;
  Tab: TTabSheet;
begin
  Id := EnsurePageId(ContainerClass, PageId);

  Tab := FindTabPage(Id);
  if not Assigned(Tab) then
    Tab := CreateTabPage(ContainerClass, Id, Info)
  else
    FPager.ActivePage := Tab;

  Result := Tab;
end;

procedure TPagerHandler.CloseAll;
var
  Tab: TTabSheet;
  Container: TPageForm;
begin
  while FPager.PageCount > 0 do
  begin
    Tab := FPager.Pages[0];
    Container := GetContainer(Tab);
    if Assigned(Container) then
    begin
      if not Container.CanCloseContainer() then
        Exit;
      Container.Close;
      Container.Free();
    end;
    Tab.Free;
  end;

  FPager.Clear;
end;

end.

