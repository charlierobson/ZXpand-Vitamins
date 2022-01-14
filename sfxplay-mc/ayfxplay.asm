; This player is slightly modified from the work of shiru:
;
; https://shiru.untergrund.net/software.shtml

	.module	AFX

;--------------------------------------------------------------;
;                                                              ;
; The simplest effects player.                                 ;
;                                                              ;
; Plays effects on one AY, without music on the background.    ;
;                                                              ;
; Priority of channel selection:                               ;
;  If there are free channels, one of them is selected.        ;
;  If there are no free channels, the longest sounding         ;
;  is selected.                                                ;
;                                                              ;
; The playing procedure uses the registers AF, BC, DE, HL, IX. ;
;                                                              ;
; Initialization:                                              ;
;   ld hl, Effects Bank Address                                ;
;   call AFX.INIT                                              ;
;                                                              ;
; Start the effect:                                            ;
;   ld a, effect number (0..255)                               ;
;   call AFX.PLAY                                              ;
;                                                              ;
; In the interrupt handler:                                    ;
;   call AFX.FRAME                                             ;
;                                                              ;
;--------------------------------------------------------------;

; channel descriptors, 4 bytes per channel:
; +0 (2) current address (the channel is free if the high byte =$00)
; +2 (2) sound time
; ...

afxChDesc:	.fill 3*4

;--------------------------------------------------------------;
; Initializing the effects player.                             ;
; Turns off all channels, sets variables.                      ;
; Input: HL = bank address with effects                        ;
;--------------------------------------------------------------;

INIT:
	inc		hl
	ld		(afxBnkAdr+1),hl	;save the address of the table of offsets

	ld		hl,afxChDesc		;mark all channels as empty
	ld		de,$00ff
	ld		bc,$0300
-:
	ld		(hl),d
	inc		hl
	ld		(hl),d
	inc		hl
	ld		(hl),e
	inc		hl
	ld		(hl),e
	inc		hl
	djnz	{-}

	ld		hl,$cf0f			;initialize AY
	ld		e,15

-:
	dec		e
	ld		c,h
	out		(c),e
	ld		c,l
	out		(c),d
	jr		nz,{-}

	ld 		(afxNseMix+1),de	;reset the player variables
	ret

;--------------------------------------------------------------;
; Launch the effect on a free channel. Without                 ;
; free channels is selected the longest sounding.              ;
; Input: A = Effect number 1..255                              ;
;--------------------------------------------------------------;

PLAY:
	push	hl
	push	bc
	push	de
	dec		a
	ld		de,0				;in DE the longest time in search
	ld		h,e
	ld		l,a
	add		hl,hl
afxBnkAdr:
	ld		bc,0				;address of the effect offsets table (SELF MODIFIED)
	add		hl,bc
	ld		c,(hl)
	inc		hl
	ld		b,(hl)
	add		hl,bc				;the effect address is obtained in hl
	push	hl					;save the effect address on the stack

	ld		hl,afxChDesc		;empty channel search
	ld		b,3
-:
	inc		hl
	inc		hl
	ld		a,(hl)				;compare the channel time with the largest
	inc		hl
	cp		e
	jr		c,{+}
	ld		c,a
	ld		a,(hl)
	cp		d
	jr		c,{+}
	ld		e,c					;remember the longest time
	ld		d,a
	ld		(afxChnAdr+1),hl
+:
	inc		hl
	djnz	{-}

afxChnAdr:
	ld		hl,0				;hl is address of channel to use (SELF MODIFIES)
	ld		(hl),b				;b is 0
	dec		hl
	ld		(hl),b
	dec		hl
	pop		de					;take the effect address from the stack
	ld		(hl),d
	dec		hl
	ld		(hl),e
	pop		de
	pop		bc
	pop		hl
	ret


;--------------------------------------------------------------;
; Playing the current frame.                                   ;
; No parameters.                                               ;
;--------------------------------------------------------------;

FRAME:
	ld		bc,$0300
	ld		ix,afxChDesc

afxFrame0:
	push	bc

	ld		a,11
	ld		h,(ix+1)			;the comparison of the high-order byte of the address to <11
	cp		h 
	jr		nc,afxFrame7		;the channel does not play, we skip
	ld		l,(ix+0)
	
	ld		e,(hl)				;we take the value of the information byte
	inc		hl
			
	sub		b					;select the volume register:
	ld		d,b					;(11-3=8, 11-2=9, 11-1=10)

	ld		c,$cf				;output the volume value
	out		(c),a
	ld		a,e
	and		$0f
	ld		c,$0f
	out		(c),a
	
	bit		5,e					;will change the tone?
	jr		z,afxFrame1			;tone does not change
	
	ld		a,3					;select the tone registers:
	sub		d					;3-3=0, 3-2=1, 3-1=2
	add		a,a					;0*2=0, 1*2=2, 2*2=4
	
	ld		c,$cf				;output the tone values
	out		(c),a
	ld		d,(hl)
	inc		hl
	ld		c,$0f
	out		(c),d
	inc		a
	ld		c,$cf
	out		(c),a
	ld		d,(hl)
	inc		hl
	ld		c,$0f
	out		(c),d
	
afxFrame1:
	bit		6,e					;will change the noise?
	jr		z,afxFrame3			;noise does not change
	
	ld		a,(hl)				;read the meaning of noise
	sub		$20
	jr		c,afxFrame2			;less than $ 20, play on
	ld		h,a					;otherwise the end of the effect
	ld		b,$ff
	ld		b,c					;in BC we record the longest time
	jr		afxFrame6
	
afxFrame2:
	inc		hl
	ld		(afxNseMix+1),a		;keep the noise value
	
afxFrame3:
	pop		bc					;restore the value of the cycle in B
	push	bc
	inc		b					;number of shifts for flags TN
	
	ld		a,%01101111			;mask for flags TN
afxFrame4:
	rrc		e					;shift flags and mask
	rrca
	djnz	afxFrame4
	ld		d,a
	
	ld		bc,afxNseMix+2		;store the values ​​of the flags
	ld		a,(bc)
	xor		e
	and		d
	xor		e					;E is masked by D
	ld		(bc),a
	
afxFrame5:
	ld		c,(ix+2)			;increase the time counter
	ld		b,(ix+3)
	inc		bc
	
afxFrame6:
	ld		(ix+2),c
	ld		(ix+3),b
	
	ld		(ix+0),l			;save the changed address
	ld		(ix+1),h
	
afxFrame7:
	ld		bc,4				;go to the next channel
	add		ix,bc
	pop		bc
	djnz	afxFrame0

	ld		hl,$cf0f			;output the value of noise and mixer
afxNseMix:
	ld		de,0				;+1 (E) = noise, +2 (D) = mixer  (SELF MODIFIES)
	ld		a,6
	ld		c,h
	out		(c),a
	ld		c,l
	out		(c),e
	inc		a
	ld		c,h
	out		(c),a
	ld		c,l
	out		(c),d
	
	ret
