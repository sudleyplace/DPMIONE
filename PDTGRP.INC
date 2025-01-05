;' $Header:   P:/PVCS/386SWAT/PDTGRP.INV   1.3   10 Aug 1998 11:00:44   BOB  $
;
; (C) Copyright 1987-98 Sudley Place Software              .
;
; PDTGRP.INC
;
; Page Directory segment and equates
;

PDTGRP	 group	 PDTSEG


PDTSEG	 segment use32 dword at 0 ; Start PDTSEG segment
	 assume  fs:PDTGRP

	 extrn	 OFFPDT:dword

	 assume  fs:nothing

PDTSEG	 ends			; End PDTSEG segment

@PDELOC  equ	 (2*1024)-(4*4) ; Location for new PDE
@PDELIN  equ	 @PDELOC shl (22-2) ; Linear address of @PDELOC
@PDELIN2 equ	 (4*1024)+@PDELIN ; Linear address of @PDELOC + 4KB

