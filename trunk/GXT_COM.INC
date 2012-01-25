;' $Header$
;
; (C) Copyright 1995-2002 Qualitas, Inc.  All rights reserved.
;
; GXT_COM.INC
;
; Common structures and macros for MMEXT
;

; If the resident size of DPMI.LOD increases, this number
; might have to increase as well.

@TSRSIZE equ	6*1024		; Size of TSR room in the STACK segment

; File loader structure

LOAD_STR struc

LOAD_SEG dw	?		; 00:  Segment of file image
LOAD_XMS dw	0		; 02:  XMS handle (0=none)
LOAD_NSELS dw	?		; 04:  # selectors needed
LOAD_SEL1 dw	?		; 06:  First selector
LOAD_PHYS dd	?		; 08:  Physical address of XMS image
LOAD_MMLIN dd	?		; 0C:  MM-linear ...
LOAD_COFF dd	?		; 10:  Offset to PM code (typically zero)
LOAD_CLEN dd	?		; 14:  Length of ...
LOAD_DOFF dd	?		; 18:  Offset to PM data
LOAD_DLEN dd	?		; 1C:  Length of ... (may include uninitialized data)
LOAD_ATTR dd	?		; 20:  Attributes (see GXTHDR_REC)
LOAD_RREAL dd	?		; 24:  Seg:Off of REST_REAL code

LOAD_STR ends


; Common macros

SETDATA macro	SREG,FL

ifnb <FL>
	pushf			; Save flags
endif				; IFNB <FL>
	push	cs		; Get code selector
	add	[esp].ELO,size DESC_STR ; Skip to data selector
	pop	SREG		; Address it
ifnb <FL>
	popf			; Restore flags
endif				; IFNB <FL>

	endm			; SETDATA


IDTMAC	macro	N1,N2,SRC,SAV
	local	L1

IDT	equ	<AGROUP:[ebx+N1*(type IDT_STR)]>

	mov	ax,SRC&INT&N2&_FVEC.FSEL ; Get selector
	xchg	ax,IDT.IDT_SELECT ; Swap with IDT
ifnb <SAV>
	mov	SAV&INT&N2&_FVEC.FSEL,ax ; Save for later use
endif

	mov	eax,SRC&INT&N2&_FVEC.FOFF ; Get 32-bit offset
	xchg	ax,IDT.IDT_OFFLO ; Swap with IDT
ifnb <SAV>
	mov	SAV&INT&N2&_FVEC.FOFF.ELO,ax ; Save for later use
endif
	shr	eax,16		; Shift to low-order
	xchg	ax,IDT.IDT_OFFHI ; Swap with IDT
ifnb <SAV>
	mov	SAV&INT&N2&_FVEC.FOFF.EHI,ax ; Save for later use
endif

	mov	al,SRC&INT&N2&_ARB ; Get incoming A/R byte
	and	al,not (mask $DT_DPL) ; Clear the DPL
	mov	ah,IDT.IDT_ACCESS ; Get current A/R byte
	and	ah,mask $DT_DPL ; Isolate the DPL
	or	al,ah		; Copy to incoming A/R byte
	xchg	al,IDT.IDT_ACCESS ; Swap with IDT
ifnb <SAV>
	mov	SAV&INT&N2&_ARB,al ; Save for later use
endif
L1:
	endm


; PM2RM stack argument structure

PM2RM_STR struc

PM2RM_EIP dd	?		; 00:  Old EIP
PM2RM_CS  dw	?,?		; 04:  Old CS
PM2RM_EFL dd	?		; 08:  Old EFL
PM2RM_ESP dd	?		; 0C:  Old ESP3
PM2RM_SS  dw	?,?		; 10:  Old SS
PM2RM_ES  dw	?,?		; 14:  Old ES
PM2RM_DS  dw	?,?		; 18:  Old DS
PM2RM_FS  dw	?,?		; 1C:  Old FS
PM2RM_GS  dw	?,?		; 20:  Old GS
PM2RM_NEXT dd	?		; 24:  RM_NEXT
PM2RM_DEV_FLAG dw ?		; 28:  DEV_FLAG
PM2RM_GDTR df	?		; 2A:  GDTR

PM2RM_STR ends


