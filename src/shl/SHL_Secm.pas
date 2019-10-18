unit SHL_Secm; // SemVersion: 0.1.0

interface // SpyroHackingLib is licensed under WTFPL
                  
// TODO:

uses
  SysUtils, Classes, SHL_Types, SHL_EccEdc, SHL_XaMusic;

type
  TSecmBuilder = class(TObject)
    constructor Create();
    destructor Destroy(); override;
  public
    procedure ConvertTo(ReadIso, WriteSecm: TStream);
    function InitFrom(ReadSecm: TStream): Boolean;
  private
    function CheckSync(Data: Pointer): Boolean;
    function FirstSector(ReadIso: TStream): Pointer;
    function NextSector(ReadIso: TStream): Pointer;
    function GetTime(Sector: Pointer; out Mode: Byte): Integer;
    function SetTime(Time: Integer; Mode: Byte = 0; Sector: Pointer = nil): Integer;
    function GetFlag(Sector: Pointer; out Chan: Byte): Integer;
    function bcd2int(bcd: Byte): Integer;
    function int2bcd(int: Integer): Byte;
    function SetSetus(Type1, Type3, NewFlag, NewChan, NewTime, ZeroData, ZeroAll, ZeroXA, InvalidEDC: Boolean): Byte;
    procedure GetSetus(Status: Byte; out Type1, Type3, NewFlag, NewChan, NewTime, ZeroData, ZeroAll, ZeroXA, InvalidEDC: Boolean);
  private
    FZeroData: array[0..2351] of Byte;
    FZeroXA: array[0..2327] of Byte;
    FBuffer: array[0..255, 0..2351] of Byte;
    FStart, FIndex, FEnd: Byte;
    FOldType, FOldChan: Byte;
    FOldTime, FOldFlag: Integer;
    FEccEdc: TEccEdc;
  end;

implementation

uses
  Math;

type
  TSecmHeader = packed record
    Secm: Integer;
    Version: Byte;
  end;

const
  Secm_id = 1296254291;

function TSecmBuilder.bcd2int(bcd: Byte): Integer;
var
  Hi, Lo: Word;
begin
  Hi := bcd shr 4;
  Lo := bcd and 15;
  if (Hi > 9) or (Lo > 9) then
  begin
    Result := -1;
    Exit;
  end;
  Result := Hi * 10 + Lo;
end;

function TSecmBuilder.int2bcd(int: Integer): Byte;
var
  Hi, Lo: Word;
begin
  if (int < 0) or (int > 99) then
  begin
    Result := 255;
    Exit;
  end;
  DivMod(int, 10, Hi, Lo);
  Result := (Hi shl 4) or Lo;
end;

constructor TSecmBuilder.Create();
begin
  FEccEdc := TEccEdc.Create();
  TXaDecoder.XaEmprySector(@FZeroXA[0]);
  ZeroMemory(@FZeroData[0], SizeOf(FZeroData));
end;

destructor TSecmBuilder.Destroy();
begin
  FEccEdc.Free();
end;

procedure TSecmBuilder.ConvertTo(ReadIso, WriteSecm: TStream);
var
  Time, StartTime, Flag, Count, i: Integer;
  Mode, Chan, Stat, EccType: Byte;
  Type1, Type3, NewFlag, NewChan, NewTime, ZeroData, ZeroAll, ZeroXA, InvalidEDC: Boolean;
  Data: PInteger;
  Sector: Pointer;
  OldStat: Byte;
  Header: TSecmHeader;
begin
  Header.Secm := Secm_id;
  Header.Version := 1;
  WriteSecm.WriteBuffer(Header, SizeOf(Header));
  FOldTime := 0;
  FOldFlag := 0;
  FOldType := 0;
  FOldChan := 0;
  FStart := 255;
  FIndex := 0;
  FEnd := 0;
  StartTime := 0;

  while true do
  begin
    OldStat := 0;
    Sector := FirstSector(ReadIso);
    if Sector = nil then
      Break;
    Count := 0;

    repeat
      Time := GetTime(Sector, Mode);
      Flag := GetFlag(Sector, Chan);
      if (not CheckSync(Sector)) or (Time = -1) or (Flag = -1) then
        Stat := 255
      else
      begin
        EccType := FEccEdc.check(Sector);
        Type1 := Mode = 1;
        Type3 := EccType = 3;
        if Type1 then
        begin
          NewFlag := False;
          NewChan := False;
        end
        else
        begin
          NewFlag := Flag <> FOldFlag;
          NewChan := (Chan <> FOldChan) and (not NewFlag);
          if Type3 then
            Mode := 3
        end;
        NewTime := Time <> FOldTime + 1;
        ZeroAll := False;
        Data := Sector;
        if Type1 then
        begin
          Inc(Data, 4);
          ZeroData := CompareMem(Data, @FZeroData[0], 2048);
          ZeroXA := False;
          if ZeroData then
          begin
            Inc(Data, 514);
            ZeroAll := CompareMem(Data, @FZeroData[0], 280);
          end;
        end
        else
        begin
          Inc(Data, 6);
          ZeroXA := CompareMem(Data, @FZeroXa[0], 2324);
          ZeroData := CompareMem(Data, @FZeroData[0], 2324);
          if ZeroXA or ZeroData then
          begin
            Mode := 3;
            Type3 := True;
            Inc(Data, 581);
            ZeroAll := Data^ = 0;
          end
          else
          begin
            ZeroData := CompareMem(Data, @FZeroData[0], 2048);
            if ZeroData then
            begin
              Inc(Data, 581);
              ZeroAll := CompareMem(Data, @FZeroData[0], 280);
            end;
          end;
        end;
        if ZeroAll then
        begin
          ZeroData := False;
          ZeroXA := False;
        end;
        if FOldType <> Mode then
        begin
          NewFlag := not Type1;
          NewChan := False;
        end;
        InvalidEDC := EccType = 0;
        Stat := SetSetus(Type1, Type3, NewFlag, NewChan, NewTime, ZeroData, ZeroAll, ZeroXA, InvalidEDC);
        FOldTime := Time;
        FOldFlag := Flag;
        FOldChan := Chan;
        FOldType := Mode;
      end;
      if OldStat = 0 then
      begin
        OldStat := Stat;
        StartTime := Time;
      end;
      Time := SetTime(Time);
      if (Stat <> OldStat) or (Count = 129) then
        Break;
      Inc(Count);
      Sector := NextSector(ReadIso);
    until Sector = nil;

    Sector := NextSector(nil);

    GetSetus(OldStat, Type1, Type3, NewFlag, NewChan, NewTime, ZeroData, ZeroAll, ZeroXA, InvalidEDC);

    if Count > 1 then
    begin
      Stat := Count - 2;
      WriteSecm.WriteBuffer(Stat, 1);
    end;
    WriteSecm.WriteBuffer(OldStat, 1);

    repeat
      if OldStat = 255 then
        WriteSecm.WriteBuffer(Sector^, 2352)
      else
      begin
        if NewFlag then
          WriteSecm.WriteBuffer(Flag, 4);
        if NewChan then
          WriteSecm.WriteBuffer(Chan, 1);
        if NewTime then
        begin
          Time := SetTime(StartTime);
          WriteSecm.WriteBuffer(Time, 3);
          Inc(StartTime);
        end;
        Data := Sector;
        if not (ZeroData or ZeroAll or ZeroXA) then
        begin
          if Type1 then
          begin
            Inc(Data, 4);
            WriteSecm.WriteBuffer(Data^, 2048);
            if InvalidEDC then
            begin
              Inc(Data, 514);
              WriteSecm.WriteBuffer(Data^, 280);
            end;
          end
          else
          begin
            Inc(Data, 6);
            if InvalidEDC then
              WriteSecm.WriteBuffer(Data^, 2328)
            else
            begin
              if Type3 then
                WriteSecm.WriteBuffer(Data^, 2324)
              else
                WriteSecm.WriteBuffer(Data^, 2048);
            end;
          end;
        end
        else
        begin
          if InvalidEDC and not ZeroAll then
          begin
            if Type1 then
            begin
              Inc(Data, 514);
              WriteSecm.WriteBuffer(Data^, 280);
            end
            else if Type3 then
            begin
              Inc(Data, 587);
              WriteSecm.WriteBuffer(Data^, 4);
            end
            else
            begin
              Inc(Data, 518);
              WriteSecm.WriteBuffer(Data^, 280);
            end;
          end;
        end;
      end;
      Dec(Count);
      FOldTime := GetTime(Sector, Mode);
      if Count = 0 then
        Break;
      Sector := FirstSector(ReadIso);
    until Sector = nil;
  end;
end;

function TSecmBuilder.InitFrom(ReadSecm: TStream): Boolean;
var
  Header: TSecmHeader;
begin
  Result := False;
  if ReadSecm <> nil then
  try
    ReadSecm.ReadBuffer(Header, SizeOf(Header));
    if Header.Secm = Secm_id then
      if Header.Version = 1 then
        Result := True;
  except
  end;
end;

function TSecmBuilder.CheckSync(Data: Pointer): Boolean;
var
  Test: PInteger;
const
  Sync_00FFFFFF = -256;
  Sync_FFFFFFFF = -1;
  Sync_FFFFFF00 = 16777215;
begin
  Result := False;
  Test := Data;
  if Test^ <> Sync_00FFFFFF then
    Exit;
  Inc(Test);
  if Test^ <> Sync_FFFFFFFF then
    Exit;
  Inc(Test);
  if Test^ <> Sync_FFFFFF00 then
    Exit;
  Result := True;
end;

function TSecmBuilder.FirstSector(ReadIso: TStream): Pointer;
var
  Size: Integer;
begin
  Inc(FStart);
  if FStart = FEnd then
  begin
    Size := 256 - FEnd;
    Size := ReadIso.Read(FBuffer[FEnd, 0], Size * 2352) div 2352;
    if Size = 0 then
    begin
      Result := nil;
      Exit;
    end;
    Inc(FEnd, Size);
  end;
  FIndex := FStart + 1;
  Result := @FBuffer[FStart, 0];
end;

function TSecmBuilder.NextSector(ReadIso: TStream): Pointer;
var
  Size: Integer;
begin
  if ReadIso = nil then
  begin
    FIndex := FStart + 1;
    Result := @FBuffer[FStart, 0];
    Exit;
  end;
  if FIndex = FEnd then
  begin
    if FEnd >= FStart then
      Size := 256 - FEnd
    else
      Size := FStart - FEnd;
    Size := ReadIso.Read(FBuffer[FEnd, 0], Size * 2352) div 2352;
    if Size = 0 then
    begin
      Result := nil;
      Exit;
    end;
    Inc(FEnd, Size);
  end;
  Result := @FBuffer[FIndex, 0];
  Inc(FIndex);
end;

function TSecmBuilder.GetTime(Sector: Pointer; out Mode: Byte): Integer;
var
  Test: PInteger;
  Minutes, Seconds, Frames: Integer;
begin
  Test := Sector;
  Inc(Test, 3);
  Result := Test^;
  Mode := Result shr 24;
  Result := Result and $ffffff;
  if (Mode <> 1) and (Mode <> 2) then
  begin
    Exit;
    Result := -1;
  end;
  Minutes := bcd2int(Result and 255);
  Seconds := bcd2int((Result shr 8) and 255);
  Frames := bcd2int((Result shr 16) and 255);
  if (Minutes < 0) or (Minutes > 99) or (Seconds < 0) or (Seconds > 59) or (Frames < 0) or (Frames > 74) then
  begin
    Result := -1;
    Exit;
  end;
  Result := (Minutes * 60 + Seconds) * 75 + Frames;
end;

function TSecmBuilder.SetTime(Time: Integer; Mode: Byte = 0; Sector: Pointer = nil): Integer;
var
  Test: PInteger;
  Minutes, Seconds, Frames: Word;
begin
  DivMod(Time, 75, Seconds, Frames);
  DivMod(Seconds, 60, Minutes, Seconds);
  if (Minutes > 99) then
  begin
    Result := -1;
    Exit;
  end;
  Result := int2bcd(Minutes) or (int2bcd(Seconds) shl 8) or (int2bcd(Frames) shl 16) or (Mode shl 24);
  if Sector = nil then
    Exit;
  Test := Sector;
  Inc(Test, 3);
  Test^ := Result;
end;

function TSecmBuilder.GetFlag(Sector: Pointer; out Chan: Byte): Integer;
var
  Test: PInteger;
  Mode, MinStride: Byte;
  Stereo, HiQuality: Boolean;
begin
  Result := -1;
  Test := Sector;
  Inc(Test, 3);
  Mode := Test^ shr 24;
  if Mode = 2 then
  begin
    Inc(Test);
    Result := Test^;
    Inc(Test);
    if Result = Test^ then
      TXaDecoder.TrackInfoByXa(Result, Chan, Stereo, HiQuality, MinStride)
    else
      Result := -1;
  end
  else if Mode = 1 then
  begin
    Inc(Test, 513);
    Result := Test^;
    Inc(Test);
    if (Result = 0) and (Result = Test^) then
      Chan := 0
    else
      Result := -1;
  end;
end;

function TSecmBuilder.SetSetus(Type1, Type3, NewFlag, NewChan, NewTime, ZeroData, ZeroAll, ZeroXA, InvalidEDC: Boolean): Byte;
begin
  if (Type1 and (Type3 or NewFlag or NewChan)) or (NewFlag and NewChan) or (Ord(ZeroData) + Ord(ZeroAll) + Ord(ZeroXA) > 1) then
  begin
    Result := 255;
    Exit;
  end;
  Result := 128;
  if Type1 or NewFlag or NewChan then
  begin
    if Type3 or Type1 then
      Result := 4 or Result;
    if NewFlag then
      Result := 1 or Result;
    if NewChan then
      Result := 2 or Result;
  end;
  if NewTime then
    Result := 8 or Result;
  if ZeroData then
    Result := 16 or Result;
  if ZeroXA then
    Result := 32 or Result;
  if ZeroAll then
    Result := 48 or Result;
  if InvalidEDC then
    Result := 64 or Result;
end;

procedure TSecmBuilder.GetSetus(Status: Byte; out Type1, Type3, NewFlag, NewChan, NewTime, ZeroData, ZeroAll, ZeroXA, InvalidEDC: Boolean);
begin
  if (Status = 255) or ((Status and 128) = 0) then
    Exit;
  InvalidEDC := (Status and 64) <> 0;
  if (Status and 48) = 48 then
  begin
    ZeroAll := True;
    ZeroData := False;
    ZeroXA := False;
  end
  else
  begin
    ZeroAll := False;
    ZeroXA := (Status and 32) <> 0;
    ZeroData := (Status and 16) <> 0;
  end;
  NewTime := (Status and 8) <> 0;
  NewChan := (Status and 2) <> 0;
  NewFlag := (Status and 1) <> 0;
  Type1 := False;
  Type3 := False;
  if (Status and 4) <> 0 then
  begin
    if NewFlag or NewChan then
      Type3 := True
    else
      Type1 := True;
  end;
end;

end.

