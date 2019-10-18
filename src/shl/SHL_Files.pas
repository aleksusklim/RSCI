unit SHL_Files; // SpyroHackingLib is licensed under WTFPL

interface

uses
  Windows, Classes, SysUtils, SHL_TextUtils, SHL_Types;

type
  RHandles = record
    Read, Write, Error: THandle;
  end;

type
  RFindFile = record
    Name: WideString;
    Attr: Integer;
    Size: Int64;
    CreationTime, WriteTime: TFileTime;
  end;

  AFindFile = array of RFindFile;

type
  SFiles = class
  private
    class function ScanAndGet(const Text: WideString; Delim: SetOfChar; Tail:
      Boolean): WideString;
    class function ReadFile(Stream: THandleStream; MaxSize: Integer): DataString;
    class function WriteFile(Stream: THandleStream; Data: Pointer; Size: Integer):
      Boolean;
  public
    class function ReadEntireFile(const Filename: TextString; MaxSize: Integer =
      -1): DataString; overload;
    class function ReadEntireFile(const Filename: WideString; MaxSize: Integer =
      -1): DataString; overload;
    class function WriteEntireFile(const Filename: TextString; Data: Pointer;
      Size: Integer): Boolean; overload;
    class function WriteEntireFile(const Filename: WideString; Data: Pointer;
      Size: Integer): Boolean; overload;
    class function WriteEntireFile(const Filename: TextString; const Data:
      DataString): Boolean; overload;
    class function WriteEntireFile(const Filename: WideString; const Data:
      DataString): Boolean; overload;
    class function OpenRead(const Filename: TextString): THandleStream; overload;
    class function OpenRead(const Filename: WideString): THandleStream; overload;
    class function OpenWrite(const Filename: TextString): THandleStream; overload;
    class function OpenWrite(const Filename: WideString): THandleStream; overload;
    class function OpenNew(const Filename: TextString): THandleStream; overload;
    class function OpenNew(const Filename: WideString): THandleStream; overload;
    class function OpenConsole(const Filename: TextString): THandle;
    class procedure CloseStream(var Stream: THandleStream);
    class function GetArguments(): ArrayOfWide;
    class function GetExecutable(): WideString;
    class function GetProgramDirectory(): WideString;
    class function RemoveLastSlash(const Filepath: WideString): WideString;
    class function GetLastSlash(const Filepath: WideString; Noslash: Boolean =
      False): WideString;
    class function RemoveExtension(const Filepath: WideString): WideString;
    class function GetExtension(const Filepath: WideString): WideString;
    class function NoBackslash(const Filepath: WideString): WideString;
    class procedure ResetCurrentDir();
    class function IsDirectory(const Filepath: WideString): Boolean;
    class function Exists(const Filepath: WideString): Boolean;
    class function GetFullName(const Filepath: WideString): WideString;
    class function CreateDirectory(const Filepath: WideString): Boolean;
    class function GetAllFiles(const Dir: WideString; Folders: Trilean =
      Anything): ArrayOfWide;
    class function GetAllFilesExt(const Mask: WideString): AFindFile;
    class function RedirectFile(out Old: RHandles; const Read, Write, Error:
      WideString): Boolean;
    class procedure RedirectRestore(var Old: RHandles);
    class function UseCurrentDirectory(const Path: WideString = ''): WideString;
    class function DeleteFile(const Filename: WideString): Boolean;
    class function CopyFile(const Source, Target: WideString; Owerride: Boolean): Boolean;
    class procedure SetTime(Filename: WideString; const CreationTime, WriteTime:
      FILETIME);
    class function RecursiveDirectory(Create: WideString): Boolean;
    class function DeleteEmptyDirs(const Root: WideString): Boolean;
  end;

implementation

class function SFiles.ReadFile(Stream: THandleStream; MaxSize: Integer): DataString;
begin
  if (Stream = nil) or ((MaxSize >= 0) and (Stream.Size > MaxSize)) then
    Result := ''
  else
  begin
    SetLength(Result, Stream.Size);
    SetLength(Result, Stream.Read(Cast(Result)^, Length(Result)));
  end;
  CloseStream(Stream);
end;

class function SFiles.ReadEntireFile(const Filename: TextString; MaxSize:
  Integer = -1): DataString;
begin
  Result := ReadFile(OpenRead(Filename), MaxSize);
end;

class function SFiles.ReadEntireFile(const Filename: WideString; MaxSize:
  Integer = -1): DataString;
begin
  Result := ReadFile(OpenRead(Filename), MaxSize);
end;

class function SFiles.WriteFile(Stream: THandleStream; Data: Pointer; Size:
  Integer): Boolean;
begin
  Result := False;
  if Stream <> nil then
  begin
    if (Data <> nil) and (Size > 0) then
      Result := Stream.Write(Data^, Size) = Size;
    CloseStream(Stream);
  end;
end;

class function SFiles.WriteEntireFile(const Filename: TextString; Data: Pointer;
  Size: Integer): Boolean;
begin
  Result := WriteFile(OpenNew(Filename), Data, Size);
end;

class function SFiles.WriteEntireFile(const Filename: WideString; Data: Pointer;
  Size: Integer): Boolean;
begin
  Result := WriteFile(OpenNew(Filename), Data, Size);
end;

class function SFiles.WriteEntireFile(const Filename: TextString; const Data:
  DataString): Boolean;
begin
  Result := WriteFile(OpenNew(Filename), Cast(Data), Length(Data));
end;

class function SFiles.WriteEntireFile(const Filename: WideString; const Data:
  DataString): Boolean;
begin
  Result := WriteFile(OpenNew(Filename), Cast(Data), Length(Data));
end;

class function SFiles.OpenRead(const Filename: TextString): THandleStream;
var
  Handle: Integer;
begin
  Handle := CreateFileA(Cast(Filename), GENERIC_READ, FILE_SHARE_READ or
    FILE_SHARE_WRITE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if (Handle <> 0) and (Handle <> -1) then
    Result := THandleStream.Create(Handle)
  else
    Result := nil;
end;

class function SFiles.OpenRead(const Filename: WideString): THandleStream;
var
  Handle: Integer;
begin
  Handle := CreateFileW(PWideChar(Filename), GENERIC_READ, FILE_SHARE_READ or
    FILE_SHARE_WRITE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if (Handle <> 0) and (Handle <> -1) then
    Result := THandleStream.Create(Handle)
  else
    Result := nil;
end;

class function SFiles.OpenWrite(const Filename: TextString): THandleStream;
var
  Handle: Integer;
begin
  Handle := CreateFileA(Cast(Filename), GENERIC_READ or GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if (Handle <> 0) and (Handle <> -1) then
    Result := THandleStream.Create(Handle)
  else
    Result := nil;
end;

class function SFiles.OpenWrite(const Filename: WideString): THandleStream;
var
  Handle: Integer;
begin
  Handle := CreateFileW(PWideChar(Filename), GENERIC_READ or GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if (Handle <> 0) and (Handle <> -1) then
    Result := THandleStream.Create(Handle)
  else
    Result := nil;
end;

class function SFiles.OpenNew(const Filename: TextString): THandleStream;
var
  Handle: Integer;
begin
  Handle := CreateFileA(Cast(Filename), GENERIC_READ or GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if (Handle <> 0) and (Handle <> -1) then
    Result := THandleStream.Create(Handle)
  else
    Result := nil;
end;

class function SFiles.OpenNew(const Filename: WideString): THandleStream;
var
  Handle: Integer;
begin
  Handle := CreateFileW(PWideChar(Filename), GENERIC_READ or GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if (Handle <> 0) and (Handle <> -1) then
    Result := THandleStream.Create(Handle)
  else
    Result := nil;
end;

class function SFiles.OpenConsole(const Filename: TextString): THandle;
begin
  Result := CreateFileA(Cast(Filename), GENERIC_READ or GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
  if Result = INVALID_HANDLE_VALUE then
    Result := 0;
end;

class procedure SFiles.CloseStream(var Stream: THandleStream);
var
  Handle: Integer;
begin
  if Stream <> nil then
  begin
    Handle := Stream.Handle;
    Stream.Destroy();
    Stream := nil;
    CloseHandle(Handle);
  end;
end;

class function SFiles.GetArguments(): ArrayOfWide;
var
  Size, Count, Data: Integer;
  Start, Last, Arg: PWideChar;
  Quote: Boolean;
begin
  Size := 16;
  SetLength(Result, Size);
  Count := 0;
  Start := GetCommandLineW();
  repeat
    Quote := False;
    while Start^ <> #0 do
      if (Start^ = #32) or (Start^ = #9) then
        Inc(Start)
      else
        Break;
    if Start^ = #0 then
      Break;
    Last := Start;
    Data := 0;
    while Last^ <> #0 do
    begin
      if Quote then
      begin
        if Last^ = '"' then
        begin
          Inc(Last);
          if Last^ = #0 then
            Break;
          if Last^ = '"' then
            Inc(Data)
          else if (Last^ = #32) or (Last^ = #9) then
            Break
          else
            Quote := False;
        end
        else
          Inc(Data);
      end
      else if (Last^ = #32) or (Last^ = #9) then
        Break
      else
      begin
        if Last^ = '"' then
          Quote := True
        else
          Inc(Data);
      end;
      Inc(Last);
    end;
    if Count = Size then
    begin
      Size := (Size + 8) * 2;
      SetLength(Result, Size);
    end;
    SetLength(Result[Count], Data);
    Arg := PWideChar(Result[Count]);
    Quote := False;
    while Start <> Last do
    begin
      if Quote then
      begin
        if Start^ <> '"' then
        begin
          Arg^ := Start^;
          Inc(Arg);
        end
        else
        begin
          Inc(Start);
          if Start = Last then
            Break;
          if Start^ = '"' then
          begin
            Arg^ := '"';
            Inc(Arg);
          end
          else
            Quote := False;
        end;
      end
      else if Start^ = '"' then
        Quote := True
      else
      begin
        Arg^ := Start^;
        Inc(Arg);
      end;
      Inc(Start);
    end;
    Inc(Count);
  until False;
  SetLength(Result, Count);
end;

class function SFiles.GetExecutable(): WideString;
var
  Size: Integer;
begin
  SetLength(Result, 512);
  repeat
    Size := GetModuleFileNameW(0, PWideChar(Result), Length(Result));
  until Size < Length(Result) - 2;
  SetLength(Result, Size);
end;

class function SFiles.GetProgramDirectory(): WideString;
begin
  Result := RemoveLastSlash(GetExecutable()) + WideString('\');
end;

class function SFiles.ScanAndGet(const Text: WideString; Delim: SetOfChar; Tail:
  Boolean): WideString;
var
  Step: PWideChar;
  Len: Integer;
begin
  if Tail then
    Result := Text
  else
    Result := '';
  Step := PWideChar(Text);
  if Step = nil then
    Exit;
  Len := Length(Text);
  Inc(Step, Len);
  while Len > 0 do
  begin
    Dec(Len);
    Dec(Step);
    if TextChar(Step^) in Delim then
    begin
      if Tail then
        Result := Copy(Text, Len + 1, Length(Text))
      else
        Result := Copy(Text, 1, Len);
      Break;
    end;
  end;
end;

class function SFiles.RemoveLastSlash(const Filepath: WideString): WideString;
begin
  Result := ScanAndGet(Filepath, ['\', '/'], False);
end;

class function SFiles.GetLastSlash(const Filepath: WideString; Noslash: Boolean
  = False): WideString;
begin
  Result := ScanAndGet(Filepath, ['\', '/'], True);
  if Noslash and (Length(Result) > 0) and (Result[1] = '\') then
    Delete(Result, 1, 1);
end;

class function SFiles.RemoveExtension(const Filepath: WideString): WideString;
begin
  Result := ScanAndGet(Filepath, ['.'], False);
end;

class function SFiles.GetExtension(const Filepath: WideString): WideString;
begin
  Result := ScanAndGet(Filepath, ['.'], True);
end;

class function SFiles.NoBackslash(const Filepath: WideString): WideString;
var
  Len: Integer;
begin
  Len := Length(Filepath);
  while (Len > 0) and ((Filepath[Len] = '/') or (Filepath[Len] = '\')) do
    Dec(Len);
  Result := Copy(Filepath, 1, Len);
end;

class procedure SFiles.ResetCurrentDir();
var
  Path: WideString;
begin
  Path := GetExecutable();
  Path := RemoveLastSlash(Path);
  SetCurrentDirectoryW(PWideChar(Path));
end;

class function SFiles.IsDirectory(const Filepath: WideString): Boolean;
var
  Code: Integer;
begin
  Code := GetFileAttributesW(PWideChar(Filepath));
  Result := (Code <> -1) and ((FILE_ATTRIBUTE_DIRECTORY and Code) <> 0);
end;

class function SFiles.Exists(const Filepath: WideString): Boolean;
var
  Code: Integer;
begin
  Code := GetFileAttributesW(PWideChar(Filepath));
  Result := (Code <> -1);
end;

class function SFiles.GetFullName(const Filepath: WideString): WideString;
var
  Ignore: PWideChar;
begin
  SetLength(Result, GetFullPathNameW(PWideChar(Filepath), 0, nil, Ignore) + 4);
  SetLength(Result, GetFullPathNameW(PWideChar(Filepath), Length(Result),
    PWideChar(Result), Ignore));
end;

class function SFiles.CreateDirectory(const Filepath: WideString): Boolean;
begin
  Result := CreateDirectoryW(PWideChar(Filepath), nil);
end;

class function SFiles.GetAllFiles(const Dir: WideString; Folders: Trilean =
  Anything): ArrayOfWide;
var
  Path: WideString;
  Find: TWIN32FindDataW;
  Handle: THandle;
  Size: Integer;
const
  W1: WideString = '.';
  W2: WideString = '..';
begin
  Size := 0;
  SetLength(Result, 16);
  Path := NoBackslash(Dir);
  if Path <> '' then
    Path := Path + '\*'
  else
    Path := Path + '*';
  Handle := FindFirstFileW(PWideChar(Path), Find);
  if (Handle <> INVALID_HANDLE_VALUE) and (Handle <> 0) then
  begin
    repeat
      if TriCheck(Folders, (Find.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) then
      begin
        if Size >= Length(Result) then
          SetLength(Result, (Size + 8) * 2);
        if (Find.cFileName <> W1) and (Find.cFileName <> W2) then
        begin
          Result[Size] := Find.cFileName;
          Inc(Size);
        end;
      end;
    until not FindNextFileW(Handle, Find);
    windows.FindClose(Handle);
  end;
  SetLength(Result, Size);
end;

class function SFiles.GetAllFilesExt(const Mask: WideString): AFindFile;
var
  Find: TWIN32FindDataW;
  Handle: THandle;
  Cnt: Integer;
const
  W1: WideString = '.';
  W2: WideString = '..';
begin
  Cnt := 0;
  SetLength(Result, 16);
  Handle := FindFirstFileW(PWideChar(Mask), Find);
  if (Handle <> INVALID_HANDLE_VALUE) and (Handle <> 0) then
  begin
    repeat
      if Cnt >= Length(Result) then
        SetLength(Result, (Cnt + 8) * 2);
      if (Find.cFileName <> W1) and (Find.cFileName <> W2) then
        with Result[Cnt] do
        begin
          Name := Find.cFileName;
          Attr := Find.dwFileAttributes;
          Size := Int64(Find.nFileSizeLow) or Int64(Find.nFileSizeHigh shl 32);
          CreationTime := Find.ftCreationTime;
          WriteTime := Find.ftLastWriteTime;
          Inc(Cnt);
        end;
    until not FindNextFileW(Handle, Find);
    windows.FindClose(Handle);
  end;
  SetLength(Result, Cnt);
end;

class function SFiles.RedirectFile(out Old: RHandles; const Read, Write, Error:
  WideString): Boolean;
var
  Handle: THandle;
  Stream: THandleStream;
begin
  Result := True;
  Old.Read := 0;
  if Read <> '' then
  begin
    Stream := OpenRead(Read);
    if Stream <> nil then
    begin
      Handle := GetStdHandle(STD_INPUT_HANDLE);
      if (Handle <> 0) and (Handle <> INVALID_HANDLE_VALUE) then
        Old.Read := Handle;
      SetStdHandle(STD_INPUT_HANDLE, Stream.Handle);
      Stream.Free();
    end
    else
      Result := False;
  end;
  if Write <> '' then
  begin
    Stream := OpenNew(Write);
    if Stream <> nil then
    begin
      Handle := GetStdHandle(STD_OUTPUT_HANDLE);
      if (Handle <> 0) and (Handle <> INVALID_HANDLE_VALUE) then
        Old.Write := Handle;
      SetStdHandle(STD_OUTPUT_HANDLE, Stream.Handle);
      Stream.Free();
    end
    else
      Result := False;
  end;
end;

class procedure SFiles.RedirectRestore(var Old: RHandles);
var
  Handle: THandle;
begin
  if Old.Read <> 0 then
  begin
    Handle := GetStdHandle(STD_INPUT_HANDLE);
    if (Handle <> 0) and (Handle <> INVALID_HANDLE_VALUE) then
      CloseHandle(Handle);
    SetStdHandle(STD_INPUT_HANDLE, Old.Read);
    Old.Read := 0;
  end;
  if Old.Write <> 0 then
  begin
    Flush(Output);
    Handle := GetStdHandle(STD_OUTPUT_HANDLE);
    if (Handle <> 0) and (Handle <> INVALID_HANDLE_VALUE) then
      CloseHandle(Handle);
    SetStdHandle(STD_OUTPUT_HANDLE, Old.Write);
    Old.Write := 0;
  end;
end;

class function SFiles.UseCurrentDirectory(const Path: WideString = ''): WideString;
begin
  SetLength(Result, windows.GetCurrentDirectoryW(0, nil));
  SetLength(Result, GetCurrentDirectoryW(Length(Result), PWideChar(Result)));
  if Path <> '' then
    windows.SetCurrentDirectoryW(PWideChar(Path));
end;

class function SFiles.DeleteFile(const Filename: WideString): Boolean;
begin
  Result := windows.DeleteFileW(PWideChar(Filename));
end;

class function SFiles.CopyFile(const Source, Target: WideString; Owerride:
  Boolean): Boolean;
begin
  Result := windows.CopyFileW(PWideChar(Source), PWideChar(Target), not Owerride);
end;

class procedure SFiles.SetTime(Filename: WideString; const CreationTime,
  WriteTime: FILETIME);
const
  FILE_WRITE_ATTRIBUTES = $100;
var
  Handle: Integer;
begin
  Handle := CreateFileW(PWideChar(Filename), FILE_WRITE_ATTRIBUTES,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL, 0);
  if (Handle <> 0) and (Handle <> -1) then
  begin
    SetFileTime(Handle, @CreationTime, nil, @WriteTime);
    CloseHandle(Handle);
  end;
end;

class function SFiles.RecursiveDirectory(Create: WideString): Boolean;
var
  Code: Integer;
  Path: PWideChar;

  procedure Recur(Len: Integer);
  var
    Seek: PWideChar;
  begin
    if Path^ = #0 then
      Exit;
    Code := GetFileAttributesW(Path);
    if (Code <> -1) and ((FILE_ATTRIBUTE_DIRECTORY and Code) <> 0) then
      Exit;
    Seek := Path;
    Inc(Seek, Len);
    repeat
      Dec(Seek);
      Dec(Len);
      if Len = 0 then
        Exit;
    until (Seek^ = '\');
    Seek^ := #0;
    Recur(Len);
    Seek^ := '\';
    CreateDirectoryW(Path, nil);
  end;

begin
  Path := PWideChar(NoBackslash(Create));
  Recur(Length(Create));
  Result := IsDirectory(Create);
end;

class function SFiles.DeleteEmptyDirs(const Root: WideString): Boolean;
var
  Target, Name: WideString;
  Handle: THandle;
  Find: TWIN32FindDataW;
  Trydel: Boolean;
begin
  Result := False;
  Trydel := False;
  Handle := 0;
  try
    Target := NoBackslash(Root) + WideString('\');
    Handle := FindFirstFileW(PWideChar(Target + '*'), Find);
    if Handle = INVALID_HANDLE_VALUE then
      Handle := 0;
    if Handle <> 0 then
    begin
      Trydel := True;
      repeat
        Name := WideString(Find.cFileName);
        if (Name <> '.') and (Name <> '..') then
        begin
          if Find.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY <> 0 then
          begin
            if not DeleteEmptyDirs(Target + Name) then
              Trydel := False;
          end
          else
            Trydel := False;
        end;
      until not FindNextFileW(Handle, Find);
    end;
  except
  end;
  if Handle <> 0 then
    windows.FindClose(Handle);
  if Trydel then
    Result := RemoveDirectoryW(PWideChar(Target));
end;

end.

