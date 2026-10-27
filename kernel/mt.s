; mt.s - Free Pascal 3.2's random generator (MT19937; rtl/inc/system.inc), so the port's random
; sequences match the original's exactly (the oracle runs with randseed 1994). Part of kernel.s.
;
; mt_seed     in: d0.l = seed (FPC randseed)                       trashes: d0-d2/a0-a1
; mt_setseed  in: d0.l: the Pascal assignment randseed := d0 (lazy, as FPC: the generator is
;             seeded from it at the next draw, unless it equals the value the last seeding left in
;             randseed - which is how PushRand/PopRand restore a sequence)  trashes: nothing
; mt_getseed  out: d0.l = randseed (FPC's variable: after a seeding it holds not seed)
; mt_u32      out: d0.l = next 32-bit number (mtwist_u32rand)       trashes: d1-d2/a0
; mt_random   in: d0.w = l (1..65535)  out: d0.l = random(l) = (u32 * l) >> 32   trashes: d1-d2/a0
; mt_random64 in: d0.w = l (1..65535)  out: d0.l = FPC's random(int64 l): two draws a, b,
;             ((b << 32 | a) and $7FFF...) mod l. The x86-64 oracle build calls this overload
;             whenever the argument is an arithmetic expression (random(a+b), random(n-1), ...;
;             a plain variable or a constant takes random(longint)): port each call with the
;             overload the original's argument selects.           trashes: d1-d2/a0
; mt_random64l in: d0.l = l (>= 0): random(int64 l) for any longint l (0 gives 0, after the two
;             draws, as FPC)                                         trashes: d1-d2/a0
; mt_seedc    in: d0.l = seed: mt_seed and the first draw's regeneration done at once (the state
;             after mt_update, index 0: every later draw, skip and randseed exactly as after
;             mt_seed), from a cache of the last MT_CN seeds (2.5 KB each). For code that seeds
;             with the same few seeds again and again (Phase 6h: the system view's planet icons
;             and facts, every pass)                                trashes: d0-d2/a0-a1
;             (Phase 6i) a hit no longer copies: the draws read the kept state in place
;             (`mt_cur`), and mt_update - the only writer - copies it to mt_state first.
; mt_own      makes mt_state the generator's state (copies a kept state mt_seedc lent): call it
;             before reading or writing mt_state directly (the walks in utils2.s)  trashes: nothing
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
mt_setseed:
	move.l	d0,mt_rs
	rts
mt_getseed:
	move.l	mt_rs,d0
	rts

mt_seed:
	movem.l	d3-d4,-(sp)
	move.l	#mt_state,mt_cur	; (overwritten whole: nothing to copy back)
	move.l	d0,d1			; randseed and oldseed := not seed (FPC, after the seeding)
	not.l	d1
	move.l	d1,mt_rs
	move.l	d1,mt_old
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

mt_seedc:
	movem.l	d3-d7/a2-a3,-(sp)
	lea	mt_cache,a2
	moveq	#MT_CN-1,d1
.f:	tst.w	4(a2)
	beq.s	.n
	cmp.l	(a2),d0
	beq.s	.hit
.n:	lea	MT_CE(a2),a2
	dbf	d1,.f
	move.l	d0,-(sp)		; not kept: seed, regenerate, keep
	bsr	mt_seed
	bsr	mt_update
	clr.w	mt_index
	move.w	mt_cnext,d0
	move.w	d0,d1
	addq.w	#1,d1
	cmp.w	#MT_CN,d1
	blo.s	.w
	moveq	#0,d1
.w:	move.w	d1,mt_cnext
	mulu	#MT_CE,d0
	lea	mt_cache,a1
	add.l	d0,a1
	move.l	(sp)+,(a1)+		; the seed, valid
	move.w	#1,(a1)+
	addq.l	#2,a1
	lea	mt_state,a2
	bra.s	.cp
.hit:	not.l	d0			; randseed and oldseed := not seed, as mt_seed leaves them
	move.l	d0,mt_rs
	move.l	d0,mt_old
	clr.w	mt_index
	addq.l	#8,a2			; the draws read the kept state where it is
	move.l	a2,mt_cur
	movem.l	(sp)+,d3-d7/a2-a3
	rts
.cp:	moveq	#MT_N*4/32-1,d0		; 2496 bytes, 32 at a time
.c:	movem.l	(a2)+,d1-d7/a3
	movem.l	d1-d7/a3,(a1)
	lea	32(a1),a1
	dbf	d0,.c
	movem.l	(sp)+,d3-d7/a2-a3
	rts

mt_own:
	cmp.l	#mt_state,mt_cur
	bne.s	.cp
	rts
.cp:	movem.l	d0-d7/a0-a3,-(sp)
	move.l	mt_cur,a2
	lea	mt_state,a1
	move.l	a1,mt_cur
	moveq	#MT_N*4/32-1,d0
.c:	movem.l	(a2)+,d1-d7/a3
	movem.l	d1-d7/a3,(a1)
	lea	32(a1),a1
	dbf	d0,.c
	movem.l	(sp)+,d0-d7/a0-a3
	rts

; regenerate the 624 words (mtwist_update_state): mt[k] = mt[k+M] ^ twist(mt[k], mt[k+1]),
; twist(u, v) = (mixbits(u, v) >> 1) ^ (odd(v) ? $9908B0DF : 0)
mt_update:				; (keeps a2: createplanet's walk relies on it)
	bsr	mt_own			; a kept state lent by mt_seedc: copied first
	movem.l	d3-d5/a1-a2,-(sp)
	move.l	#$9908B0DF,d5
	lea	mt_state,a0		; mt[k]
	lea	4(a0),a2		; mt[k + 1]
	lea	MT_M*4(a0),a1		; mt[k + M]
	move.l	(a0),d0			; u = mt[0]
	move.w	#(MT_N-MT_M)/2-1,d4	; k = 0 .. N-M-1: 113 pairs and one
	bsr.s	.run2
	bsr.s	.run1
	lea	mt_state,a1		; mt[k + M - N]
	move.w	#(MT_M-1)/2-1,d4	; k = N-M .. N-2: 198 pairs
	bsr.s	.run2
	move.l	mt_state,d1		; mt[N-1] = mt[M-1] ^ twist(mt[N-1], mt[0])  (d0 = old mt[N-1])
	bsr.s	.tw
	move.l	(a1),d0
	eor.l	d0,d2
	move.l	d2,(a0)
	movem.l	(sp)+,d3-d5/a1-a2
	rts
; mt[k] = mt[k+M] ^ twist(u = mt[k], v = mt[k+1]), v the next u; d0 = u on entry and exit.
; twist: mixbits(u, v) >> 1 (v's low 31 bits under u's top bit; the last shift's carry is v's
; bit 0) ^ (odd(v) ? $9908B0DF : 0)
.run2:	move.l	(a2)+,d1		; v
	move.l	d1,d2
	add.l	d2,d2
	add.l	d0,d0
	roxr.l	#1,d2
	lsr.l	#1,d2
	bcc.s	.e1
	eor.l	d5,d2
.e1:	move.l	(a1)+,d0
	eor.l	d0,d2
	move.l	d2,(a0)+
	move.l	(a2)+,d0		; the next pair: u = d1, v -> d0
	move.l	d0,d2
	add.l	d2,d2
	add.l	d1,d1
	roxr.l	#1,d2
	lsr.l	#1,d2
	bcc.s	.e2
	eor.l	d5,d2
.e2:	move.l	(a1)+,d1
	eor.l	d1,d2
	move.l	d2,(a0)+
	dbf	d4,.run2
	rts
.run1:	move.l	(a2)+,d1
	move.l	d1,d2
	add.l	d2,d2
	add.l	d0,d0
	roxr.l	#1,d2
	lsr.l	#1,d2
	bcc.s	.e3
	eor.l	d5,d2
.e3:	move.l	(a1)+,d0
	eor.l	d0,d2
	move.l	d2,(a0)+
	move.l	d1,d0
	rts
.tw:	move.l	d1,d2			; d2 = twist(d0, d1)
	add.l	d2,d2
	add.l	d0,d0
	roxr.l	#1,d2
	lsr.l	#1,d2
	bcc.s	.t0
	eor.l	d5,d2
.t0:	rts

mt_u32:
	move.l	mt_rs,d0		; randseed changed since the last seeding: seed from it
	cmp.l	mt_old,d0
	beq.s	.same
	move.l	a1,-(sp)
	bsr	mt_seed
	move.l	(sp)+,a1
.same:	move.w	mt_index,d0
	cmp.w	#MT_N,d0
	blo.s	.ok
	bsr	mt_update
	moveq	#0,d0
.ok:	move.w	d0,d1
	addq.w	#1,d1
	move.w	d1,mt_index
	lsl.w	#2,d0
	move.l	mt_cur,a0
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
	move.l	d0,d1			; y ^= y >> 18 (low word only)
	swap	d1
	lsr.w	#2,d1
	eor.w	d1,d0
	rts

mt_skip:
	move.l	d3,-(sp)
	move.l	d0,d3
	move.l	mt_rs,d0
	cmp.l	mt_old,d0
	beq.s	.l
	bsr	mt_seed
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

mt_random64:
	movem.l	d3-d4,-(sp)
	move.w	d0,d4			; l
	bsr	mt_u32
	move.l	d0,d3			; a: the low half
	bsr	mt_u32			; b: the high half, bit 63 masked off
	bclr	#31,d0
	moveq	#0,d1			; r := (r*65536 + word) mod l over bh, bl, ah, al
	swap	d0
	bsr.s	.step
	swap	d0
	bsr.s	.step
	move.l	d3,d0
	swap	d0
	bsr.s	.step
	swap	d0
	bsr.s	.step
	move.l	d1,d0
	movem.l	(sp)+,d3-d4
	rts
.step:	swap	d1			; r < l: the quotient fits 16 bits
	move.w	d0,d1
	divu	d4,d1
	swap	d1
	and.l	#$ffff,d1
	rts

mt_random64l:
	movem.l	d3-d5,-(sp)
	move.l	d0,d4			; l
	bsr	mt_u32
	move.l	d0,d3			; low half
	bsr	mt_u32
	bclr	#31,d0			; high half (63 bits)
	tst.l	d4
	beq.s	.zero
	moveq	#0,d1			; r := (r*2 + bit) mod l over the 64 bits
	moveq	#64-1,d5
.b:	add.l	d3,d3
	addx.l	d0,d0
	addx.l	d1,d1			; (r < l < 2^31: no carry out)
	cmp.l	d4,d1
	blo.s	.n
	sub.l	d4,d1
.n:	dbf	d5,.b
	move.l	d1,d0
	bra.s	.x
.zero:	moveq	#0,d0
.x:	movem.l	(sp)+,d3-d5
	rts

	section	bss
mt_rs:		ds.l	1		; FPC's randseed variable
mt_old:		ds.l	1		; and its oldrandseed
mt_state:	ds.l	MT_N
mt_index:	ds.w	1
	section	data
mt_cur:		dc.l	mt_state	; the state the draws read: mt_state or a kept one (mt_seedc)
	section	bss
MT_CN		equ	10		; mt_seedc's cache: seed.l, valid.w, pad.w, the state after mt_update
MT_CE		equ	8+MT_N*4
mt_cnext:	ds.w	1
mt_cache:	ds.b	MT_CN*MT_CE
	even
