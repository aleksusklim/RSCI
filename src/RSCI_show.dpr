program RSCI_show;

{$APPTYPE CONSOLE}

uses
  Windows,
  SysUtils,
  Classes,
  SHL_Classes,
  SHL_Types,
  SHL_BufferedStream,
  RSCI_core;

procedure Main(Name: WideString);
begin
  Name := SFiles.NoBackslash(SFiles.GetFullName(Name)) + WideString('\');
  Assure(SFiles.IsDirectory(Name));
  RSCI_log(Name);
end;

var
  Arg: ArrayOfWide;
  Par: Integer;
  Wait: TextString;

begin
  Arg := SFiles.GetArguments();
  if Length(Arg) <= 1 then
  begin
    WriteLn('Remote Server-Client Interface (simple rename file operations) tool.');
    WriteLn('This is "RSCI_show.exe" component  (v1.2)');
    WriteLn('Usage: RSCI_show.exe "path" ["..."]');
    WriteLn('');
    WriteLn('Cast to client directory to create there "RSCI.LOG" file in each folder.');
    WriteLn('This file will show you real content data for all child objects:');
    WriteLn('');
    WriteLn('".\name" - current directory;');
    WriteLn('\name\ - subdirectory;');
    WriteLn('"name" - file;');
    WriteLn('(number XX /bytes) - size;');
    WriteLn('dd.mm.yyyy,hh:mm - modification timestamp;');
    WriteLn('<.string> - extension;');
    WriteLn('<children/totalfiles> - counters;');
    WriteLn('[date] - creation timestamp;');
    WriteLn('{hex} - hash SHA-1;');
    WriteLn('');
    WriteLn('Encoding of RSCI.LOG: UTF-8 + BOM.');
    WriteLn('This file is not versioned and will not be transferred to server.');
    WriteLn('You can remove all logs from client with "RSCI_clear.exe".');
    WriteLn('Do not use this program on server (it will not do anything there).');
    WriteLn('Log in the root folder will also show file duplicates from the entire tree.');
    WriteLn('');
    WriteLn('Press ENTER to close this window!');
    Readln(Wait);
  end
  else
    for Par := 1 to Length(Arg) - 1 do
    try
      Main(Arg[Par]);
    except
    end;
end.

