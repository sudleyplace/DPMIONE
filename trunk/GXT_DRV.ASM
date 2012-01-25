;' $Header$
	title	GXT_DRV -- MMEXT Device Driver Routines
	page	58,122
	name	GXT_DRV

COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1995-2004 Qualitas, Inc.  All rights reserved.

|
.386p
.xlist
	include MASM.INC
	include DOSCALL.INC
	include KEYCALL.INC
	include ASCII.INC
	include 386.INC
	include PTR.INC
	include DEVDRV.INC
	include MAXDEV.INC
	include CMOS.INC
	include CPUID.INC
	include A20.INC
	include HMA.INC
	include BIOSCONF.INC
	include 8253.INC
	include 8255.INC
	include 8259.INC
	include BITFLAGS.INC
	include MASM5.MAC
	include ALLMEM.INC
	include CPUFLAGS.INC
	include VCPI.INC
	include BIOSDATA.INC
	include SCANCODE.INC
	include INTVEC.INC
	include OPEN.INC
	include IOCTL.INC
	include XMS.INC
	include VDS.INC
	include E820.INC
	include CPUFET2.INC
	include OPCODES.INC
	include DPMI.INC

	include GXT_API.INC
	include GXT_COM.INC
	include GXT_DRV.INC
	include GXT_HDR.INC
	include GXT_PRG.INC
	include GXT_SEG.INC
	include GXT_SWT.INC

	include QMAX_FIL.INC
	include SWAT_SYM.INC
.list

CGROUP	group	CPUID_SEG
PSPGRP	group	PSPSEG

PSPSEG	segment use16 at 0	; Start PSPSEG segment
	assume	cs:PSPGRP,ds:PSPGRP

	include PSP.INC

PSPSEG	ends			; End PSPSEG segment


P1ST	segment use32 byte public 'prog' ; Start P1ST segment
	assume	cs:PGROUP

	extrn	GXTINI:tbyte
	extrn	DEVLOAD:byte
	extrn	P1TAIL:near

P1ST	ends			; End P1ST segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP,ds:PGROUP

;;;;;;; extrn	ERM_FVEC:fword

; Note we omit INT 00h from the list below to allow us
; to intercept it later on

@PSWATINTS equ	<01,02,03,05,06,09,0B,0C,0D> ; Hook these INTs if preceding SWAT
@HOOKINTS  equ	<00>		; Hook these INTs for local service

%	irp	XX,<@HOOKINTS>
	extrn	LCL_INT&XX:near
	endm

	extrn	LCL_RM2PM:near

PROG	ends			; End PROG segment


DATA16	segment use32 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	public	@GXT_DRV_DATA16
@GXT_DRV_DATA16 label byte	; Mark module start in .MAP file

	extrn	RM2PM_STK_FVEC:fword
	extrn	LOADTAB:tbyte
	extrn	LOADTABLST:dword
	extrn	LOADCOUNT:dword
	extrn	OLDINTxx_VEC:dword

;;	  public  LaDEVINTCOM
;;LaDEVINTCOM dd  ?		  ; Linear address of DEVINTCOM
	public	LaRM_IDT
LaRM_IDT dd	?		; ...		    RM_IDT

	public	RUD_GDTR,RUD_IDTR
RUD_GDTR df	?		; Current GDTR for INTRUDEing
RUD_IDTR df	?		; ...	  IDTR ...

	public	PSWAT_FVEC,PSWAT2_FVEC
PSWAT_FVEC df	?		; Sel|Off of PSWAT
PSWAT2_FVEC label fword 	; Sel|Off of PSWAT as VCPI intruder
	dd	?		; ...
	dw	DTE_PSWAT	; ...

DATA16	ends			; End DATA16 segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@GXT_DRV_DATA
@GXT_DRV_DATA	label byte	; Mark module start in .MAP file

;;;	public	XMSHNDL
;;; XMSHNDL dw	    0		    ; XMS handle for LOADUP -- PDIRS	 (0=none)

	public	XMSHNDL2
XMSHNDL2 dw	0		; XMS handle for LOADUP -- Code/Data (0=none)

	public	PL0STK_SIZ,LaPL0STK
PL0STK_SIZ dd	128*1024	; Default PL0 stack size
LaPL0STK dd	?		; Linear address of PL0 stack

	public	LCL_EAX
LCL_EAX dd	?		; Save area

DATA	ends			; End DATA segment


RCODE0	segment use16 para public 'rcode' ; Start RCODE0 segment
	assume	ds:RGROUP

	public	@GXT_DRV_RCODE0
@GXT_DRV_RCODE0 label byte	; Mark module start in .MAP file

; RGXTINI must be the first variable in this group

	public	RGXTINI
RGXTINI MD_STR	<>		; Resident device driver header

	public	VCPSTK_FVEC
VCPSTK_FVEC df	VCPSTKZ-RGXTINI ; Ptr to Device VCPI stack

	public	VCPSTK,VCPSTKZ
	align	4
VCPSTK	dd	32 dup (?)	; Device VCPI stack
VCPSTKZ label	dword		; Top of the stack

RCODE0	ends			; End RCODE0 segment


RCODE	segment use16 para public 'rcode' ; Start RCODE segment
	assume	cs:RGROUP,ds:RGROUP

	public	@GXT_DRV_RCODE
@GXT_DRV_RCODE	label byte	; Mark module start in .MAP file

	extrn	A20COM_I92:near
	extrn	GATEA20:near
	extrn	DEGATEA20:near
	extrn	CHECKA20:near

	extrn	A20SUP:word
	extrn	ACTA20_COMSUB:word

	public	RH_VEC
RH_VEC	dd	?		; Save area for request vector

	FPPROC	DEV_STRA -- Resident/Non-resident Device Strategy Routine
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Resident/non-resident device driver strategy routine.

|

.8086
	mov	RH_VEC.VOFF,bx	; Save for later use
	mov	RH_VEC.VSEG,es
DOT386 p

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEV_STRA endp			; End DEV_STRA procedure
	FPPROC	DEV_INTR -- Resident Device Interrupt Routine
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Resident device driver interrupt routine.

|

	REGSAVE <bx,es> 	; Save registers

	les	bx,RH_VEC	; ES:BX ==> request header
	assume	es:nothing	; Tell the assembler about it

	STATUS	DONE,NOERROR	; Set status word (done, no error)

	REGREST <es,bx> 	; Restore
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEV_INTR endp			; End DEV_INTR procedure

	public	DEV_INTRZ
DEV_INTRZ label byte		; Last byte in header if we're INTRUDEing

	align	16		; Fill tail with NOPs

RCODE	ends			; End RCODE segment


RCODE	segment use16 para public 'rcode' ; Start RCODE segment
	assume	cs:RGROUP,ds:RGROUP

;;;;;;; public	@GXT_DRV_RCODE
;;;@GXT_DRV_RCODE  label byte	   ; Mark module start in .MAP file

	public	GXTGDT
	align	4		; Ensure dword-aligned
GXTGDT	XDTE_STR <>		; Device driver's GDT

	public	GXTGDTR,GXTIDTR
GXTGDTR equ	GXTGDT.DTE_GDT.EDF ; DTR for GDT in low memory
GXTIDTR equ	GXTGDT.DTE_IDT.EDF ; ...     IDT in extended memory

	public	SAVE_EAX,SAVE_ESI
SAVE_EAX dd	?		; Save area
SAVE_ESI dd	?		; ...

	public	VCPEPM
VCPEPM	VCPEPM_STR <>		; VCPI Enter PM Structure

	public	LaVCPEPM
LaVCPEPM dd	?		; Linear address of VCPEPM

	public	PMI_FVEC
PMI_FVEC df	?		; Sel:Off to PMI code

	public	PE_MASK
PE_MASK dw	mask $PE	; PE mask unless VCPI (zero then)

	public	DEV_FLAG
DEV_FLAG dw	0		; Device driver flags

	public	TRP_FLAG
TRP_FLAG dd	@TRP_I00 or @TRP_RM2PM ; @TRP_xxx flags

@GXTSTK_LEN equ 1024		; GXT stack length per interrupt
@GXTSTK_CNT equ 4		; ...	    count

	public	GXTSTK_FVEC
GXTSTK_FVEC label fword 	; Pointer to GXT stack in extended memory
	dd	@GXTSTK_LEN*@GXTSTK_CNT ; Initial top of stack
	dw	DTE_SS		; Selector

	public	DEVEXTSIZE
DEVEXTSIZE dw	?		; Size of extended memory below us

	public	RMSTK_FVEC
RMSTK_FVEC df	?		; Pointer to RM stack
	dw	?		; Pad RMSTK_VEC to use as qword

	public	RM_EIP,RM_CSF,RM_EFL,RM_ESF,RM_DSF,RM_FSF,RM_GSF
	public	RM_NEXT,RM_TRP,RM_RIP
RM_EIP	dd	0		; Save area for EIP
RM_CSF	dw	?,?		; ...		CS w/filler
RM_EFL	dd	?		; ...		EFL
RM_ESF	dw	?,?		; ...		ES w/filler
RM_DSF	dw	?,?		; ...		DS ...
RM_FSF	dw	?,?		; ...		FS ...
RM_GSF	dw	?,?		; ...		GS ...
RM_NEXT dd	?		; ...		next handler in sequence
RM_TRP	dd	?		; ...		@TRP_Ixx flag
RM_RIP	dw	?		; ...		return IP

	public	RM_GDTR,RM_IDTRL,RM_IDTR0
RM_GDTR df	?		; GDTR upon entry to debugger
RM_IDTRL df	(size RM_IDT)-1 ; IDTR in local memory
RM_IDTR0 df	(size RM_IDT)-1 ; IDTR at 0:0

	public	PSP_SEG
PSP_SEG dw	0		; PSP segment (0 = none)

	align	4
%	irp	XX,<@HOOKINTS,15,2F>

	public	ORIGDEV&XX&_VEC
ORIGDEV&XX&_VEC dd ?		; Original handler in sequence for INT XX&h
				; (before .LOD modules are called)
	public	PREVDEV&XX&_VEC
PREVDEV&XX&_VEC dd ?		; Previous handler in sequence for INT XX&h
				; (after .LOD modules are called)
	endm			; IRP XX,<@HOOKINTS,15,2F>

	public	RMIRQ,RMPORTBASE,RMINPUT
RMIRQ	db	0FFh,?		; Serial port IRQ active or 0FFh to ignore
RMPORTBASE dw	?		; Serial port base
RMINPUT dd	0		; Input buffer for BREAK signal interrupt

	public	RGRSEG,RGRSEL
RGRSEG	dw	seg RGROUP	; Segment of RGROUP changed by COPYLOW
				; to reflect reality
RGRSEL	dw	DTE_ES		; Selector of RGROUP ...

; Define default IDT for PM interrupts
; This table is used for interrupts not otherwise
; handled specially.

	public	IGT_IDT
	align	4		; Needed to make each entry four bytes
IGT_IDT:
	call	IGTINTCOM
IGT_IDTZ:
	rept	255		; One per interrupt
	align	4		; Filler
	call	IGTINTCOM
	endm			; REPT


	public	VSAPI_STR1
VSAPI_STR1 db	@VSAPINAME,0	; Signature
VSAPI_STR1_LEN equ $-VSAPI_STR1 ; Length of ...


	NPPROC	IGTINTCOM -- IGT Common Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Common interrupt handler for reflecting
interrupts to RM/VM.

This routine is used for interrupts not otherwise
handled specially.

This routine runs in PM only.

On entry:

The return address is IGT_IDTZ[4 * INT #]

|

INTCOM_STR struc

INTCOM_EIP dd	 ?		; 00:  Old EIP
INTCOM_CS dw	 ?		; 04:  Old CS
INTCOM_INTNO dw  ?		; 06:  Interrupt #
INTCOM_EFL dd	 ?		; 08:  Old EFL
INTCOM_ESP dd	 ?		; 0C:  Old ESP3
INTCOM_SS dw	 ?,0		; 10:  Old SS
INTCOM_ES dw	 ?		; 14:  Old ES
INTCOM_ICOMLO dw ?		; 16:  INTCOM-restart point, low-order word
INTCOM_DS dw	 ?		; 18:  Old DS
INTCOM_ICOMHI dw ?		; 1A:  INTCOM-restart point, high-order word
INTCOM_FS dw	 ?,0		; 1C:  Old FS
INTCOM_GS dw	 ?,0		; 20:  Old GS

INTCOM_STR ends

	pop	[esp].INTCOM_INTNO ; Save IGT_IDTZ[4 * INT #]

;;;;;;; SWATMAC 		; Call our debugger *FIXME* *TESTME*

; Ensure there's room on PL3 stack for CS, IP, and FL

	sub	[esp].INTCOM_ESP.ELO,type IRET_STR ; Make room
	jnc	short @F	; Jump if enough room

;;;;;;; SWATMAC ERR		; Call our debugger *FIXME*
@@:

; Save CS, IP, and FL on PL3 stack as in a real mode interrupt

	REGSAVE <eax,ebx,edi>	; Save registers

@PUSHSIZE equ	4+4+4		; Size on stack of PUSHed registers

	push	DTE_LOAD+1*(type DESC_STR) ; Get load module's data selector
	pop	ds		; Address it
	assume	ds:DGROUP	; Tell the assembler about it

	movzx	ebx,[esp+@PUSHSIZE].INTCOM_INTNO ; Get the INT # times 4 + ...
	sub	ebx,offset RGROUP:IGT_IDTZ ; Convert to origin-0, unit 4
	movzx	edi,[esp+@PUSHSIZE].INTCOM_SS ; Get stack segment
	mov	eax,OLDINTxx_VEC[ebx] ; Get original Segment:Offset
	shl	edi,4-0 	; Convert from paras to bytes

	push	DTE_4GB 	; Get AGROUP data selector
	pop	ds		; Address it
	assume	ds:AGROUP	; Tell the assembler about it

	xchg	ax,[esp+@PUSHSIZE].INTCOM_EIP.ELO ; Swap IPs
	mov	[esp+@PUSHSIZE].INTCOM_EIP.EHI,0 ; Clear high-order word
	movzx	ebx,[esp+@PUSHSIZE].INTCOM_ESP.ELO ; Get caller's ESP
	mov	AGROUP:[edi+ebx],ax ; Save on PL3 stack

	shr	eax,16		; Shift segment down to low-order

	xchg	ax,[esp+@PUSHSIZE].INTCOM_CS ; Swap CSs
	inc	bx		; Account for saved word, emulate 64KB wrap
	inc	bx
	mov	AGROUP:[edi+ebx],ax ; Save on PL3 stack

	mov	ax,[esp+@PUSHSIZE].INTCOM_EFL.ELO ; Get FL (as opposed to EFL)
	inc	bx		; Account for saved word, emulate 64KB wrap
	inc	bx
	mov	AGROUP:[edi+ebx],ax ; Save on PL3 stack

; Turn off VM, trap, interrupt, and nested task flags in PL0 stack

	and	[esp+@PUSHSIZE].INTCOM_EFL,not ((mask $VMHI) or (mask $TF) or (mask $IF) or (mask $NT))

	REGREST <edi,ebx,eax>	; Restore

;;;;;;; assume	ds:PGROUP	; Tell the assembler about it
;;;;;;; db	@OPCOD_CS	; CS: override
;;;;;;; jmp	ERM_FVEC	; Enter RM
;;;;;;; assume	ds:nothing	; Tell the assembler about it
	jmp	PM2RM_HANDLER	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

IGTINTCOM endp			; End IGTINTCOM procedure
	FPPROC	RM2PM_HANDLER -- RM to PM Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

RM to PM handler

On entry:

On exit:

|

	push	dword ptr @TRP_RM2PM ; Pass trap flag to test
	PUSHD	0		; Pass address of next handler in sequence
	call	EPM		; Enter PM
;;;;;;; jc	short RMDEVxx_VM ; Jump if we're in VM

	FIJMP32 PGROUP:LCL_RM2PM,DTE_LOAD ; Join common code in PM

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

RM2PM_HANDLER endp		; End RM2PM_HANDLER procedure
;	  NPPROC  DEVINTCOM -- Device GXT Interrupt Common Routine
;	  assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
; COMMENT|
;
; Device GXT Interrupt Common Routine
;
; The incoming code segment is (seg PGROUP) - INT #.
; Note that this means we can't use any CS: overrides.
;
; |
;
; DEVINT_STR struc
;
;	  dw	  ?		  ; Caller's BP
; DEVINT_VEC dd   ?		  ; Room for CS:IP
;
; DEVINT_STR ends
;
;	  push	  ebx		  ; Make room for DEVINT_VEC
;	  push	  bp		  ; Prepare to address the stack
;	  mov	  bp,sp 	  ; Hello, Mr. Stack
;
;	  pushf 		  ; Save flags
;
;	  push	  ds		  ; Save register
;
;	  mov	  bx,seg INTVEC   ; Get segment of RM IDT
;	  mov	  ds,bx 	  ; Address it
;	  assume  ds:INTVEC	  ; Tell the assembler about it
;
;	  mov	  bx,cs 	  ; Get code segment to get INT #
;	  sub	  bx,seg PGROUP   ; Less the expected segment #
;	  neg	  bx		  ; Negate to get INT #
;	  shl	  bx,2-0	  ; Convert from INT # to bytes
;
;	  mov	  ebx,INT00_VEC[bx] ; Get the Seg:Off
;	  xchg	  ebx,[bp].DEVINT_VEC ; Save back onto stack, restore EBX
;
;	  pop	  ds		  ; Restore
;	  assume  ds:nothing	  ; Tell the assembler about it
;
;	  popf			  ; Restore
;
;	  pop	  bp		  ; Restore
;
;	  retf			  ; Continue with next handler in sequence
;
;	  assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;
; DEVINTCOM endp		  ; End DEVINTCOM procedure
	FPPROC	RMDEV00 -- RM Device Driver Divide Overflow Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

RM device driver divide overflow interrupt handler

|

	push	dword ptr @TRP_I00 ; Pass trap flag to test
	push	PREVDEV00_VEC	; Pass address of previous handler in sequence
	call	EPM		; Enter PM
	jc	short RMDEV00_VM ; Jump if we're in VM

	or	[esp].DEVSTK_EFL.EHI,mask $RF ; RF=1 for fault

	FIJMP32 PGROUP:LCL_INT00,DTE_LOAD ; Join common code in PM


RMDEV00_VM:
	jmp	PREVDEV00_VEC	; Continue with next handler in sequence

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

RMDEV00 endp			; End RMDEV00 procedure
	FPPROC	RMDEV15 -- BIOS Services Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

BIOS services interrupt handler

|

	pushf			; Save flags for a moment

	cmp	ah,88h		; Izit Get Extended Memory function?
	jne	short @F	; Jump if not

	mov	ax,DEVEXTSIZE	; Get size of extended memory

	popf			; Restore flags

	iret			; Return to caller


@@:
	popf			; Restore flags

	jmp	PREVDEV15_VEC	; Continue with previous handler in sequence

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

RMDEV15 endp			; End RMDEV15 procedure
	FPPROC	RMDEV2F -- Multiplexor Services Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Multiplexor services interrupt handler

This routine runs in RM/VM only.

In particular, we're looking for function 168Ah
so as to determine whether or not we're already
installed.

On entry (if AX = @DPMI_API2F):

DS:SI	==>	ASCIIZ string

On exit (if AX = @DPMI_API2F):

ZF	=	1 if it's '@VSAPINAME',0
ES:DI	==>	our entry point

ZF	=	0 if not

|

RM2F_STR struc

	dw	?		; Caller's BP
	dw	?		; ...	   IP
	dw	?		; ...	   CS
RM2F_FL dw	?		; ...	   FL

RM2F_STR ends

	pushf			; Save flags for a moment

	cmp	ax,@DPMI_API2F	; Izit Get Vendor-Specific API Entry Point?
	jne	short RMDEV2F_ORIG ; Jump if not

	REGSAVE <cx,di,es>	; Save registers

; Check for our signature

	mov	es,RGRSEG	; Get our data segment
	assume	es:RGROUP	; Tell the assembler about it

	lea	di,VSAPI_STR1	; ES:DI ==> VSAPI signature
	mov	cx,VSAPI_STR1_LEN ; CX = length of ...
	push	si		; Save for a moment
	cld			; Strings ops forwardly
   repe cmps	ds:[si].LO,VSAPI_STR1[di] ; Compare 'em
	pop	si		; Restore
	REGREST <es,di,cx>	; Restore
	assume	es:nothing	; Tell the assembler about it
	jne	short RMDEV2F_ORIG ; Jump if no match

; It's a match:
; Return with ES:DI ==> API Entry point
;	      AL    =	0
;	      ZF    =	1

	popf			; Restore flags

	push	bp		; Prepare to address the stack
	mov	bp,sp		; Hello, Mr. Stack
	or	[bp].RM2F_FL,mask $ZF ; ZF=1
	pop	bp		; Restore

	mov	es,RGRSEG	; ES = RGROUP
	assume	es:RGROUP	; Tell the assembler about it

	lea	di,RMDEV_VSAPI	; ES:DI ==> VSAPI Entry Point
	mov	al,0		; Tell 'em it's a match

	iret			; Return to caller


	assume	es:nothing	; Tell the assembler about it
RMDEV2F_ORIG:
	popf			; Restore flags

	jmp	PREVDEV2F_VEC	; Continue with previous handler in sequence

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

RMDEV2F endp			; End RMDEV2F procedure
	FPPROC	UNSETINTS -- Restore Interrupts
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Uninstall RM interrupt handlers

|

	REGSAVE <eax,ds,es>	; Save registers

	mov	es,RGRSEG	; Get segment for RM_IDT as relocated
	assume	es:RGROUP	; Tell the assembler about it

	mov	ax,seg INTVEC	; Get INTVEC segment
	mov	ds,ax		; Address it
	assume	ds:INTVEC	; Tell the assembler about it

; Unset our special interrupts in the RM IDT
; INTs 15h/2Fh are extra as we don't reflect them to PM.

%	irp	XX,<@HOOKINTS,15,2F> ; *FIXME*

	mov	eax,ORIGDEV&XX&_VEC ; Get original saved value
	mov	INT00_VEC[0&XX&h*(type INT00_VEC)],eax

	endm			; IRP XX,<@HOOKINTS,15,2F>

	REGREST <es,ds,eax>	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

UNSETINTS endp			; End UNSETINTS procedure
	FPPROC	RMDEV_VSAPI -- VSAPI Entry Point
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

VSAPI entry point

On entry:

AX	=	function code

On exit:

CF	=	0 if successful
	=	1 if not

|

	cmp	ax,@VSAPI_RREAL ; Izit REST_REAL?
	jne	short RMDEV_VSAPI1 ; Jump if not

	push	cs		; Push return CS
	call	near ptr UNSETINTS ; Unset RM interrupts

	mov	ax,PSP_SEG	; Return our segment in AX (or zero if device driver)

	clc			; Mark as successful

	jmp	short RMDEV_VSAPI_EXIT ; Join common exit code


RMDEV_VSAPI1:
	stc			; Mark as in error
RMDEV_VSAPI_EXIT:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

RMDEV_VSAPI endp		; End RMDEV_VSAPI procedure
	NPPROC	EPM -- Enter PM
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Enter PM

If we're already in PM (actually VM) or if we're entered with TF set
(perhaps 386MAX is single-stepping through us), then don't try to enter
PM; otherwise, do it.

On exit:

CF	=	0 if we're in PM
	=	1 ...	       VM or TF=1

|

EPM_STR struc

EPM_RIP dw	?		; Caller's return IP
EPM_NEXT dd	?		; Address of next handler in sequence
EPM_TRP dd	?		; @TRP_Ixx flag to test
EPM_IP	dw	?		; Caller's IP
EPM_CS	dw	?		; ...	   CS
EPM_FL	dw	?		; ...	   FL

EPM_STR ends

; The stack is mapped by EPM_STR

	push	bp		; Prepare to address the stack
	mov	bp,sp		; Hello, Mr. Stack

	push	eax		; Save for a moment

	mov	eax,[bp+2].EPM_TRP ; Get @TRP_Ixx flag to test (+2 for BP)

	test	eax,TRP_FLAG	; Should we intercept this one?
	pop	eax		; Restore
	pop	bp		; Restore
	jz	short EPM_ORIG	; Jump if not (continue with original handler)

	call	CHECK_VMTF	; Check VM and TF
	jz	short @F	; Jump if neither is set
EPM_ORIG:
	stc			; Indicate we're in VM

	ret	(size EPM_NEXT) + (size EPM_TRP) ; Return to caller,
				; popping arguments

@@:
	push	ds		; Save for a moment
	push	es		; ...
	push	fs		; ...
	push	gs		; ...

	push	cs		; Get segment of RM_xxx
	pop	ds		; Address it
	assume	ds:RGROUP	; Tell the assembler about it

	pop	RM_GSF		; Save for later use
	pop	RM_FSF		; ...
	pop	RM_ESF		; ...
	pop	RM_DSF		; ...

	pop	RM_RIP		; ...
	pop	RM_NEXT 	; ...
	pop	RM_TRP		; ...
	pop	RM_EIP.ELO	; ...
	pop	RM_CSF		; ...

; Clear the NT flag bit

	push	ax		; Save for a moment
	pushf			; Copy flags
	pop	ax		; ...to register
	and	ax,not (mask $NT) ; NT = 0
	push	ax		; Copy register
	popf			; ...to flags
	pop	ax		; Restore

	pushfd			; Get current EFL
	pop	RM_EFL		; Save high-order word for later use
	pop	RM_EFL.ELO	; ...

;;;; Iff we're in VM ($PE = 1), set the $VM bit
;;;;;;;
;;;;;;; push	ax		; Save for a moment
;;;;;;; smsw	ax		; Get the Machine Status Word
;;;;;;; test	ax,mask $PE	; Are we in VM?
;;;;;;; pop	ax		; Restore
;;;;;;; jz	short @F	; Jump if not
;;;;;;;

; Set the VM bit to satisfy code everywhere else which was
; written for VM only.	No IRETD is ever performed with this
; bit set, so we don't have to worry about returning to the
; wrong mode.  We always return to the original mode via
; VCPI or ERM.

	or	RM_EFL.EHI,mask $VM ; VM=1
;;;@@:
	mov	RMSTK_FVEC.FSEL,ss  ; Save for later use
	mov	RMSTK_FVEC.FOFF,esp ; ...

	test	DEV_FLAG,@DEV_VCPI ; Are we using VCPI services?
	jnz	short EPM_VCPI	; Jump if so

; Gate A20 ON unless it's already ON

	or	DEV_FLAG,@DEV_A20ON ; Assume A20 enabled upon entry
@@:
	call	CHECKA20	; Izit enabled?
	jc	short @F	; Jump if so

	and	DEV_FLAG,not @DEV_A20ON ; Mark as A20 not enabled upon entry
	call	GATEA20 	; Gate A20 on

	jmp	short @B	; Jump if not
@@:

; Enter PM

	SGDTD	RM_GDTR 	; Save old GDTR
	LGDTD	GXTGDTR 	; Point GDTR to low memory
	LIDTD	GXTIDTR 	; ...	IDTR to extended memory

	push	eax		; Save for a moment

	mov	eax,cr0 	; Get current CR0
	or	ax,mask $PE	; Mark as enabling protected mode
	mov	cr0,eax 	; Enter protected mode

	FIJMP	RGROUP:@F,DTE_CS ; Flush prefetch instruction queue


@@:
	and	GXTGDT.DTE_TSS.DESC_ACCESS,not (mask $DS_BUSY) ; Clear the busy bit

	mov	ax,DTE_TSS	; Get TSS selector
	ltr	ax		; Tell the CPU about it

	pop	eax		; Restore

	jmp	short EPM_PMCOM ; Join common code


EPM_VCPI:
	mov	SAVE_EAX,eax	; Save register
	mov	SAVE_ESI,esi	; ...
	cli			; Enter with IF=0

	mov	esi,LaVCPEPM	; Get linear address of VCPEPM
	VCPICALL @VCPI_EPM	; Enter PM using ESI = EPM struc
EPM_VCPI_PMINI:
	cli			; Some VCPI hosts (RM386 comes to mind)
				; start us off with IF=1
	xor	ax,ax		; A convenient zero
	mov	ds,ax		; Clear to avoid fault
	assume	ds:nothing	; Tell the assembler about it
	mov	es,ax		; Clear to avoid fault
	assume	es:nothing	; Tell the assembler about it
	mov	fs,ax		; Clear to avoid fault
	assume	fs:nothing	; Tell the assembler about it
	mov	gs,ax		; ...
	assume	gs:nothing	; Tell the assembler about it

	mov	eax,SAVE_EAX	; Restore
	mov	esi,SAVE_ESI	; ...

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

EPM_PMCOM:
	mov	ds,RGRSEL	; Get RGROUP selector
	assume	ds:RGROUP	; Tell the assembler about it (note lie)

; Switch to GXT's stack in extended memory

	lss	esp,GXTSTK_FVEC ; Address it
	assume	ss:nothing	; Tell the assembler about it

; Delete this portion in case we're re-entrant

	sub	GXTSTK_FVEC.FOFF,@GXTSTK_LEN ; Count out one stack frame
	ja	short @F	; Jump if within range

	SWATMAC ERR,RM		; Call our debugger
@@:
EPM_COM1:

; Setup segment registers

	mov	ds,GXTGDT.ELO	; Zero the selector
	assume	ds:nothing	; Tell the assembler about it

	mov	es,GXTGDT.ELO	; ...
	assume	es:nothing	; Tell the assembler about it

	mov	fs,GXTGDT.ELO	; ...
	assume	fs:nothing	; Tell the assembler about it

	mov	gs,GXTGDT.ELO	; ...
	assume	gs:nothing	; Tell the assembler about it

; Setup stack as per VM
; The start of this stack *MUST* match EPRM_STR from GXT_INI.ASM

	push	RM_GDTR.DTR_BASE ; Save old GDTR
	push	RM_GDTR.DTR_LIM ; ...
	push	DEV_FLAG	; Save flags upon entry
;;;;;;; push	RM_TRP		; Pass back @TRP_Ixx flag
	push	RM_NEXT 	; Pass back address of next handler in sequence
	push	RM_GSF.EDD	; Setup GS w/filler
	push	RM_FSF.EDD	; ...	FS ...
	push	RM_DSF.EDD	; ...	DS ...
	push	RM_ESF.EDD	; ...	ES ...
	push	RMSTK_FVEC.FSEL.EDD ; ...   SS ...
	push	RMSTK_FVEC.FOFF ; ...	 ESP
	push	RM_EFL		; ...	EFL
	push	RM_CSF.EDD	; ...	CS w/filler
	push	RM_EIP		; ...	EIP

	clc			; Indicate all went well

	jmp	RM_RIP		; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

EPM	endp			; End EPM procedure
	NPPROC	PM2RM_HANDLER -- PM To RM Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

PM to RM handler

SS:ESP	==>	PM2RM_STR

|

	cli			; Disallow interrupts

	push	DTE_LOAD+1*(type DESC_STR) ; Get load module's data selector
	pop	ds		; Address it
	assume	ds:DGROUP	; Tell the assembler about it

	mov	LCL_EAX,eax	; Save to restore later

; If we're on the same stack as the return stack, make room for the
; return stack info at ESP not RM2PM_STK_FVEC

	mov	eax,ss		; Get current stack selector

	cmp	ax,RM2PM_STK_FVEC.FSEL ; Izit the same stack?
	je	short PM2RM_HANDLER1 ; Jump if so

	lds	eax,RM2PM_STK_FVEC ; DS:EAX ==> initial stack
	assume	ds:nothing	; Tell the assembler about it

	pop	ds:[eax].EPRM_EIP	; EIP
	pop	ds:[eax].EPRM_CS.EDD	; CS w/filler
	pop	ds:[eax].EPRM_EFL	; EFL
	pop	ds:[eax].EPRM_ESP	; ESP
	pop	ds:[eax].EPRM_SS.EDD	; SS w/filler
	pop	ds:[eax].EPRM_ES.EDD	; ES w/filler
	pop	ds:[eax].EPRM_DS.EDD	; DS w/filler
	pop	ds:[eax].EPRM_FS.EDD	; FS w/filler
	pop	ds:[eax].EPRM_GS.EDD	; GS w/filler

	push	DTE_LOAD+1*(type DESC_STR) ; Get load module's data selector
	pop	ds		; Address it
	assume	ds:DGROUP	; Tell the assembler about it

	lss	esp,RM2PM_STK_FVEC ; SS:ESP ==> initial stack
	assume	ss:nothing	; Tell the assembler about it

	jmp	PM2RM_HANDLER2	; Join common code


PM2RM_HANDLER1:
	SWATMAC ERR,RM		; *FIXME* *TESTME*

;;; ; Move the current stack down to accommodate the trailing
;;; ; entries needed by ERM
;;;
;;; @PM2RM_DIFF equ (size RM_NEXT)  + (size DEV_FLAG) + (size RM_GDTR)
;;;
;;;	    sub     esp,@PM2RM_DIFF ; Make room
;;;
;;; ; Move values down by @PM2RM_DIFF
;;;
;;;	    mov     eax,[esp+@PM2RM_DIFF].PM2RM_EIP
;;;	    mov     [esp].PM2RM_EIP,eax
;;;
;;;	    mov     eax,[esp+@PM2RM_DIFF].PM2RM_CS.EDD
;;;	    mov     [esp].PM2RM_CS.EDD,eax
;;;
;;;	    mov     eax,[esp+@PM2RM_DIFF].PM2RM_EFL
;;;	    mov     [esp].PM2RM_EFL,eax
;;;
;;;	    mov     eax,[esp+@PM2RM_DIFF].PM2RM_ESP
;;;	    mov     [esp].PM2RM_ESP,eax
;;;
;;;	    mov     eax,[esp+@PM2RM_DIFF].PM2RM_SS.EDD
;;;	    mov     [esp].PM2RM_SS.EDD,eax
;;;
;;;	    mov     eax,[esp+@PM2RM_DIFF].PM2RM_ES.EDD
;;;	    mov     [esp].PM2RM_ES.EDD,eax
;;;
;;;	    mov     eax,[esp+@PM2RM_DIFF].PM2RM_DS.EDD
;;;	    mov     [esp].PM2RM_DS.EDD,eax
;;;
;;;	    mov     eax,[esp+@PM2RM_DIFF].PM2RM_FS.EDD
;;;	    mov     [esp].PM2RM_FS.EDD,eax
;;;
;;;	    mov     eax,[esp+@PM2RM_DIFF].PM2RM_GS.EDD
;;;	    mov     [esp].PM2RM_GS.EDD,eax
;;;
;;;	    lds     eax,RM2PM_STK_FVEC ; DS:EAX ==> initial stack
;;;	    assume  ds:nothing	    ; Tell the assembler about it
;;;
;;;	    push    ds:[eax].PM2RM_NEXT
;;;	    pop     [esp].PM2RM_NEXT
;;;
;;;	    push    ds:[eax].PM2RM_DEV_FLAG
;;;	    pop     [esp].PM2RM_DEV_FLAG
;;;
;;;	    push    ds:[eax].PM2RM_GDTR.DTR_BASE
;;;	    pop     [esp].PM2RM_GDTR.DTR_BASE
;;;
;;;	    push    ds:[eax].PM2RM_GDTR.DTR_LIM
;;;	    pop     [esp].PM2RM_GDTR.DTR_LIM
;;;
;;;	    push    DTE_LOAD+1*(type DESC_STR) ; Get load module's data selector
;;;	    pop     ds		    ; Address it
;;;	    assume  ds:DGROUP	    ; Tell the assembler about it
PM2RM_HANDLER2:
	and	[esp].EPRM_EFL,not (mask $VMHI) ; VM=0

	mov	eax,LCL_EAX	; Restore

	jmp	short ERM	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PM2RM_HANDLER endp		; End PM2RM_HANDLER procedure
	NPPROC	ERM -- Enter RM
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Enter RM

On entry:

We're in PM

SS:ESP	==>	VM IRETD stack frame
DS,ES,FS,GS,SS are still PM selectors

On exit:

We're in RM

|

	cli			; Disallow interrupts

; The PM stack has pushed onto it RM_GDTR through RM_EIP
; Pop these into the associated variables

	mov	ds,RGRSEL	; Get RGROUP data selector
	assume	ds:RGROUP	; Tell the assembler about it

	pop	RM_EIP		; Save	EIP temporarily
	pop	RM_CSF.EDD	; ...	CS w/filler
	pop	RM_EFL		; ...	EFL
	pop	RMSTK_FVEC.FOFF ; ...	ESP
	pop	RMSTK_FVEC.FSEL.EDD ; ... SS w/filler
	pop	RM_ESF.EDD	; ...	ES ...
	pop	RM_DSF.EDD	; ...	DS ...
	pop	RM_FSF.EDD	; ...	FS ...
	pop	RM_GSF.EDD	; ...	GS ...
	pop	RM_NEXT 	; ... next handler
;;;;;;; pop	RM_TRP		; ... @TRP_Ixx flag
	pop	DEV_FLAG	; ... flags set upon entry
	pop	RM_GDTR.DTR_LIM ; Old GDTR
	pop	RM_GDTR.DTR_BASE ; ...

	test	DEV_FLAG,@DEV_VCPI ; Are we using VCPI services?
	jz	short ERM_NOVCPI ; Jump if not

	lss	esp,VCPSTK_FVEC ; Use stack in one-to-one memory
				; as there's a bug in EMM386
	assume	ss:nothing	; Tell the assembler about it
	mov	SAVE_EAX,eax	; Save register

	mov	ax,seg PGROUP	; Get segment of PGROUP

	push	eax		; Pass resulting GS w/filler
	push	eax		; ...		 FS ...
	push	RGRSEG.EDD	; ...		 DS ...
	push	RGRSEG.EDD	; ...		 ES ...
	push	RMSTK_FVEC.FSEL.EDD ; ...	 SS ...
	push	RMSTK_FVEC.FOFF ; ...		 ESP
	pushfd			; ...		 EFL
	push	RGRSEG.EDD	; ...		 CS ...
	lea	eax,RGROUP:@F	; Get return EIP
	push	eax		; ...		 EIP ...

	mov	ax,DTE_4GB	; Get AGROUP data selector
	mov	ds,ax		; Address it
	assume	ds:AGROUP	; Tell the assembler about it

	cli			; Exit with IF=0

	mov	ax,(@VCPI shl 8) or @VCPI_EPM ; Get return function
	call	PMI_FVEC	; Request VCPI service
@@:
	assume	ds:RGROUP,es:RGROUP ; Tell the assembler about it
	assume	fs:PGROUP,gs:PGROUP ; Tell the assembler about it

	mov	eax,SAVE_EAX	; Restore

	add	GXTSTK_FVEC.FOFF,@GXTSTK_LEN ; Count in one stack frame

	jmp	short ERM_COM	; Join common code


	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
ERM_NOVCPI:
	FICALL	RGROUP:GOREAL,DTE_CS,<seg PGROUP> ; Enter RM
	assume	ds:RGROUP,es:RGROUP ; Tell the assembler about it
	assume	fs:PGROUP,gs:PGROUP ; Tell the assembler about it

; Note that SS still has the PM selector value and
; its descriptor cache has not been changed.

	lss	esp,RMSTK_FVEC	; Re-specify the stack
	assume	ss:nothing	; Tell the assembler about it

; Add back in this portion

	add	GXTSTK_FVEC.FOFF,@GXTSTK_LEN ; Count in one stack frame

; Restore the original GDTR

	LGDTD	RM_GDTR 	; Restore it

; Now that we're back in RM and on a valid stack, restore
; A20 to the state we found it.

	test	DEV_FLAG,@DEV_A20ON ; Wuzit enabled upon entry?
	jnz	short @F	; Jump if so

	call	DEGATEA20	; Disable address line A20
	jnc	short @F	; Jump if no error

	SWATMAC ERR,RM		; Call our debugger
@@:
ERM_COM:

; Note that we pass back the 32-bit IRETD frame so we can
; take advantage of possible RF setting

	push	RM_EFL		; Pass back EFL
	push	RM_CSF.EDD	; ...	    CS w/filler
	push	RM_EIP		; ...	    EIP

; Note that we re-specify DS last so as to use it for
; the other variables.

	mov	gs,RM_GSF	; ...	  GS
	assume	gs:nothing	; Tell the assembler about it

	mov	fs,RM_FSF	; ...	  FS
	assume	fs:nothing	; Tell the assembler about it

	mov	es,RM_ESF	; ...	  ES
	assume	es:nothing	; Tell the assembler about it

	mov	ds,RM_DSF	; Restore DS
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

ERM	endp			; End ERM procedure
	FPPROC	GOREAL -- Enter Real Mode
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

On entry:

We're in protected mode

On exit:

We're in real mode

DS,ES	=	RGROUP
FS,GS	=	PGROUP

Note that SS still has the PM selector value and
its descriptor cache has not been changed.

|

	push	eax		; Save register

	mov	ax,DTE_DS	; Get 64KB limit selector
	mov	ds,ax		; Set to known value
	mov	es,ax		; ...
	mov	fs,ax		; ...
	mov	gs,ax		; ...
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

	mov	ax,DTE_SSB0	; Get DTE_SS with Big bit clear
	mov	ss,ax		; Set to valid value
	assume	ss:nothing	; Tell the assembler about it
	nop			; So we can single-step the MOV SS,AX

; Load base and limit of IDT for real mode
; Note that we do it here in case the FAR JMP below signals
; an error.

	LIDTD	RM_IDTRL	; Reset IDT to the table in local memory

; Exit protected mode

	mov	eax,cr0 	; Get current CR0
	and	eax,not ((mask $PG) or (mask $PE)) ; Turn off PG & PE bit
	mov	cr0,eax 	; Exit protected mode

	xor	eax,eax 	; Flush the
	mov	cr3,eax 	; ...TLB

; Jump to real mode code

;;;;;;; FIJMP	RGROUP:@F,<seg RGROUP> ; Far jump to set access rights
	db	0EAh		; Far jump immediate
	dw	RGROUP:@F
GOREAL_SEG dw	seg RGROUP
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing ; Tell the assembler about it
@@:

; Re-initialize segment registers

	mov	ds,RGRSEG	; Get relocated RGROUP segment
	assume	ds:RGROUP	; Tell the assembler about it

	mov	es,RGRSEG	; Get relocated RGROUP segment
	assume	es:RGROUP	; Tell the assembler about it

	mov	ax,seg PGROUP
	mov	fs,ax
	assume	fs:PGROUP	; Tell the assembler about it

	mov	gs,ax
	assume	gs:PGROUP	; Tell the assembler about it

; Note that we have to wait until we switch back to the RM stack
; before degating A20 as the current stack is in extended memory.

	pop	eax		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

GOREAL	endp			; End GOREAL procedure
	NPPROC	CHECK_VMTF -- Check On VM And TF
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Check on VM and TF -- if either is set return ZF=0

On exit:

ZF	=	0 if either VM or TF set
	=	1 otherwise

|

	push	ax		; Save for a moment

	pushf			; Save flags to test TF
	pop	ax		; Save to test

	test	ax,mask $TF	; Izit set?
	jnz	short @F	; Jump if so (note ZF=0)

	smsw	ax		; Get MSW
	test	ax,PE_MASK	; Are we in VM?
				; Return with ZF=0 if so
@@:
	pop	ax		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_VMTF endp 		; End CHECK_VMTF procedure

	align	16		; Fill tail with NOPs

RCODE	ends			; End RCODE segment


RDATAZ	segment use16 para public 'rdataz'; Start RDATAZ segment
	assume	ds:RGROUP

	public	@GXT_DRV_RDATAZ
@GXT_DRV_RDATAZ label byte	; Mark module start in .MAP file

	public	RTAIL
RTAIL	label	byte		; This label marks the end of the device
				; driver resident code/data.

	public	RM_IDT
	align	4
RM_IDT	dd	256 dup (?)	; Real mode IDT filled in by SETINTS

	FPPROC	FGATEA20 -- Far Call To GATEA20
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Far call to GATEA20

|

	call	GATEA20 	; Gate A20 on

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FGATEA20 endp			; End FGATEA20 procedure
	FPPROC	FDEGATEA20 -- Far Call To DEGATEA20
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Far call to DEGATEA20

|

	call	DEGATEA20	; Gate A20 off

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FDEGATEA20 endp 		; End FDEGATEA20 procedure
	FPPROC	FCHECKA20 -- Far Call To CHECKA20
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Far call to CHECKA20

|

	call	CHECKA20	; Izit enabled?
				; Return with CF significant
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCHECKA20 endp			; End FCHECKA20 procedure

	public	RTAIL_NR
RTAIL_NR label	byte		; This label marks the end of the device
				; driver non-resident code/data.

RDATAZ	ends			; End RDATAZ segment


NDATA	segment use16 dword public 'ndata' ; Start NDATA segment
	assume	ds:NGROUP

	public	@GXT_DRV_NDATA
@GXT_DRV_NDATA	label byte	; Mark module start in .MAP file

	extrn	ARG_FLAG:word
	include GXT_ARG.INC

	extrn	MAPSEG_NXT:word
	extrn	MAPSEG_LST:word
	extrn	TSRSEG_1ST:word
	extrn	TSRSEG_NXT:word
	extrn	TSRSEG_LST:word

	public	EPM_GDT
EPM_GDT DTE_STR <>		; EPM GDT

	public	MOVE_TAB
MOVE_TAB MDTE_STR <>		; Move block descriptor tables

	public	PGXTGDT
PGXTGDT dd	RGROUP:GXTGDT	; Seg:Off of GXT's GDT

	public	PVCPEPM
PVCPEPM dd	RGROUP:VCPEPM	; Seg:Off of VCPEPM

	public	DOSCMD_VEC
DOSCMD_VEC dd	PSPGRP:PSP_PARM_STRING ; Seg:Off of DOS command line

	public	BIOSCONF_VEC
BIOSCONF_VEC dd 0		; Seg:Off of BIOS configuration data (0 if none)

	public	GXT_TSIZ,GXT_ISIZ,GXT_USIZ,GXT_DAT,GXT_XTRA
GXT_TSIZ dd	?		; Total size of PM-resident GXT module
GXT_ISIZ dd	?		; Size of initialized code/data
GXT_USIZ dd	?		; ...	  uninitialized data
GXT_DAT dd	?		; Offset to data segment
GXT_XTRA dd	\
(@GXTSTK_LEN*@GXTSTK_CNT) + \
(256*(type IDT_STR)) + \
(size TSS_STR) + \
(256/8) + \
(8*1024 + 1)	; Size of extra data

	public	OLDINT67_VEC
OLDINT67_VEC dd ?		; Old INT 67h handler

;;;	 public  MMPaXMS
;;; MMPaXMS dd	    ?		    ; Physical address of XMS allocation if VCPI/MM
;;;
	public	RUDLaGDT,RUDLaIDT,RUDGDTCNT,RUDIDTCNT
RUDLaGDT dd	?		; Linear address in our space of MM's GDT
RUDLaIDT dd	?		; ...				      IDT
RUDGDTCNT dw	?		; # PTEs needed by GDT
RUDIDTCNT dw	?		; ...		   IDT

	public	RUDSTK
RUDSTK	dd	32 dup (?)	; INTRUDE stack
RUDSTKZ label	dword		; End of ...

	public	XMSDRV_VEC
XMSDRV_VEC dd	?		; Seg:Off of XMS driver entry point

	public	DDS
DDS	DDS_STR <>		; DMA Descriptor Structure

	public	LaCODE,LaDATA,LaIDT,LaTSS,LaSTK,LaEND,OffCR3,OffPDIR
	public	SegCR3,SegPTE,SegIDT,SegTSS
	public	NEXTPTE,NDRVPDIR,NDRVPTE,NLODPTE
	public	LaPSWAT,PSWAT_TSIZ
	public	TSS_LEN
LaCODE	dd	?		; Linear address of our code segment
LaDATA	dd	?		; ...			data
LaIDT	dd	?		; ...			IDT
LaTSS	dd	?		; ...			TSS
LaSTK	dd	?		; ...		    GXT's stack
LaEND	dd	?		; ...		    the end (including extra data)
LaPSWAT dd	-1		; ...		    PSWAT's code/data (-1=none) (/4KB)
PSWAT_TSIZ dd	4*1024*1024	; Total size of PM-resident preceding SWAT (/4KB)
				; Note we don't know the actual size, so we guess
OffCR3	dd	?		; Offset of CR3 in SegPTE
OffPDIR dd	?		; ...	    PDIRs ...
SegCR3	dw	?		; Segment of CR3	CR3 (/4KB)
SegPTE	dw	?		; ...			PTEs (/4KB)
SegIDT	dw	?		; ...			IDT
SegTSS	dw	?		; ...			TSS
NEXTPTE dd	?		; Offset of next available PTE in PDT
NDRVPDIR dd	?		; # PDIRs needed for VCPI GXT counting the IDT,
				; stack, and TSS
NDRVPTE dd	?		; # PTEs ...
NLODPTE dd	0		; # PTEs needed for load modules
TSS_LEN dd	?		; Length of TSS data in bytes

	public	XMBMOVE
XMBMOVE XMBMOVE_STR <>		; XMS Block Move

	public	PHYSIZE
PHYSIZE dd	0		; Size of physical memory in 1KB

	public	PMSTK_FVEC
PMSTK_FVEC df	?		; PM stack for VCPI EPM

	public	EPM_FLAG
EPM_FLAG dw	0		; EPM flags
EPM_REC record	\
$EPM_A20ON:1

@EPM_A20ON equ	(mask $EPM_A20ON) ; A20 enabled at start of EPM

	public	DOSVER
DOSVER	dw	?		; DOS version #

	public	PSWAT_VER,PSWAT_CR3SEL,PSWAT_4GBSEL
PSWAT_VER dw	?		; Version # of preceding SWAT (if any)
PSWAT_CR3SEL dw 0		; CR3 selector (0=none)
PSWAT_4GBSEL dw 0		; 4GB ...

	public	MEMBUF
MEMBUF	MB_STR	<>		; Buffer for E820 results

	public	CPUFET_FLAG
CPUFET_FLAG CPUFET_REC <>	; CPU feature bits

	public	SYMTRAN
SYMTRAN SYMTRAN_STR <>		; Symbol translation struc for SWAT

	public	MEMCNT
MEMCNT	dw	0		; Count of memory entries

	public	XMSZLEN
XMSZLEN dw	0		; Zero-length XMS handle (0=none)

	public	PICBASE
PICBASE dw	0870h		; (Master, Slave) PIC base values

	public	PRTAIL
PRTAIL	dw	RGROUP:RTAIL	; Offset of next available byte in RGROUP

	public	DRV_ERRMSG
DRV_ERRMSG dw	-1		; Address of driver error message (-1=none)

	public	RUD_ERRMSG
RUD_ERRMSG dw	-1		; Address of INTRUDE error message (-1=none)

	public	XMS_QRYXMB,XMS_GETXMB,XMS_MODXMB
XMS_QRYXMB db	@XMS_QRYXMB	; Function code for Query XMS Memory
XMS_GETXMB db	@XMS_GETXMB	; ...		    Allocate ...
XMS_MODXMB db	@XMS_MODXMB	; ...		    Re-allocate ...

	public	ERRCODE
ERRCODE db	0		; Error code returned to DOS

	public	DEVNMIPORT,DEVNMIENA,DEVNMIDIS,DEVNMIMASK
DEVNMIPORT dw	@CMOS_CMD	; NMI clear I/O port
DEVNMIENA  db	@CMOS_ENANMI	; ... enable value
DEVNMIDIS  db	@CMOS_DISNMI	; ... disable value
DEVNMIMASK db	mask $ATPAR	; ... clear mask

	public	SWTNAME,MAXNAME,QEMMNAME
SWTNAME db	'386SWAT$',0    ; 386SWAT device name
MAXNAME db	'386MAX$$',0    ; 386MAX ...
QEMMNAME db	'QEMM386$',0    ; QEMM ...

	public	EMMNAME,EMMNAM2,EMMNAM3
EMMNAME db	'EMMXXXX0',0    ; Generic EMM device name
EMMNAM2 db	'$MMXXXX0',0    ; MSDOS device name if NOEMS
EMMNAM3 db	'EMMQXXX0',0    ; NetRoom/DRDOS device name if NOFRAME
;;;NAM4  db	 'EMMXXXQ0',0   ; QEMM device name if NOEMS
;;;NAM5  db	 'QMMXXXX0',0   ; 386MAX device name if EMS=0

MMDEV_STR struc

MMDEV_OFF dw	?		; Offset in NGROUP of ASCIIZ name
MMDEV_FLG dw	?		; DEV_FLAG bits to set

MMDEV_STR ends

COMMENT|

Note that we do not include in this table the device name for either
QEMM or 386MAX when EMS support is disabled as we catch them through
their nested device names which are always present.

|

	public	PMMDEV
	align	2		; Ensure word alignment
PMMDEV	MMDEV_STR <NGROUP:MAXNAME, @DEV_VDS or @DEV_MAX> ; 386MAX nested device name
	MMDEV_STR <NGROUP:QEMMNAME,@DEV_FCR3> ; QEMM nested device name
	MMDEV_STR <NGROUP:EMMNAM2, 0	     > ; MSDOS w/NOEMS
	MMDEV_STR <NGROUP:EMMNAM3, 0	     > ; NetRoom/DRDOS w/NOFRAME
;;;;;;; MMDEV_STR <NGROUP:EMMNAM4, @DEV_FCR3> ; QEMM w/NOEMS
;;;;;;; MMDEV_STR <NGROUP:EMMNAM5, 0	     > ; 386MAX w/EMS=0
	MMDEV_STR <NGROUP:EMMNAME, 0	     > ; Generic should be last
PMMDEV_LEN equ ($-PMMDEV)/(type MMDEV_STR) ; # entries

	public	INTA01,INTB01
INTA01	db	?		; Save area for master IMR
INTB01	db	?		; ...		slave

	public	MACHID
MACHID	db	?		; Machine ID

	public	MSG_NOVCPMEM,MSG_NOTINST,MSG_PRESS
MSG_NOVCPMEM db '様> Insufficient VCPI memory to load.',CR,LF,EOS
MSG_NOTINST db	'様> ',@FILENAME,' not installed.',CR,LF,EOS
MSG_PRESS db	BEL,'    Press any key to continue...',CR,LF,EOS

	public	OLDDEVSTK_VEC,INIDEVSTK_VEC
	align	4
OLDDEVSTK_VEC dd ?		; Save area for old stack pointer
INIDEVSTK_VEC dd NGROUP:DEVSTKZ ; Pointer to local stack

	public	DEVSTK
DEVSTK	dw	256 dup (?)	; Local initialization stack
DEVSTKZ label	word

	public	MSG_VCPI,MSG_PSWAT
	public	MSG_DEVGXT,MSG_VCPIGXT,MSG_LOADGXT
MSG_VCPI  db	"....VCPI host detected.",CR,LF,EOS
MSG_PSWAT db	"....Preceding SWAT detected.",CR,LF,EOS
MSG_DEVGXT db	"....Loading as Real Mode program.",CR,LF,EOS
MSG_VCPIGXT db	"....Loading as Virtual Mode program.",CR,LF,EOS
MSG_LOADGXT db	"....Loading as Protected Mode program.",CR,LF,EOS

	public	MSG_RUDEGXT
MSG_RUDEGXT db	"....Loading as PL0 Intrude program.",CR,LF,EOS

	public	MSG_NOVCPI,MSG_NOTAIL
MSG_NOVCPI db	BEL,"様> The CPU is in Virtual Mode and there's no VCPI host.",CR,LF,EOS
MSG_NOTAIL db	BEL,'様> Program error:  RTAIL > P1TAIL (need     '
MSG_NOTAIL1 db	'_ more bytes).',CR,LF,EOS

	public	MEMERR
	public	MEMERR_SEGPTE,MEMERR_ALLPTE,MEMERR_TSS,MEMERR_IDT
	public	MEMERR_IREAL,MEMERR_DVGA,MEMERR_PRO,MEMERR_VIDEO
MEMERR	db	BEL,'様> Out of memory error at:  ',EOS
MEMERR_SEGPTE db 'SegPTE',CR,LF,EOS   ; Specific error message
MEMERR_ALLPTE db 'All PTEs',CR,LF,EOS ; ...
MEMERR_TSS db	'TSS',CR,LF,EOS      ; ...
MEMERR_IDT db	'IDT',CR,LF,EOS      ; ...
MEMERR_IREAL db 'INIT_REAL',CR,LF,EOS ; ...
MEMERR_DVGA db	'DVGA',CR,LF,EOS     ; ...
MEMERR_PRO  db	'PRO=',CR,LF,EOS     ; ...
MEMERR_VIDEO db 'VIDEO=',CR,LF,EOS   ; ...

	public	MSG_CHECK_XMS,MSG_CHECK_MODEL,MSG_CHECK_VCPI
	public	MSG_CHECK_EXT,MSG_CHECK_PSWAT,MSG_DEV_ARGS,MSG_INIT_VCPI
	public	MSG_IZIT_CPUID,MSG_CHECK_P5,MSG_CHECK_NDP,MSG_CHECK_VID,
	public	MSG_CHECK_ARGS,MSG_CHECK_BPI,MSG_SET_MONO,MSG_SET_CO80,
	public	MSG_U16_SET_ATTRS
	public	MSG_VCPI_PRES,MSG_VCPI_DPRES,MSG_VCPI_GETINFO
	public	MSG_VCPI_DBGLIN,MSG_VCPI_DBGINI2
MSG_CHECK_XMS db    '....Calling CHECK_XMS',CR,LF,EOS
MSG_CHECK_MODEL db  '....Calling CHECK_MODEL',CR,LF,EOS
MSG_CHECK_VCPI	db  '....Calling CHECK_VCPI',CR,LF,EOS
MSG_CHECK_EXT db    '....Calling CHECK_EXT',CR,LF,EOS
MSG_CHECK_PSWAT db  '....Calling CHECK_PSWAT',CR,LF,EOS
MSG_DEV_ARGS	db  '....Calling DEV_ARGS',CR,LF,EOS
MSG_IZIT_CPUID	db  '....Calling MSG_IZIT_CPUID',CR,LF,EOS
MSG_CHECK_P5	db  '....Calling MSG_CHECK_P5',CR,LF,EOS
MSG_CHECK_NDP	db  '....Calling MSG_CHECK_NDP',CR,LF,EOS
MSG_CHECK_VID	db  '....Calling MSG_CHECK_VID',CR,LF,EOS
MSG_CHECK_ARGS	db  '....Calling MSG_CHECK_ARGS',CR,LF,EOS
MSG_CHECK_BPI	db  '....Calling MSG_CHECK_BPI',CR,LF,EOS
MSG_SET_MONO	db  '....Calling MSG_SET_MONO',CR,LF,EOS
MSG_SET_CO80	db  '....Calling MSG_SET_CO80',CR,LF,EOS
MSG_U16_SET_ATTRS db'....Calling MSG_U16_SET_ATTRS',CR,LF,EOS
MSG_INIT_VCPI	db  '....Calling INIT_VCPI',CR,LF,EOS
MSG_VCPI_PRES	db  '....Calling @VCPI_PRES',CR,LF,EOS
MSG_VCPI_DPRES	db  '....Calling @VCPI_DPRES',CR,LF,EOS
MSG_VCPI_GETINFO db '....Calling @VCPI_GETINFO',CR,LF,EOS
MSG_VCPI_DBGLIN db  '....Calling @VCPI_DBGLIN',CR,LF,EOS
MSG_VCPI_DBGINI2 db '....Calling @VCPI_DBGINI2',CR,LF,EOS

	public	SHF_FLAG
SHF_FLAG db	0		; 1 = Shift-GXT enabled, 0 = not

NDATA	ends			; End NDATA segment


NCODE	segment use16 para public 'ncode' ; Start NCODE segment
	assume	cs:NGROUP

	public	@GXT_DRV_NCODE
@GXT_DRV_NCODE: 		; Mark module start in .MAP file

	extrn	DISP_COPY:near
	extrn	DISP_ERRMSG:near
	extrn	SKIP_WHITE:near
	extrn	CHECK_I78:near
	extrn	CHECK_I92:near
;;;;;;; extrn	INTRUDE:near
	extrn	INIT_MAX:near
;;;;;;; extrn	XMS_UNINST:near
	extrn	SET_LOAD_DTE:near
	extrn	BIN2BASE:near

	NPPROC	DOSCMD -- DOS Command Line Entry
	assume	ds:nothing,es:PSPGRP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DOS command line entry

On entry:

On exit:

|

	movzx	esp,sp		; In case it's non-zero
	lss	sp,INIDEVSTK_VEC ; Install our local stack
	assume	ss:nothing	; Tell the assembler about it

	push	seg NGROUP	; Get NGROUP data segment
	pop	ds		; Address it
	assume	ds:NGROUP	; Tell the assembler about it

	push	seg PGROUP	; Get PGROUP data segment
	pop	fs		; Address it
	assume	fs:PGROUP	; Tell the assembler about it

	push	seg RGROUP	; Get RGROUP data segment
	pop	gs		; Address it
	assume	gs:RGROUP	; Tell the assembler about it

	or	DEV_FLAG,@DEV_DOSCMD ; Mark as loading from DOS command line
	mov	DOSCMD_VEC.VSEG,es ; Save as segment of PSP
	mov	PSP_SEG,es	; ...
	mov	ax,PSP_STOR_MAX ; Get highest para
	mov	MAPSEG_LST,ax	; Save for later use

	call	INIT_COM	; Call code common to Device Driver/DOS Command line
	jnc	short DOSCMD_OK ; Jump if all went well

	mov	ERRCODE,-1	; Tell 'em we failed
DOSCMD_EXIT:
	mov	al,ERRCODE	; Get the return error code
	DOSCALL @EXITRC 	; Return to DOS, with error code

DOSCMD_OK:

; Free our environment

	xor	ax,ax		; Zero the segment
	xchg	ax,PSP_ENVIR_PTR ; AX:0 ==> environment

	mov	es,ax		; ES:0 ==> environment
	assume	es:nothing	; Tell the assembler about it

	DOSCALL @RELMEM 	; Release segment ES

; Go resident

	mov	dx,TSRSEG_NXT	; Get next available TSR segment
	mov	ax,PRTAIL	; Get ending offset in RGROUP
	add	ax,16-1 	; Round up to para boundary
	shr	ax,4-0		; Convert from bytes to paras
	add	dx,ax		; Add to TSR segment

	sub	dx,TSRSEG_1ST	; Less the first one
	jz	short DOSCMD_EXIT ; Jump if nothing went resident

	add	dx,256/16	; Plus the size of the PSP

	mov	al,ERRCODE	; Get the return error code
	DOSCALL @KEEPRC 	; Go resident with error code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DOSCMD	endp			; End DOSCMD procedure
	NPPROC	CHECK_SHIFT -- Check Keyboard Shift States
	assume	ds:NGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Check keyboard shift states

|

	REGSAVE <es>		; Save for a moment

	push	seg BIOSDATA	; Get segment of BIOS data area
	pop	es		; Address it
	assume	es:BIOSDATA	; Tell the assembler about it

	test	KB_FLAG,(mask $KB_LSHFT) or (mask $KB_RSHFT) ; Either shift key down?
	jz	short @F	; Jump if not

	mov	SHF_FLAG,1	; Mark as Shift-GXT enabled
@@:
	REGREST <es>		; Restore
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_SHIFT endp		; End CHECK_SHIFT procedure
	NPPROC	DISP_PROGMSG -- Display Progress Message
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Display progress message

|

DPM_STR struc

	dw	?		; Caller's BP
	dw	?		; ...	   IP
DPM_OFF dw	?		; Offset in NGROUP of progress message

DPM_STR ends

	push	bp		; Prepare to address the stack
	mov	bp,sp		; Hello, Mr. Stack

	cmp	SHF_FLAG,1	; Izit enabled?
	jne	short DISP_PROGMSG_EXIT ; Jump if not

	REGSAVE <ax,dx,ds>	; Save registers

	mov	ax,cs		; Get segment of NGROUP
	mov	ds,ax		; Address it
	assume	ds:NGROUP	; Tell the assembler about it

	mov	dx,[bp].DPM_OFF ; Get offset in NGROUP of progress message
	DOSCALL @STROUT 	; Display specific name

	REGREST <ds,dx,ax>	; Restore
	assume	ds:nothing	; Tell the assembler about it
DISP_PROGMSG_EXIT:
	pop	bp		; Restore

	ret	2		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DISP_PROGMSG endp		; End DISP_PROGMSG procedure
	NPPROC	DISP_NORMMSG -- Display Normal Message
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Display normal message

|

DNM_STR struc

	dw	?		; Caller's BP
	dw	?		; ...	   IP
DNM_OFF dw	?		; Offset in NGROUP of normal message

DNM_STR ends

	push	bp		; Prepare to address the stack
	mov	bp,sp		; Hello, Mr. Stack

	REGSAVE <ax,dx,ds>	; Save registers

	mov	ax,cs		; Get segment of NGROUP
	mov	ds,ax		; Address it
	assume	ds:NGROUP	; Tell the assembler about it

	mov	dx,[bp].DNM_OFF ; Get offset in NGROUP of normal message
	DOSCALL @STROUT 	; Display specific name

	REGREST <ds,dx,ax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	pop	bp		; Restore

	ret	2		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DISP_NORMMSG endp		; End DISP_NORMMSG procedure
	NPPROC	CHECK_NXTSEG -- Check On Next Segment
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Check on next segment to ensure we have enough room

|

CNS_STR struc

	dw	?		; Caller's BP
	dw	?		; ...	   IP
CNS_OFF dw	?		; Offset in NGROUP of error text

CNS_STR ends

	push	bp		; Prepare to address the stack
	mov	bp,sp		; Hello, Mr. Stack

	REGSAVE <ax,dx,ds>	; Save registers

	mov	ax,MAPSEG_NXT	; Get next available segment

	cmp	ax,MAPSEG_LST	; Check against the last segment
	jbe	short @F	; Jump if within range

	mov	ax,cs		; Get segment of NGROUP
	mov	ds,ax		; Address it
	assume	ds:NGROUP	; Tell the assembler about it

	push	offset NGROUP:MEMERR ; Pass offset in NGROUP of error msg
	call	DISP_ERRMSG	; Tell 'em there's an error

	push	[bp].CNS_OFF	; Pass offset in NGROUP of specific text
	call	DISP_ERRMSG	; Tell 'em there's an error
@@:
	REGREST <ds,dx,ax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	pop	bp		; Restore

	ret	2		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_NXTSEG endp		; End CHECK_NXTSEG procedure
	FPPROC	DEV_INTR_NR -- Device Interrupt Routine
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Non-resident device driver interrupt routine.

|

.8086
	mov	OLDDEVSTK_VEC.VOFF,sp ; Save old stack pointer
	mov	OLDDEVSTK_VEC.VSEG,ss ; ...
DOT386 p
	movzx	esp,sp		; In case it's non-zero
	lss	sp,INIDEVSTK_VEC ; Install our local stack
	assume	ss:nothing	; Tell the assembler about it

	pushad			; Save all EGP registers
	REGSAVE <ds,es,fs,gs>	; Save segment registers

	push	seg NGROUP	; Get NGROUP data segment
	pop	ds		; Address it
	assume	ds:NGROUP	; Tell the assembler about it

	push	seg PGROUP	; Get PGROUP data segment
	pop	fs		; Address it
	assume	fs:PGROUP	; Tell the assembler about it

	push	seg RGROUP	; Get RGROUP data segment
	pop	gs		; Address it
	assume	gs:RGROUP	; Tell the assembler about it

	les	bx,RH_VEC	; ES:BX ==> request header
	assume	es:nothing	; Tell the assembler about it

	STATUS	DONE,NOERROR	; Set status word (done, no error)

; Mark as being loaded as a device driver

	or	DEVLOAD,@DEVL_LOAD ; Mark it

	cmp	es:[bx].SRH_CCD,0 ; Izit initialization?
	jne	near ptr DEV_INTR_NR_EXIT ; Not this time

	mov	ax,es:[bx].INIT_END_VEC.VSEG ; Get last available para
	mov	MAPSEG_LST,ax	; Save for later use

	push	ds		; Save for a moment

	push	seg DGROUP	; Get DGROUP data segment
	pop	ds		; Address it
	assume	ds:DGROUP	; Tell the assembler about it

;;	xor	eax,eax 	; Zero to use as dword
;;	mov	ax,seg PGROUP	; Get segment to which DEVINTCOM is relocated
;;	shl	eax,4-0 	; Convert from paras to bytes
;;	add	eax,offset RGROUP:DEVINTCOM ; Plus its offset
;;	mov	LaDEVINTCOM,eax ; Save for later use
;;
	xor	eax,eax 	; Zero to use as dword
	mov	ax,seg PGROUP	; Get segment to which RM_IDTRL is relocated
	shl	eax,4-0 	; Convert from paras to bytes
	add	eax,offset RGROUP:RM_IDT ; Plus its offset
	mov	LaRM_IDT,eax	; Save for later use

	pop	ds		; Restore
	assume	ds:NGROUP	; Tell the assembler about it

	call	INIT_COM	; Call code common to Device Driver/DOS Command line
	jc	short DEV_INTR_NR_ERR ; Jump if something went wrong

	mov	ax,TSRSEG_NXT	; Get next available segment
	mov	es:[bx].INIT_END_VEC.VSEG,ax ; Mark as ending address
	mov	ax,PRTAIL	; Get ending offset in RGROUP
	mov	es:[bx].INIT_END_VEC.VOFF,ax ; ...

	jmp	short DEV_INTR_NR_EXIT ; Join common exit code


DEV_INTR_NR_ERR:
	mov	GXTINI.MD_DD.DD_ATTR,0 ; Bug in DOS doesn't allow char devices to
				; fail initialization -- convert to block device
	mov	es:[bx].INIT_UNITS,0 ; No units defined
	mov	es:[bx].INIT_END_VEC.VSEG,seg PGROUP ; Mark as ending address
	mov	es:[bx].INIT_END_VEC.VOFF,0 ; ...

	STATUS	DONE,ERROR,ERR_UGH ; Mark as general failure
DEV_INTR_NR_EXIT:
	REGREST <gs,fs,es,ds>	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; ...
	popad			; Restore all EGP registers

	lss	sp,OLDDEVSTK_VEC ; Restore original stack
	assume	ss:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEV_INTR_NR endp		; End DEV_INTR_NR procedure
	NPPROC	INIT_COM -- Common Initialization Code
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Common initialization code

On exit:

CF	=	0 if successful
	=	1 if not

|

	pushad			; Save all EGP registers

; Mark as being loaded as a device driver

	or	DEVLOAD,@DEVL_LOAD ; Mark it

; Set TSRSEG_LST here because MS LINK doesn't handle a certain
; FIXUPP record correctly but QLINK does, so before this change
; this file was different depending upon which linker was used

	add	TSRSEG_LST,@TSRSIZE/16 ; Handle fixup ourselves

	call	DISP_COPY	; Display our copyright notice

; Get DOS version #

	REGSAVE <ax,bx,cx>	; Save registers

	DOSCALL @DOSVER 	; Return with
				; AL=major
				; AH=minor
				; BX=CX=0
	xchg	al,ah		; Swap to comparison order
	mov	DOSVER,ax	; Save for later use

	REGREST <cx,bx,ax>	; Restore

; See if RTAIL is below P1TAIL

	lea	eax,RTAIL	; Get offset of RTAIL

	sub	eax,offset PGROUP:P1TAIL ; Check against P1TAIL
	jbe	short INIT_COM1 ; Jump if OK

	REGSAVE <cx,dx,di,es>	; Save for a moment

; Format AX into the error message

	mov	di,ds		; Get NGROUP segment
	mov	es,di		; Address it
	assume	es:NGROUP	; Tell the assembler about it

	lea	di,MSG_NOTAIL1	; ES:DI ==> units digit in message
	mov	cx,10		; Use base 10 to convert
	call	BIN2BASE	; Convert AX to ASCII ending at ES:DI

	push	offset NGROUP:MSG_NOTAIL ; Pass offset in NGROUP of error msg
	call	DISP_ERRMSG	; Tell 'em there's an error

	REGREST <es,di,dx,cx>	; Restore
	assume	es:nothing	; Tell the assembler about it

	jmp	short INIT_COM_ERR ; Jump if something went wrong


INIT_COM1:

; See if either shift key is held down

	call	CHECK_SHIFT	; Check on shift key state

; See if this CPU supports the CPUID instruction

	STROUT	IZIT_CPUID
	call	IZIT_CPUID	; Check on it

; Check on preceding device SWAT.  Note we put the check here
; so we can test the presence bit in INIT_REAL.

	STROUT	CHECK_PSWAT
	call	CHECK_PSWAT	; Check on it *DEBUG*

; See if there's an XMS handler present

	STROUT	CHECK_XMS
	call	CHECK_XMS	; See if it's present

; See what type of system we're running on

	STROUT	CHECK_MODEL
	call	CHECK_MODEL	; Set model-specific flags

; See if there's a VCPI host present

	STROUT	CHECK_VCPI
	call	CHECK_VCPI	; See if it's present
	jc	short INIT_COM_ERR ; Jump if something went wrong

; Get physical size of memory

	STROUT	CHECK_EXT
	call	CHECK_EXT	; Get size of extended memory

	call	SAVEINTS	; Save current interrupt handlers

	STROUT	DEV_ARGS
	call	DEV_ARGS	; Process arguments, call INIT_REAL
	jc	short INIT_COM_ERR ; Jump if something went wrong

	STROUT	INIT_VCPI
	call	INIT_VCPI	; Initialize VCPI data if appropriate
	jc	short INIT_COM_ERR ; Jump if something went wrong

;;;	    test    DEV_FLAG,@DEV_INTRUDE ; Are we INTRUDEing today?
;;;	    jnz     short INIT_COM_INTRUDE ; Jump if we were successful
;;;
; Copy the resident portion to extended memory

	call	LOADUP		; Copy it upstairs
	jc	short INIT_COM_ERR ; Jump if something went wrong

	call	PROT_INIT	; Initialize PM
	jc	short INIT_COM_ERR ; Jump if something went wrong
;;; INIT_COM_INTRUDE:
	call	COPYLOW 	; Copy RGROUP to low memory in PGROUP

;;;	    test    DEV_FLAG,@DEV_INTRUDE ; Are we INTRUDEing today?
;;;	    jnz     short @F	    ; Jump if so
;;;
	call	SETINTS 	; Setup interrupt handlers
;;; @@:
	call	VIRT_INIT	; Initialize VM
	jnc	short INIT_COM_EXIT ; Jump if all went well (note CF=0)

	call	UNSETINTS	; Restore interrupt handlers
INIT_COM_ERR:
	test	ARG_FLAG,@ARG_UNINST ; Are we uninstalling?
	jnz	short INIT_COM_ERR1 ; Jump if so

	REGSAVE <ax,dx> 	; Save for a moment

	mov	dx,DRV_ERRMSG	; Get address of error message (if any)

	cmp	dx,-1		; Izit valid?
	je	short @F	; Jump if not

	push	dx		; Pass offset in NGROUP of error msg
	call	DISP_ERRMSG	; Tell 'em there's an error
@@:
	push	offset NGROUP:MSG_NOTINST ; Pass offset in NGROUP of error msg
	call	DISP_ERRMSG	; Tell 'em we're not installed

	push	offset NGROUP:MSG_PRESS ; Pass offset in NGROUP of error msg
	call	DISP_ERRMSG	; Tell 'em what to do

; Purge the keyboard buffer and wait for a key press -- discard the key

	call	KEYWAIT 	; Wait for an acknowledgement
				; Return with key in AX
	REGREST <dx,ax> 	; Restore
INIT_COM_ERR1:
	stc			; Mark as in error
INIT_COM_EXIT:
	pushf			; Save state of CF

	REGSAVE <ax,bx,dx>	; Save for a moment

; If we allocated a zero-length XMS handle, free it now

	mov	dx,XMSZLEN	; Get XMS handle

	and	dx,dx		; Wuzit allocated?
	jz	short @F	; Jump if not

	mov	ah,@XMS_RELXMB	; Function code to free XMS memory
	call	XMSDRV_VEC	; Request XMS service

	cmp	ax,1		; Did it work?
	je	short @F	; Jump if so

	SWATMAC ERR,RM		; Call our debugger
@@:
	REGREST <dx,bx,ax>	; Restore

	popf			; Restore CF

	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INIT_COM endp			; End INIT_COM procedure
	NPPROC	IZIT_CPUID -- Determine Support of CPUID Instruction
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

The test for the CPUID instruction is done by attempting to set the ID
bit in the high-order word of the extended flag dword.	If that's
successful, the CPUID instruction is supported; otherwise, it's not.

On exit:

CPUFET_FLAG filled in if it's supported

|

	push	bp		; Save to address the stack
	clc			; Assume it's not supported
	pushfd			; Save original flags
	pushfd			; Save temporary flags

IZIT_CPUID_STR struc

IZIT_CPUID_TMPEFL dd ?		; Temporary EFL
IZIT_CPUID_RETEFL dd ?		; Return EFL
	dw	?		; Caller's BP

IZIT_CPUID_STR ends

	mov	bp,sp		; Address the stack
	or	[bp].IZIT_CPUID_TMPEFL,mask $ID ; Set ID bit
	popfd			; Put into effect

	pushfd			; Put back onto the stack to test

	test	[bp].IZIT_CPUID_TMPEFL,mask $ID ; Izit still set?
	jz	short @F	; No, so it's not supported

	REGSAVE <eax,ebx,ecx,edx> ; Save for a moment

	mov	eax,1		; Function code to retrieve feature bits
	CPUID			; Return with EAX = stepping info
				;	      EBX, ECX reserved
				;	      EDX = feature bits
	mov	CPUFET_FLAG,edx ; Include in our list

	REGREST <edx,ecx,ebx,eax> ; Restore
@@:
	popfd			; Restore temporary flags
	popfd			; Restore original flags
	pop	bp		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

IZIT_CPUID endp 		; End IZIT_CPUID procedure
	NPPROC	CHECK_XMS -- Check On XMS Driver
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Check on XMS driver

|

	REGSAVE <ax,bx,dx,es>	; Save registers

	mov	ax,4300h	; Function code to check on XMS driver
	int	2Fh		; Request multiplexor service

	cmp	al,80h		; Izit present?
	jne	short CHECK_XMS_EXIT ; Jump if not

	mov	ax,4310h	; Function code to get driver entry point
	int	2Fh		; Request multiplexor service
	assume	es:nothing	; Tell the assembler about it

	mov	XMSDRV_VEC.VOFF,bx ; Save for later use
	mov	XMSDRV_VEC.VSEG,es ; ...

; Check the version #

	mov	ah,@XMS_VERS	; Function code to get version #
	call	XMSDRV_VEC	; Request XMS service
				; Return with AX = version #
				; ...	      DX = debugging version #
	cmp	ax,0300h	; Izit version 3.00 or later?
	jb	short @F	; Jump if not

	mov	XMS_QRYXMB,@XMS_QRY2XMB ; Use new function
	mov	XMS_GETXMB,@XMS_GET2XMB ; ...
	mov	XMS_MODXMB,@XMS_MOD2XMB ; ...
@@:
	or	DEV_FLAG,@DEV_XMS ; Mark as present
CHECK_XMS_EXIT:
	REGREST <es,dx,bx,ax>	; Restore
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_XMS endp			; End CHECK_XMS procedure
	NPPROC	CHECK_VCPI -- Check On VCPI Host
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Check on VCPI host

|

	pushad			; Save all EGP registers

; In case we're under a memory manager in AUTO mode, allocate
; a zero-length XMS handle to put it into VM.

	test	DEV_FLAG,@DEV_XMS ; Is there an XMS driver present?
	jz	short @F	; Jump if not

	xor	edx,edx 	; Size of request in kilobytes
	mov	ah,XMS_GETXMB	; Function code to allocate eDX kilobytes
	call	XMSDRV_VEC	; Request XMS service

	cmp	ax,1		; Did it work?
	jne	short @F	; Jump if not

	mov	XMSZLEN,dx	; Save to free later
@@:
	smsw	ax		; Get MSW

	test	ax,mask $PE	; Izit in VM86 mode?
	jz	near ptr CHECK_VCPI_CLC ; Jump if not

; Check for various known memory managers

	mov	cx,PMMDEV_LEN	; Get # table entries
	xor	si,si		; Initialize index into table
CHECK_VCPI_NEXT:
	mov	al,@OPEN_R	; Code for read-only access
	mov	dx,PMMDEV[si].MMDEV_OFF ; Get offset in NGROUP of ASCIIZ name
	DOSCALL @OPENF2 	; Attempt to open the device
	jnc	short CHECK_VCPI_FND ; Jump if present
CHECK_VCPI_LOOP:
	add	si,type MMDEV_STR ; Skip to next entry

	loop	CHECK_VCPI_NEXT ; Jump if more table entries to check

	jmp	CHECK_VCPI_ERR	; Join common error code


CHECK_VCPI_FND:
	mov	bx,ax		; Copy to handle register

	mov	al,0		; Code to get device info
	DOSCALL @IOCTL2 	; Return with DX = device info
	pushf			; Save CF from DOSCALL
	DOSCALL @CLOSF2 	; Close the file
	popf			; Restore
	jc	short CHECK_VCPI_LOOP ; Jump if IOCTL failed

	test	dx,@IOCTL_DEV	; Izit a device?
	jz	short CHECK_VCPI_LOOP ; Jump if not

; Set the flag bits

	mov	ax,PMMDEV[si].MMDEV_FLG ; Get DEV_FLAG bits to set
	or	DEV_FLAG,ax	; Set them bits

; See if there's a VCPI host present

CHECK_VCPI_FND1:
	STROUT	VCPI_PRES
	VCPICALL @VCPI_PRES	; Check on VCPI host
				; Return with AH = 0 if present
				;	 (BH,BL) = version #
	cmp	ah,0		; Izit present?
	jne	short CHECK_VCPI_ERR ; Jump if not

	DOSCALL @STROUT,MSG_VCPI ; Tell 'em what we found

	or	DEV_FLAG,@DEV_VCPI ; Mark as using VCPI services to enter PM
	or	DEVLOAD,@DEVL_VCPI ; ...
	mov	PE_MASK,0	; Zero for CHECK_VMTF
	mov	VCPSTK_FVEC.FSEL,DTE_ES ; Setup VCPI device stack

; Read the master and slave IRQ bases

	VCPICALL @VCPI_GIBV	; Return with BX = master base
				; ...	      CX = slave base
	mov	GXTINI.MD_IBV0,bl ; Save for later use
	mov	GXTINI.MD_IBV1,cl ; ...

	REGSAVE <es>		; Save for a moment

; Get current INT 67h holder

	mov	al,67h		; Interrupt #
	DOSCALL @GETINT 	; Return with ES:BX ==> handler
	assume	es:nothing	; Tell the assembler about it

	mov	OLDINT67_VEC.VOFF,bx ; Save for later use
	mov	OLDINT67_VEC.VSEG,es ; ...

	REGREST <es>		; Restore
	assume	es:nothing	; Tell the assembler about it
CHECK_VCPI_CLC:
	clc			; Mark as successful

	jmp	short CHECK_VCPI_EXIT ; Join common exit code


CHECK_VCPI_ERR:
	mov	DRV_ERRMSG,offset NGROUP:MSG_NOVCPI ; Tell 'em the bad news

	stc			; Mark as in error
CHECK_VCPI_EXIT:
	popad			; Restore all GP registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_VCPI endp 		; End CHECK_VCPI procedure
	NPPROC	INIT_VCPI -- Initialize VCPI Data
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Initialize VCPI data

The low memory is organized as follows:

* SegCR3 is on a 4KB boundary and contains PDIR entries for 4KB.  The
  initial entries are of SegPTE and as many following 4KB PDIRs as
  needed.

* SegPTE follows SegCR3 (and thus is also on a 4KB boundary).  It is
  filled in with as many PTEs as the VCPI host requires.  This is
  immediately followed by as many PTEs as GXT requires (based on
  GXT_TSIZ).  At OffCR3 we save the physical address of the extended
  memory CR3 (SegCR3 is temporary).  At OffPDIR and following are the
  physical addresses of as many PDIRs needed to cover all of the
  needed linear addresses (typically, this is a single PDIR but it can
  be more in case GXT plus the VCPI host's PTEs overflow into the
  next 4MB).

  By putting the new CR3 and PDIRs into the PTE we can address them
  via the linear address which corresponds to OffCR3 and OffPDIR.

  Note that when we copy the PTEs to extended memory, we also copy the
  PTE which corresponds to CR3.  This way, GXT can find it when doing
  a LIN2LIN.

|

	pushad			; Save all EGP registers
	REGSAVE <es>		; Save register

	test	DEV_FLAG,@DEV_VCPI ; Are we using VCPI services?
	SETMSG	DRV,"No VCPI services available."
	lea	dx,MSG_DEVGXT	; Assume we're loading as device GXT
	jz	near ptr INIT_VCPI_CLC ; Jump if not

	mov	GXTINI.MD_IPROT.FSEL,DTE_LOAD ; Save for protected mode init
	mov	GXTINI.MD_RPROT.FSEL,DTE_LOAD ; ...			 restore

; Setup for VCPI calls

	mov	ax,MAPSEG_NXT	; Get next available segment
	add	ax,(4*1024/16-1) ; Round up to 4KB boundary
	and	ax,not (4*1024/16-1) ; ...
	mov	SegCR3,ax	; Save as segment of CR3 (/4KB)
	add	ax,4*1024/16	; Skip over CR3
	mov	SegPTE,ax	; Save as segment of PTEs (/4KB)
	mov	MAPSEG_NXT,ax	; Protect the CR3

	push	offset NGROUP:MEMERR_SEGPTE ; Pass offset of error message
	call	CHECK_NXTSEG	; Ensure we've enough room

; Allocate space for our code/data

	test	DEV_FLAG,@DEV_XMS ; Is there an XMS driver present?
	SETMSG	DRV,"No XMS services available."
	jz	near ptr INIT_VCPI_ERR ; Jump if not

;;;;;;; mov	edx,GXT_TSIZ	; Get total size of PM-resident GXT
;;;;;;; call	ALLOC_XMS	; Allocate EDX bytes of XMS memory
;;;;;;; 			; returning EAX = base physical address
;;;;;;; 			;	    CX = handle
;;;;;;; jc	near ptr INIT_VCPI_ERR ; Jump if something went wrong
;;;;;;;
;;;;;;; mov	MMPaXMS,eax	; Save in case we're INTRUDEing into a MM
;;;;;;;
;;;;;;; push	seg DGROUP	; Get segment of XMSHNDL2
;;;;;;; pop	es		; Address it
;;;;;;; assume	es:DGROUP	; Tell the assembler about it
;;;;;;;
;;;;;;; mov	XMSHNDL2,cx	; Save for later use
;;;;;;;
; Setup PMI

	mov	es,SegPTE	; Get segment of PTEs (/4KB)
	assume	es:nothing	; Tell the assembler about it

	xor	di,di		; ES:DI ==> PTEs

	push	ds		; Save for a moment

	lds	si,PGXTGDT	; DS:SI ==> GXT's GDT
	assume	ds:RGROUP	; Tell the assembler about it

	add	si,DTE_VCPI	; DS:SI ==> three DTEs for PMI
	VCPICALL @VCPI_GPMI	; Return with EBX=offset, DI=advanced

	pop	ds		; Restore
	assume	ds:NGROUP	; Tell the assembler about it

	cmp	ah,0		; Check for error
	SETMSG	DRV,"Unable to read VCPI Protected Mode Interface data."
	jne	near ptr INIT_VCPI_ERR ; Jump if not OK

	mov	PMI_FVEC.FOFF,ebx ; Save offset of PMI
	mov	PMI_FVEC.FSEL,DTE_VCPI ; Save selector of PMI

	movzx	edi,di		; Zero to use as dword

; In case the VCPI host doesn't include the HMA, we include it here
; For some reason, EMM386 fills in 0410h bytes (1MB + 16KB) and the
; 4 PTEs at 1MB are not one-to-one.  Moreover, those PTEs do not
; reflect the mapping it uses when DOS is in effect.  The workaround
; here is to blast in one-to-one PTEs.	Damn the torpedoes!

	cmp	edi,((1024+64)*1024) shr (12-2) ; Izit at or above 1.1MB?
	jae	short INIT_VCPI_HMAOK ; Jump if so

	mov	ecx,64/4	; Get # PTEs to blast in
	mov	edi,(1024*1024) shr (12-2) ; Get offset of 1MB

	mov	eax,edi 	; Copy starting offset
	shl	eax,(12-2)-0	; Convert from 4KB in dwords to bytes
	or	eax,@PTE_URP	; Mark as User/Read-Write/Present
@@:
S32	stos	es:[edi].EDD	; Save as address of next PTE
	add	eax,4*1024	; Skip to next PTE

	LOOPD	@B		; Jump if more PDIRs to fill in
INIT_VCPI_HMAOK:
;;;
;;; ; If we're INTRUDEing, reserve space for the MM's GDT and IDT
;;;
;;;	    test    DEV_FLAG,@DEV_INTRUDE ; Are we INTRUDEing today?
;;;	    jz	    near ptr INIT_VCPI_XINTRUDE ; Jump if not
;;;
;;;	    push    es		    ; Save for a moment
;;;
;;;	    mov     ax,seg DGROUP   ; Get segment of RUD_xDTR variables
;;;	    mov     es,ax	    ; Address it
;;;	    assume  es:DGROUP	    ; Tell the assembler about it
;;;
;;;	    SGDTD   RUD_GDTR	    ; Save old GDTR for when we INTRUDE
;;;	    SIDTD   RUD_IDTR	    ; ...      IDTR ...
;;;
;;;	    shl     edi,(12-2)-0    ; Convert from 4KB in dwords to bytes
;;;
;;;	    movzx   eax,RUD_GDTR.DTR_LIM ; Get the GDT limit
;;;	    inc     eax 	    ; Convert from limit to length
;;;	    and     eax,not ((size DESC_STR)-1) ; Round down to DTE boundary
;;;				    ; in case someone uses a length instead
;;;				    ; of a limit
;;;	    mov     ebx,RUD_GDTR.DTR_BASE ; Get the base address
;;;	    and     ebx,not @PTE_FRM ; Isolate the offset
;;;	    add     eax,ebx	    ; Add to get ending address
;;;	    add     eax,4*1024-1    ; Round up to 4KB boundary
;;;	    and     eax,not (4*1024-1) ; ...
;;;	    mov     RUDLaGDT,edi    ; Save as offset of GDT in our linear address space
;;;	    add     RUDLaGDT,ebx    ; Plus the offset in the 4KB page
;;;	    add     edi,eax	    ; Skip over the GDT
;;;	    shr     eax,12-0	    ; Convert from bytes to 4KB (# PTEs)
;;;	    mov     RUDGDTCNT,ax    ; Save for later use
;;;
;;;	    movzx   eax,RUD_IDTR.DTR_LIM ; Get the IDT limit
;;;	    inc     eax 	    ; Convert from limit to length
;;;	    and     eax,not ((size IDT_STR)-1) ; Round down to IDT boundary
;;;				    ; in case someone uses a length instead
;;;				    ; of a limit
;;;	    mov     ebx,RUD_IDTR.DTR_BASE ; Get the base address
;;;	    and     ebx,not @PTE_FRM ; Isolate the offset
;;;	    add     eax,ebx	    ; Add to get ending address
;;;	    add     eax,4*1024-1    ; Round up to 4KB boundary
;;;	    and     eax,not (4*1024-1) ; ...
;;;	    mov     RUDLaIDT,edi    ; Save as offset of IDT in our linear address space
;;;	    add     RUDLaIDT,ebx    ; Plus the offset in the 4KB page
;;;	    add     edi,eax	    ; Skip over the IDT
;;;	    shr     eax,12-0	    ; Convert from bytes to 4KB (# PTEs)
;;;	    mov     RUDIDTCNT,ax    ; Save for later use
;;;
;;;	    shr     edi,(12-2)-0    ; Convert from bytes to 4KB in dwords
;;;
;;;	    pop     es		    ; Restore
;;;	    assume  es:nothing	    ; Tell the assembler about it
;;; INIT_VCPI_XINTRUDE:

; If there's a preceding SWAT, reserve space for it

	test	DEVLOAD,@DEVL_PSWAT ; Izit present?
	jz	short @F	; Jump if not

	mov	edx,-1		; Skip new linear address
	mov	ebx,-1		; Use the current CR3
	XVCPICALL @VCPI_DBGLIN	; Request SWAT services
				; Return with EDX = current linear address
	mov	LaPSWAT,edx	; Save as new linear address (/4KB)
;;;;;;; shl	edi,(12-2)-0	; Convert from 4KB in dwords to bytes
;;;;;;; mov	LaPSWAT,edi	; Save as new linear address (/4KB)
;;;;;;; add	edi,PSWAT_TSIZ	; Skip over it
;;;;;;; shr	edi,(12-2)-0	; Convert from bytes to 4KB in dwords
@@:
	mov	NEXTPTE,edi	; Save offset of next available PTE

	mov	eax,edi 	; Copy offset in 4KB in dwords
	shl	eax,(12-2)-0	; Convert from 4KB in dwords to bytes

; Next in the extended memory linear address space is the IDT,
; device GXT's stack (after entering PM but before calling GXT),
; and the TSS (for VCPI GXT).

	mov	LaIDT,eax	; Save as linear address of IDT

	add	eax,256*(type IDT_STR) ; Skip over the IDT
	mov	LaSTK,eax	; Save as linear address of stack

	add	eax,GXTSTK_FVEC.FOFF ; Skip over the stack
	mov	LaTSS,eax	; Save as linear address of TSS

	add	eax,size TSS_STR ; Skip over TSS

; Make room for the SIRB table whether or not VME is supported,

	add	eax,256/8	; Plus size of SIRB table
	add	eax,8*1024+1	; Skip over I/O bit permission map
	mov	ebx,eax 	; Copy current offset
	sub	ebx,LaTSS	; Less start to get length in bytes
	mov	TSS_LEN,ebx	; Save for later use

; Make room for the global PL0 stack

	push	seg DGROUP	; Get segment of LaPL0STK/PL0STK_SIZ
	pop	es		; Address it
	assume	es:DGROUP	; Tell the assembler about it

	add	eax,4-1 	; Round up to dword
	and	eax,not (4-1)	; ...boundary
	mov	LaPL0STK,eax	; Save as linear address of PL0 stack
	add	eax,PL0STK_SIZ	; Skip over the PL0 stack

	add	eax,4*1024-1	; Round up to 4KB boundary
	and	eax,not (4*1024-1) ; ...

; Next in the extended memory linear address space is our code/data

;;;;;;; mov	ebx,MMPaXMS	; Get our physical address
;;;;;;; and	ebx,4*1024-1	; Isolate offset within 4KB page
;;;;;;; add	eax,ebx 	; Add into current address
;;;;;;;
	mov	LaCODE,eax	; Save as linear address of our code

;;;;;;; mov	eax,LaCODE	; Get linear address of our code
	add	eax,GXT_DAT	; Plus offset to data segment
	mov	LaDATA,eax	; Save as linear address of our data

	mov	eax,LaCODE	; Get linear address of our code
	add	eax,GXT_TSIZ	; Plus total size of PM-resident GXT
	mov	LaEND,eax	; Save as ending linear address

; Make room for the Page Directory followed by PTEs sufficient
; for room for the IDT, stack, TSS, and our code/data

;;;;;;; mov	eax,LaEND	; Get ending linear address
	add	eax,4*1024-1	; Round up to 4KB boundary
	and	eax,not (4*1024-1) ; ...
	shr	eax,(12-2)-0	; Convert from bytes to 4KB in dwords
	sub	eax,NEXTPTE	; Less # PTEs already saved

	shr	eax,12-(12-2)	; Convert from 4KB in dwords to 4KB (# PTEs)
	mov	NDRVPTE,eax	; Save for later use

; Make room for enough PTEs for the load modules

	push	seg DGROUP	; Get segment of LOADTAB
	pop	es		; Address it
	assume	es:DGROUP	; Tell the assembler about it

	mov	esi,LaEND	; Get ending linear address
	add	esi,4*1024-1	; Round up to 4KB boundary
	and	esi,not (4*1024-1) ; ...

	mov	edi,LOADTABLST	; Get last index

	mov	ecx,LOADCOUNT	; ECX = # load modules
	jecxz	INIT_VCPI_XLOAD1 ; Jump if none
INIT_VCPI_LOADNEXT1:
	mov	edx,LOADTAB[edi].LOAD_MMLIN ; Get the linear address (/1KB)
	and	edx,4*1024-1	; Isolate the 4KB offset
	add	edx,esi 	; Plus linear address start
	mov	LOADTAB[edi].LOAD_MMLIN,edx ; Save as new linear address
	call	SET_LOAD_DTE	; Set the load module DTEs at LOADTAB[edi]

	mov	edx,LOADTAB[edi].LOAD_PHYS ; Get the physical address (/1KB)
	mov	ebx,edx 	; Copy for later use
	add	edx,LOADTAB[edi].LOAD_CLEN ; Plus length of code
	add	edx,LOADTAB[edi].LOAD_DLEN ; ...	    data
	add	edx,4*1024-1	; Round up to 4KB boundary
	and	edx,not (4*1024-1) ; ...
	mov	esi,edx 	; Copy as next module's start address
	and	ebx,not (4*1024-1) ; Round down to 4KB boundary
	sub	edx,ebx 	; Subtract to get length in bytes (/4KB)
	shr	edx,12-0	; Convert from bytes to 4KB (#PTEs)
	add	eax,edx 	; Skip over these PTEs
	add	NLODPTE,edx	; Count in these PTEs

	sub	edi,type LOAD_STR ; Skip to next entry

	loop	INIT_VCPI_LOADNEXT1 ; Jump if more load modules
INIT_VCPI_XLOAD1:
	shl	eax,12-(12-2)	; Convert from 4KB to 4KB in dwords
	add	eax,NEXTPTE	; Skip over existing PTEs

@NDRVPDIR equ	4		; Maximum # temporary PDIRs we support

	mov	OffCR3,eax	; Save for later use
	add	eax,4		; Skip over it
	mov	OffPDIR,eax	; Save for later use
	add	eax,4*@NDRVPDIR ; Skip over temp @NDRVPDIR PDIRs
				; Note that @NDRVPDIR must be <= NRDVPDIR
				; In other words, the VCPI host plus GXT
				; cannot exceed 4MB * @NDRVPDIR.

; This is the next available offset in bytes after all PTEs

	mov	ecx,eax 	; Copy as maximum size of PTEs
	add	eax,16-1	; Round up to next para
	shr	eax,4-0 	; Convert from bytes to paras
	add	MAPSEG_NXT,ax	; Protect the PTEs

	push	offset NGROUP:MEMERR_ALLPTE ; Pass offset of error message
	call	CHECK_NXTSEG	; Ensure we've enough room

; Calculate the # PDIRs

	add	ecx,4*1024-1	; Round up to 4KB boundary
	shr	ecx,12-0	; Convert from bytes to 4KB (# PDIRs)
	mov	NDRVPDIR,ecx	; Save for later use

; Zero the temp PDIR PTEs

	mov	es,SegPTE	; Get segment of PTEs (/4KB)
	assume	es:nothing	; Tell the assembler about it

	mov	edi,OffPDIR	; Get offset of temp PDIRs
	mov	ecx,@NDRVPDIR	; Get # PDIRs reserved
	xor	eax,eax 	; A convenient zero
    rep stos	es:[edi].EDD	; Zero the temp PDIRs

; Initialize the PDIR with zeros

	mov	es,SegCR3	; Get segment of CR3 (/4KB)
	assume	es:nothing	; Tell the assembler about it

	xor	edi,edi 	; ES:EDI ==> PDEs

	mov	ecx,4*1024/4	; Get maximum # PDEs
	xor	eax,eax 	; Set 'em all to zero
    rep stos	es:[edi].EDD	; Save as next PDE

; Fill in the PDIRs

	movzx	eax,SegPTE	; Get segment of PTEs (/4KB)
	shl	eax,4-0 	; Convert from paras to bytes
	xor	edi,edi 	; ES:EDI ==> PTEs
	mov	ecx,NDRVPDIR	; Get # PDIRs for GXT
	or	eax,@PTE_URP	; Mark as User/Read-Write/Present
@@:
S32	stos	es:[edi].EDD	; Save as address of next PDIR
	add	eax,4*1024	; Skip to next PTE

	LOOPD	@B		; Jump if more PDIRs to fill in

; Setup the GDT

	call	INIT_GDT	; Initialize it

; Setup TSS descriptor to point to low memory as we haven't copied
; our code/data to extended memory as yet.

	movzx	ebx,MAPSEG_NXT	; Get next available segment
	mov	SegTSS,bx	; Save for later use
	mov	es,bx		; Address it
	assume	es:nothing	; Tell the assembler about it

	mov	eax,TSS_LEN	; Get size of TSS data in bytes
	add	eax,16-1	; Round up to
;;;;;;; and	eax,not (16-1)	; ...para boundary
	shr	eax,4-0 	; Convert from bytes to paras
	add	MAPSEG_NXT,ax	; Protect the TSS

	push	offset NGROUP:MEMERR_TSS ; Pass offset of error message
	call	CHECK_NXTSEG	; Ensure we've enough room

; Zero the temporary TSS

	xor	edi,edi 	; ES:EDI ==> temporary TSS
	xor	eax,eax 	; A convenient zero
	mov	ecx,TSS_LEN	; Get # bytes in TSS
    rep stos	es:[edi].LO	; Zero it

	shl	ebx,4-0 	; Convert from paras to bytes

	push	TSS_LEN 	; Get length of TSS data
	push	ebx		; Get base address
	push	DTE_TSS 	; Get DTE
	push	CPL0_IDLE3	; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

; Fill in the Enter PM structure in preparation for entering PM via VCPI
; Note that these values are temporary solely for the purpose of
; allocating memory for GXT and its tables.

	push	fs		; Save for a moment

	push	seg DGROUP	; Get segment of PSWAT_FVEC
	pop	fs		; Address it
	assume	fs:DGROUP	; Tell the assembler about it

	mov	VCPEPM.VCPEPM_TR,DTE_TSS ; Save TR
	movzx	eax,SegCR3	; Get segment of CR3 (/4KB)
	shl	eax,4-0 	; Convert from paras to bytes
	mov	VCPEPM.VCPEPM_CR3,eax ; Save in VCPI EPM struc
	mov	es:[0].TSS_CR3,eax ; Save in TSS
;;;;;;; mov	es:[0].TSS_SS0,DTE_SS ; ...
;;;;;;; mov	es:[0].TSS_ESP0,offset NGROUP:RUDSTKZ ; ...
	mov	es:[0].TSS_SS0,DTE_PL0STK ; Save in TSS
	mov	eax,PL0STK_SIZ	; Get PL0 stack size
	mov	es:[0].TSS_ESP0,eax ; Save in TSS
	mov	es:[0].TSS_IOMAP,(size TSS_STR) + 256/8 ; ...

	pop	fs		; Restore
	assume	fs:PGROUP	; Tell the assembler about it

	movzx	eax,PGXTGDT.VSEG ; Get GXT GDT's segment
	shl	eax,4-0 	; Convert from paras to bytes
	movzx	ebx,PGXTGDT.VOFF ; Get GXT GDT's offset
	add	eax,ebx 	; Add to get 32-bit linear address
	add	eax,DTE_GDT	; Skip to GDT entry
	mov	VCPEPM.VCPEPM_GDTP,eax ; Save in VCPI EPM struc
	add	eax,DTE_IDT-DTE_GDT ; Skip to IDT entry
	mov	VCPEPM.VCPEPM_IDTP,eax ; Save in VCPI EPM struc

; If there's a preceding SWAT, tell it about the new CR3

	test	DEVLOAD,@DEVL_PSWAT ; Izit present?
	jz	near ptr INIT_VCPI_XPSWAT1 ; Jump if not

	mov	edx,LaPSWAT	; Get new linear address (/4KB)
	mov	ebx,VCPEPM.VCPEPM_CR3 ; Get the new CR3
	XVCPICALL @VCPI_DBGLIN	; Request SWAT services

	movzx	eax,SegPTE	; Get segment of PTEs (/4KB)
	shl	eax,4-0 	; Convert from paras to bytes

	push	eax		; Pass LA of PTEs
	call	INIT_PSWAT_PTE	; Initialize preceding SWAT's PTEs

; Because we changed the linear address, we need to re-initialize
; the preceding SWAT in our PM GDT.

	push	es		; Save for a moment

	les	di,PGXTGDT	; ES:DI ==> GXT's GDT
	assume	es:RGROUP	; Tell the assembler about it

	mov	bx,DTE_PSWAT	; Get its code selector
	add	di,bx		; ES:DI ==> GDT entries for preceding device SWAT

	XVCPICALL @VCPI_DBGINI2 ; Initialize debugger interface with
				; with BX = code selector
				; and ES:DI ==> GDT entries to fill in
				; Return with BX:EDX ==> PM entry point
;;;;;;;
;;;;;;; cmp	ah,0		; Did it succeed?
;;;;;;; jne	short ???	; Jump if not

	cmp	PSWAT_VER,(5 shl 8) or 30 ; Izit version 5.30 or later?
	jb	short @F	; Jump if not

	push	seg DGROUP	; Get segment of PSWAT_FVEC
	pop	es		; Address it
	assume	es:DGROUP	; Tell the assembler about it

	mov	PSWAT_FVEC.FSEL,bx ; Save for later use
	mov	PSWAT_FVEC.FOFF,edx ; ...
	mov	PSWAT2_FVEC.FOFF,edx ; ...
@@:
	mov	es,SegIDT	; Get the segment of the temporary IDT
	assume	es:nothing	; Tell the assembler about it

%	irp	XX,<@PSWATINTS>
	mov	bx,0&XX&h	; Interrupt #
	mov	di,0&XX&h*(type IDT_STR) ; ES:DI ==> this IDT entry
	XVCPICALL @VCPI_DBGIDT	; Initialize debugger IDT entry
				; Ignore error return
	endm			; IRP XX,<@PSWATINTS>

	pop	es		; Restore
	assume	es:nothing	; Tell the assembler about it
INIT_VCPI_XPSWAT1:

; Setup dummy IDT

	movzx	eax,SegIDT	; Get segment of the temporary IDT
	shl	eax,4-0 	; Convert from paras to bytes
	mov	GXTIDTR.DTR_BASE,eax ; Save for later use
	mov	GXTIDTR.DTR_LIM,(type IDT_STR)*256-1 ; ...

; If there's an XMS driver present with enough memory,
; allocate memory that way.

	test	DEV_FLAG,@DEV_XMS ; Is there an XMS driver present?
	jz	near ptr INIT_VCPI_NOXMS ; Jump if not

; Calculate how many 4KB pages we need to allocate

	mov	edx,1		; One for CR3
	add	edx,NDRVPDIR	; Plus PDIRs
	add	edx,NDRVPTE	; Plus PTEs
	shl	edx,12-0	; Convert from 4KB to bytes
	add	edx,4*1024-1	; Add in extra page-1 in case the
				; address we get back isn't on 4KB boundary
	call	ALLOC_XMS	; Allocate EDX bytes of XMS memory
				; returning EAX = base physical address
				;	    CX = handle
	jc	near ptr INIT_VCPI_ERR ; Jump if something went wrong

	test	DEV_FLAG,@DEV_XMS ; Did we fail trying XMS?
	jz	near ptr INIT_VCPI_NOXMS ; Jump if so (try VCPI alone)

	push	seg DGROUP	; Get segment of XMSHNDL2
	pop	es		; Address it
	assume	es:DGROUP	; Tell the assembler about it

	mov	XMSHNDL2,cx	; Save for later use

	add	eax,4*1024-1	; Round up to 4KB boundary
	and	eax,not (4*1024-1) ; ...

	mov	es,SegPTE	; Get segment of PTEs (/4KB)
	assume	es:nothing	; Tell the assembler about it

	or	eax,@PTE_URP	; Mark as User/Read-Write/Present

; The first NDRVPTEs are used for PTEs for IDT, Stack, TSS, code/data

	mov	edi,NEXTPTE	; ES:EDI ==> next available PTE
	mov	ecx,NDRVPTE	; Get # PTEs needed
@@:
S32	stos	es:[edi].EDD	; Save as PTE
	add	eax,4*1024	; Skip to next 4KB page

	LOOPD	@B		; Jump if more PTEs

	REGSAVE <eax,fs>	; Save for a moment

; The next NLODPTE PTEs are for the load modules

	push	seg DGROUP	; Get DGROUP data segment
	pop	fs		; Address it
	assume	fs:DGROUP	; Tell the assembler about it

	mov	esi,LOADTABLST	; Get last index
	mov	ecx,LOADCOUNT	; ECX = # load modules
	jecxz	INIT_VCPI_XLOAD2 ; Jump if none
INIT_VCPI_LOADNEXT2:
	push	ecx		; Save for a moment

	mov	eax,LOADTAB[esi].LOAD_PHYS ; Get the physical address (/1KB)
	mov	ecx,eax 	; Copy address
	add	ecx,LOADTAB[esi].LOAD_CLEN ; Plus length of code
	add	ecx,LOADTAB[esi].LOAD_DLEN ; ...	    data
	add	ecx,4*1024-1	; Round up to 4KB boundary
	and	ecx,not (4*1024-1) ; ...
	and	eax,not (4*1024-1) ; Round down to 4KB boundary
	sub	ecx,eax 	; Subtract to get length in bytes (/4KB)
	shr	ecx,12-0	; Convert from bytes to 4KB (#PTEs)

	or	eax,@PTE_URP	; Mark as User/Read-Write/Present
@@:
S32	stos	es:[edi].EDD	; Save as PTE
	add	eax,4*1024	; Skip to next 4KB page

	LOOPD	@B		; Jump if more PTEs

	pop	ecx		; Restore

	sub	esi,type LOAD_STR ; Skip to next entry

	LOOPD	INIT_VCPI_LOADNEXT2 ; Jump if more load modules
INIT_VCPI_XLOAD2:
	REGREST <fs,eax>	; Restore
	assume	fs:PGROUP	; Tell the assembler about it

; The next 4KB page (at OffCR3) is used for CR3

	mov	edi,OffCR3	; Get offset of CR3 temp PTE
S32	stos	es:[edi].EDD	; Save as PTE
	add	eax,4*1024	; Skip to next 4KB page

; The next NDRVPDIRs (at OffPDIR) are used for PDIRs

	mov	ecx,NDRVPDIR	; Get # PDIRs
;;;;;;; mov	edi,OffPDIR	; Get offset of temp PDIRs
@@:
S32	stos	es:[edi].EDD	; Save as PTE
	add	eax,4*1024	; Skip to next 4KB page

	LOOPD	@B		; Jump if more PDIRs
;;;
;;; ; The next PTEs are used for code/data
;;;
;;;	    mov     edi,LaCODE	    ; Get linear address of code
;;;	    mov     ecx,GXT_TSIZ    ; Get total size of PM-resident GXT
;;;	    add     ecx,edi	    ; Add to get ending address
;;;	    and     edi,not (4*1024-1) ; Round down to 4KB boundary
;;;	    sub     ecx,edi	    ; Subtract to get length in bytes
;;;	    add     ecx,4*1024-1    ; Round up to 4KB boundary
;;;	    shr     ecx,12-0	    ; Convert from bytes to 4KB (# PTEs)
;;;	    shr     edi,(12-2)-0    ; Convert from bytes to 4KB in dwords
;;;
;;;	    mov     eax,MMPaXMS     ; Get physical address
;;;	    and     eax,@PTE_FRM    ; Isolate the 4KB page
;;;	    or	    eax,@PTE_URP    ; Mark as User/Read-Write/Present
;;; @@:
;;; S32     stos    es:[edi].EDD    ; Save as PTE
;;;	    add     eax,4*1024	    ; Skip to next 4KB page
;;;
;;;	    LOOPD   @B		    ; Jump if more PTEs
INIT_VCPI_NOXMS:

; If the MM is 386MAX, read the first PDE in MAX's Page Directory
; because MAX hides this information from the VCPI client.

	test	DEV_FLAG,@DEV_MAX ; Izit present?
	jz	short @F	; Jump if not

	call	INIT_MAX	; Initialize for 386MAX
@@:

; Enter PM via VCPI, allocate all needed memory, fill in the
; PDIR and PTE entries, and copy code and data to extended memory.

	mov	VCPEPM.VCPEPM_EXIT.FSEL,DTE_CS ; Save initial CS
	mov	VCPEPM.VCPEPM_EXIT.FOFF,offset cs:INIT_VCPI_PMINI1 ; ... EIP

	movzx	esi,PVCPEPM.VSEG ; Get segment of VCPEPM
	movzx	eax,PVCPEPM.VOFF ; ... offset ...
	shl	esi,4-0 	; Convert from paras to bytes
	add	esi,eax 	; Add to get 32-bit linear address
	mov	LaVCPEPM,esi	; Save for later use

; Put return VM registers onto the stack

	mov	eax,esp 	; Get current ESP

	PUSHD	gs		; Place GS onto stack
	PUSHD	fs		; ...	FS ...
	PUSHD	ds		; ...	DS ...
	PUSHD	es		; ...	ES ...
	PUSHD	ss		; ...	SS ...
	push	eax		; ...	ESP ...
	pushfd			; ...	EFL ...
	PUSHD	cs		; ...	CS ...
	lea	eax,INIT_VCPI_VMRET1 ; Get return EIP
	push	eax		; ...	EIP ...

	mov	PMSTK_FVEC.FSEL,DTE_SS ; Setup stack for later use
	mov	PMSTK_FVEC.FOFF,esp ; ...

	cli			; Enter with IF=0

;;;;;;; mov	esi,LaVCPEPM	; ESI = VCPEPM
	VCPICALL @VCPI_EPM	; Enter PM using ESI = EPM struc
INIT_VCPI_PMINI1:
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

	cli			; Some VCPI hosts (RM386 comes to mind)
				; start us off with IF=1
	lss	esp,PMSTK_FVEC	; Setup our stack
	assume	ss:nothing	; Tell the assembler about it

	xor	ax,ax		; A convenient zero
	mov	ds,ax		; Clear to avoid fault
	assume	ds:nothing	; Tell the assembler about it
	mov	es,ax		; Clear to avoid fault
	assume	es:nothing	; Tell the assembler about it
	mov	fs,ax		; Clear to avoid fault
	assume	fs:nothing	; Tell the assembler about it
	mov	gs,ax		; ...
	assume	gs:nothing	; Tell the assembler about it

	mov	ax,DTE_4GB	; Get AGROUP data selector
	mov	es,ax		; Address it
	assume	es:AGROUP	; Tell the assembler about it

	mov	ax,DTE_ES	; Get RGROUP data selector
	mov	fs,ax		; Address it
	assume	fs:RGROUP	; Tell the assembler about it

; If we've been asked to, attempt to intrude into the memory manager's
; PL0 context.

;;;;;;; call	INTRUDE 	; Whether they like it or not
;;;;;;; jnc	near ptr INIT_VCPI_INTRUDE1 ; Jump if we succeeded
;;;;;;;
; Allocate a 4KB page for the permanent CR3

	movzx	ebx,SegPTE	; Get segment of PTEs (/4KB)
	shl	ebx,4-0 	; Convert from paras to bytes
	add	ebx,OffCR3	; Plus offset of CR3 temp PTE

	test	DEV_FLAG,@DEV_XMS ; Is there an XMS driver present?
	jnz	short INIT_VCPI_XMS1 ; Jump if so (already allocated and in EDX)

	mov	edx,AGROUP:[ebx] ; Get PDIR at OffCR3 if using XMS

	mov	ax,(@VCPI shl 8) or @VCPI_ALLOC ; Allocate 4KB for CR3
	call	PMI_FVEC	; Request VCPI service

	cmp	ah,0		; Did it work?
	jne	near ptr INIT_VCPI_PMERR ; Jump if not

	or	edx,@PTE_URP	; Mark as User/Read-Write/Present
	mov	AGROUP:[ebx],edx ; Save as PDIR at OffCR3

; Flush CR3

	mov	eax,VCPEPM.VCPEPM_CR3 ; Get current value
	mov	cr3,eax 	; Flush it
INIT_VCPI_XMS1:

; Zero the new CR3 page

	mov	edi,OffCR3	; Get offset of CR3 temp PTE
	shl	edi,(12-2)-0	; Convert from 4KB in dwords to bytes
	xor	eax,eax 	; A convenient zero
	mov	ecx,4*1024/4	; # dwords in a 4KB page
    rep stos	AGROUP:[edi].EDD ; Zero the PDIR

; Allocate a 4KB page for each PDIR

	movzx	ebx,SegPTE	; Get segment of PTEs (/4KB)
	shl	ebx,4-0 	; Convert from paras to bytes
	add	ebx,OffPDIR	; Plus offset of temp PDIRs

	mov	edi,OffCR3	; Get offset of CR3 temp PTE
	shl	edi,(12-2)-0	; Convert from 4KB in dwords to bytes
	mov	ecx,NDRVPDIR	; Get # PDIRs
INIT_VCPI_NEXTPDIR:
	mov	edx,AGROUP:[ebx] ; Get PTE if using XMS

	test	DEV_FLAG,@DEV_XMS ; Is there an XMS driver present?
	jnz	short @F	; Jump if so (allready allocated and in EDX)

	mov	ax,(@VCPI shl 8) or @VCPI_ALLOC ; Allocate 4KB for next PDIR
	call	PMI_FVEC	; Request VCPI service

	cmp	ah,0		; Did it work?
	jne	near ptr INIT_VCPI_PMERR ; Jump if not
@@:
	mov	eax,edx 	; Copy to output register
	and	eax,@PTE_FRM	; Isolate the 4KB frame
	or	eax,@PTE_URP	; Mark as User/Read-Write/Present
S32	stos	AGROUP:[edi].EDD ; Save as next PDE

	mov	AGROUP:[ebx],eax ; Save as PTE
	add	ebx,4		; Skip over last PTE

	LOOPD	INIT_VCPI_NEXTPDIR ; Jump if more PDIRs to fill in

; Allocate 4KB pages for each PTE and save the physical addresses
; into the PDIRs

	movzx	edi,SegPTE	; Get segment of PTEs (/4KB)
	shl	edi,4-0 	; Convert from paras to bytes
	add	edi,NEXTPTE	; ES:EDI ==> next available PTE

	mov	ecx,NDRVPTE	; Get # PTEs needed

	test	DEV_FLAG,@DEV_XMS ; Is there an XMS driver present?
	jnz	short INIT_VCPI_FLUSH ; Jump if so (already allocated
				; and in SegPTE following NEXTPTE)
INIT_VCPI_NEXTPTE:
	mov	ax,(@VCPI shl 8) or @VCPI_ALLOC ; Allocate 4KB for next PTE
	call	PMI_FVEC	; Request VCPI service

	cmp	ah,0		; Did it work?
	jne	near ptr INIT_VCPI_PMERR ; Jump if not

	mov	eax,edx 	; Copy to output register
	and	eax,@PTE_FRM	; Isolate the 4KB frame
	or	eax,@PTE_URP	; Mark as User/Read-Write/Present
S32	stos	AGROUP:[edi].EDD ; Save as next PDE

	LOOPD	INIT_VCPI_NEXTPTE ; Jump if more PTEs to fill in
INIT_VCPI_FLUSH:

; Flush CR3

	mov	eax,VCPEPM.VCPEPM_CR3 ; Get current value
	mov	cr3,eax 	; Flush it

; Copy the temporary PTEs to their permanent home
; At this point, because we put the physical address of the
; new PDIRs as PTEs at OffPDIR and following, we can copy
; all of the PTEs to their final resting place using the
; linear address corresponding to OffPDIR.

	movzx	esi,SegPTE	; Get segment of PTEs (/4KB)
	shl	esi,4-0 	; Convert from paras to bytes

	mov	edi,OffPDIR	; Get offset of temp PDIRs
	shl	edi,(12-2)-0	; Convert from 4KB in dwords to bytes

	mov	ecx,NEXTPTE	; Get offset of next PTE
	shr	ecx,12-(12-2)	; Convert from 4KB in dwords to 4KB (# PTEs)
	add	ecx,NDRVPTE	; Plus # GXT PTEs to copy
	add	ecx,NLODPTE	; Plus # LOD PTEs to copy
	inc	ecx		; Plus the CR3 temp PTE
	add	ecx,@NDRVPDIR	; Plus maximum # temp PDIRs
S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy old to new PTEs

; Copy GXT to extended memory

	xor	esi,esi 	; Zero to use as dword
	mov	si,seg PGROUP	; Get start of GXT
	shl	esi,4-0 	; Convert from paras to bytes

	mov	edi,LaCODE	; Get linear address of code/data

	mov	ecx,GXT_ISIZ	; Get size of initialized code/data
	shr	ecx,2-0 	; Convert from bytes to dwords
S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy GXT to extended mem

; Copy the dummy TSS to extended memory

	movzx	esi,SegTSS	; Get segment of TSS
	shl	esi,4-0 	; Convert from paras to bytes

	mov	edi,LaTSS	; Get linear address of TSS in extended memory
	mov	ecx,TSS_LEN	; Get length of TSS data in bytes
S32 rep movs	<AGROUP:[edi].LO,AGROUP:[esi].LO> ; Copy TSS to extended mem

; Save new CR3 into TSS in extended memory

	movzx	eax,SegPTE	; Get segment of PTEs (/4KB)
	shl	eax,4-0 	; Convert from paras to bytes
	add	eax,OffCR3	; Plus offset to CR3 temp PTE
	mov	eax,AGROUP:[eax] ; Get new CR3
	and	eax,@PTE_FRM	; Isolate the 4KB frame
	mov	ebx,LaTSS	; Get linear address of TSS in extended memory
	mov	AGROUP:[ebx].TSS_CR3,eax ; Save in TSS

; Copy the dummy IDT to extended memory

	mov	esi,GXTIDTR.DTR_BASE ; Get source IDT
	mov	edi,LaIDT	; Get destination IDT
	mov	ecx,(256*(type IDT_STR))/4 ; Get # dwords in IDT
S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy IDT to extended mem





;;; INIT_VCPI_INTRUDE1:
	mov	bx,DRV_ERRMSG	; Mark as no error

	jmp	short INIT_VCPI_PMRET ; Join common return code


INIT_VCPI_PMERR:
	lea	bx,MSG_NOVCPMEM ; Insufficient VCPI memory
INIT_VCPI_PMRET:
	mov	ax,DTE_4GB	; Get AGROUP data selector
	mov	ds,ax		; Address it
	assume	ds:AGROUP	; Tell the assembler about it

	cli			; Exit with IF=0

	mov	ax,(@VCPI shl 8) or @VCPI_EPM ; Get return function
	call	PMI_FVEC	; Request VCPI service
INIT_VCPI_VMRET1:
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing

	sti			; Allow interrupts

; Check for errors from PM

	mov	DRV_ERRMSG,bx	; Save error offset (if any)

	cmp	DRV_ERRMSG,-1	; Any errors?
	jne	near ptr INIT_VCPI_ERR ; Jump if so

	mov	dx,RUD_ERRMSG	; Get address of error message (if any)

	cmp	dx,-1		; Izit valid?
	je	short @F	; Jump if not

	push	dx		; Pass offset in NGROUP of error msg
	call	DISP_ERRMSG	; Tell 'em there's an error
@@:
;;;	    test    DEV_FLAG,@DEV_INTRUDE ; Are we INTRUDEing today?
;;;	    jnz     near ptr INIT_VCPI_INTRUDE2 ; Jump if so
;;;
; Setup TSS descriptor to point to extended memory

	push	TSS_LEN 	; Get length of TSS data
	push	LaTSS		; Get base address
	push	DTE_TSS 	; Get DTE
	push	CPL0_IDLE3	; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

; Save new CR3

	mov	es,SegPTE	; Get segment of PTEs (/4KB)
	assume	es:nothing	; Tell the assembler about it

	mov	eax,OffCR3	; Get offset of CR3 temp PTE
	mov	eax,es:[eax]	; Get new CR3
	and	eax,@PTE_FRM	; Isolate the 4KB frame
	mov	VCPEPM.VCPEPM_CR3,eax ; Save in VCPI EPM struc

; If there's a preceding SWAT, tell it about the new CR3

	test	DEVLOAD,@DEVL_PSWAT ; Izit present?
	jz	near ptr INIT_VCPI_XPSWAT2 ; Jump if not

	mov	edx,LaPSWAT	; Get new linear address (/4KB)
	mov	ebx,VCPEPM.VCPEPM_CR3 ; Get the new CR3
	XVCPICALL @VCPI_DBGLIN	; Request SWAT services

	mov	eax,OffPDIR	; Get offset of temp PDIRs
	mov	eax,es:[eax]	; Get the PTE
	and	eax,@PTE_FRM	; Isolate the 4KB frame

	push	eax		; Pass LA of PTEs (Lin = Phys)
	call	INIT_PSWAT_PTE	; Initialize preceding SWAT's PTEs

; Because we changed the linear address, we need to re-initialize
; the preceding SWAT in our PM GDT.

	push	es		; Save for a moment

	les	di,PGXTGDT	; ES:DI ==> GXT's GDT
	assume	es:RGROUP	; Tell the assembler about it

	mov	bx,DTE_PSWAT	; Get its code selector
	add	di,bx		; ES:DI ==> GDT entries for preceding device SWAT

	XVCPICALL @VCPI_DBGINI2 ; Initialize debugger interface with
				; with BX = code selector
				; and ES:DI ==> GDT entries to fill in
				; Return with BX:EDX ==> PM entry point
;;;;;;;
;;;;;;; cmp	ah,0		; Did it succeed?
;;;;;;; jne	short ???	; Jump if not

	cmp	PSWAT_VER,(5 shl 8) or 30 ; Izit version 5.30 or later?
	jb	short @F	; Jump if not

	push	seg DGROUP	; Get segment of PSWAT_FVEC
	pop	es		; Address it
	assume	es:DGROUP	; Tell the assembler about it

	mov	PSWAT_FVEC.FSEL,bx ; Save for later use
	mov	PSWAT_FVEC.FOFF,edx ; ...
	mov	PSWAT2_FVEC.FOFF,edx ; ...
@@:
	pop	es		; Restore
	assume	es:nothing	; Tell the assembler about it
INIT_VCPI_XPSWAT2:
	mov	eax,LaIDT	; Get linear address of GXT's IDT
	mov	GXTIDTR.DTR_BASE,eax ; Save for later use

; Enter PM again with using the new CR3 and initialize PM

	mov	VCPEPM.VCPEPM_EXIT.FSEL,DTE_CS ; Save initial CS
	mov	VCPEPM.VCPEPM_EXIT.FOFF,offset cs:INIT_VCPI_PMINI2 ; ... EIP

; Put return VM registers onto the stack

	mov	eax,esp 	; Get current ESP

	PUSHD	gs		; Place GS onto stack
	PUSHD	fs		; ...	FS ...
	PUSHD	ds		; ...	DS ...
	PUSHD	es		; ...	ES ...
	PUSHD	ss		; ...	SS ...
	push	eax		; ...	ESP ...
	pushfd			; ...	EFL ...
	PUSHD	cs		; ...	CS ...
	lea	eax,INIT_VCPI_VMRET2 ; Get return EIP
	push	eax		; ...	EIP ...

	mov	PMSTK_FVEC.FSEL,DTE_SS ; Setup stack for later use
	mov	PMSTK_FVEC.FOFF,esp ; ...

	cli			; Enter with IF=0

	mov	esi,LaVCPEPM	; Get linear address of VCPEPM
	VCPICALL @VCPI_EPM	; Enter PM using ESI = EPM struc
INIT_VCPI_PMINI2:
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

	cli			; Some VCPI hosts (RM386 comes to mind)
				; start us off with IF=1
	lss	esp,PMSTK_FVEC	; Setup our stack
	assume	ss:nothing	; Tell the assembler about it

	xor	ax,ax		; A convenient zero
	mov	ds,ax		; Clear to avoid fault
	assume	ds:nothing	; Tell the assembler about it
	mov	es,ax		; Clear to avoid fault
	assume	es:nothing	; Tell the assembler about it
	mov	fs,ax		; Clear to avoid fault
	assume	fs:nothing	; Tell the assembler about it
	mov	gs,ax		; ...
	assume	gs:nothing	; Tell the assembler about it

; Setup common data in load module data area in extended memory

	mov	ax,DTE_LOAD+1*(type DESC_STR) ; Get GXT's data selector
	mov	fs,ax		; Address the file's data segment
	assume	fs:DGROUP	; Tell the assembler about it

	mov	fs:[0].FILE_4GB,DTE_4GB ; Save descriptor
	mov	fs:[0].FILE_CR3,DTE_CR3 ; ...

	mov	ax,DTE_LOAD	; Get PGROUP data selector
	mov	es,ax		; Address it
	assume	es:PGROUP	; Tell the assembler about it

; Call protected mode initialization code

	call	GXTINI.MD_IPROT ; Call it

	mov	ax,DTE_4GB	; Get AGROUP data selector
	mov	ds,ax		; Address it
	assume	ds:AGROUP	; Tell the assembler about it

	mov	ax,DTE_ES	; Get RGROUP data selector
	mov	es,ax		; Address it
	assume	es:RGROUP	; Tell the assembler about it

	cli			; Exit with IF=0

	mov	ax,(@VCPI shl 8) or @VCPI_EPM ; Get return function
	call	PMI_FVEC	; Request VCPI service
INIT_VCPI_VMRET2:
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing

	sti			; Enable interrupts

; Re-specify the GXT stack into extended memory

	push	dword ptr (64*1024) ; Get length of GXT low memory
	push	LaSTK		; Get base address
	push	DTE_SS		; Get DTE
	push	((mask $DTE_B) shl 8) or CPL0_DATA ; Get A/R byte and flags
	call	SET_DEVGDT	; Set the GDT entry

	push	dword ptr (64*1024) ; Get length of GXT low memory
	push	LaSTK		; Get base address
	push	DTE_SSB0	; Get DTE
	push	CPL0_DATA	; Get A/R byte and flags
	call	SET_DEVGDT	; Set the GDT entry

; Re-specify the RGROUP code selector as per COPYLOW

	xor	eax,eax 	; Zero to use as dword
	mov	ax,seg PGROUP	; Get PGROUP segment
	shl	eax,4-0 	; Convert from paras to bytes

	push	dword ptr (64*1024) ; Get length of GXT low memory
	push	eax		; Get base address
	push	DTE_CS		; Get DTE
	push	CPL0_CODE	; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

; Re-specify the VCPI entry address

	mov	VCPEPM.VCPEPM_EXIT.FSEL,DTE_CS ; Save initial CS
	mov	VCPEPM.VCPEPM_EXIT.FOFF,offset RGROUP:EPM_VCPI_PMINI ; ... EIP
;;; INIT_VCPI_INTRUDE2:
	lea	dx,MSG_VCPIGXT ; Assume we're loading as VCPI GXT
INIT_VCPI_CLC:
;;;	    test    DEV_FLAG,@DEV_INTRUDE ; Are we INTRUDEing today?
;;;	    jz	    short @F	    ; Jump if not
;;;
;;;	    lea     dx,MSG_RUDEGXT  ; We're loading as RUDE GXT
;;;	    mov     PRTAIL,offset RGROUP:DEV_INTRZ ; Save new ending address
;;; @@:
	DOSCALL @STROUT 	; Tell 'em what we're doing

;;; ; If we allocated an XMS handle for PDIRs and PTEs,
;;; ; free it now
;;;
;;;	    push    seg DGROUP	    ; Get segment of XMSHNDL
;;;	    pop     es		    ; Address it
;;;	    assume  es:DGROUP	    ; Tell the assembler about it
;;;
;;;	    mov     dx,XMSHNDL	    ; Get the handle
;;;
;;;	    and     dx,dx	    ; Wuzit allocated?
;;;	    jz	    short @F	    ; Jump if not
;;;
;;;	    call    XMS_UNINST	    ; Remove XMS handle in DX
;;; @@:
;;;	    test    DEVLOAD,@DEVL_PSWAT ; Izit present?
;;;	    jz	    short @F	    ; Jump if not
;;;
;;;	    mov     edx,-1	    ; Skip new linear address
;;;	    mov     ebx,-1	    ; Use the current CR3
;;;	    XVCPICALL @VCPI_DBGLIN  ; Request SWAT services
;;;				    ; Return with EDX = current linear address
;;; @@:
	clc			; Mark as successful

	jmp	short INIT_VCPI_EXIT ; Join common exit code


INIT_VCPI_ERR:
	stc			; Indicate something went wrong
INIT_VCPI_EXIT:
	REGREST <es>		; Restore
	assume	es:nothing	; Tell the assembler about it
	popad			; Restore all EGP registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INIT_VCPI endp			; End INIT_VCPI procedure
	NPPROC	ALLOC_XMS -- Allocate XMS Memory
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Allocate XMS memory

On entry:

EDX	=	size in bytes to allocate

On exit:

EAX	=	base physical address
CX	=	XMS handle
CF	=	0 if all went well (although @DEV_XMS might be clear)
	=	1 otherwise

|

	REGSAVE <bx,edx,di,ds,es> ; Save registers

	mov	ax,seg RGROUP	; Get segment of RGROUP
	mov	ds,ax		; Address it
	assume	ds:RGROUP	; Tell the assembler about it

	mov	ax,seg NGROUP	; Get segment of NGROUP
	mov	es,ax		; Address it
	assume	es:NGROUP	; Tell the assembler about it

	mov	DDS.DDS_SIZE,edx ; Save in case we need VDS translation
	add	edx,1024-1	; Round up to 1KB boundary
	shr	edx,10-0	; Convert from bytes to 1KB

	mov	ah,XMS_GETXMB	; Function code to allocate eDX kilobytes
	call	XMSDRV_VEC	; Request XMS service
				; Return with AX = 1 if successful
				;	      DX = XMS handle
	cmp	ax,1		; Did it work?
	SETMSG	DRV,"Unable to allocate XMS memory."
	jne	short ALLOC_XMS_ERRXMS ; Jump if not

	mov	cx,dx		; Save to return as result

; Lock the memory to get its linear/physical address

	mov	ah,@XMS_LCKXMB	; Function code to lock an XMB, DX=handle
	call	XMSDRV_VEC	; Request XMS service
				; Return with AX = 1 if successful
				;	      DX:BX = 32-bit linear/physical addr
	cmp	ax,1		; Did it work?
	SETMSG	DRV,"Unable to lock XMS memory."
	jne	short ALLOC_XMS_ERRXMS0 ; Jump if not

	mov	ax,dx		; Copy high-order word
	shl	eax,16		; Shift to high-order word
	mov	ax,bx		; Copy low-order word

; If we're running under 386MAX or Memory Commander, translate
; the incoming address from linear to physical.

	test	DEV_FLAG,@DEV_VDS ; Do we need VDS translation?
	jz	short ALLOC_XMS_NOVDS ; Jump if not

	mov	DDS.DDS_FVEC.FOFF,eax ; Save as linear address

	mov	dx,@VDSF_XBUF	; Disable automatic buffer allocation
	lea	di,DDS		; ES:DI ==> DDS
	VDSCALL @VDS_LOCK	; Request VDS service
	jnc	short @F	; Jump if no error

	SETMSG	DRV,"VDS translation error."

	stc			; Indicate something went wrong

	jmp	short ALLOC_XMS_EXIT ; Join common exit code (note CF=1)


@@:
	mov	eax,DDS.DDS_POFF ; Get the physical address
ALLOC_XMS_NOVDS:
	mov	DRV_ERRMSG,-1	; Mark as no error

	jmp	short ALLOC_XMS_EXIT0 ; Join common exit code with EAX=addr


ALLOC_XMS_ERRXMS0:
	mov	ah,@XMS_RELXMB	; Function code to release an XMB, DX=handle
	call	XMSDRV_VEC	; Request XMS service
ALLOC_XMS_ERRXMS:
	and	DEV_FLAG,not @DEV_XMS ; Mark as not present
ALLOC_XMS_EXIT0:
	clc			; Indicate all went well
ALLOC_XMS_EXIT:
	REGREST <es,ds,di,edx,bx> ; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

ALLOC_XMS endp			; End ALLOC_XMS procedure
	NPPROC	CHECK_EXT -- Get Size of Extended Memory
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Get size of extended memory

|

	call	CheckE820	; Check BIOS function E820
	jnc	short CHECK_EXT_EXIT ; Jump if successful

	call	CheckE801	; Check BIOS function E801
	jnc	short CHECK_EXT_EXIT ; Jump if successful

	call	Check8Axx	; Check BIOS function 8Axx
	jnc	short CHECK_EXT_EXIT ; Jump if successful






	call	Check88xx	; Check BIOS function 88xx
CHECK_EXT_EXIT:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_EXT endp			; End CHECK_EXT procedure
	NPPROC	Check88xx -- Check Function 88xx Size
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Check function 88xx size.

On exit:

PHYSIZE =	top of physical memory in 1KB

|

	REGSAVE <eax,cx,dx,di>	; Save registers

	xor	eax,eax 	; Zero to use as dword
	mov	ah,88h		; Get extmem size
	int	15h		; Request BIOS service
				; Return AX = extmem in 1KB up to 64MB
	and	eax,not (4-1)	; Round down to a multiple of four
	add	eax,1024	; Plus first megabyte

	mov	PHYSIZE,eax	; Save for later use

	clc			; Mark as successful

	REGREST <di,dx,cx,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

Check88xx endp			; End Check88xx procedure
	NPPROC	Check8Axx -- Check Function 8Axx Size
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Check function 8Axx size.

On exit:

PHYSIZE =	top of physical memory in 1KB
CF	=	0 if successful
	=	1 if not

|

	REGSAVE <eax,cx,dx,di>	; Save registers

	mov	ah,8Ah		; Get extmem size
	int	15h		; Request BIOS service
	jc	short @F	; Jump if not supported
				; Return DX:AX = extmem in 1KB
	shl	eax,16		; Shift up low-order word to make room for DX
	mov	ax,dx		; Copy high-order word
	rol	eax,16		; Swap to proper order

	mov	PHYSIZE,eax	; Save for later use

	clc			; Mark as successful
@@:
	REGREST <di,dx,cx,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

Check8Axx endp			; End Check8Axx procedure
	NPPROC	CheckE801 -- Check Function E801 Memory Size
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Check function E801 memory size.

On exit:

PHYSIZE =	top of physical memory in 1KB
CF	=	0 if successful
	=	1 if not

|

	pushad			; Save all EGP registers

	xor	cx,cx		; Set to known value
	xor	dx,dx		; ...
	mov	ax,0E801h	; Get function code to return extmem
	int	15h		; Request BIOS service
	stc			; Assume not installed
	jcxz	CheckE801Exit	; Jump if not installed
				; Return AX = installed extmem in 1KB up to 16MB
				; ...	 BX = ...		 64KB above 16MB
				; ...	 CX = configured extmem in 1KB up to 16MB
				; ...	 DX = ...		 64KB above 16MB
	movzx	eax,cx		; Get extmem up to 16MB in 1KB
	movzx	edx,dx		; Zero to use as dword
	shl	edx,16-10	; Convert from 64KB to 1KB
	add	eax,edx 	; Plus extmem up to 16MB

	mov	PHYSIZE,eax	; Save for later use

	clc			; Mark as successful
CheckE801Exit:
	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CheckE801 endp			; End CheckE801 procedure
	NPPROC	CheckE820 -- Check E820 Memory Size
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Check function E820 memory size.

On exit:

PHYSIZE =	top of physical memory in 1KB
CF	=	0 if successful
	=	1 if not

|

	pushad			; Save registers
	push	es		; ...

	mov	ax,ds		; Get segment of MEMBUF
	mov	es,ax		; Address it
	assume	es:NGROUP	; Tell the assembler about it

	xor	ebx,ebx 	; Mark as start of map
CheckE820Next:
	mov	eax,0E820h	; Some BIOSes require high-order word to be zero
	mov	ecx,type MB_STR ; Size of buffer
	mov	edx,'SMAP'      ; Special value
	lea	di,MEMBUF	; ES:DI ==> buffer
	int	15h		; Request BIOS service
	jc	short CheckE820Done ; Jump if no more data

; Note that we test for EBX == 0 at the end, because although that means
; there are no more entries, the contents of the buffer are still valid.

	cmp	MEMBUF.MB_TYPE,@MB_MEM ; Izit extmem?
	jne	near ptr CheckE820Loop ; Jump if not

;;;;;;; cmp	MEMBUF.MB_BASE.EDQLO,1024*1024 ; Izit at or above 1MB?
;;;;;;; jb	near ptr DispE820Loop ; Jump if not
;;;;;;;
	inc	MEMCNT		; Mark as one more entry

	mov	eax,MEMBUF.MB_BASE.EDQLO ; Get base address
	add	eax,MEMBUF.MB_LEN.EDQLO ; Get length
	shr	eax,10-0	; Convert from bytes to 1KB

	cmp	eax,PHYSIZE	; Izit larger?
	jb	short @F	; Jump if not

	mov	PHYSIZE,eax	; Save for later use
@@:
CheckE820Loop:
	cmp	ebx,0		; Izit over?
	jne	short CheckE820Next ; Jump if no more data
CheckE820Done:
	cmp	MEMCNT,1	; Any entries?
				; CF=1 if none
	pop	es		; Restore
	assume	es:nothing	; Tell the assembler about it
	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CheckE820 endp			; End CheckE820 procedure
	NPPROC	DEV_ARGS -- Process Arguments, Call INIT_REAL
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Process arguments and call INIT_REAL.

On entry:

ES:BX	==>	Request header

On exit:

CF	=	0 if all went well
	=	1 otherwise

|

	pushad			; Save all EGP registers
	REGSAVE <ds,es> 	; Save registers

COMMENT|

Setup registers for INIT_REAL call

DS:DX	==>	"d:\path\filename.ext [arguments]",0
DS:SI	==>	"[arguments]",0

|

	lds	si,DOSCMD_VEC	; DS:SI ==> DOS command line

	test	DEV_FLAG,@DEV_DOSCMD ; Izit from DOS command line?
	jnz	short DEV_ARGS_SRCH0 ; Jump if so

	les	bx,RH_VEC	; ES:BX ==> request header
	assume	es:nothing	; Tell the assembler about it

	lds	si,es:[bx].INIT_CMD_VEC ; Get address of command line args
	assume	ds:nothing	; Tell the assembler about it

	mov	dx,si		; DS:DX ==> start of line

; Skip to [arguments] if any

DEV_ARGS_FILE:			; Initial scan to skip over file name
	lods	ds:[si].LO	; Get the next byte

	cmp	al,CR		; If CR, then no arguments
	je	short DEV_ARGS_DEF ; Use defaults

	cmp	al,LF		; If LF, then no arguments
	jne	short @F	; Jump if not
DEV_ARGS_DEF:
	dec	si		; Back off to terminator

	jmp	short DEV_ARGS_SRCH0 ; Join common search code


@@:
	cmp	al,' '          ; If white space, then we've reached the end
	je	short DEV_ARGS_SRCH0 ; Yup

	cmp	al,TAB		; If white space, then we've reached the end
	je	short DEV_ARGS_SRCH0 ; Yup

	and	al,al		; If zero, we've reached the end
	jnz	short DEV_ARGS_FILE ; Not as yet
DEV_ARGS_SRCH0: 		; Search for arguments
	push	seg NGROUP	; Get our segment
	pop	es		; Address it
	assume	es:NGROUP	; Tell the assembler about it
DEV_ARGS_SRCH:			; Search for arguments
	lea	bx,[si-1]	; Copy offset of filename terminator

	call	SKIP_WHITE	; Skip over white space

	push	si		; Save start of args for a moment

; Skip to end of the argument list to plant a terminating zero

DEV_ARGS_TERM:
	lods	ds:[si].LO	; Get the next byte

	cmp	al,CR		; If CR, then end of arguments
	je	short @F	; Jump if so

	cmp	al,LF		; If LF, then end of arguments
	je	short @F	; Jump if so

	and	al,al		; If zero, we've reached the end
	jnz	short DEV_ARGS_TERM ; Not as yet
@@:
	lea	di,[si-1]	; Save ending offset in index register

	pop	si		; Restore starting argument offset

; Set flags for XT or MCA if necessary

	test	DEV_FLAG,@DEV_XT ; Izit an XT?
	jz	short @F	; Not this time

	or	GXTINI.MD_ATTR,@MD_XT ; Mark as an XT
@@:
	test	DEV_FLAG,@DEV_MCA ; Izit an MCA-compatible machine?
	jz	short @F	; Not this time

	or	GXTINI.MD_ATTR,@MD_MCA ; Mark as an MCA-compatible
@@:

; Tell the load module that we support APIVER features if it does

	test	GXTINI.MD_ATTR,@MD_VER ; Duzit?
	jz	short @F	; Jump if not

	mov	GXTINI.MD_MAXVER,01h ; Tell 'em
@@:

; Tell the load module we support MD_VSIZE if it does

	or	GXTINI.MD_ATTR,@MD_VSIZE ; Tell 'em

; Initialize real mode

	mov	cx,0		; Terminators
	xchg	cl,ds:[bx]	; Swap 'em
	xchg	ch,ds:[di]	; Swap 'em
	call	GXTINI.MD_IREAL ; Call INIT_REAL
	xchg	ch,ds:[di]	; Restore
	xchg	cl,ds:[bx]	; Restore

	test	GXTINI.MD_ATTR,@MD_RMIE ; Test for real mode initialization error
	jnz	near ptr DEV_ARGS_ERR ; Jump if something went wrong

	mov	eax,GXTINI.MD_SIZE ; Get the initialization size in bytes
	add	eax,16-1	; Round up to para boundary
	and	ax,not (16-1)	; and down again
	mov	GXT_TSIZ,eax	; Save for later use
	mov	GXT_ISIZ,eax	; ...

	mov	eax,GXTINI.MD_USIZE ; Get byte size of uninitialized data
	add	eax,16-1	; Round up to para boundary
	and	ax,not (16-1)	; and down again
	add	GXT_TSIZ,eax	; Add into accumulated load count
	mov	GXT_USIZ,eax	; Save as uninitialized data size

	mov	eax,GXTINI.MD_DATA ; Read in the data segment offset
	mov	GXT_DAT,eax	; Save for later use

	clc			; Indicate all went well

	jmp	short DEV_ARGS_EXIT ; Join common exit code


DEV_ARGS_ERR:
	stc			; Indicate something went wrong
DEV_ARGS_EXIT:
	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	popad			; Save all EGP registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEV_ARGS endp			; End DEV_ARGS procedure
	NPPROC	LOADUP -- Copy LOD Module To Extended Memory
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Copy a load module to extended memory
In each case, the data map is LaCODE, LaDATA, LaIDT, LaSTK, LaTSS.

1. If we're not using VCPI w/o XMS manager, use BIOS block move.
2. If we're not using VCPI w/XMS manager, allocate XMS memory,
   and use XMS block move.

On entry:

CF	=	0 if all went well
	=	1 otherwise

|

	REGSAVE <eax,ebx,ecx,edx,si,es,fs> ; Save registers

	test	DEV_FLAG,@DEV_VCPI ; Are we using VCPI services?
	jnz	near ptr LOADUP_EXIT ; Jump if so (already done) (note CF=0)

	push	seg NGROUP	; Get our segment
	pop	es		; Address it
	assume	es:NGROUP	; Tell the assembler about it

	mov	GXTINI.MD_IPROT.FSEL,DTE_LOAD ; Save for protected mode init
	mov	GXTINI.MD_RPROT.FSEL,DTE_LOAD ; ...			 restore

	test	DEV_FLAG,@DEV_XMS ; Is there an XMS driver present?
	jnz	near ptr LOADUP_XMS ; Jump if so

	mov	edx,PHYSIZE	; Use current physical size in 1KB
	shl	edx,10-0	; Convert from 1KB to bytes
	mov	LaEND,edx	; Save as ending linear/physical address

	mov	eax,size TSS_STR ; Get size of TSS

; Make room for the SIRB table whether or not VME is supported,

	add	eax,256/8	; Plus size of SIRB table
	add	eax,8*1024+1	; Skip over I/O bit permission map
	add	eax,4-1 	; Round up to dword
	and	eax,not (4-1)	; ... boundary
	mov	TSS_LEN,eax	; Save for later use

	sub	edx,eax 	; Less size of TSS data
	jb	near ptr LOADUP_ERR0 ; Jump if too small

	mov	LaTSS,edx	; Save as linear/physical address of TSS

	sub	edx,GXTSTK_FVEC.FOFF ; Less size of stack
	jb	near ptr LOADUP_ERR0 ; Jump if too small

	mov	LaSTK,edx	; Save as linear/physical address of stack

	sub	edx,256*(type IDT_STR) ; Less size of IDT
	jb	near ptr LOADUP_ERR0 ; Jump if too small

	mov	LaIDT,edx	; Save as linear/physical address of IDT

	sub	edx,GXT_TSIZ	; Less size of PM-resident data
	jb	near ptr LOADUP_ERR0 ; Jump if too small

	and	edx,not (1024-1) ; Round down to 1KB boundary
	mov	LaCODE,edx	; Save linear/physical address of code

	cmp	edx,1024*1024	; Izit too small?
	jb	near ptr LOADUP_ERR0 ; Jump if too small

	mov	GXTINI.MD_PHYS,edx ; Save physical address of code segment

	add	edx,GXT_DAT	; Plus size of data segment
	mov	LaDATA,edx	; Save linear/physical address of data

; Calculate DTE limit

	mov	ecx,GXT_ISIZ	; Get size of initialized code/data
	mov	ebx,ecx 	; Copy to save in DTEs

	dec	ebx		; Convert from length to limit

	cmp	ebx,1024*1024	; Check against limit limit
	jb	short @F	; Jump if within range

	shr	ebx,12-0	; Convert from bytes to 4KB
	or	ebx,(mask $DTE_G) shl (8*(DESC_SEGLM1-DESC_BASE2)) ; Set G-bit
@@:

; Save DTE for source and destination limits

	mov	MOVE_TAB.MDTE_DS.DESC_SEGLM0,bx ; Save as data limit
	mov	MOVE_TAB.MDTE_ES.DESC_SEGLM0,bx ; ...
	rol	ebx,16		; Swap high- and low-order words
	mov	MOVE_TAB.MDTE_DS.DESC_SEGLM1,bl ; Save size & flags
	mov	MOVE_TAB.MDTE_ES.DESC_SEGLM1,bl ; ...
;;;;;;; ror	ebx,16		; Swap back

	xor	ebx,ebx 	; Zero to use as dword
	mov	bx,seg PGROUP	; Get segment of module in low DOS
	shl	ebx,4-0 	; Convert from paras to bytes

	mov	edx,GXTINI.MD_PHYS ; Get physical address of code segment
LOADUP_NEXT:

; Save DTE for source base and A/R

	mov	MOVE_TAB.MDTE_DS.DESC_BASE01.EDD,ebx
	rol	ebx,8		; Rotate out the high-order byte
	mov	MOVE_TAB.MDTE_DS.DESC_BASE3,bl ; Save as base byte #3
	ror	ebx,8		; Rotate back
	mov	MOVE_TAB.MDTE_DS.DESC_ACCESS,CPL0_DATA

; Save DTE for destination base and A/R

	mov	MOVE_TAB.MDTE_ES.DESC_BASE01.EDD,edx
	rol	edx,8		; Rotate out the high-order byte
	mov	MOVE_TAB.MDTE_ES.DESC_BASE3,dl ; Save as base byte #3
	ror	edx,8		; Rotate back
	mov	MOVE_TAB.MDTE_ES.DESC_ACCESS,CPL0_DATA

	REGSAVE <ebx,ecx,edx,fs,gs> ; Save because you can never tell
				; what a BIOS might clobber

; Set move length as smaller of actual length
; and the maximum move length (64KB).

	cmp	ecx,64*1024	; Izit too big?
	jbe	short @F	; Jump if not

	mov	ecx,64*1024	; Use smaller
@@:
	shr	ecx,1-0 	; Convert from bytes to words

	lea	si,MOVE_TAB	; ES:SI ==> GDT
	mov	ah,87h		; Function code to BIOS block move
	int	15h		; Request BIOS service

	REGREST <gs,fs,edx,ecx,ebx> ; Restore

	cmp	ah,0		; Did it work?
	jne	near ptr LOADUP_ERR ; Jump if not

	mov	eax,64*1024	; Get maximum length moved

	add	ebx,eax 	; Skip to next source base
	add	edx,eax 	; ...	       destin ...

	sub	ecx,eax 	; Less length
	ja	short LOADUP_NEXT ; Jump if there's more to do

	clc			; Indicate all went well

	jmp	LOADUP_EXIT	; Join common exit code


; XMS driver present:  use its memory to copy code/data to extended memory

LOADUP_XMS:

; Calculate how many 1KB blocks we need to allocate

	push	fs		; Save for a moment

	push	seg DGROUP	; Get segment of PL0STK_SIZ
	pop	fs		; Address it
	assume	fs:DGROUP	; Tell the assembler about it

	mov	edx,GXT_ISIZ	; Get size of initialized code/data
	mov	XMBMOVE.XMBMOVE_LEN,edx ; Save as move length

	add	edx,GXT_TSIZ	; Plus total size of PM-resident GXT
	add	edx,PL0STK_SIZ	; Plus size of PL0 stack
	call	ALLOC_XMS	; Allocate EDX bytes of XMS memory
	pop	fs		; Restore
	assume	fs:PGROUP	; Tell the assembler about it
				; Returning EAX = base physical address
				;	    CX	= handle
	jc	near ptr LOADUP_ERR0 ; Jump if something went wrong

	mov	GXTINI.MD_PHYS,eax ; Save physical address of code segment
	mov	LaCODE,eax	; Save linear address of image

	push	seg DGROUP	; Get segment of XMSHNDL2
	pop	fs		; Address it
	assume	fs:DGROUP	; Tell the assembler about it

	mov	XMSHNDL2,cx	; Save for later use

	add	eax,GXT_DAT	; Plus offset to data segment
	mov	LaDATA,eax	; Save as linear address of our data

	mov	eax,LaCODE	; Get linear address of our code
	add	eax,GXT_TSIZ	; Plus size of PM-resident data

	mov	LaIDT,eax	; Save as linear address of IDT
	add	eax,256*(type IDT_STR) ; Plus size of IDT

	mov	LaPL0STK,eax	; Save as linear address of PL0 stack
	add	eax,PL0STK_SIZ	; Skip over the PL0 stack

	mov	LaSTK,eax	; Save as linear address of stack
	add	eax,GXTSTK_FVEC.FOFF ; Plus size of stack

	mov	LaTSS,eax	; Save as linear address of TSS
	add	eax,size TSS_STR ; Plus size of TSS

; Make room for the SIRB table whether or not VME is supported,

	add	eax,256/8	; Plus size of SIRB table
	add	eax,8*1024+1	; Skip over I/O bit permission map
	add	eax,4-1 	; Roudn up to dword
	and	eax,not (4-1)	; ... boundary
	mov	ebx,eax 	; Copy current offset
	sub	ebx,LaTSS	; Less start to get length in bytes
	mov	TSS_LEN,ebx	; Save for later use

	mov	LaEND,eax	; Save as ending linear address

	test	DEV_FLAG,@DEV_XMS ; Did we fail trying XMS?
	jz	short LOADUP_ERR0 ; Jump if so

; Move data to XMS memory

	mov	XMBMOVE.XMBMOVE_SHNDL,0 ; Save as source handle
				; meaning it's in the first megabyte
	mov	XMBMOVE.XMBMOVE_SOFF.VOFF,0 ; Save as source offset
	mov	XMBMOVE.XMBMOVE_SOFF.VSEG,seg PGROUP ; ...   segment

	mov	dx,XMSHNDL2	; Get XMS handle #
	mov	XMBMOVE.XMBMOVE_DHNDL,dx ; Save as destin handle
	mov	XMBMOVE.XMBMOVE_DOFF,0 ; ...		   offset

	lea	si,XMBMOVE	; DS:SI ==> XMS block move struc
	mov	ah,@XMS_MOVXMB	; Function code for block move using DS:SI
	call	XMSDRV_VEC	; Request XMS service
				; Return with AX = 1 if successful
	cmp	ax,1		; Did it work?
	je	short LOADUP_EXIT ; Jump if so (note CF=0)

; An error occurred using XMS services; unlock and release the memory

LOADUP_ERRXMS:
	mov	ah,@XMS_UNLXMB	; Function code to unlock an XMB, DX=handle
	call	XMSDRV_VEC	; Request XMS service
				; Return with AX = 1 if successful
	cmp	ax,1		; Did it work?
	je	short @F	; Jump if so

	SWATMAC ERR,RM		; Call our debugger
@@:
	mov	ah,@XMS_RELXMB	; Function code to release an XMB, DX=handle
	call	XMSDRV_VEC	; Request XMS service
				; Return with AX = 1 if successful
	cmp	ax,1		; Did it work?
	je	short @F	; Jump if so

	SWATMAC ERR,RM		; Call our debugger
@@:
LOADUP_ERR0:
	SETMSG	DRV,"Insufficient extended memory to load."
LOADUP_ERR:
	stc			; Indicate the move failed
LOADUP_EXIT:
	REGREST <fs,es,si,edx,ecx,ebx,eax> ; Restore
	assume	es:nothing,fs:nothing ; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

LOADUP	endp			; End LOADUP procedure
	NPPROC	KEYWAIT -- Wait For Keyboard Acknowledgement
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Purge the keyboard buffer and wait for a key press -- discard the key

On exit:

AX	=	last key pressed

|

KEYWAIT_NEXT:
	KEYCALL @GETKST 	; Get buffer state
	jz	short KEYWAIT_PAUSE ; Nothing available

	KEYCALL @GETKEY 	; Get the key

	jmp	KEYWAIT_NEXT	; Go around again

KEYWAIT_PAUSE:
	KEYCALL @GETKEY 	; Get the key

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

KEYWAIT endp			; End KEYWAIT procedure
	NPPROC	OUTCMOS -- Out To CMOS, Conditional Read
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Out to CMOS, conditional read.

Note that this routine is bimodal.

This routine should not be interrupted between the OUT and IN.

|

	pushf			; Save flags
	cli			; Disallow interrupts

	out	dx,al		; Send to CMOS

	cmp	dx,@CMOS_CMD	; Izit an AT?
	jne	short @F	; Jump if not

	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

	in	al,@CMOS_DATA	; Ensure OUT is followed by IN
@@:
	popf			; Restore flags

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

OUTCMOS endp			; End OUTCMOS procedure
	NPPROC	CHECK_MODEL -- Check for MCA-Compatible Machines
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Check for MCA-compatible, EISA, and a whole bunch more machines.

|

	REGSAVE <ax,bx,cx,dx,di,es> ; Save registers

	push	seg CGROUP	; Get ROM BIOS segment
	pop	es		; Address via segment register
	assume	es:CGROUP	; Tell the assembler about it

	mov	al,BIOSCPUID	; Get the machine ID byte
	mov	MACHID,al	; Save for later use

	test	DEV_FLAG,@DEV_XMS ; Are there XMS services present?
	jnz	near ptr CHECK_MODEL_EXIT ; Jump if so

; Check on using I/O port 92h for toggling A20

	mov	ax,@A20_SUP	; A20 function, Query A20 gate support
	int	15h		; Request BIOS service

	cmp	ah,0		; Did it succeed?
	jne	short @F	; Jump if not

	mov	A20SUP,bx	; Save for later use
	or	DEV_FLAG,@DEV_A20FN ; Mark as services present

	test	bx,mask $A20_I92 ; Duzit use I/O port 92h to toggle A20?
	jz	short @F	; Jump if not

	mov	ACTA20_COMSUB,offset RGROUP:A20COM_I92 ; Save routine addr
@@:

; If this BIOS doesn't support A20 Architecture functions,
; check for I/O port 78h or 92h gating of A20

	test	DEV_FLAG,@DEV_A20FN ; Are A20 Architecture services present?
	jnz	short @F	; Jump if so

	smsw	ax		; Get MSW

	test	ax,mask $PE	; Are we in VM?
	jnz	short @F	; Skip this (especially CHECK_I92
				; as it can reboot the system)
	call	CHECK_I78	; Check for I/O port 78h toggle of A20
	call	CHECK_I92	; Check for I/O port 92h A20 gating
@@:

; Save pointer to BIOS configuration data (if supported)

	push	es		; Save for a moment

	mov	ah,0C0h 	; Attempt to read configuration record
	stc			; Assume failure
	int	15h		; Request BIOS service
	assume	es:nothing	; Tell the assembler about it
	jc	short @F	; Jump if error

	cmp	ah,80h		; Check for error return
	je	short @F	; Jump if error

	cmp	ah,86h		; Check for error return
	je	short @F	; Jump if error

	mov	BIOSCONF_VEC.VOFF,bx ; Save for later use
	mov	BIOSCONF_VEC.VSEG,es ; ...
@@:
	pop	es		; Restore
	assume	es:CGROUP	; Tell the assembler about it

; Check for EISA signature at F000:FFD9

; Some early EISA machines don't follow the spec, they put their
; signature somewhere else in the BIOS.  However, we can't search
; through the entire BIOS, because many ISA machines have EISA
; strings that we would pick up as false positives.

	cmp	dword ptr EISASIGN,'ASIE' ; Check for EISA signature
	jne	short CHECK_MODEL_XEISA ; Jump if not EISA machine

	or	DEV_FLAG,@DEV_EISA ; Mark as present (EISA machine)

	jmp	CHECK_MODEL_EXIT ; Join common code

CHECK_MODEL_XEISA:

; Check for MCA-compatible machines

	cmp	BIOSCONF_VEC.VSEG,0 ; Izit valid?
	je	short CHECK_MODEL_XMCA; Jump if not

	les	bx,BIOSCONF_VEC ; ES:BX ==> BIOS configuration data
	assume	es:nothing	; Tell the assembler about it

	test	es:[bx].CFG_PARMS,@CFG_MCA ; Izit a Micro Channel Architecture?
	jz	short CHECK_MODEL_XMCA ; Not this time

	or	DEV_FLAG,@DEV_MCA ; Mark as an MCA-compatible machine
	mov	ACTA20_COMSUB,offset RGROUP:A20COM_I92 ; Save routine addr

	test	DEV_FLAG,@DEV_A20FN ; A20 services present?
	jnz	short @F	; Jump if so

	mov	A20SUP,mask $A20_I92 ; Mark as A20 support value
@@:
	jmp	short CHECK_MODEL_EXIT ; Join common exit code

	assume	es:nothing	; Tell the assembler about it

CHECK_MODEL_XMCA:
CHECK_MODEL_EXIT:
	REGREST <es,di,dx,cx,bx,ax> ; Restore
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_MODEL endp		; End CHECK_MODEL procedure
	NPPROC	INIT_GDT -- Initialize The GDT
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Initialize the GDT

|

	pushad			; Save all EGP registers

	movzx	eax,PGXTGDT.VSEG ; Get segment of GXTGDT
	movzx	ebx,PGXTGDT.VOFF ; ... offset ...
	shl	eax,4-0 	; Convert from paras to bytes
	add	eax,ebx 	; Add to get 32-bit linear address
	mov	GXTGDTR.DTR_BASE,eax ; Save for later use
	mov	GXTGDTR.DTR_LIM,(size XDTE_STR)-1 ; ...

	xor	eax,eax 	; Zero to use as dword
	mov	ax,cs		; Get current code segment
	shl	eax,4-0 	; Convert from paras to bytes

	push	dword ptr (64*1024) ; Get length of GXT low memory
	push	eax		; Get base address
	push	DTE_CS		; Get DTE
	push	CPL0_CODE	; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

	xor	eax,eax 	; Zero to use as dword
	mov	ax,seg PGROUP	; Get PGROUP segment
	shl	eax,4-0 	; Convert from paras to bytes

	push	dword ptr (64*1024) ; Get length of GXT low memory
	push	eax		; Get base address
	push	DTE_DS		; Get DTE
	push	CPL0_DATA or DPL3 ; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

	movzx	eax,RGRSEG	; Get RGROUP segment
	shl	eax,4-0 	; Convert from paras to bytes

	push	dword ptr (64*1024) ; Get length of GXT low memory
	push	eax		; Get base address
	push	DTE_CSR 	; Get DTE
	push	CPL0_CODE	; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

	push	dword ptr (64*1024) ; Get length of GXT low memory
	push	eax		; Get base address
	push	DTE_ES		; Get DTE
	push	CPL0_DATA or DPL3 ; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

	xor	eax,eax 	; Zero to use as dword
	mov	ax,ss		; Get current stack segment
	shl	eax,4-0 	; Convert from paras to bytes

	push	dword ptr (64*1024) ; Get length of GXT low memory
	push	eax		; Get base address
	push	DTE_SS		; Get DTE
	push	((mask $DTE_B) shl 8) or CPL0_DATA ; Get A/R byte and flags
	call	SET_DEVGDT	; Set the GDT entry

	push	dword ptr (64*1024) ; Get length of GXT low memory
	push	eax		; Get base address
	push	DTE_SSB0	; Get DTE
	push	CPL0_DATA	; Get A/R byte and flags
	call	SET_DEVGDT	; Set the GDT entry

;;;	    test    DEV_FLAG,@DEV_INTRUDE ; Are we INTRUDEing today?
;;;	    jz	    short @F	    ; Jump if not
;;;
;;;	    push    dword ptr (64*1024) ; Get length of GXT low memory
;;;	    push    eax 	    ; Get base address
;;;	    push    DTE_RUDSS1	    ; Get DTE
;;;	    push    ((mask $DTE_B) shl 8) or CPL0_DATA or CPL1 ; Get A/R byte and flags
;;;	    call    SET_DEVGDT	    ; Set the GDT entry
;;; @@:
	mov	eax,OffCR3	; Get offset of CR3 temp PTE
	shl	eax,(12-2)-0	; Convert from 4KB in dwords to bytes

	push	dword ptr (4*1024) ; Get length of 4KB page
	push	eax		; Get base address
	push	DTE_CR3 	; Get DTE
	push	CPL0_DATA or DPL3 ; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

	PUSHD	0		; Get length of all memory selector
	PUSHD	0		; Get base address
	push	DTE_4GB 	; Get DTE
	push	((mask $DTE_B) shl 8) or CPL0_DATA or DPL3 ; Get A/R byte and flags
	call	SET_DEVGDT	; Set the GDT entry

; Setup BIOS Data Area entry

	xor	eax,eax 	; Zero to use as dword
	mov	ax,seg BIOSDATA ; Get segment of BDA
	shl	eax,4-0 	; Convert from paras to bytes

	push	dword ptr (64*1024) ; Get length of all BDA selector
	push	eax		; Get base address
	push	DTE_BDA 	; Get DTE
	push	CPL0_DATA or DPL3 ; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

; Setup DTE_LOAD entries

	mov	ecx,GXT_TSIZ	; Get length of GXT
	mov	ebx,LaCODE	; Get base address
	mov	dx,DTE_LOAD	; Get DTE for code

	push	ecx		; Get length of GXT code and aata
	push	ebx		; Get base address
	push	dx		; Get DTE
	push	((mask $DTE_B) shl 8) or CPL0_CODE ; Get A/R byte and flags
	call	SET_DEVGDT	; Set the GDT entry

	add	ebx,GXT_DAT	; Skip to data
	sub	ecx,GXT_DAT	; Less its length
	add	dx,type DESC_STR ; Skip to next entry

	push	ecx		; Get length of GXT data
	push	ebx		; Get base address
	push	dx		; Get DTE
	push	CPL0_DATA or DPL3 ; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

	add	dx,type DESC_STR ; Skip to next entry

	push	GXT_TSIZ	; Get length of GXT code and aata
	push	LaCODE		; Get base address
	push	dx		; Get DTE
	push	CPL0_DATA or DPL3 ; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

; Setup TSS descriptor

	push	TSS_LEN 	; Get length of TSS data
	push	LaTSS		; Get base address
	push	DTE_TSS 	; Get DTE
	push	CPL0_IDLE3	; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

; Setup PL0 stack for all modules

	push	es		; Save for a moment

	mov	ax,seg DGROUP	; Get segment of DGROUP
	mov	es,ax		; Address it
	assume	es:DGROUP	; Tell the assembler about it

	push	PL0STK_SIZ	; Get length of stack
	push	LaPL0STK	; Get base address
	push	DTE_PL0STK	; Get DTE
	push	((mask $DTE_B) shl 8) or CPL0_DATA ; Get A/R byte and flags
	call	SET_DEVGDT	; Set the GDT entry

	pop	es		; Restore
	assume	es:nothing	; Tell the assembler about it

; Setup temporary IDT

	push	es		; Save for a moment

	mov	ax,MAPSEG_NXT	; Get next available segment
	mov	SegIDT,ax	; Save for later use
	mov	es,ax		; Address it
	assume	es:nothing	; Tell the assembler about it

	add	MAPSEG_NXT,(256*(type IDT_STR))/16 ; Protect the IDT

	push	offset NGROUP:MEMERR_IDT ; Pass offset of error message
	call	CHECK_NXTSEG	; Ensure we've enough room

; Set the IDT table to default values = IGT_IDT[4*nn]

	mov	cx,256		; Get # entries in IDT
	xor	di,di		; Start at the beginning of the segment
	lea	eax,IGT_IDT	; Get offset of 1st handler
@@:
	mov	es:[di].IDT_SELECT,DTE_CS ; Save selector
	mov	es:[di].IDT_OFFLO,ax ; ... offset
	ror	eax,16		; Shift to low-order
	mov	es:[di].IDT_OFFHI,ax ; ... offset
	mov	es:[di].IDT_ACCESS,CPL0_INTR3 or (3 shl $DT_DPL) ; ... A/R
	rol	eax,16		; Shift back

	add	di,type IDT_STR ; Skip to next IDT entry
	add	eax,4		; ...	       handler

	loop	@B		; Jump if more IDT entries

	pop	es		; Restore
	assume	es:nothing	; Tell the assembler about it

; If there's a preceding copy of device SWAT running, install it
; in our PM GDT/IDT

	call	INIT_PSWAT	; Initialize it

	popad			; Restore all EGP registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INIT_GDT endp			; End INIT_GDT procedure
	NPPROC	PROT_INIT -- Initialize Protected Mode
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Initialize protected mode

On exit:

CF	=	0 if all went well
	=	1 otherwise

|

	pushad			; Save all EGP registers

	test	DEV_FLAG,@DEV_VCPI ; Are we using VCPI services?
	jnz	near ptr PROT_INIT_EXIT ; Jump if so (note CF=0)

	mov	eax,LaIDT	; Get linear address of IDT
	mov	GXTIDTR.DTR_BASE,eax   ; Save for later use
	mov	GXTIDTR.DTR_LIM,(type IDT_STR)*256-1 ; ...

	mov	eax,LaCODE	; Get linear address of GXT start
	shr	eax,10-0	; Convert from bytes to 1KB (rounding down)
	sub	eax,1024	; Less first megabyte
	mov	DEVEXTSIZE,ax	; Save for our INT 15h handler

; Setup the GDT

	call	INIT_GDT	; Initialize it

	mov	RMSTK_FVEC.FSEL,ss  ; Save to restore later
	mov	RMSTK_FVEC.FOFF,esp ; ...

; Save the current state of A20 in DEV_FLAG to restore later

	or	DEV_FLAG,@DEV_A20ON ; Assume A20 enabled upon entry

	call	FCHECKA20	; Izit enabled?
	jc	short @F	; Jump if so

	and	DEV_FLAG,not @DEV_A20ON ; Mark as A20 not enabled upon entry
@@:
	REGSAVE <ds,es,fs,gs>	; Save registers

	mov	es,RGRSEG	; Get segment of GXTGDT
	assume	es:RGROUP	; Tell the assembler about it

	lea	si,GXTGDT	; ES:SI ==> GDT to use

	call	GOPROT		; Enter PM
	assume	ds:PGROUP,es:RGROUP   ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

; Re-specify the GDTR and IDTR in case the BIOS loaded the
; 24-bit address only.

	LGDTD	GXTGDTR 	; Point GDTR to low memory
	LIDTD	GXTIDTR 	; ...	IDTR to extended memory

	push	es		; Save for a moment

	mov	ax,DTE_4GB	; Get AGROUP data selector
	mov	es,ax		; Address it
	assume	es:AGROUP	; Tell the assembler about it

; Copy the dummy IDT to extended memory

	movzx	esi,SegIDT	; Get segment of low memory IDT
	shl	esi,4-0 	; Convert from paras to bytes
	mov	edi,LaIDT	; Get destination IDT
	mov	ecx,(256*(type IDT_STR))/4 ; Get # dwords in IDT
S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy IDT to extended mem

	pop	es		; Restore
	assume	es:RGROUP	; Tell the assembler about it

; Handle preceding SWAT issues if present

;;;;;;; test	DEVLOAD,@DEVL_PSWAT ; Izit present?
;;;;;;; jz	short PROT_INIT_NOPSWAT ; Jump if not
;;;;;;;
; Zero the TSS

	push	es		; Save for a moment

	mov	ax,DTE_4GB	; Get AGROUP data selector
	mov	es,ax		; Address it
	assume	es:AGROUP	; Tell the assembler about it

	mov	edi,LaTSS	; ES:EDI ==> TSS
	xor	eax,eax 	; A convenient zero
	mov	ecx,TSS_LEN	; Get # bytes of TSS data
    rep stos	AGROUP:[edi].LO ; Zero it

	pop	es		; Restore
	assume	es:RGROUP	; Tell the assembler about it

	mov	ax,DTE_TSS	; Get TSS selector
	ltr	ax		; Tell the CPU about it

; Handle preceding SWAT issues if present

	test	DEVLOAD,@DEVL_QSWAT ; Izit quiet?
	jnz	short PROT_INIT_NOPSWAT ; Jump if so

	SWATMAC 		; Call our debugger
PROT_INIT_NOPSWAT:

; Set the PL0 stack for all clients

	mov	ax,DTE_LOAD+1*(type DESC_STR) ; Get GXT's data selector
	mov	fs,ax		; Address it
	assume	fs:DGROUP	; Tell the assembler about it

	mov	eax,PL0STK_SIZ	; Get the stack size

	mov	bx,DTE_4GB	; Get AGROUP data selector
	mov	fs,bx		; Address it
	assume	fs:AGROUP	; Tell the assembler about it

	mov	edi,LaTSS	; ES:EDI ==> TSS
	mov	AGROUP:[edi].TSS_SS0,DTE_PL0STK ; Save selector
	mov	AGROUP:[edi].TSS_ESP0,eax ; Start at top
	mov	AGROUP:[edi].TSS_IOMAP,(size TSS_STR) + 256/8 ; ...

; Setup common data in load module data area

	mov	ax,DTE_LOAD+1*(type DESC_STR) ; Get GXT's data selector
	mov	fs,ax		; Address the file's data segment
	assume	fs:nothing	; Tell the assembler about it

	mov	fs:[0].FILE_4GB,DTE_4GB ; Save descriptor
;;;;;;; mov	fs:[0].FILE_VID,DTE_VID ; ...
;;;;;;; mov	fs:[0].FILE_CR3,DTE_CR3 ; ...

; Call protected mode initialization code

	call	GXTINI.MD_IPROT ; Call it

	FICALL	RGROUP:GOREAL,DTE_CSR,<seg NGROUP> ; Enter RM
	assume	ds:RGROUP,es:RGROUP ; Tell the assembler about it
	assume	fs:PGROUP,gs:PGROUP ; Tell the assembler about it

; Reset segment registers

	REGREST <gs,fs,es,ds>	; Restore
	assume	ds:NGROUP,es:nothing ; Tell the assembler about it
	assume	fs:PGROUP,gs:RGROUP ; Tell the assembler about it

	lss	esp,RMSTK_FVEC	; Re-specify the stack
	assume	ss:nothing	; Tell the assembler about it

; Now that we're back in RM and on a valid stack, restore
; A20 to the state we found it.

	test	DEV_FLAG,@DEV_A20ON ; Wuzit enabled upon entry?
	jnz	short @F	; Jump if so

	call	FDEGATEA20	; Disable address line A20
	jnc	short @F	; Jump if no error

	SWATMAC ERR,RM		; Call our debugger
@@:
	call	ENABLE_IMR	; Enable the 8259 interrupt mask register

	call	DEVENABLE_NMI	; Enable NMI

	sti			; Allow interrupts

; Re-specify the GXT stack into extended memory

	push	dword ptr (64*1024) ; Get length of GXT low memory
	push	LaSTK		; Get base address
	push	DTE_SS		; Get DTE
	push	((mask $DTE_B) shl 8) or CPL0_DATA ; Get A/R byte and flags
	call	SET_DEVGDT	; Set the GDT entry

	push	dword ptr (64*1024) ; Get length of GXT low memory
	push	LaSTK		; Get base address
	push	DTE_SSB0	; Get DTE
	push	CPL0_DATA	; Get A/R byte and flags
	call	SET_DEVGDT	; Set the GDT entry

; Note we must not set the B-bit in the stack selector as
; we don't reset the A/R byte when we return to RM.

	clc			; Mark as successful
PROT_INIT_EXIT:
	popad			; Restore all EGP registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PROT_INIT endp			; End PROT_INIT procedure
	NPPROC	VIRT_INIT -- Initialize Virtual Mode
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Initialize virtual mode (actually real mode, but who's counting).

On exit:

CF	=	0 if all went well
	=	1 otherwise

|

; Does this file support the INIT_VIRT entry point?

	test	GXTINI.MD_ATTR,@MD_VER ; Does this one have init_virt?
	jz	short VIRT_INIT_EXIT ; Nope, just exit (note CF=0)

; Relocate the INIT_VIRT code

	pusha			; Save all GP registers
	REGSAVE <ds,es> 	; Save for a moment

	mov	cx,GXTINI.MD_VSIZE.ELO ; Get # bytes to move

	mov	ax,PRTAIL	; Get ending offset in RGROUP
	add	ax,16-1 	; Round up to para boundary
	shr	ax,4-0		; Convert from bytes to paras
	add	ax,RGRSEG	; Plus segment of (relocated) RGROUP
	mov	es,ax		; Address it
	assume	es:nothing	; Tell the assembler about it

	xchg	ax,GXTINI.MD_IVIRT.VSEG ; Get INIT_VIRT segment

	mov	ds,ax		; Address it
	assume	ds:nothing	; Tell the assembler about it

	xor	si,si		; Start at the beginning of the segment
	xor	di,di		; ...

S16 rep movs	<es:[di].LO,ds:[si].LO> ; Copy to lower memory

	REGREST <es,ds> 	; Restore
	assume	ds:NGROUP,es:PGROUP ; Tell the assembler about it
	popa			; Restore GP registers

; Call the file's INIT_VIRT routine

	call	GXTINI.MD_IVIRT ; Call it

	test	GXTINI.MD_ATTR,@MD_VMIE ; Did it fail?
	jz	short VIRT_INIT_EXIT ; Jump if not (note CF=0)

	stc			; Indicate it failed
VIRT_INIT_EXIT:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

VIRT_INIT endp			; End VIRT_INIT procedure
	NPPROC	SET_DEVGDT -- Set GDT Entry
	assume	ds:nothing,es:nothing,fs:nothing,gs:RGROUP,ss:nothing
COMMENT|

Set GDT entry
This routine can be called in RM/VM/PM.

|

SDG_STR struc

	dw	?		; Caller's BP
	dw	?		; ...	   IP
SDG_ARB db	?		; A/R byte
SDG_FLG db	?		; Flags
SDG_DTE dw	?		; DTE
SDG_BASE dd	?		; Base address
SDG_LEN dd	?		; Length

SDG_STR ends

	push	bp		; Prepare to address the stack
	mov	bp,sp		; Hello, Mr. Stack

	REGSAVE <eax,bx,ecx>	; Save registers

	mov	eax,[bp].SDG_BASE ; Get base address
	mov	bx,[bp].SDG_DTE ; Get the DTE #
	and	bx,not (mask $PL) ; Clear the RPL bits

	mov	ecx,[bp].SDG_LEN ; Get DTE length
	dec	ecx		; Convert from length to limit

	cmp	ecx,1024*1024	; Check against limit limit
	jb	short @F	; Jump if within range

	shr	ecx,12-0	; Convert from bytes to 4KB
	or	ecx,(mask $DTE_G) shl 16 ; Set G-bit
@@:
	mov	GXTGDT[bx].DESC_BASE01.EDD,eax
	rol	eax,8		; Rotate out the high-order byte
	mov	GXTGDT[bx].DESC_BASE3,al ; Save as base byte #3
;;;;;;; ror	eax,8		; Rotate back
	mov	GXTGDT[bx].DESC_SEGLM0,cx ; Save as data limit
	rol	ecx,16		; Swap high- and low-order words
	or	cl,[bp].SDG_FLG ; Include flags
	mov	GXTGDT[bx].DESC_SEGLM1,cl ; Save as data limit and flags

	mov	al,[bp].SDG_ARB ; Get the A/R byte
	mov	GXTGDT[bx].DESC_ACCESS,al ; Save in the GDT

	REGREST <ecx,bx,eax>	; Restore

	pop	bp		; Restore

	ret	4+4+2+1+1	; Return to caller, popping arguments

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SET_DEVGDT endp 		; End SET_DEVGDT procedure
	NPPROC	CHECK_PSWAT -- Check On Preceding Device SWAT
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Check on preceding device SWAT.

|

	pushad			; Save all EGP registers

; Attempt to open the device '386SWAT$'

	mov	al,@OPEN_R	; Code for read-only access
	DOSCALL @OPENF2,SWTNAME ; Attempt to open the device
	jnc	short CHECK_PSWAT1 ; Jump if present

; Attempt to open the device '386MAX$$'

	mov	al,@OPEN_R	; Code for read-only access
	DOSCALL @OPENF2,MAXNAME ; Attempt to open the device
	jc	near ptr CHECK_PSWAT_EXIT ; Jump if not present
CHECK_PSWAT1:
	mov	bx,ax		; Copy to handle register

	mov	al,0		; Code to get device info
	DOSCALL @IOCTL2 	; Return with DX = device info
	pushf			; Save CF from DOSCALL
	DOSCALL @CLOSF2 	; Close the file
	popf			; Restore
	jc	near ptr CHECK_PSWAT_EXIT ; Jump if IOCTL failed

	test	dx,@IOCTL_DEV	; Izit a device?
	jz	near ptr CHECK_PSWAT_EXIT ; Jump if not

; See if there's a debugging host present

	STROUT	VCPI_DPRES
	XVCPICALL @VCPI_DPRES	; Check on VCPI debugging host
				; Return with AH = 0 if present
				;	 (BH,BL) = version #
	cmp	ah,0		; Izit present?
	jne	near ptr CHECK_PSWAT_EXIT ; Jump if not

	mov	PSWAT_VER,bx	; BH = major, BL = minor

; Get SWAT's selectors if this version of SWAT supports it

	STROUT	VCPI_GETINFO
	mov	bl,@GETINFO_SELS ; Get SWAT's selectors
	XVCPICALL @VCPI_GETINFO ; Return SWAT internal information
				;	 CX = 4GB selector
				;	 DX = CR3 selector
	and	ah,ah		; Did it work?
	jne	short @F	; Jump if not

	mov	PSWAT_4GBSEL,cx ; Save for later use
	mov	PSWAT_CR3SEL,dx ; ...
@@:
	mov	edx,-1		; Get new linear address (/4KB)
	mov	ebx,-1		; Get the new CR3
	STROUT	VCPI_DBGLIN
	XVCPICALL @VCPI_DBGLIN	; Request SWAT services

; Initialize the preceding SWAT in our PM GDT

	push	es		; Save for a moment

	les	di,PGXTGDT	; ES:DI ==> GXT's GDT
	assume	es:RGROUP	; Tell the assembler about it

	mov	bx,DTE_PSWAT	; Get its code selector
	add	di,bx		; ES:DI ==> GDT entries for preceding device SWAT

	STROUT	VCPI_DBGINI2
	XVCPICALL @VCPI_DBGINI2 ; Initialize debugger interface with
				; with BX = code selector
				; and ES:DI ==> GDT entries to fill in
				; Return with BX:EDX ==> PM entry point
	cmp	PSWAT_VER,(5 shl 8) or 30 ; Izit version 5.30 or later?
	jb	short @F	; Jump if not

	push	seg DGROUP	; Get segment of PSWAT_...
	pop	es		; Address it
	assume	es:DGROUP	; Tell the assembler about it

	mov	PSWAT_FVEC.FSEL,bx ; Save for later use
	mov	PSWAT_FVEC.FOFF,edx ; ...
	mov	PSWAT2_FVEC.FOFF,edx ; ...
@@:
	pop	es		; Restore
	assume	es:nothing	; Tell the assembler about it

	cmp	ah,0		; Did it succeed?
	jne	short CHECK_PSWAT_ERR ; Jump if not

	DOSCALL @STROUT,MSG_PSWAT ; Tell 'em what we found

	or	DEVLOAD,@DEVL_PSWAT ; Mark as present

	jmp	short CHECK_PSWAT_EXIT ; Join common exit code


CHECK_PSWAT_ERR:
	SWATMAC ERR,RM		; Call our debugger
CHECK_PSWAT_EXIT:
	popad			; Restore all EGP registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_PSWAT endp		; End CHECK_PSWAT procedure
	NPPROC	INIT_PSWAT -- Initialize Preceding Device SWAT Data
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Initialize preceding device SWAT data.

|

	pushad			; Save all EGP registers
	REGSAVE <ds,es,fs,gs>	; Save registers

	test	DEV_FLAG,@DEV_VCPI ; Are we using VCPI services?
	jnz	near ptr INIT_PSWAT_VCPI ; Jump if so

	mov	es,SegIDT	; Get the segment of the temporary IDT
	assume	es:nothing	; Tell the assembler about it

	test	DEVLOAD,@DEVL_PSWAT ; Izit present?
	jz	near ptr INIT_PSWAT1 ; Jump if not

%	irp	XX,<@PSWATINTS>
	mov	bx,0&XX&h	; Interrupt #
	mov	di,0&XX&h*(type IDT_STR) ; ES:DI ==> this IDT entry
	XVCPICALL @VCPI_DBGIDT	; Initialize debugger IDT entry
				; Ignore error return
	endm			; IRP XX,<@PSWATINTS>
INIT_PSWAT1:

; Save DTE for source and destination limits

	movzx	eax,GXTIDTR.DTR_LIM ; Get IDT limit
	mov	MOVE_TAB.MDTE_DS.DESC_SEGLM0,ax ; Save as data limit
	mov	MOVE_TAB.MDTE_ES.DESC_SEGLM0,ax ; ...
	rol	eax,16		; Swap high- and low-order words
	mov	MOVE_TAB.MDTE_DS.DESC_SEGLM1,al ; Save size & flags
	mov	MOVE_TAB.MDTE_ES.DESC_SEGLM1,al ; ...
;;;;;;; ror	eax,16		; Swap back

; Save DTE for source base and A/R

	xor	eax,eax 	; Zero to use as dword
	mov	ax,es		; Get the IDT's segment
	shl	eax,4-0 	; Convert from paras to bytes
	mov	MOVE_TAB.MDTE_DS.DESC_BASE01.EDD,eax
	rol	eax,8		; Rotate out the high-order byte
	mov	MOVE_TAB.MDTE_DS.DESC_BASE3,al ; Save as base byte #3
;;;;;;; ror	eax,8		; Rotate back
	mov	MOVE_TAB.MDTE_DS.DESC_ACCESS,CPL0_DATA

; Save DTE for destination base and A/R

	mov	eax,GXTIDTR.DTR_BASE ; Get base address of the IDT
	mov	MOVE_TAB.MDTE_ES.DESC_BASE01.EDD,eax
	rol	eax,8		; Rotate out the high-order byte
	mov	MOVE_TAB.MDTE_ES.DESC_BASE3,al ; Save as base byte #3
;;;;;;; ror	eax,8		; Rotate back
	mov	MOVE_TAB.MDTE_ES.DESC_ACCESS,CPL0_DATA

; Copy the new PM IDT to extended memory

	movzx	ecx,GXTIDTR.DTR_LIM ; Get IDT limit
	inc	ecx		; Convert from limit to length
	shr	ecx,1-0 	; Convert from bytes to words

	push	seg NGROUP	; Get segment of MOVE_TAB
	pop	es		; Address it
	assume	es:NGROUP	; Tell the assembler about it

; For some inexplicable reason, WinME hooks this function and
; directs it to CLI/HLT!  If we detect WinME, we need to roll
; our own Enter PM.

	cmp	DOSVER,0800h	; Izit WinME?
	je	short INIT_PSWAT_WINME ; Jump if so

	lea	si,MOVE_TAB	; ES:SI ==> GDT
				; eCX = # words to move
	mov	ah,87h		; Function code to BIOS block move
	int	15h		; Request BIOS service

	cmp	ah,0		; Did it work?
	je	short INIT_PSWAT_EXIT ; Jump if so

	jmp	short INIT_PSWAT_ERR ; Join common error code


INIT_PSWAT_WINME:

; ECX	=	 # words in IDT

	call	EnterPM 	; Enter PM via CR0
	assume	ds:NGROUP	; Tell the assembler about it
	assume	es:AGROUP	; Tell the assembler about it
	jc	short INIT_PSWAT_ERR ; Jump if it failed

; Copy the IDT to extended memory

	movzx	esi,SegIDT	; Get the segment of the temporary IDT
	shl	esi,4-0 	; Convert from paras to bytes
	mov	edi,GXTIDTR.DTR_BASE ; Get base address of the IDT

    rep movs	AGROUP:[edi].ELO,AGROUP:[esi].ELO ; Copy it

	call	ExitPM		; Exit PM via CR0

	jmp	short INIT_PSWAT_EXIT ; Join common exit code


INIT_PSWAT_ERR:
	SWATMAC ERR,RM		; Call our debugger
INIT_PSWAT_VCPI:
;;;;;;; push	???		; Pass LA of PTEs
;;;;;;; call	INIT_PSWAT_PTE	; Initialize preceding SWAT's PTEs
INIT_PSWAT_EXIT:
	REGREST <gs,fs,es,ds>	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; ...
	popad			; Restore all EGP registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INIT_PSWAT endp 		; End INIT_PSWAT procedure
	NPPROC	EnterPM -- Enter PM Via CR0
	assume	ds:NGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Enter PM via CR0

On entry:

DS	=	seg NGROUP

On exit:

CF	=	0 if successful
	=	1 if not
DS	=	sel NGROUP
ES	=	sel AGROUP

Note that we don't set SS or the IDTR as we're depending upon
the Invisible Descriptor Cache for the former and there are no
interrupts for the latter.

|

	REGSAVE <eax>		; Save registers

; Setup code selector

	xor	eax,eax 	; Zero to use as dword
	mov	eax,cs		; Get code segment
	shl	eax,4-0 	; Convert from paras to bytes

	mov	EPM_GDT.DTE_CS.DESC_SEGLM0,0FFFFh ; Save limit
	mov	EPM_GDT.DTE_CS.DESC_BASE01.EDD,eax ; Save base bytes 0-2
	shr	eax,24		; Shift down high-order byte
	mov	EPM_GDT.DTE_CS.DESC_BASE3,al ; Save bas byte 3
	mov	EPM_GDT.DTE_CS.DESC_ACCESS,CPL0_CODE ; Save A/R byte
	mov	EPM_GDT.DTE_CS.DESC_SEGLM1,0 ; ...

; Setup data selector

	xor	eax,eax 	; Zero to use as dword
	mov	eax,ds		; Get data segment
	shl	eax,4-0 	; Convert from paras to bytes

	mov	EPM_GDT.DTE_DS.DESC_SEGLM0,0FFFFh ; Save limit
	mov	EPM_GDT.DTE_DS.DESC_BASE01.EDD,eax ; Save base bytes 0-2
	shr	eax,24		; Shift down high-order byte
	mov	EPM_GDT.DTE_DS.DESC_BASE3,al ; Save base byte 3
	mov	EPM_GDT.DTE_DS.DESC_ACCESS,CPL0_DATA ; Save A/R byte
	mov	EPM_GDT.DTE_DS.DESC_SEGLM1,0 ; ...

;;; ; Setup stack selector
;;;;;;;
;;;;;;; xor	eax,eax 	; Zero to use as dword
;;;;;;; mov	eax,ss		; Get stack segment
;;;;;;; shl	eax,4-0 	; Convert from paras to bytes
;;;;;;;
;;;;;;; mov	EPM_GDT.DTE_SS.DESC_SEGLM0,0FFFFh ; Save limit
;;;;;;; mov	EPM_GDT.DTE_SS.DESC_BASE01.EDD,eax ; Save base bytes 0-2
;;;;;;; shr	eax,24		; Shift down high-order byte
;;;;;;; mov	EPM_GDT.DTE_SS.DESC_BASE3,al ; Save base byte 3
;;;;;;; mov	EPM_GDT.DTE_SS.DESC_ACCESS,CPL0_DATA ; Save A/R byte
;;;;;;; mov	EPM_GDT.DTE_SS.DESC_SEGLM1,0 ; ...

; Setup all memory selector

	mov	EPM_GDT.DTE_ES.DESC_SEGLM0,0FFFFh ; Save limit
	mov	EPM_GDT.DTE_ES.DESC_BASE01.EDD,0 ; Save base bytes 0-2
	mov	EPM_GDT.DTE_ES.DESC_BASE3,0 ; Save base byte 3
	mov	EPM_GDT.DTE_ES.DESC_ACCESS,CPL0_DATA ; Save A/R byte
	mov	EPM_GDT.DTE_ES.DESC_SEGLM1,(mask $DTE_B) or (mask $DTE_G) or (mask $SEGLM1) ; ...

; Setup GDT DTR

	xor	eax,eax 	; Zero to use as dword
	mov	eax,ds		; Get data segment
	shl	eax,4-0 	; Convert from paras to bytes
	add	eax,offset ds:EPM_GDT ; Plus offset of GDT

	mov	EPM_GDT.DTE_GDT.DTR_LIM,(size DTE_STR)-1 ; Save GDT limit
	mov	EPM_GDT.DTE_GDT.DTR_BASE,eax ; Save GDT base

; Gate A20 ON unless it's already ON

	or	EPM_FLAG,@EPM_A20ON ; Assume it's ON
@@:
	call	FCHECKA20	; Izit enabled?
	jc	short @F	; Jump if so

	and	EPM_FLAG,not @EPM_A20ON ; Mark as A20 not enabled upon entry
	call	FGATEA20	; Gate A20 on

	jmp	short @B	; Jump if not


@@:
	cli			; Disable interrupts
	LGDTD	EPM_GDT.DTE_GDT.EDF ; Load the GDTR

; Note that we are dependent upon the Invisible Descriptor Cache
; for SS

	mov	eax,cr0 	; Get current CR0
	or	al,mask $PE	; Set Protect Enable bit
	mov	cr0,eax 	; Tell the CPU about it

	db	@OPCOD_JMPF	; Opcode for Far Jump Immediate
	dw	NGROUP:@F,DTE_CS ; Next instruction
@@:
	mov	ax,DTE_DS	; Get data selector
	mov	ds,ax		; Address it
	assume	ds:NGROUP	; Tell the assembler about it

	mov	ax,DTE_ES	; Get all memory selector
	mov	es,ax		; Address it
	assume	es:AGROUP	; Tell the assembler about it

;;;;;;; mov	ax,DTE_SS	; Get stack selector
;;;;;;; mov	ss,ax		; Address it
;;;;;;; assume	ss:nothing	; Tell the assembler about it
;;;;;;;
	clc			; Mark as successful

	REGREST <eax>		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

EnterPM endp			; End EnterPM procedure
	NPPROC	ExitPM -- Exit PM Via CR0
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Exit PM via CR0

On entry:

On exit:

|

	push	eax		; Save register

	mov	ax,DTE_DS	; Get 64KB limit selector
;;;;;;; mov	ds,ax		; Set to known value
	mov	es,ax		; ...
;;;;;;; mov	fs,ax		; ...
;;;;;;; mov	gs,ax		; ...
;;;;;;; mov	ss,ax		; ...
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

; Load base and limit of IDT for real mode
; Note that we do it here in case the FAR JMP below signals
; an error.

;;;;;;; LIDTD	RM_IDTRL	; Reset IDT to the table in local memory

; Exit protected mode

	mov	eax,cr0 	; Get current CR0
	and	al,not (mask $PE) ; Turn off PE bit
	mov	cr0,eax 	; Exit protected mode

;;;;;;; xor	eax,eax 	; Flush the
;;;;;;; mov	cr3,eax 	; ...TLB

; Jump to real mode code

	db	@OPCOD_JMPF	; Far jump immediate
	dw	NGROUP:@F,seg NGROUP ; Next instruction
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing ; Tell the assembler about it
@@:
	sti			; Enable interrupts

; Re-initialize segment registers

	mov	ax,seg NGROUP	; Get segment of NGROUP
	mov	ds,ax		; Get relocated RGROUP segment
	assume	ds:NGROUP	; Tell the assembler about it

	mov	es,ax		; Get relocated RGROUP segment
	assume	es:NGROUP	; Tell the assembler about it

	test	EPM_FLAG,@EPM_A20ON ; Wuzit enabled upon entry?
	jnz	short @F	; Jump if so

	call	FDEGATEA20	; Disable address line A20
	jnc	short @F	; Jump if no error

	SWATMAC ERR,RM		; Call our debugger
@@:
	pop	eax		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

ExitPM	endp			; End ExitPM procedure
	NPPROC	INIT_PSWAT_PTE -- Initialize Preceding SWAT PTEs
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Initialize preceding SWAT's PTEs

|

IPSWAT_STR struc

	dw	?		; Caller's BP
	dw	?		; ...	   IP
IPSWAT_LA dd	?		; LA of PTEs

IPSWAT_STR ends

	push	bp		; Prepare to address the stack
	mov	bp,sp		; Hello, Mr. Stack

	REGSAVE <eax,ecx,edi,es> ; Save registers

	test	DEV_FLAG,@DEV_VCPI ; Are we using VCPI services?
	jz	short INIT_PSWAT_PTE_EXIT ; Jump if not

	test	DEVLOAD,@DEVL_PSWAT ; Izit present?
	jz	short INIT_PSWAT_PTE_EXIT ; Jump if not

	cmp	PSWAT_VER,0400h ; Does it support fill PTE function?
	jb	short INIT_PSWAT_PTE_VCPIERR ; Jump if not

	mov	edi,LaPSWAT	; Get linear address of preceding SWAT (/4KB)

; Convert the linear address to offset into the PDIR

;;;;;;; movzx	eax,SegPTE	; Get segment of PTEs (/4KB)
;;;;;;; shl	eax,4-0 	; Convert from paras to bytes
;;;;;;;
	shr	edi,(12-2)-0	; Convert from bytes to 4KB in dwords
;;;;;;; add	edi,eax 	; Plus linear address of the PTEs (/4KB)
	add	edi,[bp].IPSWAT_LA ; Plus linear address of the PTEs (/4KB)

	xor	ax,ax		; A convenient zero
	mov	es,ax		; Address it
	assume	es:nothing	; Tell the assembler about it

; Request that SWAT fill in the PTEs

	mov	ecx,PSWAT_TSIZ	; Get total size of PM-resident PSWAT (/4KB)
	shr	ecx,12-0	; Convert from bytes to 4KB (# PTEs)
	XVCPICALL @VCPI_FILLPTE ; Fill in ECX PTEs into ES:EDI
				; Return with ECX = # PTEs not filled in
	or	ah,ah		; Did it work?
	jz	short INIT_PSWAT_PTE_EXIT ; Jump so
INIT_PSWAT_PTE_VCPIERR:
	and	DEVLOAD,not @DEVL_PSWAT ; Mark as not present
INIT_PSWAT_PTE_EXIT:
	REGREST <es,edi,ecx,eax> ; Restore
	assume	es:nothing	; Tell the assembler about it

	pop	bp		; Restore

	ret	4		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INIT_PSWAT_PTE endp		; End INIT_PSWAT_PTE procedure
	NPPROC	COPYLOW -- Copy RGROUP To Low Memory
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Copy RGROUP to low memory except for GXTINI.

|

	REGSAVE <eax,cx,si,di,es> ; Save registers

	mov	GOREAL_SEG,seg PGROUP ; Relocate
	mov	RGRSEG,seg PGROUP ; Relocate
	mov	RGRSEL,DTE_DS	; ...
	mov	VCPSTK_FVEC.FSEL,DTE_DS ; ...

; Relocate VCPI pointers

	xor	eax,eax 	; Zero to use as dword
	mov	ax,seg RGROUP	; Get old segment
	sub	ax,seg PGROUP	; Get new segment
	shl	eax,4-0 	; Convert from paras to bytes

	sub	LaVCPEPM,eax	; Relocate from RGROUP to PGROUP
	sub	VCPEPM.VCPEPM_GDTP,eax ; ...
	sub	VCPEPM.VCPEPM_IDTP,eax ; ...
	sub	GXTGDTR.DTR_BASE,eax ; ...

; Relocate the code selector to PGROUP

	movzx	eax,RGRSEG	; Get new segment of RGROUP
	shl	eax,4-0 	; Convert from paras to bytes

	push	dword ptr (64*1024) ; Get length of GXT low memory
	push	eax		; Get base address
	push	DTE_CS		; Get DTE
	push	CPL0_CODE	; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

; Relocate the data selector to PGROUP

	push	dword ptr (64*1024) ; Get length of GXT low memory
	push	eax		; Get base address
	push	DTE_DS		; Get DTE
	push	CPL0_DATA	; Get A/R byte
	call	SET_DEVGDT	; Set the GDT entry

	mov	es,RGRSEG	; Address it
	assume	es:PGROUP	; Tell the assembler about it

	lea	di,PGROUP:GXTINI [size MD_STR] ; Get next byte after GXTINI
	lea	si,RGROUP:RGXTINI[size MD_STR] ; ...		     RGXTINI

	mov	cx,PRTAIL	; Get last byte in RGROUP
	sub	cx,si		; Less starting offset to get length

S16 rep movs	<GXTINI.LO[di],RGXTINI.LO[si]> ; Copy to low memory

	mov	GXTINI.MD_DD.DD_STRA,offset RGROUP:DEV_STRA ; Note for next time
	mov	GXTINI.MD_DD.DD_INTR,offset RGROUP:DEV_INTR ; ...

; Tell SWAT we've relocated its symbols

	test	DEVLOAD,@DEVL_PSWAT ; Izit present?
	jz	short COPYLOW1	; Jump if not

	REGSAVE <bx,esi>	; Save for a moment

	mov	SYMTRAN.SYMTRAN_OSEL,ds ; Save as old selector/segment
;;;;;;; mov	SYMTRAN.SYMTRAN_OGRP,
;;	mov	SYMTRAN.SYMTRAN_NFLAG,
	mov	SYMTRAN.SYMTRAN_NSEL,es ; Save as new selector/segment
;;;;;;; mov	SYMTRAN.SYMTRAN_NBASE,
;;	mov	SYMTRAN.SYMTRAN_FLAGS,

	lea	esi,SYMTRAN	; DS:ESI ==> SYMTRAN_STR
	mov	bl,@DBGSYM_TRANS ; Function code to translate symbols
				; according to DS:ESI ==> SYMTRAN_STR
;;	XVCPICALL @VCPI_DBGSYM	; Request SWAT service

	REGREST <esi,bx>	; Restore
COPYLOW1:
	REGREST <es,di,si,cx,eax> ; Restore
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

COPYLOW endp			; End COPYLOW procedure
	NPPROC	GOPROT -- Enter Protected Mode
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Common routine to enter Protected Mode.

On entry:

ES:SI	==>	Global Descriptor Table

On exit:

CF	=	0 if all went well
	=	1 otherwise
AH	=	error code if CF=1
BX	=	clobbered
CX	=	clobbered by some BIOSs
FS	=	0
GS	=	0

IF	=	0
NMI	=	disabled

|

	call	DISABLE_IMR	; Disable the 8259 interrupt mask register
	call	DEVDISABLE_NMI	; Disable NMI

	mov	bx,PICBASE	; Initialize hardware interrupts here
	call	near ptr INT15PROT ; Enter protected mode
	assume	ds:PGROUP,es:RGROUP ; Tell the assembler about it

; Return in protected mode with interrupts and NMI disabled

GOPROT_CLC:
	xor	ax,ax		; A convenient zero

	mov	fs,ax		; Ensure valid
	assume	fs:nothing	; Tell the assembler about it

	mov	gs,ax		; Ensure valid
	assume	gs:nothing	; Tell the assembler about it

	clc			; Indicate we are in protected mode
GOPROT_EXIT:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

GOPROT	endp			; End GOPROT procedure
	FPPROC	INT15PROT -- Enter Protected Mode
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Enter protected mode on an XT that doesn't support
INT 15h BIOS function 89h.

On entry:

* Disable NMI
* Disable IMR

ES:SI	==>	descriptor table
BH	=	8259 origin for master
BL	=	8259 origin for slave

On exit:

* Clear the NT flag bit
* Disable interrupts
* Read and save A20 state
* Gate A20 on
* Setup DTE_BIOS entry
* Load GDTR
* Load IDTR
* Program the 8259
* Enter protected mode
* Setup segment registers
* Return to caller

|

; * Clear the NT flag bit

	pushf			; Copy flags
	pop	ax		; ...to register
	and	ax,not (mask $NT) ; NT = 0
	push	ax		; Copy register
	popf			; ...to flags

; * Disable NMI
;;;;;;;
;;;;;;; call	DEVDISABLE_NMI	; Disable NMI
;;;;;;;
; * Disable interrupts

	cli

; * Gate A20 on

	call	FGATEA20

; * Setup DTE_BIOS entry

	xor	eax,eax 	; Zero entire register
	mov	ax,cs		; Get current code segment
	shl	eax,4-0 	; Convert from paras to bytes

	mov	es:[si].DTE_BIOS.DESC_BASE01.EDD,eax
	rol	eax,8		; Rotate out the high-order byte
	mov	es:[si].DTE_BIOS.DESC_BASE3,al
	ror	eax,8		; Rotate back
	mov	es:[si].DTE_BIOS.DESC_SEGLM0,0FFFFh ; 64KB of code
	mov	es:[si].DTE_BIOS.DESC_SEGLM1,0
	mov	es:[si].DTE_BIOS.DESC_ACCESS,CPL0_CODE

; * Load GDTR from low memory

	LGDTD	es:[si].DTE_GDT.EDF

; * Load IDTR

	LIDTD	es:[si].DTE_IDT.EDF

; * Program the 8259

	test	DEV_FLAG,@DEV_XT ; Running on an XT?
	jz	short INT15PROT1 ; Not this time

; ICW1

	mov	al,13h		; ICW1 -- edge-triggered, single, ICW4 needed
	out	@ICR,al 	; Send to 8259
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

; ICW2

	mov	al,bh		; ICW2 -- start of 8259 vector
	out	@IMR,al 	; Send to 8259
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

; ICW3 (none because it's not in cascade mode)
; ICW4

	mov	al,09h		; ICW4 -- buffered slave, normal EOI, 8086 mode
	out	@IMR,al 	; Send to 8259
;;;;;;; jmp	short $+2	; I/O delay
;;;;;;; jmp	short $+2	; I/O delay
;;;;;;; jmp	short $+2	; I/O delay

	jmp	short INT15PROT2 ; Join common code

INT15PROT1:

; ICW1 -- master 8259

	mov	al,11h		; ICW1 -- edge-triggered, cascade, ICW4 needed

	test	DEV_FLAG,@DEV_MCA ; Izit an MCA-compatible machine?
	jz	short @F	; Not this time

	or	al,08h		; Mark as level-triggered
@@:
	mov	ah,al		; Save for later use
	out	@ICR,al 	; Send to master 8259
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

; ICW2 -- master 8259

	mov	al,bh		; ICW2 -- start of 8259 vector
	out	@IMR,al 	; Send to 8259
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

; ICW3 -- master 8259

	mov	al,@BIT2	; ICW3 -- master level 2
	out	@IMR,al 	; Send to master 8259
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

; ICW4 -- master 8259

	mov	al,01h		; ICW4 -- not SFNM, normal EOI, 8086 mode
	out	@IMR,al 	; Send to master 8259
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

; ICW1 -- slave 8259

	mov	al,ah		; ICW1 -- level/edge-triggered, cascade, ICW4 needed
	out	@ICR2,al	; Send to slave 8259
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

; ICW2 -- slave 8259

	mov	al,bl		; ICW2 -- start of slave 8259 vector
	out	@IMR2,al	; Send to slave 8259
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

; ICW3 -- slave 8259

	mov	al,02h		; ICW3 -- slave level 2
	out	@IMR2,al	; Send to slave 8259
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

; ICW34-- slave 8259

	mov	al,01h		; ICW4 -- not SFNM, normal EOI, 8086 mode
	out	@IMR2,al	; Send to slave 8259
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
INT15PROT2:

; * Disable IMR
;;;;;;;
;;;;;;; call	DISABLE_IMR	; Disable the 8259 interrupt mask register
;;;;;;;
; * Enter protected mode

	mov	eax,cr0 	; Get current CR0
	or	ax,mask $PE	; Mark as enabling protected mode
	mov	cr0,eax 	; Enter protected mode

	assume	ds:nothing,es:nothing ; Tell the assembler about it

	FIJMP	NGROUP:@F,DTE_BIOS ; Flush prefetch instruction queue
@@:

; * Setup segment registers

	mov	ax,DTE_DS	; Get DS selector
	mov	ds,ax
	assume	ds:PGROUP	; Tell the assembler about it

	mov	ax,DTE_ES	; Get DS selector
	mov	es,ax
	assume	es:RGROUP	; Tell the assembler about it

	xor	ax,ax		; A convenient zero

	mov	fs,ax		; Ensure valid
	assume	fs:nothing	; Tell the assembler about it

	mov	gs,ax		; Ensure valid
	assume	gs:nothing	; Tell the assembler about it

	mov	ax,DTE_SS	; Get SS selector
	mov	ss,ax
	assume	ss:nothing	; Tell the assembler about it

; * Return to caller

	pop	ax		; Get return offset
	push	DTE_CS		; Put return selector on stack
	push	ax		; Followed by offset

	xor	ax,ax		; Successful return code (AH=0, CF=0, ZF=1)

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT15PROT endp			; End INT15PROT procedure
	NPPROC	DISABLE_IMR -- Disable the 8259 Interrupt Mask Register
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Disable the 8259 interrupt mask register

This routine is called from real mode only.

|

	REGSAVE <ax>		; Save register

	in	al,@IMR 	; Get current value
	jmp	short $+2	; Drain PIQ
	jmp	short $+2	; Drain PIQ
	jmp	short $+2	; Drain PIQ

	mov	INTA01,al	; Save to restore later

	mov	al,0FFh 	; Disable all interrupts
	out	@IMR,al 	; Send to 8259

	test	DEV_FLAG,@DEV_XT ; Running on an XT?
	jnz	short DISABLE_IMR_EXIT ; Yes, so there's no slave controller

	jmp	short $+2	; Drain PIQ
	jmp	short $+2	; Drain PIQ
	jmp	short $+2	; Drain PIQ

	in	al,@IMR2	; Get current value
	jmp	short $+2	; Drain PIQ
	jmp	short $+2	; Drain PIQ
	jmp	short $+2	; Drain PIQ

	mov	INTB01,al	; Save to restore later

	mov	al,0FFh 	; Disable all interrupts
	out	@IMR2,al	; Reset in slave 8259
;;;;;;; jmp	short $+2	; Drain PIQ
;;;;;;; jmp	short $+2	; Drain PIQ
;;;;;;; jmp	short $+2	; Drain PIQ
DISABLE_IMR_EXIT:
	REGREST <ax>		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DISABLE_IMR endp		; End DISABLE_IMR procedure
	NPPROC	ENABLE_IMR -- Enable the 8259 Interrupt Mask Register
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Enable the 8259 interrupt mask register

|

	REGSAVE <ax>		; Save register

	mov	al,INTA01	; Get original master interrupt mask
	out	@IMR,al 	; Reset in master 8259

	test	DEV_FLAG,@DEV_XT ; Running on an XT?
	jnz	short ENABLE_IMR_EXIT ; Yes, so there's no slave controller

	jmp	short $+2	; Drain PIQ
;;;;;;; jmp	short $+2	; Drain PIQ
;;;;;;; jmp	short $+2	; Drain PIQ

	mov	al,INTB01	; Get original slave interrupt mask
	out	@IMR2,al	; Reset in slave 8259
;;;;;;; jmp	short $+2	; Drain PIQ
;;;;;;; jmp	short $+2	; Drain PIQ
;;;;;;; jmp	short $+2	; Drain PIQ
ENABLE_IMR_EXIT:
	REGREST <ax>		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

ENABLE_IMR endp 		; End ENABLE_IMR procedure
	NPPROC	DEVDISABLE_NMI -- Disable NMI
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Disable NMI

Note that this routine is bimodal.

|

	pushf			; Save flags
	cli			; Ensure interrupts disabled

	REGSAVE <ax,dx> 	; Save for a moment

; Disable NMI

	mov	dx,DEVNMIPORT	; Get NMI clear I/O port
	mov	al,DEVNMIDIS	; ...	  disable value
	call	OUTCMOS 	; Out to CMOS, conditional read

	REGREST <dx,ax> 	; Restore
	popf			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEVDISABLE_NMI endp		; End DEVDISABLE_NMI procedure
	NPPROC	DEVENABLE_NMI -- Enable NMI, Clear Parity Latches
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Enable NMI, clear parity latches.

Note that this routine is bimodal.

|

	pushf			; Save flags
	cli			; Ensure interrupts disabled

	REGSAVE <ax,dx> 	; Save for a moment

; Clear the parity latches

	call	CLR_PARITY	; Clear any parity errors

; Enable the NMI latch

	mov	dx,DEVNMIPORT	; Get NMI clear I/O port
	mov	al,DEVNMIENA	; ...	  enable value
	call	OUTCMOS 	; Out to CMOS, conditional read

	REGREST <dx,ax> 	; Restore
	popf			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEVENABLE_NMI endp		; End DEVENABLE_NMI procedure
	NPPROC	CLR_PARITY -- Clear Parity Latches
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Clear the parity latches

Note that this routine is bimodal.

|

	REGSAVE <ax>		; Save register

;;;;;;; test	DEV_FLAG,@DEV_XPARITY ; Was NOPARITY specified?
;;;;;;; jnz	short CLR_PARITY_EXIT ; Jump if so
;;;;;;;
	mov	ah,DEVNMIMASK	; Get parity mask
	in	al,@8255_B	; Get the parity latches
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

	or	al,ah		; Toggle parity check latches off
	out	@8255_B,al	; Tell the system about it
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

	xor	al,ah		; Toggle parity check latches on
	out	@8255_B,al	; Tell the system about it
;;;;;;; jmp	short $+2	; I/O delay
;;;;;;; jmp	short $+2	; I/O delay
;;;;;;; jmp	short $+2	; I/O delay

CLR_PARITY_EXIT:
	REGREST <ax>		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CLR_PARITY endp 		; End CLR_PARITY procedure
	NPPROC	SAVEINTS -- Save Interrupts
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:nothing,ss:nothing
COMMENT|

Read and save RM interrupt handlers

RGROUP code has NOT been copied down to the bottom of PGROUP.

|

	REGSAVE <eax,ds,es>	; Save registers

	mov	ax,seg RGROUP	; Get segment for RM_IDT
	mov	es,ax		; Address it
	assume	es:RGROUP	; Tell the assembler about it

	mov	ax,seg INTVEC	; Get INTVEC segment
	mov	ds,ax		; Address it
	assume	ds:INTVEC	; Tell the assembler about it

; Save our special interrupts in the RM IDT
; INTs 15h/2Fh are extra as we don't reflect them to PM.

%	irp	XX,<@HOOKINTS,15,2F> ; *FIXME*

	mov	eax,INT00_VEC[0&XX&h*(type INT00_VEC)] ; Get current handler
	mov	ORIGDEV&XX&_VEC,eax ; Save for later use

	endm			; IRP XX,<@HOOKINTS,15,2F>

	REGREST <es,ds,eax>	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SAVEINTS endp			; End SAVEINTS procedure
	NPPROC	SETINTS -- Setup Interrupts
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:nothing,ss:nothing
COMMENT|

Install RM interrupt handlers

RGROUP code has been copied down to the bottom of PGROUP.

|

	REGSAVE <eax,ds,es>	; Save registers

	mov	ax,seg PGROUP	; Get segment for RM_IDT and RGRSEG as relocated
	mov	es,ax		; Address it
	assume	es:RGROUP	; Tell the assembler about it (note lie)

	mov	ax,seg INTVEC	; Get INTVEC segment
	mov	ds,ax		; Address it
	assume	ds:INTVEC	; Tell the assembler about it

; Set our special interrupts in the RM IDT
; INTs 15h/2Fh are extra as we don't reflect them to PM.

%	irp	XX,<@HOOKINTS,15,2F> ; *FIXME*

	mov	ax,seg PGROUP	; Get segment to save
	shl	eax,16		; Shift to high-order word
	lea	ax,RMDEV&XX	; Get offset to save
	xchg	eax,INT00_VEC[0&XX&h*(type INT00_VEC)] ; Swap with old
	mov	PREVDEV&XX&_VEC,eax ; Save for later use

	endm			; IRP XX,<@HOOKINTS,15,2F>

	REGREST <es,ds,eax>	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SETINTS endp			; End SETINTS procedure

	align	16		; Fill tail with NOPs

NCODE	ends			; End NCODE segment

	MEND	DOSCMD		; End GXT_DRV module
