;' $Header$
	title	GXT_MAX -- MMEXT 386MAX Routines
	page	58,122
	name	GXT_MAX

COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1995-2003 Qualitas, Inc.  All rights reserved.

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include PTR.INC
	include DOSCALL.INC
	include IOCTL.INC

	include GXT_SEG.INC
	include EMM2CALL.INC
	include QMAX_CTL.INC
	include QMAX_DBG.INC
.list

NDATA	segment use16 dword public 'ndata' ; Start NDATA segment
	assume	ds:NGROUP

	public	@GXT_MAX_NDATA
@GXT_MAX_NDATA	label byte	; Mark module start in .MAP file

	extrn	MOVE_TAB:qword
	extrn	MAXNAME:byte

	public	QMAX_CR3,QMAX_PDE
QMAX_CR3 dd	?		; 386MAX's CR3
QMAX_PDE dd	?		; 1st PDE in 386MAX's CR3

	public	DEV_HNDL
DEV_HNDL dw	?		; Device handle

	public	INFO_CTL,INFO,INFOSIZE
	include QMAXINFO.INC
	db	?		; Force even alignment for INFO_STR
INFO_CTL db	?		; IOCTL type
INFO	INFO_STR <>
INFOSIZE equ	size INFO_STR
PORT67	equ	INFO.INFO_P67	; Equate for EMMOUT

NDATA	ends			; End NDATA segment


NCODE	segment use16 para public 'ncode' ; Start NCODE segment
	assume	cs:NGROUP

	public	@GXT_MAX_NCODE
@GXT_MAX_NCODE: 		; Mark module start in .MAP file

	NPPROC	INIT_MAX -- Initialize For 386MAX
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Initialize for 386MAX

On exit:

CF	=	0 if successful
	=	1 if not

|

	pushad			; Save registers
	REGSAVE <es,fs,gs>	; Save because you can never tell
				; what a BIOS might clobber

	mov	al,02h		; Access code for read/write
	DOSCALL @OPENF2,MAXNAME ; Attempt to open 386MAX device driver
	jc	near ptr INIT_MAX_ERR ; Jump if it failed

	mov	DEV_HNDL,ax	; Save for later use
	mov	bx,ax		; Copy to handle register

	mov	al,00h		; Function code to get device information
	DOSCALL @IOCTL2 	; Return in DX
	jc	near ptr INIT_MAX_ERR ; Something went wrong

	test	dx,@IOCTL_DEV	; Izit a device?
	jz	near ptr INIT_MAX_ERR ; No???

; Read 386MAX info structure

	call	INFO_READ	; Read in INFO structure

	DOSCALL @CLOSF2 	; Close it up

; Get the linear address of CR3

	mov	edx,cr3 	; Get current CR3
	EMMOUT	@EMM2_PHYS2LIN	; Request Phys to Lin, return in EDX

	mov	QMAX_CR3,edx	; Save for later use

	mov	MOVE_TAB.MDTE_DS.DESC_BASE01.EDD,edx
	rol	edx,8		; Rotate out the high-order byte
	mov	MOVE_TAB.MDTE_DS.DESC_BASE3,dl ; Save as base byte #3
;;;;;;; ror	edx,8		; Rotate back
	mov	MOVE_TAB.MDTE_DS.DESC_ACCESS,CPL0_DATA

	xor	eax,eax 	; A convenient zero
	mov	ax,seg NGROUP	; Get segment of QMAX_PDE
	shl	eax,4-0 	; Convert from paras to bytes
	lea	eax,QMAX_PDE[eax] ; Add in the offset

	mov	MOVE_TAB.MDTE_ES.DESC_BASE01.EDD,eax
	rol	eax,8		; Rotate out the high-order byte
	mov	MOVE_TAB.MDTE_ES.DESC_BASE3,al ; Save as base byte #3
;;;;;;; ror	eax,8		; Rotate back
	mov	MOVE_TAB.MDTE_ES.DESC_ACCESS,CPL0_DATA

	mov	ebx,0FFFFh	; Get segment limit
	mov	MOVE_TAB.MDTE_DS.DESC_SEGLM0,bx ; Save as data limit
	mov	MOVE_TAB.MDTE_ES.DESC_SEGLM0,bx ; ...
	rol	ebx,16		; Swap high- and low-order words
	mov	MOVE_TAB.MDTE_DS.DESC_SEGLM1,bl ; Save size & flags
	mov	MOVE_TAB.MDTE_ES.DESC_SEGLM1,bl ; ...

; Tell MAX we're moving from its data area

	mov	bx,@DBG_XR	; Get bit to test/flip

	test	INFO.INFO_DBG,bx ; Are XR moves allowed?
	jnz	short @F	; Jump if so

	EMMOUT	@EMM2_DBGFLAG	; Flip the bit
@@:
	mov	ax,seg NGROUP	; Get segment of MOVE_TAB
	mov	es,ax		; Address it
	assume	es:NGROUP	; Tell the assembler about it

	mov	cx,type QMAX_PDE ; Move this many bytes
	lea	si,MOVE_TAB	; ES:SI ==> GDT
	mov	ah,87h		; Function code to BIOS block move
	int	15h		; Request BIOS service

	cmp	ah,0		; Did it work?
	je	short INIT_MAX_EXIT ; Jump if so (note CF=0)
INIT_MAX_ERR:
	stc			; Mark as unsuccessful
INIT_MAX_EXIT:
	pushf			; Save CF

; Tell MAX we're no longer moving from its data area

	mov	bx,@DBG_XR	; Get bit to test/flip

	test	INFO.INFO_DBG,bx ; Are XR moves allowed?
	jnz	short @F	; Jump if so

	EMMOUT	@EMM2_DBGFLAG	; Flip the bit
@@:
	popf			; Restore CF

	REGREST <gs,fs,es>	; Restore
	assume	es:nothing,fs:nothing,gs:nothing ; Tell the assembler about it
	popad			; ...

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INIT_MAX endp			; End INIT_MAX procedure
	NPPROC	INFO_READ -- Read In INFO Structure
	assume	ds:NGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing

	REGSAVE <ax,bx,cx,dx>	; Save registers

	mov	al,02h		; Read from device
	mov	bx,DEV_HNDL	; Get device handle
	mov	cx,INFOSIZE	; CX = # bytes in INFO structure
	mov	INFO_CTL,@CTL_XFER ; Mark as INFO transfer
	DOSCALL @IOCTL2,INFO_CTL ; Get IOCTL info into INFO

	REGREST <dx,cx,bx,ax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INFO_READ endp			; End INFO_READ procedure

	align	16		; Fill tail with NOPs

NCODE	ends			; End NCODE segment

	MEND			; End GXT_MAX module
