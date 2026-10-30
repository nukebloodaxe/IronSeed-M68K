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
	ifd	PROFILE
	move.l	HZ200.w,-(sp)
	endif
.w:	bsr	scr_tick		; test scripts keep running during waits
	move.l	HZ200.w,d1
	cmp.l	d0,d1
	blo.s	.w
	ifd	PROFILE			; (idle 200 Hz ticks, logged with each script shot: tag 61)
	sub.l	(sp)+,d1
	add.l	d1,tim_idlet
	endif
	rts

; tim_pace: as tim_delay, for a main loop's frame: the wait ends d0.w ms after the previous
; tim_pace's end (a deadline), so the frame's own work counts against it; a late frame does not
; wait (the next one starts now). The original's loops are work + delay(tslice*n) with work tiny
; on a 486: pacing keeps the ST's frame rate near the original's instead of adding the delay to
; seconds of work. Game logic is unchanged (it counts frames); virtual time: exactly tim_delay.
; Phase 6n: catch-up (see .late; ASMDEFS=-DNOCATCH=1 = 6m). in: d0.w = ms  trashes: d0-d2/a0-a2
tim_pace:
	ifd	NOPACE
	bra	tim_delay		; (ASMDEFS=-DNOPACE=1: the old behaviour, for comparisons)
	endif
	bsr	snd_poll
	and.l	#$ffff,d0
	tst.w	scr_vtime
	bne	scr_vdelay
	addq.l	#4,d0
	divu	#5,d0			; ms -> ticks, rounded up
	and.l	#$ffff,d0
	move.l	d0,d2			; the period (ticks)
	add.l	tim_pdead,d0
	move.l	HZ200.w,d1
	cmp.l	d1,d0
	bls.s	.late
	move.l	d0,tim_pdead
	ifd	PROFILE
	move.l	d1,-(sp)
	endif
.w:	bsr	scr_tick
	move.l	HZ200.w,d1
	cmp.l	d0,d1
	blo.s	.w
	ifd	PROFILE
	sub.l	(sp)+,d1
	add.l	d1,tim_idlet
	endif
	rts
.late:	ifnd	NOCATCH
	mulu	#3,d2			; (Phase 6n) a frame late by up to 3 periods keeps its deadline:
	add.l	d0,d2			; the next frames wait less, so a loop whose work is uneven (the
	cmp.l	d1,d2			; bridge: one frame in four turns the planet) keeps the
	blo.s	.lt			; original's mean pace; later than that: start again from now
	move.l	d0,tim_pdead
	bra	scr_tick
.lt:
	endif
	move.l	d1,tim_pdead
	bra	scr_tick

	section	bss
tim_base:	ds.l	1
tim_pdead:	ds.l	1		; tim_pace's last deadline (200 Hz ticks)
tim_idlet:	ds.l	1		; (PROFILE: idle ticks in tim_delay/tim_pace)

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
