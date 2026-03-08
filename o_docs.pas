unit o_Docs;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SyncObjs
  , SysUtils
  , lazsysutils
  , DateUtils
  , Generics.Collections
  , o_Filer
  ;

type
  TDocAction = (daClose, daSaveAs, daKeep, daReload);

  { TTextDocument }
  TTextDocument = class(TCollectionItem)
  private
    fBufferIndex: Integer;
    fCaretX: Integer;
    fCaretY: Integer;
    fFilePath: string;
    fFileReadInfo: TFileReadInfo;

    fId: string;
    fLastSavedUtc: TDateTime;
    fTopLine: Integer;

    fDiskExists: Boolean;
    fDiskMTimeUtc: TDateTime;
    fDiskSize: Int64;

    fSuppressDiskEventsUntilUtc: TDateTime;

    function GetBufferFilePath: string;
    function GetIsBuffer: Boolean;
    function GetIsFirst: Boolean;
    function GetIsLast: Boolean;
    function GetRealFilePath: string;
  protected
    function GetId: string;
    function GetTitle: string;
  public
    function  Load(): string;
    procedure Save(const Text: string);
    procedure SaveAs(const Text: string; const AFilePath: string);

    procedure UpdateDiskState();
    function DiskSignatureChanged(out NewExists: Boolean; out NewMTimeUtc: TDateTime; out NewSize: Int64): Boolean;

    procedure NotifySavedByApp();
    function IsDiskEventSuppressed: Boolean;

    property Title: string read GetTitle;

    property BufferFilePath: string read GetBufferFilePath;
    property RealFilePath: string read GetRealFilePath;

    property IsFirst: Boolean read GetIsFirst;
    property IsLast: Boolean read GetIsLast;

    property IsBuffer: Boolean read GetIsBuffer;
    property FileReadInfo: TFileReadInfo read fFileReadInfo write fFileReadInfo;

    property DiskExists: Boolean read fDiskExists;
    property DiskMTimeUtc: TDateTime read fDiskMTimeUtc;
    property DiskSize: Int64 read fDiskSize;
  published
    property Id: string read GetId write fId;

    property FilePath: string read fFilePath write fFilePath;
    property BufferIndex: Integer read fBufferIndex write fBufferIndex;

    property TopLine: Integer read fTopLine write fTopLine;
    property CaretX: Integer read fCaretX write fCaretX;
    property CaretY: Integer read fCaretY write fCaretY;

    property LastSavedUtc: TDateTime read fLastSavedUtc write fLastSavedUtc;
  end;

  TCollectionFindMethod = function(Item: TCollectionItem): Boolean of object;
  TCollectionFindFunc = function(Item: TCollectionItem): Boolean;

  { TDocumentList }
  TDocumentList = class(TCollection)
  private
    function GetItem(Index: Integer): TTextDocument;
    function GetFirst: TTextDocument;
    function GetLast: TTextDocument;
  public
    constructor Create;

    function Add: TTextDocument;
    function IndexOf(Item: TTextDocument): Integer;
    function Remove(Item: TTextDocument): Boolean;
    function FindItem(Func: TCollectionFindMethod): TTextDocument; overload;
    function FindItem(Func: TCollectionFindFunc): TTextDocument; overload;

    property First: TTextDocument read GetFirst;
    property Last: TTextDocument read GetLast;

    property Items[Index: Integer]: TTextDocument read GetItem; default;
  end;

  { TDocuments }
  TDocuments = class(TPersistent)
  public const
    SFileName = 'Documents.json';
  private
    FLock   : TCriticalSection;
    fActivePageIndex: Integer;
    fList: TDocumentList;
    fFilePath: string;

    function GetNextBufferIndex(): Integer;
  public
    constructor Create();
    destructor Destroy(); override;

    procedure Save();
    procedure Load();

    function OpenDoc(const FilePath: string): TTextDocument;
    function CreateNewBufferDocument(): TTextDocument;

    procedure Rearrange(SourceList: TObjectList<TTextDocument>);

    function FindDocument(const AFilePath: string): TTextDocument;
    function ContainsDocument(const AFilePath: string): Boolean;

    property FilePath: string read fFilePath;
  published
    property List: TDocumentList read fList write fList;
    property ActivePageIndex: Integer read fActivePageIndex write fActivePageIndex;
  end;

implementation

uses
  Math
  ,Tripous
  ,o_App
  ;

{ TTextDocument }

function TTextDocument.GetIsFirst: Boolean;
begin
  Result := Assigned(Collection) and (Collection.Count > 0) and (Collection.Items[0] = Self);
end;

function TTextDocument.GetIsLast: Boolean;
begin
  Result := Assigned(Collection) and (Collection.Count > 0) and (Collection.Items[Collection.Count - 1] = Self);
end;

function TTextDocument.GetRealFilePath: string;
begin
  if IsBuffer then
    Result := BufferFilePath
  else
    Result := FilePath;
end;

function TTextDocument.GetId: string;
begin
  if Sys.IsEmpty(fId) then
    fId := Sys.GenId(False);
  Result := fId;
end;

function TTextDocument.GetTitle: string;
begin
  Result := 'Untitled';
  if IsBuffer then
    Result := Format('Untitled %d', [BufferIndex])
  else
    Result := ExtractFileName(FilePath);
end;

function TTextDocument.GetBufferFilePath: string;
var
  FileName: string;
begin
  FileName := Id + '.txt';
  Result := Sys.CombinePath(App.GetBufferFolderPath(), FileName);
end;

function TTextDocument.GetIsBuffer: Boolean;
begin
  Result := FilePath = '';
end;

function TTextDocument.Load(): string;
begin
  if FileExists(RealFilePath) then
  begin
    //Result := Sys.ReadUtf8TextFile(RealFilePath);
    Result := Filer.ReadTextFile(RealFilePath, fFileReadInfo);
  end;
end;

procedure TTextDocument.Save(const Text: string);
begin
  //Sys.WriteUtf8TextFile(RealFilePath, Text, False);
  Filer.WriteTextFile(RealFilePath, Text, fFileReadInfo.Encoding);
  LastSavedUtc := NowUTC;
  UpdateDiskState();
end;

procedure TTextDocument.SaveAs(const Text: string; const AFilePath: string);
begin
  if FileExists(BufferFilePath) then
      DeleteFile(BufferFilePath);

  //IsBuffer := False;
  BufferIndex := 0;

  FilePath := AFilePath;
  Save(Text);
end;

procedure TTextDocument.UpdateDiskState();
var
  Info: TSearchRec;
  Exists: Boolean;
  MTimeLocal: TDateTime;
begin
  Exists := FileExists(RealFilePath);
  fDiskExists := Exists;

  if Exists then
  begin
    // size + mtime (local datetime)
    if FindFirst(RealFilePath, faAnyFile, Info) = 0 then
    try
      fDiskSize := Info.Size;
      MTimeLocal := FileDateToDateTime(Info.Time);
      // κάνε το UTC signature για να συγκρίνεις σταθερά
      fDiskMTimeUtc := LocalTimeToUniversal(MTimeLocal);
    finally
      FindClose(Info);
    end
    else
    begin
      fDiskSize := 0;
      fDiskMTimeUtc := 0;
    end;
  end
  else
  begin
    fDiskSize := 0;
    fDiskMTimeUtc := 0;
  end;
end;

function TTextDocument.DiskSignatureChanged(out NewExists: Boolean; out NewMTimeUtc: TDateTime; out NewSize: Int64): Boolean;
var
  Info: TSearchRec;
  MTimeLocal: TDateTime;
begin
  NewExists := FileExists(RealFilePath);

  if NewExists then
  begin
    if FindFirst(RealFilePath, faAnyFile, Info) = 0 then
    try
      NewSize := Info.Size;
      MTimeLocal := FileDateToDateTime(Info.Time);
      NewMTimeUtc := LocalTimeToUniversal(MTimeLocal);
    finally
      FindClose(Info);
    end
    else
    begin
      NewSize := 0;
      NewMTimeUtc := 0;
    end;
  end
  else
  begin
    NewSize := 0;
    NewMTimeUtc := 0;
  end;

  Result :=
    (NewExists <> fDiskExists) or
    (Abs(NewMTimeUtc - fDiskMTimeUtc) > (1.0 / (24*60*60))) or // >1 sec
    (NewSize <> fDiskSize);
end;

procedure TTextDocument.NotifySavedByApp();
var
  SuppressDays: Double;
begin
  SuppressDays := (App.DocMonitorIntervalMSecs * 3) / (24 * 60 * 60 * 1000);

  fSuppressDiskEventsUntilUtc := NowUTC + SuppressDays;
end;

function TTextDocument.IsDiskEventSuppressed: Boolean;
begin
  Result := NowUTC <= fSuppressDiskEventsUntilUtc;
end;


{ TDocumentList }

constructor TDocumentList.Create;
begin
  inherited Create(TTextDocument);
end;

function TDocumentList.Add: TTextDocument;
begin
   Result := TTextDocument(inherited Add);
end;

function TDocumentList.Remove(Item: TTextDocument): Boolean;
begin
  Result := IndexOf(Item) >= 0;
  if Result then
    Item.Free;
end;

function TDocumentList.GetItem(Index: Integer): TTextDocument;
begin
  Result := TTextDocument(inherited Items[Index]);
end;

function TDocumentList.GetFirst: TTextDocument;
begin
  Result := nil;
  if Self.Count > 0 then
    Result := Items[0];
end;

function TDocumentList.GetLast: TTextDocument;
begin
  Result := nil;
  if Self.Count > 0 then
    Result := Items[Self.Count - 1];
end;

function TDocumentList.IndexOf(Item: TTextDocument): Integer;
var
  I: Integer;
begin
  Result := -1;
  if Item = nil then
    Exit;

  for I := 0 to Count - 1 do
    if Items[I] = Item then
      Exit(I);
end;

function TDocumentList.FindItem(Func: TCollectionFindMethod): TTextDocument;
var
  I: Integer;
  Item: TTextDocument;
begin
  Result := nil;

  for I := 0 to Count - 1 do
  begin
    Item := Items[I];
    if Func(Item) then
      Exit(Item);
  end;
end;

function TDocumentList.FindItem(Func: TCollectionFindFunc): TTextDocument;
var
  I: Integer;
  Item: TTextDocument;
begin
  Result := nil;

  for I := 0 to Count - 1 do
  begin
    Item := Items[I];
    if Func(Item) then
      Exit(Item);
  end;
end;

{ TDocuments }

constructor TDocuments.Create();
begin
  inherited Create();
  FLock := TCriticalSection.Create();
  fList := TDocumentList.Create();
  fFilePath := Sys.CombinePath(App.GetBufferFolderPath(), SFileName);
end;

destructor TDocuments.Destroy();
begin
  fList.Free();
  FLock.Free();
  inherited Destroy();
end;

procedure TDocuments.Save();
begin
  FLock.Enter();
  try
    Json.SaveToFileSafe(FilePath, Self);
  finally
    FLock.Leave();
  end;
end;

procedure TDocuments.Load();
begin
  FLock.Enter();
  try
    Json.LoadFromFile(FilePath, Self);
  finally
    FLock.Leave();
  end;
end;

procedure TDocuments.Rearrange(SourceList: TObjectList<TTextDocument>);
var
  Item : TTextDocument;
begin
  while List.Count > 0 do
   List[List.Count - 1].Collection := nil;

  for Item in SourceList do
    Item.Collection := List;

  Save();
end;

function TDocuments.FindDocument(const AFilePath: string): TTextDocument;
var
  Item: TCollectionItem;
  Doc: TTextDocument;
begin
  Result := nil;
  for Item in Self.List do
  begin
    Doc := TTextDocument(Item);
    if (not Doc.IsBuffer) and AnsiSameText(Doc.FilePath, AFilePath) then
    begin
      Result := Doc;
      break;
    end;
  end;

end;

function TDocuments.ContainsDocument(const AFilePath: string): Boolean;
begin
  Result := FindDocument(AFilePath) <> nil;
end;

function TDocuments.OpenDoc(const FilePath: string): TTextDocument;
begin
  Result := List.Add();
  //Result.IsBuffer := False;
  Result.BufferIndex := 0;
  Result.LastSavedUtc := NowUTC();
  Result.FilePath := FilePath;

  Save();
end;

function TDocuments.CreateNewBufferDocument(): TTextDocument;
begin
  Result := List.Add();
  //Result.IsBuffer := True;
  Result.BufferIndex := GetNextBufferIndex();
  Result.LastSavedUtc := NowUTC();
  Result.Save('');

  Save();
end;

function TDocuments.GetNextBufferIndex(): Integer;
var
  Item: TCollectionItem;
  Doc : TTextDocument;
  Value : Integer;
begin
  Value := 0;
  for Item in List do
  begin
    Doc := TTextDocument(Item);
    Value := Max(Value, Doc.BufferIndex);
  end;
  Inc(Value);
  Result := Value;

end;



end.

