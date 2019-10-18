program RSCI_import;

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
  Name, Target: WideString;
begin
  try
    Name := SFiles.NoBackslash(SFiles.GetFullName(Filename));
    Target := SFiles.RemoveExtension(Name);
    Assure(Target <> '');
    Assure(SFiles.IsDirectory(Target) and SFiles.IsDirectory(Name));
    RSCI_combine(Name + WideString('\'), Target + WideString('\'), Name + '.LOG');
  except
  end;
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
    Writeln('This is "RSCI_import.exe" component (v1.2)');
    Writeln('Usage: RSCI_import.exe "path.XXXX" ["..."]');
    Writeln('');
    Writeln('Cast to client directory. It must be located at default place,');
    Writeln('  with the name like "server.anything", where "server" part is');
    Writeln('  actually a name of versioned server folder in');
    Writeln('  the same parent NTFS directory.');
    Writeln('');
    Writeln('Server will be synchronized with client. That is, all files will be');
    Writeln('  moved or renamed according to their path in client directory.');
    Writeln('Because of versioning, the program will know each file by hash');
    Writeln('  to successfully locate it in both client and server.');
    Writeln('The sync process will fail if versioned files on server and client');
    Writeln('  are not equal; or if for a new path, there is already something on');
    Writeln('  the server (so you cannot exchange two files or folders in one operation).');
    Writeln('Note than any empty directory (or a directory tree) will be');
    Writeln('  permanently removed from server! To preserve empty folders,');
    Writeln('  you will have to put something there by yourself.');
    Writeln('To add new files to server, use "RSCI_export.exe" and make new client.');
    Writeln('To delete files, first move them to a new directory on client, then');
    Writeln('  sync with server, remove it from server manually, and make new client.');
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

