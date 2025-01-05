;' $Header$
;
; (C) Copyright 1987-2003 Sudley Place Software.  All rights reserved.
;
; DPMI_LCL.INC
;
; Local flags in LCL_FLAG
;

; These flags are constant

@LCL_DIS2F equ	8000h		; Disable VME for INT 2Fh in REST_PROT
@LCL_DIS31 equ	4000h		; ...		      31h ...
@LCL_NDPIN equ	2000h		; NDP installed
@LCL_PSWAT equ	1000h		; Preceding SWAT installed
@LCL_HPDA  equ	0800h		; A local HPDA is present
@LCL_NOUMB equ	0400h		; Don't allocate memory in UMBs

