; ====== Text View =====================================================
; By Kelly Abrantes Murta - Nov 2012
;

loadfile:
   xor   a
   call  api_fileop
   call  errorhandler
   ret   nc
   pop   hl
   ret



verifytxt:
   ; change to the selected directory

   ld    hl,DIRNAME
   ld    a,$12                ; '>' - change to the selected directory
   call  dircommand

   call  errorhandler
   ret   c

   ld    hl,FNBUF             ; copy the selected filename up to filepath1 and set the high bit of the name

   ld    de,FILEPATH1
   call  copystring           ; copy the name

   call  $02e7               ; go fast - don't use proxy as we really really do need to disable nmis at this point

   ld    hl,txtdestadd
   call  copystring          ; append the destination address to the name
   ld    de,FILEPATH1
   call  loadfile            ; load the text file
   
   xor   a                   ; mark the end of text with a null
   ld    (hl),a              ;
   inc   hl
   ld    (ssb),hl
   ld    (ssp),hl

   ; no need - now it's incbin'd
;   ld    hl,fntfile          ; load the font file
;   ld    de,FILEPATH1
;   call  copystrTHB
;   call  loadfile



tview:
        call    clshr
        call    $0f2b           ; SLOW
        call    hron

        ld      hl,start_txt

new_scr:
        call    clshr
        ld      (cur_scr),hl

clr_aLF:
        xor     a               ; reset the auto LF flag
        ld      (autoLF),a

get_char:
        ld      a,(hl)          ; read character
        inc     hl
        cp      0               ; is it the end of text mark?
        jr      z,keyb_rd
        cp      10              ; is it a LF ?
        jr      z,prt_LF
        cp      13              ; is it a CR (followed by LF) ? 
        jr      z,pass_LF

        ld      b,a
        xor     a               ; reset the auto LF flag
        ld      (autoLF),a
        ld      a,b


        cp      32              ; it is a space?
        jr      z,is_SPC
        jr      c,get_char      ; any other control character is discarded

        dec     hl              ; Starts word processing
        push    hl              ; save pointer
        ld      b,-1
cnt_chars:                      ; count chars
        ld      a,(hl)
        inc     hl
        inc     b
        cp      $21             ; repeat until a space or control char is found ( A <= 32 )
        jr      nc,cnt_chars
        pop     hl              ; restore text pointer
        ld      a,(curCol)
        add     a,b             ; B = word lenght
        cp      43              ; the word fits in the line?
        jr      c,chk_wlen
        ld      a,(curCol)      ; checks that it is the first column
        or      a
        jr      z,chk_wlen
        ld      a,10            ; If not the first column, advances to the next
        call    print42         ; line (print lf)
        jr      chk_eos

chk_wlen:
        ld      a,42            ; If the word has length greater than 42 then prints
        cp      b               ; only first 42 characters and leaves the remaining
        jr      nc,prt_wrd      ; to be printed at the next line
        ld      b,a
prt_wrd
        ld      a,(hl)
        inc     hl
        call    print42
        djnz    prt_wrd
        jr      chk_eos


is_SPC:
        ld      a,(curCol)      ; Verifies if is at the first column and print immediately
        or      a               ; the space only if not at column 0
        jr      nz,nfcol
        dec     hl              ; If is at column 0, checks if last char printed
        dec     hl              ; was LF and prints the space only if so
        ld      a,(hl)
        inc     hl
        inc     hl
        cp      10
        jr      nz,get_char     ; return to process the next char
nfcol:
        ld      a,32
        jr      prt_SPC

pass_LF:
        inc     hl
prt_LF:
        ld      a,(autoLF)      ; Discards printing CR/LF immediately after
        or      a               ; an automatic LF
        jr      nz,clr_aLF
        ld      a,10            ; A = LF
prt_SPC:
        call    print42
chk_eos:                        ; checks if reached the end of screen
        ld      a,(curRow)      ; A=linha
        cp      24
        jr      c,get_char

keyb_rd:
        push    hl
        call    waitforkey
        pop     hl
        cp      $22             ; checks for key 6 (page down)
        jr      z,pag_down
        cp      $23             ; checks for key 7 (page up)
        jr      z,pag_up
        cp      $25             ; checks for key 9  (invert the screen)
        jr      z,inv_scr
        and     a               ; checks for key SPC (ends the text view)
        jr      nz,keyb_rd

        call    hroff           ; exit from text view
        call    reloaddir
        ret


pag_up:
        push    hl
        ld      hl,(cur_scr)    ; If it is on the first text screen, ignores the key 7
        ld      de,start_txt
        sbc     hl,de
        pop     hl
        jr      z,keyb_rd
        call    pop_scr         ; Process previos text screen
        jp      new_scr


pag_down:
        ex      de,hl
        ld      hl,(ssb)        ; If it is on the last text screen, ignores the key 6
        sbc     hl,de
        ex      de,hl
        jr      z,keyb_rd
        call    push_scr        ; Process next text screen
        jp      new_scr


push_scr:
        push    hl
        ld      de,(cur_scr)
        ld      hl,(ssp)
        ld      (hl),e
        inc     hl
        ld      (hl),d
        inc     hl
        ld      (ssp),hl
        ex      de,hl
        pop     hl
        ret


pop_scr:
        ld      hl,(ssp)
        dec     hl
        ld      d,(hl)
        dec     hl
        ld      e,(hl)
        ld      (ssp),hl
        ex      de,hl
        ret


; Clear the HR screen
clshr:
        push    hl
        push    de
        push    bc
        ld      hl,0
        ld      (curRow),hl
        ld      de,$8001
        ld      h,d
        ld      bc,$17ff
        ld      (hl),0
        ldir
        pop     bc
        pop     de
        pop     hl
        ret


; Invert the HR screen
inv_scr:
        push    hl
        call    waitnokey       ; wait for release key
        call    inv_dd
        pop     hl
        jp      keyb_rd

inv_dd:
        ld      hl,lbuf+2
        ld      b,32
inv_lp:
        ld      a,$80
        xor     (hl)
        ld      (hl),a
        inc     hl
        djnz    inv_lp
        ret


; ===== HR drive =====================================================

hron:
        ld      hl,lbuf+2
        bit     7,(hl)          ; if the 'dummy display' is prepared to invert screen (bit 7 = 1),
        jr      z,sethr         ; then change it to no invert.
        call    inv_dd
sethr:
        ld      ix,hr           ; simple start of the hres mode
        ret

hroff:
        ld      a,$1e
        ld      i,a
        ld      ix,$0281
        ret


lbuf:   ld r,a      ;load HFILE address LSB
        db 0, 0, 0, 0     ;32 NOPs = 256 pixels
        db 0, 0, 0, 0
        db 0, 0, 0, 0 
        db 0, 0, 0, 0 
        db 0, 0, 0, 0 
        db 0, 0, 0, 0 
        db 0, 0, 0, 0
        db 0, 0, 0, 0
        ret nz      ;always returns
 
hr:
        xor (hl)     ;delay
        ld b,7       ;delay
hr0:    djnz hr0     ;delay
        dec b        ;reset z flag
        ld hl,$8000  ;HFILE 
        ld de,$20    ;32 bytes per line
        ld b,$c0     ;192 lines per hires screen
hr1:    ld a,h       ;get HFILE address MSB
        ld i,a       ;load MSB into I register
        ld a,l       ;get HFILE address LSB
        call lbuf + $8000
        add hl,de    ;next line
        dec b        ;dec line counter
        jp nz,hr1    ;last line

hr2:
        call $292    ;return to application program
        call $220    ;extra register PUSH and VSYNC
        ld ix,hr     ;load the HR vector
        jp $2a4      ;return to application program


; ===== Print 42 =====================================================

print42:
        push    hl
        push    de
        push    bc
        exx
        push    hl
        ld      hl,curCol
        cp      10                      ; A = LF ?
        jr      z,newline
;        cp      13                      ; A = CR ?
;        jr      z,newline
        ;ld      h,$13                   ; H="value base" of character table
        ld      h,fontdata/2048
        ld      l,a                     ; L=character
        add     hl, hl
        add     hl, hl
        add     hl, hl                  ; HL = "value base" * 2048 + character * 8

        exx

        ld      a,(curRow)              ; A=line

; converte the line A in the screen coordinate ( HL = (A + screen base address) * 32 * 8  )
        or      $80                    ; add to screen base address
        ld      h,a
        ld      l,0

        ld      a,(curCol)              ; A=column (0~41)

        ld      e,a
        add     a,e
        add     a,e
        add     a,e
        add     a,e
        add     a,e
        inc     a
        inc     a                       ; A = column * 6 + 2

        ld      e,a
        ld      d,0
        srl     e
        srl     e
        srl     e                       ; DE = (column * 6 +2) / 8
        add     hl,de                   ; HL = line + column screen addres
        push    hl
        cpl
        and     $07
        inc     a
        ld      (shft),a
        and     $07
        ld      e,a
        ld      d,0
        ld      hl,charmask
        add     hl,de
        ld      d,(hl)                  ; left mask
        inc     hl
        ld      e,(hl)                  ; right mask
        pop     hl

        exx

        ld      b,$08
gptrn:  ld      a,(hl)                  ; char pixel pattern

        exx

        ld      c,a
        ld      a,(shft)
        cp      $05
        jr      c,sft24                 ; Jumps when SHFT is equal 2 or 4
        cpl                             ; SHFT = 6 or 8
        add     a,$09
        and     a
        ld      b,a
        ld      a,c
        ld      c,$00
        jr      z,norot                 ; Jump if SHFT = 8 (the character does not rotate)
rotrg:  rra                             ; SHFT = 6 (rotate right 2 times)
        rr      c                       ;
        djnz    rotrg                   ;
        jr      norot
sft24:  ld      b,a                     ; Rotate left 2 (SHFT = 2) or 4 (SHFT =4) times
        xor     a                       ; 
rotlf:  rl      c                       ;
        rla                             ;
        djnz    rotlf                   ;

norot:  ld      b,a                     ; B = char pixel pattern
        ld      a,d                     ; apply left mask
        and     (hl)                    ;
        or      b                       ; print char left side
        ld      (hl),a                  ;
        inc     hl
        ld      a,e                     ; apply right mask
        and     (hl)                    ;
        or      c                       ; print char right side
        ld      (hl),a                  ;
        ld      bc,$1f                  ; change to the next screen pixel line
        add     hl,bc                   ;
        exx
        inc     hl                      ; points to next char pixel pattern
        djnz    gptrn

        ld      hl,curCol               ; change to next screen column
        ld      a,(hl)                  ;
        inc     a                       ;
        ld      (hl),a                  ;
        cp      42
        jr      c,pr_exit
        ld      a,1                     ; set LF auto flag: this prevents printing CR/LF at the 
        ld      (autoLF),a              ; end of a line with 42 characters, when occurs an
                                        ; automatic LF
newline:
        xor a                           ; prints a LF
        ld      (hl),a
        dec     hl
        inc     (hl)

pr_exit:                                ; exit
        pop     hl
        exx
        pop     bc
        pop     de
        pop     hl
        ret


curRow: db      0
curCol: db      0
shft:   db      0

charmask:
        db %00000011, %11111111
        db %11111100, %00001111
        db %11110000, %00111111
        db %11000000, %11111111


ssb:            dw      0       ; Base address of the stack of screens
ssp:            dw      0       ; Stack pointer screens
cur_scr:        dw      0       ; Current screen
autoLF:         db      0       ; Auto LF flag

start_txt       equ     38912           ; Where the text file will be loaded

txtdestadd:
   db    $19,$1f,$24,$25,$1d,$1e,$ff    ; ';38912'

;fntfile:
;   db    $18,$27,$2e,$33,$18,$2b       ; '/BIN/FT885915.BIN;38912'
;   db    $39,$24,$24,$21,$25,$1d
;   db    $21,$1b,$27,$2e,$33,$19
;   db    $1f,$24,$25,$1d,$1e,$ff
