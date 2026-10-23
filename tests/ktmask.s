; ktmask.s - txt_mask/txt_mdraw against txt_print (flat, transparent): the same strings at
; many x/y (all 16 shifts, across the band split at 104, up to the right edge), both fonts,
; drawn over MAIN.ISP into two screens; writes C:\KTMASK.TXT "ok" or "bad" + the timings.
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"

	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	lea	fn_pic,a0
	move.l	vid_scr,a1
	bsr	pic_load
	bcs	.fail
	lea	fn_pic,a0
	move.l	vid_scr+4,a1
	bsr	pic_load
	bcs	.fail
	moveq	#1,d0
	bsr	txt_set_flat
	move.w	#255,GS_BKCOLOR(a6)
	; --- reference: txt_print into screen 0
	move.l	vid_scr,a0
	bsr	gfx_set_target
	bsr	tim_ticks
	move.l	d0,t_ref
	moveq	#0,d6
	bsr	cases
	bsr	tim_ticks
	sub.l	t_ref,d0
	move.l	d0,t_ref
	; --- txt_mdraw into screen 1
	move.l	vid_scr+4,a0
	bsr	gfx_set_target
	bsr	tim_ticks
	move.l	d0,t_new
	moveq	#1,d6
	bsr	cases
	bsr	tim_ticks
	sub.l	t_new,d0
	move.l	d0,t_new
	; --- compare
	move.l	vid_scr,a0
	move.l	vid_scr+4,a1
	move.w	#SCR_SIZE/2-1,d0
	moveq	#0,d1
.c:	cmpm.w	(a0)+,(a1)+
	beq.s	.s
	addq.w	#1,d1
.s:	dbf	d0,.c
	lea	res,a1
	move.l	#'ok  ',(a1)
	tst.w	d1
	beq.s	.w
	move.l	#'bad ',(a1)
.w:	move.l	t_ref,4(a1)		; 200 Hz ticks: txt_print, txt_mdraw
	move.l	t_new,8(a1)
	move.w	d1,12(a1)
	lea	fn_res,a0
	moveq	#14,d0
	bsr	fil_save
	lea	fn_scr,a0		; the mask version, for a look
	move.l	vid_scr+4,a1
	move.l	#SCR_SIZE,d0
	bsr	fil_save
	lea	fn_ref,a0
	move.l	vid_scr,a1
	move.l	#SCR_SIZE,d0
	bsr	fil_save
	moveq	#0,d0
	bra	sys_exit
.fail:	moveq	#1,d0
	bra	sys_exit

; all cases; d6 = 0: txt_print, 1: txt_mask + txt_mdraw
cases:
	lea	txt_font_intro,a0
	bsr	txt_set_font
	lea	tab,a3
.n:	move.w	(a3)+,d3		; x (-1 = font switch, -2 = end)
	cmp.w	#-2,d3
	beq.s	.x
	cmp.w	#-1,d3
	bne.s	.go
	sub.l	a0,a0			; the game font
	bsr	txt_set_font
	bra.s	.n
.go:	move.w	(a3)+,d4		; y
	move.w	(a3)+,d5		; colour
	move.w	(a3)+,d7		; string number
	lea	strs,a4
	bra.s	.f
.sk:	moveq	#0,d0
	move.b	(a4),d0
	lea	1(a4,d0.w),a4
.f:	dbf	d7,.sk
	tst.w	d6
	bne.s	.m
	move.w	d5,GS_TCOLOR(a6)
	move.w	d3,d0
	move.w	d4,d1
	move.l	a4,a0
	bsr	txt_print
	bra.s	.n
.m:	move.l	a4,a0
	bsr	txt_mask
	move.w	d3,d0
	move.w	d4,d1
	move.w	d5,d2
	bsr	txt_mdraw
	bra.s	.n
.x:	rts

	include	"kernel.s"

	section	data
fn_pic:	dc.b	"C:\MAIN.ISP",0
fn_res:	dc.b	"C:\KTMASK.TXT",0
fn_scr:	dc.b	"C:\KTMASK.BIN",0
fn_ref:	dc.b	"C:\KTREF.BIN",0
strs:	dc.b	24,"Nuke Bloodaxe M68K Ports"
	dc.b	42,1,2,"Nuke Bloodaxe 2026 M68K Port (Atari STE)"
	dc.b	53,"ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz"
	dc.b	34,"0123456789 !",34,"'()*+,-./:;<=>?%#&@[]"
	dc.b	1,"W"
	dc.b	0
	even
; x, y, colour, string
tab:	dc.w	0,2,31,0, 1,10,30,1, 2,18,22,2, 3,26,5,3, 4,34,31,4, 5,42,63,0
	dc.w	6,50,1,1, 7,58,15,2, 8,66,200,3, 9,74,31,0, 10,82,47,1, 11,90,31,2
	dc.w	12,98,63,3, 13,101,31,0, 14,103,16,1, 15,106,31,2, 16,114,31,5
	dc.w	57,122,31,0, 189,130,31,0, 300,138,31,4, 310,146,22,4, 50,192,31,1
	dc.w	-1
	dc.w	3,154,31,2, 17,162,47,3, 99,170,63,0, 158,178,31,0, 0,186,12,2
	dc.w	-2

	section	bss
t_ref:	ds.l	1
t_new:	ds.l	1
res:	ds.b	16
