;' $Header$
	title	DPMI_I0E -- DPMI.LOD INT 0Eh Handler
	page	58,122
	name	DPMI_I0E
COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1987-2003 Qualitas, Inc.  All Rights Reserved.

|
.386p
.xlist
	include MASM.INC
	include BITFLAGS.INC
	include CPUFLAGS.INC
	include 386.INC
	include PTR.INC
	include 8259.INC
	include ALLMEM.INC
	include IOPBITS.INC
	include OPCODES.INC
	include MASM5.MAC

	include QMAX_I31.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_SEG.INC
.list

DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_I0E_DATA
@DPMI_I0E_DATA	label byte	; Mark module start in .MAP file

	extrn	PPL0STK_DNRM:dword
	extrn	PPL0STK_DERR:dword
	extrn	PPL0STK_NRM:dword
	extrn	PPL0STK_ERR:dword

	extrn	DPMITYPE:byte
	extrn	DPMI_CPFHOOK:byte
;;;;;;; extrn	LaVMTSS:dword
	extrn	PCURTSS:dword
	extrn	PMVPF:abs
	extrn	DPMI_IDEF:word
;;;;;;; extrn	SEL_4GB:word

	extrn	OLDINT0E_FVEC:dword

	extrn	LPMSTK_FVEC:fword
	extrn	LPMSTK_CNT:dword

	extrn	DPMIMSG0E:byte

	extrn	VMM_FLAG:word
	include QMAX_VMM.INC

	public	OLDCR2
OLDCR2	dd	?		; Save area for old CR2

	public	SAVE_DS0D0E
SAVE_DS0D0E dd	?		; Save area for DS for INTs 0Dh/0Eh

	public	DPMICNT0E
DPMICNT0E dw	0		; Count of active INT 0Eh DPMI calls

DATA	ends			; End DATA segment


CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
	assume	cs:PGROUP

	extrn	INTPROC00Z:near

CODE16A ends			; End CODE16A segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_I0E_PROG
@DPMI_I0E_PROG: 		; Mark module start in .MAP file

	extrn	RESETVARS:near

	extrn	VMM_PageFaultHandler:near
	extrn	DPMIFN_LPMSTK:near
	extrn	FLTPROC_APPL:near

	extrn	INTXXCOM:near
	extrn	HARDINT:near

	extrn	INTCOM_DPMI_INT:near
	extrn	INTCOM_DPMI_FAULT:near
	extrn	SET_PPL0STK:near

	FPPROC	INT0E -- Page Fault Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Page fault interrupt (0Eh) with error code on stack.

Distinguish amongst four cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC0E
Page Fault	 VM86	  ESP=PPL0STK_ERR	Attempt to fix it
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto INTCOM_DPMI_INT
Page Fault	 DPMI	  ESP=PPL0STK_DERR	Attempt to fix it
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT
Page Fault	 PM				UGH

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
	je	short INTPROC0E ; Yes, use normal interrupt processor

	cmp	esp,PPL0STK_ERR ; Is it a fault from VM86 mode?
	je	near ptr INT0E_VM86 ; Yes

	cmp	esp,PPL0STK_DNRM ; Izit a HW/SW interrupt from a DPMI client?
	je	short INT0E_DPMI_INT ; Jump if so

	cmp	esp,PPL0STK_DERR ; Izit a fault from a DPMI client?
	je	near ptr INT0E_DPMI_FAULT ; Jump if so

; We need to distinguish between HW-MAX and EX-MAX, so we test
; the R3 bit in NRM_EFL.  If it's HW-MAX, NRM_EFL contains EFL
; and that bit is always set.  If it's EX-MAX, NRM_EFL contains
; CS (a selector), and that bit is the high-order bit of CPL.
; As the host never executes at CPL2 or CPL3, that bit is always clear.

	test	[esp].NRM_EFL,mask $R3 ; Izit set?
	jz	near ptr INT0E_PL0 ; No, so that's a Page Fault at PL0

; HW-MAX has occurred:	if there's a DPMI client active, treat it
; as a DPMI interrupt so we use the HPDA stack, not LAST_INTCOM.

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	jne	short INT0E_DPMI_INT ; Jump if so

	mov	[esp].NRM_INTNO,4*0Eh+offset PGROUP:INTPROC00Z ; Mark as hardware INT 0Eh

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	HARDINT 	; It's a hardware interrupt


; Normal stack:  HW/SW interrupt from DPMI host

	assume	ds:DGROUP	; Tell the assembler about it
INTPROC0E:
	push	OLDINT0E_FVEC.FSEL.EDD ; Pass selector as dword
	push	OLDINT0E_FVEC.FOFF	; Pass offset

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	retf			; Continue with original handler


; Hardware/software interrupt from a DPMI client

	assume	ds:DGROUP	; Tell the assembler about it
INT0E_DPMI_INT:
	mov	[esp].NRM_INTNO,4*0Eh+offset PGROUP:INTPROC00Z ; Mark as hardware INT 0Eh

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	INTCOM_DPMI_INT ; Join common DPMI interrupt code


; Fault from VM, PL0, or a DPMI client -- see if we can emulate it
; The stack is mapped by INTDPF_STR -- move it down to look like
; INTXX_STR.

	assume	ds:DGROUP	; Tell the assembler about it
INT0E_DPMI_FAULT:
INT0E_VM86:
INT0E_PL0:
	pushad			; Save all EGP registers

	cld			; String ops forwardly
	mov	ebp,esp 	; SS:EBP ==> INTXX_STR

	mov	[ebp].INTXX_INTNO,4*0Eh+offset PGROUP:INTPROC00Z ; Mark as INT 0Eh

	test	[ebp].INTXX_EFL.EHI,mask $VM ; Izit from VM86 mode?
	jnz	short INT0E_XVMM ; Jump if so

	test	VMM_FLAG,@VMM_SYSINIT ; Is VMM active?
	jz	short INT0E_XVMM ; Jump if not

	push	LPMSTK_FVEC.FSEL.EDD ; Save current LPM stack top
	push	LPMSTK_FVEC.FOFF ; ...

	lea	eax,[ebp].INTXX_EIP ; SS:EAX == > INTDPI_STR from PL3
	push	eax		; Pass the offset
	call	DPMIFN_LPMSTK	; Save new LPM stack as appropriate

	mov	eax,cr2 	; Get Page Fault linear address
	push	eax		; Pass the linear address
	call	VMM_PageFaultHandler
	pop	LPMSTK_FVEC.FOFF ; De-allocate it
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

	or	eax,eax 	; Returns zero on successfully handled
				; transparent fault
	jz	near ptr INT0E_IRETD ; Join common code

	and	[ebp].INTXX_EFL.ELO,not (mask $NT) ; Clear NT flag

	cmp	eax,1		; If this is definitely something the user
				; wants to handle, EAX is returned 1
	je	near ptr INT0E_DPMI_VISIBLE ; Jump if so
INT0E_XVMM:

; The stack is mapped by INTXX_STR
; Note that INTXX_INTNO is already filled in with the
; INT # times 4 + offset PGROUP:INTPROC00Z

; If this fault came from a DPMI client, give 'em a crack at it.
; If it came from VM, pass it on to a DPMI client
; hooking this fault or to the MM.

	test	[ebp].INTXX_EFL.EHI,mask $VM ; Izit from V86 mode?
	jnz	short @F	; Pass it on

; If there's a DPMI client active, give it a crack at this exception

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	jne	short INT0E_DPMI_VISIBLE ; Jump if so
@@:
	mov	esi,4*0Eh	; Interrupt # times 4
	lea	ebx,DPMIMSG0E	; Offset of message to display to user

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	INTXXCOM	; Join common code


	assume	ds:DGROUP	; Tell the assembler about it
INT0E_INTCOM_DPMI_FAULT:
	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	INTCOM_DPMI_FAULT ; Join common code


	assume	ds:DGROUP	; Tell the assembler about it
INT0E_FLTPROC_APPL:
	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	FLTPROC_APPL	; Join common code


; * Restart the instruction

	assume	ds:DGROUP	; Tell the assembler about it
INT0E_IRETD:

; Because EMM386 uses the value of CR2 as a global variable to
; modify its behavior, we must be sure to zero it after we no
; longer need it.

	xor	eax,eax 	; A convenient zero
	mov	cr2,eax 	; Clear it

	popad			; Restore all EGP registers
				; N.B.:  Do not follow with [EAX+???*?]
	add	esp,size INTXX_ERR ; Strip off error code

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Return to caller (PM only)


; The stack is mapped by INTXX_STR (nothing above INTXX_SS is valid)
; This code is shared by both INT 0Dh and INT 0Eh handlers

	public	INT0D_DPMI_VISIBLE
	assume	ds:DGROUP	; Tell the assembler about it
INT0D_DPMI_VISIBLE:
INT0E_DPMI_VISIBLE:

; Because EMM386 uses the value of CR2 as a global variable to
; modify its behavior, we must be sure to zero it after we no
; longer need it.

	mov	eax,cr2 	; Get the current Page Fault Linear Address
	mov	OLDCR2,eax	; Save for later use

	xor	eax,eax 	; A convenient zero
	mov	cr2,eax 	; Clear it

	popad			; Restore all EGP registers

; SS:ESP ==> INTDPF_STR

	test	[esp].INTDPF_EFL.EHI,mask $VM ; Izit from VM86?
	jnz	near ptr INT0E_INTCOM_DPMI_FAULT ; Jump if so

	test	[esp].INTDPF_CS,mask $PL ; Izit at PL0?
	jnz	near ptr INT0E_INTCOM_DPMI_FAULT ; Jump if not

; See if the current DPMI client has hooked this fault

	push	eax		; Save for a moment

	movzx	eax,[esp+4].INTDPF_INTNO ; Get INT # times 4 + ...
	sub	eax,offset PGROUP:INTPROC00Z ; Convert to INT # times 4
	shr	eax,2-0 	; Convert from times 4 to times 1

	bt	DPMI_CPFHOOK.EDD,eax ; Izit hooked by current client?
	pop	eax		; Restore
	jnc	near ptr INT0E_FLTPROC_APPL ; Jump if not

DPMI_VPF_STR struc

DPMI_VPF_ESP0 dd ?		; Previous TSS_ESP0
DPMI_VPF_SS0 dw ?		; ...	   TSS_SS0
DPMI_VPF_LPMSTK df ?		; Original LPMSTK_FVEC
	dw	?		; For alignment
DPMI_VPF_EBP dd ?		; Caller's EBP
DPMI_VPF_EBX dd ?		; ...	   EBX
DPMI_VPF_EAX dd ?		; ...	   EAX
DPMI_VPF_NXT db (size INTDPF_STR) dup (?) ; The rest of the stack

DPMI_VPF_STR ends

	REGSAVE <eax,ebx,ebp>	; Save registers

	push	LPMSTK_FVEC.FSEL.EDD ; Save current LPM stack top
	push	LPMSTK_FVEC.FOFF ; ...

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	push	DGROUP:[eax].TSS_SS0  ; Save old stack selector
	push	DGROUP:[eax].TSS_ESP0 ; Save pointer to stack top

; The stack is now mapped by DPMI_VPF_STR

	mov	ebp,esp 	; Hello, Mr. Stack

; Set new LPM stack top for nested callers if it's active
; and we're called from PM, not PL0

	lea	ebx,[ebp].DPMI_VPF_NXT.INTDPF_EIP ; SS:EBX ==> INTDPI_STR from PL3
	push	ebx		; Pass the offset
	call	DPMIFN_LPMSTK	; Save new LPM stack as appropriate

; * Save SS:ESP as new top of stack pointer

	mov	DGROUP:[eax].TSS_SS0,ss ; Save for next time
	mov	DGROUP:[eax].TSS_ESP0,ebp ; ...

;;;;;;; push	gs		; Save for a moment
;;;;;;;
;;;;;;; mov	gs,SEL_4GB	; Get AGROUP data selector
;;;;;;; assume	gs:AGROUP	; Tell the assembler about it
;;;;;;;
;;;;;;; mov	eax,LaVMTSS	; Get offset in AGROUP of VM TSS
;;;;;;; mov	AGROUP:[eax].TSS_ESP0,ebp ; Save for next time
;;;;;;;
;;;;;;; pop	gs		; Restore
;;;;;;; assume	gs:nothing	; Tell the assembler about it
;;;;;;;
	cli			; Disallow interrupts

; * Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

; Setup the PL0 stack as if the fault occurred at PL3

	inc	LPMSTK_CNT	; Count in another one

	push	LPMSTK_FVEC.FSEL.EDD ; Fake up the SS for the fault
	push	LPMSTK_FVEC.FOFF ; Fake up the ESP for the fault
	push	[ebp].DPMI_VPF_NXT.INTDPF_EFL ; Pass the return flags
	push	[ebp].DPMI_VPF_NXT.INTDPF_INTNO ; Pass INT #
	push	DPMI_IDEF	 ; Pass the return CS
	push	dword ptr PMVPF ; Pass the return EIP
	push	[ebp].DPMI_VPF_NXT.INTDPF_ERR ; Pass the error code

	mov	eax,[ebp].DPMI_VPF_EAX ; ...		 EAX
	mov	ebx,[ebp].DPMI_VPF_EBX ; ...		 EBX
	mov	ebp,[ebp].DPMI_VPF_EBP ; ...		 EBP

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	INTCOM_DPMI_FAULT ; Continue with the DPMI handler


	public	DPMI_VPFRET
DPMI_VPFRET:

; We arrive at this label after a visible fault at ring 0.  When a
; fault at ring 0 occurs, the client is given a phony ring 3
; address (DPMI_IDEF:PMVPF) as the address where the fault occurred.
; Code at that address calls (via a call-gate) to here.  At this
; point, the user handler has been executed, and all registers are
; in the correct state.  All we have to do is to pop excess data from
; the stack and issue the IRETD.

; The stack is mapped by INTDPI_STR followed by DPMI_VPF_STR

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	pop	SAVE_DS0D0E	; Save to restore later

	add	esp,size INTDPI_STR ; Strip off pseudo-return address

	mov	[esp].DPMI_VPF_EAX,eax ; ...	      EAX
	mov	[esp].DPMI_VPF_EBX,ebx ; ...	      EBX

; Restore the previous TSS_ESP0 and TSS_SS0 to the TSS

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	pop	ebx		; Restore
	mov	DGROUP:[eax].TSS_ESP0,ebx ; Restore
	pop	DGROUP:[eax].TSS_SS0 ; ...

;;;;;;; push	gs		; Save for a moment
;;;;;;;
;;;;;;; mov	gs,SEL_4GB	; Get AGROUP data selector
;;;;;;; assume	gs:AGROUP	; Tell the assembler about it
;;;;;;;
;;;;;;; mov	eax,LaVMTSS	; Get offset in AGROUP of VM TSS
;;;;;;; mov	AGROUP:[eax].TSS_ESP0,ebx ; Save for next time
;;;;;;;
;;;;;;; pop	gs		; Restore
;;;;;;; assume	gs:nothing	; Tell the assembler about it
;;;;;;;
; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

; De-allocate our portion of the LPM stack

	pop	LPMSTK_FVEC.FOFF ; De-allocate it
	pop	LPMSTK_FVEC.FSEL.EDD ; ...
	dec	LPMSTK_CNT	; Count it out

; Restore caller's registers

	pop	eax		; ...		 EBP
	pop	ebx		; ...		 EBX
	pop	eax		; ...		 EAX

	add	esp,size INTDPF_ERR ; Strip off pseudo-error code

	mov	ds,SAVE_DS0D0E	; Restore
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Return to fault address (PM only)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT0E	endp			; End INT0E procedure

PROG	ends			; End PROG segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

$P	equ	00h		; Prefix

$M	equ	01h		; MOD R/M byte present
$A	equ	02h		; Immediate word:word (OSP=0) or word:dword (OSP=1)
$O	equ	04h		; Immediate word (ASP=0) or dword (ASP=1)
$B	equ	08h		; Immediate byte
$W	equ	10h		; Immediate word
$V	equ	20h		; Immediate word (OSP=0) or dword (OSP=1)
$OSP	equ	40h		; Operand size prefix
$ASP	equ	80h		; Address ...

	public	$USE32
$USE32	equ	$OSP or $ASP	; USE32 attibutes

$BW	equ	$B or $W	; Immediate word and immediate byte
$MB	equ	$M or $B	; MOD R/M byte with immediate byte
$MV	equ	$M or $V	; MOD R/M byte with immediate word (OSP=0) or dword (OSP=1)

	public	OPCOD1
;		x0  x1	x2  x3	x4  x5	x6  x7	x8  x9	xA  xB	xC  xD	xE  xF
OPCOD1	db	$M ,$M ,$M ,$M ,$MB,$MV, 0 , 0 ,$M ,$M ,$M ,$M ,$MB,$MV, 0 ,$P	; 0x
	db	$M ,$M ,$M ,$M ,$MB,$MV, 0 , 0 ,$M ,$M ,$M ,$M ,$MB,$MV, 0 , 0	; 1x
	db	$M ,$M ,$M ,$M ,$MB,$MV,$P , 0 ,$M ,$M ,$M ,$M ,$MB,$MV,$P , 0	; 2x
	db	$M ,$M ,$M ,$M ,$MB,$MV,$P , 0 ,$M ,$M ,$M ,$M ,$MB,$MV,$P , 0	; 3x
	db	 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0	; 4x
	db	 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0	; 5x
	db	 0 , 0 ,$M ,$M ,$P ,$P ,$P ,$P ,$V ,$MV,$B ,$MB, 0 , 0 , 0 , 0	; 6x
	db	$B ,$B ,$B ,$B ,$B ,$B ,$B ,$B ,$B ,$B ,$B ,$B ,$B ,$B ,$B ,$B	; 7x
	db	$MB,$MV,$MB,$MB,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M	; 8x
	db	 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 ,$A , 0 , 0 , 0 , 0 , 0	; 9x
	db	$O ,$O ,$O ,$O , 0 , 0 , 0 , 0 ,$B ,$V , 0 , 0 , 0 , 0 , 0 , 0	; Ax
	db	$B ,$B ,$B ,$B ,$B ,$B ,$B ,$B ,$V ,$V ,$V ,$V ,$V ,$V ,$V ,$V	; Bx
	db	$MB,$MB,$W , 0 ,$M ,$M ,$MB,$MV,$BW, 0 ,$W , 0 , 0 ,$B , 0 , 0	; Cx
	db	$M ,$M ,$M ,$M ,$B ,$B , 0 , 0 ,$P ,$P ,$P ,$P ,$P ,$P ,$P ,$P	; Dx
	db	$B ,$B ,$B ,$B ,$B ,$B ,$B ,$B ,$V ,$V ,$V ,$B , 0 , 0 , 0 , 0	; Ex
	db	$P , 0 ,$P ,$P , 0 , 0 ,$M ,$M , 0 , 0 , 0 , 0 , 0 , 0 ,$M ,$M	; Fx

	public	OPCOD2
;		x0  x1	x2  x3	x4  x5	x6  x7	x8  x9	xA  xB	xC  xD	xE  xF
OPCOD2	db	$M ,$M ,$M ,$M , ? , 0 , 0 , 0 , 0 , 0 , ? , 0 , ? , ? , ? , ?	; 0x
	db	$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M , ? , ? , ? , ? , ? , ? , ?	; 1x
	db	$M ,$M ,$M ,$M ,$M , ? ,$M , ? ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M	; 2x
	db	 0 , 0 , 0 , 0 , 0 , 0 , ? , ? , ? , ? , ? , ? , ? , ? , ? , ?	; 3x
	db	$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M	; 4x
	db	$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M	; 5x
	db	$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M	; 6x
	db	$MB,$MB,$MB,$MB,$M ,$M ,$M , 0 , ? , ? , ? , ? , ? , ? ,$M ,$M	; 7x
	db	$V ,$V ,$V ,$V ,$V ,$V ,$V ,$V ,$V ,$V ,$V ,$V ,$V ,$V ,$V ,$V	; 8x
	db	$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M	; 9x
	db	 0 , 0 , 0 ,$M ,$MB,$M ,$M ,$M , 0 , 0 , 0 ,$M ,$MB,$M , ? ,$M	; Ax
	db	$M ,$M ,$M ,$M ,$M ,$M ,$M ,$M , ? , ? ,$MB,$M ,$M ,$M ,$M ,$M	; Bx
	db	$M ,$M , ? , ? , ? , ? , ? ,$M , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0	; Cx
	db	 ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ?	; Dx
	db	 ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ?	; Ex
	db	 ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , ? , 0	; Fx

DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	NPPROC	GETILEN -- Get Instruction Length
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Get instruction length

On entry:

ES:ESI	==>	First byte of instruction
DL	=	0 or $USE32

On exit:

EAX	=	length of instruction
ES:ESI	==>	changed

|

	REGSAVE <ebx,ecx,edx>	; Save registers

	xor	ecx,ecx 	; Initialize byte count
GETILEN_NEXT:
	lods	es:[esi].LO	; Get next instruction byte
	inc	ecx		; Count it in

	cmp	al,@OPCOD_CS	; Check for CS:
	je	short GETILEN_NEXT ; Jump if so

	cmp	al,@OPCOD_DS	; Check for DS:
	je	short GETILEN_NEXT ; Jump if so

	cmp	al,@OPCOD_ES	; Check for ES:
	je	short GETILEN_NEXT ; Jump if so

	cmp	al,@OPCOD_FS	; Check for FS:
	je	short GETILEN_NEXT ; Jump if so

	cmp	al,@OPCOD_GS	; Check for GS:
	je	short GETILEN_NEXT ; Jump if so

	cmp	al,@OPCOD_SS	; Check for SS:
	je	short GETILEN_NEXT ; Jump if so

	cmp	al,@OPCOD_REPE	; Check for REPE
	je	short GETILEN_NEXT ; Jump if so

	cmp	al,@OPCOD_REPNE ; Check for REPNE
	je	short GETILEN_NEXT ; Jump if so

	cmp	al,@OPCOD_LOCK	; Check for LOCK
	je	short GETILEN_NEXT ; Jump if so

	cmp	al,@OPCOD_ESC0	; Izit below ESC 0?
	jb	short @F	; Jump if so

	cmp	al,@OPCOD_ESC7	; Izit above ESC 7?
	jbe	short GETILEN_NEXT ; Jump if not
@@:
	cmp	al,@OPCOD_OSP ; Check for OSP
	jne	short @F	; Jump if not

	or	dl,$OSP 	; Mark as present

	jmp	short GETILEN_NEXT ; Jump if so


@@:
	cmp	al,@OPCOD_ASP ; Check for ASP
	jne	short @F	; Jump if not

	or	dl,$ASP 	; Mark as present

	jmp	short GETILEN_NEXT ; Jump if so


@@:
	lea	ebx,OPCOD1	; ES:EBX ==> one-byte opcode table

	cmp	al,@OPCOD_2ND	; Check for secondary opcodes
	jne	short @F	; Jump if not

	lods	es:[esi].LO	; Get next instruction byte (opcode)
	inc	ecx		; Count it in
	lea	ebx,OPCOD2	; ES:EBX ==> two-byte opcode table
@@:
	xlat	OPCOD1[ebx]	; Translate opcode into flags
	or	dl,al		; Include with OSP/ASP flags

; Check for immediate word:word (OSP=0) or word:dword (OSP=1)

	test	dl,$A		; Check it
	jz	short GETILEN_XA ; Jump if not

	add	ecx,2+2 	; Count in word:word

	test	dl,$OSP 	; Check for OSP
	jz	short GETILEN_XA ; Jump if OSP=0

	add	ecx,2		; Count in extra word
GETILEN_XA:

; Check for immediate word (ASP=0) or dword (ASP=1)

	test	dl,$O		; Check it
	jz	short GETILEN_XO ; Jump if not

	add	ecx,2		; Count in word

	test	dl,$ASP 	; Check for ASP
	jz	short GETILEN_XO ; Jump if ASP=0

	add	ecx,2		; Count in extra word
GETILEN_XO:

; Check for immediate byte

	test	dl,$B		; Check it
	jz	short GETILEN_XB ; Jump if not

	inc	ecx		; Count in byte
GETILEN_XB:

; Check for immediate word

	test	dl,$W		; Check it
	jz	short GETILEN_XW ; Jump if not

	add	ecx,2		; Count in word
GETILEN_XW:

; Check for immediate word (OSP=0) or dword (OSP=1)

	test	dl,$V		; Check it
	jz	short GETILEN_XV ; Jump if not

	add	ecx,2		; Count in word

	test	dl,$OSP 	; Check for OSP
	jz	short GETILEN_XV ; Jump if OSP=0

	add	ecx,2		; Count in extra word
GETILEN_XV:
	test	dl,$M		; Izit present?
	jz	short GETILEN_EXIT ; Jump if not

	lods	es:[esi].LO	; Get next instruction byte (mod R/M)
	inc	ecx		; Count it in
	mov	ah,al		; Save for later use

;;;;;;; mov	al,ah		; Copy for destructive test
	and	al,mask $MOD	; Isolate the MOD bits

	test	dl,$ASP 	; Check for Address Size Prefix
	jnz	short GETILEN_ASP ; Jump if so

	cmp	al,11b shl $MOD ; Check for MOD=11 (register operand)
	je	short GETILEN_EXIT ; Jump if that's all

	cmp	al,10b shl $MOD ; Check for MOD=10 (DISP16)
	je	short GETILEN_D16 ; Jump if so

	cmp	al,01b shl $MOD ; Check for MOD=01 (DISP8)
	je	short GETILEN_D8 ; Jump if so

	mov	al,ah		; Copy for destructive test
	and	al,mask $RM	; Isolate the RM bits

	cmp	al,110b shl $RM ; Check for special DISP16
	jne	short GETILEN_EXIT ; Not this time
GETILEN_D16:
	inc	ecx		; Count in another byte
	inc	esi		; Skip past the instruction byte
GETILEN_D8:
	inc	ecx		; Count in another byte
	inc	esi		; Skip past the instruction byte

	jmp	short GETILEN_EXIT ; Join common code


; There's an Address Size Prefix, hence maybe an SIB byte

GETILEN_ASP:
	mov	al,ah		; Copy for destructive test
	and	al,mask $MOD	; Isolate the MOD bits

	cmp	al,11b shl $MOD ; Check for MOD=11 (register operand)
	je	short GETILEN_EXIT ; Jump if that's all

	mov	dh,ah		; Copy for destructive test
	and	dh,mask $RM	; Isolate the RM bits

	cmp	dh,100b shl $RM ; Check for special SIB byte
	jne	short @F	; Not this time

	inc	ecx		; Count in another byte
	inc	esi		; Skip past the instruction byte
@@:
	cmp	al,10b shl $MOD ; Check for MOD=10 (DISP32)
	je	short GETILEN_D32 ; Jump if so

	cmp	al,01b shl $MOD ; Check for MOD=01 (DISP8)
	je	short GETILEN_D8 ; Jump if so

	mov	al,ah		; Copy for destructive test
	and	al,mask $RM	; Isolate the RM bits

	cmp	al,101b shl $RM ; Check for special DISP32
	jne	short GETILEN_EXIT ; Not this time
GETILEN_D32:
	add	ecx,4		; Count in another dword
	add	esi,4		; Skip past the DISP32
GETILEN_EXIT:
	mov	eax,ecx 	; Copy to return register

	REGREST <edx,ecx,ebx>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

GETILEN endp			; End GETILEN procedure

PROG	ends			; End PROG segment

	MEND			; End DPMI_I0E module
