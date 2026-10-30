; usecode2.s - the rest of usecode.pas for MAIN.PRG: the right-hand panels' openers, the
; viewscreen maps (star map, history, scans) and their removal, targeting and engage, shields and
; weapons (arm, raise, lower, power down: the grey palette fades), the time burst (restcrew,
; checkrandommonster), and utils.pas showpanel / genericrightside / sprinkle2.
; (all trash d0-d2/a0-a2)

	section	text
; ---------------------------------------------------------------- utils.pas
; showpanel(buttons d0, d1, d2): the five fixed icons 54-58 and the three buttons at the top right
showpanel:
	movem.l	d3-d5/a3,-(sp)
	movem.w	d0-d2,u3_but
	bsr	mousehide
	moveq	#1,d3			; for a := 1 to 5: icons^[53+a] at x 137+a*17
.a:	move.w	d3,d0
	add.w	#53,d0
	move.w	d3,d1
	mulu	#17,d1
	add.w	#137,d1
	bsr	.icon
	addq.w	#1,d3
	cmp.w	#6,d3
	bne.s	.a
	moveq	#0,d3			; for a := 0 to 2: icons^[53+buttons[a]] at x 239+a*17
.b:	move.w	d3,d0
	add.w	d0,d0
	lea	u3_but,a0
	move.w	0(a0,d0.w),d0
	add.w	#53,d0
	move.w	d3,d1
	mulu	#17,d1
	add.w	#239,d1
	bsr	.icon
	addq.w	#1,d3
	cmp.w	#3,d3
	bne.s	.b
	st	GS_PANELON(a6)
	bsr	mouseshow
	movem.l	(sp)+,d3-d5/a3
	rts
.icon:	mulu	#255,d0			; screen[i+9, j+x] := icons^[n, j, i] (17 x 15)
	move.l	GS_ICONS(a6),a3
	add.l	d0,a3
	move.w	d1,d5
	moveq	#9,d1
	move.w	d5,d0
	bsr	ms_addr
	moveq	#0,d4			; j
.j:	move.l	a0,a1
	moveq	#15-1,d2
.i:	move.b	(a3)+,(a1)
	lea	MS_W(a1),a1
	dbf	d2,.i
	addq.l	#1,a0
	addq.w	#1,d4
	cmp.w	#17,d4
	bne.s	.j
	move.w	d5,d0
	moveq	#9,d1
	move.w	d5,d2
	add.w	#16,d2
	move.l	d3,-(sp)
	moveq	#23,d3
	bsr	ms_dirty
	move.l	(sp)+,d3
	rts

; genericrightside(buttons d0, d1, d2)
genericrightside:
	movem.l	d3-d4,-(sp)
	bsr	showpanel
	bsr	mousehide
	moveq	#5-1,d3
.f:	FADE	165,25,279,117,1
	DELAYTS	2
	dbf	d3,.f
	bsr	us_panel
	bsr	mouseshow
	movem.l	(sp)+,d3-d4
	rts

; utils.pas sprinkle2(x1 d0, y1 d1, x2 d2, y2 d3, seed d4): as sprinkle, but inside the
; viewscreen (28..147 x 13..133) the pixels come from the planet
sprinkle2:				; (usecode.s us_sprinkle: utils.pas sprinkle2)
	st	us_sp2
	bra	us_sprinkle

; ---------------------------------------------------------------- the panels' openers
readyoptions:
	SHOWPANEL_GR 21,20,12
	move.w	#1,GS_VIEWINDEX(a6)
	move.w	#1,GS_VIEWLEVEL(a6)
	move.w	#6,GS_VIEWMODE(a6)
	bsr	mousehide
	TCOL	191
	BKCOL	5
	PXY	168,27,"General Game Options"
	PXY	183,37,"Probes"		; (the original: 'Screen Saver' - see OPT_PROBES)
	PXY	173,45,"Time Slice"
	PXY	186,53,"Sound"
	PXY	173,61,"Difficulty"
	PXY	168,69,"General Msgs"
	PXY	175,77,"Animation"
	PXY	173,85,"Font Style"
	PXY	175,93,"Auto-Save"
	PXY	183,101,"Volume"
	PXY	186,109,"Stars"		; (6m) ten rows 8 lines apart (the original: nine, 9 apart)
	LINE	238,36,238,116,2
	LINE	239,36,239,116,10
	PSET	238,36,6
	PSET	239,117,6
	bsr	mouseshow
	moveq	#0,d0
	bra	displayoptions

readydamagecontrol:
	SHOWPANEL_GR 17,18,19
	move.w	#1,GS_VIEWINDEX(a6)
	move.w	#2,GS_VIEWLEVEL(a6)
	move.w	#5,GS_VIEWMODE(a6)
	moveq	#1,d0
	bra	displaydamagecontrol

readyconfigure:
	bsr	mousehide
	GRAYB	15,25,279,115
	RGRAYB	59,32,234,108
	bsr	mouseshow
	move.w	#1,GS_VIEWLEVEL(a6)
	move.w	#10,GS_VIEWMODE(a6)
	moveq	#1,d0
	cmp.b	#SHPTYPE_HEAVY,GS_SHIP+SHIP_SHIPTYPE(a6)
	bne.s	.v
	moveq	#2,d0
.v:	move.w	d0,GS_VIEWINDEX(a6)
	moveq	#6,d0
	bra	displayconfigure

readybots:
	tst.b	GS_SHOWPLANET(a6)
	bne.s	.p
	TCOL	94
	PRTLN
	PRT	"ENGINEERING: Not near a planet."
	rts
.p:	sf	d0
	bsr	cleanright
	SHOWPANEL_GR 14,15,16
	TCOL	191
	BKCOL	5
	bsr	mousehide
	PXY	183,27,"Cache Contents"
	bsr	mouseshow
	clr.w	GS_VIEWLEVEL(a6)
	move.w	#11,GS_VIEWMODE(a6)
	move.w	GS_CURPLAN(a6),d0	; the first used cache slot (8: none -> 0)
	mulu	#PLANET_SIZEOF,d0
	move.l	GS_TEMPPLAN(a6),a0
	lea	-PLANET_SIZEOF+PLANET_CACHE(a0,d0.l),a0
	moveq	#1,d0
.c:	tst.w	(a0)+
	bne.s	.f
	addq.w	#1,d0
	cmp.w	#8,d0
	blt.s	.c
	moveq	#0,d0
.f:	move.w	d0,GS_VIEWINDEX(a6)
	moveq	#0,d0
	bra	displaybotinfo

readyshieldopts:
	SHOWPANEL_GR 9,12,12
	move.w	#1,GS_VIEWLEVEL(a6)
	move.w	#1,GS_VIEWINDEX(a6)
	move.w	#4,GS_VIEWMODE(a6)
	moveq	#6,d0
	bra	displayshieldopts

readyweaponinfo:
	lea	GS_SHIP+SHIP_GUNNODES(a6),a0	; any weapons?
	moveq	#10-1,d0
.g:	tst.b	(a0)+
	bne.s	.yes
	dbf	d0,.g
	bsr	removepanel
	TCOL	94
	PRTLN
	PRT	"SECURITY: No weapons installed."
	rts
.yes:	SHOWPANEL_GR 12,12,12
	clr.w	GS_VIEWLEVEL(a6)
	lea	GS_SHIP+SHIP_GUNNODES(a6),a0
	moveq	#1,d0
.v:	tst.b	(a0)+
	bne.s	.vf
	addq.w	#1,d0
	cmp.w	#11,d0
	blt.s	.v
	moveq	#0,d0
.vf:	move.w	d0,GS_VIEWINDEX(a6)
	move.w	#2,GS_VIEWMODE(a6)
	TCOL	191
	BKCOL	5
	PXY	168,27,"Gun Node Information"
	moveq	#0,d0
	bra	displayweaponinfo

readysysteminfo:
	SHOWPANEL_GR 24,13,26
	move.w	#1,GS_VIEWLEVEL(a6)
	move.w	#3,GS_VIEWMODE(a6)
	moveq	#1,d0
	bra	displaysysteminfo

readylogs:
	SHOWPANEL_GR 23,25,6
	clr.w	GS_VIEWLEVEL(a6)
	move.w	#7,GS_VIEWMODE(a6)
	move.w	#1,GS_VIEWINDEX(a6)
	clr.w	GS_VIEWINDEX3(a6)
	tst.b	GS_SHOWPLANET(a6)
	beq.s	.v
	move.w	GS_CURPLAN(a6),d0
	bsr	dp_plan
	moveq	#0,d0
	move.b	PLANET_SYSTEM(a0),d0
	move.w	d0,GS_VIEWINDEX(a6)
	bra.s	.t
.v:	move.w	#1,d1			; the first visited system (251: none -> 0)
.vl:	move.w	d1,d0
	bsr	dp_sys
	tst.w	SYSTEM_VISITS(a0)
	bne.s	.vf
	addq.w	#1,d1
	cmp.w	#251,d1
	blt.s	.vl
	moveq	#0,d1
.vf:	move.w	d1,GS_VIEWINDEX(a6)
.t:	BKCOL	5
	TCOL	191
	PXY	166,27," Ship Logs: Systems  "
	moveq	#0,d0
	bra	displaylogs

readyshipinfo:
	movem.l	d3,-(sp)
	bsr	mousehide
	GRAYB	15,25,279,115
	RGRAYB	16,26,191,102
	RGRAYB	196,83,274,112
	LINE	220,26,220,75,2
	LINE	191,75,278,75,2
	LINE	221,26,221,75,10
	LINE	192,76,279,76,10
	PSET	191,75,6
	PSET	279,76,6
	PSET	221,75,6
	move.w	#9,GS_VIEWMODE(a6)
	moveq	#17,d0
	moveq	#27,d1
	bsr	displayship2
	TCOL	191
	BKCOL	5
	lea	u3_s,a0			; 'Model:' + the three type names
	lea	u3_t_model,a1
	bsr	pstr_cpy
	moveq	#0,d0
	move.b	GS_SHIP+SHIP_SHIPTYPE(a6),d0
	subq.w	#1,d0
	bsr	.name
	lea	u3_s,a0
	lea	dp_t_space,a1
	bsr	pstr_cat
	moveq	#2,d0
	add.b	GS_SHIP+SHIP_SHIPTYPE+1(a6),d0
	bsr	.name
	lea	u3_s,a0
	lea	dp_t_space,a1
	bsr	pstr_cat
	moveq	#5,d0
	add.b	GS_SHIP+SHIP_SHIPTYPE+2(a6),d0
	bsr	.name
	PXYS	13,106,u3_s
	PXY	189,26,"X Loc"
	PXY	189,32,"Y Loc"
	PXY	189,38,"Z Loc"
	PXY	192,44,"Hull"
	PXY	192,50,"Fuel"
	PXY	192,56,"Batt"
	PXY	189,62,"Cargo"
	PXY	189,68,"Accel"
	PXY	216,76,"Damage"
	bsr	mouseshow
	movem.l	(sp)+,d3
	bra	displayshipinfo
.name:	ext.w	d0			; shipnames[d0] appended
	mulu	#10,d0
	lea	u3_shipnames,a1
	add.w	d0,a1
	lea	u3_s,a0
	bra	pstr_cat

; usecode.pas readysystem: the system view (viewmode 8)
readysystem:
	movem.l	d3,-(sp)
	clr.w	GS_VIEWINDEX2(a6)
	move.w	#142,GS_CX(a6)
	move.w	#65,GS_CY(a6)
	bsr	jy_findhere		; the nearby slot of the system the ship is at
	move.w	d0,GS_VIEWINDEX2(a6)
	bne.s	.ok
	PRTLN
	TCOL	94
	PRT	"NAVIGATION: Not near a system."
	bra	.x
.ok:	sf	d0
	bsr	cleanright
	tst.w	GS_VIEWMODE2(a6)
	ble.s	.nm
	bsr	removestarmap
.nm:	bsr	mousehide
	GRAYB	15,25,279,115
	SHOWPANEL 13,22,27
	move.w	#8,GS_VIEWMODE(a6)
	move.w	GS_SHIP+SHIP_ORBITING(a6),GS_VIEWINDEX(a6)
	move.w	#2,GS_VIEWLEVEL(a6)
	move.w	GS_VIEWINDEX2(a6),d0	; viewindex2 := nearby[viewindex2].index
	bsr	dp_near
	move.w	NEARBY_INDEX(a0),GS_VIEWINDEX2(a6)
	TCOL	191
	BKCOL	5
	PXY	12,26,"System:"
	move.w	GS_VIEWINDEX2(a6),d0
	bsr	dp_sys
	moveq	#12,d0
	moveq	#32,d1
	bsr	printxy
	PXY	13,102,"Planet:"
	PXY	238,102,"Target:"
	moveq	#13,d0
	moveq	#108,d1
	move.w	GS_SHIP+SHIP_ORBITING(a6),d2
	move.w	GS_VIEWINDEX2(a6),d3
	bsr	printplanet
	move.w	#233,d0
	moveq	#108,d1
	move.w	GS_VIEWINDEX(a6),d2
	move.w	GS_VIEWINDEX2(a6),d3
	bsr	printplanet
	bsr	mouseshow
	moveq	#0,d0
	bsr	displaysystem
.x:	movem.l	(sp)+,d3
	rts

; usecode.pas removesystem(erase d0.b)
removesystem:
	movem.l	d3-d5,-(sp)
	move.b	d0,d5
	move.w	#15,d0
	moveq	#25,d1
	move.w	#280,d2
	moveq	#116,d3
	moveq	#19,d4
	tst.b	GS_SHOWPLANET(a6)
	beq.s	.s
	cmp.w	#3,GS_SPHERE(a6)
	beq.s	.s
	bsr	sprinkle2
	bra.s	.p
.s:	bsr	sprinkle
.p:	tst.b	GS_PANELON(a6)
	beq.s	.v
	tst.b	d5
	beq.s	.v
	bsr	removepanel
.v:	clr.w	GS_VIEWMODE(a6)
	clr.w	GS_GLOWINDEX(a6)
	movem.l	(sp)+,d3-d5
	rts

; ---------------------------------------------------------------- the viewscreen maps
; usecode.pas readystarmap(mode d0)
readystarmap:
	move.l	d3,-(sp)
	move.w	d0,d3
	bsr	mousehide
	LINE	146,39,146,96,0
	LINE	147,49,147,86,0
	LINE	148,59,148,76,0
	BAR	25,10,143,125,5
	LINE	25,9,145,9,10
	LINE	25,9,25,126,10
	LINE	26,10,144,10,9
	LINE	26,10,26,124,9
	LINE	145,9,145,126,1
	LINE	25,126,145,126,1
	LINE	144,10,144,125,2
	LINE	26,125,144,125,2
	LINE	27,124,143,124,5
	TCOL	191
	BKCOL	5
	cmp.w	#1,d3
	bne.s	.m2
	PXY	58,11,"Star Map"
	bra.s	.m
.m2:	cmp.w	#2,d3
	bne.s	.m3
	PXY	33,11,"Direction of Travel"
	bra.s	.m
.m3:	cmp.w	#3,d3
	bne.s	.m4
	PXY	40,11,"Short Range Scan"
	bra.s	.m
.m4:	cmp.w	#4,d3
	bne.s	.m
	PXY	43,11,"Long Range Scan"
.m:	BKCOL	3
	move.w	d3,GS_VIEWMODE2(a6)
	move.l	GS_STARMAPSCREEN(a6),a0	; fillchar(starmapscreen^, 12402, 5)
	move.w	#12402/2-1,d0
.f:	move.w	#$0505,(a0)+
	dbf	d0,.f
	bsr	mouseshow
	bsr	u3_t1_628
	move.l	(sp)+,d3
	rts
u3_t1_628:				; t1 := 6.28 (the extended constant, stored as a real)
	FLDX	gx_6_28
	FSTG	GS_T1
	rts

removestarmap:
	movem.l	d3-d4,-(sp)
	clr.w	GS_VIEWMODE2(a6)
	bsr	mousehide
	moveq	#5-1,d3
.f:	FADE	27,11,143,123,-1
	DELAYTS	2
	dbf	d3,.f
	tst.b	GS_SHOWPLANET(a6)
	beq.s	.s
	cmp.w	#3,GS_SPHERE(a6)
	beq.s	.s
	moveq	#24,d0
	moveq	#9,d1
	move.w	#148,d2
	move.w	#133,d3
	moveq	#13,d4
	bsr	sprinkle2
	bra.s	.p
.s:	moveq	#24,d0
	moveq	#9,d1
	move.w	#149,d2
	moveq	#126,d3
	moveq	#17,d4
	bsr	sprinkle
.p:	bsr	mouseshow
	clr.w	GS_GLOWINDEX(a6)
	movem.l	(sp)+,d3-d4
	rts

; usecode.pas readyhistory: the nearby systems sorted by the date of the last visit
readyhistory:
	movem.l	d3-d5/a3-a4,-(sp)
	moveq	#1,d3			; j
.j:	move.w	d3,d4			; i := j .. nearbymax
.i:	move.w	d3,d0
	bsr	dp_near
	move.l	a0,a3			; nearby[j]
	move.w	d4,d0
	bsr	dp_near
	move.l	a0,a4			; nearby[i]
	tst.w	NEARBY_INDEX(a4)
	beq.s	.n
	tst.w	NEARBY_INDEX(a3)
	beq.s	.sw
	move.w	NEARBY_INDEX(a4),d0
	bsr	dp_sys
	move.w	SYSTEM_DATEY(a0),d5
	move.w	NEARBY_INDEX(a3),d0
	bsr	dp_sys
	cmp.w	SYSTEM_DATEY(a0),d5	; datey[i] < datey[j]
	bge.s	.n
.sw:	move.l	a3,a0			; swap nearby[i], nearby[j] and the backups
	move.l	a4,a1
	bsr	.swap
	lea	GS_NEARBYBACKUP-GS_NEARBY(a3),a0
	lea	GS_NEARBYBACKUP-GS_NEARBY(a4),a1
	bsr	.swap
.n:	addq.w	#1,d4
	cmp.w	#NEARBYMAX,d4
	ble.s	.i
	addq.w	#1,d3
	cmp.w	#NEARBYMAX,d3
	ble.s	.j
	moveq	#2,d0
	bsr	readystarmap
	bsr	u3_t1_628
	bsr	displayhistorymap
	st	GS_ANYCHANGE(a6)
	movem.l	(sp)+,d3-d5/a3-a4
	rts
.swap:	moveq	#NEARBY_SIZEOF/2-1,d0
.sl:	move.w	(a0),d1
	move.w	(a1),(a0)+
	move.w	d1,(a1)+
	dbf	d0,.sl
	rts

; usecode.pas readylongscan
readylongscan:
	movem.l	d3-d6,-(sp)
	bsr	mousehide
	moveq	#85,d0			; pieslice(85,86,0,360,40) in 0; circle(85,86,40) in 12
	moveq	#86,d1
	moveq	#40,d2
	moveq	#0,d4
	bsr	ms_disc
	moveq	#85,d0
	moveq	#86,d1
	moveq	#40,d2
	moveq	#12,d4
	bsr	ms_circle
	RGRAYB	35,24,135,44
	BAR	36,25,134,43,0
	move.w	GS_CURPLAN(a6),d0	; randseed := tempplan^[curplan].seed
	bsr	dp_plan
	moveq	#0,d0
	move.w	PLANET_SEED(a0),d0
	bsr	mt_seed
	tst.b	GS_SHOWPLANET(a6)
	beq	.dots
	bsr	u3_rang			; x1 := random(628)/100
	moveq	#20,d0			; i := random(20)+8
	bsr	mt_random
	addq.w	#8,d0
	move.w	d0,u3_i
	bsr	u3_cosi			; x := round(cos(x1)*i)+85; y := round(sin(x1)*i)+86
	add.w	#85,d0
	move.w	d0,GS_X(a6)
	bsr	u3_sini
	add.w	#86,d0
	move.w	d0,GS_Y(a6)
	moveq	#36-1,d3		; 36 dots around the planet
.p:	bsr	u3_rang
	moveq	#7,d0
	bsr	mt_random
	move.w	d0,u3_i
	bsr	u3_sini
	add.w	GS_Y(a6),d0
	move.w	d0,d5
	bsr	u3_cosi
	add.w	GS_X(a6),d0
	move.w	d0,d4
	moveq	#31,d0
	bsr	mt_random
	move.w	d0,d2
	move.w	d4,d0
	move.w	d5,d1
	bsr	ms_pset
	dbf	d3,.p
.dots:	moveq	#45,d0			; for j := 0 to random(45)+15: dots in the field
	bsr	mt_random
	add.w	#15,d0
	move.w	d0,d6
	moveq	#0,d3
.d:	bsr	u3_rang
	moveq	#35,d0
	bsr	mt_random
	move.w	d0,u3_i
	bsr	u3_sini
	add.w	#86,d0
	move.w	d0,d5
	bsr	u3_cosi
	add.w	#85,d0
	move.w	d0,d4
	moveq	#31,d0
	bsr	mt_random
	move.w	d0,d2
	move.w	d4,d0
	move.w	d5,d1
	bsr	ms_pset
	addq.w	#1,d3
	cmp.w	d6,d3
	ble.s	.d
	move.w	#135,GS_VIEWINDEX3(a6)
	bsr	mt_randomize
	move.l	GS_STARMAPSCREEN(a6),a1	; scrfrom_move(screen[i,27], starmapscreen^[i,27], 116)
	moveq	#27,d0
	moveq	#18,d1
	bsr	ms_addr
	moveq	#106-1,d1
.r:	moveq	#116-1,d0
	move.l	a0,a2
	move.l	a1,-(sp)
.c:	move.b	(a2)+,(a1)+
	dbf	d0,.c
	move.l	(sp)+,a1
	lea	117(a1),a1
	lea	MS_W(a0),a0
	dbf	d1,.r
	bsr	mouseshow
	movem.l	(sp)+,d3-d6
	bra	displaylongscan
u3_rang:				; x1 := random(628)/100 (SSE)
	move.w	#628,d0
	bsr	mt_random
	FSSE
	bsr	fp_ldw
	FLDI	100
	bsr	fp_div
	FSTG	GS_X1
	rts
u3_cosi:				; d0 := round(cos(x1)*i)  (x87)
	FLDG	GS_X1
	bsr	fp_cos
	bra.s	u3_muli
u3_sini:
	FLDG	GS_X1
	bsr	fp_sin
u3_muli:
	FX87
	move.w	u3_i,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	FSSE
	rts

; usecode.pas targetstar(tarx d0, tary d1): the star map's click
targetstar:
	movem.l	d3-d5,-(sp)
	move.w	d0,d4
	move.w	d1,d5
	sf	GS_TARGETREADY(a6)
	clr.w	GS_TARGET(a6)
	moveq	#1,d3
.j:	move.w	d3,d0
	bsr	dp_near
	tst.w	NEARBY_INDEX(a0)
	beq.s	.n
	bsr	dp_project
	sub.w	d4,d0
	bpl.s	.a
	neg.w	d0
.a:	cmp.w	#8,d0
	bge.s	.n
	sub.w	d5,d1
	bpl.s	.b
	neg.w	d1
.b:	cmp.w	#8,d1
	bge.s	.n
	move.w	d3,GS_TARGET(a6)
	bra.s	.f
.n:	addq.w	#1,d3
	cmp.w	#NEARBYMAX,d3
	ble.s	.j
.f:	cmp.w	#3,GS_VIEWMODE(a6)
	bne.s	.x
	moveq	#0,d0
	bsr	displaysysteminfo
.x:	movem.l	(sp)+,d3-d5
	rts

; the target's position on the side (x, y) and top (x+140, z) views: d0 = system x / y / z
; minus the ship's, then div 12 (truncating) + 82 (x) or + 70
u3_tpos:
	ext.l	d0
	divs	#12,d0
	rts
; a star's cross on the targeting views at (d0, d1): centre 31, arms 170
u3_cross:
	movem.l	d3-d4,-(sp)
	move.w	d0,d3
	move.w	d1,d4
	moveq	#31,d2
	bsr	ms_pset
	move.w	d3,d0
	move.w	d4,d1
	addq.w	#1,d1
	move.w	#170,d2
	bsr	ms_pset
	move.w	d3,d0
	move.w	d4,d1
	subq.w	#1,d1
	move.w	#170,d2
	bsr	ms_pset
	move.w	d3,d0
	addq.w	#1,d0
	move.w	d4,d1
	move.w	#170,d2
	bsr	ms_pset
	move.w	d3,d0
	subq.w	#1,d0
	move.w	d4,d1
	move.w	#170,d2
	bsr	ms_pset
	movem.l	(sp)+,d3-d4
	rts
; the ship's cross at (d0, 70): centre 94, arms 84
u3_shipcross:
	movem.l	d3,-(sp)
	move.w	d0,d3
	moveq	#70,d1
	moveq	#94,d2
	bsr	ms_pset
	move.w	d3,d0
	subq.w	#1,d0
	moveq	#70,d1
	moveq	#84,d2
	bsr	ms_pset
	move.w	d3,d0
	addq.w	#1,d0
	moveq	#70,d1
	moveq	#84,d2
	bsr	ms_pset
	move.w	d3,d0
	moveq	#69,d1
	moveq	#84,d2
	bsr	ms_pset
	move.w	d3,d0
	moveq	#71,d1
	moveq	#84,d2
	bsr	ms_pset
	movem.l	(sp)+,d3
	rts
; a0 := @systems[nearby[d0].index]
u3_nsys:
	bsr	dp_near
	move.w	NEARBY_INDEX(a0),d0
	bra	dp_sys

; usecode.pas plotstars: the nearby stars on the side (x,y) and top (x,z) views
plotstars:
	movem.l	d3-d5/a3,-(sp)
	moveq	#1,d3
.j:	move.w	d3,d0
	bsr	dp_near
	tst.w	NEARBY_INDEX(a0)
	beq.s	.n
	move.w	d3,d0
	bsr	u3_nsys
	move.l	a0,a3
	move.w	SYSTEM_X(a3),d0
	sub.w	GS_SHIP+SHIP_POSX(a6),d0
	bsr	u3_tpos
	add.w	#82,d0
	move.w	d0,d4
	move.w	SYSTEM_Y(a3),d0
	sub.w	GS_SHIP+SHIP_POSY(a6),d0
	bsr	u3_tpos
	add.w	#70,d0
	move.w	d0,d1
	move.w	d4,d0
	bsr	u3_cross
.n:	addq.w	#1,d3
	cmp.w	#NEARBYMAX,d3
	ble.s	.j
	moveq	#82,d0
	bsr	u3_shipcross
	moveq	#1,d3
.j2:	move.w	d3,d0
	bsr	dp_near
	tst.w	NEARBY_INDEX(a0)
	beq.s	.n2
	move.w	d3,d0
	bsr	u3_nsys
	move.l	a0,a3
	move.w	SYSTEM_X(a3),d0
	sub.w	GS_SHIP+SHIP_POSX(a6),d0
	bsr	u3_tpos
	add.w	#222,d0
	move.w	d0,d4
	move.w	SYSTEM_Z(a3),d0
	sub.w	GS_SHIP+SHIP_POSZ(a6),d0
	bsr	u3_tpos
	add.w	#70,d0
	move.w	d0,d1
	move.w	d4,d0
	bsr	u3_cross
.n2:	addq.w	#1,d3
	cmp.w	#NEARBYMAX,d3
	ble.s	.j2
	move.w	#222,d0
	bsr	u3_shipcross
	movem.l	(sp)+,d3-d5/a3
	rts

; the two vertical scan lines at 167+j and 27+j (rows 27-113) in colour d4 (xor mode as set)
u3_vlines:
	movem.l	d3-d4,-(sp)
	move.w	d0,-(sp)
	add.w	#167,d0
	moveq	#27,d1
	move.w	d0,d2
	moveq	#113,d3
	bsr	ms_line
	move.w	(sp)+,d0
	add.w	#27,d0
	moveq	#27,d1
	move.w	d0,d2
	moveq	#113,d3
	move.l	4(sp),d4
	bsr	ms_line
	movem.l	(sp)+,d3-d4
	rts

; usecode.pas removestars: a scan line sweeps both views, then a second one reveals the target
removestars:
	movem.l	d3-d6/a3,-(sp)
	st	ms_xor
	move.w	GS_TSLICE(a6),d6	; index := tslice div 8
	lsr.w	#3,d6
	move.w	#110,d3
.a:	move.w	d3,d0
	moveq	#120,d4
	bsr	u3_vlines
	move.w	d6,d0
	bsr	delay
	move.w	d3,d0
	moveq	#120,d4
	bsr	u3_vlines
	subq.w	#1,d3
	bne.s	.a
	sf	ms_xor
	move.w	GS_TARGET(a6),d0
	bsr	u3_nsys
	move.l	a0,a3
	moveq	#1,d3
.b:	move.w	d3,d0
	moveq	#118,d4
	bsr	u3_vlines
	move.w	d6,d0
	bsr	delay
	move.w	d3,d0
	moveq	#4,d4
	bsr	u3_vlines
	cmp.w	#56,d3
	bne.s	.n56
	moveq	#82,d0
	bsr	u3_shipcross
	move.w	#222,d0
	bsr	u3_shipcross
.n56:	move.w	SYSTEM_X(a3),d0		; the target appears when the line reaches it
	sub.w	GS_SHIP+SHIP_POSX(a6),d0
	bsr	u3_tpos
	add.w	#82,d0
	move.w	d0,d5
	move.w	d3,d1
	add.w	#26,d1
	cmp.w	d1,d5
	bne.s	.nt
	move.w	SYSTEM_Y(a3),d0
	sub.w	GS_SHIP+SHIP_POSY(a6),d0
	bsr	u3_tpos
	add.w	#70,d0
	move.w	d0,d1
	move.w	d5,d0
	bsr	u3_cross
	move.w	SYSTEM_Z(a3),d0
	sub.w	GS_SHIP+SHIP_POSZ(a6),d0
	bsr	u3_tpos
	add.w	#70,d0
	move.w	d0,d1
	move.w	d5,d0
	add.w	#140,d0
	bsr	u3_cross
.nt:	PXY	29,105,"Side"
	PXY	169,105,"Top"
	addq.w	#1,d3
	cmp.w	#111,d3
	bne	.b
	movem.l	(sp)+,d3-d6/a3
	rts

; usecode.pas setuptarget: cross hairs move to the target, blink, then the target's corners
setuptarget:
	movem.l	d3-d7/a3,-(sp)
	move.w	GS_TARGET(a6),d0
	bsr	u3_nsys
	move.l	a0,a3
	move.w	SYSTEM_X(a3),d0		; x1, x2, y1, y2
	sub.w	GS_SHIP+SHIP_POSX(a6),d0
	bsr	u3_tpos
	add.w	#82,d0
	move.w	d0,u3_x1
	add.w	#140,d0
	move.w	d0,u3_x2
	move.w	SYSTEM_Y(a3),d0
	sub.w	GS_SHIP+SHIP_POSY(a6),d0
	bsr	u3_tpos
	add.w	#70,d0
	move.w	d0,u3_y1
	move.w	SYSTEM_Z(a3),d0
	sub.w	GS_SHIP+SHIP_POSZ(a6),d0
	bsr	u3_tpos
	add.w	#70,d0
	move.w	d0,u3_y2
	moveq	#82,d4			; lx
	move.w	#222,d5			; rx
	moveq	#70,d6			; ly
	moveq	#70,d7			; ry
	st	ms_xor
.r:	moveq	#0,d3			; done
	cmp.w	u3_x2,d5
	bge.s	.r1
	addq.w	#1,d5
	bra.s	.r2
.r1:	ble.s	.r1e
	subq.w	#1,d5
	bra.s	.r2
.r1e:	addq.w	#1,d3
.r2:	cmp.w	u3_x1,d4
	bge.s	.l1
	addq.w	#1,d4
	bra.s	.l2
.l1:	ble.s	.l1e
	subq.w	#1,d4
	bra.s	.l2
.l1e:	addq.w	#1,d3
.l2:	cmp.w	u3_y2,d7
	bge.s	.y1
	addq.w	#1,d7
	bra.s	.y2
.y1:	ble.s	.y1e
	subq.w	#1,d7
	bra.s	.y2
.y1e:	addq.w	#1,d3
.y2:	cmp.w	u3_y1,d6
	bge.s	.z1
	addq.w	#1,d6
	bra.s	.z2
.z1:	ble.s	.z1e
	subq.w	#1,d6
	bra.s	.z2
.z1e:	addq.w	#1,d3
.z2:	bsr	.hairs
	move.w	GS_TSLICE(a6),d0	; delay(c), c = tslice*2
	add.w	d0,d0
	bsr	delay
	bsr	.hairs
	cmp.w	#4,d3
	bne	.r
	moveq	#10-1,d3		; blink 10 times
.bl:	bsr	.hairs
	DELAYTS	5
	dbf	d3,.bl
	moveq	#2-1,d3			; the corners, twice, closing in
.i:	moveq	#8,d4
.j:	moveq	#13,d0
	move.w	d4,d1
	mulu	#3,d1
	add.w	d1,d0
	bsr	.corners
	DELAYTS	4
	moveq	#4,d0
	bsr	.corners
	subq.w	#1,d4
	bne.s	.j
	dbf	d3,.i
	sf	ms_xor
	movem.l	(sp)+,d3-d7/a3
	rts
.hairs:	movem.l	d3-d4,-(sp)		; line(rx,..), line(lx,..), line(27,ly,137,ly), line(167,ry,277,ry)
	move.w	d4,-(sp)
	move.w	d5,d0
	moveq	#27,d1
	move.w	d5,d2
	moveq	#113,d3
	moveq	#120,d4
	bsr	ms_line
	move.w	(sp)+,d0
	moveq	#27,d1
	move.w	d0,d2
	moveq	#113,d3
	moveq	#120,d4
	bsr	ms_line
	moveq	#27,d0
	move.w	d6,d1
	move.w	#137,d2
	move.w	d6,d3
	moveq	#120,d4
	bsr	ms_line
	move.w	#167,d0
	move.w	d7,d1
	move.w	#277,d2
	move.w	d7,d3
	moveq	#120,d4
	bsr	ms_line
	movem.l	(sp)+,d3-d4
	rts
.corners:				; the 8 pixels at +-j around (x1,y1) and (x2,y2) := d0
	movem.l	d3/d5,-(sp)
	move.w	d0,d5
	move.w	u3_x1,d0
	move.w	u3_y1,d1
	bsr.s	.four
	move.w	u3_x2,d0
	move.w	u3_y2,d1
	bsr.s	.four
	movem.l	(sp)+,d3/d5
	rts
.four:	movem.w	d0-d1,-(sp)		; (y-j,x-j), (y+j,x-j), (y-j,x+j), (y+j,x+j)
	sub.w	d4,d0
	sub.w	d4,d1
	move.w	d5,d2
	bsr	ms_pset
	movem.w	(sp),d0-d1
	sub.w	d4,d0
	add.w	d4,d1
	move.w	d5,d2
	bsr	ms_pset
	movem.w	(sp),d0-d1
	add.w	d4,d0
	sub.w	d4,d1
	move.w	d5,d2
	bsr	ms_pset
	movem.w	(sp)+,d0-d1
	add.w	d4,d0
	add.w	d4,d1
	move.w	d5,d2
	bra	ms_pset

; usecode.pas readytarget
readytarget:
	movem.l	d3-d5,-(sp)
	tst.w	GS_TARGET(a6)
	bne.s	.go
	TCOL	94
	PRTLN
	PRT	"No target selected!"
	bra	.x
.go:	tst.w	GS_VIEWMODE2(a6)
	ble.s	.nm
	bsr	removestarmap
.nm:	st	d0
	bsr	cleanright
	PRTLN
	TCOL	31
	PRT	"Targeting.."
	bsr	mousehide
	moveq	#6-1,d3
.f:	FADE	167,26,277,113,1
	FADE	27,26,137,113,1
	DELAYTS	3
	dbf	d3,.f
	TCOL	31
	BKCOL	6
	PXY	29,105,"Side"
	PXY	169,105,"Top"
	bsr	plotstars
	DELAYTS	40
	BKCOL	4
	bsr	removestars
	DELAYTS	20
	bsr	setuptarget
	DELAYTS	40
	TCOL	31
	BKCOL	3
	PRT	"LOCKED"
	moveq	#24,d3			; restore rows 24-116: the background (and the planet)
.r:	move.w	d3,d5			; y := i+backgry; if y > 199 then y := y-199 (sic)
	add.w	GS_BACKGRY(a6),d5
	cmp.w	#199,d5
	ble.s	.ry
	sub.w	#199,d5
.ry:	moveq	#24,d4
.c1:	bsr	.bg			; columns 24-27
	addq.w	#1,d4
	cmp.w	#28,d4
	bne.s	.c1
	tst.b	GS_SHOWPLANET(a6)
	beq.s	.c2
	cmp.w	#3,GS_SPHERE(a6)
	beq.s	.c2
.cp:	move.w	d3,d0			; planet^[i-12, j-27]
	sub.w	#13,d0
	mulu	#120,d0
	add.w	d4,d0
	sub.w	#28,d0
	move.l	GS_PLANET(a6),a0
	move.b	0(a0,d0.l),d2
	move.w	d4,d0
	move.w	d3,d1
	bsr	ms_pset
	addq.w	#1,d4
	cmp.w	#142,d4
	bne.s	.cp
	bra.s	.c3
.c2:	bsr	.bg
	addq.w	#1,d4
	cmp.w	#142,d4
	bne.s	.c2
.c3:	addq.w	#1,d3
	cmp.w	#117,d3
	bne.s	.r
	moveq	#24,d3			; and columns 164-281
.r2:	move.w	d3,d5
	add.w	GS_BACKGRY(a6),d5
	cmp.w	#199,d5
	ble.s	.ry2
	sub.w	#199,d5
.ry2:	move.w	#164,d4
.c4:	bsr	.bg
	addq.w	#1,d4
	cmp.w	#282,d4
	bne.s	.c4
	addq.w	#1,d3
	cmp.w	#117,d3
	bne.s	.r2
	bsr	mouseshow
	st	GS_TARGETREADY(a6)
.x:	movem.l	(sp)+,d3-d5
	rts
.bg:	move.w	d4,d0			; screen[i,j] := backgr^[y, x], x := j+backgrx (-319 if > 319)
	add.w	GS_BACKGRX(a6),d0
	cmp.w	#319,d0
	ble.s	.bx
	sub.w	#319,d0
.bx:	move.w	d5,d1
	mulu	#320,d1
	add.w	d0,d1
	move.l	GS_BACKGR(a6),a0
	move.b	0(a0,d1.l),d2
	move.w	d4,d0
	move.w	d3,d1
	bra	ms_pset

; ---------------------------------------------------------------- shields and weapons
; graypalin / graypalout: 15 steps between colors and its grey (exact integer forms of the
; original's reals: grey = round of (30r+59g+11b)/100 with ties to even; a step round(d/15*b))
u3_grey:
	lea	GS_COLORS(a6),a0
	lea	u3_greypal,a1
	move.w	#256-1,d2
.c:	moveq	#0,d0
	move.b	(a0)+,d0
	mulu	#30,d0
	moveq	#0,d1
	move.b	(a0)+,d1
	mulu	#59,d1
	add.w	d1,d0
	moveq	#0,d1
	move.b	(a0)+,d1
	mulu	#11,d1
	add.w	d1,d0
	divu	#100,d0			; q, rem
	move.l	d0,d1
	swap	d1
	cmp.w	#50,d1
	blo.s	.r
	bhi.s	.u
	btst	#0,d0
	beq.s	.r
.u:	addq.w	#1,d0
.r:	move.b	d0,(a1)+
	move.b	d0,(a1)+
	move.b	d0,(a1)+
	dbf	d2,.c
	rts
; colors2 := from + round((to-from)/15*b) per component, b = d0; set256colors(colors2)
; a0 = from, a1 = to
u3_greystep:
	movem.l	d3-d5/a3,-(sp)
	move.w	d0,d5
	lea	u3_colors2,a2
	move.w	#768-1,d4
.c:	moveq	#0,d0
	move.b	(a0)+,d0
	moveq	#0,d1
	move.b	(a1)+,d1
	sub.w	d0,d1			; d
	muls	d5,d1			; d*b
	add.l	d1,d1
	add.l	#15,d1			; floor((2*d*b + 15) / 30)
	divs	#30,d1
	bpl.s	.p
	move.l	d1,d3
	swap	d3
	tst.w	d3
	beq.s	.p
	subq.w	#1,d1
.p:	add.b	d1,d0
	move.b	d0,(a2)+
	dbf	d4,.c
	lea	u3_colors2,a0
	bsr	set256colors
	movem.l	(sp)+,d3-d5/a3
	rts
graypalin:
	movem.l	d3,-(sp)
	bsr	u3_grey
	moveq	#1,d3
.b:	lea	GS_COLORS(a6),a0
	lea	u3_greypal,a1
	move.w	d3,d0
	bsr	u3_greystep
	DELAYTS	3
	addq.w	#1,d3
	cmp.w	#16,d3
	bne.s	.b
	movem.l	(sp)+,d3
	rts
graypalout:
	movem.l	d3,-(sp)
	bsr	u3_grey
	moveq	#1,d3
.b:	lea	u3_greypal,a0
	lea	GS_COLORS(a6),a1
	move.w	d3,d0
	bsr	u3_greystep
	DELAYTS	2
	addq.w	#1,d3
	cmp.w	#16,d3
	bne.s	.b
	lea	GS_COLORS(a6),a0
	bsr	set256colors
	movem.l	(sp)+,d3
	rts
; if viewmode = 1 then displaystatus else checkstats
u3_stat:
	cmp.w	#1,GS_VIEWMODE(a6)
	beq	displaystatus
	bra	checkstats

lowershields:
	cmp.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)
	ble.s	.x
	PRTLN
	TCOL	63
	PRT	"SECURITY: Lowering shields..."
	bsr	graypalin
	moveq	#ALRT_ALERT,d0
	moveq	#1,d1
	bsr	setalertmode
	bsr	u3_stat
	DELAYTS	3
	bsr	graypalout
	moveq	#0,d0
	move.b	GS_SHIP+SHIP_SHIELDOPT+SHLD_ALERT_WANT-1(a6),d0
	cmp.w	GS_SHIP+SHIP_SHIELDLEVEL(a6),d0
	bne.s	.x
	TCOL	63
	PRT	"Complete."
.x:	rts

raiseshields:
	PRTLN
	TCOL	94
	cmp.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)
	bgt.s	.s
	PRT	"SECURITY: No shield to raise."
	rts
.s:	moveq	#0,d0
	move.b	GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6),d0
	cmp.w	#59,d0
	ble.s	.u
	PRT	"Shield integrity compromised...needs repair."
	clr.w	GS_SHIP+SHIP_SHIELDLEVEL(a6)
	bra	u3_stat
.u:	cmp.w	#25,d0
	ble.s	.r
	PRT	"SECURITY: Shield unstable..."
	moveq	#40,d0
	bsr	mt_random
	add.w	#20,d0
	moveq	#0,d1
	move.b	GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6),d1
	cmp.w	d1,d0
	bge.s	.r
	PRT	"Failed to raise shield."
	clr.w	GS_SHIP+SHIP_SHIELDLEVEL(a6)
	bra	u3_stat
.r:	PRT	"SECURITY: Raising shields..."
	bsr	graypalin
	moveq	#ALRT_COMBAT,d0
	moveq	#1,d1
	bsr	setalertmode
	bsr	u3_stat
	DELAYTS	3
	bsr	graypalout
	bra	u3_ready
u3_ready:				; 'Ready.' / 'Combat mode activated.' / 'Crew standing by.'
	PRT	"Ready."
	PRTLN
	PRT	"Combat mode activated."
	PRTLN
	TCOL	31
	PRT	"Crew standing by."
	rts

powerdownweapons:
	movem.l	d3/a3,-(sp)
	tst.b	GS_SHIP+SHIP_ARMED(a6)
	beq.s	.x
	PRTLN
	sf	GS_SHIP+SHIP_ARMED(a6)
	TCOL	63
	PRT	"SECURITY: Powering down weapons..."
	bsr	graypalin
	moveq	#ALRT_ALERT,d0
	moveq	#0,d1
	bsr	setalertmode
	lea	GS_SHIP+SHIP_GUNNODES(a6),a3	; the weapons' energy back to the battery
	moveq	#10-1,d3
.g:	moveq	#0,d0
	move.b	(a3)+,d0
	beq.s	.n
	bsr	dp_weapon
	move.w	WEAPON_ENERGY(a0),d0
	add.w	d0,GS_SHIP+SHIP_BATTERY(a6)
	cmp.w	#32000,GS_SHIP+SHIP_BATTERY(a6)
	bgt.s	.c
	tst.w	GS_SHIP+SHIP_BATTERY(a6)
	bpl.s	.n
.c:	move.w	#32000,GS_SHIP+SHIP_BATTERY(a6)
.n:	dbf	d3,.g
	bsr	u3_stat
	DELAYTS	3
	bsr	graypalout
	PRT	"Complete."
.x:	movem.l	(sp)+,d3/a3
	rts

armweapons:
	movem.l	d3/a3,-(sp)
	TCOL	94
	PRTLN
	moveq	#0,d0
	move.b	GS_SHIP+SHIP_DAMAGES+DMG_WEAPONS-1(a6),d0
	cmp.w	#59,d0
	ble.s	.u
	PRT	"Weapon control compromised...needs repair"
	sf	GS_SHIP+SHIP_ARMED(a6)
	bsr	u3_stat
	bra	.x
.u:	cmp.w	#25,d0
	ble.s	.g0
	PRT	"SECURITY: Weapon control unstable..."
	moveq	#40,d0			; (the original tests the shield's damage here)
	bsr	mt_random
	add.w	#20,d0
	moveq	#0,d1
	move.b	GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6),d1
	cmp.w	d1,d0
	bge.s	.g0
	PRT	"Failed to arm weapons."
	sf	GS_SHIP+SHIP_ARMED(a6)
	bsr	u3_stat
	bra	.x
.g0:	lea	GS_SHIP+SHIP_GUNNODES(a6),a0
	moveq	#10-1,d0
.g:	tst.b	(a0)+
	bne.s	.arm
	dbf	d0,.g
	PRT	"SECURITY: No weapons installed!"
	bra	.x
.arm:	PRT	"SECURITY: Arming weapons..."
	bsr	graypalin
	moveq	#ALRT_COMBAT,d0
	moveq	#0,d1
	bsr	setalertmode
	st	GS_SHIP+SHIP_ARMED(a6)
	lea	GS_SHIP+SHIP_GUNNODES(a6),a3	; charge the weapons that the battery can
	moveq	#10-1,d3
.c:	moveq	#0,d0
	move.b	(a3)+,d0
	beq.s	.cn
	bsr	dp_weapon
	move.w	WEAPON_ENERGY(a0),d0
	cmp.w	GS_SHIP+SHIP_BATTERY(a6),d0
	bgt.s	.cn
	sub.w	d0,GS_SHIP+SHIP_BATTERY(a6)
.cn:	dbf	d3,.c
	tst.w	GS_SHIP+SHIP_BATTERY(a6)
	bpl.s	.ok
	sf	GS_SHIP+SHIP_ARMED(a6)
	TCOL	94
	PRTLN
	PRT	"COMPUTER: Secondary power failure...Weapons powering down..."
	clr.w	GS_SHIP+SHIP_SHIELDLEVEL(a6)
	clr.w	GS_SHIP+SHIP_BATTERY(a6)
	bra.s	.x
.ok:	bsr	u3_stat
	DELAYTS	3
	bsr	graypalout
	bsr	u3_ready
.x:	movem.l	(sp)+,d3/a3
	rts

; the panic button / 'P': arm and raise when below combat, else power down and lower
u3_panic:
	cmp.w	#ALRT_COMBAT,GS_ALERT(a6)
	bge.s	.d
	bsr	armweapons
	bra	raiseshields
.d:	bsr	powerdownweapons
	bra	lowershields

; ---------------------------------------------------------------- time and travel
; usecode.pas addlotstime(background d0.b, dayticks d1.b, t d2.w)
addlotstime:
	movem.l	d3-d5,-(sp)
	move.b	d0,d4
	move.b	d1,d5
	move.w	d2,d3
	move.w	GS_SHIP+SHIP_SHIELD(a6),d0	; a powered shield: battery -= round(energy*level/100)
	cmp.w	#ID_REFLECTIVEHULL,d0
	ble.s	.b
	sub.w	#ID_SHIELDS_OFFSET,d0
	bsr	dp_weapon
	FSSE
	move.w	WEAPON_ENERGY(a0),d0
	bsr	fp_ldw
	move.w	GS_SHIP+SHIP_SHIELDLEVEL(a6),d0
	bsr	fp_ldw
	bsr	fp_mul
	FLDI	100
	bsr	fp_div
	bsr	fp_rnd
	sub.w	d0,GS_SHIP+SHIP_BATTERY(a6)
.b:	cmp.w	#31960,GS_SHIP+SHIP_BATTERY(a6)
	bge.s	.bf
	add.w	#40,GS_SHIP+SHIP_BATTERY(a6)
	bra.s	.bn
.bf:	move.w	#32000,GS_SHIP+SHIP_BATTERY(a6)
.bn:	tst.w	GS_SHIP+SHIP_BATTERY(a6)
	bpl.s	.d
	TCOL	94
	PRTLN
	PRT	"COMPUTER: Secondary power failure...Shields powering down..."
	clr.w	GS_SHIP+SHIP_SHIELDLEVEL(a6)
	clr.w	GS_SHIP+SHIP_BATTERY(a6)
.d:	lea	GS_SHIP+SHIP_STARDATE(a6),a0	; stardate[5] += t; carries (20 per unit up)
	add.w	d3,8(a0)
	cmp.w	#99,8(a0)
	ble.s	.sh
	moveq	#0,d0
	move.w	8(a0),d0
	divu	#100,d0
	add.w	d0,6(a0)
	swap	d0
	move.w	d0,8(a0)
	cmp.w	#19,6(a0)
	ble.s	.sh
	tst.b	d5
	beq.s	.nd
	move.b	d4,d0
	bsr	ct_daytick
	lea	GS_SHIP+SHIP_STARDATE(a6),a0
.nd:	moveq	#0,d0			; [2] += [4] div 20; [4] := [4] mod 20
	move.w	6(a0),d0
	divu	#20,d0
	add.w	d0,2(a0)
	swap	d0
	move.w	d0,6(a0)
	cmp.w	#19,2(a0)
	ble.s	.sh
	moveq	#0,d0			; [1] += [2] div 20
	move.w	2(a0),d0
	divu	#20,d0
	add.w	d0,(a0)
	swap	d0
	move.w	d0,2(a0)
	cmp.w	#19,(a0)
	ble.s	.sh
	moveq	#0,d0			; [3] += [1] div 20
	move.w	(a0),d0
	divu	#20,d0
	add.w	d0,4(a0)
	swap	d0
	move.w	d0,(a0)
.sh:	bsr	mousehide
	bsr	showtime
	bsr	mouseshow
	st	GS_ANYCHANGE(a6)
	movem.l	(sp)+,d3-d5
	rts

; usecode.pas engage(x d0, y d1, z d2)
engage:
	movem.l	d3-d5,-(sp)
	movem.w	d0-d2,u3_xyz
	sf	d0
	bsr	checkweight
	beq	.x
	moveq	#11,d0
	bsr	chevent
	tst.w	d0
	bne.s	.ok
	TCOL	94
	PRTLN
	PRT	"SCIENCE: Sir, that would not be wise. I suggest we first scan this planet."
	bra	.x
.ok:	moveq	#21,d0
	bsr	event
	moveq	#22,d0
	bsr	event
	moveq	#26,d0
	bsr	event
	moveq	#27,d0
	bsr	event
	move.w	GS_CURPLAN(a6),d0
	bsr	dp_plan
	cmp.b	#33,PLANET_SYSTEM(a0)
	bne.s	.e
	moveq	#25,d0
	bsr	event
.e:	cmp.b	#25,GS_SHIP+SHIP_DAMAGES+DMG_ENGINES-1(a6)
	bls.s	.tr
	TCOL	94
	PRTLN
	PRT	"COMPUTER: Warning! Ship engines have sustained damage."
	PLEA	"Continue countdown?"
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq	.x
.tr:	tst.b	GS_TARGETREADY(a6)
	bne.s	.d
	TCOL	94
	PRTLN
	PRT	"NAVIGATION: No target computed!"
	bra	.x
.d:	movem.w	u3_xyz,d0-d2		; dist (SSE)
	sub.w	GS_SHIP+SHIP_POSX(a6),d0
	sub.w	GS_SHIP+SHIP_POSY(a6),d1
	sub.w	GS_SHIP+SHIP_POSZ(a6),d2
	bsr	dp_dist
	lea	u3_dist,a0
	bsr	fp_std
	lea	u3_dist,a0
	bsr	fp_ldd
	bsr	fp_rnd
	cmp.l	#10,d0
	bge.s	.d10
	FLDI	10
	lea	u3_dist,a0
	bsr	fp_std
.d10:	lea	u3_dist,a0
	bsr	fp_ldd
	bsr	fp_rnd
	move.w	GS_SHIP+SHIP_FUEL(a6),d1
	ext.l	d1
	cmp.l	d1,d0
	ble.s	.f
	PRTLN
	TCOL	94
	PRT	"NAVIGATION: Insufficient fuel!"
	bra	.x
.f:	sub.w	d0,GS_SHIP+SHIP_FUEL(a6)
	tst.w	GS_VIEWMODE2(a6)
	ble.s	.nm
	bsr	removestarmap
.nm:	st	d0
	bsr	cleanright
	TCOL	31
	moveq	#ALRT_ALERT,d0
	moveq	#1,d1
	bsr	setalertmode
	PRTLN
	PRT	"ENGINEERING: Engaging.."
	movem.w	u3_xyz,d0-d2
	bsr	redoscreen
	moveq	#ALRT_REST,d0
	moveq	#1,d1
	bsr	setalertmode
.x:	movem.l	(sp)+,d3-d5
	rts

; usecode.pas checkrandommonster: an alien ship may turn up (after a time burst)
checkrandommonster:
	cmp.w	#16000,GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6)
	blt.s	.x
	move.w	#200,d0			; i := random(200)
	bsr	mt_random
	cmp.w	#30,d0
	bgt.s	.r2
	moveq	#7,d0			; 0-30: scavengers
	move.w	#1007,d1
	bra.s	.alien
.r2:	cmp.w	#100,d0
	bgt.s	.x
	moveq	#10,d0			; 31-100: a random alien (not 8)
	bsr	mt_random
	addq.w	#1,d0
	cmp.w	#8,d0
	beq.s	.x
	move.w	d0,d1
	add.w	#1000,d1
.alien:	bsr	getspecial
	bsr	addtofile
	bsr	getanger
	moveq	#WNDORDER_RETREAT,d1	; afraid
	cmp.w	#1,d0
	beq.s	.o
	moveq	#WNDORDER_NONE,d1	; indifferent / friendly
	cmp.w	#4,d0
	blt.s	.o
	moveq	#WNDORDER_ATTACK,d1	; angry / violent
.o:	move.w	d1,d0
	bra	createwandering
.x:	rts
getanger:
	move.w	GS_ALIEN+ALIEN_ANGER(a6),d0
	move.w	GS_ALIEN+ALIEN_CONGENIALITY(a6),d1
	bra	calc_anger

; usecode.pas restcrew: the time burst (2000 ticks)
restcrew:
	movem.l	d3,-(sp)
	move.w	#2000-1,d3
.t:	bsr	addtime
	bsr	showtime
	dbf	d3,.t
	moveq	#1,d3			; the crew's values recomputed
.c:	move.w	d3,d0
	bsr	ct_computeperf
	move.w	d0,-(sp)
	move.w	d3,d0
	bsr	ct_computeskill
	move.w	d0,-(sp)
	move.w	d3,d0
	bsr	ct_computesanity
	move.w	d0,d2
	move.w	d3,d0
	bsr	ct_crew
	move.b	d2,CREW_SAN(a0)
	move.w	(sp)+,d0
	move.b	d0,CREW_SKILL(a0)
	move.w	(sp)+,d0
	move.b	d0,CREW_PERF(a0)
	addq.w	#1,d3
	cmp.w	#7,d3
	bne.s	.c
	bsr	checkrandommonster
	st	GS_ANYCHANGE(a6)
	movem.l	(sp)+,d3
	rts

contactfailure:
	PRTLN
	TCOL	94
	PRT	"SCIENCE: Communications too damaged!"
	rts

	section	data
u3_t_model:	dc.b	6,"Model:"
	even
u3_shipnames:	dc.b	5,"Heavy",0,0,0,0
		dc.b	5,"Light",0,0,0,0
		dc.b	9,"Strategic"
		dc.b	7,"Shuttle",0,0
		dc.b	7,"Assault",0,0
		dc.b	5,"Storm",0,0,0,0
		dc.b	9,"Transport"
		dc.b	7,"Frigate",0,0
		dc.b	7,"Cruiser",0,0
	even

	section	bss
u3_but:		ds.w	3
u3_i:		ds.w	1
u3_x1:		ds.w	1
u3_x2:		ds.w	1
u3_y1:		ds.w	1
u3_y2:		ds.w	1
u3_xyz:		ds.w	3
u3_dist:	ds.l	2
u3_s:		ds.b	64
u3_greypal:	ds.b	768
u3_colors2:	ds.b	768

	section	text
; saveload.pas savegamedata(alt d0, text d1) for MAIN.PRG: the dialog in the shadow; what was
; under it (rows 40-140, x 74-245) comes back afterwards.  out d0.w = 1 saved
savegamedata:
	movem.l	d3-d5/a3,-(sp)
	move.w	d0,d4
	move.w	d1,d5
	bsr	mem_mark
	move.l	d0,-(sp)
	move.l	#101*172,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,a3
	bsr	mousehide
	bsr	.copy			; keep
	move.w	d4,d0
	move.w	d5,d1
	bsr	sl_savegamedata
	move.w	d0,d4
	bsr	mousehide
	exg	a0,a1			; (restore: the other way round)
	st	u3_back
	bsr	.copy
	sf	u3_back
	move.w	#74,d0
	moveq	#40,d1
	move.w	#245,d2
	move.w	#140,d3
	bsr	ms_dirty
	bsr	ms_refit_end		; (Phase 6j: the screen's own design again)
	bsr	mouseshow
	BKCOL	3
	move.l	(sp)+,d0
	bsr	mem_release
	move.w	d4,d0
	movem.l	(sp)+,d3-d5/a3
	rts
.copy:	move.w	#74,d0
	moveq	#40,d1
	bsr	ms_addr
	move.l	a3,a1
	moveq	#101-1,d1
.r:	move.w	#172-1,d0
	move.l	a0,a2
.c:	tst.b	u3_back
	bne.s	.b
	move.b	(a2)+,(a1)+
	dbf	d0,.c
	bra.s	.n
.b:	move.b	(a1)+,(a2)+
	dbf	d0,.b
.n:	lea	MS_W(a0),a0
	dbf	d1,.r
	rts

	section	bss
u3_back:	ds.b	1
	even
