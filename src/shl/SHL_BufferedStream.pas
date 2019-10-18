unit SHL_BufferedStream; // SpyroHackingLib is licensed under WTFPL

interface

uses
  SysUtils, Classes, SHL_Types;

type
  TBufferedRead = class(TStream)
  private
    FStream: TStream;
    FSize, FBack: Integer;
    FBuffer: Pointer;
    FIndex, FFirst, FLast: Integer;
  private
    function RealPosition(): Int64;
  protected
    function GetSize(): Int64; override;
  public
    constructor Create(BufferSize: Integer; Backtrack: Integer = 1);
    destructor Destroy(); override;
  public
    function Open(Source: TStream): Boolean;
    procedure Close();
    function BackTrack(Value: Integer): Integer;
    function Write(const Buffer; Count: Integer): Integer; override;
    function Read(var Buffer; Count: Integer): Integer; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

type
  TBufferedWrite = class(TStream)
  private
    FStream: TStream;
    FSize, FOffset: Integer;
    FBuffer: Pointer;
    FOwned, FUsed: Boolean;
    FWideName: WideString;
    FTextName: TextString;
  private
    function RealPosition(): Int64;
  protected
    function GetSize(): Int64; override;
  public
    constructor Create(BufferSize: Integer);
    destructor Destroy(); override;
  public
    function Open(Source: TStream): Boolean; overload;
    function Open(const Filename: WideString; Demand: Boolean): Boolean; overload;
    function Open(const Filename: TextString; Demand: Boolean): Boolean; overload;
    procedure Close();
    function Flush(): Boolean;
    function Write(const Buffer; Count: Integer): Integer; override;
    function Read(var Buffer; Count: Integer): Integer; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  public
    property Used: Boolean read FUsed;
  end;

implementation

uses
  Math, SHL_Files;

constructor TBufferedRead.Create(BufferSize: Integer; Backtrack: Integer = 1);
begin
  inherited Create();
  FBack := BackTrack;
  FSize := BufferSize + FBack;
  GetMem(FBuffer, FSize);
end;

destructor TBufferedRead.Destroy();
begin
  if FBuffer <> nil then
    FreeMem(FBuffer);
  inherited Destroy();
end;

function TBufferedRead.Open(Source: TStream): Boolean;
begin
  Close();
  FStream := Source;
  FIndex := 0;
  FFirst := 0;
  FLast := 0;
  Result := Source <> nil;
end;

procedure TBufferedRead.Close();
begin
  FStream := nil;
end;

function TBufferedRead.BackTrack(Value: Integer): Integer;
begin
  if FFirst <= FIndex then
    Result := FIndex - FFirst
  else
    Result := FIndex + FSize - FFirst;
  if Value < Result then
    Result := Value;
  Dec(FIndex, Result);
  if FIndex < 0 then
    Inc(FIndex, FSize);
end;

function TBufferedRead.RealPosition(): Int64;
begin
  Result := FStream.Position;
  if FIndex < FLast then
    Dec(Result, Int64(FLast) - Int64(FIndex))
  else
    Dec(Result, Int64(FLast) + Int64(FSize) - Int64(FIndex));
end;

function TBufferedRead.GetSize(): Int64;
begin
  Result := FStream.Size;
end;

function TBufferedRead.Read(var Buffer; Count: Integer): Integer;
var
  SaveTo: Pointer;
  Len, Target: Integer;
begin
  Result := 0;
  SaveTo := @Buffer;
  while Count > 0 do
  begin
    if FLast >= FIndex then
      Len := FLast - FIndex
    else
      Len := FSize - FIndex;
    if Len = 0 then
    begin
      if FFirst <= FIndex then
        Len := FSize - FIndex
      else
        Len := FFirst - FIndex;
      Len := FStream.Read(Cast(Fbuffer, FIndex)^, Len);
      Inc(FLast, Len);
      if FLast = FSize then
        FLast := 0;
    end;
    if Len > Count then
      Len := Count;
    if Len = 0 then
      Exit;
    CopyMemory(Cast(Fbuffer, FIndex), SaveTo, Len);
    Inc(Result, Len);
    Adv(SaveTo, Len);
    Dec(Count, Len);
    Inc(FIndex, Len);
    if FIndex = FSize then
      FIndex := 0;
    if FIndex > FFirst then
      Target := FIndex - FFirst
    else
      Target := FIndex + FSize - FFirst;
    Dec(Target, FBack);
    if Target > 0 then
    begin
      Inc(FFirst, Target);
      if FFirst >= FSize then
        Dec(FFirst, FSize);
    end;
  end;
end;

function TBufferedRead.Write(const Buffer; Count: Integer): Integer;
begin
  Ignore(Buffer, Count);
  Result := 0;
end;

function TBufferedRead.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  if (Origin = soCurrent) and (Offset = 0) then
  begin
    Result := RealPosition();
  end
  else
  begin
    Result := Offset;
    if Origin = soCurrent then
      Inc(Result, RealPosition())
    else if Origin = soEnd then
      Inc(Result, GetSize());
    FStream.Position := Result;
    Open(FStream);
  end;
end;

constructor TBufferedWrite.Create(BufferSize: Integer);
begin
  inherited Create();
  if BufferSize < 0 then
    FSize := 0
  else
  begin
    FSize := BufferSize;
    GetMem(FBuffer, FSize);
  end;
end;

destructor TBufferedWrite.Destroy();
begin
  Close();
  if FBuffer <> nil then
    FreeMem(FBuffer);
  inherited Destroy();
end;

function TBufferedWrite.Open(Source: TStream): Boolean;
begin
  Close();
  FStream := Source;
  FOffset := 0;
  Result := Source <> nil;
end;

function TBufferedWrite.Open(const Filename: WideString; Demand: Boolean): Boolean;
begin
  Close();
  if Filename = '' then
    Result := False
  else
  begin
    Result := True;
    FOwned := True;
    if Demand then
      FWideName := Filename
    else
    begin
      FStream := SFiles.OpenNew(Filename);
      if FStream = nil then
      begin
        FOwned := False;
        Result := False;
      end;
    end;
  end;
end;

function TBufferedWrite.Open(const Filename: TextString; Demand: Boolean): Boolean;
begin
  Close();
  if Filename = '' then
    Result := False
  else
  begin
    Result := True;
    FOwned := True;
    if Demand then
      FTextName := Filename
    else
    begin
      FStream := SFiles.OpenNew(Filename);
      if FStream = nil then
      begin
        FOwned := False;
        Result := False;
      end;
    end;
  end;
end;

procedure TBufferedWrite.Close();
begin
  Flush();
  if FOwned then
    FStream.Free();
  FStream := nil;
  FOwned := False;
  FUsed := False;
end;

function TBufferedWrite.Flush(): Boolean;
begin
  Result := False;
  if (FOffset < 0) or (FStream = nil) then
    Exit;
  if FOffset = 0 then
  begin
    Result := True;
    Exit;
  end;
  if FStream.Write(FBuffer^, FOffset) = FOffset then
    Result := True;
end;

function TBufferedWrite.RealPosition(): Int64;
begin
  if FOffset > 0 then
    Result := FStream.Position + FOffset
  else
    Result := FStream.Position;
end;

function TBufferedWrite.GetSize(): Int64;
var
  Last: Int64;
begin
  Result := FStream.Size;
  Last := RealPosition();
  if Last > Result then
    Result := Last;
end;

function TBufferedWrite.Read(var Buffer; Count: Integer): Integer;
begin
  Ignore(Buffer, Count);
  Result := 0;
end;

function TBufferedWrite.Write(const Buffer; Count: Integer): Integer;
var
  ReadFrom: Pointer;
  Tail: Integer;
begin
  Result := 0;
  if (FOffset < 0) or (Count < 1) then
    Exit;
  FUsed := True;
  if FStream = nil then
  begin
    if not FOwned then
      Exit;
    if FWideName <> '' then
      FStream := SFiles.OpenNew(FWideName)
    else if FTextName <> '' then
      FStream := SFiles.OpenNew(FTextName);
    if FStream = nil then
    begin
      Exit;
      FOwned := False;
    end;
  end;
  ReadFrom := @Buffer;
  Tail := FSize - FOffset;
  if Count > Tail then
  begin
    if Tail > 0 then
    begin
      CopyMemory(ReadFrom, Cast(FBuffer, FOffset), Tail);
      Adv(ReadFrom, Tail);
      Inc(FOffset, Tail);
      Inc(Result, Tail);
      Dec(Count, Tail);
    end;
    if (FSize > 0) and (FStream.Write(FBuffer^, FSize) <> FSize) then
    begin
      Result := 0;
      FOffset := -1;
      Exit;
    end;
    FOffset := 0;
    if Count > FSize then
    begin
      Inc(Result, FStream.Write(ReadFrom^, Count));
      Exit;
    end;
  end;
  CopyMemory(ReadFrom, Cast(FBuffer, FOffset), Count);
  Inc(FOffset, Count);
  Inc(Result, Count);
end;

function TBufferedWrite.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  if (Origin = soCurrent) and (Offset = 0) then
  begin
    Result := RealPosition();
  end
  else
  begin
    Result := Offset;
    if Origin = soCurrent then
      Inc(Result, RealPosition())
    else if Origin = soEnd then
      Inc(Result, GetSize());
    Flush();
    FStream.Position := Result;
    Open(FStream);
  end;
end;

end.

