; mt.s - Free Pascal 3.2's random generator (MT19937; rtl/inc/system.inc), so the port's random
; sequences match the original's exactly (the oracle runs with randseed 1994). Part of kernel.s.
;
; mt_seed     in: d0.l = seed (FPC randseed)                       trashes: d0-d2/a0-a1
; mt_u32      out: d0.l = next 32-bit number (mtwist_u32rand)       trashes: d1-d2/a0
; mt_random   in: d0.w = l (1..65535)  out: d0.l = random(l) = (u32 * l) >> 32   trashes: d1-d2/a0
;mt_skip      in: d0.l = n: advances the generator as n calls would (fast)   trashes: d0-d2/a0-a1
; mt_randomize  seed from the clock (FPC randomize); scripted test runs (scr_test) use 1994,
;             like the oracle build.                                trashes: d0-d2/a0-a1
; The original program calls random(l) with l < 65536 everywhere in the ported code.

MT_N	equ	624
MT_M	equ	397

	section	text
mt_randomize:
	moveq	#0,d0
	move.w	#1994,d0
	tst.w	scr_test
	bne.s	mt_seed
	move.l	HZ200.w,d0
	move.w	#$17,-(sp)		; Gettime (xbios 23): date and time
	trap	#14
	addq.l	#2,sp
	add.l	HZ200.w,d0
	; fall through
mt_seed:
	movem.l	d3-d4,-(sp)
	lea	mt_state,a0
	move.l	d0,(a0)+
	moveq	#1,d3			; i
.i:	move.l	d0,d1			; x = prev ^ (prev >> 30)
	moveq	#30,d2
	lsr.l	d2,d1
	eor.l	d1,d0
	; d0 = x * $6C078965 + i  (low 32 bits)
	move.l	d0,d1
	swap	d1			; x.hi
	mulu	#$8965,d1		; x.hi * lo
	move.l	d0,d2
	mulu	#$6C07,d2		; x.lo * hi
	add.l	d2,d1
	swap	d1
	clr.w	d1			; cross terms << 16
	mulu	#$8965,d0		; x.lo * lo
	add.l	d1,d0
	add.l	d3,d0
	move.l	d0,(a0)+
	addq.w	#1,d3
	cmp.w	#MT_N,d3
	bne.s	.i
	move.w	#MT_N,mt_index
	movem.l	(sp)+,d3-d4
	rts

; regenerate the 624 words (mtwist_update_state)
mt_update:
	movem.l	d3-d5/a1,-(sp)
	move.l	#$9908B0DF,d5
	lea	mt_state,a0		; mt[k]
	lea	MT_M*4(a0),a1		; mt[k + M]
	move.w	#MT_N-MT_M-1,d4		; k = 0 .. N-M-1
	bsr.s	.run
	lea	mt_state,a1		; mt[k + M - N]
	move.w	#MT_M-1-1,d4		; k = N-M .. N-2
	bsr.s	.run
	move.l	mt_state,d1		; mt[N-1] = mt[M-1] ^ twist(mt[N-1], mt[0])
	bsr.s	.tw
	move.l	(a1),d1			; (a1 = mt[M-1] now)
	eor.l	d1,d0
	move.l	d0,(a0)
	movem.l	(sp)+,d3-d5/a1
	rts
.run:	move.l	4(a0),d1
	bsr.s	.tw
	move.l	(a1)+,d1
	eor.l	d1,d0
	move.l	d0,(a0)+
	dbf	d4,.run
	rts
; d0 = twist(u = (a0), v = d1) = (mixbits(u, v) >> 1) ^ (odd(v) ? $9908B0DF : 0)   trashes d2
.tw:	move.l	(a0),d0
	and.l	#$80000000,d0
	move.l	d1,d2
	and.l	#$7fffffff,d2
	or.l	d2,d0
	lsr.l	#1,d0
	btst	#0,d1
	beq.s	.t0
	eor.l	d5,d0
.t0:	rts

mt_u32:
	move.w	mt_index,d0
	cmp.w	#MT_N,d0
	blo.s	.ok
	bsr	mt_update
	moveq	#0,d0
.ok:	move.w	d0,d1
	addq.w	#1,d1
	move.w	d1,mt_index
	lsl.w	#2,d0
	lea	mt_state,a0
	move.l	0(a0,d0.w),d0
	move.l	d0,d1			; y ^= y >> 11
	moveq	#11,d2
	lsr.l	d2,d1
	eor.l	d1,d0
	move.l	d0,d1			; y ^= (y << 7) & $9D2C5680
	lsl.l	#7,d1
	and.l	#$9D2C5680,d1
	eor.l	d1,d0
	move.l	d0,d1			; y ^= (y << 15) & $EFC60000
	moveq	#15,d2
	lsl.l	d2,d1
	and.l	#$EFC60000,d1
	eor.l	d1,d0
	move.l	d0,d1			; y ^= y >> 18
	moveq	#18,d2
	lsr.l	d2,d1
	eor.l	d1,d0
	rts

mt_skip:
	move.l	d3,-(sp)
	move.l	d0,d3
.l:	tst.l	d3
	beq.s	.x
	move.w	mt_index,d0
	cmp.w	#MT_N,d0
	blo.s	.ok
	bsr	mt_update
	clr.w	mt_index
	moveq	#0,d0
.ok:	move.l	#MT_N,d1		; k = min(n, N - index)
	sub.w	d0,d1
	cmp.l	d3,d1
	bls.s	.k
	move.l	d3,d1
.k:	add.w	d1,mt_index
	sub.l	d1,d3
	bra.s	.l
.x:	move.l	(sp)+,d3
	rts

mt_random:
	move.w	d0,-(sp)
	bsr	mt_u32
	move.w	(sp)+,d2
	move.l	d0,d1
	mulu	d2,d0			; lo * l
	clr.w	d0
	swap	d0			; >> 16
	swap	d1
	mulu	d2,d1			; hi * l
	add.l	d1,d0
	clr.w	d0
	swap	d0			; >> 16
	rts

	section	bss
mt_state:	ds.l	MT_N
mt_index:	ds.w	1
	even
