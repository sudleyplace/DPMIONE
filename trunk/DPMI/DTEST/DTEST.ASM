;' $Header$
	title	DTEST -- Test DPMI DOS Allocate Call
	page	58,122
	name	DTEST

COMMENT|		Module Specifications

Copyright:  (C) Copyright 2004 Qualitas, Inc.  All rights reserved.

Segmentation:  Group PGROUP:
	       Stack   segment STACK, byte-aligned, stack,  class 'stack'
	       Program segment CODE,  byte-aligned, public, class 'code'
	       Data    segment DATA,  dword-aligned, public, class 'data'

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

PGROUP	group	CODE
DGROUP	group	DATA


DATA	segment use16 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	DPMI_VEC
DPMI_VEC dd	?		; Ptr to DPMI PM entry

	public	REGSIZE
REGSIZE dd	1000h		; Region size in bytes (arbitrary #)

	public	DDS
DDS	DDS_STR <>		; Virtual DMA Descriptor Structure

	public	DOS_SEL,DOS_SEG
DOS_SEL dw	?		; Selector of allocated DOS memory
DOS_SEG dw	?		; Segment ...

	public	MSG_DESC
MSG_DESC db	'This program enters PM via DPMI, allocates DOS memory,',CR,LF
	db	'  and displays the linear and physical addresses of the',CR,LF
	db	'  allocated DOS memory.',CR,LF,EOS

	public	MSG_DOS_SEG,MSG_PHYS
MSG_DOS_SEG db	'The segment # of the allocated DOS memory is %04X.',CR,LF
	db	'The linear   address is %08lX.',CR,LF,0
MSG_PHYS db	'The physical address is %08lX.',CR,LF,0

	public	MSG_ERR_NODPMI,MSG_ERR_GETMEM,MSG_ERR_EPM,MSG_ERR_GETALIAS,MSG_ERR_GETDMEM
MSG_ERR_NODPMI db '様> No DPMI host available.',CR,LF,EOS
MSG_ERR_GETMEM db '様> Unable to allocate memory for the HPDA.',CR,LF,EOS
MSG_ERR_EPM db	  '様> Unable to enter PM via DPMI services.',CR,LF,EOS
MSG_ERR_GETALIAS db '様> Unable to allocate alias selector via DPMI services.',CR,LF,EOS
MSG_ERR_GETDMEM db '様> Unable to allocate memory for the DOS buffer.',CR,LF,EOS

DATA	ends			; End DATA segment


CODE	segment use16 byte public 'code' ; Start CODE segment
	assume	cs:PGROUP,ds:PGROUP

	extrn	PRINTF16:near

	public	DATASEG
DATASEG dw	?		; DGROUP selector

	NPPROC	DTEST -- Test DPMI DOS Memory Allocate
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing

	mov	ax,seg DGROUP	; Get DGROUP segment
	mov	ds,ax		; Address it
	mov	es,ax		; ...
	assume	ds:DGROUP,es:DGROUP ; Tell the assembler about it

	DOSCALL @STROUT,MSG_DESC ; Display entry message

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
	jnz	near ptr DTEST_ERR_NODPMI ; Jump if not

	mov	DPMI_VEC.VSEG,es ; Save for later use
	mov	DPMI_VEC.VOFF,di ; ...

; Allocate memory for HPDA

	mov	bx,si		; Copy # paras needed for HPDA
	DOSCALL @GETMEM 	; Allocate memory for BX paras
				; Return with AX = segment
	jc	near ptr DTEST_ERR_GETMEM ; Jump if something went wrong

	mov	es,ax		; Address it
	assume	es:nothing	; Tell the assembler about it

; Enter PM via DPMI

	mov	ax,1		; 32-bit client
	call	DPMI_VEC	; Enter PM with ES:0 ==> HPDA
	assume	es:nothing	; Tell the assembler about it
	jc	near ptr DTEST_ERR_EPM ; Jump if something went wrong

; Because PRINTF16 doesn't know it's data selector, save it in DATASEG

	mov	bx,cs		; Copy code selector to get alias
	DPMICALL @DPMI_GETALIAS ; Get data alias of code selector
				; Return with AX = data selector
	jc	near ptr DTEST_ERR_GETALIAS ; Jump if something went wrong

	mov	es,ax		; Address it
	assume	es:PGROUP	; Tell the assembler about it

	mov	DATASEG,ds	; Save for later use

	mov	es,DATASEG	; Address DGROUP
	assume	es:DGROUP	; Tell the assembler about it

; Test Allocate DOS Memory call for one-to-one memory

	mov	ebx,REGSIZE	; Get arbitrary amount of memory (in bytes)
	shr	ebx,4-0 	; Convert from bytes to paras
	DPMICALL @DPMI_GETDMEM	; Allocate BX paras of DOS memory
				; Return with AX = segment #
				; ...	      DX = selector #
	jc	near ptr DTEST_ERR_GETDMEM ; Jump if something went wrong

	mov	DOS_SEL,dx	; Save for later use
	mov	DOS_SEG,ax	; ...

; Display the DOS segment #

	push	ds		; Get data selector
	pop	es		; Address it
	assume	es:DGROUP	; Tell the assembler about it

	xor	ebx,ebx 	; Zero to use as dword
	mov	bx,ax		; Copy segment #
	shl	ebx,4-0 	; Convert from paras to bytes

	push	ebx		; Pass the linear address
	push	ax		; ...  the DOS segment #
	push	ds		; ...  segment of format string
	push	offset DGROUP:MSG_DOS_SEG ; ... offset ...
	call	PRINTF16	; Printf it, return with AX = # chars printed
	add	sp,4+2+4	; Strip arguments from stack

; Get the physical address

	mov	eax,REGSIZE	; Get the region size in bytes
	mov	DDS.DDS_SIZE,eax ; Set region size
	movzx	eax,DOS_SEG	; Get DOS segment #
	shl	eax,4-0 	; Convert from paras to bytes
	mov	DDS.DDS_FVEC.FOFF,eax ; Set base address
	mov	DDS.DDS_FVEC.FSEL,0 ; ...
;;;;;;; mov	DDS.DDS_BID,0	; Set buffer ID

	lea	edi,DDS 	; ES:eDI ==> DDS
	xor	dx,dx		; No flags
	VDSCALL @VDS_LOCK	; Request VDS services

; Display the physical address

	push	DDS.DDS_POFF	; Pass the physical address
	push	ds		; ...  segment of format string
	push	offset DGROUP:MSG_PHYS ; ... offset ...
	call	PRINTF16	; Printf it, return with AX = # chars printed
	add	sp,4+4		; Strip arguments from stack

; Free the DOS memory

	mov	dx,DOS_SEL	; Get the selector #
	DPMICALL @DPMI_RELDMEM	; Release the memory
;;;;;;; jc	short ???	; Jump if something went wrong
DTEST_EXIT:
	xor	ax,ax		; Zero return code
	DOSCALL @EXITRC 	; Return to DOS


DTEST_ERR_NODPMI:
	DOSCALL @STROUT,MSG_ERR_NODPMI ; Display the error message

	jmp	DTEST_EXIT	; Join common exit code


DTEST_ERR_GETMEM:
	DOSCALL @STROUT,MSG_ERR_GETMEM ; Display the error message

	jmp	DTEST_EXIT	; Join common exit code



DTEST_ERR_EPM:
	DOSCALL @STROUT,MSG_ERR_EPM ; Display the error message

	jmp	DTEST_EXIT	; Join common exit code



DTEST_ERR_GETALIAS:
	DOSCALL @STROUT,MSG_ERR_GETALIAS ; Display the error message

	jmp	DTEST_EXIT	; Join common exit code



DTEST_ERR_GETDMEM:
	DOSCALL @STROUT,MSG_ERR_GETDMEM ; Display the error message

	jmp	DTEST_EXIT	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DTEST	endp			; End DTEST procedure

CODE	ends			; End CODE segment


STACK	segment use16 byte stack ; Start STACK segment

	public	LCLSTK
LCLSTK	dw	1024 dup (?)	; Local stack starts here (bottom)
LCLSTKZ label	word		; ...	      ends   ...  (top)

STACK	ends			; End STACK segment

	MEND	DTEST		; End DTEST module
