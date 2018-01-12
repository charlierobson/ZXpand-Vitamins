; process control macros
;
#define YIELD	call $+3 \ pop de \ jp yield

#define	DIE		jp dodie

dodie:
	push	iy
	pop		hl
	call	unlinkobject
	jp		resumenext

	;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	;
	; yield: the core of the co-operative multitasking 'os' at the
	; heart of the game. allows game entities to be written in a
	; 'linear' fashion, without having to worry about state. yield
	; simply stores the return address in the object's struct, and
	; resumes execution at the next object's saved execution address.
	; neat and effective. called from the YIELD macro, which does the
	; relevant return-address pickling.
	;
	; [in] iy: points at the object's storage
	; [out]: nothing
	; preserves: nothing
	;

yield:
	; on entry de points to the 'pop de' instruction in the YIELD macro
	; adjust it so that it points to the instruction after the jump: in other
	; words, the resume address for the function.
	;
	inc		de
	inc		de
	inc		de
	inc		de

	; store 'return' address held in de in o->OPC
	;
	ld		(IY+OPC),e
	ld		(IY+OPC+1),d

resumenext:
	; get next object from o = o->ONEXT in hl
	;
	ld		l,(IY+ONEXT)
	ld		h,(IY+ONEXT+1)

	push	hl
	pop		iy

	; make a courtesy pointer to the object's OUSER (private store) area
	;
	ld		bc,OUSER
	add		hl,bc
	ld		(PSTORE),hl

	; now resume executing at the object's saved address
	;
	ld		l,(IY+OPC)
	ld		h,(IY+OPC+1)
	jp		(hl)
