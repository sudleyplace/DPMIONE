;' $Header$
    title   IZITDPMI -- Shell to Create a .COM File
    page    58,122
    name    IZITDPMI

COMMENT|        Module Specifications

Copyright:  (C) Copyright 2003 Sudley Place Software.

Segmentation:  Group PGROUP:
           Program segment CODE,  byte-aligned,  public, class 'code'
           Tail    segment NCODE, para-aligned,  public, class 'code'
           Tail    segment NCODZ, para-aligned,  public, class 'code'
           Group DGROUP:
           Data    segment DATA,  dword-aligned, public, class 'data'
           Stack   segment STACK, para-aligned,  stack,  class 'code'

Program derived from:  None.

Original code by:  Bob Smith, May, 2003.

Modifications by:  None.

|
.386p
.xlist
    include MASM.INC
    include ASCII.INC
    include DOS.INC
    include PTR.INC
    include DPMI.INC
    include ALLMEM.INC
    include 386.INC
.list

PGROUP  group   CODE,NCODE,NCODZ
DGROUP  group   DATA,STACK


CODE    segment use16 byte public 'code' ; Start CODE segment
    assume  cs:PGROUP,ds:PGROUP
.xlist
    include PSP.INC     ; Define & skip over PSP area for .COM program
.list

INITIAL:
    jmp IZITDPMI    ; Join initialization code

CODE    ends            ; End CODE segment


NCODE   segment use16 para public 'code' ; Start NCODE segment
    assume  cs:PGROUP,ds:PGROUP

    extrn   PRINTF16:near

    public  DPMIDRV_VEC
DPMIDRV_VEC dd   ?      ; DPMI driver address

    public  LMBADDR,LMBHNDL
LMBADDR dd  ?       ; Address of Linear Memory Block
LMBHNDL dd  ?       ; Handle of ...

    public  OLDINT0D_FVEC,OLDINT0E_FVEC,OLDINT31_FVEC
OLDINT0D_FVEC df ?      ; Address of old INT 0Dh handler
OLDINT0E_FVEC df ?      ; ...            0Eh ...
OLDINT31_FVEC df ?      ; ...            31h ...

    public  SEL4GB,DTE4GB
SEL4GB  dw  ?       ; AGROUP data selector
DTE4GB  DESC_STR <-1, \
           0, \
           0, \
           CPL0_DATA or DPL3, \
           0Fh or (mask $DTE_G) or (mask $DTE_B), \
           0> ; DTE for 4GB selector

    public  DATASEG,DATASEL,NoVERW,DTEVERW
DATASEG dw  ?       ; Data segment
DATASEL dw  ?       ; Data selector
NoVERW  dw  ?       ; Bad data selector
DTEVERW DESC_STR <>     ; DTE for bad data selector

    public  DPMI_HPDA,DPMI_VER,DPMI_CPU,DPMI_FLAG,HPDA_SEG
DPMI_HPDA dw     ?      ; DPMI HPDA size in paras
DPMI_VER dw ?       ; DPMI version #
DPMI_FLAG dw    ?       ; DPMI flags
DPMI_CPU db ?,0     ; DPMI CPU
HPDA_SEG dw ?       ; HPDA segment

    public  ERRCODE
ERRCODE db  ?       ; Return code for DOS

    public  MSG_COPY
MSG_COPY db 'IZITDPMI -- Version 1.00 ',CR,LF
    db  '   (C) Copyright 2003 Sudley Place Software.',CR,LF,EOS

    public  MSG_DPMIYES,MSG_DPMINO,MSG_ERRPM
MSG_DPMIYES db  'A DPMI host is present.',CR,LF,EOS
MSG_DPMINO  db  'A DPMI host is NOT present.',CR,LF,EOS
MSG_ERRPM db    'ออ> Unable to enter PM!',CR,LF,EOS
MSG_0283OK db   'This DPMI host supports DPMI function 0283h.',CR,LF,EOS

    public  MSG_BP1,MSG_BP2,MSG_BP3
MSG_BP0 db  'Breakpoint #0',CR,LF,EOS
MSG_BP1 db  'Breakpoint #1',CR,LF,EOS
MSG_BP2 db  'Breakpoint #2',CR,LF,EOS
MSG_BP3 db  'Breakpoint #3',CR,LF,EOS
MSG_BP4 db  'Breakpoint #4',CR,LF,EOS
MSG_I0D db  'Breakpoint 0Dh',CR,LF,EOS
MSG_I0E db  'Breakpoint 0Eh',CR,LF,EOS

    public  MSG_STATS
MSG_STATS db    '# HPDA paras:  %u',CR,LF
    db  'DPMI Ver:      %tu.%02tu',CR,LF
    db  'CPU:           %02X',CR,LF
    db  'Flags:         %.8b',CR,LF
    db  'Entry Pt:      %04X:%04X',CR,LF,0

    public  MSG_REGS,MSG_EXCP,MSG_DD,MSG_LMB
MSG_REGS db 'CS:  %04X, DS:  %04X',CR,LF,0
MSG_EXCP db 'CS:EIP  %04X:%08lX, EFL:  %08lX, SS:ESP  %04X:%08lX, Err:  %08lX',CR,LF,0
MSG_DD   db '%04X:%08lX:  %08lX',CR,LF,0
MSG_LMB  db 'Address:  %08lX, handle:  %08lX',CR,LF,0
MSG_0DFVEC db   'Old INT 0D:  %04X|%08lX',CR,LF,0
MSG_0EFVEC db   'Old INT 0E:  %04X|%08lX',CR,LF,0
MSG_31FVEC db   'Old INT 31:  %04X|%08lX',CR,LF,0


    NPPROC  IZITDPMI -- Check For DPMI Host
    assume  ds:PGROUP,es:PGROUP,fs:nothing,gs:nothing,ss:nothing

; Calculate the segment of DGROUP which immediately follows NCODZ

    lea ax,ZTAIL    ; Get offset of tail
    shr ax,4-0      ; Convert from bytes to paras
    mov bx,cs       ; Get PGROUP segment
    add ax,bx       ; Add to get DGROUP
    mov DATASEG,ax  ; Save for PRINTF use

    mov ss,ax       ; Address the stack
    assume  ss:nothing  ; Tell the assembler about it
    lea sp,DGROUP:LCLSTKZ ; ...

    DOSCALL @STROUT,MSG_COPY ; Display our copyright

; Check for DPMI host

    call    CheckDPMI   ; See if we're running under a DPMI host
    jc  near ptr IZITDPMI_NOTPRES ; Jump if not present

    DOSCALL @STROUT,MSG_DPMIYES ; Tell 'em the news

    push    DPMIDRV_VEC.VOFF ; Pass Entry Point offset
    push    DPMIDRV_VEC.VSEG ; ...          segment
    push    DPMI_FLAG   ; ...  flags
    push    DPMI_CPU.ELO    ; ...  CPU type
    push    DPMI_VER    ; ...  DPMI version #
    push    DPMI_HPDA   ; ...  # paras for HPDA
    push    ds      ; ...  ptr to format string
    push    offset ds:MSG_STATS ; ...
    call    PRINTF16    ; Printf the arguments
    add sp,2*8      ; Strip from the stack

; Allocate the HPDA

    lea ax,DGROUP:LCLSTKZ ; Get offset of end of stack
    shr ax,4-0      ; Convert from bytes to paras
    add ax,DATASEG  ; Plus DGROUP segment
                ; to get next available segment
    mov HPDA_SEG,ax ; Save as HPDA segment
;;;;;;; add ax,DPMI_HPDA    ; Plus # paras in HPDA
;;;;;;; mov NEXTSEG,ax  ; Save for later use

; Enter PM

    mov es,HPDA_SEG ; Address the HPDA
    assume  es:nothing  ; Tell the assembler about it

    mov ax,DPMI_FLAG    ; Get DPMI flags
    call    DPMIDRV_VEC ; Enter PM
    assume  ds:PGROUP,es:nothing ; Tell the assembler about it
    jc  near ptr IZITDPMI_ERRPM ; Jump if something went wrong
;;;;
;;;;         mov     ax,ds       ; Get data selector
;;;;
;;;;         verw    ax          ; izit writable?
;;;;         jz      short @F        ; Jump if so
;;;;
;;;;         mov     bx,cs       ; Get code selector
;;;;         DPMICALL @DPMI_GETALIAS ; Return with AX = data alias
;;;; ;;;;;;; jc      short ???       ; Ignore error return
;;;;
;;;;         mov     bx,ds       ; Copy old DS
;;;;         mov     ds,ax       ; Address it
;;;;         assume  ds:PGROUP       ; Tell the assembler about it
;;;;         mov     DATASEL,ax      ; Save for later use
;;;;         mov     NoVERW,bx       ; Save for later use
;;;; @@:
;;;;         mov     DATASEL,ax      ; Save for later use
;;;;         mov     es,ax       ; Address it
;;;;         assume  es:PGROUP       ; Tell the assembler about it
;;;;
;;;; ; Get the DESC_STR for the bad data selector
;;;;
;;;;         mov     bx,NoVERW       ; Get the bad data selector
;;;;
;;;;         and     bx,bx       ; Izit valid?
;;;;         jz      short @F        ; Jump if not
;;;;
;;;;         lea     edi,DTEVERW     ; ES:EDI ==> DTE
;;;;         DPMICALL @DPMI_GETLDTE  ; Get LDTE for BX into ES:EDI
;;;; @@:

; Create a selector for PRINTF's DGROUP

    mov bx,DATASEG  ; Get the segment
    DPMICALL @DPMI_SEG2SEL  ; Request DPMI service
    mov DATASEG,ax  ; Save for PRINTF use

    mov ax,ds       ; Copy DGROUP selector
    mov es,ax       ; Address it
    assume  es:DGROUP   ; Tell the assembler about it

; Display our segment registers

    push    ds      ; Pass data selector
    push    cs      ; ...  code ...
    push    ds      ; ...  ptr to format string
    push    offset ds:MSG_REGS ; ...
    call    PRINTF16    ; Printf the arguments
    add sp,2*4      ; Strip from the stack








;;;; ; Get the current Extended PM Processor Exception handler
;;;;
;;;;         mov     cx,-1       ; A known value
;;;;         mov     edx,-1      ; ...
;;;;
;;;;         mov     bl,0Dh      ; Page Fault
;;;;         DPMICALL @DPMI_GETEPMPEHV ; Request DPMI service
;;;;         jc      near ptr IZITDPMI_DONE ; Jump if something went wrong
;;;;
;;;;         mov     OLDINT0D_FVEC.FSEL,cx ; Save for later use
;;;;         mov     OLDINT0D_FVEC.FOFF,edx ; ...
;;;;
;;;;         mov     bl,0Eh      ; Page Fault
;;;;         DPMICALL @DPMI_GETEPMPEHV ; Request DPMI service
;;;;         jc      near ptr IZITDPMI_DONE ; Jump if something went wrong
;;;;
;;;;         mov     OLDINT0E_FVEC.FSEL,cx ; Save for later use
;;;;         mov     OLDINT0E_FVEC.FOFF,edx ; ...
;;;;
;;;; ; Display the old vectors
;;;;
;;;;         push    OLDINT0D_FVEC.FOFF ; Pass ptr to old handler
;;;;         push    OLDINT0D_FVEC.FSEL ;
;;;;         push    ds          ; ...  ptr to format string
;;;;         push    offset ds:MSG_0DFVEC ; ...
;;;;         call    PRINTF16        ; Printf the arguments
;;;;         add     sp,4+2+4        ; Strip from the stack
;;;;
;;;;         push    OLDINT0E_FVEC.FOFF ; Pass ptr to old handler
;;;;         push    OLDINT0E_FVEC.FSEL ;
;;;;         push    ds          ; ...  ptr to format string
;;;;         push    offset ds:MSG_0EFVEC ; ...
;;;;         call    PRINTF16        ; Printf the arguments
;;;;         add     sp,4+2+4        ; Strip from the stack

; Try again using the DPMI 0.9 calls

    mov bl,0Dh      ; Page Fault
    DPMICALL @DPMI_GETPEHV  ; Request DPMI service
    jc  near ptr IZITDPMI_DONE ; Jump if something went wrong

    mov OLDINT0D_FVEC.FSEL,cx ; Save for later use
    mov OLDINT0D_FVEC.FOFF,edx ; ...

    mov bl,0Eh      ; Page Fault
    DPMICALL @DPMI_GETPEHV  ; Request DPMI service
    jc  near ptr IZITDPMI_DONE ; Jump if something went wrong

    mov OLDINT0E_FVEC.FSEL,cx ; Save for later use
    mov OLDINT0E_FVEC.FOFF,edx ; ...

;;;;         mov     bl,31h      ; DPMI functions
;;;;         DPMICALL @DPMI_GETPMIV  ; Request DPMI service
;;;;         jc      near ptr IZITDPMI_DONE ; Jump if something went wrong
;;;;
;;;;         mov     OLDINT31_FVEC.FSEL,cx ; Save for later use
;;;;         mov     OLDINT31_FVEC.FOFF,edx ; ...

; Display the old vectors

    push    OLDINT0D_FVEC.FOFF ; Pass ptr to old handler
    push    OLDINT0D_FVEC.FSEL ;
    push    ds      ; ...  ptr to format string
    push    offset ds:MSG_0DFVEC ; ...
    call    PRINTF16    ; Printf the arguments
    add sp,4+2+4    ; Strip from the stack

    push    OLDINT0E_FVEC.FOFF ; Pass ptr to old handler
    push    OLDINT0E_FVEC.FSEL ;
    push    ds      ; ...  ptr to format string
    push    offset ds:MSG_0EFVEC ; ...
    call    PRINTF16    ; Printf the arguments
    add sp,4+2+4    ; Strip from the stack

;;;;         push    OLDINT31_FVEC.FOFF ; Pass ptr to old handler
;;;;         push    OLDINT31_FVEC.FSEL ;
;;;;         push    ds          ; ...  ptr to format string
;;;;         push    offset ds:MSG_31FVEC ; ...
;;;;         call    PRINTF16        ; Printf the arguments
;;;;         add     sp,4+2+4        ; Strip from the stack
;;;;
;;;; ; Check to see if it supports DPMI function 0283h
;;;;
;;;;         mov     cx,cs       ; Get code selector
;;;;         lea     edx,LCL_INT0E   ; CX:EDX ==> local handler
;;;;         mov     bl,0Eh      ; Page Fault
;;;;         DPMICALL @DPMI_SETPEHVWIN ; Request DPMI service
;;;;         jc      near ptr IZITDPMI_DONE ; Jump if it didn't work
;;;;
;;;; ;;;;    DPMICALL @DPMI_SETPEHV  ; Request DPMI service
;;;; ;;;;    jc      short IZITDPMI_DONE ; Jump if it didn't work
;;;;
;;;;         mov     cx,cs       ; Get code selector
;;;;         lea     edx,LCL_INT0D   ; CX:EDX ==> local handler
;;;;         mov     bl,0Dh      ; Page Fault
;;;; ;;;;    DPMICALL @DPMI_SETPEHVWIN ; Request DPMI service
;;;; ;;;;    jc      near ptr IZITDPMI_DONE ; Jump if it didn't work
;;;;
;;;;         DPMICALL @DPMI_SETPEHV  ; Request DPMI service
;;;;         jc      short IZITDPMI_DONE ; Jump if it didn't work
;;;;
;;;;         xor     edx,edx         ; Zero to use as dword
;;;;         DOSCALL @STROUT,MSG_BP0 ; Tell 'em the good news

; Create an All Memory selector

    mov cx,1        ; # selectors to allocate
    DPMICALL @DPMI_GETLDT   ; Allocate a selector
    jc  near ptr IZITDPMI_DONE ; Jump if something went wrong

    mov SEL4GB,ax   ; Save for later use

    xor edx,edx     ; Zero to use as dword
    DOSCALL @STROUT,MSG_BP1 ; Tell 'em the good news

; Test DPMI 1.0 Set Multiple DTE call

    mov cx,1        ; Set one selector
    lea edi,SEL4GB  ; ES:EDI ==> selector followed by descriptor
    DPMICALL @DPMI_SETMLDTE ; Set the selector
    jc  near ptr IZITDPMI_DONE ; Jump if something went wrong

;;;;;;; lea edi,DTE4GB  ; ES:EDI ==> selector followed by descriptor
;;;;;;; mov bx,SEL4GB   ; Get the selector
;;;;;;; DPMICALL @DPMI_SETLDTE  ; Set the selector
;;;;;;; jc  near ptr IZITDPMI_DONE ; Jump if something went wrong
;;;;;;;
    xor edx,edx     ; Zero to use as dword
    DOSCALL @STROUT,MSG_BP2 ; Tell 'em the good news

; Allocate some Uncommitted Memory

    xor ebx,ebx     ; No special address
    xor edx,edx     ; Uncommitted Memory
    mov ecx,4*1024  ; A single 4KB page
    mov esi,-1      ; Known value
    DPMICALL @DPMI_GETLMB   ; Request DPMI service
    jc  near ptr IZITDPMI_DONE ; Jump if something went wrong

    mov LMBADDR,ebx ; Save for later use
    mov LMBHNDL,esi ; ...

    xor edx,edx     ; Zero to use as dword
    DOSCALL @STROUT,MSG_BP3 ; Tell 'em the good news

; Display LMB info

    push    LMBHNDL     ; Pass the handle
    push    LMBADDR     ; ...      address
    push    ds      ; ...  ptr to format string
    push    offset ds:MSG_LMB ; ...
    call    PRINTF16    ; Printf the arguments
    add sp,3*4      ; Strip from the stack

; Free the memory

    mov si,LMBHNDL.EHI  ; SI:DI ==> memory block handle
    mov di,LMBHNDL.ELO  ; ...
    DPMICALL @DPMI_RELMEM   ; Release the memory block
    jc  short IZITDPMI_DONE ; Jump if something went wrong

; Allocate some Uncommitted Memory

    xor ebx,ebx     ; No special address
    xor edx,edx     ; Uncommitted Memory
    mov ecx,4*1024  ; A single 4KB page
    mov esi,-1      ; Known value
    DPMICALL @DPMI_GETLMB   ; Request DPMI service
    jc  short IZITDPMI_DONE ; Jump if something went wrong

    mov LMBADDR,ebx ; Save for later use
    mov LMBHNDL,esi ; ...

    xor edx,edx     ; Zero to use as dword
    DOSCALL @STROUT,MSG_BP3 ; Tell 'em the good news

; Display LMB info

    push    LMBHNDL     ; Pass the handle
    push    LMBADDR     ; ...      address
    push    ds      ; ...  ptr to format string
    push    offset ds:MSG_LMB ; ...
    call    PRINTF16    ; Printf the arguments
    add sp,3*4      ; Strip from the stack

; Trigger a page fault

    mov gs,SEL4GB   ; Address it
    assume  gs:AGROUP   ; Tell the assembler about it

    mov ebx,LMBADDR ; Get LMB address
IZITDPMI_FAULT:
    mov eax,AGROUP:[ebx] ; Trigger a Page Fault
IZITDPMI_NEXT:
    xor edx,edx     ; Zero to use as dword
    DOSCALL @STROUT,MSG_BP4 ; Tell 'em the good news
IZITDPMI_DONE:
    mov ERRCODE,1   ; Set error code

; Restore the original handlers

    mov cx,OLDINT0D_FVEC.FSEL ; CX:EDX ==> old handler
    mov edx,OLDINT0D_FVEC.FOFF ; ...
    mov bl,0Dh      ; GP Fault
    DPMICALL @DPMI_SETPEHVWIN ; Request DPMI service
    DPMICALL @DPMI_SETPEHV  ; Request DPMI service

    mov cx,OLDINT0E_FVEC.FSEL ; CX:EDX ==> old handler
    mov edx,OLDINT0E_FVEC.FOFF ; ...
    mov bl,0Eh      ; Page Fault
    DPMICALL @DPMI_SETPEHVWIN ; Request DPMI service
    DPMICALL @DPMI_SETPEHV  ; Request DPMI service

; Free the LMB

    mov si,LMBHNDL.EHI  ; SI:DI ==> memory block handle
    mov di,LMBHNDL.ELO  ; ...
    DPMICALL @DPMI_RELMEM   ; Release the memory

    jmp short IZITDPMI_EXIT ; Join common exit code


IZITDPMI_ERRPM:
    DOSCALL @STROUT,MSG_ERRPM ; Tell 'em the news

    jmp short IZITDPMI_ERRCOM ; Join common error code


IZITDPMI_NOTPRES:
    DOSCALL @STROUT,MSG_DPMINO ; Tell 'em the news
IZITDPMI_ERRCOM:
    mov ERRCODE,0   ; Set error code
IZITDPMI_EXIT:
    mov al,ERRCODE  ; Get error code
    DOSCALL @EXITRC     ; Return to DOS

    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

IZITDPMI endp           ; End IZITDPMI procedure
    FPPROC  LCL_INT0D -- Local GP Fault Handler
    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Local GP Fault handler

On entry:

On exit:

|

I0D_STR struc

    db  (type PUSHAD_STR)  dup (?) ; Caller's EGP registers
    dd  ?       ; Caller's return EIP
    dw  ?,?     ; ...         CS w/filler
I0D_ERR dd  ?       ; Error code
I0D_EIP dd  ?       ; Faulting EIP
I0D_CS  dw  ?,?     ; ...      CS w/filler
I0D_EFL dd  ?       ; EFL
I0D_ESP dd  ?       ; ESP
I0D_SS  dw  ?,?     ; ...      SS w/filler

I0D_STR ends


    pushad          ; Save all EGP registers
    mov ebp,esp     ; Address the stack

    REGSAVE <ds,es>     ; Save registers

; Display the contents of the stack

    mov ds,DATASEL  ; Address the data
    assume  ds:PGROUP   ; Tell the assembler about it

    mov es,DATASEL  ; Address the data
    assume  es:PGROUP   ; Tell the assembler about it

    DOSCALL @STROUT,MSG_I0D ; Tell 'em the good news

; Display the contents of the stack

    mov ecx,16+8    ; # dwords to display
    mov esi,ebp     ; SS:ESI ==> start of display
@@:
    push    ss:[esi].EDD    ; Pass next dword
    push    esi     ; ...  offset
    push    ss      ; ...  selector
    push    ds      ; ...  ptr to format string
    push    offset ds:MSG_DD ; ...
    call    PRINTF16    ; Printf the arguments
    add sp,4+2+4+4  ; Strip from the stack

    add esi,4       ; Skip to next dword

    loop    @B      ; Jump if more dwords to display




    push    [ebp].I0D_ERR   ; Pass error code
    push    [ebp].I0D_ESP   ; ...  ptr to SS:ESP
    push    [ebp].I0D_SS    ; ...
    push    [ebp].I0D_EFL   ; ...  EFL
    push    [ebp].I0D_EIP   ; Pass ptr to CS:EIP
    push    [ebp].I0D_CS    ; ...

    push    ds      ; ...  ptr to format string
    push    offset ds:MSG_EXCP ; ...
    call    PRINTF16    ; Printf the arguments
    add sp,4+6+4+6+4    ; Strip from the stack







; Restore the original handler

    mov cx,OLDINT0D_FVEC.FSEL ; CX:EDX ==> old handler
    mov edx,OLDINT0D_FVEC.FOFF ; ...
    mov bl,0Dh      ; GP Fault
    DPMICALL @DPMI_SETPEHV  ; Request DPMI service

; If it's at IZITDPMI_FAULT, continue with IZITDPMI_NEXT

    cmp [ebp].I0D_EIP,offset cs:IZITDPMI_FAULT ; Izit our fault?
    clc         ; Assume not
    jne short LCL_INT0D_NEXT ; Jump if not (note CF=0)

    mov [ebp].I0D_EIP,offset cs:IZITDPMI_NEXT ; Skip over it

    stc         ; Mark as continuing on
LCL_INT0D_NEXT:
    REGREST <es,ds>     ; Restore
    assume  ds:nothing  ; Tell the assembler about it
    assume  es:nothing  ; Tell the assembler about it

    popad           ; Restore
    jc  short @F    ; Jump if we're continuing on

    jmp OLDINT0D_FVEC   ; Continue with next handler


@@:
    retfd           ; Return to caller

    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

LCL_INT0D endp          ; End LCL_INT0D procedure
    FPPROC  LCL_INT0E -- Local Page Fault Handler
    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Local Page Fault handler

On entry:

On exit:

|

I0E_STR struc

    db  (type PUSHAD_STR)  dup (?) ; Caller's EGP registers
    dd  ?       ; Caller's return EIP
    dw  ?,?     ; ...         CS w/filler
I0E_ERR dd  ?       ; Error code
I0E_EIP dd  ?       ; Faulting EIP
I0E_CS  dw  ?,?     ; ...      CS w/filler
I0E_EFL dd  ?       ; EFL
I0E_ESP dd  ?       ; ESP
I0E_SS  dw  ?,?     ; ...      SS w/filler

I0E_STR ends


    pushad          ; Save all EGP registers
    mov ebp,esp     ; Address the stack

    REGSAVE <ds,es>     ; Save registers

; Display the contents of the stack

    mov ds,DATASEL  ; Address the data
    assume  ds:PGROUP   ; Tell the assembler about it

    mov es,DATASEL  ; Address the data
    assume  es:PGROUP   ; Tell the assembler about it


    DOSCALL @STROUT,MSG_I0E ; Tell 'em the good news

; Display the contents of the stack

    mov ecx,16+8    ; # dwords to display
    mov esi,ebp     ; SS:ESI ==> start of display
@@:
    push    ss:[esi].EDD    ; Pass next dword
    push    esi     ; ...  offset
    push    ss      ; ...  selector
    push    ds      ; ...  ptr to format string
    push    offset ds:MSG_DD ; ...
    call    PRINTF16    ; Printf the arguments
    add sp,4+2+4+4  ; Strip from the stack

    add esi,4       ; Skip to next dword

    loop    @B      ; Jump if more dwords to display




    push    [ebp].I0D_ERR   ; Pass error code
    push    [ebp].I0D_ESP   ; ...  ptr to SS:ESP
    push    [ebp].I0D_SS    ; ...
    push    [ebp].I0D_EFL   ; ...  EFL
    push    [ebp].I0D_EIP   ; Pass ptr to CS:EIP
    push    [ebp].I0D_CS    ; ...

    push    ds      ; ...  ptr to format string
    push    offset ds:MSG_EXCP ; ...
    call    PRINTF16    ; Printf the arguments
    add sp,4+6+4+6+4    ; Strip from the stack











; Restore the original handler

    mov cx,OLDINT0E_FVEC.FSEL ; CX:EDX ==> old handler
    mov edx,OLDINT0E_FVEC.FOFF ; ...
    mov bl,0Eh      ; Page Fault
    DPMICALL @DPMI_SETPEHV  ; Request DPMI service

; If it's at IZITDPMI_FAULT, continue with IZITDPMI_NEXT

    cmp [ebp].I0E_EIP,offset cs:IZITDPMI_FAULT ; Izit our fault?
    clc         ; Assume not
    jne short LCL_INT0E_NEXT ; Jump if not (note CF=0)

    mov [ebp].I0E_EIP,offset cs:IZITDPMI_NEXT ; Skip over it

    stc         ; Mark as continuing on
LCL_INT0E_NEXT:
    REGREST <es,ds>     ; Restore
    assume  ds:nothing  ; Tell the assembler about it
    assume  es:nothing  ; Tell the assembler about it

    popad           ; Restore
    jc  short @F    ; Jump if we're continuing on

    jmp OLDINT0E_FVEC   ; Continue with next handler


@@:
    retfd           ; Return to caller

    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

LCL_INT0E endp          ; End LCL_INT0E procedure
    NPPROC  CheckDPMI -- Check On DPMI Services
    assume  ds:PGROUP,es:PGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Check on DPMI services

On exit:

CF  =   0 if successful
    =   1 if not

|

    pusha           ; Save all GP registers
    push    es      ; Save

    mov ax,@DPMI_GPME   ; Function code to detect DPMI servcices
    int 2Fh     ; Request multiplexor services
    assume  es:nothing  ; Tell the assembler about it
                ; On return
                ;   AX    =   0 (if present)
                ;   BX    =   flags -- Bit 0: 1 = 32-bit apps supported
                ;   CL    =   CPU type (02 = 286, 03 = 386, 04 = 486, etc.)
                ;   DH    =   DPMI major version # (in decimal)
                ;   DL    =   ...  minor ...
                ;   SI    =   # paras in host private data area
                ;   ES:DI ==> VM -> PM entry point
    and ax,ax       ; Izit present?
    stc         ; Assume not
    jnz short CheckDPMIExit ; Jump if not

    mov DPMIDRV_VEC.VSEG,es ; Save for later use
    mov DPMIDRV_VEC.VOFF,di ; ...
    mov DPMI_HPDA,si    ; ...
    xchg    dl,dh       ; Swap for PRINTF
    mov DPMI_VER,dx ; ...
    mov DPMI_CPU,cl ; ...
    mov DPMI_FLAG,bx    ; ...

    clc         ; Mark as successful
CheckDPMIExit:
    pop es      ; Restore
    assume  es:nothing  ; Tell the assembler about it
    popa            ; ...

    ret         ; Return to caller

    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

CheckDPMI endp          ; End CHECK_DPMI procedure

NCODE   ends            ; End NCODE segment


NCODZ   segment use16 para public 'code' ; Start NCODZ segment
    assume  ds:PGROUP

    public  ZTAIL
ZTAIL   label   dword

NCODZ   ends            ; End NCODZ segment



DATA    segment use16 dword public 'data' ; Start DATA segment
DATA    ends            ; End DATA segment



STACK   segment use16 para stack 'data' ; Start STACK segment
    assume  ds:DGROUP

    public  LCLSTK,LCLSTKZ
LCLSTK  dw  (4*1024) dup (?) ; Local stack
LCLSTKZ label   word        ; End of ...

STACK   ends            ; End STACK segment

    MEND    INITIAL     ; End IZITDPMI module
