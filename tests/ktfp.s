; ktfp.s - kernel fp.s against Free Pascal (tools/fp/fpref): reads C:\FPIN.BIN (32-byte records:
; op.w, w.w, d.w, pad.w, a: 12 bytes (double, or extended se.w hi.l lo.l), b: 12 bytes), writes a
; 16-byte result per record to C:\FPOUT.BIN. tests/fptest.py makes the cases and compares.
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"

	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	lea	fn_in,a0
	lea	inbuf,a1
	move.l	#MAXREC*32,d0
	bsr	fil_load
	bcs	.x
	lsr.l	#5,d0
	move.w	d0,d7			; records
	lea	inbuf,a3
	lea	outbuf,a4
	bra	.n
.l:	moveq	#4-1,d0			; clear the result
	move.l	a4,a0
.c:	clr.l	(a0)+
	dbf	d0,.c
	move.w	(a3),d6			; op
	FSSE
	cmp.w	#5,d6
	blo	.sse
	cmp.w	#10,d6
	blo	.x87
	cmp.w	#10,d6
	bne.s	.o11
	lea	8(a3),a0		; ext -> double
	bsr	fp_ldx
	move.l	a4,a0
	bsr	fp_std
	bra	.nx
.o11:	cmp.w	#13,d6
	bhi.s	.o14
	beq.s	.o13
	lea	8(a3),a0
	bsr	fp_ldd
	cmp.w	#11,d6
	bne.s	.o12
	bsr	fp_rnd
	move.l	d0,(a4)
	bra	.nx
.o12:	bsr	fp_trunc
	move.l	d0,(a4)
	bra	.nx
.o13:	FX87
	lea	8(a3),a0
	bsr	fp_ldx
	bsr	fp_rnd
	move.l	d0,(a4)
	bra	.nx
.o14:	cmp.w	#17,d6
	bhs.s	.o17
	lea	8(a3),a0
	bsr	fp_ldd
	bsr	.trans
	move.l	a4,a0
	bsr	fp_std
	bra	.nx
.o17:	bne.s	.o18
	lea	8(a3),a0
	bsr	fp_ldd
	move.w	2(a3),d0
	move.w	4(a3),d1
	move.l	a4,a0
	bsr	fp_str
	bra	.nx
.o18:	cmp.w	#18,d6
	bne.s	.o19
	move.l	8(a3),d0
	bsr	fp_ldi
	move.l	a4,a0
	bsr	fp_std
	bra	.nx
.o19:	cmp.w	#19,d6
	bne.s	.o20
	lea	8(a3),a0
	bsr	fp_ldd
	lea	20(a3),a0
	bsr	fp_ldd
	bsr	fp_cmp
	move.b	d0,(a4)
	bra	.nx
.o20:	lea	8(a3),a0		; 20-22: extended sin/cos/atan
	bsr	fp_ldx
	subq.w	#6,d6
	bsr	.trans
	move.l	a4,a0
	bsr	fp_stx
	bra	.nx
.trans:	cmp.w	#14,d6
	beq	fp_sin
	cmp.w	#15,d6
	beq	fp_cos
	bra	fp_atan
.sse:	lea	8(a3),a0
	bsr	fp_ldd
	cmp.w	#4,d6
	beq.s	.s4
	lea	20(a3),a0
	bsr	fp_ldd
.s4:	bsr	.arith
	move.l	a4,a0
	bsr	fp_std
	bra.s	.nx
.x87:	FX87
	lea	8(a3),a0
	bsr	fp_ldx
	subq.w	#5,d6
	cmp.w	#4,d6
	beq.s	.x4
	lea	20(a3),a0
	bsr	fp_ldx
.x4:	bsr	.arith
	move.l	a4,a0
	bsr	fp_stx
	bra.s	.nx
.arith:	tst.w	d6
	beq	fp_add
	cmp.w	#1,d6
	beq	fp_sub
	cmp.w	#2,d6
	beq	fp_mul
	cmp.w	#3,d6
	beq	fp_div
	bra	fp_sqrt
.nx:	lea	32(a3),a3
	lea	16(a4),a4
.n:	dbf	d7,.l
	lea	fn_out,a0
	lea	outbuf,a1
	move.l	a4,d0
	sub.l	a1,d0
	bsr	fil_save
.x:	moveq	#0,d0
	bra	sys_exit

	include	"kernel.s"
	include	"fp.s"

MAXREC	equ	12000
	section	data
fn_in:	dc.b	"C:\FPIN.BIN",0
fn_out:	dc.b	"C:\FPOUT.BIN",0
	even
	section	bss
inbuf:	ds.b	MAXREC*32
outbuf:	ds.b	MAXREC*16
