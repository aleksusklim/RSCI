@echo off
:main
set /p "name=Project name:"
if not defined name goto :main
if exist "%name%" echo "Already exists!" & goto :main
mkdir "%name%"
if not exist "%name%" echo "Cannot create!" & goto :main
mkdir "%name%\src"
mkdir "%name%\src\shl"
copy /y "SHL_*.pas" "%name%\src\shl\SHL_*.pas"
copy /y "SHL.bat" "%name%\src\shl\SHL.bat"
date /t>"%name%\src\shl\SHL.txt"
