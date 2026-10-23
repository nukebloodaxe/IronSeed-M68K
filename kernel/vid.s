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
; Screens: vid_scr = 3 buffers (256-byte aligned, 32000 bytes); vid_log = where to draw next;
; vid_phys = last flipped (or the start-up screen); programs that never flip draw into vid_phys.
; vid_vbl_hook    (long) 0, or a routine the VBL calls every frame after the band-0 palette and
;                 before the cursor and the mixer, i.e. while the beam is still in the top border
;                 (~45 lines, ~23 000 cycles before line 0 at 60 Hz). Interrupt context: may
;                 trash d0-d7/a0-a3 only, no TOS calls, keep it short (the mixer waits).

BAND_SIZE	equ	2+32

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
	move.l	(sp)+,vid_cur
	rts
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
	move.l	(sp)+,vid_cur		; atomic switch for the VBL
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
	lea	vid_reps,a1
	moveq	#64/4-1,d0
.c:	move.l	(a0)+,(a1)+
	dbf	d0,.c
	rts

vid_set_keep:
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

vid_setrgb:
	movem.l	d3-d5,-(sp)
	lea	vid_c6tab,a0
	moveq	#0,d4
	move.b	0(a0,d1.w),d4		; the STE word
	lsl.w	#4,d4
	or.b	0(a0,d2.w),d4
	lsl.w	#4,d4
	or.b	0(a0,d3.w),d4
	lea	vid_reps,a1
	lea	vid_keep,a2
	lea	vid_bands_src,a0
	move.w	(a0)+,d5
	subq.w	#1,d5
	moveq	#0,d3			; any change
.band:	addq.l	#2,a0
	moveq	#16-1,d2
.slot:	tst.b	(a2)+
	bne.s	.n
	cmp.b	(a1),d0
	bne.s	.n
	move.w	d4,(a0)
	moveq	#1,d3
.n:	addq.l	#1,a1
	addq.l	#2,a0
	dbf	d2,.slot
	dbf	d5,.band
	tst.w	d3
	beq.s	.x
	move.w	vid_fade,d0
	bsr	vid_set_fade
.x:	movem.l	(sp)+,d3-d5
	rts

vid_set256:
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
	rts

vid_set_luts:
	move.l	a3,-(sp)
	lea	vid_luts,a1
	cmp.l	a0,a1
	beq.s	.same
	move.w	#1024/4-1,d0
.cp:	move.l	(a0)+,(a1)+
	dbf	d0,.cp
.same:	lea	vid_luts,a0		; slot*4 copies for gfx_c4_span
	lea	vid_luts4,a1
	move.w	#1024-1,d0
.x4:	move.b	(a0)+,d1
	add.b	d1,d1
	add.b	d1,d1
	move.b	d1,(a1)+
	dbf	d0,.x4
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
	move.l	vid_log,d0
	move.l	d0,vid_pending
.w:	tst.l	vid_pending		; taken by the VBL
	bne.s	.w
	move.l	vid_phys,d1		; previous buffer: still on screen this frame
	move.l	d0,vid_phys
	move.l	vid_spare,vid_log	; draw into the free one
	move.l	d1,vid_spare		; becomes free after the next VBL
	rts

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
	move.l	vid_pending,d0
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
.w:	movep.l	0(a1),d0
	clr.b	d0
	cmp.l	a2,d0
	blo.s	.w
	movem.l	d1-d7/a3,VID_PAL.w
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
vid_black_bands:
	dc.w	1,0
	dcb.w	16,0
	even
vid_cur:	dc.l	vid_bands_a

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
vid_fade:	ds.w	1
vid_bands_src:	ds.b	2+4*BAND_SIZE
vid_bands_a:	ds.b	2+4*BAND_SIZE
vid_bands_b:	ds.b	2+4*BAND_SIZE
vid_fadetab:	ds.b	17*16
vid_luts:	ds.b	4*256
vid_luts4:	ds.b	4*256		; the same x4 (slot*4: gfx_c4_span), right after vid_luts
vid_line_lut:	ds.l	SCR_H
vid_line_band:	ds.b	SCR_H
vid_reps:	ds.b	64
vid_best:	ds.b	1
	even
vid_keep:	ds.b	64
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
