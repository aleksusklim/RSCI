unit SHL_Models3D; // SpyroHackingLib is licensed under WTFPL

interface

uses
  SysUtils, Classes, SHL_Types;

type
  RPoint = record
    X, Y, Z: Real;
  end;

  RVertex = record
    X, Y, Z: Integer;
  end;

  RColor = record
    case Boolean of
      True:
        (Color: Integer);
      False:
        (R, G, B, A: Byte);
  end;

  RFace = record
    V, C, T, N: Integer;
  end;

  RQuad = record
    P1, P2, P3, P4: RFace;
  end;

  RTexture = record
    U, V: Integer;
  end;

  RTextureQuad = record
    U, V: array[1..4] of Real;
  end;

  RQuadData = array[1..4] of Integer;

  RVramTexture = record
    Texture: array[1..4] of RTexture;
    Pal: RTexture;
    Bpp, Alpha: Integer;
  end;

  RPolyVertex = record
    V, C, T, N: Integer;
  end;

  RPolyQuad = record
    Vertex, Normal, Color, Texture: RQuadData;
  end;

  RBox = record
    Corner, Size: RPoint;
  end;

type
  SModels3D = class(TObject)
  public
    class function Vertex2Point(Vertex: RVertex): RPoint;
  end;

implementation

class function SModels3D.Vertex2Point(Vertex: RVertex): RPoint;
begin
  Result.X := Vertex.X;
  Result.Y := Vertex.Y;
  Result.Z := Vertex.Z;
end;

end.

