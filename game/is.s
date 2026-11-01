; is.s - IS.PRG, the launcher (port of is.pas). Runs the game's programs in turn with
; Pexec, passing the same switches as the original, until one asks to quit (code 4/0).
;   5 (start)     INTRO.PRG /showseed
;   3             INTRO.PRG /showseed /done      (back to the title)
;   1             CREWGEN.PRG /makeseed          (new game)
;   2             MAIN.PRG /playseed             (continue)
;   49..56        MAIN.PRG /playseed <slot>      (load a saved game)
; Programs not ported yet are skipped back to the title.
; Phase 8, the floppy version (tools/mkfloppy.py): started from drive A/B with \ISDISK.TAB in the
; root (from AUTO\ too: the root becomes the current folder), a program not on the disk in the
; drive brings up a text prompt for its disk (the table), and hdv_mediach tells TOS after it
; that the disk changed. Inside the programs the kernel (flp.s) does the same on the screen.
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
	bsr	fl_init
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
	bra	.run
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
.try:	movem.l	a0-a1,-(sp)		; (floppies: its disk in the drive)
	bsr	fl_need
	movem.l	(sp)+,a0-a1
	movem.l	a0-a1,-(sp)		; not ported yet? -> back to the title
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
.run:	movem.l	a0-a1,-(sp)
	bsr	fl_need
	movem.l	(sp)+,a0-a1
	clr.l	-(sp)			; Pexec(0, name, tail, env = parent's)
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
.quit:	bsr	fl_exit
	clr.w	-(sp)
	trap	#1
.err:	pea	msg_err
	GEMDOS	GD_CCONWS,6
	move.w	#2,-(sp)		; wait for a key so the message can be read
	BIOS	BI_BCONIN,4
	bra.s	.quit

; ---------------------------------------------------------------- the floppies
fl_init:
	GEMDOS	$19,2			; Dgetdrv
	cmp.w	#2,d0
	bcc	.x
	move.w	d0,fl_drv
	add.b	#'A',d0
	move.b	d0,fl_m_drv
	move.b	#92,fl_buf		; Dgetpath(buf+1, 0), then the root (from AUTO\ or a folder)
	clr.w	-(sp)
	pea	fl_buf+1
	GEMDOS	$47,8
	pea	fl_root
	GEMDOS	$3b,6			; Dsetpath
	clr.w	-(sp)
	pea	fl_fn_tab
	GEMDOS	GD_FOPEN,8
	move.l	d0,d3
	bpl.s	.t
	lea	fl_buf,a0		; not the floppies: the folder back
	tst.b	1(a0)
	beq.s	.x
	cmp.b	#92,1(a0)
	bne.s	.sp
	addq.l	#1,a0
.sp:	move.l	a0,-(sp)
	GEMDOS	$3b,6
	bra.s	.x
.t:
	pea	fl_tab
	move.l	#FL_TABMAX,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FREAD,12
	move.l	d0,d4
	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
	cmp.l	#10,d4
	blt.s	.x
	cmp.l	#'ISD1',fl_tab
	bne.s	.x
	move.w	#1,fl_on
	pea	fl_hook			; hdv_mediach
	XBIOS	38,6
.x:	rts

fl_exit:
	tst.w	fl_on
	beq.s	.x
	clr.w	fl_on
	pea	fl_unhook
	XBIOS	38,6
.x:	rts

fl_hook:
	move.l	$47e.w,fl_oldmc
	move.l	#fl_mediach,$47e.w
	rts
fl_unhook:
	move.l	fl_oldmc,$47e.w
	rts
fl_mediach:				; "changed" once after a prompt
	move.w	4(sp),d0
	cmp.w	fl_drv,d0
	bne.s	.o
	tst.w	fl_force
	beq.s	.o
	clr.w	fl_force
	moveq	#2,d0
	rts
.o:	move.l	fl_oldmc,-(sp)
	rts

; a0 = program name: until it opens, ask for the disk the table puts it on.
fl_need:
	tst.w	fl_on
	beq	.x
	movem.l	d3/a0-a1/a3,-(sp)
	move.l	a0,a3
.l:	clr.w	-(sp)
	move.l	a3,-(sp)
	GEMDOS	GD_FOPEN,8
	tst.l	d0
	bmi.s	.ask
	move.w	d0,-(sp)
	GEMDOS	GD_FCLOSE,4
	bra	.ok
.ask:	lea	fl_tab+10,a0		; its disk
	move.w	fl_tab+6,d3
	bra.s	.ne
.e:	lea	4(a0),a1
	move.l	a3,a2
.cm:	move.b	(a2)+,d0
	cmp.b	(a1)+,d0
	bne.s	.nx
	tst.b	d0
	bne.s	.cm
	move.w	(a0),d1			; the first of its disks
	moveq	#'0',d0
.f:	addq.b	#1,d0
	lsr.w	#1,d1
	bcc.s	.f
	move.b	d0,fl_m_dn
	ifd	FLPNF			; (test builds: tell the Hatari driver)
	move.b	d0,fl_nfmsg+11
	pea	fl_nfid
	bsr	fl_nf_id
	addq.l	#4,sp
	pea	fl_nfmsg
	move.l	d0,-(sp)
	bsr	fl_nf_call
	addq.l	#8,sp
	endc
	pea	fl_m_ins
	GEMDOS	GD_CCONWS,6
	move.w	#2,-(sp)
	BIOS	BI_BCONIN,4
	move.w	#1,fl_force
	bra	.l
.nx:	lea	4(a0),a1		; the next entry
.sk:	tst.b	(a1)+
	bne.s	.sk
	move.l	a1,d0
	addq.l	#1,d0
	and.w	#$fffe,d0
	move.l	d0,a0
.ne:	dbf	d3,.e
.ok:	movem.l	(sp)+,d3/a0-a1/a3	; (not in the table: the caller finds out)
.x:	rts

	ifd	FLPNF
fl_nf_id:	dc.w	$7300
	rts
fl_nf_call:	dc.w	$7301
	rts
	endc

	section	data
fl_fn_tab:	dc.b	92,"ISDISK.TAB",0
fl_root:	dc.b	92,0
	ifd	FLPNF
fl_nfid:	dc.b	"NF_STDERR",0
fl_nfmsg:	dc.b	"FLP-PROMPT x",10,0
	endc
fl_m_ins:	dc.b	13,10,"Please insert Iron Seed disk "
fl_m_dn:	dc.b	"1",13,10,"in drive "
fl_m_drv:	dc.b	"A and press a key.",13,10,0
	even
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
FL_TABMAX	equ	8192
fl_tab:		ds.b	FL_TABMAX
fl_buf:		ds.b	128
fl_oldmc:	ds.l	1
fl_on:		ds.w	1
fl_drv:		ds.w	1
fl_force:	ds.w	1
		ds.b	4096
stack_top:
