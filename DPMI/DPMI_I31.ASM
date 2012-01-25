;' $Header$
	title	DPMI_I31 -- DPMI.LOD INT 31h Handler
	page	58,122
	name	DPMI_I31

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
	include DOSCALL.INC
	include VIDCALL.INC
	include ASCII.INC
	include CPUFLAGS.INC
	include BITFLAGS.INC
	include ALLMEM.INC
	include OPCODES.INC
	include MAC.INC
	include DPMI.INC
	include DOSERR.INC
	include MASM5.MAC
	include INTVEC.INC
	include MAXDEV.INC
	include CPUFET2.INC
	include VIDATTR.INC
	include IOPBITS.INC
	include MOVSPR.INC
	include OPEN.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_EXP.INC
	include DPMI_LCL.INC
	include DPMI_SEG.INC
	include DPMI_SWT.INC
	include DPMI_W9X.INC
	include GXT_HDR.INC

	include QMAX_DYN.INC
	include QMAX_EMM.INC
	include QMAX_TSS.INC
	include QMAX_VMM.INC
	include QMAX_I31.INC		; Must precede QMAXDPMI.INC
	include QMAXDPMI.INC		; Must follow QMAX_I31.INC
.list

PSPSEG	segment use16 at 0	; Start PSPSEG segment
	assume	cs:PSPGRP,ds:PSPGRP

	public	PSP_ENVIR_PTR
	include PSP.INC

PSPSEG	ends			; End PSPSEG segment


YCODE	segment use16 para public 'ycode' ; Start YCODE segment
	assume	ds:YGROUP

	extrn	YY_XMSMEM_CNT:dword
	extrn	YY_XMSMEM:tbyte
	extrn	FreeAllMem:far

YCODE	ends			; End YCODE segment


DATA16	segment use16 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	public	@DPMI_I31_DATA16
@DPMI_I31_DATA16 label byte	; Mark module start in .MAP file

	extrn	DB2_FLAG:word
	include DPMI_DB2.INC

	extrn	CPUFET_FLAG:dword

	extrn	LDT_SIZ:dword
	extrn	XLDT_SIZ:dword

;;;;;;; extrn	PLCL_PL0CUR:dword

	extrn	HIMEM_CS:word
	extrn	XMSMEM_CNT:dword
	extrn	XMSMEM:tbyte
	extrn	PXMSBMAP:dword

	public	HPDASTK_SIZ,HPDABUF_SIZ,HPDAVMC_CNT
HPDASTK_SIZ dw	@HPDASTK_DEF	; Size of HPDA stack  in bytes
HPDABUF_SIZ dw	@HPDABUF_DEF	; Size of HPDA buffer in bytes
HPDAVMC_CNT dd	@HPDAVMC_DEF	; # HPDA VM callbacks

@HPDASTK_OFF equ (4*(((4-1)+(size HPDA_STR))/4)) ; Default HPDA stack bottom

	public	HPDASTK_OFF,HPDASTK_TOP,HPDABUF_OFF,HPDAVMC_OFF,HPDA_NPAR
SOF	=	@HPDASTK_OFF	; Size so far
HPDASTK_OFF dw	SOF		; Offset of local stack in HPDA
SOF	=	SOF + @HPDASTK_DEF ; Plus size of default stack
HPDASTK_TOP dw	SOF		; Offset of top of local HPDA stack
HPDABUF_OFF dw	SOF		; Offset of local HPDA buffer
SOF	=	SOF + @HPDABUF_DEF ; Plus size of default buffer
HPDAVMC_OFF dw	SOF		; Offset of local VM callback structures
SOF	=	SOF + (@HPDAVMC_DEF * (size HPDAVMC_STR)) ; Plus size of default VM callback strucs
HPDA_NPAR dw	((16-1)+SOF)/16 ; # paras in HPDA

	public	DPMIDYN_SIZ,DPMIHNDL_CNT,DPMIPDIR_CNT,DPMIHNDL_SIZ
	align	4		; Ensure dword-aligned
DPMIDYN_SIZ dd	@DPMIDYN_DEF	; Size of dynamic save area
DPMIHNDL_CNT dd @DPMIHNDL_DEF	; Initial # DPMI memory handles
@DPMIHNDL_SIZ equ @DPMIHNDL_DEF*(type DPMIHNDL_STR)
@DPMIHNDL_RND equ (@DPMIHNDL_SIZ+(@DPMI_BOUND-1)) and (not (@DPMI_BOUND-1))
DPMIHNDL_SIZ dd @DPMIHNDL_RND	; Initial byte size of DPMI memory handle table
				; /@DPMI_BOUND
DPMIPDIR_CNT dd @DPMIPDIR_DEF	; # DPMI page directories for phys-to-lin mappings

	public	DPM_FLAG
DPM_FLAG dw	0		; DPMI debugging flags

DATA16	ends			; End DATA16 segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

;;;;;;; extrn	GLB_FLAG:word
;;;;;;; include QMAX_GLB.INC
;;;;;;;
	extrn	LCL_FLAG:word
	extrn	OffCR3:dword
	extrn	PaCR3:dword
	extrn	PHYSIZE:dword
;;;;;;; extrn	DPMI_EXIT:dword

DATA	ends			; End DATA segment


;;; HICODE   segment use16 dword public 'prog' ; Start HICODE segment
;;;	     assume  cs:PGROUP,ds:PGROUP
;;;
;;;	     extrn   DPMI_VM2PM:near
;;;
;;;	     extrn   EXITRCHI:word
;;;
;;; HICODE   ends		    ; End HICODE segment
;;;
;;;
;;; DL2DATA  segment use16 word public 'dl2code' ; Start DL2DATA segment
;;;	     assume  ds:DL2GROUP
;;;
;;;	     public  DL2_PMERET,DL2_PGRSEG
;;; DL2_PMERET dd    ?		    ; Return from call to protected mode entry
;;; DL2_PGRSEG dw    ?		    ; High DOS segment for PGROUP
;;;
;;; DL2DATA  ends		    ; End DL2DATA segment
;;;
;;;
;;; DL2CODE  segment use16 para public 'dl2code' ; Start DL2CODE segment
;;;	     assume  cs:DL2GROUP
;;;
;;;	     NPPROC  GENINT23 -- Act on Int 23
;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;; COMMENT|
;;;
;;; Act on Int 23 if Ctrl-Break detected during DPMI client's backing store
;;; initialization.  We detect the Int 23 and ignore it while initializing
;;; the swap file, but abort client initialization.  We'll return here from
;;; protected mode via IRETD, then call the current Int 23 handler.  If CF=1
;;; (abort) we'll set the flag in QMAX_OVR to return our own value for function
;;; 4D (we want to return 0300 - terminated via Ctrl-C) and terminate with
;;; function 4C.  Otherwise, we'll IRET to the code following the call to
;;; the protected mode entry point.
;;;
;;; |
;;;
;;;	     clc		    ; Assume we'll ignore it
;;;	     int     23h	    ; Call current Ctrl-Break handler
;;;	     jc      short @F	    ; Jump if we need to abort program
;;;
;;; ; Ignore Ctrl-C; return to instruction following far call to protected mode
;;; ; entry point with CF=1 and AX=8014 (insufficient backing store).
;;;	     mov     ax,@DERR_INSUFF_BACK ; This is the only error message
;;;				    ; related to backing store.
;;;	     stc		    ; Indicate error
;;;
;;;	     jmp     DL2_PMERET     ; Note that stack is already set up for return
;;;
;;; @@:
;;;	     push    ds 	    ; Save for a moment
;;;
;;; ; Set return code to 0300 via high DOS function 4D hook
;;;	     mov     ds,DL2_PGRSEG  ; Address PGROUP in high DOS
;;;	     assume  ds:PGROUP	    ; Tell the assembler
;;;
;;;	     or      MSC_FLAG,mask $MSC_GETRC ; Lie about return code on next fn 4D
;;;	     mov     EXITRCHI,0300h ; Terminated via Ctrl-C
;;;
;;;	     pop     ds 	    ; Restore
;;;	     assume  ds:nothing     ; Tell the assembler
;;;
;;;	     mov     al,0	    ; No return code
;;;	     DOSCALL @EXITRC	    ; Terminate with return code AL
;;;
;;;	     int     20h	    ; In case it's DOS 4...
;;;
;;;	     assume  ds:nothing,es:nothing,ss:nothing
;;;
;;; GENINT23 endp		    ; End GENINT23 procedure
;;;
;;; DL2CODE  ends		    ; End DL2CODE segment
;;;
;;;
;;; DL2DATZ  segment use16 dword public 'dl2code' ; Start DL2DATZ segment
;;;	     assume  ds:DL2GROUP
;;;
;;;	     extrn   DL2GROUP_END:word
;;;
;;; DL2DATZ  ends		    ; End DL2DATZ segment
;;;
;;;
DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_I31_DATA
@DPMI_I31_DATA	label byte	; Mark module start in .MAP file

	extrn	LAST_DPMI_DS:word
	extrn	LAST_DPMI_ES:word
	extrn	LAST_DPMI_FS:word
	extrn	LAST_DPMI_GS:word
	extrn	DGRBASE:dword
	extrn	SEL_DATA:word
	extrn	SEL_4GB:word
	extrn	LAST_INTCOM:dword
	extrn	LAST_INTFLG:dword
	extrn	LPMSTK_CNT:dword
	extrn	LPMSTK_SIZ:dword
	extrn	LPMSTK_FVEC:fword
	extrn	CON4KB:dword
	extrn	CON64KB:dword

	extrn	DPMI_CPIHOOK:byte
	extrn	DPMI_CPFHOOK:byte
	extrn	DPMI_CVFHOOK:byte
	extrn	DPMI_PPIHOOK:byte
	extrn	DPMI_PVFHOOK:byte

	extrn	LaIOBIT:dword
	extrn	LaSIRBCUR:dword

	extrn	DPMIMSG:dword
	extrn	MSG_APPLNAME:tbyte
	extrn	MSG_APPLNAME_LEN:abs

	extrn	MSW_PM:word

	extrn	VMCREGS:tbyte

	extrn	TSRsize:word

	extrn	VMM_FLAG:word

	extrn	MSG_TITLE:tbyte
	extrn	MSG_TITL2:tbyte
	extrn	MSG_TITL3:tbyte
	extrn	MSG_TITL4:tbyte
	extrn	MSG_APPLUNK:tbyte
	extrn	MSG_TAIL:tbyte

	extrn	MSG_DPMIADDREFL:byte
	extrn	MSG_DPMISTK:byte
	extrn	MSG_DPMISTK1:byte

	extrn	MSG_DPMIADDR:tbyte
	extrn	MSG_DPMIADDROFF:byte
	extrn	MSG_DPMIADDRSEP:byte
	extrn	MSG_DPMIADDRSEL:byte
	extrn	MSG_DPMIPRESS:tbyte

	extrn	BSTotal:dword
	extrn	BSGTotal:dword

	extrn	DBGCTL:byte
	extrn	DBGSTA:byte
	extrn	DBGREGS:dword
	extrn	DBGDR7:dword

	extrn	DTE_DPMIDEF:dword
;;;;;;; extrn	LastTR:word

if @W9X
	public	WINDIR_LEN,APPDIR_LEN
WINDIR_LEN dd	0		; Length of Windows directory in MSG_APPLNAME
APPDIR_LEN dd	0		; ...	    Application ...

	public	KERNEL32_LEN
KERNEL32_LEN dd ?		; Length of KERNEL32.DLL

@KERNEL32_BASE equ 0BFF60000h	; Load at this base
endif

	public	PDE_Start
PDE_Start dd	?		; Start of PDE

	public	OffALLOCMEM
OffALLOCMEM dd	?		; Linear address offset for ALLLOCMEM/DEALLOCMEM

	public	CurCR0
CurCR0	dd	?		; Current CR0

	public	LaSTKPTE,LaSTKMEM,STKPTE
LaSTKPTE dd	?		; Linear address of stack PTE in page tables
LaSTKMEM dd	0		; ...			  memory (free later)
				; 0 = not allocated
STKPTE	dd	?		; Old stack PTE (restore later)

	public	PPL0STK_INI,PPL0STK_ERR,PPL0STK_NRM,PPL0STK_MIN
	public	PPL0STK_MAX,PPL0STK_MAP
	public	@PPL0STK_INT
@PPL0STK_INT equ 128		; Stack size for hardware interrupts
PPL0STK_INI dd	?		; Pointer to PL0STK	(fixed)
PPL0STK_ERR dd	?		; Offset of stack when error code present
PPL0STK_NRM dd	?		; Offset of stack when normal start
PPL0STK_MIN dd	?		; Offset of stack minimum for interrupts
PPL0STK_MAX dd	?		; Offset of stack maximum for interrupts
PPL0STK_MAP dd	?		; Offset of stack bottom for Map & Call struc

	public	PPL0STK_DERR,PPL0STK_DNRM
PPL0STK_DERR dd ?		; Offset of stack when DPMI fault
PPL0STK_DNRM dd ?		; Offset of stack when DPMI HW/SW interrupt

	public	LaVMTSS,PVMTSS,PCURTSS,PPRMTSS
LaVMTSS dd	?		; Offset in AGROUP of 1st TSS (original)
PVMTSS	dd	?		; Offset in DGROUP of 1st TSS (copy)
PCURTSS dd	?		; ...		      current TSS
PPRMTSS dd	?		; ...		      primary TSS

	public	HPDA_TEMPLATE
HPDA_TEMPLATE HPDA_STR <>	; HPDA template used for all HPDAs

	public	I31_FLAG,PDC_FLAG
I31_FLAG dw	0		; INT 31h flags (mapped by I31_REC)
PDC_FLAG dw	0		; Per DPMI Client flags (mapped by I31_REC)

	public	NOSWAP_CNT
NOSWAP_CNT dw	0		; Lie about swapping this many times

	public	VM2PM_PSP,VM2PM_DTAVEC,VM2PM_TSS,VM2PM_ERR
VM2PM_PSP dw	?		; Caller's PSP
VM2PM_DTAVEC dd ?		; Temporary save area for caller's DTA
VM2PM_TSS dw	?		; Current TSS selector
VM2PM_ERR dw	?		; Error code if we terminate
;;;	    public  VM2PM_TSS1
;;; VM2PM_TSS1 dw   ?		    ; 1st TSS selector

	public	EXITRC
EXITRC	dw	@EXITRC shl 8	; DOS function code to exit with code

; Note that comparisons against the DPMITYPE byte should *ALMOST ALWAYS*
; be made with @DPMITYPE16.  That way, we treat the "no DPMI client"
; (i.e. MAX's use of these services) case as 32-bit

	public	CPUTYPE,DPMITYPE
CPUTYPE db	03h		; CPU type (02 = 286, 03 = 386, 04 = 486, etc.)
DPMITYPE db	@DPMITYPEXX	; DPMI client type:
				; 0 = 16-bit
				; 1 = 32-bit
				; 2 = no DPMI clients active
	public	DPMI_CODE,DPMI_DATA,DPMI_IDEF,DPMI_CPL,DPMI_DPL
DPMI_CODE dw	CPL0_CODE or (@DPMI_DPL shl $DT_DPL) ; A/R byte for DPMI code
DPMI_DATA dw	CPL0_DATA or (@DPMI_DPL shl $DT_DPL) ; ...		 data
DPMI_IDEF dw	0ABCDh		; Interrupt selector
DPMI_CPL  db	@DPMI_CPL shl $PL     ; DPMI CPL
DPMI_DPL  db	@DPMI_DPL shl $DT_DPL ; DPMI DPL


	public	DPMIHNDL_OFF,DPMIPDIR_OFF,LaDPMIPDIR,LaDPMIPDIRMEM
DPMIHNDL_OFF dd ?		; Offset in DGROUP of initial resident DPMI
				; memory handle structure
DPMIPDIR_OFF dd ?		; Offset in DGROUP of page directories
LaDPMIPDIR dd	?		; Linear address of the first DPMI page
				; directory (/4KB)
LaDPMIPDIRMEM dd ?		; Linear address of the memory mapped by the
				; first DPMI page directory (/4MB)

	public	DPMIOLDPM_SIZ
DPMIOLDPM_SIZ dd ?		; Size of old PM data area

	public	LPMSTK_SEL
LPMSTK_SEL dw	LDTE_DATALPM3	; Default LPM stack selector

PM_MAC16 macro	NAME,N
	dw	NAME&N
	dw	0ABCDh
	endm			; PM_MAC16

PM_MAC32 macro	NAME,N
	dd	NAME&N
	dw	0ABCDh
	endm			; PM_MAC32

; Define default PM interrupt handlers

	public	PMINT_FVECS
PMINT_FVECS label fword

CNT	=	0
	rept	256

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	PM_MAC32 PMIDEF,%N
CNT	=	CNT + 1
	endm			; REPT 256

	public	PMINT_DVECS
PMINT_DVECS label dword

CNT	=	0
	rept	256

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	PM_MAC16 PMIDEF,%N
CNT	=	CNT + 1
	endm			; REPT 256


; Define default PM fault handlers

	public	PMFLT_FVECS
PMFLT_FVECS label fword

CNT	=	0
	rept	32

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	PM_MAC32 PMFDEF,%N
CNT	=	CNT + 1
	endm			; REPT 32

	public	PMFLT_DVECS
PMFLT_DVECS label dword

CNT	=	0
	rept	32

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	PM_MAC16 PMFDEF,%N
CNT	=	CNT + 1
	endm			; REPT 32

; Define default VM fault handlers

	public	VMFLT_FVECS
VMFLT_FVECS label fword

CNT	=	0
	rept	32

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	PM_MAC32 VMFDEF,%N
CNT	=	CNT + 1
	endm			; REPT 32

	public	VMFLT_DVECS
VMFLT_DVECS label dword

CNT	=	0
	rept	32

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	PM_MAC16 VMFDEF,%N
CNT	=	CNT + 1
	endm			; REPT 32

; Note that comparisons against the DPMITYPEIG byte should *ALMOST ALWAYS*
; be made with @DPMITYPE16.  That way, we treat the "no DPMI client"
; (i.e. MAX's use of these services) case as 32-bit

	public	DPMITYPEIG
DPMITYPEIG db	@DPMITYPEXX	; DPMI client type:  (same as DPMITYPE)

	public	STK_FLAG
STK_FLAG db	0		; Stack flag:  1 = extra memory present below stack
				;	       0 = not

	public	KRNL386
KRNL386 db	'KRNL386.EXE',0 ; Windows DPMI client
@KRNL386_LEN equ $-KRNL386	; Length of ...

if @W9X
	public	WINDIREQ
WINDIREQ db	'windir='       ; Windows directory env var
@WINDIREQ_LEN equ $-WINDIREQ	; Length of ...

	public	KERNEL32
KERNEL32 db	'KERNEL32.DLL'  ; DLL to load for
@KERNEL32_LEN equ $-KERNEL32	; Length of ...
endif

	public	MSG_REGS
;;;;;;; 	 012345678
MSG_REGS db	'EAX      '
	db	'EBX      '
	db	'ECX      '
	db	'EDX      '
	db	'ESI      '
	db	'EDI      '
	db	'EBP      '
	db	'ESP      '
	db	'EIP',CR,LF
	db	'%08X %08X %08X %08X %08X %08X %08X %08X %08X',CR,LF,0

DATA	ends			; End DATA segment



; Define DPMI functions which we handle

DPMIMAC macro	VAL,ACT,EXT

VALSEG	segment use32 byte public 'data' ; Start VALSEG segment
	assume	ds:DGROUP

VALORG	=	((VAL and (mask $MAXDFN_HI)) shr (width $MAXDFN_MD)) or (VAL and (mask $MAXDFN_LO))

	org	DPMI_VAL+VALORG
	db	NXTDFN		; Fill with next DPMI function code
	org	DPMI_VALZ	; back to the ending byte

NXTDFN	=	NXTDFN+1	; Skip to next DPMI function code

VALSEG	ends			; End VALSEG segment


ACTSEG	segment use32 dword public 'data' ; Start ACTSEG segment
	assume	ds:DGROUP

	dd	offset PGROUP:DPMI_&ACT

ACTSEG	ends			; End ACTSEG segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	extrn	DPMI_&ACT:near

PROG	ends			; End PROG segment

	endm			; DPMIMAC


VALSEG	segment use32 byte public 'data' ; Start VALSEG segment
	assume	ds:DGROUP

	public	@DPMI_I31_VALSEG
@DPMI_I31_VALSEG label byte	; Mark module start in .MAP file

; Pack the DPMI function code into a hash via the $MAXDFN_xx record
; where we delete the $MAXDFN_MD section.

@MAXDFN equ	0E01h		; Maximum DPMI function code

MAXDFN_REC record $MAXDFN_EX:4,$MAXDFN_HI:5,$MAXDFN_MD:2,$MAXDFN_LO:5

COMMENT|

The 16 bits in DPMI functions are parsed as follows:

 EX   HI   MD	LO
0000 xxxx x00x xxxx

where a 0 is ignored and an x is allowed

|

@MAXDVAL equ	(@MAXDFN shr (width $MAXDFN_MD)) or \
		(@MAXDFN and (mask $MAXDFN_LO))

	public	DPMI_VAL
DPMI_VAL db	(@MAXDVAL-1) dup (00h) ; Fill with Invalid Function code
DPMI_VALZ label byte

VALSEG	ends			; End VALSEG segment


ACTSEG	segment use32 dword public 'data' ; Start ACTSEG segment
	assume	ds:DGROUP

	public	@DPMI_I31_ACTSEG
@DPMI_I31_ACTSEG label byte	; Mark module start in .MAP file

	public	DPMI_ACT
DPMI_ACT dd	offset PGROUP:INT31_ERR_NOFNS ; Seed with Invalid Function entry

ACTSEG	ends			; End ACTSEG segment


NXTDFN	=	1		; Initialize next DPMI function code
				; after the Invalid Function entry

; LDT Descriptor Management Services

	DPMIMAC 0000h,GETLDT	  ; [0.9] Allocate LDT selectors
	DPMIMAC 0001h,RELLDT	  ; [0.9] Free an LDT selector
	DPMIMAC 0002h,SEG2SEL	  ; [0.9] Convert Segment to Selector
	DPMIMAC 0003h,NXTSEL	  ; [0.9] Get next selector increment value
	DPMIMAC 0004h,LOCKSEG	  ; [0.8] Lock Linear Region using selector
	DPMIMAC 0005h,LOCKSEG	  ; [0.8] Unlock Linear Region using selector
	DPMIMAC 0006h,GSELBAS	  ; [0.9] Get selector base address
	DPMIMAC 0007h,SSELBAS	  ; [0.9] Set selector base address
	DPMIMAC 0008h,SSELLIM	  ; [0.9] Set selector limit
	DPMIMAC 0009h,SSELARW	  ; [0.9] Set selector A/R word
	DPMIMAC 000Ah,GETALIAS	  ; [0.9] Get selector alias
	DPMIMAC 000Bh,GETLDTE	  ; [0.9] Get LDT entry
	DPMIMAC 000Ch,SETLDTE	  ; [0.9] Set LDT entry
	DPMIMAC 000Dh,GETRLDT	  ; [0.9] Allocate reserved LDT selector
	DPMIMAC 000Eh,GETMLDTE	  ; [1.0] Get multiple LDT entries		    1.0
	DPMIMAC 000Fh,SETMLDTE	  ; [1.0] Set multiple LDT entries		    1.0

; DOS Memory Management Services

	DPMIMAC 0100h,GETDMEM	  ; [0.9] Allocate DOS memory block
	DPMIMAC 0101h,RELDMEM	  ; [0.9] Free DOS memory block
	DPMIMAC 0102h,MODDMEM	  ; [0.9] Resize DOS memory block

; Interrupt Management Services

	DPMIMAC 0200h,GETVMIV	  ; [0.9] Get VM interrupt vector
	DPMIMAC 0201h,SETVMIV	  ; [0.9] Set VM interrupt vector
	DPMIMAC 0202h,GETPEHV	  ; [0.9] Get processor exception handler vector
	DPMIMAC 0203h,SETPEHV	  ; [0.9] Set processor exception handler vector
	DPMIMAC 0204h,GETPMIV	  ; [0.9] Get protected mode interrupt vector
	DPMIMAC 0205h,SETPMIV	  ; [0.9] Set protected mode interrupt vector
	DPMIMAC 0210h,GETPEHV	  ; [1.0] Get extended PM proc exception handler
	DPMIMAC 0211h,GETEVMPEHV  ; [1.0] Get extended VM proc exception handler
	DPMIMAC 0212h,SETPEHV	  ; [1.0] Set extended PM proc exception handler
	DPMIMAC 0213h,SETEVMPEHV  ; [1.0] Set extended VM proc exception handler
	DPMIMAC 0283h,SETPEHV	  ; [Win] Set Processor Exception Handler Vector

	DPMIMAC 0900h,INTCLI	  ; [0.9] Get & Disable Virtual Interrupt State
	DPMIMAC 0901h,INTSTI	  ; [0.9] Get & Enable Virtual Interrupt State
	DPMIMAC 0902h,GETIF	  ; [0.9] Get Virtual Interrupt State

; Translation Services

	DPMIMAC 0300h,SIMVMI	  ; [0.9] Simulate VM interrupt
	DPMIMAC 0301h,SIMVMCFR	  ; [0.9] Simulate VM call with far return
	DPMIMAC 0302h,SIMVMCIR	  ; [0.9] Simulate VM call with IRET return
	DPMIMAC 0303h,GETVMCB	  ; [0.9] Allocate VM callback address
	DPMIMAC 0304h,RELVMCB	  ; [0.9] Free VM callback address
	DPMIMAC 0305h,GETSSR	  ; [0.9] Get State Save/Restore addresses
	DPMIMAC 0306h,GETRMS	  ; [0.9] Get Raw Mode Switch addresses

; Extended Memory Management Services

	DPMIMAC 0500h,GETFMI	  ; [0.9] Get Free Memory Information
	DPMIMAC 0501h,GETMEM	  ; [0.9] Allocate Memory Block
	DPMIMAC 0502h,RELMEM	  ; [0.9] Free Memory Block
	DPMIMAC 0503h,MODMEM	  ; [0.9] Resize Memory Block
	DPMIMAC 0504h,GETLMB	  ; [1.0] Allocate Linear Memory Block
	DPMIMAC 0505h,MODLMB	  ; [1.0] Resize Linear Memory Block
	DPMIMAC 0506h,GPGATTR	  ; [1.0] Get Page Attributes
	DPMIMAC 0507h,SPGATTR	  ; [1.0] Set Page Attributes
	DPMIMAC 0508h,MAPDEV	  ; [1.0] Map Device in Memory Block
	DPMIMAC 0509h,MAPCONV	  ; [1.0] Map Conventional Memory in Memory Block
	DPMIMAC 050Ah,GETMBLKSZ   ; [1.0] Get Memory Block Size & Base
	DPMIMAC 050Bh,GETMEMI	  ; [1.0] Get Memory Information

	DPMIMAC 0800h,GETP2L	  ; [0.9] Get Physical to Linear Address Mapping
	DPMIMAC 0801h,RELP2L	  ; [1.0] Free Physical to Linear Address Mapping

	DPMIMAC 0D00h,GETSHR	  ; [1.0] Allocate Shared Memory
	DPMIMAC 0D01h,RELSHR	  ; [1.0] Free Shared Memory
	DPMIMAC 0D02h,SERIALIZE   ; [1.0] Serialize on Shared Memory
	DPMIMAC 0D03h,RELSERIAL   ; [1.0] Free Serialization on Shared Memory

; Page Management Services

	DPMIMAC 0600h,LOCKLINREG  ; [0.9] Lock Linear Region
	DPMIMAC 0601h,UNLKLINREG  ; [0.9] Unlock Linear Region
	DPMIMAC 0602h,PAGEVM	  ; [0.9] Mark VM Region as Pageable
	DPMIMAC 0603h,RLCKVM	  ; [0.9] Relock VM Region
	DPMIMAC 0604h,GETPAGESIZ  ; [0.9] Get Page Size

	DPMIMAC 0700h,PGSELUNLK   ; [0.8] Mark Selector as Pageable
	DPMIMAC 0701h,PGSELFREE   ; [0.8] Mark Selector as Discardable
	DPMIMAC 0702h,PGUNLK	  ; [0.9] Mark Page as Pageable
	DPMIMAC 0703h,PGFREE	  ; [0.9] Mark Page as Discardable

; Debug Support Services

	DPMIMAC 0B00h,DBGSET	  ; [0.9] Set Debug Watchpoint
	DPMIMAC 0B01h,DBGCLR	  ; [0.9] Clear Debug Watchpoint
	DPMIMAC 0B02h,DBGQRY	  ; [0.9] Query State of Debug Watchpoint
	DPMIMAC 0B03h,DBGRST	  ; [0.9] Reset Debug Watchpoint

; Miscellaneous Services

	DPMIMAC 0400h,GETVER	  ; [0.9] Get Version Information
	DPMIMAC 0401h,GETCAP	  ; [1.0] Get DPMI Capabilities

	DPMIMAC 0A00h,VSAPI	  ; [0.9] Get Vendor-Specific API Entry Point

	DPMIMAC 0C00h,TSRSRV	  ; [1.0] Install Resident Service Provider CB
	DPMIMAC 0C01h,TSRXIT	  ; [1.0] Terminate & Stay Resident

	DPMIMAC 0E00h,EMUGET	  ; [1.0] Get Coprocessor Status
	DPMIMAC 0E01h,EMUSET	  ; [1.0] Set Coprocessor Emulation

CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
	assume	cs:PGROUP,ds:PGROUP

	extrn	INTPROC00Z:near
	extrn	GXTHDR:tbyte
	extrn	ERM_FVEC:fword

CODE16A ends			; End CODE16A segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_I31_PROG
@DPMI_I31_PROG: 		; Mark module start in .MAP file

;;;;	extrn	PRINTF32:near
	extrn	TellGXT_CR3:near
	extrn	RESETVARS:near
if @W9X
	extrn	VMM_ALLOC:near
endif
	extrn	GETBASE:near
	extrn	SETBASE:near
;;;;;;; extrn	WRAP_DISABLE:near
;;;;;;; extrn	WRAP_ENABLE:near
	extrn	KEYWAIT:near
	extrn	SET_GDT:near
	extrn	INTPROC31:near
	extrn	SET_PPL0STK:near
	extrn	ALLOCMEM:near
	extrn	DEALLOCMEM:near

	extrn	DW2HEX:near
	extrn	DD2HEX:near

	extrn	GETSET_LDTVAR:near
	extrn	GETSET_LDTFIX:near
	extrn	CLR_LDT:near
	extrn	DPMIFN_XLDT_SIZ:near
	extrn	DPMIFN_LPMSTK:near
	extrn	DPMIFN_RESTMEI:near

	extrn	SAVE_VMCREGS:near
	extrn	REST_VMCREGS:near

	extrn	PMINTCOM:near

	extrn	VMM_INIT:near
	extrn	VMM_INIT_CLIENT:near
	extrn	VMM_LOCK:near
	extrn	VMM_TERMINATE_CLIENT:near
	extrn	DPMIFN_CALL_RSPS:near

PMEXT_MAC macro NAME,N
	extrn	NAME&N:abs
	endm			; PMEXT_MAC


CNT	=	0
	rept	256

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	PMEXT_MAC PMIDEF,%N
CNT	=	CNT + 1
	endm			; REPT 256

CNT	=	0
	rept	32

; Extract high- and low-order digits from CNT in ASCII hex as L and H
; and catenate them as a two-character hex representation of CNT in N

H	substr	@HEX,1+(CNT/16),1
L	substr	@HEX,1+(CNT mod 16),1
N	catstr	H,L

	PMEXT_MAC PMFDEF,%N
	PMEXT_MAC VMFDEF,%N
CNT	=	CNT + 1
	endm			; REPT 32


	FPPROC	INT31 -- DPMI Interrupt Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI protected mode interrupt handler

If we're called from VM, we provide a VM to PM mode switch from
   DPMI_VM2PM.

If we're called from PM, and there are no DPMI clients active,
   service the call.

If we're called from PM, and there are DPMI clients active,
   give them a crack at this interrupt.  If we regain control,
   service the call.

|

	call	RESETVARS	; Keep variables up-to-date

	test	[esp].NRM_EFL.EHI,mask $VM ; Izit VM86 mode?
	jnz	near ptr INT31_INTRETVM ; Jump if so

; If the caller is at PL0, don't pass on to any DPMI clients

	test	[esp].INTDPI_CS,mask $PL ; Izit at PL0?
	jz	short INT31_INTRETPM ; Jump if so

; If there's a DPMI client active and it has hooked this interrupt,
; give it a crack at this interrupt.
; Note that if there are no DPMI clients active, then the corresponding
; bit in DPMI_CPIHOOK must be clear.

; Note that we can't use BT with immediate here as MASM 5.10 doesn't
; handle it correctly

	push	ds		; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPMI_CPIHOOK[31h/8],1 shl (31h mod 8) ; Izit hooked by current client?
	pop	ds		; Restore
	assume	ds:nothing	; Tell the assembler about it
	jz	short INT31_INTRETPM ; Jump if not

	mov	[esp].NRM_INTNO,4*31h+offset PGROUP:INTPROC00Z ; Mark as INT 31h

; The stack is mapped by INTDPI_STR

	push	@PMINTCOM_NRM	; Use application stack
	jmp	near ptr PMINTCOM ; Jump to common code


	public	INT31_INTRETPM
INT31_INTRETPM:
	PUSHD	0		; Put pseudo-error code onto stack

	pushad			; All EGP registers

	mov	ebp,esp 	; SS:EBP ==> INTXX_STR
				; (nothing above INTXX_SS is valid)
	REGSAVE <ds,es> 	; Save selectors

; Note that the above REGSAVE is mapped by I31_STR and must be
; consistent with it

; Split cases based upon the DPMI function # in AX

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPM_FLAG,mask $DPM_DPMI ; Is debugging desired?
	jz	short @F	; Jump if not

	SWATMAC 		; Call our debugger
@@:
	mov	es,SEL_DATA	; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	push	LPMSTK_FVEC.FSEL.EDD ; Save current LPM stack top
	push	LPMSTK_FVEC.FOFF ; ...

; Set new LPM stack top for nested callers if it's active
; and we're called from PM

	lea	eax,[ebp].INTXX_EIP ; SS:EAX ==> INTDPI_STR from PL3
	push	eax		; Pass the offset
	call	DPMIFN_LPMSTK	; Save new LPM stack as appropriate

COMMENT|

Note that although the IDT entry for this interrupt is marked as an
interrupt gate, we have been careful to be able to handle incoming
hardware interrupts.  This means that it's safe to enable interrupts
which is what the following code might do.  In fact, we set our
interrupt flag (IF) to that of the caller's giving us the effect of
being a trap gate.  We are not marked as a trap gate in the IDT
because we might become confused by the stack frame if we were to get
an interrupt (timer tick) immediately following the above PUSHD 0.
Were that to happen, ESP would match PPL0STK_DERR and we would think
that a Double Fault had occurred.

If we need to perform data accesses without interruption use
PUSHF/CLI/.../POPF.

|

	push	[ebp].INTXX_EFL ; Get caller's flags
	and	[esp].ELO,not ((mask $NT) or (mask $DF) or (mask $TF)) ; NT=TF=DF=0
	popfd			; Put caller's IF into effect

	movzx	ebx,[ebp].INTXX_EAX.ELO ; Get the function #

	test	ebx,mask $MAXDFN_MD ; Any hashed-out bits set?
	jnz	short INT31_ERR_NOFNS ; Jump if so

	cmp	ebx,@MAXDFN	; Izit above the maximum DPMI function?
	ja	short INT31_ERR_NOFNS ; Jump if so
				; EBX = 0000 xxxx 000x xxxx
	shl	bl,width $MAXDFN_MD ; Shift up low-order bits
				; next to high-order bits
				; EBX = 0000 xxxx xxxx x000
	shr	ebx,width $MAXDFN_MD ; Shift down to byte index
				; EBX = 0000 000x xxxx xxxx
	movzx	ebx,DPMI_VAL[ebx] ; Get the function code byte

	jmp	DPMI_ACT[ebx*(type DPMI_ACT)] ; Take appropriate action

	assume	ds:nothing,es:nothing ; Tell the assembler about it


	public	INT31_ERR_MAC
INT31_ERR_MAC:
	mov	[ebp].INTXX_EAX.ELO,@DOSERR_XMAC ; Mark as MAC error

	jmp	INT31_ERR	; Join common error exit code


	public	INT31_ERR_MNF
INT31_ERR_MNF:
	mov	[ebp].INTXX_EAX.ELO,@DOSERR_MNF ; Mark as MAC not found error

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_NODMEM
INT31_ERR_NODMEM:
	mov	[ebp].INTXX_EAX.ELO,@DOSERR_XMEM ; Mark as insufficient DOS memory

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_NOFNS
INT31_ERR_NOFNS:
	mov	[ebp].INTXX_EAX.ELO,8001h ; Mark as unsupported function

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_INVSTATE
INT31_ERR_INVSTATE:
	mov	[ebp].INTXX_EAX.ELO,8002h ; Mark as invalid state

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_REQCAN
INT31_ERR_REQCAN:
	mov	[ebp].INTXX_EAX.ELO,8005h ; Mark as serial request cancelled

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_NOSEL
INT31_ERR_NOSEL:
	mov	[ebp].INTXX_EAX.ELO,8011h ; Mark as no selectors available

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_NOMEM
INT31_ERR_NOMEM:
	mov	[ebp].INTXX_EAX.ELO,8012h ; Mark as no memory available

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_NOPHYSMEM
INT31_ERR_NOPHYSMEM:
	mov	[ebp].INTXX_EAX.ELO,8013h ; Mark as no physical mem available

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_NOVMC
INT31_ERR_NOVMC:
	mov	[ebp].INTXX_EAX.ELO,8015h ; Mark as no VM callback available

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_NOHNDL
INT31_ERR_NOHNDL:
	mov	[ebp].INTXX_EAX.ELO,8016h ; Mark as no handles available

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_EXCLUSIVE
INT31_ERR_EXCLUSIVE:
	mov	[ebp].INTXX_EAX.ELO,8018h ; Mark as already serialized

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_SHARED
INT31_ERR_SHARED:
	mov	[ebp].INTXX_EAX.ELO,8019h ; Mark as already serialized

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_INVVAL
INT31_ERR_INVVAL:
	mov	[ebp].INTXX_EAX.ELO,8021h ; Mark as invalid value

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_INVSEL
INT31_ERR_INVSEL:
	mov	[ebp].INTXX_EAX.ELO,8022h ; Mark as invalid selector

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_INVHNDL
INT31_ERR_INVHNDL:
	mov	[ebp].INTXX_EAX.ELO,8023h ; Mark as invalid handle

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_INVVMC
INT31_ERR_INVVMC:
	mov	[ebp].INTXX_EAX.ELO,8024h ; Mark as invalid VM callback address

	jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR_INVADDR
INT31_ERR_INVADDR:
	mov	[ebp].INTXX_EAX.ELO,8025h ; Mark as invalid linear address

;;;;;;; jmp	short INT31_ERR ; Join common error exit code


	public	INT31_ERR
INT31_ERR:
	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	test	DPM_FLAG,mask $DPM_DPMIERR ; Debugging on DPMI errors?
	jz	short @F	; Jump if not

	SWATMAC 		; Call our debugger
@@:
	or	[ebp].INTXX_EFL.ELO,mask $CF ; Set the carry flag

	jmp	short INT31_EXIT ; Join common exit code


	assume	ds:nothing,es:nothing ; Tell the assembler about it

	public	INT31_CLC
INT31_CLC:
	and	[ebp].INTXX_EFL.ELO,not (mask $CF) ; Clear the carry flag
INT31_EXIT:
	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	cli			; Disable interrupts to avoid HW interrupt
				; after POPAD looking like a VM interrupt
	pop	LPMSTK_FVEC.FOFF ; Restore
	pop	LPMSTK_FVEC.FSEL.EDD ; ...

	REGREST <es,ds> 	; Restore selectors
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	popad			; Restore all EGP registers

	add	esp,size INTXX_ERR ; Strip off pseudo-error code

	iretd			; Return to caller (PM only)


COMMENT|

INT 31h has been called from VM.

If it's from our device driver, then it's a DPMI request
to switch from VM to PM.

If not, continue with INTPROC31.

|

INT31_INTRETVM:
	cmp	[esp].NRM_CS,seg YGROUP ; Izit from high DOS?
	org	$-2
	public	INT31A_HIMEM_CS
INT31A_HIMEM_CS label near	; Address previous segment for relocation
	org	$+2
	je	short INT31_VM2PM ; Jump if so

	cli			; Disallow interrupts as per interrupt gate
				; expectations of all other INTPROCxx entries
	jmp	INTPROC31	; Call as VM INT 31h


COMMENT|

Switch from VM to PM

On entry (in PL3 stack):

AX	=	flags:	Bit 0 = 1 if 32-bit application
			      = 0 if 16-bit ...
CX	=	segment of PSP
ES:BX	==>	DTA
SS:SP[0] ==>	caller's ES (segment of HPDA)
     [2] ==>	...	 CX (to be restored)
     [4] ==>	...	 BX ...
     [6] ==>	...	 AX ...
     [8] ==>	...	 CS:IP

On exit (in DPMI TSS):

CF	=	0 if successful
CS	=	16-bit	   64KB selector mapping caller's CS
DS	=	16-/32-bit 64KB selector mapping caller's DS
ES	=	16-/32-bit 100h selector mapping caller's PSP
FS	=	0
GS	=	0
SS	=	16-/32-bit 64KB selector mapping caller's SS

CF	=	1 if not successful
AX	=	8011 if descriptor unavailable
	=	8012 if linear memory unavailable (dynamic save area)
	=	8021 if invalid value (mismatch of 16- vs. 32-bit clients)
		80FF is used internally; it will never be returned to
		a caller, but is used to indicate that Ctrl-Break was
		pressed during swapfile initialization.

|

INT31_VM2PM:
	PUSHD	0		; Put pseudo-error code onto stack

	pushad			; All EGP registers

	cld			; Ensure string ops forwardly
	mov	ebp,esp 	; SS:EBP ==> INTXX_STR

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	es,SEL_DATA	; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	mov	gs,SEL_4GB	; Get AGROUP data selector at PL0
	assume	gs:AGROUP	; Tell the assembler about it

	jmp	INT31_VRM2PM_COM ; Call common subroutine


;;;;;;; call	INT31_VRM2PM_COM ; Call common subroutine
;;;;;;; SWATMAC ERR		; We should never get here???

	assume	ds:DGROUP,es:DGROUP  ; Tell the assembler about it
	assume	fs:nothing,gs:AGROUP ; Tell the assembler about it

	public	INT31_VM2PM_RET
INT31_VM2PM_RET:

; This might be a spurious task switch caused by an IRET/D with NT set
; If $I31_EXIT is set, it's valid; if not, it's spurious

	clts			; Clear the Task Switched flag in CR0

	btr	I31_FLAG,$I31_EXIT ; Reset and check
	jc	short INT31_VM2PM_RETOK ; Jump if valid

	mov	edx,PCURTSS	; Get offset in DGROUP of current TSS

; Set the base of the new LDT

	push	DGROUP:[edx].TSS_LDT.EDD ; Pass LDT selector as dword
	push	DGROUP:[edx].DPTSS_LaLDT ; ...	LDT base address
	call	SETBASE 	; Set the base address

	lldt	DGROUP:[edx].TSS_LDT ; Get new LDT
	ltr	DGROUP:[edx].DPTSS_SEL ; Set new Task Register (CPU marks as busy)

; Tell GXT about the new CR3

	mov	eax,DGROUP:[edx].TSS_CR3 ; Get incoming CR3
	mov	cr3,eax 	; Tell the CPU about it

	push	eax		; Pass physical address
	PUSHD	0		; ...  linear address (TBD)
	call	TellGXT_CR3	; Tell 'em (after the fact)

	test	DPM_FLAG,mask $DPM_DPMISPURNT ; Should we signal INT 01h?
	jz	short @F	; Jump if not

	SWATMAC 		; Call our debugger
@@:
	jmp	INT31_VRM2PM_TS ; Go around again


	assume	ds:DGROUP,es:DGROUP  ; Tell the assembler about it
	assume	fs:nothing,gs:AGROUP ; Tell the assembler about it

INT31_VM2PM_RETOK:

; If we've been told not to switch stacks, the value of ESP is already set

	test	I31_FLAG,@I31_NOSWITCH ; Should we use the same stack?
	jnz	short INT31_VM2PM_RETOK1 ; Jump if so

; Setup our return stack pointer with room for INTCOM_STR.  If we
; exit due to a fault, we need this to address the faulting CS|EIP.
; If we exit normally, we need this space defined to return to VM.

	push	eax		; Save for a moment

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	mov	eax,DGROUP:[eax].DPTSS_PLNKTSS ; Back off to previous TSS
	mov	eax,DGROUP:[eax].TSS_ESP0 ; Get top of MAX stack
	sub	eax,size INTCOM_STR ; Make room

	xchg	eax,[esp]	; Swap with original EAX

	mov	esp,[esp]	; Set to new location
INT31_VM2PM_RETOK1:
	test	I31_FLAG,@I31_FAULT ; Did we terminate because of a fault?
	jnz	short @F	; Jump if so (error code already on stack)

	PUSHD	0		; Make room for pseudo-error code
@@:

; At this point, the DPMI client has terminated (via DOS function 4C or
; because of a fault) and we must clean up.  Restart execution in VM
; in the host private data area at the INT 21h function there.
; Note that we return with interrupts disabled as that's how we
; entered the last TSS.

; The stack has room on it for INTCOM_STR preceded by an error code
; If we terminated due to a fault, the INTDPF_STR portion of the stack
; is meaningful; otherwise, the contents of the stack are undefined.

	pushad			; All EGP registers

	cld			; Ensure string ops forwardly
	mov	ebp,esp 	; SS:EBP ==> INTXX_STR
				; (nothing above INTXX_EFL is valid)

; Restore LAST_INTCOM, LAST_INTFLG, PL0 stack values, and LPM stack top

	mov	edx,PCURTSS	; Get offset in DGROUP of current TSS

	mov	eax,DGROUP:[edx].DPTSS_INTCOM ; Get previous value
	mov	LAST_INTCOM,eax ; Restore it

	mov	eax,DGROUP:[edx].DPTSS_INTFLG ; Get previous value
	mov	LAST_INTFLG,eax ; Restore it

	mov	eax,DGROUP:[edx].DPTSS_STKERR ; Get previous value
	mov	PPL0STK_ERR,eax ; Restore it

	mov	eax,DGROUP:[edx].DPTSS_STKDNRM ; Get previous value
	mov	PPL0STK_DNRM,eax ; Restore it

	mov	eax,DGROUP:[edx].DPTSS_STKDERR ; Get previous value
	mov	PPL0STK_DERR,eax ; Restore it

	mov	eax,DGROUP:[edx].DPTSS_STKNRM ; Get previous value
	mov	PPL0STK_NRM,eax ; Restore it

	mov	eax,DGROUP:[edx].DPTSS_STKMIN ; Get previous value
	mov	PPL0STK_MIN,eax ; Restore it

	mov	eax,DGROUP:[edx].DPTSS_STKMAP ; Get previous value
	mov	PPL0STK_MAP,eax ; Restore it

	mov	ebx,DGROUP:[edx].DPTSS_PLNKTSS ; Get offset in DGROUP of prev TSS
	mov	eax,DGROUP:[ebx].DPTSS_LPMSTK_FVEC.FOFF ; Get offset of LPM stack top
	mov	LPMSTK_FVEC.FOFF,eax ; Restore it
	mov	ax,DGROUP:[ebx].DPTSS_LPMSTK_FVEC.FSEL ; Get offset of LPM stack top
	mov	LPMSTK_FVEC.FSEL,ax ; Restore it
	mov	eax,DGROUP:[ebx].DPTSS_LPMSTK_CNT ; Get previous LPM stack usage count
	mov	LPMSTK_CNT,eax	; Restore it

; Restore DPMI client's EGP registers from the previous TSS

	mov	eax,DGROUP:[edx].TSS_EAX ; Get caller's EAX
	mov	[ebp].INTXX_EAX,eax ; Save on stack
	mov	eax,DGROUP:[edx].TSS_EBX ; ...	 EBX
	mov	[ebp].INTXX_EBX,eax ; ...
	mov	eax,DGROUP:[edx].TSS_ECX ; ...	 ECX
	mov	[ebp].INTXX_ECX,eax ; ...
	mov	eax,DGROUP:[edx].TSS_EDX ; ...	 EDX
	mov	[ebp].INTXX_EDX,eax ; ...
	mov	eax,DGROUP:[edx].TSS_ESI ; ...	 ESI
	mov	[ebp].INTXX_ESI,eax ; ...
	mov	eax,DGROUP:[edx].TSS_EDI ; ...	 EDI
	mov	[ebp].INTXX_EDI,eax ; ...
	mov	eax,DGROUP:[edx].TSS_EBP ; ...	 EBP
	mov	[ebp].INTXX_EBP,eax ; ...

; De-link this TSS if we faulted in the middle of the chain
; Note that we *MUST* call this routine before we have reset PCURTSS.

	call	DPMIFN_DELINKTSS ; De-link 'em

; Back off to previous TSS and its selector
; Note we still need the value in EDX below

	call	DPMIFN_PLNKTSS	; Back off to previous TSS with EDX=PCURTSS

; If we terminated because of a fault, display an appropriate message
; Note we *MUST NOT* call this routine before we have reset PCURTSS and
; DPMITYPE.

	call	DPMIFN_FAULT	; Check it out using EDX = old PCURTSS

;;; ; If we previously enabled the 1MB wrap, ensure it's restored to
;;; ; its previous state
;;; ; Note we wait until after we've used and de-allocated the dynamic save
;;; ; area in case it's in the wrap region.
;;;
;;;	     test    DGROUP:[edx].DPTSS_FLAG,mask $DPTSS_WRAP ; Izit changed?
;;;	     jz      short @F	    ; Jump if so
;;;
;;; ; Re-map the first 64KB of memory above the 1MB limit back to first 64KB
;;; ; This also flushes the TLB if CF=0 on return
;;;
;;;	     and     GLB_FLAG,not @GLB_X1MB ; Disable the virtual A20 line
;;;	     call    WRAP_ENABLE    ; Enable the 1MB wrap, ignore return
;;; @@:
;;;
; Get the segment of the current PSP in case it's been switched on us
; Note that we can't use the DOSCALL macro as the value of LAST_INTCOM
; might not point to an INTXX_STR frame (it might be that of the DOS
; @EXITRC function and thus it's an INTDPI_STR frame).

;;;;;;; DOSCALL @GETPS0 	; Get PSP into BX
	push	edx		; Use HPDA stack in here
	call	DPMIFN_GETPSP	; Get PSP segment into BX using
				; the HPDA stack from EDX
	movzx	ecx,bx		; Copy to convert to bytes
	shl	ecx,4-0 	; Convert from paras to bytes

; Address the HPDA

	mov	ebx,DGROUP:[edx].DPTSS_LaHPDA ; Get linear address of HPDA

; Convert the caller's environment selector back to a segment

	mov	ax,AGROUP:[ebx].HPDA_ENVSEG ; Get the original environment segment

	assume	gs:PSPGRP	; Tell the assembler about it
	mov	PSP_ENVIR_PTR[ecx],ax ; Set the environment selector
	assume	gs:AGROUP	; Tell the assembler about it

; Zap the Terminate, Ctrl-Break, and Critical Error addresses in the HPDA
; so we continue with the next handler in sequence

	mov	AGROUP:[ebx].HPDA_I22DEF[0].ELO,@OPCOD_JMPS or \
				((HPDA_I22DEF2-HPDA_I22DEF-2) shl 8)
	mov	AGROUP:[ebx].HPDA_I23DEF[0].ELO,@OPCOD_JMPS or \
				((HPDA_I23DEF2-HPDA_I23DEF-2) shl 8)
	mov	AGROUP:[ebx].HPDA_I24DEF[0].ELO,@OPCOD_JMPS or \
				((HPDA_I24DEF2-HPDA_I24DEF-2) shl 8)

; If this client is BC 3.0 (DPMILOAD.EXE), it has clobbered the
; INT 22h address in the PSP by setting the offset but not the segment.
; Check for that and make it all better.

	call	DPMIFN_CHK22	; Fix it if it's broken

; If we're returning to the caller directly (as opposed to the
; INT 21h address in the PSP), skip restoring the INTXX_xxx registers

	test	I31_FLAG,@I31_RETCALL ; Return to caller?
	jnz	short INT31_VM2PM_RETOK3 ; Jump if so

; Note that if we don't use "dword ptr" on the HPDA_xxx values
; below MASM generates incorrect .OBJ code without any warning

	mov	eax,ebx 	; Get linear address of HPDA
	shr	eax,4-0 	; Convert from bytes to paras
	mov	[ebp].INTXX_CS,ax ; Save as return segment
	mov	[ebp].INTXX_EIP,dword ptr HPDA_INT21 ; Save as return EIP
	mov	[ebp].INTXX_SS,ax ; Save as return stack
	movzx	eax,HPDASTK_TOP ; Get offset of top of HPDA stack
	mov	[ebp].INTXX_ESP,eax ; Save as return ESP
	mov	[ebp].INTXX_EFL,(mask $VMHI) or (@VMIOPL shl $IOPL) or (mask $IF) ; Save flags

; Ensure the latter part of the stack is addressible

	lea	eax,[ebp].INTXX_GS ; Get highest offset

	cmp	eax,PPL0STK_MAX ; Izit too big?
	jae	short @F	; Jump if so

; Restore VM segment registers to the values present
; when the VM to PM switch was done

	mov	ax,AGROUP:[ebx].HPDA_vDS ; Get original DS
	mov	[ebp].INTXX_DS,ax ; Save as return DS
	mov	ax,AGROUP:[ebx].HPDA_vES ; ...	 ES
	mov	[ebp].INTXX_ES,ax ; ...     ES
	mov	ax,AGROUP:[ebx].HPDA_vFS ; ...	 FS
	mov	[ebp].INTXX_FS,ax ; ...     FS
	mov	ax,AGROUP:[ebx].HPDA_vGS ; ...	 GS
	mov	[ebp].INTXX_GS,ax ; ...     GS
@@:
	mov	ax,EXITRC	; Mark as exiting with return code
	mov	[ebp].INTXX_EAX.ELO,ax

; If we are terminating due to a TSR (resident service provider) request,
; then set the DOS function to 31h (keep process) and load the count of
; paragraphs to keep from global.

	xor	cx,cx		; A convenient zero
	xchg	cx,TSRsize	; Pick up size to TSR
	jcxz	short @F	; Jump if already zero

	mov	[ebp].INTXX_EDX.ELO,cx ; Store for DOS call
	mov	[ebp].INTXX_EAX.ELO.HI,@KEEPRC ; Set function code
@@:
INT31_VM2PM_RETOK3:
	and	I31_FLAG,@I31_PERCLIENT ; Isolate DPMI client-specific flags

	push	PVMTSS		; Pass offset in DGROUP of the 1st TSS
	call	DPMIFN_LMSW	; Put MSW and INT 07h values into effect

	test	I31_FLAG,@I31_RETCALL ; Return to caller?
	jnz	short INT31_IRETD ; Jump if so

; Push the current CS:IP onto the RM stack as the return address
; and set the current CS:IP to FreeAllMem

	movzx	ebx,[ebp].INTXX_SS ; Get the RM stack segment
	shl	ebx,4-0 	; Convert from paras to bytes
	sub	[ebp].INTXX_ESP,2+2 ; Make room for far return
	add	ebx,[ebp].INTXX_ESP ; Plus the RM stack offset

	mov	ax,HIMEM_CS	; Get segment of FreeAllMem
	xchg	ax,[ebp].INTXX_CS ; Swap with RM CS
	mov	AGROUP:[ebx].IRET_CS,ax ; Save on RM stack

	lea	eax,YGROUP:FreeAllMem ; Get offset of FreeAllMem
	xchg	eax,[ebp].INTXX_EIP ; Swap with RM eIP
	mov	AGROUP:[ebx].IRET_IP,ax ; Save on RM stack

	popad			; Restore

	add	esp,size INTXX_ERR ; Strip off pseudo-error code

	jmp	GXTHDR.GXTHDR_PM2RM_FVEC ; Switch from PM to RM


INT31_IRETD:
	popad			; Restore all EGP registers

	add	esp,size INTXX_ERR ; Strip off pseudo-error code

	jmp	ERM_FVEC	; Continue in VM in the HPDA at INT 21h

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT31	endp			; End INT31 procedure
	NPPROC	CopyXMSMem -- Copy XMS Memory
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Copy XMS memory

|

	pushad			; Save registers

	assume	gs:YGROUP	; Tell the assembler a white lie

; Mark available XMS bytemap entries

	movzx	ebx,HIMEM_CS	; Get segment of YGROUP
	shl	ebx,4-0 	; Convert from paras to bytes

	mov	ecx,YY_XMSMEM_CNT[ebx] ; Get # active entries
	mov	XMSMEM_CNT,ecx	; Save in DGROUP
	jecxz	CopyXMSMemDone	; Jump if none
	xor	esi,esi 	; Initialize index into table
CopyXMSMemNext:
	mov	ax,YY_XMSMEM[esi+ebx].XMSMEM_HNDL ; Get the handle
	mov	XMSMEM[esi].XMSMEM_HNDL,ax ; Save in DGROUP

	mov	eax,YY_XMSMEM[esi+ebx].XMSMEM_LEN ; Get the length
	mov	XMSMEM[esi].XMSMEM_LEN,eax ; Save in DGROUP

	mov	eax,YY_XMSMEM[esi+ebx].XMSMEM_PA ; Get the Physical Address
	mov	XMSMEM[esi].XMSMEM_PA,eax ; Save in DGROUP

	add	esi,type XMSMEM_STR ; Skip to next entry

	loop	CopyXMSMemNext	; Jump if more entries
CopyXMSMemDone:
	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CopyXMSMem endp 		; End CopyXMSMem procedure
	NPPROC	MarkXMSMem -- Mark XMS Memory As Available
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Mark XMS memory as available

|

	pushad			; Save registers

; Mark available XMS bytemap entries

	mov	ecx,XMSMEM_CNT	; Get # active entries
	jecxz	MarkXMSMemDone	; Jump if none
	xor	esi,esi 	; Initialize index into table
MarkXMSMemNext:
	push	ecx		; Save for a moment

	mov	ecx,XMSMEM[esi].XMSMEM_LEN ; Get the block's length in 1KB
	mov	edi,XMSMEM[esi].XMSMEM_PA ; ...       physical address
;;;	    and     edi,not (4*1024-1) ; Round down to 4KB boundary
;;;
;;; ; Translate the physical address to a linear one in the MM's CR3
;;;
;;;	    mov     eax,cr3	    ; Get the MM's CR3
;;;
;;;	    push    dword ptr (1*1024*1024) ; Pass minimum acceptable linear address
;;;	    push    eax 	    ; Pass the MM's CR3
;;;	    push    edi 	    ; Pass the physical address (/4KB)
;;;	    call    PHYS2MMLIN	    ; Translate physical addr to MM-linear in EAX
;;; ;;;;;;; jc	    short FIND_XMS_MMLIN_EXIT ; Jump if not found (note CF=0)
;;;
;;;	    mov     edi,XMSMEM[esi].XMSMEM_PA ; Get the block's physical address
;;;	    and     edi,4*1024-1    ; Isolate the offset in 4KB
;;;	    add     edi,eax	    ; Add to get linear address
;;;
	shr	edi,10-0	; Convert from bytes to 1KB
	add	edi,PXMSBMAP	; Plus start of XMS bytemap

	mov	al,00h		; No bits set means available
    rep stos	DGROUP:[edi].LO ; Mark as available

	pop	ecx		; Restore

	add	esi,type XMSMEM_STR ; Skip to next entry

	loop	MarkXMSMemNext	; Jump if more entries
MarkXMSMemDone:
	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

MarkXMSMem endp 		; End MarkXMSMem procedure
	NPPROC	INT31_RM2PM -- INT 31h RM to PM Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

INT 31h RM to PM handler

On entry:

SS:EBP	==>	RM2PM_STR

|

	REGSAVE <ds,es,gs>	; Save registers

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	es,SEL_DATA	; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	mov	gs,SEL_4GB	; Get AGROUP data selector at PL0
	assume	gs:AGROUP	; Tell the assembler about it

;;;;;;; mov	DPMI_EXIT,0	; Clear DPMI_EXIT count

	cmp	DPMITYPE,@DPMITYPEXX ; Any DPMI clients active?
	jne	near ptr INT31_RM2PM_ENAPG ; Jump if so

; Copy memory from YY_XMSMEM to XMSMEM

	call	CopyXMSMem	; Copy it

; Mark memory as available

	call	MarkXMSMem	; Mark it

; Initialize global CR3

; Up to physical memory, allocate a PDE for each 4MB

	push	es		; Save for a while

	mov	eax,cr0 	; Get register with Paging bit
	mov	CurCR0,eax	; Save for later use

; Split cases depending upon Paging state

	test	CurCR0,mask $PG ; Izit enabled?
	jz	short INT31_RM2PM_XPG1 ; Jump if not

	push	gs		; Save for a moment

	mov	gs,GXTHDR.GXTHDR_SELCR3 ; Get CR3 selector
	assume	gs:nothing	; Tell the assembler about it

; Copy the incoming CR3 to OffCR3

	xor	esi,esi 	; GS:ESI ==> incoming CR3
	mov	edi,OffCR3	; Get offset in DGROUP of global CR3
	mov	ecx,1024	; # dwords in 4KB
    rep movs	DGROUP:[edi].EDD,gs:[esi].EDD ; Copy to global CR3

	pop	gs		; Restore
	assume	gs:AGROUP	; Tell the assembler about it

; Switch to the new CR3

	mov	eax,PaCR3	; Get physical address of CR3
	mov	cr3,eax 	; Tell the CPU about it

	mov	ebx,OffCR3	; Get linear address of CR3
	add	ebx,DGRBASE	; Plus linear address of DGROUP

; Tell GXT about the new CR3

	push	PaCR3		; Pass physical address
	push	ebx		; ...  linear address
	call	TellGXT_CR3	; Tell 'em (after the fact)

; Skip over initial PDes

	mov	edi,OffCR3	; Get offset in DGROUP of global CR3
	add	edi,DGRBASE	; Plus linear address of DGROUP
				; to get linear address
@@:
	cmp	AGROUP:[edi].EDD,0 ; Izit available?
	je	short @F	; Jump if so

	add	edi,4		; Skip over it

	jmp	@B		; Go around again


@@:
	jmp	short INT31_RM2PM_PGCOM1 ; Join common code


INT31_RM2PM_XPG1:
	mov	edi,OffCR3	; Get offset in DGROUP of global CR3
	add	edi,DGRBASE	; Plus linear address of DGROUP
				; to get linear address
INT31_RM2PM_PGCOM1:
	mov	PDE_Start,edi	; Save for later use
	mov	OffALLOCMEM,0	; Initialize for local calls to ALLOCMEM

	mov	es,SEL_4GB	; Get AGROUP data selector at PL0
	assume	es:AGROUP	; Tell the assembler about it

@PDELOC3 equ	(4*1024)-(4*4)	; Location for new PDE
@PDELIN3 equ	@PDELOC3 shl (22-2) ; Linear address of @PDELOC3

	mov	ebx,OffCR3	; Get offset in DGROUP of global CR3
	mov	eax,cr3 	; Get current PDBR
	and	eax,@PTE_FRM	; Isolate the 4KB frame
	or	eax,@PTE_URP	; Mark as User/Read-write/Present
	mov	DGROUP:[ebx+@PDELOC3].EDD,eax ; Address it from @PDELIN

	mov	ecx,PHYSIZE	; Pick up total machine size in bytes
	add	ecx,4*1024*1024-1 ; Round up to 4MB
;;;;;;; and	ecx,not (4*1024*1024-1) ; ...boundary
	shr	ecx,22-0	; Convert from bytes to 4MB pages
	mov	edx,@PTE_URP	; Mark as User/Read-write/Present
				; Initialize physical address of PDE (/4MB)
	mov	esi,ecx 	; Save for later use
INT31_RM2PM1:
	push	@ALLOC_VCPI	; Tell 'em what kind of memory we're allocating
	push	4*1024		; Pass # bytes to allocate
	call	ALLOCMEM	; Allocate 'em
				; Return with EBX = physical address of memory
	jnc	short @F	; Jump if OK

	SWATMAC ERR		; Call our debugger
@@:
	mov	eax,@PTE_URP	; Mark as User/Read-write/Present
	or	eax,ebx 	; Include physical address

	test	CurCR0,mask $PG ; Izit enabled?
	jz	short @F	; Jump if not

	mov	ebx,edi 	; Copy offset in AGROUP
	sub	ebx,DGRBASE	; Less linear address of DGROUP
				; to get offset in DGROUP
	sub	ebx,OffCR3	; Less offset in DGROUP of start
				; to get offset in CR3 (/4)
	shl	ebx,(12-2)-0	; Convert from 4KB in dwords to bytes
	add	ebx,@PDELIN3	; Add in linear address of CR3
@@:
	stos	AGROUP:[edi].EDD ; Save in CR3

	REGSAVE <ecx,edi>	; Save for a moment

	mov	ecx,1024	; # PTEs in a PDE
	mov	eax,edx 	; Get physical address (/4MB)
	mov	edi,ebx 	; Copy linear address of PDE
@@:
	stos	AGROUP:[edi].EDD ; Save in PDE
	add	eax,4*1024	; Skip to next page
	loop	@B		; Jump if more PTEs

	REGREST <edi,ecx>	; Restore

	mov	edx,eax 	; Skip to next 4MB page

	loop	INT31_RM2PM1	; Jump if more PDEs

; Fill in the trailing entries in CR3

	mov	ecx,1024	; Get # entries in CR3
	sub	ecx,esi 	; Less # filled in so far
	mov	eax,@PTE_URP	; Mark as User/Read-write/Present
	or	eax,0FFFFF000h	; Include physical address
    rep stos	AGROUP:[edi].EDD ; Save in CR3

	pop	es		; Restore
	assume	es:DGROUP	; Tell the assembler about it

; Calculate the linear address offset for ALLOCMEM/DEALLOCMEM

	mov	eax,PDE_Start	; Get start of PDE
	sub	eax,DGRBASE	; Less linear address of DGROUP
				; to get offset in DGROUP
	sub	eax,OffCR3	; Less offset in DGROUP of start
				; to get offset in CR3 (/4)
	shl	eax,(22-2)-0	; Convert from 4MB in dwords to bytes
	mov	OffALLOCMEM,eax ; Save for later use
INT31_RM2PM_ENAPG:

; Enable paging

	mov	eax,PaCR3	; Get physical address of CR3

	cmp	DPMITYPE,@DPMITYPEXX ; Any DPMI clients active?
	je	short @F	; Jump if not

	mov	ax,VM2PM_TSS	; Get current TSS

	push	eax		; Pass the selector
	call	GETBASE 	; Return with EAX = base address

	mov	eax,AGROUP:[eax].TSS_CR3 ; Get the incoming CR3
@@:
	mov	cr3,eax 	; Tell the CPUI about it

; Tell GXT about the new CR3

	push	eax		; Pass physical address
	PUSHD	0		; ...  linear address
	call	TellGXT_CR3	; Tell 'em (after the fact)

;;;; ; Enable paging
;;;;
;;;;	     mov     eax,PaCR3	     ; Get physical address of CR3
;;;;	     mov     cr3,eax	     ; Tell the CPU about it
;;;;
;;;;	     mov     ebx,OffCR3      ; Get linear address of CR3
;;;;	     add     ebx,DGRBASE     ; Plus linear address of DGROUP
;;;;
;;;; ; Tell GXT about the new CR3
;;;;
;;;;	     push    PaCR3	     ; Pass physical address
;;;;	     push    ebx	     ; ...  linear address
;;;;	     call    TellGXT_CR3     ; Tell 'em (after the fact)
;;;;
	mov	eax,cr0 	; Get current Control Register
	or	eax,mask $PG	; Enable paging
	mov	cr0,eax 	; Tell the CPU about it

; Setup the stack so that SS:EBP ==> INTXX_STR

	push	[ebp].RM2PM_EPRM.EPRM_GS.EDD;INTXX_GS w/filler
	push	[ebp].RM2PM_EPRM.EPRM_FS.EDD;...   FS w/filler
	push	[ebp].RM2PM_EPRM.EPRM_DS.EDD;...   DS w/filler
	push	[ebp].RM2PM_EPRM.EPRM_ES.EDD;...   ES w/filler
	push	[ebp].RM2PM_EPRM.EPRM_SS.EDD;...   SS w/filler
	push	[ebp].RM2PM_EPRM.EPRM_ESP  ; ...   ESP
	push	[ebp].RM2PM_EPRM.EPRM_EFL  ; ...   EFL
	push	[ebp].RM2PM_EPRM.EPRM_CS.EDD;...   CS w/filler
	push	[ebp].RM2PM_EPRM.EPRM_EIP  ; ...   EIP
	PUSHD	0			   ; ...   ERR
	push	[ebp].RM2PM_EGP.PUSHAD_EAX ; ...   EAX
	push	[ebp].RM2PM_EGP.PUSHAD_ECX ; ...   EBX
	push	[ebp].RM2PM_EGP.PUSHAD_EDX ; ...   EDX
	push	[ebp].RM2PM_EGP.PUSHAD_EBX ; ...   EBX
	push	[ebp].RM2PM_EGP.PUSHAD_ESP ; ...   ESP
	push	[ebp].RM2PM_EGP.PUSHAD_EBP ; ...   EBP
	push	[ebp].RM2PM_EGP.PUSHAD_ESI ; ...   ESI
	push	[ebp].RM2PM_EGP.PUSHAD_EDI ; ...   EDI

;;;;;;; mov	eax,ebp 	; Copy old EBP
	mov	ebp,esp 	; SS:EBP ==> INTXX_STR
				; (nothing above INTXX_EFL is valid)
	jmp	short INT31_VRM2PM_COM ; Call common subroutine


;;;;;;; push	eax		; Save old EBP
;;;;;;; call	INT31_VRM2PM_COM ; Call common subroutine
;;;;;;; pop	ebp		; Restore old EBP
;;;;;;;
;;;;;;; pop	[ebp].RM2PM_EGP.PUSHAD_EDI ; INTXX_EDI
;;;;;;; pop	[ebp].RM2PM_EGP.PUSHAD_ESI ; ...   ESI
;;;;;;; pop	[ebp].RM2PM_EGP.PUSHAD_EBP ; ...   EBP
;;;;;;; pop	[ebp].RM2PM_EGP.PUSHAD_ESP ; ...   ESP
;;;;;;; pop	[ebp].RM2PM_EGP.PUSHAD_EBX ; ...   EBX
;;;;;;; pop	[ebp].RM2PM_EGP.PUSHAD_EDX ; ...   EDX
;;;;;;; pop	[ebp].RM2PM_EGP.PUSHAD_ECX ; ...   ECX
;;;;;;; pop	[ebp].RM2PM_EGP.PUSHAD_EAX ; ...   EAX
;;;;;;; add	esp,4			   ; ...   ERR
;;;;;;; pop	[ebp].RM2PM_EPRM.EPRM_EIP  ; ...   EIP
;;;;;;; pop	[ebp].RM2PM_EPRM.EPRM_CS.EDD;...   CS w/filler
;;;;;;; pop	[ebp].RM2PM_EPRM.EPRM_EFL  ; ...   EFL
;;;;;;; pop	[ebp].RM2PM_EPRM.EPRM_ESP  ; ...   ESP
;;;;;;; pop	[ebp].RM2PM_EPRM.EPRM_SS.EDD;...   SS w/filler
;;;;;;; pop	[ebp].RM2PM_EPRM.EPRM_ES.EDD;...   ES w/filler
;;;;;;; pop	[ebp].RM2PM_EPRM.EPRM_DS.EDD;...   DS w/filler
;;;;;;; pop	[ebp].RM2PM_EPRM.EPRM_FS.EDD;...   FS w/filler
;;;;;;; pop	[ebp].RM2PM_EPRM.EPRM_GS.EDD;...   GS w/filler
;;;;;;;
;;;;;;; REGREST <gs,es,ds>	; Restore
;;;;;;; assume	ds:nothing,es:nothing,gs:nothing ; Tell the assembler about it
;;;;;;;
;;;;;;; ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT31_RM2PM endp		; End INT31_RM2PM procedure
	NPPROC	INT31_VRM2PM_COM -- INT 31h VM/RM to PM Common Routine
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

INT 31h VM/RM to PM common routine

On entry:

SS:EBP	==>	INTXX_STR

On exit:

All EGP registers may be clobbered.

|

	test	DPM_FLAG,mask $DPM_DPMISTART ; Is debugging desired?
	jz	short @F	; Jump if not

	SWATMAC 		; Call our debugger
@@:

; Save caller's PSP segment

	cli			; Disallow interrupts as we use
				; non-sharable data variables
	mov	ax,[ebp].INTXX_ECX.ELO ; Get the segment
	mov	VM2PM_PSP,ax	; Save to use later

; Save caller's DTA

	mov	ax,[ebp].INTXX_ES ; Get the segment
	mov	VM2PM_DTAVEC.VSEG,ax ; Save for later use
	mov	ax,[ebp].INTXX_EBX.ELO ; Get the segment
	mov	VM2PM_DTAVEC.VOFF,ax ; Save for later use

VM2PM_STR struc

VM2PM_ES dw	?		; Caller's original ES
VM2PM_CX dw	?		; ...		    CX
VM2PM_BX dw	?		; ...		    BX
VM2PM_AX dw	?		; ...		    AX
VM2PM_CSIP dd	?		; ...		    CS:IP

VM2PM_STR ends

; Save caller's HPDA segment and restore the original AX, BX, CX, ES

	movzx	eax,[ebp].INTXX_SS ; Get caller's SS
	shl	eax,4-0 	; Convert from paras to bytes
	movzx	ebx,[ebp].INTXX_ESP.ELO ; Get caller's SP

	mov	dx,AGROUP:[eax+ebx].VM2PM_ES ; Get the original ES
	mov	[ebp].INTXX_ES,dx ; Restore the original value

	mov	dx,AGROUP:[eax+ebx].VM2PM_CX ; Get the original CX
	mov	[ebp].INTXX_ECX.ELO,dx ; Restore the original value

	mov	dx,AGROUP:[eax+ebx].VM2PM_BX ; Get the original BX
	mov	[ebp].INTXX_EBX.ELO,dx ; Restore the original value

	mov	dx,AGROUP:[eax+ebx].VM2PM_AX ; Get the original AX
	mov	[ebp].INTXX_EAX.ELO,dx ; Restore the original value

; Restore the return address from the stack to CS:IP

	mov	dx,AGROUP:[eax+ebx].VM2PM_CSIP.VOFF ; Get the return offset
	mov	[ebp].INTXX_EIP.ELO,dx ; Save as new IP

	mov	dx,AGROUP:[eax+ebx].VM2PM_CSIP.VSEG ; Get the return segment
	mov	[ebp].INTXX_CS,dx ; Save as new CS

	add	bx,size VM2PM_STR ; Skip over saved registers
	mov	[ebp].INTXX_ESP.ELO,bx ; Save as new SP

; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様
; From this point on we can signal an error

; Ensure we're not running out of TSSs

	mov	esi,PVMTSS	; Get offset in DGROUP of the 1st TSS
	mov	ecx,@TSS_MAX-1	; Get maximum # DPMI clients we support
@@:
	add	esi,type DPTSS_STR ; Skip to next valid TSS

	cmp	DGROUP:[esi].TSS_LINK,-1 ; Izit available?
	je	short @F	; Jump if so

	loop	@B		; Jump if more TSSs to check

	mov	VM2PM_ERR,8010h ; Internal resource unavailable

	jmp	INT31_VRM2PM_ERRCOM ; Jump if no TSSs available


@@:
	mov	edx,PCURTSS	; Get offset in DGROUP of current TSS

; ESI	 =	 offset in DGROUP of the incoming TSS
; EDX	 =	 ...			 current ...

; Zero all fields beyond TSS_STR in DPTSS_STR so we start
; off with a known value except for the constant fields

	push	DGROUP:[esi].DPTSS_SEL ; Save the selector

	lea	edi,DGROUP:[esi+(type TSS_STR)] ; Skip over TSS_STR in DPTSS_STR
	mov	ecx,((type DPTSS_STR)-(type TSS_STR))/4 ; Get size in dwords
	xor	eax,eax 	; Filler value
    rep stos	DGROUP:[edi].EDD ; Set to known value

	pop	DGROUP:[esi].DPTSS_SEL ; Restore the selector

; Save back pointers to the current TSS in the incoming TSS

	mov	DGROUP:[esi].DPTSS_PLNKTSS,edx ; Save as back pointer
	str	DGROUP:[esi].TSS_LINK ; ...
;;;;	mov	ax,DGROUP:[edx].DPTSS_SEL ; Get its TSS selector
;;;;	mov	DGROUP:[esi].TSS_LINK,ax ; Save as back pointer
	mov	DGROUP:[esi].DPTSS_PRMSTSS,esi ; ...

;;; ; Save the current PLCL_PL0CUR state in the outgoing TSS so it can be
;;; ; restored when the outgoing TSS is restarted
;;;
;;;	    mov     eax,PLCL_PL0CUR ; Get current offset in DGROUP
;;;	    mov     DGROUP:[edx].DPTSS_PLCL_PL0CUR,eax ; Save to restore later
;;;
; Address the next TSS to use.	We must save this value into PCURTSS
; because it is needed to reference the current LDT.  If we encounter
; an error, we'll back off from this value.

	mov	edx,esi 	; Get the next pointer
	mov	PCURTSS,edx	; Save for next time
	mov	PPRMTSS,edx	; ...
	mov	ax,DGROUP:[edx].DPTSS_SEL ; Get the next TSS selector
	mov	VM2PM_TSS,ax	; Skip to next TSS selector

; Because we don't terminate the TSS, the entry might
; still be marked as busy

; Establish addressibility to GDT

	movzx	ebx,ax		; Zero to use as dword
	and	ebx,not (mask $PL) ; Clear the PL bits to use as index

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	add	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> TSS entry in GDT
	add	esp,size DTR_STR ; Strip

	and	AGROUP:[ebx].DESC_ACCESS,not (mask $DS_BUSY) ; Mark as not busy

	ltr	ax		; Set new Task Register (CPU marks as busy)

; Save the bit type

; Note we don't save the value into DPMITYPEIG as yet so we can
; use it as the old value in the old PM data area

	test	[ebp].INTXX_EAX.ELO,@BIT0 ; Set ==> 32-bit, Clr ==> 16-bit
	setnz	DPMITYPE	; Save to check the next time

	call	DPMIFN_INITVARS ; Initialize TSS and HPDA

	call	DPMIFN_INITAPP	; Initialize application flags

; Because QEMM runs on a short stack (512 bytes) and guards
; that short stack at the bottom with an ugly Page Fault,
; we need to insert some valid physical memory down there
; if there is none

	test	[ebp].INTXX_EFL.EHI,mask $VM ; Izit VM86 mode?
	jz	near ptr INT31_VRM2PM_STKOK2 ; Jump if not

	cmp	STK_FLAG,1	; Izit already done?
	je	near ptr INT31_VRM2PM_STKOK2 ; Jump if so

	mov	fs,GXTHDR.GXTHDR_SELCR3 ; Get the CR3 selector
	assume	fs:nothing	; Tell the assembler about it

@PDELOC equ	(2*1024)-(3*4)	; Location for new PDE
@PDELIN equ	@PDELOC shl (22-2) ; Linear address of @PDELOC

	push	fs:[@PDELOC].EDD ; Save last PDE

	mov	eax,cr3 	; Get current CR3
	or	eax,@PTE_URP	; Mark as user/Read-write/Present
	mov	fs:[@PDELOC],eax ; Make it addressible

	mov	eax,cr3 	; Get current CR3
	mov	cr3,eax 	; Flush the TLB

; Calculate the linear address of the 4KB page below the current SS|ESP

	push	ss		; Pass stack selector
	call	GETBASE 	; Return with EAX = base address of selector

	add	eax,esp 	; Plus current pointer
	and	eax,not (4*1024-1) ; Round down to 4KB boundary
	sub	eax,4*1024	; Back off another 4KB
	shr	eax,$LA_PAGE-2	; Convert from 4KB to dwords
	add	eax,@PDELIN	; Plus linear address
	mov	LaSTKPTE,eax	; Save for later use

	test	AGROUP:[eax].PDT_PTE,mask $PTE_P ; Izit present?
	jnz	short INT31_VRM2PM_STKOK1 ; Jump if so

	push	@ALLOC_VCPI	; Tell 'em what kind of memory we're allocating
	push	4*1024		; Pass # bytes to allocate
	call	ALLOCMEM	; Allocate 'em
				; Return with EBX = linear address of memory
	jc	near ptr INT31_VRM2PM_ERR_NOMEM9 ; Jump if no memory found

	mov	LaSTKMEM,ebx	; Save to restore later
;;;;;;; and	ebx,not (4*1024-1) ; Round down to 4KB boundary (already there)
	shr	ebx,$LA_PAGE-2	; Convert from 4KB to dwords
	add	ebx,@PDELIN	; Plus linear address
	mov	ebx,AGROUP:[ebx].PDT_PTE ; Get the PTE
	xchg	AGROUP:[eax].PDT_PTE,ebx ; Save in new location
	mov	STKPTE,ebx	; Save to restore later

	test	VMM_FLAG,@VMM_SYSINIT ; Is VMM active?
	jz	short INT31_VRM2PM_STKOK1 ; Jump if not

	mov	eax,LaSTKMEM	; Get the lienar address
	mov	ebx,1		; Get # 4KB in the stack
	call	VMM_LOCK	; Lock EBX bytes at EAX
	mov	VM2PM_ERR,ax	; In case we failed
	jc	near ptr INT31_VRM2PM_ERR_NOMEM9 ; Jump if some error occurred
INT31_VRM2PM_STKOK1:
	pop	fs:[@PDELOC].EDD ; Restore

	mov	eax,cr3 	; Get current CR3
	mov	cr3,eax 	; Flush the TLB

	mov	STK_FLAG,1	; Mark as done
INT31_VRM2PM_STKOK2:

; If this is the first DPMI client, allocate memory
; for the current PMxxT_xVECS and other variables
; and save its address in the current DPTSS_STR

	mov	eax,PVMTSS	; Get offset in DGROUP of the 1st TSS

	cmp	eax,DGROUP:[edx].DPTSS_PLNKTSS ; Izit the 1st TSS?
	jne	short INT31_VRM2PM_X1TSS ; Jump if not

	mov	VM2PM_ERR,8012h ; Assume we run out of linear memory

	push	@ALLOC_VCPI	; Tell 'em what kind of memory we're allocating
	push	DPMIOLDPM_SIZ	; Pass # bytes to allocate
	call	ALLOCMEM	; Allocate 'em
				; Return with EBX = linear address of memory
	jc	near ptr INT31_VRM2PM_ERR_NOMEM9 ; Jump if no memory found

	mov	DGROUP:[eax].DPTSS_OLDPM,ebx ; Save for later use
INT31_VRM2PM_X1TSS:

; Allocate memory for the current PMxxT_xVECS and other variables
; and save its address in the current DPTSS_STR

	mov	VM2PM_ERR,8012h ; Assume we run out of linear memory

	push	@ALLOC_VCPI	; Tell 'em what kind of memory we're allocating
	push	DPMIOLDPM_SIZ	; Pass # bytes to allocate
	call	ALLOCMEM	; Allocate 'em
				; Return with EBX = linear address of memory
	jc	near ptr INT31_VRM2PM_ERR_NOMEM8 ; Jump if no memory found

	mov	DGROUP:[edx].DPTSS_OLDPM,ebx ; Save for later use

	test	CPUFET_FLAG,mask $CPUFET_VME ; Is VME supported?
	jz	short @F	; Jump if not

	mov	DGROUP:[edx].DPTSS_LaSIRBCUR,ebx ; Save for later use
	mov	LaSIRBCUR,ebx	; Save as current linear address
@@:

; Save current PMxxT_xVECS to outgoing PM data area
; and re-initialize PMxxT_xVECS.

	push	DGROUP:[edx].DPTSS_PLNKTSS ; Point to previous TSS
	push	1		; Tell 'em to re-initialize
	call	DPMIFN_SAVEOLDPM ; Save 'em

; If the swapfile is not active for this client, clear the bit now

	test	VMM_FLAG,@VMM_BSGLOBAL ; Izit globally available?
	jz	short INT31_VRM2PM_NOSWAP ; Jump if not

; If this isn't the first DPMI client, ignore the NOSWAP count as
; we can't re-initialize BSM at this point

	mov	eax,PVMTSS	; Get offset in DGROUP of the 1st TSS

	cmp	eax,DGROUP:[edx].DPTSS_PLNKTSS ; Izit the 1st TSS?
	jne	short INT31_VRM2PM_NOSWAP ; Jump if not

	or	VMM_FLAG,@VMM_BSPRES ; Mark as present
	mov	eax,BSGTotal	; Get global swapfile size
	mov	BSTotal,eax	; Save as local size

	cmp	NOSWAP_CNT,0	; Izit time to lie?
	je	short @F	; Jump if not

	cmp	NOSWAP_CNT,-1	; Izit forever?
	sbb	NOSWAP_CNT,0	; One fewer for next time if not forever
	and	VMM_FLAG,not @VMM_BSPRES ; Mark as not present
	mov	BSTotal,0	; Save as local size
@@:
	test	PDC_FLAG,@I31_NOSWAP ; Skip swapfile for this DPMI client?
	jz	short @F	; Jump if not

	and	VMM_FLAG,not @VMM_BSPRES ; Mark as not present
	mov	BSTotal,0	; Save as local size
@@:
INT31_VRM2PM_NOSWAP:

; Because VMM_INIT might initiate PM DOS calls (for the swapfile),
; we need to ensure that various elements of PCURTSS are properly
; initialized.	These elements include:  TSS_CR3

	mov	eax,cr3 	; Get current PDBR
	mov	DGROUP:[edx].TSS_CR3,eax ; Initialize in TSS

; If this is the first DPMI client, and VMM is present,
; initialize the VMM system.  If that fails, we disallow
; further VMM calls.

	and	VMM_FLAG,not @VMM_CTRLBREAK ; Clear Ctrl-Break flag

	mov	eax,PVMTSS	; Get offset in DGROUP of the 1st TSS

	cmp	eax,DGROUP:[edx].DPTSS_PLNKTSS ; Izit the 1st TSS?
	jne	short @F	; Jump if not

	call	VMM_INIT	; Initialize the VMM system
	mov	VM2PM_ERR,ax	; In case we fail
	jc	near ptr INT31_VRM2PM_ERR_NOMEM7 ; Jump if unable to initialize
@@:

; Initialize this client's portion of the VM system

	call	VMM_INIT_CLIENT ; Initialize the client
	mov	VM2PM_ERR,ax	; In case we fail
	jc	near ptr INT31_VRM2PM_ERR_NOMEM7 ; Jump if no memory found
				; with error code in AX

; Check for Ctrl-Break pressed during swapfile initialization

	mov	VM2PM_ERR,@DERR_CTRLBREAK_SWP ; Assume this (internal) error

	test	VMM_FLAG,@VMM_CTRLBREAK ; Did we hit the panic button?
	jnz	near ptr INT31_VRM2PM_ERR_NOMEM7 ; Jump if so

;;; ; If there's no HMA, ensure the 1MB wrap is disabled as we might allocate
;;; ; to a DPMI client the extended memory at 1MB to 1.1MB
;;;
;;;	     cmp     HMASIZE,0	    ; Izit available?
;;;	     jne     short @F	    ; Jump if so
;;;
;;; ; Re-map the first 64KB of memory above the 1MB limit into itself
;;; ; This also flushes the TLB if CF=0 on return
;;;
;;;	     call    WRAP_DISABLE   ; Disable the 1MB wrap
;;;	     jc      short @F	    ; Jump if we didn't flush the TLB
;;;				    ; (and thus didn't change state)
;;;	     or      DGROUP:[edx].DPTSS_FLAG,mask $DPTSS_WRAP ; Mark as changed
;;;	     or      GLB_FLAG,@GLB_X1MB ; Enable the virtual A20 line
;;; @@:
;;;
; Allocate a Locked Protected Mode stack

	mov	VM2PM_ERR,8012h ; Assume we run out of linear memory

	push	@ALLOC_DPMI	; Tell 'em what kind of memory we're allocating
	push	LPMSTK_SIZ	; Pass # bytes to allocate
	call	ALLOCMEM	; Allocate 'em
				; Return with EBX = linear address of memory
	jc	near ptr INT31_VRM2PM_ERR_NOMEM6 ; Jump if no memory found

	mov	DGROUP:[edx].DPTSS_LPMBASE,ebx ; Save for later use

	test	VMM_FLAG,@VMM_SYSINIT ; Is VMM active?
	jz	short @F	; Jump if not

	mov	eax,ebx 	; Copy linear address
	mov	ebx,LPMSTK_SIZ	; Get # bytes in the stack
	add	ebx,4*1024-1	; Round up to 4KB boundary
	shr	ebx,12-0	; Convert from bytes to 4KB
	call	VMM_LOCK	; Lock EBX bytes at EAX
	mov	VM2PM_ERR,ax	; In case we failed
	jc	near ptr INT31_VRM2PM_ERR_NOMEM5 ; Jump if some error occurred
@@:

; Allocate memory for our extended LDT
; and save its address in the new DPTSS_STR

	mov	VM2PM_ERR,8012h ; Assume we run out of linear memory

	push	@ALLOC_DPMI	; Tell 'em what kind of memory we're allocating
	push	XLDT_SIZ	; Pass # bytes to allocate (/@DPMI_BOUND)
	call	ALLOCMEM	; Allocate 'em
				; Return with EBX = linear address of memory
	jc	near ptr INT31_VRM2PM_ERR_NOMEM4 ; Jump if no memory found

	mov	DGROUP:[edx].DPTSS_LaLDT,ebx ; Save for later use

	mov	eax,LDT_SIZ	; Get initial byte size of DPMI LDT (/8)
	mov	DGROUP:[edx].DPTSS_LDT_SIZ,eax ; Save for later use

	mov	ax,VM2PM_TSS	; Get current TSS selector
	add	ax,type DESC_STR ; Skip to LDT selector
	or	al,DPMI_CPL	; Include CPL/RPL
	mov	DGROUP:[edx].TSS_LDT,ax ; Save in TSS

	test	VMM_FLAG,@VMM_SYSINIT ; Is VMM active?
	jz	short @F	; Jump if not

	mov	eax,ebx 	; Copy linear address
	mov	ebx,XLDT_SIZ	; Get # bytes in the LDT
	add	ebx,4*1024-1	; Round up to 4KB boundary
	shr	ebx,12-0	; Convert from bytes to 4KB
	call	VMM_LOCK	; Lock EBX bytes at EAX
	mov	VM2PM_ERR,ax	; In case we failed
	jc	near ptr INT31_VRM2PM_ERR_NOMEM3 ; Jump if some error occurred
@@:
	call	DPMIFN_INITLDT	; Initialize the contents of the LDT
				; and install it

; Initialize the LPM stack to known values for debugging purposes.
; That way, we can see how much gets used by DPMI clients.
; Note we wait until the LDT base has been set and saved into DPTSS
; before generating any Page Faults as RESETVARS gets called at
; that time and would save incorrect values.

	push	es		; Save for a moment

	mov	es,SEL_4GB	; Get AGROUP data selector at PL0
	assume	es:AGROUP	; Tell the assembler about it

	mov	edi,DGROUP:[edx].DPTSS_LPMBASE ; Get linear address of the LPM stack
	mov	ecx,LPMSTK_SIZ	; Get size of the LPM stack in bytes
	shr	ecx,2-0 	; Convert from bytes to dwords
	mov	eax,@LPMSTKFILL ; Fill with this value
    rep stos	AGROUP:[edi].EDD ; Fill it

	pop	es		; Restore
	assume	es:DGROUP	; Tell the assembler about it

; Allocate memory for our DPMI memory handle structure
; and save its address in the new DPTSS_STR

	mov	VM2PM_ERR,8012h ; Assume we run out of linear memory

	push	@ALLOC_DPMI	; Tell 'em what kind of memory we're allocating
	push	DPMIHNDL_SIZ	; Pass # bytes to allocate (/@DPMI_BOUND)
	call	ALLOCMEM	; Allocate 'em
				; Return with EBX = linear address of memory
	jc	near ptr INT31_VRM2PM_ERR_NOMEM3 ; Jump if no memory found

	mov	DGROUP:[edx].DPTSS_LaDPMIHNDL,ebx ; Save for later use

	mov	eax,DPMIHNDL_CNT ; Get initial # DPMI memory handles
	mov	DGROUP:[edx].DPTSS_DPMIHNDL_CNT,eax ; Save for later use

	call	DPMIFN_INITDPMIHNDL ; Initialize the contents of the DPMI
				; memory handle structure

; Allocate memory for our dynamic data save area
; and save its address in the new DPTSS_STR

	mov	VM2PM_ERR,8012h ; Assume we run out of linear memory

	push	@ALLOC_DPMI	; Tell 'em what kind of memory we're allocating
	push	DPMIDYN_SIZ	; Pass # bytes to allocate
	call	ALLOCMEM	; Allocate 'em
				; Return with EBX = linear address of memory
	jc	near ptr INT31_VRM2PM_ERR_NOMEM2 ; Jump if no memory found

	mov	DGROUP:[edx].DPTSS_DYN,ebx ; Save for later use

; Setup LDT selector for caller's return CS

	mov	VM2PM_ERR,8011h ; Assume selector unavailable

	movzx	eax,[ebp].INTXX_CS ; Get the return CS
	shl	eax,4-0 	; Convert from paras to bytes

	push	DPMI_CODE	; Pass access rights word
	push	CON64KB 	; Pass segment length in bytes
	push	eax		; Pass base address
	call	GETSET_LDTVAR	; Return with EAX = selector ($TI and $PL set)
	jc	near ptr INT31_VRM2PM_ERR_NOSEL ; Jump if not available

	mov	ebx,DGROUP:[edx].DPTSS_LaHPDA ; Get linear address of the HPDA
	mov	DGROUP:[edx].TSS_CS,ax ; Save for later use
	mov	AGROUP:[ebx].HPDA_pCS,ax ; Save for later use

; Set B-bit for data selectors if it's not a 16-bit client

	mov	cl,DPMI_DATA.LO ; Get A/R byte for 16-bit client

	cmp	DPMITYPE,@DPMITYPE16 ; Izit a 16-bit client?
	setne	ch		; CH = 1 if 32-bit or no DPMI
				;    = 0 if 16-bit
	shl	ch,$DTE_B	; Set B-bit for 32-bit apps

; Setup selector for caller's DTA

	movzx	eax,VM2PM_DTAVEC.VSEG ; Get the DTA segment
	shl	eax,4-0 	; Convert from paras to bytes

	push	cx		; Pass A/R word (from above)
	push	dword ptr 80h	; Pass segment length in bytes
	push	eax		; Pass base address
	call	GETSET_LDTFIX	; Return with EAX = selector ($TI and $PL set)
	jc	near ptr INT31_VRM2PM_ERR5 ; Jump if not available

	mov	DGROUP:[edx].DPTSS_DTA_FVEC.FSEL,ax ; Save for later use
	movzx	eax,VM2PM_DTAVEC.VOFF ; Get the DTA offset
	mov	DGROUP:[edx].DPTSS_DTA_FVEC.FOFF,eax ; ...

; Setup LDT selector for caller's DS

	movzx	eax,[ebp].INTXX_DS ; Get caller's DS
	shl	eax,4-0 	; Convert from paras to bytes

	push	cx		; Pass A/R word (from above)
	push	CON64KB 	; Pass segment length in bytes
	push	eax		; Pass base address
	call	GETSET_LDTVAR	; Return with EAX = selector ($TI and $PL set)
	jc	near ptr INT31_VRM2PM_ERR4 ; Jump if not available

	mov	DGROUP:[edx].TSS_DS,ax ; Save for later use
	mov	AGROUP:[ebx].HPDA_pDS,ax ; Save for later use

; Setup LDT selector for caller's SS

	movzx	eax,[ebp].INTXX_SS ; Get caller's SS
	shl	eax,4-0 	; Convert from paras to bytes

	push	cx		; Pass A/R word (from above)
	push	CON64KB 	; Pass segment length in bytes
	push	eax		; Pass base address
	call	GETSET_LDTVAR	; Return with EAX = selector ($TI and $PL set)
	jc	near ptr INT31_VRM2PM_ERR3 ; Jump if not available

	mov	DGROUP:[edx].TSS_SS,ax ; Save for later use
	mov	AGROUP:[ebx].HPDA_pSS,ax ; Save for later use

; Setup LDT selector for caller's PSP

	movzx	eax,VM2PM_PSP	; Get the PSP segment
	shl	eax,4-0 	; Convert from paras to bytes

	push	cx		; Pass A/R word (from above)
	push	dword ptr 100h	; Pass segment length in bytes
	push	eax		; Pass base address
	call	GETSET_LDTFIX	; Return with EAX = selector ($TI and $PL set)
	jc	near ptr INT31_VRM2PM_ERR2 ; Jump if not available

	mov	DGROUP:[edx].TSS_ES,ax ; ...
	mov	AGROUP:[ebx].HPDA_pES,ax ; ...

; Setup LDT selector for caller's environment

	movzx	esi,VM2PM_PSP	; Get the PSP segment
	shl	esi,4-0 	; Convert from paras to bytes

	assume	gs:PSPGRP	; Tell the assembler about it
	movzx	eax,PSP_ENVIR_PTR[esi] ; Get the environment segment
	assume	gs:AGROUP	; Tell the assembler about it

	mov	AGROUP:[ebx].HPDA_ENVSEG,ax ; Save for later use

	shl	eax,4-0 	; Convert from paras to bytes
	jz	short INT31_VRM2PM_XENV ; Jump if it's been freed

@ENVLEN equ	8000h		; Length of environment

	push	cx		; Pass A/R word (from above)
	push	dword ptr @ENVLEN ; Pass size of area in bytes (32KB maximum)
	push	eax		; Pass base address
	call	GETSET_LDTFIX	; Return with EAX = selector ($TI and $PL set)
	jc	near ptr INT31_VRM2PM_ERR1 ; Jump if not available

	call	CHECK_ENVCFG	; Check for this program in environment AX
				; in the CFG file
	assume	gs:PSPGRP	; Tell the assembler about it
	mov	PSP_ENVIR_PTR[esi],ax ; Save the environment selector
	assume	gs:AGROUP	; Tell the assembler about it
INT31_VRM2PM_XENV:
; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様
; From this point on, we should not signal any errors

; Now that we know we're going to succeed, we can save the
; per DPMI client flags in a more permanent place (I31_FLAG)
; which gets switched in and out as the client changes.

	xor	ax,ax		; Clear for the next time
	xchg	ax,PDC_FLAG	; Get per DPMI client flags and zero 'em
	or	I31_FLAG,ax	; Include for later use
if @EXPD

; If this is the Kernel, we need to change the
; Expand Down stack to Expand Up as Win3x expects that

	test	I31_FLAG,@I31_KRNL ; Izit the Kernel?
	jz	short INT31_VRM2PM_XKRNL1 ; Jump if not

; Save linear address of DPMI LPM as Read-Write data descriptor at PL3
; now so we get the same selector for each LDT

	mov	eax,DGROUP:[edx].DPTSS_LPMBASE ; Get linear address of LPM

	mov	cl,DPMI_DATA.LO ; Get A/R byte for 16-bit client

	cmp	DPMITYPE,@DPMITYPE16 ; Izit a 16-bit client?
	setne	ch		; CH = 1 if 32-bit or no DPMI
				;    = 0 if 16-bit
	shl	ch,$DTE_B	; Set B-bit for 32-bit apps
	mov	edi,LPMSTK_SIZ	; Get size of area in bytes

	push	edi		; Pass size of area in bytes
	push	cx		; Pass access rights word
	push	word ptr LDTE_DATALPM3 ; Pass descriptor to set
	call	SET_GDT 	; Set the GDT to EAX base
INT31_VRM2PM_XKRNL1:
endif
if @W9X

; If this is the Kernel, we need to load KERNEL32.DLL @ BFF6000

	test	I31_FLAG,@I31_KRNL ; Izit the Kernel?
	jz	near ptr INT31_VRM2PM_XKRNL2 ; Jump if not

	REGSAVE <edx,es>	; Save for a moment

	int	01h

	mov	ax,0101h * @DPMITYPE32 ; Get Type 32
	xchg	al,DPMITYPE	; Swap with original
	xchg	ah,DPMITYPEIG	; ...

	push	ax		; Save for a moment

; Construct the path to KERNEL32.DLL

@KERNEL_STKSIZE equ 256 	; Room needed on stack for KERNEL32.DLL & path

	sub	esp,@KERNEL_STKSIZE ; Make room on the stack

	mov	ax,ss		; Copy stack selector
	mov	es,ax		; Save in destin selector
	assume	es:nothing	; Tell the assembler about it

	mov	edi,esp 	; ES:EDI ==> save area
	mov	edx,edi 	; ES:EDX ==> ...

	lea	esi,MSG_APPLNAME[size LENTXT_LEN] ; DS:ESI ==> load directory
	mov	ecx,APPDIR_LEN	; Length of application directory (with "SYSTEM\")
    rep movs	es:[edi].LO,MSG_APPLNAME[esi].LO ; Copy the directory

	lea	esi,KERNEL32	; DS:ESI ==> "KERNEL32.DLL"
	mov	ecx,@KERNEL32_LEN ; Length of ...
    rep movs	es:[edi].LO,KERNEL32[esi] ; Copy the directory

	mov	al,0		; Terminator
	stos	es:[esi].LO	; Terminate it

; Attempt to open the file

	push	ds		; Save for a moment

	mov	ax,ss		; Copy stack selector
	mov	ds,ax		; Address it
	assume	ds:nothing	; Tell the assembler about it

	mov	al,@OPEN_R	; Open as read-only
	DOSCALL @OPENF2 	; Open the file
				; Return with AX = file handle
	pop	ds		; Restore
	assume	ds:DGROUP	; Tell the assembler about it
	jc	short INT31_VRM2PM_XKRNL2B ; Jump if not present

	mov	bx,ax		; Copy to file handle register

; Get the file length

	mov	al,@MOVFP2_END	; Move to end
	xor	cx,cx		; CX:DX == 0:0
	xor	dx,dx		; ...
	DOSCALL @MOVFP2 	; Move file pointer to CX:DX
				; Return with DX:AX ==> file end
	mov	KERNEL32_LEN.EHI,dx ; Save for later use
	mov	KERNEL32_LEN.ELO,ax ; ...

	mov	al,@MOVFP2_BEG	; Move to beginning
	xor	cx,cx		; CX:DX == 0:0
	xor	dx,dx		; ...
	DOSCALL @MOVFP2 	; Move file pointer
				; Return with DX:AX ==> file beginning
; Allocate space for KERNEL32.DLL at @KERNEL32_BASE

	push	ebx		; Save for a moment

	mov	ebx,KERNEL32_LEN ; Get length
	add	ebx,4*1024-1	; Round up to 4KB
;;;;;;; and	ebx,not (4*1024-1) ; ...boundary
	shr	ebx,12-0	; Convert from bytes to 4KB
	mov	eax,@KERNEL32_BASE ; Alloc this absolute location
	mov	ecx,mask $commit ; Set flags:  Committed
	call	VMM_ALLOC	; Allocate the memory
	pop	ebx		; Restore
	jc	short INT31_VRM2PM_XKRNL2A ; Jump if no room

; Read the file into memory

	push	ds		; Save for a moment

	mov	edx,@KERNEL32_BASE ; Read into this absolute location
	mov	ecx,KERNEL32_LEN ; Get length

	mov	ds,SEL_4GB	; Get AGROUP data selector at PL0
	assume	ds:AGROUP	; Tell the assembler about it

	DOSCALL @READF2 	; Read in the file
	pop	ds		; Restore
	assume	ds:DGROUP	; Tell the assembler about it
;;;;;;; jc	short ???	; Ignore error return
INT31_VRM2PM_XKRNL2A:
	DOSCALL @CLOSF2 	; Copy the file
INT31_VRM2PM_XKRNL2B:
	add	esp,@KERNEL_STKSIZE ; Strip from stack

	pop	ax		; Restore

	mov	DPMITYPE,al	; Restore
	mov	DPMITYPEIG,ah	; ...

	REGREST <es,edx>	; Restore
	assume	es:DGROUP	; Tell the assembler about it
INT31_VRM2PM_XKRNL2:
endif
	push	PCURTSS 	; Pass offset in DGROUP of the current TSS
	call	DPMIFN_LMSW	; Put MSW and INT 07h values into effect

; Initialize dynamic save area.
; Note we wait until after we've disabled the 1MB wrap to initialize
; this area in case it's in the wrap region.

	mov	eax,DGROUP:[edx].DPTSS_DYN ; Get linear address of dynamic save area
	mov	AGROUP:[eax].DYNHDR_FN,@DYNFN_EOL ; Mark as nothing present

; Setup registers for when caller returns to us

	mov	eax,[ebp].INTXX_EAX ; Get caller's EAX
	mov	DGROUP:[edx].TSS_EAX,eax ; Save in new TSS

	mov	eax,[ebp].INTXX_EBX ; ...	    EBX
	mov	DGROUP:[edx].TSS_EBX,eax ; ...

	mov	eax,[ebp].INTXX_ECX ; ...	    ECX
	mov	DGROUP:[edx].TSS_ECX,eax ; ...

	mov	eax,[ebp].INTXX_EDX ; ...	    EDX
	mov	DGROUP:[edx].TSS_EDX,eax ; ...

	mov	eax,[ebp].INTXX_ESI ; ...	    ESI
	mov	DGROUP:[edx].TSS_ESI,eax ; ...

	mov	eax,[ebp].INTXX_EDI ; ...	    EDI
	mov	DGROUP:[edx].TSS_EDI,eax ; ...

	mov	eax,[ebp].INTXX_EBP ; ...	    EBP
	mov	DGROUP:[edx].TSS_EBP,eax ; ...

	mov	DGROUP:[edx].TSS_FS,0 ; Ensure valid
	mov	DGROUP:[edx].TSS_GS,0 ; ...

; Set new TSS_ESP0 to previous value for nesting

	mov	eax,DGROUP:[edx].DPTSS_PLNKTSS ; Get offset in DGROUP of prev TSS
	mov	eax,DGROUP:[eax].TSS_ESP0 ; Get top of MAX stack
	mov	DGROUP:[edx].TSS_ESP0,eax ; Set top of MAX stack

; Recalculate PL0STK pointers

	call	SET_PPL0STK	; Set PPL0STK... pointers

; Swap the value of the INT 22h address in the PSP with our own

	mov	eax,DGROUP:[edx].DPTSS_LaHPDA ; Get linear address of HPDA

	movzx	ecx,VM2PM_PSP	; Get the PSP segment
	shl	ecx,4-0 	; Convert from paras to bytes

	mov	bx,DGROUP:[edx].DPTSS_HPDASEG ; Get segment of the HPDA
	shl	ebx,16		; Shift to high-order word
	mov	bx,HPDA_I22DEF	; Get offset of default Terminate handler

	assume	gs:PSPGRP	; Tell the assembler about it
	xchg	ebx,PSP_TERMINATE[ecx] ; Swap with the previous address
	assume	gs:AGROUP	; Tell the assembler about it

	mov	AGROUP:[eax].HPDA_I22VEC,ebx ; Save for later use

; Swap the value of the INT 23h address in the VM IDT with our own

;;;;;;; mov	eax,DGROUP:[edx].DPTSS_LaHPDA ; Get linear address of HPDA

	mov	bx,DGROUP:[edx].DPTSS_HPDASEG ; Get segment of the HPDA
	shl	ebx,16		; Shift to high-order word
	mov	bx,HPDA_I23DEF	; Get offset of default Ctrl-Break handler

	assume	gs:INTVEC	; Tell the assembler about it
	xchg	ebx,INT00_VEC[23h*(type INT00_VEC)] ; Get the previous address
	assume	gs:AGROUP	; Tell the assembler about it

	mov	AGROUP:[eax].HPDA_I23VEC,ebx ; Save for later use

; Swap the value of the INT 24h address in the VM IDT with our own

;;;;;;; mov	eax,DGROUP:[edx].DPTSS_LaHPDA ; Get linear address of HPDA

	mov	bx,DGROUP:[edx].DPTSS_HPDASEG ; Get segment of the HPDA
	shl	ebx,16		; Shift to high-order word
	mov	bx,HPDA_I24DEF	; Get offset of default Critical Error handler

	assume	gs:INTVEC	; Tell the assembler about it
	xchg	ebx,INT00_VEC[24h*(type INT00_VEC)] ; Get the previous address
	assume	gs:AGROUP	; Tell the assembler about it

	mov	AGROUP:[eax].HPDA_I24VEC,ebx ; Save for later use

; Save current LPM stack pointer in the outgoing TSS

	mov	edx,DGROUP:[edx].DPTSS_PLNKTSS ; Get offset in DGROUP of prev TSS

	mov	eax,LPMSTK_FVEC.FOFF ; Get offset of top of LPM stack
	mov	DGROUP:[edx].DPTSS_LPMSTK_FVEC.FOFF,eax ; Save for later use
	mov	ax,LPMSTK_FVEC.FSEL ; Get selector of top of LPM stack
	mov	DGROUP:[edx].DPTSS_LPMSTK_FVEC.FSEL,ax ; Save for later use
	mov	eax,LPMSTK_CNT	; Get current LPM stack usage count
	mov	DGROUP:[edx].DPTSS_LPMSTK_CNT,eax ; Save for later use

; Save new value for LPM stack pointer and count

	mov	ax,LPMSTK_SEL	; Get the default selector
	mov	LPMSTK_FVEC.FSEL,ax ; Save the new selector

	mov	eax,LPMSTK_SIZ	; Get initial stack offset
if @EXPD
	test	I31_FLAG,@I31_KRNL ; Izit the Kernel?
	jnz	short @F	; Jump if so

	xor	eax,eax 	; Get initial stack offset
@@:
endif
	mov	LPMSTK_FVEC.FOFF,eax ; Save for later use
	mov	LPMSTK_CNT,0	; Set initial LPM stack usage count

	and	LAST_INTFLG,not @INTCOM_VAL ; Mark as invalid

; Call Resident Service Providers

	mov	ah,0		; Pass INITIALIZATION parameter
	mov	al,DPMITYPE	; Pass bitness
	call	DPMIFN_CALL_RSPS ; Call RSPs

	mov	edx,PCURTSS	; Get offset in DGROUP of current TSS
	or	DGROUP:[edx].DPTSS_FLAG,mask $DPTSS_INIT ; Mark as initialized

; Because we don't want to set the NT bit, we effect a task switch
; by hand.

; Note:  the following label is JMPed to from outside this routine

INT31_VRM2PM_TS:
	mov	edx,PCURTSS	; Get offset in DGROUP of current TSS

	push	DGROUP:[edx].TSS_SS.EDD ; Setup for IRETD
	push	DGROUP:[edx].TSS_ESP	 ; ...

; If the return CS is at PL0 (as may be the case if we entered here
; from a spurious IRET/D at PL0 because the DPMI client set the NT
; flag and then called us), restore the stack immediately because
; the following IRETD won't perform a ring transition.

	test	DGROUP:[edx].TSS_CS,mask $PL ; Izit at PL0?
	jnz	short @F	; Jump if not

	lss	esp,[esp].EDF	; Restore it now
	assume	ss:nothing	; Tell the assembler about it
@@:
	push	DGROUP:[edx].TSS_EFL	 ; ...
	push	DGROUP:[edx].TSS_CS.EDD ; ...
	push	DGROUP:[edx].TSS_EIP	 ; ...

	mov	eax,DGROUP:[edx].TSS_EAX ; Restore from new TSS
	mov	ebx,DGROUP:[edx].TSS_EBX ; ...
	mov	ecx,DGROUP:[edx].TSS_ECX ; ...
	mov	esi,DGROUP:[edx].TSS_ESI ; ...
	mov	edi,DGROUP:[edx].TSS_EDI ; ...
	mov	ebp,DGROUP:[edx].TSS_EBP ; ...

	push	DGROUP:[edx].TSS_EDX ; Save on stack

	mov	gs,DGROUP:[edx].TSS_GS ; Restore from new TSS
	assume	gs:nothing	; Tell the assembler about it

	mov	fs,DGROUP:[edx].TSS_FS ; ...
	assume	fs:nothing	; Tell the assembler about it

	mov	es,DGROUP:[edx].TSS_ES ; ...
	assume	es:nothing	; Tell the assembler about it

	mov	ds,DGROUP:[edx].TSS_DS ; ...
	assume	ds:nothing	; Tell the assembler about it

	pop	edx		; Restore

	iretd			; Switch to the new task (PM only)


	assume	ds:DGROUP,es:DGROUP  ; Tell the assembler about it
	assume	fs:nothing,gs:AGROUP ; Tell the assembler about it

INT31_VRM2PM_ERR1:
	push	DGROUP:[edx].TSS_ES ; Get selector to free
	call	CLR_LDT 	; Free this LDT selector
;;;;;;; jc	short ???	; Ignore error return
INT31_VRM2PM_ERR2:
	push	DGROUP:[edx].TSS_SS ; Get selector to free
	call	CLR_LDT 	; Free this LDT selector
;;;;;;; jc	short ???	; Ignore error return
INT31_VRM2PM_ERR3:
	push	DGROUP:[edx].TSS_DS ; Get selector to free
	call	CLR_LDT 	; Free this LDT selector
;;;;;;; jc	short ???	; Ignore error return
INT31_VRM2PM_ERR4:
	push	DGROUP:[edx].DPTSS_DTA_FVEC.FSEL ; Get selector to free
	call	CLR_LDT 	; Free this LDT selector
;;;;;;; jc	short ???	; Ignore error return
INT31_VRM2PM_ERR5:
	push	DGROUP:[edx].TSS_CS ; Get selector to free
	call	CLR_LDT 	; Free this LDT selector
;;;;;;; jc	short ???	; Ignore error return
INT31_VRM2PM_ERR_NOSEL:

; Deallocate dynamic save area

	push	DPMIDYN_SIZ	; Pass byte length
	push	DGROUP:[edx].DPTSS_DYN ; Pass starting linear address
	call	DEALLOCMEM	; Deallocate the memory
	jnc	short @F	; Jump if no error

	SWATMAC ERR		; Call our debugger
@@:
INT31_VRM2PM_ERR_NOMEM2:

; Deallocate DPMI memory handle structure

	push	DPMIHNDL_SIZ	; Pass byte length
	push	DGROUP:[edx].DPTSS_LaDPMIHNDL ; Pass starting linear address
	call	DEALLOCMEM	; Deallocate the memory
	jnc	short @F	; Jump if no error

	SWATMAC ERR		; Call our debugger
@@:
INT31_VRM2PM_ERR_NOMEM3:

; Deallocate old LDT and restore new one

	call	DPMIFN_FREELDT	; Free it
INT31_VRM2PM_ERR_NOMEM4:
INT31_VRM2PM_ERR_NOMEM5:

; Deallocate DPMI LPM stack

	push	LPMSTK_SIZ	; Pass byte length
	push	DGROUP:[edx].DPTSS_LPMBASE ; Pass starting linear address
	call	DEALLOCMEM	; Deallocate the memory
	jnc	short @F	; Jump if no error

	SWATMAC ERR		; Call our debugger
@@:
INT31_VRM2PM_ERR_NOMEM6:
;;;
;;; ; If we previously enabled the 1MB wrap, ensure it's restored to
;;; ; its previous state
;;;
;;;	     test    DGROUP:[edx].DPTSS_FLAG,mask $DPTSS_WRAP ; Izit changed?
;;;	     jz      short @F	    ; Jump if so
;;;
;;; ; Re-map the first 64KB of memory above the 1MB limit back to first 64KB
;;; ; This also flushes the TLB if CF=0 on return
;;;
;;;	     and     GLB_FLAG,not @GLB_X1MB ; Disable the virtual A20 line
;;;	     call    WRAP_ENABLE     ; Enable the 1MB wrap, ignore return
;;; @@:
INT31_VRM2PM_ERR_NOMEM7:

; Restore the incoming PM data area

	push	@BIT0		; Tell 'em we're terminating
	push	DGROUP:[edx].DPTSS_PLNKTSS ; Get offset in DGROUP of prev TSS
	call	DPMIFN_RESTOLDPM ; Restore it

; De-allocate the outgoing PM data area

	push	DPMIOLDPM_SIZ	; Pass byte length
	push	DGROUP:[edx].DPTSS_OLDPM ; Pass linear address of old PM data area
	call	DEALLOCMEM	; Deallocate the memory
	jnc	short @F	; Jump if no error

	SWATMAC ERR		; Call our debugger
@@:
INT31_VRM2PM_ERR_NOMEM8:

; If this is the first DPMI client, de-allocate memory
; for the current PMxxT_xVECS and other variables
; Note that this routine must be called *BEFORE* PCURTSS has been
; restored to the incoming TSS.

	call	DPMIFN_FREE_VMOLDPM ; Free it
INT31_VRM2PM_ERR_NOMEM9:

; Terminate this client and the VMM system if this is the last client

	test	VMM_FLAG,@VMM_SYSINIT ; Is VMM active?
	jz	short @F	; Jump if not

	call	VMM_TERMINATE_CLIENT ; Terminate the current client (PCURTSS)
@@:
	mov	edx,PCURTSS	; Get offset in DGROUP of the current TSS
	movzx	ebx,DGROUP:[edx].DPTSS_SEL ; Get the next TSS selector

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	mov	eax,[esp].DTR_BASE ; AGROUP:EAX ==> GDT
	add	esp,size DTR_STR ; Strip

	and	AGROUP:[eax].DESC_ACCESS[ebx],not (mask $DS_BUSY) ; Mark as not busy

; Back off to previous TSS and its selector

	call	DPMIFN_PLNKTSS	; Back off to previous TSS with EDX=PCURTSS

	mov	edx,PCURTSS	; Get offset in DGROUP of the current TSS

; Set the base of the new LDT

	push	DGROUP:[edx].TSS_LDT.EDD ; Pass LDT selector as dword
	push	DGROUP:[edx].DPTSS_LaLDT ; ...	LDT base address
	call	SETBASE 	; Set the base address

	lldt	DGROUP:[edx].TSS_LDT ; Set LDTR
;;;;;;; movzx	ebx,DGROUP:[edx].DPTSS_SEL ; Get the next TSS selector
;;;;;;; and	AGROUP:[eax].DESC_ACCESS[ebx],not (mask $DS_BUSY) ; Mark as not busy
;;;;;;; ltr	bx		; Tell the CPU about it
;;;;;;;
	mov	ax,VM2PM_ERR	; Return error code
INT31_VRM2PM_ERRCOM:
	mov	bl,DPMITYPEIG	; Restore original DPMITYPE value
	mov	DPMITYPE,bl	; Restored

	or	[ebp].INTXX_EFL.ELO,mask $CF ; Indicate we failed

;;; ; If the error is caused by Ctrl-Break during swapfile initialization,
;;; ; we need to IRETD to code in the HPDA which issues an Int 23, then
;;; ; checks for abort.  If not aborting, we have an IRET frame pointing
;;; ; to the original return address, and we just IRET there.  If aborting,
;;; ; we need to set the reason for termination to Ctrl-Break.
;;;    *FIXME*
;;;	     cmp     ax,@DERR_CTRLBREAK_SWP ; Izit Ctrl-Break during swapfile init?
;;;	     jne     short @F	    ; Jump if not
;;;
;;;	     call    CPY_DL2GROUP   ; Set up return to code in HPDA
;;; @@:
	mov	[ebp].INTXX_EAX.ELO,ax ; Return it

; Split cases depending upon from where we were called (VM vs. RM)

	test	[ebp].INTXX_EFL.EHI,mask $VM ; Izit VM86 mode?
	jnz	short @F	; Jump if so

	ret			; Return to caller


@@:
	popad			; Restore all EGP registers
				; N.B.:  Do not follow with [EAX+???*?]
	add	esp,size INTXX_ERR ; Strip off error code

	jmp	ERM_FVEC	; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INT31_VRM2PM_COM endp		; End INT31_VRM2PM_COM procedure
	NPPROC	DPMIFN_CHK22 -- Check INT 22h In The PSP
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

If this client is BC 3.0 (DPMILOAD.EXE), it has clobbered the
INT 22h address in the PSP by setting the offset but not the segment.
Check for that and make it all better.

On entry:

EBX	=	linear address of HPDA
ECX	=	linear address of PSP

|

	REGSAVE <eax,esi>	; Save registers

; See if it's our friend DPMILOAD.EXE

	mov	esi,MSG_APPLNAME.LENTXT_LEN ; Get dword length of application
	add	esi,size LENTXT_LEN ; Count in length word

	cmp	MSG_APPLNAME.EDD[esi-4],'EXE.' ; Izit ".EXE"?
	jne	short DPMIFN_CHK22_EXIT ; Jump if not

	cmp	MSG_APPLNAME.EDD[esi-8],'DAOL' ; Izit "LOAD"?
	jne	short DPMIFN_CHK22_EXIT ; Jump if not

	cmp	MSG_APPLNAME.EDD[esi-12],'IMPD' ; Izit "DPMI"?
	jne	short DPMIFN_CHK22_EXIT ; Jump if not

; If the segment portion of the PSP_TERMINATE address is that of
; our HPDA, but the offset portion doesn't match any of our entry
; addresses, then it must be invalid.

	mov	eax,ebx 	; Copy HPDA linear address
	shr	eax,4-0 	; Convert from bytes to paras

	assume	gs:PSPGRP	; Tell the assembler about it
	cmp	ax,PSP_TERMINATE[ecx].VSEG ; Izit our segment?
	assume	gs:AGROUP	; Tell the assembler about it
	jne	short DPMIFN_CHK22_EXIT ; Jump if not

	assume	gs:PSPGRP	; Tell the assembler about it
	mov	ax,PSP_TERMINATE[ecx].VOFF ; Get the offset
	assume	gs:AGROUP	; Tell the assembler about it

; Check the offset portion against all the legitimate offsets
; in our HPDA.

	cmp	ax,HPDA_SIMRET	; Izit SIMRET?
	je	short DPMIFN_CHK22_EXIT ; Jump if so

	cmp	ax,HPDA_I22DEF	; Izit INT 22h?
	je	short DPMIFN_CHK22_EXIT ; Jump if so

; Set the segment portion of the PSP_TERMINATE address to
; that of the original address.

	mov	ax,AGROUP:[ebx].HPDA_I22VEC.VSEG ; Get the original segment

	assume	gs:PSPGRP	; Tell the assembler about it
	mov	PSP_TERMINATE[ecx].VSEG,ax ; Save as the segment
	assume	gs:AGROUP	; Tell the assembler about it
DPMIFN_CHK22_EXIT:
	REGREST <esi,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_CHK22 endp		; End DPMIFN_CHK22 procedure
	NPPROC	DPMIFN_INITVARS -- Initialize TSS and HPDA
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Initialize TSS and HPDA

On entry:

EDX	=	offset in PRGOUP of the incoming TSS
SS:EBP	==>	INTXX_STR

On exit:

|

	REGSAVE <eax,ebx,ecx,edx,esi,edi> ; Save registers

; Save LAST_INTCOM, LAST_INTFLG, and PL0 stack values into the next TSS

	mov	eax,LAST_INTCOM ; Get last INTCOM restart point
	mov	DGROUP:[edx].DPTSS_INTCOM,eax ; Save to restore later

	mov	eax,LAST_INTFLG ; Get its flag
	mov	DGROUP:[edx].DPTSS_INTFLG,eax ; Save to restore later

	mov	eax,PPL0STK_ERR ; Get stack offset when error code present
	mov	DGROUP:[edx].DPTSS_STKERR,eax ; Save to restore later

	mov	eax,PPL0STK_NRM ; Get stack offset when normal start
	mov	DGROUP:[edx].DPTSS_STKNRM,eax ; Save to restore later

	mov	eax,PPL0STK_DERR ; Get stack offset when DPMI fault occurs
	mov	DGROUP:[edx].DPTSS_STKDERR,eax ; Save to restore later

	mov	eax,PPL0STK_DNRM ; Get stack offset when DPMI HW/SW occurs
	mov	DGROUP:[edx].DPTSS_STKDNRM,eax ; Save to restore later

	mov	eax,PPL0STK_MIN ; Get stack minimum for interrupts
	mov	DGROUP:[edx].DPTSS_STKMIN,eax ; Save to restore later

	mov	eax,PPL0STK_MAP ; Get stack bottom for Map & Call struc
	mov	DGROUP:[edx].DPTSS_STKMAP,eax ; Save to restore later

; Save the initial current buffer offset and size

	mov	ax,HPDABUF_OFF	; Get the offset
	mov	DGROUP:[edx].DPTSS_VMBUFOFF,ax ; Save for later use

	mov	ax,HPDABUF_SIZ	; Get the size
	mov	DGROUP:[edx].DPTSS_VMBUFSIZ,ax ; Save for later use

; Save MSW and INT 07h values

	mov	ax,MSW_PM	; Get MSW for PM operaton
	mov	DGROUP:[edx].DPTSS_MSW,ax ; Save for later use

; Establish addressibility to IDT

	sub	esp,size DTR_STR ; Make room on stack
	SIDTD	[esp].EDF	; Save IDTR on stack
	mov	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> IDT
	add	esp,size DTR_STR ; Strip

	mov	eax,AGROUP:[ebx+07h*(type IDT_STR)].EDQLO ; Get low-order dword
	mov	DGROUP:[edx].DPTSS_IDT07.EDQLO,eax ; Save for later use

	mov	eax,AGROUP:[ebx+07h*(type IDT_STR)].EDQHI ; Get high-order dword
	mov	DGROUP:[edx].DPTSS_IDT07.EDQHI,eax ; Save for later use

; Save the segment of the host private data area

	movzx	ebx,[ebp].INTXX_ES ; Get the HPDA segment
	mov	DGROUP:[edx].DPTSS_HPDASEG,bx ; Save for later use
	mov	DGROUP:[edx].DPTSS_VMSTKSEG,bx ; ...
	shl	ebx,4-0 	; Convert from paras to bytes
	mov	DGROUP:[edx].DPTSS_LaHPDA,ebx ; Save for later use

; Setup constant values in the HPDA

	push	es		; Save for a moment

	mov	es,SEL_4GB	; Get AGROUP data selector at PL0
	assume	es:AGROUP	; Tell the assembler about it

	mov	edi,ebx 	; ES:EDI ==> HPDA in first megabyte
	lea	esi,HPDA_TEMPLATE ; CS:ESI ==> HPDA template
	mov	ecx,(size HPDA_TEMPLATE)/4 ; ECX = # dwords in HPDA template
S32 rep movs	<AGROUP:[edi].EDD,HPDA_TEMPLATE.EDD> ; Copy template to HPDA

	pop	es		; Restore
	assume	es:DGROUP	; Tell the assembler about it

; Save back pointer to the current TSS

	mov	AGROUP:[ebx].HPDA_PCURTSS,edx ; Save as back pointer

; Save stack segment and initial offsets

	mov	ax,HPDASTK_TOP	; Get offset of top of HPDA stack
	mov	DGROUP:[edx].DPTSS_VMSTKOFF,ax ; Save for later use
	sub	ax,HPDASTK_SIZ	; Less size of HPDA stack
	mov	DGROUP:[edx].DPTSS_VMSTKBOT,ax ; Save for later use

; Save caller's EIP and ESP in new TSS for transfer

	movzx	eax,[ebp].INTXX_EIP.ELO ; Get the return EIP
	mov	DGROUP:[edx].TSS_EIP,eax ; Save for later use

	movzx	eax,[ebp].INTXX_ESP.ELO ; Get the return ESP
	mov	DGROUP:[edx].TSS_ESP,eax ; Save for later use

; Save the original segment registers so we can restore them when we exit

	mov	ax,[ebp].INTXX_DS ; Get original DS
	mov	AGROUP:[ebx].HPDA_vDS,ax ; Save to restore later
	mov	ax,[ebp].INTXX_ES ; ...   ES
	mov	AGROUP:[ebx].HPDA_vES,ax ; ...
	mov	ax,[ebp].INTXX_FS ; ...   FS
	mov	AGROUP:[ebx].HPDA_vFS,ax ; ...
	mov	ax,[ebp].INTXX_GS ; ...   GS
	mov	AGROUP:[ebx].HPDA_vGS,ax ; ...

; Initialize VM callback structures

	mov	ecx,HPDAVMC_CNT ; Get # VM callback structures
	movzx	eax,HPDAVMC_OFF ; Get offset of 1st VM callback struc
@@:
	mov	AGROUP:[ebx+eax].HPDAVMC_INTFF[0],@OPCOD_INT3 ; Mark as free

	add	eax,size HPDAVMC_STR ; Skip to next VM callback struc

	loop	@B		; Jump if more VM callback struc

; Clear the VM and CF bits, set IOPL to DPMIOPL; IF remains as set by the caller

	mov	eax,[ebp].INTXX_EFL ; Get the return EFL
	and	eax,not ((mask $VMHI) or (mask $IOPL) or (mask $CF))
	or	eax,@DPMIOPL shl $IOPL ; IOPL=@DPMIOPL
	mov	DGROUP:[edx].TSS_EFL,eax ; Save for later use

; Save our important registers into our own TSS to restore upon return

	mov	edx,DGROUP:[edx].DPTSS_PLNKTSS ; Get offset in DGROUP of prev TSS

	mov	DGROUP:[edx].TSS_CS,cs ; Save it
	mov	DGROUP:[edx].TSS_DS,ds ; ...
	mov	DGROUP:[edx].TSS_ES,es ; ...
	mov	DGROUP:[edx].TSS_FS,fs ; ...
	mov	DGROUP:[edx].TSS_GS,gs ; ...
	mov	DGROUP:[edx].TSS_SS,ss ; ...
	mov	DGROUP:[edx].TSS_EFL,0 ; ...

; Setup our return stack pointer to a minimum stack with just enough
; room to handle spurious IRET/Ds with NT set

; The following number must be large enough to handle all stack
; activity between the entry at INT31_VM2PM_RET through a return
; to the caller at the IRETD just above INT31_VM2PM_RET.

@SPURNT equ	256		; Size of stack for spurious TSS switch

	mov	eax,DGROUP:[edx].DPTSS_STKMIN ; Get minimum stack offset
	add	eax,@SPURNT	; Make it a short stack (with blueberries?)
	mov	DGROUP:[edx].TSS_ESP,eax ; Save in old TSS

	lea	eax,INT31_VM2PM_RET ; Get offset of our return EIP
	mov	DGROUP:[edx].TSS_EIP,eax ; ...

	REGREST <edi,esi,edx,ecx,ebx,eax> ; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_INITVARS endp		; End DPMIFN_INITVARS procedure
	NPPROC	DPMIFN_INITAPP -- Initialize Application Flags
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Initialize application flags

On entry:

EDX	=	offset in PRGOUP of the incoming TSS
SS:EBP	==>	INTXX_STR

On exit:

|

	pushad			; Save registers

; Because the MS linker (ver 5.09) has a bug in it where they
; mistakenly assume that their GP Fault handler is entered with
; a 16-bit LPM stack (even though they enter PM as a 32-bit app),
; we need to recognize them and set a flag which forces us to use
; a 16-bit LPM stack.

	test	DB2_FLAG,@DB2_LPM16 ; Force 16-bit LPM stack anyway?
	jnz	short DPMIFN_INITAPP_LPM16 ; Jump if so

; We recognize the MS linker by the code which follows it in memory
; after the call to us to EPM.

	movzx	esi,[ebp].INTXX_CS ; Get caller's CS
	shl	esi,4-0 	; Convert from paras to bytes
	add	esi,[ebp].INTXX_EIP ; Plus caller's EIP
				; to get return address
	cmp	AGROUP:[esi].EDD,97B80673h ; Izit MS linker?
	jne	short DPMIFN_INITAPP1 ; Jump if not

	cmp	AGROUP:[esi+4].ELO,0E903h ; Izit MS linker?
	jne	short DPMIFN_INITAPP1 ; Jump if not
DPMIFN_INITAPP_LPM16:
	or	DGROUP:[edx].DPTSS_FLAG,mask $DPTSS_LPM16 ; Mark as forcing
DPMIFN_INITAPP1:





	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_INITAPP endp		; End DPMIFN_INITAPP procedure
	NPPROC	DPMIFN_DELINKTSS -- De-link TSS If Fault in Middle
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

De-link this TSS if we faulted in the middle of the chain
Note that we *MUST* call this routine before we have reset PCURTSS.

On entry:

EDX	=	PCURTSS

|

	REGSAVE <eax,ecx,edx>	; Save registers

; Search through all valid TSSs looking for one
; whose DPTSS_PLNKTSS == PCURTSS and de-link that one

	mov	ecx,@TSS_MAX	; Get maximum # TSSs
	mov	eax,PVMTSS	; Get offset in DGROUP of the 1st TSS
DPMIFN_DELINKTSS_NEXT:
	cmp	edx,DGROUP:[eax].DPTSS_PLNKTSS ; Duzit point to outgoing TSS?
	je	short @F	; Jump if so

	add	eax,type DPTSS_STR ; Skip to next TSS

	loop	DPMIFN_DELINKTSS_NEXT ; Jump if more TSS to check

	jmp	short DPMIFN_DELINKTSS_EXIT ; Join common exit code

@@:
	mov	ecx,DGROUP:[edx].DPTSS_PLNKTSS ; Get offset in DGROUP of prev TSS
	mov	DGROUP:[eax].DPTSS_PLNKTSS,ecx ; De-link us

	mov	cx,DGROUP:[edx].TSS_LINK ; Get prev TSS link
	mov	DGROUP:[eax].TSS_LINK,cx ; De-link us
DPMIFN_DELINKTSS_EXIT:
	REGREST <edx,ecx,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_DELINKTSS endp		; End DPMIFN_DELINKTSS procedure
	NPPROC	DPMIFN_PLNKTSS -- Back Off To Previous TSS and Selector
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Back off to the previous TSS and its selector.

On entry:

EDX	=	PCURTSS

|

	REGSAVE <eax,ebx>	; Save registers

	xor	eax,eax 	; Get invalid marker
	mov	DGROUP:[edx].TSS_LDT,ax ; Ensure invalid
	xchg	eax,DGROUP:[edx].DPTSS_PLNKTSS ; Get offset in DGROUP of the prev TSS
	mov	PCURTSS,eax	; Back off to previous TSS
	mov	PPRMTSS,eax	; ...

;;; ; Restore the current PLCL_PL0CUR state from the incoming TSS
;;;
;;;	    mov     ebx,DGROUP:[eax].DPTSS_PLCL_PL0CUR ; Get the original value
;;;	    mov     PLCL_PL0CUR,ebx ; Restore
;;;
	mov	ax,-1		; Get available TSS marker
	xchg	ax,DGROUP:[edx].TSS_LINK ; Mark as available
	mov	VM2PM_TSS,ax	; Back off to previous TSS selector

	REGREST <ebx,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_PLNKTSS endp		; End DPMIFN_PLNKTSS procedure
	NPPROC	DPMIFN_FREE_VMOLDPM -- Free First Old PM Data Area
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Free the first old PM data area if we are back to the first TSS.

Note that this routine must be called *BEFORE* PCURTSS has been
restored to the incoming TSS.

|

	REGSAVE <edx>		; Save register

	mov	edx,PCURTSS	; Get offset in DGROUP of the current TSS
	mov	edx,DGROUP:[edx].DPTSS_PLNKTSS ; Get offset in DGROUP of prev TSS

	cmp	edx,PVMTSS	; Izit the 1st TSS?
	jne	short DPMIFN_FREE_VMOLDPM_EXIT ; Jump if not

	cmp	DGROUP:[edx].DPTSS_OLDPM,0 ; Izit initialized as yet?
	je	short @F	; Jump if not

	push	DPMIOLDPM_SIZ	; Pass byte length
	push	DGROUP:[edx].DPTSS_OLDPM ; Pass starting linear address
	call	DEALLOCMEM	; Deallocate the memory
	jnc	short @F	; Jump if no error

	SWATMAC ERR		; Call our debugger
@@:
	mov	DGROUP:[edx].DPTSS_OLDPM,0 ; Mark as not initialized
DPMIFN_FREE_VMOLDPM_EXIT:
	REGREST <edx>		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_FREE_VMOLDPM endp	; End DPMIFN_FREE_VMOLDPM procedure
	NPPROC	DPMIFN_INITLDT -- Initialize the Contents of the LDT
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Initialize the contents of the LDT and install it as the current one.

On entry:

AGROUP:EDX ==>	 current TSS

|

	REGSAVE <eax,ecx,edi,es> ; Save registers

; Initialize the LDT contents to zero

	mov	es,SEL_4GB	; Get AGROUP data selector at PL0
	assume	es:AGROUP	; Tell the assembler about it

	mov	edi,DGROUP:[edx].DPTSS_LaLDT ; Get linear address of DPMI LDT
	xor	eax,eax 	; Set contents to this value
	mov	ecx,XLDT_SIZ	; Get byte size of extended LDT (/@DPMI_BOUND)
	shr	ecx,2-0 	; Convert from bytes to dwords
    rep stos	AGROUP:[edi].EDD ; Initialize it

; Set linear address of new DPMI LDT in the GDT

	mov	eax,DGROUP:[edx].DPTSS_LaLDT ; Get linear address of DPMI LDT

	mov	ecx,CPL0_LDT	; Get A/R byte
	or	cl,DPMI_DPL	; Include DPL
	push	DGROUP:[edx].DPTSS_LDT_SIZ ; Pass size of area in bytes (/8)
	push	cx		; Pass access rights word
	push	DGROUP:[edx].TSS_LDT ; Pass descriptor to set
	call	SET_GDT 	; Set the GDT to EAX base

; Tell the CPU about the new LDTR

	lldt	DGROUP:[edx].TSS_LDT ; Set LDTR

; Save linear address of DPMI LDT as Read-Write data descriptor at PL3
; now so we get the same selector for each LDT

	mov	eax,DGROUP:[edx].DPTSS_LaLDT ; Get linear address of DPMI LDT

	push	DGROUP:[edx].DPTSS_LDT_SIZ ; Pass size of area in bytes (/8)
	push	DPMI_DATA	; Pass access rights word
	push	word ptr LDTE_DATALDT3 ; Pass descriptor to set
	call	SET_GDT 	; Set the GDT to EAX base

; Save linear address of DPMI LPM as Read-Write data descriptor at PL3
; now so we get the same selector for each LDT

	mov	eax,DGROUP:[edx].DPTSS_LPMBASE ; Get linear address of LPM

	mov	cl,DPMI_DATA.LO ; Get A/R byte for 16-bit client
	mov	ch,0		; Assume 16-bit stack

	test	DGROUP:[edx].DPTSS_FLAG,mask $DPTSS_LPM16 ; Force 16-bit LPM stack?
	jnz	short @F	; Jump if so

	cmp	DPMITYPE,@DPMITYPE16 ; Izit a 16-bit client?
	setne	ch		; CH = 1 if 32-bit or no DPMI
				;    = 0 if 16-bit
	shl	ch,$DTE_B	; Set B-bit for 32-bit apps
@@:
	mov	edi,LPMSTK_SIZ	; Get size of area in bytes
if @EXPD
	or	cl,mask $DD_EXPD ; Mark as Expand Down
	add	eax,edi 	; Move base address to just beyond size
	neg	edi		; Negate for Expand Down

	test	ch,mask $DTE_B	; Izit a 32-bit stack?
	jnz	short @F	; Jump if so

	sub	eax,64*1024	; Move base down
	movzx	edi,di		; Zero the high-order word
@@:
endif
	push	edi		; Pass size of area in bytes
	push	cx		; Pass access rights word
	push	word ptr LDTE_DATALPM3 ; Pass descriptor to set
	call	SET_GDT 	; Set the GDT to EAX base

	REGREST <es,edi,ecx,eax> ; Restore
	assume	es:DGROUP	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_INITLDT endp		; End DPMIFN_INITLDT procedure
	NPPROC	DPMIFN_INITDPMIHNDL -- Initialize the Contents of the DPMI Memory Handle Table
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Initialize the contents of the DPMI memory handle table

On entry:

AGROUP:EDX ==>	 current TSS

|

	REGSAVE <eax,ecx,edi,es> ; Save registers

; Initialize the DPMI memory handle table contents to zero

	mov	es,SEL_4GB	; Get AGROUP data selector at PL0
	assume	es:AGROUP	; Tell the assembler about it

	mov	edi,DGROUP:[edx].DPTSS_LaDPMIHNDL ; Get linear address of DPMI
				; memory handle table
	mov	al,0		; Set contents to this value
	mov	ecx,DGROUP:[edx].DPTSS_DPMIHNDL_CNT ; Get total # handles
	imul	ecx,type DPMIHNDL_STR ; Convert from struc to bytes
    rep stos	AGROUP:[edi].LO ; Initialize it

	REGREST <es,edi,ecx,eax> ; Restore
	assume	es:DGROUP	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_INITDPMIHNDL endp	; End DPMIFN_INITDPMIHNDL procedure
	NPPROC	DPMIFN_FREELDT -- De-allocate The LDT
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

On entry:

Note that both PCURTSS and VM2PM_TSS point to the outgoing TSS.

|

	REGSAVE <eax,ebx,edx,ds> ; Save registers

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	edx,PCURTSS	; Get offset in DGROUP of current TSS

	mov	eax,DGROUP:[edx].DPTSS_LDT_SIZ ; Get byte size of DPMI LDT (/8)
	call	DPMIFN_XLDT_SIZ ; Return with EBX = byte size of extended
				; DPMI LDT using LDT_SIZ of EAX

	cmp	DGROUP:[edx].DPTSS_LaLDT,0 ; Izit initialized as yet?
	je	short DPMIFN_FREELDT_EXIT ; Jump if not (leave LDTR alone
				; as we haven't switched to this client)
	push	ebx		; Pass byte length
	push	DGROUP:[edx].DPTSS_LaLDT ; Pass starting linear address
	call	DEALLOCMEM	; Deallocate the memory
	jnc	short @F	; Jump if no error

	SWATMAC ERR		; Call our debugger
@@:
	mov	DGROUP:[edx].DPTSS_LaLDT,0 ; Mask as not initialized

; Invalidate the LDTR until we switch back to the previous client

	xor	ax,ax		; An invalid DTE
	lldt	ax		; Set LDTR
DPMIFN_FREELDT_EXIT:
	REGREST <ds,edx,ebx,eax> ; Restore
	assume	ds:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_FREELDT endp		; End DPMIFN_FREELDT procedure
	NPPROC	DPMIFN_SAVEOLDPM -- Save Current Data to Old PM Data Area
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Save current data into old PM data area
and re-initialize all values if asked to.

The structure of the old PM data area is

SIRBCUR
DPMI_CPIHOOK
DPMI_CPFHOOK
DPMI_CVFHOOK
PMINT_FVECS
PMINT_DVECS
PMFLT_FVECS
PMFLT_DVECS
VMFLT_FVECS
VMFLT_DVECS
LAST_DPMI_DS
LAST_DPMI_ES
LAST_DPMI_FS
LAST_DPMI_GS
I31_FLAG
DPMITYPE
DBGCTL
DBGSTA
DBGREGS
DBGDR7

If any fields are added/deleted from this list, be sure to update
DPMIFN_RESTOLDPM as well as the size calculations in QMAX_ARG.ASM in
the CHECK_ARGS_VALIDxx section.

|

SAVEOLDPM_STR struc

	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
SAVEOLDPM_FLG dd ?		; Flag:  1 = re-initialize variables
				;	 0 = don't
SAVEOLDPM_TSS dd ?		; Offset in DGROUP of TSS to use

SAVEOLDPM_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	pushad			; Save all EGP registers
	REGSAVE <es>		; Save selector

	mov	es,SEL_4GB	; Get AGROUP data selector at PL0
	assume	es:AGROUP	; Tell the assembler about it

	mov	edi,[ebp].SAVEOLDPM_TSS ; Get offset in DGROUP of TSS to use
	mov	edi,DGROUP:[edi].DPTSS_OLDPM ; Get linear address of old PM data area


; Skip over SIRBCUR

	test	CPUFET_FLAG,mask $CPUFET_VME ; Is VME supported?
	jz	short @F	; Jump if not

	add	edi,256/8	; Skip over SIRBCUR table
@@:


; Copy DPMI_CPIHOOK

	lea	esi,DPMI_CPIHOOK ; Get offset in DGROUP of current PM
				; interrupt hook bitmap
	add	esi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,256/(8*4)	; Get size of table in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy to old PM data area


; Copy DPMI_CPFHOOK

	lea	esi,DPMI_CPFHOOK ; Get offset in DGROUP of current PM
				; fault hook bitmap
	add	esi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,32/(8*4)	; Get size of table in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy to old PM data area


; Copy DPMI_CVFHOOK

	lea	esi,DPMI_CVFHOOK ; Get offset in DGROUP of current VM
				; fault hook bitmap
	add	esi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,32/(8*4)	; Get size of table in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy to old PM data area


; Copy PMINT_FVECS

	lea	esi,DGROUP:PMINT_FVECS ; Get offset in DGROUP of PMINT_FVECS
	add	esi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,(256/4)*(type PMINT_FVECS) ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy to old PM data area


; Copy PMINT_DVECS

	lea	esi,DGROUP:PMINT_DVECS ; Get offset in DGROUP of PMINT_DVECS
	add	esi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,(256/4)*(type PMINT_DVECS) ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy to old PM data area


; Copy PMFLT_FVECS

	lea	esi,DGROUP:PMFLT_FVECS ; Get offset in DGROUP of PMFLT_FVECS
	add	esi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,(32/4)*(type PMFLT_FVECS) ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy to old PM data area


; Copy PMFLT_DVECS

	lea	esi,DGROUP:PMFLT_DVECS ; Get offset in DGROUP of PMFLT_DVECS
	add	esi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,(32/4)*(type PMFLT_DVECS) ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy to old PM data area


; Copy VMFLT_FVECS

	lea	esi,DGROUP:VMFLT_FVECS ; Get offset in DGROUP of VMFLT_FVECS
	add	esi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,(32/4)*(type VMFLT_FVECS) ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy to old PM data area


; Copy VMFLT_DVECS

	lea	esi,DGROUP:VMFLT_DVECS ; Get offset in DGROUP of VMFLT_DVECS
	add	esi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,(32/4)*(type VMFLT_DVECS) ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy to old PM data area


; Copy LAST_DPMI_xS

	mov	ax,LAST_DPMI_DS ; Get the value
S32	stos	AGROUP:[edi].ELO ; Copy to old PM data area
	mov	ax,LAST_DPMI_ES ; Get the value
S32	stos	AGROUP:[edi].ELO ; Copy to old PM data area
	mov	ax,LAST_DPMI_FS ; Get the value
S32	stos	AGROUP:[edi].ELO ; Copy to old PM data area
	mov	ax,LAST_DPMI_GS ; Get the value
S32	stos	AGROUP:[edi].ELO ; Copy to old PM data area


; Copy I31_FLAG

	mov	ax,I31_FLAG	; Get the value
S32	stos	AGROUP:[edi].ELO ; Copy to old PM data area


; Copy DPMITYPEIG

	mov	al,DPMITYPEIG	; Get the value
S32	stos	AGROUP:[edi].LO ; Copy to old PM data area


; Copy DBGCTL

	mov	al,DBGCTL	; Get the value
S32	stos	AGROUP:[edi].LO ; Copy to old PM data area


; Copy DBGSTA

	mov	al,DBGSTA	; Get the value
S32	stos	AGROUP:[edi].LO ; Copy to old PM data area


; Copy DBGREGS

	lea	esi,DGROUP:DBGREGS ; Get offset in DGROUP of DBGREGS
	add	esi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,4*(type DBGREGS)/4 ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy to old PM data area


; Copy DBGDR7

	mov	eax,DBGDR7	; Get the value
S32	stos	AGROUP:[edi].EDD ; Copy to old PM data area


; Check on whether or not we should re-initialize

	cmp	[ebp].SAVEOLDPM_FLG,1 ; Should we?
	jne	near ptr DPMIFN_SAVEOLDPM_EXIT ; Jump if not

; Re-initialize SIRBCUR to default values

	test	CPUFET_FLAG,mask $CPUFET_VME ; Is VME supported?
	jz	short DPMIFN_SAVEOLDPM_XP5 ; Jump if not

	MOVSPR	eax,cr4 	; Get CPU extensions register

	test	eax,mask $VME	; Izit enabled?
	jz	short DPMIFN_SAVEOLDPM_XP5 ; Jump if not

	mov	eax,PVMTSS	; Get offset in DGROUP of the 1st TSS
	mov	esi,DGROUP:[eax].DPTSS_LaSIRBCUR ; Get linear address of the
				; default SIRB table
	mov	edi,LaSIRBCUR	; Get linear address of current SIRB table

	mov	ecx,(256/8)/4	; Get size of table in dwords
	push	edi		; Save for a moment
S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy it
	pop	edi		; Restore

; Set SIRBCUR values for INTs 23h and 24h at AGROUP:EDI using SIRB_MAC

	SIRB_MAC 23		; INT  23h - Ctrl-Break termination
	SIRB_MAC 24		; ...  24h - Critical Error termination

	call	SIRBCUR2B	; Copy SIRBCUR values to SIRB
DPMIFN_SAVEOLDPM_XP5:

; Re-initialize DPMI_PPIHOOK

	lea	edi,DPMI_PPIHOOK ; Get offset in DGROUP of primary PM
				; interrupt hook bitmap
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,256/(8*4)	; Get size of table in dwords
	xor	eax,eax 	; Initial value
    rep stos	AGROUP:[edi].EDD ; Zero it


; Re-initialize DPMI_CPIHOOK

	lea	edi,DPMI_CPIHOOK ; Get offset in DGROUP of current PM
				; interrupt hook bitmap
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,256/(8*4)	; Get size of table in dwords
	xor	eax,eax 	; Initial value
    rep stos	AGROUP:[edi].EDD ; Zero it


; Re-initialize DPMI_CPFHOOK

	lea	edi,DPMI_CPFHOOK ; Get offset in DGROUP of current PM
				; fault hook bitmap
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,32/(8*4)	; Get size of table in dwords
	xor	eax,eax 	; Initial value
    rep stos	AGROUP:[edi].EDD ; Zero it


; Re-initialize DPMI_CVFHOOK

	lea	edi,DPMI_CVFHOOK ; Get offset in DGROUP of current VM
				; fault hook bitmap
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,32/(8*4)	; Get size of table in dwords
	xor	eax,eax 	; Initial value
    rep stos	AGROUP:[edi].EDD ; Zero it


; Re-initialize DPMI_PPIHOOK

	lea	edi,DPMI_PPIHOOK ; Get offset in DGROUP of primary PM
				; interrupt hook bitmap
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,256/(8*4)	; Get size of table in dwords
	xor	eax,eax 	; Initial value
    rep stos	AGROUP:[edi].EDD ; Zero it


; Re-initialize DPMI_PVFHOOK

	lea	edi,DPMI_PVFHOOK ; Get offset in DGROUP of primary VM
				; fault hook bitmap
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,32/(8*4)	; Get size of table in dwords
	xor	eax,eax 	; Initial value
    rep stos	AGROUP:[edi].EDD ; Zero it


; Re-initialize PMINT_xVECS

	mov	es,SEL_DATA	; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	mov	ecx,256 	; # entries in PMINT_xVECS
	xor	esi,esi 	; Initialize index into PMINT_FVECS
	xor	edi,edi 	; Initialize index into PMINT_DVECS
	mov	eax,PMIDEF00	; Get initial routine offset
	mov	edx,DTE_DPMIDEF ; Get the selector
	or	dl,DPMI_CPL	; Set the CPL/RPL bits
DPMIFN_SAVEOLDPM_NEXT_IDEF:
	mov	PMINT_FVECS.FSEL[esi],dx ; Set selector
	mov	PMINT_DVECS.VSEG[edi],dx ; ...

	mov	PMINT_FVECS.FOFF[esi],eax ; Set offset
	mov	PMINT_DVECS.VOFF[edi],ax  ; ...

	add	esi,type PMINT_FVECS ; Skip to next entry
	add	edi,type PMINT_DVECS ; ...
	add	eax,@PMxDEF_LEN ; ...

	loop	DPMIFN_SAVEOLDPM_NEXT_IDEF ; Jump if more handlers


; Re-initialize PMFLT_xVECS and VMFLT_xVECS

	mov	ecx,32		; # entries in PMFLT_xVECS & VMFLT_xVECS
	xor	esi,esi 	; Initialize index into PMFLT_FVECS & VMFLT_FVECS
	xor	edi,edi 	; Initialize index into PMFLT_DVECS & VMFLT_DVECS
	mov	eax,PMFDEF00	; Get initial routine offset
	mov	ebx,VMFDEF00	; ...
	mov	edx,DTE_DPMIDEF ; Get the selector
	or	dl,DPMI_CPL	; Set the CPL/RPL bits
DPMIFN_SAVEOLDPM_NEXT_FDEF:
	mov	PMFLT_FVECS.FSEL[esi],dx ; Set selector
	mov	PMFLT_DVECS.VSEG[edi],dx ; ...

	mov	VMFLT_FVECS.FSEL[esi],dx ; Set selector
	mov	VMFLT_DVECS.VSEG[edi],dx ; ...

	mov	PMFLT_FVECS.FOFF[esi],eax ; Set offset
	mov	PMFLT_DVECS.VOFF[edi],ax  ; ...

	mov	VMFLT_FVECS.FOFF[esi],ebx ; Set offset
	mov	VMFLT_DVECS.VOFF[edi],bx  ; ...

	add	esi,type PMFLT_FVECS ; Skip to next entry
	add	edi,type PMFLT_DVECS ; ...
	add	eax,@PMxDEF_LEN ; ...
	add	ebx,@PMxDEF_LEN ; ...

	loop	DPMIFN_SAVEOLDPM_NEXT_FDEF ; Jump if more handlers


; Re-initialize LAST_DPMI_xS

	mov	LAST_DPMI_DS,0	; Clear for next time
	mov	LAST_DPMI_ES,0	; ...
	mov	LAST_DPMI_FS,0	; ...
	mov	LAST_DPMI_GS,0	; ...


; Re-initialize I31_FLAG

	and	I31_FLAG,@I31_PERCLIENT ; Isolate DPMI client-specific flags


; Re-initialize DPMITYPEIG

	mov	al,DPMITYPE	; Get the new value
	mov	DPMITYPEIG,al	; Save to check the next time


; Re-initialize DBGDR7

	mov	DBGDR7,0	; Clear for next time


; Re-initialize DR0-3 and DR7

	xor	eax,eax 	; A convenient zero
	mov	ebx,dr7 	; Get debug control register

	bt	DBGCTL,0	; Test bit for DR0
	jnc	short @F	; Jump if inactive

	mov	dr0,eax 	; Clear for next time
	and	ebx,not ((mask $LEN0) or (mask $RW0) or (mask $G0) or (mask $L0))
@@:
	bt	DBGCTL,1	; Test bit for DR1
	jnc	short @F	; Jump if inactive

	mov	dr1,eax 	; Clear for next time
	and	ebx,not ((mask $LEN1) or (mask $RW1) or (mask $G1) or (mask $L1))
@@:
	bt	DBGCTL,2	; Test bit for DR2
	jnc	short @F	; Jump if inactive

	mov	dr2,eax 	; Clear for next time
	and	ebx,not ((mask $LEN2) or (mask $RW2) or (mask $G2) or (mask $L2))
@@:
	bt	DBGCTL,3	; Test bit for DR3
	jnc	short @F	; Jump if inactive

	mov	dr3,eax 	; Clear for next time
	and	ebx,not ((mask $LEN3) or (mask $RW3) or (mask $G3) or (mask $L3))
@@:
	mov	dr7,ebx 	; Clear for next time


; Re-initialize DBGCTL

	mov	DBGCTL,0	; Clear for next time


; Re-initialize DBGSTA

	mov	DBGSTA,0	; Clear for next time


; Re-initialize DBGREGS

	lea	edi,DGROUP:DBGREGS ; Get offset in DGROUP of DBGREGS
	mov	ecx,4*(type DBGREGS)/4 ; Get size in dwords
	xor	eax,eax 	; Initialize to this value
    rep stos	DBGREGS[edi]	; Clear for next time
DPMIFN_SAVEOLDPM_EXIT:
	REGREST <es>		; Restore selector
	assume	es:DGROUP	; Tell the assembler about it
	popad			; Restore all EGP registers

	pop	ebp		; Restore

	ret	4+4		; Return to caller, popping arguments

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_SAVEOLDPM endp		; End DPMIFN_SAVEOLDPM procedure
	NPPROC	CHECK_ENVCFG -- Check For This Program In CFG File
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Check for This program in the CFG file and set a bit if found.

On entry:

AX	=	environment selector
EDX	=	offset in DGROUP of DPTSS_STR
SS:EBP	==>	INTXX_STR

On exit:

AX	=	environment selector (possibly now at PL1)

|

	REGSAVE <ebx,ecx,esi,edi,es> ; Save registers

	mov	es,ax		; Address the environment
	assume	es:nothing	; Tell the assembler about it

	xor	edi,edi 	; Start at the beginning
	mov	ecx,@ENVLEN	; Get selector length
	mov	al,0		; Search for the end
@@:
	cmp	al,1		; Ensure ZF=0 in case CX=0
  repne scas	es:[edi].LO	; Scan for end of next string
	jne	near ptr CHECK_ENVCFG_DONE ; Jump if not found

	scas	es:[edi].LO	; Izit double zero at end of environment?
	jne	short @B	; Jump if not

; We're at the end of the environment

	add	edi,2		; Skip over the string counter
	sub	ecx,2		; Account for it
	jbe	near ptr CHECK_ENVCFG_DONE ; Jump if nothing remains

; Copy the name of the application in case we need to display it later

	call	COPY_APPLNAME	; Copy the application name at ES:EDI

; Search for the end of the program name

  repne scas	es:[edi].LO	; Scan for end of program name
	jne	near ptr CHECK_ENVCFG_DONE ; Jump if not found???

	dec	edi		; Back off to trailing zero
	mov	ecx,edi 	; Copy offset so far as the length

; Back up to the start of the program name

	mov	al,'\'          ; Look for trailing backslash
	std			; Search backwards
  repne scas	es:[edi].LO	; Search for it
	cld			; Restore
	jne	near ptr CHECK_ENVCFG_DONE ; Jump if not found???

	add	edi,2		; Skip over backslash to start of program name

; Check for KRNL386.EXE which requires special treatment

	cmp	ecx,@KRNL386_LEN ; Use the smaller
	jb	near ptr CHECK_ENVCFG_DONE ; Jump if file is smaller

	mov	ecx,@KRNL386_LEN ; Use length of program name

	lea	esi,KRNL386	; DS:ESI ==> KRNL386 name
CHECK_ENVCFG1:
   repe cmps	KRNL386[esi],es:[edi].LO ; Compare 'em
	je	short @F	; Jump it it's a match

	mov	al,ds:[esi-1]	; Get last source char
	mov	ah,es:[edi-1]	; ...	   destin ...
	or	ax,2020h	; Convert to lowercase

	cmp	al,ah		; Are they still different?
	je	short CHECK_ENVCFG1 ; Jump if not

	jmp	CHECK_ENVCFG_DONE ; Jump if no match


@@:
	or	PDC_FLAG,@I31_KRNL ; Mark as Windows DPMI client

if @W9X

; At least Win9x needs to find "windir=..." as the first
; environment variable

	lea	esi,WINDIREQ	; DS:ESI ==> "windir=..."
	mov	ecx,@WINDIREQ_LEN ; Length of ...
	xor	edi,edi 	; ES:EDI ==> start of environment
    rep movs	es:[edi].LO,WINDIREQ[esi] ; Copy to environment

; Now copy the Windows directory

	lea	esi,MSG_APPLNAME[size LENTXT_LEN] ; DS:ESI ==> application dir
	mov	ecx,WINDIR_LEN	; Get length of ...
    rep movs	es:[edi].LO,MSG_APPLNAME[esi].LO ; Copy to environment

; If the directory ends with a '\', delete it

	cmp	es:[edi-1].LO,'\' ; Izit a backslash?
	jne	short @F	; Jump if not

	dec	edi		; Back over it
@@:
	mov	al,0		; Terminating zero
	stos	es:[edi].LO	; Terminate it

; In case of really bad luck, we might have overlaid the first
; entry such that the terminator we just stored is followed by
; another terminator.  If we don't do anything, this situation
; will be recognized as the end of the environment (double zero),
; so we store an arbitrary character over the second zero which
; in effect starts the next environment name with that character.
; We assume that there are enough entries in the environment that
; we not at the actual end of the environment.

	cmp	es:[edi].LO,0	; Izit another terminator?
	jne	short @F	; Jump if not

	mov	al,'_'          ; Get an arbitrary character
	stos	es:[edi].LO	; Start it
@@:
endif

;;; ; Tell SWAT that Windows is coming up (sort of) so it can
;;; ; ignore ARPLs and 0F FFs
;;;
;;;	     push    SWATCODE.FSEL.EDD ; Get SWAT code selector as dword
;;;	     call    GETBASE	    ; Return with EAX = base address of selector
;;;
;;;	     or      AGROUP:[eax].MD_ATTR,@MD_WIN3 ; Mark as Windows active
;;;
; If this is Windows 3.00, we must change all our PL3 values to PL1
; Alas, I can't seem to find a way to distinguish Windows 3.00 from
; later versions except by a few bytes preceding the return address
; in the caller's code segment.  Here we go again.

	movzx	ebx,[ebp].INTXX_CS ; Get caller's CS
	shl	ebx,4-0 	; Convert from paras to bytes
	movzx	eax,[ebp].INTXX_EIP.ELO ; Get caller's IP

	cmp	AGROUP:[ebx+eax-1Dh].EDD,7203F980h ; Izit CMP CL,03//JC xxx ?
	jne	near ptr CHECK_ENVCFG_DONE ; Jump if not

	or	PDC_FLAG,@I31_WIN3 ; Mark as Windows 3.00

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	mov	eax,[esp].DTR_BASE ; AGROUP:EAX ==> GDT
	add	esp,size DTR_STR ; Strip

	add	eax,DTE_DPMIDEF ; Plus the selector

; Change DPL of DTE_DPMIDEF from @DPMI_DPL to 1

	and	AGROUP:[eax].DESC_ACCESS,not (mask $DT_DPL) ; Clear DPL bits
	or	AGROUP:[eax].DESC_ACCESS,1 shl $DT_DPL ; DPL=1

; Change DPL of DTE_DATALPM from @DPMI_DPL to 1

	mov	edi,DGROUP:[edx].DPTSS_LaLDT ; Get linear address of DPMI LDT
	and	AGROUP:[edi].DTE_DATALPM.DESC_ACCESS,not (mask $DT_DPL) ; Clear DPL bits
	or	AGROUP:[edi].DTE_DATALPM.DESC_ACCESS,1 shl $DT_DPL ; DPL=1

; Change RPL of default interrupt handlers from @DPMI_CPL to 1

	mov	ax,1 shl $PL	; RPL=1
	call	DPMIFN_SETRPL	; Set RPL of default interrupt handlers to AX

; Change LPM stack selector RPL from @DPMI_CPL to 1

	and	LPMSTK_SEL,not (mask $PL) ; Clear the PL bits
	or	LPMSTK_SEL,1 shl $PL ; RPL=1

; Set DPMI client RPL and DPL to 1

	mov	DPMI_CODE,CPL0_CODE or (1 shl $DT_DPL)
	mov	DPMI_DATA,CPL0_DATA or (1 shl $DT_DPL)
	mov	eax,DTE_DPMIDEF ; Get the selector
	or	ax,1 shl $PL	; Set the PL bits
	mov	DPMI_IDEF,ax	; Save for later use
	mov	DPMI_CPL,1 shl $PL
	mov	DPMI_DPL,1 shl $DT_DPL

; Change LDT entries from @DPMI_DPL to 1

	mov	ebx,DGROUP:[edx].DPTSS_LaLDT ; Get linear address of DPMI LDT
	mov	ecx,DGROUP:[edx].DPTSS_LDT_SIZ ; Get byte size of DPMI LDT (/8)
	shr	ecx,3-0 	; Convert from bytes to qwords (# LDTEs)
CHECK_ENVCFG_NEXT:
	mov	al,AGROUP:[ebx].DESC_ACCESS ; Get the A/R byte

	and	al,mask $DT_DPL ; Isolate the DPL

	cmp	al,DPMI_DPL	; Izit at DPMI DPL?
	jne	short @F	; Jump if not

	and	AGROUP:[ebx].DESC_ACCESS,not (mask $DT_DPL) ; Clear DPL bits
	or	AGROUP:[ebx].DESC_ACCESS,1 shl $DT_DPL ; Set to DPL1
@@:
	add	ebx,type DESC_STR ; Skip to next LDTE

	loop	CHECK_ENVCFG_NEXT ; Jump if more LDTEs to check

; Change DPTSS selectors RPL from @DPMI_CPL to 1

	mov	ax,DGROUP:[edx].TSS_CS ; Get caller's CS
	and	ax,not (mask $PL) ; Clear PL bits
	or	ax,1 shl $PL	; CPL = 1
	mov	DGROUP:[edx].TSS_CS,ax ; Restore

	mov	ax,DGROUP:[edx].DPTSS_DTA_FVEC.FSEL ; Get caller's DTA
	and	ax,not (mask $PL) ; Clear PL bits
	or	ax,1 shl $PL	; CPL = 1
	mov	DGROUP:[edx].DPTSS_DTA_FVEC.FSEL,ax ; Restore

	mov	ax,DGROUP:[edx].TSS_DS ; Get caller's DS
	and	ax,not (mask $PL) ; Clear PL bits
	or	ax,1 shl $PL	; CPL = 1
	mov	DGROUP:[edx].TSS_DS,ax ; Restore

	mov	ax,DGROUP:[edx].TSS_ES ; Get caller's ES
	and	ax,not (mask $PL) ; Clear PL bits
	or	ax,1 shl $PL	; CPL = 1
	mov	DGROUP:[edx].TSS_ES,ax ; Restore

	mov	ax,DGROUP:[edx].TSS_SS ; Get caller's SS
	and	ax,not (mask $PL) ; Clear PL bits
	or	ax,1 shl $PL	; CPL = 1
	mov	DGROUP:[edx].TSS_SS,ax ; Restore

; Return AX as caller's environment selector at RPL1

	mov	ax,es		; Get caller's environment selector
	and	ax,not (mask $PL) ; Clear PL bits
	or	ax,1 shl $PL	; CPL = 1

	jmp	short CHECK_ENVCFG_EXIT ; Join common exit code


CHECK_ENVCFG_DONE:
	mov	ax,es		; Get caller's environment selector
CHECK_ENVCFG_EXIT:
	REGREST <es,edi,esi,ecx,ebx> ; Restore
	assume	es:DGROUP	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_ENVCFG endp		; End CHECK_ENVCFG procedure
	NPPROC	COPY_APPLNAME -- Copy The Application Name
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Copy the application name

On entry:

ES:EDI	==>	application d:\path\name

|

	REGSAVE <eax,ecx,esi,edi> ; Save registers

	mov	esi,edi 	; ES:ESI ==> application name
	mov	edi,size LENTXT_LEN ; DS:EDI ==> index into MSG_APPLNAME

	mov	ecx,MSG_APPLNAME_LEN ; Get maximum size
COPY_APPLNAME_NEXT:
	lods	es:[esi].LO	; Get one character

	or	al,al		; Izit EOL?
	jz	short COPY_APPLNAME_EOL ; Jump if so

;;;;;;; call	UPPERCASE	; Convert AL to uppercase
	cmp	al,'a'          ; Check lower limit
	jb	short @F	; Too small for us

	cmp	al,'z'          ; Check upper limit
	ja	short @F	; Too big for us

	add	al,'A'-'a'      ; Convert alpha to upper case
@@:
	mov	MSG_APPLNAME[edi].LO,al ; Copy one character
	inc	edi		; Skip over it
if @W9X
	cmp	al,':'          ; Izit a possible drive separator?
	je	short @F	; Jump if so

	cmp	al,'\'          ; Izit a path separator?
	je	short @F	; Jump if so

	cmp	al,'/'          ; Izit an alternate path separator?
	jne	short COPY_APPLNAME_LOOP ; Go around again if not
@@:
	mov	eax,edi
	sub	eax,size LENTXT_LEN ; Less header
	mov	APPDIR_LEN,eax	; Save as length of application
				; directory in MSG_APPLNAME
	sub	eax,7		; Less size of "system\"
	mov	WINDIR_LEN,eax	; Save as length of Windows
				; directory in MSG_APPLNAME
COPY_APPLNAME_LOOP:
endif
	loop	COPY_APPLNAME_NEXT ; Jump if more characters to check
COPY_APPLNAME_EOL:
	sub	ecx,MSG_APPLNAME_LEN ; Subtract from maximum length
	neg	ecx		; Negate to get actual length
	mov	MSG_APPLNAME.LENTXT_LEN,ecx ; Save text length

	REGREST <edi,esi,ecx,eax> ; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

COPY_APPLNAME endp		; End COPY_APPLNAME procedure
	NPPROC	DPMIFN_RESTWIN -- Restore PL State to Normal After Windows
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Restore the PL state to normal after Windows ran at PL1.

|

	REGSAVE <eax>		; Save registers

;;; ; Tell SWAT that Windows is no longer active
;;;
;;;	     push    SWATCODE.FSEL.EDD ; Get SWAT code selector as dword
;;;	     call    GETBASE	    ; Return with EAX = base address of selector
;;;
;;;	     and     AGROUP:[eax].MD_ATTR,not @MD_WIN3 ; Mark as Windows inactive
;;;
; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	mov	eax,[esp].DTR_BASE ; AGROUP:EAX ==> GDT
	add	esp,size DTR_STR ; Strip

	add	eax,DTE_DPMIDEF ; Plus the selector

; Change DPL of DTE_DPMIDEF from 1 to @DPMI_DPL

	and	AGROUP:[eax].DESC_ACCESS,not (mask $DT_DPL) ; Clear DPL bits
	or	AGROUP:[eax].DESC_ACCESS,@DPMI_DPL shl $DT_DPL ; DPL=@DPMI_DPL

; Reset LPM stack selector RPL to @DPMI_CPL

	and	LPMSTK_SEL,not (mask $PL) ; Clear the PL bits
	or	LPMSTK_SEL,@DPMI_CPL shl $PL ; RPL=@DPMI_CPL

; Reset RPL and DPL in case it was KRNL386

	mov	DPMI_CODE,CPL0_CODE or (@DPMI_DPL shl $DT_DPL)
	mov	DPMI_DATA,CPL0_DATA or (@DPMI_DPL shl $DT_DPL)
	mov	eax,DTE_DPMIDEF ; Get the selector
	or	ax,@DPMI_CPL shl $PL ; Set the PL bits
	mov	DPMI_IDEF,ax	; Save for later use
	mov	DPMI_CPL,@DPMI_CPL shl $PL
	mov	DPMI_DPL,@DPMI_DPL shl $DT_DPL

; Note we don't need to change the LDTE RPLs as we're about to abandon
; that LDT

	REGREST <eax>		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_RESTWIN endp		; End DPMIFN_RESTWIN procedure
	NPPROC	DPMIFN_SETRPL -- DPMI Function to Set RPL of Default Interrupt Handlers
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Set RPL of default interrupt handlers

On entry:

AX	=	new RPL

|

	REGSAVE <ecx,esi,edi>	; Save registers

	mov	ecx,256 	; # entries in PMINT_xVECS
	xor	esi,esi 	; Initialize index into PMINT_FVECS
	xor	edi,edi 	; Initialize index into PMINT_DVECS
DPMIFN_SETRPL_NEXT_IDEF:
	and	PMINT_FVECS.FSEL[esi],not (mask $PL) ; Clear PL bits
	and	PMINT_DVECS.VSEG[edi],not (mask $PL) ; ...

	or	PMINT_FVECS.FSEL[esi],ax ; RPL=AX
	or	PMINT_DVECS.VSEG[edi],ax ; ...

	add	esi,type PMINT_FVECS ; Skip to next entry
	add	edi,type PMINT_DVECS ; ...

	loop	DPMIFN_SETRPL_NEXT_IDEF ; Jump if more handlers

	mov	ecx,32		; # entries in PMFLT_xVECS & VMFLT_xVECS
	xor	esi,esi 	; Initialize index into PMFLT_FVECS & VMFLT_FVECS
	xor	edi,edi 	; Initialize index into PMFLT_DVECS & VMFLT_DVECS
DPMIFN_SETRPL_NEXT_FDEF:
	and	PMFLT_FVECS.FSEL[esi],not (mask $PL) ; Clear PL bits
	and	PMFLT_DVECS.VSEG[edi],not (mask $PL) ; ...

	and	VMFLT_FVECS.FSEL[esi],not (mask $PL) ; Clear PL bits
	and	VMFLT_DVECS.VSEG[edi],not (mask $PL) ; ...

	or	PMFLT_FVECS.FSEL[esi],ax ; RPL=AX
	or	PMFLT_DVECS.VSEG[edi],ax ; ...

	or	VMFLT_FVECS.FSEL[esi],ax ; RPL=AX
	or	VMFLT_DVECS.VSEG[edi],ax ; ...

	add	esi,type PMFLT_FVECS ; Skip to next entry
	add	edi,type PMFLT_DVECS ; ...

	loop	DPMIFN_SETRPL_NEXT_FDEF ; Jump if more handlers

	REGREST <edi,esi,ecx>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_SETRPL endp		; End DPMIFN_SETRPL procedure
	NPPROC	DPMIFN_FREEMEM -- Free Allocated Memory
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Free memory allocated to this DPMI client

|

	REGSAVE <eax,ecx,edx,edi> ; Save registers

	mov	edx,PCURTSS	; Get offset in DGROUP of the current TSS

	mov	ecx,DGROUP:[edx].DPTSS_DPMIHNDL_CNT ; Get total # handles
	mov	edi,DGROUP:[edx].DPTSS_LaDPMIHNDL ; AGROUP:EDI ==> DPMI memory
				; handle table
	and	edi,edi 	; Izit initialized as yet?
	jz	near ptr DPMIFN_FREEMEM_EXIT ; Jump if not

	mov	ax,VM2PM_TSS	; Get the current TSS selector
DPMIFN_FREEMEM_NEXT:
	cmp	AGROUP:[edi].DPMIHNDL_LEN,0 ; Izit a valid entry?
	je	short DPMIFN_FREEMEM_LOOP ; Jump if not

	cmp	ax,AGROUP:[edi].DPMIHNDL_TSS ; Izit the same client?
	jne	short DPMIFN_FREEMEM_LOOP ; Jump if not

	test	DPM_FLAG,mask $DPM_DPMITERM ; Should we tell anybody about this?
	jz	short @F	; Jump if not

	SWATMAC 		; Call our debugger
@@:

; Deallocate the memory

	push	AGROUP:[edi].DPMIHNDL_LEN ; Pass byte length
	push	AGROUP:[edi].DPMIHNDL_LA ; Pass starting linear address
	call	DEALLOCMEM	; Deallocate the memory
	jnc	short @F	; Jump if no error

	SWATMAC ERR		; Call our debugger
@@:

; Free the corresponding selector (if any)

	cmp	AGROUP:[edi].DPMIHNDL_SEL,0 ; Izit valid?
	je	short @F	; Jump if not

	push	AGROUP:[edi].DPMIHNDL_SEL ; Get the selector
	call	CLR_LDT 	; Free this LDT selector
	jnc	short @F	; Jump if no error

	SWATMAC ERR		; Call our debugger
@@:
	mov	AGROUP:[edi].DPMIHNDL_LEN,0 ; Free the handle
DPMIFN_FREEMEM_LOOP:
	add	edi,type DPMIHNDL_STR ; Skip to next entry

	loop	DPMIFN_FREEMEM_NEXT ; Jump if more handles to check

; Free the DPMI memory handle table itself

	mov	eax,DGROUP:[edx].DPTSS_DPMIHNDL_CNT ; Get total # handles
	imul	eax,type DPMIHNDL_STR ; Convert from struc to bytes
	add	eax,@DPMI_BOUND-1 ; Round up to next
	and	eax,not (@DPMI_BOUND-1) ; ... boundary for ALLOCMEM

	push	eax		; Pass byte length
	push	DGROUP:[edx].DPTSS_LaDPMIHNDL ; Pass starting linear address
	call	DEALLOCMEM	; Deallocate the memory
	jnc	short @F	; Jump if no error

	SWATMAC ERR		; Call our debugger
@@:
	mov	DGROUP:[edx].DPTSS_LaDPMIHNDL,0 ; Mark as not initialized
DPMIFN_FREEMEM_EXIT:
	REGREST <edi,edx,ecx,eax> ; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_FREEMEM endp		; End DPMIFN_FREEMEM procedure
	NPPROC	DPMIFN_RESTDYN -- Restore Data In Dynamic Save Area
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Restore data in dynamic save area

The structure of the dynamic save area is described in QMAX_DYN.INC

|

	pushad			; Save all EGP registers

	mov	bx,VM2PM_TSS	; Get the current TSS selector
	mov	edx,PCURTSS	; Get offset in DGROUP of current TSS

	mov	esi,DGROUP:[edx].DPTSS_DYN ; Get linear address of dynamic save area

	and	esi,esi 	; Izit initialized as yet?
	jz	near ptr DPMIFN_RESTDYN_EXIT ; Jump if not

	mov	edi,esi 	; Save for later use
DPMIFN_RESTDYN_NEXT:
	cmp	AGROUP:[esi].DYNHDR_FN,@DYNFN_EOL ; Izit End-of-the-line?
	je	near ptr DPMIFN_RESTDYN_DONE ; Jump if so

	cmp	AGROUP:[esi].DYNHDR_FN,@DYNFN_DEL ; Izit deleted?
	je	near ptr DPMIFN_RESTDYN_LOOP ; Jump if so

	cmp	bx,AGROUP:[esi].DYNHDR_TSS ; Izit the same TSS?
	jne	near ptr DPMIFN_RESTDYN_LOOP ; Jump if not

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

	cmp	AGROUP:[esi].DYNHDR_FN,@DYNFN_VMIV ; Izit VMIV function code?
	jne	short DPMIFN_RESTDYN_XVMIV ; Jump if not

	test	I31_FLAG,@I31_FAULT ; Did we terminate because of a fault?
	jz	short @F	; Jump if not

; Restore the original handler

	mov	edx,AGROUP:[esi].DYNVMIV_VEC ; Get original handler
	movzx	eax,AGROUP:[esi].DYNVMIV_NUM ; Get interrupt #

	assume	gs:INTVEC	; Tell the assembler about it
	mov	INT00_VEC[eax*(type INT00_VEC)],edx ; Restore
	assume	gs:AGROUP	; Tell the assembler about it
@@:
	jmp	short DPMIFN_RESTDYN_DEL ; Join common delete code

DPMIFN_RESTDYN_XVMIV:
	cmp	AGROUP:[esi].DYNHDR_FN,@DYNFN_P2L ; Izit GETP2L function code?
	jne	short DPMIFN_RESTDYN_XP2L ; Jump if not

; The following test is commented out because in the DPMI 0.9 spec
; the client has no way to free this mapping.
;;;;;;;
;;;;;;; test	DPM_FLAG,mask $DPM_DPMITERM ; Should we tell anybody about this?
;;;;;;; jz	short @F	; Jump if not
;;;;;;;
;;;;;;; SWATMAC 		; Call our debugger
;;; @@:

; Free the PTEs

	mov	eax,AGROUP:[esi].DYNP2L_OFF ; Get offset in DGROUP of 1st PTE
	sub	eax,DPMIPDIR_OFF ; Less offset in DGROUP of DPMI PDIRs
				; to get offset (/4)
	shl	eax,(12-2)-0	; Convert from 4KB in dwords to bytes
	add	eax,LaDPMIPDIRMEM ; Plus linear address of memory mapped by
				; first DPMI page directory (/4MB)
	or	eax,@PTE_URP	; Mark as User/Read-write/Present
	and	eax,not (mask $PTE_US) ; Mark as unallocated

	mov	edx,AGROUP:[esi].DYNP2L_OFF ; Get offset in DGROUP of 1st PTE
	mov	ecx,AGROUP:[esi].DYNP2L_LEN ; Get # PTEs to free
@@:
	mov	DGROUP:[edx],eax ; Mark as available
	add	eax,CON4KB	; Skip to next PTE
	add	edx,4		; Skip to next PTE

	loop	@B		; Jump if more PTEs to free

	jmp	short DPMIFN_RESTDYN_DEL ; Join common delete code

DPMIFN_RESTDYN_XP2L:
	SWATMAC ERR		; Call our debugger (unknown function code)






DPMIFN_RESTDYN_DEL:
	mov	AGROUP:[esi].DYNHDR_FN,@DYNFN_DEL ; Mark as deleted
DPMIFN_RESTDYN_LOOP:
	movzx	eax,AGROUP:[esi].DYNHDR_LEN ; Get byte length of this entry
	add	esi,eax 	; Skip to next entry

	jmp	DPMIFN_RESTDYN_NEXT ; Go around again

DPMIFN_RESTDYN_DONE:

; Deallocate dynamic save area

	push	DPMIDYN_SIZ	; Pass byte length
	push	edi		; Pass starting linear address
	call	DEALLOCMEM	; Deallocate the memory
	jnc	short @F	; Jump if no error

	SWATMAC ERR		; Call our debugger
@@:
	mov	edx,PCURTSS	; Get offset in DGROUP of current TSS
	mov	DGROUP:[edx].DPTSS_DYN,0 ; Mark as not initialized
DPMIFN_RESTDYN_EXIT:
	popad			; Restore all EGP registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_RESTDYN endp		; End DPMIFN_RESTDYN procedure
	NPPROC	DPMIFN_RESTOLDPM -- Restore Data In Old PM Data Area
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Restore data in old PM data area

The structure of the old PM data area is

SIRBCUR
DPMI_CPIHOOK
DPMI_CPFHOOK
DPMI_CVFHOOK
PMINT_FVECS
PMINT_DVECS
PMFLT_FVECS
PMFLT_DVECS
VMFLT_FVECS
VMFLT_DVECS
LAST_DPMI_DS
LAST_DPMI_ES
LAST_DPMI_FS
LAST_DPMI_GS
I31_FLAG
DPMITYPE
DBGCTL
DBGSTA
DBGREGS

If any fields are added/deleted from this list, be sure to update
DPMIFN_SAVEOLDPM as well as the size calculations in QMAX_ARG.ASM in
the CHECK_ARGS_VALIDxx section.

|

RESTOLDPM_STR struc

	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
RESTOLDPM_TSS dd ?		; Offset in DGROUP of TSS to use
RESTOLDPM_FLG dd ?		; Flags:
				;   Bit 0:  1 = we're terminating
RESTOLDPM_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ecx,esi,edi,es,fs> ; Save registers

	mov	es,SEL_4GB	; Get AGROUP data selector at PL0
	assume	es:AGROUP	; Tell the assembler about it

	mov	fs,SEL_DATA	; Get DGROUP data selector
	assume	fs:DGROUP	; Tell the assembler about it

	mov	eax,[ebp].RESTOLDPM_TSS ; Get offset in DGROUP of TSS to use
	mov	esi,DGROUP:[eax].DPTSS_OLDPM ; Get linear address of old PM data area


; Restore SIRBCUR

	test	CPUFET_FLAG,mask $CPUFET_VME ; Is VME supported?
	jz	short @F	; Jump if not

	mov	eax,DGROUP:[eax].DPTSS_LaSIRBCUR ; Get previous address
	mov	LaSIRBCUR,eax	; Save as new linear address
	add	esi,256/8	; Skip over SIRBCUR table

	MOVSPR	eax,cr4 	; Get CPU extensions register

	test	eax,mask $VME	; Izit enabled?
	jz	short @F	; Jump if not

	call	SIRBCUR2B	; Copy SIRBCUR values to SIRB
@@:


; Restore DPMI_CPIHOOK

	lea	edi,DPMI_CPIHOOK ; Get offset in DGROUP of current PM
				; interrupt hook bitmap
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,256/(8*4)	; Get size of table in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy from old PM data area


; Restore DPMI_CPFHOOK

	lea	edi,DPMI_CPFHOOK ; Get offset in DGROUP of current PM
				; fault hook bitmap
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,32/(8*4)	; Get size of table in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy from old PM data area


; Restore DPMI_CVFHOOK

	lea	edi,DPMI_CVFHOOK ; Get offset in DGROUP of current VM
				; fault hook bitmap
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,32/(8*4)	; Get size of table in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy from old PM data area


; If we're terminating, we have a new primary client and
; we need to copy DPMI_CxxHOOK to DPMI_PxxHOOK.

	test	[ebp].RESTOLDPM_FLG,@BIT0 ; Are we terminating?
	jz	short DPMIFN_RESTOLDPM1 ; Jump if not

	push	esi		; Save for a moment

	lea	esi,DPMI_CPIHOOK ; Get offset in DGROUP of current PM
				; interrupt hook bitmap
	add	esi,DGRBASE	; Plus linear address of DGROUP

	lea	edi,DPMI_PPIHOOK ; Get offset in DGROUP of primary PM
				; interrupt hook bitmap
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,256/(8*4)	; Get size of table in dwords
S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy it

	lea	esi,DPMI_CVFHOOK ; Get offset in DGROUP of current VM
				; fault hook bitmap
	add	esi,DGRBASE	; Plus linear address of DGROUP

	lea	edi,DPMI_PVFHOOK ; Get offset in DGROUP of primary VM
				; fault hook bitmap
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,32/(8*4)	; Get size of table in dwords
S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy it

	pop	esi		; Restore
DPMIFN_RESTOLDPM1:

; Restore PMINT_FVECS

	lea	edi,DGROUP:PMINT_FVECS ; Get offset in DGROUP of PMINT_FVECS
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,(256/4)*(type PMINT_FVECS) ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy from old PM data area


; Restore PMINT_DVECS

	lea	edi,DGROUP:PMINT_DVECS ; Get offset in DGROUP of PMINT_DVECS
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,(256/4)*(type PMINT_DVECS) ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy from old PM data area


; Restore PMFLT_FVECS

	lea	edi,DGROUP:PMFLT_FVECS ; Get offset in DGROUP of PMFLT_FVECS
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,(32/4)*(type PMFLT_FVECS) ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy from old PM data area


; Restore PMFLT_DVECS

	lea	edi,DGROUP:PMFLT_DVECS ; Get offset in DGROUP of PMFLT_DVECS
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,(32/4)*(type PMFLT_DVECS) ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy from old PM data area


; Restore VMFLT_FVECS

	lea	edi,DGROUP:VMFLT_FVECS ; Get offset in DGROUP of VMFLT_FVECS
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,(32/4)*(type VMFLT_FVECS) ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy from old PM data area


; Restore VMFLT_DVECS

	lea	edi,DGROUP:VMFLT_DVECS ; Get offset in DGROUP of VMFLT_DVECS
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,(32/4)*(type VMFLT_DVECS) ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy from old PM data area


; Restore LAST_DPMI_xS

	lods	AGROUP:[esi].ELO ; Get LAST_DPMI_DS value
	mov	LAST_DPMI_DS,ax ; Restore
	lods	AGROUP:[esi].ELO ; Get LAST_DPMI_ES value
	mov	LAST_DPMI_ES,ax ; Restore
	lods	AGROUP:[esi].ELO ; Get LAST_DPMI_FS value
	mov	LAST_DPMI_FS,ax ; Restore
	lods	AGROUP:[esi].ELO ; Get LAST_DPMI_GS value
	mov	LAST_DPMI_GS,ax ; Restore


; Restore I31_FLAG

	lods	AGROUP:[esi].ELO ; Get I31_FLAG value
	mov	I31_FLAG,ax	; Restore


; Restore DPMITYPE and DPMITYPEIG

	lods	AGROUP:[esi].LO ; Get DPMITYPE value
	mov	DPMITYPE,al	; Restore
	mov	DPMITYPEIG,al	; ...


; Restore DBGCTL

	lods	AGROUP:[esi].LO ; Get DBGCTL value
	mov	DBGCTL,al	; Restore


; Restore DBGSTA

	lods	AGROUP:[esi].LO ; Get DBGSTA value
	mov	DBGSTA,al	; Restore


; Restore DBGREGS

	lea	edi,DGROUP:DBGREGS ; Get offset in DGROUP of DBGREGS
	add	edi,DGRBASE	; Plus linear address of DGROUP
	mov	ecx,4*(type DBGREGS)/4 ; Get size in dwords

S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy from old PM data area


; Restore DBGDR7

	lods	AGROUP:[esi].EDD ; Get DBGDR7 value
	mov	DBGDR7,eax	; Restore


; Restore DR0-3 and DR7

	mov	ecx,dr7 	; Get debug control register

	bt	DBGCTL,0	; Test bit for DR0
	jnc	short @F	; Jump if not active

	mov	eax,DBGREGS[0*(type DBGREGS)] ; Get linear address
	mov	dr0,eax 	; Restore
	and	ecx,not ((mask $LEN0) or (mask $RW0) or (mask $G0) or (mask $L0))
@@:
	bt	DBGCTL,1	; Test bit for DR1
	jnc	short @F	; Jump if not active

	mov	eax,DBGREGS[1*(type DBGREGS)] ; Get linear address
	mov	dr1,eax 	; Restore
	and	ecx,not ((mask $LEN1) or (mask $RW1) or (mask $G1) or (mask $L1))
@@:
	bt	DBGCTL,2	; Test bit for DR2
	jnc	short @F	; Jump if not active

	mov	eax,DBGREGS[2*(type DBGREGS)] ; Get linear address
	mov	dr2,eax 	; Restore
	and	ecx,not ((mask $LEN2) or (mask $RW2) or (mask $G2) or (mask $L2))
@@:
	bt	DBGCTL,3	; Test bit for DR3
	jnc	short @F	; Jump if not active

	mov	eax,DBGREGS[3*(type DBGREGS)] ; Get linear address
	mov	dr3,eax 	; Restore
	and	ecx,not ((mask $LEN3) or (mask $RW3) or (mask $G3) or (mask $L3))
@@:
	or	ecx,DBGDR7	; Get active DR7 bits
	mov	dr7,ecx 	; Tell the CPU about it

	REGREST <fs,es,edi,esi,ecx,eax> ; Restore
	assume	es:DGROUP,fs:nothing ; Tell the assembler about it

	pop	ebp		; Restore

	ret	4+4		; Return to caller, popping arguments

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_RESTOLDPM endp		; End DPMIFN_RESTOLDPM procedure
	NPPROC	DPMIFN_FAULT -- Display Error Message If Fault
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Display error message if fault

On entry:

EDX	=	previous PCURTSS
SS:EBP	==>	INTXX_STR

|

	pushad			; Save all EGP registers
	REGSAVE <es>		; Save segment register

	test	I31_FLAG,@I31_FAULT ; Did we terminate because of a fault?
	jz	near ptr DPMIFN_FAULT_EXIT ; Jump if not

; Format CS:EIP into the message

	mov	eax,[ebp].INTXX_EIP ; Get EIP from stack
	lea	edi,MSG_DPMIADDROFF ; ES:EDI ==> place to put result
	call	DD2HEX		; Convert EAX to hex at ES:EDI

	mov	ax,[ebp].INTXX_CS ; Get CS from stack
	lea	edi,MSG_DPMIADDRSEL ; ES:EDI ==> place to put result
	call	DW2HEX		; Convert AX to hex at ES:EDI

	mov	al,':'          ; Assume VM

	test	[ebp].INTXX_EFL.EHI.LO,mask $VM ; In VM86 mode?
	jnz	short @F	; Jump if so

	mov	al,'|'          ; It's PM
@@:
	mov	MSG_DPMIADDRSEP,al ; Save as separator in message

; Format the flags

	mov	eax,[ebp].INTXX_EFL ; Get the flags
	lea	edi,MSG_DPMIADDREFL ; ES:EDI ==> place to put result
	call	DD2HEX		; Convert EAX to hex at ES:EDI

; Format the return stack

	lea	edi,MSG_DPMISTK1 ; ES:EDI ==> place to put result
	lea	esi,[ebp].INTXX_SS ; SS:ESI ==> stack values to format

; Display up to nine stack entries, depending upon the stack limit

	mov	ecx,ss		; Get the stack selector
	lsl	ecx,ecx 	; Get the segment limit
	inc	ecx		; Convert from limit to length
	sub	ecx,esi 	; Less starting point
	shr	ecx,2-0 	; Convert from bytes to dwords

	cmp	ecx,9		; Izit above the maximum?
	jbe	short @F	; Jump if not

	mov	ecx,9		; # stack entries to display
@@:
	lods	ss:[esi].EDD	; Get next stack dword
	call	DD2HEX		; Convert EAX to hex at ES:EDI

	inc	edi		; Skip over blank separator

	loop	@B		; Jump if more entries to format

; If we've wound back to the first TSS (PVMTSS), we might not have
; a valid stack (SS:SP) to use to reflect the INT 10hs to VM.  In
; this case, use the stack from the HPDA from old TSS.

	mov	eax,PVMTSS	; Get offset in DGROUP of the 1st TSS

	cmp	eax,PCURTSS	; Izit the current TSS?
	jne	short DPMIFN_FAULT1 ; Jump if not

	push	LCL_FLAG		     ; Save old flags
	push	DGROUP:[eax].DPTSS_VMSTKSEG ; ...	SS
	push	DGROUP:[eax].DPTSS_VMSTKOFF ; ...	SP

	test	LCL_FLAG,@LCL_HPDA ; Do we have a local HPDA?
	jnz	short DPMIFN_FAULT1 ; Jump if so

	or	LCL_FLAG,@LCL_HPDA ; Now we do

	mov	cx,DGROUP:[edx].DPTSS_VMSTKSEG ; Get new SS
	mov	DGROUP:[eax].DPTSS_VMSTKSEG,cx ; Save in VM TSS

	mov	cx,DGROUP:[edx].DPTSS_VMSTKOFF ; Get new SP
	mov	DGROUP:[eax].DPTSS_VMSTKOFF,cx ; Save in VM TSS

	mov	cx,DGROUP:[edx].DPTSS_HPDASEG	; Get new HPDA segment
	mov	DGROUP:[eax].DPTSS_HPDASEG,cx	; Save in VM TSS

	movzx	esi,cx		; Copy HPDA segment
	shl	esi,4-0 	; Convert from paras to bytes
	mov	ebx,PCURTSS	; Get new current TSS
	xchg	AGROUP:[esi].HPDA_PCURTSS,ebx ; Save in HPDA
DPMIFN_FAULT1:

; Ensure we're in a text mode

	VIDCALL @GETINF 	; Get video state into mode AL, cols AH, page BH

	cmp	al,03h		; Izit in text mode already?
	je	short @F	; Jump if so

	VIDCALL @SETMOD,03h	; Set video mode to 03h
@@:

; Display DPMI fault title

@DPMIMSG_ROW equ 18h		; Starting row for DPMI message display
@DPMIMSG_COL equ 00h		; ...	   col ...

	mov	dh,@DPMIMSG_ROW ; Start at this row
	mov	dl,@DPMIMSG_COL ; Start at this col
	push	es		; Pass message selector
	push	offset DGROUP:MSG_TITLE ; Pass message offset
	call	DISP_STR	; Display it

; Display specific fault error message

	mov	dx,-1		; Use current position
	push	es		; Pass message selector
	push	DPMIMSG 	; Pass message offset
	call	DISP_STR	; Display it

; Display address

;;;;;;; mov	dx,-1		; Use current position
	push	es		; Pass message selector
	push	offset DGROUP:MSG_DPMIADDR ; Pass message offset
	call	DISP_STR	; Display it

; Display return stack values

;;;;;;; mov	dx,-1		; Use current position
	push	es		; Pass message selector
	push	offset DGROUP:MSG_DPMISTK ; Pass message offset
	call	DISP_STR	; Display it

; Display next part of message

;;;;;;; mov	dx,-1		; Use current position
	push	es		; Pass message selector
	push	offset DGROUP:MSG_TITL2 ; Pass message offset
	call	DISP_STR	; Display it
	push	es		; Pass message selector
	push	offset DGROUP:MSG_TITL3 ; Pass message offset
	call	DISP_STR	; Display it
	push	es		; Pass message selector
	push	offset DGROUP:MSG_TITL4 ; Pass message offset
	call	DISP_STR	; Display it

; Convert the application name to uppercase

	lea	esi,DGROUP:MSG_APPLNAME ; ES:ESI ==> message to display
	lods	MSG_APPLNAME[esi].LENTXT_LEN ; Get and skip over string length
	mov	ecx,eax 	; Copy to loop counter
	jecxz	DPMIFN_FAULT_MSG_XAPPL ; Jump if it's empty????
DPMIFN_FAULT_MSG_NEXT:
	lods	MSG_APPLNAME[esi].LO ; Get next byte

	cmp	al,'a'          ; Check against lower limit
	jb	short @F	; Jump if too small

	cmp	al,'z'          ; Check against upper limit
	ja	short @F	; Jump if too large

	add	al,'A'-'a'      ; Convert to uppercase
	mov	DGROUP:[esi-1],al ; Save back into application name
@@:
	loop	DPMIFN_FAULT_MSG_NEXT ; Jump if more characters to convert

; Display name of last application

;;;;;;; mov	dx,-1		; Use current position
	push	es		; Pass message selector
	push	offset DGROUP:MSG_APPLNAME ; Pass message offset
	call	DISP_STR	; Display it

	jmp	short DPMIFN_FAULT_MSG_XAPPL1 ; Join common code


DPMIFN_FAULT_MSG_XAPPL:

; Application name unknown:  tell 'em so

;;;;;;; mov	dx,-1		; Use current position
	push	es		; Pass message selector
	push	offset DGROUP:MSG_APPLUNK ; Pass message offset
	call	DISP_STR	; Display it
DPMIFN_FAULT_MSG_XAPPL1:

; Print and format the registers for debugging

;	push	[ebp].INTXX_EIP ; Pass register value
;	push	[ebp].INTXX_ESP ; ...
;	push	[ebp].INTXX_EBP ; ...
;	push	[ebp].INTXX_EDI ; ...
;	push	[ebp].INTXX_ESI ; ...
;	push	[ebp].INTXX_EDX ; ...
;	push	[ebp].INTXX_ECX ; ...
;	push	[ebp].INTXX_EBX ; ...
;	push	[ebp].INTXX_EAX ; ...
;	push	es		; ...  selector of format string
;	push	offset DGROUP:MSG_REGS ; ... offset ...
;	call	PRINTF32	; Printf it, return with EAX = # chars printed
;	add	sp,4*11 	; Strip arguments from stack

; Display next part of message

;;;;;;; mov	dx,-1		; Use current position
	push	es		; Pass message selector
	push	offset DGROUP:MSG_TAIL ; Pass message offset
	call	DISP_STR	; Display it

; Display key wait message

;;;;;;; mov	dx,-1		; Use current position
	push	es		; Pass message selector
	push	offset DGROUP:MSG_DPMIPRESS ; Pass message offset
	call	DISP_STR	; Display it

; Purge the keyboard buffer and wait for a key press -- discard the key

	call	KEYWAIT 	; Wait for an acknowledgement

	call	DPMIFN_NEWLINE	; Start on a new line

; If we've wound back to the first TSS (PVMTSS), restore the original
; VM TSS values

	mov	eax,PVMTSS	; Get offset in DGROUP of the 1st TSS

	cmp	eax,PCURTSS	; Izit the current TSS?
	jne	short DPMIFN_FAULT2 ; Jump if not

	movzx	esi,DGROUP:[eax].DPTSS_HPDASEG ; Save current HPDASEG
	pop	DGROUP:[eax].DPTSS_VMSTKOFF ; Restore SP
	pop	DGROUP:[eax].DPTSS_VMSTKSEG ; ...     SS
	pop	LCL_FLAG		     ; ...     flags

	test	LCL_FLAG,@LCL_HPDA ; Do we have a local HPDA?
	jnz	short DPMIFN_FAULT2 ; Jump if so

	shl	esi,4-0 	; Convert from paras to bytes
	mov	AGROUP:[esi].HPDA_PCURTSS,ebx ; Restore PCURTSS
DPMIFN_FAULT2:
DPMIFN_FAULT_EXIT:
	REGREST <es>		; Restore
	assume	es:DGROUP	; Tell the assembler about it
	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_FAULT endp		; End DPMIFN_FAULT procedure
	NPPROC	DPMIFN_NEWLINE -- Start On A New Line
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Start on a new line

|

	REGSAVE <eax>		; Save register

	mov	al,CR		; Start a new line
	VIDCALL @SETTTY 	; Write to screen

	mov	al,LF		; Start a new line
	VIDCALL @SETTTY 	; Write to screen

	REGREST <eax>		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_NEWLINE endp		; End DPMIFN_NEWLINE procedure
	NPPROC	DPMIFN_LMSW -- Load New MSW For DPMI Client
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Load the MSW for a DPMI client.

|

DPMIFN_LMSW_STR struc

	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
DPMIFN_LMSW_TSS dd ?		; Offset in DGROUP of the TSS to use

DPMIFN_LMSW_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ebx,edx,ds> ; Save registers

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	edx,[ebp].DPMIFN_LMSW_TSS ; Get offset in DGROUP of the TSS

COMMENT|

Note we don't change the global value of the MP bit as
the DPMI client's value tells us whether or not to save
the NDP state when we switch tasks, not the presence of
an NDP.

Because we're not a multitasking OS, we can ignore this
information.

|

	smsw	ax		; Get current MSW
	and	ax,not (mask $EM) ; Clear EM bit
	mov	bx,DGROUP:[edx].DPTSS_MSW ; Get this client's MSW
	and	bx,mask $EM	; Isolate EM bit
	or	ax,bx		; Include client's EM bit
	lmsw	ax		; Set into effect

; Establish addressibility to IDT

	sub	esp,size DTR_STR ; Make room on stack
	SIDTD	[esp].EDF	; Save IDTR on stack
	mov	ebx,[esp].DTR_BASE ; AGROUP:EBX ==> IDT
	add	esp,size DTR_STR ; Strip

; Put into effect the appropriate IDT entry for INT 07h

	push	DGROUP:[edx].DPTSS_IDT07.EDQLO ; Get low-order dword
	push	DGROUP:[edx].DPTSS_IDT07.EDQHI ; Get high-order dword

	mov	ds,SEL_4GB	; Get AGROUP data selector at PL0
	assume	ds:AGROUP	; Tell the assembler about it

	pop	AGROUP:[ebx+07h*(type IDT_STR)].EDQHI ; Save into the IDT
	pop	AGROUP:[ebx+07h*(type IDT_STR)].EDQLO ; ...

	REGREST <ds,edx,ebx,eax> ; Restore
	assume	ds:nothing	; Tell the assembler about it

	pop	ebp		; Restore

	ret	4		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_LMSW endp		; End DPMIFN_LMSW procedure
	NPPROC	DPMIFN_GETPSP -- Get PSP
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Get PSP into BX using the HPDA stack from stack argument

On exit:

BX	=	 segment of the current PSP

|

PSPSTK_STR struc

	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
PSPSTK_PTSS dd	?		; Offset in DGROUP of TSS to use

PSPSTK_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ecx,edx,esi,edi,es,gs> ; Save registers

	SETDATA es		; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	mov	gs,SEL_4GB	; Get AGROUP data selector at PL0
	assume	gs:AGROUP	; Tell the assembler about it

	call	SAVE_VMCREGS	; Save current values of VMCREGS on stack

	mov	edi,[ebp].PSPSTK_PTSS ; Get offset in DGROUP of TSS

	mov	VMCREGS.VMC_EAX.ELO.HI,@GETPS0 ; Save DOS function

	mov	ax,DGROUP:[edi].DPTSS_VMSTKOFF ; Get current stack offset
	mov	VMCREGS.VMC_SP,ax ; Use as new SP

	sub	ax,@HPDAFRM_SIZ ; Make room for a level
;;;;;;; jb	short DPMIFN_GETPSP_VMFULL ; Jump if there's no more room
;;;;;;;
;;;;;;; cmp	ax,DGROUP:[edi].DPTSS_VMSTKBOT ; Izit below the bottom?
;;;;;;; jb	short DPMIFN_GETPSP_VMFULL ; Jump if so
;;;;;;;
	push	DGROUP:[edi].DPTSS_VMSTKOFF ; Save the old value

	mov	DGROUP:[edi].DPTSS_VMSTKOFF,ax ; Make room for a level

	mov	ax,DGROUP:[edi].DPTSS_VMSTKSEG ; Get current stack segment
	mov	VMCREGS.VMC_SS,ax ; Use as new SS

	mov	VMCREGS.VMC_FL,0 ; Set to known value

	mov	edx,PCURTSS	; Get offset in DGROUP of current TSS

	mov	ax,DGROUP:[edi].DPTSS_HPDASEG ; Get current value
	xchg	ax,DGROUP:[edx].DPTSS_HPDASEG ; Swap to known value
	push	ax		; Save over SIMVMI call

	mov	esi,DGROUP:[edi].DPTSS_LaHPDA ; Get the linear address of the HPDA
	mov	eax,edx 	; Get current value
	xchg	eax,AGROUP:[esi].HPDA_PCURTSS ; Swap to known value
	push	eax		; Save over SIMVMI call

	mov	bx,21h		; BL = Interrupt #, BH = flags (none)
	xor	cx,cx		; # words to copy
	lea	edi,VMCREGS	; ES:EDI ==> VMC register structure
	DPMICALL0 @DPMI_SIMVMI	; Request DPMI service
	jnc	short @F	; Jump if all went OK

	SWATMAC ERR		; Call our debugger
@@:
	pop	AGROUP:[esi].HPDA_PCURTSS ; Restore
	pop	DGROUP:[edx].DPTSS_HPDASEG ; ...

	mov	edi,[ebp].PSPSTK_PTSS ; Get offset in DGROUP of TSS

	pop	DGROUP:[edi].DPTSS_VMSTKOFF ; Restore the old value

	mov	bx,VMCREGS.VMC_EBX.ELO ; Get the segment #

	call	REST_VMCREGS	; Restore old values of VMCREGS from stack

	REGREST <gs,es,edi,esi,edx,ecx,eax> ; Restore
	assume	es:DGROUP,gs:nothing ; Tell the assembler about it

	pop	ebp		; Restore

	ret	4		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_GETPSP endp		; End DPMIFN_GETPSP procedure
	NPPROC	DPMIFN_SETPSP -- Set PSP
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Set PSP to BX using the HPDA stack stack argument

On entry:

BX	=	segment of PSP to set

|

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ecx,edi,es> ; Save registers

	SETDATA es		; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	call	SAVE_VMCREGS	; Save current values of VMCREGS on stack

	mov	edi,[ebp].PSPSTK_PTSS ; Get offset in DGROUP of TSS

	mov	VMCREGS.VMC_EAX.ELO.HI,@SETPSP ; Save DOS function

	mov	ax,DGROUP:[edi].DPTSS_VMSTKOFF ; Get current stack offset
	mov	VMCREGS.VMC_SP,ax ; Use as new SP

	sub	ax,@HPDAFRM_SIZ ; Make room for a level
;;;;;;; jb	short DPMIFN_SETPSP_VMFULL ; Jump if there's no more room
;;;;;;;
;;;;;;; cmp	ax,DGROUP:[edi].DPTSS_VMSTKBOT ; Izit below the bottom?
;;;;;;; jb	short DPMIFN_SETPSP_VMFULL ; Jump if so
;;;;;;;
	push	DGROUP:[edi].DPTSS_VMSTKOFF ; Save the old value

	mov	DGROUP:[edi].DPTSS_VMSTKOFF,ax ; Make room for a level

	mov	ax,DGROUP:[edi].DPTSS_VMSTKSEG ; Get current stack segment
	mov	VMCREGS.VMC_SS,ax ; Use as new SS

	mov	VMCREGS.VMC_FL,0 ; Set to known value
	mov	VMCREGS.VMC_EBX.ELO,bx ; Save incoming PSP

	mov	bx,21h		; BL = Interrupt #, BH = flags (none)
	xor	cx,cx		; # words to copy
	lea	edi,VMCREGS	; ES:EDI ==> VMC register structure
	DPMICALL0 @DPMI_SIMVMI	; Request DPMI service
	jnc	short @F	; Jump if all went OK

	SWATMAC ERR		; Call our debugger
@@:
	mov	edi,[ebp].PSPSTK_PTSS ; Get offset in DGROUP of TSS

	pop	DGROUP:[edi].DPTSS_VMSTKOFF ; Restore the old value

	call	REST_VMCREGS	; Restore old values of VMCREGS from stack

	REGREST <es,edi,ecx,eax> ; Restore
	assume	es:DGROUP	; Tell the assembler about it

	pop	ebp		; Restore

	ret	4		; Return to caller, popping argument

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_SETPSP endp		; End DPMIFN_SETPSP procedure
	NPPROC	DPMIFN_TERMINATE -- Handle DPMI Client Termination
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Handle DPMI client termination

If there are any activities which need to be done at
termination time when PCURTSS and TR match, now's the time

On exit:

IF	=	0
DS, FS, GS clobbered.
ES	=	DGROUP

|

	REGSAVE <eax,edx>	; Save registers

	cli			; Disable interrupts because we switch back
				; to the previous address space and can't
				; afford HW interrupts to be reflected to VM

	xor	dx,dx		; A convenient zero
	mov	fs,dx		; Zero in case it's in the LDT
	assume	fs:nothing	; Tell the assembler about it

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	es,SEL_DATA	; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	mov	gs,SEL_4GB	; Get AGROUP data selector at PL0
	assume	gs:AGROUP	; Tell the assembler about it

; Notify Resident Service Providers that client is terminating

	mov	ah,1		; Flag termination
	mov	al,DPMITYPEIG	; Pass client bitness
	call	DPMIFN_CALL_RSPS ; Notify RSPs

	mov	edx,PCURTSS	; Get offset in DGROUP of the current TSS
	and	DGROUP:[edx].DPTSS_FLAG,not (mask $DPTSS_INIT) ; Mark as not initialized

; If the terminating DPMI client is Windows 3.00,
; restore PL1 state to @DPMI_CPL/@DPMI_DPL.

	test	I31_FLAG,@I31_KRNL ; Izit the KRNL?
	jz	short @F	; Jump if not

	test	I31_FLAG,@I31_WIN3 ; Izit Windows 3.00?
	jz	short @F	; Jump if not

	call	DPMIFN_RESTWIN	; Restore the state
@@:

; Free memory allocated to this client

	call	DPMIFN_FREEMEM	; Free 'em

; Restore data in the dynamic save area

	call	DPMIFN_RESTDYN	; Restore it

; Restore the incoming PM data area

; We're about to restore I31_FLAG (among other things).
; Because we need the current value for a bit longer, we
; save it, and exchange it with the incoming value until
; we finish terminating.

	mov	ax,I31_FLAG	; Get current value

	push	@BIT0		; Tell 'em we're terminating
	push	DGROUP:[edx].DPTSS_PLNKTSS ; Get offset in DGROUP of prev TSS
	call	DPMIFN_RESTOLDPM ; Restore it

	xchg	ax,I31_FLAG	; Swap back the original value

; De-allocate the outgoing PM data area

	push	DPMIOLDPM_SIZ	; Pass byte length
	push	DGROUP:[edx].DPTSS_OLDPM ; Pass linear address of old PM data area
	call	DEALLOCMEM	; Deallocate the memory
	jnc	short @F	; Jump if no error

	SWATMAC ERR		; Call our debugger
@@:

; If this is the first DPMI client, de-allocate memory
; for the current PMxxT_xVECS and other variables
; Note that this routine must be called *BEFORE* PCURTSS has been
; restored to the incoming TSS.

	call	DPMIFN_FREE_VMOLDPM ; Free it

; Deallocate DPMI LPM stack

	cmp	DGROUP:[edx].DPTSS_LPMBASE,0 ; Izit initialized as yet?
	je	short @F	; Jump if not

	push	LPMSTK_SIZ	; Pass byte length
	push	DGROUP:[edx].DPTSS_LPMBASE ; Pass starting linear address
	call	DEALLOCMEM	; Deallocate the memory
	jnc	short @F	; Jump if no error

	SWATMAC ERR		; Call our debugger
@@:
	mov	DGROUP:[edx].DPTSS_LPMBASE,0 ; Mark as not initialized

	mov	es,SEL_DATA	; Get DGROUP data selector
	assume	es:DGROUP	; Tell the assembler about it

	test	VMM_FLAG,@VMM_SYSINIT ; Is VMM active?
	jz	short @F	; Jump if not

	call	VMM_TERMINATE_CLIENT ; Terminate the current client (PCURTSS)

	jmp	short DPMIFN_TERMINATE1 ; Join common code

@@:

; Deallocate old LDT and restore new one

	call	DPMIFN_FREELDT	; Free it
DPMIFN_TERMINATE1:

; If there was a Swapped Mouse Interrupt Subroutine,
; restore the original one now
; Note we must do this in the current TSS so that PCURTSS and
; TR match.

	call	DPMIFN_RESTMEI	; Restore it

	mov	I31_FLAG,ax	; Save it for real

	REGREST <edx,eax>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMIFN_TERMINATE endp		; End DPMIFN_TERMINATE procedure
	NPPROC	SIRBCUR2B -- Copy SIRBCUR Values To SIRB
	assume	ds:DGROUP,es:AGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Copy SIRBCUR values to SIRB

|

	REGSAVE <ecx,esi,edi>	; Save registers

	mov	ecx,(256/8)/4	; Get # dwords in SIRB/SIRBCUR tables
	mov	esi,LaSIRBCUR	; Get linear address of current table

	mov	edi,LaIOBIT	; Get offset in AGROUP of I/O bit map
	sub	edi,256/8	; Back off to start of the SIR bitmap
S32 rep movs	<AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Copy in new table

	REGREST <edi,esi,ecx>	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SIRBCUR2B endp			; End SIRBCUR2B procedure
	NPPROC	DISP_STR -- Display A String Through INT 10h
	assume	ds:DGROUP,es:DGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Display a string through INT 10h.

On entry:

(DH,DL)  =	 (row,col) of start of message
		 if DX == -1, use current position
ES:ESI	==>	message length, message

|

DS_STR	struc

	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
DS_FVEC df	?		; Sel|Off of string to display in LENTXT2 form
	dw	?		; Filler

DS_STR	ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ebx,ecx,esi,ds> ; Save registers

	lds	esi,[ebp].DS_FVEC ; DS:ESI ==> LENTXT2 string
	assume	ds:nothing	; Tell the assembler about it

	lods	ds:[esi].LENTXT_LEN ; Get and skip over string length
	mov	ecx,eax 	; Copy to count register

; BH = Page #0, BL = Intense white on black

	mov	bx,(0 shl 8) or (@ATChigh or @ATCFwhite)

	cmp	dx,-1		; Use current position?
	je	short @F	; Jump if so

	VIDCALL @SETPOS 	; Set cursor position to (DH,DL) for page BH
@@:
	jecxz	DISP_STR_EXIT	; Jump if nothing to display
DISP_STR_NEXT:
	lods	ds:[esi].LO	; Get the next character

	VIDCALL @SETTTY 	; Write to screen

	loop	DISP_STR_NEXT	; Jump if more characters to write
DISP_STR_EXIT:
	REGREST <ds,esi,ecx,ebx,eax> ; Restore
	assume	ds:nothing	; Tell the assembler about it

	pop	ebp		; Restore

	ret	4+4		; Return to caller, popping arguments

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DISP_STR endp			; End DISP_STR procedure

PROG	ends			; End PROG segment


;;; JCODE    segment use16 dword public 'jcode' ; Start JCODE segment
;;;	     assume  cs:PGROUP
;;;
;;;	     extrn   DPMIFN_CALL_RSPS:near
;;;
;;;	     NPPROC  CPY_DL2GROUP -- Copy Int 23 code to HPDA
;;;	     assume  ds:DGROUP,es:DGROUP,fs:nothing,gs:AGROUP
;;; COMMENT|
;;;
;;; Copy Int 23 code to HPDA and set up return stack.
;;;
;;; If Ctrl-Break was pressed during swapfile initialization (BREAK=ON),
;;; we need to ignore it until we're done initializing the swapfile.
;;; Then we abort client initialization, and call this procedure to
;;; set up VM code to call the current Int 23 handler.	If we're to
;;; ignore the Ctrl-Break, we return to the code which called the
;;; Enter Protected Mode address returned by Int 2f fn 1687.  If we're
;;; to abort, we need to set the Int 21 fn 4d return code in QMAX_OVR.
;;;
;;; On entry:
;;; CLD 	    In effect
;;; SS:EBP ==>	    INTXX_STR:
;;;		    INTXX_ES = segment of HPDA
;;;		    INTXX_EIP.ELO = Return IP to modify
;;;		    INTXX_CS = Return CS to modify
;;;
;;; On exit:
;;; SS:EBP.INTXX_EIP ==> GENINT23
;;; SS:EBP.INTXX_CS = HPDA segment
;;; DL2GROUP code and data initialized and copied to HPDA segment
;;;
;;; |
;;;
;;;	     REGSAVE <eax,ecx,esi,edi,es,fs> ; Save
;;;
;;;	     mov     fs,SEL_DATA    ; Get DROUP data selector
;;;	     assume  fs:DGROUP	    ; Tell the assembler
;;;
;;;	     mov     ax,[ebp].INTXX_ES ; Get HPDA segment
;;;	     movzx   edi,ax	    ; Save destination segment
;;;	     xchg    ax,[ebp].INTXX_CS ; Set new return segment and get previous
;;;	     shl     eax,16	    ; Move segment to high word of vector
;;;	     mov     ax,offset DGROUP:GENINT23 ; Offset of entry point in HPDA
;;;	     xchg    ax,[ebp].INTXX_EIP.ELO ; Set return offset and get previous
;;;
;;;	     sub     esi,esi	    ; Clear high word
;;;	     mov     si,seg DL2GROUP ; Get DL2GROUP segment
;;;	     sub     si,seg JGROUP  ; ESI = offset in paras from JGROUP base
;;;	     shl     esi,4-0	    ; Convert paras to bytes
;;;
;;;	     assume  fs:DL2GROUP    ; Tell a little white lie
;;;	     mov     DL2_PMERET[esi],eax ; Return address if ignoring Ctrl-Break
;;;	     mov     ax,DGROUP:INT31A_HIMEM_CS.ELO ; Get high DOS PGROUP segment
;;;	     mov     DL2_PGRSEG[esi],ax ; Save for later
;;;	     assume  fs:JGROUP	    ; Retract nose
;;;
;;;	     push    gs 	    ; Get AGROUP selector
;;;	     pop     es 	    ; Address for REP MOVS
;;;	     assume  es:AGROUP	    ; Tell the assembler
;;;
;;;	     shl     edi,4-0	    ; Convert destination segment to address
;;;	     lea     ecx,DL2GROUP:DL2GROUP_END[4-1] ; Address end of DL2GROUP
;;;	     shr     ecx,2-0	    ; Convert bytes to dwords
;;;
;;; S32 rep  movs    <AGROUP:[edi].EDD,JGROUP:[esi].EDD> ; Copy DL2GROUP downstairs
;;;
;;;	     REGREST <fs,es,edi,esi,ecx,eax> ; Restore
;;;	     assume  es:nothing,fs:nothing ; Tell the assembler
;;;
;;;	     ret		    ; Return to caller
;;;
;;; CPY_DL2GROUP endp		    ; End CPY_DL2GROUP procedure
;;;
;;; JCODE    ends		    ; End JCODE segment

	MEND			; End DPMI_I31 module
