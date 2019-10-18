unit SHL_VramManager; // SpyroHackingLib is licensed under WTFPL

interface

uses
  Windows, SysUtils, Classes, Graphics, SHL_Bitmaps, SHL_Files, SHL_Types;

type
  TVram = class(TObject)
  private
    FMemory: Pointer;
    FWidth, FHeight, FSize: Integer;
  private
    class function ColorFrom(Pixel: Word; Mult: Boolean): Integer;
    class function ColorTo(Color: Integer; Mult: Boolean): Word;
    class function ColorFilter(Color: Integer; Transparent: Trilean; Square:
      Boolean): Integer;
  private
    function Cell(X, Y: Integer): PWord;
  public
    destructor Destroy(); override;
    class function PaletteToIndexed(Bitmap: TBitmap; const Palette: RPalette): Boolean;
    class function PaletteFromIndexed(Bitmap: TBitmap; out Palette: RPalette;
      Alpha: Boolean): Boolean;
    class function PaletteToTrue(const Palette: RPalette): TBitmap;
    class function PaletteFromTrue(Bitmap: TBitmap; out Palette: RPalette): Boolean;
    class function PaletteAsAlpha(const Palette: RPalette; Black, White: Integer):
      RPalette;
    class function SquareColor(Color: Integer): Integer;
  public
    procedure Close();
    function Open(Width, Height: Integer): Boolean;
    function Black(): Boolean;
    function Assign(From: TVram): Boolean;
    function CopyRect(From: TVram; X, Y: Integer): Boolean;
    function DrawRect(From: TVram; X, Y: Integer): Boolean;
    function Mirror(FlipY: Boolean): Boolean;
    function Transpose(): Boolean;
    function Rotate(CounterClock: Boolean): Boolean;
    function Convert(From: TVram; SrcBpp, DstBpp: Byte): Boolean;
    function GetPalette(X, Y, Colors: Integer; out Palette: RPalette): Boolean;
    function FilterPalette(const Palette: RPalette; Transparent, Square: Boolean):
      RPalette;
    function SetPalette(X, Y, Colors: Integer; const Palette: RPalette): Boolean;
    function RenderTrue(Bitmap, Alpha: TBitmap; Transparent: Trilean = Anything;
      Square: Boolean = False): Boolean;
    function RenderIndex(Bitmap: TBitmap; Result8bit: Boolean; const Palette:
      RPalette): Boolean;
    function LoadTrue(Bitmap, Alpha: TBitmap): Boolean;
    function LoadIndex(Bitmap: TBitmap): Boolean;
    function ReadFrom(Stream: TStream): Boolean; overload;
    function ReadFrom(Memory: Pointer; Size: Integer): Boolean; overload;
    function ReadAs(const Filename: WideString; Offset, Width, Height: Integer): Boolean;
    function SaveTo(Stream: TStream): Boolean;
    function SaveAs(const Filename: WideString; Offset: Integer): Boolean;
    function ExportTo(const Filename: WideString; Bpp: Byte; Palette: PPalette =
      nil): Boolean;
    function ImportFromIndex(const Filename: WideString; Palette: PPalette = nil):
      Boolean;
    function ImportFromTrue(const Filename: WideString; Palette: PPalette = nil): Boolean;
    function ImportFromDib(const BmpName, DibName: WideString): Boolean;
    function RawData(out Size: Integer): Pointer;
  public
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
  end;

implementation

const
  Squared: array[0..179] of byte = ($00, $01, $03, $04, $06, $07, $08, $0A, $0B,
    $0D, $0E, $10, $11, $12, $14, $15, $17, $18, $19, $1B, $1C, $1E, $1F, $21,
    $22, $23, $25, $26, $28, $29, $2A, $2C, $2D, $2F, $30, $31, $33, $34, $36,
    $37, $39, $3A, $3B, $3D, $3E, $40, $41, $42, $44, $45, $47, $48, $4A, $4B,
    $4C, $4E, $4F, $51, $52, $53, $55, $56, $58, $59, $5B, $5C, $5D, $5F, $60,
    $62, $63, $64, $66, $67, $69, $6A, $6B, $6D, $6E, $70, $71, $73, $74, $75,
    $77, $78, $7A, $7B, $7C, $7E, $7F, $81, $82, $84, $85, $86, $88, $89, $8B,
    $8C, $8D, $8F, $90, $92, $93, $94, $96, $97, $99, $9A, $9C, $9D, $9E, $A0,
    $A1, $A3, $A4, $A5, $A7, $A8, $AA, $AB, $AD, $AE, $AF, $B1, $B2, $B4, $B5,
    $B6, $B8, $B9, $BB, $BC, $BE, $BF, $C0, $C2, $C3, $C5, $C6, $C7, $C9, $CA,
    $CC, $CD, $CE, $D0, $D1, $D3, $D4, $D6, $D7, $D8, $DA, $DB, $DD, $DE, $DF,
    $E1, $E2, $E4, $E5, $E7, $E8, $E9, $EB, $EC, $EE, $EF, $F0, $F2, $F3, $F5,
    $F6, $F7, $F9, $FA, $FC, $FD);

function TVram.Cell(X, Y: Integer): PWord;
begin
  Result := Cast(FMemory, (Y * FWidth + X) * 2);
end;

class function TVram.ColorFrom(Pixel: Word; Mult: Boolean): Integer;
var
  Ri, Gi, Bi: Byte;
  Rd, Gd, Bd: Real;
const
  M: Real = 255 / 31;
begin
  if Mult then
  begin
    Bd := Pixel and 31;
    Gd := (Pixel shr 5) and 31;
    Rd := (Pixel shr 10) and 31;
    if (Pixel shr 15) = 0 then
      Result := 0
    else
      Result := Integer($80000000);
    Result := Result or (Round(Rd * M) and 255) or ((Round(Gd * M) and 255) shl
      8) or ((Round(Bd * M) and 255) shl 16);
  end
  else
  begin
    Bi := (Pixel and 31) shl 1;
    Gi := ((Pixel shr 5) and 31) shl 1;
    Ri := ((Pixel shr 10) and 31) shl 1;
    if (Pixel shr 15) <> 0 then
    begin
      Ri := Ri or 128;
      Gi := Gi or 128;
      Bi := Bi or 128;
    end;
    Result := (Ri or (Gi shl 8) or (Bi shl 16));
  end;
end;

class function TVram.ColorTo(Color: Integer; Mult: Boolean): Word;
var
  Ri, Gi, Bi: Byte;
  Rd, Gd, Bd: Real;
const
  M: Real = 31 / 255;
begin
  if Mult then
  begin
    Rd := Color and 255;
    Gd := (Color shr 8) and 255;
    Bd := (Color shr 16) and 255;
    if (Color shr 31) = 0 then
      Result := 0
    else
      Result := $8000;
    Result := Result or (Round(Bd * M) and 31) or ((Round(Gd * M) and 31) shl 5)
      or ((Round(Rd * M) and 31) shl 10);
  end
  else
  begin
    Ri := Color;
    Gi := Color shr 8;
    Bi := Color shr 16;
    if ((Ri shr 7) or (Gi shr 7) or (Bi shr 7)) = 0 then
      Result := 0
    else
      Result := $8000;
    Result := Result or ((Bi shr 1) and 31) or (((Gi shr 1) and 31) shl 5) or (((Ri
      shr 1) and 31) shl 10);
  end;
end;

destructor TVram.Destroy();
begin
  Close();
  inherited Destroy();
end;

procedure TVram.Close();
begin
  if Self = nil then
    Exit;
  if FMemory <> nil then
    FreeMem(FMemory);
  FMemory := nil;
  FWidth := 0;
  FHeight := 0;
  FSize := 0;
end;

function TVram.Open(Width, Height: Integer): Boolean;
var
  Size: Integer;
begin
  if Self = nil then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  if Width <= 0 then
  begin
    Width := 1;
    Result := False;
  end;
  if Height <= 0 then
  begin
    Height := 1;
    Result := False;
  end;
  Size := Width * Height * 2;
  if Size > FSize then
  begin
    Close();
    FSize := Size;
    try
      GetMem(FMemory, FSize);
    except
      FMemory := nil;
      Result := False;
    end;
  end;
  FWidth := Width;
  FHeight := Height;
end;

function TVram.Black(): Boolean;
begin
  Result := False;
  if (Self = nil) or (FMemory = nil) then
    Exit;
  ZeroMemory(FMemory, FWidth * FHeight * 2);
  Result := True;
end;

function TVram.Assign(From: TVram): Boolean;
begin
  if Self = nil then
  begin
    Result := False;
    Exit;
  end;
  if (From = nil) or (From.FMemory = nil) then
  begin
    Close();
    Result := True;
    Exit;
  end;
  Result := Open(From.FWidth, From.FHeight);
  if Result then
    CopyMemory(From.FMemory, FMemory, FWidth * FHeight * 2);
end;

function TVram.CopyRect(From: TVram; X, Y: Integer): Boolean;
var
  Index, Count: Integer;
begin
  Result := False;
  if (Self = nil) or (FMemory = nil) or (From = nil) or (From.FMemory = nil) or
    (X < 0) or (X + FWidth > From.FWidth) or (Y < 0) or (Y + FHeight > From.FHeight) then
    Exit;
  Result := True;
  Count := FWidth * 2;
  for Index := 0 to FHeight - 1 do
    CopyMemory(From.Cell(X, Y + Index), Cell(0, Index), Count);
end;

function TVram.DrawRect(From: TVram; X, Y: Integer): Boolean;
var
  Index, Count: Integer;
begin
  Result := False;
  if (Self = nil) or (FMemory = nil) or (From = nil) or (From.FMemory = nil) or
    (X < 0) or (X + From.FWidth > FWidth) or (Y < 0) or (Y + From.FHeight > FHeight) then
    Exit;
  Result := True;
  Count := From.FWidth * 2;
  for Index := 0 to From.FHeight - 1 do
    CopyMemory(From.Cell(0, Index), Cell(X, Y + Index), Count);
end;

function TVram.Mirror(FlipY: Boolean): Boolean;
var
  X, Y: Integer;
  Left, Right: PWord;
  Temp: Word;
begin
  if (Self = nil) or (FMemory = nil) then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  if FlipY then
  begin
    for Y := 1 to FHeight div 2 do
    begin
      Left := Cell(0, Y - 1);
      Right := Cell(0, FHeight - Y);
      for X := 0 to FWidth - 1 do
      begin
        Temp := Left^;
        Left^ := Right^;
        Right^ := Temp;
        Inc(Left);
        Inc(Right);
      end;
    end;
  end
  else
    for Y := 0 to FHeight - 1 do
    begin
      Left := Cell(0, Y);
      Right := Cell(FWidth - 1, Y);
      for X := 1 to FWidth div 2 do
      begin
        Temp := Left^;
        Left^ := Right^;
        Right^ := Temp;
        Inc(Left);
        Dec(Right);
      end;
    end;
end;

function TVram.Transpose(): Boolean;
var
  X, Y: Integer;
  Temp: Word;
  Mem: Pointer;
  NewWidth, NewSize: Integer;
begin
  if (Self = nil) or (FMemory = nil) then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  if FWidth = FHeight then
    for X := 0 to FWidth - 2 do
      for Y := X + 1 to FHeight - 1 do
      begin
        Temp := Cell(X, Y)^;
        Cell(X, Y)^ := Cell(Y, X)^;
        Cell(Y, X)^ := Temp;
      end
  else
  begin
    NewSize := FWidth * FHeight * 2;
    try
      GetMem(Mem, NewSize);
    except
      Result := False;
      Exit;
    end;
    NewWidth := FHeight;
    for Y := 0 to FHeight - 1 do
      for X := 0 to FWidth - 1 do
        CastWord(Mem, (X * NewWidth + Y) * 2)^ := Cell(X, Y)^;
    FHeight := FWidth;
    FWidth := NewWidth;
    FreeMem(FMemory);
    FMemory := Mem;
    FSize := NewSize;
  end;
end;

function TVram.Rotate(CounterClock: Boolean): Boolean;
begin
  Result := Transpose() and Mirror(CounterClock);
end;

function TVram.Convert(From: TVram; SrcBpp, DstBpp: Byte): Boolean;
var
  Size: Integer;
  Src, Dst: PWord;
begin
  if (Self = nil) or (From = nil) or (From.FMemory = nil) then
  begin
    Result := False;
    Exit;
  end;
  if SrcBpp = 15 then
    SrcBpp := 16;
  if DstBpp = 15 then
    DstBpp := 16;
  Result := True;
  if SrcBpp = DstBpp then
    Result := Assign(From)
  else if SrcBpp = 16 then
  begin
    if DstBpp = 8 then
    begin
      if not Open(From.FWidth * 2, From.FHeight) then
      begin
        Result := False;
        Exit;
      end;
      Src := Pointer(From.FMemory);
      Dst := Pointer(FMemory);
      Size := From.FWidth * From.FHeight;
      while Size <> 0 do
      begin
        Dec(Size);
        Dst^ := Src^ and $ff;
        Inc(Dst);
        Dst^ := Src^ shr 8;
        Inc(Dst);
        Inc(Src);
      end;
    end
    else if DstBpp = 4 then
    begin
      if not Open(From.FWidth * 4, From.FHeight) then
      begin
        Result := False;
        Exit;
      end;
      Src := Pointer(From.FMemory);
      Dst := Pointer(FMemory);
      Size := From.FWidth * From.FHeight;
      while Size <> 0 do
      begin
        Dec(Size);
        Dst^ := Src^ and $f;
        Inc(Dst);
        Dst^ := (Src^ shr 4) and $f;
        Inc(Dst);
        Dst^ := (Src^ shr 8) and $f;
        Inc(Dst);
        Dst^ := (Src^ shr 12) and $f;
        Inc(Dst);
        Inc(Src);
      end;
    end
    else if DstBpp = 1 then
    begin
      if not Open(From.FWidth, From.FHeight) then
      begin
        Result := False;
        Exit;
      end;
      Src := Pointer(From.FMemory);
      Dst := Pointer(FMemory);
      Size := From.FWidth * From.FHeight;
      while Size <> 0 do
      begin
        Dec(Size);
        Dst^ := Src^ shr 15;
        Inc(Src);
        Inc(Dst);
      end;
    end
    else
      Result := False;
  end
  else if SrcBpp = 8 then
  begin
    if DstBpp = 16 then
    begin
      if not Open(From.FWidth div 2, From.FHeight) then
      begin
        Result := False;
        Exit;
      end;
      Src := Pointer(From.FMemory);
      Dst := Pointer(FMemory);
      Size := FWidth * FHeight;
      while Size <> 0 do
      begin
        Dec(Size);
        Dst^ := Src^ and $ff;
        Inc(Src);
        Dst^ := Dst^ or (Src^ shl 8);
        Inc(Src);
        Inc(Dst);
      end;
    end
    else
      Result := False;
  end
  else if SrcBpp = 4 then
  begin
    if DstBpp = 16 then
    begin
      if not Open(From.FWidth div 4, From.FHeight) then
      begin
        Result := False;
        Exit;
      end;
      Src := Pointer(From.FMemory);
      Dst := Pointer(FMemory);
      Size := FWidth * FHeight;
      while Size <> 0 do
      begin
        Dec(Size);
        Dst^ := Src^ and $f;
        Inc(Src);
        Dst^ := Dst^ or (Src^ shl 4);
        Inc(Src);
        Dst^ := Dst^ or (Src^ shl 8);
        Inc(Src);
        Dst^ := Dst^ or (Src^ shl 12);
        Inc(Src);
        Inc(Dst);
      end;
    end
    else
      Result := False;
  end
  else if SrcBpp = 1 then
  begin
    if (DstBpp = 16) and (From.FWidth = FWidth) and (From.FHeight = FHeight) then
    begin
      Src := Pointer(From.FMemory);
      Dst := Pointer(FMemory);
      Size := FWidth * FHeight;
      while Size <> 0 do
      begin
        Dec(Size);
        Dst^ := Integer(Dst^ and $7fff) or Integer(Src^ shl 15);
        Inc(Src);
        Inc(Dst);
      end;
    end
    else
      Result := False;
  end
  else
    Result := False;
end;

function TVram.GetPalette(X, Y, Colors: Integer; out Palette: RPalette): Boolean;
var
  Index: Integer;
  Step, Last: PWord;
begin
  Result := False;
  if (Self = nil) or (FMemory = nil) or (@Palette = nil) or (X < 0) or (Y < 0)
    or (Y >= FHeight) then
  begin
    ZeroMemory(@Palette, SizeOf(Palette));
    Exit;
  end;
  Result := True;
  Step := Cell(X, Y);
  Last := Cell(FWidth - 1, FHeight - 1);
  for Index := 0 to Colors - 1 do
  begin
    if Diff(Step, Last) > 0 then
      Palette[Index] := 0
    else
      Palette[Index] := ColorFrom(Step^, True);
    Inc(Step);
  end;
end;

class function TVram.ColorFilter(Color: Integer; Transparent: Trilean; Square:
  Boolean): Integer;
begin
  if Transparent = Include then
    if (Color shr 31) = 0 then
      Result := 0
    else if (Color and $ffffff) = 0 then
      Result := 0
    else
      Result := Color and $ffffff
  else if Transparent = Exclude then
    if (Color shr 31) = 0 then
      Result := Color
    else if (Color and $ffffff) = 0 then
      Result := $10101
    else
      Result := 0
  else
    Result := Color;
  if Square then
    Result := SquareColor(Result);
end;

function TVram.FilterPalette(const Palette: RPalette; Transparent, Square:
  Boolean): RPalette;
var
  Index: Integer;
begin
  if Transparent then
    for Index := 0 to 255 do
      Result[Index] := ColorFilter(Palette[Index], Include, Square)
  else
    for Index := 0 to 255 do
      Result[Index] := ColorFilter(Palette[Index], Exclude, Square);
end;

function TVram.SetPalette(X, Y, Colors: Integer; const Palette: RPalette): Boolean;
var
  Index: Integer;
  Step, Last: PWord;
begin
  Result := False;
  if (Self = nil) or (FMemory = nil) or (@Palette = nil) or (X < 0) or (Y < 0)
    or (Y >= FHeight) then
    Exit;
  Result := True;
  Step := Cell(X, Y);
  Last := Cell(FWidth - 1, FHeight - 1);
  for Index := 0 to Colors - 1 do
  begin
    if Diff(Step, Last) > 0 then
      Break
    else
      Step^ := ColorTo(Palette[Index], True);
    Inc(Step);
  end;
end;

function TVram.RenderTrue(Bitmap, Alpha: TBitmap; Transparent: Trilean =
  Anything; Square: Boolean = False): Boolean;
var
  X, Y: Integer;
  Bits: PByte;
  Step: PWord;
  Color: Integer;
  Mult: Boolean;
begin
  Result := False;
  if (Self = nil) or (FMemory = nil) or (Bitmap = nil) then
    Exit;
  Mult := True;
  if Alpha = Bitmap then
    Mult := False
  else if Alpha <> nil then
  begin
    if (Alpha.Width <> FWidth) or (Alpha.Height <> FHeight) or (Alpha.PixelFormat
      <> pf24bit) then
    begin
      try
        Alpha.Assign(nil);
        Alpha.PixelFormat := pf24bit;
        SBitmaps.SetSize(Alpha, FWidth, FHeight);
      except
        Result := False;
        Exit;
      end;
    end;
    SBitmaps.BeginUpdate(Alpha);
    Result := True;
    try
      for Y := 0 to FHeight - 1 do
      begin
        Bits := SBitmaps.ScanLine(Alpha, Y);
        Step := Cell(0, Y);
        for X := 0 to FWidth - 1 do
        begin
          Color := Step^ shr 15;
          Inc(Step);
          if Color <> 0 then
            Color := 255;
          Bits^ := Color;
          Inc(Bits);
          Bits^ := Color;
          Inc(Bits);
          Bits^ := Color;
          Inc(Bits);
        end;
      end;
    except
      Result := False;
    end;
    SBitmaps.EndUpdate(Alpha);
    if not Result then
      Exit;
  end;
  if (Bitmap.Width <> FWidth) or (Bitmap.Height <> FHeight) or (Bitmap.PixelFormat
    <> pf24bit) then
  begin
    try
      Bitmap.Assign(nil);
      Bitmap.PixelFormat := pf24bit;
      SBitmaps.SetSize(Bitmap, FWidth, FHeight);
    except
      Result := False;
      Exit;
    end;
  end;
  SBitmaps.BeginUpdate(Bitmap);
  Result := True;
  try
    for Y := 0 to FHeight - 1 do
    begin
      Bits := SBitmaps.ScanLine(Bitmap, Y);
      Step := Cell(0, Y);
      for X := 0 to FWidth - 1 do
      begin
        Color := ColorFilter(ColorFrom(Step^, Mult), Transparent, Square);
        Inc(Step);
        Bits^ := Color;
        Inc(Bits);
        Bits^ := Color shr 8;
        Inc(Bits);
        Bits^ := Color shr 16;
        Inc(Bits);
      end;
    end;
  except
    Result := False;
  end;
  SBitmaps.EndUpdate(Bitmap);
end;

function TVram.RenderIndex(Bitmap: TBitmap; Result8bit: Boolean; const Palette:
  RPalette): Boolean;
var
  X, Y: Integer;
  Color: Integer;
  Bits: PByte;
  Step: PWord;
  BitPal: RPalette;
  Format: TPixelFormat;
begin
  Result := False;
  if (Self = nil) or (FMemory = nil) or (Bitmap = nil) then
    Exit;
  if Result8bit then
    Format := pf8bit
  else
    Format := pf24bit;
  if Bitmap.Empty or (Bitmap.Width <> FWidth) or (Bitmap.Height <> FHeight) or (Bitmap.PixelFormat
    <> Format) then
  begin
    try
      Bitmap.Assign(nil);
      Bitmap.PixelFormat := Format;
      SBitmaps.SetSize(Bitmap, FWidth, FHeight);
    except
      Exit;
    end;
  end;
  SBitmaps.BeginUpdate(Bitmap);
  Result := True;
  try
    if Result8bit then
    begin
      BitPal := Palette;
      SBitmaps.SetPalette(Bitmap, BitPal);
      for Y := 0 to FHeight - 1 do
      begin
        Bits := SBitmaps.ScanLine(Bitmap, Y);
        Step := Cell(0, Y);
        for X := 0 to FWidth - 1 do
        begin
          Bits^ := Step^;
          Inc(Step);
          Inc(Bits);
        end;
      end;
    end
    else
      for Y := 0 to FHeight - 1 do
      begin
        Bits := SBitmaps.ScanLine(Bitmap, Y);
        Step := Cell(0, Y);
        for X := 0 to FWidth - 1 do
        begin
          Color := Palette[Step^ and 255];
          Inc(Step);
          Bits^ := Color;
          Inc(Bits);
          Bits^ := Color shr 8;
          Inc(Bits);
          Bits^ := Color shr 16;
          Inc(Bits);
        end;
      end;
  except
    Result := False;
  end;
  SBitmaps.EndUpdate(Bitmap);
end;

function TVram.LoadTrue(Bitmap, Alpha: TBitmap): Boolean;
var
  X, Y: Integer;
  Step: PWord;
  Bits: PByte;
  Color: Integer;
  Mult: Boolean;
begin
  Result := False;
  if Self = nil then
    Exit;
  if (Bitmap = nil) or (Bitmap.PixelFormat <> pf24bit) or (Bitmap.Width < 1) or
    (Bitmap.Height < 1) then
    Exit;
  if (Alpha <> nil) and ((Alpha.Width <> Bitmap.Width) or (Alpha.Height <>
    Bitmap.Height) or (Alpha.PixelFormat <> pf24bit)) then
    Exit;
  Mult := True;
  if Alpha = Bitmap then
    Mult := False;
  if not Open(Bitmap.Width, Bitmap.Height) then
    Exit;
  if Alpha = nil then
    Black()
  else if Alpha <> Bitmap then
  begin
    SBitmaps.BeginUpdate(Alpha);
    Result := True;
    try
      for Y := 0 to FHeight - 1 do
      begin
        Bits := SBitmaps.ScanLine(Alpha, Y);
        Step := Cell(0, Y);
        for X := 0 to FWidth - 1 do
        begin
          Color := Bits^;
          Inc(Bits);
          Color := Color or Integer(Bits^ shl 8);
          Inc(Bits);
          Color := Color or Integer(Bits^ shl 16);
          Inc(Bits);
          if Color <> 0 then
            Color := $8000;
          Step^ := Color;
          Inc(Step);
        end;
      end;
    except
      Result := False;
    end;
    SBitmaps.EndUpdate(Alpha);
    if not Result then
      Exit;
  end;
  SBitmaps.BeginUpdate(Bitmap);
  Result := True;
  try
    for Y := 0 to FHeight - 1 do
    begin
      Bits := SBitmaps.ScanLine(Bitmap, Y);
      Step := Cell(0, Y);
      for X := 0 to FWidth - 1 do
      begin
        Color := Bits^;
        Inc(Bits);
        Color := Color or Integer(Bits^ shl 8);
        Inc(Bits);
        Color := Color or Integer(Bits^ shl 16);
        Inc(Bits);
        if Mult then
          Step^ := Step^ or (ColorTo(Color, True) and $7fff)
        else
          Step^ := ColorTo(Color, False);
        Inc(Step);
      end;
    end;
  except
    Result := False;
  end;
  SBitmaps.EndUpdate(Bitmap);
end;

function TVram.LoadIndex(Bitmap: TBitmap): Boolean;
var
  X, Y: Integer;
  Step: PWord;
  Bits: PByte;
begin
  Result := False;
  if (Self = nil) or (Bitmap = nil) or (Bitmap.PixelFormat <> pf8bit) or (Bitmap.Width
    < 1) or (Bitmap.Height < 1) then
    Exit;
  if not Open(Bitmap.Width, Bitmap.Height) then
    Exit;
  SBitmaps.BeginUpdate(Bitmap);
  Result := True;
  try
    for Y := 0 to FHeight - 1 do
    begin
      Bits := SBitmaps.ScanLine(Bitmap, Y);
      Step := Cell(0, Y);
      for X := 0 to FWidth - 1 do
      begin
        Step^ := Bits^;
        Inc(Step);
        Inc(Bits);
      end;
    end;
  except
    Result := False;
  end;
  SBitmaps.EndUpdate(Bitmap);
end;

function TVram.ReadFrom(Stream: TStream): Boolean;
var
  Need, Size: Integer;
begin
  Need := FWidth * FHeight * 2;
  Result := False;
  if (Self = nil) or (FMemory = nil) or (Stream = nil) then
    Exit;
  try
    Size := Stream.Read(FMemory^, Need);
    if Size <> Need then
    begin
      ZeroMemory(Cast(FMemory, Size), Need - Size);
      Exit;
    end;
  except
    Exit;
  end;
  Result := True;
end;

function TVram.ReadFrom(Memory: Pointer; Size: Integer): Boolean;
var
  Need: Integer;
begin
  Need := FWidth * FHeight * 2;
  Result := False;
  if (Self = nil) or (FMemory = nil) or (Memory = nil) then
    Exit;
  try
    if Size >= Need then
      CopyMemory(Memory, FMemory, Need)
    else
    begin
      CopyMemory(Memory, FMemory, Size);
      ZeroMemory(Cast(FMemory, Size), Need - Size);
      Exit;
    end;
  except
    Exit;
  end;
  Result := True;
end;

function TVram.ReadAs(const Filename: WideString; Offset, Width, Height: Integer):
  Boolean;
var
  Stream: THandleStream;
begin
  Result := False;
  Stream := nil;
  if (Self = nil) or (Offset < 0) or (Width < 1) or (Height < 1) then
    Exit;
  if not Open(Width, Height) then
    Exit;
  Stream := SFiles.OpenRead(Filename);
  if Stream = nil then
    Exit;
  try
    Stream.Position := Offset;
    Result := ReadFrom(Stream);
  except
  end;
  SFiles.CloseStream(Stream);
end;

function TVram.SaveTo(Stream: TStream): Boolean;
var
  Size: Integer;
begin
  Result := False;
  if (Self = nil) or (FMemory = nil) or (Stream = nil) then
    Exit;
  Size := FWidth * FHeight * 2;
  try
    if Stream.Write(FMemory^, Size) <> Size then
      Exit;
    Result := True;
  except
  end;
end;

function TVram.SaveAs(const Filename: WideString; Offset: Integer): Boolean;
var
  Stream: THandleStream;
begin
  Result := False;
  if (Self = nil) or (FMemory = nil) or (Offset < 0) then
    Exit;
  Stream := SFiles.OpenWrite(Filename);
  try
    if Stream = nil then
    begin
      if Offset <> 0 then
        Abort;
      Stream := SFiles.OpenNew(Filename);
      if Stream = nil then
        Abort;
    end;
    Stream.Position := Offset;
    if (Offset <> 0) and ((Stream.Position + Int64(FWidth) * Int64(FHeight) * 2)
      > Stream.Size) then
      Abort;
    Result := SaveTo(Stream);
  except
  end;
  SFiles.CloseStream(Stream);
end;

function TVram.ExportTo(const Filename: WideString; Bpp: Byte; Palette: PPalette
  = nil): Boolean;
var
  Bitmap: TBitmap;
  Temp: TVram;
begin
  Result := False;
  if (Self = nil) or (FMemory = nil) then
    Exit;
  Bitmap := nil;
  Temp := nil;
  try
    Bitmap := TBitmap.Create();
    if Bpp >= 15 then
      Result := RenderTrue(Bitmap, nil)
    else if Palette <> nil then
    begin
      if Bpp > 1 then
        Result := RenderIndex(Bitmap, True, Palette^)
      else
      begin
        Temp := TVram.Create();
        Result := Temp.Convert(Self, 15, 1) and Temp.RenderIndex(Bitmap, True, Palette^);
      end;
    end;
    if Result then
      Result := SBitmaps.ToFile(Bitmap, Filename);
  except
    Result := False;
  end;
  Temp.Free();
  Bitmap.Free();
end;

function TVram.ImportFromIndex(const Filename: WideString; Palette: PPalette =
  nil): Boolean;
var
  Bitmap: TBitmap;
begin
  Bitmap := SBitmaps.FromFile(Filename);
  SBitmaps.GetPalette(Bitmap, Palette^);
  Result := LoadIndex(Bitmap);
  Bitmap.Free();
end;

function TVram.ImportFromTrue(const Filename: WideString; Palette: PPalette =
  nil): Boolean;
var
  Bitmap: TBitmap;
begin
  Bitmap := SBitmaps.FromFile(Filename);
  SBitmaps.GetPalette(Bitmap, Palette^);
  Result := LoadTrue(Bitmap, Bitmap);
  Bitmap.Free();
end;

function TVram.ImportFromDib(const BmpName, DibName: WideString): Boolean;
var
  Bitmap, Alpha: TBitmap;
begin
  Alpha := SBitmaps.FromFile(DibName);
  if Alpha = nil then
    Result := False
  else
  begin
    Bitmap := SBitmaps.FromFile(BmpName);
    Result := LoadTrue(Bitmap, Alpha);
    Bitmap.Free();
    Alpha.Free();
  end;
end;

class function TVram.PaletteToIndexed(Bitmap: TBitmap; const Palette: RPalette): Boolean;
begin
  Result := False;
  if (Bitmap = nil) or (Bitmap.PixelFormat <> pf8bit) or (Bitmap.Width < 1) or (Bitmap.Height
    < 1) then
    Exit;
  SBitmaps.SetPalette(Bitmap, Palette);
  Result := True;
end;

class function TVram.PaletteFromIndexed(Bitmap: TBitmap; out Palette: RPalette;
  Alpha: Boolean): Boolean;
var
  Index: Integer;
begin
  Result := False;
  if (Bitmap = nil) or (Bitmap.PixelFormat <> pf8bit) or (Bitmap.Width < 1) or (Bitmap.Height
    < 1) then
    Exit;
  Result := True;
  SBitmaps.GetPalette(Bitmap, Palette);
  if Alpha then
    for Index := 0 to 255 do
      if Palette[Index] <> 0 then
        Palette[Index] := Palette[Index] or Integer($80000000);
end;

class function TVram.PaletteToTrue(const Palette: RPalette): TBitmap;
var
  Done: Boolean;
  One, Two: PByte;
  Index, Color: Integer;
begin
  Done := false;
  Result := nil;
  try
    Result := TBitmap.Create();
    Result.PixelFormat := pf24bit;
    SBitmaps.SetSize(Result, 256, 2);
  except
    FreeAndNil(Result);
    Exit;
  end;
  SBitmaps.BeginUpdate(Result);
  try
    One := SBitmaps.Scanline(Result, 0);
    Two := SBitmaps.Scanline(Result, 1);
    for Index := 0 to 255 do
    begin
      Color := Palette[Index];
      One^ := Color;
      Inc(One);
      One^ := Color shr 8;
      Inc(One);
      One^ := Color shr 16;
      Inc(One);
      if (Color shr 31) = 0 then
        Color := 0
      else
        Color := 255;
      Two^ := Color;
      Inc(Two);
      Two^ := Color;
      Inc(Two);
      Two^ := Color;
      Inc(Two);
    end;
    Done := false;
  except
  end;
  SBitmaps.EndUpdate(Result);
  if not Done then
    FreeAndNil(Result);
end;

class function TVram.PaletteFromTrue(Bitmap: TBitmap; out Palette: RPalette): Boolean;
var
  Index, Color: Integer;
  One, Two: PByte;
begin
  Result := False;
  if (Bitmap = nil) or (Bitmap.Width <> 256) or (Bitmap.Height <> 2) or (Bitmap.PixelFormat
    <> pf24bit) then
  begin
    ZeroMemory(@Palette, SizeOf(Palette));
    Exit;
  end;
  SBitmaps.BeginUpdate(Bitmap);
  try
    One := SBitmaps.ScanLine(Bitmap, 0);
    Two := SBitmaps.ScanLine(Bitmap, 1);
    for Index := 0 to 255 do
    begin
      Color := Two^;
      Inc(Two);
      Color := Color or Two^;
      Inc(Two);
      Color := Color or Two^;
      Inc(Two);
      if Color <> 0 then
        Color := Integer($80000000);
      Color := Color or One^;
      Inc(One);
      Color := Color or Integer(One^ shl 8);
      Inc(One);
      Color := Color or Integer(One^ shl 16);
      Inc(One);
      Palette[Index] := Color;
    end;
    Result := True;
  except
  end;
  SBitmaps.EndUpdate(Bitmap);
end;

class function TVram.PaletteAsAlpha(const Palette: RPalette; Black, White:
  Integer): RPalette;
var
  Index: Integer;
begin
  for Index := 0 to 255 do
    if (Palette[index] shr 31) = 0 then
      Result[Index] := Black
    else
      Result[Index] := White;
end;

class function TVram.SquareColor(Color: Integer): Integer;
var
  R, G, B: Byte;
begin
  R := Color and 255;
  G := Color shr 8;
  B := Color shr 16;
  if R > SizeOf(Squared) then
    R := 255
  else
    R := Squared[R];
  if G > SizeOf(Squared) then
    G := 255
  else
    G := Squared[G];
  if B > SizeOf(Squared) then
    B := 255
  else
    B := Squared[B];
  Result := R or (G shl 8) or (B shl 16);
end;

function TVram.RawData(out Size: Integer): Pointer;
begin
  Result := nil;
  if (Self = nil) or (FMemory = nil) or (FWidth <= 0) or (FHeight <= 0) then
    Exit;
  Size := FWidth * FHeight * 2;
  Result := FMemory;
end;

end.

