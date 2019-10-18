unit SHL_ProcessStream; // SpyroHackingLib is licensed under WTFPL

interface

uses
  Windows, SysUtils, Classes, SHL_Types;

type
  TProcessStream = class(TStream)
  private
    FName, FComm, FDir: WideString;
    OutRead, OutWrite, InRead, InWrite, ErrRead, ErrWrite: THandle;
    FProcHand: THandle;
    FStdIn, FStdOut, FStdErr: THandleStream;
  public
    constructor Create(const ExecutableName, CommandLine, WorkDirectory:
      WideString; ReadPipe, WritePipe: Boolean; ErrPipe: Boolean = False; ToStd:
      Boolean = True);
    destructor Destroy(); override;
  public
    function IsRunning(Timeout: Integer = 0): Boolean;
    procedure SetPriority(Prio: Integer);
    function Write(const Buffer; Count: Integer): Integer; override;
    function Read(var Buffer; Count: Integer): Integer; override;
    function Seek(Offset: Integer; Origin: Word): Integer; override;
    procedure Close(Read: Boolean; Write: Boolean = False; Error: Boolean = False);
  public
    property StdIn: THandleStream read FStdIn write FStdIn;
    property StdOut: THandleStream read FStdOut write FStdOut;
    property StdErr: THandleStream read FStdErr write FStdErr;
  end;

implementation

{$IFDEF FPC}
type
  STARTUPINFO = STARTUPINFOW;
{$ENDIF}

constructor TProcessStream.Create(const ExecutableName, CommandLine,
  WorkDirectory: WideString; ReadPipe, WritePipe: Boolean; ErrPipe: Boolean =
  False; ToStd: Boolean = True);
var
  SI: STARTUPINFO;
  PI: PROCESS_INFORMATION;
  SA: SECURITY_ATTRIBUTES;
  Err: Integer;
  PDir: PWideChar;
begin
  inherited Create();
  Err := 0;
  FName := ExecutableName + #0#0;
  FComm := CommandLine + #0#0;

  if WorkDirectory = '' then
    PDir := nil
  else
  begin
    FDir := WorkDirectory + #0#0;
    PDir := PWideChar(FDir);
  end;

  ZeroMemory(@SI, SizeOf(STARTUPINFO));
  ZeroMemory(@PI, SizeOf(PROCESS_INFORMATION));
  ZeroMemory(@SA, SizeOf(SECURITY_ATTRIBUTES));

  SI.cb := SizeOf(STARTUPINFO);
  SA.nLength := SizeOf(SECURITY_ATTRIBUTES);
  SA.bInheritHandle := True;

  if ReadPipe then
    CreatePipe(InRead, InWrite, @SA, 0);
  if WritePipe then
    CreatePipe(OutRead, OutWrite, @SA, 0);
  if ErrPipe then
    CreatePipe(ErrRead, ErrWrite, @SA, 0);

  if ReadPipe then
    SetHandleInformation(InWrite, HANDLE_FLAG_INHERIT, 0);
  if WritePipe then
    SetHandleInformation(OutRead, HANDLE_FLAG_INHERIT, 0);
  if ErrPipe then
    SetHandleInformation(ErrRead, HANDLE_FLAG_INHERIT, 0);

  if ReadPipe then
    SI.hStdInput := InRead
  else if ToStd then
    SI.hStdInput := GetStdHandle(STD_INPUT_HANDLE);
  if WritePipe then
    SI.hStdOutput := OutWrite
  else if ToStd then
    SI.hStdOutput := GetStdHandle(STD_OUTPUT_HANDLE);
  if ErrPipe then
    SI.hStdError := ErrWrite
  else if ToStd then
    SI.hStdError := GetStdHandle(STD_ERROR_HANDLE);

  SI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_HIDE;
  if not CreateProcessW(PWideChar(FName), PWideChar(FComm), nil, nil, True,
    CREATE_NO_WINDOW, nil, PDir, SI, PI) then
    Err := GetLastError();

  if ReadPipe then
    CloseHandle(InRead);
  if WritePipe then
    CloseHandle(OutWrite);
  if ErrPipe then
    CloseHandle(ErrWrite);

  if PI.dwProcessId = 0 then
    raise Exception.Create(IntToStr(Err));
  if ReadPipe then
    StdIn := THandleStream.Create(InWrite);
  if WritePipe then
    StdOut := THandleStream.Create(OutRead);
  if ErrPipe then
    StdErr := THandleStream.Create(ErrRead);

  CloseHandle(PI.hThread);
  FProcHand := PI.hProcess;
end;

destructor TProcessStream.Destroy();
begin
  Close(True, True, True);
  if FProcHand <> 0 then
    if IsRunning() then
      TerminateProcess(FProcHand, 1);
  CloseHandle(FProcHand);
  inherited Destroy();
end;

function TProcessStream.IsRunning(Timeout: Integer = 0): Boolean;
begin
  Result := (WaitForSingleObject(FProcHand, Timeout) = WAIT_TIMEOUT);
end;

procedure TProcessStream.SetPriority(Prio: Integer);
begin
  SetPriorityClass(FProcHand, Prio);
end;

procedure TProcessStream.Close(Read: Boolean; Write: Boolean = False; Error:
  Boolean = False);
begin
  if Read and (StdIn <> nil) then
  begin
    StdIn.Free();
    CloseHandle(InWrite);
    StdIn := nil;
    InWrite := 0;
  end;
  if Write and (StdOut <> nil) then
  begin
    StdOut.Free();
    CloseHandle(OutRead);
    StdOut := nil;
    OutRead := 0;
  end;
  if Error and (StdErr <> nil) then
  begin
    StdErr.Free();
    CloseHandle(ErrRead);
    StdErr := nil;
    ErrRead := 0;
  end;
end;

function TProcessStream.Write(const Buffer; Count: Integer): Integer;
begin
  if StdIn <> nil then
    Result := StdIn.Write(Buffer, Count)
  else
    Result := 0;
end;

function TProcessStream.Read(var Buffer; Count: Integer): Integer;
begin
  if StdOut <> nil then
    Result := StdOut.Read(Buffer, Count)
  else
    Result := 0;
end;

function TProcessStream.Seek(Offset: Integer; Origin: Word): Integer;
begin
  Ignore(Offset, Origin);
  Result := 0;
end;

end.

