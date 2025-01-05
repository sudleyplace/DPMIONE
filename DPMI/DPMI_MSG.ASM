;' $Header$
	title	DPMI_MSG -- DPMI.LOD Message Text
	page	58,122
	name	DPMI_MSG
COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1987-2001 Sudley Place Software.  All Rights reserved.

|
.386p
.xlist
	include MASM.INC
	include ASCII.INC
	include DTE.INC
NOVER_HTU = 1
	include VERSION.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_PRG.INC
	include DPMI_SEG.INC
.list

XDATA	segment use16 dword public 'xdata' ; Start XDATA segment
	assume	ds:XGROUP

	public	@DPMI_MSG_XDATA
@DPMI_MSG_XDATA label byte	; Mark module start in .MAP file

	public	MSG_SEP,MSG_UNK,MSG_UNKLST,MSG_UNKPRO,MSG_EOLERR,MSG_OVF
	public	MSG_SWERR,MSG_VAL
MSG_SEP db	BEL,'ÍÍ> Missing separator.',CR,LF,EOS
MSG_UNK db	BEL,'ÍÍ> Unknown keyword:  ',EOS
MSG_UNKLST db	BEL,'ÍÍ> Unknown list elment:  ',EOS
MSG_UNKPRO db	BEL,'ÍÍ> Unknown keyword in profile:  ',EOS
MSG_EOLERR db	BEL,'ÍÍ> Invalid line ending in profile.',CR,LF,EOS
MSG_OVF db	BEL,'ÍÍ> Value too large:  ',EOS
MSG_SWERR db	BEL,'ÍÍ> Invalid switch character:  ',EOS
MSG_VAL db	BEL,'ÍÍ> Missing value:  ',EOS

	public	MSG_DPMI
ifdef LANG_GR
MSG_DPMI db	BEL,'ÍÍ> ungltige DPMIMEM Option.',CR,LF,EOS
else
MSG_DPMI db	BEL,'ÍÍ> Invalid DPMIMEM option.',CR,LF,EOS
endif				; IFDEF LANG_GR

XDATA	ends			; End XDATA segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_MSG_DATA
@DPMI_MSG_DATA	label byte	; Mark module start in .MAP file

LENTXT	macro	LAB,MSG
	local	LABA,LABZ

	public	LAB
LAB	LENTXT_STR <LABZ-LABA>
LABA	db	MSG

LABZ	label	byte

	endm			; LENTXT

ERRNO	=	1		; Initial error #

LENTXT	MSG_L01,    <'A debug exception'>             ; 01
LENTXT	MSG_L03,    <'A breakpoint exception'>        ; 02
LENTXT	MSG_L06,    <'An invalid opcode'>             ; 03
LENTXT2 MSG_L08,    <'A double fault'>                ; 04
ifdef LANG_GR
LENTXT	MSG_L0D,    <'Ein interner Systemfehler '>    ; 08
else
LENTXT	MSG_L0D,    <'An internal system error'>      ; 08
endif				; IFDEF LANG_GR
LENTXT	MSG_DMAPAGE,<'A DMA page fault'>              ; 10
LENTXT	MSG_PNP,    <'A page not present fault'>      ; 11
LENTXT	MSG_SUP,    <'A page not user fault'>         ; 12
LENTXT	MSG_ROM,    <'A read-only EMS page fault'>    ; 13
LENTXT	MSG_CRn,    <'A ROM move into CRn'>           ; 14
LENTXT	MSG_CTRL,   <'Ctrl-Alt-Del'>                  ; 15
LENTXT	MSG_WOUT,   <'A write to 8042 output port'>   ; 16
LENTXT	MSG_PULSE,  <'A pulse of 8042 output port'>   ; 18
LENTXT	MSG_286,    <'A shift to 286 mode'>           ; 19
LENTXT	MSG_XTA20,  <'A degate of A20'>               ; 20
LENTXT	MSG_SELF,   <'A ROM keyboard self-test'>      ; 22
LENTXT	MSG_REBOOT  <'A ROM reboot from F000:FFF0'>   ; 23
LENTXT	MSG_ICTRL,  <'INT 09h Ctrl-Alt-Del'>          ; 24
LENTXT	MSG_P92,    <'MCA Port 92h reset'>            ; 25
ifdef LANG_GR
LENTXT2 MSG_DMAFULL,<'DMA-Transfergrenze berschritten: DMA=  _ in ',@FILENAME,'.PRO-File eintragen'> ; xx
else
LENTXT2 MSG_DMAFULL,<'DMA transfer limit exceeded:  put DMA=  _ in ',@FILENAME,'.PRO file'> ; xx
endif				; IFDEF LANG_GR
LENTXT2 MSG_L0A,    <'An invalid TSS fault'>          ; xx
LENTXT2 MSG_L0B,    <'A segment not present fault'>   ; xx
ifdef LANG_GR
LENTXT2 MSG_L0C,    <'Stapelspeicherfehler ESP=________'> ; xx
else
LENTXT2 MSG_L0C,    <'A stack fault with ESP=________'> ; xx
endif				; IFDEF LANG_GR
	public	L0CNUM
L0CNUM	label	byte		; Start fill here - 8

LENTXT2 MSG_LLA,    <'A 286 LOADALL exception'>       ; xx
LENTXT2 MSG_L11,    <'An Alignment Check Fault'>      ; xx
LENTXT2 MSG_L12,    <'A Machine Check Fault at ________________'> ; xx
	public	L12NUM
L12NUM	label	byte		; Start fill here - 16

ifdef LANG_GR
LENTXT2 MSG_NF,     <'Ausnahmesituation bei privilegierter Anweisung'>
else
LENTXT2 MSG_NF,     <'A Privileged operation exception'>
endif				; IFDEF LANG_GR

ifdef LANG_GR
LENTXT2 MSG_TITLE,<CR,LF,@FILENAME,' Version ',VERS_H,'.',VERS_T,VERS_U,CR,LF,\
		    CR,LF,'Eine Anwendung hat die System-Integrit„t verletzt:',CR,LF,CR,LF>
else
LENTXT2 MSG_TITLE,<CR,LF,@FILENAME,' Version ',VERS_H,'.',VERS_T,VERS_U,CR,LF,\
		    CR,LF,'An application has violated system integrity:',CR,LF,CR,LF>
endif				; IFDEF LANG_GR

; The following text is split into several pieces because bozo MASM
; can't handle lines this long.

ifdef LANG_GR
;	  1	    2	      3 	4	  5	    6	      7
;1234567890123456789012345678901234567890123456789012345678901234567890123
LENTXT2 MSG_TITL2,<CR,LF,\
'ÍÍ> Eine Anwendung versuchte, Speicherbereiche bzw. bereits belegten',CR,LF,\
'    dynamischen Speicher regelwidrig zu nutzen. Der 386/486-Prozessor',CR,LF,\
'    meldete uns das, somit k”nnen wir bei der Behebung dieses Fehlers',CR,LF>
LENTXT2 MSG_TITL3,<\
'    helfen.',CR,LF,CR,LF,\
'    Entfernen Sie einen oder mehrere Ihrer Einheiten-Treiber u/o residen-',CR,LF,\
'    te Programme zeitweise, um den Verursacher zu finden. 386UTIL /D /M',CR,LF>
LENTXT2 MSG_TITL4,<\
'    identifiziert Einh.-Treiber u/o residente Programme. Hier war das',CR,LF,\
'    zuletzt geladene Programm ',CR,LF,CR,LF,\
'    '>
LENTXT2 MSG_APPLUNK <'(unbekannt)'>
	public	MSG_TAIL
MSG_TAIL LENTXT_STR <MSG_TAILZ-MSG_TAILA>
MSG_TAILA db CR,LF,CR,LF
	db '    Wenn nach Entfernen dieses bestimmten Programms der Fehler behoben ist,',CR,LF
	db '    wenden Sie sich an dessen Hersteller. Unser Kundendienst hilft gern,',CR,LF
	db '    mit Ihnen und dem Hersteller zusammen dieses Problem zu l”sen.'
	db CR,LF,CR,LF
MSG_TAILZ label byte
LENTXT2 MSG_LKEY, <'ÍÍ> Starten Sie neu mit beliebiger Taste... '>
else
LENTXT2 MSG_TITL2,<CR,LF,\
'ÍÍ> A program has attempted to use system resources improperly, or to use',CR,LF,\
'    non-shareable resources already in use.  The central processor has',CR,LF,\
'    reported this event to us so we may assist you in diagnosing the',CR,LF>
LENTXT2 MSG_TITL3,<\
'    problem.',CR,LF,CR,LF>
LENTXT2 MSG_TITL4,<\
'    For reference, the last program to load is',CR,LF,CR,LF, \
'    '>
LENTXT2 MSG_APPLUNK <'(unknown)'>
LENTXT2 MSG_TAIL, <CR,LF,CR,LF>
LENTXT2 MSG_LKEY, <'ÍÍ> Press any key to reboot the system... '>
endif				; IFDEF LANG_GR

ifdef LANG_GR
LENTXT2 MSG_LADR, <' bei ____:____ aufgetreten',CR,LF,'in Ihrer Anwendung.',CR,LF>
else
LENTXT2 MSG_LADR, <' at ____:____ has occurred',CR,LF,'in your application.',CR,LF>
endif				; IFDEF LANG_GR

	public	MSG_ADDROFF,MSG_ADDRSEG,MSG_ADDRSEP
ifdef LANG_GR
MSG_ADDRSEG equ MSG_LADR[5+(size LENTXT_LEN)] ; Skipping over length word
else
MSG_ADDRSEG equ MSG_LADR[4+(size LENTXT_LEN)] ; Skipping over length word
endif				; IFDEF LANG_GR
MSG_ADDRSEP equ MSG_ADDRSEG[4]	; The Seg:Off separator
MSG_ADDROFF equ MSG_ADDRSEG[5]

ifdef LANG_GR
LENTXT2 MSG_DPMIADDR,<' bei ____|________ aufgetreten',CR,LF,'in Ihrer DPMI-Anwendung.',CR,LF>
else
LENTXT2 MSG_DPMIADDR,<' at ____|________ (________) has occurred',CR,LF,'in your DPMI application.',CR,LF>
	public	MSG_DPMISTK,MSG_DPMISTK1
LENTXT2 MSG_DPMISTK, <8 dup ('________ '),'________',CR,LF>
MSG_DPMISTK1 equ MSG_DPMISTK[size LENTXT_LEN]
endif				; IFDEF LANG_GR

	public	MSG_DPMIADDRSEL,MSG_DPMIADDRSEP,MSG_DPMIADDROFF
ifdef LANG_GR
MSG_DPMIADDRSEL equ  MSG_DPMIADDR[5+(size LENTXT_LEN)] ; Skipping over length word
else
MSG_DPMIADDRSEL equ  MSG_DPMIADDR[4+(size LENTXT_LEN)] ; Skipping over length word
endif				; IFDEF LANG_GR
MSG_DPMIADDRSEP equ  MSG_DPMIADDRSEL[4]
MSG_DPMIADDROFF equ  MSG_DPMIADDRSEL[5]

	public	MSG_DPMIADDREFL
MSG_DPMIADDREFL equ  MSG_DPMIADDROFF[10]

ifdef LANG_GR
LENTXT2 MSG_DPMIPRESS, <'ÍÍ> weiter mit beliebiger Taste... '>
else
LENTXT2 MSG_DPMIPRESS, <'ÍÍ> Press any key to continue... '>
endif				; IFDEF LANG_GR

; The following message are used by either DISP_STR or SWAT and
; thus need to span both formats.  DISP_STR uses a leading
; byte containing the length of the following message.	SWAT
; uses ASCIIZ format.

LENTXT3 macro	LAB,MSG

LENTXT2 LAB,MSG
	db	0		; Terminator for SWAT if used

	endm			; LENTXT3


LENTXT3 DPMIMSG_LOW,	 <78 dup (?)>
LENTXT3 DPMIMSG_APPLFULL,<'Appl Stack Overflow'>
LENTXT3 DPMIMSG_LPMFULL,<'LPM Stack Overflow'>
LENTXT3 DPMIMSG_VMFULL, <'VM Stack Overflow'>
LENTXT3 DPMIMSG00,	 <'A Divide Exception'>
LENTXT3 DPMIMSG01,	 <'A Debug Exception'>
LENTXT3 DPMIMSG02,	 <'An NMI Exception'>
LENTXT3 DPMIMSG03,	 <'A Breakpoint Exception'>
LENTXT3 DPMIMSG04,	 <'An INTO Exception'>
LENTXT3 DPMIMSG05,	 <'A BOUND Exception'>
LENTXT3 DPMIMSG06,	 <'An Invalid Opcode'>
LENTXT3 DPMIMSG07,	 <'NDP Not Available'>
LENTXT3 DPMIMSG08,	 <'A Double Fault'>
LENTXT3 DPMIMSG09,	 <'An NDP Segment Overrun'>
LENTXT3 DPMIMSG0A,	 <'A TSS Fault'>
LENTXT3 DPMIMSG0B,	 <'A Segment Not Present'>
LENTXT3 DPMIMSG0C,	 <'A Stack Fault'>
LENTXT3 DPMIMSG0D,	 <'A GP Fault'>
LENTXT3 DPMIMSG0E,	 <'A Page Fault'>
LENTXT3 DPMIMSG0F,	 <'An INT 0Fh Exception'>
LENTXT3 DPMIMSG10,	 <'An NDP Exception'>
LENTXT3 DPMIMSG11,	 <'An Alignment Check'>
LENTXT3 DPMIMSG12,	 <'An INT 12h Exception'>
LENTXT3 DPMIMSG13,	 <'An INT 13h Exception'>
LENTXT3 DPMIMSG14,	 <'An INT 14h Exception'>
LENTXT3 DPMIMSG15,	 <'An INT 15h Exception'>
LENTXT3 DPMIMSG16,	 <'An INT 16h Exception'>
LENTXT3 DPMIMSG17,	 <'An INT 17h Exception'>
LENTXT3 DPMIMSG18,	 <'An INT 18h Exception'>
LENTXT3 DPMIMSG19,	 <'An INT 19h Exception'>
LENTXT3 DPMIMSG1A,	 <'An INT 1Ah Exception'>
LENTXT3 DPMIMSG1B,	 <'An INT 1Bh Exception'>
LENTXT3 DPMIMSG1C,	 <'An INT 1Ch Exception'>
LENTXT3 DPMIMSG1D,	 <'An INT 1Dh Exception'>
LENTXT3 DPMIMSG1E,	 <'An INT 1Eh Exception'>
LENTXT3 DPMIMSG1F,	 <'An INT 1Fh Exception'>

DATA	ends			; End DATA segment

	MEND			; End DPMI_MSG module
