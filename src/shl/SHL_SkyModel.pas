unit SHL_SkyModel; // SpyroHackingLib is licensed under WTFPL

interface

uses
  SysUtils, Classes, SHL_Models3D, SHL_Types;

type
  TSkyModel = class(TObject)
  private
    FMemory: PDataChar;
    FType2: Boolean;
    FPoly: PInteger;
    FMics: PWord;
    FPolyCount, FMiscCount: Integer;
    FMiscUsed: Boolean;
    FPrevVertex, FMidVertex, FPrevColor, FMidColor: Integer;
  private
    function DecodeVertex(Data: Integer): RVertex;
    function DecodeFace(var Poly: PInteger; var Misc: PWord): RPolyQuad;
    function PartFaceCount(Part: Pointer): Integer;
  public
    constructor Create(SkyData: Pointer);
    function PartCount(): Integer;
    function GetPart(Index: Integer): Pointer;
    function BackgroundColor(): RColor;
    function PartVertexCount(Part: Pointer): Integer;
    function PartColorCount(Part: Pointer): Integer;
    function PartPosition(Part: Pointer): RVertex;
    function PartGetVertex(Part: Pointer; Index: Integer): RVertex;
    function PartGetColor(Part: Pointer; Index: Integer): RColor;
    procedure PartFaceStart(Part: Pointer);
    function PartFaceNext(out Triangle: RPolyQuad): Boolean;
  public
  end;

implementation

type
  RSky1 = packed record
    Angle: array[0..3] of SmallInt;
    Y, Z: Smallint;
    Vertex: Word;
    X: Smallint;
    Face: Word;
    Color: Word;
    Flag: Integer;
  end;

  PSky1 = ^RSky1;

  RSky2 = packed record
    Angle: array[0..3] of SmallInt;
    Y, Z: Smallint;
    Vertex, Color: Byte;
    X: Smallint;
    Misc, Face: Word;
  end;

  PSky2 = ^RSky2;

constructor TSkyModel.Create(SkyData: Pointer);
begin
  inherited Create();
  FMemory := SkyData;
  FType2 := PSky1(GetPart(0)).Flag <> -1;
end;

function TSkyModel.PartCount(): Integer;
begin
  Result := PInteger(Pointer(FMemory + 4))^;
end;

function TSkyModel.BackgroundColor(): RColor;
begin
  Result.Color := PInteger(Pointer(FMemory))^;
end;

function TSkyModel.GetPart(Index: Integer): Pointer;
begin
  Result := FMemory + PInteger(Pointer(FMemory + 8 + 4 * Index))^;
end;

function TSkyModel.PartVertexCount(Part: Pointer): Integer;
begin
  if FType2 then
    Result := PSky2(Part).Vertex
  else
    Result := PSky1(Part).Vertex;
end;

function TSkyModel.PartColorCount(Part: Pointer): Integer;
begin
  if FType2 then
    Result := PSky2(Part).Color
  else
    Result := PSky1(Part).Color;
end;

function TSkyModel.PartFaceCount(Part: Pointer): Integer;
begin
  if FType2 then
    Result := PSky2(Part).Face
  else
    Result := PSky1(Part).Face;
end;

function TSkyModel.PartPosition(Part: Pointer): RVertex;
begin
  if FType2 then
  begin
    Result.X := PSky2(Part).X;
    Result.Y := -PSky2(Part).Y;
    Result.Z := -PSky2(Part).Z;
  end
  else
  begin
    Result.X := PSky1(Part).X;
    Result.Y := -PSky1(Part).Y;
    Result.Z := -PSky1(Part).Z;
  end;
end;

function TSkyModel.DecodeVertex(Data: Integer): RVertex;
begin
  Result.Z := Bit(Data, 10, False);
  Result.Y := Bit(Data, 11, False);
  Result.X := Bit(Data, 11, False);
end;

function TSkyModel.DecodeFace(var Poly: PInteger; var Misc: PWord): RPolyQuad;
var
  Value, Data: Integer;
begin
  if FType2 then
  begin
    if not FMiscUsed then
    begin
      Value := Poly^;
      Inc(Poly);
      Data := Misc^;
      Inc(Misc);
      FMiscCount := Bit(Value, 3, False);
      Result.Color[1] := Bit(Value, 7, False);
      Result.Color[2] := Bit(Value, 7, False);
      Result.Color[3] := Bit(Value, 7, False);
      Result.Vertex[1] := Bit(Value, 8, False);
      Result.Vertex[2] := Bit(Data, 8, False);
      Result.Vertex[3] := Bit(Data, 8, False);
      if FMiscCount <> 0 then
      begin
        FMiscUsed := True;
        FPrevVertex := Result.Vertex[1];
        FPrevColor := Result.Color[1];
        FMidVertex := Result.Vertex[2];
        FMidColor := Result.Color[2];
      end
      else
        Dec(FPolyCount);
    end
    else
    begin
      Data := Misc^;
      Inc(Misc);
      Result.Vertex[1] := Bit(Data, 8, False);
      Result.Color[1] := Bit(Data, 7, False);
      Result.Vertex[2] := FPrevVertex;
      Result.Color[2] := FPrevColor;
      Result.Vertex[3] := FMidVertex;
      Result.Color[3] := FMidColor;
      if Data <> 0 then
      begin
        FMidVertex := FPrevVertex;
        FMidColor := FPrevColor;
      end;
      FPrevVertex := Result.Vertex[1];
      FPrevColor := Result.Color[1];
      Dec(FMiscCount);
      if FMiscCount = 0 then
      begin
        FMiscUsed := False;
        Dec(FPolyCount);
      end;
    end;
  end
  else
  begin
    Value := Poly^;
    Bit(Value, 2, False);
    Result.Vertex[1] := Bit(Value, 10, False) + 1;
    Result.Vertex[2] := Bit(Value, 10, False) + 1;
    Result.Vertex[3] := Bit(Value, 10, False) + 1;
    Inc(Poly);
    Value := Poly^;
    Bit(Value, 2, False);
    Result.Color[1] := Bit(Value, 10, False) + 1;
    Result.Color[2] := Bit(Value, 10, False) + 1;
    Result.Color[3] := Bit(Value, 10, False) + 1;
    Inc(Poly);
    Dec(FPolyCount);
  end;
end;

function TSkyModel.PartGetVertex(Part: Pointer; Index: Integer): RVertex;
begin
  Result := DecodeVertex(PInteger(Pointer(PDataChar(Part) + SizeOf(RSky1) + (Index
    - 1) * 4))^);
end;

function TSkyModel.PartGetColor(Part: Pointer; Index: Integer): RColor;
begin
  Result.Color := (PInteger(Pointer(PDataChar(Part) + SizeOf(RSky1) + 4 *
    PartVertexCount(Part) + (Index - 1) * 4))^);
end;

procedure TSkyModel.PartFaceStart(Part: Pointer);
begin
  if FType2 then
  begin
    FPolyCount := PartFaceCount(Part);
    FPoly := Pointer(PDataChar(Part) + SizeOf(RSky2) + 4 * PartVertexCount(Part)
      + 4 * PartColorCount(Part));
    FMics := Pointer(PDataChar(Pointer(FPoly)) + FPolyCount);
    FPolyCount := FPolyCount div 4;
    FMiscUsed := False;
  end
  else
  begin
    FPolyCount := PartFaceCount(Part);
    FPoly := Pointer(PDataChar(Part) + SizeOf(RSky1) + 4 * PartVertexCount(Part)
      + 4 * PartColorCount(Part));
  end;
end;

function TSkyModel.PartFaceNext(out Triangle: RPolyQuad): Boolean;
begin
  if FPolyCount = 0 then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  Triangle := DecodeFace(FPoly, FMics);
end;

end.

