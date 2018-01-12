    .module UTILS

x_ = OUSER+0
y_ = OUSER+1
aL_ = OUSER+2
aH_ = OUSER+3
id_ = OUSER+4
user_ = OUSER+5

.define ADD_HL_A add a,l \ ld l,a \ adc a,h \ sub l \ ld h,a

coords:
_coord_x:   .byte   0
_coord_y:   .byte   0


printstring:
    pop     hl
    ld      de,coords
    ldi
    ldi

_calcadd:
    push    hl
    call    coords2dfile
    pop     de
    ex      de,hl

_loop:
    ld      a,(hl)
    inc     hl

    cp      $f0
    jr      nz,_notend

    push    hl
    ret

_notend:
    cp      $40
    jr      nz,_notnl

    xor     a
    ld      (_coord_x),a
    ld      a,(_coord_y)
    inc     a
    ld      (_coord_y),a
    jr      _calcadd

_notnl:
    ld      (de),a
    inc     de
    jr      _loop




xy2dfile:
    ld      a,(iy+x_)
    ld      (_coord_x),a
    ld      a,(iy+y_)
    inc     a
    inc     a
    ld      (_coord_y),a

coords2dfile:
    ld      a,(_coord_y)
    ld      l,a
    ld      h,0
    sla     l
    sla     l
    sla     l
    sla     l
    rl      h
    sla     l
    rl      h
    ADD_HL_A
    ld      de,(D_FILE)
    inc     de
    add     hl,de
    ld      a,(_coord_x)
    ADD_HL_A
    ret
