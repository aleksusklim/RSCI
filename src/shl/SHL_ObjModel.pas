unit SHL_ObjModel; // SpyroHackingLib is licensed under WTFPL

interface

uses
  SysUtils, SHL_Models3D, SHL_Types;

type
  TObjModel = class(TObject)
    constructor Create();
    destructor Destroy(); override;
  public
    procedure Clear();
    function AddVertex(X, Y, Z: Real; W: Real = 1; V: Real = 0; U: Real = 0):
      Integer; overload;
    function AddVertex(V: RPoint): Integer; overload;
    function AddVertex(V: RVertex): Integer; overload;
    function AddTexture(U, V, W: Real): Integer; overload;
    function AddTexture(T: RPoint): Integer; overload;
    function AddTextureColor(R, G, B: Byte): Integer; overload;
    function AddTextureColor(Color: Integer): Integer; overload;
    function AddNormal(I, J, K: Real): Integer; overload;
    function AddNormal(N: RPoint): Integer; overload;
    function AddFace(V1, V2, V3: Integer; V4: Integer = 0): Integer; overload;
    function AddFaceTexture(V1, T1, V2, T2, V3, T3: Integer; V4: Integer = 0; T4:
      Integer = 0): Integer;
    function AddFaceNormal(V1, N1, V2, N2, V3, N3: Integer; V4: Integer = 0; N4:
      Integer = 0): Integer;
    function AddFaceTextureNormal(V1, T1, N1, V2, T2, N2, V3, T3, N3: Integer;
      V4: Integer = 0; T4: Integer = 0; N4: Integer = 0): Integer;
    function AddFace(Poly: RQuad): Integer; overload;
    function AddQuad(Quad: RPolyQuad; UseColors: Boolean): Integer;
    procedure WriteTo(Filename: string; MaxPrecision: Integer = 15; SixVertex:
      Boolean = False);
    function GetVertex(Index: Integer; out X, Y, Z, W, V, U: Real): Boolean; overload;
    function GetVertex(Index: Integer; out X, Y, Z: Real): Boolean; overload;
    function GetVertex(Index: Integer): RPoint; overload;
    function GetTexture(Index: Integer; out U, V, W: Real): Boolean; overload;
    function GetTexture(Index: Integer): RPoint; overload;
    function GetTextureColor(Index: Integer; out R, G, B: Byte): Boolean; overload;
    function GetTextureColor(Index: Integer; out Color: Integer): Boolean; overload;
    function GetTextureColor(Index: Integer): Integer; overload;
    function GetNormal(Index: Integer; out I, J, K: Real): Boolean; overload;
    function GetNormal(Index: Integer): RPoint; overload;
    function GetFace(Index: Integer; out V1, V2, V3: Integer): Boolean; overload;
    function GetFace(Index: Integer; out V1, V2, V3, V4: Integer): Boolean; overload;
    function GetFaceTexture(Index: Integer; out V1, T1, V2, T2, V3, T3: Integer):
      Boolean; overload;
    function GetFaceTexture(Index: Integer; out V1, T1, V2, T2, V3, T3, V4, T4:
      Integer): Boolean; overload;
    function GetFaceNormal(Index: Integer; out V1, N1, V2, N2, V3, N3: Integer):
      Boolean; overload;
    function GetFaceNormal(Index: Integer; out V1, N1, V2, N2, V3, N3, V4, N4:
      Integer): Boolean; overload;
    function GetFaceTextureNormal(Index: Integer; out V1, T1, N1, V2, T2, N2, V3,
      T3, N3: Integer): Boolean; overload;
    function GetFaceTextureNormal(Index: Integer; out V1, T1, N1, V2, T2, N2, V3,
      T3, N3, V4, T4, N4: Integer): Boolean; overload;
    function GetFace(Index: Integer): RQuad; overload;
    function FaceHave(Index: Integer; out Texture, Normal, Quadro: Boolean): Boolean;
    procedure ReadFrom(Filename: string; DoClear: Boolean = True);
    procedure PrepareTexture(const TextureQuad: RTextureQuad; var Quad: RPolyQuad);
  private
    function NewLength(Size: Integer): Integer;
    function Negative(Value, Count: Integer): Integer;
  private
    Vertex: array of array[0..5] of Real;
    Texture, Normal: array of array[0..2] of Real;
    Face: array of array[0..3, 0..2] of Integer;
    VertexCount, TextureCount, NormalCount, FaceCount: Integer;
  public
    property Vertexes: Integer read VertexCount;
    property Textures: Integer read TextureCount;
    property Normals: Integer read NormalCount;
    property Faces: Integer read FaceCount;
  end;

implementation

uses
  Classes;

constructor TObjModel.Create();
begin
  inherited Create();
  Clear();
end;

destructor TObjModel.Destroy();
begin
  Clear();
  inherited Destroy();
end;

procedure TObjModel.Clear();
begin
  VertexCount := 0;
  TextureCount := 0;
  NormalCount := 0;
  FaceCount := 0;
  SetLength(Vertex, 0);
  SetLength(Normal, 0);
  SetLength(Texture, 0);
  SetLength(Face, 0);
end;

function TObjModel.NewLength(Size: Integer): Integer;
begin
  Result := 8 + Size * 2;
end;

function TObjModel.Negative(Value, Count: Integer): Integer;
begin
  if Value < 0 then
    Result := Count + Value + 1
  else
    Result := Value;
end;

function TObjModel.AddVertex(X, Y, Z: Real; W: Real = 1; V: Real = 0; U: Real =
  0): Integer;
begin
  Inc(VertexCount);
  Result := VertexCount;
  if Length(Vertex) <= Result then
    SetLength(Vertex, NewLength(Result));
  Vertex[Result][0] := X;
  Vertex[Result][1] := Y;
  Vertex[Result][2] := Z;
  Vertex[Result][3] := W;
  Vertex[Result][4] := V;
  Vertex[Result][5] := U;
end;

function TObjModel.AddVertex(V: RPoint): Integer;
begin
  Result := AddVertex(V.X, V.Y, V.Z);
end;

function TObjModel.AddVertex(V: RVertex): Integer;
begin
  Result := AddVertex(V.X, V.Y, V.Z);
end;

function TObjModel.AddTexture(U, V, W: Real): Integer;
begin
  Inc(TextureCount);
  Result := TextureCount;
  if Length(Texture) <= Result then
    SetLength(Texture, NewLength(Result));
  Texture[Result][0] := U;
  Texture[Result][1] := V;
  Texture[Result][2] := W;
end;

function TObjModel.AddTexture(T: RPoint): Integer;
begin
  Result := AddTexture(T.X, T.Y, T.Z);
end;

function TObjModel.AddTextureColor(R, G, B: Byte): Integer;
begin
  Result := AddTexture(R / 255, G / 255, B / 255);
end;

function TObjModel.AddTextureColor(Color: Integer): Integer;
begin
  Result := AddTextureColor(Color, Color shr 8, Color shr 16);
end;

function TObjModel.AddNormal(I, J, K: Real): Integer;
begin
  Inc(NormalCount);
  Result := NormalCount;
  if Length(Normal) <= Result then
    SetLength(Normal, NewLength(Result));
  Normal[Result][0] := I;
  Normal[Result][1] := J;
  Normal[Result][2] := K;
end;

function TObjModel.AddNormal(N: RPoint): Integer;
begin
  Result := AddNormal(N.X, N.Y, N.Z);
end;

function TObjModel.AddFace(V1, V2, V3: Integer; V4: Integer = 0): Integer;
begin
  Result := AddFaceTextureNormal(V1, 0, 0, V2, 0, 0, V3, 0, 0, V4, 0, 0);
end;

function TObjModel.AddFaceTexture(V1, T1, V2, T2, V3, T3: Integer; V4: Integer =
  0; T4: Integer = 0): Integer;
begin
  Result := AddFaceTextureNormal(V1, T1, 0, V2, T2, 0, V3, T3, 0, V4, T4, 0);
end;

function TObjModel.AddFaceNormal(V1, N1, V2, N2, V3, N3: Integer; V4: Integer =
  0; N4: Integer = 0): Integer;
begin
  Result := AddFaceTextureNormal(V1, 0, N1, V2, 0, N2, V3, 0, N3, V4, 0, N4);
end;

function TObjModel.AddFaceTextureNormal(V1, T1, N1, V2, T2, N2, V3, T3, N3:
  Integer; V4: Integer = 0; T4: Integer = 0; N4: Integer = 0): Integer;
begin
  Inc(FaceCount);
  Result := FaceCount;
  if Length(Face) <= Result then
    SetLength(Face, NewLength(Result));
  Face[Result][0, 0] := Negative(V1, VertexCount);
  Face[Result][1, 0] := Negative(V2, VertexCount);
  Face[Result][2, 0] := Negative(V3, VertexCount);
  Face[Result][3, 0] := Negative(V4, VertexCount);
  Face[Result][0, 1] := Negative(T1, TextureCount);
  Face[Result][1, 1] := Negative(T2, TextureCount);
  Face[Result][2, 1] := Negative(T3, TextureCount);
  Face[Result][3, 1] := Negative(T4, TextureCount);
  Face[Result][0, 2] := Negative(N1, NormalCount);
  Face[Result][1, 2] := Negative(N2, NormalCount);
  Face[Result][2, 2] := Negative(N3, NormalCount);
  Face[Result][3, 2] := Negative(N4, NormalCount);
end;

function TObjModel.AddFace(Poly: RQuad): Integer;
begin
  Result := AddFaceTextureNormal(Poly.P1.V, Poly.P1.T, Poly.P1.N, Poly.P2.V,
    Poly.P2.T, Poly.P2.N, Poly.P3.V, Poly.P3.T, Poly.P3.N, Poly.P4.V, Poly.P4.T,
    Poly.P4.N);
end;

function TObjModel.AddQuad(Quad: RPolyQuad; UseColors: Boolean): Integer;
begin
  if UseColors then
    Result := AddFaceTextureNormal(Quad.Vertex[1], Quad.Color[1], Quad.Normal[1],
      Quad.Vertex[2], Quad.Color[2], Quad.Normal[2], Quad.Vertex[3], Quad.Color[3],
      Quad.Normal[3], Quad.Vertex[4], Quad.Color[4], Quad.Normal[4])
  else
    Result := AddFaceTextureNormal(Quad.Vertex[1], Quad.Texture[1], Quad.Normal[1],
      Quad.Vertex[2], Quad.Texture[2], Quad.Normal[2], Quad.Vertex[3], Quad.Texture
      [3], Quad.Normal[3], Quad.Vertex[4], Quad.Texture[4], Quad.Normal[4]);
end;

procedure TObjModel.WriteTo(Filename: string; MaxPrecision: Integer = 15;
  SixVertex: Boolean = False);
var
  Obj: Text;
  Index: Integer;
  Settings: TFormatSettings;
  OldFileMode: Byte;
  Form: string;

  procedure PrintFloats(var Obj: Text; Form: string; Settings: TFormatSettings;
    Mode: string; Six: Boolean; const Data: array of Real);
  begin
    if Six then
      Writeln(Obj, Mode, ' ', FormatFloat(Form, Data[0], Settings), ' ',
        FormatFloat(Form, Data[1], Settings), ' ', FormatFloat(Form, Data[2],
        Settings), ' ', FormatFloat(Form, Data[3], Settings), ' ', FormatFloat(Form,
        Data[4], Settings), ' ', FormatFloat(Form, Data[5], Settings))
    else
      Writeln(Obj, Mode, ' ', FormatFloat(Form, Data[0], Settings), ' ',
        FormatFloat(Form, Data[1], Settings), ' ', FormatFloat(Form, Data[2], Settings));
  end;

  function StrIf(Value: string; Condition: Boolean): string;
  begin
    if Condition then
      Result := Value
    else
      Result := '';
  end;

begin
  Form := '0.' + StringOfChar('#', MaxPrecision);
  ZeroMemory(@Settings, SizeOf(Settings));
  Settings.DecimalSeparator := '.';
  OldFileMode := FileMode;
  FileMode := 2;
  Assign(Obj, Filename);
  Rewrite(Obj);
  for Index := 1 to VertexCount do
    PrintFloats(Obj, Form, Settings, 'v', SixVertex, [Vertex[Index][0], Vertex[Index]
      [1], Vertex[Index][2], Vertex[Index][3], Vertex[Index][4], Vertex[Index][5]]);
  for Index := 1 to TextureCount do
    PrintFloats(Obj, Form, Settings, 'vt', False, [Texture[Index][0], Texture[Index]
      [1], Texture[Index][2]]);
  for Index := 1 to NormalCount do
    PrintFloats(Obj, Form, Settings, 'vn', False, [Normal[Index][0], Normal[Index]
      [1], Normal[Index][2]]);
  for Index := 1 to FaceCount do
    if Face[Index][0, 1] <> 0 then
      if Face[Index][0, 2] <> 0 then
        Writeln(Obj, Format('f %d/%d/%d %d/%d/%d %d/%d/%d' + StrIf(' %d/%d/%d',
          Face[Index][3, 0] <> 0), [Face[Index][0, 0], Face[Index][0, 1], Face[Index]
          [0, 2], Face[Index][1, 0], Face[Index][1, 1], Face[Index][1, 2], Face[Index]
          [2, 0], Face[Index][2, 1], Face[Index][2, 2], Face[Index][3, 0], Face[Index]
          [3, 1], Face[Index][3, 2]], Settings))
      else
        Writeln(Obj, Format('f %d/%d %d/%d %d/%d' + StrIf(' %d/%d', Face[Index][3,
          0] <> 0), [Face[Index][0, 0], Face[Index][0, 1], Face[Index][1, 0],
          Face[Index][1, 1], Face[Index][2, 0], Face[Index][2, 1], Face[Index][3,
          0], Face[Index][3, 1]], Settings))
    else if Face[Index][0, 2] <> 0 then
      Writeln(Obj, Format('f %d//%d %d//%d %d//%d' + StrIf(' %d//%d', Face[Index]
        [3, 0] <> 0), [Face[Index][0, 0], Face[Index][0, 2], Face[Index][1, 0],
        Face[Index][1, 2], Face[Index][2, 0], Face[Index][2, 2], Face[Index][3,
        0], Face[Index][3, 2]], Settings))
    else
      Writeln(Obj, Format('f %d %d %d' + StrIf(' %d', Face[Index][3, 0] <> 0), [Face
        [Index][0, 0], Face[Index][1, 0], Face[Index][2, 0], Face[Index][3, 0]],
        Settings));
  Close(Obj);
  FileMode := OldFileMode;
end;

function TObjModel.GetVertex(Index: Integer; out X, Y, Z, W, V, U: Real): Boolean;
begin
  if (Index < 1) or (Index > VertexCount) then
  begin
    Result := False;
    Exit
  end;
  Result := True;
  X := Vertex[Index][0];
  Y := Vertex[Index][1];
  Z := Vertex[Index][2];
  W := Vertex[Index][3];
  V := Vertex[Index][4];
  U := Vertex[Index][5];
end;

function TObjModel.GetVertex(Index: Integer; out X, Y, Z: Real): Boolean;
var
  W, V, U: Real;
begin
  Result := GetVertex(Index, X, Y, Z, W, V, U);
end;

function TObjModel.GetVertex(Index: Integer): RPoint;
begin
  if not GetVertex(Index, Result.X, Result.Y, Result.Z) then
  begin
    Result.X := 0;
    Result.Y := 0;
    Result.Z := 0;
  end;
end;

function TObjModel.GetTexture(Index: Integer; out U, V, W: Real): Boolean;
begin
  if (Index < 1) or (Index > TextureCount) then
  begin
    Result := False;
    Exit
  end;
  Result := True;
  U := Texture[Index][0];
  V := Texture[Index][1];
  W := Texture[Index][2];
end;

function TObjModel.GetTexture(Index: Integer): RPoint;
begin
  if not GetTexture(Index, Result.X, Result.Y, Result.Z) then
  begin
    Result.X := 0;
    Result.Y := 0;
    Result.Z := 0;
  end;
end;

function TObjModel.GetTextureColor(Index: Integer; out R, G, B: Byte): Boolean;
var
  U, V, W: Real;
begin
  Result := GetTexture(Index, U, V, W);
  R := Round(U * 255);
  G := Round(V * 255);
  B := Round(W * 255);
end;

function TObjModel.GetTextureColor(Index: Integer; out Color: Integer): Boolean;
var
  R, G, B: Byte;
begin
  Result := GetTextureColor(Index, R, G, B);
  Color := R or (G shl 8) or (B shl 16);
end;

function TObjModel.GetTextureColor(Index: Integer): Integer;
begin
  if not GetTextureColor(Index, Result) then
    Result := 0;
end;

function TObjModel.GetNormal(Index: Integer; out I, J, K: Real): Boolean;
begin
  if (Index < 1) or (Index > NormalCount) then
  begin
    Result := False;
    Exit
  end;
  Result := True;
  I := Normal[Index][0];
  J := Normal[Index][1];
  K := Normal[Index][2];
end;

function TObjModel.GetNormal(Index: Integer): RPoint;
begin
  if not GetNormal(Index, Result.X, Result.Y, Result.Z) then
  begin
    Result.X := 0;
    Result.Y := 0;
    Result.Z := 0;
  end;
end;

function TObjModel.GetFace(Index: Integer; out V1, V2, V3: Integer): Boolean;
var
  T1, N1, T2, N2, T3, N3, V4, T4, N4: Integer;
begin
  Result := GetFaceTextureNormal(Index, V1, T1, N1, V2, T2, N2, V3, T3, N3, V4, T4, N4);
end;

function TObjModel.GetFace(Index: Integer; out V1, V2, V3, V4: Integer): Boolean;
var
  T1, N1, T2, N2, T3, N3, T4, N4: Integer;
begin
  Result := GetFaceTextureNormal(Index, V1, T1, N1, V2, T2, N2, V3, T3, N3, V4, T4, N4);
end;

function TObjModel.GetFaceTexture(Index: Integer; out V1, T1, V2, T2, V3, T3:
  Integer): Boolean;
var
  N1, N2, N3, V4, T4, N4: Integer;
begin
  Result := GetFaceTextureNormal(Index, V1, T1, N1, V2, T2, N2, V3, T3, N3, V4, T4, N4);
end;

function TObjModel.GetFaceTexture(Index: Integer; out V1, T1, V2, T2, V3, T3, V4,
  T4: Integer): Boolean;
var
  N1, N2, N3, N4: Integer;
begin
  Result := GetFaceTextureNormal(Index, V1, T1, N1, V2, T2, N2, V3, T3, N3, V4, T4, N4);
end;

function TObjModel.GetFaceNormal(Index: Integer; out V1, N1, V2, N2, V3, N3:
  Integer): Boolean;
var
  T1, T2, T3, V4, N4, T4: Integer;
begin
  Result := GetFaceTextureNormal(Index, V1, T1, N1, V2, T2, N2, V3, T3, N3, V4, T4, N4);
end;

function TObjModel.GetFaceNormal(Index: Integer; out V1, N1, V2, N2, V3, N3, V4,
  N4: Integer): Boolean;
var
  T1, T2, T3, T4: Integer;
begin
  Result := GetFaceTextureNormal(Index, V1, T1, N1, V2, T2, N2, V3, T3, N3, V4, T4, N4);
end;

function TObjModel.GetFaceTextureNormal(Index: Integer; out V1, T1, N1, V2, T2,
  N2, V3, T3, N3: Integer): Boolean;
var
  V4, T4, N4: Integer;
begin
  Result := GetFaceTextureNormal(Index, V1, T1, N1, V2, T2, N2, V3, T3, N3, V4, T4, N4);
end;

function TObjModel.GetFaceTextureNormal(Index: Integer; out V1, T1, N1, V2, T2,
  N2, V3, T3, N3, V4, T4, N4: Integer): Boolean;
begin
  if (Index < 1) or (Index > FaceCount) then
  begin
    Result := False;
    Exit
  end;
  Result := True;
  V1 := Face[Index][0, 0];
  V2 := Face[Index][1, 0];
  V3 := Face[Index][2, 0];
  V4 := Face[Index][3, 0];
  T1 := Face[Index][0, 1];
  T2 := Face[Index][1, 1];
  T3 := Face[Index][2, 1];
  T4 := Face[Index][3, 1];
  N1 := Face[Index][0, 2];
  N2 := Face[Index][1, 2];
  N3 := Face[Index][2, 2];
  N4 := Face[Index][3, 2];
end;

function TObjModel.GetFace(Index: Integer): RQuad;
begin
  if not GetFaceTextureNormal(Index, Result.P1.V, Result.P1.T, Result.P1.N,
    Result.P2.V, Result.P2.T, Result.P2.N, Result.P3.V, Result.P3.T, Result.P3.N,
    Result.P4.V, Result.P4.T, Result.P4.N) then
    FillChar(Result, SizeOf(Result), #0);
end;

function TObjModel.FaceHave(Index: Integer; out Texture, Normal, Quadro: Boolean):
  Boolean;
var
  V1, T1, N1, V2, T2, N2, V3, T3, N3, V4, T4, N4: Integer;
begin
  Result := GetFaceTextureNormal(Index, V1, T1, N1, V2, T2, N2, V3, T3, N3, V4, T4, N4);
  Texture := T1 <> 0;
  Normal := N1 <> 0;
  Quadro := V4 <> 0;
end;

procedure TObjModel.ReadFrom(Filename: string; DoClear: Boolean = True);
var
  OldVertex, OldTexture, OldNormal: Integer;
  Obj: Text;
  OldFileMode: Byte;
  Line: string;
  Cur: PTextChar;
  Loop, Count, Len: Integer;
  Tokens: array[0..7] of PTextChar;
  Got: Boolean;
  Format: TFormatSettings;

  function Take(Index: Integer; Def: Real): Real;
  begin
    if Index < Count then
      Result := StrToFloatDef(TextString(Tokens[Index]), Def, Format)
    else
      Result := Def;
  end;

  function Poly(Index, Token: Integer): Integer;
  var
    Own: string;
    Value, Last: Integer;
  begin
    if Index >= Count then
    begin
      Result := 0;
      Exit;
    end;
    if Token = 1 then
    begin
      Value := OldVertex;
      Last := VertexCount;
    end
    else if Token = 2 then
    begin
      Value := OldTexture;
      Last := TextureCount;
    end
    else if Token = 3 then
    begin
      Value := OldNormal;
      Last := NormalCount;
    end
    else
    begin
      Result := 0;
      Exit;
    end;
    Own := TextString(Tokens[Index]);
    for Index := 1 to Length(Own) do
      if Own[Index] = '/' then
      begin
        Own[Index] := ' ';
        Dec(Token);
      end
      else if Token <> 1 then
        Own[Index] := ' ';
    Result := StrToIntDef(Trim(Own), 0);
    if Result > 0 then
      if Result > Last - Value then
        Result := 0
      else
        Inc(Result, Value)
    else if Result < 0 then
      if Result < Value - Last then
        Result := 0;
  end;

begin
  if DoClear then
    Clear();
  Inits(Tokens);
  OldVertex := VertexCount;
  OldTexture := TextureCount;
  OldNormal := NormalCount;
  OldFileMode := FileMode;
  ZeroMemory(@Format, SizeOf(Format));
  Format.DecimalSeparator := '.';
  FileMode := 0;
  Assign(Obj, Filename);
  Reset(Obj);
  while not Eof(Obj) do
  begin
    Readln(Obj, Line);
    Line := LowerCase(Trim(Line));
    UniqueString(Line);
    Len := Length(Line);
    Cur := Cast(Line);
    Got := False;
    Count := 0;
    for Loop := 1 to Len do
    begin
      if not (Cur^ in ['0'..'9', '.', ',', '-', '+', 'a'..'z', 'A'..'Z', '/']) then
      begin
        Cur^ := #0;
        Got := False;
      end
      else if not Got then
      begin
        if Cur^ = ',' then
          Cur^ := '.';
        Got := True;
        Tokens[Count] := Cur;
        Inc(Count);
        if Count > 7 then
          Break;
      end;
      Inc(Cur);
    end;
    if Count < 2 then
      Continue;
    if StrComp(Tokens[0], Cast('v'#0)) = 0 then
      AddVertex(Take(1, 0), Take(2, 0), Take(3, 0), Take(4, 0), Take(5, 0), Take(6, 0))
    else if StrComp(Tokens[0], Cast('vt'#0)) = 0 then
      AddTexture(Take(1, 0), Take(2, 0), Take(3, 0))
    else if StrComp(Tokens[0], Cast('vn'#0)) = 0 then
      AddNormal(Take(1, 0), Take(2, 0), Take(3, 0))
    else if StrComp(Tokens[0], Cast('f'#0)) = 0 then
    begin
      AddFaceTextureNormal(Poly(1, 1), Poly(1, 2), Poly(1, 3), Poly(2, 1), Poly(2,
        2), Poly(2, 3), Poly(3, 1), Poly(3, 2), Poly(3, 3), Poly(4, 1), Poly(4,
        2), Poly(4, 3));
    end;
  end;
  Close(Obj);
  FileMode := OldFileMode;
end;

procedure TObjModel.PrepareTexture(const TextureQuad: RTextureQuad; var Quad: RPolyQuad);
var
  Index: Integer;
begin
  for Index := 1 to 4 do
    AddTexture(TextureQuad.U[Index], TextureQuad.V[Index], 0);
  for Index := 1 to 4 do
    Quad.Texture[Index] := Index - 5;
end;


{

 Tria:

     3
   / |
 1 - 2

 Quad:

 4 - 3
 | / |
 1 - 2

}

end.

