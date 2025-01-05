;' $Header$
	title	DPMI_I0D -- DPMI.LOD INT 0Dh Handler
	page	58,122
	name	DPMI_I0D
COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1987-2004 Sudley Place Software.  All Rights Reserved.

|
.386p
.xlist
	include MASM.INC
	include CPUFLAGS.INC
	include 386.INC
	include PTR.INC
	include OPCODES.INC
	include ALLMEM.INC
	include MOVSPR.INC
	include IOPBITS.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_LCL.INC
	include DPMI_SEG.INC
	include DPMI_SWT.INC

	include QMAX_I31.INC
	include QMAX_TSS.INC
.list

YCODE	segment use16 para public 'ycode' ; Start YCODE segment
	assume	cs:YGROUP

	extrn	DPMI_IO_INPB:near
	extrn	DPMI_IO_INPW:near
	extrn	DPMI_IO_INPD:near
	extrn	DPMI_IO_OUTB:near
	extrn	DPMI_IO_OUTW:near
	extrn	DPMI_IO_OUTD:near

YCODE	ends			; End YCODE segment


CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
	assume	cs:PGROUP

	extrn	INTPROC00Z:near

CODE16A ends			; End CODE16A segment


DATA16	segment use16 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	extrn	LCL_FLAG:word

DATA16	ends			; End DATA16 segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_I0D_DATA
@DPMI_I0D_DATA	label byte	; Mark module start in .MAP file

	extrn	I31_FLAG:word

	extrn	PVMTSS:dword
	extrn	PCURTSS:dword

	extrn	OLDINT0D_FVEC:fword

	extrn	PPL0STK_DNRM:dword
	extrn	PPL0STK_DERR:dword
	extrn	DPMITYPE:byte

	extrn	PPL0STK_NRM:dword
	extrn	PPL0STK_ERR:dword

	extrn	SEL_4GB:word

	extrn	MSG_NF:byte

	extrn	LaIOBIT:dword

	extrn	SAVE_DS0D0E:dword

	public	ReadCRnTab
ReadCRnTab dd	offset PGROUP:ReadCR0 ; Read CR0
	dd	offset PGROUP:ReadCR1 ; ...  CR1
	dd	offset PGROUP:ReadCR2 ; ...  CR2
	dd	offset PGROUP:ReadCR3 ; ...  CR3
	dd	offset PGROUP:ReadCR4 ; ...  CR4
	dd	offset PGROUP:ReadCR5 ; ...  CR5
	dd	offset PGROUP:ReadCR6 ; ...  CR6
	dd	offset PGROUP:ReadCR7 ; ...  CR7

	public	WriteCRnTab
WriteCRnTab dd	offset PGROUP:WriteCR0 ; Write CR0
	dd	offset PGROUP:WriteCR1 ; ...   CR1
	dd	offset PGROUP:WriteCR2 ; ...   CR2
	dd	offset PGROUP:WriteCR3 ; ...   CR3
	dd	offset PGROUP:WriteCR4 ; ...   CR4
	dd	offset PGROUP:WriteCR5 ; ...   CR5
	dd	offset PGROUP:WriteCR6 ; ...   CR6
	dd	offset PGROUP:WriteCR7 ; ...   CR7

	public	INT_ERRCODE
INT_ERRCODE dd	?		; Interrupt error code

	public	SAVE_EAX0D
SAVE_EAX0D dd	?		; Local save area for EAX

	public	DPMI_IO_OFF,DPMI_IO_PORT
DPMI_IO_OFF dw	?		; Offset in YGROUP of emulation routine
DPMI_IO_PORT dw ?		; I/O port

	public	DPMICNT0D
DPMICNT0D dw	0		; Count of active INT 0Dh DPMI calls

DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_I0D_PROG
@DPMI_I0D_PROG: 		; Mark module start in .MAP file

	extrn	RESETVARS:near
	extrn	GETILEN:near
	extrn	$USE32:abs
	extrn	GETARW:near

	extrn	INTXXCOM:near
	extrn	INT0D_DPMI_VISIBLE:near
	extrn	HARDINT:near
	extrn	INTCOM_DPMI_INT:near
	extrn	DPMIFN_LMSW:near
	extrn	INTxx_DPMI:near
	extrn	INT0D_IOREF:near
	extrn	INT06:near

	FPPROC	INT0D -- General Protection Fault Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

General protection interrupt (0Dh) with error code on stack.

Distinguish amongst four cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC0D
GP		 VM86	  ESP=PPL0STK_ERR	Parse caller's CS:IP
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto INTCOM_DPMI_INT
GP		 DPMI	  ESP=PPL0STK_DERR	Parse caller's CS:IP
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT
GP		 PM				UGH

Note that the test for PM interrupts actually tests for CS within
descriptor table limits.  If there is an error code on the stack,
we're testing not caller's CS, but IP.  By construction, IP in our
code can never get small enough to be confused with a valid CS.

|

	call	RESETVARS	; Keep variables up-to-date

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	pop	SAVE_DS0D0E	; Save to restore later

	cmp	esp,PPL0STK_NRM ; Izit a HW/SW interrupt from VM86 mode?
	je	short INTPROC0D ; Yes, use normal interrupt processor

	cmp	esp,PPL0STK_ERR ; Is it a fault from VM86 mode?
	je	near ptr INT0D_VM86 ; Yes

	cmp	esp,PPL0STK_DNRM ; Izit a HW/SW interrupt from a DPMI client?
	je	short INT0D_DPMI_INT ; Jump if so

	cmp	esp,PPL0STK_DERR ; Izit a fault from a DPMI client?
	je	near ptr INT0D_DPMI_FAULT ; Jump if so

; We need to distinguish between HW-MAX and EX-MAX, so we test
; the R3 bit in NRM_EFL.  If it's HW-MAX, NRM_EFL contains EFL
; and that bit is always set.  If it's EX-MAX, NRM_EFL contains
; CS (a selector), and that bit is the high-order bit of CPL.
; As the host never executes at CPL2 or CPL3, that bit is always clear.

	test	[esp].NRM_EFL,mask $R3 ; Izit set?
	jz	near ptr INT0D_UGH ; No, so that's a big UGH

; HW-MAX has occurred:	if there's a DPMI client active, treat it
; as a DPMI interrupt so we use the HPDA stack, not LAST_INTCOM.

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	jne	short INT0D_DPMI_INT ; Jump if so

	mov	[esp].NRM_INTNO,4*0Dh+offset PGROUP:INTPROC00Z ; Mark as hardware INT 0Dh

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	HARDINT 	; It's a hardware interrupt


; Normal stack:  HW/SW interrupt from DPMI host

	assume	ds:DGROUP	; Tell the assembler about it
INTPROC0D:
	push	OLDINT0D_FVEC.FSEL.EDD ; Pass selector as dword
	push	OLDINT0D_FVEC.FOFF	; Pass offset

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	retf			; Continue with original handler


; Hardware/software interrupt from a DPMI client

	assume	ds:DGROUP	; Tell the assembler about it
INT0D_DPMI_INT:
	mov	[esp].NRM_INTNO,4*0Dh+offset PGROUP:INTPROC00Z ; Mark as hardware INT 0Dh

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	INTCOM_DPMI_INT ; Join common DPMI interrupt code


; Fault at PL0 *FIXME*

	assume	ds:DGROUP	; Tell the assembler about it
INT0D_UGH:
	test	LCL_FLAG,@LCL_PSWAT ; Is SWAT installed?
	jz	short @F	; Jump if not

	SWATMAC 		; Call our debugger

	jmp	short @F	; Skip over IRETD frame


	add	esp,type INTXX_ERR ; Strip pseudo-error code

	iretd			; Return to the scene of the GP Fault


@@:

; Fault from VM or a DPMI client -- see if we can emulate it
; The stack is mapped by INTDPF_STR -- move it down to look like
; INTXX_STR.

	assume	ds:DGROUP	; Tell the assembler about it
INT0D_DPMI_FAULT:
INT0D_VM86:
	pushad			; Save all EGP registers

	cld			; String ops forwardly
	mov	ebp,esp 	; SS:EBP ==> INTXX_STR

	mov	[ebp].INTXX_INTNO,4*0Dh+offset PGROUP:INTPROC00Z ; Mark as INT 0Dh

	push	es		; Save for a moment

	test	[ebp].INTXX_EFL.EHI,mask $VM ; Izit from VM86 mode?
	jnz	near ptr INT0D_VM86A ; Jump if so

; In PM, emulate IN/OUT/CLI/STI as they may be new GP Faults to the MM
; because we're running the DPMI client at @DPMIOPL.
; Also emulate LMSW so we can keep track of the NDP emulation status.
; and various INTs at DPL < 3,
; and emulate MOV r32,CRn
;	      MOV CRn,r32

	les	edi,[ebp].INTXX_EIP.EDF ; Get caller's CS:EIP
	assume	es:nothing	; Tell the assembler about it

; Check for INT xx which EMM386 from MS-DOS has at DPL=0

	cmp	es:[edi].LO,@OPCOD_INT ; Izit INT?
	je	near ptr INT0D_PMINT ; Jump if so

	cmp	es:[edi].LO,@OPCOD_INIB ; Izit IN AL,xx?
	mov	DPMI_IO_OFF,offset YGROUP:DPMI_IO_INPB ; Save offset of emulation
	je	near ptr INT0D_PMIO_IMM1 ; Jump if so

	cmp	es:[edi].LO,@OPCOD_INDB ; Izit IN AL,DX?
;;;;;;; mov	DPMI_IO_OFF,offset YGROUP:DPMI_IO_INPB ; Save offset of emulation
	je	near ptr INT0D_PMIO_DX1 ; Jump if so

	cmp	es:[edi].LO,@OPCOD_INIW ; Izit IN AX,xx?
	mov	DPMI_IO_OFF,offset YGROUP:DPMI_IO_INPW ; Save offset of emulation
	je	near ptr INT0D_PMIO_IMM1 ; Jump if so

	cmp	es:[edi].LO,@OPCOD_INDW ; Izit IN AX,DX?
;;;;;;; mov	DPMI_IO_OFF,offset YGROUP:DPMI_IO_INPW ; Save offset of emulation
	je	near ptr INT0D_PMIO_DX1 ; Jump if so

	cmp	es:[edi].ELO,@OPCOD_INID ; Izit IN EAX,xx?
	mov	DPMI_IO_OFF,offset YGROUP:DPMI_IO_INPD ; Save offset of emulation
	je	near ptr INT0D_PMIO_IMM2 ; Jump if so

	cmp	es:[edi].ELO,@OPCOD_INDD ; Izit IN EAX,DX?
;;;;;;; mov	DPMI_IO_OFF,offset YGROUP:DPMI_IO_INPD ; Save offset of emulation
	je	near ptr INT0D_PMIO_DX2 ; Jump if so

	cmp	es:[edi].LO,@OPCOD_OUTIB ; Izit OUT xx,AL?
	mov	DPMI_IO_OFF,offset YGROUP:DPMI_IO_OUTB ; Save offset of emulation
	je	near ptr INT0D_PMIO_IMM1 ; Jump if so

	cmp	es:[edi].LO,@OPCOD_OUTDB ; Izit OUT DX,AL?
;;;;;;; mov	DPMI_IO_OFF,offset YGROUP:DPMI_IO_OUTB ; Save offset of emulation
	je	near ptr INT0D_PMIO_DX1 ; Jump if so

	cmp	es:[edi].LO,@OPCOD_OUTIW ; Izit OUT xx,AX?
	mov	DPMI_IO_OFF,offset YGROUP:DPMI_IO_OUTW ; Save offset of emulation
	je	near ptr INT0D_PMIO_IMM1 ; Jump if so

	cmp	es:[edi].LO,@OPCOD_OUTDW ; Izit OUT DX,AX?
;;;;;;; mov	DPMI_IO_OFF,offset YGROUP:DPMI_IO_OUTW ; Save offset of emulation
	je	near ptr INT0D_PMIO_DX1 ; Jump if so

	cmp	es:[edi].ELO,@OPCOD_OUTID ; Izit OUT xx,EAX?
	mov	DPMI_IO_OFF,offset YGROUP:DPMI_IO_OUTD ; Save offset of emulation
	je	near ptr INT0D_PMIO_IMM2 ; Jump if so

	cmp	es:[edi].ELO,@OPCOD_OUTDD ; Izit OUT DX,EAX?
;;;;;;; mov	DPMI_IO_OFF,offset YGROUP:DPMI_IO_OUTD ; Save offset of emulation
	je	near ptr INT0D_PMIO_DX2 ; Jump if so

; Check for MOV r32,CRn

	cmp	es:[edi].ELO,@OPCOD_MOV_R32_CRn ; Izit MOV r32,CRn?
	je	near ptr INT0D_MOV_R32_CRn ; Jump if so

; Check for MOV CRn,r32

	cmp	es:[edi].ELO,@OPCOD_MOV_CRn_R32 ; Izit MOV CRn,r32?
	je	near ptr INT0D_MOV_CRn_R32 ; Jump if so

; Check for GRP7 (LMSW)

	cmp	es:[edi].ELO,@OPCOD_GRP7 ; Izit GRP7?
	je	short INT0D_PMGRP7 ; Jump if so

; Check for CLI/STI

	cmp	es:[edi].LO,@OPCOD_CLI ; Izit a CLI?
	je	short INT0D_PMCLI ; Jump if so

	cmp	es:[edi].LO,@OPCOD_STI ; Izit a STI?
	jne	near ptr INT0D_PMUNK ; Jump if not

	or	[ebp].INTXX_EFL.ELO,mask $IF ; IF=1

	jmp	short @F	; Join common code


INT0D_PMCLI:
	test	I31_FLAG,mask $I31_CLI ; Should we skip this?
	jnz	short @F	; Jump if so

	and	[ebp].INTXX_EFL.ELO,not (mask $IF) ; IF=0
@@:
	inc	[ebp].INTXX_EIP ; Skip over the CLI/STI
INT0D_PMRET:
	pop	es		; Restore
	assume	es:nothing	; Tell the assembler about it

; The stack is mapped by INTXX_STR
; Note that INTXX_INTNO is already filled in with the
; INT # times 4 + offset PGROUP:INTPROC00Z

	popad			; Restore all EGP registers
				; N.B.:  Do not follow with [EAX+???*?]
; The stack is mapped by INTDPF_STR

	add	esp,type INTXX_ERR ; Strip pseudo-error code

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Return to caller (PM only)


	assume	ds:DGROUP	; Tell the assembler about it
INT0D_MOV_R32_CRn:

; Save the value of CRn into r32

	call	PROC_MOV_R32_CRn ; Process it
	jc	near ptr INT06	; Handle as Invalid Opcode

	jmp	INT0D_PMRET	; Join common PM return code


	assume	ds:DGROUP	; Tell the assembler about it
INT0D_MOV_CRn_R32:

; Save the value of r32 into CRn

	call	PROC_MOV_CRn_R32 ; Process it
	jc	near ptr INT06	; Handle as Invalid Opcode

	jmp	INT0D_PMRET	; Join common PM return code


	assume	ds:DGROUP	; Tell the assembler about it
INT0D_PMGRP7:
INT0D_VMGRP7:
	mov	al,es:[edi+2]	; Get Mod R/M byte
	and	al,mask $REG	; Isolate the REG bits

; Check for LMSW reg which we'll emulate

	cmp	al,110b shl $REG ; Check for LMSW
	jne	near ptr INT0D_PMUNK ; It's not found

; It's LMSW -- save the value into the low-order word of CR0

	call	PROC_LMSW	; Process it

	jmp	INT0D_PMRET	; Join common PM return code


	assume	ds:DGROUP	; Tell the assembler about it
INT0D_PMIO_IMM1:
	movzx	edx,es:[edi+1].LO ; Get the immediate I/O port
	mov	ecx,2		; Get instruction length

	jmp	short INT0D_PMIO_COM ; Join common code


INT0D_PMIO_IMM2:
	movzx	edx,es:[edi+2].LO ; Get the immediate I/O port
	mov	ecx,3		; Get instruction length

	jmp	short INT0D_PMIO_COM ; Join common code


INT0D_PMIO_DX1:
	movzx	edx,[ebp].INTXX_EDX.ELO ; Get the I/O port
	mov	ecx,1		; Get instruction length

	jmp	short INT0D_PMIO_COM ; Join common code


INT0D_PMIO_DX2:
	movzx	edx,[ebp].INTXX_EDX.ELO ; Get the I/O port
	mov	ecx,2		; Get instruction length
INT0D_PMIO_COM:
	mov	eax,LaIOBIT	; Get offset in AGROUP of I/O permission bitmap

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

	bt	AGROUP:[eax].EDD,edx ; Izit trapped?
	jc	short @F	; Jump if so

	SWATMAC ERR		; Call our debugger
@@:
	pop	es		; Restore
	assume	es:nothing	; Tell the assembler about it

	mov	DPMI_IO_PORT,dx ; Save to use later

	add	[ebp].INTXX_EIP,ecx ; Skip over the instruction

; The stack is mapped by INTXX_STR
; Note that INTXX_INTNO is already filled in with the
; INT # times 4 + offset PGROUP:INTPROC00Z

	popad			; Restore all EGP registers
				; N.B.:  Do not follow with [EAX+???*?]
; The stack is mapped by INTDPF_STR

	add	esp,type INTXX_ERR ; Strip the error code

; The stack is mapped by INTDPI_STR

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

; Because EMM386 can't handle a GP Fault from PM (it thinks it tripped
; over its own shoelaces), we need to relfect this I/O instruction to
; VM so it can be re-issued.

	jmp	INT0D_IOREF	; Reflect the GP Fault to VM


	assume	ds:DGROUP	; Tell the assembler about it
INT0D_PMINT:
INT0D_VMINT:
	add	[ebp].INTXX_EIP,2 ; Skip over the INT xx

	movzx	eax,es:[edi].HI ; Get the interrupt #

	cmp	al,01h		; Izit INT 01h?
	je	near ptr INT0D_VMINT01 ; Jump if so

	cmp	al,03h		; Izit INT 03h?
	je	near ptr INT0D_VMINT03 ; Jump if so

	cmp	al,2Fh		; Izit INT 2Fh?
	je	near ptr INT0D_VMINT2F ; Jump if so

	cmp	al,31h		; Izit INT 31h?
	je	near ptr INT0D_VMINT31 ; Jump if so

; The following "hardware" interrupt return can occur outside
; an active DPMI client.

%	cmp	al,0&@PMH_INT&h ; Izit INT @PMH_INT?
%	je	near ptr INT0D_VMINT&@PMH_INT ; Jump if so

; If there's a DPMI client active, we're providing translation
; services for INTs 10h, 15h, 21h, 33h, and 4Bh as well as special
; treatment for INTs 1Ch, 23h, 24h, 41h, @PMI_INT, @PMF_INT, and @PMM_INT.

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	je	short INT0D_XDPMI ; Jump if not

	cmp	al,10h		; Izit INT 10h?
	je	near ptr INT0D_VMINT10 ; Jump if so

	cmp	al,15h		; Izit INT 15h?
	je	near ptr INT0D_VMINT15 ; Jump if so

	cmp	al,1Ch		; Izit INT 1Ch?
	je	near ptr INT0D_VMINT1C ; Jump if so

	cmp	al,21h		; Izit INT 21h?
	je	near ptr INT0D_VMINT21 ; Jump if so

	cmp	al,23h		; Izit INT 23h?
	je	near ptr INT0D_VMINT23 ; Jump if so

	cmp	al,24h		; Izit INT 24h?
	je	near ptr INT0D_VMINT24 ; Jump if so

	cmp	al,33h		; Izit INT 33h?
	je	near ptr INT0D_VMINT33 ; Jump if so

	cmp	al,41h		; Izit INT 41h?
	je	near ptr INT0D_VMINT41 ; Jump if so

	cmp	al,4Bh		; Izit INT 4Bh?
	je	near ptr INT0D_VMINT4B ; Jump if so

%	cmp	al,0&@PMI_INT&h ; Izit INT @PMI_INT?
%	je	near ptr INT0D_VMINT&@PMI_INT ; Jump if so

%	cmp	al,0&@PMF_INT&h ; Izit INT @PMF_INT?
%	je	near ptr INT0D_VMINT&@PMF_INT ; Jump if so

%	cmp	al,0&@PMM_INT&h ; Izit INT @PMM_INT?
%	je	near ptr INT0D_VMINT&@PMM_INT ; Jump if so
INT0D_XDPMI:
	pop	es		; Restore
	assume	es:nothing	; Tell the assembler about it

; The stack is mapped by INTXX_STR
; Note that INTXX_INTNO is NOT already filled in with the
; INT # times 4 + offset PGROUP:INTPROC00Z

	shl	eax,2-0 	; Convert to width of INTPROC table
	add	eax,offset PGROUP:INTPROC00Z ; Plus ending address
	mov	[ebp].INTXX_INTNO,ax ; Mark as appropriate interrupt

	popad			; Restore all EGP registers
				; N.B.:  Do not follow with [EAX+???*?]
; The stack is mapped by INTDPF_STR

	pop	INT_ERRCODE	; Strip pseudo-error code

; The stack is mapped by INTDPI_STR

	test	INT_ERRCODE,mask $FEXT ; Izit an external event?
	jnz	short INT0D_INTEXT ; Jump if so

; If this SW interrupt occurred in VM, let the MM handle it
; If it occurred in PM, the MM might not know what to do with
; it (OK, EMM386 barfs), so we need to pass it through a
; service translator.

	test	[esp].INTDPI_EFL.EHI,mask $VM ; Izit from VM?
	jz	short INT0D_INTxx_DPMI ; Jump if not

	sub	[esp].INTDPI_EIP,2 ; Back up to INT xx instruction

; Jump to OLDINT0D_FVEC

	push	INT_ERRCODE	; Pass the error code

	push	SAVE_DS0D0E.ELO ; Pass caller's DS

	push	OLDINT0D_FVEC.FSEL ; Pass the selector
	push	OLDINT0D_FVEC.FOFF ; ...  the offset

DPLINT0D_STR struc

	df	?		; Return CS:EIP
DPLINT0D_DS dw	?		; Caller's DS

DPLINT0D_STR ends

	mov	ds,[esp].DPLINT0D_DS ; Restore
	assume	ds:nothing	; Tell the assembler about it

	retf			; Continue as GP Fault

	assume	ds:nothing	; Tell the assembler about it


	assume	ds:DGROUP	; Tell the assembler about it
INT0D_INTxx_DPMI:
	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	INTxx_DPMI	; Join common DPMI code

	assume	ds:nothing	; Tell the assembler about it


; The stack is mapped by INTDPI_STR
; Jump to INTPROCxx where the interrupt # is in EAX

	assume	ds:DGROUP	; Tell the assembler about it
INT0D_INTEXT:
	SWATMAC ERR		; *FIXME* Can this ever be called?

	push	eax		; Save for a moment and make room for RET target

	movzx	eax,[esp+4].INTDPI_INTNO ; Get offset of INTPROC call table
	xchg	eax,[esp]	; Swap with original EAX

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	retn			; Jump to appropriate routine (INTPROCxx)


EXIT_INT macro	NN

	extrn	INT&NN:near

	assume	ds:DGROUP	; Tell the assembler about it
INT0D_VMINT&NN:
	pop	es		; Restore
	assume	es:nothing	; Tell the assembler about it

; The stack is mapped by INTXX_STR
; Note that INTXX_INTNO is already filled in with the
; INT # times 4 + offset PGROUP:INTPROC00Z

	popad			; Restore all EGP registers
				; N.B.:  Do not follow with [EAX+???*?]
; The stack is mapped by INTDPF_STR

	pop	INT_ERRCODE	; Strip pseudo-error code

; The stack is mapped by INTDPI_STR

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	INT&NN		; Continue with our local handler

	endm			; EXIT_INT

	EXIT_INT 01
	EXIT_INT 03
	EXIT_INT 10
	EXIT_INT 15
	EXIT_INT 1C
	EXIT_INT 21
	EXIT_INT 23
	EXIT_INT 24
	EXIT_INT 2F
	EXIT_INT 31
	EXIT_INT 33
	EXIT_INT 41
	EXIT_INT 4B
%	EXIT_INT @PMI_INT
%	EXIT_INT @PMF_INT
%	EXIT_INT @PMM_INT
%	EXIT_INT @PMH_INT


; Fault from VM -- see if we can emulate it.
; The stack is mapped by INTXX_STR (SS:EBP).

	assume	ds:DGROUP	; Tell the assembler about it
INT0D_VM86A:
	mov	es,SEL_4GB	; Get AGROUP data selector
;;;;;;; assume	es:AGROUP	; Tell the assembler about it
	assume	es:nothing	; Tell the assembler about it

	movzx	edi,[ebp].INTXX_CS ; Get caller's segment
	shl	edi,4-0 	; Convert from paras to bytes
	add	edi,[ebp].INTXX_EIP ; Plus caller's EIP

; Check for GRP7 (LMSW)

	cmp	es:[edi].ELO,@OPCOD_GRP7 ; Izit GRP7?
	je	near ptr INT0D_VMGRP7 ; Jump if so

; Check for INT xx which EMM386 from MS-DOS has at DPL=0

	cmp	es:[edi].LO,@OPCOD_INT ; Izit INT?
	je	near ptr INT0D_VMINT ; Jump if so

; Enter here for fault from DPMI client which we could not emulate.
; The stack is mapped by INTXX_STR (SS:EBP).

INT0D_PMUNK:
	pop	es		; Restore
	assume	es:nothing	; Tell the assembler about it

; The stack is mapped by INTXX_STR
; Note that INTXX_INTNO is already filled in with the
; INT # times 4 + offset PGROUP:INTPROC00Z

; If this fault came from a DPMI client, give 'em a crack at it.
; If it came from VM, pass it on to a DPMI client
; hooking this fault or to the MM.

	test	[esp].INTXX_EFL.EHI,mask $VM ; Izit from V86 mode?
	jnz	short @F	; Jump if so

; If there's a DPMI client active, give it a crack at this exception

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	jne	near ptr INT0D_DPMI_VISIBLE ; Jump if so
@@:
	mov	esi,4*0Dh	; Interrupt # times 4
	lea	ebx,MSG_NF	; Offset of message to display to user

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	INTXXCOM	; Join common code

	assume	ds:nothing,es:nothing,ss:nothing ; Tell the assembler about it

INT0D	endp			; End INT0D procedure
	NPPROC	PROC_LMSW -- Process LMSW Instruction
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Process LMSW instruction

On entry:

ES:EDI	==>	LMSW two-byte opcode
SS:EBP	==>	INTXX_STR

On exit:

ES:EDI	==>	(updated)

|

	REGSAVE <eax,esi>	; Save register

	mov	al,es:[edi+2]	; Get Mod R/M byte
	mov	ah,al		; Copy for destructive test
	and	ah,mask $MOD	; Isolate the MOD bits

	cmp	ah,11b shl $MOD ; Check for register source
	jne	short PROC_LMSW_SKIP ; Jump if not

	and	eax,mask $RM	; Isolate the RM bits
	shr	eax,$RM 	; Shift to low-order
	sub	eax,111b	; Subtract from largest value to invert
	neg	eax		; Negate to complete the inversion
	mov	ax,[ebp+eax*4].INTXX_EDI.ELO ; Get the incoming value
	or	ax,mask $PE	; Ensure we're still in PM
	lmsw	ax		; Tell the CPU about it

; If we're coming from VM, transfer the $EM bit into the MSW
; for VM operation.  Otherwise, transfer it into the DPMI MSW.

	mov	ebx,PVMTSS	; Get offset in PGROUP of the 1st TSS

	test	[ebp].INTXX_EFL.EHI,mask $VM ; Izit from VM?
	jnz	short @F	; Jump if so

	mov	ebx,PCURTSS	; Get offset in PGROUP of the current TSS
@@:
	and	ax,mask $EM	; Isolate $EM bit
	and	DGROUP:[ebx].DPTSS_MSW,not (mask $EM) ; Clear old $EM bit
	or	DGROUP:[ebx].DPTSS_MSW,ax ; Save new value for $EM bit

	push	ebx		; Pass offset in PGROUP of TSS
	call	DPMIFN_LMSW	; Put MSW and INT 07h values into effect
PROC_LMSW_SKIP:

; Determine the instruction length and skip over it

	xor	dl,dl		; Initialize flags, assuming USE16

	test	[ebp].INTXX_EFL.EHI,mask $VM ; Izit from VM?
	jnz	short @F	; Jump if so (must be USE16)

	push	es		; Pass the selector
	call	GETARW		; Return with AX = A/R word

	test	ah,mask $DTE_B	; Izit USE32?
	jz	short @F	; Jump if not

	mov	dl,$USE32	; Mark as USE32
@@:
	mov	esi,edi 	; ES:ESI ==> instruction (starting with prefixes)
	call	GETILEN 	; Return with EAX = length of instruction
				;  with ES:ESI ==> instruction, DL = 0 or $USE32
	add	[ebp].INTXX_EIP,eax ; Skip to the next instruction

	REGREST <esi,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PROC_LMSW endp			; End PROC_LMSW procedure
	NPPROC	PROC_MOV_R32_CRn -- Process MOV r32,CRn Instruction
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Process MOV r32,CRn instruction

On entry:

ES:EDI	==>	MOV r32,CRn instruction (0F 20 mod r/m)
SS:EBP	==>	INTXX_STR

On exit:

CF	=	0 if successful
	=	1 if not
ES:EDI	==>	(updated)

|

	REGSAVE <eax,esi>	; Save register

	mov	al,es:[edi+2]	; Get Mod R/M byte
	mov	ah,al		; Copy for destructive test
	and	ah,mask $MOD	; Isolate the MOD bits

	cmp	ah,11b shl $MOD ; Check for register source
;;;;;;; jne	short PROC_MOV_R32_CRn_ERR ; Jump if not
	jb	short PROC_MOV_R32_CRn_ERR ; Jump if not (note CF=1)

	mov	ebx,eax 	; Copy Mod R/M byte
	and	ebx,mask $REG	; Isolate the REG bits (CRn value)
	shr	ebx,$REG	; Shift to low-order

	clc			; CF=0 in case invalid register
	call	ReadCRnTab[ebx * (type ReadCRnTab)] ; Read CRn value into EBX
	jc	short PROC_MOV_R32_CRn_ERR ; Jump if error (note CF=1)

	and	eax,mask $RM	; Isolate the RM bits (r32 value)
	shr	eax,$RM 	; Shift to low-order
	sub	eax,111b	; Subtract from largest value to invert
	neg	eax		; Negate to complete the inversion
	mov	[ebp+eax*4].INTXX_EDI,ebx ; Save the resulting value

; Determine the instruction length and skip over it

	xor	dl,dl		; Initialize flags, assuming USE16

	test	[ebp].INTXX_EFL.EHI,mask $VM ; Izit from VM?
	jnz	short @F	; Jump if so (must be USE16)

	push	es		; Pass the selector
	call	GETARW		; Return with AX = A/R word

	test	ah,mask $DTE_B	; Izit USE32?
	jz	short @F	; Jump if not

	mov	dl,$USE32	; Mark as USE32
@@:
	mov	esi,edi 	; ES:ESI ==> instruction (starting with prefixes)
	call	GETILEN 	; Return with EAX = length of instruction
				;  with ES:ESI ==> instruction, DL = 0 or $USE32
	add	[ebp].INTXX_EIP,eax ; Skip to the next instruction

	clc			; Mark as successful
PROC_MOV_R32_CRn_ERR:
	REGREST <esi,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PROC_MOV_R32_CRn endp		; End PROC_MOV_R32_CRn procedure
	NPPROC	ReadCRn -- Read CRn Instruction
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Read CRn instruction

On exit:

EBX	=	value

|

ReadCR0:
	mov	ebx,cr0 	; Get value

	ret			; Return to caller

ReadCR1:
	MOVSPR	ebx,cr1 	; Get value

	ret			; Return to caller

ReadCR2:
	mov	ebx,cr2 	; Get value

	ret			; Return to caller

ReadCR3:
	mov	ebx,cr3 	; Get value

	ret			; Return to caller

ReadCR4:
	MOVSPR	ebx,cr4 	; Get value

	ret			; Return to caller

ReadCR5:
	MOVSPR	ebx,cr5 	; Get value

	ret			; Return to caller

ReadCR6:
	MOVSPR	ebx,cr6 	; Get value

	ret			; Return to caller

ReadCR7:
	MOVSPR	ebx,cr7 	; Get value

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

ReadCRn endp			; End ReadCRn procedure
	NPPROC	PROC_MOV_CRn_R32 -- Process MOV CRn,r32 Instruction
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Process MOV CRn,r32 instruction

On entry:

ES:EDI	==>	MOV CRn,r32 instruction (0F 22 mod r/m)
SS:EBP	==>	INTXX_STR

On exit:

CF	=	0 if successful
	=	1 if not
ES:EDI	==>	(updated)

|

	REGSAVE <eax,esi>	; Save register

	mov	al,es:[edi+2]	; Get Mod R/M byte
	mov	ah,al		; Copy for destructive test
	and	ah,mask $MOD	; Isolate the MOD bits

	cmp	ah,11b shl $MOD ; Check for register source
;;;;;;; jne	short PROC_MOV_CRn_R32_ERR ; Jump if not
	jb	short PROC_MOV_CRn_R32_ERR ; Jump if not (note CF=1)

	mov	ebx,eax 	; Copy Mod R/M byte
	and	ebx,mask $REG	; Isolate the REG bits (CRn value)
	shr	ebx,$REG	; Shift to low-order

	and	eax,mask $RM	; Isolate the RM bits (r32 value)
	shr	eax,$RM 	; Shift to low-order
	sub	eax,111b	; Subtract from largest value to invert
	neg	eax		; Negate to complete the inversion
	mov	eax,[ebp+eax*4].INTXX_EDI ; Get the incoming value

	clc			; CF=0 in case invalid register
	call	WriteCRnTab[ebx * (type WriteCRnTab)] ; Write EAX into CRn
	jc	short PROC_MOV_CRn_R32_ERR ; Jump if error (note CF=1)

; Determine the instruction length and skip over it

	xor	dl,dl		; Initialize flags, assuming USE16

	test	[ebp].INTXX_EFL.EHI,mask $VM ; Izit from VM?
	jnz	short @F	; Jump if so (must be USE16)

	push	es		; Pass the selector
	call	GETARW		; Return with AX = A/R word

	test	ah,mask $DTE_B	; Izit USE32?
	jz	short @F	; Jump if not

	mov	dl,$USE32	; Mark as USE32
@@:
	mov	esi,edi 	; ES:ESI ==> instruction (starting with prefixes)
	call	GETILEN 	; Return with EAX = length of instruction
				;  with ES:ESI ==> instruction, DL = 0 or $USE32
	add	[ebp].INTXX_EIP,eax ; Skip to the next instruction

	clc			; Mark as successful
PROC_MOV_CRn_R32_ERR:
	REGREST <esi,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PROC_MOV_CRn_R32 endp		; End PROC_MOV_CRn_R32 procedure
	NPPROC	WriteCRn -- Write CRn Instruction
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Write CRn instruction

On entry:

EAX	=	value

|

WriteCR0:
	or	eax,(mask $PG) or (mask $PE) ; Ensure PE=PG=1
	mov	cr0,eax 	; Set value

	ret			; Return to caller

WriteCR1:
	MOVSPR	cr1,eax 	; Set value

	ret			; Return to caller

WriteCR2:
	mov	cr2,eax 	; Set value

	ret			; Return to caller

WriteCR3:
	mov	cr3,eax 	; Set value

	ret			; Return to caller

WriteCR4:
	MOVSPR	cr4,eax 	; Set value

	ret			; Return to caller

WriteCR5:
	MOVSPR	cr5,eax 	; Set value

	ret			; Return to caller

WriteCR6:
	MOVSPR	cr6,eax 	; Set value

	ret			; Return to caller

WriteCR7:
	MOVSPR	cr7,eax 	; Set value

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

WriteCRn endp			; End WriteCRn procedure

PROG	ends			; End PROG segment

	MEND			; End DPMI_I0D module
