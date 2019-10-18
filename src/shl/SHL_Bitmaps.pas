unit SHL_Bitmaps; // SpyroHackingLib is licensed under WTFPL

interface

uses
  Windows, Classes, SysUtils, Graphics, SHL_Models3D, SHL_Files, SHL_Types;

type
  RPalette = array[0..255] of Integer;

  PPalette = ^RPalette;

  SBitmaps = class
    class procedure GetPalette(Bitmap: TBitmap; out Palette: RPalette);
    class procedure SetPalette(Bitmap: TBitmap; const Palette: RPalette);
    class procedure BeginUpdate(Bitmap: TBitmap);
    class procedure EndUpdate(Bitmap: TBitmap);
    class procedure SetSize(Bitmap: TBitmap; Width, Height: Integer);
    class function Scanline(Bitmap: TBitmap; Row: Integer): Pointer;
    class function FromFile(const Filename: WideString): TBitmap; overload;
    class function FromFile(const Filename: TextString): TBitmap; overload;
    class function ToFile(Bitmap: TBitmap; const Filename: WideString): Boolean; overload;
    class function ToFile(Bitmap: TBitmap; const Filename: TextString): Boolean; overload;
    class procedure Clear(Bitmap: TBitmap; Color: TColor);
    class function CopyLight(out Point: RPoint; W, H: Integer; Source: TBitmap;
      X, Y: Integer; Target: TBitmap; TX, TY: Integer): Boolean;
    class function GetLight(out Point: RPoint; W, H: Integer; Source: TBitmap; X,
      Y: Integer): Boolean;
  end;

implementation

class procedure SBitmaps.GetPalette(Bitmap: TBitmap; out Palette: RPalette);
var
  Index: Integer;
begin
  if (Bitmap = nil) or (@Palette = nil) then
    Exit;
  Inits(Palette);
  GetDIBColorTable(Bitmap.Canvas.Handle, 0, 256, Palette);
  for Index := 0 to 255 do
    Palette[Index] := Palette[Index] and $ffffff;
end;

class procedure SBitmaps.SetPalette(Bitmap: TBitmap; const Palette: RPalette);
var
  Index: Integer;
  Temp: RPalette;
begin
  Bitmap.ReleasePalette();
  for Index := 0 to 255 do
    Temp[Index] := Palette[Index] and $ffffff;
  SetDIBColorTable(Bitmap.Canvas.Handle, 0, 256, (@Temp[0])^);
end;

class procedure SBitmaps.BeginUpdate(Bitmap: TBitmap);
begin
{$IFDEF FPC}
  Bitmap.BeginUpdate();
{$ENDIF}
end;

class procedure SBitmaps.EndUpdate(Bitmap: TBitmap);
begin
{$IFDEF FPC}
  Bitmap.EndUpdate();
{$ENDIF}
end;

class procedure SBitmaps.SetSize(Bitmap: TBitmap; Width, Height: Integer);
begin
{$IFDEF FPC}
  Bitmap.SetSize(Width, Height);
{$ELSE}
  Bitmap.Width := Width;
  Bitmap.Height := Height;
{$ENDIF}
end;

class function SBitmaps.Scanline(Bitmap: TBitmap; Row: Integer): Pointer;
begin
  Result := Bitmap.{%H-}ScanLine[Row];
end;

class function SBitmaps.FromFile(const Filename: WideString): TBitmap;
var
  Stream: THandleStream;
begin
  Result := nil;
  Stream := SFiles.OpenRead(Filename);
  if Stream = nil then
    Exit;
  try
    Result := TBitmap.Create();
    Result.LoadFromStream(Stream);
  except
    FreeAndNil(Result);
  end;
  SFiles.CloseStream(Stream);
end;

class function SBitmaps.FromFile(const Filename: TextString): TBitmap;
var
  Stream: THandleStream;
begin
  Result := nil;
  Stream := SFiles.OpenRead(Filename);
  if Stream = nil then
    Exit;
  try
    Result := TBitmap.Create();
    Result.LoadFromStream(Stream);
  except
    FreeAndNil(Result);
  end;
  SFiles.CloseStream(Stream);
end;

class function SBitmaps.ToFile(Bitmap: TBitmap; const Filename: WideString): Boolean;
var
  Stream: THandleStream;
begin
  Result := False;
  if (Bitmap = nil) or (Filename = '') then
    Exit;
  Stream := SFiles.OpenNew(Filename);
  if Stream = nil then
    Exit;
  try
    Bitmap.SaveToStream(Stream);
    Result := True;
  except
  end;
  SFiles.CloseStream(Stream);
end;

class function SBitmaps.ToFile(Bitmap: TBitmap; const Filename: TextString): Boolean;
var
  Stream: THandleStream;
begin
  Result := False;
  if (Bitmap = nil) or (Filename = '') then
    Exit;
  Stream := SFiles.OpenNew(Filename);
  if Stream = nil then
    Exit;
  try
    Bitmap.SaveToStream(Stream);
    Result := True;
  except
  end;
  SFiles.CloseStream(Stream);
end;

class procedure SBitmaps.Clear(Bitmap: TBitmap; Color: TColor);
begin
  if Bitmap <> nil then
    with Bitmap.Canvas do
    begin
      Brush.Style := bsSolid;
      Brush.Color := Color;
      Pen.Style := psClear;
      FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    end;
end;

class function SBitmaps.CopyLight(out Point: RPoint; W, H: Integer; Source:
  TBitmap; X, Y: Integer; Target: TBitmap; TX, TY: Integer): Boolean;
var
  S, T: PByte;
  R, G, B: Byte;
  U, V: Integer;
begin
  if (Source.PixelFormat <> pf24bit) or (Target.PixelFormat <> pf24bit) or (X <
    0) or (Y < 0) or (W < 0) or (H < 0) or (TX < 0) or (TY < 0) or (X + W >
    Source.Width) or (Y + H > Source.Height) or (TX + W > Target.Width) or (TY +
    H > Target.Height) then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  R := 0;
  G := 0;
  B := 0;
  for U := 0 to H - 1 do
  begin
    S := Source.ScanLine[U + Y];
    T := Target.ScanLine[U + TY];
    Inc(S, 3 * X);
    Inc(T, 3 * TX);
    for V := 0 to W - 1 do
    begin
      if S^ > R then
        R := S^;
      T^ := S^;
      Inc(S);
      Inc(T);
      if S^ > G then
        G := S^;
      T^ := S^;
      Inc(S);
      Inc(T);
      if S^ > B then
        B := S^;
      T^ := S^;
      Inc(S);
      Inc(T);
    end;
  end;
  if R > 0 then
    Point.X := 255 / R
  else
    Point.X := 0;
  if G > 0 then
    Point.Y := 255 / G
  else
    Point.Y := 0;
  if B > 0 then
    Point.Z := 255 / B
  else
    Point.Z := 0;

  for U := 0 to H - 1 do
  begin
    T := Target.ScanLine[U + TY];
    Inc(T, 3 * TX);
    for V := 0 to W - 1 do
    begin
      T^ := Round(T^ * Point.X);
      Inc(T);
      T^ := Round(T^ * Point.Y);
      Inc(T);
      T^ := Round(T^ * Point.Z);
      Inc(T);
    end;
  end;
  Point.X := 2 * R / 255;
  Point.Y := 2 * G / 255;
  Point.Z := 2 * B / 255;
end;

class function SBitmaps.GetLight(out Point: RPoint; W, H: Integer; Source:
  TBitmap; X, Y: Integer): Boolean;
var
  S: PByte;
  R, G, B: Byte;
  U, V: Integer;
begin
  if (Source.PixelFormat <> pf24bit) or (X < 0) or (Y < 0) or (W < 0) or (H < 0)
    or (X + W > Source.Width) or (Y + H > Source.Height) then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  R := 0;
  G := 0;
  B := 0;
  for U := 0 to H - 1 do
  begin
    S := Source.ScanLine[U + Y];
    Inc(S, 3 * X);
    for V := 0 to W - 1 do
    begin
      if S^ > R then
        R := S^;
      Inc(S);
      if S^ > G then
        G := S^;
      Inc(S);
      if S^ > B then
        B := S^;
      Inc(S);
    end;
  end;
  Point.X := 2 * R / 255;
  Point.Y := 2 * G / 255;
  Point.Z := 2 * B / 255;
end;

end.

