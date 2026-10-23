; tim.s - timing. Part of kernel.s. Uses the TOS 200 Hz counter (_hz_200), so game
; speed does not depend on 50/60 Hz.
;
; tim_ticks   out: d0.l = 200 Hz ticks since boot
; tim_delay   in: d0.w = milliseconds (original delay()); waits at least that long
;             (advances a test script meanwhile)  trashes: d0-d1
; tim_ms      out: d0.l = milliseconds since tim_init (5 ms resolution)  trashes: d1
; rnd         in: d0.w = range n   out: d0.w = random 0..n-1 (Pascal random(n))  trashes: d1

	section	text
tim_init:
	move.l	HZ200.w,tim_base
	rts

tim_ticks:
	move.l	HZ200.w,d0
	rts

tim_ms:
	move.l	HZ200.w,d0
	sub.l	tim_base,d0
	move.l	d0,d1			; x5 (long)
	add.l	d0,d0
	add.l	d0,d0
	add.l	d1,d0
	rts

tim_delay:
	bsr	snd_poll		; the music stream refills here (changes no registers)
	and.l	#$ffff,d0
	tst.w	scr_vtime
	bne	scr_vdelay		; scripted test in virtual time: no real wait
	addq.l	#4,d0
	divu	#5,d0			; ms -> ticks, rounded up
	and.l	#$ffff,d0
	add.l	HZ200.w,d0
.w:	bsr	scr_tick		; test scripts keep running during waits
	move.l	HZ200.w,d1
	cmp.l	d0,d1
	blo.s	.w
	rts

	section	bss
tim_base:	ds.l	1

	section	text
rnd:
	move.w	d0,-(sp)
	move.l	rnd_seed,d0		; 32-bit LCG (Numerical Recipes); high word used
	mulu	#$660d,d0		; seed * 1664525 + 1013904223, done in 16-bit pieces:
	move.l	rnd_seed,d1		; lo*lo + ((hi*lo + lo*hi') << 16)
	swap	d1
	mulu	#$660d,d1
	swap	d1
	clr.w	d1
	add.l	d1,d0
	move.l	rnd_seed,d1
	mulu	#$0019,d1
	swap	d1
	clr.w	d1
	add.l	d1,d0
	add.l	#1013904223,d0
	move.l	d0,rnd_seed
	swap	d0
	mulu	(sp)+,d0		; (high word * n) >> 16
	swap	d0
	rts

	section	data
rnd_seed:	dc.l	1994
