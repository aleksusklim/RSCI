unit SHL_Gzip; // SemVersion: 0.1.0

interface  // SpyroHackingLib is licensed under WTFPL

uses
  SHL_Types, SysUtils, Classes;

type
  TGzipFile = class(TStream)
    constructor CreateRead(Filename: TextString);
    constructor CreateNew(Filename: TextString; Level: Integer = 1);
    destructor Destroy(); override;
  public
    function Write(const Buffer; Count: Integer): Integer; override;
    function Read(var Buffer; Count: Integer): Integer; override;
    function Seek(Offset: Integer; Origin: Word): Integer; override;
  protected
    function GetSize(): Int64; override;
  private
    FStream: TFileStream;
    FGzip: Pointer;
  end;

implementation

{$IFDEF SHL_GNU}

uses
  GNU_gzip;

{$ELSE}

function gzopen(strm: TStream; mode: TextString; dstream: boolean = false): Pointer;
begin
  Ignore(mode, dstream);
  Result := strm;
end;

function gzread(f: Pointer; buf: Pointer; len: Integer): Integer;
begin
  Result := TStream(f).Read(buf^, len);
end;

function gzwrite(f: Pointer; buf: Pointer; len: Integer): Integer;
begin
  Result := TStream(f).Write(buf^, len);
end;

function gzclose(f: Pointer): Integer;
begin
  Ignore(f);
  Result := 0;
end;

{$ENDIF}

constructor TGzipFile.CreateRead(Filename: TextString);
begin
  FStream := TFileStream.Create(Filename, fmOpenRead or fmShareDenyNone);
  FGzip := gzopen(FStream, 'r');
end;

constructor TGzipFile.CreateNew(Filename: TextString; Level: Integer = 1);
begin
  FStream := TFileStream.Create(Filename, fmCreate);
  FGzip := gzopen(FStream, 'w' + Chr(Ord('0') + Level));
end;

destructor TGzipFile.Destroy();
begin
  gzclose(FGzip);
  FStream.Free();
end;

function TGzipFile.Write(const Buffer; Count: Integer): Integer;
begin
  Result := gzwrite(FGzip, @Buffer, Count);
end;

function TGzipFile.Read(var Buffer; Count: Integer): Integer;
begin
  Result := gzread(FGzip, @Buffer, Count);
end;

function TGzipFile.Seek(Offset: Integer; Origin: Word): Integer;
begin
  Ignore(Offset, Origin);
  Result := 0;
end;

function TGzipFile.GetSize(): Int64;
begin
  Result := 0;
end;

end.

