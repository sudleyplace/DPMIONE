;' $Header$
	title	DPMI_N31 -- DPMI.LOD INT 31h Miscellaneous Interrupt Handlers
	page	58,122
	name	DPMI_N31
COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1991-2004 Sudley Place Software.  All Rights Reserved.

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include PTR.INC
	include CPUFLAGS.INC
	include ALLMEM.INC
	include OPCODES.INC
	include DOSERR.INC
	include MASM5.MAC
	include IOPBITS.INC
	include INTVEC.INC
	include DOSCALL.INC
	include VCPI.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_SEG.INC
;;;;;;; include DPMI_SWT.INC

	include QMAX_I31.INC		; Must precede QMAXDPMI.INC
	include QMAXDPMI.INC		; Must follow QMAX_I31.INC
	include QMAX_MSC.INC
	include QMAX_TSS.INC
	include QMAX_VMM.INC
.list


YCODE	segment use16 para public 'ycode' ; Start YCODE segment
	assume	ds:YGROUP

	extrn	MSC_FLAG:word

	extrn	EXITRCHI:word

YCODE	ends			; End YCODE segment


DATA16	segment use16 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	extrn	DPM_FLAG:word

DATA16	ends			; End DATA16 segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_N31_DATA
@DPMI_N31_DATA	label byte	; Mark module start in .MAP file

;;;;;;; include DPMI_LCL.INC
;;;;;;; extrn	LCL_FLAG:word

	extrn	I31_FLAG:word
	extrn	OLDINT_ARB:byte
	extrn	OLDINT0D_FVEC:fword

	extrn	DPMI_CPIHOOK:byte
	extrn	DPMI_PVFHOOK:byte

	extrn	SAVE_EAX:dword

	extrn	PVMTSS:dword
	extrn	PCURTSS:dword

	extrn	INT23_TYP:byte
	extrn	INT24_TYP:byte

	extrn	DPMITYPE:byte
	extrn	SEL_4GB:word

	extrn	VMM_FLAG:word
	extrn	HIMEM_La:dword

	extrn	BSActive:byte
	extrn	PageIOActive:byte

	public	INT00NXT_FVEC
INT00NXT_FVEC df ?		; Address of next interrupt in GP_INT

@BSAgeInit equ	18		; Start with 1 second

	public	BSAgeClock,BSAgeMax
BSAgeClock dw	@BSAgeInit	; Aging countdown counter
BSAgeMax   dw	@BSAgeInit	; Aging maximum counter for refresh

DATA	ends			; End DATA segment


CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
	assume	cs:PGROUP,ds:PGROUP

	extrn	INTPROC00Z:near

	extrn	ERM_FVEC:fword

CODE16A ends			; End CODE16A segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_N31_PROG
@DPMI_N31_PROG: 		; Mark module start in .MAP file

	extrn	RESETVARS:near

	irp	XX,<00,04,05,10,15,1C,20,21,23,24,25,26,27,33,41,4B,67>
	extrn	INTPROC&XX&:near
	endm			; IRP

	extrn	INTCOM_DPMI_FAULT:near

	extrn	INT10_DPMI:near
	extrn	INT15_DPMI:near
;;;;;;; extrn	INT16_DPMI:near
	extrn	INT21_DPMI:near
	extrn	INT33_DPMI:near
	extrn	INT4B_DPMI:near
	extrn	PMINTCOM:near
	extrn	VMFLTCOM:near
	extrn	DPMIFN_LMSW:near
	extrn	DPMIFN_TERMINATE:near
	extrn	DPMIFN_ESPMOD:near
	extrn	DPMIFN_SWITCHADDR:near

	extrn	PPM_AGE_PAGES:near

	FPPROC	INT00 -- Divide Overflow Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Divide overflow interrupt handler

If we're called from VM,
   If there's a DPMI client active and the primary client has hooked
     this exception, give it a crack at it.
   Otherwise, continue with INTPROC00.
If we're called from PM and there's a DPMI client active,
   give it a crack at this exception.
Otherwise, continue with INTPROC00.

|

; The stack is mapped by NRM_STR

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit VM86 mode?
	jz	short INT00_PM	; Jump if not

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_PVFHOOK[00h/8],1 shl (00h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	near ptr INTPROC00 ; Jump if not (call as VM INT 00h)

	PUSHD	0		; Pass pseudo-error code

; The MAX stack is consists of (from bottom up) an error code
; followed by INTCOM_STR.

	mov	[esp].INTDPF_INTNO,4*00h + offset PGROUP:INTPROC00Z ; Mark as INT 00h

	jmp	near ptr VMFLTCOM ; Jump to common code

INT00_PM:

; If there's a DPMI client active, give it a crack at this exception

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	je	near ptr INTPROC00 ; Jump if not (call as VM INT 00h)

COMMENT!

Because of a bug in the Intel Codebuilder which uses self-modifying
code to execute an arbitrary interrupt, we must handle INT 00h
specially.  What they do is as follows:

	 lea	 esi,INT00+1
	 mov	 [esi],al
INT00:
	 int	 00h

which fails to take into account the prefetch instruction queue.  In
particular, the above code always executes the preceding interrupt #,
never the one written into the INT instruction.  To my great
disappointment, the above code works under Windows for all the wrong
reasons.  When running DPMI code, Windows sets up the IDT for most
interrupts to be at DPL 0 (and defines only the first 60h IDT
entries).  This means that the INT instruction actually doesn't
execute; instead, it signals a GP Fault.  The GP Fault handler then
checks to see which interrupt # was specified at which time it sees
the value written by the self-modifying code and executes the correct
instruction.

Here's what I propose to do:

* Detect the problem in our INT 00h handler as that is the default
  value in the INT instruction.
* Save the xxh value in INT xxh, and change it back to 00h.
* Simulate the INT xxh.

Detection Phase:

The Divide Overflow interrupt is a fault, meaning that the CS|EIP on
the stack point to the faulting instruction.  The first check then is
that the instruction to which the CS|EIP on the stack points is either
DIV or IDIV.  The opcodes for DIV are F6 /6 and F7 /6; for IDIV, they
are F6 /7 and F7 /7.

If the instruction at CS|EIP is neither DIV nor IDIV and the two bytes
which precede it are CD xx where xx is not zero, then we assume we
have detected this bug.

Correction Phase:

* Save the xxh value in INT xxh, and change it back to 00h.
* Simulate the INT xxh.

!

INT00_STR struc

	dd	?		; Caller's EBP
INT00_EIP dd	?		; ...	   EIP
INT00_CS  dw	?,?		; ...	   CS w/filler
INT00_EFL dd	?		; ...	   EFL

INT00_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ebx,ecx,ds,es> ; Save registers

	lds	ebx,[ebp].INT00_EIP.EDF ; Get caller's CS|EIP
	assume	ds:nothing	; Tell the assembler about it

	xor	ecx,ecx 	; Initialize index register
INT00_NEXTINSTR:
	mov	al,ds:[ebx+ecx] ; Get next instruction byte
	inc	ecx		; Skip over it

; Strip off segment overrides prefixes

	cmp	al,@OPCOD_CS	; Izit segment override?
	je	short INT00_NEXTINSTR ; Jump if so

	cmp	al,@OPCOD_DS	; Izit segment override?
	je	short INT00_NEXTINSTR ; Jump if so

	cmp	al,@OPCOD_ES	; Izit segment override?
	je	short INT00_NEXTINSTR ; Jump if so

	cmp	al,@OPCOD_FS	; Izit segment override?
	je	short INT00_NEXTINSTR ; Jump if so

	cmp	al,@OPCOD_GS	; Izit segment override?
	je	short INT00_NEXTINSTR ; Jump if so

	cmp	al,@OPCOD_SS	; Izit segment override?
	je	short INT00_NEXTINSTR ; Jump if so

; Strip off operand and address size prefixes

	cmp	al,@OPCOD_OSP	; Izit Operand Size Prefix?
	je	short INT00_NEXTINSTR ; Jump if so

	cmp	al,@OPCOD_ASP	; Izit Address Size Prefix?
	je	short INT00_NEXTINSTR ; Jump if so

; No more valid prefixes:  check for DIV and IDIV opcodes

	cmp	al,@OPCOD_GRP3A ; Izit Group 3, type A?
	je	short @F	; Jump if so

	cmp	al,@OPCOD_GRP3B ; Izit Group 3, type B?
	jne	short INT00_CHK1 ; Jump if not
@@:
	mov	al,ds:[ebx+ecx] ; Get MOD R/M byte
	and	al,mask $REG	; Isolate the REG bits
	shr	al,$REG 	; Shift to low-order

	cmp	al,110b 	; Izit DIV or IDIV?
	jae	short INT00_DIV ; Jump if so

; The current instruction is neither DIV not IDIV
; Check for CD xx preceding the current instruction

INT00_CHK1:
	sub	ebx,2		; Back off to CD xxh
	jc	short INT00_DIV ; Jump if we are confused

	cmp	ds:[ebx].LO,@OPCOD_INT ; Izit INT instruction?
	jne	short INT00_DIV ; Jump if we are quite confused

	movzx	eax,ds:[ebx].HI ; Get the interrupt #

	cmp	al,00h		; Izit INT 00h instruction?
	je	short INT00_DIV ; Jump if we are totally confused

; We have detected the case described above:  now we must correct it

; Get the address of the corresponding interrupt

	sub	esp,size DTR_STR ; Make room on the stack
	SIDTD	[esp].EDF	; Save linear address of the IDT
	mov	ebx,[esp].DTR_BASE ; Get base address of the IDT
	add	esp,size DTR_STR ; Remove from the stack

	SETDATA es		; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	mov	ds,SEL_4GB	; Get AGROUP data selector
	assume	ds:AGROUP	; Tell the assembler about it

	mov	cx,AGROUP:[ebx+eax*(type IDT_STR)].IDT_SELECT ; Get the selector
	mov	INT00NXT_FVEC.FSEL,cx ; Save for later use

	mov	cx,AGROUP:[ebx+eax*(type IDT_STR)].IDT_OFFHI ; Get the high-order offset
	shl	ecx,16		; Shift to high-order word
	mov	cx,AGROUP:[ebx+eax*(type IDT_STR)].IDT_OFFLO ; Get the low-...
	mov	INT00NXT_FVEC.FOFF,ecx ; Save for later use

	clc			; Indicate we need to emulate

	jmp	short INT00_EXIT ; Join common exit code (note CF=0)

	assume	ds:nothing	; Tell the assembler about it

INT00_DIV:
	stc			; Mark as no fixup needed
INT00_EXIT:
	REGREST <es,ds,ecx,ebx,eax> ; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	pop	ebp		; Restore
	jc	short INT00_DPMI_FAULT ; Jump if no fixup needed

	PUSHW	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	push	INT00NXT_FVEC.FSEL ; Pass selector as word
	push	INT00NXT_FVEC.FOFF ; ...  offset   as dword

LINT00_STR struc

	dd	?		; Next EIP
	dw	?		; ...  CS
LINT00_DS dw	?		; Caller's DS

LINT00_STR ends

	mov	ds,[esp].LINT00_DS ; Restore
	assume	ds:nothing	; Tell the assembler about it

	RETFD			; Jump to next interrupt
;;;;;;; jmp	INT00NXT_FVEC	; Jump to next interrupt

	jmp	near ptr INT00	; In case we jumped to a task gate

INT00_DPMI_FAULT:
	PUSHD	0		; Put pseudo-error code onto stack

; The stack is mapped by INTDPF_STR if we came from DPMI,
; or FLT_STR if we came from MAX.

	mov	[esp].INTDPF_INTNO,4*00h + offset PGROUP:INTPROC00Z ; Mark as INT 00h

	jmp	INTCOM_DPMI_FAULT ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT00	endp			; End INT00 procedure
	FPPROC	INT04 -- INTO Overflow Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

INTO overflow interrupt handler

If we're called from VM,
   If there's a DPMI client active and the primary client has hooked
     this exception, give it a crack at it.
   Otherwise, continue with INTPROC04.
If we're called from PM and there's a DPMI client active,
   give it a crack at this exception.
Otherwise, continue with INTPROC04.

|

; The stack is mapped by NRM_STR

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit VM86 mode?
	jz	short INT04_PM	; Jump if not

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_PVFHOOK[04h/8],1 shl (04h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT04_ORIG ; Jump if not

	PUSHD	0		; Pass pseudo-error code

; The MAX stack is consists of (from bottom up) an error code
; followed by INTCOM_STR.

	mov	[esp].INTDPF_INTNO,4*04h + offset PGROUP:INTPROC00Z ; Mark as INT 04h

	jmp	near ptr VMFLTCOM ; Jump to common code


INT04_ORIG:
	jmp	INTPROC04	; Jump if so (call as VM INT 04h)


INT04_PM:

; If there's a DPMI client active, give it a crack at this exception

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	je	short INT04_ORIG ; Jump if no DPMI clients active

	PUSHD	0		; Put pseudo-error code onto stack

; The stack is mapped by INTDPF_STR if we came from DPMI,
; or FLT_STR if we came from MAX.

	mov	[esp].INTDPF_INTNO,4*04h + offset PGROUP:INTPROC00Z ; Mark as INT 04h

	jmp	INTCOM_DPMI_FAULT ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT04	endp			; End INT04 procedure
	FPPROC	INT05 -- BOUND Instruction Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

BOUND instruction interrupt handler

If we're called from VM,
   If there's a DPMI client active and the primary client has hooked
     this exception, give it a crack at it.
   Otherwise, continue with INTPROC05.
If we're called from PM and there's a DPMI client active,
   give it a crack at this exception.
Otherwise, continue with INTPROC05.

|

; The stack is mapped by NRM_STR

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit VM86 mode?
	jz	short INT05_PM	; Jump if not

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_PVFHOOK[05h/8],1 shl (05h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT05_ORIG ; Jump if not

	PUSHD	0		; Pass pseudo-error code

; The MAX stack is consists of (from bottom up) an error code
; followed by INTCOM_STR.

	mov	[esp].INTDPF_INTNO,4*05h + offset PGROUP:INTPROC00Z ; Mark as INT 05h

	jmp	near ptr VMFLTCOM ; Jump to common code

INT05_ORIG:
	jmp	INTPROC05	; Jump if so (call as VM INT 05h)

INT05_PM:

; If there's a DPMI client active, give it a crack at this exception

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	je	short INT05_ORIG ; Jump if no DPMI clients active

	PUSHD	0		; Put pseudo-error code onto stack

; The stack is mapped by INTDPF_STR if we came from DPMI,
; or FLT_STR if we came from MAX.

	mov	[esp].INTDPF_INTNO,4*05h + offset PGROUP:INTPROC00Z ; Mark as INT 05h

	jmp	INTCOM_DPMI_FAULT ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT05	endp			; End INT05 procedure
	FPPROC	INT10 -- Video Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Video interrupt handler

If we're called from VM, continue on (the code at INTCOM_DPMI_INT
   will call any active DPMI clients).

If we're called from PM, and there are no DPMI clients active,
   pass the call through our translation services.

If we're called from PM, and there are DPMI clients active,
   give them a crack at this interrupt.  If we regain control,
   pass the call through our translation services.

On entry:

SS:ESP	==>	INTCOM_STR (if we're called from VM86 mode)
SS:ESP	==>	INTDPI_STR (if we're called from DPMI)

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].INTCOM_EFL.EHI,mask $VM ; Izit from VM86 mode?
	jz	near ptr INT10_DPMI ; No, run through our translator

	EXITDPL 10,VM		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT10	endp			; End INT10 procedure
	FPPROC	INT15 -- BIOS Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

BIOS function interrupt handler.

If we're called from VM, continue on (the code at INTCOM_DPMI_INT
   will call any active DPMI clients).

If we're called from PM, and there are no DPMI clients active,
   pass the call through our translation services.

If we're called from PM, and there are DPMI clients active,
   give them a crack at this interrupt.  If we regain control,
   pass the call through our translation services.

On entry:

AH	=	DOS function code
SS:ESP	==>	INTCOM_STR (if we're called from VM86 mode)
SS:ESP	==>	INTDPI_STR (if we're called from DPMI)

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit from VM86 mode?
	jz	near ptr INT15_DPMI ; No, run through our translator

;;;	    cmp     ah,87h	    ; Izit Move Extended Memory?
;;;	    jne     short INT15_X87 ; Jump if not
;;;
;;; ; Emulate BIOS Block Move
;;;
;;;	    PUSHD   0		    ; Push pseudo-error code
;;;	    pushad		    ; Save all EGPs
;;;	    mov     ebp,esp	    ; SS:EBP ==> INTXX_STR
;;;
;;; ; Using the GDT at ES:SI (VM addresses), move CX words
;;; ; from MDTE_DS to MDTE_ES
;;;
;;;	    movzx   ebx,[ebp].INTXX_ES ; Get GDT segment
;;;	    shl     ebx,4-0	    ; Convert from paras to bytes
;;;	    movzx   eax,[ebp].INTXX_ESI.ELO ; Get GDT offset
;;;	    add     ebx,eax	    ; AGROUP:EBX ==> GDT
;;;
;;;	    SETDATA ds		    ; Get DGROUP data selector
;;;	    assume  ds:DGROUP	    ; Tell the assembler about it
;;;
;;;	    mov     es,SEL_4GB	    ; Get AGROUP data selector
;;;	    assume  es:AGROUP	    ; Tell the assembler about it
;;;
;;;	    mov     ah,AGROUP:[ebx].MDTE_DS.DESC_BASE3 ; Get base address bits 24-31
;;;	    mov     al,AGROUP:[ebx].MDTE_DS.DESC_BASE2 ; ...		       16-23
;;;	    shl     eax,16	    ; Shift to high-order word
;;;	    mov     ax,AGROUP:[ebx].MDTE_DS.DESC_BASE01 ; ...		       0-15
;;;	    mov     esi,eax	    ; AGROUP:ESI ==> source
;;;
;;;	    mov     ah,AGROUP:[ebx].MDTE_ES.DESC_BASE3 ; Get base address bits 24-31
;;;	    mov     al,AGROUP:[ebx].MDTE_ES.DESC_BASE2 ; ...		       16-23
;;;	    shl     eax,16	    ; Shift to high-order word
;;;	    mov     ax,AGROUP:[ebx].MDTE_ES.DESC_BASE01 ; ...		       0-15
;;;	    mov     edi,eax	    ; AGROUP:EDI ==> destin
;;;
;;;	    movzx   ecx,cx	    ; Zero to use as dword
;;;	rep movs    AGROUP:[edi].ELO,AGROUP:[esi].ELO ; Move the data
;;;
;;; ; Mark as successful
;;;
;;;	    mov     [ebp].INTXX_EAX.ELO.HI,0 ; AH=0
;;;	    and     [ebp].INTXX_EFL,not (mask $CF) ; CF=0
;;;
;;;	    popad		    ; Restore
;;;
;;;	    add     esp,type INTXX_ERR ; Strip pseudo-error code
;;;
;;;	    iretd		    ; Continue execution
;;;
;;;
;;; INT15_X87:
	EXITDPL 15,VM		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT15	endp			; End INT15 procedure
;;;	    FPPROC  INT16 -- Keyboard Services Interrupt Handler
;;;	    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;; COMMENT|
;;;
;;; Keybaord services interrupt handler.
;;;
;;; If we're called from VM, continue on (the code at INTCOM_DPMI_INT
;;;    will call any active DPMI clients).
;;;
;;; If we're called from PM, and there are no DPMI clients active,
;;;    pass the call through our translation services.
;;;
;;; If we're called from PM, and there are DPMI clients active,
;;;    give them a crack at this interrupt.  If we regain control,
;;;    pass the call through our translation services.
;;;
;;; On entry:
;;;
;;; AH	    =	    DOS function code
;;; SS:ESP  ==>     INTCOM_STR (if we're called from VM86 mode)
;;; SS:ESP  ==>     INTDPI_STR (if we're called from DPMI)
;;;
;;; |
;;;
;;;	    call    RESETVARS	    ; Keep variables up-to-date
;;;
;;;	    test    [esp].NRM_EFL.EHI,mask $VM ; Izit from VM86 mode?
;;;	    jz	    near ptr INT16_DPMI ; No, run through our translator
;;;
;;;	    EXITDPL 16,VM	    ; Continue with next handler or GP Fault
;;;	    assume  ds:nothing	    ; Tell the assembler about it
;;;
;;;	    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;
;;; INT16   endp		    ; End INT16 procedure
	FPPROC	INT1C -- Secondary Timer Tick Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Secondary timer tick handler

On entry:

SS:ESP	==>	INTCOM_STR

|

	call	RESETVARS	; Keep variables up-to-date

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	BSActive,0	; Is paging active?
	je	short INT1C_ORIG ; Jump if not

	dec	BSAgeClock	; Count out one fewer timer tick
	jnz	short INT1C_ORIG ; Jump if it's not our time as yet

	REGSAVE <ax>		; Save register

	mov	ax,BSAgeMax	; Get maximum time
	mov	BSAgeClock,ax	; Set for next time

	call	PPM_AGE_PAGES	; Age 'em

	REGREST <ax>		; Restore
INT1C_ORIG:
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	EXITDPL 1C		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT1C	endp			; End INT1C procedure
	FPPROC	INT20 -- DOS Terminate Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DOS terminate interrupt handler

If we're called from VM, continue on (the code at INTCOM_DPMI_INT
   will call any active DPMI clients).

If we're called from PM, and there are no DPMI clients active,
   ignore the call (MAX did this?).

If we're called from PM, and there are DPMI clients active,
   give them a crack at this interrupt.  If we regain control,
   ignore the call.

On entry:

SS:ESP	==>	INTCOM_STR (if we're called from VM86 mode)
SS:ESP	==>	INTDPI_STR (if we're called from DPMI)

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].INTCOM_EFL.EHI,mask $VM ; Izit from VM86 mode?
	jnz	short INT20_ORIG ; Jump if so (call as VM INT 20h)

; If the caller is at PL0, don't pass on to any DPMI clients

	test	[esp].INTDPI_CS,mask $PL ; Izit at PL0?
	jz	short INT20_INTRETPM ; Jump if so

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_CPIHOOK[20h/8],1 shl (20h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT20_INTRETPM ; Jump if not

; The stack is mapped by INTDPI_STR

	mov	[esp].INTDPI_INTNO,4*20h + offset PGROUP:INTPROC00Z ; Mark as INT 20h

	push	@PMINTCOM_NRM	; Use application stack
	jmp	near ptr PMINTCOM ; Jump to common code


	public	INT20_INTRETPM
INT20_INTRETPM:
	iretd			; Return to caller (PM only)


INT20_ORIG:
	EXITDPL 20,VM		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT20	endp			; End INT20 procedure
	FPPROC	INT21 -- DOS Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DOS function interrupt handler.

If we're called from VM, continue on (the code at INTCOM_DPMI_INT
   will call any active DPMI clients).

If we're called from PM, and there are no DPMI clients active,
   pass the call through our translation services.

If we're called from PM, and there are DPMI clients active,
   give them a crack at this interrupt.  If we regain control,
   pass the call through our translation services.

On entry:

AH	=	DOS function code
SS:ESP	==>	INTCOM_STR (if we're called from VM86 mode)
SS:ESP	==>	INTDPI_STR (if we're called from DPMI)

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit from VM86 mode?
	jz	near ptr INT21_DPMI ; No, run through our translator

	EXITDPL 21,VM		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT21	endp			; End INT21 procedure
	NPPROC	INT22DEF -- Terminate Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Terminate interrupt handler

This code is entered from DPMI_SIMRET.

We are called only when a client has terminated in VM but not in PM.
This can happen if the client has installed an INT 23h/24h handler
in VM and it terminated there without reflecting to PM.  Our job is
to terminate in PM.

On entry:

AGROUP:EAX ==>	 HPDA
SS:EBP	==>	INTXX_STR

The PL3 stack has AX pushed onto it with the exit return code
the AX in INTXX_EAX.ELO.

|

; Restore the address of the previous INT 22h handler into the VM IDT.

	mov	ebx,AGROUP:[eax].HPDA_I22VEC ; Get the previous INT 22h handler

	assume	gs:INTVEC	; Tell the assembler about it
	mov	INT00_VEC[22h*(type INT00_VEC)],ebx ; Restore
	assume	gs:AGROUP	; Tell the assembler about it

; Pop the old AX from the stack and restore it

	movzx	ebx,[ebp].INTXX_SS ; Get caller's SS
	shl	ebx,4-0 	; Convert from paras to bytes
	movzx	ecx,[ebp].INTXX_ESP.ELO ; Get caller's SP

	mov	bx,AGROUP:[ebx+ecx] ; Get the original AX
	xchg	bx,[ebp].INTXX_EAX.ELO ; Swap with EXITRC value

	add	[ebp].INTXX_ESP.ELO,2 ; Strip from the stack

; Because the exit return code is available only once (why, why, why?),
; we must save the return code back into our resident INT 21h handler
; so we can return it the next time someone asks.

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	eax,HIMEM_La	; Get linear address of high DOS memory

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	assume	gs:YGROUP	; Tell the assembler about it
	mov	EXITRCHI[eax],bx ; Save into high DOS
	or	MSC_FLAG[eax],@MSC_GETRC ; Tell 'em to return the saved value
				; the next time
	assume	gs:AGROUP	; Tell the assembler about it
	assume	ds:nothing	; Tell the assembler about it

; Check the return code in BH:	if we terminated because of INT 23h/24h,
; terminate the DPMI application.  Otherwise, ignore this call.

	cmp	bh,@GETRC_I23	; Izit an INT 23h termination?
	je	short @F	; Jump if so

	cmp	bh,@GETRC_I24	; Izit an INT 24h termination?
				; Fall through with ZF significant
@@:
	popad			; Restore all EGP registers

	lea	esp,[esp+(size INTXX_ERR)] ; Strip pseudo-error code
	jne	short INT22_IRETD ; Jump if not error termination

; The stack is mapped by INTCOM_STR

	mov	[esp].INTCOM_INTNO,4*22h + offset PGROUP:INTPROC00Z ; Mark as INT 22h

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jne	near ptr INT22_INTRETPM_ABORT ; Jump if so to common abort code
INT22_IRETD:
	iretd			; Return to caller (PM only)
				; (which jumps to the next handler)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT22DEF endp			; End INT22DEF procedure
	FPPROC	INT23 -- Ctrl-Break Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Ctrl-Break interrupt handler

Because when paging is active we switch to the PSP
in which we opened the swapfile (the DPMI client),
we can't allow Ctrl-Break to terminate the client.
Thus if paging is active (meaning we switched PSPs),
we ignore this event by returning to the caller.

We take note of the event, however.  If Ctrl-Break
is pressed during swapfile initialization, we'll
simulate an Int 23 on return from client initialization.

On entry:

SS:ESP	==>	INTCOM_STR (if we're called from VM86 mode)

|

	call	RESETVARS	; Keep variables up-to-date

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	bt	PageIOActive,0	; Izit active?
	jnc	short @F	; Jump if not

	or	VMM_FLAG,@VMM_CTRLBREAK ; Mark as Ctrl-Break pressed

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Return to caller (PM only), ignoring the event


	assume	ds:DGROUP	; Tell the assembler about it
@@:
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	EXITDPL 23		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT23	endp			; End INT23 procedure
	NPPROC	INT23DEF -- Ctrl-Break Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Ctrl-Break interrupt handler

This code is entered from DPMI_SIMRET.

If there are no DPMI clients active, continue on.

If there are DPMI clients active, give them a crack at this interrupt.
   When we regain control, if the handler made a decision, take that
   action.  Otherwise, terminate the DPMI client.

On entry:

SS:EBP	==>	INTXX_STR

|

	popad			; Restore all EGP registers

	add	esp,size INTXX_ERR ; Strip pseudo-error code

; The stack is mapped by INTCOM_STR

	mov	[esp].INTCOM_INTNO,4*23h + offset PGROUP:INTPROC00Z ; Mark as INT 23h

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	jne	short @F	; Jump if so

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Return to caller (PM only)
				; (which jumps to the next handler)


	assume	ds:DGROUP	; Tell the assembler about it
@@:
	mov	INT23_TYP,@INT23_ABORT ; Set to special value in case
				; there's no DPMI client hooking INT 23h or
				; there is, but the client exits via JMPF/CALLF
				; so we terminate the client.

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	test	DPMI_CPIHOOK[23h/8],1 shl (23h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT23_INTRETPM ; Jump if not

; The stack is mapped by INTCOM_STR

	push	@PMINTCOM_LPM	; Use LPM stack
	jmp	near ptr PMINTCOM ; Jump to common code

COMMENT|

Enter here from one of the following situations:

1.  From above with the PL0 stack mapped by INTCOM_STR from the
    original INT 23h in VM (no decision, so we terminate).

2.  From DPMI_INTRET when the DPMI client returns control to us via
    JMPF/CALLF with the PL0 stack mapped by INTDPI_STR (no decision,
    so we terminate).

3.  From DPMI_INTRET when the DPMI client returns control to us via
    RETF/D or IRET/D with the PL0 stack mapped by INTCOM_STR from the
    original INT 23h (ignore or abort).

In all cases, INT23_TYP contains an action code.

Cases #1 and #3 have the $VM bit set, case #2 does not.

|

	public	INT23_INTRETPM
INT23_INTRETPM:
	test	[esp].INTDPI_EFL.EHI,mask $VM ; Izit from VM?
	jnz	short INT23_INTRETPM1 ; Jump if so

; Make the stack look like STC/RETF to mark as terminating

	or	[esp].INTDPI_EFL.ELO,mask $CF ; CF=1

; If it's a 16-bit client, subtract 2 (size of FL)
; If it's a 32-bit client, subtract 4 (size of EFL)

	xchg	eax,[esp].INTDPI_ESP ; Get caller's return ESP

	sub	ax,2		; Assume 16-bit client

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPE16 ; Izit a 16-bit client?
	je	short @F	; Jump if so

	sub	ax,4-2		; It's a 32-bit client
@@:
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	xchg	eax,[esp].INTDPI_ESP ; Set new ESP, restore EAX

	iretd			; Return to caller (PM only) to complete the cycle


	assume	ds:DGROUP	; Tell the assembler about it
INT23_INTRETPM1:
	cmp	INT23_TYP,@INT23_IGNORE ; Should we ignore it?
	je	short INT23_INTRETPM_IGNORE ; Jump if so

; Fall through if we're to abort the client

; The check for CF=1 if the client returns via RETF/D
; is performed in DPMI_INTRET.

; Tell DOS that we're aborting by returning to the address
; in the HPDA which does STC/RETF.

	mov	[esp].INTCOM_EIP,dword ptr HPDA_I23STC ; Mark as aborting
INT22_INTRETPM_ABORT:
INT24_INTRETPM_ABORT:
	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	SAVE_EAX,eax	; Save for a moment
	mov	eax,PCURTSS	; Get offset in DGROUP of the current TSS
	mov	eax,DGROUP:[eax].DPTSS_PLNKTSS ; Get offset in DGROUP of prev TSS
	mov	DGROUP:[eax].TSS_ESP,esp ; Save to use after IRET NT below
	mov	eax,SAVE_EAX	; Restore

; If there are any activities which need to be done at
; termination time when PCURTSS and TR match, now's the time

	call	DPMIFN_TERMINATE ; Handle termination (note IF=0 upon return)
	assume	ds:nothing,es:DGROUP  ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; ...

; Tell our terminate code that we're terminating normally,
; not to switch stacks, and to return to the caller
; Note that we set these bits after calling DPMIFN_TERMINATE as it
; restores the previous I31_FLAG values.

	or	I31_FLAG,(mask $I31_EXIT)     or \
			 (mask $I31_NOSWITCH) or \
			 (mask $I31_RETCALL)

;;; ; Set NT bit and IRET to it to effect task switch
;;;
;;;	     pushfd		    ; Save flags
;;;	     or      [esp].ELO,mask $NT ; Set the NT bit
;;;	     popfd		    ; Put it into effect
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

LINT24_STR struc

	dd	?		; Return offset
	dw	?		; ...	 selector
LINT24_DS dw	?		; Original DS

LINT24_STR ends

	mov	eax,SAVE_EAX	; Restore

	mov	ds,[esp].LINT24_DS ; Restore
	assume	ds:nothing	; Tell the assembler about it

	retf			; Continue with next

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing


; Ignore the event

INT23_INTRETPM_IGNORE:

; Tell DOS that we're ignoring by returning to the address
; in the HPDA which does CLC/RETF.

	mov	[esp].INTCOM_EIP,dword ptr HPDA_I23CLC ; Mark as ignoring
INT24_INTRETPM_IGNORE:
INT24_INTRETPM_REFLVM:
	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	push	PVMTSS		; Pass offset in DGROUP of the 1st TSS
	call	DPMIFN_LMSW	; Put MSW and INT 07h values into effect

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	ERM_FVEC	; Return to caller in VM

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT23DEF endp			; End INT23DEF procedure
	FPPROC	INT24 -- Critical Error Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Critical Error interrupt handler

Because when paging is active we switch to the PSP
in which we opened the swapfile (the DPMI client),
we can't allow Critical Error to terminate the client.
Thus if paging is active (meaning we switched PSPs),
we fail this event by returning to the caller.

On entry:

SS:ESP	==>	INTCOM_STR (if we're called from VM86 mode)

|

	call	RESETVARS	; Keep variables up-to-date

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	bt	PageIOActive,0	; Izit active?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jnc	short INT24_ORIG ; Jump if not

	mov	al,@INT24_RETRY ; Tell 'em we're retrying the DOS call

;;;;;;; iretd			; Return to caller, ignoring the event
;;;;;;; SWATMAC ERR,PM		; *FIXME*

	jmp	ERM_FVEC	; Return to caller in VM

	iretd			; *DEBUG* -- For debugging


INT24_ORIG:
	EXITDPL 24		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT24	endp			; End INT24 procedure
	NPPROC	INT24DEF -- Critical Error Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Critical error interrupt handler

This code is entered from DPMI_SIMRET.

If there are no DPMI clients active, continue on.

If there are DPMI clients active, give them a crack at this interrupt.
   When we regain control, if the handler made a decision, take that
   action.  Otherwise, pass the buck to VM (which, presumably,
   displays the usual "Abort, Retry, Ignore, Fail" message).

On entry:

AH	=	flags as in I24_REC
SS:ESP	==>	INTXX_STR (if we're called from VM86 mode)

|

	popad			; Restore all EGP registers

	add	esp,size INTXX_ERR ; Strip pseudo-error code

; The stack is mapped by INTCOM_STR

	mov	[esp].INTCOM_INTNO,4*24h + offset PGROUP:INTPROC00Z ; Mark as INT 24h

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	jne	short @F	; Jump if so

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Return to caller (PM only)
				; (which jumps to the next handler)

	assume	ds:DGROUP	; Tell the assembler about it
@@:

; Save flags in AH in the DPTSS to reference later.
; Save the value in BP in the DPTSS to restore later.

	push	esi		; Save for a moment

	mov	esi,PCURTSS	; Get offset in DGROUP of the current TSS
	mov	DGROUP:[esi].DPTSS_I24FLG,ah ; Save for later use
	mov	DGROUP:[esi].DPTSS_I24BP,bp ; Save to restore later

	pop	esi		; Restore

COMMENT|

Given that we come here only if no decision has been made in VM, the
following paths through this code are possible:

No PM handler:

* Jumps to INT24_INTRETPM (with $VM=1).

PM handler makes a decision (Abort, Retry, Ignore, Fail):

* Code in DPMI_INTRET saves a value into INT24_TYP based on the
  handler's decision and jumps to INT24_INTRETPM (with $VM=1).

PM handle does not make a decision (JMPF/CALLF):

* Code in DPMI_INTRET does not save a value into INT24_TYP, but it
  does jump to INT24_INTRETPM (with $VM=0).

  To complete the cycle, this case is detected at INT24_INTRETPM
  ($VM=0), sets INT24_TYP to @INT24_REFLVM and IRETDs (to complete the
  JMPF/CALLF).	Eventually, the code at DPMI_INTRET is entered with
  INT24_TYP set to a special value, and jumps to INT24_INTRETPM (with $VM=1).

If a DPMI client has hooked INT 24h, the initial value for INT24_TYP
is set to anything other than @INT24_REFLVM so we can distinguish it
from the case where we save @INT24_REFLVM into INT24_TYP.  Otherwise,
the initial value is set to @INT24_REFLVM so we reflect the decision to
VM.

|

	mov	INT24_TYP,@INT24_REFLVM ; Set to special value so we reflect
				; the decision to VM.

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	test	DPMI_CPIHOOK[24h/8],1 shl (24h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	jz	short INT24_INTRETPM ; Jump if not

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	INT24_TYP,@INT24_FAIL ; Set to any value other than REFLVM

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

; The stack is mapped by INTCOM_STR

	push	@PMINTCOM_LPM	; Use LPM stack
	jmp	near ptr PMINTCOM ; Jump to common code

COMMENT|

Enter here from one of the following situations:

1.  From above with the PL0 stack mapped by INTCOM_STR from the
    original INT 24h (pass the buck to VM).

2.  From DPMI_INTRET when the DPMI client returns control to us via
    JMPF/CALLF with the PL0 stack mapped by INTDPI_STR (pass the buck
    to VM).

3.  From DPMI_INTRET when the DPMI client returns control to us via
    IRET/D with the PL0 stack mapped by INTCOM_STR from the original
    INT 24h (ignore, retry, abort or fail).

In all cases, INT24_TYP contains an action code.

Case #2 is distinguished by the $VM bit in INTCOM_EFL or INTDPI_EFL
which are both in the same location.  The other cases are handled
identically and don't need to be distinguished.

|

	public	INT24_INTRETPM
INT24_INTRETPM:
	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	[esp].INTDPI_EFL.EHI,mask $VM ; Izit from VM?
	jnz	short INT24_INTRETPM1 ; Jump if so

	mov	INT24_TYP,@INT24_REFLVM ; Set to special value so we reflect
				; the decision to VM.

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Return to caller (PM only) to complete the cycle


	assume	ds:DGROUP	; Tell the assembler about it
INT24_INTRETPM1:

; If there was a PM handler, we translated the value in BP to
; a selector; restore the original value now.

	push	esi		; Save for a moment

	mov	esi,PCURTSS	; Get offset in DGROUP of the current TSS
	mov	bp,DGROUP:[esi].DPTSS_I24BP ; Restore original value

	pop	esi		; Restore

	cmp	INT24_TYP,@INT24_REFLVM ; Should we pass the buck to VM?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	je	near ptr INT24_INTRETPM_REFLVM ; Jump if so

	mov	[esp].INTCOM_EIP,dword ptr HPDA_I24IRET ; Save as return address

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	al,INT24_TYP	; Get the type code when we return

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	cmp	al,@INT24_ABORT ; Should we abort the program?
	je	near ptr INT24_INTRETPM_ABORT ; Jump if so (join common abort code)

	jmp	INT24_INTRETPM_IGNORE ; Join common return code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT24DEF endp			; End INT24DEF procedure
	FPPROC	INT25 -- DOS Absolute Disk Read Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DOS absolute disk read interrupt handler

If we're called from VM, continue on (the code at INTCOM_DPMI_INT
   will call any active DPMI clients).

If we're called from PM, and there are no DPMI clients active,
   ignore the call (MAX did this?).

If we're called from PM, and there are DPMI clients active,
   give them a crack at this interrupt.  If we regain control,
   ignore the call.

On entry:

SS:ESP	==>	INTCOM_STR (if we're called from VM86 mode)
SS:ESP	==>	INTDPI_STR (if we're called from DPMI)

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].INTCOM_EFL.EHI,mask $VM ; Izit from VM86 mode?
	jnz	short INT25_ORIG ; Jump if so (call as VM INT 25h)

; If the caller is at PL0, don't pass on to any DPMI clients

	test	[esp].INTDPI_CS,mask $PL ; Izit at PL0?
	jz	short INT25_INTRETPM ; Jump if so

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_CPIHOOK[25h/8],1 shl (25h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT25_INTRETPM ; Jump if not

; The stack is mapped by INTDPI_STR

	mov	[esp].INTDPI_INTNO,4*25h + offset PGROUP:INTPROC00Z ; Mark as INT 25h

	push	@PMINTCOM_NRM	; Use application stack
	jmp	near ptr PMINTCOM ; Jump to common code


	public	INT25_INTRETPM
INT25_INTRETPM:
	public	INT26_INTRETPM
INT26_INTRETPM:


INT25_STR struc

	dd	?		; Callers' EBP
INT25_NXT db	(size INTDPI_STR) dup (?) ; Remainder of the stack

INT25_STR ends

; Set CF in the return flags and put the original flags onto the stack

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ds>	; Save for a moment

; Note that if we're not called by a DPMI client, there's no
; ring transition and INTDPI_ESP and above are not present.
; On the other hand, we would like to think that none of our
; own load modules would make such a silly call.

	sub	[ebp].INT25_NXT.INTDPI_ESP,2 ; Make room for original flags

; If the B-bit in the stack selector is clear, zero the upper
; word of the stack offset.

	lea	eax,[ebp].INT25_NXT.INTDPI_ESP ; SS:EAX ==> SS|ESP from PL3
	push	eax		; Pass the offset
	call	DPMIFN_ESPMOD	; Clear the high-order word of the PL3 ESP
				; if the B-bit in the PL3 SS is clear
	lds	eax,[ebp].INT25_NXT.INTDPI_ESP.EDF ; DS:EAX ==> caller's stack
	assume	ds:nothing	; Tell the assembler about it

	push	[ebp].INT25_NXT.INTDPI_EFL.ELO ; Get original flags
	pop	ds:[eax].ELO	; Save onto caller's stack

	or	[ebp].INT25_NXT.INTDPI_EFL.ELO,mask $CF ; CF=1

	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	pop	ebp		; Restore

	iretd			; Return to caller (PM only)


INT25_ORIG:
	EXITDPL 25,VM		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT25	endp			; End INT25 procedure
	FPPROC	INT26 -- DOS Absolute Disk Write Interrupt handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DOS absolute disk write interrupt handler

If we're called from VM, continue on (the code at INTCOM_DPMI_INT
   will call any active DPMI clients).

If we're called from PM, and there are no DPMI clients active,
   ignore the call (MAX did this?).

If we're called from PM, and there are DPMI clients active,
   give them a crack at this interrupt.  If we regain control,
   ignore the call.

On entry:

SS:ESP	==>	INTCOM_STR (if we're called from VM86 mode)
SS:ESP	==>	INTDPI_STR (if we're called from DPMI)

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].INTCOM_EFL.EHI,mask $VM ; Izit from VM86 mode?
	jnz	short INT26_ORIG ; Jump if so (call as VM INT 26h)

; If the caller is at PL0, don't pass on to any DPMI clients

	test	[esp].INTDPI_CS,mask $PL ; Izit at PL0?
	jz	short INT26_INTRETPM ; Jump if so

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_CPIHOOK[26h/8],1 shl (26h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	near ptr INT26_INTRETPM ; Jump if not

; The stack is mapped by INTDPI_STR

	mov	[esp].INTDPI_INTNO,4*26h + offset PGROUP:INTPROC00Z ; Mark as INT 26h

	push	@PMINTCOM_NRM	; Use application stack
	jmp	near ptr PMINTCOM ; Jump to common code


INT26_ORIG:
	EXITDPL 26,VM		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT26	endp			; End INT26 procedure
	FPPROC	INT27 -- DOS TSR Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DOS TSR interrupt handler

If we're called from VM, continue on (the code at INTCOM_DPMI_INT
   will call any active DPMI clients).

If we're called from PM, and there are no DPMI clients active,
   ignore the call (MAX did this?).

If we're called from PM, and there are DPMI clients active,
   give them a crack at this interrupt.  If we regain control,
   ignore the call.

On entry:

SS:ESP	==>	INTCOM_STR (if we're called from VM86 mode)
SS:ESP	==>	INTDPI_STR (if we're called from DPMI)

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].INTCOM_EFL.EHI,mask $VM ; Izit from VM86 mode?
	jnz	short INT27_ORIG ; Jump if so (call as VM INT 27h)

; If the caller is at PL0, don't pass on to any DPMI clients

	test	[esp].INTDPI_CS,mask $PL ; Izit at PL0?
	jz	short INT27_INTRETPM ; Jump if so

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_CPIHOOK[27h/8],1 shl (27h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT27_INTRETPM ; Jump if not

; The stack is mapped by INTDPI_STR

	mov	[esp].INTDPI_INTNO,4*27h + offset PGROUP:INTPROC00Z ; Mark as INT 27h

	push	@PMINTCOM_NRM	; Use application stack
	jmp	near ptr PMINTCOM ; Jump to common code


	public	INT27_INTRETPM
INT27_INTRETPM:
	iretd			; Return to caller (PM only)


INT27_ORIG:
	EXITDPL 27,VM		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT27	endp			; End INT27 procedure
	FPPROC	INT33 -- Mouse Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Mouse interrupt handler

If we're called from VM, continue on (the code at INTCOM_DPMI_INT
   will call any active DPMI clients).

If we're called from PM, and there are no DPMI clients active,
   pass the call through our translation services.

If we're called from PM, and there are DPMI clients active,
   give them a crack at this interrupt.  If we regain control,
   pass the call through our translation services.

On entry:

SS:ESP	==>	INTCOM_STR (if we're called from VM86 mode)
SS:ESP	==>	INTDPI_STR (if we're called from DPMI)

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].INTCOM_EFL.EHI,mask $VM ; Izit from VM86 mode?
	jz	near ptr INT33_DPMI ; No, run through our translator

	EXITDPL 33,VM		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT33	endp			; End INT33 procedure
	FPPROC	INT41 -- Windows Debugger Services
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Windows debugger services

If we're called from VM, continue on (the code at INTCOM_DPMI_INT
   will call any active DPMI clients).

If we're called from PM, and there are no DPMI clients active,
   ignore the call (MAX did this?).

If we're called from PM, and there are DPMI clients active,
   give them a crack at this interrupt.  If we regain control,
   ignore the call.

On entry:

SS:ESP	==>	INTCOM_STR (if we're called from VM86 mode)
SS:ESP	==>	INTDPI_STR (if we're called from DPMI)

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].INTCOM_EFL.EHI,mask $VM ; Izit from VM86 mode?
	jz	short INT41_INTRETPM ; Jump if not

	EXITDPL 41,VM		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	public	INT41_INTRETPM
INT41_INTRETPM:
	iretd			; Return to caller (PM only)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT41	endp			; End INT41 procedure
	FPPROC	INT4B -- VDS Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

VDS interrupt handler

If we're called from VM, continue on (the code at INTCOM_DPMI_INT
   will call any active DPMI clients).

If we're called from PM, and there are no DPMI clients active,
   pass the call through our translation services.

If we're called from PM, and there are DPMI clients active,
   give them a crack at this interrupt.  If we regain control,
   pass the call through our translation services.

On entry:

SS:ESP	==>	INTCOM_STR (if we're called from VM86 mode)
SS:ESP	==>	INTDPI_STR (if we're called from DPMI)

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].INTCOM_EFL.EHI,mask $VM ; Izit from VM86 mode?
	jz	near ptr INT4B_DPMI ; No, run through our translator

	EXITDPL 4B,VM		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT4B	endp			; End INT4B procedure
	FPPROC	INT67 -- VCPI/EMS Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

VCPI/EMS interrupt handler

If it's VCPI mode switch and there's a DPMI client active,
   swap back in the original CR3.
If it's VCPI presence detection and we're to lie, do so.

On entry:

SS:ESP	==>	INTCOM_STR (if we're called from VM86 mode)
SS:ESP	==>	INTDPI_STR (if we're called from DPMI)

|

	call	RESETVARS	; Keep variables up-to-date

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	ax,(@VCPI shl 8) or @VCPI_EPM ; Izit VCPI enter PM?
	jne	short @F	; Jump if not

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	je	short @F	; Jump if not

	push	PVMTSS		; Pass offset in DGROUP of VM TSS
	call	DPMIFN_SWITCHADDR ; Switch to the incoming address space

	jmp	short INT67_ORIG ; Continue on with next handler

@@:
	test	DPM_FLAG,mask $DPM_NOVCPI ; Are we failing VCPI calls?
	jz	short INT67_ORIG ; Jump if not

	cmp	ax,(@VCPI shl 8) or @VCPI_PRES ; Izit presence detection?
	jne	short INT67_ORIG ; Jump if not

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Return to caller (PM only) (fail the call)


	assume	ds:DGROUP	; Tell the assembler about it
INT67_ORIG:
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	EXITDPL 67		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT67	endp			; End INT67 procedure

PROG	ends			; End PROG segment

	MEND			; End DPMI_N31 module
