;-------------------------------------------------------------------------------
;
; assemble with BRASS 1.0.5.3, see:
;   http://benryves.com/bin/brass/
;
; brass main.asm sndtest.p -s -l sndtest.html
;
; runs nicely under MONO on linux/mac
;
; For some background to the whole infrastructure, see:
;   https://github.com/Threetwosevensixseven/ayfxedit-improved
;
;-------------------------------------------------------------------------------

	.org		$4009

	.exportmode NO$GMB
	.export

versn	.byte   $00
e_ppc	.word   $0000
d_file	.word   dfile
df_cc	.word   dfile+1
vars	.word   var
dest	.word   $0000
e_line	.word   var+1
ch_add	.word   last-1
x_ptr	.word   $0000
stkbot	.word   last
stkend	.word   last
breg	.byte   $00
mem		.word   membot
unuseb	.byte   $00
df_sz	.byte   $02
s_top	.word   $0000
last_k	.word   $ffff
db_st	.byte   $ff
margin	.byte   55
nxtlin	.word   line10
oldpc   .word   $0000
flagx   .byte   $00
strlen  .word   $0000
t_addr  .word   $0c8d; $0c6b
seed	.word   $0000
frames  .word   $ffff
coords  .byte   $00
		.byte   $00
pr_cc   .byte   188
s_posn  .byte   33
s_psn1  .byte   24
cdflag  .byte   64
PRTBUF  .fill   32,0
prbend  .byte   $76
membot  .fill   32,0

;-------------------------------------------------------------------------------

line1:
	.byte	0,1
	.word	line01end-$-2
	.byte	$ea

;-------------------------------------------------------------------------------
;
.module MAIN

start:

	call	dukenukem
	call	wait50				; wait a sec

	ld		hl,chana
	call	playchan
	call	wait50

	ld		hl,chanab
	call	playchan
	call	wait50

	ld		hl,chanabc
	call	playchan
	call	wait50

	call	dukenukem
	call	wait50

	ld		hl,chana
	call	playchan
	call	wait50

	call	dukenukem
	ld		hl,chanb
	call	playchan
	call	wait50

	call	dukenukem
	ld		hl,chanc
	call	playchan
	call	wait50

	jp		start

playchan:
	ld		b,4
-:
	ld		a,(hl)
	inc		hl
	out		($cf),a
	ld		a,(hl)
	inc		hl
	out		($0f),a
	djnz	{-}
	ret

framesync:
	ld		hl,frames
	ld		a,(hl)
-:	cp		(hl)
	jr		z,{-}
	ret

wait50:
	ld		b,50
-:	call	framesync
	djnz	{-}
	ret

dukenukem:
	ld		a,$07				; enable register
	out		($cf),a
	ld		a,$ff				; all off
	out		($0f),a
	ret

;-------------------------------------------------------------------------------

chana:
	.byte	$00,$57		; ch. A period
	.byte	$01,$03
	.byte	$08,$0F 	; volume
	.byte	$07,$FF-1	; enable output A

chanb:
	.byte	$02,$AB		; ch. B period
	.byte	$03,$01
	.byte	$09,$0F 	; volume
	.byte	$07,$FF-2	; enable output B

chanc:
	.byte	$04,$D5		; ch. C period
	.byte	$05,$00
	.byte	$0A,$0F 	; volume
	.byte	$07,$FF-4	; enable output C

chanab:
	.byte	$02,$AB		; ch. B period
	.byte	$03,$01
	.byte	$09,$0F 	; volume
	.byte	$07,$FF-3	; enable output A,B

chanabc:
	.byte	$04,$D5		; ch. C period
	.byte	$05,$00
	.byte	$0A,$0F 	; volume
	.byte	$07,$FF-7	; enable output A,B,C

;-------------------------------------------------------------------------------

	.byte	$76
line01end:
line10:
	.byte	0,2
	.word	line10end-$-2
	.byte	$F9,$D4,$C5,$0B		; RAND USR VAL "
	.byte	$1D,$22,$21,$1D,$20	; 16514 
	.byte	$0B					; "
	.byte	076H				; N/L
line10end:

dfile:
	.repeat 24
	  .byte	076H
	  .fill	32,0
	.loop
	.byte	076H

var:
	.byte	080H
last:

	.end
