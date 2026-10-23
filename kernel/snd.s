; snd.s - DMA sound: ring buffer refilled from the VBL, N-voice mixer. Part of kernel.s.
; The mixing arithmetic is the integer model of tools/modref.py (see its docstring).
;
; snd_set_rate   in: d0.w = 0 for 12517 Hz, 1 for 6258 Hz (restarts the DMA)
; snd_capture    in: a0 = buffer, d0.l = bytes (0 = off): also copy every mixed pair there
; snd_cpu        out: d0.l = 200 Hz ticks spent mixing since start (for measurements)
; snd_mute       in: d0.b = bit mask of MOD channels to leave out of the mix (CPU budget:
;                each silent voice saves ~57 cycles per output sample). Replay still runs.
; snd_budget     in: d0.w = most MOD voices to mix (0 = all, the default; SND_BUDGET at build
;                time sets the start value): each chunk mixes the loudest ones (CH_VOL; on a tie
;                the lower channel), the others only move on through their samples (snd_skipv),
;                so they come back in step. A CPU budget for 6/8-channel MODs on busy screens.
; snd_vbl        called by the VBL handler (vid.s); saves everything it uses

SND_RING	equ	4096		; bytes = 1024 stereo pairs (82 ms at 12517 Hz)
SND_CHUNK	equ	1024		; most pairs mixed in one go
SFX_SLOTS	equ	2		; simultaneous sound effects

	section	text
snd_init:
	bsr	mod_region_init
	moveq	#1,d0			; 6258 Hz: David's choice (warmer than 12517 on the STE)
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
	clr.l	snd_pairs		; pair numbers (snd_sfxlog) count from the capture start
	clr.l	snd_sfxlog
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

snd_budget:
	move.w	d0,snd_maxv
	clr.b	snd_budmask		; (chosen again at the next tick)
	rts

; snd_sfx_load  in: a0 = file name, a1 = sample entry (SMP_SIZE bytes, caller's)
;               loads a signed 8-bit .SAM with zero padding for the mixer. carry on error.
;               trashes d0-d2/a0-a2
snd_sfx_load:
	movem.l	d3/a3-a4,-(sp)
	move.l	a0,a4
	move.l	a1,a3
	bsr	fil_size
	bcs.s	.err
	move.l	d0,d3
	add.l	#MOD_PAD,d0
	bsr	mem_alloc
	bcs.s	.err
	move.l	a0,SMP_ADDR(a3)
	move.l	d3,SMP_LEN(a3)
	clr.l	SMP_LS(a3)
	clr.l	SMP_LL(a3)
	move.w	#64,SMP_VOL(a3)
	lea	0(a0,d3.l),a1		; zero the padding (bytes: a .SAM can have an odd length)
	move.w	#MOD_PAD-1,d0
.z:	clr.b	(a1)+
	dbf	d0,.z
	move.l	a4,a0
	move.l	SMP_ADDR(a3),a1
	move.l	d3,d0
	bsr	fil_load
	bcs.s	.err
	movem.l	(sp)+,d3/a3-a4
	and.b	#$fe,ccr
	rts
.err:	movem.l	(sp)+,d3/a3-a4
	or.b	#1,ccr
	rts

; snd_sfx_play  in: a0 = loaded sample entry, d0.w = playback rate in Hz (original soundeffect)
;               Uses a free slot, else replaces the oldest. trashes d0-d2/a0-a2
snd_sfx_play:
	moveq	#0,d2			; output rate
	move.w	#6258,d2
	tst.w	snd_rate
	bne.s	.r
	move.w	#12517,d2
.r:	moveq	#0,d1
	move.w	d0,d1
	divu	d2,d1			; d1.w = rate / out, high word = remainder
	moveq	#0,d0
	move.w	d1,d0
	swap	d0			; integer part << 16
	clr.w	d1			; remainder << 16
	divu	d2,d1			; = fraction (remainder < out, so it fits)
	move.w	d1,d0			; step 16.16 = rate * 65536 // out
	lea	snd_sfxch,a1
	moveq	#SFX_SLOTS-1,d1
.f:	tst.b	CH_ON(a1)
	beq.s	.use
	lea	CH_SIZE(a1),a1
	dbf	d1,.f
	move.w	snd_sfxnext,d1		; all busy: round robin
	addq.w	#1,snd_sfxnext
	and.w	#SFX_SLOTS-1,snd_sfxnext
	mulu	#CH_SIZE,d1
	lea	snd_sfxch,a1
	add.w	d1,a1
.use:	DI
	move.l	a0,CH_SMP(a1)
	clr.l	CH_POS(a1)
	clr.w	CH_FRAC(a1)
	move.w	#64,CH_VOL(a1)
	clr.w	CH_DELAY(a1)
	move.l	a1,d1			; step slot = same index
	sub.l	#snd_sfxch,d1
	divu	#CH_SIZE,d1
	lsl.w	#2,d1
	lea	snd_sfxstep,a2
	move.l	d0,0(a2,d1.w)
	st	CH_ON(a1)
	EI
	rts

; snd_sfx_room  in: d0.w = 1 to reserve mixing headroom for sound effects (music one
;               voice quieter so music + effect can't overflow), 0 for none. Set per screen.
snd_sfx_room:
	move.w	d0,snd_sfxroom
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
	beq.s	.nomus
	tst.w	mod_tickleft
	bne.s	.mix
	bsr	mod_tick
	tst.w	snd_maxv		; the voice budget: chosen once a tick (volumes change on ticks)
	beq.s	.loop
	bsr	snd_pickvoices
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
.nomus:	move.w	snd_need,d0		; no music: chunks of up to SND_CHUNK (SFX only, or silence)
	cmp.w	#SND_CHUNK,d0
	bls.s	.s1
	move.w	#SND_CHUNK,d0
.s1:	sub.w	d0,snd_need
	move.w	d0,snd_k
	bsr	snd_mix
	bsr	snd_out
	bra	.loop
.done:	rts

; snd_mix: mix snd_k samples of every active voice into snd_accl / snd_accr
snd_mix:
	clr.w	snd_wrote		; bit 0 left side written, bit 1 right
	move.w	mod_ch,d0		; volume table: channels/2 (+1 with SFX headroom)
	lsr.w	#1,d0
	add.w	snd_sfxroom,d0
	subq.w	#2,d0
	lsl.w	#2,d0
	lea	snd_vtabs,a5
	move.l	0(a5,d0.w),a5
	move.l	a5,snd_vt
	tst.w	mod_on
	beq	.sfx
	lea	mod_chans,a3
	move.w	mod_ch,d0
	subq.w	#1,d0
	move.w	d0,snd_vcnt
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
	moveq	#1,d6			; side bit
	tst.b	CH_SIDE(a3)
	beq.s	.l
	moveq	#2,d6
.l:	move.w	mod_ch,d0		; over the budget this chunk: only move on
	subq.w	#1,d0
	sub.w	snd_vcnt,d0
	btst	d0,snd_budmask
	beq.s	.mx
	bsr	snd_skipv
	bra.s	.nextv
.mx:	move.l	snd_vt,a5
	bsr	snd_voice
.nextv:	lea	CH_SIZE(a3),a3
	subq.w	#1,snd_vcnt
	bpl	.voice
.sfx:	lea	snd_sfxch,a3		; sound effects: both sides, full volume
	lea	snd_sfxstep,a4
	moveq	#SFX_SLOTS-1,d0
.sl:	move.w	d0,snd_vcnt
	tst.b	CH_ON(a3)
	beq.s	.ns
	move.l	a4,-(sp)
	tst.l	snd_sfxlog		; first chunk of this effect: log the output pair (tests)
	bne.s	.lg
	tst.w	CH_DELAY(a3)
	bne.s	.lg
	move.l	snd_pairs,snd_sfxlog
.lg:	move.w	#1,CH_DELAY(a3)		; (CH_DELAY = "started" flag for SFX slots)
	move.l	CH_POS(a3),-(sp)	; left pass, then rewind for the right pass
	move.w	CH_FRAC(a3),-(sp)
	move.l	(a4),d4
	moveq	#1,d6
	move.l	snd_vt,a5
	bsr	snd_voice
	move.w	(sp)+,CH_FRAC(a3)
	move.l	(sp)+,CH_POS(a3)
	st	CH_ON(a3)
	move.l	(sp),a4
	move.l	(a4),d4
	moveq	#2,d6
	move.l	snd_vt,a5
	bsr	snd_voice
	move.l	(sp)+,a4
.ns:	lea	CH_SIZE(a3),a3
	addq.l	#4,a4
	move.w	snd_vcnt,d0
	dbf	d0,.sl
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
.x:	move.w	snd_k,d0
	ext.l	d0
	add.l	d0,snd_pairs
	rts

snd_vtabs:	dc.l	snd_vt2,snd_vt3,snd_vt4,snd_vt5

; snd_pickvoices: snd_budmask := the voices beyond the budget (snd_maxv): of the playing,
; unmuted ones, the quietest go first (on a tie the higher channel). trashes d0-d6/a0-a1
snd_pickvoices:
	lea	snd_bkeys,a1		; key per voice: vol*16 + 15-channel ($7fff: not playing)
	lea	mod_chans,a0
	moveq	#0,d2			; channel
	moveq	#0,d3			; voices that would play
.c:	move.w	#$7fff,d0
	tst.b	CH_ON(a0)
	beq.s	.k
	tst.w	CH_OUTPER(a0)
	beq.s	.k
	btst	d2,snd_mutemask
	bne.s	.k
	addq.w	#1,d3
	move.w	CH_VOL(a0),d0
	lsl.w	#4,d0
	add.w	#15,d0
	sub.w	d2,d0
.k:	move.w	d0,(a1)+
	lea	CH_SIZE(a0),a0
	addq.w	#1,d2
	cmp.w	mod_ch,d2
	blo.s	.c
	moveq	#0,d5			; voices left out
	sub.w	snd_maxv,d3		; how many
	ble.s	.done
	subq.w	#1,d3
.out:	lea	snd_bkeys,a1		; the smallest key left
	move.w	#$7fff,d6
	moveq	#0,d2
.m:	move.w	(a1)+,d0
	cmp.w	d6,d0
	bhs.s	.mn
	move.w	d0,d6
	move.w	d2,d4
.mn:	addq.w	#1,d2
	cmp.w	mod_ch,d2
	blo.s	.m
	bset	d4,d5
	add.w	d4,d4
	lea	snd_bkeys,a1
	move.w	#$7fff,0(a1,d4.w)
	dbf	d3,.out
.done:	move.b	d5,snd_budmask
	rts

; snd_skipv: move a voice on by snd_k samples without mixing it (the position snd_voice would
; leave). in: a3 = channel, d4.l = step 16.16   trashes d0-d2/a4
snd_skipv:
	move.w	snd_k,d0
	moveq	#0,d1
	move.w	d4,d1
	mulu	d0,d1			; k * frac step
	moveq	#0,d2
	move.w	CH_FRAC(a3),d2
	add.l	d2,d1
	move.w	d1,CH_FRAC(a3)
	clr.w	d1
	swap	d1			; the carries
	move.l	d4,d2
	swap	d2
	mulu	d0,d2			; k * int step
	add.l	d1,d2
	add.l	CH_POS(a3),d2		; new position
	move.l	CH_SMP(a3),a4
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
	rts

; snd_voice: mix snd_k samples of one voice into one side.
; in: a3 = channel (CH_*), a5 = volume table, d4.l = step 16.16, d6 = side bit (1 L, 2 R)
; trashes d0-d7/a0-a2/a4/a6
snd_voice:
	move.w	d4,d3			; frac step
	swap	d4			; int step
	move.l	CH_SMP(a3),a4
	move.l	SMP_ADDR(a4),a1
	add.l	CH_POS(a3),a1		; sample base for this chunk
	move.w	CH_VOL(a3),d0
	lsl.w	#8,d0
	lea	0(a5,d0.w),a2		; volume row
	lea	snd_accl,a0
	cmp.w	#1,d6
	beq.s	.l
	lea	snd_accr,a0
.l:	move.w	CH_FRAC(a3),d1
	moveq	#0,d2			; offset from a1
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
	rts

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
	ifnd	SND_BUDGET
SND_BUDGET	equ	0		; ASMDEFS=-DSND_BUDGET=4: mix at most 4 MOD voices (snd_budget)
	endc
snd_maxv:	dc.w	SND_BUDGET
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
snd_sfxroom:	ds.w	1
snd_sfxnext:	ds.w	1
snd_vt:		ds.l	1
snd_pairs:	ds.l	1		; output pairs mixed so far
snd_sfxlog:	ds.l	1		; snd_pairs when the first effect started (tests)
snd_sfxstep:	ds.l	SFX_SLOTS
snd_sfxch:	ds.b	SFX_SLOTS*CH_SIZE
snd_mutemask:	ds.b	1
snd_budmask:	ds.b	1		; this tick's voices beyond the budget
	even
snd_bkeys:	ds.w	8
	even
snd_accl:	ds.b	SND_CHUNK+4
snd_accr:	ds.b	SND_CHUNK+4
	even
snd_ring:	ds.b	SND_RING
