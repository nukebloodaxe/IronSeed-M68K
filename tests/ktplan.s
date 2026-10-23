; ktplan.s - planet renderer test: known (c, ecl) frames on PLN1 (geometry 0) and PLN2
; (geometry 1, inverted land), each screen saved as C:\PLANn.BIN for tests/check_plan.py.
; Also times 20 frames of geometry 0 (C:\PLANT.BIN: 200 Hz ticks).
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"
	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	bsr	plan_load
	bcs	.fail
	lea	fn_p1,a0
	move.l	vid_phys,a1
	bsr	pic_load
	bcs	.fail
	move.l	vid_phys,a0
	bsr	gfx_set_target
	moveq	#0,d0
	bsr	plan_setup
	lea	frames1,a3
	lea	fn_out,a4
	moveq	#3-1,d7
.f1:	move.w	(a3)+,d0
	move.w	(a3)+,d1
	bsr	plan_frame
	bsr	save_shot
	dbf	d7,.f1
	move.l	HZ200.w,d6		; timing: 20 frames
	moveq	#20-1,d7
.t:	move.w	d7,d0
	addq.w	#1,d0
	move.w	#200,d1
	bsr	plan_frame
	dbf	d7,.t
	move.l	HZ200.w,d0
	sub.l	d6,d0
	move.l	d0,tres
	lea	fn_t,a0
	lea	tres,a1
	moveq	#4,d0
	bsr	fil_save
	lea	fn_p2,a0
	move.l	vid_phys,a1
	bsr	pic_load
	bcs	.fail
	bsr	plan_invert
	moveq	#1,d0
	bsr	plan_setup
	move.w	#50,d0
	move.w	#105,d1
	bsr	plan_frame
	bsr	save_shot
	moveq	#0,d0
	bra	sys_exit
.fail:	moveq	#1,d0
	bra	sys_exit

save_shot:				; a4 -> name (incremented digit)
	move.l	a4,a0
	move.l	vid_phys,a1
	move.l	#SCR_SIZE,d0
	bsr	fil_save
	addq.b	#1,7(a4)		; C:\PLAN0 -> PLAN1 ...
	rts

	include	"kernel.s"
	include	"planet.s"
	section	data
frames1:	dc.w	1,180, 100,250, 200,120
fn_p1:		dc.b	"DATA",92,"PLN1.ISP",0
fn_p2:		dc.b	"DATA",92,"PLN2.ISP",0
fn_out:		dc.b	"C:",92,"PLAN0.BIN",0
fn_t:		dc.b	"C:",92,"PLANT.BIN",0
	even
	section	bss
tres:	ds.l	1
