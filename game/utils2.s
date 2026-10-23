; utils2.s - utils2.pas for MAIN.PRG: the bridge background, planets and stars in orbit.
;
; reloadbackground  backgrx/y := random; main.cpr's transparent pixels from cloud.cpr, shifted
; readyplanet       generate the planet in orbit (landform) and show it (sphere 1); gas giants,
;                   asteroid fields and clouds are not ported yet
; readystar         the same for a star (orbit 0)
; gettechnologylevel in: d0.w planet  out: d0.w
; loadchk           in: a0 = mode name, a1 = 64000-byte buffer: NAME.CHK into it (+ its
;                   palette into GS_COLORS when it has one) - loadscreen into a buffer
; makesphere1/2/3, makesphere, makestar: journey.pas, drawing tables from DATA\SPHERE.DAT
; (tools/mkmain.py: the per-row texture columns the original computes with reals)
; (all trash d0-d2/a0-a2)

LAND_W		equ	120		; landform^[x 1..240, y 1..120]: (x-1)*120 + (y-1)

	section	text
reloadbackground:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	#320,d0			; backgrx := random(320); backgry := random(200)
	bsr	mt_random
	move.w	d0,GS_BACKGRX(a6)
	move.w	#200,d0
	bsr	mt_random
	move.w	d0,GS_BACKGRY(a6)
	bsr	mem_mark
	move.l	d0,-(sp)
	move.l	#64000,d0		; new(temp)
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,a5
	bsr	orc_dump		; loadscreen(main, temp)
	lea	u2_main,a0
	move.l	a5,a1
	bsr	loadchk
	bsr	orc_dump		; loadscreen(cloud, backgr)
	lea	u2_cloud,a0
	move.l	GS_BACKGR(a6),a1
	bsr	loadchk
	move.l	ms_buf,a3		; screen
	move.l	GS_BACKGR(a6),d7
	moveq	#-1,d5			; (255: transparent in main)
	moveq	#0,d6			; i (row)
.row:	move.w	d6,d0			; y := i + backgry (wrapped)
	add.w	GS_BACKGRY(a6),d0
	cmp.w	#199,d0
	ble.s	.y
	sub.w	#200,d0
.y:	mulu	#320,d0
	add.l	d7,d0
	move.l	d0,a2			; backgr row, twice in u2_dbl (the x wrap)
	lea	u2_dbl,a4
	moveq	#80-1,d1
.dbl:	move.l	(a2)+,d0
	move.l	d0,320(a4)
	move.l	d0,(a4)+
	dbf	d1,.dbl
	lea	u2_dbl,a0
	add.w	GS_BACKGRX(a6),a0	; backgr pixel j of the row = (a0 + j)
	move.l	a5,a1			; the row's start in main
	move.w	#320-1,d1		; bytes after the current one
.f:	cmp.b	(a5)+,d5		; the next transparent pixel
	dbeq	d1,.f
	bne.s	.rd
	move.l	a5,d0
	subq.l	#1,d0
	sub.l	a1,d0			; its column
	lea	0(a0,d0.w),a2
	lea	0(a3,d0.w),a4
.cp:	move.b	(a2)+,(a4)+		; the run
	subq.w	#1,d1
	bmi.s	.rd
	cmp.b	(a5)+,d5
	beq.s	.cp
	subq.w	#1,d1
	bpl.s	.f
.rd:	move.l	a1,a5
	lea	320(a5),a5
	lea	320(a3),a3
	addq.w	#1,d6
	cmp.w	#200,d6
	bne.s	.row
	bsr	ms_dirty_all
	move.l	(sp)+,d0		; dispose(temp)
	bsr	mem_release
	movem.l	(sp)+,d3-d7/a3-a5
	rts

loadchk:
	move.l	a1,-(sp)
	lea	ms_path+5,a1		; "DATA\" + name + ".CHK"
.cp:	move.b	(a0)+,(a1)+
	bne.s	.cp
	move.b	#'.',-1(a1)
	move.b	#'C',(a1)+
	move.b	#'H',(a1)+
	move.b	#'K',(a1)+
	clr.b	(a1)
	move.l	(sp)+,a1
	lea	ms_path,a0
	move.l	#64000,d0
	bsr	fil_load
	bcs	fatal
	lea	ms_path,a0
	bsr	fil_size
	cmp.l	#64000+768,d0
	bne.s	.x
	bra	ms_loadpal
.x:	rts

; ---------------------------------------------------------------
; utils2.pas GetTechnologyLevel(plan)
gettechnologylevel:
	move.l	d3,-(sp)
	subq.w	#1,d0
	mulu	#PLANET_SIZEOF,d0
	move.l	GS_TEMPPLAN(a6),a0
	add.l	d0,a0
	moveq	#0,d0
	tst.b	PLANET_ORBIT(a0)
	beq	.x
	moveq	#-2,d3			; techlvl
	moveq	#0,d1
	move.b	PLANET_SYSTEM(a0),d1
	lea	.six,a1
.s6:	move.w	(a1)+,d2
	bmi.s	.n6
	cmp.w	d2,d1
	bne.s	.s6
	move.w	#6*256,d0
	bra	.x
.n6:	cmp.w	#45,d1
	bne.s	.st
	moveq	#27,d0
	move.l	a0,-(sp)
	bsr	chevent
	move.l	(sp)+,a0
	bne	.x			; chevent(27): 0
	move.w	#6*256,d0
	bra	.x
.st:	moveq	#0,d1
	move.b	PLANET_STATE(a0),d1
	moveq	#0,d2
	move.b	PLANET_MODE(a0),d2
	move.l	PLANET_AGE(a0),d0
	cmp.w	#2,d1
	bne.s	.s3
	cmp.w	#2,d2
	bne.s	.s23
	moveq	#-1,d3
	bra	.done
.s23:	cmp.w	#3,d2
	bne	.done
	move.l	#15000000,d1
	bsr	.div
	move.w	d0,d3
	bra	.done
.s3:	cmp.w	#3,d1
	bne.s	.s4
	move.w	d2,d3			; (mode-1)*256
	subq.w	#1,d3
	lsl.w	#8,d3
	cmp.w	#1,d2
	bne.s	.s32
	move.l	#1500000,d1
	bra.s	.s3d
.s32:	cmp.w	#2,d2
	bne.s	.s33
	move.l	#1000,d1
	bra.s	.s3d
.s33:	cmp.w	#3,d2
	bne	.done
	move.l	#800,d1
.s3d:	bsr	.div
	add.w	d0,d3
	bra	.done
.s4:	cmp.w	#4,d1
	bne.s	.s5
	move.w	d2,d3			; (mode+2)*256
	addq.w	#2,d3
	lsl.w	#8,d3
	cmp.w	#1,d2
	bne.s	.s42
	move.l	#400,d1
	bra.s	.s3d
.s42:	cmp.w	#2,d2
	bne.s	.done
	move.l	#200,d1
	bra.s	.s3d
.s5:	cmp.w	#5,d1
	bne.s	.s6x
	cmp.w	#1,d2
	bne.s	.s52
	move.l	#100000000,d1
	bsr	.div
	cmp.w	#9,d0
	ble.s	.s51
	moveq	#9,d0
.s51:	add.w	d0,d3
	bra.s	.done
.s52:	cmp.w	#2,d2
	bne.s	.done
	moveq	#-1,d3
	bra.s	.done
.s6x:	cmp.w	#6,d1			; state 6: the original tests tempplan^[curplan].mode
	bne.s	.done
	move.w	GS_CURPLAN(a6),d0
	subq.w	#1,d0
	mulu	#PLANET_SIZEOF,d0
	move.l	GS_TEMPPLAN(a6),a1
	cmp.b	#2,PLANET_MODE(a1,d0.l)
	bne.s	.done
	move.w	#6*256,d3
.done:	move.w	d3,d0
.x:	move.l	(sp)+,d3
	rts
; d0.l (>= 0) div d1.l -> d0.w (the callers' quotients fit a word)
.div:	movem.l	d2-d3,-(sp)
	moveq	#0,d2			; shift-subtract 32-bit division
	moveq	#32-1,d3
.dl:	add.l	d0,d0
	addx.l	d2,d2
	cmp.l	d1,d2
	blo.s	.dn
	sub.l	d1,d2
	addq.l	#1,d0
.dn:	dbf	d3,.dl
	movem.l	(sp)+,d2-d3
	rts
.six:	dc.w	93,138,78,191,171,221,-1

; ---------------------------------------------------------------
; sphere tables: a0 -> the record for radius d0.w (SPHERE.DAT, loaded at start-up)
; record: radius.w r2.w offset.w maxspherei.w spherei.w xw.w, then rows 6..maxspherei:
; pm.w, n.w, n index bytes (padded to even)
SPH_RADIUS	equ	0
SPH_R2		equ	2
SPH_OFFSET	equ	4
SPH_MAX		equ	6
SPH_HALF	equ	8
SPH_XW		equ	10
SPH_ROWS	equ	12

sphere_find:
	move.l	u2_sphere,a0
.f:	cmp.w	SPH_RADIUS(a0),d0
	beq.s	.x
	move.l	a0,a1			; skip this record
	move.w	SPH_MAX(a0),d1
	subq.w	#6,d1			; rows - 1
	lea	SPH_ROWS(a0),a0
.r:	move.w	2(a0),d2
	addq.w	#4+1,d2
	and.w	#$fffe,d2
	add.w	d2,a0
	dbf	d1,.r
	tst.w	(a0)
	bne.s	.f
	bra	fatal
.x:	rts

; set r2, offset, maxspherei, spherei, xw, pm[] from the table for radius GS_RADIUS
sphere_setup:
	move.w	GS_RADIUS(a6),d0
	bsr.s	sphere_find
	move.l	a0,u2_sph
	move.w	SPH_R2(a0),GS_R2(a6)
	move.w	SPH_OFFSET(a0),GS_OFFSET(a6)
	move.w	SPH_MAX(a0),GS_MAXSPHEREI(a6)
	move.w	SPH_HALF(a0),GS_SPHEREI(a6)
	move.w	SPH_XW(a0),GS_XW(a6)
	move.w	SPH_MAX(a0),d1
	subq.w	#6,d1
	lea	GS_PM+5*2(a6),a1	; pm[6..]
	lea	SPH_ROWS(a0),a0
.r:	move.w	(a0),(a1)+
	move.w	2(a0),d2
	addq.w	#4+1,d2
	and.w	#$fffe,d2
	add.w	d2,a0
	dbf	d1,.r
	rts

; ---------------------------------------------------------------
; readyplanet (utils2.pas 1218)
readyplanet:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	#4,GS_GLOWINDEX(a6)
	bsr	mousehide
	bsr	reloadbackground
	st	GS_SHOWPLANET(a6)
	bsr	u2_curplan		; a3 = tempplan^[curplan]
	moveq	#0,d0			; randseed := seed
	move.w	PLANET_SEED(a3),d0
	bsr	mt_seed
	moveq	#0,d0			; fillchar(landform^, 28800, water+20)
	move.b	PLANET_WATER(a3),d0
	add.b	#20,d0
	move.l	GS_LANDFORM(a6),a0
	move.w	#28800-1,d1
.fl:	move.b	d0,(a0)+
	dbf	d1,.fl
	moveq	#0,d0
	move.b	PLANET_PSIZE(a3),d0
	lea	.radius,a0		; 0,1: 900  2,3: 2000  4: 3025
	move.b	0(a0,d0.w),d0
	add.w	d0,d0
	lea	.rads,a0
	move.w	0(a0,d0.w),GS_RADIUS(a6)
	bsr	mt_randomize		; randomize
	moveq	#4,d0			; case random(4) of: ecl
	bsr	mt_random
	move.w	d0,d3
	moveq	#25,d0
	bsr	mt_random
	add.w	d3,d3
	lea	.ecl,a0
	move.w	0(a0,d3.w),d1
	bpl.s	.ep
	neg.w	d1			; 80 - r, 250 - r
	sub.w	d0,d1
	bra.s	.es
.ep:	add.w	d0,d1			; r + 30, 200 + r
.es:	move.w	d1,GS_ECL(a6)
	bsr	sphere_setup
	move.b	PLANET_STATE(a3),d0
	move.b	PLANET_MODE(a3),d1
	tst.b	d0
	bne.s	.n0
	cmp.b	#1,d1
	bgt	notported		; gas giant
	bra	notported		; cloud
.n0:	cmp.b	#6,d0
	bne.s	.reg
	cmp.b	#2,d1
	beq	notported		; asteroid field
.reg:	bsr	u2_approach		; 'Approaching planet...'
	lea	u2_s_planet,a0
	bsr	u2_approach_text
	clr.w	u2_index
	clr.w	u2_i
	move.w	#200,d0
	moveq	#90,d1
	bsr	createplanet
	moveq	#30,d0
	moveq	#30,d1
	bsr	createplanet
	moveq	#120,d0
	moveq	#60,d1
	bsr	createplanet
	bsr	u2_unapproach
	move.w	#50,GS_WATER(a6)	; water, waterindex, spcindex by state/mode
	moveq	#0,d0
	move.b	PLANET_STATE(a3),d0
	moveq	#0,d1
	move.b	PLANET_MODE(a3),d1
	lea	GS_SPCINDEX(a6),a0
	cmp.w	#1,d0
	bne.s	.t2
	move.w	#80,GS_WATERINDEX(a6)
	move.l	#$53525150,(a0)		; 83,82,81,80
	move.b	#82,4(a0)
	move.b	#81,5(a0)
	bra	.lk
.t2:	cmp.w	#2,d0
	bne.s	.t3
	move.w	#32,GS_WATERINDEX(a6)
	cmp.w	#1,d1
	bne.s	.t22
	bsr	.ones
	bra	.lk
.t22:	cmp.w	#2,d1
	bne.s	.t23
	bsr	.ones
	move.b	#48,4(a0)
	move.b	#49,5(a0)
	bra	.lk
.t23:	cmp.w	#3,d1
	bne	.lk
	move.l	#$30313233,(a0)
	move.b	#128,4(a0)
	move.b	#130,5(a0)
	bra	.lk
.t3:	cmp.w	#3,d0
	bne.s	.t4
	move.w	#33,GS_WATERINDEX(a6)
	move.l	#$30313233,(a0)
	move.b	#128,4(a0)
	move.b	#129,5(a0)
	bra.s	.lk
.t4:	cmp.w	#4,d0
	bne.s	.t5
	move.w	#32,GS_WATERINDEX(a6)
	move.w	#40,GS_WATER(a6)
	move.l	#$30313233,(a0)
	move.b	#128,4(a0)
	move.b	#129,5(a0)
	bra.s	.lk
.t5:	cmp.w	#5,d0
	bne.s	.t6
	move.w	#32,GS_WATERINDEX(a6)
	bsr	.ones
	move.w	#30,GS_WATER(a6)
	cmp.w	#3,d1
	bne.s	.lk
	clr.w	GS_WATER(a6)
	bra.s	.lk
.t6:	cmp.w	#6,d0
	bne.s	.lk
	move.w	#32,GS_WATERINDEX(a6)
	clr.w	GS_WATER(a6)
	bsr	.ones
.lk:	lea	GS_SPCINDEX(a6),a0	; spcindex2[j] := spcindex[j] mod 16
	lea	GS_SPCINDEX2(a6),a1
	moveq	#6-1,d0
.s2:	move.b	(a0)+,d1
	and.b	#15,d1
	move.b	d1,(a1)+
	dbf	d0,.s2
	; colorlookup: below water: waterindex+6; water..246: round((j-water)*28/(255-water)); 247..: j
	lea	GS_COLORLOOKUP(a6),a0
	move.w	GS_WATER(a6),d4
	moveq	#0,d3			; j
	move.w	GS_WATERINDEX(a6),d1
	addq.w	#6,d1
.cw:	cmp.w	d4,d3
	bge.s	.cl
	move.b	d1,(a0)+
	addq.w	#1,d3
	bra.s	.cw
.cl:	move.w	#255,d5
	sub.w	d4,d5			; 255 - water
	move.w	d5,d6
	add.w	d6,d6			; 2*(255-water)
.cc:	cmp.w	#246,d3
	bgt.s	.ch
	move.w	d3,d0			; (56*(j-water) + (255-water)) div (2*(255-water)): no ties occur
	sub.w	d4,d0
	mulu	#56,d0
	add.w	d5,d0
	divu	d6,d0
	move.b	d0,(a0)+
	addq.w	#1,d3
	bra.s	.cc
.ch:	move.b	d3,(a0)+
	addq.w	#1,d3
	cmp.w	#256,d3
	bne.s	.ch
	bsr	u2_grabplanet		; planet^ := the viewscreen's background
	bsr	u2_shade
	bsr	makesphere
	move.w	#1,GS_SPHERE(a6)
	bsr	checkstats
	bsr	showtime
	bsr	mouseshow
	bsr	fadein
	move.w	#31,GS_TCOLOR(a6)
	move.w	#3,GS_BKCOLOR(a6)
	bsr	println
	lea	u2_s_orbit,a0
	bsr	print
	bsr	mt_randomize		; randomize
	bsr	checkwandering
	movem.l	(sp)+,d3-d7/a3-a5
	rts
.ones:	move.l	#$01010101,(a0)
	move.w	#$0101,4(a0)
	rts
.radius: dc.b	0,0,1,1,2,0
.rads:	dc.w	900,2000,3025
.ecl:	dc.w	30,-80,200,-250		; (negative: minus random(25))

; a3 := tempplan^[curplan]
u2_curplan:
	move.w	GS_CURPLAN(a6),d0
	subq.w	#1,d0
	mulu	#PLANET_SIZEOF,d0
	move.l	GS_TEMPPLAN(a6),a3
	add.l	d0,a3
	rts

; planet^[1..120] := screen[13..132, 28..147]
u2_grabplanet:
	moveq	#28,d0
	moveq	#13,d1
	bsr	ms_addr
	move.l	GS_PLANET(a6),a1
	moveq	#120-1,d1
.r:	moveq	#120/4-1,d0
	move.l	a0,a2
.c:	move.b	(a2)+,(a1)+		; (bytes: 28 is not long-aligned for every row)
	move.b	(a2)+,(a1)+
	move.b	(a2)+,(a1)+
	move.b	(a2)+,(a1)+
	dbf	d0,.c
	lea	MS_W(a0),a0
	dbf	d1,.r
	rts

; the approach screen: keep the screen, black screen at full palette (set256colors(colors))
u2_approach:
	moveq	#1,d0			; new(t); t^ := screen
	bsr	ms_snap
	bsr	kbd_cursor_hide
	move.l	ms_buf,a0		; scr_fillchar(screen, 64000, 0)
	move.w	#64000/4-1,d0
.c:	clr.l	(a0)+
	dbf	d0,.c
	move.l	vid_phys,a0
	bsr	vid_clear
	bsr	ms_clean
	lea	GS_COLORS(a6),a0
	bsr	set256colors
	move.w	#47,GS_TCOLOR(a6)
	clr.w	GS_BKCOLOR(a6)
	rts

u2_approach_text:			; a0 = the first line
	moveq	#30,d0
	move.w	#160,d1
	bsr	printxy
	moveq	#30,d0
	move.w	#170,d1
	lea	u2_s_eta,a0
	bsr	printxy
	bra	ms_flush

; set256colors(tpal = black); screen := t^
u2_unapproach:
	moveq	#0,d0
	bsr	vid_set_fade
	moveq	#1,d0
	bra	ms_unsnap


; U2_R3 minus,zero,plus: random(3) on the next generator number (a5 into mt_state, a3 its
; end), branching to one of the three labels. Only the top word of the tempered number is
; needed (it is y3's: y3 >> 18 stays below it), unless it equals a threshold's ($5555, $AAAA):
; then u2_lo tempers the low word too. Trashes d0-d2/a0.
U2_R3	macro
	cmp.l	a3,a5
	blo.s	.a\@
	bsr	mt_update
	lea	mt_state,a5
.a\@:	move.l	(a5)+,d0
	move.l	d0,d1			; y ^= y >> 11
	moveq	#11,d2
	lsr.l	d2,d1
	eor.l	d1,d0
	move.l	d0,d1			; y ^= (y << 7) & $9D2C5680
	lsl.l	#7,d1
	and.l	#$9D2C5680,d1
	eor.l	d1,d0
	move.l	d0,d2			; (y2)
	move.l	d0,d1			; top word of y ^= (y << 15) & $EFC60000
	lsr.l	#1,d1
	and.w	#$EFC6,d1
	swap	d0
	eor.w	d1,d0
	cmp.w	#$5555,d0
	blo	\1
	beq.s	.s\@
	cmp.w	#$aaaa,d0
	blo	\2
	bne	\3
	bsr	u2_lo
	cmp.w	#$aaab,d0
	blo	\2
	bra	\3
.s\@:	bsr	u2_lo
	cmp.w	#$5556,d0
	blo	\1
	bra	\2
	endm

; the low word of the tempered number from y2 (d2) in d0.w  trashes d1
u2_lo:	move.l	d2,d0
	move.l	d0,d1
	lsl.l	#8,d1
	lsl.l	#7,d1
	and.l	#$EFC60000,d1
	eor.l	d1,d0
	move.l	d0,d1
	swap	d1
	lsr.w	#2,d1
	eor.w	d1,d0
	rts

; the next run of steps before the countdown: d5 := min(left, 1125 - i) - 1 (dbf); left and
; i advance by it
u2_chunk:
	move.w	#1125,d0
	sub.w	u2_i,d0
	ext.l	d0
	cmp.l	u2_left,d0
	bls.s	.m
	move.l	u2_left,d0
.m:	sub.l	d0,u2_left
	add.w	d0,u2_i
	move.w	d0,d5
	subq.w	#1,d5
	rts
; after a run: the countdown when i reaches 1125. Z: no steps left
u2_chunkend:
	cmp.w	#1125,u2_i
	bne.s	.n
	clr.w	u2_i
	addq.w	#1,u2_index
	bsr	u2_count
.n:	tst.l	u2_left
	rts

; createplanet(xc d0, yc d1): 75000 steps of a random walk raising the land (+7 below 240),
; the countdown every 1125 steps; then the technology spots. A walk depends on the seed only:
; the steps are kept (u2_walk: bit 0/1 x-1/x+1, bit 2/3 y-1/y+1) with the generator after
; them, and a walk of the same seed (readyplanet's 3 calls, a planet seen again) replays them.
createplanet:
	ifd	PROFILE
	bsr	tim_ms
	bsr	scr_dbg
	endif
	movem.l	d3-d7/a3-a5,-(sp)
	mulu	#LAND_W,d0
	move.w	d0,d6			; x1 * 120
	move.w	d1,d7			; y1
	move.l	GS_LANDFORM(a6),a4
	lea	-LAND_W-1(a4),a4	; [x,y] = a4 + x*120 + y
	lea	u2_walk,a1
	move.l	a3,-(sp)
	move.l	#75000,u2_left
	moveq	#0,d0
	move.w	PLANET_SEED(a3),d0
	cmp.l	u2_wseed,d0
	beq	.replay
	moveq	#-1,d1
	move.l	d1,u2_wseed
	bsr	mt_seed			; randseed := seed
	lea	mt_state,a5		; the generator inline (mt_u32)
	move.w	mt_index,d0
	lsl.w	#2,d0
	add.w	d0,a5
	lea	mt_state+MT_N*4,a3
.wchunk:
	bsr	u2_chunk
.step:	U2_R3	.xm,.x0,.xp		; x1 := x1 - 1 + random(3), wrapped
.xm:	sub.w	#LAND_W,d6
	bne.s	.xm1
	move.w	#240*LAND_W,d6
.xm1:	move.b	#1,(a1)
	bra.s	.y
.x0:	clr.b	(a1)
	bra.s	.y
.xp:	add.w	#LAND_W,d6
	cmp.w	#240*LAND_W,d6
	bls.s	.xp1
	moveq	#LAND_W,d6
.xp1:	move.b	#2,(a1)
.y:	U2_R3	.ym,.y0,.yp		; y1 := y1 - 1 + random(3), wrapped
.ym:	subq.w	#1,d7
	bne.s	.ym1
	moveq	#120,d7
.ym1:	addq.b	#4,(a1)+
	bra.s	.r
.y0:	addq.l	#1,a1
	bra.s	.r
.yp:	addq.w	#1,d7
	cmp.w	#120,d7
	bls.s	.yp1
	moveq	#1,d7
.yp1:	addq.b	#8,(a1)+
.r:	lea	0(a4,d6.w),a0		; landform^[x1,y1]
	cmp.b	#240,0(a0,d7.w)
	bhs.s	.n
	addq.b	#7,0(a0,d7.w)
.n:	dbf	d5,.step
	bsr	u2_chunkend
	bne	.wchunk
	move.l	a5,d0			; mt_index; keep the state after the walk
	sub.l	#mt_state,d0
	lsr.w	#2,d0
	move.w	d0,mt_index
	lea	mt_state,a0
	lea	u2_wstate,a1
	move.w	#MT_N/2-1,d0
.sv:	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbf	d0,.sv
	move.w	mt_index,u2_wsidx
	move.l	(sp)+,a3
	moveq	#0,d0
	move.w	PLANET_SEED(a3),d0
	move.l	d0,u2_wseed
	bra	.tech
.replay:
	bsr	u2_chunk
.rs:	move.b	(a1)+,d0
	btst	#0,d0
	bne.s	.rxm
	btst	#1,d0
	beq.s	.ry
	add.w	#LAND_W,d6
	cmp.w	#240*LAND_W,d6
	bls.s	.ry
	moveq	#LAND_W,d6
	bra.s	.ry
.rxm:	sub.w	#LAND_W,d6
	bne.s	.ry
	move.w	#240*LAND_W,d6
.ry:	btst	#2,d0
	bne.s	.rym
	btst	#3,d0
	beq.s	.rr
	addq.w	#1,d7
	cmp.w	#120,d7
	bls.s	.rr
	moveq	#1,d7
	bra.s	.rr
.rym:	subq.w	#1,d7
	bne.s	.rr
	moveq	#120,d7
.rr:	lea	0(a4,d6.w),a0
	cmp.b	#240,0(a0,d7.w)
	bhs.s	.rn
	addq.b	#7,0(a0,d7.w)
.rn:	dbf	d5,.rs
	bsr	u2_chunkend
	bne	.replay
	lea	u2_wstate,a0
	lea	mt_state,a1
	move.w	#MT_N/2-1,d0
.rst:	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbf	d0,.rst
	move.w	u2_wsidx,mt_index
	move.l	(sp)+,a3
.tech:
	move.w	GS_CURPLAN(a6),d0	; tl := GetTechnologyLevel(curplan)
	bsr	gettechnologylevel
	tst.w	d0
	ble.s	.x
	move.w	d0,d1			; tl := hi(tl)*10 + lo(tl); tl := tl*tl div 10
	lsr.w	#8,d1
	mulu	#10,d1
	and.w	#$ff,d0
	add.w	d1,d0
	muls	d0,d0
	divs	#10,d0
	move.w	d0,d5
	ble.s	.x
	subq.w	#1,d5
.tl:	move.w	#240,d0
	bsr	mt_random
	move.w	d0,d6
	moveq	#120,d0
	bsr	mt_random
	move.w	d6,d1
	mulu	#LAND_W,d1
	add.w	d0,d1
	lea	0(a4,d1.l),a0
	moveq	#0,d0
	move.b	(a0),d0
	cmp.w	GS_WATER(a6),d0
	ble.s	.nt
	st	(a0)
.nt:	dbf	d5,.tl
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; printxy(90,170, str(200-index:3))
u2_count:
	movem.l	d0-d2/a0-a2,-(sp)
	move.w	#200,d0
	sub.w	u2_index,d0
	ext.l	d0
	moveq	#3,d1
	lea	u2_num,a0
	bsr	int_str
	moveq	#90,d0
	move.w	#170,d1
	lea	u2_num,a0
	bsr	printxy
	bsr	ms_flush
	movem.l	(sp)+,d0-d2/a0-a2
	rts

; ---------------------------------------------------------------
; readystar (utils2.pas 1464)
readystar:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	mousehide
	bsr	reloadbackground
	st	GS_SHOWPLANET(a6)
	bsr	u2_curplan
	moveq	#0,d0
	move.w	PLANET_SEED(a3),d0
	bsr	mt_seed
	moveq	#0,d0			; compressfile(current) - the ST keeps snapshot 1 below
	clr.w	u2_index
	move.b	PLANET_MODE(a3),d0	; 1: 2000/120  2: 3025/83  3: 900/16
	subq.w	#1,d0
	add.w	d0,d0
	lea	.rad,a0
	move.w	0(a0,d0.w),GS_RADIUS(a6)
	lea	.col,a0
	move.w	0(a0,d0.w),d3		; i
	bsr	sphere_setup
	move.l	GS_LANDFORM(a6),a0
	move.w	#28800-1,d1
.fl:	move.b	d3,(a0)+
	dbf	d1,.fl
	move.l	GS_PLANET(a6),a0
	move.w	#14400/4-1,d1
.fp:	clr.l	(a0)+
	dbf	d1,.fp
	addq.w	#6,d3			; i2 := i + 6
	bsr	u2_approach
	lea	u2_s_star,a0
	bsr	u2_approach_text
	clr.w	u2_index
	clr.w	u2_i
	move.w	d3,d0
	move.w	#200,d1
	moveq	#90,d2
	bsr	createstar
	move.w	d3,d0
	moveq	#30,d1
	moveq	#30,d2
	bsr	createstar
	move.w	d3,d0
	moveq	#120,d1
	moveq	#60,d2
	bsr	createstar
	bsr	u2_unapproach		; (loadscreen(current): the same screen)
	bsr	showtime
	bsr	u2_grabplanet
	bsr	makestar
	bsr	checkstats
	bsr	mouseshow
	bsr	fadein
	move.w	#31,GS_TCOLOR(a6)
	bsr	println
	lea	u2_s_orbit,a0
	bsr	print
	move.w	#1,GS_SPHERE(a6)
	bsr	mt_randomize
	movem.l	(sp)+,d3-d7/a3-a5
	rts
.rad:	dc.w	2000,3025,900
.col:	dc.w	120,83,16

; createstar(c d0, xc d1, yc d2): like createplanet, +1 below c, no technology spots
createstar:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,d5			; c
	move.w	d1,d6
	move.w	d2,d7
	move.l	GS_LANDFORM(a6),a4
	lea	-LAND_W-1(a4),a4
	move.l	#75000,d2
	move.l	d2,u2_cnt
	move.l	#$55555556,d3
	move.l	#$aaaaaaab,d4
.step:	bsr	mt_u32
	cmp.l	d3,d0
	blo.s	.xm
	cmp.l	d4,d0
	blo.s	.x0
	addq.w	#1,d6
	bra.s	.x0
.xm:	subq.w	#1,d6
.x0:	bsr	mt_u32
	cmp.l	d3,d0
	blo.s	.ym
	cmp.l	d4,d0
	blo.s	.y0
	addq.w	#1,d7
	bra.s	.y0
.ym:	subq.w	#1,d7
.y0:	cmp.w	#240,d6
	ble.s	.w1
	moveq	#1,d6
	bra.s	.w2
.w1:	cmp.w	#1,d6
	bge.s	.w2
	move.w	#240,d6
.w2:	cmp.w	#120,d7
	ble.s	.w3
	moveq	#1,d7
	bra.s	.w4
.w3:	cmp.w	#1,d7
	bge.s	.w4
	moveq	#120,d7
.w4:	move.w	d6,d0
	mulu	#LAND_W,d0
	add.w	d7,d0
	lea	0(a4,d0.l),a0
	moveq	#0,d0
	move.b	(a0),d0
	cmp.w	d5,d0
	bge.s	.hi
	addq.b	#1,(a0)
.hi:	addq.w	#1,u2_i			; (createstar counts in utils2's i)
	cmp.w	#1125,u2_i
	bne.s	.nx
	clr.w	u2_i
	addq.w	#1,u2_index
	bsr	u2_count
.nx:	subq.l	#1,u2_cnt
	bne	.step
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; ---------------------------------------------------------------
; journey.pas makesphere1 / makesphere2: rows 6..spherei / spherei+1..maxspherei of planet^.
; The original's per-pixel rules (lighting alt from ecl and the column, water, special colours,
; the grey ramp) are folded into a table u2_tab[alt][land value] (alt capped at 31: every rule
; is saturated by then) built once per planet (u2_shade), and one pointer per column index;
; per frame only the texture columns' offsets change (rotation c).
makesphere1:
	moveq	#6,d0
	move.w	GS_SPHEREI(a6),d1
	bra.s	u2_sphere_rows
makesphere2:
	move.w	GS_SPHEREI(a6),d0
	addq.w	#1,d0
	move.w	GS_MAXSPHEREI(a6),d1
	; fall through
u2_sphere_rows:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,d6			; i
	move.w	d1,u2_last
	move.l	u2_sph,a1		; the radius's rows: skip to row d0
	lea	SPH_ROWS(a1),a1
	move.w	d0,d1
	subq.w	#6,d1
	bra.s	.sk
.skl:	move.w	2(a1),d2
	addq.w	#4+1,d2
	and.w	#$fffe,d2
	add.w	d2,a1
.sk:	dbf	d1,.skl
	move.l	a1,u2_rowp
	lea	u2_colofs,a5		; colofs[index] := (j2-1)*120, j2 := index + c (wrapped at 240)
	move.w	GS_C(a6),d1
	moveq	#0,d0			; index
.co:	move.w	d0,d2
	add.w	d1,d2
	cmp.w	#240,d2
	ble.s	.c1
	sub.w	#240,d2
.c1:	subq.w	#1,d2
	mulu	#LAND_W,d2
	move.w	d2,(a5)+
	addq.w	#1,d0
	cmp.w	#128,d0
	bne.s	.co
	lea	u2_colofs,a5
	lea	u2_rowtab,a3
.row:	cmp.w	u2_last,d6
	bgt	.x
	move.w	d6,d0			; ii := 60*i div spherei
	mulu	#60,d0
	divu	GS_SPHEREI(a6),d0
	move.l	GS_LANDFORM(a6),a4	; a4 = landform^[1, ii]
	lea	-1(a4,d0.w),a4
	move.w	d6,d0			; ofsy := i + offset (planet^ row, 1-based)
	add.w	GS_OFFSET(a6),d0
	subq.w	#1,d0
	mulu	#120,d0
	move.l	GS_PLANET(a6),a2
	add.l	d0,a2
	move.l	u2_rowp,a1
	move.w	(a1)+,d0		; ofsx := pm[i] + offset: the first pixel is planet^[ofsy, ofsx+1]
	add.w	GS_OFFSET(a6),d0
	add.w	d0,a2
	move.w	(a1)+,d7		; n
	move.w	d7,d0
	addq.w	#1,d0
	and.w	#$fffe,d0
	lea	0(a1,d0.w),a0
	move.l	a0,u2_rowp		; next row
	subq.w	#1,d7
	bmi.s	.nr
	moveq	#0,d3			; the first pixel (j = 1) may light differently
	move.b	(a1)+,d3
	add.w	d3,d3
	move.w	0(a5,d3.w),d0
	moveq	#0,d1
	move.b	0(a4,d0.w),d1
	move.l	u2_first,d0
	bne.s	.f1
	add.w	d3,d3
	move.l	0(a3,d3.w),a0
	bra.s	.f2
.f1:	move.l	d0,a0
.f2:	move.b	0(a0,d1.w),(a2)+
	bra.s	.pn
.px:	moveq	#0,d3			; the others: colour := rowtab[index][landform^[j2, ii]]
	move.b	(a1)+,d3
	add.w	d3,d3
	move.w	0(a5,d3.w),d0
	moveq	#0,d1
	move.b	0(a4,d0.w),d1
	add.w	d3,d3
	move.l	0(a3,d3.w),a0
	move.b	0(a0,d1.w),(a2)+
.pn:	dbf	d7,.px
.nr:	addq.w	#1,d6
	bra	.row
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; u2_shade: the colour tables of the planet in orbit (after colorlookup, water, spcindex, ecl):
; u2_tab[a][v] for alt a = 0..31, land value v; u2_rowtab[index] -> the row of alt(index)
; (journey.pas: ecl > 170: (index-ecl+186) div 2; else index = xw: 10, (ecl-index) div 2;
; at least 0; Pascal div truncates); u2_first -> the row of alt 10 when ecl > 170 (the first
; pixel of each row), else 0 (the column's own)
u2_shade:
	movem.l	d3-d6/a3,-(sp)
	lea	u2_tab,a3
	moveq	#0,d3			; a
.a:	moveq	#0,d4			; v
.v:	lea	GS_COLORLOOKUP(a6),a0
	moveq	#0,d1
	move.b	0(a0,d4.w),d1		; z
	move.w	GS_WATERINDEX(a6),d2
	cmp.w	d2,d1
	bne.s	.nw
	cmp.w	#6,d3			; water: lit edge
	bge.s	.put2
	addq.w	#6,d2
	sub.w	d3,d2
.put2:	move.w	d2,d1
	bra.s	.put
.nw:	cmp.w	#247,d1
	blo.s	.ns
	moveq	#116,d1
	bra.s	.put
.ns:	cmp.w	#6,d1
	bhs.s	.ng
	lea	GS_SPCINDEX2(a6),a0	; z < 6: if alt > spcindex2[z] then 1 else spcindex[z]-alt
	moveq	#0,d2
	move.b	0(a0,d1.w),d2
	cmp.w	d2,d3
	ble.s	.sp
	moveq	#1,d1
	bra.s	.put
.sp:	lea	GS_SPCINDEX(a6),a0
	move.b	0(a0,d1.w),d1
	sub.b	d3,d1
	bra.s	.put
.ng:	cmp.w	#32,d1
	bhs.s	.put
	cmp.w	d3,d1			; z < 32: if z > alt then z-alt else 1
	ble.s	.one
	sub.w	d3,d1
	bra.s	.put
.one:	moveq	#1,d1
.put:	move.b	d1,(a3)+
	addq.w	#1,d4
	cmp.w	#256,d4
	bne.s	.v
	addq.w	#1,d3
	cmp.w	#32,d3
	bne	.a
	lea	u2_rowtab,a3		; per column index: the row of its alt
	move.w	GS_ECL(a6),d5
	moveq	#0,d4			; index
.i:	cmp.w	#170,d5
	ble.s	.lo
	move.w	d4,d0
	sub.w	d5,d0
	add.w	#186,d0
	bra.s	.div
.lo:	cmp.w	GS_XW(a6),d4
	bne.s	.lo2
	moveq	#10,d0
	bra.s	.st
.lo2:	move.w	d5,d0
	sub.w	d4,d0
.div:	ext.l	d0
	divs	#2,d0
.st:	tst.w	d0
	bpl.s	.p
	moveq	#0,d0
.p:	cmp.w	#31,d0
	ble.s	.c
	moveq	#31,d0
.c:	lsl.w	#8,d0
	lea	u2_tab,a0
	add.w	d0,a0
	move.l	a0,(a3)+
	addq.w	#1,d4
	cmp.w	#128,d4
	bne.s	.i
	clr.l	u2_first
	cmp.w	#170,d5
	ble.s	.x
	lea	u2_tab+10*256,a0
	move.l	a0,u2_first
.x:	movem.l	(sp)+,d3-d6/a3
	rts

; makesphere3: planet^ to the screen, c := c + 1 (wrapping at 240)
makesphere3:
	ifd	PROFILE
	bsr	tim_ms
	bsr	scr_dbg
	endif
	bsr	mousehide
	moveq	#28,d0
	moveq	#13,d1
	bsr	ms_addr
	move.l	GS_PLANET(a6),a1	; (both even: long copies)
	moveq	#120-1,d1
.r:	moveq	#120/4-1,d0
	move.l	a0,a2
.c:	move.l	(a1)+,(a2)+
	dbf	d0,.c
	lea	MS_W(a0),a0
	dbf	d1,.r
	move.l	d3,-(sp)
	moveq	#28,d0
	moveq	#13,d1
	move.w	#147,d2
	move.w	#132,d3
	bsr	ms_dirty
	move.l	(sp)+,d3
	bsr	mouseshow
	addq.w	#1,GS_C(a6)
	cmp.w	#240,GS_C(a6)
	ble.s	.x
	sub.w	#240,GS_C(a6)
.x:	rts

makesphere:
	bsr	makesphere1
	bsr	makesphere2
	bra	makesphere3

; journey.pas makestar: rows 6..2*r2+4, colour = landform (darker at the rim)
makestar:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	u2_sph,a5
	lea	SPH_ROWS(a5),a5
	move.l	GS_LANDFORM(a6),a4
	lea	-LAND_W-1(a4),a4
	moveq	#6,d6			; i
.row:	move.w	GS_R2(a6),d0
	add.w	d0,d0
	addq.w	#4,d0
	cmp.w	d0,d6
	bgt	.x
	move.w	d6,d0
	add.w	GS_OFFSET(a6),d0
	subq.w	#1,d0
	mulu	#120,d0
	move.l	GS_PLANET(a6),a2
	add.l	d0,a2
	move.w	(a5)+,d0
	add.w	GS_OFFSET(a6),d0
	add.w	d0,a2
	move.w	(a5)+,d7
	move.l	a5,a1
	move.w	d7,d0
	addq.w	#1,d0
	and.w	#$fffe,d0
	add.w	d0,a5
	subq.w	#1,d7
	bmi.s	.nr
	moveq	#1,d5			; j
.px:	moveq	#0,d3
	move.b	(a1)+,d3		; index
	move.w	d3,d0			; j2 := index + c
	add.w	GS_C(a6),d0
	cmp.w	#240,d0
	ble.s	.j2
	sub.w	#240,d0
.j2:	moveq	#0,d4			; alt: 6 at both ends
	cmp.w	#1,d5
	beq.s	.a6
	cmp.w	GS_XW(a6),d3
	bne.s	.a0
.a6:	moveq	#6,d4
.a0:	mulu	#LAND_W,d0
	add.w	d6,d0			; landform^[j2, i]
	moveq	#0,d1
	move.b	0(a4,d0.l),d1
	move.w	d1,d2
	and.w	#15,d2
	cmp.w	d2,d4			; if alt > landform mod 16 then landform div 16
	ble.s	.lt
	lsr.w	#4,d1
	bra.s	.put
.lt:	sub.w	d4,d1
.put:	move.b	d1,(a2)+
	addq.w	#1,d5
	dbf	d7,.px
.nr:	addq.w	#1,d6
	bra	.row
.x:	movem.l	(sp)+,d3-d7/a3-a5
	bra	makesphere3

	section	data
u2_wseed:	dc.l	-1		; the seed of the walk in u2_walk (-1: none)
u2_main:	dc.b	"MAIN",0
u2_cloud:	dc.b	"CLOUD",0
u2_s_planet:	dc.b	21,"Approaching planet..."
u2_s_star:	dc.b	19,"Approaching star..."
u2_s_eta:	dc.b	19,"ETA T Minus     hrs"
u2_s_orbit:	dc.b	17,"Orbit achieved..."
	even

	section	bss
u2_walk:	ds.b	75000
	even
u2_dbl:		ds.b	640
	even
u2_wstate:	ds.l	MT_N		; the generator after the walk
u2_wsidx:	ds.w	1
	even
u2_left:	ds.l	1
u2_sphere:	ds.l	1		; DATA\SPHERE.DAT
u2_sph:		ds.l	1		; the current radius's record
u2_cnt:		ds.l	1
u2_index:	ds.w	1		; utils2's index (the countdown)
u2_i:		ds.w	1
u2_ii:		ds.w	1
u2_last:	ds.w	1
u2_num:		ds.b	12
	even
u2_rowp:	ds.l	1
u2_first:	ds.l	1
u2_rowtab:	ds.l	128		; per column index: its row of u2_tab
u2_colofs:	ds.w	128		; per column index: the texture column's offset this frame
u2_tab:		ds.b	32*256		; [alt 0-31][land value] -> colour
