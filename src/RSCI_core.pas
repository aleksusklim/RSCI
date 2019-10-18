unit RSCI_core;

interface

uses
  Windows, SysUtils, Classes, SHL_Classes, SHL_Types, DCPsha1;

const
  BUF_SIZE = 1024 * 8;

type
  TRsciHash = array[0..19] of Byte;

type
  PRSCI_sort = ^RSCI_sort;

  RSCI_sort_u = record
    Hash: TRsciHash;
    Length: Int64;
  end;

  RSCI_sort = record
    U: RSCI_sort_u;
    Creation, Modification: Int64;
    Caption: PWideChar;
    Extension: PWideChar;
    Child, Next, Parent: PRSCI_sort;
    Children, Files: Integer;
    Flag: Integer;
  end;

function RSCI_refresh(const Filepath: WideString; Data: RFindFile): DataString;

function RSCI_check(const Filepath: WideString; Data: RFindFile): Boolean;

function RSCI_copy(const Original, Ghost: WideString): Boolean;

procedure RSCI_walk(const Server, Client: WideString);

procedure RSCI_combine(Client, Server, Error: WideString);

procedure RSCI_free(const Path: WideString);

function RSCI_data(const Path: WideString; out Size: Int64; out Time: TFileTime): Boolean;

function RSCI_print(Client: Boolean; const Target: WideString; MemStr, MemRec:
  TMemorySimple; Res: PRSCI_sort = nil): PRSCI_sort;

procedure RSCI_log(const Name: WideString);

implementation

uses
  SHL_Files;

const
  NtfsData: WideString = ':RSCIdata';
  RsciLog: WideString = 'RSCI.LOG';
//  RSCI_FLAG_LOG = Integer($80000000);
  RSCI_FLAG_COPY = $00000001;

type
  PRSCI_header = ^RSCI_header;

  RSCI_header = record
    Size: Int64;
    TimeC, TimeW: TFileTime;
    Hash: TRsciHash;
    Flag: Integer;
  end;

type
  PRSCI_pair = ^RSCI_pair;

  RSCI_pair = record
    Old, New: PWideChar;
  end;

const
  RSCI_size = SizeOf(RSCI_header);

function RSCI_refresh(const Filepath: WideString; Data: RFindFile): DataString;
var
  Stream: THandleStream;
  Hash: TDCP_sha1;
  Head: PRSCI_header;
begin
  Result := '';
  Hash := nil;
  try
    Result := SFiles.ReadEntireFile(Filepath + NtfsData, RSCI_size);
    if Length(Result) = RSCI_size then
    begin
      Head := Cast(Result);
      if (Head.Flag and RSCI_FLAG_COPY) <> 0 then
        Exit;
      if (Head.Size = Data.Size) and (Head.TimeC.dwLowDateTime = Data.CreationTime.dwLowDateTime)
        and (Head.TimeC.dwHighDateTime = Data.CreationTime.dwHighDateTime) and (Head.TimeW.dwLowDateTime
        = Data.WriteTime.dwLowDateTime) and (Head.TimeW.dwHighDateTime = Data.WriteTime.dwHighDateTime)
        then
        Exit;
    end;
    SetLength(Result, RSCI_size);
    Head := Cast(Result);
    Head.Size := Data.Size;
    Head.TimeC := Data.CreationTime;
    Head.TimeW := Data.WriteTime;
    Head.Flag := 0;
    Hash := TDCP_sha1.Create(nil);
    Stream := SFiles.OpenRead(Filepath);
    Assure(Stream <> nil);
    Hash.Init();
    Hash.UpdateStream(Stream, Stream.Size);
    Hash.final(Head.Hash);
    Assure(SFiles.WriteEntireFile(Filepath + NtfsData, Head, RSCI_size));
    SFiles.SetTime(Filepath, Data.CreationTime, Data.WriteTime);
  except
    Result := '';
  end;
  Hash.Free();
  SFiles.CloseStream(Stream);
end;

function RSCI_check(const Filepath: WideString; Data: RFindFile): Boolean;
var
  Header: PRSCI_header;
  Stream: DataString;
begin
  Result := False;
  try
    Stream := SFiles.ReadEntireFile(Filepath + NtfsData, RSCI_size);
    Assure(Length(Stream) = RSCI_size);
    Header := Cast(Stream);
    if (Header.Size = Data.Size) and (Header.TimeC.dwLowDateTime = Data.CreationTime.dwLowDateTime)
      and (Header.TimeC.dwHighDateTime = Data.CreationTime.dwHighDateTime) and (Header.TimeW.dwLowDateTime
      = Data.WriteTime.dwLowDateTime) and (Header.TimeW.dwHighDateTime = Data.WriteTime.dwHighDateTime)
      then
      Result := True;
  except
  end;
end;

function RSCI_copy(const Original, Ghost: WideString): Boolean;
var
  Data: DataString;
  Head: PRSCI_header;
begin
  Result := False;
  try
    Data := SFiles.ReadEntireFile(Original + NtfsData, RSCI_size);
    Assure(Length(Data) = RSCI_size);
    SFiles.WriteEntireFile(Ghost, '');
    Head := Cast(Data);
    Head.Flag := Head.Flag or RSCI_FLAG_COPY;
    Assure(SFiles.WriteEntireFile(Ghost + NtfsData, Data));
    Result := True;
  except
  end;
end;

procedure RSCI_walk(const Server, Client: WideString);
var
  Index: Integer;
  Name: WideString;
  Arr: AFindFile;
  Data: DataString;
  Head: PRSCI_header;
begin
  SetLength(Arr, 0);
  try
    Arr := SFiles.GetAllFilesExt(Server + '*');
    for Index := 0 to Length(Arr) - 1 do
      if (Arr[Index].Attr and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
      begin
        Name := Client + Arr[Index].Name + WideString('\');
        SFiles.CreateDirectory(Name);
        Assure(SFiles.IsDirectory(Name));
        RSCI_walk(Server + Arr[Index].Name + WideString('\'), Name);
      end
      else
      begin
        if Arr[Index].Name = RsciLog then
          Continue;
        Data := RSCI_refresh(Server + Arr[Index].Name, Arr[Index]);
        Head := Cast(Data);
        if (Head.Flag and RSCI_FLAG_COPY) <> 0 then
          Continue;
        RSCI_copy(Server + Arr[Index].Name, Client + Arr[Index].Name);
      end;
  except
  end;
end;

procedure RSCI_free(const Path: WideString);
var
  Index: Integer;
  Name: WideString;
  Arr: ArrayOfWide;
  Data: DataString;
  Head: PRSCI_header;
begin
  SetLength(Arr, 0);
  try
    if SFiles.IsDirectory(Path) then
    begin
      Name := SFiles.NoBackslash(Path) + WideString('\');
      Arr := SFiles.GetAllFiles(Name);
      for Index := 0 to Length(Arr) - 1 do
        RSCI_free(Name + Arr[Index]);
    end
    else
    begin
      if SFiles.GetLastSlash(Path, True) = RsciLog then
      begin
        SFiles.DeleteFile(Path);
        Exit;
      end;
      Data := SFiles.ReadEntireFile(Path + NtfsData, RSCI_size);
      Head := Cast(Data);
      if (Length(Data) = RSCI_size) and ((Head.Flag and RSCI_FLAG_COPY) <> 0) then
        Exit;
      SFiles.DeleteFile(Path + NtfsData);
    end;
  except
  end;
end;

function RSCI_data(const Path: WideString; out Size: Int64; out Time: TFileTime): Boolean;
var
  Data: DataString;
  Header: PRSCI_header;
begin
  Result := False;
  Data := SFiles.ReadEntireFile(Path + NtfsData, RSCI_size);
  if Length(Data) <> RSCI_size then
    Exit;
  Header := Cast(Data);
  Size := Header.Size;
  Time := Header.TimeW;
  Result := True;
end;

function FindExt(S: PWideChar): PWideChar;
var
  W: Word;
begin
  Result := nil;
  if S <> nil then
    while True do
    begin
      W := PWord(Pointer(S))^;
      if W = 0 then
        Exit;
      if W = Ord('.') then
        Result := S;
      Inc(S);
    end;
end;

function NewElem(Mem: TMemorySimple): PRSCI_sort;
begin
  Result := Mem.Alloc(SizeOf(RSCI_sort), 4);
  ZeroMemory(Result, SizeOf(RSCI_sort));
end;

function RSCI_print(Client: Boolean; const Target: WideString; MemStr, MemRec:
  TMemorySimple; Res: PRSCI_sort = nil): PRSCI_sort;
var
  Index: Integer;
  Arr: AFindFile;
  Elem: PRSCI_sort;
  Old: PPointer;
  Data: DataString;
  Head: PRSCI_header;
begin
  SetLength(Arr, 0);
  Old := nil;
  if Res = nil then
    Res := NewElem(MemRec);
  Result := Res;
  try
    Arr := SFiles.GetAllFilesExt(Target + WideString('*'));
    for Index := 0 to Length(Arr) - 1 do
      if (Arr[Index].Attr and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
      begin
        Inc(Res.Children);
        Elem := NewElem(MemRec);
        RSCI_print(Client, Target + Arr[Index].Name + WideString('\'), MemStr,
          MemRec, Elem);
        if Elem.Files = 0 then
          Continue;
        if Old <> nil then
          Old^ := Elem
        else
          Res.Child := Elem;
        Elem.Parent := Res;
        Old := @Elem.Next;
        Inc(Res.U.Length, Elem.U.Length);
        Inc(Res.Files, Elem.Files);
        if Res.Creation < Elem.Creation then
          Res.Creation := Elem.Creation;
        if Res.Modification < Elem.Modification then
          Res.Modification := Elem.Modification;
        Elem.Caption := MemStr.CopyWide(Arr[Index].Name);
        Elem.Extension := nil;
      end;
    for Index := 0 to Length(Arr) - 1 do
      if (Arr[Index].Attr and FILE_ATTRIBUTE_DIRECTORY) = 0 then
      begin
        if Arr[Index].Name = RsciLog then
          Continue;
        Data := SFiles.ReadEntireFile(Target + Arr[Index].Name + NtfsData, RSCI_size);
        if Length(Data) <> RSCI_size then
          Continue;
        Head := Cast(Data);
        if ((Head.Flag and RSCI_FLAG_COPY) <> 0) <> Client then
          Continue;
        Inc(Res.Children);
        Inc(Res.Files);
        Elem := NewElem(MemRec);
        Elem.Parent := Res;
        if Old <> nil then
          Old^ := Elem
        else
          Res.Child := Elem;
        Old := @Elem.Next;
        Elem.U.Length := Head.Size;
        Elem.Creation := Int64(Head.TimeC);
        Elem.Modification := Int64(Head.TimeW);
        Elem.U.Hash := Head.Hash;
        Elem.Flag := Head.Flag;
        Elem.Caption := MemStr.CopyWide(Arr[Index].Name);
        Elem.Extension := FindExt(Elem.Caption);
        Inc(Res.U.Length, Elem.U.Length);
        if Res.Creation < Elem.Creation then
          Res.Creation := Elem.Creation;
        if Res.Modification < Elem.Modification then
          Res.Modification := Elem.Modification;
      end;
  except
  end;
end;

function RSCI_compare_str(Str1, Str2: PWideChar): Integer;
const
  Nul: Word = 0;
var
  A, B: PWord;
begin
  A := Pointer(PWideChar(WideLowerCase(WideString(Str1))));
  B := Pointer(PWideChar(WideLowerCase(WideString(Str2))));
  if A = nil then
    A := @Nul;
  if B = nil then
    B := @Nul;
  repeat
    Result := A^ - B^;
    if (Result <> 0) or (A^ = 0) or (B^ = 0) then
      Exit;
    Inc(A);
    Inc(B);
  until False;
end;

function RSCI_compare_name(Item1, Item2: Pointer): Integer;
begin
  Result := RSCI_compare_str(PRSCI_sort(Item1).Caption, PRSCI_sort(Item2).Caption);
end;

function RSCI_compare_size(Item1, Item2: Pointer): Integer;
var
  I: Int64;
begin
  I := PRSCI_sort(Item1).U.Length - PRSCI_sort(Item2).U.Length;
  if I = 0 then
    Result := RSCI_compare_name(Item1, Item2)
  else if I > 0 then
    Result := 1
  else
    Result := -1;
end;

function RSCI_compare_modif(Item1, Item2: Pointer): Integer;
var
  I: Int64;
begin
  I := PRSCI_sort(Item1).Modification - PRSCI_sort(Item2).Modification;
  if I = 0 then
    Result := RSCI_compare_name(Item1, Item2)
  else if I > 0 then
    Result := 1
  else
    Result := -1;
end;

function RSCI_compare_create(Item1, Item2: Pointer): Integer;
var
  I: Int64;
begin
  I := PRSCI_sort(Item1).Creation - PRSCI_sort(Item2).Creation;
  if I = 0 then
    Result := RSCI_compare_name(Item1, Item2)
  else if I > 0 then
    Result := 1
  else
    Result := -1;
end;

function RSCI_compare_count(Item1, Item2: Pointer): Integer;
begin
  Result := PRSCI_sort(Item1).Files - PRSCI_sort(Item2).Files;
  if Result = 0 then
  begin
    Result := PRSCI_sort(Item1).Children - PRSCI_sort(Item2).Children;
    if Result = 0 then
      Result := RSCI_compare_name(Item1, Item2);
  end;
end;

function RSCI_compare_ext(Item1, Item2: Pointer): Integer;
begin
  Result := RSCI_compare_str(PRSCI_sort(Item1).Extension, PRSCI_sort(Item2).Extension);
end;

function RSCI_compare_hash(Item1, Item2: Pointer): Integer;
var
  A, B: TextString;
  I: Int64;
begin
  I := PRSCI_sort(Item1).U.Length - PRSCI_sort(Item2).U.Length;
  if I = 0 then
  begin
    SetString(A, CastChar(@PRSCI_sort(Item1).U.Hash), SizeOf(TRsciHash));
    SetString(B, CastChar(@PRSCI_sort(Item2).U.Hash), SizeOf(TRsciHash));
    Result := CompareStr(A, B);
  end
  else if I > 0 then
    Result := 1
  else
    Result := -1;
end;

function NameRoot(Elem: PRSCI_sort): TextString;
var
  R: WideString;
begin
  R := '".\' + WideString(Elem.Caption) + '"';
  Result := UTF8Encode(R);
end;

function NameDir(Elem: PRSCI_sort): TextString;
var
  R: WideString;
begin
  R := '\' + WideString(Elem.Caption) + '\';
  Result := UTF8Encode(R);
end;

function NameFile(Elem: PRSCI_sort): TextString;
var
  R: WideString;
begin
  R := '"' + WideString(Elem.Caption) + '"';
  Result := UTF8Encode(R);
end;

function NameExt(Elem: PRSCI_sort): TextString;
var
  R: WideString;
begin
  R := '<' + WideString(Elem.Extension) + '>';
  Result := UTF8Encode(R);
end;

function NameSize(Elem: PRSCI_sort): TextString;
var
  R: WideString;
begin
  R := '(' + STextUtils.SizeToString(Elem.U.Length) + ' /' + IntToStr(Elem.U.Length)
    + ')';
  Result := UTF8Encode(R);
end;

function NameHash(Elem: PRSCI_sort): TextString;
var
  Arr: array[0..SizeOf(TRsciHash) * 2 - 1] of TextChar;
  R: WideString;
begin
  BinToHex(@Elem.U.Hash, @Arr, SizeOf(TRsciHash));
  R := WideString('{' + TextString(Arr) + '}');
  Result := UTF8Encode(R);
end;

function NameModfed(Elem: PRSCI_sort): TextString;
var
  R: WideString;
begin
  R := STextUtils.DateToString(TFileTime(Elem.Modification));
  Result := UTF8Encode(R);
end;

function NameCount(Elem: PRSCI_sort): TextString;
var
  R: WideString;
begin
  R := '<' + IntToStr(Elem.Children) + '/' + IntToStr(Elem.Files) + '>';
  Result := UTF8Encode(R);
end;

function NameCreate(Elem: PRSCI_sort): TextString;
var
  R: WideString;
begin
  R := '[' + STextUtils.DateToString(TFileTime(Elem.Creation)) + ']';
  Result := UTF8Encode(R);
end;

function NameFull(Elem: PRSCI_sort): TextString;
var
  R: WideString;
begin
  R := '';
  while (Elem <> nil) and (Elem.Caption <> nil) do
  begin
    R := WideString('\') + Elem.Caption + R;
    Elem := Elem.Parent;
  end;
  Result := UTF8Encode(R);
end;

function NameFullW(Elem: PRSCI_sort): WideString;
begin
  Result := '';
  while (Elem <> nil) and (Elem.Caption <> nil) do
  begin
    Result := WideString('\') + Elem.Caption + Result;
    Elem := Elem.Parent;
  end;
end;

function DumpList(Root: PRSCI_sort; Stream: TStream; List, Sort: TList): Boolean;
var
  Elem: PRSCI_sort;
  Index: Integer;
begin
  Result := False;
  with STextUtils do
  try
    List.Clear();
    Elem := Root;

    WriteText(Stream, NameRoot(Elem) + #9);
    WriteText(Stream, NameSize(Elem) + #9);
    WriteText(Stream, NameModfed(Elem) + #9);
    WriteText(Stream, NameCount(Elem) + #9);
    WriteText(Stream, NameCreate(Elem));
    WriteLine(Stream, True);
    WriteLine(Stream, True);
    WriteLine(Stream, True);

    Elem := Elem.Child;
    while Elem <> nil do
    begin
      if Elem.Child <> nil then
        List.Add(Elem);
      Elem := Elem.Next;
    end;

    if List.Count > 0 then
    begin
      List.Sort(RSCI_compare_name);
      for Index := 0 to List.Count - 1 do
      begin
        Elem := List[Index];
        WriteText(Stream, NameDir(Elem) + #9);
        WriteText(Stream, NameSize(Elem) + #9);
        WriteText(Stream, NameModfed(Elem) + #9);
        WriteText(Stream, NameCount(Elem) + #9);
        WriteText(Stream, NameCreate(Elem));
        STextUtils.WriteLine(Stream, True);
      end;
      STextUtils.WriteLine(Stream, True);

      List.Sort(RSCI_compare_size);
      for Index := 0 to List.Count - 1 do
      begin
        Elem := List[Index];
        WriteText(Stream, NameSize(Elem) + #9);
        WriteText(Stream, NameDir(Elem) + #9);
        WriteText(Stream, NameModfed(Elem) + #9);
        WriteText(Stream, NameCount(Elem) + #9);
        WriteText(Stream, NameCreate(Elem));
        STextUtils.WriteLine(Stream, True);
      end;
      STextUtils.WriteLine(Stream, True);

      List.Sort(RSCI_compare_modif);
      for Index := 0 to List.Count - 1 do
      begin
        Elem := List[Index];
        WriteText(Stream, NameModfed(Elem) + #9);
        WriteText(Stream, NameDir(Elem) + #9);
        WriteText(Stream, NameSize(Elem) + #9);
        WriteText(Stream, NameCount(Elem) + #9);
        WriteText(Stream, NameCreate(Elem));
        STextUtils.WriteLine(Stream, True);
      end;
      STextUtils.WriteLine(Stream, True);

      List.Sort(RSCI_compare_count);
      for Index := 0 to List.Count - 1 do
      begin
        Elem := List[Index];
        WriteText(Stream, NameCount(Elem) + #9);
        WriteText(Stream, NameDir(Elem) + #9);
        WriteText(Stream, NameSize(Elem) + #9);
        WriteText(Stream, NameModfed(Elem) + #9);
        WriteText(Stream, NameCreate(Elem));
        STextUtils.WriteLine(Stream, True);
      end;
      STextUtils.WriteLine(Stream, True);

      List.Sort(RSCI_compare_create);
      for Index := 0 to List.Count - 1 do
      begin
        Elem := List[Index];
        WriteText(Stream, NameCreate(Elem) + #9);
        WriteText(Stream, NameDir(Elem) + #9);
        WriteText(Stream, NameSize(Elem) + #9);
        WriteText(Stream, NameModfed(Elem) + #9);
        WriteText(Stream, NameCount(Elem));
        STextUtils.WriteLine(Stream, True);
      end;
      STextUtils.WriteLine(Stream, True);
    end;

    STextUtils.WriteLine(Stream, True);
    List.Clear();
    Elem := Root.Child;
    while Elem <> nil do
    begin
      if (Elem.Child = nil) and (Elem.Caption <> RsciLog) then
      begin
        List.Add(Elem);
        Sort.Add(Elem);
      end;
      Elem := Elem.Next;
    end;

    if List.Count > 0 then
    begin
      List.Sort(RSCI_compare_name);
      for Index := 0 to List.Count - 1 do
      begin
        Elem := List[Index];
        WriteText(Stream, NameFile(Elem) + #9);
        WriteText(Stream, NameSize(Elem) + #9);
        WriteText(Stream, NameModfed(Elem) + #9);
        WriteText(Stream, NameExt(Elem) + #9);
        WriteText(Stream, NameCreate(Elem) + #9);
        WriteText(Stream, NameHash(Elem));
        STextUtils.WriteLine(Stream, True);
      end;
      STextUtils.WriteLine(Stream, True);

      List.Sort(RSCI_compare_size);
      for Index := 0 to List.Count - 1 do
      begin
        Elem := List[Index];
        WriteText(Stream, NameSize(Elem) + #9);
        WriteText(Stream, NameFile(Elem) + #9);
        WriteText(Stream, NameModfed(Elem) + #9);
        WriteText(Stream, NameExt(Elem) + #9);
        WriteText(Stream, NameCreate(Elem));
        STextUtils.WriteLine(Stream, True);
      end;
      STextUtils.WriteLine(Stream, True);

      List.Sort(RSCI_compare_modif);
      for Index := 0 to List.Count - 1 do
      begin
        Elem := List[Index];
        WriteText(Stream, NameModfed(Elem) + #9);
        WriteText(Stream, NameFile(Elem) + #9);
        WriteText(Stream, NameSize(Elem) + #9);
        WriteText(Stream, NameExt(Elem) + #9);
        WriteText(Stream, NameCreate(Elem));
        STextUtils.WriteLine(Stream, True);
      end;
      STextUtils.WriteLine(Stream, True);

      List.Sort(RSCI_compare_ext);
      for Index := 0 to List.Count - 1 do
      begin
        Elem := List[Index];
        WriteText(Stream, NameExt(Elem) + #9);
        WriteText(Stream, NameFile(Elem) + #9);
        WriteText(Stream, NameSize(Elem) + #9);
        WriteText(Stream, NameModfed(Elem) + #9);
        WriteText(Stream, NameCreate(Elem));
        STextUtils.WriteLine(Stream, True);
      end;
      STextUtils.WriteLine(Stream, True);

      List.Sort(RSCI_compare_create);
      for Index := 0 to List.Count - 1 do
      begin
        Elem := List[Index];
        WriteText(Stream, NameCreate(Elem) + #9);
        WriteText(Stream, NameFile(Elem) + #9);
        WriteText(Stream, NameSize(Elem) + #9);
        WriteText(Stream, NameModfed(Elem) + #9);
        WriteText(Stream, NameExt(Elem));
        STextUtils.WriteLine(Stream, True);
      end;
      STextUtils.WriteLine(Stream, True);
    end;
    Result := True;
  except
  end;
end;

procedure DumpHash(List: TList; Stream: TBufferedWrite);
var
  Index: Integer;
  Elem: PRSCI_sort;
  Prev: Integer;
begin
  with STextUtils do
  try
    List.Sort(RSCI_compare_hash);
    WriteLine(Stream, True);
    Prev := -1;
    for Index := 1 to List.Count - 1 do
    begin
      if (RSCI_compare_hash(List[Index], List[Index - 1]) = 0) then
      begin
        if Prev <> Index - 1 then
        begin
          Elem := List[Index - 1];
          WriteLine(Stream, True);
          WriteText(Stream, NameHash(Elem) + #9);
          WriteText(Stream, NameSize(Elem));
          WriteLine(Stream, True);
          WriteText(Stream, '"' + NameFull(Elem) + '"'#9);
          WriteText(Stream, NameModfed(Elem) + #9);
          WriteText(Stream, NameExt(Elem) + #9);
          WriteText(Stream, NameCreate(Elem));
          WriteLine(Stream, True);
        end;
        Elem := List[Index];
        WriteText(Stream, '"' + NameFull(Elem) + '"'#9);
        WriteText(Stream, NameModfed(Elem) + #9);
        WriteText(Stream, NameExt(Elem) + #9);
        WriteText(Stream, NameCreate(Elem));
        WriteLine(Stream, True);
        Prev := Index;
      end;
    end;
  except
  end;
end;

function Descend(Root: PRSCI_sort; Path: WideString; Stream: TBufferedWrite;
  List, Sort: TList; First: Boolean = True): Boolean;
var
  Handle: THandleStream;
  Elem: PRSCI_sort;
begin
  Result := False;
  Handle := nil;
  try
    Elem := Root.Child;
    while Elem <> nil do
    begin
      if Elem.Child <> nil then
        Descend(Elem, Path + Elem.Caption + WideString('\'), Stream, List, Sort, False);
      Elem := Elem.Next;
    end;
    Handle := SFiles.OpenNew(Path + RsciLog);
    Stream.Open(Handle);
    STextUtils.WriteBom(Stream, True);
    DumpList(Root, Stream, List, Sort);
    if First then
      DumpHash(Sort, Stream);
    Stream.Close();
    SFiles.CloseStream(Handle);
    Result := True;
  except
  end;
  SFiles.CloseStream(Handle);
end;

procedure RSCI_log(const Name: WideString);
var
  MemStr, MemRec: TMemorySimple;
  Root: PRSCI_sort;
  Stream: TBufferedWrite;
  List, Sort: TList;
begin
  Sort := nil;
  List := nil;
  Stream := nil;
  MemStr := nil;
  MemRec := nil;
  try
    List := TList.Create();
    Sort := TList.Create();
    MemStr := TMemorySimple.Create();
    MemRec := TMemorySimple.Create();
    Stream := TBufferedWrite.Create(BUF_SIZE);
    Root := RSCI_print(True, Name, MemStr, MemRec);
    Assure((Root <> nil) and (Root.Files <> 0));
    Root.Caption := MemStr.CopyWide(SFiles.GetLastSlash(SFiles.NoBackslash(Name), True));
    Descend(Root, Name, Stream, List, Sort);
  except
  end;
  MemStr.Free();
  MemRec.Free();
  Stream.Free();
  List.Free();
  Sort.Free();
end;

procedure GetFiles(Elem: PRSCI_sort; List: TStringList; Client: Boolean);
var
  Key: DataString;
begin
  while Elem <> nil do
  begin
    if Elem.Child <> nil then
      GetFiles(Elem.Child, List, Client)
    else
    begin
      if ((Elem.Flag and RSCI_FLAG_COPY) <> 0) = Client then
      begin
        SetString(Key, PDataChar_(@Elem.U), SizeOf(RSCI_sort_u));
        List.AddObject(Key, TObject(Elem));
      end;
    end;
    Elem := Elem.Next;
  end;
end;

procedure RSCI_error(Cl, Sr: TextString; ListCli, ListSrv: TStringList; Filename:
  WideString);
var
  Elem: PRSCI_sort;
  Index, Other: Integer;
  Handle: THandleStream;
  Stream: TBufferedWrite;
  Value: Integer;
begin
  Handle := nil;
  Stream := nil;
  with STextUtils do
  try
    Stream := TBufferedWrite.Create(BUF_SIZE);
    Handle := SFiles.OpenNew(Filename);
    Stream.Open(Handle);
    WriteBom(Stream, True);
    WriteText(Stream, Cl + ':');
    WriteLine(Stream, True);
    Index := ListCli.Count - 1;
    Other := ListSrv.Count - 1;
    while Index >= 0 do
    begin
      if Other < 0 then
        Value := 1
      else
        Value := CompareStr(ListCli[Index], ListSrv[Other]);
      if Value = 0 then
      begin
        Dec(Other);
        Dec(Index);
      end
      else if Value < 0 then
        Dec(Other)
      else if Value > 0 then
      begin
        Elem := Pointer(ListCli.Objects[Index]);
        WriteText(Stream, NameHash(Elem) + #9);
        WriteText(Stream, '"' + NameFull(Elem) + '"'#9);
        WriteText(Stream, NameSize(Elem) + #9);
        WriteText(Stream, NameModfed(Elem) + #9);
        WriteText(Stream, NameExt(Elem) + #9);
        WriteText(Stream, NameCreate(Elem) + #9);
        WriteLine(Stream, True);
        Dec(Index);
      end;
    end;
    WriteLine(Stream, True);
    WriteText(Stream, Sr + ':');
    WriteLine(Stream, True);
    Index := ListSrv.Count - 1;
    Other := ListCli.Count - 1;
    while Index >= 0 do
    begin
      if Other < 0 then
        Value := 1
      else
        Value := CompareStr(ListSrv[Index], ListCli[Other]);
      if Value = 0 then
      begin
        Dec(Other);
        Dec(Index);
      end
      else if Value < 0 then
        Dec(Other)
      else if Value > 0 then
      begin
        Elem := Pointer(ListSrv.Objects[Index]);
        WriteText(Stream, NameHash(Elem) + #9);
        WriteText(Stream, '"' + NameFull(Elem) + '"'#9);
        WriteText(Stream, NameSize(Elem) + #9);
        WriteText(Stream, NameModfed(Elem) + #9);
        WriteText(Stream, NameExt(Elem) + #9);
        WriteText(Stream, NameCreate(Elem) + #9);
        WriteLine(Stream, True);
        Dec(Index);
      end;
    end;
  except
  end;
  Stream.Free();
  SFiles.CloseStream(Handle);
  Abort;
end;

procedure RSCI_combine(Client, Server, Error: WideString);
var
  MemStr, MemRec: TMemorySimple;
  RootCli, RootSrv: PRSCI_sort;
  ListCli, ListSrv: TStringList;
  Index: Integer;
  Src, Dst: WideString;
  Pair: PRSCI_pair;
  Pairs: TList;
  OldCur, Name: WideString;
  Cl, Sr: TextString;
  Log: TBufferedWrite;
begin
  SFiles.DeleteFile(Error);
  OldCur := '';
  MemStr := nil;
  MemRec := nil;
  ListSrv := nil;
  ListCli := nil;
  Pairs := nil;
  Log := nil;
  try
    Pairs := TList.Create();
    ListSrv := TStringList.Create();
    ListSrv.Sorted := False;
    ListSrv.CaseSensitive := True;
    ListCli := TStringList.Create();
    ListCli.Sorted := False;
    ListCli.CaseSensitive := True;
    MemStr := TMemorySimple.Create();
    MemRec := TMemorySimple.Create();
    Client := SFiles.NoBackslash(Client);
    Server := SFiles.NoBackslash(Server);
    Cl := UTF8Encode(SFiles.GetLastSlash(Client, True));
    Sr := UTF8Encode(SFiles.GetLastSlash(Server, True));
    RootCli := RSCI_print(true, Client + WideString('\'), MemStr, MemRec);
    GetFiles(RootCli, ListCli, True);
    RootSrv := RSCI_print(False, Server + WideString('\'), MemStr, MemRec);
    GetFiles(RootSrv, ListSrv, False);
    ListCli.Sort();
    ListSrv.Sort();
    ListCli.Sorted := False;
    ListSrv.Sorted := False;
    if ListCli.Count <> ListSrv.Count then
      RSCI_error(Cl, Sr, ListCli, ListSrv, Error);
    for Index := 0 to ListSrv.Count - 1 do
      if not (ListCli[Index] = ListSrv[Index]) then
        RSCI_error(Cl, Sr, ListCli, ListSrv, Error);
    Log := TBufferedWrite.Create(BUF_SIZE);
    Log.Open(Error, True);
    OldCur := SFiles.UseCurrentDirectory(Server);
    for Index := 0 to ListCli.Count - 1 do
    begin
      Src := NameFullW(Pointer(ListSrv.Objects[Index]));
      Dst := NameFullW(Pointer(ListCli.Objects[Index]));
      if Src = Dst then
        Continue;
      Pair := MemRec.Alloc(SizeOf(RSCI_pair), 4);
      Pair.Old := MemStr.CopyWide(WideString('.') + Src);
      Pair.New := MemStr.CopyWide(WideString('.') + Dst);
      if (not SFiles.Exists(Pair.Old)) or SFiles.Exists(Pair.New) then
      begin
        if not Log.Used then
          STextUtils.WriteBom(Log, True);
        STextUtils.WriteText(Log, 'Exchange failed: "' + UTF8Encode(Pair.Old) +
          '" to "' + UTF8Encode(Pair.New) + '"');
        STextUtils.WriteLine(Log, True);
      end;
      Pairs.Add(Pair);
    end;
    if Log.Used then
      Abort;
    for Index := 0 to Pairs.Count - 1 do
    begin
      Pair := Pairs[Index];
      Name := SFiles.RemoveLastSlash(Pair.New) + WideString('\');
      if not SFiles.RecursiveDirectory(Name) then
      begin
        if not Log.Used then
          STextUtils.WriteBom(Log, True);
        STextUtils.WriteText(Log, 'Create directory failed: "' + UTF8Encode(Name) + '"');
        STextUtils.WriteLine(Log, True);
      end;
    end;
    if Log.Used then
      Abort;
    for Index := 0 to Pairs.Count - 1 do
    begin
      Pair := Pairs[Index];
      if not MoveFileW(Pair.Old, Pair.New) then
      begin
        if not Log.Used then
          STextUtils.WriteBom(Log, True);
        STextUtils.WriteText(Log, 'Move file failed: "' + UTF8Encode(Pair.Old) +
          '" to "' + UTF8Encode(Pair.New) + '"');
        STextUtils.WriteLine(Log, True);
      end;
    end;
    SFiles.DeleteEmptyDirs(Server);
  except
  end;
  Log.Free();
  MemRec.Free();
  MemStr.Free();
  ListSrv.Free();
  ListCli.Free();
  Pairs.Free();
  if OldCur <> '' then
    SFiles.UseCurrentDirectory(OldCur);
end;

end.

