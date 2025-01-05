;' $Header$
	title	DPMI_D33 -- DPMI.LOD DPMI INT 33h Translation Services
	page	58,122
	name	DPMI_D33
COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1991-2004 Sudley Place Software.   

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include PTR.INC
	include DPMI.INC
	include ALLMEM.INC
	include CPUFLAGS.INC
	include MASM5.MAC
	include BITFLAGS.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_EXP.INC
	include DPMI_SEG.INC

	include QMAX_I31.INC		; Must precede QMAXDPMI.INC
	include QMAXDPMI.INC		; Must follow QMAX_I31.INC
	include QMAX_TSS.INC
	include QMAX_VMM.INC
.list

CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
	assume	cs:PGROUP,ds:PGROUP

	extrn	INTPROC00Z:near

	extrn	ERM_FVEC:fword

CODE16A ends			; End CODE16A segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	extrn	I31_FLAG:word

	extrn	VMM_FLAG:word

	extrn	PageFaultActive:byte

	extrn	CON64KB:dword
	extrn	CON1MB:dword

	extrn	DPMI_CPIHOOK:byte
	extrn	VMCREGS:tbyte
	extrn	PVMTSS:dword
	extrn	PCURTSS:dword
	extrn	DPMI_IDEF:word
	extrn	LPMSTK_FVEC:fword
	extrn	LPMSTK_CNT:dword
	extrn	LAST_DPMI_DS:word
	extrn	LAST_DPMI_ES:word
	extrn	LAST_DPMI_FS:word
	extrn	LAST_DPMI_GS:word
	extrn	LAST_INTCOM:dword
	extrn	LAST_INTFLG:dword

	extrn	OLD_PCURTSS:dword
	extrn	SAVE_EAX:dword
;;;;;;; extrn	SAVE_ECX:dword
;;;;;;; extrn	SAVE_ESI:dword
;;;;;;; extrn	SAVE_EDI:dword

	extrn	LaINDOS:dword

;;;;;;; extrn	PPL0STK_MAX:dword
;;;;;;; extrn	PLCL_PL0CUR:dword

DATA	ends			; End DATA segment


; Define mouse INT 33h functions which we handle

DPMIMOUSEMAC macro VAL,ACT

ACTSEG	segment use32 dword public 'data' ; Start ACTSEG segment
	assume	ds:DGROUP

	org	DPMIMOUSE_ACT + VAL * (type DPMIMOUSE_ACT) ; Set to appropriate origin
	dd	offset DGROUP:INT33_DPMIJMP_&ACT
	org	DPMIMOUSE_ACTZ	; Restore to end of the table

ACTSEG	ends			; End ACTSEG segment

	endm			; DPMIMOUSEMAC


ACTSEG	segment use32 dword public 'data' ; Start ACTSEG segment
	assume	ds:DGROUP

	public	@DPMI_D33_ACTSEG
@DPMI_D33_ACTSEG label byte	; Mark module start in .MAP file

	public	DPMIMOUSE_ACT
DPMIMOUSE_ACT dd  256 dup (offset DGROUP:INT33_DPMIJMP_PASSTHRU) ; Seed with pass through action
DPMIMOUSE_ACTZ label dword

ACTSEG	ends			; End ACTSEG segment


; The following mouse functions require special treatment

.sall
	DPMIMOUSEMAC	09h,SETSHAPE	; 09:  Set Pointer Shape
	DPMIMOUSEMAC	0Ch,HOOKMEI	; 0C:  Hook Mouse Event Interrupt
	DPMIMOUSEMAC	14h,SWAPINT	; 14:  Swap Mouse Interrupt Subroutines
	DPMIMOUSEMAC	15h,GETSSRSIZE	; 15:  Get State Save/Restore Buffer Size
	DPMIMOUSEMAC	16h,SAVESTATE	; 16:  Save Driver State
	DPMIMOUSEMAC	17h,RESTSTATE	; 17:  Restore Driver State
.lall


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_D33_DATA
@DPMI_D33_DATA	label byte	; Mark module start in .MAP file

	extrn	DPMITYPEIG:byte

DLBL	macro	LBL
INT33_DPMIJMP_&LBL label dword
	endm			; DLBL


ACT	macro	LBL
	public	INT33_DPMI_&LBL
	dd	offset PGROUP:INT33_DPMI_&LBL
	endm			; ACT


DOSFN	macro	LBL,ARGS
	dd	offset PGROUP:DOSFN_&LBL
ifnb <ARGS>
	dd	ARGS
endif				; IFNB
	endm			; DOSFN


DJMP	macro	LBL
	dd	offset PGROUP:DOSFN_JMP
	dd	offset DGROUP:INT33_DPMIJMP_&LBL
	endm			; DJMP


	public	JMPTAB33
JMPTAB33 label	dword
.sall
	DLBL	SETSHAPE	; 09:  Set Pointer Shape
	DOSFN	SAVE_INTXXREG,<INTXX_EDX>
	DOSFN	SAVE_VMCREGS
	ACT	SETSHAPE
	DOSFN	GETBUF,<VMC_EDX.ELO,VMC_ES,INTXX_EDX,I31_ES-@I31BACK>
	DOSFN	SIMVMI,33h
	DOSFN	RELBUF		; No need to copy back the buffer
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDX>
	ACT	EXIT


	DLBL	HOOKMEI 	; 0C:  Hook Mouse Event Interrupt
	DOSFN	SAVE_INTXXREG,<INTXX_EDX>
	DOSFN	SAVE_VMCREGS
	ACT	HOOKMEI
	DOSFN	SIMVMI,33h
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDX>
	ACT	EXIT


	DLBL	SWAPINT 	; 14:  Swap Mouse Interrupt Subroutines
	DOSFN	SAVE_VMCREGS
	ACT	SWAPINT
	ACT	HOOKMEI
	DOSFN	SIMVMI,33h
	ACT	SWAPINT_EXIT
     DLBL	SWAPINT_TAIL
	DOSFN	SEG2SEL,<@CODESEL,VMC_ES,I31_ES-@I31BACK>
	DOSFN	IF32ZX,<VMC_EDX.EHI>
	DOSFN	REST_VMCREGS
	ACT	EXIT

     DLBL	SWAPINT_REST
	DOSFN	SIMVMI,33h
	DJMP	SWAPINT_TAIL


	DLBL	GETSSRSIZE	; 15:  Get State Save/Restore Buffer Size
	DOSFN	SAVE_VMCREGS
	DOSFN	SIMVMI,33h
	ACT	GETSSRSIZE_EXIT
	DOSFN	REST_VMCREGS
	ACT	EXIT


	DLBL	SAVESTATE	; 16:  Save Driver State
	DOSFN	SAVE_INTXXREG,<INTXX_EDX>
	DOSFN	SAVE_VMCREGS
	ACT	SAVESTATE
	DOSFN	GETBUF,<VMC_EDX.ELO,VMC_ES,INTXX_EDX,I31_ES-@I31BACK>
	DOSFN	SIMVMI,33h
	DOSFN	LOW2EXT,<INTXX_EDX,I31_ES-@I31BACK>
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDX>
	ACT	EXIT


	DLBL	RESTSTATE	; 17:  Restore Driver State
	DOSFN	SAVE_INTXXREG,<INTXX_EDX>
	DOSFN	SAVE_VMCREGS
	ACT	RESTSTATE
	DOSFN	GETBUF,<VMC_EDX.ELO,VMC_ES,INTXX_EDX,I31_ES-@I31BACK>
	DOSFN	SIMVMI,33h
	DOSFN	RELBUF		; No need to copy back the buffer
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDX>
	ACT	EXIT

; We rely on 0FFh being unsupported...

	DLBL	RESTMEI 	; Restore MEI upon termination
	DOSFN	SAVE_INTXXREG,<INTXX_EAX>
	DOSFN	SAVE_INTXXREG,<INTXX_ECX>
	DOSFN	SAVE_INTXXREG,<INTXX_EDX>
	DOSFN	SAVE_VMCREGS
	ACT	RESTMEI
	DOSFN	SIMVMI,33h
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDX>
	DOSFN	REST_INTXXREG,<INTXX_ECX>
	DOSFN	REST_INTXXREG,<INTXX_EAX>
	ACT	RESTMEI_EXIT


	DLBL	PASSTHRU	; Pass through label for all other functions
	DOSFN	SAVE_VMCREGS
	DOSFN	SIMVMI,33h
	DOSFN	REST_VMCREGS
	ACT	EXIT
.lall

DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_D33_PROG
@DPMI_D33_PROG: 		; Mark module start in .MAP file

	extrn	GETBASE:near
	extrn	SET_PPL0STK:near
	extrn	PMINTCOM:near
	extrn	DOSFN_SAVE_INTXXREG:near
	extrn	DOSFN_SAVE_VMCREGS:near
	extrn	DOSFN_GETBUF:near
	extrn	DOSFN_SIMVMI:near
	extrn	DOSFN_RELBUF:near
	extrn	DOSFN_LOW2EXT:near
	extrn	DOSFN_REST_VMCREGS:near
	extrn	DOSFN_REST_INTXXREG:near
	extrn	DOSFN_SEG2SEL:near
	extrn	DOSFN_IF32ZX:near
	extrn	DOSFN_JMP:near
	extrn	FLTPROC_LPMFULL:near
	extrn	PMMEI:abs
	extrn	DPMIFN_LMSW:near
	extrn	DPMIFN_NESTRET:near
	extrn	DPMIFN_LPMSTK:near
if @EXPD
	extrn	DPMIFN_EBXMOD:near
	extrn	DPMIFN_CHKSTK:near
endif
	FPPROC	INT33_DPMI -- Mouse Calls from DPMI Clients
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Mouse calls from DPMI clients

On entry:

AX	=	function #

|

; If the caller is at PL0, don't pass on to any DPMI clients

	test	[esp].INTDPI_CS,mask $PL ; Izit at PL0?
	jz	short INT33_INTRETPM ; Jump if so

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_CPIHOOK[33h/8],1 shl (33h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT33_INTRETPM ; Jump if not

	mov	[esp].INTCOM_INTNO,4*33h + offset PGROUP:INTPROC00Z

	push	@PMINTCOM_NRM	; Use application stack
	jmp	near ptr PMINTCOM ; Jump to common code


; We're back to handle it ourselves

	public	INT33_INTRETPM
INT33_INTRETPM:
	PUSHD	0		; Put pseudo-error code onto stack

	pushad			; All EGP registers

	cld			; Ensure string ops forwardly
	mov	ebp,esp 	; SS:EBP ==> INTXX_STR
				; (nothing above INTXX_SS is valid)
	REGSAVE <ds,es> 	; Save segment registers

; Note that the above REGSAVE is mapped by I31_STR and must be
; consistent with it

	SETDATA es		; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	push	LPMSTK_FVEC.FSEL.EDD ; Save current LPM stack top
	push	LPMSTK_FVEC.FOFF ; ...

; Set new LPM stack top for nested callers if it's active
; and we're called from PM, not PL0

	lea	eax,[ebp].INTXX_EIP ; SS:EAX ==> INTDPI_STR from PL3
	push	eax		; Pass the offset
	call	DPMIFN_LPMSTK	; Save new LPM stack as appropriate

; Enable interrupts if the caller has them enabled

	push	[ebp].INTXX_EFL ; Get caller's flags
	and	[esp].ELO,not ((mask $NT) or (mask $DF) or (mask $TF)) ; NT=TF=DF=0
	popfd			; Put caller's IF into effect

	movzx	eax,[ebp].INTXX_EAX.ELO ; Copy function code

; Check for invalid functions we should ignore

	or	ah,ah		; Izit an odd Int 33h call?
	jz	short @F	; Jump if not

	mov	ax,0FFh 	; Use a known unsupported function
@@:
	mov	esi,DPMIMOUSE_ACT[eax*(type DPMIMOUSE_ACT)] ; ES:ESI ==> action stream
	lods	JMPTAB33[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 09:  Set Pointer Shape

; On entry (in PL3 stack):
; ES:eDX ==>	 64-byte buffer

; On entry (in registers):
; ES:ESI ==>	 action stream
; ES	 =	 DGROUP
; SS:EBP ==>	 INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT33_DPMI_SETSHAPE:
	mov	eax,64		; Get pointer shape buffer

	push	eax		; RELBUF:  # bytes to release in buffer
	push	eax		; GETBUF:  # leading bytes to copy
	push	eax		; GETBUF:  # bytes to allocate in buffer

	lods	JMPTAB33[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 0C:  Hook Mouse Event Interrupt

; On entry (in PL3 stack):
; ES:eDX ==>	 PM Mouse Event Interrupt handler

; On entry (in registers):
; ES:ESI ==>	 action stream
; ES	 =	 DGROUP
; SS:EBP ==>	 INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT33_DPMI_HOOKMEI:
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	mov	bx,[ebp-@I31BACK].I31_ES ; Get caller's selector
	mov	DGROUP:[eax].DPTSS_MEI_FVEC.FSEL,bx ; Set selector

	mov	ebx,[ebp].INTXX_EDX ; Get offset
	mov	DGROUP:[eax].DPTSS_MEI_FVEC.FOFF,ebx ; Set offset

	mov	bx,DGROUP:[eax].DPTSS_HPDASEG ; Get segment of HPDA
	mov	VMCREGS.VMC_ES,bx ; Pass to VM
	mov	VMCREGS.VMC_EDX.ELO,offset HPDA_MEI ; Save offset

	lods	JMPTAB33[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 14:  Swap Mouse Interrupt Subroutines

; On entry (in PL3 stack):
; ES:eDX ==>	 incoming subroutine
; CX	 =	 incoming call mask

; On exit (in PL3 stack):
; ES:eDX ==>	 previous subroutine
; CX	 =	 previous call mask

; On entry (in registers):
; ES:ESI ==>	 action stream
; ES	 =	 DGROUP
; SS:EBP ==>	 INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT33_DPMI_SWAPINT:

; If the incoming address matches the original address, and the
; call masks match, we assume that the client is restoring it

	push	[ebp-@I31BACK].I31_ES.EDD ; Pass selector (as dword)
	call	GETBASE 	; Return with EAX = base address of selector

	test	al,@NIB0	; Izit on a para boundary?
	jnz	short INT33_DPMI_SWAPINT1 ; Jump if not

	cmp	eax,CON1MB	; Izit within the first megabyte?
	jae	short INT33_DPMI_SWAPINT1 ; Jump if not

	mov	ebx,[ebp].INTXX_EDX ; Get offset
	IF16ZX	bx,IG		; Zero to use as dword if 16-bit client

	cmp	ebx,CON64KB	; Izit too large?
	jae	short INT33_DPMI_SWAPINT1 ; Jump if so

	shr	eax,4-0 	; Convert from bytes to paras
	shl	eax,16		; Shift to high-order word
	mov	ax,bx		; Copy offset

	mov	edx,PCURTSS	; Get offset in DGROUP of current TSS

	cmp	eax,DGROUP:[edx].DPTSS_MEI_ORIG_VEC ; Izit the same?
	jne	short INT33_DPMI_SWAPINT1 ; Jump if not

	mov	ax,[ebp].INTXX_ECX.ELO ; Get the call mask

	cmp	ax,DGROUP:[edx].DPTSS_MEI_ORIG_MASK ; Izit the same?
	jne	short INT33_DPMI_SWAPINT1 ; Jump if not

	shr	eax,16		; Shift segment to low-order word
	mov	VMCREGS.VMC_ES,ax ; Pass to VM

; As we're restoring the original value, zero the entries
; in DPTSS_STR so we save any new value there the next time.

	mov	DGROUP:[edx].DPTSS_MEI_ORIG_VEC,0 ; Zero for next time
	mov	DGROUP:[edx].DPTSS_MEI_ORIG_MASK,0 ; ...

	lea	esi,INT33_DPMIJMP_SWAPINT_REST ; ES:ESI ==> action stream
INT33_DPMI_SWAPINT1:
	lods	JMPTAB33[esi]	; Get next action
	jmp	eax		; Take appropriate action


INT33_DPMI_SWAPINT_EXIT:

; If we've not saved these values in DPTSS_STR, do so now
; so we can restore them when we exit

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	cmp	DGROUP:[eax].DPTSS_MEI_ORIG_VEC,0 ; Izit already saved?
	jne	short @F	; Jump if so

	mov	bx,VMCREGS.VMC_ES ; Get original segment
	shl	ebx,16		; Shift segment to high-order word
	mov	bx,VMCREGS.VMC_EDX.ELO ; Get original offset
	mov	DGROUP:[eax].DPTSS_MEI_ORIG_VEC,ebx ; Save to restore later

	mov	bx,VMCREGS.VMC_ECX.ELO ; Get original mask
	mov	DGROUP:[eax].DPTSS_MEI_ORIG_MASK,bx ; Save to restore later
@@:
	lods	JMPTAB33[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 15:  Get State Save/Restore Buffer Size

; On entry (in PL3 stack):
; BX	 =	 State Save/Restore Buffer Size (in bytes)

; On entry (in registers):
; ES:ESI ==>	 action stream
; ES	 =	 DGROUP
; SS:EBP ==>	 INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT33_DPMI_GETSSRSIZE_EXIT:
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	push	ebx		; Save for a moment

	mov	bx,VMCREGS.VMC_EBX.ELO ; Get State Save/Restore Buffer Size
	mov	DGROUP:[eax].DPTSS_MOUSE_SSRSIZE,bx ; Save size

	pop	ebx		; Restore

	lods	JMPTAB33[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 16:  Save Driver State

; On entry (in PL3 stack):
; ES:eDX ==>	 Buffer into which state is to be saved

; On entry (in registers):
; ES:ESI ==>	 action stream
; ES	 =	 DGROUP
; SS:EBP ==>	 INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT33_DPMI_SAVESTATE:
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	movzx	eax,DGROUP:[eax].DPTSS_MOUSE_SSRSIZE ; Get size of buffer

	push	eax		; LOW2EXT:  # bytes to release (entire buffer)
	push	eax		; LOW2EXT:  # trailing bytes to copy (entire buffer)
	PUSHD	0		; GETBUF:   # leading bytes to copy
	push	eax		; GETBUF:   # bytes to allocate in buffer

	lods	JMPTAB33[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 17:  Restore Driver State

; On entry (in PL3 stack):
; ES:eDX ==>	 Buffer from which state is to be restored

; On entry (in registers):
; ES:ESI ==>	 action stream
; ES	 =	 DGROUP
; SS:EBP ==>	 INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT33_DPMI_RESTSTATE:
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	movzx	eax,DGROUP:[eax].DPTSS_MOUSE_SSRSIZE ; Get size of buffer

	push	eax		; RELBUF:  # bytes to release in buffer
	push	eax		; GETBUF:  # leading bytes to copy
	push	eax		; GETBUF:  # bytes to allocate in buffer

	lods	JMPTAB33[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

	assume	es:DGROUP	; Tell the assembler about it
INT33_DPMI_EXIT:
	cli			; Disable interrupts to avoid HW interrupt
				; after POPAD looking like a VM interrupt
	pop	LPMSTK_FVEC.FOFF ; Restore
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	popad			; Restore all EGP registers

	add	esp,size INTXX_ERR ; Strip off pseudo-error code

	iretd			; Return to caller (PM only)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT33_DPMI endp 		; End INT33_DPMI procedure
	NPPROC	DPMI_PDBI -- PDBI Mouse Event Interrupt Handler
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

PDBI Mouse event interrupt handler

On entry (in registers):

SS:EBP	==>	INTXX_STR

|

	mov	ecx,4		; Set # words to copy from the VM
				; stack to DPMI client's PL3 stack
	jmp	short DPMI_MEI_NXT ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_PDBI endp			; End DPMI_PDBI procedure
	NPPROC	DPMI_MEI -- Mouse Event Interrupt Handler
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Mouse event interrupt handler

On entry (in registers):

SS:EBP	==>	INTXX_STR

|

	xor	ecx,ecx 	; Set # words to copy from the VM
				; stack to DPMI client's PL3 stack
DPMI_MEI_NXT:
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	push	OLD_PCURTSS	; Save previous value in case we need
				; ...to restore it upon exit
	push	DGROUP:[eax].TSS_SS0  ; Save old stack selector
	push	DGROUP:[eax].TSS_ESP0 ; Save old pointer to stack top

;;;;;;; PUSHD	-1		; Make room for MEI_PL0LEN
;;;;;;;
	push	LAST_INTCOM	; Save old LAST_INTCOM
	push	LAST_INTFLG	; ...and its flag
	push	LPMSTK_FVEC.FSEL.EDD ; Save current LPM stack offset
	push	LPMSTK_FVEC.FOFF ; ...

MEI_STR struc

MEI_LPMSTK df	?		; LPMSTK_FVEC
	dw	?		; For alignment
MEI_LIFLG dd	?		; LAST_INTFLG
MEI_LICOM dd	?		; LAST_INTCOM
;;;MEI_PL0LEN dd   ?		   ; Length of stack to protect
MEI_ESP0 dd	?		; TSS_ESP0
MEI_SS0 dw	?		; TSS_SS0
MEI_OPCURTSS dd ?		; OLD_PCURTSS
	db	(type INTXX_STR) dup (?) ; The rest of the stack

MEI_STR ends

; SS:ESP ==> MEI_STR

; * Save SS:ESP as new top of stack pointer

	mov	DGROUP:[eax].TSS_SS0,ss ; Save for next time
	mov	DGROUP:[eax].TSS_ESP0,esp ; ...

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

; Set new LPM stack top for nested callers if it's active
; and we're called from PM, not PL0

	lea	eax,[ebp].INTXX_EIP ; SS:EAX ==> INTDPI_STR from PL3
	push	eax		; Pass the offset
	call	DPMIFN_LPMSTK	; Save new LPM stack as appropriate

	lfs	ebx,LPMSTK_FVEC ; ES:EBX ==> special stack used by faults
	assume	fs:nothing	; Tell the assembler about it

	inc	LPMSTK_CNT	; Count in another one

; Copy parameters from the VM stack to the DPMI client's PL3 stack
; if we entered from DPMI_PDBI

	jecxz	DPMI_MEI_XPARM	; Jump if parameters to copy

	movzx	eax,[ebp].INTXX_SS ; Get VM stack segment
	shl	eax,4-0 	; Convert from paras to bytes
	movzx	edx,[ebp].INTXX_ESP.ELO ; Get VM stack pointer
	add	eax,edx    ; Plus VM stack pointer
COMMENT|

The VM stack at this point (AGROUP:EAX) contains from the bottom up

CS:IP	 16-bit far return to caller
Parms	 four word parameters

|

;;;;;;; add	eax,4-2 	; Skip over far return, back off to last word
				; instead this addition is done in the EA calc
DPMI_MEI_NEXTPARAM:
	mov	dx,AGROUP:[eax+ecx*2+2] ; Get the next word
	sub	ebx,2		; Make room for it
if @EXPD

; If this is a 16-bit stack, zero the high-order word of EBX
; to simulate using BX instead of EBX.

	push	fs		; Pass stack selector
	call	DPMIFN_EBXMOD	; Modify high-order word of EBX
				; if stack selector is a 16-bit stack
; Check to see if the resulting offset is within the stack's bounds

	push	fs		; Pass stack selector
	push	ebx		; ...	     offset
	call	DPMIFN_CHKSTK	; Check the stack offset
endif
	jc	near ptr DPMI_MEI_LPMFULL ; Jump if we overflowed

	mov	fs:[ebx],dx	; Save on PL3 stack

	loop	DPMI_MEI_NEXTPARAM ; Jump if more parameters to copy
DPMI_MEI_XPARM:

; Pass our return address onto the LPM stack
; for the callback procedure to RETF/D

DPMI_MEI16_STR struc

DPMI_MEI16_RIP dw ?		; Our return IP
DPMI_MEI16_RCS dw ?		; ...	     CS

DPMI_MEI16_STR ends


DPMI_MEI32_STR struc

DPMI_MEI32_REIP dd ?		; Our return EIP
DPMI_MEI32_RCS dw ?,?		; ...	     CS w/filler

DPMI_MEI32_STR ends

	mov	ax,DPMI_IDEF	; Get our interrupt selector

	cmp	DPMITYPEIG,@DPMITYPE16 ; Izit a 16-bit client?
	je	short DPMI_MEI16 ; Jump if so

	sub	ebx,size DPMI_MEI32_STR ; Make room on LPM stack
if @EXPD

; If this is a 16-bit stack, zero the high-order word of EBX
; to simulate using BX instead of EBX.

	push	fs		; Pass stack selector
	call	DPMIFN_EBXMOD	; Modify high-order word of EBX
				; if stack selector is a 16-bit stack
; Check to see if the resulting offset is within the stack's bounds

	push	fs		; Pass stack selector
	push	ebx		; ...	     offset
	call	DPMIFN_CHKSTK	; Check the stack offset
endif
	jc	near ptr DPMI_MEI_LPMFULL ; Jump if we overflowed

	mov	fs:[ebx].DPMI_MEI32_REIP,PMMEI ; Return EIP
	mov	fs:[ebx].DPMI_MEI32_RCS,ax	; ...	CS

	jmp	short DPMI_MEI_COM ; Join common code


DPMI_MEI16:
	sub	ebx,size DPMI_MEI16_STR ; Make room on LPM stack
if @EXPD

; If this is a 16-bit stack, zero the high-order word of EBX
; to simulate using BX instead of EBX.

	push	fs		; Pass stack selector
	call	DPMIFN_EBXMOD	; Modify high-order word of EBX
				; if stack selector is a 16-bit stack
; Check to see if the resulting offset is within the stack's bounds

	push	fs		; Pass stack selector
	push	ebx		; ...	     offset
	call	DPMIFN_CHKSTK	; Check the stack offset
endif
	jc	near ptr DPMI_MEI_LPMFULL ; Jump if we overflowed

	mov	fs:[ebx].DPMI_MEI16_RIP,PMMEI ; Return IP
	mov	fs:[ebx].DPMI_MEI16_RCS,ax    ; ...    CS
DPMI_MEI_COM:

;;; ; Protect the PL0 stack at and above MEI_STR by
;;; ; copying it to PLCL_PL0CUR
;;;
;;;	    SETDATA es		    ; Get DGROUP data selector
;;;	    assume  es:DGROUP	    ; Tell the assembler about it
;;;
;;;	    mov     esi,esp	    ; Copy as source
;;;	    mov     ecx,PPL0STK_MAX ; Get top of PL0 stack
;;;	    sub     ecx,esi	    ; Less source offset
;;;	    mov     [esp].MEI_PL0LEN,ecx ; Save for later use
;;;
;;;	    sub     PLCL_PL0CUR,ecx ; Less length to make room
;;;	    mov     edi,PLCL_PL0CUR ; Get offset in DGROUP of current local PL0 stack
;;;	    mov     DGROUP:[edi-4],ecx ; Save as length of saved stack
;;;	    sub     PLCL_PL0CUR,4   ; Protect it
;;;
;;;	    lea     eax,[ecx+esi]   ; Add to get ending source address
;;;
;;;	    cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	    jbe     short @F	    ; Jump if not
;;;
;;;	    SWATMAC ERR 	    ; Call our debugger
;;; @@:
;;;	    cld 		    ; String ops fowardly
;;; S32 rep movs    <DGROUP:[edi].LO,ss:[esi].LO> ; Copy to local storage

; Put the address (SSF, ESP, EFL, EIP, CSF) to which we're
; transferring on our PL0 stack

	PUSHD	fs		; Pass SS w/filler
	push	ebx		; Pass ESP
	push	[ebp].INTXX_EFL ; Pass EFL
	and	[esp].EDD,not ((mask $VMHI) or (mask $RFHI) \
			     or (mask $IOPL) or (mask $TF)) ; VM=RF=IOPL=TF=0
	or	[esp].EDD,@DPMIOPL shl $IOPL ; IOPL=@DPMIOPL

	mov	ebx,PCURTSS	; Get offset in DGROUP of current TSS

	push	DGROUP:[ebx].DPTSS_MEI_FVEC.FSEL.EDD ; Pass selector w/filler
	push	DGROUP:[ebx].DPTSS_MEI_FVEC.FOFF     ; Pass offset

	mov	eax,[ebp].INTXX_EAX ; Restore caller's EAX
	mov	ebx,[ebp].INTXX_EBX ; ...		EBX
	mov	ecx,[ebp].INTXX_ECX ; ...		ECX
	mov	edx,[ebp].INTXX_EDX ; ...		EDX
	mov	esi,[ebp].INTXX_ESI ; ...		ESI
	mov	edi,[ebp].INTXX_EDI ; ...		EDI
	mov	ebp,[ebp].INTXX_EBP ; ...		EBP

; If this is a program which doesn't lock its Mouse handler pages,
; we're inside DOS, and swapping is active, ignore this call.

	test	I31_FLAG,mask $I31_XMEI ; Izit one to worry about?
	jz	short DPMI_MEI_XDOS ; Jump if not

	test	VMM_FLAG,@VMM_BSPRES ; Is swapping active?
	jz	short DPMI_MEI_XDOS ; Jump if not

	cmp	PageFaultActive,0 ; Are we processing a page fault?
	jne	near ptr DPMI_MEIRET ; Jump if so

	push	eax		; Save for a moment

	mov	eax,LaINDOS	; AGROUP:EAX ==> InDOS flag

	cmp	AGROUP:[eax].LO,0 ; Are we inside DOS?
	pop	eax		; Restore
	jne	near ptr DPMI_MEIRET ; Jump if so
DPMI_MEI_XDOS:
	REGSAVE <LAST_DPMI_DS.EDD,LAST_DPMI_ES.EDD, \
		  LAST_DPMI_FS.EDD,LAST_DPMI_GS.EDD> ; Get previous values
	VERREST <gs,fs,es,ds>	; Restore selectors with VERR
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; Tell the assembler about it

	iretd			; Continue with the callback procedure (PM only)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing


	public	DPMI_MEI_LPMFULL
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:AGROUP,ss:nothing
DPMI_MEI_LPMFULL:

; We overflowed the LPM stack:	strip back to the original INTDPI_STR
; and exit to common error code

	pop	LPMSTK_FVEC.FOFF ; De-allocate it
	pop	LPMSTK_FVEC.FSEL.EDD ; ...
	dec	LPMSTK_CNT	; Count it out

	pop	LAST_INTFLG	; Restore
	pop	LAST_INTCOM	; Restore

;;;;;;; add	esp,type MEI_PL0LEN ; Strip MEI_PL0LEN
;;;;;;;
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	pop	DGROUP:[eax].TSS_ESP0 ; Restore
	pop	DGROUP:[eax].TSS_SS0  ; ...

; Restore PCURTSS

	pop	PCURTSS 	; Restore

; * Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

	popad			; Restore all EGP registers

; The MAX stack contains INTDPF_STR

	jmp	FLTPROC_LPMFULL ; Join common error code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_MEI endp			; End DPMI_MEI procedure
	NPPROC	DPMI_MEIRET -- Return From Mouse Event Interrupt Procedure
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Return from mouse event interrupt procedure

On entry:

IF	=	0
SS:EBP	==>	INTDPI_STR (discarded) followed by MEI_STR

|

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	push	PVMTSS		; Pass offset in DGROUP of the 1st TSS
	call	DPMIFN_LMSW	; Put MSW and INT 07h values into effect

; Restore MEI_STR

	add	esp,size INTDPI_STR ; Discard the client's return frame

;;; ; Restore the original PL0 stack from PLCL_PL0CUR
;;;
;;;	    mov     SAVE_ECX,ecx    ; Save to use as scratch
;;;	    mov     SAVE_ESI,esi    ; ...
;;;	    mov     SAVE_EDI,edi    ; ...
;;;
;;;	    mov     cx,ss	    ; Get stack selector
;;;	    mov     es,cx	    ; Address it
;;;	    assume  es:nothing	    ; Tell the assembler about it
;;;
;;;	    mov     esi,PLCL_PL0CUR ; Get offset in DGROUP of current local stack
;;;	    lods    DGROUP:[esi].EDD ; Get and skip over length of saved stack
;;;	    mov     ecx,eax	    ; Copy to count register
;;;	    jecxz   DPMI_MEIRET_DMS ; Jump if we're at the deadman's switch
;;;	    sub     esp,ecx	    ; Back off to start
;;;	    mov     edi,esp	    ; Copy as destin
;;;
;;;	    lea     eax,[ecx+edi]   ; Add to get ending destin address
;;;
;;;	    cmp     eax,PPL0STK_MAX ; Izit out of range?
;;;	    jbe     short @F	    ; Jump if not
;;;
;;;	    SWATMAC ERR 	    ; Call our debugger
;;; @@:
;;;	    cld 		    ; String ops fowardly
;;; S32 rep movs    <es:[edi].LO,DGROUP:[esi].LO> ; Copy the stack down
;;;	    mov     PLCL_PL0CUR,esi ; Strip from storage
;;; DPMI_MEIRET_DMS:
;;;	    mov     ecx,SAVE_ECX    ; Restore
;;;	    mov     esi,SAVE_ESI    ; ...
;;;	    mov     edi,SAVE_EDI    ; ...

	pop	LPMSTK_FVEC.FOFF ; De-allocate it
	pop	LPMSTK_FVEC.FSEL.EDD ; ...
	dec	LPMSTK_CNT	; Count it out

	pop	LAST_INTFLG	; Restore
	pop	LAST_INTCOM	; Restore

;;;;;;; add	esp,type MEI_PL0LEN ; Strip MEI_PL0LEN
;;;;;;;
	mov	SAVE_EAX,eax	; Save for a moment
	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS

	pop	DGROUP:[eax].TSS_ESP0 ; Restore
	pop	DGROUP:[eax].TSS_SS0  ; ...

; Restore PCURTSS

	pop	PCURTSS 	; Restore

; Check for return from nesting

	call	DPMIFN_NESTRET	; Check for nesting return with EAX=old PCURTSS
	assume	es:nothing,fs:nothing,gs:nothing ; Tell the assembler about it

; * Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

; Note that we may have switched to a new LDT
; so some selectors may have been set to zero

	mov	eax,SAVE_EAX	; Restore original value

; The stack is mapped by the original INTXX_STR which we use for the IRETD to VM

	mov	[esp].INTXX_EAX,eax ; Return caller's EAX
	mov	[esp].INTXX_EBX,ebx ; ...	       EBX
	mov	[esp].INTXX_ECX,ecx ; ...	       ECX
	mov	[esp].INTXX_EDX,edx ; ...	       EDX
	mov	[esp].INTXX_ESI,esi ; ...	       ESI
	mov	[esp].INTXX_EDI,edi ; ...	       EDI
	mov	[esp].INTXX_EBP,ebp ; ...	       EBP

	popad			; Restore all EGP registers

	add	esp,size INTXX_ERR ; Strip off pseudo-error code

	jmp	ERM_FVEC	; Return to RM/VCPI

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_MEIRET endp		; End DPMI_MEIRET procedure
	NPPROC	DPMIFN_RESTMEI -- Restore Mouse Event Interrupt
	assume	ds:nothing,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Restore mouse event interrupt

|

	pushad			; Save all EGP registers

	mov	edx,PCURTSS	; Get offset in DGROUP of current TSS

	cmp	DGROUP:[edx].DPTSS_MEI_ORIG_VEC,0 ; Izit valid?
	je	short INT33_DPMI_RESTMEI_EXIT ; Jump if not

	lea	esi,INT33_DPMIJMP_RESTMEI ; ES:ESI ==> action stream
	lods	JMPTAB33[esi]	; Get next action
	jmp	eax		; Take appropriate action


INT33_DPMI_RESTMEI:
	mov	VMCREGS.VMC_EAX.ELO,000Ch ; Mark as Hook Mouse Event Interrupt

	mov	ax,DGROUP:[edx].DPTSS_MEI_ORIG_MASK ; Get original mask value
	mov	VMCREGS.VMC_ECX.ELO,ax ; Pass as call mask in CX

	mov	eax,DGROUP:[edx].DPTSS_MEI_ORIG_VEC ; Get original address
	mov	VMCREGS.VMC_EDX.ELO,ax ; Pass as offset in DX
	shr	eax,16		; Shift down segment high order word
	mov	VMCREGS.VMC_ES,ax ; Pass as segment in ES

	lods	JMPTAB33[esi]	; Get next action
	jmp	eax		; Take appropriate action


INT33_DPMI_RESTMEI_EXIT:
	popad			; Restore all EGP registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_RESTMEI endp		; End DPMIFN_RESTMEI procedure

PROG	ends			; End PROG segment

	MEND			; End DPMI_D33 module
