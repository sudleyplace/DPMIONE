;' $Header$
	title	DPMI08 -- Test SIGINT 08 In DPMI Client
	page	58,122
	name	DPMI08

COMMENT|		Module Specifications

Copyright:  (C) Copyright 2003 Qualitas, Inc.  All rights reserved.

Segmentation:  Group PGROUP:
	       Stack   segment STACK, byte-aligned, stack,  class 'prog'
	       Program segment CODE,  byte-aligned, public, class 'prog'
	       Tail    segment NCODE, byte-aligned, public, class 'prog'

Program derived from:  None.

Original code by:  Bob Smith, May, 2003.

Modifications by:  None.

|
.386p
.xlist
	include MASM.INC
	include ASCII.INC
	include DOS.INC
	include PTR.INC
	include DPMI.INC
	include 386.INC
.list

PGROUP	group	STACK,CODE,NDATA,NCODE,NDATAZ


; The following segment both positions class 'prog' segments lower in
; memory than others so the first byte of the resulting .COM file is
; in the CODE segment, as well as satisfies the LINKer's need to have
; a stack segment.

STACK	segment use16 byte stack 'prog' ; Start STACK segment
STACK	ends			; End STACK segment


CODE	segment use16 byte public 'prog' ; Start CODE segment
	assume	cs:PGROUP,ds:PGROUP
.xlist
	include PSP.INC 	; Define & skip over PSP area for .COM program
.list

INITIAL:
	jmp	COMSHELL	; Join initialization code

CODE	ends			; End CODE segment


NDATA	segment use16 para public 'prog' ; Start NDATA segment
	assume	ds:PGROUP

	public	DPMIDRV_VEC
DPMIDRV_VEC dd	 ?		; DPMI driver address

	public	OLDINT08_FVEC
OLDINT08_FVEC df ?		; Old INT 08h handler

	public	DPMI_HPDA,HPDA_SEG
DPMI_HPDA dw	 ?		; DPMI HPDA size in paras
HPDA_SEG  dw	 ?		; DPMI HPDA segment

	public	LCLSEL
LCLSEL	dw	?		; Local selector

	public	SegLim
SegLim	dd	?		; Segment Limit

	public	LCLSTK,LCLSTKZ
LCLSTK	dw	(4*1024) dup (?) ; Local stack
LCLSTKZ label	word

NDATA	ends			; End NDATA segment


NCODE	segment use16 byte public 'prog' ; Start NCODE segment
	assume	cs:PGROUP

	public	MSG_COPY
MSG_COPY db	'DPMI08   -- Version 1.00 ',CR,LF
	db	'   (C) Copyright 2003 Qualitas, Inc. '
	db	' All rights reserved.',CR,LF,EOS

	NPPROC	COMSHELL -- Shell to Create a .COM File
	assume	ds:PGROUP,es:PGROUP,fs:nothing,gs:nothing,ss:nothing

; Switch to local stack

	lea	sp,LCLSTKZ	; SS:SP ==> local stack

	DOSCALL @STROUT,MSG_COPY ; Display our copyright

; Check for PDMI host

	call	CheckDPMI	; See if we're running under a DPMI host
	jc	near ptr COMSHELL_EXIT ; Jump if not present

; Re-allocate our space downwards

	lea	bx,ZTAIL[16-1]	; Get next available byte offset
;;;;;;; and	bx,not (16-1)	; Round down
	shr	bx,4-0		; Convert from bytes to paras
	DOSCALL @MODMEM 	; Modify memory block at ES:0 to BX paras

; Allocate space for the HPDA

	mov	bx,DPMI_HPDA	; Get HPDA size in paras
	DOSCALL @GETMEM 	; Allocate BX paras
	jc	short COMSHELL_EXIT ; Jump if no memory

	mov	HPDA_SEG,ax	; Save for later use

; Enter PM through DPMI

	call	EnterPM 	; Enter PM through DPMI
	jc	short COMSHELL_EXIT ; Jump if not successful

; Test LSL on various DTEs

	mov	cx,1
	DPMICALL @DPMI_GETLDT	; Allocate a selector
;;;;;;; jc	short ???	; Jump on error

	mov	LCLSEL,ax	; Save for later use
	mov	es,ax		; Address it
	assume	es:nothing	; Tell the assembler about it

	mov	SegLim,1024*1024 ; Set to 1MB

	int	01h

	push	LCLSEL		; Pass the selector
	push	CPL0_DATA	; ...  Access Rights word
	PUSHD	0		; ...  Base Address
	push	SegLim		; ...  Segment Length
	call	SetDTE		; Set the DTE

	lsl	eax,LCLSEL.EDD	; Get the Segment Limit
	xor	ebx,ebx 	; A convenient zero
	mov	dl,es:[ebx].LO	; Reference it

	push	LCLSEL		; Pass the selector
	push	CPL0_STK	; ...  Access Rights word
	PUSHD	0		; ...  Base Address
	push	SegLim		; ...  Segment Length
	call	SetDTE		; Set the DTE

	lsl	eax,LCLSEL.EDD	; Get the Segment Limit
	xor	ebx,ebx 	; A convenient zero
	mov	dl,es:[ebx].LO	; Reference it






; Hook HW INT 08h

	mov	bl,08h		; Hook this one
	DPMICALL @DPMI_GETPMIV	; Get PM interrupt vector
				; Return with CX:EDX ==> old handler
	mov	OLDINT08_FVEC.FOFF,edx ; Save for later use
	mov	OLDINT08_FVEC.FSEL,cx ; ...

;;;;;;; mov	bl,08h		; Hook this one
	mov	cx,cs		; Get selector
	lea	edx,LCL_INT08	; CX:EDX ==> new handler
	DPMICALL @DPMI_SETPMIV	; Set PM interrupt vector to CX:EDX






	int	01h
COMSHELL_EXIT:
	DOSCALL @EXITRC 	; Return to DOS

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

COMSHELL endp			; End COMSHELL procedure
	NPPROC	SetDTE -- Set DTE
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Set DTE

On entry:

SS:ESP	==>	DTE_STR (after lclPROLOG)

On exit:

|

lclDTE_STR struc		; Local vars
lclDTE_STR ends


argDTE_STR struc		; Arguments

argDTE_LEN dd	?		; Segment Length
argDTE_BASE dd	?		; ...	  Base Address
argDTE_ARW dw	?		; ...	  Access Rights word
argDTE_SEL dw	?		; ...	  Selector

argDTE_STR ends


DTE_STR struc

if (type lclDTE_STR)
DTElcl	db	(type lclDTE_STR) dup (?) ; Local vars
endif
	dw	?		; Caller's BP
	dw	?		; ...	   IP
DTEarg	db	(type argDTE_STR) dup (?) ; Arguments

DTE_STR ends


	lclPROLOG <DTE_STR>	; Address local vars

	pusha			; Save registers

	mov	bx,[ebp].DTEarg.argDTE_SEL ; Get the selector
	mov	cx,[ebp].DTEarg.argDTE_BASE.EHI ; Get high-order word
	mov	dx,[ebp].DTEarg.argDTE_BASE.ELO ; ... low-...
	DPMICALL @DPMI_SSELBAS	; Set the Base Address to CX:DX

;;;;;;; mov	bx,[ebp].DTEarg.argDTE_SEL ; Get the selector
	mov	cx,[ebp].DTEarg.argDTE_ARW ; Get A/R word
	DPMICALL @DPMI_SSELARW	; Set the A/R word to CX

;;;;;;; mov	bx,[ebp].DTEarg.argDTE_SEL ; Get the selector
	mov	cx,[ebp].DTEarg.argDTE_LEN.EHI ; Get high-order word
	mov	dx,[ebp].DTEarg.argDTE_LEN.ELO ; ... low-...
	sub	dx,1		; Convert from length to limit
	sbb	cx,0		; ...
	DPMICALL @DPMI_SSELLIM	; Set the Limit to CX:DX

	popa			; Restore

	lclEPILOG <DTE_STR>	; Strip local vars and return

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SetDTE	endp		; End SetDTE procedure
	FPPROC	LCL_INT08 -- Local INT 08h Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Local INT 08h handler

|

	int	01h		; Call our debugger

	push	ebx		; Save for a moment

	xor	ebx,ebx 	; A convenient zero
	mov	ss:[ebx].LO,0	; Trigger a Stack Fault

	sub	esp,4*1024	; Make room on stack for local vars

	push	eax


	pop	eax

	add	esp,4*1024	; Strip stack back

	pop	ebx		; Restore

	jmp	OLDINT08_FVEC	; Continue with next handler

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

LCL_INT08 endp			; End LCL_INT08 procedure
	NPPROC	CheckDPMI -- Check On DPMI Services
	assume	ds:PGROUP,es:PGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Check on DPMI services

On exit:

CF	=	0 if successful
	=	1 if not

|

	pusha			; Save all GP registers
	push	es		; Save

	mov	ax,@DPMI_GPME	; Function code to detect DPMI servcices
	int	2Fh		; Request multiplexor services
	assume	es:nothing	; Tell the assembler about it
				; On return
				;   AX	  =   0 (if present)
				;   BX	  =   flags -- Bit 0: 1 = 32-bit apps supported
				;   CL	  =   CPU type (02 = 286, 03 = 386, 04 = 486, etc.)
				;   DH	  =   DPMI major version # (in decimal)
				;   DL	  =   ...  minor ...
				;   SI	  =   # paras in host private data area
				;   ES:DI ==> VM -> PM entry point
	and	ax,ax		; Izit present?
	stc			; Assume not
	jnz	short CheckDPMIExit ; Jump if not

	mov	DPMIDRV_VEC.VSEG,es ; Save for later use
	mov	DPMIDRV_VEC.VOFF,di ; ...
	mov	DPMI_HPDA,si	; ...

	clc			; Mark as successful
CheckDPMIExit:
	pop	es		; Restore
	assume	es:nothing	; Tell the assembler about it
	popa			; ...

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CheckDPMI endp			; End CHECK_DPMI procedure
	NPPROC	EnterPM -- Enter PM Through DPMI
	assume	ds:PGROUP,es:PGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Enter PM through DPMI

On exit:

CF	=	0 if successful
	=	1 if not

|

	pusha			; Save registers

; Enter PM through DPMI

	mov	es,HPDA_SEG	; Get segment of HPDA
	assume	es:nothing	; Tell the assembler about it

	mov	ax,@DPMI_EPM_32 ; We're a 32-bit client
	call	DPMIDRV_VEC	; Request entry into PM
	jc	short EnterPMExit ; Jump if something went wrong (note CF=1)
	assume	ds:PGROUP	; Tell the assembler about it
;;;;;;; assume	es:PSPGRP	; ...

	push	ds		; Get PGROUP segment/selector
	pop	es		; Address it
	assume	es:PGROUP	; Tell the assembler about it
EnterPMExit:
	popa			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

EnterPM endp			; End EnterPM procedure

NCODE	ends			; End NCODE segment


NDATAZ	segment use16 para public 'prog' ; Start NDATAZ segment
	assume	ds:PGROUP

	public	ZTAIL
ZTAIL	label	byte

NDATAZ	ends			; End NDATAZ segment

	MEND	INITIAL 	; End DPMI08 module
