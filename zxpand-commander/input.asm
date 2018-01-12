

waitnokey:
   call  $2bb           ; kscan - loop while a key is already pressed
   inc   l
   jr    nz,waitnokey
   ret


waitforkey:
   call  $2bb           ; kscan - loop while a key is already pressed
   inc   l
   jr    nz,waitforkey

gk_wait:
   call  $2bb           ; kscan - loop while no key is pressed
   push  hl
   pop   bc
   ld    d,c
   inc   d
   jr    z,gk_wait

   call  $7bd           ; findchr
   ld    a,(hl)
   and   a
   ret   z              ; space
   cp    $77
   ret   z              ; rubout
   cp    $76
   ret   z              ; return

   cp    $0b            ; exclude gfx/multibyte chars
   jr    c,gk_wait
   cp    $40
   jr    nc,gk_wait

   ret



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



showcursor:
   ld    a,(FRAMES)
   and   $10
   sla   a
   sla   a
   sla   a
   call  printa
   ld    hl,(SCR_POS)
   dec   hl
   ld    (SCR_POS),hl
   ret



; hl - string to edit (high-bit terminated)
;
editbuffer:
   push  hl                   ; save source string location

   ld    bc,(SCR_POS)         ; save this so we can compare and copy later
   ld    (eb_delete+1),bc
   ld    (eb_done+1),bc

   call  printstring

eb_loop:
   call  showcursor
   call  keyinput
   jr    z,eb_loop

   and   a                    ; should be test for illegal character, only space atm
   jr    z,eb_loop

   cp    $76                  ; enter
   jr    z,eb_done

   cp    $77                  ; rubout
   jr    z,eb_delete

   cp    $0c                  ; quit
   jr    z,eb_exit

   call  printa               ; add the character
   ; todo - cap the length?
   jr    eb_loop


eb_delete:
   ld    de,0                 ; [self modifies]
   ld    hl,(SCR_POS)
   and   a
   sbc   hl,de
   jr    z,eb_loop             ; can't delete - at start of line

   ld    hl,(SCR_POS)
   xor   a
   call  printa
   dec   hl
   ld    (SCR_POS),hl
   jr    eb_loop

eb_done:
   ld    de,0                 ; [smc] copy the edited string back from whence it came
   push  de                   ; source - start of string
   ld    hl,(SCR_POS)         ; calculate string length
   and   a
   sbc   hl,de
   push  hl
   pop   bc
   pop   hl                   ; source - start of string
   pop   de                   ; string's origin address
   ldir
   ex    de,hl                ; terminate target string
   ld    (hl),$ff
   ret

eb_exit:
   xor   a                    ; return with z set if edit aborted
   pop   hl
   ret
