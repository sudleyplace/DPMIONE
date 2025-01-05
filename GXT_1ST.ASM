;' $Header$
	title	GXT_1ST -- MMEXT First Routine
	page	58,122
	name	GXT_1ST

COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1988-2003 Sudley Place Software.

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include PTR.INC
	include 8259.INC
	include MASM5.MAC

	include GXT_COM.INC
	include GXT_HDR.INC
	include GXT_PRG.INC
	include GXT_SEG.INC
.list

PDTGRP	group	PDTSEG


PDTSEG	segment use32 dword at 0 ; Start PDTSEG segment
	assume	ds:PDTGRP

	public	OFFPDT
OFFPDT	label	dword

PDTSEG	ends			; End PDTSEG segment


DATA16	segment use32 dword public 'data' ; Start DATA16 segment
	assume	ds:DGROUP

	public	@GXT_1ST_DATA16
@GXT_1ST_DATA16 label byte	; Mark module start in .MAP file

	public	COMMON
	include QMAX_FIL.INC
COMMON	FILE_STR <>		; Common data structure

DATA16	ends			; End DATA16 segment


RCODE	segment use16 para public 'rcode' ; Start RCODE segment
	assume	cs:RGROUP

	extrn	DEV_STRA:far

RCODE	ends			; End RCODE segment


NCODE	segment use16 para public 'ncode' ; Start NCODE segment
	assume	cs:NGROUP,ds:NGROUP

	public	@GXT_1ST_NCODE
@GXT_1ST_NCODE	label byte	; Mark module start in .MAP file

	extrn	DEV_INTR_NR:far
	extrn	INIT_REAL:far

	public	PTAIL
PTAIL	label	byte		; Note the PARA-alignment of this segment

NCODE	ends			; End NCODE segment


CODEZ	segment use16 para public 'codez' ; Start CODEZ segment
	assume	ds:PCODEZ

	public	@GXT_1ST_CODEZ
@GXT_1ST_CODEZ	label byte	; Mark module start in .MAP file

	public	ZTAIL
ZTAIL	label	byte		; Note the PARA-alignment of this segment

CODEZ	ends			; End CODEZ segment


XCODE	segment use16 para public 'xcode' ; Start XCODE segment
	assume	cs:XGROUP

	extrn	INIT_VIRT:far

XCODE	ends			; End XCODE segment


XDATAZ	segment use16 para public 'xdataz' ; Start XDATAZ segment
	assume	ds:XGROUP

	extrn	XTAIL:byte

XDATAZ	ends			; End XDATAZ segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP,ds:PGROUP

	extrn	INIT_PROT:far
	extrn	REST_PROT:far

PROG	ends			; End PROG segment


P1ST	segment use32 byte public 'prog' ; Start P1ST segment
	assume	cs:PGROUP,ds:PGROUP

	public	@GXT_1ST_P1ST
@GXT_1ST_P1ST	label byte	; Mark module start in .MAP file

	public	GXTSTART
GXTSTART label	near

	public	GXTINI
	include MAXDEV.INC
GXTINI	MD_STR	<,			\
		  @MD_EXE or @MD_VER or @MD_USE32,\
		  @DEVNAME,		\
		  NGROUP:INIT_REAL,	\
		  offset PGROUP:INIT_PROT,\
		  offset PGROUP:REST_PROT,\
		  NGROUP:PTAIL, 	\
		  PCODEZ:ZTAIL, 	\
		  ,			\
		  ,			\
		  @IMRBASE,@IMR2BASE,	\
		  ,			\
		  @APIVER,		\
		  ,			\
		  XGROUP:INIT_VIRT,	\
		  ,			\
		  ,			\
		  ,			\
		  XGROUP:XTAIL>
L1:

; Define segment values in DDs for Seg:Off which the LINKer forgets

	org	GXTINI.MD_IREAL.VSEG
	dw	seg NGROUP		; For INIT_REAL
	org	GXTINI.MD_SIZE.VSEG
	dw	seg NGROUP		; For PTAIL
	org	GXTINI.MD_DATA.VSEG
	dw	seg PCODEZ		; For ZTAIL
	org	GXTINI.MD_IVIRT.VSEG
	dw	seg XGROUP		; For INIT_VIRT
	org	GXTINI.MD_VSIZE.VSEG
	dw	seg XGROUP		; For XTAIL

; Define DOS device driver header

	org	GXTINI
	include DEVDRV.INC
	DD_STR	<,			\
		  DRV_ATTR_CHAR,	\
		  PGROUP:LDEV_STRA-PGROUP:GXTSTART,\
		  PGROUP:LDEV_INTR-PGROUP:GXTSTART,\
		  @DEVNAME>
	org	L1

	FPPROC	DEV_FNS -- Local DEV_STRA and DEV_INTR Routines
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

	public	DEVLOAD
DEVLOAD db	0		; Device load flags

; We need to contruct the following JMPs by hand as the USE32
; setting of this segment produces an OSP when we don't want one.

	public	LDEV_STRA
LDEV_STRA:
	FIJMP	RGROUP:DEV_STRA,<seg RGROUP>

	public	LDEV_INTR
LDEV_INTR:
	FIJMP	NGROUP:DEV_INTR_NR,<seg NGROUP>

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEV_FNS endp			; End DEV_FNS procedure

	org	1800h		; Skip past RTAIL

	public	P1TAIL
P1TAIL	label	byte		; Used to ensure above assertion

P1ST	ends			; End P1ST segment


PTSR	segment use32 para public 'prog' ; Start PTSR segment
	assume	ds:PGROUP

	public	@GXT_1ST_PTSR
@GXT_1ST_PTSR	label byte	; Mark module start in .MAP file

;;;;;;; GXTHDR_STR <>		; Initial structure

	db	@TSRSIZE dup (?) ; Room for TSRs

PTSR	ends			; End PTSR segment

	MEND			; End GXT_1ST module
