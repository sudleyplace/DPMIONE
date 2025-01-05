;' $Header$
	title	DPMI_ARG -- DPMI.LOD Argument Processing Routines
	page	58,122
	name	DPMI_ARG

COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1988-2004 Sudley Place Software.   

|
.386p
.xlist
	include MASM.INC
	include DOSCALL.INC
	include ASCII.INC
	include 386.INC
	include PTR.INC
	include INTVEC.INC
	include CPUFET2.INC

	include DPMI_COM.INC
	include DPMI_SEG.INC

	include QMAX_I31.INC		; Must precede QMAXDPMI.INC
	include QMAXDPMI.INC		; Must follow QMAX_I31.INC
.list

LINARG_MAC macro TXT,ACT
	local	LCL_TXT,LCL_LEN

XDATA	segment use16 dword public 'xdata' ; Start XDATA segment
	assume	ds:XGROUP

LCL_TXT db	TXT
LCL_LEN equ	$-LCL_TXT

XDATA	ends			; End XDATA segment


ASEGLEN segment use16 word public 'xdata' ; Start ASEGLEN segment
	assume	ds:XGROUP

	dw	LCL_LEN

ASEGLEN ends			; End ASEGLEN segment


ASEGTAB segment use16 word public 'xdata' ; Start ASEGTAB segment
	assume	ds:XGROUP

	dw	XGROUP:LCL_TXT

ASEGTAB ends			; End ASEGTAB segment


ASEGACT segment use16 word public 'xdata' ; Start ASEGACT segment
	assume	ds:XGROUP

	dw	XGROUP:ACT

ASEGACT ends			; End ASEGACT segment


XCODE	segment use16 para public 'xcode' ; Start XCODE segment
	assume	cs:XGROUP

	extrn	ACT:near

XCODE	ends			; End XCODE segment

	endm			; LINARG_MAC


XDATA	segment use16 dword public 'xdata' ; Start XDATA segment
	assume	ds:XGROUP

	public	@DPMI_ARG_XDATA
@DPMI_ARG_XDATA label byte	; Mark module start in .MAP file

	extrn	DPFEPTR:dword
	extrn	ARGPTR:dword
	extrn	PROF_CNT:word
	extrn	PROF_SEG:word

	extrn	MSG_UNK:byte
	extrn	MSG_UNKPRO:byte
	extrn	MSG_EOLERR:byte

	public	OLDINT24_VEC
OLDINT24_VEC dd ?		; Save area for old INT 24h handler

	public	LASTKEY
LASTKEY dw	?		; Offset of last keyword

	public	NUMBERS_LO
NUMBERS_LO db	'0123456789abcdef' ; Lowercase hex digits

	public	FILE_DPFE,PATHSTEM_LEN
FILE_DPFE db	128 dup (?)	; Buffer for file/path name
PATHSTEM_LEN dw 0		; Length of d:\pathname\ part of FILE_DPFE

	public	DRVPATH_END
DRVPATH_END dw	?		; Offset to end+1 of driver's "d:\path\"

XDATA	ends			; End XDATA segment


ASEGTAB segment use16 word public 'xdata' ; Start ASEGTAB segment
	assume	ds:XGROUP

	public	@DPMI_ARG_ASEGTAB
@DPMI_ARG_ASEGTAB label byte	; Mark module start in .MAP file

	public	LINARG_TAB
LINARG_TAB label word

ASEGTAB ends			; End ASEGTAB segment


ASEGLEN segment use16 word public 'xdata' ; Start ASEGLEN segment
	assume	ds:XGROUP

	public	@DPMI_ARG_ASEGLEN
@DPMI_ARG_ASEGLEN label byte	; Mark module start in .MAP file

	public	LINARG_LEN
LINARG_LEN label word

ASEGLEN ends			; End ASEGLEN segment


ASEGACT segment use16 word public 'xdata' ; Start ASEGACT segment
	assume	ds:XGROUP

	public	@DPMI_ARG_ASEGACT
@DPMI_ARG_ASEGACT label byte	; Mark module start in .MAP file

	public	LINARG_ACT
LINARG_ACT label word

ASEGACT ends			; End ASEGACT segment


; All keywords in this table *MUST* be in uppercase

	LINARG_MAC 'DEBUG=CLI',        FCN_DBGCLI
	LINARG_MAC 'DEBUG=DPMIERR',    FCN_DBGDPMIERR
	LINARG_MAC 'DEBUG=DPMILOCK',   FCN_DBGDPMILOCK
	LINARG_MAC 'DEBUG=DPMINEWSEL', FCN_DBGDPMINEWSEL
	LINARG_MAC 'DEBUG=DPMIPHYS',   FCN_DBGDPMIPHYS
	LINARG_MAC 'DEBUG=DPMISEL',    FCN_DBGDPMISEL
	LINARG_MAC 'DEBUG=DPMISPURNT', FCN_DBGDPMISPURNT
	LINARG_MAC 'DEBUG=DPMISTART',  FCN_DBGDPMISTART
	LINARG_MAC 'DEBUG=DPMISTD',    FCN_DBGDPMISTD
	LINARG_MAC 'DEBUG=DPMITERM',   FCN_DBGDPMITERM
	LINARG_MAC 'DEBUG=DPMIV100',   FCN_DBGDPMIV100
	LINARG_MAC 'DEBUG=NODEBUG',    FCN_DBGNODEBUG
	LINARG_MAC 'DEBUG=NOKEYB',     FCN_DBGNOKEYB
	LINARG_MAC 'DEBUG=NONMI',      FCN_DBGNONMI
	LINARG_MAC 'DPMIMEM',          FCN_DPMIMEM
	LINARG_MAC 'FORCELPM16',       FCN_FORCELPM16
	LINARG_MAC 'NOUMB',            FCN_NOUMB
	LINARG_MAC 'NOVCPI',           FCN_NOVCPI
	LINARG_MAC 'PRO',              FCN_PRO
	LINARG_MAC 'PROF',             FCN_PRO
	LINARG_MAC 'SHAREDMEM',        FCN_SHAREDMEM
	LINARG_MAC 'SWAPFILE',         FCN_SWAPFILE


ASEGTAB segment use16 word public 'xdata' ; Start ASEGTAB segment
	assume	ds:XGROUP

	public	NLINARGS
NLINARGS equ	($-LINARG_TAB)/(type LINARG_TAB) ; Its length

ASEGTAB ends			; End ASEGTAB segment


DATA16	segment use16 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	extrn	CPUFET_FLAG:dword
	extrn	DPMIOLDPM_SIZ:dword

DATA16	ends			; End DATA16 segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_ARG_DATA
@DPMI_ARG_DATA	label byte	; Mark module start in .MAP file

	extrn	DPMI_CPIHOOK:byte
	extrn	DPMI_CPFHOOK:byte
	extrn	DPMI_CVFHOOK:byte
	extrn	I31_FLAG:word
	extrn	DPMITYPE:byte
	extrn	LAST_DPMI_DS:word
	extrn	LAST_DPMI_ES:word
	extrn	LAST_DPMI_FS:word
	extrn	LAST_DPMI_GS:word

	extrn	PMINT_FVECS:fword
	extrn	PMINT_DVECS:dword
	extrn	PMFLT_FVECS:fword
	extrn	PMFLT_DVECS:dword
	extrn	VMFLT_FVECS:fword
	extrn	VMFLT_DVECS:dword

	extrn	DBGCTL:byte
	extrn	DBGSTA:byte
	extrn	DBGREGS:dword
	extrn	DBGDR7:dword

DATA	ends			; End DATA segment


XCODE	segment use16 para public 'xcode' ; Start XCODE segment
	assume	cs:XGROUP

	public	@DPMI_ARG_XCODE
@DPMI_ARG_XCODE:		; Mark module start in .MAP file

	NPPROC	CHECK_ARGS -- Check for Arguments
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Check for arguments

On exit:

CF	=	0 if all went OK
	=	1 otherwise

|

	pushad			; Save all EGP registers
	REGSAVE <ds,es,fs>	; Save segment register

	mov	ax,seg XGROUP	; Get XGROUP segment
	mov	es,ax		; Address it
	assume	es:XGROUP	; Tell the assembler about it

	mov	ax,seg DGROUP	; Get DGROUP segment
	mov	fs,ax		; Address it
	assume	fs:DGROUP	; Tell the assembler about it

	call	SET_PATHSTEM	; Save drive and path from device line

	xor	esi,esi 	; Zero to use as dword
	lds	si,ARGPTR	; DS:SI ==> command line
	assume	ds:nothing	; Tell the assembler about it

	call	STR_UPPER	; Convert the string to upper case
CHECK_ARGS_SRCH:		; Search for arguments
	call	SKIP_WHITE	; Skip over white space

	and	al,al		; Check for terminator
	jz	short CHECK_ARGS_CLC ; That's all folks

	cmp	al,';'          ; Check for terminator
	je	short CHECK_ARGS_CLC ; That's all folks

; Search for the argument text

	xor	bx,bx		; Zero index register
	mov	cx,NLINARGS	; # arguments to check
CHECK_ARGS_NEXT:
	mov	di,LINARG_TAB[bx] ; Get location of text

	REGSAVE <cx,si> 	; Save for a moment
	mov	cx,LINARG_LEN[bx] ; Get length
   repe cmps	ds:[si].LO,es:[di].LO ; Compare 'em
	REGREST <si,cx> 	; Restore
	jne	short CHECK_ARGS_NEXT1 ; Not this one

; Mark as found only if the next character is a valid separator

	mov	di,LINARG_LEN[bx] ; Get length of matching command
	add	di,si		; Add into starting offset
	mov	al,ds:[di]	; Get the next character

	cmp	al,'='          ; Check for valid separator
	je	short CHECK_ARGS_FOUND ; Jump if valid

	cmp	al,'/'          ; Check for valid separator
	je	short CHECK_ARGS_FOUND ; Jump if valid

	cmp	al,';'          ; Check for valid separator
	je	short CHECK_ARGS_FOUND ; Jump if valid

	cmp	al,' '          ; Check for blank or below
	jbe	short CHECK_ARGS_FOUND ; A match
CHECK_ARGS_NEXT1:
	add	bx,type LINARG_TAB ; Skip to next entry

	LOOPS	CHECK_ARGS_NEXT ; Jump if more entries to check

; Keyword not found

	lea	di,MSG_UNK	; ES:DI ==> error message
	call	DISP_UNK	; Display it along with unknown keyword at DS:SI

	stc			; Indicate an error occurred

	jmp	CHECK_ARGS_EXIT ; Join common exit code


CHECK_ARGS_FOUND:
	mov	LASTKEY,si	; Save starting offset
	add	si,LINARG_LEN[bx] ; Skip over the keyword

	call	LINARG_ACT[bx]	; Take appropriate action
	jc	short CHECK_ARGS_ERR ; Join common error code

	jmp	CHECK_ARGS_SRCH ; Join common tail code


CHECK_ARGS_CLC:

; Calculate and save the byte size of each old PM data area

	xor	eax,eax 	; Initial size

	test	CPUFET_FLAG,mask $CPUFET_VME ; Is VME supported?
	jz	short @F	; Jump if not

	add	eax,256/8	; Size of SIRBCUR table
@@:
	add	eax,(256/8)*(type DPMI_CPIHOOK)
	add	eax,( 32/8)*(type DPMI_CPFHOOK)
	add	eax,( 32/8)*(type DPMI_CVFHOOK)
	add	eax,256*(type PMINT_FVECS) + 256*(type PMINT_DVECS)
	add	eax, 32*(type PMFLT_FVECS) +  32*(type PMFLT_DVECS)
	add	eax, 32*(type VMFLT_FVECS) +  32*(type VMFLT_DVECS)
	add	eax,type LAST_DPMI_DS
	add	eax,type LAST_DPMI_ES
	add	eax,type LAST_DPMI_FS
	add	eax,type LAST_DPMI_GS
	add	eax,type I31_FLAG
	add	eax,type DPMITYPE
	add	eax,type DBGCTL
	add	eax,type DBGSTA
	add	eax,4*(type DBGREGS)
	add	eax,type DBGDR7
	add	eax,@DPMI_BOUND-1 ; Round up to next
	and	eax,not (@DPMI_BOUND-1) ; ... boundary for ALLOCMEM
	mov	DPMIOLDPM_SIZ,eax ; Save for later use

	clc			; Indicate all went well

	jmp	short CHECK_ARGS_EXIT ; Join common exit code


CHECK_ARGS_ERR:
	stc			; Indicate something went wrong
CHECK_ARGS_EXIT:
	REGREST <fs,es,ds>	; Restore
	assume	ds:XGROUP,es:nothing,fs:nothing ; Tell the assembler about it
	popad			; Restore all GP registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_ARGS endp 		; End CHECK_ARGS procedure
	NPPROC	DISP_UNK -- Display Message and Unknown Keyword
	assume	ds:nothing,es:XGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Display error message and unknown keyword.

On entry:

ES:DI	==>	error message to display
DS:SI	==>	unknown keyword

|

	push	di		; Pass address of error message
	call	DISP_MSG	; Tell 'em we couldn't decipher their handwriting

; Copy unmatched text to local buffer

	REGSAVE <ax,cx,si,di>	; Save registers

	mov	cx,30		; Maximum message length
@@:
	lods	ds:[si].LO	; Get next character
S16	stos	es:[di].LO	; Save in local buffer

	cmp	al,' '          ; Check for terminator
	jbe	short @F	; Jump if that's all folks

	LOOPS	@B		; Jump if more characters
@@:
	mov	ax,LF*256+CR	; Line terminators
S16	stos	es:[di].ELO	; Save in message

	mov	al,EOS		; String terminator
S16	stos	es:[di].ELO	; Save in message

	REGREST <di,si,cx,ax>	; Restore

	push	di		; Pass address of unknown keyword
	call	DISP_MSG	; Tell 'em we couldn't decipher their handwriting

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DISP_UNK endp			; End DISP_UNK procedure
	NPPROC	DISP_MSG -- Display Message
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DISP_MSG_STR struc

	dw	?		; Caller's BP
	dw	?		; Caller's return address
DISP_MSG_OFF dw ?		; Offset in CS of message

DISP_MSG_STR ends

	push	bp		; Prepare to address stack
	mov	bp,sp		; Hello, Mr. Stack

	REGSAVE <ax,dx,ds>	; Save registers

	push	cs		; Setup DS for @STROUT
	pop	ds
	assume	ds:XGROUP	; Tell the assembler about it

	mov	dx,[bp].DISP_MSG_OFF ; DS:DX ==> message

	DOSCALL @STROUT 	; Display the message

	REGREST <ds,dx,ax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	pop	bp		; Restore

	ret	2		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DISP_MSG endp			; End DISP_MSG procedure
	NPPROC	SKIP_WHITE -- Skip Over White Space
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Skip over white space

On entry:

DS:SI	==>	command line

On exit:

AL	=	non-white space character
DS:SI	==>	(updated)

|

@@:
	lods	ds:[si].LO	; Get next character

	cmp	al,' '          ; Izit white space?
	je	short @B	; Yes, go around again

	cmp	al,TAB		; Izit white space?
	je	short @B	; Yes, go around again

	dec	si		; Back off to previous character
	call	LOWERCASE	; Convert AL to lowercase

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SKIP_WHITE endp 		; End SKIP_WHITE procedure
	NPPROC	STR_UPPER -- Copnvert String to Uppercase
	assume	ds:nothing,es:XGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Convert ASCIIZ string at DS:SI to uppercase

|

	REGSAVE <ax,si> 	; Save registers
STR_UPPER_NEXT:
	lods	ds:[si].LO	; Get next character

	and	al,al		; Check for end-of-the-line
	jz	short STR_UPPER_EXIT ; Good guess

	cmp	al,EOF		; Check for end-of-the-file
	je	short STR_UPPER_EXIT ; Good guess

	cmp	al,'a'          ; Check against lower limit
	jb	short STR_UPPER_NEXT ; Jump if too small

	cmp	al,'z'          ; Check against upper limit
	ja	short STR_UPPER_NEXT ; Jump if too large

	add	al,'A'-'a'      ; Convert to uppercase

	mov	ds:[si-1],al	; Save back in text

	jmp	short STR_UPPER_NEXT ; Go around again


STR_UPPER_EXIT:
	REGREST <si,ax> 	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

STR_UPPER endp			; End STR_UPPER procedure
	NPPROC	PROC_PROFILE -- Process Profile Entries
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing

	pushad			; Save all EGP registers
	REGSAVE <ds,es> 	; Save segment registers

	mov	ds,PROF_SEG	; Get the segment
	assume	ds:nothing	; Tell the assembler about it

; Convert everything to common case

	xor	esi,esi 	; DS:ESI ==> start of profile

	mov	cx,PROF_CNT	; Get # bytes in profile
	or	cx,cx		; Izit empty?
	jz	near ptr PROC_PROF_EOF ; Jump if so

	call	STR_UPPER	; Convert the string to upper case

; Loop through the file contents

PROC_PROF_LINE:
	call	SKIP_WHITE	; Skip over more white space

	cmp	al,EOF		; Check for end of the file
	je	short PROC_PROF_EOF ; Skip over it

	cmp	al,';'          ; Check for end of the line
	je	short PROC_PROF_EOL ; Skip over it

	cmp	al,CR		; Check for end of the line
	je	short PROC_PROF_EOL ; Skip over it

	cmp	al,LF		; Check for end of the line
	je	short PROC_PROF_EOL ; Skip over it

; Search for the argument text

	xor	bx,bx		; Zero index register
	mov	cx,NLINARGS	; # arguments to check
PROCHK_ARGS_NEXT:
	mov	di,LINARG_TAB[bx] ; Get location of text

	REGSAVE <cx,si> 	; Save for a moment
	mov	cx,LINARG_LEN[bx] ; Get length
   repe cmps	ds:[si].LO,es:[di].LO ; Compare 'em
	REGREST <si,cx> 	; Restore
	jne	short PROCHK_ARGS_NEXT1 ; Not this one

; Mark as found only if the next character is a valid separator

	mov	di,LINARG_LEN[bx] ; Get length of matching command
	add	di,si		; Add into starting offset
	mov	al,ds:[di]	; Get the next character

	cmp	al,'='          ; Check for valid separator
	je	short PROCHK_ARGS_FOUND ; Jump if valid

	cmp	al,'/'          ; Check for valid separator
	je	short PROCHK_ARGS_FOUND ; Jump if valid

	cmp	al,';'          ; Check for valid separator
	je	short PROCHK_ARGS_FOUND ; Jump if valid

	cmp	al,' '          ; Check for blank or below
	jbe	short PROCHK_ARGS_FOUND ; A match
PROCHK_ARGS_NEXT1:
	add	bx,type LINARG_TAB ; Skip to next entry

	LOOPS	PROCHK_ARGS_NEXT ; Jump if more entries to check

; Keyword not found

	lea	di,MSG_UNKPRO	; Pass address of error message
	call	DISP_UNK	; Display it along with unknown keyword at DS:SI

	jmp	short PROC_PROF_ERR ; Call it an error


PROCHK_ARGS_FOUND:
	mov	LASTKEY,si	; Save starting offset
	add	si,LINARG_LEN[bx] ; Skip over the keyword

	call	LINARG_ACT[bx]	; Take appropriate action
	jc	short PROC_PROF_EXIT ; Jump if something went wrong (note CF=1)
PROC_PROF_EOL:
	call	SKIP_EOL	; Skip to end of line, allowing white space
	lea	dx,MSG_EOLERR	; In case something goes wrong
	jc	short PROC_PROF_ERRMSG ; Jump if error
PROC_PROF_EOL2:
	cmp	al,EOF		; Check for EOF
	je	short PROC_PROF_EOF ; Jump if EOF found

	cmp	si,PROF_CNT	; Check against current position
	jb	near ptr PROC_PROF_LINE ; Continue on
PROC_PROF_EOF:
	clc			; Indicate all went well

	jmp	short PROC_PROF_EXIT ; Join common exit code


PROC_PROF_ERRMSG:
	push	dx		; Pass address of error message
	call	DISP_MSG	; Tell 'em we couldn't decipher their handwriting
PROC_PROF_ERR:
	stc			; Indicate something went wrong
PROC_PROF_EXIT:
	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	popad			; Restore all GP registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PROC_PROFILE endp		; End PROC_PROFILE procedure
	NPPROC	SKIP_EOL -- Skip to End-of-line
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Skip to the end of the current line ensuring that there's at
most white space or comment text in the trailing portion.

An alternate entry point at SKIP_EOL_COMMENT unconditionally
skips to the end of the line.

|

	call	SKIP_WHITE	; Skip over white space
	inc	si		; Skip to next character

	cmp	al,EOF		; Check for EOF
	je	short SKIP_EOL_EXIT  ; Jump if so (note CF=0)

	cmp	al,';'          ; Check for comment marker
	je	short SKIP_EOL_COMMENT ; Jump if so

	cmp	al,CR		; Check for CR
	je	short SKIP_EOL_CRLF  ; Jump if so

	cmp	al,LF		; Check for LF
	je	short SKIP_EOL_CRLF  ; Jump if so

	stc			; Indicate something went wrong

	jmp	short SKIP_EOL_EXIT ; Join common exit code


	public	SKIP_EOL_COMMENT
SKIP_EOL_COMMENT:
	lods	ds:[si].LO	; Get next byte

	cmp	al,CR		; Izit end of the line?
	je	short SKIP_EOL_CRLF  ; Yes

	cmp	al,LF		; Izit end of the line?
	je	short SKIP_EOL_CRLF  ; Yes

	cmp	al,EOF		; Izit end of the file?
	je	short SKIP_EOL_EXIT  ; Yes (note CF=0)

	jmp	short SKIP_EOL_COMMENT ; Go around again


SKIP_EOL_CRLF:
	call	SKIP_WHITE	; Skip over white space
	inc	si		; Skip to next character

	cmp	al,EOF		; Check for EOF
	je	short SKIP_EOL_EXIT  ; Jump if so (note CF=0)

	cmp	al,CR		; Check for CR
	je	short SKIP_EOL_CRLF  ; Jump if so

	cmp	al,LF		; Check for LF
	je	short SKIP_EOL_CRLF  ; Jump if so

	clc			; Indicate all went OK
SKIP_EOL_EXIT:
	dec	si		; Back up to last byte

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SKIP_EOL endp			; End SKIP_EOL procedure
	FPPROC	LCL_INT24 -- Critical Error Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Critical error interrupt handler.

Cut back the stack to the INT 21h caller,
set CF, and RETF 2.

|

ARG_STR struc

	dw	?		; Caller's BP
ARG_CSIP dd	?		; Caller's return address
ARG_FLG dw	?		; Caller's flags

ARG_STR ends

	add	sp,3*2		; Strip off IP, CS, FL from INT 24h caller

	REGREST <ax,bx,cx,dx,si,di,bp,ds,es> ; Restore INT 21h caller's regs
	assume	ds:nothing,es:nothing ; Tell the assembler about it

; Set caller's flags (IF is the only significant one)

	push	bp		; Prepare to address the stack
	mov	bp,sp		; Hello, Mr. Stack
	push	[bp].ARG_FLG	; Put flags onto stack
	popf			; Restore caller's IF
	pop	bp		; Restore

	stc			; Ensure set to indicate error

	ret	2		; Return to INT 21h caller, popping flags

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

LCL_INT24 endp			 ; End LCL_INT24 procedure
	NPPROC	INST24 -- Install INT 24h Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

	REGSAVE <ax,ds,es>	; Save registers

	push	seg XGROUP	; Setup DS for data references
	pop	ds
	assume	ds:XGROUP	; Tell the assembler about it

	push	seg INTVEC	; Prepare to address segment zero
	pop	es		; Hello, segment zero
	assume	es:INTVEC	; Tell the assembler about it

	cli			; Nobody move

	lea	ax,LCL_INT24	; Get & set offset
	xchg	ax,INT00_VEC.VOFF[24h*type INT00_VEC]
	mov	OLDINT24_VEC.VOFF,ax ; Save to restore later

	mov	ax,cs		; Get & set segment
	xchg	ax,INT00_VEC.VSEG[24h*type INT00_VEC]
	mov	OLDINT24_VEC.VSEG,ax ; Save to restore later

	sti			; Allow interrupts

	REGREST <es,ds,ax>	; Restore
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INST24	endp			; End INST24 procedure
	NPPROC	REST24 -- Restore INT 24h Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

	REGSAVE <ax,ds,es>	; Save registers

	push	seg XGROUP	; Setup DS for data references
	pop	ds
	assume	ds:XGROUP	; Tell the assembler about it

	push	seg INTVEC	; Prepare to address segment zero
	pop	es		; Hello, segment zero
	assume	es:INTVEC	; Tell the assembler about it

	lds	ax,OLDINT24_VEC ; DS:AX ==> old interrupt handler
	assume	ds:nothing	; Tell the assembler about it

	cli			; Nobody move
	mov	INT00_VEC.VOFF[24h*type INT00_VEC],ax ; Restore offset
	mov	INT00_VEC.VSEG[24h*type INT00_VEC],ds ; ...	segment
	sti			; Allow interrupts

	REGREST <es,ds,ax>	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

REST24	endp			; End REST24 procedure
	NPPROC	IZITCOMMENT -- Check for a comment delimiter
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

If AL is a comment delimiter (; or *) return ZR, otherwise NZ.

|

	cmp	al,';'          ; Izit a comment delimiter?
	je	short @F	; Jump if so

	cmp	al,'*'          ; Izit other comment delimiter?
@@:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

IZITCOMMENT endp		; End IZITCOMMENT procedure
	NPPROC	IZITEOL -- Check For An End-Of-Line Character
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

If AL is an EOL character return ZF=1, otherwise ZF=0.

|

	cmp	al,0		; Izit EOL?
	je	short @F	; Jump if so

	cmp	al,LF		; Izit EOL?
	je	short @F	; Jump if so

	cmp	al,CR		; Izit EOL?
	je	short @F	; Jump if so

	cmp	al,EOF		; Izit EOL?
@@:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

IZITEOL endp			; End IZITEOL procedure
	NPPROC	LOWERCASE -- Convert AL to Lowercase
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

	cmp	al,40h		; Test for conversion of alpha to lower case
	jb	short LOWERCASE_EXIT ; Not this time

	or	al,20h		; Convert alpha to lower case
LOWERCASE_EXIT:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

LOWERCASE endp			; End LOWERCASE procedure
	NPPROC	UPPERCASE -- Convert AL to Uppercase
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

	cmp	al,'a'          ; Check lower limit
	jb	short UPPERCASE_EXIT ; Too small for us

	cmp	al,'z'          ; Check upper limit
	ja	short UPPERCASE_EXIT ; Too big for us

	add	al,'A'-'a'      ; Convert alpha to upper case
UPPERCASE_EXIT:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

UPPERCASE endp			; End UPPERCASE procedure
	NPPROC	BASE2BIN -- Convert From Specified Base to Binary
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

BASE2BIN -- Convert the number at DS:SI in base CX to binary.
The converted # is returned in AX.

On entry:

CX	=	number base
DS:SI	==>	input save area

On exit:

CF	=	1 if overflow
	=	0 if OK
AX	=	converted #

|

	REGSAVE <bx,dx,di,es>	; Save registers

	call	SKIP_WHITE	; Skip over more white space
	inc	si		; Skip over it

	xor	bx,bx		; Zero accumulator

	push	seg XGROUP	; Move NUMBERS_LO segment to ES for SCASB
	pop	es		; Address it
	assume	es:XGROUP	; Tell the assembler about it
BASE2BIN_LOOP:
	lea	di,NUMBERS_LO	; Get address of number conversion table
	push	cx		; Save number base (and table length)
  repne scas	NUMBERS_LO[di]	; Look for the character
	pop	cx		; Restore number base
	jne	short BASE2BIN_DONE ; Not one of ours

	sub	di,1+offset es:NUMBERS_LO ; Convert to origin 0
	mov	ax,bx		; Copy old to multiply by base

	mul	cx		; Shift over accumulated #
	jc	short BASE2BIN_OVF ; Jump if it overflowed

	mov	bx,ax		; Copy back
	add	bx,di		; Add in new #
	jc	short BASE2BIN_OVF ; Jump if out of range

	lods	ds:[si].LO	; Get next digit
	call	LOWERCASE	; Convert to lowercase

	jmp	BASE2BIN_LOOP	; Go around again


BASE2BIN_OVF:
	stc			; Indicate something went wrong

	jmp	short BASE2BIN_EXIT ; Join common exit code


BASE2BIN_DONE:
	dec	si		; Back off to previous character
	mov	ax,bx		; Place result in accumulator

	clc			; Indicate all went well
BASE2BIN_EXIT:
	REGREST <es,di,dx,bx>	; Restore registers
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller with number in AX

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

BASE2BIN endp			; End BASE2BIN procedure
	NPPROC	BASE2BIND -- Convert From Specified Base to Binary
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

BASE2BIND -- Convert the number at DS:SI in base CX to binary.
The converted # is returned in EAX.

On entry:

CX	=	number base
DS:SI	==>	input save area

On exit:

CF	=	1 if overflow
	=	0 if OK
EAX	=	converted #

|

	REGSAVE <ebx,ecx,edx,edi,es> ; Save registers

	call	SKIP_WHITE	; Skip over more white space
	inc	si		; Skip over it

	xor	ebx,ebx 	; Zero accumulator
	movzx	ecx,cx		; Zero to use as dword

	push	seg XGROUP	; Move NUMBERS_LO segment to ES for SCASB
	pop	es		; Address it
	assume	es:XGROUP	; Tell the assembler about it
BASE2BIND_LOOP:
	lea	edi,NUMBERS_LO	; Get address of number conversion table
	push	cx		; Save number base (and table length)
  repne scas	NUMBERS_LO[di]	; Look for the character
	pop	cx		; Restore number base
	jne	short BASE2BIND_DONE ; Not one of ours

	sub	di,1+offset es:NUMBERS_LO ; Convert to origin 0
	mov	eax,ebx 	; Copy old to multiply by base

	mul	ecx		; Shift over accumulated #
	jc	short BASE2BIND_OVF ; Jump if out of range

	mov	ebx,eax 	; Copy back
	add	ebx,edi 	; Add in new #
	jc	short BASE2BIND_OVF ; Jump if out of range

	lods	ds:[si].LO	; Get next digit
	call	LOWERCASE	; Convert to lowercase

	jmp	BASE2BIND_LOOP	; Go around again


BASE2BIND_OVF:
	stc			; Indicate something went wrong

	jmp	short BASE2BIND_EXIT ; Join common exit code


BASE2BIND_DONE:
	dec	si		; Back off to previous character
	mov	eax,ebx 	; Place result in accumulator

	clc			; Indicate all went well
BASE2BIND_EXIT:
	REGREST <es,edi,edx,ecx,ebx> ; Restore registers
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller with number in AX

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

BASE2BIND endp			; End BASE2BIND procedure
	NPPROC	SET_PATHSTEM -- Extract DPMI.LOD Directory
	assume	ds:nothing,es:XGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Copy the drive and path from device= to FILE_DPFE, make sure
it ends in \, and save the length of the prefix in PATHSTEM_LEN.

|

	pushad			; Save all EGP registers
	REGSAVE <ds>		; Save segment register

	cld			; String ops forwardly

; Copy path from device driver or environment

	lds	si,DPFEPTR	; DS:SI ==> d:\path\filename.ext
	assume	ds:nothing	; Tell the assembler about it

	REGSAVE <si,ds> 	; Save

	mov	DRVPATH_END,si	; Save as end+1 ...
SETPATH_INIT:			; Initial scan to skip over file name
	lods	ds:[si].LO	; Get the next byte

	cmp	al,CR		; If CR, end of line (?)
	je	short SETPATH_ENDNAME ; Use defaults

	cmp	al,LF		; If LF, end of line (?)
	je	short SETPATH_ENDNAME ; Use defaults

	cmp	al,' '          ; If a space, then we've reached the end
	je	short SETPATH_SRCH ; Yup

	and	al,al		; If zero, we've reached the end
	jz	short SETPATH_SRCH ; Yup

	cmp	al,':'          ; Check for drive separator
	je	short @F	; Jump if so

	cmp	al,'\'          ; Check for path separator
	je	short @F	; Jump if so

	cmp	al,'/'          ; Check for alternate path separator
	jne	short SETPATH_INIT ; Not as yet
@@:
	mov	DRVPATH_END,si	; Save as end+1 of driver path

	jmp	short SETPATH_INIT ; Not there as yet, continue looking


SETPATH_SRCH:
	dec	si		; Back off to end+1
;;;;;;; mov	DPFE_END,si	; Save as end+1 of d:\path\filename.ext
SETPATH_ENDNAME:
	REGREST <ds,si> 	; Restore
	assume	ds:nothing	; Tell the assembler

	lea	di,FILE_DPFE	; ES:DI ==> local buffer for filename

	cmp	ds:[si+1].LO,':' ; Is there a drive separator?
	je	short PROC_FF1	; Jump if so

	DOSCALL @GETDSK 	; Return with current drive # in AL (origin-0)
	add	al,'A'          ; Convert to uppercase ASCII

	stos	FILE_DPFE[di]	; Save in output area
	mov	al,':'          ; Get drive separator
	stos	FILE_DPFE[di]	; Save in output area

	jmp	short PROC_FF2	; Join common code


PROC_FF1:
	movs	FILE_DPFE[di].ELO,ds:[si].ELO ; Move drive letter and separator

PROC_FF2:
	cmp	ds:[si].LO,'\'  ; Is there a path separator?
	je	short PROC_FF3	; Jump if so

	mov	al,'\'          ; Get path separator
	stos	FILE_DPFE[di]	; Save in output area

	REGSAVE <si,ds> 	; Save for a moment

	mov	al,FILE_DPFE	; Get drive letter
	call	UPPERCASE	; Convert AL to uppercase
	sub	al,'A'-1        ; Convert to origin-1
	mov	dl,al		; Copy to @GETDIR register

	push	es		; Get destin segment
	pop	ds		; Address it
	assume	ds:nothing	; Tell the assembler about it
	mov	si,di		; DS:SI ==> output save area

	DOSCALL @GETDIR 	; Get current directory for drive DL to DS:SI

; Skip to the end of the output area

	mov	al,0		; String terminator
	mov	cx,-1		; We know it's there
  repne scas	FILE_DPFE[di]	; Search for it

	dec	di		; Back off to trailing zero

	cmp	es:[di-1].LO,'\' ; Is there a trailing path separator?
	je	short @F	; Jump if so

	mov	al,'\'          ; Get path separator
	stos	FILE_DPFE[di]	; Save in output area
@@:
	REGREST <ds,si> 	; Restore
	assume	ds:nothing	; Tell the assembler about it

PROC_FF3:
	mov	cx,DRVPATH_END	; Get offset to end+1 of path
	sub	cx,si		; Less start to get length
    rep movs	FILE_DPFE[di],ds:[si].LO ; Copy it

; FS:DI ==> end+1 of path.  Save length.

	sub	di,offset XGROUP:FILE_DPFE ; Get length of path
	mov	PATHSTEM_LEN,di ; Save
SET_PATHEXIT:
	REGREST <ds>		; Restore
	assume	ds:nothing	; Tell the assembler about it
	popad			; Restore all EGP registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SET_PATHSTEM endp		; End SET_PATHSTEM procedure
	align	16		; Fill with NOPs

XCODE	ends			; End XCODE segment

	MEND			; End DPMI_ARG module
