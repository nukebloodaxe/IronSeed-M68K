; planet.s - the rotating, lit planet of intro.pas makeplanet (tools/planetref.py is the
; reference; PLANET.DAT comes from tools/mkplanets.py). Include after the kernel.
;
; plan_load     loads PLANET.DAT (once). carry set on error.
; plan_setup    in: d0.w = geometry set (0: radius 3025 / c2 1.09, 1: radius 2000 / c2 1.16,
;               2: radius 400 / c2 1.30)
;               builds per-band long tables (alt, height) -> unshifted plane bits of the slot
;               the colour maps to in that band - call after the scene's picture/bands are set.
;               trashes d0-d2/a0-a2
; plan_invert   land := 255 - land (the battle scene; the original never undoes it)
; plan_reset    land as loaded (generateplanet re-reads plan1.dta when the intro replays)
; plan_frame    in: d0.w = c (rotation, 1..240), d1.w = ecl (lighting). Draws one frame into
;               gfx_target at the original's position (planet^ row r -> screen row r+12,
;               column 1 -> x 28). trashes d0-d2/a0-a2
;
; Per pixel: index*2 (precomputed sample column) -> land height*4 -> + alt*1024 -> long of
; plane bits (bit 0 of each byte), shifted into the cell accumulator d5; 8 pixels -> movep.
; Cells whose indices all lie where the lighting is clamped (same alt) skip the alt lookup.

; one planet pixel, alt from the per-index table (a1)
PLPIX	macro
	move.b	(a3)+,d0		; index*2
	move.w	0(a4,d0.w),d1		; height*4
	add.w	0(a1,d0.w),d1		; + alt*1024
	add.l	d5,d5
	or.l	0(a5,d1.w),d5
	endm
; first pixel of a cell
PLPIX1	macro
	move.b	(a3)+,d0
	move.w	0(a4,d0.w),d1
	add.w	0(a1,d0.w),d1
	move.l	0(a5,d1.w),d5
	endm
; one pixel with constant alt (a0 = that alt's table row)
PLPIXC	macro
	move.b	(a3)+,d0
	move.w	0(a4,d0.w),d1
	add.l	d5,d5
	or.l	0(a0,d1.w),d5
	endm

PLN_F		equ	4			; 30 x 256 game colours
PLN_LAND	equ	PLN_F+30*256		; 120 rows x 360 words (height*4)
PLN_GEO		equ	PLN_LAND+120*360*2
PLN_TAB		equ	30*256*4		; one band's long table
PLR_SIZE	equ	16			; row table entry

	section	text
plan_load:
	tst.l	plan_data
	bne.s	.ok
	lea	fn_planet,a0
	bsr	fil_size
	bcs.s	.err
	move.l	d0,d3
	bsr	mem_alloc
	bcs.s	.err
	move.l	a0,plan_data
	move.l	a0,a1
	lea	fn_planet,a0
	move.l	d3,d0
	bsr	fil_load
	bcs.s	.err
	move.l	#4*PLN_TAB,d0		; per-band long tables
	bsr	mem_alloc
	bcs.s	.err
	move.l	a0,plan_ftab
.ok:	and.b	#$fe,ccr
	rts
.err:	or.b	#1,ccr
	rts

plan_setup:
	movem.l	d3-d4/a3-a4,-(sp)
	move.l	plan_data,a0		; find geometry set d0
	add.l	#PLN_GEO,a0
	bra.s	.ns
.set:	move.w	4(a0),d1		; skip a set: its rows
	addq.l	#6,a0
	subq.w	#1,d1
.sk:	move.w	4(a0),d2		; count
	addq.w	#1,d2
	and.w	#$fffe,d2
	lea	6(a0,d2.w),a0
	dbf	d1,.sk
.ns:	dbf	d0,.set
.g:	move.l	a0,plan_geo
	move.w	2(a0),plan_x
	moveq	#4-1,d3			; bands
	move.l	plan_ftab,a2
	lea	vid_luts,a3
	lea	gfx_ptab+7*64,a4	; unshifted plane bits per slot
.b:	move.l	plan_data,a0
	addq.l	#PLN_F,a0
	move.w	#30*256-1,d4
	moveq	#0,d0
.f:	move.b	(a0)+,d0
	moveq	#0,d1
	move.b	0(a3,d0.w),d1
	add.w	d1,d1
	add.w	d1,d1
	move.l	0(a4,d1.w),(a2)+
	dbf	d4,.f
	lea	256(a3),a3
	dbf	d3,.b
	; per-row constants: screen offset of the first cell, next-cell step, leading skip,
	; land row offset (from plan_data, before + 2c), band table
	move.l	plan_geo,a0
	move.w	4(a0),d3		; rows
	subq.w	#1,d3
	addq.l	#6,a0
	lea	plan_rowtab,a1
.r:	move.w	(a0)+,d0		; ofsy
	move.w	(a0)+,d1		; m
	move.w	(a0)+,d2		; count
	move.w	d0,d4			; land: PLN_LAND - 720 - 2 + (ofsy + 5) * 720
	addq.w	#5,d4
	mulu	#720,d4
	add.l	#PLN_LAND-720-2,d4
	move.l	d4,8(a1)
	add.w	#12,d0			; screen y
	lea	vid_line_band,a2
	moveq	#0,d4
	move.b	0(a2,d0.w),d4
	mulu	#PLN_TAB,d4
	add.l	plan_ftab,d4
	move.l	d4,12(a1)
	mulu	#SCR_BPL,d0
	add.w	#28,d1			; x0
	move.w	d1,d4
	and.w	#7,d4
	move.w	d4,6(a1)		; s
	lsr.w	#3,d1			; cell -> (cell>>1)*8 + (cell&1), step 1 (even) / 7 (odd)
	moveq	#1,d4
	lsr.w	#1,d1
	bcc.s	.ev
	addq.l	#1,d0
	moveq	#7,d4
.ev:	lsl.w	#3,d1
	add.w	d1,d0
	move.w	d0,(a1)			; screen offset (< 32000)
	move.w	d4,4(a1)
	move.w	d2,2(a1)		; count
	addq.w	#1,d2
	and.w	#$fffe,d2
	add.w	d2,a0
	lea	PLR_SIZE(a1),a1
	dbf	d3,.r
	movem.l	(sp)+,d3-d4/a3-a4
	rts

plan_reset:
	tst.w	plan_inv
	bne.s	plan_invert
	rts
plan_invert:
	not.w	plan_inv
	move.l	plan_data,a0
	add.l	#PLN_LAND,a0
	move.w	#120*360-1,d0
	move.w	#255*4,d1
.i:	move.w	d1,d2			; (255 - h) * 4
	sub.w	(a0),d2
	move.w	d2,(a0)+
	dbf	d0,.i
	rts

plan_frame:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,plan_c
	add.w	d0,d0
	move.w	d0,plan_c2
	; alt offsets for this frame: altoff[index] = min(alt,29) * 1024, index 0..x
	lea	plan_altoff,a0
	move.w	plan_x,d4
	moveq	#10,d3
	moveq	#0,d2			; index
.al:	cmp.w	#170,d1
	ble.s	.lo
	move.w	d2,d0			; ecl > 170: (index - ecl + 186) div 2
	sub.w	d1,d0
	add.w	#186,d0
	bra.s	.dv
.lo:	cmp.w	d4,d2			; ecl < 171: index = x -> 10, else (ecl - index) div 2
	bne.s	.lo2
	moveq	#10,d0
	bra.s	.cl
.lo2:	move.w	d1,d0
	sub.w	d2,d0
.dv:	asr.w	#1,d0			; (negative results are clamped to 0 below, so the
.cl:	tst.w	d0			;  rounding direction of the division does not matter)
	bpl.s	.c0
	moveq	#0,d0
.c0:	cmp.w	#29,d0
	ble.s	.c1
	moveq	#29,d0
.c1:	lsl.w	d3,d0
	move.w	d0,(a0)+
	addq.w	#1,d2
	cmp.w	d4,d2
	bls.s	.al
	move.w	#10*1024,plan_j1	; j = 1 with ecl > 170: alt 10
	cmp.w	#170,d1
	bgt.s	.j1
	move.w	#-1,plan_j1		; (no special case)
.j1:	; constant runs: alt is the same for indices 1..ia/2 (value aa) and ib/2..x-1 (ab)
	lea	plan_altoff,a0
	move.w	2(a0),d0
	move.w	d0,plan_aa
	add.w	d4,d4			; 2x
	moveq	#2,d2
.ia:	addq.w	#2,d2
	cmp.w	d4,d2
	bhs.s	.iad
	cmp.w	0(a0,d2.w),d0
	beq.s	.ia
.iad:	subq.w	#2,d2
	move.w	d2,plan_ia
	move.w	d4,d2
	subq.w	#2,d2			; 2(x-1)
	move.w	0(a0,d2.w),d0
	move.w	d0,plan_ab
.ib:	subq.w	#2,d2
	beq.s	.ibd
	cmp.w	0(a0,d2.w),d0
	beq.s	.ib
.ibd:	addq.w	#2,d2
	move.w	d2,plan_ib

	move.l	plan_geo,a3
	move.w	4(a3),d5		; rows
	subq.w	#1,d5
	move.w	d5,plan_rows
	addq.l	#6,a3
	lea	plan_rowtab,a0
	move.l	a0,plan_rowp
.row:	move.l	plan_rowp,a0
	addq.l	#6,a3			; (ofsy, m, count: in the row table)
	move.w	2(a0),d6		; count = pixels left
	move.l	plan_data,a4		; land row + 2*(c - 1) (index*2 added per pixel)
	add.l	8(a0),a4
	add.w	plan_c2,a4
	move.l	12(a0),a5		; this row's band table
	move.l	gfx_target,a2
	add.w	(a0),a2
	move.w	4(a0),d3		; d3 = step (toggles 1 <-> 7)
	move.w	6(a0),d7		; s = leading skip
	lea	PLR_SIZE(a0),a0
	move.l	a0,plan_rowp
	lea	plan_altoff,a1
	tst.w	plan_j1			; first pixel lit specially (ecl > 170): patch its entry
	bmi.s	.np
	moveq	#0,d0
	move.b	(a3),d0
	move.w	0(a1,d0.w),plan_save
	move.w	d0,plan_savei
	move.w	plan_j1,0(a1,d0.w)
.np:
	moveq	#0,d0
	tst.w	d7
	bne.s	.lead
	cmp.w	#8,d6
	bhs.s	.nolead
.lead:	moveq	#8,d4			; leading partial: n = min(8 - s, count)
	sub.w	d7,d4
	cmp.w	d6,d4
	bls.s	.l1
	move.w	d6,d4
.l1:	sub.w	d4,d6
	neg.w	d7			; shift = 8 - s - n
	addq.w	#8,d7
	sub.w	d4,d7
	bsr	plan_part
	add.w	d3,a2
	eor.w	#6,d3
.nolead:
	; full cells: n = d6/8. Cells 1..n-2 may run with constant alt (the first and last
	; stay per index: they can hold the specially lit j = 1 / index = x pixels).
	; Runs: [vary: cell 0] [const A: cells 1..kA-1] [vary: kA..kB] [const B: kB+1..n-2]
	;       [vary: cell n-1]
	move.w	d6,d2
	lsr.w	#3,d2			; n
	beq	.trail
	cmp.w	#3,d2
	bhs.s	.runs
	move.w	d2,d4
	bsr	plan_vary
	bra	.trail
.runs:	move.w	d2,plan_n
	moveq	#1,d4
	bsr	plan_vary		; cell 0
	move.w	plan_n,d2
	subq.w	#2,d2			; d2 = n-2 = last candidate
	move.w	plan_ia,d1
	lea	7(a3),a0		; last index of cell 1
	moveq	#1,d7			; kA
.sa:	cmp.w	d2,d7
	bhi.s	.sad
	move.b	(a0),d0
	cmp.w	d1,d0
	bgt.s	.sad
	addq.w	#1,d7
	addq.l	#8,a0
	bra.s	.sa
.sad:	move.w	plan_ib,d1		; kB: down from n-2 while first index >= ib
	move.w	d2,d4
	lsl.w	#3,d4
	lea	-8(a3,d4.w),a0		; first index of cell n-2
.sb:	cmp.w	d7,d2
	blo.s	.sbd
	move.b	(a0),d0
	cmp.w	d1,d0
	blt.s	.sbd
	subq.w	#1,d2
	subq.l	#8,a0
	bra.s	.sb
.sbd:	move.w	d2,plan_kb
	move.w	d7,d4			; const A: kA-1 cells
	subq.w	#1,d4
	beq.s	.v2
	move.w	plan_aa,d0
	lea	0(a5,d0.w),a0
	moveq	#0,d0
	bsr	plan_const
.v2:	move.w	plan_kb,d4		; vary: kB - kA + 1
	sub.w	d7,d4
	addq.w	#1,d4
	beq.s	.cb
	bsr	plan_vary
.cb:	move.w	plan_n,d4		; const B: n-2-kB
	subq.w	#2,d4
	sub.w	plan_kb,d4
	beq.s	.v3
	move.w	plan_ab,d0
	lea	0(a5,d0.w),a0
	moveq	#0,d0
	bsr	plan_const
.v3:	moveq	#1,d4			; cell n-1
	bsr	plan_vary
.trail:	and.w	#7,d6			; trailing partial
	beq.s	.done
	move.w	d6,d4
	moveq	#8,d7
	sub.w	d4,d7
	bsr	plan_part
.done:	tst.w	plan_j1			; undo the patch
	bmi.s	.nu
	move.w	plan_savei,d4
	move.w	plan_save,0(a1,d4.w)
.nu:	move.l	a3,d0			; rows are padded to even
	addq.l	#1,d0
	and.w	#$fffe,d0
	move.l	d0,a3
	subq.w	#1,plan_rows
	bpl	.row
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; plan_vary: d4 (>0) full cells with per-index alt. d6 -= 8 per cell.
plan_vary:
	subq.w	#8,d6
	PLPIX1
	PLPIX
	PLPIX
	PLPIX
	PLPIX
	PLPIX
	PLPIX
	PLPIX
	movep.l	d5,0(a2)
	add.w	d3,a2
	eor.w	#6,d3
	subq.w	#1,d4
	bne	plan_vary
	rts

; plan_const: d4 (>0) full cells, constant alt (a0 = that alt's table row)
plan_const:
	subq.w	#8,d6
	move.b	(a3)+,d0
	move.w	0(a4,d0.w),d1
	move.l	0(a0,d1.w),d5
	PLPIXC
	PLPIXC
	PLPIXC
	PLPIXC
	PLPIXC
	PLPIXC
	PLPIXC
	movep.l	d5,0(a2)
	add.w	d3,a2
	eor.w	#6,d3
	subq.w	#1,d4
	bne	plan_const
	rts

; plan_part: d4.w = n pixels (1..8), d7.w = shift (free positions right of them);
; merges them into the cell at a2. Uses d0-d2/d5/d7 (d0 high byte stays 0).
plan_part:
	move.w	d4,d2
	subq.w	#1,d2
	PLPIX1
	bra.s	.e
.p:	PLPIX
.e:	dbf	d2,.p
	lsl.l	d7,d5
	moveq	#1,d1			; mask = ((1 << n) - 1) << shift, in all four bytes
	lsl.b	d4,d1
	subq.b	#1,d1
	lsl.b	d7,d1
	move.b	d1,d2
	lsl.w	#8,d1
	move.b	d2,d1
	move.w	d1,d2
	swap	d1
	move.w	d2,d1
	movep.l	0(a2),d2
	not.l	d1
	and.l	d1,d2
	or.l	d5,d2
	movep.l	d2,0(a2)
	rts

	section	data
fn_planet:	dc.b	"DATA",92,"PLANET.DAT",0
	even

	section	bss
plan_data:	ds.l	1
plan_ftab:	ds.l	1
plan_geo:	ds.l	1
plan_rowp:	ds.l	1
plan_x:		ds.w	1
plan_altoff:	ds.w	128
plan_c:		ds.w	1
plan_c2:	ds.w	1
plan_rowtab:	ds.b	120*PLR_SIZE
plan_j1:	ds.w	1
plan_rows:	ds.w	1
plan_save:	ds.w	1
plan_savei:	ds.w	1
plan_ia:	ds.w	1
plan_ib:	ds.w	1
plan_aa:	ds.w	1
plan_ab:	ds.w	1
plan_n:		ds.w	1
plan_kb:	ds.w	1
plan_inv:	ds.w	1
	even
