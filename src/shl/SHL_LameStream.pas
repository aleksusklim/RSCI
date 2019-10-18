unit SHL_LameStream; // SpyroHackingLib is licensed under WTFPL

interface

uses
  SysUtils, Classes, SHL_ProcessStream, SHL_Types;

type
  TLameStream = class(TStream)
  private
    FLame: WideString;
    FProcess: TProcessStream;
    FIsEncode, FIsDecode: Boolean;
//    FDump: TFileStream;
  public
    constructor Create(const PathToLamaExe: WideString);
    destructor Destroy(); override;
  public
    procedure Decode(const ReadFromMp3: WideString; NoHeader: Boolean = False);
    procedure Encode(const SaveToMp3: WideString; InRate, OutRate: TextString;
      InStereo, OutStereo: Boolean);
    procedure WaitExit(Timeout: Integer = 10000);
    function IsTerminated(): Boolean;
    procedure SetPriority(Prio: Integer);
    function Write(const Buffer; Count: Integer): Integer; override;
    function Read(var Buffer; Count: Integer): Integer; override;
    function Seek(Offset: Integer; Origin: Word): Integer; override;
  end;

implementation

constructor TLameStream.Create(const PathToLamaExe: WideString);
begin
  inherited Create();
  FLame := PathToLamaExe;
  if not FileExists(FLame) then
    Abort;
//  FDump := TFileStream.Create(IntToStr(GetTickCount()) + '_.wav', fmCreate);
end;

destructor TLameStream.Destroy();
begin
  FProcess.Free();
//  FDump.Free();
  inherited Destroy();
end;

procedure TLameStream.WaitExit(Timeout: Integer = 10000);
begin
  if FIsEncode then
    FProcess.Close(True, False);
  if FIsDecode then
    FProcess.Close(False, True);
  FProcess.IsRunning(Timeout);
end;

procedure TLameStream.Encode(const SaveToMp3: WideString; InRate, OutRate:
  TextString; InStereo, OutStereo: Boolean);
var
  Line: WideString;
begin
  FIsEncode := True;
  Line:='';
  if InStereo and OutStereo then
    Line := ' -m j'
  else if InStereo and not OutStereo then
    Line := ' -a'
  else if not InStereo and OutStereo then
    Line := ' -m d'
  else if not InStereo and not OutStereo then
    Line := ' -m m';
  Line := ExtractFileName(FLame) + Line + ' -r -x -s ' + WideString(InRate) +
    ' --resample ' + WideString(OutRate) + ' --silent --preset extreme - "' +
    SaveToMp3 + '"';
  FProcess := TProcessStream.Create(FLame, Line, '', True, False, False, False);
end;

procedure TLameStream.Decode(const ReadFromMp3: WideString; NoHeader: Boolean = False);
var
  Line: WideString;
begin
  FIsDecode := True;
  Line := ExtractFileName(FLame);
  if NoHeader then
    Line := Line + ' -t';
  Line := Line + ' --quiet --decode "' + ReadFromMp3 + '" -';
  FProcess := TProcessStream.Create(FLame, Line, '', False, True, False, False);
end;

function TLameStream.IsTerminated(): Boolean;
begin
  Result := not FProcess.IsRunning();
end;

procedure TLameStream.SetPriority(Prio: Integer);
begin
  FProcess.SetPriority(Prio);
end;

function TLameStream.Write(const Buffer; Count: Integer): Integer;
begin
  Result := FProcess.Write(Buffer, Count);
end;

function TLameStream.Read(var Buffer; Count: Integer): Integer;
begin
  Result := FProcess.Read(Buffer, Count);
//  FDump.Write(Buffer, Result);
end;

function TLameStream.Seek(Offset: Integer; Origin: Word): Integer;
begin
  Ignore(Offset, Origin);
  Result := 0;
end;

end.

