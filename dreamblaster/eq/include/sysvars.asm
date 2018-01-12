
ERR_NR		.equ	$4000
FLAGS		.equ	$4001
ERR_SP		.equ	$4002
RAMTOP		.equ	$4004
MODE		.equ	$4006
PPC			.equ	$4007

;= System variables as saved ============================================

VERSN:		.byte	0
E_PPC:		.word	0
D_FILE:		.word	exdfile
DF_CC:		.word	exdfile+1
VARS:		.word	var
DEST:		.word	0
E_LINE:		.word	var+1
CH_ADD:		.word	LAST-1
X_PTR:		.word	0
STKBOT:		.word	LAST
STKEND:		.word	LAST
BERG:		.byte	0
MEM:		.word	MEMBOT
			.byte	0
DF_SZ:		.byte	2
S_TOP:		.word	1
LAST_K:		.byte	$FF,$FF,$FF
MARGIN:		.byte	55
NXTLIN:		.word	line1
OLDPPC:		.word	0
FLAGX:		.byte	0
STRLEN:		.word	0
T_ADDR:		.word	$0C8D
SEED:		.word	0
FRAMES:		.word	$FFFF
COORDS:		.byte	0,0
PR_CC:		.byte	$BC
S_POSN:		.byte	33,24
CDFLAG:		.byte	01000000B
PRTBUF:		.block	33			; print buffer - iow scratch ram for us :)
MEMBOT:		.block	30			; calculator's scratch
SPARE:		.block	2
