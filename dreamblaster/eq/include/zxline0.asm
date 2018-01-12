
;= First BASIC line, asm code ==================================

line0:
   .byte $00,$00     ; line number
   .word line1-$-2   ; line length

   .byte $ea         ; REM

   .byte $7e         ; m/c for ld a,(hl),  BASIC token for 'next 5 bytes are fp number'
   jp starthere ;
   .byte 0,0         ; ... what a neat trick - thanks!

   .byte $76      ; end of line
   .byte $76      ; end of line

