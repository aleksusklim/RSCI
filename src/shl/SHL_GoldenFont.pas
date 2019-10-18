unit SHL_GoldenFont; // SpyroHackingLib is licensed under WTFPL

interface

uses
  Windows, SysUtils, Classes, SHL_ObjModel, SHL_GmlModel, SHL_VramManager,
  SHL_TextureManager, SHL_Models3D, SHL_Types;

type
  TGoldenFont = class(TObject)
  private
    FMemory, FRamStart, FUsedModel: Pointer;
    FVertexCount, FColorCount, FPolySize, FUsedFrame: Integer;
    FVertexIndex, FColorIndex, FPolyIndex: PInteger;
    FColors: RQuadData;
    FTexture: RVramTexture;
    FNormal: Integer;
    FUsedLow, FHaveNormal, FHaveColor, FHaveTexture, FNormalpha, FSecondLayer: Boolean;
    FPositive: Boolean;
    _at, _a0, _a1, _a2, _v0, _v1, _t6, _t7, _s0, _s4: Integer;
    FCacheVertex: array of RVertex;
    FCacheColors: array[0..255] of RColor;
    FTiangle: Boolean;
    FManager: TTextureManager;
    FTwoVertex, FTwoColor: RQuadData;
    FTwoNormal, FTwoTextU, FTwoTextV: RPoint;
    FTwoHaveTexture, FTwoHaveNormal, FTwoHaveLayer: Boolean;
    FTwoHaveAlpha: Integer;
  private
    function RamCalc(): Integer;
    function GetData(Model: Pointer; Index: Integer): Pointer;
    function GetVertexCount(Model: Pointer): Integer;
    function GetModel(Index: Integer): Pointer;
    procedure DecodeVertex(Vertex: Integer; out X, Y, Z: Integer);
    function GetVertex(Model: Pointer; Index: Integer): PInteger;
    function GetColorCount(Model: Pointer): Integer;
    function GetColor(Model: Pointer; Index: Integer; Low: Boolean): PInteger;
    procedure DecodeNormals(Normal: Integer; out X, Y, Z: Real);
    function DecodePoly(Poly: Pointer; out V1, V2, V3, V4, C1, C2, C3, C4,
      Normals: Integer; out Alpha: Boolean): Boolean;
    function GetPoly(Model: Pointer; out Size: Integer; Low: Boolean): Pointer;
    function Triangle(V1, V2, V3, V4: Integer; out A1, A2, A3, B1, B2, B3, Q1,
      Q2, Q3, Q4: Integer; TwoSizeFlag: Boolean): Boolean;
    function DecodeTexture(Poly: Pointer; out X1, Y1, X2, Y2, X3, Y3, X4, Y4,
      Pal_x, Pal_y, Bpp, Alpha: Integer): Boolean;
  protected
    function EncodeVertex(X, Y, Z: Integer): Integer;
    function EncodeNormals(X, Y, Z: Real): Integer;
    procedure EncodePoly(Poly: Pointer; V1, V2, V3, V4, C1, C2, C3, C4, Normals: Integer);
    function GetPolyCount(Model: Pointer; Low: Boolean): Integer;
    function GetPolyNext(Poly: Pointer): Pointer;
  public
    constructor Create(Memory: Pointer);
  public
    function ModelCount(): Integer;
    function ModelFrames(Index: Integer): Integer;
    procedure UseModel(Index: Integer; Frame: Integer; LowPoly: Boolean);
    procedure VertexStart(Frame: Integer);
    function VertexNext(out Vertex: RVertex): Boolean;
    procedure ColorStart();
    function ColorNext(out Color: RColor): Boolean;
    procedure FaceStart();
    function FaceNext(out QuadVertex: RQuadData): Boolean;
    function FaceColor(out QuadColor: RQuadData): Boolean;
    function FaceNormal(out Normal: RPoint): Boolean;
    function FaceTexture(out VramTexture: RVramTexture): Boolean;
    function FaceAlpha(): Boolean;
    function FaceLayer(): Boolean;
    function FaceTriangle(Poly: RPolyQuad; out TiangleOne, TiangleTwo, Quadro:
      RPolyQuad): Boolean;
    procedure Convert(RamStart: Integer = 0);
    procedure Textures(TextureManager: TTextureManager; Model: Integer = -1);
    function ObjVertex(Obj: TObjModel): Integer;
    function ObjColors(Obj: TObjModel): Integer;
    function ObjPoly(Obj: TObjModel; TextureManager: TTextureManager = nil;
      Alpha: Trilean = Anything): Integer;
    procedure GmlSavePoly(Gml: TGmlModel; TextureManager: TTextureManager = nil;
      Alpha: Trilean = Anything; Normal: Trilean = Anything; Texture: Trilean =
      Anything; Flag: Integer = 0; Layer: Trilean = Anything);
    procedure GmlSaveVertex(Gml: TGmlModel; Radius: Real; Steps: Integer);
    procedure GmlSaveEdge(Gml: TGmlModel; Triangulate: Boolean);
    function PrepareModel(Frame: Integer): RBox;
    procedure SetPolyFlag(Poly: Pointer; Flag: Integer);
    function FaceDataStart(TextureManager: TTextureManager): Boolean;
    function FaceDataNext(out Vertex: RQuadData; out Color: RQuadData; out
      Normal, TextU, TextV: RPoint; out HaveTexture, HaveNormal, HaveLayer:
      Boolean; out HaveAlpha: Integer): Boolean;
  end;

type
  RGoldModel = record
    Data, Vertex, Colors, Poly, Low: string;
  end;

  AGoldModel = array of RGoldModel;

  SGoldModel = class
    class procedure GoldModelSave(Model: RGoldModel; Filename: string);
    class function GoldModelLoad(Filename: string): RGoldModel;
    class function GoldModelExtract(Gold: TGoldenFont; Index: Integer): RGoldModel;
    class function GoldModelCombine(Models: AGoldModel; Optimize: Boolean =
      False): string;
    class function GoldModelNew(Vertex, Colors, Poly, PolyTex, PolyLow,
      PolyLowTex: Integer): RGoldModel;
  end;

implementation

const
  GlobVertexData: array[0..127] of Integer = (Integer($FE9FD3FA), Integer($FF5FD3FA),
    Integer($001FD3FA), Integer($00DFD3FA), Integer($019FD3FA), Integer($FE9FEBFA),
    Integer($FF5FEBFA), Integer($001FEBFA), Integer($00DFEBFA), Integer($019FEBFA),
    Integer($FE8003FA), Integer($FF4003FA), Integer($000003FA), Integer($00C003FA),
    Integer($018003FA), Integer($FE801BFA), Integer($FF401BFA), Integer($00001BFA),
    Integer($00C01BFA), Integer($01801BFA), Integer($FE8033FA), Integer($FF4033FA),
    Integer($000033FA), Integer($00C033FA), Integer($018033FA), Integer($FE9FD3FD),
    Integer($FF5FD3FD), Integer($001FD3FD), Integer($00DFD3FD), Integer($019FD3FD),
    Integer($FE9FEBFD), Integer($FF5FEBFD), Integer($001FEBFD), Integer($00DFEBFD),
    Integer($019FEBFD), Integer($FE8003FD), Integer($FF4003FD), Integer($000003FD),
    Integer($00C003FD), Integer($018003FD), Integer($FE801BFD), Integer($FF401BFD),
    Integer($00001BFD), Integer($00C01BFD), Integer($01801BFD), Integer($FE8033FD),
    Integer($FF4033FD), Integer($000033FD), Integer($00C033FD), Integer($018033FD),
    Integer($FE9FD000), Integer($FF5FD000), Integer($001FD000), Integer($00DFD000),
    Integer($019FD000), Integer($FE9FE800), Integer($FF5FE800), Integer($001FE800),
    Integer($00DFE800), Integer($019FE800), Integer($FE800000), Integer($FF400000),
    Integer($00000000), Integer($00C00000), Integer($01800000), Integer($FE801800),
    Integer($FF401800), Integer($00001800), Integer($00C01800), Integer($01801800),
    Integer($FE803000), Integer($FF403000), Integer($00003000), Integer($00C03000),
    Integer($01803000), Integer($FE9FD003), Integer($FF5FD003), Integer($001FD003),
    Integer($00DFD003), Integer($019FD003), Integer($FE9FE803), Integer($FF5FE803),
    Integer($001FE803), Integer($00DFE803), Integer($019FE803), Integer($FE800003),
    Integer($FF400003), Integer($00000003), Integer($00C00003), Integer($01800003),
    Integer($FE801803), Integer($FF401803), Integer($00001803), Integer($00C01803),
    Integer($01801803), Integer($FE803003), Integer($FF403003), Integer($00003003),
    Integer($00C03003), Integer($01803003), Integer($FE9FD006), Integer($FF5FD006),
    Integer($001FD006), Integer($00DFD006), Integer($019FD006), Integer($FE9FE806),
    Integer($FF5FE806), Integer($001FE806), Integer($00DFE806), Integer($019FE806),
    Integer($FE800006), Integer($FF400006), Integer($00000006), Integer($00C00006),
    Integer($01800006), Integer($FE801806), Integer($FF401806), Integer($00001806),
    Integer($00C01806), Integer($01801806), Integer($FE803006), Integer($FF403006),
    Integer($00003006), Integer($00C03006), Integer($01803006), Integer($7E7F7F80),
    Integer($7C7C7D7D), Integer($797A7A7B));

class procedure SGoldModel.GoldModelSave(Model: RGoldModel; Filename: string);
var
  Doc: Text;

  procedure Push(S: string);
  var
    I, L: Integer;
  begin
    L := Length(S);
    Writeln(Doc, L);
    if L > 0 then
    begin
      for I := 1 to L - 1 do
        Write(Doc, Ord(S[I]), ' ');
      Writeln(Doc, Ord(S[L]));
    end;
  end;

begin
  Assign(Doc, Filename);
  Rewrite(Doc);
  Push(Model.Data);
  Push(Model.Vertex);
  Push(Model.Colors);
  Push(Model.Poly);
  Push(Model.Low);
  Close(Doc);
end;

class function SGoldModel.GoldModelLoad(Filename: string): RGoldModel;
var
  Doc: Text;

  function Pop(): string;
  var
    I, L, X: Integer;
  begin
    Readln(Doc, L);
    SetLength(Result, L);
    if L > 0 then
    begin
      for I := 1 to L - 1 do
      begin
        read(Doc, X);
        Result[I] := Chr(X);
      end;
      Readln(Doc, X);
      Result[L] := Chr(X);
    end;
  end;

begin
  Assign(Doc, Filename);
  Reset(Doc);
  Result.Data := Pop();
  Result.Vertex := Pop();
  Result.Colors := Pop();
  Result.Poly := Pop();
  Result.Low := Pop();
  Close(Doc);
end;

class function SGoldModel.GoldModelExtract(Gold: TGoldenFont; Index: Integer): RGoldModel;
var
  Model, Data: Pointer;
  Count: Integer;
begin
  Model := Gold.GetModel(Index);

  Count := 6;
  SetLength(Result.Data, Count);
  CopyMemory(Cast(Model, 2), Cast(Result.Data), Count);

  Count := Gold.GetVertexCount(Model) * 4;
  SetLength(Result.Vertex, Count);
  CopyMemory(Cast(Model, 16), Cast(Result.Vertex), Count);

  Count := Gold.GetColorCount(Model) * 4;
  SetLength(Result.Colors, Count * 2);
  CopyMemory(Gold.GetColor(Model, 0, False), Cast(Result.Colors), Count);
  CopyMemory(Gold.GetColor(Model, 0, True), Cast(Result.Colors, Count), Count);

  Data := Gold.GetPoly(Model, Count, False);
  SetLength(Result.Poly, Count);
  CopyMemory(Data, Cast(Result.Poly), Count);

  Data := Gold.GetPoly(Model, Count, True);
  SetLength(Result.Low, Count);
  CopyMemory(Data, Cast(Result.Low), Count);
end;

class function SGoldModel.GoldModelCombine(Models: AGoldModel; Optimize: Boolean
  = False): string;
var
  Model: RGoldModel;
  Index, Count, Offset, Len: Integer;
  Data, Header, Body, Poly, Intro, Chunk: string;
  PHeader, PSize, PChunk: PInteger;
  Words: PWord;
begin
  Result := '';
  Data := '';
  Count := Length(Models);
  if Count < 1 then
    Exit;
  SetLength(Header, 20 + Count * 4);
  PHeader := Cast(Header);

  PHeader^ := -Count;
  Inc(PHeader);
  PHeader^ := -1;
  Inc(PHeader);
  PHeader^ := 0;
  Inc(PHeader);
  PHeader^ := 0;
  Inc(PHeader);
  PSize := PHeader;
  Inc(PHeader);

  Body := '';
  Poly := '';
  if Optimize then
    Offset := 4
  else
    Offset := 0;
  SetLength(Intro, 16);
  for Index := 0 to Count - 1 do
  begin
    Model := Models[Index];
    Chunk := '';
    if Length(Model.Data) = 6 then
      Data := Model.Data
    else
      Model.Data := #0#0#0#0#0#0;

    if Model.Vertex <> '' then
    begin
      Words := Cast(Intro);
      FillChar(Words^, 16, #0);
      Words^ := (Length(Model.Colors) div 8) or ((Length(Model.Vertex) div 4) shl 8);
      Inc(Words);
      CopyMemory(Cast(Data), Words, 6);
      Inc(Words, 3);

      SetLength(Chunk, 4 + Length(Model.Poly) + 4 + Length(Model.Low) + Length(Model.Colors));
      PChunk := Cast(Chunk);

      Words^ := Offset;
      Len := Length(Model.Poly);
      PChunk^ := Len;
      Inc(PChunk);
      CopyMemory(Cast(Model.Poly), PChunk, Len);
      Inc(PChunk, Len div 4);
      Inc(Offset, Len + 4);

      Inc(Words, 2);
      Words^ := Offset;
      Len := Length(Model.Low);
      PChunk^ := Len;
      Inc(PChunk);
      CopyMemory(Cast(Model.Low), PChunk, Len);
      Inc(PChunk, Len div 4);
      if (Len = 0) and (Length(Model.Colors) = 8) and Optimize then
      begin
        SetLength(Chunk, Length(Chunk) - 12);
      end
      else
      begin
        Inc(Offset, Len + 4);
        Dec(Words, 1);
        Words^ := Offset;
        Len := Length(Model.Colors);
        CopyMemory(Cast(Model.Colors), PChunk, Len);
        Inc(Offset, Len div 2);
        Inc(Words, 2);
        Words^ := Offset;
        Inc(Offset, Len div 2);
      end;
    end;

    PHeader^ := Length(Header) + Length(Body);
    Inc(PHeader);

    if Model.Vertex <> '' then
    begin
      Body := Body + Intro + Model.Vertex;
      Poly := Poly + Chunk;
    end;
  end;

  if Optimize then
    Poly := #0#0#0#0 + Poly;
  PSize^ := Length(Header) + Length(Body);
  Result := Header + Body + Poly;
end;

class function SGoldModel.GoldModelNew(Vertex, Colors, Poly, PolyTex, PolyLow,
  PolyLowTex: Integer): RGoldModel;
var
  Skip: PInteger;
  Index: Integer;
begin
  Result.Data := StringOfChar(#0, 6);
  Result.Vertex := StringOfChar(#0, Vertex * 4);
  Result.Colors := StringOfChar(#0, Colors * 4 * 2);
  Result.Poly := StringOfChar(#0, Poly * 8 + PolyTex * 20);
  Result.Low := StringOfChar(#0, PolyLow * 8 + PolyLowTex * 20);
  Skip := Cast(Result.Poly);
  Inc(Skip, Poly * 2 + 1);
  for Index := 1 to PolyTex do
  begin
    Skip^ := Integer($80000000);
    Inc(Skip, 5);
  end;
  Skip := Cast(Result.Low);
  Inc(Skip, PolyLow * 2 + 1);
  for Index := 1 to PolyLowTex do
  begin
    Skip^ := Integer($80000000);
    Inc(Skip, 5);
  end;
end;

constructor TGoldenFont.Create(Memory: Pointer);
begin
  inherited Create();
  FMemory := Memory;
  RamCalc();
  UseModel(0, 0, False);
end;

function TGoldenFont.RamCalc(): Integer;
var
  Data: PIntegerArray;
begin
  FPositive := False;
  Data := Pointer(FMemory);
  if Data[5] < 0 then
  begin
    FRamStart := CastChar(@Data[5 + Abs(Data[0])]) - (Data[5] and $1fffff);
    Result := Diff(FMemory, FRamStart) or Integer($80000000);
  end
  else
  begin
    FRamStart := nil;
    Result := 0;
    if Data[0] > 0 then
      FPositive := True;
  end;
end;

function TGoldenFont.GetData(Model: Pointer; Index: Integer): Pointer;
begin
  if FPositive then
    Result := Cast(FMemory, CastInt(FMemory, 56)^ + CastInt(Model, 8 + Index * 4)^)
  else if FRamStart = nil then
    Result := Cast(FMemory, CastInt(FMemory, 16)^ + CastWord(Model, Index * 2)^)
  else
    Result := Cast(Model, CastWord(Model, Index * 2)^);
end;

function TGoldenFont.ModelCount(): Integer;
begin
  Result := PInteger(FMemory)^;
  if Result < 0 then
    Result := -Result;
end;

function TGoldenFont.ModelFrames(Index: Integer): Integer;
begin
  if FPositive then
    Result := CastByte(GetModel(Index))^
  else
    Result := 1;
end;

procedure TGoldenFont.UseModel(Index: Integer; Frame: Integer; LowPoly: Boolean);
begin
  FUsedModel := GetModel(Index);
  FUsedFrame := Frame;
  FUsedLow := LowPoly;
  FVertexCount := 0;
  FColorCount := 0;
  FPolySize := 0;
  FHaveNormal := False;
  FHaveColor := False;
  FHaveTexture := False;
  SetLength(FCacheVertex, 0);
end;

function TGoldenFont.GetModel(Index: Integer): Pointer;
begin
  if FPositive then
  begin
    Index := CastInt(FMemory, 60 + Index * 4)^;
    Result := Cast(FMemory, Index);
    Exit;
  end;
  if FRamStart = nil then
  begin
    Index := CastInt(FMemory, 20 + Index * 4)^;
    Result := Cast(FMemory, Index);
  end
  else
  begin
    Index := CastInt(FMemory, 20 + Index * 4)^ and $1fffff;
    Result := Cast(FRamStart, Index);
  end;
end;

function TGoldenFont.GetVertexCount(Model: Pointer): Integer;
begin
  if FPositive then
    Result := CastByte(Model, 4)^
  else
    Result := CastByte(Model, 1)^;
end;

function TGoldenFont.GetColorCount(Model: Pointer): Integer;
begin
  if FPositive then
    Result := CastByte(Model, 1)^
  else
    Result := CastByte(Model, 0)^
end;

function TGoldenFont.GetVertex(Model: Pointer; Index: Integer): PInteger;
begin
  Result := Cast(Model, 16 + Index * 4);
end;

procedure TGoldenFont.VertexStart(Frame: Integer);
begin
  FVertexCount := GetVertexCount(FUsedModel);
  if FPositive then
  begin
    _at := CastInt(FUsedModel, 36 + FUsedFrame * 8)^;
    _v1 := Diff(GetData(FUsedModel, 6), FMemory);
    _s4 := Diff(GetData(FUsedModel, 1), FMemory);
    _a2 := (_at shr 25) and 1;
    _v0 := (_at and $FFFF) shl 1;
    _at := (_at shr 15) and $3FE;
    _v0 := _v0 + _v1;
    _at := _at + _v0;
    _v1 := 0;
    _a0 := 0;
    _a1 := 0;
  end
  else
    FVertexIndex := GetVertex(FUsedModel, 0);
end;

function TGoldenFont.VertexNext(out Vertex: RVertex): Boolean;
begin
  if FVertexCount = 0 then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  Dec(FVertexCount);
  if FPositive then
  begin
    if _a2 = 0 then
    begin
      _t6 := CastByte(FMemory, _at)^;
      _s0 := CastInt(FMemory, _s4)^;
      Inc(_s4, 4);
      Inc(_at);
      _a2 := _t6 and 1;
      _t7 := _s0 + GlobVertexData[(_t6 shr 1) and 127];
      Dec(_a1, Bit(_t7, 10, True) shl 1);
      Dec(_a0, Bit(_t7, 11, True));
      Inc(_v1, Bit(_t7, 11, True));
      Vertex.X := _v1;
      Vertex.Y := _a0;
      Vertex.Z := -_a1;
      Exit;
    end;
    _t6 := CastWord(FMemory, _v0)^;
    _t6 := Bit(_t6, 16, True);
    Inc(_v0, 2);
    _s0 := CastInt(FMemory, _s4)^;
    Inc(_s4, 4);
    _t7 := _t6 and 2;
    _a2 := _t6 and 1;
    if _t7 = 0 then
    begin
      _t7 := ShiftAr(_t6, 9);
      Inc(_v1, _t7);
      _t7 := _t6 shl 21;
      _t7 := ShiftAr(_t7, 25);
      Dec(_a0, _t7);
      _t7 := _t6 shl 26;
      _t7 := ShiftAr(_t7, 27);
      _t7 := _t7 shl 2;
      Dec(_a1, _t7);
      _t6 := ShiftAr(_s0, 21);
      _t7 := _s0 shl 11;
      _t7 := ShiftAr(_t7, 21);
      _s0 := _s0 shl 22;
      _s0 := ShiftAr(_s0, 21);
      Inc(_v1, _t6);
      Dec(_a0, _t7);
      Dec(_a1, _s0);
      Vertex.X := _v1;
      Vertex.Y := _a0;
      Vertex.Z := -_a1;
      Exit;
    end;
    _t7 := CastWord(FMemory, _v0)^;
    _t7 := Bit(_t7, 16, True);
    Inc(_v0, 2);
    _a1 := _t6 and $FFC;
    _a1 := Bit(_a1, 12, True);
    _a0 := (ShiftAr(_t7 shl 26, 21)) or ((_t6 and $F000) shr 11);
    _v1 := ShiftAr(_t7, 5);
    Vertex.X := _v1;
    Vertex.Y := _a0;
    Vertex.Z := -_a1;
    Exit;
  end;
  DecodeVertex(FVertexIndex^, Vertex.X, Vertex.Y, Vertex.Z);
  Inc(FVertexIndex);
end;

procedure TGoldenFont.ColorStart();
begin
  FColorCount := GetColorCount(FUsedModel);
  FColorIndex := GetColor(FUsedModel, 0, FUsedLow);
end;

function TGoldenFont.ColorNext(out Color: RColor): Boolean;
begin
  if FColorCount = 0 then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  Color.Color := FColorIndex^;
  Inc(FColorIndex);
  Dec(FColorCount);
end;

procedure TGoldenFont.FaceStart();
begin
  FPolyIndex := GetPoly(FUsedModel, FPolySize, FUsedLow);
end;

function TGoldenFont.FaceNext(out QuadVertex: RQuadData): Boolean;
begin
  if FPolySize <= 0 then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  FHaveNormal := DecodePoly(FPolyIndex, QuadVertex[1], QuadVertex[2], QuadVertex
    [3], QuadVertex[4], FColors[1], FColors[2], FColors[3], FColors[4], FNormal,
    FNormalpha);
  if DecodeTexture(FPolyIndex, FTexture.Texture[1].U, FTexture.Texture[1].V,
    FTexture.Texture[2].U, FTexture.Texture[2].V, FTexture.Texture[3].U,
    FTexture.Texture[3].V, FTexture.Texture[4].U, FTexture.Texture[4].V,
    FTexture.Pal.U, FTexture.Pal.V, FTexture.Bpp, FTexture.Alpha) then
  begin
    Dec(FPolySize, 20);
    Inc(FPolyIndex, 5);
    FHaveTexture := True;
  end
  else
  begin
    Dec(FPolySize, 8);
    Inc(FPolyIndex, 2);
    FHaveTexture := False;
  end;
  if FHaveNormal then
    FHaveTexture := False;
  FHaveColor := True;
  if FPositive then
  begin
    FSecondLayer := FNormalpha;
    FNormalpha := False;
  end
  else
  begin
    FSecondLayer := False;
    if not FHaveNormal and FNormalpha then
    begin
      FNormalpha := False;
      QuadVertex[1] := QuadVertex[1] or Integer($80000000);
    end;
  end;
end;

function TGoldenFont.FaceColor(out QuadColor: RQuadData): Boolean;
begin
  if FHaveColor then
  begin
    Result := True;
    QuadColor := FColors;
    FHaveColor := False;
  end
  else
    Result := False;
end;

function TGoldenFont.FaceNormal(out Normal: RPoint): Boolean;
begin
  if FHaveNormal then
  begin
    Result := True;
    DecodeNormals(FNormal, Normal.X, Normal.Y, Normal.Z);
  end
  else
    Result := False;
end;

function TGoldenFont.FaceTexture(out VramTexture: RVramTexture): Boolean;
begin
  if FHaveTexture then
  begin
    Result := True;
    VramTexture := FTexture;
  end
  else
    Result := False;
end;

function TGoldenFont.FaceAlpha(): Boolean;
begin
  Result := FNormalpha;
  if FHaveTexture then
    Result := Result or (FTexture.Alpha <> 0);
end;

function TGoldenFont.FaceLayer(): Boolean;
begin
  Result := FSecondLayer;
end;

procedure TGoldenFont.DecodeVertex(Vertex: Integer; out X, Y, Z: Integer);
begin
  Inits(Vertex);
  Bit(Vertex, 1, False);
  Z := -Bit(Vertex, 11, True);
  Y := Bit(Vertex, 10, True);
  X := Bit(Vertex, 10, True);
end;

function TGoldenFont.EncodeVertex(X, Y, Z: Integer): Integer;
begin
  Result := 0;
  Fit(Result, 10, X);
  Fit(Result, 10, Y);
  Fit(Result, 11, -Z);
  Fit(Result, 1, 0);
end;

function TGoldenFont.GetColor(Model: Pointer; Index: Integer; Low: Boolean): PInteger;
begin
  if FPositive then
  begin
    if Low then
      Result := Cast(GetData(Model, 5), Index * 4)
    else
      Result := Cast(GetData(Model, 3), Index * 4);
  end
  else
  begin
    if Low then
      Result := Cast(GetData(Model, 7), Index * 4)
    else
      Result := Cast(GetData(Model, 5), Index * 4);
  end;
end;

procedure TGoldenFont.DecodeNormals(Normal: Integer; out X, Y, Z: Real);
begin
  Inits(Normal);
  Z := Bit(Normal, 8, True);
  Y := Bit(Normal, 8, True);
  X := Bit(Normal, 8, True);
  if Z < 0 then
    Z := Z / 128
  else
    Z := Z / 127;
  if Y < 0 then
    Y := Y / 128
  else
    Y := Y / 127;
  if X < 0 then
    X := X / 128
  else
    X := X / 127;
  Z := -Z;
end;

function TGoldenFont.EncodeNormals(X, Y, Z: Real): Integer;
begin
  Result := 0;
  Z := -Z;
  if X < 0 then
    X := X * 128
  else
    X := X * 127;
  if Y < 0 then
    Y := Y * 128
  else
    Y := Y * 127;
  if Z < 0 then
    Z := Z * 128
  else
    Z := Z * 127;
  Fit(Result, 8, Round(X));
  Fit(Result, 8, Round(Y));
  Fit(Result, 8, Round(Z));
end;

function TGoldenFont.GetPoly(Model: Pointer; out Size: Integer; Low: Boolean): Pointer;
var
  Poly: Pointer;
begin
  if FPositive then
  begin
    if Low then
      Poly := GetData(Model, 4)
    else
      Poly := GetData(Model, 2);
    Size := PInteger(Poly)^;
    Adv(Poly, 4);
    Result := Poly;
    Exit;
  end;
  if Low then
    Poly := GetData(Model, 6)
  else
    Poly := GetData(Model, 4);
  Size := PInteger(Poly)^;
  Adv(Poly, 4);
  Result := Poly;
end;

function TGoldenFont.GetPolyCount(Model: Pointer; Low: Boolean): Integer;
var
  Size, Next: Integer;
  Poly: Pointer;
begin
  Result := 0;
  Poly := GetPoly(Model, Size, Low);
  while Size > 0 do
  begin
    if (CastByte(Poly, 7)^ and 128) = 0 then
      Next := 8
    else
      Next := 20;
    Adv(Poly, Next);
    Dec(Size, Next);
    Inc(Result);
  end;
end;

function TGoldenFont.GetPolyNext(Poly: Pointer): Pointer;
begin
  Result := Poly;
  if (CastByte(Result, 7)^ and 128) = 0 then
    Adv(Result, 8)
  else
    Adv(Result, 20);
end;

function TGoldenFont.DecodePoly(Poly: Pointer; out V1, V2, V3, V4, C1, C2, C3,
  C4, Normals: Integer; out Alpha: Boolean): Boolean;
var
  Vertex, Color, Mode: Integer;
  Data: PInteger;
begin
  Alpha := False;
  if FPositive then
  begin
    Data := Poly;
    Vertex := Data^;
    Inc(Data);
    Color := Data^;
    V1 := Bit(Vertex, 8, False) + 1;
    V2 := Bit(Vertex, 8, False) + 1;
    V3 := Bit(Vertex, 8, False) + 1;
    V4 := Bit(Vertex, 8, False) + 1;
    Mode := Bit(Color, 3, False);
    if Mode <> 0 then
    begin
      Alpha := True;
    end;
    C1 := Bit(Color, 7, False) + 1;
    C2 := Bit(Color, 7, False) + 1;
    C3 := Bit(Color, 7, False) + 1;
    C4 := Bit(Color, 7, False) + 1;
    Result := False;
    Exit;
  end;
  Data := Poly;
  Vertex := Data^;
  Inc(Data);
  Color := Data^;
  V1 := Bit(Vertex, 7, False) + 1;
  V2 := Bit(Vertex, 7, False) + 1;
  V3 := Bit(Vertex, 7, False) + 1;
  V4 := Bit(Vertex, 7, False) + 1;
  Mode := Bit(Color, 3, False);
  Alpha := (Mode and 1) <> 0;
  if (Mode and 2) = 0 then
  begin
    C1 := Bit(Color, 7, False) + 1;
    C2 := Bit(Color, 7, False) + 1;
    C3 := Bit(Color, 7, False) + 1;
    C4 := Bit(Color, 7, False) + 1;
    Result := False;
  end
  else
  begin
    Bit(Color, 4, False);
    Normals := Bit(Color, 24, False);
    Result := True;
  end;
end;

procedure TGoldenFont.SetPolyFlag(Poly: Pointer; Flag: Integer);
var
  Data: PByte;
begin
  Data := Poly;
  Inc(Data, 4);
  Data^ := (Data^ and not 3) or (Flag and 3);
end;

procedure TGoldenFont.EncodePoly(Poly: Pointer; V1, V2, V3, V4, C1, C2, C3, C4,
  Normals: Integer);
var
  Vertex, Color: Integer;
  Data: PInteger;
begin
  Data := Poly;
  Vertex := 0;
  Fit(Vertex, 7, V4);
  Fit(Vertex, 7, V3);
  Fit(Vertex, 7, V2);
  Fit(Vertex, 7, V1);
  Data^ := Vertex;
  Inc(Data);
  if Normals = 0 then
  begin
    Color := 0;
    Fit(Color, 7, C4);
    Fit(Color, 7, C3);
    Fit(Color, 7, C2);
    Fit(Color, 7, C1);
    Data^ := Data^ or (Color and $7fffffff);
  end
  else
  begin
    Color := 0;
    Fit(Color, 24, Normals);
    Fit(Color, 7, 2);
    Data^ := Data^ or (Color and $7fffffff);
  end;
end;

function TGoldenFont.Triangle(V1, V2, V3, V4: Integer; out A1, A2, A3, B1, B2,
  B3, Q1, Q2, Q3, Q4: Integer; TwoSizeFlag: Boolean): Boolean;
begin
//  begin
//  4 - 2
//  | / |
//  3 - 1
  if V2 = V3 then
  begin
    Result := False;
    A1 := 1;
    A2 := 1;
    A3 := 1;
  end
  else if V1 = V2 then
  begin
//  4 - 2   2 - 4
//  | /       \ |
//  3           3
    Result := True;
    A1 := 2;
    A2 := 4;
    A3 := 3;
    B1 := 3;
    B2 := 4;
    B3 := 2;
    Q1 := 2;
    Q2 := 4;
    Q3 := 3;
    Q4 := 4;
  end
  else if V1 = V3 then
  begin
//  4 - 2
//  | /
//  3
    Result := False;
    A1 := 2;
    A2 := 4;
    A3 := 3;
  end
  else if V1 = V4 then
  begin
//  4 - 2    2 - 1
//  | /        \ |
//  3            3
    Result := True;
    A1 := 2;
    A2 := 4;
    A3 := 3;
    B1 := 3;
    B2 := 1;
    B3 := 2;
    Q1 := 2;
    Q2 := 4;
    Q3 := 3;
    Q4 := 1;
  end
  else if V2 = V4 then
  begin
//  2
//  | \
//  3 - 1
    Result := False;
    A1 := 2;
    A2 := 3;
    A3 := 1;
  end
  else if V3 = V4 then
  begin
//  3 - 2
//    \ |
//      1
    Result := False;
    A1 := 1;
    A2 := 2;
    A3 := 3;
  end
  else
  begin
//  4 - 2       2
//  | /       / |
//  3       3 - 1
    Result := True;
    A1 := 2;
    A2 := 4;
    A3 := 3;
    B1 := 3;
    B2 := 1;
    B3 := 2;
    Q1 := 2;
    Q2 := 4;
    Q3 := 3;
    Q4 := 1;
  end;
  V1 := A1;
  A1 := A3;
  A3 := V1;
  V1 := B1;
  B1 := B3;
  B3 := V1;
  V1 := Q1;
  Q1 := Q4;
  Q4 := V1;
end;

function TGoldenFont.FaceTriangle(Poly: RPolyQuad; out TiangleOne, TiangleTwo,
  Quadro: RPolyQuad): Boolean;
var
  A, B, Q: array[1..4] of Integer;
  Index: Integer;
  TwoSizeFlag: Boolean;
begin
  Result := True;
  if (Poly.Vertex[1] or Integer($80000000) <> 0) then
  begin
    Poly.Vertex[1] := Poly.Vertex[1] and Integer($7fffffff);
    TwoSizeFlag := True;
  end
  else
    TwoSizeFlag := False;
  ZeroMemory(@TiangleOne, SizeOf(TiangleOne));
  ZeroMemory(@TiangleTwo, SizeOf(TiangleTwo));
  if Triangle(Poly.Vertex[1], Poly.Vertex[2], Poly.Vertex[3], Poly.Vertex[4], A[1],
    A[2], A[3], B[1], B[2], B[3], Q[1], Q[2], Q[3], Q[4], TwoSizeFlag) then
  begin
    Result := False;
    for Index := 1 to 3 do
    begin
      TiangleTwo.Vertex[Index] := Poly.Vertex[B[Index]];
      TiangleTwo.Normal[Index] := Poly.Normal[B[Index]];
      TiangleTwo.Color[Index] := Poly.Color[B[Index]];
      TiangleTwo.Texture[Index] := Poly.Texture[B[Index]];
    end;
    for Index := 1 to 4 do
    begin
      Quadro.Vertex[Index] := Poly.Vertex[Q[Index]];
      Quadro.Normal[Index] := Poly.Normal[Q[Index]];
      Quadro.Color[Index] := Poly.Color[Q[Index]];
      Quadro.Texture[Index] := Poly.Texture[Q[Index]];
    end;
  end;
  for Index := 1 to 3 do
  begin
    TiangleOne.Vertex[Index] := Poly.Vertex[A[Index]];
    TiangleOne.Normal[Index] := Poly.Normal[A[Index]];
    TiangleOne.Color[Index] := Poly.Color[A[Index]];
    TiangleOne.Texture[Index] := Poly.Texture[A[Index]];
  end;
end;

function TGoldenFont.DecodeTexture(Poly: Pointer; out X1, Y1, X2, Y2, X3, Y3, X4,
  Y4, Pal_x, Pal_y, Bpp, Alpha: Integer): Boolean;
var
  Data: PWord;
  Sector, X, Y: Integer;
  _x1, _y1, _x2, _y2, _x3, _y3, _x4, _y4: Integer;
begin
  Result := False;
  Data := Poly;
  Inc(Data, 3);
  if (Data^ shr 15) = 0 then
    Exit;
  Result := True;
  Inc(Data);
  _x4 := Data^ and 255;
  _y4 := Data^ shr 8;
  Inc(Data);
  Pal_y := Data^;
  Pal_x := Bit(Pal_y, 6, False) * 16;
  Pal_y := Bit(Pal_y, 10, False);
  Inc(Data);
  _x3 := Data^ and 255;
  _y3 := Data^ shr 8;
  Inc(Data);
  Sector := Data^;
  X := Bit(Sector, 4, False);
  Y := Bit(Sector, 1, False);
  Alpha := Bit(Sector, 2, False);
  Bpp := Bit(Sector, 1, False);
  if Bit(Sector, 1, False) = 1 then
    Bpp := 15
  else if Bpp = 1 then
    Bpp := 8
  else
    Bpp := 4;
  Bit(Sector, 6, False);
  if Bit(Sector, 1, False) = 0 then
    Alpha := 0
  else
    Alpha := Alpha + 1;
  Inc(Data);
  _x2 := Data^ and 255;
  _y2 := Data^ shr 8;
  Inc(Data);
  _x1 := Data^ and 255;
  _y1 := Data^ shr 8;
  Dec(X, 8); //
  Dec(Pal_x, 512); //
  if Bpp = 15 then
    X := X * 64
  else if Bpp = 8 then
    X := X * 128
  else
    X := X * 256;
  Y := Y * 256;
  X1 := _x1 + X;
  Y1 := _y1 + Y;
  X2 := _x2 + X;
  Y2 := _y2 + Y;
  X3 := _x3 + X;
  Y3 := _y3 + Y;
  X4 := _x4 + X;
  Y4 := _y4 + Y;
end;

procedure TGoldenFont.Convert(RamStart: Integer = 0);
var
  Index, Part: Integer;
  Data: PIntegerArray;
  Model: PWordArray;
begin
  if RamStart = 0 then
  begin
    if FRamStart = nil then
      Exit;
    RamStart := RamCalc();
    Data := Pointer(FMemory);
    Dec(Data[4], RamStart);
    for Index := 0 to ModelCount() - 1 do
    begin
      Model := GetModel(Index);
      for Part := 4 to 7 do
        Model[Part] := CastChar(Model) + Model[Part] - Data[4] - FMemory;
      Dec(Data[5 + Index], RamStart);
    end;
    FRamStart := nil;
    RamCalc();
  end
  else
  begin
    Convert(0);
    RamStart := RamStart or Integer($80000000);
    Data := Pointer(FMemory);
    for Index := 0 to ModelCount() - 1 do
    begin
      Model := GetModel(Index);
      for Part := 4 to 7 do
        Model[Part] := Diff(GetData(Model, Part), Model);
      Inc(Data[5 + Index], RamStart);
    end;
    Inc(Data[4], RamStart);
    RamCalc();
  end;
end;

procedure TGoldenFont.Textures(TextureManager: TTextureManager; Model: Integer = -1);
var
  Gold: TGoldenFont;
  QuadVertex: RQuadData;
  VramTexture: RVramTexture;

  procedure Work();
  begin
    Gold.FaceStart();
    while Gold.FaceNext(QuadVertex) do
      if Gold.FaceTexture(VramTexture) then
        TextureManager.Add(VramTexture);
  end;

begin
  Gold := nil;
  try
    Gold := TGoldenFont.Create(FMemory);
    if Model < 0 then
      for Model := 0 to Gold.ModelCount() - 1 do
      begin
        Gold.UseModel(Model, 0, False);
        Work();
      end
    else
    begin
      Gold.UseModel(Model, 0, False);
      Work();
    end;
  finally
    Gold.Free();
  end;
end;

function TGoldenFont.ObjVertex(Obj: TObjModel): Integer;
var
  Vertex: RVertex;
begin
  Result := 0;
  VertexStart(0); // 0??
  while VertexNext(Vertex) do
  begin
    Inc(Result);
    Obj.AddVertex(Vertex);
  end;
end;

function TGoldenFont.ObjColors(Obj: TObjModel): Integer;
var
  Color: RColor;
begin
  Result := 0;
  ColorStart();
  while ColorNext(Color) do
  begin
    Inc(Result);
    Obj.AddTextureColor(Color.Color);
  end;
end;

function TGoldenFont.ObjPoly(Obj: TObjModel; TextureManager: TTextureManager =
  nil; Alpha: Trilean = Anything): Integer;
var
  Quad, Tri1, Tri2: RPolyQuad;
  VramTexture: RVramTexture;
  HavaNormal, HaveTexture: Boolean;
  Normal: RPoint;
  Index: Integer;
  TextureQuad: RTextureQuad;
  Vertex: RQuadData;
begin
  Result := 0;
  FaceStart();
  while FaceNext(Vertex) do
  begin
    Inc(Result);
    ZeroMemory(@Quad, SizeOf(Quad));
    ZeroMemory(@VramTexture, SizeOf(VramTexture));
    Quad.Vertex := Vertex;
    HavaNormal := FaceNormal(Normal);
    HaveTexture := FaceTexture(VramTexture);
    if HaveTexture then
      if not TriCheck(Alpha, VramTexture.Alpha <> 0) then
        Continue;
    if HavaNormal then
    begin
      Obj.AddNormal(Normal);
      for Index := 1 to 4 do
        Quad.Normal[Index] := -1;
    end
    else if TextureManager = nil then
      FaceColor(Quad.Color);
    if HaveTexture and (TextureManager <> nil) then
    begin
      TextureManager.Get(VramTexture, TextureQuad, 0); // 0??
      Obj.PrepareTexture(TextureQuad, Quad);
    end;
    if FaceTriangle(Quad, Tri1, Tri2, Quad) then
      Obj.AddQuad(Tri1, TextureManager = nil)
    else
    begin
      Obj.AddQuad(Tri1, TextureManager = nil);
      Obj.AddQuad(Tri2, TextureManager = nil);
    end;
  end;
end;

procedure TGoldenFont.GmlSavePoly(Gml: TGmlModel; TextureManager:
  TTextureManager = nil; Alpha: Trilean = Anything; Normal: Trilean = Anything;
  Texture: Trilean = Anything; Flag: Integer = 0; Layer: Trilean = Anything);
var
  Quad: RPolyQuad;
  Tria: array[1..2] of RPolyQuad;
  VramTexture: RVramTexture;
  HaveTexture, HaveNormal, HaveAlpha, HaveLayer: Boolean;
  Norm: RPoint;
  Index: Integer;
  TextureQuad: RTextureQuad;
  Count: Integer;
  Texts: array[1..4] of RPoint;
  Alp: Real;
begin
  if Length(FCacheVertex) = 0 then
    PrepareModel(FUsedFrame);
  Gml.PrimitiveBegin(GmlPrimitiveTrianglelist);
  FaceStart();
  while FaceNext(Quad.Vertex) do
  begin
    HaveNormal := FaceNormal(Norm);
    HaveTexture := FaceTexture(VramTexture);
    HaveAlpha := FaceAlpha();
    HaveLayer := FaceLayer();
    if not TriCheck(Alpha, HaveAlpha) or not TriCheck(Normal, HaveNormal) or not
      TriCheck(Texture, HaveTexture) or not TriCheck(Layer, HaveLayer) then
      Continue;
    HaveTexture := HaveTexture and (TextureManager <> nil);
    if HaveAlpha and (Flag <> 1) then
      Alp := 0.7
    else
      Alp := 1;
    if HaveNormal then
      ZeroMemory(@Quad.Normal, SizeOf(Quad.Color))
    else
      FaceColor(Quad.Color);
    if HaveTexture then
    begin
      TextureManager.Get(VramTexture, TextureQuad, Flag);
      for Index := 1 to 4 do
      begin
        Texts[Index].X := TextureQuad.U[Index];
        Texts[Index].Y := TextureQuad.V[Index];
        Quad.Texture[Index] := Index;
      end;
    end;
    Count := 2;
    if FaceTriangle(Quad, Tria[1], Tria[2], Quad) then
      Count := 1;
    repeat
  //    if HaveAlpha then
    {  begin
        for Index := 1 to 3 do
          Gml.VertexColor(FCacheVertex[Tria[Count].Vertex[Index]].X,
            FCacheVertex[Tria[Count].Vertex[Index]].Y, FCacheVertex[Tria[Count].Vertex
            [Index]].Z, Random(-1));
      end else   }
      for Index := 1 to 3 do
        if HaveTexture then
        begin
          if HaveNormal then
            Gml.VertexNormalTexture(FCacheVertex[Tria[Count].Vertex[Index]].X,
              FCacheVertex[Tria[Count].Vertex[Index]].Y, FCacheVertex[Tria[Count].Vertex
              [Index]].Z, Texts[Tria[Count].Texture[Index]].X, Texts[Tria[Count].Texture
              [Index]].Y, Norm.X, Norm.Y, Norm.Z)
          else if Flag = 3 then
            Gml.VertexTextureColor(FCacheVertex[Tria[Count].Vertex[Index]].X,
              FCacheVertex[Tria[Count].Vertex[Index]].Y, FCacheVertex[Tria[Count].Vertex
              [Index]].Z, Texts[Tria[Count].Texture[Index]].X, Texts[Tria[Count].Texture
              [Index]].Y, TVram.SquareColor(FCacheColors[Tria[Count].Color[Index]].Color),
              Alp)
          else
            Gml.VertexTextureColor(FCacheVertex[Tria[Count].Vertex[Index]].X,
              FCacheVertex[Tria[Count].Vertex[Index]].Y, FCacheVertex[Tria[Count].Vertex
              [Index]].Z, Texts[Tria[Count].Texture[Index]].X, Texts[Tria[Count].Texture
              [Index]].Y, FCacheColors[Tria[Count].Color[Index]].Color, Alp)
        end
        else
        begin
          if HaveNormal then
            Gml.VertexNormal(FCacheVertex[Tria[Count].Vertex[Index]].X,
              FCacheVertex[Tria[Count].Vertex[Index]].Y, FCacheVertex[Tria[Count].Vertex
              [Index]].Z, Norm.X, Norm.Y, Norm.Z)
          else
            Gml.VertexColor(FCacheVertex[Tria[Count].Vertex[Index]].X,
              FCacheVertex[Tria[Count].Vertex[Index]].Y, FCacheVertex[Tria[Count].Vertex
              [Index]].Z, FCacheColors[Tria[Count].Color[Index]].Color, Alp);
        end;
      Dec(Count);
    until Count = 0;
  end;
  Gml.PrimitiveEnd();
end;

procedure TGoldenFont.GmlSaveVertex(Gml: TGmlModel; Radius: Real; Steps: Integer);
var
  Index: Integer;
begin
  if Length(FCacheVertex) = 0 then
    PrepareModel(FUsedFrame);
  for Index := 1 to Length(FCacheVertex) - 1 do
    Gml.Ball(FCacheVertex[Index].X, FCacheVertex[Index].Y, FCacheVertex[Index].Z,
      Radius, Steps);
end;

procedure TGoldenFont.GmlSaveEdge(Gml: TGmlModel; Triangulate: Boolean);
var
  Quad, Tri1, Tri2: RPolyQuad;
begin
  if Length(FCacheVertex) = 0 then
    PrepareModel(FUsedFrame);
  Gml.PrimitiveBegin(GmlPrimitiveLinelist);
  FaceStart();
  while FaceNext(Quad.Vertex) do
  begin
    if not FaceTriangle(Quad, Tri1, Tri2, Quad) then
    begin
      if Triangulate then
      begin
        Gml.Vertex(FCacheVertex[Tri2.Vertex[1]].X, FCacheVertex[Tri2.Vertex[1]].Y,
          FCacheVertex[Tri2.Vertex[1]].Z);
        Gml.Vertex(FCacheVertex[Tri2.Vertex[2]].X, FCacheVertex[Tri2.Vertex[2]].Y,
          FCacheVertex[Tri2.Vertex[2]].Z);
        Gml.Vertex(FCacheVertex[Tri2.Vertex[2]].X, FCacheVertex[Tri2.Vertex[2]].Y,
          FCacheVertex[Tri2.Vertex[2]].Z);
        Gml.Vertex(FCacheVertex[Tri2.Vertex[3]].X, FCacheVertex[Tri2.Vertex[3]].Y,
          FCacheVertex[Tri2.Vertex[3]].Z);
        Gml.Vertex(FCacheVertex[Tri2.Vertex[3]].X, FCacheVertex[Tri2.Vertex[3]].Y,
          FCacheVertex[Tri2.Vertex[3]].Z);
        Gml.Vertex(FCacheVertex[Tri2.Vertex[1]].X, FCacheVertex[Tri2.Vertex[1]].Y,
          FCacheVertex[Tri2.Vertex[1]].Z);
      end
      else
      begin
        Gml.Vertex(FCacheVertex[Quad.Vertex[1]].X, FCacheVertex[Quad.Vertex[1]].Y,
          FCacheVertex[Quad.Vertex[1]].Z);
        Gml.Vertex(FCacheVertex[Quad.Vertex[2]].X, FCacheVertex[Quad.Vertex[2]].Y,
          FCacheVertex[Quad.Vertex[2]].Z);
        Gml.Vertex(FCacheVertex[Quad.Vertex[2]].X, FCacheVertex[Quad.Vertex[2]].Y,
          FCacheVertex[Quad.Vertex[2]].Z);
        Gml.Vertex(FCacheVertex[Quad.Vertex[3]].X, FCacheVertex[Quad.Vertex[3]].Y,
          FCacheVertex[Quad.Vertex[3]].Z);
        Gml.Vertex(FCacheVertex[Quad.Vertex[3]].X, FCacheVertex[Quad.Vertex[3]].Y,
          FCacheVertex[Quad.Vertex[3]].Z);
        Gml.Vertex(FCacheVertex[Quad.Vertex[4]].X, FCacheVertex[Quad.Vertex[4]].Y,
          FCacheVertex[Quad.Vertex[4]].Z);
        Gml.Vertex(FCacheVertex[Quad.Vertex[4]].X, FCacheVertex[Quad.Vertex[4]].Y,
          FCacheVertex[Quad.Vertex[4]].Z);
        Gml.Vertex(FCacheVertex[Quad.Vertex[1]].X, FCacheVertex[Quad.Vertex[1]].Y,
          FCacheVertex[Quad.Vertex[1]].Z);
        Continue;
      end;
    end;
    Gml.Vertex(FCacheVertex[Tri1.Vertex[1]].X, FCacheVertex[Tri1.Vertex[1]].Y,
      FCacheVertex[Tri1.Vertex[1]].Z);
    Gml.Vertex(FCacheVertex[Tri1.Vertex[2]].X, FCacheVertex[Tri1.Vertex[2]].Y,
      FCacheVertex[Tri1.Vertex[2]].Z);
    Gml.Vertex(FCacheVertex[Tri1.Vertex[2]].X, FCacheVertex[Tri1.Vertex[2]].Y,
      FCacheVertex[Tri1.Vertex[2]].Z);
    Gml.Vertex(FCacheVertex[Tri1.Vertex[3]].X, FCacheVertex[Tri1.Vertex[3]].Y,
      FCacheVertex[Tri1.Vertex[3]].Z);
    Gml.Vertex(FCacheVertex[Tri1.Vertex[3]].X, FCacheVertex[Tri1.Vertex[3]].Y,
      FCacheVertex[Tri1.Vertex[3]].Z);
    Gml.Vertex(FCacheVertex[Tri1.Vertex[1]].X, FCacheVertex[Tri1.Vertex[1]].Y,
      FCacheVertex[Tri1.Vertex[1]].Z);
  end;
  Gml.PrimitiveEnd();
end;

function TGoldenFont.PrepareModel(Frame: Integer): RBox;
var
  Count: Integer;
  Color: RColor;
  Point: RVertex;
  First: Boolean;
begin
  SetLength(FCacheVertex, 0);
  First := True;
  Count := 0;
  VertexStart(Frame);
  while VertexNext(Point) do
    Inc(Count);
  SetLength(FCacheVertex, Count + 1);
  Count := 0;
  VertexStart(FUsedFrame);
  while VertexNext(Point) do
  begin
    Inc(Count);
    Point.X := Point.X;
    Point.Y := Point.Y;
    Point.Z := Point.Z;
    FCacheVertex[Count] := Point;
    if First then
    begin
      First := False;
      Result.Corner := SModels3D.Vertex2Point(Point);
      Result.Size := SModels3D.Vertex2Point(Point);
    end;
    if Point.X < Result.Corner.X then
      Result.Corner.X := Point.X;
    if Point.Y < Result.Corner.Y then
      Result.Corner.Y := Point.Y;
    if Point.Z < Result.Corner.Z then
      Result.Corner.Z := Point.Z;
    if Point.X > Result.Size.X then
      Result.Size.X := Point.X;
    if Point.Y > Result.Size.Y then
      Result.Size.Y := Point.Y;
    if Point.Z > Result.Size.Z then
      Result.Size.Z := Point.Z;
  end;
  Result.Size.X := Result.Size.X - Result.Corner.X;
  Result.Size.Y := Result.Size.Y - Result.Corner.Y;
  Result.Size.Z := Result.Size.Z - Result.Corner.Z;
  Count := 0;
  ColorStart();
  FillChar(FCacheColors, 256 * 4, 127);
  while ColorNext(Color) do
  begin
    Inc(Count);
    FCacheColors[Count] := Color;
  end;
end;

function TGoldenFont.FaceDataStart(TextureManager: TTextureManager): Boolean;
var
  Quad: RQuadData;
begin
  FaceStart();
  FTiangle := False;
  FManager := TextureManager;
  if FaceNext(Quad) then
  begin
    Result := True;
    FaceStart();
  end
  else
    Result := False;
end;

function TGoldenFont.FaceDataNext(out Vertex: RQuadData; out Color: RQuadData;
  out Normal, TextU, TextV: RPoint; out HaveTexture, HaveNormal, HaveLayer:
  Boolean; out HaveAlpha: Integer): Boolean;
var
  Quad: RPolyQuad;
  Tria1, Tria2: RPolyQuad;
  VramTexture: RVramTexture;
  TextureQuad: RTextureQuad;
  Index: Integer;
begin
  if FTiangle then
  begin
    FTiangle := False;
    Result := True;
    Vertex := FTwoVertex;
    Color := FTwoColor;
    Normal := FTwoNormal;
    TextU := FTwoTextU;
    TextV := FTwoTextV;
    HaveTexture := FTwoHaveTexture;
    HaveNormal := FTwoHaveNormal;
    HaveLayer := FTwoHaveLayer;
    HaveAlpha := FTwoHaveAlpha;
    Exit;
  end;
  Result := False;
  if not FaceNext(Quad.Vertex) then
    Exit;
  Result := True;
  HaveNormal := FaceNormal(Normal);
  HaveTexture := FaceTexture(VramTexture);
  if FNormalpha then
    HaveAlpha := 5
  else
    HaveAlpha := FTexture.Alpha;
  HaveLayer := FaceLayer();
  HaveTexture := HaveTexture and (FManager <> nil);
  FaceColor(Quad.Color);
  if HaveTexture then
  begin
    FManager.Get(VramTexture, TextureQuad, 0);
    for Index := 1 to 4 do
      Quad.Texture[Index] := Index;
  end;
  if not FaceTriangle(Quad, Tria1, Tria2, Quad) then
  begin
    FTiangle := True;
    Vertex := Tria2.Vertex;
    Color := Tria2.Color;
    if HaveTexture then
    begin
      TextU.X := TextureQuad.U[Tria2.Texture[1]];
      TextV.X := TextureQuad.V[Tria2.Texture[1]];
      TextU.Y := TextureQuad.U[Tria2.Texture[2]];
      TextV.Y := TextureQuad.V[Tria2.Texture[2]];
      TextU.Z := TextureQuad.U[Tria2.Texture[3]];
      TextV.Z := TextureQuad.V[Tria2.Texture[3]];
    end;
    FTwoVertex := Vertex;
    FTwoColor := Color;
    FTwoNormal := Normal;
    FTwoTextU := TextU;
    FTwoTextV := TextV;
    FTwoHaveTexture := HaveTexture;
    FTwoHaveNormal := HaveNormal;
    FTwoHaveLayer := HaveLayer;
    FTwoHaveAlpha := HaveAlpha;
  end;
  Vertex := Tria1.Vertex;
  Color := Tria1.Color;
  if HaveTexture then
  begin
    TextU.X := TextureQuad.U[Tria1.Texture[1]];
    TextV.X := TextureQuad.V[Tria1.Texture[1]];
    TextU.Y := TextureQuad.U[Tria1.Texture[2]];
    TextV.Y := TextureQuad.V[Tria1.Texture[2]];
    TextU.Z := TextureQuad.U[Tria1.Texture[3]];
    TextV.Z := TextureQuad.V[Tria1.Texture[3]];
  end;
end;

end.

