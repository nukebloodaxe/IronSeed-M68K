; c2p.i - chunky->planar kernel shared by the spikes (include AFTER the entry code).
; Needs BANDH, luttabs (4*256 longs), chunky, and c2p_mac.i included earlier.

	section	text
; c2p_full: a0 = chunky (64000 bytes), a2 = screen. Trashes d0-d6/a0-a2.
c2p_full:
	lea	luttabs,a1
	moveq	#BANDH,d3
	move.w	#200-1,d5
.line:	moveq	#20-1,d1
.grp:	PIX8
	movep.l	d6,0(a2)
	PIX8
	movep.l	d6,1(a2)
	addq.l	#8,a2
	dbf	d1,.grp
	subq.w	#1,d3
	bne.s	.same
	lea	1024(a1),a1		; next band's table
	moveq	#BANDH,d3
.same:	dbf	d5,.line
	rts

; build_luts: 4 bands x 256 longs. Chunky value c -> colour index (c>>4)&15;
; entry = plane bit k placed in bit 0 of byte (3-k) (MOVEP writes byte 3 first).
build_luts:
	lea	luttabs,a0
	moveq	#4-1,d2
.band:	moveq	#0,d1			; c
.c:	move.w	d1,d0
	lsr.w	#4,d0
	and.w	#15,d0
	moveq	#0,d3
	btst	#0,d0
	beq.s	.b1
	or.l	#$01000000,d3
.b1:	btst	#1,d0
	beq.s	.b2
	or.l	#$00010000,d3
.b2:	btst	#2,d0
	beq.s	.b3
	or.l	#$00000100,d3
.b3:	btst	#3,d0
	beq.s	.b4
	or.l	#$00000001,d3
.b4:	move.l	d3,(a0)+
	addq.w	#1,d1
	cmp.w	#256,d1
	bne.s	.c
	dbf	d2,.band
	rts

; fill_chunky: value = (x + y) & 255 -> 16-pixel-wide diagonal stripes
fill_chunky:
	lea	chunky,a0
	moveq	#0,d1			; y
.y:	moveq	#0,d0			; x
.x:	move.w	d0,d2
	add.w	d1,d2
	move.b	d2,(a0)+
	addq.w	#1,d0
	cmp.w	#320,d0
	bne.s	.x
	addq.w	#1,d1
	cmp.w	#200,d1
	bne.s	.y
	rts

