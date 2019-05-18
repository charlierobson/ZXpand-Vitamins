;;
;; Compile with "tasm -80 -b cmdr.asm cmdr.p"
;;

; A useful reference
;
;  ____0___1___2___3___4___5___6___7___8___9___A___B___C___D___E___F____
;  00 SPC GRA GRA GRA GRA GRA GRA GRA GRA GRA GRA  "  GBP  $   :   ?  0F
;  10  (   )   >   <   =   +   -   *   /   ;   ,   .   0   1   2   3  1F
;  20  4   5   6   7   8   9   A   B   C   D   E   F   G   H   I   J  2F
;  30  K   L   M   N   O   P   Q   R   S   T   U   V   W   X   Y   Z  3F

; the BRASS assembler requires this
.emptyfill	0


; TASM cross-assembler definitions
;
#define  db    .byte
#define  dw    .word
#define  ds    .block
#define  dt    .text
#define  equ   .equ
#define  org   .org
#define  end   .end

; Some EQUates

PATSEP      .equ  $18         ; '/'

; the following are offsets into the calculator's workspace RAM
;
CURPANE     .equ  $5d         ; pane flag, 0 or 1
PRINTMOD    .equ  $5e         ; inverse flag, 0 or $80
DBFLAG      .equ  $5f         ; show last-k value on screen
FFLAGS      .equ  $60         ; selected file flags
KBSTATE     .equ  $61         ; flag indicates waiting for release or press
XLOADFLAG   .equ  $62         ; bit 0 set indicates we need a ';x' on the load command
RENFLAGS    .equ  $63         ; rename flags
ZXPTYPE     .equ  $64         ; zxpand state flags

NUMINLIST   .equ  19
MAXLISTIDX  .equ  NUMINLIST-1

CXLATTAB    .equ  $7000
FILEPATH1   .equ  $6f80
FILEPATH2   .equ  $6f00
PANEW       .equ  $6e80
pnNENTRIES  .equ  0
pnTOPENTRY  .equ  2
pnSELECTION .equ  4
pnDATAPTR   .equ  6
pnSCROFFS   .equ  8
pnDIRNAME   .equ  10
NENTRIES    .equ  PANEW+pnNENTRIES
TOPENTRY    .equ  PANEW+pnTOPENTRY
SELECTION   .equ  PANEW+pnSELECTION
DATAPTR     .equ  PANEW+pnDATAPTR
SCROFFS     .equ  PANEW+pnSCROFFS
DIRNAME     .equ  PANEW+pnDIRNAME
PANEWENDx    .equ  $6f00
PANEDATALEN .equ  PANEWENDx-PANEW
PANE1DATA   .equ  $6e00
PANE2DATA   .equ  $6d80
BBDEST      .equ  $6d00
UPBUF       .equ  $6c00

; wait for long command to finish, a has response code on return
;
api_responder  .equ $1ff6

; de = fname pointer, with optional start,length;  a = operation.: 0 = load, 1 = delete, 2 = rename, 80-ff = save
;
api_fileop     .equ $1ff8

; de = high bit terminated string, terminating zero will be sent
;
api_sendstring .equ $1ffa

; de = memory to xfer, l = len, a = mode: 0 = read, 1 = write
;
api_xfer       .equ $1ffc

; C has joy bits on return 7:5 := UDLRF---
;
api_rdjoy      .equ $1ffe



         org   $4009


#include "sysvars.asm"
#include "zxRem0.asm"


;; STARTS HERE ;)


starthere:
   xor   a
   ld    (iy+CURPANE),a
   ld    (iy+DBFLAG),a
   ld    (iy+PRINTMOD),a
   ld    (iy+KBSTATE),a
   ld    (iy+XLOADFLAG),a

   call   memhigh                ; ram at 16-48k

   call  detectZXpandType
   ld    (iy+ZXPTYPE),a

; ===== Set Joy patch (kmurta) =========================================
   call  setjoy
; ======================================================================

   ; convert the ascii source to zeddy strings
   ;
   call  initconvert             ; initialise the ascii->zeddy conversion table above RAMTOP
   ld    hl,stringsforconversion
   call  inplaceconvert

   ; prevent re-entry if the program is run twice
   ;
   ld    a,$c9                   ; RET
   ld    (inplaceconvert),a

   call  initpanedata

   ; load and display PANE1 data
   ;
   call  pane1                   ; copy pane 1 info into working block
   call  loaddir                 ; updates working block
   call  acceptpanechanges       ; copy updated info in working pane back to the originator

   call  drawscreen

mainloop:
   call  waitsync
   call  keyshow
   call  keyhandler
   jr    mainloop








; ------------------------------------------------------------
; if A is not RT_OK then pop open a window showing the error
; text. wait for a key and clear up.
;
; on return carry indicates error state
;
errorhandler:
   cp    $40
   jr    nz,eh_error

   and   a
   ret

eh_error:
   and   $1f ; extend error numbers to 31
   call  geterror
   push  hl
   ld    bc,$0a00
   call  box
   pop   hl
   ld    bc,$0b00
   call  centrestring
   call  invertscreen
   call  invertscreen
   call  invertscreen
   call  invertscreen
   call  waitforkey
   call  unbox
   call  waitnokey
   and   a
   ccf
   ret


; ------------------------------------------------------------
; load directory content to memory. directory is stored in DIRNAME,
; target memory address in DATAPTR
;
loaddir:
   ld    de,0
   ld    (SELECTION),de
   ld    (TOPENTRY),de

reloaddir:
   ld    hl,(DATAPTR)
   ld    bc,16*20
   call  clearmem

   ld    hl,DIRNAME           ; create a high-bit terminated copy of DIRNAME as expected by sendstring
   ld    de,UPBUF
   call  copystrTHB
   call  api_sendstring

   ld    bc,$6007             ; open dir
   ld    a,0
   out   (c),a
   call  api_responder

   call  errorhandler
   ret   c

   ld    de,0
   ld    (NENTRIES),de

   ld    de,(DATAPTR)

ld_findnext:
   ld    bc,$6007             ; next entry
   or    $ff
   out   (c),a
   call  api_responder

   cp    $3f                  ; done?
   ret   z

   call  errorhandler
   ret   c

   ld    l,16                 ; 12b'name + 1b'flags + 3b'length
   xor   a
   call  api_xfer             ; de will be left pointing to byte after transferred data

   ld    hl,(NENTRIES)
   inc   hl
   ld    (NENTRIES),hl

   ld    a,h                  ; cap entry count at 512
   cp    2
   ret   z

   jr    ld_findnext




; ------------------------------------------------------------
; draw the file list according to the parameters loaded in the working block
;
drawlist:
   ld    a,(NENTRIES)
   and   a
   ret   z

   ld    hl,(TOPENTRY)
   call  hltimes16
   ld    de,(DATAPTR)
   add   hl,de

   call  getscroffs           ; screen offset into DE

   ld    b,NUMINLIST

dl_main:
   push  bc

   push  de
   push  hl

   ld    b,12                 ; max characters to draw
   ld    c,$ff                ; AND mask which will be set to 0 when the 1st space is encountered

dl_loop
   ld    a,(hl)
   and   a                    ; test for 0
   jr    nz,dl_notspc

   ld    c,a                  ; clear the AND mask so that any junk after the filename is shown as spaces

dl_notspc:
   and   c
   ld    (de),a
   inc   hl
   inc   de
   djnz  dl_loop

   ; all 12 character spaces in the list are filled. this prevents overdraw issues.

   ld    a,16
   call  stkAdd8
   pop   hl

   ld    a,33
   call  stkAdd8
   pop   de

   pop   bc
   djnz  dl_main

   ret



; ------------------------------------------------------------
; copy item name into the FNBUF and get its length
;
parsefileinfo:
   ld    hl,(SELECTION)       ; now find the associated item in memory
   ld    de,(TOPENTRY)
   add   hl,de
   call  hltimes16
   ld    de,(DATAPTR)
   add   hl,de

   ld    de,FNBUF-1           ; increment before store, so de is left pointing at last byte
   jr    pfi_start

pfi_copy:
   cp    $12                  ; '>'
   jr    z,pfi_skip
   cp    $13                  ; '<'
   jr    z,pfi_skip

   inc   de                   ; only store characters, not '<...>' enclosure
   ld    (de),a

pfi_skip:
   inc   hl

pfi_start:
   ld    a,(hl)
   and   a
   jr    nz,pfi_copy

pfi_done:
   inc   de
   ld    a,$ff                ; terminate file name string with high bit
   ld    (de),a

   inc   hl
   ld    a,(hl)               ; (byte) flags
   ld    (iy+FFLAGS),a
   inc   hl
   ld    a,(hl)               ; (word) length - technically it's 3 bytes though.
   ld    (FLEN),a
   inc   hl
   ld    a,(hl)
   ld    (FLEN+1),a

   ret


; ------------------------------------------------------------


; remove item highlighting
;
lolightitem:
   ld    hl,$7fe6             ; AND $7F
   ld    (hl_action),hl
   jr    hli_go


; highlight the selected item on screen
;
highlightitem:
   ld    hl,$80f6             ; OR $80
   ld    (hl_action),hl

hli_go:
   ld    hl,(SELECTION)
   call  hltimes33
   call  getscroffs
   add   hl,de
   dec   hl
   ld    b,14

hli_loop:
   ld    a,(hl)
hl_action:
   nop                        ; [SMC] will be replaced by required op
   nop
   ld    (hl),a
   inc   hl
   djnz  hli_loop

   ret



; ------------------------------------------------------------
; -PANE-DATA-HANDLING-----------------------------------------
; ------------------------------------------------------------



initpanedata:
   xor   a
   ld    hl,PANE1DATA
   ld    (hl),a
   ld    de,PANE1DATA+1
   ld    bc,(PANEDATALEN*3)+1
   ldir
   ld    hl,$8000
   ld    (PANE1DATA+pnDATAPTR),hl
   ld    hl,$a000
   ld    (PANE2DATA+pnDATAPTR),hl
   ld    hl,$0202
   ld    (PANE1DATA+pnSCROFFS),hl
   ld    hl,$0212
   ld    (PANE2DATA+pnSCROFFS),hl
   ld    a,PATSEP                      ; '/'
   ld    (PANE1DATA+pnDIRNAME),a
   ld    a,$ff
   ld    (PANE1DATA+pnDIRNAME+1),a
   ret


; ------------------------------------------------------------


; copy content of pane 1 info block into working area
;
pane1:
   res   0,(iy+CURPANE)
   jr    initpanew

; copy content of pane 2 info block into working area
;
pane2:
   set   0,(iy+CURPANE)


; copy content of pane info block, in hl, into working area
;
initpanew:
   ld    hl,PANE1DATA
   bit   0,(iy+CURPANE)
   jr    z,ipw_copy

   ld    hl,PANE2DATA

ipw_copy:
   ; hl = pointer to source pane data block
   ;
   ld    de,PANEW
   ld    bc,PANEDATALEN
   ldir
   ret


; ------------------------------------------------------------


p1reload:
   call  pane1
   jr    p2r_action

p2reload:
   call  pane2

p2r_action:
   call  reloaddir
   call  acceptpanechanges
   jp    drawlist



; ------------------------------------------------------------


reloadpanes:
   ld    a,(iy+CURPANE)
   push  af
   call  p1reload
   ld    a,(PANE2DATA+pnDIRNAME)
   and   a
   call  nz,p2reload
   pop   af
   and   a
   ret   nz
   jp    pane1


; ------------------------------------------------------------



; given the pane ID in A get its data pointer
;
getpaneptr:
   ld    hl,PANE2DATA
   and   a
   ret   nz
   ld    hl,PANE1DATA
   ret



getotherpanedirname:
   ld    a,(iy+CURPANE)
   xor   1
   call  getpaneptr
   ld    a,pnDIRNAME
   jp    addAtohl



; ------------------------------------------------------------


; copy updated working data back to the parent pane info block
;
acceptpanechanges:
   ld    a,(iy+CURPANE)
   call  getpaneptr
   ld    de,PANEW
   ex    de,hl
   ld    bc,PANEDATALEN
   ldir
   ret


; ------------------------------------------------------------


; take dirname and add the currently selected filename
;
createfilepath:
   push  de
   ld    bc,64
   ldir
   pop   hl
   jp    updatefilenamebuffer



; update the working block's path data using the path in the filename buffer.
; '..' will strip off the last folder name unless we're already at the root
;
updateFilePath:
   ld    a,(FNBUF)
   cp    $1b                  ; '.'
   jr    z,ufp_up

   ; add a directory level. another special case at the root.

   ld    hl,DIRNAME           ; find the last character in the current filename

updatefilenamebuffer:         ; entry point when creating file paths
   call  findend              ; hl points at terminator
   ld    a,PATSEP                ; check to see whether we're at the root
   dec   hl
   cp    (hl)
   inc   hl
   jr    z,ke_isroot          ; if we're not at the root then we need to add a slash

   ld    (hl),a
   inc   hl

ke_isroot:
   ld    de,FNBUF             ; concatenate the new name component
   ex    de,hl
   call  copystring
   ex    de,hl
   ret                        ; return with hl pointing at terminator

   ; remove a directory level. there's a special case when we drop back to root. 

ufp_up:
   ld    hl,DIRNAME+1

   push  hl
   ld    a,PATSEP                ; '/' - see if there are any other slashes
   call  findchar
   pop   hl

   jr    nz,ufp_toroot        ; test return from findchar - if there is only one slash in the name then we're cutting at the root

   call  findend              ; look backward from the end of the string for the last slash
   ld    a,PATSEP                ; '/'
   call  rfindchar            ; we have to guarantee the presence of a slash in the buffer else this will blow

ufp_toroot:
   ld    (hl),$ff             ; terminate the path at the previous directory.
   ret



; ------------------------------------------------------------



getscroffs:
   push  bc
   ld    bc,(SCROFFS)
   call  pr_pos
   pop   bc
   ld    de,(SCR_POS)      ; de = screen ram destination
   ret


; ------------------------------------------------------------

drawscreen:
   call  cls
   call  sidebars

   ld    bc,0
   set   7,(iy+PRINTMOD)
   ld    hl,titlestr
   call  printstringat
   res   7,(iy+PRINTMOD)

   ld    a,(iy+CURPANE)
   push  af
   call  pane1
   call  drawlist                ; put the directory listing on screen
   call  pane2
   call  drawlist                ; put the directory listing on screen
   pop   af
   bit   0,a
   call  z,pane1
   call  highlightitem           ; highlight the current selection
   call  parsefileinfo           ; get the file/dir info for the current selection
   call  drawdirectory
   jp    drawfile


; ------------------------------------------------------------


cleartoeol:
   xor   a
clr_untileol:
   call  printa
   jr    z,clr_untileol
   ret



; ------------------------------------------------------------


; draw information about the current selected directory
;
drawdirectory:
   set   7,(iy+PRINTMOD)      ; restore normal print mode
   ld    bc,$1600             ; set print position at the lower text line
   call  pr_pos
   xor   a
   call  printa
   ld    hl,DIRNAME           ; print the directory name
   call  printstring
   call  cleartoeol
   ld    bc,$1614             ; now print the file count
   call  pr_pos
   ld    hl,(NENTRIES)
   call  decimal16spc
   ld    hl,entriesstr
   call  printstring
   res   7,(iy+PRINTMOD)      ; restore normal print mode
   ret


; ------------------------------------------------------------


; draw information about the current selected file
;
drawfile:
   set   7,(iy+PRINTMOD)      ; restore normal print mode
   ld    bc,$1700             ; set print position at the lower text line
   call  pr_pos
   xor   a
   call  printa

   ld    hl,FNBUF             ; print the file name

   bit   4,(iy+FFLAGS)        ; bit 4 is set for a folder
   call  z,printstring

   call  cleartoeol

   bit   4,(iy+FFLAGS)        ; bit 4 is set for a folder
   jr    nz,df_done

   ld    bc,$1714             ; now print the file count
   call  pr_pos
   ld    hl,(FLEN)
   call  decimal16spc
   ld    hl,bytesstr
   call  printstring

   bit   0,(iy+FFLAGS)        ; bit 0 is set for a read-only file
   jr    z,df_done

   ld    bc,$1711
   call  pr_pos
   ld    a,$37                ; 'R'
   call  printa
   ld    a,$34                ; 'O'
   call  printa

df_done:
   res   7,(iy+PRINTMOD)      ; restore normal print mode
   ret


; ------------------------------------------------------------


sidebars:
   ld    hl,(D_FILE)
   inc   hl
   ld    b,22

sb_loop:
   ld    a,$05
   ld    (hl),a
   ld    de,15
   add   hl,de
   ld    a,$85
   ld    (hl),a
   inc   hl
   ld    a,$05
   ld    (hl),a
   ld    de,15
   add   hl,de
   ld    a,$85
   ld    (hl),a
   inc   hl
   inc   hl
   djnz  sb_loop
   ret

; ------------------------------------------------------------

cls:
   ld    bc,0
   call  pr_pos
   ld    bc,32*24
cl_loop:
   xor   a
   call  printa
   dec   bc
   ld    a,c
   or    b
   jr    nz,cl_loop
   ret

; ------------------------------------------------------------


; draw 64 spaces
;
spc64:
   push  bc
   ld    b,64
   xor   a
sp_loop:
   call  printa
   djnz  sp_loop
   pop   bc
   ret


; ------------------------------------------------------------

; return to basic, do not pass go, do not collect �200
;
errorhard:
   ld    hl,(ERR_SP)
   ld    sp,hl

   add   a,$3f          ; inverse 0..7
   ld    (error_t),a

   rst   08h
   
error_t:
   db    $ff



;---------------------------------------------------------------------------
; -STRING-HANDLING----------------------------------------------------------
;---------------------------------------------------------------------------


; copy a path string from hl to de, terminating at the last slash
;
copypath:
   call  copystring
   ld    a,PATSEP
   ex    de,hl
   call  rfindchar
   ld    (hl),$ff
   ret


; compares string at hl & de, returns z if same
;
strcmp:
   ld    a,(de)
   cp    (hl)
   ret   nz

   cp    $ff
   ret   z

   inc   hl
   inc   de
   jr    strcmp


; all B characters must match where b <=strlen
;
strcmpll:
   ld    a,(de)
   cp    (hl)
   ret   nz

   inc   hl
   inc   de
   djnz  strcmpll
   ret


; search a high-bit-terminated string for the given character. Will not match the last character.
; return with Z set if found
;
findchar:
   cp    (hl)
   ret   z
   bit   7,(hl)
   ret   nz
   inc   hl
   jr    findchar


; ------------------------------------------------------------


; search back through memory for given character. It must exist!
;
rfindchar:
   cp    (hl)
   ret   z
   dec   hl
   jr    rfindchar


; ------------------------------------------------------------


; search for the last character in an ff-terminated string
; leaves with hl pointing at the terminator
;
findend:
   bit   7,(hl)
   ret   nz
   inc   hl
   jr    findend


; ------------------------------------------------------------



; copies an ff-terminated string up to and including the terminator
;
copystring:
   ld    a,(hl)
   ld    (de),a
   and   a
   ret   m
   inc   hl
   inc   de
   jr    copystring



; ------------------------------------------------------------



; copies an ff-terminated string and re-terminates it with a high-bit-set final character
; de left pointing to terminating character in dest buffer. as this will mostly be used 
; with api_xxx calls, we'll preserve de
;
copystrTHB:
   push  de
   call  copystring
   dec   de
   ld    a,(de)
   or    $80
   ld    (de),a
   pop   de
   ret


; ------------------------------------------------------------


; count the number of occurrences of the character code in A
; searched-for character can't be the last, the high-bit set one
;
count:
   ld    c,0
   dec   hl

ct_next:
   inc   hl
   bit   7,(hl)
   ret   nz
   cp    (hl)
   jr    nz,ct_next
   inc   c
   jr    ct_next


; ------------------------------------------------------------


; return length, in chars, of an ff-terminated string in register C
;
strlen:
   push  hl
   xor   a
   ld    c,a

sl_loop:
   bit   7,(hl)
   jr    z,sl_next

   pop   hl
   ret

sl_next:
   inc   hl
   inc   c
   jr    sl_loop


; ------------------------------------------------------------


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


; hl = filename, ff terminated
; returns with z set if file exists and is writable
;
filewritable:
   ld    a,1
   call  fc_entry
   cp    $40
   ret   nz
   push  af
   ld    a,$80
   call  fc_cmd
   pop   af
   ret

; hl = filename, ff terminated
; returns with z set if file exists
;
fileexists:
   xor   a


fc_entry:
   push  af
   ld    de,UPBUF
   call  copystrTHB
   call  api_sendstring
   pop   af
fc_cmd:
   ld    bc,$8007
   out   (c),a
   call  api_responder
   cp    $40
   ret


; ------------------------------------------------------------


; hl points to ff-terminated directory name string
; A holds command
;
dircommand:
   ld    de,FILEPATH1
   ld    (de),a
   inc   de
   call  copystrTHB
   dec   de
   call  api_sendstring

   ld    bc,$6007             ; open dir, which will interpret '+' command and create the directory
   ld    a,0
   out   (c),a
   jp    api_responder


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

   ld    a,$ff                ; delay some time to allow paging. i'm surprised it takes this long but it does.
ep_wait:
   ex    (sp),hl
   ex    (sp),hl
   dec   a
   jr    nz,ep_wait
   ret


; ------------------------------------------------------------


; load and run a program with name stored in HL
;
executeprog:
   ld    de,FILEPATH1
   bit   0,(iy+XLOADFLAG)
   jr    z,ep_normalOrStop

   res   0,(iy+XLOADFLAG)

   call  copystring           ; copy the name
   ex    de,hl
   ld    (hl),$19             ; ';'
   inc   hl
   ld    (hl),$3d+$80         ; '[X]'
   jr    ep_golow

ep_normalOrStop:
   bit   1,(iy+XLOADFLAG)
   jr    z,ep_normal

   res   1,(iy+XLOADFLAG)

   call  copystring           ; copy the name
   ex    de,hl
   ld    (hl),227             ; ' STOP '
   jr    ep_golow

ep_normal:
   call  copystrTHB

ep_golow:
   call  memlow              ; ram at 8-40k
   
   call  $02e7               ; go fast - don't use proxy as we really really do need to disable nmis at this point

   ld    hl,ep_start         ; move code to 8K and jump there
   ld    de,$2000
   ld    bc,ep_end-ep_start
   ldir

   jp    $2000

ep_start:
   ld    hl,(ERR_SP)          ; we can't return to the old program now, so clean up the stack
   ld    sp,hl
   ld    hl,$207              ; we want to return via SLOW
   push  hl
   ld    de,FILEPATH1
   xor   a
   jp    api_fileop           ; go loader!
ep_end:

; ------------------------------------------------------------


; create a rename string from paths in FILEPATH1 & 2, perform the action
; return with A = error code or $40 if success
;
rename:
   ; concatenate the paths using a semicolon
   ;
   ld    hl,FILEPATH1
   call  findend
   ld    a,$19             ; ';'
   ld    (hl),a
   inc   hl
   ld    de,FILEPATH2
   ex    de,hl
   call  copystrTHB

   ld    de,FILEPATH1
   call  api_sendstring

   ld    bc,$8007             ; execute rename command
   ld    a,$e0
   out   (c),a

   jp    api_responder






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


gofast:
   ret
   jp    $2e7


goslow:
   ret
   jp    $207

; ------------------------------------------------------------


; move the conversion data to a location where the LSB is 0.
; dirty, dirty code. do not use. ever.
;
initconvert:
   ld    hl,convtable
   ld    de,CXLATTAB
   ld    bc,128
   ldir
   ret

; ------------------------------------------------------------

inplaceconvert:
   ld    de,CXLATTAB

ipc_loop:
   ld    a,(hl)            ; char with high bit set is the terminator
   bit   7,a
   jr    z,ipc_store

   inc   hl                ; point past the terminator to 1st char of next string or final $ff
   bit   7,(hl)
   jr    z,ipc_loop

   ret

ipc_store:
   ld    e,a
   ld    a,(de)
   ld    (hl),a
   inc   hl
   jr    ipc_loop



; ------------------------------------------------------------
; -SCREEN-IO--------------------------------------------------
; ------------------------------------------------------------

invertscreen:
   ld    hl,(D_FILE)
   ld    bc,32*24

iv_loop:
   inc   hl
   ld    a,(hl)
   cp    $76
   jr    z,iv_loop
   xor   $80
   ld    (hl),a
   dec   bc
   ld    a,b
   or    c
   jr    nz,iv_loop
   ret


; enter with B indicating line number
; hk points to string
;
centrestring:
   call  strlen
   ld    a,$20
   sub   c
   rra
   ld    c,a
   call  pr_pos
   jr    printstring


iprintstringat:
   set   7,(iy+PRINTMOD)
   call  printstringat
   res   7,(iy+PRINTMOD)
   ret

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
   or    (iy+PRINTMOD)        ; 0 or $80, in order to effect an inverted print routine
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



; print 4 digit hex value in hl
;
hexout16:
   ld    a,h
   call  hexout8
   ld    a,l


; print A register in hex
;  
hexout8:
   push  af

   rr    a
   rr    a
   rr    a
   rr    a

   call  ho8_nyb

   pop   af
   
ho8_nyb:  
   and   $0f
   add   a,$1c
   jp    printa



; print decimal representation of value in hl, in a 5 character wide cell with leading paces
;
decimal16spc:
   ld    e,0               ; leading 0 suppression flag
   ld    bc,-10000
   call  dm_digit
   ld    bc,-1000
   call  dm_digit
   ld    bc,-100
   call  dm_digit
   ld    c,-10
   call  dm_digit
   ld    c,-1
   ld    e,$ff             ; force zero suppression off

dm_digit:
   ld    a,$1c-1           ; '0'-1

dm_digit2:
   inc   a
   add   hl,bc
   jr    c,dm_digit2
   sbc   hl,bc

   cp    $1c               ; otherwise test for a zero
   jr    z,dm_output

   ld    e,$ff             ; zero suppression off when we encounter 1st non-'0' character

dm_output:
   and   e                 ; make character a space if zero suppression is on
   jp    printa



; print decimal representation of value in hl, leading spaces and zeros suppressed
;
decimal16:
   ld    e,0               ; leading 0 suppression flag
   ld    bc,-10000
   call  dm16_digit
   ld    bc,-1000
   call  dm16_digit
   ld    bc,-100
   call  dm16_digit
   ld    c,-10
   call  dm16_digit
   ld    c,-1
   ld    e,$ff             ; force zero suppression off

dm16_digit:
   ld    a,$1c-1           ; '0'-1

dm16_digit2:
   inc   a
   add   hl,bc
   jr    c,dm16_digit2
   sbc   hl,bc

   cp    $1c               ; test for a zero
   jr    nz,dm16_output

   and   e                 ; return early if result is 0
   ret   z

dm16_output:
   ld    e,$ff             ; zero suppression off when we encounter 1st non-'0' character
   call  printa
   ret


; show the hex value of last-k on screen
;
keyshow:
   ld    bc,$001c
   call  pr_pos

   set   7,(iy+PRINTMOD)
   bit   0,(iy+DBFLAG)
   jr    nz,ks_show

   xor   a
   call  printa
   call  printa
   call  printa
   call  printa
   jr    ks_out

ks_show:
   ld    hl,(LAST_K)
   call  hexout16

ks_out:
   res   7,(iy+PRINTMOD)
   ret


preservescreen:
   push  hl
   push  bc
   push  de
   ld    hl,(SCR_POS)
   ld    (BBDEST),hl
   ld    de,BBDEST+2
   ld    bc,33*3
   ldir
   pop   de
   pop   bc
   pop   hl
   ret

unbox:
   push  hl
   push  bc
   push  de
   ld    hl,BBDEST+2
   ld    de,(BBDEST)
   ld    bc,33*3
   ldir
   pop   de
   pop   bc
   pop   hl
   ret


bottombox:
   ld    bc,$1500
box:
   call  pr_pos
   call  preservescreen
   ld    a,7
   call  printa
   ld    a,3
   ld    b,30
   call  printna
   ld    a,132
   call  printa
   ld    a,5
   call  printa
   ld    a,0
   ld    b,30
   call  printna
   ld    a,128+5
   call  printa
   ld    a,128+2
   call  printa
   ld    a,128+3
   ld    b,30
   call  printna
   ld    a,128+1
   jp    printa




smalldelay:
   ld    a,0
sd_loop:
   dec   a
   jr    nz,sd_loop
   ret




titlescreen:
   ld    bc,$0803
   call  pr_pos
   ld    hl,titlestr+3
   call  printstring
   ld    bc,$0c05
   call  pr_pos
   ld    hl,intro1
   jp    printstring





helpscreen:
   ld    hl,titlestr
   ld    bc,$0100

hs_loop:
   call  centrestring
   inc   hl                   ; skip string terminator
   inc   b

   bit   6,(hl)               ; does a NL/DONE follow?
   jr    z,hs_loop

   bit   0,(hl)               ; $77 = done
   ret   nz

   inc   b                    ; $76 = extra newline
   inc   hl
   jr    hs_loop



geterror:
   ld    hl,errorstrings
   push  hl
   sla   a
   call  stkAdd8
   pop   hl
   ld    (ge_addr+1),hl
   nop
   nop
ge_addr:
   ld    hl,(0)
   ret




#include "math.asm"
#include "input.asm"
#include "keyhand.asm"

; ===== Text Viewer patch (kmurta) =====================================
#include "tviewer.asm"
; ===== Set Joy patch (kmurta) =========================================
#include "setjoy.asm"
; ===== BMP viewer patch =====================================
#include "bmpview.asm"
; ======================================================================

#include "zxpand.asm"

; ---------------------------------------------------------- ;
; DATA SECTION . DATA SECTION .  DATA SECTION . DATA SECTION ;
; ---------------------------------------------------------- ;

SCR_POS:
   dw    0

; key states - should be in order up, down, left, right, enter
;
joycodes:
   dw    $efef, $dfef, $dff7, $f7ef, $fdbf

keyStates:
   .dw   $efef             ; selection up [7]
   .db   0,0
   .dw   kType3
   .dw   keySelectionUp

   .dw   $dfef             ; selection down [6]
   .db   0,0
   .dw   kType3
   .dw   keySelectionDown

   .dw   $dff7             ; left pane [shift-5]
   .db   0,0
   .dw   kType1   ; press/release
   .dw   keyLeftPane

   .dw   $f7ef             ; right pane [shift-8]
   .db   0,0
   .dw   kType1
   .dw   keyRightPane

   .dw   $fdbf             ; enter dir\execute [enter]
   .db   0,0
   .dw   kType1
   .dw   keyEnterExecute

   .dw   $fcbf             ; open dir in other pane [shift-enter]
   .db   0,0
   .dw   kType1
   .dw   keyOpenDirInOther

   .dw   $f6fe             ; load;x [shift-x]
   .db   0,0
   .dw   kType1
   .dw   keyXecute

   .dw   $fcfd             ; load STOP [shift-a]
   .db   0,0
   .dw   kType1
   .dw   keyLoadSTOP

   .dw   $f6fd             ; delete [shift-d]
   .db   0,0
   .dw   kType1
   .dw   keyDelete

   .dw   $eefe             ; copy [shift-c]
   .db   0,0
   .dw   kType1
   .dw   keyCopy

   .dw   $f67f             ; move [shift-m]
   .db   0,0
   .dw   kType1
   .dw   keyMove

   .dw   $eefb             ; rename [shift-r]
   .db   0,0
   .dw   kType1
   .dw   keyRename

   .dw   $f6bf             ; create directory [shift-k]
   .db   0,0
   .dw   kType1
   .dw   keyCreatedir

   .dw   $fb7f             ; up a level [.]
   .db   0,0
   .dw   kType1
   .dw   keyUpALevel

   .dw   $deef             ; down fast [shift-6]
   .db   0,0
   .dw   kType1
   .dw   keyDownFast

   .dw   $eeef             ; up fast [shift-7]
   .db   0,0
   .dw   kType1
   .dw   keyUpFast

   .dw   $debf             ; help [shift-h]
   .db   0,0
   .dw   kType1
   .dw   keyHelp

   .dw   $fcfb             ; quit [shift-q]
   .db   0,0
   .dw   kType1
   .dw   keyQuit

   .db   0                  ; no useful key codes have an lsb of zero

   .dw   $fcf7             ; enable key display [shift-1]
   .db   0,0
   .dw   kType1
   .dw   keyDebugToggle

   .db   0                  ; no useful key codes have an lsb of zero



; info about the current highlighted item
;
FNBUF:
   ds    16
FLEN:
   dw    0


errorstrings:
   dw    error00, error01, error02, error03, error04
   dw    error05, error06, error07, error08, error09
   dw    error10, error11, error12, error13, error14
   dw    error15
   ; BMP errors
   dw	 error16, error17, error18, error19, error20
   ; unused errors
   dw	 error21, error22, error23, error24, error25
   dw	 error26, error27, error28, error29, error30
   dw    error31


; all strings which need converting go here.
; no other data please, just the strings
;
stringsforconversion:

entriesstr:
   dt    " ITEMS "
   db    $ff

bytesstr:
   dt    " BYTES "
   db    $ff

sourcestr:
   dt    ";32768"
   db    $ff

deststr:
   dt    ";32768,"
   db    $ff

titlestr:
;         --------========--------========
   dt    "     ZXPAND-COMMANDER  2.00     "
   db    $ff
   db    $0d
   dt    "CURSOR KEYS - MOVE SELECTION"
   db    $ff
   dt    "SHIFT UP/DN - JUMP UP/DN"
   db    $ff
   db    $0d
   dt    "ENTER - OPEN SUBDIR OR EXEC PROG"
   db    $ff
   dt    "SHIFT ENTER - OPEN SUBDIR >OTHER"
   db    $ff
   dt    ". - GO UP A DIR LEVEL"
   db    $ff
   db    $0d
   dt    "SHIFT C - COPY FILE >OTHER"
   db    $ff
   dt    "SHIFT M - MOVE FILE >OTHER"
   db    $ff
   dt    "SHIFT D - DELETE FILE"
   db    $ff
   dt    "SHIFT X - EXEC PROG WITH ;X FLAG"
   db    $ff
   dt    "SHIFT A - LOAD AND STOP (+)"
   db    $ff
   db    $0d
   dt    "SHIFT R - RENAME FILE"
   db    $ff
   dt    "SHIFT K - KREATE A SUBDIR"
   db    $ff
   dt    "SHIFT-SPACE CANCELS TEXT INPUT"
   db    $ff
   db    $0d
   dt    "SHIFT Q - QUIT"
   db    $ff
   db    $0d
   dt    "PRESS A KEY"
   db    $ff
   db    $1b

error00:
   dt    "OK"
   db    $ff
error01:
   dt    "DISK ERROR"
   db    $ff
error02:
   dt    "INTERNAL ERROR"
   db    $ff
error03:
   dt    "DEVICE NOT READY"
   db    $ff
error04:
   dt    "NO FILE"
   db    $ff
error05:
   dt    "NO PATH"
   db    $ff
error06:
   dt    "INVALID NAME"
   db    $ff
error07:
   dt    "ACCESS DENIED"
   db    $ff
error08:
   dt    "FILE EXISTS"
   db    $ff
error09:
   dt    "INVALID OBJECT"
   db    $ff
error10:
   dt    "WRITE PROTECTED"
   db    $ff
error11
   dt    "INVALID DRIVE"
   db    $ff
error12:
   dt    "NOT ENABLED"
   db    $ff
error13:
   dt    "NO FILESYSTEM"
   db    $ff
error14:
   dt    "MKFS ABORTED"
   db    $ff
error15:
   dt    "TIMEOUT"
   db    $ff

; BMP errors
error16:
	dt	"NO BMP FILE" 
	db	$ff
error17:
	dt	"UNSUPPORTED BITMAP TYPE"
	db	$ff
error18:
	dt	"UNSUPPORTED BMP COMPRESSION"
	db	$ff
error19:
	dt	"UNSUPPORTED BMP WIDTH"
	db	$ff
error20:
	dt	"UNSUPPORTED BMP HEIGTH"
	db	$ff
; unused ERRORS from 21 to 31
error21:
error22:
error23:
error24:
error25:
error26:
error27:
error28:
error29:
error30:
error31:
	dt	"UNEXPECTED ERROR"
	db	$ff

renamestr:
   dt    "RENAME"
   db    $ff

mkdirstr:
   dt    "CREATE DIRECTORY"
   db    $ff

intro1:
   dt    "PRESS SHIFT-H FOR HELP"
   db    $ff

terminator:
   db    $ff
;
; terminate conversion list

; ------------------------------------------------------------

convtable:
   db $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0f, $76, $0F, $0F,
   db $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $77, $0F, $0F, $0F, $0F,
   db $00, $0F, $0B, $0F, $0D, $0F, $0F, $0F, $10, $11, $17, $15, $1A, $16, $1B, $18,
   db $1C, $1D, $1E, $1F, $20, $21, $22, $23, $24, $25, $0E, $19, $13, $14, $12, $0F,
   db $0F, $26, $27, $28, $29, $2A, $2B, $2C, $2D, $2E, $2F, $30, $31, $32, $33, $34,
   db $35, $36, $37, $38, $39, $3A, $3B, $3C, $3D, $3E, $3F, $0F, $18, $0F, $0F, $0F,
   db $0F, $26, $27, $28, $29, $2A, $2B, $2C, $2D, $2E, $2F, $30, $31, $32, $33, $34,
   db $35, $36, $37, $38, $39, $3A, $3B, $3C, $3D, $3E, $3F, $0F, $0F, $0F, $0F, $0F
   

   ; pad to the next 2k boundary
   ;;org ((*+2047) / 2048) * 2048   ; for TASM
	.align 2048                      ; for BRASS

fontdata:
   #include "font.asm"

   
   ; end of line for BASIC
   db $76

line1:
   .byte 0,1                     ; line number
   .word xxdfile-$-2             ; line length

   .byte $f9,$d4,$c5             ; RAND USR VAL
   .byte $b,$1d,$22,$21,$1d,$20,$b  ; "16514"
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
