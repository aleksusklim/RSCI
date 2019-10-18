unit SHL_TextureManager; // SpyroHackingLib is licensed under WTFPL

interface

uses
  Math, Windows, SysUtils, Classes, Graphics, SHL_VramManager, SHL_Bitmaps,
  SHL_Models3D, SHL_Types;

type
  RTextureBlock = record
    Cmp: record
      Pal_x, Pal_y, Bpp, Flag: Word;
    end;
    X, Y, W, H, U, V: Integer;
  end;

  RTextureTile = record
    X, Y, W, H: Integer;
    P: RPoint;
  end;

type
  TTextureManager = class(TObject)
  private
    FRendered: Boolean;
    FBlocks: array of RTextureBlock;
    FVrams: array of RVramTexture;
    FRects: array of RTextureTile;
    FBlockCount, FVramsCount, FMode: Integer;
    FWidth, FHeight: Integer;
//    FCombined: Boolean;
  private
    class procedure MinMax(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer; out X, Y, W,
      H: Integer);
    function Find(const VramTexture: RVramTexture; Flag: Integer): Integer;
  public
    constructor Create();
    destructor Destroy(); override;
    class function Mult(Mult: RPoint; Color: RColor): RColor;
  public
    procedure Clear();
//    procedure SetCombined(Combined: Boolean);
    procedure Add(const VramTexture: RVramTexture);
    procedure Render(Vram: TVram; Bitmap: TBitmap);
    function AutoRender(const VramFrom, BitmapTo: WideString; Offset: Integer =
      0): Boolean;
    function BlockCount(): Integer;
    procedure Get(const VramTexture: RVramTexture; var TextureQuad: RTextureQuad;
      Flag: Integer);
    procedure SetMode(Mode: Integer);
  end;

implementation

constructor TTextureManager.Create();
begin
  inherited Create();
  Clear();
end;

destructor TTextureManager.Destroy();
begin
  Clear();
  inherited Destroy();
end;

procedure TTextureManager.Clear();
begin
  SetLength(FBlocks, 0);
  SetLength(FVrams, 0);
  SetLength(FRects, 0);
  FBlockCount := 0;
  FVramsCount := 0;
  FRendered := False;
end;

class procedure TTextureManager.MinMax(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer;
  out X, Y, W, H: Integer);
var
  MinX, MinY, MaxX, MaxY: Integer;
begin
  MinX := X1;
  MinY := Y1;
  MaxX := MinX;
  MaxY := MinY;
  if X2 < MinX then
    MinX := X2;
  if X3 < MinX then
    MinX := X3;
  if X4 < MinX then
    MinX := X4;
  if X2 > MaxX then
    MaxX := X2;
  if X3 > MaxX then
    MaxX := X3;
  if X4 > MaxX then
    MaxX := X4;
  if Y2 < MinY then
    MinY := Y2;
  if Y3 < MinY then
    MinY := Y3;
  if Y4 < MinY then
    MinY := Y4;
  if Y2 > MaxY then
    MaxY := Y2;
  if Y3 > MaxY then
    MaxY := Y3;
  if Y4 > MaxY then
    MaxY := Y4;
  X := MinX;
  Y := MinY;
  W := MaxX + 1 - MinX;
  H := MaxY + 1 - MinY;
end;

function TTextureManager.Find(const VramTexture: RVramTexture; Flag: Integer): Integer;
var
  Block: RTextureBlock;
  Index: Integer;
begin
  Result := -1;
  {
  if not FRendered then
  begin
    if FVramsCount >= Length(FVrams) then
      SetLength(FVrams, (FVramsCount + 8) * 2);
    FVrams[FVramsCount] := VramTexture;
    Inc(FVramsCount);
  end;
  }
  Block.Cmp.Bpp := VramTexture.Bpp;
  Block.Cmp.Flag := Flag;
  if VramTexture.Bpp > 8 then
  begin
    Block.Cmp.Pal_x := 0;
    Block.Cmp.Pal_y := 0;
  end
  else
  begin
    Block.Cmp.Pal_x := VramTexture.Pal.U;
    Block.Cmp.Pal_y := VramTexture.Pal.V;
  end;
  Block.U := 0;
  Block.V := 0;
  MinMax(VramTexture.Texture[1].U, VramTexture.Texture[1].V, VramTexture.Texture
    [2].U, VramTexture.Texture[2].V, VramTexture.Texture[3].U, VramTexture.Texture
    [3].V, VramTexture.Texture[4].U, VramTexture.Texture[4].V, Block.X, Block.Y,
    Block.W, Block.H);
  for Index := 0 to FBlockCount - 1 do
    if CompareMem(@Block, @FBlocks[Index], SizeOf(Block.Cmp)) then
    begin
      if not ((FBlocks[Index].X + FBlocks[Index].W < Block.X) or (Block.X +
        Block.W < FBlocks[Index].X) or (FBlocks[Index].Y + FBlocks[Index].H <
        Block.Y) or (Block.Y + Block.H < FBlocks[Index].Y)) then
      begin
        MinMax(FBlocks[Index].X, FBlocks[Index].Y, FBlocks[Index].X + FBlocks[Index].W
          - 1, FBlocks[Index].Y + FBlocks[Index].H - 1, Block.X, Block.Y, Block.X
          + Block.W - 1, Block.Y + Block.H - 1, FBlocks[Index].X, FBlocks[Index].Y,
          FBlocks[Index].W, FBlocks[Index].H);
        Result := Index;
        Exit;
      end;
    end;
  if FRendered then
    Exit;
  if FBlockCount >= Length(FBlocks) then
    SetLength(FBlocks, (FBlockCount + 8) * 2);
  FBlocks[FBlockCount] := Block;
  Result := FBlockCount;
  Inc(FBlockCount);
end;

procedure TTextureManager.Add(const VramTexture: RVramTexture);
var
  Flag: Integer;
begin
  if (VramTexture.Alpha = 0) or ((FMode and 0) = 0) then
    Find(VramTexture, 0)
  else
    for Flag := 0 to 3 do
      Find(VramTexture, Flag);
end;

procedure TTextureManager.Render(Vram: TVram; Bitmap: TBitmap);
var
  Width, Height, Index, Start, Left, Max, Col: Integer;
  V8, V4, Part, Target: TVram;
  Block: RTextureBlock;
  Img: TBitmap;
  Palette: RPalette;
  Diff: Boolean;
begin
  if FRendered then
    Exit;
  FRendered := True;
  SetLength(FRects, 0);
  Start := 0;
  Max := 0;
  Diff := False;
  while Start < FBlockCount do
  begin
    Block := FBlocks[Start];
    if Block.W > Max then
      Max := Block.W;
    for Index := Start + 1 to FBlockCount - 1 do
      if CompareMem(@Block, @FBlocks[Index], SizeOf(Block.Cmp)) then
      begin
        if not ((FBlocks[Index].X + FBlocks[Index].W < Block.X) or (Block.X +
          Block.W < FBlocks[Index].X) or (FBlocks[Index].Y + FBlocks[Index].H <
          Block.Y) or (Block.Y + Block.H < FBlocks[Index].Y)) then
        begin
          MinMax(FBlocks[Index].X, FBlocks[Index].Y, FBlocks[Index].X + FBlocks[Index].W
            - 1, FBlocks[Index].Y + FBlocks[Index].H - 1, Block.X, Block.Y,
            Block.X + Block.W - 1, Block.Y + Block.H - 1, FBlocks[Index].X,
            FBlocks[Index].Y, FBlocks[Index].W, FBlocks[Index].H);
          FBlocks[Start].Cmp.Bpp := 0;
          Dec(Start);
          Diff := True;
          Break;
        end;
      end;
    Inc(Start);
  end;
  if Diff then
  begin
    Start := 0;
    for Index := 0 to FBlockCount - 1 do
      if FBlocks[Index].Cmp.Bpp <> 0 then
      begin
        FBlocks[Start] := FBlocks[Index];
        Inc(Start);
      end;
    FBlockCount := Start;
  end;

  Width := 2;
  while Width < Max do
    Width := Width shl 1;
  Width := Width shr 1;

  repeat
    Width := Width shl 1;
    Index := 0;
    Left := 0;
    Height := 0;
    Max := 0;
    while Index < FBlockCount do
    begin
      FBlocks[Index].U := Left;
      FBlocks[Index].V := Height;
      Inc(Left, FBlocks[Index].W);
      if FBlocks[Index].H > Max then
        Max := FBlocks[Index].H;
      if Left > Width then
      begin
        Inc(Height, Max);
        FBlocks[Index].U := 0;
        FBlocks[Index].V := Height;
        Max := FBlocks[Index].H;
        Left := FBlocks[Index].W;
        if Height > Width then
          Break;
      end;
      Inc(Index);
    end;
  until Height + Max < Width;
  Inc(Height, Max + 1);

  Max := 1;
  while Max < Height do
    Max := Max shl 1;
  Height := Max;

  FWidth := Width;
  FHeight := Height;

  {
  Count := 0;
  SetLength(FRects, Length(FVrams));
  for Index := 0 to FVramsCount - 1 do
  begin
    Block := FBlocks[Add(FVrams[Index])];
    MinMax(Block.U + FVrams[Index].Texture[4].U - Block.X, Block.V + FVrams[Index].Texture
      [4].V - Block.Y, Block.U + FVrams[Index].Texture[1].U - Block.X, Block.V +
      FVrams[Index].Texture[1].V - Block.Y, Block.U + FVrams[Index].Texture[2].U
      - Block.X, Block.V + FVrams[Index].Texture[2].V - Block.Y, Block.U +
      FVrams[Index].Texture[3].U - Block.X, Block.V + FVrams[Index].Texture[3].V
      - Block.Y, FRects[Count].X, FRects[Count].Y, FRects[Count].W, FRects[Count].H);
    Start := Count - 1;
    while Start >= 0 do
    begin
      if not ((FRects[Start].X + FRects[Start].W <= FRects[Count].X) or (FRects[Count].X
        + FRects[Count].W <= FRects[Start].X) or (FRects[Start].Y + FRects[Start].H
        <= FRects[Count].Y) or (FRects[Count].Y + FRects[Count].H <= FRects[Start].Y))
        then
      begin
        MinMax(FRects[Start].X, FRects[Start].Y, FRects[Start].X + FRects[Start].W
          - 1, FRects[Start].Y + FRects[Start].H - 1, FRects[Count].X, FRects[Count].Y,
          FRects[Count].X + FRects[Count].W - 1, FRects[Count].Y + FRects[Count].H
          - 1, FRects[Start].X, FRects[Start].Y, FRects[Start].W, FRects[Start].H);
        Dec(Count);
        Start := Count;
      end;
      Dec(Start);
    end;
    Inc(Count);
  end;
  SetLength(FRects, Count);
  }

  if Bitmap = nil then
    Exit;

  {
  if Vram = nil then
  begin
    for Index := 0 to Count - 1 do
      SBitmaps.GetLight(FRects[Index].P, FRects[Index].W, FRects[Index].H,
        Bitmap, FRects[Index].X, FRects[Index].Y);
    Exit;
  end;
  }

  if Bitmap.Empty then
    Bitmap.PixelFormat := pf24bit;
  SBitmaps.SetSize(Bitmap, FWidth, Height);
  SBitmaps.Clear(Bitmap, clBlack);

  V4 := nil;
  V8 := nil;
  Part := TVram.Create();
  Img := TBitmap.Create();
  Img.PixelFormat := pf24bit;

  for Index := 0 to FBlockCount - 1 do
  begin
    Block := FBlocks[Index];
    Target := Vram;
    Col := 0;
    if Block.Cmp.Bpp = 4 then
    begin
      if V4 = nil then
      begin
        V4 := TVram.Create();
        V4.Convert(Vram, 15, 4);
      end;
      Target := V4;
      Col := 16;
    end;

    if Block.Cmp.Bpp = 8 then
    begin
      if V8 = nil then
      begin
        V8 := TVram.Create();
        V8.Convert(Vram, 15, 8);
      end;
      Target := V8;
      Col := 256;
    end;

    Part.Open(Block.W, Block.H);
    Part.CopyRect(Target, Block.X, Block.Y);
    if Block.Cmp.Bpp > 8 then
    begin
      case Block.Cmp.Flag of
        0:
          Part.RenderTrue(Img, nil, Anything, False);
        1:
          Part.RenderTrue(Img, nil, Exclude, False);
        2:
          Part.RenderTrue(Img, nil, Include, False);
        3:
          Part.RenderTrue(Img, nil, Include, True);
      end;
    end
    else
    begin
      Vram.GetPalette(Block.Cmp.Pal_x, Block.Cmp.Pal_y, Col, Palette);
      case Block.Cmp.Flag of
        1:
          Palette := Vram.FilterPalette(Palette, False, False);
        2:
          Palette := Vram.FilterPalette(Palette, True, False);
        3:
          Palette := Vram.FilterPalette(Palette, True, True);
      end;
      Part.RenderIndex(Img, False, Palette);
    end;
    Bitmap.Canvas.Draw(Block.U, Block.V, Img);
  end;

  {
  for Index := 0 to Count - 1 do
    SBitmaps.CopyLight(FRects[Index].P, FRects[Index].W, FRects[Index].H, Bitmap,
      FRects[Index].X, FRects[Index].Y, Bitmap, FRects[Index].X + Width, FRects[Index].Y);
  }

  Img.Free();
  Part.Free();
  V8.Free();
  V4.Free();
end;

function TTextureManager.AutoRender(const VramFrom, BitmapTo: WideString; Offset:
  Integer = 0): Boolean;
var
  Vram: TVram;
  Bitmap: TBitmap;
begin
  Result := False;
  Vram := nil;
  Bitmap := nil;
  try
    Vram := TVram.Create();
    Assure(Vram.ReadAs(VramFrom, Offset, 512, 512));
    Bitmap := TBitmap.Create();
    Render(Vram, Bitmap);
    Assure(SBitmaps.ToFile(Bitmap, BitmapTo));
  except
  end;
  Vram.Free();
  Bitmap.Free();
end;

function TTextureManager.BlockCount(): Integer;
begin
  Result := FBlockCount;
end;

procedure TTextureManager.Get(const VramTexture: RVramTexture; var TextureQuad:
  RTextureQuad; Flag: Integer);
var
  Block: RTextureBlock;
  Index: Integer;
begin
  if not FRendered then
    Exit;
  if (FMode and 0) = 0 then
    Flag := 0;
  Index := Find(VramTexture, Flag);
  if (Index < 0) or (Index >= FBlockCount) or (FWidth < 1) or (FHeight < 1) then
    Exit;
  Block := FBlocks[Index];
  for Index := 1 to 4 do
  begin
    TextureQuad.U[Index] := (Block.U + VramTexture.Texture[Index].U - Block.X +
      0.5) / FWidth;
    TextureQuad.V[Index] := (Block.V + VramTexture.Texture[Index].V - Block.Y +
      0.5) / FHeight;
  end;
end;

class function TTextureManager.Mult(Mult: RPoint; Color: RColor): RColor;
begin
  Result.A := Color.A;
  Result.R := Min(255, Round(Color.R * Mult.Z));
  Result.G := Min(255, Round(Color.G * Mult.Y));
  Result.B := Min(255, Round(Color.B * Mult.X));
end;

procedure TTextureManager.SetMode(Mode: Integer);
begin
  FMode := Mode;
end;

end.

