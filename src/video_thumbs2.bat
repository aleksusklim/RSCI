@echo off
:main
set "SRC=%~f1"
if not defined SRC exit /b
set "FF=%~dp0ffmpeg.exe"
if not exist "%FF%" set "FF=ffmpeg.exe"
set "ROOT=%SRC%\"
if not exist "%ROOT%" exit /b
::goto :robo
for /R "%ROOT%" %%i in (*.avi;*.mp4;*.3gp) do set "FROM=%%i" & set "NAME=%%~nxi"& set "DIR=%%~dpni" & call :proc
:robo
set "RC=%~dp0robocopy.exe"
if not exist "%RC%" set "RC=robocopy.exe"
set "DST=%SRC%_thumbs"
echo "%DST%"
"%RC%" "%SRC%" "%DST%" /MOVE /IS /IT /S /NFL /NDL /NJH /NJS /NC /NS /NP "thumb_??.jpg"
shift
goto :main

:proc
setlocal ENABLEDELAYEDEXPANSION
echo "!NAME!"
if not exist "!DIR!" mkdir "!DIR!"
set /a SEC=30
set /a CNT=1
:loop
if !CNT! lss 10 ( set "CNTS=0!CNT!" ) else set "CNTS=!CNT!"
set "TO=!DIR!\thumb_!CNTS!.jpg"
if not exist "!TO!" "%FF%" -nostdin -loglevel quiet -y -ss "!SEC!" -i "!FROM!" -s 512x320 -vframes 1 "!TO:%%=%%%%!"
set /a CNT=CNT+1
set /a SEC=SEC*3/2
if exist "!TO!" goto :loop
exit /b
