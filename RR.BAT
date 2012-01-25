@echo off
Set SR=
izitswat
if errorlevel 1 Set SR=SWATRUN
%SR% r:\lib\qlink @ret\dpmione.arf
Set SR=
