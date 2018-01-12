    .emptyfill  0
    .org        $4009

#include "include/sysvars.asm"
#include "include/zxline0.asm"

    .exportmode NO$GMB          ; xxxx:yyyy NAME
    .export

OSTORE = $2400

#include "yield.asm"
#include "ostore.asm"
#include "util.asm"

FREELIST = OSTORE + (NSTRUCTS * OSTRUCTSIZE)

    .asciimap   'A','Z',{*}-'A'+$26
    .asciimap   '0','9',{*}-'0'+$1c
    .asciimap   ' ',' ',$00
    .asciimap   ':',':',$0e
    .asciimap   '-','-',$16
    .asciimap   '/','/',$18
    .asciimap   ',',',',$1a
    .asciimap   '.','.',$1b

charset = $2000
charsetx:
    .incbin "zx81plus.bin"

inputstates:
    .byte    %10000000,4,%00001000,0        ; up      (Q)
    .byte    %01000000,4,%00010000,0        ; down    (A)
    .byte    %00100000,3,%00010000,0        ; left    (N)
    .byte    %00010000,4,%00000100,0        ; right   (M)
    .byte    %00001000,4,%00000001,0        ; play    (SP)
    .byte    %11111111,0,%11111111,0        ;
    .byte    %11111111,0,%11111111,0        ;
    .byte    %11111111,0,%11111111,0        ;

; ------------------------------------------------------------
starthere:
    out     ($fd),a

    ld      bc,$e007            ; go low, ram at 8-40k
    ld      a,$b2
    out     (c),a

    call    initostore

    call    getobject
    ld      bc,fnmain
    call    initobject
    ld      hl,OSTORE
    ld      (OSTORE+ONEXT),hl
    ld      (OSTORE+OPREV),hl

    ld      hl,charsetx 
    ld      de,charset
    ld      bc,$400
    ldir

    ld      hl,charset+$200
    ld      bc,$00ff
-:  ld      a,(hl)
    xor     c
    ld      (hl),a
    inc     hl
    djnz    {-}

;    ld      a,$18
;    ld      (charset+3),a
;    ld      (charset+4),a

    ld      a,$21       ; go udg!
    ld      i,a

    call    openmidi

    ld      bc,selectaLR
    call    objectbeforehead

    ld      bc,selectaUD
    call    objectbeforehead
    ld      a,0
    ld      (de),a

    ld      bc,selectaUD
    call    objectbeforehead
    ld      a,2
    ld      (de),a

    ld      bc,selectaUD
    call    objectbeforehead
    ld      a,3
    ld      (de),a

    ld      bc,selectaUD
    call    objectbeforehead
    ld      a,4
    ld      (de),a

    ld      bc,selectaUD
    call    objectbeforehead
    ld      a,5
    ld      (de),a

    call    printstring
    .byte   1,0
    .asc    "VOLUME      LO  LMID HMID HIGH"
    .byte   $F0

    call    printstring
    .byte   0,18
    ;        --------========--------========
    .asc    "   CURSOR KEYS: ALTER SLIDERS"
    .byte   $40
    .asc    "             0: PLAY / STOP"
    .byte   $F0

    call    printstring
    .byte   9,23
    .asc    "MOGG-E-Q V1.10"
    .byte   $F0

	out     ($fe),a

    ; here's the main loop, the root

    ld      (iy+user_),0
    ld      (iy+user_+1),50
    ld      a,19+9
    ld      (_coord_x),a
    ld      a,19
    ld      (_coord_y),a

    call    coords2dfile
    ld      (iy+aL_),l
    ld      (iy+aH_),h

fnmain:
    call    readinput
    call    waitvsync
    YIELD

    dec     (iy+user_+1)        ; timer
    jr      nz,{+}

    ld      (iy+user_+1),50     ; reset timer,
    ld      a,(iy+user_)
    and     a                   ;  test to see if we should play a note
    call    nz,playmiddlec

    ld      l,(iy+aL_)
    ld      h,(iy+aH_)
    ld      a,(hl)
    xor     $8d
    and     (iy+user_)
    ld      (hl),a

+:  ld      a,(play)            ; test play toggle
    cp      1
    jr      nz,fnmain

    ld      a,(iy+user_)        ; toggle play on/off
    xor     $ff
    ld      (iy+user_),a

    ld      (iy+user_+1),1      ; reset timer so we play immediately if enabled
    jr      fnmain


    ;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    ;
    ; Kill time until we notice the FRAMES variable change
    ;
    ; A display has just been produced, and now we can continue.
    ;
waitvsync:
    ld      hl,FRAMES
    ld      a,(hl)
-:  cp      (hl)
    jr      z,{-}
    ret

#include "input.asm"
#include "midi.asm"
#include "selectaUD.asm"
#include "selectaLR.asm"

endhere:
; ------------------------------------------------------------

#include "include/zxline1.asm"

    .end
