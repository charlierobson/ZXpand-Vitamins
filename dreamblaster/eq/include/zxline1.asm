
    ; end of line for BASIC
    .byte $76

line1:
    .byte   0,1                         ; line number
    .word   exdfile-$-2                 ; line length

    .byte   $f9,$d4,$c5                 ; RAND USR VAL
    .byte   $b,$1d,$22,$21,$1d,$20,$b   ; "16514"
    .byte   $76                         ; N/L

exdfile:
   .byte    $76
.repeat 24
   .fill    32,0
   .byte    $76
.loop

;- BASIC-Variables ----------------------------------------

var:
   .byte $80

;- End of program area ----------------------------

LAST:
