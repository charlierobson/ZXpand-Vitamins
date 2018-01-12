    .module SELLR

id2x:
    ld      b,a
    sla     a
    sla     a
    add     a,3
    add     a,b
    ret


selectedfader:
    .byte   0


selectaLR:
    ld      (iy+y_),10
    ld      (iy+id_),0
    jr      _draw

_loop:
    ld      a,(left)
    cp      1
    call    z,_goleft

    ld      a,(right)
    cp      1
    call    z,_goright

_draw:
    ld      a,(iy+id_)
    ld      (selectedfader),a
    call    id2x
    ld      (iy+x_),a

    ld      l,(iy+aL_)
    ld      h,(iy+aH_)
    ld      (hl),0
    inc     hl
    ld      (hl),0

    call    xy2dfile

    ld      (iy+aL_),l
    ld      (iy+aH_),h
    ld      (hl),$98
    inc     hl
    ld      (hl),$98
    YIELD
    jr      _loop


_goleft:
    ld      a,(iy+id_)
    dec     a
    ret     m
    cp      1
    jr      nz,{+}
    dec     a
+:  ld      (iy+id_),a
    ret

_goright:
    ld      a,(iy+id_)
    inc     a
    cp      6
    ret     z
    cp      1
    jr      nz,{+}
    inc     a
+:  ld      (iy+id_),a
    ret
