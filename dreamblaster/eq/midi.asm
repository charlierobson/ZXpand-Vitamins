    .module MIDI


openmidi:
    ld      de,_startmidimsg
    jp      $1ff2


playmiddlec:
    ld      de,_middlec
    ld      l,6

    ; fall through

spoogemidi:
    ld      a,1
    call    $1ffc

    ld      bc,$e007        ; write usart
    ld      a,$c0
    out     (c),a

    jp      $1ff6           ; get response


_startmidimsg:
    .asc    "OPEN MIDI"
    .byte   $ff



setEQ:
    ld      h,controlValues / 256
    ld      l,(iy+id_)
    ld      a,(hl)
    ld      (effect),a

    ld      a,7
    ld      b,(iy+y_)
    sub     b
    sla     a
    sla     a
    sla     a
    sla     a
    ld      (level),a

    ld      de,eqMessage
    ld      l,9
    jp      spoogemidi


eqMessage:
    .byte   $B0,$62,$ff
    .byte   $B0,$63,$37
    .byte   $B0,$06,$ff

effect = eqMessage + 2
level = eqMessage + 8


    .align  256

controlValues:
    .byte   $07,$ff,$00,$01,$02,$03

_middlec:
    .byte   $90, 60, 127    ; note on channel 0, middle c, on-velocity
    .byte   $80, 60, 0      ; note off channel 0, middle c, off-velocity

midibuffer:
    .fill   256
