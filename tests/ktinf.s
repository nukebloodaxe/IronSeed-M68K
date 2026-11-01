; ktinf.s - the inflate test (Phase 8): C:\INF.PK = long unpacked size + raw deflate data
; (tools/mkfloppy.py's packing) -> C:\INF.OUT (the output) and C:\INF.TIM (long: frames taken).
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"

	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	lea	fn_in,a0
	bsr	fil_size
	bcs	.fail
	move.l	d0,d6
	bsr	mem_alloc
	bcs	.fail
	move.l	a0,a5
	lea	fn_in,a0
	move.l	a5,a1
	move.l	d6,d0
	bsr	fil_load
	bcs	.fail
	move.l	(a5),d7			; unpacked size
	move.l	d7,d0
	bsr	mem_alloc
	bcs	.fail
	move.l	a0,a4
	move.l	vid_frames,d5
	lea	4(a5),a0
	move.l	a4,a1
	bsr	inf_inflate
	bcs	.fail
	move.l	vid_frames,d0
	sub.l	d5,d0
	move.l	d0,tim
	sub.l	a4,a1			; bytes made
	move.l	a1,made
	lea	fn_out,a0
	move.l	a4,a1
	move.l	made,d0
	bsr	fil_save
	lea	fn_tim,a0
	lea	tim,a1
	moveq	#8,d0
	bsr	fil_save
.fail:	bra	sys_exit

	include	"kernel.s"

	section	data
fn_in:	dc.b	"C:\INF.PK",0
fn_out:	dc.b	"C:\INF.OUT",0
fn_tim:	dc.b	"C:\INF.TIM",0
	even
	section	bss
tim:	ds.l	1
made:	ds.l	1
