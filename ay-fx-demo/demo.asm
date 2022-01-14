;;
;; Compile with "brass -s cmdr.asm cmdr.p"
;;

; contains directives to map ascii->zxcsii in '.asc' statements
#include "charmap.asm"

; A useful reference
;
;  ____0___1___2___3___4___5___6___7___8___9___A___B___C___D___E___F____
;  00 SPC GRA GRA GRA GRA GRA GRA GRA GRA GRA GRA  "  GBP  $   :   ?  0F
;  10  (   )   >   <   =   +   -   *   /   ;   ,   .   0   1   2   3  1F
;  20  4   5   6   7   8   9   A   B   C   D   E   F   G   H   I   J  2F
;  30  K   L   M   N   O   P   Q   R   S   T   U   V   W   X   Y   Z  3F

; the BRASS assembler requires this
.emptyfill	0


; TASM/BRASS cross-assembler definitions
;
#define  db    .byte
#define  dw    .word
#define  ds    .block
#define  dt    .text
#define  equ   .equ
#define  org   .org
#define  end   .end

         org   $4009

#include "sysvars.asm"
#include "zxRem0.asm"

;; STARTS HERE ;)

starthere:
   ld    hl,sfx
   call  AFXINIT

   ld    bc,$0101
   ld    hl,message
   call  printstringat

   ld    ix,isr

mainloop:
   call  waitsync

   call  keyinput
   jr    z,mainloop

   cp    $1d
   jr    c,mainloop

   cp    $26
   jr    nc,mainloop

   sub   $1c ; 1..9
   call  AFXPLAY
   jr    mainloop


; ------------------------------------------------------------

isr:
   ld    a,r
   ld    bc,$1901
   ld    a,$f5
   call  $02b5
   call  $0292
   call  $0220

   push  iy
   call  AFXFRAME
   pop   iy

   ld    ix,isr
   jp    $02a4


; ------------------------------------------------------------



KBSTATE = 33 ; unused sysvar

; return with z flag set if no key pressed, otherwise A has key code.
;
keyinput:
   bit   0,(iy+KBSTATE)
   jr    nz,ip_look4key

   ; state 0 - return with z flag set while we're waiting for a key to be released

   call  $2bb              ; kscan
   inc   l
   jr    nz,ip_retnokey    ; if value is not 255, then a key is still pressed

   set   0,(iy+KBSTATE)    ; otherwise no key is pressed; next time we can start scanning for a code
   ret

ip_look4key:
   call  $2bb              ; kscan
   ld    a,l
   inc   a
   ret   z                 ; no key pressed - return with z set

   push  hl
   pop   bc
   call  $7bd              ; findchr

   ld    a,(hl)
   and   a
   jr    z,ip_retwithkey   ; space - switch state and return
   cp    $76
   jr    z,ip_retwithkey   ; enter -  "     "    "    "
   cp    $77
   jr    z,ip_retwithkey   ; rubout -  "     "    "    "

   cp    $0b               ; exclude gfx/multibyte chars
   jr    c,ip_retnokey    ; ie less than B,
   cp    $40
   jr    nc,ip_retnokey    ; greater than or equal to 64

ip_retwithkey:
   res   0,(iy+KBSTATE)    ; indicate we need to wait for key release
   cp    $ff               ; return with Z flag clear to indicate key is present
   ret

ip_retnokey:
   ld    a,0
   and   a
   ret


; clear memory to 0 - specialisation of fill mem
;
clearmem:
   xor   a

; fils BC bytes of memory starting at HL
;
fillmem:
   push  de
   ld    (hl),a
   push  hl
   pop   de
   inc   de
   ldir
   pop   de
   ret



; ------------------------------------------------------------
; -ZXPANDY-STUFF----------------------------------------------
; ------------------------------------------------------------

; set memory map to 16-48k
;
memhigh:
   ld    a,$b3
   jr    memwind

; set memory map to 8-40k
;
memlow:
   ld    a,$b2

memwind:
   ld    bc,$e007             ; set RAM page window on zxpand
   out   (c),a

   ; it takes a little time for the mapping to 'take'

   ret



; ------------------------------------------------------------
; -STUFF------------------------------------------------------
; ------------------------------------------------------------


; wait for a vertical sync to happen
;
waitsync:
   ld    hl,FRAMES
   ld    a,(hl)
ws_loop:
   cp    (hl)
   jr    z,ws_loop
   ret


; ------------------------------------------------------------
; -SCREEN-IO--------------------------------------------------
; ------------------------------------------------------------


; BC is screen coords,
;
printstringat:
   call  pr_pos

; hl is pointer to string with a $ff terminator
;
printstring:
   ld    a,(hl)
   and   a
   ret   m
   call  printa
   inc   hl
   jr    printstring



; BC is YX. SCR_POS = D_FILE + (33*B) + 1 + C
;
pr_pos:
   push  hl
   call  scrmemcalc
   ld    (SCR_POS),hl
   pop   hl
   ret



; calculate address of byte in screen ram
; BC = YX
;
scrmemcalc:
   push  de
   ld    l,b            ; hl = b
   ld    h,0
   push  hl             ; de = hl
   pop   de
   call  hltimes32      ; hl *= 33
   add   hl,de
   push  hl
   ld    a,c
   call  stkAdd8
   pop   hl

   ld    de,(D_FILE)
   inc   de
   add   hl,de
   pop   de
   ret


; 'print' character in A, advance SCR_POS pointer, skips NEWLINEs
; set (iy+PRINTMOD) to $80 to print inverted chars
; returns with Z flag set unless last character cell was an EOL
;
printa:
   push  hl
   ld    hl,(SCR_POS)
   ld    (hl),a
   inc   hl
   bit   6,(hl)
   jr    z,pra_noteol
   inc   hl
pra_noteol:
   ld    (SCR_POS),hl
   pop   hl
   ret



; 'print' B characters in A
;
printna:
   call  printa
   djnz  printna
   ret




; multiply HL by some power of 2
;
hltimes32:
   sla   l
   rl    h
hltimes16:
   sla   l
   rl    h
hltimes8:
   sla   l
   rl    h
hltimes4:
   sla   l
   rl    h
hltimes2:
   sla   l
   rl    h
   ret



addAtohl:
   add   a,l
   ld    l,a
   ret   nc
   inc   h
   ret


; adds 8 bit value in A register to 16 bit value on stack.
;
; preserves hl, bc, de
;
stkAdd8:
   ex    (sp),hl        ; return address into hl, save previous value
   ld    (stkExit+1),hl ; remove need for return address on stack
   pop   hl             ; restores previous HL

   ex    (sp),hl        ; get parameter value in HL, store previous hl
   push  de             ; we can now use stack
   ld    e,a            ; a -> de
   ld    d,0
   add   hl,de
   pop   de
   ex    (sp),hl        ; store result and recover previous HL

   jr    stkExit


; adds the 2 top stack entries leaving sum on the stack - tricky!!
;
; preserves hl, bc, de
;
stkAdd16:
   ex    (sp),hl           ; swap hl for return address off stack and
   ld    (stkExit+1),hl    ; store ret addr as jump at the end of the routine,
   pop   hl                ; recover hl. so far so good - hl is preserved and the ret addr is gone.

;  after this op:    HL  DE   STACK (*=SP)
                  ;  777 999  *12   30
   ex    (sp),hl  ;  12  999  *999  30
   ex    de,hl    ;  999 12   *999  30
   inc   sp       ;
   inc   sp       ;  999 12    999 *30
   ex    (sp),hl  ;  30  12    999 *777
   add   hl,de    ;  42  12    999 *777
   ex    (sp),hl  ;  777 12    999 *42
   dec   sp       ;
   dec   sp       ;  777 12   *999  42
   pop   de       ;  777 999   42
   ex    de,hl    ;  999 777   42

   jr    stkExit


; multiply the number at the top of the stack by 16
;
; preserves a, hl, bc, de
;
stkmul16:
   ex    (sp),hl
   ld    (stkExit+1),hl
   pop   hl

   ex    (sp),hl
   call  hltimes16
   ex    (sp),hl              ; store result and recover previous HL

stkExit:
   jp    0



SCR_POS:
   dw    0


   #include "ayfxplay.asm"

sfx:
   #incbin "demo.afb"

message:
   .asc  "press keys 1..9"
   .db   $ff



   ; end of line for BASIC
   db $76

line1:
   .byte 0,1                     ; line number
   .word xxdfile-$-2             ; line length

   .byte $f9,$d4,$c5             ; RAND USR VAL
   .byte $0b,$1d,$22,$21,$1d,$20,$0b  ; "16514"
   .byte $76                     ; N/L

;- Display file --------------------------------------------

xxdfile:
   db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76
   ds 32 \ db $76

;- BASIC-Variables ----------------------------------------

var:
   db $80

;- End of program area ----------------------------

LAST:

   end
