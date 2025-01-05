;' $Header$
	title	DPMI_I2F -- DPMI.LOD INT 2Fh Handler
	page	58,122
	name	DPMI_I2F

COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1991-2003 Sudley Place Software.   

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include PTR.INC
	include ASCII.INC
	include CPUFLAGS.INC
	include BITFLAGS.INC
	include ALLMEM.INC
	include DPMI.INC

	include QMAX_I31.INC		; Must precede QMAXDPMI.INC
	include QMAXDPMI.INC		; Must follow QMAX_I31.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC		; Must precede QMAX_VMM.INC
	include QMAX_VMM.INC		; Must follow DPMI_DTE.INC
	include DPMI_SEG.INC
	include DPMI_W9X.INC
	include GXT_HDR.INC
	include VWIN32.INC
.list

DATA16	segment use16 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	extrn	DPM_FLAG:word
	extrn	VM2PM_VEC:dword

DATA16	ends			; End DATA16 segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_I2F_DATA
@DPMI_I2F_DATA	label byte	; Mark module start in .MAP file

	extrn	SEL_DATA:word
	extrn	SEL_4GB:word
	extrn	PDC_FLAG:word
	extrn	HPDA_NPAR:word
	extrn	CPUTYPE:byte
	extrn	OLDINT2F_FVEC:fword
	extrn	DPMI_CPIHOOK:byte
	extrn	DPMITYPE:byte
	extrn	I31_FLAG:word
	extrn	DPMI_CPL:byte
if @W9X
	extrn	DPMI_IDEF:word
	extrn	LaPMIDEF:dword

	public	VWIN32_TAB
VWIN32_TAB dw	PMVWIN32_16	; Entry points for VWIN32 API
	dw	PMVWIN32_32	; ...
endif
	public	MSG_FOXCOMPAT
MSG_FOXCOMPAT db 'Incompatible memory manager',LF,0
MSG_FOXCOMPAT_LEN equ $-MSG_FOXCOMPAT ; Length of ...

	public	MSG_RATIONAL1
MSG_RATIONAL1 db 'Copyright (C) 1987-199'
MSG_RATIONAL1A db '? by Rational Systems, Inc.'
MSG_RATIONAL1_LEN equ $-MSG_RATIONAL1 ; Length of ...

	public	MSG_RATIONAL2
MSG_RATIONAL2 db 'Copyright (C) Rational Systems, Inc. 1'
MSG_RATIONAL2_LEN equ $-MSG_RATIONAL2 ; Length of ...

	public	MSG_PHARLAP
MSG_PHARLAP db	'Copyright (C) 1986-1989 Phar Lap Software, Inc.'
MSG_PHARLAP_LEN equ $-MSG_PHARLAP ; Length of ...

DATA	ends			; End DATA segment


CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
	assume	cs:PGROUP,ds:PGROUP

	extrn	INTPROC00Z:near

	extrn	ERM_FVEC:fword

CODE16A ends			; End CODE16A segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_I2F_PROG
@DPMI_I2F_PROG: 		; Mark module start in .MAP file

	extrn	RESETVARS:near

	extrn	PMINTCOM:near
;;;;;;; extrn	DPMI_REFINT:near
	extrn	INTxx_INTRETPM:near
	extrn	INTPROC2F:near
	extrn	DPMIFN_CHKVSAPI:near
if @W9X
	extrn	GETBASE:near
	extrn	PMVWIN32_16:abs
	extrn	PMVWIN32_16B:abs
	extrn	PMVWIN32_16C:abs
	extrn	PMVWIN32_32:abs
;;;;;;; extrn	PMVWIN32_32B:abs
;;;;;;; extrn	PMVWIN32_32C:abs
	extrn	VMM_SET_ONEATTR:near
	extrn	VMM_ALLOC:near
	extrn	VMM_ZERO_PAGE:near
endif
	FPPROC	INT2F -- Local INT 2Fh Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Local INT 2Fh handler

|

INT2F_STR struc

INT2F_EGP db	(size PUSHAD_STR) dup (?) ; Caller's EGP registers
INT2F_EIP dd	?		; Caller's EIP
INT2F_CS  dw	?,?		; ...	   CS w/filler
INT2F_EFL dd	?		; ...	   EFL
INT2F_ESP dd	?		; ...	   ESP
INT2F_SS  dw	?,?		; ...	   SS w/filler
INT2F_ES  dw	?,?		; ...	   ES w/filler
INT2F_DS  dw	?,?		; ...	   DS w/filler
INT2F_FS  dw	?,?		; ...	   FS w/filler
INT2F_GS  dw	?,?		; ...	   GS w/filler

INT2F_STR ends

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit VM86 mode?
	jnz	near ptr INT2F_INTRETVM ; Jump if so

; If the caller is at PL0, don't pass on to any DPMI clients

	test	[esp].INTDPI_CS,mask $PL ; Izit at PL0?
	jz	short INT2F_INTRETPM ; Jump if so

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_CPIHOOK[2Fh/8],1 shl (2Fh mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT2F_INTRETPM ; Jump if not

	mov	[esp].NRM_INTNO,4*2Fh + offset PGROUP:INTPROC00Z ; Mark as INT 2Fh

; The stack is mapped by INTDPI_STR

	push	@PMINTCOM_NRM	; Use application stack
	jmp	PMINTCOM	; Jump to common code


	public	INT2F_INTRETPM
INT2F_INTRETPM:
	cmp	ax,@DPMI_CPUMODE ; Izit DPMI mode check (PM vs VM)?
	jne	short INT2F_INTRETPM1 ; Jump if not

	xor	ax,ax		; Mark as PM

	iretd			; Return to caller with AX = 0 (PM only)


INT2F_INTRETPM1:
	cmp	ax,@DPMI_API2F	; Izit Vendor-Specific API Entry Point request?
	jne	short INT2F_INTRETPM2 ; Jump if not

	PUSHW	ds		; Pass caller's DS (as word)
	push	esi		; ...		ESI
	FCALL	DPMIFN_CHKVSAPI ; Izit our string?
	assume	es:nothing	; Tell the assembler about it
	jne	short INT2F_INTRETPM2 ; Jump if it's not us

	mov	al,0		; Tell 'em it's a match

	iretd			; Return to caller (PM only)


INT2F_INTRETPM2:
	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

; Check for Windows calling us to ask for XMS presence
; from a DPMI client.  In order to get KRNL386 to run
; under our DPMI services, we must fail this call.

	cmp	ax,4300h	; Izit XMS presence detection?
	jne	short INT2F_INTRETPM3 ; Jump if not

	test	I31_FLAG,mask $I31_KRNL ; Izit Windows?
	jz	short INT2F_INTRETPM3 ; Jump if not

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Return to caller (PM only)


	assume	ds:DGROUP	; Tell the assembler about it
INT2F_INTRETPM3:

; Check for Windows asking for a read-write selector to the LDT

	cmp	ax,1688h	; Izit get read-write LDT selector?
	jne	short INT2F_INTRETPM4 ; Jump if not

; Return the LDT selector in BX at DPMI CPL

	mov	bx,DTE_DATALDT or (mask $TI) ; Return it
	or	bl,DPMI_CPL	; Plus DPMI CPL/RPL
	xor	ax,ax		; Tell 'em we succeeded

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Return to caller (PM only)


	assume	ds:DGROUP	; Tell the assembler about it
INT2F_INTRETPM4:

; Check for Windows asking if Windows/386 is running.
; In order to come up in 386 Enhanced Mode, we must
; respond to this call.

	cmp	ax,1600h	; Izit Windows/386 installation check?
	jne	short INT2F_INTRETPM5 ; Jump if not

	test	I31_FLAG,mask $I31_KRNL ; Izit Windows?
	jz	short INT2F_INTRETPM5 ; Jump if not

	test	DPM_FLAG,mask $DPM_DPMISTD ; Force KRNL386 to come up in standard mode?
	jnz	short INT2F_INTRETPM5 ; Jump if so

	mov	ax,0003h	; Tell a lie

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Return to caller (PM only)


	assume	ds:DGROUP	; Tell the assembler about it
INT2F_INTRETPM5:

if @W9X
; Check for Win9x asking for VWIN32 Device Entry point

	cmp	ax,1684h	; Izit Get Device-Specific API Entry Point?
	jne	short INT2F_INTRETPM6 ; Jump if not

	test	I31_FLAG,mask $I31_KRNL ; Izit Windows?
	jz	short INT2F_INTRETPM6 ; Jump if not

	cmp	bx,002Ah	; Izit VWIN32?
	jne	short INT2F_INTRETPM6 ; Jump if not

	push	ebx		; Save for a moment

	lea	ebx,VWIN32_TAB	; Assume it's a 16-bit client

	cmp	DPMITYPE,@DPMITYPE16 ; Izit a 16-bit client?
	je	short @F	; Jump if so

	add	ebx,type VWIN32_TAB ; Skip to 32-bit entry point
	xor	edi,edi 	; Zero high-order word
@@:
	mov	di,DGROUP:[ebx] ; Get the offset

	pop	ebx		; Restore

	mov	es,DPMI_IDEF	; Get our interrupt selector
	assume	es:nothing	; Tell the assembler about it

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Return to caller (PM only)


	assume	ds:DGROUP	; Tell the assembler about it
INT2F_INTRETPM6:
endif

; Nobody handled this function, so we must reflect it to VM
; If there's a DPMI client active, use DPMI_REFINT;
; otherwise, use INTPROC2F.

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	je	short @F	; Jump if not

	mov	[esp].NRM_INTNO,4*2Fh + offset PGROUP:INTPROC00Z ; Mark as INT 2Fh

;;;;;;; jmp	DPMI_REFINT	; Reflect to VM
	jmp	INTxx_INTRETPM	; Reflect to VM


@@:
	jmp	INTPROC2F	; Reflect to VM


INT2F_INTRETVM:
; อออออออออออออออออออออVirtual mode INT 2Fh callsอออออออออออออออออออออออออออ

	cmp	ax,@DPMI_CPUMODE ; Izit DPMI mode check (PM vs VM)?
	jne	short @F	; Jump if not

	jmp	ERM_FVEC	; Return to caller with AX <> 0


@@:
	cmp	ax,@DPMI_GPME	; DPMI presence check?
	jne	near ptr INT2F_ORIG ; Jump if not

	pushad			; Save all EGP registers

	cld			; Ensure string ops forwardly
	mov	ebp,esp 	; SS:EBP ==> INT2F_STR

	REGSAVE <ds,gs> 	; Save registers

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	mov	gs,SEL_4GB	; Get AGROUP data selector
	assume	gs:AGROUP	; Tell the assembler about it

	call	DPMIPRES	; Check on DPMI presence

	jmp	short INT2F_EXIT ; Join common exit code


INT2F_ERR:
	or	[ebp].INT2F_EFL.ELO,mask $CF ; CF=1
INT2F_EXIT:
	REGREST <gs,ds> 	; Restore
	assume	ds:nothing,gs:nothing ; Tell the assembler

	popad			; Restore

	jmp	ERM_FVEC	; Return to caller


INT2F_ORIG:
	PUSHW	ds		; Save for a moment

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	push	OLDINT2F_FVEC.FSEL ; Pass selector
	push	OLDINT2F_FVEC.FOFF ; ...  offset

LINT2F_STR struc

	dd	?		; Return offset
	dw	?		; ...	 selector
LINT2F_DS dw	?		; Original DS

LINT2F_STR ends

	mov	ds,[esp].LINT2F_DS ; Restore
	assume	ds:nothing	; Tell the assembler about it

	retf			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT2F	endp			; End INT2F procedure
	NPPROC	RM2PM_DPMIPRES -- RM to PM DPMI Presence Check
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

RM to PM DPMI presence check

On entry:

SS:EBP	==>	RM2PM_STR

On exit:

|

; Setup the stack so that SS:EBP ==> INT2F_STR

	REGSAVE <ds,gs> 	; Save registers

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	mov	gs,SEL_4GB	; Get AGROUP data selector
	assume	gs:AGROUP	; Tell the assembler about it

	push	[ebp].RM2PM_EPRM.EPRM_GS.EDD;INTXX_GS w/filler
	push	[ebp].RM2PM_EPRM.EPRM_FS.EDD;...   FS w/filler
	push	[ebp].RM2PM_EPRM.EPRM_DS.EDD;...   DS w/filler
	push	[ebp].RM2PM_EPRM.EPRM_ES.EDD;...   ES w/filler
	push	[ebp].RM2PM_EPRM.EPRM_SS.EDD;...   SS w/filler
	push	[ebp].RM2PM_EPRM.EPRM_ESP  ; ...   ESP
	push	[ebp].RM2PM_EPRM.EPRM_EFL  ; ...   EFL
	push	[ebp].RM2PM_EPRM.EPRM_CS.EDD;...   CS w/filler
	push	[ebp].RM2PM_EPRM.EPRM_EIP  ; ...   EIP
	push	[ebp].RM2PM_EGP.PUSHAD_EAX ; ...   EAX
	push	[ebp].RM2PM_EGP.PUSHAD_ECX ; ...   EBX
	push	[ebp].RM2PM_EGP.PUSHAD_EDX ; ...   EDX
	push	[ebp].RM2PM_EGP.PUSHAD_EBX ; ...   EBX
	push	[ebp].RM2PM_EGP.PUSHAD_ESP ; ...   ESP
	push	[ebp].RM2PM_EGP.PUSHAD_EBP ; ...   EBP
	push	[ebp].RM2PM_EGP.PUSHAD_ESI ; ...   ESI
	push	[ebp].RM2PM_EGP.PUSHAD_EDI ; ...   EDI

	mov	eax,ebp 	; Copy old EBP
	mov	ebp,esp 	; SS:EBP ==> INTXX_STR
				; (nothing above INTXX_EFL is valid)
	push	eax		; Save old EBP
	call	DPMIPRES	; Call common subroutine
	pop	ebp		; Restore old EBP

	pop	[ebp].RM2PM_EGP.PUSHAD_EDI ; INTXX_EDI
	pop	[ebp].RM2PM_EGP.PUSHAD_ESI ; ...   ESI
	pop	[ebp].RM2PM_EGP.PUSHAD_EBP ; ...   EBP
	pop	[ebp].RM2PM_EGP.PUSHAD_ESP ; ...   ESP
	pop	[ebp].RM2PM_EGP.PUSHAD_EBX ; ...   EBX
	pop	[ebp].RM2PM_EGP.PUSHAD_EDX ; ...   EDX
	pop	[ebp].RM2PM_EGP.PUSHAD_ECX ; ...   ECX
	pop	[ebp].RM2PM_EGP.PUSHAD_EAX ; ...   EAX
	pop	[ebp].RM2PM_EPRM.EPRM_EIP  ; ...   EIP
	pop	[ebp].RM2PM_EPRM.EPRM_CS.EDD;...   CS w/filler
	pop	[ebp].RM2PM_EPRM.EPRM_EFL  ; ...   EFL
	pop	[ebp].RM2PM_EPRM.EPRM_ESP  ; ...   ESP
	pop	[ebp].RM2PM_EPRM.EPRM_SS.EDD;...   SS w/filler
	pop	[ebp].RM2PM_EPRM.EPRM_ES.EDD;...   ES w/filler
	pop	[ebp].RM2PM_EPRM.EPRM_DS.EDD;...   DS w/filler
	pop	[ebp].RM2PM_EPRM.EPRM_FS.EDD;...   FS w/filler
	pop	[ebp].RM2PM_EPRM.EPRM_GS.EDD;...   GS w/filler

	REGREST <gs,ds> 	; Restore
	assume	ds:nothing,gs:nothing ; Tell the assembler

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

RM2PM_DPMIPRES endp		; End RM2PM_DPMIPRES procedure
	NPPROC	DPMIPRES -- DPMI Presence Detection
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI presence detection

On entry:

AX	=	1687
SS:EBP	==>	INT2F_STR

On exit:

AX	=	0
BX	=	1 (32-bit apps supported)
CL	=	CPU type (02 = 286, 03 = 386, 04 = 486, etc.)
DH	=	DPMI major version # (in decimal)
DL	=	...  minor ...
SI	=	# paras in host private data area
ES:DI	==>	VM -> PM entry point

|

;;;;;;; call	IMM2_USEVCPI	; Check for DOS extenders better off with VCPI
;;;;;;; jnc	short DPMIPRES_EXIT ; Jump if no match
;;;;;;;
	and	[ebp].INT2F_EFL.ELO,not (mask $CF) ; CF=0

	mov	[ebp].INT2F_EGP.PUSHAD_EBX.ELO,@BIT0 ; BX = 1 (we support 32-bit apps)
	mov	al,CPUTYPE	; Get the CPU type
	mov	[ebp].INT2F_EGP.PUSHAD_ECX.ELO.LO,al ; Return in CL

; Because of a bug in certain Rational Systems-based programs,
; we need to check for their signature and return version 0.90
; instead of 1.00.  These programs actually test the major DPMI
; version # and take a different path if it's 1.00.  Of course,
; the path they take has never been tested (we're the first DPMI
; 1.00 host), and (of course) the code on that path doesn't work.

	mov	ax,0100h	; We're thoroughly modern

	call	IZIT_RATIONAL	; Izit Rational Systems, Inc.?
	jc	short DPMIPRES1 ; No, but it makes sense

	or	PDC_FLAG,mask $I31_RSI ; Mark as Rational Systems, Inc.

	jmp	short DPMIPRES2 ; Join common code


DPMIPRES1:
	test	PDC_FLAG,mask $I31_VER090 ; Time to lie?
	jz	short DPMIPRES3 ; Jump if not
DPMIPRES2:
	test	DPM_FLAG,mask $DPM_DPMIV100 ; Should we force version 1.00?
	jnz	short DPMIPRES3 ; Jump if so

	mov	ax,005Ah	; Use the back level version (0.90)
DPMIPRES3:
	mov	[ebp].INT2F_EGP.PUSHAD_EDX.ELO.HI,ah ; Save major version #
	mov	[ebp].INT2F_EGP.PUSHAD_EDX.ELO.LO,al ; ...  minor ...

	mov	ax,HPDA_NPAR	; Get size of HPDA in paras
	mov	[ebp].INT2F_EGP.PUSHAD_ESI.ELO,ax ; # paras in HPDA

	mov	eax,VM2PM_VEC	; Get Seg:Off of DPMI_RVM2PM
	mov	[ebp].INT2F_EGP.PUSHAD_EDI.ELO,ax ; Return offset in caller's DI
	shr	eax,16		; Shift down the high-order word (segment)
	mov	[ebp].INT2F_ES,ax ; Return segment in caller's ES

	mov	[ebp].INT2F_EGP.PUSHAD_EAX.ELO,0 ; Result in AX is zero
DPMIPRES_EXIT:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIPRES endp			; End DPMIPRES procedure
;;;	     NPPROC  IMM2_USEVCPI -- Check for DOS Extenders For VCPI
;;;	     assume  ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;; COMMENT|
;;;
;;; Check for DOS extenders which would be better off using VCPI.
;;;
;;; On entry:
;;;
;;; SS:EBP   ==>     INT2F_STR
;;;
;;; On exit:
;;;
;;; CF	     =	     0 if we have a match and should fail the 1687 call
;;;	     =	     1 otherwise
;;;
;;; |
;;;
;;;	     pushad		    ; Save all EGP registers
;;;	     REGSAVE <es,fs>	    ; Save selectors
;;;
;;;	     test    DPM_FLAG,mask $DPM_DPMIXCOPY ; Should we disregard copyright notices?
;;;	     jnz     near ptr IMM2_USEVCPI_NOMATCH ; Jump if so
;;;
;;; ; Because the alternative is to use VCPI, we had better be sure
;;; ; we're providing those services.
;;;
;;; ;;;;;;;; test    LCL_FLAG,@LCL_DRV ; Another EMS driver present?
;;; ;;;;;;;; jnz     near ptr IMM2_USEVCPI_NOMATCH ; Jump if so
;;; ;;;;;;;;
;;;	     mov     es,SEL_4GB     ; Get AGROUP data selector
;;;	     assume  es:AGROUP	    ; Tell the assembler about it
;;;
;;;	     mov     fs,SEL_DATA    ; Get DGROUP data selector
;;;	     assume  fs:DGROUP	    ; Tell the assembler about it
;;;
;;; ; Check for Foxpro DOS extender which has the error message
;;; ; MSG_FOXCOMPAT at DS:007E.
;;;
;;;	     movzx   edi,[ebp].INT2F_DS ; Get caller's DS
;;;	     shl     edi,4-0	    ; Convert from paras to bytes
;;;	     add     edi,007Eh	    ; Plus magic offset
;;;
;;;	     lea     esi,MSG_FOXCOMPAT ; DGROUP:ESI ==> string to match
;;;	     mov     ecx,MSG_FOXCOMPAT_LEN ; ECX = length of ...
;;;	repe cmps    MSG_FOXCOMPAT[esi].LO,AGROUP:[edi].LO ; Duzit match?
;;;	     je      near ptr IMM2_USEVCPI_EXIT ; Jump if so (note CF=0)
;;;
;;;	     call    IZIT_RATIONAL  ; Izit Rational Systems, Inc.?
;;;	     jnc     short IMM2_USEVCPI_EXIT ; Jump if so (note CF=0)
;;;
;;; ; Check for Phar Lap copyright message at PSP:0100 with either
;;; ; 'P3', 'P5', or 'P6' at PSP:PHARLAP_CFG_ESIG
;;;
;;;	     DOSCALL @GETPS0	    ; Get PSP into BX
;;;
;;;	     push    ebx	    ; Pass selector as argument as dword
;;;	     call    GETBASE	    ; Return with EAX = base address of selector
;;;
;;;	     mov     edi,eax	    ; Copy to string register
;;;
;;; PHARLAP_CFGBLK_STR struc
;;;
;;;	     db      100h dup (?)   ; The PSP
;;; PHARLAP_CFG_COPYRIGHT db 32h dup (?) ; Their copyright notice
;;; PHARLAP_CFG_TYPE	  dw ?	    ; Configuration type block
;;; PHARLAP_CFG_RSRV1	  dw ?	    ; Reserved
;;; PHARLAP_CFG_RSRV2	  dw ?	    ; Reserved
;;; PHARLAP_CFG_ESIG	  dw ?	    ; .EXE file signature
;;;
;;; PHARLAP_CFGBLK_STR ends
;;;
;;;	     cmp     AGROUP:[edi].PHARLAP_CFG_ESIG,'3P' ; Izit 'P3'?
;;;	     je      short @F	    ; Jump if so
;;;
;;;	     cmp     AGROUP:[edi].PHARLAP_CFG_ESIG,'5P' ; Izit 'P5'?
;;;	     je      short @F	    ; Jump if so
;;;
;;;	     cmp     AGROUP:[edi].PHARLAP_CFG_ESIG,'6P' ; Izit 'P6'?
;;;	     jne     short IMM2_USEVCPI_NOMATCH ; Jump if not
;;; @@:
;;;	     lea     edi,AGROUP:[edi].PHARLAP_CFG_COPYRIGHT ; AGROUP:EDI ==> copyright notice
;;;	     lea     esi,MSG_PHARLAP ; DGROUP:ESI ==> string to match
;;;	     mov     ecx,MSG_PHARLAP_LEN ; ECX = length of ...
;;;
;;;	repe cmps    MSG_PHARLAP[esi].LO,AGROUP:[edi].LO ; Duzit match?
;;;	     je      short IMM2_USEVCPI_EXIT ; Jump if so (note CF=0)
;;; IMM2_USEVCPI_NOMATCH:
;;;	     stc		    ; Mark as no match
;;; IMM2_USEVCPI_EXIT:
;;;	     REGREST <fs,es>	    ; Restore
;;;	     assume  es:nothing,fs:nothing ; Tell the assembler about it
;;;	     popad		    ; Restore
;;;
;;;	     ret		    ; Return to caller
;;;
;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;
;;; IMM2_USEVCPI endp		    ; End IMM2_USEVCPI procedure
	NPPROC	IZIT_RATIONAL -- Check For Rational Systems, Inc.
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Check for the three different Rational Systems copyright notices
each of which is at DS3:XXXX where XXXX is the word at DS3:0030.

On entry:

SS:EBP	==>	INT2F_STR

On exit:

CF	=	0 if it's a Rational Systems, Inc based program
	=	1 otherwise

|

	REGSAVE <eax,ecx,esi,edi,es,fs> ; Save registers

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

	mov	fs,SEL_DATA	; Get DGROUP data selector
	assume	fs:DGROUP	; Tell the assembler about it

	movzx	edi,[ebp].INT2F_DS ; Get caller's DS
	shl	edi,4-0 	; Convert from paras to bytes
	movzx	eax,AGROUP:[edi+0030h].ELO ; Get word ptr at DS:0030h
	add	edi,eax 	; AGROUP:EDI ==> copyright string (if present)

	lea	esi,MSG_RATIONAL1 ; DGROUP:ESI ==> string to match
	mov	ecx,MSG_RATIONAL1_LEN ; ECX = length of ...

	mov	MSG_RATIONAL1A,'0' ; Try '1990'

	REGSAVE <ecx,esi,edi>	; Save for a moment
   repe cmps	MSG_RATIONAL1[esi].LO,AGROUP:[edi].LO ; Duzit match?
	REGREST <edi,esi,ecx>	; Restore
	je	short IZIT_RATIONAL_EXIT ; Jump if so (note CF=0)

	mov	MSG_RATIONAL1A,'1' ; Try '1991'

	REGSAVE <ecx,esi,edi>	; Save for a moment
   repe cmps	MSG_RATIONAL1[esi].LO,AGROUP:[edi].LO ; Duzit match?
	REGREST <edi,esi,ecx>	; Restore
	je	short IZIT_RATIONAL_EXIT ; Jump if so (note CF=0)

	lea	esi,MSG_RATIONAL2 ; DGROUP:ESI ==> string to match
	mov	ecx,MSG_RATIONAL2_LEN ; ECX = length of ...

   repe cmps	MSG_RATIONAL2[esi].LO,AGROUP:[edi].LO ; Duzit match?
	je	short IZIT_RATIONAL_EXIT ; Jump if so (note CF=0)

	stc			; Mark as not Rational, but sensible
IZIT_RATIONAL_EXIT:
	REGREST <fs,es,edi,esi,ecx,eax> ; Restore
	assume	es:nothing,fs:nothing ; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

IZIT_RATIONAL endp		; End IZIT_RATIONAL procedure
if @W9X
	FPPROC	VWIN32_API -- VWIN32 API Device Entry Point
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

VWIN32 API device entry point

On entry:

AH	=	function #

On exit:

CF	=	0 if successful
	=	1 it nof

|

	cmp	ah,VWIN32_GET_VER ; Izit Get Version #?
	jne	short VWIN32_API1 ; Jump if not

	mov	ax,0100h	; Return version #

	jmp	near ptr VWIN32_API_CLC ; Join common CLC code


VWIN32_API1:
	cmp	ah,VWIN32_MMGR_FUNCTIONS ; Izit Memory Manager functions?
	jne	near ptr VWIN32_API2 ; Jump if not


VWIN32_ALLOC_STK_STR struc

VWIN32_ALLOC_STK_EGP db (type PUSHAD_STR) dup (?) ; Caller's EGP
	dd	?		; EFL
VWIN32_ALLOC_STK_RETFDPI db (type RETFDPI_STR) dup (?) ; Caller's RETFDPI_STR

VWIN32_ALLOC_STK_STR ends


COMMENT|

Allocate address space/memory

On exit:

AL	=	00 Reserve pages	Stack = ECX/4 dwords of VWIN_ALLOC00_STR
	=	01 Commit pages 	Stack = ECX/4 dwords of VWIN_ALLOC01_STR
	=	02 Decommit pages
	=	03 Free pages
ECX	=	# bytes used on the PL3 stack

On exit:

if AL == 00
EAX	=	linear address
elseif AL == 1


endif

CF	=	0 if successful
	=	1 if not

|

	cmp	ax,VWIN32_MMGR_RESERVE	; Izit Reserve pages?
	je	short VWIN32_API_ALLOC00 ; Jump if so

	cmp	ax,VWIN32_MMGR_COMMIT	; Izit Commit pages?
	je	near ptr VWIN32_API_ALLOC01 ; Jump if so

	cmp	ax,VWIN32_MMGR_DECOMMIT ; Izit Decommit pages?
	je	near ptr VWIN32_API_ALLOC02 ; Jump if so

	cmp	ax,VWIN32_MMGR_PAGEFREE ; Izit Free pages?
	je	near ptr VWIN32_API_ALLOC03 ; Jump if so

	int	03h		; Unknown subfunction

	jmp	VWIN32_API_ERR	; Join common error code


VWIN32_ALLOC00_STR struc

VWIN32_ALLOC00_LADDR dd ?	; Linear address to reserve (or PR_xxx)
VWIN32_ALLOC00_NPAGE dd ?	; # 4KB pages to reserve
VWIN32_ALLOC00_FLAGS dd ?	; Flags (PR_xxx)

VWIN32_ALLOC00_STR ends


; Reserve pages as described by VWIN32_ALLOC00_STR


VWIN32_API_ALLOC00:
	pushad			; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <ds,es> 	; Save registers

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

	movzx	edx,[ebp].VWIN32_ALLOC_STK_RETFDPI.RETFDPI_ESP.ELO ; Get offset of caller's PL3 stack
	mov	bx,[ebp].VWIN32_ALLOC_STK_RETFDPI.RETFDPI_SS ; Get caller's PL3 stack selector

	push	ebx		; Pass selector as argument as dword
	call	GETBASE 	; Return with EAX = base address of selector

	add	edx,eax 	; Add to get linear address caller's PL3 stack

	add	edx,@VSAPI_DDSTKSIZE*4+4+(type RETF_STR) ; Skip to VWIN32_ALLOC00_STR
	mov	ebx,AGROUP:[edx].VWIN32_ALLOC00_LADDR ; Get linear address

; Split out PR_xxx cases

	cmp	ebx,PR_PRIVATE	; Izit to be reserved in private memory?
	je	short VWIN32_ALLOC00_ERR1 ; Jump if so

	cmp	ebx,PR_SHARED	; Izit to be reserved in shared memory?
	je	short VWIN32_ALLOC00_SHARED ; Jump if so

	cmp	ebx,PR_SYSTEM	; Izit to be reserved in system memory?
	je	short VWIN32_ALLOC00_ERR2 ; Jump if so

; Split out non-zero flags

	cmp	AGROUP:[edx].VWIN32_ALLOC00_FLAGS,0 ; Flags all inactive?
	jne	short VWIN32_ALLOC00_ERR3 ; Jump if not

	mov	ecx,AGROUP:[edx].VWIN32_ALLOC00_NPAGE ; Get # 4KB pages to reserve
	shl	ecx,12-0	; Convert from 4KB to bytes
	xor	edx,edx 	; Flags:  uncommitted

	DPMICALL @DPMI_GETLMB	; Allocate an uncommitted LMB
				; Return with CF significant
	jnc	short @F	; Jump if it succeeded
VWIN32_ALLOC00_ERR:
	mov	ebx,-1		; Mark as in error
;;;;;;; stc			; Mark as in error (already set)
@@:
	jmp	short VWIN32_ALLOC00_DONE ; Join common done code


; Allocate shared memory

VWIN32_ALLOC00_SHARED:
	cmp	AGROUP:[edx].VWIN32_ALLOC00_FLAGS,0 ; Flags all inactive?
	je	short @F	; Jump if so

	int	03h		; Call our debugger
@@:
	mov	ebx,AGROUP:[edx].VWIN32_ALLOC00_NPAGE ; Get # 4KB pages to reserve
	xor	eax,eax 	; Alloc at any address
	mov	ecx,		      (mask $shared) ; Set flags:  Shared & Committed
;;;;;;; mov	ecx,(mask $commit) or (mask $shared) ; Set flags:  Shared & Committed
	call	VMM_ALLOC	; Allocate the memory
	jc	short VWIN32_ALLOC00_ERR4 ; Bail on fail

	mov	ebx,eax 	; Return to caller

;;;;;;; clc			; Mark as successful (already clear)
VWIN32_ALLOC00_DONE:
	mov	[ebp].VWIN32_ALLOC_STK_EGP.PUSHAD_EAX,ebx ; Save as return LA
				; CF still significant
	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	popad			; Restore
				; CF still significant
	jmp	VWIN32_API_ALLOC_COM ; Join common exit code (note CF significant)


VWIN32_ALLOC00_ERR1:
	int	03h		; Call our debugger
VWIN32_ALLOC00_ERR2:
	int	03h		; Call our debugger
VWIN32_ALLOC00_ERR3:
	int	03h		; Call our debugger
VWIN32_ALLOC00_ERR4:
	int	03h		; Call our debugger

	jmp	VWIN32_ALLOC00_ERR ; Join common error code


VWIN32_ALLOC01_STR struc

VWIN32_ALLOC01_LADDR dd ?	; Linear address to commit
VWIN32_ALLOC01_NPAGE dd ?	; # 4KB pages to commit
VWIN32_ALLOC01_HPAGE dd ?	; Handle of registered pager (or PD_xxx)
VWIN32_ALLOC01_DPAGE dd ?	; Pager data (zero if HPAGE is PD_xxx)
VWIN32_ALLOC01_FLAGS dd ?	; Flags (PC_xxx)

VWIN32_ALLOC01_STR ends


; Commit pages as described by VWIN32_ALLOC01_STR

VWIN32_API_ALLOC01:
	pushad			; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <ds,es> 	; Save registers

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

	movzx	edx,[ebp].VWIN32_ALLOC_STK_RETFDPI.RETFDPI_ESP.ELO ; Get offset of caller's PL3 stack
	mov	bx,[ebp].VWIN32_ALLOC_STK_RETFDPI.RETFDPI_SS ; Get caller's PL3 stack selector

	push	ebx		; Pass selector as argument as dword
	call	GETBASE 	; Return with EAX = base address of selector

	add	edx,eax 	; Add to get linear address caller's PL3 stack

	add	edx,@VSAPI_DDSTKSIZE*4+4+(type RETF_STR) ; Skip to VWIN32_ALLOC00_STR
	mov	eax,AGROUP:[edx].VWIN32_ALLOC01_LADDR ; Get linear page #
	shl	eax,12-0	; Convert from 4KB to bytes
	mov	ebx,AGROUP:[edx].VWIN32_ALLOC01_FLAGS ; Get flags
	mov	ecx,AGROUP:[edx].VWIN32_ALLOC01_NPAGE ; Get # 4KB to commit
	jecxz	VWIN32_API_ALLOC01_DONE ; Jump if no pages

COMMENT|

The incoming HPAGE values are

PD_ZEROINIT	Swappable zero-initialized.
PD_NOINIT	Swappable unintialized.
PD_FIXED	Fixed uninitialized (must also pass in PC_FIXED flag).
PD_FIXEDZERO	Fixed zero-initialized (must also pass in PC_FIXED flag).

|

COMMENT|

The incoming FLAGS are

PC_FIXED	The pages are permanently locked.
PC_LOCKED	The pages are initially present and locked.
PC_LOCKEDIFDP	The pages are locked only if the virtual pageswap
		  device uses MS-DOS or BIOS functions to write
		  pages to the hardware.
PC_STATIC	The pages are committed even if the linear addresses
		  were reserved using the PR_STATIC flag.
PC_USER 	The pages are accessible at ring 3.
PC_WRITEABLE	The pages are writeable.
PC_INCR 	Increments the pager-defined 32-bit value associated
		  with each page in the specified range.

The only bits we use are PC_FIXED, PC_LOCKED, and PC_WRITEABLE.

|

; Translate the flags in EBX to flags for VMM_SET_ONEATTR

	mov	esi,@SPTYP_COM shl $SPATTR_TYP ; Initialize flags to Commit

	test	ebx,PC_WRITEABLE ; Izit writeable?
	jz	short @F	; Jump if so

	or	esi,@SPATTR_RW	; Mark as Read/Write
@@:
VWIN32_API_ALLOC01_NEXT:
	push	eax		; Pass the address
	push	esi		; ...	   attributes (as a dword)
	call	VMM_SET_ONEATTR ; Set one page attribute
	jc	short VWIN32_API_ALLOC01_ERR ; Jump if error (note CF=1)

; Lock the page if PC_FIXED or PC_LOCKED

	test	ebx,PC_FIXED or PC_LOCKED ; Lock it?
	jz	short @F	; Jump if not

	int	03h		; *FIXME*
@@:

; Zero the page if PD_ZEROINIT or PD_FIXEDZERO

	cmp	AGROUP:[edx].VWIN32_ALLOC01_HPAGE,PD_ZEROINIT ; Zero it?
	je	short @F	; Jump if so

	cmp	AGROUP:[edx].VWIN32_ALLOC01_HPAGE,PD_FIXEDZERO ; Zero it?
	jne	short VWIN32_API_ALLOC01_LOOP ; Jump if not
@@:
	call	VMM_ZERO_PAGE	; Zap the page at EAX
VWIN32_API_ALLOC01_LOOP:
	add	eax,4*1024	; SKip to next 4KB page

	loop	VWIN32_API_ALLOC01_NEXT ; Jump if more pages to commit
VWIN32_API_ALLOC01_DONE:
	clc			; Mark as successful

	jmp	short VWIN32_API_ALLOC01_EXIT ; Join common exit code


VWIN32_API_ALLOC01_ERR:
	mov	[ebp].VWIN32_ALLOC_STK_EGP.PUSHAD_EAX,0 ; Mark as in error

	stc			; Mark as in error
VWIN32_API_ALLOC01_EXIT:
	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	popad			; Restore
				; CF still significant
	jmp	short VWIN32_API_ALLOC_COM ; Join common exit code


VWIN32_ALLOC02_STR struc

VWIN32_ALLOC02_LADDR dd ?	; Linear address to decommit
VWIN32_ALLOC02_NPAGE dd ?	; # 4KB pages to decommit
VWIN32_ALLOC02_FLAGS dd ?	; Flags (zero)

VWIN32_ALLOC02_STR ends


; Decommit pages as described by VWIN32_ALLOC02_STR

VWIN32_API_ALLOC02:
	pushad			; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	int	03h

	push	ds		; Save register

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	mov	ds,SEL_4GB	; Get AGROUP data selector
	assume	ds:AGROUP	; Tell the assembler about it

	movzx	edx,[ebp].VWIN32_ALLOC_STK_RETFDPI.RETFDPI_ESP.ELO ; Get offset of caller's PL3 stack
	mov	bx,[ebp].VWIN32_ALLOC_STK_RETFDPI.RETFDPI_SS ; Get caller's PL3 stack selector

	push	ebx		; Pass selector as argument as dword
	call	GETBASE 	; Return with EAX = base address of selector

	add	edx,eax 	; Add to get linear address caller's PL3 stack

	add	edx,@VSAPI_DDSTKSIZE*4+4+(type RETF_STR) ; Skip to VWIN32_ALLOC00_STR
	mov	ebx,AGROUP:[edx].VWIN32_ALLOC02_LADDR ; Get linear address






	clc			; Mark as successful

	jmp	short VWIN32_API_ALLOC02_EXIT ; Join common exit code


VWIN32_API_ALLOC02_ERR:
	mov	[ebp].VWIN32_ALLOC_STK_EGP.PUSHAD_EAX,0 ; Mark as in error

	stc			; Mark as in error
VWIN32_API_ALLOC02_EXIT:
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	popad			; Restore
				; CF still significant
	jmp	short VWIN32_API_ALLOC_COM ; Join common exit code


VWIN32_ALLOC03_STR struc

VWIN32_ALLOC03_LADDR dd ?	; Linear address to free
VWIN32_ALLOC03_FLAGS dd ?	; Flags (zero)

VWIN32_ALLOC03_STR ends


; Free pages as described by VWIN32_ALLOC03_STR

VWIN32_API_ALLOC03:
	pushad			; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	int	03h

	push	ds		; Save register

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	mov	ds,SEL_4GB	; Get AGROUP data selector
	assume	ds:AGROUP	; Tell the assembler about it

	movzx	edx,[ebp].VWIN32_ALLOC_STK_RETFDPI.RETFDPI_ESP.ELO ; Get offset of caller's PL3 stack
	mov	bx,[ebp].VWIN32_ALLOC_STK_RETFDPI.RETFDPI_SS ; Get caller's PL3 stack selector

	push	ebx		; Pass selector as argument as dword
	call	GETBASE 	; Return with EAX = base address of selector

	add	edx,eax 	; Add to get linear address caller's PL3 stack

	add	edx,@VSAPI_DDSTKSIZE*4+4+(type RETF_STR) ; Skip to VWIN32_ALLOC00_STR
	mov	ebx,AGROUP:[edx].VWIN32_ALLOC03_LADDR ; Get linear address






	clc			; Mark as successful

	jmp	short VWIN32_API_ALLOC03_EXIT ; Join common exit code


VWIN32_API_ALLOC03_ERR:
	mov	[ebp].VWIN32_ALLOC_STK_EGP.PUSHAD_EAX,0 ; Mark as in error

	stc			; Mark as in error
VWIN32_API_ALLOC03_EXIT:
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	popad			; Restore
				; CF still significant
;;;;;;; jmp	short VWIN32_API_ALLOC_COM ; Join common exit code


VWIN32_API_ALLOC_COM:
	pushfd			; Save flags (CF in particular)

	REGSAVE <eax,ds>	; Save for a moment

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	mov	eax,LaPMIDEF	; Get linear address of PMIDEF

	mov	ds,SEL_4GB	; Get AGROUP data selector
	assume	ds:AGROUP	; Tell the assembler about it

	mov	AGROUP:[eax+PMVWIN32_16C+2],cx ; Strip from the stack
				; The +2 is for 66 CA
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	popfd			; Restore
				; CF significant
	mov	[esp].IRETD_EIP,PMVWIN32_16B ; New return address
	jc	short VWIN32_API_ERR ; Jump if something went wrong

	jmp	short VWIN32_API_CLC ; Join common CLC code


VWIN32_API2:
	cmp	ah,VWIN32_PDB_INFO ; Izit PDB info?
	jne	short VWIN32_API3 ; Jump if not

	int	01h

	mov	al,00h		; Return unknown value

	jmp	short VWIN32_API_CLC ; Join common CLC code


VWIN32_API3:
	cmp	ah,VWIN32_EVENT_CREATE ; Izit Event Create?
	jne	short VWIN32_API4 ; Jump if not

	int	01h





	jmp	short VWIN32_API_CLC ; Join common CLC code


VWIN32_API4:
	int	03h		; Unknown function

;;;;;;; jmp	short VWIN32_API_ERR ; Join common error code


VWIN32_API_ERR:
	or	[esp].IRETD_EFL,mask $CF ; Mark as in error

	jmp	short VWIN32_API_EXIT ; Join common exit code


VWIN32_API_CLC:
	and	[esp].IRETD_EFL,not (mask $CF) ; Mark as successful
VWIN32_API_EXIT:
	iretd			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

VWIN32_API endp 		; End VWIN32_API procedure
endif

PROG	ends			; End PROG segment

	MEND			; End DPMI_I2F module
