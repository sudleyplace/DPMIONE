@echo off
Set SR=
izitswat
if errorlevel 1 Set SR=SWATRUN
%SR% r:\lib\dpmione.exe pro=r:\lib\dpmione.pro %1 %2 %3 %4 %5 %6 %7 %8 %9
Set SR=
