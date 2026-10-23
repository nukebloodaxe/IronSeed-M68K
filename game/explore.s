; explore.s - explore.pas for MAIN.PRG: planet exploration. The probes are launched on the
; five scans (lithosphere, hydrosphere, atmosphere, biosphere, anomalies), fly to the planet,
; wander over the land map and analyse; the zoom window under the map shows a magnified part of
; it; the data pages list what the scans found; a planet summary when everything is known;
; anomalies (cached items) can be retrieved into the cargo hold. Mode LAND (tools/mkmain.py:
; DATA\LAND.ISP/.CHK, landform.cpr; index 235 has its own slot: the main loop pulses it green).
;
; exploreplanet   explore.pas exploreplanet (from the cube's science commands)
;                 trashes: d0-d2/a0-a2
; The unit's own variables keep the original's names with an ex_ prefix. Its water/waterindex/
; batindex/index/x1.. shadow data.pas's globals in the original, so they are its own here too
; (x, y and x1 are data.pas's: GS_X, GS_Y, GS_X1).

LC_W		equ	241		; landcolors^/summarypic^: [13..133, 28..268]
LC_SIZE		equ	121*LC_W
PR_CURX		equ	0		; probetype
PR_CURY		equ	2
PR_TARX		equ	4
PR_TARY		equ	6
PR_STATUS	equ	8
PR_TIMELEFT	equ	10
PR_FUEL		equ	12
PR_TOGATHER	equ	14
PR_SIZE		equ	16
SCAN_SIZE	equ	26		; planscantype: string[24], state
MSG_SIZE	equ	8*16		; msgtype [0..7, 0..15]
ICON_SIZE	equ	26*32		; probeicontype [1..4, 1..26, 1..32]

; setcolor(c)
SETC	macro
	move.w	#\1,ms_color
	endm

; Z clear when the 1994 probes are on (options[OPT_PROBES], the options panel's first row).
; The port's own option, outside the oracle: off, every probe does what explore.pas does.
; On (David's description of the 1994 release, Oct 2026): a probe gathers only the category it
; was launched for (togather) and comes home when that category is complete (the que still
; moves on to the next open one, as explore.pas); Retrieve sends a free probe to the anomaly,
; it picks the item up, flies back and the item goes into the hold at refuelling (the fit is
; checked before the launch).
CLASSIC	macro
	tst.b	GS_SHIP+SHIP_OPTIONS+OPT_PROBES-1(a6)
	endm

	section	text
; ---------------------------------------------------------------- helpers
; a0 = landcolors^[y d1, x d0]   (trashes d1)
ex_lcaddr:
	sub.w	#13,d1
	mulu	#LC_W,d1
	lea	ex_lc,a0
	add.l	d1,a0
	add.w	d0,a0
	sub.w	#28,a0
	rts
; a0 = landform^[x d0, y d1] (flat: (x-1)*120 + y-1, any x/y)   (trashes d0)
ex_lfaddr:
	move.l	GS_LANDFORM(a6),a0
	subq.w	#1,d0
	muls	#120,d0
	add.l	d0,a0
	add.w	d1,a0
	subq.l	#1,a0
	rts
; a0 = tempplan^[curplan]
ex_plan:
	move.w	GS_CURPLAN(a6),d0
	bra	dp_plan
; screen[y d1, x d0] := d2.b, marked
ex_pset:
	bra	ms_pset
; screen[y d1, x d0] := landcolors^[y, x], marked   (trashes d0-d2/a0-a1)
ex_restore:
	movem.w	d0-d1,-(sp)
	bsr.s	ex_lcaddr
	move.b	(a0),d2
	movem.w	(sp)+,d0-d1
	bra	ms_pset
; d0 := 1 if any datagathered[j,2] < 1000 (Z clear)
ex_notall:
	lea	ex_dg+2,a0
	moveq	#5-1,d1
.l:	cmp.w	#1000,(a0)
	blt.s	.y
	addq.l	#4,a0
	dbf	d1,.l
	moveq	#0,d0
	rts
.y:	moveq	#1,d0
	rts
; probe a3 keeps scanning (Z clear): explore.pas while any category is open (ex_notall); with
; the 1994 probes while its own category (togather) is
ex_scanopen:
	CLASSIC
	beq.s	ex_notall
	move.w	PR_TOGATHER(a3),d0
	lsl.w	#2,d0
	lea	ex_dg-4+2,a0
	cmp.w	#1000,0(a0,d0.w)
	blt.s	.y
	moveq	#0,d0
	rts
.y:	moveq	#1,d0
	rts
; a0 = ex_pitem[j d7] (1994 probes: the cache index a probe is sent for, 0 = none);
; 8(a0) = ex_pcarry[j] (the item it carries home, 0 = none)
ex_pslot:
	lea	ex_pitem-2,a0
	add.w	d7,a0
	add.w	d7,a0
	rts
; rectangle(d0-d3) in the current colour
ex_rect:
	move.l	d4,-(sp)
	move.w	ms_color,d4
	bsr	ms_rect
	move.l	(sp)+,d4
	rts
; scr_fillchar(screen[y,x1..x2], c) for rows y1..y2: BAR with variable arguments d0-d3, d4
ex_bar:	bra	ms_bar

; ---------------------------------------------------------------- createano
createano:
	movem.l	d3-d7/a3,-(sp)
	tst.b	ex_doneano
	bne	.x
	cmp.w	#1000,ex_dg+4*4+2
	blt	.x
	bsr	ex_plan
	move.l	a0,a3
	cmp.b	#45,PLANET_SYSTEM(a3)
	bne.s	.n
	tst.b	PLANET_ORBIT(a3)
	bne.s	.n
	moveq	#28,d0
	bsr	chevent
	tst.w	d0
	beq.s	.n
	lea	PLANET_CACHE(a3),a0
	move.w	#ID_TEMPORAL_ANCHOR,(a0)+
	move.w	#ID_HEAVY_CORSE_GRENADE,(a0)+
	move.w	#ID_HEAVY_CORSE_GRENADE,(a0)+
	move.w	#ID_SLING_OF_DAVID,(a0)+
	move.w	#ID_SLING_OF_DAVID,(a0)+
	move.w	#ID_THYNNE_VORTEX,(a0)+
	move.w	#ID_THYNNE_VORTEX,(a0)+
	bra	.x
.n:	moveq	#0,d0			; RandSeed := seed
	move.w	PLANET_SEED(a3),d0
	bsr	mt_seed
	moveq	#1,d7			; j
.j:	lea	PLANET_CACHE-2(a3),a0
	move.w	d7,d0
	add.w	d0,d0
	tst.w	0(a0,d0.w)
	bne	.have
	moveq	#100,d0			; i := random(100)
	bsr	mt_random
	move.w	d0,d6
	moveq	#0,d5			; a
	moveq	#0,d0
	move.b	PLANET_STATE(a3),d0
	beq.s	.s0
	cmp.w	#2,d0
	bls.s	.s12
	cmp.w	#3,d0
	beq.s	.s3
	cmp.w	#4,d0
	beq.s	.s4
	cmp.w	#5,d0
	beq	.s5
	cmp.w	#6,d0
	beq	.s6
	bra	.set
.s0:	cmp.w	#25,d6			; material
	bge	.set
	moveq	#21,d0
	bsr	mt_random
	add.w	#4000,d0
	move.w	d0,d5
	bra	.set
.s12:	cmp.w	#76,d6			; element
	bge	.set
.elem:	moveq	#17,d0
	bsr	mt_random
	add.w	#500,d0
	mulu	#10,d0
	move.w	d0,d5
	bra	.set
.s3:	cmp.w	#50,d6
	ble.s	.elem
	cmp.w	#75,d6
	bgt	.set
.mat:	moveq	#2,d0			; unknown material or component
	bsr	mt_random
	addq.w	#3,d0
	mulu	#1000,d0
	move.w	d0,d5
	bra	.set
.s4:	cmp.w	#40,d6
	ble.s	.elem
	cmp.w	#70,d6
	ble.s	.mat
	cmp.w	#74,d6
	blt	.set
	cmp.w	#75,d6
	bgt	.set
.art:	move.w	#500,d0			; artifact
	bsr	mt_random
	move.w	d0,d5
	cmp.w	#400,d5
	ble.s	.a1
	add.w	#6101,d5
	bra	.set
.a1:	add.w	#6001,d5
	bra	.set
.s5:	cmp.w	#65,d6
	ble.s	.mat
	cmp.w	#73,d6
	blt	.set
	cmp.w	#75,d6
	ble.s	.art
	bra	.set
.s6:	cmp.w	#6,d6
	blt.s	.art
.set:	lea	PLANET_CACHE-2(a3),a0
	move.w	d7,d0
	add.w	d0,d0
	move.w	d5,0(a0,d0.w)
	tst.w	d5
	ble	.nj
.have:	move.w	d7,d0
	bsr	ex_place		; itemloc[j] random, marked 235 on the map
.nj:	addq.w	#1,d7
	cmp.w	#7,d7
	ble	.j
	st	ex_doneano
.x:	movem.l	(sp)+,d3-d7/a3
	rts

; itemloc[j d0] := random(60)+30, random(180)+30; landcolors^ and screen there := 235
ex_place:
	movem.l	d3/a3,-(sp)
	lea	ex_itemloc-2,a3
	add.w	d0,d0
	add.w	d0,a3
	moveq	#60,d0
	bsr	mt_random
	add.w	#30,d0
	move.b	d0,(a3)
	move.w	#180,d0
	bsr	mt_random
	add.w	#30,d0
	move.b	d0,1(a3)
	bsr	ex_mark235
	movem.l	(sp)+,d3/a3
	rts
ex_mark235:				; a3 = itemloc[j]
	moveq	#0,d0
	move.b	1(a3),d0
	add.w	#27,d0
	moveq	#0,d1
	move.b	(a3),d1
	add.w	#12,d1
	movem.w	d0-d1,-(sp)
	bsr	ex_lcaddr
	move.b	#235,(a0)
	movem.w	(sp)+,d0-d1
	move.w	#235,d2
	bra	ms_pset

; ---------------------------------------------------------------- computebiostuff
computebiostuff:
	movem.l	d3/a3,-(sp)
	moveq	#0,d0			; biostuff: landcolors^ values 48..63 over [13..132, 28..267]
	lea	ex_lc,a0
	moveq	#120-1,d2
.r:	move.l	a0,a1
	move.w	#240-1,d1
.c:	move.b	(a1)+,d3
	cmp.b	#47,d3
	bls.s	.n
	cmp.b	#64,d3
	bhs.s	.n
	addq.w	#1,d0
.n:	dbf	d1,.c
	lea	LC_W(a0),a0
	dbf	d2,.r
	move.w	d0,ex_biostuff
	move.w	#-2,ex_techlvl
	bsr	ex_plan
	move.l	a0,a3
	moveq	#0,d0
	move.b	PLANET_SYSTEM(a3),d0
	lea	.techsys,a0
.ts:	move.w	(a0)+,d1
	beq.s	.n45
	cmp.w	d1,d0
	bne.s	.ts
	tst.b	PLANET_ORBIT(a3)
	beq.s	.n45
.t6:	move.w	#6,ex_techlvl
	clr.w	ex_tl2
	bra	.x
.n45:	cmp.w	#45,d0
	bne.s	.st
	tst.b	PLANET_ORBIT(a3)
	beq.s	.m2
	moveq	#27,d0
	bsr	chevent
	tst.w	d0
	beq.s	.t6
.m2:	move.w	#-2,ex_techlvl
	bra	.x
.st:	moveq	#0,d0
	move.b	PLANET_STATE(a3),d0
	moveq	#0,d1
	move.b	PLANET_MODE(a3),d1
	move.l	PLANET_AGE(a3),d2
	cmp.w	#2,d0
	bne.s	.s3
	cmp.w	#2,d1
	bne.s	.s23
	move.w	#-1,ex_techlvl
	bra	.x
.s23:	cmp.w	#3,d1
	bne	.x
	clr.w	ex_techlvl
	move.l	#15000000,d0
	bra	.div
.s3:	cmp.w	#3,d0
	bne.s	.s4
	move.w	d1,d0
	subq.w	#1,d0
	move.w	d0,ex_techlvl
	move.l	#1500000,d0
	cmp.w	#1,d1
	beq	.div
	move.l	#1000,d0
	cmp.w	#2,d1
	beq	.div
	move.l	#800,d0
	cmp.w	#3,d1
	beq	.div
	bra	.x
.s4:	cmp.w	#4,d0
	bne.s	.s5
	move.w	d1,d0
	addq.w	#2,d0
	move.w	d0,ex_techlvl
	move.l	#400,d0
	cmp.w	#1,d1
	beq	.div
	move.l	#200,d0
	cmp.w	#2,d1
	beq	.div
	cmp.w	#3,d1
	bne	.x
	clr.w	ex_tl2
	bra	.x
.s5:	cmp.w	#5,d0
	bne.s	.s7
	cmp.w	#2,d1
	bne.s	.s51
	move.w	#-1,ex_techlvl
	bra	.x
.s51:	cmp.w	#1,d1
	bne	.x
	clr.w	ex_techlvl
	move.l	#100000000,d0
	bsr	ex_ldiv
	cmp.l	#9,d0
	ble.s	.s52
	moveq	#9,d0
.s52:	move.w	d0,ex_tl2
	bra	.x
.s7:	cmp.w	#7,d0
	bne	.x
	move.w	#-2,ex_techlvl
	clr.w	ex_biostuff
	bra	.x
.div:	bsr	ex_ldiv			; tl2 := age div d0
	move.w	d0,ex_tl2
.x:	movem.l	(sp)+,d3/a3
	rts
.techsys: dc.w	93,138,78,191,171,221,0

; d0.l := d2.l (age, >= 0) div d0.l (> 0)   (trashes d1-d2)
ex_ldiv:
	movem.l	d3-d4,-(sp)
	move.l	d0,d3			; divisor
	moveq	#0,d1			; remainder
	moveq	#32-1,d4
	moveq	#0,d0			; quotient
.b:	add.l	d2,d2
	addx.l	d1,d1
	add.l	d0,d0
	cmp.l	d3,d1
	blo.s	.n
	sub.l	d3,d1
	addq.l	#1,d0
.n:	dbf	d4,.b
	movem.l	(sp)+,d3-d4
	rts

; ---------------------------------------------------------------- generatescanlist
generatescanlist:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	mem_mark
	move.l	d0,-(sp)
	move.l	#204+4276,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,a4			; temp^ (scantype: [0..16, 0..11] bytes)
	lea	204(a4),a5		; namelist^ (171 x string[24])
	lea	u2_fn_scan,a0
	move.l	a4,a1
	move.l	#204,d0
	bsr	load_exact
	lea	ex_fn_elem,a0
	move.l	a5,a1
	move.l	#171*25,d0
	bsr	load_exact
	lea	ex_scaninfo,a0		; name := ''; state := 4
	moveq	#52-1,d0
.c:	clr.b	(a0)
	move.b	#4,25(a0)
	lea	SCAN_SIZE(a0),a0
	dbf	d0,.c
	move.w	#1,ex_index
	bsr	ex_plan
	move.l	a0,a3
	moveq	#0,d0
	move.w	PLANET_SEED(a3),d0
	bsr	mt_seed
	moveq	#0,d7			; j
	moveq	#0,d6
	move.b	PLANET_STATE(a3),d6	; state
.j:	move.w	d7,d0
	mulu	#12,d0
	lea	0(a4,d0.w),a2		; temp^[j]
	lea	ex_amounts,a0
	move.b	0(a2,d6.w),0(a0,d7.w)	; amounts[j] := temp^[j, state]
	clr.l	ex_already
	clr.l	ex_already+4
	clr.w	ex_already+8
	moveq	#0,d5
	move.b	0(a2,d6.w),d5		; count
	beq	.nj
	moveq	#1,d4			; i
.i:	moveq	#10,d0			; repeat a := random(10) until already[a] = 0
	bsr	mt_random
	lea	ex_already,a0
	tst.b	0(a0,d0.w)
	bne.s	.i
	st	0(a0,d0.w)
	move.w	ex_index,d1		; scaninfo^[index].name := namelist^[a+1+j*10]
	subq.w	#1,d1
	mulu	#SCAN_SIZE,d1
	lea	ex_scaninfo,a1
	add.w	d1,a1
	move.w	d7,d1
	mulu	#10,d1
	add.w	d0,d1
	addq.w	#1,d1
	mulu	#25,d1
	lea	0(a5,d1.l),a0
	move.l	a1,-(sp)
	moveq	#0,d0
	move.b	(a0),d0
.cp:	move.b	(a0)+,(a1)+
	dbf	d0,.cp
	move.l	(sp)+,a1
	move.w	d7,d0			; state by the planet's state
	mulu	#12,d0
	lea	0(a4,d0.w),a2
	moveq	#-1,d1
	tst.w	d6
	bne.s	.t1
	moveq	#7,d1
.t1:	cmp.w	#1,d6
	bne.s	.t2
	moveq	#8,d1
.t2:	cmp.w	#2,d6
	blt.s	.t5
	cmp.w	#4,d6
	bgt.s	.t5
	moveq	#9,d1
.t5:	cmp.w	#5,d6
	bne.s	.t6
	moveq	#10,d1
.t6:	cmp.w	#6,d6
	bne.s	.t7
	moveq	#11,d1
.t7:	tst.w	d1
	bmi.s	.ns
	move.b	0(a2,d1.w),25(a1)
.ns:	addq.w	#1,ex_index
	addq.w	#1,d4
	cmp.w	d5,d4
	ble	.i
.nj:	addq.w	#1,d7
	cmp.w	#16,d7
	ble	.j
	move.l	(sp)+,d0
	bsr	mem_release
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; ---------------------------------------------------------------- setcolors
setcolors:
	move.w	#50,ex_water
	st	ex_colorchange
	bsr	ex_plan
	moveq	#0,d0
	move.b	PLANET_STATE(a0),d0
	moveq	#0,d1
	move.b	PLANET_MODE(a0),d1
	tst.w	d0
	beq.s	.off
	cmp.w	#7,d0
	beq.s	.off
	clr.w	ex_gindex
	move.w	#144,ex_g2index
	move.w	#32,ex_waterindex
	cmp.w	#1,d0
	bne.s	.n1
	move.w	#80,ex_waterindex
	rts
.n1:	cmp.w	#2,d0
	bne.s	.n2
	move.w	#33,ex_waterindex
	rts
.n2:	cmp.w	#4,d0
	bne.s	.n4
	move.w	#40,ex_water
	rts
.n4:	cmp.w	#5,d0
	bne.s	.n5
	move.w	#30,ex_water
	cmp.w	#3,d1
	bne.s	.r
	clr.w	ex_water
.r:	rts
.n5:	cmp.w	#6,d0
	bne.s	.r
	clr.w	ex_water
	cmp.w	#2,d1
	bne.s	.r
.off:	sf	ex_colorchange
	rts

; the colour tables of showzoom (ex_zlut, per zoomscr value) and displaylandform (ex_llut, per
; landform value; -1: landcolors keeps its byte), with the original's reals (SSE doubles)
ex_tables:
	movem.l	d3-d4,-(sp)
	FSSE
	FLDI	73			; part := 73/(255-water)
	move.l	#255,d0
	sub.w	ex_water,d0
	bsr	fp_ldi
	bsr	fp_div
	lea	ex_part,a0
	bsr	fp_std
	FLDI	31			; part (displaylandform) := 31/(255-water)
	move.l	#255,d0
	sub.w	ex_water,d0
	bsr	fp_ldi
	bsr	fp_div
	lea	ex_partl,a0
	bsr	fp_std
	clr.l	ex_part2
	clr.l	ex_part2+4
	tst.w	ex_water		; part2 := 5/water (else 0)
	ble.s	.p2
	FLDI	5
	move.w	ex_water,d0
	ext.l	d0
	bsr	fp_ldi
	bsr	fp_div
	lea	ex_part2,a0
	bsr	fp_std
.p2:	moveq	#0,d3			; v
.v:	lea	ex_zlut,a0		; --- showzoom
	cmp.w	#255,d3
	bne.s	.z1
	move.w	#95,2*255(a0)
	bra	.l
.z1:	cmp.w	ex_water,d3
	bge.s	.z2
	lea	ex_part2,a0		; waterindex + round(part2*z)
	bsr	fp_ldd
	move.w	d3,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	add.w	ex_waterindex,d0
	bra.s	.zs
.z2:	move.w	d3,d0			; index := round((z-water)*part)
	sub.w	ex_water,d0
	bsr	fp_ldw
	lea	ex_part,a0
	bsr	fp_ldd
	bsr	fp_mul
	bsr	fp_rnd
	cmp.w	#42,d0
	blt.s	.z3
	cmp.w	#73,d0
	bgt.s	.z5
	add.w	ex_g2index,d0
	sub.w	#10,d0
	bra.s	.z5
.z3:	cmp.w	#11,d0
	blt.s	.z4
	add.w	ex_gindex,d0
	sub.w	#10,d0
	bra.s	.z5
.z4:	tst.w	d0
	bmi.s	.z5
	lsr.w	#1,d0
	lea	GS_SPCINDEX(a6),a0
	move.b	0(a0,d0.w),d0
	and.w	#$ff,d0
.z5:	cmp.w	#64,d0
	bne.s	.zs
	moveq	#95,d0
.zs:	and.w	#$ff,d0
	lea	ex_zlut,a0
	move.w	d3,d1
	add.w	d1,d1
	move.w	d0,0(a0,d1.w)
.l:	; --- displaylandform
	cmp.w	ex_water,d3
	bge.s	.l2
	lea	ex_part2,a0		; round(l*part2) + waterindex
	bsr	fp_ldd
	move.w	d3,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	add.w	ex_waterindex,d0
	and.w	#$ff,d0
	bra.s	.ls
.l2:	moveq	#-1,d0
	cmp.w	#246,d3
	bgt.s	.ls
	move.w	d3,d0			; index := round((l-water)*part)
	sub.w	ex_water,d0
	bsr	fp_ldw
	lea	ex_partl,a0
	bsr	fp_ldd
	bsr	fp_mul
	bsr	fp_rnd
	cmp.w	#16,d0
	blt.s	.l3
	cmp.w	#31,d0
	bgt.s	.l5
	add.w	d0,d0
	add.w	ex_g2index,d0
	bra.s	.l5
.l3:	cmp.w	#6,d0
	blt.s	.l4
	add.w	d0,d0
	add.w	ex_gindex,d0
	bra.s	.l5
.l4:	tst.w	d0
	bmi.s	.l5
	lea	GS_SPCINDEX(a6),a0
	move.b	0(a0,d0.w),d0
.l5:	and.w	#$ff,d0
.ls:	lea	ex_llut,a0
	move.w	d3,d1
	add.w	d1,d1
	move.w	d0,0(a0,d1.w)
	addq.w	#1,d3
	cmp.w	#256,d3
	bne	.v
	movem.l	(sp)+,d3-d4
	rts

; ---------------------------------------------------------------- zooms
; zoom3x(x1 d0, y1 d1)
zoom3x:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,d6
	move.w	d1,d7
	move.w	d6,d0			; rectangle(x1+28, y1+13, x1+48, y1+33)
	add.w	#28,d0
	move.w	d7,d1
	add.w	#13,d1
	move.w	d0,d2
	add.w	#20,d2
	move.w	d1,d3
	add.w	#20,d3
	bsr	ex_rect
	lea	ex_zoomscr,a5
	moveq	#0,d4			; a
.a:	moveq	#0,d5			; b
.b:	move.w	d6,d0			; a3 = landform^[x1+a, y1+b]
	add.w	d4,d0
	move.w	d7,d1
	add.w	d5,d1
	bsr	ex_lfaddr
	move.l	a0,a3
	move.w	d7,d1			; is landcolors^[y1+b+12, x1+a+27] the anomaly?
	add.w	d5,d1
	add.w	#12,d1
	move.w	d6,d0
	add.w	d4,d0
	add.w	#27,d0
	bsr	ex_lcaddr
	cmp.b	#235,(a0)
	seq	d3
	moveq	#-1,d2			; i
.i:	moveq	#-1,d1			; j
.jj:	move.w	d4,d0			; a*3+j in 1..60, b*3+i in 1..60
	mulu	#3,d0
	add.w	d1,d0
	ble.s	.nx
	cmp.w	#61,d0
	bge.s	.nx
	move.w	d5,-(sp)
	mulu	#3,d5
	add.w	d2,d5			; b*3+i
	ble.s	.nx2
	cmp.w	#61,d5
	bge.s	.nx2
	move.w	d0,-(sp)		; zoomscr^[a*3+j, b*3+i] = (a*3+j-1)*60 + b*3+i-1
	subq.w	#1,d0
	mulu	#60,d0
	add.w	d5,d0
	subq.w	#1,d0
	lea	0(a5,d0.w),a1
	move.w	(sp)+,d0
	tst.b	d3
	beq.s	.nn
	st	(a1)
	bra.s	.nx2
.nn:	move.w	d1,d0			; temp := round((landform^[x1+a+j, y1+b+i] - landform^[x1+a, y1+b]) / 3)
	muls	#120,d0
	add.w	d2,d0
	moveq	#0,d5
	move.b	0(a3,d0.w),d5
	moveq	#0,d0
	move.b	(a3),d0
	sub.w	d0,d5
	move.w	d5,d0
	bsr	ex_rnd3
	add.b	(a3),d0
	move.b	d0,(a1)
.nx2:	move.w	(sp)+,d5
.nx:	addq.w	#1,d1
	cmp.w	#1,d1
	ble.s	.jj
	addq.w	#1,d2
	cmp.w	#1,d2
	ble.s	.i
	addq.w	#1,d5
	cmp.w	#20,d5
	ble	.b
	addq.w	#1,d4
	cmp.w	#20,d4
	ble	.a
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; d0.w := round(d0.w / 3) (nearest: no ties)   (trashes d1)
ex_rnd3:
	tst.w	d0
	bmi.s	.n
	addq.w	#1,d0
	ext.l	d0
	divu	#3,d0
	rts
.n:	neg.w	d0
	addq.w	#1,d0
	ext.l	d0
	divu	#3,d0
	neg.w	d0
	rts
; d0.w := round(d0.w / 2) (banker's)   (trashes d1)
ex_rnd2:
	move.w	d0,d1
	bpl.s	.p
	neg.w	d1
.p:	asr.w	#1,d1			; |d|/2
	bcc.s	.e			; even: exact
	btst	#0,d1
	beq.s	.e			; .5 -> the even neighbour
	addq.w	#1,d1
.e:	tst.w	d0
	bpl.s	.x
	neg.w	d1
.x:	move.w	d1,d0
	rts

; zoom2x(x1 d0, y1 d1)
zoom2x:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,d6
	move.w	d1,d7
	move.w	d6,d0			; rectangle(x1+28, y1+13, x1+58, y1+43)
	add.w	#28,d0
	move.w	d7,d1
	add.w	#13,d1
	move.w	d0,d2
	add.w	#30,d2
	move.w	d1,d3
	add.w	#30,d3
	bsr	ex_rect
	lea	ex_zoomscr,a5
	moveq	#0,d4			; a
.a:	moveq	#0,d5			; b
.b:	move.w	d6,d0
	add.w	d4,d0
	move.w	d7,d1
	add.w	d5,d1
	bsr	ex_lfaddr
	move.l	a0,a3			; landform^[x1+a, y1+b]
	move.w	d4,d0			; a4 = zoomscr^[a*2+1, b*2+1] = (a*2)*60 + b*2
	mulu	#120,d0
	add.w	d5,d0
	add.w	d5,d0
	lea	0(a5,d0.w),a4
	moveq	#0,d3
	move.b	(a3),d3			; l
	tst.b	ex_colorchange
	beq.s	.flat
	move.b	d3,(a4)
	moveq	#0,d0			; [a*2+2, b*2+1]: landform^[x1+a+1, y1+b]
	move.b	120(a3),d0
	sub.w	d3,d0
	bsr	ex_rnd2
	add.b	d3,d0
	move.b	d0,60(a4)
	moveq	#0,d0			; [a*2+1, b*2+2]: landform^[x1+a, y1+b+1]
	move.b	1(a3),d0
	sub.w	d3,d0
	bsr	ex_rnd2
	add.b	d3,d0
	move.b	d0,1(a4)
	moveq	#0,d0			; [a*2+2, b*2+2]: landform^[x1+a+1, y1+b+1]
	move.b	121(a3),d0
	sub.w	d3,d0
	bsr	ex_rnd2
	add.b	d3,d0
	move.b	d0,61(a4)
	move.w	d7,d1
	add.w	d5,d1
	add.w	#12,d1
	move.w	d6,d0
	add.w	d4,d0
	add.w	#27,d0
	bsr	ex_lcaddr
	cmp.b	#235,(a0)
	bne.s	.n
	st	(a4)
	bra.s	.n
.flat:	move.b	d3,(a4)
	move.b	d3,60(a4)
	move.b	d3,1(a4)
	move.b	d3,61(a4)
.n:	addq.w	#1,d5
	cmp.w	#29,d5
	ble	.b
	addq.w	#1,d4
	cmp.w	#29,d4
	ble	.a
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; zoom1x(x1 d0, y1 d1)
zoom1x:
	movem.l	d3-d7,-(sp)
	move.w	d0,d6
	move.w	d1,d7
	move.w	d6,d0			; rectangle(x1+28, y1+13, x1+88, y1+73)
	add.w	#28,d0
	move.w	d7,d1
	add.w	#13,d1
	move.w	d0,d2
	add.w	#60,d2
	move.w	d1,d3
	add.w	#60,d3
	bsr	ex_rect
	lea	ex_zoomscr,a1		; move(landform^[x1+a, y1], zoomscr^[a, 1], 60), a = 1..60
	moveq	#1,d4
.a:	move.w	d6,d0
	add.w	d4,d0
	move.w	d7,d1
	bsr	ex_lfaddr
	moveq	#60-1,d0
.c:	move.b	(a0)+,(a1)+
	dbf	d0,.c
	addq.w	#1,d4
	cmp.w	#60,d4
	ble.s	.a
	movem.l	(sp)+,d3-d7
	rts

undozoom:
	movem.l	d3-d5,-(sp)
	moveq	#0,d3			; i
.i:	move.w	ex_zoomy,d0
	add.w	d3,d0
	cmp.w	#120,d0
	bge.s	.ni
	move.w	ex_zoomx,d0		; screen[zoomy+i+13, zoomx+j+28] := landcolors^[...] for the j with zoomx+j < 240
	move.w	ex_zoomy,d1
	add.w	d3,d1
	add.w	#13,d1
	add.w	#28,d0
	movem.w	d0-d1,-(sp)
	bsr	ex_lcaddr
	movem.w	(sp)+,d0-d1
	move.l	a0,a1
	move.w	d1,d4
	bsr	ms_addr			; (keeps d0)
	move.w	#240,d2
	sub.w	ex_zoomx,d2		; count: min(61, 240-zoomx)
	cmp.w	#61,d2
	ble.s	.k
	moveq	#61,d2
.k:	tst.w	d2
	ble.s	.ni
	move.w	d2,d5
	subq.w	#1,d2
.c:	move.b	(a1)+,(a0)+
	dbf	d2,.c
	move.w	d4,d1			; mark
	move.w	d0,d2
	add.w	d5,d2
	subq.w	#1,d2
	move.w	d3,-(sp)
	move.w	d1,d3
	bsr	ms_dirty
	move.w	(sp)+,d3
.ni:	addq.w	#1,d3
	cmp.w	#60,d3
	ble.s	.i
	movem.l	(sp)+,d3-d5
	rts

; showzoom: the zoom window (screen rows 139-198, x 206-265) from zoomscr^ through the colour
; table, with the noise messages and the anomaly signals, and its two circles
showzoom:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	ex_zoomscr,a3
	lea	ex_tempzoom,a4
	lea	ex_zlut,a5
	moveq	#0,d7			; i (row) 0..59 : tempzoom^[i,j] := f(zoomscr^[j,i])
.i:	move.l	a3,a0
	add.w	d7,a0
	moveq	#60-1,d6
	tst.b	ex_colorchange
	beq.s	.raw
.j:	moveq	#0,d0
	move.b	(a0),d0
	lea	60(a0),a0
	add.w	d0,d0
	move.b	1(a5,d0.w),(a4)+
	dbf	d6,.j
	bra.s	.ni
.raw:	move.b	(a0),(a4)+
	lea	60(a0),a0
	dbf	d6,.raw
.ni:	addq.w	#1,d7
	cmp.w	#60,d7
	bne.s	.i
	moveq	#2,d0			; if random(2) = 0: a message at [i+52, b+43]
	bsr	mt_random
	tst.w	d0
	bne.s	.m2
	moveq	#52,d0
	moveq	#43,d1
	moveq	#0,d2
	bsr	ex_zmsg
.m2:	moveq	#2,d0			; if random(2) = 0: at [i+8, b+4]
	bsr	mt_random
	tst.w	d0
	bne.s	.m3
	moveq	#8,d0
	moveq	#4,d1
	moveq	#0,d2
	bsr	ex_zmsg
.m3:	moveq	#1,d7			; anomalies near the zoom's centre
.an:	bsr	ex_plan
	move.w	d7,d0
	add.w	d0,d0
	tst.w	PLANET_CACHE-2(a0,d0.w)
	ble.s	.na
	lea	ex_itemloc-2,a0
	add.w	d0,a0
	moveq	#0,d0
	move.b	(a0),d0			; itemloc[j,1] - zoomy - c1, itemloc[j,2] - zoomx - c2
	sub.w	ex_zoomy,d0
	moveq	#0,d1
	move.b	1(a0),d1
	sub.w	ex_zoomx,d1
	cmp.w	#2,ex_zoommode
	bne.s	.z3
	sub.w	#15,d0
	sub.w	#14,d1
	bsr	ex_abs01
	cmp.w	#3,d0
	bge.s	.na
	bra.s	.z3b
.z3:	cmp.w	#3,ex_zoommode
	bne.s	.na
	sub.w	#11,d0
	sub.w	#10,d1
	bsr	ex_abs01
	cmp.w	#4,d0
	bge.s	.na
.z3b:	cmp.w	#4,d1
	bge.s	.na
	moveq	#8,d0			; the signal: msgs+32 at [i+8, b+43] and [i+52, b+4]
	moveq	#43,d1
	moveq	#32,d2
	moveq	#52,d3
	moveq	#4,d4
	bsr	ex_zmsg2
.na:	addq.w	#1,d7
	cmp.w	#7,d7
	ble	.an
	SETC	47
	bsr	mousehide
	moveq	#1,d7			; scrto_move(tempzoom^[i], screen[i+138, 206], 60)
	lea	ex_tempzoom,a3
.cp:	move.w	#206,d0
	move.w	d7,d1
	add.w	#138,d1
	bsr	ms_addr
	moveq	#60/4-1,d0
.cl:	move.b	(a3)+,(a0)+
	move.b	(a3)+,(a0)+
	move.b	(a3)+,(a0)+
	move.b	(a3)+,(a0)+
	dbf	d0,.cl
	addq.w	#1,d7
	cmp.w	#60,d7
	ble.s	.cp
	move.w	#206,d0
	move.w	#139,d1
	move.w	#265,d2
	move.w	#198,d3
	bsr	ms_dirty
	move.w	#236,d0			; circle(236, 169, 8*zoommode), (…, 4*zoommode)
	move.w	#169,d1
	move.w	ex_zoommode,d2
	lsl.w	#3,d2
	move.w	ms_color,d4
	bsr	ms_circle
	move.w	#236,d0
	move.w	#169,d1
	move.w	ex_zoommode,d2
	lsl.w	#2,d2
	move.w	ms_color,d4
	bsr	ms_circle
	bsr	mouseshow
	movem.l	(sp)+,d3-d7/a3-a5
	rts
; d0 := abs(d0), d1 := abs(d1)
ex_abs01:
	tst.w	d0
	bpl.s	.a
	neg.w	d0
.a:	tst.w	d1
	bpl.s	.b
	neg.w	d1
.b:	rts

; a := random(7)+1; msgs^[a, i, b] <> 0 -> tempzoom^[i+d0, b+d1] := it + d2
ex_zmsg:
	movem.l	d3-d5,-(sp)
	move.w	d0,d3
	move.w	d1,d4
	move.w	d2,d5
	moveq	#7,d0
	bsr	mt_random
	move.w	d0,d2
	move.w	d3,d0
	move.w	d4,d1
	bsr	ex_zput
	movem.l	(sp)+,d3-d5
	rts
; one draw a, both places: (d0, d1) and (d3, d4), + d2
ex_zmsg2:
	movem.l	d3-d6,-(sp)
	movem.w	d0-d4,ex_tmp
	moveq	#7,d0
	bsr	mt_random
	move.w	d0,d6			; a-1
	lea	ex_msgs,a1
	mulu	#MSG_SIZE,d0
	add.w	d0,a1
	moveq	#0,d5			; b (columns first, as the original; both writes per pixel)
.b:	moveq	#0,d4			; i
.i:	move.w	d4,d0
	lsl.w	#4,d0
	add.w	d5,d0
	move.b	0(a1,d0.w),d1
	beq.s	.n
	add.b	ex_tmp+5,d1		; + d2
	move.w	ex_tmp,d0		; [i+d0, b+d1]
	add.w	d4,d0
	subq.w	#1,d0
	mulu	#60,d0
	add.w	ex_tmp+2,d0
	add.w	d5,d0
	subq.w	#1,d0
	lea	ex_tempzoom,a0
	move.b	d1,0(a0,d0.w)
	move.w	ex_tmp+6,d0		; [i+d3, b+d4]
	add.w	d4,d0
	subq.w	#1,d0
	mulu	#60,d0
	add.w	ex_tmp+8,d0
	add.w	d5,d0
	subq.w	#1,d0
	move.b	d1,0(a0,d0.w)
.n:	addq.w	#1,d4
	cmp.w	#7,d4
	ble.s	.i
	addq.w	#1,d5
	cmp.w	#15,d5
	ble.s	.b
	movem.l	(sp)+,d3-d6
	rts
; msgs^[a d2 (0-based), i, b] <> 0 -> tempzoom^[i+d0, b+d1] := it (+ d5 of ex_zmsg: 0)
ex_zput:
	movem.l	d3-d5,-(sp)
	lea	ex_msgs,a1
	mulu	#MSG_SIZE,d2
	add.w	d2,a1
	move.w	d0,d3
	move.w	d1,d4
	subq.w	#1,d3			; tempzoom^[r, c] = (r-1)*60 + c-1
	mulu	#60,d3
	add.w	d4,d3
	subq.w	#1,d3
	lea	ex_tempzoom,a0
	add.w	d3,a0
	moveq	#0,d5			; i
.i:	moveq	#16-1,d0
	move.l	a0,a2
.b:	move.b	(a1)+,d1
	beq.s	.n
	move.b	d1,(a2)
.n:	addq.l	#1,a2
	dbf	d0,.b
	lea	60(a0),a0
	addq.w	#1,d5
	cmp.w	#8,d5
	bne.s	.i
	movem.l	(sp)+,d3-d5
	rts

; ---------------------------------------------------------------- sprinkles
; landsprinkle(seed d0) / summarysprinkle (ex_sum := 1, no key check, x/y are data.pas's)
landsprinkle:
	sf	ex_sum
	bra.s	ex_sprinkle
summarysprinkle:
	st	ex_sum
ex_sprinkle:				; (x, y counted on, no divisions; per row and per column tables;
	PMARK	5			; the pixels go to the shadow and the planar screen at once)
	movem.l	d3-d7/a3-a4,-(sp)
	moveq	#0,d1
	move.w	d0,d1
	divu	#240,d1
	move.w	d1,d0
	lsl.w	#4,d0
	move.w	d0,ex_sq		; (seed div 240) * 16: rows of the table
	move.w	d1,a3			; seed div 240
	swap	d1
	move.w	d1,d6			; seed mod 240
	bsr	mousehide
	lea	ex_lc,a0		; the picture: landcolors^ or summarypic^
	tst.b	ex_sum
	beq.s	.pic
	lea	ex_sumpic,a0
.pic:	move.l	a0,d0
	lea	ex_spt,a1		; rows 13..132: planar row, shadow row + 28, the line's LUT,
	moveq	#13,d1			; the picture's row
.t:	move.w	d1,d2
	mulu	#SCR_BPL,d2
	add.l	vid_phys,d2
	move.l	d2,(a1)+
	move.w	d1,d2
	mulu	#MS_W,d2
	add.l	ms_buf,d2
	add.l	#28,d2
	move.l	d2,(a1)+
	lea	vid_line_lut,a0
	move.w	d1,d2
	lsl.w	#2,d2
	move.l	0(a0,d2.w),(a1)+
	move.l	d0,(a1)+
	add.l	#LC_W,d0
	addq.w	#1,d1
	cmp.w	#133,d1
	bne.s	.t
	lea	ex_sxt,a1		; columns 28..267: the group's byte offset, the pixel's bit
	moveq	#28,d1
.u:	move.w	d1,d0
	lsr.w	#4,d0
	lsl.w	#3,d0
	move.w	d0,(a1)+
	moveq	#15,d0
	and.w	d1,d0
	move.w	#$8000,d2
	lsr.w	d0,d2
	move.w	d2,(a1)+
	addq.w	#1,d1
	cmp.w	#268,d1
	bne.s	.u
	moveq	#0,d3			; j mod 240 = x - 28
	moveq	#0,d4			; j div 240 = y - 13
	moveq	#0,d5			; index mod 50
	move.w	#28800-1,d7
	lea	ex_spt,a4		; the row's entry (a4: kept across the calls)
.l:	add.w	d6,d3			; j := j + seed; if j > 28799 then j := j - 28800
	add.w	a3,d4
	add.w	ex_sq,a4
	cmp.w	#240,d3
	blo.s	.w
	sub.w	#240,d3
	addq.w	#1,d4
	lea	16(a4),a4
.w:	cmp.w	#120,d4
	blo.s	.w2
	sub.w	#120,d4
	lea	-120*16(a4),a4
.w2:	move.l	12(a4),a0		; screen[y, x] := landcolors^[y, x] (or summarypic^)
	moveq	#0,d2
	move.b	0(a0,d3.w),d2
	move.l	4(a4),a0
	move.b	d2,0(a0,d3.w)		; the shadow
	move.l	8(a4),a1
	move.b	0(a1,d2.w),d2		; the slot of the line's band
	move.w	d3,d0
	add.w	d0,d0
	add.w	d0,d0
	lea	ex_sxt,a0
	add.w	d0,a0
	move.w	(a0)+,d0		; group offset
	move.w	(a0),d1			; bit
	move.l	(a4),a0
	add.w	d0,a0
	move.w	d1,d0
	not.w	d0
	lsr.b	#1,d2		; plane 0
	bcc.s	.c0
	or.w	d1,(a0)+
	bra.s	.n0
.c0:	and.w	d0,(a0)+
.n0:
	lsr.b	#1,d2		; plane 1
	bcc.s	.c1
	or.w	d1,(a0)+
	bra.s	.n1
.c1:	and.w	d0,(a0)+
.n1:
	lsr.b	#1,d2		; plane 2
	bcc.s	.c2
	or.w	d1,(a0)+
	bra.s	.n2
.c2:	and.w	d0,(a0)+
.n2:
	lsr.b	#1,d2		; plane 3
	bcc.s	.c3
	or.w	d1,(a0)+
	bra.s	.n3
.c3:	and.w	d0,(a0)+
.n3:
	tst.b	ex_sum		; (summarysprinkle's x, y are data.pas's)
	beq.s	.ps
	move.w	d3,d0
	add.w	#28,d0
	move.w	d0,GS_X(a6)
	move.w	d4,d0
	add.w	#13,d0
	move.w	d0,GS_Y(a6)
.ps:	tst.w	d5			; if index mod 50 = 0
	bne.s	.n
	tst.b	ex_sum
	bne.s	.d
	bsr	kbd_keypressed
	bne.s	.n
.d:	move.w	GS_TSLICE(a6),d0	; delay(tslice div 9)
	ext.l	d0
	divs	#9,d0
	bsr	delay
.n:	addq.w	#1,d5
	cmp.w	#50,d5
	bne.s	.c
	moveq	#0,d5
.c:	dbf	d7,.l
	bsr	mouseshow
	movem.l	(sp)+,d3-d7/a3-a4
	PMARK	6
	rts

displaylandform:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	ex_llut,a5
	moveq	#1,d7			; i (y)
.i:	moveq	#1,d6			; j (x)
	move.w	d6,d0
	move.w	d7,d1
	bsr	ex_lfaddr
	move.l	a0,a3			; landform^[1, i]
	move.w	#28,d0
	move.w	d7,d1
	add.w	#12,d1
	bsr	ex_lcaddr
	move.l	a0,a4			; landcolors^[i+12, 28]
	move.w	#240-1,d6
	tst.b	ex_colorchange
	beq.s	.raw
.j:	moveq	#0,d0
	move.b	(a3),d0
	lea	120(a3),a3
	add.w	d0,d0
	move.w	0(a5,d0.w),d0
	bmi.s	.k
	move.b	d0,(a4)
.k:	addq.l	#1,a4
	dbf	d6,.j
	bra.s	.ni
.raw:	move.b	(a3),(a4)+
	lea	120(a3),a3
	dbf	d6,.raw
.ni:	addq.w	#1,d7
	cmp.w	#120,d7
	ble.s	.i
	cmp.w	#1000,ex_dg+4*4+2
	blt.s	.sp
	st	ex_doneano
	moveq	#1,d7
.an:	bsr	ex_plan
	move.w	d7,d0
	add.w	d0,d0
	tst.w	PLANET_CACHE-2(a0,d0.w)
	ble.s	.na
	move.w	d7,d0
	bsr	ex_place
.na:	addq.w	#1,d7
	cmp.w	#7,d7
	ble.s	.an
.sp:	moveq	#19,d0
	bsr	landsprinkle
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; ---------------------------------------------------------------- probes
; a0 = probes[num d0]
ex_probe:
	lea	ex_probes-PR_SIZE,a0
	lsl.w	#4,d0
	add.w	d0,a0
	rts
; copy 26 rows x 32 bytes from screen (x d0, y d1 first row) to screen[row+num*40-26, 281]
; (num d2), marked
ex_tobox:
	movem.l	d3-d5,-(sp)
	move.w	d2,d5
	mulu	#40,d5
	sub.w	#25,d5			; first target row
	moveq	#26-1,d4
	move.w	d0,d3
.r:	movem.w	d1/d3,-(sp)
	move.w	d3,d0
	bsr	ms_addr
	move.l	a0,a1
	move.w	#281,d0
	move.w	d5,d1
	bsr	ms_addr
	moveq	#32-1,d0
.c:	move.b	(a1)+,(a0)+
	dbf	d0,.c
	movem.w	(sp)+,d1/d3
	addq.w	#1,d1
	addq.w	#1,d5
	dbf	d4,.r
	move.w	#281,d0
	move.w	d5,d3
	subq.w	#1,d3
	move.w	d3,d1
	sub.w	#25,d1
	move.w	#312,d2
	bsr	ms_dirty
	movem.l	(sp)+,d3-d5
	rts
; probeicons^[k d0 (1-4), i] -> screen[i+num*40-26, 281] (32 bytes, 26 rows), num d1
ex_icon:
	movem.l	d3-d4/a3,-(sp)
	lea	ex_icons-ICON_SIZE,a3
	mulu	#ICON_SIZE,d0
	add.w	d0,a3
	move.w	d1,d4
	mulu	#40,d4
	sub.w	#25,d4
	moveq	#26-1,d3
.r:	move.w	#281,d0
	move.w	d4,d1
	bsr	ms_addr
	moveq	#32-1,d0
.c:	move.b	(a3)+,(a0)+
	dbf	d0,.c
	addq.w	#1,d4
	dbf	d3,.r
	move.w	#281,d0
	move.w	d4,d3
	subq.w	#1,d3
	move.w	d3,d1
	sub.w	#25,d1
	move.w	#312,d2
	bsr	ms_dirty
	movem.l	(sp)+,d3-d4/a3
	rts
; probeicons^[k d0, b, a] <> 0 -> screen[num*40-26+b, x0+a] for b 1..26, a 1..31; num d1, x0 d2
ex_iconm:
	movem.l	d3-d5/a3,-(sp)
	lea	ex_icons-ICON_SIZE,a3
	mulu	#ICON_SIZE,d0
	add.w	d0,a3
	move.w	d2,d5
	move.w	d1,d4
	mulu	#40,d4
	sub.w	#25,d4
	moveq	#26-1,d3
.r:	move.w	d5,d0
	addq.w	#1,d0
	move.w	d4,d1
	bsr	ms_addr
	moveq	#31-1,d0
	move.l	a3,a1
.c:	move.b	(a1)+,d1
	beq.s	.n
	move.b	d1,(a0)
.n:	addq.l	#1,a0
	dbf	d0,.c
	lea	32(a3),a3
	addq.w	#1,d4
	dbf	d3,.r
	move.w	d5,d0
	addq.w	#1,d0
	move.w	d4,d3
	subq.w	#1,d3
	move.w	d3,d1
	sub.w	#25,d1
	move.w	d5,d2
	add.w	#31,d2
	bsr	ms_dirty
	movem.l	(sp)+,d3-d5/a3
	rts

; moveprobe(num d0)
moveprobe:
	movem.l	d3/a3,-(sp)
	move.w	d0,d3
	bsr	ex_probe
	move.l	a0,a3
	subq.w	#1,PR_FUEL(a3)
	move.w	PR_CURX(a3),d0		; screen[cury+12, curx+27] := landcolors^[...]
	add.w	#27,d0
	move.w	PR_CURY(a3),d1
	add.w	#12,d1
	bsr	ex_restore
	move.w	PR_CURX(a3),d0
	cmp.w	PR_TARX(a3),d0
	bge.s	.x1
	addq.w	#1,PR_CURX(a3)
	bra.s	.y
.x1:	ble.s	.y
	subq.w	#1,PR_CURX(a3)
.y:	move.w	PR_CURY(a3),d0
	cmp.w	PR_TARY(a3),d0
	bge.s	.y1
	addq.w	#1,PR_CURY(a3)
	bra.s	.t
.y1:	ble.s	.t
	subq.w	#1,PR_CURY(a3)
.t:	move.w	PR_CURX(a3),d0
	cmp.w	PR_TARX(a3),d0
	bne.s	.mv
	move.w	PR_CURY(a3),d0
	cmp.w	PR_TARY(a3),d0
	bne.s	.mv
	move.w	#4,PR_STATUS(a3)	; arrived: analyse
	moveq	#50,d0
	bsr	mt_random
	add.w	#80,d0
	move.w	d0,PR_TIMELEFT(a3)
	bra.s	.x
.mv:	moveq	#6,d0			; screen[cury+12, curx+27] := 90+random(6)
	bsr	mt_random
	move.w	d0,d2
	add.w	#90,d2
	move.w	PR_CURX(a3),d0
	add.w	#27,d0
	move.w	PR_CURY(a3),d1
	add.w	#12,d1
	bsr	ms_pset
	move.w	PR_CURX(a3),d0		; its view: screen[cury-1+i, curx+11 ..] -> the box
	add.w	#11,d0
	move.w	PR_CURY(a3),d1
	move.w	d3,d2
	bsr	ex_tobox
.x:	movem.l	(sp)+,d3/a3
	rts

; showplanet(num d0): the planet^ texture shrinking into the probe's box
ex_showplanet:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,d7			; num
	move.w	#276,d0			; clear 26 rows x 36 at [i+num*40-26, 276]
	move.w	d7,d1
	mulu	#40,d1
	sub.w	#25,d1
	move.w	#311,d2
	move.w	d1,d3
	add.w	#25,d3
	moveq	#0,d4
	bsr	ms_bar
	moveq	#30,d6			; a
.a:	move.w	d7,d5			; i := num*40-31
	mulu	#40,d5
	sub.w	#31,d5
	moveq	#0,d4			; indexi
.ri:	add.w	d6,d4
	addq.w	#1,d5
	move.w	d5,d1			; row i+a
	add.w	d6,d1
	move.w	#277,d0			; first j+a: 277+a
	add.w	d6,d0
	bsr	ms_addr
	move.l	GS_PLANET(a6),a3
	move.w	d4,d0
	subq.w	#1,d0
	mulu	#120,d0
	add.w	d0,a3			; planet^[indexi, 0]
	lea	-1(a3),a3
	moveq	#0,d3			; indexj
.rj:	add.w	d6,d3
	cmp.w	#121,d4
	bge.s	.nj
	cmp.w	#121,d3
	bge.s	.nj
	move.b	0(a3,d3.w),(a0)
.nj:	addq.l	#1,a0
	cmp.w	#119,d3
	ble.s	.rj
	movem.l	d3-d4,-(sp)		; mark the row: x 277+a .. 276+a+count
	move.w	d5,d1
	add.w	d6,d1
	move.w	d1,d3
	move.w	#277,d0
	add.w	d6,d0
	move.l	a0,d2
	move.w	d0,d4
	bsr	ms_addr
	sub.l	a0,d2
	add.w	d4,d2
	subq.w	#1,d2
	move.w	d4,d0
	move.w	d3,d1
	cmp.w	#319,d2
	ble.s	.mw
	move.w	#319,d2
.mw:	bsr	ms_dirty
	movem.l	(sp)+,d3-d4
	cmp.w	#119,d4
	ble.s	.ri
	move.w	GS_TSLICE(a6),d0	; delay(tslice)
	bsr	delay
	subq.w	#1,d6
	cmp.w	#4,d6
	bge	.a
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; ---------------------------------------------------------------- text
; explore.pas printxy2(x1 d0, y1 d1, a0 = string): flat glyphs in tcolor on bkcolor (< 255),
; and the column after each letter in bkcolor whatever it is
printxy2x:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	a0,a5
	move.w	d0,d6			; x1
	addq.w	#4,d6
	move.w	d1,d7			; y1
	moveq	#0,d5
	move.b	(a5)+,d5		; length
	beq	.x
	move.w	d6,d0			; mark the whole string
	move.w	d7,d1
	move.w	d5,d2
	mulu	#5,d2
	add.w	d6,d2
	cmp.w	#319,d2
	ble.s	.mw
	move.w	#319,d2
.mw:	move.w	d7,d3
	addq.w	#6,d3
	bsr	ms_dirty
	moveq	#0,d0			; the font: ship.options[OPT_FONT]
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_FONT-1(a6),d0
	mulu	#82*3,d0
	lea	txt_font,a4
	add.w	d0,a4
	subq.w	#1,d5
.ch:	moveq	#0,d0
	move.b	(a5)+,d0
	bsr	ex_letter		; d0 = letter (1-based)
	subq.w	#1,d0
	mulu	#3,d0
	lea	0(a4,d0.w),a3		; its 3 bytes
	move.w	d6,d0
	addq.w	#1,d0
	move.w	d7,d1
	addq.w	#1,d1
	bsr	ms_addr			; screen[y1+1, x1+1]
	moveq	#3-1,d4
.gb:	move.b	(a3)+,d3
	moveq	#2-1,d2			; two rows: high nibble, low nibble
.gr:	moveq	#4-1,d1
.gp:	add.b	d3,d3
	bcc.s	.bk
	move.b	GS_TCOLOR+1(a6),(a0)+
	bra.s	.gn
.bk:	cmp.w	#255,GS_BKCOLOR(a6)
	bge.s	.sk
	move.b	GS_BKCOLOR+1(a6),(a0)
.sk:	addq.l	#1,a0
.gn:	dbf	d1,.gp
	lea	MS_W-4(a0),a0
	dbf	d2,.gr
	dbf	d4,.gb
	addq.w	#5,d6			; x1 := x1+5; screen[y1+i, x1] := bkcolor, i = 1..6
	move.w	d6,d0
	move.w	d7,d1
	addq.w	#1,d1
	bsr	ms_addr
	move.b	GS_BKCOLOR+1(a6),d0
	moveq	#6-1,d1
.bc:	move.b	d0,(a0)
	lea	MS_W(a0),a0
	dbf	d1,.bc
	dbf	d5,.ch
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts
; data.pas's letter mapping: d0 = character -> letter number
ex_letter:
	cmp.b	#'a',d0
	blo.s	.u
	cmp.b	#'z',d0
	bhi.s	.o
	sub.w	#40,d0
	rts
.u:	cmp.b	#' ',d0
	blo.s	.o
	cmp.b	#'"',d0
	bhi.s	.q
	sub.w	#31,d0
	rts
.q:	cmp.b	#39,d0
	blo.s	.p
	cmp.b	#'?',d0
	bhi.s	.A
	sub.w	#35,d0
	rts
.A:	cmp.b	#'A',d0
	blo.s	.o
	cmp.b	#'Z',d0
	bhi.s	.o
	sub.w	#36,d0
	rts
.p:	cmp.b	#'%',d0
	bne.s	.o
	moveq	#55,d0
	rts
.o:	moveq	#1,d0
	rts

; ---------------------------------------------------------------- the summary
; pieslice(63, 114, phi0 d0, phi1 d1, 20) in fill colour d2 (c_utils.c: the pixels whose angle
; is in [phi0, phi1) degrees, tests/tables in build/dptab.i ct_pie20)
ex_pieslice:
	movem.l	d3-d7/a3,-(sp)
	move.w	d0,d6
	move.w	d1,d7
	move.b	d2,ex_tmp
	move.w	#43,d0			; dirty: 43..82, 96..132
	moveq	#96,d1
	moveq	#82,d2
	move.w	#132,d3
	bsr	ms_dirty
	lea	ct_pie20,a3
	moveq	#-20,d5			; j
.j:	lea	ct_pie+100,a0		; row y - (int)(j*0.9)
	move.b	0(a0,d5.w),d1
	ext.w	d1
	neg.w	d1
	add.w	#114,d1
	moveq	#43,d0			; x+i, i from -20
	bsr	ms_addr
	moveq	#40-1,d4
.i:	move.w	(a3)+,d0
	bmi.s	.n
	cmp.w	d6,d0			; phi0 < A <= phi1
	ble.s	.n
	cmp.w	d7,d0
	bgt.s	.n
	move.b	ex_tmp,(a0)
.n:	addq.l	#1,a0
	dbf	d4,.i
	addq.w	#1,d5
	cmp.w	#20,d5
	blt.s	.j
	movem.l	(sp)+,d3-d7/a3
	rts

; str(x1:5:2) of the double at a0 into ex_str (FSSE value)
ex_str52:
	bsr	fp_ldd
	moveq	#5,d0
	moveq	#2,d1
	lea	ex_str,a0
	bra	fp_str

; printhighest: the four most common compounds and 'Other', and their pie
printhighest:
	movem.l	d3-d7/a3,-(sp)
	clr.w	GS_Y(a6)		; y := 0
	lea	GS_CARGO(a6),a0		; cargindex: the first element
	moveq	#1,d7
.ci:	cmp.w	#ID_FIRST_ELEMENT,CARGO_INDEX(a0)
	bge.s	.cf
	lea	CARGO_SIZEOF(a0),a0
	addq.w	#1,d7
	bra.s	.ci
.cf:	move.w	d7,ex_cargindex
	lea	ex_amounts,a0		; amounts2 := amounts; total
	lea	ex_amounts2,a1
	moveq	#0,d6
	moveq	#17-1,d0
.t:	moveq	#0,d1
	move.b	(a0)+,d1
	move.b	d1,(a1)+
	add.w	d1,d6
	dbf	d0,.t
	move.w	d6,ex_total
	clr.l	ex_angle
	clr.l	ex_angle+4
	moveq	#80,d2			; pieslice(63, 114, 0, 360, 20) in 80
	moveq	#0,d0
	move.w	#360,d1
	bsr	ex_pieslice
.rep:	lea	ex_amounts2,a0		; max, index
	moveq	#0,d5
	move.b	(a0),d5
	clr.w	ex_index
	moveq	#0,d0
.m:	moveq	#0,d1
	move.b	0(a0,d0.w),d1
	cmp.w	d5,d1
	ble.s	.mn
	move.w	d1,d5
	move.w	d0,ex_index
.mn:	addq.w	#1,d0
	cmp.w	#17,d0
	bne.s	.m
	tst.w	d5
	ble	.nm
	FSSE				; x1 := max/total*100
	move.w	d5,d0
	bsr	fp_ldw
	move.w	ex_total,d0
	bsr	fp_ldw
	bsr	fp_div
	FLDI	100
	bsr	fp_mul
	FSTG	GS_X1
	lea	GS_X1(a6),a0		; str(x1:5:2, str1)
	bsr	ex_str52
	move.w	GS_Y(a6),d0		; tcolor := 95 - y*3
	mulu	#3,d0
	neg.w	d0
	add.w	#95,d0
	move.w	d0,GS_TCOLOR(a6)
	lea	ex_str,a0		; str1 + '% ' + cargo[cargindex+index].name
	lea	ex_t_pct,a1
	bsr	pstr_cat
	move.w	ex_cargindex,d0
	add.w	ex_index,d0
	subq.w	#1,d0
	mulu	#CARGO_SIZEOF,d0
	lea	GS_CARGO+CARGO_NAME(a6),a1
	add.w	d0,a1
	lea	ex_str,a0
	bsr	pstr_cat
	move.w	GS_Y(a6),d1
	mulu	#6,d1
	add.w	#101,d1
	move.w	#120,d0
	lea	ex_str,a0
	bsr	printxy2x
	FX87				; round(x1*3.6 + angle + 5)
	bsr	ex_x1angle
	FLDI	5
	bsr	fp_add
	bsr	fp_rnd
	move.w	d0,d4
	FSSE
	lea	ex_angle,a0		; round(angle)
	bsr	fp_ldd
	bsr	fp_rnd
	move.w	d4,d1
	cmp.w	#360,d4
	ble.s	.p
	move.w	#360,d1
.p:	move.w	GS_TCOLOR(a6),d2
	bsr	ex_pieslice
	FX87				; angle := x1*3.6 + angle
	bsr	ex_x1angle
	lea	ex_angle,a0
	bsr	fp_std
	FSSE
	lea	ex_amounts2,a0
	add.w	ex_index,a0
	clr.b	(a0)
.nm:	addq.w	#1,GS_Y(a6)
	cmp.w	#4,GS_Y(a6)
	bne	.rep
	move.w	#80,GS_TCOLOR(a6)	; the rest: 'Other'
	lea	ex_amounts2,a0
	moveq	#0,d5
	moveq	#17-1,d0
.o:	moveq	#0,d1
	move.b	(a0)+,d1
	add.w	d1,d5
	dbf	d0,.o
	tst.w	d5
	ble.s	.x
	FSSE				; x1 := max/total; str((x1*100):5:2)
	move.w	d5,d0
	bsr	fp_ldw
	move.w	ex_total,d0
	bsr	fp_ldw
	bsr	fp_div
	FSTG	GS_X1
	FLDG	GS_X1
	FLDI	100
	bsr	fp_mul
	moveq	#5,d0
	moveq	#2,d1
	lea	ex_str,a0
	bsr	fp_str
	lea	ex_str,a0
	lea	ex_t_other,a1
	bsr	pstr_cat
	move.w	#120,d0
	moveq	#125,d1
	lea	ex_str,a0
	bsr	printxy2x
.x:	move.w	#31,GS_TCOLOR(a6)
	movem.l	(sp)+,d3-d7/a3
	rts
ex_x1angle:				; push x1*3.6 + angle (x87)
	FLDG	GS_X1
	FLDX	gx_3_6
	bsr	fp_mul
	lea	ex_angle,a0
	bsr	fp_ldd
	bra	fp_add

; printslice(angle1, angle2: doubles at ex_a1/ex_a2, row d0, val: double at ex_val, a0 = name)
printslice:
	movem.l	d3-d4/a3,-(sp)
	move.w	d0,d3
	move.l	a0,a3
	FSSE
	lea	ex_val,a0		; str(val:5:2, str1)
	bsr	ex_str52
	move.w	d3,d0			; tcolor := 95 - row*3
	mulu	#3,d0
	neg.w	d0
	add.w	#95,d0
	move.w	d0,GS_TCOLOR(a6)
	lea	ex_str,a0
	lea	ex_t_pct,a1
	bsr	pstr_cat
	lea	ex_str,a0
	move.l	a3,a1
	bsr	pstr_cat
	move.w	d3,d1
	mulu	#6,d1
	add.w	#101,d1
	move.w	#120,d0
	lea	ex_str,a0
	bsr	printxy2x
	lea	ex_a2,a0		; round(angle2 + 5)
	bsr	fp_ldd
	FLDI	5
	bsr	fp_add
	bsr	fp_rnd
	move.w	d0,d4
	lea	ex_a1,a0
	bsr	fp_ldd
	bsr	fp_rnd
	move.w	d4,d1
	cmp.w	#360,d4
	ble.s	.p
	move.w	#360,d1
.p:	move.w	GS_TCOLOR(a6),d2
	bsr	ex_pieslice
	movem.l	(sp)+,d3-d4/a3
	rts

printhigheststar:
	movem.l	d3-d5,-(sp)
	move.w	#200,d0			; other := random(200)+1; helium := random(500)+2300
	bsr	mt_random
	addq.w	#1,d0
	move.w	d0,d5
	move.w	#500,d0
	bsr	mt_random
	add.w	#2300,d0
	move.w	d0,d4
	move.w	#10000,d3		; hydrogen
	sub.w	d5,d3
	sub.w	d4,d3
	moveq	#80,d2			; pieslice(63, 114, 0, 360, 20) in 80
	moveq	#0,d0
	move.w	#360,d1
	bsr	ex_pieslice
	clr.l	ex_a1			; printslice(0, hydrogen*0.036, 0, hydrogen/100, 'Hydrogen')
	clr.l	ex_a1+4
	move.w	d3,d0
	bsr	ex_s036
	lea	ex_a2,a0
	bsr	fp_std
	move.w	d3,d0
	bsr	ex_s100
	moveq	#0,d0
	lea	ex_t_hyd,a0
	bsr	printslice
	move.w	d3,d0			; printslice(hydrogen*0.036, (hydrogen+helium)*0.036, 1, helium/100, 'Helium')
	bsr	ex_s036
	lea	ex_a1,a0
	bsr	fp_std
	move.w	d3,d0
	add.w	d4,d0
	bsr	ex_s036
	lea	ex_a2,a0
	bsr	fp_std
	move.w	d4,d0
	bsr	ex_s100
	moveq	#1,d0
	lea	ex_t_hel,a0
	bsr	printslice
	move.w	d3,d0			; printslice((hydrogen+helium)*0.036, 360, 2, other/100, 'Other')
	add.w	d4,d0
	bsr	ex_s036
	lea	ex_a1,a0
	bsr	fp_std
	FSSE
	FLDI	360
	lea	ex_a2,a0
	bsr	fp_std
	move.w	d5,d0
	bsr	ex_s100
	moveq	#2,d0
	lea	ex_t_oth,a0
	bsr	printslice
	move.w	#31,GS_TCOLOR(a6)
	movem.l	(sp)+,d3-d5
	rts
ex_s036:				; push word d0 * 0.036 (x87)
	FX87
	and.l	#$ffff,d0
	bsr	fp_ldi
	FLDX	gx_0_036
	bra	fp_mul
ex_s100:				; val := word d0 / 100 (SSE)
	FSSE
	and.l	#$ffff,d0
	bsr	fp_ldi
	FLDI	100
	bsr	fp_div
	lea	ex_val,a0
	bra	fp_std

; summaryinfo
summaryinfo:
	movem.l	d3-d7/a3-a5,-(sp)
	tst.b	ex_donescan
	beq.s	.go
	move.w	#109,d0
	bsr	summarysprinkle
	st	ex_showscan
	bra	.x
.go:	bsr	mousehide
	BAR	28,13,267,133,0
	BAR	6,147,130,196,0
	bsr	ex_plan
	move.l	a0,a3
	moveq	#0,d0
	move.w	PLANET_SEED(a3),d0	; randseed := seed
	bsr	mt_seed
	TCOL	207
	cmp.b	#7,PLANET_STATE(a3)
	beq.s	.st1
	PXY	113,14,"Planet Summary"
	bra.s	.st2
.st1:	PXY	118,14,"Star Summary"
.st2:	TCOL	192
	PXY	50,21,"Seismic Activity"
	PXY	40,27,"Atmospheric Activity"
	PXY	40,33,"Atmospheric Pressure"
	PXY	50,39,"Relative Gravity"
	PXY	55,45,"Per Cent Hydro"
	PXY	60,51,"Per Cent Bio"
	PXY	65,57,"Life Forms"
	PXY	65,63,"Population"
	PXY	49,69,"Technology Level"
	PXY	62,75,"Temperature"
	PXY	52,81,"Surface Radiation"
	cmp.b	#7,PLANET_STATE(a3)
	beq.s	.st3
	PXY	60,87,"Planet State"
	bra.s	.st4
.st3:	PXY	45,87,"Star Classification"
.st4:	TCOL	207
	PXY	95,94,"Most Common Compounds"
	TCOL	31
	cmp.b	#7,PLANET_STATE(a3)
	beq.s	.st5
	bsr	printhighest
	bra.s	.st6
.st5:	bsr	printhigheststar
.st6:	bsr	ex_plan			; (printhighest's calls keep a3? reload)
	move.l	a0,a3
	moveq	#0,d0			; seismic activity
	move.b	PLANET_STATE(a3),d0
	lea	ex_t_none,a4
	tst.w	d0
	beq.s	.sa
	cmp.w	#1,d0
	beq.s	.sa1
	cmp.w	#7,d0
	beq.s	.sa1
	cmp.w	#3,d0
	bls.s	.sa2
	cmp.w	#4,d0
	beq.s	.sa4
	cmp.w	#6,d0
	bls.s	.sa5
	bra.s	.sa
.sa1:	lea	ex_t_heavy,a4
	lea	ex_t_massive,a5
	bra.s	.sar
.sa2:	lea	ex_t_mild,a4
	lea	ex_t_moderate,a5
	bra.s	.sar
.sa4:	lea	ex_t_calm,a4
	lea	ex_t_mild,a5
	bra.s	.sar
.sa5:	lea	ex_t_none,a4
	lea	ex_t_calm,a5
.sar:	moveq	#2,d0
	bsr	mt_random
	tst.w	d0
	beq.s	.sa
	move.l	a5,a4
.sa:	move.l	a4,a0			; printxy(240-length*5, 21, str1)
	moveq	#21,d1
	bsr	ex_pright240
	moveq	#0,d0			; x1 := abs(orbit-7)*(psize+1) + water; j := (round(x1) mod 5)+1
	move.b	PLANET_ORBIT(a3),d0
	subq.w	#7,d0
	bpl.s	.ab
	neg.w	d0
.ab:	moveq	#0,d1
	move.b	PLANET_PSIZE(a3),d1
	addq.w	#1,d1
	mulu	d1,d0
	moveq	#0,d1
	move.b	PLANET_WATER(a3),d1
	add.w	d1,d0
	move.l	d0,d3
	bsr	fp_ldi
	FSTG	GS_X1
	move.l	d3,d0
	divu	#5,d0			; (an integer: round(x1) = itself)
	swap	d0
	mulu	#9,d0
	lea	ex_activity,a0
	add.w	d0,a0
	move.w	#200,d0
	moveq	#27,d1
	bsr	printxy
	FSSE				; grav := (psize+1)*((random(30)+1)/15)
	moveq	#30,d0
	bsr	mt_random
	addq.w	#1,d0
	bsr	fp_ldw
	FLDI	15
	bsr	fp_div
	moveq	#0,d0
	move.b	PLANET_PSIZE(a3),d0
	addq.w	#1,d0
	bsr	fp_ldw
	bsr	fp_mul
	lea	ex_grav,a0
	bsr	fp_std
	moveq	#0,d0			; i by state
	move.b	PLANET_STATE(a3),d0
	move.b	.atab(pc,d0.w),d3
	ext.w	d3
	cmp.w	#7,d0
	bne.s	.ng
	moveq	#10,d0			; star: grav := grav*10 + random(10)
	bsr	mt_random
	bsr	fp_ldw
	lea	ex_grav,a0
	bsr	fp_ldd
	FLDI	10
	bsr	fp_mul
	bsr	fp_add
	lea	ex_grav,a0
	bsr	fp_std
	bra.s	.ng
.atab:	dc.b	17,12,3,4,3,3,2,10
.ng:	move.w	d3,d0			; atm := grav*(i/(psize+1))
	bsr	fp_ldw
	moveq	#0,d0
	move.b	PLANET_PSIZE(a3),d0
	addq.w	#1,d0
	bsr	fp_ldw
	bsr	fp_div
	lea	ex_grav,a0
	bsr	fp_ldd
	bsr	fp_mul
	lea	ex_atm,a0
	bsr	fp_std
	lea	ex_atm,a0		; str(atm:5:2) + ' Atm'
	bsr	ex_str52
	lea	ex_str,a0
	lea	ex_t_atm,a1
	bsr	pstr_cat
	move.w	#195,d0
	moveq	#33,d1
	lea	ex_str,a0
	bsr	printxy
	lea	ex_grav,a0		; str(grav:5:2) + ' G'
	bsr	ex_str52
	lea	ex_str,a0
	lea	ex_t_g,a1
	bsr	pstr_cat
	move.w	#205,d0
	moveq	#39,d1
	lea	ex_str,a0
	bsr	printxy
	moveq	#0,d3			; x: hydro count (16-bit, wraps as the original's integer)
	lea	ex_lc,a0
	moveq	#120-1,d2
.hr:	move.l	a0,a1
	move.w	#240-1,d1
.hc:	move.b	(a1)+,d0
	cmp.b	#31,d0
	bls.s	.hn
	cmp.b	#48,d0
	bhs.s	.h2
	addq.w	#2,d3
	bra.s	.hn
.h2:	cmp.b	#63,d0
	bhs.s	.hn
	addq.w	#1,d3
.hn:	dbf	d1,.hc
	lea	LC_W(a0),a0
	dbf	d2,.hr
	move.w	d3,GS_X(a6)
	move.w	d3,d0			; str((x/58322*100):5:2) + '%'
	bsr	fp_ldw
	move.l	#58322,d0
	bsr	fp_ldi
	bsr	fp_div
	FLDI	100
	bsr	fp_mul
	moveq	#5,d0
	moveq	#2,d1
	lea	ex_str,a0
	bsr	fp_str
	lea	ex_str,a0
	lea	ex_t_pc,a1
	bsr	pstr_cat
	move.w	#210,d0
	moveq	#45,d1
	lea	ex_str,a0
	bsr	printxy
	moveq	#0,d0			; x1 := (abs(orbit-7)*atm + (50-water) mod 7)/2
	move.b	PLANET_ORBIT(a3),d0
	subq.w	#7,d0
	bpl.s	.ab2
	neg.w	d0
.ab2:	bsr	fp_ldw
	lea	ex_atm,a0
	bsr	fp_ldd
	bsr	fp_mul
	moveq	#50,d0
	moveq	#0,d1
	move.b	PLANET_WATER(a3),d1
	sub.w	d1,d0
	ext.l	d0
	divs	#7,d0
	swap	d0			; the remainder (sign of the dividend)
	bsr	fp_ldw
	bsr	fp_add
	FLDI	2
	bsr	fp_div
	FSTG	GS_X1
	FLDG	GS_X1			; if x1 < 0 then x1 := 0
	bsr	fp_tst
	bpl.s	.t0
	clr.l	GS_X1(a6)
	clr.l	GS_X1+4(a6)
.t0:	FLDG	GS_X1			; case round(x1)
	bsr	fp_rnd
	lea	ex_t_infernal,a0
	tst.l	d0
	bmi.s	.tp
	cmp.l	#7,d0
	bgt.s	.tp
	lea	ex_temps,a0
	mulu	#10,d0
	add.w	d0,a0
.tp:	moveq	#75,d1
	bsr	ex_pright240
	moveq	#0,d0			; x1 := abs(orbit-7)/atm*5; str(x1:7:2) + ' RAD/Yr'
	move.b	PLANET_ORBIT(a3),d0
	subq.w	#7,d0
	bpl.s	.ab3
	neg.w	d0
.ab3:	bsr	fp_ldw
	lea	ex_atm,a0
	bsr	fp_ldd
	bsr	fp_div
	FLDI	5
	bsr	fp_mul
	FSTG	GS_X1
	FLDG	GS_X1
	moveq	#7,d0
	moveq	#2,d1
	lea	ex_str,a0
	bsr	fp_str
	lea	ex_str,a0
	lea	ex_t_rad,a1
	bsr	pstr_cat
	move.w	#170,d0
	moveq	#81,d1
	lea	ex_str,a0
	bsr	printxy
	moveq	#0,d0			; planet state
	move.b	PLANET_STATE(a3),d0
	cmp.w	#7,d0
	beq.s	.ps7
	cmp.w	#6,d0
	bhi.s	.psd
	add.w	d0,d0
	move.w	.psx(pc,d0.w),d1
	move.w	d1,d0
	lsr.w	#8,d0			; (x in the high byte, string index in the low byte)
	and.w	#$ff,d1
	mulu	#14,d1
	lea	ex_states,a0
	add.w	d1,a0
	moveq	#87,d1
	bsr	printxy
	bra.s	.psd
.psx:	dc.w	205<<8+0,210<<8+1,210<<8+2,190<<8+3,175<<8+4,215<<8+5,220<<8+6
.ps7:	moveq	#0,d0
	move.b	PLANET_MODE(a3),d0
	subq.w	#1,d0
	cmp.w	#2,d0
	bhi.s	.psd
	add.w	d0,d0
	move.w	.ssx(pc,d0.w),d1
	move.w	d1,d0
	lsr.w	#8,d0
	and.w	#$ff,d1
	mulu	#14,d1
	lea	ex_stars,a0
	add.w	d1,a0
	moveq	#87,d1
	bsr	printxy
	bra.s	.psd
.ssx:	dc.w	200<<8+0,185<<8+1,190<<8+2
.psd:	FSSE				; str((biostuff/29161*100):5:2) + '%'
	bsr	ex_biopct
	move.w	#210,d0
	moveq	#51,d1
	lea	ex_str,a0
	bsr	printxy
	cmp.b	#6,PLANET_STATE(a3)
	bne.s	.lf
	cmp.b	#2,PLANET_MODE(a3)
	bne.s	.lf
	PXY	169,57,"Void Dwellers"
	PXY	205,63,"Unknown"
	PXY	225,69,"6.0"
	bra	.lfx
.lf:	move.w	ex_techlvl,d0
	cmp.w	#-2,d0
	bne.s	.lf1
	PXY	205,57,"No Life"
	PXY	220,63,"None"
	PXY	220,69,"None"
	bra	.lfx
.lf1:	cmp.w	#-1,d0
	bne	.lf2
	moveq	#0,d0			; randseed := seed; j := random(word(state+mode+seed)) mod 3
	move.w	PLANET_SEED(a3),d0
	bsr	mt_seed
	bsr	ex_lifej
	tst.w	d0
	bne.s	.j1
	moveq	#2,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.j0b
	PXY	140,57,"Short Chain Proteins"
	bra	.j9
.j0b:	PXY	145,57,"Long Chain Proteins"
	bra	.j9
.j1:	cmp.w	#1,d0
	bne.s	.j2
	moveq	#2,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.j1b
	PXY	150,57,"Simple Protoplasms"
	bra.s	.j9
.j1b:	PXY	145,57,"Complex Protoplasms"
	bra.s	.j9
.j2:	moveq	#3,d0			; 'Singlecelled ' + Chaosms / Communes / Hierarchies
	bsr	mt_random
	mulu	#12,d0
	lea	ex_cells,a1
	add.w	d0,a1
	lea	ex_str,a0
	bsr	pstr_cpy
	moveq	#0,d3
	move.b	ex_str,d3
	lea	ex_str2,a0
	lea	ex_t_single,a1
	bsr	pstr_cpy
	lea	ex_str2,a0
	lea	ex_str,a1
	bsr	pstr_cat
	mulu	#5,d3
	move.w	#175,d0
	sub.w	d3,d0
	moveq	#57,d1
	lea	ex_str2,a0
	bsr	printxy
.j9:	PXY	180,63,"Uncomputable"
	PXY	165,69,"No Intelligence"
	bra	.lfx
.lf2:	tst.w	d0
	bmi	.lfx
	cmp.w	#5,d0
	bgt	.lfx
	bsr	ex_population		; pop (randseed := seed first)
	move.l	ex_pop,d0		; str(pop, str1)
	moveq	#0,d1
	lea	ex_str,a0
	bsr	int_str
	moveq	#0,d3
	move.b	ex_str,d3		; length
	cmp.w	#3,d3
	bgt.s	.pp4
	lea	ex_str,a0		; str1+'000' at 225-length*5
	lea	ex_t_000,a1
	bsr	pstr_cat
	move.w	#225,d4
	bra.s	.ppo
.pp4:	cmp.w	#6,d3
	bgt.s	.pp7
	subq.b	#3,ex_str
	lea	ex_t_million,a1
	move.w	#200,d4
	bra.s	.ppc
.pp7:	cmp.w	#9,d3
	bgt.s	.pp10
	subq.b	#6,ex_str
	lea	ex_t_billion,a1
	move.w	#200,d4
	bra.s	.ppc
.pp10:	cmp.w	#12,d3
	bgt.s	.ppn
	subq.b	#8,ex_str
	subq.b	#1,ex_str
	lea	ex_t_trillion,a1
	move.w	#195,d4
.ppc:	moveq	#0,d3
	move.b	ex_str,d3
	lea	ex_str,a0
	bsr	pstr_cat
.ppo:	mulu	#5,d3
	sub.w	d3,d4
	move.w	d4,d0
	moveq	#63,d1
	lea	ex_str,a0
	bsr	printxy
.ppn:	moveq	#0,d0			; randseed := seed; str1 := alientypes[random(11)]
	move.w	PLANET_SEED(a3),d0
	bsr	mt_seed
	moveq	#11,d0
	bsr	mt_random
	mulu	#13,d0
	lea	alientypes,a1
	add.w	d0,a1
	lea	ex_str,a0
	bsr	pstr_cpy
	moveq	#5,d0			; case random(5): diet + ' ' + type
	bsr	mt_random
	move.w	d0,d3
	add.w	d0,d0
	move.w	.dx(pc,d0.w),d4
	moveq	#0,d0
	move.b	ex_str,d0
	mulu	#5,d0
	sub.w	d0,d4
	mulu	#16,d3
	lea	ex_diets,a1
	add.w	d3,a1
	lea	ex_str2,a0
	bsr	pstr_cpy
	lea	ex_str2,a0
	lea	ex_str,a1
	bsr	pstr_cat
	move.w	d4,d0
	moveq	#57,d1
	lea	ex_str2,a0
	bsr	printxy
	bsr	ex_techstr		; techlvl.tl2
	move.w	#225,d0
	moveq	#69,d1
	lea	ex_str,a0
	bsr	printxy
	bra.s	.lfx
.dx:	dc.w	180,180,185,170,165
.lfx:	moveq	#13,d3			; summarypic^ := the map area's rows 13-132
.sp:	move.w	#28,d0
	move.w	d3,d1
	bsr	ms_addr
	move.l	a0,a1
	move.w	#28,d0
	move.w	d3,d1
	bsr	ex_lcaddr
	lea	ex_sumpic-ex_lc(a0),a0
	move.w	#240-1,d0
.spc:	move.b	(a1)+,(a0)+
	dbf	d0,.spc
	addq.w	#1,d3
	cmp.w	#132,d3
	ble.s	.sp
	bsr	mouseshow
	st	ex_donescan
	st	ex_showscan
	bsr	ex_plan
	or.b	#1,PLANET_NOTES(a0)
	SETC	47
	TCOL	207
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; printxy(240 - length(a0^)*5, d1, a0)
ex_pright240:
	moveq	#0,d0
	move.b	(a0),d0
	mulu	#5,d0
	neg.w	d0
	add.w	#240,d0
	bra	printxy

; str((biostuff/29161*100):5:2) + '%' -> ex_str
ex_biopct:
	FSSE
	move.w	ex_biostuff,d0
	bsr	fp_ldw
	move.l	#29161,d0
	bsr	fp_ldi
	bsr	fp_div
	FLDI	100
	bsr	fp_mul
	moveq	#5,d0
	moveq	#2,d1
	lea	ex_str,a0
	bsr	fp_str
	lea	ex_str,a0
	lea	ex_t_pc,a1
	bra	pstr_cat

; j := random(word(state+mode+seed)) mod 3 (a3 = the planet)
ex_lifej:
	moveq	#0,d0
	move.b	PLANET_STATE(a3),d0
	moveq	#0,d1
	move.b	PLANET_MODE(a3),d1
	add.w	d1,d0
	add.w	PLANET_SEED(a3),d0
	bsr	mt_random
	divu	#3,d0
	swap	d0
	rts

; pop: techlvl > 0: 2000 * 10^(techlvl+1), else 10; randseed := seed;
; pop := round(pop/10*tl2) + pop + random(pop div 1000)  (random(int64) first, as FPC evaluates it)
ex_population:
	move.l	d3,-(sp)
	move.l	#10,d3
	move.w	ex_techlvl,d0
	ble.s	.s
	move.l	#2000,d3
.m:	move.l	d3,d1			; *10
	lsl.l	#3,d3
	add.l	d1,d3
	add.l	d1,d3
	subq.w	#1,d0
	bpl.s	.m
.s:	move.l	d3,ex_pop
	moveq	#0,d0
	move.w	PLANET_SEED(a3),d0
	bsr	mt_seed
	move.l	ex_pop,d2		; pop div 1000
	move.l	#1000,d0
	bsr	ex_ldiv
	bsr	mt_random64l
	move.l	d0,d3
	FSSE
	move.l	ex_pop,d0		; round(pop/10*tl2)
	bsr	fp_ldi
	FLDI	10
	bsr	fp_div
	move.w	ex_tl2,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	add.l	ex_pop,d0
	add.l	d3,d0
	move.l	d0,ex_pop
	move.l	(sp)+,d3
	rts

; ex_str := chr(techlvl+48) + '.' + chr(tl2+48)
ex_techstr:
	lea	ex_str,a0
	move.b	#3,(a0)
	move.w	ex_techlvl,d0
	add.w	#48,d0
	move.b	d0,1(a0)
	move.b	#'.',2(a0)
	move.w	ex_tl2,d0
	add.w	#48,d0
	move.b	d0,3(a0)
	rts

; ---------------------------------------------------------------- the data pages
; refreshinfogathered(force d0.b)
refreshinfogathered:
	movem.l	d3-d4,-(sp)
	move.b	d0,d4
	moveq	#1,d3
.j:	lea	ex_dg-4,a0
	move.w	d3,d0
	lsl.w	#2,d0
	add.w	d0,a0
	tst.b	d4
	bne.s	.do
	move.w	(a0),d0
	cmp.w	2(a0),d0
	beq	.n
.do:	move.w	2(a0),d0
	move.w	d0,(a0)
	cmp.w	#1000,d0
	blt.s	.pc
	lea	ex_t_completed,a0
	bra.s	.pr
.pc:	move.w	d0,-(sp)		; str(n:3) -> " 12" -> "1.2" style: s[4]:=s[3]; s[3]:='.'
	ext.l	d0
	moveq	#3,d1
	lea	ex_str,a0
	bsr	int_str
	lea	ex_str,a0
	addq.b	#1,(a0)
	move.b	3(a0),4(a0)
	move.b	#'.',3(a0)
	cmp.w	#10,(sp)+
	bge.s	.p2
	move.b	#'0',2(a0)
.p2:	lea	ex_t_pc,a1
	bsr	pstr_cat
	lea	ex_str,a0
.pr:	move.w	d3,d1			; printxy(10+5*13, 152+j*7, ...)
	mulu	#7,d1
	add.w	#152,d1
	moveq	#75,d0
	bsr	printxy
.n:	addq.w	#1,d3
	cmp.w	#5,d3
	ble	.j
	movem.l	(sp)+,d3-d4
	rts

displayinfogathered:
	movem.l	d3-d4,-(sp)
	bsr	mousehide
	tst.w	ex_explorelevel
	beq.s	.nf
	BAR	5,147,132,196,0
	st	d0
	bsr	refreshinfogathered
	bra.s	.t
.nf:	sf	d0
	bsr	refreshinfogathered
.t:	PXY	6,148,"Information Gathered"
	moveq	#1,d3
.l:	move.w	d3,d0
	subq.w	#1,d0
	mulu	#14,d0
	lea	ex_scantypes,a0
	add.w	d0,a0
	move.w	d3,d1
	mulu	#7,d1
	add.w	#152,d1
	moveq	#10,d0
	bsr	printxy
	addq.w	#1,d3
	cmp.w	#5,d3
	ble.s	.l
	bsr	mouseshow
	clr.w	ex_explorelevel
	moveq	#0,d4			; a: scans completed (notes bits)
	moveq	#1,d3
.c:	lea	ex_dg-4+2,a0
	move.w	d3,d0
	lsl.w	#2,d0
	cmp.w	#1000,0(a0,d0.w)
	blt.s	.cn
	bsr	ex_plan
	move.w	d3,d0
	addq.w	#1,d0
	bset	d0,PLANET_NOTES(a0)
	addq.w	#1,d4
.cn:	addq.w	#1,d3
	cmp.w	#5,d3
	ble.s	.c
	lea	ex_probes+PR_STATUS,a0	; a probe out: a := 0
	move.w	ex_numprobes,d0
	bra.s	.pe
.p:	tst.w	(a0)
	beq.s	.pn
	moveq	#0,d4
.pn:	lea	PR_SIZE(a0),a0
.pe:	dbf	d0,.p
	cmp.w	#5,d4
	bne.s	.x
	tst.b	ex_donescan
	bne.s	.x
	bsr	summaryinfo
.x:	movem.l	(sp)+,d3-d4
	rts

; SetScan(nextscan d0)
setscan:
	movem.l	d3-d6,-(sp)
	tst.w	d0
	beq.s	.l
	move.w	d0,d1
	bpl.s	.a
	neg.w	d1
.a:	cmp.w	#5,d1
	bgt.s	.l
	lea	ex_dg-4+2,a0
	lsl.w	#2,d1
	cmp.w	#1000,0(a0,d1.w)
	bge.s	.l
	move.w	d0,ex_que
.l:	moveq	#1,d3			; i
.i:	moveq	#112,d4			; c: queued 127 and 240, open 95 and 240, done 63 and 240
	cmp.w	ex_que,d3
	beq.s	.c
	moveq	#80,d4
	lea	ex_dg-4+2,a0
	move.w	d3,d0
	lsl.w	#2,d0
	cmp.w	#1000,0(a0,d0.w)
	blt.s	.c
	moveq	#48,d4
.c:	move.w	d3,d6			; rows 9*i+14 .. 9*i+17, x 2..20
	mulu	#9,d6
	add.w	#14,d6
	moveq	#4-1,d5
.y:	moveq	#2,d0
	move.w	d6,d1
	bsr	ms_addr
	moveq	#19-1,d0
.x:	move.b	(a0),d1
	cmp.b	#32,d1
	blo.s	.n
	and.b	#15,d1
	or.b	d4,d1
	move.b	d1,(a0)
.n:	addq.l	#1,a0
	dbf	d0,.x
	addq.w	#1,d6
	dbf	d5,.y
	moveq	#2,d0
	move.w	d6,d3
	subq.w	#1,d3
	move.w	d3,d1
	subq.w	#3,d1
	moveq	#20,d2
	bsr	ms_dirty
	move.w	d6,d3			; (restore i)
	sub.w	#18,d3
	divu	#9,d3
	addq.w	#1,d3
	cmp.w	#5,d3
	ble.s	.i
	movem.l	(sp)+,d3-d6
	rts

; ---------------------------------------------------------------- controlprobes
controlprobes:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	mousehide
	sf	ex_dirty
	moveq	#1,d7			; j
.j:	cmp.w	ex_numprobes,d7
	bgt	.done
	move.w	d7,d0
	bsr	ex_probe
	move.l	a0,a3
	move.w	PR_STATUS(a3),d0
	cmp.w	#3,d0
	beq	.s3
	cmp.w	#4,d0
	beq	.s4
	tst.w	d0
	beq	.s0
	cmp.w	#7,d0
	beq	.s7
	subq.w	#1,PR_TIMELEFT(a3)	; the others count down
	bne	.txt
	move.w	PR_STATUS(a3),d0
	cmp.w	#1,d0
	beq	.t1
	cmp.w	#2,d0
	beq	.t2
	cmp.w	#5,d0
	beq	.t5
	cmp.w	#6,d0
	beq	.t6
	cmp.w	#8,d0
	beq	.t8
	bra	.txt
.s3:	bsr	ex_pslot		; moving/gathering (a probe sent for an anomaly: on to it)
	tst.w	(a0)
	bne.s	.s3m
	bsr	ex_scanopen
	beq.s	.s3r
.s3m:	move.w	d7,d0
	bsr	moveprobe
	bra	.txt
.s3r:	bsr	ex_retarget		; return to the craft
	bra	.txt
.s4:	subq.w	#1,PR_TIMELEFT(a3)	; analysing
	bne	.s4s
	bsr	ex_pslot
	tst.w	(a0)
	bne	.s4p			; at the anomaly: pick it up
	tst.w	PR_FUEL(a3)
	ble.s	.s4r
	bsr	ex_scanopen
	beq.s	.s4r
	move.w	#3,PR_STATUS(a3)	; to the next place
	move.w	#200,d0
	bsr	mt_random
	add.w	#20,d0
	move.w	d0,PR_TARX(a3)
	moveq	#80,d0
	bsr	mt_random
	add.w	#20,d0
	move.w	d0,PR_TARY(a3)
	bra	.txt
.s4r:	bsr	ex_retarget
	bra	.txt
.s4p:	move.w	(a0),d3			; 1994: pick up the anomaly (cache index d3)
	clr.w	(a0)
	move.l	a0,a4
	bsr	ex_plan
	add.w	d3,d3
	move.w	PLANET_CACHE-2(a0,d3.w),8(a4)	; carried home: into the hold at refuelling
	clr.w	PLANET_CACHE-2(a0,d3.w)
	lea	ex_itemloc-2,a0		; its mark goes as in retrieve: landcolors^ and screen
	add.w	d3,a0			; [y+12, x+27] := landcolors^[y+11, x+27]
	moveq	#0,d0
	move.b	1(a0),d0
	add.w	#27,d0
	moveq	#0,d1
	move.b	(a0),d1
	add.w	#11,d1
	movem.w	d0-d1,-(sp)
	bsr	ex_lcaddr
	move.b	(a0),d4
	movem.w	(sp)+,d0-d1
	addq.w	#1,d1
	movem.w	d0-d1,-(sp)
	bsr	ex_lcaddr
	move.b	d4,(a0)
	movem.w	(sp)+,d0-d1
	move.b	d4,d2
	bsr	ms_pset
	st	ex_pickup		; the lists and the zoom after mouseshow (as retrieve)
	bra.s	.s4r
.s4s:	bsr	ex_pslot		; perform the scan (not by a probe sent for an anomaly)
	tst.w	(a0)
	bne	.s4v
	CLASSIC				; 1994: for its own category, while open
	bne.s	.s4c
	tst.w	ex_que
	beq	.s4v
	bra.s	.s4k
.s4c:	bsr	ex_scanopen		; (done by another probe meanwhile: nothing to add)
	beq	.s4v
.s4k:	moveq	#1,d0			; i := (SkillRange(True, 3, 5, 10) + 20) * 10 div 100
	moveq	#3,d1
	moveq	#5,d2
	moveq	#10,d3
	bsr	skillrange
	add.w	#20,d0
	muls	#10,d0
	divs	#100,d0
	move.w	ex_que,d1
	bpl.s	.qa
	neg.w	d1
.qa:	CLASSIC				; 1994: into the probe's own category
	beq.s	.qb
	move.w	PR_TOGATHER(a3),d1
.qb:	lsl.w	#2,d1
	lea	ex_dg-4+2,a0
	add.w	d0,0(a0,d1.w)
	cmp.w	#1000,0(a0,d1.w)
	blt	.s4d
	move.w	d1,-(sp)
	bsr	createano
	move.w	(sp)+,d1
	lea	ex_dg-4+2,a0
	move.w	#1000,0(a0,d1.w)
	CLASSIC				; 1994: the que moves on only if this was its category
	beq.s	.qc
	move.w	ex_que,d0
	bpl.s	.qd
	neg.w	d0
.qd:	lsl.w	#2,d0
	cmp.w	d1,d0
	bne	.s4d
.qc:	tst.w	ex_que
	ble.s	.qn
	clr.w	ex_que			; the next open scan
	moveq	#0,d0
	bsr	setscan
	moveq	#1,d3
.qi:	lea	ex_dg-4+2,a0
	move.w	d3,d0
	lsl.w	#2,d0
	cmp.w	#1000,0(a0,d0.w)
	bge.s	.qj
	move.w	d3,d0
	bsr	setscan
	bra.s	.s4d
.qj:	addq.w	#1,d3
	cmp.w	#5,d3
	ble.s	.qi
	bra.s	.s4d
.qn:	clr.w	ex_que
	moveq	#0,d0
	bsr	setscan
.s4d:	st	ex_dirty
.s4v:	moveq	#6,d0			; screen[cury+12, curx+27] := 90+random(6)
	bsr	mt_random
	move.w	d0,d2
	add.w	#90,d2
	move.w	PR_CURX(a3),d0
	add.w	#27,d0
	move.w	PR_CURY(a3),d1
	add.w	#12,d1
	bsr	ms_pset
	move.w	PR_CURX(a3),d0		; the view (one column further right than moveprobe's)
	add.w	#12,d0
	move.w	PR_CURY(a3),d1
	move.w	d7,d2
	bsr	ex_tobox
	moveq	#1,d0			; the probe icon over it
	move.w	d7,d1
	move.w	#280,d2
	bsr	ex_iconm
	moveq	#7,d0			; a message: msgs^[a, i, b] at [j*40-7+i, 297+b]
	bsr	mt_random
	lea	ex_msgs,a4
	mulu	#MSG_SIZE,d0
	add.w	d0,a4
	move.w	d7,d4
	mulu	#40,d4
	subq.w	#7,d4
	moveq	#8-1,d5
.mr:	move.w	#297,d0
	move.w	d4,d1
	bsr	ms_addr
	moveq	#16-1,d0
.mc:	move.b	(a4)+,d1
	beq.s	.mn
	move.b	d1,(a0)
.mn:	addq.l	#1,a0
	dbf	d0,.mc
	addq.w	#1,d4
	dbf	d5,.mr
	move.w	#297,d0
	move.w	d4,d3
	subq.w	#1,d3
	move.w	d3,d1
	subq.w	#7,d1
	move.w	#312,d2
	bsr	ms_dirty
	bra	.txt
.s0:	tst.w	ex_que			; launch
	ble	.txt
	bsr	ex_notall
	bne.s	.l0
	clr.w	ex_que
	bra	.txt
.l0:	move.w	ex_que,d0
	bpl.s	.l1
	neg.w	d0
.l1:	move.w	d0,PR_TOGATHER(a3)
	move.w	#1,PR_STATUS(a3)
	move.w	#20,PR_TIMELEFT(a3)
	move.w	d7,d0
	bsr	ex_showplanet
	cmp.w	#4,ex_techlvl		; destroyed by the natives?
	blt.s	.l2
	moveq	#100,d0
	bsr	mt_random
	cmp.w	#25,d0
	blt.s	.lk
	bra.s	.l3
.l2:	cmp.w	#3,ex_techlvl
	bne.s	.l3
	moveq	#100,d0
	bsr	mt_random
	cmp.w	#5,d0
	bge.s	.l3
.lk:	move.w	#7,PR_STATUS(a3)
	move.w	#ID_PROBOT,d0
	bsr	removecargo
	move.w	ex_que,d0
	bpl.s	.lk1
	neg.w	d0
.lk1:	neg.w	d0
	move.w	d0,ex_que
	moveq	#0,d0
	bsr	setscan
.l3:	tst.b	GS_SHIP+SHIP_OPTIONS+OPT_DIFFICULTY-1(a6)	; easy: the scan counts as done
	bne.s	.l4
	move.w	ex_que,d0
	beq.s	.l4
	bpl.s	.l35
	neg.w	d0
.l35:	addq.w	#1,d0
	bsr	ex_plan
	bset	d0,PLANET_NOTES(a0)
.l4:	move.w	ex_que,d0		; if datagathered[abs(que),2] >= 1000
	bpl.s	.l5
	neg.w	d0
.l5:	lsl.w	#2,d0
	lea	ex_dg-4+2,a0
	cmp.w	#1000,0(a0,d0.w)
	blt	.txt
	bsr	createano
	tst.w	ex_que
	ble.s	.l7
	clr.w	ex_que
	moveq	#1,d3
.l6:	lea	ex_dg-4+2,a0
	move.w	d3,d0
	lsl.w	#2,d0
	cmp.w	#1000,0(a0,d0.w)
	bge.s	.l6n
	move.w	d3,ex_que
	bra.s	.l8
.l6n:	addq.w	#1,d3
	cmp.w	#5,d3
	ble.s	.l6
	bra.s	.l8
.l7:	clr.w	ex_que
.l8:	moveq	#0,d0
	bsr	setscan
	bra	.txt
.s7:	moveq	#1,d5			; destroyed: noise, rows j*40-26+1..+27
.db:	moveq	#1,d6
.da:	moveq	#16,d0
	bsr	mt_random
	move.w	d0,d2
	add.w	#16,d2
	move.w	d6,d0
	add.w	#280,d0
	move.w	d7,d1
	mulu	#40,d1
	sub.w	#26,d1
	add.w	d5,d1
	movem.w	d0-d1,-(sp)
	bsr	ms_addr
	move.b	d2,(a0)
	movem.w	(sp)+,d0-d1
	addq.w	#1,d6
	cmp.w	#31,d6
	ble.s	.da
	addq.w	#1,d5
	cmp.w	#27,d5
	ble.s	.db
	move.w	#281,d0
	move.w	d7,d1
	mulu	#40,d1
	sub.w	#25,d1
	move.w	#311,d2
	move.w	d1,d3
	add.w	#26,d3
	bsr	ms_dirty
	bra	.txt
.t1:	move.w	#40,PR_TIMELEFT(a3)	; landing
	move.w	#2,PR_STATUS(a3)
	move.w	#50,PR_FUEL(a3)
	moveq	#4,d0
	move.w	d7,d1
	move.w	#281,d2
	bsr	ex_iconm
	bra	.txt
.t2:	move.w	#180,d0			; landed
	bsr	mt_random
	add.w	#30,d0
	move.w	d0,PR_CURX(a3)
	moveq	#60,d0
	bsr	mt_random
	add.w	#30,d0
	move.w	d0,PR_CURY(a3)
	move.w	#180,d0
	bsr	mt_random
	add.w	#30,d0
	move.w	d0,PR_TARX(a3)
	moveq	#60,d0
	bsr	mt_random
	add.w	#30,d0
	move.w	d0,PR_TARY(a3)
	move.w	#281,d0			; scr_fillchar(screen[j*40+1, 281], 30, 0)
	move.w	d7,d1
	mulu	#40,d1
	addq.w	#1,d1
	move.w	#310,d2
	move.w	d1,d3
	moveq	#0,d4
	bsr	ms_bar
	move.w	#3,PR_STATUS(a3)
	move.w	#281,d0			; rows j*40-25 .. j*40+4, 32 bytes: 0
	move.w	d7,d1
	mulu	#40,d1
	sub.w	#25,d1
	move.w	#312,d2
	move.w	d1,d3
	add.w	#29,d3
	moveq	#0,d4
	bsr	ms_bar
	bsr	ex_pslot		; 1994: a probe sent for an anomaly heads for it
	move.w	(a0),d0
	beq	.txt
	add.w	d0,d0
	lea	ex_itemloc-2,a0
	add.w	d0,a0
	moveq	#0,d0
	move.b	1(a0),d0
	move.w	d0,PR_TARX(a3)
	move.b	(a0),d0
	move.w	d0,PR_TARY(a3)
	bra	.txt
.t5:	moveq	#3,d0			; returning
	move.w	d7,d1
	bsr	ex_icon
	move.w	#40,PR_TIMELEFT(a3)
	move.w	#6,PR_STATUS(a3)
	bra	.txt
.t6:	move.w	#8,PR_STATUS(a3)	; refuelling
	move.w	#10,PR_TIMELEFT(a3)
	moveq	#2,d0
	move.w	d7,d1
	bsr	ex_icon
	st	ex_dirty
	bsr	ex_pslot		; 1994: an anomaly brought home goes into the hold
	move.w	8(a0),d0		; (its fit was checked at the launch)
	beq	.txt
	clr.w	8(a0)
	st	d1
	bsr	addcargo2
	bra	.txt
.t8:	clr.w	PR_STATUS(a3)		; cool down
	st	ex_dirty
	bsr	ex_notall
	bne.s	.txt
	sf	ex_dirty
	bsr	displayinfogathered
.txt:	move.w	PR_STATUS(a3),d0	; printxy(269, 4+j*40, probetext[status])
	mulu	#10,d0
	lea	ex_probetext,a0
	add.w	d0,a0
	move.w	d7,d1
	mulu	#40,d1
	addq.w	#4,d1
	move.w	#269,d0
	bsr	printxy
	addq.w	#1,d7
	bra	.j
.done:	tst.b	ex_dirty
	beq.s	.nd
	tst.w	ex_explorelevel
	bne.s	.nd
	bsr	displayinfogathered
.nd:	tst.b	ex_showscan
	bne.s	.x
	bsr	ex_zoomrect
.x:	bsr	mouseshow
	tst.b	ex_pickup		; 1994: an anomaly was picked up - as retrieve after it
	beq.s	.xx
	sf	ex_pickup
	cmp.w	#5,ex_explorelevel	; (the anomaly list again only if it is shown)
	bne.s	.xr
	bsr	readyanoinfo
.xr:	bsr	redraw
	bsr	showzoom
.xx:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; probe a3, num d7: screen[tary+12, tarx+27] := landcolors^; icon 4; timeleft 70; status 5
ex_retarget:
	move.w	PR_TARX(a3),d0
	add.w	#27,d0
	move.w	PR_TARY(a3),d1
	add.w	#12,d1
	bsr	ex_restore
	moveq	#4,d0
	move.w	d7,d1
	bsr	ex_icon
	move.w	#70,PR_TIMELEFT(a3)
	move.w	#5,PR_STATUS(a3)
	rts

; the zoom's rectangle on the map by zoommode
ex_zoomrect:
	movem.l	d3,-(sp)
	move.w	ex_zoommode,d2
	moveq	#60,d3
	cmp.w	#1,d2
	beq.s	.r
	moveq	#30,d3
	cmp.w	#2,d2
	beq.s	.r
	moveq	#20,d3
	cmp.w	#3,d2
	bne.s	.x
.r:	move.w	ex_zoomx,d0
	add.w	#28,d0
	move.w	ex_zoomy,d1
	add.w	#13,d1
	move.w	d0,d2
	add.w	d3,d2
	add.w	d1,d3
	bsr	ex_rect
.x:	movem.l	(sp)+,d3
	rts

; crewtick.pas SkillRange(background d0.b, crew d1, difficulty d2, learn d3): out d0.w
skillrange:
	movem.l	d3-d7,-(sp)
	move.b	d0,ct_bg
	move.w	d1,d4			; crew
	move.w	d2,d5			; difficulty
	move.w	d3,d7			; learn
	move.w	d4,d0
	bsr	ct_crew
	moveq	#0,d6
	move.b	CREW_SKILL(a0),d6	; ski
	cmp.w	#5,d6
	bgt.s	.a
	moveq	#5,d6
.a:	move.w	d5,d3			; dif
	bgt.s	.b
	moveq	#1,d3
.b:	move.w	d6,d0			; random(ski) - random(dif)
	bsr	mt_random
	move.w	d0,-(sp)
	move.w	d3,d0
	bsr	mt_random
	sub.w	d0,(sp)
	move.w	d3,d1			; CrewStress(crew, 100*dif div ski)
	mulu	#100,d1
	divu	d6,d1
	move.w	d4,d0
	bsr	ct_stress
	move.w	#1000,d0		; if random(1000) < learn then addxp(crew, difficulty, ord(not background))
	bsr	mt_random
	cmp.w	d7,d0
	bge.s	.x
	move.w	d4,d0
	move.w	d5,d1
	ext.l	d1
	moveq	#1,d2
	tst.b	ct_bg
	beq.s	.ad
	moveq	#0,d2
.ad:	bsr	addxp
.x:	move.w	(sp)+,d0
	movem.l	(sp)+,d3-d7
	rts

; ---------------------------------------------------------------- the data lists
; displayatmoinfo / hydro / litho: scaninfo^ entries of state d0 from explorecur, 7 rows
ex_displaylist:
	movem.l	d3-d6,-(sp)
	move.w	d0,d6			; state
	moveq	#0,d3			; y
	move.w	ex_explorecur,d4	; x
.r:	cmp.w	#53,d4
	bge.s	.e
	bsr	ex_scanstate
	cmp.b	d6,d0
	beq.s	.f
	addq.w	#1,d4
	bra.s	.r
.f:	move.w	d4,d0			; printxy(8, 155+y*6, name)
	subq.w	#1,d0
	mulu	#SCAN_SIZE,d0
	lea	ex_scaninfo,a0
	add.w	d0,a0
	move.w	d3,d1
	mulu	#6,d1
	add.w	#155,d1
	moveq	#8,d0
	bsr	printxy
	addq.w	#1,d3
.e:	addq.w	#1,d4
	cmp.w	#7,d3
	beq.s	.d
	cmp.w	#52,d4
	ble.s	.r
.d:	cmp.w	#7,d3
	bge.s	.x
	move.w	d3,d1			; clear rows (y+1)*6+149 .. 197, x 5..132
	addq.w	#1,d1
	mulu	#6,d1
	add.w	#149,d1
	moveq	#5,d0
	move.w	#132,d2
	move.w	#197,d3
	moveq	#0,d4
	bsr	ms_bar
.x:	movem.l	(sp)+,d3-d6
	rts
; d0.b = scaninfo^[d4].state (d4 in 1..52)
ex_scanstate:
	moveq	#-1,d0			; (scaninfo^[0]: before the array; taken as no state)
	tst.w	d4
	ble.s	.x
	move.w	d4,d0
	subq.w	#1,d0
	mulu	#SCAN_SIZE,d0
	lea	ex_scaninfo+25,a0
	move.b	0(a0,d0.w),d0
.x:	rts

; displaybioinfo
displaybioinfo:
	movem.l	d3-d4/a3,-(sp)
	bsr	computebiostuff
	bsr	ex_plan
	move.l	a0,a3
	PXY	9,155,"% Bio:"
	bsr	ex_biopct
	moveq	#44,d0
	move.w	#155,d1
	lea	ex_str,a0
	bsr	printxy
	cmp.b	#6,PLANET_STATE(a3)
	bne.s	.n
	cmp.b	#2,PLANET_MODE(a3)
	bne.s	.n
	PXY	9,163,"Sapient Life"
	PXY	14,169,"Void"
	PXY	14,175,"Dwellers"
	PXY	9,183,"Pop.: Unknown"
	PXY	9,189,"Tech Level: 6.0"
	bra	.x
.n:	move.w	ex_techlvl,d0
	cmp.w	#-2,d0
	bne.s	.n1
	PXY	9,163,"No Life"
	bra	.x
.n1:	cmp.w	#-1,d0
	bne	.n2
	PXY	9,163,"Dominant Life Form"
	moveq	#0,d0
	move.w	PLANET_SEED(a3),d0
	bsr	mt_seed
	bsr	ex_lifej
	tst.w	d0
	bne.s	.j1
	moveq	#2,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.j0b
	PXY	14,169,"Short Chain"
	bra.s	.j0c
.j0b:	PXY	14,169,"Long Chain"
.j0c:	PXY	14,175,"Proteins"
	bra	.x
.j1:	cmp.w	#1,d0
	bne.s	.j2
	moveq	#2,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.j1b
	PXY	14,169,"Simple"
	bra.s	.j1c
.j1b:	PXY	14,169,"Complex"
.j1c:	PXY	14,175,"Protoplasms"
	bra	.x
.j2:	PXY	14,169,"Singlecelled"
	moveq	#3,d0
	bsr	mt_random
	mulu	#12,d0
	lea	ex_cells,a0
	add.w	d0,a0
	moveq	#14,d0
	move.w	#175,d1
	bsr	printxy
	bra	.x
.n2:	tst.w	d0
	bmi	.x
	cmp.w	#5,d0
	bgt	.x
	PXY	9,163,"Sapient Life"
	bsr	ex_population
	moveq	#0,d0			; randseed := seed; str1 := alientypes[random(11)]
	move.w	PLANET_SEED(a3),d0
	bsr	mt_seed
	moveq	#11,d0
	bsr	mt_random
	mulu	#13,d0
	lea	alientypes,a0
	add.w	d0,a0
	moveq	#14,d0
	move.w	#175,d1
	bsr	printxy
	moveq	#5,d0
	bsr	mt_random
	mulu	#16,d0
	lea	ex_diets,a0
	add.w	d0,a0
	lea	ex_str,a1		; (the diet without its trailing space)
	exg	a0,a1
	bsr	pstr_cpy
	subq.b	#1,ex_str
	moveq	#14,d0
	move.w	#169,d1
	lea	ex_str,a0
	bsr	printxy
	PXY	9,183,"Pop.:"
	move.l	ex_pop,d0		; str(pop) + '000'
	moveq	#0,d1
	lea	ex_str,a0
	bsr	int_str
	lea	ex_str,a0
	lea	ex_t_000,a1
	bsr	pstr_cat
	moveq	#39,d0
	move.w	#183,d1
	lea	ex_str,a0
	bsr	printxy
	PXY	9,189,"Tech Level:"
	bsr	ex_techstr
	moveq	#69,d0
	move.w	#189,d1
	lea	ex_str,a0
	bsr	printxy
.x:	movem.l	(sp)+,d3-d4/a3
	rts

; readyatmoinfo / readyhydroinfo / readylithoinfo: level d0 (3, 2, 1), state d1 (0, 1, 2),
; title a0
ex_readylist:
	movem.l	d3-d4/a3,-(sp)
	move.w	d0,d3
	move.w	d1,d4
	move.l	a0,a3
	tst.b	ex_donescan
	beq.s	.a
	tst.b	ex_showscan
	bne.s	.a
	bsr	summaryinfo
.a:	move.w	d3,ex_explorelevel
	move.w	#1,ex_explorecur
	move.l	d4,-(sp)
	move.w	#1,d4
.f:	cmp.w	#53,d4
	bge.s	.ff
	bsr	ex_scanstate
	cmp.b	3(sp),d0
	beq.s	.ff
	addq.w	#1,d4
	bra.s	.f
.ff:	cmp.w	#53,d4
	bne.s	.fs
	moveq	#0,d4
.fs:	move.w	d4,ex_explorecur
	move.l	(sp)+,d4
	bsr	mousehide
	BAR	5,147,132,196,0
	move.l	a3,a0
	moveq	#6,d0
	move.w	#148,d1
	bsr	printxy
	move.w	d4,d0
	bsr	ex_displaylist
	bsr	mouseshow
	movem.l	(sp)+,d3-d4/a3
	rts
readylithoinfo:
	moveq	#1,d0
	moveq	#2,d1
	lea	ex_t_litho,a0
	bra	ex_readylist
readyhydroinfo:
	moveq	#2,d0
	moveq	#1,d1
	lea	ex_t_hydro,a0
	bra	ex_readylist
readyatmoinfo:
	moveq	#3,d0
	moveq	#0,d1
	lea	ex_t_atmo,a0
	bra	ex_readylist
readybioinfo:
	tst.b	ex_donescan
	beq.s	.a
	tst.b	ex_showscan
	bne.s	.a
	bsr	summaryinfo
.a:	move.w	#4,ex_explorelevel
	bsr	mousehide
	BAR	5,147,132,196,0
	PXY	6,148,"Biosphere Data"
	bsr	displaybioinfo
	bra	mouseshow

readyanoinfo:
	movem.l	d3-d4/a3,-(sp)
	move.w	#5,ex_explorelevel
	bsr	createano
	bsr	mousehide
	BAR	5,147,132,196,0
	PXY	6,148,"Anomaly Data"
	moveq	#0,d4			; y
	moveq	#1,d3
.j:	bsr	ex_plan
	move.w	d3,d0
	add.w	d0,d0
	move.w	PLANET_CACHE-2(a0,d0.w),d0
	ble.s	.n
	cmp.w	#ID_ARTIFACT_OFFSET,d0
	ble.s	.c
	bsr	getartifactname		; i := maxcargo
	move.w	#MAXCARGO,d0
	bra.s	.p
.c:	lea	GS_CARGO+CARGO_INDEX(a6),a0	; i: the item in cargo[] (maxcargo if not found)
	moveq	#1,d1
.ci:	cmp.w	(a0),d0
	beq.s	.cf
	lea	CARGO_SIZEOF(a0),a0
	addq.w	#1,d1
	cmp.w	#MAXCARGO,d1
	ble.s	.ci
	move.w	#MAXCARGO,d1
.cf:	move.w	d1,d0
.p:	subq.w	#1,d0
	mulu	#CARGO_SIZEOF,d0
	lea	GS_CARGO+CARGO_NAME(a6),a0
	add.w	d0,a0
	addq.w	#1,d4
	move.w	d4,d1
	mulu	#6,d1
	add.w	#148,d1
	moveq	#11,d0
	bsr	printxy
.n:	addq.w	#1,d3
	cmp.w	#7,d3
	ble.s	.j
	tst.b	ex_showscan
	beq.s	.x
	moveq	#19,d0
	bsr	landsprinkle
	sf	ex_showscan
.x:	bsr	mouseshow
	movem.l	(sp)+,d3-d4/a3
	rts

; newzoom(x d0, y d1)
newzoom:
	tst.b	ex_showscan
	bne	.x
	cmp.w	#28,d0
	ble	.x
	cmp.w	#13,d1
	ble	.x
	cmp.w	#268,d0
	bge	.x
	cmp.w	#132,d1
	bge	.x
	movem.w	d0-d1,-(sp)
	bsr	undo
	movem.w	(sp)+,d0-d1
	sub.w	#28,d0
	sub.w	#13,d1
	move.w	ex_zoommode,d2
	moveq	#29,d3
	cmp.w	#1,d2
	beq.s	.o
	moveq	#14,d3
	cmp.w	#2,d2
	beq.s	.o
	moveq	#9,d3
	cmp.w	#3,d2
	bne.s	.no
.o:	sub.w	d3,d0
	sub.w	d3,d1
	move.w	d3,ex_zoomoffset
.no:	move.w	d0,ex_zoomx
	move.w	d1,ex_zoomy
	cmp.w	#1,d2			; clamp
	bne.s	.c2
	move.w	#178,d0
	move.w	#178,d1
	moveq	#58,d2
	moveq	#58,d3
	bra.s	.cl
.c2:	cmp.w	#2,d2
	bne.s	.c3
	move.w	#207,d0
	move.w	#208,d1
	moveq	#88,d2
	moveq	#88,d3
	bra.s	.cl
.c3:	cmp.w	#3,d2
	bne.s	.rd
	move.w	#217,d0
	move.w	#217,d1
	moveq	#98,d2
	moveq	#98,d3
.cl:	cmp.w	ex_zoomx,d0		; if zoomx > lim then zoomx := val else if zoomx <= 0 then 1
	bge.s	.c4
	move.w	d1,ex_zoomx
	bra.s	.c5
.c4:	tst.w	ex_zoomx
	bgt.s	.c5
	move.w	#1,ex_zoomx
.c5:	cmp.w	ex_zoomy,d2
	bge.s	.c6
	move.w	d3,ex_zoomy
	bra.s	.rd
.c6:	tst.w	ex_zoomy
	bgt.s	.rd
	move.w	#1,ex_zoomy
.rd:	bra	redraw
.x:	rts

undo:	bsr	mousehide
	bsr	undozoom
	bra	mouseshow

redraw:
	bsr	mousehide
	move.w	ex_zoomx,d0
	move.w	ex_zoomy,d1
	move.w	ex_zoommode,d2
	cmp.w	#1,d2
	bne.s	.2
	bsr	zoom1x
	bra.s	.x
.2:	cmp.w	#2,d2
	bne.s	.3
	bsr	zoom2x
	bra.s	.x
.3:	cmp.w	#3,d2
	bne.s	.x
	bsr	zoom3x
.x:	bra	mouseshow

; the explore cursor in the lists: dec / inc (explorelevel 1-3)
decexplorecursor:
	moveq	#-1,d0
	bra.s	ex_movecursor
incexplorecursor:
	moveq	#1,d0
ex_movecursor:
	movem.l	d3-d6,-(sp)
	move.w	d0,d5
	bsr	mousehide
	move.w	ex_explorelevel,d0
	cmp.w	#1,d0
	blt	.x
	cmp.w	#3,d0
	bgt	.x
	moveq	#3,d6			; state: level 3 -> 0, 2 -> 1, 1 -> 2
	sub.w	d0,d6
	move.w	ex_explorecur,d4
	add.w	d5,d4
	tst.w	d5
	bmi.s	.dec
.i:	cmp.w	#53,d4			; inc: while (cur < 53) and (state <> s) do inc
	bge.s	.iw
	bsr	ex_scanstate
	cmp.b	d6,d0
	beq.s	.d
	addq.w	#1,d4
	bra.s	.i
.iw:	moveq	#1,d4			; wrap: from 1, 53 -> 0
.i2:	cmp.w	#53,d4
	bge.s	.i3
	bsr	ex_scanstate
	cmp.b	d6,d0
	beq.s	.d
	addq.w	#1,d4
	bra.s	.i2
.i3:	moveq	#0,d4
	bra.s	.d
.dec:	tst.w	d4			; dec: while (cur > 0) and (state <> s) do dec
	ble.s	.dw
	bsr	ex_scanstate
	cmp.b	d6,d0
	beq.s	.dk
	subq.w	#1,d4
	bra.s	.dec
.dk:	tst.w	d4
	bgt.s	.d
.dw:	moveq	#52,d4			; wrap from 52
.d2:	tst.w	d4
	ble.s	.d
	bsr	ex_scanstate
	cmp.b	d6,d0
	beq.s	.d
	subq.w	#1,d4
	bra.s	.d2
.d:	move.w	d4,ex_explorecur
	move.w	d6,d0
	bsr	ex_displaylist
.x:	bsr	mouseshow
	movem.l	(sp)+,d3-d6
	rts

; retrieve: the anomaly under the zoom's centre into the cargo hold
retrieve:
	movem.l	d3-d4,-(sp)
	clr.w	ex_index
	moveq	#1,d3
.j:	bsr	ex_plan
	move.w	d3,d0
	add.w	d0,d0
	tst.w	PLANET_CACHE-2(a0,d0.w)
	ble.s	.n
	lea	ex_itemloc-2,a0
	add.w	d0,a0
	moveq	#0,d0
	move.b	(a0),d0
	sub.w	ex_zoomy,d0
	moveq	#0,d1
	move.b	1(a0),d1
	sub.w	ex_zoomx,d1
	cmp.w	#2,ex_zoommode
	bne.s	.z3
	sub.w	#15,d0
	sub.w	#14,d1
	bsr	ex_abs01
	cmp.w	#3,d0
	bge.s	.n
	cmp.w	#4,d1
	bge.s	.n
	bra.s	.hit
.z3:	cmp.w	#3,ex_zoommode
	bne.s	.n
	sub.w	#11,d0
	sub.w	#10,d1
	bsr	ex_abs01
	cmp.w	#4,d0
	bge.s	.n
	cmp.w	#4,d1
	bge.s	.n
.hit:	move.w	d3,ex_index		; (j := 7: the loop ends)
	bra.s	.e
.n:	addq.w	#1,d3
	cmp.w	#7,d3
	ble	.j
.e:	CLASSIC				; 1994 probes: a probe goes for it
	beq.s	.e0
	move.w	ex_index,d3
	ble	.r2
	bsr	ex_fetch
	bra.s	.r2
.e0:	bsr	mousehide
	move.w	ex_index,d3
	ble	.r
	bsr	ex_plan
	move.w	d3,d0
	add.w	d0,d0
	move.w	PLANET_CACHE-2(a0,d0.w),d0
	sf	d1
	bsr	addcargo2
	beq.s	.r
	lea	ex_itemloc-2,a0		; a := landcolors^[itemloc[index,1]+11, itemloc[index,2]+27]
	move.w	d3,d0
	add.w	d0,d0
	add.w	d0,a0
	moveq	#0,d0
	move.b	1(a0),d0
	add.w	#27,d0
	moveq	#0,d1
	move.b	(a0),d1
	add.w	#11,d1
	move.l	a0,-(sp)
	movem.w	d0-d1,-(sp)
	bsr	ex_lcaddr
	move.b	(a0),d4
	movem.w	(sp)+,d0-d1
	addq.w	#1,d1			; landcolors^ and screen one row lower := a
	movem.w	d0-d1,-(sp)
	bsr	ex_lcaddr
	move.b	d4,(a0)
	movem.w	(sp)+,d0-d1
	move.b	d4,d2
	bsr	ms_pset
	addq.l	#4,sp
	bsr	ex_plan
	move.w	d3,d0
	add.w	d0,d0
	clr.w	PLANET_CACHE-2(a0,d0.w)
.r:	bsr	mouseshow
.r2:	bsr	readyanoinfo
	bsr	redraw
	bsr	showzoom
	movem.l	(sp)+,d3-d4
	rts

; 1994 probes (retrieve): send a free probe for the anomaly in cache slot d3. Not twice for one
; anomaly; "All probes are busy." when none is docked; the fit is checked now (addcargo2 on the
; hold, its own messages, then the hold put back) - the item goes in at refuelling regardless.
ex_fetch:
	movem.l	d3-d7/a3-a4,-(sp)
	moveq	#1,d7			; one already on its way?
.a:	bsr	ex_pslot
	cmp.w	(a0),d3
	beq	.x
	addq.w	#1,d7
	cmp.w	#4,d7
	ble.s	.a
	moveq	#1,d7			; a docked probe
.f:	cmp.w	ex_numprobes,d7
	bgt.s	.busy
	move.w	d7,d0
	bsr	ex_probe
	tst.w	PR_STATUS(a0)
	beq.s	.got
	addq.w	#1,d7
	bra.s	.f
.busy:	lea	ex_t_busy,a0
	bsr	printbox
	bra	.x
.got:	move.l	a0,a3
	bsr	ex_plan
	move.w	d3,d0
	add.w	d0,d0
	move.w	PLANET_CACHE-2(a0,d0.w),d4	; the item
	lea	GS_SHIP+SHIP_CARGO(a6),a0	; does it fit: cargo[] and numcargo[] kept
	lea	ex_holdcopy,a1
	move.w	#1000/4-1,d0
.c1:	move.l	(a0)+,(a1)+
	dbf	d0,.c1
	bsr	mousehide
	move.w	d4,d0
	sf	d1
	bsr	addcargo2
	bsr	mouseshow
	lea	GS_SHIP+SHIP_CARGO(a6),a0	; it went in (an artifact even when over weight) if
	lea	ex_holdcopy,a1		; the hold changed; put it back
	moveq	#0,d5
	move.w	#1000/4-1,d0
.c2:	move.l	(a1)+,d1
	cmp.l	(a0),d1
	beq.s	.c3
	moveq	#1,d5
.c3:	move.l	d1,(a0)+
	dbf	d0,.c2
	tst.w	d5
	beq	.x
	bsr	ex_pslot		; launch it (as controlprobes' status 0)
	move.w	d3,(a0)
	clr.w	PR_TOGATHER(a3)
	move.w	#1,PR_STATUS(a3)
	move.w	#20,PR_TIMELEFT(a3)
	bsr	mousehide
	move.w	d7,d0
	bsr	ex_showplanet
	cmp.w	#4,ex_techlvl		; destroyed by the natives?
	blt.s	.l2
	moveq	#100,d0
	bsr	mt_random
	cmp.w	#25,d0
	blt.s	.lk
	bra.s	.l3
.l2:	cmp.w	#3,ex_techlvl
	bne.s	.l3
	moveq	#100,d0
	bsr	mt_random
	cmp.w	#5,d0
	bge.s	.l3
.lk:	move.w	#7,PR_STATUS(a3)
	move.w	#ID_PROBOT,d0
	bsr	removecargo
	bsr	ex_pslot
	clr.w	(a0)
.l3:	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d7/a3-a4
	rts

; utils.pas addcargo2(item d0, force d1.b): out d0.w = 1 (Z clear) if it fitted
addcargo2:
	movem.l	d3-d5,-(sp)
	move.w	d0,d3
	move.b	d1,d5
	bsr	mu_weight
	move.l	d0,d4
	move.w	d3,d0
	bsr	mu_cargorec
	move.w	CARGO_SIZE(a0),d0
	ext.l	d0
	add.l	d0,d4
	divs	#10,d4			; weight div 10
	ext.l	d4
	cmp.w	GS_SHIP+SHIP_CARGOMAX(a6),d4
	ble	.fits
	cmp.w	#ID_ARTIFACT_OFFSET,d3
	bge.s	.fits
	tst.b	d5
	bne.s	.fits
	lea	ex_str,a0		; printbox('Cargo full! '+str1+'/'+str2+' used.')
	lea	ex_t_cfull,a1
	bsr	pstr_cpy
	move.w	d4,d0
	bsr	mu_wstr
	lea	ex_str,a0
	lea	mu_s,a1
	bsr	pstr_cat
	lea	ex_str,a0
	lea	mu_t_slash,a1
	bsr	pstr_cat
	move.w	GS_SHIP+SHIP_CARGOMAX(a6),d0
	bsr	mu_wstr
	lea	ex_str,a0
	lea	mu_s,a1
	bsr	pstr_cat
	lea	ex_str,a0
	lea	ex_t_used,a1
	bsr	pstr_cat
	lea	ex_str,a0
	bsr	printbox
	moveq	#0,d0
	bra.s	.x
.fits:	moveq	#1,d1			; j: the item's slot (numcargo > 254: none)
	lea	GS_SHIP+SHIP_CARGO(a6),a0
.j:	cmp.w	(a0),d3
	beq.s	.found
	addq.l	#2,a0
	addq.w	#1,d1
	cmp.w	#251,d1
	bne.s	.j
	bra.s	.new
.found:	cmp.w	#254,SHIP_NUMCARGO-SHIP_CARGO(a0)
	ble.s	.inc
.new:	moveq	#1,d1			; the first free slot
	lea	GS_SHIP+SHIP_NUMCARGO(a6),a0
.f:	tst.w	(a0)
	beq.s	.ff
	addq.l	#2,a0
	addq.w	#1,d1
	cmp.w	#251,d1
	bne.s	.f
	lea	ex_t_noslot1,a0		; printbigbox('No cargo slot available. ...'); addcargo2 := false
	lea	ex_t_noslot2,a1
	bsr	printbigbox
	moveq	#0,d0
	bra	.x
.ff:	move.w	d3,SHIP_CARGO-SHIP_NUMCARGO(a0)
	move.w	#1,(a0)
	bra.s	.ok
.inc:	addq.w	#1,SHIP_NUMCARGO-SHIP_CARGO(a0)
.ok:	moveq	#1,d5
	cmp.w	GS_SHIP+SHIP_CARGOMAX(a6),d4
	ble.s	.s
	moveq	#0,d5
.s:	bsr	sortcargo
	move.w	d5,d0
.x:	movem.l	(sp)+,d3-d5
	tst.w	d0
	rts

; ---------------------------------------------------------------- input
findmouse:
	movem.l	d3-d7,-(sp)
	bsr	kbd_mouse_status
	tst.b	d0
	beq	.x
	bsr	kbd_mouse_xy
	move.w	d0,d6			; x
	move.w	d1,d7			; y
	cmp.w	#1,d6
	blt	.other
	cmp.w	#21,d6
	bgt	.c2
	moveq	#1,d3			; the scan buttons: rows 21-28, 30-37, 39-46, 48-55, 57-64
	moveq	#21,d0
.sb:	cmp.w	d0,d7
	blt.s	.sn
	move.w	d0,d1
	addq.w	#7,d1
	cmp.w	d1,d7
	ble.s	.sh
.sn:	add.w	#9,d0
	addq.w	#1,d3
	cmp.w	#5,d3
	ble.s	.sb
	cmp.w	#66,d7			; 66..85: done
	blt	.ano
	cmp.w	#85,d7
	bgt	.ano
	st	GS_DONE(a6)
	bra	.ano
.sh:	move.w	d3,d0
	bsr	ex_scankey
	bra	.ano
.c2:	cmp.w	#133,d6
	blt	.other
	cmp.w	#145,d6
	bgt.s	.c3
	cmp.w	#144,d7
	blt	.nz
	cmp.w	#163,d7
	bgt.s	.c21
	bsr	decexplorecursor
	bra	.ano
.c21:	cmp.w	#179,d7
	bgt.s	.c22
	bsr	displayinfogathered
	bra	.ano
.c22:	cmp.w	#198,d7
	bgt	.nz
	bsr	incexplorecursor
	bra	.ano
.c3:	cmp.w	#195,d6
	blt	.other
	cmp.w	#203,d6
	bgt.s	.c4
	cmp.w	#177,d7
	blt	.nz
	cmp.w	#185,d7
	bgt.s	.c31
	bsr	ex_zoomin
	bra	.ano
.c31:	cmp.w	#187,d7
	blt	.nz
	cmp.w	#195,d7
	bgt	.nz
	bsr	ex_zoomout
	bra	.ano
.c4:	cmp.w	#206,d6
	blt	.other
	cmp.w	#265,d6
	bgt	.c5
	cmp.w	#139,d7
	blt	.nz
	cmp.w	#198,d7
	bgt	.nz
	tst.b	ex_showscan		; move the zoom by the click's offset from the centre
	bne	.ano
	bsr	undo
	move.w	d6,d0			; j := round((x-235)/3); i := round((y-168)/3)
	sub.w	#235,d0
	bsr	ex_rnd3
	add.w	d0,ex_zoomx
	move.w	d7,d0
	sub.w	#168,d0
	bsr	ex_rnd3
	add.w	d0,ex_zoomy
	cmp.w	#2,ex_zoomx
	bge.s	.m1
	move.w	#2,ex_zoomx
.m1:	cmp.w	#2,ex_zoomy
	bge.s	.m2
	move.w	#2,ex_zoomy
.m2:	move.w	ex_zoommode,d0
	cmp.w	#1,d0
	bne.s	.m3
	move.w	#178,d1
	move.w	#178,d2
	moveq	#58,d3
	moveq	#58,d4
	bra.s	.mc
.m3:	cmp.w	#2,d0
	bne.s	.m4
	move.w	#207,d1
	move.w	#208,d2
	moveq	#88,d3
	moveq	#88,d4
	bra.s	.mc
.m4:	cmp.w	#3,d0
	bne.s	.md
	move.w	#218,d1
	move.w	#218,d2
	moveq	#98,d3
	moveq	#98,d4
.mc:	cmp.w	ex_zoomx,d1		; if zoomx > a then zoomx := b else if zoomy > c then zoomy := d
	bge.s	.mc2
	move.w	d2,ex_zoomx
	bra.s	.md
.mc2:	cmp.w	ex_zoomy,d3
	bge.s	.md
	move.w	d4,ex_zoomy
.md:	bsr	redraw
	bra	.ano
.c5:	cmp.w	#270,d6
	blt	.other
	cmp.w	#318,d6
	bgt	.other
	cmp.w	#172,d7
	ble	.ano
	bsr	retrieve
	bra	.ano
.other:	; (x 0, 22..132, 146..194, 204..205, 266..269, 319: newzoom)
.nz:	move.w	d6,d0
	move.w	d7,d1
	bsr	newzoom
.ano:	cmp.w	#5,ex_explorelevel	; a click on an anomaly's line: zoom to it
	bne	.x
	tst.b	ex_doneano
	beq	.x
	cmp.w	#5,d6
	blt	.x
	cmp.w	#132,d6
	bgt	.x
	cmp.w	#148,d7
	blt	.x
	cmp.w	#196,d7
	bgt	.x
	move.w	d7,d5			; y := (mouse.y - 148) div 6
	sub.w	#148,d5
	ext.l	d5
	divu	#6,d5
	moveq	#0,d4			; i
	moveq	#1,d3
.aj:	bsr	ex_plan
	move.w	d3,d0
	add.w	d0,d0
	tst.w	PLANET_CACHE-2(a0,d0.w)
	ble.s	.an
	addq.w	#1,d4
	cmp.w	d5,d4
	bne.s	.an
	cmp.w	#1,ex_zoommode
	bne.s	.az
	move.w	#2,ex_zoommode
.az:	lea	ex_itemloc-2,a0		; newzoom(itemloc[j,2]+27, itemloc[j,1]+12)
	move.w	d3,d0
	add.w	d0,d0
	add.w	d0,a0
	moveq	#0,d0
	move.b	1(a0),d0
	add.w	#27,d0
	moveq	#0,d1
	move.b	(a0),d1
	add.w	#12,d1
	bsr	newzoom
	bra.s	.x
.an:	addq.w	#1,d3
	cmp.w	#7,d3
	ble.s	.aj
.x:	movem.l	(sp)+,d3-d7
	rts

; the scan buttons / keys 1-5: queue the scan, or show its data when it is complete
ex_scankey:
	move.w	d0,-(sp)
	lea	ex_dg-4+2,a0
	lsl.w	#2,d0
	cmp.w	#1000,0(a0,d0.w)
	bge.s	.done
	bsr	mousehide
	move.w	(sp),d0
	bsr	setscan
	bsr	displayinfogathered
	bsr	mouseshow
	addq.l	#2,sp
	rts
.done:	move.w	(sp)+,d0
	cmp.w	ex_explorelevel,d0
	beq.s	.x
	cmp.w	#1,d0
	beq	readylithoinfo
	cmp.w	#2,d0
	beq	readyhydroinfo
	cmp.w	#3,d0
	beq	readyatmoinfo
	cmp.w	#4,d0
	beq	readybioinfo
	bra	readyanoinfo
.x:	rts

ex_zoomin:
	tst.b	ex_showscan
	bne.s	.x
	bsr	undo
	move.w	ex_zoommode,d0
	cmp.w	#1,d0
	bne.s	.2
	move.w	#2,ex_zoommode
	add.w	#15,ex_zoomx
	add.w	#15,ex_zoomy
	bra.s	.r
.2:	cmp.w	#2,d0
	bne.s	.r
	tst.b	ex_colorchange
	beq.s	.r
	move.w	#3,ex_zoommode
	addq.w	#5,ex_zoomx
	addq.w	#5,ex_zoomy
.r:	bra	redraw
.x:	rts

ex_zoomout:
	tst.b	ex_showscan
	bne.s	.x
	bsr	undo
	bsr	ex_zoomdown
	bra	redraw
.x:	rts
ex_zoomdown:				; zoommode 2 -> 1, 3 -> 2, with the clamps
	move.w	ex_zoommode,d0
	cmp.w	#2,d0
	bne.s	.3
	sub.w	#15,ex_zoomx
	sub.w	#15,ex_zoomy
	move.w	#178,d1
	moveq	#58,d2
	move.w	#1,ex_zoommode
	bra.s	.c
.3:	cmp.w	#3,d0
	bne.s	.x
	subq.w	#5,ex_zoomx
	subq.w	#5,ex_zoomy
	move.w	#208,d1
	moveq	#88,d2
	move.w	#2,ex_zoommode
.c:	cmp.w	ex_zoomx,d1
	bge.s	.c1
	move.w	d1,ex_zoomx
	bra.s	.c2
.c1:	cmp.w	#1,ex_zoomx
	bge.s	.c2
	move.w	#1,ex_zoomx
.c2:	cmp.w	ex_zoomy,d2
	bge.s	.c3
	move.w	d2,ex_zoomy
	rts
.c3:	cmp.w	#1,ex_zoomy
	bge.s	.x
	move.w	#1,ex_zoomy
.x:	rts

processkey:
	movem.l	d3,-(sp)
	bsr	kbd_readkey
	move.b	d0,d3
	beq	.ext
	cmp.b	#'a',d3			; upcase
	blo.s	.u
	cmp.b	#'z',d3
	bhi.s	.u
	sub.b	#32,d3
.u:	cmp.b	#'+',d3
	bne.s	.m
	bsr	ex_zoomin
	bra	.x
.m:	cmp.b	#'-',d3
	bne.s	.d
	bsr	ex_zoomout
	bra	.x
.d:	cmp.b	#'1',d3
	blt.s	.q
	cmp.b	#'5',d3
	bgt.s	.q
	moveq	#0,d0
	move.b	d3,d0
	sub.w	#48,d0
	bsr	ex_scankey
	bra	.x
.q:	cmp.b	#'Q',d3
	beq.s	.dn
	cmp.b	#27,d3
	beq.s	.dn
	cmp.b	#'X',d3
	bne.s	.r
.dn:	st	GS_DONE(a6)
	bra	.x
.r:	cmp.b	#13,d3
	bne.s	.rb
	bsr	retrieve
	bra	.x
.rb:	cmp.b	#'`',d3			; bossmode (#10 heap stats: not on the ST)
	bne	.x
	bsr	bossmode
	bra	.x
.ext:	bsr	kbd_readkey
	move.b	d0,d3
	cmp.b	#73,d3
	bne.s	.e1
	bsr	decexplorecursor
	bra	.x
.e1:	cmp.b	#81,d3
	bne.s	.e2
	bsr	incexplorecursor
	bra	.x
.e2:	tst.b	ex_showscan
	bne	.x
	move.w	ex_zoomx,d0		; arrows: newzoom from the centre +- 2
	add.w	#28,d0
	add.w	ex_zoomoffset,d0
	move.w	ex_zoomy,d1
	add.w	#13,d1
	add.w	ex_zoomoffset,d1
	cmp.b	#75,d3
	bne.s	.e3
	subq.w	#2,d0
	bra.s	.go
.e3:	cmp.b	#77,d3
	bne.s	.e4
	addq.w	#2,d0
	bra.s	.go
.e4:	cmp.b	#72,d3
	bne.s	.e5
	subq.w	#2,d1
	bra.s	.go
.e5:	cmp.b	#80,d3
	bne.s	.x
	addq.w	#2,d1
.go:	movem.w	d0-d1,-(sp)
	bsr	undo
	movem.w	(sp)+,d0-d1
	bsr	newzoom
.x:	movem.l	(sp)+,d3
	rts

; ---------------------------------------------------------------- the screen
ex_mainloop:
	bsr	mouseshow
	bsr	displayinfogathered
.l:	moveq	#8,d0			; fadestep(FADESTEP_STEP)
	bsr	fadestep
	bsr	findmouse
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	processkey
.nk:	bsr	controlprobes
	cmp.w	#8,ex_batindex
	bge.s	.b0
	addq.w	#1,ex_batindex
	bra.s	.g
.b0:	clr.w	ex_batindex
	bsr	addtime2
.g:	move.w	ex_batindex,d2		; setrgb256(235, 0, min(batindex*8, 63), 0)
	lsl.w	#3,d2
	cmp.w	#63,d2
	ble.s	.g2
	moveq	#63,d2
.g2:	move.w	#235,d0
	moveq	#0,d1
	move.l	d3,-(sp)
	moveq	#0,d3
	bsr	vid_setrgb
	move.l	(sp)+,d3
	bsr	showzoom
	bsr	controlprobes
	move.w	GS_TSLICE(a6),d0	; delay(tslice*FADE_TSLICE_MUL_EXPLORE)
	add.w	d0,d0
	bsr	delay
	tst.b	GS_DONE(a6)
	beq.s	.l
	st	GS_ANYCHANGE(a6)
	rts

; utils.pas addtime2
addtime2:
	cmp.w	#16000,GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6)
	bge.s	.t
	bsr	ut_movewandering
.t:	st	d0
	moveq	#1,d1
	bra	gametick

; utils.pas movewandering / adjustwanderer (the screens' own copies, used by addtime2: no
; drifting for WNDORDER_NONE; a ship that comes close ends the screen (done) instead of combat)
ut_movewandering:
	move.w	GS_ACTION(a6),d0
	cmp.w	#WNDACT_RETREAT,d0
	beq.s	.r
	cmp.w	#WNDACT_ATTACK,d0
	bne.s	.o
	bsr.s	.ofs
	bsr	ut_adjustwanderer
	bra.s	.o
.r:	bsr.s	.ofs
	neg.w	d0
	bsr	ut_adjustwanderer
.o:	move.w	GS_SHIP+SHIP_WANDERING+ONEALIEN_ORDERS(a6),d0
	cmp.w	#WNDORDER_ATTACK,d0
	bne.s	.o2
	cmp.w	#WNDACT_MASKING,GS_ACTION(a6)
	bne.s	.a30
	moveq	#12,d0			; 5-random(12)
	bsr	mt_random
	neg.w	d0
	addq.w	#5,d0
	bra	ut_adjustwanderer
.a30:	moveq	#30,d0
	bra	ut_adjustwanderer
.o2:	cmp.w	#WNDORDER_RETREAT,d0
	bne.s	.x
	moveq	#-70,d0
	cmp.w	#WNDACT_MASKING,GS_ACTION(a6)
	bne	ut_adjustwanderer
	moveq	#-50,d0
	bra	ut_adjustwanderer
.x:	rts
.ofs:	move.w	GS_SHIP+SHIP_ACCELMAX(a6),d0	; (accelmax div 4)*(100-dmg) / 100, banker's
	ext.l	d0
	divs	#4,d0
	moveq	#100,d1
	sub.b	GS_SHIP+SHIP_DAMAGES+DMG_ENGINES-1(a6),d1
	and.w	#$ff,d1
	muls	d1,d0
	move.l	d0,d1
	bpl.s	.op
	neg.l	d1
.op:	divu	#100,d1
	move.l	d1,d2
	swap	d2
	cmp.w	#50,d2
	blo.s	.ot
	bhi.s	.ou
	btst	#0,d1
	beq.s	.ot
.ou:	addq.w	#1,d1
.ot:	tst.l	d0
	bpl.s	.os
	neg.w	d1
.os:	move.w	d1,d0
	rts

ut_adjustwanderer:
	movem.l	d3/a3,-(sp)
	move.w	d0,d3
	lea	GS_SHIP+SHIP_WANDERING(a6),a3
	cmp.w	#16000,ONEALIEN_ALIENID(a3)
	bgt	.x
	lea	ONEALIEN_RELX(a3),a0
	moveq	#3-1,d2
.c:	move.w	(a0),d0
	move.w	d0,d1
	bpl.s	.p
	neg.w	d1
.p:	cmp.w	#499,d1
	ble.s	.n
	tst.w	d0
	bpl.s	.m
	add.w	d3,(a0)
	bra.s	.n
.m:	sub.w	d3,(a0)
.n:	addq.l	#2,a0
	dbf	d2,.c
	lea	ONEALIEN_RELX(a3),a0	; all within 500: done
	moveq	#3-1,d2
.cl:	move.w	(a0)+,d0
	bpl.s	.cp
	neg.w	d0
.cp:	cmp.w	#500,d0
	bge.s	.far
	dbf	d2,.cl
	st	GS_DONE(a6)
	bra.s	.x
.far:	lea	ONEALIEN_RELX(a3),a0	; any beyond 23000: gone
	moveq	#3-1,d2
.fl:	move.w	(a0)+,d0
	bpl.s	.fp
	neg.w	d0
.fp:	cmp.w	#23000,d0
	bgt.s	.gone
	dbf	d2,.fl
	bra.s	.x
.gone:	move.w	#20000,ONEALIEN_ALIENID(a3)
	cmp.w	#WNDACT_RETREAT,GS_ACTION(a6)
	bne.s	.na
	moveq	#4,d0			; showchar(4, 'Evasion successful!')
	lea	.ev,a0
	bsr	showchar
.na:	clr.w	GS_ACTION(a6)
.x:	movem.l	(sp)+,d3/a3
	rts
.ev:	dc.b	19,"Evasion successful!"
	even

ex_readydata:
	movem.l	d3-d7/a3,-(sp)
	move.w	#-1,ex_explorelevel
	SETC	47
	sf	GS_DONE(a6)
	sf	ex_donescan
	sf	ex_showscan
	sf	ex_doneano
	TCOL	207
	BKCOL	0
	clr.w	ex_batindex
	bsr	ex_plan
	move.w	#ID_PROBOT,d0
	cmp.b	#7,PLANET_STATE(a0)
	bne.s	.pb
	move.w	#ID_STARDIVER,d0
.pb:	bsr	incargo
	cmp.w	#4,d0
	ble.s	.p4
	moveq	#4,d0
.p4:	move.w	d0,ex_numprobes
	moveq	#0,d0			; compressfile(current)
	bsr	ms_snap
	moveq	#-8,d0			; fadestopmod(-FADEFULL_STEP, FADEFULL_DELAY)
	moveq	#20,d1
	bsr	fadestopmod
	bsr	orc_dump		; loadscreen(landform)
	lea	ex_mode,a0
	bsr	ms_load
	bcs	fatal
	lea	ex_fn_mod,a0		; playmod(true, PROBE.MOD)
	bsr	playmod
	bsr	setcolors
	bsr	generatescanlist
	moveq	#1,d3			; itemloc[j] := random(60)+30, random(180)+30 (not marked)
.il:	lea	ex_itemloc-2,a3
	move.w	d3,d0
	add.w	d0,d0
	add.w	d0,a3
	moveq	#60,d0
	bsr	mt_random
	add.w	#30,d0
	move.b	d0,(a3)
	move.w	#180,d0
	bsr	mt_random
	add.w	#30,d0
	move.b	d0,1(a3)
	addq.w	#1,d3
	cmp.w	#7,d3
	ble.s	.il
	lea	ex_probes+PR_STATUS,a0
	moveq	#4-1,d0
.ps:	clr.w	(a0)
	lea	PR_SIZE(a0),a0
	dbf	d0,.ps
	lea	ex_pitem,a0		; (1994 probes: none sent for anomalies, none carrying)
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	sf	ex_pickup
	bsr	ex_plan			; datagathered from the planet's notes
	move.b	PLANET_NOTES(a0),d4
	lea	ex_dg,a1
	moveq	#1,d3
.dg:	move.w	d3,d0
	addq.w	#1,d0
	moveq	#0,d1
	btst	d0,d4
	beq.s	.dg0
	move.w	#1000,d1
.dg0:	move.w	d1,(a1)+
	move.w	d1,(a1)+
	addq.w	#1,d3
	cmp.w	#5,d3
	ble.s	.dg
	cmp.w	#1000,ex_dg+4*4+2
	blt.s	.nd
	st	ex_doneano
.nd:	lea	ex_icons,a3		; probeicons^[j, i] := screen[i+j*40-26, 281..312]
	moveq	#1,d3
.pi:	moveq	#1,d4
.pi2:	move.w	#281,d0
	move.w	d3,d1
	mulu	#40,d1
	sub.w	#26,d1
	add.w	d4,d1
	bsr	ms_addr
	moveq	#32-1,d0
.pi3:	move.b	(a0)+,(a3)+
	dbf	d0,.pi3
	addq.w	#1,d4
	cmp.w	#26,d4
	ble.s	.pi2
	addq.w	#1,d3
	cmp.w	#4,d3
	ble.s	.pi
	moveq	#1,d3			; the probes on board: icon 2
.pd:	cmp.w	ex_numprobes,d3
	bgt.s	.pde
	moveq	#2,d0
	move.w	d3,d1
	bsr	ex_icon
	addq.w	#1,d3
	bra.s	.pd
.pde:	move.w	ex_numprobes,d5		; the empty bays: (j = numprobes after the loop)
	cmp.w	#4,d5
	bge.s	.pe
	addq.w	#1,d5
.pe1:	move.w	#281,d0			; scr_fillchar(screen[i+a*40-26, 281], 31, 0), i = 1..26
	move.w	d5,d1
	mulu	#40,d1
	sub.w	#25,d1
	move.w	#311,d2
	move.w	d1,d3
	add.w	#25,d3
	moveq	#0,d4
	bsr	ms_bar
	addq.w	#1,d5
	cmp.w	#4,d5
	ble.s	.pe1
.pe:	lea	ex_msgs,a3		; msgs^[j, i-20] := screen[i, j*20+10 ..+15], i = 20..27
	moveq	#1,d3
.mg:	moveq	#20,d4
.mg2:	move.w	d3,d0
	mulu	#20,d0
	add.w	#10,d0
	move.w	d4,d1
	bsr	ms_addr
	moveq	#16-1,d0
.mg3:	move.b	(a0)+,(a3)+
	dbf	d0,.mg3
	addq.w	#1,d4
	cmp.w	#27,d4
	ble.s	.mg2
	addq.w	#1,d3
	cmp.w	#7,d3
	ble.s	.mg
	clr.w	ex_que
	moveq	#0,d0
	bsr	setscan
	BAR	28,13,267,133,0
	tst.b	ex_colorchange		; no zoom x3 without colours
	bne.s	.zc
	cmp.w	#3,ex_zoommode
	bne.s	.zc
	bsr	ex_zoomdown		; (zoommode 3 -> 2, as the '-' key)
.zc:	bsr	ex_tables
	bsr	fadein
	bsr	displaylandform
	bsr	redraw
	bsr	showzoom
	movem.l	(sp)+,d3-d7/a3
	rts

ex_removedata:
	bsr	mousehide
	moveq	#-8,d0			; fadestopmod(-FADEFULL_STEP, FADEFULL_DELAY)
	moveq	#20,d1
	bsr	fadestopmod
	bsr	orc_dump		; loadscreen(cloud, backgr)
	lea	u2_cloud,a0
	move.l	GS_BACKGR(a6),a1
	bsr	loadchk
	bsr	orc_dump		; loadscreen(current)
	moveq	#0,d0
	bsr	ms_unsnap
	bsr	gp_extras		; an asteroid field / a cloud in backgr again
	st	GS_ANYCHANGE(a6)
	bsr	showtime
	moveq	#0,d0
	bsr	displaytextbox
	cmp.w	#11,GS_VIEWMODE(a6)
	bne.s	.x
	cmp.w	#2,GS_VIEWLEVEL(a6)
	bne.s	.x
	moveq	#6,d0
	bsr	displaybotinfo
.x:	rts

exploreplanet:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	computebiostuff
	cmp.w	#4,ex_techlvl
	bne.s	.t5
	cmp.w	#2,ex_tl2
	bge.s	.shield
.t5:	cmp.w	#4,ex_techlvl
	ble.s	.go
.shield:
	bsr	println
	TCOL	95
	PRT	"SCIENCE: Probes cannot penetrate planetary shield."
	bra	.x
.go:	bsr	mousehide
	bsr	ex_readydata
	bsr	ex_mainloop
	moveq	#1,d7			; 1994 probes: what is on its way home is kept
.pc:	bsr	ex_pslot
	move.w	8(a0),d0
	beq.s	.pn
	clr.w	8(a0)
	st	d1
	bsr	addcargo2
.pn:	addq.w	#1,d7
	cmp.w	#4,d7
	ble.s	.pc
	bsr	ex_removedata
	bsr	mouseshow
	bsr	ex_plan
	move.l	a0,a3
	move.b	PLANET_NOTES(a3),d0
	and.b	#125,d0
	beq.s	.x
	moveq	#11,d0
	bsr	chevent
	tst.w	d0
	bne.s	.e1
	moveq	#11,d0
	bra.s	.ev
.e1:	moveq	#0,d1
	move.b	PLANET_SYSTEM(a3),d1
	move.w	#19,d0
	cmp.w	#164,d1
	beq.s	.ev
	cmp.w	#45,d1
	bne.s	.e2
	tst.b	PLANET_ORBIT(a3)
	beq.s	.e45
	moveq	#28,d0
	bra.s	.ev
.e2:	moveq	#15,d0
	cmp.w	#31,d1
	beq.s	.ev
	moveq	#42,d0
	cmp.w	#28,d1
	beq.s	.ev
	moveq	#49,d0
	cmp.w	#123,d1
	beq.s	.ev
	bra.s	.x
.e45:	moveq	#28,d0
	bsr	chevent
	tst.w	d0
	beq.s	.x
	move.w	#1103,d0
.ev:	bsr	event
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; ---------------------------------------------------------------- data
	section	data
ex_mode:	dc.b	"LAND",0
ex_fn_mod:	dc.b	"SOUND",92,"PROBE.MOD",0
ex_fn_elem:	dc.b	"DATA",92,"ELEMENTS.DTA",0
	even
ex_zoommode:	dc.w	1		; (the unit's initialisation: zoommode := 1; zoomx := 1; zoomy := 1)
ex_zoomx:	dc.w	1
ex_zoomy:	dc.w	1
ex_probetext:				; string[9] each (10 bytes)
	dc.b	9,"   Docked"
	dc.b	9," Deployed"
	dc.b	9," Orbiting"
	dc.b	9,"Gathering"
	dc.b	9,"Analyzing"
	dc.b	9,"Returning"
	dc.b	9,"Refueling"
	dc.b	9,"Destroyed"
	dc.b	9,"   Docked"
ex_scantypes:				; string[13] each (14 bytes)
	dc.b	13,"Lithosphere.."
	dc.b	13,"Hydrosphere.."
	dc.b	13,"Atmosphere..."
	dc.b	13,"Biosphere...."
	dc.b	13,"Anomaly......"
ex_activity:				; string[8] each (9 bytes)
	dc.b	8,"    Calm"
	dc.b	8,"    Mild"
	dc.b	8,"Moderate"
	dc.b	8,"   Heavy"
	dc.b	8," Massive"
ex_temps:				; 10 bytes each
	dc.b	9,"Subarctic"
	dc.b	6,"Arctic   "
	dc.b	4,"Cold     "
	dc.b	4,"Cool     "
	dc.b	8,"Moderate "
	dc.b	4,"Warm     "
	dc.b	8,"Tropical "
	dc.b	7,"Searing  "
ex_t_infernal:	dc.b	8,"Infernal"
ex_states:				; 14 bytes each
	dc.b	7,"Gaseous      "
	dc.b	6,"Active       "
	dc.b	6,"Stable       "
	dc.b	10,"Early Life   "
	dc.b	13,"Advanced Life"
	dc.b	5,"Dying        "
	dc.b	4,"Dead         "
ex_stars:
	dc.b	8,"Red Star     "
	dc.b	11,"Yellow Star  "
	dc.b	10,"White Star   "
ex_diets:				; 16 bytes each: the word + ' '
	dc.b	12,"Carnivorous    "
	dc.b	12,"Herbivorous    "
	dc.b	11,"Omnivorous     "
	dc.b	14,"Cannibalistic  "
	dc.b	15,"Photosynthetic "
ex_cells:				; 12 bytes each
	dc.b	7,"Chaosms    "
	dc.b	8,"Communes   "
	dc.b	11,"Hierarchies"
ex_t_single:	dc.b	13,"Singlecelled "
ex_t_none:	dc.b	4,"None"
ex_t_heavy:	dc.b	5,"Heavy"
ex_t_massive:	dc.b	7,"Massive"
ex_t_mild:	dc.b	4,"Mild"
ex_t_moderate:	dc.b	8,"Moderate"
ex_t_calm:	dc.b	4,"Calm"
ex_t_atm:	dc.b	4," Atm"
ex_t_g:		dc.b	2," G"
ex_t_pc:	dc.b	1,"%"
ex_t_pct:	dc.b	2,"% "
ex_t_other:	dc.b	7,"% Other"
ex_t_rad:	dc.b	7," RAD/Yr"
ex_t_000:	dc.b	3,"000"
ex_t_million:	dc.b	8," Million"
ex_t_billion:	dc.b	8," Billion"
ex_t_trillion:	dc.b	9," Trillion"
ex_t_hyd:	dc.b	8,"Hydrogen"
ex_t_hel:	dc.b	6,"Helium"
ex_t_oth:	dc.b	5,"Other"
ex_t_completed:	dc.b	10,"Completed."
ex_t_litho:	dc.b	16,"Lithosphere Data"
ex_t_hydro:	dc.b	16,"Hydrosphere Data"
ex_t_atmo:	dc.b	15,"Atmosphere Data"
ex_t_cfull:	dc.b	12,"Cargo full! "
ex_t_used:	dc.b	6," used."
ex_t_busy:	dc.b	20,"All probes are busy."
	even

	section	bss
ex_lc:		ds.b	LC_SIZE		; landcolors^ (kept between explorations, as the original's)
	even
ex_sumpic:	ds.b	LC_SIZE		; summarypic^
	even
ex_scaninfo:	ds.b	52*SCAN_SIZE
ex_tempzoom:	ds.b	3600
ex_zoomscr:	ds.b	3600
ex_msgs:	ds.b	7*MSG_SIZE
ex_icons:	ds.b	4*ICON_SIZE
ex_zlut:	ds.w	256
ex_llut:	ds.w	256
ex_probes:	ds.b	4*PR_SIZE
ex_dg:		ds.w	10		; datagathered[1..5, 1..2]
ex_part:	ds.l	2
ex_partl:	ds.l	2
ex_part2:	ds.l	2
ex_angle:	ds.l	2
ex_grav:	ds.l	2
ex_atm:		ds.l	2
ex_a1:		ds.l	2
ex_a2:		ds.l	2
ex_val:		ds.l	2
ex_pop:		ds.l	1
ex_tmp:		ds.w	6
ex_itemloc:	ds.b	14
ex_amounts:	ds.b	17
ex_amounts2:	ds.b	17
ex_already:	ds.b	10
	even
ex_str:		ds.b	256
ex_str2:	ds.b	256
ex_water:	ds.w	1
ex_waterindex:	ds.w	1
ex_gindex:	ds.w	1
ex_g2index:	ds.w	1
ex_zoomoffset:	ds.w	1
ex_batindex:	ds.w	1
ex_que:		ds.w	1
ex_pitem:	ds.w	4		; 1994 probes: the cache index each probe is sent for
ex_pcarry:	ds.w	4		; (= ex_pitem+8) the item it carries home
ex_holdcopy:	ds.b	1000		; ship.cargo + numcargo while ex_fetch tries the fit
ex_pickup:	ds.b	1
	even
ex_explorelevel: ds.w	1
ex_explorecur:	ds.w	1
ex_numprobes:	ds.w	1
ex_index:	ds.w	1
ex_techlvl:	ds.w	1
ex_tl2:		ds.w	1
ex_biostuff:	ds.w	1
ex_cargindex:	ds.w	1
ex_total:	ds.w	1
ex_colorchange:	ds.b	1
ex_donescan:	ds.b	1
ex_showscan:	ds.b	1
ex_doneano:	ds.b	1
ex_dirty:	ds.b	1
	even
ex_sq:		ds.w	1
ex_spt:		ds.l	4*120	; ex_sprinkle's rows: planar, shadow + 28, LUT, picture
ex_sxt:		ds.w	2*240	; and columns: group offset, bit
ex_sum:		ds.b	1
	even
	section	text

	section	data
ex_t_noslot1:	dc.b	54,"No cargo slot available.  Some cargo should be dumped."
ex_t_noslot2:	dc.b	14,"Can not store."
	even
	section	text
