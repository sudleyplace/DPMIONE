;' $Header$
	title	DPMI_PPM -- DPMI.LOD Physical Page Manager functions
	page	58,122
	name	DPMI_PPM
COMMENT|		Module Specifications

********************************* QUALITAS ***********************************
******************************* CONFIDENTIAL *********************************

Copyright:  (C) Copyright 1987-2003 Sudley Place Software.  All Rights Reserved.

|
.386p
.xlist
	include MASM.INC
	include 386.INC
	include MASM5.MAC
	include ALLMEM.INC
	include PTR.INC

	include QMAX_EMM.INC

	include DPMI_COM.INC
	include DPMI_DTE.INC
	include DPMI_SEG.INC
	include DPMI_SWT.INC
.list

PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	extrn	ALLOCMEM:near
	extrn	DEALLOCMEM:near
	extrn	QRY_PGCNT:near

PROG	ends			; End PROG segment


DATA	segment use32 dword public 'data' ; Start DATA segment
	assume	ds:DGROUP

	public	@DPMI_PPM_DATA
@DPMI_PPM_DATA	label byte	; Mark module start in .MAP file

	extrn	LCL_FLAG:word
	include DPMI_LCL.INC

	extrn	VMM_FLAG:word
	include QMAX_VMM.INC

	extrn	PHYSIZE:dword
	extrn	SEL_DATA:word
	extrn	SEL_4GB:word

	extrn	VMMCurrentClient:word	 ; id of current client
	extrn	VMMCurrentTime:word	 ; current paging time
	extrn	BSTotal:dword		 ; amount of total backing store
	extrn	BSInUse:dword		 ; amount of backing store in use
	extrn	BSActive:byte		 ; swapping (and page-aging)started
	extrn	VirtualReserved:dword	 ; number of reserved virtual pages

	public	PhysicalLocked, PhysicalMinUnlocked, PhysicalTotal
	public	PhysicalInUse, nRegions, RegionTable, PhysicalManaged
	public	PhysicalSwappable, PhysicalFreeListHead

PPMinitialized		db	0	; initialized flag

PhysicalLocked		dd	?	; number of physical pages
					;  currently locked
PhysicalMinUnlocked	dd	?	; min number of physical pages
					;  that must be kept unlocked
PhysicalFreeListHead	dd	?	; head of physical free list
					; -1 if list is empty
PhysicalTotal		dd	?	; total page count for system
PhysicalManaged 	dd	0	; number of physical pages currently
					;   managed by PPM
PhysicalInUse		dd	?	; number of managed pages currently
					;   in use (by clients and system)
nRegions		db	?	; number of contiguous regions
PhysicalSwappable	dd	?	; number of in-use swappable pages

	public	TotalPPRSize,PPRBaseAddress
TotalPPRSize		dd	?	; size (bytes) of PhysicalPageRecord
					;    array (/4KB)
PPRBaseAddress		dd	?	; base address of PPR array

NeedToFillPool		db	?	; flag: call primary mgr for memory


RegionTable	PhysicalRegion @MAXREGIONS dup (<0,0,0>)

PrimaryAllocInProg db 0 	; Primary allocate in progress flag

DATA	ends			; End DATA segment


PROG	segment use32 byte public 'prog' ; Start PROG segment
	assume	cs:PGROUP

	public	@DPMI_PPM_PROG
@DPMI_PPM_PROG: 		; Mark module start in .MAP file

	extrn	VMM_SWAP_OUT:near

;;;	    NPPROC  Lin2PTE -- Convert Linear Address To PTE
;;;	    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;; COMMENT|
;;;
;;; Convert linear address to PTE taking 4MB pages into account
;;;
;;; On entry:
;;;
;;; SS:ESP  ==>     Lin2PTE_STR
;;;
;;; On exit:
;;;
;;; SS:[ESP].Lin2PTE_Lin = PTE
;;; CF	    =	    0 if successful
;;;	    =	    1 if not
;;;
;;; |
;;;
;;; Lin2PTE_STR struc
;;;
;;;	    dd	    ?		    ; Caller's EBP
;;;	    dd	    ?		    ; ...      EIP
;;; Lin2PTE_Lin dd  ?		    ; Linear address to convert
;;;
;;; Lin2PTE_STR ends
;;;
;;;	    push    ebp 	    ; Prepare to address the stack
;;;	    mov     ebp,esp	    ; Hello, Mr. Stack
;;;
;;;	    pushad		    ; Save registers
;;;	    REGSAVE <ds,es>	    ; Save for a moment
;;;
;;;	    SETDATA ds		    ; Get DGROUP data selector
;;;	    assume  ds:DGROUP	    ; Tell the assembler about it
;;;
;;;	    mov     es,SEL_4GB	    ; Get AGROUP data selector
;;;	    assume  es:AGROUP	    ; Tell the assembler about it
;;;
;;;	    mov     edx,[ebp].Lin2PTE_Lin ; Get the linear address
;;;	    MakePDEaddress edx	    ; edx ==> PDE
;;;
;;;	    test    AGROUP:[edx].EDD,mask $PTE_PS ; Izit a 4MB page?
;;;	    jz	    short Lin2PTE1  ; Jump if not
;;;
;;;	    SWATMAC	 
;;;
;;; ; Allocate a PDE and fill in the PTEs
;;;
;;;	    push    @ALLOC_VCPI 	    ; Will look like a VCPI alloc
;;;	    push    @PageSize		    ; Push size to allocate
;;;	    call    ALLOCMEM		    ; Returns linear addr in EBX
;;; ;;;;;;; mov     ax,@DERR_INSUFF_PHYS    ; Return error code
;;;	    jc	    short Lin2PTE_EXIT	    ; Carry set on fail
;;;
;;; ; Setup the PTEs for this 4MB page
;;;
;;;	    mov     edi,ebx	    ; Copy linear address
;;;	    mov     ecx,1024	    ; # PTEs in a pge
;;;	    mov     eax,AGROUP:[edx] ; eax <- PDE
;;;	    and     eax,mask $LA_DIR ; Isolate the 4MB frame
;;;	    or	    eax,(mask $PTE_RW) or (mask $PTE_P) ; Mark as Read-write/Present
;;;				    ; Supervisor
;;; @@:
;;;	    stos    AGROUP:[edi].EDD ; Save physical address
;;;	    add     eax,@PageSize   ; Skip to next PTE
;;;	    loop    @B		    ; Jump if more pages
;;;
;;; ; Save the new PDE
;;;
;;;	    mov     eax,edi	    ; Copy linear address
;;;
;;; ; Translate from linear to physical *FIXME*
;;;
;;;	    mov     AGROUP:[edx].EDD,eax ; Save new PDE
;;;
;;;	    jmp     short Lin2PTE2  ; Join common code
;;;
;;;
;;; Lin2PTE1:
;;;	    mov     eax,[ebp].Lin2PTE_Lin ; Get the linear address
;;;	    shr     eax,10	    ; Convert from bytes to 4KB
;;;	    or	    eax,@PTBase     ; Include the PTE base
;;;	    and     eax,not 3	    ; Round down to dword boundary
;;; Lin2PTE2:
;;;	    mov     [ebp].Lin2PTE_Lin,eax ; Save as return value
;;;
;;;	    clc 		    ; Mark as successful
;;; Lin2PTE_EXIT:
;;;	    REGREST <es,ds>	    ; Restore
;;;	    assume  ds:nothing,es:nothing ; Tell the assembler about it
;;;	    popad		    ; Restore
;;;
;;;	    pop     ebp 	    ; Restore
;;;
;;;	    ret 		    ; Return to caller
;;;
;;;	    assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
;;;
;;; Lin2PTE endp		    ; End Lin2PTE procedure
	NPPROC	PPM_GET_PAGE_RECORD -- Get address of page record
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Locate physical page record for a given page. This routine just walks
the region table until it finds the region in which the specified page
resides, then makes an arithmetic calculation to determine the address
of the PhysicalPageRecord.

On entry:

EBX	=	physical address of page for which to get record

On exit:

ESI	=	linear address of physical page record

|

	REGSAVE <eax,ebx,ecx,edi> ; Save registers

	movzx	ecx,nRegions	; Pick up region count
	lea	edi,RegionTable ; Point at region table
	and	ebx,not $clientMask ; Discard low bits
PPM_GPR_NEXTREGION:
	mov	esi,ebx 	; Copy physical address

	sub	esi,DGROUP:[edi].PRbase ; ESI <- input addr less region base
	jb	short PPM_GPR_LOOP ; Jump if page below this region

	shr	esi,@BytePage	; ESI <- page count of offset

	cmp	esi,DGROUP:[edi].PRsize ; In this region?
	jb	short PPM_GPR_EXIT ; Jump if so
PPM_GPR_LOOP:
	add	edi,size PhysicalRegion ; Try next region

	loop	PPM_GPR_NEXTREGION ; Go again
PPM_GPR_FAIL:
	SWATMAC ERR		; Shouldn't happen

	jmp	short PPM_GPR_FAIL ; Tried all regions - didn't find it


PPM_GPR_EXIT:
	imul	esi,size PhysicalPageRecord ; Times record size to get offset
	add	esi,DGROUP:[edi].PRtable ; Add table base to get address of rec

	REGREST <edi,ecx,ebx,eax> ; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PPM_GET_PAGE_RECORD endp	; End PPM_GET_PAGE_RECORD procedure
	NPPROC	PPM_SETPHYSMU -- Set PhysicalMinUnlocked
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Set PhysicalMinUnlocked.

Use a value for PhysicalMinUnlocked which is the smaller of @PhysMin
and PhysicalManaged/2.	That way we can fail less often in a starved
memory configuration as some DPMI clients (MS C7) don't correctly
handle failure of the switch entry point.  Furthermore, this value
must be at least as large as the minimum number of pages which can be
touched by a single instruction.  By my count this is 6 for (say) a
CALL Dword ptr [....] which references two pages via the Dword ptr,
two pages to push the address onto the stack, and two pages for the
first instruction in the new routine.  Note that we're assuming that
the GDT/LDT are in locked memory, otherwise we need to add three more
pages to this count.

|

	REGSAVE <eax>		; Save register

@PhysMinMax equ 16		; Maximum value for PhysicalMinUnlocked
@PhysMinMin equ   6		; Minimum ...

	mov	eax,PhysicalManaged ; Get # pages managed
	shr	eax,1		; Divide by two to compare

	cmp	eax,@PhysMinMax ; Izit smaller than we ever thought reasonable?
	jb	short @F	; Jump if so

	mov	eax,@PhysMinMax ; Use maximum working set
@@:
	cmp	eax,@PhysMinMin ; Izit no worse than our minimum?
	jae	short @F	; Jump if so

	mov	eax,@PhysMinMin ; Use minimum working set
@@:
	mov	PhysicalMinUnlocked,eax ; Save as minimum working set

	REGREST <eax>		; Restore

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PPM_SETPHYSMU endp		; End PPM_SETPHYSMU procedure
	NPPROC	PPM_INIT -- Initialize Physical Page Manager
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Initialize Physical Page Manager

This function has two things to get done:

(1) It must set up the RegionTable, which is an array of
PhysicalRegion structures.  The first entry always corresponds
to the contiguous physical memory starting at zero.

(2) It must allocate and zero out pages for the PhysicalPageRecords.
The number of pages depends on the total size of physical memory.

On exit:

CF	=	0 ==> ok
	=	1 ==> failure
AX	=	error code

|

	REGSAVE <ebx,ecx,edx,esi,edi,es> ; Save registers

; Initialize the free list for physical memory.  There are no
; pages actually in the list until PPM_FILL_POOL is called.

	mov	PhysicalFreeListHead,-1 ; free list initially empty
	xor	eax,eax 		; make a zero
	mov	PhysicalManaged,eax	; init location
	mov	PhysicalInUse,eax	; ...
	mov	PhysicalSwappable,eax	; ...
	mov	PhysicalLocked,eax	; ...
					; Build the RegionTable
	mov	eax,PHYSIZE		; Pick up total machine size in bytes
	add	eax,4*1024-1		; Round up to 4KB
;;;;;;; and	eax,not (4*1024-1)	; ...boundary
	shr	eax,12-0		; Convert from bytes to 4KB
	mov	PhysicalTotal,eax	; Size in pages of contiguous RAM
					;   starting at physical address 0
	mov	nRegions,1		; Init region count
	xor	edi,edi 		; Initialize index into region table
	mov	RegionTable[edi].PRbase,0 ; Base is addr 0
	mov	RegionTable[edi].PRsize,eax ; EAX == PhysicalTotal

	imul	eax,PhysicalTotal,size PhysicalPageRecord ; Get total page
					; count in bytes
	add	eax,@PageSize-1 	; Round up to page
	and	eax,not (@PageSize-1)	; EAX <- size of PPRs in bytes
	mov	TotalPPRSize,eax	; Remember it for shutdown

; Now allocate the memory

	push	@ALLOC_VCPI		; Will look like a VCPI alloc
	push	eax			; Push size to allocate
	call	ALLOCMEM		; Returns linear addr in EBX
	mov	ax,@DERR_INSUFF_PHYS	; Return error code
	jc	short PPM_INIT_EXIT	; Carry set on fail

; Now set up each region with the correct base address for its PPR array

	mov	PPRBaseAddress,ebx	; Remember this for shutdown
	movzx	ecx,nRegions		; Init region counter
	xor	edi,edi 		; Initialize index into region table
PPM_INIT_REGION_BASE:
	mov	RegionTable[edi].PRtable,ebx ; Set table address for region

; Now calculate base of next region based on size of this region

	imul	eax,RegionTable[edi].PRsize,size PhysicalPageRecord
					 ; EAX <- size of region in pages
	add	ebx,eax 		 ; Table base for next region
	add	edi,size PhysicalRegion  ; Advance to next record

	loop	PPM_INIT_REGION_BASE	 ; do next if not done

; Now zero out the PPR array

	mov	es,SEL_4GB		 ; es <- AGROUP (all memory)
	assume	es:AGROUP		 ; tell assembler

	mov	edi,PPRBaseAddress	 ; edi <- base of PPR array
	mov	ecx,TotalPPRSize	 ; ecx <- size of PPRs in bytes (/4KB)
	shr	ecx,2			 ; ecx <- size of PPRs in dwords
	xor	eax,eax 		 ; eax <- zero
	cld
    rep stos	AGROUP:[edi].EDD	 ; zero out the PPR array
PPM_INIT_DONE:
	mov	PrimaryAllocInProg, 0	 ; set location
	mov	PPMinitialized, 1	 ; ...
	mov	NeedToFillPool, 1	 ; flag fill of page pool needed
	call	PPM_SETPHYSMU	; Set PhysicalMinUnlocked

	clc			; Success
PPM_INIT_EXIT:
	REGREST <es,edi,esi,edx,ecx,ebx> ; Restore regs
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PPM_INIT endp			; End PPM_INIT procedure
	NPPROC	PPM_ALLOC -- Allocate a physical page
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Allocate a physical page. The PhysicalPageRecords for
free pages are linked in a list headed by PhysicalFreeListHead.

On entry:

EAX	=	virtual address of page
		LSB of address has the following sense:
EDX	=	$canSwap

On exit:

EBX	=	physical address of allocated page
		if EBX == -1 on exit, no page could be allocated

|
	REGSAVE <eax, ecx, esi, es>	; save registers

	mov	ebx, PhysicalFreeListHead ; physical address of next free page
	cmp	ebx, -1 		; at end of list?
	jne	short PPM_ALLOC_GO	; do alloc if not at end of list

	mov	ecx, PhysicalTotal	; get total page count
	call	PPM_FILL_POOL		; get pages from base memory manager
	mov	ebx, PhysicalFreeListHead ; try again

	cmp	ebx, -1 		; end of list?
	je	PPM_ALLOC_EXIT		; give up if so
PPM_ALLOC_GO:				; ebx is physical address of free page
	mov	es,SEL_4GB		; es <- AGROUP
	assume	es:AGROUP		; Tell the assembler about it

	call	PPM_GET_PAGE_RECORD	; esi <- page record linear address

	and	eax, not $clientMask	; insert current client into vaddr
	or	ax, VMMCurrentClient	; ...

	xchg	es:[esi].PPaddr, eax	; eax <- free link, PPaddr <- vaddr
	mov	PhysicalFreeListHead, eax  ; set location
	or	es:[esi].PPflags, mask $alloced ; this page is allocated

	test	edx, mask $canSwap	; test swappable argument
	jz	short @F		; jump if not swappable

	or	es:[esi].PPflags, mask $swappable ; page is swappable
	inc	PhysicalSwappable	; bump count of swappable pages
@@:
	mov	es:[esi].PPlocks, 0	; zero lock count
	mov	ax, VMMCurrentTime	; get current VMM time
	mov	es:[esi].PPusage, ax	; make the page new, timewise

; If we have not started swapping yet, increment the timer so
; that pages allocated before swapping starts are differentiated
; by age.

	cmp	BSActive, 0		; have we started swapping?
	je	short @F		; jump if not

	add	VMMCurrentTime, 10h	; advance the clock
@@:
	inc	PhysicalInUse		; inc count of physical pages in use

	and	ebx, not $clientMask	; clear out low bits
PPM_ALLOC_EXIT:
	REGREST <es, esi, ecx, eax>	 ; restore regs
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PPM_ALLOC endp			; End of PPM_ALLOC procedure
	NPPROC	PPM_FREE -- Free a physical page
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Free a physical page.  To do this, update the PhysicalPageRecord
of the free page (clear flags), update system counts (locked,
swappable), and link the page into the free list.

On entry:

EBX	=	physical address of page to free

|

	REGSAVE <es,esi,eax,ebx>	; Save registers

	mov	es,SEL_4GB		; ES <- AGROUP
	assume	es:AGROUP		; Tell the assembler about it

	call	PPM_GET_PAGE_RECORD	; ESI <- page record linear address

	test	es:[esi].PPflags, mask $managed ; verify this is valid to free
	jnz	short @F		; Jump if page managed

	SWATMAC ERR			; Freeing an unmanaged page
@@:
	test	es:[esi].PPflags, mask $alloced ; is page allocated?
	jnz	short @F		; Jump if so

	SWATMAC ERR			; Freeing an unallocated page
@@:
	cmp	es:[esi].PPlocks, 0	; Was page locked?
	jz	short @F		; Jump if not

	dec	PhysicalLocked		; Decrement locked total
@@:
	test	es:[esi].PPflags, mask $swappable ; Was page swappable?
	jz	short @F		; Jump if not

	dec	PhysicalSwappable	; Decrement count of swappable pages
@@:
	and	es:[esi].PPflags, \
		       not (mask $alloced OR mask $swappable OR mask $marked)
	mov	eax,PhysicalFreeListHead ; Get head
	mov	es:[esi].PPaddr,eax  ; Old head follows freed page

	and	ebx, not $clientMask ; Clear out low bits
	mov	PhysicalFreeListHead,ebx ; Set new head

	dec	PhysicalInUse	; Dec count of phys pages in use

	REGREST <ebx,eax,esi,es> ; Restore registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
PPM_FREE endp			; End of PPM_FREE procedure
	NPPROC PPM_QUERY -- Query number of free pages
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Determine the number of free pages

On exit:

EAX	=	Number of currently available physical pages. Fills the
		pool.

|

	REGSAVE <ecx>			; save register

	cmp	NeedToFillPool, 0	; has page pool been drained?
	je	short @F		; jump if not

	mov	ecx,PhysicalTotal	; get total physical page count
	call	PPM_FILL_POOL		; fill the pool from primary mgr
@@:
	mov	eax, PhysicalManaged	; eax <- count of managed pages
	sub	eax, PhysicalInUse	; eax <- available pages

	REGREST <ecx>			; restore registers

	ret				; return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PPM_QUERY endp				; end of PPM_QUERY procedure
	NPPROC PPM_QUERY_SWAPPABLE -- Query number of swappable pages
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT| Get the number of swappable pages

On exit:
EAX	=	number of currently in-use but swappable pages
|
	; swappable = min(PhysicalSwappable, BSFree)

	mov	eax, BSTotal		; eax <- total number of BS pages
	sub	eax, BSInUse		; eax <- available BS pages
	cmp	eax, PhysicalSwappable	; compare to physical swappable
	jb	short @F		; jump if fewer BS pages than swappable
	mov	eax, PhysicalSwappable	; max is swappable count
@@:
	ret				; return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PPM_QUERY_SWAPPABLE endp	; End of PPM_QUERY_SWAPPABLE procedure
	NPPROC PPM_DRAIN_POOL -- Move pages to primary (XMS/EMS) manager
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT| Release free pages in page pool to primary allocator

On entry:
ECX	=	number of pages to release

On exit:
ECX	=	number of pages actually released

|
	cmp	PrimaryAllocInProg, 0	; if not doing a primary allocate
	je	short @F		; proceed with normal processing

	xor	ecx, ecx		; zero pages moved

	ret				; else never mind


@@:
	REGSAVE <eax, ebx, edx, esi, es>	; save registers

; We might be called before any memory has been allocated.  If so,
; skip out early

	cmp	PhysicalManaged,0	; Izit available?
	je	near ptr PPM_DRAIN_ZERO; Jump if none

; We have to careful about how many pages we release, because some may
; in fact be committed. The reservation mechanism used for virtual memory
; allocation assumes that it can get virtual storage on demand, up to
; certain limits.  Some of this virtual storage may be in backing store,
; so the calculation of how much physical memory to free depends on how
; much backing store is available, how much virtual memory has been
; reserved (committed but not assigned to either physical memory or backing
; store) and, finally, on how much free physical memory there is.
;
; The logic is:
;
;	if (VirtualReserved > BackFree) i.e. if backing store doesn't cover
;						amount reserved
;	{
;		canDrain = PhysicalFree - (VirtualReserved - BackFree);
;		willDrain = min(request, canDrain);
;	}
;
; Even if no virtual memory is reserved, there are still constraints. We
; cannot drain more than is currently free, nor can we let the number of
; unlocked pages fall below the minimum threshold. The logic continues:
;
;	willDrain = min(willDrain, PhysicalManaged-PhysicalInUse);
;	willDrain = min(willDrain, PhysicalManaged-PhysicalLocked-
;							PhysicalMinUnlocked);

	and	VMM_FLAG,not @VMM_MUSTDRAIN ; Mark as no longer needed
PPM_DRAIN_BEGIN:
	mov	esi, ecx		; save request size
	mov	eax, BSTotal		; compute BackFree=BSTotal-BSInUse
	sub	eax, BSInUse		; eax <- available bs pages

	cmp	VirtualReserved, eax	; see if physical pages are needed
	jb	short PPM_DRAIN_CHECK_FREE; jump if there are enough bs pages

	add	eax, PhysicalManaged
	sub	eax, PhysicalInUse	; eax=PhysicalFree+BackFree

	sub	eax, VirtualReserved	; compute PhysicalFree+BackFree-VirtualReserved
	jbe	PPM_DRAIN_ZERO		; jump if can't drain

	cmp	eax, ecx		; if this quantity less than requested
	jae	short @F		;  amount to drain, then set new

	mov	ecx, eax		;  request to this quantity
@@:
PPM_DRAIN_CHECK_FREE:			; check request against free pages
	mov	eax, PhysicalManaged	; compute eax = PhysManaged-PhysInUse
	sub	eax, PhysicalInUse

	cmp	eax, ecx		; do min() operation
	jae	short @F

	mov	ecx, eax		; ecx <- min(requested,free)
@@:					; now check againt lock constraints
	mov	eax, PhysicalManaged	; eax <- managed count
	sub	eax, PhysicalLocked	; eax <- managed - locked
	sub	eax, PhysicalMinUnlocked; eax <- managed - locked - min unlock
	jc	short PPM_DRAIN_SWAP	; Jump if not enough pages

	cmp	eax, ecx		; do min operation
	jae	short @F
	mov	ecx, eax		; ...
@@:					; ecx now holds amount that can be
					;   safely drained
	or	ecx,ecx 		; can we drain any?
	jnz	PPM_DRAIN_CAN		; jump if so
PPM_DRAIN_SWAP:

;; If all the pages are in use, try swapping some out

	cmp	PhysicalSwappable,0	; are any pages swappable
	je	PPM_DRAIN_ZERO		; jump if not

	mov	ecx,BSTotal		; calc bs free
	sub	ecx,BSInUse		; ecx <- bs pages free
	cmp	ecx,PhysicalSwappable	; get min(swappable, bsfree)
	jb	short @F		; jump if below

	mov	ecx,PhysicalSwappable	; swappable is min
@@:
	cmp	ecx,PhysicalMinUnlocked ; Leave some pages for swapping in
	jb	PPM_DRAIN_ZERO		; Need at least PhysicalMinUnlocked
	sub	ecx,PhysicalMinUnlocked ; ECX <- new how many to swap out

	cmp	esi,ecx 		; Only need to swap as many as req'ed
	ja	short @F		; Jump if requested more

	mov	ecx,esi 		; Swap out number requested
@@:
	or	ecx,ecx 		; Are there any pages?
	jz	PPM_DRAIN_ZERO		; Jump if not
PPM_DRAIN_PAGEOUT:
	call	VMM_SWAP_OUT		; Free a page

	loop	PPM_DRAIN_PAGEOUT

	mov	ecx,esi 		; Restore request size

	jmp	PPM_DRAIN_BEGIN 	; Try again


PPM_DRAIN_CAN:
	mov	es,SEL_4GB		; ES <- AGROUP
	assume	es:AGROUP		; Tell the assembler about it

	xor	edx,edx 		; Use EDX as counter
	mov	NeedToFillPool, 1	; Flag that we will need a refill
PPM_DRAIN_NEXT:
	cmp	edx,ecx 		; Are we there yet?
	je	short PPM_DRAIN_EXIT	; Jump if so

	mov	ebx,PhysicalFreeListHead ; Get first page in free list

	cmp	ebx,-1			; Is free list empty?
	jne	short @F		; Jump if not

	SWATMAC ERR			; Unexpected end of list
@@:
	call	PPM_GET_PAGE_RECORD	; Get the record for this page

	test	es:[esi].PPflags, mask $swappable ; Is it swappable?
	jz	short @F		; Jump if not

	dec	PhysicalSwappable	; Dec count of swappable pages
@@:
	and	es:[esi].PPflags, not mask $managed ; Un-manage the page
	mov	eax, es:[esi].PPaddr	; Get free link
	mov	PhysicalFreeListHead, eax ; Set new free head

	push	dword ptr @PageSize	; Pass size to deallocate
	push	es:[esi].PPlowAddr	; EAX <- linear address to free
	call	DEALLOCMEM	; Release to primary manager

	dec	PhysicalManaged ; Dec count of managed phys pages

	call	PPM_SETPHYSMU	; Set PhysicalMinUnlocked

	inc	edx		; Inc count of pages released

	jmp	PPM_DRAIN_NEXT	; Go for more


PPM_DRAIN_ZERO:
	xor	ecx,ecx 	; Didn't drain any pages
PPM_DRAIN_EXIT:
	REGREST <es,esi,edx,ebx,eax> ; Restore registers
	assume	es:nothing	; Tell the assembler about it

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PPM_DRAIN_POOL endp		; End PPM_DRAIN_POOL procedure
	NPPROC	PPM_FILL_POOL -- Move pages from primary manager to VMM pool
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Allocate pages from primary allocator; insert into VMM managed pool

On entry:

ECX	=	number of pages to add to pool

On exit:

ECX	=	number of pages added to pool

|

	REGSAVE <eax,ebx,edx,esi,edi,ds,es> ; Save registers

	or	VMM_FLAG,@VMM_MUSTDRAIN ; Mark as needing draining
				; if VCPI app does VM to PM switch
PPM_FILL_POOL_GO:
	push	ecx		; Save the request size

	mov	PrimaryAllocInProg,1 ; Signal for drain pool

	push	@ALLOC_VCPI	; Pass allocation type
	call	QRY_PGCNT	; eax <- available mem in KB
	shr	eax,12-10	; Convert to pages
	mov	edi,eax 	; edi <- pages available

	cmp	eax,ecx 	; Get min of request, available
	ja	short @F

	mov	ecx,eax 	; ecx <- min(available, requested)
@@:

; Now allocate that memory from the primary manager

	shl	ecx,@BytePage	; Convert size to bytes
PPM_FILL_GETMEM:
	or	ecx,ecx 	; Is request non-zero?
	jz	PPM_FILL_POOL_FAIL ; Jump if so

	push	@ALLOC_VCPI	; Pass allocation type
	push	ecx		; ...  # 1KB pages to allocate
	call	ALLOCMEM	; Returns linear addr in EBX
	jnc	short @F	; Jump ahead if succeeded

	shr	ecx,1		; If failed, try for half as much
	and	ecx,not (@PageSize-1) ; Round down to page

	jmp	PPM_FILL_GETMEM


@@:
	mov	eax,ebx 	; EAX <- linear address of block

	mov	es,SEL_4GB	; Set up es with AGROUP
	assume	es:AGROUP	; Tell the assembler about it

	shr	ecx,@BytePage	; Convert size to pages

	push	ecx		; Remember how many pages we got

	sub	edi,ecx 	; EDI <- available - allocated

	jecxz	short PPM_FILL_POOL_DONE

; Walk over the allocated block and process each page.

PPM_FILL_POOL_NEXT:
	mov	ebx,eax 		; EBX <- current linear address
	MakePTEaddress ebx		; EBX <- address of PTE for cur LA

	mov	ebx,AGROUP:[ebx]	; EBX <- PTE
	and	ebx,@PTE_FRM		; Mask off low bits to get phys addr
PPM_FILL_POOL1:
	call	PPM_GET_PAGE_RECORD	; ESI <- page record pointer (AGROUP)

	mov	AGROUP:[esi].PPlowAddr, eax ; Remember low address
	mov	AGROUP:[esi].PPflags, mask $managed
	mov	edx, PhysicalFreeListHead ; Link this page into the chain
	mov	AGROUP:[esi].PPaddr,edx
	mov	PhysicalFreeListHead,ebx ;
	inc	PhysicalManaged

	call	PPM_SETPHYSMU	; Set PhysicalMinUnlocked

	add	eax,@PageSize	; Advance linear address

	loop	PPM_FILL_POOL_NEXT ; Get next
PPM_FILL_POOL_DONE:
	pop	ecx		; Recall page count added

	pop	eax		; Recall request size

	cmp	eax,ecx 	; Did we satisfy the request
	je	short @F	; Jump if yes

	or	edi,edi 	; Is there more available?
	jz	short @F	; Jump if not

	sub	eax,ecx 	; Calc how much more is needed
	mov	ecx,eax 	; Load as arg

	jmp	PPM_FILL_POOL_GO ; Go back for more


@@:
	mov	NeedToFillPool,0 ; Flag that pool has been filled
PPM_FILL_POOL_EXIT:
	mov	PrimaryAllocInProg,0 ; Signal for drain pool

	REGREST <es,ds,edi,esi,edx,ebx,eax> ; restore regs
	assume	ds:nothing,es:nothing ; Tell the assembler about it

	ret			; Return to caller

PPM_FILL_POOL_FAIL:
	pop	ecx		; Discard request size

	xor	ecx, ecx	; No pages moved

	jmp	PPM_FILL_POOL_EXIT ; Exit

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PPM_FILL_POOL endp		; End of PPM_FILL_POOL procedure
	NPPROC PPM_LOCK -- Lock Physical Pages
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Lock a physical page

On entry:

EBX	=	physical address of page to lock

On exit:

AL	=	new lock count

|
	REGSAVE <es, esi>			; save registers

	mov	es,SEL_4GB
	assume	es:AGROUP			; Tell the assembler about it

	call	PPM_GET_PAGE_RECORD		; get the page record

	cmp	es:[esi].PPlocks, 0ffh		; if already at max, quit
	je	short PPM_LOCK_EXIT		; jump if at max lock count

	cmp	es:[esi].PPlocks, 0		; is lock count zero?
	jne	short @F			; jump if not
	inc	PhysicalLocked			; it is a new locked page
@@:
	inc	es:[esi].PPlocks		; increment lock count for page
	test	es:[esi].PPflags, mask $swappable ; was it swappable before?
	jz	short @F			; jump if not
	dec	PhysicalSwappable		; else dec count of swappables
@@:
	and	es:[esi].PPflags, not mask $swappable ; the whole point

PPM_LOCK_EXIT:
	mov	al, es:[esi].PPlocks		 ; return new lock count

	REGREST <esi, es>			 ; restore regs
	assume	es:nothing	; Tell the assembler about it

	ret					 ; return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PPM_LOCK endp			; End PPM_LOCK procedure
	NPPROC PPM_UNLOCK -- Unlock physical page
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT| Unlock a physical page

On entry:
EBX	=	physical address of page to unlock

On exit:
AL	=	new lock count
|
	REGSAVE <esi, es>			; save registers

	mov	es,SEL_4GB			; es <- AGROUP
	assume	es:AGROUP			; Tell the assembler about it
	call	PPM_GET_PAGE_RECORD		; get the page record

	cmp	es:[esi].PPlocks, 0		; if lock count already zero
	je	short PPM_PAGE_UNLOCK_EXIT	;	quit

	dec	es:[esi].PPlocks		; if new count is not zero
	jnz	short PPM_PAGE_UNLOCK_EXIT	;	done
						; else
	or	es:[esi].PPflags, mask $swappable ; page is now swappable
	inc	PhysicalSwappable		; inc swappable count
	dec	PhysicalLocked			; dec locked count

PPM_PAGE_UNLOCK_EXIT:
	mov	al, es:[esi].PPlocks		 ; return new lock count

	REGREST <es, esi>			 ; restore regiseters
	assume	es:nothing	; Tell the assembler about it

	ret					 ; return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PPM_UNLOCK	ENDP		; end of PPM_UNLOCK procedure
	NPPROC PPM_SET_PAGE_OWNER -- Set owner of physical page
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT| Set the owner (client) of a physical page

On entry:
EBX	=	physical address of page
AX	=	client id
|
	REGSAVE <esi, es>			; save registers

	mov	es,SEL_4GB			; es <- AGROUP
	assume	es:AGROUP			; Tell the assembler about it

	call	PPM_GET_PAGE_RECORD		; get the page record

	and	ax, $clientMask 		; just the low bits thanks
	and	word ptr es:[esi].PPaddr, not $clientMask ; clear old owner
	or	word ptr es:[esi].PPaddr, ax	; set new owner

	REGREST <es,esi>			; restore regs

	ret					; return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
PPM_SET_PAGE_OWNER	ENDP		; end of PPM_SET_PAGE_OWNER procedure
	NPPROC PPM_SET_PAGE_ADDRESS -- Set mapped linear address of page
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT| Set the virtual address of a physical page

On entry:
EBX	=	physical address of page
EAX	=	virtual address of page
|
	REGSAVE <esi, es>			; save registers

	mov	es,SEL_4GB			; es <- AGROUP
	assume	es:AGROUP			; Tell the assembler about it

	call	PPM_GET_PAGE_RECORD		; get the page record

	and	eax, not $clientMask		; just the high bits
	and	es:[esi].PPaddr, $clientMask	; clear out old address
	or	es:[esi].PPaddr, eax		; set new address

	REGREST <es,esi>			; restore registers

	ret					; return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
PPM_SET_PAGE_ADDRESS	ENDP		; end of PPM_SET_PAGE_ADDRESS procedure
	NPPROC PPM_AGE_PAGES -- Age the pages
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT| Age the pages

The "age" of page is based on the value in the PPusage field of the
physical page record.  The high 12 bits of this word are the timestamp,
and the low four bits are the "history".

The history bits work as follows: Bit i is set if the page was referenced 4-i
intervals ago.	For example, if the page was referenced in the interval
immediately prior to the interval specified in the timestamp, then bit
3 (=4-1) is set.

The job of this routine is to (1) bump the timestamp, and (2) update the
PPusage words on all pages. NOTE: only pages that belong to the current
client are updated.

|

	REGSAVE <eax, ebx, ecx, edx, esi, edi, ds, es> ; save registers

	SETDATA ds			; Get DGROUP data selector
	assume	ds:DGROUP		; Tell the assembler about it

	mov	es,SEL_4GB		; es <- AGROUP
	assume	es:AGROUP		; Tell the assembler about it

	add	VMMCurrentTime,10h	; advance the "clock"

	movzx	cx, nRegions		; pick up region count
	lea	edi,RegionTable 	; point to region table
PPM_AGE_NEXT_REGION:
	mov	edx,[edi].PRsize	; use edx as page counter for region
	mov	esi,[edi].PRtable	; point to page records for region
	push	cx			; save
	push	di			; ...

	mov	di,VMMCurrentClient	; pick up current client id
	mov	cx,VMMCurrentTime	; pick up current time
PPM_AGE_NEXT_PAGE:
	or	edx,edx 		; done with this region?
	jz	near ptr PPM_AGE_LOOP_REGION ; jump if yes

	mov	al,es:[esi].PPflags	; qualify page state
	and	al,mask $managed OR mask $alloced OR mask $swappable

	cmp	al,mask $managed OR mask $alloced OR mask $swappable
	jne	short PPM_AGE_ADVANCE	 ; jump if not age-able

	mov	ax, word ptr es:[esi].PPaddr	; qualify client
	and	ax, $clientMask 	; isolate client id
	cmp	ax, $clientMask 	; if shared page
	je	PPM_AGE_CHECK_REFER	;   further processing
	cmp	ax, di			; if not current client
	jne	short PPM_AGE_ADVANCE	;   skip

PPM_AGE_CHECK_REFER:
	mov	eax, es:[esi].PPaddr	; get virtual address
	and	eax, not $clientMask	; strip client info
	MakePTEaddress eax		; eax <- address of PTE for page
	btr	byte ptr es:[eax], @AccessBitOrd ; was it touched? (+clear it)
	jnc	PPM_AGE_ADVANCE 	; jump if not

	; if we get here, the page must be updated

	mov	bx, es:[esi].PPusage	; get current usage word
	and	bx, 0fff0h		; mask off history
	mov	ax, cx			; ax <- current time
	sub	ax, bx			; subtract page time
	shr	ax, 4			; ax <- number of interval since last
					;    referenced
	xchg	ax, cx			; cx <- delta , ax <- current time
	cmp	cx, 4			; was reference within history range?
	ja	short PPM_AGE_HISTZERO	; jump if not

	mov	bx, es:[esi].PPusage	; get history bits
	and	bx, 0fh 		; isolate history bits
	or	bl, 10h 		; set bit for this quantum
	shr	bx, cl			; shift by delta since last ref'ed
	or	bx, ax			; new PPusage value with history
	mov	es:[esi].PPusage, bx	; set new usage/history
	jmp	short PPM_AGE_DONE	; continue processing

PPM_AGE_HISTZERO:
	mov	es:[esi].PPusage, ax	; set usage to current time
PPM_AGE_DONE:
	mov	cx, ax			; cx <- current time
PPM_AGE_ADVANCE:
	dec	edx			; dec count of pages in region
	add	esi, size PhysicalPageRecord ; advance to next page

	jmp	PPM_AGE_NEXT_PAGE	; go do next page

PPM_AGE_LOOP_REGION:
	pop	di			; restore
	pop	cx			; ...
	add	di, size PhysicalRegion ; advance to next region
	dec	cx			; dec count of regions left to go
	jnz	PPM_AGE_NEXT_REGION	; continue if more

	REGREST <es, ds, edi, esi, edx, ecx, ebx, eax> ;restore registers
	ret				; return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
PPM_AGE_PAGES	ENDP		; end of PPM_AGE_PAGES procedure
	NPPROC	PPM_GET_LOWADDR -- Get page's address in non-VMM space
	assume	ds:DGROUP,es:AGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Get low address of page, which is stored in the page's PhysicalPageRecord

On entry:

EDX	=	physical address of page
ES	=	all memory selector

On exit:

EDX	=	low address of page

|

	REGSAVE <ebx,esi>	; Save registers

	mov	ebx,edx 	; Copy page address
	call	PPM_GET_PAGE_RECORD ; Look it up

	mov	edx,AGROUP:[esi].PPlowAddr ; Pull out the lowaddr

	REGREST <esi,ebx>	; restore registers

	ret			; return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PPM_GET_LOWADDR endp		; End PPM_GET_LOWADDR procedure
	NPPROC	PPM_SHUTDOWN -- Shutdown the physical page manager
	assume	ds:DGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Shut down the Physical Page Manager

|

	pushad				 ; save all regs
	REGSAVE <es,fs> 		 ; save seg regs

	mov	fs,SEL_DATA		 ; fs <- DGROUP
	assume	fs:DGROUP		 ; tell assembler

; Instead of freeing pages one at time, which is very slow, we try
; to find contiguous linear pages in the PPRs, and free them in a
; block.  The outer loop finds a managed page.	The inner loops
; scan forward to find contiguous linear pages.  When a non-contiguous
; page is found, we call DEALLOCMEM and the non-contiguous page
; becomes the start of the next block.

	mov	esi, PPRBaseAddress	 ; esi <- start addr of PPRs

	mov	es,SEL_4GB		 ; es <- AGROUP
	assume	es:AGROUP

	mov	edx, esi		 ; edx <- ppr base address
	add	edx, TotalPPRSize	 ; edx <- end of PPRs
PPM_SHUT_LOOP1:
	cmp	PhysicalManaged, 0	 ; have all pages been released?
	je	near ptr PPM_SHUT_FREE_PPRS ; jump if yes
@@:
	cmp	esi, edx		 ; are we at the end of the PPRs
	je	near ptr PPM_SHUT_FREE_PPRS ; jump if yes

	test	es:[esi].PPflags, mask $managed ; is this page managed?
	jnz	short @F		 ; jump if yes

	add	esi, size PhysicalPageRecord ; else advance pointer

	jmp	short @B		; and continue

@@:
	xor	ecx, ecx		 ; init byte count to free
	mov	edi, esi		 ; esi will address next mng'd page
PPM_SHUT_LOOP2:
	add	edi, size PhysicalPageRecord ; point to next PPR
	add	ecx, @PageSize		 ; increment byte count to free
PPM_SHUT_FINDNEXT:
	cmp	edi, edx		 ; are we at the end?
	je	short PPM_SHUT_DEALLOCBLOCK ; jump if yes

	test	es:[edi].PPflags, mask $managed ; is this page managed?
	jnz	short @F		 ; jump if yes

	add	edi, size PhysicalPageRecord ; else advance

	jmp	short PPM_SHUT_FINDNEXT

@@:					; here we have the next mng'd page
	mov	eax, es:[esi].PPlowAddr ; get linear address of start page
	add	eax, ecx		 ; add size delta

	cmp	eax, es:[edi].PPlowAddr ; are the pages contigous?
	je	short PPM_SHUT_LOOP2	 ; if yes look for more
PPM_SHUT_DEALLOCBLOCK:			; now deallocate what we've accumulated
	push	ecx			 ; byte size to free
	push	es:[esi].PPlowAddr	 ; start address to free
	call	DEALLOCMEM		; free it

	shr	ecx, @BytePage		 ; convert size to page
	sub	PhysicalManaged, ecx	 ; decrement managed count

	call	PPM_SETPHYSMU	; Set PhysicalMinUnlocked

	mov	esi, edi		 ; advance PPR pointer

	jmp	PPM_SHUT_LOOP1

PPM_SHUT_FREE_PPRS:
	push	TotalPPRSize	; Size to free (/4KB)
	push	PPRBaseAddress	; Address to free
	call	DEALLOCMEM	; Free it
	jnc	short @F	; Should be ok

	SWATMAC ERR		; What happened?
@@:
	and	VMM_FLAG,not @VMM_MUSTDRAIN ; Mark as no longer needed

	REGREST <fs,es> 	; Restore seg registers
	popad			; Restore registers

	ret			; Return to caller

	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

PPM_SHUTDOWN ENDP		; End PPM_SHUTDOWN procedure

PROG	ends			; End PROG segment

	MEND			; End DPMI_PPM.ASM
