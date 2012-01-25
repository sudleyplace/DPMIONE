;' $Header$
	title	DPMI_DIF -- DPMI.LOD DPMI Interrupt Fault Handler
	page	58,122
	name	DPMI_DIF
COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1991-2004 Qualitas, Inc.  All Rights Reserved.

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include PTR.INC
	include DPMI.INC
;;;;;;; include BITFLAGS.INC
	include CPUFLAGS.INC
	include MASM5.MAC
	include ALLMEM.INC
	include INTVEC.INC
	include DOSERR.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_EXP.INC
	include DPMI_PRG.INC
	include DPMI_SEG.INC
	include DPMI_SWT.INC
	include DPMI_W9X.INC

	include QMAX_I31.INC		; Must precede QMAXDPMI.INC
	include QMAXDPMI.INC		; Must follow QMAX_I31.INC
	include QMAX_EMM.INC
	include QMAX_TSS.INC
	include QMAX_VMM.INC
.list

@BIT1	 equ	 02h		; Because ML6.11a can't handle BITFLAGS.INC


CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
	assume	cs:PGROUP,ds:PGROUP

	extrn	INTPROC00Z:near

	extrn	ERM_FVEC:fword

CODE16A ends			; End CODE16A segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

;;;;;;; extrn	INT01_COMMON:near
%	extrn	INTPROC&@PMI_INT:near
%	extrn	INTPROC&@PMF_INT:near
%	extrn	INTPROC&@PMM_INT:near
	extrn	SET_PPL0STK:near
;;;;;;; extrn	INTCOM_DPMI_CHKRET:near
	extrn	INTCOM_DPMI_INTMAX:near
	extrn	DPMI_VPFRET:near

PROG	ends			; End PROG segment


DATA16	segment use16 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	extrn	DPM_FLAG:word
	extrn	VMM_FLAG:word

DATA16	ends			; End DATA16 segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_DIF_DATA
@DPMI_DIF_DATA	label byte	; Mark module start in .MAP file

	include DPMI_LCL.INC
	extrn	LCL_FLAG:word

	extrn	SEL_4GB:word
	extrn	LAST_INTCOM:dword
	extrn	LAST_INTFLG:dword
	extrn	PVMTSS:dword
	extrn	PCURTSS:dword
	extrn	PPRMTSS:dword
	extrn	I31_FLAG:word
	extrn	EXITRC:word
	extrn	DPMI_IDEF:word
	extrn	DPMI_HW:byte
	extrn	OLDCR2:dword
	extrn	LPMSTK_SEL:word

	extrn	PPL0STK_MAX:dword
;;;;;;; extrn	PLCL_PL0CUR:dword

	public	SAVE_EBP,SAVE_EAX,SAVE_EBX,SAVE_DS,SAVE_ES
	public	SAVE_ECX,SAVE_ESI,SAVE_EDI
SAVE_EBP dd	?		; Save area for EBP
SAVE_EAX dd	?		; ...		EAX
SAVE_EBX dd	?		; ...		EBX
SAVE_ECX dd	?		; ...		ECX
SAVE_ESI dd	?		; ...		ESI
SAVE_EDI dd	?		; ...		EDI
SAVE_DS dd	?		; ...		DS (w/filler for alignment)
SAVE_ES dd	?		; ...		ES ...

; The following pointer is to what the DPMI spec calls the
; locked protected mode stack (at PL3)

	public	LPMSTK_CNT,LPMSTK_SIZ,LPMSTK_FVEC
LPMSTK_CNT dd	0		; Count of outstanding LPM usages (0=none)
LPMSTK_SIZ dd	@LPMSTK_DEF	; Size of the default LPM stack
LPMSTK_FVEC df	-1		; Ptr to top of locked protected mode stack
	dw	?		; For alignment and so we can POPD into the FSEL

	public	DPMIMSG
DPMIMSG dd	?		; Save area for DPMI fault message

	public	LAST_DPMI_DS,LAST_DPMI_ES,LAST_DPMI_FS,LAST_DPMI_GS
LAST_DPMI_DS dw ?		; Last valid DS selector
LAST_DPMI_ES dw ?		; ...	     ES ...
LAST_DPMI_FS dw ?		; ...	     FS ...
LAST_DPMI_GS dw ?		; ...	     GS ...

	public	NEXT_DPMI_DS,NEXT_DPMI_ES,NEXT_DPMI_FS,NEXT_DPMI_GS
NEXT_DPMI_DS dw ?		; Next DS selector to use
NEXT_DPMI_ES dw ?		; ...  ES ...
NEXT_DPMI_FS dw ?		; ...  FS ...
NEXT_DPMI_GS dw ?		; ...  GS ...

FLT_REC record	$FLT_I01:1

@FLT_I01 equ	(mask $FLT_I01) ; Single-step the next instruction in caller

	public	FLT_FLAG
FLT_FLAG dw	0		; Fault flags

	public	INT23_TYP
INT23_TYP db	?		; INT 23h return code:
				; @INT23_IGNORE if we're to ignore the event
				;		(the client exited via IRET/D)
				; @INT23_ABORT	if we're to abort
				;		(the client exited via RETF/D
				;		 with CF=1)

	public	INT24_TYP
INT24_TYP db	?		; INT 24h return code:
				; @INT24_IGNORE if we're to ignore the event
				; @INT24_RETRY	if we're to retry the operation
				; @INT24_ABORT	if we're to abort
				; @INT24_FAIL	if we're to fail the operation
				; @INT24_REFLVM if we're to reflect the call to VM

	irp	XX,<00,01,02,03,04,05,06,07,08,09,0A,0B,0C,0D,0E,0F,10,11,12,13,14,15,16,17,18,19,1A,1B,1C,1D,1E,1F>
	extrn	DPMIMSG&XX&:tbyte
	endm			; IRP

	extrn	DPMIMSG_APPLFULL:tbyte
	extrn	DPMIMSG_LPMFULL:tbyte
	extrn	DPMIMSG_VMFULL:tbyte

DATA	ends			; End DATA segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	extrn	DPMITYPEIG:byte
	extrn	PMINT_FVECS:fword
	extrn	PMINT_DVECS:dword
	extrn	PMFLT_FVECS:fword
	extrn	PMFLT_DVECS:dword
	extrn	VMFLT_FVECS:fword
	extrn	VMFLT_DVECS:dword

DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_DIF_PROG
@DPMI_DIF_PROG: 		; Mark module start in .MAP file

	extrn	GETBASE:near
	extrn	SETBASE:near
	extrn	SETLENGTH:near
	extrn	RESETVARS:near
	extrn	ALLOCMEM:near
	extrn	DEALLOCMEM:near
	extrn	VMM_LOCK:near

	extrn	DPMI_RSPRET:near

	extrn	INT10_INTRETPM:near
	extrn	INT15_INTRETPM:near
	extrn	INT20_INTRETPM:near
	extrn	INT21_INTRETPM:near
	extrn	INT23_INTRETPM:near
	extrn	INT24_INTRETPM:near
	extrn	INT25_INTRETPM:near
	extrn	INT26_INTRETPM:near
	extrn	INT27_INTRETPM:near
	extrn	INT2F_INTRETPM:near
	extrn	INT31_INTRETPM:near
	extrn	INT33_INTRETPM:near
	extrn	INT4B_INTRETPM:near
	extrn	INTxx_INTRETPM:near

	extrn	DPMIFN_TERMINATE:near
	extrn	DPMIFN_LMSW:near
	extrn	DPMIFN_LPMSTK:near
	extrn	DPMIFN_ESPMOD:near
	extrn	DPMIFN_NESTOUT:near
	extrn	DPMIFN_NESTRET:near

	extrn	DPMI_RMSPM2VM:near
	extrn	DPMI_VMCRET:near
	extrn	DPMI_MEIRET:near

PMIJMP_MAC macro N

INTJMP&N:
;;;;;;; jmp	DPMI_REFINT
	jmp	INTxx_INTRETPM

	endm			; PMIJMP_MAC

; Define jump table for default interrupts

	public	PMINT_JMP
PMINT_JMP label near

CNT	=	0
.sall
	rept	256

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	PMIJMP_MAC %N
CNT	=	CNT + 1
	endm			; REPT 256
.lall
L1:

; Replace existing entries into this table if and only if there is
; additional work we do when this interrupt occurs in PM.

	org	INTJMP10	; Special routine for INT 10h
	jmp	INT10_INTRETPM

	org	INTJMP15	; Special routine for INT 15h
	jmp	INT15_INTRETPM

	org	INTJMP20	; Special routine for INT 20h
	jmp	INT20_INTRETPM

	org	INTJMP21	; Special routine for INT 21h
	jmp	INT21_INTRETPM

	org	INTJMP23	; Special routine for INT 23h
	jmp	INT23_INTRETPM

	org	INTJMP24	; Special routine for INT 24h
	jmp	INT24_INTRETPM

	org	INTJMP25	; Special routine for INT 25h
	jmp	INT25_INTRETPM

	org	INTJMP26	; Special routine for INT 26h
	jmp	INT26_INTRETPM

	org	INTJMP27	; Special routine for INT 27h
	jmp	INT27_INTRETPM

	org	INTJMP2F	; Special routine for INT 2Fh
	jmp	INT2F_INTRETPM

	org	INTJMP31	; Special routine for INT 31h
	jmp	INT31_INTRETPM

	org	INTJMP33	; Special routine for INT 33h
	jmp	INT33_INTRETPM

	org	INTJMP4B	; Special routine for INT 4Bh
	jmp	INT4B_INTRETPM

	org	L1		; We now return your set to normal programming


PMFJMP_MAC macro N

FLTJMP&N:
	jmp	FLTPROC&N

	endm			; PMFJMP_MAC


; Define jump table for default faults

	public	PMFLT_JMP
PMFLT_JMP label near

CNT	=	0
.sall
	rept	32

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	PMFJMP_MAC %N
CNT	=	CNT + 1
	endm			; REPT 32
.lall

	NPPROC	PMIDEF -- PM Interrupt Return Default Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI PM interrupt return default handler

This code is all at PL3 so it can be accessible to DPMI clients.

|

; The starting address in this routine is mapped by DTE_DPMIDEF:0

PMINT_MAC macro N

	public	PMIDEF&N
PMIDEF&N equ	$-PMIDEF	; Get offset in DTE_DPMIDEF
%	int	0&&@PMI_INT&&h	; Interrupt for PM Interrupts

	endm			; PMINT_MAC

PMFLT_MAC macro N

	public	PMFDEF&N
PMFDEF&N equ	$-PMIDEF	; Get offset in DTE_DPMIDEF
%	int	0&&@PMF_INT&&h	; Interrupt for PM Faults

	endm			; PMFLT_MAC

VMFLT_MAC macro N

	public	VMFDEF&N
VMFDEF&N equ	$-PMIDEF	; Get offset in DTE_DPMIDEF
%	int	0&&@PMF_INT&&h	; Interrupt for VM Faults (same as for PM faults)

	endm			; PMFLT_MAC

CNT	=	0
.sall
	rept	256

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	PMINT_MAC %N
CNT	=	CNT + 1
	endm			; REPT 256
.lall


CNT	=	0
.sall
	rept	32

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	PMFLT_MAC %N
CNT	=	CNT + 1
	endm			; REPT 32
.lall


CNT	=	0
.sall
	rept	32

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	VMFLT_MAC %N
CNT	=	CNT + 1
	endm			; REPT 32
.lall

	public	PMIDEF_SSR16
PMIDEF_SSR16 equ $-PMIDEF	; Offset in DTE_DPMIDEF
	RETFS			; Return to 16-bit code


	public	PMIDEF_SSR32
PMIDEF_SSR32 equ $-PMIDEF	; Offset in DTE_DPMIDEF
	RETFD			; Return to 32-bit code


	public	PMIRMS
PMIRMS	equ	$-PMIDEF	; Offset in DTE_DPMIDEF
%	int	0&@PMM_INT&h	; Interrupt for PM Miscellaneous Returns


	public	PMILPM
PMILPM	equ	$-PMIDEF	; Offset in DTE_DPMIDEF
%	int	0&@PMI_INT&h	; Interrupt for PM Interrupts


	public	PMFLPM
PMFLPM	equ	$-PMIDEF	; Offset in DTE_DPMIDEF
%	int	0&@PMF_INT&h	; Interrupt for PM Faults


	public	PMFLPM2 	; This address is used by 1.0 fault handlers
				; that pop off the old (0.9) frame and return
				; on the big 1.0 frame.
PMFLPM2 equ	$-PMIDEF	; Offset in DTE_DPMIDEF
%	int	0&@PMF_INT&h	; Interrupt for PM Faults


	public	PMVMCB
PMVMCB	equ	$-PMIDEF	; Offset in DTE_DPMIDEF
%	int	0&@PMM_INT&h	; Interrupt for PM Miscellaneous Returns


	public	PMMEI
PMMEI	equ	$-PMIDEF	; Offset in DTE_DPMIDEF
%	int	0&@PMM_INT&h	; Interrupt for PM Miscellaneous Returns


	public	PMVSAPI16_MSDOS
PMVSAPI16_MSDOS equ $-PMIDEF	; Offset in DTE_DPMIDEF
	sub	sp,@VSAPI_DDSTKSIZE*4 ; Make room for args to avoid confusion
				;   in case there's a Fault
	PUSHD	@VSAPI_MSDOS	; Pass flag for MS-DOS caller
	pushfd			; Save flags as dword (restored by VSAPI)
	cli			; Disallow interrupts in case we're on the LPM
				; stack so we don't have to save LPMSTK_FVEC
	FICALL	0,?		; Call gate to MAX code in DPMIFN_VSAPI
	public	PMVSAPI16_MSDOS1
	org	$-2
PMVSAPI16_MSDOS1 dw 0ABCDh	; Offset in PGROUP of fixup

	RETFS			; Return to 16-bit code


%	public	PMVSAPI16_&@VSAPINAME
% PMVSAPI16_&@VSAPINAME& equ $-PMIDEF ; Offset in DTE_DPMIDEF
	sub	sp,@VSAPI_DDSTKSIZE*4 ; Make room for args to avoid confusion
				;   in case there's a Fault
	PUSHD	@VSAPI_HOST	; Pass flag for @VSAPINAME caller
	pushfd			; Save flags as dword (restored by VSAPI)
	cli			; Disallow interrupts in case we're on the LPM
				; stack so we don't have to save LPMSTK_FVEC
	FICALL	0,?		; Call gate to MAX code in DPMIFN_VSAPI
%	public	PMVSAPI16_&@VSAPINAME&1
	org	$-2
% PMVSAPI16_&@VSAPINAME&1 dw 0ABCDh ; Offset in PGROUP of fixup

	RETFS			; Return to 16-bit code


	public	PMVSAPI32_MSDOS
PMVSAPI32_MSDOS equ $-PMIDEF	; Offset in DTE_DPMIDEF
	sub	esp,@VSAPI_DDSTKSIZE*4 ; Make room for args to avoid confusion
				;   in case there's a Fault
	PUSHD	@VSAPI_MSDOS	; Pass flag for MS-DOS caller
	pushfd			; Save flags as dword (restored by VSAPI)
	cli			; Disallow interrupts in case we're on the LPM
				; stack so we don't have to save LPMSTK_FVEC
	FICALL	0,?		; Call gate to MAX code in DPMIFN_VSAPI
	public	PMVSAPI32_MSDOS1
	org	$-2
PMVSAPI32_MSDOS1 dw 0ABCDh	; Offset in PGROUP of fixup

	RETFD			; Return to 32-bit code


%	public	PMVSAPI32_&@VSAPINAME
% PMVSAPI32_&@VSAPINAME equ $-PMIDEF ; Offset in DTE_DPMIDEF
	sub	esp,@VSAPI_DDSTKSIZE*4 ; Make room for args to avoid confusion
				;   in case there's a Fault
	PUSHD	@VSAPI_HOST	; Pass flag for @VSAPINAME caller
	pushfd			; Save flags as dword (restored by VSAPI)
	cli			; Disallow interrupts in case we're on the LPM
				; stack so we don't have to save LPMSTK_FVEC
	FICALL	0,?		; Call gate to MAX code in DPMIFN_VSAPI
%	public	PMVSAPI32_&@VSAPINAME&1
	org	$-2
% PMVSAPI32_&@VSAPINAME&1 dw 0ABCDh ; Offset in PGROUP of fixup

	RETFD			; Return to 32-bit code

if @W9X
	public	PMVWIN32_16
PMVWIN32_16 equ $-PMIDEF	; Offset in DTE_DPMIDEF
	sub	sp,@VSAPI_DDSTKSIZE*4 ; Make room for args to avoid confusion
				;   in case there's a Fault
	pushfd			; Save flags as dword (restored by VSAPI)
	cli			; Disallow interrupts in case we're on the LPM
				; stack so we don't have to save LPMSTK_FVEC
	FICALL	0,?		; Call gate to MAX code in DPMIFN_VSAPI
%	public	PMVWIN32_16A
	org	$-2
% PMVWIN32_16A dw 0ABCDh	; Offset in PGROUP of fixup
	lea	sp,[esp+@VSAPI_DDSTKSIZE*4 + 4] ; Strip from stack

	RETFS			; Return to 16-bit code


	public	PMVWIN32_16B,PMVWIN32_16C
PMVWIN32_16B equ $-PMIDEF	; Offset in DTE_DPMIDEF
	lea	sp,[esp+@VSAPI_DDSTKSIZE*4 + 4] ; Strip from stack
PMVWIN32_16C equ $-PMIDEF	; Offset in DTE_DPMIDEF
	RETFS	1		; Return to 16-bit code, popping arguments


%	public	PMVWIN32_32
% PMVWIN32_32 equ $-PMIDEF	; Offset in DTE_DPMIDEF
	sub	esp,@VSAPI_DDSTKSIZE*4 ; Make room for args to avoid confusion
				;   in case there's a Fault
	pushfd			; Save flags as dword (restored by VSAPI)
	cli			; Disallow interrupts in case we're on the LPM
				; stack so we don't have to save LPMSTK_FVEC
	FICALL	0,?		; Call gate to MAX code in DPMIFN_VSAPI
%	public	PMVWIN32_32A
	org	$-2
% PMVWIN32_32A dw 0ABCDh	; Offset in PGROUP of fixup
	lea	esp,[esp+@VSAPI_DDSTKSIZE*4 + 4] ; Strip from stack

	RETFD			; Return to 32-bit code


	public	PMVWIN32_32B,PMVWIN32_32C
PMVWIN32_32B equ $-PMIDEF	; Offset in DTE_DPMIDEF
	lea	sp,[esp+@VSAPI_DDSTKSIZE*4 + 4] ; Strip from stack
PMVWIN32_32C equ $-PMIDEF	; Offset in DTE_DPMIDEF
	RETFD	1		; Return to 32-bit code
endif

	public	PMVPF
PMVPF	equ	$-PMIDEF	; Offset in DTE_DPMIDEF
%	int	0&@PMM_INT&h	; Interrupt for PM Miscellaneous Returns


	public	PMRSP
PMRSP	equ	$-PMIDEF	; Offset in DTE_DPMIDEF
%	int	0&@PMM_INT&h	; Interrupt for PM Miscellaneous Returns


	public	PMIDEF_LEN
PMIDEF_LEN equ	$-PMIDEF	; Length of default interrupt handlers at PL3

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PMIDEF	endp			; End PMIDEF procedure
%	FPPROC	INT&@PMM_INT -- Interrupt Handler For PM Miscellaneous Returns
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Interrupt handler for PM miscellaneous returns

If it's from VM, or if the return CS is not DPMI_IDEF,
continue on with INTPROCxx.
Otherwise, process this as a miscellaneous interrupt return from a
DPMI client.

On entry:

SS:ESP	==>	INTDPI_STR

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].INTDPI_EFL.EHI,mask $VM ; Izit from VM?
%	jnz	near ptr INTPROC&@PMM_INT ; Jump if so

	xchg	ax,[esp].INTDPI_CS ; Get the caller's CS

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	ax,DPMI_IDEF	; Izit in our court?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	xchg	ax,[esp].INTDPI_CS ; Restore
%	jne	near ptr INTPROC&@PMM_INT ; Jump if not

	cmp	[esp].INTDPI_EIP,PMIRMS+@PMxDEF_LEN ; Izit RMS PM to VM?
	je	near ptr DPMI_RMSPM2VM ; Jump if so

	cmp	[esp].INTDPI_EIP,PMVMCB+@PMxDEF_LEN ; Izit VMCB return?
	je	near ptr DPMI_VMCRET ; Jump if so

	cmp	[esp].INTDPI_EIP,PMMEI+@PMxDEF_LEN ; Izit MEI return?
	je	near ptr DPMI_MEIRET ; Jump if so

	cmp	[esp].INTDPI_EIP,PMVPF+@PMxDEF_LEN ; Izit VPF return?
	je	near ptr DPMI_VPFRET ; Jump if so

	cmp	[esp].INTDPI_EIP,PMRSP+@PMxDEF_LEN ; Izit RSP return?
	je	near ptr DPMI_RSPRET ; Jump if so

	SWATMAC ERR,PM		; Call our debugger

%	jmp	INTPROC&@PMM_INT ; Huh??

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

% INT&@PMM_INT endp		; End INT&@PMM_INT procedure
%	FPPROC	INT&@PMF_INT -- Interrupt Handler For PM (and VM) Fault Return
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Interrupt handler for PM (and VM) fault return

If it's from VM, or if the return CS is not DPMI_IDEF,
continue on with INTPROCxx.
Otherwise, process this as an interrupt return from a
DPMI client.

On entry:

SS:ESP	==>	INTDPI_STR

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].INTDPI_EFL.EHI,mask $VM ; Izit from VM?
%	jnz	near ptr INTPROC&@PMF_INT ; Jump if so

	xchg	ax,[esp].INTDPI_CS ; Get the caller's CS

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	ax,DPMI_IDEF	; Izit in our court?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	xchg	ax,[esp].INTDPI_CS ; Restore
%	jne	near ptr INTPROC&@PMF_INT ; Jump if not

	jmp	short DPMI_FLTRET ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

% INT&@PMF_INT endp		; End INT&@PMF_INT procedure
	FPPROC	DPMI_FLTRET -- DPMI Fault Return Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT!

The PL0 stack is mapped by DPMI_FLTRET_STR.

We're returning from a DPMI PM fault routine via the DPMI client's
IRET/D or JMPF/CALLF.  We can tell the difference by looking at
DPMI_FLTRET_EIP which is PMFLPM+@PMxDEF_LEN (for IRET/D) or
PMFDEFxx+@PMxDEF_LEN (for JMPF/CALLF).

The MAX stack on entry contains (from bottom up) DPMI_FLTRET_STR
followed by the INTDPF_STR from the original fault.

If this is JMPF/CALLF, the interrupt # (xx in PMFDEFxx) is calculated
from DPMI_FLTRET_EIP on the MAX stack.	That value is replaced by the
return address from the DPMI stack.  The interrupt # (after a suitable
change in units) should match the value in [esp+(size
DPMI_FLTRET_STR)].INTDPF_INTNO.  We should take our default action
which is to reflect the exception as a PM interrupt (similar to
HW-DPMI) for 00h-05h, and 07h, and to terminate the DPMI client for
all others.

If this is IRET/D, then the client (presumably) handled the fault
itself and we should copy the DPMI stack values from DPMI_FLT32A_STR
or DPMI_FLT16A_STR to INTDPF_STR, de-allocate our portion of the LPM
stack, restore the previous TSS_ESP0 and TSS_SS0 to the TSS, strip off
DPMI_FLTRET_STR, strip off INTDPF_ERR, and IRETD to the return address
on the stack at that point.

On entry:

IF	=	0

!

DPMI_FLT16A_STR struc

DPMI_FLT16A_RIP dw ?		; Our return IP
DPMI_FLT16A_RCS dw ?		; ...	     CS
DPMI_FLT16A_ERR dw ?		; This INT's return error code
DPMI_FLT16A_IP	dw ?		; ...		    IP
DPMI_FLT16A_CS	dw ?		; ...		    CS
DPMI_FLT16A_FL	dw ?		; ...		    FL
DPMI_FLT16A_SP	dw ?		; ...		    SP
DPMI_FLT16A_SS	dw ?		; ...		    SS

DPMI_FLT16A_STR ends


DPMI_FLT32A_STR struc

DPMI_FLT32A_REIP dd ?		; Our return EIP
DPMI_FLT32A_RCS dd ?		; ...	     CS w/filler (note it's a DD)
DPMI_FLT32A_ERR dd ?		; This INT's return error code
DPMI_FLT32A_EIP dd ?		; ...		    EIP
DPMI_FLT32A_CS	dw ?,?		; ...		    CS w/filler
DPMI_FLT32A_EFL dd ?		; ...		    EFL
DPMI_FLT32A_ESP dd ?		; ...		    ESP
DPMI_FLT32A_SS	dw ?,?		; ...		    SS w/filler

DPMI_FLT32A_STR ends


DPMI_FLT10_STR struc		; Exception stack frame struc for DPMI 1.0

DPMI_FLT10_OLDFRAME db (size DPMI_FLT32A_STR) dup (?) ; The maximum size old frame
DPMI_FLT10_RET dq ?		; Our return address (CS|IP or CS|EIP)
DPMI_FLT10_ERR dd ?		; The fault's error code
DPMI_FLT10_EIP dd ?		; ...	      EIP
DPMI_FLT10_CS  dw ?		; ...	      CS w/filler
DPMI_FLT10_INFO dw ?		; ...	      info bits
DPMI_FLT10_EFL dd ?		; ...	      EFL
DPMI_FLT10_ESP dd ?		; ...	      ESP
DPMI_FLT10_SS  dw ?,?		; ...	      SS w/filler
DPMI_FLT10_ES  dw ?,?		; ...	      ES w/filler
DPMI_FLT10_DS  dw ?,?		; ...	      DS w/filler
DPMI_FLT10_FS  dw ?,?		; ...	      FS w/filler
DPMI_FLT10_GS  dw ?,?		; ...	      GS w/filler
DPMI_FLT10_CR2 dd ?		; ...	faulting linear address (fault 0Eh)
DPMI_FLT10_PTE dd ?		; ...	virtual PTE contents for addr in CR2

DPMI_FLT10_STR ends


DPMI_FLTRET_STR struc

DPMI_FLTRET_EIP   dd ?		; Offset in DTE_DPMIDEF
DPMI_FLTRET_CS	  dw ?		; Selector  DTE_DPMIDEF+(@DPMI_CPL shl $PL)
DPMI_FLTRET_FDEF  dw ?		; Before DPMI_FLTRET, undefined
				; After DPMI_FLTRET, INT #
DPMI_FLTRET_EFL   dd ?		; EFL from PL3 via call gate parm copy
DPMI_FLTRET_ESP   dd ?		; ESP
DPMI_FLTRET_SS	  dw ?,?	; SSF

; The portion of this structure below this point *MUST* match
; the corresponding portion of DPMI_FLT_STR.

DPMI_FLTRET_LPMSTK df ? 	; Original LPMSTK_FVEC
		  dw ?		; For alignment
DPMI_FLTRET_GS	  dd ?		; Original GS
DPMI_FLTRET_FS	  dd ?		; ...	   FS
DPMI_FLTRET_ES	  dd ?		; ...	   ES
DPMI_FLTRET_DS	  dd ?		; ...	   DS
;;;DPMI_FLTRET_PL0LEN dd ?	   ; Length of protected stack
DPMI_FLTRET_ESP0  dd ?		; Old TSS_ESP0 to be restored
DPMI_FLTRET_SS0   dw ?		; ... TSS_SS0 ...
DPMI_FLTRET_PCURTSS dd ?	; ... PCURTSS
DPMI_FLTRET_FLG   dd ?		; @PMINTCOM_LPM

DPMI_FLTRET_STR ends

DPMI_FLTRET_REST equ <DPMI_FLTRET_LPMSTK> ; Restore stack above this point

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	pop	SAVE_DS 	; Save to restore later

	mov	SAVE_EAX,eax	; Save for a moment
	mov	SAVE_EBX,ebx	; ...
	mov	SAVE_ECX,ecx	; ...
	mov	SAVE_ESI,esi	; ...
	mov	SAVE_EDI,edi	; ...
	mov	SAVE_EBP,ebp	; ...
	mov	SAVE_ES,es	; ...

	mov	ebp,esp 	; SS:EBP ==> DPMI_FLTRET_STR

; If the B-bit in the stack selector is clear, zero the upper
; word of the stack offset so we can use it as a dword.

	lea	ebx,[ebp].DPMI_FLTRET_ESP ; SS:EBX ==> SS|ESP from PL3
	push	ebx		; Pass the offset
	call	DPMIFN_ESPMOD	; Clear the high-order word of the PL3 ESP
				; if the B-bit in the PL3 SS is clear
;;; ; Move the current PL0 stack down to where it would be
;;; ; had the CPU used the TSS_ESP0 we calculated.
;;;
;;;	    mov     edi,PPL0STK_MAX ; Get maximum stack offset
;;;	    mov     esi,PLCL_PL0CUR ; Get offset in DGROUP of current local stack
;;;	    sub     edi,DGROUP:[esi] ; Less length of saved stack
;;;	    mov     ecx,type INTDPI_STR ; Get length of PL0 stack to move down
;;;	    sub     edi,ecx	    ; Less length of move
;;;	    mov     esi,esp	    ; Get source offset
;;;	    mov     esp,edi	    ; Back off to that offset
;;;	    mov     ebp,esp	    ; ...
;;;
;;;	    lea     eax,[ecx+esi]   ; Add to get ending source address
;;;
;;;	    cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	    jbe     short @F	    ; Jump if not
;;;
;;;	    SWATMAC ERR 	    ; Call our debugger
;;; @@:
;;;	    lea     eax,[ecx+edi]   ; Add to get ending destin address
;;;
;;;	    cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	    jbe     short @F	    ; Jump if not
;;;
;;;	    SWATMAC ERR 	    ; Call our debugger
;;; @@:
;;;	    mov     ax,ss	    ; Copy stack selector
;;;	    mov     es,ax	    ; Address it
;;;	    assume  es:nothing	    ; Tell the assembler about it
;;;
;;;	    cld 		    ; String ops fowardly
;;; S32 rep movs    <es:[edi].LO,ss:[esi].LO> ; Copy the stack down
;;;
;;; ; Restore the original PL0 stack from PLCL_PL0CUR
;;;
;;;	    mov     esi,PLCL_PL0CUR ; Get offset in DGROUP of current local stack
;;;	    mov     ecx,DGROUP:[esi] ; Get length of saved stack
;;;	    jecxz   DPMI_FLTRET_DMS ; Jump if we're at the deadman's switch
;;;
;;;	    add     esi,4	    ; Skip over length of saved stack
;;;
;;;	    lea     eax,[ecx+edi]   ; Add to get ending destin address
;;;
;;;	    cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	    jbe     short @F	    ; Jump if not
;;;
;;;	    SWATMAC ERR 	    ; Call our debugger
;;; @@:
;;; ;;;;;;; cld 		    ; String ops fowardly
;;; S32 rep movs    <es:[edi].LO,DGROUP:[esi].LO> ; Copy the stack down
;;; DPMI_FLTRET_DMS:
	les	ebx,[ebp].DPMI_FLTRET_ESP.EDF ; ES:EBX ==> DPMI stack
	assume	es:nothing	; Tell the assembler about it

; See if we got here through PMFDEFxx or PMFLPM or PMFLPM2

	cmp	[ebp].DPMI_FLTRET_EIP,PMFLPM2+@PMxDEF_LEN ; Izit PMFLPM2?
	je	near ptr DPMI_FLTRET_10RET ; Jump if so

	cmp	[ebp].DPMI_FLTRET_EIP,PMFLPM+@PMxDEF_LEN ; Izit PMFLPM?
	jne	near ptr DPMI_FLTRET_XLPM ; Jump if not (the client chained to us)

;;;;;;; mov	PLCL_PL0CUR,esi ; Strip from storage

; The DPMI client exited with RETF/D on the LPM stack

; Copy the client's DS, ES, FS, GS to DPMI_FLTRET_xS as return registers

	mov	eax,SAVE_DS	; Get original value
	mov	[ebp].DPMI_FLTRET_DS,eax ; Copy 'em
	mov	eax,SAVE_ES	; Get original value
	mov	[ebp].DPMI_FLTRET_ES,eax ; ...
	mov	[ebp].DPMI_FLTRET_FS,fs ; ...
	mov	[ebp].DPMI_FLTRET_GS,gs ; ...

; Copy the DPMI stack values from DPMI_FLT32A_STR or DPMI_FLT16A_STR
; to INTDPF_STR

; Note that if this is a 16-bit client, the high-order word of EBX
; need not be valid

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	short DPMI_FLTRET16 ; Jump if so

; The caller's stack doesn't have the REIP and RCS dwords on it
; If we back off by that amount, we can use DPMI_FLT32A_STR

	sub	ebx,(size DPMI_FLT32A_REIP) + (size DPMI_FLT32A_RCS)
;;;;;;; jc	short ???	; Ignore error

; Clear RF in the return flags if the return address from the
; DPMI stack is different from the address in the MAX stack.
; Note that because we entered here from a fault, RF is set
; in the MAX stack.  It is the responsibility of the DPMI fault
; handler to manage the return TF.

	mov	eax,es:[ebx].DPMI_FLT32A_EIP ; Get EIP

	cmp	eax,[ebp+(size DPMI_FLTRET_STR)].INTDPF_EIP ; Izit the same?
	je	short @F	; Jump if so

	mov	[ebp+(size DPMI_FLTRET_STR)].INTDPF_EIP,eax
	call	DPMIFLT_CHGRET	; Handle fault return address changes
@@:
	mov	ax,es:[ebx].DPMI_FLT32A_CS ; Get CS

	cmp	ax,[ebp+(size DPMI_FLTRET_STR)].INTDPF_CS ; Izit the same?
	je	short @F	; Jump if so

	mov	[ebp+(size DPMI_FLTRET_STR)].INTDPF_CS,ax
	call	DPMIFLT_CHGRET	; Handle fault return address changes
@@:

; The flags in DPMI_FLT32A_EFL from the return are to be returned to
; the caller, except for VM and IOPL which should remain the
; same as the caller's.  The TF flag is copied from the return flags
; as that's the only way a debugger can turn off single-stepping.

FLMASK	=	((mask $VMHI) or (mask $IOPL))

	mov	eax,es:[ebx].DPMI_FLT32A_EFL ; Get EFL
	and	eax,not FLMASK	; VM=IOPL=0
	and	[ebp+(size DPMI_FLTRET_STR)].INTDPF_EFL,FLMASK ; Isolate
	or	[ebp+(size DPMI_FLTRET_STR)].INTDPF_EFL,eax ; Incldue

	mov	eax,es:[ebx].DPMI_FLT32A_ESP ; Get ESP
	mov	[ebp+(size DPMI_FLTRET_STR)].INTDPF_ESP,eax

	mov	ax,es:[ebx].DPMI_FLT32A_SS ; Get SS
	mov	[ebp+(size DPMI_FLTRET_STR)].INTDPF_SS,ax

	jmp	DPMI_FLTRET_COM ; Join common code


DPMI_FLTRET16:

; The caller's stack doesn't have the RIP and RCS words on it
; If we back off by that amount, we can use DPMI_FLT16A_STR

	sub	ebx,(size DPMI_FLT16A_RIP) + (size DPMI_FLT16A_RCS)
;;;;;;; jc	short ???	; Ignore error

; Clear RF in the return flags if the return address from the
; DPMI stack is different from the address in the MAX stack.
; Note that because we entered here from a fault, RF is set
; in the MAX stack.  It is the responsibility of the DPMI fault
; handler to manage the return TF.

	mov	ax,es:[ebx].DPMI_FLT16A_IP ; Get IP

	cmp	ax,[ebp+(size DPMI_FLTRET_STR)].INTDPF_EIP.ELO ; Izit the same?
	je	short @F	; Jump if so

	mov	[ebp+(size DPMI_FLTRET_STR)].INTDPF_EIP.ELO,ax
	call	DPMIFLT_CHGRET	; Handle fault return address changes
@@:
	mov	ax,es:[ebx].DPMI_FLT16A_CS ; Get CS

	cmp	ax,[ebp+(size DPMI_FLTRET_STR)].INTDPF_CS ; Izit the same?
	je	short @F	; Jump if so

	mov	[ebp+(size DPMI_FLTRET_STR)].INTDPF_CS,ax
	call	DPMIFLT_CHGRET	; Handle fault return address changes
@@:

; The flags in DPMI_FLT16A_EFL from the return are to be returned to
; the caller, except for IOPL which should remain the same as
; the caller's.  The TF flag is copied from the return flags
; as that's the only way a debugger can turn off single-stepping.

FLMASK	=	(mask $IOPL)

	mov	ax,es:[ebx].DPMI_FLT16A_FL ; Get FL
	and	ax,not FLMASK ; IOPL=0
	and	[ebp+(size DPMI_FLTRET_STR)].INTDPF_EFL.ELO,FLMASK ; Isolate
	or	[ebp+(size DPMI_FLTRET_STR)].INTDPF_EFL.ELO,ax ; Include

	mov	ax,es:[ebx].DPMI_FLT16A_SP ; Get SP
	mov	[ebp+(size DPMI_FLTRET_STR)].INTDPF_ESP.ELO,ax

	mov	ax,es:[ebx].DPMI_FLT16A_SS ; Get SS
	mov	[ebp+(size DPMI_FLTRET_STR)].INTDPF_SS,ax

	jmp	DPMI_FLTRET_COM ; Join common code


; Handle return on 1.0 frame

DPMI_FLTRET_10RET:
;;;;;;; mov	PLCL_PL0CUR,esi ; Strip from storage

; Copy the DPMI stack values from DPMI_FLT10_STR to INTDPF_STR

; The client's stack doesn't have the RET and OLDFRAME fields on it.
; If we back off by that amount, we can use DPMI_FLT10_STR

	sub	ebx,(size DPMI_FLT10_OLDFRAME) + (size DPMI_FLT10_RET)

; If this is a 16-bit client, the CPU didn't clear off all of
; DPMI_FLT10_RET, in the RETF; thus the SUB above backed off too far.

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	jne	short @F	; Jump if not

	add	ebx,(size DPMI_FLT10_RET)/2 ; Back to normal
@@:

; Clear RF in the return flags if the return address from the
; DPMI stack is different from the address in the MAX stack.
; Note that because we entered here from a fault, RF is set
; in the MAX stack.  It is the responsibility of the DPMI fault
; handler to manage the return TF.

	mov	eax,es:[ebx].DPMI_FLT10_EIP ; Get EIP

	cmp	eax,[ebp+(size DPMI_FLTRET_STR)].INTDPF_EIP ; Izit the same?
	je	short @F	; Jump if so

	mov	[ebp+(size DPMI_FLTRET_STR)].INTDPF_EIP,eax
	call	DPMIFLT_CHGRET	; Handle fault return address changes
@@:
	mov	ax,es:[ebx].DPMI_FLT10_CS ; Get CS

	cmp	ax,[ebp+(size DPMI_FLTRET_STR)].INTDPF_CS ; Izit the same?
	je	short @F	; Jump if so

	mov	[ebp+(size DPMI_FLTRET_STR)].INTDPF_CS,ax
	call	DPMIFLT_CHGRET	; Handle fault return address changes
@@:

; The flags in DPMI_FLT10_EFL from the return are to be returned to
; the caller, except for VM and IOPL which should remain the
; same as the caller's.

FLMASK	=	((mask $VMHI) or (mask $IOPL))

	mov	eax,es:[ebx].DPMI_FLT10_EFL	; Get EFL
	and	eax,not FLMASK	; VM=IOPL=0
	and	[ebp+(size DPMI_FLTRET_STR)].INTDPF_EFL,FLMASK ; Isolate
	or	[ebp+(size DPMI_FLTRET_STR)].INTDPF_EFL,eax ; Include

	mov	eax,es:[ebx].DPMI_FLT10_ESP ; Get ESP
	mov	[ebp+(size DPMI_FLTRET_STR)].INTDPF_ESP,eax

	mov	ax,es:[ebx].DPMI_FLT10_SS ; Get SS
	mov	[ebp+(size DPMI_FLTRET_STR)].INTDPF_SS,ax

; Return the caller's DS, ES, FS, SS.
; If this is a VM client, the segment registers go into
; (size DPMI_FLTRET_STR)+INTCOM_xS[4] (because there's a pseudo-error code)
; Otherwise, the selectors are in DPMI_FLTRET_xS.

	test	[ebp+(size DPMI_FLTRET_STR)].INTDPF_EFL.EHI,mask $VM ; Izit from VM?
	jz	short DPMI_FLTRET_10RET_PM ; Jump if not

	mov	ax,es:[ebx].DPMI_FLT10_DS ; Get DS
	mov	[ebp+(size DPMI_FLTRET_STR)].INTCOM_DS[4],ax ; ...

	mov	ax,es:[ebx].DPMI_FLT10_ES ; Get ES
	mov	[ebp+(size DPMI_FLTRET_STR)].INTCOM_ES[4],ax ; ...

	mov	ax,es:[ebx].DPMI_FLT10_FS ; Get FS
	mov	[ebp+(size DPMI_FLTRET_STR)].INTCOM_FS[4],ax ; ...

	mov	ax,es:[ebx].DPMI_FLT10_GS ; Get GS
	mov	[ebp+(size DPMI_FLTRET_STR)].INTCOM_GS[4],ax ; ...

	jmp	short DPMI_FLTRET_COM ; Join common code


DPMI_FLTRET_10RET_PM:
	mov	eax,es:[ebx].DPMI_FLT10_DS.EDD ; Get DS
	mov	[ebp].DPMI_FLTRET_DS,eax ; ...

	mov	eax,es:[ebx].DPMI_FLT10_ES.EDD ; Get ES
	mov	[ebp].DPMI_FLTRET_ES,eax ; ...

	mov	eax,es:[ebx].DPMI_FLT10_FS.EDD ; Get FS
	mov	[ebp].DPMI_FLTRET_FS,eax ; ...

	mov	eax,es:[ebx].DPMI_FLT10_GS.EDD ; Get GS
	mov	[ebp].DPMI_FLTRET_GS,eax ; ...
DPMI_FLTRET_COM:
	add	esp,DPMI_FLTRET_REST ; Strip from the stack to
				; previous restore point

; De-allocate our portion of the LPM stack

	pop	LPMSTK_FVEC.FOFF ; De-allocate it
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

; Because some DPMI clients (pssst, it's Windows 3.10 á 2) may
; invalidate the selectors we carefully pushed onto the stack
; when we handled an interrupt so we can restore them now, we must
; VERR them and zero the invalid ones.

	VERREST <gs,fs,es,ds>	; Restore selectors with VERR
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

;;;;;;; add	esp,type DPMI_FLTRET_PL0LEN ; Strip
;;;;;;;
; Restore the previous TSS_ESP0 and TSS_SS0 to the TSS

; Between the time we change the MAX stack pointer in the TSS
; and we recalculate PL0STK pointers, we can't allow any interruption

;;;;;;; cli			; Disallow interrupts (already disabled)

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	pop	SAVE_DS 	; Save to restore later

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	pop	DGROUP:[eax].TSS_ESP0 ; Restore
	pop	DGROUP:[eax].TSS_SS0  ; ...

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

; If we switched out a TSS, switch it back in

	pop	eax		; Restore incoming PCURTSS

	xchg	eax,PCURTSS	; Get original TSS, save incoming one
	call	DPMIFN_NESTRET	; Check for nesting return with EAX=old PCURTSS
	assume	es:nothing,fs:nothing,gs:nothing ; Tell the assembler about it

	pop	eax		; Restore DPMI_FLTRET_FLG

	cmp	eax,@PMINTCOM_LPM ; Did we use the LPM stack?
	jne	short @F	; Jump if not

	dec	LPMSTK_CNT	; Count it out
@@:

; Restore saved registers

	mov	eax,SAVE_EAX	; Restore
	mov	ebx,SAVE_EBX	; ...
	mov	ecx,SAVE_ECX	; ...
	mov	esi,SAVE_ESI	; ...
	mov	edi,SAVE_EDI	; ...
	mov	ebp,SAVE_EBP	; ...
;;;;;;; mov	es,SAVE_ES	; ... (already restored from DPMI_FLTRET_ES)
;;;;;;; assume	es:nothing	; Tell the assembler about it
	mov	ds,SAVE_DS	; Restore
	assume	ds:nothing	; Tell the assembler about it

; Strip off INTDPF_ERR

	add	esp,size INTDPF_ERR ; Strip it

; Ensure NT=0 so the following IRETD doesn't cause a task switch

	pushf			; Get our flags
	and	[esp].ELO,not (mask $NT) ; NT=0
	popf			; Restore

	test	[esp].IRETD_EFL.EHI,mask $VM ; Izit VM?
	jnz	short DPMI_FLTRET_ERM1 ; Jump if so

; Should we single-step the next instruction in the caller?

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	btr	FLT_FLAG,$FLT_I01 ; Should we single-step next instr?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jnc	short @F	; Jump if not

	push	mask $TF	; Get TF
	popfd			; TF=1

; Note we *MUST* not insert any instructions between the
; last POPF and the following IRETD or they might get traced

@@:
	iretd			; Return to caller (??? only)


DPMI_FLTRET_ERM1:
	jmp	ERM_FVEC	; Return to RM/VCPI


; We got here through JMPF/CALLF
; Note IF=0 and various registers have been saved
;;;; ESI = end of stack restored from PLCL_PL0CUR

	public	DPMI_FLTRET_XLPM
	assume	ds:DGROUP	; Tell the assembler about it
DPMI_FLTRET_XLPM:

; Calculate the interrupt # whose default handler we should invoke
; The interrupt # (xx in PMFDEFxx) is calculated from DPMI_FLTRET_EIP
; on the MAX stack.

; Copy the return address on the DPMI stack to the MAX stack
; and strip it from the DPMI stack

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	short DPMI_FLTRET_XLPM16 ; Jump if so
DPMI_FLTRET_FLPM2:
	mov	ax,es:[ebx].DPMI_FLT32A_RCS.ELO ; Get return CS
	mov	[ebp].DPMI_FLTRET_CS,ax ; Save on MAX stack

	mov	eax,es:[ebx].DPMI_FLT32A_REIP ; Get return EIP
	xchg	eax,[ebp].DPMI_FLTRET_EIP ; Get EIP, swap with return address

	add	ebx,2*4 	; Strip EIP and CSF from the DPMI stack

	jmp	short DPMI_FLTRET_XLPMCOM ; Join common code


DPMI_FLTRET_XLPM16:

; If the return IP on the caller's stack is PMFLPM2, the rest of
; the caller's stack is mapped by DPMI_FLT10_STR (without the old
; frame) which (for our purposes) is the same as DPMI_FLT32A_STR.

	cmp	es:[ebx].DPMI_FLT16A_RIP,PMFLPM2 ; Izit PMFLPM2?
	je	short DPMI_FLTRET_FLPM2 ; Jump if so

	mov	ax,es:[ebx].DPMI_FLT16A_RCS ; Get return CS (assume 16-bit)
	mov	[ebp].DPMI_FLTRET_CS,ax ; Save on MAX stack

	movzx	eax,es:[ebx].DPMI_FLT16A_RIP ; Get return IP
	xchg	eax,[ebp].DPMI_FLTRET_EIP ; Get IP, swap with return address

	add	ebx,2*2 	; Strip the return IP and CS from the DPMI stack
DPMI_FLTRET_XLPMCOM:
	mov	[ebp].DPMI_FLTRET_ESP,ebx ; Strip the DPMI stack

; Note EAX = return EIP

; Set new LPM stack top for nested callers if it's active
; and we're called from PM, not PL0

	cmp	LPMSTK_CNT,0	; Is the LPM stack active?
	je	short DPMI_FLTRET_LPMINACT ; Jump if not

; The following tests are unnecessary as the caller has already
; been qualified as having used the LPM stack.	That is, it's
; a DPMI client at PL3 or a VM exception.
;;;;;;;
;;;;;;; test	[ebp].DPMI_FLTRET_EFL.EHI,mask $VM ; Izit from VM?
;;;;;;; jnz	short DPMI_FLTRET_LPMINACT ; Jump if so
;;;;;;;
;;;;;;; test	[ebp].DPMI_FLTRET_CS,mask $PL ; Izit from PL0?
;;;;;;; jz	short DPMI_FLTRET_LPMINACT ; Jump if so
;;;;;;;
	mov	LPMSTK_FVEC.FOFF,ebx ; Save caller's offset
	mov	LPMSTK_FVEC.FSEL,es ; ...	      selector
DPMI_FLTRET_LPMINACT:

; Calculate the interrupt # and save in DPMI_FLTRET_FDEF
; This value is later used in FLTPROC_STRIP to distinguish
; whether or not we came from the DPMI client's fault handler.

; Note that by construction, the incoming EIP is small so that
; the high-order word of EAX is always zero.

	push	edx		 ; Save for a moment

	mov	edx,@PMxDEF_LEN+PMFDEF00 ; Assume not from VM

	test	[ebp+(size DPMI_FLTRET_STR)].INTDPF_EFL.EHI,mask $VM ; Izit from VM?
	jz	short @F	; Jump if not

	mov	edx,@PMxDEF_LEN+VMFDEF00 ; Assume so
@@:
	sub	eax,edx 	; Convert to origin-0
	xor	edx,edx 	; Zero to use in dividend
	mov	ebx,@PMxDEF_LEN ; Get divisor
	div	ebx		; Divide to get AX = interrupt #

	pop	edx		; Restore

	mov	[ebp].DPMI_FLTRET_FDEF,ax ; Mark as coming from DPMI_FLTRET

	imul	eax,@xxTJMP_LEN ; Multiply INT # to get offset in PMFLT_JMP
	add	eax,offset PGROUP:PMFLT_JMP ; Plus offset of JMP base
	xchg	eax,SAVE_EAX	; Swap with original EAX

	PUSHD	0		; Put pseudo-error code onto stack

	push	SAVE_EAX	; Pass return address

	mov	ebx,SAVE_EBX	; Restore
	mov	ecx,SAVE_ECX	; ...
	mov	esi,SAVE_ESI	; ...
	mov	edi,SAVE_EDI	; ...
	mov	ebp,SAVE_EBP	; ...

	mov	es,SAVE_ES	; ...
	assume	es:nothing	; Tell the assembler about it

	mov	ds,SAVE_DS	; ...
	assume	ds:nothing	; Tell the assembler about it

	retn			; Take appropriate action

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_FLTRET endp		; End DPMI_FLTRET procedure
	NPPROC	DPMIFLT_CHGRET -- DPMI Fault Return Address Changed
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

The return address from a DPMI fault handler has changed.

* Clear RF in the return flags so we don't miss the next instruction.

* If TF is set in the return flags, set $FLT_I01 in FLT_FLAG so we
  single-step into the next handler.

On entry:

SS:EBP	==>	DPMI_FLTRET_STR

|

	and	[ebp+(size DPMI_FLTRET_STR)].INTDPF_EFL,not (mask $RFHI) ; RF=0

	test	[ebp+(size DPMI_FLTRET_STR)].INTDPF_EFL,mask $TF ; Is TF set?
	jz	short @F	; Jump if not

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	or	FLT_FLAG,mask $FLT_I01 ; Set so we single-step next instr

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
@@:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFLT_CHGRET endp		; End DPMIFLT_CHGRET procedure
%	FPPROC	INT&@PMI_INT -- Interrupt Handler For PM Interrupt Return
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Interrupt handler for PM interrupt return

If it's from VM, or if the return CS is not DPMI_IDEF,
continue on with INTPROCxx.
Otherwise, process this as an interrupt return from a
DPMI client.

On entry:

SS:ESP	==>	INTDPI_STR

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].INTDPI_EFL.EHI,mask $VM ; Izit from VM?
%	jnz	near ptr INTPROC&@PMI_INT ; Jump if so

	xchg	ax,[esp].INTDPI_CS ; Get the caller's CS

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	ax,DPMI_IDEF	; Izit in our court?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	xchg	ax,[esp].INTDPI_CS ; Restore
%	jne	near ptr INTPROC&@PMI_INT ; Jump if not

	jmp	short DPMI_INTRET ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

% INT&@PMI_INT endp		; End INT&@PMI_INT procedure
	FPPROC	DPMI_INTRET -- DPMI Interrupt Return Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT!

The PL0 stack is mapped by DPMI_INTRET_STR.

We're returning from a DPMI PM interrupt routine either via the DPMI
client IRET/D or JMPF/CALLF.  We can tell the difference by looking at
DPMI_INTRET_EIP which is PMILPM+@PMxDEF_LEN (for IRET/D) or
PMIDEFxx+@PMxDEF_LEN (for JMPF/CALLF).

If in PMINTCOM we used the LPM stack (HW-VM, SP-VM, HW-DPMI, HW-MAX),
the MAX stack on entry contains (from bottom up) DPMI_INTRET_STR, and
one of INTCOM_STR (HW-VM, SP-VM), INTDPI_STR (HW-DPMI), or NRM_STR
(HW-MAX) each from the original interrupt.

If in PMINTCOM we used the application stack (SP-DPMI, SW-DPMI), an
IRET/D by the DPMI client returns to the point following the
interruption in the application.  If we return to here, then the DPMI
client exited with a JMPF/CALLF in which case the MAX stack on entry
contains (from bottom up) INTDPI_STR (in other words, it contains
DPMI_INTRET_STR up to and including DPMI_INTRET_SS).  Thus the
JMPF/CALLF and subsequent actions must be careful not to reference
anything above INTDPI_STR.

If this is JMPF/CALLF, the interrupt # (xx in PMIDEFxx) is calculated
from DPMI_INTRET_EIP on the MAX stack.	That value is replaced by the
return address from the DPMI stack.  The interrupt # (after a suitable
change in units) should match the value in [esp+(size
DPMI_INTRET_STR)].NRM_INTNO.  We should take our default action.

Note that when INTs 23h and 24h come through here, they use the LPM
stack.	It is required that the DPMI client return to us via RETF/D or
IRET/D, although a return via JMPF/CALLF is converted into a request
to reflect the interrupt to VM.

On entry:

IF	=	0

!

DPMI_INTRET_STR struc

DPMI_INTRET_EIP   dd ?		; Offset in DTE_DPMIDEF
DPMI_INTRET_CS	  dw ?		; Selector  DTE_DPMIDEF+(@DPMI_CPL shl $PL)
DPMI_INTRET_IDEF  dw ?		; Before DPMI_INTRET, undefined
				; After DPMI_INTRET, 4 * INT # + offset ...
DPMI_INTRET_EFL   dd ?		; EFL from PL3 via call gate parm copy
DPMI_INTRET_ESP   dd ?		; ESP
DPMI_INTRET_SS	  dw ?,?	; SSF

; The portion of this structure below this point *MUST* match
; the corresponding portion of DPMI_INT_STR.

DPMI_INTRET_LPMSTK df ? 	; Original LPMSTK_FVEC
		  dw ?		; For alignment
DPMI_INTRET_GS	  dd ?		; Original GS
DPMI_INTRET_FS	  dd ?		; ...	   FS
DPMI_INTRET_ES	  dd ?		; ...	   ES
DPMI_INTRET_DS	  dd ?		; ...	   DS
DPMI_INTRET_LIFLG dd ?		; Old LAST_INTFLG to be restored
DPMI_INTRET_LICOM dd ?		; ... LAST_INTCOM ...
;;;DPMI_INTRET_PL0LEN dd ?	   ; Length of protected stack
DPMI_INTRET_ESP0  dd ?		; Old TSS_ESP0 ...
DPMI_INTRET_SS0   dw ?		; ... TSS_SS0 ...
DPMI_INTRET_PCURTSS dd ?	; ... PCURTSS ...
DPMI_INTRET_FLG   dd ?		; @PMINTCOM_LPM or ..._NRM stack usage flag

DPMI_INTRET_STR ends

DPMI_INTRET_REST equ	<DPMI_INTRET_LPMSTK> ; Restore stack above this point

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	pop	SAVE_DS 	; Save to restore later

	mov	SAVE_EAX,eax	; Save for a moment
	mov	SAVE_EBX,ebx	; ...
	mov	SAVE_ECX,ecx	; ...
	mov	SAVE_ESI,esi	; ...
	mov	SAVE_EDI,edi	; ...
	mov	SAVE_EBP,ebp	; ...
	mov	SAVE_ES,es	; ...

	mov	ebp,esp 	; SS:EBP ==> DPMI_INTRET_STR

;;; ; Move the current PL0 stack down to where it would be
;;; ; had the CPU used the TSS_ESP0 we calculated.
;;;
;;;	    mov     edi,PPL0STK_MAX ; Get maximum stack offset
;;;	    mov     esi,PLCL_PL0CUR ; Get offset in DGROUP of current local stack
;;;	    sub     edi,DGROUP:[esi] ; Less length of saved stack
;;;	    mov     ecx,type INTDPI_STR ; Get length of PL0 stack to move down
;;;	    sub     edi,ecx	    ; Less length of move
;;;	    mov     esi,esp	    ; Get source offset
;;;	    mov     esp,edi	    ; Back off to that offset
;;;	    mov     ebp,esp	    ; ...
;;;
;;;	    lea     eax,[ecx+esi]   ; Add to get ending source address
;;;
;;;	    cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	    jbe     short @F	    ; Jump if not
;;;
;;;	    SWATMAC ERR 	    ; Call our debugger
;;; @@:
;;;	    lea     eax,[ecx+edi]   ; Add to get ending destin address
;;;
;;;	    cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	    jbe     short @F	    ; Jump if not
;;;
;;;	    SWATMAC ERR 	    ; Call our debugger
;;; @@:
;;;	    mov     ax,ss	    ; Copy stack selector
;;;	    mov     es,ax	    ; Address it
;;;	    assume  es:nothing	    ; Tell the assembler about it
;;;
;;;	    cld 		    ; String ops fowardly
;;; S32 rep movs    <es:[edi].LO,ss:[esi].LO> ; Copy the stack down
;;;
;;; ; Restore the original PL0 stack from PLCL_PL0CUR
;;;
;;;	    mov     esi,PLCL_PL0CUR ; Get offset in DGROUP of current local stack
;;;	    mov     ecx,DGROUP:[esi] ; Get over length of saved stack
;;;	    jecxz   DPMI_INTRET_DMS ; Jump if we're at the deadman's switch
;;;
;;;	    add     esi,4	    ; Skip over length of saved stack
;;;
;;;	    lea     eax,[ecx+edi]   ; Add to get ending destin address
;;;
;;;	    cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	    jbe     short @F	    ; Jump if not
;;;
;;;	    SWATMAC ERR 	    ; Call our debugger
;;; @@:
;;; ;;;;;;; cld 		    ; String ops fowardly
;;; S32 rep movs    <es:[edi].LO,DGROUP:[esi].LO> ; Copy the stack down
;;; DPMI_INTRET_DMS:

; See if we got here through PMIDEFxx or PMILPM

	cmp	[ebp].DPMI_INTRET_EIP,PMILPM+@PMxDEF_LEN ; Izit PMILPM?
	jne	near ptr DPMI_INTRET_XLPM ; Jump if not

;;;;;;; mov	PLCL_PL0CUR,esi ; Strip from storage

; The DPMI client exited with IRET/D on the LPM stack,
; possibly RETF/D if it's INT 23h

; If we're in a debuggin' mood, check for different selectors
; from when we entered the DPMI client's handler

	test	DPM_FLAG,mask $DPM_DPMISEL ; Are we in the mood?
	jz	near ptr DPMI_INTRET_XDBG ; Jump if not

	mov	ax,SAVE_DS.ELO	; Get caller's DS
	xchg	ax,LAST_DPMI_DS ; Swap 'em

	cmp	ax,LAST_DPMI_DS ; Izit different?
	je	short @F	; Jump if not

	cmp	ax,NEXT_DPMI_DS ; Izit different?
	je	short @F	; Jump if not

	SWATMAC ERR		; Call our debugger
@@:
	mov	ax,SAVE_ES.ELO	; Get caller's ES
	xchg	ax,LAST_DPMI_ES ; Swap 'em

	cmp	ax,LAST_DPMI_ES ; Izit different?
	je	short @F	; Jump if not

	cmp	ax,NEXT_DPMI_ES ; Izit different?
	je	short @F	; Jump if not

	SWATMAC ERR		; Call our debugger
@@:
	mov	ax,fs		; Get caller's FS
	xchg	ax,LAST_DPMI_FS ; Swap 'em

	cmp	ax,LAST_DPMI_FS ; Izit different?
	je	short @F	; Jump if not

	cmp	ax,NEXT_DPMI_FS ; Izit different?
	je	short @F	; Jump if not

	SWATMAC ERR		; Call our debugger
@@:
	mov	ax,gs		; Get caller's GS
	xchg	ax,LAST_DPMI_GS ; Swap 'em

	cmp	ax,LAST_DPMI_GS ; Izit different?
	je	short @F	; Jump if not

	cmp	ax,NEXT_DPMI_GS ; Izit different?
	je	short @F	; Jump if not

	SWATMAC ERR		; Call our debugger
@@:
DPMI_INTRET_XDBG:

; The flags in DPMI_INTRET_EFL from the IRET/D are to be returned to
; the caller, except for VM and IOPL which should remain the
; same as the caller's.

FLMASK	=	((mask $VMHI) or (mask $IOPL))

	mov	eax,[ebp].DPMI_INTRET_EFL ; Get return EFL
	and	eax,not FLMASK	; VM=IOPL=0
	and	[ebp+(size DPMI_INTRET_STR)].NRM_EFL,FLMASK ; Isolate
	or	[ebp+(size DPMI_INTRET_STR)].NRM_EFL,eax ; Include

; If this is a return from INT 23h via RETF/D and CF=1 in
; the DPMI stack, convert it into PMIDEF23

; Izit INT 23h?

	cmp	[ebp+(size DPMI_INTRET_STR)].NRM_INTNO,4*23h+offset PGROUP:INTPROC00Z
	jne	short DPMI_INTRET_X23 ; Jump if not

; Perform sanity check

	test	[ebp+(size DPMI_INTRET_STR)].NRM_EFL.EHI,mask $VM ; Izit from VM?
	jz	short DPMI_INTRET_X23 ; Jump if not

; Check for the way the client terminated by looking at the size
; of the PL3 stack at this point in case we're
; returning from INT 23h.  This value is 0 if the client exited
; via IRET/D and 2 for 16-bit clients or 4 for 32-bit clients
; (the size of the remaining eFL) if the client exited via RETF/D.

	mov	INT23_TYP,@INT23_IGNORE ; Assume it's IRET/D

	push	[ebp].DPMI_INTRET_LPMSTK.FSEL.EDD ; Pass the LPM stack selector
				; as dword
	call	GETBASE 	; Return with EAX = base address of selector

	add	eax,[ebp].DPMI_INTRET_LPMSTK.FOFF ; Plus offset to get
				; previous stack top

	mov	ebx,eax 	; Save old linear address

	push	[ebp].DPMI_INTRET_SS.EDD ; Pass the stack selector as dword
	call	GETBASE 	; Return with EAX = base address of selector

	add	eax,[ebp].DPMI_INTRET_ESP ; Less ESP from DPMI stack

	sub	ebx,eax 	; Less linear address of SS:ESP from DPMI stack
	jz	short @F	; Jump if it's IRET/D

; Check the returning carry flag

	test	[ebp].DPMI_INTRET_EFL.ELO,mask $CF ; Izit set?
	jz	short @F	; Jump if not

	mov	INT23_TYP,@INT23_ABORT ; Mark as terminating
@@:
	jmp	DPMI_INTRET_XLPM23 ; Join common code


DPMI_INTRET_X23:

DPMI_INT24_STR struc

DPMI_INT24_AX dw ?		; VM INT 21h  AX
DPMI_INT24_BX dw ?		; ...	      BX
DPMI_INT24_CX dw ?		; ...	      CX
DPMI_INT24_DX dw ?		; ...	      DX
DPMI_INT24_SI dw ?		; ...	      SI
DPMI_INT24_DI dw ?		; ...	      DI
DPMI_INT24_BP dw ?		; ...	      BP
DPMI_INT24_DS dw ?		; ...	      DS
DPMI_INT24_ES dw ?		; ...	      ES
DPMI_INT24_IP dw ?		; ...	      IP
DPMI_INT24_CS dw ?		; ...	      CS
DPMI_INT24_FL dw ?		; ...	      FL

DPMI_INT24_STR ends

; If this is a return from INT 24h, copy the DPMI_INT24_STR
; back to the VM stack, and check AL for translation

; Izit INT 24h?

	cmp	[ebp+(size DPMI_INTRET_STR)].NRM_INTNO,4*24h+offset PGROUP:INTPROC00Z
	jne	near ptr DPMI_INTRET_X24 ; Jump if not

; Perform sanity check

	test	[ebp+(size DPMI_INTRET_STR)].NRM_EFL.EHI,mask $VM ; Izit from VM?
	jz	short DPMI_INTRET_X24 ; Jump if not

; Copy the LPM stack DPMI_INT24_STR registers back to the VM stack

	REGSAVE <ds,es> 	; Save for a moment

	mov	es,SEL_4GB	; Get our all memory selector
	assume	es:AGROUP	; Tell the assembler about it

	movzx	edi,[ebp+(size DPMI_INTRET_STR)].INTCOM_SS ; Get SS from VM
	shl	edi,4-0 	; Convert from paras to bytes
	movzx	ecx,[ebp+(size DPMI_INTRET_STR)].INTCOM_ESP.ELO ; Get SP from VM
	add	edi,ecx 	; DS:ESI ==> VM caller's stack

; If the B-bit in the stack selector is clear, zero the upper
; word of the stack offset so we can use it as a dword.

	lea	esi,[ebp].DPMI_INTRET_ESP ; SS:ESI ==> SS|ESP from PL3
	push	esi		; Pass the offset
	call	DPMIFN_ESPMOD	; Clear the high-order word of the PL3 ESP
				; if the B-bit in the PL3 SS is clear
	mov	eax,PCURTSS	; Get offset in DGROUP of the current TSS
	mov	ah,DGROUP:[eax].DPTSS_I24FLG ; Get the original flags

	lds	esi,[ebp].DPMI_INTRET_ESP.EDF ; DS:ESI ==> DPMI stack
	assume	ds:nothing	; Tell the assembler about it

	mov	ecx,(size DPMI_INT24_STR)/2 ; Get # words to copy
;;;;;;; cld			; String ops fowardly
S32 rep movs	<AGROUP:[edi].ELO,ds:[esi].ELO> ; Copy back

	REGREST <es,ds> 	; Restore
	assume	ds:DGROUP,es:nothing ; Tell the assembler about it

COMMENT|

If IGNORE is specified but not allowed (AH & @BIT5 == 0),
  convert the response to FAIL.

If RETRY is specified but not allowed (AH & @BIT4 == 0),
  convert the response to FAIL.

If FAIL is specified but not allowed (AH & @BIT3 == 0),
  convert the response to TERMINATE.

|

	cmp	INT24_TYP,@INT24_REFLVM ; Should we reflect it to VM?
	je	short @F	; Jump if so

	mov	al,SAVE_EAX.LO	; Restore original value
	call	DPMIFN_I24XLAT	; Translate AL return code w/AH=flags
				; returning AL = new return code
	mov	INT24_TYP,al	; Save for later use
	mov	SAVE_EAX.LO,al	; Tell DOS about it as well
@@:
	jmp	DPMI_INTRET_XLPM24 ; Join common code


DPMI_INTRET_X24:
	add	esp,DPMI_INTRET_REST ; Strip from the stack to old restore point

; De-allocate our portion of the LPM stack

	pop	LPMSTK_FVEC.FOFF ; De-allocate it
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

; Because some DPMI clients (pssst, it's Windows 3.10 á 2) may
; invalidate the selectors we carefully pushed onto the stack
; when we handled an interrupt so we can restore them now, we must
; VERR them and zero the invalid ones.

	VERREST <gs,fs,es,ds>	; Restore selectors with VERR
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

; Restore the previous LAST_INTFLG, LAST_INTCOM, and TSS_ESP0 and TSS_SS0
; to the TSS

; Between the time we change the MAX stack pointer in the TSS
; and we recalculate PL0STK pointers, we can't allow any interruption

;;;;;;; cli			; Disallow interrupts (already disabled above)

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	pop	SAVE_DS 	; Save to restore later

	pop	LAST_INTFLG	; Restore
	pop	LAST_INTCOM	; Restore

;;;;;;; add	esp,type DPMI_INTRET_PL0LEN ; Strip
;;;;;;;
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	pop	DGROUP:[eax].TSS_ESP0 ; Restore
	pop	DGROUP:[eax].TSS_SS0  ; ...

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

; If we switched out a TSS, switch it back in

	pop	eax		; Restore incoming PCURTSS

	xchg	eax,PCURTSS	; Get original TSS, save incoming one
	call	DPMIFN_NESTRET	; Check for nesting return with EAX=old PCURTSS
	assume	es:nothing,fs:nothing,gs:nothing ; Tell the assembler about it

	pop	eax		; Restore DPMI_INTRET_FLG

	cmp	eax,@PMINTCOM_LPM ; Did we use the LPM stack?
	jne	short @F	; Jump if not

	dec	LPMSTK_CNT	; Count it out
@@:

; Restore saved registers

	mov	eax,SAVE_EAX	; Restore
	mov	ebx,SAVE_EBX	; ...
	mov	ecx,SAVE_ECX	; ...
	mov	esi,SAVE_ESI	; ...
	mov	edi,SAVE_EDI	; ...
	mov	ebp,SAVE_EBP	; ...

	mov	es,SAVE_ES	; Already restored w/VERREST???
	assume	es:nothing	; Tell the assembler about it

; Restore VM MSW if we are returning to VM

	test	[esp].NRM_EFL.EHI,mask $VM ; Are we in VM 86 mode?
	jz	short @F	; Jump if not

	push	PVMTSS		; Pass offset in DGROUP of the 1st TSS
	call	DPMIFN_LMSW	; Put MSW and INT 07h values into effect
@@:
	mov	ds,SAVE_DS	; Restore
	assume	ds:nothing	; Tell the assembler about it

;;;;;;; jmp	DPMI_COM_IRETD	; Join common IRETD code


; Ensure NT=0 so the following IRETD doesn't cause a task switch

	pushf			; Get our flags
	and	[esp].ELO,not (mask $NT) ; NT=0
	popf			; Restore

	test	[esp].IRETD_EFL.EHI,mask $VM ; Izit VM?
	jnz	short @F	; Jump if so

	iretd			; Return to caller (PM only)


@@:
	jmp	ERM_FVEC	; Return to RM/VCPI


; We returned from INT 24h.
; Because we used the LPM stack, we need to strip it as we're not
; returning to the DPMI client.

	assume	ds:DGROUP	; Tell the assembler about it
DPMI_INTRET_XLPM24:
	lea	ebp,PMINT_JMP[24h*@xxTJMP_LEN] ; Mark as INT 24h

	jmp	short DPMI_INTRET_XLPM_COM ; Join common code


; We returned from INT 23h.
; Because we used the LPM stack, we need to strip it as we're not
; returning to the DPMI client.

	assume	ds:DGROUP	; Tell the assembler about it
DPMI_INTRET_XLPM23:
	lea	ebp,PMINT_JMP[23h*@xxTJMP_LEN] ; Mark as INT 23h
DPMI_INTRET_XLPM_COM:
	add	esp,DPMI_INTRET_REST ; Strip from the stack to old
				; restore point
; De-allocate our portion of the LPM stack

	pop	LPMSTK_FVEC.FOFF ; De-allocate it
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

; Because some DPMI clients (pssst, it's Windows 3.10 á 2) may
; invalidate the selectors we carefully pushed onto the stack
; when we handled an interrupt so we can restore them now, we must
; VERR them and zero the invalid ones.

	VERREST <gs,fs,es,ds>	; Restore selectors with VERR
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

; Restore the previous LAST_INTFLG, LAST_INTCOM, and TSS_ESP0 and TSS_SS0
; to the TSS

; Between the time we change the MAX stack pointer in the TSS
; and we recalculate PL0STK pointers, we can't allow any interruption

;;;;;;; cli			; Disallow interrupts (already disabled above)

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	pop	SAVE_DS 	; Save to restore later

	pop	LAST_INTFLG	; Restore
	pop	LAST_INTCOM	; Restore

;;;;;;; add	esp,type DPMI_INTRET_PL0LEN ; Strip
;;;;;;;
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	pop	DGROUP:[eax].TSS_ESP0 ; Restore
	pop	DGROUP:[eax].TSS_SS0  ; ...

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

; If we switched out a TSS, switch it back in

	pop	eax		; Restore incoming PCURTSS

	xchg	eax,PCURTSS	; Get original TSS, save incoming one
	call	DPMIFN_NESTRET	; Check for nesting return with EAX=old PCURTSS
	assume	es:nothing,fs:nothing,gs:nothing ; Tell the assembler about it

	pop	eax		; Restore DPMI_INTRET_FLG

	cmp	eax,@PMINTCOM_LPM ; Did we use the LPM stack?
	jne	short @F	; Jump if not

	dec	LPMSTK_CNT	; Count it out
@@:
	xchg	ebp,SAVE_EBP	; Swap with original EBP

; Restore saved registers

	push	SAVE_EBP	; Pass return address

	mov	eax,SAVE_EAX	; Restore
	mov	ebx,SAVE_EBX	; ...
	mov	ecx,SAVE_ECX	; ...
	mov	esi,SAVE_ESI	; ...
	mov	edi,SAVE_EDI	; ...

;;;;;;; mov	es,SAVE_ES	; Already restored w/VERREST
;;;;;;; assume	es:nothing	; Tell the assembler about it

	mov	ds,SAVE_DS	; ...
	assume	ds:nothing	; Tell the assembler about it

	retn			; Take appropriate action


; We got here through JMPF/CALLF
; Note IF=0 and various registers have been saved
;;;; ESI = end of stack restored from PLCL_PL0CUR

	public	DPMI_INTRET_XLPM
	assume	ds:DGROUP	; Tell the assembler about it
DPMI_INTRET_XLPM:

; Calculate the interrupt # whose default handler we should invoke
; The interrupt # (xx in PMIDEFxx) is calculated from DPMI_INTRET_EIP
; on the MAX stack.

; If the B-bit in the stack selector is clear, zero the upper
; word of the stack offset so we can use it as a dword.

	lea	ebx,[ebp].DPMI_INTRET_ESP ; SS:EBX ==> SS|ESP from PL3
	push	ebx		; Pass the offset
	call	DPMIFN_ESPMOD	; Clear the high-order word of the PL3 ESP
				; if the B-bit in the PL3 SS is clear
	les	ebx,[ebp].DPMI_INTRET_ESP.EDF ; ES:EBX ==> DPMI stack
	assume	es:nothing	; Tell the assembler about it

; Copy the return address on the DPMI stack to the MAX stack
; and strip it from the DPMI stack

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	short DPMI_INTRET_XLPM16 ; Jump if so

DPMI_INT32A_STR struc

DPMI_INT32A_EIP dd ?		; This INT's return EIP
DPMI_INT32A_CS	dw ?,?		; ...		    CS with filler
DPMI_INT32A_EFL dd ?		; ...		    EFL

DPMI_INT32A_STR ends

	mov	eax,es:[ebx].DPMI_INT32A_EFL ; Get EFL
	mov	[ebp].DPMI_INTRET_EFL,eax ; Save on MAX stack

	mov	ax,es:[ebx].DPMI_INT32A_CS ; Get CS
	mov	[ebp].DPMI_INTRET_CS,ax ; Save on MAX stack

	mov	eax,es:[ebx].DPMI_INT32A_EIP ; Get EIP
	xchg	eax,[ebp].DPMI_INTRET_EIP ; Get EIP, swap with return address

	add	ebx,type DPMI_INT32A_STR ; Strip EIP, CSF, EFL from the DPMI stack

	jmp	short DPMI_INTRET_XLPMCOM ; Join common code


DPMI_INTRET_XLPM16:

DPMI_INT16A_STR struc

DPMI_INT16A_IP	dw ?		; This INT's return IP
DPMI_INT16A_CS	dw ?		; ...		    CS
DPMI_INT16A_FL	dw ?		; ...		    FL

DPMI_INT16A_STR ends

	movzx	eax,es:[ebx].DPMI_INT16A_FL ; Get FL
	mov	[ebp].DPMI_INTRET_EFL,eax ; Save on MAX stack

	mov	ax,es:[ebx].DPMI_INT16A_CS ; Get CS
	mov	[ebp].DPMI_INTRET_CS,ax ; Save on MAX stack

	movzx	eax,es:[ebx].DPMI_INT16A_IP ; Get IP
	xchg	eax,[ebp].DPMI_INTRET_EIP ; Get IP, swap with return address

	add	ebx,type DPMI_INT16A_STR ; Strip IP, CS, FL from the DPMI stack
DPMI_INTRET_XLPMCOM:
	mov	[ebp].DPMI_INTRET_ESP,ebx ; Strip the DPMI stack

; Note EAX = return EIP

; Set new LPM stack top for nested callers if it's active
; and we're called from PM, not PL0

	cmp	LPMSTK_CNT,0	; Is the LPM stack active?
	je	short DPMI_INTRET_LPMINACT ; Jump if not

; The following tests are unnecessary as the caller has already
; been qualified as a DPMI client at PL3
;;;;;;;
;;;;;;; test	[ebp].DPMI_INTRET_EFL.EHI,mask $VM ; Izit from VM?
;;;;;;; jnz	short DPMI_INTRET_LPMINACT ; Jump if so
;;;;;;;
;;;;;;; test	[ebp].DPMI_INTRET_CS,mask $PL ; Izit from PL0?
;;;;;;; jz	short DPMI_INTRET_LPMINACT ; Jump if so
;;;;;;;
	mov	LPMSTK_FVEC.FOFF,ebx ; Save caller's offset
	mov	LPMSTK_FVEC.FSEL,es ; ...	      selector
DPMI_INTRET_LPMINACT:

; Calculate the interrupt # whose default handler we should invoke
; The interrupt # (xx in PMIDEFxx) is calculated from DPMI_INTRET_EIP
; on the MAX stack and 4 * INT # + offset PGROUP:INTPROC00Z is saved
; in DPMI_INTRET_IDEF.

	push	edx		; Save for a moment

	sub	eax,@PMxDEF_LEN+PMIDEF00 ; Convert to origin-0
	xor	edx,edx 	; Zero to use in dividend
	mov	ebx,@PMxDEF_LEN ; Get divisor
	div	ebx		; Divide to get EAX = interrupt #

	pop	edx		; Restore

	mov	ebx,eax 	; Save for a moment

	shl	ebx,2-0 	; Convert from dwords to bytes
	add	ebx,offset PGROUP:INTPROC00Z ; Convert to final form
	mov	[ebp].DPMI_INTRET_IDEF,bx ; Save for later use

	imul	eax,@xxTJMP_LEN ; Multiply to get offset in PMINT_JMP
	add	eax,offset PGROUP:PMINT_JMP ; Plus offset of JMP base
	xchg	eax,SAVE_EAX	; Swap with original EAX

	push	SAVE_EAX	; Pass return address

	mov	ebp,SAVE_EBP	; Restore
	mov	ebx,SAVE_EBX	; ...
	mov	ecx,SAVE_ECX	; ...
	mov	esi,SAVE_ESI	; ...
	mov	edi,SAVE_EDI	; ...

	mov	es,SAVE_ES	; ...
	assume	es:nothing	; Tell the assembler about it

	mov	ds,SAVE_DS	; ...
	assume	ds:nothing	; Tell the assembler about it

	retn			; Take appropriate action

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_INTRET endp		; End DPMI_INTRET procedure
	NPPROC	DPMIFN_I24XLAT -- Translate INT 24h Return code
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Translate INT 24h return code

On entry:

AL	=	initial return code
AH	=	I24_REC flags

On exit:

AL	=	translated return code

|

	test	ah,mask $I24_IGNORE ; Izit allowed?
	jnz	short @F	; Jump if so

	cmp	al,@INT24_IGNORE ; Izit Ignore?
	jne	short @F	; Jump if not

	mov	al,@INT24_FAIL	 ; Translate it into Fail
@@:
	test	ah,mask $I24_RETRY ; Izit allowed?
	jnz	short @F	; Jump if so

	cmp	al,@INT24_RETRY  ; Izit Retry?
	jne	short @F	; Jump if not

	mov	al,@INT24_FAIL	 ; Translate it into Fail
@@:
	test	ah,mask $I24_FAIL ; Izit allowed?
	jnz	short @F	; Jump if so

	cmp	al,@INT24_FAIL	 ; Izit Fail?
	jne	short @F	; Jump if not

	mov	al,@INT24_ABORT  ; Translate it into Abort
@@:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_I24XLAT endp		; End DPMIFN_I24XLAT procedure
	NPPROC	FLTPROC -- PM Fault From DPMI Client
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

PM Fault from DPMI client

A fault occurred while the DPMI client was executing and
neither our leading fixup code nor the client's exception
handler (if any) could fix it up.

Our default action is to reflect the exception as a PM interrupt
(similar to HW-DPMI) for 00h-05h, and 07h, and to terminate the DPMI
client for all others.

The MAX stack contains (from bottom up) INTDPF_STR.

If we enter at FLTPROC_APPL, the MAX stack contains INTDPF_STR with
the actual fault address.  Also, INTDPF_INTNO is filled in with with
the INT # times 4 + offset PGROUP:INTPROC00Z.

If we enter at FLTPROCxx, the MAX stack contains a pseudo-error
code, DPMI_FLTRET_STR with the return address to the DPMI client's
fault handler, and the original INTDPF_STR.  Also, INTDPF_INTNO is
filled in with the INT #.

Subsequently, at FLTPROC_FLTCOM or FLTPROC_INTCOM we can tell which of
the above two sources we came by examining INTDPF_INTNO.  If it's
below 20h (maximum fault #), we came from FLTPROCxx; if it's above
that, we came from FLTPROC_APPL (which came from INTCOM_DPMI_FAULT).

|

; Enter here from INTCOM_DPMI_FAULT to jump to appropriate routine

	public	FLTPROC_APPL
FLTPROC_APPL:
	push	eax		; Save for a moment and make room for RET target

	movzx	eax,[esp+4].INTDPF_INTNO ; Get INT # times 4 + ...
	sub	eax,offset PGROUP:INTPROC00Z ; Convert to INT # times 4
	shr	eax,2-0 	; Convert from times 4 to times 1
	imul	eax,@xxTJMP_LEN ; Times jump length
	add	eax,offset PGROUP:FLTJMP00 ; Plus start of fault jump table

	xchg	eax,[esp]	; Put onto stack, swap with original value

	retn			; Jump to appropriate routine (FLTPROCxx)


PMFDEF_MAC macro N,TYP

	public	FLTPROC&N
FLTPROC&N:
	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	DPMIMSG,offset DGROUP:DPMIMSG&N ; Save offset of debugging message

	jmp	FLTPROC_&TYP&COM ; Join common code

	endm			; PMFDEF_MAC


	PMFDEF_MAC 00,INT
	PMFDEF_MAC 01,INT
	PMFDEF_MAC 02,INT
	PMFDEF_MAC 03,INT
	PMFDEF_MAC 04,INT
	PMFDEF_MAC 05,INT
	PMFDEF_MAC 07,INT07
FLTPROC_INT07COM:
	clts			; Clear the TS bit in CR0
FLTPROC_INTCOM:
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

; The MAX stack is mapped by INTDPF_STR

; If the INTDPF_INTNO field is < 20h, convert it to the
; INT # * 4 + offset PGROUP:INTPROC00Z format for the VM
; reflection code.

	cmp	[esp].INTDPF_INTNO,20h ; Izit INT #?
	jae	short @F	; Jump if not

	shl	[esp].INTDPF_INTNO,2-0 ; Convert from times 1 to times 4
	add	[esp].INTDPF_INTNO,offset PGROUP:INTPROC00Z ; Convert to INT # * 4 + ...
@@:

; The default action for these exceptions is to reflect
; the exception to VM.

	add	esp,size INTDPF_ERR ; Strip off error code

; The MAX stack is mapped by INTDPI_STR

	jmp	INTCOM_DPMI_INTMAX ; Reflect to VM


	PMFDEF_MAC _VMFULL,FLT
	PMFDEF_MAC _LPMFULL,FLT
	PMFDEF_MAC _APPLFULL,FLT
	PMFDEF_MAC 06,FLT

CNT	=	8
.sall
	rept	32-CNT

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	PMFDEF_MAC %N,FLT
CNT	=	CNT + 1
	endm			; REPT 32-CNT
.lall

; The MAX stack is mapped by INTDPF_STR

FLTPROC_FLTCOM:
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

; If we came from the DPMI client's fault handler, strip back the
; stack to the original INTDPF_STR as we aren't coming back to
; the client's handler

	call	FLTPROC_STRIP	; Strip it if appropriate
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

	public	FLTPROC_ABORT
FLTPROC_ABORT:

; If this is an INT 03h, decrement INTDPF_EIP so SWAT
; or the abort message sees the proper offset.

	push	eax		; Save for a moment

	movzx	eax,[esp+4].INTDPF_INTNO ; Get INT # times 4 + ...
				; or INT #
	cmp	eax,20h 	; Izit already INT #?
	jb	short @F	; Jump if so

	sub	eax,offset PGROUP:INTPROC00Z ; Convert to INT # times 4
	shr	eax,2-0 	; Convert from times 4 to times 1
@@:
	cmp	eax,03h 	; Izit INT 03h?
	pop	eax		; Restore
	jne	short @F	; Jump if not

	dec	[esp].INTDPF_EIP ; Back off to INT 03h instruction
@@:

; The MAX stack is mapped by INTDPF_STR which contains the actual
; faulting address

;;;;;;; test	LCL_FLAG,@LCL_SWAT ; Is SWAT installed?
;;;;;;; jnz	near ptr FLTPROC_SWAT ; Jump if so
;;;;;;;
; Nobody home, so we'll terminate the DPMI client
; after printing a suitable message

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	pop	SAVE_DS 	; Save to restore later

; Move the INTDPF_STR down so it's at the bottom of INTCOM_STR
; preceded by an error code as that's what is expected on the
; other side of the following IRET

	mov	SAVE_EAX,eax	; Save for a moment

@STKDIFF equ	(size INTCOM_STR) - (size INTDPI_STR)

	sub	esp,@STKDIFF	; Make room

	mov	eax,[esp+@STKDIFF].INTDPF_ERR; Get old error code
	mov	[esp].INTDPF_ERR,eax ; Save in new place

	mov	eax,[esp+@STKDIFF].INTDPF_EIP ; Get old EIP
	mov	[esp].INTDPF_EIP,eax ; Save in new place

	mov	eax,[esp+@STKDIFF].INTDPF_CS.EDD ; Get old CS w/filler
	mov	[esp].INTDPF_CS.EDD,eax ; Save in new place

	mov	eax,[esp+@STKDIFF].INTDPF_EFL ; Get old EFL
	mov	[esp].INTDPF_EFL,eax ; Save in new place

	lea	eax,[esp+@STKDIFF].INTDPF_ESP ; Get next offset

	cmp	eax,PPL0STK_MAX ; Izit too big?
	jae	short @F	; Jump if so

	mov	eax,[esp+@STKDIFF].INTDPF_ESP ; Get old ESP
	mov	[esp].INTDPF_ESP,eax ; Save in new place

	mov	eax,[esp+@STKDIFF].INTDPF_SS.EDD ; Get old SS w/filler
	mov	[esp].INTDPF_SS.EDD,eax ; Save in new place
@@:

; Save this ESP as the previous TSS's ESP so when we IRET, the
; stack on the other side points to our current stack.

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	mov	eax,DGROUP:[eax].DPTSS_PLNKTSS ; Back off to previous TSS
	mov	DGROUP:[eax].TSS_ESP,esp ; Save to use after IRET NT below
	mov	eax,SAVE_EAX	; Restore
	mov	ds,SAVE_DS	; ...
	assume	ds:nothing	; Tell the assembler about it

; If there are any activities which need to be done at
; termination time when PCURTSS and TR match, now's the time

	call	DPMIFN_TERMINATE ; Handle termination (note IF=0 upon return)
	assume	ds:nothing,es:DGROUP  ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; ...

	mov	EXITRC.LO,-1	; Save pseudo-return code

; Tell our terminate code that we're terminating because of a fault,
; and not to switch stacks.
; Note that we set these bits after calling DPMIFN_TERMINATE as it
; restores the previous I31_FLAG values.

	or	I31_FLAG,(mask $I31_EXIT)     or \
			 (mask $I31_FAULT)    or \
			 (mask $I31_NOSWITCH)

;;; ; Set NT bit and IRET to it to affect task switch
;;;
;;;	     pushf		    ; Save flags
;;;	     or      [esp].ELO,mask $NT ; Set the NT bit
;;;	     popf		    ; Put it into effect
;;;
;;; ; The following IRET causes a task switch to the back link TSS
;;; ; which is (presumably) PVMTSS.  As the task switch from PVMTSS
;;; ; was initiated by the hand-constructed CALLF VM2PM_TSS, execution
;;; ; continues at that point.
;;;
;;;	     iret		    ; Return to caller
;;;
	PUSHW	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	SAVE_EAX,eax	; Save for a moment

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	push	DGROUP:[eax-(type DPTSS_STR)].TSS_CS ; Pass CS
	push	DGROUP:[eax-(type DPTSS_STR)].TSS_EIP ; ... EIP

LINTXX_STR struc

	dd	?		; Return offset
	dw	?		; ...	 selector
LINTXX_DS dw	?		; Original DS

LINTXX_STR ends

	mov	eax,SAVE_EAX	; Restore

	mov	ds,[esp].LINTXX_DS ; Restore
	assume	ds:nothing	; Tell the assembler about it

	retf			; Continue with next


; The MAX stack is mapped by INTDPF_STR which contains the actual
; faulting address

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing

;;;	     public  FLTPROC_SWAT
;;; FLTPROC_SWAT:
;;;
;;; ; Note that the error code is already on the stack and is used
;;; ; as an argument to the call to SWATMSG which pops the error
;;; ; code upon return.
;;;
;;;	     push    dword ptr (DTE_FIXUP or (@DPMI_CPL shl $PL)) ; Segment of error message
;;;	     push    eax	    ; Placeholder for offset of error message
;;;	     movzx   eax,DPMIMSG    ; Zero high-order word for SWATMSG
;;;	     add     ax,size LENTXT_LEN ; Skip over the string length
;;;	     xchg    eax,[esp]	    ; Put offset onto stack, restore original value
;;;	     call    SWATMSG	    ; Pass error message to 386SWAT
;;;
;;; ; The MAX stack is mapped by INTDPI_STR which contains the actual
;;; ; faulting address
;;;
;;;	     jmp     INT01_COMMON   ; Join common debugging code
;;;
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FLTPROC endp			; End FLTPROC procedure
	NPPROC	FLTPROC_STRIP -- Strip To Original INTDPF_STR
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Strip to original INTDPF_STR

If we came from the DPMI client's fault handler, strip back the
stack to the original INTDPF_STR as we aren't coming back to
the client's handler.

On entry:

IF	=	0

|

FLTPROC_STR struc

	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
FLTPROC_ERR dd	?		; Pseudo-error code
FLTPROC_NXT db	(size DPMI_FLTRET_STR) dup (?) ; The rest of the stack

FLTPROC_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ebx,ds,gs> ; Save registers

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	gs,SEL_4GB	; Get AGROUP data selector
	assume	gs:AGROUP	; Tell the assembler about it

	cmp	[ebp].FLTPROC_NXT.DPMI_FLTRET_FDEF,20h ; Izit INT #?
	jae	near ptr FLTPROC_INTCOM1 ; Jump if not

; De-allocate our portion of the LPM stack

	mov	eax,[ebp].FLTPROC_NXT.DPMI_FLTRET_LPMSTK.FOFF ; Get previous LPM stack top
	mov	LPMSTK_FVEC.FOFF,eax ; De-allocate it
	mov	ax,[ebp].FLTPROC_NXT.DPMI_FLTRET_LPMSTK.FSEL ; ...
	mov	LPMSTK_FVEC.FSEL,ax ; De-allocate it

	cmp	[ebp].FLTPROC_NXT.DPMI_FLTRET_FLG,@PMINTCOM_LPM ; Did we use the LPM stack?
	jne	short @F	; Jump if not

	dec	LPMSTK_CNT	; Count it out
@@:

; Restore the previous TSS_ESP0 and TSS_SS0 to the TSS

; Between the time we change the MAX stack pointer in the TSS
; and we recalculate PL0STK pointers, we can't allow any interruption

;;;;;;; cli			; Disallow interrupts (already disabled)

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	mov	bx,[ebp].FLTPROC_NXT.DPMI_FLTRET_SS0 ; Get old TSS_SS0
	mov	DGROUP:[eax].TSS_SS0,bx ; Restore

	mov	ebx,[ebp].FLTPROC_NXT.DPMI_FLTRET_ESP0 ; Get old TSS_ESP0
	mov	DGROUP:[eax].TSS_ESP0,ebx ; Restore

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

	REGREST <gs,ds,ebx,eax> ; Restore
	assume	ds:nothing,gs:nothing ; Tell the assembler about it

; Restore previous data selectors

	REGSAVE <[ebp].FLTPROC_NXT.DPMI_FLTRET_DS, \
		  [ebp].FLTPROC_NXT.DPMI_FLTRET_ES, \
		  [ebp].FLTPROC_NXT.DPMI_FLTRET_FS, \
		  [ebp].FLTPROC_NXT.DPMI_FLTRET_GS>
	VERREST <gs,fs,es,ds>	; Restore selectors with VERR
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

	pop	ebp		; Restore

; Strip from the stack to previous INTDPF_STR

	ret	(size DPMI_FLTRET_STR) + (size FLTPROC_ERR) ; Strip and return


FLTPROC_INTCOM1:
	REGREST <gs,ds,ebx,eax> ; Restore
	assume	ds:nothing,gs:nothing ; Tell the assembler about it

	pop	ebp		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FLTPROC_STRIP endp		; End FLTPROC_STRIP procedure
	FPPROC	VMFLTCOM -- VM Fault For The Primary DPMI Client
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

VM Fault for the primary DPMI client.

On entry:

SS:ESP	==>	INTCOM_STR preceded by an error code

|

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	pop	SAVE_DS 	; Save to restore later

	push	@PMINTCOM_LPM	; Use LPM stack
	push	PCURTSS 	; Pass offset in DGROUP of current TSS

; If this isn't the primary client, switch now

	REGSAVE <ebx,SAVE_DS>	; Save for a moment

	mov	ebx,PPRMTSS	; Get offset in DGROUP of primary TSS

	cmp	ebx,PCURTSS	; Izit the current client?
	je	short @F	; Jump if so

; Switch to this TSS only if it's been initialized.

	test	DGROUP:[ebx].DPTSS_FLAG,mask $DPTSS_INIT ; Has it?
	jz	short @F	; Jump if not

	call	DPMIFN_NESTOUT	; Save the old state and switch to the new one
@@:
	REGREST <ds,ebx>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	near ptr PMFLTCOM ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

VMFLTCOM endp			; End VMFLTCOM procedure
	NPPROC	DPMIFN_EXPLPM -- DPMI Function to Expand LPM Stack
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI function to expand the LPM stack.
We presume that the LPM stack is Expand Down.

On entry:

SS:EBP	==>	EXP_STR (after lclPROLOG)

On exit:

CF	=	0 if successful
	=	1 if not

|

lclEXP_STR struc		; Local vars

lclEXP_TLEN dd	?		; Total length
lclEXP_OLEN dd	?		; Old length
lclEXP_SRC  dd	?		; Source linear address
lclEXP_MOD  dd	?		; Modulus:  64KB or 4GB (=0)

lclEXP_STR ends


argEXP_STR struc		; Arguments

argEXP_ALEN dd	?		; # additional bytes needed
argEXP_SEL  dw	?,?		; LPM stack selector

argEXP_STR ends


EXP_STR struc

EXPlcl	db	(type lclEXP_STR) dup (?) ; Local vars
	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
EXParg	db	(type argEXP_STR) dup (?) ; Arguments

EXP_STR ends


	lclPROLOG <EXP_STR>	; Address local vars

	pushad			; Save registers
	REGSAVE <es>		; ...

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

	cld			; String ops fowards

; Round up # bytes needed to 4KB boundary

	mov	eax,[ebp].EXParg.argEXP_ALEN ; Get # bytes needed
	add	eax,(4*1024)-1	; Round up to next 4KB
	and	eax,not ((4*1024)-1) ; ... boundary
	mov	[ebp].EXParg.argEXP_ALEN,eax ; Save as additional length

; Get the A/R word for the selector
; and save the modulus as 64KB if 16-bit stack
;			   4GB if 32-...

	lar	eax,[ebp].EXParg.argEXP_SEL.EDD ; Get A/R word

	test	eax,(mask $DTE_B) shl (8*(DESC_SEGLM1 - DESC_BASE2)) ; Izit 32-bit stack?
	mov	[ebp].EXPlcl.lclEXP_MOD,0 ; Save as modulus (4GB)
	jnz	short @F	; Jump if so

	mov	[ebp].EXPlcl.lclEXP_MOD,64*1024 ; Save as modulus (64KB)
@@:

; Get current limit/length
; which is 64KB - (LSL + 1) for 16-bit stack
;	    4GB - (LSL + 1) for 32-...
; or	    MOD - (LSL + 1)

	lsl	ecx,[ebp].EXParg.argEXP_SEL.EDD ; Get segment limit
				; e.g. 0000EFFF for 16-bit 4KB Expand-Down stack
				;      FFFFEFFF for 32-bit ...
				; where valid stack offsets range
				; from 0000F000 to 0000FFFF for 16-bit
				;      FFFFF000 to FFFFFFFF ... 32-...
	inc	ecx		; Convert from limit to length
	mov	eax,[ebp].EXPlcl.lclEXP_MOD ; Get modulus
	sub	eax,ecx 	; Subtract from modulus to get actual length
	mov	[ebp].EXPlcl.lclEXP_OLEN,eax ; Save as old length

; Calculate new stack length as OLEN + ALEN

;;;;;;; mov	eax,[ebp].EXPlcl.lclEXP_OLEN ; Get old length
	add	eax,[ebp].EXParg.argEXP_ALEN ; Add additional length to get new length
	mov	[ebp].EXPlcl.lclEXP_TLEN,eax ; Save for later use

; Allocate new stack

	push	@ALLOC_DPMI	; Tell 'em what kind of memory we're allocating
	push	eax		; Pass # bytes to allocate
	call	ALLOCMEM	; Allocate 'em
				; Return with EBX = linear address of memory
	jc	short DPMIFN_EXPLPM_EXIT ; Jump if no memory found (note CF=1)

	mov	edi,ebx 	; Save as destination address
	mov	edx,PCURTSS	; Get offset in DGROUP of current DPTSS_STR
	xchg	ebx,DGROUP:[edx].DPTSS_LPMBASE ; Save for later use
	mov	[ebp].EXPlcl.lclEXP_SRC,ebx ; Save as source address

	test	VMM_FLAG,@VMM_SYSINIT ; Is VMM active?
	jz	short @F	; Jump if not

	mov	eax,edi 	; Copy linear address
	mov	ebx,[ebp].EXPlcl.lclEXP_TLEN ; Get total length
	add	ebx,4*1024-1	; Round up to 4KB boundary
	shr	ebx,12-0	; Convert from bytes to 4KB
	call	VMM_LOCK	; Lock EBX bytes at EAX
;;;;;;; mov	VM2PM_ERR,ax	; In case we failed
	jc	short DPMIFN_EXPLPM_EXIT ; Jump if some error occurred
@@:

; Initialize the new part of the LPM stack to known values
; for debugging purposes.

;;;;;;; mov	edi,DGROUP:[edx].DPTSS_LPMBASE ; Get LA of new stack
	mov	esi,[ebp].EXPlcl.lclEXP_SRC ; Get LA of old stack
	mov	ecx,[ebp].EXParg.argEXP_ALEN ; Get size of new part
	shr	ecx,2-0 	; Convert from bytes to dwords
	mov	eax,@LPMSTKFILL ; Fill with this value
    rep stos	AGROUP:[edi].EDD ; Fill it

; Copy the old stack to the new stack

	mov	ecx,[ebp].EXPlcl.lclEXP_OLEN ; Get byte size of old length
	shr	ecx,2-0 	; Convert from bytes to dwords
    rep movs	AGROUP:[edi].EDD,AGROUP:[esi].EDD ; Copy old to new

; Change the base address of the LPM stack selector to the new address
; which is LA + Length - 64KB for 16-bit stack
;	   LA + Length - 4GB  for 32-...
; or	   LA + Length - MOD

	mov	eax,DGROUP:[edx].DPTSS_LPMBASE ; Get new base address
	add	eax,[ebp].EXPlcl.lclEXP_TLEN ; Plus new length
	sub	eax,[ebp].EXPlcl.lclEXP_MOD ; Less modulus
				; to get base address for Expand-Down segments
	push	[ebp].EXParg.argEXP_SEL.EDD ; Pass LPM stack selector as dword
	push	eax		; ...  base address
	call	SETBASE 	; Set the selector base address

; Change the length of the LPM stack to the new length
; which is 64KB - TLEN for 16-bit stack
;	    4GB - TLEN for 32-...
; or	    MOD - TLEN

	mov	eax,[ebp].EXPlcl.lclEXP_MOD ; Get modulus
	sub	eax,[ebp].EXPlcl.lclEXP_TLEN ; Less total length

	push	[ebp].EXParg.argEXP_SEL.EDD ; Pass LPM stack selector as dword
	push	eax		; ...  limit
	call	SETLENGTH	; Set the selector length

; Free the old stack

	push	[ebp].EXPlcl.lclEXP_OLEN ; Pass byte length of old stack
	push	[ebp].EXPlcl.lclEXP_SRC ; Pass starting linear address
	call	DEALLOCMEM	; Deallocate the memory
;;;;;;; jc	short ???	; Jump if error
DPMIFN_EXPLPM_EXIT:
	REGREST <es>		; Restore
	assume	es:nothing	; Tell the assembler about it
	popad			; Restore

	lclEPILOG <EXP_STR>	; Strip local vars and return

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_EXPLPM endp		; End DPMIFN_EXPLPM procedure
	NPPROC	DPMIFN_CHKSTK -- DPMI Function to Check Stack Offset
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI function to check stack offset

On entry:

SS:ESP	==>	DFCHKSTK_STR

On exit:

CF	=	0 if valid offset
	=	1 if not

|

DFCHKSTK_STR struc

	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
DFCHKSTK_FVEC df ?		; Ptr to stack location

DFCHKSTK_STR ends


	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ebx>	; Save registers

	mov	ebx,[ebp].DFCHKSTK_FVEC.FOFF ; Get stack offset

; Split cases depending upon the Expand-Down bit in the stack selector

	lar	eax,[ebp].DFCHKSTK_FVEC.FSEL.EDD ; Get A/R dword

	test	eax,(mask $DD_EXPD) shl (8*(DESC_ACCESS - DESC_BASE2)) ; Izit Expand-Down?
	jnz	short DPMIFN_CHKSTK_EXPD ; Jump if so

	lsl	eax,[ebp].DFCHKSTK_FVEC.FSEL.EDD ; Get segment limit
				; e.g. 00000FFF for a 4KB Expand-Up stack
				; where valid stack offsets range
				; from 00000000 to 00000FFF
	cmp	eax,ebx 	; Izit within upper limit?

	jmp	short DPMIFN_CHKSTK_EXIT ; Join common code (note CF=1 if not)


DPMIFN_CHKSTK_EXPD:
	lsl	eax,[ebp].DFCHKSTK_FVEC.FSEL.EDD ; Get segment limit
				; e.g. FFFFEFFF for a 4KB Expand-Down stack
				; where valid stack offsets range
				; from FFFFF000 to FFFFFFFF
	sub	ebx,eax 	; Izit above lower limit?
	ja	short DPMIFN_CHKSTK_EXIT ; Jump if so (note CF=0)

; If this is our LPM stack, attempt to grow it

	mov	ax,LPMSTK_SEL	; Get the LPM stack selector

	cmp	ax,[ebp].DFCHKSTK_FVEC.FSEL ; Izit our LPM stack?
	stc			; Assume not
	jne	short DPMIFN_CHKSTK_EXIT ; Jump if not (note CF=1)

	neg	ebx		; Negate to get limit difference
	inc	ebx		; Convert from limit to length

	push	eax		; Pass LPM stack selector as dword
	push	ebx		; ...  # bytes needed
	call	DPMIFN_EXPLPM	; Expand the LPM stack
				; Return with CF significant
DPMIFN_CHKSTK_EXIT:
	REGREST <ebx,eax>	; Restore

	pop	ebp		; Restore

	ret	8		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_CHKSTK endp		; End DPMIFN_CHKSTK procedure
	NPPROC	DPMIFN_EBXMOD -- DPMI Function To Modify EBX
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI function to modify the high-order word of EBX
if stack selector is a 16-bit stack.

On entry:

StackSel:eBX ==> stack

On exit:

EBX	=	(modified)

|

DFEBX_STR struc

	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
DFEBX_SEL dw	?,?		; Stack selector

DFEBX_STR ends


	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	push	eax		; Save for a moment

	lar	eax,[ebp].DFEBX_SEL.EDD ; Get the stack selector's A/R word

	test	eax,(mask $DTE_B) shl (8*(DESC_SEGLM1-DESC_BASE2)) ; Izit a 32-bit stack?
	pop	eax		; Restore
	jnz	short @F	; Jump if so

	movzx	ebx,bx		; Zero the high-order word
@@:
	pop	ebp		; Restore

	ret	4		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_EBXMOD endp		; End DPMIFN_EBXMOD procedure
	NPPROC	DPMIFN_ESIMOD -- DPMI Function To Modify ESI
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI function to modify the high-order word of ESI
if FS is a 16-bit stack.

On entry:

StackSel:eSI ==> stack

On exit:

ESI	=	(modified)

|

DFESI_STR struc

	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
DFESI_SEL dw	?,?		; Stack selector

DFESI_STR ends


	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	push	eax		; Save for a moment

	lar	eax,[ebp].DFESI_SEL.EDD ; Get the stack selector's A/R word

	test	eax,(mask $DTE_B) shl (8*(DESC_SEGLM1-DESC_BASE2)) ; Izit a 32-bit stack?
	pop	eax		; Restore
	jnz	short @F	; Jump if so

	movzx	esi,si		; Zero the high-order word
@@:
	pop	ebp		; Restore

	ret	4		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_ESIMOD endp		; End DPMIFN_ESIMOD procedure
	FPPROC	PMFLTCOM -- PM Fault From DPMI Client
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT!

Protected Mode fault/exception from a DPMI client
or from VM.

The terms fault and exception are used indistinguishably.

The MAX stack on entry contains (from bottom up) DPMI_FLT_PCURTSS,
DPMI_FLT_FLG, and INTDPF_STR.  The flag value is assumed to be
@PMINTCOM_LPM and is not used by this routine.	Note that INTDPF_INTNO
is already filled in with the INT # times 4 + offset PGROUP:INTPROC00Z.

The MAX stack on exit is constructed to contain (from bottom up) the
current TSS_ESP0 and TSS_SS0, and the MAX stack on entry.  The new
TSS_SS0 and TSS_ESP0 point to the previous ones thus protecting the
MAX stack above that point.

The DPMI stack on exit is taken from the LPM pool as the DPMI stack
might not be reliable (such as in a Stack Fault).  It is constructed
to contain (from bottom up) a pseudo-return CS|eIP (PMFLPM), and the
interrupted caller's eFL, eSP, and SS.

Upon return in PMILPM, we free the portion of the LPM stack we used.

The caller has already determined that a DPMI client has hooked this
interrupt, so we never return from this program.

The transference of flags from the caller to the client and back is
handled as follows:

Note that the only flags the client sees are its own return flags.
A flag transference can take one of several forms:

0 = forced to 0
3 = forced to 3
P = passed from Caller to Client
NC = Not changed
NA = Not applicable

If the interrupt comes in on the LPM stack (HW-VM, SP-VM, HW-MAX,
HW-DPMI), the caller's flags are handled as follows:

	 Client's Stack   Client's EFL   Caller's Stack
	  Upon Return	   Upon Entry	  Upon Return
------------------------------------------------------------
VM	      0 / NA (16)      0	  NC / NA (16)
RF	      P / NA (16)      0	  P / NC (16)
NT	      P 	       0	  P
IOPL	      3 	       3	  NC
IF	      P 	       0	  P
TF	      P / 0 (LPM)      0	  P / NC (LPM)
Others	      P 	       P	  P

!

DPMI_FLT_STR struc

DPMI_FLT_EBP dd ?		; PL3 caller's EBP
DPMI_FLT_EDI dd ?		; ...	       EDI
DPMI_FLT_ESI dd ?		; ...	       ESI
DPMI_FLT_ECX dd ?		; ...	       ECX
DPMI_FLT_EBX dd ?		; ...	       EBX
DPMI_FLT_EAX dd ?		; ...	       EAX

; The portion of this structure below this point *MUST* match
; the corresponding portion of DPMI_FLTRET_STR.

DPMI_FLT_LPMSTK df ?		; Original LPMSTK_FVEC
		dw ?		; For alignment
DPMI_FLT_GS  dd ?		; Caller's GS
DPMI_FLT_FS  dd ?		; ...	   FS
DPMI_FLT_ES  dd ?		; ...	   ES
DPMI_FLT_DS  dd ?		; ...	   DS
;;;DPMI_FLT_PL0LEN dd ? 	   ; Length of protected stack
DPMI_FLT_ESP0 dd ?		; Previous TSS_ESP0
DPMI_FLT_SS0 dw ?		; ...	   TSS_SS0
DPMI_FLT_PCURTSS dd ?		; ...	   PCURTSS
DPMI_FLT_FLG dd ?		; @PMINTCOM_LPM
DPMI_FLT_NXT db (size INTDPF_STR) dup (?) ; The rest of the stack

DPMI_FLT_STR ends

DPMI_FLT_PROT equ <DPMI_FLT_LPMSTK> ; Protect the stack above this point

;;;;;;; sub	esp,\ ;;;(size DPMI_FLT_PL0LEN) + \
	sub	esp,\
		    (size DPMI_FLT_SS0)    + \
		    (size DPMI_FLT_ESP0) ; Make room

	REGSAVE <ds,es,fs,gs>	; Save all selectors

	SETDATA ds		; Get DGROUP data selector at PL3
	assume	ds:DGROUP	; Tell the assembler about it

	mov	gs,SEL_4GB	; Get AGROUP data selector
	assume	gs:AGROUP	; Tell the assembler about it

	push	LPMSTK_FVEC.FSEL.EDD ; Save current LPM stack top
	push	LPMSTK_FVEC.FOFF ; ...

; Allow any PM fault handlers to take a crack at this fault first

	REGSAVE <eax,ebx,ecx,esi,edi> ; Save for a moment

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

; Set new LPM stack top for nested callers if it's active
; and we're called from PM, not PL0

	lea	eax,[ebp].DPMI_FLT_NXT.INTDPF_EIP ; SS:EAX ==> INTDPI_STR from PL3
	push	eax		; Pass the offset
	call	DPMIFN_LPMSTK	; Save new LPM stack as appropriate

	movzx	eax,[ebp].DPMI_FLT_NXT.INTDPF_INTNO ; Get INT # times 4 + ...
	sub	eax,offset PGROUP:INTPROC00Z ; Convert to INT # times 4
	shr	eax,2-0 	; Convert from INT # in bytes to dwords

; Protect the MAX stack up to [ebp].DPMI_FLT_PROT
; where we will also save the old values from TSS_SS0 and TSS_ESP0

; Between the time we change the MAX stack pointer in the TSS
; and we recalculate PL0STK pointers, we can't allow any interruption

	cli			; Disallow interrupts

	mov	ebx,PCURTSS	; Get offset in DGROUP of current TSS

	push	DGROUP:[ebx].TSS_SS0  ; Save old stack selector
	pop	[ebp].DPMI_FLT_SS0 ; Save to restore later

	push	DGROUP:[ebx].TSS_ESP0 ; Save pointer to stack top
	pop	[ebp].DPMI_FLT_ESP0 ; Save to restore later

	mov	DGROUP:[ebx].TSS_SS0,ss ; Save for next time
	mov	DGROUP:[ebx].TSS_ESP0,ebp ; ...
	add	DGROUP:[ebx].TSS_ESP0,offset DPMI_FLT_PROT ; ...

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

; Address PL3 stack

; Note interrupts are disabled over the LPM stack allocation

	les	ebx,LPMSTK_FVEC ; ES:EBX ==> special stack used by faults
	assume	es:nothing	; Tell the assembler about it

	inc	LPMSTK_CNT	; Count in another one

; Setup the PL3 stack as in DPMI_FLT10_STR

	sub	ebx,size DPMI_FLT10_STR ; Make room on PL3 stack
if @EXPD

; If this is a 16-bit stack, zero the high-order word of EBX
; to simulate using BX instead of EBX.

	push	es		; Pass stack selector
	call	DPMIFN_EBXMOD	; Modify high-order word of EBX
				; if stack selector is a 16-bit stack
; Check to see if the resulting offset is within the stack's bounds

	push	es		; Pass stack selector
	push	ebx		; ...	     offset
	call	DPMIFN_CHKSTK	; Check the stack offset
endif
	jc	near ptr PMFLTCOM_LPMFULL ; Jump if there's no room

; Build the DPMI 1.0 frame

	REGSAVE <eax>		; Save for a moment

	mov	eax,OLDCR2	; Get Page Fault linear address
	mov	es:[ebx].DPMI_FLT10_CR2,eax ; Save in frame

	MakePDEaddress eax	; Get the PDE address
	test	AGROUP:[eax].LO,@PG_PRESENT ; If PDE not present
	jz	short @F	; then jump

; In case we could generate another Page Fault, we use the one we saved

	mov	eax,es:[ebx].DPMI_FLT10_CR2 ; Get Page Fault linear address
	MakePTEaddress eax	; Get address of PTE
	mov	eax,AGROUP:[eax].PDT_PTE ; Get the PTE
	mov	es:[ebx].DPMI_FLT10_PTE,eax ; Save in frame
@@:
	REGREST <eax>		; Restore

; Fill in the client's DS, ES, FS, GS.
; If this is a VM client, the segment registers are in
; DPMI_FLT_NXT.INTCOM_xS[4] (because there's a pseudo-error code)
; Otherwise, the selectors are in DPMI_FLT_xS.

	test	[ebp].DPMI_FLT_NXT.INTDPF_EFL.EHI,mask $VM ; Izit from VM?
	jz	short PMFLTCOM_PM ; Jump if not

	push	[ebp].DPMI_FLT_NXT.INTCOM_GS.EDD[4] ; Client GS
	pop	es:[ebx].DPMI_FLT10_GS.EDD
	push	[ebp].DPMI_FLT_NXT.INTCOM_FS.EDD[4] ; Client FS
	pop	es:[ebx].DPMI_FLT10_FS.EDD
	push	[ebp].DPMI_FLT_NXT.INTCOM_ES.EDD[4] ; Client ES
	pop	es:[ebx].DPMI_FLT10_ES.EDD
	push	[ebp].DPMI_FLT_NXT.INTCOM_DS.EDD[4] ; Client DS
	pop	es:[ebx].DPMI_FLT10_DS.EDD

	jmp	short PMFLTCOM_VMPM_COM ; Join common code


PMFLTCOM_PM:
	push	[ebp].DPMI_FLT_GS		; Client GS
	pop	es:[ebx].DPMI_FLT10_GS.EDD
	push	[ebp].DPMI_FLT_FS		; Client FS
	pop	es:[ebx].DPMI_FLT10_FS.EDD
	push	[ebp].DPMI_FLT_ES		; Client ES
	pop	es:[ebx].DPMI_FLT10_ES.EDD
	push	[ebp].DPMI_FLT_DS		; Client DS
	pop	es:[ebx].DPMI_FLT10_DS.EDD
PMFLTCOM_VMPM_COM:
	push	[ebp].DPMI_FLT_NXT.INTDPF_ESP	; Client ESP
	pop	es:[ebx].DPMI_FLT10_ESP
	push	[ebp].DPMI_FLT_NXT.INTDPF_SS.EDD ; Client SS
	pop	es:[ebx].DPMI_FLT10_SS.EDD
	push	[ebp].DPMI_FLT_NXT.INTDPF_EFL	; Client flags
	pop	es:[ebx].DPMI_FLT10_EFL
	push	[ebp].DPMI_FLT_NXT.INTDPF_CS.EDD ; Client CS
	pop	es:[ebx].DPMI_FLT10_CS
	push	[ebp].DPMI_FLT_NXT.INTDPF_EIP	; Client EIP
	pop	es:[ebx].DPMI_FLT10_EIP
	push	[ebp].DPMI_FLT_NXT.INTDPF_ERR ; Error code
	pop	es:[ebx].DPMI_FLT10_ERR

	mov	es:[ebx].DPMI_FLT10_INFO,@BIT1 ; Initialize the flags
				; to assume VM:
				; Bit 0=0:  Exception occurred in client (?)
				; Bit 1=1:  Exception cannot be retried
				; Bit 2-15=0
	test	[ebp].DPMI_FLT_NXT.INTDPF_EFL.EHI,mask $VM ; Izit from VM?
	jnz	short PMFLTCOM_XINFO ; Jump if so (info filled in)

	test	[ebp].DPMI_FLT_NXT.INTDPF_CS,mask $PL ; What PL faulted?
	setz	es:[ebx].DPMI_FLT10_INFO.LO ; Bit 0 set iff at PL0
	jz	short PMFLTCOM_XINFO ; Jump if so (info filled in)

; If the return CS is DPMI_DEF, it means we have a fault at PL0 which
; we force through as a PL3 fault.  The user must be aware that the
; fault actually occurred in the host.

	push	ax		; Sav for a moment

	mov	ax,DPMI_IDEF	; Get our interrupt selector

	cmp	ax,[ebp].DPMI_FLT_NXT.INTDPF_CS ; Izit back to us?
	pop	ax		; Restore
	setz	es:[ebx].DPMI_FLT10_INFO.LO ; Bit 0 set iff at PL0
PMFLTCOM_XINFO:

; Split cases based upon 16- or 32-bit clients

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	near ptr PMFLTCOM_DPMI_FLT16 ; Jump if so

	test	[ebp].DPMI_FLT_NXT.INTDPF_EFL.EHI,mask $VM ; Izit from VM?
	jnz	short PMFLTCOM32A ; Jump if so

	imul	eax,type PMFLT_FVECS ; Times size of FVECS
	lea	eax,PMFLT_FVECS[eax] ; Get its offset in PGROUP

	jmp	short PMFLTCOM32_COM1 ; Join common code


PMFLTCOM32A:
	imul	eax,type VMFLT_FVECS ; Times size of FVECS
	lea	eax,VMFLT_FVECS[eax] ; Get its offset in PGROUP
PMFLTCOM32_COM1:

; For 32-bit clients, DPMI_FLT10_RET is Ptr 16:32.

	mov	es:[ebx].DPMI_FLT10_RET.FOFF,PMFLPM2 ; Return EIP
	push	DPMI_IDEF	; Get our interrupt selector
	pop	es:[ebx].DPMI_FLT10_RET.FSEL

	mov	es:[ebx].DPMI_FLT32A_REIP,PMFLPM ; Our return EIP
	push	DPMI_IDEF	; Get our interrupt selector
	pop	es:[ebx].DPMI_FLT32A_RCS.ELO ; ... CS

; Put the interrupt address in a 32-bit frame on the PL3 stack

	push	[ebp].DPMI_FLT_NXT.INTDPF_ERR ; Get error code
	pop	es:[ebx].DPMI_FLT32A_ERR

	push	[ebp].DPMI_FLT_NXT.INTDPF_EFL ; ... EFL
	pop	es:[ebx].DPMI_FLT32A_EFL

	push	[ebp].DPMI_FLT_NXT.INTDPF_CS.EDD ; ... CS
	pop	es:[ebx].DPMI_FLT32A_CS.EDD

	push	[ebp].DPMI_FLT_NXT.INTDPF_EIP ; ... EIP
	pop	es:[ebx].DPMI_FLT32A_EIP

	push	[ebp].DPMI_FLT_NXT.INTDPF_ESP ; ... ESP
	pop	es:[ebx].DPMI_FLT32A_ESP

	push	[ebp].DPMI_FLT_NXT.INTDPF_SS.EDD ; ... SS
	pop	es:[ebx].DPMI_FLT32A_SS.EDD

; Put the address to which we're transferring as DPMI_IRETD_STR
; on the MAX stack

DPMI_IRETD_STR struc

DPMI_IRETD_EIP dd ?		; This INT's EIP
DPMI_IRETD_CS  dw ?,?		; ...	     CS w/filler
DPMI_IRETD_EFL dd ?		; ...	     EFL
DPMI_IRETD_ESP dd ?		; ...	     ESP
DPMI_IRETD_SS  dw ?,?		; ...	     SS w/filler

DPMI_IRETD_STR ends

	PUSHD	es			       ; Setup caller's SSF
	push	ebx			       ; ...		ESP
	push	[ebp].DPMI_FLT_NXT.INTDPF_EFL ; ...		EFL
	push	DGROUP:[eax].FSEL.EDD	       ; Use this INT's CSF
	push	DGROUP:[eax].FOFF	       ; Use this INT's EIP

	jmp	PMFLTCOM_IRETDCOM ; Join common code


	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	ds:nothing,gs:nothing ; Tell the assembler about it


	public	PMFLTCOM_LPMFULL
	assume	ds:DGROUP,gs:AGROUP ; Tell the assembler about it
PMFLTCOM_LPMFULL:
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	mov	bx,[ebp].DPMI_FLT_SS0 ; Get previous TSS_SS0
	mov	DGROUP:[eax].TSS_SS0,bx ; Restore

	mov	ebx,[ebp].DPMI_FLT_ESP0 ; Get previous TSS_ESP0
	mov	DGROUP:[eax].TSS_ESP0,ebx ; Restore

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

; If we switched out a TSS, switch it back in

	mov	eax,[ebp].DPMI_FLT_PCURTSS ; Get previous PCURTSS

	xchg	eax,PCURTSS	; Get original TSS, save incoming one
	call	DPMIFN_NESTRET	; Check for nesting return with EAX=old PCURTSS
	assume	es:nothing,fs:nothing,gs:nothing ; Tell the assembler about it

	cmp	[ebp].DPMI_FLT_FLG,@PMINTCOM_LPM ; Did we use the LPM stack?
	jne	short @F	; Jump if not

	dec	LPMSTK_CNT	; Count it out
@@:
	pop	ebp		; Restore

	REGREST <edi,esi,ecx,ebx,eax> ; Restore

	pop	LPMSTK_FVEC.FOFF ; Restore
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

; Because some DPMI clients (pssst, it's Windows 3.10 á 2) may
; invalidate the selectors we carefully pushed onto the stack
; when we handled an interrupt so we can restore them now, we must
; VERR them and zero the invalid ones.

	VERREST <gs,fs,es,ds>	; Restore selectors with VERR
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

	add	esp,(size DPMI_FLT_ESP0) + (size DPMI_FLT_SS0) + \
		     (size DPMI_FLT_PCURTSS) + (size DPMI_FLT_FLG) ; Strip

; The MAX stack contains INTDPF_STR

	jmp	FLTPROC_LPMFULL ; Join common error code


	assume	ds:nothing	; Tell the assembler about it


	assume	ds:DGROUP,gs:AGROUP ; Tell the assembler about it

	public	PMFLTCOM_DPMI_FLT16
PMFLTCOM_DPMI_FLT16:
	test	[ebp].DPMI_FLT_NXT.INTDPF_EFL.EHI,mask $VM ; Izit from VM?
	jnz	short PMFLTCOM16A ; Jump if so

	imul	eax,type PMFLT_DVECS ; Times size of DVECS
	lea	eax,PMFLT_DVECS[eax] ; Get its offset in PGROUP

	jmp	short PMFLTCOM16_COM1 ; Join common code


PMFLTCOM16A:
	imul	eax,type VMFLT_DVECS ; Times size of DVECS
	lea	eax,VMFLT_DVECS[eax] ; Get its offset in PGROUP
PMFLTCOM16_COM1:

; For 16-bit clients, DPMI_FLT10_RET is Ptr 16:16.

	mov	es:[ebx].DPMI_FLT10_RET.VOFF,PMFLPM2 ; Return IP
	push	DPMI_IDEF	; Get our interrupt selector
	pop	es:[ebx].DPMI_FLT10_RET.VSEG
	mov	es:[ebx].DPMI_FLT10_RET.EDQHI.ELO,0 ; Zero 32-bit CS filler

; Put a pseudo-interrupt address in a 16-bit frame on the LPM stack

	mov	es:[ebx].DPMI_FLT16A_RIP,PMFLPM ; Our return IP
	push	DPMI_IDEF	; Get our interrupt selector
	pop	es:[ebx].DPMI_FLT16A_RCS ; ... CS

; Put the interrupt address in a 16-bit frame on the caller's stack

	push	[ebp].DPMI_FLT_NXT.INTDPF_ERR.ELO ; Get error code
	pop	es:[ebx].DPMI_FLT16A_ERR

	push	[ebp].DPMI_FLT_NXT.INTDPF_EFL.ELO ; ... FL
	pop	es:[ebx].DPMI_FLT16A_FL

	push	[ebp].DPMI_FLT_NXT.INTDPF_CS	   ; ... CS
	pop	es:[ebx].DPMI_FLT16A_CS

	push	[ebp].DPMI_FLT_NXT.INTDPF_EIP.ELO ; ... IP
	pop	es:[ebx].DPMI_FLT16A_IP

	push	[ebp].DPMI_FLT_NXT.INTDPF_ESP.ELO ; ... SP
	pop	es:[ebx].DPMI_FLT16A_SP

	push	[ebp].DPMI_FLT_NXT.INTDPF_SS	   ; ... SS
	pop	es:[ebx].DPMI_FLT16A_SS

; Put the address to which we're transferring as DPMI_IRETD_STR
; on the MAX stack

	PUSHD	es			       ; Setup caller's SSF
	push	ebx			       ; ...		ESP
	push	[ebp].DPMI_FLT_NXT.INTDPF_EFL ; ...		EFL
	movzx	ebx,DGROUP:[eax].VSEG	       ; Get this INT's CS
	push	ebx			       ; Pass it as dword
	movzx	ebx,DGROUP:[eax].VOFF	       ; ...		IP
	push	ebx			       ; Pass it as dword

	public	PMFLTCOM_IRETDCOM
PMFLTCOM_IRETDCOM:

;;; ; Protect the PL0 stack at and above the INTDPI_STR by
;;; ; copying it to PLCL_PL0CUR
;;;
;;;	    SETDATA es		    ; Get DGROUP data selector
;;;	    assume  es:DGROUP	    ; Tell the assembler about it
;;;
;;;	    lea     esi,[ebp].DPMI_FLT_PROT ; Copy as source
;;;	    mov     ecx,PPL0STK_MAX ; Get top of PL0 stack
;;;	    sub     ecx,esi	    ; Less source offset
;;;	    jnc     short @F	    ; Jump if OK
;;;
;;;	    SWATMAC ERR 	    ; Call our debugger
;;; @@:
;;;	    mov     [ebp].DPMI_FLT_PL0LEN,ecx ; Save for later use
;;;
;;;	    sub     PLCL_PL0CUR,ecx ; Less length to make room
;;;	    mov     edi,PLCL_PL0CUR ; Get offset in DGROUP of current local PL0 stack
;;;	    mov     DGROUP:[edi-4],ecx ; Save as length of saved stack
;;;	    sub     PLCL_PL0CUR,4   ; Protect it
;;;
;;;	    lea     eax,[ecx+esi]   ; Add to get ending source address
;;;
;;;	    cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	    jbe     short @F	    ; Jump if not
;;;
;;;	    SWATMAC ERR 	    ; Call our debugger
;;; @@:
;;;	    cld 		    ; String ops fowardly
;;; S32 rep movs    <DGROUP:[edi].LO,ss:[esi].LO> ; Copy to local storage

; We're simulating an interrupt to the next handler in sequence
; Ensure VM=RF=NT=IF=TF=0 in the next handler's EFL, and IOPL=@DPMIOPL

	and	[esp].DPMI_IRETD_EFL,not ((mask $VMHI) or (mask $RFHI) \
		or (mask $NT) or (mask $IOPL) or (mask $IF) or (mask $TF))
	or	[esp].DPMI_IRETD_EFL,@DPMIOPL shl $IOPL ; IOPL=@DPMIOPL

	mov	ds,[ebp].DPMI_FLT_DS ; Restore original DS
	assume	ds:nothing	; Tell the assembler about it

	mov	es,[ebp].DPMI_FLT_ES ; ...		 ES
	assume	es:nothing	; Tell the assembler about it

	mov	gs,[ebp].DPMI_FLT_GS ; ...		 GS
	assume	gs:nothing	; Tell the assembler about it

; Restore saved EGP registers

	mov	eax,[ebp].DPMI_FLT_EAX ; Restore
	mov	ebx,[ebp].DPMI_FLT_EBX ; ...
	mov	ecx,[ebp].DPMI_FLT_ECX ; ...
	mov	esi,[ebp].DPMI_FLT_ESI ; ...
	mov	edi,[ebp].DPMI_FLT_EDI ; ...
	mov	ebp,[ebp].DPMI_FLT_EBP ; ...

	iretd			; Call the next handler in sequence (PM only)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PMFLTCOM endp			; End PMFLTCOM procedure
	FPPROC	PMINTCOM -- PM HW/SW Interrupt From DPMI Client
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Protected Mode hardware/special/software interrupt from a DPMI client
(HW-DPMI, SP-DPMI, SW-DPMI), or a hardware or special interrupt from
VM (HW-VM, SP-VM), or a hardware interrupt from MAX (HW-MAX).

The value of DPMI_INT_FLG is @PMINTCOM_NRM for SP-DPMI and SW-DPMI
and @PMINTCOM_LPM for HW-DPMI, HW-VM, HW-MAX, and SP-VM.

If this interrupt came from VM (HW-VM, SP-VM), we need to protect its
stack via LAST_INTCOM.

The MAX stack on entry contains (from bottom up) DPMI_INT_FLG and one
of INTCOM_STR (HW-VM, SP-VM), or INTDPI_STR (HW-DPMI, SP-DPMI,
SW-DPMI), or NRM_STR (HW-MAX).	Note that INTDPI_INTNO is already
filled in with the INT # times 4 + offset PGROUP:INTPROC00Z.

The caller has already determined that a DPMI client has hooked this
interrupt, so we never return from this program.

If the incoming interrupt is HW or SP (but not 1Ch), then we
switch to the primary client because that's what the spec says to do.

The transference of flags from the caller to the client and back is
handled as follows:

Note that the only flags the client sees are its own return flags.
A flag transference can take one of several forms:

0 = forced to 0
3 = forced to 3
P = passed from Caller to Client
NC = Not changed
NA = Not applicable

If the interrupt comes in on the LPM stack (HW-VM, SP-VM, HW-MAX,
HW-DPMI), the caller's flags are handled as follows:

	 Client's Stack   Client's EFL   Caller's Stack
	  Upon Return	   Upon Entry	  Upon Return
------------------------------------------------------------
VM	      0 / NA (16)      0	  NC / NA (16)
RF	      P / NA (16)      0	  P / NC (16)
NT	      P 	       0	  P
IOPL	      3 	       3	  NC
IF	      P 	       0	  P
TF	      P / 0 (LPM)      0	  P / NC (LPM)
Others	      P 	       P	  P

|

DPMI_INT_STR struc

DPMI_INT_EBP dd ?		; PL3 caller's EBP
DPMI_INT_EDI dd ?		; ...	       EDI
DPMI_INT_ESI dd ?		; ...	       ESI
DPMI_INT_ECX dd ?		; ...	       ECX
DPMI_INT_EBX dd ?		; ...	       EBX
DPMI_INT_EAX dd ?		; ...	       EAX

; The portion of this structure below this point *MUST* match
; the corresponding portion of DPMI_INTRET_STR.

DPMI_INT_LPMSTK df ?		; Original LPMSTK_FVEC
		dw ?		; For alignment
DPMI_INT_GS  dd ?		; Caller's GS
DPMI_INT_FS  dd ?		; ...	   FS
DPMI_INT_ES  dd ?		; ...	   ES
DPMI_INT_DS  dd ?		; ...	   DS
DPMI_INT_LIFLG dd ?		; Previous LAST_INTFLG
DPMI_INT_LICOM dd ?		; ...	   LAST_INTCOM
;;; DPMI_INT_PL0LEN dd ?	    ; Length of protected stack
DPMI_INT_ESP0 dd ?		; ...	   TSS_ESP0
DPMI_INT_SS0 dw ?		; ...	   TSS_SS0
DPMI_INT_PCURTSS dd ?		; ...	   PCURTSS
DPMI_INT_FLG dd ?		; @PMINTCOM_LPM or ..._NRM stack usage flag
DPMI_INT_NXT db (size INTDPI_STR) dup (?) ; The rest of the stack

DPMI_INT_STR ends

DPMI_INT_PROT equ <DPMI_INT_LPMSTK> ; Protect the stack above this point

; Allow any PM interrupt handlers to take a crack at this interrupt first

;;;;;;; sub	esp,(size DPMI_INT_PCURTSS) + (size DPMI_INT_SS0)    + \
;;;;;;; 	    (size DPMI_INT_ESP0)    + (size DPMI_INT_PL0LEN) + \
;;;;;;; 	    (size DPMI_INT_LICOM)   + (size DPMI_INT_LIFLG) ; Make room
	sub	esp,(size DPMI_INT_PCURTSS) + (size DPMI_INT_SS0)    + \
		    (size DPMI_INT_ESP0)    + \
		    (size DPMI_INT_LICOM)   + (size DPMI_INT_LIFLG) ; Make room

	REGSAVE <ds,es,fs,gs>	; Save all selectors

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	gs,SEL_4GB	; Get AGROUP data selector
	assume	gs:AGROUP	; Tell the assembler about it

	push	LPMSTK_FVEC.FSEL.EDD ; Save current LPM stack top
	push	LPMSTK_FVEC.FOFF ; ...

	REGSAVE <eax,ebx,ecx,esi,edi> ; Save for a moment

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

; Set new LPM stack top for nested callers if it's active
; and we're called from PM

	lea	eax,[ebp].DPMI_INT_NXT.INTDPI_EIP ; SS:EAX ==> INTDPI_STR from PL3
	push	eax		; Pass the offset
	call	DPMIFN_LPMSTK	; Save new LPM stack as appropriate

	mov	eax,PCURTSS	; Get offset in DGROUP of the current TSS
	mov	[ebp].DPMI_INT_PCURTSS,eax ; Save for later use

; If this is a HW interrupt, switch to the primary client.
; Note that these interrupts are always presented to the
; client on the LPM stack, so we'll have an opportunity to
; switch back to the current client.

	cmp	eax,PPRMTSS	; Izit the primary client?
	je	short PMINTCOM_PRM ; Jump if so

	movzx	eax,[ebp].DPMI_INT_NXT.INTDPI_INTNO ; Get INT # times 4 + ...
	sub	eax,offset PGROUP:INTPROC00Z ; Convert to INT # times 4
	shr	eax,2-0 	; Convert from INT # in bytes to dwords

	bt	DPMI_HW.EDD,eax ; Izit HW?
	jnc	short PMINTCOM_PRM ; Jump if not

	mov	ebx,PPRMTSS	; Get offset in DGROUP of primary TSS

; Switch to this TSS only if it's been initialized.

	test	DGROUP:[ebx].DPTSS_FLAG,mask $DPTSS_INIT ; Has it?
	jz	short PMINTCOM_PRM ; Jump if not

	call	DPMIFN_NESTOUT	; Save the old state and switch to the new one
PMINTCOM_PRM:

; If we're coming from VM, set the MSW and INT 07h IDT entry

	test	[ebp].DPMI_INT_NXT.INTDPI_EFL.EHI,mask $VM ; Izit from VM?
	jz	short @F	; Jump if not

	push	PCURTSS 	; Pass offset in DGROUP of the current TSS
	call	DPMIFN_LMSW	; Put MSW and INT 07h values into effect
@@:
	mov	ax,[ebp].DPMI_INT_DS.ELO ; Get current DS
	mov	NEXT_DPMI_DS,ax ; Save as next value

	mov	ax,[ebp].DPMI_INT_ES.ELO ; Get current ES
	mov	NEXT_DPMI_ES,ax ; Save as next value

	mov	ax,[ebp].DPMI_INT_FS.ELO ; Get current FS
	mov	NEXT_DPMI_FS,ax ; Save as next value

	mov	ax,[ebp].DPMI_INT_GS.ELO ; Get current GS
	mov	NEXT_DPMI_GS,ax ; Save as next value

	movzx	eax,[ebp].DPMI_INT_NXT.INTDPI_INTNO ; Get INT # times 4 + ...
	sub	eax,offset PGROUP:INTPROC00Z ; Convert to INT # times 4
	shr	eax,2-0 	; Convert from INT # in bytes to dwords

; Split cases based upon 16- or 32-bit clients

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	near ptr PMINTCOM_DPMI_INT16 ; Jump if so

	imul	eax,type PMINT_FVECS ; Times size of FVECS

; Setup the caller's stack as in DPMI_INT32A_STR

; Select which stack to use (PL3 or LPM) depending upon DPMI_INT_FLG

	 cmp	 [ebp].DPMI_INT_FLG,@PMINTCOM_NRM ; Use application stack?
	 je	 near ptr PMINTCOM1A ; Jump if so

; Protect the MAX stack up to [ebp].DPMI_INT_PROT
; where we will also save the old values from LAST_INTFLG, LAST_INTCOM,
; TSS_SS0, and TSS_ESP0

; Between the time we change the MAX stack pointer in the TSS
; and we recalculate PL0STK pointers, we can't allow any interruption

	cli			; Disallow interrupts

	push	LAST_INTCOM	; Save to restore later
	pop	[ebp].DPMI_INT_LICOM ; Save to restore later

	push	LAST_INTFLG	; Save to restore later
	pop	[ebp].DPMI_INT_LIFLG ; Save to restore later

; If we came from VM, protect its stack via LAST_INTCOM

	test	[ebp].DPMI_INT_NXT.NRM_EFL.EHI,mask $VM ; Izit VM86 mode?
	jz	short @F	; Jump if not

	lea	ebx,[ebp].DPMI_INT_NXT.INTCOM_EIP ; Get address of frame
	xchg	ebx,LAST_INTCOM ; Swap with the last one
	bts	LAST_INTFLG,$INTCOM_VAL ; Copy previous flag and mark as valid
	adc	ebx,0		; Save previous flag
	mov	[ebp].DPMI_INT_NXT.INTCOM_ICOMLO,bx ; Save to restore later
	shr	ebx,16		; Shift down high-order word
	mov	[ebp].DPMI_INT_NXT.INTCOM_ICOMHI,bx ; Save to restore later
@@:
	mov	ebx,PCURTSS	; Get offset in DGROUP of current TSS

	push	DGROUP:[ebx].TSS_SS0  ; Save old stack selector
	pop	[ebp].DPMI_INT_SS0 ; Save to restore later

	push	DGROUP:[ebx].TSS_ESP0 ; Save pointer to stack top
	pop	[ebp].DPMI_INT_ESP0 ; Save to restore later

	mov	DGROUP:[ebx].TSS_SS0,ss ; Save for next time
	mov	DGROUP:[ebx].TSS_ESP0,ebp ; ...
	add	DGROUP:[ebx].TSS_ESP0,offset DPMI_INT_PROT ; ...

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

; Address PL3 stack

; Note interrupts are disabled over the LPM stack allocation

	les	ebx,LPMSTK_FVEC ; ES:EBX ==> locked protected mode stack
	assume	es:nothing	; Tell the assembler about it

	inc	LPMSTK_CNT	; Count in another one

; If we're executing INT 24h, copy the VM stack parameters to
; the DPMI client's stack as in DPMI_INT24_STR

	call	DPMIFN_CHK24	; Check it out
	jc	near ptr INT24_INTRETPM ; Call the terminator

; Setup the PL3 stack as in DPMI_INT32A_STR

	sub	ebx,size DPMI_INT32A_STR ; Make room on LPM stack
if @EXPD

; If this is a 16-bit stack, zero the high-order word of EBX
; to simulate using BX instead of EBX.

	push	es		; Pass stack selector
	call	DPMIFN_EBXMOD	; Modify high-order word of EBX
				; if stack selector is a 16-bit stack
; Check to see if the resulting offset is within the stack's bounds

	push	es		; Pass stack selector
	push	ebx		; ...	     offset
	call	DPMIFN_CHKSTK	; Check the stack offset
endif
	jc	near ptr PMINTCOM_APPLFULL ; Jump if we overflowed

; Put a pseudo-interrupt address in a 32-bit frame on the LPM stack

	mov	es:[ebx].DPMI_INT32A_EIP,PMILPM ; Save EIP
	push	DPMI_IDEF	; Get our interrupt selector
	pop	es:[ebx].DPMI_INT32A_CS ; ... CS

; Because some DPMI applications expect to obtain control in their
; interrupt handler with the selectors in DS through GS having the
; same value as they had when the application was interrupted, we
; must do the same here.  Note that this action we take is limited
; to the cases where the interrupt handler is for one of the special
; interrupts (HW-xx or SP-xx).

; Because some DPMI clients may invalidate the selectors we
; saw the last time we were called by a DPMI client, we must
; VERR them and zero the invalid ones.

	REGSAVE <LAST_DPMI_FS.EDD,LAST_DPMI_GS.EDD> ; Push 'em onto the stack for VERR
	VERREST <gs,fs> 	; Restore selectors with VERR
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

	push	LAST_DPMI_ES	; Get last valid ES
	VERREST <NEXT_DPMI_ES>	; Restore selector with VERR

	push	LAST_DPMI_DS	; Get last valid DS
	VERREST <NEXT_DPMI_DS>	; Restore selector with VERR

	jmp	short PMINTCOM2A ; Join common code


PMINTCOM1A:

; If the B-bit in the stack selector is clear, zero the upper
; word of the stack offset so we can use it as a dword.

	lea	ebx,[ebp].DPMI_INT_NXT.INTDPI_ESP ; SS:EBX ==> SS|ESP from PL3
	push	ebx		; Pass the offset
	call	DPMIFN_ESPMOD	; Clear the high-order word of the PL3 ESP
				; if the B-bit in the PL3 SS is clear
	les	ebx,[ebp].DPMI_INT_NXT.INTDPI_ESP.EDF ; ES:eBX ==> caller's stack
	assume	es:nothing	; Tell the assembler about it

; Setup the PL3 stack as in DPMI_INT32A_STR

	sub	ebx,size DPMI_INT32A_STR ; Make room on LPM stack
	jc	near ptr PMINTCOM_APPLFULL ; Jump if we overflowed

; Put the interrupt address in a 32-bit frame on the caller's stack

	push	[ebp].DPMI_INT_NXT.INTDPI_EIP ; Get EIP
	pop	es:[ebx].DPMI_INT32A_EIP
	push	[ebp].DPMI_INT_NXT.INTDPI_CS  ; ... CSF
	pop	es:[ebx].DPMI_INT32A_CS
PMINTCOM2A:

; Use caller's flags with VM=0 for the return flags.
; If we're using the application stack, the return is to the point
; following the interrupt in the application code.
; If we're using the LPM stack, the return is to us at PMILPM.

	push	[ebp].DPMI_INT_NXT.INTDPI_EFL ; Get EFL
	and	[esp].EDD,not (mask $VMHI) ; VM=0
	pop	es:[ebx].DPMI_INT32A_EFL

; Put the stack and instruction addresses to which we're transferring
; on the MAX stack as DPMI_IRETD_STR

	PUSHD	es			       ; Setup caller's SSF
	push	ebx			       ; ...		ESP
	push	[ebp].DPMI_INT_NXT.INTDPI_EFL ; ...   EFL
	push	PMINT_FVECS.FSEL.EDD[eax]     ; Use this INT's CSF
	push	PMINT_FVECS.FOFF[eax]	       ; Use this INT's EIP

	jmp	PMINTCOM_IRETDCOM ; Join common code


	assume	ds:nothing,es:nothing ; Tell the assembler about it


	public	PMINTCOM_APPLFULL
	assume	ds:DGROUP,gs:AGROUP ; Tell the assembler about it
PMINTCOM_APPLFULL:
	mov	SAVE_EAX,offset PGROUP:FLTPROC_APPLFULL ; Save adddress

	jmp	short PMINTCOM_FULLCOM ; Join common code


	public	PMINTCOM_LPMFULL
	assume	ds:DGROUP,gs:AGROUP ; Tell the assembler about it
PMINTCOM_LPMFULL:
	mov	SAVE_EAX,offset PGROUP:FLTPROC_LPMFULL ; Save address
PMINTCOM_FULLCOM:
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	mov	bx,[ebp].DPMI_INT_SS0 ; Get previous TSS_SS0
	mov	DGROUP:[eax].TSS_SS0,bx ; Restore

	mov	ebx,[ebp].DPMI_INT_ESP0 ; Get previous TSS_ESP0
	mov	DGROUP:[eax].TSS_ESP0,ebx ; Restore

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

	mov	eax,[ebp].DPMI_INT_LIFLG ; Get previous LAST_INTFLG
	mov	LAST_INTFLG,eax ; Restore

	mov	eax,[ebp].DPMI_INT_LICOM ; Get previous LAST_INTCOM
	mov	LAST_INTCOM,eax ; Restore

	cmp	[ebp].DPMI_INT_FLG,@PMINTCOM_LPM ; Did we use the LPM stack?
	jne	short @F	; Jump if not

	dec	LPMSTK_CNT	; Count it out
@@:

; Switch back to the current TSS if we switched out

	mov	eax,[ebp].DPMI_INT_PCURTSS ; Get original TSS
	xchg	eax,PCURTSS	; Get original TSS, save incoming one
	call	DPMIFN_NESTRET	; Check for nesting return with EAX=old PCURTSS
	assume	es:nothing,fs:nothing,gs:nothing ; Tell the assembler about it

;;; ; Note there's no need to strip PLCL_PL0CUR back as we haven't allocated
;;; ; from it as yet.

	pop	ebp		; Restore

	REGREST <edi,esi,ecx,ebx,eax> ; Restore

	pop	LPMSTK_FVEC.FOFF ; Restore
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

; Because some DPMI clients (pssst, it's Windows 3.10 á 2) may
; invalidate the selectors we carefully pushed onto the stack
; when we handled an interrupt so we can restore them now, we must
; VERR them and zero the invalid ones.

	VERREST <gs,fs,es,ds>	; Restore selectors with VERR
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

; Good ole MASM 5.10B can't handle the following construction if we
; use the line continuation character.

STRIP1	=		  (size DPMI_INT_LIFLG)  + (size DPMI_INT_LICOM)
STRIP1	=	STRIP1 + (size DPMI_INT_ESP0)	 + (size DPMI_INT_SS0)
STRIP1	=	STRIP1 + (size DPMI_INT_PCURTSS) + (size DPMI_INT_FLG)
;;;STRIP1  =	   STRIP1 + (size DPMI_INT_PL0LEN)

	add	esp,STRIP1	; Strip the stack back to INTDPI_STR

; The MAX stack contains INTDPI_STR

	PUSHD	0		; Put pseudo-error code onto stack

; The MAX stack contains INTDPF_STR

	jmp	FLTPROC_LPMFULL ; Join common error code


	assume	ds:nothing	; Tell the assembler about it


	assume	ds:DGROUP,gs:AGROUP ; Tell the assembler about it
PMINTCOM_DPMI_INT16:
	imul	eax,type PMINT_DVECS ; Times size of DVECS

; Setup the caller's stack as in DPMI_INT16A_STR

; Protect the MAX stack up to [ebp].DPMI_INT_PROT
; where we will also save the old values from LAST_INTFLG, LAST_INTCOM,
; TSS_SS0, and TSS_ESP0

; Between the time we change the MAX stack pointer in the TSS
; and we recalculate PL0STK pointers, we can't allow any interruption

	cli			; Disallow interrupts

	push	LAST_INTCOM	; Save to restore later
	pop	[ebp].DPMI_INT_LICOM ; Save to restore later

	push	LAST_INTFLG	; Save to restore later
	pop	[ebp].DPMI_INT_LIFLG ; Save to restore later

; If we came from VM, protect its stack via LAST_INTCOM

	test	[ebp].DPMI_INT_NXT.NRM_EFL.EHI,mask $VM ; Izit VM86 mode?
	jz	short @F	; Jump if not

	lea	ebx,[ebp].DPMI_INT_NXT.INTCOM_EIP ; Get address of frame
	xchg	ebx,LAST_INTCOM ; Swap with the last one
	bts	LAST_INTFLG,$INTCOM_VAL ; Copy previous flag and mark as valid
	adc	ebx,0		; Save previous flag
	mov	[ebp].DPMI_INT_NXT.INTCOM_ICOMLO,bx ; Save to restore later
	shr	ebx,16		; Shift down high-order word
	mov	[ebp].DPMI_INT_NXT.INTCOM_ICOMHI,bx ; Save to restore later
@@:
	mov	ebx,PCURTSS	; Get offset in DGROUP of current TSS

	push	DGROUP:[ebx].TSS_SS0  ; Save old stack selector
	pop	[ebp].DPMI_INT_SS0 ; Save to restore later

	push	DGROUP:[ebx].TSS_ESP0 ; Save pointer to stack top
	pop	[ebp].DPMI_INT_ESP0 ; Save to restore later

	mov	DGROUP:[ebx].TSS_SS0,ss ; Save for next time
	mov	DGROUP:[ebx].TSS_ESP0,ebp ; ...
	add	DGROUP:[ebx].TSS_ESP0,offset DPMI_INT_PROT ; ...

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

; Select which stack to use (PL3 or LPM) depending upon DPMI_INT_FLG.

	cmp	[ebp].DPMI_INT_FLG,@PMINTCOM_NRM ; Use application stack?
	jne	near ptr PMINTCOM1B ; Jump if not

; If the B-bit in the stack selector is clear, zero the upper
; word of the stack offset so we can use it as a dword.

	lea	ebx,[ebp].DPMI_INT_NXT.INTDPI_ESP ; SS:EBX ==> SS|ESP from PL3
	push	ebx		; Pass the offset
	call	DPMIFN_ESPMOD	; Clear the high-order word of the PL3 ESP
				; if the B-bit in the PL3 SS is clear
	les	ebx,[ebp].DPMI_INT_NXT.INTDPI_ESP.EDF ; ES:eBX ==> caller's stack
	assume	es:nothing	; Tell the assembler about it

	jmp	short PMINTCOM2B ; Join common code


PMINTCOM1B:

; Address PL3 stack

; Note interrupts are disabled over the LPM stack allocation

	les	ebx,LPMSTK_FVEC ; ES:EBX ==> locked protected mode stacks
	assume	es:nothing	; Tell the assembler about it

	inc	LPMSTK_CNT	; Count in another one

; If we're executing INT 24h, copy the VM stack parameters to
; the DPMI client's stack as in DPMI_INT24_STR

	call	DPMIFN_CHK24	; Check it out
	jc	near ptr INT24_INTRETPM ; Call the terminator
PMINTCOM2B:

; Setup the PL3 stack as in DPMI_INT16A_STR

	sub	ebx,size DPMI_INT16A_STR ; Make room on LPM stack
if @EXPD

; If this is a 16-bit stack, zero the high-order word of EBX
; to simulate using BX instead of EBX.

	push	es		; Pass stack selector
	call	DPMIFN_EBXMOD	; Modify high-order word of EBX
				; if stack selector is a 16-bit stack
; Check to see if the resulting offset is within the stack's bounds

	push	es		; Pass stack selector
	push	ebx		; ...	     offset
	call	DPMIFN_CHKSTK	; Check the stack offset
endif
	jc	near ptr PMINTCOM_LPMFULL ; Jump if there's no room

; Put a pseudo-interrupt address in a 16-bit frame on the LPM stack

	mov	es:[ebx].DPMI_INT16A_IP,PMILPM ; Save EIP
	push	DPMI_IDEF	; Get our interrupt selector
	pop	es:[ebx].DPMI_INT16A_CS ; ... CS

	cmp	[ebp].DPMI_INT_FLG,@PMINTCOM_NRM ; Use application stack?
	je	near ptr PMINTCOM3B ; Jump if so

; Because some DPMI applications expect to obtain control in their
; interrupt handler with the selectors in DS through GS having the
; same value as they had when the application was interrupted, we
; must do the same here.  Note that this action we take is limited
; to the cases where the interrupt handler is for one of the special
; interrupts (HW-xx or SP-xx).

; Because some DPMI clients may invalidate the selectors we
; saw the last time we were called by a DPMI client, we must
; VERR them and zero the invalid ones.

	REGSAVE <LAST_DPMI_FS.EDD,LAST_DPMI_GS.EDD> ; Push 'em onto the stack for VERR
	VERREST <gs,fs> 	; Restore selectors with VERR
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

	push	LAST_DPMI_ES	; Get last valid ES
	VERREST <NEXT_DPMI_ES>	; Restore selector with VERR

	push	LAST_DPMI_DS	; Get last valid DS
	VERREST <NEXT_DPMI_DS>	; Restore selector with VERR
PMINTCOM3B:
	push	[ebp].DPMI_INT_NXT.INTDPI_EFL.ELO ; Get FL
	pop	es:[ebx].DPMI_INT16A_FL

; Put the address to which we're transferring
; on the MAX stack as DPMI_IRETD_STR

	PUSHD	es			       ; Setup caller's SSF
	push	ebx			       ; ...		ESP
	push	[ebp].DPMI_INT_NXT.INTDPI_EFL ; ...		EFL
	and	[esp].EDD,not (mask $IOPL)    ; Clear IOPL bits
	or	[esp].EDD,@DPMIOPL shl $IOPL  ; IOPL=@DPMIOPL
	movzx	ebx,PMINT_DVECS.VSEG[eax]     ; Get this INT's CS
	push	ebx			       ; Pass as dword
	movzx	ebx,PMINT_DVECS.VOFF[eax]     ; ...		IP
	push	ebx			       ; Pass as dword
PMINTCOM_IRETDCOM:

;;; ; Protect the PL0 stack at and above [ebp].DPMI_INT_PROT
;;; ; by copying it to PLCL_PL0CUR
;;;
;;;	    SETDATA es		    ; Get DGROUP data selector
;;;	    assume  es:DGROUP	    ; Tell the assembler about it
;;;
;;;	    lea     esi,[ebp].DPMI_INT_PROT ; Copy as source
;;;	    mov     ecx,PPL0STK_MAX ; Get top of PL0 stack
;;;	    sub     ecx,esi	    ; Less source offset
;;;	    mov     [ebp].DPMI_INT_PL0LEN,ecx ; Save for later use
;;;
;;;	    sub     PLCL_PL0CUR,ecx ; Less length to make room
;;;	    mov     edi,PLCL_PL0CUR ; Get offset in DGROUP of current local PL0 stack
;;;	    mov     DGROUP:[edi-4],ecx ; Save as length of saved stack
;;;	    sub     PLCL_PL0CUR,4   ; Protect it
;;;
;;;	    lea     eax,[ecx+esi]   ; Add to get ending source address
;;;
;;;	    cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	    jbe     short @F	    ; Jump if not
;;;
;;;	    SWATMAC ERR 	    ; Call our debugger
;;; @@:
;;;	    cld 		    ; String ops fowardly
;;; S32 rep movs    <DGROUP:[edi].LO,ss:[esi].LO> ; Copy to local storage

COMMENT|

We're simulating an interrupt to the next handler in sequence
Ensure VM=RF=NT=TF=0 in the next handler's EFL, and IOPL=@DPMIOPL

Furthermore, as the DPMI spec says, the Interrupt Flag is handled
specially for interrupts which come through here.  In particular, HW
and SP interrupts as well as SW INTs 00h-07h clear IF, all others
leave it alone.

|

	cmp	[ebp].DPMI_INT_FLG,@PMINTCOM_LPM ; Izit the LPM stack?
				; (this picks up HW and SP interrupts)
	je	short PMINTCOM_CLI ; Jump if so (clear IF)

; Check for SW INTs 00h-07h

	cmp	[ebp].DPMI_INT_NXT.INTDPI_INTNO,4*07h+offset PGROUP:INTPROC00Z ; Izit INTs 00h-07h?
	ja	short @F	; Jump if not
PMINTCOM_CLI:
	and	[esp].DPMI_IRETD_EFL,not (mask $IF) ; IF=0
@@:
	and	[esp].DPMI_IRETD_EFL,not ((mask $VMHI) or (mask $RFHI) \
		or (mask $NT) or (mask $IOPL) or (mask $TF))
	or	[esp].DPMI_IRETD_EFL,@DPMIOPL shl $IOPL ; IOPL=@DPMIOPL

	mov	gs,NEXT_DPMI_GS ; Restore
	assume	gs:nothing	; Tell the assembler about it

	mov	es,NEXT_DPMI_ES ; Restore
	assume	es:nothing	; Tell the assembler about it

	mov	ds,NEXT_DPMI_DS ; Restore
	assume	ds:nothing	; Tell the assembler about it

	mov	eax,[ebp].DPMI_INT_EAX ; Restore
	mov	ebx,[ebp].DPMI_INT_EBX ; ...
	mov	ecx,[ebp].DPMI_INT_ECX ; ...
	mov	esi,[ebp].DPMI_INT_ESI ; ...
	mov	edi,[ebp].DPMI_INT_EDI ; ...
	mov	ebp,[ebp].DPMI_INT_EBP ; ...

	iretd			; Call the next handler in sequence (PM only)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PMINTCOM endp			; End PMINTCOM procedure
	NPPROC	DPMIFN_CHK24 -- Setup Stack For INT 24h If Present
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

If we're executing INT 24h, copy the VM stack parameters to
the DPMI client's stack as in DPMI_INT24_STR

On entry:

SS:EBP	==>	DPMI_INT_STR
ES:EBX	==>	LPM stack

On exit:

CF	=	0 if successful
ES:EBX	==>	LPM stack updated

CF	=	1 if not successful

|

	cmp	[ebp].DPMI_INT_NXT.NRM_INTNO,4*24h+offset PGROUP:INTPROC00Z
	clc			; In case we exit
	jne	near ptr DPMIFN_CHK24_EXIT ; Jump if not (note CF=0)

; Perform sanity check

	test	[ebp].DPMI_INT_NXT.NRM_EFL.EHI,mask $VM ; Izit from VM?
	jz	short DPMIFN_CHK24_EXIT ; Jump if not (note CF=0)

; Setup the PL3 stack as in DPMI_INT24_STR

	sub	ebx,size DPMI_INT24_STR ; Make room on LPM stack
	jc	short DPMIFN_CHK24_EXIT ; Jump if no room (note CF=1)

	REGSAVE <ax,ecx,esi,edi,ds> ; Save for a moment

	mov	esi,PCURTSS	; Get offset in DGROUP of the current TSS
	mov	esi,DGROUP:[esi].DPTSS_LaHPDA ; Get linear address of the HPDA

	mov	ds,SEL_4GB	; Get our all memory selector
	assume	ds:AGROUP	; Tell the assembler about it

	movzx	esi,[ebp].DPMI_INT_NXT.INTCOM_SS ; Get SS from VM
	shl	esi,4-0 	; Convert from paras to bytes
	movzx	ecx,[ebp].DPMI_INT_NXT.INTCOM_ESP.ELO ; Get SP from VM
	add	esi,ecx 	; DS:ESI ==> VM caller's stack

	mov	edi,ebx 	; ES:EDI ==> LPM stack

	mov	ecx,(size DPMI_INT24_STR)/2 ; Get # words to copy
	cld			; String ops fowardly
S32 rep movs	<es:[edi].ELO,AGROUP:[esi].ELO> ; Copy 'em

; Translate the BP register from VM to a selector
; This register is restored from the value in DPTSS_I24BP.

	push	bx		; Save for a moment
	mov	bx,[ebp].DPMI_INT_EBP.ELO ; Get the segment #
	DPMICALL0 @DPMI_SEG2SEL ; Translate it
	pop	bx		; Restore
	jc	short @F	; Jump if something went wrong (note CF=1)

	mov	[ebp].DPMI_INT_EBP.ELO,ax ; Save the selector
@@:
	REGREST <ds,edi,esi,ecx,ax> ; Restore
	assume	ds:nothing	; Tell the assembler about it
				; Return with CF significant
DPMIFN_CHK24_EXIT:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_CHK24 endp		; End DPMIFN_CHK24 procedure
;;;	     NPPROC  DPMI_REFINT -- Reflect An Interrupt To VM
;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;; COMMENT|
;;;
;;; Reflect an interrupt to VM from a variety of sources:  HW-VM, SP-VM,
;;; HW-DPMI, HW-MAX, SP-DPMI, SW-DPMI.
;;;
;;; If in PMINTCOM we used the LPM stack (HW-VM, SP-VM, HW-DPMI, HW-MAX),
;;; the MAX stack on entry contains (from bottom up) DPMI_INTRET_STR, and
;;; one of INTCOM_STR (HW-VM, SP-VM), or INTDPI_STR (HW-DPMI), or NRM_STR
;;; (HW-MAX) each from the original interrupt.
;;;
;;; If in PMINTCOM we used the application stack (SP-DPMI, SW-DPMI), the
;;; MAX stack on entry contains (from bottom up) INTDPI_STR.
;;;
;;; The MAX stack is further protected at this point by pushing onto it
;;; the current values of TSS_SS0 and TSS_ESP0 and pointing the new values
;;; to the previous ones.
;;;
;;; By comparing LAST_INTCOM with ESP + size DPMI_INTRET2_STR, we can tell
;;; whether or not the interruption came from VM.  If it came from VM, we
;;; use the SS:SP in that frame to reflect the interrupt to VM; otherwise,
;;; we allocate a stack from the HPDA.
;;;
;;; The interrupt is reflected to VM with a return address which allows us
;;; to regain control.	Upon return from VM, the MAX stack contains
;;; INTCOM_STR followed by previously protected MAX stack.  The flags in
;;; INTCOM_EFL are copied to the original interrupted code's EFL.  If the
;;; original interruption was in VM, we also copy the values of the
;;; segment registers to the original VM frame.  The MAX stack is stripped
;;; back to the previously protected point, the previous TSS_ESP0 and
;;; TSS_SS0 are popped and restored to the TSS, and we IRETD to the
;;; address at this point.  This returns us to the DPMI code in MAX which
;;; IRET/Ds to the address on the DPMI stack.  That returns us to PMILPM
;;; which cleans up the LPM stack.
;;;
;;; On entry:
;;;
;;; IF	     =	     0 (from DPMI_INTRET)
;;;
;;; |
;;;
;;;	     push    ds 	    ; Save for a moment
;;;
;;;	     SETDATA ds 	    ; Get DGROUP data selector
;;;	     assume  ds:DGROUP	    ; Tell the assembler about it
;;;
;;;	     pop     SAVE_DS	    ; Save to restore later
;;;
;;;	     mov     SAVE_EAX,eax   ; Save to restore later
;;;	     mov     SAVE_EBX,ebx   ; ...
;;;	     mov     SAVE_ECX,ecx   ; ...
;;;	     mov     SAVE_ESI,esi   ; ...
;;;	     mov     SAVE_EDI,edi   ; ...
;;;	     mov     SAVE_EBP,ebp   ; ...
;;;
;;; ; Protect the MAX stack up to new LAST_INTFLG (set below)
;;; ; where we will also save the old values from TSS_SS0 and TSS_ESP0
;;;
;;; ; Between the time we change the MAX stack pointer in the TSS
;;; ; and we recalculate PL0STK pointers, we can't allow any interruption
;;;
;;; ;;;;;;;; cli		    ; Disallow interrupts (already disabled)
;;;
;;;	     mov     eax,PCURTSS    ; Get offset in DGROUP of current TSS
;;;	     push    DGROUP:[eax].TSS_SS0  ; Save old stack selector
;;;	     push    DGROUP:[eax].TSS_ESP0 ; Save old pointer to stack top
;;;
;;;	     push    LAST_INTCOM    ; Save old LAST_INTCOM
;;;	     push    LAST_INTFLG    ; ...and its flag
;;;	     PUSHD   0		    ; Make room for DPMI_INTRET1_PL0LEN
;;;
;;;	     REGSAVE <SAVE_DS,es,fs,gs>  ; Save selectors to restore when we return
;;;
;;;	     mov     gs,SEL_4GB     ; Get AGROUP data selector
;;;	     assume  gs:AGROUP	    ; Tell the assembler about it
;;;
;;;	     mov     DGROUP:[eax].TSS_SS0,ss ; Save for next time
;;;	     mov     DGROUP:[eax].TSS_ESP0,esp ; ...
;;;
;;; ; Recalculate PL0STK pointers
;;;
;;;	     call    SET_PPL0STK    ; Set PPL0STK... pointers
;;;
;;; DPMI_INTRET1_STR struc
;;;
;;; DPMI_INTRET1_GS dd ?	    ; Caller's GS
;;; DPMI_INTRET1_FS dd ?	    ; ...      FS
;;; DPMI_INTRET1_ES dd ?	    ; ...      ES
;;; DPMI_INTRET1_DS dd ?	    ; ...      DS
;;; DPMI_INTRET1_PL0LEN dd ?	    ; Length of protected stack
;;; DPMI_INTRET1_LIFLG dd ?	    ; Previous LAST_INTFLG
;;; DPMI_INTRET1_LICOM dd ?	    ; Previous LAST_INTCOM
;;; DPMI_INTRET1_ESP0 dd ?	    ; Previous TSS_ESP0
;;; DPMI_INTRET1_SS0  dw ?	    ; ...      TSS_SS0
;;; DPMI_INTRET1_NXT db (size DPMI_INTRET_STR) dup (?) ; The rest of the stack
;;;
;;; DPMI_INTRET1_STR ends
;;;
;;;
;;; DPMI_INTRET2_STR struc
;;;
;;; DPMI_INTRET2_VM db (size INTCOM_STR) dup (?) ; VM interrupt structure
;;; DPMI_INTRET2_PM db (size DPMI_INTRET1_STR) dup (?) ; PM ...
;;;
;;; DPMI_INTRET2_STR ends
;;;
;;; DPMI_INTRET2_PROT equ <DPMI_INTRET2_PM> ; Protect the stack above this point
;;;
;;;	     sub     esp,size INTCOM_STR ; Make room for VM interrupt structure
;;;	     mov     ebp,esp	    ; SS:EBP ==> DPMI_INTRET2_STR
;;;
;;; ; The MAX stack is mapped by DPMI_INTRET2_STR
;;; ; If we used the application stack in PMINTCOM, then DPMI_INTRET_STR
;;; ; is valid up to and including DPMI_INTRET_SS only.
;;;
;;; ; Setup VM interrupt structure to reflect this interrupt to VM
;;;
;;;	     mov     ax,[ebp].DPMI_INTRET2_PM.DPMI_INTRET1_NXT.DPMI_INTRET_IDEF ; Get 4 * INT # + offset ...
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_INTNO,ax ; Save it
;;;
;;; ; Use the IF from the flags from the DPMI stack
;;; ; along with the other flags from DPMI_INTRET_EFL
;;;
;;;	     mov     eax,[ebp].DPMI_INTRET2_PM.DPMI_INTRET1_NXT.DPMI_INTRET_EFL ; Get caller's EFL
;;;	     or      eax,(mask $VMHI) or (@VMIOPL shl $IOPL) ; VM=1, IOPL=@VMIOPL
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_EFL,eax ; Save in VM stack
;;;
;;; ; Setup our return address in VM
;;;
;;;	     mov     eax,PCURTSS    ; Get offset in DGROUP of current TSS
;;;	     mov     ax,DGROUP:[eax].DPTSS_HPDASEG ; Get segment of HPDA
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_CS,ax ; Save return CS
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_EIP,offset HPDA_REFRET ; Save return offset
;;;
;;; ; Split cases depending upon whether or not we were interrupted from VM
;;;
;;;	     mov     ebx,[ebp].DPMI_INTRET2_PM.DPMI_INTRET1_LICOM ; Get offset of previous LAST_INTCOM
;;;	     lea     eax,[ebp+(size DPMI_INTRET2_STR)] ; Get putative offset
;;;
;;;	     cmp     eax,ebx		    ; Izit the same (and thus valid)?
;;;	     je      near ptr DPMI_REFINT_VM ; Jump if coming from VM
;;;
;;; ; Zero segment registers
;;;
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_GS,0 ; Zero GS
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_FS,0 ; ...  FS
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_DS,0 ; ...  DS
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_ES,0 ; ...  ES
;;;
;;; ; Allocate stack from HPDA
;;; ; Note interrupts are disabled
;;;
;;;	     mov     eax,PCURTSS    ; Get offset in DGROUP of current TSS
;;;
;;;	     movzx   ebx,DGROUP:[eax].DPTSS_VMSTKOFF ; Get current offset
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_ESP,ebx ; Save as new ESP
;;;
;;;	     sub     bx,@HPDAFRM_SIZ ; Make room for a level
;;;
;;;	     cmp     bx,DGROUP:[eax].DPTSS_VMSTKBOT ; Izit below the bottom?
;;;	     jb      short DPMI_REFINT_VMFULL ; Jump if so
;;;
;;;	     mov     DGROUP:[eax].DPTSS_VMSTKOFF,bx ; Make room for a level
;;;
;;;	     mov     ax,DGROUP:[eax].DPTSS_VMSTKSEG ; Get stack segment
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_SS,ax ; Save as new SS
;;;
;;;	     jmp     DPMI_REFINT_COM ; Join common code
;;;
;;;
;;; ; The VM stack overflowed
;;;
;;; DPMI_REFINT_VMFULL:
;;;	     mov     ax,[ebp].DPMI_INTRET2_VM.INTCOM_INTNO ; Get INT # * 4 + ...
;;;	     mov     [ebp].DPMI_INTRET2_PM.DPMI_INTRET1_NXT.DPMI_INTRET_IDEF,ax ; Restore
;;;
;;;	     mov     eax,PCURTSS    ; Get offset in DGROUP of current TSS
;;;
;;;	     mov     bx,[ebp].DPMI_INTRET2_PM.DPMI_INTRET1_SS0 ; Get previous TSS_SS0
;;;	     mov     DGROUP:[eax].TSS_SS0,bx ; Restore
;;;
;;;	     mov     ebx,[ebp].DPMI_INTRET2_PM.DPMI_INTRET1_ESP0 ; Get previous TSS_ESP0
;;;	     mov     DGROUP:[eax].TSS_ESP0,ebx ; Restore
;;;
;;; ; Recalculate PL0STK pointers
;;;
;;;	     call    SET_PPL0STK    ; Set PPL0STK... pointers
;;;
;;;	     mov     eax,[ebp].DPMI_INTRET2_PM.DPMI_INTRET1_LIFLG ; Get previous LAST_INTFLG
;;;	     mov     LAST_INTFLG,eax ; Restore
;;;
;;;	     mov     eax,[ebp].DPMI_INTRET2_PM.DPMI_INTRET1_LICOM ; Get previous LAST_INTCOM
;;;	     mov     LAST_INTCOM,eax ; Restore
;;;
;;;	     mov     ds,[ebp].DPMI_INTRET2_PM.DPMI_INTRET1_DS ; Restore caller's DS
;;;	     mov     es,[ebp].DPMI_INTRET2_PM.DPMI_INTRET1_ES ; ...		 ES
;;;	     mov     fs,[ebp].DPMI_INTRET2_PM.DPMI_INTRET1_FS ; ...		 FS
;;;	     mov     gs,[ebp].DPMI_INTRET2_PM.DPMI_INTRET1_GS ; ...		 GS
;;;
;;; ; Restore saved registers
;;;
;;;	     mov     eax,SAVE_EAX   ; Restore
;;;	     mov     ebx,SAVE_EBX   ; ...
;;;	     mov     ecx,SAVE_ECX   ; ...
;;;	     mov     esi,SAVE_ESI   ; ...
;;;	     mov     edi,SAVE_EDI   ; ...
;;;	     mov     ebp,SAVE_EBP   ; ...
;;;
;;;	     add     esp,DPMI_INTRET2_PM.DPMI_INTRET1_NXT ; Strip back to DPMI_INTRET_STR
;;;
;;; ; The MAX stack contains INTDPI_STR
;;;
;;;	     PUSHD   0		    ; Put pseudo-error code onto stack
;;;
;;; ; The MAX stack contains INTDPF_STR
;;;
;;;	     jmp     FLTPROC_VMFULL ; Join common error code
;;;
;;;
;;;	     assume  ds:nothing,es:nothing ; Tell the assembler about it
;;;	     assume  fs:nothing,gs:nothing ; Tell the assembler about it
;;;
;;;
;;; ; We came from VM -- use same segment registers and stack
;;;
;;;	     assume  ds:DGROUP,gs:AGROUP ; Tell the assembler about it
;;; DPMI_REFINT_VM:
;;;	     mov     ax,ss:[ebx].INTCOM_GS ; Get GS from VM
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_GS,ax ; Save it
;;;
;;;	     mov     ax,ss:[ebx].INTCOM_FS ; Get FS from VM
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_FS,ax ; Save it
;;;
;;;	     mov     ax,ss:[ebx].INTCOM_DS ; Get DS from VM
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_DS,ax ; Save it
;;;
;;;	     mov     ax,ss:[ebx].INTCOM_ES ; Get ES from VM
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_ES,ax ; Save it
;;;
;;;	     mov     ax,ss:[ebx].INTCOM_SS ; Get SS from VM
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_SS,ax ; Save it
;;;
;;;	     mov     eax,ss:[ebx].INTCOM_ESP ; Get ESP from VM
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_ESP,eax ; Save it
;;; DPMI_REFINT_COM:
;;;
;;; ; Point LAST_INTCOM to this stack in case there's any
;;; ; further interrupt activity
;;;
;;;	     lea     eax,[ebp].DPMI_INTRET2_VM.INTCOM_EIP ; Get offset of new stack frame
;;;	     xchg    eax,LAST_INTCOM ; Swap with the previous one
;;;	     bts     LAST_INTFLG,$INTCOM_VAL ; Copy previous flag and mark as valid
;;;	     adc     eax,0	    ; Save previous flag
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_ICOMLO,ax ; Save to restore later
;;;	     shr     eax,16	    ; Shift down high-order word
;;;	     mov     [ebp].DPMI_INTRET2_VM.INTCOM_ICOMHI,ax ; Save to restore later
;;;
;;; ; Protect the PL0 stack up to [ebp].DPMI_INTRET2_PROT
;;; ; by copying it to PLCL_PL0CUR
;;;
;;;	     SETDATA es 	    ; Get DGROUP data selector
;;;	     assume  es:DGROUP	    ; Tell the assembler about it
;;;
;;;	     lea     esi,[ebp].DPMI_INTRET2_PROT ; Copy as source
;;;	     mov     ecx,PPL0STK_MAX ; Get top of PL0 stack
;;;	     sub     ecx,esi	    ; Less source offset
;;;	     mov     [ebp].DPMI_INTRET2_PM.DPMI_INTRET1_PL0LEN,ecx ; Save for later use
;;;
;;;	     sub     PLCL_PL0CUR,ecx ; Less length to make room
;;;	     mov     edi,PLCL_PL0CUR ; Get offset in DGROUP of current local PL0 stack
;;;	     mov     DGROUP:[edi-4],ecx ; Save as length of saved stack
;;;	     sub     PLCL_PL0CUR,4  ; Protect it
;;;
;;;	     lea     eax,[ecx+esi]  ; Add to get ending source address
;;;
;;;	     cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	     jbe     short @F	    ; Jump if not
;;;
;;;	     SWATMAC ERR	    ; Call our debugger
;;; @@:
;;;	     cld		    ; String ops fowardly
;;; S32  rep movs    <DGROUP:[edi].LO,ss:[esi].LO> ; Copy to local storage
;;;
;;; ; Because some MMs might be sensitive to the incoming ESP, setup
;;; ; the stack so that it looks just like it occurred in VM by copying
;;; ; VM stack frame up to the top of the stack
;;;
;;;	     mov     edi,PPL0STK_MAX ; Get top of PL0 stack
;;;	     mov     ecx,type INTCOM_STR ; Get the size of the VM stack frame
;;;	     lea     esi,[ebp].DPMI_INTRET2_VM ; Copy as source
;;;	     add     esi,ecx	    ; Skip to the end
;;;	     dec     edi	    ; Back off to starting byte
;;;	     dec     esi	    ;
;;;
;;;	     mov     ax,ss	    ; Copy stack selector
;;;	     mov     es,ax	    ; Address it
;;;	     assume  es:nothing     ; Tell the assembler about it
;;;
;;;	     std		    ; String ops backwards
;;; S32  rep movs    <es:[edi].LO,ss:[esi].LO> ; Copy to VM stack frame
;;;	     cld		    ; Restore
;;;	     lea     esp,[edi+1]    ; Strip the stack
;;;
;;; ; Restore saved registers
;;;
;;;	     mov     eax,SAVE_EAX   ; Restore
;;;	     mov     ebx,SAVE_EBX   ; ...
;;;	     mov     ecx,SAVE_ECX   ; ...
;;;	     mov     esi,SAVE_ESI   ; ...
;;;	     mov     edi,SAVE_EDI   ; ...
;;;	     mov     ebp,SAVE_EBP   ; ...
;;;
;;;	     push    PVMTSS	    ; Pass offset in DGROUP of the 1st TSS
;;;	     call    DPMIFN_LMSW    ; Put MSW and INT 07h values into effect
;;;
;;; ;;;;;;;; mov     ds,SAVE_DS     ; Restore
;;; ;;;;;;;; assume  ds:nothing     ; Tell the assembler about it
;;; ;;;;;;;;
;;;	     jmp     INTCOM_DPMI_CHKRET ; Join common code
;;;
;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;
;;; DPMI_REFINT endp		    ; End DPMI_REFINT procedure
;;;	     NPPROC  DPMI_REFRET -- Return From Reflecting An Interrupt To VM
;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;; COMMENT|
;;;
;;; Return from reflecting an interrupt to VM.
;;;
;;; Upon return from VM, the MAX stack contains INTCOM_STR, a pseudo
;;; return code, and the previously protected MAX stack.
;;;
;;; By comparing LAST_INTCOM with ESP + size DPMI_REFRET_STR, we can tell
;;; whether or not the interruption came from VM.  If it came from VM, we
;;; copy the values of the segment registers to the original VM frame;
;;; otherwise, we de-allocate a stack from the HPDA.
;;;
;;; The flags in INTCOM_EFL are copied to the original interrupted code's
;;; EFL.
;;;
;;; The MAX stack is stripped back to the previously protected point, the
;;; previous TSS_ESP0 and TSS_SS0 are popped and restored to the TSS, and
;;; we IRETD to the address at this point.  This returns us to the DPMI
;;; code in MAX which IRET/Ds to the address on the DPMI stack.  That
;;; returns us to PMILPM which cleans up the LPM stack.
;;;
;;; On entry:
;;;
;;; SS:EBP   ==>     DPMI_REFRET_STR
;;; IF	     =	     0 (from DPMI_SIMRET from INT&@PMH_INT)
;;;
;;; |
;;;
;;; DPMI_REFRET_STR struc
;;;
;;; DPMI_REFRET_EGP db (size PUSHAD_STR) dup (?) ; Caller's EGP registers
;;; DPMI_REFRET_ERR dd ?	    ; Pseudo-error code
;;; DPMI_REFRET_NXT db (size DPMI_INTRET2_STR) dup (?) ; The rest of the stack
;;;
;;; DPMI_REFRET_STR ends
;;;
;;;	     SETDATA ds 	    ; Get DGROUP data selector
;;;	     assume  ds:DGROUP	    ; Tell the assembler about it
;;;
;;; ; Move the current PL0 stack down to where it would be
;;; ; had the CPU used the TSS_ESP0 we calculated.
;;;
;;;	     mov     edi,PPL0STK_MAX ; Get maximum stack offset
;;;	     mov     esi,PLCL_PL0CUR ; Get offset in DGROUP of current local stack
;;;	     sub     edi,DGROUP:[esi] ; Less length of saved stack
;;;	     mov     ecx,(size DPMI_REFRET_STR) - (size DPMI_INTRET1_STR) ; Get length of PL0 stack to move down
;;;	     sub     edi,ecx	    ; Less length of move
;;;	     mov     esi,esp	    ; Get source offset
;;;	     mov     esp,edi	    ; Back off to that offset
;;;	     mov     ebp,esp	    ; ...
;;;
;;;	     lea     eax,[ecx+esi]  ; Add to get ending source address
;;;
;;;	     cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	     jbe     short @F	    ; Jump if not
;;;
;;;	     SWATMAC ERR	    ; Call our debugger
;;; @@:
;;;	     lea     eax,[ecx+edi]  ; Add to get ending destin address
;;;
;;;	     cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	     jbe     short @F	    ; Jump if not
;;;
;;;	     SWATMAC ERR	    ; Call our debugger
;;; @@:
;;;	     mov     ax,ss	    ; Copy stack selector
;;;	     mov     es,ax	    ; Address it
;;;	     assume  es:nothing     ; Tell the assembler about it
;;;
;;;	     cld		    ; String ops fowardly
;;; S32  rep movs    <es:[edi].LO,ss:[esi].LO> ; Copy the stack down
;;;
;;; ; Restore the original PL0 stack from PLCL_PL0CUR
;;; ; Get length of saved stack
;;;
;;;	     mov     esi,PLCL_PL0CUR ; Get offset in DGROUP of current local stack
;;;	     mov     ecx,DGROUP:[esi] ; Get over length of saved stack
;;;	     jecxz   DPMI_REFRET_DMS ; Jump if we're at the deadman's switch
;;;
;;;	     add     esi,4	    ; Skip over length of saved stack
;;;
;;;	     lea     eax,[ecx+edi]  ; Add to get ending destin address
;;;
;;;	     cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	     jbe     short @F	    ; Jump if not
;;;
;;;	     SWATMAC ERR	    ; Call our debugger
;;; @@:
;;; ;;;;;;;; cld		    ; String ops fowardly
;;; S32  rep movs    <es:[edi].LO,DGROUP:[esi].LO> ; Copy the stack down
;;; DPMI_REFRET_DMS:
;;;	     mov     PLCL_PL0CUR,esi ; Strip from storage
;;;
;;; ; The flags in INTCOM_EFL from the return are to be returned to
;;; ; the caller, except for VM and IOPL and which should remain the
;;; ; same as the caller's.
;;;
;;; FLMASK   =	     ((mask $VMHI) or (mask $IOPL))
;;;
;;;	     mov     eax,[ebp].DPMI_REFRET_NXT.DPMI_INTRET2_VM.INTCOM_EFL ; Get EFL from VM
;;;	     and     eax,not FLMASK ; VM=IOPL=0
;;;	     and     [ebp].DPMI_REFRET_NXT.DPMI_INTRET2_PM.DPMI_INTRET1_NXT.DPMI_INTRET_EFL,FLMASK ; Isolate
;;;	     or      [ebp].DPMI_REFRET_NXT.DPMI_INTRET2_PM.DPMI_INTRET1_NXT.DPMI_INTRET_EFL,eax ; Include
;;;
;;; ; Split cases depending upon whether or not we were interrupted from VM
;;;
;;;	     mov     ebx,[ebp].DPMI_REFRET_NXT.DPMI_INTRET2_PM.DPMI_INTRET1_LICOM ; Get offset of previous LAST_INTCOM
;;;	     lea     eax,[ebp+(size DPMI_REFRET_STR)] ; Get putative offset
;;;
;;;	     cmp     eax,ebx	    ; Izit the same (and thus valid)?
;;;	     je      short DPMI_REFRET_VM ; Jump if coming from VM
;;;
;;; ; De-allocate stack from HPDA
;;;
;;;	     mov     eax,PCURTSS    ; Get offset in DGROUP of current TSS
;;;	     add     DGROUP:[eax].DPTSS_VMSTKOFF,@HPDAFRM_SIZ ; Strip off a level
;;;
;;;	     jmp     short DPMI_REFRET_COM ; Join common code
;;;
;;;
;;; ; We came from VM -- copy the segment registers to the
;;; ; interrupted routine's stack frame
;;;
;;; DPMI_REFRET_VM:
;;;	     mov     ax,[ebp].DPMI_REFRET_NXT.DPMI_INTRET2_VM.INTCOM_GS ; Get GS from VM
;;;	     mov     ss:[ebx].INTCOM_GS,ax ; Save it
;;;
;;;	     mov     ax,[ebp].DPMI_REFRET_NXT.DPMI_INTRET2_VM.INTCOM_FS ; Get FS from VM
;;;	     mov     ss:[ebx].INTCOM_FS,ax ; Save it
;;;
;;;	     mov     ax,[ebp].DPMI_REFRET_NXT.DPMI_INTRET2_VM.INTCOM_DS ; Get DS from VM
;;;	     mov     ss:[ebx].INTCOM_DS,ax ; Save it
;;;
;;;	     mov     ax,[ebp].DPMI_REFRET_NXT.DPMI_INTRET2_VM.INTCOM_ES ; Get ES from VM
;;;	     mov     ss:[ebx].INTCOM_ES,ax ; Save it
;;; DPMI_REFRET_COM:
;;;	     popad		    ; Restore all EGP registers
;;;
;;; ; Restore the previous selectors, LAST_INTFLG, LAST_INTCOM, and
;;; ; TSS_ESP0 and TSS_SS0 to the TSS
;;;
;;;	     add     esp,(size DPMI_REFRET_ERR)+(size INTCOM_STR) ; Strip from the
;;;				    ; stack to previous selectors, LAST_INTFLG,
;;;				    ; LAST_INTCOM, TSS_ESP0, and TSS_SS0
;;;
;;; ; Because some DPMI clients (pssst, it's Windows 3.10 á 2) may
;;; ; invalidate the selectors we carefully pushed onto the stack
;;; ; when we handled an interrupt so we can restore them now, we must
;;; ; VERR them and zero the invalid ones.
;;;
;;;	     VERREST <gs,fs,es,ds>  ; Restore selectors with VERR
;;;	     assume  ds:nothing,es:nothing ; Tell the assembler about it
;;;	     assume  fs:nothing,gs:nothing ; Tell the assembler about it
;;;
;;; ; Between the time we change the MAX stack pointer in the TSS
;;; ; and we recalculate PL0STK pointers, we can't allow any interruption
;;;
;;; ;;;;;;;; cli		    ; Disallow interrupts (already disabled)
;;;
;;;	     push    ds 	    ; Save for a moment
;;;
;;;	     SETDATA ds 	    ; Get DGROUP data selector
;;;	     assume  ds:DGROUP	    ; Tell the assembler about it
;;;
;;;	     pop     SAVE_DS	    ; Save to restore later
;;;
;;;	     add     esp,type DPMI_INTRET1_PL0LEN ; Strip
;;;
;;;	     pop     LAST_INTFLG    ; Restore
;;;	     pop     LAST_INTCOM    ; Restore
;;;
;;;	     mov     SAVE_EAX,eax   ; Save for a moment
;;;
;;;	     mov     eax,PCURTSS    ; Get offset in DGROUP of current TSS
;;;	     pop     DGROUP:[eax].TSS_ESP0 ; Restore
;;;	     pop     DGROUP:[eax].TSS_SS0  ; ...
;;;
;;; ; Recalculate PL0STK pointers
;;;
;;;	     call    SET_PPL0STK    ; Set PPL0STK... pointers
;;;
;;; ; Restore saved registers
;;;
;;;	     mov     eax,SAVE_EAX   ; Restore
;;;	     mov     ds,SAVE_DS     ; ...
;;;	     assume  ds:nothing     ; Tell the assembler about it
;;;
;;;	     public  DPMI_COM_IRETD
;;; DPMI_COM_IRETD:
;;;
;;; ; Ensure NT=0 so the following IRETD doesn't cause a task switch
;;;
;;;	     pushf		    ; Get our flags
;;;	     and     [esp].ELO,not (mask $NT) ; NT=0
;;;	     popf		    ; Restore
;;;
;;;	     iretd		    ; Return to caller
;;;
;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;
;;; DPMI_REFRET endp		    ; End DPMI_REFRET procedure

PROG	ends			; End PROG segment

	MEND			; End DPMI_DIF module
