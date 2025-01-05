;' $Header$
;
; (C) Copyright 1987-2001 Sudley Place Software.
;
; GXT_SEG.INC
;
; All segments in MMEXT in order of appearance
;

PGROUP	group	P1ST,PTSR,PROG
PCODEZ	group	CODEZ
DGROUP	group	DATA16,DATA,DATAZ
NGROUP	group	NCODE,NDATA,ASEGLEN,ASEGTAB,ASEGACT,NDATAZ
XGROUP	group	XCODE,XDATA,XDATAZ
RGROUP	group	RCODE0,RCODE,RDATAZ


P1ST	segment use32 byte public 'prog' ; Start P1ST segment
P1ST	ends			; End P1ST segment


PTSR	segment use32 para public 'prog' ; Start PTSR segment
PTSR	ends			; End PTSR segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
PROG	ends			; End PROG segment


CODEZ	segment use16 para public 'codez' ; Start CODEZ segment
CODEZ	ends			; End CODEZ segment


DATA16	segment use32 dword public 'data' ; Start DATA16 segment
DATA16	ends			; End DATA16 segment


DATA	segment use32 dword public 'data' ; Start DATA segment
DATA	ends			; End DATA segment


DATAZ	segment use32 dword public 'data' ; Start DATAZ segment
DATAZ	ends			; End DATAZ segment


NCODE	segment use16 para public 'ncode' ; Start NCODE segment
NCODE	ends			; End NCODE segment


NDATA	segment use16 dword public 'ndata' ; Start NDATA segment
NDATA	ends			; End NDATA segment


ASEGLEN segment use16 word public 'ndata' ; Start ASEGLEN segment
ASEGLEN ends			; End ASEGLEN segment


ASEGTAB segment use16 word public 'ndata' ; Start ASEGTAB segment
ASEGTAB ends			; End ASEGTAB segment


ASEGACT segment use16 word public 'ndata' ; Start ASEGACT segment
ASEGACT ends			; End ASEGACT segment


NDATAZ	segment use16 para public 'ndataz' ; Start NDATAZ segment
NDATAZ	ends			; End NDATAZ segment


XCODE	segment use16 para public 'xcode' ; Start XCODE segment
XCODE	ends			; End XCODE segment


XDATA	segment use16 dword public 'xdata' ; Start XDATA segment
XDATA	ends			; End XDATA segment


XDATAZ	segment use16 para public 'xdataz' ; Start XDATAZ segment
XDATAZ	ends			; End XDATAZ segment


RCODE0	segment use16 para public 'rcode' ; Start RCODE0 segment
RCODE0	ends			; End RCODE0 segment


RCODE	segment use16 para public 'rcode' ; Start RCODE segment
RCODE	ends			; End RCODE segment


RDATAZ	segment use16 para public 'rdataz' ; Start RDATAZ segment
RDATAZ	ends			; End RDATAZ segment


STACK	segment use16 byte stack ; Start STACK segment
STACK	ends			; End STACK segment


