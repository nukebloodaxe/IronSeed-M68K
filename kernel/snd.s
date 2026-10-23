; snd.s - DMA sound: ring buffer refilled from the VBL, N-voice mixer. Part of kernel.s.
; The mixing arithmetic is the integer model of tools/modref.py (see its docstring).
;
; snd_set_rate   in: d0.w = 0 for 12517 Hz, 1 for 6258 Hz (restarts the DMA)
; snd_capture    in: a0 = buffer, d0.l = bytes (0 = off): also copy every mixed pair there
; snd_cpu        out: d0.l = 200 Hz ticks spent mixing since start (for measurements)
; snd_mute       in: d0.b = bit mask of MOD channels to leave out of the mix (CPU budget:
;                each silent voice saves ~57 cycles per output sample). Replay still runs.
; snd_vbl        called by the VBL handler (vid.s); saves everything it uses

SND_RING	equ	4096		; bytes = 1024 stereo pairs (82 ms at 12517 Hz)
SND_CHUNK	equ	1024		; most pairs mixed in one go

	section	text
snd_init:
	moveq	#0,d0
	bra	snd_set_rate

snd_exit:
	clr.w	snd_ready
	clr.b	SND_CTL.w
	rts

snd_set_rate:
	DI
	clr.b	SND_CTL.w
	move.w	d0,snd_rate
	lea	snd_step12,a0
	lea	snd_tick12,a1
	moveq	#%00000001,d1		; stereo, 12517 Hz ([PB-5 J.2]: bits 1-0 = 00 6258, 01 12517)
	tst.w	d0
	beq.s	.r
	lea	snd_step6,a0
	lea	snd_tick6,a1
	moveq	#%00000000,d1
.r:	move.l	a0,snd_steptab
	move.l	a1,snd_ticktab
	move.b	d1,SND_MODE.w
	lea	snd_ring,a0		; silence, then start the loop
	move.w	#SND_RING/4-1,d0
.z:	clr.l	(a0)+
	dbf	d0,.z
	move.l	#snd_ring,d0
	move.b	d0,SND_START+4.w
	lsr.l	#8,d0
	move.b	d0,SND_START+2.w
	lsr.l	#8,d0
	move.b	d0,SND_START.w
	move.l	#snd_ring+SND_RING,d0
	move.b	d0,SND_END+4.w
	lsr.l	#8,d0
	move.b	d0,SND_END+2.w
	lsr.l	#8,d0
	move.b	d0,SND_END.w
	clr.w	snd_wpos
	move.b	#3,SND_CTL.w		; play, repeat
	move.w	#1,snd_ready
	EI
	rts

snd_capture:
	move.l	a0,snd_cap
	add.l	a0,d0
	move.l	d0,snd_capend
	rts

snd_cpu:
	move.l	snd_ticks,d0
	rts

snd_mute:
	move.b	d0,snd_mutemask
	rts

; ---------------------------------------------------------------
snd_vbl:
	tst.w	snd_ready		; the VBL runs before snd_init: the DMA counter means nothing yet
	bne.s	.go
	rts
.go:	movem.l	d0-d7/a0-a6,-(sp)
	move.l	HZ200.w,-(sp)
	lea	SND_COUNT.w,a1
	movep.l	0(a1),d0		; play position
	lsr.l	#8,d0
	and.l	#$00fffffe,d0
	sub.l	#snd_ring,d0
	subq.l	#8,d0			; stay clear of the 4-word FIFO
	bpl.s	.p
	add.l	#SND_RING,d0
.p:	move.w	snd_wpos,d1
	sub.w	d1,d0			; bytes free
	bpl.s	.q
	add.w	#SND_RING,d0
.q:	lsr.w	#1,d0			; pairs
	beq.s	.x
	cmp.w	#SND_RING/2,d0		; sanity (a bad counter read must not hog the CPU)
	bhi.s	.x
	bsr	snd_fill
.x:	move.l	HZ200.w,d0
	sub.l	(sp)+,d0
	add.l	d0,snd_ticks
	movem.l	(sp)+,d0-d7/a0-a6
	rts

; snd_fill: d0.w = pairs to produce into the ring at snd_wpos
snd_fill:
	move.w	d0,snd_need
.loop:	tst.w	snd_need
	beq	.done
	tst.w	mod_on
	beq.s	.silent
	tst.w	mod_tickleft
	bne.s	.mix
	bsr	mod_tick
	bra.s	.loop
.mix:	move.w	snd_need,d0
	cmp.w	mod_tickleft,d0
	bls.s	.m1
	move.w	mod_tickleft,d0
.m1:	cmp.w	#SND_CHUNK,d0
	bls.s	.m2
	move.w	#SND_CHUNK,d0
.m2:	sub.w	d0,snd_need
	sub.w	d0,mod_tickleft
	move.w	d0,snd_k
	bsr	snd_mix
	bsr	snd_out
	bra.s	.loop
.silent:
	move.w	snd_need,d0
	cmp.w	#SND_CHUNK,d0
	bls.s	.s1
	move.w	#SND_CHUNK,d0
.s1:	sub.w	d0,snd_need
	move.w	d0,snd_k
	lea	snd_accl,a0		; zero both sides
	lea	snd_accr,a1
	subq.w	#1,d0
.sz:	clr.b	(a0)+
	clr.b	(a1)+
	dbf	d0,.sz
	bsr	snd_out
	bra	.loop
.done:	rts

; snd_mix: mix snd_k samples of every active voice into snd_accl / snd_accr
snd_mix:
	clr.w	snd_wrote		; bit 0 left side written, bit 1 right
	lea	mod_chans,a3
	move.w	mod_ch,d0
	subq.w	#1,d0
	move.w	d0,snd_vcnt
	move.w	mod_ch,d0		; volume table for this channel count
	lea	snd_vt2,a5
	cmp.w	#6,d0
	bne.s	.v8
	lea	snd_vt3,a5
.v8:	cmp.w	#8,d0
	bne.s	.voice
	lea	snd_vt4,a5
.voice:	tst.b	CH_ON(a3)
	beq	.nextv
	move.w	mod_ch,d0		; channel number = ch - 1 - vcnt
	subq.w	#1,d0
	sub.w	snd_vcnt,d0
	btst	d0,snd_mutemask
	bne	.nextv
	move.w	CH_OUTPER(a3),d0
	beq	.nextv
	cmp.w	#1023,d0
	bls.s	.pk
	move.w	#1023,d0
.pk:	lsl.w	#2,d0
	move.l	snd_steptab,a0
	move.l	0(a0,d0.w),d4		; step 16.16
	move.w	d4,d3			; frac step
	swap	d4			; int step (low word)
	move.l	CH_SMP(a3),a4
	move.l	SMP_ADDR(a4),a1
	add.l	CH_POS(a3),a1		; sample base for this chunk
	move.w	CH_VOL(a3),d0
	lsl.w	#8,d0
	lea	0(a5,d0.w),a2		; volume row
	moveq	#1,d6			; side bit
	lea	snd_accl,a0
	tst.b	CH_SIDE(a3)
	beq.s	.l
	moveq	#2,d6
	lea	snd_accr,a0
.l:	move.w	CH_FRAC(a3),d1
	moveq	#0,d2			; offset from a1
	moveq	#0,d0
	; Duff's device: d7 = k/8 passes, enter so the first pass does k%8 (or 8) samples
	move.w	snd_k,d7
	move.w	d7,d5
	and.w	#7,d5
	bne.s	.r
	moveq	#8,d5
.r:	sub.w	d5,d7
	lsr.w	#3,d7			; full passes after the first
	neg.w	d5
	addq.w	#8,d5			; blocks to skip
	move.w	snd_wrote,d0
	and.w	d6,d0
	bne.s	.add
	or.w	d6,snd_wrote		; first voice on this side: write
	moveq	#0,d0
	mulu	#WBLK,d5
	lea	.wl(pc),a6
	add.w	d5,a6
	jmp	(a6)
.wl:
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	dbf	d7,.wl
	bra	.done
.add:	moveq	#0,d0
	mulu	#ABLK,d5
	lea	.al(pc),a6
	add.w	d5,a6
	jmp	(a6)
.al:
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),d5
	add.b	d5,(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),d5
	add.b	d5,(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),d5
	add.b	d5,(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),d5
	add.b	d5,(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),d5
	add.b	d5,(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),d5
	add.b	d5,(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),d5
	add.b	d5,(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	move.b	0(a1,d2.w),d0
	move.b	0(a2,d0.w),d5
	add.b	d5,(a0)+
	add.w	d3,d1
	addx.w	d4,d2
	dbf	d7,.al
.done:	move.w	d1,CH_FRAC(a3)
	ext.l	d2
	add.l	CH_POS(a3),d2		; new position
	move.l	SMP_LL(a4),d0
	beq.s	.noloop
	move.l	SMP_LS(a4),d1
	add.l	d0,d1			; loop end
.wr:	cmp.l	d1,d2
	blo.s	.st
	sub.l	d0,d2
	bra.s	.wr
.noloop:
	cmp.l	SMP_LEN(a4),d2
	blo.s	.st
	clr.b	CH_ON(a3)
.st:	move.l	d2,CH_POS(a3)
.nextv:	lea	CH_SIZE(a3),a3
	subq.w	#1,snd_vcnt
	bpl	.voice
	; sides nobody wrote: silence
	btst	#0,snd_wrote+1
	bne.s	.zr
	lea	snd_accl,a0
	bsr.s	.zero
.zr:	btst	#1,snd_wrote+1
	bne.s	.x
	lea	snd_accr,a0
.zero:	move.w	snd_k,d0
	addq.w	#3,d0
	lsr.w	#2,d0
	subq.w	#1,d0
.z:	clr.l	(a0)+
	dbf	d0,.z
.x:	rts

WBLK	equ	12			; bytes per unrolled sample, write variant
ABLK	equ	14			; add variant

; snd_out: interleave snd_k pairs into the ring at snd_wpos (two runs around the wrap),
; then into the capture buffer if one is set
snd_out:
	lea	snd_accl,a1
	lea	snd_accr,a2
	lea	snd_ring,a0
	move.w	snd_wpos,d0
	add.w	d0,a0
	move.w	#SND_RING,d1
	sub.w	d0,d1
	lsr.w	#1,d1			; pairs before the wrap
	move.w	snd_k,d7
	cmp.w	d1,d7
	bls.s	.one
	sub.w	d1,d7			; second run
	subq.w	#1,d1
.o1:	move.b	(a1)+,(a0)+
	move.b	(a2)+,(a0)+
	dbf	d1,.o1
	lea	snd_ring,a0
.one:	subq.w	#1,d7
.o2:	move.b	(a1)+,(a0)+
	move.b	(a2)+,(a0)+
	dbf	d7,.o2
	sub.l	#snd_ring,a0
	cmp.w	#SND_RING,a0
	bne.s	.w
	sub.l	a0,a0
.w:	move.w	a0,snd_wpos
	move.l	snd_cap,d0		; capture (tests)
	beq.s	.x
	move.l	d0,a0
	lea	snd_accl,a1
	lea	snd_accr,a2
	move.w	snd_k,d7
	subq.w	#1,d7
.c:	cmp.l	snd_capend,a0
	bhs.s	.cx
	move.b	(a1)+,(a0)+
	move.b	(a2)+,(a0)+
	dbf	d7,.c
.cx:	move.l	a0,snd_cap
.x:	rts

	section	data
	include	"snd_tables.i"
	even

	section	bss
snd_steptab:	ds.l	1
snd_ticktab:	ds.l	1
snd_cap:	ds.l	1
snd_capend:	ds.l	1
snd_ticks:	ds.l	1
snd_rate:	ds.w	1
snd_ready:	ds.w	1
snd_wpos:	ds.w	1
snd_need:	ds.w	1
snd_k:		ds.w	1
snd_vcnt:	ds.w	1
snd_wrote:	ds.w	1
snd_mutemask:	ds.b	1
	even
snd_accl:	ds.b	SND_CHUNK+4
snd_accr:	ds.b	SND_CHUNK+4
	even
snd_ring:	ds.b	SND_RING
