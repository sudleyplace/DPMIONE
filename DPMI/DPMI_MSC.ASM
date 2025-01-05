;' $Header$
	title	DPMI_MSC -- DPMI.LOD Miscellaneous Routines
	page	58,122
	name	DPMI_MSC
COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1987-2003 Sudley Place Software.   

|
.386p
.xlist
	include MASM.INC
	include PTR.INC
	include 386.INC
	include ALLMEM.INC
	include BITFLAGS.INC

	include QMAX_TSS.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_SEG.INC
	include DPMI_SWT.INC
.list

CODE16	segment use32 byte public 'prog' ; Start CODE16 segment
	assume	ds:PGROUP

	extrn	NEWIMR1:byte
	extrn	NEWIMR2:byte

CODE16	ends			; End CODE16 segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_MSC_DATA
@DPMI_MSC_DATA	label byte	; Mark module start in .MAP file

	include DPMI_LCL.INC
	extrn	LCL_FLAG:word

	extrn	PCURTSS:dword
	extrn	SEL_4GB:word

	public	CON4KB,CON64KB,CON1MB,CON1P1MB
CON4KB	dd	00001000h	; Constant  4KB
CON64KB dd	00010000h	;	   64KB
CON1MB	dd	00100000h	;	    1MB
CON1P1MB dd	00110000h	;	  1.1MB

	public	DPMI_HWSP,DPMI_HW,DPMI_CPIHOOK,DPMI_CPFHOOK
	public	DPMI_PPIHOOK,DPMI_PVFHOOK,DPMI_CVFHOOK
DPMI_HWSP db	(256/8) dup (?) ; Bit map for HW/SP interrupts
DPMI_HW db	(256/8) dup (?) ; ...	      HW    ...

COMMENT|

The totality of exceptions (EX), software (SW), hardware (HW), and
special (1C/23/24) interrupts in VM/MAX/DPMI which may occur are as
follows:

Current Client		Primary Client		Not Presented To Any Client
---------------------------------------------------------------------------
23 VM			HW VM			SW VM
24 VM			EX VM
			1C VM
EX MAX			HW MAX			SW MAX
						1C MAX*
						23 MAX*
						24 MAX*
SW DPMI 		HW DPMI
EX DPMI
1C DPMI*
23 DPMI*
24 DPMI*

The above table comes from reading the DPMI 1.0 spec.  The distinction
between 1C (primary) and 23/24 (current) VM interrupts is not
specifically covered by the spec and it is our (Steve/Fred/Bob's)
interpretation.

* = does not (if in MAX) or should not (if in DPMI) occur.

|

DPMI_CPIHOOK db (256/8) dup (0) ; Bit map for any PM interrupts hooked by DPMI
				; current clients.
				; Test this for col #1 SW interrupts and special
				; (23/24) VM interrupts.
DPMI_PPIHOOK db (256/8) dup (0) ; Bit map for any PM interrupts hooked by DPMI
				; primary client.
				; Test this for col #2 HW interrupts and special
				; (1C) VM interrupts.
DPMI_CPFHOOK db (32/8) dup (0)	; Bit map for any PM faults hooked by DPMI
				; current clients.
				; Test this for col #1 exceptions.
DPMI_PVFHOOK db (32/8) dup (0)	; Bit map for any VM faults hooked by DPMI
				; primary client.
				; Test this for col #2 exceptions.
DPMI_CVFHOOK db (32/8) dup (0)	; Bit map for any VM faults hooked by DPMI
				; current client.  This variable is not tested
				; for any event.  It is used to hold the current
				; state which is copied to/from the old PM area
				; and when this client becomes the primary
				; client, it is copied to DPMI_PVFHOOK.
	public	MSG_APPLNAME_LEN
MSG_APPLNAME_LEN equ 78 	; Maximum length of last application
LENTXT2 MSG_APPLNAME,<MSG_APPLNAME_LEN dup (?)> ; Name of last application

DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP,ds:PGROUP

	public	@DPMI_MSC_PROG
@DPMI_MSC_PROG: 		; Mark module start in .MAP file

	public	HEXTABLE
HEXTABLE db	'0123456789ABCDEF' ; Binary to ASCII/hex translation table

	NPPROC	SET_HWSP -- Set DPMI_HWSP Values
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Set DPMI_HWSP bitmap values.  These bits are used in INTCOM to
check on hardware or special interrupts from VM or MAX which
must be reflected to DPMI clients in PM.

The special interrupt #s are 1Ch, 23h, 24h.
The hardware interrupts are anything from the master or slave PIC.

|

	REGSAVE <eax,ecx,edi,es> ; Save registers

	mov	ax,ds		; Get DGROUP data selector
	mov	es,ax		; Address it
	assume	es:DGROUP	; Tell the assembler about it

; Clear the maps

	mov	ecx,size DPMI_HWSP ; ECX = # bytes in DPMI_HWSP
	lea	edi,DPMI_HWSP	; ES:EDI ==> DPMI_HWSP
	xor	al,al		; A convenient zero
    rep stos	DPMI_HWSP[edi]	; Clear it

	mov	ecx,size DPMI_HW ; ECX = # bytes in DPMI_HW
	lea	edi,DPMI_HW	; ES:EDI ==> DPMI_HW
;;;;;;; xor	al,al		; A convenient zero
    rep stos	DPMI_HW[edi]	; Clear it

; Set the special values

; Note that we can't use BTS with immediate here as MASM 5.10 doesn't
; handle it correctly

	or	DPMI_HWSP[1Ch/8],1 shl (1Ch mod 8) ; Set the bit for INT 1Ch
	or	DPMI_HWSP[23h/8],1 shl (23h mod 8) ; ...	      INT 23h
	or	DPMI_HWSP[24h/8],1 shl (24h mod 8) ; ...	      INT 24h

	movzx	edi,NEWIMR1	; Get master PIC base (/8)
	shr	edi,3-0 	; Convert from bits to bytes
	mov	DPMI_HWSP[edi],0FFh ; Set all eight IRQs
	mov	DPMI_HW[edi],0FFh ; ...

	movzx	edi,NEWIMR2	; Get slave PIC base (/8)
	shr	edi,3-0 	; Convert from bits to bytes
	mov	DPMI_HWSP[edi],0FFh ; Set all eight IRQs
	mov	DPMI_HW[edi],0FFh ; ...

	REGREST <es,edi,ecx,eax> ; Restore
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SET_HWSP endp			; End SET_HWSP procedure
	NPPROC	SET_GDT -- Set Global Descriptor Table
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Set the global or local descriptor table to base EAX.

Note that this routine must execute in BOTH real and protected modes.

Also, because the LDT might not be addressable within 64KB
of the start of PGROUP, we can't use this routine to set an
LDT entry from real mode.

We can't afford to allow the GDT/LDT to be partially changed,
so we disable interrupts during changes.

On entry:

EAX	=	segment base

|

SET_GDT_STR struc

	dd	?		; Caller's EBP
	dd	?		; Caller's IP
SET_GDT_DTE dw	?		; DTE to set
SET_GDT_ARB db	?		; Access rights byte
SET_GDT_FLG db	?		; DTE flags
SET_GDT_LEN dd	?		; Segment length

SET_GDT_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <ebx,ecx,ds>	; Save registers

	pushfd			; Save flags
	cli			; Disallow interrupts

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	ecx,[ebp].SET_GDT_LEN ; Get segment length
	dec	ecx		; Convert from length to limit

	cmp	ecx,CON1MB	; Check against limit limit
	jb	short @F	; Jump if within range

	shr	ecx,12-0	; Convert from bytes to 4KB
	or	[ebp].SET_GDT_FLG,mask $DTE_G ; Set G-bit
@@:
	movzx	ebx,[ebp].SET_GDT_DTE ; Get the DTE to set
	and	ebx,not (mask $PL) ; Clear the PL bits

	btr	ebx,$TI 	; Check and reset the table index bit
	jnc	short SET_GDT1	; Jump if it's in the GDT

	push	eax		; Save for a moment

	mov	eax,PCURTSS	; Get offset in PGROUP of the current TSS
	add	ebx,DGROUP:[eax].DPTSS_LaLDT ; Plus linear address of DPMI LDT

	cmp	DGROUP:[eax].DPTSS_LaLDT,0 ; Izit valid?
	jne	short @F	; Jump if so

	SWATMAC ERR		; Call our debugger
@@:
	pop	eax		; Restore

	jmp	short SET_GDT2	; Join common code

	assume	ds:DGROUP	; Tell the assembler about it
SET_GDT1:

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	add	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> GDT
	add	esp,size DTR_STR ; Strip
SET_GDT2:
	mov	ds,SEL_4GB	; Get all memory data selector
	assume	ds:AGROUP	; Tell the assembler about it

	mov	AGROUP:[ebx].DESC_BASE01.EDD,eax
	rol	eax,8		; Rotate out the high-order byte
	mov	AGROUP:[ebx].DESC_BASE3,al ; Save as base byte #3
	ror	eax,8		; Rotate back
	mov	AGROUP:[ebx].DESC_SEGLM0,cx ; Save as data limit
	rol	ecx,16		; Swap high- and low-order words
	or	cl,[ebp].SET_GDT_FLG ; Include any flags
	mov	AGROUP:[ebx].DESC_SEGLM1,cl ; Save as data limit
;;;;;;; ror	ecx,16		; Swap back

; Set access rights byte

	mov	cl,[ebp].SET_GDT_ARB ; Get it
	mov	AGROUP:[ebx].DESC_ACCESS,cl ; Set it

	popfd			; Restore flags

	REGREST <ds,ecx,ebx>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	pop	ebp		; Restore

	ret	2+2+4		; Return to caller, popping arguments

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SET_GDT endp			; End SET_GDT procedure
	NPPROC	SET_CG -- Set GDT With Call Gate
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Set the global descriptor table with a call gate.

Note that this routine executes in real mode only.

|

SET_CG_STR struc

	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
SET_CG_DTE dw	?		; DTE to set
SET_CG_ARB db	?		; Access rights byte
SET_CG_CNT db	?		; Parameter count
SET_CG_FVEC df	?		; Code Sel:Off
	dw	?		; Padding

SET_CG_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ebx,es>	; Save registers

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	mov	eax,[esp].DTR_BASE ; ES:EAX ==> GDT
	add	esp,size DTR_STR ; Strip

	movzx	ebx,[ebp].SET_CG_DTE ; Get the DTE to set
	and	ebx,not (mask $PL) ; Clear the PL bits
	add	ebx,eax 	; AGROUP:EBX ==> GDT entry

; The code selector goes into BASE01

	mov	ax,[ebp].SET_CG_FVEC.FSEL ; Get it
	mov	AGROUP:[ebx].DESC_BASE01,ax ; Save it

; The offset goes into SEGLM0, SEGLM1, BASE3

	mov	eax,[ebp].SET_CG_FVEC.FOFF ; Get the offset
	mov	AGROUP:[ebx].DESC_SEGLM0,ax ; Save bytes 0-1
	shr	eax,16		; Shift down the high-order word
	mov	AGROUP:[ebx].DESC_SEGLM1,al ; Save byte 2
	mov	AGROUP:[ebx].DESC_BASE3,ah ; Save byte 3

; The parameter count goes into BASE2

	mov	al,[ebp].SET_CG_CNT ; Get it
	mov	AGROUP:[ebx].DESC_BASE2,al ; Save it

; The A/R word goes into ACCESS

	mov	al,[ebp].SET_CG_ARB ; Get it
	mov	AGROUP:[ebx].DESC_ACCESS,al ; Save it

	REGREST <es,ebx,eax>	; Restore
	assume	es:nothing	; Tell the assembler about it

	pop	ebp		; Restore

	ret	2+1+1+6+2	; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SET_CG	endp			; End SET_CG procedure
	NPPROC	GETBASE -- Get Selector Base
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Get selector base

On exit:

EAX	=	selector base address

|

GETBASE_STR struc

	dd	?	    ; Caller's EBP
	dd	?	    ; ...      EIP
GETBASE_SEL dw	?,?	    ; Selector to get base

GETBASE_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <ebx>		; Save register

	movzx	ebx,[ebp].GETBASE_SEL ; Copy selector to index register
	and	ebx,not (mask $PL) ; Clear the Privilege Level bits

	btr	ebx,$TI 	; Test and reset the Table Index bit
	jnc	short GETBASE_GDT ; Jump if it's in the GDT

	sldt	ax		; Get local LDT selector

	push	eax		; Pass the selector
	call	GETBASE 	; Return with EAX = base address

	add	ebx,eax 	; AGROUP:EBX ==> DTE

	jmp	short GETBASE_COM ; Join common code


GETBASE_GDT:

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	add	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> GDT
	add	esp,size DTR_STR ; Strip
GETBASE_COM:
	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	ds,SEL_4GB	; Get AGROUP data selector
	assume	ds:AGROUP	; Tell the assembler about it

	mov	eax,AGROUP:[ebx].DESC_BASE01.EDD ; Get bytes 0-2
	rol	eax,8		; Shift out
	mov	al,AGROUP:[ebx].DESC_BASE3 ; Get byte 3
	ror	eax,8		; Shift back

	pop	ds		; Restore

	REGREST <ebx>		; Restore

	pop	ebp		; Restore

	ret	4		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

GETBASE endp			; End GETBASE procedure
	NPPROC	SETBASE -- Set Selector Base
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Set selector base

|

SETBASE_STR struc

	dd	?	    ; Caller's EBP
	dd	?	    ; ...      EIP
SETBASE_LA  dd	?	    ; Base to set
SETBASE_SEL dw	?,?	    ; Selector to set base

SETBASE_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ebx>	; Save registers

	movzx	ebx,[ebp].SETBASE_SEL ; Copy selector to index register
	and	ebx,not (mask $PL) ; Clear the Privilege Level bits

	btr	ebx,$TI 	; Test and reset the Table Index bit
	jnc	short SETBASE_GDT ; Jump if it's in the GDT

	sldt	ax		; Get local LDT selector

	push	eax		; Pass the selector
	call	GETBASE 	; Return with EAX = base address

	add	ebx,eax 	; AGROUP:EBX ==> DTE

	jmp	short SETBASE_COM ; Join common code


SETBASE_GDT:

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	add	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> GDT
	add	esp,size DTR_STR ; Strip
SETBASE_COM:
	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	ds,SEL_4GB	; Get AGROUP data selector
	assume	ds:AGROUP	; Tell the assembler about it

	mov	eax,[ebp].SETBASE_LA ; Get the new base

	mov	AGROUP:[ebx].DESC_BASE01,ax ; Set bytes 0-1
	ror	eax,16		; Shift down high-order word
	mov	AGROUP:[ebx].DESC_BASE2,al ; Set byte 2
	mov	AGROUP:[ebx].DESC_BASE3,ah ; Set byte 3
;;;;;;; rol	eax,16		; Shift back

	pop	ds		; Restore

	REGREST <ebx,eax>	; Restore

	pop	ebp		; Restore

	ret	4+4		; Return to caller, popping arguments

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SETBASE endp			; End SETBASE procedure
	NPPROC	SETLENGTH -- Set Selector Length
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Set selector length

|

SETLENGTH_STR struc

	dd	?	    ; Caller's EBP
	dd	?	    ; ...      EIP
SETLENGTH_LEN dd ?	    ; Length to set
SETLENGTH_SEL dw ?,?	    ; Selector to set length

SETLENGTH_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ebx>	; Save registers

	movzx	ebx,[ebp].SETLENGTH_SEL ; Copy selector to index register
	and	ebx,not (mask $PL) ; Clear the Privilege Level bits

	btr	ebx,$TI 	; Test and reset the Table Index bit
	jnc	short SETLENGTH_GDT ; Jump if it's in the GDT

	sldt	ax		; Get local LDT selector

	push	eax		; Pass the selector
	call	GETBASE 	; Return with EAX = base address

	add	ebx,eax 	; AGROUP:EBX ==> DTE

	jmp	short SETLENGTH_COM ; Join common code


SETLENGTH_GDT:

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	add	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> GDT
	add	esp,size DTR_STR ; Strip
SETLENGTH_COM:
	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	ds,SEL_4GB	; Get AGROUP data selector
	assume	ds:AGROUP	; Tell the assembler about it

	mov	eax,[ebp].SETLENGTH_LEN ; Get the new length
	dec	eax		; Convert from length to limit

	test	AGROUP:[ebx].DESC_SEGLM1,mask $DTE_B ; Izit 4KB granular?
	jz	short @F	; Jump if not

	shr	eax,12-0	; Convert from bytes to 4KB
@@:
	mov	AGROUP:[ebx].DESC_SEGLM0,ax ; Set bytes 0-1
	shr	eax,16		; Shift down high-order word
	and	AGROUP:[ebx].DESC_SEGLM1,not (mask $SEGLM1) ; Zero the old bits
	or	AGROUP:[ebx].DESC_SEGLM1,al ; Set byte 2

	pop	ds		; Restore

	REGREST <ebx,eax>	; Restore

	pop	ebp		; Restore

	ret	4+4		; Return to caller, popping arguments

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SETLENGTH endp			; End SETLENGTH procedure
	NPPROC	GETARW -- Get Access Rights Word
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Get access rights word

On exit:

AX	=	A/R word

|

GETARW_STR struc

	dd	?	    ; Caller's EBP
	dd	?	    ; ...      EIP
GETARW_SEL dw	?,?	    ; Selector to get A/R word

GETARW_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <ebx>		; Save register

	movzx	ebx,[ebp].GETARW_SEL ; Copy selector to index register
	and	ebx,not (mask $PL) ; Clear the Privilege Level bits

	btr	ebx,$TI 	; Test and reset the Table Index bit
	jnc	short GETARW_GDT ; Jump if it's in the GDT

	sldt	ax		; Get local LDT selector

	push	eax		; Pass the selector
	call	GETBASE 	; Return with EAX = base address

	add	ebx,eax 	; AGROUP:EBX ==> DTE

	jmp	short GETARW_COM ; Join common code


GETARW_GDT:

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	add	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> GDT
	add	esp,size DTR_STR ; Strip
GETARW_COM:
	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	ds,SEL_4GB	; Get AGROUP data selector
	assume	ds:AGROUP	; Tell the assembler about it

	mov	ax,AGROUP:[ebx].DESC_ACCESS.ELO ; Get DTYP_REC and DLIM_REC

	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it

	REGREST <ebx>		; Restore

	pop	ebp		; Restore

	ret	4		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

GETARW	endp			; End GETARW procedure
	NPPROC	DD2HEX -- Convert EAX to Hex at ES:EDI
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

On entry:

ES:EDI	==>	place to put high-order digit of output

On exit:

ES:EDI	==>	(updated)

|

	rol	eax,16		; Swap order
	call	DW2HEX		; Convert AX to hex at ES:EDI

	rol	eax,16		; Swap order
	call	DW2HEX		; Convert AX to hex at ES:EDI

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DD2HEX	endp			; End DD2HEX procedure
	NPPROC	DW2HEX -- Convert AX to Hex at ES:EDI
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

On entry:

ES:EDI	==>	place to put high-order digit of output

On exit:

ES:EDI	==>	(updated)

|

	rol	ax,8		; Swap order
	call	DB2HEX		; Convert AL to hex at ES:EDI

	rol	ax,8		; Swap order
	call	DB2HEX		; Convert AL to hex at ES:EDI

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DW2HEX	endp			; End DW2HEX procedure
	NPPROC	DB2HEX -- Convert AL to Hex at ES:EDI
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

On entry:

ES:EDI	==>	place to put high-order digit of output

On exit:

ES:EDI	==>	(updated)

|

	rol	al,4		; Swap order
	call	DN2HEX		; Convert low-order nibble in AL to hex at ES:EDI

	rol	al,4		; Swap order
	call	DN2HEX		; Convert low-order nibble in AL to hex at ES:EDI

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DB2HEX	endp			; End DB2HEX procedure
	NPPROC	DN2HEX -- Convert Low-order Nibble in AL to Hex at ES:EDI
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

On entry:

ES:EDI	==>	place to put high-order digit of output

On exit:

ES:EDI	==>	(updated)

|

	REGSAVE <eax,ebx>	; Save registers

	cld			; String ops forwardly
	lea	ebx,HEXTABLE	; CS:EBX ==> translate table
	and	al,@NIB0	; Isolate the digit
	xlat	HEXTABLE[ebx]	; Translate to ASCII
	stos	es:[edi].LO	; Save in output area

	REGREST <ebx,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DN2HEX	endp			; End DN2HEX procedure

PROG	ends			; End PROG segment

	MEND			; End DPMI_MSC module
