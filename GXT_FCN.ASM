;' $Header$
	title	GXT_FCN -- MMEXT Argument Function Routines
	page	58,122
	name	GXT_FCN

COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1988-2003 Sudley Place Software.

|
.386
.xlist
	include MASM.INC
	include 386.INC
	include DOSCALL.INC
	include ASCII.INC
	include PTR.INC
	include DIR.INC
	include XMS.INC
	include BIOSDATA.INC
	include INTVEC.INC
	include OPCODES.INC
	include MAXDEV.INC
	include DEVDRV.INC

	include GXT_API.INC
	include GXT_COM.INC
	include GXT_DRV.INC
	include GXT_HDR.INC
	include GXT_PRG.INC
	include GXT_SEG.INC
	include GXT_SWT.INC
	include GXT_V2P.INC
.list


P1ST	segment use32 byte public 'prog' ; Start P1ST segment
	assume	ds:PGROUP

;;;;;;; extrn	GXTINI:tbyte
	extrn	DEVLOAD:byte

P1ST	ends			; End P1ST segment


DATA16	segment use32 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	public	@GXT_FCN_DATA16
@GXT_FCN_DATA16 label byte	; Mark module start in .MAP file

@CON1MB equ	1024*1024	; Constant 1MB

@LOAD_MAX equ	32		; Size of load table

	public	LOADCOUNT,LOADTABIND,LOADTABLST
LOADCOUNT dd	0		; # entries in LOADTAB
LOADTABIND dd	@LOAD_MAX*(type LOAD_STR) ; Next available index (dynamic)
LOADTABLST dd	(@LOAD_MAX-1)*(type LOAD_STR) ; Last index (static)

	public	LOADTAB
LOADTAB LOAD_STR @LOAD_MAX dup (<?>) ; Load table

DATA16	ends			; End DATA16 segment


NDATA	segment use16 dword public 'ndata' ; Start NDATA segment
	assume	ds:NGROUP

	public	@GXT_FCN_NDATA
@GXT_FCN_NDATA	label byte	; Mark module start in .MAP file

	extrn	OLDINT24_VEC:dword
	extrn	MSG_UNK:byte
	extrn	MSG_SEP:byte
	extrn	MAPSEG_NXT:word
	extrn	XMSDRV_VEC:dword
	extrn	DRV_ERRMSG:word

	extrn	TSRSEG_CUR:word
	extrn	TSRSEG_NXT:word
	extrn	TSRSEG_LST:word

	extrn	XMBMOVE:tbyte
	extrn	PHYSIZE:dword

;;;	public	RR_VEC
;;; RR_VEC  dd	    RGROUP:RRSTART  ; Seg:Off of REST_REAL copied code/data

	public	EXEC_BLK
EXEC_BLK dw	?,?		; Load and relocation factors

	public	NEXTSEL,MAXSEL1
;;;TSEL dw	DTE_MODS or RPL3 ; Starting selector for load modules if RM/VCPI
NEXTSEL dw	DTE_MODS	; Starting selector for load modules if RM/VCPI
MAXSEL1 dw	size XDTE_STR	; Maximum selector + (size DESC_STR)

	public	ARG_FLAG
	include GXT_ARG.INC
ARG_FLAG dw	0		; Argument flags

	public	PROF_CNT,PROF_SEG
PROF_CNT dw	?		; # bytes in the profile
PROF_SEG dw	?		; Segment of the profile


	public	MSG_POPEN,MSG_PREAD
MSG_POPEN label byte
MSG_PREAD db	BEL,'様> Unable to access profile.',CR,LF,EOS

	public	MSG_SYMSW,MSG_LEXEC,MSG_EXECUP,MSG_ERRSEL
	public	MSG_NOTINST2,MSG_UNINSTALL
MSG_SYMSW  db	BEL,'様> Invalid switch.',CR,LF,EOS
MSG_LEXEC db	BEL,'様> Unable to access load module.',CR,LF,EOS
MSG_EXECUP db	BEL,'様> Unable to move load module to extended memory.',CR,LF,EOS
MSG_ERRSEL db	BEL,'様> Unable to allocate all selectors to load module (need   '
MSG_ERRSEL1 db	'_ more selectors).',CR,LF,EOS
MSG_NOTINST2 db BEL,"様> ",@PROGNAME," not previously installed -- can't uninstall.",CR,LF,EOS
MSG_UNINSTALL db @PROGNAME,' uninstalled.',CR,LF,EOS

NDATA	ends			; End NDATA segment


;;; RCODE0  segment use16 para public 'rcode' ; Start RCODE0 segment
;;;	    assume  ds:RGROUP
;;;
;;;	    public  RRSTART
;;; RRSTART label   byte
;;;
;;; RCODE0  ends		    ; End RCODE0 segment
;;;
;;;
RCODE	segment use16 para public 'rcode' ; Start RCODE segment
	assume	cs:RGROUP,ds:RGROUP

	extrn	RM2PM_HANDLER:far
	extrn	PM2RM_HANDLER:far
	extrn	DEV_FLAG:word
	extrn	VSAPI_VEC:dword

RCODE	ends			; End RCODE segment


NCODE	segment use16 para public 'ncode' ; Start NCODE segment
	assume	cs:NGROUP

	public	@GXT_FCN_NCODE
@GXT_FCN_NCODE: 		; Mark module start in .MAP file

	extrn	SKIP_WHITE:near
	extrn	PROC_PROFILE:near
	extrn	DISP_ERRMSG:near
	extrn	DISP_NORMMSG:near
	extrn	INST24:near
	extrn	REST24:near
	extrn	ALLOC_XMS:near
	extrn	SET_DEVGDT:near
	extrn	BIN2BASE:near
	extrn	CheckPrev:near

	NPPROC	FCN_DBGNSWAT -- DEBUG=NSWAT Function
	assume	ds:nothing,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=NSWAT function

Don't pass on SWAT presence to load modules.

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan

|

	push	ds		; Save for a moment

	push	seg PGROUP	; Get segment of DEVLOAD
	pop	ds		; Address it
	assume	ds:PGROUP	; Tell the assembler about it

	or	DEVLOAD,@DEVL_NSWAT ; Mark as not passing on SWAT presence

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGNSWAT endp		; End FCN_DBGNSWAT procedure
	NPPROC	FCN_DBGPSWAT -- DEBUG=PSWAT Function
	assume	ds:nothing,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=PSWAT function

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan

|

	push	ds		; Save for a moment

	push	seg PGROUP	; Get segment of DEVLOAD
	pop	ds		; Address it
	assume	ds:PGROUP	; Tell the assembler about it

	and	DEVLOAD,not @DEVL_QSWAT ; Mark as not quiet SWAT if present

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGPSWAT endp		; End FCN_DBGPSWAT procedure
	NPPROC	FCN_DBGQSWAT -- DEBUG=QSWAT Function
	assume	ds:nothing,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

DEBUG=QSWAT function

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan

|

	push	ds		; Save for a moment

	push	seg PGROUP	; Get segment of DEVLOAD
	pop	ds		; Address it
	assume	ds:PGROUP	; Tell the assembler about it

	or	DEVLOAD,@DEVL_QSWAT ; Mark as quiet SWAT if present

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_DBGQSWAT endp		; End FCN_DBGQSWAT procedure
;;;;	     NPPROC  FCN_INTRUDE -- INTRUDE Function
;;;;	     assume  ds:nothing,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing
;;;; COMMENT|
;;;;
;;;; INTRUDE function
;;;;
;;;; On entry:
;;;;
;;;; DS:ESI  ==>     command line following keyword
;;;;
;;;; On exit:
;;;;
;;;; DS:ESI  ==>     next character to scan
;;;;
;;;; |
;;;;
;;;;	     push    ds 	     ; Save for a moment
;;;;
;;;;	     push    seg RGROUP      ; Get segment of DEV_FLAG
;;;;	     pop     ds 	     ; Address it
;;;;	     assume  ds:RGROUP	     ; Tell the assembler about it
;;;;
;;;;	     test    DEV_FLAG,@DEV_VCPI ; Are we using VCPI services?
;;;;	     jz      short FCN_INTRUDE_EXIT ; Jump if not
;;;;
;;;;	     or      DEV_FLAG,@DEV_INTRUDE ; Mark as INTRUDE present
;;;;
;;;;	     push    seg PGROUP      ; Get segment of DEVLOAD
;;;;	     pop     ds 	     ; Address it
;;;;	     assume  ds:PGROUP	     ; Tell the assembler about it
;;;;
;;;;	     or      DEVLOAD,@DEVL_INTRUDE ; Mark as INTRUDE present
;;;; FCN_INTRUDE_EXIT:
;;;;	     pop     ds 	     ; Restore
;;;;	     assume  ds:nothing      ; Tell the assembler about it
;;;;
;;;;	     clc		     ; Indicate all went well
;;;;
;;;;	     ret		     ; Return to caller
;;;;
;;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;;
;;;; FCN_INTRUDE endp		     ; End FCN_INTRUDE procedure
	NPPROC	FCN_LOAD -- LOAD=d:\path\filename.ext Function
	assume	ds:nothing,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

LOAD= function

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan

|

	REGSAVE <eax,ebx,ecx,edx,edi,gs> ; Save registers

	push	OLDINT24_VEC	; Save old INT 24h handler's address
	call	INST24		; Install local INT 24h handler

	call	SKIP_WHITE	; Skip over more white space

	cmp	al,'='          ; Must be
	jne	near ptr FCN_LOAD_EQ ; Too bad

	inc	si		; Skip over the character
	call	SKIP_WHITE	; Skip over more white space

	mov	dx,si		; Save as start of profile fid

; Search for end of filename

FCN_LOAD1:
	lods	ds:[si].LO	; Get next character

	cmp	al,' '          ; Too small for filename?
	ja	short FCN_LOAD1 ; No, go around again

	dec	si		; Back off to terminator

; Search for end of arguments

	call	ARGEND		; Return with DS:DI ==> end of argument list

; Load the file into memory

	mov	ax,MAPSEG_NXT	; Get next available segment
	mov	EXEC_BLK.ELO,ax ; Save as segment address for load
	mov	EXEC_BLK.EHI,ax ; Save as relocation factor

	lea	bx,EXEC_BLK	; ES:BX ==> EXEC block
	mov	cl,0		; String terminator
	xchg	cl,[si] 	; Terminate filename.ext
	mov	al,03h		; Access code for load overlay

	REGSAVE <cx,dx,si>	; Save over EXEC
	DOSCALL @EXEC		; Load the overlay
	REGREST <si,dx,cx>	; Restore

	xchg	cl,[si] 	; Restore filename.ext
	jc	near ptr FCN_LOAD_EXEC ; Something went wrong

COMMENT|

Call the real mode initialization code

On entry:

DS:DX	==>	"d:\path\filename.ext [arguments]",0
DS:SI	==>	"[arguments]",0

|

; Relocate code if necessary

	mov	gs,MAPSEG_NXT	; Get next available segment
	assume	gs:nothing	; Tell the assembler about it

; Note that this segment has a copy of the module's GXTHDR
; at its start.  We now fill in some dynamic field values.

; Terminate filename and argument list

	mov	bx,si		; Copy offset of filename terminator

	cmp	ds:[si].LO,TAB	; Any arguments?
	je	short FCN_LOAD5 ; Jump if so

	cmp	ds:[si].LO,' '  ; Any arguments?
	jb	short FCN_LOAD6 ; Jump if not
FCN_LOAD5:
	inc	si		; Skip over filename terminator
FCN_LOAD6:
	push	ds		; Save for a moment

	push	seg PGROUP	; Get segment of DEVLOAD
	pop	ds		; Address it
	assume	ds:PGROUP	; Tell the assembler about it

	test	DEVLOAD,@DEVL_PSWAT ; Is SWAT present?
	jz	short @F	; Jump if not

	test	DEVLOAD,@DEVL_NSWAT ; Is not passed on?
	jnz	short @F	; Jump if so

	or	gs:[0].GXTHDR_ATTR,@GXTHDR_PSWAT ; Mark as present
@@:
	mov	eax,PHYSIZE	; Get top of physical memory in 1KB
	mov	gs:[0].GXTHDR_PHYSIZE,eax ; Save for later use

	push	seg RGROUP	; Get segment of DEV_FLAG
	pop	ds		; Address it
	assume	ds:RGROUP	; Tell the assembler about it

	test	DEV_FLAG,@DEV_FCR3 ; Is there a full CR3?
	jz	short @F	; Jump if not

	or	gs:[0].GXTHDR_ATTR,@GXTHDR_FCR3 ; Mark as present
@@:
	test	DEV_FLAG,@DEV_VDS ; Do XMS lock addrs needs VDS translation?
	jz	short @F	; Jump if not

	or	gs:[0].GXTHDR_ATTR,@GXTHDR_VDS ; Mark as needing translation
@@:
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

; Skip over the copy of GXTHDR_STR we will save in the TSR area
; after INIT_REAL is called.

@TSRHDR_SIZE equ ((size GXTHDR_STR) + (16 - 1)) / 16

	mov	ax,TSRSEG_NXT	; Get next available segment for TSRs
	mov	gs:[0].GXTHDR_HDRSEG,ax ; Save for load module use
	add	ax,@TSRHDR_SIZE ; Skip over it
	mov	gs:[0].GXTHDR_PRGSEG_CUR,ax ; Save for load module use

	mov	ax,TSRSEG_LST	; Get highest ...
	mov	gs:[0].GXTHDR_PRGSEG_NXT,ax ; Save for load module use

; Note that the following address is to be copied by the LOD module
; during INIT_REAL, so we specify the segment as PGROUP to which it'll
; be copied in COPYLOW as opposed to its current segment (RGROUP).

	mov	gs:[0].GXTHDR_RM2PM_VEC.VOFF,offset RGROUP:RM2PM_HANDLER ; Save address of RM2PM routine
	mov	gs:[0].GXTHDR_PM2RM_FVEC.FOFF,offset RGROUP:PM2RM_HANDLER ; Save address of PM2RM routine
	mov	gs:[0].GXTHDR_RM2PM_VEC.VSEG,seg PGROUP ; ...

	mov	cx,0		; Terminators
	xchg	cl,ds:[bx]	; Swap 'em
	xchg	ch,ds:[di]	; Swap 'em
	call	gs:[0].GXTHDR_IREAL ; Call it to initialize
	xchg	ch,ds:[di]	; Restore
	xchg	cl,ds:[bx]	; Restore

	mov	si,di		; DS:SI ==> end of argument list

	test	gs:[0].GXTHDR_ATTR,@GXTHDR_RMIE ; Test for real mode initialization error
	jnz	near ptr FCN_LOAD_ERR ; Jump if something went wrong

; Copy the GXTHDR to the TSR area and link it in

	REGSAVE <si,di,es>	; Save for a moment

	mov	es,TSRSEG_NXT	; Get next header segment
	assume	es:nothing	; Tell the assembler about it

; Save new next segment in TSRSEG_NXT

	mov	ax,es		; Get next available segment for TSRs
	add	ax,@TSRHDR_SIZE ; Skip over it
	add	ax,gs:[0].GXTHDR_NLOWPARA ; Plus # low DOS paras needed (possibly 0)
.8086
	mov	TSRSEG_NXT,ax	; Save for next time
.386
	mov	ax,gs:[0].GXTHDR_PRGSEG_CUR ; Get current program segment
	mov	gs:[0].GXTHDR_RREAL.VSEG,ax ; Save it

; Copy GXTHDR_STR

	xor	si,si		; GS:SI ==> current header
	xor	di,di		; ES:DI ==> new ...
	mov	cx,size GXTHDR_STR ; CX = byte length
    rep movs	es:[di].LO,gs:[si].LO ; Copy to TSR area
	mov	es:[0].GXTHDR_NXT,-1 ; Mark as last segment

; Link it in

	mov	si,es		; Copy current segment

	cmp	TSRSEG_CUR,-1	; Izit invalid?
	je	short @F	; Jump if so

	mov	es,TSRSEG_CUR	; Address it
	assume	es:nothing	; Tell the assembler about it

	mov	es:[0].GXTHDR_NXT,si ; Save as next segment
@@:
.8086
	mov	TSRSEG_CUR,si	; Save as current segment
.386
	REGREST <es,di,si>	; Restore
	assume	ds:nothing,es:NGROUP ; Tell the assembler about it

;;;;;;; mov	si,di		; DS:SI ==> end of argument list
;;;;;;;
;;;;;;; test	gs:[0].GXTHDR_ATTR,@GXTHDR_RMIE ; Test for real mode initialization error
;;;;;;; jnz	near ptr FCN_LOAD_ERR ; Jump if something went wrong
;;;;;;;
; Save load table information backwards as that's the way the
; extended memory is reserved.

	mov	edi,LOADTABIND	; Get index to next load table entry
	sub	edi,size LOAD_STR ; Skip to next entry backwards

	mov	ax,MAPSEG_NXT	; Get next available segment
	mov	LOADTAB[edi].LOAD_SEG,ax ; Save in LOAD structure

	mov	ax,gs:[0].GXTHDR_NSELS ; Get # selectors needed
	mov	LOADTAB[edi].LOAD_NSELS,ax ; Save in LOAD structure

	mov	eax,gs:[0].GXTHDR_COFF ; Get the code offset
	mov	LOADTAB[edi].LOAD_COFF,eax ; Save in LOAD structure

	mov	eax,gs:[0].GXTHDR_CLEN ; Get the code size
	mov	LOADTAB[edi].LOAD_CLEN,eax ; Save in LOAD structure

	mov	eax,gs:[0].GXTHDR_DOFF ; Get the data offset
	mov	LOADTAB[edi].LOAD_DOFF,eax ; Save in LOAD structure

	mov	eax,gs:[0].GXTHDR_DLEN ; Get the data size
	mov	LOADTAB[edi].LOAD_DLEN,eax ; Save in LOAD structure

	mov	eax,gs:[0].GXTHDR_ATTR ; Get the attributes
	mov	LOADTAB[edi].LOAD_ATTR,eax ; Save in LOAD structure

	mov	eax,gs:[0].GXTHDR_RREAL ; Get REST_REAL address
	mov	LOADTAB[edi].LOAD_RREAL,eax ; Save in LOAD structure

	mov	eax,gs:[0].GXTHDR_CLEN ; Get the code size
	add	eax,gs:[0].GXTHDR_DLEN ; Plus ... data

	and	eax,eax 	; Anything to save?
	jz	near ptr FCN_LOAD_CLC ; Jump if not

; Copy the resident portion to extended memory

	call	FCN_LOADUP	; Copy it upstairs
	jc	near ptr FCN_LOAD_ERRUP ; Jump if something went wrong

; If we're not INTRUDing, save selectors and setup DTEs

	push	ds		; Save for a moment

	push	seg RGROUP	; Get segment of DEV_FLAG
	pop	ds		; Address it
	assume	ds:RGROUP	; Tell the assembler about it

	test	DEV_FLAG,@DEV_INTRUDE ; Izit present?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jnz	short FCN_LOAD_INTRUDE ; Jump if so

	mov	ax,NEXTSEL	; Get next available selector if RM/VCPI
	add	ax,2 * (size DESC_STR) ; Skip over CR3 (-1) and TSS (-2) selectors
	mov	LOADTAB[edi].LOAD_SEL1,ax ; Save in LOAD structure
	imul	ax,gs:[0].GXTHDR_NSELS,size DESC_STR ; Get size of # selectors needed
	add	NEXTSEL,ax	; Save for next time

	mov	ax,NEXTSEL	; Get next selector

	sub	ax,MAXSEL1	; Izit within range?
	ja	short FCN_LOAD_ERRSEL ; Jump if not

; Set the DTEs

	call	SET_LOAD_DTE	; Set the load module DTEs at LOADTAB[edi]
FCN_LOAD_INTRUDE:
	mov	LOADTABIND,edi	; Save current index
	inc	LOADCOUNT	; Count in another table entry
FCN_LOAD_CLC:
	clc			; Indicate all went well

	jmp	short FCN_LOAD_EXIT ; Join common tail code


FCN_LOAD_EXEC:
	push	offset NGROUP:MSG_LEXEC ; Pass address of error message
	call	DISP_ERRMSG	; Tell 'em we allow no mistakes

	jmp	short FCN_LOAD_EXIT ; Join common tail code (CF set)


FCN_LOAD_ERRSEL:

; Format AX/8 into the error message

	shr	ax,3-0		; Convert from bytes to selectors
	lea	di,MSG_ERRSEL1	; ES:DI ==> units digit in message
	mov	cx,10		; Use base 10 to convert
	call	BIN2BASE	; Convert AX to ASCII ending at ES:DI

	push	offset NGROUP:MSG_ERRSEL ; Pass address of error message
	call	DISP_ERRMSG	; Tell 'em we allow no mistakes

	jmp	short FCN_LOAD_ERR ; Join common tail code


FCN_LOAD_ERRUP:
	push	offset NGROUP:MSG_EXECUP ; Pass address of error message
	call	DISP_ERRMSG	; Tell 'em we allow no mistakes

	jmp	short FCN_LOAD_ERR ; Join common tail code


FCN_LOAD_EQ:
	push	offset NGROUP:MSG_SEP ; Pass address of error message
	call	DISP_ERRMSG	; Tell 'em we allow no mistakes
FCN_LOAD_ERR:
	stc			; Indicate there was a problem
FCN_LOAD_EXIT:
	call	REST24		; Restore INT 24h handler
	pop	OLDINT24_VEC	; Restore old INT 24h handler's address

	REGREST <gs,edi,edx,ecx,ebx,eax> ; Restore
	assume	gs:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_LOAD endp			; End FCN_LOAD procedure
	NPPROC	FCN_PRO -- PRO=d:\path\filename.ext Function
	assume	ds:nothing,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

PRO=d:\path\filename.ext function

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan

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
	push	offset NGROUP:MSG_POPEN ; Pass address of error message
	call	DISP_ERRMSG	; Tell 'em we couldn't open the file

	jmp	short FCN_PRO_ERR ; Join common tail code


FCN_PRO_READERR:
	push	offset NGROUP:MSG_PREAD ; Pass address of error message
	call	DISP_ERRMSG	; Tell 'em we couldn't read the file

	jmp	short FCN_PRO_ERR ; Join common tail code


FCN_PRO_UNK:
	push	offset NGROUP:MSG_UNK ; Pass address of error message
	call	DISP_ERRMSG	; Tell 'em we couldn't decipher their handwriting

	jmp	short FCN_PRO_ERR ; Join common tail code


FCN_PRO_EQ:
	push	offset NGROUP:MSG_SEP ; Pass address of error message
	call	DISP_ERRMSG	; Tell 'em we allow no mistakes
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
	NPPROC	FCN_UNINSTALL -- UNINSTALL Function
	assume	ds:nothing,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

UNINSTALL function

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan

|

	pushad			; Save all EGP registers
	REGSAVE <ds>		; Save register

; Check to see if we're installed

	call	CheckPrev	; Check on previous installation
	jnc	short FCN_UNINSTALL_NOTINST ; Jump if we're not installed

; Signal to upstairs to get LOADTAB values

	lea	edi,LOADTAB	; FS:EDI ==> local tables
	xor	cx,cx		; Assume not installed
	xor	dx,dx		; ...
	CALLPL0 GETTAB		; Tell 'em to send the LOADTAB values
				; Return with CX = LOADCOUNT
				; ...	      DX = MMEXT XMS handle
	mov	LOADCOUNT.ELO,cx ; Save for later use

	and	dx,dx		; Wuzit allocated?
	jz	short @F	; Jump if not

	call	XMS_UNINST	; Remove XMS handle in DX
@@:
;;;;;;; mov	cx,LOADCOUNT.ELO ; Get # load modules
	jcxz	FCN_UNINSTALL_EXIT ; Jump if no load modules

; Loop through the table unlocking and releasing the XMS handles
; and calling REST_REAL

	mov	esi,LOADTABLST	; Get last index
FCN_UNINSTALL_NEXT1:
	mov	dx,LOADTAB[esi].LOAD_XMS ; Get the handle

	and	dx,dx		; Wuzit allocated?
	jz	short FCN_UNINSTALL_LOOP1 ; Jump if not

;;; ; Tell 'em to copy REST_REAL code/data to ES:EDI
;;;
;;;	    push    es		    ; Save for a moment
;;;
;;;	    xor     edi,edi	    ; Zero to use as dword
;;;	    les     di,RR_VEC	    ; ES:EDI ==> free area for REST_REAL code/data
;;;	    assume  es:nothing	    ; Tell the assembler about it
;;;
;;;	    mov     es:[di].LO,@OPCOD_RETF ; In case no REST_REAL code
;;;	    CALLPL0 RREAL	    ; Tell 'em to copy REST_REAL code/data
;;;				    ; for entry ESI to ES:EDI
;;;
;;;	    pop     es		    ; Restore
;;;	    assume  es:NGROUP	    ; Tell the assembler about it
;;;
;;; ; Call the REST_REAL function at RR_VEC
;;;
;;;	    call    RR_VEC	    ; Call 'em
;;;
; Call the REST_REAL code in the UMB segment

	call	LOADTAB[esi].LOAD_RREAL ; Call it

	call	XMS_UNINST	; Remove XMS handle in DX

	mov	LOADTAB[esi].LOAD_XMS,0 ; Mark as released
FCN_UNINSTALL_LOOP1:
	sub	esi,type LOAD_STR ; Skip to next entry

	loop	FCN_UNINSTALL_NEXT1 ; Jump if more handles

; Tell 'em to call REST_PROT

	CALLPL0 RPROT		; Tell 'em to call REST_PROT

	call	REST_REAL	; Restore our RM/VM values

	push	offset NGROUP:MSG_UNINSTALL ; Pass address of normal message
	call	DISP_NORMMSG	; Tell 'em we succeeded

	jmp	short FCN_UNINSTALL_EXIT ; Join common exit code


FCN_UNINSTALL_NOTINST:
	push	offset NGROUP:MSG_NOTINST2 ; Pass address of error message
	call	DISP_ERRMSG	; Tell 'em there's no previous installed copy
FCN_UNINSTALL_EXIT:
	REGREST <ds>		; Restore
	assume	ds:nothing	; Tell the assembler about it
	popad			; ...

	or	ARG_FLAG,@ARG_UNINST ; Mark as uninstalling

	stc			; Indicate we're terminating

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_UNINSTALL endp		; End FCN_UNINSTALL procedure
	NPPROC	REST_REAL -- Restore RM/VM Values
	assume	ds:nothing,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

Restore RM/VM values

|

	REGSAVE <ax,ds,es>	; Save registers

	mov	ax,seg RGROUP	; Get segment of VSAPI_VEC
	mov	ds,ax		; Address it
	assume	ds:RGROUP	; Tell the assembler about it

	mov	ax,@VSAPI_RREAL ; Function code for REST_REAL
	call	VSAPI_VEC	; Request VSAPI Entry Point service
				; Return AX = memory segment to free
	jc	short @F	; Jump if something went wrong

	and	ax,ax		; Izit valid?
	jz	short @F	; Jump if not

	mov	es,ax		; Address it
	DOSCALL @RELMEM 	; Free the memory
@@:
	REGREST <es,ds,ax>	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

REST_REAL endp			; End REST_REAL procedure
	NPPROC	TMP_INT00 -- Temporary Divide Overflow Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Temporary divide overflow handler

|

TMP00_STR struc

	dw	?		; Caller's BP
TMP00_IP dw	?		; ...	   IP
	dw	?		; ...	   CS
	dw	?		; ...	   FL

TMP00_STR ends

	push	bp		; Prepare to address the stack
	mov	bp,sp		; Hello, Mr. Stack

	add	[bp].TMP00_IP,2 ; Skip over the DIV AX

	pop	bp		; Restore

	iret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

TMP_INT00 endp			; End TMP_INT00 procedure
	NPPROC	XMS_UNINST -- Uninstall An XMS Handle
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Uninstall an XMS handle

On entry:

DX	=	XMS handle to uninstall

|

	REGSAVE <ax,bx> 	; Save registers

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
	REGREST <bx,ax> 	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

XMS_UNINST endp 		; End XMS_UNINST procedure
	NPPROC	ARGEND -- Search for End of Argument List
	assume	ds:nothing,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing
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
	NPPROC	FCN_LOADUP -- Copy LOD Module To Extended Memory
	assume	ds:nothing,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

Copy a load module to extended memory

On entry:

DGROUP:EDI ==>	 LOAD_STR for this module
GS:0	==>	File image starting with GXTHDR.INC

On exit:

CF	=	0 if all went well
	=	1 otherwise

|

	pushad			; Save all EGP registers
	REGSAVE <ds>		; Save segment register

	mov	ax,seg NGROUP	; Get segment of XMBMOVE
	mov	ds,ax		; Address it
	assume	ds:NGROUP	; Tell the assembler about it

; Allocate XMS memory

	mov	edx,gs:[0].GXTHDR_CLEN ; Get the code size
	add	edx,gs:[0].GXTHDR_DLEN ; Plus ... data
	add	edx,1024-1	; Round up to 1KB
	and	edx,not (1024-1) ; ...boundary
	mov	XMBMOVE.XMBMOVE_LEN,edx ; Save as move length
	call	ALLOC_XMS	; Allocate EDX bytes of XMS memory
				; returning EAX = base physical address
				;	    CX = handle
	jc	short FCN_LOADUP_EXIT ; Jump if something went wrong (note CF=1)

	mov	dx,cx		; Copy to XMS handle register
	mov	LOADTAB[edi].LOAD_PHYS,eax ; Save in LOAD structure
	mov	LOADTAB[edi].LOAD_MMLIN,eax ; ...
	mov	LOADTAB[edi].LOAD_XMS,dx ; ...

; Move data to XMS memory

	mov	XMBMOVE.XMBMOVE_SHNDL,0 ; Save as source handle
				; meaning it's in the first megabyte
	mov	XMBMOVE.XMBMOVE_SOFF.VOFF,0 ; Save as source offset
	mov	XMBMOVE.XMBMOVE_SOFF.VSEG,gs ; ...	      segment

	mov	XMBMOVE.XMBMOVE_DHNDL,dx ; Save as destin handle
	mov	XMBMOVE.XMBMOVE_DOFF,0 ; ...		   offset

; Ensure the move length doesn't overlap the 1MB boundary as EMM386
; complains if that happens.  This occurs if there is a large amount
; of uninitialized data.

	mov	eax,XMBMOVE.XMBMOVE_LEN ; Get the move length
	xor	ecx,ecx 	; Zero to use as dword
	mov	cx,gs		; Copy source segment
	shl	ecx,4-0 	; Convert from paras to bytes
	add	eax,ecx 	; Plus starting address

	cmp	eax,@CON1MB	; Izit too big?
	jbe	short @F	; Jump if not

	mov	eax,@CON1MB	; Get maximum
	sub	eax,ecx 	; Less starting address
	mov	XMBMOVE.XMBMOVE_LEN,eax ; Save as move length
@@:
	lea	si,XMBMOVE	; DS:SI ==> XMS block move struc
	mov	ah,@XMS_MOVXMB	; Function code for block move using DS:SI
	call	XMSDRV_VEC	; Request XMS service
				; Return with AX = 1 if successful
	cmp	ax,1		; Did it work?
	je	short FCN_LOADUP_EXIT ; Jump if so (note CF=0)

; An error occurred using XMS services; unlock and release the memory

	call	XMS_UNINST	; Remove XMS handle in DX

	SETMSG	DRV,"Insufficient extended memory to load."

	stc			; Indicate the move failed
FCN_LOADUP_EXIT:
	REGREST <ds>		; Restore
	assume	ds:nothing	; Tell the assembler about it
	popad			; ...

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_LOADUP endp 		; End FCN_LOADUP procedure
	NPPROC	FCN_VCPIONLY -- VCPIONLY Function
	assume	ds:nothing,es:NGROUP,fs:DGROUP,gs:nothing,ss:nothing
COMMENT|

VCPIONLY function

On entry:

DS:ESI	==>	command line following keyword

On exit:

DS:ESI	==>	next character to scan

|

	push	ds		; Save for a moment

	push	seg RGROUP	; Get segment of DEV_FLAG
	pop	ds		; Address it
	assume	ds:RGROUP	; Tell the assembler about it

	test	DEV_FLAG,@DEV_VCPI ; Are we using VCPI services?
	jz	short FCN_VCPIONLY_EXIT ; Jump if not

	and	DEV_FLAG,not @DEV_INTRUDE ; Mark as INTRUDE not present

	push	seg PGROUP	; Get segment of DEVLOAD
	pop	ds		; Address it
	assume	ds:PGROUP	; Tell the assembler about it

	and	DEVLOAD,not @DEVL_INTRUDE ; Mark as INTRUDE not present
FCN_VCPIONLY_EXIT:
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	clc			; Indicate all went well

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_VCPIONLY endp		; End FCN_VCPIONLY procedure
	NPPROC	SET_LOAD_DTE -- Set Load Module DTEs
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Set load module DTEs

On entry:

EDI	=	index into LOADTAB

|

	pushad			; Save registers
	REGSAVE <es,fs,gs>	; ...

	push	seg NGROUP	; Get segment of NGROUP
	pop	es		; Address it
	assume	es:NGROUP	; Tell the assembler about it

	push	seg DGROUP	; Get segment of DGROUP
	pop	fs		; Address it
	assume	fs:DGROUP	; Tell the assembler about it

	push	seg RGROUP	; Get segment of SWATGDT
	pop	gs		; Address it
	assume	gs:RGROUP	; Tell the assembler about it

	mov	cx,LOADTAB[edi].LOAD_NSELS ; Get # selectors needed
	mov	dx,LOADTAB[edi].LOAD_SEL1 ; Get starting selector

; Install code selector

	mov	ebx,LOADTAB[edi].LOAD_MMLIN ; Get base linear address
	mov	eax,ebx 	; Copy base linear address
	add	eax,LOADTAB[edi].LOAD_COFF ; Plus offset to code segment

	push	LOADTAB[edi].LOAD_CLEN ; Pass length of code
	push	eax		; Get base address
	push	dx		; Get DTE
	test	LOADTAB[edi].LOAD_ATTR,@GXTHDR_USE32 ; Is CS big?
	setnz	ah		; AH = 1 iff CS is big
	shl	ah,$DTE_B	; Shift into position
	mov	al,CPL0_CODE	; Get A/R byte
	push	ax		; Pass A/R byte and flags
	call	SET_DEVGDT	; Set the GDT entry

	dec	cx		; Count out code selector
	jcxz	SET_LOAD_DTE_EXIT ; Jump if no more???

; Install data selectors

	mov	eax,ebx 	; Copy base linear address
	add	eax,LOADTAB[edi].LOAD_DOFF ; Plus offset to data segment
@@:
	add	dx,type DESC_STR ; Skip to next DTE

	push	LOADTAB[edi].LOAD_DLEN ; Pass length of data
	push	eax		; Get base address
	push	dx		; Get DTE
	push	((mask $DTE_B) shl 8) or CPL0_DATA or DPL3 ; Get A/R byte and flags
	call	SET_DEVGDT	; Set the GDT entry

	loop	@B		; Jump if more selectors
SET_LOAD_DTE_EXIT:
	REGREST <gs,fs,es>	; Restore
	assume	es:nothing,fs:nothing,gs:nothing ; Tell the assembler about it
	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SET_LOAD_DTE endp		; End SET_LOAD_DTE procedure

	align	16		; Fill tail with NOPs

NCODE	ends			; End NCODE segment

	MEND			; End GXT_FCN module
