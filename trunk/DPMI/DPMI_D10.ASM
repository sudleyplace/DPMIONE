;' $Header$
	title	DPMI_D10 -- DPMI.LOD DPMI INT 10h Translation Services
	page	58,122
	name	DPMI_D10
COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1991-2002 Qualitas, Inc.  All Rights Reserved.

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include PTR.INC
	include VIDCALL.INC
	include DPMI.INC
	include CPUFLAGS.INC

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

DATA	ends			; End DATA segment


; Define Video INT 10h functions which we handle

DPMIVIDMAC macro VAL,ACT

ACTSEG	segment use32 dword public 'data' ; Start ACTSEG segment
	assume	ds:DGROUP

	org	DPMIVID_ACT + VAL * (type DPMIVID_ACT) ; Set to appropriate origin
	dd	offset DGROUP:INT10_DPMIJMP_&ACT
	org	DPMIVID_ACTZ  ; Restore to end of the table

ACTSEG	ends			; End ACTSEG segment

	endm			; DPMIVIDMAC


ACTSEG	segment use32 dword public 'data' ; Start ACTSEG segment
	assume	ds:DGROUP

	public	@DPMI_D10_ACTSEG
@DPMI_D10_ACTSEG label byte	; Mark module start in .MAP file

	public	DPMIVID_ACT
DPMIVID_ACT dd	256 dup (offset DGROUP:INT10_DPMIJMP_PASSTHRU) ; Seed with pass through action
DPMIVID_ACTZ label dword

ACTSEG	ends			; End ACTSEG segment


; The following Video functions require special treatment

.sall
	DPMIVIDMAC @SETPA2,SETPA2	; 10:  Set EGA pallette registers
	DPMIVIDMAC @SETCG, SETCG	; 11:  Set EGA character generator
	DPMIVIDMAC @GETEGA,GETEGA	; 12:  Alternate Selector (Get EGA Information)
	DPMIVIDMAC @SETSTR,SETSTR	; 13:  Write string at ES:eBP length CX at (DH,DL) in page BH, type AL
;;;;;;; DPMIVIDMAC 1Bh,   ,GETFSI	; 1B:  Get Functionality/State Information
;;;;;;; DPMIVIDMAC 1Ch,   ,SRVSTATE	; 1C:  Save/Restore Video State
.lall


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_D10_DATA
@DPMI_D10_DATA	label byte	; Mark module start in .MAP file

DLBL	macro	LBL
INT10_DPMIJMP_&LBL label dword
	endm			; DLBL


ACT	macro	LBL
	dd	offset PGROUP:INT10_DPMI_&LBL
	endm			; ACT


DOSFN	macro	LBL,ARGS
	dd	offset PGROUP:DOSFN_&LBL
ifnb <ARGS>
	dd	ARGS
endif				; IFNB
	endm			; DOSFN


DJMP	macro	LBL
	dd	offset PGROUP:DOSFN_JMP
	dd	offset DGROUP:INT10_DPMIJMP_&LBL
	endm


	public	JMPTAB10
JMPTAB10 label	dword
.sall
	DLBL	SETPA2		; 10:  Set EGA pallette registers
	ACT	SETPA2
	DJMP	PASSTHRU	; Used for non-special functions

	DLBL	SETPA2_F02	; 1002:  Set all pallette registers to ES:eDX
	DOSFN	SAVE_INTXXREG,<INTXX_EDX>
	DOSFN	SAVE_VMCREGS
	ACT	SETPA2_F02
	DOSFN	GETBUF,<VMC_EDX.ELO,VMC_ES,INTXX_EDX,I31_ES-@I31BACK>
	DOSFN	SIMVMI,10h
	DOSFN	RELBUF		; No need to copy back the pallette registers
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDX>
	ACT	EXIT

	DLBL	SETPA2_F09	; 1009:  Get all pallette registers into ES:eDX
	DOSFN	SAVE_INTXXREG,<INTXX_EDX>
	DOSFN	SAVE_VMCREGS
	ACT	SETPA2_F09
	DOSFN	GETBUF,<VMC_EDX.ELO,VMC_ES,INTXX_EDX,I31_ES-@I31BACK>
	DOSFN	SIMVMI,10h
	DOSFN	LOW2EXT,<INTXX_EDX,I31_ES-@I31BACK>
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDX>
	ACT	EXIT

	DLBL	SETPA2_F12	; 1012:  Set block of color registers to ES:eDX
	DOSFN	SAVE_INTXXREG,<INTXX_EDX>
	DOSFN	SAVE_VMCREGS
	ACT	SETPA2_F12
	DOSFN	GETBUF,<VMC_EDX.ELO,VMC_ES,INTXX_EDX,I31_ES-@I31BACK>
	DOSFN	SIMVMI,10h
	DOSFN	RELBUF		; No need to copy back the pallette registers
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDX>
	ACT	EXIT

	DLBL	SETPA2_F17	; 1017:  Get block of color registers into ES:eDX
	DOSFN	SAVE_INTXXREG,<INTXX_EDX>
	DOSFN	SAVE_VMCREGS
	ACT	SETPA2_F17
	DOSFN	GETBUF,<VMC_EDX.ELO,VMC_ES,INTXX_EDX,I31_ES-@I31BACK>
	DOSFN	SIMVMI,10h
	DOSFN	LOW2EXT,<INTXX_EDX,I31_ES-@I31BACK>
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDX>
	ACT	EXIT


	DLBL	SETCG		; 11:  Set EGA character generator
	ACT	SETCG
	DJMP	PASSTHRU	; Used for non-special functions

	DLBL	SETCG_F00	; 1100:  User Alpha Load
	DOSFN	SAVE_INTXXREG,<INTXX_EBP>
	DOSFN	SAVE_VMCREGS
	ACT	SETCG_F00
	DOSFN	GETBUF,<VMC_EBP.ELO,VMC_ES,INTXX_EBP,I31_ES-@I31BACK>
	DOSFN	SIMVMI,10h
	DOSFN	RELBUF		; No need to copy back the font table
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EBP>
	ACT	EXIT

	DLBL	SETCG_F30	; 1130:  Get Font Table Information into ES:eBP
	DOSFN	SAVE_VMCREGS
	DOSFN	SIMVMI,10h
	DOSFN	SEG2SEL,<@DATASEL,VMC_ES,I31_ES-@I31BACK>
	DOSFN	REST_VMCREGS
	ACT	EXIT


	DLBL	GETEGA		; 12:  Alternate Selector (Get EGA Information)
	ACT	GETEGA
	DJMP	PASSTHRU	; Used for non-special functions

	DLBL	GETEGA_F35	; 12xx:  BL=35:  Display Switch
	DOSFN	SAVE_INTXXREG,<INTXX_EDX>
	DOSFN	SAVE_VMCREGS
	ACT	GETEGA_F35
	DOSFN	GETBUF,<VMC_EDX.ELO,VMC_ES,INTXX_EDX,I31_ES-@I31BACK>
	DOSFN	SIMVMI,10h
	DOSFN	LOW2EXT,<INTXX_EDX,I31_ES-@I31BACK>
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EDX>
	ACT	EXIT


	DLBL	SETSTR		; 13:  Write string at ES:eBP length CX at (DH,DL) in page BH, type AL
	DOSFN	SAVE_INTXXREG,<INTXX_EBP>
	DOSFN	SAVE_VMCREGS
	ACT	SETSTR
	DOSFN	GETBUF,<VMC_EBP.ELO,VMC_ES,INTXX_EBP,I31_ES-@I31BACK>
	DOSFN	SIMVMI,10h
	DOSFN	RELBUF		; No need to copy back the string
	DOSFN	REST_VMCREGS
	DOSFN	REST_INTXXREG,<INTXX_EBP>
	ACT	EXIT


	DLBL	PASSTHRU	; Pass through label for all other functions
	DOSFN	SAVE_VMCREGS
	DLBL	SIMVMI
	DOSFN	SIMVMI,10h
	DOSFN	REST_VMCREGS
	ACT	EXIT
.lall

DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_D10_PROG
@DPMI_D10_PROG: 		; Mark module start in .MAP file

	extrn	PMINTCOM:near
	extrn	DOSFN_SAVE_INTXXREG:near
	extrn	DOSFN_SAVE_VMCREGS:near
	extrn	DOSFN_GETBUF:near
	extrn	DOSFN_SIMVMI:near
	extrn	DOSFN_LOW2EXT:near
	extrn	DOSFN_RELBUF:near
	extrn	DOSFN_REST_VMCREGS:near
	extrn	DOSFN_REST_INTXXREG:near
	extrn	DOSFN_SEG2SEL:near
	extrn	DOSFN_JMP:near
	extrn	DPMIFN_LPMSTK:near

	FPPROC	INT10_DPMI -- Video Calls from DPMI Clients
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Video calls from DPMI clients

On entry:

AH	=	function #

|

; If the caller is at PL0, don't pass on to any DPMI clients

	test	[esp].INTDPI_CS,mask $PL ; Izit at PL0?
	jz	short INT10_INTRETPM ; Jump if so

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_CPIHOOK[10h/8],1 shl (10h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT10_INTRETPM ; Jump if not

	mov	[esp].INTCOM_INTNO,4*10h + offset PGROUP:INTPROC00Z

	push	@PMINTCOM_NRM	; Use application stack
	jmp	near ptr PMINTCOM ; Jump to common code


; We're back to handle it ourselves

	public	INT10_INTRETPM
INT10_INTRETPM:
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

	movzx	eax,[ebp].INTXX_EAX.ELO.HI ; Copy function code
	mov	esi,DPMIVID_ACT[eax*(type DPMIVID_ACT)] ; ES:ESI ==> action stream

	lods	JMPTAB10[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 10:  Set EGA pallette registers

; On entry (in PL3 stack):
; AL	 =	 function code

; On entry (in registers):
; ES:ESI ==>	 action stream
; ES	 =	 DGROUP
; SS:EBP ==>	 INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT10_DPMI_SETPA2:
	mov	al,[ebp].INTXX_EAX.ELO.LO ; Get function code

	cmp	al,02h		; Izit Set All Pallette Registers?
	je	short INT10_DPMI_SETPA2_SAPR ; Jump if so

	cmp	al,09h		; Izit Get All Pallette Registers?
	je	short INT10_DPMI_SETPA2_GAPR ; Jump if so

	cmp	al,12h		; Izit Set Block of Color Registers?
	je	short INT10_DPMI_SETPA2_SBCR ; Jump if so

	cmp	al,17h		; Izit Get Block of Color Registers?
	je	short INT10_DPMI_SETPA2_GBCR ; Jump if so

; We don't treat the subfunction specially -- pass it on through

INT10_DPMI_SETPA2_PASSTHRU:
	lods	JMPTAB10[esi]	; Get next action
	jmp	eax		; Take appropriate action


INT10_DPMI_SETPA2_SAPR:
	lea	esi,INT10_DPMIJMP_SETPA2_F02 ; DS:ESI ==> action stream

	jmp	short INT10_DPMI_SETPA2_PASSTHRU ; Join common code


INT10_DPMI_SETPA2_GAPR:
	lea	esi,INT10_DPMIJMP_SETPA2_F09 ; DS:ESI ==> action stream

	jmp	short INT10_DPMI_SETPA2_PASSTHRU ; Join common code


INT10_DPMI_SETPA2_SBCR:
	lea	esi,INT10_DPMIJMP_SETPA2_F12 ; DS:ESI ==> action stream

	jmp	short INT10_DPMI_SETPA2_PASSTHRU ; Join common code


INT10_DPMI_SETPA2_GBCR:
	lea	esi,INT10_DPMIJMP_SETPA2_F17 ; DS:ESI ==> action stream

	jmp	short INT10_DPMI_SETPA2_PASSTHRU ; Join common code


INT10_DPMI_SETPA2_F02:
	mov	eax,17		; Get size of pallette register buffer

	push	eax		; RELBUF:  # bytes to release in buffer
	push	eax		; GETBUF:  # leading bytes to copy
	push	eax		; GETBUF:  # bytes to allocate in buffer

	jmp	short INT10_DPMI_SETPA2_PASSTHRU ; Join common code


INT10_DPMI_SETPA2_F09:
	mov	eax,17		; Get size of pallette register buffer

	push	eax		; LOW2EXT:  # bytes to release in buffer
	push	eax		; LOW2EXT:  # trailing bytes to copy
	PUSHD	0		; GETBUF:   # leading bytes to copy
	push	eax		; GETBUF:   # bytes to allocate in buffer

	jmp	short INT10_DPMI_SETPA2_PASSTHRU ; Join common code


INT10_DPMI_SETPA2_F12:
	movzx	eax,[ebp].INTXX_ECX.ELO ; Get # registers to write
	imul	eax,3		; Times three bytes per register
				; (red, green, blue)
	push	eax		; RELBUF:  # bytes to release in buffer
	push	eax		; GETBUF:  # leading bytes to copy
	push	eax		; GETBUF:  # bytes to allocate in buffer

	jmp	short INT10_DPMI_SETPA2_PASSTHRU ; Join common code


INT10_DPMI_SETPA2_F17:
	movzx	eax,[ebp].INTXX_ECX.ELO ; Get # registers to read
	imul	eax,3		; Times three bytes per register
				; (red, green, blue)
	push	eax		; LOW2EXT:  # bytes to release in buffer
	push	eax		; LOW2EXT:  # trailing bytes to copy
	PUSHD	0		; GETBUF:   # leading bytes to copy
	push	eax		; GETBUF:   # bytes to allocate in buffer

	jmp	short INT10_DPMI_SETPA2_PASSTHRU ; Join common code

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 11:  Set EGA character generator

; On entry (in PL3 stack):
; AL	 =	 function code

; On entry (in registers):
; ES:ESI ==>	 action stream
; ES	 =	 DGROUP
; SS:EBP ==>	 INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT10_DPMI_SETCG:
	mov	al,[ebp].INTXX_EAX.ELO.LO ; Get function code

	cmp	al,00h		; Izit User Alpha Load?
	je	short INT10_DPMI_SETCG_UAL ; Jump if so

	cmp	al,10h		; Izit User Alpha Load w/recalc?
	je	short INT10_DPMI_SETCG_UAL ; Jump if so

;;;;;;; cmp	al,20h		; Izit Set Interrupt 1Fh to ES:BP?
;;;;;;; je	short INT10_DPMI_SETCG_SI1F ; Jump if so
;;;;;;;
;;;;;;; cmp	al,21h		; Izit Set Interrupt 43h to ES:BP?
;;;;;;; je	short INT10_DPMI_SETCG_SI43 ; Jump if so
;;;;;;;
	cmp	al,30h		; Izit Get Font Table Information?
	je	short INT10_DPMI_SETCG_GFTI ; Jump if so

; We don't treat the subfunction specially -- pass it on through

INT10_DPMI_SETCG_PASSTHRU:
	lods	JMPTAB10[esi]	; Get next action
	jmp	eax		; Take appropriate action


INT10_DPMI_SETCG_UAL:
	lea	esi,INT10_DPMIJMP_SETCG_F00 ; ES:ESI ==> action stream

	jmp	short INT10_DPMI_SETCG_PASSTHRU ; Join common code


INT10_DPMI_SETCG_GFTI:
	lea	esi,INT10_DPMIJMP_SETCG_F30 ; ES:ESI ==> action stream

	jmp	short INT10_DPMI_SETCG_PASSTHRU ; Join common code


INT10_DPMI_SETCG_F00:
	movzx	eax,[ebp].INTXX_EBX.ELO.HI ; Get # bytes per character
	imul	ax,[ebp].INTXX_ECX.ELO ; Times # characters

	push	eax		; RELBUF:  # bytes to release in buffer
	push	eax		; GETBUF:  # leading bytes to copy
	push	eax		; GETBUF:  # bytes to allocate in buffer

	jmp	short INT10_DPMI_SETCG_PASSTHRU ; Join common code

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 12:  Alternate Select (Get EGA Information)

; On entry (in PL3 stack):
; BL	 =	 function code

; On entry (in registers):
; ES:ESI ==>	 action stream
; ES	 =	 DGROUP
; SS:EBP ==>	 INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT10_DPMI_GETEGA:
	mov	al,[ebp].INTXX_EBX.ELO.LO ; Get function code

	cmp	al,35h		; Izit Display Switch?
	je	short INT10_DPMI_GETEGA_DS ; Jump if so

; We don't treat the subfunction specially -- pass it on through

INT10_DPMI_GETEGA_PASSTHRU:
	lods	JMPTAB10[esi]	; Get next action
	jmp	eax		; Take appropriate action


INT10_DPMI_GETEGA_DS:
	mov	al,[ebp].INTXX_EAX.ELO.LO ; Get function code

	cmp	al,00h		; Izit Initial Adapter Off?
	je	short INT10_DPMI_GETEGA_DSBUF ; Jump if so

	cmp	al,02h		; Izit Switch off active video?
	je	short INT10_DPMI_GETEGA_DSBUF ; Jump if so

	cmp	al,03h		; Izit Switch on active video?
	je	short INT10_DPMI_GETEGA_DSBUF ; Jump if so

; We don't treat the subfunction specially -- pass it on through

INT10_DPMI_GETEGA_DS_PASSTHRU:
	lods	JMPTAB10[esi]	; Get next action
	jmp	eax		; Take appropriate action


INT10_DPMI_GETEGA_DSBUF:
	lea	esi,INT10_DPMIJMP_GETEGA_F35 ; ES:ESI ==> action stream

	jmp	short INT10_DPMI_GETEGA_PASSTHRU ; Join common code


INT10_DPMI_GETEGA_F35:
	mov	eax,128 	; Get size of save buffer

	push	eax		; LOW2EXT:  # bytes to release in buffer
	push	eax		; LOW2EXT:  # trailing bytes to copy
	push	eax		; GETBUF:   # leading bytes to copy
	push	eax		; GETBUF:   # bytes to allocate in buffer

	jmp	short INT10_DPMI_GETEGA_DS_PASSTHRU ; Join common code

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

; 13:  Write string at ES:BP length CX at (DH,DL) in page BH, type AL

; On entry (in PL3 stack):
; ES:BP  ==>	 string to display

; On entry (in registers):
; ES:ESI ==>	 action stream
; ES	 =	 DGROUP
; SS:EBP ==>	 INTXX_STR (nothing above INTXX_SS is valid)

	assume	es:DGROUP	; Tell the assembler about it
INT10_DPMI_SETSTR:
	movzx	eax,[ebp].INTXX_ECX.ELO ; Get character count

	cmp	[ebp].INTXX_EAX.ELO.LO,01h ; Izit char only?
	jbe	short @F	; Jump if so

	shl	eax,1-0 	; Convert from (Char,Attr) to bytes
@@:
	push	eax		; RELBUF:  # bytes to release in buffer
	push	eax		; GETBUF:  # leading bytes to copy
	push	eax		; GETBUF:  # bytes to allocate in buffer

	lods	JMPTAB10[esi]	; Get next action
	jmp	eax		; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

	assume	es:DGROUP	; Tell the assembler about it
INT10_DPMI_EXIT:
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

INT10_DPMI endp 		; End INT10_DPMI procedure

PROG	ends			; End PROG segment

	MEND			; End DPMI_D10 module
