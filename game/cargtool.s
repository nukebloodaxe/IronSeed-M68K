; cargtool.s - cargtool.pas for MAIN.PRG: the cargo hold (inventory: the list and info views,
; the filters, jettisoning with the All/Half/One request) and the creation screen (integrate /
; decompose: the list of things the crew can make or the cargo to take apart, the parts and
; their stock, the item information, the three engineering teams and their progress), and
; StartBuild (also used by the engineering teams' work in crewtick.s). Modes CARGO (cargo.cpr)
; and TECH1 (tech1.cpr), tools/mkmain.py.
;
; inventory     cargtool.pas inventory                               trashes: d0-d2/a0-a2
; creation      cargtool.pas creation                                trashes: d0-d2/a0-a2
; startbuild    in: d0.b background, d1.w root, d2.w item, d3.w team  out: d0.w (1 started,
;               0 no parts, -1 level, -2 unknown, -3 knowledge)       trashes: d0-d2/a0-a2
; getbuildtime  in: d0.w item  out: d0.w                              trashes: d0-d1/a0
; Printing the cargo (yes to 'PRINT CARGO?'): printcargo (print.s) writes TEMP\LPT1.

II_SIZE		equ	118		; iteminfotype: index.w, 4 x string[28]
FADE_MUL_CARGTOOL equ	4
FADE_MUL_CARGCREAT equ	2

	section	text
; ---------------------------------------------------------------- shared
; a0 = cargo[] record whose index is d0 (i := 1; while cargo[i].index <> item do inc(i))
ct2_cargorec:
	lea	GS_CARGO(a6),a0
.l:	cmp.w	CARGO_INDEX(a0),d0
	beq.s	.x
	lea	CARGO_SIZEOF(a0),a0
	bra.s	.l
.x:	rts
; d0.w = ship.cargo[d0] (flat: cargo[0] is orbiting, cargo[251] numcargo[1], as the original reads)
ct2_cargo:
	add.w	d0,d0
	lea	GS_SHIP+SHIP_CARGO-2(a6),a0
	move.w	0(a0,d0.w),d0
	rts
; d0.w = ship.numcargo[d0]
ct2_num:
	add.w	d0,d0
	lea	GS_SHIP+SHIP_NUMCARGO-2(a6),a0
	move.w	0(a0,d0.w),d0
	rts
; the filter class of an item d0 (cargo screen ranges): out d0 = 1 weapon, 2 shield,
; 3 element/material, 4 device/component/artifact, 0 none
ct2_class:
	cmp.w	#ID_DIRK,d0
	blt.s	.n
	cmp.w	#1499,d0
	ble.s	.w
	cmp.w	#1999,d0
	ble.s	.s
	cmp.w	#3999,d0
	ble.s	.d
	cmp.w	#ID_LAST_ELEMENT,d0
	ble.s	.m
	cmp.w	#ID_LAST_ARTIFACT,d0
	ble.s	.d
.n:	moveq	#0,d0
	rts
.w:	moveq	#1,d0
	rts
.s:	moveq	#2,d0
	rts
.m:	moveq	#3,d0
	rts
.d:	moveq	#4,d0
	rts
; Z clear if filters2[class of item d0] = 1 (out d0 = 1/0)
ct2_shown:
	bsr.s	ct2_class
	tst.w	d0
	beq.s	.x
	lea	ct2_filters2-1,a0
	moveq	#0,d1
	move.b	0(a0,d0.w),d1
	move.w	d1,d0
.x:	tst.w	d0
	rts

getbuildtime:
	move.l	d3,-(sp)
	lea	GS_CARGO+CARGO_INDEX(a6),a0
	moveq	#0,d1			; i-1
.l:	cmp.w	(a0),d0
	beq.s	.f
	lea	CARGO_SIZEOF(a0),a0
	addq.w	#1,d1
	cmp.w	#MAXCARGO,d1
	blt.s	.l
	move.w	#6500,d0
	bra.s	.x
.f:	add.w	d1,d1
	lea	GS_BLDCARGO(a6),a0
	add.w	d1,a0
	cmp.w	#30000,(a0)
	bne.s	.k
	move.w	#65,(a0)
.k:	move.w	(a0),d0
	mulu	#100,d0
.x:	move.l	(sp)+,d3
	rts

; i := the cargo[] index (1-based) of item d0, or MAXCARGO+1: out d0
ct2_cargoindex:
	lea	GS_CARGO+CARGO_INDEX(a6),a0
	moveq	#1,d1
.l:	cmp.w	#MAXCARGO,d1
	bgt.s	.x
	cmp.w	(a0),d0
	beq.s	.x
	lea	CARGO_SIZEOF(a0),a0
	addq.w	#1,d1
	bra.s	.l
.x:	move.w	d1,d0
	rts
; a0 = prtcargo[i d0] (3 words), a1 = lvlcargo[i] (6 words)
ct2_parts:
	subq.w	#1,d0
	move.w	d0,d1
	mulu	#6,d0
	lea	GS_PRTCARGO(a6),a0
	add.w	d0,a0
	mulu	#12,d1
	lea	GS_LVLCARGO(a6),a1
	add.w	d1,a1
	rts
; d0 = 1 if some level lvlcargo[i, j] > ship.crew[j].level (a1 = lvlcargo[i])
ct2_lowlevel:
	lea	GS_SHIP+SHIP_CREW+CREW_LEVEL(a6),a0
	moveq	#6-1,d1
.l:	moveq	#0,d0
	move.b	(a0),d0
	cmp.w	(a1)+,d0
	blt.s	.y
	lea	CREW_SIZEOF(a0),a0
	dbf	d1,.l
	moveq	#0,d0
	rts
.y:	moveq	#1,d0
	rts

startbuild:
	movem.l	d3-d7/a3-a4,-(sp)
	move.b	d0,ct2_bg
	move.w	d1,d6			; root
	move.w	d2,d5			; item
	move.w	d3,d7			; team
	move.w	d5,d0
	bsr	ct2_cargoindex
	cmp.w	#MAXCARGO,d0
	ble.s	.e
	moveq	#-2,d0
	bra	.x
.e:	move.w	d0,d4			; i
	bsr	ct2_parts
	move.l	a0,a3			; prtcargo[i]
	move.l	a1,a4			; lvlcargo[i]
	tst.w	(a3)
	bne.s	.p
	moveq	#0,d0
	bra	.x
.p:	cmp.w	#ID_THERMOPLAST,d5
	bne.s	.l
	moveq	#18,d0
	bsr	chevent
	tst.w	d0
	bne.s	.l
	moveq	#-3,d0
	bra	.x
.l:	move.l	a4,a1
	bsr	ct2_lowlevel
	tst.w	d0
	beq.s	.k
	moveq	#-1,d0
	bra	.x
.k:	moveq	#1,d3			; k: how many of the first part
	move.w	(a3),d0
	cmp.w	2(a3),d0
	bne.s	.k2
	addq.w	#1,d3
.k2:	cmp.w	4(a3),d0
	bne.s	.k3
	addq.w	#1,d3
.k3:	bsr	incargo
	cmp.w	d3,d0
	bge.s	.p2
	move.w	(a3),d2			; the first part is missing: build it first
	bra	.sub
.p2:	moveq	#2-1,d3			; parts 2, 3
	lea	2(a3),a0
.p3:	move.w	(a0),d0
	move.l	a0,-(sp)
	bsr	incargo
	move.l	(sp)+,a0
	tst.w	d0
	bgt.s	.p4
	move.w	(a0),d2
	bra	.sub
.p4:	addq.l	#2,a0
	dbf	d3,.p3
	move.w	d7,d0			; the team takes the job
	subq.w	#1,d0
	lsl.w	#3,d0
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a0
	add.w	d0,a0
	move.w	d5,TEAM_JOB(a0)
	move.w	d6,TEAM_EXTRA(a0)
	move.w	#JOBTYPE_CREATE,TEAM_JOBTYPE(a0)
	move.l	a0,-(sp)
	move.w	d5,d0
	bsr	getbuildtime
	move.l	(sp)+,a0
	move.w	d0,TEAM_TIMELEFT(a0)
	move.w	(a3),d0			; the parts out of the hold
	bsr	removecargo
	move.w	2(a3),d0
	bsr	removecargo
	move.w	4(a3),d0
	bsr	removecargo
	bsr	rebuildcargoreserve
	moveq	#1,d3			; addxp(j, lvlcargo[i,j], ord(not background))
.xp:	move.w	d3,d0
	move.w	d3,d1
	add.w	d1,d1
	move.w	-2(a4,d1.w),d1
	ext.l	d1
	moveq	#1,d2
	tst.b	ct2_bg
	beq.s	.xp3
	moveq	#0,d2
.xp3:	bsr	addxp
	addq.w	#1,d3
	cmp.w	#6,d3
	ble.s	.xp
	clr.w	ct2_teamjob
	moveq	#1,d0
	bra.s	.x
.sub:	cmp.w	d5,d2			; (the part is the item itself: no endless recursion)
	bne.s	.r
	moveq	#0,d0
	bra.s	.x
.r:	move.b	ct2_bg,d0
	move.w	d6,d1
	move.w	d7,d3
	bsr	startbuild
.x:	movem.l	(sp)+,d3-d7/a3-a4
	rts

; CheckBuildSubStock(item d0): out d0
ct2_substock:
	movem.l	d3-d6/a3,-(sp)
	move.w	d0,d5
	bsr	incargoindex
	tst.w	d0
	beq.s	.n
	move.w	d0,d1			; numcargo[i] - rescargo[i] - res2cargo[i] > 0 ?
	add.w	d1,d1
	lea	GS_SHIP+SHIP_NUMCARGO-2(a6),a0
	move.w	0(a0,d1.w),d2
	lea	GS_RESCARGO-2(a6),a0
	sub.w	0(a0,d1.w),d2
	lea	ct2_res2-2,a0
	sub.w	0(a0,d1.w),d2
	ble.s	.n
	addq.w	#1,0(a0,d1.w)
	moveq	#1,d0
	bra	.x
.n:	move.w	d5,d0
	bsr	ct2_cargoindex
	cmp.w	#MAXCARGO,d0
	ble.s	.e
	moveq	#-2,d0
	bra.s	.x
.e:	bsr	ct2_parts
	move.l	a0,a3
	bsr	ct2_lowlevel
	tst.w	d0
	beq.s	.k
	moveq	#-1,d0
	bra.s	.x
.k:	tst.w	5*2(a3)			; prtcargo[i, j] with j = 6 after the level loop: the next
	bne.s	.go			; entry's third part (as the original reads it)
	moveq	#0,d0
	bra.s	.x
.go:	moveq	#2,d6			; l
	moveq	#3-1,d4
.j:	move.w	(a3)+,d0
	cmp.w	d5,d0
	bne.s	.rc
	moveq	#0,d0
	bra.s	.c
.rc:	bsr	ct2_substock
.c:	cmp.w	#-2,d0
	bne.s	.c1
	moveq	#-2,d6
	bra.s	.cn
.c1:	cmp.w	#-1,d0
	bne.s	.c2
	cmp.w	#-1,d6
	ble.s	.cn
	moveq	#-1,d6
	bra.s	.cn
.c2:	tst.w	d0
	bne.s	.cn
	tst.w	d6
	ble.s	.cn
	moveq	#0,d6
.cn:	dbf	d4,.j
	move.w	d6,d0
.x:	movem.l	(sp)+,d3-d6/a3
	rts

; CheckBuildStock(item d0): out d0
ct2_buildstock:
	movem.l	d3-d6/a3,-(sp)
	move.w	d0,d5
	lea	ct2_res2,a0
	move.w	#250-1,d1
.z:	clr.w	(a0)+
	dbf	d1,.z
	move.w	d5,d0
	bsr	ct2_cargoindex
	cmp.w	#MAXCARGO,d0
	ble.s	.e
	moveq	#-2,d0
	bra.s	.x
.e:	bsr	ct2_parts
	move.l	a0,a3
	tst.w	(a3)			; (not buildable: -2, unless the level test exits first)
	bne.s	.lv
	moveq	#-2,d6
	bsr	ct2_lowlevel
	tst.w	d0
	beq.s	.go
	moveq	#-1,d0
	bra.s	.x
.lv:	bsr	ct2_lowlevel
	tst.w	d0
	beq.s	.go
	moveq	#-1,d0
	bra.s	.x
.go:	moveq	#0,d6			; l (the -2 above is overwritten: l := 0)
	moveq	#0,d4			; j-1
.j:	move.w	(a3)+,d0
	bsr	ct2_substock
	cmp.w	#-2,d0
	bne.s	.c1
	moveq	#-2,d6
	bra.s	.cn
.c1:	cmp.w	#1,d0
	blt.s	.cn
	cmp.w	#2,d0
	bgt.s	.cn
	move.w	d4,d1			; l := l or (k shl (j+j-2))
	add.w	d1,d1
	lsl.w	d1,d0
	or.w	d0,d6
.cn:	addq.w	#1,d4
	cmp.w	#3,d4
	bne.s	.j
	move.w	d6,d0
.x:	movem.l	(sp)+,d3-d6/a3
	rts

; ---------------------------------------------------------------- the cargo hold
; newcursor(start d0) / revnewcursor(start d0) on ct2_index
ct2_newcursor:
	move.w	d0,ct2_index
	cmp.w	#251,d0
	beq.s	.x
.l:	addq.w	#1,ct2_index
	move.w	ct2_index,d0
	bsr	ct2_cargo
	bsr	ct2_shown
	bne.s	.x
	cmp.w	#251,ct2_index
	bne.s	.l
.x:	rts
ct2_revnewcursor:
	move.w	d0,ct2_index
	cmp.w	#1,d0
	blt.s	.x
.l:	subq.w	#1,ct2_index
	move.w	ct2_index,d0
	bsr	ct2_cargo
	move.w	d0,d1
	bsr	ct2_class
	tst.w	d0
	beq.s	.t			; (no class: no change)
	lea	ct2_filters2-1,a0
	tst.b	0(a0,d0.w)
	bne.s	.x			; shown: found
	subq.w	#1,ct2_index		; not shown: one more step back (the original's extra dec)
.t:	cmp.w	#1,ct2_index
	bge.s	.l
.x:	rts

ct2_drawfilters:
	movem.l	d3-d5,-(sp)
	moveq	#1,d5			; a
.a:	moveq	#0,d3			; b
.b:	lea	ct2_filters2-1,a0	; colour 48 + filters2[a+b*2]*8
	move.w	d3,d0
	add.w	d0,d0
	add.w	d5,d0
	moveq	#0,d4
	move.b	0(a0,d0.w),d4
	lsl.w	#3,d4
	add.w	#48,d4
	move.w	d3,d0			; rows 72+a*5 .. 74+a*5, x 269+b*9 .. 276+b*9
	mulu	#9,d0
	add.w	#269,d0
	move.w	d5,d1
	mulu	#5,d1
	add.w	#72,d1
	move.w	d0,d2
	addq.w	#7,d2
	move.w	d3,-(sp)
	move.w	d1,d3
	addq.w	#2,d3
	bsr	ms_bar
	move.w	(sp)+,d3
	addq.w	#1,d3
	cmp.w	#1,d3
	ble.s	.b
	addq.w	#1,d5
	cmp.w	#2,d5
	ble.s	.a
	movem.l	(sp)+,d3-d5
	rts

; opendoors: the gate slides up (OPT_ANIMATION), the button row comes back
ct2_opendoors:
	PMARK	1
	movem.l	d3-d4,-(sp)
	tst.b	GS_SHIP+SHIP_OPTIONS+OPT_ANIMATION-1(a6)
	bne.s	.anim
	moveq	#1,d0
	bsr	fadestep
	BAR	90,20,233,130,0
	moveq	#110,d3
.b:	move.w	d3,d0
	bsr	ct2_putbuttons
	addq.w	#1,d3
	cmp.w	#126,d3
	ble.s	.b
	bra.s	.f
.anim:	moveq	#0,d4			; a
.a:	moveq	#1,d0
	bsr	fadestep
	move.w	GS_TSLICE(a6),d0
	lsr.w	#2,d0
	bsr	delay
	moveq	#90,d0			; the planar rows move too (ms_vscroll: a copy, not a conversion)
	moveq	#20,d1
	move.w	#233,d2
	move.w	#130,d3
	sub.w	d4,d3
	move.w	d4,-(sp)
	moveq	#1,d4
	bsr	ms_vscroll
	move.w	(sp)+,d4
	moveq	#20,d3			; rows 20..130-a := the row below
.r:	moveq	#90,d0
	move.w	d3,d1
	bsr	ms_addr
	moveq	#144/4-1,d0		; (x 90: even, longs)
.c:	move.l	MS_W(a0),(a0)+
	dbf	d0,.c
	addq.w	#1,d3
	move.w	#130,d0
	sub.w	d4,d0
	cmp.w	d0,d3
	ble.s	.r
	move.w	#131,d0			; the button row 131-a while it is in 110..126
	sub.w	d4,d0
	cmp.w	#127,d0
	bge.s	.n
	cmp.w	#109,d0
	ble.s	.n
	bsr	ct2_putbuttons
.n:	addq.w	#1,d4
	cmp.w	#109,d4
	ble.s	.a
.f:	FADE	38,78,40,82,-12
	FADE	44,78,46,82,12
	movem.l	(sp)+,d3-d4
	PMARK	2
	rts
; cargobuttons^[row d0, 92..227] -> screen
ct2_putbuttons:
	move.w	d3,-(sp)
	move.w	d0,d3
	sub.w	#110,d0
	mulu	#136,d0
	lea	ct2_buttons,a1
	add.w	d0,a1
	moveq	#92,d0
	move.w	d3,d1
	bsr	ms_addr
	moveq	#136/4-1,d0
.c:	move.l	(a1)+,d1		; (a0 even: x 92)
	move.l	d1,(a0)+
	dbf	d0,.c
	moveq	#92,d0
	move.w	d3,d1
	move.w	#227,d2
	bsr	ms_dirty
	move.w	(sp)+,d3
	rts

; closedoors: the gate comes down again (the picture from cargo.cpr, without the list)
ct2_closedoors:
	PMARK	3
	movem.l	d3-d5/a3,-(sp)
	tst.b	GS_SHIP+SHIP_OPTIONS+OPT_ANIMATION-1(a6)
	beq	.x
	bsr	mousehide
	bsr	mem_mark
	move.l	d0,d5
	move.l	#64000,d0		; temp := cargo.cpr
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,a3
	bsr	orc_dump
	lea	ct2_mode,a0
	move.l	a3,a1
	bsr	loadchk
	moveq	#110,d3			; temp^[110..126, 94..226] := 0
.z:	move.w	d3,d0
	mulu	#MS_W,d0
	lea	94(a3,d0.l),a0
	move.w	#133-1,d0
.zc:	clr.b	(a0)+
	dbf	d0,.zc
	addq.w	#1,d3
	cmp.w	#126,d3
	ble.s	.z
	moveq	#1,d4			; a
.a:	move.w	GS_TSLICE(a6),d0
	lsr.w	#2,d0
	bsr	delay
	cmp.w	#1,d4			; rows 21..20+a show what rows 20..19+a showed: move them
	beq.s	.cs
	moveq	#90,d0
	moveq	#21,d1
	move.w	#233,d2
	moveq	#20,d3
	add.w	d4,d3
	move.w	d4,-(sp)
	moveq	#-1,d4
	bsr	ms_vscroll
	move.w	(sp)+,d4
.cs:	moveq	#20,d3			; screen[20..20+a] := temp^[110-a+i]
.r:	moveq	#90,d0
	move.w	d3,d1
	bsr	ms_addr
	move.w	#110,d0
	sub.w	d4,d0
	add.w	d3,d0
	mulu	#MS_W,d0
	lea	90(a3,d0.l),a1
	moveq	#144/4-1,d0
.c:	move.l	(a1)+,(a0)+
	dbf	d0,.c
	addq.w	#1,d3
	move.w	#20,d0
	add.w	d4,d0
	cmp.w	d0,d3
	ble.s	.r
	moveq	#90,d0			; the new row 20 (a = 1: both rows)
	moveq	#20,d1
	move.w	#233,d2
	moveq	#20,d3
	cmp.w	#1,d4
	bne.s	.d1
	moveq	#21,d3
.d1:	bsr	ms_dirty
	addq.w	#1,d4
	cmp.w	#110,d4
	ble.s	.a
	move.l	d5,d0
	bsr	mem_release
	bsr	mouseshow
	FADE	38,78,40,82,12
	FADE	44,78,46,82,-12
.x:	movem.l	(sp)+,d3-d5/a3
	PMARK	4
	rts

ct2_readydata:
	movem.l	d3,-(sp)
	bsr	mousehide
	moveq	#0,d0			; quicksavescreen(current)
	bsr	ms_snap
	moveq	#-8,d0			; fadefull(-FADEFULL_STEP, FADEFULL_DELAY)
	moveq	#20,d1
	bsr	fadefull
	lea	ct2_fn_cargo,a0		; playmod(true, CARGO.MOD)
	bsr	playmod
	bsr	orc_dump		; loadscreen(cargo)
	lea	ct2_mode,a0
	bsr	ms_load
	bcs	fatal
	lea	ct2_buttons,a1		; cargobuttons^ := rows 110..126, x 92..227; then 94..226 := 0
	moveq	#110,d3
.b:	moveq	#92,d0
	move.w	d3,d1
	bsr	ms_addr
	moveq	#136/4-1,d0
.bc:	move.l	(a0)+,(a1)+
	dbf	d0,.bc
	addq.w	#1,d3
	cmp.w	#126,d3
	ble.s	.b
	BAR	94,110,226,126,0
	FADE	38,78,40,82,12
	bsr	ct2_drawfilters
	bsr	fadein
	bsr	ct2_opendoors
	bsr	mouseshow
	sf	GS_DONE(a6)
	moveq	#0,d0
	bsr	ct2_newcursor
	clr.w	ct2_mode_
	move.w	#232,GS_LIGHTINDEX(a6)
	BKCOL	0
	move.l	GS_T1(a6),GS_OLDT1(a6)
	move.l	GS_T1+4(a6),GS_OLDT1+4(a6)
	movem.l	(sp)+,d3
	rts

; checklist(down d0.b): the list line of ship.cargo[x] (x, y are data.pas's)
ct2_checklist:
	movem.l	d3-d5/a3,-(sp)
	move.b	d0,d5
	move.w	GS_X(a6),d3
	cmp.w	#1,d3
	blt	.x
	cmp.w	#250,d3
	bgt	.x
	move.w	d3,d0			; str(rescargo[x]:3, str2)
	add.w	d0,d0
	lea	GS_RESCARGO-2(a6),a0
	move.w	0(a0,d0.w),d0
	ext.l	d0
	moveq	#3,d1
	lea	ct2_s2,a0
	bsr	int_str
	move.w	d3,d0
	bsr	ct2_cargo
	move.w	d0,d4			; item
	beq	.x
	bsr	ct2_shown
	beq	.x
	tst.b	d5			; if down then dec(y) else inc(y)
	beq.s	.up
	subq.w	#1,GS_Y(a6)
	bra.s	.yy
.up:	addq.w	#1,GS_Y(a6)
.yy:	move.w	d3,d0			; str(numcargo[x]:3, str1)
	bsr	ct2_num
	ext.l	d0
	and.l	#$ffff,d0
	moveq	#3,d1
	lea	ct2_s,a0
	bsr	int_str
	cmp.w	#ID_ARTIFACT_OFFSET,d4
	blt.s	.it
	move.w	d4,d0			; artifact: str1 + '     ' + cargo[maxcargo].name
	bsr	getartifactname
	lea	ct2_s,a0
	lea	ct2_t_5sp,a1
	bsr	pstr_cat
	lea	GS_CARGO+(MAXCARGO-1)*CARGO_SIZEOF+CARGO_NAME(a6),a1
	bra.s	.pr
.it:	lea	ct2_s,a0		; str1 + '(' + str2 + ')' + cargo[j].name
	lea	ct2_t_lp,a1
	bsr	pstr_cat
	lea	ct2_s,a0
	lea	ct2_s2,a1
	bsr	pstr_cat
	lea	ct2_s,a0
	lea	ct2_t_rp,a1
	bsr	pstr_cat
	move.w	d4,d0
	bsr	ct2_cargorec
	lea	CARGO_NAME(a0),a1
.pr:	lea	ct2_s,a0
	bsr	pstr_cat
	move.w	GS_Y(a6),d1		; printxy(86, 16+y*6, ...)
	mulu	#6,d1
	add.w	#16,d1
	moveq	#86,d0
	lea	ct2_s,a0
	bsr	printxy
.x:	movem.l	(sp)+,d3-d5/a3
	rts

ct2_displaylist:
	move.w	ct2_index,d0
	bsr	ct2_cargo
	tst.w	d0
	bne.s	.a
	move.w	ct2_index,d0
	bsr	ct2_newcursor
	cmp.w	#251,ct2_index
	bne.s	.a
	move.w	ct2_index,d0
	bsr	ct2_revnewcursor
.a:	TCOL	28
	BKCOL	0
	move.w	ct2_index,d0
	subq.w	#1,d0
	move.w	d0,GS_X(a6)
	bsr	mousehide
	move.w	#7,GS_Y(a6)
.l1:	st	d0
	bsr	ct2_checklist
	subq.w	#1,GS_X(a6)
	cmp.w	#1,GS_Y(a6)
	beq.s	.e1
	cmp.w	#1,GS_X(a6)
	bge.s	.l1
.e1:	cmp.w	#1,GS_Y(a6)
	ble.s	.n1
	move.l	d3,-(sp)
	moveq	#92,d0			; rows 23 .. 16+y*6, x 92..224 := 0
	moveq	#23,d1
	move.w	#224,d2
	move.w	GS_Y(a6),d3
	mulu	#6,d3
	add.w	#16,d3
	movem.l	d4,-(sp)
	moveq	#0,d4
	bsr	ms_bar
	movem.l	(sp)+,d4
	move.l	(sp)+,d3
.n1:	BKCOL	6
	move.w	ct2_index,GS_X(a6)
	move.w	#6,GS_Y(a6)
.l2:	sf	d0
	bsr	ct2_checklist
	BKCOL	0
	addq.w	#1,GS_X(a6)
	cmp.w	#14,GS_Y(a6)
	beq.s	.e2
	cmp.w	#251,GS_X(a6)
	ble.s	.l2
.e2:	cmp.w	#14,GS_Y(a6)
	bge.s	.n2
	movem.l	d3-d4,-(sp)
	moveq	#92,d0			; rows 23+y*6 .. 106 := 0
	move.w	GS_Y(a6),d1
	mulu	#6,d1
	add.w	#23,d1
	move.w	#224,d2
	moveq	#106,d3
	moveq	#0,d4
	cmp.w	d3,d1
	bgt.s	.n2b
	bsr	ms_bar
.n2b:	movem.l	(sp)+,d3-d4
.n2:	bra	mouseshow

ct2_displayinfo:
	movem.l	d3-d6/a3,-(sp)
	move.w	ct2_index,d0
	bsr	ct2_cargo
	tst.w	d0
	bne.s	.a
	move.w	ct2_index,d0
	bsr	ct2_newcursor
	cmp.w	#251,ct2_index
	bne.s	.a
	moveq	#0,d0
	bsr	ct2_newcursor
.a:	tst.w	ct2_index
	beq	.x
	move.w	ct2_index,GS_X(a6)
	TCOL	28
	BKCOL	6
	clr.w	GS_Y(a6)
	bsr	mousehide
.r:	move.w	GS_X(a6),d3		; while (x < 251) and (cargo[x] = 0) do inc(x)
.w:	cmp.w	#251,d3
	bge.s	.we
	move.w	d3,d0
	bsr	ct2_cargo
	tst.w	d0
	bne.s	.we
	addq.w	#1,d3
	bra.s	.w
.we:	move.w	d3,GS_X(a6)
	move.w	d3,d0
	bsr	ct2_cargo
	move.w	d0,d4			; item
	cmp.w	#251,d3
	bge	.nx
	bsr	ct2_shown
	beq	.nx
	cmp.w	#ID_ARTIFACT_OFFSET,d4
	ble.s	.ci
	move.w	d4,d0
	bsr	getartifactname
	lea	GS_CARGO+(MAXCARGO-1)*CARGO_SIZEOF(a6),a3
	bra.s	.cf
.ci:	move.w	d4,d0
	bsr	ct2_cargorec
	move.l	a0,a3
.cf:	addq.w	#1,GS_Y(a6)
	move.w	GS_Y(a6),d6
	mulu	#20,d6			; y*20
	lea	CARGO_NAME(a3),a0
	moveq	#92,d0
	move.w	d6,d1
	addq.w	#2,d1
	bsr	printxy
	BKCOL	0			; (y > 0 now)
	lea	ct2_t_types,a1		; the type
	move.w	d4,d0
	cmp.w	#ID_DIRK,d0
	blt.s	.ty7
	cmp.w	#1499,d0
	ble.s	.ty
	lea	10(a1),a1
	cmp.w	#1999,d0
	ble.s	.ty
	lea	10(a1),a1
	cmp.w	#2999,d0
	ble.s	.ty
	lea	10(a1),a1
	cmp.w	#3999,d0
	ble.s	.ty
	lea	10(a1),a1
	cmp.w	#ID_LAST_ELEMENT,d0
	ble.s	.ty
	lea	10(a1),a1
	cmp.w	#ID_LAST_ARTIFACT,d0
	ble.s	.ty
.ty7:	lea	ct2_t_types+60,a1
.ty:	lea	ct2_s,a0
	move.l	a1,-(sp)
	lea	ct2_t_type,a1
	bsr	pstr_cpy
	move.l	(sp)+,a1
	lea	ct2_s,a0
	bsr	pstr_cat
	moveq	#100,d0
	move.w	d6,d1
	addq.w	#8,d1
	lea	ct2_s,a0
	bsr	printxy
	FSSE				; x1 := cargo[j].size/10; str(x1:7:1)
	move.w	CARGO_SIZE(a3),d0
	bsr	fp_ldw
	FLDI	10
	bsr	fp_div
	FSTG	GS_X1
	FLDG	GS_X1
	moveq	#7,d0
	moveq	#1,d1
	lea	ct2_s2,a0
	bsr	fp_str
	lea	ct2_s,a0
	lea	ct2_t_size,a1
	bsr	pstr_cpy
	lea	ct2_s,a0
	lea	ct2_s2,a1
	bsr	pstr_cat
	moveq	#100,d0
	move.w	d6,d1
	add.w	#14,d1
	lea	ct2_s,a0
	bsr	printxy
	move.w	GS_X(a6),d0		; 'Num:' + str(numcargo[x]:3)
	bsr	ct2_num
	and.l	#$ffff,d0
	moveq	#3,d1
	lea	ct2_s2,a0
	bsr	int_str
	lea	ct2_s,a0
	lea	ct2_t_num,a1
	bsr	pstr_cpy
	lea	ct2_s,a0
	lea	ct2_s2,a1
	bsr	pstr_cat
	move.w	#175,d0
	move.w	d6,d1
	add.w	#14,d1
	lea	ct2_s,a0
	bsr	printxy
.nx:	addq.w	#1,GS_X(a6)
	cmp.w	#4,GS_Y(a6)
	beq.s	.e
	cmp.w	#250,GS_X(a6)
	ble	.r
.e:	cmp.w	#4,GS_Y(a6)
	bge.s	.m
	moveq	#92,d0			; rows 22+y*20 .. 106 := 0
	move.w	GS_Y(a6),d1
	mulu	#20,d1
	add.w	#22,d1
	move.w	#224,d2
	moveq	#106,d3
	moveq	#0,d4
	bsr	ms_bar
.m:	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d6/a3
	rts

; request(s a0, alt d0, text d1): out d0 = 1 All, 2 Half, 3 One, 4 Esc
ct2_request:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	a0,a5
	move.w	d0,d6			; alt
	bsr	mousehide
	lea	mb_save,a3		; tempscr^ := rows 60..102, x 74..245
	moveq	#60,d3
.sv:	moveq	#74,d0
	move.w	d3,d1
	bsr	ms_addr
	move.w	#172-1,d0
.svc:	move.b	(a0)+,(a3)+
	dbf	d0,.svc
	addq.w	#1,d3
	cmp.w	#102,d3
	ble.s	.sv
	move.w	ct2_reqtext,d0		; tcolor := text-5
	subq.w	#5,d0
	move.w	d0,GS_TCOLOR(a6)
	move.w	d6,d0
	add.w	#35,d0
	move.w	d0,GS_BKCOLOR(a6)
	moveq	#75,d0			; the box and the three buttons
	moveq	#60,d1
	move.w	#245,d2
	moveq	#102,d3
	move.w	d6,d4
	bsr	mb_button
	moveq	#78,d0
	moveq	#78,d1
	move.w	#128,d2
	moveq	#92,d3
	move.w	d6,d4
	addq.w	#2,d4
	bsr	mb_button
	move.w	#135,d0
	moveq	#78,d1
	move.w	#185,d2
	moveq	#92,d3
	move.w	d6,d4
	addq.w	#2,d4
	bsr	mb_button
	move.w	#192,d0
	moveq	#78,d1
	move.w	#242,d2
	moveq	#92,d3
	move.w	d6,d4
	addq.w	#2,d4
	bsr	mb_button
	moveq	#0,d0			; printxy(156 - round(length(s)*2.5), 65, s)
	move.b	(a5),d0
	mulu	#5,d0
	lsr.w	#1,d0
	bcc.s	.e
	btst	#0,d0
	beq.s	.e
	addq.w	#1,d0
.e:	neg.w	d0
	add.w	#156,d0
	moveq	#65,d1
	move.l	a5,a0
	bsr	printxy
	move.w	d6,d0
	add.w	#37,d0
	move.w	d0,GS_BKCOLOR(a6)
	PXY	92,82,"All"
	PXY	146,82,"Half"
	PXY	206,82,"One"
	clr.w	ct2_lastx		; mainloop2
	clr.w	ct2_lasty
	clr.w	ct2_cursor
	sf	ct2_done2
	bsr	mouseshow
.l:	bsr	ct2_findmouse2
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	ct2_processkey2
.nk:	tst.b	ct2_done2
	beq.s	.l
	move.w	ct2_cursor,d7
	bsr	mousehide
	lea	mb_save,a3
	moveq	#60,d3
.rs:	moveq	#74,d0
	move.w	d3,d1
	bsr	ms_addr
	move.w	#172-1,d0
.rsc:	move.b	(a3)+,(a0)+
	dbf	d0,.rsc
	addq.w	#1,d3
	cmp.w	#102,d3
	ble.s	.rs
	moveq	#74,d0
	moveq	#60,d1
	move.w	#245,d2
	moveq	#102,d3
	bsr	ms_dirty
	move.w	#3,GS_BKCOLOR(a6)
	bsr	mouseshow
	moveq	#0,d0			; move_mouse(0, 0)
	moveq	#0,d1
	bsr	kbd_mouse_move
	move.w	d7,d0
	movem.l	(sp)+,d3-d7/a3-a5
	rts
; the request's buttons: plainfadearea +-3 on button d0 (1-3)
ct2_reqfade:
	movem.l	d3-d4,-(sp)
	move.w	d1,d4
	subq.w	#1,d0
	bmi.s	.x
	cmp.w	#2,d0
	bgt.s	.x
	mulu	#57,d0
	add.w	#78,d0
	moveq	#78,d1
	move.w	d0,d2
	add.w	#50,d2
	moveq	#92,d3
	bsr	plainfadearea
.x:	movem.l	(sp)+,d3-d4
	rts
ct2_findmouse2:
	bsr	kbd_mouse_status
	move.b	d0,ct2_button
	bsr	kbd_mouse_xy
	tst.b	ct2_button		; if (not button) and (x = lastx) or (y = lasty) then exit
	bne.s	.b
	cmp.w	ct2_lastx,d0
	beq	.x
.b:	cmp.w	ct2_lasty,d1
	beq.s	.x
	moveq	#0,d2			; newcursor by the position
	cmp.w	#78,d1
	blt.s	.n
	cmp.w	#92,d1
	bgt.s	.n
	cmp.w	#78,d0
	blt.s	.n
	moveq	#1,d2
	cmp.w	#128,d0
	ble.s	.n
	moveq	#0,d2
	cmp.w	#135,d0
	blt.s	.n
	moveq	#2,d2
	cmp.w	#185,d0
	ble.s	.n
	moveq	#0,d2
	cmp.w	#192,d0
	blt.s	.n
	moveq	#3,d2
	cmp.w	#242,d0
	ble.s	.n
	moveq	#0,d2
.n:	cmp.w	ct2_cursor,d2
	beq.s	.c
	move.w	d2,-(sp)
	move.w	ct2_cursor,d0
	moveq	#-3,d1
	bsr	ct2_reqfade
	move.w	(sp)+,ct2_cursor
	move.w	ct2_cursor,d0
	moveq	#3,d1
	bsr	ct2_reqfade
.c:	tst.w	ct2_cursor
	beq.s	.x
	tst.b	ct2_button
	beq.s	.x
	st	ct2_done2
.x:	rts
ct2_processkey2:
	move.w	ct2_cursor,d0		; undocursor2
	moveq	#-3,d1
	bsr	ct2_reqfade
	bsr	kbd_readkey
	tst.b	d0
	bne.s	.a
	bsr	kbd_readkey
	cmp.b	#75,d0
	beq.s	.lr
	cmp.b	#77,d0
	bne.s	.d
.lr:	cmp.w	#1,ct2_cursor
	bne.s	.l1
	move.w	#2,ct2_cursor
	bra.s	.d
.l1:	move.w	#1,ct2_cursor
	bra.s	.d
.a:	cmp.b	#'a',d0
	blo.s	.u
	cmp.b	#'z',d0
	bhi.s	.u
	sub.b	#32,d0
.u:	cmp.b	#13,d0
	bne.s	.k1
	tst.w	ct2_cursor
	beq.s	.d
	bra.s	.dn
.k1:	moveq	#4,d1
	cmp.b	#27,d0
	beq.s	.set
	moveq	#1,d1
	cmp.b	#'A',d0
	beq.s	.set
	moveq	#2,d1
	cmp.b	#'H',d0
	beq.s	.set
	moveq	#3,d1
	cmp.b	#'O',d0
	beq.s	.set
	cmp.b	#'1',d0
	bne.s	.d
.set:	move.w	d1,ct2_cursor
.dn:	st	ct2_done2
.d:	move.w	ct2_cursor,d0		; drawcursor2
	moveq	#3,d1
	bsr	ct2_reqfade
	bsr	kbd_mouse_xy
	move.w	d0,ct2_lastx
	move.w	d1,ct2_lasty
	rts

; dropit: jettison the item under the cursor
ct2_dropit:
	movem.l	d3-d4/a3,-(sp)
	move.w	ct2_index,d3
	beq	.x
	cmp.w	#251,d3
	beq	.x
	move.w	d3,d0
	bsr	ct2_cargo
	cmp.w	#ID_MOBIUS_DEVICE,d0
	beq	.vital
	cmp.w	#ID_ART_SHUNT_DRIVE,d0
	bge	.vital
	move.w	d3,d0			; rescargo >= numcargo: needed for building
	add.w	d0,d0
	lea	GS_RESCARGO-2(a6),a0
	move.w	0(a0,d0.w),d1
	lea	GS_SHIP+SHIP_NUMCARGO-2(a6),a0
	cmp.w	0(a0,d0.w),d1
	bhs	.need
	move.w	d3,d0
	bsr	ct2_cargo
	bsr	ct2_cargorec		; s := name with its trailing spaces cut
	move.l	a0,a3
	moveq	#20,d0
.t:	cmp.b	#' ',CARGO_NAME(a3,d0.w)
	bne.s	.tc
	subq.w	#1,d0
	bra.s	.t
.tc:	move.w	d0,d4
	lea	ct2_s,a0		; 'Jettison ' + s + '?'
	lea	ct2_t_jett,a1
	bsr	pstr_cpy
	move.w	d4,d0
	lea	ct2_s2,a0
	move.b	d0,(a0)+
	lea	CARGO_NAME+1(a3),a1
	bra.s	.ce
.cl:	move.b	(a1)+,(a0)+
.ce:	dbf	d0,.cl
	lea	ct2_s,a0
	lea	ct2_s2,a1
	bsr	pstr_cat
	lea	ct2_s,a0
	lea	ct2_t_qm,a1
	bsr	pstr_cat
	move.w	#31,ct2_reqtext
	lea	ct2_s,a0
	moveq	#0,d0
	moveq	#31,d1
	bsr	ct2_request
	move.w	d0,ct2_j		; (j is the unit's)
	lea	GS_SHIP+SHIP_NUMCARGO-2(a6),a0
	move.w	d3,d1
	add.w	d1,d1
	add.w	d1,a0
	cmp.w	#1,d0
	beq.s	.all
	cmp.w	#2,d0
	beq.s	.half
	cmp.w	#3,d0
	bne.s	.b0
	cmp.w	#1,(a0)			; One
	bne.s	.one
.all:	clr.w	(a0)
.gone:	clr.w	SHIP_CARGO-SHIP_NUMCARGO(a0)
	move.w	d3,d0
	bsr	ct2_revnewcursor
	tst.w	ct2_index
	bgt.s	.b0
	moveq	#1,d0
	bsr	ct2_newcursor
	bra.s	.b0
.half:	move.w	(a0),d0			; dec(numcargo, numcargo div 2)
	lsr.w	#1,d0
	sub.w	d0,(a0)
	tst.w	(a0)
	beq.s	.gone
	bra.s	.b0
.one:	subq.w	#1,(a0)
.b0:	BKCOL	0
	bra.s	.x
.vital:	lea	ct2_t_vital1,a0
	lea	ct2_t_vital2,a1
	bra.s	.box
.need:	lea	ct2_t_need1,a0
	lea	ct2_t_need2,a1
.box:	lea	GS_SHIP+SHIP_OPTIONS+OPT_MSGS-1(a6),a2	; printbigbox with the messages option forced to 2
	move.b	(a2),-(sp)
	move.b	#2,(a2)
	bsr	printbigbox
	move.b	(sp)+,GS_SHIP+SHIP_OPTIONS+OPT_MSGS-1(a6)
.x:	movem.l	(sp)+,d3-d4/a3
	rts

; findcargcursor: the cursor moves by the clicked line
ct2_findcargcursor:
	move.l	d3,-(sp)
	bsr	kbd_mouse_xy
	move.w	d1,d3
	sub.w	#22,d3
	ext.l	d3
	tst.w	ct2_mode_
	bne.s	.i
	divs	#6,d3
	subq.w	#6,d3
	bra.s	.y
.i:	divs	#20,d3
.y:	move.w	d3,GS_Y(a6)
	beq.s	.x
.dn:	tst.w	GS_Y(a6)
	ble.s	.up
	cmp.w	#251,ct2_index
	bge.s	.up
	move.w	ct2_index,d0
	bsr	ct2_newcursor
	subq.w	#1,GS_Y(a6)
	bra.s	.dn
.up:	tst.w	GS_Y(a6)
	bge.s	.e
	tst.w	ct2_index
	ble.s	.e
	move.w	ct2_index,d0
	bsr	ct2_revnewcursor
	addq.w	#1,GS_Y(a6)
	bra.s	.up
.e:	cmp.w	#250,ct2_index
	ble.s	.e2
	move.w	#251,d0
	bsr	ct2_revnewcursor
.e2:	tst.w	ct2_index
	bgt.s	.x
	moveq	#0,d0
	bsr	ct2_newcursor
.x:	move.l	(sp)+,d3
	rts

ct2_togglef:				; filters2[d0] := 1 - it; newcursor(d1); drawfilters
	lea	ct2_filters2-1,a0
	eor.b	#1,0(a0,d0.w)
	move.w	d1,d0
	bsr	ct2_newcursor
	bra	ct2_drawfilters
ct2_cleanlist:				; rows 22..106, x 90..229 := 0
	movem.l	d3-d4,-(sp)
	moveq	#90,d0
	moveq	#22,d1
	move.w	#229,d2
	moveq	#106,d3
	moveq	#0,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
	rts
ct2_togglemode:
	eor.w	#1,ct2_mode_
	bsr	ct2_cleanlist
	moveq	#0,d0
	bra	ct2_newcursor
ct2_up:
	cmp.w	#1,ct2_index
	ble.s	.w
	move.w	ct2_index,d0
	bsr	ct2_revnewcursor
	bra.s	.c
.w:	move.w	#251,d0
	bsr	ct2_revnewcursor
.c:	tst.w	ct2_index
	bne.s	.x
	moveq	#0,d0
	bsr	ct2_newcursor
.x:	rts
ct2_down:
	move.w	ct2_index,d0
	bsr	ct2_newcursor
	cmp.w	#251,ct2_index
	bne.s	.x
	move.w	#251,d0
	bsr	ct2_revnewcursor
.x:	rts

; after a click / key: index > 250 -> 0 and the list cleared; redraw the view
ct2_after:
	cmp.w	#250,ct2_index
	ble.s	.d
	clr.w	ct2_index
	bsr	mousehide
	bsr	ct2_cleanlist
	bsr	mouseshow
.d:	tst.w	ct2_mode_
	bne.s	.i
	bsr	ct2_displaylist
	bra.s	.x
.i:	bsr	ct2_displayinfo
.x:	clr.w	GS_IDLETIME(a6)
	rts

ct2_findmouse:
	movem.l	d3-d4,-(sp)
	bsr	kbd_mouse_status
	tst.b	d0
	beq	.x
	bsr	kbd_mouse_xy
	move.w	d0,d3
	move.w	d1,d4
	lea	.reg,a0			; the column: 0-6, or none
	moveq	#0,d2
.rg:	move.w	(a0)+,d0
	bmi	.af
	move.w	(a0)+,d1
	cmp.w	d0,d3
	blt	.af
	cmp.w	d1,d3
	ble.s	.hit
	addq.w	#1,d2
	bra.s	.rg
.hit:	cmp.w	#6,d2			; 236..250: print the cargo
	bne.s	.lst
	cmp.w	#71,d4
	ble	.af
	cmp.w	#91,d4
	bge	.af
	lea	ct2_t_print,a0
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq	.af
	bsr	printcargo
	bra	.af
.lst:	cmp.w	#22,d4			; 22..106: the list
	blt	.af
	cmp.w	#106,d4
	bgt.s	.btn
	bsr	ct2_findcargcursor
	bra	.af
.btn:	cmp.w	#110,d4
	blt	.af
	cmp.w	#126,d4
	bgt	.af
	add.w	d2,d2
	move.w	.jt(pc,d2.w),d2
	jmp	.jt(pc,d2.w)
.jt:	dc.w	.c0-.jt,.c1-.jt,.c2-.jt,.c3-.jt,.c4-.jt,.c5-.jt
.c0:	st	GS_DONE(a6)		; 94..102: done
	bra.s	.af
.c1:	bsr	ct2_dropit		; 104..113: drop
	bra.s	.af
.c2:	moveq	#1,d0			; 115..159: filters 1 / 2
	bra.s	.f
.c3:	moveq	#3,d0			; 161..204: filters 3 / 4
.f:	cmp.w	#117,d4
	ble.s	.f1
	cmp.w	#119,d4
	blt.s	.af
	addq.w	#1,d0
.f1:	moveq	#0,d1
	bsr	ct2_togglef
	bra.s	.af
.c4:	bsr	ct2_togglemode		; 206..215: list / info
	bra.s	.af
.c5:	cmp.w	#117,d4			; 217..226: up / down
	bgt.s	.c6
	bsr	ct2_up
	bra.s	.af
.c6:	cmp.w	#119,d4
	blt.s	.af
	bsr	ct2_down
.af:	bsr	ct2_after
.x:	movem.l	(sp)+,d3-d4
	rts
.reg:	dc.w	94,102,104,113,115,159,161,204,206,215,217,226,236,250,-1

ct2_processkey:
	bsr	kbd_readkey
	tst.b	d0
	beq.s	.ext
	cmp.b	#'a',d0
	blo.s	.u
	cmp.b	#'z',d0
	bhi.s	.u
	sub.b	#32,d0
.u:	cmp.b	#27,d0
	beq.s	.dn
	cmp.b	#'Q',d0
	bne.s	.n1
.dn:	st	GS_DONE(a6)
	bra	.af
.n1:	cmp.b	#'1',d0
	blt.s	.n2
	cmp.b	#'4',d0
	bgt.s	.n2
	sub.b	#'0',d0
	ext.w	d0
	moveq	#1,d1
	bsr	ct2_togglef
	bra.s	.af
.n2:	cmp.b	#'D',d0
	bne.s	.n3
	bsr	ct2_dropit
	bra.s	.af
.n3:	cmp.b	#'`',d0			; bossmode
	bne.s	.n3b
	bsr	bossmode
	bra	.af
.n3b:	cmp.b	#'/',d0			; (#10 heap stats: not on the ST)
	beq.s	.m
	cmp.b	#'?',d0
	bne.s	.af
.m:	bsr	ct2_togglemode
	bra.s	.af
.ext:	bsr	kbd_readkey
	cmp.b	#72,d0
	bne.s	.e1
	bsr	ct2_up
	bra.s	.af
.e1:	cmp.b	#80,d0
	bne.s	.e2
	bsr	ct2_down
	bra.s	.af
.e2:	cmp.b	#81,d0
	bne.s	.e3
	moveq	#98,d1
	bra.s	.mv
.e3:	cmp.b	#73,d0
	bne.s	.af
	moveq	#22,d1
.mv:	move.w	d1,-(sp)		; move_mouse(mouse.x, y); findcargcursor
	bsr	kbd_mouse_xy
	move.w	(sp)+,d1
	bsr	kbd_mouse_move
	bsr	ct2_findcargcursor
.af:	bra	ct2_after

; animation: the light chases round 232..239; noise in the box at 240..246 x 77..78
ct2_animation:
	movem.l	d3-d4,-(sp)
	move.w	GS_LIGHTINDEX(a6),d0	; setrgb256(lightindex, 0, 0, 0)
	moveq	#0,d1
	moveq	#0,d2
	moveq	#0,d3
	bsr	vid_setrgb
	addq.w	#1,GS_LIGHTINDEX(a6)
	cmp.w	#240,GS_LIGHTINDEX(a6)
	bne.s	.l
	move.w	#232,GS_LIGHTINDEX(a6)
.l:	move.w	GS_LIGHTINDEX(a6),d0	; setrgb256(lightindex, 0, 0, 48)
	moveq	#0,d1
	moveq	#0,d2
	moveq	#48,d3
	bsr	vid_setrgb
	bsr	mousehide
	moveq	#77,d3
.r:	move.w	#240,d4
.c:	moveq	#2,d0
	bsr	mt_random
	moveq	#0,d2
	tst.w	d0
	bne.s	.p
	moveq	#63,d2
.p:	move.w	d4,d0
	move.w	d3,d1
	bsr	ms_pset
	addq.w	#1,d4
	cmp.w	#246,d4
	ble.s	.c
	addq.w	#1,d3
	cmp.w	#78,d3
	ble.s	.r
	bsr	mouseshow
	movem.l	(sp)+,d3-d4
	rts

ct2_mainloop:
.l:	moveq	#8,d0			; fadestep(FADESTEP_STEP)
	bsr	fadestep
	bsr	ct2_findmouse
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	ct2_processkey
.nk:	addq.w	#1,GS_IDLETIME(a6)
	cmp.w	#MAXIDLE,GS_IDLETIME(a6)
	bne.s	.ni
	bsr	screensaver
.ni:	bsr	ct2_animation
	cmp.w	#8,GS_BATINDEX(a6)
	bge.s	.b0
	addq.w	#1,GS_BATINDEX(a6)
	bra.s	.dl
.b0:	clr.w	GS_BATINDEX(a6)
	bsr	addtime2
	tst.w	ct2_mode_
	bne.s	.i
	bsr	ct2_displaylist
	bra.s	.dl
.i:	bsr	ct2_displayinfo
.dl:	move.w	GS_TSLICE(a6),d0	; delay(tslice*FADE_TSLICE_MUL_CARGTOOL)
	mulu	#FADE_MUL_CARGTOOL,d0
	bsr	delay
	tst.b	GS_DONE(a6)
	beq.s	.l
	rts

; removedata (cargtool's: quickloadscreen, no loadscreen dump; the bots panel)
ct2_removedata:
	bsr	mousehide
	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	moveq	#3,d0			; mouse.setmousecursor(random(3))
	bsr	mt_random
	bsr	setmousecursor
	moveq	#0,d0			; quickloadscreen(current)
	bsr	ms_unsnap
	bsr	showresearchlights
	move.w	#3,GS_BKCOLOR(a6)
	moveq	#0,d0
	bsr	displaytextbox
	move.w	#25,GS_TEXTINDEX(a6)
	cmp.w	#11,GS_VIEWMODE(a6)
	bne.s	.n
	cmp.w	#2,GS_VIEWLEVEL(a6)
	bne.s	.n
	moveq	#6,d0
	bsr	displaybotinfo
.n:	bsr	mouseshow
	st	GS_ANYCHANGE(a6)
	move.l	GS_OLDT1(a6),GS_T1(a6)
	move.l	GS_OLDT1+4(a6),GS_T1+4(a6)
	rts

inventory:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	ct2_readydata
	bsr	ct2_displaylist
	bsr	ct2_mainloop
	bsr	ct2_closedoors
	bsr	ct2_removedata
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; ---------------------------------------------------------------- creation
	include	"cargtool2.s"

	section	data
ct2_mode:	dc.b	"CARGO",0
ct2_fn_cargo:	dc.b	"SOUND",92,"CARGO.MOD",0
ct2_t_5sp:	dc.b	5,"     "
ct2_t_lp:	dc.b	1,"("
ct2_t_rp:	dc.b	1,")"
ct2_t_type:	dc.b	6,"Type: "
ct2_t_size:	dc.b	5,"Size:"
ct2_t_num:	dc.b	4,"Num:"
ct2_t_types:				; 10 bytes each (string[9])
	dc.b	9,"Weapon   "
	dc.b	9,"Shield   "
	dc.b	9,"Device   "
	dc.b	9,"Component"
	dc.b	9,"Material "
	dc.b	9,"Artifact "
	dc.b	9,"         "
ct2_t_jett:	dc.b	9,"Jettison "
ct2_t_qm:	dc.b	1,"?"
ct2_t_print:	dc.b	12,"PRINT CARGO?"
ct2_t_vital1:	dc.b	22,"That item is too vital"
ct2_t_vital2:	dc.b	12,"to jettison!"
ct2_t_need1:	dc.b	20,"Can't jettison that!"
ct2_t_need2:	dc.b	25,"It's needed for building."
	even
ct2_filters2:	dc.b	1,1,1,1		; (the unit's initialisation)
	even
	section	bss
ct2_res2:	ds.w	250
ct2_buttons:	ds.b	17*136
ct2_index:	ds.w	1		; cargoindex
ct2_mode_:	ds.w	1		; cargomode
ct2_teamjob:	ds.w	1
ct2_j:		ds.w	1
ct2_reqtext:	ds.w	1
ct2_lastx:	ds.w	1
ct2_lasty:	ds.w	1
ct2_cursor:	ds.w	1
ct2_s:		ds.b	256
ct2_s2:		ds.b	256
ct2_bg:		ds.b	1
ct2_done2:	ds.b	1
ct2_button:	ds.b	1
	even
	section	text
