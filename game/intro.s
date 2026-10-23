; intro.s - INTRO.PRG: port of intro.pas. Started by IS.PRG with "/showseed" or
; "/showseed /done" (straight to the title). Exit codes as the original: 1 new game,
; 2 continue game, 4 quit.
;
; The whole intro: credits, Channel 7 logo, 'Destiny: Virtual', Mars, planet, charcom,
; battle, ship1, shrink into the alien screen, is2, final planet, then intro5 and the title
; (scrolling cloud under the logo, music, menu with mouse and keys, "Introduction" replays
; the intro). A key skips to the title. Scene data comes from tools/mk*.py (mkgame.sh).
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
	bsr	anykey
	bne	.cont
	bsr	generateplanet
	bsr	mem_mark		; the scenes' memory, released at .cont
	move.l	d0,scene_mark
	lea	fn_intro1,a0
	bsr	mod_load
	moveq	#88-87,d0		; mouse.setmousecursor(1)
	bsr	set_cursor
	bsr	anykey
	bne	.cont
	bsr	c7logo
	bsr	anykey
	bne	.cont
	bsr	loadmainpalette		; #1.2
	lea	ws_a,a0
	lea	ws_b,a1
	lea	ws_c,a2
	bsr	writestr2
	bsr	anykey
	bne	.cont
	move.w	#2000,d0		; wait(2)
	bsr	tim_delay
	bsr	fading
	bsr	anykey
	bne	.cont
	bsr	showmars		; #1.3
	bsr	anykey
	bne	.cont
	move.w	#2000,d0
	bsr	tim_delay
	bsr	fading
	bsr	anykey
	bne	.cont
	bsr	planet1			; #1.4
	bsr	charcom
	bsr	anykey
	bne	.cont
	bsr	battle
	bsr	ship1
	bsr	anykey
	bne	.cont
	bsr	alienscreen
	bsr	anykey
	bne	.cont
	bsr	is2
	bsr	anykey
	bne	.cont
	bsr	planet3
.cont:
	; continue: (intro.pas 1660) stopmod; flush keys; intro5 + fadein
	bsr	mod_stop
	move.l	scene_mark,d0
	beq.s	.nm
	bsr	mem_release
	clr.l	scene_mark
.nm:
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

; anykey: Z clear (bne) if a key is waiting (fastkeypressed). trashes d0-d2/a0-a2
anykey:
	bsr	kbd_keypressed
	tst.b	d0
	rts

; set_cursor: d0.w = n -> mouse cursor = weapicon.dta record 87+n (gmouse setmousecursor)
set_cursor:
	move.w	d0,cursor_rec
	bra	load_cursor

; the game's cursor (gmouse.pas: weapicon.dta record 87+n, 16x16 of 20x20)
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
	move.w	cursor_rec,d0
	add.w	#87,d0
	mulu	#400,d0
	move.l	a3,a0
	add.l	d0,a0
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

; ---------------------------------------------------------------
; c7logo (intro.pas 1095): TV static by palette flicker, the Channel 7 logo revealed
; 178 pixels per frame, then 75 frames of static, then a 24-step fade with static.
C7_ISP		equ	ISP_DATA+64+SCR_SIZE	; tools/mkc7.py: ISP2, then logo chunky, palette
C7_TSLICE	equ	TSLICE/2		; tslice:=tslice div 2
C7_B		equ	22			; b:=round(tslice*1.8)
C7_MAX		equ	38000
c7logo:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	GS_COLORS(a6),a0	; fillchar(colors,0); set256colors
	move.w	#768/4-1,d0
.z:	clr.l	(a0)+
	dbf	d0,.z
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	tst.l	c7_data			; loadscreen_data('channel7',t) (+ static on screen)
	bne.s	.have
	lea	fn_c7,a0
	bsr	fil_size
	bcs	.out
	move.l	d0,d3
	bsr	mem_alloc
	bcs	.out
	move.l	a0,c7_data
	move.l	a0,a1
	lea	fn_c7,a0
	move.l	d3,d0
	bsr	fil_load
	bcs	.out
.have:	moveq	#16,d0
	bsr	vid_set_fade
	move.l	c7_data,a0
	move.l	vid_phys,a1
	bsr	pic_show
	move.l	vid_phys,a0
	bsr	gfx_set_target
	lea	GS_COLORS(a6),a0	; the screen's static shows only once colours are set
	bsr	vid_set256
	move.l	c7_data,a0		; colors := channel7's palette
	add.l	#C7_ISP+64000,a0
	lea	GS_COLORS(a6),a1
	move.w	#768/4-1,d0
.pc:	move.l	(a0)+,(a1)+
	dbf	d0,.pc
	bsr	anykey
	bne	.out
	clr.w	c7_j
	moveq	#0,d6			; index
.loop1:	bsr	c7_phase_a
	move.w	#70+(120-C7_TSLICE)-1,d7	; reveal 178 pixels
.rv:	addq.w	#1,d6
	move.w	c7_j,d0
	add.w	#159,d0
	cmp.w	#C7_MAX,d0
	bls.s	.j
	sub.w	#C7_MAX,d0
.j:	move.w	d0,c7_j
	moveq	#0,d1
	move.w	d0,d1
	divu	#300,d1			; y-30 in the low word, x-20 in the high word
	move.l	d1,d0
	swap	d0
	add.w	#20,d0			; x
	add.w	#30,d1			; y
	move.w	d1,d2
	mulu	#320,d2
	add.w	d0,d2
	move.l	c7_data,a0
	add.l	#C7_ISP,a0
	move.b	0(a0,d2.l),d2		; t^[y,x]
	beq.s	.nz
	bsr	gfx_pset
.nz:	dbf	d7,.rv
	bsr	c7_phase_b
	moveq	#C7_B,d0
	bsr	tim_delay
	cmp.w	#C7_MAX,d6
	bls	.loop1
	bsr	anykey
	bne.s	.end
	moveq	#75-1,d6		; 75 frames of static
.loop2:	bsr	c7_phase_a
	moveq	#C7_TSLICE,d0
	bsr	tim_delay
	bsr	c7_phase_b
	moveq	#C7_B,d0
	bsr	tim_delay
	dbf	d6,.loop2
	bsr	anykey
	bne.s	.end
	lea	GS_COLORS(a6),a0	; temppal := colors
	lea	c7_temppal,a1
	move.w	#768/4-1,d0
.tp:	move.l	(a0)+,(a1)+
	dbf	d0,.tp
	moveq	#24,d5			; a
	moveq	#0,d6			; index
.loop3:	addq.w	#1,d6
	tst.w	d5
	beq.s	.nf
	lea	c7_temppal,a0		; colors[0..199] := round(a/24 * temppal)
	lea	GS_COLORS(a6),a1
	move.w	#200*3-1,d4
.f:	moveq	#0,d0
	move.b	(a0)+,d0
	mulu	d5,d0
	add.w	#12,d0			; round(x/24)
	divu	#24,d0
	move.b	d0,(a1)+
	dbf	d4,.f
.nf:	bsr	c7_phase_a
	moveq	#C7_TSLICE*2,d0
	bsr	tim_delay
	bsr	c7_phase_b
	moveq	#C7_TSLICE,d0
	bsr	tim_delay
	btst	#0,d6
	bne.s	.odd
	subq.w	#1,d5
.odd:	tst.w	d5
	bne.s	.loop3
	bra.s	.x
.end:	lea	GS_COLORS(a6),a0	; ending: black
	move.w	#768/4-1,d0
.zz:	clr.l	(a0)+
	dbf	d0,.zz
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
.x:
.out:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; even-row static on: colors[200..215] := colors[random(22)], colors[216..231] := colors[0]
c7_phase_a:
	lea	GS_COLORS+200*3(a6),a2
	moveq	#22,d2
	bsr.s	c7_randomise
	lea	GS_COLORS+216*3(a6),a2
	bsr.s	c7_black
	lea	GS_COLORS(a6),a0
	bra	vid_set256
; odd-row static on: colors[216..231] := colors[random(16)], colors[200..215] := colors[0]
c7_phase_b:
	lea	GS_COLORS+216*3(a6),a2
	moveq	#16,d2
	bsr.s	c7_randomise
	lea	GS_COLORS+200*3(a6),a2
	bsr.s	c7_black
	lea	GS_COLORS(a6),a0
	bra	vid_set256
c7_randomise:				; 16 entries at a2 := random entries 0..d2-1
	move.l	d3,-(sp)
	moveq	#16-1,d3
.r:	move.w	d2,d0
	bsr	rnd
	move.w	d0,d1
	add.w	d0,d0
	add.w	d1,d0
	lea	GS_COLORS(a6),a0
	add.w	d0,a0
	move.b	(a0)+,(a2)+
	move.b	(a0)+,(a2)+
	move.b	(a0)+,(a2)+
	dbf	d3,.r
	move.l	(sp)+,d3
	rts
c7_black:				; 16 entries at a2 := colors[0]
	moveq	#16-1,d0
.b:	move.b	GS_COLORS(a6),(a2)+
	move.b	GS_COLORS+1(a6),(a2)+
	move.b	GS_COLORS+2(a6),(a2)+
	dbf	d0,.b
	rts

; ---------------------------------------------------------------
; palette helpers: exact ports of intro.pas fading / fadein / loadmainpalette, on GS_COLORS

loadmainpalette:
	lea	fn_mainpal,a0
	lea	GS_COLORS(a6),a1
	move.l	#768,d0
	bra	fil_load

; fading (intro.pas 425): 47 steps down to black, delay tslice shr 1
fading:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	GS_COLORS(a6),a0
	lea	f_temp,a1
	lea	f_px,a2
	lea	f_pdx,a3
	lea	f_dx,a4
	move.w	#768-1,d0
.i:	moveq	#0,d1
	move.b	(a0)+,d1
	move.b	d1,(a1)+		; temppal := colors
	divu	#48,d1
	move.b	d1,(a2)+		; px = c div 48
	swap	d1
	move.b	d1,(a3)+		; pdx = c mod 48
	move.b	#48,(a4)+		; dx = 48
	dbf	d0,.i
	moveq	#47-1,d7
.step:	lea	f_temp,a1
	lea	f_px,a2
	lea	f_pdx,a3
	lea	f_dx,a4
	move.w	#768-1,d6
.j:	move.b	(a2)+,d0
	sub.b	d0,(a1)
	move.b	(a3)+,d0
	sub.b	d0,(a4)
	bgt.s	.n
	add.b	#48,(a4)
	subq.b	#1,(a1)
.n:	addq.l	#1,a1
	addq.l	#1,a4
	dbf	d6,.j
	lea	f_temp,a0
	bsr	vid_set256
	moveq	#TSLICE/2,d0
	bsr	tim_delay
	dbf	d7,.step
	lea	f_temp,a0
	move.w	#768/4-1,d0
.z:	clr.l	(a0)+
	dbf	d0,.z
	lea	f_temp,a0
	bsr	vid_set256
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; fadein (intro.pas 459): 47 steps up to colors, delay tslice shr 2
fadein:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	GS_COLORS(a6),a0
	lea	f_temp,a1
	lea	f_px,a2
	lea	f_pdx,a3
	lea	f_dx,a4
	move.w	#768-1,d0
.i:	moveq	#0,d1
	move.b	(a0)+,d1
	clr.b	(a1)+
	divu	#48,d1
	move.b	d1,(a2)+
	swap	d1
	move.b	d1,(a3)+
	clr.b	(a4)+
	dbf	d0,.i
	moveq	#47-1,d7
.step:	lea	f_temp,a1
	lea	f_px,a2
	lea	f_pdx,a3
	lea	f_dx,a4
	move.w	#768-1,d6
.j:	move.b	(a2)+,d0
	add.b	d0,(a1)
	move.b	(a3)+,d0
	add.b	d0,(a4)
	cmp.b	#48,(a4)
	blt.s	.n
	addq.b	#1,(a1)
	sub.b	#48,(a4)
.n:	addq.l	#1,a1
	addq.l	#1,a4
	dbf	d6,.j
	lea	f_temp,a0
	bsr	vid_set256
	moveq	#TSLICE/4,d0
	bsr	tim_delay
	dbf	d7,.step
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; pas_round: d0.l = numerator (>= 0), d1.w = denominator -> d0.w = round(n/d), halves to even
pas_round:
	divu	d1,d0
	move.l	d0,d2
	swap	d2			; remainder
	add.w	d2,d2
	cmp.w	d1,d2
	blo.s	.x
	bhi.s	.up
	btst	#0,d0			; exactly half: to even
	beq.s	.x
.up:	addq.w	#1,d0
.x:	and.l	#$ffff,d0
	rts

; printxy2 (intro.pas 754): d0 = x, d1 = y, d2 = colour, a0 = string; flat, transparent
printxy2:
	movem.l	d0-d1/a0,-(sp)
	move.w	d2,GS_TCOLOR(a6)
	move.w	#255,GS_BKCOLOR(a6)
	moveq	#1,d0
	bsr	txt_set_flat
	movem.l	(sp)+,d0-d1/a0
	bsr	txt_print
	moveq	#0,d0
	bra	txt_set_flat

; ---------------------------------------------------------------
; writestr2 (intro.pas 791): three centred lines converge from four directions, colour
; 31-i, leaving trails; then dothefade.  a0, a1, a2 = Pascal strings
writestr2:
	movem.l	d3-d7/a3-a5,-(sp)
	movem.l	a0-a2,ws_str
	move.l	vid_phys,a0
	bsr	vid_clear
	move.l	vid_phys,a0
	bsr	gfx_set_target
	lea	fn_mainpalisl,a0	; slots for colours 0-31 (31 alone: dothefade turns it red)
	bsr	pal_load
	moveq	#16,d0
	bsr	vid_set_fade
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	lea	ws_str,a3		; j = 156 - (length*5) div 2
	lea	ws_j,a4
	moveq	#3-1,d0
.jl:	move.l	(a3)+,a0
	moveq	#0,d1
	move.b	(a0),d1
	mulu	#5,d1
	lsr.w	#1,d1
	move.w	#156,d2
	sub.w	d1,d2
	move.w	d2,(a4)+
	dbf	d0,.jl
	moveq	#31,d7			; i
.i:	moveq	#0,d6			; line 0..2 (y 90, 100, 110)
.line:	move.w	d6,d0
	mulu	#10,d0
	add.w	#90,d0
	move.w	d0,d5			; y centre
	move.w	d6,d0
	add.w	d0,d0
	lea	ws_j,a0
	move.w	0(a0,d0.w),d4		; j
	lsl.w	#1,d0
	lea	ws_str,a0
	move.l	0(a0,d0.w),a5		; string
	moveq	#4-1,d3			; (-,-) (-,+) (+,-) (+,+)
.dir:	move.w	d4,d0
	move.w	d5,d1
	btst	#1,d3
	bne.s	.xp
	sub.w	d7,d0
	bra.s	.xd
.xp:	add.w	d7,d0
.xd:	btst	#0,d3
	bne.s	.yp
	sub.w	d7,d1
	bra.s	.yd
.yp:	add.w	d7,d1
.yd:	moveq	#31,d2
	sub.w	d7,d2
	move.l	a5,a0
	bsr	printxy2
	dbf	d3,.dir
	addq.w	#1,d6
	cmp.w	#3,d6
	bne.s	.line
	moveq	#TSLICE/2,d0
	bsr	tim_delay
	dbf	d7,.i
	bsr	dothefade
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; dothefade (intro.pas 722): colours 0-30 fade out over 32 steps, colour 31 fades to
; half, then turns red
dothefade:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	GS_COLORS(a6),a0
	lea	f_temp,a1
	move.w	#768/4-1,d0
.c:	move.l	(a0)+,(a1)+
	dbf	d0,.c
	moveq	#31,d7			; a
.a:	lea	GS_COLORS(a6),a3
	lea	f_temp,a4
	moveq	#31*3-1,d6		; entries 0..30
.e:	moveq	#0,d0
	move.b	(a3)+,d0
	mulu	d7,d0
	moveq	#32,d1
	bsr	pas_round
	move.b	d0,(a4)+
	dbf	d6,.e
	cmp.w	#16,d7
	ble.s	.red
	moveq	#3-1,d6			; entry 31: round((a-16)*c/16)
.e31:	moveq	#0,d0
	move.b	(a3)+,d0
	move.w	d7,d1
	sub.w	#16,d1
	mulu	d1,d0
	moveq	#16,d1
	bsr	pas_round
	move.b	d0,(a4)+
	dbf	d6,.e31
	bra.s	.set
.red:	moveq	#16,d0			; temppal[31,1] := round(63/16*(16-a))
	sub.w	d7,d0
	mulu	#63,d0
	moveq	#16,d1
	bsr	pas_round
	move.b	d0,(a4)
.set:	lea	f_temp,a0
	bsr	vid_set256
	moveq	#TSLICE,d0
	bsr	tim_delay
	dbf	d7,.a
	lea	f_temp,a0		; colors := temppal
	lea	GS_COLORS(a6),a1
	move.w	#768/4-1,d0
.b:	move.l	(a0)+,(a1)+
	dbf	d0,.b
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; ---------------------------------------------------------------
; showmars (intro.pas 697) + upscroll + the Mars titles with their red ramps
MRS_BANDS	equ	4
MRS_LUTS	equ	MRS_BANDS+2+4*34
MRS_REPS	equ	MRS_LUTS+1024
MRS_SPLITS	equ	MRS_REPS+64
MRS_CLOUD	equ	MRS_SPLITS+6
MRS_WORLD	equ	MRS_CLOUD+SCR_SIZE
MRS_PAL		equ	MRS_WORLD+99*SCR_BPL
showmars:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	GS_COLORS(a6),a0	; fillchar(colors,0); set256colors
	move.w	#768/4-1,d0
.z:	clr.l	(a0)+
	dbf	d0,.z
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	tst.l	mrs_data
	bne.s	.have
	lea	fn_mars,a0
	bsr	fil_size
	bcs	.out
	move.l	d0,d3
	bsr	mem_alloc
	bcs	.out
	move.l	a0,mrs_data
	move.l	a0,a1
	lea	fn_mars,a0
	move.l	d3,d0
	bsr	fil_load
	bcs	.out
.have:	move.l	mrs_data,a5
	lea	MRS_BANDS(a5),a0
	bsr	vid_set_bands
	lea	MRS_REPS(a5),a0
	bsr	vid_set_reps
	moveq	#1,d0			; only the cloud band to start with
	lea	mrs_lines,a0
	clr.w	(a0)
	bsr	vid_set_lines
	lea	MRS_LUTS(a5),a0
	bsr	vid_set_luts
	lea	MRS_CLOUD(a5),a0	; loadscreen_data('cloud',@screen)
	move.l	vid_phys,a1
	bsr	copy_screen
	move.l	vid_phys,a0
	bsr	gfx_set_target
	move.l	a5,a0			; colors := world's palette; [29], [30] := [0]
	add.l	#MRS_PAL,a0
	lea	GS_COLORS(a6),a1
	move.w	#768/4-1,d0
.p:	move.l	(a0)+,(a1)+
	dbf	d0,.p
	lea	GS_COLORS(a6),a0
	move.b	(a0),29*3(a0)
	move.b	1(a0),29*3+1(a0)
	move.b	2(a0),29*3+2(a0)
	move.b	(a0),30*3(a0)
	move.b	1(a0),30*3+1(a0)
	move.b	2(a0),30*3+2(a0)
	bsr	vid_set256
	moveq	#1,d7			; upscroll: y = 1..99, the world's top y rows at 200-y
.up:	move.w	#200,d6
	sub.w	d7,d6			; first row on screen
	lea	mrs_lines,a0		; bands follow the picture: 0, then each world split on screen
	move.l	a0,a2
	clr.w	(a2)+
	moveq	#1,d0			; band count
	lea	MRS_SPLITS(a5),a1
	moveq	#3-1,d2
.bl:	move.w	(a1)+,d1
	add.w	d6,d1
	cmp.w	#SCR_H-1,d1
	bhi.s	.bn
	move.w	d1,(a2)+
	addq.w	#1,d0
.bn:	dbf	d2,.bl
	bsr	vid_set_lines
	move.l	a5,a0			; memmove(v_buf + 320*(200-y), img, 320*y)
	add.l	#MRS_WORLD,a0
	move.l	vid_phys,a1
	move.w	d6,d0
	mulu	#SCR_BPL,d0
	add.l	d0,a1
	move.w	d7,d0
	mulu	#SCR_BPL/4,d0
	subq.w	#1,d0
.cp:	move.l	(a0)+,(a1)+
	dbf	d0,.cp
	moveq	#5,d0
	bsr	tim_delay
	addq.w	#1,d7
	cmp.w	#100,d7
	bne	.up
	lea	vid_luts,a0		; line LUTs for the final layout (text below uses band 0)
	bsr	vid_set_luts
	move.w	#145,d0			; printxy2(145,30,29,'Mars'); printxy2(133,40,30,'3784 A.D.')
	moveq	#30,d1
	moveq	#29,d2
	lea	s_mars,a0
	bsr	printxy2
	move.w	#133,d0
	moveq	#40,d1
	moveq	#30,d2
	lea	s_year,a0
	bsr	printxy2
	moveq	#29,d4			; ramps: setrgb256(c, a, 0, 0), a = 0..63, delay tslice
.ramp:	moveq	#0,d5
.ra:	move.w	d4,d0
	mulu	#3,d0
	lea	GS_COLORS(a6),a0
	move.b	d5,0(a0,d0.w)
	clr.b	1(a0,d0.w)
	clr.b	2(a0,d0.w)
	bsr	vid_set256
	moveq	#TSLICE,d0
	bsr	tim_delay
	addq.w	#1,d5
	cmp.w	#64,d5
	bne.s	.ra
	addq.w	#1,d4
	cmp.w	#31,d4
	bne.s	.ramp
.out:	movem.l	(sp)+,d3-d7/a3-a5
	rts
; ---------------------------------------------------------------
; planet scenes (intro.pas makeplanet; renderer in planet.s)

; generateplanet (intro.pas 929): land as loaded, c = 0, ecl = 180
generateplanet:
	bsr	plan_load
	bcs	fatal
	bsr	plan_reset
	clr.w	pl_c
	move.w	#180,pl_ecl
	rts

; planet_scene: a0 = picture name. Loads it hidden (palette black) into all three screens.
planet_scene:
	move.l	a0,-(sp)
	moveq	#0,d0
	bsr	vid_set_fade
	move.l	(sp)+,a0
	move.l	vid_phys,a1
	bsr	pic_load
	bcs	fatal
	move.l	vid_phys,a0
	move.l	vid_log,a1
	bsr	copy_screen
	move.l	vid_phys,a0
	move.l	vid_spare,a1
	bsr	copy_screen
	bsr	black256		; black, then the fade level back to full
	moveq	#16,d0
	bra	vid_set_fade

; makeplanet (intro.pas 955): d0.w = t seconds, d1.w = eclipse flag. Frames until t seconds
; have passed (the original compares wall-clock seconds, so t = 0 is up to a second of
; frames - spent while the palette is black: one frame here; t > 0 runs t + 0.5 s).
; The original turns one step per frame + delay(tslice*3); here the steps follow the time
; (one per 75 ms) so the planet turns at the original speed whatever a frame costs.
; A key press ends it early (the original waits).
makeplanet:
	movem.l	d3-d7,-(sp)
	move.w	d0,d6
	move.w	d1,d7
	bsr	tim_ms
	move.l	d0,d5			; start
	move.l	d0,d4
	sub.l	#3*TSLICE,d4		; time of the last step: the first frame steps once
	mulu	#1000,d6
	add.l	#500,d6			; t > 0: run until t + 0.5 s
.frame:	bsr	tim_ms
	move.l	d0,d3
	sub.l	d4,d0
	cmp.l	#3*TSLICE,d0
	bhs.s	.go
	sub.w	#3*TSLICE,d0		; faster than the original: wait out the rest
	neg.w	d0
	bsr	tim_delay
	bra.s	.frame
.go:	divu	#3*TSLICE,d0		; steps due
	move.w	d0,d1
	mulu	#3*TSLICE,d0
	add.l	d0,d4
	subq.w	#1,d1
.st:	move.w	pl_c,d0			; inc(c); eclipse: inc(ecl) on even c
	addq.w	#1,d0
	cmp.w	#240,d0
	bls.s	.c
	sub.w	#240,d0
.c:	move.w	d0,pl_c
	tst.w	d7
	beq.s	.ne
	btst	#0,d0
	bne.s	.ne
	move.w	pl_ecl,d0
	addq.w	#1,d0
	cmp.w	#340,d0
	bls.s	.e
	sub.w	#340,d0
.e:	move.w	d0,pl_ecl
.ne:	dbf	d1,.st
	move.l	vid_log,a0
	bsr	gfx_set_target
	move.w	pl_c,d0
	move.w	pl_ecl,d1
	bsr	plan_frame
	bsr	vid_flip
	bsr	anykey
	bne.s	.x
	cmp.l	#500,d6			; t = 0: one frame
	beq.s	.x
	bsr	tim_ms
	sub.l	d5,d0
	cmp.l	d6,d0
	blo	.frame
.x:	movem.l	(sp)+,d3-d7
	rts

; bigtext: a0 = (y.w, Pascal string, even) records ending with -1: bigprintxy(0, y, s)
; into all three screens (the original draws once, on its single screen)
bigtext:
	movem.l	d3/a3-a4,-(sp)
	move.l	a0,a4
	lea	vid_spare,a3		; vid_spare, vid_phys, vid_log (consecutive longs)
	moveq	#3-1,d3
.buf:	move.l	(a3)+,a0
	bsr	gfx_set_target
	move.l	a4,a0
.l:	move.w	(a0)+,d1
	bmi.s	.n
	moveq	#0,d0
	move.l	a0,-(sp)
	bsr	bigprintxy
	move.l	(sp)+,a0
	moveq	#0,d0
	move.b	(a0),d0
	lea	2(a0,d0.w),a0
	move.l	a0,d0
	and.w	#$fffe,d0
	move.l	d0,a0
	bra.s	.l
.n:	dbf	d3,.buf
	move.l	vid_log,a0
	bsr	gfx_set_target
	movem.l	(sp)+,d3/a3-a4
	rts

; bigprintxy (intro.pas 381): d0 = x1, d1 = y1, a0 = Pascal string. 8x8 glyphs, colour
; tcolor down by one per row, transparent (bkcolor 255)
bigprintxy:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,d6
	move.w	d1,d7
	moveq	#0,d0
	move.b	(a0)+,d0
	move.l	a0,a3
	move.w	d0,bp_n
	beq	.x
.ch:	moveq	#0,d0
	move.b	(a3)+,d0
	moveq	#1,d1			; letter (1-based)
	cmp.b	#'a',d0
	blo.s	.l1
	cmp.b	#'z',d0
	bhi.s	.l1
	sub.w	#40,d0
	bra.s	.lt
.l1:	cmp.b	#'A',d0
	blo.s	.l2
	cmp.b	#'Z',d0
	bhi.s	.l2
	sub.w	#36,d0
	bra.s	.lt
.l2:	cmp.b	#' ',d0
	blo.s	.l3
	cmp.b	#'"',d0
	bhi.s	.l3
	sub.w	#31,d0
	bra.s	.lt
.l3:	cmp.b	#39,d0
	blo.s	.l4
	cmp.b	#'?',d0
	bhi.s	.l4
	sub.w	#35,d0
	bra.s	.lt
.l4:	cmp.b	#'%',d0
	bne.s	.l5
	moveq	#55,d0
	bra.s	.lt
.l5:	moveq	#1,d0
.lt:	subq.w	#1,d0
	lsl.w	#3,d0
	lea	txt_bigfont,a4
	add.w	d0,a4
	move.w	GS_TCOLOR(a6),d4
	move.w	d7,d5			; y
	move.w	#8-1,a5
.row:	addq.w	#1,d5
	move.b	(a4)+,d3
	moveq	#7,d0			; column
.px:	add.b	d3,d3
	bcc.s	.np
	movem.w	d0,-(sp)
	neg.w	d0
	addq.w	#8,d0
	add.w	d6,d0			; x1 + 1 + (7 - a)
	move.w	d5,d1
	move.w	d4,d2
	bsr	gfx_pset
	movem.w	(sp)+,d0
.np:	dbf	d0,.px
	subq.w	#1,d4
	subq.w	#1,a5
	move.w	a5,d0
	bpl.s	.row
	addq.w	#8,d6
	subq.w	#1,bp_n
	bne	.ch
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; ---------------------------------------------------------------
; charcom (intro.pas 1540): the encode transfer screen. tools/mkcharcom.py made
; CHARCOM.ISP: picture, palette, pre-rendered static frames of the box, the lights.
CC_PAL		equ	ISP2_FULL
CC_NFR		equ	CC_PAL+768
CC_FRAMES	equ	CC_NFR+2
CC_FSIZE	equ	70*48
charcom:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	mem_mark
	move.l	d0,-(sp)
	lea	fn_charcom,a0
	bsr	fil_size
	bcs	fatal
	move.l	d0,d3
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,cc_data
	move.l	a0,a1
	lea	fn_charcom,a0
	move.l	d3,d0
	bsr	fil_load
	bcs	fatal
	move.l	cc_data,a0		; lights table: after the frames
	add.l	#CC_NFR,a0
	move.w	(a0),d0
	sub.l	#CC_NFR,a0
	move.w	d0,cc_nfr
	mulu	#CC_FSIZE,d0
	add.l	#CC_FRAMES,d0
	add.l	a0,d0
	move.l	d0,cc_lights
	moveq	#0,d0			; loadscreen_data (hidden: the palette is black)
	bsr	vid_set_fade
	move.l	cc_data,a0
	move.l	vid_phys,a1
	bsr	pic_show
	bsr	black256
	moveq	#16,d0
	bsr	vid_set_fade
	move.l	cc_data,a0		; colors := charcom's palette
	add.l	#CC_PAL,a0
	lea	GS_COLORS(a6),a1
	move.w	#768/4-1,d0
.p:	move.l	(a0)+,(a1)+
	dbf	d0,.p
	move.l	vid_phys,a0
	bsr	gfx_set_target
	bsr	fadein
	moveq	#0,d0			; readyencode
	bsr	cc_static
	move.w	#191,GS_TCOLOR(a6)
	move.w	#255,GS_BKCOLOR(a6)
	lea	cc_text,a3		; (x, y, string) lines, each followed by charcomstuff(1);
	moveq	#0,d7			; powerupencodes after the third
.tl:	move.w	(a3)+,d0
	bmi.s	.td
	move.w	(a3)+,d1
	move.l	a3,a0
	bsr	txt_print
	moveq	#0,d0
	move.b	(a3),d0
	lea	2(a3,d0.w),a3
	move.l	a3,d0
	and.w	#$fffe,d0
	move.l	d0,a3
	addq.w	#1,d7
	cmp.w	#3,d7
	bne.s	.ns
	bsr	powerupencodes
.ns:	bsr	charcomstuff
	bra.s	.tl
.td:	bsr	fadecharcom
	move.l	(sp)+,d0
	bsr	mem_release
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; black256: show the current bands' reps at black (colors untouched)
black256:
	lea	f_temp,a0
	move.w	#768/4-1,d0
.z:	clr.l	(a0)+
	dbf	d0,.z
	lea	f_temp,a0
	bra	vid_set256

; cc_static: d0.w = phase (0: even rows lit, 1: odd rows). At the next VBL, draws a random
; frame of that phase into the static box of vid_phys.
cc_static:
	movem.l	d3-d5,-(sp)
	move.w	d0,d3
	move.w	cc_nfr,d0
	lsr.w	#1,d0
	bsr	rnd
	add.w	d0,d0
	add.w	d3,d0
	mulu	#CC_FSIZE,d0
	move.l	cc_data,a0
	add.l	#CC_FRAMES,a0
	add.l	d0,a0
	bsr	vid_vsync
	move.l	vid_phys,a2
	lea	40*SCR_BPL+56(a2),a2
	moveq	#70-1,d3
.r:	movem.l	(a0)+,d0-d2/d4-d5/a1
	movem.l	d0-d2/d4-d5/a1,(a2)
	movem.l	(a0)+,d0-d2/d4-d5/a1
	movem.l	d0-d2/d4-d5/a1,24(a2)
	lea	SCR_BPL(a2),a2
	dbf	d3,.r
	movem.l	(sp)+,d3-d5
	rts

; charcomstuff(1) (intro.pas 1039): flicker for t = 1 s by the wall clock (1-2 s; 1.5 s
; here): phase A, tslice/2, phase B, tslice/2 + tslice/5. A key press ends it early.
charcomstuff:
	movem.l	d3-d4,-(sp)
	bsr	tim_ms
	move.l	d0,d4
.l:	moveq	#0,d0
	bsr	cc_static
	moveq	#TSLICE/2,d0
	bsr	tim_delay
	moveq	#1,d0
	bsr	cc_static
	moveq	#TSLICE/2,d0
	bsr	tim_delay
	moveq	#TSLICE/5,d0
	bsr	tim_delay
	bsr	anykey
	bne.s	.x
	bsr	tim_ms
	sub.l	d4,d0
	cmp.l	#1500,d0
	blo.s	.l
.x:	movem.l	(sp)+,d3-d4
	rts

; powerupencodes (intro.pas 882): six bars grow, 37 steps each (colour 64+round(b*31/36),
; two rows), with the bar's light switched on. Per step phase A, tslice; phase B is set
; and replaced at once in the original (never on screen), so it is skipped.
powerupencodes:
	movem.l	d3-d7/a3,-(sp)
	moveq	#0,d6			; a
.a:	move.l	d6,d0			; lights of bar a
	divu	#3,d0
	move.w	d0,d5			; a div 3
	swap	d0
	mulu	#30,d0
	add.w	#48,d0
	move.w	d0,d4			; row (a mod 3)*30+48
	mulu	#258,d5
	add.w	#13,d5			; x (a div 3)*258+13
	moveq	#0,d7			; b
.b:	bsr	tim_ms			; step start (the VBL wait below counts in tslice)
	move.l	d0,pu_t0
	move.l	d7,d0
	mulu	#31,d0
	moveq	#36,d1
	bsr	pas_round
	add.w	#64,d0
	move.w	d0,d3
	move.w	d5,d0
	add.w	d7,d0
	move.w	d4,d1
	move.w	d3,d2
	bsr	gfx_pset
	move.w	d5,d0
	add.w	d7,d0
	move.w	d4,d1
	addq.w	#1,d1
	move.w	d3,d2
	bsr	gfx_pset
	moveq	#0,d0
	bsr	cc_static
	bsr	tim_ms
	sub.l	pu_t0,d0
	sub.w	#TSLICE,d0
	bpl.s	.nd
	neg.w	d0
	bsr	tim_delay
.nd:	tst.w	d7
	bne.s	.nl
	move.l	cc_lights,a3		; find bar a's list
	move.w	d6,d0
	bra.s	.lf
.ls:	move.w	(a3)+,d1
	mulu	#6,d1
	add.w	d1,a3
.lf:	dbf	d0,.ls
	move.w	(a3)+,d3
	bra.s	.le
.lp:	movem.w	(a3)+,d0-d2
	bsr	gfx_pset
.le:	dbf	d3,.lp
.nl:	addq.w	#1,d7
	cmp.w	#37,d7
	bne	.b
	addq.w	#1,d6
	cmp.w	#6,d6
	bne	.a
	movem.l	(sp)+,d3-d7/a3
	rts

; fadecharcom (intro.pas 1062): 24 steps colors := round(a*temppal/24), a = 24..1, with
; the static: phase A, tslice/2, phase B, tslice/2+2
fadecharcom:
	movem.l	d3-d7/a3-a4,-(sp)
	lea	GS_COLORS(a6),a0
	lea	f_temp,a1
	move.w	#768/4-1,d0
.c:	move.l	(a0)+,(a1)+
	dbf	d0,.c
	moveq	#24,d7
.s:	lea	f_temp,a3
	lea	GS_COLORS(a6),a4
	move.w	#768-1,d6
.j:	moveq	#0,d0
	move.b	(a3)+,d0
	mulu	d7,d0
	moveq	#24,d1
	bsr	pas_round
	move.b	d0,(a4)+
	dbf	d6,.j
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	moveq	#0,d0
	bsr	cc_static
	moveq	#TSLICE/2,d0
	bsr	tim_delay
	moveq	#1,d0
	bsr	cc_static
	moveq	#TSLICE/2+2,d0
	bsr	tim_delay
	subq.w	#1,d7
	bne.s	.s
	movem.l	(sp)+,d3-d7/a3-a4
	rts

; load_whole: a0 = file name -> a0 = the whole file in a new block, d0.l = size
load_whole:
	move.l	a0,-(sp)
	bsr	fil_size
	bcs	fatal
	move.l	d0,-(sp)
	bsr	mem_alloc
	bcs	fatal
	move.l	(sp)+,d0
	move.l	(sp)+,a1
	exg	a0,a1
	movem.l	d0/a1,-(sp)
	bsr	fil_load
	bcs	fatal
	movem.l	(sp)+,d0/a0
	rts

; battle (intro.pas 1569): battle1 with its palette, inverted land, the small planet
battle:
	lea	fn_pln2,a0
	bsr	planet_scene
	lea	fn_pln2pal,a0		; loadscreen_data: colors := battle1's palette
	lea	GS_COLORS(a6),a1
	move.l	#768,d0
	bsr	fil_load
	bcs	fatal
	bsr	plan_invert
	moveq	#1,d0			; radius 2000, c2 1.16
	bsr	plan_setup
	moveq	#120,d0
	bsr	rnd
	move.w	d0,pl_c
	move.w	#105,pl_ecl
	move.w	#22,GS_TCOLOR(a6)
	move.w	#255,GS_BKCOLOR(a6)
	lea	text2,a0
	bsr	bigtext
	moveq	#0,d0
	moveq	#0,d1
	bsr	makeplanet
	bsr	fadein
	moveq	#10,d0
	moveq	#0,d1
	bra	makeplanet

; ship1 (intro.pas 1585): shown at once (set256colors), then the orders, wait(2) apart.
; SHRINK.DAT (tools/mkalien.py) stays loaded for alienscreen, which releases it.
SH_PAL		equ	ISP2_FULL
SH_FRAMES	equ	SH_PAL+768
ship1:
	movem.l	d3/a3,-(sp)
	bsr	mem_mark
	move.l	d0,al_mark
	lea	fn_shrink,a0
	bsr	load_whole
	move.l	a0,al_shrink
	move.l	vid_phys,a1
	bsr	pic_show
	move.l	al_shrink,a0
	add.l	#SH_PAL,a0
	lea	GS_COLORS(a6),a1
	move.w	#768/4-1,d0
.p:	move.l	(a0)+,(a1)+
	dbf	d0,.p
	move.l	vid_phys,a0
	bsr	gfx_set_target
	move.w	#255,GS_TCOLOR(a6)
	move.w	#255,GS_BKCOLOR(a6)
	move.w	#2000,d0
	bsr	tim_delay
	lea	orders,a3
.l:	move.w	(a3)+,d1
	bmi.s	.x
	moveq	#50,d0
	move.l	a3,a0
	bsr	txt_print
	moveq	#0,d0
	move.b	(a3),d0
	lea	2(a3,d0.w),a3
	move.l	a3,d0
	and.w	#$fffe,d0
	move.l	d0,a3
	move.w	#2000,d0
	bsr	tim_delay
	bsr	anykey
	beq.s	.l
.x:	movem.l	(sp)+,d3/a3
	rts

; alienscreen: shrinkalienscreen, fadeinalienscreen, alienscreenwait, fading
; (intro.pas 1281-1366, 1608)
AL_PAL		equ	ISP2_FULL
AL_DOTS		equ	AL_PAL+768
AL_CIRC		equ	AL_DOTS+2*8*8
alienscreen:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	f_temp2,a1		; temppal: colours 0-31 and 240-255 of colors, the rest black
	lea	GS_COLORS(a6),a0
	move.w	#768-1,d0
.t:	clr.b	(a1)+
	dbf	d0,.t
	lea	f_temp2,a1
	move.w	#32*3-1,d0
.t1:	move.b	(a0)+,(a1)+
	dbf	d0,.t1
	lea	GS_COLORS+240*3(a6),a0
	lea	f_temp2+240*3,a1
	moveq	#16*3-1,d0
.t2:	move.b	(a0)+,(a1)+
	dbf	d0,.t2
	move.l	al_shrink,a3		; the 24 frames: delay(30), then the scaled rectangle
	add.l	#SH_FRAMES,a3
	move.w	(a3)+,d7
	subq.w	#1,d7
.f:	moveq	#30,d0
	bsr	tim_delay
	movem.w	(a3)+,d0-d3		; y0, rows, offset, longs per row
	move.l	vid_phys,a2
	mulu	#SCR_BPL,d0
	add.l	d0,a2
	add.w	d2,a2
	subq.w	#1,d1
	subq.w	#1,d3
.r:	move.l	a2,a1
	move.w	d3,d0
.c:	move.l	(a3)+,(a1)+
	dbf	d0,.c
	lea	SCR_BPL(a2),a2
	dbf	d1,.r
	dbf	d7,.f
	lea	f_temp2,a0		; set256colors(temppal)
	bsr	vid_set256
	moveq	#0,d0			; loadscreen_data('alien'): the composite with the box
	bsr	vid_set_fade
	lea	fn_aliens,a0
	bsr	load_whole
	move.l	a0,a5
	move.l	vid_phys,a1
	bsr	pic_show
	lea	f_temp2,a0
	bsr	vid_set256
	moveq	#16,d0
	bsr	vid_set_fade
	move.l	a5,a0			; colors := alien's palette
	add.l	#AL_PAL,a0
	lea	GS_COLORS(a6),a1
	move.w	#768/4-1,d0
.p:	move.l	(a0)+,(a1)+
	dbf	d0,.p
	move.l	vid_phys,a0
	bsr	gfx_set_target
	; fadeinalienscreen: 0-31 / 240-255 at once, 32-239 in 24 steps of tslice
	moveq	#1,d7
.fi:	lea	GS_COLORS(a6),a3
	lea	f_temp2,a4
	moveq	#0,d6
.fj:	moveq	#0,d0
	move.b	(a3)+,d0
	cmp.w	#32*3,d6
	blo.s	.fk
	cmp.w	#240*3,d6
	bhs.s	.fk
	mulu	d7,d0
	moveq	#24,d1
	bsr	pas_round
.fk:	move.b	d0,(a4)+
	addq.w	#1,d6
	cmp.w	#768,d6
	bne.s	.fj
	lea	f_temp2,a0
	bsr	vid_set256
	moveq	#TSLICE,d0
	bsr	tim_delay
	addq.w	#1,d7
	cmp.w	#25,d7
	bne.s	.fi
	; alienscreenwait: two dots move 7 steps, one per wall-clock second, then circles
	bsr	tim_ms
	move.l	d0,d5
	moveq	#0,d0			; xor at position 0
	bsr	al_dots
	moveq	#1,d7
.dj:	move.w	d7,d0			; restore j-1 ...
	subq.w	#1,d0
	bset	#15,d0
	bsr	al_dots
	move.w	d7,d0			; ... xor j
	bsr	al_dots
	move.w	d7,d0			; until j s have passed (j..j+1 s in the original)
	mulu	#1000,d0
	add.l	#500,d0
	add.l	d5,d0
	move.l	d0,d4
.dw:	bsr	anykey
	bne	.out
	bsr	tim_ms
	cmp.l	d4,d0
	blo.s	.dw
	addq.w	#1,d7
	cmp.w	#8,d7
	bne.s	.dj
	move.l	a5,a3			; circles
	add.l	#AL_CIRC,a3		; j = 3, 2, 1: colour 175-2j, radius 3j+1
	moveq	#3-1,d7
.ci:	move.w	(a3)+,d6		; colour
	move.w	(a3)+,d5		; points
	subq.w	#1,d5
.cp:	move.b	(a3)+,d3		; dx
	ext.w	d3
	move.b	(a3)+,d4		; dy
	ext.w	d4
	move.w	#176,d0
	add.w	d3,d0
	move.w	#138,d1
	add.w	d4,d1
	move.w	d6,d2
	bsr	gfx_pset
	moveq	#62,d0
	add.w	d3,d0
	move.w	#155,d1
	add.w	d4,d1
	move.w	d6,d2
	bsr	gfx_pset
	dbf	d5,.cp
	move.w	#TSLICE*8,d0
	bsr	tim_delay
	dbf	d7,.ci
	bsr	fading
.out:	move.l	al_mark,d0
	bsr	mem_release
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; al_dots: d0.w = position j (0..7) -> both dots there in their xor colour; bit 15 set:
; their original colour. a5 = ALIENS.DAT
al_dots:
	movem.l	d3-d4/a3,-(sp)
	moveq	#0,d3
	bclr	#15,d0
	sne	d3			; d3 = $ff: original colour
	lsl.w	#3,d0
	move.l	a5,a3
	add.l	#AL_DOTS,a3
	add.w	d0,a3
	moveq	#2-1,d4
.d:	movem.w	(a3),d0-d2		; x, y, colour
	tst.b	d3
	bne.s	.o
	move.w	6(a3),d2		; xor colour
.o:	bsr	gfx_pset
	lea	8*8(a3),a3		; dot 2
	dbf	d4,.d
	movem.l	(sp)+,d3-d4/a3
	rts

; is2 (intro.pas 1617): main3 over the cloud, the small planet, four lit bars that is2wait
; puts out column by column, the text, blast(63,0,0) to red, fading.
; IS2.DAT (tools/mkis2.py): picture (bars lit), main3's palette, rows 35-105 unlit.
IS2_PAL		equ	ISP2_FULL
IS2_BASE	equ	IS2_PAL+768
is2:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	mem_mark
	move.l	d0,-(sp)
	lea	fn_is2,a0
	bsr	load_whole
	move.l	a0,a5
	move.l	a0,-(sp)
	moveq	#0,d0			; hidden while loading (the palette is black)
	bsr	vid_set_fade
	move.l	(sp)+,a0
	move.l	vid_phys,a1
	bsr	pic_show
	bsr	black256
	moveq	#16,d0
	bsr	vid_set_fade
	move.l	a5,a0			; colors := main3's palette
	add.l	#IS2_PAL,a0
	lea	GS_COLORS(a6),a1
	move.w	#768/4-1,d0
.p:	move.l	(a0)+,(a1)+
	dbf	d0,.p
	move.l	vid_phys,a0
	bsr	gfx_set_target
	moveq	#2,d0			; radius 400, c2 1.30; c = random(120), ecl = 50;
	bsr	plan_setup		; makeplanet(0): one frame (c + 1)
	moveq	#120,d0
	bsr	rnd
	addq.w	#1,d0
	moveq	#50,d1
	bsr	plan_frame
	lea	is2_m,a0		; m1..m4
	move.l	#(291<<16)|201,(a0)+
	move.l	#(234<<16)|280,(a0)
	move.l	a5,is2_src
	add.l	#IS2_BASE-35*SCR_BPL,is2_src
	bsr	fadein
	move.w	#26,GS_TCOLOR(a6)
	move.w	#255,GS_BKCOLOR(a6)
	lea	is2_text,a3
	moveq	#13,d0
	move.w	#160,d1
	bsr	is2_print
	move.w	#2000,d0
	bsr	tim_delay
	move.w	#167,d1
	bsr	is2_print
	lea	is2_alts,a4
	moveq	#3-1,d7
.w:	move.l	a4,a0
	bsr	is2wait
	addq.l	#8,a4
	bsr	anykey
	bne.s	.out
	move.w	#1000,d0		; wait(1)
	bsr	tim_delay
	move.w	#174,d1
	cmp.w	#1,d7
	bhi.s	.pr
	move.w	#182,d1
	tst.w	d7
	beq.s	.nb
.pr:	bsr	is2_print
.nb:	dbf	d7,.w
	moveq	#63,d0			; blast(63,0,0)
	moveq	#0,d1
	moveq	#0,d2
	bsr	blast
	bsr	fading
.out:	move.l	(sp)+,d0
	bsr	mem_release
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; is2_print: d1.w = y; prints the next is2 line (a3) at x 13
is2_print:
	moveq	#13,d0
	move.l	a3,a0
	bsr	txt_print
	moveq	#0,d0
	move.b	(a3),d0
	lea	2(a3,d0.w),a3
	move.l	a3,d0
	and.w	#$fffe,d0
	move.l	d0,a3
	rts

; is2wait (intro.pas 1403): a0 -> alt1..alt4 (words). Every tslice*7 each bar with m > 190
; loses columns m+alt..m-1 (copied back unlit), until 1 s has passed by the wall clock
; (2-3 s; 2.5 s here).
is2wait:
	movem.l	d3-d7/a3-a4,-(sp)
	move.l	a0,a4
	bsr	tim_ms
	move.l	d0,d7
.l:	lea	is2_m,a3
	moveq	#35,d6			; bar top row
	moveq	#0,d5
.b:	move.w	(a3),d4			; m
	cmp.w	#190,d4
	ble.s	.n
	move.w	0(a4,d5.w),d0		; alt
	beq.s	.n
	add.w	d4,d0			; x1 = m + alt
	move.w	d0,(a3)
	move.w	d4,d2
	subq.w	#1,d2			; x2 = m - 1
	move.w	d6,d1
	move.w	d6,d3
	add.w	#10,d3
	move.l	is2_src,a0
	bsr	gfx_copy_rect
.n:	addq.l	#2,a3
	add.w	#20,d6
	addq.w	#2,d5
	cmp.w	#8,d5
	bne.s	.b
	move.w	#TSLICE*7,d0
	bsr	tim_delay
	bsr	anykey
	bne.s	.x
	bsr	tim_ms
	sub.l	d7,d0
	cmp.l	#2500,d0
	blo.s	.l
.x:	movem.l	(sp)+,d3-d7/a3-a4
	rts

; blast (intro.pas 494): d0-d2 = target r, g, b. 31 steps:
; colors += round(a * (target - colors) / 31), a = 1..31, delay tslice/2
blast:
	movem.l	d3-d7/a3,-(sp)
	movem.w	d0-d2,bl_rgb
	moveq	#1,d7
.s:	lea	GS_COLORS(a6),a3
	move.w	#256-1,d6
.j:	moveq	#0,d5
.g:	moveq	#0,d3
	move.b	(a3),d3
	lea	bl_rgb,a0
	move.w	0(a0,d5.w),d0
	sub.w	d3,d0
	muls	d7,d0
	moveq	#31,d1
	bsr	sround
	add.b	d0,(a3)+
	addq.w	#2,d5
	cmp.w	#6,d5
	bne.s	.g
	dbf	d6,.j
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	moveq	#TSLICE/2,d0
	bsr	tim_delay
	addq.w	#1,d7
	cmp.w	#32,d7
	bne.s	.s
	movem.l	(sp)+,d3-d7/a3
	rts

; sround: d0.w = signed numerator, d1.w = denominator -> d0.w = round(n/d), halves to even
sround:
	tst.w	d0
	bmi.s	.neg
	ext.l	d0
	bra	pas_round
.neg:	neg.w	d0
	ext.l	d0
	bsr	pas_round
	neg.w	d0
	rts

; final planet (intro.pas 1625): over the cloud again, c = 0, ecl = 190, still inverted
planet3:
	bsr	loadmainpalette
	lea	fn_pln3,a0
	bsr	planet_scene
	moveq	#0,d0
	bsr	plan_setup
	clr.w	pl_c
	move.w	#190,pl_ecl
	moveq	#0,d0
	moveq	#0,d1
	bsr	makeplanet
	move.w	#22,GS_TCOLOR(a6)
	move.w	#255,GS_BKCOLOR(a6)
	lea	text3,a0
	bsr	bigtext
	bsr	fadein
	moveq	#12,d0
	moveq	#0,d1
	bsr	makeplanet
	bra	fading

; #1.4 (intro.pas 1517): the planet over the cloud, text, a 12 s eclipse turn
planet1:
	bsr	loadmainpalette
	lea	fn_pln1,a0
	bsr	planet_scene
	moveq	#0,d0
	bsr	plan_setup
	moveq	#0,d0
	moveq	#0,d1
	bsr	makeplanet
	move.w	#22,GS_TCOLOR(a6)
	move.w	#255,GS_BKCOLOR(a6)
	lea	text1,a0
	bsr	bigtext
	bsr	fadein
	moveq	#12,d0
	moveq	#1,d1
	bsr	makeplanet
	bra	fading
fatal:	moveq	#4,d0
	bra	sys_exit

	include	"kernel.s"
	include	"planet.s"

	section	data
fn_script:	dc.b	"INPUT.INT",0
fn_is2:		dc.b	"DATA",92,"IS2.DAT",0
	even
is2_alts:	dc.w	-1,0,0,-2, -3,0,-1,-1, -1,-1,0,0
is2_text:
	dc.b	23,"Enemy Closing Rapidly.."
	even
	dc.b	20,"Shields Imploding..."
	even
	dc.b	21,"Destruction Imminent."
	even
	dc.b	25,"Attempting Crash Landing."
	even
text3:
	dc.w	159
	dc.b	35,"They threaten to devour all life in"
	even
	dc.w	167
	dc.b	40,"their path...your only hope of defeating"
	even
	dc.w	175
	dc.b	40,"the Scavengers is to reunite the Kendar,"
	even
	dc.w	183
	dc.b	34,"an ancient alliance among the free"
	even
	dc.w	191
	dc.b	7,"worlds."
	even
	dc.w	-1
fn_shrink:	dc.b	"DATA",92,"SHRINK.DAT",0
fn_aliens:	dc.b	"DATA",92,"ALIENS.DAT",0
	even
text2:
	dc.w	175
	dc.b	37,"As captain, you awaken along with the"
	even
	dc.w	183
	dc.b	38,"crew some thousand years later and are"
	even
	dc.w	191
	dc.b	31,"confronted by an alien horde..."
	even
	dc.w	-1
orders:
	dc.w	125
	dc.b	29,"Orders: Approach and Destroy."
	even
	dc.w	135
	dc.b	22,"Jamming all Emissions."
	even
	dc.w	145
	dc.b	12,"Targeting..."
	even
	dc.w	155
	dc.b	21,"Locked and Loading..."
	even
	dc.w	165
	dc.b	19,"Closing for Fire..."
	even
	dc.w	-1
fn_charcom:	dc.b	"DATA",92,"CHARCOM.ISP",0
	even
cc_text:
	dc.w	20,153
	dc.b	29,"Ship IRONSEED to Relay Point:"
	even
	dc.w	170,153
	dc.b	17,"Link Established."
	even
	dc.w	20,159
	dc.b	26,"Receiving Encode Variants."
	even
	dc.w	20,165
	dc.b	22,"Wiping Source Encodes."
	even
	dc.w	20,171
	dc.b	25,"Terminating Transmission."
	even
	dc.w	20,177
	dc.b	53,"Control Protocol Transferred to Human Encode ",34,"PRIME",34,"."
	even
	dc.w	-1
fn_pln1:	dc.b	"DATA",92,"PLN1.ISP",0
fn_pln2:	dc.b	"DATA",92,"PLN2.ISP",0
fn_pln2pal:	dc.b	"DATA",92,"PLN2.PAL",0
fn_pln3:	dc.b	"DATA",92,"PLN3.ISP",0
	even
text1:	dc.w	159
	dc.b	35,"Escaping the iron fist of a fanatic"
	even
	dc.w	167
	dc.b	38,"theocracy, the members of the Ironseed"
	even
	dc.w	175
	dc.b	38,"Movement launch into space and are set"
	even
	dc.w	183
	dc.b	33,"adrift after suffering a computer"
	even
	dc.w	191
	dc.b	12,"malfunction."
	even
	dc.w	-1
fn_title:	dc.b	"DATA",92,"TITLE.DAT",0
fn_credpal:	dc.b	"DATA",92,"CREDITS.ISL",0
fn_icon:	dc.b	"DATA",92,"WEAPICON.DTA",0
fn_intro2:	dc.b	"SOUND",92,"INTRO2.MOD",0
fn_intro1:	dc.b	"SOUND",92,"INTRO1.MOD",0
fn_c7:		dc.b	"DATA",92,"C7.ISP",0
fn_mars:	dc.b	"DATA",92,"MARS.DAT",0
fn_mainpal:	dc.b	"DATA",92,"MAIN.PAL",0
fn_mainpalisl:	dc.b	"DATA",92,"MAINPAL.ISL",0
ws_a:		dc.b	1,"A"
ws_b:		dc.b	16,"Destiny: Virtual"
ws_c:		dc.b	13,"Designed Game"
s_mars:		dc.b	4,"Mars"
s_year:		dc.b	9,"3784 A.D."
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
c7_j:		ds.w	1
mrs_data:	ds.l	1
mrs_lines:	ds.w	5
ws_str:		ds.l	3
pl_c:		ds.w	1
pl_ecl:		ds.w	1
bp_n:		ds.w	1
cc_data:	ds.l	1
cc_lights:	ds.l	1
cc_nfr:		ds.w	1
pu_t0:		ds.l	1
al_mark:	ds.l	1
scene_mark:	ds.l	1
is2_src:	ds.l	1
is2_m:		ds.w	4
bl_rgb:		ds.w	3
al_shrink:	ds.l	1
f_temp2:	ds.b	768
ws_j:		ds.w	3
f_temp:		ds.b	768
f_px:		ds.b	768
f_pdx:		ds.b	768
f_dx:		ds.b	768
c7_temppal:	ds.b	768
cursor_icon:	ds.b	256
cursor_rec:	ds.w	1
c7_data:	ds.l	1
	even
