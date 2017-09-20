
; compares a space terminated string at hl & de, returns z if it match
;
spstrcmp:
        ld      a,(de)
        cp      (hl)
        ret     nz

        cp      $20
        ret     z

        inc     hl
        inc     de
        jr      spstrcmp


config_joy:
        ld      hl,filejoy+1    ; check for the JOYCFG.TXT in current directory
        call    fileexists      ; 
        jr      z,loadcfgjoy

        ld      hl,filejoy      ; check for the JOYCFG.TXT in root directory
        call    fileexists      ; and return if it not exists
        ret     nz              ; 

loadcfgjoy:
        xor     a
        ld      de,UPBUF        ; load the file JOYCFG.TXT
        call    api_fileop
        xor     a               ; mark the end of text with a null
        ld      (hl),a          ;

        ld      hl,FNBUF        ; convert the .p file name to ascii and copy it to FILEPATH1
        ld      de,FILEPATH1
fname2asc:
        ld      a,(hl)
        cp      $1b             ; '.'
        jr      z,putspc
        push    hl
        ld      hl,CXLATTAB     ; convert it to ascii
        call    findchar
        ld      a,l
        pop     hl
        ld      (de),a
        inc     hl
        inc     de
        jr      fname2asc

putspc:
        ld      a,$20
        ld      (de),a          ; terminate string with a space
        ld      hl,32768        ; address of config file in RAM

findjoystup:
        ld      de,FILEPATH1
        call    spstrcmp
        jr      z,advspc

tonextname
        inc     hl
        ld      a,(hl)
        or      a               ; check for end of config file
        ret     z
        cp      $0a
        jr      z,advlf
        cp      $0d
        jr      z,advcr
        jr      tonextname

advcr:
        inc     hl
advlf:
        inc     hl
        jr      findjoystup
        

advspc:
        inc     hl
        ld      a,(hl)
        cp      $20
        jr      z,advspc

; Configure the programmable joystick

        ld de,dec_keys          ; Decode the joystick keys. The keys are addressed by hl
        ld b,6                  ; the key string must contain exactly 6 characters and this
                                ; isn't checked by the program.
l01:
        ld a,(hl)
        inc hl

        push hl
        push bc
        cp '-'
        jr nz,decrow

        ld a,$ff
        inc de
        jr nokey

decrow:
        push de
        ld hl,keyb_rows+39
        ld bc,40
        cpdr
        ld d,c
        ld e,5
        call div_d_e
        inc a
        ld b,a
        ld e,d
        ld d,0
        ld hl,key_row_addr
        add hl,de
        ld a,(hl)
        pop de
        ld (de),a
        inc de
        ld a,$ff
        or a
l02:
        rla
        djnz l02
nokey:
        ld (de),a
        inc de
        pop bc
        pop hl
        djnz l01


setjoy:
; Fill setup table at $8000 with $ff
;
        ld h,$80
        ld b,8
        ld a,$ff
l03:
        ld l,$75
l04:
        ld (hl),a
        dec l
        jr nz,l04
        inc h
        djnz l03



; Now, prepare the setup table in a RAM area started
; at address $8000

        ld hl,joy_ram_ports
        ld de,dec_keys
        ld b,6          ; load counter (for six keys)
l05:
        push bc
        ld a,(de)       ; load the key row address
        inc de

        ld c,-1         ; convert the key row address to a number
l07:                    ; between $00 and $07
        rra             ;
        inc c           ;
        jr c,l07        ;

        set 7,c         ; now the number is between $80 and $87
        ld a,(de)       ; load the key pattern
        inc de
        push de
        ld d,c          ; 'de' will be used to address the RAM

        ld b,(hl)       ; load counter
        inc hl
l06:
        ld e,(hl)
        inc hl
        ex de,hl
        push af         ; save the key pattern
        and (hl)
        ld (hl),a
        pop af
        ex de,hl
        djnz l06
        pop de
        pop bc
        djnz l05


; Transfer the setup table in RAM to the joystick board

        ld h,$80
        ld b,$fe
        ld d,$08
l09:
        ld e,$3a
        ld l,$03
l08:
        ld a,(hl)
        ld c,l
        inc hl
        inc hl           ; only consider addresses with A0=1; this is necessary because an
                         ; OUT to a port with A0=A1=0 will cause a system crash
        out (c),a
        dec e
        jr nz,l08

        ld a,b
        rlca
        ld b,a
        inc h
        dec d
        jr nz,l09

        out ($fe),a     ; turn on the NMI generator and return CMDR
;        call $0f2b      ; go SLOW
        ret             ; with joystick board configured.


;:The following routine divides d by e and places the quotient in d and the remainder in a
div_d_e:
        xor a
        ld b, 8

_loop:
        sla d
        rla
        cp e
        jr c, $+4
        sub e
        inc d

        djnz _loop
   
        ret
 

filejoy:
        db  $18,$2f,$34,$3e,$28,$2b,$2c,$1b     ; /JOYCFG.TXT;32768
        db  $39,$3d,$39,$19,$1f,$1e,$23,$22
        db  $24,$ff

; Keyboard row addresses table (msb byte)
key_row_addr:
        db  $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f


; Ports to access the joystick RAM to store the key codes
joy_ram_ports:
        db  12,$11,$15,$13,$31,$51,$35,$33,$55,$53,$71,$75,$73     ;UP
        db  12,$09,$0d,$0b,$29,$49,$2d,$2b,$4d,$4c,$69,$6d,$6b     ;DOWN
        db  12,$05,$15,$0d,$25,$45,$35,$2d,$55,$4d,$65,$75,$6d     ;LEFT
        db  12,$03,$13,$0b,$23,$43,$33,$2b,$53,$4b,$63,$73,$6b     ;RIGHT
        db  18,$21,$23,$25,$29,$31,$2b,$33,$2d,$35,$61,$63,$65     ;BUTTON 1
        db  $69,$71,$6b,$73,$6d,$75
        db  18,$41,$43,$45,$49,$51,$4b,$53,$4d,$55,$61,$63,$65     ;BUTTON 2
        db  $69,$71,$6b,$73,$6d,$75


;Keyboard rows
keyb_rows:
        db  "^ZXCV"                ;address $fe
        db  "ASDFG"                ;address $fd
        db  "QWERT"                ;address $fb
        db  "12345"                ;address $f7
        db  "09876"                ;address $ef
        db  "POIUY"                ;address $df
        db  "#LKJH"                ;address $bf
        db  "_.MNB"                ;address $7f


; Decoded keys. The key code is decoded in two bytes: the row address
; and the position of the key in a row. 
; Preseted with keys 7,6,5,8,0 and NEWLINE, respectivelly.
dec_keys:
        db  $ef,$f7                       ;UP
        db  $ef,$ef                       ;DW
        db  $f7,$ef                       ;LF
        db  $ef,$fb                       ;RG
        db  $ef,$fe                       ;B1
        db  $bf,$fe                       ;B2
