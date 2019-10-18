unit SHL_WadManager; // SpyroHackingLib is licensed under WTFPL

interface

uses
  SysUtils, Classes, SHL_VagEncoder, SHL_VramManager, SHL_Types;

type
  NGame = (GameUnknown = 0, GameSpyro1 = 1, GameSpyro2 = 2, GameSpyro3 = 3);

type
  RLevelPart = record
    Addr: Pointer;
    Size: Integer;
    Name: TextString;
  end;

  ALevelPart = array of RLevelPart;

type
  RLevelData = record
    Name: TextString;
    Data: DataString;
  end;

  ALevelData = array of RLevelData;

type
  RWadHeader = record
    Offset, Count: Integer;
  end;

  PWadHeader = ^RWadHeader;

type
  TWadManager = class(TObject)
  private
    FLevelSub, FLevelCopy: Pointer;
    FLevelSize: Integer;
    FGame: NGame;
    FParts: ALevelPart;
  protected
    function SublevelDataToSubsubfile(Sublevel: Integer): Integer;
    function GuessGame(): NGame;
  private
    function SublevelTextToSubsubfile(Sublevel: Integer): Integer;
    function GetSubsubfile(Index: Integer; out Size: Integer): Pointer;
    function MakeJump(From: Pointer; var HaveSize: Integer; Count: Integer): Pointer;
    function MoveToTextSubsubfileFirstJump(StartOfSubsubfile: Pointer; var Size:
      Integer): Pointer;
    function GetLevelModels(Start: Pointer; out Size: Integer): Pointer;
    function GetLastModel(): Pointer;
    function GetFirstModel(): Pointer;
    procedure RebaseModels(Models: Pointer; Offset: Integer);
    procedure PushMove(var Offset: Integer; Addr: Pointer; Size: Integer);
    procedure PushGpuSub(var Offset: Integer; Addr: Pointer; Size: Integer);
    procedure PushZero(var Offset: Integer);
    procedure PushJump(var Offset: Integer; Addr: Pointer; Size: Integer);
    function PushIndex(Target: Pointer; Source: Pointer; Size, Offset: Integer): Integer;
    function GivePart(Name: TextString; out Size: Integer): Pointer;
  public
    constructor Create();
    destructor Destroy(); override;
    class function WadSubfilesCount(Header: Pointer): Integer;
    class function WadSubfileInfoGet(Header: Pointer; Index: Integer; out Offset,
      Size: Integer): Boolean;
    class procedure WadSubfileInfoSet(Header: Pointer; Index, Offset, Size: Integer);
    class function CutSubfileExportBlocks(Cutscene: Pointer; Size: Integer): ALevelPart;
    class function CutSubfileImportBlocks(const Parts: ALevelPart): DataString;
    class function CutSubfileExportTracks(const Parts: ALevelPart): ALevelData;
//    class function CutSubfileImportTracks(const Datas: ALevelData): ALevelPart;
    class function CutSubfileGetModel(const Tracks: ALevelData; Index: Integer): Integer;
    class function ModelAnimated(Model: Pointer): Boolean;
    class function ModelFrames(Model: Pointer): Integer;
  public
    function LoadLevelParts(): ALevelPart;
    function SaveLevelParts(const Parts: ALevelPart): DataString;
    function UseLevelSub(Subfile: Pointer; Size: Integer): Boolean; overload;
    function UseLevelSub(Subfile: DataString): Boolean; overload;
    function SeekSky(out Size: Integer; SubLevel: Integer = 1): Pointer;
    function LevelModelCount(): Integer;
    function LevelGetVram(out Size: Integer): Pointer;
    function LevelGetModel(out Size: Integer; Index: Integer; out Entity:
      Integer; Sublevel: Integer = 1): Pointer;
    function LevelGetEggModel(out Size: Integer; Index: Integer): Pointer;
    function LevelGetEggTexture(Index: Integer; Vram: TVram; out X, Y: Integer): Boolean;
    function LevelGetSublevelVram(Index: Integer; Vram: TVram; out X, Y: Integer):
      Boolean;
  end;

implementation

uses
  Types;

const
  //
  Sp3_header_eggs = 96;
  Sp3_header_models = 160;
  Sp3_header_types = 416;
  Sp3_header_last = 560;
  //
  Sp2_header_models = 64;
  Sp2_header_types = 320;
  Sp2_header_last = 560;
  //
  Sp1_header_dragons = 32;
  Sp1_header_models = 80;
  Sp1_header_types = 336;
  Sp1_header_last = 464;
  //
  SizeOfModelsHeader = 64 * 4 + 64 * 2;

constructor TWadManager.Create();
begin
//
end;

destructor TWadManager.Destroy();
begin
  if FLevelCopy <> nil then
    FreeMem(FLevelCopy);
end;

class function TWadManager.WadSubfilesCount(Header: Pointer): Integer;
var
  Data: PInteger;
begin
  if Header = nil then
  begin
    Result := 0;
    Exit;
  end;
  Data := Header;
  Inc(Data, 510);
  Result := 256;
  while (Result <> 0) and (PWadHeader(Data).Offset = 0) and (PWadHeader(Data).Count
    = 0) do
  begin
    Dec(Data, 2);
    Dec(Result);
  end;
end;

class function TWadManager.WadSubfileInfoGet(Header: Pointer; Index: Integer;
  out Offset, Size: Integer): Boolean;
var
  Data: PWadHeader;
const
  Minsize = 2048;
  Maxsize = 256 * 1024 * 1024;
begin
  Result := False;
  if (Header = nil) or (Index < 1) or (Index > 256) then
    Exit;
  Data := Cast(Header, (Index - 1) * 8);
  Offset := Data.Offset;
  Size := Data.Count;
  if (Size >= Minsize) and (Offset >= Minsize) and (Size <= Maxsize) and (Offset
    <= Maxsize) then
    Result := True;
end;

class procedure TWadManager.WadSubfileInfoSet(Header: Pointer; Index, Offset,
  Size: Integer);
var
  Data: PWadHeader;
begin
  if (Header = nil) or (Index < 1) or (Index > 256) then
    Exit;
  Data := Cast(Header, (Index - 1) * 8);
  Data.Offset := Offset;
  Data.Count := Size;
end;

function TWadManager.SublevelTextToSubsubfile(Sublevel: Integer): Integer; // del?
begin
  Assert(Sublevel > 0);
  Result := 4 + (Sublevel - 1) * 2;
end;

function TWadManager.SublevelDataToSubsubfile(Sublevel: Integer): Integer; // del?
begin
  Assert(Sublevel > 1);
  Result := SublevelTextToSubsubfile(Sublevel) - 1;
end;

function TWadManager.GetSubsubfile(Index: Integer; out Size: Integer): Pointer;
var
  Ints: PIntegerArray;
begin
  Assert(Index > 0);
  Ints := Pointer(FLevelSub);
  Index := (Index - 1) * 2;
  Result := Cast(FLevelSub, Ints[Index]);
  Size := Ints[Index + 1];
  if (Ints[Index] + Size > FLevelSize) or (Ints[Index] < 2048) or (Size < 2048) then
  begin
    Size := 0;
    Result := nil;
  end;
end;

function TWadManager.MakeJump(From: Pointer; var HaveSize: Integer; Count:
  Integer): Pointer; // del
var
  Value: Integer;
begin
  while (HaveSize > 0) and (Count > 0) do
  begin
    Dec(Count);
    Value := PInteger(From)^;
    if (Value < 4) or ((Value and 3) <> 0) then
    begin
      HaveSize := -1;
      Break;
    end;
    Dec(HaveSize, Value);
    From := Cast(From, Value);
  end;
  Result := From;
end;

function TWadManager.MoveToTextSubsubfileFirstJump(StartOfSubsubfile: Pointer;
  var Size: Integer): Pointer; // del
var
  Value: Integer;
begin
  Value := 0;
  Result := StartOfSubsubfile;
  if Size > 0 then
  begin
    case FGame of
      GameSpyro1:
        Value := 136;
      GameSpyro2:
        Value := 44;
      GameSpyro3:
        Value := 48;
    end;
    Result := Cast(Result, Value);
    Dec(Size, Value);
  end;
end;

function TWadManager.UseLevelSub(Subfile: Pointer; Size: Integer): Boolean;
begin
  if Size < 2048 then
  begin
    Result := False;
    Exit;
  end;
  if FLevelCopy = nil then
    GetMem(FLevelCopy, 2048);
  CopyMemory(Subfile, FLevelCopy, 2048);
  Result := True;
  FLevelSub := Subfile;
  FLevelSize := Size;
  GuessGame();
  RebaseModels(GetLevelModels(FLevelCopy, Size), 0);
end;

function TWadManager.UseLevelSub(Subfile: DataString): Boolean;
begin
  Result := UseLevelSub(Cast(Subfile), Length(Subfile));
end;

function TWadManager.GuessGame(): NGame;   // fix
var
  Arr: PIntegerArray;
begin
  Result := GameSpyro3;
  if FLevelSub <> nil then
  begin
    Arr := Pointer(FLevelSub);
    if Arr[4] = Arr[16] then
      Result := GameSpyro2
    else if Arr[4] = Arr[20] then
      Result := GameSpyro1;
    FGame := Result;
    Exit;
  end;
end;

function TWadManager.SeekSky(out Size: Integer; SubLevel: Integer = 1): Pointer; // fix
var
  Arr: PIntegerArray;
begin
  Result := nil;
  try
    if Sublevel = 1 then
    begin
      case FGame of
        GameSpyro1:
          begin
            Arr := GetSubsubfile(2, Size);
            Arr := MakeJump(Arr, Size, 5);
            Assure((Size > 0) and (Size > Arr[0]));
            Size := Arr[0] - 4;
            Result := @Arr[1];
          end;
        GameSpyro2:
          begin
            Arr := GetSubsubfile(2, Size);
            Arr := MakeJump(Arr, Size, 6);
            Assure(Size > 16);
            Arr := MakeJump(@Arr[3], Size, 1);
            Assure((Size > 0) and (Size > Arr[0]));
            Size := Arr[0] - 4;
            Result := @Arr[1];
          end;
        GameSpyro3:
          begin
            Arr := GetSubsubfile(2, Size);
            Arr := MakeJump(Arr, Size, 4);
            Assure(Size > 16);
            Arr := MakeJump(@Arr[3], Size, 1);
            Assure((Size > 0) and (Size > Arr[0]));
            Size := Arr[0] - 4;
            Result := @Arr[1];
          end;
      end;
    end
    else if FGame = GameSpyro3 then
    begin
      Arr := GetSubsubfile(SublevelTextToSubsubfile(SubLevel), Size);
      Arr := MoveToTextSubsubfileFirstJump(Arr, Size);
      Size := CastChar(MakeJump(Arr, Size, 1)) - CastChar(Arr);
      Assure(Size > 4);
      Result := @Arr[1];
    end;
  except
  end;
end;

function TWadManager.LevelModelCount(): Integer; // fix
var
  Data: PWord;
  Offset, Start: Integer;
begin
  Result := 0;
  case FGame of
    GameSpyro1:
      begin
        Offset := Sp1_header_last;
        Start := Sp1_header_types;
      end;
    GameSpyro2:
      begin
        Offset := Sp2_header_last;
        Start := Sp2_header_types;
      end;
    GameSpyro3:
      begin
        Offset := Sp3_header_last;
        Start := Sp3_header_types;
      end;
  else
    Exit;
  end;
  Data := Cast(FLevelSub, Offset);
  while Start < Offset do
  begin
    Dec(Offset, 2);
    Dec(Data);
    if Data^ <> 0 then
      Break;
  end;
  Result := (Offset - Start + 2) div 2;
  if FGame = GameSpyro1 then
    Dec(Result);
end;
{
function TWadManager.LevelGetModel(Index: Integer; out Size, Entity: Integer):
  Pointer; // fix
var
  Model: PInteger;
  Data: PWord;
begin
  Result := nil;
  Assert(Index > 0);
  case FGame of
    GameSpyro1:
      begin
        Model := Pointer(FLevelSub + Sp1_header_models);
        Data := Pointer(FLevelSub + Sp1_header_types);
      end;
    GameSpyro2:
      begin
        Model := Pointer(FLevelSub + Sp2_header_models);
        Data := Pointer(FLevelSub + Sp2_header_types);
      end;
    GameSpyro3:
      begin
        Model := Pointer(FLevelSub + Sp3_header_models);
        Data := Pointer(FLevelSub + Sp3_header_types);
      end;
  else
    Exit;
  end;
  Inc(Model, Index);
  Inc(Data, Index - 1);
  Size := Model^;
  Dec(Model);
  Result := FLevelSub + Model^;
  Dec(Size, Model^);
  Entity := Data^;
end;
}
//

function Fail(out Addr: Pointer; out Size: Integer; out Have: Integer): Pointer;
begin
  Addr := nil;
  Size := 0;
  Have := -1;
  Result := nil;
end;

function Jump(var Addr: Pointer; out Size: Integer; var Have: Integer): Pointer;
begin
  if Addr = nil then
  begin
    Result := Fail(Addr, Size, Have);
    Exit;
  end;
  Size := PInteger(Addr)^;
  if (Size < 4) or ((Size and 3) <> 0) then
  begin
    Result := Fail(Addr, Size, Have);
    Exit;
  end;
  Dec(Have, Size);
  if Have < 0 then
  begin
    Result := Fail(Addr, Size, Have);
    Exit;
  end;
  Result := Cast(Addr, Size);
  Addr := Cast(Addr, 4);
  Dec(Size, 4);
end;

function Walk(var Addr: Pointer; Size: Integer; var Have: Integer): Pointer;
begin
  Dec(Have, Size);
  if (Have < 0) or (Addr = nil) then
    Result := Fail(Addr, Size, Have)
  else
    Result := Cast(Addr, Size);
end;

function SkipPortal(var Addr: Pointer; out Size: Integer; var Have: Integer): Pointer;
var
  Count, Got: Integer;
begin
  if Have < 4 then
  begin
    Result := Fail(Addr, Size, Have);
    Exit;
  end;
  Count := PInteger(Addr)^;
  if (Count < 0) or (Count > 9) then
  begin
    Result := Fail(Addr, Size, Have);
    Exit;
  end;
  Result := Walk(Addr, 4, Have);
  Size := 4;
  while Count > 0 do
  begin
    Dec(Count);
    Result := Walk(Result, 112, Have);
    Result := Jump(Result, Got, Have);
    Inc(Size, 112 + 4 + Got);
  end;
  if Have < 0 then
  begin
    Result := Fail(Addr, Size, Have);
    Exit;
  end;
end;

type
  RSublevelTexture = record
    X, Y, W, H, S: Integer;
  end;

  PSublevelTexture = ^RSublevelTexture;

function SkipTextures(var Addr: Pointer; out Size: Integer; var Have: Integer): Pointer;
var
  Header: PSublevelTexture;
begin
  if Have < 20 then
  begin
    Result := Fail(Addr, Size, Have);
    Exit;
  end;
  Header := Addr;
  with Header^ do
    if (X = 0) or (Y = 0) or (W = 0) or (H = 0) or (S = -1) then
      Size := 20
    else
      Size := 16 + S + W * H * 2;
  Result := Walk(Addr, Size, Have);
end;

function SkipColor(var Addr: Pointer; out Size: Integer; var Have: Integer): Pointer;
begin
  Size := 12;
  Result := Walk(Addr, Size, Have);
end;

function SkipSounds(var Addr: Pointer; out Size: Integer; var Have: Integer): Pointer;
begin
  Size := 32;
  Result := Walk(Addr, Size, Have);
end;

function SkipModels(var Addr: Pointer; out Size: Integer; var Have: Integer): Pointer;
begin
  Size := SizeOfModelsHeader;
  Result := Walk(Addr, Size, Have);
end;

function SkipVram(var Addr: Pointer; out Size: Integer; var Have: Integer): Pointer;
begin
  Size := 512 * 512 * 2;
  Result := Walk(Addr, Size, Have);
end;

function SkipGuide(var Addr: Pointer; out Size: Integer; var Have: Integer): Pointer;
begin
  Size := 192 * 64 * 2;
  Result := Walk(Addr, Size, Have);
end;

function SkipEgg(var Addr: Pointer; out Size: Integer; var Have: Integer): Pointer;
begin
  Size := 96 * 64 * 2;
  Result := Walk(Addr, Size, Have);
end;

function TrimSize(From: Pointer; Size: Integer): Integer;
var
  Data: PInteger;
  Diff: Boolean;
const
  Zero: array[0..31] of Byte = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
begin
  Result := Size;
  if (From = nil) or (Result < 32) then
    Exit;
  Data := Pointer(((Integer(From) + Result) and not 31) - 16);
  if not CompareMem(Data, @Zero[0], CastChar(From) - CastChar(Data)) then
    Exit;
  while Result > 31 do
  begin
    Dec(Data, 8);
    Diff := Data^ <> 0;
    Inc(Data);
    Diff := Diff or (Data^ <> 0);
    Inc(Data);
    Diff := Diff or (Data^ <> 0);
    Inc(Data);
    Diff := Diff or (Data^ <> 0);
    Inc(Data);
    Diff := Diff or (Data^ <> 0);
    Inc(Data);
    Diff := Diff or (Data^ <> 0);
    Inc(Data);
    Diff := Diff or (Data^ <> 0);
    Inc(Data);
    Diff := Diff or (Data^ <> 0);
    Inc(Data);
    if Diff then
      Break;
    Dec(Result, 32);
    Dec(Data, 8);
  end;
end;

function FindPart(const Arr: ALevelPart; const Name: TextString): RLevelPart;
var
  Index: Integer;
begin
  Result.Addr := nil;
  Result.Size := 0;
  Result.Name := '';
  for Index := 0 to Length(Arr) - 1 do
    if Arr[Index].Name = Name then
    begin
      Result := Arr[Index];
      Break;
    end;
end;

function TWadManager.GetLevelModels(Start: Pointer; out Size: Integer): Pointer;
begin
  Size := SizeOfModelsHeader;
  case FGame of
    GameSpyro1:
      Result := Cast(Start, 80);
    GameSpyro2:
      Result := Cast(Start, 64);
    GameSpyro3:
      Result := Cast(Start, 160);
  else
    Result := nil;
  end;
end;

function TWadManager.GetLastModel(): Pointer;
var
  Size: Integer;
  Data: PInteger;
begin
  Data := GetLevelModels(FLevelSub, Size);
  if (Data = nil) or (Data^ = 0) then
  begin
    Result := nil;
    Exit;
  end;
  Inc(Data, 63);
  while Data^ = 0 do
    Dec(Data);
  if Data^ >= FLevelSize then
    Result := nil
  else
    Result := Cast(FLevelSub, Data^);
end;

function TWadManager.GetFirstModel(): Pointer;
var
  Size: Integer;
  Data: PInteger;
begin
  Data := GetLevelModels(FLevelSub, Size);
  if (Data = nil) or (Data^ = 0) then
  begin
    Result := nil;
    Exit;
  end;
  Result := Cast(FLevelSub, Data^);
end;

const
  SubTableModels = 'tbl-mdl';
  SubTableWad = 'tbl-wad';
  SubGpuTextures = 'gpu-txt';
  SubGpuGuidebook = 'gpu-gui';
  SubGpuSublevel = 'gpu-sub';
  SubSpuVag = 'spu-vag';
  SubTableGround = 'tbl-grd';
  SubModelGround = 'mdl-grd';
  SubOptimizeGround = 'opt-grd';
  SubOptimizeSky = 'opt-sky';
  SubTableCollision = 'tbl-cln';
  SubModelCollision = 'mdl-cln';
  SubModelSky = 'mdl-sky';
  SubModelPortal = 'mdl-por';
  SubTableParticle = 'tbl-prt';
  SubTableSound = 'tbl-snd';
  SubModelObjects = 'mdl-obj';
  SubLevelData = 'lev-dat';
  SubDragonData = 'drg-dat';
  SubTableBlend = 'tbl-bln';
  SubTableColor = 'tbl-col';
  SubTableCamera = 'tbl-cam';
  SubTableRun = 'tbl-run';
  SubEggZone = 'egg-zon';
  SubEggTexture = 'egg-txt';
  SubEggModel = 'egg-mdl';

function TWadManager.LoadLevelParts(): ALevelPart;
var
  Have, P, Keep: Integer;
  Last: Pointer;
  Lev: TextChar;
  R: ALevelPart;

  procedure Body();
  var
    I: Integer;
  begin
    case FGame of
      GameSpyro1:
        for I := 0 to 10 do
          case I of
            0:
              begin
                R[P].Name := SubTableModels;
                R[P].Addr := GetLevelModels(FLevelCopy, R[P].Size);
                Inc(P);
                R[P].Name := SubTableWad;
                R[P].Addr := FLevelSub;
                R[P].Size := 2048;
                Inc(P);
              end;
            1:
              begin
                R[P].Name := SubGpuTextures;
                R[P].Addr := GetSubsubfile(1, Have);
                Inc(P);
                R[P].Name := SubSpuVag;
                R[P].Addr := SkipVram(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P - 1].Size := TrimSize(R[P - 1].Addr, Have);
              end;
            2:
              begin
                R[P].Name := SubTableGround;
                R[P].Addr := GetSubsubfile(2, Have);
                Inc(P);
                R[P].Name := SubModelGround;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubOptimizeGround;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableCollision;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubModelCollision;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubModelSky;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubModelPortal;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableParticle;
                R[P].Addr := SkipPortal(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableSound;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                Jump(R[P - 1].Addr, R[P - 1].Size, Have);
              end;
            3:
              begin
                R[P].Name := SubModelObjects;
                R[P].Addr := GetSubsubfile(3, R[P].Size);
                R[P].Size := TrimSize(R[P].Addr, R[P].Size);
                Inc(P);
              end;
            4:
              begin
                R[P].Name := SubLevelData;
                R[P].Addr := GetSubsubfile(4, R[P].Size);
                R[P].Size := TrimSize(R[P].Addr, R[P].Size);
                Inc(P);
              end;
            5, 6, 7, 8, 9, 10:
              begin
                Lev := Chr(Ord('0') + (I - 5 + 1));
                R[P].Name := SubDragonData + '-' + Lev;
                R[P].Addr := GetSubsubfile(I, R[P].Size);
                R[P].Size := TrimSize(R[P].Addr, R[P].Size);
                Inc(P);
              end;
          end;
      GameSpyro2:
        for I := 0 to 4 do
          case I of
            0:
              begin
                R[P].Name := SubTableModels;
                R[P].Addr := GetLevelModels(FLevelCopy, R[P].Size);
                Inc(P);
                R[P].Name := SubTableWad;
                R[P].Addr := FLevelSub;
                R[P].Size := 2048;
                Inc(P);
              end;
            1:
              begin
                R[P].Name := SubGpuTextures;
                R[P].Addr := GetSubsubfile(1, Have);
                Inc(P);
                R[P].Name := SubGpuGuidebook;
                R[P].Addr := SkipVram(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubSpuVag;
                R[P].Addr := SkipGuide(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P - 1].Size := TrimSize(R[P - 1].Addr, Have);
              end;
            2:
              begin
                R[P].Name := SubTableGround;
                R[P].Addr := GetSubsubfile(2, Have);
                Inc(P);
                R[P].Name := SubModelGround;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubOptimizeGround;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubOptimizeSky;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableCollision;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableColor;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableBlend;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubModelCollision;
                R[P].Addr := SkipColor(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubModelSky;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubModelPortal;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableParticle;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableCamera;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableRun;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableSound;
                R[P].Addr := SkipSounds(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                Jump(R[P - 1].Addr, R[P - 1].Size, Have);
              end;
            3:
              begin
                R[P].Name := SubModelObjects;
                R[P].Addr := GetSubsubfile(3, R[P].Size);
                R[P].Size := CastChar(GetLastModel()) - R[P].Addr;
                R[P].Size := TrimSize(R[P].Addr, R[P].Size);
                Inc(P);
              end;
            4:
              begin
                R[P].Name := SubLevelData;
                R[P].Addr := GetSubsubfile(4, R[P].Size);
                R[P].Size := TrimSize(R[P].Addr, R[P].Size);
                Inc(P);
              end;
          end;
      GameSpyro3:
        for I := 0 to 20 do
          case I of
            0:
              begin
                Lev := '1';
                R[P].Name := SubTableModels + '-' + Lev;
                R[P].Addr := GetLevelModels(FLevelCopy, R[P].Size);
                Inc(P);
                R[P].Name := SubTableWad;
                R[P].Addr := FLevelSub;
                R[P].Size := 2048;
                Inc(P);
              end;
            1:
              begin
                R[P].Name := SubGpuTextures;
                R[P].Addr := GetSubsubfile(1, Have);
                Inc(P);
                R[P].Name := SubSpuVag;
                R[P].Addr := SkipVram(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P - 1].Size := TrimSize(R[P - 1].Addr, Have);
              end;
            2:
              begin
                Lev := '1';
                R[P].Name := SubTableGround;
                R[P].Addr := GetSubsubfile(2, Have);
                Inc(P);
                R[P].Name := SubModelGround + '-' + Lev;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableCollision + '-' + Lev;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableColor;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableBlend;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubModelCollision + '-' + Lev;
                R[P].Addr := SkipColor(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubModelSky;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubModelPortal;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableParticle;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubEggZone;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableCamera;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableRun;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableSound;
                R[P].Addr := SkipSounds(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                Jump(R[P - 1].Addr, R[P - 1].Size, Have);
              end;
            3:
              begin
                Lev := '1';
                R[P].Name := SubOptimizeGround + '-' + Lev;
                R[P].Addr := GetSubsubfile(3, Keep);
                Inc(P);
                Have := Keep;
                Last := Jump(R[P - 1].Addr, R[P - 1].Size, Keep);
                R[P].Name := SubOptimizeSky + '-' + Lev;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);

                R[P].Name := SubModelCollision;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                R[P].Size := CastChar(GetFirstModel()) - R[P].Addr;
                Inc(P);

                R[P].Name := SubModelObjects + '-' + Lev;
                R[P].Addr := GetFirstModel();
                R[P].Size := CastChar(GetLastModel()) - R[P].Addr;
                Inc(P);
                R[P].Name := SubGpuSublevel + '-' + Lev;
                SkipTextures(Last, R[P].Size, Keep);
                R[P].Addr := Last;
                Inc(P);
              end;
            4:
              begin
                Lev := '1';
                R[P].Name := SubLevelData + '-' + Lev;
                R[P].Addr := GetSubsubfile(4, R[P].Size);
                R[P].Size := TrimSize(R[P].Addr, R[P].Size);
                Inc(P);
              end;
            5, 7, 9, 11:
              begin
                Lev := Chr(Ord('0') + ((I - 5) div 2) + 2);
                R[P].Name := SubModelObjects + '-' + Lev;
                R[P].Addr := GetSubsubfile(I, Have);
                if R[P].Addr = nil then
                  Continue;
                Inc(P);
                R[P].Name := SubTableModels + '-' + Lev;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubModelGround + '-' + Lev;
                R[P].Addr := SkipModels(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubOptimizeGround + '-' + Lev;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubOptimizeSky + '-' + Lev;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubTableCollision + '-' + Lev;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubModelCollision + '-' + Lev;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P].Name := SubGpuSublevel + '-' + Lev;
                R[P].Addr := Jump(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                SkipTextures(R[P - 1].Addr, R[P - 1].Size, Have);
              end;
            6, 8, 10, 12:
              begin
                Lev := Chr(Ord('0') + ((I - 6) div 2) + 2);
                R[P].Name := SubLevelData + '-' + Lev;
                R[P].Addr := GetSubsubfile(I, R[P].Size);
                if R[P].Addr = nil then
                  Continue;
                R[P].Size := TrimSize(R[P].Addr, R[P].Size);
                Inc(P);
              end;
            13, 14, 15, 16, 17, 18, 19, 20:
              begin
                Lev := Chr(Ord('0') + (I - 13 + 1));
                R[P].Name := SubEggTexture + '-' + Lev;
                R[P].Addr := GetSubsubfile(I, Have);
                if R[P].Addr = nil then
                  Continue;
                Inc(P);
                R[P].Name := SubEggModel + '-' + Lev;
                R[P].Addr := SkipEgg(R[P - 1].Addr, R[P - 1].Size, Have);
                Inc(P);
                R[P - 1].Size := TrimSize(R[P - 1].Addr, Have);
              end;
          end;
    end;
  end;

begin
  SetLength(FParts, 0);
  SetLength(Result, 0);
  try
    P := 0;
    SetLength(R, 99);
    Body();
  except
    Exit;
  end;
  Dec(P);
  SetLength(R, P + 1);
  Result := R;
  FParts := R;
end;

procedure TWadManager.RebaseModels(Models: Pointer; Offset: Integer);
var
  Data: PInteger;
  Index: Integer;
begin
  if (Models = nil) or (Offset < 0) then
    Exit;
  Data := Models;
  Dec(Offset, Data^);
  for Index := 1 to 64 do
  begin
    Inc(Data^, Offset);
    Inc(Data);
    if Data^ = 0 then
      Break;
  end;
end;

procedure TWadManager.PushMove(var Offset: Integer; Addr: Pointer; Size: Integer);
begin
  if Size <> 0 then
  begin
    CopyMemory(Addr, Cast(FLevelSub, Offset), Size);
    Inc(Offset, Size);
  end;
end;

procedure TWadManager.PushGpuSub(var Offset: Integer; Addr: Pointer; Size: Integer);
var
  Data: PInteger;
  First, Len: Integer;
  Head: PSublevelTexture;
begin
  Head := Addr;
  if Addr = nil then
    Exit;
  if Head.S = -1 then
  begin
    PushMove(Offset, Addr, Size);
    Exit;
  end;
  if Size < 20 then
    Exit;
  PushMove(Offset, Addr, 16);
  Data := Cast(FLevelSub, Offset);
  First := Offset;
  Inc(Offset, 4);
  PushZero(Offset);
  Data^ := Offset - First;
  Len := 16 + Head.S;
  PushMove(Offset, Cast(Addr, Len), Size - Len);
end;

procedure TWadManager.PushZero(var Offset: Integer);
var
  Size: Integer;
begin
  if (Offset and 2047) <> 0 then
  begin
    Size := 2048 - (Offset and 2047);
    ZeroMemory(Cast(FLevelSub, Offset), Size);
    Inc(Offset, Size);
  end;
end;

procedure TWadManager.PushJump(var Offset: Integer; Addr: Pointer; Size: Integer);
begin
  if (Size and 3) <> 0 then
    Size := (Size + 4) and not 3;
  CastInt(FLevelSub, Offset)^ := Size + 4;
  Inc(Offset, 4);
  if Size <> 0 then
  begin
    CopyMemory(Addr, Cast(FLevelSub, Offset), Size);
    Inc(Offset, Size);
  end;
end;

function TWadManager.PushIndex(Target: Pointer; Source: Pointer; Size, Offset:
  Integer): Integer;
begin
  Result := SizeOfModelsHeader;
  ZeroMemory(Target, Result);
  if Source = nil then
    Exit;
  if Result < Size then
    Size := Result;
  CopyMemory(Source, Target, Size);
end;

function TWadManager.SaveLevelParts(const Parts: ALevelPart): DataString;
var
  Index, Size, Offset, Start, Keep, I: Integer;
  Part: RLevelPart;
  Old: Pointer;
  Lev: TextChar;
begin
  Old := FLevelSub;
  Result := '';
  try
    Size := 0;
    for Index := 0 to Length(Parts) - 1 do
    begin
      Inc(Size, Parts[Index].Size);
      if Parts[Index].Size < 0 then
        Exit;
    end;
    if (Size = 0) or (Size > 16 * 1024 * 1024) then
      Exit;
    SetLength(Result, Size * 2);
    FLevelSub := Cast(Result);
    Part := FindPart(Parts, SubTableWad);
    Assure(Part.Addr <> nil);
    CopyMemory(Part.Addr, FLevelSub, Part.Size);
    GuessGame();
    ZeroMemory(FLevelSub, Part.Size);
    Offset := Part.Size;
    PushZero(Offset);
    case FGame of
      GameSpyro1:
        begin
          for I := 1 to 10 do
          begin
            Start := Offset;
            case I of
              1:
                begin
                  Part := FindPart(Parts, SubGpuTextures);
                  PushMove(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubSpuVag);
                  PushMove(Offset, Part.Addr, Part.Size);
                end;
              2:
                begin
                  Part := FindPart(Parts, SubTableGround);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelGround);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubOptimizeGround);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableCollision);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelCollision);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelSky);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelPortal);
                  PushMove(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableParticle);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableSound);
                  PushJump(Offset, Part.Addr, Part.Size);
                end;
              3:
                begin
                  Part := FindPart(Parts, SubTableModels);
                  PushIndex(GetLevelModels(FLevelCopy, Size), Part.Addr, Part.Size,
                    Offset);
                  Part := FindPart(Parts, SubModelObjects);
                  PushMove(Offset, Part.Addr, Part.Size);
                end;
              4:
                begin
                  Part := FindPart(Parts, SubLevelData);
                  PushMove(Offset, Part.Addr, Part.Size);
                end;
              5, 6, 7, 8, 9, 10:
                begin
                  Lev := Chr(Ord('0') + (I - 5 + 1));
                  Part := FindPart(Parts, SubDragonData + '-' + Lev);
                  PushMove(Offset, Part.Addr, Part.Size);
                end;
            end;
            PushZero(Offset);
            if Offset <> Start then
              WadSubfileInfoSet(FLevelSub, I, Start, Offset - Start);
          end;
        end;
      GameSpyro2:
        begin
          for I := 1 to 4 do
          begin
            Start := Offset;
            case I of
              1:
                begin
                  Part := FindPart(Parts, SubGpuTextures);
                  PushMove(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubGpuGuidebook);
                  PushMove(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubSpuVag);
                  PushMove(Offset, Part.Addr, Part.Size);
                end;
              2:
                begin
                  Part := FindPart(Parts, SubTableGround);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelGround);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubOptimizeGround);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubOptimizeSky);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableCollision);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableColor);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableBlend);
                  PushMove(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelCollision);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelSky);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelPortal);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableParticle);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableCamera);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableRun);
                  PushMove(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableSound);
                  PushJump(Offset, Part.Addr, Part.Size);
                end;
              3:
                begin
                  Part := FindPart(Parts, SubTableModels);
                  PushIndex(GetLevelModels(FLevelCopy, Size), Part.Addr, Part.Size,
                    Offset);
                  Part := FindPart(Parts, SubModelObjects);
                  PushMove(Offset, Part.Addr, Part.Size);
                end;
              4:
                begin
                  Part := FindPart(Parts, SubLevelData);
                  PushMove(Offset, Part.Addr, Part.Size);
                end;
            end;
            PushZero(Offset);
            if Offset <> Start then
              WadSubfileInfoSet(FLevelSub, I, Start, Offset - Start);
          end;
        end;
      GameSpyro3:
        begin
          for I := 1 to 20 do
          begin
            Start := Offset;
            case I of
              1:
                begin
                  Part := FindPart(Parts, SubGpuTextures);
                  PushMove(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubSpuVag);
                  PushMove(Offset, Part.Addr, Part.Size);
                end;
              2:
                begin
                  Lev := '1';
                  Part := FindPart(Parts, SubTableGround);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelGround + '-' + Lev);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableCollision + '-' + Lev);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableColor);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableBlend);
                  PushMove(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelCollision + '-' + Lev);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelSky);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelPortal);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableParticle);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubEggZone);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableCamera);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableRun);
                  PushMove(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableSound);
                  PushJump(Offset, Part.Addr, Part.Size);
                end;
              3:
                begin
                  Lev := '1';
                  Keep := Offset;
                  Inc(Offset, 4);
                  Part := FindPart(Parts, SubOptimizeGround + '-' + Lev);
                  PushJump(Offset, Part.Addr, Part.Size);

                  Part := FindPart(Parts, SubOptimizeSky + '-' + Lev);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelCollision);
                  PushMove(Offset, Part.Addr, Part.Size);

                  Part := FindPart(Parts, SubTableModels + '-' + Lev);
                  PushIndex(GetLevelModels(FLevelCopy, Size), Part.Addr, Part.Size,
                    Offset);
                  Part := FindPart(Parts, SubModelObjects + '-' + Lev);
                  PushMove(Offset, Part.Addr, Part.Size);
                  CastInt(FLevelSub, Keep)^ := Offset - Keep;
                  Part := FindPart(Parts, SubGpuSublevel + '-' + Lev);
                  PushMove(Offset, Part.Addr, Part.Size);
                end;
              4:
                begin
                  Lev := '1';
                  Part := FindPart(Parts, SubLevelData + '-' + Lev);
                  PushMove(Offset, Part.Addr, Part.Size);
                end;
              5, 7, 9, 11:
                begin
                  Lev := Chr(Ord('0') + ((I - 5) div 2) + 2);
                  Part := FindPart(Parts, SubModelObjects + '-' + Lev);
                  if Part.Addr = nil then
                    Continue;
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableModels + '-' + Lev);
                  Inc(Offset, PushIndex(Cast(FLevelSub, Offset), Part.Addr, Part.Size,
                    0));
                  Part := FindPart(Parts, SubModelGround + '-' + Lev);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubOptimizeGround + '-' + Lev);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubOptimizeSky + '-' + Lev);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubTableCollision + '-' + Lev);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubModelCollision + '-' + Lev);
                  PushJump(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubGpuSublevel + '-' + Lev);
                  PushGpuSub(Offset, Part.Addr, Part.Size);
                end;
              6, 8, 10, 12:
                begin
                  Lev := Chr(Ord('0') + ((I - 6) div 2) + 2);
                  Part := FindPart(Parts, SubLevelData + '-' + Lev);
                  PushMove(Offset, Part.Addr, Part.Size);
                end;
              13, 14, 15, 16, 17, 18, 19, 20:
                begin
                  Lev := Chr(Ord('0') + (I - 13 + 1));
                  Part := FindPart(Parts, SubEggTexture + '-' + Lev);
                  PushMove(Offset, Part.Addr, Part.Size);
                  Part := FindPart(Parts, SubEggModel + '-' + Lev);
                  PushMove(Offset, Part.Addr, Part.Size);
                end;
            end;
            PushZero(Offset);
            if Offset <> Start then
              WadSubfileInfoSet(FLevelSub, I, Start, Offset - Start);
          end;
        end;
    end;
    SetLength(Result, Offset);
  except
    Result := '';
  end;
  FLevelSub := Old;
end;

const
  CutHeader = 'cut-hdr';
  CutTable = 'cut-tbl';
  CutLength = 'cut-len';
  CutModel = 'cut-mdl-';
  CutBlock = 'cut-blk-';
  CutSound = 'cut-snd';
  CutCamera = 'cut-cam';
  CutTest = 'cut-tst-';
  CutObject = 'cut-obj-';

class function TWadManager.CutSubfileExportBlocks(Cutscene: Pointer; Size:
  Integer): ALevelPart;
var
  P, I: Integer;
  R: ALevelPart;
  Blocks, Models, Header, Offset, Count: Integer;
  Data, BlockOffset, BlockSize, ModelOffset: Pinteger;
  From: Pointer;
begin
  SetLength(Result, 0);
  try
    Assure(Size > 32);
    From := Cutscene;
    Data := Cutscene;
    Inc(Data);
    Blocks := Data^;
    Inc(Data);
    Models := Data^;
    Header := (6 + Blocks * 2 + Models) * 4;
    Assure((Blocks > 0) and (Models > 0) and (Size > Header));
    Inc(Data);
    Offset := Data^;
    Inc(Data, 2);
    BlockOffset := Data;
    Inc(Data, Blocks);
    BlockSize := Data;
    Inc(Data, Blocks);
    ModelOffset := Data;
    Inc(ModelOffset);
    SetLength(R, 3 + Models + Blocks);
    P := 0;
    R[P].Addr := Cutscene;
    R[P].Size := 12;
    R[P].Name := CutHeader;
    Inc(P);
    Count := Offset - Data^;
    Assure((Data^ > 0) and (Count > 0) and (Data^ + Count <= Size));
    R[P].Addr := Cast(From, Data^);
    R[P].Size := TrimSize(R[P].Addr, Count);
    R[P].Name := CutTable;
    Inc(P);
    Assure((Offset > 0) and (Data^ + Offset + 16 <= Size));
    R[P].Addr := Cast(From, Offset);
    R[P].Size := 16;
    R[P].Name := CutLength;
    Inc(P);
    for I := 1 to Models do
    begin
      Offset := ModelOffset^;
      Inc(ModelOffset);
      if I = Models then
        Count := Data^ - Offset
      else
        Count := ModelOffset^ - Offset;
      Assure((Offset > 0) and (Count > 0) and (Offset + Count <= Size));
      R[P].Addr := Cast(From, Offset);
      R[P].Size := Count;
      R[P].Name := CutModel + IntToStr(I);
      Inc(P);
    end;
    for I := 1 to Blocks do
    begin
      Offset := BlockOffset^;
      Inc(BlockOffset);
      Count := BlockSize^;
      Inc(BlockSize);
      if Offset + Count > Size then
      begin
        Count := Size - Offset;
        if Count <= 0 then
          Break;
      end;
      Assure((Offset > 0) and (Count > 0) and (Offset + Count <= Size));
      R[P].Addr := Cast(From, Offset);
      R[P].Size := Count;
      R[P].Name := CutBlock + IntToStr(I);
      Inc(P);
    end;
    Result := R;
    SetLength(Result, P);
  except
  end;
end;

procedure CutWrite(var Data: PInteger; From: Pointer; Size: Integer);
begin
  if (Size <= 0) or ((Size and 3) <> 0) then
    Exit;
  CopyMemory(From, Data, Size);
  Inc(Data, Size shr 2);
end;

procedure CutZero(var Data: PInteger; From: Pointer);
var
  Size: Integer;
begin
  Size := CastChar(Data) - From;
  if (Size and 2047) <> 0 then
  begin
    Size := 2048 - (Size and 2047);
    ZeroMemory(Data, Size);
    Inc(Data, Size shr 2);
  end;
end;

class function TWadManager.CutSubfileImportBlocks(const Parts: ALevelPart): DataString;
var
  Index, Size, I: Integer;
  Blocks, Models, Header, Max: Integer;
  Part: RLevelPart;
  From: Pointer;
  Data, StartOffset, BlockOffset, BlockSize, ModelOffset, LastOffset: PInteger;
begin
  Result := '';
  try
    Size := 0;
    for Index := 0 to Length(Parts) - 1 do
    begin
      Inc(Size, Parts[Index].Size);
      if Parts[Index].Size < 0 then
        Exit;
    end;
    if (Size = 0) or (Size > 16 * 1024 * 1024) then
      Exit;
    SetLength(Result, Size * 2);
    From := Cast(Result);
    Part := FindPart(Parts, CutHeader);
    Assure(Part.Size = 12);
    CopyMemory(Part.Addr, From, Part.Size);
    Data := Pointer(From);
    Inc(Data);
    Blocks := Data^;
    Inc(Data);
    Models := Data^;
    Header := (6 + Blocks * 2 + Models) * 4;
    Assure((Blocks > 0) and (Models > 0) and (Size > Header));
    Inc(Data);
    StartOffset := Data;
    Inc(Data, 2);
    BlockOffset := Data;
    Inc(Data, Blocks);
    BlockSize := Data;
    Inc(Data, Blocks);
    LastOffset := Data;
    Inc(Data);
    ModelOffset := Data;
    Inc(Data, Models);
    for I := 1 to Models do
    begin
      ModelOffset^ := CastChar(Data) - From;
      Inc(ModelOffset);
      Part := FindPart(Parts, CutModel + IntToStr(I));
      CutWrite(Data, Part.Addr, Part.Size);
    end;
    LastOffset^ := CastChar(Data) - From;
    Part := FindPart(Parts, CutTable);
    CutWrite(Data, Part.Addr, Part.Size);
    CutZero(Data, From);
    StartOffset^ := CastChar(Data) - From;
    Inc(StartOffset);
    Max := 0;
    for I := 1 to Blocks do
    begin
      CutZero(Data, From);
      BlockOffset^ := CastChar(Data) - From;
      Inc(BlockOffset);
      Part := FindPart(Parts, CutBlock + IntToStr(I));
      CutWrite(Data, Part.Addr, Part.Size);
      if Part.Size > Max then
        Max := Part.Size;
      BlockSize^ := Part.Size;
      Inc(BlockSize);
    end;
    StartOffset^ := Max;
    SetLength(Result, CastChar(Data) - From);
  except
    Result := '';
  end;
end;

class function TWadManager.CutSubfileExportTracks(const Parts: ALevelPart): ALevelData;
var
  Part: RLevelPart;
  Lengs, Mdls: PIntegerArray;
  SoundLen, CameraLen, Models, Blocks, Frames, P, I, T, K, Offset, Count, Model,
    Tres, Size, HeadSize, ModelBlocks: Integer;
  R: ALevelData;
  Save, Hdr: PInteger;
  Vag: TVagEncoder;
  From: Pointer;
  BuffAdd, BuffHdr, BuffDat: DataString;
  SaveAdd, SaveHdr, SaveDat, Head, Pnts: PInteger;
begin
  SetLength(R, 0);
  SetLength(Result, 0);
  Vag := nil;
  try
    Vag := TVagEncoder.Create();
    Part := FindPart(Parts, CutLength);
    Assure(Part.Size = 16);
    Lengs := Part.Addr;
    SoundLen := Lengs[1];
    CameraLen := Lengs[3] - Lengs[2];
    Part := FindPart(Parts, CutHeader);
    Assure(Part.Size = 12);
    Lengs := Part.Addr;
    Frames := Lengs[0];
    Blocks := Lengs[1];
    Models := Lengs[2];
    Assure((Frames > 0) and (Models > 0) and (Blocks > 0) and (SoundLen > 0) and
      (CameraLen > 0));
    SetLength(R, 2 + Models * 2);
    P := 0;
    Assure(Vag.StartRawToVag(SoundLen * Blocks));
    Size := 0;
    for I := 1 to Blocks do
    begin
      Part := FindPart(Parts, CutBlock + IntToStr(I));
      Assure(Part.Size > 16);
      Inc(Size, Part.Size);
      Lengs := Part.Addr;
      Offset := Lengs[0];
      Count := Lengs[1];
      Assure((Count <= SoundLen) and (Count > 0) and (Offset > 0) and (Offset +
        Count <= Part.Size));
      Assure(Vag.PushRawToVag(Cast(Part.Addr, Offset), Count));
    end;
    Assure(Size < 10 * 1024 * 1024);
    R[P].Name := CutSound;
    R[P].Data := Vag.DoneRawToVag(22050);
    Inc(P);
    SetLength(R[P].Data, CameraLen * Blocks);
    Save := Cast(R[P].Data);
    for I := 1 to Blocks do
    begin
      Part := FindPart(Parts, CutBlock + IntToStr(I));
      Lengs := Part.Addr;
      Offset := Lengs[2];
      K := 3;
      while Lengs[K] = 0 do
        Inc(K);
      Count := Lengs[K] - Offset;
      Assure((Count <= CameraLen) and (Count > 0) and (Offset > 0) and (Offset +
        Count <= Part.Size));
      CutWrite(Save, Cast(Part.Addr, Offset), Count);
    end;
    R[P].Name := CutCamera;
    SetLength(R[P].Data, CastChar(Save) - CastChar(R[P].Data));
    Inc(P);
    SetLength(BuffAdd, Size);
    SetLength(BuffHdr, Size);
    SetLength(BuffDat, Size);
    for Model := 1 to Models do
    begin
      Part := FindPart(Parts, CutModel + IntToStr(Model));
      Mdls := Part.Addr;
      ModelBlocks := Mdls[0];
      if ModelBlocks < 1 then
        Continue;
      SaveAdd := Cast(BuffAdd);
      SaveHdr := Cast(BuffHdr);
      SaveDat := Cast(BuffDat);
      if ModelBlocks > Blocks then
      begin
        Mdls[0] := Blocks;
        ModelBlocks := Blocks;
      end;
      Head := SaveHdr;
      Inc(Head, 15);
      HeadSize := 60 + Blocks * 4;
      CutWrite(SaveHdr, Mdls, HeadSize);
      CutWrite(SaveDat, Cast(Part.Addr, HeadSize), Part.Size - HeadSize);
      Tres := Mdls[14];
//      Tres := Part.Size;
      Hdr := @Mdls[15];
      for I := 1 to ModelBlocks do
      begin
        Part := FindPart(Parts, CutBlock + IntToStr(I));
        Lengs := Part.Addr;
        Offset := Lengs[2 + Model];
        From := Part.Addr;
        Assure(Hdr^ + 8 < Part.Size);
        Size := CastByte(From, Hdr^)^ * 4;
        CutWrite(SaveAdd, Cast(From, Offset), Size);
        Head^ := CastChar(SaveHdr) - CastChar(BuffHdr);
        Inc(Head);
        Pnts := SaveHdr;
        Inc(Pnts, 3);
        CutWrite(SaveHdr, Cast(From, Hdr^), CastByte(From, Hdr^)^ * 8 + 36);
        for T := 1 to 6 do
        begin
          if Pnts^ > Tres then
            Pnts^ := Pnts^ - (Offset + Size) + CastChar(SaveDat) - CastChar(BuffDat)
          else
            Pnts^ := Pnts^ - HeadSize;
          if (T = 4) or (T = 5) then
            Pnts^ := CastInt(Pnts, -8)^;
          Inc(Pnts);
        end;
        CutWrite(SaveDat, Cast(From, Offset + Size), Hdr^ - (Offset + Size));
        Inc(Hdr);
      end;
      R[P].Data := Copy(BuffAdd, 1, CastChar(SaveAdd) - CastChar(BuffAdd));
      R[P].Name := CutTest + IntToStr(Model);
      Inc(P);
      Head := Cast(BuffHdr);
      Inc(Head, 14);
      Head^ := CastChar(SaveHdr) - CastChar(BuffHdr);
      CutWrite(SaveHdr, CastChar(BuffDat), CastChar(SaveDat) - CastChar(BuffDat));
      Size := CastChar(SaveHdr) - CastChar(BuffHdr);
      Dec(Head);
      Head^ := Size;
      R[P].Data := Copy(BuffHdr, 1, Size);
      R[P].Name := CutObject + IntToStr(Model);
      Inc(P);
    end;
    Result := R;
  except
  end;
  Vag.Free();
end;

class function TWadManager.CutSubfileGetModel(const Tracks: ALevelData; Index:
  Integer): Integer;
var
  Seek: TextString;
  Loop: Integer;
begin
  Seek := CutObject + IntToStr(Index);
  for Loop := 0 to Length(Tracks) - 1 do
    if Tracks[Loop].Name = Seek then
    begin
      Result := Loop;
      Exit;
    end;
  Result := -1;
end;

function TWadManager.GivePart(Name: TextString; out Size: Integer): Pointer;
var
  Part: RLevelPart;
begin
  Part := FindPart(FParts, Name);
  Result := Part.Addr;
  Size := Part.Size;
end;

function TWadManager.LevelGetVram(out Size: Integer): Pointer;
begin
  Result := GivePart(SubGpuTextures, Size);
end;

function TableModelsGet(Table: Pointer; Index: Integer; out Offset, Entity:
  Integer): Boolean;
begin
  Result := False;
  if (Index < 0) or (Index >= 64) or (Table = nil) then
    Exit;
  Offset := CastInt(Table, Index * 4)^;
  Entity := CastWord(Table, 64 * 4 + Index * 2)^;
  Result := True;
end;

function TWadManager.LevelGetModel(out Size: Integer; Index: Integer; out Entity:
  Integer; Sublevel: Integer = 1): Pointer;
var
  Models: Pointer;
  Table: PIntegerArray;
  Lev: TextString;
  Offset, Next: Integer;
begin
  Lev := IntToStr(Sublevel);
  Result := nil;
  if FGame = gameSpyro3 then
  begin
    Table := GivePart(SubTableModels + '-' + Lev, Size);
    Models := GivePart(SubModelObjects + '-' + Lev, Size);
  end
  else if Sublevel <> 1 then
    Exit
  else
  begin
    Table := GivePart(SubTableModels, Size);
    Models := GivePart(SubModelObjects, Size);
  end;
  if (Table = nil) or (Models = nil) then
    Exit;
  if not TableModelsGet(Table, Index + 1, Next, Entity) then
    Exit;
  if not TableModelsGet(Table, Index, Offset, Entity) then
    Exit;
  if (Next = 0) or (Offset < 0) then
    Exit;
  Dec(Next, Offset);
  if (Next <= 0) or (Size < Offset + Next) then
    Exit;
  Size := Next;
  Result := Cast(Models, Offset);
end;

function TWadManager.LevelGetEggModel(out Size: Integer; Index: Integer): Pointer;
var
  Lev: TextString;
begin
  Lev := IntToStr(Index);
  Result := GivePart(SubEggModel + '-' + Lev, Size);
end;

function TWadManager.LevelGetEggTexture(Index: Integer; Vram: TVram; out X, Y:
  Integer): Boolean;
var
  Lev: TextString;
  Size: Integer;
  Texture: Pointer;
begin
  Result := False;
  Lev := IntToStr(Index);
  Texture := GivePart(SubEggTexture + '-' + Lev, Size);
  if (Texture = nil) or (Vram = nil) then
    Exit;
  if not Vram.Open(64, 96) then
    Exit;
  if not Vram.ReadFrom(Texture, Size) then
    Exit;
  X := 384;
  Y := 256;
  Result := True;
end;

class function TWadManager.ModelAnimated(Model: Pointer): Boolean;
begin
  Result := PInteger(Model)^ > 0;
end;

class function TWadManager.ModelFrames(Model: Pointer): Integer;
begin
  Result := PInteger(Model)^;
  if Result < 0 then
    Result := -Result;
end;

function TWadManager.LevelGetSublevelVram(Index: Integer; Vram: TVram; out X, Y:
  Integer): Boolean;
var
  Lev: TextString;
  Size: Integer;
  Texture: Pointer;
  Header: PSublevelTexture;
begin
  Result := False;
  Lev := IntToStr(Index);
  Header := GivePart(SubGpuSublevel + '-' + Lev, Size);
  if (Header = nil) or (Vram = nil) then
    Exit;
  X := Header.X - 512;
  Y := Header.Y;
  if (Header.W <= 0) or (Header.H <= 0) or (Header.S < 0) then
    Exit;
  if not Vram.Open(Header.W, Header.H) then
    Exit;
  Texture := Cast(@Header.S, Header.S);
  if not Vram.ReadFrom(Texture, Size) then
    Exit;
  Result := True;
end;

end.

