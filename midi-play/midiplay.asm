//
// COMPILE THIS USING ZX-IDE
// http://www.sinclairzxworld.com/viewtopic.php?f=6&t=1064
//

	format zx81

	MEMAVL =  MEM_16K        // can be MEM_1K, MEM_2K, MEM_4K, MEM_8K, MEM_16K, MEM_32K, MEM_48K
	STARTMODE EQU SLOW_MODE  // SLOW or FAST
	DFILETYPE EQU EXPANDED	 // COLLAPSED or EXPANDED or AUTO

	include 'SINCL-ZX\ZX81.INC'

	S_OPEN		equ	1 ; ZXpand+ streaming API defines
	S_READ		equ	2
	S_WAIT		equ	4
	S_STORE 	equ	8

	api_stream		equ	$1FF4	; vector addresses in ZXpand+ overlay ROM
	api_response	equ	$1FF6

	API_OP		equ	16444		; API header addresses (PRBUFF - PRBUFF+32)
	API_RES 	equ	16445
	API_DLEN	equ	16446
	API_DPTR	equ	16447

	AUTOLINE 10

	REM _asm
main:
	ld	a,$ff
	ld	(frameNum),a
	ld	(frameNum+1),a
	ld	(frameNum+2),a

readNextFrame:
	ld	a,S_READ+S_WAIT ; read file -> wait for result
	ld	(API_OP),a
	ld	a,128
	ld	(API_DLEN),a
	call	api_stream

	ld	a,(API_RES)	; return on file error / done
	cp	$40
	ret	nz

	in	a,($7)		; upper 8 address bits not needed for read
	ld	(frameCmp),a
	in	a,($7)
	ld	(frameCmp+1),a
	in	a,($7)
	ld	(frameCmp+1),a

waitNextFrame:
	call	frameWait
	call	updateCounter
	ld	hl,(frameNum)
	inc	hl
	ld	(frameNum),hl
	ld	a,h
	or	l
	jr	nz,.skip

	ld	a,(frameNum+2)
	inc	a
	ld	(frameNum+2),a

.skip:
	ld	de,(frameCmp)
	and	a
	sbc	hl,de
	ld	a,h
	or	l
	jr	nz,testQuit	; if it's not time to play, see if it's time to quit

	ld	hl,frameNum+2
	ld	a,(frameCmp+2)
	sub	(hl)
	jr	nz,testQuit

	; play and continue
	;
	ld	bc,$e007
	ld	a,$c1
	out	(c),a
	call	api_response
	jr	readNextFrame

testQuit:
	call	$02bb		; quit if key pressed
	inc	l
	jr	z,waitNextFrame

	ret


updateCounter:
	ld	b,6		; max digits
	ld	hl,(D_FILE)
	ld	de,32
	add	hl,de		; last digit in counter
.cascade:
	ld	a,(hl)
	inc	a
	cp	38	; '9'+1
	jr	nz,.store
	ld	a,28	; '0'
.store:
	ld	(hl),a
	ret	nz		; return if we didn't roll over
	dec	hl
	djnz	.cascade
	ret

frameWait:
	ld	hl,FRAMES
	ld	a,(hl)
.FrameLoop:
	cp	(hl)
	jr	z,.FrameLoop
	ret

frameNum:
	db	0,0,0

frameCmp:
	dw	0,0,0




	END _asm
AUTORUN:
	PRINT "MIDIPLAY V0.95           0000000"
	PRINT
	LET A$ = "ALFIE"
	LPRINT "GET PAR"
	IF PEEK 16446 <> 0 THEN GOSUB #getparam#
	PRINT "PLAYING """ + A$ + """"
	PRINT "PRESS A KEY TO STOP"
	LPRINT "OPE MID"
	LPRINT "OPE FIL " + A$ + ".ZXM"
	RAND USR #main
	LPRINT "CLO MID"
	STOP
getparam:
	LET A$ = ""
	FOR I = 1 TO PEEK 16446
	LET A$ = A$ + CHR$(PEEK (16448 + I))
	NEXT I
	RETURN

include 'SINCL-ZX\ZX81DISP.INC'   ;include D_FILE and needed memory areas

VARS_ADDR:
	db 80h
WORKSPACE:

assert ($-MEMST)<MEMAVL
// end of program