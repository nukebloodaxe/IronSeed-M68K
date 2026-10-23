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
; gfx_slot_span  in: a0 = slot bytes (0-15, already mapped), d0.w x0, d1.w y, d2.w count (>0)
;                 writes them as planar pixels at (x0..x0+count-1, y), 8-pixel cells, masked edges
;                 trashes: d0-d2/a0-a2
; gfx_slot4_span  same, but a0 = slot*4 bytes (fast path for renderers)
; gfx_chunky_span  same, but a0 = game colour indices, mapped through the line's LUT
; gfx_copy_rect  in: a0 = source screen (same layout; only the rectangle is read), d0.w x1,
;                 d1.w y1, d2.w x2, d3.w y2 (inclusive): copies those pixels to gfx_target
;                 trashes: d0-d2/a0-a2
; gfx_cline       in: d0.w x1, d1.w y1, d2.w x2, d3.w y2, d4.b colour: c_utils.c line() (the
;                 original's line/lineto: its own stepping, pixel-exact), sets the pen to x2, y2
;                 trashes: d0-d2/a0-a2
; gfx_lineto      in: d0.w x, d1.w y, d4.b colour: gfx_cline from the pen (moveto: gfx_pen)
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

; ---------------------------------------------------------------
gfx_lineto:
	move.l	d3,-(sp)
	move.w	d1,d3
	move.w	d0,d2
	move.w	gfx_pen,d0
	move.w	gfx_pen+2,d1
	bsr.s	gfx_cline
	move.l	(sp)+,d3
	rts
gfx_cline:
	movem.l	d3-d7,-(sp)
	move.b	d4,gfx_lcol
	move.w	d2,gfx_pen
	move.w	d3,gfx_pen+2
	move.w	d2,d5
	sub.w	d0,d5			; dx
	moveq	#1,d6
	tst.w	d5
	bgt.s	.sx
	moveq	#-1,d6
.sx:	move.w	d6,gfx_sdx
	tst.w	d5
	bpl.s	.ax
	neg.w	d5			; dxabs
.ax:	move.w	d3,d6
	sub.w	d1,d6			; dy
	moveq	#1,d7
	tst.w	d6
	bgt.s	.sy
	moveq	#-1,d7
.sy:	move.w	d7,gfx_sdy
	tst.w	d6
	bpl.s	.ay
	neg.w	d6			; dyabs
.ay:	move.w	d0,d3			; px
	move.w	d1,d4			; py
	move.w	d6,d7
	lsr.w	#1,d7
	move.w	d7,gfx_accx		; x = dyabs >> 1
	move.w	d5,d7
	lsr.w	#1,d7
	move.w	d7,gfx_accy		; y = dxabs >> 1
	bsr.s	.put
	cmp.w	d6,d5
	blt.s	.vert
	move.w	d5,d7			; more horizontal: dxabs steps
	bra.s	.hn
.hl:	move.w	gfx_accy,d0
	add.w	d6,d0
	cmp.w	d5,d0
	blt.s	.h1
	sub.w	d5,d0
	add.w	gfx_sdy,d4
.h1:	move.w	d0,gfx_accy
	add.w	gfx_sdx,d3
	bsr.s	.put
.hn:	dbf	d7,.hl
	bra.s	.x
.vert:	move.w	d6,d7
	bra.s	.vn
.vl:	move.w	gfx_accx,d0
	add.w	d5,d0
	cmp.w	d6,d0
	blt.s	.v1
	sub.w	d6,d0
	add.w	gfx_sdx,d3
.v1:	move.w	d0,gfx_accx
	add.w	gfx_sdy,d4
	bsr.s	.put
.vn:	dbf	d7,.vl
.x:	movem.l	(sp)+,d3-d7
	rts
.put:	move.w	d3,d0
	move.w	d4,d1
	move.b	gfx_lcol,d2
	bra	gfx_pset

; ---------------------------------------------------------------
gfx_chunky_span:
	movem.l	d0-d2,-(sp)
	bsr	vid_lut_y		; a1 = this line's LUT
	lea	gfx_spanbuf,a2
	subq.w	#1,d2
	moveq	#0,d0
.m:	move.b	(a0)+,d0
	move.b	0(a1,d0.w),(a2)+
	dbf	d2,.m
	movem.l	(sp)+,d0-d2
	lea	gfx_spanbuf,a0
	; fall through
gfx_slot_span:				; slots 0-15 -> slot*4, then the fast writer
	movem.l	d0-d2,-(sp)
	lea	gfx_spanbuf,a1
	subq.w	#1,d2
.s4:	move.b	(a0)+,d0
	add.b	d0,d0
	add.b	d0,d0
	move.b	d0,(a1)+
	dbf	d2,.s4
	movem.l	(sp)+,d0-d2
	lea	gfx_spanbuf,a0
	; fall through
; gfx_slot4_span  as gfx_slot_span, but a0 = slot*4 bytes (0, 4, ... 60)
gfx_slot4_span:
	movem.l	d3-d7/a3-a4,-(sp)
	move.l	gfx_target,a1
	mulu	#SCR_BPL,d1
	add.l	d1,a1			; line
	lea	gfx_ptab+2*64,a3	; shifted tables 0-3 at -128..64(a3)
	lea	gfx_ptab+6*64,a4	; tables 4-7 at -128..64(a4)
	move.w	d0,d3
	lsr.w	#3,d3			; first cell
	move.w	d2,d6			; pixels left
	and.w	#7,d0			; skip in the first cell
	moveq	#0,d2
.cell:	move.w	d3,d1			; cell address: group (cell>>1)*8 + (cell&1)
	lsr.w	#1,d1
	lsl.w	#3,d1
	btst	#0,d3
	beq.s	.ev
	addq.w	#1,d1
.ev:	lea	0(a1,d1.w),a2
	tst.w	d0
	bne.s	.part
	cmp.w	#8,d6
	blo.s	.part
	moveq	#0,d5			; full cell: 8 pixels, no masks
	move.b	(a0)+,d2
	or.l	-128(a3,d2.w),d5	; table 0 = shifted left 7 (leftmost pixel)
	move.b	(a0)+,d2
	or.l	-64(a3,d2.w),d5
	move.b	(a0)+,d2
	or.l	0(a3,d2.w),d5
	move.b	(a0)+,d2
	or.l	64(a3,d2.w),d5
	move.b	(a0)+,d2
	or.l	-128(a4,d2.w),d5
	move.b	(a0)+,d2
	or.l	-64(a4,d2.w),d5
	move.b	(a0)+,d2
	or.l	0(a4,d2.w),d5
	move.b	(a0)+,d2
	or.l	64(a4,d2.w),d5
	movep.l	d5,0(a2)
	subq.w	#8,d6
	bra.s	.next
.part:	moveq	#0,d5			; partial cell: position by position, with a mask
	moveq	#0,d7
	moveq	#8-1,d1
.px:	add.l	d5,d5
	add.b	d7,d7
	tst.w	d0
	beq.s	.in
	subq.w	#1,d0
	bra.s	.nx
.in:	tst.w	d6
	beq.s	.nx
	subq.w	#1,d6
	addq.b	#1,d7
	move.b	(a0)+,d2
	or.l	64(a4,d2.w),d5		; table 7 = unshifted
.nx:	dbf	d1,.px
	move.b	d7,d1			; mask in all four bytes
	lsl.w	#8,d1
	move.b	d7,d1
	move.w	d1,d4
	swap	d1
	move.w	d4,d1
	and.l	d1,d5
	not.l	d1
	movep.l	0(a2),d4
	and.l	d1,d4
	or.l	d5,d4
	movep.l	d4,0(a2)
.next:	addq.w	#1,d3
	tst.w	d6
	bne	.cell
	movem.l	(sp)+,d3-d7/a3-a4
	rts

gfx_copy_rect:
	movem.l	d3-d7/a3,-(sp)
	sub.w	d1,d3			; rows - 1
	mulu	#SCR_BPL,d1
	move.l	gfx_target,a1
	add.l	d1,a1
	add.l	d1,a0
	moveq	#15,d6			; left mask: $ffff >> (x1 & 15)
	and.w	d0,d6
	moveq	#-1,d7
	lsr.w	d6,d7
	moveq	#15,d6			; right mask: top (x2 & 15) + 1 bits
	and.w	d2,d6
	move.w	#$8000,d1
	asr.w	d6,d1
	lsr.w	#4,d0			; first group
	lsr.w	#4,d2
	move.w	d2,d5
	sub.w	d0,d5			; groups - 1
	lsl.w	#3,d0
	add.w	d0,a0
	add.w	d0,a1
.row:	move.l	a0,a2
	move.l	a1,a3
	moveq	#0,d6
.grp:	moveq	#-1,d0
	tst.w	d6
	bne.s	.nl
	move.w	d7,d0
.nl:	cmp.w	d5,d6
	bne.s	.nr
	and.w	d1,d0
.nr:	move.w	d0,d2
	not.w	d2
	rept	4
	move.w	(a2)+,d4
	and.w	d0,d4
	and.w	d2,(a3)
	or.w	d4,(a3)+
	endr
	addq.w	#1,d6
	cmp.w	d5,d6
	bls.s	.grp
	lea	SCR_BPL(a0),a0
	lea	SCR_BPL(a1),a1
	dbf	d3,.row
	movem.l	(sp)+,d3-d7/a3
	rts

	section	data
gfx_ptab:				; 8 tables x 16 slots: slot s -> plane k bit at bit (7-t) of byte
					; (3-k) (movep order), table t = pixel position t in the cell
t	set	0
	rept	8
x	set	0
	rept	16
	dc.l	(((x&1)<<24)|(((x>>1)&1)<<16)|(((x>>2)&1)<<8)|((x>>3)&1))<<(7-t)
x	set	x+1
	endr
t	set	t+1
	endr

	section	bss
gfx_spanbuf:	ds.b	SCR_W
	even
gfx_target:	ds.l	1
gfx_lx2:	ds.w	1
gfx_ly2:	ds.w	1
gfx_lcol:	ds.b	1
	even
gfx_pen:	ds.w	2
gfx_sdx:	ds.w	1
gfx_sdy:	ds.w	1
gfx_accx:	ds.w	1
gfx_accy:	ds.w	1
	even
