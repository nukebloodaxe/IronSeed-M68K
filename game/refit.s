; refit.s - MAIN.PRG (Phase 6j): band designs fitted at run time for dialogs.
;
; A dialog drawn over a screen brings colours that the screen's band design has no slots for
; (the save dialog over the bridge: band 1 holds the planet's greys and one blue, so the rows'
; bevels and the selected row's highlight vanish). ms_refit chooses new colours for the bands the
; dialog covers from what the shadow holds now - dialog included - and shows them; ms_refit_end
; puts the design back. Each shows the shadow at once (ms_flush, the colours there are), then
; switches: the band's lines are converted into the spare screen and screen and palette change in
; the same frame (kernel vid_flip_pal) - no frame shows slots and colours that do not belong
; together. (~0.6 s for the bridge's viewscreen band at open, ~0.4 s at close.)
;
; ms_refit      in: d0.w x1, d1.w y1, d2.w x2, d3.w y2 (the dialog, inclusive), d4.w fade (the
;               dialog's highlight: plainfadearea's step, 0 = none; its shades are added at half
;               weight).  trashes: d0-d2/a0-a2
; ms_refit_end  the design as before ms_refit (nothing when none is active), the shadow's
;               current contents converted with it.  trashes: d0-d2/a0-a2
;
; The fit (per band, 16 slots): a histogram of the band's lines in the shadow (every other line,
; plus the dialog's shades), the used colours merged by the colour the STE shows (the index with the
; most pixels represents them; 6-bit RGB of GS_COLORS) weighted by their pixel counts; slot 0 keeps
; its colour (the border's black); slots 1-15 start by weighted farthest-point picks, then four
; rounds of weighted k-means; each slot's rep is the used index nearest its centre. The band's LUT
; maps every index to the nearest slot colour as shown (STE levels), as vid_lut_remap does. Only
; bands with at least RF_MINL of the dialog's lines are refitted.

RF_MINL		equ	8
RF_ITER		equ	4

	section	text
ms_refit:
	PMARK	43			; (PROFILE: tools/dbgtimes.py - the refit's time)
	movem.l	d3-d7/a3-a5,-(sp)
	tst.b	rf_on			; (one at a time: a nested dialog keeps the first fit)
	bne	.x
	movem.w	d0-d4,-(sp)		; the dialog on the screen at once, in the colours there are;
	bsr	ms_flush		; the better ones follow
	movem.w	(sp)+,d0-d4
	movem.w	d0-d4,rf_x1		; x1, y1, x2, y2, fade
	lea	vid_reps,a0		; keep the design
	lea	rf_sreps,a1
	moveq	#64/4-1,d0
.k1:	move.l	(a0)+,(a1)+
	dbf	d0,.k1
	lea	vid_keep,a0
	lea	rf_skeep,a1
	moveq	#64/4-1,d0
.k2:	move.l	(a0)+,(a1)+
	dbf	d0,.k2
	lea	vid_luts,a0
	lea	rf_sluts,a1
	move.w	#1024/4-1,d0
.k3:	move.l	(a0)+,(a1)+
	dbf	d0,.k3
	clr.b	rf_mask
	lea	vid_bands_src,a0
	move.w	(a0),d7			; bands
	moveq	#0,d6			; band
.b:	move.w	d6,d0
	bsr	rf_lines		; d0 = first, d1 = last line
	move.w	rf_y1,d2		; overlap with the dialog
	cmp.w	d2,d0
	bge.s	.o1
	move.w	d2,d0
.o1:	move.w	rf_y2,d2
	cmp.w	d2,d1
	ble.s	.o2
	move.w	d2,d1
.o2:	sub.w	d0,d1
	cmp.w	#RF_MINL-1,d1
	blt.s	.nb
	move.w	d6,d0
	bsr	rf_band
	bset	d6,rf_mask
.nb:	addq.w	#1,d6
	cmp.w	d7,d6
	blt.s	.b
	tst.b	rf_mask
	beq	.x
	st	rf_on
	st	gfx_pnobuild		; (the LUTs are temporary: cached pair tables only, until the end)
	sf	vid_rgbok		; (reps and keep flags written directly: vid_setrgb's chains)
	bsr	vid_defer_on
	lea	GS_COLORS(a6),a0	; the slots' colours from their new reps (deferred)
	bsr	vid_set256
	moveq	#0,d6			; and each refitted band's LUT from them
.l:	btst	d6,rf_mask
	beq.s	.ln
	move.w	d6,d0
	bsr	rf_lut
.ln:	addq.w	#1,d6
	cmp.w	d7,d6
	blt.s	.l
	lea	vid_luts,a0
	bsr	vid_set_luts
	bsr	rf_switch
.x:	movem.l	(sp)+,d3-d7/a3-a5
	PMARK	44
	rts

ms_refit_end:
	tst.b	rf_on
	beq.s	.x
	movem.l	d3-d7/a3-a5,-(sp)
	sf	rf_on
	PMARK	45
	bsr	ms_flush		; (what the dialog covered, at once)
	bsr	vid_defer_on
	lea	rf_sreps,a0
	bsr	vid_set_reps
	lea	rf_skeep,a0
	bsr	vid_set_keep
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	lea	rf_sluts,a0
	bsr	vid_set_luts
	bsr	rf_switch
	sf	gfx_pnobuild
	PMARK	46
	movem.l	(sp)+,d3-d7/a3-a5
.x:	rts

; band d0.w -> d0.w first line, d1.w last line.  trashes: a0
rf_lines:
	lea	vid_bands_src,a0
	move.w	d0,d1
	mulu	#BAND_SIZE,d1
	addq.w	#1,d0
	cmp.w	(a0),d0			; the last band: to line 199
	blt.s	.n
	move.w	2(a0,d1.w),d0
	move.w	#SCR_H-1,d1
	rts
.n:	move.w	2+BAND_SIZE(a0,d1.w),d0	; the next band's first line - 1
	subq.w	#1,d0
	move.w	2(a0,d1.w),d1
	exg	d0,d1
	rts

; the refitted bands' lines converted into the spare screen with the new LUTs, then screen and
; palette shown from the same frame (the palette changes were deferred by the caller)
rf_switch:
	move.w	kbd_cur_on,-(sp)
	bsr	kbd_cursor_hide
	move.l	vid_phys,a0		; the spare := the screen
	move.l	vid_log,a1
	move.w	#SCR_SIZE/32-1,d0
.c:	movem.l	(a0)+,d1-d7/a2
	movem.l	d1-d7/a2,(a1)
	lea	32(a1),a1
	dbf	d0,.c
	move.l	vid_log,gfx_target
	moveq	#0,d6
.b:	btst	d6,rf_mask
	beq.s	.bn
	move.w	d6,d0
	bsr	rf_lines
	move.w	d1,d3
	move.w	d0,d1
	moveq	#0,d0
	move.w	#MS_W-1,d2
	bsr	ms_dirty
.bn:	addq.w	#1,d6
	cmp.w	#4,d6
	blt.s	.b
	bsr	ms_flush
	bsr	vid_flip_pal
	move.l	vid_phys,gfx_target
	tst.w	(sp)+
	beq.s	.x
	bsr	kbd_cursor_show
.x:	rts

; rf_band(d0.w band): the band's histogram, the fit, its reps (vid_reps) and keep flags cleared
rf_band:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,rf_b
	bsr	rf_lines
	move.w	d0,d6			; first line
	move.w	d1,d7			; last
	lea	rf_hist,a0		; the band's histogram
	moveq	#256/2-1,d0
.hc:	clr.l	(a0)+
	dbf	d0,.hc
	lea	rf_hist,a1		; (every other line, weight 2: the fit only needs proportions)
	move.w	d6,d3
.hy:	move.w	d3,d1
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	moveq	#MS_W/8-1,d2
.h:
	rept	8
	moveq	#0,d0
	move.b	(a0)+,d0
	add.w	d0,d0
	addq.w	#2,0(a1,d0.w)
	endr
	dbf	d2,.h
	addq.w	#2,d3
	cmp.w	d7,d3
	ble.s	.hy
	move.w	rf_fade,d5		; the dialog's highlight shades: its pixels' indices + fade,
	beq	.nf			; at half weight (within the band's lines)
	lea	rf_hist2,a0
	moveq	#256/2-1,d0
.hc2:	clr.l	(a0)+
	dbf	d0,.hc2
	move.w	rf_y1,d3
	cmp.w	d6,d3
	bge.s	.r1
	move.w	d6,d3
.r1:	move.w	rf_y2,d4
	cmp.w	d7,d4
	ble.s	.r2
	move.w	d7,d4
.r2:	lea	rf_hist2,a1
.ry:	move.w	d3,d1
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	add.w	rf_x1,a0
	move.w	rf_x2,d2
	sub.w	rf_x1,d2
.rx:	moveq	#0,d0
	move.b	(a0)+,d0
	add.w	d0,d0
	addq.w	#2,0(a1,d0.w)
	dbf	d2,.rx
	addq.w	#2,d3
	cmp.w	d4,d3
	ble.s	.ry
	lea	rf_hist2,a0		; hist[i + fade] += hist2[i] / 2 (+ 1)
	lea	rf_hist,a1
	moveq	#0,d0
.fs:	move.w	(a0)+,d1
	beq.s	.fn
	move.w	d0,d2
	add.w	d5,d2
	cmp.w	#255,d2
	bhi.s	.fn			; (unsigned: below 0 or above 255)
	lsr.w	#1,d1
	addq.w	#1,d1
	add.w	d2,d2
	add.w	d1,0(a1,d2.w)
	bcc.s	.fn
	move.w	#$ffff,0(a1,d2.w)
.fn:	addq.w	#1,d0
	cmp.w	#256,d0
	blt.s	.fs
.nf:	lea	rf_hist,a0		; the weights must sum below 65536 (divu): halve while needed
.sum:	moveq	#0,d1
	moveq	#0,d2
	move.w	#256-1,d0
.s1:	move.w	(a0)+,d2
	add.l	d2,d1
	dbf	d0,.s1
	lea	-512(a0),a0
	cmp.l	#65535,d1
	bls.s	.ok
	move.w	#256-1,d0
.s2:	move.w	(a0),d2
	beq.s	.s3
	addq.w	#1,d2
	lsr.w	#1,d2
	move.w	d2,(a0)
.s3:	addq.l	#2,a0
	dbf	d0,.s2
	lea	-512(a0),a0
	bra.s	.sum
.ok:	lea	rf_map,a0		; the used colours, one per colour as the STE shows it
	move.w	#4096*2/16-1,d0		; (rf_map: STE colour -> entry + 1)
.mc:	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	dbf	d0,.mc
	lea	rf_hist,a0
	lea	GS_COLORS(a6),a2
	lea	vid_c6tab,a3
	lea	rf_map,a4
	moveq	#0,d0			; index
	moveq	#0,d3			; n
.u:	move.w	(a0)+,d1		; its count
	beq	.un
	move.w	d0,d2
	mulu	#3,d2
	lea	0(a2,d2.w),a1		; its colour
	moveq	#0,d4			; its STE code
	move.b	(a1),d4
	move.b	0(a3,d4.w),d4
	lsl.w	#4,d4
	moveq	#0,d5
	move.b	1(a1),d5
	or.b	0(a3,d5.w),d4
	lsl.w	#4,d4
	move.b	2(a1),d5
	or.b	0(a3,d5.w),d4
	add.w	d4,d4
	move.w	0(a4,d4.w),d5		; entry + 1
	bne.s	.old
	addq.w	#1,d3			; a new entry: this index, its count, its colour
	move.w	d3,0(a4,d4.w)
	move.w	d3,d5
	subq.w	#1,d5
	lea	rf_ci,a5
	move.b	d0,0(a5,d5.w)
	add.w	d5,d5
	lea	rf_cw,a5
	move.w	d1,0(a5,d5.w)
	lea	rf_cb,a5
	move.w	d1,0(a5,d5.w)
	move.w	d5,d4
	add.w	d5,d5
	add.w	d4,d5			; entry * 6
	lea	rf_cc,a5
	add.w	d5,a5
	moveq	#0,d4
	move.b	(a1)+,d4
	move.w	d4,(a5)+
	move.b	(a1)+,d4
	move.w	d4,(a5)+
	move.b	(a1),d4
	move.w	d4,(a5)
	bra.s	.un
.old:	subq.w	#1,d5			; the same colour as an entry: its weight; the index with the
	add.w	d5,d5			; largest count represents it
	lea	rf_cw,a5
	add.w	d1,0(a5,d5.w)
	lea	rf_cb,a5
	cmp.w	0(a5,d5.w),d1
	bls.s	.un
	move.w	d1,0(a5,d5.w)
	lsr.w	#1,d5
	lea	rf_ci,a5
	move.b	d0,0(a5,d5.w)
.un:	addq.w	#1,d0
	cmp.w	#256,d0
	blt	.u
	move.w	d3,rf_n
	move.w	rf_b,d0			; centre 0: slot 0's colour, fixed
	lsl.w	#4,d0
	lea	vid_reps,a0
	moveq	#0,d1
	move.b	0(a0,d0.w),d1
	move.b	d1,rf_pick
	mulu	#3,d1
	lea	rf_cent,a1
	moveq	#0,d0
	move.b	0(a2,d1.w),d0
	move.w	d0,(a1)+
	move.b	1(a2,d1.w),d0
	move.w	d0,(a1)+
	move.b	2(a2,d1.w),d0
	move.w	d0,(a1)+
	bsr	rf_init
	moveq	#RF_ITER-1,d7
.it:	bsr	rf_assign
	bsr	rf_update
	dbf	d7,.it
	bsr	rf_assign
	bsr	rf_reps
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; d0-d2 = colour A (words), a1 -> colour B (3 words, a1 advances), \1 = the squares table's
; centre (rf_sq + 2*63): d3.w = squared distance (< 65536).  trashes: d4
; RFDE: the same with early exits to \2 once the partial sum reaches d7 (the best so far)
RFDE	macro
	move.w	d0,d4
	sub.w	(a1)+,d4
	add.w	d4,d4
	move.w	0(\1,d4.w),d3
	cmp.w	d7,d3
	bhs.s	\2
	move.w	d1,d4
	sub.w	(a1)+,d4
	add.w	d4,d4
	add.w	0(\1,d4.w),d3
	cmp.w	d7,d3
	bhs.s	\3
	move.w	d2,d4
	sub.w	(a1)+,d4
	add.w	d4,d4
	add.w	0(\1,d4.w),d3
	endm
RFDIST	macro
	move.w	d0,d4
	sub.w	(a1)+,d4
	add.w	d4,d4
	move.w	0(\1,d4.w),d3
	move.w	d1,d4
	sub.w	(a1)+,d4
	add.w	d4,d4
	add.w	0(\1,d4.w),d3
	move.w	d2,d4
	sub.w	(a1)+,d4
	add.w	d4,d4
	add.w	0(\1,d4.w),d3
	endm

; weighted farthest-point picks for slots 1-15: rf_md[k] = distance to the nearest centre so far
rf_init:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	rf_sq+2*63,a5
	lea	rf_cc,a0
	lea	rf_md,a2
	move.w	rf_n,d6
	subq.w	#1,d6
	bmi	.x
.m0:	movem.w	(a0)+,d0-d2
	lea	rf_cent,a1
	RFDIST	a5
	move.w	d3,(a2)+
	dbf	d6,.m0
	moveq	#1,d5			; slot
.sl:	lea	rf_md,a2		; k with the largest w * md
	lea	rf_cw,a3
	moveq	#0,d7			; best value
	moveq	#-1,d6			; best k
	moveq	#0,d0
	move.w	rf_n,d2
.k:	move.w	(a2)+,d1
	mulu	(a3)+,d1
	cmp.l	d7,d1
	bls.s	.kn
	move.l	d1,d7
	move.w	d0,d6
.kn:	addq.w	#1,d0
	cmp.w	d2,d0
	blt.s	.k
	lea	rf_cent,a1
	move.w	d5,d0
	mulu	#6,d0
	add.w	d0,a1
	lea	rf_pick,a4
	tst.w	d6
	bmi.s	.dup			; every colour is a centre already: repeat centre 0
	lea	rf_ci,a0
	move.b	0(a0,d6.w),0(a4,d5.w)
	move.w	d6,d0
	mulu	#6,d0
	lea	rf_cc,a0
	move.l	0(a0,d0.w),(a1)		; r, g
	move.w	4(a0,d0.w),4(a1)	; b
	move.l	a1,a3
	lea	rf_cc,a0		; md := min(md, distance to the new centre)
	lea	rf_md,a2
	move.w	rf_n,d6
	subq.w	#1,d6
.m1:	movem.w	(a0)+,d0-d2
	move.l	a3,a1
	RFDIST	a5
	cmp.w	(a2)+,d3
	bhs.s	.m2
	move.w	d3,-2(a2)
.m2:	dbf	d6,.m1
	bra.s	.sn
.dup:	move.l	rf_cent,(a1)
	move.w	rf_cent+4,4(a1)
	move.b	(a4),0(a4,d5.w)
.sn:	addq.w	#1,d5
	cmp.w	#16,d5
	blt	.sl
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; each used colour to its nearest centre (rf_ca)
rf_assign:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	rf_sq+2*63,a5
	lea	rf_cc,a0
	lea	rf_ca,a2
	move.w	rf_n,d6
	subq.w	#1,d6
	bmi.s	.x
.k:	movem.w	(a0)+,d0-d2
	lea	rf_cent,a1
	moveq	#-1,d7			; best distance (unsigned word)
	moveq	#0,d5			; slot
.j:	RFDE	a5,.j2,.j1
	cmp.w	d7,d3
	bhs.s	.jn
	move.w	d3,d7
	move.b	d5,(a2)
	bra.s	.jn
.j2:	addq.l	#2,a1			; (an early exit: skip the centre's other components)
.j1:	addq.l	#2,a1
.jn:	addq.w	#1,d5
	cmp.w	#16,d5
	blt.s	.j
	addq.l	#1,a2
	dbf	d6,.k
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; centres 1-15 := the weighted means of their colours (unchanged when empty)
rf_update:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	rf_sum,a0
	moveq	#16*4-1,d0
.c:	clr.l	(a0)+
	dbf	d0,.c
	lea	rf_cc,a0
	lea	rf_cw,a1
	lea	rf_ca,a2
	lea	rf_sum,a3
	move.w	rf_n,d6
	subq.w	#1,d6
	bmi.s	.x
.k:	moveq	#0,d0
	move.b	(a2)+,d0
	lsl.w	#4,d0
	lea	0(a3,d0.w),a4		; sw, sr, sg, sb
	move.w	(a1)+,d1
	moveq	#0,d2
	move.w	d1,d2
	add.l	d2,(a4)+
	move.w	(a0)+,d2
	mulu	d1,d2
	add.l	d2,(a4)+
	move.w	(a0)+,d2
	mulu	d1,d2
	add.l	d2,(a4)+
	move.w	(a0)+,d2
	mulu	d1,d2
	add.l	d2,(a4)+
	dbf	d6,.k
	lea	rf_sum+16,a3		; slot 1 on
	lea	rf_cent+6,a4
	moveq	#15-1,d6
.j:	move.l	(a3)+,d1		; sw (< 65536)
	beq.s	.e
	move.w	d1,d5
	lsr.w	#1,d5			; rounding
	moveq	#3-1,d4
.q:	move.l	(a3)+,d0
	add.l	d5,d0
	divu	d1,d0
	move.w	d0,(a4)+
	dbf	d4,.q
	bra.s	.jn
.e:	lea	12(a3),a3
	addq.l	#6,a4
.jn:	dbf	d6,.j
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; slots 1-15: the used index nearest the centre among its colours (the pick when empty);
; vid_reps and vid_keep of the band
rf_reps:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	rf_sq+2*63,a5
	lea	vid_reps,a3
	move.w	rf_b,d0
	lsl.w	#4,d0
	add.w	d0,a3
	moveq	#1,d5
.j:	moveq	#-1,d7			; best distance (unsigned word)
	lea	rf_pick,a0		; (the pick, when no colour is nearer)
	move.b	0(a0,d5.w),rf_tmp
	lea	rf_cc,a0
	lea	rf_ca,a2
	lea	rf_ci,a4
	move.w	d5,d6
	mulu	#6,d6
	lea	rf_cent,a1
	add.w	d6,a1
	move.l	a1,d6			; this slot's centre
	move.w	rf_n,-(sp)
.k:	subq.w	#1,(sp)
	bmi.s	.set
	cmp.b	(a2)+,d5
	bne.s	.kn
	movem.w	(a0),d0-d2
	move.l	d6,a1
	RFDIST	a5
	cmp.w	d7,d3
	bhs.s	.kn
	move.w	d3,d7
	move.b	(a4),rf_tmp
.kn:	addq.l	#6,a0
	addq.l	#1,a4
	bra.s	.k
.set:	addq.l	#2,sp
	move.b	rf_tmp,0(a3,d5.w)
	addq.w	#1,d5
	cmp.w	#16,d5
	blt	.j
	lea	vid_keep,a4		; every slot from its rep from now on
	move.w	rf_b,d0
	lsl.w	#4,d0
	add.w	d0,a4
	moveq	#16-1,d0
.kc:	clr.b	(a4)+
	dbf	d0,.kc
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; rf_lut(d0.w band): vid_luts[band][i] := the slot whose colour (as shown: STE levels) is
; nearest to index i's colour in GS_COLORS; ties to the lower slot (as vid_lut_remap)
rf_lut:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,d1
	mulu	#BAND_SIZE,d1
	lea	vid_bands_src+4,a0	; the band's colours (decoded once into rf_sc)
	add.w	d1,a0
	lea	rf_sc,a1
	lea	vid_dec4,a2
	moveq	#16-1,d2
.sc:	move.w	(a0)+,d3
	move.w	d3,d4
	lsr.w	#8,d4
	and.w	#15,d4
	moveq	#0,d5
	move.b	0(a2,d4.w),d5
	move.w	d5,(a1)+
	move.w	d3,d4
	lsr.w	#4,d4
	and.w	#15,d4
	move.b	0(a2,d4.w),d5
	move.w	d5,(a1)+
	and.w	#15,d3
	move.b	0(a2,d3.w),d5
	move.w	d5,(a1)+
	dbf	d2,.sc
	lea	vid_luts,a5
	lsl.w	#8,d0
	add.w	d0,a5
	lea	GS_COLORS(a6),a3
	lea	vid_c6tab,a4
	lea	rf_sq+2*63,a0
	moveq	#0,d6			; index
.i:	moveq	#0,d0			; the index's colour as levels
	move.b	(a3)+,d0
	move.b	0(a4,d0.w),d0
	move.b	0(a2,d0.w),d0
	moveq	#0,d1
	move.b	(a3)+,d1
	move.b	0(a4,d1.w),d1
	move.b	0(a2,d1.w),d1
	moveq	#0,d2
	move.b	(a3)+,d2
	move.b	0(a4,d2.w),d2
	move.b	0(a2,d2.w),d2
	lea	rf_sc,a1
	moveq	#-1,d7
	moveq	#0,d5
.s:	RFDE	a0,.s2,.s1
	cmp.w	d7,d3
	bhs.s	.sn
	move.w	d3,d7
	move.b	d5,(a5)
	bra.s	.sn
.s2:	addq.l	#2,a1
.s1:	addq.l	#2,a1
.sn:	addq.w	#1,d5
	cmp.w	#16,d5
	blt.s	.s
	addq.l	#1,a5
	addq.w	#1,d6
	cmp.w	#256,d6
	blt.s	.i
	movem.l	(sp)+,d3-d7/a3-a5
	rts

	section	data
rf_sq:					; (d - 63)^2 for d = 0..126: the squares table
N	set	-63
	rept	127
	dc.w	N*N
N	set	N+1
	endr

	section	bss
rf_x1:		ds.w	1		; (rf_x1 .. rf_fade: movem.w order)
rf_y1:		ds.w	1
rf_x2:		ds.w	1
rf_y2:		ds.w	1
rf_fade:	ds.w	1
rf_b:		ds.w	1
rf_n:		ds.w	1
rf_cent:	ds.w	16*3		; centres (6-bit r, g, b)
rf_sum:		ds.l	16*4		; per slot: weight, r, g, b sums
rf_cc:		ds.w	256*3		; used colours
rf_cw:		ds.w	256		; their weights
rf_cb:		ds.w	256		; the largest count among the indices of an entry
rf_map:		ds.w	4096		; STE colour -> entry + 1
rf_md:		ds.w	256
rf_hist:	ds.w	256
rf_hist2:	ds.w	256
rf_sc:		ds.w	16*3
rf_sreps:	ds.b	64		; the design before the refit
rf_skeep:	ds.b	64
rf_sluts:	ds.b	1024
rf_ci:		ds.b	256		; used colours' indices
rf_ca:		ds.b	256		; their slots
rf_pick:	ds.b	16		; the init's pick per slot
rf_tmp:		ds.b	1
rf_on:		ds.b	1
rf_mask:	ds.b	1		; the refitted bands
	even
	section	text
