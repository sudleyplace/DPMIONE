@echo off
pkzip pmlsrc *.asm *.inc makefile *.wsg *.pro
cd dpmi
pkzip dpmi *.asm *.inc makefile *.wsg *.pro
