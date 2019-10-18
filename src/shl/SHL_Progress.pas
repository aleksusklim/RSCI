unit SHL_Progress; // SpyroHackingLib is licensed under WTFPL

interface

uses
  SysUtils, Classes, SHL_Types;

type
  TConsoleProgress = class(TObject)
    constructor Create(MaxValue: Integer; MinValue: Integer = 0; Timeout: Integer = 1000);
  public
    procedure Show(Current: Integer);
    procedure Step(Count: Integer = 1);
    procedure Success();
  private
    FTimeout: Integer;
    FOldValue, FOldPrint, FRealValue: Integer;
    FOldTime: TDateTime;
    FMinimal: Integer;
    FBody: Double;
  end;

implementation

uses
  DateUtils;

constructor TConsoleProgress.Create(MaxValue: Integer; MinValue: Integer = 0;
  Timeout: Integer = 1000);
begin
  inherited Create();
  FTimeout := Timeout;
  FOldValue := Integer($80000000);
  FOldPrint := FOldValue;
  FMinimal := MinValue;
  FBody := (MaxValue - MinValue);
  Show(0);
  Ignore(Timeout);
end;

procedure TConsoleProgress.Show(Current: Integer);
var
  Time: TDateTime;
  Print: Integer;
begin
  FRealValue := Current;
  if Current = FOldValue then
    Exit;
  Print := Round((Current - FMinimal) / FBody * 100);
  if Print = FOldPrint then
    Exit;
  Time := Now();
  if MilliSecondsBetween(Time, FOldTime) < FTimeout then
    Exit;
  if Print < 0 then
    Print := 0
  else if Print > 100 then
    Print := 100;
  Write(#9, Print, ' % ', #9#13);
  FOldValue := Current;
  FOldPrint := Print;
  FOldTime := Time;
end;

procedure TConsoleProgress.Step(Count: Integer = 1);
begin
  Show(FRealValue + Count);
end;

procedure TConsoleProgress.Success();
begin
  WriteLn(#9, '100 %');
end;

end.

