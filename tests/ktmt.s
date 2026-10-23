; ktmt.s - mt.s against Free Pascal's random: seed 1994, then random(64000) x 5, random(7) x 700,
; random(1000) x 3, and 2000 x mt_u32 (crosses several state updates). Writes C:\KTMT.BIN
; (big-endian longs) for tests/check_mt.py.
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"

	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	move.l	#1994,d0
	bsr	mt_seed
	lea	out,a3
	moveq	#5-1,d3
.a:	move.w	#64000,d0
	bsr	mt_random
	move.l	d0,(a3)+
	dbf	d3,.a
	move.w	#700-1,d3
.b:	moveq	#7,d0
	bsr	mt_random
	move.l	d0,(a3)+
	dbf	d3,.b
	moveq	#3-1,d3
.c:	move.w	#1000,d0
	bsr	mt_random
	move.l	d0,(a3)+
	dbf	d3,.c
	move.w	#2000-1,d3
.d:	bsr	mt_u32
	move.l	d0,(a3)+
	dbf	d3,.d
	lea	fn,a0
	lea	out,a1
	move.l	a3,d0
	sub.l	a1,d0
	bsr	fil_save
	moveq	#0,d0
	bra	sys_exit

	include	"kernel.s"

	section	data
fn:	dc.b	"C:\KTMT.BIN",0
	even
	section	bss
out:	ds.l	5+700+3+2000
