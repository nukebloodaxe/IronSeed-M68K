; intro.s - INTRO.PRG: port of intro.pas. Started by IS.PRG with "/showseed" or
; "/showseed /done" (straight to the title). Exit codes as the original: 1 new game,
; 2 continue game, 4 quit.
;
; Done (Phase 2a): credits screen, title screen (scrolling cloud under the logo, music,
; menu with mouse and keys, "Introduction" replays the intro).
; Not yet (Phase 2b): the story scenes between the credits and the title (c7logo, Mars,
; planets, charcom, battle, alien screens); the intro jumps from the credits to the title,
; as the original does when a key is pressed.
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"

TSLICE		equ	25		; intro.pas tslice (ms)
VARIANT		equ	64000		; one pre-shifted, doubled cloud
; TITLE.DAT offsets (tools/mktitle.py)
TTL_BANDS	equ	4
TTL_LUTS	equ	TTL_BANDS+2+4*34
TTL_CLOUD	equ	TTL_LUTS+1024
TTL_LOGO	equ	TTL_CLOUD+SCR_SIZE
TTL_LISTS	equ	TTL_LOGO+SCR_SIZE

	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	lea	fn_script,a0
	bsr	scr_open
	lea	txt_font_intro,a0
	bsr	txt_set_font
	bsr	load_cursor
	; command line: "/showseed" required, "/done" skips to the title
	move.l	sys_basepage,a0
	lea	$81(a0),a0
	lea	arg_seed,a1
	bsr	has_arg
	tst.w	d0
	beq	not_from_is
	move.l	sys_basepage,a0
	lea	$81(a0),a0
	lea	arg_done,a1
	bsr	has_arg
	tst.w	d0
	bne.s	.done
	bsr	runintro
	bra.s	.title
.done:	bsr	show_title_logo		; checkparams /done: intro5 + fadein
.title:	bsr	mainloop
	move.w	exitcode,d0
	bra	sys_exit

not_from_is:
	moveq	#4,d0
	bra	sys_exit

; ---------------------------------------------------------------
; runintro (intro.pas 1456): credits, then (scenes: Phase 2b), then intro5
runintro:
	moveq	#0,d0
	bsr	vid_set_fade
	move.l	vid_phys,a0
	bsr	vid_clear
	move.l	vid_log,a0
	bsr	vid_clear
	move.l	vid_phys,a0
	bsr	gfx_set_target
	lea	fn_credpal,a0
	bsr	pal_load
	moveq	#16,d0			; main.pal is simply set, no fade (readygraph)
	bsr	vid_set_fade
	clr.w	GS_BKCOLOR(a6)
	move.w	#22,GS_TCOLOR(a6)
	lea	credits,a2		; (y, x, string) records, y = -1 ends
.cl:	move.w	(a2)+,d1
	bmi.s	.cd
	move.w	(a2)+,d0
	move.l	a2,a0
	moveq	#0,d2
	move.b	(a2),d2
	lea	1(a2,d2.w),a2
	move.l	a2,d2
	addq.l	#1,d2
	and.w	#$fffe,d2
	move.l	d2,a2
	bsr	txt_print
	bra.s	.cl
.cd:	move.w	#3000,d0		; wait(3)
	bsr	tim_delay
	; --- Phase 2b: c7logo, Mars, ... go here ---
	; continue: (intro.pas 1660) stopmod; flush keys; intro5 + fadein
	bsr	mod_stop
.fl:	bsr	kbd_keypressed
	tst.b	d0
	beq.s	.fe
	bsr	kbd_readkey
	bra.s	.fl
.fe:	bra	show_title_logo

; intro5 on black, fade in (fadein: 47 steps of tslice/4)
show_title_logo:
	moveq	#0,d0
	bsr	vid_set_fade
	bsr	title_load
	bcs	fatal
	moveq	#3-1,d3			; the logo into all three screens (its full groups
	lea	vid_scr,a3		; are never redrawn)
.ls:	move.l	ttl_data,a0
	add.l	#TTL_LOGO,a0
	move.l	(a3)+,a1
	bsr	copy_screen
	dbf	d3,.ls
	moveq	#0,d0
	moveq	#16,d1
	move.w	#47*TSLICE/4,d2
	bsr	vid_fade_ms
	bsr	kbd_cursor_show
	rts

; ---------------------------------------------------------------
; mainloop (intro.pas 595): title screen until a menu choice ends it
mainloop:
	clr.w	exitcode
	clr.w	cursor
	clr.w	keymode
	bsr	make_variants		; (the logo is on screen meanwhile, as intro5 was)
	ifnd	NOMUSIC
	lea	fn_intro2,a0
	bsr	mod_load
	endc
	bsr	tim_ticks		; k := random(32000)
	and.l	#$7fff,d0
	cmp.w	#32000,d0
	blo.s	.k
	sub.w	#32000,d0
.k:	move.w	d0,kpos
	bsr	tim_ms
	move.l	d0,lastms
.loop:	; advance the cloud: one pixel per 25 ms (the original's frame time)
	bsr	tim_ms
	move.l	d0,d1
	sub.l	lastms,d1
	divu	#TSLICE,d1
	beq.s	.nomove
	mulu	#TSLICE,d1
	add.l	d1,lastms
	divu	#TSLICE,d1
.dec:	move.w	kpos,d0			; dec(k); if k>64000 then k:=k-64000 (word arithmetic,
	subq.w	#1,d0			; so 0 wraps to 1535 - kept as the original does it)
	cmp.w	#64000,d0
	bls.s	.kok
	sub.w	#64000,d0
.kok:	move.w	d0,kpos
	subq.w	#1,d1
	bne.s	.dec
.nomove:
	addq.l	#1,tframes		; (frame counter, for measurements)
	bsr	compose			; cloud + logo into vid_log
	bsr	drawcursor
	bsr	vid_flip
	bsr	findmouse
	tst.w	exitcode
	bne.s	.end
	bsr	kbd_keypressed
	tst.b	d0
	beq.s	.loop
	move.w	#1,keymode
	bsr	kbd_mouse_xy
	move.w	d0,permx
	move.w	d1,permy
	bsr	kbd_readkey
	tst.b	d0
	bne.s	.nk0
	bsr	kbd_readkey
	bsr	checkkey
	bra.s	.ck
.nk0:	cmp.b	#13,d0
	bne.s	.ck
	bsr	startit
.ck:	tst.w	exitcode
	beq	.loop
.end:	bsr	mod_stop		; stopmod; fading
	moveq	#16,d0
	moveq	#0,d1
	move.w	#47*TSLICE/2,d2
	bsr	vid_fade_ms
	bsr	kbd_cursor_hide
	rts

; startit (intro.pas 523)
startit:
	move.w	cursor,d0
	cmp.w	#1,d0
	bne.s	.s2
	move.w	#1,exitcode
	rts
.s2:	cmp.w	#2,d0
	bne.s	.s3
	bsr	kbd_cursor_hide		; replay the introduction
	bsr	mod_stop
	moveq	#16,d0
	moveq	#0,d1
	move.w	#47*TSLICE/2,d2
	bsr	vid_fade_ms
	bsr	runintro
	lea	fn_intro2,a0
	bsr	mod_load
	clr.w	cursor
	rts
.s3:	cmp.w	#3,d0
	bne.s	.s4
	move.w	#2,exitcode
	rts
.s4:	cmp.w	#4,d0
	bne.s	.x
	move.w	#4,exitcode
.x:	rts

; drawcursor (intro.pas 545): box round the chosen menu entry, colour 207
drawcursor:
	move.l	vid_log,a0
	bsr	gfx_set_target
	move.w	cursor,d0
	beq.s	.x
	bsr	box_of			; d0-d3
	move.b	#207,d4
	bsr	gfx_rect
	bsr	buf_index		; remember it for this buffer (to restore the logo)
	lea	boxes(pc),a0
	move.w	cursor,0(a0,d0.w)
.x:	rts
boxes:	dc.w	0,0,0

; d0.w = cursor 1-4 -> d0-d3 = x1,y1,x2,y2
box_of:
	subq.w	#1,d0
	lsl.w	#3,d0
	lea	box_tab,a0
	movem.w	0(a0,d0.w),d0-d3
	rts
box_tab:
	dc.w	25,148,159,167
	dc.w	43,168,159,187
	dc.w	159,148,283,167
	dc.w	159,168,267,187

; out: d0.w = 0, 2 or 4 for the buffer vid_log is
buf_index:
	moveq	#0,d0
	move.l	vid_log,d1
	cmp.l	vid_scr,d1
	beq.s	.x
	moveq	#2,d0
	cmp.l	vid_scr+4,d1
	beq.s	.x
	moveq	#4,d0
.x:	rts

; findmouse (intro.pas 558)
findmouse:
	bsr	kbd_mouse_status
	move.b	d0,d4			; button
	bsr	kbd_mouse_xy
	cmp.w	permx,d0
	bne.s	.mv
	cmp.w	permy,d1
	beq.s	.nm
.mv:	clr.w	keymode
.nm:	tst.w	keymode
	beq.s	.go
	tst.b	d4
	beq.s	.x
.go:	cmp.w	#148,d1
	blt.s	.other
	cmp.w	#167,d1
	bgt.s	.row2
	moveq	#1,d2			; 148..167
	cmp.w	#25,d0
	blt.s	.none
	cmp.w	#159,d0
	ble.s	.set
	moveq	#3,d2
	cmp.w	#283,d0
	ble.s	.set
	bra.s	.none
.row2:	cmp.w	#187,d1
	bgt.s	.other
	moveq	#2,d2			; 168..187
	cmp.w	#43,d0
	blt.s	.none
	cmp.w	#159,d0
	ble.s	.set
	moveq	#4,d2
	cmp.w	#267,d0
	ble.s	.set
.none:	moveq	#0,d2
.set:	move.w	d2,cursor
	bra.s	.btn
.other:	tst.w	keymode
	bne.s	.btn
	clr.w	cursor
.btn:	tst.b	d4
	beq.s	.x
	tst.w	cursor
	beq.s	.x
	bsr	startit
.x:	rts

; checkkey (intro.pas 581): d0.b = extended scan exitcode
checkkey:
	move.w	cursor,d1
	cmp.b	#72,d0
	bne.s	.dn
	tst.w	d1
	bne.s	.u1
	moveq	#1,d1
	bra.s	.set
.u1:	cmp.w	#1,d1
	bne.s	.u2
	moveq	#4,d1
	bra.s	.set
.u2:	subq.w	#1,d1
	bra.s	.set
.dn:	cmp.b	#80,d0
	bne.s	.lr
	tst.w	d1
	bne.s	.d1
	moveq	#1,d1
	bra.s	.set
.d1:	cmp.w	#4,d1
	bne.s	.d2
	moveq	#1,d1
	bra.s	.set
.d2:	addq.w	#1,d1
	bra.s	.set
.lr:	cmp.b	#75,d0
	beq.s	.h
	cmp.b	#77,d0
	bne.s	.x
.h:	cmp.w	#2,d1
	bls.s	.h2
	subq.w	#2,d1
	bra.s	.set
.h2:	addq.w	#2,d1
.set:	move.w	d1,cursor
.x:	rts

; ---------------------------------------------------------------
; compose: s3 = cloud rotated by kpos, logo over it (mktitle.py lists), into vid_log
compose:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	vid_log,a1
	bsr	buf_index		; first undo the menu box drawn into this buffer last time
	lea	boxes(pc),a0
	move.w	0(a0,d0.w),d1
	beq.s	.nobox
	clr.w	0(a0,d0.w)
	move.w	d1,d0
	bsr	box_of
	bsr	restore_logo
.nobox:	moveq	#0,d0
	move.w	kpos,d0
	move.w	d0,d1
	and.w	#15,d1			; r
	lsr.w	#4,d0			; q
	mulu	#VARIANT,d1
	move.l	variants,a0
	add.l	d1,a0
	add.l	#SCR_SIZE,a0
	lsl.w	#3,d0
	sub.w	d0,a0			; D_r + 32000 - 8q
	move.l	vid_log,a1
	move.l	ttl_data,a2
	add.l	#TTL_LISTS,a2
	move.w	(a2)+,d7		; empty runs: copy cloud groups
	subq.w	#1,d7
	move.l	a6,-(sp)		; (a6 = GS: used as a data register below)
	movem.l	a0-a1,-(sp)		; 4(sp) = destination base, (sp) = source base
.run:	move.w	(a2)+,d0
	move.w	(a2)+,d6
	move.l	(sp),a3
	move.l	4(sp),a4
	add.w	d0,a3
	add.w	d0,a4
	move.l	a2,-(sp)
	sub.w	#6,d6			; blocks of 6 groups = 48 bytes = 12 registers
	bmi.s	.tail
.blk:	movem.l	(a3)+,d0-d5/a0-a2/a5-a6
	movem.l	d0-d5/a0-a2/a5-a6,(a4)
	move.l	(a3)+,(a4)+		; (11 registers + 1 long = 48 bytes)
	lea	44(a4),a4
	sub.w	#6,d6
	bpl.s	.blk
.tail:	addq.w	#6,d6
	beq.s	.rend
	subq.w	#1,d6
.g:	move.l	(a3)+,(a4)+
	move.l	(a3)+,(a4)+
	dbf	d6,.g
.rend:	move.l	(sp)+,a2
	dbf	d7,.run
	movem.l	(sp)+,a0-a1
	move.l	(sp)+,a6
	move.w	(a2)+,d7		; partial groups: keep the cloud where the logo is clear
	subq.w	#1,d7
.part:	move.w	(a2)+,d0
	movem.l	(a2)+,d1-d3
	lea	0(a0,d0.w),a3
	lea	0(a1,d0.w),a4
	move.l	(a3)+,d4
	and.l	d1,d4
	or.l	d2,d4
	move.l	d4,(a4)+
	move.l	(a3),d4
	and.l	d1,d4
	or.l	d3,d4
	move.l	d4,(a4)
	dbf	d7,.part
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; restore_logo: d0-d3 = box; copies the logo's groups under the box outline into vid_log
restore_logo:
	movem.l	d3-d5/a3,-(sp)
	lsr.w	#4,d0			; first group
	lsr.w	#4,d2			; last group
	sub.w	d0,d2			; groups - 1
	lsl.w	#3,d0
	move.w	d1,d4
	mulu	#SCR_BPL,d4
	add.w	d0,d4			; byte offset of the top-left group
	sub.w	d1,d3			; rows - 1
	move.l	ttl_data,a2
	add.l	#TTL_LOGO,a2
	move.l	vid_log,a3
.r:	move.w	d2,d5
	lea	0(a2,d4.w),a0
	lea	0(a3,d4.w),a1
.g:	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbf	d5,.g
	add.w	#SCR_BPL,d4
	dbf	d3,.r
	movem.l	(sp)+,d3-d5/a3
	rts

; ---------------------------------------------------------------
title_load:
	tst.l	ttl_data
	bne.s	.have
	lea	fn_title,a0
	bsr	fil_size
	bcs.s	.err
	move.l	d0,d3
	bsr	mem_alloc
	bcs.s	.err
	move.l	a0,ttl_data
	move.l	a0,a1
	lea	fn_title,a0
	move.l	d3,d0
	bsr	fil_load
	bcs.s	.err
.have:	move.l	ttl_data,a0
	lea	TTL_BANDS(a0),a0
	bsr	vid_set_bands
	move.l	ttl_data,a0
	lea	TTL_LUTS(a0),a0
	bsr	vid_set_luts
	and.b	#$fe,ccr
	rts
.err:	or.b	#1,ccr
	rts

; 16 copies of the cloud, each shifted one more pixel right (linear, wrapping) and stored
; twice in a row, so any rotation is a plain copy (see compose).
make_variants:
	tst.l	variants
	bne	.x
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	#16*VARIANT,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,variants
	move.l	ttl_data,a0		; D_0 = cloud
	lea	TTL_CLOUD(a0),a0
	move.l	variants,a1
	bsr	copy_screen
	moveq	#1,d7			; r
.var:	move.l	variants,a0		; D_r <- D_(r-1), then shift right one pixel
	move.l	d7,d0
	subq.l	#1,d0
	mulu	#VARIANT,d0
	add.l	d0,a0
	move.l	a0,a1
	add.l	#VARIANT,a1
	move.l	a1,a5
	bsr	copy_screen
	moveq	#4-1,d6			; planes
.pl:	move.l	a5,a0
	moveq	#3,d0
	sub.w	d6,d0
	add.w	d0,d0
	add.w	d0,a0			; plane p's first word
	move.w	31992(a0),d0		; X := LSB of the last word of this plane's stream
	lsr.w	#1,d0
	move.w	#4000/8-1,d5
.w:	roxr.w	(a0)
	lea	8(a0),a0
	roxr.w	(a0)
	lea	8(a0),a0
	roxr.w	(a0)
	lea	8(a0),a0
	roxr.w	(a0)
	lea	8(a0),a0
	roxr.w	(a0)
	lea	8(a0),a0
	roxr.w	(a0)
	lea	8(a0),a0
	roxr.w	(a0)
	lea	8(a0),a0
	roxr.w	(a0)
	lea	8(a0),a0
	dbf	d5,.w
	dbf	d6,.pl
	addq.w	#1,d7
	cmp.w	#16,d7
	bne	.var
	moveq	#16-1,d7		; second halves
	move.l	variants,a5
.dup:	move.l	a5,a0
	lea	SCR_SIZE(a5),a1
	bsr	copy_screen
	add.l	#VARIANT,a5
	dbf	d7,.dup
	movem.l	(sp)+,d3-d7/a3-a5
.x:	rts

; copy 32000 bytes a0 -> a1 (40-byte movem blocks). trashes d0-d2/a0-a2
copy_screen:
	movem.l	d3-d7/a3-a4,-(sp)
	move.w	#SCR_SIZE/40-1,d7
.c:	movem.l	(a0)+,d0-d6/a2-a4
	movem.l	d0-d6/a2-a4,(a1)
	lea	40(a1),a1
	dbf	d7,.c
	movem.l	(sp)+,d3-d7/a3-a4
	rts

; the game's default cursor (gmouse.pas: weapicon.dta record 87, 16x16 of 20x20)
load_cursor:
	lea	fn_icon,a0
	bsr	fil_size
	bcs.s	.x
	move.l	d0,d3
	bsr	mem_mark
	move.l	d0,d4
	move.l	d3,d0
	bsr	mem_alloc
	bcs.s	.x
	move.l	a0,a3
	lea	fn_icon,a0
	move.l	a3,a1
	move.l	d3,d0
	bsr	fil_load
	bcs.s	.rel
	move.l	a3,a0
	add.l	#87*400,a0
	lea	cursor_icon,a1
	moveq	#16-1,d1
.r:	moveq	#16-1,d0
.c:	move.b	(a0)+,(a1)+
	dbf	d0,.c
	addq.l	#4,a0
	dbf	d1,.r
	lea	cursor_icon,a0
	bsr	kbd_cursor_set
.rel:	move.l	d4,d0
	bsr	mem_release
.x:	rts

; has_arg: a0 = command tail text, a1 = word (C string). d0.w = 1 if present
has_arg:
.s:	move.b	(a0),d0
	beq.s	.no
	cmp.b	#13,d0
	beq.s	.no
	move.l	a0,a2
	move.l	a1,d1
.cmp:	move.b	(a1)+,d0
	beq.s	.yes
	move.b	(a2)+,d2
	cmp.b	#'a',d2
	blo.s	.u
	sub.b	#32,d2
.u:	cmp.b	d0,d2
	beq.s	.cmp
	move.l	d1,a1
	addq.l	#1,a0
	bra.s	.s
.yes:	moveq	#1,d0
	rts
.no:	moveq	#0,d0
	rts

fatal:	moveq	#4,d0
	bra	sys_exit

	include	"kernel.s"

	section	data
fn_script:	dc.b	"INPUT.INT",0
fn_title:	dc.b	"DATA",92,"TITLE.DAT",0
fn_credpal:	dc.b	"DATA",92,"CREDITS.ISL",0
fn_icon:	dc.b	"DATA",92,"WEAPICON.DTA",0
fn_intro2:	dc.b	"SOUND",92,"INTRO2.MOD",0
arg_seed:	dc.b	"/SHOWSEED",0
arg_done:	dc.b	"/DONE",0
	even
; runintro credits (intro.pas 1464): y, x, Pascal string
credits:
	dc.w	5,5
	dc.b	34,1,2,"1994 Channel 7, Destiny: Virtual"
	even
	dc.w	15,5
	dc.b	51,"Released Under GPL V3.0 in 2013 by Jeremy D Stanton"
	even
	dc.w	25,15
	dc.b	16," of IronSeed.net"
	even
	dc.w	35,5
	dc.b	52,1,2,"2013 y-salnikov - Converted IronSeed to FreePascal"
	even
	dc.w	45,15
	dc.b	14," and GNU/Linux"
	even
	dc.w	55,5
	dc.b	20,1,2,"2016 Nuke Bloodaxe"
	even
	dc.w	65,5
	dc.b	19,1,2,"2020 Matija Nalis"
	even
	dc.w	75,5
	dc.b	39,1,2,"2026 Atari STE port (68000 assembler)"
	even
	dc.w	85,5
	dc.b	21,"Some rights reserved."
	even
	dc.w	105,5
	dc.b	39,"IronSeed v1.30.0001 fpc 0.2.6 / STE 0.1"
	even
	dc.w	-1

	section	bss
ttl_data:	ds.l	1
tframes:	ds.l	1
variants:	ds.l	1
lastms:		ds.l	1
exitcode:		ds.w	1
cursor:		ds.w	1
keymode:	ds.w	1
permx:		ds.w	1
permy:		ds.w	1
kpos:		ds.w	1
cursor_icon:	ds.b	256
	even
