; fp.s - software floating point that reproduces the Linux oracle's arithmetic (Free Pascal 3.2 on
; x86-64): `real` = IEEE double; expressions on doubles are evaluated with SSE (each operation
; correctly rounded to 53 bits), expressions that involve an extended constant (a literal that is
; not exact in double, e.g. 0.66, 0.049) or sin/cos/arctan run on the x87 (each operation rounded to
; 64 bits, the result rounded again to 53 bits when stored to a real). Include after the kernel.
;
; Model: a stack of 80-bit numbers (x87 layout: sign/exponent word, bias 16383, 64-bit mantissa
; with explicit integer bit; zero = exponent 0 and mantissa 0), 12-byte slots. Every operation
; rounds its exact result once, to 53 bits (fp_mode 0: SSE) or 64 bits (fp_mode 1: x87),
; round-to-nearest-even. No infinities, NaNs or denormals (the game's values are moderate).
; Check FPC's code for an expression (fpc -a) when it is not obvious which unit computes it.
;
; Stack (st0 = top, st1 below it); all routines trash d0-d2/a0-a2 only.
; fp_ldd   a0 = double*: push            fp_ldx  a0 = 10-byte extended (se.w, hi.l, lo.l): push
; fp_ldi   d0.l: push the integer        fp_ldw  d0.w (signed): push
; fp_std   a0 = double*: pop st0, rounded to 53 bits (x87 fstp / SSE movsd)
; fp_stx   a0 = 12-byte slot: pop st0 unchanged
; fp_add / fp_sub (st1-st0) / fp_subr (st0-st1) / fp_mul / fp_div (st1/st0) / fp_divr (st0/st1):
;          pop two, push the result
; fp_neg, fp_abs, fp_sqrt (SSE sqrtsd / x87 fsqrt by mode), fp_sqr (st0*st0)
; fp_dup, fp_swap, fp_pop
; fp_rnd   pop st0, out d0.l = round(st0) (banker's: cvtsd2si / fistp)
; fp_trunc pop st0, out d0.l = trunc(st0)
; fp_cmp   pop st0 and st1, out d0.w = -1 / 0 / 1 for st1 < = > st0 (flags set from d0.w)
; fp_tst   pop st0, out d0.w = -1 / 0 / 1 (flags set)
; fp_sin, fp_cos, fp_atan  st0 := f(st0), computed at 64 bits (the x87's fsin/fcos/fpatan)
; fp_str   pop st0, in d0.w width, d1.w decimals, a0 = Pascal string: FPC's str(r:w:d)
;          (rounded half away from zero on the shortest decimal form, as FPC does)
; fp_mode  (word) 0 = SSE (53 bits), 1 = x87 (64 bits); macros FSSE / FX87 set it.

FP_SLOT		equ	12
FP_BIAS		equ	16383


	section	text
; ---------------------------------------------------------------- stack access
fpi_top:				; a0 = st0 slot
	move.l	fp_sp,a0
	rts
fpi_pop:				; d0.w/d1/d2 := st0, pop    (trashes a0)
	move.l	fp_sp,a0
	move.w	(a0),d0
	move.l	2(a0),d1
	move.l	6(a0),d2
	lea	-FP_SLOT(a0),a0
	move.l	a0,fp_sp
	rts
fpi_push:				; push d0.w/d1/d2           (trashes a0)
	move.l	fp_sp,a0
	lea	FP_SLOT(a0),a0
	move.l	a0,fp_sp
	move.w	d0,(a0)
	move.l	d1,2(a0)
	move.l	d2,6(a0)
	rts
fpi_pop2:				; B (d3-d5) := st0, A (d0-d2) := st1, pop both
	move.l	fp_sp,a0
	move.w	(a0),d3
	move.l	2(a0),d4
	move.l	6(a0),d5
	move.w	-FP_SLOT(a0),d0
	move.l	-FP_SLOT+2(a0),d1
	move.l	-FP_SLOT+6(a0),d2
	lea	-2*FP_SLOT(a0),a0
	move.l	a0,fp_sp
	rts

; ---------------------------------------------------------------- loads and stores
fp_ldd:
	movem.l	d3,-(sp)
	move.l	(a0),d3			; hi
	move.l	4(a0),d2		; lo
	move.l	d3,d0
	swap	d0
	lsr.w	#4,d0
	and.w	#$7ff,d0		; double exponent
	bne.s	.nz
	moveq	#0,d0			; zero (and denormals)
	moveq	#0,d1
	moveq	#0,d2
	bra.s	.p
.nz:	add.w	#FP_BIAS-1023,d0
	tst.l	d3
	bpl.s	.ps
	or.w	#$8000,d0
.ps:	move.l	d3,d1			; mantissa: 1 . 20 bits of hi . 32 bits of lo, << 11
	and.l	#$fffff,d1
	or.l	#$100000,d1
	moveq	#11,d3
	lsl.l	d3,d1
	move.l	d2,d3
	swap	d3			; lo >> 21
	lsr.w	#5,d3
	and.l	#$7ff,d3
	or.l	d3,d1
	moveq	#11,d3
	lsl.l	d3,d2
.p:	bsr	fpi_push
	movem.l	(sp)+,d3
	rts

fp_ldx:
	move.w	(a0),d0
	move.l	2(a0),d1
	move.l	6(a0),d2
	bra	fpi_push

fp_ldw:
	ext.l	d0
fp_ldi:
	bsr.s	fpi_int
	bra	fpi_push
fpi_int:				; d0.l -> d0.w/d1/d2
	move.l	d0,d1
	moveq	#0,d2
	moveq	#0,d0
	tst.l	d1
	beq.s	.x
	move.w	#FP_BIAS+31,d0
	tst.l	d1
	bpl.s	.n
	neg.l	d1
	or.w	#$8000,d0
.n:	tst.l	d1			; normalise (16, 8, then single bits)
	bmi.s	.x
	cmp.l	#$ffff,d1
	bhi.s	.b8
	swap	d1
	sub.w	#16,d0
.b8:	cmp.l	#$ffffff,d1
	bhi.s	.b1
	lsl.l	#8,d1
	subq.w	#8,d0
.b1:	tst.l	d1
	bmi.s	.x
	add.l	d1,d1
	subq.w	#1,d0
	bra.s	.b1
.x:	rts

fp_std:
	movem.l	d3-d6,-(sp)
	move.l	a0,-(sp)
	bsr	fpi_pop
	moveq	#0,d6
	moveq	#0,d3			; 53 bits
	bsr	fpi_round
	move.l	(sp)+,a0
	tst.l	d1
	bne.s	.nz
	clr.l	(a0)+
	clr.l	(a0)
	bra.s	.x
.nz:	move.w	d0,d3			; exponent: biased 16383 -> 1023
	and.w	#$7fff,d3
	sub.w	#FP_BIAS-1023,d3
	and.l	#$7ff,d3
	swap	d3
	lsl.l	#4,d3			; << 20
	tst.w	d0
	bpl.s	.ps
	bset	#31,d3
.ps:	move.l	d1,d4			; hi |= (mant_hi >> 11) & $fffff
	moveq	#11,d5
	lsr.l	d5,d4
	and.l	#$fffff,d4
	or.l	d4,d3
	move.l	d3,(a0)+
	moveq	#21,d5			; lo = mant_hi << 21 | mant_lo >> 11
	lsl.l	d5,d1
	moveq	#11,d5
	lsr.l	d5,d2
	or.l	d2,d1
	move.l	d1,(a0)
.x:	movem.l	(sp)+,d3-d6
	rts

fp_stx:
	move.l	a0,a1
	bsr	fpi_pop
	move.w	d0,(a1)
	move.l	d1,2(a1)
	move.l	d2,6(a1)
	rts

fp_dup:
	move.l	fp_sp,a0
	move.w	(a0),d0
	move.l	2(a0),d1
	move.l	6(a0),d2
	bra	fpi_push
fp_pop:
	sub.l	#FP_SLOT,fp_sp
	rts
fp_swap:
	move.l	fp_sp,a0
	lea	-FP_SLOT(a0),a1
	moveq	#FP_SLOT/2-1,d1
.s:	move.w	(a0),d0
	move.w	(a1),(a0)+
	move.w	d0,(a1)+
	dbf	d1,.s
	rts
fp_neg:
	move.l	fp_sp,a0
	tst.l	2(a0)
	beq.s	.x
	eor.w	#$8000,(a0)
.x:	rts
fp_abs:
	move.l	fp_sp,a0
	and.w	#$7fff,(a0)
	rts

; ---------------------------------------------------------------- rounding
; in: d0.w = sign/exponent, d1:d2:d6 = 96-bit mantissa (bit 31 of d1 set, or all zero), d6 holds
; the bits below the 64 kept ones (its bit 0 may be a sticky bit); d3.w = 0: round to 53 bits,
; 1: to 64 bits.  out: d0.w, d1:d2 rounded (nearest even).  trashes d3-d4
fpi_round:
	tst.w	d3
	beq.s	.r53
	tst.l	d6			; 64 bits: d6 is the remainder
	bpl.s	.x			; < half
	cmp.l	#$80000000,d6
	bne.s	.up
	btst	#0,d2			; tie: to even
	beq.s	.x
.up:	addq.l	#1,d2
	bcc.s	.x
	addq.l	#1,d1
	bcc.s	.x
.ovf:	move.l	#$80000000,d1		; carried out: 1.000..., exponent + 1
	addq.w	#1,d0
.x:	rts
.r53:	move.l	d2,d3			; 53 bits: the low 11 bits of d2 and d6 are the remainder
	and.w	#$7ff,d3
	and.w	#$f800,d2
	cmp.w	#$400,d3
	blo.s	.x
	bhi.s	.up53
	tst.l	d6			; exactly $400: a tie unless d6 has bits
	bne.s	.up53
	btst	#11,d2
	beq.s	.x
.up53:	add.l	#$800,d2
	bcc.s	.x
	addq.l	#1,d1
	bcc.s	.x
	bra.s	.ovf

; d3.w := the precision of fp_mode (0: 53, 1: 64)
fpi_prec	macro
	move.w	fp_mode,d3
	endm

; ---------------------------------------------------------------- add / sub
fp_sub:
	movem.l	d3-d7,-(sp)
	bsr	fpi_pop2
	eor.w	#$8000,d3
	bra.s	fpi_add
fp_subr:
	movem.l	d3-d7,-(sp)
	bsr	fpi_pop2
	eor.w	#$8000,d0
	bra.s	fpi_add
fp_add:
	movem.l	d3-d7,-(sp)
	bsr	fpi_pop2
fpi_add:
	bsr.s	fpx_add
	bsr	fpi_push
	movem.l	(sp)+,d3-d7
	rts

; A (d0-d2) + B (d3-d5) -> d0-d2, rounded to fp_mode.  trashes d3-d7
fpx_add:
	moveq	#0,d6
	tst.l	d4			; B = 0: A
	beq	.rnd
	tst.l	d1			; A = 0: B
	bne.s	.both
	move.w	d3,d0
	move.l	d4,d1
	move.l	d5,d2
	bra	.rnd
.both:	move.w	d0,d6			; |A| >= |B|? (exponent, then mantissa)
	and.w	#$7fff,d6
	move.w	d3,d7
	and.w	#$7fff,d7
	cmp.w	d7,d6
	bhi.s	.ord
	blo.s	.swp
	cmp.l	d4,d1
	bhi.s	.ord
	blo.s	.swp
	cmp.l	d5,d2
	bhs.s	.ord
.swp:	exg	d0,d3
	exg	d1,d4
	exg	d2,d5
	exg	d6,d7
.ord:	sub.w	d7,d6			; diff
	move.w	d6,-(sp)
	moveq	#0,d6			; A's low part
	moveq	#0,d7			; B's low part
	move.w	(sp)+,d6
	bsr	fpi_shr96b		; B >>= diff (d4:d5:d7) with sticky; d6 cleared again
	move.w	d0,d6			; signs
	eor.w	d3,d6
	bmi.s	.diffs
	moveq	#0,d6
	add.l	d7,d6
	addx.l	d5,d2
	addx.l	d4,d1
	bcc.s	.rnd
	roxr.l	#1,d1			; carry out: >> 1 (keep the lost bit as sticky)
	roxr.l	#1,d2
	roxr.l	#1,d6
	bcc.s	.c1
	or.w	#1,d6
.c1:	addq.w	#1,d0
	bra.s	.rnd
.diffs:	moveq	#0,d6
	sub.l	d7,d6
	subx.l	d5,d2
	subx.l	d4,d1
	move.l	d1,d3			; zero?
	or.l	d2,d3
	or.l	d6,d3
	bne.s	.norm
	moveq	#0,d0
	moveq	#0,d1
	moveq	#0,d2
	rts
.norm:	tst.l	d1			; normalise left (whole longs first)
	bne.s	.nb
	move.l	d2,d1
	move.l	d6,d2
	moveq	#0,d6
	sub.w	#32,d0
	bra.s	.norm
.nb:	tst.l	d1
	bmi.s	.rnd
	add.l	d6,d6
	addx.l	d2,d2
	addx.l	d1,d1
	subq.w	#1,d0
	bra.s	.nb
.rnd:	fpi_prec
	bra	fpi_round

; shift B's 96-bit mantissa d4:d5:d7 right by d6.w (>= 0) with a sticky bit in d7 bit 0;
; out: d6 = 0.  trashes d3? no: uses only d4-d7 and the stack
fpi_shr96b:
	move.l	d3,-(sp)
	moveq	#0,d3			; sticky
	cmp.w	#96,d6
	blo.s	.l
	move.l	d4,d3			; everything goes
	or.l	d5,d3
	or.l	d7,d3
	moveq	#0,d4
	moveq	#0,d5
	moveq	#0,d7
	bra.s	.st
.l:	cmp.w	#32,d6
	blo.s	.b
	or.l	d7,d3
	move.l	d5,d7
	move.l	d4,d5
	moveq	#0,d4
	sub.w	#32,d6
	bra.s	.l
.b:	tst.w	d6
	beq.s	.st
	move.l	d3,-(sp)
	moveq	#-1,d3			; the bits of d7 that go: d7 & ((1 << n) - 1)
	lsl.l	d6,d3
	not.l	d3
	and.l	d7,d3
	or.l	d3,(sp)
	lsr.l	d6,d7			; d7 = d7 >> n | d5 << (32-n)
	moveq	#32,d3
	sub.w	d6,d3
	move.l	d5,-(sp)
	lsl.l	d3,d5
	or.l	d5,d7
	move.l	(sp)+,d5
	lsr.l	d6,d5			; d5 = d5 >> n | d4 << (32-n)
	move.l	d4,-(sp)
	lsl.l	d3,d4
	or.l	d4,d5
	move.l	(sp)+,d4
	lsr.l	d6,d4
	move.l	(sp)+,d3
.st:	tst.l	d3
	beq.s	.x
	or.w	#1,d7
.x:	moveq	#0,d6
	move.l	(sp)+,d3
	rts

; ---------------------------------------------------------------- multiply
fp_sqr:
	bsr	fp_dup
fp_mul:
	movem.l	d3-d7,-(sp)
	bsr	fpi_pop2
	bsr.s	fpx_mul
	bsr	fpi_push
	movem.l	(sp)+,d3-d7
	rts

; A * B -> A.  trashes d3-d7, a1
fpx_mul:
	move.w	d0,d6			; sign
	eor.w	d3,d6
	and.w	#$8000,d6
	tst.l	d1
	beq.s	.zero
	tst.l	d4
	bne.s	.go
.zero:	moveq	#0,d0
	moveq	#0,d1
	moveq	#0,d2
	rts
.go:	and.w	#$7fff,d0		; exponent: ea + eb - bias + 1
	and.w	#$7fff,d3
	add.w	d3,d0
	sub.w	#FP_BIAS-1,d0
	or.w	d6,d0
	move.w	d0,-(sp)
	lea	fp_prod,a1		; 128-bit product of d1:d2 x d4:d5 -> fp_prod (4 longs, big-endian)
	movem.l	d1-d2/d4-d5,fp_ops	; (Phase 6i: a zero low long - integers, short constants -
	moveq	#0,d0			; skips its products)
	moveq	#0,d1
	tst.l	d2			; al*bl -> p1:p0
	beq.s	.z1
	tst.l	d5
	beq.s	.z1
	move.l	d2,d0
	move.l	d5,d1
	bsr	fpi_mul32
.z1:	move.l	d0,8(a1)
	move.l	d1,12(a1)
	move.l	fp_ops,d0		; ah*bh -> p3:p2
	move.l	fp_ops+8,d1
	bsr	fpi_mul32
	move.l	d0,(a1)
	move.l	d1,4(a1)
	move.l	fp_ops+12,d1		; ah*bl -> + p2:p1
	beq.s	.z2
	move.l	fp_ops,d0
	bsr.s	.addm
.z2:	move.l	fp_ops+4,d0		; al*bh -> + p2:p1
	beq.s	.z3
	move.l	fp_ops+8,d1
	bsr.s	.addm
.z3:	move.w	(sp)+,d0
	movem.l	(a1),d1-d2/d6-d7
	tst.l	d1			; normalise: product in [1, 4)
	bmi.s	.n
	add.l	d7,d7
	addx.l	d6,d6
	addx.l	d2,d2
	addx.l	d1,d1
	subq.w	#1,d0
.n:	tst.l	d7			; sticky from the lowest long
	beq.s	.r
	or.w	#1,d6
.r:	fpi_prec
	bra	fpi_round
.addm:	bsr.s	fpi_mul32		; d0:d1 added at p2:p1, carry into p3
	add.l	d1,8(a1)
	move.l	4(a1),d2
	addx.l	d0,d2
	bcc.s	.ac
	addq.l	#1,(a1)
.ac:	move.l	d2,4(a1)
	rts

; d0.l * d1.l -> d0:d1 (unsigned 64-bit).  trashes d2-d4
fpi_mul32:
	move.l	d0,d2
	move.l	d1,d3
	swap	d2			; ah
	swap	d3			; bh
	move.w	d2,d4
	mulu	d3,d4			; ah*bh
	mulu	d0,d3			; al*bh
	mulu	d1,d2			; ah*bl
	mulu	d1,d0			; al*bl
	add.l	d3,d2			; middle sum (33 bits)
	bcc.s	.nc
	add.l	#$10000,d4
.nc:	move.l	d2,d3
	swap	d3
	clr.w	d3			; middle << 16 (low part)
	clr.w	d2
	swap	d2			; middle >> 16
	add.l	d3,d0
	addx.l	d2,d4
	move.l	d0,d1
	move.l	d4,d0
	rts

; ---------------------------------------------------------------- divide
fp_divr:
	movem.l	d3-d7,-(sp)
	bsr	fpi_pop2
	exg	d0,d3
	exg	d1,d4
	exg	d2,d5
	bra.s	fpi_div
fp_div:
	movem.l	d3-d7,-(sp)
	bsr	fpi_pop2
fpi_div:
	bsr.s	fpx_div
	bsr	fpi_push
	movem.l	(sp)+,d3-d7
	rts

; A / B -> A.  trashes d3-d7, a1
fpx_div:
	move.w	d0,d6
	eor.w	d3,d6
	and.w	#$8000,d6
	tst.l	d1
	beq.s	.zero
	tst.l	d4
	bne.s	.go
.zero:	moveq	#0,d0			; (x/0 does not happen in the game)
	moveq	#0,d1
	moveq	#0,d2
	rts
.go:	and.w	#$7fff,d0		; exponent: ea - eb + bias
	and.w	#$7fff,d3
	sub.w	d3,d0
	add.w	#FP_BIAS,d0
	moveq	#0,d7			; R = d7:d1:d2 (65 bits), D = d4:d5
	cmp.l	d4,d1			; R < D: R <<= 1, exponent - 1 (the first quotient bit is 1)
	bhi.s	.ge
	blo.s	.lt
	cmp.l	d5,d2
	bhs.s	.ge
.lt:	add.l	d2,d2
	addx.l	d1,d1
	addx.l	d7,d7
	subq.w	#1,d0
.ge:	or.w	d6,d0
	move.w	d0,-(sp)
	; R (d7:d1:d2) is in [B, 2B): the first quotient bit is 1 and R - B < B. The other 64 bits
	; (q64 = floor((R-B)*2^64 / B)) come as four base-65536 digits (Knuth's algorithm D: divu
	; by B's top word gives qhat >= q, at most 2 too big; the remainder says, and B is added
	; back). Q = 2^63 + q64/2, guard = q64 bit 0, sticky = remainder <> 0 - the same bits as
	; one quotient bit at a time, ~3x faster.
	sub.l	d5,d2
	subx.l	d4,d1			; r := R - B
	clr.l	fp_q
	clr.l	fp_q+4			; q64
	move.w	#4-1,-(sp)
.dig:	move.l	d4,d7
	swap	d7			; v1 = B's top word
	move.l	d1,d0
	swap	d0
	cmp.w	d7,d0
	bhs.s	.cap			; (r's top word = v1: the quotient would not fit a word)
	move.l	d1,d0
	divu	d7,d0			; qhat
	bra.s	.qh
.cap:	move.w	#$ffff,d0
.qh:	move.w	d0,a0
	move.w	d5,d3			; P := qhat*B (80 bits: d6.w : d7 : d3)
	mulu	d0,d3			; qhat*b4
	move.l	d5,d6
	swap	d6
	mulu	d0,d6			; qhat*b3
	move.l	d6,d7
	swap	d7
	clr.w	d7
	clr.w	d6
	swap	d6
	add.l	d7,d3			; L
	move.w	d4,d7
	mulu	d0,d7			; qhat*b2
	addx.l	d6,d7
	move.l	d4,d6
	swap	d6
	mulu	d0,d6			; qhat*b1
	move.l	d6,d0
	swap	d0
	clr.w	d0
	add.l	d0,d7			; H
	clr.w	d6
	swap	d6
	moveq	#0,d0
	addx.w	d0,d6			; T
	move.l	d1,d0			; r*65536 - P: d0.w : d1 : d2
	swap	d0
	swap	d1
	swap	d2
	move.w	d2,d1
	clr.w	d2
	sub.l	d3,d2
	subx.l	d7,d1
	subx.w	d6,d0
	bpl.s	.ok
	moveq	#0,d3
.fix:	subq.w	#1,a0			; too big: add B back
	add.l	d5,d2
	addx.l	d4,d1
	addx.w	d3,d0
	bmi.s	.fix
.ok:	move.l	fp_q,d3			; q64 := q64*65536 + qhat
	move.l	fp_q+4,d6
	swap	d3
	swap	d6
	move.w	d6,d3
	move.w	a0,d6
	move.l	d3,fp_q
	move.l	d6,fp_q+4
	subq.w	#1,(sp)
	bpl	.dig
	addq.l	#2,sp
	move.l	d1,d0			; sticky: remainder <> 0
	or.l	d2,d0
	sne	d7
	lsr.l	#1,d3			; Q = 2^63 + q64/2, C = guard
	roxr.l	#1,d6
	scs	d0
	bset	#31,d3
	move.l	d3,d1
	move.l	d6,d2
	moveq	#0,d6
	tst.b	d0
	beq.s	.g0
	move.l	#$80000000,d6
.g0:	tst.b	d7
	beq.s	.s0
	or.w	#1,d6
.s0:	move.w	(sp)+,d0
	fpi_prec
	bra	fpi_round

; ---------------------------------------------------------------- square root
fp_sqrt:
	movem.l	d3-d7,-(sp)
	bsr	fpi_pop
	bsr.s	fpx_sqrt
	bsr	fpi_push
	movem.l	(sp)+,d3-d7
	rts

; sqrt(A) -> A (A >= 0).  digit by digit: 65 root bits, remainder for the sticky bit. All in
; registers: r = d0:d1:d2 (the remainder), T = d3:d4:d5 = root << 2 (T|1 is the trial value of a
; step: the low two bits of T are 0), the source bits in d6:d7 (the mantissa; even exponents
; start with a 0 bit, so its last bit comes in after 32 steps).  trashes d3-d7, a1-a2
fpx_sqrt:
	tst.l	d1
	beq.s	.zero
	tst.w	d0
	bpl.s	.go
.zero:	moveq	#0,d0
	moveq	#0,d1
	moveq	#0,d2
	rts
.go:	move.w	d0,d3			; u = e - bias
	sub.w	#FP_BIAS,d3
	move.l	d1,d6			; source = m
	move.l	d2,d7
	sub.l	a2,a2			; (the bit for step 33)
	btst	#0,d3
	beq.s	.even
	subq.w	#1,d3			; odd: N = m << 66
	bra.s	.src
.even:	lsr.l	#1,d6			; even: N = m << 65: source = 0, m63..m1, then m0
	roxr.l	#1,d7
	bcc.s	.src
	move.w	#1,a2
.src:	asr.w	#1,d3
	add.w	#FP_BIAS,d3
	move.w	d3,-(sp)		; result exponent
	moveq	#0,d0			; r
	moveq	#0,d1
	moveq	#0,d2
	moveq	#0,d3			; T
	moveq	#0,d4
	moveq	#0,d5
	move.w	#32-1,-(sp)
	bsr.s	.steps
	moveq	#0,d6			; the source after its 64 bits: m0 (even) and zeros
	moveq	#0,d7
	move.w	a2,d6
	ror.l	#1,d6
	move.w	#33-1,(sp)
	bsr.s	.steps
	addq.l	#2,sp
	; root (65 bits) = T >> 2 -> mantissa root >> 1, guard root & 1; sticky: r <> 0
	moveq	#0,d6
	lsr.l	#1,d3			; T >> 3: the mantissa
	roxr.l	#1,d4
	roxr.l	#1,d5
	lsr.l	#1,d3
	roxr.l	#1,d4
	roxr.l	#1,d5
	lsr.l	#1,d3
	roxr.l	#1,d4
	roxr.l	#1,d5			; C = the root's last bit: guard
	bcc.s	.ng
	move.l	#$80000000,d6
.ng:	or.l	d1,d0
	or.l	d2,d0
	beq.s	.ns
	or.w	#1,d6
.ns:	move.l	d4,d1
	move.l	d5,d2
	move.w	(sp)+,d0
	fpi_prec
	bra	fpi_round
; (sp+4).w + 1 steps: r := r << 2 | two source bits; if r >= T|1: r -= T|1, T := 2T + 4,
; else T := 2T
.steps:
.st:	add.l	d7,d7
	addx.l	d6,d6
	addx.l	d2,d2
	addx.l	d1,d1
	addx.l	d0,d0
	add.l	d7,d7
	addx.l	d6,d6
	addx.l	d2,d2
	addx.l	d1,d1
	addx.l	d0,d0
	cmp.l	d3,d0			; r >= T|1 ?
	bhi.s	.ge
	blo.s	.lt
	cmp.l	d4,d1
	bhi.s	.ge
	blo.s	.lt
	cmp.l	d5,d2			; (T's low bits are 0: r >= T|1 <=> r > T)
	bls.s	.lt
.ge:	bset	#0,d5
	sub.l	d5,d2
	subx.l	d4,d1
	subx.l	d3,d0
	bclr	#0,d5
	add.l	d5,d5
	addx.l	d4,d4
	addx.l	d3,d3
	addq.l	#4,d5
	subq.w	#1,4(sp)
	bpl.s	.st
	rts
.lt:	add.l	d5,d5
	addx.l	d4,d4
	addx.l	d3,d3
	subq.w	#1,4(sp)
	bpl.s	.st
	rts

; ---------------------------------------------------------------- to integer, compare
fp_trunc:
	movem.l	d3-d7,-(sp)
	clr.w	-(sp)
	bra.s	fpi_toint
fp_rnd:
	movem.l	d3-d7,-(sp)
	move.w	#1,-(sp)
fpi_toint:
	bsr	fpi_pop
	tst.l	d1
	beq.s	.zero
	move.w	d0,-(sp)		; sign
	and.w	#$7fff,d0
	move.w	#FP_BIAS+63,d6		; fraction bits = bias + 63 - e
	sub.w	d0,d6
	bgt.s	.sh
	move.l	#$7fffffff,d0		; (too big: not in the game)
	bra.s	.sg
.sh:	move.l	d1,d4
	move.l	d2,d5
	moveq	#0,d7
	bsr	fpi_shr96b		; d4:d5 = integer part, d7 = fraction (with sticky)
	move.l	d5,d0
	tst.w	2(sp)
	beq.s	.sg			; trunc
	tst.l	d7
	bpl.s	.sg
	cmp.l	#$80000000,d7
	bne.s	.up
	btst	#0,d0
	beq.s	.sg
.up:	addq.l	#1,d0
.sg:	tst.w	(sp)+
	bpl.s	.x
	neg.l	d0
.x:	addq.l	#2,sp
	movem.l	(sp)+,d3-d7
	rts
.zero:	moveq	#0,d0
	bra.s	.x

fp_tst:
	moveq	#0,d0
	bsr	fp_ldi
fp_cmp:
	movem.l	d3-d7,-(sp)
	bsr	fpi_pop2		; A = st1, B = st0
	tst.l	d1			; zeros compare by sign of the other
	bne.s	.a
	moveq	#0,d0
.a:	tst.l	d4
	bne.s	.b
	moveq	#0,d3
.b:	move.w	d0,d6			; signs differ: the positive one is bigger
	eor.w	d3,d6
	bpl.s	.same
	tst.l	d1
	bne.s	.d1
	tst.l	d4
	beq.s	.eq
.d1:	tst.w	d0
	bmi.s	.lt
	bra.s	.gt
.same:	tst.l	d1			; both zero?
	bne.s	.mag
	tst.l	d4
	beq.s	.eq
.mag:	moveq	#0,d6			; magnitude compare, flipped for negatives
	cmp.w	d3,d0			; (sign bits equal: compare exponents as unsigned words)
	bhi.s	.mg
	blo.s	.ml
	cmp.l	d4,d1
	bhi.s	.mg
	blo.s	.ml
	cmp.l	d5,d2
	bhi.s	.mg
	blo.s	.ml
.eq:	moveq	#0,d0
	bra.s	.x
.mg:	tst.w	d0
	bmi.s	.lt
.gt:	moveq	#1,d0
	bra.s	.x
.ml:	tst.w	d0
	bmi.s	.gt
.lt:	moveq	#-1,d0
.x:	movem.l	(sp)+,d3-d7
	tst.w	d0
	rts

; ---------------------------------------------------------------- sin, cos, arctan (x87)
; Phase 6i: sin and cos come from fpi_fsc (below: fixed point, both at once, ~10x faster and closer
; to the x87) and are kept for the last argument - the game asks for cos(a) and then sin(a). An
; argument fpi_fsc does not take (|x| >= 2^14, tiny, or |r| < 2^-24) goes to the series.
fp_cos:
	moveq	#1,d0
	bra.s	fpi_sincos
fp_sin:
	moveq	#0,d0
fpi_sincos:
	move.l	fp_sp,a0
	tst.b	fps_kok			; the same argument as last time?
	beq.s	.calc
	move.w	(a0),d1
	cmp.w	fps_key,d1
	bne.s	.calc
	move.l	2(a0),d1
	cmp.l	fps_key+2,d1
	bne.s	.calc
	move.l	6(a0),d1
	cmp.l	fps_key+6,d1
	beq.s	.hit
.calc:	move.w	d0,-(sp)
	bsr	fpi_fsc
	movem.w	(sp)+,d0		; (movem: the carry stays)
	bcs.s	fpi_sser
	move.l	fp_sp,a0		; keep the argument
	move.w	(a0),fps_key
	move.l	2(a0),fps_key+2
	move.l	6(a0),fps_key+6
	st	fps_kok
.hit:	lea	fps_res,a1		; st0 := sin or cos
	tst.w	d0
	beq.s	.cp
	lea	12(a1),a1
.cp:	move.l	fp_sp,a0
	move.w	(a1)+,(a0)+
	move.l	(a1)+,(a0)+
	move.l	(a1)+,(a0)+
	rts

; the series (until Phase 6h all of it): k := round(x * 2/pi); r := (x - k*P1) - k*P2 (pi/2 in
; two parts); then sin or cos of r by Taylor series (|r| <= pi/4, error ~2^-62) and the quadrant.
; Computed in 64-bit mode.  d0.w = 0 sin, 1 cos
fpi_sser:
	movem.l	d3-d4,-(sp)
	move.w	fp_mode,-(sp)
	move.w	#1,fp_mode
	move.w	d0,d3			; 0 sin, 1 cos
	bsr	fp_dup			; k = round(x * 2/pi)
	lea	fpc_2opi,a0
	bsr	fp_ldx
	bsr	fp_mul
	bsr	fp_rnd
	move.l	d0,d4
	add.w	d0,d3			; quadrant = k (+1 for cos)
	lea	fp_tx,a0		; r = (x - k*P1) - k*P2
	bsr	fp_stx
	move.l	d4,d0
	bsr	fp_ldi
	lea	fpc_pio2a,a0
	bsr	fp_ldx
	bsr	fp_mul
	lea	fp_tx,a0
	bsr	fp_ldx
	bsr	fp_subr
	move.l	d4,d0
	bsr	fp_ldi
	lea	fpc_pio2b,a0
	bsr	fp_ldx
	bsr	fp_mul
	bsr	fp_sub
	and.w	#3,d3
	btst	#0,d3
	bne.s	.cos
	bsr	fpi_sinr
	bra.s	.q
.cos:	bsr	fpi_cosr
.q:	btst	#1,d3			; quadrants 2, 3: negative
	beq.s	.x
	bsr	fp_neg
.x:	move.w	(sp)+,fp_mode
	movem.l	(sp)+,d3-d4
	rts

; sin(r) = r - r^3/3! + ... (r^21): Horner in r^2
fpi_sinr:
	movem.l	d3/a3,-(sp)
	bsr	fp_dup			; r, r
	bsr	fp_sqr			; r, r2
	lea	fpc_sin,a3		; coefficients from the highest: c10 .. c1 (1/21! .. -1/3!)
	move.l	a3,a0
	bsr	fp_ldx			; acc = c10
	moveq	#10-1,d3
.h:	lea	10(a3),a3
	bsr	fpi_mulst1		; acc *= r2
	move.l	a3,a0
	bsr	fp_ldx
	bsr	fp_add			; acc += c
	dbf	d3,.h			; (the last coefficient is 1)
	bsr	fp_swap			; r, acc, r2 -> drop r2
	bsr	fp_pop
	bsr	fp_mul			; r * acc
	movem.l	(sp)+,d3/a3
	rts
; cos(r) = 1 - r^2/2! + ... (r^20)
fpi_cosr:
	movem.l	d3/a3,-(sp)
	bsr	fp_sqr			; r2
	lea	fpc_cos,a3
	move.l	a3,a0
	bsr	fp_ldx
	moveq	#10-1,d3
.h:	lea	10(a3),a3
	bsr	fpi_mulst1
	move.l	a3,a0
	bsr	fp_ldx
	bsr	fp_add
	dbf	d3,.h
	bsr	fp_swap
	bsr	fp_pop
	movem.l	(sp)+,d3/a3
	rts
; st0 := st0 * st1 (st1 stays)
fpi_mulst1:
	move.l	fp_sp,a0
	lea	-FP_SLOT(a0),a0
	move.w	(a0),d0
	move.l	2(a0),d1
	move.l	6(a0),d2
	bsr	fpi_push
	bra	fp_mul

; ---------------------------------------------------------------- fast sin and cos (Phase 6i)
; fpi_fsc: a0 = the argument's slot (se.w, m.l, m.l).  Carry clear: fps_res = sin(x), fps_res+12 =
; cos(x) (12-byte slots).  Carry set: not taken (fps_res unchanged).  Exactly tools/sincos_model.py:
; R = x - k*Pm (Pm = pi/2 in 66 bits, as the x87 reduces; units 2^-65, exact), A = |R|, j = round(A
; * 512), b = A - j/512 (|b| <= 2^-10, exact); sin/cos(j/512) from fps_tab (units 2^-95);
; sin A = S - S*ec + sb*(C*b - C*b*es), cos A = C - C*ec - sb*(S*b - S*b*es) with ec = 1 - cos b,
; es = 1 - sin(b)/b by short series; every product exact, then floored; one rounding to 64 bits.
; trashes d0-d2/a0-a2
fpi_fsc:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	(a0),d7			; se
	move.l	2(a0),d1
	move.l	6(a0),d2
	tst.l	d1
	beq	.no			; zero
	move.w	d7,d0			; E = exponent - bias: -12 .. 13
	and.w	#$7fff,d0
	sub.w	#FP_BIAS,d0
	cmp.w	#13,d0
	bgt	.no
	cmp.w	#-12,d0
	blt	.no
	moveq	#0,d3			; X = |x| * 2^65 = d3:d1:d2, exact
	addq.w	#2,d0
	bmi.s	.xr
	beq.s	.xok
	subq.w	#1,d0
.xl:	add.l	d2,d2
	addx.l	d1,d1
	addx.l	d3,d3
	dbf	d0,.xl
	bra.s	.xok
.xr:	neg.w	d0
	subq.w	#1,d0
.xs:	lsr.l	#1,d1
	roxr.l	#1,d2
	bcs	.no			; a bit would be lost
	dbf	d0,.xs
.xok:	move.l	d1,d4			; k = (q16 * 41722 + 2^31) >> 32, q16 = X >> 49
	moveq	#17,d0
	lsr.l	d0,d4
	move.l	d3,d5
	moveq	#15,d0
	lsl.l	d0,d5
	or.l	d5,d4			; q16 (< 2^30)
	move.l	d4,d5
	swap	d5
	mulu	#41722,d5		; qh * 41722
	mulu	#41722,d4		; ql * 41722
	move.l	d5,d6			; P = ph << 16 + pl + 2^31, k = P >> 32
	clr.w	d6
	swap	d6
	swap	d5
	clr.w	d5
	add.l	d4,d5
	bcc.s	.k1
	addq.l	#1,d6
.k1:	add.l	#$80000000,d5
	bcc.s	.k2
	addq.l	#1,d6
.k2:	lea	fps_pm+12,a1		; R = X - k * Pm (word by word from the low end)
	lea	fps_t+12,a2
	moveq	#0,d4
	moveq	#5,d5
.km:	moveq	#0,d0
	move.w	-(a1),d0
	mulu	d6,d0
	add.l	d4,d0
	move.w	d0,-(a2)
	clr.w	d0
	swap	d0
	move.l	d0,d4
	dbf	d5,.km
	movem.l	fps_t,d0/d4/d5
	sub.l	d5,d2
	subx.l	d4,d1
	subx.l	d0,d3
.adj:	tst.l	d3			; while R > h: R -= Pm, k++; while R < -h: R += Pm, k--
	bmi.s	.adn
	cmp.l	fps_h,d3
	bhi.s	.asub
	bne.s	.aok
	cmp.l	fps_h+4,d1
	bhi.s	.asub
	bne.s	.aok
	cmp.l	fps_h+8,d2
	bls.s	.aok
.asub:	movem.l	fps_pm,d0/d4/d5
	sub.l	d5,d2
	subx.l	d4,d1
	subx.l	d0,d3
	addq.w	#1,d6
	bra.s	.adj
.adn:	moveq	#0,d0			; -R in d0:d4:d5
	moveq	#0,d4
	moveq	#0,d5
	sub.l	d2,d5
	subx.l	d1,d4
	subx.l	d3,d0
	cmp.l	fps_h,d0
	bhi.s	.aadd
	bne.s	.aok
	cmp.l	fps_h+4,d4
	bhi.s	.aadd
	bne.s	.aok
	cmp.l	fps_h+8,d5
	bls.s	.aok
.aadd:	movem.l	fps_pm,d0/d4/d5
	add.l	d5,d2
	addx.l	d4,d1
	addx.l	d0,d3
	subq.w	#1,d6
	bra.s	.adj
.aok:	move.w	d6,fps_k		; k (its low two bits: the quadrant)
	move.w	d7,fps_se
	sf	fps_sr
	tst.l	d3			; A = |R|, fps_sr = R < 0
	bpl.s	.ap
	neg.l	d2
	negx.l	d1
	negx.l	d3
	st	fps_sr
.ap:	tst.l	d3			; A < 2^41: the short series
	bne.s	.abig
	cmp.l	#$200,d1
	bhs.s	.abig
	move.l	d1,d0
	or.l	d2,d0
	beq	.no			; A = 0
	bra	.small
.abig:	move.l	d1,d4			; j = (A + 2^55) >> 56
	move.l	d3,d5
	add.l	#$00800000,d4
	bcc.s	.j1
	addq.l	#1,d5
.j1:	rol.l	#8,d4
	and.l	#$ff,d4
	lsl.w	#8,d5
	or.w	d5,d4			; j
	moveq	#0,d5			; b = A - j << 56
	move.b	d4,d5
	ror.l	#8,d5
	moveq	#0,d0
	move.w	d4,d0
	lsr.w	#8,d0
	sub.l	d5,d1
	subx.l	d0,d3
	sf	fps_sb			; Bm = |b|, fps_sb = b < 0
	tst.l	d3
	bpl.s	.bp
	neg.l	d2
	negx.l	d1
	st	fps_sb
.bp:	cmp.l	#$00800000,d1		; Bm >= 2^55: not here
	bhs	.no
	movem.l	d1-d2,fps_bm
	mulu	#24,d4			; the table entry
	lea	fps_tab,a5
	add.l	d4,a5
	lea	fps_bm,a0		; Q = Bm^2 >> 46
	moveq	#2,d0
	move.l	a0,a1
	moveq	#2,d1
	lea	fps_p,a2
	bsr	fps_mul
	lea	fps_p,a0
	moveq	#4,d0
	moveq	#46,d1
	lea	fps_q,a1
	moveq	#2,d2
	bsr	fps_shr
	lea	fps_q,a0		; Q2 = Q^2 >> 84
	moveq	#2,d0
	move.l	a0,a1
	moveq	#2,d1
	lea	fps_p,a2
	bsr	fps_mul
	lea	fps_p,a0
	moveq	#4,d0
	moveq	#84,d1
	lea	fps_q2,a1
	moveq	#2,d2
	bsr	fps_shr
	move.l	fps_q,d0		; W3 = (((W*W) >> 32) * W) >> 40, W = Q >> 32
	move.l	d0,d1
	bsr	fpi_mul32
	move.l	fps_q,d1
	bsr	fpi_mul32
	lsr.l	#8,d0
	move.l	d0,d7			; W3 (< 2^24)
	movem.l	fps_q,d0-d1		; es = Q/6 - Q2/120 + W3/5040
	movem.l	d0-d1,fps_es
	lea	fps_es,a0
	moveq	#2,d0
	moveq	#6,d1
	bsr	fps_divs
	movem.l	fps_q2,d0-d1
	movem.l	d0-d1,fps_t
	lea	fps_t,a0
	moveq	#2,d0
	moveq	#120,d1
	bsr	fps_divs
	lea	fps_es,a0
	lea	fps_t,a1
	moveq	#2,d0
	bsr	fps_sub
	move.l	d7,d0
	divu	#5040,d0
	and.l	#$ffff,d0
	add.l	d0,fps_es+4
	bcc.s	.e1
	addq.l	#1,fps_es
.e1:	movem.l	fps_q,d0-d1		; ec = Q/2 - Q2/24 + W3/720
	lsr.l	#1,d0
	roxr.l	#1,d1
	movem.l	d0-d1,fps_ec
	movem.l	fps_q2,d0-d1
	movem.l	d0-d1,fps_t
	lea	fps_t,a0
	moveq	#2,d0
	moveq	#24,d1
	bsr	fps_divs
	lea	fps_ec,a0
	lea	fps_t,a1
	moveq	#2,d0
	bsr	fps_sub
	move.l	d7,d0
	divu	#720,d0
	and.l	#$ffff,d0
	add.l	d0,fps_ec+4
	bcc.s	.e2
	addq.l	#1,fps_ec
.e2:	lea	12(a5),a0		; CB = (C * Bm) >> 65 and CBe = ((CB >> 21) * es) >> 63
	lea	fps_cb,a3
	lea	fps_cbe,a4
	bsr	fps_bterm
	move.l	a5,a0			; SB, SBe the same with S
	lea	fps_sbx,a3
	lea	fps_sbe,a4
	bsr	fps_bterm
	move.l	a5,a0			; Sec = (S * ec) >> 84
	lea	fps_sec,a3
	bsr	fps_ecterm
	lea	12(a5),a0		; Cec = (C * ec) >> 84
	lea	fps_cec,a3
	bsr	fps_ecterm
	lea	fps_cb,a0		; u = CB - CBe, v = SB - SBe (in place)
	lea	fps_cbe+8,a1
	bsr	fps_sub3_2
	lea	fps_sbx,a0
	lea	fps_sbe+8,a1
	bsr	fps_sub3_2
	movem.l	(a5),d0-d2		; sA = S - Sec +- u
	movem.l	d0-d2,fps_sa
	lea	fps_sa,a0
	lea	fps_sec,a1
	moveq	#3,d0
	bsr	fps_sub
	lea	fps_sa,a0
	lea	fps_cb,a1
	moveq	#3,d0
	tst.b	fps_sb
	bne.s	.s1
	bsr	fps_add
	bra.s	.s2
.s1:	bsr	fps_sub
.s2:	movem.l	12(a5),d0-d2		; cA = C - Cec -+ v
	movem.l	d0-d2,fps_ca
	lea	fps_ca,a0
	lea	fps_cec,a1
	moveq	#3,d0
	bsr	fps_sub
	lea	fps_ca,a0
	lea	fps_sbx,a1
	moveq	#3,d0
	tst.b	fps_sb
	bne.s	.c1
	bsr	fps_sub
	bra.s	.c2
.c1:	bsr	fps_add
.c2:	lea	fps_sa,a0		; to extended: sin |r| -> fps_xs, cos r -> fps_xc
	bsr	fps_toext
	lea	fps_xs,a0
	move.w	d0,(a0)+
	move.l	d1,(a0)+
	move.l	d2,(a0)
	lea	fps_ca,a0
	bsr	fps_toext
	lea	fps_xc,a0
	move.w	d0,(a0)+
	move.l	d1,(a0)+
	move.l	d2,(a0)
	; quadrant q = k & 3 of |x|; sinR = sr * sA, cosR = cA:
	; q 0: sin = sinR, cos = cosR   1: sin = cosR, cos = -sinR   2: -sinR, -cosR   3: -cosR, sinR
	move.w	fps_k,d0
	and.w	#3,d0
	moveq	#0,d1			; d1.b: sin negative, d2.b: cos negative
	moveq	#0,d2
	move.b	fps_sr,d3		; $ff: sinR < 0
	lea	fps_xs,a0		; the sin slot's source
	lea	fps_xc,a1		; the cos slot's source
	tst.w	d0
	bne.s	.q1
	move.b	d3,d1
	bra.s	.qx
.q1:	cmp.w	#1,d0
	bne.s	.q2
	exg	a0,a1
	move.b	d3,d2
	not.b	d2
	bra.s	.qx
.q2:	cmp.w	#2,d0
	bne.s	.q3
	move.b	d3,d1
	not.b	d1
	st	d2
	bra.s	.qx
.q3:	exg	a0,a1
	st	d1
	move.b	d3,d2
.qx:	tst.w	fps_se			; x < 0: sin(x) = -sin|x|
	bpl.s	.qp
	not.b	d1
.qp:	lea	fps_res,a2
	move.w	(a0)+,d0
	tst.b	d1
	beq.s	.w1
	or.w	#$8000,d0
.w1:	move.w	d0,(a2)+
	move.l	(a0)+,(a2)+
	move.l	(a0)+,(a2)+
	clr.w	(a2)+
	move.w	(a1)+,d0
	tst.b	d2
	beq.s	.w2
	or.w	#$8000,d0
.w2:	move.w	d0,(a2)+
	move.l	(a1)+,(a2)+
	move.l	(a1)+,(a2)+
	movem.l	(sp)+,d3-d7/a3-a5
	and.b	#$fe,ccr		; carry clear: done
	rts
.no:	movem.l	(sp)+,d3-d7/a3-a5
	or.b	#1,ccr			; carry set: the series
	rts
; |r| < 2^-24: sin A = A - A^3/6, cos A = 1 - A^2/2 (units 2^-95; the next terms are below them)
.small:	movem.l	d1-d2,fps_bm
	lea	fps_bm,a0		; A^2
	moveq	#2,d0
	move.l	a0,a1
	moveq	#2,d1
	lea	fps_a2,a2
	bsr	fps_mul
	lea	fps_a2,a0		; cA = 2^95 - (A^2 >> 36)
	moveq	#4,d0
	moveq	#36,d1
	lea	fps_t,a1
	moveq	#3,d2
	bsr	fps_shr
	move.l	#$80000000,fps_ca
	clr.l	fps_ca+4
	clr.l	fps_ca+8
	lea	fps_ca,a0
	lea	fps_t,a1
	moveq	#3,d0
	bsr	fps_sub
	lea	fps_a2,a0		; sA = A << 30 - (A^3 >> 100) / 6
	moveq	#4,d0
	lea	fps_bm,a1
	moveq	#2,d1
	lea	fps_p,a2
	bsr	fps_mul
	lea	fps_p,a0
	moveq	#6,d0
	moveq	#100,d1
	lea	fps_t,a1
	moveq	#3,d2
	bsr	fps_shr
	lea	fps_t,a0
	moveq	#3,d0
	moveq	#6,d1
	bsr	fps_divs
	movem.l	fps_bm,d1-d2		; A << 30 = (A << 32) >> 2
	move.l	d1,d0
	move.l	d2,d1
	moveq	#0,d2
	lsr.l	#1,d0
	roxr.l	#1,d1
	roxr.l	#1,d2
	lsr.l	#1,d0
	roxr.l	#1,d1
	roxr.l	#1,d2
	movem.l	d0-d2,fps_sa
	lea	fps_sa,a0
	lea	fps_t,a1
	moveq	#3,d0
	bsr	fps_sub
	bra	.c2

; fps_bterm: a0 = the table's 3-long value V, a3 = (V * Bm) >> 65 (3 longs), a4 = ((that >> 21) *
; es) >> 63 (2 longs).  trashes d0-d2/a0-a2
fps_bterm:
	moveq	#3,d0
	lea	fps_bm,a1
	moveq	#2,d1
	lea	fps_p,a2
	bsr	fps_mul
	lea	fps_p,a0
	moveq	#5,d0
	moveq	#65,d1
	move.l	a3,a1
	moveq	#3,d2
	bsr	fps_shr
	move.l	a3,a0
	moveq	#3,d0
	moveq	#21,d1
	lea	fps_t,a1
	moveq	#2,d2
	bsr	fps_shr
	lea	fps_t,a0
	moveq	#2,d0
	lea	fps_es,a1
	moveq	#2,d1
	lea	fps_p,a2
	bsr	fps_mul
	lea	fps_p,a0
	moveq	#4,d0
	moveq	#63,d1
	move.l	a4,a1
	moveq	#2,d2
	bra	fps_shr
; fps_ecterm: a0 = the table's 3-long V, a3 = (V * ec) >> 84 (3 longs).  trashes d0-d2/a0-a2
fps_ecterm:
	moveq	#3,d0
	lea	fps_ec,a1
	moveq	#2,d1
	lea	fps_p,a2
	bsr	fps_mul
	lea	fps_p,a0
	moveq	#5,d0
	moveq	#84,d1
	move.l	a3,a1
	moveq	#3,d2
	bra	fps_shr
; a0 = 3 longs -= the 2 longs ending at a1 (a1 = their end)
fps_sub3_2:
	lea	12(a0),a0
	move.l	-(a1),d0
	sub.l	d0,-(a0)
	move.l	-(a1),d0
	move.l	-(a0),d1
	subx.l	d0,d1
	move.l	d1,(a0)
	move.l	-(a0),d1
	moveq	#0,d0
	subx.l	d0,d1
	move.l	d1,(a0)
	rts

; fps_mul: a2 (d0+2 longs) := a0 (d0.w longs) * a1 (2 longs), unsigned, big-endian, exact (d1 is
; ignored: every multiplier here has two longs).  trashes d0-d2 (keeps a0-a5)
fps_mul:
	movem.l	d3-d7/a2-a4,-(sp)
	move.l	(a1),d6			; B
	move.l	4(a1),d7
	move.w	d0,d1			; clear P
	addq.w	#1,d1
	move.l	a2,a3
.clr:	clr.l	(a3)+
	dbf	d1,.clr
	move.w	d0,d1			; rows from A's low long: row i adds at P[i .. i+2]
	lsl.w	#2,d1
	lea	0(a0,d1.w),a1		; after A's last long
	lea	8(a2,d1.w),a2		; after P[i+2] for the last i
	subq.w	#1,d0
.r:	move.l	-(a1),d5
	beq.s	.n
	move.l	a2,-(sp)
	bsr.s	fps_row
	move.l	(sp)+,a2
.n:	subq.l	#4,a2
	dbf	d0,.r
	movem.l	(sp)+,d3-d7/a2-a4
	rts

; MUL32: d0 * d1 -> d0 (high) : d1 (low), unsigned.  trashes d2-d4
MUL32	macro
	move.l	d0,d2
	move.l	d1,d3
	swap	d2
	swap	d3
	move.w	d2,d4
	mulu	d3,d4
	mulu	d0,d3
	mulu	d1,d2
	mulu	d1,d0
	add.l	d3,d2
	bcc.s	.nc\@
	add.l	#$10000,d4
.nc\@:	move.l	d2,d3
	swap	d3
	clr.w	d3
	clr.w	d2
	swap	d2
	add.l	d3,d0
	addx.l	d2,d4
	move.l	d0,d1
	move.l	d4,d0
	endm

; fps_row: the 3 longs before a2 += d5 * (d6:d7), the carry on into the longs before them.
; trashes d1-d4/a2-a4 (keeps d0)
fps_row:
	move.l	d0,-(sp)
	move.l	d5,d0
	move.l	d6,d1
	MUL32
	move.l	d0,a3			; d5 * hi = h1:l1
	move.l	d1,a4
	move.l	d5,d0
	move.l	d7,d1
	MUL32				; d5 * lo = h0:l0
	move.l	a4,d2			; the row: h1 + c : h0 + l1 : l0
	add.l	d2,d0
	move.l	a3,d2
	moveq	#0,d3
	addx.l	d3,d2
	add.l	d1,-(a2)
	move.l	-(a2),d3
	addx.l	d0,d3
	move.l	d3,(a2)
	move.l	-(a2),d3
	addx.l	d2,d3
	bcs.s	.cy			; (a move clears the carry)
	move.l	d3,(a2)
	move.l	(sp)+,d0
	rts
.cy:	move.l	d3,(a2)
.c:	addq.l	#1,-(a2)
	bcs.s	.c
	move.l	(sp)+,d0
	rts

; fps_shr: a1 (d2.w longs) := (a0 (d0.w longs) >> d1.w) mod 2^(32 * d2).  trashes d0-d2/a1
fps_shr:
	movem.l	d3-d6,-(sp)
	move.w	d1,d3
	lsr.w	#5,d3			; w: the source long (from the low end) of each result's low bits
	and.w	#31,d1			; b
	moveq	#32,d6
	sub.w	d1,d6
	move.w	d2,d4
	lsl.w	#2,d4
	add.w	d4,a1
	subq.w	#1,d2
.l:	move.w	d0,d4
	sub.w	d3,d4
	moveq	#0,d5
	subq.w	#1,d4			; the source long's index (big-endian)
	bmi.s	.st
	lsl.w	#2,d4
	move.l	0(a0,d4.w),d5
	lsr.l	d1,d5
	tst.w	d1
	beq.s	.st
	subq.w	#4,d4
	bmi.s	.st
	move.l	0(a0,d4.w),d4
	lsl.l	d6,d4
	or.l	d4,d5
.st:	move.l	d5,-(a1)
	addq.w	#1,d3
	dbf	d2,.l
	movem.l	(sp)+,d3-d6
	rts

; fps_divs: a0 (d0.w longs) := floor(a0 / d1.w), d1 = 1..65535.  trashes d0/d2/a0
fps_divs:
	add.w	d0,d0
	subq.w	#1,d0
	moveq	#0,d2
.l:	move.w	(a0),d2			; (remainder << 16) + word
	divu	d1,d2
	move.w	d2,(a0)+
	dbf	d0,.l
	rts

; fps_add / fps_sub: a0 (d0.w longs) +:= / -:= a1 (d0.w longs).  trashes d0-d1/a0-a1
fps_add:
	add.w	d0,d0
	add.w	d0,d0
	add.w	d0,a0
	add.w	d0,a1
	lsr.w	#2,d0
	subq.w	#1,d0
	moveq	#0,d1
	add.l	d1,d1			; X := 0
.l:	addx.l	-(a1),-(a0)
	dbf	d0,.l
	rts
fps_sub:
	add.w	d0,d0
	add.w	d0,d0
	add.w	d0,a0
	add.w	d0,a1
	lsr.w	#2,d0
	subq.w	#1,d0
	moveq	#0,d1
	add.l	d1,d1
.l:	subx.l	-(a1),-(a0)
	dbf	d0,.l
	rts

; fps_toext: a0 = 3 longs V (0 < V < 2^96, units 2^-95) -> d0.w = exponent field, d1:d2 =
; mantissa, rounded to 64 bits (nearest even).  trashes d3-d4/d6
fps_toext:
	movem.l	(a0),d1-d2/d6
	move.w	#FP_BIAS,d0		; bias + n - 1 - 95: n = 96 when bit 95 is set
.n8:	move.l	d1,d3			; whole bytes first
	and.l	#$ff000000,d3
	bne.s	.n
	lsl.l	#8,d1
	rol.l	#8,d2
	move.b	d2,d1
	clr.b	d2
	rol.l	#8,d6
	move.b	d6,d2
	clr.b	d6
	subq.w	#8,d0
	bra.s	.n8
.n:	tst.l	d1
	bmi.s	.r
	add.l	d6,d6
	addx.l	d2,d2
	addx.l	d1,d1
	subq.w	#1,d0
	bra.s	.n
.r:	moveq	#1,d3
	bra	fpi_round

; arctan(x): a = |x|; a > 1: a = 1/a; twice a := a / (1 + sqrt(1 + a^2)); series to a^29;
; times 4; pi/2 - that if inverted; the sign of x
fp_atan:
	movem.l	d3-d4/a3,-(sp)
	move.w	fp_mode,-(sp)
	move.w	#1,fp_mode
	move.l	fp_sp,a0
	move.w	(a0),d4			; sign
	and.w	#$7fff,(a0)
	moveq	#0,d3
	bsr	fp_dup			; a > 1 ?
	moveq	#1,d0
	bsr	fp_ldi
	bsr	fp_cmp
	ble.s	.le
	moveq	#1,d3
	moveq	#1,d0
	bsr	fp_ldi
	bsr	fp_divr			; 1 / a
.le:	moveq	#2-1,d1
.red:	move.w	d1,-(sp)
	bsr	fp_dup			; a, a
	bsr	fp_sqr
	moveq	#1,d0
	bsr	fp_ldi
	bsr	fp_add
	bsr	fp_sqrt
	moveq	#1,d0
	bsr	fp_ldi
	bsr	fp_add			; a, 1 + sqrt(1 + a^2)
	bsr	fp_div
	move.w	(sp)+,d1
	dbf	d1,.red
	bsr	fp_dup			; a, a2
	bsr	fp_sqr
	lea	fpc_atan,a3		; c14 .. c0: (-1)^k/(2k+1) from k = 14
	move.l	a3,a0
	bsr	fp_ldx
	moveq	#14-1,d1
.h:	move.w	d1,-(sp)
	lea	10(a3),a3
	bsr	fpi_mulst1
	move.l	a3,a0
	bsr	fp_ldx
	bsr	fp_add
	move.w	(sp)+,d1
	dbf	d1,.h
	bsr	fp_swap
	bsr	fp_pop
	bsr	fp_mul			; atan(a) / 4
	moveq	#4,d0
	bsr	fp_ldi
	bsr	fp_mul
	tst.w	d3
	beq.s	.s
	lea	fpc_pio2,a0
	bsr	fp_ldx
	bsr	fp_subr			; pi/2 - atan
.s:	tst.w	d4
	bpl.s	.x
	bsr	fp_neg
.x:	move.w	(sp)+,fp_mode
	movem.l	(sp)+,d3-d4/a3
	rts

; ---------------------------------------------------------------- str(r:w:d)
; v = |st0| as m * 2^E (E = e - bias - 63); R = v * 10^d: integer part and fraction exactly
; (m * 10^d in 96 bits, shifted right by -E). Rounding: to nearest; a tie point that lies within
; half a double ulp of v counts as the decimal ...5 FPC prints, and rounds away from zero.
fp_str:
	movem.l	d3-d7/a3-a4,-(sp)
	move.l	a0,a4			; destination
	move.w	d0,-(sp)		; width
	move.w	d1,-(sp)		; decimals
	bsr	fpi_pop
	move.w	d0,-(sp)		; sign
	moveq	#0,d7			; R (integer, 32 bits)
	tst.l	d1
	beq	.dig
	move.l	d1,d4			; M = m * 10^d (d <= 4): 96 bits in d3:d4:d5
	move.l	d2,d5
	moveq	#0,d3
	move.w	2(sp),d6		; decimals
	bra.s	.m10n
.m10:	bsr	.x10
.m10n:	dbf	d6,.m10
	move.w	(sp),d6			; E = e - bias - 63
	and.w	#$7fff,d6
	sub.w	#FP_BIAS+63,d6
	bpl	.big
	neg.w	d6			; fraction bits s = -E
	; threshold: 10^d * 1024 (half a double ulp of v, in units of 2^E)
	move.l	#1024,d0
	move.w	2(sp),d1
	bra.s	.thn
.th:	move.l	d0,d2
	lsl.l	#2,d0
	add.l	d2,d0
	add.l	d0,d0
.thn:	dbf	d1,.th
	move.l	d0,fp_thr
	; split M at bit s: integer part (must fit 32 bits) and the fraction compared with half
	move.w	d6,fp_s
	movem.l	d3-d5,fp_t		; M
	bsr	.split			; d7 = int, d0 = cmp result: -1 below half-thr, 0 near, 1 above
	tst.w	d0
	bmi.s	.dig
	addq.l	#1,d7			; above, or a tie within the interval: away from zero
	bra.s	.dig
.big:	move.l	d5,d7			; E >= 0: v is an integer (small in the game): M << E
	lsl.l	d6,d7
.dig:	; R -> digits: integer part and d decimals
	lea	fp_buf+40,a3
	move.w	2(sp),d6		; decimals
	move.l	d7,d0
	tst.w	d6
	beq.s	.ip
	subq.w	#1,d6
.fd:	bsr	.div10
	add.b	#'0',d1
	move.b	d1,-(a3)
	dbf	d6,.fd
	move.b	#'.',-(a3)
.ip:	bsr	.div10			; integer part (at least one digit)
	add.b	#'0',d1
	move.b	d1,-(a3)
	tst.l	d0
	bne.s	.ip
	tst.w	(sp)			; sign (FPC keeps it when the value rounds to 0: "-0")
	bpl.s	.ns
	move.b	#'-',-(a3)
.ns:	lea	fp_buf+40,a0		; length
	sub.l	a3,a0
	move.w	a0,d0
	move.w	4(sp),d1		; width: pad on the left
	move.l	a4,a1
	moveq	#0,d2
	move.w	d1,d2
	cmp.w	d0,d2
	bge.s	.w
	move.w	d0,d2
.w:	move.b	d2,(a1)+
	sub.w	d0,d2
	bra.s	.pn
.pad:	move.b	#' ',(a1)+
.pn:	dbf	d2,.pad
	subq.w	#1,d0
.cp:	move.b	(a3)+,(a1)+
	dbf	d0,.cp
	addq.l	#6,sp
	movem.l	(sp)+,d3-d7/a3-a4
	rts
.div10:	move.w	d0,d2			; d0.l / 10 -> d0.l, remainder d1.l (trashes d2)
	swap	d0
	moveq	#0,d1
	move.w	d0,d1
	divu	#10,d1
	move.w	d1,d0
	swap	d0
	move.w	d2,d1
	divu	#10,d1
	move.w	d1,d0
	clr.w	d1
	swap	d1
	rts
.x10:	; d3:d4:d5 *= 10
	movem.l	d3-d5,fp_t
	add.l	d5,d5
	addx.l	d4,d4
	addx.l	d3,d3			; *2
	movem.l	d3-d5,fp_t+12
	add.l	d5,d5
	addx.l	d4,d4
	addx.l	d3,d3
	add.l	d5,d5
	addx.l	d4,d4
	addx.l	d3,d3			; *8
	move.l	fp_t+20,d0
	add.l	d0,d5
	move.l	fp_t+16,d0
	addx.l	d0,d4
	move.l	fp_t+12,d0
	addx.l	d0,d3			; *10
	rts
; fp_t = M (3 longs), fp_s = s (fraction bits, > 0), fp_thr: out d7 = M >> s (low 32 bits),
; d0.w = -1: fraction < half - thr (round down), 0: |fraction - half| <= thr (tie: away), 1: above
.split:	movem.l	fp_t,d3-d5
	moveq	#0,d6			; shift M right by s into d3:d4:d5, the fraction into d6:d7 (64 bits)
	moveq	#0,d7			; (s < 96 + 64 in practice)
	move.w	fp_s,d0
.s32:	cmp.w	#32,d0
	blo.s	.s1
	move.l	d6,d7
	move.l	d5,d6
	move.l	d4,d5
	move.l	d3,d4
	moveq	#0,d3
	sub.w	#32,d0
	bra.s	.s32
.s1:	tst.w	d0
	beq.s	.sd
.s1l:	lsr.l	#1,d3
	roxr.l	#1,d4
	roxr.l	#1,d5
	roxr.l	#1,d6
	roxr.l	#1,d7
	subq.w	#1,d0
	bne.s	.s1l
.sd:	; integer part d5 (d3, d4 zero for the game's values); fraction F = d6:d7 as a 64-bit
	; fixed-point number (F / 2^64); half = 2^63; thr in the same units: thr * 2^(64-s)
	move.l	d5,-(sp)
	move.l	fp_thr,d2		; T = thr << (64 - s): shift a 64-bit 0:thr left by 64-s
	moveq	#0,d1
	move.w	#64,d0
	sub.w	fp_s,d0
	bmi.s	.tsmall
.tl:	tst.w	d0
	beq.s	.td
	add.l	d2,d2
	addx.l	d1,d1
	subq.w	#1,d0
	bra.s	.tl
.tsmall:neg.w	d0			; s > 64: T = thr >> (s-64)
.tr:	lsr.l	#1,d1
	roxr.l	#1,d2
	subq.w	#1,d0
	bne.s	.tr
.td:	; diff = F - 2^63 (signed 64-bit) in d6:d7
	sub.l	#$80000000,d6
	; |diff| <= T ?  diff < -T: below; diff > T: above
	tst.l	d6
	bmi.s	.neg2
	cmp.l	d1,d6			; diff >= 0: compare with T
	bhi.s	.above
	blo.s	.near
	cmp.l	d2,d7
	bhi.s	.above
.near:	moveq	#0,d0
	bra.s	.sx
.neg2:	neg.l	d7			; |diff|
	negx.l	d6
	cmp.l	d1,d6
	bhi.s	.below
	blo.s	.near
	cmp.l	d2,d7
	bhi.s	.below
	bra.s	.near
.above:	moveq	#1,d0
	bra.s	.sx
.below:	moveq	#-1,d0
.sx:	move.l	(sp)+,d7
	rts

	section	data
fp_sp:		dc.l	fp_stack-FP_SLOT
fp_mode:	dc.w	0
	include	"fpconst.i"		; build/: tools/mkfpconst.py (2/pi, pi/2 parts, series)
	even
	include	"fpstab.i"		; build/: tools/sincos_model.py --table (fpi_fsc: Pm, h, sin/cos(j/512))
	even

	section	bss
fp_stack:	ds.b	16*FP_SLOT
fp_ops:		ds.l	4
fp_prod:	ds.l	4
fp_sq:		ds.l	3
fp_t:		ds.l	6
fp_q:		ds.l	2		; fpx_div's quotient digits
fp_tx:		ds.l	3
fp_thr:		ds.l	1
fp_s:		ds.w	1
fp_buf:		ds.b	44
fps_key:	ds.w	5		; fpi_sincos: the last argument (se, mantissa) and its results
fps_res:	ds.w	12		; sin, cos (12-byte slots)
fps_xs:		ds.w	6
fps_xc:		ds.w	6
fps_t:		ds.l	3		; fpi_fsc's numbers (big-endian longs)
fps_bm:		ds.l	2
fps_a2:		ds.l	4
fps_p:		ds.l	6
fps_q:		ds.l	2
fps_q2:		ds.l	2
fps_es:		ds.l	2
fps_ec:		ds.l	2
fps_cb:		ds.l	3
fps_cbe:	ds.l	2
fps_sbx:	ds.l	3
fps_sbe:	ds.l	2
fps_sec:	ds.l	3
fps_cec:	ds.l	3
fps_sa:		ds.l	3
fps_ca:		ds.l	3
fps_k:		ds.w	1
fps_se:		ds.w	1
fps_kok:	ds.b	1
fps_sr:		ds.b	1
fps_sb:		ds.b	1
		even
