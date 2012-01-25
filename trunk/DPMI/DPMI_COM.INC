;' $Header$
;
; (C) Copyright 1995-2001 Qualitas, Inc.  All rights reserved.
;
; DPMI_COM.INC
;
; Common strucs and equates for DPMI.LOD
;

@IOMAP	equ	2000h		; Byte size of I/O bit permission map

XMSMEM_STR struc

XMSMEM_HNDL dw	?		; XMS handle
XMSMEM_LEN dd	?		; XMS block's length in 1KB
XMSMEM_PA dd	?		; ...	      physical address

XMSMEM_STR ends

@XMSMEM_LEN equ 32		; Maximum # entries


SETDATA macro	SREG,FL

ifnb <FL>
	pushfd			; Save flags
endif				; IFNB <FL>
	push	cs		; Get code selector
	add	[esp].ELO,size DESC_STR ; Skip to data selector
	or	[esp].ELO,RPL3	; Set to RPL3
	pop	SREG		; Address it
ifnb <FL>
	popfd			; Restore flags
endif				; IFNB <FL>

	endm			; SETDATA


BT_MAC	macro	INSTR,EA,NN

	INSTR	EA[(NN/32)*4],NN mod 32 ; Enable/disable it

	endm			; BT_MAC


EXITDPL macro	NN,FL
	local	INTxx_ORIG,L1

; The stack is mapped by INTCOM_STR.
; If we were called from DPMI, nothing above INTCOM_SS is valid.

; Pass control to the next handler in sequence.
; If the caller's CPL is greater than the next handler's DPL,
; pass it on as a GP Fault with error code.  Otherwise,
; continue with the next handler.

ifb <FL>
	test	[esp].INTCOM_EFL.EHI,mask $VM ; Izit from VM86 mode?
	jnz	short L1	; Jump if so

	test	[esp].INTCOM_CS,mask $PL ; Izit CPL=0?
	jz	near ptr INTPROC&NN ; Jump if so
L1:
endif				; IFB <FL>
	push	0&NN&h*(type IDT_STR) or (mask $FIDT) ; Set error code

	PUSHW	ds		; Save for a moment

EXITDPL&NN&_STR struc

	dw	?		; Caller's DS
	dd	?		; Error code
EXITDPL&NN&_NXT db (type INTCOM_STR) dup (?) ; The rest of the stack

EXITDPL&NN&_STR ends

; The stack is mapped by EXITDPL&NN&_STR

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

; If the interrupt was external, the CPL vs DPL is ignored
; however, that's handled by our GP Fault handler

;;;;;;; test	INT_ERRCODE,mask $FEXT ; Izit external?
;;;;;;; jnz	short INTxx_ORIG ; Jump if so
;;;;;;;
	test	OLDINT_ARB[0&NN&h*(type OLDINT_ARB)],mask $DT_DPL ; Izit DPL < 3?
	jz	short @F	; Jump if so (DPL=0)
	jpe	short INTxx_ORIG ; Jump if not (DPL=3)
@@:				; Fall through with DPL=1,2
	sub	[esp].EXITDPL&NN&_NXT.INTCOM_EIP,2 ; Back up to INT xx instruction

	push	OLDINT0D_FVEC.FSEL ; Pass the selector
	push	OLDINT0D_FVEC.FOFF ; ...  the offset

DPLINT&NN&_STR struc

	df	?		; Return CS:EIP
DPLINT&NN&_DS dw ?		; Caller's DS

DPLINT&NN&_STR ends

	mov	ds,[esp].DPLINT&NN&_DS ; Restore
	assume	ds:nothing	; Tell the assembler about it

	retf			; Continue as GP Fault

INTxx_ORIG:
	POPW	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	add	esp,type INTXX_ERR ; Strip error code

	jmp	INTPROC&NN&	; Jump if so (call as VM INT 0&NN&h)

	endm			; EXITDPL


