program RSCI_clear;

{$APPTYPE CONSOLE}

uses
  Windows,
  SysUtils,
  Classes,
  SHL_Classes,
  SHL_Types,
  RSCI_core;

procedure Main(Filename: WideString);
var
  Target: WideString;
begin
  Target := SFiles.NoBackslash(SFiles.GetFullName(Filename));
  RSCI_free(Target);
end;

var
  Arg: ArrayOfWide;
  Par: Integer;
  Wait: TextString;

begin
  Arg := SFiles.GetArguments();
  if Length(Arg) <= 1 then
  begin
    Writeln('Remote Server-Client Interface (simple rename file operations) tool.');
    Writeln('This is "RSCI_clear.exe" component (v1.2)');
    Writeln('Usage: RSCI_clear.exe "path" ["..."]');
    Writeln('');
    Writeln('Cast to client directory to recursively delete all "RSCI.LOG" files.');
    Writeln('The versioning information on other (zeroed) files will be preserved.');
    Writeln('');
    Writeln('Cast to server directory to completely remove all versioning information');
    Writeln('  from all files there. You will no longer be able to sync it anymore!');
    Writeln('Also the next server creation fro it will take longer, because all hashes');
    Writeln('  are removed too.');
    Writeln('');
    Writeln('Use this to "remove" a server (all actual files will not be deleted),');
    Writeln('  or to remove all logs from client (that were created by "RSCI_show.exe").');
    Writeln('To remove a client entirely, just delete it manually.');
    Writeln('');
    Writeln('Press ENTER to close this window!');
    Readln(Wait);
  end
  else
    for Par := 1 to Length(Arg) - 1 do
    try
      Main(Arg[Par]);
    except
    end;
end.

