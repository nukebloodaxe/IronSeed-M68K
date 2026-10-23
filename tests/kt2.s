; kt2.s - kernel test 2: picture with 4 bands, text, primitives, cursor.
; Writes C:\KT2SCR.BIN (the screen) for checking against tools/ref_kt2.py.
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"

	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	lea	fn_pic,a0
	move.l	vid_phys,a1
	bsr	pic_load
	bcs	.fail

	move.w	#31,GS_TCOLOR(a6)	; shaded text, transparent background
	move.w	#255,GS_BKCOLOR(a6)
	move.w	#20,d0
	move.w	#30,d1
	lea	s1,a0
	bsr	txt_print
	move.w	#63,GS_TCOLOR(a6)	; on a background colour
	move.w	#0,GS_BKCOLOR(a6)
	move.w	#20,d0
	move.w	#40,d1
	lea	s2,a0
	bsr	txt_print
	move.w	#47,GS_TCOLOR(a6)
	move.w	#255,GS_BKCOLOR(a6)
	move.w	#13,d0			; crosses 16-pixel groups and the band at 104
	move.w	#100,d1
	lea	s3,a0
	bsr	txt_print

	move.w	#200,d0			; bar
	move.w	#20,d1
	move.w	#250,d2
	move.w	#60,d3
	move.b	#44,d4
	bsr	gfx_bar
	move.w	#190,d0			; rectangle round it
	move.w	#15,d1
	move.w	#260,d2
	move.w	#65,d3
	move.b	#63,d4
	bsr	gfx_rect
	move.w	#30,d0			; diagonal line across a split
	move.w	#60,d1
	move.w	#170,d2
	move.w	#150,d3
	move.b	#31,d4
	bsr	gfx_line
	move.w	#5,d0			; single pixels
	move.w	#5,d1
	move.b	#63,d2
	bsr	gfx_pset
	move.w	#318,d0
	move.w	#197,d1
	move.b	#63,d2
	bsr	gfx_pset

	lea	fn_scr,a0
	move.l	vid_phys,a1
	move.l	#SCR_SIZE,d0
	bsr	fil_save
	move.w	#250,d0			; drawing is done: now show the cursor
	move.w	#120,d1
	bsr	kbd_mouse_move
	bsr	kbd_cursor_show
	move.w	#3000,d0
	bsr	tim_delay
	moveq	#0,d0
	bra	sys_exit
.fail:	moveq	#1,d0
	bra	sys_exit

	include	"kernel.s"

	section	data
fn_pic:	dc.b	"C:\MAIN.ISP",0
fn_scr:	dc.b	"C:\KT2SCR.BIN",0
s1:	dc.b	s1e-s1-1,"IRON SEED on the STE: 64 colours!"
s1e:
s2:	dc.b	s2e-s2-1,"Text on a background (bkcolor 0)"
s2e:
s3:	dc.b	s3e-s3-1,"Crossing the band split at line 104?"
s3e:
	even
