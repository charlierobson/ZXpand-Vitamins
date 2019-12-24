; exits with bit 0 indicating type,
; = 0 = classic
; = 1 = plus
;
detectZXpandType:
    ld      a,$1d       ; command = ID
    ld      bc,$e007
    out     (c),a
    ex      (sp),hl
    ex      (sp),hl
    in      a,(c)       ; will be 0x80 for classic or 5 for plus
    ret
