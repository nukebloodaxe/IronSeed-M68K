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
; Screens: vid_scr = 3 buffers (256-byte aligned, 32000 bytes); vid_log = where to draw next;
; vid_phys = last flipped (or the start-up screen); programs that never flip draw into vid_phys.

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
	move.w	(a0)+,d1
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
vid_set_luts:
	move.l	a3,-(sp)
	lea	vid_luts,a1
	cmp.l	a0,a1
	beq.s	.same
	move.w	#1024/4-1,d0
.cp:	move.l	(a0)+,(a1)+
	dbf	d0,.cp
.same:	lea	vid_bands_src,a0
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
vid_tb_ptr:	ds.l	1
vid_tb_target:	ds.l	1
vid_tb_left:	ds.w	1
vid_fade:	ds.w	1
vid_bands_src:	ds.b	2+4*BAND_SIZE
vid_bands_a:	ds.b	2+4*BAND_SIZE
vid_bands_b:	ds.b	2+4*BAND_SIZE
vid_fadetab:	ds.b	17*16
vid_luts:	ds.b	4*256
vid_line_lut:	ds.l	SCR_H
vid_line_band:	ds.b	SCR_H
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
