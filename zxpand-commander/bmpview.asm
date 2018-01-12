; ============================================
; BMP viewer
; ================= Dec 2012, Krystian 'Tygrys' Wlosek
; www.speccy.pl

; error definition related to errors messages from cmdr.asm

BMPERROR_NOBMPFILE			.equ	16 ; no bmp file
BMPERROR_WRONGBITMAP		.equ	17 ; bitmap type
BMPERROR_WRONGCOMPRESSION	.equ	18 ; compressed data!
BMPERROR_WRONGWIDTH			.equ	19
BMPERROR_WRRONGHEIGHT		.equ	20


bmpviewer:
    ld    hl,DIRNAME
    ld    a,$12
    call  dircommand

    call  errorhandler
    ret   c

    ld    hl,FNBUF
    ld    de,FILEPATH1
    call  copystring
    ;call  $02e7
    ld    hl,txtdestadd
    call  copystring
    ld    de,FILEPATH1
    call  loadfile

    ; check bmp signature
    call bmp_checksignature
	jr	z,_bmpviwer_step2

	; oops, it's not a bmp file
	ld	a,BMPERROR_NOBMPFILE
	jr	bmp_errorhandler

_bmpviwer_step2:
	; check other params and restrictions
    call bmp_checksize
    or    a
    jr    nz,bmp_errorhandler ; something goes wrong

    call  clshr   ; clear HR buffer in case image is smaller

    call imageCenter ; calc. image pos. on screen

    call bmp_showimage ; generate image

	call	hron ; and show

_bmpviewer_keys:
	call	waitforkey
	or	a ; space
	jr	nz,_bmpviewer_keys

	call	hroff
        call    reloaddir
	ret

bmp_errorhandler:
	; this is good usage?
	jp	errorhandler
;	ret

; check 'BM' signature
bmp_checksignature:
	ld	hl,(bmp_address)
	ld	de,'B' * 256 + 'M'
	ld	a,(hl)
	cp	d
	ret	nz
	inc	hl
	ld	a,(hl)
	cp	e
	ret

bmp_checksize:
    ld    hl,(bmp_address)
    ld    de,28 ; width
    add    hl,de
    ld    e,(hl)
    inc    hl
    ld    d,(hl) ; in DE type of bitmap
    ld    a,1 ; we accept type 1
    cp    e
    ld    a,BMPERROR_WRONGBITMAP ; ERROR_WRONGBITMAP
    ret    nz

    inc    hl
    ld e,(hl)
    inc    hl
    ld d,(hl) ; type of compression
    ld a,e
    or d
    ld a,BMPERROR_WRONGCOMPRESSION ; ERROR_WRONGCOMPRESSION
    ret    nz
    ld    hl,(bmp_address)
    ld    de,18 ; width
    add    hl,de
    ld    e,(hl)
    inc    hl
    ld    d,(hl) ; width in DE
    srl    d
    rr    e
    srl    d
    rr    e
    srl    d
    rr    e
    ; D should be 0
    ld    a,d
    or    a
    ld    a,BMPERROR_WRONGWIDTH ; error = wrong size Width
    ret    nz

    ld    a,e
    cp    33 ; not much than 256pixels

    ld    a,BMPERROR_WRONGWIDTH
    ret    nc

    ld    a,e
    ld    (bmp_width),a

    inc    hl
    inc    hl
    inc    hl

    ld    e,(hl)
    inc    hl
    ld    d,(hl)   ; height

    ld    a,d
    or    a
    ld    a,3
    ret    nz

    ld    a,e
    cp    193 ; max 192 lines
    ld    a,BMPERROR_WRRONGHEIGHT
    ret    nc ; too big

    ld    a,e
    ld    (bmp_height),a

	; palette detection
	ld	hl,(bmp_address)
	ld	de,54 ; width
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	or	e
	or	d
	ld	a,0 ; NOP
	jp	nz,_bmp_checksize_rd
	ld	a,$2F ; CPL
_bmp_checksize_rd:
	ld	(bmp_operation),a


	ld    hl,(bmp_address)
    ld    de,10
    add    hl,de
    ld    e,(hl)
    inc    hl
    ld    d,(hl)
    ld    (bmp_rasterdata),de
     xor    a
    ret


bmp_showimage:
    ld    hl,(bmp_address)
    ld    de,(bmp_rasterdata)
    add   hl,de
    
    ld    a,(bmp_width)
    ld    (_bmp_showimage_srcadd),a
    ld    b,a
    ld    e,a

    ld    a,(bmp_height)
    ld    c,a

    push    hl

    dec    a
    ld    h,a
    ld    l,0
    ld    d,l
    call    multi_8_8
    ex    de,hl
    pop    hl
    add    hl,de

image_addr equ    $+1
    ld    de,imagebuffer

    jp    _bmp_showimage_skip

_bmp_showimage_loop:
    push    hl
    ld      hl,32
    add     hl,de
    ex      de,hl
    pop     hl

_bmp_showimage_skip_2
    push    de

    xor    a ; reset Carry
_bmp_showimage_srcadd    equ    $+1
    ld     de,0
    sbc    hl,de

    pop    de

_bmp_showimage_skip:
    push    bc
    
    push    hl
    push    de
    
_bmp_showimage_intloop:
    ld    a,(hl)
    xor   $ff
    ld    (de),a
bmp_operation:
	nop
    inc    hl
    inc    de
    djnz    _bmp_showimage_intloop
    
    pop    de
    pop    hl

    pop    bc
    dec    c
    jr    nz,_bmp_showimage_loop
    ret

	
imageCenter:
    ld    a,(bmp_width)
    ld    e,a
    ld    a,32
    sub    e
    srl    a
    ld    e,a

    ld    a,(bmp_height)
    ld    d,a
    ld    a,192
    sub    d
    srl    a
    ld    d,a

    ld    bc,32
    ld    hl,imagebuffer
    or    a
    jr    z,_imageCenter_store

_imageCenter_l1:
    add    hl,bc
    dec    d
    jr    nz,_imageCenter_l1

_imageCenter_store:
    add    hl,de
    ld    (image_addr),hl
    ret


imagebuffer:		equ	$8000
bmp_address:      dw    start_txt
bmp_rasterdata:   dw    0
bmp_width:        db    0
bmp_height:       db    0