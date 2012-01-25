;' $Header$
;
; (C) Copyright 1987-2003 Qualitas, Inc.  All rights reserved.
;
; DPMI_DTE.INC
;
; Structures and equates for the GDT and related issues.
; This file is common to almost all DPMI*.ASM files.
;

;;;;IOPL equ	0		; Use this IOPL for DPMI clients to catch
				; I/O trapping from PL3 (not anymore)
@DPMIOPL equ	3		; Use this IOPL for DPMI clients to avoid
				; bugs with PUSHF/CLI/POPF and IRET which don't
				; change IF on the POPF/IRET
@VMIOPL  equ	3		; Use this IOPL for VM clients to avoid
				; GP Faults on CLI/STI/HLT/INT/IRET/PUSHF/POPF

NRM_STR struc			; Stack when no error code present

NRM_EIP   dd	?		; 00:  EIP
NRM_CS	  dw	?		; 04:  CS
NRM_INTNO dw	?		; 06:  INT # times 4 + offset PGROUP:INTPROC00Z
NRM_EFL   dd	?		; 08:  EFL

NRM_STR ends


FLT_STR struc			; Stack when error code is present

FLT_ERR   dd	?		; 00:  Error code
FLT_EIP   dd	?		; 04:  EIP
FLT_CS	  dw	?		; 08:  CS
FLT_INTNO dw	?		; 0A:  INT # times 4 + offset PGROUP:INTPROC00Z
FLT_EFL   dd	?		; 0C:  EFL

FLT_STR ends


; DPMI stack argument structure for faults

INTDPF_STR struc

INTDPF_ERR dd	?		; 00:  Error code
INTDPF_EIP dd	?		; 04:  Old EIP
INTDPF_CS  dw	?		; 08:  Old CS
INTDPF_INTNO dw ?		; 0A:  INT # times 4 + offset PGROUP:INTPROC00Z
INTDPF_EFL dd	?		; 0C:  Old EFL
INTDPF_ESP dd	?		; 10:  Old ESP
INTDPF_SS  dw	?,0		; 14:  Old SS w/filler

INTDPF_STR ends


; DPMI stack argument structure for interrupts

INTDPI_STR struc

INTDPI_EIP dd	?		; 00:  Old EIP
INTDPI_CS  dw	?		; 04:  Old CS
INTDPI_INTNO dw ?		; 06:  INT # times 4 + offset PGROUP:INTPROC00Z
INTDPI_EFL dd	?		; 08:  Old EFL
INTDPI_ESP dd	?		; 0C:  Old ESP
INTDPI_SS  dw	?,0		; 10:  Old SS w/filler

INTDPI_STR ends


; DPMI stack argument structure for far calls

RETFDPI_STR struc

RETFDPI_EIP dd	?		; 00:  Old EIP
RETFDPI_CS  dw	?,0		; 04:  Old CS w/filler
RETFDPI_ESP dd	?		; 08:  Old ESP
RETFDPI_SS  dw	?,0		; 0C:  Old SS w/filler

RETFDPI_STR ends


; INTCOM stack argument structure

INTCOM_STR struc

INTCOM_EIP dd	?		; 00:  Old EIP
INTCOM_CS dw	?		; 04:  Old CS
INTCOM_INTNO dw ?		; 06:  Interrupt #
INTCOM_EFL dd	?		; 08:  Old EFL
INTCOM_ESP dd	?		; 0C:  Old ESP3
INTCOM_SS dw	?,0		; 10:  Old SS
INTCOM_ES dw	?		; 14:  Old ES
INTCOM_ICOMLO dw ?		; 16:  INTCOM-restart point, low-order word
INTCOM_DS dw	?		; 18:  Old DS
INTCOM_ICOMHI dw ?		; 1A:  INTCOM-restart point, high-order word
INTCOM_FS dw	?		; 1C:  Old FS
INTCOM_I0DCS dw ?		; 1E:  Save area for DPMI client's CS for GPFs
INTCOM_GS dw	?		; 20:  Old GS
INTCOM_I0DDX dw ?		; 22:  Save area for DPMI client's DX for GPFs
INTCOM_NEXT dd	?		; 24:  RM_NEXT
INTCOM_DEV_FLAG dw ?		; 28:  DEV_FLAG
INTCOM_GDTR df	?		; 2A:  RM_GDTR

INTCOM_STR ends


; Record and equate for LAST_INTFLG

INTCOM_REC record $INTCOM_RSV:7,$INTCOM_VAL:1 ; Do NOT define additional bits
				; in the low-order byte so we can use SETcc
@INTCOM_VAL equ mask $INTCOM_VAL ; LAST_INTCOM is valid:  *MUST* be Bit 0.


; INTXX stack argument structure

INTXX_STR struc

INTXX_EDI   dd	?		; 00:  Old EDI
INTXX_ESI   dd	?		; 04:  Old ESI
INTXX_EBP   dd	?		; 08:  Old EBP
INTXX_ESP0  dd	?		; 0C:  Old ESP0
INTXX_EBX   dd	?		; 10:  Old EBX
INTXX_EDX   dd	?		; 14:  Old EDX
INTXX_ECX   dd	?		; 18:  Old ECX
INTXX_EAX   dd	?		; 1C:  Old EAX
INTXX_ERR   dd	?		; 20:  Fault error code
INTXX_EIP   dd	?		; 24:  Old EIP
INTXX_CS    dw	?		; 28:  Old CS
INTXX_INTNO dw	?		; 2A:  Interrupt #
INTXX_EFL   dd	?		; 2C:  Old EFL
INTXX_ESP   dd	?		; 30:  Old ESP3
INTXX_SS    dw	?		; 34:  Old SS
INTXX_OIPLO dw	?		; 36:  Original EIP, low-order word
INTXX_ES    dw	?		; 38:  Old ES
INTXX_ICOMLO dw ?		; 3A:  INTCOM-restart point, low-order word
INTXX_DS    dw	?		; 3C:  Old DS
INTXX_ICOMHI dw ?		; 3E:  INTCOM-restart point, high-order word
INTXX_FS    dw	?		; 40:  Old FS
INTXX_OIPHI dw	?		; 42:  Original EIP, high-order word
INTXX_GS    dw	?,0		; 44:  Old GS
INTXX_NEXT dd	?		; 46:  RM_NEXT
INTXX_DEV_FLAG dw ?		; 4A:  DEV_FLAG
INTXX_GDTR df	?		; 4C:  RM_GDTR

INTXX_STR ends


COMMENT|

Equate for VSAPI stack size in dwords to avoid conflict with other
stack sizes during PL0 processing.  This value *MUST* be such that the
stack upon entry to the VSAPI routine is larger than any other initial
stack.	The other entry stacks are as follows:

Variable	  Structure				Byte size
--------------------------------------------------------------------
PPL0STK_DNRM	  size INTDPI_STR			    14h
PPL0STK_DERR	  size INTDPF_STR			    18h
PPL0STK_NRM	  size INTCOM_STR			    24h
PPL0STK_ERR	 (size INTCOM_STR) + (size INTXX_ERR)	    28h

Before entry to the VSAPI routine, the PL3 code subtracts this amount
from the current stack and pushes at least one argument.  The call
gate for VSAPI copies this many dword parameters from the PL3 stack.
Upon entry to the VSAPI routine, the CPU pushes RETFDPI_STR onto the
stack.

|

@VSAPI_DDSTKSIZE equ (((size INTCOM_STR)+(size INTXX_ERR)-(size RETFDPI_STR))/4)


; Equates for XDTE_STR

@TSS_MAX  equ	64		; Maximum # TSSs supported and thus
				; this number (less one for the main TSS)
				; becomes the maximum depth of DPMI client
				; nesting we allow

@DPMI_CPL equ	3		; DPMI client CPL/RPL
@DPMI_DPL equ	3		; DPMI client DPL
DTE_DATALDT equ 0080h		; LDT selector offset
DTE_DATALPM equ 0088h		; LPM selector offset
LDTE_DATALDT3 equ (DTE_DATALDT or (mask $TI) or (@DPMI_CPL shl $PL)) ; LDTE for LDT at DPMI DPL
LDTE_DATALPM3 equ (DTE_DATALPM or (mask $TI) or (@DPMI_CPL shl $PL)) ; LDTE for LPM at DPMI DPL


; LENTXT2 is used for message creation with leading dword length

LENTXT2 macro	LAB,MSG
	local	LABA,LABZ

	public	LAB
LAB	LENTXT_STR <LABZ-LABA>
LABA	db	MSG
LABZ	label	byte

	endm			; LENTXT2

LENTXT_STR struc

LENTXT_LEN dd	?		; Length of following string
				; First byte of following string
LENTXT_STR ends


PDT_STR struc

PDT_PTE dd	?		; Page Table Entry in PDT

PDT_STR ends


