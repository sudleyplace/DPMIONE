;' $Header$
;
; (C) Copyright 2003 Qualitas, Inc.  All rights reserved.
;
; GXT_SWT.INC
;
; Macros and equates for SWAT
;

SWATMAC macro	ERR,RM
	local	L1

ifb <RM>
	test	DEVLOAD,@DEVL_PSWAT ; Izit present?
	jz	short L1	; Jump if not

ifb <ERR>
	int	01h		; Call our debugger
else
	int	03h		; Call our debugger
endif
L1:
else
	int	03h		; Call our debugger
endif
	endm


