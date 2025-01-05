;' $Header$
	title	DPMI_IDT -- DPMI.LOD IDT Routines
	page	58,122
	name	DPMI_IDT
COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1987-2003 Sudley Place Software.  All Rights Reserved.

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include PTR.INC
	include CPUFLAGS.INC
	include ALLMEM.INC
	include KEYCALL.INC
	include ASCII.INC
	include OPCODES.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_LCL.INC
	include DPMI_SEG.INC
	include DPMI_SWT.INC

	include QMAX_I31.INC		; Must precede QMAXDPMI.INC
	include QMAXDPMI.INC		; Must follow QMAX_I31.INC
	include QMAX_GLB.INC
	include QMAX_TSS.INC
	include QMAX_VMM.INC
.list

DATA16	segment use16 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	extrn	LCL_FLAG:word

DATA16	ends			; End DATA16 segment


;;;; CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
;;;;	     assume  ds:PGROUP
;;;;
;;;;	     extrn   ERM_FVEC:fword
;;;;
;;;; CODE16A ends		     ; End CODE16A segment
;;;;
;;;;
DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_IDT_DATA
@DPMI_IDT_DATA	label byte	; Mark module start in .MAP file

	extrn	OLDINT_FVEC:fword
	extrn	OLDINT0D_FVEC:fword
	extrn	OLDINT_ARB:byte

	extrn	SAVE_EAX:dword

;;;;;;; extrn	I13CNT:word

	extrn	I31_FLAG:word

	extrn	VMM_FLAG:word

	extrn	LaINDOS:dword

	extrn	SEL_4GB:word
	extrn	SEL_DATA:word
	extrn	PPL0STK_DNRM:dword
	extrn	PPL0STK_DERR:dword
	extrn	DPMITYPE:byte
;;;;;;; extrn	DPMICNT0D:word
;;;;;;; extrn	DPMICNT0E:word
	extrn	DPMI_HWSP:byte
	extrn	DPMI_HW:byte
	extrn	DPMI_CPIHOOK:byte
	extrn	DPMI_PPIHOOK:byte
	extrn	DPMI_CPFHOOK:byte
	extrn	DPMI_PVFHOOK:byte
	extrn	DPMIMSG:word
	extrn	LAST_DPMI_DS:word
	extrn	LAST_DPMI_ES:word
	extrn	LAST_DPMI_FS:word
	extrn	LAST_DPMI_GS:word

	extrn	PageFaultActive:byte
	extrn	VMMCurrentClient:word

;;;;;;; extrn	HIMEM_CS:word
	extrn	PPL0STK_NRM:dword
	extrn	PPL0STK_ERR:dword
;;;;;;; extrn	LaVMTSS:dword
	extrn	PPRMTSS:dword
	extrn	PCURTSS:dword

;;;;;;; extrn	SAVE_EBX:dword
;;;;;;; extrn	LPMSTK_FVEC:fword
	extrn	LPMSTK_SEL:word

	extrn	MSG_L01:tbyte
	extrn	MSG_L03:tbyte
	extrn	MSG_L08:tbyte
	extrn	MSG_L0A:tbyte
	extrn	MSG_L0B:tbyte
	extrn	MSG_L0C:tbyte
	extrn	L0CNUM:byte

	extrn	DPMIMSG_LOW:tbyte

	extrn	PMFLT_FVECS:fword


DD_MAC	macro	N

	dd	offset PGROUP:INTPROC&N

	endm			; DD_MAC


	public	TABINT_OFF
TABINT_OFF label dword

CNT	=	0		; Start with first interrupt

	rept	256		; Define all interrupts

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	DD_MAC	%N
CNT	=	CNT+1

	endm			; REPT 100h

	public	LAST_INTCOM,LAST_INTFLG
LAST_INTCOM dd	?		; Offset of bottom of last INTCOM interrupt frame
LAST_INTFLG dd	?		; ...and its flag

	public	SAVE_DSXX
SAVE_DSXX dd	?		; Save area for DS

	public	GLB_FLAG
GLB_FLAG dw	0		; Global flags

DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP,ds:PGROUP

	public	@DPMI_IDT_PROG
@DPMI_IDT_PROG: 		; Mark module start in .MAP file

	extrn	INT31_VM2PM_RET:near

	extrn	SETBASE:near
	extrn	DPMIFN_EXPLPM:near
	extrn	DPMI_SIMRET:near
	extrn	DPMI_INT01:near
	extrn	PMINTCOM:near
	extrn	PMFLTCOM:near
	extrn	VMFLTCOM:near
	extrn	FLTPROC_APPL:near
	extrn	FLTPROC_ABORT:near
;;;;;;; extrn	FLTPROC_VMFULL:near
	extrn	TellGXT_CR3:near
	extrn	DD2HEX:near

;;;;;;; extrn	WRAP_DISABLE:near
;;;;;;; extrn	WRAP_ENABLE:near

	public	FLTERR
;		 11111111111111110000000000000000
;		 FEDCBA9876543210FEDCBA9876543210
FLTERR	dd	00000000000001100111110100000000b ; Faults with error code

	NPPROC	SET_PPL0STK -- Setup PPL0STK Variables
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

;;;;;;; REGSAVE <eax,ebx,ds,gs> ; Save registers
	REGSAVE <eax,ebx,ds>	; Save registers

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

;;;;;;; mov	gs,SEL_4GB	; Get AGROUP data selector
;;;;;;; assume	gs:AGROUP	; Tell the assembler about it

;;;;;;; mov	ebx,LaVMTSS	; Get offset in AGROUP of VM TSS
	mov	ebx,PCURTSS	; Get offset in DGROUP of current TSS

	mov	eax,DGROUP:[ebx].TSS_ESP0 ; Get end of stack
	sub	eax,size INTDPF_STR ; Get offset of DPMI error code
	mov	PPL0STK_DERR,eax ; Save for later use

	add	eax,size INTDPF_ERR ; Get offset of DPMI normal stack start
	mov	PPL0STK_DNRM,eax ; Save for later use

	mov	eax,DGROUP:[ebx].TSS_ESP0 ; Get end of stack
	sub	eax,(size INTXX_STR)-INTXX_ERR ; Get offset of error code
	mov	PPL0STK_ERR,eax ; Save for later use

	add	eax,size INTXX_ERR ; Get offset of normal stack start
	mov	PPL0STK_NRM,eax ; Save for later use

;;;;;;; REGREST <gs,ds,ebx,eax> ; Restore
;;;;;;; assume	ds:nothing,gs:nothing ; Tell the assembler about it
	REGREST <ds,ebx,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SET_PPL0STK endp		; End SET_PPL0STK procedure
	NPPROC	RESETVARS -- Reset Local Variables
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Reset local variables such as CR3 and LDTR

|

	REGSAVE <eax,ebx,ecx,ds> ; Save registers

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

;;;;;;; mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
;;;;;;;
;;;;;;; test	DGROUP:[eax].DPTSS_FLAG,mask $DPTSS_INIT ; Izit initialized?
;;;;;;; jz	short RESETVARS_EXIT ; Jump if not
;;;;;;;
; * Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	mov	ebx,cr3 	; Get the current value
	mov	ecx,ebx 	; Copy in case we need to low-order bits
	and	bx,mask $PTE_FRM ; Isolate the frame

	cmp	ebx,DGROUP:[eax].TSS_CR3 ; Izit the same?
	je	short RESETVARS1 ; Jump if so (optimization to avoid flushing TLB)

	mov	bx,DGROUP:[eax].DPTSS_SEL ; Get incoming TSS's selector
	mov	VMMCurrentClient,bx ; Set as current client

	mov	ebx,DGROUP:[eax].TSS_CR3 ; Get our value
	and	cx,not (mask $PTE_FRM) ; Isolate the flags
	or	bx,cx		; Include the flags
	mov	cr3,ebx 	; Set as current value

; Tell GXT about the new CR3

	push	ebx		; Pass physical address
	PUSHD	0		; ...  linear address (TBD)
	call	TellGXT_CR3	; Tell 'em (after the fact)
RESETVARS1:
	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	je	short RESETVARS_EXIT ; Jump if not

; Set the base of the new LDT

	push	DGROUP:[eax].TSS_LDT.EDD ; Pass LDT selector as dword
	push	DGROUP:[eax].DPTSS_LaLDT ; ...	LDT base address
	call	SETBASE 	; Set the base address

	lldt	DGROUP:[eax].TSS_LDT ; Reset the LDT
RESETVARS_EXIT:
	REGREST <ds,ecx,ebx,eax> ; Restore
	assume	ds:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

RESETVARS endp			; End RESETVARS procedure

PROG	ends			; End PROG segment


CODE16	segment use32 byte public 'prog' ; Start CODE16 segment
	assume	cs:PGROUP

	public	@DPMI_IDT_CODE16
@DPMI_IDT_CODE16:		; Mark module start in .MAP file

	extrn	INTxx_INTRETPM:near
;;;;;;; extrn	DPMI_REFINT:near

	FPPROC	INTCOM -- Common Interrupt Routine
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Common interrupt handler for all but those handled by INTXXCOM.

On entry:

INTCOM_INTNO has the INT # times 4 + offset PGROUP:INTPROC00Z

Caller's EIP has been incremented past the instruction.

|

	call	RESETVARS	; Keep variables up-to-date

	pop	[esp].INTCOM_INTNO ; Save INT # times 4 + ...

; See if we're called from a DPMI client (HW-DPMI, SP-DPMI, SW-DPMI)

	REGSAVE <eax,ds>	; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	lea	eax,[esp+4+4]	; Get original ESP

	cmp	eax,PPL0STK_DNRM ; Izit a HW/SW interrupt from a DPMI client?
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it
	je	near ptr INTCOM_DPMI_INT ; Jump if so

; We're called from VM  (HW-VM,  SP-VM,  SW-VM)
;		 or MAX (HW-MAX, SP-MAX, SW-MAX)

; The other possibilities (EX-VM, EX-MAX, EX-DPMI) are handled
; elsewhere (INT08, INT0A, INT0B, INT0C, INT0D, INT0E, INTXXCOM)

; See if there's a DPMI client active
; If so, we need to check for HW and SP interrupts which must
; be reflected to DPMI clients first.

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jne	near ptr INTCOM_DPMI_CHK ; Jump if so (check for HW INTs)

	public	INTCOM_DPMI_CHKRET
INTCOM_DPMI_CHKRET:

; Continue with the next handler in sequence

	jmp	HARDINT 	; Join common code


; We're called from VM  (HW-VM,  SP-VM,  SW-VM)
;		 or MAX (HW-MAX, SP-MAX, SW-MAX)
; and there's a DPMI client active.
; If this is a HW or special (1Ch, 23h, 24h) interrupt,
; reflect it to the DPMI client.
; Note that 23h and 24h have their own handlers, so we skip them here
; as they have already been presented to any active DPMI clients.

INTCOM_DPMI_CHK:
	push	eax		; Save for a moment

	movzx	eax,[esp+4].INTCOM_INTNO ; Get INT # times 4 + ...
	sub	eax,offset PGROUP:INTPROC00Z ; Convert to INT # times 4
	shr	eax,2-0 	; Convert from times 4 to times 1

; Check for interrupts from VM or MAX which we must handle specially.
; These include 1Ch, 23h, and 24h as well as master and slave PICs.
; Note that 23h and 24h have their own handlers, so we skip them here
; as they have already been presented to any active DPMI clients.

	call	IZIT_PPIHOOK	; Is INT EAX hooked by the (active) primary client
				; and isn't INT 23h or 24h?
	jnc	short @F	; Jump if not (note CF=0)

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	bt	DPMI_HWSP.EDD,eax ; Izit HW or SP?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jnc	short @F	; Jump if not (note CF=0)

	call	IZIT_REFLINT	; Izit reflectable?
				; Return with CF=1 iff we can pass to client
@@:
	pop	eax		; Restore
	jnc	short @F	; Jump if not

; Reflect this HW or special interrupt from VM or MAX to the DPMI client
; The stack is mapped by INTCOM_STR if we came from VM
; or NRM_STR if we came from MAX

	push	@PMINTCOM_LPM	; Use LPM stack
	jmp	PMINTCOM	; Jump to common code


@@:

; If this is from MAX, use a separate stack
; as LAST_INTCOM is not necessarily valid

	test	[esp].INTCOM_EFL.EHI.LO,mask $VM ; In VM86 mode?
	jz	near ptr INTCOM_DPMI_INTMAX ; Jump if not (handle as DPMI interrupt)

	jmp	INTCOM_DPMI_CHKRET ; Join common code



;;; DPMI_HARDRET_STR struc
;;;
;;;	     dd      ?		    ; Return ESP
;;;	     dw      ?,?	    ; ...    SS with filler
;;;	     dw      ?,?	    ; ...    ES ...
;;;	     dw      ?,?	    ; ...    DS ...
;;;	     dw      ?,?	    ; ...    DS ...
;;;	     dw      ?,?	    ; ...    GS ...
;;; DPMI_HARDRET_CNT0E dw ?	    ; DPMICNT0E
;;;	     dw      ?		    ; DPMICNT0D
;;;	     dd      ?		    ; LAST_INTFLG
;;;	     dd      ?		    ; LAST_INTCOM
;;;	     df      ?		    ; LPMSTK_FVEC
;;; DPMI_HARDRET_NXT db (size INTDPI_STR) dup (?) ; The rest of the stack
;;;
;;; DPMI_HARDRET_STR ends
;;;
;;; DPMI_HARDRET_REST equ <DPMI_HARDRET_CNT0E> ; Strip stack to this point
;;;				    ; upon return
;;;
;;; DPMI_HARDINT_STR struc
;;;
;;;	     dd      ?		    ; Return EIP
;;;	     dw      ?		    ; ...    CS
;;; DPMI_HARDINT_INTNO dw ?	    ; ...    INT # times 4 + ...
;;; DPMI_HARDINT_EFL   dd ?	    ; ...    EFL
;;; DPMI_HARDINT_NXT db (size DPMI_HARDRET_STR) dup (?) ; The rest of the stack
;;;
;;; DPMI_HARDINT_STR ends
;;;
;;;
;;; ; Return from DPMI HW/SW interrupt
;;;
;;; ; The stack is mapped by DPMI_HARDRET_STR
;;;
;;; ; The flags upon entry to this point are significant and are
;;; ; to be returned to the caller.
;;;
;;;	     public  INTCOM_DPMI_HARDRET
;;; INTCOM_DPMI_HARDRET:
;;;	     pushfd		    ; Get our flags
;;;
;;;	     call    RESETVARS	    ; Keep variables up-to-date
;;;
;;;	     push    ds 	    ; Save for a moment
;;;
;;;	     SETDATA ds 	    ; Get DGROUP data selector
;;;	     assume  ds:DGROUP	    ; Tell the assembler about it
;;;
;;;	     pop     SAVE_DSXX	    ; Restore
;;;
;;;	     mov     SAVE_EAX,eax   ; Save for a moment
;;;
;;; ; Establish addressibility to GDT
;;;
;;;	     sub     esp,size DTR_STR ; Make room on stack
;;;	     SGDTD   [esp].EDF	    ; Save GDTR on stack
;;;	     mov     eax,[esp].DTR_BASE ; ES:EBX ==> GDT
;;;	     add     esp,size DTR_STR ; Strip
;;;
;;; ; Return flags to caller except for VM, RF, IOPL, IF, and TF
;;;
;;; FLMASK   =	     ((mask $VMHI) or (mask $RFHI) or (mask $IOPL) or (mask $IF) or (mask $TF))
;;;
;;;	     pop     eax	    ; Copy to save on stack
;;;	     and     eax,not FLMASK ; VM=RF=IOPL=IF=TF=0
;;;	     and     [esp].DPMI_HARDRET_NXT.INTDPI_EFL,FLMASK ; Isolate
;;;	     or      [esp].DPMI_HARDRET_NXT.INTDPI_EFL,eax ; Save as caller's flags
;;;
;;;	     and     ax,not (mask $NT) ; NT=0 for the following IRETD
;;;
;;;	     push    ax 	    ; Save on stack
;;;	     popf		    ; Put into flags
;;;
;;;	     mov     eax,PCURTSS    ; Get offset in DGROUP of current TSS
;;;	     add     DGROUP:[eax].DPTSS_VMSTKOFF,@HPDAFRM_SIZ ; Strip off a level
;;;
;;;	     mov     eax,SAVE_EAX   ; Restore
;;;
;;;	     add     esp,DPMI_HARDRET_REST ; Strip back the stack including
;;;				    ; GSF, FSF, DSF, ESF, SSF, and ESP
;;;
;;;	     REGREST <DPMICNT0E,DPMICNT0D,LAST_INTFLG,LAST_INTCOM> ; Restore
;;;
;;;	     pop     LPMSTK_FVEC.FOFF ; Restore
;;;	     pop     LPMSTK_FVEC.FSEL.EDD ; ...
;;;
;;;	     push    PCURTSS	    ; Pass offset in DGROUP of current TSS
;;;	     call    DPMIFN_LMSW    ; Put MSW and INT 07h values into effect
;;;
;;;	     mov     ds,SAVE_DSXX   ; Restore
;;;	     assume  ds:nothing     ; Tell the assembler about it
;;;
;;;	     iretd		    ; Return to interrupted code
;;;
;;;
; Hardware/special/software interrupt from a DPMI client or from MAX

	public	INTCOM_DPMI_INT
INTCOM_DPMI_INT:

; The stack is mapped by INTDPI_STR if we came from DPMI
; or NRM_STR if we came from MAX
; Note that NRM_INTNO/INTDPI_INTNO is already filled in with the
; INT # times 4 + offset PGROUP:INTPROC00Z

	PUSHW	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

; Save DPMI selectors in case we need them when the DPMI client
; handles a HW- or SP- interrupt

;;;;;;; mov	LAST_DPMI_DS,ds ; Save for later use
	pop	LAST_DPMI_DS	 ; ...
	mov	LAST_DPMI_ES,es ; ...
	mov	LAST_DPMI_FS,fs ; ...
	mov	LAST_DPMI_GS,gs ; ...

; If this is a hardware interrupt, (and we're lumping special
; interrupts in with this), use the LPM stack
; If this is a software interrupt, use the application stack

	push	eax		; Save for a moment

	movzx	eax,[esp+4].NRM_INTNO ; Get INT # times 4 + ...
	sub	eax,offset PGROUP:INTPROC00Z ; Convert to INT # times 4
	shr	eax,2-0 	; Convert from times 4 to times 1

; Check for interrupts from a DPMI client which we must handle specially.
; These include 1Ch, 23h, and 24h as well as master and slave PICs.
; Note that 23h and 24h have their own handlers, so we skip them here
; as they have already been presented to any active DPMI clients.

; If it's a HW interrupt, send it to the primary client (if hooked)
; on the LPM stack.
; Otherwise, send it to the current client (if hooked) on the application
; stack.

	bt	DPMI_HW.EDD,eax ; Izit HW?
	jc	short INTCOM_DPMI_INT_HW ; Jump if so

	call	IZIT_CPIHOOK	; Is INT EAX hooked by the (active) current client?
	jnc	short INTCOM_DPMI_INTRET ; Jump if not

	mov	eax,@PMINTCOM_NRM ; Use application stack

	jmp	short @F	; Join common code


INTCOM_DPMI_INT_HW:
	call	IZIT_PPIHOOK	; Is INT EAX hooked by the (active) primary client
				; and isn't INT 23h or 24h?
	jnc	short INTCOM_DPMI_INTRET ; Jump if not

	call	IZIT_REFLINT	; Izit reflectable?
	jnc	short INTCOM_DPMI_INTRET ; Jump if not

	mov	eax,@PMINTCOM_LPM ; Use LPM stack
@@:
	xchg	eax,[esp]	; Push onto stack, restore old EAX

	mov	ds,LAST_DPMI_DS ; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	PMINTCOM	; Jump to common code


	assume	ds:DGROUP	; Tell the assembler about it
INTCOM_DPMI_INTRET:
	pop	eax		; Restore

	mov	ds,LAST_DPMI_DS ; Restore
	assume	ds:nothing	; Tell the assembler about it

; If we return, the client decided to let us handle it
; We reflect it to VM86

; Save variables so we can be re-entrant

	public	INTCOM_DPMI_INTMAX
INTCOM_DPMI_INTMAX:

; If this interrupt occurred in VM, let HARDINT handle it

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit from VM?
	jnz	near ptr HARDINT ; Jump if so

; If this is an INT 01h/03h, handle it specially

	push	eax		; Save for a moment

	movzx	eax,[esp+4].NRM_INTNO ; Get INT # times 4 + ...
	sub	eax,offset PGROUP:INTPROC00Z ; Convert to INT # times 4
	shr	eax,2-0 	; Convert from times 4 to times 1

	cmp	eax,01h 	; Izit INT 01h?
	je	short @F	; Jump if so (note ZF=1)

	cmp	eax,03h 	; Izit INT 03h?
@@:
	pop	eax		; Restore
;;;;;;; jne	near ptr DPMI_REFINT ; Reflect it to VM
	jne	near ptr INTxx_INTRETPM ; Reflect it to VM

; The DPMI client has encountered an INT 01h/03h and
; it didn't handle it.  If SWAT is installed, pass it on to
; the next handler in sequence.  Otherwise, just IRETD on
; the assumption that (at least the INT 03h) was suprious.

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	LCL_FLAG,@LCL_PSWAT ; Is SWAT installed?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jnz	near ptr HARDINT ; Jump if so

	iretd			; Return to the caller (PM only)
				; (and hope for the best)

;;;;	     assume  ds:DGROUP	     ; Tell the assembler about it
;;;; INTCOM_DPMI_INTRET_VMFULL:
;;;;	     add     esp,size INTCOM_STR ; Strip
;;;;
;;;;	     REGREST <DPMICNT0E,DPMICNT0D,LAST_INTFLG,LAST_INTCOM> ; Restore
;;;;
;;;;	     pop     LPMSTK_FVEC.FOFF ; Restore
;;;;	     pop     LPMSTK_FVEC.FSEL.EDD ; ...
;;;;
;;;;	     mov     eax,SAVE_EAX    ; Restore
;;;;	     mov     ebx,SAVE_EBX    ; ...
;;;;	     mov     ds,SAVE_DSXX    ; Restore
;;;;	     assume  ds:nothing      ; Tell the assembler about it
;;;;
;;;;	     PUSHD   0		     ; Put pseudo-error code onto stack
;;;;
;;;;	     jmp     FLTPROC_VMFULL  ; Join common error code
;;;;


; A fault from a DPMI client has occurred
; The stack is mapped by INTDPF_STR if we came from DPMI
; or FLT_STR if we came from MAX.
; Note that INTDPF_INTNO is already filled in with the
; INT # times 4 + offset PGROUP:INTPROC00Z

	public	INTCOM_DPMI_FAULT
INTCOM_DPMI_FAULT:
	PUSHW	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

; Save DPMI selectors in case we need them when the DPMI client
; handles a HW- or SP- interrupt

;;;;;;; mov	LAST_DPMI_DS,ds ; Save for later use
	pop	LAST_DPMI_DS	 ; ...
	mov	LAST_DPMI_ES,es ; ...
	mov	LAST_DPMI_FS,fs ; ...
	mov	LAST_DPMI_GS,gs ; ...

	REGSAVE <eax,LAST_DPMI_DS.EDD> ; Save for a moment

	movzx	eax,[esp+4+4].INTDPF_INTNO ; Get INT # times 4 + ...
	sub	eax,offset PGROUP:INTPROC00Z ; Convert to INT # times 4
	shr	eax,2-0 	; Convert from times 4 to times 1

	bt	DPMI_CPFHOOK.EDD,eax ; Izit hooked by current client?
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it
	jnc	short INTCOM_DPMI_FAULT1 ; Jump if not

	push	@PMINTCOM_LPM	; Use LPM stack
	push	eax		; Pass placeholder for PCURTSS

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	xchg	eax,[esp+4]	; Swap with original value

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	PMFLTCOM	; Jump to common code


INTCOM_DPMI_FAULT1:

; The fault is not hooked by the current client -- if it's hooked as
; an interrupt, send it down the PMINTCOM chain, otherwise, terminate
; the DPMI client.

	REGSAVE <eax,ds>	; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	movzx	eax,[esp+4+4].INTDPF_INTNO ; Get INT # times 4 + ...
	sub	eax,offset PGROUP:INTPROC00Z ; Convert to INT # times 4
	shr	eax,2-0 	; Convert from times 4 to times 1

	bt	DPMI_CPIHOOK.EDD,eax ; Izit hooked by current DPMI client?
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it
	jnc	short @F	; Jump if not

	add	esp,size INTDPF_ERR ; Strip off the error code

	push	@PMINTCOM_NRM	; Use application stack
	jmp	PMINTCOM	; Jump to common code


@@:
	jmp	FLTPROC_APPL	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INTCOM	endp			; End INTCOM procedure
	NPPROC	IZIT_REFLINT -- Is This Interrupt Reflectable
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Is this interrupt reflectable??

Because some DPMI clients don't lock their HW interrupt handlers, we
have to take special precautions:

If this is a special program (also called a bozo program), and
  Swapping is present, and
  Either we're already processing a page fault, or
	 we're inside an INT 13h call, or
	 we're inside DOS
then don't pass the INT on to the client.

On entry:

AX	=	interrupt #

On exit:

CF	=	1 if it's reflectable
	=	0 if not

|

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	I31_FLAG,mask $I31_XMEI ; Izit one to worry about?
	jz	short IZIT_REFLINT1 ; Jump if not

	test	VMM_FLAG,@VMM_BSPRES ; Is swapping present?
	jz	short IZIT_REFLINT1 ; Jump if not

	cmp	PageFaultActive,0 ; Are we processing a page fault?
	ja	short IZIT_REFLINT2 ; Jump if so (note CF=0)

	REGSAVE <eax,ds>	; Save for a moment
;;;*FIXME*
;;;	     mov     ds,SEL_DSHI    ; Get high DOS memory selector
;;;	     assume  ds:DGROUP	    ; Tell the assembler about it
;;;
;;;	     cmp     I13CNT,0	    ; Izit within an INT 13h call?
;;;	     ja      short @F	    ; Jump if so (note CF=0)
;;;
;;;	     assume  ds:nothing     ; Tell the assembler about it

	mov	eax,LaINDOS	; AGROUP:EAX ==> InDOS flag

	mov	ds,SEL_4GB	; Get AGROUP data selector
	assume	ds:AGROUP	; Tell the assembler about it

	cmp	AGROUP:[eax].LO,0 ; Are we inside DOS?
@@:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it
	ja	short IZIT_REFLINT2 ; Jump if so (note CF=0)
IZIT_REFLINT1:
	stc			; Mark as reflectable
IZIT_REFLINT2:
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

IZIT_REFLINT endp		; End IZIT_REFLINT procedure
	NPPROC	IZIT_CPIHOOK -- Is An Interrupt Hooked By Active Current DPMI Client
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Is a SW interrupt hooked by an active current DPMI client?

On entry:

EAX	=	INT #

On exit:

CF	=	0 if not hooked
	=	1 if so

|

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	bt	DPMI_CPIHOOK.EDD,eax ; Izit hooked by current DPMI client?
	jnc	short IZIT_CPIHOOK_EXIT ; Jump if not (note CF=0)

	push	eax		; Save for a moment

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	bt	DGROUP:[eax].DPTSS_FLAG,$DPTSS_INIT ; Izit initialized?
	pop	eax		; Restore
				; Return with CF=1 if initialized, 0 if not
IZIT_CPIHOOK_EXIT:
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

IZIT_CPIHOOK endp		; End IZIT_CPIHOOK procedure
	NPPROC	IZIT_PPIHOOK -- Is An Interrupt Hooked By Active Primary DPMI Client
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Is an interrupt hooked by an active primary DPMI client?

On entry:

EAX	=	INT #

On exit:

CF	=	0 if not hooked
	=	1 if so

|

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	bt	DPMI_PPIHOOK.EDD,eax ; Izit hooked by primary DPMI client?
	jnc	short IZIT_PPIHOOK_EXIT ; Jump if not (note CF=0)

	cmp	al,23h		; Izit INT 23h?
	je	short IZIT_PPIHOOK_EXIT ; Jump if so (note CF=0)

	cmp	al,24h		; Izit INT 24h?
	je	short IZIT_PPIHOOK_EXIT ; Jump if so (note CF=0)

	push	eax		; Save for a moment

	mov	eax,PPRMTSS	; Get offset in DGROUP of primary TSS

	bt	DGROUP:[eax].DPTSS_FLAG,$DPTSS_INIT ; Izit initialized?
	pop	eax		; Restore
				; Return with CF=1 if initialized, 0 if not
IZIT_PPIHOOK_EXIT:
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

IZIT_PPIHOOK endp		; End IZIT_PPIHOOK procedure
;;;;	     NPPROC  IRETD_COM -- Common IRETD Routine
;;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;; COMMENT|
;;;;
;;;; Common IRETD routine
;;;;
;;;; Because NMI can occur while we're executing, the INT02 handler
;;;; below sets a flag and returns.  This routine tests for that
;;;; condition and if set, clears the bit, and continues processing
;;;; as if an INT 02h had just occurred.
;;;;
;;;; |
;;;;
;;;;	     push    ds 	     ; Save for a moment
;;;;
;;;;	     SETDATA ds 	     ; Get DGROUP data selector
;;;;	     assume  ds:DGROUP	     ; Tell the assembler about it
;;;;
;;;;	     test    GLB_FLAG,@GLB_NMI or @GLB_TLB ; TLB flush needed or did an NMI occur?
;;;;	     pop     ds 	     ; Restore
;;;;	     assume  ds:nothing      ; Tell the assembler about it
;;;;	     jnz     short IRETD_COM1 ; Yes, handle as if an INT 02h had occurred
;;;;
;;;;	     test    [esp].IRETD_EFL.HI,mask $VM ; Izit to VM?
;;;;	     jnz     short @F	     ; Jump if so
;;;;
;;;;	     iretd		     ; No, just return as usual (PM only)
;;;;
;;;;
;;;; @@:
;;;;	     jmp     ERM_FVEC	     ; Return to RM/VCPI
;;;;
;;;;
;;;; IRETD_COM1:
;;;;	     push    ds 	     ; Save for a moment
;;;;
;;;;	     SETDATA ds 	     ; Get DGROUP data selector
;;;;	     assume  ds:DGROUP	     ; Tell the assembler about it
;;;;
;;;;	     btr     GLB_FLAG,$GLB_NMI ; Did an NMI occur?
;;;;	     pop     ds 	     ; Restore
;;;;	     assume  ds:nothing      ; Tell the assembler about it
;;;;	     jnc     short @F	     ; Jump if not
;;;;
;;;;	     cli		     ; Ensure disabled for INT 02h handler
;;;;
;;;;	     jmp     short INTPROC02 ; Handle as if an INT 02h had just occurred
;;;;
;;;;
;;;; @@:
;;;;
;;;;	     test    [esp].IRETD_EFL.EHI,mask $VM ; Izit VM?
;;;;	     jnz     short IRETD_COM_ERM1 ; Jump if so
;;;;
;;;; ; Should we single-step the next instruction in the caller?
;;;;
;;;;	     push    ds 	     ; Save for a moment
;;;;
;;;;	     SETDATA ds 	     ; Get DGROUP data selector
;;;;	     assume  ds:DGROUP	     ; Tell the assembler about it
;;;;
;;;;	     btr     GLB_FLAG,$GLB_I01 ; Should we single-step next instr in VM?
;;;;	     pop     ds 	     ; Restore
;;;;	     assume  ds:nothing      ; Tell the assembler about it
;;;;	     jnc     short @F	     ; Jump if not
;;;;
;;;;	     push    mask $TF	     ; Get TF
;;;;	     popfd		     ; TF=1
;;;;
;;;; ; Note we *MUST* not insert any instructions between the
;;;; ; last POPF and the following IRETD or they might get traced
;;;;
;;;; @@:
;;;;	     iretd		     ; Return to caller (??? only)
;;;;
;;;;
;;;; IRETD_COM_ERM1:
;;;;	     jmp     ERM_FVEC	     ; Return to RM/VCPI
;;;;
;;;;
;;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;;
;;;; IRETD_COM endp		     ; End IRETD_COM procedure
	FPPROC	INTPROC -- Interrupt Procedures
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT_MAC macro	N
	local	LAB

	.xcref	INTPROC&N
	public	INTPROC&N
INTPROC&N:
;;;;;;; call	near ptr INTCOM ; Call common routine, w/return addr on stack
	dw	@OPCOD_CALLND
	dw	INTCOM-LAB	; Call INTCOM
LAB:

	endm			; INT_MAC

	public	INTPROC00,INTPROC00Z
INTPROC00 label near
;;;;;;; call	near ptr INTCOM ; Call common routine, w/return addr on stack
	dw	@OPCOD_CALLND
	dw	INTCOM-INTPROC00Z ; Call INTCOM
INTPROC00Z label near		; This address is pushed by the CALL

CNT	=	1		; Start with next interrupt

.xlist
	rept	255		; Define remaining interrupts

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	INT_MAC %N
CNT	=	CNT+1

	endm			; REPT 100h
.list
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INTPROC endp			; End INTPROC procedure
	FPPROC	INTXXCOM -- Common Routine For INTXX
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Common routine for INT0C, INT0D, and INT0E.

On entry:

PUSHAD has been done.
ESI	=	interrupt # times 4
EBX	=	offset of low memory message in DGROUP
SS:EBP	==>	INTXX_STR

|

	cld			; String ops forwardly
	mov	esp,ebp 	; Cut back the stack

	mov	[ebp].INTXX_INTNO,si ; Save interrupt # times 4 for debugging
	add	[ebp].INTXX_INTNO.EDD,offset PGROUP:INTPROC00Z ; Convert to other origin

; Copy the message at DGROUP:EBX to DPMIMSG_LOW

	REGSAVE <ds,es> 	; Save for a moment

	SETDATA es		; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	lea	edi,DPMIMSG_LOW ; ES:EDI ==> message destin

	mov	ds,SEL_DATA	; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	push	esi		; Save interrupt # times 4

	mov	esi,ebx 	; DGROUP:ESI ==> message source
	mov	DPMIMSG,di	; Save message offset

	mov	ecx,DGROUP:[esi].LENTXT_LEN ; Get message length
	add	ecx,size LENTXT_LEN ; Plus the length word

	cld			; String ops fowards
S32 rep movs	<DPMIMSG_LOW.LO[edi],DGROUP:[esi].LO> ; Copy to DGROUP

	pop	esi		; Restore

	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

; This code catches faults not otherwise handled by specific code
; which is present for VM Faults 00h-07h.  The VM Faults which
; come here include 08h-0Eh, and 12h.

	mov	eax,esi 	; Copy INT # times 4
	shr	eax,2		; Divide by four to get INT #

	test	[ebp].INTXX_EFL.EHI,mask $VM ; Izit from VM?
	jz	short INTXXCOM_PM ; Jump if not

; If there's a DPMI client active and the primary client has hooked
; this exception, give it a crack at it.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_PVFHOOK must be clear.

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	bt	DPMI_PVFHOOK.EDD,eax ; Izit hooked by primary client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jnc	short INTXXCOM_XDPMI0 ; Jump if not

	popad			; Restore

; The MAX stack consists of (from bottom up) an error code
; followed by INTCOM_STR.

	jmp	VMFLTCOM	; Jump to common code


INTXXCOM_PM:

; If it's an INT 03h, the EIP has already been decremented
; to point to the INT 03h instruction.	Here, we need to
; increment it back 'cause the code at FLTPROC_ABORT
; will decrement it again.  The right hand giveth, ...

	cmp	esi,4*03h	; Izit INT 03h?
	jne	short @F	; Jump if not

	inc	[ebp].INTXX_EIP ; Point past the INT 03h again
@@:
	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	je	short INTXXCOM_XDPMI0 ; Jump if no DPMI clients active

	popad			; Restore all EGP registers
				; N.B.:  Do not follow with [E?X+E?X*?]
	jmp	FLTPROC_ABORT	; Join common DPMI abort code


COMMENT|

Handle faults from VM or PM when no DPMI client is active.

If the fault doesn't have an error code (we pushed a pseudo-error code
onto the stack), strip it now.

On entry:

EAX	=	interrupt #
ESI	=	interrupt # times 4
SS:EBP	==>	INTXX_STR

|

INTXXCOM_XDPMI0:
	bt	FLTERR,eax	; Izit a fault with error code?
	popad			; Restore
	jc	short INTXXCOM_XDPMI1 ; Jump if so

	add	esp,type INTXX_ERR ; Strip off the pseudo-error code

	pushad			; Save all EGP registers

	mov	ebp,esp 	; SS:EBP ==> PUSHAD_STR and INTDPI_STR

	movzx	esi,[ebp+(type PUSHAD_STR)].NRM_INTNO ; Get the INT # * 4 + ...
	sub	esi,offset PGROUP:INTPROC00Z ; Less base offset
	mov	ebx,1		; Mark as a fault

	jmp	short INTXXCOM_XDPMI ; Join common code


INTXXCOM_XDPMI1:
	pushad			; Save all EGP registers

	mov	ebp,esp 	; SS:EBP ==> PUSHAD_STR and INTDPI_STR

	movzx	esi,[ebp+(type PUSHAD_STR)].FLT_INTNO ; Get the INT # * 4 + ...
	sub	esi,offset PGROUP:INTPROC00Z ; Less base offset
	mov	ebx,1		; Mark as a fault

	jmp	short INTXXCOM_XDPMI ; Join common code


COMMENT|

Handle hardware interrupts while executing in protected mode.

The stack upon entry contains

EIP
CS
INT # * 4+ offset PGROUP:INTPROC00Z
EFL

* Pass control to the original handler

On entry:

IF	=	0 (interrupts disabled)

|

	public	HARDINT
HARDINT:
	pushad			; Save all EGP registers

	mov	ebp,esp 	; SS:EBP ==> PUSHAD_STR and INTDPI_STR

	movzx	esi,[ebp+(type PUSHAD_STR)].NRM_INTNO ; Get the
	sub	esi,offset PGROUP:INTPROC00Z ; Less base offset
	xor	ebx,ebx 	; Mark as not a fault

COMMENT|

A fault or HW INT from VM or PM outside a DPMI client has occurred.
Pass it on to the original fault handler

On entry:

ESI	=	INT # * 4
EBX	=	0 iff not a fault

|

INTXXCOM_XDPMI:
	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

; If it's a fault and there's a DPMI client active, terminate it

	cmp	ebx,1		; Izit a fault?
	jne	short @F	; Jump if not

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	je	short @F	; Jump if not

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	popad			; Restore all EGP registers
				; N.B.:  Do not follow with [E?X+E?X*?]
	jmp	FLTPROC_ABORT	; Join common DPMI abort code


	assume	ds:DGROUP	; Tell the assembler about it
@@:
	mov	eax,esi 	; Copy INT # times 4
	shr	eax,1		; Divide by two to get INT # times 2
	add	eax,esi 	; Add to get INT # times 6 (for OLDINT_FVEC)
	mov	SAVE_EAX,eax	; Save for later use

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

; If it's in PM and not a fault, pass it through via INTxx_INTRETPM

	test	[ebp+(type PUSHAD_STR)].INTDPF_EFL.EHI,mask $VM ; Izit from VM?
	jnz	short @F	; Jump if so (note ZF=0)

	cmp	ebx,0		; Izit a fault?
@@:
	popad			; Restore
	je	near ptr INTxx_INTRETPM ; Jump if not

	PUSHW	ds		; Save for a moment

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	xchg	eax,SAVE_EAX	; Get INT # times 6, save old value

	cmp	OLDINT_FVEC.FSEL[eax],0 ; Izit valid?
	jne	short @F	; Jump if so

	SWATMAC ERR		; *FIXME*
@@:
	push	OLDINT_FVEC.FSEL[eax] ; Pass selector
	push	OLDINT_FVEC.FOFF[eax] ; ...  offset

LINTXX_STR struc

	dd	?		; Return offset
	dw	?		; ...	 selector
LINTXX_DS dw	?		; Original DS

LINTXX_STR ends

	mov	eax,SAVE_EAX	; Restore

	mov	ds,[esp].LINTXX_DS ; Restore
	assume	ds:nothing	; Tell the assembler about it

	retf			; Return to caller


;;;	     assume  ds:DGROUP	    ; Tell the assembler about it
;;; INTXXCOM_GPF:
;;;	     SWATMAC ERR
;;;
;;;	     pop     ax 	    ; Get the caller's DS
;;;
;;;	     sub     esp,type INTXX_ERR ; Make room for error code
;;;
;;;	     push    ax 	    ; Save in proper place
;;;
;;;	     push    OLDINT_FVEC.FSEL[0Dh*(type OLDINT_FVEC)] ; Pass selector
;;;	     push    OLDINT_FVEC.FOFF[0Dh*(type OLDINT_FVEC)] ; ...  offset
;;;
;;; LINTXX2_STR struc
;;;
;;;	     dd      ?		    ; Return offset
;;;	     dw      ?		    ; ...    selector
;;; LINTXX2_DS dw    ?		    ; Original DS
;;; LINTXX2_ERR dd   ?		    ; Error code
;;; LINTXX2_NXT db   (type INTDPI_STR) dup (?) ; The rest of the stack
;;;
;;; LINTXX2_STR ends
;;;
;;;	     movzx   eax,[esp].LINTXX2_NXT.INTCOM_INTNO ; Get INT # * 4 + offset ...
;;;	     sub     eax,offset PGROUP:INTPROC00Z ; Less offset ...
;;;	     shl     eax,3-2	    ; Convert from *4 to *8 for GP Fault error code
;;;	     mov     [esp].LINTXX2_ERR,eax ; Save for GP Fault handler
;;;
;;;	     mov     eax,SAVE_EAX   ; Restore
;;;
;;;	     mov     ds,[esp].LINTXX2_DS ; Restore
;;;	     assume  ds:nothing     ; Tell the assembler about it
;;;
;;;	     retf		    ; Return to caller
;;;
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INTXXCOM endp			; End INTXXCOM procedure
	NPPROC	KEYWAIT -- Wait For Keyboard Acknowledgement
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Purge the keyboard buffer and wait for a key press -- discard the key

On exit:

AX	=	last key pressed

|

KEYWAIT_NEXT:
	KEYCALL @GETKST 	; Get buffer state
	jz	short KEYWAIT_PAUSE ; Nothing available

	KEYCALL @GETKEY 	; Get the key

	jmp	KEYWAIT_NEXT	; Go around again

KEYWAIT_PAUSE:
	KEYCALL @GETKEY 	; Get the key

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

KEYWAIT endp			; End KEYWAIT procedure
	FPPROC	INT01 -- Debug Exception
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Debug exception interrupt (01h) with no error code on stack.

If we're called from VM,
   If there's a DPMI client active and the primary client has hooked
     this exception, give it a crack at it.
   Otherwise, continue with INTPROC01.
If we're called from PM and there's a DPMI client active,
   give it a crack at this exception.
If we're called from PM and SWAT is active, tell 'em about it.
Otherwise, signal an exception and terminate the session.

|

	call	RESETVARS	; Keep variables up-to-date

; The stack is mapped by NRM_STR

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit VM86 mode?
	jz	short INT01_PM	; Jump if not

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_PVFHOOK[01h/8],1 shl (01h mod 8) ; Izit hooked by primary client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	near ptr INT01_ORIG ; Jump if not

	push	eax		; Make room for pseudo-error code
	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack
	call	DPMI_INT01	; Check on DPMI debug watchpoints
	pop	ebp		; Restore
	xchg	eax,[esp]	; Save on stack, restore original value

; The MAX stack is consists of (from bottom up) an error code
; followed by INTCOM_STR.

	mov	[esp].INTDPF_INTNO,4*01h ; Mark as INT 01h
	add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	VMFLTCOM	; Jump to common code

	assume	ds:nothing	; Tell the assembler about it

INT01_PM:

; The stack is mapped by INTDPI_STR if we came from DPMI
; or NRM_STR if we came from MAX

	test	[esp].NRM_CS,mask $PL ; Izit PL0?
	jz	short INT01_FLTRETPM ; Jump if so (ignore it)

; If there's a DPMI client active, give it a crack at this exception

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	je	short INT01_FLTRETPM ; Jump if no DPMI clients active

	push	eax		; Make room for pseudo-error code
	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack
	call	DPMI_INT01	; Check on DPMI debug watchpoints
	pop	ebp		; Restore
	xchg	eax,[esp]	; Save on stack, restore original value

; The stack is mapped by INTDPF_STR if we came from DPMI
; or FLT_STR if we came from MAX

	mov	[esp].INTDPF_INTNO,4*01h ; Mark as INT 01h
	add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTCOM_DPMI_FAULT ; Join common code


; The stack is mapped by INTDPI_STR

INT01_FLTRETPM:
	mov	[esp].INTDPI_INTNO,4*01h ; Mark as INT 01h
	add	[esp].INTDPI_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

; If SWAT is active, pass this interrupt on

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	LCL_FLAG,@LCL_PSWAT ; Is SWAT installed?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jnz	near ptr HARDINT ; Jump if so

; Ensure not BD bit in DR6 causing us to signal exception

	push	eax		; Save for a moment

	mov	eax,dr6 	; Get debug status register

	test	eax,mask $BD	; Check for cause of GD bit in DR7
	pop	eax		; Restore
	jnz	short INT01_ORIG ; Jump if that's the case
				; and hope that the next handler clears it

	PUSHD	0		; Put pseudo-error code onto stack

	pushad			; Save all EGP registers

	mov	ebp,esp 	; SS:EBP ==> INTXX_STR

	mov	esi,4*01h	; Interrupt # times 4
	lea	ebx,DGROUP:MSG_L01 ; Offset of message to display to user

	jmp	near ptr INTXXCOM ; Join common code


INT01_ORIG:
	EXITDPL 01		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT01	endp			; End INT01 procedure
	FPPROC	INT02 -- NMI Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Non-maskable interrupt (02h) with no error code on stack.

If we're called from VM,
   If there's a DPMI client active and the primary client has hooked
     this exception, give it a crack at it.
   Otherwise, continue with INTPROC02.
If we're called from PM and there's a DPMI client active,
   give it a crack at this exception.
If we're called from PM and IF=1, continue with INTPROC02.
Otherwise, then mark it for NMI when we return to VM.

|

	call	RESETVARS	; Keep variables up-to-date

; The stack is mapped by NRM_STR

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit VM86 mode?
	jz	short INT02_PM	; Jump if not

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_PVFHOOK[02h/8],1 shl (02h mod 8) ; Izit hooked by primary client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT02_ORIG ; Jump if not

	PUSHD	0		; Pass pseudo-error code

; The MAX stack is consists of (from bottom up) an error code
; followed by INTCOM_STR.

	mov	[esp].INTDPF_INTNO,4*02h ; Mark as INT 02h
	add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	VMFLTCOM	; Jump to common code


INT02_PM:

; The stack is mapped by INTDPI_STR if we came from DPMI
; or NRM_STR if we came from MAX

	test	[esp].NRM_CS,mask $PL ; Izit PL0?
	jz	short INT02_FLTRETPM ; Jump if so (ignore it)

; If there's a DPMI client active, give it a crack at this exception

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	je	short INT02_FLTRETPM ; Jump if no DPMI clients active

	PUSHD	0		; Put pseudo-error code onto stack

; The stack is mapped by INTDPF_STR if we came from DPMI
; or FLT_STR if we came from MAX

	mov	[esp].INTDPF_INTNO,4*02h ; Mark as INT 02h
	add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTCOM_DPMI_FAULT ; Join common code


INT02_FLTRETPM:
	test	[esp].NRM_EFL.EHI,mask $IF ; Izit enabled?
	jnz	short INT02_ORIG ; Yes, continue with VM 8086 mode handler

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	or	GLB_FLAG,@GLB_NMI ; Mark as NMI occurred

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	iretd			; Just keep on chugging (PM only)
				; Note that this IRET allows another NMI

INT02_ORIG:
	EXITDPL 02		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT02	endp			; End INT02 procedure
	FPPROC	INT03 -- Breakpoint Exception
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Breakpoint exception interrupt (03h) with no error code on stack.

If we're called from VM,
   If there's a DPMI client active and the primary client has hooked
     this exception, give it a crack at it.
   Otherwise, continue with INTPROC03.
If we're called from PM and there's a DPMI client active,
   give it a crack at this exception.
If we're called from PM and SWAT is active, tell 'em about it.
Otherwise, signal an exception and terminate the session.

|

	call	RESETVARS	; Keep variables up-to-date

; The stack is mapped by NRM_STR

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit VM86 mode?
	jz	short INT03_PM	; Jump if not

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_PVFHOOK[03h/8],1 shl (03h mod 8) ; Izit hooked by primary client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	near ptr INT03_ORIG ; Jump if not

	PUSHD	0		; Pass pseudo-error code

; The MAX stack is consists of (from bottom up) an error code
; followed by INTCOM_STR.

	mov	[esp].INTDPF_INTNO,4*03h ; Mark as INT 03h
	add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	VMFLTCOM	; Jump to common code

INT03_PM:

; The stack is mapped by INTDPI_STR if we came from DPMI
; or NRM_STR if we came from MAX

	test	[esp].NRM_CS,mask $PL ; Izit PL0?
	jz	short INT03_FLTRETPM ; Jump if so (ignore it)

; If there's a DPMI client active, give it a crack at this exception

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	je	short INT03_FLTRETPM ; Jump if no DPMI clients active

	PUSHD	0		; Put pseudo-error code onto stack

; The stack is mapped by INTDPF_STR if we came from DPMI
; or FLT_STR if we came from MAX

	mov	[esp].INTDPF_INTNO,4*03h ; Mark as INT 03h
	add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTCOM_DPMI_FAULT ; Join common code


; The stack is mapped by INTDPI_STR

INT03_FLTRETPM:
	mov	[esp].INTDPI_INTNO,4*03h ; Mark as INT 03h
	add	[esp].INTDPI_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

; If SWAT is active, pass this interrupt on

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	LCL_FLAG,@LCL_PSWAT ; Is SWAT installed?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jnz	near ptr HARDINT ; Jump if so

	dec	[esp].NRM_EIP	; Backup to the breakpoint instruction

	PUSHD	0		; Put pseudo-error code onto stack

	pushad			; Save all EGP registers

	mov	ebp,esp 	; SS:EBP ==> INTXX_STR

	mov	esi,4*03h	; Interrupt # times 4
	lea	ebx,DGROUP:MSG_L03 ; Offset of message to display to user

	jmp	near ptr INTXXCOM ; Join common code

INT03_ORIG:
	EXITDPL 03		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT03	endp			; End INT03 procedure
	FPPROC	INT06 -- Invalid Opcode Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

If we're called from VM,
   If there's a DPMI client active and the primary client has hooked
     this exception, give it a crack at it.
   Otherwise, attempt to fix the problem
   If we fail, continue with INTPROC06.
If we're called from PM and there's a DPMI client active,
   give it a crack at this exception.
Otherwise, signal an exception and terminate the session.

|

INT06STK_STR struc

INT06STK_DS  dw ?		; Caller's DS
INT06STK_EBX dd ?		; ...	   EBX
INT06STK_EAX dd ?		;	   EAX
INT06STK_EIP dd ?		;	   EIP
INT06STK_CS  dw ?,?		;	   CS with fill
INT06STK_EFL dd ?		;	   EFLAGS

INT06STK_STR ends


; The stack is mapped by INTDPI_STR if we came from DPMI,
; INTCOM_STR if we came from VM, or NRM_STR if we came from MAX

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit VM86 mode?
	jz	short INT06_PM	; Jump if not

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_PVFHOOK[06h/8],1 shl (06h mod 8) ; Izit hooked by primary client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT06_FLTRETVM ; Jump if not

	PUSHD	0		; Pass pseudo-error code

; The MAX stack is consists of (from bottom up) an error code
; followed by INTCOM_STR.

	mov	[esp].INTDPF_INTNO,4*06h ; Mark as INT 06h
	add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	VMFLTCOM	; Jump to common code


INT06_PM:
	test	[esp].NRM_CS,mask $PL ; Izit PL0?
	jz	short INT06_FLTRETPM ; Jump if so (ignore it)

; If there's a DPMI client active, give it a crack at this exception

INT06_FLTRETVM:
	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	je	short INT06_FLTRETPM ; Jump if no DPMI clients active

	PUSHD	0		; Put pseudo-error code onto stack

; The stack is mapped by INTDPF_STR if we came from DPMI,
; or FLT_STR if we came from MAX.

	mov	[esp].INTDPF_INTNO,4*06h ; Mark as INT 06h
	add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTCOM_DPMI_FAULT ; Join common code


INT06_FLTRETPM:
	EXITDPL 06		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT06	endp			; End INT06 procedure
	FPPROC	INT07 -- Coprocessor Not Available
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Coprocessor not available

If we're called from VM,
   If there's a DPMI client active and the primary client has hooked
     this exception, give it a crack at it.
   Otherwise, fix it and continue with INTPROC07.
If we're called from PM and there's a DPMI client active,
   give it a crack at this exception.
Otherwise, fix it (clear the TS bit in CR0) and
   continue with INTPROC07.

|

; The stack is mapped by NRM_STR

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit VM86 mode?
	jz	short INT07_PM	; Jump if not

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_PVFHOOK[07h/8],1 shl (07h mod 8) ; Izit hooked by primary client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	near ptr INT07_FLTRETVM ; Jump if not

	PUSHD	0		; Pass pseudo-error code

; The MAX stack is consists of (from bottom up) an error code
; followed by INTCOM_STR.

	mov	[esp].INTDPF_INTNO,4*07h ; Mark as INT 07h
	add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	VMFLTCOM	; Jump to common code


INT07_PM:
	test	[esp].NRM_CS,mask $PL ; Izit PL0?
	jz	near ptr INT07_FLTRETPM ; Jump if so (ignore it)

; If there's a DPMI client active, give it a crack at this exception

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	je	near ptr INT07_FLTRETPM ; Jump if no DPMI clients active

COMMENT|

Because of a bug in Rational Systems, Inc. DOS 16/M-based products,
used in conjunction with Watcom compiler, Watcom installs a fault
handler and RSI installs an interrupt handler for this event.  The
fault handler does not expect to be called and if it is called, it
terminates the program with an "Unexpected interrupt" message.  By the
way, Watcom uses VxD under Windows to overcome this bug.  To determine
what to do, we use the following heuristic (worked out in conjunction
with Sean True at RSI):

If it's an RSI-based product and a 32-bit DPMI client
  If INT 07h is hooked as a fault
    If the INT 07h fault handler has a 32-bit CS
      Signal as a fault.
    Else
      Signal as an interrupt.
  Else
    Signal as a fault (it'll be reflected as an interrupt later).
Else
  Signal as a fault.

|

	REGSAVE <eax,esi,ds>	; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	I31_FLAG,mask $I31_RSI ; Izit an RSI-based product?
	jz	short INT07_PM_XRSI ; Jump if not

	cmp	DPMITYPE,@DPMITYPE32 ; Izit a 32-bit DPMI client?
	jne	short INT07_PM_XRSI ; Jump if not

	test	DPMI_CPFHOOK[07h/8],1 shl (07h mod 8) ; Izit hooked by current client?
	jz	short INT07_PM_XRSI ; Jump if not

	lar	eax,PMFLT_FVECS[07h*(type PMFLT_FVECS)].FSEL.EDD ; Get A/R word

	test	eax,(mask $DTE_B) shl 16 ; Izit a 32-bit selector?
	jz	short INT07_PM_INT ; Jump if not (signal as an interrupt) (note CF=0)
INT07_PM_XRSI:

COMMENT|

Because of code in the Phar Lap DPMI DOS extender to overcome a bug in
Windows, they put INT 07h at the start of all their fault handlers.
This means that we might be here because of an INT 07h (CD 07) rather
than a Co-processor Not Available condition.  So distinguish these
cases, I propose that we check the code around the caller's CS:EIP.
If it is preceded by CD 07 and the code at CS:IP is not a floating
point instruction (opcode D8-DF), then we convert the INT 07h into a
software interrupt.

|

INT07_RSI_STR struc

	dd	?		; Caller's EBP
	dw	?,?		; ...	   DS w/filler
	dd	?		; ...	   ESI
	dd	?		; ...	   EAX

INT07_RSI_STR ends

	push	ebp		; Prepare to address the stack
	lea	ebp,[esp+(type INT07_RSI_STR)] ; SS:EBP ==> INTDPI_STR

	lds	esi,[ebp].INTDPI_EIP.EDF ; Get caller's CS:EIP
	assume	ds:nothing	; Tell the assembler about it

	cmp	esi,2		; Izit too small to be preceded by CD 07?
	jb	short INT07_PL_EXIT ; Jump if so (note CF=1 -- continue with fault)

	cmp	ds:[esi-2].ELO,07CDh ; Izit INT 07h?
	stc			; Assume not
	jne	short INT07_PL_EXIT ; Jump if not (note CF=1 -- continue with fault)

; Check for floating point opcode at CS|IP
; If found, continue with the INT 07h fault handler

	cld			; String ops forwardly
INT07_PL_NEXT:
	lods	ds:[esi].LO	; Get next instruction byte

	cmp	al,@OPCOD_CS	; Izit segment override?
	je	short INT07_PL_NEXT ; Jump if so

	cmp	al,@OPCOD_DS	; Izit segment override?
	je	short INT07_PL_NEXT ; Jump if so

	cmp	al,@OPCOD_ES	; Izit segment override?
	je	short INT07_PL_NEXT ; Jump if so

	cmp	al,@OPCOD_FS	; Izit segment override?
	je	short INT07_PL_NEXT ; Jump if so

	cmp	al,@OPCOD_GS	; Izit segment override?
	je	short INT07_PL_NEXT ; Jump if so

	cmp	al,@OPCOD_SS	; Izit segment override?
	je	short INT07_PL_NEXT ; Jump if so

	cmp	al,@OPCOD_ASP	; Izit address size prefix?
	je	short INT07_PL_NEXT ; Jump if so

	cmp	al,@OPCOD_OSP	; Izit operand size prefix?
	je	short INT07_PL_NEXT ; Jump if so

; Check the opcode

	cmp	al,@OPCOD_ESC7+1 ; Izit above ESC 07h?
	jae	short INT07_PL_EXIT ; Jump if so (note CF=0 -- ignore the fault)

	cmp	al,@OPCOD_ESC0	; Izit at or above ESC 00h?
				; CF=0 ==> it's a floating point instruction
				; CF=1 ==> not
	cmc			; CF=1 ==> it's a floating point instruction
				; CF=0 ==> not (ignore the fault)
INT07_PL_EXIT:
	pop	ebp		; Restore
INT07_PM_INT:
	REGREST <ds,esi,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jc	short INT07_FLTPM ; Jump if we should continue with the fault

; Treat this interrupt as a software interrupt, not a fault

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_CPIHOOK[07h/8],1 shl (07h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT07_ORIG ; Jump if not

; The stack is mapped by INTDPI_STR

	mov	[esp].INTDPI_INTNO,4*07h ; Mark as INT 07h
	add	[esp].INTDPI_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	push	@PMINTCOM_NRM	; Use application stack
	jmp	PMINTCOM	; Jump to common code

INT07_FLTPM:
	PUSHD	0		; Put pseudo-error code onto stack

; The stack is mapped by INTDPF_STR if we came from DPMI,
; or FLT_STR if we came from MAX.

	mov	[esp].INTDPF_INTNO,4*07h ; Mark as INT 07h
	add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTCOM_DPMI_FAULT ; Join common code


INT07_FLTRETPM:
INT07_FLTRETVM:
	clts			; Clear the TS bit in CR0
INT07_ORIG:
	EXITDPL 07		; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT07	endp			; End INT07 procedure
	FPPROC	INT08 -- Double Fault Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Double Fault (08h) with error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC08
Double Fault	 VM86	  ESP=PPL0STK_ERR	UGH
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Double Fault	 DPMI	  ESP=PPL0STK_DERR	UGH
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT
Double Fault	 PM				UGH

Note that the test for PM interrupts actually tests for CS within
descriptor table limits.  If there is an error code on the stack,
we're testing not caller's CS, but IP.  By construction, IP in our
code can never get small enough to be confused with a valid CS.

|

	call	RESETVARS	; Keep variables up-to-date

	REGSAVE <eax,ds>	; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	lea	eax,[esp+4+4]	; Get original ESP

	cmp	eax,PPL0STK_NRM ; Is the stack normal?
	je	short INT08_DSTKCHK ; Yes, use normal interrupt processor

	cmp	eax,PPL0STK_ERR ; Is it a fault from VM86 mode?
	je	near ptr INT08_VM86 ; Yes

; See if we're called from a DPMI client

	cmp	eax,PPL0STK_DNRM ; Izit a HW/SW interrupt from a DPMI client?
	je	near ptr INT08_DPMI_INT ; Jump if so

	cmp	eax,PPL0STK_DERR ; Izit a fault from a DPMI client?
	je	near ptr INT08_DPMI_FAULT ; Jump if so

; We need to distinguish between HW-MAX and EX-MAX, so we test
; the R3 bit in NRM_EFL.  If it's HW-MAX, NRM_EFL contains EFL
; and that bit is always set.  If it's EX-MAX, NRM_EFL contains
; CS (a selector), and that bit is the high-order bit of CPL.
; As the host never executes at CPL2 or CPL3, that bit is always clear.

	test	ss:[eax].NRM_EFL,mask $R3 ; Izit set?
	jz	near ptr INT08_UGH ; No, so that's a big UGH

; HW-MAX has occurred:	if there's a DPMI client active, treat it
; as a DPMI interrupt so we use the HPDA stack, not LAST_INTCOM.

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	jne	short INT08_DPMI_INT ; Jump if so

	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	mov	[esp].NRM_INTNO,4*08h ; Mark as hardware INT 08h
	add	[esp].NRM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	near ptr HARDINT ; It's a hardware interrupt


	assume	ds:DGROUP	; Tell the assembler about it
INT08_DSTKCHK:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	INTPROC08	; Continue as VM INT 08h


; A hardware interrupt from a DPMI client has occurred

	assume	ds:DGROUP	; Tell the assembler about it
INT08_DPMI_INT:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

; The stack is mapped by INTDPI_STR

	mov	[esp].INTDPI_INTNO,4*08h ; Mark as hardware INT 08h
	add	[esp].INTDPI_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTCOM_DPMI_INT ; Join common code


; A fault from a DPMI client has occurred

	assume	ds:DGROUP	; Tell the assembler about it
INT08_DPMI_FAULT:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

; The stack is mapped by INTDPF_STR

	mov	[esp].INTDPF_INTNO,4*08h ; Mark as INT 08h
	add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTCOM_DPMI_FAULT ; Join common code


	assume	ds:DGROUP	; Tell the assembler about it
INT08_UGH:
INT08_VM86:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	pushad			; Save all EGP registers

	mov	ebp,esp 	; SS:EBP ==> INTXX_STR

	cld			; String ops forwardly

	mov	esi,4*08h	; Interrupt # times 4
	lea	ebx,DGROUP:MSG_L08 ; Offset of message to display to user

	jmp	near ptr INTXXCOM ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT08	endp			; End INT08 procedure
	FPPROC	INT0A -- Invalid TSS Fault Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Invalid TSS Fault (0Ah) with error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC0A
Invalid TSS ???  VM86	  ESP=PPL0STK_ERR	UGH
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Invalid TSS ???  DPMI	  ESP=PPL0STK_DERR	UGH
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT
Invalid TSS	 PM				UGH

Note that the test for PM interrupts actually tests for CS within
descriptor table limits.  If there is an error code on the stack,
we're testing not caller's CS, but IP.  By construction, IP in our
code can never get small enough to be confused with a valid CS.

|

	call	RESETVARS	; Keep variables up-to-date

	REGSAVE <eax,ds>	; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	lea	eax,[esp+4+4]	; Get original ESP

	cmp	eax,PPL0STK_NRM ; Is the stack normal?
	je	short INT0A_DSTKCHK ; Yes, use normal interrupt processor

	cmp	eax,PPL0STK_ERR ; Is it a fault from VM86 mode?
	je	near ptr INT0A_VM86 ; Yes

; See if we're called from a DPMI client

	cmp	eax,PPL0STK_DNRM ; Izit a HW/SW interrupt from a DPMI client?
	je	near ptr INT0A_DPMI_INT ; Jump if so

	cmp	eax,PPL0STK_DERR ; Izit a fault from a DPMI client?
	je	near ptr INT0A_DPMI_FAULT ; Jump if so

; We need to distinguish between HW-MAX and EX-MAX, so we test
; the R3 bit in NRM_EFL.  If it's HW-MAX, NRM_EFL contains EFL
; and that bit is always set.  If it's EX-MAX, NRM_EFL contains
; CS (a selector), and that bit is the high-order bit of CPL.
; As the host never executes at CPL2 or CPL3, that bit is always clear.

	test	ss:[eax].NRM_EFL,mask $R3 ; Izit set?
	jz	near ptr INT0A_UGH ; No, so that's a big UGH

; HW-MAX has occurred:	if there's a DPMI client active, treat it
; as a DPMI interrupt so we use the HPDA stack, not LAST_INTCOM.

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	jne	short INT0A_DPMI_INT ; Jump if so

	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	mov	[esp].NRM_INTNO,4*0Ah ; Mark as hardware INT 0Ah
	add	[esp].NRM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	near ptr HARDINT ; It's a hardware interrupt


	assume	ds:DGROUP	; Tell the assembler about it
INT0A_DSTKCHK:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	INTPROC0A	; Continue as VM INT 0Ah


; A hardware interrupt from a DPMI client has occurred

	assume	ds:DGROUP	; Tell the assembler about it
INT0A_DPMI_INT:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

; The stack is mapped by INTDPI_STR

	mov	[esp].INTDPI_INTNO,4*0Ah ; Mark as hardware INT 0Ah
	add	[esp].INTDPI_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTCOM_DPMI_INT ; Join common code


; A fault from a DPMI client has occurred

	assume	ds:DGROUP	; Tell the assembler about it
INT0A_DPMI_FAULT:

; The only way this can happen in a DPMI client is if they
; execute IRET/d with the NT bit set.

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

;;;;;;; mov	DGROUP:[eax].TSS_EAX,eax ; Save in TSS
	mov	DGROUP:[eax].TSS_EBX,ebx ; ...
	mov	DGROUP:[eax].TSS_ECX,ecx ; ...
	mov	DGROUP:[eax].TSS_EDX,edx ; ...
	mov	DGROUP:[eax].TSS_ESI,esi ; ...
	mov	DGROUP:[eax].TSS_EDI,edi ; ...
	mov	DGROUP:[eax].TSS_EBP,ebp ; ...
	mov	DGROUP:[eax].TSS_EBP,ebp ; ...

;;;;;;; mov	DGROUP:[eax].TSS_DS,ds ; ...
	mov	DGROUP:[eax].TSS_ES,es ; ...
	mov	DGROUP:[eax].TSS_FS,fs ; ...
	mov	DGROUP:[eax].TSS_GS,gs ; ...

	lea	ebp,[esp+4+4]	; SS:EBP ==> INTDPF_STR (+4=EAX, +4=DS)

	push	[ebp].INTDPF_CS ; Get return CS
	pop	DGROUP:[eax].TSS_CS ; Save in TSS

	push	[ebp].INTDPF_EIP ; Get return EIP
	pop	DGROUP:[eax].TSS_EIP ; Save in TSS

	push	[ebp].INTDPF_EFL ; Get return EFL
	and	[esp].EDD,not (mask $NT) ; NT=0
	pop	DGROUP:[eax].TSS_EFL ; Save in TSS

	push	[ebp].INTDPF_ESP ; Get return ESP
	pop	DGROUP:[eax].TSS_ESP ; Save in TSS

	push	[ebp].INTDPF_SS ; Get return SS
	pop	DGROUP:[eax].TSS_SS ; Save in TSS

	push	[ebp-2*4].ELO	; Get return DS
	pop	DGROUP:[eax].TSS_DS ; Save in TSS

	push	[ebp-1*4].EDD	; Get return EAX
	pop	DGROUP:[eax].TSS_EAX ; Save in TSS

	mov	ebp,DGROUP:[eax].TSS_EBP ; Restore

	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

; Setup selectors for INT31_VM2PM_RET

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	es,SEL_DATA	; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	mov	gs,SEL_4GB	; Get AGROUP data selector
	assume	gs:AGROUP	; Tell the assembler about it

; The stack is mapped by INTDPF_STR

	add	esp,type INTDPF_ERR ; Strip the error code

	jmp	INT31_VM2PM_RET ; Join common code

;;;;;;; mov	[esp].INTDPF_INTNO,4*0Ah ; Mark as INT 0Ah
;;;;;;; add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...
;;;;;;;
;;;;;;; jmp	INTCOM_DPMI_FAULT ; Join common code


	assume	ds:DGROUP	; Tell the assembler about it
	assume	es:nothing	; ...
	assume	gs:nothing	; ...
INT0A_UGH:
INT0A_VM86:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	pushad			; Save all EGP registers

	mov	ebp,esp 	; SS:EBP ==> INTXX_STR

	cld			; String ops forwardly

	mov	esi,4*0Ah	; Interrupt # times 4
	lea	ebx,DGROUP:MSG_L0A ; Offset of message to display to user

	jmp	near ptr INTXXCOM ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT0A	endp			; End INT0A procedure
	FPPROC	INT0B -- Segment Not Present Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Segment Not Present interrupt (0Bh) with error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC0B
Segment Overrun  VM86	  ESP=PPL0STK_ERR	UGH
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Segment Overrun  DPMI	  ESP=PPL0STK_DERR	UGH
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT
Segment Overrun  PM				UGH

Note that the test for PM interrupts actually tests for CS within
descriptor table limits.  If there is an error code on the stack,
we're testing not caller's CS, but IP.  By construction, IP in our
code can never get small enough to be confused with a valid CS.

|

	call	RESETVARS	; Keep variables up-to-date

	REGSAVE <eax,ds>	; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	lea	eax,[esp+4+4]	; Get original ESP

	cmp	eax,PPL0STK_NRM ; Is the stack normal?
	je	short INT0B_DSTKCHK ; Yes, use normal interrupt processor

	cmp	eax,PPL0STK_ERR ; Is it a fault from VM86 mode?
	je	near ptr INT0B_VM86 ; Yes

; See if we're called from a DPMI client

	cmp	eax,PPL0STK_DNRM ; Izit a HW/SW interrupt from a DPMI client?
	je	near ptr INT0B_DPMI_INT ; Jump if so

	cmp	eax,PPL0STK_DERR ; Izit a fault from a DPMI client?
	je	near ptr INT0B_DPMI_FAULT ; Jump if so

; We need to distinguish between HW-MAX and EX-MAX, so we test
; the R3 bit in NRM_EFL.  If it's HW-MAX, NRM_EFL contains EFL
; and that bit is always set.  If it's EX-MAX, NRM_EFL contains
; CS (a selector), and that bit is the high-order bit of CPL.
; As the host never executes at CPL2 or CPL3, that bit is always clear.

	test	ss:[eax].NRM_EFL,mask $R3 ; Izit set?
	jz	near ptr INT0B_UGH ; No, so that's a big UGH

; HW-MAX has occurred:	if there's a DPMI client active, treat it
; as a DPMI interrupt so we use the HPDA stack, not LAST_INTCOM.

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	jne	short INT0B_DPMI_INT ; Jump if so

	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	mov	[esp].NRM_INTNO,4*0Bh ; Mark as hardware INT 0Bh
	add	[esp].NRM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	near ptr HARDINT ; It's a hardware interrupt


	assume	ds:DGROUP	; Tell the assembler about it
INT0B_DSTKCHK:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	INTPROC0B	; Continue as VM INT 0Bh


; A hardware interrupt from a DPMI client has occurred

	assume	ds:DGROUP	; Tell the assembler about it
INT0B_DPMI_INT:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

; The stack is mapped by INTDPI_STR

	mov	[esp].INTDPI_INTNO,4*0Bh ; Mark as hardware INT 0Bh
	add	[esp].INTDPI_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTCOM_DPMI_INT ; Join common code


; A fault from a DPMI client has occurred

	assume	ds:DGROUP	; Tell the assembler about it
INT0B_DPMI_FAULT:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

; The stack is mapped by INTDPF_STR

	mov	[esp].INTDPF_INTNO,4*0Bh ; Mark as INT 0Bh
	add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTCOM_DPMI_FAULT ; Join common code


	assume	ds:DGROUP	; Tell the assembler about it
INT0B_UGH:
INT0B_VM86:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	pushad			; Save all EGP registers

	mov	ebp,esp 	; SS:EBP ==> INTXX_STR

	cld			; String ops forwardly

	mov	esi,4*0Bh	; Interrupt # times 4
	lea	ebx,DGROUP:MSG_L0B ; Offset of message to display to user

	jmp	near ptr INTXXCOM ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT0B	endp			; End INT0B procedure
	FPPROC	INT0C -- Stack Fault Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Stack fault interrupt (0Ch) with error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC0C
Stack Fault	 VM86	  ESP=PPL0STK_ERR	UGH
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Stack Fault	 DPMI	  ESP=PPL0STK_DERR	UGH
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT
Stack Fault	 PM				UGH

Note that the test for PM interrupts actually tests for CS within
descriptor table limits.  If there is an error code on the stack,
we're testing not caller's CS, but IP.  By construction, IP in our
code can never get small enough to be confused with a valid CS.

|

	call	RESETVARS	; Keep variables up-to-date

	REGSAVE <eax,ds>	; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	lea	eax,[esp+4+4]	; Get original ESP

	cmp	eax,PPL0STK_NRM ; Is the stack normal?
	je	short INT0C_DSTKCHK ; Yes, use normal interrupt processor

	cmp	eax,PPL0STK_ERR ; Is it a fault from VM86 mode?
	je	near ptr INT0C_VM86 ; Yes

; See if we're called from a DPMI client

	cmp	eax,PPL0STK_DNRM ; Izit a HW/SW interrupt from a DPMI client?
	je	near ptr INT0C_DPMI_INT ; Jump if so

	cmp	eax,PPL0STK_DERR ; Izit a fault from a DPMI client?
	je	near ptr INT0C_DPMI_FAULT ; Jump if so

; We need to distinguish between HW-MAX and EX-MAX, so we test
; the R3 bit in NRM_EFL.  If it's HW-MAX, NRM_EFL contains EFL
; and that bit is always set.  If it's EX-MAX, NRM_EFL contains
; CS (a selector), and that bit is the high-order bit of CPL.
; As the host never executes at CPL2 or CPL3, that bit is always clear.

	test	ss:[eax].NRM_EFL,mask $R3 ; Izit set?
	jz	near ptr INT0C_UGH ; No, so that's a big UGH

; HW-MAX has occurred:	if there's a DPMI client active, treat it
; as a DPMI interrupt so we use the HPDA stack, not LAST_INTCOM.

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	jne	short INT0C_DPMI_INT ; Jump if so

	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	mov	[esp].NRM_INTNO,4*0Ch ; Mark as hardware INT 0Ch
	add	[esp].NRM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	near ptr HARDINT ; It's a hardware interrupt


	assume	ds:DGROUP	; Tell the assembler about it
INT0C_DSTKCHK:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	INTPROC0C	; Continue as VM INT 0Ch


; A hardware interrupt from a DPMI client has occurred

	assume	ds:DGROUP	; Tell the assembler about it
INT0C_DPMI_INT:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

; The stack is mapped by INTDPI_STR

	mov	[esp].INTDPI_INTNO,4*0Ch ; Mark as hardware INT 0Ch
	add	[esp].INTDPI_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTCOM_DPMI_INT ; Join common code


; A fault from a DPMI client has occurred

	assume	ds:DGROUP	; Tell the assembler about it
INT0C_DPMI_FAULT:
	mov	ax,[esp+8].INTDPF_SS ; Get the faulting SS
				; (the "+8" is for <ds,eax>
				; still on the stack)
	cmp	ax,LPMSTK_SEL	; Izit our LPM stack selector?
	stc			; Assume not
	jne	short @F	; Jump if not

	push	eax		; Pass LPM stack selector as dword
	push	4*1024		; ...  # bytes needed
	call	DPMIFN_EXPLPM	; Expand the LPM stack
				; Return with CF significant
@@:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it
	jc	short @F	; Jump if not growing LPM stack

	add	esp,size INTDPF_ERR ; Strip off the error code

	iretd			; Return to caller


@@:

; The stack is mapped by INTDPF_STR

	mov	[esp].INTDPF_INTNO,4*0Ch ; Mark as INT 0Ch
	add	[esp].INTDPF_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTCOM_DPMI_FAULT ; Join common code


; Case EX-MAX:	SS:ESP ==> EAX, DS, FLT_STR

	assume	ds:DGROUP	; Tell the assembler about it
INT0C_UGH:
	lea	eax,[esp+4+4+(size FLT_STR)] ; Get faulting ESP

	jmp	short INT0C_UGH_COM ; Join common code


; Case EX-VM86:  SS:ESP ==> EAX, DS, ERRCODE, INTCOM_STR

	assume	ds:DGROUP	; Tell the assembler about it
INT0C_VM86:
	mov	eax,[esp+4+4+4].INTCOM_ESP ; Get faulting ESP
INT0C_UGH_COM:
	REGSAVE <edi,es>	; Save for a moment

	mov	edi,ds		; Get DGROUP selector
	mov	es,edi		; Address it
	assume	es:DGROUP	; Tell the assembler about it

	lea	edi,DGROUP:L0CNUM[-8] ; Offset of message to display to user
	call	DD2HEX		; Convert EAX to hex at ES:EDI

	REGREST <es,edi>	; Restore
	assume	es:nothing	; Tell the assembler about it

	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	pushad			; Save all EGP registers

	mov	ebp,esp 	; SS:EBP ==> INTXX_STR, possibly no higher
				; INTXX_EFL if it's EX-MAX
	cld			; String ops forwardly

	mov	esi,4*0Ch	; Interrupt # times 4
	lea	ebx,DGROUP:MSG_L0C ; Offset of message to display to user

	jmp	near ptr INTXXCOM ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT0C	endp			; End INT0C procedure
	FPPROC	INT09 -- Keyboard Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Keyboard interrupt (09h) without error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC09
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT

|

	mov	[esp].INTCOM_INTNO,4*09h ; Mark as hardware INT 09h
	add	[esp].INTCOM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTNFCOM	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT09	endp			; End INT09 procedure
	FPPROC	INT0F -- Spurious Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Spurious interrupt (0Fh) without error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC0F
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT

|

	mov	[esp].INTCOM_INTNO,4*0Fh ; Mark as hardware INT 0Fh
	add	[esp].INTCOM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	INTNFCOM	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT0F	endp			; End INT0F procedure
	FPPROC	INT70 -- IRQ8 Real-Time Clock Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

IRQ8 Real-Time Clock interrupt (70h) without error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC70
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT

On entry:

SS:ESP	==>	INTCOM_STR

|

	mov	[esp].INTCOM_INTNO,4*70h ; Mark as hardware INT 70h
	add	[esp].INTCOM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	short INTNFCOM	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT70	endp			; End INT70 procedure
	FPPROC	INT71 -- IRQ9 Redirect Cascade Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

IRQ9 Redirect Cascade (71h) without error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC71
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT

On entry:

SS:ESP	==>	INTCOM_STR

|

	mov	[esp].INTCOM_INTNO,4*71h ; Mark as hardware INT 71h
	add	[esp].INTCOM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	short INTNFCOM	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT71	endp			; End INT71 procedure
	FPPROC	INT72 -- IRQ10 Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

IRQ10 (72h) without error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC72
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT

On entry:

SS:ESP	==>	INTCOM_STR

|

	mov	[esp].INTCOM_INTNO,4*72h ; Mark as hardware INT 72h
	add	[esp].INTCOM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	short INTNFCOM	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT72	endp			; End INT72 procedure
	FPPROC	INT73 -- IRQ11 Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

IRQ11 (73h) without error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC73
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT

On entry:

SS:ESP	==>	INTCOM_STR

|

	mov	[esp].INTCOM_INTNO,4*73h ; Mark as hardware INT 73h
	add	[esp].INTCOM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	short INTNFCOM	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT73	endp			; End INT73 procedure
	FPPROC	INT74 -- IRQ12 Auxiliary Device Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

IRQ12 Auxiliary Device (74h) without error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC74
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT

On entry:

SS:ESP	==>	INTCOM_STR

|

	mov	[esp].INTCOM_INTNO,4*74h ; Mark as hardware INT 74h
	add	[esp].INTCOM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	short INTNFCOM	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT74	endp			; End INT74 procedure
	FPPROC	INT75 -- IRQ13 Math Coprocessor Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

IRQ13 Math Coprocessor (75h) without error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC75
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT

On entry:

SS:ESP	==>	INTCOM_STR

|

	mov	[esp].INTCOM_INTNO,4*75h ; Mark as hardware INT 75h
	add	[esp].INTCOM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	short INTNFCOM	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT75	endp			; End INT75 procedure
	FPPROC	INT76 -- IRQ14 Fixed Disk Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

IRQ14 Fixed Disk (76h) without error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC76
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT

On entry:

SS:ESP	==>	INTCOM_STR

|

	mov	[esp].INTCOM_INTNO,4*76h ; Mark as hardware INT 76h
	add	[esp].INTCOM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	short INTNFCOM	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT76	endp			; End INT76 procedure
	FPPROC	INT77 -- IRQ15 Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

IRQ15 (77h) without error code on stack.

Distinguish amongst several cases:

Type		 Mode	  Test			Action
--------------------------------------------------------------------
Hard/software	 VM86	  ESP=PPL0STK_NRM	Goto INTPROC77
Hard/software	 DPMI	  ESP=PPL0STK_DNRM	Goto HARDINT
Hard/software	 PM	  CS=[EBP].NRM_CS	Goto HARDINT

On entry:

SS:ESP	==>	INTCOM_STR

|

	mov	[esp].INTCOM_INTNO,4*77h ; Mark as hardware INT 77h
	add	[esp].INTCOM_INTNO.EDD,offset PGROUP:INTPROC00Z ; ...

	jmp	short INTNFCOM	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT77	endp			; End INT77 procedure
	NPPROC	INTNFCOM -- Common Non-Fault Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Common non-fault interrupt handler

On entry:

INTCOM_INTNO has the INT # times 4 + offset PGROUP:INTPROC00Z

Note that the test for PM interrupts actually tests for CS within
descriptor table limits.  If there is an error code on the stack,
we're testing not caller's CS, but IP.  By construction, IP in our
code can never get small enough to be confused with a valid CS.

|

	call	RESETVARS	; Keep variables up-to-date

	REGSAVE <eax,ds>	; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	lea	eax,[esp+4+4]	; Get original ESP

	cmp	eax,PPL0STK_NRM ; Is the stack normal?
	je	short INTNFCOM_DSTKCHK ; Yes, use normal interrupt processor

; See if we're called from a DPMI client

	cmp	eax,PPL0STK_DNRM ; Izit a HW/SW interrupt from a DPMI client?
	je	short INTNFCOM_DPMI_INT ; Jump if so

; HW-MAX has occurred:	if there's a DPMI client active, treat it
; as a DPMI interrupt so we use the HPDA stack, not LAST_INTCOM.

	cmp	DPMITYPE,@DPMITYPEXX ; Izit active?
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it
	jne	near ptr INTCOM_DPMI_INT ; Jump if so

	jmp	near ptr HARDINT ; It's a hardware interrupt


INTNFCOM_DPMI_INT:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	jmp	INTCOM_DPMI_INT ; Jump if so


INTNFCOM_DSTKCHK:
	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	push	eax		; Save for a moment (also return address)

	movzx	eax,[esp+4].INTCOM_INTNO ; Get INT # times 4 + ...
	sub	eax,INTPROC00Z-INTPROC00 ; Back off to INTPROCxx
	xchg	eax,[esp]	; Restore original EAX
; *FIXME* to handle CPL > DPL if necessary
	ret			; Use normal interrupt processor

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INTNFCOM endp			; End INTNFCOM procedure
;;;	     NPPROC  HARDINT -- Handle Hardware Interrupts
;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;; COMMENT|
;;;
;;; Handle hardware interrupts while executing in protected mode.
;;;
;;; The stack upon entry contains
;;;
;;; EIP
;;; CS
;;; INT # * 4+ offset PGROUP:INTPROC00Z
;;; EFL
;;;
;;; * Pass control to the original handler
;;;
;;; On entry:
;;;
;;; IF	     =	     0 (interrupts disabled)
;;;
;;; |
;;;
;;; HARDINT_STR struc
;;;
;;; ; The VM 8086 stack starts here
;;;
;;; HARDINT_VEIP dd  ?		    ; VM 8086  EIP
;;; HARDINT_VCS  dw  ?		    ; ...      CS
;;; HARDINT_VINT dw  ?		    ; ...      INT # times 4 + offset PGROUP:INTPROC00Z
;;; HARDINT_VEFL dd  ?		    ; ...      EFL
;;; HARDINT_VESP dd  ?		    ; ...      ESP
;;; HARDINT_VSS dd   ?		    ; ...      SS with filler
;;; HARDINT_VES dd   ?		    ; ...      ES ...
;;; HARDINT_VDS dd   ?		    ; ...      DS ...
;;; HARDINT_VFS dd   ?		    ; ...      FS ...
;;; HARDINT_VGS dd   ?		    ; ...      GS ...
;;;
;;; ; The return stack starts here
;;;
;;; HARDINT_ESP dd   ?		    ; Caller's ESP
;;; HARDINT_SS dw    ?		    ; ...      SS
;;; HARDINT_GLB dw   ?		    ; GLB_FLAG
;;; HARDINT_GS dw    ?		    ; Caller's GS
;;; HARDINT_FS dw    ?		    ; ...      FS
;;; HARDINT_ES dw    ?		    ; ...      ES
;;; HARDINT_DS dw    ?		    ; ...      DS
;;; HARDINT_EIP dd   ?		    ; ...      EIP
;;; HARDINT_CS	dw   ?		    ; ...      CS
;;; HARDINT_INTNO dw ?		    ; Interrupt #
;;; HARDINT_EFL dd   ?		    ; ...      EFL
;;;
;;; HARDINT_STR ends
;;;
;;;
;;; COMMENT|
;;;
;;; Because of a bug in the Rational Systems DOS extender in (say) Lotus
;;; 1-2-3 Version 3.10 which trashes the high-order word of several 32-bit
;;; registers (EAX, ECX, EDX, and ESI), we must save those values here and
;;; restore them upon return.
;;;
;;; |
;;;
;;; ; * Save all segment registers on the stack
;;;
;;;	     REGSAVE <ds,es,fs,gs>  ; Save all data segment registers
;;;
;;;	     SETDATA ds 	    ; Get DGROUP data selector
;;;	     assume  ds:DGROUP	    ; Tell the assembler about it
;;;
;;;	     mov     SAVE_EAX,eax   ; Save for a moment
;;;
;;;	     inc     HARDCNT	    ; Count in another interrupt
;;;
;;; ; * Save local data variables
;;;
;;; ; Save on the stack any local data variables which might be
;;; ; overwritten while executing the hardware interrupt
;;;
;;;	     push    GLB_FLAG
;;;
;;; ;;;;;;;; call    WRAP_ENABLE    ; Ensure 1MB wrap enabled
;;;
;;;	     mov     eax,PCURTSS    ; Get offset in DGROUP of current TSS
;;;	     push    DGROUP:[eax].TSS_SS0  ; Save old stack selector
;;;	     push    DGROUP:[eax].TSS_ESP0 ; Save pointer to stack top
;;;
;;; ; * Save SS:ESP as new top of stack pointer
;;;
;;;	     mov     DGROUP:[eax].TSS_SS0,ss ; Save for next time
;;;	     mov     DGROUP:[eax].TSS_ESP0,esp ; ... *FIXME*
;;;
;;;	     cli		    ; Disallow interrupts
;;;
;;; ; * Recalculate PL0STK pointers
;;;
;;;	     call    SET_PPL0STK    ; Set PPL0STK... pointers
;;;
;;; ; * Setup stack for IRETD
;;;
;;;	     mov     eax,LAST_INTCOM ; DS:EAX ==> bottom of last INTCOM
;;;				    ; interrupt frame
;;;
;;; ; Note we don't know whether or not this call interrupted a procedure
;;; ; with an error code on the stack.	Thus we can't refer to any data
;;; ; below INTCOM_EIP.
;;;
;;; ; Setup stack as if we'd been interrupted from VM86 mode
;;;
;;; ; We can't allow an interrupt during the following code in case the
;;; ; interrupt handler might trip at the point where PL0STK_ERR or PL0STK_NRM
;;; ; would be matched.
;;;
;;;	     push    [eax].INTCOM_GS.EDD ; GS as dword
;;;	     push    [eax].INTCOM_FS.EDD ; FS
;;;	     push    [eax].INTCOM_DS.EDD ; DS
;;;	     push    [eax].INTCOM_ES.EDD ; ES
;;;	     push    [eax].INTCOM_SS.EDD ; SS
;;;	     push    [eax].INTCOM_ESP ; ESP
;;;
;;;	     PUSHD   0		    ; Place holder for EFL
;;;
;;;	     push    HIMEM_CS.EDD   ; CS with placeholder for HARDINT_VINT
;;;
;;;	     push    dword ptr (offset cs:HARDRET) ; EIP.ELO
;;;
;;; ; At this point, the stack is correctly modeled by HARDINT_STR
;;; ; and can be addressed through [ESP].
;;;
;;;	     mov     eax,[esp].HARDINT_EFL ; Get caller's flags
;;;	     and     eax,not ((mask $RFHI) or (mask $IOPL)); RF=IOPL=0
;;;	     or      eax,(mask $VMHI) or (@VMIOPL shl $IOPL) ; VM=1, IOPL=@VMIOPL
;;;	     mov     [esp].HARDINT_VEFL,eax ; Save on stack
;;;
;;;	     mov     ax,[esp].HARDINT_INTNO ; Get the INT # times 4 + ...
;;;	     mov     [esp].HARDINT_VINT,ax ; Save on stack
;;;
;;;	     sub     ax,INTPROC00Z-INTPROC00 ; Back off to the CALL
;;;	     xchg    eax,SAVE_EAX   ; Restore
;;;
;;;	     jmp     SAVE_EAX.ELO   ; Jump to common routine
;;;
;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;
;;; HARDINT  endp		    ; End HARDINT procedure
%	FPPROC	INT&@PMH_INT -- Hardware Interrupt Return Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Hardware interrupt return handler (0&@PMH_INT&h) without error code on stack.

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit VM86 mode?
%	jz	short INT&@PMH_INT&_ORIG ; Jump if not (INTCOM catches DPMI calls)

	cmp	[esp].NRM_CS,seg YGROUP ; Check against device driver's CS
	org	$-2
%	public	INT&@PMH_INT&_HIMEM_CS
% INT&@PMH_INT&_HIMEM_CS label near
	org	$+2
	je	short @F	; Jump if so

	jmp	DPMI_SIMRET	; Jump if not (check on DPMI returns)

@@:
% INT&@PMH_INT&_ORIG:
%	EXITDPL @PMH_INT	; Continue with next handler or GP Fault
	assume	ds:nothing	; Tell the assembler about it

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

% INT&@PMH_INT endp		; End INT&@PMH_INT procedure

CODE16	ends			; End CODE16 segment

	MEND			; End DPMI_IDT module
