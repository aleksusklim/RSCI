unit SHL_PosWriter; // SpyroHackingLib is licensed under WTFPL

interface

uses
  SysUtils, Classes, SHL_Files, SHL_Types;

type
  TPosWriter = class(TObject)
  private
    FStream: THandleStream;
    FCount: Integer;
  private
  public
    destructor Destroy(); override;
  public
    function Start(Filename: WideString): Boolean;
    procedure Close();
    function Add(Offset, Size: Int64; Color: Integer; const Text: TextString =
      ''): Boolean;
  end;

implementation

destructor TPosWriter.Destroy();
begin
  Close();
  inherited Destroy();
end;

function TPosWriter.Start(Filename: WideString): Boolean;
const
  Header = 'WinHex Pos v2.0'#0#0#0#0#0#0#0#0#0;
begin
  Close();
  FStream := SFiles.OpenNew(Filename);
  if FStream <> nil then
  begin
    Result := FStream.Write(Header, Length(Header)) = Length(Header);
  end
  else
    Result := False;
end;

procedure TPosWriter.Close();
begin
  if FCount <> 0 then
  begin
    FStream.Position := 20;
    FStream.Write(FCount, 4);
  end;
  FCount := 0;
  SFiles.CloseStream(FStream);
end;

function TPosWriter.Add(Offset, Size: Int64; Color: Integer; const Text:
  TextString = ''): Boolean;
var
  Spec: packed record
    Body: packed record
      Offset, Size, Time: Int64;
      RGB_Flags: Integer;
      DescrLen: Word;
    end;
    Descr: array[0..8191] of TextChar;
  end;
var
  Len: Integer;
begin
  Result := False;
  if FStream = nil then
    Exit;
  with Spec do
  begin
    Body.Offset := Offset;
    Body.Size := Size;
    Body.Time := 0;
    Body.RGB_Flags := Color and $ffffff;
    Len := Length(Text);
    if Len > 8192 then
      Len := 8192;
    Body.DescrLen := Len;
    if Len <> 0 then
      CopyMemory(Cast(Text), Cast(Descr), Len);
    Inc(Len, SizeOf(Body));
    Result := FStream.Write(Body, Len) = Len;
    Inc(FCount);
  end;
end;

end.

