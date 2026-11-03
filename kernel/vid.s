; vid.s - screens, raster palette bands, fades, VBL. Part of kernel.s.
;
; Band table (BANDS): dc.w count (1-4), then per band: dc.w first_line, 16 x dc.w STE colour.
; Band 0 must start at line 0; bands must be at least 2 lines high.
; Splits: Timer B fires at the end of the line two lines before a split; the handler
; preloads the colours, polls the video counter until the split line's own blank
; begins, then writes all 16 colours with one movem (PLAN §3.3, §7).
;
; vid_set_bands   in: a0 = band table            trashes: d0-d2/a0-a2
; vid_set_fade    in: d0.w = 0 (black) .. 16 (full)  trashes: d0-d2/a0-a2
; vid_flip        show vid_log from the next frame on; returns as soon as the VBL has taken it
;                 (at most one VBL). Triple buffering: a base written in a VBL is displayed from
;                 the following frame, so the buffer shown until then is still busy; vid_log
;                 becomes the third buffer, which is free. vid_phys = the buffer just flipped.
; vid_vsync       wait for the next VBL                trashes: d0
; vid_fade_ms     in: d0.w = from level, d1.w = to level (0-16), d2.w = total milliseconds
;                 steps one level at a time, timed with _hz_200   trashes: d0-d2/a0-a2
; vid_clear       in: a0 = screen                      trashes: d0-d2/a0-a2
; vid_set_luts    in: a0 = 4 x 256-byte LUTs (original palette index -> slot 0-15, one per band);
;                 builds vid_line_lut / vid_line_band from the current bands; rebuilds the cursor
;                 trashes: d0-d2/a0-a2
; vid_lut_y       in: d1.w = y   out: a1 = LUT for that line           trashes: nothing else
; vid_set_lines   in: d0.w = band count (1-4), a0 = first line of each band (words; band 0 = 0,
;                 increasing, < 200): moves the splits, keeps the colours (e.g. bands that
;                 follow a scrolling picture). Call vid_set_luts(vid_luts) afterwards before
;                 drawing with game colours.   trashes: d0-d2/a0-a2
; vid_set_reps    in: a0 = 4 x 16 bytes: per band and slot, the original palette index it shows
; vid_set256      in: a0 = 256 x 3 bytes, 6-bit VGA palette (the original set256colors): every
;                 slot of every band takes the colour of its rep index; the fade level applies.
;                 trashes: d0-d2/a0-a2
; vid_setrgb      in: d0.w index, d1.w r, d2.w g, d3.w b (0-63): c_utils.c setrgb256: the slots
;                 whose rep is that index (and not kept) take the colour; the fade level applies.
;                 trashes: d0-d2/a0-a2
; vid_set_keep    in: a0 = 4 x 16 bytes (non-zero: vid_set256 leaves that slot's colour alone,
;                 e.g. the quantiser's colours where only some slots are animated), or a0 = 0:
;                 none kept (default)                              trashes: d0/a0-a1
; vid_lut_remap   in: d0.w first index, d1.w count: in every band, maps those palette indices to
;                 the slot whose colour is nearest to their colour in GS_COLORS now (for indices
;                 whose colours were changed at run time, e.g. after colour cycling stopped)
;                 trashes: d0-d2/a0-a2
; vid_flip_pal    (Phase 6j) a screen and a palette change shown from the same frame: call
;                 vid_defer_on, change the palette (vid_set_fade and whatever calls it build into
;                 vid_palnext instead of vid_cur), draw the new screen into vid_log, then call
;                 this: vid_flip, and the VBL that starts showing vid_log takes vid_palnext.
;                 Returns once both are on the screen; clears vid_defer.  trashes: d0-d2/a0-a2
; Screens: vid_scr = 3 buffers (256-byte aligned, 32000 bytes); vid_log = where to draw next;
; vid_phys = last flipped (or the start-up screen); programs that never flip draw into vid_phys.
; vid_vbl_hook    (long) 0, or a routine the VBL calls every frame after the band-0 palette and
;                 before the cursor and the mixer, i.e. while the beam is still in the top border
;                 (~45 lines, ~23 000 cycles before line 0 at 60 Hz). Interrupt context: may
;                 trash d0-d7/a0-a3 only, no TOS calls, keep it short (the mixer waits).

BAND_SIZE	equ	2+32
	ifd	TBLOG
TBS_N		equ	0		; splits
TBS_LATE	equ	4		; palette written after the line's first pixels had started
TBS_MAX		equ	8		; the latest, in bytes (2 pixels each)
TBS_BIG		equ	12		; late by 8 bytes (16 pixels) or more
TBS_ENT		equ	16		; the interrupt itself arrived after the line had begun
TBS_SIZE	equ	20
	endc

	section	text
vid_init:
	move.l	vid_scr,vid_phys
	move.l	vid_scr,gfx_target
	move.l	vid_scr,vid_shown
	move.l	vid_scr,vid_written
	move.l	vid_scr+4,vid_log
	move.l	vid_scr+8,vid_spare
	; fade table: level 0..16 x STE nibble -> STE nibble
	lea	vid_fadetab,a0
	moveq	#0,d1			; level
.lv:	moveq	#0,d2			; nibble
.nb:	move.w	d2,d0			; decode: v = (n&7)<<1 | n>>3
	and.w	#7,d0
	add.w	d0,d0
	btst	#3,d2
	beq.s	.d0
	addq.w	#1,d0
.d0:	mulu	d1,d0			; v * level / 16
	lsr.w	#4,d0
	moveq	#0,d3			; encode: n = (v&1)<<3 | v>>1
	btst	#0,d0
	beq.s	.e0
	moveq	#8,d3
.e0:	lsr.w	#1,d0
	or.w	d3,d0
	move.b	d0,(a0)+
	addq.w	#1,d2
	cmp.w	#16,d2
	bne.s	.nb
	addq.w	#1,d1
	cmp.w	#17,d1
	bne.s	.lv
	move.w	#16,vid_fade
	lea	vid_black_bands,a0
	bsr	vid_set_bands
	lea	vid_luts,a0		; default LUTs: index -> index & 15
	moveq	#0,d0
.lut:	move.b	d0,d1
	and.b	#15,d1
	move.b	d1,(a0)
	move.b	d1,256(a0)
	move.b	d1,512(a0)
	move.b	d1,768(a0)
	addq.l	#1,a0
	addq.w	#1,d0
	cmp.w	#256,d0
	bne.s	.lut
	lea	vid_luts,a0
	bsr	vid_set_luts
	DI
	clr.b	MFP_TBCR.w
	move.l	#vid_tb_handler,VEC_TIMERB.w
	move.l	#vid_vbl_handler,VEC_VBL.w
	move.l	#vid_tc_wrap,VEC_TIMERC.w
	move.l	#vid_acia_wrap,VEC_ACIA.w
	bset	#0,MFP_IERA.w
	bset	#0,MFP_IMRA.w
	EI
	rts

; ---------------------------------------------------------------
vid_set_bands:
	move.w	(a0),d0
	cmp.w	#4,d0
	bls.s	.ok
	moveq	#4,d0
.ok:	mulu	#BAND_SIZE,d0
	addq.w	#2,d0
	lsr.w	#1,d0
	subq.w	#1,d0
	lea	vid_bands_src,a1
.cp:	move.w	(a0)+,(a1)+
	dbf	d0,.cp
	move.w	vid_fade,d0
	; fall through
vid_set_fade:
	move.w	d0,vid_fade
	lea	vid_fadetab,a2
	lsl.w	#4,d0
	add.w	d0,a2			; this level's 16-entry row
	move.l	vid_cur,a1		; build into the copy the VBL is NOT using
	cmp.l	#vid_bands_a,a1
	beq.s	.useb
	lea	vid_bands_a,a1
	bra.s	.go
.useb:	lea	vid_bands_b,a1
.go:	move.l	a1,-(sp)
	lea	vid_bands_src,a0
	cmp.w	#16,vid_fade		; full level: the colours as they are (the common case)
	bne.s	.f
	move.w	#(2+4*BAND_SIZE)/2-1,d1
.cp:	move.w	(a0)+,(a1)+
	dbf	d1,.cp
	bra.s	.cur
.f:	move.w	(a0)+,d1
	move.w	d1,(a1)+
	subq.w	#1,d1
.band:	move.w	(a0)+,(a1)+		; first line
	moveq	#16-1,d2
.col:	move.w	(a0)+,d0
	; d0 = 0RRR GGGG BBBB (STE nibbles) -> faded
	move.w	d0,-(sp)
	and.w	#$0f,d0
	move.b	0(a2,d0.w),d0		; B
	ext.w	d0
	move.w	d0,-(sp)
	move.w	2(sp),d0
	lsr.w	#4,d0
	and.w	#$0f,d0
	move.b	0(a2,d0.w),d0		; G
	lsl.w	#4,d0
	or.w	d0,(sp)
	move.w	2(sp),d0
	lsr.w	#8,d0
	and.w	#$0f,d0
	move.b	0(a2,d0.w),d0		; R
	lsl.w	#8,d0
	or.w	(sp)+,d0
	addq.l	#2,sp
	move.w	d0,(a1)+
	dbf	d2,.col
	dbf	d1,.band
.cur:	tst.b	vid_defer		; (Phase 6j) deferred: the VBL takes it with vid_palscr
	bne.s	.def
	move.l	(sp)+,vid_cur		; atomic switch for the VBL
	rts
.def:	move.l	(sp)+,vid_palnext
	rts

; ---------------------------------------------------------------
vid_set_lines:
	lea	vid_bands_src,a1
	move.w	d0,(a1)+
	subq.w	#1,d0
.l:	move.w	(a0)+,(a1)
	lea	BAND_SIZE(a1),a1
	dbf	d0,.l
	move.w	vid_fade,d0
	bra	vid_set_fade

vid_set_reps:
	sf	vid_rgbok		; vid_setrgb's slot chains are built again when needed
	lea	vid_reps,a1
	moveq	#64/4-1,d0
.c:	move.l	(a0)+,(a1)+
	dbf	d0,.c
	rts

vid_set_keep:
	sf	vid_rgbok
	lea	vid_keep,a1
	moveq	#64/4-1,d0
	cmp.w	#0,a0
	beq.s	.clr
.c:	move.l	(a0)+,(a1)+
	dbf	d0,.c
	rts
.clr:	clr.l	(a1)+
	dbf	d0,.clr
	rts

; vid_setrgb: the slots of an index come from a chain per index (vid_rgbfirst[index] = the
; first slot's offset in vid_bands_src + 1, vid_rgbnext[slot] the next; built from vid_reps,
; vid_keep and the band count when one of them has changed). At full fade level the colour also
; goes straight into the copy the VBL shows (a word write: atomic) - no rebuild.
vid_setrgb:
	movem.l	d3-d5,-(sp)
	lea	vid_c6tab,a0
	moveq	#0,d4
	move.b	0(a0,d1.w),d4		; the STE word
	lsl.w	#4,d4
	or.b	0(a0,d2.w),d4
	lsl.w	#4,d4
	or.b	0(a0,d3.w),d4
	tst.b	vid_rgbok
	beq.s	.mk
	move.w	vid_bands_src,d1
	cmp.w	vid_rgbbands,d1
	beq.s	.go
.mk:	bsr	vid_rgbchains
.go:	lea	vid_rgbfirst,a0
	moveq	#0,d1
	move.b	0(a0,d0.w),d1		; slot offset + 1 (0: no slot shows this index)
	beq.s	.x
	lea	vid_bands_src-1,a1
	move.l	vid_cur,a2
	subq.l	#1,a2
	lea	vid_rgbnext,a0
	cmp.w	#16,vid_fade
	bne.s	.slow
.f:	move.w	d4,0(a1,d1.w)		; source and shown copy
	move.w	d4,0(a2,d1.w)
	move.b	0(a0,d1.w),d1
	bne.s	.f
	bra.s	.x
.slow:	move.w	d4,0(a1,d1.w)
	move.b	0(a0,d1.w),d1
	bne.s	.slow
	move.w	vid_fade,d0
	bsr	vid_set_fade
.x:	movem.l	(sp)+,d3-d5
	rts
; the chains (slot offsets in vid_bands_src fit a byte: 2 + 3*34 + 2 + 15*2 = 136)
vid_rgbchains:
	movem.l	d0/d3-d5,-(sp)
	lea	vid_rgbfirst,a0
	moveq	#256/4-1,d1
.cl:	clr.l	(a0)+
	dbf	d1,.cl
	move.w	vid_bands_src,d5
	move.w	d5,vid_rgbbands
	mulu	#16,d5			; slots in use
	lea	vid_reps,a1
	lea	vid_keep,a2
	lea	vid_rgbfirst,a0
	lea	vid_rgbnext,a1
	move.w	d5,d3			; backwards, so a chain runs in slot order
.s:	subq.w	#1,d3
	bmi.s	.e
	lea	vid_keep,a2
	tst.b	0(a2,d3.w)
	bne.s	.s
	lea	vid_reps,a2
	moveq	#0,d1
	move.b	0(a2,d3.w),d1		; its index
	move.w	d3,d4			; offset + 1 = 2 + band*34 + 2 + slot*2 + 1
	lsr.w	#4,d4
	mulu	#BAND_SIZE,d4
	move.w	d3,d2
	and.w	#15,d2
	add.w	d2,d2
	add.w	d2,d4
	addq.w	#5,d4
	move.b	0(a0,d1.w),0(a1,d4.w)	; next := first[index]
	move.b	d4,0(a0,d1.w)		; first[index] := this slot
	bra.s	.s
.e:	st	vid_rgbok
	movem.l	(sp)+,d0/d3-d5
	rts

vid_set256:
	move.l	a0,vid_dpal		; (Phase 7: the colours the dithering is made for)
	movem.l	d3-d5/a3-a4,-(sp)
	lea	vid_reps,a1
	lea	vid_keep,a4
	lea	vid_bands_src,a2
	move.w	(a2)+,d5		; band count
	subq.w	#1,d5
	lea	vid_c6tab,a3
.band:	addq.l	#2,a2			; first line stays
	moveq	#16-1,d4
.slot:	tst.b	(a4)+
	beq.s	.set
	addq.l	#1,a1			; kept: skip
	addq.l	#2,a2
	bra.s	.nxt
.set:	moveq	#0,d0
	move.b	(a1)+,d0
	move.w	d0,d1
	add.w	d0,d0
	add.w	d1,d0			; index * 3
	moveq	#0,d1
	move.b	0(a0,d0.w),d1		; R (0-63)
	move.b	0(a3,d1.w),d1
	lsl.w	#4,d1
	moveq	#0,d2
	move.b	1(a0,d0.w),d2		; G
	or.b	0(a3,d2.w),d1
	lsl.w	#4,d1
	move.b	2(a0,d0.w),d2		; B
	or.b	0(a3,d2.w),d1
	move.w	d1,(a2)+
.nxt:	dbf	d4,.slot
	dbf	d5,.band
	move.w	vid_fade,d0		; rebuild the displayed copy
	bsr	vid_set_fade
	movem.l	(sp)+,d3-d5/a3-a4
	move.l	vid_dhook,d0		; (Phase 7) the program's dithering, from these colours
	beq.s	.nh
	move.l	d0,a1
	move.l	vid_dpal,a0
	jmp	(a1)
.nh:	rts

vid_set_luts:
	addq.l	#1,vid_lutgen		; (Phase 6k: MAIN's flush mirror notices LUT changes)
	move.l	a3,-(sp)
	move.l	a0,-(sp)
	bsr	gfx_pair_inval		; (Phase 6j: the pair tables follow the LUTs)
	move.l	(sp)+,a0
	lea	vid_luts,a1
	cmp.l	a0,a1
	beq.s	.same
	move.w	#1024/4-1,d0
.cp:	move.l	(a0)+,(a1)+
	dbf	d0,.cp
.same:	lea	vid_luts,a0		; (Phase 7) per band [A, B, A] slot*4 copies for gfx_c4_span,
	lea	vid_luts4,a1		; B = A: no dithering until vid_dith says otherwise
	lea	vid_lutsb,a2
	moveq	#4-1,d2
.x4b:	move.w	#256-1,d0
.x4:	move.b	(a0)+,d1
	move.b	d1,(a2)+
	add.b	d1,d1
	add.b	d1,d1
	move.b	d1,(a1)
	move.b	d1,256(a1)
	move.b	d1,512(a1)
	addq.l	#1,a1
	dbf	d0,.x4
	lea	512(a1),a1
	dbf	d2,.x4b
	lea	vid_dvalid,a0		; (the dither caches: inputs to be looked at again)
	clr.l	(a0)
	clr.l	vid_ddith		; (no band dithered)
	lea	vid_bands_src,a0
	move.w	(a0)+,d2		; band count
	lea	vid_line_lut,a1
	lea	vid_luts,a2		; current band's LUT
	moveq	#0,d0			; band index
	moveq	#0,d1			; y
.y:	; next band starts here?
	move.w	d0,d2
	addq.w	#1,d2
	cmp.w	vid_bands_src,d2
	bhs.s	.put
	mulu	#BAND_SIZE,d2
	cmp.w	0(a0,d2.w),d1		; first line of band d0+1
	blo.s	.put
	addq.w	#1,d0
	lea	256(a2),a2
.put:	move.l	a2,(a1)+
	lea	vid_line_band,a3
	move.b	d0,0(a3,d1.w)
	addq.w	#1,d1
	cmp.w	#SCR_H,d1
	bne.s	.y
	move.l	(sp)+,a3
	bra	kbd_cursor_build	; the cursor's colours follow the LUTs

vid_lut_remap:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,d6			; index
	move.w	d1,d7
	subq.w	#1,d7
	lea	vid_c6tab,a3
	lea	vid_dec4,a4
.idx:	move.w	d6,d0			; this index's colour, as decoded 0-15 levels
	mulu	#3,d0
	lea	GS_COLORS(a6,d0.w),a0
	moveq	#0,d3
	moveq	#0,d4
	moveq	#0,d5
	move.b	(a0)+,d3
	move.b	0(a3,d3.w),d3
	move.b	0(a4,d3.w),d3		; r
	move.b	(a0)+,d4
	move.b	0(a3,d4.w),d4
	move.b	0(a4,d4.w),d4		; g
	move.b	(a0),d5
	move.b	0(a3,d5.w),d5
	move.b	0(a4,d5.w),d5		; b
	lea	vid_bands_src,a1
	move.w	(a1)+,d2		; bands
	subq.w	#1,d2
	lea	vid_luts,a5
.band:	movem.l	d2/d6-d7,-(sp)
	addq.l	#2,a1			; first line
	move.l	#$7fff,d7		; best distance
	moveq	#0,d6			; slot
.slot:	move.w	(a1)+,d0		; STE colour
	move.w	d0,d1
	lsr.w	#8,d1
	and.w	#15,d1
	move.b	0(a4,d1.w),d1
	sub.w	d3,d1
	muls	d1,d1
	move.w	d0,d2
	lsr.w	#4,d2
	and.w	#15,d2
	move.b	0(a4,d2.w),d2
	sub.w	d4,d2
	muls	d2,d2
	add.w	d2,d1
	and.w	#15,d0
	move.b	0(a4,d0.w),d0
	sub.w	d5,d0
	muls	d0,d0
	add.w	d0,d1
	cmp.w	d7,d1
	bge.s	.ns
	move.w	d1,d7
	move.b	d6,vid_best		; nearest so far
.ns:	addq.w	#1,d6
	cmp.w	#16,d6
	bne.s	.slot
	movem.l	(sp)+,d2/d6-d7
	move.b	vid_best,0(a5,d6.w)
	lea	256(a5),a5
	dbf	d2,.band
	addq.w	#1,d6
	dbf	d7,.idx
	movem.l	(sp)+,d3-d7/a3-a5
	lea	vid_luts,a0
	bra	vid_set_luts

; ---------------------------------------------------------------- Phase 7: dithering
; vid_dith(d0.w band, d1.w lo, d2.w hi, a0 = 768-byte palette shown, 6-bit): the band's odd-pixel
; LUT B (gfx_c4_span shows A on (x+y) even, B on odd: a checkerboard). An index lo..hi whose slot A
; shows a colour from lo..hi (its rep there, not kept) more than VID_DTHR (0-255 RGB distance) from
; the index's own colour gets as B the slot (rep in lo..hi, not kept) whose average with A comes
; closest - 5*|A+B-2t|^2 + 2*|A-B|^2, the contrast penalty keeping noise down - if that average is
; within half of A's error; else B = A. Only colours of the range take part, so animated slots and
; the screen furniture never mix in. Cached on its inputs (LUT, reps, keep flags, the range's
; colours): a call with nothing changed costs a compare.
; out: d0.w = 1 when B changed (the band's lines need converting again)  trashes: d0-d2/a0-a2
VID_DTHR	equ	14
VDC_SIZE	equ	256+16+16+768+256	; cache: LUT, reps, keep, palette, the B last made
vid_dith:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,vid_dband
	move.w	d1,vid_dlo
	move.w	d2,vid_dhi
	move.l	a0,a5			; palette
	move.w	d0,d3
	mulu	#VDC_SIZE,d3
	lea	vid_dcache,a4
	add.l	d3,a4			; this band's cache
	move.w	d0,d3
	lsl.w	#8,d3
	lea	vid_luts,a3
	add.w	d3,a3			; A
	; the inputs as before?
	lea	vid_dvalid,a0
	tst.b	0(a0,d0.w)
	beq	.calc
	cmp.w	vid_dclo,d1		; (one range for all bands: the program's)
	bne	.calc
	cmp.w	vid_dchi,d2
	bne	.calc
	move.l	a3,a0
	move.l	a4,a1
	moveq	#256/4-1,d3
.c1:	cmpm.l	(a0)+,(a1)+
	bne	.calc
	dbf	d3,.c1
	move.w	vid_dband,d3
	lsl.w	#4,d3
	lea	vid_reps,a0
	add.w	d3,a0
	moveq	#4-1,d4
.c2:	cmpm.l	(a0)+,(a1)+
	bne	.calc
	dbf	d4,.c2
	lea	vid_keep,a0
	add.w	d3,a0
	moveq	#4-1,d4
.c3:	cmpm.l	(a0)+,(a1)+
	bne	.calc
	dbf	d4,.c3
	move.w	d1,d3			; the range's colours
	mulu	#3,d3
	lea	0(a5,d3.w),a0
	add.w	d3,a1
	move.w	d2,d4
	sub.w	d1,d4
	addq.w	#1,d4
	mulu	#3,d4
	subq.w	#1,d4
.c4:	cmpm.b	(a0)+,(a1)+
	bne	.calc
	dbf	d4,.c4
	moveq	#0,d0			; nothing changed
	bra	.out
.calc:	move.w	vid_dband,d0		; the inputs into the cache
	lea	vid_dvalid,a0
	st	0(a0,d0.w)
	move.w	vid_dlo,vid_dclo
	move.w	vid_dhi,vid_dchi
	move.l	a3,a0
	move.l	a4,a1
	moveq	#256/4-1,d3
.k1:	move.l	(a0)+,(a1)+
	dbf	d3,.k1
	lsl.w	#4,d0
	lea	vid_reps,a0
	add.w	d0,a0
	moveq	#4-1,d3
.k2:	move.l	(a0)+,(a1)+
	dbf	d3,.k2
	lea	vid_keep,a0
	add.w	d0,a0
	moveq	#4-1,d3
.k3:	move.l	(a0)+,(a1)+
	dbf	d3,.k3
	move.l	a5,a0
	move.w	#768/4-1,d3
.k4:	move.b	(a0)+,(a1)+
	move.b	(a0)+,(a1)+
	move.b	(a0)+,(a1)+
	move.b	(a0)+,(a1)+
	dbf	d3,.k4
	; the slots: usable (rep in range, not kept) and their colours as shown (0-255)
	lea	vid_reps,a0
	add.w	d0,a0
	lea	vid_keep,a1
	add.w	d0,a1
	lea	vid_dslot,a2		; per slot: usable.w, r.w, g.w, b.w
	moveq	#16-1,d7
.sl:	moveq	#0,d3
	move.b	(a0)+,d3		; rep
	clr.w	(a2)
	tst.b	(a1)+
	bne.s	.sk
	cmp.w	vid_dlo,d3
	blo.s	.sk
	cmp.w	vid_dhi,d3
	bhi.s	.sk
	move.w	#1,(a2)
.sk:	mulu	#3,d3
	lea	0(a5,d3.w),a3
	lea	2(a2),a2
	moveq	#3-1,d6
.sc:	moveq	#0,d4
	move.b	(a3)+,d4		; 6-bit -> STE nibble -> level -> * 17
	lea	vid_c6tab,a4
	move.b	0(a4,d4.w),d4
	lea	vid_dec4,a4
	move.b	0(a4,d4.w),d4
	mulu	#17,d4
	move.w	d4,(a2)+
	dbf	d6,.sc
	dbf	d7,.sl
	; B for every index: A outside the range
	move.w	vid_dband,d0
	lsl.w	#8,d0
	lea	vid_luts,a3
	add.w	d0,a3			; A
	lea	vid_dnew,a4		; B being made
	move.l	a3,a0
	move.l	a4,a1
	moveq	#256/4-1,d3
.cb:	move.l	(a0)+,(a1)+
	dbf	d3,.cb
	move.w	vid_dlo,d7		; index
.ix:	cmp.w	vid_dhi,d7
	bhi	.made
	moveq	#0,d6
	move.b	0(a3,d7.w),d6		; A
	lea	vid_dslot,a2
	move.w	d6,d0
	lsl.w	#3,d0
	add.w	d0,a2
	tst.w	(a2)+			; A's colour from the range?
	beq	.nx
	movem.w	(a2),d0-d2		; cA
	move.w	d7,d3			; t (0-255)
	mulu	#3,d3
	lea	0(a5,d3.w),a0
	lea	vid_c6v,a1
	moveq	#0,d3
	move.b	(a0)+,d3
	move.b	0(a1,d3.w),d3
	moveq	#0,d4
	move.b	(a0)+,d4
	move.b	0(a1,d4.w),d4
	moveq	#0,d5
	move.b	(a0),d5
	move.b	0(a1,d5.w),d5
	movem.w	d3-d5,vid_dt
	movem.w	d0-d2,vid_dca
	sub.w	d0,d3			; eA^2
	muls	d3,d3
	sub.w	d1,d4
	muls	d4,d4
	add.l	d4,d3
	sub.w	d2,d5
	muls	d5,d5
	add.l	d5,d3
	cmp.l	#VID_DTHR*VID_DTHR,d3
	bls	.nx
	move.l	d3,vid_dea		; |A+B-2t|^2 must not exceed eA^2 (half the error)
	move.l	#$7fffffff,vid_dbest
	move.w	d6,vid_dbs
	lea	vid_dslot,a2
	moveq	#0,d5			; slot s
.s:	cmp.w	d6,d5
	beq	.sn
	tst.w	(a2)
	beq	.sn
	movem.w	2(a2),d0-d2		; cs
	movem.w	vid_dca,d3-d4		; (r, g of A)
	move.w	d0,a0			; keep cs.r
	add.w	d3,d0			; A + B - 2t, per channel
	sub.w	vid_dt,d0
	sub.w	vid_dt,d0
	muls	d0,d0
	add.w	d4,d1
	sub.w	vid_dt+2,d1
	sub.w	vid_dt+2,d1
	muls	d1,d1
	add.l	d1,d0
	move.w	vid_dca+4,d1
	add.w	d1,d2
	sub.w	vid_dt+4,d2
	sub.w	vid_dt+4,d2
	muls	d2,d2
	add.l	d2,d0			; S1
	cmp.l	vid_dea,d0
	bhi	.sn
	move.l	d0,d1
	add.l	d1,d1
	add.l	d1,d1
	add.l	d1,d0			; 5*S1
	move.w	a0,d1			; |A - B|^2
	sub.w	d3,d1
	muls	d1,d1
	move.w	4(a2),d2
	sub.w	d4,d2
	muls	d2,d2
	add.l	d2,d1
	move.w	6(a2),d2
	sub.w	vid_dca+4,d2
	muls	d2,d2
	add.l	d2,d1
	add.l	d1,d1
	add.l	d1,d0			; + 2*S2
	cmp.l	vid_dbest,d0
	bhs.s	.sn
	move.l	d0,vid_dbest
	move.w	d5,vid_dbs
.sn:	lea	8(a2),a2
	addq.w	#1,d5
	cmp.w	#16,d5
	blo	.s
	move.b	vid_dbs+1,0(a4,d7.w)
.nx:	addq.w	#1,d7
	bra	.ix
.made:	move.w	vid_dband,d0		; changed from the B made last time?
	mulu	#VDC_SIZE,d0
	lea	vid_dcache+256+16+16+768,a1
	add.l	d0,a1
	move.l	a4,a0
	moveq	#0,d5
	moveq	#256/4-1,d3
.cm:	cmpm.l	(a0)+,(a1)+
	beq.s	.cme
	moveq	#1,d5
.cme:	dbf	d3,.cm
	sub.w	#256,a1			; (keep it)
	move.l	a4,a0
	moveq	#256/4-1,d3
.kb:	move.l	(a0)+,(a1)+
	dbf	d3,.kb
	; into vid_lutsb and the band's B quarter of vid_luts4 (always: vid_set_luts reset them)
	move.w	vid_dband,d0
	move.w	d0,d1
	lsl.w	#8,d1
	lea	vid_lutsb,a1
	add.w	d1,a1
	move.w	d0,d1
	mulu	#768,d1
	lea	vid_luts4+256,a2
	add.w	d1,a2
	move.l	a4,a0
	moveq	#0,d6			; any different from the B in use?
	move.w	#256-1,d3
.wb:	move.b	(a0)+,d1
	cmp.b	(a1),d1
	beq.s	.ws
	moveq	#1,d6
.ws:	move.b	d1,(a1)+
	add.b	d1,d1
	add.b	d1,d1
	move.b	d1,(a2)+
	dbf	d3,.wb
	move.w	vid_dband,d0		; dithered at all? (gfx_pair_get: such a band's two pair
	lea	vid_ddith,a0		; tables may take slots from undithered bands)
	sf	0(a0,d0.w)
	lsl.w	#8,d0
	lea	vid_luts,a1
	add.w	d0,a1
	move.l	a4,a2
	move.w	#256-1,d3
.dd:	cmpm.b	(a1)+,(a2)+
	dbne	d3,.dd
	beq.s	.dn
	move.w	vid_dband,d0
	st	0(a0,d0.w)
.dn:	tst.w	d6
	beq.s	.same
	addq.l	#1,vid_lutgen		; (the flush's mirror and the pair tables follow)
	bsr	gfx_pair_inval
.same:	move.w	d5,d0
.out:	movem.l	(sp)+,d3-d7/a3-a5
	rts

vid_lut_y:
	move.l	d1,-(sp)
	and.w	#$ff,d1
	lsl.w	#2,d1
	lea	vid_line_lut,a1
	move.l	0(a1,d1.w),a1
	move.l	(sp)+,d1
	rts

vid_vsync:
	move.l	vid_frames,d0
.w:	cmp.l	vid_frames,d0
	beq.s	.w
	rts

vid_flip:
	bsr	snd_poll
	move.l	vid_log,d0
	move.l	d0,vid_pending
.w:	tst.l	vid_pending		; taken by the VBL
	bne.s	.w
	move.l	vid_phys,d1		; previous buffer: still on screen this frame
	move.l	d0,vid_phys
	move.l	vid_spare,vid_log	; draw into the free one
	move.l	d1,vid_spare		; becomes free after the next VBL
	rts

vid_defer_on:				; (vid_palscr first: vid_palnext is only taken with it)
	move.l	vid_log,vid_palscr
	st	vid_defer
	rts
vid_flip_pal:
	sf	vid_defer
	bsr	vid_flip
.w:	tst.l	vid_palnext		; until the VBL that shows it has taken the palette
	beq.s	.x
	bsr	snd_poll
	bra.s	.w
.x:	rts

vid_clear:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	SCR_SIZE(a0),a0
	moveq	#0,d0
	moveq	#0,d1
	moveq	#0,d3
	moveq	#0,d4
	moveq	#0,d5
	moveq	#0,d6
	moveq	#0,d7
	move.l	d0,a1
	move.l	d0,a2
	move.l	d0,a3
	move.l	d0,a4
	move.l	d0,a5
	move.w	#SCR_SIZE/48-1,d2	; 666 x 48 bytes = 31968
.c:	movem.l	d0-d1/d3-d7/a1-a5,-(a0)	; 12 registers = 48 bytes
	dbf	d2,.c
	movem.l	d0-d1/d3-d7/a1,-(a0)	; last 32 bytes
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; ---------------------------------------------------------------
vid_vbl_handler:
	movem.l	d0-d7/a0-a3,-(sp)
	move.l	vid_written,vid_shown	; the base written last VBL is on screen now
	move.l	vid_palnext,d0		; (Phase 6j) a palette that goes with that screen
	beq.s	.npal
	move.l	vid_shown,d1
	cmp.l	vid_palscr,d1
	bne.s	.npal
	move.l	d0,vid_cur
	clr.l	vid_palnext
	clr.l	vid_palscr
.npal:	move.l	vid_pending,d0
	beq.s	.nosw
	move.l	d0,vid_written
	lsr.w	#8,d0			; STE: high, mid, low base bytes
	move.b	d0,VID_BASEM.w
	swap	d0
	move.b	d0,VID_BASEH.w
	move.l	vid_pending,d0
	move.b	d0,VID_BASEL.w
	clr.l	vid_pending
.nosw:	move.l	vid_cur,a0
	move.w	(a0)+,d0		; band count
	addq.l	#2,a0			; band 0 first line
	movem.l	(a0)+,d1-d7/a3
	movem.l	d1-d7/a3,VID_PAL.w
	clr.b	MFP_TBCR.w
	subq.w	#1,d0
	move.w	d0,vid_tb_left
	beq.s	.nosplit
	move.l	a0,vid_tb_ptr		; -> band 1
	move.w	(a0),d1			; its first line
	move.w	d1,d2
	subq.w	#1,d2			; fire at the end of line (split-2)
	move.b	d2,MFP_TBDR.w
	move.b	#8,MFP_TBCR.w		; event count on display enable
	mulu	#SCR_BPL,d1
	add.l	vid_shown,d1
	lsl.l	#8,d1
	move.l	d1,vid_tb_target
.nosplit:
	addq.l	#1,vid_frames
	move.l	vid_vbl_hook,d0		; screen module hook, runs before cursor and mixer
	beq.s	.nohook			; (top of the frame: beam still in the border)
	move.l	d0,a0
	jsr	(a0)
.nohook:
	bsr	kbd_vbl			; mouse cursor
	bsr	snd_vbl			; mixer refill
	movem.l	(sp)+,d0-d7/a0-a3
	move.l	sys_oldvec+16,-(sp)	; chain to TOS
	rts

; Timer B: next band. Polls until the counter reaches the split line's first byte.
vid_tb_handler:
	movem.l	d0-d7/a0-a3,-(sp)
	move.l	vid_tb_ptr,a0
	lea	2(a0),a2
	movem.l	(a2)+,d1-d7/a3		; the 16 colours
	lea	VID_COUNT.w,a1
	move.l	vid_tb_target,a2
	ifd	TBLOG			; (kit/hwcheck.s only: the split's timing statistics)
	movep.l	0(a1),d0
	clr.b	d0
	cmp.l	a2,d0
	blo.s	.w
	move.w	vid_tbsel,d0		; the interrupt came after the split line had begun
	lea	vid_tbst,a0
	addq.l	#1,TBS_ENT(a0,d0.w)
	move.l	vid_tb_ptr,a0
	endc
.w:	movep.l	0(a1),d0
	clr.b	d0
	cmp.l	a2,d0
	blo.s	.w
	movem.l	d1-d7/a3,VID_PAL.w
	ifd	TBLOG			; the counter after the write: still the line's start = in the
	movep.l	0(a1),d0		; blank before it (on time); past it = the first pixels of the
	clr.b	d0			; line showed the old colours
	sub.l	a2,d0
	lsr.l	#8,d0			; bytes late (1 byte = 2 pixels)
	lea	vid_tbst,a3
	add.w	vid_tbsel,a3
	addq.l	#1,TBS_N(a3)
	tst.l	d0
	beq.s	.tbok
	addq.l	#1,TBS_LATE(a3)
	cmp.l	TBS_MAX(a3),d0
	bls.s	.tbm
	move.l	d0,TBS_MAX(a3)
.tbm:	cmp.l	#8,d0
	blo.s	.tbok
	addq.l	#1,TBS_BIG(a3)
.tbok:
	endc
	; schedule the next band (not time critical any more)
	clr.b	MFP_TBCR.w
	subq.w	#1,vid_tb_left
	beq.s	.done
	move.w	(a0),d1			; this band's line
	lea	BAND_SIZE(a0),a0
	move.l	a0,vid_tb_ptr
	move.w	(a0),d0			; next band's line
	sub.w	d1,d0			; lines between splits
	move.w	d0,d1
	subq.w	#1,d1
	move.b	d1,MFP_TBDR.w
	move.b	#8,MFP_TBCR.w
	mulu	#SCR_BPL*256,d0		; counter target advances by lines*160 (<<8)
	add.l	d0,vid_tb_target
.done:	movem.l	(sp)+,d0-d7/a0-a3
	bclr	#0,MFP_ISRA.w
	rte

; Let Timer B preempt TOS's Timer C and ACIA handlers ([CG] recipe, PLAN §7).
vid_tc_wrap:
	move.w	#$2500,sr
	move.l	sys_oldvec+20,-(sp)
	rts
vid_acia_wrap:
	move.w	#$2500,sr
	move.l	sys_oldvec+24,-(sp)
	rts

	section	data
vid_c6tab:				; 6-bit VGA level -> STE nibble: round(c*15/63), LSB moved to bit 3
	dc.b	0,0,0,8,8,8,8,1,1,1,1,9,9,9,9,2,2,2,2,10,10,10,10,10,3,3,3,3,11,11,11,11
	dc.b	4,4,4,4,12,12,12,12,5,5,5,5,5,13,13,13,13,6,6,6,6,14,14,14,14,7,7,7,7,15,15,15
vid_dec4:				; STE nibble -> level 0-15
	dc.b	0,2,4,6,8,10,12,14,1,3,5,7,9,11,13,15
vid_c6v:				; (Phase 7) 6-bit level -> 0-255: round(c*255/63)
c	set	0
	rept	64
	dc.b	(c*255+31)/63
c	set	c+1
	endr
vid_black_bands:
	dc.w	1,0
	dcb.w	16,0
	even
vid_cur:	dc.l	vid_bands_a
vid_palnext:	dc.l	0		; (Phase 6j) the next palette copy, shown from the frame that
vid_palscr:	dc.l	0		; shows this screen (vid_flip_pal)
vid_defer:	dc.b	0		; vid_set_fade builds into vid_palnext instead of vid_cur
	even

	section	bss
vid_scr:	ds.l	3
vid_spare:	ds.l	1
vid_phys:	ds.l	1
vid_log:	ds.l	1
vid_shown:	ds.l	1
vid_written:	ds.l	1
vid_pending:	ds.l	1
vid_frames:	ds.l	1
vid_vbl_hook:	ds.l	1
vid_tb_ptr:	ds.l	1
vid_tb_target:	ds.l	1
vid_tb_left:	ds.w	1
	ifd	TBLOG			; Timer B statistics (kit/hwcheck.s): two sets, vid_tbsel = 0 or
vid_tbsel:	ds.w	1		; TBS_SIZE picks the one counted (e.g. while a disk read runs)
vid_tbst:	ds.b	2*TBS_SIZE
	endc
vid_fade:	ds.w	1
vid_bands_src:	ds.b	2+4*BAND_SIZE
vid_bands_a:	ds.b	2+4*BAND_SIZE
vid_bands_b:	ds.b	2+4*BAND_SIZE
vid_fadetab:	ds.b	17*16
vid_luts:	ds.b	4*256
vid_luts4:	ds.b	4*768		; per band [A, B, A] x4 (slot*4: gfx_c4_span; Phase 7)
vid_lutsb:	ds.b	4*256		; (Phase 7) the odd-pixel LUTs (= vid_luts unless dithered)
vid_dhook:	ds.l	1		; (Phase 7) called at the end of vid_set256, a0 = its palette
vid_dpal:	ds.l	1		; the palette of the last vid_set256
vid_dvalid:	ds.b	4		; per band: its dither cache holds inputs
vid_ddith:	ds.b	4		; per band: some index has B <> A
vid_dband:	ds.w	1
vid_dlo:	ds.w	1
vid_dhi:	ds.w	1
vid_dclo:	ds.w	1
vid_dchi:	ds.w	1
vid_dt:		ds.w	3
vid_dca:	ds.w	3
vid_dbs:	ds.w	1
vid_dea:	ds.l	1
vid_dbest:	ds.l	1
vid_dslot:	ds.w	16*4
vid_dnew:	ds.b	256
vid_dcache:	ds.b	4*VDC_SIZE
vid_line_lut:	ds.l	SCR_H
vid_lutgen:	ds.l	1		; (Phase 6k) +1 at every vid_set_luts
vid_line_band:	ds.b	SCR_H
vid_reps:	ds.b	64
vid_best:	ds.b	1
	even
vid_keep:	ds.b	64
	even
vid_rgbfirst:	ds.b	256		; vid_setrgb's chains (vid_rgbchains)
vid_rgbnext:	ds.b	140
vid_rgbbands:	ds.w	1
vid_rgbok:	ds.b	1
	even
vid_screens:	ds.b	3*SCR_SIZE+256

	section	text
vid_fade_ms:
	movem.l	d3-d5,-(sp)
	move.w	d0,d3			; level
	move.w	d1,d4			; target
	move.w	d1,d5
	sub.w	d0,d5
	bpl.s	.p
	neg.w	d5
.p:	tst.w	d5
	beq.s	.last
	ext.l	d2
	divu	d5,d2			; ms per step
	move.w	d2,d5
.lp:	cmp.w	d4,d3
	beq.s	.last
	blt.s	.up
	subq.w	#1,d3
	bra.s	.set
.up:	addq.w	#1,d3
.set:	move.w	d3,d0
	bsr	vid_set_fade
	move.w	d5,d0
	bsr	tim_delay
	bra.s	.lp
.last:	move.w	d4,d0
	bsr	vid_set_fade
	movem.l	(sp)+,d3-d5
	rts
