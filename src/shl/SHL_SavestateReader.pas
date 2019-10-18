unit SHL_SavestateReader;

interface

uses
  SysUtils, Classes, SHL_Gzip;

type
  TSavestateType = (SavestateUnknown, SavestateEpsxe);

  TSavestateReader = class(TObject)
    constructor Create();
    destructor Destroy(); override;
  public
    function ReadFromFile(Savestate: string): Boolean;
    function WriteToFile(Savestate: string): Boolean;
  private
    function GetType(): Boolean;
    procedure UseType();
    function GetMemorySize(): Integer;
  private
    FBuffer, FMemory: PAnsiChar;
    FActualSize: Integer;
    FType: TSavestateType;
  public
    property Memory: PAnsiChar read FMemory;
    property MemorySize: Integer read GetMemorySize;
  end;

implementation

const
  MaxBufferSize = 1024 * 1024 * 6;
  MemorySizeRAM = 1024 * 1024 * 2;

constructor TSavestateReader.Create();
begin
  GetMem(FBuffer, MaxBufferSize);
  GetMem(FMemory, MemorySizeRAM);
  FActualSize := 0;
  FType := SavestateUnknown;
end;

destructor TSavestateReader.Destroy();
begin
  FreeMem(FBuffer);
end;

function TSavestateReader.ReadFromFile(Savestate: string): Boolean;
var
  Gz: TGzipFile;
begin
  Result := False;
  Gz := nil;
  try
    Gz := TGzipFile.CreateRead(Savestate);
    FActualSize := Gz.Read(FBuffer, MaxBufferSize);
    Result := GetType();
  except
  end;
  Gz.Free();
end;

function TSavestateReader.WriteToFile(Savestate: string): Boolean;
var
  Gz: TGzipFile;
begin
  UseType();
  Gz := nil;
  Result := False;
  try
    Gz := TGzipFile.CreateNew(Savestate);
    Gz.WriteBuffer(FBuffer, FActualSize);
    Result := True;
  except
  end;
  Gz.Free();
end;

function TSavestateReader.GetType(): Boolean;
begin
  FType := SavestateUnknown;
  Result := False;
  if not CompareMem(FBuffer, PChar('ePSXe'), 5) then
    Exit;
  if not CompareMem(@FBuffer[435], PChar('MEM'#0), 4) then
    Exit;
  FType := SavestateEpsxe;
  Move(FBuffer[442], FMemory^, MemorySizeRAM);
  Result := True;
end;

procedure TSavestateReader.UseType();
begin
  if FType = SavestateEpsxe then
  begin
    Move(FMemory^, FBuffer[442], MemorySizeRAM);
  end;
end;

function TSavestateReader.GetMemorySize(): Integer;
begin
  if FType <> SavestateUnknown then
    Result := MemorySizeRAM
  else
    Result := 0;
end;

end.

