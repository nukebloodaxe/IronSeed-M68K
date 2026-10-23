; tim.s - timing. Part of kernel.s. Uses the TOS 200 Hz counter (_hz_200), so game
; speed does not depend on 50/60 Hz.
;
; tim_ticks   out: d0.l = 200 Hz ticks since boot
; tim_delay   in: d0.w = milliseconds (original delay()); waits at least that long
;             trashes: d0-d1
; tim_ms      out: d0.l = milliseconds since tim_init (5 ms resolution)  trashes: d1

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
	and.l	#$ffff,d0
	addq.l	#4,d0
	divu	#5,d0			; ms -> ticks, rounded up
	and.l	#$ffff,d0
	add.l	HZ200.w,d0
.w:	move.l	HZ200.w,d1
	cmp.l	d0,d1
	blo.s	.w
	rts

	section	bss
tim_base:	ds.l	1
