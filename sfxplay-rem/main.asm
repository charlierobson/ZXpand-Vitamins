;-------------------------------------------------------------------------------
;
; assemble with BRASS 1.0.5.3, see:
;   http://benryves.com/bin/brass/
;
; brass main.asm sfxplay.p -s -l sfxplay.html
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
	.byte	$ea					; REM

;-------------------------------------------------------------------------------
;
.module MAIN
_INIT:
	ld		hl,soundbank	; USR 16514 : startup
	call	AFX.INIT
	ld		ix,isr
	ret

_PLAY:						; poke 16526,fxnum ; rand usr 16525
	ld		a,0
	jp		AFX.PLAY

;-------------------------------------------------------------------------------

isr:
	ld		a,r
	ld		bc,$1901
	ld		a,$f5
	call	$02b5
	call	$0292
	call	$0220

	push	hl
	push	bc
	push	de
	push	af
	call	AFX.FRAME
	pop		af
	pop		de
	pop		bc
	pop		hl

	ld		ix,isr
	jp		$02a4

;-------------------------------------------------------------------------------

	.include ayfxplay.asm

soundbank:
	.incbin SFX.AFB

;-------------------------------------------------------------------------------

	.byte	$76
line01end:
line10:
	.byte	0,2
	.word	line10end-$-2
	.byte	$ea					; REM
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
