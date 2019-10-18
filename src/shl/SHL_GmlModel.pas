unit SHL_GmlModel; // SpyroHackingLib is licensed under WTFPL

interface

uses
  Classes, SysUtils, SHL_Types;

type
  NGmlPrimitive = (GmlPrimitivePointlist = 1, GmlPrimitiveLinelist = 2,
    GmlPrimitiveLinestrip = 3, GmlPrimitiveTrianglelist = 4,
    GmlPrimitiveTrianglestrip = 5, GmlPrimitiveTrianglefan = 6);

type
  TGmlModel = class(TObject)
  private
    FText: Text;
    FName: string;
    FCount: Integer;
  public
    constructor Create(Filename: string);
    destructor Destroy(); override;
  public
    class function Color(r, g, b: Real): Integer;
    procedure Send(Mode: Integer; v1, v2, v3, v4, v5, v6, v7, v8, v9, v10: Real);
    procedure Ellipsoid(x1, y1, z1, x2, y2, z2, hrepeat, vrepeat, steps: Real);
    procedure Ball(x, y, z, r, steps: Real);
    procedure Vertex(x, y, z: Real);
    procedure VertexNormal(x, y, z, nx, ny, nz: Real);
    procedure VertexColor(x, y, z: Real; c: Integer; alpha: Real = 1);
    procedure VertexNormalColor(x, y, z, nx, ny, nz: Real; c: Integer; alpha: Real = 1);
    procedure VertexTexture(x, y, z, xtex, ytex: Real);
    procedure VertexNormalTexture(x, y, z, nx, ny, nz, xtex, ytex: Real);
    procedure VertexTextureColor(x, y, z, xtex, ytex: Real; c: Integer; alpha: Real = 1);
    procedure VertexNormalTextureColor(x, y, z, nx, ny, nz, xtex, ytex: Real; c:
      Integer; alpha: Real = 1);
    procedure PrimitiveBegin(PrimitiveMode: NGmlPrimitive);
    procedure PrimitiveEnd();
    procedure TriaRec(Level: Integer; x1, y1, z1, x2, y2, z2, x3, y3, z3, nx, ny,
      nz: Real);
    procedure Background(Size: Real; Color: Integer);
  end;

implementation

constructor TGmlModel.Create(Filename: string);
begin
  inherited Create();
  FName := Filename;
  Assign(FText, FName);
  Rewrite(FText);
  Writeln(Ftext, 100);
  Writeln(Ftext, '0          ');
  FCount := 0;
end;

destructor TGmlModel.Destroy();
var
  Stream: TFileStream;
  Header: string;
begin
  Close(FText);
  Header := '100'#13#10 + IntToStr(FCount);
  Stream := TFileStream.Create(FName, fmOpenReadWrite or fmShareDenyNone);
  Stream.WriteBuffer(Cast(Header)^, Length(Header));
  Stream.Free();
  inherited Destroy();
end;

class function TGmlModel.Color(r, g, b: Real): Integer;
begin
  Result := Round(Abs(b) * 256 * 256 + Abs(g) * 256 + Abs(r));
end;

procedure TGmlModel.Send(Mode: Integer; v1, v2, v3, v4, v5, v6, v7, v8, v9, v10: Real);
var
  Settings: TFormatSettings;
begin
  ZeroMemory(@Settings, SizeOf(Settings));
  Settings.DecimalSeparator := '.';
  Writeln(FText, Format('%d %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f',
    [Mode, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10], Settings));
  Inc(FCount);
end;

procedure TGmlModel.Ellipsoid(x1, y1, z1, x2, y2, z2, hrepeat, vrepeat, steps: Real);
begin
  Send(13, x1, y1, z1, x2, y2, z2, hrepeat, vrepeat, steps, 0);
end;

procedure TGmlModel.Ball(x, y, z, r, steps: Real);
begin
  Ellipsoid(x - r, y - r, z - r, x + r, y + r, z + r, 1, 1, steps);
end;

procedure TGmlModel.Vertex(x, y, z: Real);
begin
  Send(2, x, y, z, 0, 0, 0, 0, 0, 0, 0);
end;

procedure TGmlModel.VertexNormal(x, y, z, nx, ny, nz: Real);
begin
  Send(6, x, y, z, nx, ny, nz, 0, 0, 0, 0);
end;

procedure TGmlModel.VertexColor(x, y, z: Real; c: Integer; alpha: Real = 1);
begin
  Send(3, x, y, z, c, alpha, 0, 0, 0, 0, 0);
end;

procedure TGmlModel.VertexNormalColor(x, y, z, nx, ny, nz: Real; c: Integer;
  alpha: Real = 1);
begin
  Send(7, x, y, z, nx, ny, nz, c, alpha, 0, 0);
end;

procedure TGmlModel.VertexTexture(x, y, z, xtex, ytex: Real);
begin
  Send(4, x, y, z, xtex, ytex, 0, 0, 0, 0, 0);
end;

procedure TGmlModel.VertexNormalTexture(x, y, z, nx, ny, nz, xtex, ytex: Real);
begin
  Send(4, x, y, z, nx, ny, nz, xtex, ytex, 0, 0);
end;

procedure TGmlModel.VertexTextureColor(x, y, z, xtex, ytex: Real; c: Integer;
  alpha: Real = 1);
begin
  Send(5, x, y, z, xtex, ytex, c, alpha, 0, 0, 0);
end;

procedure TGmlModel.VertexNormalTextureColor(x, y, z, nx, ny, nz, xtex, ytex:
  Real; c: Integer; alpha: Real = 1);
begin
  Send(9, x, y, z, nx, ny, nz, xtex, ytex, c, alpha);
end;

procedure TGmlModel.PrimitiveBegin(PrimitiveMode: NGmlPrimitive);
begin
  Send(0, Integer(PrimitiveMode), 0, 0, 0, 0, 0, 0, 0, 0, 0);
end;

procedure TGmlModel.PrimitiveEnd();
begin
  Send(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
end;

procedure TGmlModel.TriaRec(Level: Integer; x1, y1, z1, x2, y2, z2, x3, y3, z3,
  nx, ny, nz: Real);
const
  nr = 4;
begin
  Inc(Level);
  if Level > 3 then
    Exit;
  VertexColor(x1, y1, z1, Color(nx, ny, nz));
  VertexColor(x1 + nx * nr, y1 + ny * nr, z1 + nz * nr, Color(nx, ny, nz));
  VertexColor(x2, y2, z2, Color(nx, ny, nz));
  VertexColor(x2 + nx * nr, y2 + ny * nr, z2 + nz * nr, Color(nx, ny, nz));
  VertexColor(x3, y3, z3, Color(nx, ny, nz));
  VertexColor(x3 + nx * nr, y3 + ny * nr, z3 + nz * nr, Color(nx, ny, nz));
  TriaRec(Level, (x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2, (x1 + x3) / 2, (y1
    + y3) / 2, (z1 + z3) / 2, (x3 + x2) / 2, (y3 + y2) / 2, (z3 + z2) / 2, nx, ny, nz);
  TriaRec(Level, (x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2, (x1 + x3) / 2, (y1
    + y3) / 2, (z1 + z3) / 2, x1, y1, z1, nx, ny, nz);
  TriaRec(Level, x3, y3, z3, (x1 + x3) / 2, (y1 + y3) / 2, (z1 + z3) / 2, (x3 +
    x2) / 2, (y3 + y2) / 2, (z3 + z2) / 2, nx, ny, nz);
  TriaRec(Level, (x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2, x2, y2, z2, (x3 +
    x2) / 2, (y3 + y2) / 2, (z3 + z2) / 2, nx, ny, nz);
end;

procedure TGmlModel.Background(Size: Real; Color: Integer);
var
  len, hei: Real;
  Vertex: array[1..4, 1..3] of Real;
  i, j: Integer;
const
  Seq: array[1..4, 1..3] of Integer = ((1, 3, 2), (1, 2, 4), (2, 3, 4), (3, 1, 4));
begin
  len := Size * Sqrt(3) / 3;
  hei := Size * Sqrt(6) / 6;
  Vertex[1, 1] := -len * 2;
  Vertex[1, 2] := 0;
  Vertex[1, 3] := -hei;
  Vertex[2, 1] := len;
  Vertex[2, 2] := -Size;
  Vertex[2, 3] := -hei;
  Vertex[3, 1] := len;
  Vertex[3, 2] := Size;
  Vertex[3, 3] := -hei;
  Vertex[4, 1] := 0;
  Vertex[4, 2] := 0;
  Vertex[4, 3] := hei * 3;
  for i := 1 to 4 do
    for j := 1 to 3 do
      VertexColor(Vertex[Seq[i, j], 1], Vertex[Seq[i, j], 2], Vertex[Seq[i, j],
        3], Color);
end;

end.

