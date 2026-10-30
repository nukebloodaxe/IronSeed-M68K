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
U2_SPHW		equ	10600		; words of the largest radius's rows (3025: 10570)

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
	sf	u2_xok			; (u2_sphere_rows and makestar build their pixel tables again)
	sf	u2_sxok
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
	lea	u2_sphw,a2		; and the rows as words for u2_sphere_rows
.r:	move.w	(a0),(a1)+
	move.w	(a0)+,(a2)+		; pm
	move.w	(a0)+,d2		; n
	move.w	d2,(a2)+
	move.w	d2,d0			; the next row: after n bytes, even
	addq.w	#1,d0
	and.w	#$fffe,d0
	pea	0(a0,d0.w)
	subq.w	#1,d2
	bmi.s	.e
.w:	moveq	#0,d0			; index * 2
	move.b	(a0)+,d0
	add.w	d0,d0
	move.w	d0,(a2)+
	dbf	d2,.w
.e:	move.l	(sp)+,a0
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
	bgt	.gas
	bra	.cloud
.n0:	cmp.b	#6,d0
	bne.s	.reg
	cmp.b	#2,d1
	beq	.ast
.reg:	bsr	u2_approach		; 'Approaching planet...'
	lea	u2_s_planet,a0
	bsr	u2_approach_text
	clr.w	u2_index
	clr.w	u2_i
	PMARK	20			; (PROFILE builds: the three walks' time, tools/dbgtimes.py)
	move.w	#200,d0
	moveq	#90,d1
	bsr	createplanet
	moveq	#30,d0
	moveq	#30,d1
	bsr	createplanet
	moveq	#120,d0
	moveq	#60,d1
	bsr	createplanet
	PMARK	21
	ifd	LANDDUMP
	bsr	u2_landdump
	endif
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
.tail:	bsr	checkstats
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
.gas:	bsr	creategasplanet		; a gas giant (sphere 2)
	bsr	.appr
	move.w	#2,GS_SPHERE(a6)
	bsr	u2_unapproach
	bsr	u2_grabplanet
	bsr	makegasplanet
	bra	.tail
.ast:	bsr	.clrpl			; an asteroid field (sphere 3)
	bsr	makeastoroidfield
	bsr	.appr
	move.w	#3,GS_SPHERE(a6)
	bsr	u2_unapproach
	bsr	drawastoroid
	bra	.tail
.cloud:	bsr	.clrpl			; a gas cloud (sphere 3)
	bsr	makecloud
	bsr	.appr
	bsr	u2_grabplanet		; (of the approach screen: zeros)
	move.w	#3,GS_SPHERE(a6)
	bsr	u2_unapproach
	bsr	drawastoroid
	bra	.tail
.appr:	bsr	u2_approach
	lea	u2_s_planet,a0
	bsr	u2_approach_text
	bra	gp_countdown
.clrpl:	move.l	GS_PLANET(a6),a0	; fillchar(planet^, 14400, 0); backgrx := backgry := 0
	move.w	#14400/4-1,d0
.cp:	clr.l	(a0)+
	dbf	d0,.cp
	clr.w	GS_BACKGRX(a6)
	clr.w	GS_BACKGRY(a6)
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
	bsr	ms_inval		; (the mirror: Phase 6k)
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
	bsr	ms_unsnap
	; fall through: the band design for the new orbit (still faded out)

; u2_design (Phase 6i, 6k): the bridge's band design for the ship's orbit. The designs differ only
; in band 1 (the viewscreen, the status panel and lights: lines 12-139), each fitted on what that
; orbit puts there (tools/mkmain.py star_modes; tools/mkbridge.py for the planets, from the Linux
; build's own shots). Codes (ms_design): 0 MAIN; around a star (orbiting = 0) 1-3 = MAINSn for the
; star's mode n; in orbit of a planet 4/5 = MAING1/G2 (a gas giant, creategasplanet's colour set
; gp_cols 32/48/64 or 112/128/96), 6 = MAINC (a gas cloud: state 0, mode 0/1), 7 = MAINA (an
; asteroid field: state 6, mode 2), 16 + 4*state + mode = MAINPsm (a land sphere, state 1-6,
; mode 1-3). A missing file falls back to MAIN. Called while faded out (u2_unapproach): loads
; the header (DATA\MAINx.ISP), sets reps, bands, LUTs, recolours from GS_COLORS (vid_set256 -
; the fade level stays) and marks that band's lines dirty. ms_design (mscr.s, kept by the
; snapshots) says which is in use.
u2_design:
	movem.l	d3/a3,-(sp)
	bsr	u2_dcode
	move.w	d0,d3
.w:	cmp.w	ms_design,d3
	beq	.x
	lea	u2_dname,a0		; "DATA\MAIN" + suffix + ".ISP"
	lea	u2_dpath,a1
.cp:	move.b	(a0)+,(a1)+
	bne.s	.cp
	subq.l	#1,a1
	move.w	d3,d0
	bsr	u2_dsuffix		; a0 = the suffix (0-terminated)
.cs:	move.b	(a0)+,(a1)+
	bne.s	.cs
	subq.l	#1,a1
	move.b	#'.',(a1)+
	move.b	#'I',(a1)+
	move.b	#'S',(a1)+
	move.b	#'P',(a1)+
	clr.b	(a1)
	bsr	mem_mark
	move.l	d0,-(sp)
	move.l	#ISP_DATA+64,d0
	bsr	mem_alloc
	bcs.s	.r
	move.l	a0,a3
	lea	u2_dpath,a0
	move.l	a3,a1
	move.l	#ISP_DATA+64,d0
	bsr	fil_load
	bcc.s	.ok
	move.l	(sp)+,d0		; (no such file: MAIN, unless that is the one missing)
	bsr	mem_release
	tst.w	d3
	beq.s	.x
	moveq	#0,d3
	bra	.w
.ok:	lea	ISP_DATA(a3),a0
	bsr	vid_set_reps
	lea	ISP_BANDS(a3),a0
	bsr	vid_set_bands
	lea	ISP_LUTS(a3),a0
	bsr	vid_set_luts
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	moveq	#0,d0			; band 1's lines
	move.w	ISP_BANDS+2+34(a3),d1
	move.w	#319,d2
	move.w	d3,-(sp)
	move.w	ISP_BANDS+2+2*34(a3),d3
	subq.w	#1,d3
	bsr	ms_dirty
	move.w	(sp)+,d3
	move.w	d3,ms_design
.r:	move.l	(sp)+,d0
	bsr	mem_release
.x:	movem.l	(sp)+,d3/a3
	rts

; u2_dcode: the design code of the ship's orbit (u2_design)   out: d0.w = code   trashes: d1/a0
u2_dcode:
	move.l	a3,-(sp)
	moveq	#0,d0
	tst.w	GS_SHIP+SHIP_ORBITING(a6)
	bne.s	.pl
	bsr	u2_curplan		; a star: its mode 1-3
	moveq	#0,d0
	move.b	PLANET_MODE(a3),d0
	cmp.w	#3,d0
	bls.s	.x
	moveq	#0,d0
	bra.s	.x
.pl:	bsr	u2_curplan
	moveq	#0,d0
	moveq	#0,d1
	move.b	PLANET_STATE(a3),d0
	move.b	PLANET_MODE(a3),d1
	tst.b	d0
	bne.s	.n0
	moveq	#6,d0			; state 0: a cloud (mode 0/1) or a gas giant
	cmp.b	#1,d1
	bls.s	.x
	moveq	#4,d0
	cmp.w	#32,gp_cols
	beq.s	.x
	moveq	#5,d0
	bra.s	.x
.n0:	cmp.b	#6,d0
	bne.s	.n6
	cmp.b	#2,d1
	bne.s	.n6
	moveq	#7,d0
	bra.s	.x
.n6:	cmp.b	#6,d0			; a land sphere: 16 + 4*state + mode
	bhi.s	.z
	subq.b	#1,d1
	cmp.b	#2,d1
	bhi.s	.z
	addq.b	#1,d1
	lsl.w	#2,d0
	add.w	d1,d0
	add.w	#16,d0
	bra.s	.x
.z:	moveq	#0,d0
.x:	move.l	(sp)+,a3
	rts

; u2_dsuffix: d0.w = a design code -> a0 = its name's suffix after "MAIN"   trashes: d0-d1
u2_dsuffix:
	lea	u2_dsbuf,a0
	tst.w	d0
	beq.s	.z
	cmp.w	#16,d0
	bhs.s	.p
	cmp.w	#3,d0
	bhi.s	.o
	move.b	#'S',(a0)		; 1-3: Sn
	add.b	#'0',d0
	move.b	d0,1(a0)
	clr.b	2(a0)
	rts
.o:	subq.w	#4,d0			; 4-7: G1 G2 C A
	lsl.w	#2,d0
	lea	u2_dsfx(pc,d0.w),a0
	rts
.p:	sub.w	#16,d0			; 16+: Psm
	move.w	d0,d1
	lsr.w	#2,d1
	and.w	#3,d0
	move.b	#'P',(a0)
	add.b	#'0',d1
	move.b	d1,1(a0)
	add.b	#'0',d0
	move.b	d0,2(a0)
	clr.b	3(a0)
	rts
.z:	clr.b	(a0)
	rts
u2_dsfx: dc.b	"G1",0,0,"G2",0,0,"C",0,0,0,"A",0,0,0
	even


; ---------------------------------------------------------------
; The walks of createplanet/createstar (Phase 6g): random(3) = (u32*3) >> 32 is decided by the
; top byte of the tempered generator number - below $55: 0, $56-$A9: 1, above $AA: 2 - except
; when it is $55 or $AA (1 in 128): then u2_tie tempers fully. Tempering is linear over GF(2),
; so the top byte = u2_tha[high word of the state word] ^ u2_tla[low word] (2 x 64 KB, built
; once by u2_tinit from 16 basis bytes each). A walk only counts visits per cell (u2_cmap, the
; landform's layout; at most 63 visits for a planet walk, 95 for a star's three, over every seed
; random(64000) gives: no byte wraps), then u2_apply adds them to the landform in one pass with
; the original's rule (+7 while below 240, or +1 while below c) - the order of the increments
; does not matter. readyplanet's three createplanet walks are one walk (same seed) translated on
; the 240x120 torus: the 2nd and 3rd apply the same map shifted.

; U2_T3 minus,zero,plus: random(3) on the next generator number; a5 into mt_state, a3 its end,
; a2 = u2_tha, a1 = u2_tla, d1/d2 with clear high words (u2_update/u2_tie keep it so).
; U2_F3: the same without the end check (the caller knows a number is left). Trashes d0-d2/a0.
U2_T3	macro
	cmp.l	a3,a5
	blo.s	.a\@
	bsr	u2_update
.a\@:	U2_F3	\1,\2,\3
	endm
U2_F3	macro
	move.w	(a5)+,d1
	move.w	(a5)+,d2
	move.b	0(a2,d1.l),d0
	move.b	0(a1,d2.l),d1
	eor.b	d1,d0
	cmp.b	#$55,d0
	blo	\1
	beq.s	.t\@
	cmp.b	#$aa,d0
	blo	\2
	bne	\3
.t\@:	bsr	u2_tie
	subq.w	#1,d0
	bmi	\1
	beq	\2
	bra	\3
	endm
; one step of the walk (U2_T3 or U2_F3 as \1): d6 = x * 120, d7 = y, a4 = the map - 121
U2_STEP	macro
	\1	.xm\@,.x0\@,.xp\@		; x1 := x1 - 1 + random(3), wrapped
.xm\@:	sub.w	#LAND_W,d6
	bne.s	.x0\@
	move.w	#240*LAND_W,d6
	bra.s	.x0\@
.xp\@:	add.w	#LAND_W,d6
	cmp.w	#240*LAND_W,d6
	bls.s	.x0\@
	moveq	#LAND_W,d6
.x0\@:	\1	.ym\@,.y0\@,.yp\@		; y1 := y1 - 1 + random(3), wrapped
.ym\@:	subq.w	#1,d7
	bne.s	.y0\@
	moveq	#120,d7
	bra.s	.y0\@
.yp\@:	addq.w	#1,d7
	cmp.w	#120,d7
	bls.s	.y0\@
	moveq	#1,d7
.y0\@:	lea	0(a4,d6.w),a0		; a visit of [x1,y1]
	addq.b	#1,0(a0,d7.w)
	endm

u2_update:
	bsr	mt_update
	lea	mt_state,a5
	moveq	#0,d1
	moveq	#0,d2
	rts

; d0.w = random(3) of the generator number before a5 (tempered in full)  d1/d2 cleared
u2_tie:	move.l	-4(a5),d0
; u2_r3(d0.l = an untempered state word) -> d0.w = random(3) of it  d1/d2 cleared
u2_r3:	move.l	d0,d1			; y ^= y >> 11
	moveq	#11,d2
	lsr.l	d2,d1
	eor.l	d1,d0
	move.l	d0,d1			; y ^= (y << 7) & $9D2C5680
	lsl.l	#7,d1
	and.l	#$9D2C5680,d1
	eor.l	d1,d0
	move.l	d0,d1			; y ^= (y << 15) & $EFC60000
	moveq	#15,d2
	lsl.l	d2,d1
	and.l	#$EFC60000,d1
	eor.l	d1,d0
	move.l	d0,d1			; y ^= y >> 18
	moveq	#18,d2
	lsr.l	d2,d1
	eor.l	d1,d0
	moveq	#0,d1
	moveq	#0,d2
	cmp.l	#$55555556,d0
	blo.s	.0
	cmp.l	#$aaaaaaab,d0
	blo.s	.1
	moveq	#2,d0
	rts
.1:	moveq	#1,d0
	rts
.0:	moveq	#0,d0
	rts

; build the two tempering tables once (~0.2 s)
u2_tinit:
	tst.b	u2_tok
	bne.s	.x
	movem.l	d3/a3,-(sp)
	lea	u2_tha,a0
	lea	u2_bhi,a1
	bsr.s	.build
	lea	u2_tla,a0
	lea	u2_blo,a1
	bsr.s	.build
	bsr	u2_pinit
	st	u2_tok
	movem.l	(sp)+,d3/a3
.x:	rts
; a0 = table (65536 bytes), a1 = its 16 basis bytes (bit 0 first): t[2^k + j] = t[j] ^ basis[k]
.build:	clr.b	(a0)
	move.b	(a1)+,1(a0)		; bit 0
	move.b	(a1),d0			; bit 1
	move.b	d0,2(a0)
	move.b	1(a0),d1
	eor.b	d1,d0
	move.b	d0,3(a0)
	addq.l	#1,a1
	moveq	#4,d1			; entries so far
	moveq	#16-2-1,d2
.k:	moveq	#0,d0			; the basis byte in all four bytes of a long
	move.b	(a1)+,d0
	move.w	d0,d3
	lsl.w	#8,d3
	or.w	d3,d0
	move.w	d0,d3
	swap	d0
	move.w	d3,d0
	move.l	a0,a3			; entries 0..d1-1 -> d1..2*d1-1
	lea	0(a0,d1.l),a2
	move.l	d1,d3
	lsr.l	#2,d3
	subq.w	#1,d3
.c:	move.l	(a3)+,(a2)
	eor.l	d0,(a2)+
	dbf	d3,.c
	add.l	d1,d1
	dbf	d2,.k
	rts

; u2_clx/u2_cly (top byte -> the step's delta) and u2_pmap's border codes, once
u2_pinit:
	lea	u2_clx,a0
	lea	u2_cly,a1
	moveq	#0,d0
.t:	cmp.b	#$55,d0
	blo.s	.c0
	beq.s	.ct
	cmp.b	#$aa,d0
	blo.s	.c1
	beq.s	.ct
	move.w	#U2_PS,d1		; above $AA: random(3) = 2
	moveq	#1,d2
	bra.s	.ts
.c0:	move.w	#-U2_PS,d1		; below $55: 0
	moveq	#-1,d2
	bra.s	.ts
.c1:	moveq	#0,d1			; $56-$A9: 1
	moveq	#0,d2
	bra.s	.ts
.ct:	move.w	#U2_TIE,d1		; $55 / $AA: decided by the lower bytes
	move.w	d1,d2
.ts:	move.w	d1,(a0)+
	move.w	d2,(a1)+
	addq.b	#1,d0
	bne.s	.t
	lea	u2_pmap,a0		; border: $80 + xc*3 + yc
	moveq	#0,d1			; x
.x:	moveq	#0,d2			; xc
	tst.w	d1
	beq.s	.x1
	cmp.w	#241,d1
	bne.s	.x0
	moveq	#6,d2
	bra.s	.x0
.x1:	moveq	#3,d2
.x0:	clr.b	(a0)+			; (padding)
	moveq	#0,d0			; y
.y:	moveq	#0,d3
	tst.w	d0
	bne.s	.y1
	moveq	#1,d3
	bra.s	.y0
.y1:	cmp.w	#121,d0
	bne.s	.y0
	moveq	#2,d3
.y0:	add.w	d2,d3
	beq.s	.in
	or.b	#$80,d3
.in:	move.b	d3,(a0)+
	addq.w	#1,d0
	cmp.w	#122,d0
	bne.s	.y
	clr.b	(a0)+			; (padding)
	addq.w	#1,d1
	cmp.w	#242,d1
	bne.s	.x
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

; u2_walkc(x d0, y d1): 75000 steps from (x, y) on the generator as it stands (lazy seeding
; done first), each visit counted in u2_cmap (not cleared here), the countdown every 1125 steps
; of utils2's i; mt_index follows the numbers used.
; Phase 6l: the walk runs on u2_pmap, the torus with a one-cell border (x 0..241, y 0..121; cell
; [x,y] at x*U2_PS + y + 1, so the columns' cells 1..120 are long-aligned). A border cell holds
; $80 + its wrap code, so a step is: the two draws' deltas from u2_clx/u2_cly (a byte of
; u2_tha^u2_tla -> dx*U2_PS or dy, a tie -> U2_TIE), add, a sign test, a count (counts stay below
; 128: at most 63 visits a cell in one walk). The counts are added to u2_cmap at the end (bytes,
; no carries: < 96 + 64) and u2_pmap's inside cleared again. ~200 cycles a step (was ~264).
U2_PS		equ	124		; u2_pmap's column stride
U2_TIE		equ	$3000		; a tie's delta in the draw tables (both: $6000, still > 0)
u2_walkc:
	movem.l	d3-d7/a3-a5,-(sp)
	mulu	#U2_PS,d0
	lea	u2_pmap+1,a0		; a0 = the cell [x,y]
	add.l	d0,a0
	add.w	d1,a0
	move.l	#75000,u2_left
	move.l	a0,-(sp)
	moveq	#0,d0			; FPC's lazy re-seeding, as the first random() would
	bsr	mt_skip
	bsr	mt_own			; (the walk reads mt_state itself)
	bsr	u2_tinit
	move.l	(sp)+,a0
	lea	u2_tha,a2
	lea	u2_tla,a1
	lea	u2_clx,a3
	lea	u2_cly,a4
	lea	mt_state,a5
	move.w	mt_index,d0
	lsl.w	#2,d0
	add.w	d0,a5
	moveq	#0,d0			; d0/d6: only their low bytes are ever written
	moveq	#0,d6
	moveq	#0,d1			; d1/d2: clear high words (indexes .l)
	moveq	#0,d2
.chunk:	bsr	u2_chunk		; d5 = the chunk's steps - 1
	addq.w	#1,d5			; steps left in the chunk
.more:	moveq	#0,d0			; (calls leave d0's high byte dirty)
	move.l	#mt_state+MT_N*4,d7	; steps the generator's block still has both numbers for
	sub.l	a5,d7
	lsr.l	#3,d7
	beq	.edge
	cmp.w	d5,d7
	bls.s	.n
	move.w	d5,d7
.n:	sub.w	d7,d5
	move.w	d7,d4
	subq.w	#1,d4
.fast:	move.w	(a5)+,d1		; x1 := x1 - 1 + random(3)
	move.w	(a5)+,d2
	move.b	0(a2,d1.l),d0
	move.b	0(a1,d2.l),d2
	eor.b	d2,d0
	move.w	d0,d3
	add.w	d3,d3
	move.w	0(a3,d3.w),d3
	move.w	(a5)+,d1		; y1 := y1 - 1 + random(3)
	move.w	(a5)+,d2
	move.b	0(a2,d1.l),d6
	move.b	0(a1,d2.l),d2
	eor.b	d2,d6
	move.w	d6,d7
	add.w	d7,d7
	add.w	0(a4,d7.w),d3
	cmp.w	#U2_TIE/2,d3
	bge.s	.ftie
.fap:	add.w	d3,a0			; the step; wrapped when it lands on the border
	tst.b	(a0)
	bmi.s	.fwr
.fin:
	ifd	WALKCHK
	cmp.l	#u2_pmap+U2_PS+1,a0
	blo.s	.bad
	cmp.l	#u2_pmap+241*U2_PS,a0
	bhs.s	.bad
	tst.b	(a0)
	bmi.s	.bad
	endif
	addq.b	#1,(a0)			; a visit of [x1,y1]
	dbf	d4,.fast
	bra.s	.cend
.fwr:	bsr	u2_wrap
	bra	.fin
	ifd	WALKCHK
.bad:	illegal
	endif
.ftie:	move.l	-8(a5),d0		; a tie (1 in 64 steps): both numbers tempered in full
	bsr	u2_r3
	add.w	d0,d0
	move.w	.dxt(pc,d0.w),d3
	move.l	-4(a5),d0
	bsr	u2_r3
	add.w	d0,d3
	subq.w	#1,d3
	moveq	#0,d0
	bra.s	.fap
.dxt:	dc.w	-U2_PS,0,U2_PS
.edge:	bsr	u2_d3			; a step that crosses the block's end: the numbers one by one
	add.w	d0,d0
	move.w	.dxt(pc,d0.w),d3
	move.w	d3,-(sp)
	bsr	u2_d3
	move.w	(sp)+,d3
	add.w	d0,d3
	subq.w	#1,d3
	moveq	#0,d0
	add.w	d3,a0
	tst.b	(a0)
	bpl.s	.ein
	bsr	u2_wrap
.ein:	addq.b	#1,(a0)
	subq.w	#1,d5
.cend:	tst.w	d5
	bne	.more
	movem.l	d1-d2/a0-a2,-(sp)	; (the countdown prints)
	bsr	u2_chunkend
	movem.l	(sp)+,d1-d2/a0-a2
	bne	.chunk
	move.l	a5,d0			; mt_index
	sub.l	#mt_state,d0
	lsr.w	#2,d0
	move.w	d0,mt_index
	bsr.s	u2_fold
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; the walk's counts into u2_cmap (column by column, 30 longs each), u2_pmap's inside cleared
; again  trashes d0-d2/a0-a1
u2_fold:
	lea	u2_pmap+U2_PS+2,a0
	lea	u2_cmap,a1
	move.w	#240-1,d1
.fc:	moveq	#LAND_W/4-1,d2
.fl:	move.l	(a0)+,d0
	beq.s	.f0
	add.l	d0,(a1)+
	clr.l	-4(a0)
	dbf	d2,.fl
	bra.s	.fe
.f0:	addq.l	#4,a1
	dbf	d2,.fl
.fe:	addq.l	#U2_PS-LAND_W,a0
	dbf	d1,.fc
	rts

; ---------------------------------------------------------------
; Fast stars (Phase 6m, the options panel's row 10 = options[10] bit 1, David's choice): a
; star's three walks on a cheap generator instead of FPC's - the star looks like a star of its
; kind but not like the PC's. readystar ends with randomize, so no game state depends on the
; walks. The generator: additive lagged Fibonacci on longs (x[n] = x[n-24] + x[n-55]), seeded
; by an LCG from seed | mode << 16, consumed a byte a step: 252 values = the 9 steps (28 each,
; (dx, dy) = (b div 28) div 3 - 1, mod 3 - 1), 4 = stay. tools/faststar.c is the model (land:
; the landform; scan: every key's largest count of one cell in one walk = 72 < 128, so
; u2_pmap's sign bit stays the border's). ~70 cycles a step + ~14 for the generator.
U2_FNB		equ	2048		; longs made per block
; one fast step (u2_walkf's blocks are entered at a step: all steps the same size): the byte's
; delta, the wrap on the border, the visit
U2_FSTEP	macro
	moveq	#0,d0
	move.b	(a5)+,d0
	add.w	d0,d0
	add.w	0(a3,d0.w),a0
	tst.b	(a0)
	bpl.s	.k\@
	bsr.w	u2_wrap
.k\@:	addq.b	#1,(a0)			; a visit of [x1,y1]
	endm

; u2_fseed(key d0.l)  trashes d0-d2/a0
u2_fseed:
	lea	u2_fbuf,a0
	moveq	#55-1,d2
.s:	move.w	d0,d1			; s := s * 69069 + 1 = (s << 16) + s * 3533 + 1
	mulu	#3533,d1
	move.w	d0,-(sp)
	swap	d0
	mulu	#3533,d0
	swap	d0
	clr.w	d0
	add.l	d0,d1
	move.w	(sp)+,d0		; the old high word; s << 16 = the old low word above
	swap	d0
	clr.w	d0
	add.l	d1,d0
	addq.l	#1,d0
	move.l	d0,(a0)+
	dbf	d2,.s
	or.b	#1,u2_fbuf+3
	clr.w	u2_fav
	rts

; a new block: u2_fbuf[55..] from the recurrence, its last 55 longs to the front (the history of
; the next block); a5 = its first byte, u2_fav = U2_FNB*4  trashes d0-d1/a1-a2
u2_fblock:
	lea	u2_fbuf+55*4,a1
	move.w	#U2_FNB/4-1,d0
.g:	rept	4
	move.l	-24*4(a1),d1
	add.l	-55*4(a1),d1
	move.l	d1,(a1)+
	endr
	dbf	d0,.g
	lea	u2_fbuf+U2_FNB*4,a1
	lea	u2_fbuf,a2
	moveq	#55-1,d0
.c:	move.l	(a1)+,(a2)+
	dbf	d0,.c
	lea	u2_fbuf+55*4,a5
	move.w	#U2_FNB*4,u2_fav
	rts

; u2_fdt: the step's pointer delta per byte (dx * U2_PS + dy), once
u2_fdinit:
	tst.b	u2_fdok
	bne.s	.x
	lea	u2_fdt,a0
	moveq	#0,d0			; b
.b:	moveq	#0,d1
	cmp.w	#252,d0
	bhs.s	.st
	move.w	d0,d1			; k = b div 28: dx = k div 3 - 1, dy = k mod 3 - 1
	divu	#28,d1
	ext.l	d1
	divu	#3,d1
	move.l	d1,d2
	swap	d2			; dy + 1
	subq.w	#1,d1
	muls	#U2_PS,d1
	add.w	d2,d1
	subq.w	#1,d1
.st:	move.w	d1,(a0)+
	addq.w	#1,d0
	cmp.w	#256,d0
	bne.s	.b
	st	u2_fdok
.x:	rts

; u2_walkf(x d0, y d1): u2_walkc's walk (75000 steps, the countdown, the counts into u2_cmap)
; on the fast generator (u2_fseed first; it goes on across calls)
u2_walkf:
	movem.l	d3-d7/a3-a5,-(sp)
	movem.w	d0-d1,-(sp)
	bsr	u2_tinit		; (u2_pmap's border)
	bsr	u2_fdinit
	movem.w	(sp)+,d0-d1
	mulu	#U2_PS,d0
	lea	u2_pmap+1,a0		; a0 = the cell [x,y]
	add.l	d0,a0
	add.w	d1,a0
	move.l	#75000,u2_left
	lea	u2_fdt,a3
	move.l	u2_fp,a5
	moveq	#0,d0
.chunk:	bsr	u2_chunk		; d5 = the chunk's steps - 1
	move.w	d5,d0
	addq.w	#1,d0
	cmp.w	u2_fav,d0
	bls.s	.ok
	move.w	d0,-(sp)
	bsr	u2_fblock
	move.w	(sp)+,d0
.ok:	sub.w	d0,u2_fav
	move.w	d0,d6			; the steps in blocks of 8: the first block entered at its
	lsr.w	#3,d6			; (8 - n mod 8)-th step, d6 = the blocks after it
	and.w	#7,d0
	bne.s	.part
	subq.w	#1,d6
	bra.s	.blk
.part:	neg.w	d0			; (8 - r) steps' bytes in
	addq.w	#8,d0
	mulu	#(.blke-.blk)/8,d0
	lea	.blk(pc),a1
	add.w	d0,a1
	jmp	(a1)
.blk:	rept	8
	U2_FSTEP
	endr
.blke:	dbf	d6,.blk
	movem.l	d1-d2/a0-a2,-(sp)	; (the countdown prints)
	bsr	u2_chunkend
	movem.l	(sp)+,d1-d2/a0-a2
	bne	.chunk
	move.l	a5,u2_fp
	bsr	u2_fold
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; a0 on a border cell of u2_pmap: to its twin inside the torus  trashes d7
u2_wrap:
	moveq	#$7f,d7
	and.b	(a0),d7
	add.w	d7,d7
	add.w	.cor(pc,d7.w),a0
	rts
.cor:	dc.w	0,120,-120			; code = xc*3 + yc (1: 0 -> 240 / 120, 2: 241 / 121 -> 1)
	dc.w	240*U2_PS,240*U2_PS+120,240*U2_PS-120
	dc.w	-240*U2_PS,-240*U2_PS+120,-240*U2_PS-120

; d0.w = random(3) of the next generator number (a new block when needed: a5, d1/d2 as U2_T3)
u2_d3:	cmp.l	#mt_state+MT_N*4,a5
	blo.s	.a
	move.l	a0,-(sp)		; (mt_update trashes a0: the walk's cell)
	bsr	u2_update
	move.l	(sp)+,a0
.a:	U2_F3	.0,.1,.2
.0:	moveq	#0,d0
	rts
.1:	moveq	#1,d0
	rts
.2:	moveq	#2,d0
	rts

	ifd	LANDDUMP
; debug (ASMDEFS=-DLANDDUMP=1): the landform with its margin and the generator to C:\LANDn.BIN
u2_landdump:
	movem.l	d0-d2/a0-a2,-(sp)
	bsr	mt_own
	move.w	u2_ldn,d0
	addq.w	#1,u2_ldn
	add.b	#'A',d0
	move.b	d0,u2_ldname+7
	move.l	GS_LANDFORM(a6),a0	; landform copy + mt_state + index after it
	lea	-128(a0),a0
	lea	u2_ldbuf,a1
	move.w	#(128+28800)/4-1,d0
.c:	move.l	(a0)+,(a1)+
	dbf	d0,.c
	lea	mt_state,a0
	move.w	#MT_N-1,d0
.m:	move.l	(a0)+,(a1)+
	dbf	d0,.m
	move.w	mt_index,(a1)+
	move.l	mt_rs,(a1)+
	move.l	mt_old,(a1)+
	lea	u2_ldname,a0
	lea	u2_ldbuf,a1
	move.l	#128+28800+MT_N*4+10,d0
	bsr	fil_save
	movem.l	(sp)+,d0-d2/a0-a2
	rts
	section	data
u2_ldname:	dc.b	"C:",92,"LANDA.BIN",0
	even
	section	bss
u2_ldn:		ds.w	1
u2_ldbuf:	ds.b	128+28800+MT_N*4+16
	section	text
	endif

; The stars' cache (Phase 6g): readystar's three walks (16 s) depend only on the star's seed and
; mode, so the landform and the generator after them are kept for the last U2_SN stars.
U2_SN		equ	4
U2_SREC		equ	28800+MT_N*4+2+4+4	; landform, mt_state, mt_index, randseed, oldseed
; u2_sfind(key d0.l) -> a0 = the entry, Z clear if found  trashes d1
u2_sfind:
	lea	u2_skey,a0
	moveq	#0,d1
.f:	cmp.l	(a0)+,d0
	beq.s	.y
	addq.w	#1,d1
	cmp.w	#U2_SN,d1
	bne.s	.f
	moveq	#0,d1			; Z set: not found
	rts
.y:	mulu	#U2_SREC,d1
	lea	u2_sdata,a0
	add.l	d1,a0
	moveq	#1,d1			; Z clear
	rts
; u2_sload(a0 = entry): landform, generator; the countdown as after the 225000 steps
u2_sload:
	bsr	mt_own
	move.l	GS_LANDFORM(a6),a1
	move.w	#28800/4-1,d0
.l:	move.l	(a0)+,(a1)+
	dbf	d0,.l
	lea	mt_state,a1
	move.w	#MT_N-1,d0
.m:	move.l	(a0)+,(a1)+
	dbf	d0,.m
	move.w	(a0)+,mt_index
	move.l	(a0)+,mt_rs
	move.l	(a0)+,mt_old
	add.w	#200,u2_index
	bra	u2_count
; u2_sstore(key d0.l): the landform and generator into the next slot (round robin)
u2_sstore:
	bsr	mt_own
	move.w	u2_snext,d1
	lea	u2_skey,a0
	move.w	d1,d2
	add.w	d2,d2
	add.w	d2,d2
	move.l	d0,0(a0,d2.w)
	addq.w	#1,u2_snext
	cmp.w	#U2_SN,u2_snext
	bne.s	.s
	clr.w	u2_snext
.s:	mulu	#U2_SREC,d1
	lea	u2_sdata,a1
	add.l	d1,a1
	move.l	GS_LANDFORM(a6),a0
	move.w	#28800/4-1,d0
.l:	move.l	(a0)+,(a1)+
	dbf	d0,.l
	lea	mt_state,a0
	move.w	#MT_N-1,d0
.m:	move.l	(a0)+,(a1)+
	dbf	d0,.m
	move.w	mt_index,(a1)+
	move.l	mt_rs,(a1)+
	move.l	mt_old,(a1)+
	rts

u2_cclear:				; u2_cmap := 0
	lea	u2_cmap,a0
	move.w	#28800/4-1,d0
.c:	clr.l	(a0)+
	dbf	d0,.c
	rts

; u2_apply(dx d0, dy d1, c d2): landform[x,y] gets the visits of u2_cmap[x-dx, y-dy] (on the
; torus): c = 0: +7 per visit while below 240 (createplanet), else +1 while below c (createstar)
u2_apply:
	movem.l	d3-d7/a3-a5,-(sp)
	ext.l	d0			; dx, dy into 0..239 / 0..119
	divs	#240,d0
	swap	d0
	tst.w	d0
	bpl.s	.dx
	add.w	#240,d0
.dx:	ext.l	d1
	divs	#120,d1
	swap	d1
	tst.w	d1
	bpl.s	.dy
	add.w	#120,d1
.dy:	move.w	d1,d7			; dy
	move.w	d2,d4			; c
	move.l	GS_LANDFORM(a6),a3	; destination column 0
	lea	u2_need,a5
	moveq	#0,d6			; destination column
	move.w	d0,d5			; dx
.col:	move.w	d6,d0			; source column (x - dx) mod 240
	sub.w	d5,d0
	bpl.s	.sc
	add.w	#240,d0
.sc:	mulu	#LAND_W,d0
	lea	u2_cmap,a4
	add.l	d0,a4
	move.l	a3,a1			; rows dy..119 <- source rows 0..119-dy
	add.w	d7,a1
	move.l	a4,a0
	move.w	#LAND_W-1,d3
	sub.w	d7,d3
	bsr.s	.run
	tst.w	d7			; rows 0..dy-1 <- source rows 120-dy..119
	beq.s	.nc
	move.l	a3,a1
	lea	LAND_W(a4),a0
	sub.w	d7,a0
	move.w	d7,d3
	subq.w	#1,d3
	bsr.s	.run
.nc:	lea	LAND_W(a3),a3
	addq.w	#1,d6
	cmp.w	#240,d6
	bne.s	.col
	movem.l	(sp)+,d3-d7/a3-a5
	rts
; d3+1 cells: a0 = counts, a1 = landform
.run:	moveq	#0,d1
.b:	move.b	(a0)+,d0
	bne.s	.hit
	addq.l	#1,a1
	dbf	d3,.b
	rts
.hit:	move.b	(a1),d1
	tst.w	d4
	bne.s	.st
	move.b	0(a5,d1.w),d2		; steps below 240: min(visits, need)
	cmp.b	d2,d0
	bls.s	.k
	move.b	d2,d0
.k:	and.w	#$ff,d0
	move.w	d0,d2			; + 7 * k
	lsl.w	#3,d2
	sub.w	d0,d2
	add.b	d2,d1
	move.b	d1,(a1)+
	dbf	d3,.b
	rts
.st:	cmp.w	d4,d1			; +1 per visit while below c: min(c, v + n) when v < c
	bhs.s	.sn
	and.w	#$ff,d0
	add.w	d0,d1
	cmp.w	d4,d1
	bls.s	.sv
	move.w	d4,d1
.sv:	move.b	d1,(a1)
.sn:	addq.l	#1,a1
	dbf	d3,.b
	rts

; createplanet(xc d0, yc d1) - a3 = tempplan^[curplan]: 75000 steps of a random walk raising
; the land (+7 below 240), the countdown every 1125 steps; then the technology spots. The walk
; depends on the seed only: its visit map is kept with the generator after it, and a walk of
; the same seed (readyplanet's 2nd and 3rd calls, the planet seen again) applies the map shifted
; to its start and restores the generator.
createplanet:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,d6			; xc
	move.w	d1,d7			; yc
	moveq	#0,d0
	move.w	PLANET_SEED(a3),d0
	cmp.l	u2_wseed,d0
	beq	.replay
	moveq	#-1,d1
	move.l	d1,u2_wseed
	move.l	a3,-(sp)
	bsr	mt_seed			; randseed := seed
	bsr	u2_cclear
	move.w	d6,d0
	move.w	d7,d1
	bsr	u2_walkc
	lea	mt_state,a0		; keep the generator after the walk
	lea	u2_wstate,a1
	move.w	#MT_N/2-1,d0
.sv:	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbf	d0,.sv
	move.w	mt_index,u2_wsidx
	move.w	d6,u2_cx
	move.w	d7,u2_cy
	move.l	(sp)+,a3
	moveq	#0,d0
	move.w	PLANET_SEED(a3),d0
	move.l	d0,u2_wseed
	bra.s	.apply
.replay:				; the countdown as the 75000 steps would have run it
	moveq	#0,d0
	move.w	u2_i,d0
	add.l	#75000,d0
	divu	#1125,d0
	add.w	d0,u2_index
	swap	d0
	move.w	d0,u2_i
	bsr	u2_count
	bsr	mt_own
	lea	u2_wstate,a0		; the generator as after the walk
	lea	mt_state,a1
	move.w	#MT_N/2-1,d0
.rst:	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbf	d0,.rst
	move.w	u2_wsidx,mt_index
	moveq	#0,d0			; randseed and oldseed as the seeding left them: not seed
	move.w	PLANET_SEED(a3),d0
	not.l	d0
	move.l	d0,mt_rs
	move.l	d0,mt_old
.apply:	move.w	d6,d0			; the map from its walk's start to this one's
	sub.w	u2_cx,d0
	move.w	d7,d1
	sub.w	u2_cy,d1
	moveq	#0,d2
	bsr	u2_apply
	move.l	GS_LANDFORM(a6),a4
	lea	-LAND_W-1(a4),a4	; [x,y] = a4 + x*120 + y
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
	PMARK	22
	moveq	#0,d4			; the cache key: seed | mode << 16 (the walks depend on them only:
	move.b	PLANET_MODE(a3),d4	; the generator was seeded just above), bit 31 = fast stars
	swap	d4
	move.w	PLANET_SEED(a3),d4
	clr.b	u2_fast
	btst	#OPTB_STARS,GS_SHIP+SHIP_OPTIONS+OPT_PROBES-1(a6)
	beq.s	.key
	st	u2_fast
	move.l	d4,d0
	bsr	u2_fseed
	bset	#31,d4
.key:	move.l	d4,d0
	bsr	u2_sfind
	beq.s	.walk
	bsr	u2_sload		; a star seen before: its landform and generator, the countdown at 0
	bra.s	.walked
.walk:	moveq	#-1,d0			; (6m) u2_cmap is no longer the planet walk's: a planet seen
	move.l	d0,u2_wseed		; again must walk again (6g-6l replayed the star's map)
	bsr	u2_cclear		; (6m) the three createstar walks into one visit map, applied
	move.w	#200,d0			; once: from a uniform i, three times +1 per visit while below c
	moveq	#90,d1			; = min(i + all visits, c) (at most 95 a cell: no byte wraps)
	bsr	u2_swalk
	moveq	#30,d0
	moveq	#30,d1
	bsr	u2_swalk
	moveq	#120,d0
	moveq	#60,d1
	bsr	u2_swalk
	move.w	d3,d0
	bsr	u2_sapply
	move.l	d4,d0
	bsr	u2_sstore
.walked:
	clr.b	u2_fast
	PMARK	23
	ifd	LANDDUMP
	bsr	u2_landdump
	endif
	bsr	orc_dump		; loadscreen(current): an oracle dump point
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

; createstar(c, xc, yc) x 3 (utils2.pas): readystar's .walk - u2_swalk(x d0, y d1) = one walk's
; visits added to u2_cmap (u2_walkc, or u2_walkf for fast stars), then u2_sapply
u2_swalk:
	tst.b	u2_fast
	bne	u2_walkf
	bra	u2_walkc

; u2_sapply(c d0): landform (all c-6 = readystar's i) := min(i + visits, c) from u2_cmap
; trashes d0-d2/a0-a2
u2_sapply:
	lea	u2_stab,a2		; t[n] = min(i + n, c)
	move.w	d0,d2
	subq.w	#6,d0			; i
	moveq	#0,d1
.t:	move.b	d0,(a2)+
	cmp.w	d2,d0
	bhs.s	.tc
	addq.w	#1,d0
.tc:	addq.w	#1,d1
	cmp.w	#256,d1
	bne.s	.t
	lea	u2_stab,a2
	lea	u2_cmap,a0
	move.l	GS_LANDFORM(a6),a1
	move.w	#28800/8-1,d1
	moveq	#0,d0
.c:	rept	8
	move.b	(a0)+,d0
	move.b	0(a2,d0.w),(a1)+
	endr
	dbf	d1,.c
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
U2_RMAX		equ	128		; (6m) the longest sphere row (pixels; the largest radius gives < 120)
u2_sphere_rows:
	movem.l	d3-d7/a3-a5,-(sp)
	tst.b	u2_xok			; (Phase 6i) the pixel table of this radius and shading
	bne.s	.ok
	movem.l	d0-d1,-(sp)
	bsr	u2_sphx_build
	movem.l	(sp)+,d0-d1
.ok:	move.w	d0,d6			; i
	move.w	d1,u2_last
	lea	u2_sphx,a1		; skip to row d0 (pm, n, n x (index*120, alt*256), cnt[128])
	move.w	d0,d1
	subq.w	#6,d1
	bra.s	.sk
.skl:	move.w	2(a1),d2
	lsl.w	#2,d2
	add.w	#4+128,d2
	add.w	d2,a1
.sk:	dbf	d1,.skl
	move.w	GS_C(a6),d4		; j2 := index + c, wrapped at 240: pixels with index <= 240 - c
	move.w	#240,d5			; read column index + c - 1, the others index + c - 241
	sub.w	d4,d5
	move.w	d4,d3
	subq.w	#1,d3
	muls	#LAND_W,d3		; (c - 1) * 120 (c starts at 0)
	lea	u2_tab,a0
.row:	cmp.w	u2_last,d6
	bgt	.x
	move.w	d6,d0			; ii := 60*i div spherei
	mulu	#60,d0
	divu	GS_SPHEREI(a6),d0
	move.l	GS_LANDFORM(a6),a4	; a4 = landform^[1, ii] + (c - 1) * 120
	lea	-1(a4,d0.w),a4
	add.l	d3,a4
	move.w	d6,d0			; ofsy := i + offset (planet^ row, 1-based)
	add.w	GS_OFFSET(a6),d0
	subq.w	#1,d0
	mulu	#120,d0
	move.l	GS_PLANET(a6),a2
	add.l	d0,a2
	move.w	(a1)+,d0		; ofsx := pm[i] + offset: the first pixel is planet^[ofsy, ofsx+1]
	add.w	GS_OFFSET(a6),d0
	add.w	d0,a2
	move.w	(a1)+,d7		; n
	move.w	d7,d2
	lsl.w	#2,d2
	lea	0(a1,d2.w),a3		; the row's cnt[]
	move.w	d7,d1			; k: the pixels before the wrap
	cmp.w	#127,d5
	bhi.s	.k
	moveq	#0,d1
	move.b	0(a3,d5.w),d1
.k:	sub.w	d1,d7
	move.w	d1,d0			; (6m) the run unrolled: jump to its d1-th pixel from the end
	lsl.w	#2,d0			; (12 bytes a pixel)
	move.w	d0,d2
	add.w	d0,d0
	add.w	d2,d0
	lea	.p1e(pc),a5
	sub.w	d0,a5
	jmp	(a5)
	rept	U2_RMAX
	move.w	(a1)+,d0		; colour := u2_tab[alt][landform^[j2, ii]]
	move.w	(a1)+,d2
	move.b	0(a4,d0.w),d2
	move.b	0(a0,d2.w),(a2)+
	endr
.p1e:	tst.w	d7
	beq	.nr
	lea	-240*LAND_W(a4),a4	; the wrapped run
	move.w	d7,d0
	lsl.w	#2,d0
	move.w	d0,d2
	add.w	d0,d0
	add.w	d2,d0
	lea	.p2e(pc),a5
	sub.w	d0,a5
	jmp	(a5)
	rept	U2_RMAX
	move.w	(a1)+,d0
	move.w	(a1)+,d2
	move.b	0(a4,d0.w),d2
	move.b	0(a0,d2.w),(a2)+
	endr
.p2e:
.nr:	lea	128(a3),a1
	addq.w	#1,d6
	bra	.row
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; u2_sphx_build: u2_sphx from u2_sphw (the radius's rows), u2_altw and u2_first (the shading): per
; row pm, n, per pixel (index * 120, alt * 256 - the first pixel's alt from u2_first when that is
; set), then cnt[t] = the pixels with index <= t for t = 0..127 (index rises along a row)
u2_sphx_build:
	movem.l	d3-d5/a3,-(sp)
	lea	u2_sphw,a0
	lea	u2_sphx,a1
	lea	u2_altw,a3
	move.w	GS_MAXSPHEREI(a6),d5
	subq.w	#6,d5			; rows - 1
.r:	move.w	(a0)+,(a1)+		; pm
	move.w	(a0)+,d3		; n
	move.w	d3,(a1)+
	move.l	a0,a2
	move.w	d3,d4
	subq.w	#1,d4
	bmi.s	.cnt
	moveq	#1,d2			; the first pixel
.e:	move.w	(a0)+,d0		; index * 2
	move.w	d0,d1
	mulu	#LAND_W/2,d1
	move.w	d1,(a1)+
	move.w	0(a3,d0.w),d1
	tst.w	d2
	beq.s	.e1
	moveq	#0,d2
	tst.w	u2_first
	bmi.s	.e1
	move.w	u2_first,d1
.e1:	move.w	d1,(a1)+
	dbf	d4,.e
.cnt:	moveq	#0,d0			; t
	moveq	#0,d1			; p
.c:	cmp.w	d3,d1
	bhs.s	.cs
	move.w	d1,d2
	add.w	d2,d2
	move.w	0(a2,d2.w),d2
	lsr.w	#1,d2
	cmp.w	d0,d2
	bhi.s	.cs
	addq.w	#1,d1
	bra.s	.c
.cs:	move.b	d1,(a1)+
	addq.w	#1,d0
	cmp.w	#128,d0
	bne.s	.c
	dbf	d5,.r
	st	u2_xok
	sf	u2_sxok			; (the star's table shares u2_sphx)
	movem.l	(sp)+,d3-d5/a3
	rts

; u2_shade: the colour tables of the planet in orbit (after colorlookup, water, spcindex, ecl):
; u2_tab[a][v] for alt a = 0..31, land value v; u2_altw[index] = alt(index) * 256
; (journey.pas: ecl > 170: (index-ecl+186) div 2; else index = xw: 10, (ecl-index) div 2;
; at least 0; Pascal div truncates); u2_first = 10 * 256 when ecl > 170 (the first
; pixel of each row), else 0 (the column's own)
u2_shade:
	sf	u2_xok
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
	lea	u2_altw,a3		; per column index: its alt's row offset in u2_tab (alt * 256)
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
	move.w	d0,(a3)+
	addq.w	#1,d4
	cmp.w	#128,d4
	bne.s	.i
	move.w	#-1,u2_first
	cmp.w	#170,d5
	ble.s	.x
	move.w	#10*256,u2_first
.x:	movem.l	(sp)+,d3-d6/a3
	rts

; makesphere3: planet^ to the screen, c := c + 1 (wrapping at 240)
makesphere3:
	ifd	PROFILE
	bsr	tim_ms
	bsr	scr_dbg
	endif
	bsr	mousehide
	movem.l	d3-d6/a3,-(sp)
	moveq	#28,d0			; the shadow at (28, 13)
	moveq	#13,d1
	bsr	ms_addr
	move.l	GS_PLANET(a6),a1
	moveq	#13,d5			; y
	moveq	#120-1,d6
; per row only the span that differs from the shadow is copied and marked (Phase 6g: the flush
; then converts the turning surface, not the background corners or an unchanged night side)
.r:	move.l	a0,a2
	move.l	a1,a3
	moveq	#30-1,d0
.l:	cmpm.l	(a3)+,(a2)+		; the first differing long from the left
	dbne	d0,.l
	beq.s	.nx			; the row is unchanged
	moveq	#29,d3
	sub.w	d0,d3			; its index
	lea	120(a0),a2		; the last differing long from the right
	lea	120(a1),a3
	moveq	#30-1,d4
.rl:	move.l	-(a3),d1
	cmp.l	-(a2),d1
	dbne	d4,.rl
	movem.l	a0-a1,-(sp)		; copy longs d3..d4
	move.w	d3,d0
	lsl.w	#2,d0
	add.w	d0,a0
	add.w	d0,a1
	move.w	d4,d0
	sub.w	d3,d0
.cp:	move.l	(a1)+,(a0)+
	dbf	d0,.cp
	move.w	d3,d0			; ms_dirty(28 + 4*d3, y, 28 + 4*d4 + 3, y)
	lsl.w	#2,d0
	add.w	#28,d0
	move.w	d4,d2
	lsl.w	#2,d2
	add.w	#28+3,d2
	move.w	d5,d1
	move.w	d3,-(sp)
	move.w	d5,d3
	bsr	ms_dirtyx		; (the span did change: no need to compare it again)
	move.w	(sp)+,d3
	movem.l	(sp)+,a0-a1
.nx:	lea	MS_W(a0),a0
	lea	120(a1),a1
	addq.w	#1,d5
	dbf	d6,.r
	movem.l	(sp)+,d3-d6/a3
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
	tst.b	u2_sxok			; (Phase 6i) the star's pixel table: as the sphere's, but each
	bne.s	.ok			; pixel is landform^[j2, i] itself except the first and those
	bsr	u2_stx_build		; with index = xw (alt 6), fixed up after the row
.ok:	lea	u2_sphx,a1		; per row: pm, n, e, n x index*120, cnt[128]
	move.w	GS_C(a6),d4
	move.w	#240,d5
	sub.w	d4,d5			; pixels with index <= 240 - c do not wrap
	move.w	d4,d3
	subq.w	#1,d3
	muls	#LAND_W,d3		; (c - 1) * 120
	moveq	#6,d6			; i
.row:	move.w	GS_R2(a6),d0
	add.w	d0,d0
	addq.w	#4,d0
	cmp.w	d0,d6
	bgt	.x
	move.l	GS_LANDFORM(a6),a4	; landform^[1, i] + (c - 1) * 120
	lea	-1(a4,d6.w),a4
	add.l	d3,a4
	move.w	d6,d0			; planet^[i + offset, pm[i] + offset + 1]
	add.w	GS_OFFSET(a6),d0
	subq.w	#1,d0
	mulu	#120,d0
	move.l	GS_PLANET(a6),a2
	add.l	d0,a2
	move.w	(a1)+,d0
	add.w	GS_OFFSET(a6),d0
	add.w	d0,a2
	move.l	a2,a5			; the row's first pixel
	move.w	(a1)+,d7		; n
	move.w	(a1)+,d4		; e: the trailing pixels with index = xw
	move.l	a1,a3			; the entries
	move.w	d7,d2
	add.w	d2,d2
	lea	0(a1,d2.w),a0		; cnt[]
	move.w	d7,d1			; k: before the wrap
	cmp.w	#127,d5
	bhi.s	.k
	moveq	#0,d1
	move.b	0(a0,d5.w),d1
.k:	move.w	d7,d2
	sub.w	d1,d2			; after the wrap
	move.w	d1,-(sp)
	subq.w	#1,d1
	bmi.s	.w
.p1:	move.w	(a1)+,d0
	move.b	0(a4,d0.w),(a2)+
	dbf	d1,.p1
.w:	subq.w	#1,d2
	bmi.s	.f
	lea	-240*LAND_W(a4),a4
.p2:	move.w	(a1)+,d0
	move.b	0(a4,d0.w),(a2)+
	dbf	d2,.p2
	lea	240*LAND_W(a4),a4
.f:	move.w	(sp)+,d1		; the fix-ups (alt 6): the first pixel, the last e
	tst.w	d7
	beq.s	.nr
	moveq	#0,d0
	bsr.s	.fix
	move.w	d7,d0
	sub.w	d4,d0
	bne.s	.fl
	addq.w	#1,d0			; (the first is done)
.fl:	cmp.w	d7,d0
	bge.s	.nr
	bsr.s	.fix
	addq.w	#1,d0
	bra.s	.fl
.nr:	lea	128(a0),a1
	addq.w	#1,d6
	bra	.row
.x:	movem.l	(sp)+,d3-d7/a3-a5
	bra	makesphere3
; pixel d0.w of the row again with alt 6: v := landform^[j2, i]; if 6 > v mod 16 then v div 16
; else v - 6.  (d1 = the pixels before the wrap, a3 = the entries, a4 = the base, a5 = the row)
.fix:	move.w	d0,d2
	add.w	d2,d2
	move.w	0(a3,d2.w),d2
	move.l	a4,a2
	cmp.w	d1,d0
	blt.s	.fb
	lea	-240*LAND_W(a2),a2
.fb:	move.b	0(a2,d2.w),d2
	move.b	d2,-(sp)
	and.b	#15,d2
	cmp.b	#6,d2
	move.b	(sp)+,d2
	bhs.s	.fs
	lsr.b	#4,d2
	bra.s	.fp
.fs:	subq.b	#6,d2
.fp:	move.b	d2,0(a5,d0.w)
	rts

; u2_stx_build: makestar's pixel table in u2_sphx (shared with the sphere's: each build makes the
; other's stale): per row pm, n, e (the trailing pixels with index = xw), n x index*120, cnt[128]
u2_stx_build:
	movem.l	d3-d5,-(sp)
	lea	u2_sphw,a0
	lea	u2_sphx,a1
	move.w	GS_R2(a6),d5
	add.w	d5,d5
	subq.w	#2,d5			; rows - 1 (2*r2+4 - 6)
.r:	move.w	(a0)+,(a1)+		; pm
	move.w	(a0)+,d3		; n
	move.w	d3,(a1)+
	move.l	a0,a2
	moveq	#0,d4			; e
	move.w	GS_XW(a6),d1
	add.w	d1,d1
	move.w	d3,d0
.e:	subq.w	#1,d0
	bmi.s	.ee
	move.w	d0,d2
	add.w	d2,d2
	cmp.w	0(a2,d2.w),d1
	bne.s	.ee
	addq.w	#1,d4
	bra.s	.e
.ee:	move.w	d4,(a1)+
	move.w	d3,d4
	subq.w	#1,d4
	bmi.s	.cnt
.w:	move.w	(a0)+,d0		; index * 2 -> index * 120
	mulu	#LAND_W/2,d0
	move.w	d0,(a1)+
	dbf	d4,.w
.cnt:	moveq	#0,d0			; cnt[t] = the pixels with index <= t
	moveq	#0,d1
.c:	cmp.w	d3,d1
	bhs.s	.cs
	move.w	d1,d2
	add.w	d2,d2
	move.w	0(a2,d2.w),d2
	lsr.w	#1,d2
	cmp.w	d0,d2
	bhi.s	.cs
	addq.w	#1,d1
	bra.s	.c
.cs:	move.b	d1,(a1)+
	addq.w	#1,d0
	cmp.w	#128,d0
	bne.s	.c
	dbf	d5,.r
	st	u2_sxok
	sf	u2_xok
	movem.l	(sp)+,d3-d5
	rts

	section	data
u2_wseed:	dc.l	-1		; the seed of the walk in u2_cmap (-1: none)
u2_skey:	dcb.l	U2_SN,-1	; the stars' cache: keys (-1: empty)
u2_bhi:		dc.b	$88,$01,$20,$04,$09,$12,$04,$08,$81,$22,$44,$88,$11,$20,$44,$88
u2_blo:		dc.b	$00,$00,$01,$02,$00,$08,$00,$20,$00,$01,$02,$04,$08,$01,$22,$40
; (top byte of the tempered number of bit k alone, high word / low word; tools: see PLAN Phase 6g)
u2_need:				; steps of +7 until 240: ceil((240 - v) / 7), 0 from 240
	dc.b	35,35,34,34,34,34,34,34,34,33,33,33,33,33,33,33
	dc.b	32,32,32,32,32,32,32,31,31,31,31,31,31,31,30,30
	dc.b	30,30,30,30,30,29,29,29,29,29,29,29,28,28,28,28
	dc.b	28,28,28,27,27,27,27,27,27,27,26,26,26,26,26,26
	dc.b	26,25,25,25,25,25,25,25,24,24,24,24,24,24,24,23
	dc.b	23,23,23,23,23,23,22,22,22,22,22,22,22,21,21,21
	dc.b	21,21,21,21,20,20,20,20,20,20,20,19,19,19,19,19
	dc.b	19,19,18,18,18,18,18,18,18,17,17,17,17,17,17,17
	dc.b	16,16,16,16,16,16,16,15,15,15,15,15,15,15,14,14
	dc.b	14,14,14,14,14,13,13,13,13,13,13,13,12,12,12,12
	dc.b	12,12,12,11,11,11,11,11,11,11,10,10,10,10,10,10
	dc.b	10,9,9,9,9,9,9,9,8,8,8,8,8,8,8,7
	dc.b	7,7,7,7,7,7,6,6,6,6,6,6,6,5,5,5
	dc.b	5,5,5,5,4,4,4,4,4,4,4,3,3,3,3,3
	dc.b	3,3,2,2,2,2,2,2,2,1,1,1,1,1,1,1
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
u2_main:	dc.b	"MAIN",0
u2_dname:	dc.b	"DATA",92,"MAIN",0
u2_cloud:	dc.b	"CLOUD",0
u2_s_planet:	dc.b	21,"Approaching planet..."
u2_s_star:	dc.b	19,"Approaching star..."
u2_s_eta:	dc.b	19,"ETA T Minus     hrs"
u2_s_orbit:	dc.b	17,"Orbit achieved..."
	even

	section	bss
u2_cmap:	ds.b	28800		; visits per landform cell of the last walk(s)
u2_tha:		ds.b	65536		; top byte of the tempered number: high word's part
u2_tla:		ds.b	65536		; ... low word's part
u2_tok:		ds.b	1		; the tables are built
	even
u2_clx:		ds.w	256		; (6l) top byte -> x step * U2_PS (U2_TIE: a tie)
u2_cly:		ds.w	256		; ... -> y step
u2_pmap:	ds.b	242*U2_PS	; (6l) the walk's torus with its border (u2_walkc)
	even
u2_snext:	ds.w	1		; the stars' cache: the next slot to fill
u2_sdata:	ds.b	U2_SN*U2_SREC
u2_cx:		ds.w	1		; where u2_cmap's walk started
u2_cy:		ds.w	1
u2_dbl:		ds.b	640
	even
u2_wstate:	ds.l	MT_N		; the generator after the walk
u2_wsidx:	ds.w	1
	even
u2_left:	ds.l	1
u2_fbuf:	ds.l	55+U2_FNB	; (6m) fast stars: the generator's history + block
u2_fp:		ds.l	1		; the next byte
u2_fav:		ds.w	1		; bytes left in the block
u2_fdt:		ds.w	256		; byte -> the step's delta
u2_fast:	ds.b	1		; readystar's walks on the fast generator
u2_fdok:	ds.b	1
	even
u2_stab:	ds.b	256		; (6m) u2_sapply's min(i + n, c)
u2_sphere:	ds.l	1		; DATA\SPHERE.DAT
u2_sph:		ds.l	1		; the current radius's record
u2_index:	ds.w	1		; utils2's index (the countdown)
u2_i:		ds.w	1
u2_ii:		ds.w	1
u2_last:	ds.w	1
u2_num:		ds.b	12
	even
u2_rowp:	ds.l	1
u2_first:	ds.w	1		; alt 10's row offset for each row's first pixel, or -1: its own
u2_altw:	ds.w	128		; per column index: its alt's row offset in u2_tab (alt * 256)
u2_sphw:	ds.w	U2_SPHW		; the radius's rows as words: pm, n, n x index * 2 (sphere_setup)
u2_sphx:	ds.b	4*U2_SPHW+132*128	; u2_sphere_rows' pixel table (u2_sphx_build)
u2_dpath:	ds.b	20		; u2_design's file name
u2_dsbuf:	ds.b	4		; u2_dsuffix's suffix
u2_xok:		ds.b	1		; u2_sphx holds the sphere's table, up to date
u2_sxok:	ds.b	1		; u2_sphx holds makestar's table, up to date
	even
u2_tab:		ds.b	32*256		; [alt 0-31][land value] -> colour

	section	text
; ---------------------------------------------------------------- what a planet's bots find
; utils2.pas getstuffamounts(state d0): u2_ele[0..16], u2_mat[0..20], u2_cmp[0..22] (words)
getstuffamounts:
	movem.l	d3-d7/a3-a4,-(sp)
	move.w	d0,d7
	tst.l	u2_scan			; scan.dta: 17 elements x 12 states (bytes), read once
	bne.s	.h
	move.l	#17*12,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,u2_scan
	move.l	a0,a1
	lea	u2_fn_scan,a0
	move.l	#17*12,d0
	bsr	load_exact
.h:	move.l	u2_scan,a0		; ele[i] := temp^[i, state]
	lea	u2_ele,a1
	moveq	#0,d1
.e:	moveq	#0,d0
	move.b	0(a0,d7.w),d0
	move.w	d0,(a1)+
	lea	12(a0),a0
	addq.w	#1,d1
	cmp.w	#17,d1
	bne.s	.e
	moveq	#1,d3			; materials 1..19
.m:	lea	u2_mat,a4
	move.w	d3,d0
	add.w	d0,d0
	clr.w	0(a4,d0.w)
	move.w	d3,d4
	add.w	#ID_UNKNOWN_MATERIAL,d4	; n
	lea	GS_CARGO+CARGO_INDEX(a6),a3
	moveq	#1,d5			; j
.mj:	cmp.w	(a3),d4
	beq.s	.mf
	lea	CARGO_SIZEOF(a3),a3
	addq.w	#1,d5
	cmp.w	#MAXCARGO,d5
	ble.s	.mj
	bra.s	.mn
.mf:	move.w	d5,d0			; tt := 99; tly := 0: over the 3 parts (elements)
	subq.w	#1,d0
	mulu	#6,d0
	lea	GS_PRTCARGO(a6),a0
	add.w	d0,a0
	moveq	#99,d1			; tt
	moveq	#0,d2			; tly
	moveq	#3-1,d6
.mk:	move.w	(a0)+,d0
	sub.w	#ID_FIRST_ELEMENT,d0
	ext.l	d0
	divs	#10,d0
	add.w	d0,d0
	lea	u2_ele,a1
	move.w	0(a1,d0.w),d0
	add.w	d0,d2
	cmp.w	d1,d0
	bge.s	.mk2
	move.w	d0,d1
.mk2:	dbf	d6,.mk
	tst.w	d1
	ble.s	.mn
	move.w	d3,d0
	add.w	d0,d0
	move.w	d2,0(a4,d0.w)
.mn:	addq.w	#1,d3
	cmp.w	#20,d3
	bne.s	.m
	clr.w	u2_mat
	clr.w	u2_mat+40
	moveq	#1,d3			; components 1..20
.c:	move.w	d3,d0
	add.w	#ID_UNKNOWN_COMPONENT,d0
	bsr	u2_getsub
	move.w	d3,d1
	add.w	d1,d1
	lea	u2_cmp,a0
	move.w	d0,0(a0,d1.w)
	addq.w	#1,d3
	cmp.w	#21,d3
	bne.s	.c
	clr.w	u2_cmp
	clr.w	u2_cmp+42
	clr.w	u2_cmp+44
	movem.l	(sp)+,d3-d7/a3-a4
	rts
; getsubamount(item d0): min over its parts of the amounts (0 if not a cargo item)
u2_getsub:
	movem.l	d3-d5/a3,-(sp)
	lea	GS_CARGO+CARGO_INDEX(a6),a3
	moveq	#1,d1
.f:	cmp.w	(a3),d0
	beq.s	.ff
	lea	CARGO_SIZEOF(a3),a3
	addq.w	#1,d1
	cmp.w	#MAXCARGO,d1
	ble.s	.f
	moveq	#0,d0
	bra.s	.x
.ff:	subq.w	#1,d1
	mulu	#6,d1
	lea	GS_PRTCARGO(a6),a3
	add.w	d1,a3
	moveq	#99,d4			; tt
	moveq	#3-1,d5
.p:	move.w	(a3)+,d0		; n
	cmp.w	#ID_FIRST_ELEMENT,d0
	blt.s	.pm
	cmp.w	#ID_LAST_ELEMENT,d0
	bgt.s	.pc
	sub.w	#ID_FIRST_ELEMENT,d0
	ext.l	d0
	divs	#10,d0
	add.w	d0,d0
	lea	u2_ele,a0
	move.w	0(a0,d0.w),d0
	bra.s	.pc
.pm:	cmp.w	#ID_UNKNOWN_MATERIAL,d0
	blt.s	.pk
	sub.w	#ID_UNKNOWN_MATERIAL,d0
	add.w	d0,d0
	lea	u2_mat,a0
	move.w	0(a0,d0.w),d0
	bra.s	.pc
.pk:	cmp.w	#ID_UNKNOWN_COMPONENT,d0
	blt.s	.pc
	bsr	u2_getsub
.pc:	cmp.w	d4,d0
	bge.s	.pn
	move.w	d0,d4
.pn:	dbf	d5,.p
	move.w	d4,d0
.x:	movem.l	(sp)+,d3-d5/a3
	rts

; utils2.pas addstuff(n d0, limit d1): the bots of planet n fill its cache
addstuff:
	movem.l	d3-d7/a3-a4,-(sp)
	move.w	d1,d7			; lim
	bsr	u2_plan
	move.l	a0,a3
	moveq	#7,d6
	and.b	PLANET_BOTS(a3),d6
	beq	.x
	moveq	#0,d0
	move.b	PLANET_STATE(a3),d0
	bsr	getstuffamounts
	moveq	#0,d5			; total
	cmp.w	#1,d6
	bne	.mat
	lea	u2_ele,a0		; elements
	moveq	#17-1,d0
.te:	add.w	(a0)+,d5
	dbf	d0,.te
	lea	PLANET_CACHE(a3),a4
	moveq	#7-1,d4
.ce:	tst.w	(a4)
	bne.s	.cen
	move.w	d5,d0			; r := random(total)
	bsr	mt_random
	moveq	#0,d1			; j
	lea	u2_ele,a0
.w:	cmp.w	#16,d1
	bge.s	.wd
	cmp.w	(a0),d0
	blt.s	.wd
	sub.w	(a0)+,d0
	addq.w	#1,d1
	bra.s	.w
.wd:	mulu	#10,d1
	add.w	#ID_FIRST_ELEMENT,d1
	move.w	d1,(a4)
	subq.w	#1,d7
	ble	.x
.cen:	addq.l	#2,a4
	dbf	d4,.ce
	bra	.x
.mat:	cmp.w	#2,d6
	beq.s	.m
	cmp.w	#5,d6
	bne.s	.cmp
.m:	lea	u2_mat,a0		; materials: doubled; unknown + junk get one more
	moveq	#21-1,d0
.tm:	move.w	(a0),d1
	add.w	d1,d1
	move.w	d1,(a0)+
	add.w	d1,d5
	dbf	d0,.tm
	addq.w	#1,u2_mat
	addq.w	#1,u2_mat+40
	addq.w	#2,d5
	lea	u2_mat,a1
	moveq	#20,d3			; the last j
	move.w	#ID_UNKNOWN_MATERIAL,d2
	bra.s	.fill
.cmp:	cmp.w	#3,d6
	blt	.x
	cmp.w	#4,d6
	bgt	.x
	lea	u2_cmp,a0		; components
	moveq	#23-1,d0
.tc:	move.w	(a0),d1
	add.w	d1,d1
	move.w	d1,(a0)+
	add.w	d1,d5
	dbf	d0,.tc
	addq.w	#1,u2_cmp
	addq.w	#1,u2_cmp+44
	addq.w	#2,d5
	lea	u2_cmp,a1
	moveq	#22,d3
	move.w	#ID_UNKNOWN_COMPONENT,d2
.fill:	lea	PLANET_CACHE(a3),a4	; for i := 1 to 7: an empty slot, or junk half the time
	moveq	#7-1,d4
.cf:	tst.w	(a4)
	beq.s	.cg
	cmp.w	#ID_WORTHLESS_JUNK,(a4)
	bne.s	.cfn
	movem.l	d2/a1,-(sp)
	moveq	#2,d0
	bsr	mt_random
	movem.l	(sp)+,d2/a1
	tst.w	d0
	bne.s	.cfn
.cg:	movem.l	d2/a1,-(sp)
	move.w	d5,d0
	bsr	mt_random
	movem.l	(sp)+,d2/a1
	moveq	#0,d1			; j
	move.l	a1,a0
.cw:	cmp.w	d3,d1
	bge.s	.cwd
	cmp.w	(a0),d0
	blt.s	.cwd
	sub.w	(a0)+,d0
	addq.w	#1,d1
	bra.s	.cw
.cwd:	cmp.w	#22,d1			; components: j = 22 is worthless junk
	bne.s	.cid
	cmp.w	#ID_UNKNOWN_COMPONENT,d2
	bne.s	.cid
	move.w	#ID_WORTHLESS_JUNK,(a4)
	bra.s	.cl
.cid:	add.w	d2,d1
	move.w	d1,(a4)
.cl:	subq.w	#1,d7
	ble.s	.x
.cfn:	addq.l	#2,a4
	dbf	d4,.cf
.x:	movem.l	(sp)+,d3-d7/a3-a4
	rts
u2_plan:				; a0 := @tempplan^[d0]
	mulu	#PLANET_SIZEOF,d0
	move.l	GS_TEMPPLAN(a6),a0
	lea	-PLANET_SIZEOF(a0),a0
	add.l	d0,a0
	rts

	section	data
u2_fn_scan:	dc.b	"DATA",92,"SCAN.DTA",0
	even
	section	bss
u2_scan:	ds.l	1
u2_ele:		ds.w	17
u2_mat:		ds.w	21
u2_cmp:		ds.w	23

	section	text
; ---------------------------------------------------------------- travel (utils2.pas)
; redoscreen(x d0, y d1, z d2): the journey to (x, y, z): position (maybe off course), the
; systems now near, the countdown screen, time passing, arrival at a star or in deep space,
; the autosave, travel damage, the events of the system
redoscreen:
	movem.l	d3-d7/a3,-(sp)
	movem.w	d0-d2,u2_xyz
	sub.w	GS_SHIP+SHIP_POSX(a6),d0	; dist (SSE)
	sub.w	GS_SHIP+SHIP_POSY(a6),d1
	sub.w	GS_SHIP+SHIP_POSZ(a6),d2
	bsr	dp_dist
	lea	u2_dist,a0
	bsr	fp_std
	moveq	#85,d0			; off course: (random(85)+15) < damages[ENGINES]
	bsr	mt_random
	add.w	#15,d0
	moveq	#0,d1
	move.b	GS_SHIP+SHIP_DAMAGES+DMG_ENGINES-1(a6),d1
	cmp.w	d1,d0
	bge.s	.on
	TCOL	94
	PRTLN
	PRT	"NAVIGATION: Ship off course!"
	lea	u2_xyz,a3
	lea	GS_SHIP+SHIP_POSX(a6),a0
	moveq	#3-1,d3
.oc:	move.l	a0,-(sp)
	moveq	#7,d0
	bsr	mt_random
	move.l	(sp)+,a0
	add.w	(a3)+,d0
	subq.w	#3,d0
	move.w	d0,(a0)+
	dbf	d3,.oc
	bra.s	.pos
.on:	movem.w	u2_xyz,d0-d2
	movem.w	d0-d2,GS_SHIP+SHIP_POSX(a6)
.pos:	sf	GS_TARGETREADY(a6)
	move.w	#32000,GS_SHIP+SHIP_BATTERY(a6)
	bsr	checkstats
	sf	GS_SHOWPLANET(a6)
	lea	GS_NEARBY(a6),a0	; the systems within 400
	moveq	#NEARBYMAX-1,d0
.cl:	clr.w	NEARBY_INDEX(a0)
	lea	NEARBY_SIZEOF(a0),a0
	dbf	d0,.cl
	moveq	#0,d6			; i
	lea	GS_SYSTEMS(a6),a3
	moveq	#1,d7			; j
.s:	move.w	SYSTEM_X(a3),d3
	sub.w	GS_SHIP+SHIP_POSX(a6),d3
	move.w	SYSTEM_Y(a3),d4
	sub.w	GS_SHIP+SHIP_POSY(a6),d4
	move.w	SYSTEM_Z(a3),d5
	sub.w	GS_SHIP+SHIP_POSZ(a6),d5
	move.w	d3,GS_X(a6)
	move.w	d4,GS_Y(a6)
	move.w	d5,GS_Z(a6)
	move.w	d3,d0
	bsr	.abs
	cmp.w	#400,d0
	bge.s	.n
	move.w	d4,d0
	bsr	.abs
	cmp.w	#400,d0
	bge.s	.n
	move.w	d5,d0
	bsr	.abs
	cmp.w	#400,d0
	bge.s	.n
	addq.w	#1,d6
	cmp.w	#NEARBYMAX,d6
	bgt	fatal			; NEARBY STRUCTURE OVERFLOW #1
	move.w	d6,d0
	bsr	dp_near
	move.w	d7,NEARBY_INDEX(a0)
	move.l	a0,-(sp)
	move.w	d3,d0			; x/10, y/10, z/10 (SSE)
	lea	NEARBY_X(a0),a0
	bsr	u2_div10
	move.l	(sp),a0
	move.w	d4,d0
	lea	NEARBY_Y(a0),a0
	bsr	u2_div10
	move.l	(sp)+,a0
	move.w	d5,d0
	lea	NEARBY_Z(a0),a0
	bsr	u2_div10
	bset	#0,SYSTEM_NOTES(a3)
.n:	lea	SYSTEM_SIZEOF(a3),a3
	addq.w	#1,d7
	cmp.w	#250,d7
	ble	.s
	lea	GS_NEARBY(a6),a0	; nearbybackup := nearby
	lea	GS_NEARBYBACKUP(a6),a1
	move.w	#NEARBYARRAY_SIZEOF/2-1,d0
.bk:	move.w	(a0)+,(a1)+
	dbf	d0,.bk
	bsr	mousehide
	moveq	#0,d0			; compressfile(current); a black screen
	bsr	ms_snap
	BAR	0,0,319,199,0
	TCOL	47
	BKCOL	0
	lea	u2_dist,a0		; time := round(dist*2)+1
	bsr	fp_ldd
	FLDI	2
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,d4			; the last j
	move.w	d0,d3
	addq.w	#1,d3			; time
	PXY	42,187,"Acceleration to near light speed..."
	bsr	mouseshow
	moveq	#0,d7			; for j := 0 to round(dist*2)
.t:	cmp.w	d4,d7
	bgt.s	.te
	move.w	#4000,d0
	bsr	mt_random
	add.w	#4000,d0
	move.w	d0,d2
	sf	d0
	sf	d1
	bsr	addlotstime
	subq.w	#1,d3
	move.w	d3,d0			; str(time) padded with chr(20) to 4 characters
	ext.l	d0
	moveq	#0,d1
	lea	u2_num,a0
	bsr	int_str
	lea	u2_num,a0
	moveq	#0,d0
	move.b	(a0),d0
.pad:	cmp.w	#4,d0
	bge.s	.pd
	addq.w	#1,d0
	move.b	#20,0(a0,d0.w)
	bra.s	.pad
.pd:	move.b	#4,(a0)
	BKCOL	0
	PXYS	222,187,u2_num
	addq.w	#1,d7
	bra.s	.t
.te:	BKCOL	3
	TCOL	31
	moveq	#-8,d0			; fadestopmod(-FADEFULL_STEP, FADEFULL_DELAY)
	moveq	#20,d1
	bsr	fadestopmod
	bsr	mousehide
	bsr	orc_dump		; loadscreen(current): an oracle dump point
	moveq	#0,d0			; loadscreen(current)
	bsr	ms_unsnap
	bsr	showtime
	bsr	jy_findhere		; index: the system at the ship's position
	move.w	d0,u2_idx
	beq.s	.deep
	lea	u2_dist,a0		; stardate[3] += round(dist)
	bsr	fp_ldd
	bsr	fp_rnd
	add.w	d0,GS_SHIP+SHIP_STARDATE+4(a6)
	move.w	u2_idx,d0
	bsr	dp_near
	move.w	NEARBY_INDEX(a0),d0
	bsr	findfirstplanet
	move.w	d0,u2_j
	clr.w	GS_SHIP+SHIP_ORBITING(a6)
	move.w	d0,GS_CURPLAN(a6)
	bsr	showtime
	bsr	adjustsystem
	lea	u2_dist,a0
	bsr	fp_ldd
	bsr	fp_rnd
	bsr	adjustplanets
	bsr	readystar
	bra.s	.ms
.deep:	clr.w	GS_CURPLAN(a6)
	clr.w	GS_SHIP+SHIP_ORBITING(a6)
	bsr	reloadbackground
	bsr	fadein
.ms:	bsr	mouseshow
	cmp.b	#1,GS_SHIP+SHIP_OPTIONS+OPT_AUTOSAVE-1(a6)
	bne.s	.na
	moveq	#0,d0
	moveq	#31,d1
	bsr	savegamedata
.na:	clr.w	GS_TARGET(a6)
	moveq	#4,d0			; for j := 1 to random(4)+1: travel damage
	bsr	mt_random
	move.w	d0,d3
.dm:	moveq	#7,d0
	bsr	mt_random
	lea	GS_SHIP+SHIP_DAMAGES(a6),a0
	cmp.b	#90,0(a0,d0.w)
	bhs.s	.dn
	addq.b	#1,0(a0,d0.w)
.dn:	dbf	d3,.dm
	move.w	u2_idx,d0		; the system's events
	beq.s	.x
	bsr	dp_near
	move.w	NEARBY_INDEX(a0),d3
	lea	jy_eventsystems,a3
.ev:	move.w	(a3)+,d0
	bmi.s	.x
	move.w	(a3)+,d1
	cmp.w	d0,d3
	bne.s	.ev
	move.w	d1,d0
	bsr	event
	bra.s	.ev
.x:	movem.l	(sp)+,d3-d7/a3
	rts
.abs:	tst.w	d0
	bpl.s	.a
	neg.w	d0
.a:	rts
; (a0) := d0.w / 10 (SSE)
u2_div10:
	move.l	a0,-(sp)
	FSSE
	bsr	fp_ldw
	FLDI	10
	bsr	fp_div
	move.l	(sp)+,a0
	bra	fp_std

; utils2.pas adjustsystem (j = the star: u2_j)
adjustsystem:
	movem.l	d3/a3,-(sp)
	move.w	GS_CURPLAN(a6),d0
	bsr	u2_plan
	moveq	#0,d3
	move.b	PLANET_SYSTEM(a0),d3
	move.w	d3,d0
	bsr	dp_sys
	move.l	a0,a3
	tst.w	SYSTEM_VISITS(a3)
	bne.s	.v
	move.w	d3,d0
	bsr	getname
.v:	addq.w	#1,SYSTEM_VISITS(a3)
	move.w	GS_SHIP+SHIP_STARDATE+4(a6),SYSTEM_DATEY(a3)
	move.b	GS_SHIP+SHIP_STARDATE+1(a6),SYSTEM_DATEM(a3)
	move.w	u2_j,d0
	bsr	u2_plan
	cmp.w	#255,SYSTEM_VISITS(a3)
	bhs.s	.n
	addq.w	#1,PLANET_VISITS(a0)
.n:	move.w	GS_SHIP+SHIP_STARDATE+4(a6),PLANET_DATEY(a0)
	move.b	GS_SHIP+SHIP_STARDATE+1(a6),PLANET_DATEM(a0)
	movem.l	(sp)+,d3/a3
	rts

; utils2.pas getname(n d0): systems[n].name := sysname.dta record n-1 (string[12])
getname:
	movem.l	d3,-(sp)
	move.w	d0,d3
	tst.l	u2_names
	bne.s	.h
	move.l	#250*13,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,u2_names
	move.l	a0,a1
	lea	u2_fn_sysname,a0
	move.l	#250*13,d0
	bsr	load_exact
.h:	move.l	u2_names,a1
	move.w	d3,d0
	subq.w	#1,d0
	mulu	#13,d0
	add.l	d0,a1
	move.w	d3,d0
	bsr	dp_sys
	moveq	#13-1,d0
.c:	move.b	(a1)+,(a0)+
	dbf	d0,.c
	movem.l	(sp)+,d3
	rts

; utils2.pas adjustplanets(t d0): randomize; the bots' cache; the planets age and evolve
adjustplanets:
	movem.l	d3-d7/a3,-(sp)
	move.w	d0,d7
	ext.l	d7
	bsr	mt_randomize
	moveq	#1,d3			; j
	move.l	GS_TEMPPLAN(a6),a3
.j:	tst.b	PLANET_BOTS(a3)
	beq.s	.age
	and.b	#7,PLANET_BOTS(a3)	; clear the depletion; bots: addstuff(j, 7)
	beq.s	.age
	move.w	d3,d0
	moveq	#7,d1
	bsr	addstuff
.age:	add.l	d7,PLANET_AGE(a3)
	moveq	#0,d4
	move.b	PLANET_STATE(a3),d4	; olds
	move.b	PLANET_MODE(a3),d5
	move.l	PLANET_AGE(a3),d6
	lea	u2_evol,a0		; (state, mode, age limit, new mode, new state) rows
.e:	move.w	(a0)+,d0
	bmi.s	.rnd
	move.w	(a0)+,d1
	move.l	(a0)+,d2
	cmp.b	d0,d4
	bne.s	.en
	cmp.b	d1,d5
	bne.s	.en
	cmp.l	d2,d6
	blt.s	.en
	clr.l	PLANET_AGE(a3)
	move.b	1(a0),PLANET_MODE(a3)
	move.b	3(a0),PLANET_STATE(a3)
	bra.s	.rnd
.en:	addq.l	#4,a0
	bra.s	.e
.rnd:	bsr	u2_evolrnd		; the chances (random(40) = 0), in the original's order
	cmp.b	PLANET_STATE(a3),d4
	beq.s	.n
	lea	PLANET_CACHE(a3),a0	; a new state: cache, bots, notes cleared
	moveq	#7-1,d0
.cc:	clr.w	(a0)+
	dbf	d0,.cc
	clr.b	PLANET_BOTS(a3)
	clr.b	PLANET_NOTES(a3)
.n:	lea	PLANET_SIZEOF(a3),a3
	addq.w	#1,d3
	cmp.w	#1000,d3
	ble	.j
	movem.l	(sp)+,d3-d7/a3
	rts
; the random turns of adjustplanets for planet a3 (state/mode as before the age step: d4, d5;
; the age step may already have changed them - the original tests its own case only)
u2_evolrnd:
	cmp.b	#2,d4			; state 2 mode 3: 1 in 40 -> state 5 mode 2
	bne.s	.s3
	cmp.b	#3,d5
	bne	.x
	bra.s	.dying
.s3:	cmp.b	#3,d4			; state 3 mode 1: the same
	bne.s	.s4
	cmp.b	#1,d5
	bne.s	.x
.dying:	moveq	#40,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.x
	clr.l	PLANET_AGE(a3)
	move.b	#5,PLANET_STATE(a3)
	move.b	#2,PLANET_MODE(a3)
	rts
.s4:	cmp.b	#4,d4			; state 4 modes 2, 3: 1 in 40 -> dead (mode 1 or 2)
	bne.s	.s5
	cmp.b	#2,d5
	blo.s	.x
	moveq	#40,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.x
	moveq	#2,d0
	bsr	mt_random
	moveq	#1,d1
	tst.w	d0
	beq.s	.m
	moveq	#2,d1
.m:	move.b	d1,PLANET_MODE(a3)
	move.b	#6,PLANET_STATE(a3)
	clr.l	PLANET_AGE(a3)
	rts
.s5:	cmp.b	#5,d4			; state 5 mode 2: 1 in 40 -> state 2 mode 3
	bne.s	.x
	cmp.b	#2,d5
	bne.s	.x
	moveq	#40,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.x
	clr.l	PLANET_AGE(a3)
	move.b	#2,PLANET_STATE(a3)
	move.b	#3,PLANET_MODE(a3)
.x:	rts

; utils2.pas getplanetorbit(planet d0): its rank among the system's orbits
getplanetorbit:
	movem.l	d3-d4,-(sp)
	move.w	d0,d3
	bsr	u2_orbits
	moveq	#0,d1			; j
	lea	u2_orb,a0
	moveq	#8-1,d2
.l:	move.w	(a0)+,d0
	cmp.w	d3,d0
	beq.s	.x
	tst.w	d0
	ble.s	.n
	addq.w	#1,d1
.n:	dbf	d2,.l
.x:	move.w	d1,d0
	movem.l	(sp)+,d3-d4
	rts
; orbits[0..7] (u2_orb) of the system of planet d0 (or of system d1 when d0 < 0)
u2_orbits:
	lea	u2_orb,a0
	moveq	#8-1,d1
.c:	clr.w	(a0)+
	dbf	d1,.c
	bsr	u2_plan
	moveq	#0,d0
	move.b	PLANET_SYSTEM(a0),d0
u2_orbits_sys:
	movem.l	d3-d4,-(sp)
	move.w	d0,d4			; sys
	bsr	findfirstplanet
	move.w	d0,d3			; i
.l:	cmp.w	#1000,d3
	bgt.s	.x
	move.w	d3,d0
	bsr	u2_plan
	cmp.b	PLANET_SYSTEM(a0),d4
	bne.s	.x
	moveq	#0,d0
	move.b	PLANET_ORBIT(a0),d0
	add.w	d0,d0
	lea	u2_orb,a0
	move.w	d3,0(a0,d0.w)
	addq.w	#1,d3
	bra.s	.l
.x:	movem.l	(sp)+,d3-d4
	rts
; utils2.pas getplanetbyorbit(sys d0, orbit d1): out d0.w = the planet in that rank (0: none)
getplanetbyorbit:
	movem.l	d3,-(sp)
	move.w	d1,d3
	bmi.s	.z
	lea	u2_orb,a0
	moveq	#8-1,d1
.c:	clr.w	(a0)+
	dbf	d1,.c
	bsr	u2_orbits_sys
	lea	u2_orb,a0
	moveq	#8-1,d2
.l:	move.w	(a0)+,d0
	ble.s	.n
	tst.w	d3
	ble.s	.x
	subq.w	#1,d3
.n:	dbf	d2,.l
.z:	moveq	#0,d0
.x:	movem.l	(sp)+,d3
	rts

; utils2.pas planettravel(-1, index d0): to the planet tempplan index
planettravel:
	movem.l	d3-d5,-(sp)
	move.w	d0,d3			; index
	bsr	u2_plan
	move.b	PLANET_SYSTEM(a0),d4	; sy
	move.w	d3,d5			; j := index; while (j > 0) and (system = sy) do dec(j); inc(j)
.l:	tst.w	d5
	ble.s	.f
	move.w	d5,d0
	bsr	u2_plan
	cmp.b	PLANET_SYSTEM(a0),d4
	bne.s	.f
	subq.w	#1,d5
	bra.s	.l
.f:	addq.w	#1,d5
	sub.w	d5,d3			; index := index - j (the orbit's rank); j := j + index
	add.w	d3,d5
	move.w	d5,d0			; port: already in orbit there -> Science says so, no travel
	bsr	u2_here
	bne	.here
	tst.w	GS_VIEWMODE2(a6)
	ble.s	.nm
	bsr	removestarmap
.nm:	st	d0
	bsr	cleanright
	move.w	d5,GS_CURPLAN(a6)
	move.w	d5,d0
	bsr	u2_plan
	cmp.w	#255,PLANET_VISITS(a0)
	bhs.s	.v
	addq.w	#1,PLANET_VISITS(a0)
.v:	move.w	GS_SHIP+SHIP_STARDATE+4(a6),PLANET_DATEY(a0)
	move.b	GS_SHIP+SHIP_STARDATE+1(a6),PLANET_DATEM(a0)
	move.w	d3,GS_SHIP+SHIP_ORBITING(a6)
	bsr	mousehide
	moveq	#0,d0
	bsr	ms_snap
	BAR	0,0,319,199,0
	bsr	mouseshow
	moveq	#40,d0			; for j := 1 to random(40)+60 do addlotstime(false, true, 100+random(100))
	bsr	mt_random
	add.w	#60,d0
	move.w	d0,d4
.t:	moveq	#100,d0
	bsr	mt_random
	add.w	#100,d0
	move.w	d0,d2
	sf	d0
	st	d1
	bsr	addlotstime
	subq.w	#1,d4
	bne.s	.t
	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	bsr	mousehide
	bsr	orc_dump		; loadscreen(current): an oracle dump point
	moveq	#0,d0
	bsr	ms_unsnap
	bsr	mouseshow
	tst.w	d3
	beq.s	.st
	bsr	readyplanet
	bra.s	.cw
.st:	bsr	readystar
.cw:	bsr	checkwandering
.here:	movem.l	(sp)+,d3-d5
	rts

; port only (Phase 6l, David's request): travel to the planet or star the ship already orbits.
; The original travels again (a time burst and a fresh arrival); the port stops and Science says
; so. in: d0.w = tempplan index j of the destination  out: d0.w = 1 (flags ne) when the ship is
; already there (message printed in the caller's bkcolor), 0 (eq) otherwise
; trashes: d1-d2/a0-a2
u2_here:
	tst.b	GS_SHOWPLANET(a6)
	beq.s	.no
	cmp.w	GS_CURPLAN(a6),d0
	bne.s	.no
	TCOL	94
	PRTLN
	tst.w	GS_SHIP+SHIP_ORBITING(a6)
	beq.s	.star
	PRT	"SCIENCE: We are already in orbit of this planet, my Liege."
	bra.s	.yes
.star:	PRT	"SCIENCE: We are already in orbit of this star, my Liege."
.yes:	moveq	#1,d0
	rts
.no:	moveq	#0,d0
	rts

; utils2.pas gotoorbit(sys d0, n d1)
gotoorbit:
	bsr	getplanetbyorbit
	tst.w	d0
	bne	planettravel
	PRTLN
	TCOL	94
	PRT	"NAVIGATION: There's no orbit to go to."
	rts

	section	data
u2_fn_sysname:	dc.b	"DATA",92,"SYSNAME.DTA",0
	even
; adjustplanets' age steps: state, mode, age limit, new mode, new state (in the original's case
; order; at most one applies)
u2_evol:	dc.w	0,1
		dc.l	1000000000
		dc.w	2,0
		dc.w	0,2
		dc.l	1000000000
		dc.w	3,0
		dc.w	0,3
		dc.l	500000000
		dc.w	1,1
		dc.w	1,1
		dc.l	500000000
		dc.w	2,1
		dc.w	1,2
		dc.l	400000000
		dc.w	3,1
		dc.w	1,3
		dc.l	300000000
		dc.w	1,2
		dc.w	2,1
		dc.l	200000000
		dc.w	2,2
		dc.w	2,2
		dc.l	150000000
		dc.w	3,2
		dc.w	2,3
		dc.l	150000000
		dc.w	1,3
		dc.w	3,1
		dc.l	15000000
		dc.w	2,3
		dc.w	3,2
		dc.l	10000
		dc.w	3,3
		dc.w	3,3
		dc.l	8000
		dc.w	1,4
		dc.w	4,1
		dc.l	4000
		dc.w	2,4
		dc.w	4,2
		dc.l	2000
		dc.w	3,4
		dc.w	4,3
		dc.l	4000
		dc.w	1,5
		dc.w	5,1
		dc.l	3000
		dc.w	2,5
		dc.w	5,2
		dc.l	8000
		dc.w	3,5
		dc.w	6,1
		dc.l	100000
		dc.w	2,6
		dc.w	-1

	section	bss
u2_xyz:		ds.w	3
u2_idx:		ds.w	1
u2_j:		ds.w	1
u2_dist:	ds.l	2
u2_names:	ds.l	1
u2_orb:		ds.w	8
