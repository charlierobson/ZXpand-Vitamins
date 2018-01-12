; -----------------------------------------------------------------------------
; -MATH-HELPER-FUNCTIONS-------------------------------------------------------
; -----------------------------------------------------------------------------


; returns smallest of hl, de in hl
;
smallest:
   push  hl
   and   a
   sbc   hl,de
   pop   hl
   ret   c
   ex    de,hl
   ret

; return with Z flag set if hl==de, c set if de > hl
;
areequal:
   push  hl
   and   a
   sbc   hl,de
   pop   hl
   ret


; multiply HL by some power of 2
;
hltimes32:
   sla   l
   rl    h
hltimes16:
   sla   l
   rl    h
hltimes8:
   sla   l
   rl    h
hltimes4:
   sla   l
   rl    h
hltimes2:
   sla   l
   rl    h
   ret


; multiplies hl by 33.
;
; preserves a, de, bc
;
hltimes33:
   push  de             ; preserve de
   push  hl             ; de = hl
   pop   de
   call  hltimes32      ; hl *= 32
   add   hl,de          ; *33
   pop   de             ; restore de
   ret


addAtohl:
   add   a,l
   ld    l,a
   ret   nc
   inc   h
   ret


; adds 8 bit value in A register to 16 bit value on stack.
;
; preserves hl, bc, de
;
stkAdd8:
   ex    (sp),hl        ; return address into hl, save previous value
   ld    (stkExit+1),hl ; remove need for return address on stack
   pop   hl             ; restores previous HL

   ex    (sp),hl        ; get parameter value in HL, store previous hl
   push  de             ; we can now use stack
   ld    e,a            ; a -> de
   ld    d,0
   add   hl,de
   pop   de
   ex    (sp),hl        ; store result and recover previous HL

   jr    stkExit


; adds the 2 top stack entries leaving sum on the stack - tricky!!
;
; preserves hl, bc, de
;
stkAdd16:
   ex    (sp),hl           ; swap hl for return address off stack and
   ld    (stkExit+1),hl    ; store ret addr as jump at the end of the routine,
   pop   hl                ; recover hl. so far so good - hl is preserved and the ret addr is gone.

;  after this op:    HL  DE   STACK (*=SP)
                  ;  777 999  *12   30
   ex    (sp),hl  ;  12  999  *999  30
   ex    de,hl    ;  999 12   *999  30
   inc   sp       ;
   inc   sp       ;  999 12    999 *30
   ex    (sp),hl  ;  30  12    999 *777
   add   hl,de    ;  42  12    999 *777
   ex    (sp),hl  ;  777 12    999 *42
   dec   sp       ;
   dec   sp       ;  777 12   *999  42
   pop   de       ;  777 999   42
   ex    de,hl    ;  999 777   42

   jr    stkExit


; multiply the number at the top of the stack by 16
;
; preserves a, hl, bc, de
;
stkmul16:
   ex    (sp),hl
   ld    (stkExit+1),hl
   pop   hl

   ex    (sp),hl
   call  hltimes16
   ex    (sp),hl              ; store result and recover previous HL

stkExit:
   jp    0


; decrement the 16 bit value pointed to by hl if it is not already 0.
; return with z flag set if value was already 0.
;
decINZ:
   ld    (dn_load+1),hl
   ld    (dn_save+1),hl
   ld    a,(hl)
   inc   hl
   or    (hl)
   ret   z
dn_load:
   ld    hl,(0)
   dec   hl
dn_save:
   ld    (0),hl
   ret


incmem:
   inc   (hl)
   ret   nz
   inc   hl
   inc   (hl)
   dec   hl
   ret

   
multi_8_8:
; procedure taken from http://baze.au.com/misc/z80bits.html; thanks Baze!
; 1.1 Restoring 8-bit * 8-bit Unsigned
; Input: H = Multiplier, E = Multiplicand, L = 0, D = 0
; Output: HL = Product
	sla	h		; optimised 1st iteration
	jr	nc,$+3
	ld	l,e

	add	hl,hl		; unroll 7 times
	jr	nc,$+3
	add	hl,de

	add	hl,hl
	jr	nc,$+3
	add	hl,de

	add	hl,hl
	jr	nc,$+3
	add	hl,de

	add	hl,hl
	jr	nc,$+3
	add	hl,de

	add	hl,hl
	jr	nc,$+3
	add	hl,de

	add	hl,hl
	jr	nc,$+3
	add	hl,de

	add	hl,hl
	jr	nc,$+3
	add	hl,de
	ret
