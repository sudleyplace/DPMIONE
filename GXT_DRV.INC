;' $Header$
;
; (C) Copyright 1992-2003 Sudley Place Software.
;
; GXT_DRV.INC
;
; Common structures and macros for DPMIONE as a device driver
;

XDTE_STR struc			; GDT for SWAT as a device driver

	db	(size DTE_STR) dup (?)
;;;_DUMMY dq	?		; 00:  First entry not accessible
;;;_GDT  dq	?		; 08:  Global descriptor table
;;;_IDT  dq	?		; 10:  Interrupt ...
;;;_DS	 dq	?		; 18:  DS ...
;;;_ES	 dq	?		; 20:  ES ...
;;;_SS	 dq	?		; 28:  SS ...
;;;_CS	 dq	?		; 30:  CS ...
;;;_BIOS dq	?		; 38:  Temporary BIOS ...
DTE_BDA  dq	?		; 40:  BIOS data area (must be selector 40h)
DTE_CSR dq	?		; 48:  CS for RGROUP
DTE_4GB dq	?		; 50:  All memory selector
DTE_TSS dq	?		; 58:  TSS selector
DTE_CR3 dq	?		; 60:  CR3 selector
DTE_LOAD dq	3 dup (?)	; Three DTEs for PM load modules
				; 68: The 1st DTE is the code segment
				; 70: The 2nd DTE is the data segment
				; 78: The 3rd DTE is available
DTE_VCPI dq	3 dup (?)	; Three DTEs for VCPI host
				; 80: The 1st DTE is the code segment
				; 88: The 2nd DTE is the data segment
				; 90: The 3rd DTE is available
DTE_PSWAT dq	20 dup (?)	; DTEs for preceding device SWAT as VCPI host
				; 98: The 1st DTE is CS
				; A0: The 2nd DTE is DS
				; A8: The 3rd DTE is LDT
				; B0: The 4th DTE is CR3
				; B8: The 5th DTE is 4GB
				; C0-130: The 6th DTE and beyond are the TSSs
				; See VCPDTE_STR in SWAT_VCP.ASM for more details
DTE_RUDCODE dq	?		; 138: INTRUDE Code selector
DTE_RUDDATA dq	?		; 140: INTRUDE Data ...
DTE_RUDSS1  dq	?		; 148: INTRUDE SS at PL1
DTE_SSB0    dq	?		; 150: DTE_SS with Big bit clear, 64KB length
DTE_PL0STK  dq	?		; 158: PL0 Expand down stack for all modules
DTE_MODS    dq	256 dup ()	; 160-???: Load modules

XDTE_STR ends


DEVSTK_STR struc		; Stack frame upon entry to PM interrupt
				; handler when called by SWAT as a device driver
DEVSTK_EIP dd	?		; Caller's EIP
DEVSTK_CS  dw	?,?		; ...	   CS w/filler
DEVSTK_EFL dd	?		; ...	   EFL
DEVSTK_ESP dd	?		; ...	   ESP
DEVSTK_SS  dw	?,?		; ...	   SS w/filler
	   dw	?,?		; ...	   ES w/filler
	   dw	?,?		; ...	   DS w/filler
	   dw	?,?		; ...	   FS w/filler
	   dw	?,?		; ...	   GS w/filler
DEVSTK_ORIG dd	?		; Next handler in sequence
DEVSTK_DEVF dw	?		; DEV_FLAG
DEVSTK_GDTR df	?		; Original GDTR

DEVSTK_STR ends


LCLINT_STR struc		; Stack frame in LCL_INTxx handlers at
				; or near the label LCL_INTxx_ORIG
	   dw	?		; Old DS
	   dd	?		; ... EFL (IF=TF=0)
LCLINT_NXT db	(size DEVSTK_STR) dup (?) ; The rest of the stack

LCLINT_STR ends


; Equates for DEVLOAD

DEVL_REC record   \
 $DEVL_NSWAT:1,   \
 $DEVL_QSWAT:1,   \
 $DEVL_VCPIPTE:1, \
 $DEVL_INTRUDE:1, \
 $DEVL_VCPI:1,	  \
 $DEVL_LOAD:1,	  \
 $DEVL_PSWAT:1

@DEVL_NSWAT   equ mask $DEVL_NSWAT   ; 40:  Don't pass on SWAT presence to load modules
@DEVL_QSWAT   equ mask $DEVL_QSWAT   ; 20:  Don't signal INT 01h if preceding SWAT
@DEVL_VCPIPTE equ mask $DEVL_VCPIPTE ; 10:  Append our PTEs to DE01 VCPI call
@DEVL_INTRUDE equ mask $DEVL_INTRUDE ; 08:  We're INTRUDEing
@DEVL_VCPI    equ mask $DEVL_VCPI    ; 04:  This is VCPI SWAT
@DEVL_LOAD    equ mask $DEVL_LOAD    ; 02:  Loaded as device driver
@DEVL_PSWAT   equ mask $DEVL_PSWAT   ; 01:  Preceding device SWAT present


; Equates for TRP_FLAG

TRP_REC record	\
 $TRP_RM2PM:1,	\
 $TRP_I67:1,	\
 $TRP_I15:1,	\
 $TRP_I0E:1,	\
 $TRP_I0D:1,	\
 $TRP_I0C:1,	\
 $TRP_I0B:1,	\
 $TRP_I0A:1,	\
 $TRP_I09:1,	\
 $TRP_I06:1,	\
 $TRP_I05:1,	\
 $TRP_I03:1,	\
 $TRP_I02:1,	\
 $TRP_I01:1,	\
 $TRP_I00:1

@TRP_RM2PM equ	mask $TRP_RM2PM ; 4000:  Trap RM2PM ...
@TRP_I67 equ	mask $TRP_I67	; 2000:  ...  INT 67h ...
@TRP_I15 equ	mask $TRP_I15	; 1000:  ...	  15h ...
@TRP_I0E equ	mask $TRP_I0E	; 0800:  ...	  0Eh ...
@TRP_I0D equ	mask $TRP_I0D	; 0400:  ...	  0Dh ...
@TRP_I0C equ	mask $TRP_I0C	; 0200:  ...	  0Ch ...
@TRP_I0B equ	mask $TRP_I0B	; 0100:  ...	  0Bh ...
@TRP_I0A equ	mask $TRP_I0A	; 0080:  ...	  0Ah ...
@TRP_I09 equ	mask $TRP_I09	; 0040:  ...	  09h ...
@TRP_I06 equ	mask $TRP_I06	; 0020:  ...	  06h ...
@TRP_I05 equ	mask $TRP_I05	; 0010:  ...	  05h ...
@TRP_I03 equ	mask $TRP_I03	; 0008:  ...	  03h ...
@TRP_I02 equ	mask $TRP_I02	; 0004:  ...	  02h ...
@TRP_I01 equ	mask $TRP_I01	; 0002:  ...	  01h ...
@TRP_I00 equ	mask $TRP_I00	; 0001:  ...	  00h ...


; Equates for DEV_FLAG

@DEV_XT equ	8000h		; XT is present
@DEV_MCA equ	4000h		; MCA is present
@DEV_XMS equ	2000h		; XMS is present
@DEV_EISA equ	1000h		; EISA system present
@DEV_A20FN equ	0800h		; A20 Architecture Functions present
@DEV_A20ON equ	0400h		; A20 enabled upon entry
@DEV_VCPI equ	0200h		; VCPI host is available
@DEV_INTRUDE equ 0100h		; INTRUDE in effect
@DEV_VDS equ	0080h		; Needs VDS translation
@DEV_NORMLIDT equ 0040h 	; NORMLIDT in effect
@DEV_FCR3 equ	0020h		; This MM uses a full CR3
@DEV_DOSCMD equ 0010h		; Loading from DOS command line
@DEV_MAX equ	0008h		; 386MAX is present


XVCPICALL macro FUNC,PREF	; Extended VCPICALL macro
	local	L1

	VCPICALL FUNC		; Try INT 67h directly

	cmp	ah,8Fh		; Izit intercepted by VCPI host?
	jne	short L1	; Jump if not

	cmp	PREF&OLDINT67_VEC,0 ; Izit valid?
	je	short L1	; Jump if not

ifnb	<FUNC>
	mov	al,FUNC 	; Get subfunction
endif				; IFNB <FUNC>
	mov	ah,@VCPI	; VCPI major function
	pushf			; Simulate INT environment
	cli			; ...
	call	PREF&OLDINT67_VEC ; Check on VCPI host
L1:
	endm			; XVCPICALL


SETMSG	macro	TYP,TXT
	local	L1

NDATA	segment use16 dword public 'ndata' ; Start NDATA segment
;;;;;;; assume	ds:NGROUP

L1	db	BEL,'ออ> ',TXT,CR,LF,EOS

NDATA	ends			; End NDATA segment

	mov	TYP&_ERRMSG,offset NGROUP:L1

	endm			; SETMSG


STROUT	macro	NAM

	push	offset NGROUP:MSG_&NAM ; Pass offset in NGROUP
	call	DISP_PROGMSG	; Display progress message

	endm			; STROUT


