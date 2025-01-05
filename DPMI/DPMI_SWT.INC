;' $Header$
;
; (C) Copyright 2003 Sudley Place Software.   
;
; DPMI_SWT.INC
;
; Macros and equates for SWAT
;

SWATMAC macro	ERR,RM
	local	L1

ifb <RM>
	test	LCL_FLAG,@LCL_PSWAT ; Is SWAT installed?
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


