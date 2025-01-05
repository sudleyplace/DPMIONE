;' $Header$
	title	DPMI_D4B -- DPMI.LOD DPMI INT 4Bh Translation Services
	page	58,122
	name	DPMI_D4B
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
	include CPUFLAGS.INC
	include VDS.INC
	include ALLMEM.INC
	include BITFLAGS.INC

	include QMAX_I31.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_SEG.INC
.list

CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
	assume	cs:PGROUP

	extrn	INTPROC00Z:near

CODE16A ends			; End CODE16A segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	extrn	DPMI_CPIHOOK:byte
	extrn	LPMSTK_FVEC:fword
	extrn	DPMITYPE:byte
	extrn	SEL_4GB:word

DATA	ends			; End DATA segment


; Define VDS INT 4Bh functions which we handle

DPMIVDSMAC macro VAL,ACT

ACTSEG	segment use32 dword public 'data' ; Start ACTSEG segment
	assume	ds:DGROUP

	org	DPMIVDS_ACT + VAL * (type DPMIVDS_ACT) ; Set to appropriate origin
	dd	offset DGROUP:INT4B_DPMIJMP_&ACT
	org	DPMIVDS_ACTZ  ; Restore to end of the table

ACTSEG	ends			; End ACTSEG segment

	endm			; DPMIVDSMAC


ACTSEG	segment use32 dword public 'data' ; Start ACTSEG segment
	assume	ds:DGROUP

	public	@DPMI_D4B_ACTSEG
@DPMI_D4B_ACTSEG label byte	; Mark module start in .MAP file

	public	DPMIVDS_ACT
DPMIVDS_ACT dd	256 dup (offset DGROUP:INT4B_DPMIJMP_PASSTHRU) ; Seed with pass through action
DPMIVDS_ACTZ label dword

ACTSEG	ends			; End ACTSEG segment


; The following VDS functions require special treatment

.sall
	DPMIVDSMAC @VDS_LOCK,LOCK	; 03:  Lock DMA region
	DPMIVDSMAC @VDS_UNLK,UNLK	; 04:  Unlock DMA region
	DPMIVDSMAC @VDS_SLOCK,SLOCK	; 05:  Scatter/gather lock DMA region
	DPMIVDSMAC @VDS_SUNLK,SUNLK	; 06:  Scatter/gather unlock DMA region
	DPMIVDSMAC @VDS_GETBUF,GETBUF	; 07:  Get DMA buffer
	DPMIVDSMAC @VDS_RELBUF,RELBUF	; 08:  Release DMA buffer
;;;;;;; DPMIVDSMAC @VDS_MEM2BUF,MEM2BUF ; 09:  Memory to DMA buffer
;;;;;;; DPMIVDSMAC @VDS_BUF2MEM,BUF2MEM ; 0A:  DMA to Memory buffer
.lall


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_D4B_DATA
@DPMI_D4B_DATA	label byte	; Mark module start in .MAP file

DLBL	macro	LBL
INT4B_DPMIJMP_&LBL label dword
	endm			; DLBL


ACT	macro	LBL
	dd	offset PGROUP:INT4B_DPMI_&LBL
	endm			; ACT


DOSFN	macro	LBL,ARGS
	dd	offset PGROUP:DOSFN_&LBL
ifnb <ARGS>
	dd	ARGS
endif				; IFNB
	endm			; DOSFN


DJMP	macro	LBL
	dd	offset PGROUP:DOSFN_JMP
	dd	offset DGROUP:INT4B_DPMIJMP_&LBL
	endm


	public	JMPTAB4B
JMPTAB4B label	dword
.sall
	DLBL	LOCK		; 03:  Lock DMA region specified by ES:eDI and DX
	DLBL	UNLK		; 04:  Unlock DMA region specified by ES:eDI and DX
	DOSFN	SAVE_INTXXREG,<INTXX_EDI>
	DOSFN	SAVE_VMCREGS
	ACT	LOCK_UNLK
	DOSFN	GETBUF,<VMC_EDI.ELO,VMC_ES,INTXX_EDI,I31_ES-@I31BACK>
	DOSFN	SIMVMI,4Bh
	DOSFN	LOW2EXT,<INTXX_EDI,I31_ES-@I31BACK>
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDI>
	ACT	EXIT


	DLBL	SLOCK		; 05:  Scatter/gather lock DMA region specified by ES:eDI and DX
	DLBL	SUNLK		; 06:  Scatter/gather unlock DMA region specified by ES:eDI and DX
	DOSFN	SAVE_INTXXREG,<INTXX_EDI>
	DOSFN	SAVE_VMCREGS
	ACT	SLOCK_SUNLK
	DOSFN	GETBUF,<VMC_EDI.ELO,VMC_ES,INTXX_EDI,I31_ES-@I31BACK>
	DOSFN	SIMVMI,4Bh
	DOSFN	LOW2EXT,<INTXX_EDI,I31_ES-@I31BACK>
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDI>
	ACT	EXIT


	DLBL	GETBUF		; 07:  Request DMA buffer
	DLBL	RELBUF		; 08:  Release DMA buffer
	DOSFN	SAVE_INTXXREG,<INTXX_EDI>
	DOSFN	SAVE_VMCREGS
	ACT	GETBUF_RELBUF
	DOSFN	GETBUF,<VMC_EDI.ELO,VMC_ES,INTXX_EDI,I31_ES-@I31BACK>
	DOSFN	SIMVMI,4Bh
	DOSFN	LOW2EXT,<INTXX_EDI,I31_ES-@I31BACK>
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDI>
	ACT	EXIT


	DLBL	PASSTHRU	; Pass through label for all other functions
	DOSFN	SAVE_VMCREGS
	DLBL	SIMVMI
	DOSFN	SIMVMI,4Bh
	DOSFN	REST_VMCREGS
	ACT	EXIT
.lall

DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_D4B_PROG
@DPMI_D4B_PROG: 		; Mark module start in .MAP file

	extrn	PMINTCOM:near
	extrn	DOSFN_SAVE_INTXXREG:near
	extrn	DOSFN_SAVE_VMCREGS:near
	extrn	DOSFN_GETBUF:near
	extrn	DOSFN_SIMVMI:near
	extrn	DOSFN_LOW2EXT:near
	extrn	DOSFN_REST_VMCREGS:near
	extrn	DOSFN_REST_INTXXREG:near
	extrn	DPMIFN_LPMSTK:near
	extrn	GETBASE:near

	FPPROC	INT4B_DPMI -- VDS Calls from DPMI Clients
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

VDS calls from DPMI clients

On entry:

AX	=	function #

|

; If the caller is at PL0, don't pass on to any DPMI clients

	test	[esp].INTDPI_CS,mask $PL ; Izit at PL0?
	jz	short INT4B_INTRETPM ; Jump if so

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_CPIHOOK[4Bh/8],1 shl (4Bh mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT4B_INTRETPM ; Jump if not

	mov	[esp].INTCOM_INTNO,4*4Bh + offset PGROUP:INTPROC00Z

	push	@PMINTCOM_NRM	; Use application stack
	jmp	near ptr PMINTCOM ; Jump to common code


; We're back to handle it ourselves

	public	INT4B_INTRETPM
INT4B_INTRETPM:
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

	movzx	eax,[ebp].INTXX_EAX.ELO ; Copy function code (81xx)

	cmp	ah,@VDS_MAJOR	; Ensure major function code matches
	lea	esi,INT4B_DPMIJMP_PASSTHRU ; Jump if not
	jne	short @F	; Jump if not

	mov	ah,0		; Clear major function code to use just
				; the value in AL as a table index
	mov	esi,DPMIVDS_ACT[eax*(type DPMIVDS_ACT)] ; ES:ESI ==> action stream
@@:
	lods	JMPTAB4B[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 03:  Lock DMA region specified by ES:eDI and DX
; 04:  Unlock DMA region specified by ES:eDI and DX

; On entry (in PL3 stack):
; ES:eDI ==>	DDS buffer
; DX	 =	flags

; On entry (in registers):
; ES:ESI ==>	action stream
; ES	 =	DGROUP
; SS:EBP ==>	INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT4B_DPMI_LOCK_UNLK:
	mov	eax,size DDS_STR ; Get size of DDS buffer

	push	eax		; LOW2EXT:  # bytes to release in buffer
	push	eax		; LOW2EXT:  # trailing bytes to copy
	push	eax		; GETBUF:   # leading bytes to copy
	push	eax		; GETBUF:   # bytes to allocate in buffer

	lods	JMPTAB4B[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 05:  Scatter/gather lock DMA region specified by ES:eDI and DX
; 06:  Scatter/gather unlock DMA region specified by ES:eDI and DX

; On entry (in PL3 stack):
; ES:eDI ==>	XDDS buffer
; DX	 =	flags

; On entry (in registers):
; ES:ESI ==>	action stream
; ES	 =	DGROUP
; SS:EBP ==>	INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT4B_DPMI_SLOCK_SUNLK:

; Get the linear address of the XDDS_STR

	push	[ebp].INTXX_ES.EDD ; Pass the selector (as dword)
	call	GETBASE 	; Return with EAX = base address

	mov	ebx,[ebp].INTXX_EDI ; Get offset to XDDS_STR
	IF16ZX	bx		; Zero to use as dword if 16-bit client

	add	ebx,eax 	; Add to get linear address of XDDS_STR

	push	ds		; Save for a moment

	mov	ds,SEL_4GB	; Get AGROUP data selector
	assume	ds:AGROUP	; Tell the assembler about it

	movzx	eax,AGROUP:[ebx].XDDS_AVL ; Get # available entries

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

; Split cases based upon bit 6 of caller's DX

	test	[ebp].INTXX_EDX.ELO,@BIT6 ; Which kind?
	jz	short INT4B_DPMI_SLOCK_REG ; Jump if RDDS_STR

; If option bit 6 in DX is set, the buffer size is
; (size XDDS_STR) - (size XDDS_DATA) + XDDS_AVL * (size PDDS_STR).

	imul	eax,size PDDS_STR ; Times size of an entry

	jmp	short INT4B_DPMI_SLOCK_COM ; Join common code


; If option bit 6 in DX is clear, the buffer size is
; (size XDDS_STR) - (size XDDS_DATA) + XDDS_AVL * (size RDDS_STR).

INT4B_DPMI_SLOCK_REG:
	imul	eax,size RDDS_STR ; Times size of an entry
INT4B_DPMI_SLOCK_COM:
	add	eax,(size XDDS_STR) - (size XDDS_DATA) ; Plus size of XDDS buffer

	push	eax		; LOW2EXT:  # bytes to release in buffer
	push	eax		; LOW2EXT:  # trailing bytes to copy
	push	eax		; GETBUF:   # leading bytes to copy
	push	eax		; GETBUF:   # bytes to allocate in buffer

	lods	JMPTAB4B[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 07:  Request DMA buffer
; 08:  Release DMA buffer

; On entry (in PL3 stack):
; ES:eDI ==>	DDS buffer
; DX	 =	flags

; On entry (in registers):
; ES:ESI ==>	action stream
; ES	 =	DGROUP
; SS:EBP ==>	INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT4B_DPMI_GETBUF_RELBUF:
	mov	eax,size DDS_STR ; Get size of DDS buffer

	push	eax		; LOW2EXT:  # bytes to release in buffer
	push	eax		; LOW2EXT:  # trailing bytes to copy
	push	eax		; GETBUF:   # leading bytes to copy
	push	eax		; GETBUF:   # bytes to allocate in buffer

	lods	JMPTAB4B[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

	assume	es:DGROUP	; Tell the assembler about it
INT4B_DPMI_EXIT:
	pop	LPMSTK_FVEC.FOFF ; Restore
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

	cli			; Disable interrupts to avoid HW interrupt
				; after POPAD looking like a VM interrupt
	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	popad			; Restore all EGP registers

	add	esp,size INTXX_ERR ; Strip off pseudo-error code

	iretd			; Return to caller (PM only)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT4B_DPMI endp 		; End INT4B_DPMI procedure

PROG	ends			; End PROG segment

	MEND			; End DPMI_D4B module
