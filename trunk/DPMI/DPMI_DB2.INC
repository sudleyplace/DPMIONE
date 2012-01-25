;' $Header$
;
; (C) Copyright 1987-2004 Qualitas, Inc.  All rights reserved.
;
; DPMI_DB2.INC
;
; Local flags in DB2_FLAG
;

; This data item is constant

@DB2_DPMIPHYS equ 8000h 	; Disable checks in DPMI_GETP2L
@DB2_NODEBUG equ  4000h 	; Disable hooks of INTs 01h and 03h
@DB2_NONMI equ	  2000h 	; Disable hook	of INT	02h
@DB2_NOKEYB equ   1000h 	; Disable hook	of INT	09h
@DB2_LPM16    equ 0800h 	; Force 16-bit LPM stack

