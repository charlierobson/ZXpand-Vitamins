; -----------------------------------------------------------------------------
; -KEYBOARD-HANDLING-----------------------------------------------------------
; -----------------------------------------------------------------------------


; on entry BC has last-k value in it. if there is a joystick movement,
; bc will be overwritten with the key code value associated with the direction
;
joytolastk:
   call  api_rdjoy
   ld    bc,(LAST_K)

   or    7
   cp    $ff
   ret   z                 ; if no bits clear return immediately with last_k in BC

   ld    hl,joycodes       ; begin scanning
   ld    e,5

jt_scan:
   bit   7,a               ; zero bit indicates a press
   jr    nz,jt_nocode

   ld    c,(hl)            ; get the key code and return with it
   inc   hl
   ld    b,(hl)
   ret

jt_nocode:
   inc   hl                ; test next bit
   inc   hl
   sla   a
   dec   e
   jr    nz,jt_scan

   ; shouldn't reach here ..!

   ret



; perform the keyboard handling. iterate over an array of structures defining a key mapping.
; each structure has a last-k value, state, counter and pointers to a type handler and 'on press' function.
;
keyhandler:
   call    joytolastk
   ld      de,keyStates

   ; in short:
   ; compare LAST_K to each state's id. If they don't match,
   ; set that key's state to 0, else call the type handler.

kh_next:
   push  de                   ; points to data block

   ld    (kh_mod+1),de        ; [SMC] get key value from data block into de
kh_mod:
   ld    hl,(0)

   and   a                    ; last_k == required key val?
   sbc   hl,bc

   inc   de
   inc   de
   push  de                   ; point hl to the data part of the key code
   pop   hl

   jr    nz,kh_clearstate     ; check the result of the key data comparison - push/pop/inc don't affect flags

   inc   hl                   ; last-k matches
   inc   hl
   push  hl
   call  kh_vectorcall        ; call the updater, c will be set if we need to call the action function
   pop   hl
   inc   hl
   inc   hl
   call  c,kh_vectorcall      ; call the action/on-press function
   pop   de
   ret                        ; won't be any more matches

kh_clearstate:
   ; last_k doesn't match this key's required value, so set state and counter to 0.
   xor   a
   ld    (hl),a
   inc   hl
   ld    (hl),a

kh_advance:
   ld    a,8                  ; there are faster ways to do this but this call changes no registers
   call  stkAdd8
   pop   de

   ld    a,(de)               ; reached the end of the list? no key code has an lsb on 0.
   and   a
   jr    nz,kh_next

   ret

; take address at (hl) and _jump_ there; preserving hl
;
kh_vectorcall:
   push  hl                   ; store hl on the stack, it will be replaced later
   ld    a,(hl)               ; get the jump address into hl
   inc   hl
   ld    h,(hl)
   ld    l,a
   ex    (sp),hl              ; now put the jump address on the stack and recover the original hl
   ret                        ; then jump to the required address




; -----------------------------------------------------------------------------
; -KEY-TYPE-HANDLERS-----------------------------------------------------------
; -----------------------------------------------------------------------------

kType1:
   ; only call action when 1st pressed / one-shot
   ;
   ld    a,(de)
   and   a
   ret   nz                   ; return with carry clear if state != 1

   inc   a                    ; set state to 1 and set carry
   ld    (de),a
   ccf
   ret



kType2:
   ; simple fixed rate auto-repeat
   ;
   ld    a,(de)               ; get state
   ld    l,a                  ; preserve state for later comparison
   inc   a                    ; state = (state + 1) & 15.
   and   15
   ld    (de),a

   ld    a,l                  ; if state was 0 when we appeared here then trigger the call to action
   and   a                    ; clears carry
   ret   nz

   ccf                        ; fire a keypress when state == 0
   ret



kType3:
   ; initial action, then delay then auto repeat
   ;
   ld    (kt3_pt1+1),de
   ld    (kt3_done+1),de

kt3_pt1:
   ld    hl,(0)               ; [SMC]  get state into L and counter into H

   ld    a,h                  ; H will be 0 only on the 1st entry
   and   a
   jr    nz,kt3_not1sttime

   ld    l,-25                ; induce an initial delay
   ld    h,1
   ccf
   jr    kt3_done

kt3_not1sttime:
   inc   l
   ld    a,l
   cp    25
   jr    nz,kt3_done          ; carry will be clear at this point

   xor   a
   ld    l,a
   ccf

kt3_done:
   ld    (0),hl               ; [SMC] store state and counter
   ret





; -----------------------------------------------------------------------------
; -KEY-ACTION-HANDLERS---------------------------------------------------------
; -----------------------------------------------------------------------------



keyDebugToggle:
   bit   0,(iy+DBFLAG)
   jr    z,ksc_set

   res   0,(iy+DBFLAG)
   ret

ksc_set:
   set   0,(iy+DBFLAG)
   ret


;
;
;


keyOpenDirInOther:
   bit   4,(iy+FFLAGS)        ; is current highlighted item a folder? return if not.
   ret   z

   ld    a,(FNBUF)
   cp    $1b                  ; '.'
   jr    nz,kse_notdot

   ld    a,(FNBUF+1)
   cp    $ff
   ret   z                    ; it's <.> so return

kse_notdot:
   call  acceptpanechanges    ; copy the working pane back to the source

   ; work out which pane to copy. we won't copy all of it, only the screen offset and data ptr.
   ; once we have a pane info structure containing the other pane's basic info loaddir will
   ; fill in the rest with the updated file path.

   ld    a,(iy+CURPANE)
   xor   1
   ld    (iy+CURPANE),a

   call  getpaneptr           ; get pointer to pane source data

   ld    de,pnDATAPTR
   add   hl,de
   ld    de,DATAPTR           ; copy data to working pane
   ld    bc,4
   ldir

   call  updateFilePath

   call  gofast                ; set-fast

   call  loaddir
   call  acceptpanechanges
   call  drawlist

   ; swap back

   ld    a,(iy+CURPANE)
   xor   1
   ld    (iy+CURPANE),a
   push  af
   call  z,pane1
   pop   af
   call  nz,pane2

   jp    goslow                ; slow


;
;
;

keyUpFast:
   call  lolightitem

   ld    hl,(SELECTION)       ; if selection is already 0 then try to move list up
   ld    a,h
   or    l
   jr    z,kuf_goup

   ld    hl,0                 ; else set selection to 0
   ld    (SELECTION),hl
   jr    kdf_cleanup

   ;

kuf_goup:
   ld    hl,(TOPENTRY)        ; if topentry >= 19 then set topentry = topentry -19
   ld    de,NUMINLIST
   and   a
   sbc   hl,de
   jr    nc,kuf_ok

   ld    hl,0                 ; else set topentry = 0

kuf_ok:
   ld    (TOPENTRY),hl
   jr    kdf_cleanup




keyDownFast:
   call  lolightitem

   ld    hl,MAXLISTIDX        ; see if selection is already at bottom of screen
   ld    de,(SELECTION)       ; if so then there's a good chance there are more items
   call  areequal             ; if there are fewer than maxitems in list we'll just move selection
   jr    z,kdf_godown

   ld    de,(NENTRIES)        ; set selection to last index on screen or last item, whichever is smaller
   dec   de
   call  smallest
   ld    (SELECTION),hl
   jr    kdf_cleanup


kdf_godown:
   ; if there are more than 19 items left to show then add 19 to topentry
   ; if not set topentry to nentries - 19

   ld    hl,(TOPENTRY)
   ld    de,NUMINLIST
   add   hl,de                ; hl = top + n
   push  hl

   ld    hl,(NENTRIES)
   sbc   hl,de                ; hl = nitems - n
   pop   de                   ; de = top + n
   call  smallest
   ld    (TOPENTRY),hl

kdf_cleanup:
   call  acceptpanechanges
   call  parsefileinfo
   call  drawlist
   call  highlightitem
   call  drawdirectory
   jp    drawfile


;
;
;

keyUpALevel:
   ld    a,(DIRNAME+1)        ; cheap test to see if we're at the root
   cp    $ff
   ret   z

   ld    a,$1B                ; if not at root then fake the fnbuf to indicate 'level up'
   ld    (FNBUF),a
   ld    (FNBUF+1),a
   ld    a,$ff
   ld    (FNBUF+2),a
   jp    ke_folder            ; and continue forward to the 'concatenate path and change dir' code


;
;
;

keyXecute:
   set   0,(iy+XLOADFLAG)     ; requesting an ';X' on load
   jr    ke_extest


;
;
;

keyLoadSTOP:
   bit   0,(iy+ZXPTYPE)       ; return if classic
   ret   z

   set   1,(iy+XLOADFLAG)     ; requesting a ' STOP ' on load
   jr    ke_extest


;
;
;

findFileType:
   ld    hl,FNBUF
   ld    a,$1B                ; '.'
   call  findchar
   ret   nz                   ; no dot? no filetype!

   inc   hl
   
   ld    c,1                  ; file type 1, TXT
   ld    de,TXTFILE
   call  cmp3
   ret   z

   ld    c,2
   ld    de,HRGFILE
   call  cmp3
   ret   z

   ld    c,3
   ld    de,PFILE
   call  cmp3
   ret z

   ld    c,4
   ld    de,BMPFILE
   call  cmp3
   ret

cmp3:
   push  hl
   ld    b,4
c3_next:
   ld    a,(de)
   cp    (hl)
   jr    nz,c3_done
   cp    $ff
   jr    z,c3_done
   inc   hl
   inc   de
   djnz  c3_next
c3_done:
   pop   hl
   ret
   
TXTFILE:
   db    $39,$3d,$39,$ff
HRGFILE:
   db    $2d,$37,$2c,$ff
PFILE:
   db    $35,$ff
BMPFILE:
	db	$27,$32,$35,$ff




   
keyEnterExecute:
   bit   4,(iy+FFLAGS)        ; is current highlighted item a folder?
   jr    nz,ke_folder         ; forward if so to show subfolder content

   res   0,(iy+XLOADFLAG)     ; no need for an ';X' on load

ke_extest:
   call	findFileType
   ret   nz                   ; no file type identified

   ld    a,c
   cp    1
   jp    z,verifytxt

   cp	 4
   jp	z,bmpviewer

   cp    2
   ;jp    z,showHRG
   cp    3
   ret   nz

   ; change to the selected directory and execute the selected file

   ld    hl,DIRNAME
   ld    a,$12                ; '>' - change to the selected directory
   call  dircommand

   call  errorhandler
   ret   c

; ===== Set Joy patch (kmurta) =========================================
   call  config_joy
; ======================================================================

   ld    hl,FNBUF             ; copy the selected filename up to filepath1 and set the high bit of the name
   jp    executeprog


ke_folder:
   ld    a,(FNBUF)
   cp    $1b                  ; '.'
   jr    nz,ke_notroot

   ld    a,(FNBUF+1)
   cp    $ff                  ; '.[]' - nothing to do
   ret   z

ke_notroot:
   call  lolightitem

   call  updateFilePath

   call  gofast                ; set-fast

   call  loaddir
   call  acceptpanechanges

   call  drawlist
   call  highlightitem
   call  parsefileinfo
   call  drawdirectory
   call  drawfile

   jp     goslow                ; slow

;
;
;

keyLeftPane:
   bit   0,(iy+CURPANE)       ; nothing to do if already in pane 0
   ret   z

   call  acceptpanechanges
   call  lolightitem
   call  pane1
   call  parsefileinfo
   call  highlightitem
   call  drawdirectory
   jp    drawfile

;
;
;

keyRightPane:
   bit   0,(iy+CURPANE)       ; nothing to do if already in pane 1
   ret   nz

   ld    a,(PANE2DATA+pnDIRNAME)
   and   a
   ret   z                    ; quit if dirname is not yet set

   call  acceptpanechanges
   call  lolightitem
   call  pane2
   call  parsefileinfo
   call  highlightitem
   call  drawdirectory
   jp    drawfile


;
;
;

keyQuit:
   call  $0a2a
   rst   08h
   .db   $ff

;
;
;

keySelectionUp:
   call  lolightitem       ; remove item highlighting

   ld    hl,SELECTION
   call  decINZ            ; move selection cursor up if possible
   jr    nz,su_done

   ld    hl,TOPENTRY
   call  decINZ            ; if cursor was already at top then try to decrement the list top item index
   jr    z,su_done         ; do nothing if it was already 0

   call  drawlist          ; if the top item changed then re-draw the list

su_done:
   call  acceptpanechanges
   call  highlightitem
   call  parsefileinfo
   jp    drawfile

;
;
;

keySelectionDown:
   call  lolightitem

   ld    hl,(SELECTION)       ; if the selection cursor is equal to num items then we can go no further
   ld    de,(NENTRIES)        ; this will happen when num items < 19
   dec   de
   and   a
   sbc   hl,de
   jr    z,sd_done

   ld    hl,(SELECTION)       ; if selection cursor is not at the bottom of the list...
   ld    a,l
   cp    NUMINLIST-1
   jr    z,sd_movelist

   inc   hl                   ;  ...then move it down
   ld    (SELECTION),hl
   jr    sd_done

sd_movelist:
   ld    de,(TOPENTRY)        ; otherwise if topentry + selection < num items, then move the list up.
   add   hl,de
   ld    de,(NENTRIES)
   dec   de
   sbc   hl,de
   jr    z,sd_done

   ld    de,(TOPENTRY)        ; shuffle the list up and re-draw it
   inc   de
   ld    (TOPENTRY),de
   call  drawlist

sd_done:
   call  acceptpanechanges
   call  highlightitem
   call  parsefileinfo
   jp    drawfile




adjustwindow:
   ld    hl,(TOPENTRY)        ; calculate the number of entries off the bottom of the pane display.
   ld    bc,MAXLISTIDX        ; = nentries - (topentry + 19)
   add   hl,bc
   ld    de,(NENTRIES)
   ex    de,hl
   sbc   hl,de                ; carry will be clear from previous addition
   jr    nc,aw_nover
   ld    hl,0                 ; 0 items remaining off-screen
aw_nover:
   ld    a,h
   or    l
   ret   nz                   ; nothing to do if there are items off the bottom of the pane

   ; we now know there's nothing off the bottom

   ld    hl,(TOPENTRY)        ; are there are any items off the top?
   ld    a,h
   or    l
   jr    z,aw_trybot

   ld    hl,TOPENTRY          ; shuffle list down from the top
   jp    decINZ

aw_trybot:
   ; we now know there's nothing above and nothing below.

   ; if the cursor is on the bottom item then move it up else do nothing

   ld    hl,(NENTRIES)
   ld    de,(SELECTION)
   and   a
   sbc   hl,de
   ret   nz

   ld    hl,SELECTION         ; move selection up
   jp    decINZ




keyDelete:
   ld    a,(FNBUF)            ; is current highlighted item a root folder?
   cp    $1b                  ; '.'
   ret   z

   call  lolightitem

   ld    hl,DIRNAME           ; copy the current directory name to FILEPATH1
   ld    de,FILEPATH1
   push  de
   call  createfilepath       ; then add current filename from FNBUF
   dec   hl                   ; hl points to terminator
   set   7,(hl)
   pop   de
   ld    a,1
   call  api_fileop
   call  api_responder
   call  errorhandler         ; do nothing after an error

   call  gofast

   call  reloaddir
   call  acceptpanechanges
   call  adjustwindow
   call  drawlist
   call  highlightitem
   call  parsefileinfo
   call  drawdirectory
   call  drawfile

   jp    goslow

;
;
;


keyCopy:
   ld    a,(iy+FFLAGS)           ; is current highlighted item a folder? return if not.
   and   $10
   ret   nz

   ld    a,(PANE2DATA+pnDIRNAME)
   and   a
   ret   z                    ; if pane 2 hasn't got a directory set then quit

   ; TODO quit if source and dest names are the same?

   ld    hl,$4000             ; source file too big?
   ld    de,(FLEN)
   and   a
   sbc   hl,de
   ret   c

   call  lolightitem

   ; create fqfn with ';32768' tagged on to the end.

   ld    hl,DIRNAME
   ld    de,FILEPATH1
   call  createfilepath       ; hl left pointing at terminator
   ld    de,sourcestr
   ex    de,hl
   call  copystrTHB

   ; create fqfn with ';32768,' tagged on to the end.

   ld    a,(iy+CURPANE)       ; get path from other pane
   xor   1
   call  getpaneptr
   ld    de,pnDIRNAME
   add   hl,de
   ld    de,FILEPATH2
   call  createfilepath       ; filepath2 contains destination pane directory plus filename

   push  hl

   ld    hl,FILEPATH2
   call  fileexists           ; is destination file there?
   jr    nz,kc_continue

   ld    hl,FILEPATH2
   call  filewritable         ; is destination file writable? (doesn't exist/o-mode is non-zero)
   jr    z,kc_continue

   pop   hl
   ld    a,8
   call  errorhandler
   jr    kc_err

kc_continue:
   pop   hl
   ld    de,deststr
   ex    de,hl
   call  copystring           ; left pointing to the $ff byte. replace this with the size
   ld    (SCR_POS),de         ; by 'printing' the value there..!
   ld    hl,(FLEN)
   call  decimal16
   ld    hl,(SCR_POS)
   dec   hl
   set   7,(hl)

   call  $2e7                 ; really fast

   ld    de,FILEPATH1
   xor   a
   call  api_fileop
   call  errorhandler
   jr    c,kc_err

   ld    de,FILEPATH2
   ld    a,$ff
   call  api_fileop
   call  errorhandler
   jr    c,kc_err

   ; reload data for both panes - it's been trashed.

kc_err:
   call  acceptpanechanges

   call  reloadpanes
   call  highlightitem
   call  parsefileinfo
   call  drawdirectory
   call  drawfile

   jp    $207              ; really slow

;
;
;

keyMove:
   bit   4,(iy+FFLAGS)           ; is current highlighted item a folder? return if so.
   ret   nz

   ld    a,(PANE2DATA+pnDIRNAME)
   and   a
   ret   z                    ; if pane 2 hasn't got a directory set then quit

   call  lolightitem

   ; create path 1
   ;
   ld    hl,DIRNAME
   ld    de,FILEPATH1
   call  createfilepath

   ; create path 2
   ;
   ld    a,(iy+CURPANE)    ; get path from other pane
   xor   1
   call  getpaneptr
   ld    de,pnDIRNAME
   add   hl,de
   ld    de,FILEPATH2
   call  createfilepath    ; add target path to string

   call  gofast

   call  rename
   call  errorhandler
   jr    c,km_error

   ld    hl,NENTRIES       ; eeew, but necessary
   call  decINZ
   call  adjustwindow
   call  acceptpanechanges

   call  reloadpanes

km_error:
   call  highlightitem
   call  parsefileinfo
   call  drawdirectory
   call  drawfile

   jp    goslow

;
;
;

keyRename:
   ld    a,(FNBUF)
   cp    $1b                  ; '.'
   ret   z

   ld    (iy+RENFLAGS),0

   call  lolightitem

   ld    hl,DIRNAME
   ld    de,FILEPATH1
   call  createfilepath       ; create fqfn

   ld    hl,FILEPATH1
   ld    de,FILEPATH2
   call  copystring           ; copy the path to the target

   call  bottombox
   ld    bc,$171a
   ld    hl,renamestr
   call  iprintstringat

   ld    bc,$1601             ; edit at SCR_POS
   call  pr_pos
   ld    hl,FILEPATH2
   call  editbuffer
   push  af
   call  unbox
   pop   af
   jr    z,kr_aborted

   ; check to see that the path component is the same for source and dest paths

   ld    hl,FILEPATH1
   ld    de,UPBUF
   push  de
   call  copypath
   ld    hl,FILEPATH2
   ld    de,UPBUF+64
   push  de
   call  copypath
   pop   hl
   pop   de
   call  strcmp
   jr    z,kr_samepaths

   set   0,(iy+RENFLAGS)

kr_samepaths:
   ; see if we're renaming the folder which is open in the other pane

   bit   4,(iy+FFLAGS)           ; is current highlighted item a folder?
   jr    z,kr_checksdone

   call  getotherpanedirname     ; get the dirname of the other pane
   ld    de,FILEPATH1            ; get the folder portion of the source path name
   call  strcmp
   jr    nz,kr_checksdone

   ; hmm, we need to copy the renamed string back to the other pane iff the rename completed OK
   ;
   set   1,(iy+RENFLAGS)

kr_checksdone:
   call  gofast

   call  rename
   call  errorhandler
   jr    c,kr_aborted        ; do nothing if this failed

   bit   1,(iy+RENFLAGS)
   jr    z,kr_checkadjust

   ; we need to update the path in the other pane 

   call  getotherpanedirname
   ld    de,FILEPATH2
   ex    de,hl
   call  copystring

kr_checkadjust:
   bit   0,(iy+RENFLAGS)      ; adjust selection if file changed folders
   jr    z,kr_onlyreload

   ld    hl,NENTRIES          ; eeew, but necessary - need to check for errors though!!
   call  decINZ
   call  adjustwindow
   call  acceptpanechanges    ; this accepts the hacked count; but it will be fixed by the reloadpanes

kr_onlyreload:
   call  reloadpanes

kr_aborted:
   call  highlightitem
   call  parsefileinfo
   call  drawdirectory
   call  drawfile

   jp    goslow

;
;
;

keyCreatedir:
   call  lolightitem

   call  bottombox
   ld    bc,$1710
   ld    hl,mkdirstr
   call  iprintstringat

   ld    bc,$1601             ; edit at SCR_POS
   call  pr_pos

   ld    hl,FNBUF             ; create a directory name
   ld    (hl),$ff
   call  editbuffer
   push  af
   call  unbox
   pop   af
   jr    z,kk_aborted

   ; TODO - refactor to use dircom

   ld    hl,FILEPATH1         ; concatenate the pane's directory and our new directory name
   ld    (hl),$15             ; '+'
   inc   hl
   ld    de,DIRNAME
   ex    de,hl
   call  createfilepath       ; dirname moved to filepath1+1 then has new dir added.

   dec   hl                   ; terminate and send
   set   7,(hl)
   ld    de,FILEPATH1
   call  api_sendstring

   ld    bc,$6007             ; open dir, which will interpret '+' command and create the directory
   ld    a,0
   out   (c),a
   call  api_responder

   call  errorhandler
   jr    c,kk_aborted

   call  reloaddir
   call  acceptpanechanges
   call  drawlist

kk_aborted:
   call  highlightitem
   call  parsefileinfo
   call  drawdirectory
   call  drawfile

   jp    goslow

;
;
;

keyHelp:
   set   7,(iy+PRINTMOD)
   call  cls
   call  helpscreen
   res   7,(iy+PRINTMOD)

khl_wait:
   ld    a,(LAST_K)
   cp    $ff
   jr    nz,khl_wait
   ld    a,(LAST_K+1)
   cp    $ff
   jr    nz,khl_wait

khl_wait1:
   ld    a,(LAST_K)
   cp    $ff
   jr    z,khl_wait1
   ld    a,(LAST_K+1)
   cp    $ff
   jr    z,khl_wait1

   jp   drawscreen
