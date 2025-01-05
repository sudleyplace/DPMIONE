;' $Header$
	title	DPMI_D15 -- DPMI.LOD DPMI INT 15h Translation Services
	page	58,122
	name	DPMI_D15
COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1991-2002 Sudley Place Software.  All rights reserved.

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include PTR.INC
	include DPMI.INC
	include CPUFLAGS.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_SEG.INC

	include QMAX_I31.INC		; Must precede QMAXDPMI.INC
	include QMAXDPMI.INC		; Must follow QMAX_I31.INC
	include QMAX_TSS.INC
.list

CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
	assume	cs:PGROUP

	extrn	INTPROC00Z:near

CODE16A ends			; End CODE16A segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	extrn	DPMI_CPIHOOK:byte
	extrn	VMCREGS:tbyte
	extrn	PCURTSS:dword
	extrn	LPMSTK_FVEC:fword

DATA	ends			; End DATA segment


; Define BIOS INT 15h functions which we handle

DPMIBIOSMAC macro VAL,ACT

ACTSEG	segment use32 dword public 'data' ; Start ACTSEG segment
	assume	ds:DGROUP

	org	DPMIBIOS_ACT + VAL * (type DPMIBIOS_ACT) ; Set to appropriate origin
	dd	offset DGROUP:INT15_DPMIJMP_&ACT
	org	DPMIBIOS_ACTZ	; Restore to end of the table

ACTSEG	ends			; End ACTSEG segment

	endm			; DPMIBIOSMAC


ACTSEG	segment use32 dword public 'data' ; Start ACTSEG segment
	assume	ds:DGROUP

	public	@DPMI_D15_ACTSEG
@DPMI_D15_ACTSEG label byte	; Mark module start in .MAP file

	public	DPMIBIOS_ACT
DPMIBIOS_ACT dd 256 dup (offset DGROUP:INT15_DPMIJMP_PASSTHRU) ; Seed with pass through action
DPMIBIOS_ACTZ label dword

ACTSEG	ends			; End ACTSEG segment


; The following BIOS functions require special treatment

.sall
	DPMIBIOSMAC  87h,MOVEBLOCK	; 87:  Move block using GDT at ES:eSI
	DPMIBIOSMAC 0C0h,BIOSCONF	; C0:  Get BIOS configuration data into ES:eBX
	DPMIBIOSMAC 0C1h,XBDASEG	; C1:  Get extended BIOS data segment into ES
	DPMIBIOSMAC 0C2h,PDBI		; C2:  Pointing Device BIOS Interface
.lall


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_D15_DATA
@DPMI_D15_DATA	label byte	; Mark module start in .MAP file

DLBL	macro	LBL
INT15_DPMIJMP_&LBL label dword
	endm			; DLBL


ACT	macro	LBL
	dd	offset PGROUP:INT15_DPMI_&LBL
	endm			; ACT


DOSFN	macro	LBL,ARGS
	dd	offset PGROUP:DOSFN_&LBL
ifnb <ARGS>
	dd	ARGS
endif				; IFNB
	endm			; DOSFN


	public	JMPTAB15
JMPTAB15 label	dword
.sall
	DLBL	MOVEBLOCK	; 87:  Move block using GDT at ES:eSI
	DOSFN	SAVE_INTXXREG,<INTXX_ESI>
	DOSFN	SAVE_VMCREGS
	ACT	MOVEBLOCK
	DOSFN	GETBUF,<VMC_ESI.ELO,VMC_ES,INTXX_ESI,I31_ES-@I31BACK>
	DOSFN	SIMVMI,15h
	DOSFN	RELBUF		; No need to copy back the GDT
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_ESI>
	ACT	EXIT


	DLBL	BIOSCONF	; C0:  Get BIOS configuration data into ES:eBX
	DOSFN	SAVE_VMCREGS
	DOSFN	SIMVMI,15h
	DOSFN	SEG2SEL,<@DATASEL,VMC_ES,I31_ES-@I31BACK>
	DOSFN	IF32ZX,<VMC_EBX.EHI>
	DOSFN	REST_VMCREGS
	ACT	EXIT


	DLBL	XBDASEG 	; C1:  Get extended BIOS data segment into ES
	DOSFN	SAVE_VMCREGS
	DOSFN	SIMVMI,15h
	DOSFN	SEG2SEL,<@DATASEL,VMC_ES,I31_ES-@I31BACK>
	DOSFN	REST_VMCREGS
	ACT	EXIT


	DLBL	PDBI		; C2:  Pointing Device BIOS Interface
	DOSFN	SAVE_INTXXREG,<INTXX_EBX>
	DOSFN	SAVE_VMCREGS
	ACT	PDBI
	DOSFN	SIMVMI,15h
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EBX>
	ACT	EXIT


	DLBL	PASSTHRU	; Pass through label for all other functions
	DOSFN	SAVE_VMCREGS
	DLBL	SIMVMI
	DOSFN	SIMVMI,15h
	DOSFN	REST_VMCREGS
	ACT	EXIT
.lall

DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_D15_PROG
@DPMI_D15_PROG: 		; Mark module start in .MAP file

	extrn	PMINTCOM:near
	extrn	DOSFN_SAVE_INTXXREG:near
	extrn	DOSFN_SAVE_VMCREGS:near
	extrn	DOSFN_GETBUF:near
	extrn	DOSFN_SIMVMI:near
	extrn	DOSFN_RELBUF:near
	extrn	DOSFN_REST_VMCREGS:near
	extrn	DOSFN_REST_INTXXREG:near
	extrn	DOSFN_SEG2SEL:near
	extrn	DOSFN_IF32ZX:near
	extrn	DPMIFN_LPMSTK:near

	FPPROC	INT15_DPMI -- BIOS Calls from DPMI Clients
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

BIOS calls from DPMI clients

On entry:

AH	=	function #

|

; If the caller is at PL0, don't pass on to any DPMI clients

	test	[esp].INTDPI_CS,mask $PL ; Izit at PL0?
	jz	short INT15_INTRETPM ; Jump if so

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_CPIHOOK[15h/8],1 shl (15h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT15_INTRETPM ; Jump if not

	mov	[esp].INTCOM_INTNO,4*15h + offset PGROUP:INTPROC00Z

	push	@PMINTCOM_NRM	; Use application stack
	jmp	near ptr PMINTCOM ; Jump to common code


; We're back to handle it ourselves

	public	INT15_INTRETPM
INT15_INTRETPM:
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
	mov	esi,DPMIBIOS_ACT[eax*(type DPMIBIOS_ACT)] ; ES:ESI ==> action stream

	lods	JMPTAB15[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 87:  Move block using GDT at ES:SI

; On entry (in PL3 stack):
; ES:SI  ==>	 string to display

; On entry (in registers):
; ES:ESI ==>	 action stream
; ES	 =	 DGROUP
; SS:EBP ==>	 INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT15_DPMI_MOVEBLOCK:
	mov	eax,size MDTE_STR ; Get size of move GDT

	push	eax		; RELBUF:  # bytes to release in buffer
	push	eax		; GETBUF:  # leading bytes to copy
	push	eax		; GETBUF:  # bytes to allocate in buffer

	lods	JMPTAB15[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; C2:  Pointing Device BIOS Interface

; On entry (in PL3 stack):
; For AL = 07h
; ES:eBX ==>	 PM Mouse Event Interrupt handler

; On entry (in registers):
; ES:ESI ==>	 action stream
; ES	 =	 DGROUP
; SS:EBP ==>	 INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT15_DPMI_PDBI:
	cmp	[ebp].INTXX_EAX.ELO.LO,07h ; Izit hook call?
	jne	short INT15_DPMI_PDBI_CONT ; Jump if not (continue on)

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	mov	bx,[ebp-@I31BACK].I31_ES ; Get caller's selector
	mov	DGROUP:[eax].DPTSS_MEI_FVEC.FSEL,bx ; Set selector

	mov	ebx,[ebp].INTXX_EBX ; Get offset
	mov	DGROUP:[eax].DPTSS_MEI_FVEC.FOFF,ebx ; Set offset

	mov	bx,DGROUP:[eax].DPTSS_HPDASEG ; Get segment of HPDA
	mov	VMCREGS.VMC_ES,bx ; Pass to VM
	mov	VMCREGS.VMC_EBX.ELO,offset HPDA_PDBI ; Save offset
INT15_DPMI_PDBI_CONT:
	lods	JMPTAB15[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

	assume	es:DGROUP	; Tell the assembler about it
INT15_DPMI_EXIT:
	cli			; Disable interrupts to avoid HW interrupt
				; after POPAD looking like a VM interrupt
	pop	LPMSTK_FVEC.FOFF ; Restore
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	popad			; Restore all EGP registers

	add	esp,size INTXX_ERR ; Strip off pseudo-error code

	iretd			; Return to caller (PM only)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT15_DPMI endp 		; End INT15_DPMI procedure

PROG	ends			; End PROG segment

	MEND			; End DPMI_D15 module
