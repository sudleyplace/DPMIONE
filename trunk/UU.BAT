@echo off
Set SR=
izitswat
if errorlevel 1 Set SR=SWATRUN
%SR% ret\dpmione uninstall
Set SR=
