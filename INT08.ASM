;' $Header:   P:/PVCS/MISC/EXTSIZE/EXTSIZE.ASV   1.3   05 Oct 1995 11:13:56   BOB  $
	title	INT08 -- Check For Register Corruption Over Timer Tick
	page	58,122
	name	INT08

COMMENT|		Module Specifications

Copyright:  (C) Copyright 2002 Sudley Place Software.

Segmentation:  Group PGROUP:
	       Stack   segment STACK, byte-aligned, stack,  class 'prog'
	       Program segment CODE,  byte-aligned, public, class 'prog'
	       Tail    segment NCODE, byte-aligned, public, class 'prog'

Program derived from:  None.

Original code by:  Bob Smith, April, 2002.

Modifications by:  None.

|
.386
.xlist
	include MASM.INC
	include DOS.INC
	include PTR.INC
.list

PGROUP	group	STACK,CODE,NCODE


; The following segment both positions class 'prog' segments lower in
; memory than others so the first byte of the resulting .COM file is
; in the CODE segment, as well as satisfies the LINKer's need to have
; a stack segment.

STACK	segment use16 dword stack 'prog' ; Start STACK segment
STACK	ends			; End STACK segment


CODE	segment use16 dword public 'prog' ; Start CODE segment
	assume	cs:PGROUP,ds:PGROUP
.xlist
	include PSP.INC 	; Define & skip over PSP area for .COM program
.list

INITIAL:
	jmp	INIT08		; Join initialization code

	align	4

	public	OLDINT08_VEC
OLDINT08_VEC dd ?		; Save area for pointer to old INT 08h handler

@KNOWN	equ	089ABCDEFh	; Known value

	public	KNOWN
KNOWN	dd	@KNOWN		; Known value

	FPPROC	INT08 -- Check For Register Corruption
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

	pushad			; Save all EGP registers

; Set EGP registers to known values

	mov	eax,KNOWN	; Be sure high-order word is set
	mov	ebx,eax 	; ...
	mov	ecx,eax 	; ...
	mov	edx,eax 	; ...
	mov	esi,eax 	; ...
	mov	edi,eax 	; ...
	mov	ebp,eax 	; ...

	pushf			; Simulate INT environment
	cli			; ...
	call	OLDINT08_VEC	; Call down to next handler

	irp	XX,<eax,ebx,ecx,edx,esi,edi,ebp>

	cmp	XX,KNOWN	; Check for corruption
	je	short @F	; Jump if not

	int	03h		; Call our debugger
@@:
	endm			; IRP

	popad			; Restore

	iret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT08	endp			; End INT08 procedure

CODE	ends			; End CODE segment


NCODE	segment use16 byte public 'prog' ; Start NCODE segment
	assume	cs:PGROUP

	public	ZTAIL
ZTAIL	label	byte

	public	MSG_COPY
MSG_COPY db	'INT08 -- Version 1.00 ',CR,LF
	db	'   (C) Copyright 2002 Sudley Place Software. '
	db	' .',CR,LF,EOS

	NPPROC	INIT08 -- Initialization Code For INT08
	assume	ds:PGROUP,es:PGROUP,fs:nothing,gs:nothing,ss:nothing

	DOSCALL @STROUT,MSG_COPY ; Display our copyright

; Hook interrupt and go resident

	push	es		; Save for a moment

	mov	al,08h		; Install this handler
	DOSCALL @GETINT 	; Return with ES:BX ==> old handler
	assume	es:nothing	; Tell the assembler about it

	mov	OLDINT08_VEC.VOFF,bx ; Save for later use
	mov	OLDINT08_VEC.VSEG,es ; ...

	pop	es		; Restore
	assume	es:PGROUP	; Tell the assembler about it

	mov	al,08h		; Install this handler
	DOSCALL @SETINT,INT08

	lea	dx,ZTAIL	; DS:DX ==> next address
	int	27h		; Return to DOS as resident program

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INIT08	endp			; End INIT08 procedure

NCODE	ends			; End NCODE segment

	MEND	INITIAL 	; End INT08 module
