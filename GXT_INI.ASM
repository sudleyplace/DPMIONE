;' $Header$
	title	GXT_INI -- MMEXT Initialization Routines
	page	58,122
	name	GXT_INI

COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1988-2004 Sudley Place Software.

|
.386p
.xlist
	include MASM.INC
	include DOSCALL.INC
	include KEYCALL.INC
	include ASCII.INC
	include 386.INC
	include PTR.INC
	include ALLMEM.INC
	include MAXDEV.INC
	include VCPI.INC
	include CPUFLAGS.INC
	include PDTGRP.INC
	include INTVEC.INC

	include GXT_COM.INC
	include GXT_DRV.INC
	include GXT_HDR.INC
	include GXT_SEG.INC
	include GXT_SWT.INC
	include GXT_V2P.INC
NOVER_HTU = 1
	include VERSION.INC
.list

DATA16	segment use32 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	public	@GXT_INI_DATA16
@GXT_INI_DATA16 label byte	; Mark module start in .MAP file

	extrn	COMMON:tbyte
	include QMAX_FIL.INC

;;;;;;; extrn	RUD_IDTR:fword
;;;;;;; extrn	MMCODESEL:word
;;;;;;; extrn	MMSELS:dword
	extrn	LOADTAB:tbyte
	extrn	LOADTABIND:dword
	extrn	LOADTABLST:dword
	extrn	LOADCOUNT:dword

	extrn	PSWAT_FVEC:fword

	public	OLDINTxx_VEC
OLDINTxx_VEC dd 256 dup (?)	; Save area for original interrupt vectors

;;;	    public  INISTK_FVEC
;;; INISTK_FVEC df  ?		    ; Stack for INIT_PROT
;;;
;;;	    public  OLDSTK_FVEC
;;; OLDSTK_FVEC df  ?		    ; Save area for old stack
;;;
;;;	    public  LCLSTK_FVEC
;;; LCLSTK_FVEC df  ?		    ; Pointer to local stack *FIXME* initialize FSEL
;;;
	public	RM2PM_STK_FVEC
RM2PM_STK_FVEC df ?		; RM to PM stack ptr

DATA16	ends			; End DATA16 segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	cs:DGROUP,ds:DGROUP

	public	@GXT_INI_DATA
@GXT_INI_DATA:			; Mark module start in .MAP file

	extrn	XMSHNDL2:word
;;;;;;; extrn	MTDTE:qword
	extrn	LaPL0STK:dword
	extrn	PL0STK_SIZ:dword

	public	LCLINT00_FVEC,LCLINT00_ARB
LCLINT00_FVEC label fword	; Save area for INT 00h handler
	dd	offset PGROUP:LCL_INT00,?
LCLINT00_ARB db CPL0_INTR3 or CPL3 ; ...	    00h access rights byte

	align	4		; Ensure dword alignment

	public	OLDINT00_FVEC,OLDINT00_ARB
OLDINT00_FVEC df ?		; Save area for old INT 00h handler
OLDINT00_ARB db CPL0_INTR3 or CPL3 ; ...		    A/R byte

	public	INT00SIG
INT00SIG label	byte
	CALLPL0_SIG		; Define the signature
INT00SIG_LEN equ $-INT00SIG	; Length of ...

DATA	ends			; End DATA segment


NDATA	segment use16 dword public 'ndata' ; Start NDATA segment
	assume	ds:NGROUP

	extrn	MSG_LOADGXT:byte

NDATA	ends			; End NDATA segment


RCODE	segment use16 para public 'rcode' ; Start RCODE segment
	assume	cs:RGROUP

	extrn	ERM:near
	extrn	VCPEPM:tbyte

RCODE	ends			; End RCODE segment


P1ST	segment use32 byte public 'prog' ; Start P1ST segment
	assume	ds:PGROUP

	extrn	GXTINI:tbyte
	extrn	DEVLOAD:byte

P1ST	ends			; End P1ST segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP,ds:PGROUP

	public	@GXT_INI_PROG
@GXT_INI_PROG:			; Mark module start in .MAP file

	extrn	GETBASE:near

	public	ERM_FVEC
ERM_FVEC label	fword
	dd	offset RGROUP:ERM
	dw	DTE_CS

	FPPROC	INIT_PROT -- Protected Mode Initialization Code
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Protected mode initialization code.

|

	push	ds		; Save register

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

;;; ; Switch to a new stack so we don't impinge on the caller's stack
;;; ; *FIXME* -- probably not necessary -- delete the room for the stack
;;;
;;;	    mov     OLDSTK_FVEC.FOFF,esp ; Save to restore later
;;;	    mov     OLDSTK_FVEC.FSEL,ss ; ...
;;;
;;;	    mov     INISTK_FVEC.FSEL,ds ; Save as LCL stack selector
;;;
;;;	    lss     esp,INISTK_FVEC ; Switch to our own stack
;;;	    assume  ss:nothing	    ; Tell the assembler about it
;;;
	pushad			; Save all EGP registers
	REGSAVE <es,gs> 	; Save registers

	mov	es,COMMON.FILE_4GB ; Get all memory selector
	assume	es:AGROUP	; Tell the assembler about it

; Clear the PL0 stack to known values so we can see
; how much is used by the program

	mov	edi,LaPL0STK	; ES:EDI ==> PL0 stack
	mov	ecx,PL0STK_SIZ	; Get stack size in bytes
	shr	ecx,2-0 	; Convert from bytes to dwords
	mov	eax,'CATS'      ; Set to this value
    rep stos	es:[edi].EDD	; Initialize the stack

; Initialize our handler selector

	mov	ax,cs		; Assume we're not INTRUDEing

;;;;;;; test	DEVLOAD,@DEVL_INTRUDE ; Are we INTRUDEing today?
;;;;;;; jz	short @F	; Jump if not
;;;;;;;
;;;;;;; mov	ax,MMCODESEL	; Get our future code selector
;;;@@:
	mov	LCLINT00_FVEC.FSEL,ax ; Save our selector

; Hook an interrupt so we can be called at INIT_VIRT time to
; initialize the load modules

; Establish addressibility to IDT

	sub	esp,size DTR_STR ; Make room on stack
	SIDTD	[esp].EDF	; Save IDTR on stack
	mov	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> IDT
	add	esp,size DTR_STR ; Strip from the stack

;;;;;;; test	DEVLOAD,@DEVL_INTRUDE ; Are we INTRUDEing today?
;;;;;;; jz	short @F	; Jump if not
;;;;;;;
;;;;;;; mov	ebx,RUD_IDTR.DTR_BASE ; Get base address
;;;@@:
	IDTMAC	00h,00,LCL,OLD	; IDT to OLD, LCL to IDT (EAX clobbered)

	REGREST <gs,es> 	; Restore
	assume	es:nothing,gs:nothing ; Tell the assembler about it
	popad			; Restore

;;;	    lss     esp,OLDSTK_FVEC ; Switch back to caller's stack
;;;	    assume  ss:nothing	    ; Tell the assembler about it
;;;
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	RETFD			; Return to caller (32-bit)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INIT_PROT endp			; End INIT_PROT procedure
	FPPROC	REST_PROT -- Restore Protected Mode Initialization
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Restore previous protected mode initializations

This routine is never called *FIXME*.

|

;;;;;;; REGSAVE <eax,ebx,ecx,edx,ds,es> ; Save registers
;;;;;;;
;;;;;;; SETDATA ds		; Set data selector into DS
;;;;;;; assume	ds:DGROUP	; Tell the assembler about it
;;;;;;;
;;;;;;; mov	es,COMMON.FILE_4GB ; Get all memory selector
;;;;;;; assume	es:AGROUP	; Tell the assembler about it
;;;;;;;
;;;;;;;
;;;;;;;
;;;;;;;
;;;;;;;
;;;;;;;
;;;;;;; REGREST <es,ds,edx,ecx,ebx,eax> ; Restore
;;;;;;; assume	ds:nothing,es:nothing ; Tell the assembler about it

	RETFD			; Return to caller (32-bit)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

REST_PROT endp			; End REST_PROT procedure
	FPPROC	LCL_INT00 -- Local INT 00h Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Local INT 00h handler

On entry:

SS:ESP	==>	EPRM_STR

|

INT00_STR struc

INT00_EGP db	(size PUSHAD_STR) dup (?) ; Caller's EGP registers
INT00_REST db	(size EPRM_STR) dup (?) ; The rest of the stack

INT00_STR ends


INT00_EIP equ	<INT00_REST.EPRM_EIP>	; Caller's EIP
INT00_CS  equ	<INT00_REST.EPRM_CS>	; ...	   CS w/filler
INT00_EFL equ	<INT00_REST.EPRM_EFL>	; ...	   EFL
INT00_ESP equ	<INT00_REST.EPRM_ESP>	; ...	   ESP
INT00_SS  equ	<INT00_REST.EPRM_SS>	; ...	   SS w/filler
INT00_ES  equ	<INT00_REST.EPRM_ES>	; ...	   ES w/filler
INT00_DS  equ	<INT00_REST.EPRM_DS>	; ...	   DS w/filler
INT00_FS  equ	<INT00_REST.EPRM_FS>	; ...	   FS w/filler
INT00_GS  equ	<INT00_REST.EPRM_GS>	; ...	   GS w/filler


	pushad			; Save all EGP registers
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <ds,es> 	; Save registers

	cld			; Ensure string ops forwards

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	mov	es,COMMON.FILE_4GB ; Get all memory selector
	assume	es:AGROUP	; Tell the assembler about it

; If this call isn't preceded by our signature, skip out

	lea	esi,INT00SIG	; DS:ESI ==> INT00 signature
	mov	ecx,INT00SIG_LEN ; ECX = length of ...

	movzx	edi,[ebp].INT00_CS ; Get caller's segment
	shl	edi,4-0 	; Convert from paras to bytes
	add	edi,[ebp].INT00_EIP ; Plus caller's EIP
	sub	edi,ecx 	; Back off to preceding bytes
	jc	near ptr LCL_INT00_ORIG ; Jump if not our signature

   repe cmps	INT00SIG[esi],AGROUP:[edi].LO ; Izit the same?
	jne	near ptr LCL_INT00_ORIG ; Jump if not

	add	[ebp].INT00_EIP,2 ; Skip over the DIV AX instruction

; Get the function # from BX

	mov	bx,[ebp].INT00_EGP.PUSHAD_EBX.ELO ; Get caller's BX

	cmp	bx,@GXTV2P_IPROT ; Izit call INIT_PROT?
	jne	short @F	; Jump if not

	call	INIT_PL0SS	; Handle PL0 stack

; Call PM initialization for load modules

	call	IPROT_LOAD	; Call INIT_PROT for all load modules

	jmp	short LCL_INT00_EXIT ; Join common exit code


@@:
	cmp	bx,@GXTV2P_GETTAB ; Izit get LOADTAB vaues?
	jne	short @F	; Jump if not

	call	GETTAB_LOAD	; Get the LOADTAB values

	jmp	short LCL_INT00_EXIT ; Join common exit code


@@:
;;;;;;; cmp	bx,@GXTV2P_RREAL ; Izit copy REST_REAL?
;;;;;;; jne	short @F	; Jump if not
;;;;;;;
;;;;;;; call	RREAL_COPY	; Copy REST_REAL code/data for module ESI
;;;;;;; 			; to ES:EDI
;;;;;;; jmp	short LCL_INT00_EXIT ; Join common exit code
;;;;;;;
;;;;;;;
@@:
	cmp	bx,@GXTV2P_RPROT ; Izit call REST_PROT?
	jne	short LCL_INT00_ORIG ; Jump if not

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	mov	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> GDT
	add	esp,size DTR_STR ; Strip from the stack

	call	RPROT_LOAD	; Call REST_PROT for all load modules

; Establish addressibility to IDT

	push	ebx		; Save linear address of the GDT

	sub	esp,size DTR_STR ; Make room on stack
	SIDTD	[esp].EDF	; Save IDTR on stack
	mov	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> IDT
	add	esp,size DTR_STR ; Strip from the stack

; Unhook INT 00h

	IDTMAC	00h,00,OLD	; OLD to IDT (EAX clobbered)

	pop	ebx		; Restore linear address of the GDT

;;;;;;; test	DEVLOAD,@DEVL_INTRUDE ; Are we INTRUDEing today?
;;;;;;; jz	short LCL_INT00_XINTRUDE ; Jump if not
;;;;;;;
;;;; After we zero our own selectors, we can't continue debugging
;;;;;;;
;;;;;;; mov	ecx,MMSELS	; Get # selectors to free
;;;;;;; movzx	edx,MMCODESEL	; Get the first selector (it's CS)
;;;@@:
;;;;;;; mov	eax,MTDTE.EDQLO ; Get the low-order dword
;;;;;;; mov	AGROUP:[ebx+edx].EDQLO,eax ; Restore
;;;;;;;
;;;;;;; mov	eax,MTDTE.EDQHI ; Get the high-order dword
;;;;;;; mov	AGROUP:[ebx+edx].EDQHI,eax ; Restore
;;;;;;;
;;;;;;; add	edx,type DESC_STR ; Skip to next DTE
;;;;;;;
;;;;;;; loop	@B		; Jump if more selectors to free
;;;LCL_INT00_XINTRUDE:
;;;;;;; jmp	short LCL_INT00_EXIT ; Join common exit code
;;;;;;;
;;;;;;;
LCL_INT00_EXIT:
	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	popad			; Restore

; If the VM bit is clear in the flags, we need to exit PM before returning

;;;;;;; test	[esp].IRETD_EFL,mask $VMHI ; Izit set?
;;;;;;; jnz	short @F	; Jump if so
;;;;;;;
	jmp	ERM_FVEC	; Enter RM
;;;;;;;
;;;@@:
;;;;;;; iretd			; Return to caller


LCL_INT00_ORIG:
	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	popad			; Restore

	PUSHW	ds		; Save for a moment

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	push	OLDINT00_FVEC.FSEL ; Pass selector
	push	OLDINT00_FVEC.FOFF ; ...  offset

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

LCL_INT00 endp			; End LCL_INT00 procedure
	NPPROC	INIT_PL0SS -- Handle PL0 Stack Selector
	assume	ds:DGROUP,es:AGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Handle PL0 stack selector

|

	REGSAVE <eax,ebx>	; Save registers

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	mov	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> GDT
	add	esp,size DTR_STR ; Strip from the stack

; Because we need to present a consistent interface to our clients,
; we set the B-bit in the PL0 stack selector.

	xor	eax,eax 	; Zero to use as dword
	str	ax		; Get the current Task Register

	push	eax		; Pass the selector
	call	GETBASE 	; Return with EAX = base address

	movzx	eax,AGROUP:[eax].TSS_SS0 ; Get the PL0 stack selector
	and	eax,not (mask $PL) ; Clear the Privilege Level bits

	btr	eax,$TI 	; Test and reset the Table Index bit
;;;;;;; jc	short ???	; Jump if it's in the LDT

	or	AGROUP:[ebx+eax].DESC_SEGLM1,mask $DTE_B ; Set the B-bit

	REGREST <ebx,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INIT_PL0SS endp 		; End INIT_PL0SS procedure
	NPPROC	IPROT_LOAD -- Call INIT_PROT For All Load Modules
	assume	ds:DGROUP,es:AGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Call INIT_PROT for all load modules

On entry:

SS:EBP	==>	INT00_STR

|

	pushad			; Save all EGP registers

;;;;; ; Establish addressibility to IDT
;;;;;
;;;;;	      sub     esp,size DTR_STR ; Make room on stack
;;;;;	      SIDTD   [esp].EDF       ; Save IDTR on stack
;;;;;	      mov     ebx,[esp].DTR_BASE ; AGROUP:EBX ==> IDT
;;;;;	      add     esp,size DTR_STR ; Strip from the stack
;;;;;
;;;;; ; If there's a preceding SWAT, it doesn't know about our INT 00h
;;;;; ; handler as an old int.	Some of the modules we are about to
;;;;; ; initialize might install their own interrupts, so we need to
;;;;; ; uninstall our handler, uninstall SWAT's IDT entries, re-install
;;;;; ; our handler, and then request SWAT to re-install its IDT entries.
;;;;;
;;;;;	 IDTMAC  00h,00,OLD	 ; OLD to IDT (EAX clobbered)
;;;;;
;;;;; ; Tell PSWAT we're about to change the IDT
;;;;;
;;;;;	      cmp     PSWAT_FVEC.FSEL,0 ; Izit valid?
;;;;;	      je      short @F	      ; Jump if not
;;;;;
;;;;;	      mov     eax,(@VCPI shl 8) or @SWAT_CHGIDT ; Pass function code
;;;;;	      call    PSWAT_FVEC      ; Restore our selectors to give the client
;;;;;				      ; clean slate
;;;;; @@:
;;;;;	 IDTMAC  00h,00,LCL,OLD  ; IDT to OLD, LCL to IDT (EAX clobbered)
;;;;;
;;;;; ; Tell PSWAT we're done changing the IDT
;;;;;
;;;;;	      cmp     PSWAT_FVEC.FSEL,0 ; Izit valid?
;;;;;	      je      short @F	      ; Jump if not
;;;;;
;;;;;	      mov     eax,(@VCPI shl 8) or @SWAT_CHGIDTZ ; Pass function code
;;;;;	      call    PSWAT_FVEC      ; Initialize our selectors
;;;;; @@:
;;;;;
; Call INIT_PROT in the same order as the modules were loaded

	mov	edi,LOADTABLST	; Get the last index
	mov	ecx,LOADCOUNT	; Get # load modules
;;;;;;; jecxz	IPROT_LOAD_EXIT ; Jump if no modules
	and	ecx,ecx 	; Any modules?
	jz	IPROT_LOAD_EXIT ; Jump if no modules
IPROT_LOAD_NEXT:
	mov	ebx,LOADTAB[edi].LOAD_MMLIN ; Get the MM-linear address
	mov	ax,LOADTAB[edi].LOAD_SEL1 ; Get the first selector (code)
	mov	AGROUP:[ebx].GXTHDR_IPROT.FSEL,ax ; Save in INIT_PROT
	mov	AGROUP:[ebx].GXTHDR_RPROT.FSEL,ax ; ...     REST_PROT
	mov	AGROUP:[ebx].GXTHDR_PM2RM_FVEC.FSEL,DTE_CS ; Save address of PM2RM handler

	movzx	edx,AGROUP:[ebx].GXTHDR_HDRSEG ; Get header segment in TSR area
	shl	edx,4-0 	; Convert from paras to bytes
	mov	AGROUP:[edx].GXTHDR_RM2PM_FVEC.FSEL,ax ; Save address of RM2PM entry point

; Save the CR3 selector in the module's GXTHDR

	movzx	edx,LOADTAB[edi].LOAD_SEL1 ; Get the first selector (code)
	sub	edx,size DESC_STR ; Back off to CR3 selector
	mov	AGROUP:[ebx].GXTHDR_SELCR3,dx ; Save for later use

	movzx	eax,COMMON.FILE_CR3 ; Get CR3 selector

	and	eax,eax 	; Izit empty?
	jz	short @F	; Jump if so

; Copy the linear address of selector in AX to selector in DX

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	mov	esi,[esp].DTR_BASE ; AGROUP:ESI ==> GDT
	add	esp,size DTR_STR ; Strip from the stack

	push	AGROUP:[esi+eax].EDQHI ; Copy high-order of GDT entry
	push	AGROUP:[esi+eax].EDQLO ; ...  low-...
	pop	AGROUP:[esi+edx].EDQLO ; ...
	pop	AGROUP:[esi+edx].EDQHI ; ...
@@:
	mov	al,GXTINI.MD_IBV0 ; Save for later use
	mov	AGROUP:[ebx].GXTHDR_IBV0,al ; Save in header
	mov	al,GXTINI.MD_IBV1 ; Save for later use
	mov	AGROUP:[ebx].GXTHDR_IBV1,al ; Save in header

	mov	AGROUP:[ebx].GXTHDR_CBFVEC.FSEL,cs ; Save in header
	mov	AGROUP:[ebx].GXTHDR_CBFVEC.FOFF,offset cs:CALLBACK ; ...

	call	AGROUP:[ebx].GXTHDR_IPROT ; Call INIT_PROT

	sub	edi,type LOAD_STR ; Skip to next entry

;;;;;;; loop	IPROT_LOAD_NEXT ; Jump if more modules
	dec	ecx		; Count out another
	jnz	IPROT_LOAD_NEXT ; Jump if more modules
IPROT_LOAD_EXIT:
	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

IPROT_LOAD endp 		; End IPROT_LOAD procedure
	NPPROC	GETTAB_LOAD -- Get LOADTAB Values
	assume	ds:DGROUP,es:AGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Get LOADTAB values

On entry:

SS:EBP	==>	INT00_STR

FS3:EDI3 ==>	 caller's table

|

	pushad			; Save all EGP registers

	mov	ax,LOADCOUNT.ELO ; Get # table entries
	mov	[ebp].INT00_EGP.PUSHAD_ECX.ELO,ax ; Return in caller's CX

	mov	ax,XMSHNDL2	; Get our XMS handle
	mov	[ebp].INT00_EGP.PUSHAD_EDX.ELO,ax ; Return in caller's DX

	movzx	edi,[ebp].INT00_FS ; Get caller's FS
	shl	edi,4-0 	; Convert from paras to bytes
	add	edi,[ebp].INT00_EGP.PUSHAD_EDI ; Plus caller's EDI

	lea	esi,LOADTAB	; DS:ESI ==> LOATAB
	mov	ecx,LOADTABLST	; Get last index
	add	ecx,type LOAD_STR ; Plus last entry
    rep movs	AGROUP:[edi].LO,LOADTAB[esi].LO ; Copy to low memory

	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

GETTAB_LOAD endp		; End GETTAB_LOAD procedure
	NPPROC	RPROT_LOAD -- Call REST_PROT For All Load Modules
	assume	ds:DGROUP,es:AGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Call REST_PROT for all load modules

On entry:

EBX	=	linear address of GDT
SS:EBP	==>	INT00_STR

|

	pushad			; Save all EGP registers

; Call REST_PROT in the reverse order as the modules were loaded

	mov	edi,LOADTABIND	; Get the next index
	mov	ecx,LOADCOUNT	; Get # load modules
	jecxz	RPROT_LOAD_EXIT ; Jump if no modules
RPROT_LOAD_NEXT:
	mov	eax,LOADTAB[edi].LOAD_MMLIN ; Get the MM-linear address

	call	AGROUP:[eax].GXTHDR_RPROT ; Call REST_PROT

; Restore the allocated selectors to an empty value in MTDTE

;;;;;;; test	DEVLOAD,@DEVL_INTRUDE ; Are we INTRUDEing today?
;;;;;;; jz	short RPROT_LOAD_XINTRUDE ; Jump if not
;;;;;;;
;;;;;;; push	ecx		; Save for a moment
;;;;;;;
;;;;;;; movzx	ecx,LOADTAB[edi].LOAD_NSELS ; Get # selectors to free
;;;;;;; movzx	edx,LOADTAB[edi].LOAD_SEL1 ; Get the 1st selector
;;;@@:
;;;;;;; mov	eax,MTDTE.EDQLO ; Get the low-order dword
;;;;;;; mov	AGROUP:[ebx+edx].EDQLO,eax ; Restore
;;;;;;;
;;;;;;; mov	eax,MTDTE.EDQHI ; Get the high-order dword
;;;;;;; mov	AGROUP:[ebx+edx].EDQHI,eax ; Restore
;;;;;;;
;;;;;;; add	edx,type DESC_STR ; Skip to next DTE
;;;;;;;
;;;;;;; loop	@B		; Jump if more selectors to free
;;;;;;;
;;;;;;; pop	ecx		; Restore
;;;RPROT_LOAD_XINTRUDE:
	add	edi,type LOAD_STR ; Skip to next entry

	loop	RPROT_LOAD_NEXT ; Jump if more modules
RPROT_LOAD_EXIT:
	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

RPROT_LOAD endp 		; End RPROT_LOAD procedure
;;;	    NPPROC  RREAL_COPY -- Copy REST_REAL Code/Data
;;;	    assume  ds:DGROUP,es:AGROUP,fs:nothing,gs:nothing,ss:nothing
;;; COMMENT|
;;;
;;; Copy REST_REAL code/data for module ESI to ES:EDI
;;;
;;; On entry:
;;;
;;; SS:EBP  ==>     INT00_STR
;;;
;;; |
;;;
;;;	    pushad		    ; Save all EGP registers
;;;
;;;	    movzx   edi,[ebp].INT00_ES ; Get caller's ES
;;;	    shl     edi,4-0	    ; Convert from paras to bytes
;;;	    add     edi,[ebp].INT00_EGP.PUSHAD_EDI ; Plus caller's EDI
;;;				    ; ES:EDI ==> destin
;;;	    mov     eax,[ebp].INT00_EGP.PUSHAD_ESI ; Get index
;;;
;;;	    mov     eax,LOADTAB[eax].LOAD_MMLIN ; Get the MM-linear address
;;;	    mov     esi,AGROUP:[eax].GXTHDR_RRSRC ; Get source offset
;;;	    add     esi,eax	    ; Plus base address
;;;	    mov     ecx,AGROUP:[eax].GXTHDR_RRLEN ; Get length
;;;
;;;	rep movs    AGROUP:[edi].LO,AGROUP:[esi].LO ; Copy to low memory
;;;
;;;	    popad		    ; Restore
;;;
;;;	    ret 		    ; Return to caller
;;;
;;;	    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;
;;; RREAL_COPY endp		    ; End RREAL_COPY procedure
	FPPROC	CALLBACK -- Callback Function
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Callback function

On entry:

CB_FCN	=	function code (see GXT_HDR.INC for @GXCB_xxx equates)

On exit:

Depends upon the function

EAX	=	0 if successful
	=	8Fh if invalid subfunction

|

CB_STR	struc

	dd	?		; Caller's EBP
CB_FVEC dq	?		; ...	   return address
CB_FCN	dd	?		; ...	   function code

CB_STR	ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <ds,gs> 	; Save for a moment

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	mov	gs,COMMON.FILE_4GB ; Get all memory selector
	assume	gs:AGROUP	; Tell the assembler about it

	cmp	[ebp].CB_FCN,@GXCB_CHGIDT ; Is the client about to change the IDT?
	je	short CALLBACK_CHGIDT ; Jump if so

	cmp	[ebp].CB_FCN,@GXCB_CHGIDTZ ; Is the client done changing the IDT?
	je	short CALLBACK_CHGIDTZ ; Jump if so

	cmp	[ebp].CB_FCN,@GXCB_SETCR3 ; Is the client setting CR3?
	je	short CALLBACK_SETCR3 ; Jump if so

	cmp	[ebp].CB_FCN,@GXCB_LIN2PHYS ; Is the client requesting lin to phys?
	je	near ptr CALLBACK_LIN2PHYS ; Jump if so

	cmp	[ebp].CB_FCN,@GXCB_RELRMSTK ; Is the client releasing a RM stack?
	je	near ptr CALLBACK_RELRMSTK ; Jump if so

	mov	eax,8Fh 	; Mark as invalid subfunction

	jmp	CALLBACK_EXIT	; Join common exit code


CALLBACK_CHGIDT:
	cmp	PSWAT_FVEC.FSEL,0 ; Izit valid?
	je	short @F	; Jump if not

	mov	eax,(@VCPI shl 8) or @SWAT_CHGIDT ; Pass function code
	call	PSWAT_FVEC	; Restore our selectors to give the client
				; clean slate
@@:
;;;
;;; ; Establish addressibility to IDT
;;;
;;;	     sub     esp,size DTR_STR ; Make room on stack
;;;	     SIDTD   [esp].EDF	    ; Save IDTR on stack
;;;	     mov     ebx,[esp].DTR_BASE ; AGROUP:EBX ==> IDT
;;;	     add     esp,size DTR_STR ; Strip from the stack
;;;
;;; ; Unhook our interrupts
;;;
;;;	     IDTMAC  00h,00,OLD     ; OLD to IDT (EAX clobbered)
;;;
	jmp	CALLBACK_E00	; Join common OK code


CALLBACK_CHGIDTZ:
;;;
;;; ; Establish addressibility to IDT
;;;
;;;	     sub     esp,size DTR_STR ; Make room on stack
;;;	     SIDTD   [esp].EDF	    ; Save IDTR on stack
;;;	     mov     ebx,[esp].DTR_BASE ; AGROUP:EBX ==> IDT
;;;	     add     esp,size DTR_STR ; Strip from the stack
;;;
;;; ; Re-hook our interrupts
;;;
;;;	     IDTMAC  00h,00,LCL,OLD ; IDT to OLD, LCL to IDT (EAX clobbered)
;;;
	cmp	PSWAT_FVEC.FSEL,0 ; Izit valid?
	je	short @F	; Jump if not

	mov	eax,(@VCPI shl 8) or @SWAT_CHGIDTZ ; Pass function code
	call	PSWAT_FVEC	; Initialize our selectors
@@:
	jmp	CALLBACK_E00	; Join common OK code


CALLBACK_SETCR3:
COMMENT|

Set new CR3

On entry:

EDX	=	physical address of CR3
EBX	=	linear address ...

|

	movzx	eax,[ebp].CB_FVEC.FSEL ; Get caller's CS

	REGSAVE <esi,es>	; Save for a moment

	mov	es,COMMON.FILE_4GB ; Get all memory selector
	assume	es:AGROUP	; Tell the assembler about it

	sub	eax,size DESC_STR ; Back off to CR3 selector

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	mov	esi,[esp].DTR_BASE ; AGROUP:ESI ==> GDT
	add	esp,size DTR_STR ; Strip from the stack

	mov	AGROUP:[eax+esi].DESC_BASE01,bx ; Save bits 0-15
	ror	ebx,16		; Rotate down the high-order word
	mov	AGROUP:[eax+esi].DESC_BASE2,bl ; Save bits 16-23
	mov	AGROUP:[eax+esi].DESC_BASE3,bh ; Save bits 24-31
	mov	AGROUP:[eax+esi].DESC_SEGLM0,(4*1024)-1 ; Save bits 0-15
	mov	AGROUP:[eax+esi].DESC_SEGLM1,0	; ...	    16-19
	mov	AGROUP:[eax+esi].DESC_ACCESS,CPL0_DATA ; Save A/R byte
	rol	ebx,16		; Rotate back

	xor	eax,eax 	; Zero to use as dword
	str	ax		; Get the current Task Register

	push	eax		; Pass the selector
	call	GETBASE 	; Return with EAX = base address

	and	eax,eax 	; Izit invalid?
	jz	short @F	; Jump if so

	mov	AGROUP:[eax].TSS_CR3,edx ; Save in TSS

	xor	eax,eax 	; Zero to use as dword
	mov	ax,seg PGROUP	; Get segment of
	shl	eax,4-0 	; Convert from paras to bytes
	add	eax,offset RGROUP:VCPEPM ; Plus offset to get
				; linear address of VCPEPM
	mov	AGROUP:[eax].VCPEPM_CR3,edx ; Save in VCPEPM
@@:
	cmp	PSWAT_FVEC.FSEL,0 ; Izit valid?
	je	short @F	; Jump if not

	mov	eax,(@VCPI shl 8) or @SWAT_SETCR3 ; Pass function code
				; EDX = new CR3 physical, EBX = new CR3 linear
	call	PSWAT_FVEC	; Initialize our selectors
@@:
	REGREST <es,esi>	; Restore
	assume	es:nothing	; Tell the assembler about it

	jmp	short CALLBACK_E00 ; Join common OK code


COMMENT|

Convert an address from linear to physical

On entry:

EAX	=	linear address

On exit:

EDX	=	physical address

|

CALLBACK_LIN2PHYS:
	mov	edx,eax 	; Copy linear address in case paging disabled

	mov	eax,cr0 	; Get register with paging bit

	test	eax,mask $PG	; Is paging enabled?
	jz	short CALLBACK_LIN2PHYS_EXIT ; Jump if not

	REGSAVE <es>		; Save for a moment

	mov	es,COMMON.FILE_CR3 ; Get CR3 selector
	assume	es:PDTGRP	; Tell the assembler about it

; ES:0 = linear address of 1st level PDIR (CR3)

	push	OFFPDT[@PDELOC].EDD ; Save the PDE there (if any)

	mov	eax,cr3 	; Get current PDBR
	and	eax,@PTE_FRM	; Isolate the 4KB frame
	or	eax,@PTE_URP	; Mark as User/Read-write/Present

	mov	OFFPDT[@PDELOC],eax ; Save as new PDE
	call	FLUSH_CACHE	; Flush the TLB

; At this point, the PDE for the original address is addressible at AGROUP:@PDELIN

	mov	eax,edx 	; Copy the original linear address
;;;;;;; and	eax,@PTE_FRM	; Isolate the 4KB frame
	shr	eax,($LA_PAGE-2)-0 ; Convert from bytes to 4KB in dwords

; N.B.:  We can't use AGROUP:[EAX*4+@PDELIN] as MASM doesn't handle it correctly

	mov	eax,AGROUP:[eax+@PDELIN] ; Get the PTE
	and	eax,@PTE_FRM	; Isolate the 4KB frame

; EAX = physical address which contains the 4KB linear address

	and	edx,mask $LA_OFF ; Isolate the offset portion
	add	edx,eax 	; Add offset to physical address of page

; EDX = physical address corresponding to input linear address

	pop	OFFPDT[@PDELOC].EDD ; Restore the PDE there (if any)
	call	FLUSH_CACHE	; Flush the TLB

	REGREST <es>		; Restore
	assume	es:nothing	; Tell the assembler about it
CALLBACK_LIN2PHYS_EXIT:
	jmp	short CALLBACK_E00 ; Join common OK code


COMMENT|

Release a RM stack

On entry:

EAX	=	linear address

On exit:

EDX	=	physical address

|

CALLBACK_RELRMSTK:
	SWATMAC ERR,RM



;;;;;;; jmp	short CALLBACK_E00 ; Join common OK code


CALLBACK_E00:
	xor	eax,eax 	; Mark as a success

;;;;;;; jmp	short CALLBACK_EXIT ; Join common exit code


CALLBACK_EXIT:
	REGREST <gs,ds> 	; Restore
	assume	ds:nothing,gs:nothing ; Tell the assembler about it

	pop	ebp		; Restore

	ret	4		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CALLBACK endp			; End CALLBACK procedure
	NPPROC	FLUSH_CACHE -- Flush Page Translation Cache
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Flush the page translation cache by respecifying the
Page Descriptor Base Register.

|

	push	eax		; Save for a moment

	mov	eax,cr3 	; Get contents of CR3
	mov	cr3,eax 	; Set it again to flush cache

	pop	eax		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FLUSH_CACHE endp		; End FLUSH_CACHE procedure
	FPPROC	LCL_RM2PM -- Local RM to PM Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Local RM to PM handler

On entry:

SS:ESP	==>	RM2PM_STR

|

	pushad			; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <ds,es> 	; Save registers

; Send this to the appropriate LOD module

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	lea	eax,[ebp].RM2PM_EPRM ; Get offset of return stack
	mov	RM2PM_STK_FVEC.FOFF,eax ; Save for later use
	mov	RM2PM_STK_FVEC.FSEL,ss ; ...

	mov	es,COMMON.FILE_4GB ; Get all memory selector
	assume	es:AGROUP	; Tell the assembler about it

	movzx	eax,[ebp].RM2PM_EPRM.EPRM_CS ; Get caller's CS

; Find this CS in the TSR area

	xor	ebx,ebx 	; Zero to use as dword
	mov	bx,seg PTSR	; Get segment of first TSR
LCL_RM2PM_NEXT:
	shl	ebx,4-0 	; Convert from paras to bytes

	cmp	ax,AGROUP:[ebx].GXTHDR_PRGSEG_CUR ; Izit in this segment?
	jb	short @F	; Jump if not (keep searching)

	cmp	ax,AGROUP:[ebx].GXTHDR_PRGSEG_NXT ; Izit below the next segment?
	jb	short LCL_RM2PM_FOUND ; Jump if so (we found it)
@@:
	movzx	ebx,AGROUP:[ebx].GXTHDR_NXT ; Get next segment (if any)

	cmp	bx,-1		; Izit the last?
	jne	short LCL_RM2PM_NEXT ; Jump if not (go around again)

	SWATMAC ERR		; Call our debugger (should never occur)

	jmp	short LCL_RM2PM_EXIT ; Join common exit code


LCL_RM2PM_FOUND:
	call	AGROUP:[ebx].GXTHDR_RM2PM_FVEC ; Call the entry point
LCL_RM2PM_EXIT:
	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	popad			; Restore

	jmp	ERM_FVEC	; Enter RM

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

LCL_RM2PM endp			; End LCL_RM2PM procedure

PROG	ends			; End PROG segment


XDATA	segment use16 dword public 'xdata' ; Start XDATA segment
	assume	ds:XGROUP

	public	@GXT_INI_XDATA
@GXT_INI_XDATA	label byte	; Mark module start in .MAP file

	public	XFILPTR
XFILPTR dd	?		; Pointer to filename.ext and command line args

XDATA	ends			; End XDATA segment


XDATAZ	segment use16 para public 'xdataz' ; Start XDATAZ segment
	assume	ds:XGROUP

	public	@GXT_INI_XDATAZ
@GXT_INI_XDATAZ label byte	; Mark module start in .MAP file

	public	XTAIL
XTAIL	label	byte

XDATAZ	ends			; End XDATAZ segment


XCODE	segment use16 para public 'xcode' ; Start XCODE segment
	assume	cs:XGROUP

	public	@GXT_INI_XCODE
@GXT_INI_XCODE: 		; Mark module start in .MAP file

	FPPROC	INIT_VIRT -- Virtual Mode Initialization Code
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Virtual mode initialization code

|

	REGSAVE <ax,bx> 	; Save for a moment

	CALLPL0 IPROT		; Tell 'em to call INIT_PROT

	REGREST <bx,ax> 	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INIT_VIRT endp			; End INIT_VIRT procedure

XCODE	ends			; End XCODE segment


NDATA	segment use16 dword public 'ndata' ; Start NDATA segment
	assume	ds:NGROUP

	public	@GXT_INI_NDATA
@GXT_INI_NDATA	label byte	; Mark module start in .MAP file

	extrn	MEMERR_IREAL:byte
	extrn	MSG_CHECK_ARGS:byte

	public	ARGPTR,FILPTR
ARGPTR	dd	?		; Pointer to command line arguments
FILPTR	dd	?		; ...	     filename.ext and command line args

	public	TSRSEG_1ST,TSRSEG_CUR,TSRSEG_INI,TSRSEG_NXT,TSRSEG_LST
TSRSEG_1ST dw	seg P1ST	; Initial value (static)
TSRSEG_CUR dw	-1		; Current  segment for TSRs (-1=first) (dynamic)
TSRSEG_INI dw	seg PTSR	; Starting segment for TSRs (static)
TSRSEG_NXT dw	seg PTSR	; Starting segment for TSRs (dynamic)
TSRSEG_LST dw	seg PTSR	; Highest available ... (static) (modified in INIT_COM)

	public	MAPSEG_NXT,MAPSEG_LST
MAPSEG_NXT dw	?		; Next available paragraph
MAPSEG_LST dw	?		; Last ...

	public	MSG_COPY
MSG_COPY db	@PROGNAM8,' -- Version '
	db	VERS_H,'.',VERS_T,VERS_U
	db	' -- ',@TAGLINE,CR,LF
	db	'   (C) Copyright 1990-2004 Sudley Place Software.',CR,LF,EOS

	public	INISTK
	align	4
INISTK	dw	256 dup (?)	; Local initialization stack
INISTKZ label	word

NDATA	ends			; End NDATA segment


NDATAZ	segment use16 para public 'ndataz' ; Start NDATAZ segment
	assume	ds:NGROUP

	public	@GXT_INI_NDATAZ
@GXT_INI_NDATAZ label byte	; Mark module start in .MAP file

	public	NTAIL
NTAIL	label	byte

NDATAZ	ends			; End NDATAZ segment


RDATAZ	segment use16 para public 'rdataz' ; Start RDATAZ segment
	assume	ds:RGROUP

	extrn	RTAIL_NR:byte

RDATAZ	ends			; End RDATAZ segment


NCODE	segment use16 para public 'ncode' ; Start NCODE segment
	assume	cs:NGROUP,ds:NGROUP

	public	@GXT_INI_NCODE
@GXT_INI_NCODE: 		; Mark module start in .MAP file

	extrn	CHECK_ARGS:near
	extrn	CHECK_SHIFT:near
	extrn	CHECK_NXTSEG:near
	extrn	DISP_PROGMSG:near

	public	OLDSTK_VEC,INISTK_VEC
OLDSTK_VEC dd	?		; Save area for old stack pointer
INISTK_VEC dd	NGROUP:INISTKZ	; Pointer to local stack

	NPPROC	DISP_COPY -- Display Our Copyright Notice
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Display our copyright notice.

|

	REGSAVE <ax,dx,ds>	; Save registers

	push	seg NGROUP	; Get our data segment
	pop	ds		; Address it
	assume	ds:NGROUP	; Tell the assembler about it

	DOSCALL @STROUT,MSG_COPY ; Display the flag

	REGREST <ds,dx,ax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DISP_COPY endp			; End DISP_COPY procedure
	FPPROC	INIT_REAL -- Real Mode Initialization Code
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Real mode initialization code.

On entry:

DS:DX	==>	"d:\path\filename.ext [arguments]",0
DS:SI	==>	"[arguments]",0

On exit:

@MD_RMIE =	 0 if all went OK
	=	1 otherwise

|

.8086
	mov	OLDSTK_VEC.VOFF,sp ; Save old stack pointer
	mov	OLDSTK_VEC.VSEG,ss ; ...
DOT386 p
	lss	sp,INISTK_VEC	; Install our local stack
	assume	ss:nothing	; Tell the assembler about it

	pushad			; Save all EGP registers
	REGSAVE <ds,es,fs,gs>	; Save segment registers

; Establish addressibility to our data

	push	seg NGROUP	; Get our data segment
	pop	es		; Address it
	assume	es:NGROUP	; Tell the assembler about it

	push	seg DGROUP	; Get our data segment
	pop	fs		; Address it
	assume	fs:DGROUP	; Tell the assembler about it

	push	seg PGROUP	; Get our data segment
	pop	gs		; Address it
	assume	gs:PGROUP	; Tell the assembler about it

	mov	ARGPTR.VSEG,ds	; Save as segment of arguments
	mov	ARGPTR.VOFF,si	; ...	  offset ...

	mov	FILPTR.VSEG,ds	; Save as segment of filename.ext arguments
	mov	FILPTR.VOFF,dx	; ...	  offset ...

	push	seg XGROUP	; Get our data segment
	pop	ds		; Address it
	assume	ds:XGROUP	; Tell the assembler about it

	mov	eax,FILPTR	; Get Seg:Off of device driver
	mov	XFILPTR,eax	; Save for later use

	push	seg NGROUP	; Get our data segment
	pop	ds		; Address it
	assume	ds:NGROUP	; Tell the assembler about it

	test	DEVLOAD,@DEVL_LOAD ; Are we loading as device driver?
	jnz	short @F	; Jump if so (already displayed)

	call	DISP_COPY	; Display our copyright notice
	DOSCALL @STROUT,MSG_LOADGXT ; Tell 'em what we're doing

	call	CHECK_SHIFT	; Check on shift key state

; Set MAPSEG_LST for later use

	int	12h		; Get top of DOS memory
	shl	ax,10-4 	; Convert from 1KB to paras
	mov	MAPSEG_LST,ax	; Save for later use
@@:

; Set para of end of data

	lea	ax,NGROUP:NTAIL[16-1] ; Get offset of end of NGROUP

	test	DEVLOAD,@DEVL_LOAD ; Are we loading as device driver?
	jz	short @F	; Jump if not

	lea	ax,RGROUP:RTAIL_NR[16-1] ; Get offset of end of RGROUP
@@:
	shr	ax,4-0		; Convert from bytes to paras
	add	ax,seg RGROUP	; Plus its starting paragraph
	mov	MAPSEG_NXT,ax	; Save for later use

	push	offset NGROUP:MEMERR_IREAL ; Pass offset of error message
	call	CHECK_NXTSEG	; Ensure we've enough room

; Convert GXTINI.MD_SIZE from Seg:Off to a 32-bit linear address

	movzx	eax,GXTINI.MD_SIZE.VSEG ; Get the segment
	sub	ax,seg PGROUP	; Less starting segment
	shl	eax,4-0 	; Convert from paras to bytes
	movzx	ebx,GXTINI.MD_SIZE.VOFF ; Get the offset
	add	eax,ebx 	; Add to get 32-bit linear address
	mov	GXTINI.MD_SIZE,eax ; Save back

; Convert GXTINI.MD_DATA from Seg:Off to a 32-bit linear address

	movzx	eax,GXTINI.MD_DATA.VSEG ; Get the segment
	sub	ax,seg PGROUP	; Less starting segment
	shl	eax,4-0 	; Convert from paras to bytes
	movzx	ebx,GXTINI.MD_DATA.VOFF ; Get the offset
	add	eax,ebx 	; Add to get 32-bit linear address
	mov	GXTINI.MD_DATA,eax ; Save back

; Convert GXTINI.MD_VSIZE from Seg:Off to a 32-bit length

	movzx	eax,GXTINI.MD_VSIZE.VSEG ; Get the segment
	sub	ax,seg XGROUP	; Less starting segment
	shl	eax,4-0 	; Convert from paras to bytes
	movzx	ebx,GXTINI.MD_VSIZE.VOFF ; Get the offset
	add	eax,ebx 	; Add to get 32-bit linear address
	mov	GXTINI.MD_VSIZE,eax ; Save back

; Zero segment fields of MD_IPROT and MD_RPROT

; The MS linker fixes up a DF (Ptr 16:32) field as if it were a Ptr 16:16
; field.  Thus, they put the segment fixup in FOFF.VSEG instead of FSEL.
; Wherever it is, we need to subtract it out.

	mov	ebx,FSEL	; Assume it's done correctly

	cmp	GXTINI.MD_IPROT.FSEL,0 ; Izit unfixed?
	jne	short @F	; Jump if not

	mov	ebx,FOFF.VSEG	; It's MS link up to its old tricks
@@:
	mov	ax,seg PGROUP	; Get the fixup value put in by the LINKer
	sub	GXTINI.MD_IPROT.ELO[ebx],ax ; Zero the field
	sub	GXTINI.MD_RPROT.ELO[ebx],ax ; ...

; Save all existing interrupt vectors

	REGSAVE <ds,es> 	; Save for a moment

	mov	ax,seg INTVEC	; Get INTVEC segment
	mov	ds,ax		; Address it
	assume	ds:INTVEC	; Tell the assembler about it

	lea	si,INT00_VEC	; DS:SI ==> RM IDT

	push	seg DGROUP	; Get our data segment
	pop	es		; Address it
	assume	es:DGROUP	; Tell the assembler about it

	lea	di,OLDINTxx_VEC ; ES:DI ==> save area

	mov	cx,256		; # interrupt vectors
    rep movs	OLDINTxx_VEC[di],INT00_VEC[si] ; Copy to local storage

	REGREST <es,ds> 	; Restore
	assume	ds:NGROUP,es:NGROUP ; Tell the assembler about it

; Parse the command line

	STROUT	CHECK_ARGS
	call	CHECK_ARGS	; Check for arguments
	jc	short INIT_REAL_ERR ; Jump if something went wrong

; Set starting linear address of our dynamic data
; which is immediately following DGROUP

	xor	eax,eax 	; Zero entire register
	mov	ax,seg DATAZ	; Get segment of DATAZ
	sub	ax,seg DGROUP	; Less ...	 DGROUP
	shl	eax,4-0 	; Convert from paras to bytes

	lea	di,GXTINI.MD_USIZE ; It's supported

; อออออออออออออออออออออออออออ INITIALIZED DATA อออออออออออออออออออออออออออออออออ


; ออออออออออออออออออออออออออ UNINITIALIZED DATA ออออออออออออออออออออออออออออออออ

;;; ; Count in size of the local stack
;;; ; Take into account the rounding up in the size of uninitialized data
;;;
;;;	    mov     ebx,eax	    ; Copy original offset
;;;	    add     eax,16-1	    ; Round up to para boundary
;;;	    and     eax,not (16-1)  ; ...
;;;	    sub     ebx,eax	    ; Less original offset
;;;	    neg     ebx 	    ; Negate to get positive value
;;;
;;; @LCLSTK equ     2048	    ; Size of local stack in bytes
;;;
;;;	    add     ebx,@LCLSTK     ; Plus its size in bytes
;;;	    add     PGROUP:[di].EDD,ebx ; Add into uninitialized data
;;;	    add     eax,@LCLSTK/2   ; Skip over the first half
;;;	    mov     INISTK_FVEC.FOFF,eax ; Save as offset for INIT_PROT stack
;;;	    add     eax,@LCLSTK/2   ; Skip over the second half
;;;	    mov     LCLSTK_FVEC.FOFF,eax ; Save as offset for all other stack usage

; อออออออออออออออออออ END OF UNINITIALIZED DATA ออออออออออออออออออออออออออออออออ

	jmp	short INIT_REAL_EXIT ; Join common exit code


INIT_REAL_ERR:
	mov	ax,seg DGROUP	; Get our data segment
	mov	ds,ax		; Address it
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	TSRSEG_CUR,-1	; Any TSRs?
	je	short INIT_REAL_DONE ; Jump if not

	mov	ax,TSRSEG_INI	; Get segment of 1st TSR
INIT_REAL_ERR_NEXT:
	cmp	ax,-1		; Izit the last segment?
	je	short INIT_REAL_DONE ; Jump if so

	mov	es,ax		; Address it
	assume	es:nothing	; Tell the assembler about it

	call	es:[0].GXTHDR_RREAL ; Call REST_REAL

	mov	ax,es:[0].GXTHDR_NXT ; Get segment of next header

	jmp	INIT_REAL_ERR_NEXT ; Go around again


INIT_REAL_DONE:
	or	GXTINI.MD_ATTR,@MD_RMIE ; Indicate something went wrong
INIT_REAL_EXIT:
	REGREST <gs,fs,es,ds>	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; Tell the assembler about it
	popad			; Restore all EGP registers

	lss	sp,OLDSTK_VEC	; Restore original stack
	assume	ss:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INIT_REAL endp			; End INIT_REAL procedure

	align	16		; Fill tail with NOPs

NCODE	ends			; End NCODE segment

	MEND			; End GXT_INI module
