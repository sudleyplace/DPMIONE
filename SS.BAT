@echo off
Set FF=
Set SR=
izitswat
if errorlevel 1 Set SR=SWATRUN
if errorlevel 1 Set FF=DEBUG
%SR% r:\lib\ff.com %1 %2 %3 %4 %5 %6 %7 %8 %9
Set SR=
Set FF=
