;' $Header$
;
; (C) Copyright 1995-2002 Qualitas, Inc.  All rights reserved.
;
; GXT_HDR.INC
;
; Header structure for MMEXT loaded modules
;

COMMENT|

The file to be loaded has the following format:

* Code segment(s) the first bytes of which are GXTHDR_STR
* Initialized data segment(s)
* Uninitialized data segment

Each module is processed as follows:

* The module is loaded into memory
* The module's INIT_REAL entry point is called
* The module is copied to XMS memory

After all modules are processed as above, each module is again
processed as follows:

* The module's selectors are allocated
* The module's INIT_PROT entry point is called

At INIT_PROT time, the selectors have been allocated.  The first
selector maps the code as per GXTHDR_COFF/CLEN and the second selector
maps the data as per GXTHDR_DOFF/DLEN.	The remaining selectors are
uninitialized, but may be initialized at INIT_PROT (or later) time by
writing into the GDT directly.	Also at INIT_PROT and REST_PROT time,
the selector in ES maps all of memory.	Note that the INIT_PROT and
REST_PROT routines are called on a 32-bit stack.

During execution in PM, all interrupts and exceptions must be on the
host's PL0 stack.

|


GXTHDR_STR struc

; Legend:  R = filled in by module during INIT_REAL
;	   P = ...			  INIT_PROT
;	   L = ...	    loader before INIT_REAL
;	   ? = ...	    loader before INIT_PROT *FIXME*
;	   M = ...	    module before INIT_REAL

GXTHDR_CNT dw	size GXTHDR_STR ; 00:  R:  # bytes in header
GXTHDR_NXT dw	-1		; 02:  L:  Segment of next header (-1=last)
GXTHDR_HVER dw	?		; 04:  R:  Header version #
GXTHDR_LVER dw	0100h		; 06:  L:  Loader version #
GXTHDR_COFF dd	?		; 08:  R:  Offset to PM code (typically zero)
GXTHDR_CLEN dd	?		; 0C:  R:  Length of ...
GXTHDR_DOFF dd	?		; 10:  R:  Offset to PM data
GXTHDR_DLEN dd	?		; 14:  R:  Length of ... (may include
				;	   uninitialized data)
GXTHDR_IREAL dd ?		; 18:  M:  Seg:Off of INIT_REAL code
GXTHDR_IPROT df ?		; 1C:  R:  Sel:Off of INIT_PROT code
GXTHDR_RPROT df ?		; 22:  R:  Sel:Off of REST_PROT code
GXTHDR_RREAL dd ?		; 28:  R:  REST_REAL code/data offset
	     dd ?		; 2C:  R:  ...	     length
GXTHDR_NSELS dw ?		; 30:  R:  # consecutive selectors needed
				;	   including initial code/data
GXTHDR_SELCR3 dw ?		; 32:  ?:  Selector which maps CR3
GXTHDR_ATTR dd	?		; 34:  L/R:  Attributes (see GXTHDR_REC below)
GXTHDR_CBFVEC df ?		; 38:	:  Sel|Off of Callback address
GXTHDR_PRGSEG_CUR dw ?		; 3E:  L/R:  Current program segment of TSR
GXTHDR_PRGSEG_NXT dw ?		; 40:  R:  Upper limit segment of TSR
GXTHDR_HDRSEG dw ?		; 42:  L:  Header ...
GXTHDR_NLOWPARA dw ?		; 44:  R:  # paras needed in low DOS memory
	dw	?		; 46:  ?:  (for alignment)
GXTHDR_PM2RM_FVEC df ?		; 48:  P:  Sel:Off of entry from PM to RM transfer
	dw	?		; 4E:  ?:  (for alignment)
GXTHDR_RM2PM_VEC dd ?		; 50:  L:  Seg:Off of RM to PM transfer function
GXTHDR_RM2PM_FVEC df ?		; 54:  P:  Sel:Off of entry from RM to PM transfer
GXTHDR_IBV0 db	?		; 5A:  ?:  Master PIC base
GXTHDR_IBV1 db	?		; 5B:  ?:  Slave  ...
GXTHDR_PHYSIZE dd ?		; 5C:  L:  Top of physical memory in 1KB

GXTHDR_STR ends


; The callback function checks for one of the following function codes in EAX

@GXCB_CHGIDT   equ 0000h	; The client is about to change the IDT
@GXCB_CHGIDTZ  equ 0001h	; ...	     is finished changing ...
@GXCB_SETCR3   equ 0002h	; ...	     is setting CR3
@GXCB_LIN2PHYS equ 0003h	; ...	     requests a linear to physical
				;	     address conversion
@GXCB_RELRMSTK equ 0004h	; ...	     is releasing a RM stack

GXTHDR_REC record \
 $GXTHDR_VDS:1,   \
 $GXTHDR_FCR3:1,  \
 $GXTHDR_USE32:1, \
 $GXTHDR_RMIE:1,  \
 $GXTHDR_PSWAT:1


@GXTHDR_VDS   equ  (mask $GXTHDR_VDS)	; XMS lock addresses need VDS translation
@GXTHDR_FCR3  equ  (mask $GXTHDR_FCR3)	; The MM has a full CR3
@GXTHDR_USE32 equ  (mask $GXTHDR_USE32) ; Initial code selector for
				; module is USE32
@GXTHDR_RMIE  equ  (mask $GXTHDR_RMIE)	; Real mode initialization error
@GXTHDR_PSWAT equ  (mask $GXTHDR_PSWAT) ; SWAT present:  do not call @VCPI_DPRES

; To fail a load module and abort the loader itself, set RMIE.
; To fail a load module but continue with other load modules,
; return CLEN=DLEN=0.


; Structure for entering PM from RM

EPRM_STR struc

EPRM_EIP dd	?		; Caller's EIP
EPRM_CS  dw	?,?		; ...	   CS w/filler
EPRM_EFL dd	?		; ...	   EFL
EPRM_ESP dd	?		; ...	   ESP
EPRM_SS  dw	?,?		; ...	   SS w/filler
EPRM_ES  dw	?,?		; ...	   ES w/filler
EPRM_DS  dw	?,?		; ...	   DS w/filler
EPRM_FS  dw	?,?		; ...	   FS w/filler
EPRM_GS  dw	?,?		; ...	   GS w/filler

EPRM_STR ends


RM2PM_STR struc

RM2PM_EGP db	(size PUSHAD_STR) dup (?) ; ... EGPs
RM2PM_EPRM db	(size EPRM_STR) dup (?) ; ... EPRM
RM2PM_NEXT dd	?		; RM_NEXT
RM2PM_DEV_FLAG dw ?		; DEV_FLAG
RM2PM_GDTR df	?		; RM_GDTR

RM2PM_STR ends


