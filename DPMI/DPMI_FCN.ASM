;' $Header$
	title	DPMI_FCN -- DPMI.LOD Argument Function Routines
	page	58,122
	name	DPMI_FCN

COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1988-2004 Sudley Place Software.   

|
.386
.xlist
	include MASM.INC
	include 386.INC
	include DOSCALL.INC
	include ASCII.INC
	include PTR.INC
	include DIR.INC
	include INTVEC.INC

	include DPMI_COM.INC
	include DPMI_DB2.INC
	include DPMI_DTE.INC
	include DPMI_PRG.INC
	include DPMI_SEG.INC

	include QMAX_I31.INC		; Must precede QMAXDPMI.INC
	include QMAXDPMI.INC		; Must follow QMAX_I31.INC
	include QMAX_VMM.INC
.list

XDATA	segment use16 dword public 'xdata' ; Start XDATA segment
	assume	ds:XGROUP

	public	@DPMI_FCN_XDATA
@DPMI_FCN_XDATA label byte	; Mark module start in .MAP file

	extrn	OLDINT24_VEC:dword
	extrn	MSG_UNK:byte
	extrn	MSG_SEP:byte
	extrn	MSG_DPMI:byte
	extrn	MSG_SWERR:byte
	extrn	MSG_VAL:byte
	extrn	MSG_OVF:byte

	extrn	LASTKEY:word
	extrn	MAPSEG_NXT:word

	extrn	FILE_DPFE:byte
	extrn	PATHSTEM_LEN:word

	public	EXEC_BLK
EXEC_BLK dw	?,?		; Load and relocation factors

	public	ARG_FLAG
ARG_FLAG dw	0		; Argument flags
@ARG_PRO   equ	8000h		; PRO= being processed

	public	PROF_CNT,PROF_SEG
PROF_CNT dw	?		; # bytes in the profile
PROF_SEG dw	?		; Segment of the profile

	public	MSG_POPEN,MSG_PREAD
MSG_POPEN label byte
MSG_PREAD db	BEL,'ออ> Unable to access profile.',CR,LF,EOS

	public	SWAP_FNEZ
SWAP_FNEZ db	@PROGNAME,'.SWP',0 ; Filename.ext,0 for temporary SWAPFILE
SWAP_FNEZ_LEN equ $-SWAP_FNEZ	; Length of ...

XDATA	ends			; End XDATA segment


DATA16	segment use16 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	public	@DPMI_FCN_DATA16
@DPMI_FCN_DATA16 label byte	; Mark module start in .MAP file

	extrn	I31_FLAG:word
	extrn	DPM_FLAG:word
	include DPMI_LCL.INC
	extrn	LCL_FLAG:word
	extrn	VMM_FLAG:word

	extrn	BSPath:byte
	extrn	BSGTotal:dword
	extrn	BSMin:dword

	extrn	LDT_SIZ:dword	; Size in bytes of LDT (/8)
	extrn	XLDT_SIZ:dword	; Size in bytes of extended LDT (/@DPMI_BOUND)
	extrn	HPDABUF_SIZ:word
	extrn	HPDABUF_OFF:word
	extrn	HPDASTK_SIZ:word
	extrn	HPDASTK_OFF:word
	extrn	HPDASTK_TOP:word
	extrn	HPDAVMC_CNT:word
	extrn	HPDAVMC_OFF:word
	extrn	DPMIHNDL_CNT:dword
	extrn	DPMIHNDL_SIZ:dword
	extrn	DPMIPDIR_CNT:dword
	extrn	DPMIDYN_SIZ:dword
	extrn	HPDA_NPAR:word
	extrn	SharedSize:dword

	public	DB2_FLAG
DB2_FLAG dw	0		; Debugging flags #2

DATA16	ends			; End DATA16 segment


XCODE	segment use16 para public 'xcode' ; Start XCODE segment
	assume	cs:XGROUP

	public	@DPMI_FCN_XCODE
@DPMI_FCN_XCODE:		; Mark module start in .MAP file

	extrn	SKIP_WHITE:near
	extrn	PROC_PROFILE:near
	extrn	DISP_MSG:near
	extrn	DISP_UNK:near
	extrn	INST24:near
	extrn	REST24:near
	extrn	IZITCOMMENT:near
	extrn	IZITEOL:near
	extrn	BASE2BIN:near
	extrn	BASE2BIND:near
	extrn	UPPERCASE:near

	NPPROC	FCN_DBGCLI -- DEBUG=CLI Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=CLI

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	I31_FLAG,mask $I31_CLI ; Enable CLI/STI handling

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGCLI endp 		; End FCN_DBGCLI procedure
	NPPROC	FCN_DBGDPMIERR -- DEBUG=DPMIERR Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=DPMIERR

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DPM_FLAG,mask $DPM_DPMIERR ; Enable debugging of DPMI errors

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGDPMIERR endp		; End FCN_DBGDPMIERR procedure
	NPPROC	FCN_DBGDPMILOCK -- DEBUG=DPMILOCK Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=DPMILOCK

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DPM_FLAG,mask $DPM_DPMILOCK ; Check for InDOS when paging

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGDPMILOCK endp		; End FCN_DBGDPMILOCK procedure
	NPPROC	FCN_DBGDPMINEWSEL -- DEBUG=DPMINEWSEL Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=DPMINEWSEL

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DPM_FLAG,mask $DPM_DPMINEWSEL ; Force new selector on all
				; allocates
	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGDPMINEWSEL endp		; End FCN_DBGDPMINEWSEL procedure
	NPPROC	FCN_DBGDPMIPHYS -- DEBUG=DPMIPHYS Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=DPMIPHYS

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DB2_FLAG,@DB2_DPMIPHYS ; Disable checks in DPMI_GETP2L

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGDPMIPHYS endp		; End FCN_DBGDPMIPHYS procedure
	NPPROC	FCN_DBGDPMISEL -- DEBUG=DPMISEL Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=DPMISEL

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DPM_FLAG,mask $DPM_DPMISEL ; Enable debugging of LAST_DPMI_xS
				; selector errors
	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGDPMISEL endp		; End FCN_DBGDPMISEL procedure
	NPPROC	FCN_DBGDPMISPURNT -- DEBUG=DPMISPURNT Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=DPMISPURNT

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DPM_FLAG,mask $DPM_DPMISPURNT ; Enable debugging of spurious
				; NT task switches
	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGDPMISPURNT endp		; End FCN_DBGDPMISPURNT procedure
	NPPROC	FCN_DBGDPMISTART -- DEBUG=DPMISTART Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=DPMISTART

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DPM_FLAG,mask $DPM_DPMISTART ; Enable debugging of DPMI
				; client startup
	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGDPMISTART endp		; End FCN_DBGDPMISTART procedure
	NPPROC	FCN_DBGDPMISTD -- DEBUG=DPMISTD Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=DPMISTD

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DPM_FLAG,mask $DPM_DPMISTD ; Force KRNL386 to come up in
				; standard mode
	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGDPMISTD endp		; End FCN_DBGDPMISTD procedure
	NPPROC	FCN_DBGDPMITERM -- DEBUG=DPMITERM Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=DPMITERM

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DPM_FLAG,mask $DPM_DPMITERM ; Signal INT 01h if we free
				; resources the client forgot about upon termination
	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGDPMITERM endp		; End FCN_DBGDPMITERM procedure
	NPPROC	FCN_DBGDPMIV100 -- DEBUG=DPMIV100 Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=DPMIV100

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DPM_FLAG,mask $DPM_DPMIV100 ; Force DPMI version 1.00
				; even if Rational Systems-based program
	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGDPMIV100 endp		; End FCN_DBGDPMIV100 procedure
	NPPROC	FCN_DBGNODEBUG -- DEBUG=NODEBUG Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=NODEBUG

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DB2_FLAG,@DB2_NODEBUG ; Mark as not hooking INTs 01h and 03h

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGNODEBUG endp		; End FCN_DBGNODEBUG procedure
	NPPROC	FCN_DBGNOKEYB -- DEBUG=NOKEYB Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=NOKEYB

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DB2_FLAG,@DB2_NOKEYB ; Mark as not hooking INT 09h

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGNOKEYB endp		; End FCN_DBGNOKEYB procedure
	NPPROC	FCN_DBGNONMI -- DEBUG=NONMI Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=NONMI

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DB2_FLAG,@DB2_NONMI ; Mark as not hooking INT 02h

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGNONMI endp		; End FCN_DBGNONMI procedure
	NPPROC	FCN_NOUMB -- NOUMB Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

NOUMB

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	LCL_FLAG,@LCL_NOUMB ; Don't allocate memory in UMBs

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_NOUMB endp			; End FCN_NOUMB procedure
	NPPROC	FCN_NOVCPI -- NOVCPI Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

NOVCPI

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DPM_FLAG,mask $DPM_NOVCPI ; Disable VCPI presence detection

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_NOVCPI endp 		; End FCN_NOVCPI procedure
	NPPROC	FCN_DPMIMEM -- DPMIMEM Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DPMIMEM=lll,sss,bbb,ccc,hhh,ppp,ddd
						    Min 	     Max
where lll is the # entries in the LDT		    @NLDTE_MIN	     8192
      sss is the byte size of the HPDA stack	    @HPDASTK_MIN     ...
      bbb is the byte size of the HPDA buffer	    @HPDABUF_MIN     ...
      ccc is the # VM callbacks 		    @HPDAVMC_MIN     ...
      hhh is the # DPMI memory handles		    @DPMIHNDL_MIN    ...
      ppp is the # page directories		    @DPMIPDIR_MIN    ...
  and ddd is the byte size of the dynamic save area @DPMIDYN_MIN     ...

All items but the first are optional.  Missing items may be elided.

|

	REGSAVE <eax,ecx,edx>	; Save registers

	call	SKIP_WHITE	; Skip over more white space

	cmp	al,'='          ; Must be
	jne	near ptr FCN_DPMIMEM_EQ ; Too bad

; Check for an initial (optional) value
;     lll is the # entries in the LDT
; This value times 8 is saved into LDT_SIZ

	inc	si		; Skip over the character
	call	SKIP_WHITE	; Skip over more white space

	cmp	al,','          ; Izit elided?
	je	short FCN_DPMIMEM0 ; Jump if not

	call	IZITCOMMENT	; Izit start of comment?
	je	near ptr FCN_DPMIMEM_CALC ; Jump if so

	call	IZITEOL 	; Check for end of the line
	je	near ptr FCN_DPMIMEM_CALC ; Jump if so

	mov	cx,10		; Use base 10 to convert
	call	BASE2BIN	; Convert the number at DS:SI to binary in AX
	jc	near ptr FCN_DPMIMEM_MSG ; Jump if too large

	cmp	ax,@NLDTE_MIN	; Check against minimum
	jae	short @F	; Jump if it's within range

	mov	ax,@NLDTE_MIN	; Use minimum
@@:
	cmp	ax,8192 	; Check against maximum
	jbe	short @F	; It's within range

	mov	ax,8192 	; Use maximum
@@:
	movzx	eax,ax		; Zero to use as dword
	mov	ecx,eax 	; Copy to calculate size of bitmap
	add	ecx,8*8-1	; Round up to next qword of bits
	and	ecx,not (8*8-1) ; ...
	shr	ecx,3-0 	; Convert from bits to bytes
	mov	XLDT_SIZ,ecx	; Save as byte size of bitmap
	imul	eax,eax,type DESC_STR ; Times the size of each entry
	mov	LDT_SIZ,eax	; Save for later use
	add	eax,XLDT_SIZ	; Add to get pre-rounded extended size
	add	eax,@DPMI_BOUND-1 ; Round up to next
	and	eax,not (@DPMI_BOUND-1) ; ... boundary for ALLOCMEM
	mov	XLDT_SIZ,eax	; Save for later use

; Check for a second (optional) value delimited by a comma
;     sss is the byte size of the HPDA stack
; saved into HPDASTK_SIZ

	call	SKIP_WHITE	; Skip over more white space

	cmp	al,','          ; Izit present?
	jne	near ptr FCN_DPMIMEM_CALC ; Jump if not
FCN_DPMIMEM0:
	inc	si		; Skip over separator
	call	SKIP_WHITE	; Skip over more white space

	cmp	al,','          ; Izit elided?
	je	short FCN_DPMIMEM1 ; Jump if so

	call	IZITCOMMENT	; Izit start of comment?
	je	near ptr FCN_DPMIMEM_CALC ; Jump if so

	call	IZITEOL 	; Check for end of the line
	je	near ptr FCN_DPMIMEM_CALC ; Jump if so

	mov	cx,10		; Use base 10 to convert
	call	BASE2BIN	; Convert the number at DS:SI to binary in AX
	jc	near ptr FCN_DPMIMEM_MSG ; Jump if too large

	and	ax,not (4-1)	; Round down to a dword boundary

	cmp	ax,@HPDASTK_MIN ; Check against minimum
	jae	short @F	; Jump if it's within range

	mov	ax,@HPDASTK_MIN ; Use minimum
@@:
	mov	HPDASTK_SIZ,ax	; Save for later use

; Check for a third (optional) value delimited by a comma
;     bbb is the byte size of the HPDA buffer
; saved into HPDABUF_SIZ

	call	SKIP_WHITE	; Skip over more white space

	cmp	al,','          ; Izit present?
	jne	near ptr FCN_DPMIMEM_CALC ; Jump if not
FCN_DPMIMEM1:
	inc	si		; Skip over separator
	call	SKIP_WHITE	; Skip over more white space

	cmp	al,','          ; Izit elided?
	je	short FCN_DPMIMEM2 ; Jump if so

	call	IZITCOMMENT	; Izit start of comment?
	je	near ptr FCN_DPMIMEM_CALC ; Jump if so

	call	IZITEOL 	; Check for end of the line
	je	near ptr FCN_DPMIMEM_CALC ; Jump if so

	mov	cx,10		; Use base 10 to convert
	call	BASE2BIN	; Convert the number at DS:SI to binary in AX
	jc	near ptr FCN_DPMIMEM_MSG ; Jump if too large

	and	ax,not (4-1)	; Round down to a dword boundary

	cmp	ax,@HPDABUF_MIN ; Check against minimum
	jae	short @F	; Jump if it's within range

	mov	ax,@HPDABUF_MIN ; Use minimum
@@:
	mov	HPDABUF_SIZ,ax	; Save for later use

; Check for a fourth (optional) value delimited by a comma
;     ccc is the # VM callbacks
; saved into HPDAVMC_CNT

	call	SKIP_WHITE	; Skip over more white space

	cmp	al,','          ; Izit present?
	jne	near ptr FCN_DPMIMEM_CALC ; Jump if not
FCN_DPMIMEM2:
	inc	si		; Skip over separator
	call	SKIP_WHITE	; Skip over more white space

	cmp	al,','          ; Izit elided?
	je	short FCN_DPMIMEM3 ; Jump if so

	call	IZITCOMMENT	; Izit start of comment?
	je	near ptr FCN_DPMIMEM_CALC ; Jump if so

	call	IZITEOL 	; Check for end of the line
	je	near ptr FCN_DPMIMEM_CALC ; Jump if so

	mov	cx,10		; Use base 10 to convert
	call	BASE2BIN	; Convert the number at DS:SI to binary in AX
	jc	near ptr FCN_DPMIMEM_MSG ; Jump if too large

	cmp	ax,@HPDAVMC_MIN ; Check against minimum
	jae	short @F	; Jump if it's within range

	mov	ax,@HPDAVMC_MIN ; Use minimum
@@:
	mov	HPDAVMC_CNT,ax	; Save for later use

; Check for a fifth (optional) value delimited by a comma
;     hhh is the # DPMI memory handles
; saved into DPMIHNDL_CNT

	call	SKIP_WHITE	; Skip over more white space

	cmp	al,','          ; Izit present?
	jne	near ptr FCN_DPMIMEM_CALC ; Jump if not
FCN_DPMIMEM3:
	inc	si		; Skip over separator
	call	SKIP_WHITE	; Skip over more white space

	cmp	al,','          ; Izit elided?
	je	short FCN_DPMIMEM4 ; Jump if so

	call	IZITCOMMENT	; Izit start of comment?
	je	near ptr FCN_DPMIMEM_CALC ; Jump if so

	call	IZITEOL 	; Check for end of the line
	je	near ptr FCN_DPMIMEM_CALC ; Jump if so

	mov	cx,10		; Use base 10 to convert
	call	BASE2BIN	; Convert the number at DS:SI to binary in AX
	jc	near ptr FCN_DPMIMEM_MSG ; Jump if too large

	cmp	ax,@DPMIHNDL_MIN ; Check against minimum
	jae	short @F	; Jump if it's within range

	mov	ax,@DPMIHNDL_MIN ; Use minimum
@@:
	movzx	eax,ax		; Zero to use as dword
	mov	DPMIHNDL_CNT,eax ; Save for later use
	imul	eax,type DPMIHNDL_STR ; Times # bytes in each entry
	add	eax,@DPMI_BOUND-1 ; Round up to next
	and	eax,not (@DPMI_BOUND-1) ; ... boundary for ALLOCMEM
	mov	DPMIHNDL_SIZ,eax ; Save for later use

; Check for a sixth (optional) value delimited by a comma
;     ppp is the # page directories
; saved into DPMIPDIR_CNT

	call	SKIP_WHITE	; Skip over more white space

	cmp	al,','          ; Izit present?
	jne	near ptr FCN_DPMIMEM_CALC ; Jump if not
FCN_DPMIMEM4:
	inc	si		; Skip over separator
	call	SKIP_WHITE	; Skip over more white space

	cmp	al,','          ; Izit elided?
	je	short FCN_DPMIMEM5 ; Jump if so

	call	IZITCOMMENT	; Izit start of comment?
	je	short FCN_DPMIMEM_CALC ; Jump if so

	call	IZITEOL 	; Check for end of the line
	je	short FCN_DPMIMEM_CALC ; Jump if so

	mov	cx,10		; Use base 10 to convert
	call	BASE2BIN	; Convert the number at DS:SI to binary in AX
	jc	near ptr FCN_DPMIMEM_MSG ; Jump if too large

	cmp	ax,@DPMIPDIR_MIN ; Check against minimum
	jae	short @F	; Jump if it's within range

	mov	ax,@DPMIPDIR_MIN ; Use minimum
@@:
	movzx	eax,ax		; Zero to use as dword
	mov	DPMIPDIR_CNT,eax ; Save for later use

; Check for a seventh (optional) value delimited by a comma
;     ddd is the byte size of the dynamic save area
; saved into DPMIDYN_SIZ

	call	SKIP_WHITE	; Skip over more white space

	cmp	al,','          ; Izit present?
	jne	short FCN_DPMIMEM_CALC ; Jump if not
FCN_DPMIMEM5:
	inc	si		; Skip over separator
	call	SKIP_WHITE	; Skip over more white space

	cmp	al,','          ; Izit elided?
	je	short FCN_DPMIMEM6 ; Jump if so

	call	IZITCOMMENT	; Izit start of comment?
	je	short FCN_DPMIMEM_CALC ; Jump if so

	call	IZITEOL 	; Check for end of the line
	je	short FCN_DPMIMEM_CALC ; Jump if so

	mov	cx,10		; Use base 10 to convert
	call	BASE2BIN	; Convert the number at DS:SI to binary in AX
	jc	short FCN_DPMIMEM_MSG ; Jump if too large

	cmp	ax,@DPMIDYN_MIN ; Check against minimum
	jae	short @F	; Jump if it's within range

	mov	ax,@DPMIDYN_MIN ; Use minimum
@@:
	and	eax,@DPMI_BOUND-1 ; Round down to proper boundary
	mov	DPMIDYN_SIZ,eax ; Save for later use
FCN_DPMIMEM6:
FCN_DPMIMEM_CALC:

; Calculate HPDA dynamic data area offsets from the above values

	mov	ax,size HPDA_STR  ; Get size of static elements
	add	ax,4-1		; Round up to dword boundary
	and	ax,not (4-1)	; ...
	mov	HPDASTK_OFF,ax	; Save for later use

	add	ax,HPDASTK_SIZ	; Plus its size
	jc	short FCN_DPMIMEM_MSG ; Jump if it's too large

	mov	HPDASTK_TOP,ax	; Save for later use
	mov	HPDABUF_OFF,ax	; Save for later use

	add	ax,HPDABUF_SIZ	; Plus its size
	jc	short FCN_DPMIMEM_MSG ; Jump if it's too large

	mov	HPDAVMC_OFF,ax	; Save for later use
	mov	cx,HPDAVMC_CNT	; Get # VM callbacks
	imul	cx,size HPDAVMC_STR ; Times # bytes per callback
	jc	short FCN_DPMIMEM_MSG ; Jump if it's too large

	add	ax,cx		; Plus its size
	jc	short FCN_DPMIMEM_MSG ; Jump if it's too large

	add	ax,16-1 	; Round up to para boundary
	jc	short FCN_DPMIMEM_MSG ; Jump if it's too large

;;;;;;; and	ax,not (16-1)	; ...
	shr	ax,4-0		; Convert from bytes to paras

	mov	HPDA_NPAR,ax	; Save for later use

	clc			; Indicate all went well

	jmp	short FCN_DPMIMEM_EXIT ; Join common exit code


FCN_DPMIMEM_EQ:
	push	offset XGROUP:MSG_SEP ; Pass address of error message
	call	DISP_MSG	; Tell 'em we couldn't decipher their handwriting

	jmp	short FCN_DPMIMEM_ERR ; Join common error code


FCN_DPMIMEM_MSG:
	push	offset XGROUP:MSG_DPMI ; Pass address of error message
	call	DISP_MSG	; Tell 'em we couldn't decipher their handwriting
FCN_DPMIMEM_ERR:
	stc			; Indicate something went wrong
FCN_DPMIMEM_EXIT:
	REGREST <edx,ecx,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DPMIMEM endp		; End FCN_DPMIMEM procedure
	NPPROC	FCN_FORCELPM16 -- FORCELPM16 Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

FORCELPM16 function

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	or	DB2_FLAG,@DB2_LPM16 ; Force 16-bit LPM stack

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_FORCELPM16 endp		; End FCN_FORCELPM16 procedure
	NPPROC	FCN_PRO -- PRO=d:\path\filename.ext Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

PRO=d:\path\filename.ext function

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	REGSAVE <ax,bx,cx,dx>	; Save registers

	push	OLDINT24_VEC	; Save old value so we're recursive
	call	INST24		; Install local INT 24h handler

; Ensure we're not already processing a profile

	test	ARG_FLAG,@ARG_PRO ; Already in process?
	jnz	short FCN_PRO_UNK ; Yes, so that's an error

	or	ARG_FLAG,@ARG_PRO ; Mark as being processed

	call	SKIP_WHITE	; Skip over more white space

	cmp	al,'='          ; Must be
	jne	short FCN_PRO_EQ ; Too bad

	inc	si		; Skip over the character
	mov	dx,si		; Save as start of profile fid

; Search for end of filename

@@:
	lods	ds:[si].LO	; Get next character

	cmp	al,' '          ; Too small for filename?
	ja	short @B	; No, go around again

	dec	si		; Back off to terminator

; Attempt to open the file

	mov	cl,0		; String terminator
	xchg	cl,[si] 	; Terminate filename.ext
	mov	al,0		; Access code for read-only
	stc			; Assume error
	DOSCALL @OPENF2 	; Open it
	xchg	cl,[si] 	; Restore filename.ext
	jc	short FCN_PRO_OPENERR ; Something went wrong

	mov	bx,ax		; Copy to file handle register

	REGSAVE <ds>		; Save for a moment

	mov	ds,MAPSEG_NXT	; Setup DS for OPENF2
	assume	ds:nothing	; Tell the assembler about it

	mov	PROF_SEG,ds	; Save for later use

	xor	dx,dx		; DS:DX ==> profile segment
	mov	cx,0FFFFh	; Read in all of it

	stc			; Assume error
	DOSCALL @READF2 	; Read it in

	mov	PROF_CNT,ax	; Save # bytes read

	push	bx		; Save for a moment

	mov	bx,ax		; Copy to index register
	mov	ds:[bx].LO,EOF	; Terminate with EOF

	pop	bx		; Restore

	REGREST <ds>		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jc	short FCN_PRO_READERR ; Something went wrong

	add	ax,(16-1)+1	; Round up to para boundary (count in EOF, too)
	shr	ax,4-0		; Convert from bytes to paras
	add	MAPSEG_NXT,ax	; Skip over profile segment

;;;;;;; stc			; Assume error
	DOSCALL @CLOSF2 	; Close it up
				; Ignore error return

	call	PROC_PROFILE	; Process the profile entries
				; Return with CF significant
	jmp	short FCN_PRO_EXIT ; Join common tail code


FCN_PRO_OPENERR:
	push	offset XGROUP:MSG_POPEN ; Pass address of error message
	call	DISP_MSG	; Tell 'em we couldn't open the file

	jmp	short FCN_PRO_ERR ; Join common tail code


FCN_PRO_READERR:
	push	offset XGROUP:MSG_PREAD ; Pass address of error message
	call	DISP_MSG	; Tell 'em we couldn't read the file

	jmp	short FCN_PRO_ERR ; Join common tail code


FCN_PRO_UNK:
	push	offset XGROUP:MSG_UNK ; Pass address of error message
	call	DISP_MSG	; Tell 'em we couldn't decipher their handwriting

	jmp	short FCN_PRO_ERR ; Join common tail code


FCN_PRO_EQ:
	push	offset XGROUP:MSG_SEP ; Pass address of error message
	call	DISP_MSG	; Tell 'em we allow no mistakes
FCN_PRO_ERR:
	stc			; Indicate there was a problem
FCN_PRO_EXIT:
	pushf			; Save flags
	call	REST24		; Restore INT 24h handler
	and	ARG_FLAG,not @ARG_PRO ; Mark as not being processed
	popf			; Restore
	pop	OLDINT24_VEC	; Restore

	REGREST <dx,cx,bx,ax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing

FCN_PRO endp			; End FCN_PRO procedure
	NPPROC	ARGEND -- Search for End of Argument List
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

Search for end of argument list

On entry:

DS:SI	==>	current position in argument

On exit:

DS:DI	==>	end of argument list

|

	mov	di,si		; DS:DI ==> starting offset

	test	ARG_FLAG,@ARG_PRO ; Are we in the profile?
	jz	short ARGEND_EXIT ; No, hence no arguments
ARGEND_NEXT:
	cmp	ds:[di].LO,TAB	; Allow this in the argument
	je	short @F	; Jump if so

	cmp	ds:[di].LO,' '  ; Stop when below this
	jb	short ARGEND_EXIT ; Jump if we're at the end
@@:
	inc	di		; Skip to next character

	jmp	ARGEND_NEXT	; Go around again


ARGEND_EXIT:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

ARGEND	endp			; End ARGEND procedure
	NPPROC	FCN_SHAREDMEM -- SHAREDMEM Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

SHAREDMEM=nnn	(in KB)

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

|

	REGSAVE <eax,ecx>	; Save registers

	call	SKIP_WHITE	; Skip over more white space

	cmp	al,'='          ; Must be
	jne	short FCN_SHAREDMEM_EQ ; Too bad

	inc	si		; Skip over separator
	call	SKIP_WHITE	; Skip over more white space

	mov	cx,10		; Use base 10 to convert
	call	BASE2BIND	; Convert the number at DS:SI to binary in EAX
	jc	short FCN_SHAREDMEM_OVF ; Jump if too large

; The number is in units of 1MB and can't be too large

@LG2_1MB equ	20		; Log base 2 of 1MB

	cmp	eax,1 shl (32-@LG2_1MB) ; Izit too big?
	jae	short FCN_SHAREDMEM_OVF ; Jump if so

	add	eax,4-1 	; Round up to 4 (MB)
	and	eax,not (4-1)	; ...boundary

	shl	eax,@LG2_1MB-0	; Convert from 1MB to bytes
	mov	SharedSize,eax	; Save as new shared size

	clc			; Mark as successful

	jmp	short FCN_SHAREDMEM_EXIT ; Join common exit code


FCN_SHAREDMEM_OVF:
	mov	si,LASTKEY	; DS:SI ==> start of line
	lea	di,MSG_OVF	; ES:DI ==> error message
	call	DISP_UNK	; Display it along with unknown keyword at DS:SI

	jmp	short FCN_SHAREDMEM_ERR ; Join common error code


FCN_SHAREDMEM_EQ:
	push	offset XGROUP:MSG_SEP ; Pass address of error message
	call	DISP_MSG	; Tell 'em we couldn't decipher their handwriting

;;;;;;; jmp	short FCN_SHAREDMEM_ERR ; Join common error code


FCN_SHAREDMEM_ERR:
	stc			; Indicate something went wrong
FCN_SHAREDMEM_EXIT:
	REGREST <ecx,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing

FCN_SHAREDMEM endp		; End FCN_SHAREDMEM procedure
	NPPROC	FCN_SWAPFILE -- SWAPFILE Function
	assume	ds:nothing,es:XGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT!

SWAPFILE [/t][/p][/s=nnnn]
SWAPFILE=d:\path\filename.ext [/t][/p][/s=nnn]

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan
CF	=	0 if successful
	=	1 if not

!

	REGSAVE <eax,bx,cx,edx,di,es,gs> ; Save registers

	push	OLDINT24_VEC	; Save old INT 24h handler's address
	call	INST24		; Install local INT 24h handler

	mov	ax,seg DGROUP	; Get segment of DGROUP
	mov	es,ax		; Address it
	assume	es:DGROUP	; Tell the assembler about it

	mov	ax,seg XGROUP	; Get segment of XGROUP
	mov	gs,ax		; Address it
	assume	gs:XGROUP	; Tell the assembler about it

	or	VMM_FLAG,@VMM_BSTEMP ; Mark as temporary swapfile

	call	SKIP_WHITE	; Skip over more white space

	call	IZITCOMMENT	; Izit start of comment?
	je	short FCN_SWAPFILE_TMP ; Jump if so

	call	IZITEOL 	; Check for end of the line
	je	short FCN_SWAPFILE_TMP ; Jump if so

	cmp	al,'/'          ; Izit switch character?
	je	short FCN_SWAPFILE_TMP ; Jump if so

	cmp	al,'='          ; Must be
	jne	near ptr FCN_SWAPFILE_EQ ; Too bad

	inc	si		; Skip over it
	call	SKIP_WHITE	; Skip over more white space

; Copy and normalize the FID to BSPATH

	lea	di,BSPath	; ES:DI ==> output save area

	cmp	ds:[si+1].LO,':' ; Is there a drive separator?
	je	short FCN_SWAPFILE1 ; Jump if so

	DOSCALL @GETDSK 	; Return with current drive # in AL (origin-0)
	add	al,'A'          ; Convert to uppercase ASCII

S16	stos	BSPath[di]	; Save in output area
	mov	al,':'          ; Get drive separator
S16	stos	BSPath[di]	; Save in output area

	jmp	short FCN_SWAPFILE2 ; Join common code


FCN_SWAPFILE1:
S16	movs	<BSPath[di].ELO,ds:[si].ELO> ; Move drive letter and separator
FCN_SWAPFILE2:
	cmp	ds:[si].LO,'\'  ; Is there a path separator?
	je	short FCN_SWAPFILE3 ; Jump if so

	mov	al,'\'          ; Get path separator
S16	stos	BSPath[di]	; Save in output area

	REGSAVE <si,ds> 	; Save for a moment

	mov	al,BSPath	; Get drive letter
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
  repne scas	BSPath[di]	; Search for it

	dec	di		; Back off to trailing zero

	cmp	es:[di-1].LO,'\' ; Is there a trailing path separator?
	je	short @F	; Jump if so

	mov	al,'\'          ; Get path separator
S16	stos	BSPath[di]	; Save in output area
@@:
	REGREST <ds,si> 	; Restore
	assume	ds:nothing	; Tell the assembler about it
FCN_SWAPFILE3:

; Copy the rest of the FID

FCN_SWAPFILE4:
	lods	ds:[si].LO	; Get the next character

	cmp	al,'/'          ; Izit switch character?
	je	short FCN_SWAPFILE5 ; Jump if so

	cmp	al,' '          ; Too small for filename?
	jbe	short FCN_SWAPFILE5 ; Jump if so

S16	stos	BSPath[di]	; Save in output area

	jmp	short FCN_SWAPFILE4 ; Go around again


; Use a temporary swap file:  use the filename in BSPath, but don't
; create it.

FCN_SWAPFILE_TMP:
	REGSAVE <si>		; Save for a moment

	lea	di,BSPath	; ES:DI ==> output save area

	lea	si,XGROUP:FILE_DPFE ; Address start of path
	mov	cx,PATHSTEM_LEN ; Get length of the path
S16 rep movs	<BSPath[di],FILE_DPFE[si]> ; Copy the path

	lea	si,SWAP_FNEZ	; Get filename.ext,0 of temporary swapfile
	mov	cx,SWAP_FNEZ_LEN ; Get # bytes in ...
S16 rep movs	<BSPath[di],SWAP_FNEZ[si]> ; Copy the filename.ext,0

	REGREST <si>		; Restore

	jmp	short FCN_SWAPFILE_SWITCH ; Join common code


FCN_SWAPFILE5:
	dec	si		; Back off to terminator

	mov	al,0		; String terminator
S16	stos	BSPath[di]	; Save in output area

; Parse switch characters from the command line

FCN_SWAPFILE_SWITCH:
	call	SKIP_WHITE	; Skip over more white space

	cmp	al,'/'          ; Izit switch character?
	jne	short FCN_SWAPFILE_XSW ; Jump if not

	inc	si		; Skip over it
	call	SKIP_WHITE	; Skip over more white space

	cmp	al,'s'          ; Izit size?
	jne	short FCN_SWAPFILE_XSW_S ; Jump if not

	inc	si		; Skip over it
	call	SKIP_WHITE	; Skip over more white space

	cmp	al,'='          ; Izit size?
	jne	near ptr FCN_SWAPFILE_EQ ; Jump if not

	inc	si		; Skip over it
	call	SKIP_WHITE	; Skip over more white space

	cmp	al,'0'          ; Izit a valid digit?
	jb	near ptr FCN_SWAPFILE_VAL ; Jump if not

	cmp	al,'9'          ; Izit a valid digit?
	ja	near ptr FCN_SWAPFILE_VAL ; Jump if not

	mov	cx,10		; Use base 10 to convert
	call	BASE2BIND	; Convert the number at DS:SI to binary in EAX
	jc	near ptr FCN_SWAPFILE_ERR ; Jump if too large

	add	eax,(4*1024/1024)-1 ; Round up to 4KB boundary in 1KB
	shr	eax,12-10	; Convert from 1KB to 4KB

	mov	edx,BSMin	; Get minimum swapfile size in bytes
	shr	edx,12-0	; Convert from bytes to 4KB

	cmp	eax,edx 	; Izit below the minimum?
	jae	short @F	; Jump if not

	mov	eax,edx 	; Use the minimum
@@:
	mov	BSGTotal,eax	; Save for later use

	jmp	short FCN_SWAPFILE_SWITCH ; Go around again


FCN_SWAPFILE_XSW_S:
	cmp	al,'p'          ; Izit perm?
	jne	short FCN_SWAPFILE_XSW_P ; Jump if not

	inc	si		; Skip over it
	and	VMM_FLAG,not @VMM_BSTEMP ; Mark as no longer temporary

	jmp	short FCN_SWAPFILE_SWITCH ; Go around again


FCN_SWAPFILE_XSW_P:
	cmp	al,'t'          ; Izit temp?
	jne	short FCN_SWAPFILE_XSW_T ; Jump if not

	inc	si		; Skip over it
	or	VMM_FLAG,@VMM_BSTEMP ; Mark as temporary

	jmp	short FCN_SWAPFILE_SWITCH ; Go around again


FCN_SWAPFILE_XSW_T:

; Unknown switch character

;;;;;;; push	offset XGROUP:MSG_SWERR ; Pass offset in XGROUP of error message
;;;;;;; call	DISP_MSG	; Tell 'em we allow no mistakes

	mov	ax,gs		; Get XGROUP segment
	mov	es,ax		; Address it
	assume	es:XGROUP	; Tell the assembler about it

	lea	di,MSG_SWERR	; ES:DI ==> error message
	call	DISP_UNK	; Display it along with unknown keyword at DS:SI

	jmp	short FCN_SWAPFILE_ERR ; Join common error code

	assume	es:nothing	; Tell the assembler about it


FCN_SWAPFILE_XSW:
	or	VMM_FLAG,@VMM_BSGLOBAL ; Mark as globally present
FCN_SWAPFILE_CLC:
	clc			; Indicate all went well

	jmp	short FCN_SWAPFILE_EXIT ; Join common exit code


FCN_SWAPFILE_VAL:
	push	offset XGROUP:MSG_VAL ; Pass offset in XGROUP of error message
	call	DISP_MSG	; Tell 'em we allow no mistakes

	jmp	short FCN_SWAPFILE_ERR ; Join common error code


FCN_SWAPFILE_EQ:
	push	offset XGROUP:MSG_SEP ; Pass offset in XGROUP of error message
	call	DISP_MSG	; Tell 'em we allow no mistakes
FCN_SWAPFILE_ERR:
	stc			; Indicate something went wrong
FCN_SWAPFILE_EXIT:
	call	REST24		; Restore INT 24h handler
	pop	OLDINT24_VEC	; Restore old INT 24h handler's address

	REGREST <gs,es,di,edx,cx,bx,eax> ; Restore
	assume	es:XGROUP,gs:nothing ; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_SWAPFILE endp		; End FCN_SWAPFILE procedure
	align	16		; Fill with NOPs

XCODE	ends			; End XCODE segment

	MEND			; End DPMI_FCN module
