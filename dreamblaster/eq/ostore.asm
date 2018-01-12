	.MODULE OSTORE

	; ostruct layout
	;
	ONEXT		.equ	$0
	OPREV		.equ	$2
	OPC			.equ	$4
	OUSER		.equ	$6
	;...
	OSTRUCTSIZE	.equ	$40

	; object store - we'll allocate space for 16 objects
	;
	NSTRUCTS	.equ	$20

	PSTORE		.word	0		; pointer to private data store
	NEXTFREE	.word	0		; pointer to memory location holding address of next free object


	;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	;
	; initialise a block of memory to be an object repository, and initialise a 
	; list of pointers to structures which will be the free list.
	;
	; the iy register will be pointing to one of these object stores during execution.
	; in order to use the iy register, we need to be able to supply the interrupt
	; with the value of margin and cdflag. we'll do this by allocating 64 bytes
	; for each object (too many but it makes things simple) and setting iy+$28 to
	; a copy of the sys constant MARGIN, ditto CDFLAG at iy+$3b. it's a nasty space
	; wasting hack, but it's easier than rewriting the interrupt routine...
	;
	; [in]: nothing
	; [out]: nothing
	; preserves: nothing
	;
initostore:
	; write the freelist with the address of the last object at index 0.
	; we pull free structures off the _end_ of the list. not that it matters
	;
	; clear the memory to a random value - helps to show up bugs
	ld		hl,OSTORE
	ld		(hl),123
	ld		de,OSTORE+1
	ld		bc,NSTRUCTS*OSTRUCTSIZE-1
	ldir

	; point hl at the 1st byte past the last struct
	;
	; point de at the 1st entry in the freelist
	;
	ld		hl,OSTORE+(NSTRUCTS*OSTRUCTSIZE)
	ld		de,FREELIST

	; using a variable to support NTSC systems
	;
	ld		a,(MARGIN)
	
	ld		b,NSTRUCTS

-:	push	bc

	ld		(_pokey+1),de		; prepare write to list
	inc		de
	inc		de

	; point hl at previous struct
	;
	ld		bc,OSTRUCTSIZE
	sbc		hl,bc

_pokey
	ld		(0),hl				; write to list

	; prep the struct by writing CDFLAG and MARGIN
	;
	push	hl

	ld		bc,$28
	add		hl,bc
	ld		(hl),a				; MARGIN
	ld		bc,$3B-$28
	add		hl,bc
	ld		(hl),$c0			; CDFLAG

	pop		hl

	pop		bc
	djnz	{-}

	; NEXTFREE points at the list entry that will be pulled next
	;
	dec		de
	dec		de
	ld		(NEXTFREE),de


	; set up THIS (iy) pointer for the main object, as would have been done by the YIELD macro.
	;
	ld		iy,OSTORE
	ret



	;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	;
	; pull address of the next free ostruct off the freelist
	;
	; [in]: nothing
	; [out] hl: pointer to free object
	; preserves: all non-parameter registers
	;
getobject:
	ld		hl,(NEXTFREE)
	ld		(_peeky+1),hl		; prepare read from list
	dec		hl
	dec		hl
	ld		(NEXTFREE),hl
_peeky
	ld		hl,(0)				; read from list
	ret



	;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	;
	.MODULE freeobject
	;
	; push address of the next free ostruct (in hl) onto the freelist
	;
	; [in] hl: address of object to be returned
	; [out] nothing
	; preserves: all registers
	;
freeobject:
	push	hl
	ld		hl,(NEXTFREE)
	inc		hl
	inc		hl

	ld		(_pokey+1),hl		; prepare write to list;
	ld		(NEXTFREE),hl
	pop		hl

_pokey
	ld		(0),hl				; write to list
	ret



	;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	;
	.MODULE initobject
	;
	; setup the object's execution address.
	;
	; [in] hl: pointer to object
	; [in] bc: pointer to code
	; preserves: all registers
	;
	#if OPC != 4
	.error
	#endif
	;
initobject:
	; inc to OPC
	;
	inc		hl
	inc		hl
	inc		hl
	inc		hl
	ld		(_pokey+2),hl		; init write to list
	dec		hl
	dec		hl
	dec		hl
	dec		hl
_pokey
	ld		(0),bc				; write to list
	ret



	;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	;
	.MODULE unlinkobject
	;
	; use the spiffy doubly-linked list members of an object to
	; remove it from the execution chain, then restore its pointer
	; to the freelist.
	;
	; [in] hl: object to unlink
	; [out]: nothing
	; preserves: a, hl
	;

	#if ONEXT != 0
	.error
	#endif
	#if OPREV != 2
	.error
	#endif

unlinkobject:
	ld		(_getnxtinde+2),hl
	inc		hl
	inc		hl
	ld		(_getprvinbc+2),hl
	dec		hl
	dec		hl

_getnxtinde
	ld		de,(0)
_getprvinbc
	ld		bc,(0)

	ld		(_putnxtinprv+2),bc	
	inc		de
	inc		de
	ld		(_putprvinnxt+2),de	
	dec		de
	dec		de

_putnxtinprv
	ld		(0),de
_putprvinnxt
	ld		(0),bc

	jp		freeobject



	;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	;
	.MODULE inserters
	;
	; different ways to insert objects into the execution chain.
	; topology is important - for instance if you insert a missile
	; into the middle of a run of targets - the targets executing
	; *before* the bullet won't see it.. it's a little confusing at
	; first, i admit, but it's simple once you get your head around
	; it! another good one is when an object inserts an object before
	; itself in the chain - the new object wont execute until next
	; frame.
	;

insertobject_afterhead:
	ld		de,OSTORE
	jr		insertobject

insertobject_beforehead:
	ld		de,(OSTORE+OPREV)
	jr		insertobject

insertobject_afterthis:
	push	iy
	pop		de
	jr		insertobject

insertobject_beforethis:
	; insert after this' prev ;)
	;
	push	iy
	pop		de
	inc		de
	inc		de
	ld		(_lddeprv+2),de
_lddeprv
	ld		de,(0)
	jr		insertobject



	;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	;
	.MODULE insertobject
	;
	; insert the object into the execution chain immediately after
	; the nominated object in hl
	;
	; [in] hl: object pointer
	; [in] de: object to insert after
	; [out] hl: points at new object's user area
	; preserves: a
	;

	#if ONEXT != 0
	.error
	#endif
	#if OPREV != 2
	.error
	#endif

insertobject:
	ld		(_newino1next+1),de	; prepare read o1.next (o2) into bc
	ld		(_o1nxtintobc+2),de	; prepare write newobj into o1.next

	ld		(_svNintonew+2),hl	; prepare write saved next into new.next
	inc		hl
	inc		hl
	ld		(_svPintonew+2),hl	; prepare write saved prev into new.prev
	dec		hl
	dec		hl

_o1nxtintobc
	ld		bc,(0)				; read o1.next (o2) into bc
_newino1next
	ld		(0),hl				; write newobj into o1.next

	inc		bc					; point bc at o2.prev
	inc		bc
	ld		(_o2prvintode+2),bc	; prepare read o2.prev into de
	ld		(_newino2prev+1),bc	; prepare write newobj into o2.prev
	dec		bc
	dec		bc

_o2prvintode
	ld		de,(0)				; read o2.prev into de
_newino2prev
	ld		(0),hl				; write newobj into o2.prev

_svNintonew
	ld		(0),bc				; write saved next into newobj.next
_svPintonew
	ld		(0),de				; write saved prev into newobj.prev

	; leave with de -> new object user area, hl = current -> user area
	;
	ld		de,OUSER
	add		hl,de				; hl -> new object data
	ex		de,hl				; de -> new object data, hl = OUSER

	push	de					; stash

	push	iy					; get pointer to current object
	pop		de					; into de
	add		hl,de				; hl = OUSER + current object pointer

	pop		de					; recover target pointer
	ret



objectafterhead:
    call    getobject
    call    initobject
    jp      insertobject_afterhead

objectbeforehead:
    call    getobject
    call    initobject
    jp      insertobject_beforehead

objectafterthis:
    call    getobject
    call    initobject
    jp      insertobject_afterthis
