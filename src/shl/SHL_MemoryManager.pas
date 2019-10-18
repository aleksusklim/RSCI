unit SHL_MemoryManager;

interface

uses
  SHL_Types;

type
  TMemorySimple = class(TObject)
  private
    FPageSize: Integer;
    FLastPage: Pointer;
    FOffset, FLimit: Integer;
  public
    constructor Create(PageSize: Integer = 16348);
    destructor Destroy(); override;
  public
    function Alloc(Size: Integer; Align: Integer = 1): Pointer;
    procedure Clear();
    function CopyStr(const Str: TextString): PTextChar;
    function CopyWide(const Str: WideString): PWideChar;
  public
    property PageSize: Integer read FPageSize write FPageSize;
  end;

implementation

constructor TMemorySimple.Create(PageSize: Integer = 16348);
begin
  inherited Create();
  FPageSize := PageSize;
end;

destructor TMemorySimple.Destroy();
begin
  Clear();
  inherited Destroy();
end;

function TMemorySimple.Alloc(Size: Integer; Align: Integer = 1): Pointer;
var
  Page: Pointer;
  Have: Integer;
begin
  Result := nil;
  try
    Have := Align - 1;
    Assure((Size >= 0) and (Align > 0) and ((Align and Have) = 0));
    Have := (Integer(FLastPage) + FOffset) and Have;
    if Have <> 0 then
      Inc(FOffset, Align - Have);
    if (FLastPage = nil) or (FOffset + Size > FLimit) then
    begin
      if Size > FPageSize - SizeOf(Pointer) then
        FLimit := Size + SizeOf(Pointer)
      else
        FLimit := FPageSize;
      GetMem(Page, FLimit);
      FOffset := SizeOf(Pointer);
      CastPtr(Page)^ := FLastPage;
      FLastPage := Page;
    end;
    Result := Cast(FLastPage, FOffset);
    Inc(FOffset, Size);
  except
  end;
end;

procedure TMemorySimple.Clear();
var
  Page: Pointer;
begin
  while FLastPage <> nil do
  begin
    Page := FLastPage;
    FLastPage := CastPtr(FLastPage)^;
    FreeMem(Page);
  end;
  FOffset := 0;
  FLimit := 0;
end;

function TMemorySimple.CopyStr(const Str: TextString): PTextChar;
var
  Len: Integer;
begin
  Len := Length(Str) + 1;
  Result := Alloc(Len);
  if Result = nil then
    Exit;
  CopyMemory(Cast(Str), Result, Len);
end;

function TMemorySimple.CopyWide(const Str: WideString): PWideChar;
var
  Len: Integer;
begin
  Len := (Length(Str) + 1) * 2;
  Result := Alloc(Len);
  if Result = nil then
    Exit;
  CopyMemory(Cast(Str), Result, Len);
end;

end.

