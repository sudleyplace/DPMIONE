;' $Header$
	title	GXT_MSC -- MMEXT Miscellaneous Routines
	page	58,122
	name	GXT_MSC

COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1988-2003 Qualitas, Inc.  All rights reserved.

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include PTR.INC
	include BITFLAGS.INC
	include ALLMEM.INC

	include GXT_COM.INC
	include GXT_SEG.INC
.list

DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

;;;	    public  HEXTABLE
;;; HEXTABLE db     '0123456789ABCDEF' ; Translate table
;;;
DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@GXT_MSC_PROG
@GXT_MSC_PROG:			; Mark module start in .MAP file

	NPPROC	GETBASE -- Get Selector Base
	assume	ds:nothing,es:AGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Get selector base

On exit:

EAX	=	selector base address

|

GETBASE_STR struc

	dd	?	    ; Caller's EBP
	dd	?	    ; ...      EIP
GETBASE_SEL dw	?,?	    ; Selector to get base

GETBASE_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <ebx>		; Save register

	movzx	ebx,[ebp].GETBASE_SEL ; Copy selector to index register
	and	ebx,not (mask $PL) ; Clear the Privilege Level bits

	btr	ebx,$TI 	; Test and reset the Table Index bit
	jnc	short GETBASE_GDT ; Jump if it's in the GDT

	sldt	ax		; Get local LDT selector

	push	eax		; Pass the selector
	call	GETBASE 	; Return with EAX = base address

	add	ebx,eax 	; AGROUP:EBX ==> DTE

	jmp	short GETBASE_COM ; Join common code


GETBASE_GDT:

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	add	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> GDT
	add	esp,size DTR_STR ; Strip
GETBASE_COM:
	mov	eax,AGROUP:[ebx].DESC_BASE01.EDD ; Get bytes 0-2
	rol	eax,8		; Shift out
	mov	al,AGROUP:[ebx].DESC_BASE3 ; Get byte 3
	ror	eax,8		; Shift back

	REGREST <ebx>		; Restore

	pop	ebp		; Restore

	ret	4		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

GETBASE endp			; End GETBASE procedure
;;;	    NPPROC  BIN2DWORD -- Convert Binary EAX to Hex at ES:EDI
;;;	    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;; COMMENT|
;;;
;;; On entry:
;;;
;;; ES:EDI  ==>     place to put high-order digit of output
;;;
;;; On exit:
;;;
;;; ES:EDI  ==>     (updated)
;;;
;;; |
;;;
;;;	    rol     eax,16	    ; Swap order
;;;	    call    BIN2WORD	    ; Convert AX to hex at ES:EDI
;;;
;;;	    rol     eax,16	    ; Swap order
;;;	    call    BIN2WORD	    ; Convert AX to hex at ES:EDI
;;;
;;;	    ret 		    ; Return to caller
;;;
;;;	    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;
;;; BIN2DWORD endp		    ; End BIN2DWORD procedure
;;;	    NPPROC  BIN2WORD -- Convert Binary AX to Hex at ES:EDI
;;;	    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;; COMMENT|
;;;
;;; On entry:
;;;
;;; ES:EDI  ==>     place to put high-order digit of output
;;;
;;; On exit:
;;;
;;; ES:EDI  ==>     (updated)
;;;
;;; |
;;;
;;;	    rol     ax,8	    ; Swap order
;;;	    call    BIN2BYTE	    ; Convert AL to hex at ES:EDI
;;;
;;;	    rol     ax,8	    ; Swap order
;;;	    call    BIN2BYTE	    ; Convert AL to hex at ES:EDI
;;;
;;;	    ret 		    ; Return to caller
;;;
;;;	    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;
;;; BIN2WORD endp		    ; End BIN2WORD procedure
;;;	    NPPROC  BIN2BYTE -- Convert Binary AL to Hex at ES:EDI
;;;	    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;; COMMENT|
;;;
;;; On entry:
;;;
;;; ES:EDI  ==>     place to put high-order digit of output
;;;
;;; On exit:
;;;
;;; ES:EDI  ==>     (updated)
;;;
;;; |
;;;
;;;	    rol     al,4	    ; Swap order
;;;	    call    BIN2DIGIT	    ; Convert low-order digit in AL to hex at ES:EDI
;;;
;;;	    rol     al,4	    ; Swap order
;;;	    call    BIN2DIGIT	    ; Convert low-order digit in AL to hex at ES:EDI
;;;
;;;	    ret 		    ; Return to caller
;;;
;;;	    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;
;;; BIN2BYTE endp		    ; End BIN2BYTE procedure
;;;	    NPPROC  BIN2DIGIT -- Convert Low-order Binary Digit in AL to Hex at ES:EDI
;;;	    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;; COMMENT|
;;;
;;; On entry:
;;;
;;; ES:EDI  ==>     place to put high-order digit of output
;;;
;;; On exit:
;;;
;;; ES:EDI  ==>     (updated)
;;;
;;; |
;;;
;;;	    REGSAVE <eax,ebx,ds>    ; Save registers
;;;
;;;	    SETDATA ds		    ; Set data selector into DS
;;;	    assume  ds:DGROUP	    ; Tell the assembler about it
;;;
;;;	    lea     ebx,HEXTABLE    ; DS:EBX ==> translate table
;;;	    and     al,@NIB0	    ; Isolate the digit
;;;	    xlat    HEXTABLE[ebx]   ; Translate the digit
;;; S32     stos    es:[edi].LO     ; Save in output
;;;
;;;	    REGREST <ds,ebx,eax>    ; Restore
;;;	    assume  ds:nothing	    ; Tell the assembler about it
;;;
;;;	    ret 		    ; Return to caller
;;;
;;;	    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;
;;; BIN2DIGIT endp		    ; End BIN2DIGIT procedure

PROG	ends			; End PROG segment


NCODE	segment use16 para public 'ncode' ; Start NCODE segment
	assume	cs:NGROUP,ds:NGROUP

	public	@GXT_MSC_NCODE
@GXT_MSC_NCODE: 		; Mark module start in .MAP file

	public	NUMBERS_HI
NUMBERS_HI db	'0123456789ABCDEF' ; Conversion table for BIN2BASE

	NPPROC	BIN2BASE -- Convert From Binary to Specified Base
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

BIN2BASE -- Convert the number in AX to ASCII in base CX storing the
low-order digit of the # at ES:DI.

On exit:

ES:DI	==>	next byte below last one stored

|

	REGSAVE <ax,dx,si,bp>  ; Save registers

	pushf			; Save all flags
	std			; Direction backwards for MOVSB

	mov	bp,5		; Go through this many times
BIN2BASE_LOOP:
	xor	dx,dx		; Zero high-order word for division
	div	cx		; Divide by number base
				; DX has remainder, AX has quotient
	lea	si,NUMBERS_HI	; Get address of table
	add	si,dx		; Offset into table

	movs	es:[di].LO,NUMBERS_HI[si] ; Store in result

	and	ax,ax		; Check for zero quotient
	jz	short BIN2BASE_EXIT ; That's all folks

	dec	bp		; Check for last digit
	jnz	short BIN2BASE_LOOP ; Not done yet
BIN2BASE_EXIT:
	popf			; Restore flags

	REGREST <bp,si,dx,ax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

BIN2BASE endp			; End BIN2BASE procedure

NCODE	ends			; End NCODE segment

	MEND			; End GXT_MSC module
