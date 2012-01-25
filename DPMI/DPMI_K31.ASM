;' $Header$
	title	DPMI_K31 -- DPMI.LOD INT 31h Additional Routines
	page	58,122
	name	DPMI_K31
COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1991-2004 Qualitas, Inc.  All Rights Reserved.

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include PTR.INC
	include CPUFLAGS.INC
	include ALLMEM.INC
	include OPCODES.INC
	include DPMI.INC
	include MASM5.MAC
	include INTVEC.INC
	include BITFLAGS.INC
	include CPUFET2.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_EXP.INC
	include DPMI_SEG.INC
	include DPMI_SWT.INC

	include QMAX_DYN.INC
	include QMAX_TSS.INC
	include QMAX_VMM.INC
	include QMAX_I31.INC		; Must precede QMAXDPMI.INC
	include QMAXDPMI.INC		; Must follow QMAX_I31.INC
.list

FlushTLB	MACRO reg		; flush TLB by reloading CR3
	mov	reg, CR3
	mov	CR3, reg
	ENDM


CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
	assume	cs:PGROUP,ds:PGROUP

	extrn	INTPROC00Z:near

	extrn	ERM_FVEC:fword
	extrn	GXTHDR:tbyte
	include GXT_HDR.INC

CODE16A ends			; End CODE16A segment


DATA16	segment use16 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	extrn	CPUFET_FLAG:dword

DATA16	ends			; End DATA16 segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_K31_DATA
@DPMI_K31_DATA	label byte	; Mark module start in .MAP file

	include DPMI_LCL.INC
	extrn	LCL_FLAG:word

	extrn	SEL_4GB:word
	extrn	SEL_DATA:word

	extrn	I31_FLAG:word

	extrn	LAST_DPMI_FS:word
	extrn	LAST_DPMI_GS:word
	extrn	LAST_INTCOM:dword
	extrn	LAST_INTFLG:dword

	extrn	PVMTSS:dword
	extrn	PPRMTSS:dword
	extrn	PCURTSS:dword
	extrn	VM2PM_TSS:word
	extrn	DPMITYPE:byte
	extrn	CON64KB:dword
	extrn	LPMSTK_FVEC:fword
	extrn	LPMSTK_CNT:dword
	extrn	LaSIRBCUR:dword
	extrn	LaIOBIT:dword

	extrn	DPMI_PPIHOOK:byte
	extrn	DPMI_CPIHOOK:byte
	extrn	DPMI_CPFHOOK:byte
	extrn	DPMI_PVFHOOK:byte
	extrn	DPMI_CVFHOOK:byte

	extrn	DPMICNT0D:word
	extrn	DPMICNT0E:word

	extrn	HPDAVMC_CNT:word
	extrn	HPDAVMC_OFF:word

	extrn	DPMI_IDEF:word
	extrn	DPMI_CPL:byte

;;;;;;; extrn	PPL0STK_MAX:dword
;;;;;;; extrn	PLCL_PL0CUR:dword
;;;;;;;
	extrn	DPMITYPEIG:byte

	extrn	PMINT_DVECS:dword
	extrn	PMINT_FVECS:fword
	extrn	PMFLT_DVECS:dword
	extrn	PMFLT_FVECS:fword
	extrn	VMFLT_DVECS:dword
	extrn	VMFLT_FVECS:fword

;;;;	extrn	PageDirLA:dword
	extrn	VMMCurrentClient:word

	public	OLD_PCURTSS
OLD_PCURTSS dd	?		; Save area for old PCURTSS in case nested

	public	DPMI_STKFLG
DPMI_STKFLG dw	?		; 2 = far return frame
				; 3 = IRET frame

DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_K31_PROG
@DPMI_K31_PROG: 		; Mark module start in .MAP file

	extrn	GETBASE:near
	extrn	SETBASE:near
%	extrn	INTPROC&@PMH_INT:near
	extrn	SET_PPL0STK:near
	extrn	TellGXT_CR3:near

	extrn	VALID_LSEL:near
	extrn	GET_LDT:near
	extrn	CLR_LDTZERO:near
	extrn	SETLBASE:near
	extrn	DPMIFN_GETDYN:near
;;;;;;; extrn	DPMI_REFRET:near
	extrn	DPMI_MEI:near
	extrn	DPMI_PDBI:near
	extrn	FLTPROC_VMFULL:near
	extrn	FLTPROC_LPMFULL:near

	extrn	PMIDEF_SSR16:abs
	extrn	PMIDEF_SSR32:abs
	extrn	PMVMCB:abs
	extrn	PMIRMS:abs

	extrn	INT31_CLC:near
	extrn	INT31_ERR_NOVMC:near
	extrn	INT31_ERR_INVVMC:near
	extrn	INT31_ERR_INVSEL:near
	extrn	INT31_ERR_INVVAL:near

	extrn	DPMIFN_LMSW:near
	extrn	DPMIFN_LPMSTK:near

	extrn	DPMIFN_SAVEOLDPM:near
	extrn	DPMIFN_RESTOLDPM:near
if @EXPD
	extrn	DPMIFN_ESIMOD:near
	extrn	DPMIFN_CHKSTK:near
endif
	extrn	INT22DEF:near
	extrn	INT23DEF:near
	extrn	INT24DEF:near

	extrn	PHYS2MMLIN:near

	NPPROC	DPMI_GETVMIV -- DPMI 0.9 Function to Get VM Interrupt Vector
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 0.9 function to get VM interrupt vector

On entry (in INTXX_STR):

AX	=	0200h
BL	=	interrupt #
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

On exit (in INTXX_STR):

CF	=	0 if successful
CX:DX	=	Seg:Off of VM interrupt handler

All other registers except EBP, FS, GS, and SS may be clobbered.

|

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:INTVEC	; Tell the assembler about it

	movzx	eax,[ebp].INTXX_EBX.ELO.LO ; Get VM interrupt #
	mov	eax,INT00_VEC[eax*(type INT00_VEC)] ; Get Seg:Off of VM interrupt handler

	mov	[ebp].INTXX_EDX.ELO,ax ; Return offset portion in caller's DX
	shr	eax,16		; Shift down high-order word
	mov	[ebp].INTXX_ECX.ELO,ax ; Return segment portion in caller's CX

	jmp	INT31_CLC	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_GETVMIV endp		; End DPMI_GETVMIV procedure
	NPPROC	DPMI_SETVMIV -- DPMI 0.9 Function to Set VM Interrupt Vector
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 0.9 function to get VM interrupt vector

On entry (in INTXX_STR):

AX	=	0201h
BL	=	interrupt #
CX:DX	=	Seg:Off of VM interrupt handler
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

On exit (in INTXX_STR):

CF	=	0 if successful

All other registers except EBP, FS, GS, and SS may be clobbered.

|

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:INTVEC	; Tell the assembler about it

	mov	dx,[ebp].INTXX_ECX.ELO ; Get segment portion from caller's CX
	shl	edx,16		; Shift to high-order word
	mov	dx,[ebp].INTXX_EDX.ELO ; Get offset portion from caller's DX

	movzx	ebx,[ebp].INTXX_EBX.ELO.LO ; Get VM interrupt #
	xchg	edx,INT00_VEC[ebx*(type INT00_VEC)] ; Save as new VM interrupt handler

; The following code is commented out because when we save
; (and later restore) a VMIV some DPMI clients (at least
; Lotus 1-2-3 v3.1) has already put its handler in place
; before issuing this call and we see the new handler only,
; not the old one.  Thus, we can't restore the old one.
; Restoring VMIVs is the client's responsibility, not ours,
; but I put in this code originally knowing how well programs
; clean up after themselves.  In fact, Lotus 1-2-3 v3.1 hooks
; INT 00h and never restores it.  Moreover, they hook INT 00h
; before entering PM through us so we can't even save the original
; value at that point.	So, I decided that we shouldn't bother
; with this kind of cleanup.  Damn the torpedoes, ...

; VMIV cleanup, Part II:  Well, now that we're trying to excise
; faulting DPMI clients who exit out of order, I think it's a
; good idea to cleanup after DPMI clients who terminate by way
; of a fault.

; Save the original handler in the dynamic save area to restore later

	mov	edi,PCURTSS	; Get offset in DGROUP of current TSS
	mov	edi,DGROUP:[edi].DPTSS_DYN ; Get linear address of dynamic save area

	and	edi,edi 	; Izit present?
	jz	short DPMI_SETVMIV_EXIT ; Jump if not

	mov	si,VM2PM_TSS	; Get current TSS selector

; See if this exception # (in BL) already is present

	assume	es:AGROUP	; Tell the assembler about it
DPMI_SETVMIV_NEXT:
	cmp	AGROUP:[edi].DYNHDR_FN,@DYNFN_EOL ; Izit End-of-the-line?
	je	short DPMI_SETVMIV_NOTFND ; Jump if so

	cmp	si,AGROUP:[edi].DYNHDR_TSS ; Izit the same TSS selector?
	jne	short DPMI_SETVMIV_LOOP ; Jump if not

	cmp	AGROUP:[edi].DYNHDR_FN,@DYNFN_VMIV ; Izit our function code?
	jne	short DPMI_SETVMIV_LOOP ; Jump if not

	cmp	bl,AGROUP:[edi].DYNVMIV_NUM ; Izit same interrupt #?
	je	short DPMI_SETVMIV_EXIT ; Jump if so (already saved)
DPMI_SETVMIV_LOOP:
	movzx	eax,AGROUP:[edi].DYNHDR_LEN ; Get byte length of this entry
	add	edi,eax 	; Skip to next entry

	jmp	DPMI_SETVMIV_NEXT ; Go around again


; No matching entry -- make a new one

DPMI_SETVMIV_NOTFND:
	push	size DYNVMIV_STR ; Get size of this entry
	call	DPMIFN_GETDYN	; Allocate from dynamic save area
				; Return with AGROUP:EDI ==> our block
	jc	short DPMI_SETVMIV_EXIT ; Jump if there's no room (ignore it)

	mov	AGROUP:[edi].DYNHDR_FN,@DYNFN_VMIV ; Save new function code
	mov	AGROUP:[edi].DYNVMIV_VEC,edx ; Save to restore later
	mov	AGROUP:[edi].DYNVMIV_NUM,bl ; ...
DPMI_SETVMIV_EXIT:
	jmp	INT31_CLC	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_SETVMIV endp		; End DPMI_SETVMIV procedure
	NPPROC	DPMI_GETPEHV -- DPMI 0.9 Function to Get Processor Exception Handler Vector
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 0.9 function to get processor exception handler vector

On entry (in INTXX_STR):

AX	=	0202h/0210h
BL	=	exception # (00-1F)
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

On exit (in INTXX_STR):

CF	=	0 if successful
CX:eDX	=	sel:off of processor exception handler

CF	=	1 if not successful
AX	=	8021 if invalid value

All other registers except EBP, FS, GS, and SS may be clobbered.

|

	movzx	eax,[ebp].INTXX_EBX.ELO.LO ; Get exception #

	cmp	al,1Fh		; Check against maximum
	ja	near ptr INT31_ERR_INVVAL ; Jump if it's out of range

	mov	ds,SEL_DATA	; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	pushfd			; Save flags
	cli			; Disallow interrupts

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	short DPMI_GETPEHV16 ; Jump if so

	imul	eax,type PMFLT_FVECS ; Times size of FVECS

	mov	cx,PMFLT_FVECS.FSEL[eax] ; Get the selector
	mov	[ebp].INTXX_ECX.ELO,cx ; Return selector in caller's CX

	mov	edx,PMFLT_FVECS.FOFF[eax] ; Get the offset
	mov	[ebp].INTXX_EDX,edx ; Return offset in caller's EDX

	jmp	short DPMI_GETPEHV_COM ; Join common code


DPMI_GETPEHV16:
	imul	eax,type PMFLT_DVECS ; Times size of DVECS

	mov	cx,PMFLT_DVECS.VSEG[eax] ; Get the selector
	mov	[ebp].INTXX_ECX.ELO,cx ; Return selector in caller's CX

	mov	dx,PMFLT_DVECS.VOFF[eax] ; Get the offset
	mov	[ebp].INTXX_EDX.ELO,dx ; Return offset in caller's DX
DPMI_GETPEHV_COM:
	popfd			; Restore flags
				; (note interrupts might become enabled)
	jmp	INT31_CLC	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_GETPEHV endp		; End DPMI_GETPEHV procedure
	NPPROC	DPMIFN_CHKSEL -- Check Selector:Offset
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Check selector:offset

On entry (in INTXX_STR):

CX:eDX	=	sel:off of interrupt handler
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

On exit:

CF	=	0 if valid
CX:EDX	=	sel:off of interrupt handler
		 with high-order word of EDX fixed up
		 depending upon 16- or 32-bit client

CF	=	1 otherwise

|

	REGSAVE <ax>		; Save register

	mov	cx,[ebp].INTXX_ECX.ELO ; Get the selector from caller's CX
	mov	edx,[ebp].INTXX_EDX ; Get the offset from caller's EDX
	IF16ZX	dx		; Zero to use as dword if 16-bit client

; Validate the selector

; Because of Errata #15 on the B1-step of the 386, we must
; check for null GDT selectors separately

	test	cx,(mask $SEL) or (mask $TI) ; Izit null GDT selector?
	jz	short DPMIFN_CHKSEL_ERR ; Jump if so

	lar	ax,cx		; Get the selector's A/R byte
	jmp	short $+2	; Handle Errata #20
	jnz	short DPMIFN_CHKSEL_ERR ; Jump if it's invalid

	and	cx,not (mask $PL) ; Clear the PL bits
	or	cl,DPMI_CPL	; Ensure it's at DPMI CPL/RPL

; We allow present code and idle TSS selectors and task gates

	test	ah,mask $DT_P	; Izit present?
	jz	short DPMIFN_CHKSEL_ERR ; Jump if not

; Split off data selectors ($DT_DC set, $DC_COD clear)

	test	ah,mask $DT_DC	; Izit code/data?
	jz	short @F	; Jump if not

	test	ah,mask $DC_COD ; Izit code?
	jnz	short DPMIFN_CHKSEL_EXIT ; Jump if so (note CF=0)

	jmp	short DPMIFN_CHKSEL_ERR ; Jump if not


@@:

; Check for idle TSS selectors and task gates

	and	ah,not (mask $DT_DPL) ; Clear the DPL bits (to PL0)

	cmp	ah,CPL0_TASK ; Izit a task gate?
	je	short DPMIFN_CHKSEL_EXIT ; Jump if so (note CF=0)

	cmp	ah,CPL0_IDLE2 ; Izit an idle 286 TSS?
	je	short DPMIFN_CHKSEL_EXIT ; Jump if so (note CF=0)

	cmp	ah,CPL0_IDLE3 ; Izit an idle 386 TSS?
	je	short DPMIFN_CHKSEL_EXIT ; Jump if so (note CF=0)
DPMIFN_CHKSEL_ERR:
	stc			; Mark as invalid
DPMIFN_CHKSEL_EXIT:
	REGREST <ax>		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_CHKSEL endp		; End DPMIFN_CHKSEL procedure
	NPPROC	DPMI_SETPEHV -- DPMI 0.9 Function to Set Processor Exception Handler Vector
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 0.9 function to set processor exception handler vector

On entry (in INTXX_STR):

AX	=	0203h/0212h/0283h
BL	=	exception # (00-1F)
CX:eDX	=	sel:off of processor exception handler
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

On exit (in INTXX_STR):

CF	=	0 if successful

CF	=	1 if not successful
AX	=	8021 if invalid value
	=	8022 if invalid selector

All other registers except EBP, FS, GS, and SS may be clobbered.

|

	movzx	eax,[ebp].INTXX_EBX.ELO.LO ; Get exception #

	cmp	al,1Fh		; Check against maximum
	ja	near ptr INT31_ERR_INVVAL ; Jump if it's out of range

	call	DPMIFN_CHKSEL	; Get and check sel:off from CX:eDX
				; CX:EDX = sel:off of interrupt handler
	jc	near ptr INT31_ERR_INVSEL ; Jump if it's invalid

	mov	es,SEL_DATA	; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	mov	ebx,eax 	; Save interrupt #

	pushfd			; Save flags
	cli			; Disallow interrupts

; Set or clear the corresponding bit in DPMI_CPFHOOK depending upon
; whether or not the DPMI client is restoring this fault to
; our default handler or intercepting it for itself.

; Note we test the selector only, not the offset

	cmp	cx,DPMI_IDEF	; Izit our default handler?
	je	short DPMI_SETPEHV_CLR ; Jump if so

	bts	DPMI_CPFHOOK.EDD,ebx ; Set the bit

	jmp	short DPMI_SETPEHV_SET ; Join common exit code


DPMI_SETPEHV_CLR:
	btr	DPMI_CPFHOOK.EDD,ebx ; Clear the bit
DPMI_SETPEHV_SET:
	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	short DPMI_SETPEHV16 ; Jump if so

	imul	eax,type PMFLT_FVECS ; Times size of FVECS

	mov	PMFLT_FVECS.FSEL[eax],cx ; Save for later use
	mov	PMFLT_FVECS.FOFF[eax],edx ; ...

	jmp	short DPMI_SETPEHV_COM ; Join common code


DPMI_SETPEHV16:
	imul	eax,type PMFLT_DVECS ; Times size of DVECS

	mov	PMFLT_DVECS.VSEG[eax],cx ; Save for later use
	mov	PMFLT_DVECS.VOFF[eax],dx ; ...
DPMI_SETPEHV_COM:
	popfd			; Restore flags
				; (note interrupts might become enabled)
	jmp	INT31_CLC	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_SETPEHV endp		; End DPMI_SETPEHV procedure
	NPPROC	DPMI_GETPMIV -- DPMI 0.9 Function to Get Protected Mode Interrupt Vector
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 0.9 function to get protected mode interrupt vector

On entry (in INTXX_STR):

AX	=	0204h
BL	=	interrupt #
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

On exit (in INTXX_STR):

CF	=	0 if successful
CX:eDX	=	seg:off of protected mode interrupt handler

All other registers except EBP, FS, GS, and SS may be clobbered.

|

	movzx	eax,[ebp].INTXX_EBX.ELO.LO ; Get protected mode interrupt #
DPMI_GETPMIV1:
	mov	ds,SEL_DATA	; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	pushfd			; Save flags
	cli			; Disallow interrupts

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	short DPMI_GETPMIV16 ; Jump if so

	imul	eax,type PMINT_FVECS ; Times size of FVECS

	mov	cx,PMINT_FVECS.FSEL[eax] ; Get the selector
	mov	[ebp].INTXX_ECX.ELO,cx ; Return selector in caller's CX

	mov	edx,PMINT_FVECS.FOFF[eax] ; Get the offset
	mov	[ebp].INTXX_EDX,edx ; Return offset in caller's EDX

	jmp	short DPMI_GETPMIV_COM ; Join common code


DPMI_GETPMIV16:
	imul	eax,type PMINT_DVECS ; Times size of DVECS

	mov	cx,PMINT_DVECS.VSEG[eax] ; Get the selector
	mov	[ebp].INTXX_ECX.ELO,cx ; Return selector in caller's CX

	mov	dx,PMINT_DVECS.VOFF[eax] ; Get the offset
	mov	[ebp].INTXX_EDX.ELO,dx ; Return offset in caller's DX
DPMI_GETPMIV_COM:
	popfd			; Restore flags
				; (note interrupts might become enabled)
	jmp	INT31_CLC	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_GETPMIV endp		; End DPMI_GETPMIV procedure
	NPPROC	DPMI_SETPMIV -- DPMI 0.9 Function to Set Protected Mode Interrupt Vector
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 0.9 function to set protected mode interrupt vector

On entry (in INTXX_STR):

AX	=	0205h
BL	=	interrupt #
CX:eDX	=	sel:off of protected mode interrupt handler
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

On exit (in INTXX_STR):

CF	=	0 if successful

CF	=	1 if not successful
AX	=	8022 if invalid selector

All other registers except EBP, FS, GS, and SS may be clobbered.

|

	movzx	eax,[ebp].INTXX_EBX.ELO.LO ; Get exception #

	call	DPMIFN_CHKSEL	; Get and check sel:off from CX:eDX
				; CX:EDX = sel:off of interrupt handler
	jc	near ptr INT31_ERR_INVSEL ; Jump if it's invalid

	mov	es,SEL_DATA	; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	mov	ebx,eax 	; Save interrupt #

	pushfd			; Save flags
	cli			; Disallow interrupts

; Set or clear the corresponding bit in DPMI_CPIHOOK depending upon
; whether or not the DPMI client is restoring this interrupt to
; our default handler or intercepting it for itself.

; Note we test the selector only, not the offset

	push	gs		; Save for a moment

	mov	gs,SEL_4GB	; Get AGROUP data selector
	assume	gs:AGROUP	; Tell the assembler about it

	mov	edi,LaSIRBCUR	; Get linear address of current SIRB table

	cmp	cx,DPMI_IDEF	; Izit our default handler?
	je	short DPMI_SETPMIV_CLR ; Jump if so

	bts	DPMI_CPIHOOK.EDD,ebx ; Set the bit

; If this is the primary client, set the bit in DPMI_PPIHOOK

	mov	esi,PCURTSS	; Get offset in DGROUP of the current TSS

	cmp	esi,PPRMTSS	; Izit the primary client?
	jne	short @F	; Jump if not

	bts	DPMI_PPIHOOK.EDD,ebx ; Set the bit
@@:
	test	CPUFET_FLAG,mask $CPUFET_VME ; Is VME supported?
	jz	short DPMI_SETPMIV_SET ; Jump if not

	cmp	bl,1Ch		; Izit the only special interrupt we don't
				; force to be hooked?
	jne	short DPMI_SETPMIV_SET ; Jump if not

	mov	esi,LaIOBIT	; Get offset in AGROUP of I/O bit map
	sub	esi,256/8	; Back off to start of the SIR bitmap
	bts	AGROUP:[esi].EDD,ebx ; Set the SIRB bit
	bts	AGROUP:[edi].EDD,ebx ; Mark as active

	jmp	short DPMI_SETPMIV_SET ; Join common code


DPMI_SETPMIV_CLR:
	push	bx		; Pass the interrupt #
	call	DPMIFN_CLRINT	; Clear an interrupt
	jnc	short DPMI_SETPMIV_SET ; Jump if not special

	btr	AGROUP:[edi].EDD,ebx ; Mark as inactive
DPMI_SETPMIV_SET:
	pop	gs		; Restore
	assume	gs:nothing	; Tell the assembler about it

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	short DPMI_SETPMIV16 ; Jump if so

	imul	eax,type PMINT_FVECS ; Times size of FVECS

	mov	PMINT_FVECS.FSEL[eax],cx ; Save for later use
	mov	PMINT_FVECS.FOFF[eax],edx ; ...

	jmp	short DPMI_SETPMIV_COM ; Join common code


DPMI_SETPMIV16:
	imul	eax,type PMINT_DVECS ; Times size of DVECS

	mov	PMINT_DVECS.VSEG[eax],cx ; Save for later use
	mov	PMINT_DVECS.VOFF[eax],dx ; ...
DPMI_SETPMIV_COM:
	popfd			; Restore flags
				; (note interrupts might become enabled)
	jmp	INT31_CLC	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_SETPMIV endp		; End DPMI_SETPMIV procedure
	NPPROC	DPMI_GETEVMPEHV -- DPMI 1.0 Function to Get Extended VM Exception Handler
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 1.0 function to get extended VM exception handler vector

On entry (in INTXX_STR):

AX	=	0211h
BL	=	exception # (00-1F)
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

On exit (in INTXX_STR):

CF	=	0 if successful
CX:eDX	=	sel:off of processor exception handler

CF	=	1 if not successful
AX	=	8021 if invalid value

All other registers except EBP, FS, GS, and SS may be clobbered.

|

	movzx	eax,[ebp].INTXX_EBX.ELO.LO ; Get exception #

	cmp	al,1Fh		; Check against maximum
	ja	near ptr INT31_ERR_INVVAL ; Jump if it's out of range

	mov	ds,SEL_DATA	; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	pushfd			; Save flags
	cli			; Disallow interrupts

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	short DPMI_GETEVMPEHV16 ; Jump if so

	imul	eax,type VMFLT_FVECS ; Times size of FVECS

	mov	cx,VMFLT_FVECS.FSEL[eax] ; Get the selector
	mov	[ebp].INTXX_ECX.ELO,cx ; Return selector in caller's CX

	mov	edx,VMFLT_FVECS.FOFF[eax] ; Get the offset
	mov	[ebp].INTXX_EDX,edx ; Return offset in caller's EDX

	jmp	short DPMI_GETEVMPEHV_COM ; Join common code


DPMI_GETEVMPEHV16:
	imul	eax,type VMFLT_DVECS ; Times size of DVECS

	mov	cx,VMFLT_DVECS.VSEG[eax] ; Get the selector
	mov	[ebp].INTXX_ECX.ELO,cx ; Return selector in caller's CX

	mov	dx,VMFLT_DVECS.VOFF[eax] ; Get the offset
	mov	[ebp].INTXX_EDX.ELO,dx ; Return offset in caller's DX
DPMI_GETEVMPEHV_COM:
	popfd			; Restore flags
				; (note interrupts might become enabled)
	jmp	INT31_CLC	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_GETEVMPEHV endp		; End DPMI_GETEVMPEHV procedure
	NPPROC	DPMI_SETEVMPEHV -- DPMI 1.0 Function to Set Extended VM Exception Handler Vector
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 1.0 function to set extended VM exception handler vector

On entry (in INTXX_STR):

AX	=	0213h
BL	=	exception # (00-1F)
CX:eDX	=	sel:off of processor exception handler
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

On exit (in INTXX_STR):

CF	=	0 if successful

CF	=	1 if not successful
AX	=	8021 if invalid value
	=	8022 if invalid selector

All other registers except EBP, FS, GS, and SS may be clobbered.

|

	movzx	eax,[ebp].INTXX_EBX.ELO.LO ; Get exception #

	cmp	al,1Fh		; Check against maximum
	ja	near ptr INT31_ERR_INVVAL ; Jump if it's out of range

	cmp	al,06h		; Check against specifc values we support
	je	short @F	; Jump if it's valid

	cmp	al,0Dh		; Check against specifc values we support
	jne	near ptr INT31_ERR_INVVAL ; Jump if it's not supported
@@:
	call	DPMIFN_CHKSEL	; Get and check sel:off from CX:eDX
				; CX:EDX = sel:off of interrupt handler
	jc	near ptr INT31_ERR_INVSEL ; Jump if it's invalid

	mov	es,SEL_DATA	; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	mov	ebx,eax 	; Save interrupt #

	pushfd			; Save flags
	cli			; Disallow interrupts

; Set or clear the corresponding bit in DPMI_CVFHOOK depending upon
; whether or not the DPMI client is restoring this fault to
; our default handler or intercepting it for itself.

; Note we test the selector only, not the offset

	mov	esi,PCURTSS	; Get offset in DGROUP of the current TSS

	cmp	cx,DPMI_IDEF	; Izit our default handler?
	je	short DPMI_SETEVMPEHV_CLR ; Jump if so

	bts	DPMI_CVFHOOK.EDD,ebx ; Set the bit

; If this is the primary client, set the bit in DPMI_PVFHOOK

	cmp	esi,PPRMTSS	; Izit the primary client?
	jne	short @F	; Jump if not

	bts	DPMI_PVFHOOK.EDD,ebx ; Set the bit
@@:
	jmp	short DPMI_SETEVMPEHV_SET ; Join common exit code


DPMI_SETEVMPEHV_CLR:
	btr	DPMI_CVFHOOK.EDD,ebx ; Clear the bit

; If this is the primary client, clear the bit in DPMI_PVFHOOK

	cmp	esi,PPRMTSS	; Izit the primary client?
	jne	short @F	; Jump if not

	btr	DPMI_PVFHOOK.EDD,ebx ; Clear the bit
@@:
DPMI_SETEVMPEHV_SET:
	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	short DPMI_SETEVMPEHV16 ; Jump if so

	imul	eax,type VMFLT_FVECS ; Times size of FVECS

	mov	VMFLT_FVECS.FSEL[eax],cx ; Save for later use
	mov	VMFLT_FVECS.FOFF[eax],edx ; ...

	jmp	short DPMI_SETEVMPEHV_COM ; Join common code


DPMI_SETEVMPEHV16:
	imul	eax,type VMFLT_DVECS ; Times size of DVECS

	mov	VMFLT_DVECS.VSEG[eax],cx ; Save for later use
	mov	VMFLT_DVECS.VOFF[eax],dx ; ...
DPMI_SETEVMPEHV_COM:
	popfd			; Restore flags
				; (note interrupts might become enabled)
	jmp	INT31_CLC	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_SETEVMPEHV endp		; End DPMI_SETEVMPEHV procedure
	NPPROC	DPMIFN_CLRINT -- DPMI Function To Clear An Interrupt
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

DPMI function to clear an interrupt
Clear it in DPMI_CPIHOOK (and DPMI_PPIHOOK if primary = current client)
If we're on a P5,
   and this INT is 1Ch,
   and this INT is not active by default,
   then clear the SIRB bit and mark as special (to the caller)
   so the caller can clear the bit in LaSIRBCUR.

On exit:

CF	=	0 if not special
	=	1 otherwise

|

CLRINT_STR struc

	dd	?		; Caller's EIP
	dd	?		; ...	   EBP
CLRINT_INT dw	?		; The interrupt # to clear

CLRINT_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ebx>	; Save registers

	movzx	ebx,[ebp].CLRINT_INT ; Get the interrupt #

	btr	DPMI_CPIHOOK.EDD,ebx ; Clear the bit

; If this is the primary client, clear the bit in DPMI_PPIHOOK

	mov	eax,PCURTSS	; Get offset in DGROUP of the current TSS

	cmp	eax,PPRMTSS	; Izit the primary client?
	jne	short @F	; Jump if not

	btr	DPMI_PPIHOOK.EDD,ebx ; Clear the bit
@@:
	test	CPUFET_FLAG,mask $CPUFET_VME ; Is VME supported?
	jz	short DPMIFN_CLRINT_XSPEC ; Jump if not

	cmp	bl,1Ch		; Izit the only special interrupt we don't
				; force to be hooked?
	jne	short DPMIFN_CLRINT_XSPEC ; Jump if not (don't clear)

; Mark as inactive unless it's active in the default table

	mov	eax,PVMTSS	; Get offset in DGROUP of the 1st TSS
	mov	eax,DGROUP:[eax].DPTSS_LaSIRBCUR ; Get linear address of
				; current SIRB table
	bt	AGROUP:[eax].EDD,ebx ; Izit active by default?
	jc	short DPMIFN_CLRINT_XSPEC ; Jump if so

	mov	eax,LaIOBIT	; Get offset in AGROUP of I/O bit map
	sub	eax,256/8	; Back off to start of the SIR bitmap
	btr	AGROUP:[eax].EDD,ebx ; Clear the SIRB bit

	stc			; Mark as special

	jmp	short DPMIFN_CLRINT_EXIT ; Join common exit code


DPMIFN_CLRINT_XSPEC:
	clc			; Mark as not special
DPMIFN_CLRINT_EXIT:
	REGREST <ebx,eax>	; Restore

	pop	ebp		; Restore

	ret	2		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_CLRINT endp		; End DPMIFN_CLRINT procedure
	NPPROC	DPMI_SIMVMI -- DPMI 0.9 Function to Simulate VM Interrupt
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 0.9 function to simulate VM interrupt

On entry (in INTXX_STR):

AX	=	0300h
BL	=	interrupt #
BH	=	flags
		 Bit 0:    reset the PIC and A20 (ignored)
		 Bit 1-7:  reserved, must be 0
CX	=	# words to copy from PM to VM stack
ES:eDI	==>	VM register structure in VMC_STR format
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

If this routine is at PL 0, INTXX_ESP and INTXX_SS are
filled in and point to the caller's stack from which the
parameters are to be copied.

If this routine is at PL 3, the parameters to be copied
are found starting at INTXX_ESP and following.

On exit (in INTXX_STR):

CF	=	0 if successful

CF	=	1 if not successful
AX	=	8012 if linear memory unavailable (stack)
	=	8013 if physical ...
	=	8014 if backing store ...
	=	8021 if invalid value (CX too large)
	=	8022 if invalid selector

All other registers except EBP, FS, GS, and SS may be clobbered.

|

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

	movzx	eax,[ebp].INTXX_EBX.ELO.LO ; Get VM interrupt #
	mov	eax,AGROUP:[eax*4] ; Get seg:off of VM interrupt handler

	mov	edi,[ebp].INTXX_EDI ; Get caller's eDI
	IF16ZX	di		; Zero to use as dword if 16-bit client

	mov	es,[ebp-@I31BACK].I31_ES ; Get caller's ES
	assume	es:nothing	; Tell the assembler about it

	mov	es:[edi].VMC_IP,ax ; Save offset
	shr	eax,16		; Shift down high-order word
	mov	es:[edi].VMC_CS,ax ; Save segment

	cli			; Disallow interrupts

	mov	DPMI_STKFLG,3	; Mark as IRET frame

COMMENT|

Common entry point for translation services

On entry:

ES:EDI	==>	VMC_STR
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)
DS	=	DGROUP
IF	=	0

|

	public	DPMI_SIMVMI_COM
DPMI_SIMVMI_COM:

; Save variables so we can be re-entrant

SIMVMC_STR struc		; SIMVMC stack structure

;;;SIMVMC_PL0LEN dd ?		   ; SIMVMC value from PLCL_PL0LEN
SIMVMC_ESP0 dd	?		; SIMVMC value from TSS_ESP0
SIMVMC_SS0 dw	?		; ...		    TSS_SS0
SIMVMC_VMSTKOFF dw ?		; ...		    VMSTKOFF
SIMVMC_C0E dw	?		; ...		    DPMICNT0E
SIMVMC_C0D dw	?		; ...		    DPMICNT0D
SIMVMC_LIFLG dd ?		; ...		    LAST_INTFLG
SIMVMC_LICOM dd ?		; ...		    LAST_INTCOM
SIMVMC_GS  dd	?		; Caller's GS
SIMVMC_FS  dd	?		; ...	   FS
SIMVMC_FVEC df	?		; ...	   current ES:EDI
	dw	?		; Padding
SIMVMC_EBP dd	?		; ...	   EBP

SIMVMC_STR ends

	push	ebp		; Save offset of original INTXX_STR

	REGSAVE <es,edi>	; Save original ptrs as fword

	REGSAVE <fs,gs> 	; Save caller's selectors

	REGSAVE <LAST_INTCOM,LAST_INTFLG,DPMICNT0D,DPMICNT0E> ; Save to restore later

	mov	DPMICNT0D,0	; Clear 'em in case we are re-entered
	mov	DPMICNT0E,0	; ...

; Between the time we change the PL0 stack pointer in the TSS
; and we recalculate PL0STK pointers, we can't allow any interruption

;;;;;;; cli			; Disallow interrupts (already disabled)

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	push	DGROUP:[eax].DPTSS_VMSTKOFF ; Save old VM stack offset
	push	DGROUP:[eax].TSS_SS0  ; Save old stack selector
	push	DGROUP:[eax].TSS_ESP0 ; Save pointer to stack top

;;;;;;; PUSHD	-1		; Make room for SIMVMC_PL0LEN
;;;;;;;
; The MAX stack is now mapped by SIMVMC_STR

; * Save SS:ESP as new top of stack pointer

	mov	DGROUP:[eax].TSS_SS0,ss ; Save for next time
	mov	DGROUP:[eax].TSS_ESP0,esp ; ...

;;;;;;; mov	eax,ebp 	; Get top of stack we're protecting
;;;	mov	eax,PPL0STK_MAX ; Get top of PL0 stack
;;;	sub	eax,esp 	; Less current offset
;;;	mov	[esp].SIMVMC_PL0LEN,eax ; Save as length
;;;
	mov	gs,SEL_4GB	; Get AGROUP data selector
	assume	gs:AGROUP	; Tell the assembler about it

; * Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

; Make room for top portion of INTCOM_STR

	sub	esp,(type INTCOM_NEXT)	   + \
		    (type INTCOM_DEV_FLAG) + \
		    (type INTCOM_GDTR)

	movzx	eax,es:[edi].VMC_GS ; Get VM GS to use
	push	eax		; Place on stack for VM transfer

	movzx	eax,es:[edi].VMC_FS ; Get VM FS to use
	push	eax		; Place on stack for VM transfer

	movzx	eax,es:[edi].VMC_DS ; Get VM DS to use
	push	eax		; Place on stack for VM transfer

	movzx	eax,es:[edi].VMC_ES ; Get VM ES to use
	push	eax		; Place on stack for VM transfer

	movzx	eax,es:[edi].VMC_SS ; Get VM SS to use

	and	ax,ax		; Izit unspecified?
	jnz	short DPMI_SIMVMI1 ; Jump if not

	cmp	es:[edi].VMC_SP,0 ; Izit unspecified?
	jnz	short DPMI_SIMVMI1 ; Jump if not
;;;
;;; ; The VM stack is unspecified -- if LAST_INTCOM is valid, use
;;; ; SS:SP from there.
;;;
;;;	     test    LAST_INTFLG,@INTCOM_VAL ; Izit valid?
;;;	     jz      short DPMI_SIMVMI0 ; Jump if not
;;;
;;;	     mov     edx,LAST_INTCOM ; SS:EDX ==> last valid VM interrupt frame
;;;
;;;	     movzx   eax,ss:[edx].INTCOM_SS ; Get VM SS to use
;;;	     push    eax	    ; Place on stack for VM transfer
;;;
;;;	     movzx   eax,ss:[edx].INTCOM_ESP.ELO ; Get VM SP to use
;;;	     push    eax	    ; Place on stack for VM transfer
;;;
;;;	     xor     cx,cx	    ; Mark as not using HPDA stack
;;;
;;;	     jmp     short DPMI_SIMVMI2 ; Join common code
;;;
;;; DPMI_SIMVMI0:

; The VM stack is unspecified and LAST_INTCOM is invalid.
; If there's a DPMI client active or we have a local HPDA, use it.

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	cmp	eax,PVMTSS	; Izit the same as the 1st TSS?
	jne	short DPMI_SIMVMI0A ; Jump if not (there's a DPMI client active)

	test	LCL_FLAG,@LCL_HPDA ; Izit present?
	jnz	short @F	; Jump if so

	SWATMAC ERR		; Call our debugger
@@:
DPMI_SIMVMI0A:
	PUSHW	0		; Filler for SS
	push	DGROUP:[eax].DPTSS_VMSTKSEG ; Use as SS
	PUSHW	0		; High-order word of ESP
	push	DGROUP:[eax].DPTSS_VMSTKOFF ; Use as ESP

	mov	cx,1		; Mark as having used HPDA stack

	jmp	short DPMI_SIMVMI2 ; Join common code


DPMI_SIMVMI1:
	push	eax		; Place on stack for VM transfer

	movzx	eax,es:[edi].VMC_SP ; Get VM SP to use
	push	eax		; Place on stack for VM transfer

	xor	cx,cx		; Mark as not using HPDA stack
DPMI_SIMVMI2:
	cmp	[esp+4].ELO,0	; Is the SS valid?
	jne	short @F	; Jump if so

	SWATMAC ERR		; Call our debugger
@@:
	movzx	eax,es:[edi].VMC_FL ; Get FL to use
	and	ax,not (mask $IOPL) ; Clear the IOPL bits
	or	eax,(mask $VMHI) or (@VMIOPL shl $IOPL) ; VM=1, IOPL=@VMIOPL

	cmp	DPMI_STKFLG,3	; Izit an IRET frame?
	jne	short @F	; Jump if not

	and	eax,not ((mask $IF) or (mask $TF)) ; IF=TF=0
@@:
	push	eax		; Place on stack for VM transfer

	movzx	eax,es:[edi].VMC_CS ; Get CS to use
	push	eax		; Place on stack for VM transfer

	movzx	eax,es:[edi].VMC_IP ; Get IP to use
	push	eax		; Place on stack for VM transfer

; The MAX stack is now mapped by INTCOM_STR followed by SIMVMC_STR

	jcxz	DPMI_SIMVMI_XHPDASTK ; Jump if we didn't use the HPDA stack

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	mov	bx,DGROUP:[eax].DPTSS_VMSTKOFF ; Get offset

	sub	bx,@HPDAFRM_SIZ ; Make room for a level
	jb	near ptr DPMI_SIMVMI_VMFULL ; Jump if there's no more room

	cmp	bx,DGROUP:[eax].DPTSS_VMSTKBOT ; Izit below the bottom?
	jb	near ptr DPMI_SIMVMI_VMFULL ; Jump if so

	mov	DGROUP:[eax].DPTSS_VMSTKOFF,bx ; Make room for a level
DPMI_SIMVMI_XHPDASTK:
	mov	LAST_INTCOM,esp ; Save as new value
	or	LAST_INTFLG,@INTCOM_VAL ; Mark as valid

;;; ; Protect the PL0 stack at and above the INTCOM_STR by
;;; ; copying it to PLCL_PL0CUR
;;;
;;;	    lea     esi,[esp+(type INTCOM_STR)] ; Copy as source
;;;	    mov     ecx,ss:[esi].SIMVMC_PL0LEN ; Get the length
;;;	    sub     PLCL_PL0CUR,ecx ; Make room for it
;;;
;;;	    REGSAVE <edi,es>	    ; Save for a moment
;;;
;;;	    mov     ax,ds	    ; Get DGROUP data selector
;;;	    mov     es,ax	    ; Address it
;;;	    assume  es:DGROUP	    ; Tell the assembler about it
;;;
;;;	    mov     edi,PLCL_PL0CUR ; Get offset in DGROUP of current local PL0 stack
;;;	    mov     DGROUP:[edi-4],ecx ; Save as length of saved stack
;;;	    sub     PLCL_PL0CUR,4   ; Protect it
;;;
;;;	    cld 		    ; String ops fowardly
;;; S32 rep movs    <DGROUP:[edi].LO,ss:[esi].LO> ; Copy to local storage
;;;
;;;	    REGREST <es,edi>	    ; Restore
;;;	    assume  es:nothing	    ; Tell the assembler about it

; Make room on VM stack for caller's parameters and our return address

	mov	ax,[ebp].INTXX_ECX.ELO ; Get caller's CX
	add	ax,DPMI_STKFLG	; Plus room for appropriate size frame
	shl	ax,1-0		; Convert from words to bytes
	sub	[esp].INTCOM_ESP.ELO,ax ; Make room for parameters
				; and return address
	movzx	edx,[esp].INTCOM_SS ; Get caller's SS
	shl	edx,4-0 	; Convert from paras to bytes
	add	edx,[esp].INTCOM_ESP ; Plus top of stack

; Save our return address

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	mov	ax,DGROUP:[eax].DPTSS_HPDASEG ; Get segment of HPDA
	mov	AGROUP:[edx].VSEG,ax ; Save return segment
	mov	AGROUP:[edx].VOFF,offset HPDA_SIMRET ; Save return offset
	add	edx,size VECTOR ; Skip over return address

; Save return flags (if it's an IRET frame)

	cmp	DPMI_STKFLG,3	; Izit an IRET frame?
	jne	short @F	; Jump if not

	push	es:[edi].VMC_FL ; Get flags to use
	and	[esp].ELO,not (mask $IOPL) ; Clear the IOPL bits
	or	[esp].ELO,@VMIOPL shl $IOPL ; IOPL=@VMIOPL

	pop	AGROUP:[edx].ELO ; Save as flags
	add	edx,size VMC_FL ; Skip over flags
@@:

; Copy parameters to VM stack

	movzx	ecx,[ebp].INTXX_ECX.ELO ; Get caller's CX
	jecxz	DPMI_SIMVMI_XPARM ; Jump if no parameters to copy
	xor	ebx,ebx 	; Initialize index register

COMMENT|

Calculate the linear address of the caller's parameters

If this routine is at PL 0, INTXX_ESP and INTXX_SS are
filled in and point to the caller's stack from which the
parameters are to be copied.

If this routine is at PL 3, the parameters to be copied
are found starting after INTXX_SS.

|

; Assume we're at PL 0

	lfs	eax,[ebp].INTXX_ESP.EDF ; FS:EAX ==> caller's stack
	assume	fs:nothing	; Tell the assembler about it
	IF16ZX	ax		; Zero to use as dword if 16-bit client

; If we came here from a JMPF/CALLF from the client, the client's
; return address is on the DPMI stack.	We must skip over it to
; access the caller's parameters.

	mov	si,DPMI_IDEF	; Get our default interrupt selector

	cmp	si,[ebp].INTXX_CS ; Izit our default handler?
	jne	short DPMI_SIMVMI_XIDEF ; Jump if not

; Skip over 3 words if we're a 16-bit client, 3 dwords otherwise

	add	eax,3*2 	; # bytes to skip if 16-bit client

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	short @F	; Jump if so

	add	eax,3*2 	; # extra bytes to skip if 32-bit client
@@:
DPMI_SIMVMI_XIDEF:

;;; ; If we're at PL 3
;;;
;;;	     push    ss 	    ; Get stack selector
;;;	     pop     fs 	    ; Address it
;;;	     assume  fs:nothing     ; Tell the assembler about it
;;;
;;;	     lea     eax,[eax+ebp].INTXX_ES ; Skip over caller's SS to parms
@@:
	push	fs:[eax+ebx*2].ELO ; Get next parameter
	pop	AGROUP:[edx+ebx*2].ELO ; Save on VM stack

	inc	ebx		; Skip to next word

	loop	@B		; Jump if more parameters to copy
DPMI_SIMVMI_XPARM:
	push	es:[edi].VMC_EAX ; Pass caller's EAX
	push	es:[edi].VMC_ECX ; ...	  ECX
	push	es:[edi].VMC_EDX ; ...	  EDX
	push	es:[edi].VMC_EBX ; ...	  EBX
	PUSHD	0		  ; ... 	  ESP
	push	es:[edi].VMC_EBP ; ...	  EBP
	push	es:[edi].VMC_ESI ; ...	  ESI
	push	es:[edi].VMC_EDI ; ...	  EDI
	popad			; Put into effect

	push	PVMTSS		; Pass offset in DGROUP of the 1st TSS
	call	DPMIFN_LMSW	; Put MSW and INT 07h values into effect

	jmp	ERM_FVEC	; Continue exeuction in RM/VCPI

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing



	assume	ds:DGROUP,es:nothing; Tell the assembler about it
	assume	fs:nothing,gs:AGROUP ; Tell the assembler about it
DPMI_SIMVMI_VMFULL:
	add	esp,size INTCOM_STR ; Strip

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

;;;;;;; add	esp,type SIMVMC_PL0LEN ; Strip SIMVMC_PL0LEN
;;;;;;;
	pop	DGROUP:[eax].TSS_ESP0 ; Restore
	pop	DGROUP:[eax].TSS_SS0 ; ...
	pop	DGROUP:[eax].DPTSS_VMSTKOFF ; ...

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

	REGREST <DPMICNT0E,DPMICNT0D,LAST_INTFLG,LAST_INTCOM> ; Restore

	REGREST <gs,fs> 	; Restore
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

	REGREST <edi,es>	; Restore
	assume	es:nothing	; Tell the assembler about it

	pop	ebp		; Restore

; At this point we're back to the calling stack of
; this DPMI call

;;;;;;; cli			; Disable interrupts to avoid HW interrupt
;;;;;;;;			; after POPAD looking like a VM interrupt
;;;;;;;;			; (already disabled)
	pop	LPMSTK_FVEC.FOFF ; Restore
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	popad			; Restore

	mov	[esp].INTDPF_INTNO,4*31h+offset PGROUP:INTPROC00Z ; Mark as INT 31h

; The MAX stack contains INTDPF_STR

	jmp	FLTPROC_VMFULL	; Join common error code


; Check to see if we're returning from a simulated interrupt,
; raw mode switch from VM to PM, reflected interrupt to VM,
; or real mode callback

; The stack is mapped by INTCOM_STR

	public	DPMI_SIMRET
DPMI_SIMRET:
	PUSHD	0		; Put pseudo-error code onto stack

	pushad			; All EGP registers

; The stack is mapped by INTXX_STR

	cld			; Ensure string ops forwardly
	mov	ebp,esp 	; SS:EBP ==> INTXX_STR

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	gs,SEL_4GB	; Get AGROUP data selector
	assume	gs:AGROUP	; Tell the assembler about it

	movzx	eax,[ebp].INTXX_CS ; Get return segment
	shl	eax,4-0 	; Shift from paras to bytes

; Check for HPDA signature

	cmp	AGROUP:[eax].HPDA_SIGN.EDD,@HPDA_SIG2 ; Izit our boy?
	jne	near ptr DPMI_SIMERR ; Jump if not

; Check for same caller to handle nesting

	mov	ebx,PCURTSS	; Get offset in DGROUP of current TSS
	mov	OLD_PCURTSS,ebx ; Save to restore later

	cmp	ebx,AGROUP:[eax].HPDA_PCURTSS ; Izit the same level?
	je	short DPMI_SIMRET_SAMELVL ; Jump if so (not nesting mismatch)

	mov	ebx,AGROUP:[eax].HPDA_PCURTSS ; Get the offset in DGROUP of incoming TSS
	call	DPMIFN_NESTOUT	; Save the old state and switch to the new one
DPMI_SIMRET_SAMELVL:

; EAX	 =	 linear address of the incoming HPDA

	push	PCURTSS 	; Pass offset in DGROUP of the current TSS
	call	DPMIFN_LMSW	; Put MSW and INT 07h values into effect

; Check for return from simulated INT/Call

	cmp	[ebp].INTXX_EIP,dword ptr HPDA_SIMRET[2] ; Izit SIMRET?
	je	near ptr DPMI_SIMVMRET ; Jump if so

; Check for raw mode switch from VM to PM

	cmp	[ebp].INTXX_EIP,dword ptr HPDA_RMSRET[2] ; Izit RMSRET?
	je	near ptr DPMI_RMSVM2PM ; Jump if so

; Check for return from reflected interrupt to VM
;;;;;;;
;;;;;;; cmp	[ebp].INTXX_EIP,dword ptr HPDA_REFRET[2] ; Izit REFRET?
;;;;;;; je	near ptr DPMI_REFRET ; Jump if so
;;;;;;;
; Check for mouse event interrupt from VM

	cmp	[ebp].INTXX_EIP,dword ptr HPDA_MEI[2] ; Izit MEI?
	je	near ptr DPMI_MEI ; Jump if so

; Check for PDBI mouse event interrupt from VM

	cmp	[ebp].INTXX_EIP,dword ptr HPDA_PDBI[2] ; Izit PDBI?
	je	near ptr DPMI_PDBI ; Jump if so

; Check for Terminate reflected from VM

	cmp	[ebp].INTXX_EIP,dword ptr HPDA_I22DEF2 ; Izit INT 22h start?
	je	near ptr INT22DEF ; Jump if so

; Check for Ctrl-Break reflected from VM

	cmp	[ebp].INTXX_EIP,dword ptr HPDA_I23DEF2 ; Izit INT 23h start?
	je	near ptr INT23DEF ; Jump if so

; Check for Critical-Error reflected from VM

	cmp	[ebp].INTXX_EIP,dword ptr HPDA_I24DEF2 ; Izit INT 24h start?
	je	near ptr INT24DEF ; Jump if so

; Check for real mode callback from VM to PM

	movzx	esi,HPDAVMC_OFF ; Get offset of VM callback structures
	add	esi,eax 	; Plus caller's CS in bytes
	movzx	ecx,HPDAVMC_CNT ; Get # VM callback strucs

	mov	ebx,[ebp].INTXX_EIP ; Get caller's EIP
	add	ebx,eax 	; Plus caller's CS in bytes
	sub	ebx,2		; Back off to INT @PMH_INT
DPMI_SIMRET1:
	cmp	ebx,esi 	; Izit a VM callback address?
	je	short DPMI_VMCB ; Jump if so

	add	esi,size HPDAVMC_STR ; Skip to next VM callback struc

	loop	DPMI_SIMRET1	; Jump if more VM callbck addresses to check



	SWATMAC ERR		; Call our debugger




	assume	ds:DGROUP	; Tell the assembler about it
	assume	gs:AGROUP	; Tell the assembler about it
DPMI_SIMERR:
	push	PVMTSS		; Pass offset in DGROUP of the 1st TSS
	call	DPMIFN_LMSW	; Put MSW and INT 07h values into effect

	popad			; Restore all EGP registers

	add	esp,size INTXX_ERR ; Strip off pseudo-error code

%	jmp	INTPROC&@PMH_INT ; Call as VM INT @PMH_INT

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing


;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
; VM callback
; SS:EBP ==>	INTXX_STR on return
; GS:EBX ==>	VM callback structure
; DS	=	DGROUP

	public	DPMI_VMCB
	assume	ds:DGROUP	; Tell the assembler about it
	assume	gs:AGROUP	; Tell the assembler about it
DPMI_VMCB:
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	push	OLD_PCURTSS	; Save previous value in case we need
				; ...to restore it upon exit
	push	DGROUP:[eax].TSS_SS0  ; Save old stack selector
	push	DGROUP:[eax].TSS_ESP0 ; Save old pointer to stack top

;;;;;;; PUSHD	-1		; Make room for VMCB_PL0LEN
;;;;;;;
	push	LAST_INTCOM	; Save old LAST_INTCOM
	push	LAST_INTFLG	; ...and its flag
	push	LPMSTK_FVEC.FSEL.EDD ; Save current LPM stack offset
	push	LPMSTK_FVEC.FOFF ; ...

; * Save SS:ESP as new top of stack pointer

	mov	DGROUP:[eax].TSS_SS0,ss ; Save for next time
	mov	DGROUP:[eax].TSS_ESP0,esp ; ...

VMCB_STR struc			; VM callback stack structure

VMCB_LPMSTK df	?		; LPMSTK_FVEC
	dw	?		; For alignment
VMCB_LIFLG dd	?		; LAST_INTFLG
VMCB_LICOM dd	?		; LAST_INTCOM
;;; VMCB_PL0LEN dd  ?		    ; Length of PL0 stack to protect
VMCB_ESP0 dd	?		; TSS_ESP0
VMCB_SS0  dw	?		; TSS_SS0
VMCB_OPCURTSS dd ?		; OLD_PCURTSS
	db	(type INTXX_STR) dup (?) ; INTXX_STR

VMCB_STR ends

; * SS:ESP ==> VMCB_STR

;;; ; Protect the PL0 stack at and above VMCB_STR by
;;; ; copying it to PLCL_PL0CUR
;;;
;;;	    mov     esi,esp	    ; Copy as source
;;;	    mov     ecx,PPL0STK_MAX ; Get top of PL0 stack
;;;	    sub     ecx,esi	    ; Less source offset
;;;	    mov     [esp].VMCB_PL0LEN,ecx ; Save for later use
;;;
;;;	    sub     PLCL_PL0CUR,ecx ; Less length to make room
;;;	    mov     edi,PLCL_PL0CUR ; Get offset in DGROUP of current local PL0 stack
;;;	    mov     DGROUP:[edi-4],ecx ; Save as length of saved stack
;;;	    sub     PLCL_PL0CUR,4   ; Protect it
;;;
;;;	    SETDATA es		    ; Get DGROUP data selector
;;;	    assume  es:DGROUP	    ; Tell the assembler about it
;;;
;;;	    cld 		    ; String ops fowardly
;;; S32 rep movs    <DGROUP:[edi].LO,ss:[esi].LO> ; Copy to local storage

; * Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

; Save new value for LAST_INTCOM

	lea	eax,[ebp].INTXX_EIP ; Get stack offset of new LAST_INTCOM
	xchg	eax,LAST_INTCOM ; Swap with the last one
	bts	LAST_INTFLG,$INTCOM_VAL ; Copy previous flag and mark as valid
	adc	eax,0		; Save previous flag
	mov	[ebp].INTXX_ICOMLO,ax ; Save to restore later
	shr	eax,16		; Shift down high-order word
	mov	[ebp].INTXX_ICOMHI,ax ; Save to restore later

; Save VM registers in the client's VMC structure

	les	edi,AGROUP:[ebx].HPDAVMC_REGFVEC ; ES:EDI ==> VMC structure
	assume	es:nothing	; Tell the assembler about it

	mov	cx,1		; Function code to copy SS:SP and CS:IP
	call	DPMIFN_INTXX2VMC ; Copy registers from
				; INTXX_STR at SS:EBP to VMC_STR at ES:EDI

; Set the base and limit of the VM stack

	movzx	eax,AGROUP:[ebx].HPDAVMC_VMSS ; Get stack selector
	and	ax,not ((mask $TI) or (mask $PL)) ; Clear TI and PL bits

	mov	edx,PCURTSS	; Get offset in DGROUP of the current TSS
	add	eax,DGROUP:[edx].DPTSS_LaLDT ; Plus linear address of DPMI LDT

	mov	edx,CON64KB	; Get segment limit
	dec	edx		; Convert from length to limit

	mov	AGROUP:[eax].DESC_SEGLM0,dx ; Save limit bits 0-15
	shr	edx,16		; Shift down high-order word

; Clear segment limit bits 16-19 and the G-bit

	and	AGROUP:[eax].DESC_SEGLM1,not ((mask $DTE_G) or (mask $SEGLM1))
	or	AGROUP:[eax].DESC_SEGLM1,dl ; Save limit bits 16-19

	movzx	eax,[ebp].INTXX_SS ; Get SS from VM
	shl	eax,4-0 	; Convert from paras to bytes

	push	AGROUP:[ebx].HPDAVMC_VMSS ; Pass stack selector
	call	SETLBASE	; Set selector base to EAX
;;;;;;; jc	short ???	; Ignore error return

; Allocate a portion of the LPM stack

	lfs	esi,LPMSTK_FVEC ; FS:ESI ==> special stack used by faults
	assume	fs:nothing	; Tell the assembler about it

	inc	LPMSTK_CNT	; Count in another one

; Pass our return address onto the LPM stack
; for the callback procedure to IRET/D

DPMI_VMCB16_STR struc

DPMI_VMCB16_RIP dw ?		; Our return IP
DPMI_VMCB16_RCS dw ?		; ...	     CS
DPMI_VMCB16_RFL dw ?		; ...	     FL

DPMI_VMCB16_STR ends


DPMI_VMCB32_STR struc

DPMI_VMCB32_REIP dd ?		; Our return EIP
DPMI_VMCB32_RCS dw ?,?		; ...	     CS w/filler
DPMI_VMCB32_REFL dd ?		; ...	     EFL

DPMI_VMCB32_STR ends

	mov	ax,DPMI_IDEF	; Get our interrupt selector

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	short DPMI_VMCB16 ; Jump if so

	sub	esi,size DPMI_VMCB32_STR ; Make room on LPM stack
if @EXPD

; If this is a 16-bit stack, zero the high-order word of ESI
; to simulate using SI instead of ESI.

	push	fs		; Pass stack selector
	call	DPMIFN_ESIMOD	; Modify high-order word of ESI
				; if stack selector is a 16-bit stack
; Check to see if the resulting offset is within the stack's bounds

	push	fs		; Pass stack selector
	push	esi		; ...	     offset
	call	DPMIFN_CHKSTK	; Check the stack offset
endif
	jc	near ptr DPMI_VMCB_LPMFULL ; Jump if there's no room

	mov	fs:[esi].DPMI_VMCB32_REIP,PMVMCB ; Return EIP
	mov	fs:[esi].DPMI_VMCB32_RCS,ax	  ; ... CS
	mov	fs:[esi].DPMI_VMCB32_REFL,@DPMIOPL shl $IOPL ; ... EFL

	jmp	short DPMI_VMCB_COM ; Join common code


DPMI_VMCB16:
	sub	esi,size DPMI_VMCB16_STR ; Make room on LPM stack
if @EXPD

; If this is a 16-bit stack, zero the high-order word of ESI
; to simulate using SI instead of ESI.

	push	fs		; Pass stack selector
	call	DPMIFN_ESIMOD	; Modify high-order word of ESI
				; if stack selector is a 16-bit stack
; Check to see if the resulting offset is within the stack's bounds

	push	fs		; Pass stack selector
	push	esi		; ...	     offset
	call	DPMIFN_CHKSTK	; Check the stack offset
endif
	jc	near ptr DPMI_VMCB_LPMFULL ; Jump if there's no room

	mov	fs:[esi].DPMI_VMCB16_RIP,PMVMCB ; Return IP
	mov	fs:[esi].DPMI_VMCB16_RCS,ax	 ; ... CS
	mov	fs:[esi].DPMI_VMCB16_RFL,@DPMIOPL shl $IOPL ; ... FL
DPMI_VMCB_COM:

; Put the address (SSF, ESP, EFL, EIP, CSF) to which we're
; transferring on our PL0 stack

	PUSHD	fs		; Pass SS w/filler
	push	esi		; Pass ESP
	push	[ebp].INTXX_EFL ; Pass EFL
	and	[esp].EDD,not ((mask $VMHI) or (mask $RFHI) or \
			       (mask $NT)   or (mask $IOPL) or \
			       (mask $TF)) ; VM=RF=NT=IOPL=TF=0
	or	[esp].EDD,@DPMIOPL shl $IOPL ; IOPL=@DPMIOPL
	push	AGROUP:[ebx].HPDAVMC_CALLFVEC.FSEL.EDD ; Pass selector w/filler
	push	AGROUP:[ebx].HPDAVMC_CALLFVEC.FOFF ; Pass offset

	REGSAVE <LAST_DPMI_FS.EDD,LAST_DPMI_GS.EDD> ; Get previous values

; Return to caller with
;   DS:ESI ==> VM stack
;   ES:EDI ==> VM callback register structure

	mov	ds,AGROUP:[ebx].HPDAVMC_VMSS ; Get stack selector
	assume	ds:nothing	; Tell the assembler about it

	movzx	esi,[ebp].INTXX_ESP.ELO ; Get stack offset
	mov	eax,es:[edi].VMC_EAX ; Restore original EAX
	mov	ebx,es:[edi].VMC_EBX ; ...		 EBX
	mov	ecx,es:[edi].VMC_ECX ; ...		 ECX
	mov	edx,es:[edi].VMC_EDX ; ...		 EDX
	mov	ebp,es:[edi].VMC_EBP ; ...		 EBP

	VERREST <gs,fs> 	; Restore selectors with VERR
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

	iretd			; Continue with the callback procedure (PM only)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing



	assume	ds:DGROUP	; Tell the assembler about it
	assume	gs:AGROUP	; Tell the assembler about it

	public	DPMI_VMCB_LPMFULL
DPMI_VMCB_LPMFULL:
	SWATMAC ERR		; Call our debugger *FIXME* *TESTME*

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	mov	bx,[esp].VMCB_SS0 ; Get previous TSS_SS0
	mov	DGROUP:[eax].TSS_SS0,bx ; Restore

	mov	ebx,[esp].VMCB_ESP0 ; Get previous TSS_ESP0
	mov	DGROUP:[eax].TSS_ESP0,ebx ; Restore

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

	mov	eax,[esp].VMCB_LIFLG ; Get previous LAST_INTFLG
	mov	LAST_INTFLG,eax ; Restore

	mov	eax,[esp].VMCB_LICOM ; Get previous LAST_INTCOM
	mov	LAST_INTCOM,eax ; Restore

	dec	LPMSTK_CNT	; Count it out

; Switch back to the current TSS if we switched out

	mov	eax,[esp].VMCB_OPCURTSS ; Get original TSS
	xchg	eax,PCURTSS	; Get original TSS, save incoming one
	call	DPMIFN_NESTRET	; Check for nesting return with EAX=old PCURTSS
	assume	es:nothing,fs:nothing,gs:nothing ; Tell the assembler about it

	pop	LPMSTK_FVEC.FOFF ; Restore
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

; Good ole MASM 5.10B can't handle the following construction if we
; use the line continuation character.

STRIP1	=		 (size VMCB_LIFLG)   + (size VMCB_LICOM)
STRIP1	=	STRIP1 + (size VMCB_ESP0)    + (size VMCB_SS0)
STRIP1	=	STRIP1 + (size VMCB_OPCURTSS)
;;;STRIP1  =	   STRIP1 + (size VMCB_PL0LEN)

	add	esp,STRIP1	; Strip the stack back to INTDPI_STR

	popad			; Restore

; The MAX stack contains INTDPF_STR

	mov	[esp].INTDPF_INTNO,20h ; Put pseudo-INT # to avoid problems
				; in FLTPROC_STRIP
	jmp	FLTPROC_LPMFULL ; Join common error code


;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
; Raw mode switch from VM to PM
; SS:EBP ==> INTXX_STR on return
; INTXX_EAX.ELO = new DS
; INTXX_ECX.ELO = new ES
; INTXX_EDX.ELO = new SS
; INTXX_EBX	= new eSP
; INTXX_ESI.ELO = new CS
; INTXX_EDI	= new eIP

	public	DPMI_RMSVM2PM
	assume	ds:DGROUP	; Tell the assembler about it
	assume	gs:AGROUP	; Tell the assembler about it
DPMI_RMSVM2PM:
	and	LAST_INTFLG,not @INTCOM_VAL ; Mark as invalid

	mov	ebx,PCURTSS	; Get offset in DGROUP of current TSS
	mov	eax,OLD_PCURTSS ; Get offset in DGROUP of previous TSS
	mov	DGROUP:[ebx].DPTSS_PRMSTSS,eax ; Save for later use

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	jne	short @F	; Jump if not

	mov	[ebp].INTXX_EBX.EHI,0 ; Zero high-order word
	mov	[ebp].INTXX_EDI.EHI,0 ; Zero high-order word
@@:
	movzx	ax,DPMI_CPL	; Get DPMI CPL/RPL
	or	ax,mask $TI	; Plus LDT indicator

	REGSAVE <LAST_DPMI_FS.EDD,LAST_DPMI_GS.EDD> ; Push for VERREST
	VERREST <gs,fs> 	; Restore to previous value
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

	mov	ds,[ebp].INTXX_EAX.ELO ; Get new DS
	assume	ds:nothing	; Tell the assembler about it

	mov	es,[ebp].INTXX_ECX.ELO ; Get new ES
	assume	es:nothing	; Tell the assembler about it

	push	[ebp].INTXX_EDX ; Get new SS (with undefined filler)
	push	[ebp].INTXX_EBX ; Get new ESP
	push	[ebp].INTXX_EFL ; Get new EFL
	and	[esp].EDD,not ((mask $VMHI) or (mask $IOPL)) ; VM=IOPL=0
	or	[esp].EDD,@DPMIOPL shl $IOPL ; IOPL=@DPMIOPL
	push	[ebp].INTXX_ESI ; Get new CS (with undefined filler)
	or	[esp].EDD.ELO,ax ; Ensure LDT and DPMI CPL
	push	[ebp].INTXX_EDI ; Get new EIP

	mov	eax,[ebp].INTXX_EAX ; Restore original EAX
	mov	ebx,[ebp].INTXX_EBX ; ...		EBX
	mov	ecx,[ebp].INTXX_ECX ; ...		ECX
	mov	edx,[ebp].INTXX_EDX ; ...		EDX
	mov	esi,[ebp].INTXX_ESI ; ...		ESI
	mov	edi,[ebp].INTXX_EDI ; ...		EDI
	mov	ebp,[ebp].INTXX_EBP ; ...		EBP

	iretd			; Jump to DPMI client (PM Only)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing


;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
; Return from simulated VM interrupt
; SS:EBP ==> INTXX_STR on return

	public	DPMI_SIMVMRET
	assume	ds:DGROUP	; Tell the assembler about it
	assume	gs:AGROUP	; Tell the assembler about it
DPMI_SIMVMRET:
;;;;;;; mov	esi,PLCL_PL0CUR ; Get offset in DGROUP of current local stack
;;;;;;; 			; Note that there's a length dword at
;;;;;;; 			; DGROUP:[esi], hence the +4 below
;;;;;;; les	edi,DGROUP:[esi+4].SIMVMC_FVEC ; ES:EDI ==> caller's orginal struc
;;;;;;; assume	es:nothing	; Tell the assembler about it
;;;;;;;
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	les	edi,DGROUP:[eax].TSS_ESP0.EDF ; ES:EDI ==> stack mapped by SIMVMC_STR
	assume	es:nothing	; Tell the assembler about it

; ES:EDI ==> SIMVMC_STR

	les	edi,es:[edi].SIMVMC_FVEC ; ES:EDI ==> caller's original struc
	assume	es:nothing	; Tell the assembler about it

; Copy values from SS:EBP (mapped by INTXX_STR) to ES:EDI (mapped by VMC_STR)
; Don't copy SS:SP as we might have filled them in ourselves and don't
; want to destroy the caller's 0:0

	mov	cx,0		; Function code not to copy SS:SP and CS:IP
	call	DPMIFN_INTXX2VMC ; Copy registers from
				; INTXX_STR at SS:EBP to VMC_STR at ES:EDI
;;;
;;; ; Restore the stack from PLCL_PL0CUR
;;;
;;;	    mov     eax,PCURTSS     ; Get offset in DGROUP of current TSS
;;;	    les     edi,DGROUP:[eax].TSS_ESP0.EDF ; ES:EDI ==> stack mapped by SIMVMC_STR
;;;	    assume  es:nothing	    ; Tell the assembler about it
;;;
;;;	    mov     esp,edi	    ; Strip back to destination
;;; ;;;;;;; mov     esi,PLCL_PL0CUR ; Get offset in DGROUP of local PL0 stack
;;;	    lods    DGROUP:[esi].EDD ; Get and skip over length of saved stack
;;;	    mov     ecx,eax	    ; Copy to count register
;;;	    jecxz   DPMI_SIMVMRET_DMS ; Jump if we're at the deadman's switch
;;;
;;;	    cld 		    ; String ops fowardly
;;; S32 rep movs    <es:[edi].LO,DGROUP:[esi].LO> ; Copy to PL0 stack
;;;	    mov     PLCL_PL0CUR,esi ; Strip from storage
;;; DPMI_SIMVMRET_DMS:

; Strip back the stack to SIMVMC_STR

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	lss	esp,DGROUP:[eax].TSS_ESP0.EDF ; Strip it
	assume	ss:nothing	; Tell the assembler about it

; At this point, the stack is mapped by SIMVMC_STR

; Between the time we change the PL0 stack pointer in the TSS
; and we recalculate PL0STK pointers, we can't allow any interruption

;;;;;;; cli			; Disallow interrupts (already disabled)

;;;;;;; add	esp,type SIMVMC_PL0LEN ; Strip SIMVMC_PL0LEN
;;;;;;;
	pop	DGROUP:[eax].TSS_ESP0 ; Restore TSS pointer
	pop	DGROUP:[eax].TSS_SS0  ; ...	     selector
	pop	DGROUP:[eax].DPTSS_VMSTKOFF ; ... VM stack offset

	call	SET_PPL0STK	; Set PPL0STK... pointers

	REGREST <DPMICNT0E,DPMICNT0D,LAST_INTFLG,LAST_INTCOM> ; Restore

	REGREST <gs,fs> 	; Restore original selectors
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

	REGREST <edi,es>	; Restore original ptrs
	assume	es:nothing	; Tell the assembler about it
				; ES:EDI ==> original VMC_STR
	pop	ebp		; SS:EBP ==> INTXX_STR
				; (nothing above INTXX_EFL is valid)
	jmp	INT31_CLC	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_SIMVMI endp		; End DPMI_SIMVMI procedure
	NPPROC	DPMI_VMCRET -- Return From VM Callback Procedure
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Return from VM callback procedure

On entry:

ES:eDI	==>	new VM callback register structure
SS:EBP	==>	INTDPI_STR (discarded) followed by LPMSTK_FVEC,
		LAST_INTFLG, LAST_INTCOM, TSS_ESP0, TSS_SS0, PCURTSS,
		and the original INTXX_STR

|

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	push	PVMTSS		; Pass offset in DGROUP of the 1st TSS
	call	DPMIFN_LMSW	; Put MSW and INT 07h values into effect

; Convert ES:eDI into a linear address so we are unaffected when
; we (possibly) switch LDTs in DPMIFN_NESTRET

	push	es		; Pass selector as dword
	call	GETBASE 	; Return with EAX = base address of selector

	mov	ebx,eax 	; Save for later use

; Restore LPMSTK_FVEC, LAST_INTFLG, LAST_INTCOM, TSS_ESP0, and TSS_SS0

	add	esp,size INTDPI_STR ; Discard the client's return frame

;;; ; Restore the original PL0 stack from PLCL_PL0CUR
;;;
;;;	    mov     esi,PLCL_PL0CUR ; Get offset in DGROUP of current local stack
;;;	    lods    DGROUP:[esi].EDD ; Get and skip over length of saved stack
;;;	    mov     ecx,eax	    ; Copy to count register
;;;	    jecxz   DPMI_VMCRET_DMS ; Jump if we're at the deadman's switch
;;;	    sub     esp,ecx	    ; Back off to start
;;;	    mov     edx,esp	    ; Copy as destin
;;;
;;;	    REGSAVE <edi,es>	    ; Save for a moment
;;;
;;;	    mov     edi,edx	    ; Copy as destin
;;;
;;;	    mov     ax,ss	    ; Get stack selector
;;;	    mov     es,ax	    ; Address it
;;;	    assume  es:nothing	    ; Tell the assembler about it
;;;
;;;	    cld 		    ; String ops fowardly
;;; S32 rep movs    <es:[edi].LO,DGROUP:[esi].LO> ; Copy the stack down
;;;
;;;	    REGREST <es,edi>	    ; Restore
;;;	    assume  es:nothing	    ; Tell the assembler about it
;;;
;;;	    mov     PLCL_PL0CUR,esi ; Strip from storage
;;; DPMI_VMCRET_DMS:
	pop	LPMSTK_FVEC.FOFF ; De-allocate it
	pop	LPMSTK_FVEC.FSEL.EDD ; ...
	dec	LPMSTK_CNT	; Count it out

	pop	LAST_INTFLG	; Restore
	pop	LAST_INTCOM	; Restore

;;;;;;; add	esp,type VMCB_PL0LEN ; Strip VMCB_PL0LEN
;;;;;;;
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	pop	DGROUP:[eax].TSS_ESP0 ; Restore
	pop	DGROUP:[eax].TSS_SS0  ; ...

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

; Restore PCURTSS

	pop	PCURTSS 	; Restore

; In case we're nested, we need to pass the VM callback structure back
; to VM before we lose addressability.

; The stack is mapped by the original INTXX_STR which we use for the IRETD to VM

	mov	ebp,esp 	; SS:EBP ==> INTXX_STR

; Save old PCURTSS to pass to DPMIFN_NESTRET

	push	eax		; Save for a moment

; Pass VM callback structure register back to VM

	IF16ZX	di		; Zero to use as dword if 16-bit client

	mov	eax,AGROUP:[ebx+edi].VMC_EAX ; Get new EAX
	mov	[ebp].INTXX_EAX,eax ; Pass back

	mov	eax,AGROUP:[ebx+edi].VMC_EBX ; Get new EBX
	mov	[ebp].INTXX_EBX,eax ; Pass back

	mov	eax,AGROUP:[ebx+edi].VMC_ECX ; Get new ECX
	mov	[ebp].INTXX_ECX,eax ; Pass back

	mov	eax,AGROUP:[ebx+edi].VMC_EDX ; Get new EDX
	mov	[ebp].INTXX_EDX,eax ; Pass back

	mov	eax,AGROUP:[ebx+edi].VMC_ESI ; Get new ESI
	mov	[ebp].INTXX_ESI,eax ; Pass back

	mov	eax,AGROUP:[ebx+edi].VMC_EDI ; Get new EDI
	mov	[ebp].INTXX_EDI,eax ; Pass back

	mov	eax,AGROUP:[ebx+edi].VMC_EBP ; Get new EBP
	mov	[ebp].INTXX_EBP,eax ; Pass back

	mov	ax,AGROUP:[ebx+edi].VMC_GS ; Get new GS
	mov	[ebp].INTXX_GS,ax ; Pass back

	mov	ax,AGROUP:[ebx+edi].VMC_FS ; Get new FS
	mov	[ebp].INTXX_FS,ax ; Pass back

	mov	ax,AGROUP:[ebx+edi].VMC_DS ; Get new DS
	mov	[ebp].INTXX_DS,ax ; Pass back

	mov	ax,AGROUP:[ebx+edi].VMC_ES ; Get new ES
	mov	[ebp].INTXX_ES,ax ; Pass back

	mov	ax,AGROUP:[ebx+edi].VMC_SS ; Get new SS
	mov	[ebp].INTXX_SS,ax ; Pass back

	movzx	eax,AGROUP:[ebx+edi].VMC_SP ; Get new SP
	mov	[ebp].INTXX_ESP,eax ; Pass back

	movzx	eax,AGROUP:[ebx+edi].VMC_FL ; Get new FL
	and	ax,not (mask $IOPL) ; Clear the IOPL bits
	or	eax,(mask $VMHI) or (@VMIOPL shl $IOPL) ; VM=1, IOPL=@VMIOPL
	and	eax,not ((mask $RFHI) or (mask $TF)) ; RF=TF=0
	mov	[ebp].INTXX_EFL,eax ; Pass back

	mov	ax,AGROUP:[ebx+edi].VMC_CS ; Get new CS
	mov	[ebp].INTXX_CS,ax ; Pass back

	movzx	eax,AGROUP:[ebx+edi].VMC_IP ; Get new IP
	mov	[ebp].INTXX_EIP,eax ; Pass back

	pop	eax		; Restore old PCURTSS

; Check for return from nesting

	call	DPMIFN_NESTRET	; Check for nesting return with EAX=old PCURTSS
	assume	es:nothing,fs:nothing,gs:nothing ; Tell the assembler about it

; Note that we may have switched to a new LDT
; so some selectors may have been set to zero

; * Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

	popad			; Restore all EGP registers

	add	esp,size INTXX_ERR ; Strip off pseudo-error code

	jmp	ERM_FVEC	; Return to RM/VCPI

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_VMCRET endp		; End DPMI_VMCRET procedure
	NPPROC	DPMIFN_NESTOUT -- Save The Old State And Switch To The New One
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Save the old state and switch to the new one.

On entry:

EBX	=	offset in DGROUP of the new TSS

On exit:

|

	REGSAVE <edx,esi,es>	; Save registers

; Save the current interrupt vector state into the current TSS

	push	PCURTSS 	; Pass as argument
	push	0		; Tell 'em not to re-initialize
	call	DPMIFN_SAVEOLDPM ; Save 'em

; Switch old and new TSS selectors and pointers to the current TSS
; and reset TR

	mov	PCURTSS,ebx	; Save as offset in DGROUP of the current TSS

	movzx	esi,DGROUP:[ebx].DPTSS_SEL ; Get the incoming TSS selector
	and	esi,not (mask $PL) ; Clear the RPL bits
	mov	VM2PM_TSS,si	; Save as current TSS selector

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	mov	edx,[esp].DTR_BASE ; AGROUP:EDX ==> GDT
	add	esp,size DTR_STR ; Strip

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

	and	AGROUP:[edx].DESC_ACCESS[esi],not (mask $DS_BUSY) ; Clear the
				; busy bit in preparation for LTR
	ltr	si		; Set new TSS into place

; Set the base of the new LDT

	push	DGROUP:[ebx].TSS_LDT.EDD ; Pass LDT selector as dword
	push	DGROUP:[ebx].DPTSS_LaLDT ; ...	LDT base address
	call	SETBASE 	; Set the base address

; Tell the CPU about the new LDTR

	lldt	DGROUP:[ebx].TSS_LDT ; Set LDTR

; Switch to the incoming address space

	push	ebx		; Pass offset in DGROUP of incoming TSS
	call	DPMIFN_SWITCHADDR ; Switch to the incoming address space

; Restore the interrupt vector state from the new TSS

	push	0		; Tell 'em we're NOT terminating
	push	ebx		; Pass offset in DGROUP of the current TSS
	call	DPMIFN_RESTOLDPM ; Restore it

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers
DPMIFN_NESTOUT_EXIT:
	REGREST <es,esi,edx>	; Restore
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_NESTOUT endp		; End DPMIFN_NESTOUT procedure
	NPPROC	DPMIFN_NESTRET -- Check on Return From Nesting
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Check on return from nesting

On entry:

EAX	=	old PCURTSS

On exit:

ES, FS, GS =	 0

|

	REGSAVE <eax,ebx,edx>	; Save registers

	cmp	eax,PCURTSS	; Did we return from nesting?
	je	near ptr DPMIFN_NESTRET_EXIT ; Jump if not

	xor	bx,bx		; A convenient zero
	mov	es,bx		; Set to known value as we're
	assume	es:nothing	; Tell the assembler about it
	mov	fs,bx		; ...changing the LDTR and these
	assume	fs:nothing	; Tell the assembler about it
	mov	gs,bx		; ...selectors might become invalid
	assume	gs:nothing	; Tell the assembler about it

; Save the current interrupt vector state into the old TSS

	push	eax		; Pass as argument
	push	0		; Tell 'em not to re-initialize
	call	DPMIFN_SAVEOLDPM ; Save 'em

; Reset TR

	mov	eax,PCURTSS	; Get offset in DGROUP of incoming TSS
	movzx	ebx,DGROUP:[eax].DPTSS_SEL ; Get incoming TSS selector
	and	ebx,not (mask $PL) ; Clear the RPL bits
	mov	VM2PM_TSS,bx	; Save as current TSS selector

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	mov	edx,[esp].DTR_BASE ; AGROUP:EDX ==> GDT
	add	esp,size DTR_STR ; Strip

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

	and	AGROUP:[edx].DESC_ACCESS[ebx],not (mask $DS_BUSY) ; Clear the
				; busy bit in preparation for LTR
	ltr	bx		; Set new TSS into place

; Set the base of the new LDT

	push	DGROUP:[eax].TSS_LDT.EDD ; Pass LDT selector as dword
	push	DGROUP:[eax].DPTSS_LaLDT ; ...	LDT base address
	call	SETBASE 	; Set the base address

; Tell the CPU about the new LDTR

	lldt	DGROUP:[eax].TSS_LDT ; Set LDTR

; Switch to the incoming address space

	push	eax		; Pass offset in DGROUP of incoming TSS
	call	DPMIFN_SWITCHADDR ; Switch to the incoming address space

	push	0		; Tell 'em we're NOT terminating
	push	eax		; Pass offset in DGROUP of the current TSS
	call	DPMIFN_RESTOLDPM ; Restore it

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers
DPMIFN_NESTRET_EXIT:
	REGREST <edx,ebx,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_NESTRET endp		; End DPMIFN_NESTRET procedure
	NPPROC	DPMIFN_INTXX2VMC -- Copy Registers From INTXX_STR to VMC_STR
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

On entry:

ES:EDI	==>	VMC_STR
SS:EBP	==>	INTXX_STR
CX	=	1 copy SS:SP and CS:IP from INTXX_STR
	=	0 don't ...

|

	REGSAVE <eax>		; Save register

	mov	ax,[ebp].INTXX_GS ; Get GS from VM
	mov	es:[edi].VMC_GS,ax ; Save it

	mov	ax,[ebp].INTXX_FS ; Get FS from VM
	mov	es:[edi].VMC_FS,ax ; Save it

	mov	ax,[ebp].INTXX_DS ; Get DS from VM
	mov	es:[edi].VMC_DS,ax ; Save it

	mov	ax,[ebp].INTXX_ES ; Get ES from VM
	mov	es:[edi].VMC_ES,ax ; Save it

	mov	ax,[ebp].INTXX_EFL.ELO ; Get FL from VM
	mov	es:[edi].VMC_FL,ax ; Save it

	mov	eax,[ebp].INTXX_EAX ; Get EAX from VM
	mov	es:[edi].VMC_EAX,eax ; Save it

	mov	eax,[ebp].INTXX_EBX ; Get EBX from VM
	mov	es:[edi].VMC_EBX,eax ; Save it

	mov	eax,[ebp].INTXX_ECX ; Get ECX from VM
	mov	es:[edi].VMC_ECX,eax ; Save it

	mov	eax,[ebp].INTXX_EDX ; Get EDX from VM
	mov	es:[edi].VMC_EDX,eax ; Save it

	mov	eax,[ebp].INTXX_ESI ; Get ESI from VM
	mov	es:[edi].VMC_ESI,eax ; Save it

	mov	eax,[ebp].INTXX_EDI ; Get EDI from VM
	mov	es:[edi].VMC_EDI,eax ; Save it

	mov	eax,[ebp].INTXX_EBP ; Get EBP from VM
	mov	es:[edi].VMC_EBP,eax ; Save it

	jcxz	DPMIFN_INTXX2VMC_EXIT ; Jump if we're not to copy

	mov	ax,[ebp].INTXX_SS ; Get SS from VM
	mov	es:[edi].VMC_SS,ax ; Save it

	mov	ax,[ebp].INTXX_ESP.ELO ; Get SP from VM
	mov	es:[edi].VMC_SP,ax ; Save it

	mov	ax,[ebp].INTXX_CS ; Get CS from VM
	mov	es:[edi].VMC_CS,ax ; Save it

	mov	ax,[ebp].INTXX_EIP.ELO ; Get IP from VM
	mov	es:[edi].VMC_IP,ax ; Save it
DPMIFN_INTXX2VMC_EXIT:
	REGREST <eax>		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_INTXX2VMC endp		; End DPMIFN_INTXX2VMC procedure
	NPPROC	DPMI_SIMVMCFR -- DPMI 0.9 Function to Simulate VM Call With Far Return
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 0.9 function to simulate VM call with far return frame

On entry (in INTXX_STR):

AX	=	0301h
BH	=	flags
		 Bit 0:    reset the PIC and A20 (ignored)
		 Bit 1-7:  reserved, must be 0
CX	=	# words to copy from PM to VM stack
ES:eDI	==>	VM register structure in VMC_STR format
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

If this routine is at PL 0, INTXX_ESP and INTXX_SS are
filled in and point to the caller's stack from which the
parameters are to be copied.

If this routine is at PL 3, the parameters to be copied
are found starting at INTXX_ESP and following.

On exit (in INTXX_STR):

CF	=	0 if successful

CF	=	1 if not successful
AX	=	8012 if linear memory unavailable (stack)
	=	8013 if physical ...
	=	8014 if backing store ...
	=	8021 if invalid value (CX too large)
	=	8022 if invalid selector

All other registers except EBP, FS, GS, and SS may be clobbered.

|

	mov	edi,[ebp].INTXX_EDI ; Get caller's eDI
	IF16ZX	di		; Zero to use as dword if 16-bit client

	mov	es,[ebp-@I31BACK].I31_ES ; Get caller's ES
	assume	es:nothing	; Tell the assembler about it

	cli			; Disallow interrupts

	mov	DPMI_STKFLG,2	; Mark as far return frame

	jmp	DPMI_SIMVMI_COM ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_SIMVMCFR endp		; End DPMI_SIMVMCFR procedure
	NPPROC	DPMI_SIMVMCIR -- DPMI 0.9 Function to Simulate VM Call With IRET Return
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 0.9 function to simulate VM call with IRET return frame

On entry (in INTXX_STR):

AX	=	0302h
BH	=	flags
		 Bit 0:    reset the PIC and A20 (ignored)
		 Bit 1-7:  reserved, must be 0
CX	=	# words to copy from PM to VM stack
ES:eDI	==>	VM register structure in VMC_STR format
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

If this routine is at PL 0, INTXX_ESP and INTXX_SS are
filled in and point to the caller's stack from which the
parameters are to be copied.

If this routine is at PL 3, the parameters to be copied
are found starting at INTXX_ESP and following.

On exit (in INTXX_STR):

CF	=	0 if successful

CF	=	1 if not successful
AX	=	8012 if linear memory unavailable (stack)
	=	8013 if physical ...
	=	8014 if backing store ...
	=	8021 if invalid value (CX too large)
	=	8022 if invalid selector

All other registers except EBP, FS, GS, and SS may be clobbered.

|

	mov	edi,[ebp].INTXX_EDI ; Get caller's eDI
	IF16ZX	di		; Zero to use as dword if 16-bit client

	mov	es,[ebp-@I31BACK].I31_ES ; Get caller's ES
	assume	es:nothing	; Tell the assembler about it

	cli			; Disallow interrupts

	mov	DPMI_STKFLG,3	; Mark as IRET frame

COMMENT|

If this call comes from a Rational Systems-based DPMI client, and they
are using their default flags (zero), ensure that IF=1 in the caller's
return flags in order to overcome a bug in their code which disables
interrupts forever in conjunction with mouse activity.

|

	test	[ebp].INTXX_CS,mask $PL ; Izit PL0?
	jz	short @F	; Jump if so

	test	I31_FLAG,mask $I31_RSI ; Is there a Rational Systems in the room?
	jz	short @F	; Jump if not

	cmp	es:[edi].VMC_FL,0 ; Izit default?
	jne	short @F	; Jump if not

	or	es:[edi].VMC_FL,mask $IF ; Ensure IF=1
@@:
	jmp	DPMI_SIMVMI_COM ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_SIMVMCIR endp		; End DPMI_SIMVMCIR procedure
	NPPROC	DPMI_GETVMCB -- DPMI 0.9 Function to Get VM Callback Address
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 0.9 function to get a VM callback address

On entry (in INTXX_STR):

AX	=	0303h
DS:eSI	=	Sel:Off of PM procedure to call
ES:eDI	=	Sel:Off of PM buffer for VM register structure to
		 be used when calling callback routine
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

On exit (in INTXX_STR):

CF	=	0 if successful
CX:DX	=	Seg:Off of VM callback

CF	=	1 if not successful
AX	=	8015 if no callback available

All other registers except EBP, FS, GS, and SS may be clobbered.

|

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

; Find an available VM callback

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	mov	edi,DGROUP:[eax].DPTSS_LaHPDA ; DS:EDI ==> HPDA
	mov	dx,DGROUP:[eax].DPTSS_HPDASEG ; Get segment of HPDA for later use

	movzx	esi,HPDAVMC_OFF ; Get offset of VM callback structures
	movzx	ecx,HPDAVMC_CNT ; Get # VM callback strucs

	pushf			; Save flags
	cli			; Disallow interrupts
@@:
	cmp	AGROUP:[edi+esi].HPDAVMC_INTFF[0],@OPCOD_INT3 ; Izit available?
	je	short DPMI_GETVMCB1 ; Jump if so

	add	esi,size HPDAVMC_STR ; Skip to next entry

	loop	@B		; Jump if more VM callback strucs to check
DPMI_GETVMCB_ERR:
	popf			; Restore flags
				; (note interrupts might become enabled)
	jmp	INT31_ERR_NOVMC ; Join common error code


DPMI_GETVMCB1:

; Find an available selector for the VM stack segment

	push	@BIT0		; Mark as segment-to-selector
	push	1		; # selectors to allocate
	call	GET_LDT 	; Get next LDT selector in EAX ($TI and $PL set)
				; and LDTE marked as CPL3_DATA
	jc	short DPMI_GETVMCB_ERR ; Jump if not available

; Initialize the VM callback code which marks the callback as in use

	mov	AGROUP:[edi+esi].HPDAVMC_INTFF[0],@OPCOD_INT ; Save INT @PMH_INT
%	mov	AGROUP:[edi+esi].HPDAVMC_INTFF[1],0&@PMH_INT&h ; ...
	mov	AGROUP:[edi+esi].HPDAVMC_INTFF[2],@OPCOD_RETF ; Save RETF
	mov	AGROUP:[edi+esi].HPDAVMC_INTFF[3],@OPCOD_NOP ; Save NOP
	mov	AGROUP:[edi+esi].HPDAVMC_VMSS,ax ; Save stack selector

	popf			; Restore flags
				; (note interrupts might become enabled)
; Save address of PM procedure to call from DS:eSI

	mov	ax,[ebp-@I31BACK].I31_DS ; Get CALLFVEC selector
	mov	AGROUP:[edi+esi].HPDAVMC_CALLFVEC.FSEL,ax ; Mark as in use

	mov	eax,[ebp].INTXX_ESI ; Get CALLFVEC offset
	IF16ZX	ax		; Zero to use as dword if 16-bit client
	mov	AGROUP:[edi+esi].HPDAVMC_CALLFVEC.FOFF,eax ; Save for later use

; Save address of VM register structure from ES:eDI

	mov	ax,[ebp-@I31BACK].I31_ES ; Get REGFVEC selector
	mov	AGROUP:[edi+esi].HPDAVMC_REGFVEC.FSEL,ax ; Save for later use

	mov	eax,[ebp].INTXX_EDI ; Get REGFVEC offset
	IF16ZX	ax		; Zero to use as dword if 16-bit client
	mov	AGROUP:[edi+esi].HPDAVMC_REGFVEC.FOFF,eax ; Save for later use

; Return to caller the address of the VM callback in CX:DX

	lea	si,[esi].HPDAVMC_INTFF ; Skip to INT @PMH_INT code

	mov	[ebp].INTXX_EDX.ELO,si ; Return the offset in DX
	mov	[ebp].INTXX_ECX.ELO,dx ; ...	     segment in CX

	jmp	INT31_CLC	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_GETVMCB endp		; End DPMI_GETVMCB procedure
	NPPROC	DPMI_RELVMCB -- DPMI 0.9 Function to Free VM Callback Address
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 0.9 function to free a VM callback address

On entry (in INTXX_STR):

AX	=	0304h
CX:DX	=	Seg:Off of VM callback to free
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

On exit (in INTXX_STR):

CF	=	0 if successful

CF	=	1 if not successful
AX	=	8024 if invalid callback address

All other registers except EBP, FS, GS, and SS may be clobbered.

|

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

; Validate the VM callback address in CX:DX

	movzx	eax,[ebp].INTXX_ECX.ELO ; Get the putative VM callback segment
	shl	eax,4-0 	; Convert from paras to bytes
	movzx	ebx,[ebp].INTXX_EDX.ELO ; Get the putative VM callback offset

; Check for HPDA signature

	cmp	AGROUP:[eax].HPDA_SIGN.EDD,@HPDA_SIG2 ; Izit our boy?
	jne	near ptr INT31_ERR_INVVMC ; Jump if not

; Check for VM callback code

	cmp	AGROUP:[eax+ebx].HPDAVMC_INTFF[0],@OPCOD_INT ; Izit INT @PMH_INT?
	jne	near ptr INT31_ERR_INVVMC ; Jump if not

%	cmp	AGROUP:[eax+ebx].HPDAVMC_INTFF[1],0&@PMH_INT&h ; ...
	jne	near ptr INT31_ERR_INVVMC ; Jump if not

	PUSHW	0		; Ignore modifiable check
	push	AGROUP:[eax+ebx].HPDAVMC_VMSS ; Get stack selector
	call	VALID_LSEL	; Ensure LDT selector is valid
	jc	near ptr INT31_ERR_INVVMC ; Jump if invalid

	push	AGROUP:[eax+ebx].HPDAVMC_VMSS ; Get stack selector
	call	CLR_LDTZERO	; Free this LDT selector & zero selectors
	jc	near ptr INT31_ERR_INVVMC ; Jump if invalid

	mov	AGROUP:[eax+ebx].HPDAVMC_INTFF[0],@OPCOD_INT3 ; Mark as free

	jmp	INT31_CLC	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_RELVMCB endp		; End DPMI_RELVMCB procedure
	NPPROC	DPMI_GETSSR -- DPMI 0.9 Function to Get State Save/Restore Addresses
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 0.9 function to get state save/restore addresses

On entry (in INTXX_STR):

AX	=	0305h
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

On exit (in INTXX_STR):

CF	=	0
AX	=	byte size of buffer required to save state
BX:CX	=	Seg:Off of VM routine to save/restore state
SI:eDI	=	Sel:Off of PM ...

All other registers except EBP, FS, GS, and SS may be clobbered.

|

; Because we are fully re-entrant, we don't need to save the
; other mode's state -- return VM address to RETF, and PM address
; to (in effect) the same

	mov	[ebp].INTXX_EAX.ELO,0 ; Save SSR buffer size

; Save VM address

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	mov	ax,DGROUP:[eax].DPTSS_HPDASEG ; Get segment of HPDA
	mov	[ebp].INTXX_EBX.ELO,ax ; Save segment
	mov	[ebp].INTXX_ECX.ELO,offset HPDA_SSR ; Save offset

; Save PM address

	mov	ax,DPMI_IDEF	; Get our interrupt selector
	mov	[ebp].INTXX_ESI.ELO,ax ; Save selector

	mov	ax,PMIDEF_SSR16 ; Assume it's a 16-bit client

	cmp	DPMITYPE,@DPMITYPE16 ; Izit a 16-bit client?
	je	short @F	; Jump if so

	mov	ax,PMIDEF_SSR32 ; It's a 32-bit client
@@:
	mov	[ebp].INTXX_EDI.ELO,ax ; Save offset

	cmp	DPMITYPE,@DPMITYPE16 ; Izit a 16-bit client?
	je	short @F	; Jump if so

	mov	[ebp].INTXX_EDI.EHI,0 ; Zero high-order word
@@:
	jmp	INT31_CLC	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_GETSSR endp		; End DPMI_GETSSR procedure
	NPPROC	DPMI_GETRMS -- DPMI 0.9 Function to Get Raw Mode Switch Addresses
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI 0.9 function to get raw mode switch addresses

On entry (in INTXX_STR):

AX	=	0306h
IF	=	caller's (possibly enabled)
SS:EBP	==>	INTXX_STR (nothing above INTXX_EFL is valid)

On exit (in INTXX_STR):

CF	=	0
BX:CX	=	VM to PM switch address
SI:eDI	=	PM to VM switch address

All other registers except EBP, FS, GS, and SS may be clobbered.

|

; Save the PM to VM switch address in SI:eDI

	mov	ax,DPMI_IDEF	; Get our interrupt selector
	mov	[ebp].INTXX_ESI.ELO,ax ; Save selector
	mov	[ebp].INTXX_EDI.ELO,PMIRMS ; Save offset

	cmp	DPMITYPE,@DPMITYPE16 ; Izit a 16-bit client?
	je	short @F	; Jump if so

	mov	[ebp].INTXX_EDI.EHI,0 ; Zero the high-order word
@@:

; Save the VM to PM switch address in BX:CX

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	mov	ax,DGROUP:[eax].DPTSS_HPDASEG ; Get segment of HPDA
	mov	[ebp].INTXX_EBX.ELO,ax ; Save VM2PM segment
	mov	[ebp].INTXX_ECX.ELO,offset HPDA_RMSRET ; Save VM2PM offset

	jmp	INT31_CLC	; Join common exit code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_GETRMS endp		; End DPMI_GETRMS procedure
	NPPROC	DPMI_RMSPM2VM -- Raw Mode Switch From PM to VM
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Raw mode switch from PM to VM

On entry:

AX     =       new DS
CX     =       new ES
DX     =       new SS
EBX    =       new eSP
SI     =       new CS
EDI    =       new eIP

The MAX stack is mapped by INTDPI_STR (however it is ignored)
except for INTDPI_EFL.

|

; We subtract from ESP here in one chunk as we can't afford
; to take an interrupt between the PUSHes.  If we do, it might
; look like a HW-VM which it isn't.

	sub	esp,type INTCOM_STR ; Make room for INTCOM_STR

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

; Check for nested return from Raw Mode Switch

	push	eax		; Save for a moment

	mov	eax,PCURTSS	; Get offset in DGROUP of the current TSS
	xchg	eax,DGROUP:[eax].DPTSS_PRMSTSS ; Get offset in DGROUP of prev TSS

; Check for return from nesting

	call	DPMIFN_NESTRET	; Check for nesting return with EAX=old PCURTSS
	assume	es:nothing,fs:nothing,gs:nothing ; Tell the assembler about it

; Set new LPM stack top for nested callers if it's active
; and we're called from PM

	lea	eax,[esp+4]	; SS:EAX ==> INTCOM_STR followed by INTDPI_STR
	add	eax,type INTCOM_STR ; SS:EAX ==> INTDPI_STR from PL3
	push	eax		; Pass the offset
	call	DPMIFN_LPMSTK	; Save new LPM stack as appropriate

	pop	eax		; Restore

	push	PVMTSS		; Pass offset in DGROUP of the 1st TSS
	call	DPMIFN_LMSW	; Put MSW and INT 07h values into effect

; Note that we leave INTDPI_STR on the stack so that there's no
; confusing the value of ESP at this point with any of the PPL0STK_xxx
; values.

	mov	[esp].INTCOM_GS,0 ; New GS
	mov	[esp].INTCOM_FS,0 ; ... FS
	mov	[esp].INTCOM_DS,ax ; ... DS
	mov	[esp].INTCOM_ES,cx ; ... ES
	mov	[esp].INTCOM_SS,dx ; ... SS
	mov	[esp].INTCOM_ESP.ELO,bx ; ... eSP low
	mov	[esp].INTCOM_ESP.EHI,0	; ... eSP high

	push	[esp+(type INTCOM_STR)].INTDPI_EFL ; Get caller's EFL
	and	[esp].EDD,not (mask $IOPL) ; Clear the IOPL bits
	or	[esp].EDD,(mask $VMHI) or (@VMIOPL shl $IOPL) ; VM=1, IOPL=@VMIOPL
	pop	[esp].INTCOM_EFL ; ... EFL

	mov	[esp].INTCOM_CS,si ; ... CS
	mov	[esp].INTCOM_EIP.ELO,di ; ... eIP low
	mov	[esp].INTCOM_EIP.EHI,0	; ... eIP high

; Clear NT bit so IRETD won't affect task switch

	pushf			; Save flags
	and	[esp].ELO,not (mask $NT) ; NT=0
	popf			; Put it into effect

	jmp	ERM_FVEC	; Enter RM/VCPI mode

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_RMSPM2VM endp		; End DPMI_RMSPM2VM procedure
	NPPROC	DPMIFN_SWITCHADDR -- Switch Address Spaces
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Switch to a new linear address space on a context switch or
client termination.

|

SWITCH_STR struc

	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
SWITCH_ITSS dd	?		; Offset in DGROUP of the incoming TSS

SWITCH_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ebx,esi,edi,ds,gs> ; Save registers

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	gs,SEL_4GB	; Get AGROUP data selector (for PHYS2MMLIN)
	assume	gs:AGROUP	; Tell the assembler about it

	mov	esi,[ebp].SWITCH_ITSS ; Get the offset in DGROUP of the incoming TSS
	mov	ax,DGROUP:[esi].DPTSS_SEL ; Get incoming TSS's selector
	mov	VMMCurrentClient,ax ; Set as current client
	mov	eax,DGROUP:[esi].TSS_CR3 ; Get the incoming CR3

; Find the linear address of this page in itself as we can change
; the linear address of the selector GXTHDR_SELCR3.

	push	dword ptr (1*1024*1024) ; Pass minimum acceptable linear address
	push	eax		; Pass the MM's CR3
	push	eax		; Pass the physical address (/4KB)
	call	PHYS2MMLIN	; Translate physical addr to MM-linear in EAX
;;;;;;; jc	short FIND_XMS_MMLIN_EXIT ; Jump if not found (note CF=0)

	mov	edi,eax 	; Copy for later use

; Establish addressibility to GDT

	movzx	ebx,GXTHDR.GXTHDR_SELCR3 ; Get the selector
	and	ebx,not (mask $PL) ; Clear the RPL bits

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	add	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> GDT
	add	esp,size DTR_STR ; Strip

	mov	AGROUP:[ebx].DESC_BASE01,ax ; Save bytes 0-1
	shr	eax,16		; Shift down the high-order word
	mov	AGROUP:[ebx].DESC_BASE2,al ; Save byte 2
	mov	AGROUP:[ebx].DESC_BASE3,ah ; ...       3

	mov	eax,DGROUP:[esi].TSS_CR3 ; Get the incoming CR3

;;;;	mov	edi,PageDirLA	; Get the linear address of the Page Directory
;;;;	MakePTEaddress edi	; Convert it into a base address
	mov	cr3,eax 	; Save as new PDBR

; Tell GXT about the new CR3

	push	eax		; Pass physical address
	push	edi		; ...  linear address
	call	TellGXT_CR3	; Tell 'em (after the fact)

;;;;	or	eax,@PTE_URP	; Mark as User, Read-Write, and Present
;;;;	mov	AGROUP:[edi].PDT_PTE,eax ; Save as new PDE
;;;;
;;;;	FlushTLB eax		; Because we just changed the PDE, flush the TLB
;;;;
	REGREST <gs,ds,edi,esi,ebx,eax> ; Restore
	assume	ds:nothing,gs:nothing ; Tell the assembler about it

	pop	ebp		; Restore

	ret	4		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_SWITCHADDR endp		; End DPMIFN_SWITCHADDR procedure

PROG	ends			; End PROG segment

	MEND			; End DPMI_K31 module
