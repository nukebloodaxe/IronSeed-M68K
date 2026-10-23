; gfx.s - planar drawing with the original game's 256-colour indices. Part of kernel.s.
; Colours are mapped to the 16 slots of the band each line is in (vid_lut_y), so a
; primitive spanning a split uses each band's nearest colour.
; Drawing goes to gfx_target (default: the shown screen, set by gfx_set_target).
;
; gfx_set_target  in: a0 = screen
; gfx_pset        in: d0.w x, d1.w y, d2.b colour                 trashes: d0-d2/a0-a2
; gfx_span        in: d0.w x1, d1.w y, d2.w x2 (inclusive), d3.b colour   trashes: d0-d2/a0-a2
; gfx_bar         in: d0.w x1, d1.w y1, d2.w x2, d3.w y2, d4.b colour  (filled)   trashes: d0-d2/a0-a2
; gfx_rect        same arguments, outline only (original rectangle)
; gfx_line        in: d0.w x1, d1.w y1, d2.w x2, d3.w y2, d4.b colour   trashes: d0-d2/a0-a2
; No clipping beyond the screen edges: callers stay inside 0-319 / 0-199 like the original.

	section	text
gfx_set_target:
	move.l	a0,gfx_target
	rts

gfx_pset:
	bsr	vid_lut_y
	and.w	#$ff,d2
	move.b	0(a1,d2.w),d2		; slot
	move.l	gfx_target,a0
	mulu	#SCR_BPL,d1
	add.l	d1,a0
	move.w	d0,d1
	lsr.w	#4,d1
	lsl.w	#3,d1
	add.w	d1,a0			; group
	btst	#3,d0			; pixels 8-15 of the group live in the odd byte
	beq.s	.hi
	addq.l	#1,a0
.hi:	not.w	d0			; bit 7 - (x & 7) (bset/bclr on memory use bit mod 8)
	moveq	#4-1,d1
.p:	lsr.b	#1,d2
	bcc.s	.c
	bset	d0,(a0)
	bra.s	.n
.c:	bclr	d0,(a0)
.n:	addq.l	#2,a0
	dbf	d1,.p
	rts

gfx_span:
	movem.l	d3-d7,-(sp)
	cmp.w	d0,d2
	bge.s	.ord
	exg	d0,d2
.ord:	bsr	vid_lut_y
	and.w	#$ff,d3
	move.b	0(a1,d3.w),d3		; slot
	move.l	gfx_target,a0
	mulu	#SCR_BPL,d1
	add.l	d1,a0
	move.w	d0,d4
	lsr.w	#4,d4			; first group
	move.w	d2,d5
	lsr.w	#4,d5			; last group
	move.w	d4,d1
	lsl.w	#3,d1
	add.w	d1,a0
	and.w	#15,d0
	moveq	#-1,d6
	lsr.w	d0,d6			; left mask
	and.w	#15,d2
	move.w	#$8000,d7
	asr.w	d2,d7			; right mask
	sub.w	d4,d5			; groups - 1
	bne.s	.multi
	and.w	d7,d6			; one group: both masks
	bsr.s	.grp
	bra.s	.x
.multi:	bsr.s	.grp			; left partial group
	moveq	#-1,d6
	subq.w	#1,d5
	beq.s	.last
	subq.w	#1,d5
.mid:	bsr.s	.grp			; full middle groups
	dbf	d5,.mid
.last:	move.w	d7,d6
	bsr.s	.grp
.x:	movem.l	(sp)+,d3-d7
	rts
; one group at (a0)+ with mask d6, slot d3
.grp:	move.w	d6,d1
	not.w	d1
	move.b	d3,d0
	moveq	#4-1,d2
.pl:	lsr.b	#1,d0
	bcc.s	.clr
	or.w	d6,(a0)+
	dbf	d2,.pl
	rts
.clr:	and.w	d1,(a0)+
	dbf	d2,.pl
	rts

gfx_bar:
	movem.l	d3-d6,-(sp)
	move.w	d0,d5
	move.w	d2,d6
	cmp.w	d1,d3
	bge.s	.ok
	exg	d1,d3
.ok:	move.b	d4,-(sp)		; colour (word slot on the stack)
.y:	movem.w	d1/d3,-(sp)
	move.w	d5,d0
	move.w	d6,d2
	move.b	4(sp),d3
	bsr	gfx_span
	movem.w	(sp)+,d1/d3
	addq.w	#1,d1
	cmp.w	d3,d1
	ble.s	.y
	addq.l	#2,sp
	movem.l	(sp)+,d3-d6
	rts

gfx_rect:
	movem.l	d3-d7,-(sp)
	move.w	d0,d5			; x1
	move.w	d1,d6			; y1
	move.w	d2,d7			; x2
	move.w	d3,-(sp)		; y2
	move.b	d4,-(sp)
	move.w	d3,d1			; bottom edge
	move.b	(sp),d3
	bsr	gfx_span
	move.w	d5,d0			; top edge
	move.w	d6,d1
	move.w	d7,d2
	move.b	(sp),d3
	bsr	gfx_span
	move.w	2(sp),d4		; y2
.v:	move.w	d5,d0			; left and right columns
	move.w	d6,d1
	move.b	(sp),d2
	bsr	gfx_pset
	move.w	d7,d0
	move.w	d6,d1
	move.b	(sp),d2
	bsr	gfx_pset
	addq.w	#1,d6
	cmp.w	d4,d6
	ble.s	.v
	addq.l	#4,sp
	movem.l	(sp)+,d3-d7
	rts

; Bresenham, one gfx_pset per pixel (good enough for the UI; fast lines come later)
gfx_line:
	movem.l	d3-d7,-(sp)
	move.b	d4,gfx_lcol
	move.w	d2,d4
	sub.w	d0,d4			; dx
	moveq	#1,d6			; sx
	tst.w	d4
	bge.s	.ax
	neg.w	d4
	moveq	#-1,d6
.ax:	move.w	d3,d5
	sub.w	d1,d5			; dy
	moveq	#1,d7			; sy
	tst.w	d5
	bge.s	.ay
	neg.w	d5
	moveq	#-1,d7
.ay:	neg.w	d5			; dy = -|dy|
	move.w	d2,gfx_lx2
	move.w	d3,gfx_ly2
	move.w	d4,d3
	add.w	d5,d3			; err = dx + dy
.pt:	movem.w	d0-d1,-(sp)
	move.b	gfx_lcol,d2
	bsr	gfx_pset
	movem.w	(sp)+,d0-d1
	cmp.w	gfx_lx2,d0
	bne.s	.go
	cmp.w	gfx_ly2,d1
	beq.s	.x
.go:	move.w	d3,d2
	add.w	d2,d2			; e2 = 2 err
	cmp.w	d5,d2
	blt.s	.ny
	add.w	d5,d3
	add.w	d6,d0
.ny:	cmp.w	d4,d2
	bgt.s	.pt
	add.w	d4,d3
	add.w	d7,d1
	bra.s	.pt
.x:	movem.l	(sp)+,d3-d7
	rts

	section	bss
gfx_target:	ds.l	1
gfx_lx2:	ds.w	1
gfx_ly2:	ds.w	1
gfx_lcol:	ds.b	1
	even
