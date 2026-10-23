; demo.s - Phase 1 kernel demo: the bridge screen in 64 colours, fade in, the game's own
; mouse cursor, music (GAME.MOD), a line of text; any key fades out and quits.
; Needs MAIN.ISP, GAME.MOD and WEAPICON.DTA (converted) in the program's folder.
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"

	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	moveq	#0,d0
	bsr	vid_set_fade
	lea	fn_pic,a0
	move.l	vid_phys,a1
	bsr	pic_load
	bcs	.fail
	moveq	#0,d0			; pic_load set the bands at full brightness: back to black
	bsr	vid_set_fade

	; the game's default cursor: weapicon.dta record 87, top-left 16x16 of 20x20
	lea	fn_icon,a0
	bsr	fil_size
	bcs.s	.nocur
	move.l	d0,d6
	bsr	mem_alloc
	bcs.s	.nocur
	move.l	a0,a5
	lea	fn_icon,a0
	move.l	a5,a1
	move.l	d6,d0
	bsr	fil_load
	bcs.s	.nocur
	move.l	a5,a0
	add.l	#87*400,a0
	lea	cursor,a1
	moveq	#16-1,d1
.cr:	moveq	#16-1,d0
.cc:	move.b	(a0)+,(a1)+
	dbf	d0,.cc
	addq.l	#4,a0
	dbf	d1,.cr
	lea	cursor,a0
	bsr	kbd_cursor_set
.nocur:
	move.w	#31,GS_TCOLOR(a6)
	move.w	#255,GS_BKCOLOR(a6)
	move.w	#18,d0
	move.w	#20,d1
	lea	txt1,a0
	bsr	txt_print
	move.w	#18,d0
	move.w	#30,d1
	lea	txt2,a0
	bsr	txt_print

	lea	fn_mod,a0		; music
	bsr	fil_size
	bcs.s	.nomus
	move.l	d0,d6
	bsr	mem_alloc
	bcs.s	.nomus
	move.l	a0,a5
	lea	fn_mod,a0
	move.l	a5,a1
	move.l	d6,d0
	bsr	fil_load
	bcs.s	.nomus
	move.l	a5,a0
	bsr	mod_init
	bcs.s	.nomus
	bsr	mod_start
.nomus:
	moveq	#1,d3			; fade in
.fi:	move.w	d3,d0
	bsr	vid_set_fade
	bsr	vid_vsync
	bsr	vid_vsync
	addq.w	#1,d3
	cmp.w	#17,d3
	bne.s	.fi
	bsr	kbd_cursor_show

.wait:	bsr	kbd_keypressed		; any key or a click ends the demo
	tst.b	d0
	bne.s	.end
	bsr	kbd_mouse_status
	tst.b	d0
	bne.s	.end
	bsr	vid_vsync
	bra.s	.wait
.end:	bsr	kbd_keypressed
	tst.b	d0
	beq.s	.out
	bsr	kbd_readkey
.out:	bsr	kbd_cursor_hide
	moveq	#16,d3			; fade out
.fo:	move.w	d3,d0
	bsr	vid_set_fade
	bsr	vid_vsync
	bsr	vid_vsync
	subq.w	#1,d3
	bpl.s	.fo
	bsr	mod_stop
	moveq	#0,d0
	bra	sys_exit
.fail:	moveq	#1,d0
	bra	sys_exit

	include	"kernel.s"

	section	data
fn_pic:		dc.b	"MAIN.ISP",0
fn_mod:		dc.b	"GAME.MOD",0
fn_icon:	dc.b	"WEAPICON.DTA",0
txt1:		dc.b	txt1e-txt1-1,"IRON SEED kernel demo - Atari STE, 64 colours"
txt1e:
txt2:		dc.b	txt2e-txt2-1,"Press a key or click to quit."
txt2e:
	even
	section	bss
cursor:		ds.b	256
