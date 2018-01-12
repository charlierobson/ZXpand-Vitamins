    .module SELUD

selectaUD:
    ld      a,(iy+x_)
    ld      (iy+id_),a
    call    id2x
    ld      (iy+x_),a
    ld      (iy+y_),0

_initdraw:
    call    xy2dfile
    ld      (hl),$83
    inc     hl
    ld      (hl),$84
    inc     (iy+y_)
    ld      a,(iy+y_)
    cp      9
    jr      nz,_initdraw

    ld      h,defaultValues/256
    ld      l,(iy+id_)
    ld      a,(hl)
    ld      (iy+y_),a
    jr      _godraw

_loop:
    YIELD

    ld      a,(selectedfader)
    cp      (iy+id_)
    jr      nz,_loop

    ld      a,(up)
    cp      1
    call    z,_goup

    ld      a,(down)
    cp      1
    call    z,_godown

    ld      l,(iy+aL_)
    ld      h,(iy+aH_)
    ld      (hl),$83
    inc     hl
    ld      (hl),$84

_godraw:
    call    xy2dfile
    ld      (iy+aL_),l
    ld      (iy+aH_),h
    ld      (hl),$85
    inc     hl
    ld      (hl),$86
    jr      _loop


_goup:
    ld      a,(iy+y_)
    dec     a
    ret     m
    ld      (iy+y_),a
    jp      setEQ

_godown:
    ld      a,(iy+y_)
    inc     a
    cp      9
    ret     z
    ld      (iy+y_),a
    jp      setEQ

    .align  256
defaultValues:
    .byte   0, $ff, 3, 4, 4, 3
