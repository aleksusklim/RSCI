unit SHL_EccEdc; // SpyroHackingLib is licensed under WTFPL

interface

uses
  Windows, SysUtils, Classes, SHL_Types;

type
  TEccEdc = class(TObject)
  private
    ecc_f_lut, ecc_b_lut: array[0..255] of Byte;
    edc_lut: array[0..255] of Integer;
  private
    procedure eccedc_init();
    function ecc_writepq(address, data: Pointer; size, major_count, minor_count,
      major_mult, minor_inc: Integer; ecc: Pointer; compare: Boolean): Boolean;
    function ecc_writesector(address, data, ecc: Pointer; compare: Boolean): Boolean;
  public
    constructor Create;
  public
    function edc_compute(OldEdc: Integer; Data: Pointer; Count: Integer): Integer;
    procedure ecc_edc(Sector: Pointer; Mode: Byte);
    function check(Sector: Pointer): Byte;
  end;

implementation

procedure TEccEdc.eccedc_init();
var
  I, J, X: Integer;
begin
  for i := 0 to 255 do
  begin
    X := I;
    if (I and 128) <> 0 then
      J := (I shl 1) xor 285
    else
      J := I shl 1;
    ecc_b_lut[I xor J] := I;
    ecc_f_lut[I] := J;
    for j := 0 to 7 do
      if X and 1 <> 0 then
        X := Integer(X shr 1) xor Integer(3623976961)
      else
        X := X shr 1;
    edc_lut[I] := X;
  end;
end;

function TEccEdc.edc_compute(OldEdc: Integer; Data: Pointer; Count: Integer): Integer;
var
  Last: Pointer;
begin
  Result := OldEdc;
  Last := Cast(Data, Count);
  if Count > 0 then
    repeat
      Result := (Result shr 8) xor edc_lut[(Result xor CastByte(Data)^) and 255];
      Adv(Data, 1);
    until Data = Last;
end;

function TEccEdc.ecc_writepq(address, data: Pointer; size, major_count,
  minor_count, major_mult, minor_inc: Integer; ecc: Pointer; compare: Boolean): Boolean;
var
  major, minor, index, temp: Integer;
  ecc_a, ecc_b: Byte;
begin
  for major := 0 to major_count - 1 do
  begin
    index := (major shr 1) * major_mult + (major and 1);
    ecc_a := 0;
    ecc_b := 0;
    for minor := 0 to minor_count - 1 do
    begin
      if index < 4 then
        temp := CastByte(address, index)^
      else
        temp := CastByte(data, index - 4)^;
      Inc(index, minor_inc);
      if index >= size then
        Dec(index, size);
      ecc_a := ecc_a xor temp;
      ecc_b := ecc_b xor temp;
      ecc_a := ecc_f_lut[ecc_a];
    end;
    ecc_a := ecc_b_lut[ecc_f_lut[ecc_a] xor ecc_b];
    if compare then
    begin
      if (CastByte(ecc, major)^ <> ecc_a) or (CastByte(ecc, major + major_count)
        ^ <> (ecc_a xor ecc_b)) then
      begin
        Result := False;
        Exit;
      end;
    end
    else
    begin
      CastByte(ecc, major)^ := ecc_a;
      CastByte(ecc, major + major_count)^ := (ecc_a xor ecc_b);
    end;
  end;
  Result := True;
end;

function TEccEdc.ecc_writesector(address, data, ecc: Pointer; compare: Boolean): Boolean;
begin
  if compare then
    Result := ecc_writepq(address, data, 2064, 86, 24, 2, 86, ecc, True) and
      ecc_writepq(address, data, 2236, 52, 43, 86, 88, CastByte(ecc, 172), True)
  else
  begin
    ecc_writepq(address, data, 2064, 86, 24, 2, 86, ecc, False);
    ecc_writepq(address, data, 2236, 52, 43, 86, 88, CastByte(ecc, 172), False);
    Result := True;
  end;
end;

procedure TEccEdc.ecc_edc(Sector: Pointer; Mode: Byte);
var
  Zero: Integer;
begin
  case Mode of
    1:
      begin
        CastInt(Sector, 2064)^ := edc_compute(0, Sector, 2064);
        ecc_writesector(Cast(Sector, 12), Cast(Sector, 16), Cast(Sector, 2076), False);
      end;
    2:
      begin
        Zero := 0;
        CastInt(Sector, 2072)^ := edc_compute(0, Cast(Sector, 16), 2056);
        ecc_writesector(@Zero, Cast(Sector, 16), Cast(Sector, 2076), False);
      end;
    3:
      begin
        CastInt(Sector, 2348)^ := edc_compute(0, Cast(Sector, 16), 2332);
      end;
  end;

end;

function TEccEdc.check(Sector: Pointer): Byte;
var
  Zero: Integer;
begin
  Zero := 0;
  Result := CastByte(Sector, 15)^;
  if Result = 1 then
  begin
    if (CastInt(Sector, 2064)^ <> edc_compute(0, Sector, 2064)) or not
      ecc_writesector(Cast(Sector, 12), Cast(Sector, 16), Cast(Sector, 2076), True) then
      Result := 0;
  end
  else if Result = 2 then
  begin
    if (CastInt(Sector, 2072)^ <> edc_compute(0, Cast(Sector, 16), 2056)) or not
      ecc_writesector(@Zero, Cast(Sector, 16), Cast(Sector, 2076), True) then
      if CastInt(Sector, 2348)^ <> edc_compute(0, Cast(Sector, 16), 2332) then
        Result := 0
      else
        Result := 3;
  end
  else
    Result := 0;
end;

constructor TEccEdc.Create();
begin
  inherited Create();
  eccedc_init();
end;

end.

