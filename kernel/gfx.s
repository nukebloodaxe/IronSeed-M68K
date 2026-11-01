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
; gfx_c4_span    as gfx_chunky_span, ~2x faster (one pass, LUT straight to slot*4): the chunky
;                 shadow flush of MAIN.PRG                      trashes: d0-d2/a0-a2
;                 Phase 6j: with pair tables (gfx_pair_init) a band that converts many pixels gets
;                 a 64K-entry table: a pixel pair (one word of the shadow) -> its slot code * 16,
;                 then one or.l from gfx_pos (4 pair positions in an 8-pixel cell): ~27 cycles a
;                 pixel instead of ~42 in whole cells. Bit for bit the same planar result.
; gfx_pair_init  in: a0 = memory, d0.w = table slots (GFX_PSLOT bytes each; 0 = off). Tables are
;                 built for a band once it has converted GFX_PMIN pixels since its LUT last
;                 changed (vid_set_luts calls gfx_pair_inval), kept by LUT content, LRU.
;                 trashes: d0-d2/a0-a2
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
	move.w	d0,-(sp)		; (Phase 7) (x + y) odd: the line's B LUT (the checkerboard)
	eor.w	d1,(sp)
	btst	#0,1(sp)
	addq.l	#2,sp			; (flags kept)
	beq.s	.ev
	add.l	#vid_lutsb-vid_luts,a1
.ev:	move.b	0(a1,d2.w),d2		; slot
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

; ---------------------------------------------------------------
; GFX_PCELL k: 8 pixels at (a0)+ (words, even) by the pair table a5 and gfx_pos (a3) -> the
; cell's 4 plane bytes at k(a2)  (trashes d2/d4/d5)
GFX_PCELL	macro
	moveq	#0,d2
	move.w	(a0)+,d2
	add.l	d2,d2
	move.w	0(a5,d2.l),d4
	move.l	0(a3,d4.w),d5
	moveq	#0,d2
	move.w	(a0)+,d2
	add.l	d2,d2
	move.w	0(a5,d2.l),d4
	or.l	4(a3,d4.w),d5
	moveq	#0,d2
	move.w	(a0)+,d2
	add.l	d2,d2
	move.w	0(a5,d2.l),d4
	or.l	8(a3,d4.w),d5
	moveq	#0,d2
	move.w	(a0)+,d2
	add.l	d2,d2
	move.w	0(a5,d2.l),d4
	or.l	12(a3,d4.w),d5
	movep.l	d5,\1(a2)
	endm

gfx_c4_span:
	movem.l	d3-d7/a3-a5,-(sp)
	ifd	PROFILE
	ext.l	d2
	add.l	d2,gfx_stat+4		; (pixels asked for)
	endif
	move.l	d1,-(sp)
	bsr	vid_lut_y
	move.l	a1,d3			; (Phase 7) this line's slot*4 tables: vid_luts4 band * 768,
	sub.l	#vid_luts,d3		; [A, B, A]; an odd line starts at B (the checkerboard)
	move.w	d3,d4
	add.w	d3,d3
	add.w	d4,d3			; band * 768
	lea	vid_luts4,a5
	add.w	d3,a5
	lsr.w	#5,d4			; (band * 2) * 4
	btst	#0,3(sp)
	beq.s	.ev0
	lea	256(a5),a5
	addq.w	#4,d4
.ev0:	move.w	d4,d3			; (band * 2 + parity) * 4: the pair table's index
	clr.l	gfx_pcur
	tst.w	gfx_pslots		; (Phase 6j) the band's pair table, if it has one / earns one
	beq.s	.np
	lea	gfx_pband,a2
	move.l	0(a2,d3.w),d4
	bne.s	.pt
	lea	gfx_psrch,a2		; not looked for since the LUT changed: a cached table?
	tst.b	0(a2,d3.w)
	bne.s	.cnt
	st	0(a2,d3.w)
	movem.l	d0-d2/a0,-(sp)
	move.w	d3,d0
	lsr.w	#2,d0
	moveq	#0,d1			; (find only)
	bsr	gfx_pair_get
	move.l	a0,d4
	movem.l	(sp)+,d0-d2/a0
	bne.s	.pt
.cnt:	tst.b	gfx_pnobuild		; none: build one once the band has converted GFX_PMIN pixels
	bne.s	.np			; (not while the LUTs are temporary)
	lea	gfx_pcnt,a2
	moveq	#0,d4
	move.w	d2,d4
	add.l	d4,0(a2,d3.w)
	cmp.l	#GFX_PMIN,0(a2,d3.w)
	blo.s	.np
	movem.l	d0-d2/a0,-(sp)
	move.w	d3,d0
	lsr.w	#2,d0
	moveq	#1,d1			; (find or build)
	bsr	gfx_pair_get
	move.l	a0,d4
	movem.l	(sp)+,d0-d2/a0
.pt:	move.l	d4,gfx_pcur
.np:	move.l	(sp)+,d1
	move.l	gfx_target,a1
	mulu	#SCR_BPL,d1
	add.l	d1,a1			; line
	lea	gfx_ptab+2*64,a3
	lea	gfx_ptab+6*64,a4
	move.w	d0,d3
	lsr.w	#3,d3			; first cell
	move.w	d2,d6			; pixels left
	and.w	#7,d0			; skip in the first cell
	moveq	#0,d2
.cell:	move.w	d3,d1
	lsr.w	#1,d1
	lsl.w	#3,d1
	btst	#0,d3
	beq.s	.ev
	addq.w	#1,d1
.ev:	lea	0(a1,d1.w),a2
	tst.w	d0
	bne	.part
	cmp.w	#8,d6
	blo	.part
	move.w	d6,d7			; run of full cells: 2 per group (even, odd)
	lsr.w	#3,d7
	subq.w	#1,d7
	tst.l	gfx_pcur		; (Phase 6j) pairs: a table, and the pixels at an even address
	beq	.full0
	move.l	a0,d1
	btst	#0,d1
	bne	.full0
	movem.l	a3/a5,-(sp)
	lea	gfx_pos,a3
	move.l	gfx_pcur,a5
	addq.w	#1,d7			; (6n) the run's cells: two a loop pass (even + odd cell of a
	move.w	d7,d1			; group), d3/d6 updated once (.cell recomputes a2 from d3)
	lsl.w	#3,d1
	sub.w	d1,d6
	ifd	PROFILE
	ext.l	d1
	add.l	d1,gfx_stat		; (pixels by pairs)
	endif
	move.w	d3,d1
	add.w	d7,d3
	btst	#0,d1
	beq.s	.pev
	GFX_PCELL 0			; an odd first cell
	addq.l	#7,a2
	subq.w	#1,d7
.pev:	move.w	d7,d1
	lsr.w	#1,d7
	subq.w	#1,d7
	bmi.s	.pl
.pp:	GFX_PCELL 0
	GFX_PCELL 1
	addq.l	#8,a2
	dbf	d7,.pp
.pl:	btst	#0,d1
	beq.s	.pe
	GFX_PCELL 0			; an even last cell
.pe:
	movem.l	(sp)+,a3/a5
	moveq	#0,d2
	tst.w	d6
	bne	.cell
	bra	.done
.full0:	move.w	#$100,d4		; (Phase 7) the odd pixels' index base: [A, B, A] + 256
.full:	moveq	#0,d5
	move.b	(a0)+,d2
	move.b	0(a5,d2.w),d2
	or.l	-128(a3,d2.w),d5
	move.b	(a0)+,d4		; (odd pixel: d4 = $100 + pixel, the B half on even lines)
	move.b	0(a5,d4.w),d2
	or.l	-64(a3,d2.w),d5
	move.b	(a0)+,d2
	move.b	0(a5,d2.w),d2
	or.l	0(a3,d2.w),d5
	move.b	(a0)+,d4		; (odd pixel: d4 = $100 + pixel, the B half on even lines)
	move.b	0(a5,d4.w),d2
	or.l	64(a3,d2.w),d5
	move.b	(a0)+,d2
	move.b	0(a5,d2.w),d2
	or.l	-128(a4,d2.w),d5
	move.b	(a0)+,d4		; (odd pixel: d4 = $100 + pixel, the B half on even lines)
	move.b	0(a5,d4.w),d2
	or.l	-64(a4,d2.w),d5
	move.b	(a0)+,d2
	move.b	0(a5,d2.w),d2
	or.l	0(a4,d2.w),d5
	move.b	(a0)+,d4		; (odd pixel: d4 = $100 + pixel, the B half on even lines)
	move.b	0(a5,d4.w),d2
	or.l	64(a4,d2.w),d5
	movep.l	d5,0(a2)
	subq.w	#8,d6
	addq.w	#1,d3
	btst	#0,d3			; next cell: +1 (odd) or +7 (next group)
	bne.s	.odd
	addq.l	#6,a2
.odd:	addq.l	#1,a2
	dbf	d7,.full
	tst.w	d6
	bne	.cell
	bra.s	.done
.part:	moveq	#0,d5
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
	btst	#0,d1			; (Phase 7) position 7-d1: odd -> the B half (+256)
	bne.s	.pa
	move.w	#$100,d4
	move.b	d2,d4
	move.b	0(a5,d4.w),d2
	bra.s	.pb
.pa:	move.b	0(a5,d2.w),d2
.pb:	or.l	64(a4,d2.w),d5
.nx:	dbf	d1,.px
	move.b	d7,d1
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
	addq.w	#1,d3
	tst.w	d6
	bne	.cell
.done:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; ---------------------------------------------------------------- Phase 6j: pair tables
GFX_PMIN	equ	24000		; pixels a band converts before its table is built
GFX_PTAB	equ	65536*2		; a table: (pixel pair) -> code * 16, words
GFX_PSLOT	equ	512+GFX_PTAB	; a slot: the two LUTs it was built from (left, right pixel), the table

gfx_pair_init:
	move.l	a0,gfx_pbase
	move.w	d0,gfx_pslots
	lea	gfx_pkey,a0		; (no slot holds a table yet)
	moveq	#GFX_PMAXS-1,d0
.c:	clr.w	(a0)+
	dbf	d0,.c
gfx_pair_inval:				; (vid_set_luts: every band's LUT may have changed)
	lea	gfx_pband,a0
	moveq	#3*8-1,d0		; gfx_pband, gfx_pcnt, gfx_psrch (per band and line parity)
.i:	clr.l	(a0)+
	dbf	d0,.i
	rts

; gfx_pair_get(d0.w band, d1.w = 0: find only, 1: or build): a0 = its table (found by the LUT's
; content, or built in the least recently used slot), 0 when not found (Z from move.l a0)
; trashes: d0-d2/a0-a2
gfx_pair_get:
	movem.l	d3-d5/a3,-(sp)
	move.w	d1,d5
	move.w	d0,d3
	bsr	gfx_pkey_make		; a2 = the key: (left pixel's LUT, right pixel's LUT)
	addq.w	#1,gfx_ptick
	moveq	#0,d4			; slot
	move.l	gfx_pbase,a3
.f:	cmp.w	gfx_pslots,d4
	bhs.s	.build
	lea	gfx_pkey,a0
	move.w	d4,d0
	add.w	d0,d0
	tst.w	0(a0,d0.w)
	beq.s	.fn
	move.l	a3,a0			; its key = this one?
	move.l	a2,a1
	moveq	#512/4-1,d0
.k:	cmpm.l	(a0)+,(a1)+
	bne.s	.fn
	dbf	d0,.k
	bra	.got
.fn:	add.l	#GFX_PSLOT,a3
	addq.w	#1,d4
	bra.s	.f
.build:	sub.l	a0,a0			; (find only: none)
	tst.w	d5
	beq	.out
	lea	gfx_pkey,a0		; an empty slot, else the least recently used one no band
	moveq	#0,d4			; uses now (a table in use is never replaced: no thrashing)
.e:	cmp.w	gfx_pslots,d4
	bhs.s	.lru
	tst.w	(a0)+
	beq.s	.slot
	addq.w	#1,d4
	bra.s	.e
.lru:	bsr	gfx_pair_lru
	tst.w	d4
	bpl.s	.slot
	bsr	gfx_pair_steal		; (Phase 7) a dithered band: a slot only undithered bands use
	tst.w	d4
	bpl.s	.slot
	lea	gfx_pcnt,a0		; none free: this band tries again GFX_PMIN pixels later
	move.w	d3,d0
	lsl.w	#2,d0
	clr.l	0(a0,d0.w)
	sub.l	a0,a0
	bra	.out
.slot:	move.w	d3,d0			; (the key again: gfx_pair_live used gfx_pkb)
	bsr	gfx_pkey_make
	moveq	#0,d0
	move.w	d4,d0
	mulu	#GFX_PSLOT/256,d0
	lsl.l	#8,d0
	move.l	gfx_pbase,a3
	add.l	d0,a3
	lea	512(a3),a0		; a band still using the slot's old table loses it
	lea	gfx_pband,a1
	moveq	#8-1,d0
.ev:	cmp.l	(a1)+,a0
	bne.s	.evn
	clr.l	-4(a1)
	clr.l	32-4(a1)		; (its count starts again)
	clr.l	64-4(a1)
.evn:	dbf	d0,.ev
	move.l	a3,a1			; the key
	move.l	a2,a0
	moveq	#512/4-1,d0
.ck:	move.l	(a0)+,(a1)+
	dbf	d0,.ck
	lea	512(a3),a0
	lea	gfx_pkb,a1		; (left LUT, right LUT)
	lea	gfx_pkb+256,a2
	ifd	PROFILE
	addq.l	#1,gfx_stat+8
	move.l	d0,-(sp)		; (tag 67: band << 8 | slot of a build)
	move.w	d3,d0
	lsl.w	#8,d0
	move.b	d4,d0
	and.l	#$ffff,d0
	or.l	#67<<24,d0
	bsr	scr_dbg
	move.l	(sp)+,d0
	endif
	bsr	gfx_pair_build
	lea	gfx_pkey,a0
	move.w	d4,d0
	add.w	d0,d0
	move.w	#1,0(a0,d0.w)
.got:	lea	gfx_pstamp,a0
	move.w	d4,d0
	add.w	d0,d0
	move.w	gfx_ptick,0(a0,d0.w)
	lea	512(a3),a0		; the table
	lea	gfx_pband,a1
	move.w	d3,d0
	lsl.w	#2,d0
	move.l	a0,0(a1,d0.w)
.out:
	movem.l	(sp)+,d3-d5/a3
	move.l	a0,d0			; (Z: none)
	rts

; gfx_pair_steal (Phase 7): d3.w = the asking band * 2 + parity; d4.w := a slot whose table only
; undithered bands other than the asking one use (they go back to the byte path; a dithered band
; needs two tables - the checkerboard's parities - and the bridge has two slots), -1 when the
; asking band is not dithered or there is none.  trashes: d0-d2/a0-a1
gfx_pair_steal:
	moveq	#-1,d4
	move.w	d3,d0
	lsr.w	#1,d0
	move.w	d0,gfx_sband
	lea	vid_ddith,a0
	tst.b	0(a0,d0.w)
	beq.s	.x
	moveq	#0,d1			; slot
	move.l	gfx_pbase,a1
	lea	512(a1),a1		; its table
.s:	cmp.w	gfx_pslots,d1
	bhs.s	.x
	lea	gfx_pband,a0
	moveq	#0,d2			; bp
.u:	cmp.l	(a0)+,a1
	bne.s	.un
	move.w	d2,d0			; used by bp d2: the asking band (either parity) or a
	lsr.w	#1,d0			; dithered one: not this slot
	cmp.w	gfx_sband,d0
	beq.s	.n
	movem.l	a0,-(sp)
	lea	vid_ddith,a0
	tst.b	0(a0,d0.w)
	movem.l	(sp)+,a0
	bne.s	.n
.un:	addq.w	#1,d2
	cmp.w	#8,d2
	blo.s	.u
	move.w	d1,d4			; only undithered users: this one
	rts
.n:	add.l	#GFX_PSLOT,a1
	addq.w	#1,d1
	bra.s	.s
.x:	rts

; d4.w := the slot with the oldest stamp that no band's table pointer (gfx_pband) uses, -1 when
; every slot is in use  trashes: d0-d2/a0-a1
gfx_pair_lru:
	moveq	#0,d1			; slot
	moveq	#-1,d4
	moveq	#0,d2			; its age + 1 (0: none yet)
	move.l	gfx_pbase,a1
	lea	512(a1),a1		; the slot's table
.s:	cmp.w	gfx_pslots,d1
	bhs.s	.x
	lea	gfx_pband,a0
	moveq	#8-1,d0
.u:	cmp.l	(a0)+,a1
	beq.s	.n			; in use
	dbf	d0,.u
	bsr	gfx_pair_live		; (Phase 6k) or the table of a band's LUT now, not looked for yet
	beq.s	.n
	lea	gfx_pstamp,a0
	move.w	d1,d0
	add.w	d0,d0
	move.w	0(a0,d0.w),d0
	neg.w	d0
	add.w	gfx_ptick,d0		; age = tick - stamp
	addq.w	#1,d0
	cmp.w	d2,d0
	bls.s	.n
	move.w	d0,d2
	move.w	d1,d4
.n:	add.l	#GFX_PSLOT,a1
	addq.w	#1,d1
	bra.s	.s
.x:	rts

; gfx_pair_live (Phase 6k): Z set when the slot whose table is at a1 was built from a LUT that a
; band has now (after gfx_pair_inval the bands find their tables again only when they next
; convert: such a table must not be replaced meanwhile - the bridge lost its text box's table to
; the viewscreen's after every design switch).  keeps every register but the flags
gfx_pair_live:
	movem.l	d0-d3/a0-a2,-(sp)
	move.l	a1,d2			; (the slot's table)
	move.w	vid_bands_src,d3	; bands * 2 parities
	add.w	d3,d3
	subq.w	#1,d3
	bmi.s	.no
.b:	move.w	d3,d0
	bsr	gfx_pkey_make
	move.l	d2,a0
	lea	-512(a0),a0		; the slot's key
	moveq	#512/4-1,d0
.k:	cmpm.l	(a0)+,(a2)+
	bne.s	.d
	dbf	d0,.k
	moveq	#0,d0			; Z: live
	bra.s	.x
.d:	dbf	d3,.b
.no:	moveq	#1,d0			; Z clear
.x:	movem.l	(sp)+,d0-d3/a0-a2	; (movem keeps the flags)
	rts

; gfx_pkey_make (Phase 7): d0.w = band * 2 + parity -> a2 = gfx_pkb, the pair table's key: the
; LUT of the left (even) pixel, then the right one's: (A, B) on even lines, (B, A) on odd ones
; (B = vid_lutsb, = A unless the band is dithered).  trashes: d0-d1/a0-a1
gfx_pkey_make:
	move.w	d0,d1
	lsr.w	#1,d1
	lsl.w	#8,d1
	lea	vid_luts,a0
	add.w	d1,a0
	lea	vid_lutsb,a1
	add.w	d1,a1
	btst	#0,d0
	beq.s	.e
	exg	a0,a1
.e:	lea	gfx_pkb,a2
	moveq	#256/4-1,d1
.l:	move.l	(a0)+,(a2)+
	dbf	d1,.l
	moveq	#256/4-1,d1
.r:	move.l	(a1)+,(a2)+
	dbf	d1,.r
	lea	gfx_pkb,a2
	rts

; gfx_pair_build(a0 = table, a1 = left LUT, a2 = right LUT): table[a*256 + b] = slotL(a)*256 +
; slotR(b)*16 - 16 distinct rows (by slotL(a)) built into gfx_prow, then copied per a.
; trashes: d0-d2/a0-a2
gfx_pair_build:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	a0,a4
	move.l	a1,a5
	lea	gfx_prow,a0		; row s: s*256 + slotR(b)*16
	moveq	#0,d1			; s*256
.rs:	move.l	a2,a1
	move.w	#256-1,d2
.rb:	moveq	#0,d0
	move.b	(a1)+,d0
	lsl.w	#4,d0
	add.w	d1,d0
	move.w	d0,(a0)+
	dbf	d2,.rb
	add.w	#256,d1
	cmp.w	#16*256,d1
	blo.s	.rs
	move.w	#256-1,d7		; rows a: copies of row slot(a)
.ra:	moveq	#0,d0
	move.b	(a5)+,d0
	lsl.w	#8,d0
	add.w	d0,d0			; * 512
	lea	gfx_prow,a3
	add.w	d0,a3
	moveq	#512/32-1,d6
.cp:	movem.l	(a3)+,d0-d5/a0-a1
	movem.l	d0-d5/a0-a1,(a4)
	lea	32(a4),a4
	dbf	d6,.cp
	dbf	d7,.ra
	movem.l	(sp)+,d3-d7/a3-a5
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

gfx_pos:				; (Phase 6j) pair code c = slot(a)*16 + slot(b), position p (pixels
					; 2p, 2p+1): gfx_pos[c*16 + p*4] = their plane bits (movep order)
c	set	0
	rept	256
p	set	0
	rept	4
xa	set	c>>4
xb	set	c&15
	dc.l	((((xa&1)<<24)|(((xa>>1)&1)<<16)|(((xa>>2)&1)<<8)|((xa>>3)&1))<<(7-2*p))|((((xb&1)<<24)|(((xb>>1)&1)<<16)|(((xb>>2)&1)<<8)|((xb>>3)&1))<<(6-2*p))
p	set	p+1
	endr
c	set	c+1
	endr

	section	bss
GFX_PMAXS	equ	4
gfx_pbase:	ds.l	1		; (Phase 6j) pair tables: their memory
gfx_stat:	ds.l	3		; (PROFILE: pixels by pairs, pixels asked for, tables built)
gfx_pcur:	ds.l	1		; gfx_c4_span: this line's table (0 = none)
gfx_pband:	ds.l	8		; per band and line parity: its table (0 = none yet)
gfx_pcnt:	ds.l	8		; per band and parity: pixels converted since its LUT changed (follows gfx_pband)
gfx_psrch:	ds.l	8		; per band and parity: the cache was searched (byte at bp*4; follows gfx_pcnt)
gfx_pnobuild:	ds.b	1		; no counting, no table builds: the LUTs are temporary (a dialog's refit)
	even
gfx_pkey:	ds.w	GFX_PMAXS	; per slot: it holds a table
gfx_pstamp:	ds.w	GFX_PMAXS	; per slot: last use
gfx_pslots:	ds.w	1
gfx_ptick:	ds.w	1
gfx_prow:	ds.w	16*256
gfx_sband:	ds.w	1		; (Phase 7) gfx_pair_steal's asking band
gfx_pkb:	ds.b	512		; (Phase 7) a pair table's key being looked for
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
