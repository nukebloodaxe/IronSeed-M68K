; kt1.s - kernel test 1: init/exit, 4 colour bands, fade, planar drawing, mouse cursor.
; Writes C:\KT1.TXT ("ok" + frame count) before exiting by itself after ~4 s.
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"

	section	text
start:	move.l	4(sp),a0
	bsr	sys_init

	; 16 vertical bars on both screens
	move.l	vid_scr,a1
	bsr	bars
	move.l	vid_scr+4,a1
	bsr	bars
	move.l	vid_scr+8,a1
	bsr	bars
	lea	bands,a0
	bsr	vid_set_bands
	moveq	#0,d0
	bsr	vid_set_fade
	bsr	kbd_cursor_show

	; fade in over 16 frames
	moveq	#0,d3
.fade:	move.w	d3,d0
	bsr	vid_set_fade
	bsr	vid_vsync
	addq.w	#1,d3
	cmp.w	#17,d3
	bne.s	.fade

	; walk the cursor across the screen (no real mouse in the headless test)
	moveq	#0,d3
.walk:	move.w	d3,d0
	mulu	#3,d0
	move.w	d3,d1
	mulu	#2,d1
	bsr	kbd_mouse_move
	bsr	vid_vsync
	addq.w	#1,d3
	cmp.w	#100,d3
	bne.s	.walk
	move.w	#200,d0			; park it on a band edge (line 50)
	moveq	#45,d1
	bsr	kbd_mouse_move
	move.w	#2000,d0
	bsr	tim_delay

	lea	fn,a0
	lea	msg,a1
	moveq	#msg_end-msg,d0
	bsr	fil_save
	moveq	#0,d0
	bra	sys_exit

bars:	move.w	#200-1,d1
.l:	lea	barline,a0
	moveq	#160/4-1,d0
.c:	move.l	(a0)+,(a1)+
	dbf	d0,.c
	dbf	d1,.l
	rts

	include	"kernel.s"

	section	data
bands:	dc.w	4
	dc.w	0
	STECOL	0,0,0
	STECOL	1,0,0
	STECOL	2,0,0
	STECOL	3,0,0
	STECOL	4,0,0
	STECOL	5,0,0
	STECOL	6,0,0
	STECOL	7,0,0
	STECOL	8,0,0
	STECOL	9,0,0
	STECOL	10,0,0
	STECOL	11,0,0
	STECOL	12,0,0
	STECOL	13,0,0
	STECOL	14,0,0
	STECOL	15,15,15
	dc.w	50
	STECOL	0,0,0
	STECOL	0,1,0
	STECOL	0,2,0
	STECOL	0,3,0
	STECOL	0,4,0
	STECOL	0,5,0
	STECOL	0,6,0
	STECOL	0,7,0
	STECOL	0,8,0
	STECOL	0,9,0
	STECOL	0,10,0
	STECOL	0,11,0
	STECOL	0,12,0
	STECOL	0,13,0
	STECOL	0,14,0
	STECOL	15,15,15
	dc.w	100
	STECOL	0,0,0
	STECOL	0,0,1
	STECOL	0,0,2
	STECOL	0,0,3
	STECOL	0,0,4
	STECOL	0,0,5
	STECOL	0,0,6
	STECOL	0,0,7
	STECOL	0,0,8
	STECOL	0,0,9
	STECOL	0,0,10
	STECOL	0,0,11
	STECOL	0,0,12
	STECOL	0,0,13
	STECOL	0,0,14
	STECOL	15,15,15
	dc.w	150
	STECOL	0,0,0
	STECOL	1,1,1
	STECOL	2,2,2
	STECOL	3,3,3
	STECOL	4,4,4
	STECOL	5,5,5
	STECOL	6,6,6
	STECOL	7,7,7
	STECOL	8,8,8
	STECOL	9,9,9
	STECOL	10,10,10
	STECOL	11,11,11
	STECOL	12,12,12
	STECOL	13,13,13
	STECOL	14,14,14
	STECOL	15,15,15
barline:
	include	"split_bars.i"
fn:	dc.b	"C:\KT1.TXT",0
msg:	dc.b	"ok",13,10
msg_end:
	even
