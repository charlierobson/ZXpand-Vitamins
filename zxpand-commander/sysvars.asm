
ERR_NR		.equ	$4000
FLAGS		.equ	$4001
ERR_SP		.equ	$4002
RAMTOP		.equ	$4004
MODE		.equ	$4006
PPC			.equ	$4007

;= System variables as saved ============================================

VERSN:		db	0
E_PPC:		dw	0
D_FILE:		dw	xxdfile
DF_CC:		dw	xxdfile+1
VARS:		dw	var
DEST:		dw	0
E_LINE:		dw	var+1
CH_ADD:		dw	LAST-1
X_PTR:		dw	0
STKBOT:		dw	LAST
STKEND:		dw	LAST
BERG:		   db	0
MEM:		   dw	MEMBOT
			   db	0
DF_SZ:		db	2
S_TOP:		dw	1
LAST_K:		db	$FF,$FF,$FF
MARGIN:		db	55
NXTLIN:		dw	line1
OLDPPC:		dw	0
FLAGX:		db	0
STRLEN:		dw	0
T_ADDR:		dw	$0C8D
SEED:		dw	0
FRAMES:		dw	$FFFF
COORDS:		db	0,0
PR_CC:		db	$BC
S_POSN:		db	33,24
CDFLAG:		db	01000000B
PRTBUF:		ds	33			; print buffer - iow scratch ram for us :)
MEMBOT:		ds	30			; calculator's scratch
SPARE:		ds	2
