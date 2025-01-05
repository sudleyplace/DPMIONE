;' $Header$
	title	DPMI_D16 -- DPMI.LOD DPMI INT 16h Translation Services
	page	58,122
	name	DPMI_D16
COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1991-2002 Sudley Place Software.   

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include PTR.INC
	include DPMI.INC
	include CPUFLAGS.INC
	include KEYCALL.INC

	include QMAX_I31.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_SEG.INC
.list

CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
	assume	cs:PGROUP

	extrn	INTPROC00Z:near

CODE16A ends			; End CODE16A segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	extrn	DPMI_CPIHOOK:byte
	extrn	LPMSTK_FVEC:fword

DATA	ends			; End DATA segment


; Define BIOS INT 16h functions which we handle

DPMIKEYMAC macro VAL,ACT

ACTSEG	segment use32 dword public 'data' ; Start ACTSEG segment
	assume	ds:DGROUP

	org	DPMIKEY_ACT + VAL * (type DPMIKEY_ACT) ; Set to appropriate origin
	dd	offset DGROUP:INT16_DPMIJMP_&ACT
	org	DPMIKEY_ACTZ	; Restore to end of the table

ACTSEG	ends			; End ACTSEG segment

	endm			; DPMIKEYMAC


ACTSEG	segment use32 dword public 'data' ; Start ACTSEG segment
	assume	ds:DGROUP

	public	@DPMI_D16_ACTSEG
@DPMI_D16_ACTSEG label byte	; Mark module start in .MAP file

	public	DPMIKEY_ACT
DPMIKEY_ACT dd	256 dup (offset DGROUP:INT16_DPMIJMP_PASSTHRU) ; Seed with pass through action
DPMIKEY_ACTZ label dword

ACTSEG	ends			; End ACTSEG segment


; The following KEYCALL functions require special treatment

.sall
; No functions use segment registers, we need this module for pass through
.lall


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_D16_DATA
@DPMI_D16_DATA	label byte	; Mark module start in .MAP file

DLBL	macro	LBL
INT16_DPMIJMP_&LBL label dword
	endm			; DLBL


ACT	macro	LBL
	dd	offset PGROUP:INT16_DPMI_&LBL
	endm			; ACT


DOSFN	macro	LBL,ARGS
	dd	offset PGROUP:DOSFN_&LBL
ifnb <ARGS>
	dd	ARGS
endif				; IFNB
	endm			; DOSFN


	public	JMPTAB16
JMPTAB16 label	dword
.sall
	DLBL	PASSTHRU	; Pass through label for all other functions
	DOSFN	SAVE_VMCREGS
	DLBL	SIMVMI
	DOSFN	SIMVMI,16h
	DOSFN	REST_VMCREGS
	ACT	EXIT
.lall

DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_D16_PROG
@DPMI_D16_PROG: 		; Mark module start in .MAP file

	extrn	PMINTCOM:near
	extrn	DOSFN_SAVE_VMCREGS:near
	extrn	DOSFN_SIMVMI:near
	extrn	DOSFN_REST_VMCREGS:near
	extrn	DOSFN_IF32ZX:near
	extrn	DPMIFN_LPMSTK:near

	FPPROC	INT16_DPMI -- BIOS Calls from DPMI Clients
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

BIOS calls from DPMI clients

On entry:

AH	=	function #

|

; If the caller is at PL0, don't pass on to any DPMI clients

	test	[esp].INTDPI_CS,mask $PL ; Izit at PL0?
	jz	short INT16_INTRETPM ; Jump if so

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_CPIHOOK[16h/8],1 shl (16h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT16_INTRETPM ; Jump if not

	mov	[esp].INTCOM_INTNO,4*16h + offset PGROUP:INTPROC00Z

	push	@PMINTCOM_NRM	; Use application stack
	jmp	near ptr PMINTCOM ; Jump to common code

; We're back to handle it ourselves

	public	INT16_INTRETPM
INT16_INTRETPM:
	PUSHD	0		; Put pseudo-error code onto stack

	pushad			; All EGP registers

	cld			; Ensure string ops forwardly
	mov	ebp,esp 	; SS:EBP ==> INTXX_STR
				; (nothing above INTXX_SS is valid)
	REGSAVE <ds,es> 	; Save segment registers

; Note that the above REGSAVE is mapped by I31_STR and must be
; consistent with it

	SETDATA es		; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	push	LPMSTK_FVEC.FSEL.EDD ; Save current LPM stack top
	push	LPMSTK_FVEC.FOFF ; ...

; Set new LPM stack top for nested callers if it's active
; and we're called from PM, not PL0

	lea	eax,[ebp].INTXX_EIP ; SS:EAX ==> INTDPI_STR from PL3
	push	eax		; Pass the offset
	call	DPMIFN_LPMSTK	; Save new LPM stack as appropriate

; Enable interrupts if the caller has them enabled

	push	[ebp].INTXX_EFL ; Get caller's flags
	and	[esp].ELO,not ((mask $NT) or (mask $DF) or (mask $TF)) ; NT=TF=DF=0
	popfd			; Put caller's IF into effect

	movzx	eax,[ebp].INTXX_EAX.ELO.HI ; Copy function code
	mov	esi,DPMIKEY_ACT[eax*(type DPMIKEY_ACT)] ; ES:ESI ==> action stream

	lods	JMPTAB16[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

	assume	es:DGROUP	; Tell the assembler about it
INT16_DPMI_EXIT:
	pop	LPMSTK_FVEC.FOFF ; Restore
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

	cli			; Disable interrupts to avoid HW interrupt
				; after POPAD looking like a VM interrupt
	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	popad			; Restore all EGP registers

	add	esp,size INTXX_ERR ; Strip off pseudo-error code

	iretd			; Return to caller (PM only)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT16_DPMI endp 		; End INT16_DPMI procedure

PROG	ends			; End PROG segment

	MEND			; End DPMI_D16 module
