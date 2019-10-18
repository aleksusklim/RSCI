unit SHL_IsoReader; // SpyroHackingLib is licensed under WTFPL

interface

uses
  SysUtils, Classes, SHL_Types;

type
  NImageFormat = (ifUnknown, ifIso, ifMdf, ifStr, ifEcm);

type
  TIsoReader = class(TFileStream)
  private
    FCachedSize: Integer;
    FSectorsCount: Integer;
    FHeader: Integer;
    FFooter: Integer;
    FBody: Integer;
    FOffset: Integer;
    FTotal: Integer;
    FSector: Integer;
    FEcm: Boolean;
  protected
    function GetSize(): Int64; override;
  public
    constructor Create(Filename: TextString; DenyWrite: Boolean = False);
    constructor CreateWritable(Filename: TextString; DenyWrite: Boolean = False);
  public
    function SetFormat(Header: Integer = 0; Footer: Integer = 0; Body: Integer =
      2336; Ecm: Boolean = False): Boolean; overload;
    function SetFormat(Format: NImageFormat): Boolean; overload;
    procedure SeekToSector(Sector: Integer);
    function ReadSectors(SaveDataTo: Pointer; Count: Integer = 0): Integer;
    function WriteSectors(ReadDataFrom: Pointer; Count: Integer = 0): Integer;
    function GuessImageFormat(Text: PTextChar = nil): NImageFormat;
  public
    property SectorsCount: Integer read FSectorsCount;
    property Header: Integer read FHeader;
    property Footer: Integer read FFooter;
    property Body: Integer read FBody;
    property Total: Integer read FTotal;
    property Offset: Integer read FOffset;
    property Sector: Integer read FSector write SeekToSector;
  end;

implementation

function TIsoReader.GetSize(): Int64;
begin
  Result := Int64(FCachedSize);
end;

constructor TIsoReader.Create(Filename: TextString; DenyWrite: Boolean = False);
begin
  if DenyWrite then
    inherited Create(Filename, fmOpenRead or fmShareDenyWrite)
  else
    inherited Create(Filename, fmOpenRead or fmShareDenyNone);
  SetFormat();
end;

function TIsoReader.SetFormat(Header: Integer = 0; Footer: Integer = 0; Body:
  Integer = 2336; Ecm: Boolean = False): Boolean;
begin
  if Ecm then
  begin
    FEcm := True;
    Result := True;
    FHeader := -1;
    FBody := -1;
    FTotal := -1;
    FCachedSize := -1;
    FSectorsCount := -1;
    Exit;
  end;
  FEcm := False;
  FHeader := Header;
  FFooter := Footer;
  FBody := Body;
  FTotal := FHeader + FBody + FFooter;
  FCachedSize := Integer(inherited GetSize());
  FSectorsCount := FCachedSize div FTotal;
  Result := (FCachedSize mod FTotal) = 0;
end;

function TIsoReader.SetFormat(Format: NImageFormat): Boolean;
begin
  Result := False;
  case Format of
    ifIso:
      Result := SetFormat(16, 0);
    ifMdf:
      Result := SetFormat(16, 96);
    ifStr:
      Result := SetFormat(0, 0);
    ifEcm:
      Result := SetFormat(0, 0, 0, True);
    ifUnknown:
      Result := SetFormat();
  end;
end;

procedure TIsoReader.SeekToSector(Sector: Integer);
begin
  FSector := Sector;
  Position := Int64(FOffset) + Int64(FTotal) * Int64(FSector) + Int64(FHeader);
end;

function TIsoReader.ReadSectors(SaveDataTo: Pointer; Count: Integer = 0): Integer;
begin
  if Count = 0 then
    Result := Ord(inherited Read(SaveDataTo^, FBody) = FBody)
  else
    Result := inherited Read(SaveDataTo^, FTotal * Count) div FTotal;
  Inc(FSector, Result);
end;

function TIsoReader.WriteSectors(ReadDataFrom: Pointer; Count: Integer = 0): Integer;
begin
  if Count = 0 then
    Result := Ord(inherited Write(ReadDataFrom^, FBody) = FBody)
  else
    Result := inherited Write(ReadDataFrom^, FTotal * Count) div FTotal;
  Inc(FSector, Result);
end;

function TIsoReader.GuessImageFormat(Text: PTextChar = nil): NImageFormat;
var
  Sector: array[0..615] of Integer;
  OldPos: Integer;
const
  ID_ECM = 5063493;
begin
  Result := ifUnknown;
  FBody := 2336;
  FHeader := 0;
  FFooter := 0;
  OldPos := Position;
  Inits(Sector);
  ReadBuffer(Sector, 2464);
  Position := OldPos;
  if Sector[0] = ID_ECM then
    Result := ifEcm
  else
    while True do
    begin
      if (Sector[0] = Sector[1]) and (Sector[584] = Sector[585]) then
      begin
        if Text <> nil then
          StrCopy(Text, 'STR');
        Result := ifStr;
        Break;
      end;
      FHeader := 16;
      if (Sector[0] = Sector[588]) and (Sector[1] = Sector[589]) then
      begin
        if Text <> nil then
          StrCopy(Text, 'ISO');
        Result := ifIso;
        Break;
      end;
      FFooter := 96;
      if (Sector[0] = Sector[612]) and (Sector[1] = Sector[613]) then
      begin
        if Text <> nil then
          StrCopy(Text, 'MDF');
        Result := ifMdf;
        Break;
      end;
      if Text <> nil then
        StrCopy(Text, 'UNK');
      Break;
    end;
  SetFormat(Result);
end;

constructor TIsoReader.CreateWritable(Filename: TextString; DenyWrite: Boolean = False);
begin
  if FileExists(Filename) then
  begin
    if DenyWrite then
      inherited Create(Filename, fmOpenReadWrite or fmShareDenyWrite)
    else
      inherited Create(Filename, fmOpenReadWrite or fmShareDenyNone);
  end
  else
    inherited Create(Filename, fmCreate);
  SetFormat();
end;

end.

