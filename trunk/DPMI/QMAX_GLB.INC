;' $Header$
;
; (C) Copyright 1987-95 Qualitas, Inc.	All rights reserved.
;
; QMAX_GLB.INC
;
; Global flags for GLB_FLAG
;

; These flags are dynamic

GLB_REC record  $GLB_NMI:1,	\
		$GLB_TLB:1,	\
		$GLB_I01:1

@GLB_NMI  equ	(mask $GLB_NMI)    ; NMI encountered while executing in TSS
@GLB_TLB  equ	(mask $GLB_TLB)    ; TLB flush needed
@GLB_I01  equ	(mask $GLB_I01)    ; Single-step next instruction in VM

