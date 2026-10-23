; usecode.s - usecode.pas, display.pas and utils.pas parts of the bridge for MAIN.PRG: the ship
; status panel, the status lights, the right-hand panel's appearing/clearing, the cube's
; commands (those not ported stop with notported), the yes/no request (saveload.pas).
; (all trash d0-d2/a0-a2)

	section	text
; usecode.pas readystatus
readystatus:
	movem.l	d3-d4,-(sp)
	move.w	#1,GS_VIEWMODE(a6)
	bsr	mousehide
	moveq	#5-1,d3			; 5 x (plainfadearea(165,25,279,117,1); delay(tslice*2))
.f:	move.w	#165,d0
	moveq	#25,d1
	move.w	#279,d2
	move.w	d3,-(sp)
	moveq	#117,d3
	moveq	#1,d4
	bsr	plainfadearea
	move.w	(sp)+,d3
	move.w	GS_TSLICE(a6),d0
	add.w	d0,d0
	bsr	delay
	dbf	d3,.f
	bsr	us_panel
	move.w	#191,GS_TCOLOR(a6)
	move.w	#5,GS_BKCOLOR(a6)
	move.w	#192,d0
	moveq	#27,d1
	lea	us_s_stats,a0
	bsr	printxy
	moveq	#0,d3			; revgraybutton(172,45+j*20,272,55+j*20)
.b:	move.w	#172,d0
	move.w	d3,d1
	mulu	#20,d1
	add.w	#45,d1
	move.w	#272,d2
	move.w	d1,-(sp)
	move.w	d3,-(sp)
	move.w	d1,d3
	add.w	#10,d3
	bsr	revgraybutton
	move.w	(sp)+,d3
	addq.l	#2,sp
	addq.w	#1,d3
	cmp.w	#4,d3
	bne.s	.b
	lea	us_labels,a0
	moveq	#4-1,d3
.l:	move.w	(a0)+,d0
	move.w	(a0)+,d1
	move.l	a0,-(sp)
	bsr	printxy
	move.l	(sp)+,a0
	moveq	#0,d0
	move.b	(a0),d0
	lea	2(a0,d0.w),a0		; next (length byte + text, padded)
	move.l	a0,d0
	and.w	#$fffe,d0
	move.l	d0,a0
	dbf	d3,.l
	bsr	mouseshow
	bsr	displaystatus
	move.w	#3,GS_BKCOLOR(a6)
	movem.l	(sp)+,d3-d4
	rts

; the panel's frame (utils.pas genericrightside / readystatus): rows 25-117, x 165-279 in 5
us_panel:
	movem.l	d3-d4,-(sp)
	move.w	#165,d0
	moveq	#25,d1
	move.w	#279,d2
	moveq	#117,d3
	moveq	#5,d4
	bsr	ms_bar
	lea	us_frame,a0
.l:	move.w	(a0)+,d0
	bmi.s	.p
	move.w	(a0)+,d1
	move.w	(a0)+,d2
	move.w	(a0)+,d3
	move.w	(a0)+,d4
	move.l	a0,-(sp)
	bsr	ms_line
	move.l	(sp)+,a0
	bra.s	.l
.p:	lea	us_corners,a0
.c:	move.w	(a0)+,d0
	bmi.s	.x
	move.w	(a0)+,d1
	move.w	(a0)+,d2
	move.l	a0,-(sp)
	bsr	ms_pset
	move.l	(sp)+,a0
	bra.s	.c
.x:	movem.l	(sp)+,d3-d4
	rts

; display.pas displaystatus: four gauges (a grey ramp) and their values
displaystatus:
	movem.l	d3-d7/a3,-(sp)
	move.w	GS_TCOLOR(a6),-(sp)
	move.w	#191,GS_TCOLOR(a6)
	move.w	#255,GS_BKCOLOR(a6)
	bsr	mousehide
	lea	GS_SHIP(a6),a3
	move.w	SHIP_HULLINTEGRITY(a3),d0
	move.w	SHIP_HULLMAX(a3),d1
	moveq	#46,d2
	bsr	us_gauge
	move.w	SHIP_FUEL(a3),d0
	move.w	SHIP_FUELMAX(a3),d1
	moveq	#66,d2
	bsr	us_gauge
	move.w	SHIP_BATTERY(a3),d0
	move.w	#32000,d1
	moveq	#86,d2
	bsr	us_gauge
	move.w	SHIP_SHIELDLEVEL(a3),d0
	moveq	#100,d1
	moveq	#106,d2
	bsr	us_gauge
	bsr	mouseshow
	move.w	#3,GS_BKCOLOR(a6)
	move.w	(sp)+,GS_TCOLOR(a6)
	movem.l	(sp)+,d3-d7/a3
	rts

; one gauge: value d0, max d1, first row d2 (rows d2..d2+8)
;   a := round(value/max*98); colour of column j = round(j*31/a); the rest black; the number
us_gauge:
	movem.l	d3-d7,-(sp)
	move.w	d0,d5			; value
	move.w	d2,d6			; row
	move.w	d1,d0
	move.w	d5,d1
	moveq	#98,d2
	bsr	us_ratio		; d0 = a
	move.w	d0,d7
	moveq	#0,d3			; j
.j:	cmp.w	d7,d3
	bgt.s	.rest
	moveq	#0,d4			; c := round(j*31/a) (a = 0: 0)
	tst.w	d7
	beq.s	.c0
	move.w	d7,d0
	move.w	d3,d1
	moveq	#31,d2
	bsr	us_ratio
	move.w	d0,d4
	move.w	d3,d0			; FPC's j*(31/a) lands below 15.5 for these four
	add.w	d0,d0
	cmp.w	d7,d0
	bne.s	.c0
	lea	us_ties,a0
.t:	move.w	(a0)+,d0
	beq.s	.c0
	cmp.w	d0,d7
	bne.s	.t
	moveq	#15,d4
.c0:	move.w	d3,d0			; screen[46..54, j+173] := c
	add.w	#173,d0
	move.w	d6,d1
	move.w	d0,d2
	move.l	d3,-(sp)
	move.w	d6,d3
	addq.w	#8,d3
	bsr	ms_bar
	move.l	(sp)+,d3
	addq.w	#1,d3
	bra.s	.j
.rest:	cmp.w	#98,d7			; if a < 98: x 174+a .. 271 in 0
	bge.s	.num
	move.w	d7,d0
	add.w	#174,d0
	move.w	d6,d1
	move.w	#271,d2
	move.w	d6,d3
	addq.w	#8,d3
	moveq	#0,d4
	bsr	ms_bar
.num:	move.w	d5,d0			; printxy(219-round(length*2.5), row+1, str(value))
	ext.l	d0
	moveq	#0,d1
	lea	us_num,a0
	bsr	int_str
	moveq	#0,d0
	move.b	us_num,d0
	mulu	#5,d0			; round(len*2.5) = round(len*5/2): banker's on .5
	move.w	d0,d1
	lsr.w	#1,d0
	btst	#0,d1
	beq.s	.r
	btst	#0,d0			; x.5: to even
	beq.s	.r
	addq.w	#1,d0
.r:	move.w	#219,d1
	sub.w	d0,d1
	move.w	d1,d0
	move.w	d6,d1
	addq.w	#1,d1
	lea	us_num,a0
	bsr	printxy
	movem.l	(sp)+,d3-d7
	rts

; d0.w = round(d1 / d0 * d2) for 0 <= d1 (the original's real division and round: no ties
; in the cases used, (d1*d2) mod d0 = d0/2 aside, which rounds to even here)
us_ratio:
	movem.l	d3,-(sp)
	move.w	d0,d3			; max
	beq.s	.z
	muls	d2,d1			; value*k
	move.l	d1,d0
	bpl.s	.p
	neg.l	d0
.p:	divu	d3,d0			; q:r
	move.l	d0,d2
	swap	d2			; r
	add.w	d2,d2
	cmp.w	d3,d2
	blo.s	.s
	bhi.s	.u
	btst	#0,d0			; exactly .5: to even
	beq.s	.s
.u:	addq.w	#1,d0
.s:	tst.l	d1
	bpl.s	.x
	neg.w	d0
.x:	movem.l	(sp)+,d3
	rts
.z:	moveq	#0,d0
	movem.l	(sp)+,d3
	rts

; display.pas checkstats: the alert mode from the damages, the four status lights' colours
checkstats:
	movem.l	d3-d5/a3,-(sp)
	lea	GS_SHIP(a6),a3
	cmp.w	#ALRT_COMBAT,GS_ALERT(a6)
	bge.s	.lights
	moveq	#ALRT_REST,d0
	lea	SHIP_DAMAGES(a3),a0
	moveq	#7-1,d1
.d:	tst.b	(a0)+
	beq.s	.dn
	moveq	#ALRT_ALERT,d0
.dn:	dbf	d1,.d
	moveq	#1,d1
	bsr	setalertmode
.lights:
	move.w	SHIP_HULLINTEGRITY(a3),d0	; hull: < 250 red, < 500 yellow, else green
	moveq	#80,d3
	cmp.w	#250,d0
	blt.s	.h
	moveq	#112,d3
	cmp.w	#500,d0
	blt.s	.h
	moveq	#48,d3
.h:	moveq	#1,d5
	moveq	#29,d1
	bsr	.set
	move.w	SHIP_FUELMAX(a3),d0	; fuel: round(fuel/fuelmax*100)
	move.w	SHIP_FUEL(a3),d1
	moveq	#100,d2
	bsr	us_ratio
	bsr	.col
	moveq	#2,d5
	moveq	#49,d1
	bsr	.set
	move.w	#32000,d0		; battery: round(battery/batmax*100)
	move.w	SHIP_BATTERY(a3),d1
	moveq	#100,d2
	bsr	us_ratio
	bsr	.col
	moveq	#3,d5
	moveq	#69,d1
	bsr	.set
	move.w	SHIP_SHIELDLEVEL(a3),d0
	bsr	.col
	moveq	#4,d5
	moveq	#89,d1
	bsr	.set
	movem.l	(sp)+,d3-d5/a3
	rts
.col:	moveq	#80,d3			; a < 26 red, < 51 yellow, else green
	cmp.w	#26,d0
	blt.s	.c
	moveq	#112,d3
	cmp.w	#51,d0
	blt.s	.c
	moveq	#48,d3
.c:	rts
.set:	lea	GS_STATCOLORS-1(a6),a0	; if statcolors[n] <> tc then colorarea(300,y,313,y+10,tc,n)
	cmp.b	0(a0,d5.w),d3
	beq.s	.sx
	move.w	#300,d0
	move.w	#313,d2
	move.w	d3,d4
	move.w	d3,-(sp)
	move.w	d1,d3
	add.w	#10,d3
	bsr	colorarea
	move.w	(sp)+,d3
.sx:	rts

; usecode.pas showresearchlights
showresearchlights:
	movem.l	d3-d4,-(sp)
	moveq	#1,d3
.l:	moveq	#95,d2			; 63 on, 95 off
	btst	d3,GS_SHIP+SHIP_RESEARCH(a6)
	beq.s	.c
	moveq	#63,d2
.c:	move.w	#181,d0			; faces 1-3: (181, 141+j*12 .. 142+j*12)
	cmp.w	#3,d3
	ble.s	.p
	move.w	#299,d0			; faces 4-6: (299, 105+j*12 ..)
.p:	move.w	d3,d1
	mulu	#12,d1
	add.w	#141,d1
	cmp.w	#3,d3
	ble.s	.p2
	sub.w	#36,d1
.p2:	move.w	d2,d4
	movem.w	d0-d1,-(sp)
	bsr	ms_pset
	movem.w	(sp)+,d0-d1
	addq.w	#1,d1
	move.w	d4,d2
	bsr	ms_pset
	addq.w	#1,d3
	cmp.w	#6,d3
	ble.s	.l
	movem.l	(sp)+,d3-d4
	rts

; usecode.pas cleanright(erasepanel d0.b)
cleanright:
	tst.w	GS_VIEWMODE(a6)
	beq.s	.x
	move.w	GS_VIEWMODE(a6),d1
	cmp.w	#7,d1
	ble	removerightside
	cmp.w	#11,d1
	bge	removerightside
	bra	removesystem
.x:	rts

; utils.pas removerightside(erasepanel d0.b)
removerightside:
	movem.l	d3-d5,-(sp)
	move.b	d0,d5			; erasepanel
	bsr	mousehide
	tst.b	GS_PANELON(a6)
	beq.s	.np
	tst.b	d5
	beq.s	.np
	bsr	removepanel
.np:	clr.w	GS_VIEWMODE(a6)
	moveq	#5-1,d3
.f:	move.w	#165,d0
	moveq	#25,d1
	move.w	#279,d2
	move.w	d3,-(sp)
	moveq	#117,d3
	moveq	#-1,d4
	bsr	plainfadearea
	move.w	(sp)+,d3
	move.w	GS_TSLICE(a6),d0
	add.w	d0,d0
	bsr	delay
	dbf	d3,.f
	move.w	#164,d0			; sprinkle(164,24,281,118,17)
	moveq	#24,d1
	move.w	#281,d2
	moveq	#118,d3
	moveq	#17,d4
	bsr	sprinkle
	bsr	mouseshow
	movem.l	(sp)+,d3-d5
	rts

removepanel:
	tst.b	GS_PANELON(a6)
	beq.s	.x
	movem.l	d3-d4,-(sp)
	bsr	mousehide
	move.w	#153,d0
	moveq	#9,d1
	move.w	#290,d2
	moveq	#24,d3
	moveq	#7,d4
	bsr	sprinkle
	sf	GS_PANELON(a6)
	bsr	mouseshow
	movem.l	(sp)+,d3-d4
.x:	rts

; utils.pas sprinkle(x1,y1,x2,y2,seed d4): the background comes back pixel by pixel
sprinkle:
	movem.l	d3-d7/a3-a4,-(sp)
	move.w	d0,us_sx1
	move.w	d1,us_sy1
	sub.w	d0,d2			; x2-x1
	move.w	d2,us_sw
	sub.w	d1,d3
	mulu	d2,d3			; max := (x2-x1)*(y2-y1) (word)
	move.w	d3,us_max
	move.w	d4,us_seed
	clr.w	us_index
	moveq	#0,d7			; j
	bsr	mousehide
	move.l	GS_BACKGR(a6),a4
.l:	addq.w	#1,us_index
	add.w	us_seed,d7		; j := j + seed; if j > max then j := j - max
	cmp.w	us_max,d7
	bls.s	.j
	sub.w	us_max,d7
.j:	moveq	#0,d0
	move.w	d7,d0
	divu	us_sw,d0		; y := y1 + j div w; x := x1 + j mod w
	move.w	d0,d1
	add.w	us_sy1,d1
	swap	d0
	add.w	us_sx1,d0
	move.w	d0,d2			; a := x + backgrx (wrapped); b := y + backgry
	add.w	GS_BACKGRX(a6),d2
	cmp.w	#319,d2
	ble.s	.a
	sub.w	#320,d2
.a:	move.w	d1,d3
	add.w	GS_BACKGRY(a6),d3
	cmp.w	#199,d3
	ble.s	.b
	sub.w	#200,d3
.b:	mulu	#320,d3
	add.w	d2,d3
	move.b	0(a4,d3.l),d2		; screen[y,x] := backgr^[b,a]
	bsr	ms_pset
	move.w	us_index,d0		; if index mod 100 = 0 then delay(tslice div 10)
	ext.l	d0
	divu	#100,d0
	swap	d0
	tst.w	d0
	bne.s	.nd
	move.w	GS_TSLICE(a6),d0
	ext.l	d0
	divu	#10,d0
	bsr	delay
.nd:	move.w	us_index,d0
	cmp.w	us_max,d0
	bls	.l
	bsr	mouseshow
	movem.l	(sp)+,d3-d7/a3-a4
	rts

; ---------------------------------------------------------------
; usecode.pas processcube(face d0): the button lights up (+1), its command, the button back (-1)
processcube:
	move.l	d5,-(sp)
	move.w	d0,d5
	moveq	#1,d1
	bsr	us_cubeglow
	move.w	d5,d0
	bsr	us_command
	move.w	d5,d0
	moveq	#-1,d1
	bsr	us_cubeglow
	move.l	(sp)+,d5
	rts

; plainfadearea of face d0's button (some commands light a bigger area), alt d1
us_cubeglow:
	movem.l	d3-d5,-(sp)
	move.w	d0,d5
	move.w	d1,d4
	lea	us_glow,a0
.g:	move.w	(a0)+,d1
	bmi.s	.gen
	movem.w	(a0)+,d0/d2/d3/a1	; x1 y1 x2 y2
	cmp.w	d1,d5
	bne.s	.g
	move.w	d2,d1
	move.w	d3,d2
	move.w	a1,d3
	bra.s	.f
.gen:	move.w	d5,d0			; a := face mod 9; j := a mod 3; i := a div 3
	ext.l	d0
	divu	#9,d0
	swap	d0
	ext.l	d0
	divu	#3,d0
	move.w	d0,d1			; i
	swap	d0			; j
	mulu	#17,d0
	add.w	#215,d0
	mulu	#15,d1
	add.w	#145,d1
	move.w	d0,d2
	add.w	#16,d2
	move.w	d1,d3
	add.w	#14,d3
.f:	bsr	plainfadearea
	movem.l	(sp)+,d3-d5
	rts

; the commands (usecode.pas processcube's second case); those not ported stop the program
us_command:
	movem.l	d3-d4,-(sp)
	move.w	d0,d3
	lea	us_research,a0		; research toggles
.r:	move.w	(a0)+,d1
	bmi.s	.nr
	move.w	(a0)+,d0
	cmp.w	d1,d3
	bne.s	.r
	bsr	toggleresearch
	bra	.x
.nr:	cmp.w	#53,d3
	bhi	.x
	move.w	d3,d0
	add.w	d0,d0
	move.w	.tab(pc,d0.w),d0
	jmp	.tab(pc,d0.w)
.tab:	dc.w	.c0-.tab,.c12-.tab,.c12-.tab,.c0-.tab,.c45-.tab,.c45-.tab,.c6-.tab,.x-.tab	; 0-7
	dc.w	.c8-.tab,.c9-.tab,.c10-.tab,.c11-.tab,.c12s-.tab,.c13-.tab,.c14-.tab,.c15-.tab ; 8-15
	dc.w	.x-.tab,.c17-.tab,.c18-.tab,.cex-.tab,.cex-.tab,.c21-.tab,.cex-.tab,.cex-.tab ; 16-23
	dc.w	.c24-.tab,.x-.tab,.c26-.tab,.c27-.tab,.c27-.tab,.c29-.tab,.c30-.tab,.c31-.tab ; 24-31
	dc.w	.c32-.tab,.c33-.tab,.x-.tab,.c32-.tab,.c36-.tab,.c37-.tab,.c38-.tab,.c39-.tab ; 32-39
	dc.w	.c40-.tab,.c40-.tab,.c42-.tab,.x-.tab,.c44-.tab,.c45o-.tab,.c46-.tab,.c47-.tab ; 40-47
	dc.w	.c48-.tab,.np-.tab,.c50-.tab,.c51-.tab,.x-.tab,.c53-.tab			; 48-53
.np:	sf	d0			; loadgamedata(false): a game loaded -> reloading, quit, colors black
	bsr	sl_loadgamedata
	tst.w	d0
	beq	.x
	st	GS_RELOADING(a6)
	st	GS_QUIT(a6)
	lea	GS_COLORS(a6),a0
	move.w	#768/4-1,d0
.cl:	clr.l	(a0)+
	dbf	d0,.cl
	lea	GS_COLORS(a6),a0
	bsr	set256colors
	bra	.x
.c8:	bsr	conversewithcrew
	bra	.x
.c14:	bsr	creation
	bra	.x
.c17:	bsr	inventory
	bra	.x
.c0:	bsr	psyche
	bra	.x
.c6:	bsr	crewstats
	bra	.x
.c12:	sf	d0			; 1,2: continuecontact(false)
.cc:	cmp.b	#39,GS_SHIP+SHIP_DAMAGES+DMG_COMM-1(a6)
	bhi.s	.cf
	bsr	continuecontact
	bra	.x
.cf:	bsr	contactfailure
	bra	.x
.c45:	st	d0			; 4,5: continuecontact(true)
	bra.s	.cc
.c9:	cmp.w	#5,GS_VIEWMODE(a6)
	beq	.x
	sf	d0
	bsr	cleanright
	bsr	readydamagecontrol
	bra	.x
.c10:	cmp.w	#10,GS_VIEWMODE(a6)
	beq	.x
	bsr	.rsm
	sf	d0
	bsr	cleanright
	bsr	readyconfigure
	bra	.x
.c11:	cmp.w	#11,GS_VIEWMODE(a6)
	beq	.x
	bsr	readybots
	bra	.x
.c12s:	cmp.w	#4,GS_VIEWMODE(a6)
	beq	.x
	sf	d0
	bsr	cleanright
	bsr	readyshieldopts
	bra	.x
.c13:	move.w	#255,d0
	bsr	computerlogs
	bra	.x
.c15:	cmp.w	#2,GS_VIEWMODE(a6)
	beq	.x
	sf	d0
	bsr	cleanright
	bsr	readyweaponinfo
	bra	.x
.c18:	cmp.w	#3,GS_VIEWMODE2(a6)
	beq	.x
	bsr	.rsys
	bsr	.rsm
	moveq	#3,d0
	bsr	readystarmap
	bsr	displayshortscan
	bra	.x
.cex:	tst.b	GS_SHOWPLANET(a6)
	beq.s	.cex3
	move.w	GS_CURPLAN(a6),d0
	bsr	dp_plan
	cmp.b	#7,PLANET_STATE(a0)
	beq.s	.cex2
	move.w	#ID_PROBOT,d0
	bsr	incargo
	tst.w	d0
	ble.s	.cex1
	bsr	exploreplanet
	bra	.x
.cex1:	TCOL	94			; 19,20,22,23: exploreplanet
	PRTLN
	PRT	"SCIENCE: We have no probots."
	bra	.x
.cex2:	move.w	#ID_STARDIVER,d0
	bsr	incargo
	tst.w	d0
	ble.s	.cex4
	bsr	exploreplanet
	bra	.x
.cex4:	TCOL	94
	PRTLN
	PRT	"SCIENCE: We have no probots that can withstand a star."
	bra	.x
.cex3:	TCOL	94
	PRTLN
	PRT	"SCIENCE: We are not near a planet."
	bra	.x
.c21:	cmp.w	#4,GS_VIEWMODE2(a6)
	beq	.x
	bsr	.rsys
	bsr	.rsm
	moveq	#4,d0
	bsr	readystarmap
	bsr	readylongscan
	bra	.x
.c24:	cmp.w	#8,GS_VIEWMODE(a6)
	beq	.x
	bsr	readysystem
	bra	.x
.c26:	cmp.w	#7,GS_VIEWMODE(a6)
	beq	.x
	sf	d0
	bsr	cleanright
	bsr	readylogs
	bra	.x
.c27:	moveq	#WNDACT_RETREAT,d4	; 27,28: evade
	bsr	.near
	beq.s	.c27n
	PRT	"SECURITY: Attempting to evade aliens."
	bra	.x
.c27n:	bsr	.noaliens
	bra	.x
.c31:	moveq	#WNDACT_MASKING,d4
	bsr	.near
	beq.s	.c31n
	PRT	"SECURITY: Attempting to mask ship."
	bra	.x
.c31n:	bsr	.noaliens
	bra	.x
.c32:	moveq	#WNDACT_ATTACK,d4
	bsr	.near
	beq.s	.c32n
	PRT	"SECURITY: Attempting to close and attack aliens."
	bra	.x
.c32n:	bsr	.noaliens
	bra	.x
.c29:	lea	GS_SHIP+SHIP_GUNNODES(a6),a0	; launch drones
	moveq	#10-1,d1
	moveq	#0,d0
.c29l:	tst.b	(a0)+
	beq.s	.c29n
	addq.w	#1,d0
.c29n:	dbf	d1,.c29l
	tst.w	d0
	bne.s	.c29a
	TCOL	31
	move.w	#WNDACT_RETREAT,GS_ACTION(a6)
	PRTLN
	PRT	"SECURITY: We have no weapons installed!"
	bra	.x
.c29a:	cmp.w	#16000,GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6)
	bge.s	.c29b
	TCOL	31
	move.w	#WNDACT_RETREAT,GS_ACTION(a6)
	PRTLN
	PRT	"SECURITY: There is an alien vessel nearby. This is not the time for war exercises."
	bra	.x
.c29b:	PLEA	"Launch Combat Drones?"
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq	.x
	moveq	#13,d0
	move.w	#1013,d1
	bsr	getspecial
	moveq	#WNDORDER_ATTACK,d0
	bsr	createwandering
	lea	GS_SHIP+SHIP_WANDERING(a6),a0
	move.w	#400,ONEALIEN_RELX(a0)
	move.w	#400,ONEALIEN_RELY(a0)
	move.w	#400,ONEALIEN_RELZ(a0)
	bra	.x
.c30:	moveq	#0,d0			; raise/lower shields
	move.b	GS_SHIP+SHIP_SHIELDOPT+SHLD_COMBAT_WANT-1(a6),d0
	cmp.w	GS_SHIP+SHIP_SHIELDLEVEL(a6),d0
	bne.s	.c30r
	cmp.w	#ALRT_COMBAT,GS_ALERT(a6)
	bne.s	.c30r
	bsr	lowershields
	bra	.x
.c30r:	bsr	raiseshields
	bra	.x
.c33:	tst.b	GS_SHIP+SHIP_ARMED(a6)
	beq.s	.c33a
	bsr	powerdownweapons
	bra	.x
.c33a:	bsr	armweapons
	bra	.x
.c36:	cmp.w	#1,GS_VIEWMODE2(a6)
	beq	.x
	bsr	.rsys
	bsr	.rsm
	moveq	#1,d0
	bsr	readystarmap
	bsr	displaystarmap
	bra	.x
.c37:	cmp.w	#1,GS_VIEWMODE(a6)
	beq	.x
	st	d0
	bsr	cleanright
	bsr	readystatus
	bra	.x
.c38:	cmp.w	#9,GS_VIEWMODE(a6)
	beq	.x
	bsr	.rsm
	st	d0
	bsr	cleanright
	bsr	readyshipinfo
	bra	.x
.c39:	moveq	#11,d0
	bsr	chevent
	tst.w	d0
	beq.s	.c39n
	bsr	sectorinfo
	bra	.x
.c39n:
	PRTLN
	TCOL	94
	PRT	"NAVIGATION: Sir, we know nothing about this part of the galaxy."
	bra	.x
.c40:	bsr	readytarget
	bra	.x
.c42:	cmp.w	#2,GS_VIEWMODE2(a6)
	beq	.x
	bsr	.rsys
	bsr	.rsm
	bsr	readyhistory
	bra	.x
.c44:	cmp.w	#3,GS_VIEWMODE(a6)
	beq	.x
	sf	d0
	bsr	cleanright
	bsr	readysysteminfo
	bra	.x
.c45o:	cmp.w	#6,GS_VIEWMODE(a6)
	beq	.x
	sf	d0
	bsr	cleanright
	bsr	readyoptions
	bra	.x
.c46:	moveq	#0,d0
	moveq	#31,d1
	bsr	savegamedata
	bra	.x
.c47:	moveq	#0,d0			; lifesupportfailure or encodecrew(26)
	bsr	en_lifecheck
	bra	.x
.c50:	moveq	#2,d0			; lifesupportfailure or decodecrew
	bsr	en_lifecheck
	bra	.x
.c48:	PLEA	"Initiate Time Burst?"
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq	.x
	bsr	restcrew
	bra	.x
.c51:	bsr	.rsm
	st	d0
	bsr	cleanright
	bra	.x
.c53:	lea	jy_s_quit,a0
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq	.x
	st	GS_QUIT(a6)
.x:	movem.l	(sp)+,d3-d4
	rts
.rsm:	tst.w	GS_VIEWMODE2(a6)	; if viewmode2 > 0 then removestarmap
	ble.s	.rx
	bra	removestarmap
.rsys:	move.w	GS_VIEWMODE(a6),d0	; if (viewmode > 7) and (viewmode <> 11) then removesystem(true)
	cmp.w	#7,d0
	ble.s	.rx
	cmp.w	#11,d0
	beq.s	.rx
	st	d0
	bra	removesystem
.rx:	rts
; the alien ship within 8000 on any axis and action <> d4 ? (Z clear = yes: action := d4)
.near:	cmp.w	#16000,GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6)
	bge.s	.nn
	cmp.w	GS_ACTION(a6),d4
	beq.s	.nn
	lea	GS_SHIP+SHIP_WANDERING+ONEALIEN_RELX(a6),a0
	moveq	#3-1,d1
.nl:	move.w	(a0)+,d0
	bpl.s	.np2
	neg.w	d0
.np2:	cmp.w	#8000,d0
	blt.s	.ny
	dbf	d1,.nl
.nn:	moveq	#0,d0
	rts
.ny:	TCOL	31
	move.w	d4,GS_ACTION(a6)
	PRTLN
	moveq	#1,d0
	rts
.noaliens:				; else if action <> d4: 'No aliens on our scopes.'
	cmp.w	GS_ACTION(a6),d4
	beq.s	.rx
	TCOL	94
	clr.w	GS_ACTION(a6)
	PRTLN
	PRT	"SECURITY: No aliens on our scopes."
	rts

; usecode.pas ToggleResearch(face d0)
toggleresearch:
	move.l	d3,-(sp)
	move.w	d0,d3
	bchg	d3,GS_SHIP+SHIP_RESEARCH(a6)
	move.w	#63,GS_TCOLOR(a6)
	bsr	println
	lea	us_s1,a0		; crewtitles[face] + ': Initiating research.' / 'Cancelling'
	move.w	d3,d0
	mulu	#12,d0
	lea	us_crewtitles,a1
	add.w	d0,a1
	bsr	pstr_cpy
	lea	us_s1,a0
	lea	us_s_init,a1
	btst	d3,GS_SHIP+SHIP_RESEARCH(a6)
	bne.s	.i
	lea	us_s_cancel,a1
.i:	bsr	pstr_cat
	lea	us_s1,a0
	bsr	print
	bsr	showresearchlights
	move.l	(sp)+,d3
	rts

; ---------------------------------------------------------------
; saveload.pas yesnorequest(s a0, alt d0, text d1): out d0.w = 1 yes
yesnorequest:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	a0,a3
	move.w	d0,d6			; alt
	move.w	d1,d7			; text
	bsr	mem_mark
	move.l	d0,-(sp)
	move.l	#43*4*43,d0		; tempscr: rows 60-102, x 74-245
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,a4
	bsr	mousehide
	move.w	#74,d0
	moveq	#60,d1
	bsr	ms_addr
	move.l	a4,a1
	moveq	#43-1,d1
.sv:	move.w	#172-1,d0
	move.l	a0,a2
.svc:	move.b	(a2)+,(a1)+
	dbf	d0,.svc
	lea	MS_W(a0),a0
	dbf	d1,.sv
	move.w	d7,d0			; tcolor := text-5; bkcolor := 35+alt
	subq.w	#5,d0
	move.w	d0,GS_TCOLOR(a6)
	move.w	d6,d0
	add.w	#35,d0
	move.w	d0,GS_BKCOLOR(a6)
	move.w	#74,d0
	moveq	#60,d1
	move.w	#245,d2
	move.w	#102,d3
	move.w	d6,d4
	bsr	us_button
	move.w	#110,d0
	moveq	#78,d1
	move.w	#150,d2
	moveq	#92,d3
	move.w	d6,d4
	addq.w	#2,d4
	bsr	us_button
	move.w	#169,d0
	moveq	#78,d1
	move.w	#209,d2
	moveq	#92,d3
	move.w	d6,d4
	addq.w	#2,d4
	bsr	us_button
	moveq	#0,d0			; printxy(156-round(length*2.5), 65, s)
	move.b	(a3),d0
	mulu	#5,d0
	move.w	d0,d1
	lsr.w	#1,d0
	btst	#0,d1
	beq.s	.r
	btst	#0,d0
	beq.s	.r
	addq.w	#1,d0
.r:	move.w	#156,d1
	sub.w	d0,d1
	move.w	d1,d0
	moveq	#65,d1
	move.l	a3,a0
	bsr	printxy
	move.w	d6,d0			; bkcolor := 37+alt
	add.w	#37,d0
	move.w	d0,GS_BKCOLOR(a6)
	moveq	#118,d0
	moveq	#82,d1
	lea	us_s_yes,a0
	bsr	printxy
	move.w	#179,d0
	moveq	#82,d1
	lea	us_s_no,a0
	bsr	printxy
	bsr	us_mainloop2
	move.w	d0,d5
	bsr	mousehide		; restore the screen under the box
	move.w	#74,d0
	moveq	#60,d1
	bsr	ms_addr
	move.l	a4,a1
	moveq	#43-1,d1
.rs:	move.w	#172-1,d0
	move.l	a0,a2
.rsc:	move.b	(a1)+,(a2)+
	dbf	d0,.rsc
	lea	MS_W(a0),a0
	dbf	d1,.rs
	move.w	#74,d0
	moveq	#60,d1
	move.w	#245,d2
	moveq	#102,d3
	bsr	ms_dirty
	move.l	(sp)+,d0
	bsr	mem_release
	move.w	#3,GS_BKCOLOR(a6)
	bsr	mouseshow
	moveq	#0,d0			; move_mouse(0,0)
	moveq	#0,d1
	bsr	kbd_mouse_move
	move.w	d5,d0
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; saveload.pas button(x1,y1,x2,y2,alt d4) in the shadow
us_button:
	movem.l	d3-d7,-(sp)
	movem.w	d0-d3,us_bx
	move.w	d4,d7
	add.w	#35,d4
	bsr	ms_bar
	movem.w	us_bx,d0-d3		; line(x2,y1,x2,y2), line(x1,y2,x2,y2) in 32+alt
	move.w	d2,d0
	move.w	d7,d4
	add.w	#32,d4
	bsr	ms_line
	movem.w	us_bx,d0-d3
	move.w	d3,d1
	move.w	d7,d4
	add.w	#32,d4
	bsr	ms_line
	movem.w	us_bx,d0-d3		; line(x1,y1,x2,y1), line(x1,y1,x1,y2) in 38+alt
	move.w	d1,d3
	move.w	d7,d4
	add.w	#38,d4
	bsr	ms_line
	movem.w	us_bx,d0-d3
	move.w	d0,d2
	move.w	d7,d4
	add.w	#38,d4
	bsr	ms_line
	movem.w	us_bx,d0-d3		; corners in 36+alt
	move.w	d2,d0
	move.w	d7,d2
	add.w	#36,d2
	bsr	ms_pset
	movem.w	us_bx,d0-d3
	move.w	d3,d1
	move.w	d7,d2
	add.w	#36,d2
	bsr	ms_pset
	movem.l	(sp)+,d3-d7
	rts

; mainloop2: the yes/no cursor; out d0.w = 1 when Yes
us_mainloop2:
	sf	us_done
	clr.w	us_lastx
	clr.w	us_lasty
	clr.w	us_cursor
	bsr	mouseshow
.l:	bsr	us_findmouse2
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	us_processkey2
.nk:	move.w	GS_TSLICE(a6),d0	; delay(tslice*FADE_TSLICE_MUL_SAVELOAD)
	bsr	delay
	moveq	#8,d0
	bsr	fadestep
	tst.b	us_done
	beq.s	.l
	moveq	#0,d0
	cmp.w	#1,us_cursor
	bne.s	.x
	moveq	#1,d0
.x:	rts

us_cursorfade:				; d4.w alt: plainfadearea of the current button
	move.w	us_cursor,d0
	beq.s	.x
	move.l	d3,-(sp)
	moveq	#78,d1
	moveq	#92,d3
	cmp.w	#1,d0
	bne.s	.n
	move.w	#110,d0
	move.w	#150,d2
	bsr	plainfadearea
	move.l	(sp)+,d3
	rts
.n:	move.w	#169,d0
	move.w	#209,d2
	bsr	plainfadearea
	move.l	(sp)+,d3
.x:	rts

us_processkey2:
	move.l	d4,-(sp)
	moveq	#-3,d4			; undocursor2
	bsr	us_cursorfade
	bsr	kbd_readkey
	cmp.b	#'a',d0
	blo.s	.u
	cmp.b	#'z',d0
	bhi.s	.u
	sub.b	#32,d0
.u:	tst.b	d0
	bne.s	.a
	bsr	kbd_readkey
	cmp.b	#75,d0
	beq.s	.lr
	cmp.b	#77,d0
	bne.s	.d
.lr:	cmp.w	#1,us_cursor
	beq.s	.c2
	move.w	#1,us_cursor
	bra.s	.d
.c2:	move.w	#2,us_cursor
	bra.s	.d
.a:	cmp.b	#13,d0
	bne.s	.e
	tst.w	us_cursor
	beq.s	.d
	st	us_done
	bra.s	.d
.e:	cmp.b	#27,d0
	beq.s	.no
	cmp.b	#'N',d0
	beq.s	.no
	cmp.b	#'Y',d0
	bne.s	.d
	move.w	#1,us_cursor
	st	us_done
	bra.s	.d
.no:	move.w	#2,us_cursor
	st	us_done
.d:	moveq	#3,d4			; drawcursor2
	bsr	us_cursorfade
	bsr	kbd_mouse_xy
	move.w	d0,us_lastx
	move.w	d1,us_lasty
	move.l	(sp)+,d4
	rts

us_findmouse2:
	movem.l	d3-d4,-(sp)
	bsr	kbd_mouse_status
	move.b	d0,d3			; button
	bsr	kbd_mouse_xy
	tst.b	d3			; if ((not button) and (x = lastx)) or (y = lasty) then exit
	bne.s	.c
	cmp.w	us_lastx,d0
	beq.s	.x
.c:	cmp.w	us_lasty,d1
	beq.s	.x
	moveq	#0,d2			; newcursor
	cmp.w	#78,d1
	blt.s	.nc
	cmp.w	#92,d1
	bgt.s	.nc
	cmp.w	#110,d0
	blt.s	.nc
	cmp.w	#150,d0
	bgt.s	.n2
	moveq	#1,d2
	bra.s	.nc
.n2:	cmp.w	#169,d0
	blt.s	.nc
	cmp.w	#209,d0
	bgt.s	.nc
	moveq	#2,d2
.nc:	cmp.w	us_cursor,d2
	beq.s	.b
	move.w	d2,-(sp)
	moveq	#-3,d4
	bsr	us_cursorfade
	move.w	(sp)+,us_cursor
	moveq	#3,d4
	bsr	us_cursorfade
.b:	tst.w	us_cursor
	beq.s	.x
	tst.b	d3
	beq.s	.x
	st	us_done
.x:	movem.l	(sp)+,d3-d4
	rts

	section	data
us_ties:	dc.w	58,78,86,94,0
us_s_stats:	dc.b	10,"Ship Stats"
	even
us_labels:	dc.w	181,38
		dc.b	14,"Hull Integrity"
		even
		dc.w	184,58
		dc.b	13,"Primary Power"
		even
		dc.w	179,78
		dc.b	15,"Secondary Power"
		even
		dc.w	187,98
		dc.b	12,"Shield Level"
		even
; the panel frame: lines x1 y1 x2 y2 colour; then pixels x y colour
us_frame:	dc.w	279,25,279,117,2, 165,117,279,117,2, 165,35,278,35,2
		dc.w	165,25,279,25,10, 165,25,165,117,10, 165,36,279,36,10, -1
us_corners:	dc.w	165,35,2, 279,25,6, 165,117,6, 165,35,6, 279,36,6, -1
; processcube's highlight shapes: face, x1 y1 x2 y2 (the rest: the face's own button)
us_glow:	dc.w	19,232,145,265,174, 20,232,145,265,174, 22,232,145,265,174, 23,232,145,265,174
		dc.w	32,249,160,265,189, 35,249,160,265,189
		dc.w	1,232,145,265,159, 2,232,145,265,159
		dc.w	0,215,145,231,174, 3,215,145,231,174
		dc.w	4,232,160,265,174, 5,232,160,265,174, 40,232,160,265,174, 41,232,160,265,174
		dc.w	27,215,145,248,159, 28,215,145,248,159, -1
us_research:	dc.w	7,1,16,2,25,3,34,4,43,5,52,6,-1
us_crewtitles:	dc.b	8,"COMPUTER",0,0,0,11,"PSYCHOMETRY",11,"ENGINEERING",7,"SCIENCE",0,0,0,0
		dc.b	8,"SECURITY",0,0,0,11,"ASTROGATION",7,"MEDICAL",0,0,0,0
us_s_init:	dc.b	22,": Initiating research."
us_s_cancel:	dc.b	22,": Cancelling research."
us_s_yes:	dc.b	3,"Yes"
us_s_no:	dc.b	2,"No"
	even

	section	bss
us_sx1:		ds.w	1
us_sy1:		ds.w	1
us_sw:		ds.w	1
us_max:		ds.w	1
us_seed:	ds.w	1
us_index:	ds.w	1
us_bx:		ds.w	4
us_lastx:	ds.w	1
us_lasty:	ds.w	1
us_cursor:	ds.w	1
us_done:	ds.b	1
	even
us_num:		ds.b	12
us_s1:		ds.b	64
