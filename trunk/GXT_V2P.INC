;' $Header$
;
; (C) Copyright 1995-2002 Qualitas, Inc.  All rights reserved.
;
; GXT_V2P.INC
;
; VM to PM equates
;
	include GXT_PRG.INC

@GXTV2P_IPROT  equ  0		; Call INIT_PROT
@GXTV2P_GETTAB equ  1		; Read LOADTAB values
@GXTV2P_RREAL  equ  2		; Call REST_REAL
@GXTV2P_RPROT  equ  3		; Call REST_PROT


CALLPL0 macro	NN

ifnb <NN>
	mov	bx,@GXTV2P_&NN	; Get function code
endif
	CALLPL0_SIG		; Define the signature
	div	ax		; Call routine in PL0

	endm			; CALLPL0


CALLPL0_SIG macro
	local	L1

	jmp	short L1	; Skip over signature

	db	@PROGNAME,0	; RM/VM to PM switch signature
L1:
	db	33h,0C0h	; XOR eAX,eAX

	endm			; CALLPL0_SIG

