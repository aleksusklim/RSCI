unit SHL_VagEncoder; // SpyroHackingLib is licensed under WTFPL

interface

uses
  Windows, SysUtils, Classes, SHL_Types;

type
  NVagConversionMode = (EncVagModeNormal = 1, EncVagModeHigh = 2, EncVagModeLow
    = 3, EncVagMode4bit = 4);

  NVagBlockAttribute = (EncVag1Shot = 0, EncVag1ShotEnd = 1, EncVagLoopStart = 2,
    EncVagLoopBody = 3, EncVagLoopEnd = 4);

type
  TVagEncoder = class(TObject)
  private
    FDllHandle: THandle;
    FEncVagInit, FEncVag, FEncVagFin: Pointer;
    FVagFile: DataString;
    FVagSize, FVagMax: Integer;
    FVagData: Pointer;
  private
    function OpenLibrary(Handle: THandle): Boolean;
  public
    constructor Create();
    destructor Destroy(); override;
  public
    function OpenEncVagLibrary(DllFilename: WideString): Boolean; overload;
    function OpenEncVagLibrary(DllFilename: TextString): Boolean; overload;
    procedure CloseEncVagLibrary();
    function EncVagInit(conversion_mode: NVagConversionMode): Boolean;
    function EncVag(x, y: Pointer; block_attribute: NVagBlockAttribute): Boolean;
    function EncVagFin(y: Pointer): Boolean;
    function StartRawToVag(MaxSize: Integer): Boolean;
    function PushRawToVag(From: Pointer; Size: Integer): Boolean;
    function DoneRawToVag(SampleRate: Integer): DataString;
  end;

implementation

type
  PEncVagInit = procedure(conversion_mode: Word); stdcall;

  PEncVag = procedure(x, y: PWord; block_attribute: Word); stdcall;

  PEncVagFin = procedure(y: PWord); stdcall;

const
  VAGp = $70474156;

type
  RVagHeader = packed record
    format, ver, ssa, size, fs: Integer;
    volL, volR, pitch, ADSR1, ADSR2, reserved: Word;
    name: array[0..15] of TextChar;
  end;

  PVagHeader = ^RVagHeader;

constructor TVagEncoder.Create();
begin
  inherited Create();
end;

destructor TVagEncoder.Destroy();
begin
  CloseEncVagLibrary();
  DoneRawToVag(0);
  inherited Destroy();
end;

function TVagEncoder.OpenLibrary(Handle: THandle): Boolean;
var
  EncVagInit, EncVag, EncVagFin: Pointer;
begin
  Result := False;
  if (Handle = 0) or (Handle = INVALID_HANDLE_VALUE) then
    Exit;
  EncVagInit := GetProcAddress(Handle, Cast('EncVagInit'));
  EncVag := GetProcAddress(Handle, Cast('EncVag'));
  EncVagFin := GetProcAddress(Handle, Cast('EncVagFin'));
  if (EncVagInit = nil) or (EncVag = nil) or (EncVagFin = nil) then
  begin
    FreeLibrary(Handle);
    Exit;
  end;
  Result := True;
  CloseEncVagLibrary();
  FDllHandle := Handle;
  FEncVagInit := EncVagInit;
  FEncVag := EncVag;
  FEncVagFin := EncVagFin;
end;

function TVagEncoder.OpenEncVagLibrary(DllFilename: WideString): Boolean;
begin
  Result := OpenLibrary(LoadLibraryW(PWideChar(DllFilename)));
end;

function TVagEncoder.OpenEncVagLibrary(DllFilename: TextString): Boolean;
begin
  Result := OpenLibrary(LoadLibraryA(PTextChar(DllFilename)));
end;

procedure TVagEncoder.CloseEncVagLibrary();
begin
  if FDllHandle = 0 then
    Exit;
  FreeLibrary(FDllHandle);
  FDllHandle := 0;
  FEncVagInit := nil;
  FEncVag := nil;
  FEncVagFin := nil;
end;

function TVagEncoder.EncVagInit(conversion_mode: NVagConversionMode): Boolean;
var
  ConversionMode: Word;
begin
  ConversionMode := Word(conversion_mode);
  if (FEncVagInit = nil) or not (ConversionMode in [1..4]) then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  PEncVagInit(FEncVagInit)(ConversionMode);
end;

function TVagEncoder.EncVag(x, y: Pointer; block_attribute: NVagBlockAttribute): Boolean;
var
  BlockAttribute: Word;
begin
  BlockAttribute := Word(block_attribute);
  if (FEncVag = nil) or (x = nil) or (y = nil) or not (BlockAttribute in [0..4]) then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  PEncVag(FEncVag)(x, y, BlockAttribute);
end;

function TVagEncoder.EncVagFin(y: Pointer): Boolean;
begin
  if (FEncVagFin = nil) or (y = nil) then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  PEncVagFin(FEncVagFin)(y);
end;

function TVagEncoder.StartRawToVag(MaxSize: Integer): Boolean;
begin
  Result := False;
  FVagFile := '';
  FVagSize := 0;
  FVagMax := 0;
  FVagData := nil;
  try
    Assure(MaxSize > 0);
    SetLength(FVagFile, MaxSize + SizeOf(RVagHeader));
    Result := True;
    FVagMax := MaxSize;
    FVagData := Cast(FVagFile);
    ZeroMemory(FVagData, SizeOf(RVagHeader));
    Adv(FVagData, SizeOf(RVagHeader));
  except
    FVagFile := '';
  end;
end;

function TVagEncoder.PushRawToVag(From: Pointer; Size: Integer): Boolean;
begin
  Result := False;
  if (From = nil) or (Size < 1) then
    Exit;
  if FVagMax - Size >= 0 then
    Result := True;
  if Size > FVagMax then
  begin
    Size := FVagMax;
    FVagMax := -1;
  end
  else
    Dec(FVagMax, Size);
  if Size > 0 then
  begin
    CopyMemory(From, FVagData, Size);
    Adv(FVagData, Size);
    Inc(FVagSize, Size);
  end;
end;

function TVagEncoder.DoneRawToVag(SampleRate: Integer): DataString;
var
  Header: PVagHeader;
begin
  Result := '';
  if FVagData = nil then
    Exit;
  Result := FVagFile;
  FVagFile := '';
  SetLength(Result, FVagSize + SizeOf(RVagHeader));
  Header := Cast(Result);
  Header.format := VAGp;
  Header.ver := 2;
  Header.size := LittleInteger(FVagSize);
  Header.fs := LittleInteger(SampleRate);
  FVagSize := 0;
  FVagMax := 0;
  FVagData := nil;
end;

end.

