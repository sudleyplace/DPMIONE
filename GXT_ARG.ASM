;' $Header$
	title	GXT_ARG -- MMEXT Argument Processing Routines
	page	58,122
	name	GXT_ARG

COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1988-2003 Sudley Place Software.

|
.386p
.xlist
	include MASM.INC
	include DOSCALL.INC
	include ASCII.INC
	include 386.INC
	include PTR.INC
	include INTVEC.INC
	include DPMI.INC

	include GXT_PRG.INC
	include GXT_SEG.INC
.list

LINARG_MAC macro TXT,ACT
	local	LCL_TXT,LCL_LEN

NDATA	segment use16 dword public 'ndata' ; Start NDATA segment
	assume	ds:NGROUP

LCL_TXT db	TXT
LCL_LEN equ	$-LCL_TXT

NDATA	ends			; End NDATA segment


ASEGLEN segment use16 word public 'ndata' ; Start ASEGLEN segment
	assume	ds:NGROUP

	dw	LCL_LEN

ASEGLEN ends			; End ASEGLEN segment


ASEGTAB segment use16 word public 'ndata' ; Start ASEGTAB segment
	assume	ds:NGROUP

	dw	NGROUP:LCL_TXT

ASEGTAB ends			; End ASEGTAB segment


ASEGACT segment use16 word public 'ndata' ; Start ASEGACT segment
	assume	ds:NGROUP

	dw	NGROUP:ACT

ASEGACT ends			; End ASEGACT segment


NCODE	segment use16 para public 'ncode' ; Start NCODE segment
	assume	cs:NGROUP

	extrn	ACT:near

NCODE	ends			; End NCODE segment

	endm			; LINARG_MAC



RCODE	segment use16 para public 'rcode' ; Start RCODE segment
	assume	cs:RGROUP

	public	@GXT_ARG_RCODE
@GXT_ARG_RCODE	label byte	; Mark module start in .MAP file

	public	VSAPI_VEC
VSAPI_VEC dd	?		; Ptr to VSAPI Entry Point

RCODE	ends			; End RCODE segment


NDATA	segment use16 dword public 'ndata' ; Start NDATA segment
	assume	ds:NGROUP

	public	@GXT_ARG_NDATA
@GXT_ARG_NDATA	label byte	; Mark module start in .MAP file

	extrn	ARGPTR:dword
	extrn	PROF_CNT:word
	extrn	PROF_SEG:word
	extrn	DRV_ERRMSG:word

	public	OLDINT24_VEC
OLDINT24_VEC dd ?		; Save area for old INT 24h handler

	public	LASTKEY
LASTKEY dw	?		; Offset of last keyword

	public	MSG_SEP,MSG_UNK,MSG_UNKLST,MSG_UNKPRO,MSG_EOLERR,MSG_OVF
	public	MSG_DUPINST
MSG_SEP db	BEL,'様> Missing separator.',CR,LF,EOS
MSG_UNK db	BEL,'様> Unknown keyword:  ',EOS
MSG_UNKLST db	BEL,'様> Unknown list elment:  ',EOS
MSG_UNKPRO db	BEL,'様> Unknown keyword in profile:  ',EOS
MSG_EOLERR db	BEL,'様> Invalid line ending in profile.',CR,LF,EOS
MSG_OVF db	BEL,'様> Value too large:  ',EOS
MSG_DUPINST db	BEL,'様> ',@PROGNAME,' already installed.',CR,LF,EOS

	public	VSAPI_STR2
VSAPI_STR2 db	@VSAPINAME,0	; Signature

NDATA	ends			; End NDATA segment


ASEGTAB segment use16 word public 'ndata' ; Start ASEGTAB segment
	assume	ds:NGROUP

	public	@GXT_ARG_ASEGTAB
@GXT_ARG_ASEGTAB label byte	; Mark module start in .MAP file

	public	LINARG_TAB
LINARG_TAB label word

ASEGTAB ends			; End ASEGTAB segment


ASEGLEN segment use16 word public 'ndata' ; Start ASEGLEN segment
	assume	ds:NGROUP

	public	@GXT_ARG_ASEGLEN
@GXT_ARG_ASEGLEN label byte	; Mark module start in .MAP file

	public	LINARG_LEN
LINARG_LEN label word

ASEGLEN ends			; End ASEGLEN segment


ASEGACT segment use16 word public 'ndata' ; Start ASEGACT segment
	assume	ds:NGROUP

	public	@GXT_ARG_ASEGACT
@GXT_ARG_ASEGACT label byte	; Mark module start in .MAP file

	public	LINARG_ACT
LINARG_ACT label word

ASEGACT ends			; End ASEGACT segment


; All keywords in this table *MUST* be in uppercase

	LINARG_MAC 'DEBUG=NSWAT',      FCN_DBGNSWAT
	LINARG_MAC 'DEBUG=PSWAT',      FCN_DBGPSWAT
	LINARG_MAC 'DEBUG=QSWAT',      FCN_DBGQSWAT     ; (Default)
;;;;;;; LINARG_MAC 'INTRUDE',          FCN_INTRUDE      ; Obsolete
	LINARG_MAC 'LOAD',             FCN_LOAD
	LINARG_MAC 'PRO',              FCN_PRO
	LINARG_MAC 'PROF',             FCN_PRO
	LINARG_MAC 'UNLOAD',           FCN_UNINSTALL
	LINARG_MAC 'UNINST',           FCN_UNINSTALL
	LINARG_MAC 'UNINSTALL',        FCN_UNINSTALL
	LINARG_MAC 'VCPIONLY',         FCN_VCPIONLY


ASEGTAB segment use16 word public 'ndata' ; Start ASEGTAB segment
	assume	ds:NGROUP

	public	NLINARGS
NLINARGS equ	($-LINARG_TAB)/(type LINARG_TAB) ; Its length

ASEGTAB ends			; End ASEGTAB segment


NCODE	segment use16 para public 'ncode' ; Start NCODE segment
	assume	cs:NGROUP

	public	@GXT_ARG_NCODE
@GXT_ARG_NCODE: 		; Mark module start in .MAP file

;;;;;;; extrn	FCN_INTRUDE:near

	NPPROC	CHECK_ARGS -- Check for Arguments
	assume	ds:NGROUP,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

Check for arguments

On exit:

CF	=	0 if all went OK
	=	1 otherwise

|

	pushad			; Save all EGP registers
	REGSAVE <ds>		; Save segment register

	xor	esi,esi 	; Zero to use as dword
	lds	si,ARGPTR	; DS:SI ==> command line
	assume	ds:nothing	; Tell the assembler about it

; Set defaults

;;;;;;; call	FCN_INTRUDE	; Tell 'em we're intruding
	call	FCN_DBGQSWAT	; Tell 'em to be quiet if preceding SWAT present

	call	STR_UPPER	; Convert the string to upper case
CHECK_ARGS_SRCH:		; Search for arguments
	call	SKIP_WHITE	; Skip over white space

	and	al,al		; Check for terminator
	jz	short CHECK_ARGS_DONE ; That's all folks

	cmp	al,';'          ; Check for terminator
	je	short CHECK_ARGS_DONE ; That's all folks

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

	jmp	CHECK_ARGS_ERR	; Join common error code


CHECK_ARGS_FOUND:
	mov	LASTKEY,si	; Save starting offset
	add	si,LINARG_LEN[bx] ; Skip over the keyword

	call	LINARG_ACT[bx]	; Take appropriate action
	jnc	short CHECK_ARGS_SRCH ; Jump if successful
				; Fall through if not (note CF=1)
	jmp	short CHECK_ARGS_EXIT ; Join common exit code


CHECK_ARGS_DONE:

; Check on previous installation in which case we must abort.
; Note that the keyword UNINST doesn't come through this path -- instead
; it returns CF=1 and jumps directly to the exit.

	call	CheckPrev	; Check on previous installation
	jnc	short CHECK_ARGS_EXIT ; Jump if not installed (note CF=0)

	mov	DRV_ERRMSG,offset NGROUP:MSG_DUPINST ; Save offset in NGROUP of error msg
CHECK_ARGS_ERR:
	stc			; Indicate an error occurred
CHECK_ARGS_EXIT:
	REGREST <ds>		; Restore
	assume	ds:NGROUP	; Tell the assembler about it
	popad			; Restore all GP registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_ARGS endp 		; End CHECK_ARGS procedure
	NPPROC	CheckPrev -- Check On Previous Installation
	assume	ds:nothing,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

Check on previous installation

On exit:

CF	=	0 if no previous installation
	=	1 otherwise

|

	REGSAVE <ax,si,di,ds,es> ; Save registers

	mov	ax,cs		; Copy code/data segment
	mov	ds,ax		; Address it
	assume	ds:NGROUP	; Tell the assembler about it

	mov	ax,@DPMI_API2F	; Get function code
	lea	si,VSAPI_STR2	; DS:SI ==> VSAPI signature
	int	2Fh		; Request multiplexor services
				; If it's a match, return with ...
				; AL	=   0
				; ES:DI ==> VSAPI Entry Point
				; ZF	=   1
	jnz	short @F	; Jump if not found

	mov	si,seg RGROUP	; Get segment of VSAPI_VEC
	mov	ds,si		; Address it
	assume	ds:RGROUP	; Tell the assembler about it

	mov	VSAPI_VEC.VOFF,di ; Save for later use
	mov	VSAPI_VEC.VSEG,es ; ...
@@:
	cmp	al,1		; Izit a match?
				; Fall through with CF = 1 iff found
	REGREST <es,ds,di,si,ax> ; Restore
	assume	ds:nothing	; Tell the assembler about it
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CheckPrev endp			; End CheckPrev procedure
	NPPROC	DISP_UNK -- Display Message and Unknown Keyword
	assume	ds:nothing,es:NGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Display error message and unknown keyword.

On entry:

ES:DI	==>	error message to display
DS:SI	==>	unknown keyword

|

	push	di		; Pass address of error message
	call	DISP_ERRMSG	; Tell 'em we couldn't decipher their handwriting

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
	call	DISP_ERRMSG	; Tell 'em we couldn't decipher their handwriting

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DISP_UNK endp			; End DISP_UNK procedure
	NPPROC	DISP_ERRMSG -- Display Error Message
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DISP_ERRMSG_STR struc

	dw	?		; Caller's BP
	dw	?		; Caller's return address
DISP_ERRMSG_OFF dw ?		; Offset in CS of message

DISP_ERRMSG_STR ends

	push	bp		; Prepare to address stack
	mov	bp,sp		; Hello, Mr. Stack

	pusha			; Save all GP registers
	REGSAVE <ds,es> 	; Save registers

	push	cs		; Setup DS for @WRITF2
	pop	ds
	assume	ds:NGROUP	; Tell the assembler about it

	push	cs		; Setup ES for scas
	pop	es
	assume	es:NGROUP	; Tell the assembler about it

	mov	di,[bp].DISP_ERRMSG_OFF ; ES:DI ==> message
	mov	dx,di		; DS:DX ==> message
	mov	al,EOS		; Look for this
	mov	cx,-1		; We know it's there
	cld			; String ops forwardly
  repne scas	es:[di].LO	; Search for the string terminator
;;;;;;; jne	short ???	; Jump if not found???

	mov	cx,di		; Copy offset+1 of EOS
	sub	cx,dx		; Less start to get length + 1
	dec	cx		; ...to get actual length (without EOS)
	mov	bx,@STD_ERR	; Standard error file handle
	DOSCALL @WRITF2 	; Display the message

	REGREST <es,ds> 	; Restore
	assume	ds:nothing	; Tell the assembler about it
	assume	es:nothing	; Tell the assembler about it
	popa			; Restore

	pop	bp		; Restore

	ret	2		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DISP_ERRMSG endp		; End DISP_ERRMSG procedure
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

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SKIP_WHITE endp 		; End SKIP_WHITE procedure
	NPPROC	STR_UPPER -- Copnvert String to Uppercase
	assume	ds:nothing,es:NGROUP,fs:nothing,gs:nothing,ss:nothing
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
	assume	ds:nothing,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing

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
	call	DISP_ERRMSG	; Tell 'em we couldn't decipher their handwriting
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
	FPPROC	INT24 -- Critical Error Interrupt Handler
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

INT24	endp			; End INT24 procedure
	NPPROC	INST24 -- Install INT 24h Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

	REGSAVE <ax,ds,es>	; Save registers

	push	seg NGROUP	; Setup DS for data references
	pop	ds
	assume	ds:NGROUP	; Tell the assembler about it

	push	seg INTVEC	; Prepare to address segment zero
	pop	es		; Hello, segment zero
	assume	es:INTVEC	; Tell the assembler about it

	cli			; Nobody move

	lea	ax,INT24	; Get & set offset
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

	push	seg NGROUP	; Setup DS for data references
	pop	ds
	assume	ds:NGROUP	; Tell the assembler about it

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

	align	16		; Fill tail with NOPs

NCODE	ends			; End NCODE segment

	MEND			; End GXT_ARG module
