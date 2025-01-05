;' $Header$
	title	DPMI_1ST -- DPMI First Routine
	page	58,122
	name	DPMI_1ST

COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1988-2004 Sudley Place Software.  All rights reserved.

|
.386p
.xlist
	include MASM.INC
	include ASCII.INC
	include PTR.INC
	include 386.INC
	include MASM5.MAC
	include DOSCALL.INC
	include ALLMEM.INC
	include CPUFLAGS.INC
	include CPUFET2.INC
	include CPUSIG.INC
	include MOVSPR.INC
	include IOPBITS.INC
	include DPMI.INC
	include XMS.INC
	include BITFLAGS.INC
	include VCPI.INC
	include VDS.INC
	include I11.INC
	include MAC.INC
	include 8259.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_LCL.INC
	include DPMI_PRG.INC
	include DPMI_SEG.INC
	include DPMI_SWT.INC
	include DPMI_W9X.INC

	include QMAX_MSC.INC
	include QMAX_TSS.INC
	include QMAX_XMS.INC
	include QMAX_I31.INC		; Must precede QMAXDPMI.INC
	include QMAXDPMI.INC		; Must follow QMAX_I31.INC

	include GXT_HDR.INC
.list

SETIDT	macro	NN

	mov	edx,0&NN&h	; Get the interrupt #
	lea	eax,INT&NN&	; Get the offset
	mov	AGROUP:[ebx+edx*(type IDT_STR)].IDT_SELECT,cs
	mov	AGROUP:[ebx+edx*(type IDT_STR)].IDT_OFFLO,ax
	shr	eax,16		; Shift down the high-order word
	mov	AGROUP:[ebx+edx*(type IDT_STR)].IDT_OFFHI,ax
	mov	AGROUP:[ebx+edx*(type IDT_STR)].IDT_ACCESS,CPL0_INTR3 or (@DPMI_DPL shl $DT_DPL)

	endm			; SETIDT


PDTGRP	group	PDTSEG


PDTSEG	segment use32 dword at 0 ; Start PDTSEG segment
	assume	ds:PDTGRP

	public	OFFPDT
OFFPDT	label	dword

PDTSEG	ends			; End PDTSEG segment


CODEZ	segment use32 para public 'codez' ; Start CODEZ segment
	assume	ds:PGROUP

	public	@DPMI_1ST_CODEZ
@DPMI_1ST_CODEZ label byte	; Mark module start in .MAP file

	public	ZTAIL
ZTAIL	label	byte		; Next available byte in PGROUP (hence length)

CODEZ	ends			; End CODEZ segment


DATA16	segment use16 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	public	@DPMI_1ST_DATA16
@DPMI_1ST_DATA16 label byte	; Mark module start in .MAP file

	extrn	DB2_FLAG:word
	include DPMI_DB2.INC

	extrn	DPM_FLAG:word

	extrn	PXMSBMAP:dword
	extrn	XMSBMAP_LEN:dword

	extrn	HPDASTK_TOP:word
	extrn	HPDASTK_SIZ:word

	public	LaINDOS
LaINDOS dd	?		; Linear address of the InDOS flag

	public	P1ST_MAC
P1ST_MAC dd	?		; Linear address of 1st MAC entry

	public	PHYSIZE
PHYSIZE dd	?		; Top of physical memory (including 1st MB)

	public	CPUFET_FLAG
CPUFET_FLAG dd	?		; CPU feature bits (see CPUFET.INC for masks)

	public	VM2PM_VEC
VM2PM_VEC dd	YGROUP:DPMI_RVM2PM ; Address of DPMI_RVM2PM

	public	HIMEM_La,HIMEM_CS
HIMEM_La dd	?		; Linear address of UMB in high DOS
HIMEM_CS dw	?		; UMB in high DOS

	public	LCL_FLAG
LCL_FLAG dw	0		; Local flags

	public	DOSVER
DOSVER	dw	?		; DOS version # in comparison order

	public	XMSMEM_CNT
XMSMEM_CNT dd	0		; # active entries

	public	XMSMEM
XMSMEM	XMSMEM_STR @XMSMEM_LEN dup (<>) ; XMS memory struc

DATA16	ends			; End DATA16 segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_1ST_DATA
@DPMI_1ST_DATA	label byte	; Mark module start in .MAP file

@LCL_PL0STK_SIZ equ  8*1024	; Size of the local stack

	extrn	VMM_FLAG:word
	include QMAX_VMM.INC

	extrn	TABINT_OFF:dword
	extrn	LaVMTSS:dword
	extrn	PVMTSS:dword
	extrn	PCURTSS:dword
	extrn	VM2PM_TSS:word
;;;;;;; extrn	VM2PM_TSS1:word
	extrn	PPL0STK_MAX:dword
	extrn	PPL0STK_MIN:dword
	extrn	LAST_INTCOM:dword
	extrn	DPMITYPE:byte

	extrn	DPMI_IDEF:word
	extrn	PMINT_DVECS:dword
	extrn	PMINT_FVECS:fword
	extrn	PMFLT_DVECS:dword
	extrn	PMFLT_FVECS:fword
	extrn	VMFLT_DVECS:dword
	extrn	VMFLT_FVECS:fword

	extrn	LaSTKMEM:dword
	extrn	LaSTKPTE:dword
	extrn	STKPTE:dword

	extrn	CPUTYPE:byte
	extrn	PBSCache:dword
	extrn	@BSCSize:abs
	extrn	DPMI_DPL:byte

	public	LaPMIDEF
LaPMIDEF dd	?		; Linear address of PMIDEF

	public	EntryType
EntryType dd	?		; Offset of EIP in RM2PM_ENTRY

	public	OffCR3,PaCR3
OffCR3	dd	?		; Offset in DGROUP of global CR3
PaCR3	dd	?		; Physical address of ...

	public	OffScrPTE,PAScrPTE
OffScrPTE dd	?		; Offset in DGROUP of scratch PTE for LSM_SET_PDE
PAScrPTE dd	?		; Physical address of ...

	public	DGRBASE,PGRBASE
DGRBASE dd	?		; Save area for linear address of DGROUP
PGRBASE dd	?		; ...				  PGROUP

	public	LaSIRBCUR,LaIOBIT,PIOBIT
LaSIRBCUR dd	?		; Linear address of current SIRB table
LaIOBIT dd	?		; ...		    I/O bit permission map (original)
PIOBIT	dd	?		; Offset in DGROUP of I/O bit permission map (current)

;;;	public	PLCL_PL0STKZ,PLCL_PL0CUR
;;; PLCL_PL0STK dd  ?		    ; Offset in DGROUP of local PL0 stack
;;; PLCL_PL0STKZ dd ?		    ; ...		  end of local PL0 stack
;;; PLCL_PL0CUR dd  ?		    ; ...		  current ...

	public	VMTSS
VMTSS	dd	?		; Original VM TSS

	public	RUDPF_NF
RUDPF_NF dd	offset PGROUP:PHYS2MMLIN_NOTFOUND ; Not Found w/o full CR3

	public	ORGSIRB,CURSIRB
ORGSIRB db	(256/8) dup (?) ; Save area for original SIRB table
CURSIRB db	(256/8) dup (?) ; ...		 current ...

	public	OLDINT_FVEC,OLDINT_ARB
OLDINT_FVEC df	256 dup (?)	; Save area for old Sel|Off
OLDINT_ARB  db	256 dup (?)	; Save area for old Sel|Off

	public	OLDINT0D_FVEC,OLDINT0E_FVEC,OLDINT10_FVEC,OLDINT2F_FVEC
OLDINT0D_FVEC equ OLDINT_FVEC[0Dh*(type OLDINT_FVEC)]
OLDINT0E_FVEC equ OLDINT_FVEC[0Eh*(type OLDINT_FVEC)]
OLDINT10_FVEC equ OLDINT_FVEC[10h*(type OLDINT_FVEC)]
OLDINT2F_FVEC equ OLDINT_FVEC[2Fh*(type OLDINT_FVEC)]

	public	INT07DP,MSW_PM
INT07DP dq	?		; IDT entry for INT07
MSW_PM	dw	?		; MSW for PM operation

	public	TempEDF
TempEDF df	?		; Temporary Fword

	public	PPL0STK_SEL
PPL0STK_SEL dw	?		; PL0 stack selector

	public	SEL_DATA,SEL_4GB
SEL_DATA dw	?		; DGROUP data selector at PL3
SEL_4GB dw	?		; AGROUP ...

	public	DTE_DPMIDEF,DTE_DPMI_VSAPI,DTE_SWAPBUF
DTE_DPMIDEF dw	?,0		; Selector for default interrupt handlers (dword)
DTE_DPMI_VSAPI dw ?,0		; ...	       VSAPI call gate		   ...
DTE_SWAPBUF dw	?,0		; ...	       swap file buffer

if @W9X
	public	DTE_DPMI_VWIN32
DTE_DPMI_VWIN32 dw ?,0		; Selector for VWIN32 call gate 	   ...
endif

DATA	ends			; End DATA segment


DATAZ	segment use32 dword public 'data' ; Start DATAZ segment
	assume	ds:DGROUP

	public	@DPMI_1ST_DATAZ
@DPMI_1ST_DATAZ label byte	; Mark module start in .MAP file

	public	DTAIL
DTAIL	label	byte		; Next available byte in DGROUP (hence length)

DATAZ	ends			; End DATAZ segment


CODE16A segment use16 byte public 'prog' ; Start CODE16A segment
	assume	cs:PGROUP,ds:PGROUP

	public	@DPMI_1ST_CODE16A
@DPMI_1ST_CODE16A:		; Mark module start in .MAP file

%	extrn	INT&@PMH_INT&_HIMEM_CS:word
%	extrn	INT&@PMH_INT:near

	irp	XX,<01,02,03,06,07,08,09,0A,0B,0C,0F,70,71,72,73,74,75,76,77>
	extrn	INT&XX&:near
	endm			; IRP


; The following data structure must be first in the file

	public	GXTHDR
GXTHDR	GXTHDR_STR <,			\
		,			\
		0100h,			\
		,			\
		offset PGROUP:GXTHDR,	\
		offset PGROUP:ZTAIL,	\
		offset PGROUP:ZTAIL,	\
		offset DGROUP:DTAIL,	\
		XGROUP:INIT_REAL,	\
		PGROUP:INIT_PROT,	\
		PGROUP:REST_PROT,	\
		YGROUP:REST_REAL,	\
		?,			\
		6 + @TSS_MAX * 2,	\
		,			\
		@GXTHDR_USE32,		\
		,,,,,,>

COMMENT|

The selector count is for

* Code
* Data
* Default interrupt handlers at PL3
* VSAPI call gate
* VWIN32 call gate
* TSS outside DPMI clients
* @TSS_MAX * 2 (TSS & matching LDT)

|

	public	NEWIMR1,NEWIMR2,ERM_FVEC
NEWIMR1 equ	GXTHDR.GXTHDR_IBV0
NEWIMR2 equ	GXTHDR.GXTHDR_IBV1
ERM_FVEC equ	GXTHDR.GXTHDR_PM2RM_FVEC

CODE16A ends			; End CODE16A segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP,ds:PGROUP

	public	@DPMI_1ST_PROG
@DPMI_1ST_PROG: 		; Mark module start in .MAP file

	extrn	GETBASE:near
	extrn	DEALLOCMEM:near
	extrn	DPMIFN_VSAPI:far
if @W9X
	extrn	VWIN32_API:far
endif
	extrn	PMIDEF_LEN:abs
	extrn	PMIDEF:near
	extrn	SET_GDT:near
	extrn	SET_CG:near
	extrn	SET_PPL0STK:near
	extrn	SET_HWSP:near
	extrn	INT31A_HIMEM_CS:word

	irp	XX,<00,04,05,0D,0E,10,15,1C,20,21,23,24,25,26,27,2F,31,33,41,4B,67>
	extrn	INT&XX&:near
	endm			; IRP

%	extrn	INT&@PMM_INT&:near
%	extrn	INT&@PMF_INT&:near
%	extrn	INT&@PMI_INT&:near

	extrn	PMVSAPI16_MSDOS1:word
	extrn	PMVSAPI32_MSDOS1:word
%	extrn	PMVSAPI16_&@VSAPINAME&1:word
%	extrn	PMVSAPI32_&@VSAPINAME&1:word
if @W9X
	extrn	PMVWIN32_16A:word
	extrn	PMVWIN32_32A:word
endif
	extrn	INT31_RM2PM:near
	extrn	RM2PM_DPMIPRES:near

	NPPROC	TellGXT_CR3 -- Tell GXT About New CR3
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Tell GXT about new CR3 after it has been changed.

On entry:

SS:ESP	==>	TSCR3_STR

|

TellGXT_CR3_STR struc

	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
TellGXT_CR3_LA dd ?		; Linear address of new CR3
TellGXT_CR3_PA dd ?		; Physical ...

TellGXT_CR3_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <eax,ebx,edx,ds> ; Save registers

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	mov	edx,[ebp].TellGXT_CR3_PA ; EDX=Pa of new CR3
	mov	ebx,[ebp].TellGXT_CR3_LA ; EBX=La ...

	and	ebx,ebx 	; Izit undefined?
	jnz	short TellGXT_CR3A ; Jump if not

; Find the linear address of this page in itself

	push	gs		; Save for a moment

	mov	gs,SEL_4GB	; Get AGROUP data selector
	assume	gs:AGROUP	; Tell the assembler about it

	push	dword ptr (1*1024*1024) ; Pass minimum acceptable linear address
	push	edx		; Pass the MM's CR3
	push	edx		; Pass the physical address (/4KB)
	call	PHYS2MMLIN	; Translate physical addr to MM-linear in EAX
	pop	gs		; Restore
	assume	gs:nothing	; Tell the assembler about it
	jnc	short @F	; Jump if found

	SWATMAC ERR,RM		; Call our debugger
@@:
	mov	ebx,eax 	; Copy for SETCR3
TellGXT_CR3A:
	push	@GXCB_SETCR3	; Pass function code to set CR3
				; to EDX phys, EBX lin
	call	GXTHDR.GXTHDR_CBFVEC ; Tell the server about it
				; Return with EAX = return code (0 = OK)
TellGXT_CR3B:
	REGREST <ds,edx,ebx,eax> ; Restore
	assume	ds:nothing	; Tell the assembler about it

	pop	ebp		; Restore

	ret	4+4		; Return to caller, popping arguments

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

TellGXT_CR3 endp		; End TellGXT_CR3 procedure
	FPPROC	RM2PM_ENTRY -- RM to PM Entry Point
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

RM to PM entry point

On entry:

SS:EBP	==>	RM2PM_STR

On exit:

All EGP registers may be clobbered.

|

	REGSAVE <ds,es> 	; Save for a moment

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

; Switch to previous TR,
; ...		     CR3,
; ...		     LDT,
; Tell GXT about it
; Enable paging,

	cmp	DPMITYPE,@DPMITYPEXX ; Any DPMI clients active?
	je	short RM2PM_ENTRY2 ; Jump if not

; Turn off the busy bit for this task

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	mov	eax,[esp].DTR_BASE ; AGROUP:EAX ==> GDT
	add	esp,size DTR_STR ; Strip

	mov	bx,VM2PM_TSS	; Get TR
	and	ebx,0FFFFh xor (mask $PL) ; PL, high-order word=0
	and	AGROUP:[eax+ebx].DESC_ACCESS,not (mask $DS_BUSY) ; Busy=0

	ltr	VM2PM_TSS	; Tell the CPU about it

	push	VM2PM_TSS.EDD	; Pass the selector
	call	GETBASE 	; Return with EAX = base address

	mov	ebx,AGROUP:[eax].TSS_CR3 ; Get the incoming CR3
	mov	cr3,ebx 	; Tell the CPUI about it
	lldt	AGROUP:[eax].TSS_LDT ; Tell the CPU about it

; Tell GXT about the new CR3

	push	ebx		; Pass physical address
	PUSHD	0		; ...  linear address
	call	TellGXT_CR3	; Tell 'em (after the fact)

; Enable paging

	mov	eax,cr0 	; Get current Control Register
	or	eax,mask $PG	; Enable paging
	mov	cr0,eax 	; Tell the CPU about it
RM2PM_ENTRY2:
	mov	eax,[ebp].RM2PM_EPRM.EPRM_EIP ; Get return EIP as indicator
				; of the type of entry
	mov	EntryType,eax	; Save for later use

	cmp	EntryType,offset YGROUP:DPMI_RM2PM_INT ; Izit 1st entry into PM?
	jne	short RM2PM_ENTRY1 ; Jump if not

; Save ptr to current stack

	mov	TempEDF.FSEL,ss ; Save for later use
	mov	TempEDF.FOFF,esp ; ...

; Switch to the stack in the TSS, carrying over the current stack

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	lss	esp,DGROUP:[eax].TSS_ESP0.EDF ; SS:ESP ==> old stack
	assume	ss:nothing	; Tell the assembler about it

; Setup the stack to look like it came from a VM interrupt

	mov	es,DGROUP:[eax].TSS_SS0 ; ES = destin stack
	assume	es:nothing	; Tell the assembler about it

	lds	esi,TempEDF	; DS:ESI ==> source
	assume	ds:nothing	; Tell the assembler about it

	lea	ecx,[ebp + (type RM2PM_STR)] ; Get end of source stack
	sub	ecx,esi 	; Less start of source stack

	sub	esp,ecx 	; Make room on current stack
	mov	edi,esp 	; ES:EDI ==> destin stack

    rep movs	es:[edi].LO,ds:[esi].LO ; Copy source stack to destin stack

	mov	ebp,edi 	; Get ptr to end of stack
	sub	ebp,type RM2PM_STR ; Less struc to get new EBP

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	mov	es,SEL_4GB	; Get AGROUP data selector
	assume	es:AGROUP	; Tell the assembler about it

	jmp	INT31_RM2PM	; Switch from RM to PM


;;;	    call    INT31_RM2PM     ; Switch from RM to PM
;;;	    assume  ds:nothing	    ; Tell the assembler about it
;;;	    assume  es:nothing	    ; Tell the assembler about it
;;;
;;;	    SETDATA ds		    ; Set data selector into DS
;;;	    assume  ds:DGROUP	    ; Tell the assembler about it
;;;
;;; ; Switch back to the original stack, carrying over the current stack
;;;
;;;	    les     edi,TempEDF     ; ES:EDI ==> original stack
;;;	    assume  es:nothing	    ; Tell the assembler about it
;;;
;;;	    mov     esi,esp	    ; SS:ESI ==> source stack
;;;
;;;	    lea     ecx,[ebp + (type RM2PM_STR)] ; Get end of source stack
;;;	    sub     ecx,esi	    ; Less start of source stack
;;;
;;;	rep movs    es:[edi].LO,ss:[esi].LO ; Copy source stack to destin stack
;;;
;;;	    mov     ebp,edi	    ; Get ptr to end of stack
;;;	    sub     ebp,type RM2PM_STR ; Less struc to get new EBP
;;;
;;;	    lss     esp,TempEDF     ; SS:ESP ==> original stack
;;;	    assume  ss:nothing	    ; Tell the assembler about it
;;;
;;; ; If we return from this call, the switch failed so we need
;;; ; to free the allocated extended memory
;;;
;;;	    SETDATA ds		    ; Set data selector into DS
;;;	    assume  ds:DGROUP	    ; Tell the assembler about it
;;;
;;;	    mov     es,SEL_4GB	    ; Get AGROUP data selector
;;;	    assume  es:AGROUP	    ; Tell the assembler about it
;;;
;;; ; Push the current CS:IP onto the RM stack as the return address
;;; ; and set the current CS:IP to FreeAllMem
;;;
;;;	    movzx   ebx,[ebp].RM2PM_EPRM.EPRM_SS ; Get the RM stack segment
;;;	    shl     ebx,4-0	    ; Convert from paras to bytes
;;;	    sub     [ebp].RM2PM_EPRM.EPRM_ESP,2+2 ; Make room for far return
;;;	    add     ebx,[ebp].RM2PM_EPRM.EPRM_ESP ; Plus the RM stack offset
;;;
;;;	    mov     ax,HIMEM_CS     ; Get segment of FreeAllMem
;;;	    xchg    ax,[ebp].RM2PM_EPRM.EPRM_CS ; Swap with RM CS
;;;	    mov     AGROUP:[ebx].IRET_CS,ax ; Save on RM stack
;;;
;;;	    lea     ax,FreeAllMem   ; Get offset of FreeAllMem
;;;	    xchg    ax,[ebp].RM2PM_EPRM.EPRM_EIP.ELO ; Swap with RM IP
;;;	    mov     AGROUP:[ebx].IRET_IP,ax ; Save on RM stack
;;;
;;;	    jmp     RM2PM_ENTRY_EXIT ; Join common exit code
;;;
;;;
	assume	ds:DGROUP	; Tell the assembler about it
	assume	es:AGROUP	; Tell the assembler about it
RM2PM_ENTRY1:
;;;; ; Switch to previous TR,
;;;; ; ...		  CR3,
;;;; ; ...		  LDT,
;;;; ; Tell GXT about it
;;;; ; Enable paging,
;;;;
;;;; ;;;;;;; cmp     LastTR,0	     ; Izit invalid?
;;;; ;;;;;;; je      short RM2PM_ENTRY2 ; Jump if so
;;;;
;;;; ; The var VM2PM_TSS may have in it either VM2PM_TSS1 or
;;;; ; DTE_TSS depending upon how it was restored.  As DTE_TSS
;;;; ; is lower in value than VM2PM_TSS1, we test for the range.
;;;;
;;;;	     mov     ax,VM2PM_TSS1   ; Get selector of 1st TSS
;;;;
;;;;	     cmp     VM2PM_TSS,ax    ; Izit at the beginning?
;;;;	     jbe     short RM2PM_ENTRY2 ; Jump if so
;;;;
;;;; ; Turn off the busy bit for this task
;;;;
;;;;	     sub     esp,size DTR_STR ; Make room on stack
;;;;	     SGDTD   [esp].EDF	     ; Save GDTR on stack
;;;;	     mov     eax,[esp].DTR_BASE ; AGROUP:EAX ==> GDT
;;;;	     add     esp,size DTR_STR ; Strip
;;;;
;;;; ;;;;;;; mov     bx,LastTR	     ; Get TR
;;;;	     mov     bx,VM2PM_TSS    ; Get TR
;;;;	     and     ebx,0FFFFh xor (mask $PL) ; PL, high-order word=0
;;;;	     and     AGROUP:[eax+ebx].DESC_ACCESS,not (mask $DS_BUSY) ; Busy=0
;;;;
;;;; ;;;;;;; ltr     LastTR	     ; Tell the CPU about it
;;;;	     ltr     VM2PM_TSS	     ; Tell the CPU about it
;;;;
;;;; ;;;;;;; push    LastTR.EDD      ; Pass the selector
;;;;	     push    VM2PM_TSS.EDD   ; Pass the selector
;;;;	     call    GETBASE	     ; Return with EAX = base address
;;;;
;;;;	     mov     ebx,AGROUP:[eax].TSS_CR3 ; Get the incoming CR3
;;;;	     mov     cr3,ebx	     ; Tell the CPUI about it
;;;;	     lldt    AGROUP:[eax].TSS_LDT ; Tell the CPU about it
;;;;
;;;; ; Tell GXT about the new CR3
;;;;
;;;;	     push    ebx	     ; Pass physical address
;;;;	     PUSHD   0		     ; ...  linear address
;;;;	     call    TellGXT_CR3     ; Tell 'em (after the fact)
;;;;
;;;; ; Enable paging
;;;;
;;;;	     mov     eax,cr0	     ; Get current Control Register
;;;;	     or      eax,mask $PG    ; Enable paging
;;;;	     mov     cr0,eax	     ; Tell the CPU about it
;;;;
;;;;	     mov     ebx,[ebp].RM2PM_EGP.PUSHAD_EBX ; Restore EBX
;;;; RM2PM_ENTRY2:
;;;;	     mov     eax,[ebp].RM2PM_EGP.PUSHAD_EAX ; Restore EAX

	mov	eax,[ebp].RM2PM_EGP.PUSHAD_EAX ; Restore EAX
	mov	ebx,[ebp].RM2PM_EGP.PUSHAD_EBX ; ...	 EBX

; Split cases

	cmp	EntryType,offset YGROUP:DPMI_RM2PM_PRES ; Izit DPMI presence detection?
	jne	short RM2PM_ENTRY3 ; Jump if not

	call	RM2PM_DPMIPRES	; Check for DPMI presence

	jmp	RM2PM_ENTRY_EXIT ; Join common exit code


RM2PM_ENTRY3:
%	cmp	EntryType,offset YGROUP:DPMI_RM2PM_&@PMH_INT ; Izit HW Interrupt?
	je	short @F	; Jump if so

	cmp	EntryType,offset YGROUP:DPMI_RM2PM_VMI06 ; Izit VMI 06h?
	je	short @F	; Jump if so

	cmp	EntryType,offset YGROUP:DPMI_RM2PM_VMI0D ; Izit VMI 0Dh?
	jne	near ptr RM2PM_ENTRY4 ; Jump if not
@@:

; Save ptr to current stack

	mov	TempEDF.FSEL,ss ; Save for later use

; Switch to the current SS0:ESP0 in the TSS

	mov	eax,PCURTSS	; Get offset in DGROUP of current TSS
	lss	esp,DGROUP:[eax].TSS_ESP0.EDF ; SS:ESP ==> old stack
	assume	ss:nothing	; Tell the assembler about it

; Setup the stack to look like it came from a VM interrupt

	mov	gs,TempEDF.FSEL ; GS:EBP ==> RM2PM_STR
	assume	gs:nothing	; Tell the assembler about it

	push	gs:[ebp].RM2PM_GDTR.DTR_BASE	; Pass caller's GDTR.BASE
	push	gs:[ebp].RM2PM_GDTR.DTR_LIM	; ...		GDTR.LIM
	push	gs:[ebp].RM2PM_DEV_FLAG 	; ...		DEV_FLAG
	push	gs:[ebp].RM2PM_NEXT		; ...		NEXT
	push	gs:[ebp].RM2PM_EPRM.EPRM_GS.EDD ; Pass caller's GS
	push	gs:[ebp].RM2PM_EPRM.EPRM_FS.EDD ; ...		FS
	push	gs:[ebp].RM2PM_EPRM.EPRM_DS.EDD ; ...		DS
	push	gs:[ebp].RM2PM_EPRM.EPRM_ES.EDD ; ...		ES
	push	gs:[ebp].RM2PM_EPRM.EPRM_SS.EDD ; ...		SS
	push	gs:[ebp].RM2PM_EPRM.EPRM_ESP	; ...		ESP
	push	gs:[ebp].RM2PM_EPRM.EPRM_EFL	; ...		EFL
;;;;;;; push	gs:[ebp].RM2PM_EPRM.EPRM_CS.EDD ; ...		CS
;;;;;;; push	gs:[ebp].RM2PM_EPRM.EPRM_EIP	; ...		EIP

; The caller's stack pointed to by gs:[ebp].RM2PM_EPRM.EPRM_ESP
; is the return address in the HPDA which we must pass to INT&@PMH_INT
; instead of gs:[ebp].RM2PM_EPRM.EPRM_EIP.EDF

	movzx	esi,gs:[ebp].RM2PM_EPRM.EPRM_SS ; Get stack segment
	shl	esi,4-0 	; Convert from paras to bytes
	movzx	eax,gs:[ebp].RM2PM_EPRM.EPRM_ESP.ELO ; Get stack offset
	add	esi,eax 	; Add to get stack linear address

	movzx	eax,AGROUP:[esi].IRET_CS ; Get return CS
	push	eax		; Pass as return CS w/filler
	movzx	eax,AGROUP:[esi].IRET_IP ; Get return IP
	push	eax		; Pass as return EIP

; Now SS:ESP ==> INTCOM_STR

	cmp	EntryType,offset YGROUP:DPMI_RM2PM_VMI0D ; Izit VMI 0Dh?
	jne	short @F	; Jump if not

	call	IzitIRQ5	; Is IRQ5 active?
	jnz	short @F	; Jump if so (must be HW interrupt)

	PUSHD	0		; Pass pseudo-error code

; Now SS:ESP ==> INTCOM_STR+ErrorCode

@@:
	add	[esp].INTCOM_ESP,type IRET_STR ; Strip from the stack

; Restore original EGP registers

	mov	eax,gs:[ebp].RM2PM_EGP.PUSHAD_EAX ; Restore EAX
	mov	esi,gs:[ebp].RM2PM_EGP.PUSHAD_ESI ; ...     ESI
	mov	ebp,gs:[ebp].RM2PM_EGP.PUSHAD_EBP ; ...     EBP

%	cmp	EntryType,offset YGROUP:DPMI_RM2PM_&@PMH_INT ; Izit HW Interrupt?
%      MJ e	INT&@PMH_INT	; Jump if so

	cmp	EntryType,offset YGROUP:DPMI_RM2PM_VMI06 ; Izit VMI 06h?
       MJ e	INT06		; Jump if so

	cmp	EntryType,offset YGROUP:DPMI_RM2PM_VMI0D ; Izit VMI 0Dh?
       MJ e	INT0D		; Jump if so

	SWATMAC ERR		; We should never get here


RM2PM_ENTRY4:
	SWATMAC ERR		; We should never get here










RM2PM_ENTRY_EXIT:
	REGREST <es,ds> 	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

RM2PM_ENTRY endp		; End RM2PM_ENTRY procedure
	NPPROC	IzitIRQ5 -- Is IRQ5 Active?
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

See if we're called with IRQ5 in-service

On exit:

ZF	=	1 if so
	=	0 if not

|

	push	eax		; Save for a moment

	mov	al,@GETISR	; Code to read ISR
	out	@ICR,al 	; Tell the 8259 about it
	call	DRAINPIQ	; Drain the Prefetch Instruction Queue

	in	al,@ICR 	; Read the ISR
;;;;;;; call	U32_DRAINPIQ	; Drain the Prefetch Instruction Queue

	test	al,mask $IRQ5	; Izit in service?
	pop	eax		; Restore
				; Return with ZF=1 iff so
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

IzitIRQ5 endp			; End IzitIRQ5 procedure
	NPPROC	DRAINPIQ -- Drain The Prefetch Instruction Queue
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Drain the Prefetch Instruction Queue.

If we're on a Micro Channel system, write to I/O port 4Fh.
Otherwise, just jump a few times.

Flags are saved and restored over this routine to allow it
to be used with impunity.

|

;;;;;;; pushfd			; Save flags

;;;;;;; test	PREF&SWATINI.MD_ATTR,@MD_MCA ; Izit an MCA-compatible?
;;;;;;; jz	short @F	; Not this time
;;;;;;;
;;;;;;; out	@8253_XCIO,al	; Write to (presumably uncached) port
;;;@@:
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

;;;;;;; popfd			; Restore flags

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DRAINPIQ endp			; End DRAINPIQ procedure
	FPPROC	INIT_PROT -- PM Initialization Code
	assume	ds:nothing,es:AGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

PM initialization code

|

	pushad			; Save all EGP registers
	REGSAVE <ds,es,gs>	; Save registers

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

	mov	SEL_DATA,ds	; Save for later use
	mov	SEL_4GB,es	; ...

	push	ds		; Pass the selector
	call	GETBASE 	; Return with EAX = base address
	mov	DGRBASE,eax	; Save for later use

	push	cs		; Pass the selector
	call	GETBASE 	; Return with EAX = base address
	mov	PGRBASE,eax	; Save for later use

	mov	eax,PVMTSS	; DGROUP:EAX ==> VM TSS
	add	eax,DGRBASE	; AGROUP:EAX ==> ...
	mov	LaVMTSS,eax	; Save as linear address of VMTSS

	mov	ax,ds		; Get data selector
	add	ax,type DESC_STR ; Skip to next selector
	mov	DTE_DPMIDEF,ax	; Save for later use

	add	ax,type DESC_STR ; Skip to next selector
	mov	DTE_DPMI_VSAPI,ax ; Save for later use

if @W9X
	add	ax,type DESC_STR ; Skip to next selector
	mov	DTE_DPMI_VWIN32,ax ; Save for later use
endif
	add	ax,type DESC_STR ; Skip to next selector
	mov	VM2PM_TSS,ax	; Save for later use
;;;;;;; mov	VM2PM_TSS1,ax	; ...

	str	VMTSS.ELO	; Save for later use

; Setup default interrupt handler selector

	mov	eax,PGRBASE	; Get linear address of PGROUP
	add	eax,offset PGROUP:PMIDEF ; Plus offset of default handler
	mov	LaPMIDEF,eax	; Save for later use

	mov	ebx,PMIDEF_LEN	; Get length of the default interrupt handlers

	push	ebx		; Pass size of area in bytes
	push	word ptr (((mask $DTE_B) shl 8) or CPL0_CODE or (@DPMI_DPL shl $DT_DPL)) ; Pass A/R word
	push	DTE_DPMIDEF	; Pass descriptor to set
	call	SET_GDT 	; Set the GDT to EAX base

; Save selector in appropriate places

	mov	ax,DTE_DPMIDEF	; Get the selector
	or	ax,@DPMI_CPL shl $PL ; Set the PL bits
	mov	DPMI_IDEF,ax	; Save for later use

	mov	ecx,256 	; Get # entries in PMINT_DVECS
	xor	esi,esi 	; Initialize index into PMINT_DVECS
@@:
	mov	PMINT_DVECS[esi].VSEG,ax ; Save for later use
	add	esi,type PMINT_DVECS ; Skip to next entry

	loop	@B		; Jump if more entries

	mov	ecx,256 	; Get # entries in PMINT_FVECS
	xor	esi,esi 	; Initialize index into PMINT_FVECS
@@:
	mov	PMINT_FVECS[esi].FSEL,ax ; Save for later use
	add	esi,type PMINT_FVECS ; Skip to next entry

	loop	@B		; Jump if more entries

	mov	ecx,32		; Get # entries in PMFLT_DVECS
	xor	esi,esi 	; Initialize index into PMFLT_DVECS
@@:
	mov	PMFLT_DVECS[esi].VSEG,ax ; Save for later use
	add	esi,type PMFLT_DVECS ; Skip to next entry

	loop	@B		; Jump if more entries

	mov	ecx,32		; Get # entries in PMFLT_FVECS
	xor	esi,esi 	; Initialize index into PMFLT_FVECS
@@:
	mov	PMFLT_FVECS[esi].FSEL,ax ; Save for later use
	add	esi,type PMFLT_FVECS ; Skip to next entry

	loop	@B		; Jump if more entries

	mov	ecx,32		; Get # entries in VMFLT_DVECS
	xor	esi,esi 	; Initialize index into VMFLT_DVECS
@@:
	mov	VMFLT_DVECS[esi].VSEG,ax ; Save for later use
	add	esi,type VMFLT_DVECS ; Skip to next entry

	loop	@B		; Jump if more entries

	mov	ecx,32		; Get # entries in VMFLT_FVECS
	xor	esi,esi 	; Initialize index into VMFLT_FVECS
@@:
	mov	VMFLT_FVECS[esi].FSEL,ax ; Save for later use
	add	esi,type VMFLT_FVECS ; Skip to next entry

	loop	@B		; Jump if more entries








; Save DPMI Vendor-Specific API entry call gate

	lea	eax,DPMIFN_VSAPI ; Get the offset
	push	cs		; Pass code selector
	push	eax		; Pass offset
	push	word ptr (((@VSAPI_DDSTKSIZE+2) shl 8) or CPL0_CALL3 or (@DPMI_DPL shl $DT_DPL))
				; Pass access, rights byte,
				; parm count = @VSAPI_DDSTKSIZE+2
	push	DTE_DPMI_VSAPI	; Pass descriptor to set
	call	SET_CG		; Set the GDT to a call gate

; Save selector in appropriate places

	mov	ax,DTE_DPMI_VSAPI ; Get the VSAPI selector
	mov	ebx,PGRBASE	; Get linear address of PGROUP

	assume	es:PGROUP	; Tell a white lie
	mov	PMVSAPI16_MSDOS1[ebx],ax  ; Save in code
	mov	PMVSAPI32_MSDOS1[ebx],ax  ; ...
%	mov	PMVSAPI16_&@VSAPINAME&1[ebx],ax ; ...
%	mov	PMVSAPI32_&@VSAPINAME&1[ebx],ax ; ...
	assume	es:AGROUP	; Retract nose

if @W9X

; Save DPMI VWIN32 API entry call gate

	lea	eax,VWIN32_API	; Get the offset
	push	cs		; Pass code selector
	push	eax		; Pass offset
	push	word ptr ((1 shl 8) or CPL0_CALL3 or (@DPMI_DPL shl $DT_DPL))
				; Pass access, rights byte,
				; parm count = 1 (EFL)
	push	DTE_DPMI_VWIN32 ; Pass descriptor to set
	call	SET_CG		; Set the GDT to a call gate

; Save selector in appropriate places

	mov	ax,DTE_DPMI_VWIN32 ; Get the VWIN32 selector
	mov	ebx,PGRBASE	; Get linear address of PGROUP

	assume	es:PGROUP	; Tell a white lie
	mov	PMVWIN32_16A[ebx],ax  ; Save in code
	mov	PMVWIN32_32A[ebx],ax  ; ...
	assume	es:AGROUP	; Retract nose
endif

; Establish addressibility to GDT

	sub	esp,size DTR_STR ; Make room on stack
	SGDTD	[esp].EDF	; Save GDTR on stack
	mov	ebx,[esp].DTR_BASE ; ES:EBX ==> GDT
	add	esp,size DTR_STR ; Strip

; If selector 40h is based at 400h (BIOS data are), make sure it's at DPL3

	push	40h		; Pass the selector
	call	GETBASE 	; Return with EAX = base address

	cmp	eax,0400h	; Izit for the BIOS data area?
	jne	short @F	; Jump if not

	or	AGROUP:[ebx+40h].DESC_ACCESS,DPL3 ; Set to DPL3
@@:

; Calculate linear address of I/O bit permission map

	push	VMTSS		; Pass the selector
	call	GETBASE 	; Return with EAX = base address
	mov	LaVMTSS,eax	; Save for later use

	movzx	ebx,AGROUP:[eax].TSS_IOMAP ; Get offset to I/O bit permission map
	add	eax,ebx 	; Add to get the linear address
	mov	LaIOBIT,eax	; Save for later use

; Copy the SIRB and I/O bit permission map to local storage

	mov	esi,LaIOBIT	; AGROUP:ESI ==> I/O permission bitmap
	sub	esi,256/8	; Less size of SIRB table
	mov	edi,PIOBIT	; DGROUP:EDI ==> save area
	add	edi,DGRBASE	; AGROUP:EDI ==> ...
	mov	ecx,(256 / 8) + (8 * 1024) + 1 ; Get # bytes to copy
    rep movs	AGROUP:[edi].LO,AGROUP:[esi].LO ; Copy to local storage

; If VME is supported and enabled, copy the table and
; set the corresponding bits

	test	CPUFET_FLAG,mask $CPUFET_VME ; Izit supported?
	jz	short INIT_PROT1 ; Jump if not

	MOVSPR	edx,cr4 	; Get CPU extensions register

	test	edx,mask $VME	; Izit enabled?
	jz	short INIT_PROT1 ; Jump if not

; Copy the current table to restore when we terminate

	mov	eax,LaIOBIT	; Get offset in AGROUP of I/O permission bitmap
	lea	esi,[eax-256/8] ; Less size of SIRB table
	lea	edi,ORGSIRB	; DS:EDI ==> save area
	add	edi,DGRBASE	; ES:EDI ==> ...
	mov	ecx,256/8	; Get # bytes in table
    rep movs	AGROUP:[edi].LO,AGROUP:[esi].LO ; Copy to local storage

	BT_MAC	bts,<AGROUP:[eax-256/8].EDD>,2Fh ; Enable it
	BT_MAC	bts,<AGROUP:[eax-256/8].EDD>,31h ; ...
%	BT_MAC	bts,<AGROUP:[eax-256/8].EDD>,0&@PMH_INT&h ; HARDINT/DPMI

;;;;;;; mov	eax,LaIOBIT	; Get offset in AGROUP of I/O permission bitmap
	lea	esi,[eax-256/8] ; Less size of SIRB table
	lea	edi,CURSIRB	; DS:EDI ==> save area
	add	edi,DGRBASE	; ES:EDI ==> ...
	mov	LaSIRBCUR,edi	; Save for later use
	mov	ecx,256/8	; Get # bytes in table
    rep movs	AGROUP:[edi].LO,AGROUP:[esi].LO ; Copy to local storage
INIT_PROT1:

; Initialize TSSs

	mov	edi,PVMTSS	; DGROUP:EDI ==> TSSs
	add	edi,DGRBASE	; AGROUP:EDI ==> ...
	mov	ecx,(@TSS_MAX*(type DPTSS_STR))/4 ; ECX # dwords in TSSs
	xor	eax,eax 	; Fill with this
    rep stos	AGROUP:[edi].EDD ; Clear to fill value

; Setup PVMTSS as a copy of the original TSS

	mov	esi,LaVMTSS	; AGROUP:ESI ==> source
	mov	ax,AGROUP:[esi].TSS_SS0 ; Get the stack selector
	mov	PPL0STK_SEL,ax	; Save for later use

	mov	eax,AGROUP:[esi].TSS_ESP0 ; Get the initial stack offset
	mov	PPL0STK_MAX,eax ; Save for later use
	sub	eax,size INTCOM_STR ; Back off by frame size
	mov	LAST_INTCOM,eax ; Save as offset of last INTCOM interrupt frame

	mov	eax,PPL0STK_MAX ; Get maximum stack offset
	sub	eax,8*1024	; Assume we have this much
	mov	PPL0STK_MIN,eax ; Save as minimum stack offset

	mov	edi,PVMTSS	; DGROUP:EDI ==> destin
	add	edi,DGRBASE	; AGROUP:EDI ==> ...
	mov	ecx,type TSS_STR ; Copy the filled in part
    rep movs	AGROUP:[edi].LO,AGROUP:[esi].LO ; Copy to local storage

	call	SET_PPL0STK	; Set PPL0STK... pointers

; Initialize TSS selectors in the GDT

	mov	ecx,@TSS_MAX	; Get # TSSs
	mov	si,VM2PM_TSS	; Get 1st TSS selector

	mov	ebx,PIOBIT	; DGROUP:EBX ==> I/O bit permission map
	mov	edi,ebx 	; Copy
	add	ebx,1 + (64 * 1024) / 8 ; Plus size of I/O permission bitmap in bytes
	mov	eax,PVMTSS	; DGROUP:EAX = 1st TSS
	sub	ebx,eax 	; Less start of 1st TSS to get length of TSS
	sub	edi,eax 	; ...			       offset in TSS
	add	eax,DGRBASE	; AGROUP:EAX = ...
INIT_PROT_TSS1:
	push	ebx		; Pass size of area in bytes
	push	word ptr (CPL0_IDLE3 or (@DPMI_DPL shl $DT_DPL)) ; Pass A/R word
	push	si		; Pass descriptor to set
	call	SET_GDT 	; Set the GDT to EAX base

	add	si,type DESC_STR ; Skip to LDT selector

	push	eax		; Save for a moment

	xor	eax,eax 	; Zero the base address

	mov	edx,CPL0_LDT	; Get A/R byte
	or	dl,DPMI_DPL	; Include DPL

	PUSHD	0		; Pass size of area in bytes
	push	dx		; Pass A/R word
	push	si		; Pass descriptor to set
	call	SET_GDT 	; Set the GDT to EAX base (actually set later)

	pop	eax		; Restore

; Initialize the TSS_IOMAP values

	mov	AGROUP:[eax].TSS_IOMAP,di ; Save as offset to I/O bit permission map

	add	si,type DESC_STR ; Skip to next TSS selector
	add	eax,type DPTSS_STR ; Skip to next TSS
	sub	ebx,type DPTSS_STR ; Reduce size by one TSS
	sub	edi,type DPTSS_STR ; ...

	loop	INIT_PROT_TSS1	; Jump if more TSSs

; Establish addressibility to IDT

	sub	esp,size DTR_STR ; Make room on stack
	SIDTD	[esp].EDF	; Save IDTR on stack
	mov	ebx,[esp].DTR_BASE ; ES:EBX ==> IDT
	add	esp,size DTR_STR ; Strip

; Tell the loader that we're about to change the IDT

	push	@GXCB_CHGIDT	; Pass function code to change IDT
	call	GXTHDR.GXTHDR_CBFVEC ; Request callback services
				; Return with EAX = return code (0 = OK)

IDT	equ	<AGROUP:[ebx+edx*(type IDT_STR)]>

	xor	edx,edx 	; Initialize index into tables
	mov	ecx,256 	; # interrupts
INIT_PROT_NEXT:
	lea	edi,[edx*2]	; EDI = EDX*2 to add to EDX*4 to get EDX*6

	test	DB2_FLAG,@DB2_NODEBUG ; Disable hooking INTs 01h and 03h?
	jz	short @F	; Jump if not

	cmp	edx,01h 	; Izit INT 01h?
	je	short INIT_PROT_SAVE ; Jump if so

	cmp	edx,03h 	; Izit INT 03h?
	je	short INIT_PROT_SAVE ; Jump if so
@@:
	test	DB2_FLAG,@DB2_NONMI ; Disable hooking INT 02h?
	jz	short @F	; Jump if not

	cmp	edx,02h 	; Izit INT 02h?
	je	short INIT_PROT_SAVE ; Jump if so
@@:
	test	DB2_FLAG,@DB2_NOKEYB ; Disable hooking INT 09h?
	jz	short @F	; Jump if not

	cmp	edx,09h 	; Izit INT 09h?
	je	short INIT_PROT_SAVE ; Jump if so
@@:
	mov	ax,cs		; Get source selector
	xchg	ax,IDT.IDT_SELECT ; Swap 'em
	mov	OLDINT_FVEC.FSEL[edx*4+edi],ax ; Save to restore later

	mov	eax,TABINT_OFF[edx*(type TABINT_OFF)] ; Get the offset
	xchg	ax,IDT.IDT_OFFLO ; Swap with IDT
	mov	OLDINT_FVEC.FOFF.ELO[edx*4+edi],ax ; Save to restore later
	shr	eax,16		; Shift to low-order
	xchg	ax,IDT.IDT_OFFHI ; Swap with IDT
	mov	OLDINT_FVEC.FOFF.EHI[edx*4+edi],ax ; Save to restore later

	mov	al,IDT.IDT_ACCESS ; Get the A/R byte
	mov	OLDINT_ARB[edx*(type OLDINT_ARB)],al ; Save to restore later

;;;;;;; and	al,mask $DT_DPL ; Preserve the DPL
;;;;;;; or	al,CPL0_INTR3	; Make it an Interrupt Gate
	mov	al,CPL0_INTR3 or (@DPMI_DPL shl $DT_DPL) ; Make it an Interrupt Gate
	mov	IDT.IDT_ACCESS,al ; Put into place

	jmp	short INIT_PROT_LOOP ; Join common code


INIT_PROT_SAVE:
	mov	ax,IDT.IDT_SELECT ; Get IDT selector
	mov	OLDINT_FVEC.FSEL[edx*4+edi],ax ; Save to restore later

	mov	ax,IDT.IDT_OFFHI ; Get IDT high-order offset
	shl	eax,16		; Shift to high-order
	mov	ax,IDT.IDT_OFFLO ; Get IDT low-order offset
	mov	OLDINT_FVEC.FOFF[edx*4+edi],eax ; Save to restore later

	mov	al,IDT.IDT_ACCESS ; Get the A/R byte
	mov	OLDINT_ARB[edx*(type OLDINT_ARB)],al ; Save to restore later
INIT_PROT_LOOP:
	inc	edx		; Skip to next interrupt

;;;;;;; loop	INIT_PROT_NEXT	; Jump if more interrupts
	dec	ecx		; Count out another one
	jnz	INIT_PROT_NEXT	; Jump if more interrupts

; Hook in special handlers

	SETIDT	00		; Divide overflow fault

	test	DB2_FLAG,@DB2_NODEBUG ; Disable hooking INTs 01h and 03h?
	jnz	short @F	; Jump if so

	SETIDT	01		; Debug exception
	SETIDT	03		; Breakpoint exception
@@:
	test	DB2_FLAG,@DB2_NONMI ; Disable hooking INT 02h?
	jnz	short @F	; Jump if so

	SETIDT	02		; NMI
@@:
	SETIDT	04		; INTO exception
	SETIDT	05		; BOUND fault
	SETIDT	06		; Invalid opcode exception
	SETIDT	07		; Coprocessor not available (clear TS)
	SETIDT	08		; Normal IRQ0 = Double Fault

	test	DB2_FLAG,@DB2_NOKEYB ; Disable hooking INT 09h?
	jnz	short @F	; Jump if so

	SETIDT	09		; Normal IRQ1 = FP segment overrun
@@:
	SETIDT	0A		; Normal IRQ2 = Invalid TSS
	SETIDT	0B		; Normal IRQ3 = Segment Not Present
	SETIDT	0C		; Normal IRQ4 = Stack Fault
	SETIDT	0D		; Normal IRQ5 = General Protection
	SETIDT	0E		; Normal IRQ6 = Page Fault
	SETIDT	0F		; Normal IRQ7 = Printer

	SETIDT	10		; Used for BIOS translation
	SETIDT	15		; BIOS System Services

	test	VMM_FLAG,@VMM_BSGLOBAL ; Is there a swapfile present?
	jz	short @F	; Jump if not

	SETIDT	1C		; Secondary timer tick
	SETIDT	23		; Ignore if paging active
	SETIDT	24		; Fail if paging active
@@:
	SETIDT	21		; DOS interrupt handler
	SETIDT	2F		; XMS ...

	SETIDT	20		; Fail if called from PM
	SETIDT	25		; ...
	SETIDT	26		; ...
	SETIDT	27		; ...
	SETIDT	31		; DPMI interrupt handler
	SETIDT	33		; Mouse interrupt handler
	SETIDT	41		; Windows kernel debugger
	SETIDT	4B		; VDS interrupt handler
%	SETIDT	@PMI_INT	; PM Interrupt return
%	SETIDT	@PMF_INT	; PM (and VM) Fault return
%	SETIDT	@PMM_INT	; PM miscellaneous returns

	test	DPM_FLAG,mask $DPM_NOVCPI ; Are we failing VCPI calls?
	jz	short @F	; Jump if not

	SETIDT	67		; VCPI Services
@@:
	SETIDT	70		; Normal IRQ8  = Real-Time Clock
	SETIDT	71		; Normal IRQ9  = Redirect Cascade
	SETIDT	72		; Normal IRQ10 = (Reserved)
	SETIDT	73		; Normal IRQ11 = (Reserved)
	SETIDT	74		; Normal IRQ12 = Auxiliary Device (Mouse)
	SETIDT	75		; Normal IRQ13 = Math Coprocessor (Redirect to NMI)
	SETIDT	76		; Normal IRQ14 = Fixed Disk
	SETIDT	77		; Normal IRQ15 = (Reserved)

; Handle hardware interrupt returns specially

%	SETIDT	@PMH_INT	; Hardware interrupt return

; Save address of current INT 07h handler for later use

	mov	edx,07h 	; Save this interrupt #
	mov	eax,IDT.EDQLO	; Get low-order dword
	mov	INT07DP.EDQLO,eax ; Save for later use

	mov	eax,IDT.EDQHI	; Get high-order dword
	mov	INT07DP.EDQHI,eax ; Save for later use

; Tell the loader that we're finished changing the IDT

	push	@GXCB_CHGIDTZ	; Pass function code to end change of IDT
	call	GXTHDR.GXTHDR_CBFVEC ; Request callback services
				; Return with EAX = return code (0 = OK)

; Fill in the remaining part of the TSSs

	mov	ecx,@TSS_MAX	; Get # TSSs we have
	mov	ebx,PVMTSS	; Get offset in DGROUP of 1st TSS
	mov	si,VM2PM_TSS	; Get selector of the 1st TSS
INIT_PROT_NEXTTSS:

; This TSS will never be called from PL1 or PL2,
; so we can ignore their stacks.

	mov	eax,PPL0STK_MAX ; Get top of stack
	mov	DGROUP:[ebx].TSS_ESP0,eax ; Save in TSS
	mov	ax,PPL0STK_SEL ; Get stack selector
	mov	DGROUP:[ebx].TSS_SS0,ax ; Save stack selector

	mov	DGROUP:[ebx].TSS_LINK,-1 ; Mark TSS as available
	mov	DGROUP:[ebx].DPTSS_SEL,si ; Save the selector value
	add	si,type DESC_STR ; Skip to LDT selector
	mov	DGROUP:[ebx].TSS_LDT,si ; Save as LDT selector

; Note we zero the DPTSS-specific fields when we first use the TSS

	add	si,type DESC_STR ; Skip to next TSS selector
	add	ebx,type DPTSS_STR ; Skip to next TSS

	loop	INIT_PROT_NEXTTSS ; Jump if more TSSs to initialize

; The first TSS is initialized differently as it is used when there
; are no DPMI clients active.

	mov	ebx,PVMTSS	; Get offset in DGROUP of VM TSS

	mov	ax,VMTSS.ELO	; Get original TSS selector
	mov	DGROUP:[ebx].DPTSS_SEL,ax ; Save the selector value

; Save physical address of global CR3

	mov	eax,OffCR3	; Get offset in DGROUP of global CR3
	add	eax,DGRBASE	; Plus base address of DGROUP to get Linear address
	add	eax,4*1024-1	; Round up to 4KB
	and	eax,not (4*1024-1) ; ...boundary
	mov	edx,eax 	; Copy linear address
	sub	edx,DGRBASE	; Less base of DGROUP to get offset in DGROUP
	mov	OffCR3,edx	; Save as new offset in DGROUP

; If paging is enabled, translate the linear address in EAX
; to a physical address

	push	@GXCB_LIN2PHYS	; Pass function code to convert address in EAX
	call	GXTHDR.GXTHDR_CBFVEC ; Request callback services
				; Return with EAX = return code (0 = OK)
				; ...	      EDX = physical address
	mov	PaCR3,edx	; Save as physical address

; Save physical address of Scratch PTE

	test	VMM_FLAG,@VMM_BSGLOBAL ; Test if swapfile=xxxxx was found
	jnz	short INIT_PROT_SWAPFILE ; Jump if so

	mov	eax,OffScrPTE	; Get offset in DGROUP
	add	eax,DGRBASE	; Plus base address of DGROUP to get Linear address
	add	eax,4*1024-1	; Round up to 4KB
	and	eax,not (4*1024-1) ; ...boundary
	mov	edx,eax 	; Copy linear address
	sub	edx,DGRBASE	; Less base of DGROUP to get offset in DGROUP
	mov	OffScrPTE,edx	; Save as new offset in DGROUP

; If paging is enabled, translate the linear address in EAX
; to a physical address

	push	@GXCB_LIN2PHYS	; Pass function code to convert address in EAX
	call	GXTHDR.GXTHDR_CBFVEC ; Request callback services
				; Return with EAX = return code (0 = OK)
				; ...	      EDX = physical address
	mov	PAScrPTE,edx	; Save as physical address
INIT_PROT_SWAPFILE:

; Set CR3 -- if paging is enabled, use CR3; otherwise use PaCR3

	mov	edx,cr0 	; Get register with paging bit
	mov	eax,cr3 	; Get current PDBR

	test	edx,mask $PG	; Is paging enabled?
	jnz	short @F	; Jump if so

	mov	eax,PaCR3	; Get physical address of CR3
@@:
	mov	DGROUP:[ebx].TSS_CR3,eax ; Save current CR3 in TSS

	sldt	DGROUP:[ebx].TSS_LDT ; Save the current LDT

	mov	DGROUP:[ebx].DPTSS_OLDPM,-1 ; Zap starting linear address
	mov	DGROUP:[ebx].DPTSS_LPMSTK_FVEC.FOFF,-1 ; ...
	mov	DGROUP:[ebx].DPTSS_LPMSTK_FVEC.FSEL,-1 ; ...
	mov	DGROUP:[ebx].DPTSS_LPMSTK_CNT,-1 ; ...
	mov	DGROUP:[ebx].DPTSS_LPMBASE,-1 ; ...
	mov	DGROUP:[ebx].DPTSS_PLNKTSS,-1 ; ...

	mov	eax,LaSIRBCUR	; Get current linear address
	mov	DGROUP:[ebx].DPTSS_LaSIRBCUR,eax ; Save for later use

	movzx	eax,HIMEM_CS	; Get segment of 1st megabyte data
	add	eax,(LCL_HPDA-YYSTART)/16 ; Plus paras to HPDA
	mov	DGROUP:[ebx].DPTSS_HPDASEG,ax ; Save for later use
	mov	DGROUP:[ebx].DPTSS_VMSTKSEG,ax ; ...
	shl	eax,4-0 	; Convert from paras to bytes
	mov	DGROUP:[ebx].DPTSS_LaHPDA,eax ; Save for later use
	mov	AGROUP:[eax].HPDA_PCURTSS,ebx ; ...

	smsw	ax		; Get MSW after API loads
	and	ax,mask $EM	; Isolate EM bit

	test	LCL_FLAG,@LCL_NDPIN ; Is NDP installed?
	jz	short @F	; Jump if not

	or	ax,mask $MP	; Mark as enabled for this client
@@:
	mov	MSW_PM,ax	; Save MSW for PM operation
	mov	DGROUP:[ebx].DPTSS_MSW,ax ; Save MSW for VM operation

	mov	eax,INT07DP.EDQLO ; Get low-order dword
	mov	DGROUP:[ebx].DPTSS_IDT07.EDQLO,eax ; Save for later use

	mov	eax,INT07DP.EDQHI ; Get high-order dword
	mov	DGROUP:[ebx].DPTSS_IDT07.EDQHI,eax ; Save for later use

; Save the offset of the current stack top

	mov	ax,HPDASTK_TOP	; Get offset of top of HPDA stack
	mov	DGROUP:[ebx].DPTSS_VMSTKOFF,ax ; Save for later use

	sub	ax,HPDASTK_SIZ	; Less size of HPDA stack
	mov	DGROUP:[ebx].DPTSS_VMSTKBOT,ax ; Save for later use

	or	LCL_FLAG,@LCL_HPDA ; Mark as present

;;;;;;; mov	eax,PLCL_PL0CUR ; Get current offset in DGROUP
;;;;;;; mov	DGROUP:[ebx].DPTSS_PLCL_PL0CUR,eax ; Save to restore later
;;;;;;;
	call	SET_HWSP	; Set DPMI_HWSP values for special interrupts

	mov	ax,ds		; Get DGROUP data selector
	mov	es,ax		; Address it
	assume	es:DGROUP	; Tell the assembler about it

;;; ; Set the PL0_CUR stack to a known value
;;;
;;;	    mov     edi,PLCL_PL0STKZ ; Get the end of the stack
;;;	    mov     ecx,@LCL_PL0STK_SIZ ; Get the size in bytes
;;;	    sub     edi,ecx	    ; Back off to the start
;;;	    shr     ecx,2-0	    ; Convert from bytes to dwords
;;;	    mov     eax,'CATS'      ; A known value
;;;	rep stos    DGROUP:[edi].EDD ; Store it
;;;
;;; ; Save trailing count of zero after PLCL_PL0STKZ
;;;
;;;	    xor     eax,eax	    ; A convenient zero
;;;	    stos    DGROUP:[edi].EDD ; Store it
;;;
; Set special variables based upon which MM is in effect

	test	GXTHDR.GXTHDR_ATTR,@GXTHDR_FCR3 ; Does this MM use a full CR3?
	jz	short @F	; Jump if not

	mov	RUDPF_NF,offset PGROUP:PHYS2MMLIN_LOOPPDIR ; Jump if PDIR not present
@@:

; Mark XMS bytemap as all allocated

	mov	edi,PXMSBMAP	; ES:EDI ==> XMS bytemap
	mov	ecx,XMSBMAP_LEN ; ECX = length of ...
	mov	al,@XMSB_ALLOC	; Get allocated marker
    rep stos	DGROUP:[edi].LO ; Mark as allocated

	mov	al,0FFh 	; All bits set means terminal entry
	stos	DGROUP:[edi].LO ; Mark as terminal

;;; ; Mark available XMS bytemap entries
;;;
;;;	    mov     gs,SEL_4GB	    ; Get AGROUP data selector
;;;	    assume  gs:AGROUP	    ; Tell the assembler about it
;;;
;;;	    mov     ecx,XMSMEM_CNT  ; Get # active entries
;;;	    jecxz   INIT_PROT_DONEXMS ; Jump if none
;;;	    xor     esi,esi	    ; Initialize index into table
;;; INIT_PROT_NEXTXMS:
;;;	    push    ecx 	    ; Save for a moment
;;;
;;;	    mov     ecx,XMSMEM[esi].XMSMEM_LEN ; Get the block's length in 1KB
;;;	    mov     edi,XMSMEM[esi].XMSMEM_PA ; ...	  physical address
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
;;;	    shr     edi,10-0	    ; Convert from bytes to 1KB
;;;	    add     edi,PXMSBMAP    ; Plus start of XMS bytemap
;;;
;;;	    mov     al,00h	    ; No bits set means available
;;;	rep stos    DGROUP:[edi].LO ; Mark as available
;;;
;;;	    pop     ecx 	    ; Restore
;;;
;;;	    add     esi,type XMSMEM_STR ; Skip to next entry
;;;
;;;	    loop    INIT_PROT_NEXTXMS ; Jump if more entries
;;; INIT_PROT_DONEXMS:
	REGREST <gs,es,ds>	; Restore
	assume	ds:nothing,es:nothing,gs:nothing ; Tell the assembler about it
	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INIT_PROT endp			; End INIT_PROT procedure
	FPPROC	REST_PROT -- PM Uninitialization Code
	assume	ds:nothing,es:AGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

PM uninitialization code

|

	pushad			; Save all EGP registers
	REGSAVE <ds>		; Save registers

	SETDATA ds		; Set data selector into DS
	assume	ds:DGROUP	; Tell the assembler about it

; If we allocated backup memory for the stack, de-allocate it now

	mov	eax,LaSTKMEM	; Get the linear address (0=none)

	and	eax,eax 	; Izit allcocated?
	jz	short REST_PROT0 ; Jump if not

	push	4*1024		; Pass byte length
	push	eax		; Pass starting linear address
	call	DEALLOCMEM	; Deallocate the memory
	jnc	short @F	; Jump if no error

	SWATMAC ERR		; Call our debugger
@@:

; Restore the original PTE so we can do this again

	mov	eax,STKPTE	; Get the orginal PTE
	mov	ebx,LaSTKPTE	; Get the linear address in the PTEs
	mov	AGROUP:[ebx].EDD,eax ; Restore the original value
REST_PROT0:

; Establish addressibility to IDT

	sub	esp,size DTR_STR ; Make room on stack
	SIDTD	[esp].EDF	; Save IDTR on stack
	mov	ebx,[esp].DTR_BASE ; ES:EBX ==> IDT
	add	esp,size DTR_STR ; Strip

; Tell the loader that we're about to change the IDT

	push	@GXCB_CHGIDT	; Pass function code to change IDT
	call	GXTHDR.GXTHDR_CBFVEC ; Request callback services
				; Return with EAX = return code (0 = OK)

IDT	equ	<AGROUP:[ebx+edx*(type IDT_STR)]>

	xor	edx,edx 	; Initialize index into tables
	mov	ecx,256 	; # interrupts
REST_PROT_NEXT:
	test	DB2_FLAG,@DB2_NODEBUG ; Disable hooking INTs 01h and 03h?
	jz	short @F	; Jump if not

	cmp	edx,01h 	; Izit INT 01h?
	je	short REST_PROT_LOOP ; Jump if so

	cmp	edx,03h 	; Izit INT 03h?
	je	short REST_PROT_LOOP ; Jump if so
@@:
	test	DB2_FLAG,@DB2_NONMI ; Disable hooking INT 02h?
	jz	short @F	; Jump if not

	cmp	edx,02h 	; Izit INT 02h?
	je	short REST_PROT_LOOP ; Jump if so
@@:
	test	DB2_FLAG,@DB2_NOKEYB ; Disable hooking INT 09h?
	jz	short @F	; Jump if not

	cmp	edx,09h 	; Izit INT 09h?
	je	short REST_PROT_LOOP ; Jump if so
@@:
	lea	edi,[edx*2]	; EDI = EDX*2 to add to EDX*4 to get EDX*6

	mov	ax,OLDINT_FVEC.FSEL[edx*4+edi] ; Get old selector
	mov	IDT.IDT_SELECT,ax ; Restore

	mov	eax,OLDINT_FVEC.FOFF[edx*4+edi] ; Get old offset
	mov	IDT.IDT_OFFLO,ax ; Restore
	shr	eax,16		; Shift to low-order
	mov	IDT.IDT_OFFHI,ax ; Restore

	mov	al,OLDINT_ARB[edx*(type OLDINT_ARB)] ; Get old A/R byte
	mov	IDT.IDT_ACCESS,al ; Restore
REST_PROT_LOOP:
	inc	edx		; Skip to next interrupt

	loop	REST_PROT_NEXT	; Jump if more interrupts

; Tell the loader that we're finished changing the IDT

	push	@GXCB_CHGIDTZ	; Pass function code to end change of IDT
	call	GXTHDR.GXTHDR_CBFVEC ; Request callback services
				; Return with EAX = return code (0 = OK)

; If VME is supported and enabled, restore the original values.
; We're assuming that the VME state doesn't change from INIT_PROT time.

	test	CPUFET_FLAG,mask $CPUFET_VME ; Izit supported?
	jz	short REST_PROT1 ; Jump if not

	MOVSPR	edx,cr4 	; Get CPU extensions register

	test	edx,mask $VME	; Izit enabled?
	jz	short REST_PROT1 ; Jump if not

	lea	esi,ORGSIRB	; DGROUP:ESI ==> original SIRB table
	mov	edi,LaIOBIT	; AGROUP:EDI ==> I/O bit permission map

	lea	edi,[edi-256/8] ; Less size of SIRB table
	mov	ecx,256/8	; Get # bytes in table
    rep movs	AGROUP:[edi].LO,ORGSIRB[esi] ; Restore
REST_PROT1:
	REGREST <ds>		; Restore
	assume	ds:nothing	; Tell the assembler about it
	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

REST_PROT endp			; End REST_PROT procedure
	NPPROC	PHYS2MMLIN -- Physical To MM-Linear
	assume	ds:nothing,es:nothing,fs:nothing,gs:AGROUP,ss:nothing
COMMENT|

Translate physical address to MM-linear address.

On exit:

CF	=	0 if we found it
	=	1 otherwise

|

P2MML_STR struc

	dd	?		; Caller's EBP
	dd	?		; ...	   EIP
P2MML_PHYS dd	?		; Physical address to translate
P2MML_CR3 dd	?		; MM's CR3
P2MML_MIN dd	?		; Minimum acceptable linear address

P2MML_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

	REGSAVE <ebx,ecx,esi,es> ; Save registers

	mov	eax,cr0 	; Get register with Paging bit

	test	eax,mask $PG	; Is paging enabled?
	jnz	short PHYS2MMLIN_PAGE ; Jump if so

	mov	esi,[ebp].P2MML_CR3 ; AGROUP:ESI ==> PDEs
	mov	ecx,1024	; Get # PDEs in CR3 table
	cld			; String ops forwardly
PHYS2MMLIN_NEXTPDE1:
	lods	AGROUP:[esi].EDD ; Get next PDE

	test	eax,mask $PTE_P ; Izit Present?
	jz	short PHYS2MMLIN_LOOPPDE1 ; Jump if not

	REGSAVE <ecx,edx,esi>	; Save for a moment

	mov	ecx,1024	; Get # PTEs in PDE table
	and	eax,@PTE_FRM	; Isolate the frame
	mov	esi,eax 	; AGROUP:ESI ==> PTEs
	mov	edx,eax 	; Save as base address
PHYS2MMLIN_NEXTPTE1:
	lods	AGROUP:[esi].EDD ; Get next PDE

	test	eax,mask $PTE_P ; Izit Present?
	jz	short PHYS2MMLIN_LOOPPTE1 ; Jump if not

	and	eax,@PTE_FRM	; Isolate the frame

	cmp	eax,[ebp].P2MML_PHYS ; Izit the same physical address?
	jne	short PHYS2MMLIN_LOOPPTE1 ; Jump if not

	lea	eax,[esi-4]	; Get offset in PTE table
	sub	eax,edx 	; Less base address
	shl	eax,(12-2)-0	; Convert from 4KB in dwords to bytes

	stc			; Mark as done

	jmp	short PHYS2MMLIN_DONE1 ; Join common done code


PHYS2MMLIN_LOOPPTE1:
	loop	PHYS2MMLIN_NEXTPTE1 ; Go around again

	clc			; Mark as not done
PHYS2MMLIN_DONE1:
	REGREST <esi,edx,ecx>	; Restore
	jnc	short PHYS2MMLIN_LOOPPDE1 ; Join common loop code

	sub	esi,4		; Get offset in PDE table
	sub	esi,[ebp].P2MML_CR3 ; Less base address
	shl	esi,(22-2)-0	; Convert from 4MB in dwords to bytes
	add	eax,esi 	; Add to get physical (MM-linear) address

	jmp	PHYS2MMLIN_EXIT ; Join common exit code


PHYS2MMLIN_LOOPPDE1:
	loop	PHYS2MMLIN_NEXTPDE1 ; Go around again

	mov	eax,-1		; Mark as not found

	jmp	PHYS2MMLIN_EXIT ; Join common exit code


PHYS2MMLIN_PAGE:
	mov	es,GXTHDR.GXTHDR_SELCR3 ; Get selector for CR3
	assume	es:nothing	; Tell the assembler about it

@P2MML_LIN equ	-4*1024*1024	; Use this linear address (/4MB)

	push	es:[@P2MML_LIN shr ($LA_DIR-2)].EDD ; Save current value

	mov	eax,[ebp].P2MML_CR3 ; Get the MM's CR3
	or	eax,@PTE_URP	; Mark as User/Read-write/Present
	mov	es:[@P2MML_LIN shr ($LA_DIR-2)],eax ; Put into place

; Flush the TLB

	mov	eax,cr3 	; Get current value
	mov	cr3,eax 	; Flush it

; Save the original Page Fault handler and install our own.

	sub	esp,size DTR_STR ; Make room for IDTR
	SIDTD	[esp].EDF	; Save on the stack
	mov	ebx,[esp].DTR_BASE ; Get base address
	add	esp,size DTR_STR ; Strip from stack

	push	AGROUP:[ebx+0Eh*(type IDT_STR)].EDQHI ; Save high-order dword
	push	AGROUP:[ebx+0Eh*(type IDT_STR)].EDQLO ; ...
	push	ebx		; Save offset in AGROUP

	mov	AGROUP:[ebx+0Eh*(type IDT_STR)].IDT_SELECT,cs ; Save selector
	lea	eax,RUD_INT0E	; Get offset of our handler
	mov	AGROUP:[ebx+0Eh*(type IDT_STR)].IDT_OFFLO,ax ; ... offset
	shr	eax,16		; Shift to low-order
	mov	AGROUP:[ebx+0Eh*(type IDT_STR)].IDT_OFFHI,ax ; ... offset
	mov	AGROUP:[ebx+0Eh*(type IDT_STR)].IDT_ACCESS,CPL0_INTR3 ; ... A/R

	mov	esi,@P2MML_LIN	; Get linear address of the PTEs

	cld			; String ops forwardly
PHYS2MMLIN_NEXT:
	lods	AGROUP:[esi].EDD ; Get next PTE

	test	eax,mask $PTE_P ; Izit Present?
	jz	short PHYS2MMLIN_LOOPPTE ; Jump if not

	and	eax,@PTE_FRM	; Isolate the frame

	cmp	eax,[ebp].P2MML_PHYS ; Izit the same physical address?
	je	short PHYS2MMLIN_FOUND ; Jump if so
PHYS2MMLIN_LOOPPTE:
	cmp	esi,@P2MML_LIN+4*1024*1024 ; Izit over?
	jne	short PHYS2MMLIN_NEXT ; Jump if not
PHYS2MMLIN_NOTFOUND:
	mov	eax,-1		; Mark as not found

	jmp	short PHYS2MMLIN_DONE ; Join common done code


PHYS2MMLIN_LOOPPDIR:
	add	esi,4*1024	; Skip to next PDIR

	jmp	short PHYS2MMLIN_LOOPPTE ; Go around again


PHYS2MMLIN_FOUND:
	mov	eax,esi 	; Copy next offset
	sub	eax,@P2MML_LIN+4 ; Convert to origin-0
	shl	eax,(12-2)-0	; Convert from 4KB in dwords to bytes

	cmp	eax,[ebp].P2MML_MIN ; Izit below minimum acceptable?
	jb	short PHYS2MMLIN_LOOPPTE ; Jump if so (false positive)
PHYS2MMLIN_DONE:

; Restore the previous Page fault handler

	pop	ebx		; Restore offset in AGROUP
	pop	AGROUP:[ebx+0Eh*(type IDT_STR)].EDQLO ; Restore low-order dword
	pop	AGROUP:[ebx+0Eh*(type IDT_STR)].EDQHI ; ...	 high-order ...

; Restore previous PDIR

	pop	es:[@P2MML_LIN shr ($LA_DIR-2)].EDD ; Restore PDIR

; Flush the TLB

	mov	ebx,cr3 	; Get current value
	mov	cr3,ebx 	; Flush it
PHYS2MMLIN_EXIT:
	cmp	eax,-1		; Did we find it?
	cmc			; CF=0 if found, CF=1 if not

	REGREST <es,esi,ecx,ebx> ; Restore
	assume	es:nothing	; Tell the assembler about it

	pop	ebp		; Restore

	ret	4+4+4		; Return to caller, popping arguments

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PHYS2MMLIN endp 		; End PHYS2MMLIN procedure
	FPPROC	RUD_INT0E -- INTRUDE Page Fault Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

INTRUDE Page Fault handler

|

	add	esp,4		; Strip off error code

RUDPF_STR struc

	dd	?		; Caller's BP
RUDPF_EIP dd	?		; ...	   EIP
RUDPF_CS  dw	?,?		; ...	   CS w/filler
RUDPF_EFL dd	?		; ...	   EFL

RUDPF_STR ends

	push	ebp		; Prepare to address the stack
	mov	ebp,esp 	; Hello, Mr. Stack

COMMENT|

In an earlier incarnation of this code, I skipped this PDIR and
continued on with the next one on the theory that the MM might have
non-contiguous present PDIRs.  Then I found one MM which overlaps the
GDT in the 4KB page used by CR3 which then looped through what we
thought were PDIRs but were really GDT entries.  The real problem was
that when we referenced a PDIR, the CPU set the accessed bit in the
PDIR entry which had the effect of changing the base address of some
GDT entries!  Now we take care to distinguish between those MMs which
have a full CR3 (via @DEV_FCR3) which also implies that they might
have some not-present PDIRs between the start and the linear addresses
we're looking for.

|

	REGSAVE <eax,ds>	; Save for a moment

	SETDATA ds		; Get DGROUP data selector
	assume	ds:DGROUP	; Tell the assembler about it

	mov	eax,RUDPF_NF	; Get offset of Not Found return point
	mov	[ebp].RUDPF_EIP,eax ; Jump if PDIR not present

	REGREST <ds,eax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	pop	ebp		; Restore

	iretd			; Return to caller (PM only)

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

RUD_INT0E endp			; End RUD_INT0E procedure

PROG	ends			; End PROG segment


XDATA	segment use16 dword public 'xdata' ; Start XDATA segment
	assume	ds:XGROUP

	public	@DPMI_1ST_XDATA
@DPMI_1ST_XDATA label byte	; Mark module start in .MAP file

; Note that this data is not resident with REST_REAL

	public	DDS
DDS	DDS_STR <>		; DMA Descriptor Structure

	public	ARGPTR,DPFEPTR
ARGPTR	dd	?		; Seg:Off to arguments
DPFEPTR dd	?		; Seg:Off to d:\path\filename.ext

	public	MAPSEG_NXT
MAPSEG_NXT dw	seg ZGROUP	; Next available segment

	public	MSG_IREAL_NOXMS,MSG_IREAL_NOUMB
MSG_IREAL_NOXMS db 'ออ> ',@FILENAME,' -- No XMS handler, quitting.',CR,LF
@MSG_IREAL_NOXMS equ $-MSG_IREAL_NOXMS
	db	0
MSG_IREAL_NOUMB db 'ออ> ',@FILENAME,' -- No UMB large enough, quitting.',CR,LF
@MSG_IREAL_NOUMB equ $-MSG_IREAL_NOUMB
	db	0

;;;	    public  MSG_IREAL_NOMOD
;;; MSG_IREAL_NOMOD db 'ออ> ',@FILENAME,' -- No XMB large enough to re-allocate down.',CR,LF
;;; @MSG_IREAL_NOMOD equ $-MSG_IREAL_NOMOD
;;;	    db	    0
;;;
XDATA	ends			; End XDATA segment


XCODE	segment use16 para public 'xcode' ; Start XCODE segment
	assume	cs:XGROUP,ds:XGROUP

	public	@DPMI_1ST_XCODE
@DPMI_1ST_XCODE:		; Mark module start in .MAP file

@HOOK_VMINTS equ <06,0D,21,2F,@PMH_INT> ; Hook these INTs in VM

	extrn	CHECK_ARGS:near

	public	XMSDRV_VEC
XMSDRV_VEC dd	?		; Seg:Off of XMS driver entry point

	public	XXUMB,XXUMB_METH
XXUMB	dw	?		; Segment of UMB
XXUMB_METH db	?		; UMB allocation method (see @XXUMB_xxx equates)
@XXUMB_XMS equ	0		; UMB allocated via XMS
@XXUMB_DOS equ	1		; ...		    DOS

	public	MACPARA,MACLINK,MACSTR
MACPARA dw	?		; # paras needed to go resident
MACLINK dw	0		; MAC link state
MACSTR	dw	?		; MAC allocation strategy

	public	XMS_QRYXMB,XMS_GETXMB,XMS_MODXMB
XMS_QRYXMB db	@XMS_QRYXMB	; Function code to query XMS memory
XMS_GETXMB db	@XMS_GETXMB	; ...		   allocate ...
XMS_MODXMB db	@XMS_MODXMB	; ...		   re-allocate ...

	FPPROC	INIT_REAL -- RM Initialization Code
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

RM initialization code

On entry:

DS:DX	==>	"d:\path\filename.ext [arguments]",0
DS:SI	==>	"[arguments]",0

|

	pushad			; Save all EGP registers
	REGSAVE <ds,es,fs,gs>	; ...  segment ...

	mov	ax,seg XGROUP	; Get segment of XGROUP
	mov	es,ax		; Address it
	assume	es:XGROUP	; Tell the assembler about it

	mov	ax,seg PGROUP	; Get segment of PGROUP
	mov	fs,ax		; Address it
	assume	fs:PGROUP	; Tell the assembler about it

	mov	ax,seg DGROUP	; Get segment of DGROUP
	mov	gs,ax		; Address it
	assume	gs:DGROUP	; Tell the assembler about it

	mov	ARGPTR.VSEG,ds	; Save for later use
	mov	ARGPTR.VOFF,si	; ...

	mov	DPFEPTR.VSEG,ds ; Save for later use
	mov	DPFEPTR.VOFF,dx ; ...

	mov	ax,seg DGROUP	; Get segment of DGROUP
	mov	ds,ax		; Address it
	assume	ds:DGROUP	; Tell the assembler about it

; Save DOS version #

	DOSCALL @DOSVER 	; Return with
				; AL=major
				; AH=minor
				; BX=CX=0
	xchg	al,ah		; Swap to comparison order
	mov	DOSVER,ax	; Save for later use

; Check on NDP installed

	int	11h		; Get equipment flags

	test	ax,mask $I11_NDP ; Is an NDP installed?
	jz	short @F	; Jump if not

	or	LCL_FLAG,@LCL_NDPIN ; Mark as installed
@@:

; Get the pointer to the InDOS flag and save it as a linear address

	DOSCALL @DOSPTR 	; Return ES:BX ==> DOS call level byte (internal)
	assume	es:nothing	; Tell the assembler about it

	xor	eax,eax 	; Zero to use as dword
	mov	ax,es		; Copy the segment
	shl	eax,4-0 	; Convert from paras to bytes
	movzx	ebx,bx		; Zero to use as dword
	add	eax,ebx 	; Add to get the linear address
	mov	LaINDOS,eax	; Save for later use

; Get linear address of 1st MAC entry

	DOSCALL @GETLST 	; Return with ES:BX ==> list of lists ptr
	assume	es:nothing	; Tell the assembler about it

	mov	ax,es:[bx-2]	; Get segment of MAC entry pointer

	mov	P1ST_MAC.VSEG,ax ; First MAC entry
;;;;;;; mov	P1ST_MAC.VOFF,0

; Get maximum physical address

	mov	eax,GXTHDR.GXTHDR_PHYSIZE ; Get top of physical memory in 1KB
	shl	eax,10-0	; Convert from 1KB to bytes
	mov	PHYSIZE,eax	; Save for later use

; See if there's a debugging host present

	test	GXTHDR.GXTHDR_ATTR,@GXTHDR_PSWAT ; Izit present?
	jz	short @F	; Jump if not

	or	LCL_FLAG,@LCL_PSWAT ; Mark as present
@@:

; Check for CPUID features

	call	CHECK_P5	; Set CPUFET_FLAG

	call	CHECK_ARGS	; Check on arguments
	jc	near ptr INIT_REAL_ERRCOM ; Jump if something went wrong

	mov	ax,seg PGROUP	; Get segment of GXTHDR
	mov	ds,ax		; Address it
	assume	ds:PGROUP	; Tell the assembler about it

;;;; Add in the base values for REST_REAL source and destin offsets
;;;;;;;
;;;;;;; xor	eax,eax 	; Zero to use as dword
;;;;;;; mov	ax,seg XGROUP	; Get segment of RRSRC
;;;;;;; sub	ax,seg PGROUP	; Less segment of start of file
;;;;;;; shl	eax,4-0 	; Convert from paras to bytes
;;;;;;;
;;;;;;; add	GXTHDR.GXTHDR_RRSRC,eax ; Add in to RRSRC
;;;;;;;
	mov	GXTHDR.GXTHDR_RM2PM_FVEC.FOFF,offset PGROUP:RM2PM_ENTRY ; ...

; Copy values to YGROUP

	mov	ax,seg YGROUP	; Get the source segment
	mov	es,ax		; Address it
	assume	es:YGROUP	; Tell the assembler about it

	lea	si,GXTHDR	; DS:SI ==> destin
	lea	di,YY_GXTHDR	; ES:DI ==> destin
	mov	cx,type GXTHDR_STR ; CX = # bytes to copy
    rep movs	YY_GXTHDR[di].LO,GXTHDR[di].LO ; Copy to YGROUP

; Allocate a UMB for our DPMI VM2PM handler

	mov	ax,seg XGROUP	; Get segment of XGROUP
	mov	ds,ax		; Address it
	assume	ds:XGROUP	; Tell the assembler about it

; See if there's an XMS handler present

	call	CHECK_XMS	; See if it's present
	jc	near ptr INIT_REAL_ERR1 ; Jump if not

	mov	dx,YYLEN	; Get length of UMB in bytes
	add	dx,HPDASTK_SIZ	; Plus the size of the stack
	add	dx,16-1 	; Round up to para boundary
	shr	dx,4-0		; Convert from bytes to paras
	mov	MACPARA,dx	; Save for later use

	test	LCL_FLAG,@LCL_NOUMB ; Are we to skip UMBs?
	jnz	near ptr INIT_REAL_ERR2 ; Jump if so

	mov	XXUMB_METH,@XXUMB_XMS ; Mark as allocated via XMS
	mov	ah,@XMS_GETUMB	; Function code to allocate a UMB of DX paras
	call	XMSDRV_VEC	; Request XMS service
				; Return with AX = 1 iff successful
				; ...	      BX = segment of UMB
	cmp	ax,1		; Did it work?
	je	short INIT_REAL_UMB ; Jump if so

; Attempt to allocate a UMB using the 58xx DOS calls

; First we need to link the high and low chains

	mov	al,@MACALG_GETLINK ; Function code to return the link state
	DOSCALL @MACALG 	; Return the link state in AX
	jc	near ptr INIT_REAL_ERR2 ; Jump if not supported

	mov	MACLINK.LO,al	; Save the link state

	mov	bx,@MACALG_LINK ; Link the high and low chains
	mov	al,@MACALG_SETLINK ; Function code to set the link state
	DOSCALL @MACALG 	; Return the link state in AX
	jc	near ptr INIT_REAL_ERR2 ; Jump if not supported

; Next, set the allocation strategy to first fit, high only

	mov	al,@MACALG_GETSTR ; Function code to get strategy
	DOSCALL @MACALG 	; Return strategy in AX
	jc	near ptr INIT_REAL_ERR2LINK ; Jump if not supported

	mov	MACSTR,ax	; Save for a moment

; Set strategy to first fit high only

	mov	bx,@MACALG_FFHI ; Function code for First fit high only
	mov	al,@MACALG_SETSTR ; Function code to set strategy
	DOSCALL @MACALG 	; Set strategy to BX
	jc	near ptr INIT_REAL_ERR2LINK ; Jump if not supported

	mov	bx,MACPARA	; Get # paras needed
	DOSCALL @GETMEM 	; Return UMB segment in AX
	jc	near ptr INIT_REAL_ERR2STR ; Jump if @GETMEM failed

	mov	XXUMB,ax	; Save for later use

; Restore the original allocation strategy

	mov	bx,MACSTR	; Get the original allocation strategy
	mov	al,@MACALG_SETSTR ; Function code to set strategy
	DOSCALL @MACALG 	; Set strategy to BX
;;;;;;; jc	short ???	; Ignore error return

; Restore the original link state

	mov	bx,MACLINK	; Get the original link state
	mov	al,@MACALG_SETLINK ; Function code to set the link state
	DOSCALL @MACALG 	; Return the link state in AX
;;;;;;; jc	short ???	; Ignore error return

	mov	bx,XXUMB	; Copy UMB segment
INIT_REAL_DOS:
	mov	XXUMB_METH,@XXUMB_DOS ; Mark as allocated via DOS
INIT_REAL_UMB:
	mov	XXUMB,bx	; Save for later use

	mov	ax,bx		; Copy program segment
	mov	GXTHDR.GXTHDR_PRGSEG_CUR,ax ; Save as program segment
	add	ax,MACPARA	; Plus resident size
	mov	GXTHDR.GXTHDR_PRGSEG_NXT,ax ; Save as upper limit segment

	mov	ax,seg DGROUP	; Get the segment of HIMEM_CS/VM2PM_VEC
	mov	ds,ax		; Address it
	assume	ds:DGROUP	; Tell the assembler about it

	mov	HIMEM_CS,bx	; Save for later use
	mov	INT31A_HIMEM_CS,bx ; ...
%	mov	INT&@PMH_INT&_HIMEM_CS,bx ; ...
	mov	VM2PM_VEC.VSEG,bx ; ...

	movzx	eax,bx		; Copy the segment
	shl	eax,4-0 	; Convert from paras to bytes
	mov	HIMEM_La,eax	; Save for later use

; Copy the data there

;;;;;;; mov	es,HIMEM_CS	; Get the destin segment
	mov	es,bx		; Get the destin segment
	assume	es:nothing	; Tell the assembler about it
	xor	di,di		; ES:DI ==> destin

	push	ds		; Save for a moment

	mov	ax,seg YGROUP	; Get the source segment
	mov	ds,ax		; Address it
	assume	ds:YGROUP	; Tell the assembler about it

	mov	al,XXUMB_METH	; Get the UMB allocation method
	mov	YYUMB_METH,al	; Save in YGROUP

	xor	si,si		; DS:SI ==> source
	mov	cx,YYLEN	; CX = length in bytes
    rep movs	es:[di].LO,YYSTART[si] ; Copy to UMB

	pop	ds		; Restore
	assume	ds:DGROUP	; Tell the assembler about it

; Hook VM INTs in the UMB

	REGSAVE <bx,ds,es>	; Save for a moment

	mov	ds,bx		; Address the UMB
	assume	ds:YGROUP	; Tell the assembler about it

;;; %	    irp     XX,<21,2F,@PMI_INT,@PMF_INT,@PMM_INT,@PMH_INT>
%	irp	XX,<@HOOK_VMINTS>

%	mov	al,0&XX&h	; Interrupt #
	DOSCALL @GETINT 	; Return with ES:BX ==> handler
	assume	es:nothing	; Tell the assembler about it

%	mov	OLDINT&XX&_VEC.VOFF,bx ; Save for later use
%	mov	OLDINT&XX&_VEC.VSEG,es ; ...

%	mov	al,0&XX&h	; Interrupt #
%	DOSCALL @SETINT,LCL_INT&XX ; Hook it

	endm			; IRP

	REGREST <es,ds,bx>	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	mov	ax,seg XGROUP	; Get the segment for RR_XMSMEM
	mov	es,ax		; Address it
	assume	es:XGROUP	; Tell the assembler about it

;;; ; Allocate all XMS memory
;;;
;;;	    mov     cx,@XMSMEM_LEN  ; Get maximum # entries in our table
;;;	    xor     si,si	    ; Initialize index into table
;;; INIT_REAL_NEXTXMS:
;;;
;;; ; Query largest XMS block
;;;
;;;	    push    ecx 	    ; Save for a moment
;;;
;;;	    xor     eax,eax	    ; Zero to use as dword
;;;	    mov     ah,XMS_QRYXMB   ; Function code to query XMS memory
;;;	    call    XMSDRV_VEC	    ; Request XMS service
;;;				    ; Return with eAX = size of largest block (in 1KB)
;;;				    ; ...	  eDX = total amount of free ...
;;;				    ; ...	  ECX = highest ending address
;;;				    ; ...	  BL  = error code
;;;	    pop     ecx 	    ; Restore
;;;
;;;	    cmp     eax,0	    ; Any memory available?
;;;	    je	    short INIT_REAL_NOXMS ; Jump if not
;;;
;;;	    mov     edx,eax	    ; Copy size of largest block
;;;	    mov     XMSMEM[si].XMSMEM_LEN,eax ; Save for later use
;;;	    mov     ah,XMS_GETXMB   ; Function code to allocate XMS memory
;;;	    call    XMSDRV_VEC	    ; Request XMS service
;;;				    ; Return with AX = 1 iff successful
;;;				    ; ...	  DX = handle
;;;				    ; ...	  BL  = error code
;;;	    cmp     ax,1	    ; Did it work?
;;;	    jne     short INIT_REAL_NOXMS ; Jump if not
;;;
;;;	    mov     XMSMEM[si].XMSMEM_HNDL,dx ; Save for later use
;;;	    mov     RR_XMSMEM[si].XMSMEM_HNDL,dx ; ...
;;;
;;; ; Lock the block to get its linear address
;;;
;;;	    mov     ah,@XMS_LCKXMB  ; Function code to lock a block
;;;	    call    XMSDRV_VEC	    ; Request XMS service
;;;				    ; Return with AX = 1 iff successful
;;;				    ; ...	  DX:BX ==> linear address
;;;	    mov     ax,dx	    ; Copy high-order word
;;;	    shl     eax,16	    ; Shift to high-order
;;;	    mov     ax,bx	    ; Copy low-order word
;;;
;;; ; Translate this address to a physical one if the MM returns a linear address
;;;
;;;	    test    GXTHDR.GXTHDR_ATTR,@GXTHDR_VDS ; Duzit need translation?
;;;	    jz	    short INIT_REAL_NOVDS ; Jump if not
;;;
;;;	    mov     DDS.DDS_FVEC.FOFF,eax ; Save as offset
;;;	    mov     DDS.DDS_FVEC.FSEL,0   ; ...      segment
;;;	    mov     eax,XMSMEM[si].XMSMEM_LEN ; Save for later use
;;;	    mov     DDS.DDS_SIZE,eax ; Save as size
;;;
;;;	    xor     dx,dx	    ; No flags
;;;	    lea     di,DDS	    ; ES:DI ==> DDS
;;;	    VDSCALL @VDS_LOCK	    ; Request VDS service
;;; ;;;;;;; jc	    short ???	    ; Jump on error *FIXME*
;;;
;;;	    mov     eax,DDS.DDS_POFF ; Get the physical address
;;; INIT_REAL_NOVDS:
;;;	    mov     XMSMEM[si].XMSMEM_PA,eax ; Save for later use
;;;
;;;	    add     si,type XMSMEM_STR ; Skip to next entry
;;;
;;;	    inc     XMSMEM_CNT	    ; Count in another entry
;;;	    inc     RR_XMSMEM_CNT   ; ...
;;;
;;; ;;;;;;; loop    INIT_REAL_NEXTXMS ; Jump if more entries
;;;	    dec     cx		    ; Count out another entry
;;;	    jnz     INIT_REAL_NEXTXMS ; Jump if more entries
;;; INIT_REAL_NOXMS:
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
; Make room for uninitialized tables

	mov	eax,GXTHDR.GXTHDR_DLEN ; Get length of initialized PM data
	add	eax,4-1 	; Round up to dword
	and	eax,not (4-1)	; ...boundary

; Make room for XMS bytemap

@PHYS_FUDGE equ 16*1024*1024	; Some MM's (QEMM) use quite a bit of linear address

	mov	PXMSBMAP,eax	; Save as start of XMS bytemap
	mov	ebx,PHYSIZE	; Get top of physical memory
;;;	add	ebx,@PHYS_FUDGE ; Plus some fudge factor
	add	ebx,1024-1	; Round up to 1KB
;;;;;;; and	ebx,not (1024-1) ; ...boundary
	shr	ebx,10-0	; Convert from bytes to 1KB
	mov	XMSBMAP_LEN,ebx ; Save as length of XMS bytemap
	inc	ebx		; Plus one for terminal entry
	add	eax,ebx 	; Skip over it

; Make room for TSSs

	add	eax,4-1 	; Round up to dword
	and	eax,not (4-1)	; ...boundary

	mov	PVMTSS,eax	; Save as start of VM TSS in DGROUP
	mov	PCURTSS,eax	; ...		   current ...
	add	eax,@TSS_MAX*(type DPTSS_STR) ; Skip over it
	add	eax,256/8	; Plus size of SIRB
	mov	PIOBIT,eax	; Save as offset in DGROUP of I/O bit permission map
	add	eax,8*1024+1	; Plus size of I/O bit permission map

;;; ; Make room for local copy of the PL0 stack
;;;
;;;	    add     eax,4-1	    ; Round up to dword
;;;	    and     eax,not (4-1)   ; ...boundary
;;;	    mov     PLCL_PL0STK,eax ; Save as offset in DGROUP of local PL0 stack
;;;
;;; @LCL_PL0STK_SIZ equ  8*1024     ; Size of the local stack
;;;
;;;	    add     eax,@LCL_PL0STK_SIZ ; Plus size of the local stack
;;;	    mov     PLCL_PL0STKZ,eax ; Save as offset in DGROUP of end of local stack
;;;	    mov     PLCL_PL0CUR,eax  ; ...		    current ...
;;;	    add     eax,4	    ; Make room for the trailing count (of zero)
;;;
; Make room for global CR3

	mov	OffCR3,eax	; Save as offset in DGROUP of CR3
	add	eax,2*4*1024	; Skip over it (room for alignment)

; Make room for scratch PTE for LSM_SET_PDE if no swapfile

	test	VMM_FLAG,@VMM_BSGLOBAL ; Test if swapfile=xxxxx was found
	jnz	short @F	; Jump if so

	mov	OffScrPTE,eax	; Save offset (to be rounded up to 4KB boundary)
	add	eax,4*1024	; Skip over it
@@:

; Make room for Backing Store Cache

	add	eax,4-1 	; Round up to dword
	and	eax,not (4-1)	; ...boundary
	mov	PBSCache,eax	; Save as offset in DGROUP of BSC
	add	eax,@BSCSize	; Skip over the BSCache

; Make room for ...












	mov	GXTHDR.GXTHDR_DLEN,eax ; Save as length of PM data
				; including uninitialized data

;;; ; Because the loader needs some XMS memory to load us upstairs,
;;; ; reallocate downwards one of the blocks we just allocated
;;; ; Also, the loader hasn't allocated XMS memory for itself as yet,
;;; ; so we account for that as a fudge factor
;;;
;;; @XMS_FUDGE equ  64		    ; # kilobytes to allow for loader
;;;
;;;	    mov     ebx,GXTHDR.GXTHDR_CLEN ; Get the code size
;;;	    add     ebx,GXTHDR.GXTHDR_DLEN ; Plus the data size
;;;	    add     ebx,1024-1	    ; Round up to 1KB
;;; ;;;;;;; and     ebx,not (1024-1) ; ...boundary
;;;	    shr     ebx,10-0	    ; Convert from bytes to 1KB
;;;	    add     ebx,@XMS_FUDGE  ; Plus a fudge factor
;;;
;;; ; Find a block of at least this size
;;;
;;;	    mov     cx,RR_XMSMEM_CNT ; Get # active entries
;;;	    xor     si,si	    ; Initialize index into table
;;; @@:
;;;	    cmp     ebx,XMSMEM[si].XMSMEM_LEN ; Izit big enough?
;;;	    jbe     short @F	    ; Jump if so
;;;
;;;	    add     si,type XMSMEM_STR ; Skip to next entry
;;;
;;;	    loop    @B		    ; Jump if more entries
;;;
;;;	    jmp     INIT_REAL_ERR3  ; Join common error code
;;;
;;; @@:
;;;	    sub     ebx,XMSMEM[si].XMSMEM_LEN ; Less the actual length
;;;	    neg     ebx 	    ; Negate to get new length
;;;	    mov     XMSMEM[si].XMSMEM_LEN,ebx ; Save as new length
;;;
;;;	    mov     dx,XMSMEM[si].XMSMEM_HNDL ; Get the handle
;;;
;;; ; Unlock the block so we can re-allocate it
;;;
;;;	    push    ebx 	    ; Save for a moment
;;;
;;;	    mov     ah,@XMS_UNLXMB  ; Function code to unlock an XMS block
;;;	    call    XMSDRV_VEC	    ; Request XMS service
;;;
;;;	    cmp     ax,1	    ; Did it work?
;;;	    je	    short @F	    ; Jump if so
;;;
;;;	    SWATMAC ERR,RM	    ; Call our debugger
;;; @@:
;;;	    pop     ebx 	    ; Restore
;;;
;;; ; Re-allocate the block downwards
;;;
;;;	    mov     ah,XMS_MODXMB   ; Function code to re-allocate a block
;;;	    call    XMSDRV_VEC	    ; Request XMS service
;;;
;;;	    cmp     ax,1	    ; Did it work?
;;;	    je	    short @F	    ; Jump if so
;;;
;;;	    SWATMAC ERR,RM	    ; Call our debugger
;;; @@:
;;;
;;; ; Re-lock the block
;;;
;;;	    mov     ah,@XMS_LCKXMB  ; Function code to lock a block
;;;	    call    XMSDRV_VEC	    ; Request XMS service
;;;				    ; Return with AX = 1 iff successful
;;;				    ; ...	  DX:BX ==> linear address
;;;	    cmp     ax,1	    ; Did it work?
;;;	    je	    short @F	    ; Jump if so
;;;
;;;	    SWATMAC ERR,RM	    ; Call our debugger
;;; @@:








	jmp	INIT_REAL_EXIT	; Join common exit code


	assume	es:nothing	; Tell the assembler about it
INIT_REAL_ERR1:
	mov	bx,@STD_ERR	; Standard error file handle
	mov	cx,@MSG_IREAL_NOXMS ; Length of message
	DOSCALL @WRITF2,MSG_IREAL_NOXMS ; Tell 'em the bad news

	jmp	short INIT_REAL_ERRCOM ; Join common error code


	assume	es:nothing	; Tell the assembler about it
INIT_REAL_ERR2STR:
	mov	bx,MACSTR	; Get the original allocation strategy
	mov	al,@MACALG_SETSTR ; Function code to set strategy
	DOSCALL @MACALG 	; Set strategy to BX
;;;;;;; jc	short ???	; Ignore error return
INIT_REAL_ERR2LINK:
	mov	bx,MACLINK	; Get the original link state
	mov	al,@MACALG_SETLINK ; Function code to set the link state
	DOSCALL @MACALG 	; Return the link state in AX
;;;;;;; jc	short ???	; Ignore error return
INIT_REAL_ERR2:

; No room in high DOS memory
; Go resident in low DOS memory

	mov	bx,GXTHDR.GXTHDR_PRGSEG_CUR ; Get current program segment
	mov	ax,bx		; Copy segment
	add	ax,MACPARA	; Plus resident size

	cmp	ax,GXTHDR.GXTHDR_PRGSEG_NXT ; Izit within range?
	ja	short INIT_REAL_ERR2A ; Jump if not

	mov	ax,MACPARA	; Get # paras needed in TSR memory
	mov	GXTHDR.GXTHDR_NLOWPARA,ax ; Tell the loader about it

	jmp	INIT_REAL_DOS	; Join common code with BX=segment


INIT_REAL_ERR2A:
	mov	bx,@STD_ERR	; Standard error file handle
	mov	cx,@MSG_IREAL_NOUMB ; Length of message
	DOSCALL @WRITF2,MSG_IREAL_NOUMB ; Tell 'em the bad news

	jmp	short INIT_REAL_ERRCOM ; Join common error code


;;;	    assume  ds:nothing	    ; Tell the assembler about it
;;; INIT_REAL_ERR3:
;;;	    mov     ax,seg XGROUP   ; Get segment of MSG_IREAL_xxx
;;;	    mov     ds,ax	    ; Address it
;;;	    assume  ds:XGROUP	    ; Tell the assembler about it
;;;
;;;	    mov     bx,@STD_ERR     ; Standard error file handle
;;;	    mov     cx,@MSG_IREAL_NOMOD ; Length of message
;;;	    DOSCALL @WRITF2,MSG_IREAL_NOMOD ; Tell 'em the bad news
;;;
;;; ;;;;;;; jmp     short INIT_REAL_ERRCOM ; Join common error code
;;;
;;;
	assume	ds:nothing	; Tell the assembler about it
INIT_REAL_ERRCOM:
	mov	ax,seg DGROUP	; Get the segment of HIMEM_CS/VM2PM_VEC
	mov	es,ax		; Address it
	assume	es:DGROUP	; Tell the assembler about it

; Restore YCODE interrupts

	mov	bx,VM2PM_VEC.VSEG ; Get segment (if allocated)

	and	bx,bx		; Izit unallocated?
	jz	short INIT_REAL_ERR4 ; Jump if so

;;; %	    irp     XX,<06,21,2F,@PMI_INT,@PMF_INT,@PMM_INT,@PMH_INT>
%	irp	XX,<@HOOK_VMINTS>

	mov	ds,bx		; Address it
	assume	ds:YGROUP	; Tell the assembler about it

%	cmp	OLDINT&XX&_VEC.EDD,0 ; Izit unspecified?
	je	short @F	; Jump if so

%	lds	dx,OLDINT&XX&_VEC ; DS:DX ==> old handler
	assume	ds:nothing	; Tell the assembler about it

%	mov	al,0&XX&h	; Get interrupt #
	DOSCALL @SETINT 	; Restore the interrupt handler
@@:
	endm			; IRP
INIT_REAL_ERR4:
	mov	ax,seg PGROUP	; Get segment of GXTHDR
	mov	ds,ax		; Address it
	assume	ds:PGROUP	; Tell the assembler about it

	or	GXTHDR.GXTHDR_ATTR,@GXTHDR_RMIE ; Mark as real mode init error

	assume	ds:nothing	; Tell the assembler about it

INIT_REAL_EXIT:
	REGREST <gs,fs,es,ds>	; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it
	assume	fs:nothing,gs:nothing ; Tell the assembler about it
	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

INIT_REAL endp			; End INIT_REAL procedure
	NPPROC	IZIT_CPUID -- Determine Support of CPUID Instruction
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

The test for the CPUID instruction is done by attempting to set the ID
bit in the high-order word of the extended flag dword.	If that's
successful, the CPUID instruction is supported; otherwise, it's not.

On exit:

CF	=	1 if it's supported
	=	0 otherwise

|

	push	bp		; Save to address the stack
	clc			; Assume it's not supported
	pushfd			; Save original flags
	pushfd			; Save temporary flags

IZIT_CPUID_STR struc

IZIT_CPUID_TMPEFL dd ?		; Temporary EFL
IZIT_CPUID_RETEFL dd ?		; Return EFL
	dw	?		; Caller's BP

IZIT_CPUID_STR ends

	mov	bp,sp		; Address the stack
	or	[bp].IZIT_CPUID_TMPEFL,mask $ID ; Set ID bit
	popfd			; Put into effect

	pushfd			; Put back onto the stack to test

	test	[bp].IZIT_CPUID_TMPEFL,mask $ID ; Izit still set?
	jz	short @F	; No, so it's not supported

	or	[bp].IZIT_CPUID_RETEFL,mask $CF ; Indicate it's supported
@@:
	popfd			; Restore temporary flags
	popfd			; Restore original flags
	pop	bp		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

IZIT_CPUID endp 		; End IZIT_CPUID procedure
	NPPROC	CHECK_P5 -- Check On CPU Features
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Get CPU feature bits (especially VME and IOBRK).

On exit:

CPUFET		 Laundered feature bits from CPUID instruction

|

	call	IZIT_CPUID	; Duzit support the CPUID instruction?
	jnc	short CHECK_P5_EXIT ; Jump if not

	REGSAVE <eax,ebx,ecx,edx> ; Save for a moment

	mov	eax,1		; Function code to retrieve feature bits
	CPUID			; Return with EAX = stepping info
				;	      EBX, ECX reserved
				;	      EDX = feature bits
	mov	ebx,eax 	; Copy stepping info
	and	ebx,@CPUSIG_FAM ; Isolate the Family bits
	shr	ebx,$CPUSIG_FAM ; Shift to low-order
	mov	CPUTYPE,bl	; Save for later use

;*********************** INTEL CONFIDENTIAL **************************
; Check for A1 step SL Enhanced 486 CPUs with feature bits.  Note that
; the stepping information in the following comments is under Intel NDA.

	test	edx,@CPUFET_VME ; Any Virtual Mode Extensions supported?
	jz	short CHECK_P5_VMEOK ; Jump if not

; The A1 step says it supports VME, but has some serious bugs which may
; cause misdirection of some interrupts.  Later steppings also have this
; bug, but correctly say they don't support VME.

	mov	ebx,eax 	; Copy stepping info
	and	ebx,@CPUSIG_FAM or @CPUSIG_MOD or @CPUSIG_REV ; Isolate family,
				; model, and stepping in BX

	cmp	bx,0414h	; Izit S series 486DX, A1 step?
	je	short @F	; Jump if so

	cmp	bx,0424h	; Izit S series 486SX, A1 step?
	je	short @F	; Jump if so

	cmp	bx,0434h	; Izit S series 486DX-2, A1 step?
	jne	short CHECK_P5_VMEOK ; Jump if not
@@:
	and	edx,not @CPUFET_VME ; Don't enable Virtual Mode Extensions
CHECK_P5_VMEOK:
;************************ END INTEL CONFIDENTIAL **********************

	mov	CPUFET_FLAG,edx ; Save feature bits for later use

	REGREST <edx,ecx,ebx,eax> ; Restore
CHECK_P5_EXIT:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_P5 endp			; End CHECK_P5 procedure
	NPPROC	CHECK_XMS -- Check On XMS Driver
	assume	ds:XGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Check on XMS driver

On exit:

CF	=	0 if found
	=	1 if not

|

	REGSAVE <ax,bx,dx,es,fs> ; Save registers

	mov	ax,seg YGROUP	; Get segment of YY_XMSDRV_VEC
	mov	fs,ax		; Address it
	assume	fs:YGROUP	; Tell the assembler about it

	mov	ax,4300h	; Function code to check on XMS driver
	int	2Fh		; Request multiplexor service

	cmp	al,80h		; Izit present?
	stc			; Assume not
	jne	short CHECK_XMS_EXIT ; Jump if not

	mov	ax,4310h	; Function code to get driver entry point
	int	2Fh		; Request multiplexor service
	assume	es:nothing	; Tell the assembler about it

	mov	XMSDRV_VEC.VOFF,bx ; Save for later use
	mov	XMSDRV_VEC.VSEG,es ; ...

	mov	fs:YY_XMSDRV_VEC.VOFF,bx ; Save for later use
	mov	fs:YY_XMSDRV_VEC.VSEG,es ; ...

; Check the version #

	mov	ah,@XMS_VERS	; Function code to get version #
	call	XMSDRV_VEC	; Request XMS service
				; Return with AX = version #
				; ...	      DX = debugging version #
	cmp	ax,0300h	; Izit version 3.00 or later?
	jb	short @F	; Jump if not

	mov	XMS_QRYXMB,@XMS_QRY2XMB ; Use new function
	mov	XMS_GETXMB,@XMS_GET2XMB ; ...
	mov	XMS_MODXMB,@XMS_MOD2XMB ; ...
	mov	fs:YY_XMS_QRYXMB,@XMS_QRY2XMB ; Use new function
	mov	fs:YY_XMS_GETXMB,@XMS_GET2XMB ; ...
	mov	fs:YY_XMS_MODXMB,@XMS_MOD2XMB ; ...
@@:
	clc			; Mark as present
CHECK_XMS_EXIT:
	REGREST <fs,es,dx,bx,ax> ; Restore
	assume	es:nothing,fs:nothing ; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_XMS endp			; End CHECK_XMS procedure
	align	16		; Fill with NOPs

XCODE	ends			; End XCODE segment


YCODE	segment use16 para public 'ycode' ; Start YCODE segment
	assume	cs:YGROUP,ds:YGROUP

	public	@DPMI_1ST_YCODE
@DPMI_1ST_YCODE:		; Mark module start in .MAP file

	public	YYSTART
YYSTART label	byte		; Start of UMB code/data

	public	YY_GXTHDR
YY_GXTHDR GXTHDR_STR <> 	; Copy of GXTHDR

;;; %	    irp     XX,<21,2F,@PMI_INT,@PMF_INT,@PMM_INT,@PMH_INT>
%	irp	XX,<@HOOK_VMINTS>
	public	OLDINT&XX&_VEC
% OLDINT&XX&_VEC dd ?		; Save area for old INT 0&XX&h handler
	endm			; IRP

	public	YY_XMSDRV_VEC
YY_XMSDRV_VEC dd ?		; Seg:Off of XMS driver entry point

	public	YY_XMSMEM
YY_XMSMEM XMSMEM_STR @XMSMEM_LEN dup (<>) ; XMS memory struc

	public	YY_DDS
YY_DDS	DDS_STR <>		; DMA Descriptor Structure

	public	YY_XMSMEM_CNT
YY_XMSMEM_CNT dw 0,0		; # active entries (useable as dword)

	public	EXITRCHI
EXITRCHI dw	(@GETRC_RES shl 8) or 0 ; Default return code

	public	MSC_FLAG
MSC_FLAG MSC_REC <>		; Miscellaneous flags

	public	YYUMB_METH
YYUMB_METH db	?		; UMB allocation method (see @XXUMB_xxx equates)

	public	YY_XMS_QRYXMB,YY_XMS_GETXMB,YY_XMS_MODXMB
YY_XMS_QRYXMB db @XMS_QRYXMB	; Function code to query XMS memory
YY_XMS_GETXMB db @XMS_GETXMB	; ...		   allocate ...
YY_XMS_MODXMB db @XMS_MODXMB	; ...		   re-allocate ...


BP_IRET_STR struc

	dw	?		; Caller's BP
BP_IRET_IRET db (type IRET_STR) dup (?) ; ... IRET frame

BP_IRET_STR ends


	FPPROC	REST_REAL -- RM Uninitialization Code
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

RM uninitialization code

|

	REGSAVE <ax,cx,dx,ds>	; Save for a moment

; Restore original interrupt handlers

;;; %	    irp     XX,<21,2F,@PMI_INT,@PMF_INT,@PMM_INT,@PMH_INT>
%	irp	XX,<@HOOK_VMINTS>

%	lds	dx,OLDINT&XX&_VEC ; DS:DX ==> old handler
	assume	ds:nothing	; Tell the assembler about it

%	mov	al,0&XX&h	; Get interrupt #
	DOSCALL @SETINT 	; restore the interrupt handler

	endm			; IRP

; Release the UMB

	cmp	YYUMB_METH,@XXUMB_DOS ; Izit allocated via DOS?
	je	short REST_REAL1 ; Jump if so

	mov	dx,cs		; Get the UMB segment
	mov	ah,@XMS_RELUMB	; Function code to release UMB in DX
	call	YY_XMSDRV_VEC	; Request XNS service

;;;;;;; cmp	ax,1		; Did it work?
;;;;;;; jne	short ???	; Jump if not
;;;;;;;
	jmp	short REST_REAL2 ; Join common code


REST_REAL1:
	push	es		; Save for a moment

	mov	ax,cs		; Get the UMB segment
	mov	es,ax		; Address it
	assume	es:nothing	; Tell the assembler about it

	DOSCALL @RELMEM 	; Release the block at ES:0
;;;;;;; jc	short ???	; Ignore error return

	pop	es		; Restore
	assume	es:nothing	; Tell the assembler about it
REST_REAL2:

; Release the XMBs

	mov	cx,YY_XMSMEM_CNT ; Get # active XMS blocks
	jcxz	REST_REAL_DONEXMS ; Jump if none
	xor	si,si		; Initialize index into table
REST_REAL_NEXTXMS:
	mov	dx,YY_XMSMEM[si].XMSMEM_HNDL ; Get the handle

	and	dx,dx		; Izit already released?
	jz	short REST_REAL_LOOPXMS ; Jump if so

	mov	ah,@XMS_UNLXMB	; Function code to unlock an XMS block
	call	YY_XMSDRV_VEC	; Request XMS service

;;;;;;; cmp	ax,1		; Did it work?
;;;;;;; jne	short REST_REAL_LOOPXMS ; Jump if not
;;;;;;;
	mov	ah,@XMS_RELXMB	; Function code to release an XMS block
	call	YY_XMSDRV_VEC	; Request XMS service

;;;;;;; cmp	ax,1		; Did it work?
;;;;;;; jne	short REST_REAL_LOOPXMS ; Jump if not
.8086
	mov	YY_XMSMEM[si].XMSMEM_HNDL,0 ; Mark as released
.386
REST_REAL_LOOPXMS:
	add	si,type XMSMEM_STR ; Skip to next entry

	loop	REST_REAL_NEXTXMS ; Jump if more XMS blocks to release
REST_REAL_DONEXMS:
	REGREST <ds,dx,cx,ax>	; Restore
	assume	ds:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

REST_REAL endp			; End REST_REAL procedure
	FPPROC	LCL_INT06 -- Local INT 06h Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Local INT 06h handler

|

	call	PushIretFL	; Push FL from IRET frame
;;;;;;; pushf			; Simulate INT
	cli			; ... environment
	call	YY_GXTHDR.GXTHDR_RM2PM_VEC ; Switch from RM to PM
; Note, the return address is on the stack to identify which call this is.
	public	DPMI_RM2PM_VMI06
DPMI_RM2PM_VMI06:
	retf	2		; Return to caller, popping flags

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

LCL_INT06 endp			; End LCL_INT06 procedure
	FPPROC	LCL_INT0D -- Local INT 0Dh Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Local INT 0Dh handler

|

	call	PushIretFL	; Push FL from IRET frame
;;;;;;; pushf			; Simulate INT
	cli			; ... environment
	call	YY_GXTHDR.GXTHDR_RM2PM_VEC ; Switch from RM to PM
; Note, the return address is on the stack to identify which call this is.
	public	DPMI_RM2PM_VMI0D
DPMI_RM2PM_VMI0D:
	retf	2		; Return to caller, popping flags

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

LCL_INT0D endp			; End LCL_INT0D procedure
	FPPROC	LCL_INT21 -- Local INT 21h Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Local INT 21h handler

On entry:

AH	=	function code

|

	pushf			; Save flags

	cmp	ah,@GETRC	; Izit Get Return Code?
	jne	short LCL_INT21_XGETRC ; Jump if not

	btr	MSC_FLAG,$MSC_GETRC ; Should we lie?
	jnc	short LCL_INT21_XGETRC ; Jump if not

	popf			; Restore

	call	PushIretFL	; Push FL from IRET frame
;;;;;;; pushf			; Pass a copy of the current flags
	cli			; Simulate INT environment
	call	OLDINT21_VEC	; Pass the call on down to DOS to zero the field

	mov	ax,EXITRCHI	; Get the return code
.8086
	mov	EXITRCHI,(@GETRC_RES shl 8) or 0 ; Mark as resident for next time
DOT386 p
	retf	2		; Return to caller, popping flags


LCL_INT21_XGETRC:
	popf			; Restore

	jmp	OLDINT21_VEC	; Continue on

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

LCL_INT21 endp			; End LCL_INT21 procedure
	FPPROC	LCL_INT2F -- Local INT 2Fh Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Local INT 2Fh handler

On entry:

AX	=	function code

|

	pushf			; Save flags

	cmp	ax,@DPMI_GPME	; DPMI presence check?
	jne	short LCL_INT2F_XGPME ; Jump if not

	popf			; Restore

	call	PushIretFL	; Push FL from IRET frame
;;;;;;; pushf			; Simulate INT
	cli			; ... environment
	call	YY_GXTHDR.GXTHDR_RM2PM_VEC ; Switch from RM to PM
; Note, the return address is on the stack to identify which call this is.
	public	DPMI_RM2PM_PRES
DPMI_RM2PM_PRES:
	retf	2		; Return to caller, popping flags


LCL_INT2F_XGPME:
	popf			; Restore

	jmp	OLDINT2F_VEC	; Continue on

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

LCL_INT2F endp			; End LCL_INT2F procedure
;;;; %	     NPPROC  LCL_INT&@PMI_INT -- Local INT 0&@PMI_INT&h Handler
;;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;; COMMENT|
;;;;
;;;; Local INT 0&@PMI_INT&h handler
;;;;
;;;; PM Interrupts.
;;;;
;;;; |
;;;;
;;;;	     SWATMAC ERR,RM	     ; Call our debugger
;;;; %	     jmp     OLDINT&@PMI_INT&_VEC ; Continue on
;;;;
;;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;;
;;;; % LCL_INT&@PMI_INT endp	     ; End LCL_INT&@PMI_INT procedure
;;;; %	     NPPROC  LCL_INT&@PMF_INT -- Local INT 0&@PMF_INT&h Handler
;;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;; COMMENT|
;;;;
;;;; Local INT 0&@PMF_INT&h handler
;;;;
;;;; PM Faults.
;;;;
;;;; |
;;;;
;;;;	     SWATMAC ERR,RM	     ; Call our debugger
;;;; %	     jmp     OLDINT&@PMF_INT&_VEC ; Continue on
;;;;
;;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;;
;;;; % LCL_INT&@PMF_INT endp	     ; End LCL_INT&@PMF_INT procedure
;;;; %	     NPPROC  LCL_INT&@PMM_INT -- Local INT 0&@PMM_INT&h Handler
;;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;; COMMENT|
;;;;
;;;; Local INT 0&@PMM_INT&h handler
;;;;
;;;; Miscellaneous Returns (RSP, VPF, VMC, etc.).
;;;;
;;;; |
;;;;
;;;;	     SWATMAC ERR,RM	     ; Call our debugger
;;;; %	     jmp     OLDINT&@PMM_INT&_VEC ; Continue on
;;;;
;;;;	     assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;;
;;;; % LCL_INT&@PMM_INT endp	     ; End LCL_INT&@PMM_INT procedure
	NPPROC	PushIretFL -- Push IRET FL Onto Stack
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Push an IRET's FL onto the stack
in preparation to calling the next
interrupt handler in sequence

On entry:

SS:SP	==>

On exit:

|

PIFL_STR struc

	dw	?		; Caller's BP
PIFL_AX dw	?		; Caller's AX (to be IP)
PIFL_IP dw	?		; ...	   IP (to be FL)
PIFL_IRET db	(type IRET_STR) dup (?) ; ... IRET frame

PIFL_STR ends

	push	ax		; Make room for FL (actually IP)

	push	bp		; Prepare to address the stack
	mov	bp,sp		; Hello, Mr. Stack

	mov	ax,[bp].PIFL_IRET.IRET_FL ; Get caller's FL
	xchg	ax,[bp].PIFL_IP ; Swap with caller's IP (now FL)
	xchg	ax,[bp].PIFL_AX ; Swap with original AX (now IP)

	pop	bp		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PushIretFL endp 		; End PushIretFL procedure
%	FPPROC	LCL_INT&@PMH_INT -- Local INT 0&@PMH_INT&h Handler
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Local INT 0&@PMH_INT&h handler

HW interrupt returns.

SS:ESP	==>	IRET_STR

|

; Confirm that this comes from an HPDA

	push	bp		; Prepare to address the stack
	mov	bp,sp		; Hello, Mr. Stack
				; SS:BP ==> BP_IRET_STR
	push	ds		; Save for a moment

	mov	ds,[bp].BP_IRET_IRET.IRET_CS ; Get the calling segment #
	assume	ds:nothing	; Tell the assembler about it

	cmp	ds:[0].EDD,@HPDA_SIG2 ; Izit one of our HPDAs?

	pop	ds		; Restore

	pop	bp		; Restore
	jne	short @F	; Jump if not

; Transfer from RM to PM

	call	PushIretFL	; Push FL from IRET frame
;;;;;;; pushf			; Simulate INT
	cli			; ... environment
	call	YY_GXTHDR.GXTHDR_RM2PM_VEC ; Switch from RM to PM
; Note, the return address is on the stack to identify which call this is.
%	public	DPMI_RM2PM_&@PMH_INT
% DPMI_RM2PM_&@PMH_INT:
@@:
%	jmp	OLDINT&@PMH_INT&_VEC ; Continue on

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

% LCL_INT&@PMH_INT endp 	; End LCL_INT&@PMH_INT procedure
	NPPROC	AllocAllMem -- Allocate All Extended Memory
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Allocate all extended memory

|

	pushad			; Save registers
	REGSAVE <es>		; Save for a moment

	mov	ax,cs		; Copy YGROUP segment
	mov	es,ax		; Address it
	assume	es:YGROUP	; Tell the assembler about it

	cmp	YY_XMSMEM_CNT,0 ; Any memory found already?
	jne	near ptr AllocAllMem_NOXMS ; Jump if so

;;;;;;; mov	YY_XMSMEM_CNT,0 ; Start with none

; Allocate all XMS memory

	mov	cx,@XMSMEM_LEN	; Get maximum # entries in our table
	xor	si,si		; Initialize index into table
AllocAllMem_NEXTXMS:

; Query largest XMS block

	push	ecx		; Save for a moment

	xor	eax,eax 	; Zero to use as dword
	mov	ah,YY_XMS_QRYXMB ; Function code to query XMS memory
	call	YY_XMSDRV_VEC	; Request XMS service
				; Return with eAX = size of largest block (in 1KB)
				; ...	      eDX = total amount of free ...
				; ...	      ECX = highest ending address
				; ...	      BL  = error code
	pop	ecx		; Restore

	cmp	eax,0		; Any memory available?
	je	short AllocAllMem_NOXMS ; Jump if not

	mov	edx,eax 	; Copy size of largest block
	mov	YY_XMSMEM[si].XMSMEM_LEN,eax ; Save for later use
	mov	ah,YY_XMS_GETXMB ; Function code to allocate XMS memory
	call	YY_XMSDRV_VEC	; Request XMS service
				; Return with AX = 1 iff successful
				; ...	      DX = handle
				; ...	      BL  = error code
	cmp	ax,1		; Did it work?
	jne	short AllocAllMem_NOXMS ; Jump if not

	mov	YY_XMSMEM[si].XMSMEM_HNDL,dx ; Save for later use

; Lock the block to get its linear address

	mov	ah,@XMS_LCKXMB	; Function code to lock a block
	call	YY_XMSDRV_VEC	; Request XMS service
				; Return with AX = 1 iff successful
				; ...	      DX:BX ==> linear address
	mov	ax,dx		; Copy high-order word
	shl	eax,16		; Shift to high-order
	mov	ax,bx		; Copy low-order word

; Translate this address to a physical one if the MM returns a linear address

	test	YY_GXTHDR.GXTHDR_ATTR,@GXTHDR_VDS ; Duzit need translation?
	jz	short AllocAllMem_NOVDS ; Jump if not

	mov	YY_DDS.DDS_FVEC.FOFF,eax ; Save as offset
	mov	YY_DDS.DDS_FVEC.FSEL,0	 ; ...	    segment
	mov	eax,YY_XMSMEM[si].XMSMEM_LEN ; Save for later use
	mov	YY_DDS.DDS_SIZE,eax ; Save as size

	xor	dx,dx		; No flags
	lea	di,YY_DDS	; ES:DI ==> DDS
	VDSCALL @VDS_LOCK	; Request VDS service
;;;;;;; jc	short ???	; Jump on error *FIXME*

	mov	eax,YY_DDS.DDS_POFF ; Get the physical address
AllocAllMem_NOVDS:
	mov	YY_XMSMEM[si].XMSMEM_PA,eax ; Save for later use

	add	si,type XMSMEM_STR ; Skip to next entry

	inc	YY_XMSMEM_CNT	; Count in another entry

;;;;;;; loop	AllocAllMem_NEXTXMS ; Jump if more entries
	dec	cx		; Count out another entry
	jnz	AllocAllMem_NEXTXMS ; Jump if more entries
AllocAllMem_NOXMS:
	REGREST <es>		; Restore
	assume	es:nothing	; Tell the assembler about it

	popad			; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

AllocAllMem endp		; End AllocAllMem procedure
	FPPROC	FreeAllMem -- Free All Extended Memory
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Free all extended memory.

Note that this routine is called after a switch from RM to PM
has failed, so it must preserve the flags.

|

	pushf			; Save flags
	pusha			; Save registers

	mov	cx,YY_XMSMEM_CNT ; Get # active XMS blocks
	jcxz	FreeAllMemDone	; Jump if none
	xor	si,si		; Initialize index into table
FreeAllMemNext:
	mov	dx,YY_XMSMEM[si].XMSMEM_HNDL ; Get the handle

	and	dx,dx		; Izit already released?
	jz	short FreeAllMemLoop ; Jump if so

	mov	ah,@XMS_UNLXMB	; Function code to unlock an XMS block
	call	YY_XMSDRV_VEC	; Request XMS service

	cmp	ax,1		; Did it work?
	je	short @F	; Jump if so

	SWATMAC ERR,RM		; Call our debugger

	jmp	short FreeAllMemLoop ; Jump if not


@@:
	mov	ah,@XMS_RELXMB	; Function code to release an XMS block
	call	YY_XMSDRV_VEC	; Request XMS service

	cmp	ax,1		; Did it work?
	je	short @F	; Jump if so

	SWATMAC ERR,RM		; Call our debugger

	jmp	short FreeAllMemLoop ; Jump if not


@@:
.8086
	mov	YY_XMSMEM[si].XMSMEM_HNDL,0 ; Mark as released
.386
FreeAllMemLoop:
	add	si,type XMSMEM_STR ; Skip to next entry

	loop	FreeAllMemNext	; Jump if more XMS blocks to release
FreeAllMemDone:
	popa			; Restore
	popf			; Restore flags

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FreeAllMem endp 		; End FreeAllMem procedure
	FPPROC	DPMI_RVM2PM -- DPMI Real/Virtual Mode to Protected Mode Switch
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI Real/Virtual Mode to Protected mode switch

On entry:

AX	=	1 if it's a 32-bit application
ES:0	==>	DPMI private host data area

|

; We need to know where the caller's PSP is so we can address it
; via a selector as well as convert its environment segment to a
; selector.  Also, we need to know where the DTA points for DOS
; translation services.

	REGSAVE <ax,bx,cx,es>	; Save registers

; Note that the above REGSAVE *MUST* match VM2PM_STR in INT31_VM2PM.

	DOSCALL @GETPS0 	; Return with BX = current PSP
	mov	cx,bx		; Save for later use

	DOSCALL @GETDTA 	; Return wih ES:BX ==> current DTA
	assume	es:nothing	; Tell the assembler about it

;;;;;;; smsw	ax		; Get Machine Status Word for PE test
;;;;;;;
;;;;;;; test	ax,mask $PE	; Izit VM?
;;;;;;; jnz	short DPMI_RVM2PM_INT ; Jump if so
;;;;;;;
	call	AllocAllMem	; Allocate all available extended memory

	pushf			; Simulate INT
	cli			; ... environment
	call	YY_GXTHDR.GXTHDR_RM2PM_VEC ; Switch from RM to PM

; The return address is on the stack to identify which call this is.
; The PM routine pops the registers from the stack and does the RETF
; even if we fail the INT 31h

	public	DPMI_RM2PM_INT
DPMI_RM2PM_INT:
	SWATMAC ERR,RM		; We should never get here
;;;;;;;
;;;;;;; stc			; Mark as failing the RM/VM to PM switch
;;;;;;;
;;;;;;; REGREST <es,cx,bx,ax>	; Restore
;;;;;;; assume	es:nothing	; Tell the assembler about it
;;;;;;;
;;;;;;; ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_RVM2PM endp		; End DPMI_RVM2PM procedure
	FPPROC	DPMI_IO -- DPMI Client GP Fault I/O
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

DPMI client GP Fault I/O

On entry:

AL/AX/EAX =	 output value if output
DX	=	I/O port

On exit:

AL/AX/EAX =	 input value if input

|

	public	DPMI_IO_INPB
DPMI_IO_INPB:
	in	al,dx		; Input byte

	ret			; Return to caller

	public	DPMI_IO_INPW
DPMI_IO_INPW:
	in	ax,dx		; Input word

	ret			; Return to caller

	public	DPMI_IO_INPD
DPMI_IO_INPD:
	in	eax,dx		; Input dword

	ret			; Return to caller

	public	DPMI_IO_OUTB
DPMI_IO_OUTB:
	out	dx,al		; Output byte

	ret			; Return to caller

	public	DPMI_IO_OUTW
DPMI_IO_OUTW:
	out	dx,ax		; Output word

	ret			; Return to caller

	public	DPMI_IO_OUTD
DPMI_IO_OUTD:
	out	dx,eax		; Output dword

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DPMI_IO endp			; End DPMI_IO procedure




; Note that the local HPDA must be the last definition in this segment

	DPALIGN YYSTART 	; Ensure the HPDA is on a para boundary

	public	LCL_HPDA
LCL_HPDA HPDA_STR <>		; Define the local HPDA

	public	YYLEN
YYLEN	=	$-YYSTART	; Length of UMB code/data

YCODE	ends			; End YCODE segment

	MEND	INIT_REAL	; End DPMI_1ST module
