;' $Header$
;
; (C) Copyright 1995-2003 Sudley Place Software.   
;
; DPMI_SEG.INC
;
; All segments in DPMI.LOD in order of appearance
;

PGROUP	group	CODE16A,CODE16,PROG,CODEZ
DGROUP	group	DATA16,DATA,VALSEG,ACTSEG,DATAZ
XGROUP	group	XCODE,XDATA,ASEGLEN,ASEGTAB,ASEGACT,XDATAZ
YGROUP	group	YCODE
ZGROUP	group	ZZZZZ
PSPGRP	group	PSPSEG


CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
CODE16A ends			; End CODE16A segment


CODE16	segment use32 byte public 'prog' ; Start CODE16 segment
CODE16	ends			; End CODE16 segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
PROG	ends			; End PROG segment


CODEZ	segment use32 para public 'codez' ; Start CODEZ segment
CODEZ	ends			; End CODEZ segment


DATA16	segment use16 dword public 'data' ; Start DATA16 segment
DATA16	ends			; End DATA16 segment


DATA	segment use32 dword public 'data' ; Start DATA segment
DATA	ends			; End DATA segment


VALSEG	segment use32 byte public 'data' ; Start VALSEG segment
VALSEG	ends			; End VALSEG segment


ACTSEG	segment use32 dword public 'data' ; Start ACTSEG segment
ACTSEG	ends			; End ACTSEG segment


DATAZ	segment use32 dword public 'data' ; Start DATAZ segment
DATAZ	ends			; End DATAZ segment

; Note that XCODE must follow DATAZ so that REST_REAL code/data
; is contiguous with the tail of PGROUP/DGROUP

XCODE	segment use16 para public 'xcode' ; Start XCODE segment
XCODE	ends			; End XCODE segment


XDATA	segment use16 dword public 'xdata' ; Start XDATA segment
XDATA	ends			; End XDATA segment


ASEGLEN segment use16 word public 'xdata' ; Start ASEGLEN segment
ASEGLEN ends			; End ASEGLEN segment


ASEGTAB segment use16 word public 'xdata' ; Start ASEGTAB segment
ASEGTAB ends			; End ASEGTAB segment


ASEGACT segment use16 word public 'xdata' ; Start ASEGACT segment
ASEGACT ends			; End ASEGACT segment


XDATAZ	segment use16 para public 'xdataz' ; Start XDATAZ segment
XDATAZ	ends			; End XDATAZ segment


YCODE	segment use16 para public 'ycode' ; Start YCODE segment
YCODE	ends			; End YCODE segment


ZZZZZ	segment use16 para public 'zzzzz' ; Start ZZZZZ segment
ZZZZZ	ends			; End ZZZZZ segment


PSPSEG	segment use16 at 0	; Start PSPSEG segment
PSPSEG	ends			; End PSPSEG segment


STACK	segment use16 byte stack ; Start STACK segment
STACK	ends			; End STACK segment


