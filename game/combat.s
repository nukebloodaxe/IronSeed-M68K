; combat.s - combat.pas for MAIN.PRG: battle with an alien fleet (an attacking ship came within
; 500 km, journey.pas adjustwanderer). The radar map of the ships (xor marks), the target's
; picture or damage bars, ten gun nodes powering up and firing (by click, key or auto fire),
; the ships' own charges and hits, shields, the ship's direction, zoom, scanning, the
; colour-chasing radar ellipse; afterwards the victory (scavenger bots) or the death sequence.
; Mode FIGHT (tools/mkmain.py).
;
; initiatecombat                                        trashes: d0-d2/a0-a2

MAXSHIPS	equ	25
SHIPREC		equ	ALIENSHIP_SIZEOF

	section	text
; a0 = ships^[d0] (1-based)
cb_ship:
	subq.w	#1,d0
	mulu	#SHIPREC,d0
	move.l	cb_ships,a0
	add.l	d0,a0
	rts
; a0 = weapons[d0] (1-based)
cb_weap:
	subq.w	#1,d0
	mulu	#WEAPON_SIZEOF,d0
	lea	GS_WEAPONS(a6),a0
	add.l	d0,a0
	rts

; r (a double at a0) := sqrt(sqr(relx/10)+sqr(rely/10)+sqr(relz/10))*100 for the ship at a1
; Speed: the result only depends on relx/y/z (ships move every 8th pass), so the last 8 are kept
; (cb_rcache: relx, rely, relz, the double) - the same double the FPU steps would give.
cb_range:
	movem.l	a3-a4,-(sp)
	move.l	a0,a4
	move.l	a1,a3
	lea	cb_rcache,a0		; a hit: copy the double
	moveq	#8-1,d1
.h:	move.l	ALIENSHIP_RELX(a3),d0
	cmp.l	(a0),d0
	bne.s	.hn
	move.l	ALIENSHIP_RELY(a3),d0
	cmp.l	4(a0),d0
	bne.s	.hn
	move.l	ALIENSHIP_RELZ(a3),d0
	cmp.l	8(a0),d0
	bne.s	.hn
	tst.b	20(a0)			; (a valid entry)
	beq.s	.hn
	move.l	12(a0),(a4)
	move.l	16(a0),4(a4)
	FSSE
	movem.l	(sp)+,a3-a4
	rts
.hn:	lea	22(a0),a0
	dbf	d1,.h
	bsr.s	.calc
	move.w	cb_rnext,d0		; keep it: round robin
	addq.w	#1,cb_rnext
	and.w	#7,d0
	mulu	#22,d0
	lea	cb_rcache,a0
	add.w	d0,a0
	move.l	ALIENSHIP_RELX(a3),(a0)+
	move.l	ALIENSHIP_RELY(a3),(a0)+
	move.l	ALIENSHIP_RELZ(a3),(a0)+
	move.l	(a4),(a0)+
	move.l	4(a4),(a0)+
	st	(a0)
	movem.l	(sp)+,a3-a4
	rts
.calc:	FSSE
	move.l	ALIENSHIP_RELX(a3),d0
	bsr	.sq
	move.l	ALIENSHIP_RELY(a3),d0
	bsr	.sq
	bsr	fp_add
	move.l	ALIENSHIP_RELZ(a3),d0
	bsr	.sq
	bsr	fp_add
	bsr	fp_sqrt
	FLDI	100
	bsr	fp_mul
	move.l	a4,a0
	bra	fp_std
.sq:	bsr	fp_ldi			; sqr(v/10)
	FLDI	10
	bsr	fp_div
	bsr	fp_sqr
	rts

; d0 := round(d0.w * a / b) as FPC's SSE: (d0 / b) * a  -- for the bars: round(v/max*49) etc.
; in: d0.w v, d1.w max, d2.w scale  out: d0.w
cb_ratio:
	movem.w	d1-d2,-(sp)
	FSSE
	bsr	fp_ldw
	move.w	(sp),d0
	bsr	fp_ldw
	bsr	fp_div
	move.w	2(sp),d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	addq.l	#4,sp
	rts

; one bar of the stats tower: stats[k] at column d1 for the value part (a double at cb_part)
; (displaystats)
cb_statbar:
	movem.l	d3-d5,-(sp)
	move.w	d0,d3			; k (1-3)
	move.w	d1,d4			; column
	lea	cb_part,a0
	bsr	fp_ldd
	bsr	fp_rnd
	move.w	d0,d5			; round(part)
	lea	cb_stats-1,a0
	moveq	#0,d0
	move.b	0(a0,d3.w),d0
	cmp.w	d0,d5
	beq.s	.x
	move.w	#117,d1			; blank at 117-stats[k]
	sub.w	d0,d1
	lea	cb_blank,a1
	bsr	.put
	lea	cb_stats-1,a0
	move.b	d5,0(a0,d3.w)
	move.w	#117,d1			; statpic at 117-round(part)
	sub.w	d5,d1
	move.w	d1,GS_Y(a6)
	lea	cb_statpic,a1
	bsr	.put
.x:	movem.l	(sp)+,d3-d5
	rts
.put:	moveq	#2-1,d2			; two rows of 10 bytes (the picture rows are 12 wide)
.r:	move.w	d4,d0
	movem.l	d1-d2/a1,-(sp)
	bsr	ms_addr
	movem.l	(sp)+,d1-d2/a1
	moveq	#10-1,d0
.c:	move.b	(a1)+,(a0)+
	dbf	d0,.c
	addq.l	#2,a1
	movem.l	d1-d2/a1,-(sp)
	move.w	d4,d0
	move.w	d4,d2
	add.w	#9,d2
	move.w	d3,-(sp)
	move.w	d1,d3
	bsr	ms_dirty
	move.w	(sp)+,d3
	movem.l	(sp)+,d1-d2/a1
	addq.w	#1,d1
	dbf	d2,.r
	rts

cb_displaystats:
	tst.b	cb_done
	bne	.x
	lea	cb_dskey,a0		; (speed: the same hull, battery, shields and stats as the last
	move.w	GS_SHIP+SHIP_HULLMAX(a6),d0	; pass: nothing to redraw, part as it left it)
	cmp.w	(a0)+,d0
	bne.s	.go
	move.w	GS_SHIP+SHIP_HULLINTEGRITY(a6),d0
	cmp.w	(a0)+,d0
	bne.s	.go
	move.w	GS_SHIP+SHIP_BATTERY(a6),d0
	cmp.w	(a0)+,d0
	bne.s	.go
	move.w	GS_SHIP+SHIP_SHIELDLEVEL(a6),d0
	cmp.w	(a0)+,d0
	bne.s	.go
	move.l	cb_stats,d0		; (stats[1..3] as left by that pass)
	cmp.l	(a0),d0
	bne.s	.go
	move.l	cb_dspart,cb_part	; part := 102/100*shieldlevel as that pass left it (the unit's
	move.l	cb_dspart+4,cb_part+4	; global: moveships reads it after impact's displaystats)
	rts
.go:	bsr	mousehide
	FSSE				; part := 102/hullmax*hullintegrity
	FLDI	102
	move.w	GS_SHIP+SHIP_HULLMAX(a6),d0
	bsr	fp_ldw
	bsr	fp_div
	move.w	GS_SHIP+SHIP_HULLINTEGRITY(a6),d0
	bsr	fp_ldw
	bsr	fp_mul
	lea	cb_part,a0
	bsr	fp_std
	moveq	#1,d0
	move.w	#269,d1
	bsr	cb_statbar
	FLDI	102			; part := 102/32000*battery (a constant: 102/32000)
	FLDI	32000
	bsr	fp_div
	move.w	GS_SHIP+SHIP_BATTERY(a6),d0
	bsr	fp_ldw
	bsr	fp_mul
	lea	cb_part,a0
	bsr	fp_std
	moveq	#2,d0
	move.w	#285,d1
	bsr	cb_statbar
	FLDI	102			; part := 102/100*shieldlevel
	FLDI	100
	bsr	fp_div
	move.w	GS_SHIP+SHIP_SHIELDLEVEL(a6),d0
	bsr	fp_ldw
	bsr	fp_mul
	lea	cb_part,a0
	bsr	fp_std
	move.l	cb_part,cb_dspart
	move.l	cb_part+4,cb_dspart+4
	moveq	#3,d0
	move.w	#301,d1
	bsr	cb_statbar
	lea	cb_dskey,a0		; the inputs and stats of this pass
	move.w	GS_SHIP+SHIP_HULLMAX(a6),(a0)+
	move.w	GS_SHIP+SHIP_HULLINTEGRITY(a6),(a0)+
	move.w	GS_SHIP+SHIP_BATTERY(a6),(a0)+
	move.w	GS_SHIP+SHIP_SHIELDLEVEL(a6),(a0)+
	move.l	cb_stats,(a0)
	bsr	mouseshow
.x:	rts

; part := 102/100*d0; d0 := 114 - round(part) (the shield markers' rows)
cb_shrow:
	FSSE
	move.w	d0,-(sp)
	FLDI	102
	FLDI	100
	bsr	fp_div
	move.w	(sp)+,d0
	bsr	fp_ldw
	bsr	fp_mul
	lea	cb_part,a0
	bsr	fp_std
	lea	cb_part,a0
	bsr	fp_ldd
	bsr	fp_rnd
	neg.w	d0
	add.w	#114,d0
	rts

; displayshieldpic(n d0)
cb_displayshieldpic:
	movem.l	d3-d4,-(sp)
	move.w	d0,d3
	bsr	mousehide
	cmp.w	#ID_NOSHIELD,GS_SHIP+SHIP_SHIELD(a6)
	bgt.s	.s1
	moveq	#0,d3			; no shield
	clr.b	GS_SHIP+SHIP_SHIELDOPT+SHLD_COMBAT_WANT-1(a6)
	bra.s	.s2
.s1:	cmp.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)
	bne.s	.s2
	moveq	#100,d3
	sub.b	GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6),d3
	and.w	#$ff,d3
.s2:	moveq	#0,d0			; the old marker off: 7 rows of 4 in 0 at 312
	move.b	GS_SHIP+SHIP_SHIELDOPT+SHLD_COMBAT_WANT-1(a6),d0
	bsr	cb_shrow
	move.w	d0,d4
	moveq	#7-1,d2
.c:	move.w	#312,d0
	move.w	d4,d1
	movem.w	d2,-(sp)
	bsr	ms_addr
	movem.w	(sp)+,d2
	clr.l	(a0)			; (312 is even; 4 bytes)
	addq.w	#1,d4
	dbf	d2,.c
	moveq	#100,d0			; n := min(n, 100-damages[shield])
	sub.b	GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6),d0
	ext.w	d0
	and.w	#$ff,d0
	cmp.w	d0,d3
	ble.s	.n
	move.w	d0,d3
.n:	move.b	d3,GS_SHIP+SHIP_SHIELDOPT+SHLD_COMBAT_WANT-1(a6)
	move.w	d3,d0
	bsr	cb_shrow
	move.w	d0,d4
	lea	cb_shieldpic,a1
	moveq	#7-1,d2
.p:	move.w	#312,d0
	move.w	d4,d1
	movem.l	d2/a1,-(sp)
	bsr	ms_addr
	movem.l	(sp)+,d2/a1
	move.l	(a1)+,(a0)
	addq.w	#1,d4
	dbf	d2,.p
	move.w	#312,d0			; (the whole column marked)
	moveq	#0,d1
	move.w	#315,d2
	move.w	#122,d3
	bsr	ms_dirty
	bsr	mouseshow
	movem.l	(sp)+,d3-d4
	rts

cb_displaytargetinfo2:
	movem.l	d3-d7/a3,-(sp)
	bsr	cb_tmemo_clr
	bsr	mousehide
	move.w	cb_target,d0
	bsr	cb_ship
	move.l	a0,a3
	lea	cb_alienname,a0
	moveq	#4,d0
	moveq	#125,d1
	bsr	printxy
	bsr	cb_classline		; shipclass[b] + ' ' + chr(64+targetindex) at (4, 131)
	moveq	#4,d0
	move.w	#131,d1
	lea	cb_s,a0
	bsr	printxy
	lea	cb_r,a0			; 'Range: ' + str(r:8:1) + ' KM'
	bsr	fp_ldd
	moveq	#8,d0
	moveq	#1,d1
	lea	cb_s2,a0
	bsr	fp_str
	cmp.b	#8,cb_s2		; (str1: string[8])
	bls.s	.r8
	move.b	#8,cb_s2
.r8:	lea	cb_s,a0
	lea	.rng,a1
	bsr	pstr_cpy
	lea	cb_s,a0
	lea	cb_s2,a1
	bsr	pstr_cat
	lea	cb_s,a0
	lea	.km,a1
	bsr	pstr_cat
	moveq	#4,d0
	move.w	#137,d1
	lea	cb_s,a0
	bsr	printxy
	lea	cb_s,a0			; 'Tech Level: h.l'
	lea	.tl,a1
	bsr	pstr_cpy
	lea	cb_s,a0
	move.w	ALIENSHIP_TECHLEVEL(a3),d0
	moveq	#0,d1
	move.b	(a0),d1
	add.b	#3,(a0)
	move.w	d0,d2
	lsr.w	#8,d2
	add.b	#'0',d2
	move.b	d2,1(a0,d1.w)
	move.b	#'.',2(a0,d1.w)
	add.b	#'0',d0
	move.b	d0,3(a0,d1.w)
	moveq	#4,d0
	move.w	#143,d1
	bsr	printxy
	move.w	ALIENSHIP_ACCELMAX(a3),d0	; 'Accel: ' + str(accelmax)
	ext.l	d0
	moveq	#0,d1
	lea	cb_s2,a0
	bsr	int_str
	lea	cb_s,a0
	lea	.ac,a1
	bsr	pstr_cpy
	lea	cb_s,a0
	lea	cb_s2,a1
	bsr	pstr_cat
	moveq	#4,d0
	move.w	#149,d1
	lea	cb_s,a0
	bsr	printxy
	moveq	#5,d6			; j: 10 for picx > 139, else 5 (words of 4 bytes)
	cmp.w	#139,ALIENSHIP_PICX(a3)
	ble.s	.j5
	moveq	#10,d6
.j5:	moveq	#20,d7			; a: 19 for picy >= 179, else 20
	cmp.w	#179,cb_picy
	blt.s	.a20
	moveq	#19,d7
.a20:	move.w	d7,cb_a
	moveq	#0,d3			; rows i := 0..a: backgr^[i+picy, picx] -> screen[161+i, 14], j*4 bytes
.r:	move.w	d3,d0
	add.w	cb_picy,d0
	mulu	#320,d0
	add.w	ALIENSHIP_PICX(a3),d0
	move.l	GS_BACKGR(a6),a1
	add.l	d0,a1
	moveq	#14,d0
	move.w	d3,d1
	add.w	#161,d1
	bsr	ms_addr
	move.w	d6,d0
	lsl.w	#2,d0
	subq.w	#1,d0
.c:	move.b	(a1)+,(a0)+
	dbf	d0,.c
	addq.w	#1,d3
	cmp.w	d7,d3
	ble.s	.r
	cmp.w	#5,d6
	bne.s	.m
	BAR	34,161,53,180,0
.m:	move.w	#14,d0
	move.w	#161,d1
	move.w	#53,d2
	move.w	#181,d3
	bsr	ms_dirty
	moveq	#60,d4			; the message blocks: random frames at x 60, 70 (0-1) and 80 (2-3)
	moveq	#0,d5
	bsr.s	.msg
	moveq	#70,d4
	moveq	#0,d5
	bsr.s	.msg
	moveq	#80,d4
	moveq	#2,d5
	bsr.s	.msg
	bsr	mouseshow
	movem.l	(sp)+,d3-d7/a3
	rts
.msg:	moveq	#0,d3			; j := 0, 1
.mj:	moveq	#2,d0
	bsr	mt_random
	add.w	d5,d0
	move.w	d0,cb_a
	mulu	#100,d0
	lea	cb_msgs,a1
	add.w	d0,a1
	moveq	#0,d7			; i
.mi:	move.w	d4,d0
	move.w	d3,d1
	mulu	#10,d1
	add.w	#162,d1
	add.w	d7,d1
	bsr	ms_addr
	moveq	#10-1,d0
.mc:	move.b	(a1)+,(a0)+
	dbf	d0,.mc
	addq.w	#1,d7
	cmp.w	#10,d7
	bne.s	.mi
	addq.w	#1,d3
	cmp.w	#2,d3
	bne.s	.mj
	move.w	d4,d0
	moveq	#9,d2
	add.w	d0,d2
	move.w	#162,d1
	move.w	d3,-(sp)
	move.w	#181,d3
	bsr	ms_dirty
	move.w	(sp)+,d3
	rts
.rng:	dc.b	7,"Range: "
.km:	dc.b	3," KM"
.tl:	dc.b	12,"Tech Level: "
.ac:	dc.b	7,"Accel: "
	even

; cb_s := shipclass[b] + ' ' + chr(64+targetindex) for the target (a3)
cb_classline:
	move.w	ALIENSHIP_MAXHULL(a3),d0	; b := maxhull div 100, or (maxhull-1000) div 1600 + 9
	cmp.w	#1000,d0
	bge.s	.b2
	ext.l	d0
	divs	#100,d0
	bra.s	.b
.b2:	sub.w	#1000,d0
	ext.l	d0
	divs	#1600,d0
	add.w	#9,d0
.b:	move.w	d0,cb_b
	mulu	#15,d0
	lea	cb_classes,a1
	add.w	d0,a1
	lea	cb_s,a0
	bsr	pstr_cpy
	lea	cb_s,a0
	moveq	#0,d0
	move.b	(a0),d0
	move.b	#' ',1(a0,d0.w)
	move.w	cb_target,d1
	add.b	#64,d1
	move.b	d1,2(a0,d0.w)
	addq.b	#2,(a0)
	rts

; givedamage(n d0, d d1) to the target
cb_givedamage:
	movem.l	d3-d4/a3,-(sp)
	move.w	d0,d3
	move.w	d1,d0			; d := round(d/100*(100-damages[weapons]))
	FSSE
	bsr	fp_ldw
	FLDI	100
	bsr	fp_div
	moveq	#100,d0
	sub.b	GS_SHIP+SHIP_DAMAGES+DMG_WEAPONS-1(a6),d0
	and.w	#$ff,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,d4
	cmp.w	#1,d4
	bge.s	.d
	moveq	#1,d4
.d:	move.w	cb_target,d0
	bsr	cb_ship
	move.l	a0,a3
	lea	ALIENSHIP_DAMAGES-1(a3),a1	; (damages[1..7])
	cmp.w	#DMGTYP_PSIONIC,d3
	bne.s	.n2
	add.b	d4,DMG_LIFESUPPORT(a1)
	bra	.e
.n2:	cmp.w	#DMGTYP_PARTICLE,d3
	bne.s	.n3
	sub.w	d4,ALIENSHIP_HULLINTEGRITY(a3)
	bra	.e
.n3:	cmp.w	#DMGTYP_INERTIAL,d3
	bne.s	.n4
	move.w	d4,d0
	ext.l	d0
	divs	#2,d0
	sub.w	d0,ALIENSHIP_HULLINTEGRITY(a3)
	bra.s	.e
.n4:	cmp.w	#DMGTYP_ENERGY,d3
	bne.s	.n5
	moveq	#8,d0
	bsr	mt_random
	lea	ALIENSHIP_DAMAGES-1(a3),a1
	cmp.w	#6,d0
	blt.s	.sub
	sub.w	d4,ALIENSHIP_HULLINTEGRITY(a3)
	bra.s	.e
.sub:	move.b	.dm(pc,d0.w),d0		; 0 power, 1 shield, 2 weapons, 3 engines, 4 comm, 5 cpu
	add.b	d4,0(a1,d0.w)
	bra.s	.e
.dm:	dc.b	DMG_POWER,DMG_SHIELD,DMG_WEAPONS,DMG_ENGINES,DMG_COMM,DMG_CPU
.n5:	cmp.w	#DMGTYP_FAKE_SHLD,d3
	bne.s	.e
	add.b	d4,DMG_SHIELD(a1)
.e:	tst.w	ALIENSHIP_HULLINTEGRITY(a3)
	bpl.s	.h
	clr.w	ALIENSHIP_HULLINTEGRITY(a3)
.h:	lea	ALIENSHIP_DAMAGES(a3),a1
	moveq	#7-1,d0
.l:	cmp.b	#100,(a1)
	bls.s	.ln
	move.b	#100,(a1)
.ln:	addq.l	#1,a1
	dbf	d0,.l
	tst.w	ALIENSHIP_SHIELDLEVEL(a3)
	bpl.s	.sl
	clr.w	ALIENSHIP_SHIELDLEVEL(a3)
.sl:	cmp.w	#ID_REFLECTIVEHULL,ALIENSHIP_SHIELD(a3)
	bne.s	.rh
	moveq	#100,d0
	sub.b	ALIENSHIP_DAMAGES+DMG_SHIELD-1(a3),d0
	and.w	#$ff,d0
	move.w	d0,ALIENSHIP_SHIELDLEVEL(a3)
.rh:	cmp.b	#100,ALIENSHIP_DAMAGES+DMG_LIFESUPPORT-1(a3)
	bne.s	.x
	clr.w	ALIENSHIP_HULLINTEGRITY(a3)
.x:	movem.l	(sp)+,d3-d4/a3
	rts

; soundeffect(sample d0 (0 gun1, 1 gun4, 2-8 laser1-7, 9-10 explode1-2), rate d1)
cb_sound:
	tst.b	GS_SHIP+SHIP_OPTIONS+OPT_SOUND-1(a6)
	beq.s	.x
	mulu	#SMP_SIZE,d0
	lea	cb_samples,a0
	add.l	d0,a0
	move.w	d1,d0
	bra	snd_sfx_play
.x:	rts

; firingweapon(n d0)
cb_firingweapon:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,d7			; n
	lea	GS_SHIP+SHIP_GUNNODES-1(a6),a0
	moveq	#0,d6
	move.b	0(a0,d7.w),d6		; c
	move.w	d6,d0
	bsr	cb_weap
	move.l	a0,a4			; weapons[c]
	moveq	#0,d0			; the sound by the energy share
	move.b	WEAPON_DMGTYPES+DMGTYP_ENERGY-1(a4),d0
	cmp.w	#23,d0
	bgt.s	.l
	moveq	#0,d0			; gun1, or gun4 when particle > inertial
	move.b	WEAPON_DMGTYPES+DMGTYP_PARTICLE-1(a4),d1
	cmp.b	WEAPON_DMGTYPES+DMGTYP_INERTIAL-1(a4),d1
	bls.s	.snd
	moveq	#1,d0
	bra.s	.snd
.l:	sub.w	#24,d0			; 24..34 laser1, 35..45 laser2, ... 90..100 laser7
	ext.l	d0
	divu	#11,d0
	cmp.w	#6,d0
	bls.s	.l7
	moveq	#6,d0
.l7:	addq.w	#2,d0
.snd:	move.w	#7000,d1
	bsr	cb_sound
	move.w	GS_TSLICE(a6),d0	; delay(tslice)
	bsr	delay
	move.w	cb_target,d0
	bsr	cb_ship
	move.l	a0,a3
	st	ct_bg			; SkillTest(true, 4, skill - scanning*20, learnchance)
	moveq	#4,d0
	move.w	ALIENSHIP_SKILL(a3),d1
	tst.b	cb_scanning
	beq.s	.st
	sub.w	#20,d1
.st:	move.w	cb_learn,d2
	bsr	ct_skilltest
	tst.w	d0
	beq	.miss
	move.w	ALIENSHIP_SHIELD(a3),d0	; b := the alien's shield (as a weapon record)
	sub.w	#ID_SHIELDS_OFFSET,d0
	bsr	cb_weap
	move.l	a0,a5			; weapons[b]
	moveq	#1,d5			; j: the damage types
.j:	tst.b	WEAPON_DMGTYPES-1(a4,d5.w)
	beq	.jn
	FSSE				; i := round(dmgtypes[j]/100*damage*5)
	moveq	#0,d0
	move.b	WEAPON_DMGTYPES-1(a4,d5.w),d0
	bsr	fp_ldw
	FLDI	100
	bsr	fp_div
	move.w	WEAPON_DAMAGE(a4),d0
	bsr	fp_ldw
	bsr	fp_mul
	FLDI	5
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,d4			; i
	tst.w	ALIENSHIP_SHIELDLEVEL(a3)
	bne.s	.sh
	move.w	d5,d0			; no shields: givedamage(j, i)
	move.w	d4,d1
	bsr	cb_givedamage
	bra	.jn
.sh:	moveq	#0,d0			; a := round(sdmgtypes[j]/100*sdamage*shieldlevel/100)
	move.b	WEAPON_DMGTYPES-1(a5,d5.w),d0
	bsr	fp_ldw
	FLDI	100
	bsr	fp_div
	move.w	WEAPON_DAMAGE(a5),d0
	bsr	fp_ldw
	bsr	fp_mul
	move.w	ALIENSHIP_SHIELDLEVEL(a3),d0
	bsr	fp_ldw
	bsr	fp_mul
	FLDI	100
	bsr	fp_div
	bsr	fp_rnd
	move.w	d0,d3			; a
	cmp.w	d4,d3
	bge.s	.hold
	move.w	d5,d0			; more than the shield takes: givedamage(j, i-a), shields collapse
	move.w	d4,d1
	sub.w	d3,d1
	bsr	cb_givedamage
	move.w	#1,ALIENSHIP_SHIELDLEVEL(a3)
	bsr	.refl100
	bra	.jn
.hold:	move.w	d4,d0			; part := i/shieldlevel; *(1/damage); *100; a := round(part*100)
	bsr	fp_ldw
	move.w	ALIENSHIP_SHIELDLEVEL(a3),d0
	bsr	fp_ldw
	bsr	fp_div
	FLDI	1
	move.w	WEAPON_DAMAGE(a5),d0
	bsr	fp_ldw
	bsr	fp_div
	bsr	fp_mul
	FLDI	100
	bsr	fp_mul
	lea	cb_part,a0
	bsr	fp_std
	lea	cb_part,a0
	bsr	fp_ldd
	FLDI	100
	bsr	fp_mul
	bsr	fp_rnd
	move.w	ALIENSHIP_SHIELDLEVEL(a3),d1	; d := shieldlevel - a
	sub.w	d0,d1
	bpl.s	.still
	moveq	#4,d0			; collapsed: givedamage(FAKE_SHLD, random(4)+1)
	bsr	mt_random
	addq.w	#1,d0
	move.w	d0,d1
	moveq	#DMGTYP_FAKE_SHLD,d0
	bsr	cb_givedamage
	bsr	.refl100
	move.w	#1,ALIENSHIP_SHIELDLEVEL(a3)
	bra.s	.jn
.still:	move.w	d1,ALIENSHIP_SHIELDLEVEL(a3)
	cmp.w	#ID_REFLECTIVEHULL,ALIENSHIP_SHIELD(a3)
	bne.s	.jn
	cmp.w	#1,d5
	ble.s	.jn
	moveq	#100,d0
	sub.w	d1,d0
	move.b	d0,ALIENSHIP_DAMAGES+DMG_SHIELD-1(a3)
.jn:	addq.w	#1,d5
	cmp.w	#4,d5
	ble	.j
.miss:	tst.w	ALIENSHIP_HULLINTEGRITY(a3)
	bne.s	.alive
	move.w	#1,ALIENSHIP_HULLINTEGRITY(a3)	; destroyed: the mark once more as alive (xor), then gone
	bsr	cb_displaymap
	clr.w	ALIENSHIP_HULLINTEGRITY(a3)
	bsr	cb_firstalive
	move.w	cb_target,d0
	bsr	cb_ship
	move.l	a0,a1
	lea	cb_r,a0
	bsr	cb_range
	bsr	cb_displaymap
.alive:	add.w	d7,d7
	lea	cb_powered-2,a0
	clr.w	0(a0,d7.w)
	clr.w	cb_fire
	movem.l	(sp)+,d3-d7/a3-a5
	rts
.refl100:				; reflective hull and j > 1: damages[shield] := 100
	cmp.w	#ID_REFLECTIVEHULL,ALIENSHIP_SHIELD(a3)
	bne.s	.rx
	cmp.w	#1,d5
	ble.s	.rx
	move.b	#100,ALIENSHIP_DAMAGES+DMG_SHIELD-1(a3)
.rx:	rts

; targetindex := the first ship still alive (done_ when none; the index then nships+1)
cb_firstalive:
	move.w	#1,cb_target
.l:	move.w	cb_target,d0
	cmp.w	cb_nships,d0
	bgt.s	.none
	bsr	cb_ship
	tst.w	ALIENSHIP_HULLINTEGRITY(a0)
	bne.s	.x
	addq.w	#1,cb_target
	bra.s	.l
.none:	st	cb_done
.x:	rts

; the gun node j's frame: x := ((j-1) mod 5)*23+105, y := ((j-1) div 5)*31+131 (rectangle 20x20)
; cb_noderect_m: the same between mousehide and mouseshow - only when it is drawn (speed: a
; frame already in that colour needs neither; the shadow is the same, the flush comes later)
cb_noderect_m:
	st	cb_nrm
	bra.s	cb_nr
cb_noderect:
	sf	cb_nrm
cb_nr:	move.w	d1,-(sp)		; d0 = j, d1 = colour
	subq.w	#1,d0
	ext.l	d0
	divu	#5,d0
	move.w	d0,d1
	mulu	#31,d1
	add.w	#131,d1
	swap	d0
	mulu	#23,d0
	add.w	#105,d0
	move.w	d0,GS_X(a6)
	move.w	d1,GS_Y(a6)
	move.w	(sp)+,d4
	move.l	d3,-(sp)
	movem.w	d0-d1,-(sp)		; (speed: a frame already in this colour is left alone)
	bsr	ms_addr			; rows y and y+20, x..x+19; columns x and x+20, y..y+19
	moveq	#0,d2			; the colour in all four bytes
	move.b	d4,d2
	move.w	d2,d0
	lsl.w	#8,d0
	or.w	d0,d2
	move.w	d2,d0
	swap	d2
	move.w	d0,d2
	bsr	.row20
	bne	.draw
	lea	20*320(a0),a0
	bsr	.row20
	bne	.draw
	sub.w	#20*320,a0		; columns x and x+20, rows y..y+19 (unrolled)
o	set	0
	rept	20
	cmp.b	o(a0),d4
	bne	.draw
	cmp.b	o+20(a0),d4
	bne	.draw
o	set	o+320
	endr
	addq.l	#4,sp
	move.l	(sp)+,d3
	rts
.draw:	tst.b	cb_nrm
	beq.s	.d1
	bsr	mousehide
.d1:	movem.w	(sp)+,d0-d1
	move.w	d0,d2
	add.w	#20,d2
	move.w	d1,d3
	add.w	#20,d3
	bsr	ms_rect
	tst.b	cb_nrm
	beq.s	.d2
	bsr	mouseshow
.d2:	move.l	(sp)+,d3
	rts
.row20:	move.l	a0,d0			; 20 bytes at a0 = d2 (four copies)? Z set if so
	btst	#0,d0
	beq.s	.r20e
	cmp.b	(a0),d2
	bne.s	.r20x
	cmp.l	1(a0),d2
	bne.s	.r20x
	cmp.l	5(a0),d2
	bne.s	.r20x
	cmp.l	9(a0),d2
	bne.s	.r20x
	cmp.l	13(a0),d2
	bne.s	.r20x
	cmp.b	17(a0),d2
	bne.s	.r20x
	cmp.b	18(a0),d2
	bne.s	.r20x
	cmp.b	19(a0),d2
.r20x:	rts
.r20e:	cmp.l	(a0),d2
	bne.s	.r20x
	cmp.l	4(a0),d2
	bne.s	.r20x
	cmp.l	8(a0),d2
	bne.s	.r20x
	cmp.l	12(a0),d2
	bne.s	.r20x
	cmp.l	16(a0),d2
	rts
; colour of the powering frame: round(p*0.31): < 16: 80+i, else 32+i
; d0.w poweredup -> the node's colour: i := round(p*0.31) (x87); i < 16: 80+i, else 32+i.
; Speed: a table of the FPU's results for p = 0..100, built on first use.
cb_powcol:
	cmp.w	#100,d0
	bhi.s	.fpu
	tst.b	cb_pctab_ok
	bne.s	.t
	movem.l	d0/d3,-(sp)
	moveq	#0,d3
.b:	move.w	d3,d0
	bsr.s	.fpu
	lea	cb_pctab,a0
	move.b	d0,0(a0,d3.w)
	addq.w	#1,d3
	cmp.w	#100,d3
	ble.s	.b
	st	cb_pctab_ok
	movem.l	(sp)+,d0/d3
.t:	lea	cb_pctab,a0
	move.b	0(a0,d0.w),d0
	and.w	#$ff,d0
	rts
.fpu:	FX87
	bsr	fp_ldw
	FLDX	gx_0_31
	bsr	fp_mul
	bsr	fp_rnd
	FSSE
	cmp.w	#16,d0
	bge.s	.h
	add.w	#80,d0
	rts
.h:	add.w	#32,d0
	rts
	section	bss
cb_pctab:	ds.b	101
cb_pctab_ok:	ds.b	1
cb_nrm:		ds.b	1		; cb_noderect_m: mousehide/mouseshow around a redraw
	even
	section	text

cb_powerup:
	movem.l	d3-d7/a3,-(sp)
	moveq	#1,d7			; j
.j:	move.w	d7,d0
	add.w	d0,d0
	lea	cb_powered-2,a3
	add.w	d0,a3			; poweredup[j]
	move.w	(a3),d0
	bmi	.jn
	cmp.w	#100,d0
	bge	.full
	lea	cb_userpow-1,a0		; user wants it and it is at 0 and the battery has its energy: start
	tst.b	0(a0,d7.w)
	beq.s	.inc
	tst.w	(a3)
	bne.s	.inc
	lea	GS_SHIP+SHIP_GUNNODES-1(a6),a0
	moveq	#0,d0
	move.b	0(a0,d7.w),d0
	bsr	cb_weap
	move.w	WEAPON_ENERGY(a0),d0
	cmp.w	GS_SHIP+SHIP_BATTERY(a6),d0
	bgt.s	.inc
	sub.w	d0,GS_SHIP+SHIP_BATTERY(a6)
	move.w	#1,(a3)
	bra.s	.dr
.inc:	tst.w	(a3)
	ble.s	.dr
	addq.w	#1,(a3)
.dr:	move.w	(a3),d0			; (mousehide/mouseshow: in cb_noderect_m, if it draws)
	bsr	cb_powcol
	move.w	d0,d1
	move.w	d7,d0
	bsr	cb_noderect_m
	bra	.jn
.full:	bne	.jn			; (= 100: ready)
	lea	GS_SHIP+SHIP_GUNNODES-1(a6),a0
	moveq	#0,d0
	move.b	0(a0,d7.w),d0
	bsr	cb_weap
	move.l	WEAPON_RANGE(a0),d0	; part := range; in range: 47, else 63
	move.l	d0,-(sp)
	FSSE
	bsr	fp_ldi
	lea	cb_part,a0
	bsr	fp_std
	lea	cb_r,a0			; part >= r (exact in integers: cb_r2)
	bsr	cb_r2
	move.l	(sp)+,d1
	add.l	d1,d1
	cmp.l	d0,d1
	slt	d3			; (d3 = $ff: out of range)
	moveq	#47,d1
	tst.b	d3
	beq.s	.c
	moveq	#63,d1
.c:	move.w	d7,d0
	bsr	cb_noderect_m
	tst.b	d3
	bne.s	.jn
	tst.b	cb_autofire
	bne.s	.fire
	cmp.w	cb_fire,d7
	bne.s	.jn
.fire:	move.w	d7,d0
	bsr	cb_firingweapon
.jn:	addq.w	#1,d7
	cmp.w	#10,d7
	ble	.j
	lea	GS_SHIP+SHIP_SHIELDLEVEL(a6),a0	; the ship's shield level follows the setting
	moveq	#0,d0
	move.b	GS_SHIP+SHIP_SHIELDOPT+SHLD_COMBAT_WANT-1(a6),d0
	tst.w	GS_SHIP+SHIP_BATTERY(a6)
	ble.s	.s2
	cmp.w	(a0),d0
	ble.s	.s3
	addq.w	#1,(a0)
	bra.s	.al
.s2:	tst.w	GS_SHIP+SHIP_BATTERY(a6)
	bne.s	.s3
	tst.w	(a0)
	ble.s	.s3
	subq.w	#1,(a0)
	bra.s	.al
.s3:	cmp.w	(a0),d0
	bge.s	.al
	subq.w	#1,(a0)
.al:	moveq	#1,d7			; the aliens' shields and charges
.a:	cmp.w	cb_nships,d7
	bgt	.x
	move.w	d7,d0
	bsr	cb_ship
	move.l	a0,a3
	cmp.w	#ID_REFLECTIVEHULL,ALIENSHIP_SHIELD(a3)
	ble	.ch
	lea	cb_r,a0			; r := the ship's range
	move.l	a3,a1
	bsr	cb_range
	move.w	ALIENSHIP_SHIELD(a3),d0	; i := round(senergy*shieldlevel/100)
	sub.w	#ID_SHIELDS_OFFSET,d0
	bsr	cb_weap
	move.w	WEAPON_ENERGY(a0),d0
	muls	ALIENSHIP_SHIELDLEVEL(a3),d0
	bsr	cb_rdiv100
	move.w	d0,d6
	moveq	#100,d5			; 100 - damages[shield]
	sub.b	ALIENSHIP_DAMAGES+DMG_SHIELD-1(a3),d5
	and.w	#$ff,d5
	tst.w	ALIENSHIP_BATTERY(a3)
	ble.s	.b2
	move.l	#390000,d0
	bsr	cb_rcmp			; abs(r) < 390000
	bge.s	.b2
	cmp.w	ALIENSHIP_SHIELDLEVEL(a3),d5
	ble.s	.b2
	addq.w	#1,ALIENSHIP_SHIELDLEVEL(a3)
	bra.s	.b4
.b2:	tst.w	ALIENSHIP_BATTERY(a3)	; (battery = 0 or abs(r) > 400000) and shieldlevel > 0
	beq.s	.b2a
	move.l	#400000,d0
	bsr	cb_rcmp
	ble.s	.b3
.b2a:	tst.w	ALIENSHIP_SHIELDLEVEL(a3)
	ble.s	.b3
	subq.w	#1,ALIENSHIP_SHIELDLEVEL(a3)
	bra.s	.b4
.b3:	cmp.w	ALIENSHIP_SHIELDLEVEL(a3),d5
	bge.s	.b4
	subq.w	#1,ALIENSHIP_SHIELDLEVEL(a3)
.b4:	move.l	#230000,d0		; 230000 < abs(r) < 400000 and i > round(regen*(100-dmgpow)/100)
	bsr	cb_rcmp			; and shieldlevel > 2: dec 3
	ble.s	.ch
	move.l	#400000,d0
	bsr	cb_rcmp
	bge.s	.ch
	moveq	#100,d0
	sub.b	ALIENSHIP_DAMAGES+DMG_POWER-1(a3),d0
	and.w	#$ff,d0
	muls	ALIENSHIP_REGEN(a3),d0
	bsr	cb_rdiv100
	cmp.w	d0,d6
	ble.s	.ch
	cmp.w	#2,ALIENSHIP_SHIELDLEVEL(a3)
	ble.s	.ch
	subq.w	#3,ALIENSHIP_SHIELDLEVEL(a3)
.ch:	lea	ALIENSHIP_CHARGES(a3),a1	; charges: 0 -> 1 when the battery holds weapon 72's energy
	moveq	#MAXWEAPONS,d0
	bsr	cb_weap
	move.w	WEAPON_ENERGY(a0),d1
	moveq	#20-1,d2
.cl:	move.b	(a1),d0
	cmp.b	#100,d0
	bhs.s	.cn
	tst.b	d0
	bne.s	.cp
	cmp.w	ALIENSHIP_BATTERY(a3),d1
	bgt.s	.cn
	sub.w	d1,ALIENSHIP_BATTERY(a3)
	move.b	#1,(a1)
	bra.s	.cn
.cp:	addq.b	#1,(a1)
.cn:	addq.l	#1,a1
	dbf	d2,.cl
	addq.w	#1,d7
	bra	.a
.x:	movem.l	(sp)+,d3-d7/a3
	rts

; d0 := round(d0.l / 100) as FPC's (an integer expression divided by 100: a double, banker's).
; Done in integers: n/100 is never within an ulp of .5 unless it is exactly k.5, so the double's
; banker's rounding is the exact one. |n| < 6553600.  trashes d1-d2
cb_rdiv100:
	move.l	d0,d1
	bpl.s	.p
	neg.l	d0
.p:	divu	#100,d0
	move.l	d0,d2
	swap	d2			; remainder
	and.l	#$ffff,d0
	cmp.w	#50,d2
	blo.s	.s
	bhi.s	.up
	btst	#0,d0
	beq.s	.s
.up:	addq.l	#1,d0
.s:	tst.l	d1
	bpl.s	.x
	neg.l	d0
.x:	rts

; compare abs(r) (cb_r) with d0.l: flags as for "abs(r) - d0" (lt/eq/gt)
; (2*trunc(|r|)+frac against 2*d0: exact, no FPU)
cb_rcmp:
	move.l	d0,-(sp)
	lea	cb_r,a0
	bsr.s	cb_r2
	move.l	(sp)+,d1
	add.l	d1,d1
	cmp.l	d1,d0
	rts

; the double at a0 -> d0.l = 2*trunc(|x|) + (1 if |x| has a fraction), $7fffffff when
; |x| >= 2^30: integer compares with it are exact (x >= k <=> d0 >= 2k).  trashes d1-d2/a0-a1
cb_r2:
	move.l	(a0),d1
	move.l	4(a0),d2
	and.l	#$7fffffff,d1
	move.l	d1,d0
	swap	d0
	lsr.w	#4,d0
	sub.w	#1023,d0		; exponent
	bmi.s	.small
	cmp.w	#29,d0
	bgt.s	.huge
	and.l	#$fffff,d1		; the 53-bit mantissa: d1 (21 bits) : d2
	bset	#20,d1
	neg.w	d0
	add.w	#52-32,d0		; k = 52-e-32: shift right by 32+k
	bmi.s	.lt
	move.l	d2,a1			; s >= 32: t = mhi >> k
	moveq	#1,d2
	lsl.l	d0,d2
	subq.l	#1,d2
	and.l	d1,d2			; the fraction bits in mhi
	lsr.l	d0,d1
	add.l	d1,d1
	move.l	a1,d0
	or.l	d0,d2			; and lo
	beq.s	.x0
	addq.l	#1,d1
.x0:	move.l	d1,d0
	rts
.lt:	neg.w	d0			; c = 32-s (s = 52-e < 32)
	lsl.l	d0,d1			; mhi << c
	move.l	d2,a1
	lsl.l	d0,d2			; the fraction bits of lo
	sne	d2
	move.l	d2,a0
	neg.w	d0
	add.w	#32,d0			; s
	move.l	a1,d2
	lsr.l	d0,d2			; lo >> s
	or.l	d2,d1
	add.l	d1,d1
	move.l	a0,d0
	tst.b	d0
	beq.s	.x0
	addq.l	#1,d1
	bra.s	.x0
.small:	or.l	d2,d1
	sne	d0
	and.l	#1,d0
	rts
.huge:	move.l	#$7fffffff,d0
	rts

cb_showweaponicon:
	movem.l	d3-d5,-(sp)
	move.w	d0,d4
	move.w	d1,d5
	tst.w	d2
	bne.s	.ic
	move.w	d4,d0			; none: 20x20 in 3
	move.w	d5,d1
	move.w	d4,d2
	add.w	#19,d2
	move.w	d5,d3
	add.w	#19,d3
	move.w	d4,-(sp)
	moveq	#3,d4
	bsr	ms_bar
	move.w	(sp)+,d4
	bra.s	.x
.ic:	move.w	d2,d0
	subq.w	#1,d0
	bsr	readweaicon
	move.l	GS_TEMPICON(a6),a1
	moveq	#20-1,d3
.r:	move.w	d4,d0
	move.w	d5,d1
	bsr	ms_addr
	moveq	#20-1,d0
.c:	move.b	(a1)+,(a0)+
	dbf	d0,.c
	addq.w	#1,d5
	dbf	d3,.r
	move.w	d4,d0
	move.w	d5,d1
	sub.w	#20,d1
	move.w	d4,d2
	add.w	#19,d2
	move.w	d5,d3
	subq.w	#1,d3
	bsr	ms_dirty
.x:	movem.l	(sp)+,d3-d5
	rts

cb_displayweapons:
	movem.l	d3-d7,-(sp)
	bsr	mousehide
	moveq	#1,d7
.j:	move.w	d7,d0			; x, y of the node
	subq.w	#1,d0
	ext.l	d0
	divu	#5,d0
	move.w	d0,d1
	mulu	#31,d1
	add.w	#131,d1
	swap	d0
	mulu	#23,d0
	add.w	#105,d0
	move.w	d0,GS_X(a6)
	move.w	d1,GS_Y(a6)
	lea	GS_SHIP+SHIP_GUNNODES-1(a6),a0
	moveq	#0,d2
	move.b	0(a0,d7.w),d2
	bsr	cb_showweaponicon
	lea	GS_SHIP+SHIP_GUNNODES-1(a6),a0
	tst.b	0(a0,d7.w)
	beq.s	.n
	move.w	d7,d0
	add.w	d0,d0
	lea	cb_powered-2,a0
	move.w	0(a0,d0.w),d0
	bsr	cb_powcol
	move.w	d0,cb_a
	move.w	d0,d1
	move.w	d7,d0
	bsr	cb_noderect
.n:	addq.w	#1,d7
	cmp.w	#10,d7
	ble.s	.j
	bsr	mouseshow
	movem.l	(sp)+,d3-d7
	rts

; one damage bar: b := round((100-d)/100*49) (at least 1); part := 31/b; pixels round(j*part)
; for j 0..b at (x0+j, rows y, y+1); if b < 51: the rest (from x0+1+b, 49-b wide) in 0
cb_dmgbar:
	movem.l	d3-d7,-(sp)
	move.w	d1,d6			; row
	move.w	d2,d7			; x0
	moveq	#100,d1
	sub.w	d0,d1
	move.w	d1,d0			; b := round((100-dmg)/100*49)
	moveq	#100,d1
	bsr	cb_b49
	move.w	d0,d5			; b
	bgt.s	.b
	moveq	#1,d5
.b:	cmp.w	#49,d5
	bgt.s	.slow
	bsr	cb_rtab_init		; rows y, y+1, x0..x0+b: round(j*(31/b)) from the table
	move.w	d5,d0
	mulu	#50,d0
	lea	cb_rtab,a1
	add.w	d0,a1
	move.w	d7,d0
	move.w	d6,d1
	bsr	ms_addr
	move.w	d5,d0
.t:	move.b	(a1),320(a0)
	move.b	(a1)+,(a0)+
	dbf	d0,.t
	move.w	d7,d0			; ms_dirty(x0, y, x0+b, y+1)
	move.w	d6,d1
	move.w	d7,d2
	add.w	d5,d2
	move.w	d6,d3
	addq.w	#1,d3
	bsr	ms_dirty
	bra.s	.rest
.slow:	FSSE
	FLDI	31			; part := 31/b
	move.w	d5,d0
	bsr	fp_ldw
	bsr	fp_div
	lea	cb_part,a0
	bsr	fp_std
	moveq	#0,d4			; j
.j:	lea	cb_part,a0
	bsr	fp_ldd
	move.w	d4,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,d3
	move.w	d7,d0
	add.w	d4,d0
	move.w	d6,d1
	move.w	d3,d2
	movem.w	d0-d2,-(sp)
	bsr	ms_pset
	movem.w	(sp)+,d0-d2
	addq.w	#1,d1
	bsr	ms_pset
	addq.w	#1,d4
	cmp.w	d5,d4
	ble.s	.j
.rest:
	cmp.w	#51,d5
	bge.s	.x
	moveq	#49,d4			; 49-b bytes from x0+1+b (scr_fillchar with a count <= 0: none)
	sub.w	d5,d4
	ble.s	.x
	move.w	d7,d0
	add.w	d5,d0
	addq.w	#1,d0
	move.w	d6,d1
	move.w	d0,d2
	add.w	d4,d2
	subq.w	#1,d2
	move.w	d6,d3
	addq.w	#1,d3
	moveq	#0,d4
	bsr	ms_bar
.x:	movem.l	(sp)+,d3-d7
	rts

cb_displaydamage:
	movem.l	d3-d4,-(sp)
	tst.b	cb_done
	bne	.x
	tst.b	cb_dead
	bne	.x
	bsr	mousehide
	moveq	#1,d3			; a := 1..7: rows a*9+127
.a:	lea	GS_SHIP+SHIP_DAMAGES-1(a6),a0
	moveq	#0,d0
	move.b	0(a0,d3.w),d0
	move.w	d3,d1
	mulu	#9,d1
	add.w	#127,d1
	move.w	#267,d2
	bsr	cb_dmgbar
	addq.w	#1,d3
	cmp.w	#7,d3
	ble.s	.a
	moveq	#100,d0			; shields above what the subsystem allows: down to it
	sub.b	GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6),d0
	and.w	#$ff,d0
	moveq	#0,d1
	move.b	GS_SHIP+SHIP_SHIELDOPT+SHLD_COMBAT_WANT-1(a6),d1
	cmp.w	d1,d0
	bge.s	.m
	bsr	cb_displayshieldpic
.m:	FSSE				; part := 114 - 102/100*(100-damages[shield])
	FLDI	114
	FLDI	102
	FLDI	100
	bsr	fp_div
	moveq	#100,d0
	sub.b	GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6),d0
	and.w	#$ff,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_sub
	lea	cb_part,a0		; (part is the unit's global: moveships reads it after a hit)
	bsr	fp_std
	lea	cb_part,a0
	bsr	fp_ldd
	bsr	fp_rnd
	move.w	d0,d4
	cmp.w	cb_oldshddmg,d4
	beq.s	.n
	move.w	cb_oldshddmg,d3		; the old marker off, the new one at round(part)
	moveq	#7-1,d2
.o:	move.w	#296,d0
	move.w	d3,d1
	movem.w	d2,-(sp)
	bsr	ms_addr
	movem.w	(sp)+,d2
	clr.l	(a0)
	addq.w	#1,d3
	dbf	d2,.o
	move.w	d4,d3
	lea	cb_shieldpic2,a1
	moveq	#7-1,d2
.p:	move.w	#296,d0
	move.w	d3,d1
	movem.l	d2/a1,-(sp)
	bsr	ms_addr
	movem.l	(sp)+,d2/a1
	move.l	(a1)+,(a0)
	addq.w	#1,d3
	dbf	d2,.p
	move.w	d4,cb_oldshddmg
	move.w	#296,d0
	moveq	#0,d1
	move.w	#299,d2
	move.w	#130,d3
	bsr	ms_dirty
.n:	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d4
	rts

cb_suckpower:
	movem.l	d3-d7/a3,-(sp)
	cmp.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)
	ble.s	.p
	move.w	GS_SHIP+SHIP_SHIELD(a6),d0	; battery -= round(energy/100*shieldlevel)
	sub.w	#ID_SHIELDS_OFFSET,d0
	bsr	cb_weap
	move.w	WEAPON_ENERGY(a0),d0
	move.w	GS_SHIP+SHIP_SHIELDLEVEL(a6),d1
	bsr	cb_e100
	sub.w	d0,GS_SHIP+SHIP_BATTERY(a6)
.p:	moveq	#100,d0			; i := round((100-damages[power])/4), at least 1
	sub.b	GS_SHIP+SHIP_DAMAGES+DMG_POWER-1(a6),d0
	and.w	#$ff,d0
	FSSE
	bsr	fp_ldw
	FLDI	4
	bsr	fp_div
	bsr	fp_rnd
	move.w	d0,cb_i
	bne.s	.i
	moveq	#1,d0
	move.w	d0,cb_i
.i:	add.w	d0,GS_SHIP+SHIP_BATTERY(a6)
	lea	GS_SHIP+SHIP_BATTERY(a6),a0
	bsr	cb_clampbatt
	moveq	#1,d7
.a:	cmp.w	cb_nships,d7
	bgt	.x
	move.w	d7,d0
	bsr	cb_ship
	move.l	a0,a3
	tst.w	ALIENSHIP_HULLINTEGRITY(a3)
	ble.s	.an
	cmp.w	#ID_REFLECTIVEHULL,ALIENSHIP_SHIELD(a3)
	ble.s	.ar
	move.w	ALIENSHIP_SHIELD(a3),d0
	sub.w	#ID_SHIELDS_OFFSET,d0
	bsr	cb_weap
	move.w	WEAPON_ENERGY(a0),d0
	move.w	ALIENSHIP_SHIELDLEVEL(a3),d1
	bsr	cb_e100
	sub.w	d0,ALIENSHIP_BATTERY(a3)
.ar:	moveq	#100,d0			; battery += round(regen*(100-dmgpow)/100)
	sub.b	ALIENSHIP_DAMAGES+DMG_POWER-1(a3),d0
	and.w	#$ff,d0
	muls	ALIENSHIP_REGEN(a3),d0
	bsr	cb_rdiv100
	add.w	d0,ALIENSHIP_BATTERY(a3)
	lea	ALIENSHIP_BATTERY(a3),a0
	bsr	cb_clampbatt
	tst.w	ALIENSHIP_BATTERY(a3)
	bne.s	.an
	cmp.w	#ID_REFLECTIVEHULL,ALIENSHIP_SHIELD(a3)
	ble.s	.an
	cmp.b	#99,ALIENSHIP_DAMAGES+DMG_SHIELD-1(a3)
	bhs.s	.an
	addq.b	#2,ALIENSHIP_DAMAGES+DMG_SHIELD-1(a3)
.an:	addq.w	#1,d7
	bra.s	.a
.x:	movem.l	(sp)+,d3-d7/a3
	rts
cb_clampbatt:				; (a0).w into 0..32000
	tst.w	(a0)
	bpl.s	.p
	clr.w	(a0)
	rts
.p:	cmp.w	#32000,(a0)
	ble.s	.x
	move.w	#32000,(a0)
.x:	rts
; d0 := round(d0/100*d1) (SSE)
cb_e100:				; d0 := round(d0.w/100*d1.w): integers unless an exact .5
	tst.w	d0
	bmi.s	.fpu
	tst.w	d1
	bmi.s	.fpu
	move.w	d0,d2
	mulu	d1,d2
	divu	#100,d2
	bvs.s	.fpu
	move.l	d2,a0			; (quotient in the low word)
	swap	d2			; remainder
	cmp.w	#50,d2
	beq.s	.fpu			; a tie: the doubles decide (d0, d1 still the arguments)
	sgt	d2
	and.w	#1,d2
	move.l	a0,d0
	add.w	d2,d0
	ext.l	d0
	rts
.fpu:	move.w	d1,-(sp)
	FSSE
	bsr	fp_ldw
	FLDI	100
	bsr	fp_div
	move.w	(sp)+,d0
	bsr	fp_ldw
	bsr	fp_mul
	bra	fp_rnd

; a bar of the target's display: b := round(v/max*49) (at least 1); part := 31/b; rows
; 138+i for i 0..b in round(i*part), the rest to 49 in 0; at x d2, d3 wide
; in: d0 = v, d1 = max. Speed: round(i*(31/b)) comes from cb_rtab (built once by the same FPU
; steps, so bit-identical); a row is written and marked dirty only when it changes.
; d0.w := round(v/max*49) as FPC's SSE doubles, v = d0.w, max = d1.w (> 0). Exact in integers
; (round half up of v*49/max: checked on the host against the doubles for every max < 32768
; and 0 <= v <= max) except at an exact .5, where the doubles' rounding errors decide: the FPU.
; trashes d1-d2/a0-a2
cb_b49:
	move.l	d3,-(sp)
	tst.w	d0
	bmi.s	.fpu
	cmp.w	d1,d0
	bhi.s	.fpu
	moveq	#0,d2
	move.w	d0,d2
	mulu	#98,d2
	moveq	#0,d3
	move.w	d1,d3
	add.l	d3,d2			; v*98 + max
	add.w	d3,d3			; 2*max
	divu	d3,d2
	swap	d2
	tst.w	d2
	beq.s	.fpu			; a tie
	swap	d2
	moveq	#0,d0
	move.w	d2,d0
	move.l	(sp)+,d3
	rts
.fpu:	FSSE
	move.w	d1,-(sp)
	bsr	fp_ldw
	move.w	(sp)+,d0
	bsr	fp_ldw
	bsr	fp_div
	FLDI	49
	bsr	fp_mul
	bsr	fp_rnd
	move.l	(sp)+,d3
	rts

cb_tbar:
	movem.l	d3-d7/a3,-(sp)
	move.w	d2,d6			; x
	move.w	d3,d7			; width
	lea	cb_tmemo,a0		; the same v and max as this column's last bar, which still
	moveq	#CB_TMEMO-1,d2		; shows: the same b, nothing to do (no cb_b49 either)
.q:	cmp.w	(a0),d6
	beq.s	.qf
	tst.w	(a0)
	beq.s	.qx
	addq.l	#TM_SIZE,a0
	dbf	d2,.q
	bra.s	.qx
.qf:	tst.w	TM_B(a0)
	bmi.s	.qx
	cmp.w	TM_V(a0),d0
	bne.s	.qx
	cmp.w	TM_MAX(a0),d1
	beq	.done
.qx:	move.w	d0,d3			; (v, max kept for the memo)
	move.w	d1,d4
	bsr	cb_b49
	move.w	d0,d5
.got:	tst.w	d5
	bgt.s	.b
	moveq	#1,d5
.b:	cmp.w	#49,d5			; b > 49 (v > max): the FPU for each row, as the original
	bgt	.slow
	lea	cb_tmemo,a0		; the bar at this column already shows b: nothing to do
	moveq	#CB_TMEMO-1,d0		; (cb_tmemo_clr when anything else draws there)
.m:	cmp.w	(a0),d6
	beq.s	.mf
	tst.w	(a0)
	beq.s	.mn
	addq.l	#TM_SIZE,a0
	dbf	d0,.m
	bra.s	.mx			; (full: no memo)
.mn:	move.w	d6,(a0)			; a new column
	move.w	#-1,TM_B(a0)
.mf:	move.w	d3,TM_V(a0)		; it will show b for this v and max
	move.w	d4,TM_MAX(a0)
	cmp.w	TM_B(a0),d5
	beq	.done
	move.w	d5,TM_B(a0)
.mx:
	bsr	cb_rtab_init
	move.w	d5,d0			; a3 = the table's row for b
	mulu	#50,d0
	lea	cb_rtab,a3
	add.w	d0,a3
	move.l	a4,-(sp)
	move.w	d6,d0			; a4 = screen[138, x]: one row further each step
	move.w	#138,d1
	bsr	ms_addr
	move.l	a0,a4
	moveq	#0,d4			; i
.i:	moveq	#0,d3			; colour: round(i*part) for i <= b, else 0
	cmp.w	d5,d4
	bgt.s	.c
	move.b	0(a3,d4.w),d3
.c:	move.l	a4,a0			; written and marked only when the row differs
	move.w	d7,d0
	subq.w	#1,d0
.fc:	cmp.b	(a0)+,d3
	dbne	d0,.fc
	beq.s	.fn
	move.l	a4,a0
	move.w	d7,d0
	subq.w	#1,d0
.fw:	move.b	d3,(a0)+
	dbf	d0,.fw
	move.w	d6,d0			; ms_dirty(x, y, x+w-1, y)
	move.w	d4,d1
	add.w	#138,d1
	move.w	d6,d2
	add.w	d7,d2
	subq.w	#1,d2
	move.w	d3,-(sp)
	move.w	d1,d3
	bsr	ms_dirty
	move.w	(sp)+,d3
.fn:	lea	320(a4),a4
	addq.w	#1,d4
	cmp.w	#49,d4
	ble.s	.i
	move.l	(sp)+,a4
.done:	movem.l	(sp)+,d3-d7/a3
	rts
.slow:	bsr	cb_tmemo_clr		; (rows written outside the memo)
	FSSE
	FLDI	31			; part := 31/b; rows 0..b in round(i*part)
	move.w	d5,d0
	bsr	fp_ldw
	bsr	fp_div
	lea	cb_part,a0
	bsr	fp_std
	moveq	#0,d4
.si:	lea	cb_part,a0
	bsr	fp_ldd
	move.w	d4,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,d3
	bsr.s	.row
	addq.w	#1,d4
	cmp.w	d5,d4
	ble.s	.si
	movem.l	(sp)+,d3-d7/a3
	rts
; row i (d4) of the bar in colour d3: written and marked only when it differs
.row:	move.w	d4,d1			; the row: screen[138+i, x..x+w-1]
	add.w	#138,d1
	move.w	d6,d0
	bsr	ms_addr
	move.w	d7,d0
	subq.w	#1,d0
.cmp:	cmp.b	(a0)+,d3
	dbne	d0,.cmp
	beq.s	.n			; all equal: nothing to do
	move.w	d4,d1
	add.w	#138,d1
	move.w	d6,d0
	bsr	ms_addr
	move.w	d7,d0
	subq.w	#1,d0
.w:	move.b	d3,(a0)+
	dbf	d0,.w
	move.w	d6,d0			; ms_dirty(x, y, x+w-1, y)
	move.w	d4,d1
	add.w	#138,d1
	move.w	d6,d2
	add.w	d7,d2
	subq.w	#1,d2
	move.w	d3,-(sp)
	move.w	d1,d3
	bsr	ms_dirty
	move.w	(sp)+,d3
.n:	rts

CB_TMEMO	equ	12
TM_B		equ	2		; cb_tmemo entries: column x, the b it shows (-1: unknown),
TM_V		equ	4		; and the v and max that gave it
TM_MAX		equ	6
TM_SIZE		equ	8
; forget what the target bars show (the area was drawn by something else)
cb_tmemo_clr:
	lea	cb_tmemo,a0
	moveq	#CB_TMEMO*2-1,d0
.c:	clr.l	(a0)+
	dbf	d0,.c
	rts

; cb_rtab[b*50+i] := round(i*(31/b)) (FPC's SSE doubles, banker's), b 1..49, i 0..b: once
cb_rtab_init:
	tst.b	cb_rtab_ok
	bne.s	.x
	movem.l	d3-d4,-(sp)
	FSSE
	moveq	#1,d3			; b
.b:	FLDI	31
	move.w	d3,d0
	bsr	fp_ldw
	bsr	fp_div
	lea	cb_part,a0
	bsr	fp_std
	moveq	#0,d4			; i
.i:	lea	cb_part,a0
	bsr	fp_ldd
	move.w	d4,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d3,d1
	mulu	#50,d1
	add.w	d4,d1
	lea	cb_rtab,a0
	move.b	d0,0(a0,d1.w)
	addq.w	#1,d4
	cmp.w	d3,d4
	ble.s	.i
	addq.w	#1,d3
	cmp.w	#49,d3
	ble.s	.b
	st	cb_rtab_ok
	movem.l	(sp)+,d3-d4
.x:	rts

	section	bss
cb_rtab:	ds.b	50*50
cb_tmemo:	ds.b	CB_TMEMO*TM_SIZE	; target bars: column x, the b it shows, v, max
cb_rcache:	ds.b	8*22		; relx, rely, relz, r (double), valid (+pad)
cb_rnext:	ds.w	1
cb_dskey:	ds.w	4		; displaystats' inputs: hullmax, hull, battery, shieldlevel
		ds.l	1		; + stats[1..3] (one long, written as one)
cb_lct:		ds.w	1
cb_lcb:		ds.w	1
cb_lcs:		ds.b	32
cb_lcreg:	ds.b	6*110
cb_rtab_ok:	ds.b	1
	even
	section	text

; printxy(4, 126, cb_s) - skipped when the same text in the same colours was printed last time
; and its pixels (rows 127-132, x 4 .. 9+5*len) are still in the shadow (speed: the target's
; class line is printed every pass)
cb_classprint:
	movem.l	d3-d4/a3,-(sp)
	moveq	#0,d3
	move.b	cb_s,d3			; w = 5*len + 6 bytes a row
	mulu	#5,d3
	addq.w	#6,d3
	cmp.w	#110,d3			; (longer than the kept rows: always print, keep nothing)
	bhi	.pl
	lea	cb_s,a0			; same string?
	lea	cb_lcs,a1
	moveq	#0,d0
	move.b	(a0),d0
.sc:	cmpm.b	(a0)+,(a1)+
	dbne	d0,.sc
	bne.s	.pr
	move.w	GS_TCOLOR(a6),d0
	cmp.w	cb_lct,d0
	bne.s	.pr
	move.w	GS_BKCOLOR(a6),d0
	cmp.w	cb_lcb,d0
	bne.s	.pr
	lea	cb_lcreg,a3		; the pixels as left by that print?
	moveq	#127,d4
.rc:	moveq	#4,d0
	move.w	d4,d1
	bsr	ms_addr
	move.l	a3,a1			; (both rows even: by longs, then the last bytes)
	move.w	d3,d0
	lsr.w	#2,d0
	subq.w	#1,d0
.cc:	cmpm.l	(a0)+,(a1)+
	dbne	d0,.cc
	bne.s	.pr
	moveq	#3,d0
	and.w	d3,d0
	bra.s	.cbf
.cb:	cmpm.b	(a0)+,(a1)+
	bne.s	.pr
.cbf:	dbf	d0,.cb
	lea	110(a3),a3
	addq.w	#1,d4
	cmp.w	#132,d4
	ble.s	.rc
	bra.s	.x
.pr:	moveq	#4,d0
	moveq	#126,d1
	lea	cb_s,a0
	bsr	printxy
	lea	cb_lcs,a0		; remember the text, colours and pixels
	lea	cb_s,a1
	bsr	pstr_cpy
	move.w	GS_TCOLOR(a6),cb_lct
	move.w	GS_BKCOLOR(a6),cb_lcb
	lea	cb_lcreg,a3
	moveq	#127,d4
.rs:	moveq	#4,d0
	move.w	d4,d1
	bsr	ms_addr
	move.l	a3,a1
	move.w	d3,d0
	subq.w	#1,d0
.cs:	move.b	(a0)+,(a1)+
	dbf	d0,.cs
	lea	110(a3),a3
	addq.w	#1,d4
	cmp.w	#132,d4
	ble.s	.rs
.x:	movem.l	(sp)+,d3-d4/a3
	rts
.pl:	clr.b	cb_lcs
	moveq	#4,d0
	moveq	#126,d1
	lea	cb_s,a0
	bsr	printxy
	bra.s	.x

cb_displaytargetinfo:
	movem.l	d3-d7/a3,-(sp)
	tst.b	cb_done
	bne	.x
	move.w	cb_target,d0
	bsr	cb_ship
	move.l	a0,a3
	lea	cb_r,a0
	move.l	a3,a1
	bsr	cb_range
	tst.b	cb_picmode
	beq.s	.bars
	bsr	cb_displaytargetinfo2
	bra	.x
.bars:	lea	cb_r,a0			; (r again; mousehide: not needed - all of this draws into the
					; shadow, and the flush hides the cursor while it writes. Speed: the
					; cursor is not taken off and put back every pass)
	move.l	a3,a1
	bsr	cb_range
	bsr	cb_classline
	bsr	cb_classprint		; printxy(4,126,...) unless it is already there
	move.w	ALIENSHIP_HULLINTEGRITY(a3),d0	; hull
	move.w	ALIENSHIP_MAXHULL(a3),d1
	moveq	#8,d2
	moveq	#8,d3
	bsr	cb_tbar
	moveq	#100,d0			; life support
	sub.b	ALIENSHIP_DAMAGES+DMG_LIFESUPPORT-1(a3),d0
	and.w	#$ff,d0
	moveq	#100,d1
	moveq	#23,d2
	moveq	#8,d3
	bsr	cb_tbar
	move.w	ALIENSHIP_BATTERY(a3),d0	; battery
	move.w	#32000,d1
	moveq	#38,d2
	moveq	#9,d3
	bsr	cb_tbar
	move.w	ALIENSHIP_SHIELDLEVEL(a3),d0	; shield
	moveq	#100,d1
	moveq	#54,d2
	moveq	#8,d3
	bsr	cb_tbar
	moveq	#1,d7			; the subsystems: columns 62+5*j, one pixel wide
.s:	lea	ALIENSHIP_DAMAGES-1(a3),a0
	moveq	#100,d0
	sub.b	0(a0,d7.w),d0
	and.w	#$ff,d0
	moveq	#100,d1
	move.w	d7,d2
	mulu	#5,d2
	add.w	#62,d2
	moveq	#1,d3
	bsr	cb_tbar
	addq.w	#1,d7
	cmp.w	#7,d7
	ble.s	.s
	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d7/a3
	rts

; the map position of the ship at a0: x := round(relx/range*119), y := round(rely/range*26.66)
; (x87), z := round(relz/range*26)  out: d0 x, d1 y, d2 z
cb_mappos:
	movem.l	d3-d4/a3,-(sp)
	move.l	a0,a3
	move.l	ALIENSHIP_RELX(a3),d0
	moveq	#119,d1
	bsr	cb_mapc
	move.w	d0,d3
	FX87
	move.l	ALIENSHIP_RELY(a3),d0
	bsr	fp_ldi
	move.l	cb_range_,d0
	bsr	fp_ldi
	bsr	fp_div
	FLDX	gx_26_66
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,d4
	FSSE
	move.l	ALIENSHIP_RELZ(a3),d0
	moveq	#26,d1
	bsr	cb_mapc
	move.w	d0,d2
	move.w	d3,d0
	move.w	d4,d1
	movem.l	(sp)+,d3-d4/a3
	rts

; d0.w := round(v / range * m) as FPC's SSE doubles, v = d0.l, m = d1.w (119 or 26),
; range = cb_range_. In integers: floor((2*m*v + range) / (2*range)); the doubles can only
; differ from it at an exact .5 (v/range*m is otherwise at least 1/(2*range) away from one,
; far beyond their error), which goes to the FPU.  trashes d1-d2/a0-a1
cb_mapc:
	movem.l	d3-d5,-(sp)
	move.l	d0,d3			; v
	move.w	d1,d4			; m
	move.l	d3,d2
	bpl.s	.a
	neg.l	d2
.a:	cmp.l	#4000000,d2		; |v| * 2m must stay in 31 bits
	bhi.s	.fpu
	add.w	d1,d1			; 2m
	move.l	d2,d0			; |v| * 2m
	swap	d0
	mulu	d1,d0
	swap	d0
	clr.w	d0
	mulu	d1,d2
	add.l	d0,d2
	tst.l	d3
	bpl.s	.p
	neg.l	d2
.p:	move.l	cb_range_,d5
	add.l	d5,d2			; num = 2m*v + range
	add.l	d5,d5			; den = 2*range
	tst.l	d2
	bmi.s	.neg
	move.l	d5,d0
	bsr	ex_ldiv			; d0 = num div den, d1 = remainder
	tst.l	d1
	beq.s	.fpu			; a .5
	bra.s	.x
.neg:	neg.l	d2			; floor of a negative: -ceil(|num|/den)
	move.l	d5,d0
	bsr	ex_ldiv
	tst.l	d1
	beq.s	.fpu
	addq.l	#1,d0
	neg.l	d0
.x:	movem.l	(sp)+,d3-d5
	rts
.fpu:	FSSE
	move.l	d3,d0
	bsr	fp_ldi
	move.l	cb_range_,d0
	bsr	fp_ldi
	bsr	fp_div
	move.w	d4,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	movem.l	(sp)+,d3-d5
	rts

; screen[y d1, x d0] := screen xor d2 (marked)
cb_xor:
	movem.w	d0-d2,-(sp)
	bsr	ms_addr
	movem.w	(sp)+,d0-d2
	eor.b	d2,(a0)
	move.w	d3,-(sp)
	move.w	d0,d2
	move.w	d1,d3
	bsr	ms_dirty
	move.w	(sp)+,d3
	rts

cb_displaymap:
	movem.l	d3-d7/a3,-(sp)
	tst.b	cb_dead
	bne	.x
	moveq	#1,d7			; (mousehide: not needed, shadow only - see displaytargetinfo)
.j:	cmp.w	cb_nships,d7
	bgt	.d
	move.w	d7,d0
	bsr	cb_ship
	move.l	a0,a3
	bsr	cb_mappos
	move.w	d0,d3			; x
	move.w	d1,d4			; y
	move.w	d2,d5			; z
	move.w	d3,d0			; abs(x) < 119, abs(y) < 26, abs(z) < 35
	bpl.s	.ax
	neg.w	d0
.ax:	cmp.w	#119,d0
	bge	.n
	move.w	d4,d0
	bpl.s	.ay
	neg.w	d0
.ay:	cmp.w	#26,d0
	bge	.n
	move.w	d5,d0
	bpl.s	.az
	neg.w	d0
.az:	cmp.w	#35,d0
	bge	.n
	add.w	#132,d3			; x+132
	add.w	#62,d4			; y+62
	move.w	d4,d6			; the stalk: rows y+62 .. y+62-z, xor 6
	sub.w	d5,d6
	move.w	d4,d1
	cmp.w	d6,d1
	ble.s	.up
	exg	d1,d6
.up:	move.w	d1,cb_i
.st:	move.w	d3,d0
	moveq	#6,d2
	bsr	cb_xor
	addq.w	#1,d1
	cmp.w	d6,d1
	ble.s	.st
	move.w	d3,d0			; the base: xor 85
	move.w	d4,d1
	moveq	#85,d2
	bsr	cb_xor
	moveq	#31,d2			; the ship: xor 31 (12 when destroyed)
	tst.w	ALIENSHIP_HULLINTEGRITY(a3)
	bne.s	.al
	moveq	#12,d2
.al:	move.w	d2,cb_i
	move.w	d3,d0
	move.w	d4,d1
	sub.w	d5,d1
	bsr	cb_xor
	cmp.w	cb_target,d7
	bne.s	.n
	move.w	d4,d6			; the target's corners: xor 60
	sub.w	d5,d6			; (y+62-z)
	lea	.corn,a1
	moveq	#6-1,d5
.c:	move.b	(a1)+,d0
	ext.w	d0
	add.w	d3,d0
	move.b	(a1)+,d1
	ext.w	d1
	add.w	d6,d1
	moveq	#60,d2
	movem.l	d5/a1,-(sp)
	bsr	cb_xor
	movem.l	(sp)+,d5/a1
	dbf	d5,.c
.n:	addq.w	#1,d7
	bra	.j
.d:	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d7/a3
	rts
.corn:	dc.b	-2,-2,-1,-2,-2,-1,1,2,2,2,2,1	; (dx, dy)
	even

; drawdirection(colour d0)
cb_drawdirection:
	movem.l	d3-d4,-(sp)
	move.w	d0,d4
	bsr	mousehide		; (first: it trashes d0-d2)
	move.w	cb_shipdir,d0		; x := ((dir-1) mod 3)*12+225, y := ((dir-1) div 3)*10+88
	subq.w	#1,d0
	ext.l	d0
	divs	#3,d0
	move.w	d0,d1
	mulu	#10,d1
	add.w	#88,d1
	swap	d0
	muls	#12,d0
	add.w	#225,d0
	move.w	d0,GS_X(a6)
	move.w	d1,GS_Y(a6)
	move.w	d0,d2
	add.w	#12,d2
	move.w	d1,d3
	add.w	#10,d3
	bsr	ms_rect
	cmp.w	#1,cb_shipdir2
	bne.s	.d2
	move.w	#249,d0
	moveq	#68,d1
	move.w	#261,d2
	moveq	#78,d3
	bsr	ms_rect
	bra.s	.ms
.d2:	cmp.w	#2,cb_shipdir2
	bne.s	.ms
	move.w	#249,d0
	moveq	#78,d1
	move.w	#261,d2
	moveq	#88,d3
	bsr	ms_rect
.ms:	bsr	mouseshow
	movem.l	(sp)+,d3-d4
	rts

; takedamage(n d0, d d1)
cb_takedamage:
	movem.l	d3-d4,-(sp)
	tst.b	cb_dead
	bne	.x
	move.w	d0,d3
	move.w	d1,d4
	moveq	#2,d0			; soundeffect('explode'+chr(49+random(2)), 9000)
	bsr	mt_random
	add.w	#9,d0
	move.w	#9000,d1
	bsr	cb_sound
	move.w	GS_TSLICE(a6),d0	; delay(tslice div 2)
	lsr.w	#1,d0
	bsr	delay
	cmp.w	#1,d4
	bge.s	.d
	moveq	#1,d4
.d:	lea	GS_SHIP+SHIP_DAMAGES-1(a6),a1
	cmp.w	#DMGTYP_PSIONIC,d3
	bne.s	.n2
	add.b	d4,DMG_LIFESUPPORT(a1)
	bra	.e
.n2:	cmp.w	#DMGTYP_PARTICLE,d3
	bne.s	.n3
	sub.w	d4,GS_SHIP+SHIP_HULLINTEGRITY(a6)
	bra	.e
.n3:	cmp.w	#DMGTYP_INERTIAL,d3
	bne.s	.n4
	move.w	d4,d0
	ext.l	d0
	divs	#2,d0
	sub.w	d0,GS_SHIP+SHIP_HULLINTEGRITY(a6)
	bra	.e
.n4:	cmp.w	#DMGTYP_ENERGY,d3
	bne	.n5
	moveq	#8,d0
	bsr	mt_random
	lea	GS_SHIP+SHIP_DAMAGES-1(a6),a1
	tst.w	d0
	bne.s	.e1
	add.b	d4,DMG_POWER(a1)
	bra	.e
.e1:	cmp.w	#1,d0
	bne.s	.e2
	moveq	#0,d0			; shield: > 135 destroys it
	move.b	DMG_SHIELD(a1),d0
	add.w	d4,d0
	cmp.w	#135,d0
	ble.s	.e1b
	move.w	#ID_NOSHIELD,GS_SHIP+SHIP_SHIELD(a6)
.e1b:	lea	GS_SHIP+SHIP_DAMAGES-1(a6),a1
	add.b	d4,DMG_SHIELD(a1)
	bra	.e
.e2:	cmp.w	#2,d0
	bne.s	.e3
	add.b	d4,DMG_ENGINES(a1)
	cmp.b	#89,DMG_ENGINES(a1)
	bls	.e
	moveq	#95,d0
	bsr	cb_drawdirection
	bra	.e
.e3:	cmp.w	#3,d0
	bne.s	.e4
	moveq	#0,d0			; weapons: > 120 destroys a random gun
	move.b	DMG_WEAPONS(a1),d0
	add.w	d4,d0
	cmp.w	#120,d0
	ble.s	.e3b
	moveq	#10,d0
	bsr	mt_random
	addq.w	#1,d0
	lea	GS_SHIP+SHIP_GUNNODES-1(a6),a0
	tst.b	0(a0,d0.w)
	beq.s	.e3b
	clr.b	0(a0,d0.w)
	add.w	d0,d0
	lea	cb_powered-2,a0
	move.w	#-1,0(a0,d0.w)
	bsr	cb_displayweapons
.e3b:	lea	GS_SHIP+SHIP_DAMAGES-1(a6),a1
	add.b	d4,DMG_WEAPONS(a1)
	bra.s	.e
.e4:	cmp.w	#4,d0
	bne.s	.e5
	add.b	d4,DMG_COMM(a1)
	bra.s	.e
.e5:	cmp.w	#5,d0
	bne.s	.e6
	add.b	d4,DMG_CPU(a1)
	bra.s	.e
.e6:	sub.w	d4,GS_SHIP+SHIP_HULLINTEGRITY(a6)
	bra.s	.e
.n5:	cmp.w	#DMGTYP_FAKE_SHLD,d3
	bne.s	.e
	add.b	d4,DMG_SHIELD(a1)
.e:	lea	GS_SHIP+SHIP_DAMAGES(a6),a0
	moveq	#7-1,d0
.l:	cmp.b	#100,(a0)
	bls.s	.ln
	move.b	#100,(a0)
.ln:	addq.l	#1,a0
	dbf	d0,.l
	tst.w	GS_SHIP+SHIP_HULLINTEGRITY(a6)
	bpl.s	.h
	clr.w	GS_SHIP+SHIP_HULLINTEGRITY(a6)
.h:	bsr	cb_displaydamage
	tst.w	GS_SHIP+SHIP_HULLINTEGRITY(a6)
	beq.s	.death
	cmp.b	#100,GS_SHIP+SHIP_DAMAGES+DMG_LIFESUPPORT-1(a6)
	bne.s	.refl
.death:	cmp.w	#1013,GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6)
	bne	deathsequence
	bsr	stopmod			; the drones' practice: a red flash, nothing more
	moveq	#63,d0
	moveq	#0,d1
	moveq	#0,d2
	bsr	wd_blast
	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	st	cb_done
	st	cb_dead
.refl:	cmp.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)
	bne.s	.x
	moveq	#100,d0
	sub.b	GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6),d0
	and.w	#$ff,d0
	move.w	d0,GS_SHIP+SHIP_SHIELDLEVEL(a6)
.x:	movem.l	(sp)+,d3-d4
	rts

; weird.pas deathsequence: the music stops, a red flash, the program ends (exit code 3)
deathsequence:
	bsr	stopmod
	moveq	#63,d0
	moveq	#0,d1
	moveq	#0,d2
	bsr	wd_blast
	moveq	#3,d0
	bra	sys_exit

; impact(s d0, n d1): the ship s hits us with weapon n
cb_impact:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,d0
	bsr	cb_ship
	move.l	a0,a5			; the attacker
	move.w	d1,d0
	bsr	cb_weap
	move.l	a0,a4			; weapons[n]
	move.w	GS_SHIP+SHIP_SHIELD(a6),d0	; weapons[b]: our shield
	sub.w	#ID_SHIELDS_OFFSET,d0
	bsr	cb_weap
	move.l	a0,a3
	moveq	#1,d7			; j
.j:	tst.b	WEAPON_DMGTYPES-1(a4,d7.w)
	beq	.jn
	FSSE				; i := round(dmgtypes[j]/100*damage*5)
	moveq	#0,d0
	move.b	WEAPON_DMGTYPES-1(a4,d7.w),d0
	bsr	fp_ldw
	FLDI	100
	bsr	fp_div
	move.w	WEAPON_DAMAGE(a4),d0
	bsr	fp_ldw
	bsr	fp_mul
	FLDI	5
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,d6
	FSSE				; i := round(i/100*(100-attacker's weapons damage))
	bsr	fp_ldw
	FLDI	100
	bsr	fp_div
	moveq	#100,d0
	sub.b	ALIENSHIP_DAMAGES+DMG_WEAPONS-1(a5),d0
	and.w	#$ff,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,d6			; i
	tst.w	GS_SHIP+SHIP_SHIELDLEVEL(a6)
	beq.s	.full
	cmp.w	#ID_NOSHIELD,GS_SHIP+SHIP_SHIELD(a6)
	ble.s	.full
	tst.b	WEAPON_DMGTYPES-1(a3,d7.w)
	bne.s	.sh
.full:	move.w	d7,d0
	move.w	d6,d1
	bsr	cb_takedamage
	bra	.jn
.sh:	moveq	#0,d0			; a := round(sdmgtypes[j]/100*sdamage*shieldlevel/100)
	move.b	WEAPON_DMGTYPES-1(a3,d7.w),d0
	bsr	fp_ldw
	FLDI	100
	bsr	fp_div
	move.w	WEAPON_DAMAGE(a3),d0
	bsr	fp_ldw
	bsr	fp_mul
	move.w	GS_SHIP+SHIP_SHIELDLEVEL(a6),d0
	bsr	fp_ldw
	bsr	fp_mul
	FLDI	100
	bsr	fp_div
	bsr	fp_rnd
	move.w	d0,d5			; a
	cmp.w	d6,d5
	bge.s	.hold
	move.w	d7,d0			; overload: takedamage(j, i-a); shields 0
	move.w	d6,d1
	sub.w	d5,d1
	bsr	cb_takedamage
	clr.w	GS_SHIP+SHIP_SHIELDLEVEL(a6)
	bsr	.refl
	bsr	cb_displaydamage
	bra	.jn
.hold:	move.w	d6,d0			; a := round(i/(shieldlevel/100*sdamage)*100)
	bsr	fp_ldw
	move.w	GS_SHIP+SHIP_SHIELDLEVEL(a6),d0
	bsr	fp_ldw
	FLDI	100
	bsr	fp_div
	move.w	WEAPON_DAMAGE(a3),d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_div
	FLDI	100
	bsr	fp_mul
	bsr	fp_rnd
	move.w	GS_SHIP+SHIP_SHIELDLEVEL(a6),d4	; c := shieldlevel - a
	sub.w	d0,d4
	bpl.s	.pos
	moveq	#3,d0			; below zero: takedamage(FAKE_SHLD, random(3)+1), shields 0
	bsr	mt_random
	addq.w	#1,d0
	move.w	d0,d1
	moveq	#DMGTYP_FAKE_SHLD,d0
	bsr	cb_takedamage
	clr.w	GS_SHIP+SHIP_SHIELDLEVEL(a6)
	bsr	.refl
	bsr	cb_displaydamage
	bra.s	.jn
.pos:	move.w	d4,GS_SHIP+SHIP_SHIELDLEVEL(a6)
	cmp.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)
	bne.s	.jn
	cmp.w	#DMGTYP_PSIONIC,d7
	ble.s	.jn
	moveq	#100,d0
	sub.w	d4,d0
	move.b	d0,GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6)
	bsr	cb_displaydamage
.jn:	addq.w	#1,d7
	cmp.w	#4,d7
	ble	.j
	bsr	cb_displaystats
	movem.l	(sp)+,d3-d7/a3-a5
	rts
.refl:	cmp.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)
	bne.s	.rx
	cmp.w	#DMGTYP_PSIONIC,d7
	ble.s	.rx
	move.b	#100,GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6)
.rx:	rts

; one velocity component (v at a0, word; rel d0.l): the alien's steering
cb_steer:
	move.w	ALIENSHIP_ACCELMAX(a3),d1
	cmp.l	#5000,d0		; rel < 5000 and rel > 0 and v < -3000: v += accel
	bge.s	.b
	tst.l	d0
	ble.s	.b
	cmp.w	#-3000,(a0)
	bge.s	.b
	add.w	d1,(a0)
	rts
.b:	cmp.l	#-5000,d0		; rel > -5000 and rel < 0 and v > 3000: v -= accel
	ble.s	.c
	tst.l	d0
	bpl.s	.c
	cmp.w	#3000,(a0)
	ble.s	.c
	sub.w	d1,(a0)
	rts
.c:	tst.l	d0			; rel > 0 and v > -1000: v -= accel
	ble.s	.d
	cmp.w	#-1000,(a0)
	ble.s	.d
	sub.w	d1,(a0)
	rts
.d:	tst.l	d0			; rel < 0 and v < 1000: v += accel
	bpl.s	.x
	cmp.w	#1000,(a0)
	bge.s	.x
	add.w	d1,(a0)
.x:	rts

; v (word at a0) := round(v*0.9)  (x87)
cb_slow:
	move.l	a0,-(sp)
	FX87
	move.w	(a0),d0
	bsr	fp_ldw
	FLDX	gx_0_9
	bsr	fp_mul
	bsr	fp_rnd
	FSSE
	move.l	(sp)+,a0
	move.w	d0,(a0)
	rts
; rel (long at a1) += round(v/5) (v word at a0)
; (a1).l += round((a0).w / 5): dx/5 is never within 0.1 of a .5, so the nearest integer,
; floor((2*dx+5)/10), is the double's banker's rounding (no FPU)
cb_move:
	move.w	(a0),d0
	ext.l	d0
	add.l	d0,d0
	add.l	#5+70000,d0		; (+70000: positive for divu; dx >= -32768)
	divu	#10,d0
	and.l	#$ffff,d0
	sub.l	#7000,d0
	add.l	d0,(a1)
	rts

cb_moveships:
	movem.l	d3-d7/a3-a5,-(sp)
	moveq	#1,d7			; j
.j:	cmp.w	cb_nships,d7
	bgt	.end
	move.w	d7,d0
	bsr	cb_ship
	move.l	a0,a3
	cmp.w	#5,cb_moveindex
	bne	.mv
	tst.w	ALIENSHIP_HULLINTEGRITY(a3)
	ble	.mv
	cmp.b	#90,ALIENSHIP_DAMAGES+DMG_ENGINES-1(a3)
	bhs.s	.s9
	lea	ALIENSHIP_DX(a3),a0	; steering
	move.l	ALIENSHIP_RELX(a3),d0
	bsr	cb_steer
	lea	ALIENSHIP_DY(a3),a0
	move.l	ALIENSHIP_RELY(a3),d0
	bsr	cb_steer
	lea	ALIENSHIP_DZ(a3),a0
	move.l	ALIENSHIP_RELZ(a3),d0
	bsr	cb_steer
.s9:	cmp.b	#90,ALIENSHIP_DAMAGES+DMG_ENGINES-1(a3)
	bls.s	.mv
	lea	ALIENSHIP_DX(a3),a0	; engines gone: slowing down
	bsr	cb_slow
	lea	ALIENSHIP_DY(a3),a0
	bsr	cb_slow
	lea	ALIENSHIP_DZ(a3),a0
	bsr	cb_slow
.mv:	lea	ALIENSHIP_DX(a3),a0	; rel += round(d/5)
	lea	ALIENSHIP_RELX(a3),a1
	bsr	cb_move
	lea	ALIENSHIP_DY(a3),a0
	lea	ALIENSHIP_RELY(a3),a1
	bsr	cb_move
	lea	ALIENSHIP_DZ(a3),a0
	lea	ALIENSHIP_RELZ(a3),a1
	bsr	cb_move
	lea	cb_rl,a0		; r (local) := sqrt(rt)*100: (relx/10)*(relx/10) + ...
	move.l	a3,a1
	bsr	cb_range
	move.w	GS_SHIP+SHIP_ACCELMAX(a6),d0	; our own movement
	cmp.b	#89,GS_SHIP+SHIP_DAMAGES+DMG_ENGINES-1(a6)
	bls.s	.ac
	ext.l	d0
	divs	#4,d0
.ac:	ext.l	d0
	move.w	cb_shipdir,d1
	cmp.w	#4,d1
	bge.s	.d1
	add.l	d0,ALIENSHIP_RELY(a3)
	bra.s	.d2
.d1:	cmp.w	#6,d1
	ble.s	.d2
	sub.l	d0,ALIENSHIP_RELY(a3)
.d2:	ext.l	d1
	divs	#3,d1
	swap	d1
	cmp.w	#1,d1
	bne.s	.d3
	add.l	d0,ALIENSHIP_RELX(a3)
	bra.s	.d4
.d3:	tst.w	d1
	bne.s	.d4
	sub.l	d0,ALIENSHIP_RELX(a3)
.d4:	cmp.w	#1,cb_shipdir2
	bne.s	.d5
	sub.l	d0,ALIENSHIP_RELZ(a3)
	bra.s	.d6
.d5:	cmp.w	#2,cb_shipdir2
	bne.s	.d6
	add.l	d0,ALIENSHIP_RELZ(a3)
.d6:	move.l	ALIENSHIP_RANGE(a3),d0	; part := ships^[j].range
	FSSE
	bsr	fp_ldi
	lea	cb_part,a0
	bsr	fp_std
	tst.w	ALIENSHIP_HULLINTEGRITY(a3)
	ble	.far
	moveq	#1,d6			; a: the charges
.ch:	lea	ALIENSHIP_CHARGES-1(a3),a0
	cmp.b	#100,0(a0,d6.w)
	bne	.cn
	lea	cb_part,a0		; part >= r (part: impact may have changed it on an earlier
	bsr	fp_ldd			; charge of this loop - a global in the original)
	lea	cb_rl,a0
	bsr	fp_ldd
	bsr	fp_cmp
	bmi	.cn			; (out of range: the charge waits)
	moveq	#120,d0			; i := random(120) - 15*difficulty
	bsr	mt_random
	moveq	#0,d1
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_DIFFICULTY-1(a6),d1
	mulu	#15,d1
	sub.w	d1,d0
	move.w	d0,cb_i
	st	ct_bg			; not SkillTest(true, 4, skill + scanning*20, learnchance): a hit
	moveq	#4,d0
	move.w	ALIENSHIP_SKILL(a3),d1
	tst.b	cb_scanning
	beq.s	.sk
	add.w	#20,d1
.sk:	move.w	cb_learn,d2
	bsr	ct_skilltest
	tst.w	d0
	bne.s	.cz
	bsr	cb_displaymap
	cmp.b	#100,ALIENSHIP_DAMAGES+DMG_WEAPONS-1(a3)
	bhs.s	.nf
	tst.w	ALIENSHIP_BATTERY(a3)
	ble.s	.nf
	move.w	d7,d0
	moveq	#MAXWEAPONS,d1
	bsr	cb_impact
.nf:	bsr	cb_displaymap
.cz:	lea	ALIENSHIP_CHARGES-1(a3),a0
	clr.b	0(a0,d6.w)
.cn:	addq.w	#1,d6
	cmp.w	#20,d6
	ble	.ch
.far:	lea	cb_rl,a0		; abs(r) > 1200000: gone
	bsr	cb_r2
	cmp.l	#2*1200000,d0
	ble.s	.al
	clr.w	ALIENSHIP_HULLINTEGRITY(a3)
.al:	tst.w	ALIENSHIP_HULLINTEGRITY(a3)
	bne.s	.jn
	cmp.w	cb_target,d7
	bne.s	.jn
	bsr	cb_firstalive
.jn:	addq.w	#1,d7
	bra	.j
.end:	cmp.w	#5,cb_moveindex
	bne.s	.mi
	clr.w	cb_moveindex
	bra.s	.x
.mi:	addq.w	#1,cb_moveindex
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts

cb_previoustarget:
	bsr	cb_displaymap
	subq.w	#1,cb_target
	bsr.s	.dn
	tst.w	cb_target
	bne.s	.x
	move.w	cb_nships,cb_target
	bsr.s	.dn
.x:	bra	cb_displaymap
.dn:	move.w	cb_target,d0		; while (t > 0) and ships^[t] dead: dec(t)
	ble.s	.r
	bsr	cb_ship
	tst.w	ALIENSHIP_HULLINTEGRITY(a0)
	bne.s	.r
	subq.w	#1,cb_target
	bra.s	.dn
.r:	rts

cb_nexttarget:
	bsr	cb_displaymap
	addq.w	#1,cb_target
.u:	move.w	cb_target,d0		; while (t <= nships) and dead: inc(t)
	cmp.w	cb_nships,d0
	bgt.s	.o
	bsr	cb_ship
	tst.w	ALIENSHIP_HULLINTEGRITY(a0)
	bne.s	.o
	addq.w	#1,cb_target
	bra.s	.u
.o:	move.w	cb_target,d0		; (t > nships) or ships^[t] dead: from 1
	cmp.w	cb_nships,d0
	bgt.s	.f
	bsr	cb_ship
	tst.w	ALIENSHIP_HULLINTEGRITY(a0)
	bne.s	.x
.f:	move.w	#1,cb_target
.w:	move.w	cb_target,d0		; while (t < nships) and dead: inc(t)
	cmp.w	cb_nships,d0
	bge.s	.x
	bsr	cb_ship
	tst.w	ALIENSHIP_HULLINTEGRITY(a0)
	bne.s	.x
	addq.w	#1,cb_target
	bra.s	.w
.x:	bra	cb_displaymap

cb_switchalienmode:
	movem.l	d3,-(sp)
	bsr	cb_tmemo_clr
	bsr	mousehide
	BAR	6,125,98,189,0
	tst.b	cb_picmode
	bne.s	.off
	move.w	#156,d3			; rows 156-189 from asdisplay
	st	cb_picmode
	bra.s	.c
.off:	move.w	#125,d3			; rows 125-155
	sf	cb_picmode
.c:	move.w	d3,d0			; asdisplay^[i, 6..98] -> screen
	sub.w	#125,d0
	mulu	#93,d0
	move.l	cb_asdisplay,a1
	add.l	d0,a1
	moveq	#6,d0
	move.w	d3,d1
	bsr	ms_addr
	moveq	#93-1,d0
.cc:	move.b	(a1)+,(a0)+
	dbf	d0,.cc
	addq.w	#1,d3
	cmp.w	#189,d3
	bgt.s	.d
	tst.b	cb_picmode
	bne.s	.c
	cmp.w	#155,d3
	ble.s	.c
.d:	bsr	mouseshow
	movem.l	(sp)+,d3
	rts

cb_setdir:
	cmp.b	#89,GS_SHIP+SHIP_DAMAGES+DMG_ENGINES-1(a6)
	bhi.s	.x
	move.w	d0,-(sp)
	moveq	#0,d0
	bsr	cb_drawdirection
	move.w	(sp)+,d0
	move.w	d0,cb_shipdir
	cmp.w	#5,d0
	bne.s	.d
	clr.w	cb_shipdir2
.d:	moveq	#63,d0
	bra	cb_drawdirection
.x:	rts
cb_setdir2:
	cmp.b	#89,GS_SHIP+SHIP_DAMAGES+DMG_ENGINES-1(a6)
	bhi.s	.x
	move.w	d0,-(sp)
	moveq	#0,d0
	bsr	cb_drawdirection
	move.w	(sp)+,cb_shipdir2
	moveq	#63,d0
	bra	cb_drawdirection
.x:	rts

; findtarget: a ship near the mouse on the map
cb_findtarget:
	movem.l	d3-d7/a3,-(sp)
	bsr	kbd_mouse_xy
	move.w	d0,d6
	move.w	d1,d7
	cmp.w	#6,d6
	blt	.x
	cmp.w	#259,d6
	bgt	.x
	cmp.w	#6,d7
	blt	.x
	cmp.w	#117,d7
	bgt	.x
	moveq	#1,d3			; j
.j:	cmp.w	cb_nships,d3
	bgt	.x
	move.w	d3,d0
	bsr	cb_ship
	move.l	a0,a3
	bsr	cb_mappos		; z, y := 62+round(rely..)-z, x := 132+round(relx..)
	move.w	d2,d5
	add.w	#132,d0
	add.w	#62,d1
	sub.w	d5,d1
	move.w	d0,GS_X(a6)
	move.w	d1,GS_Y(a6)
	sub.w	d6,d0
	bpl.s	.a
	neg.w	d0
.a:	cmp.w	#5,d0
	bge.s	.n
	sub.w	d7,d1
	bpl.s	.b
	neg.w	d1
.b:	cmp.w	#5,d1
	bge.s	.n
	tst.w	ALIENSHIP_HULLINTEGRITY(a3)
	ble.s	.n
	bsr	cb_displaymap
	move.w	d3,cb_target
	bsr	cb_displaymap
	bsr	cb_displaytargetinfo
	move.w	cb_nships,d3		; j := nships
.n:	addq.w	#1,d3
	bra.s	.j
.x:	movem.l	(sp)+,d3-d7/a3
	rts

cb_displaytimedelay:
	TCOL	63
	moveq	#0,d0
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_TIMESLICE-1(a6),d0
	moveq	#3,d1
	lea	cb_s,a0
	bsr	int_str
	bsr	mousehide
	move.w	#277,d0
	moveq	#2,d1
	lea	cb_s,a0
	bsr	printxy
	bsr	mouseshow
	TCOL	95
	rts

cb_zoom:				; d0 = -5000 or 5000: range, the label
	move.w	d0,-(sp)
	bsr	cb_displaymap
	move.w	(sp)+,d0
	ext.l	d0
	add.l	d0,cb_range_
	move.l	cb_range_,d0		; str(range*10:7)
	add.l	d0,d0
	move.l	d0,d1
	add.l	d1,d1
	add.l	d1,d1
	add.l	d1,d0
	moveq	#7,d1
	lea	cb_s,a0
	bsr	int_str
	moveq	#33,d0
	moveq	#110,d1
	lea	cb_s,a0
	bsr	printxy
	bra	cb_displaymap
cb_zoomin:
	cmp.l	#5000,cb_range_
	ble.s	.x
	move.w	#-5000,d0
	bra.s	cb_zoom
.x:	rts
cb_zoomout:
	cmp.l	#5000000,cb_range_
	bge.s	.x
	move.w	#5000,d0
	bra.s	cb_zoom
.x:	rts
cb_toggleauto:
	not.b	cb_autofire
	moveq	#125,d0
	bra.s	cb_light
cb_togglescan:
	not.b	cb_scanning
	move.w	#187,d0
	move.b	cb_scanning,d1
	bra.s	cb_light2
cb_light:
	move.b	cb_autofire,d1
cb_light2:				; rows d0, d0+1 at 163 (52 wide): 63 when on, 95 off
	movem.l	d3-d4,-(sp)
	moveq	#95,d4
	tst.b	d1
	beq.s	.c
	moveq	#63,d4
.c:	move.w	d0,d3
	bsr	mousehide
	move.w	d3,d1
	addq.w	#1,d3
	move.w	#163,d0
	move.w	#214,d2
	bsr	ms_bar
	bsr	mouseshow
	movem.l	(sp)+,d3-d4
	rts

; the power switch of gun node j (d0): plainfadearea(x, y, x+12, y+2, +-32), userpowerup toggled
cb_powswitch:
	movem.l	d3-d4,-(sp)
	move.w	d0,d3
	subq.w	#1,d0			; x := 109 + ((j-1) mod 5)*23, y := 152 + ((j-1) div 5)*7
	ext.l	d0
	divu	#5,d0
	move.w	d0,d1
	mulu	#7,d1
	add.w	#152,d1
	swap	d0
	mulu	#23,d0
	add.w	#109,d0
	lea	cb_userpow-1,a0
	moveq	#32,d4
	tst.b	0(a0,d3.w)
	bne.s	.off
	moveq	#-32,d4
.off:	not.b	0(a0,d3.w)
	move.w	d0,d2
	add.w	#12,d2
	move.w	d1,d3
	addq.w	#2,d3
	bsr	plainfadearea
	movem.l	(sp)+,d3-d4
	rts

cb_findmouse:
	movem.l	d3-d4,-(sp)
	bsr	kbd_mouse_status
	tst.b	d0
	beq	.x
	bsr	kbd_mouse_xy
	move.w	d0,d3
	move.w	d1,d4
	moveq	#0,d2			; the five gun columns: x 105+23*k .. +20
.k:	move.w	d2,d0
	mulu	#23,d0
	add.w	#105,d0
	cmp.w	d0,d3
	blt.s	.kn
	add.w	#20,d0
	cmp.w	d0,d3
	ble	.gun
.kn:	addq.w	#1,d2
	cmp.w	#5,d2
	bne.s	.k
	cmp.w	#195,d3			; 195..196: the alien mode switch
	blt.s	.r2
	cmp.w	#196,d3
	bgt.s	.r2
	cmp.w	#191,d4
	blt	.ft
	cmp.w	#195,d4
	bgt	.ft
	bsr	cb_switchalienmode
	bra	.x
.r2:	cmp.w	#223,d3			; 223..225: previous target
	blt.s	.r3
	cmp.w	#225,d3
	bgt.s	.r3
	cmp.w	#184,d4
	ble	.x
	cmp.w	#193,d4
	bge	.x
	bsr	cb_previoustarget
	bra	.x
.r3:	cmp.w	#226,d3
	blt	.ft
	cmp.w	#242,d3
	bgt	.r4
	cmp.w	#124,d4			; 226..242
	blt.s	.r3b
	cmp.w	#144,d4
	bgt.s	.r3b
	bsr	cb_zoomin
	bra	.x
.r3b:	cmp.w	#151,d4
	blt.s	.r3c
	cmp.w	#173,d4
	bgt.s	.r3c
	bsr	cb_toggleauto
	bra	.x
.r3c:	cmp.w	#185,d4
	blt.s	.r3d
	cmp.w	#192,d4
	bgt.s	.r3d
	cmp.w	#241,d3
	bge	.x
	bsr	cb_previoustarget
	bra	.x
.r3d:	moveq	#1,d0			; direction pads 89-97, 99-107, 109-117
	bsr	.pad
	bne	.x
	bra	.ft
.r4:	cmp.w	#244,d3
	blt	.ft
	cmp.w	#260,d3
	bgt	.r5
	cmp.w	#124,d4
	blt.s	.r4b
	cmp.w	#144,d4
	bgt.s	.r4b
	bsr	cb_zoomout
	bra	.x
.r4b:	cmp.w	#151,d4
	blt.s	.r4c
	cmp.w	#173,d4
	bgt.s	.r4c
	bsr	cb_togglescan
	bra	.x
.r4c:	cmp.w	#185,d4
	blt.s	.r4d
	cmp.w	#192,d4
	bgt.s	.r4d
	cmp.w	#245,d3
	ble	.x
	bsr	cb_nexttarget
	bra	.x
.r4d:	cmp.w	#69,d4			; up/down pads 69-77 / 79-87 (x > 248)
	blt.s	.r4e
	cmp.w	#77,d4
	bgt.s	.r4e
	cmp.w	#248,d3
	ble	.x
	moveq	#1,d0
	bsr	cb_setdir2
	bra	.x
.r4e:	cmp.w	#79,d4
	blt.s	.r4f
	cmp.w	#87,d4
	bgt.s	.r4f
	cmp.w	#248,d3
	ble	.x
	moveq	#2,d0
	bsr	cb_setdir2
	bra	.x
.r4f:	moveq	#2,d0			; pads: x < 249: 2/5/8, else 3/6/9
	bsr	.pad2
	bne	.x
	bra	.ft
.r5:	cmp.w	#261,d3
	blt	.ft
	cmp.w	#263,d3
	bgt.s	.r6
	cmp.w	#184,d4
	ble	.ft
	cmp.w	#193,d4
	bge	.ft
	bsr	cb_nexttarget
	bra	.x
.r6:	cmp.w	#271,d3			; 271..279, y < 10: slower
	blt	.ft
	cmp.w	#279,d3
	bgt.s	.r7
	cmp.w	#10,d4
	bge	.x
	cmp.b	#1,GS_SHIP+SHIP_OPTIONS+OPT_TIMESLICE-1(a6)
	bls	.x
	subq.b	#1,GS_SHIP+SHIP_OPTIONS+OPT_TIMESLICE-1(a6)
	bra.s	.ts
.r7:	cmp.w	#291,d3
	blt	.ft
	cmp.w	#312,d3
	bgt	.ft
	cmp.w	#11,d4			; 291..312: 11..117 the shield setting; 1..9 (x 300..308) faster
	blt.s	.r7b
	cmp.w	#117,d4
	bgt	.x
	move.w	#117,d0			; round((117-y)*100/102)
	sub.w	d4,d0
	mulu	#100,d0
	FSSE
	bsr	fp_ldi
	FLDI	102
	bsr	fp_div
	bsr	fp_rnd
	bsr	cb_displayshieldpic
	bra	.x
.r7b:	cmp.w	#1,d4
	blt	.x
	cmp.w	#299,d3
	ble	.x
	cmp.w	#309,d3
	bge	.x
	cmp.b	#255,GS_SHIP+SHIP_OPTIONS+OPT_TIMESLICE-1(a6)
	bhs	.x
	addq.b	#1,GS_SHIP+SHIP_OPTIONS+OPT_TIMESLICE-1(a6)
.ts:	moveq	#0,d0
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_TIMESLICE-1(a6),d0
	move.w	d0,GS_TSLICE(a6)
	bsr	cb_displaytimedelay
	bra	.x
.gun:	addq.w	#1,d2			; gun column k+1 (1-5): rows 131-151 fire k, 162-182 fire k+5,
	cmp.w	#131,d4			; 152-156 / 157-161 the power switches (x inside), 191-195 the
	blt	.ft			; mode switch from the 4th (x > 183) / 5th (x < 209) column
	cmp.w	#151,d4
	bgt.s	.g2
	move.w	d2,cb_fire
	bra	.x
.g2:	move.w	d2,d0
	mulu	#23,d0
	add.w	#82,d0			; (105-23+... : the switch's x range: 108+23(k-1) < x < 122+23(k-1))
	addq.w	#3,d0
	cmp.w	#156,d4
	bgt.s	.g3
	cmp.w	d0,d3
	ble	.ft
	add.w	#14,d0
	cmp.w	d0,d3
	bge	.ft
	move.w	d2,d0
	bsr	cb_powswitch
	bra	.x
.g3:	cmp.w	#161,d4
	bgt.s	.g4
	cmp.w	d0,d3
	ble	.ft
	add.w	#14,d0
	cmp.w	d0,d3
	bge	.ft
	move.w	d2,d0
	addq.w	#5,d0
	bsr	cb_powswitch
	bra	.x
.g4:	cmp.w	#182,d4
	bgt.s	.g5
	addq.w	#5,d2
	move.w	d2,cb_fire
	bra	.x
.g5:	cmp.w	#191,d4
	blt	.ft
	cmp.w	#195,d4
	bgt	.ft
	cmp.w	#4,d2
	bne.s	.g6
	cmp.w	#183,d3
	ble	.ft
	bsr	cb_switchalienmode
	bra	.x
.g6:	cmp.w	#5,d2
	bne	.ft
	cmp.w	#209,d3
	bge	.ft
	bsr	cb_switchalienmode
	bra	.x
.ft:	bsr	cb_findtarget
.x:	movem.l	(sp)+,d3-d4
	rts
; the direction pads: rows 89-97 / 99-107 / 109-117; d0 = 1: x < 237: 1/4/7 else 2/5/8
; (226..242); d0 = 2: x < 249: 2/5/8 else 3/6/9 (244..260)  out: Z clear if one was hit
.pad:	move.w	#237,d1
	bra.s	.pd
.pad2:	move.w	#249,d1
.pd:	moveq	#0,d2			; row
	cmp.w	#89,d4
	blt.s	.no
	cmp.w	#97,d4
	ble.s	.p1
	moveq	#3,d2
	cmp.w	#99,d4
	blt.s	.no
	cmp.w	#107,d4
	ble.s	.p1
	moveq	#6,d2
	cmp.w	#109,d4
	blt.s	.no
	cmp.w	#117,d4
	bgt.s	.no
.p1:	add.w	d2,d0			; 1+row or 2+row
	cmp.w	d1,d3
	blt.s	.p2
	addq.w	#1,d0
.p2:	bsr	cb_setdir
	moveq	#1,d0
	rts
.no:	moveq	#0,d0
	rts

cb_processkey:
	bsr	kbd_readkey
	bsr	cm_upcase
	tst.b	d0
	bne	.a
	bsr	kbd_readkey
	lea	.ext,a0
.e:	move.b	(a0)+,d1
	beq.s	.f
	move.b	(a0)+,d2
	cmp.b	d1,d0
	bne.s	.e
	ext.w	d2
	move.w	d2,d0
	bra	cb_setdir
.f:	cmp.b	#59,d0
	beq	cb_zoomin
	cmp.b	#60,d0
	beq	cb_zoomout
	cmp.b	#61,d0
	beq	cb_toggleauto
	cmp.b	#62,d0
	beq	cb_togglescan
	cmp.b	#16,d0
	beq.s	.q
	cmp.b	#45,d0
	bne	.x
.q:	lea	.qq,a0			; yesnorequest('Do you want to quit?', 0, 31)
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq.s	.qn
	st	GS_QUIT(a6)
	st	cb_done
.qn:	TCOL	95
	BKCOL	0
	rts
.a:	lea	.keys,a0
.k:	move.b	(a0)+,d1
	beq.s	.k2
	move.b	(a0)+,d2
	cmp.b	d1,d0
	bne.s	.k
	ext.w	d2
	move.w	d2,d0
	bra	cb_setdir
.k2:	cmp.b	#'-',d0
	bne.s	.pl
	moveq	#1,d0
	bra	cb_setdir2
.pl:	cmp.b	#'+',d0
	bne.s	.z
	moveq	#2,d0
	bra	cb_setdir2
.z:	cmp.b	#'Z',d0
	bne.s	.xx
	moveq	#0,d0			; max(0, want-10)
	move.b	GS_SHIP+SHIP_SHIELDOPT+SHLD_COMBAT_WANT-1(a6),d0
	sub.w	#10,d0
	bpl	cb_displayshieldpic
	moveq	#0,d0
	bra	cb_displayshieldpic
.xx:	cmp.b	#'X',d0
	bne.s	.sp
	moveq	#0,d0			; min(100, want+10)
	move.b	GS_SHIP+SHIP_SHIELDOPT+SHLD_COMBAT_WANT-1(a6),d0
	add.w	#10,d0
	cmp.w	#100,d0
	ble	cb_displayshieldpic
	moveq	#100,d0
	bra	cb_displayshieldpic
.sp:	cmp.b	#' ',d0
	beq	cb_switchalienmode
	cmp.b	#'<',d0
	beq	cb_previoustarget
	cmp.b	#',',d0
	beq	cb_previoustarget
	cmp.b	#'>',d0
	beq	cb_nexttarget
	cmp.b	#'.',d0
	beq	cb_nexttarget
	lea	.fire,a0		; QWERT ASDFG: fire 1-10
	moveq	#1,d1
.fl:	move.b	(a0)+,d2
	beq.s	.x
	cmp.b	d2,d0
	beq.s	.fi
	addq.w	#1,d1
	bra.s	.fl
.fi:	move.w	d1,cb_fire
.x:	rts
.ext:	dc.b	71,1,72,2,73,3,75,4,77,6,79,7,80,8,81,9,0
.keys:	dc.b	'7',1,'8',2,'9',3,'4',4,'5',5,13,5,'6',6,'1',7,'2',8,'3',9,0
.fire:	dc.b	"QWERTASDFG",0
.qq:	dc.b	20,"Do you want to quit?"
	even

cb_mainloop:
	movem.l	d3-d5,-(sp)
	moveq	#0,d4			; index
	moveq	#0,d5			; cindex
	bsr	cb_displaymap
.l:	moveq	#8,d0
	bsr	fadestep
	bsr	cb_findmouse
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	cb_processkey
.nk:	addq.w	#1,d4
	cmp.w	#8,d4
	bne.s	.n8
	bsr	cb_suckpower
	moveq	#0,d4
	bsr	cb_displaymap
	bsr	cb_moveships
	bsr	cb_displaymap
.n8:	bsr	cb_displaystats
	bsr	cb_displaytargetinfo
	bsr	cb_powerup
	tst.b	cb_done
	bne.s	.e
	move.w	d5,d0			; the radar's chasing colour (32..48, then back)
	bsr	.ci
	lea	GS_COLORS+2(a6),a0	; setrgb256(i, 0, 0, colors[i, 3])
	move.w	d0,d1
	mulu	#3,d1
	moveq	#0,d3
	move.b	0(a0,d1.w),d3
	moveq	#0,d1
	moveq	#0,d2
	bsr	vid_setrgb
	addq.w	#1,d5
	cmp.w	#32,d5
	bne.s	.c
	moveq	#0,d5
.c:	move.w	d5,d0
	bsr	.ci
	moveq	#0,d1			; setrgb256(i, 0, 0, 63)
	moveq	#0,d2
	moveq	#63,d3
	bsr	vid_setrgb
	move.w	GS_TSLICE(a6),d0	; delay(tslice*FADE_TSLICE_MUL_COMBAT)
	mulu	#3,d0
	bsr	delay
.e:	tst.b	cb_done
	beq	.l
	tst.b	GS_QUIT(a6)
	bne.s	.x
	moveq	#1,d0			; wait(1); set256colors(colors)
	bsr	wait
	lea	GS_COLORS(a6),a0
	bsr	set256colors
.x:	movem.l	(sp)+,d3-d5
	rts
.ci:	cmp.w	#16,d0			; i := cindex+32 (< 16) or 64-cindex
	bge.s	.c2
	add.w	#32,d0
	rts
.c2:	neg.w	d0
	add.w	#64,d0
	rts

; getshipinfo(n d0, j d1): ships.dta record j + i*11 for the race
cb_getshipinfo:
	movem.l	d3-d4/a3,-(sp)
	move.w	d1,d4			; j
	bsr	cb_ship
	move.l	a0,a3
	move.w	GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6),d0
	moveq	#0,d3			; i
	cmp.w	#999,d0
	ble.s	.i
	moveq	#8,d3
	cmp.w	#1009,d0
	beq.s	.i
	moveq	#9,d3
	cmp.w	#1010,d0
	beq.s	.i
	moveq	#10,d3
	cmp.w	#1013,d0
	beq.s	.i
	cmp.w	#1007,d0
	bgt	fatal			; ('Invalid alien ship ID.')
	move.w	d0,d3
	sub.w	#1000,d3
.i:	clr.w	cb_picy			; picy := 0 for the drones, else i*20
	cmp.w	#10,d3
	beq.s	.p
	move.w	d3,d0
	mulu	#20,d0
	move.w	d0,cb_picy
.p:	move.w	d3,d0			; seek(j + i*11)
	mulu	#11,d0
	add.w	d4,d0
	mulu	#SHIPREC,d0
	move.l	cb_shipsdta,a0
	add.l	d0,a0
	move.w	#SHIPREC/2-1,d0
.c:	move.w	(a0)+,(a3)+
	dbf	d0,.c
	lea	-SHIPREC(a3),a3
	move.w	d4,d0			; picx
	cmp.w	#6,d0
	bgt.s	.x7
	mulu	#20,d0
	bra.s	.px
.x7:	sub.w	#7,d0
	mulu	#40,d0
	add.w	#140,d0
.px:	move.w	d0,ALIENSHIP_PICX(a3)
	movem.l	(sp)+,d3-d4/a3
	rts

cb_readyships:
	movem.l	d3-d7/a3,-(sp)
	clr.w	cb_nships
	move.w	#100,cb_learn
	lea	cb_t,a3
	cmp.w	#1013,GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6)
	bne.s	.c
	move.w	#5,cb_learn		; the drones
	lea	ALIEN_NAME(a3),a0
	lea	.dr,a1
	bsr	pstr_cpy
	moveq	#0,d0
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_DIFFICULTY-1(a6),d0
	addq.w	#1,d0
	mulu	#10,d0
	move.w	d0,ALIEN_VICTORY(a3)
	bra.s	.n
.c:	move.w	GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6),d0
	move.l	a3,a0
	bsr	cm_findcontact
	bne	fatal
.n:	TCOL	95
	lea	cb_alienname,a0		; alienname := t.name (string[12])
	lea	ALIEN_NAME(a3),a1
	moveq	#0,d0
	move.b	(a1),d0
	cmp.w	#12,d0
	ble.s	.l
	moveq	#12,d0
.l:	move.b	d0,(a0)+
	addq.l	#1,a1
	bra.s	.ce
.cc:	move.b	(a1)+,(a0)+
.ce:	dbf	d0,.cc
	moveq	#3,d0
	moveq	#10,d1
	lea	cb_alienname,a0
	bsr	printxy
	move.w	ALIEN_VICTORY(a3),d6	; a
	tst.b	GS_SHOWPLANET(a6)
	beq.s	.v
	move.w	GS_CURPLAN(a6),d0
	bsr	cm_plan
	cmp.b	#182,PLANET_SYSTEM(a0)
	bne.s	.v
	move.w	#300,d6
.v:	tst.w	d6
	bne.s	.v1
	moveq	#1,d6
.v1:	moveq	#4,d7			; index
	moveq	#3,d0			; form := random(maxformations)
	bsr	mt_random
	mulu	#30,d0			; (5 x 3 words)
	lea	.form,a0
	add.w	d0,a0
	move.l	a0,cb_form
.sh:	addq.w	#1,cb_nships
	cmp.w	#75,d6			; c
	ble.s	.c1
	moveq	#10,d0
	bra.s	.cs
.c1:	cmp.w	#11,d6
	bge.s	.c2
	move.w	d6,d0			; random(a): a variable
	bsr	mt_random
	bra.s	.cs
.c2:	moveq	#6,d0
	bsr	mt_random
	addq.w	#5,d0
.cs:	move.w	d0,d5
	move.w	cb_nships,d0
	move.w	d5,d1
	bsr	cb_getshipinfo
	sub.w	d5,d6			; dec(a, c+1)
	subq.w	#1,d6
	cmp.w	#4,d7
	bge.s	.base
	addq.w	#1,d7
	bra.s	.pos
.base:	lea	cb_base,a3		; basex/y/z := 100*random(600), negated if random(2) = 0
	moveq	#3-1,d3
.b:	move.w	#600,d0
	bsr	mt_random
	mulu	#100,d0
	move.l	d0,(a3)
	moveq	#2,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.bn
	neg.l	(a3)
.bn:	addq.l	#4,a3
	dbf	d3,.b
	moveq	#0,d7
.pos:	move.w	cb_nships,d0
	bsr	cb_ship
	move.l	cb_form,a1
	move.w	d7,d0
	mulu	#6,d0
	add.w	d0,a1
	lea	cb_base,a2
	moveq	#3-1,d3
.p:	move.w	(a1)+,d0
	ext.l	d0
	add.l	(a2)+,d0
	move.l	d0,(a0)+		; relx, rely, relz
	dbf	d3,.p
	lea	-12(a0),a0
	cmp.w	#ID_REFLECTIVEHULL,ALIENSHIP_SHIELD(a0)
	bgt.s	.u
	move.w	#100,ALIENSHIP_SHIELDLEVEL(a0)
.u:	cmp.w	#MAXSHIPS,cb_nships
	beq.s	.x
	tst.w	d6
	bne	.sh
.x:	movem.l	(sp)+,d3-d7/a3
	rts
.dr:	dc.b	5,"Drone"
	even
.form:	dc.w	0,0,0,-3000,0,0,3000,0,0,0,-3000,0,0,3000,0
	dc.w	0,0,0,-3000,-3000,0,3000,3000,0,-3000,3000,0,3000,-3000,0
	dc.w	0,0,0,1000,0,1000,2000,0,2000,3000,0,3000,4000,0,4000

cb_readydata:
	movem.l	d3-d7/a3,-(sp)
	bsr	mousehide
	moveq	#0,d0			; compressfile(current)
	bsr	ms_snap
	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	lea	cb_fn_mod,a0
	bsr	playmod
	bsr	orc_dump		; loadscreen(fight)
	lea	cb_mode,a0
	bsr	ms_load
	bcs	fatal
	bsr	cb_tmemo_clr
	bsr	orc_dump		; loadscreen(cloud, backgr)
	lea	u2_cloud,a0
	move.l	GS_BACKGR(a6),a1
	bsr	loadchk
	sf	cb_done
	bsr	mem_mark
	move.l	d0,cb_mark
	move.l	#MAXSHIPS*SHIPREC,d0	; new(ships, asdisplay); ships.dta; the samples
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,cb_ships
	move.l	#65*93,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,cb_asdisplay
	move.l	#11*11*SHIPREC,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,cb_shipsdta
	move.l	a0,a1
	lea	cb_fn_ships,a0
	move.l	#11*11*SHIPREC,d0
	bsr	fil_load
	bcs	fatal
	lea	cb_samples,a3		; gun1, gun4, laser1-7, explode1-2
	lea	cb_samnames,a4
	moveq	#11-1,d3
.sm:	lea	cb_fn_sam+6,a0
.sc:	move.b	(a4)+,(a0)+
	bne.s	.sc
	lea	cb_fn_sam,a0
	move.l	a3,a1
	bsr	snd_sfx_load
	lea	SMP_SIZE(a3),a3
	dbf	d3,.sm
	moveq	#10,d0			; the picture's pieces: statpic, blank, shieldpic(2), msgs
	moveq	#71,d1
	lea	cb_statpic,a1
	moveq	#2,d2
	bsr	.grab12
	moveq	#26,d0
	move.w	#269,d1
	lea	cb_blank,a1
	moveq	#2,d2
	bsr	.grab12
	moveq	#10,d0
	moveq	#91,d1
	lea	cb_shieldpic,a1
	bsr	.grab4
	moveq	#10,d0
	moveq	#101,d1
	lea	cb_shieldpic2,a1
	bsr	.grab4
	lea	cb_msgs,a1
	moveq	#0,d3
.mg:	moveq	#0,d4
.mr:	move.w	d3,d0			; (x 110+j*10, y i+10)
	mulu	#10,d0
	add.w	#110,d0
	move.w	d4,d1
	add.w	#10,d1
	movem.l	a1,-(sp)
	bsr	ms_addr
	movem.l	(sp)+,a1
	moveq	#10-1,d0
.mc:	move.b	(a0)+,(a1)+
	dbf	d0,.mc
	addq.w	#1,d4
	cmp.w	#10,d4
	bne.s	.mr
	addq.w	#1,d3
	cmp.w	#4,d3
	bne.s	.mg
	BAR	71,9,247,20,0
	bsr	cb_displaytimedelay
	TCOL	95
	BKCOL	0
	move.l	GS_T1(a6),GS_OLDT1(a6)
	move.l	GS_T1+4(a6),GS_OLDT1+4(a6)
	move.w	#1,cb_target
	tst.b	GS_SHIP+SHIP_OPTIONS+OPT_DIFFICULTY-1(a6)
	bne.s	.d
	st	cb_autofire
	st	cb_scanning
	moveq	#63,d4
	bra.s	.dl
.d:	sf	cb_autofire
	sf	cb_scanning
	moveq	#95,d4
.dl:	move.w	#163,d0
	moveq	#125,d1
	move.w	#214,d2
	moveq	#126,d3
	bsr	ms_bar
	move.w	#163,d0
	move.w	#187,d1
	move.w	#214,d2
	move.w	#188,d3
	bsr	ms_bar
	move.l	GS_BACKGR(a6),a1	; rows 9-117, x 6-260: 0 -> backgr^
	moveq	#9,d3
.br:	moveq	#6,d0
	move.w	d3,d1
	bsr	ms_addr
	move.w	d3,d0
	mulu	#320,d0
	lea	6(a1,d0.l),a2
	move.w	#255-1,d0
.bc:	tst.b	(a0)+
	bne.s	.bn
	move.b	(a2),-1(a0)
.bn:	addq.l	#1,a2
	dbf	d0,.bc
	addq.w	#1,d3
	cmp.w	#117,d3
	ble.s	.br
	moveq	#6,d0
	moveq	#9,d1
	move.w	#260,d2
	moveq	#117,d3
	bsr	ms_dirty
	bsr	orc_dump		; loadscreen(waricon, backgr)
	lea	cb_s_waricon,a0
	move.l	GS_BACKGR(a6),a1
	bsr	cm_loadchk
	clr.l	cb_stats
	move.w	#20,cb_oldshddmg
	move.w	#5,cb_shipdir
	clr.w	cb_shipdir2
	clr.w	cb_fire
	clr.w	cb_moveindex
	sf	cb_engaging
	sf	cb_picmode
	sf	cb_dead
	move.l	#60000,cb_range_
	PXY	33,110," 600000 KM.R."
	lea	cb_powered,a0		; poweredup: 99 when armed, else 0; -1 without a gun
	lea	GS_SHIP+SHIP_GUNNODES(a6),a1
	moveq	#10-1,d0
.pw:	moveq	#0,d1
	tst.b	GS_SHIP+SHIP_ARMED(a6)
	beq.s	.pa
	moveq	#99,d1
.pa:	tst.b	(a1)+
	bne.s	.pb
	moveq	#-1,d1
.pb:	move.w	d1,(a0)+
	dbf	d0,.pw
	move.l	cb_asdisplay,a1		; asdisplay^ := rows 125-189, x 6-98
	moveq	#125,d3
.as:	moveq	#6,d0
	move.w	d3,d1
	bsr	ms_addr
	moveq	#93-1,d0
.ac:	move.b	(a0)+,(a1)+
	dbf	d0,.ac
	addq.w	#1,d3
	cmp.w	#189,d3
	ble.s	.as
	BAR	6,137,98,189,0
	clr.l	cb_stats
	bsr	cb_displayweapons
	bsr	cb_displaystats
	bsr	cb_displaydamage
	moveq	#63,d0
	bsr	cb_drawdirection
	moveq	#0,d0
	move.b	GS_SHIP+SHIP_SHIELDOPT+SHLD_COMBAT_WANT-1(a6),d0
	bsr	cb_displayshieldpic
	bsr	cb_readyships
	bsr	cb_displaytargetinfo
	bsr	mouseshow
	moveq	#1,d3			; the switched-off power switches faded
.us:	lea	cb_userpow-1,a0
	tst.b	0(a0,d3.w)
	bne.s	.un
	move.w	d3,d0
	subq.w	#1,d0
	ext.l	d0
	divu	#5,d0
	move.w	d0,d1
	mulu	#7,d1
	add.w	#152,d1
	swap	d0
	mulu	#23,d0
	add.w	#109,d0
	move.w	d0,d2
	add.w	#12,d2
	movem.l	d3-d4,-(sp)
	move.w	d1,d3
	addq.w	#2,d3
	moveq	#32,d4
	bsr	plainfadearea
	movem.l	(sp)+,d3-d4
.un:	addq.w	#1,d3
	cmp.w	#10,d3
	ble.s	.us
	movem.l	(sp)+,d3-d7/a3
	rts
; rows from (y d0, x d1), d2 rows of 10 bytes into a1 (12 wide)
.grab12:
	move.w	d2,-(sp)
	exg	d0,d1
	movem.l	d0-d1/a1,-(sp)
	bsr	ms_addr
	movem.l	(sp)+,d0-d1/a1
	moveq	#10-1,d2
.g1:	move.b	(a0)+,(a1)+
	dbf	d2,.g1
	addq.l	#2,a1
	addq.w	#1,d1
	exg	d0,d1
	move.w	(sp)+,d2
	subq.w	#1,d2
	bne.s	.grab12
	rts
; 7 rows of 4 bytes from (y d0, x d1) into a1
.grab4:	moveq	#7-1,d2
.g4:	movem.l	d0-d2/a1,-(sp)
	exg	d0,d1
	bsr	ms_addr
	movem.l	(sp)+,d0-d2/a1
	move.b	(a0)+,(a1)+
	move.b	(a0)+,(a1)+
	move.b	(a0)+,(a1)+
	move.b	(a0)+,(a1)+
	addq.w	#1,d0
	dbf	d2,.g4
	rts

; savevictories: the contact record updated (victory, anger, congeniality)
cb_savevictories:
	movem.l	d3-d4,-(sp)
	move.w	#2,-(sp)
	pea	cm_fn_contacts2
	GEMDOS	GD_FOPEN,8
	move.w	d0,d3
	bmi	fatal
	moveq	#-1,d4			; i
.r:	addq.w	#1,d4
	pea	cb_t
	move.l	#ALIEN_SIZEOF,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FREAD,12
	cmp.l	#ALIEN_SIZEOF,d0
	bne	fatal
	move.w	cb_t+ALIEN_ID,d0
	cmp.w	GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6),d0
	bne.s	.r
	clr.w	-(sp)			; seek(f, i)
	move.w	d3,-(sp)
	move.w	d4,d0
	mulu	#ALIEN_SIZEOF,d0
	move.l	d0,-(sp)
	GEMDOS	GD_FSEEK,10
	move.w	cb_nships,d0		; victory += max(nships div 4, 1); + nships with no damage taken
	lsr.w	#2,d0
	bne.s	.v
	moveq	#1,d0
.v:	add.w	d0,cb_t+ALIEN_VICTORY
	lea	GS_SHIP+SHIP_DAMAGES(a6),a0
	moveq	#0,d0
	moveq	#7-1,d1
.dm:	moveq	#0,d2
	move.b	(a0)+,d2
	add.w	d2,d0
	dbf	d1,.dm
	tst.w	d0
	bne.s	.an
	move.w	cb_nships,d0
	add.w	d0,cb_t+ALIEN_VICTORY
.an:	cmp.w	#200,cb_t+ALIEN_ANGER
	bge.s	.cg
	addq.w	#1,cb_t+ALIEN_ANGER
	bra.s	.vm
.cg:	tst.w	cb_t+ALIEN_CONGENIALITY
	ble.s	.vm
	subq.w	#1,cb_t+ALIEN_CONGENIALITY
.vm:	cmp.w	#20000,cb_t+ALIEN_VICTORY
	ble.s	.w
	move.w	#20000,cb_t+ALIEN_VICTORY
.w:	pea	cb_t
	move.l	#ALIEN_SIZEOF,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FWRITE,12
	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
	movem.l	(sp)+,d3-d4
	rts

cb_aftereffects:
	movem.l	d3-d5,-(sp)
	lea	cb_fn_victory,a0
	bsr	playmod
	bsr	mousehide
	BAR	6,9,259,117,0
	BAR	6,125,98,189,0
	TCOL	95
	PXY	18,8,"VICTORY!"
	bsr	mouseshow
	lea	.q,a0			; yesnorequest('DEPLOY SCAVENGER BOTS?', 0, 31)
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq	.sv
	TCOL	22
	BKCOL	0
	bsr	mousehide
	PXY	18,18,"SCAVENGER BOTS DEPLOYED..."
	bsr	mouseshow
	TCOL	28
	move.w	cb_nships,d0		; i := random(nships), at most 13
	bsr	mt_random
	cmp.w	#13,d0
	ble.s	.i
	moveq	#13,d0
.i:	move.w	d0,d5
	moveq	#0,d3			; j
.j:	moveq	#21,d0			; cargoitems[j] := random(21)
	bsr	mt_random
	move.w	d0,d4
	bsr	mousehide
	move.w	#ID_UNKNOWN_COMPONENT,d0	; cargo[a+item].name, a: the unknown component's record
	bsr	td_cargorec
	move.w	d4,d0
	mulu	#CARGO_SIZEOF,d0
	add.l	d0,a0
	lea	CARGO_NAME(a0),a0
	moveq	#24,d0
	move.w	d3,d1
	mulu	#6,d1
	add.w	#28,d1
	bsr	printxy
	bsr	mouseshow
	move.w	d4,d0
	add.w	#ID_UNKNOWN_COMPONENT,d0
	st	d1
	bsr	addcargo2
	addq.w	#1,d3
	cmp.w	d5,d3
	ble.s	.j
.k1:	bsr	kbd_keypressed		; while fastkeypressed do readkey
	beq.s	.w
	bsr	kbd_readkey
	bra.s	.k1
.w:	bsr	kbd_keypressed		; repeat until fastkeypressed or mouse.getstatus
	bne.s	.k2
	bsr	kbd_mouse_status
	tst.b	d0
	beq.s	.w
.k2:	bsr	kbd_keypressed
	beq.s	.sv
	bsr	kbd_readkey
	bra.s	.k2
.sv:	bsr	cb_savevictories
	movem.l	(sp)+,d3-d5
	rts
.q:	dc.b	22,"DEPLOY SCAVENGER BOTS?"
	even

initiatecombat:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	cb_readydata
	bsr	cb_mainloop
	bsr	orc_dump		; loadscreen(cloud, backgr)
	lea	u2_cloud,a0
	move.l	GS_BACKGR(a6),a1
	bsr	loadchk
	bsr	gp_extras
	tst.b	cb_engaging
	bne.s	.n
	tst.b	cb_dead
	bne.s	.n
	cmp.w	#1013,GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6)
	bge.s	.n
	bsr	cb_aftereffects
.n:	move.l	cb_mark,d0		; dispose (the ships, the samples ...)
	bsr	mem_release
	bsr	stopmod
	bsr	removedata
	movem.l	(sp)+,d3-d7/a3-a5
	rts

	section	data
cb_mode:	dc.b	"FIGHT",0
cb_fn_mod:	dc.b	"SOUND",92,"COMBAT.MOD",0
cb_fn_victory:	dc.b	"SOUND",92,"VICTORY.MOD",0
cb_fn_ships:	dc.b	"DATA",92,"SHIPS.DTA",0
cb_s_waricon:	dc.b	"WARICON",0
cb_fn_sam:	dc.b	"SOUND",92,"EXPLODE1.SAM",0
cb_samnames:	dc.b	"GUN1.SAM",0,"GUN4.SAM",0,"LASER1.SAM",0,"LASER2.SAM",0
		dc.b	"LASER3.SAM",0,"LASER4.SAM",0,"LASER5.SAM",0,"LASER6.SAM",0
		dc.b	"LASER7.SAM",0,"EXPLODE1.SAM",0,"EXPLODE2.SAM",0
cb_classes:				; string[14] each
	dc.b	14,"Shuttle       ",14,"Scout         ",14,"Fighter       ",14,"Assault Scout "
	dc.b	14,"Patrol Craft  ",14,"Corvette      ",14,"Frigate       ",14,"Lt. Destroyer "
	dc.b	14,"Hv. Destroyer ",14,"Lt. Cruiser   ",14,"Hv. Cruiser   ",14,"Battle Cruiser"
	dc.b	14,"Flagship      ",14,"Battleship    ",14,"Dreadnaught   "
cb_userpow:	dc.b	-1,-1,-1,-1,-1,-1,-1,-1,-1,-1	; userpowerup[1..10] (true at start-up)
	even

	section	bss
cb_mark:	ds.l	1
cb_ships:	ds.l	1
cb_asdisplay:	ds.l	1
cb_shipsdta:	ds.l	1
cb_form:	ds.l	1
cb_range_:	ds.l	1
cb_base:	ds.l	3
cb_r:		ds.l	2
cb_rl:		ds.l	2
cb_part:	ds.l	2
cb_dspart:	ds.l	2		; part as displaystats left it (cb_dskey's pass)

cb_powered:	ds.w	10
cb_target:	ds.w	1
cb_nships:	ds.w	1
cb_fire:	ds.w	1
cb_moveindex:	ds.w	1
cb_picy:	ds.w	1
cb_oldshddmg:	ds.w	1
cb_shipdir:	ds.w	1
cb_shipdir2:	ds.w	1
cb_learn:	ds.w	1
cb_a:		ds.w	1
cb_b:		ds.w	1
cb_i:		ds.w	1
cb_stats:	ds.b	4		; stats[1..3]
cb_done:	ds.b	1
cb_dead:	ds.b	1
cb_autofire:	ds.b	1
cb_scanning:	ds.b	1
cb_engaging:	ds.b	1
cb_picmode:	ds.b	1
	even
cb_statpic:	ds.b	24
cb_blank:	ds.b	24
cb_shieldpic:	ds.b	28
cb_shieldpic2:	ds.b	28
cb_msgs:	ds.b	400
cb_alienname:	ds.b	14
cb_s:		ds.b	64
cb_s2:		ds.b	32
cb_t:		ds.b	ALIEN_SIZEOF
	even
cb_samples:	ds.b	11*SMP_SIZE
	even
	section	text
