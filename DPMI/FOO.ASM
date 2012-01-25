;' $Header$
	title	DTEST -- Test DPMI DOS Allocate Call
	page	58,122
	name	DTEST

COMMENT|		Module Specifications

Copyright:  (C) Copyright 2004 Qualitas, Inc.  All rights reserved.

Segmentation:  Group PGROUP:
	       Stack   segment STACK, byte-aligned, stack,  class 'prog'
	       Program segment CODE,  byte-aligned, public, class 'prog'
	       Tail    segment NCODE, byte-aligned, public, class 'prog'

Program derived from:  None.

Original code by:  Bob Smith, April, 2004.

Modifications by:  None.

|
.386
.xlist
	include MASM.INC
	include ASCII.INC
	include DOS.INC
	include PTR.INC
	include DPMI.INC
	include VDS.INC
.list

PGROUP	group	STACK,CODE,NCODE,NDATA,ZDATA


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
	jmp	DTEST		; Join initialization code

CODE	ends			; End CODE segment


NCODE	segment use16 byte public 'prog' ; Start NCODE segment
NCODE	ends			; End NCODE segment


NDATA	segment use16 dword public 'prog' ; Start NDATA segment
	assume	ds:PGROUP

	public	DPMI_VEC
DPMI_VEC dd	?		; Ptr to DPMI PM entry

	public	DOSSEL
DOSSEL	dw	?		; Selector of allocated DOS memory

	public	LCLSTK
LCLSTK	dw	1024 dup (?)	; Local stack starts here (bottom)
LCLSTKZ label	word		; ...	      ends   ...  (top)

NDATA	ends			; End NDATA segment


ZDATA	segment use16 para public 'prog' ; Start ZDATA segment
	assume	ds:PGROUP

	public	ZTAIL
ZTAIL	label	byte		; End of our program

ZDATA	ends			; End ZDATA segment


NCODE	segment use16 byte public 'prog' ; Start NCODE segment
	assume	cs:PGROUP

	public	MSG_COPY
MSG_COPY db	'DTEST    -- Version 1.00 ',CR,LF
	db	'   (C) Copyright 2004 Qualitas, Inc. '
	db	' All rights reserved.',CR,LF,EOS

	NPPROC	DTEST -- Test DPMI DOS Memory Allocate
	assume	ds:PGROUP,es:PGROUP,fs:nothing,gs:nothing,ss:nothing

	lea	sp,LCLSTKZ	; SS:SP ==> local stack

; Reduce our footprint

	lea	bx,ZTAIL	; Get offset of end of program
	shr	bx,4-0		; Convert from bytes to paras
	DOSCALL @MODMEM 	; Modify DOS memory at ES:0 to BX paras
	jc	short DTEST_ERR_MODMEM ; Jump if something went wrong

	DOSCALL @STROUT,MSG_COPY ; Display our copyright

; Test for DPMI presence

	mov	ax,@DPMI_GPME	; Code to test for presence
	int	2Fh		; Request multiplexor service
				; Return with AX = 0 if present
				; ...	      BX = flags
				; ...	      CL = CPU type
				; ...	      DX = DPMI version
				; ...	      SI = # paras needed by HPDA
				; ...	      ES:DI ==> PM entry point
	and	ax,ax		; Did it succeed?
	jnz	short DTEST_EXIT ; Jump if not

	mov	DPMI_VEC.VSEG,es ; Save for later use
	mov	DPMI_VEC.VOFF,di ; ...

; Allocate memory for HPDA

	mov	bx,si		; Copy # paras needed for HPDA
	DOSCALL @GETMEM 	; Allocate memory for BX paras
				; Return with AX = segment
	jc	short DTEST_ERR_GETMEM ; Jump if something went wrong

	mov	es,ax		; Address it
	assume	es:nothing	; Tell the assembler about it

; Enter PM via DPMI

	mov	ax,1		; 32-bit client
	call	DPMI_VEC	; Enter PM with ES:0 ==> HPDA
	jc	short DTEST_ERR_RM2PM ; Jump if something went wrong

; Test Allocate DOS Memory call for one-to-one memory

	mov	bx,100h 	; Get arbitrary amount of memory
	DPMICALL @DPMI_GETDMEM	; Allocate BX paras of DOS memory
				; Return with AX = segment #
				; ...	      DX = selector #
	jc	short DTEST_ERR_GETDMEM ; Jump if something went wrong

	mov	DOSSEL,dx	; Save for later use

; Ensure that the memory is one-to-one linear-to-physical









; Free the DOS memory

	mov	dx,DOSSEL	; Get the selector #
	DPMICALL @DPMI_RELDMEM	; Release the memory
;;;;;;; jc	short ???	; Jump if something went wrong
DTEST_EXIT:
	xor	ax,ax		; Zero return code
	DOSCALL @EXITRC 	; Return to DOS


DTEST_ERR_MODMEM:



DTEST_ERR_GETMEM:



DTEST_ERR_RM2PM:



DTEST_ERR_GETDMEM:






	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DTEST	endp			; End DTEST procedure

NCODE	ends			; End NCODE segment

	MEND	INITIAL 	; End DTEST module
