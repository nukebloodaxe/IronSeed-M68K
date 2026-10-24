; is.s - IS.PRG, the launcher (port of is.pas). Runs the game's programs in turn with
; Pexec, passing the same switches as the original, until one asks to quit (code 4/0).
;   5 (start)     INTRO.PRG /showseed
;   3             INTRO.PRG /showseed /done      (back to the title)
;   1             CREWGEN.PRG /makeseed          (new game)
;   2             MAIN.PRG /playseed             (continue)
;   49..56        MAIN.PRG /playseed <slot>      (load a saved game)
; Programs not ported yet are skipped back to the title.
	include	"hw.i"
	include	"kmac.i"

	section	text
start:	move.l	4(sp),a0		; keep only basepage + program + a small stack
	move.l	$0c(a0),d0
	add.l	$14(a0),d0
	add.l	$1c(a0),d0
	add.l	#$100,d0
	lea	stack_top,sp
	move.l	d0,-(sp)
	move.l	a0,-(sp)
	clr.w	-(sp)
	GEMDOS	$4a,12			; Mshrink
	pea	banner
	GEMDOS	GD_CCONWS,6
	moveq	#5,d7			; code
.loop:	cmp.w	#5,d7
	bne.s	.c3
	lea	prg_intro,a0
	lea	tail_show,a1
	bra	.run
.c3:	cmp.w	#3,d7
	bne.s	.c1
.title:	lea	prg_intro,a0
	lea	tail_done,a1
	bra.s	.run
.c1:	cmp.w	#1,d7
	bne.s	.c2
	lea	prg_crewgen,a0
	lea	tail_make,a1
	bra.s	.try
.c2:	cmp.w	#2,d7
	beq.s	.main
	cmp.w	#49,d7
	blo	.bad
	cmp.w	#56,d7
	bhi	.bad
	move.b	d7,tail_slot+12		; "/playseed  n"
	lea	prg_main,a0
	lea	tail_slot,a1
	bra.s	.try
.main:	lea	prg_main,a0
	lea	tail_play,a1
.try:	movem.l	a0-a1,-(sp)		; not ported yet? -> back to the title
	clr.w	-(sp)
	move.l	a0,-(sp)
	GEMDOS	GD_FOPEN,8
	movem.l	(sp)+,a0-a1
	tst.l	d0
	bmi.s	.missing
	movem.l	a0-a1,-(sp)		; (GEMDOS may trash a0-a2: the tail too - reglint)
	move.w	d0,-(sp)
	GEMDOS	GD_FCLOSE,4
	movem.l	(sp)+,a0-a1
.run:	clr.l	-(sp)			; Pexec(0, name, tail, env = parent's)
	move.l	a1,-(sp)
	move.l	a0,-(sp)
	clr.w	-(sp)
	GEMDOS	$4b,16
	tst.l	d0
	bmi.s	.err
	move.w	d0,d7
	beq.s	.quit			; 0 or 4 end the game
	cmp.w	#4,d7
	beq.s	.quit
	bra	.loop
.missing:
	pea	msg_missing
	GEMDOS	GD_CCONWS,6
	bra	.title
.bad:	pea	msg_bad
	GEMDOS	GD_CCONWS,6
.quit:	clr.w	-(sp)
	trap	#1
.err:	pea	msg_err
	GEMDOS	GD_CCONWS,6
	move.w	#2,-(sp)		; wait for a key so the message can be read
	BIOS	BI_BCONIN,4
	bra.s	.quit

	section	data
banner:		dc.b	27,"E","IronSeed v1.30.0001 / Atari STE port",13,10
		dc.b	"ironseed      Copyright (C) 1994  Channel 7",13,10
		dc.b	"ironseed_fpc  Copyright (C) 2013  y-salnikov",13,10
		dc.b	"ironseed_fpc  Copyright (C) 2016  Nuke Bloodaxe",13,10
		dc.b	"ironseed_fpc  Copyright (C) 2020  Matija Nalis",13,10,0
msg_missing:	dc.b	"That part of the game is not ported yet - back to the title.",13,10,0
msg_bad:	dc.b	"Fatal Run Error!",13,10,0
msg_err:	dc.b	"Executable not found or not enough memory. Press a key.",13,10,0
prg_intro:	dc.b	"INTRO.PRG",0
prg_crewgen:	dc.b	"CREWGEN.PRG",0
prg_main:	dc.b	"MAIN.PRG",0
; command tails: length byte, text, 0
tail_show:	dc.b	10,"/showseed ",0
tail_done:	dc.b	16,"/showseed /done ",0
tail_make:	dc.b	10,"/makeseed ",0
tail_play:	dc.b	10,"/playseed ",0
tail_slot:	dc.b	12,"/playseed  1",0
	even

	section	bss
		ds.b	4096
stack_top:
