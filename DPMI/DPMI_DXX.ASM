;' $Header$
	title	DPMI_Dxx -- DPMI.LOD DPMI INT xxh Translation Services
	page	58,122
	name	DPMI_Dxx
COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1991-2003 Sudley Place Software.  All rights reserved.

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include PTR.INC
	include DPMI.INC
	include CPUFLAGS.INC

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

	public	@DPMI_DXX_DATA
@DPMI_DXX_DATA	label byte	; Mark module start in .MAP file

;;;	    public  DPMI_EXIT
;;; DPMI_EXIT dd    0		    ; Count of DPMI_EXITs

	extrn	DPMI_CPIHOOK:byte
	extrn	LPMSTK_FVEC:fword

DLBL	macro	LBL
INTxx_DPMIJMP_&LBL label dword
	endm			; DLBL


ACT	macro	LBL
	dd	offset PGROUP:INTxx_DPMI_&LBL
	endm			; ACT


DOSFN	macro	LBL,ARGS
	dd	offset PGROUP:DOSFN_&LBL
ifnb <ARGS>
	dd	ARGS
endif				; IFNB
	endm			; DOSFN


	public	JMPTABxx
JMPTABxx label	dword
.sall
	DLBL	PASSTHRU
	DOSFN	SAVE_VMCREGS
	DOSFN	SIMVMIXX
	DOSFN	REST_VMCREGS
	ACT	EXIT

	DLBL	IOREF
	DOSFN	SAVE_INTXXREG,<INTXX_EDX>
	DOSFN	SAVE_VMCREGS
	DOSFN	SIMVMCFR
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDX>
	ACT	EXIT
.lall

DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_DXX_PROG
@DPMI_DXX_PROG: 		; Mark module start in .MAP file

	extrn	PMINTCOM:near
	extrn	DOSFN_SAVE_VMCREGS:near
	extrn	DOSFN_SIMVMIXX:near
	extrn	DOSFN_SIMVMCFR:near
	extrn	DOSFN_REST_VMCREGS:near
	extrn	DOSFN_SAVE_INTXXREG:near
	extrn	DOSFN_REST_INTXXREG:near
	extrn	DPMIFN_LPMSTK:near

	FPPROC	INTxx_DPMI -- Non-Special Interrupts from DPMI Clients
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Non-special interrupts from DPMI clients

On entry:

AH	=	function #
INTCOM_INTNO is already filled in.
SS:ESP	==>	INTDPI_STR

|

; If the caller is at PL0, don't pass on to any DPMI clients

	test	[esp].INTDPI_CS,mask $PL ; Izit at PL0?
	jz	short INTxx_INTRETPM ; Jump if so

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

	REGSAVE <eax,ds>	; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	movzx	eax,[esp+4+4].INTDPI_INTNO ; Get INT # * 4 + offset ...
	sub	eax,offset PGROUP:INTPROC00Z ; Less offset to tail
	shr	eax,2-0 	; Divide by four to get INT #

	bt	DPMI_CPIHOOK.EDD,eax ; Izit hooked by current client?
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it
	jnc	short INTxx_INTRETPM ; Jump if not

;;;;;;; mov	[esp].INTCOM_INTNO,4*xxh + offset PGROUP:INTPROC00Z
;;;;;;;
	push	@PMINTCOM_NRM	; Use application stack
	jmp	near ptr PMINTCOM ; Jump to common code


; We're back to handle it ourselves

	public	INTxx_INTRETPM
INTxx_INTRETPM:
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

	lea	esi,INTxx_DPMIJMP_PASSTHRU ; ES:ESI ==> action stream

	lods	JMPTABxx[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

	assume	es:DGROUP	; Tell the assembler about it

	public	INTxx_DPMI_EXIT
INTxx_DPMI_EXIT:
	pop	LPMSTK_FVEC.FOFF ; Restore
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

;;;;;;; inc	DPMI_EXIT	; Count in another value
;;;;;;;
	cli			; Disable interrupts to avoid HW interrupt
				; after POPAD looking like a VM interrupt
	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	popad			; Restore all EGP registers

	add	esp,size INTXX_ERR ; Strip off pseudo-error code

	iretd			; Return to caller (PM only)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INTxx_DPMI endp 		; End INTxx_DPMI procedure
	FPPROC	INT0D_IOREF -- GP Faults From I/O In PM Reflected To VM
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

GP Faults from I/O in PM which need to be reflected to VM

On entry:

SS:ESP	==>	INTDPI_STR

|

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

	lea	esi,INTxx_DPMIJMP_IOREF ; ES:ESI ==> action stream

	lods	JMPTABxx[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT0D_IOREF endp		; End INT0D_IOREF procedure

PROG	ends			; End PROG segment

	MEND			; End DPMI_Dxx module
