
;= First BASIC line, asm code ==================================

line0:
   db $00,$00     ; line number
   dw line1-$-2   ; line length

   db $ea         ; REM

   db $7e         ; m/c for ld a,(hl),  BASIC token for 'next 5 bytes are fp number'
   jp starthere ;
   db 0,0         ; ... what a neat trick - thanks!

   db $76      ; end of line
   db $76      ; end of line

