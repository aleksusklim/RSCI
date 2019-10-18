program RSCI_export;

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
    Assure(SFiles.IsDirectory(Name));
    Target := Name + WideString('.' + STextUtils.TimeToString(Now()) + '\');
    Name := Name + WideString('\');
    SFiles.CreateDirectory(Target);
    Assure(SFiles.IsDirectory(Target));
    RSCI_walk(Name, Target);
    SFiles.DeleteEmptyDirs(Target);
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
    Writeln('This is "RSCI_export.exe" component (v1.2)');
    Writeln('Usage: RSCI_export.exe "path" ["..."]');
    Writeln('');
    Writeln('Cast to any non-versioned directory on NTFS drive to turn it to a server.');
    Writeln('All files will be preserved, now with versioning information attached.');
    Writeln('The process can take long because all files mush be hashed.');
    Writeln('');
    Writeln('Cast to already created server to update it. If any of files were modified');
    Writeln('  since last call, the hash will be recalculated; otherwise, the process');
    Writeln('  should be fast. Any non-versioned file will be also added to server.');
    Writeln('');
    Writeln('In any case, new "dirname.XXXXX" folder will be created,');
    Writeln('  and this is a new client for your server. Client directory has zeroed files');
    Writeln('  from server, and you can move it outside to work alone.');
    Writeln('');
    Writeln('You can use "RSCI_show.exe" on client to get a list of original files.');
    Writeln('To remove a server (but only versioning information and hashes, not files)');
    Writeln('  use "RSCI_clear.exe" program.');
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

