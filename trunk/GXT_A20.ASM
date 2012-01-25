;' $Header$
	title	GXT_A20 -- MMEXT A20 And Related Routines
	page	58,122
	name	GXT_A20

COMMENT|		Module Specifications

*********************************** QUALITAS ***********************************
********************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1992-2003 Qualitas, Inc.  All rights reserved.

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include A20.INC
	include 8255.INC
	include 8259.INC
	include HMA.INC
	include INTVEC.INC
	include BITFLAGS.INC
	include PTR.INC

	include GXT_SEG.INC
.list

NDATA	segment use16 dword public 'ndata' ; Start NDATA segment
	assume	ds:NGROUP

	public	@GXT_A20_NDATA
@GXT_A20_NDATA	label byte	; Mark module start in .MAP file

	public	I78DATA
I78DATA db	0E4h,78h	; in	  al,78h
	db	  0Ch, 04h	; or	  al,04h
	db	0E6h,78h	; out	  78h,al
I78DATA_LEN equ $-I78DATA	; Length of I78DATA

NDATA	ends			; End NDATA segment


RDATAZ	segment use16 para public 'rdataz'; Start RDATAZ segment
	assume	ds:RGROUP

	extrn	RTAIL_NR:byte

RDATAZ	ends			; End RDATAZ segment


RCODE	segment use16 para public 'rcode' ; Start RCODE segment
	assume	cs:RGROUP,ds:RGROUP

	public	@GXT_A20_RCODE
@GXT_A20_RCODE: 		; Mark module start in .MAP file

@WAIT8042 equ	12		; Wait counter for 8042 timeout

	public	A20SUP
A20SUP	dw	mask $A20_8042	; Assume we're using an 8042

	public	ACTA20_COMSUB
ACTA20_COMSUB dw RGROUP:A20COM_ISA ; Default A20 handler

	public	ACTA20_ENA
	include QMAX_A20.INC
ACTA20_ENA ACTA20_STR <RGROUP:A20ENA_I92,RGROUP:A20ENA_QUD,RGROUP:A20ENA_XT,RGROUP:A20ENA_ISA,RGROUP:A20ENA_I78>

	public	ACTA20_DIS
ACTA20_DIS ACTA20_STR <RGROUP:A20DIS_I92,RGROUP:A20DIS_QUD,RGROUP:A20DIS_XT,RGROUP:A20DIS_ISA,RGROUP:A20DIS_I78>

	NPPROC	DEVWAITIBUF_CLR -- Wait For The Input Buffer To Clear
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Wait for the one-byte input buffer to clear.

On entry:

IF	=	0

On exit:

CF	=	0 if buffer empty
	=	1 otherwise

|

	REGSAVE <ax,cx> 	; Save registers

	mov	ah,@WAIT8042	; Outer loop counter (arbitrary value)
	xor	cx,cx		; Inner loop counter (arbitrary value)
DEVWAITIBUF_CLR1:
	in	al,@8042_ST	; Get status from keyboard

	and	al,mask $INPFULL ; Check Input Buffer Full flag
	loopnz	DEVWAITIBUF_CLR1 ; Last char not read as yet
	jz	short DEVWAITIBUF_CLR_EXIT ; Jump if buffer clear (note CF=0)

	dec	ah		; One fewer time
	jnz	short DEVWAITIBUF_CLR1 ; Go around again

	stc			; Indicate something went wrong
DEVWAITIBUF_CLR_EXIT:
	REGREST <cx,ax> 	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEVWAITIBUF_CLR endp		; End DEVWAITIBUF_CLR procedure
	NPPROC	DEVWAITOBUF_CLR -- Wait For The Output Buffer To Clear
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

On entry:

IF	=	0

Wait for the one-byte output buffer to clear.

|

	push	ax		; Save for a moment
DEVWAITOBUF_CLR1:
	in	al,@8042_ST	; Get status from keyboard

	and	al,mask $OUTFULL ; Check Output Buffer Full flag
	jz	short DEVWAITOBUF_CLR_EXIT ; Jump if buffer clear before

	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

	in	al,@8255_A	; Purge the character
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
;;;;;;; jmp	short $+2	; I/O delay

	jmp	short DEVWAITOBUF_CLR1 ; Go around again

DEVWAITOBUF_CLR_EXIT:
	pop	ax		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEVWAITOBUF_CLR endp		; End DEVWAITOBUF_CLR procedure
	NPPROC	DEVWAITOBUF_SET -- Wait for Output Buffer Full
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Wait for the output buffer to fill.

On entry:

IF	=	0

On exit:

CF	=	1 if no response
	=	0 otherwise

|

	REGSAVE <ax,cx> 	; Save registers

; Wait for a response

	mov	ah,@WAIT8042	; Outer loop counter (arbitrary value)
	xor	cx,cx		; Inner loop counter (arbitrary value)
DEVWAITOBUF_SET1:
	in	al,@8042_ST	; Get status from keyboard

	and	al,mask $OUTFULL ; Check Output Buffer Full flag
	loopz	DEVWAITOBUF_SET1 ; Jump if no response as yet
	jnz	short DEVWAITOBUF_SET_EXIT ; Join common exit code (note CF=0)

	dec	ah		; One fewer time
	jnz	short DEVWAITOBUF_SET1 ; Jump if more tries available

	stc			; Indicate something went wrong
DEVWAITOBUF_SET_EXIT:
	REGREST <cx,ax> 	; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEVWAITOBUF_SET endp		; End DEVWAITOBUF_SET procedure
	NPPROC	DEVPPI_S2C -- PPI System to Controller
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

PPI System to Controller.
Send a command to the controller (8042).

Note that it's the caller's responsibility to ensure that
the 8042 output buffer is clear.

1.  Wait for the input buffer to clear to avoid overrun.
2.  Send the command in AH to the keyboard controller port 64h.
    There is no acknowledgement of this command.

On entry:

AH	=	command
IF	=	0

On exit:

CF	=	1 if keyboard controller not responding
	=	0 otherwise

|

	call	DEVWAITIBUF_CLR ; Wait for input buffer to clear
	jc	short @F	; Error, controller not reading data (note CF=1)

	xchg	al,ah		; Swap to put command in AL
	out	@8042_ST,al	; Send the command
	xchg	al,ah		; Restore
@@:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEVPPI_S2C endp 		; End DEVPPI_S2C procedure
	NPPROC	DEVPPI_K2S -- PPI Keyboard to System
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

PPI Keyboard to System.
Wait for a response from the keyboard or its controller.

On entry:

IF	=	0

On exit:

CF	=	1 if no response
	=	0 otherwise

AL	=	response if CF=0

|

	call	DEVWAITOBUF_SET ; Wait for the output buffer to fill
	jc	short @F	; Jump if no timely response (note CF=1)

	in	al,@8255_A	; Read in the code
@@:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEVPPI_K2S endp 		; End DEVPPI_K2S procedure
	NPPROC	DEVPPI_S2C_K2S -- PPI System to Controller, Keyboard to System
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

PPI System to Controller, Keyboard to System
Send a command to the controller (8042), wait for a response.

Note that it's the caller's responsibility to ensure that
the 8042 output buffer is clear.

1.  Send the command to the 8042.
2.  Wait for the output buffer to fill.
3.  Read the response.

Note that resend does not occur with the controller (8042)
(although it can with the keyboard (6805)).

On entry:

AH	=	S2C command
IF	=	0

On exit:

CF	=	0 if all went OK
	=	1 otherwise

AL	=	byte read (if CF=0)

|

	call	DEVPPI_S2C	; Send command AH to 8042
	jc	short @F	; Jump if something went wrong (note CF=1)

	call	DEVPPI_K2S	; Wait for a response, returned in AL
				; Return with CF significant
@@:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEVPPI_S2C_K2S endp		; End DEVPPI_S2C_K2S procedure
	NPPROC	DEVPPI_S2C_S2K -- PPI System to Controller, System to Keyboard
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

PPI System to Controller, System to Keyboard.

Note that it's the caller's responsibility to ensure that
the 8042 output buffer is clear.

1.  Send the command to the 8042.
2.  Send the data to the 8042.

On entry:

AH	=	S2C command
AL	=	byte to send
IF	=	0

On exit:

CF	=	0 if all went OK
	=	1 otherwise

|

	call	DEVPPI_S2C	; Send command AH to 8042
	jc	short @F	; Jump if something went wrong (note CF=1)

	call	DEVWAITIBUF_CLR ; Wait for input buffer to clear
	jc	short @F	; Error, controller not reading data (note CF=1)

	out	@8255_A,al	; Send data AL to 8042
@@:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEVPPI_S2C_S2K endp		; End DEVPPI_S2C_S2K procedure
	NPPROC	PULSE8042 -- Pulse 8042
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Pulse the 8042 to ensure the last command has been accepted.
Typically, this is necssary after toggling A20.

|

;;;;;;; test	DEV_FLAG,@DEV_XPULS ; Should we pulse the controller?
;;;;;;; jnz	short PULSE8042_EXIT ; Not this time (note CF=0)

; Pulse the controller to ensure the last 8042 command has been processed

	push	ax		; Save for a moment
	mov	ah,@S2C_RESET	; Ensure in a stable state
	call	DEVPPI_S2C	; Send command AH to 8042
	pop	ax		; Restore
				; Return with CF significant
PULSE8042_EXIT:
	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PULSE8042 endp			; End PULSE8042 procedure
	NPPROC	READ_IRR -- Read Master 8259 Interrupt Request Register
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Read master 8259 Interrupt Request Register (IRR)

On exit:

AL	=	IRR

|

	mov	al,@GETIRR	; Command to get IRR
	out	@ICR,al 	; Tell the master 8259 about it
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay
	jmp	short $+2	; I/O delay

	in	al,@ICR 	; Get the master IRR
;;;;;;; jmp	short $+2	; I/O delay
;;;;;;; jmp	short $+2	; I/O delay
;;;;;;; jmp	short $+2	; I/O delay

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

READ_IRR endp			; End READ_IRR procedure
	NPPROC	A20DIS_I92 -- A20 Disable for I/O Port 92h Systems
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A20 disable for I/O port 92h systems

On entry:

AL	=	@PS2_A port value

On exit:

AL	=	(updated to disable A20)

|

	and	al,not (mask $PS2_GATE) ; Disable A20

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20DIS_I92 endp 		; End A20DIS_I92 procedure
	NPPROC	A20DIS_QUD -- A20 Disable for Quadram 386/XT
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A20 disable for Quadram 386/XT

On entry:

AL	=	1F8h port value

On exit:

AL	=	(updated to disable A20)

|

	and	al,not @BIT0	; Mark as disabling

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20DIS_QUD endp 		; End A20DIS_QUD procedure
	NPPROC	A20DIS_XT -- A20 Disable for Inboard/PC
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A20 disable for Inboard/PC

On exit:

AL	=	value to disable A20

|

	mov	al,@S2O_D20	; Tell it to disable A20

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20DIS_XT endp			; End A20DIS_XT procedure
	NPPROC	A20DIS_I78 -- A20 Disable for I78 Systems
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A20 disable for I78 systems

On entry:

AL	=	port 78h byte

On exit:

AL	=	(updated to disable A20)

|

	and	al,not @BIT2	; Disable A20 gate

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20DIS_I78 endp 		; End A20DIS_I78 procedure
	NPPROC	A20DIS_ISA -- A20 Disable for ISA
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A20 disable for ISA

On entry:

AL	=	output port byte

On exit:

AL	=	(updated to disable A20)

|

;;;;;;; or	al,(mask $S2O_DATA ) or \
;;;;;;;;	    (mask $S2O_OBFUL) or \
;;;;;;;;	    (mask $S2O_IBFMT)
;;;;;;;;			; Ensure 6805 data line high,
;;;;;;;;			; output buffer full,
;;;;;;;;			; input buffer empty
	or	al,mask $S2O_OBFUL ; Ensure output buffer marked as full
	and	al,not (mask $S2O_GATE) ; Disable A20 gate

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20DIS_ISA endp 		; End A20DIS_ISA procedure
	NPPROC	DEGATEA20 -- Disable Address Line A20
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Disable address line A20.

On exit:

CF	=	0 if all went well
	=	1 if we couldn't disable A20

|

	push	bx		; Save register

	lea	bx,ACTA20_DIS	; CS:BX ==> disable A20 actions

	jmp	ACTA20_COM	; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

DEGATEA20 endp			; End DEGATEA20 procedure
	NPPROC	GATEA20 -- Enable Address Line A20
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Enable address line A20.

On exit:

CF	=	0 if all went well
	=	1 if we couldn't enable A20

|

	push	bx		; Save register

	lea	bx,ACTA20_ENA	; CS:BX ==> enable A20 actions

	jmp	short ACTA20_COM ; Join common code

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

GATEA20 endp			; End GATEA20 procedure
	NPPROC	ACTA20_COM -- A20 Enable/Disable Common Routine
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A20 enable/disable common routine

On entry:

BX	 pushed onto stack
CS:BX	==>	enable/disable action structure

|

	push	ax		; Save register

	clc			; Assume all goes well
	lahf			; Load AH with flags

	pushf			; Save flags
	cli			; Disallow interrupts

	call	ACTA20_COMSUB	; Call the appropriate subroutine

	popf			; Restore flags

	sahf			; Store AH into flags

	pop	ax		; Restore

	pop	bx		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

ACTA20_COM endp 		; End ACTA20_COM procedure
	NPPROC	A20ENA_I92 -- A20 Enable for I/O Port 92 Systems
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A20 enable for I/O port 92 systems

On entry:

AL	=	@PS2_A port value

On exit:

AL	=	(updated to enable A20)

|

	or	al,mask $PS2_GATE ; Enable A20

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20ENA_I92 endp 		; End A20ENA_I92 procedure
	NPPROC	A20ENA_QUD -- A20 Enable for Quadram 386/XT
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A20 enable for Quadram 386/XT

On entry:

AL	=	1F8h port value

On exit:

AL	=	(updated to enable A20)

|

	or	al,@BIT0	; Mark as enabling

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20ENA_QUD endp 		; End A20ENA_QUD procedure
	NPPROC	A20ENA_XT -- A20 Enable for Inboard/PC
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A20 enable for Inboard/PC

On exit:

AL	=	value to enable A20

|

	mov	al,@S2O_E20	; Tell it to enable A20

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20ENA_XT endp			; End A20ENA_XT procedure
	NPPROC	A20ENA_I78 -- A20 Enable for I/O Port 78h Systems
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A20 enable for I/O port 78h systems

On entry:

AL	=	port 78h byte

On exit:

AL	=	(updated to enable A20)

|

	or	al,@BIT2	; Enable A20 gate

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20ENA_I78 endp 		; End A20ENA_I78 procedure
	NPPROC	A20ENA_ISA -- A20 Enable for ISA
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A20 enable for ISA

On entry:

AL	=	output port byte

On exit:

AL	=	(updated to enable A20)

|

;;;;;;; or	al,(mask $S2O_DATA ) or \
;;;;;;;;	    (mask $S2O_OBFUL) or \
;;;;;;;;	    (mask $S2O_IBFMT) or \
;;;;;;;;	    (mask $S2O_GATE )
;;;;;;;;			; Ensure 6805 data line high,
;;;;;;;;			; output buffer full,
;;;;;;;;			; input buffer empty
;;;;;;;;			; gate A20 enabled
	or	al,mask $S2O_OBFUL ; Ensure output buffer marked as full
	or	al,mask $S2O_GATE ; Enable A20

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20ENA_ISA endp 		; End A20ENA_ISA procedure
	NPPROC	A20COM_I92 -- Common A20 I/O Port 92h Routine
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Common A20 I/O port 92h routine

On entry:

CS:BX	==>	enable/disable routine

On exit:

AL	=	clobbered
AH	=	preserved

|

	in	al,@PS2_A	; Get system control port A
	call	RGROUP:[bx].ACTA20_I92 ; Call common I92 action
	out	@PS2_A,al	; Tell the system about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20COM_I92 endp 		; End A20COM_I92 procedure
	NPPROC	A20COM_QUD -- Common A20 Quadram 386/XT Routine
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Common A20 Quadram 386/XT routine

On entry:

CS:BX	==>	enable/disable routine

On exit:

AL	=	clobbered
AH	=	preserved

|

	push	dx		; Save for a moment

	mov	dx,01F8h	; Get A20 gate/degate I/O port
	in	al,dx		; Get the current value
;;;;;;; jmp	short $+2	; Drain the PIQ
;;;;;;; jmp	short $+2	; Drain the PIQ
;;;;;;; jmp	short $+2	; Drain the PIQ

	call	RGROUP:[bx].ACTA20_QUD ; Call common Quadram 386/XT action
	out	dx,al		; Tell the board about it
;;;;;;; jmp	short $+2	; Drain the PIQ
;;;;;;; jmp	short $+2	; Drain the PIQ
;;;;;;; jmp	short $+2	; Drain the PIQ

	pop	dx		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20COM_QUD endp 		; End A20COM_QUD procedure
	NPPROC	A20COM_XT -- Common A20 Inboard/PC Routine
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Common A20 Inboard/PC routine

On entry:

CS:BX	==>	enable/disable routine

On exit:

AL	=	clobbered
AH	=	preserved

|

	call	RGROUP:[bx].ACTA20_XT ; Call common Inboard/PC action
;;;;;;; or	al,10010000b	; Ensure 6805 data line high,
				; output buffer full
	out	@8255_A,al	; Issue the command
;;;;;;; jmp	short $+2	; I/O delay
;;;;;;; jmp	short $+2	; I/O delay
;;;;;;; jmp	short $+2	; I/O delay

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20COM_XT endp			; End A20COM_XT procedure
	NPPROC	A20COM_I78 -- Common A20 I/O Port 78h Routine
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Common A20 I/O port 78h routine

On entry:

CS:BX	==>	enable/disable routine

On exit:

AL	=	clobbered
AH	=	preserved

|

	in	al,78h		; Get current value
	call	RGROUP:[bx].ACTA20_I78 ; Call common I78 action
	out	78h,al		; Send back

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20COM_I78 endp 		; End A20COM_I78 procedure
	NPPROC	A20COM_ISA -- Common A20 ISA Bus Routine
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Common A20 ISA Bus routine

On entry:

CS:BX	==>	enable/disable routine

On exit:

AL	=	clobbered
AH	=	preserved

|

	REGSAVE <ax>		; Save for a moment

; Allow interrupts in case pending IRQ0 or IRQ1 to avoid losing a keystroke
; unless we're coming through Windows 3 callback

	mov	ah,@S2C_DIS	; Disable the keyboard
	call	DEVPPI_S2C	; Send command AH to 8042
	jc	short A20COM_ISA_COM_ERR1 ; Jump if error (note CF=1)
A20COM_ISA_FLUSH:
; Read the IRR:  if IRQ1 is pending, and both IRQ0 and IRQ1 are
; enabled in the IMR, allow time for one interrupt and check the
; IRR again.  We don't want any other lower priority interrupts
; to occur at this time.

	call	READ_IRR	; Return with AL = IRR

	test	al,mask $IRQ1	; IRQ1 pending?
	jz	short A20COM_ISA_WIN3CB ; Jump if not

	in	al,@IMR 	; Get master IMR

	test	al,(mask $IRQ1) or (mask $IRQ0) ; Are both enabled?
	jnz	short @F	; Jump if not

	sti			; Allow interrupts
	nop			; One for IRQ0/IRQ1
	cli			; Disallow interrupts

	jmp	short A20COM_ISA_FLUSH ; Go around again

@@:
	mov	al,@EOI1	; Get specific EOI for IRQ1
	out	@ICR,al 	; Clear IRQ1 from the IRR
A20COM_ISA_WIN3CB:

; First, clear any pending scan code from the output buffer (belt and suspenders)

	call	DEVWAITOBUF_CLR ; Wait for the output buffer to clear

	mov	ah,@S2C_ROUT	; Read output port byte command
	call	DEVPPI_S2C_K2S	; Send AH to 8042, return with AL = response
	jc	short A20COM_ISA_COM_ERR ; Jump if error (note CF=1)

	call	RGROUP:[bx].ACTA20_ISA ; Call common ISA action

	mov	ah,@S2C_WOUT	; Write output port byte
	call	DEVPPI_S2C_S2K	; Write command AH, data AL to 8042
	jc	short A20COM_ISA_COM_ERR ; Jump if error (note CF=1)

	call	PULSE8042	; Pulse the 8042 to ensure A20 toggle done
				; Return with CF significant
A20COM_ISA_COM_ERR:
	pushf			; Save previous flags

; Last, enable the keyboard

	mov	ah,@S2C_ENA	; Enable the keyboard
	call	DEVPPI_S2C	; Send command AH to 8042
				; Ignore error return
	popf			; Restore previous flags
A20COM_ISA_COM_ERR1:
	REGREST <ax>		; Restore

	adc	ah,0		; Set CF in AH image of flags as necessary

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

A20COM_ISA endp 		; End A20COM_ISA procedure
	NPPROC	CHECKA20 -- Determine A20 Status
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Determine A20 status.

Compare 0:0 to FFFF:10 for 4 interrupt vectors

On exit:

CF	=	1 if A20 gated ON
	=	0 ...		OFF

|

	REGSAVE <cx,si,di,ds,es> ; Save registers

	mov	cx,4		; Length of region to check

	mov	si,seg HMASEG	; Get segment of HMA
	mov	ds,si		; Address it
	assume	ds:HMASEG	; Tell the assembler about it

	lea	si,HMASTART	; DS:SI ==> start of HMA

	mov	di,seg INTVEC	; Get segment of INTVEC
	mov	es,di		; Address it
	assume	es:INTVEC	; Tell the assembler about it

	xor	di,di		; ES:DI ==> start of interrupt vector table

	cld			; String ops fowardly

   repe cmps	HMASTART[si].EDD,INT00_VEC[di] ; Compare 'em
	je	short @F	; Jump if A20 gated OFF (note CF=0)

	stc			; Indicate A20 gated ON
@@:
	REGREST <es,ds,di,si,cx> ; Restore
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECKA20 endp			; End CHECKA20 procedure

	align	16		; Fill tail with NOPs

RCODE	ends			; End RCODE segment


NCODE	segment use16 para public 'ncode' ; Start NCODE segment
	assume	cs:NGROUP

	public	@GXT_A20_NCODE
@GXT_A20_NCODE: 		; Mark module start in .MAP file

	NPPROC	CHECK_I92 -- Check For I/O Port 92h A20 Gating
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Check for I/O port 92h A20 gating

|

	REGSAVE <ax,cx,si,di,ds,es> ; Save registers

; See if this system supports I/O port 92h to gate A20

COMMENT|

Alas, from the no-good-deed-goes-unpunished file, it turns out that on
some systems the very act of writing to I/O port 92h (the actual value
doesn't matter) gates A20 on, but then that's all she wrote.  No
further writes to 92h or to the 8042 for that matter have any effect.

As this causes us some problems, we need to recognize this situation
and avoid it.  On the system I encountered with this hardware bug, the
input value of I/O port 92h is 0C0h, so the test used below checks for
the two high-order bits on.  If that's a valid I/O port (at least in
MCA parlance), that would mean that both Fixed Disk lights are on,
which is, I trust, an unlikely event.  This also catches the case
where the I/O port has no effect and a read returns 0FFh.

|

@FD01	equ	((mask $PS2_FD0) or (mask $PS2_FD1)) ; Both fixed disk lights

	in	al,@PS2_A	; Get current state
	and	al,@FD01	; Isolate Fixed Disk lights

	cmp	al,@FD01	; Izit valid?
	je	short CHECK_I92_EXIT ; Jump if so

	lea	ax,RTAIL_NR[16-1] ; Get offset of end of RGROUP
	shr	ax,4-0		; Convert from bytes to paras
	add	ax,seg RGROUP	; Plus its starting paragraph
	mov	es,ax		; Get next available segment
	assume	es:nothing	; Tell the assembler about it

	xor	di,di		; ES:DI ==> local buffer

	mov	ax,seg HMASEG	; Get segment of HMA
	mov	ds,ax		; Address it
	assume	ds:HMASEG	; Tell the assembler about it

	lea	si,HMASTART	; DS:SI ==> start of HMA

	mov	cx,100h 	; # bytes to copy and compare
	cld			; String ops forwardly

	cli			; Disable interrupts in case
				; the contents of the HMA can change
	REGSAVE <cx,si,di>	; Save for a moment

S16 rep movs	<es:[di].LO,HMASTART[si]> ; Copy to local buffer

	REGREST <di,si,cx>	; Restore

; Toggle the I/O port 92h state

	in	al,@PS2_A	; Get current state
	xor	al,mask $PS2_GATE ; Toggle the state
	out	@PS2_A,al	; Write it back out

; Compare the data (we might get fooled by a memory cache)

   repe cmps	HMASTART[si],es:[di].LO ; Compare with the local buffer
	pushf			; Save ZF and IF for a moment

; Toggle the I/O port 92h state back

	in	al,@PS2_A	; Get current state
	xor	al,mask $PS2_GATE ; Toggle the state
	out	@PS2_A,al	; Write it back out

	popf			; Restore ZF and IF
	sti			; Enable interrupts again
	je	short CHECK_I92_EXIT ; Jump if the same (not I/O port 92 system)

	push	seg NGROUP	; Setup DS for data references
	pop	ds
	assume	ds:NGROUP	; Tell the assembler about it

	mov	ACTA20_COMSUB,offset RGROUP:A20COM_I92 ; Save routine addr
	mov	A20SUP,mask $A20_I92 ; Mark as A20 support value
CHECK_I92_EXIT:
	REGREST <es,ds,di,si,cx,ax> ; Restore
	assume	ds:NGROUP,es:nothing ; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_I92 endp			; End CHECK_I92 procedure
	NPPROC	CHECK_I78 -- Check for I/O Port 78h A20 Toggle
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Check for I/O port 78h to toggle A20

In certain systems I/O port 78h is used to toggle A20.	This routine
detects those BIOSs and marks it as such.

|

	push	di		; Save register

; Search for the I78DATA string in F000:0 to FFFF

	push	dword ptr 0F0000000h ; Get starting offset of BIOS
	push	0		; Length of search area (64KB)
	push	offset NGROUP:I78DATA ; Get offset of source string
	push	I78DATA_LEN	; Get length of ...
	call	SRCHSTR 	; Search for the string
	jc	short CHECK_I78_EXIT ; Jump if not found
				; Return with DI = offset of match in ROM

	mov	ACTA20_COMSUB,offset RGROUP:A20COM_I78 ; Save routine addr
CHECK_I78_EXIT:
	pop	di		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CHECK_I78 endp			; End CHECK_I78 procedure
	NPPROC	SRCHSTR -- Search For A String
	assume	ds:NGROUP,es:nothing,fs:PGROUP,gs:RGROUP,ss:nothing
COMMENT|

Search for a string.

On entry:

On exit:

DI	=	offset of match in ROM
CF	=	0 if found
	=	1 if not

|

SRCHSTR_STR struc

	dw	?		; Caller's BP
	dw	?		; ...	   IP
SRCHSTR_LEN1 dw ?		; Length of string
SRCHSTR_OFF1 dw ?		; Offset of string in NGROUP
SRCHSTR_LEN2 dw ?		; Length of search area
SRCHSTR_VEC2 dd ?		; Ptr to area to search

SRCHSTR_STR ends

	push	bp		; Prepare to address the stack
	mov	bp,sp		; Hello, Mr. Stack

	REGSAVE <ax,cx,si,es>	; Save registers

	les	di,[bp].SRCHSTR_VEC2 ; ES:DI ==> start of search area
	assume	es:nothing	; Tell the assembler about it

	mov	si,[bp].SRCHSTR_OFF1 ; FS:SI ==> source string
	mov	cx,[bp].SRCHSTR_LEN2 ; Get length of search area
	sub	cx,[bp].SRCHSTR_LEN1 ; Less length of the string
	dec	cx		; Less one to not fall off the end
	mov	al,NGROUP:[si]	; Get the first byte
SRCHSTR_NEXT:
	jcxz	SRCHSTR_ERR	; Jump if no more bytes to check
  repne scas	es:[di].LO	; Search for the 1st byte
	jne	short SRCHSTR_ERR ; Jump if no match

	REGSAVE <cx,di> 	; Save registers
	mov	si,[bp].SRCHSTR_OFF1 ; FS:SI ==> source string
	inc	si		; Plus one to account for the first match
	mov	cx,[bp].SRCHSTR_LEN1 ; Get length of the string
	dec	cx		; Less one to account for the first match
   repe cmps	NGROUP:[si].LO,es:[di].LO ; Check the rest
	REGREST <di,cx> 	; Restore
	jne	short SRCHSTR_NEXT ; Jump if no match

	dec	di		; Back off to start of match

	clc			; Mark as found

	jmp	short SRCHSTR_EXIT ; Join common exit code

SRCHSTR_ERR:
	stc			; Mark as not found
SRCHSTR_EXIT:
	REGREST <es,si,cx,ax>	; Restore
	assume	es:nothing	; Tell the assembler about it

	pop	bp		; Restore

	ret	2+2+2+4 	; Return to caller, popping arguments

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SRCHSTR endp			; End SRCHSTR procedure

	align	16		; Fill tail with NOPs

NCODE	ends			; End NCODE segment

	MEND			; End GXT_A20 module
