; journey.s - the bridge for MAIN.PRG: starter.pas after the save is loaded (initializedata,
; loaddata, the cube) and journey.pas (the main loop, the text box, the cube's rotations, alert
; modes, the clock). Mode MAIN (tools/mkmain.py): the bridge is composed at run time from
; DATA\MAIN.CHK and CLOUD.CHK, its bands come from MAIN.ISP.
;
; bridge         starter.pas journeyon from 'reload:' on; never returns (exit 4 at quit)
; print          in: a0 = Pascal string: journey.pas print (text box, word wrap)
; println        journey.pas println (scrolls the text box)
; shadowprint / shadowprintln   the same without drawing
; displaytextbox in: d0.w = 1: scroll it (7 steps of delay(tslice div 3))
; setalertmode   in: d0.w mode (0 rest, 1 alert, 2 combat), d1.w = 1: do the shields too
; showtime / addtime
; (all trash d0-d2/a0-a2)

SHLD_LOWERED	equ	1		; ship.shieldopt[] (1-based)
SHLD_ALERT	equ	2
SHLD_COMBAT	equ	3
TXT_LINE	equ	31		; textdisplay: array[0..30] of string[30]
FADE_MUL_JOURNEY equ	2
MAXIDLE2	equ	2*750

	section	text
; ---------------------------------------------------------------
bridge:
.reload:
	bsr	mousehide
	bsr	initializedata
	bsr	getback2
	bsr	showtime
	bsr	setcube
	clr.w	GS_CUBE(a6)		; cube := 0; c := 0; ecl := 0; cursorx := 1; command := 0
	clr.w	GS_C(a6)
	clr.w	GS_ECL(a6)
	move.w	#1,GS_CURSORX(a6)
	clr.w	GS_COMMAND(a6)
	st	GS_DONE(a6)
	bsr	cleartextdisplay
	bsr	loaddata
	tst.b	GS_SHOWPLANET(a6)
	bne.s	.sp
	bsr	checkstats
.sp:	bsr	showcube
	move.w	#45,GS_TCOLOR(a6)
	clr.w	GS_BKCOLOR(a6)
	bsr	jy_cubeface
	move.w	#3,GS_BKCOLOR(a6)
	bsr	mouseshow
	tst.b	GS_SHOWPLANET(a6)
	bne.s	.sp2
	moveq	#1,d0			; deep space: the star map
	bsr	readystarmap
.sp2:	bsr	checkpendingevent
	bsr	readystatus
	bsr	mainloop
	tst.b	GS_RELOADING(a6)
	bne	.reload
.flush:	bsr	kbd_keypressed		; while fastkeypressed do readkey
	beq.s	.q
	bsr	kbd_readkey
	bra.s	.flush
.q:	moveq	#4,d0			; closegraph; halt(4)
	bra	sys_exit

; printxy(208,128,cubefaces[cube])
jy_cubeface:
	move.w	GS_CUBE(a6),d0
	mulu	#12,d0
	lea	jy_cubefaces,a0
	add.w	d0,a0
	move.w	#208,d0
	move.w	#128,d1
	bra	printxy

; starter.pas initializedata
initializedata:
	sf	GS_TARGETREADY(a6)
	sf	GS_PANELON(a6)
	sf	GS_SHOWPLANET(a6)
	clr.w	GS_BACKGRX(a6)
	clr.w	GS_BACKGRY(a6)
	clr.w	GS_TARGET(a6)
	clr.l	GS_T1(a6)		; t1 := 0; t2 := 0 (reals)
	clr.l	GS_T1+4(a6)
	clr.l	GS_T2(a6)
	clr.l	GS_T2+4(a6)
	move.w	#25,GS_TEXTINDEX(a6)
	clr.l	GS_STATCOLORS(a6)
	sf	GS_RELOADING(a6)
	clr.w	GS_LIGHTINDEX(a6)
	clr.w	GS_BATINDEX(a6)
	move.w	#1,GS_GLOWINDEX(a6)
	moveq	#-8,d0			; fadestopmod(-FADEFULL_STEP, FADEFULL_DELAY)
	moveq	#20,d1
	bsr	fadestopmod
	st	GS_PALETTEDIRTY(a6)
	moveq	#-64,d0
	bsr	fadestep
	bsr	orc_dump		; loadscreen(main, @screen)
	lea	jy_mode,a0
	bsr	ms_load
	bcs	fatal
	bsr	reloadbackground
	bsr	showtime
	sf	GS_QUIT(a6)
	clr.w	GS_VIEWMODE2(a6)
	clr.w	GS_VIEWMODE(a6)
	clr.w	GS_BATINDEX(a6)
	clr.w	GS_IDLETIME(a6)
	clr.w	GS_ACTION(a6)
	move.w	#31,GS_TCOLOR(a6)
	move.w	#3,GS_BKCOLOR(a6)
	lea	GS_SHIP(a6),a0
	tst.w	SHIP_SHIELD(a0)		; FIXUP shield 0 -> ID_NOSHIELD
	bne.s	.s1
	move.w	#ID_NOSHIELD,SHIP_SHIELD(a0)
.s1:	cmp.w	#ID_NOSHIELD,SHIP_SHIELD(a0)
	bne.s	.s2
	clr.w	SHIP_SHIELDLEVEL(a0)
	bra.s	.s3
.s2:	cmp.w	#ID_REFLECTIVEHULL,SHIP_SHIELD(a0)
	bne.s	.s3
	move.w	#100,SHIP_SHIELDLEVEL(a0)
.s3:	move.w	#ALRT_COMBAT,GS_ALERT(a6)	; main.png's panic button is red (combat)
	moveq	#0,d0
	move.b	SHIP_SHIELDOPT+SHLD_COMBAT-1(a0),d0
	moveq	#0,d1
	move.b	SHIP_SHIELDOPT+SHLD_LOWERED-1(a0),d1
	tst.b	SHIP_ARMED(a0)
	bne.s	.cmb
	cmp.w	SHIP_SHIELDLEVEL(a0),d0
	bne.s	.al
	cmp.w	d1,d0
	bgt.s	.cmb
.al:	moveq	#0,d0
	move.b	SHIP_SHIELDOPT+SHLD_ALERT-1(a0),d0
	cmp.w	SHIP_SHIELDLEVEL(a0),d0
	bne.s	.rest
	cmp.w	d1,d0
	ble.s	.rest
	moveq	#ALRT_ALERT,d0
	bra.s	.set
.cmb:	moveq	#ALRT_COMBAT,d0
	bra.s	.set
.rest:	moveq	#ALRT_REST,d0
.set:	moveq	#0,d1
	bsr	setalertmode
	bra	showresearchlights

; starter.pas getback2: the screen beside and below the cube, for its rotations
getback2:
	move.w	#202,d0			; back3[j-202, i-145] := screen[i, j], j 202-214, i 145-189
	lea	GS_BACK3(a6),a1
	bsr.s	.cols
	move.w	#266,d0			; back4: j 266-278
	lea	GS_BACK4(a6),a1
	bsr.s	.cols
	move.w	#215,d0			; back2[i-190] := screen[i, 215..266], i 190-199
	move.w	#190,d1
	bsr	ms_addr
	lea	GS_BACK2(a6),a1
	moveq	#10-1,d1
.r:	moveq	#52-1,d0
	move.l	a0,a2
.c:	move.b	(a2)+,(a1)+
	dbf	d0,.c
	lea	MS_W(a0),a0
	dbf	d1,.r
	rts
.cols:	movem.l	d3-d4,-(sp)		; 13 columns from x = d0, rows 145-189 -> a1 [col*52 + row]
	moveq	#13-1,d3
.cl:	move.w	d0,-(sp)
	move.w	#145,d1
	bsr	ms_addr
	move.l	a1,a2
	moveq	#45-1,d4
.cr:	move.b	(a0),(a2)+
	lea	MS_W(a0),a0
	dbf	d4,.cr
	lea	52(a1),a1
	move.w	(sp)+,d0
	addq.w	#1,d0
	dbf	d3,.cl
	movem.l	(sp)+,d3-d4
	rts

; starter.pas setcube: cubesrc, cubetar := face 0 (cube[b*15+i, a*17+j] := icons^[a*3+b, j, i])
setcube:
	move.l	GS_CUBESRC(a6),a1
	moveq	#0,d0
	bsr.s	jy_cubeimage
	move.l	GS_CUBETAR(a6),a1
	moveq	#0,d0
	; fall through
; the 45x51 picture of face d0 into a1
jy_cubeimage:
	movem.l	d3-d6,-(sp)
	mulu	#9*255,d0
	move.l	GS_ICONS(a6),a0
	add.l	d0,a0
	moveq	#0,d3			; a
.a:	moveq	#0,d4			; b
.b:	moveq	#0,d5			; j (x in the icon, 0-16)
.j:	moveq	#0,d6			; i (y, 0-14)
.i:	move.w	d4,d0			; cube[(b*15+i)*51 + a*17+j]
	mulu	#15,d0
	add.w	d6,d0
	mulu	#51,d0
	move.w	d3,d1
	mulu	#17,d1
	add.w	d1,d0
	add.w	d5,d0
	move.w	d3,d1			; icons^[base + a*3+b][j][i]
	mulu	#3,d1
	add.w	d4,d1
	mulu	#255,d1
	move.w	d5,d2
	mulu	#15,d2
	add.w	d2,d1
	add.w	d6,d1
	move.b	0(a0,d1.l),0(a1,d0.l)
	addq.w	#1,d6
	cmp.w	#15,d6
	bne.s	.i
	addq.w	#1,d5
	cmp.w	#17,d5
	bne.s	.j
	addq.w	#1,d4
	cmp.w	#3,d4
	bne.s	.b
	addq.w	#1,d3
	cmp.w	#3,d3
	bne.s	.a
	movem.l	(sp)+,d3-d6
	rts

; journey.pas getcube(src, tar d0.w): cubesrc := cubetar; cubetar := face tar
getcube:
	move.w	d0,-(sp)
	move.l	GS_CUBETAR(a6),a0
	move.l	GS_CUBESRC(a6),a1
	move.w	#2295-1,d0
.c:	move.b	(a0)+,(a1)+
	dbf	d0,.c
	move.w	(sp)+,d0
	move.l	GS_CUBETAR(a6),a1
	bra	jy_cubeimage

; starter.pas showcube: the cube appears column by column (the original's xor lines from
; (240,167) to each new pixel are drawn and erased at once: only their delays remain)
showcube:
	movem.l	d3-d4,-(sp)
	moveq	#0,d4			; j
.j:	move.w	d4,d0
	add.w	#215,d0
	move.w	#145,d1
	bsr	ms_addr
	move.l	GS_CUBETAR(a6),a1
	add.w	d4,a1
	moveq	#45-1,d0
.i:	move.b	(a1),(a0)
	lea	51(a1),a1
	lea	MS_W(a0),a0
	dbf	d0,.i
	move.w	d4,d0
	add.w	#215,d0
	move.w	#145,d1
	move.w	d0,d2
	move.w	#189,d3
	bsr	ms_dirty
	move.w	GS_TSLICE(a6),d0	; 45 x delay(tslice div 32)
	lsr.w	#5,d0
	mulu	#45,d0
	bsr	delay
	addq.w	#1,d4
	cmp.w	#51,d4
	bne.s	.j
	movem.l	(sp)+,d3-d4
	rts

; starter.pas cleartextdisplay
cleartextdisplay:
	move.l	GS_TEXTDISPLAY(a6),a0
	moveq	#31-1,d0
.l:	move.b	#30,(a0)+
	moveq	#30-1,d1
.c:	move.b	#' ',(a0)+
	dbf	d1,.c
	dbf	d0,.l
	move.l	GS_COLORDISPLAY(a6),a0
	move.w	#930-1,d0
.z:	clr.b	(a0)+
	dbf	d0,.z
	rts

; starter.pas loaddata: the systems within 400 of the ship (nearby[]: index; x, y, z kept as
; the integer distances, the original's reals are these / 10), then the star or planet in orbit
loaddata:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	GS_NEARBY(a6),a0
	moveq	#NEARBYMAX-1,d0
.c:	clr.w	NEARBY_INDEX(a0)
	lea	NEARBY_SIZEOF(a0),a0
	dbf	d0,.c
	moveq	#0,d6			; i
	sf	GS_SHOWPLANET(a6)
	lea	GS_SYSTEMS(a6),a3
	moveq	#1,d7			; j
.s:	move.w	SYSTEM_X(a3),d3
	sub.w	GS_SHIP+SHIP_POSX(a6),d3
	move.w	SYSTEM_Y(a3),d4
	sub.w	GS_SHIP+SHIP_POSY(a6),d4
	move.w	SYSTEM_Z(a3),d5
	sub.w	GS_SHIP+SHIP_POSZ(a6),d5
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
	bgt	fatal			; NEARBY STRUCTURE OVERFLOW
	move.w	d6,d0
	subq.w	#1,d0
	mulu	#NEARBY_SIZEOF,d0
	lea	GS_NEARBY(a6),a0
	add.w	d0,a0
	move.w	d7,NEARBY_INDEX(a0)
	move.l	a0,a4			; nearby[i].x := x/10 (and y, z): reals (SSE)
	FSSE
	move.w	d3,d0
	bsr	.tenth
	lea	NEARBY_X(a4),a0
	bsr	fp_std
	move.w	d4,d0
	bsr	.tenth
	lea	NEARBY_Y(a4),a0
	bsr	fp_std
	move.w	d5,d0
	bsr	.tenth
	lea	NEARBY_Z(a4),a0
	bsr	fp_std
	bset	#0,SYSTEM_NOTES(a3)
.n:	lea	SYSTEM_SIZEOF(a3),a3
	addq.w	#1,d7
	cmp.w	#250,d7
	ble	.s
	move.w	d3,GS_X(a6)		; (the globals x, y, z keep the last system's)
	move.w	d4,GS_Y(a6)
	move.w	d5,GS_Z(a6)
	lea	GS_NEARBY(a6),a0	; nearbybackup := nearby
	lea	GS_NEARBYBACKUP(a6),a1
	move.w	#NEARBYARRAY_SIZEOF/2-1,d0
.b:	move.w	(a0)+,(a1)+
	dbf	d0,.b
	bsr	jy_findhere		; d0 = nearby slot of the system the ship is at (0: none)
	tst.w	d0
	beq.s	.x
	subq.w	#1,d0
	mulu	#NEARBY_SIZEOF,d0
	lea	GS_NEARBY(a6),a0
	move.w	NEARBY_INDEX(a0,d0.w),d0
	bsr	findfirstplanet
	add.w	GS_SHIP+SHIP_ORBITING(a6),d0
	move.w	d0,GS_CURPLAN(a6)
	tst.w	GS_SHIP+SHIP_ORBITING(a6)
	bne.s	.pl
	bsr	readystar
	bra.s	.x
.pl:	bsr	readyplanet
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts
.abs:	tst.w	d0
	bpl.s	.a
	neg.w	d0
.a:	rts
.tenth:	ext.l	d0			; push d0.w / 10
	bsr	fp_ldi
	FLDI	10
	bra	fp_div

; the first nearby slot (1-20) whose system is at the ship's position, or 0
jy_findhere:
	lea	GS_NEARBY(a6),a1
	moveq	#1,d1
.l:	move.w	NEARBY_INDEX(a1),d0	; systems[nearby[j].index] (index 0: systems[0], i.e. the
	subq.w	#1,d0			; record before the array: never at the ship in practice)
	mulu	#SYSTEM_SIZEOF,d0
	lea	GS_SYSTEMS(a6),a0
	add.l	d0,a0
	move.w	SYSTEM_X(a0),d0
	cmp.w	GS_SHIP+SHIP_POSX(a6),d0
	bne.s	.n
	move.w	SYSTEM_Y(a0),d0
	cmp.w	GS_SHIP+SHIP_POSY(a6),d0
	bne.s	.n
	move.w	SYSTEM_Z(a0),d0
	cmp.w	GS_SHIP+SHIP_POSZ(a6),d0
	bne.s	.n
	move.w	d1,d0
	rts
.n:	lea	NEARBY_SIZEOF(a1),a1
	addq.w	#1,d1
	cmp.w	#NEARBYMAX,d1
	ble.s	.l
	moveq	#0,d0
	rts

; starter.pas checkpendingevent: the events of the system the ship is at (not in orbit)
checkpendingevent:
	movem.l	d3/a3,-(sp)
	bsr	jy_findhere
	tst.w	d0
	beq.s	.x
	tst.w	GS_SHIP+SHIP_ORBITING(a6)
	bne.s	.x
	subq.w	#1,d0
	mulu	#NEARBY_SIZEOF,d0
	lea	GS_NEARBY(a6),a0
	move.w	NEARBY_INDEX(a0,d0.w),d3
	lea	jy_eventsystems,a3
.e:	move.w	(a3)+,d0
	bmi.s	.x
	move.w	(a3)+,d1
	cmp.w	d0,d3
	bne.s	.e
	move.w	d1,d0
	bsr	event
	bra.s	.e
.x:	movem.l	(sp)+,d3/a3
	rts

; ---------------------------------------------------------------
; the text box: journey.pas printstring (into screen2), displaytextbox, println, print
; printstring(x1 d0, y1 d1, line d2): the 30 characters of textdisplay^[line] in their colours
printstring:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	GS_TCOLOR(a6),-(sp)
	move.w	d0,d5			; x1
	addq.w	#4,d5
	move.w	d1,d6			; y1
	move.l	GS_TEXTDISPLAY(a6),a5
	mulu	#TXT_LINE,d2
	lea	1(a5,d2.w),a5		; s[1]
	move.l	GS_COLORDISPLAY(a6),a3
	divu	#TXT_LINE,d2		; (line back)
	mulu	#30,d2
	add.w	d2,a3
	moveq	#0,d0			; the game font
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_FONT_-1(a6),d0
	cmp.w	#2,d0
	bls.s	.f
	moveq	#0,d0
.f:	mulu	#82*3,d0
	lea	txt_font-3,a4
	add.w	d0,a4
	move.l	GS_SCREEN2(a6),a2
	moveq	#30-1,d7
.ch:	moveq	#0,d2
	move.b	(a3)+,d2		; tcolor := colordisplay^[snum, j]
	moveq	#0,d0
	move.b	(a5)+,d0
	bsr	jy_letter		; d0 = glyph 1..82
	mulu	#3,d0
	lea	0(a4,d0.w),a1
	move.w	d6,d0			; screen2 (x1+1, y1+1)
	addq.w	#1,d0
	mulu	#MS_W,d0
	add.w	d5,d0
	addq.w	#1,d0
	lea	0(a2,d0.l),a0
	move.w	GS_BKCOLOR(a6),d3
	moveq	#0,d4			; row
.row:	move.w	d4,d0
	lsr.w	#1,d0
	move.b	0(a1,d0.w),d0
	btst	#0,d4
	bne.s	.lo
	lsr.b	#4,d0
.lo:	moveq	#4-1,d1
.px:	btst	#3,d0
	beq.s	.bg
	move.b	d2,(a0)+
	bra.s	.nx
.bg:	cmp.w	#255,d3
	bhs.s	.tr
	move.b	d3,(a0)+
	bra.s	.nx
.tr:	addq.l	#1,a0
.nx:	add.b	d0,d0
	dbf	d1,.px
	lea	MS_W-4(a0),a0
	subq.w	#2,d2
	addq.w	#1,d4
	cmp.w	#6,d4
	bne.s	.row
	addq.w	#5,d5			; x1 := x1 + 5; screen2^[y1+1..6, x1] := bkcolor
	move.w	d6,d0
	addq.w	#1,d0
	mulu	#MS_W,d0
	add.w	d5,d0
	lea	0(a2,d0.l),a0
	moveq	#6-1,d0
.gap:	move.b	d3,(a0)
	lea	MS_W(a0),a0
	dbf	d0,.gap
	dbf	d7,.ch
	move.w	(sp)+,GS_TCOLOR(a6)
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; printstring's character -> glyph: a-z, A-Z, ' '..'"', ''''..'?', '%'; else 1
jy_letter:
	cmp.b	#'a',d0
	blo.s	.u
	cmp.b	#'z',d0
	bhi.s	.e
	sub.w	#40,d0
	rts
.u:	cmp.b	#'A',d0
	blo.s	.s
	cmp.b	#'Z',d0
	bhi.s	.e
	sub.w	#36,d0
	rts
.s:	cmp.b	#' ',d0
	blo.s	.e
	cmp.b	#'"',d0
	bhi.s	.q
	sub.w	#31,d0
	rts
.q:	cmp.b	#'%',d0
	bne.s	.ap
	moveq	#55,d0
	rts
.ap:	cmp.b	#$27,d0
	blo.s	.e
	cmp.b	#'?',d0
	bhi.s	.e
	sub.w	#35,d0
	rts
.e:	moveq	#1,d0
	rts

; screen[151..186, 11..160] := screen2^[151+d0 .., 11..160]
jy_textcopy:
	movem.l	d3/a3,-(sp)
	move.w	d0,d3
	move.l	GS_SCREEN2(a6),a1
	move.w	#151,d0
	add.w	d3,d0
	mulu	#MS_W,d0
	add.l	d0,a1
	lea	11(a1),a1
	moveq	#11,d0
	move.w	#151,d1
	bsr	ms_addr
	moveq	#36-1,d1
.r:	move.l	a0,a2
	move.l	a1,a3
	move.w	#150-1,d0
.c:	move.b	(a3)+,(a2)+
	dbf	d0,.c
	lea	MS_W(a0),a0
	lea	MS_W(a1),a1
	dbf	d1,.r
	moveq	#11,d0
	move.w	#151,d1
	move.w	#160,d2
	move.w	#186,d3
	bsr	ms_dirty
	movem.l	(sp)+,d3/a3
	rts

displaytextbox:
	movem.l	d3-d4,-(sp)
	move.w	d0,d4			; scrollit
	cmp.w	#1,GS_CURSORX(a6)
	ble.s	.c1
	move.w	GS_TEXTINDEX(a6),d3	; for i2 := textindex to textindex+5
.l1:	moveq	#9,d0
	move.w	d3,d1
	sub.w	GS_TEXTINDEX(a6),d1
	mulu	#6,d1
	add.w	#150,d1
	move.w	d3,d2
	bsr	printstring
	addq.w	#1,d3
	move.w	GS_TEXTINDEX(a6),d0
	addq.w	#5,d0
	cmp.w	d0,d3
	ble.s	.l1
	bsr	mousehide
	moveq	#0,d0
	bsr	jy_textcopy
	bra.s	.bar
.c1:	move.w	GS_TEXTINDEX(a6),d3	; for i2 := textindex-1 to textindex+5
	subq.w	#1,d3
.l2:	moveq	#9,d0
	move.w	d3,d1
	sub.w	GS_TEXTINDEX(a6),d1
	addq.w	#1,d1
	mulu	#6,d1
	add.w	#150,d1
	move.w	d3,d2
	bsr	printstring
	addq.w	#1,d3
	move.w	GS_TEXTINDEX(a6),d0
	addq.w	#5,d0
	cmp.w	d0,d3
	ble.s	.l2
	bsr	mousehide
	tst.w	d4
	beq.s	.ns
	moveq	#0,d3			; scroll: 7 steps
.sc:	move.w	d3,d0
	bsr	jy_textcopy
	bsr	ms_flush
	move.w	GS_TSLICE(a6),d0
	ext.l	d0
	divu	#3,d0
	bsr	delay
	addq.w	#1,d3
	cmp.w	#7,d3
	bne.s	.sc
	bra.s	.bar
.ns:	moveq	#0,d0
	bsr	jy_textcopy
.bar:	move.w	#163,d0			; the scroll bar: rows 158-182 in 2, the thumb in 86
	move.w	#158,d1
	move.w	#168,d2
	move.w	#182,d3
	moveq	#2,d4
	bsr	ms_bar
	move.w	#163,d0
	move.w	#157,d1
	add.w	GS_TEXTINDEX(a6),d1
	move.w	#168,d2
	move.w	d1,d3
	moveq	#86,d4
	bsr	ms_bar
	bsr	mouseshow
	movem.l	(sp)+,d3-d4
	rts

shadowprintln:
	move.w	#1,GS_CURSORX(a6)
	move.l	GS_TEXTDISPLAY(a6),a0	; move(textdisplay^[j+1], textdisplay^[j], 30) for j 0..29
	moveq	#30-1,d0
.l:	moveq	#30-1,d1
	move.l	a0,a1
.c:	move.b	TXT_LINE(a1),(a1)+
	dbf	d1,.c
	lea	TXT_LINE(a0),a0
	dbf	d0,.l
	moveq	#TXT_LINE-1,d0		; fillchar(textdisplay^[30], 32, 30): the line becomes 30
.f:	move.b	#30,(a0)+		; characters chr(30) (shown blank)
	dbf	d0,.f
	move.l	GS_COLORDISPLAY(a6),a0
	move.w	#30*30-1,d0
.cc:	move.b	30(a0),(a0)+
	dbf	d0,.cc
	moveq	#30-1,d0
.cz:	clr.b	(a0)+
	dbf	d0,.cz
	rts

println:
	bsr	shadowprintln
	moveq	#1,d0
	bra	displaytextbox

print:
	sf	jy_shadow
	bsr	jy_printx
	moveq	#1,d0
	bra	displaytextbox

shadowprint:
	st	jy_shadow
	; fall through
; the body of print / shadowprint (word wrap; the recursion draws or not, by jy_shadow)
jy_printx:
	movem.l	d3-d5/a3,-(sp)
	move.l	a0,a3
	move.w	#25,GS_TEXTINDEX(a6)
	move.w	GS_TCOLOR(a6),d5	; color
	moveq	#0,d3
	move.b	(a3),d3			; length(s)
	move.w	d3,d0
	add.w	GS_CURSORX(a6),d0
	cmp.w	#30,d0
	ble	.fits
	moveq	#31,d4			; maxsize := 31 - cursorx; repeat dec until ' ', '.', ',' or 0
	sub.w	GS_CURSORX(a6),d4
.m:	subq.w	#1,d4
	move.b	0(a3,d4.w),d0
	cmp.b	#' ',d0
	beq.s	.mf
	cmp.b	#'.',d0
	beq.s	.mf
	cmp.b	#',',d0
	beq.s	.mf
	tst.w	d4
	bne.s	.m
.mf:	tst.w	d4
	bne.s	.split
	bsr	jy_println		; println; print(s)
	move.l	a3,a0
	bsr	jy_print
	bra	.x
.split:	lea	jy_s1,a0		; s1 := copy(s, 1, maxsize) (string[30])
	move.b	d4,(a0)+
	lea	1(a3),a1
	move.w	d4,d0
	subq.w	#1,d0
.c1:	move.b	(a1)+,(a0)+
	dbf	d0,.c1
	move.w	d3,d0			; s2 := copy(s, maxsize+1, length) (string[100])
	sub.w	d4,d0
	move.w	d0,-(sp)		; (s2 on the stack: the recursion reuses jy_s1)
	lea	-102(sp),sp
	move.l	sp,a0
	move.b	d0,(a0)+
	subq.w	#1,d0
	bmi.s	.c2x
.c2:	move.b	(a1)+,(a0)+
	dbf	d0,.c2
.c2x:	lea	jy_s1,a0
	bsr	jy_print
	bsr	jy_println
	move.w	d5,GS_TCOLOR(a6)
	move.l	sp,a0
	bsr	jy_print
	lea	102(sp),sp
	addq.l	#2,sp
	bra.s	.x
.fits:	move.l	GS_TEXTDISPLAY(a6),a0	; textdisplay^[30, cursorx+j-1] := s[j]
	lea	30*TXT_LINE(a0),a0
	add.w	GS_CURSORX(a6),a0
	move.l	GS_COLORDISPLAY(a6),a1	; colordisplay^[30, ...] := tcolor
	lea	30*30-1(a1),a1
	add.w	GS_CURSORX(a6),a1
	lea	1(a3),a2
	move.w	d3,d0
	subq.w	#1,d0
	bmi.s	.fe
.fc:	move.b	(a2)+,(a0)+
	move.b	d5,(a1)+
	dbf	d0,.fc
.fe:	add.w	d3,GS_CURSORX(a6)
.x:	movem.l	(sp)+,d3-d5/a3
	rts

; inside print's recursion: the drawing variant or the shadow one
jy_print:
	tst.b	jy_shadow
	bne	jy_printx
	bsr	jy_printx
	moveq	#1,d0
	bra	displaytextbox
jy_println:
	tst.b	jy_shadow
	bne	shadowprintln
	bra	println

; ---------------------------------------------------------------
; journey.pas rotatecube2 (sideways) / rotatecube (up-down) to face d1 from d0; d2.b fkey
rotatecube:
	movem.l	d3-d5,-(sp)
	move.w	d0,d3			; src
	move.w	d1,d4			; tar
	move.b	d2,d5			; fkey
	move.w	d3,d0			; opposite faces (tar+src = 5): via a neighbour first
	add.w	d4,d0
	cmp.w	#5,d0
	bne.s	.r4
	move.w	d4,d1
	cmp.w	#2,d4
	beq.s	.m2
	cmp.w	#3,d4
	beq.s	.m2
	tst.w	d4
	ble.s	.p1
	subq.w	#1,d1
	bra.s	.go
.m2:	subq.w	#2,d1
	bra.s	.go
.p1:	addq.w	#1,d1
.go:	move.w	d3,d0
	move.b	d5,d2
	bsr	rotatecube2
.r4:	moveq	#4,d0			; if random(4) = 0 then rotatecube2
	bsr	mt_random
	tst.w	d0
	bne.s	.v
	move.w	d3,d0
	move.w	d4,d1
	move.b	d5,d2
	bsr	rotatecube2
	bra	.x
.v:	move.w	d4,d0
	bsr	getcube
	tst.b	GS_SHIP+SHIP_OPTIONS+OPT_ANIMATION-1(a6)
	beq.s	.inst
	tst.b	d5
	bne.s	.inst
	bsr	mousehide		; back1 := screen[133..144, 215..266]
	move.w	#215,d0
	move.w	#133,d1
	bsr	ms_addr
	lea	GS_BACK1(a6),a1
	moveq	#12-1,d1
.b1:	moveq	#52-1,d0
	move.l	a0,a2
.b1c:	move.b	(a2)+,(a1)+
	dbf	d0,.b1c
	lea	MS_W(a0),a0
	dbf	d1,.b1
	lea	jy_cuberows,a0		; the 20 frames
	moveq	#20-1,d0
	bsr	jy_cubeanim_v
	bsr	jy_cubetar
	move.w	#215,d0			; screen[190, 215..266] := back2[0]
	move.w	#190,d1
	bsr	ms_addr
	lea	GS_BACK2(a6),a1
	moveq	#52-1,d0
.b2:	move.b	(a1)+,(a0)+
	dbf	d0,.b2
	move.w	#215,d0
	move.w	#190,d1
	move.w	#266,d2
	move.w	#190,d3
	bsr	ms_dirty
	bsr	mouseshow
	move.w	d4,GS_CUBE(a6)
	bra.s	.x
.inst:	bsr	mousehide
	bsr	jy_cubetar
	bsr	mouseshow
	move.w	d4,GS_CUBE(a6)
.x:	movem.l	(sp)+,d3-d5
	rts

rotatecube2:
	movem.l	d3-d5,-(sp)
	move.w	d1,d4
	move.b	d2,d5
	move.w	d1,d0
	bsr	getcube
	tst.b	GS_SHIP+SHIP_OPTIONS+OPT_ANIMATION-1(a6)
	beq.s	.inst
	tst.b	d5
	bne.s	.inst
	bsr	mousehide
	lea	jy_cubecols,a0		; the 21 frames
	moveq	#21-1,d0
	bsr	jy_cubeanim_h
.inst:	bsr	mousehide		; (also the end of the animation)
	bsr	jy_cubetar
	bsr	mouseshow
	move.w	d4,GS_CUBE(a6)
	movem.l	(sp)+,d3-d5
	rts

; screen[145..189, 215..265] := cubetar
jy_cubetar:
	move.l	d3,-(sp)
	move.w	#215,d0
	move.w	#145,d1
	bsr	ms_addr
	move.l	GS_CUBETAR(a6),a1
	moveq	#45-1,d1
.r:	moveq	#51-1,d0
	move.l	a0,a2
.c:	move.b	(a1)+,(a2)+
	dbf	d0,.c
	lea	MS_W(a0),a0
	dbf	d1,.r
	move.w	#215,d0
	move.w	#145,d1
	move.w	#265,d2
	move.w	#189,d3
	bsr	ms_dirty
	move.l	(sp)+,d3
	rts

; the sideways animation: d0+1 frames of 77 columns (x 202-278) from CUBE.DAT at a0
jy_cubeanim_h:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	a0,a5
	move.w	d0,d7
.fr:	moveq	#0,d6			; column 0..76
.col:	moveq	#0,d0
	move.b	(a5)+,d0		; code
	moveq	#0,d1
	move.b	(a5)+,d1		; index
	tst.b	d0
	beq.s	.nc
	move.w	d1,d2			; source column base, stride
	cmp.b	#1,d0
	bne.s	.s2
	move.l	GS_CUBETAR(a6),a1
	bra.s	.cs
.s2:	cmp.b	#2,d0
	bne.s	.s3
	move.l	GS_CUBESRC(a6),a1
.cs:	add.w	d1,a1			; cube column: rows 0..44, stride 51
	moveq	#51,d3
	bra.s	.cp
.s3:	lea	GS_BACK3(a6),a1
	cmp.b	#3,d0
	beq.s	.bk
	lea	GS_BACK4(a6),a1
.bk:	mulu	#52,d1			; back3/4[col, row]: 52 per column
	add.w	d1,a1
	moveq	#1,d3
.cp:	move.w	d6,d0
	add.w	#202,d0
	move.w	#145,d1
	bsr	ms_addr
	moveq	#45-1,d0
.px:	move.b	(a1),(a0)
	add.w	d3,a1
	lea	MS_W(a0),a0
	dbf	d0,.px
.nc:	addq.w	#1,d6
	cmp.w	#77,d6
	bne.s	.col
	move.w	#202,d0
	move.w	#145,d1
	move.w	#278,d2
	move.w	#189,d3
	bsr	ms_dirty
	bsr	mouseshow
	move.w	GS_TSLICE(a6),d0	; delay(tslice div 4)
	lsr.w	#2,d0
	bsr	delay
	bsr	mousehide
	dbf	d7,.fr
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; the up-down animation: d0+1 frames of 67 rows (y 133-199) from CUBE.DAT at a0
jy_cubeanim_v:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	a0,a5
	move.w	d0,d7
.fr:	moveq	#0,d6			; row 0..66
.row:	moveq	#0,d0
	move.b	(a5)+,d0
	moveq	#0,d1
	move.b	(a5)+,d1
	tst.b	d0
	beq.s	.nr
	moveq	#51,d2			; width
	cmp.b	#1,d0
	bne.s	.s2
	move.l	GS_CUBETAR(a6),a1
	bra.s	.cs
.s2:	cmp.b	#2,d0
	bne.s	.s3
	move.l	GS_CUBESRC(a6),a1
.cs:	mulu	#51,d1
	add.w	d1,a1
	bra.s	.cp
.s3:	lea	GS_BACK1(a6),a1
	cmp.b	#3,d0
	beq.s	.bk
	lea	GS_BACK2(a6),a1
.bk:	mulu	#52,d1
	add.w	d1,a1
	moveq	#52,d2
.cp:	move.w	#215,d0
	move.w	d6,d1
	add.w	#133,d1
	bsr	ms_addr
	subq.w	#1,d2
.px:	move.b	(a1)+,(a0)+
	dbf	d2,.px
.nr:	addq.w	#1,d6
	cmp.w	#67,d6
	bne.s	.row
	move.w	#215,d0
	move.w	#133,d1
	move.w	#266,d2
	move.w	#199,d3
	bsr	ms_dirty
	bsr	mouseshow
	move.w	GS_TSLICE(a6),d0
	lsr.w	#2,d0
	bsr	delay
	bsr	mousehide
	dbf	d7,.fr
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; journey.pas msg1(m): the menu name of a cube button; msg2: the face's name
msg1:
	move.w	d0,d1
	add.w	#100,d1
	cmp.w	jy_msg,d1
	beq.s	.x
	move.w	d1,jy_msg
	move.w	#45,GS_TCOLOR(a6)
	clr.w	GS_BKCOLOR(a6)
	mulu	#12,d0
	move.w	d0,-(sp)
	bsr	mousehide		; (trashes d0-d2/a0-a2)
	move.w	(sp)+,d0
	lea	jy_menunames,a0
	add.w	d0,a0
	move.w	#208,d0
	move.w	#128,d1
	bsr	printxy
	bsr	mouseshow
	move.w	#3,GS_BKCOLOR(a6)
.x:	rts

msg2:
	move.w	GS_CUBE(a6),d0
	cmp.w	jy_msg,d0
	beq.s	.x
	move.w	#45,GS_TCOLOR(a6)
	clr.w	GS_BKCOLOR(a6)
	bsr	mousehide
	bsr	jy_cubeface
	bsr	mouseshow
	move.w	#3,GS_BKCOLOR(a6)
	move.w	GS_CUBE(a6),jy_msg
.x:	rts

; ---------------------------------------------------------------
; journey.pas setalertmode(mode d0, do_shields d1)
setalertmode:
	movem.l	d3-d5/a3,-(sp)
	move.w	d0,d3			; mode
	move.w	d1,d4			; do_shields
	lea	GS_SHIP(a6),a3
	moveq	#0,d5			; shield_wanted
	cmp.w	#ID_NOSHIELD,SHIP_SHIELD(a3)
	bgt.s	.w
	clr.w	SHIP_SHIELDLEVEL(a3)
	bra.s	.wd
.w:	lea	SHIP_SHIELDOPT(a3),a0	; shieldopt[mode+1]
	move.b	0(a0,d3.w),d5
.wd:	tst.b	SHIP_ARMED(a3)		; armed: stay in combat
	beq.s	.na
	moveq	#ALRT_COMBAT,d3
.na:	tst.w	d4			; not do_shields and shields at combat level: combat
	bne.s	.ds
	moveq	#0,d0
	move.b	SHIP_SHIELDOPT+SHLD_COMBAT-1(a3),d0
	cmp.w	SHIP_SHIELDLEVEL(a3),d0
	bne.s	.ds
	moveq	#ALRT_COMBAT,d3
.ds:	move.w	GS_ALERT(a6),d0		; the panic button: 48 rest, 112 alert, 80 combat
	cmp.w	d3,d0
	beq.s	.same
	lea	jy_alertcol,a0
	move.b	0(a0,d0.w),d1
	move.b	0(a0,d3.w),d0
	ext.w	d0
	ext.w	d1
	and.w	#$ff,d0
	and.w	#$ff,d1
	sub.w	d1,d0
	move.w	d0,-(sp)
	moveq	#0,d0			; plainfadearea(0,184,7,199,new-alt)
	move.w	#184,d1
	moveq	#7,d2
	move.w	d3,-(sp)
	move.w	#199,d3
	move.w	d4,-(sp)
	move.w	4(sp),d4
	bsr	plainfadearea
	move.w	(sp)+,d4
	move.w	(sp)+,d3
	addq.l	#2,sp
.same:	move.w	d3,GS_ALERT(a6)
	tst.w	d4
	beq.s	.x
	cmp.w	SHIP_SHIELDLEVEL(a3),d5
	beq.s	.x
	cmp.b	#25,SHIP_DAMAGES+DMG_SHIELD-1(a3)
	bls.s	.ok
	move.w	#94,GS_TCOLOR(a6)
	bsr	println
	clr.w	SHIP_SHIELDLEVEL(a3)
	cmp.b	#59,SHIP_DAMAGES+DMG_SHIELD-1(a3)
	bls.s	.uns
	lea	jy_s_compromised,a0
	bsr	print
	bra.s	.x
.uns:	lea	jy_s_unstable,a0
	bsr	print
	moveq	#40,d0
	bsr	mt_random
	add.w	#20,d0
	moveq	#0,d1
	move.b	SHIP_DAMAGES+DMG_SHIELD-1(a3),d1
	cmp.w	d1,d0
	bge.s	.ok
	lea	jy_s_failadjust,a0
	bsr	print
	bra.s	.x
.ok:	move.w	d5,SHIP_SHIELDLEVEL(a3)
.x:	movem.l	(sp)+,d3-d5/a3
	rts

; ---------------------------------------------------------------
showtime:
	movem.l	d3/a3,-(sp)
	lea	jy_time,a3		; strs[3]/strs[1]/strs[2] strs[4]:strs[5]
	clr.b	(a3)
	moveq	#3,d0
	bsr	.part
	lea	jy_slash,a1
	bsr	.cat
	moveq	#1,d0
	bsr	.part
	lea	jy_slash,a1
	bsr	.cat
	moveq	#2,d0
	bsr	.part
	lea	jy_space,a1
	bsr	.cat
	moveq	#4,d0
	bsr	.part
	lea	jy_colon,a1
	bsr	.cat
	moveq	#5,d0
	bsr	.part
	move.w	#44,GS_TCOLOR(a6)
	clr.w	GS_BKCOLOR(a6)
	moveq	#42,d0
	move.w	#193,d1
	move.l	a3,a0
	bsr	printxy
	move.w	#3,GS_BKCOLOR(a6)
	movem.l	(sp)+,d3/a3
	rts
.part:	move.w	d0,d3			; str(stardate[j]:2 or :5), leading '0' when small
	add.w	d0,d0
	lea	GS_SHIP+SHIP_STARDATE-2(a6),a0
	move.w	0(a0,d0.w),d0
	ext.l	d0
	move.l	d0,-(sp)
	moveq	#2,d1
	cmp.w	#3,d3
	bne.s	.w
	moveq	#5,d1
.w:	lea	jy_num,a0
	bsr	int_str
	move.l	(sp)+,d0
	cmp.w	#3,d3
	bne.s	.two
	cmp.l	#10000,d0
	bge.s	.cp
	move.b	#'0',jy_num+1
	bra.s	.cp
.two:	cmp.l	#10,d0
	bge.s	.cp
	move.b	#'0',jy_num+1
.cp:	lea	jy_num,a1
.cat:	move.l	a3,a0
	bra	pstr_cat

addtime:
	moveq	#0,d0			; GameTick(False, 1)
	moveq	#1,d1
	bsr	gametick
	bsr	showtime
	st	GS_ANYCHANGE(a6)
	rts

; ---------------------------------------------------------------
; journey.pas mainloop
mainloop:
.l:	moveq	#8,d0			; fadestep(FADESTEP_STEP)
	bsr	fadestep
	bsr	jy_findmouse
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	jy_processkey
.nk:	bsr	playing			; if not playing then playmod(defaultsong)
	bne.s	.pl
	lea	jy_fn_song,a0
	bsr	playmod
.pl:	addq.w	#1,GS_IDLETIME(a6)
	cmp.w	#MAXIDLE2,GS_IDLETIME(a6)
	bne.s	.ni
	bsr	screensaver
.ni:	cmp.w	#16000,GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6)
	bge.s	.nw
	bsr	movewandering
.nw:	move.w	GS_VIEWMODE2(a6),d0
	beq.s	.vm0
	cmp.w	#1,d0
	bne.s	.vm2
	bsr	displaystarmap
	bra	.anim
.vm2:	cmp.w	#2,d0
	bne.s	.vm3
	bsr	displayhistorymap
	bra	.anim
.vm3:	cmp.w	#3,d0
	bne.s	.vm4
	bsr	displayshortscan
	bra	.anim
.vm4:	bsr	displaylongscan
	bra	.anim
.vm0:	tst.b	GS_SHOWPLANET(a6)
	beq.s	.anim
	cmp.b	#1,GS_SHIP+SHIP_OPTIONS+OPT_ANIMATION-1(a6)
	bne.s	.anim
	move.w	GS_VIEWMODE(a6),d0
	cmp.w	#8,d0
	blt.s	.vm
	cmp.w	#10,d0
	ble.s	.anim
.vm:	tst.w	GS_SHIP+SHIP_ORBITING(a6)
	bne.s	.pl2
	bsr	makestar
	bra.s	.anim
.pl2:	move.w	GS_SPHERE(a6),d0
	cmp.w	#1,d0
	bne.s	.anim			; (sphere 2: gas giants, not ported)
	move.w	GS_GLOWINDEX(a6),d0
	cmp.w	#1,d0
	bne.s	.g2
	bsr	makesphere1
	bra.s	.anim
.g2:	cmp.w	#2,d0
	bne.s	.g3
	bsr	makesphere2
	bra.s	.anim
.g3:	cmp.w	#3,d0
	bne.s	.anim
	bsr	makesphere3
.anim:	tst.b	GS_ANYCHANGE(a6)
	bne.s	.chg
	tst.w	GS_COMMAND(a6)
	ble.s	.nc
.chg:	sf	GS_ANYCHANGE(a6)
	move.w	GS_VIEWMODE(a6),d0
	bne.s	.v1
	move.w	GS_TSLICE(a6),d0	; viewmode 0: delay(tslice); anychange := true
	bsr	delay
	st	GS_ANYCHANGE(a6)
	bra.s	.vd
.v1:	cmp.w	#1,d0
	bne.s	.v2
	bsr	displaystatus
	bra.s	.vd
.v2:	cmp.w	#11,d0
	bhi.s	.vd
	lsl.w	#2,d0
	lea	jy_panels-8,a0
	move.l	0(a0,d0.w),a0
	move.w	GS_COMMAND(a6),d0
	jsr	(a0)
.vd:	clr.w	GS_COMMAND(a6)
	bsr	checkstats
.nc:	cmp.w	#10,GS_BATINDEX(a6)	; the clock: every 11th frame
	bge.s	.t
	addq.w	#1,GS_BATINDEX(a6)
	bra.s	.gl
.t:	clr.w	GS_BATINDEX(a6)
	bsr	addtime
.gl:	cmp.w	#4,GS_GLOWINDEX(a6)
	bge.s	.g1
	addq.w	#1,GS_GLOWINDEX(a6)
	bra.s	.dl
.g1:	move.w	#1,GS_GLOWINDEX(a6)
.dl:	move.w	GS_TSLICE(a6),d0	; delay(tslice*FADE_TSLICE_MUL_JOURNEY)
	mulu	#FADE_MUL_JOURNEY,d0
	bsr	delay
	tst.b	GS_QUIT(a6)
	beq	.l
	bra	stopmod

; journey.pas processkey
jy_processkey:
	clr.w	GS_IDLETIME(a6)
	bsr	kbd_readkey
	tst.b	d0
	bne	.asc
	bsr	kbd_readkey		; extended
	moveq	#0,d1
	move.b	d0,d1
	cmp.w	#72,d1
	bne.s	.k1
	move.w	#3,GS_COMMAND(a6)
	rts
.k1:	cmp.w	#75,d1
	bne.s	.k2
	move.w	#1,GS_COMMAND(a6)
	rts
.k2:	cmp.w	#77,d1
	bne.s	.k3
	move.w	#2,GS_COMMAND(a6)
	rts
.k3:	cmp.w	#80,d1
	bne.s	.k4
	move.w	#4,GS_COMMAND(a6)
	rts
.k4:	cmp.w	#59,d1			; F1-F6: the cube face
	blt.s	.k5
	cmp.w	#64,d1
	bgt.s	.k5
	sub.w	#59,d1
	cmp.w	GS_CUBE(a6),d1
	beq.s	.x
	move.w	GS_CUBE(a6),d0
	st	d2
	bsr	rotatecube
	bra	msg2
.k5:	cmp.w	#16,d1			; Alt-Q, Alt-X: quit?
	beq.s	.quit
	cmp.w	#45,d1
	bne.s	.k6
.quit:	lea	jy_s_quit,a0
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq.s	.x
	st	GS_QUIT(a6)
.x:	rts
.k6:	cmp.w	#48,d1			; Alt-B: bot control
	bne.s	.k7
	move.w	GS_CUBE(a6),d0
	moveq	#1,d1
	st	d2
	bsr	rotatecube
	moveq	#11,d0
	bra	processcube
.k7:	cmp.w	#31,d1			; Alt-S: planet scan
	bne.s	.k8
	move.w	GS_CUBE(a6),d0
	moveq	#2,d1
	st	d2
	bsr	rotatecube
	moveq	#20,d0
	bra	processcube
.k8:	cmp.w	#120,d1			; Alt-1..4 / Alt-0: an orbit of this system
	blt.s	.k9
	cmp.w	#123,d1
	ble.s	.alt
	cmp.w	#129,d1
	bne.s	.k9
.alt:	tst.b	GS_SHOWPLANET(a6)
	beq	.nosys
	moveq	#0,d2
	cmp.w	#129,d1
	beq.s	.alt0
	move.w	d1,d2
	sub.w	#119,d2
.alt0:	move.w	GS_CURPLAN(a6),d0
	bsr	jy_plansys
	move.w	d2,d1
	bra	gotoorbit
.k9:	cmp.w	#49,d1			; Alt-N / Alt-P: the next / previous orbit
	beq.s	.np
	cmp.w	#25,d1
	bne.s	.k10
.np:	tst.b	GS_SHOWPLANET(a6)
	beq.s	.nosys
	move.w	d1,-(sp)
	move.w	GS_CURPLAN(a6),d0
	bsr	getplanetorbit
	move.w	d0,d2
	move.w	(sp)+,d1
	cmp.w	#49,d1
	bne.s	.pp
	addq.w	#1,d2
	bra.s	.np2
.pp:	subq.w	#1,d2
.np2:	move.w	GS_CURPLAN(a6),d0
	bsr	jy_plansys
	move.w	d2,d1
	bra	gotoorbit
.nosys:	PRTLN
	TCOL	94
	PRT	"NAVIGATION: Not near a system."
	rts
.k10:	cmp.w	#22,d1			; Alt-U: the original's artifact shortcut
	bne.s	.k11
	moveq	#42,d0
	bsr	event
	move.w	#ID_ART_DETONATOR,d0
	st	d1
	bsr	addcargo
	moveq	#24,d0
	bsr	event
	move.w	#ID_ART_HOMING_DEVICE,d0
	st	d1
	bsr	addcargo
	moveq	#25,d0
	bsr	event
	moveq	#27,d0
	bsr	event
	moveq	#30,d0
	bsr	event
	moveq	#28,d0
	bra	event
.k11:	cmp.w	#117,d1			; the eggs (Ctrl-End, Ctrl-PgDn... Alt-7): not ported
	beq	notported
	cmp.w	#103,d1
	beq	notported
	cmp.w	#126,d1
	beq	notported
	rts
.asc:	cmp.b	#'a',d0			; upcase
	blo.s	.up
	cmp.b	#'z',d0
	bhi.s	.up
	sub.b	#32,d0
.up:	lea	jy_keys,a0
.kl:	move.b	(a0)+,d1
	beq.s	.kn
	move.b	(a0)+,d2
	cmp.b	d1,d0
	bne.s	.kl
	tst.b	d2			; d2: 1..6 = face+1 (rotate), $10+n = processcube(cube*9+n)
	bmi.s	.pc
	subq.b	#1,d2
	ext.w	d2
	cmp.w	GS_CUBE(a6),d2
	beq.s	.kx
	move.w	d2,d1
	move.w	GS_CUBE(a6),d0
	st	d2
	bra	rotatecube
.pc:	and.w	#$0f,d2
	move.w	GS_CUBE(a6),d0
	mulu	#9,d0
	add.w	d2,d0
	bra	processcube
.kn:	cmp.b	#'1',d0
	bne.s	.n2
	move.w	#6,GS_COMMAND(a6)
	rts
.n2:	cmp.b	#'2',d0
	bne.s	.n3
	move.w	#7,GS_COMMAND(a6)
	rts
.n3:	cmp.b	#'3',d0
	bne.s	.sp
	move.w	#8,GS_COMMAND(a6)
	rts
.sp:	cmp.b	#' ',d0
	bne.s	.es
	st	d0
	bra	cleanright
.es:	cmp.b	#27,d0
	bne.s	.p
	tst.w	GS_VIEWMODE2(a6)
	beq.s	.es2
	bsr	removestarmap
.es2:	st	d0
	bra	cleanright
.p:	cmp.b	#'P',d0
	bne.s	.bq
	bra	u3_panic
.bq:	cmp.b	#'`',d0
	beq	notported		; bossmode
.kx:	rts

; journey.pas findmouse (the parts of the bridge that are ported)
jy_findmouse:
	movem.l	d3-d4,-(sp)
	bsr	kbd_mouse_status
	tst.b	d0
	bne	.click
	bsr	kbd_mouse_xy		; no click: the cube's menu names under the pointer
	moveq	#0,d2
	cmp.w	#215,d0
	blt.s	.h2
	cmp.w	#231,d0
	ble.s	.hc
	moveq	#1,d2
	cmp.w	#248,d0
	ble.s	.hc
	moveq	#2,d2
	cmp.w	#265,d0
	ble.s	.hc
.h2:	bsr	.m2
	bra	.x
.hc:	moveq	#0,d3			; row 0/3/6 by y
	cmp.w	#145,d1
	blt.s	.h2
	cmp.w	#159,d1
	ble.s	.hr
	moveq	#3,d3
	cmp.w	#174,d1
	ble.s	.hr
	moveq	#6,d3
	cmp.w	#189,d1
	bgt.s	.h2
.hr:	move.w	GS_CUBE(a6),d0
	mulu	#9,d0
	add.w	d3,d0
	add.w	d2,d0
	bsr	msg1
	bra	.x
.m2:	move.w	GS_CUBE(a6),d0
	cmp.w	jy_msg,d0
	beq.s	.mx
	bsr	msg2
.mx:	rts
.click:	move.w	GS_CUBE(a6),jy_oldcube
	bsr	kbd_mouse_xy
	move.w	d0,d3
	move.w	d1,d4
	cmp.w	#184,d3			; 184-202 / 276-294: the face buttons
	blt	.c2
	cmp.w	#202,d3
	bgt.s	.c1
	moveq	#0,d1
	bra.s	.fb
.c1:	cmp.w	#276,d3
	blt.s	.c2
	cmp.w	#294,d3
	bgt.s	.c2
	moveq	#3,d1
.fb:	cmp.w	#149,d4
	blt	.cx
	cmp.w	#159,d4
	ble.s	.fr
	addq.w	#1,d1
	cmp.w	#161,d4
	blt	.cx
	cmp.w	#171,d4
	ble.s	.fr
	addq.w	#1,d1
	cmp.w	#173,d4
	blt	.cx
	cmp.w	#183,d4
	bgt	.cx
.fr:	cmp.w	GS_CUBE(a6),d1
	beq	.cx
	move.w	GS_CUBE(a6),d0
	sf	d2
	bsr	rotatecube
	bra	.cx
.c2:	cmp.w	#215,d3			; 215-265: the cube's buttons
	blt	.c3
	cmp.w	#265,d3
	bgt	.c3
	moveq	#0,d2
	cmp.w	#231,d3
	ble.s	.cc
	moveq	#1,d2
	cmp.w	#248,d3
	ble.s	.cc
	moveq	#2,d2
.cc:	moveq	#0,d1
	cmp.w	#145,d4
	blt	.cx
	cmp.w	#159,d4
	ble.s	.cr
	moveq	#3,d1
	cmp.w	#174,d4
	ble.s	.cr
	moveq	#6,d1
	cmp.w	#189,d4
	bgt	.cx
.cr:	move.w	GS_CUBE(a6),d0
	mulu	#9,d0
	add.w	d1,d0
	add.w	d2,d0
	bsr	processcube
	bra	.cx
.c3:	cmp.w	#161,d3			; 161-171: the text box's scroll bar
	blt.s	.c4
	cmp.w	#171,d3
	bgt.s	.c4
	cmp.w	#148,d4
	blt	.cx
	cmp.w	#156,d4
	bgt.s	.sb2
	cmp.w	#1,GS_TEXTINDEX(a6)
	ble.s	.sbd
	subq.w	#1,GS_TEXTINDEX(a6)
.sbd:	moveq	#0,d0
	bsr	displaytextbox
	bra	.cx
.sb2:	cmp.w	#158,d4
	blt	.cx
	cmp.w	#182,d4
	bgt.s	.sb3
	sub.w	#157,d4
	move.w	d4,GS_TEXTINDEX(a6)
	bra.s	.sbd
.sb3:	cmp.w	#185,d4
	blt	.cx
	cmp.w	#192,d4
	bgt	.cx
	cmp.w	#25,GS_TEXTINDEX(a6)
	bge.s	.sbd
	addq.w	#1,GS_TEXTINDEX(a6)
	bra.s	.sbd
.c4:	cmp.w	#8,d3			; 0-8, y > 182: the panic button
	bgt.s	.c5
	cmp.w	#182,d4
	ble	.cc0
	bsr	u3_panic
	bra	.cc0
.c5:	cmp.w	#300,d3			; 300-313: the status lights -> ship status
	blt.s	.c6
	cmp.w	#313,d3
	bgt.s	.c6
	moveq	#3,d0			; the lights at 19-38, 49-58, 69-78, 89-98 (clickcode: the egg)
	cmp.w	#19,d4
	blt	.cc0
	cmp.w	#38,d4
	ble.s	.lt
	moveq	#2,d0
	cmp.w	#49,d4
	blt.s	.cc0
	cmp.w	#58,d4
	ble.s	.lt
	moveq	#1,d0
	cmp.w	#69,d4
	blt.s	.cc0
	cmp.w	#78,d4
	ble.s	.lt
	moveq	#0,d0
	cmp.w	#89,d4
	blt.s	.cc0
	cmp.w	#98,d4
	bgt.s	.cc0
.lt:	move.w	d0,-(sp)		; (d0: the light 0-3 from the bottom, 3 = top)
	cmp.w	#1,GS_VIEWMODE(a6)
	beq.s	.lt2
	st	d0
	bsr	cleanright
	bsr	readystatus
	move.w	(sp),d0			; clickcode: lights 4, 3, 2 then 1 (bottom to top) = the egg
	bsr	jy_clickcode
.lt2:	addq.l	#2,sp
	bra	.cx
.c6:	cmp.w	#27,d3			; 27-143: the star map (viewmode2 1 or 2)
	blt.s	.cc0
	cmp.w	#143,d3
	bgt.s	.cc0
	clr.w	jy_clickcode_v
	move.w	GS_VIEWMODE2(a6),d0
	beq.s	.cx
	cmp.w	#2,d0
	bgt.s	.cx
	cmp.w	#124,d4
	bge.s	.cx
	cmp.w	#16,d4
	ble.s	.cx
	move.w	d3,d0
	move.w	d4,d1
	bsr	targetstar
	bra.s	.cx
.cc0:	clr.w	jy_clickcode_v		; (any other click: clickcode := 0)
.cx:	tst.b	GS_PANELON(a6)
	beq.s	.np
	move.w	d3,d0
	move.w	d4,d1
	bsr	jy_panelmouse
	st	GS_ANYCHANGE(a6)
.np:	move.w	GS_CUBE(a6),d0
	cmp.w	jy_oldcube,d0
	beq.s	.ni
	bsr	msg2
.ni:	clr.w	GS_IDLETIME(a6)
.x:	movem.l	(sp)+,d3-d4
	rts

; the system of planet d0 -> d0.w
jy_plansys:
	mulu	#PLANET_SIZEOF,d0
	move.l	GS_TEMPPLAN(a6),a0
	moveq	#0,d1
	move.b	-PLANET_SIZEOF+PLANET_SYSTEM(a0,d0.l),d1
	move.w	d1,d0
	rts

; clickcode (the easter egg sequence): light d0 (0 bottom .. 3 top) clicked
jy_clickcode:
	move.w	jy_clickcode_v,d1
	cmp.w	#3,d0			; top: clickcode 3 -> the egg
	bne.s	.l2
	cmp.w	#3,d1
	bne.s	.x
	clr.w	jy_clickcode_v
	bra	notported		; easteregg5
.l2:	cmp.w	#2,d0			; 49-58: 2 -> 3 else 0
	bne.s	.l1
	moveq	#0,d2
	cmp.w	#2,d1
	bne.s	.s
	moveq	#3,d2
	bra.s	.s
.l1:	cmp.w	#1,d0			; 69-78: 1 -> 2 else 0
	bne.s	.l0
	moveq	#0,d2
	cmp.w	#1,d1
	bne.s	.s
	moveq	#2,d2
	bra.s	.s
.l0:	tst.w	d1			; 89-98: 0 -> 1
	bne.s	.x
	moveq	#1,d2
.s:	move.w	d2,jy_clickcode_v
.x:	rts

; journey.pas findmouse's panel part (panelon): the top buttons give command; else by viewmode
jy_panelmouse:
	movem.l	d3-d6,-(sp)
	move.w	d0,d3			; x
	move.w	d1,d4			; y
	cmp.w	#8,d4
	ble.s	.vm
	cmp.w	#24,d4
	bge.s	.vm
	cmp.w	#153,d3
	ble.s	.vm
	cmp.w	#291,d3
	bge.s	.vm
	move.w	d3,d0			; command := (x-137) div 17
	sub.w	#137,d0
	ext.l	d0
	divs	#17,d0
	move.w	d0,GS_COMMAND(a6)
	bra	.x
.vm:	move.w	GS_VIEWMODE(a6),d0
	cmp.w	#2,d0
	bne	.v3
	tst.w	GS_VIEWLEVEL(a6)	; 2: weapons - a gun node by row
	bne	.x
	bsr	.inpanel31
	beq	.x
	move.w	d4,d5			; i := (y-32) div 7; j: the i-th node with a weapon
	sub.w	#32,d5
	ext.l	d5
	divs	#7,d5
	moveq	#1,d6
.w:	move.w	d6,d0
	lea	GS_SHIP+SHIP_GUNNODES-1(a6),a0
	tst.b	0(a0,d0.w)
	beq.s	.wn
	subq.w	#1,d5
.wn:	addq.w	#1,d6
	cmp.w	#10,d6
	bgt.s	.wd
	tst.w	d5
	bge.s	.w
.wd:	cmp.w	#11,d6
	bge	.x
	subq.w	#1,d6
	move.w	d6,GS_VIEWINDEX(a6)
	bra	.x
.v3:	cmp.w	#3,d0
	bne.s	.v4
	tst.w	GS_VIEWLEVEL(a6)	; 3: system info - the list scrolls to the row
	bne	.x
	bsr	.inpanel37
	beq	.x
	bsr	.listrow		; d5 = rows to move (-6..)
	lea	GS_TARGET(a6),a3
	moveq	#0,d6			; the target: by systems with nearby[].index <> 0
	bsr	.scrollnear
	bra	.x
.v4:	cmp.w	#4,d0
	bne	.v5
	move.w	GS_VIEWLEVEL(a6),d0	; 4: shields
	bne	.v4b
	lea	jy_shdrows,a0		; rows: (lo, hi, viewindex, set opt)
.sr:	move.w	(a0)+,d1
	bmi	.x
	move.w	(a0)+,d2
	move.w	(a0)+,d5
	move.w	(a0)+,d6
	cmp.w	d1,d4
	blt.s	.sr
	cmp.w	d2,d4
	bgt.s	.sr
	move.w	d5,GS_VIEWINDEX(a6)
	tst.w	d6
	beq	.x
	cmp.w	#172,d3			; x 173..273: shieldopt[viewindex] := x-173
	ble	.x
	cmp.w	#274,d3
	bge	.x
	move.w	d3,d0
	sub.w	#173,d0
	lea	GS_SHIP+SHIP_SHIELDOPT-1(a6),a0
	move.b	d0,0(a0,d5.w)
	bra	.x
.v4b:	cmp.w	#2,d0
	bne	.x
	tst.w	GS_VIEWINDEX2(a6)
	ble	.x
	bsr	.inpanel37
	beq	.x
	bsr	.listrow
	moveq	#2,d6			; shields in cargo
	bsr	.scrollcargo
	bra	.x
.v5:	cmp.w	#5,d0
	bne	.v6
	cmp.w	#165,d3			; 5: damage control
	ble	.x
	cmp.w	#279,d3
	bge	.x
	cmp.w	#31,d4
	ble	.x
	move.w	GS_VIEWLEVEL(a6),d0
	cmp.w	#1,d0
	bne.s	.v5b
	moveq	#1,d0			; the three teams' rows
	cmp.w	#36,d4
	blt	.x
	cmp.w	#49,d4
	ble.s	.v5s
	moveq	#2,d0
	cmp.w	#63,d4
	blt	.x
	cmp.w	#76,d4
	ble.s	.v5s
	moveq	#3,d0
	cmp.w	#90,d4
	blt	.x
	cmp.w	#103,d4
	bgt	.x
.v5s:	move.w	d0,GS_VIEWINDEX(a6)
	bra	.x
.v5b:	cmp.w	#2,d0
	bne	.x
	move.w	d4,d5			; i := (y-46) div 7: the repair to do
	sub.w	#46,d5
	ext.l	d5
	divs	#7,d5
	bsr	dp_team
	move.l	a0,a3
	tst.w	TEAM_JOBTYPE(a3)
	bne	.x
	cmp.w	#9,d5
	bge	.x
	TCOL	191			; (the old marker: ' ' on bkcolor 5)
	bsr	dp_team_unmark
	move.w	d5,TEAM_JOB(a3)
	move.w	GS_VIEWINDEX(a6),d0
	bsr	dp_team_time
	bra	.x
.v6:	cmp.w	#6,d0
	bne.s	.v7
	bsr	.inpanel37		; 6: options - viewindex := (y-27) div 9
	beq	.x
	move.w	d4,d0
	sub.w	#27,d0
	ext.l	d0
	divs	#9,d0
	move.w	d0,GS_VIEWINDEX(a6)
	bra	.x
.v7:	cmp.w	#7,d0
	bne.s	.v8
	tst.w	GS_VIEWLEVEL(a6)	; 7: logs - the list of visited systems
	bne	.x
	tst.w	GS_VIEWINDEX(a6)
	ble	.x
	bsr	.inpanel37
	beq	.x
	bsr	.listrow
	moveq	#1,d6
	lea	GS_VIEWINDEX(a6),a3
	bsr	.scrollsys
	bra	.x
.v8:	cmp.w	#8,d0
	bne.s	.v10
	move.w	d3,d0			; 8: the system view
	move.w	d4,d1
	bsr	targetplanet
	bra	.x
.v10:	cmp.w	#10,d0
	bne	.v11
	tst.w	GS_VIEWLEVEL(a6)	; 10: configure - a gun node, or the weapons in cargo
	bne.s	.v10b
	move.w	d3,d0
	move.w	d4,d1
	bsr	findgunnode
	bra	.x
.v10b:	cmp.w	#34,d3
	ble	.x
	cmp.w	#136,d3
	bge	.x
	cmp.w	#31,d4
	ble	.x
	cmp.w	#114,d4
	bge	.x
	move.w	d4,d5			; i: rows from the middle (-5 above 68)
	cmp.w	#68,d5
	bge.s	.v10l
	sub.w	#38,d5
	ext.l	d5
	divs	#6,d5
	subq.w	#5,d5
	bra.s	.v10s
.v10l:	sub.w	#68,d5
	ext.l	d5
	divs	#6,d5
.v10s:	moveq	#3,d6			; weapons in cargo (the original's own bounds)
	bsr	.scrollcargo
	bra	.x
.v11:	cmp.w	#11,d0
	bne	.x
	bsr	.inpanel37		; 11: bots
	beq	.x
	move.w	GS_VIEWLEVEL(a6),d0
	bne.s	.v11b
	move.w	d4,d5			; i := (y-31) div 10: the i-th used cache slot
	sub.w	#31,d5
	ext.l	d5
	divs	#10,d5
	move.w	GS_CURPLAN(a6),d0
	bsr	dp_plan
	lea	PLANET_CACHE(a0),a3
	moveq	#0,d6			; viewindex
.cs:	addq.w	#1,d6
	move.w	d6,d0
	add.w	d0,d0
	tst.w	-2(a3,d0.w)
	beq.s	.csn
	subq.w	#1,d5
.csn:	tst.w	d5
	blt.s	.csd
	cmp.w	#7,d6
	bne.s	.cs
.csd:	cmp.w	#7,d6
	bne.s	.csx
	tst.w	12(a3)			; viewindex 7 with nothing there: back to a used one
	bne.s	.csx
.cb:	tst.w	d6
	ble.s	.csx
	move.w	d6,d0
	add.w	d0,d0
	tst.w	-2(a3,d0.w)
	bne.s	.csx
	subq.w	#1,d6
	bra.s	.cb
.csx:	move.w	d6,GS_VIEWINDEX(a6)
	bra	.x
.v11b:	cmp.w	#1,d0
	bne.s	.v11c
	bsr	.listrow		; the cargo list
	moveq	#0,d6			; any cargo
	bsr	.scrollcargo
	bra	.x
.v11c:	move.w	d4,d5			; level 2: which bot (y-38) div 6
	sub.w	#38,d5
	ext.l	d5
	divs	#6,d5
	move.w	GS_CURPLAN(a6),d0
	bsr	dp_plan
	cmp.b	#7,PLANET_STATE(a0)
	beq.s	.b5
	move.w	#ID_MINEBOT,d0
	moveq	#1,d1
	bsr	.bot
	move.w	#ID_MANUFACTORY,d0
	moveq	#2,d1
	bsr	.bot
	move.w	#ID_FABRICATOR,d0
	moveq	#4,d1
	bsr	.bot
	bra.s	.bd
.b5:	move.w	#ID_STARMINER,d0
	moveq	#5,d1
	bsr	.bot
.bd:	cmp.w	#90,d5
	ble	.x
	bsr	mousehide
	TCOL	191
	BKCOL	5
	bsr	showbotstuff
	bsr	mouseshow
	bra	.x
.bot:	move.w	d1,-(sp)		; if incargo(item) > 0 then dec(y); if y < 0: viewindex2, y := 99
	bsr	incargo
	move.w	(sp)+,d1
	tst.w	d0
	ble.s	.bt
	subq.w	#1,d5
.bt:	tst.w	d5
	bge.s	.btx
	move.w	d1,GS_VIEWINDEX2(a6)
	moveq	#99,d5
.btx:	rts
.x:	movem.l	(sp)+,d3-d6
	rts
.inpanel31:				; 165 < x < 279 and 31 < y < 116 ?  (Z clear = yes)
	moveq	#31,d0
	bra.s	.inp
.inpanel37:
	moveq	#37,d0
.inp:	cmp.w	#165,d3
	ble.s	.no
	cmp.w	#279,d3
	bge.s	.no
	cmp.w	d0,d4
	ble.s	.no
	cmp.w	#116,d4
	bge.s	.no
	moveq	#1,d0
	rts
.no:	moveq	#0,d0
	rts
.listrow:				; d5 := i: y < 74: -6 + (y-38) div 6, else (y-74) div 6
	move.w	d4,d5
	cmp.w	#74,d5
	bge.s	.lr
	sub.w	#38,d5
	ext.l	d5
	divs	#6,d5
	subq.w	#6,d5
	rts
.lr:	sub.w	#74,d5
	ext.l	d5
	divs	#6,d5
	rts
; the target moves d5 rows through the nearby systems (index <> 0)
.scrollnear:
	tst.w	d5
	beq.s	.snx
	bpl.s	.snd
.snu:	subq.w	#1,(a3)			; up
	move.w	(a3),d0
	ble.s	.sn1
	bsr	dp_near
	tst.w	NEARBY_INDEX(a0)
	beq.s	.snc
	addq.w	#1,d5
.snc:	tst.w	d5
	bne.s	.snu
	bra.s	.snx
.sn1:	move.w	#1,(a3)			; target := 1; while nearby[target].index = 0 do inc(target)
.sn1l:	move.w	(a3),d0
	bsr	dp_near
	tst.w	NEARBY_INDEX(a0)
	bne.s	.snx
	addq.w	#1,(a3)
	bra.s	.sn1l
.snd:	addq.w	#1,(a3)			; down
	move.w	(a3),d0
	cmp.w	#NEARBYMAX,d0
	bgt.s	.sn2
	bsr	dp_near
	tst.w	NEARBY_INDEX(a0)
	beq.s	.snd2
	subq.w	#1,d5
.snd2:	tst.w	d5
	bne.s	.snd
	bra.s	.snx
.sn2:	move.w	#NEARBYMAX,(a3)		; target := nearbymax; while nearby[target].index = 0 do dec
.sn2l:	move.w	(a3),d0
	bsr	dp_near
	tst.w	NEARBY_INDEX(a0)
	bne.s	.snx
	subq.w	#1,(a3)
	bra.s	.sn2l
.snx:	rts
; viewindex (a3) moves d5 rows through the visited systems
.scrollsys:
	tst.w	d5
	beq.s	.ssx
	bpl.s	.ssd
.ssu:	subq.w	#1,(a3)
	move.w	(a3),d0
	ble.s	.ss1
	bsr	dp_sys
	tst.w	SYSTEM_VISITS(a0)
	beq.s	.ssc
	addq.w	#1,d5
.ssc:	tst.w	d5
	bne.s	.ssu
	bra.s	.ssx
.ss1:	move.w	#1,(a3)
.ss1l:	move.w	(a3),d0
	bsr	dp_sys
	tst.w	SYSTEM_VISITS(a0)
	bne.s	.ssx
	addq.w	#1,(a3)
	bra.s	.ss1l
.ssd:	addq.w	#1,(a3)
	move.w	(a3),d0
	cmp.w	#250,d0
	bgt.s	.ss2
	bsr	dp_sys
	tst.w	SYSTEM_VISITS(a0)
	beq.s	.ssd2
	subq.w	#1,d5
.ssd2:	tst.w	d5
	bne.s	.ssd
	bra.s	.ssx
.ss2:	move.w	#250,(a3)
.ss2l:	move.w	(a3),d0
	bsr	dp_sys
	tst.w	SYSTEM_VISITS(a0)
	bne.s	.ssx
	subq.w	#1,(a3)
	bra.s	.ss2l
.ssx:	rts
; viewindex2 moves d5 rows through the cargo slots of a kind (d6: 0 any, 2 shields
; NOSHIELD..NOTHING-2, 3 weapons DIRK..NOSHIELD-2), the original's own bounds per panel
.scrollcargo:
	lea	GS_VIEWINDEX2(a6),a3
	tst.w	d5
	beq	.scx
	bpl.s	.scd
.scu:	subq.w	#1,(a3)
	move.w	(a3),d0
	ble.s	.sc1
	bsr	.kind
	beq.s	.scc
	addq.w	#1,d5
.scc:	tst.w	d5
	bne.s	.scu
	bra	.scx
.sc1:	move.w	#1,(a3)			; viewindex2 := 1; skip the slots not of the kind (wide test)
.sc1l:	cmp.w	#3,d6
	bne.s	.sc1t
	cmp.w	#251,(a3)		; (weapons: while (vi2 < 251) and ...; 251 -> 0)
	blt.s	.sc1t
	clr.w	(a3)
	bra	.scx
.sc1t:	move.w	(a3),d0
	bsr	.wide
	bne	.scx
	addq.w	#1,(a3)
	bra.s	.sc1l
.scd:	addq.w	#1,(a3)
	move.w	(a3),d0
	cmp.w	#250,d0
	bgt.s	.sc2
	bsr	.kind
	beq.s	.scd2
	subq.w	#1,d5
.scd2:	tst.w	d5
	bne.s	.scd
	bra.s	.scx
.sc2:	move.w	#250,(a3)
.sc2l:	cmp.w	#3,d6
	bne.s	.sc2t
	tst.w	(a3)
	ble.s	.scx
.sc2t:	move.w	(a3),d0
	bsr	.wide
	bne.s	.scx
	subq.w	#1,(a3)
	bra.s	.sc2l
.scx:	rts
.kind:	bsr	dp_cargoitem		; the narrow test used while moving (Z clear = of the kind)
	tst.w	d6
	bne.s	.k2
	tst.w	d1
	rts
.k2:	cmp.w	#2,d6
	bne.s	.k3
	cmp.w	#ID_NOSHIELD,d1
	blt.s	.kn
	cmp.w	#ID_NOTHING-1,d1
	bge.s	.kn
	bra.s	.ky
.k3:	cmp.w	#ID_DIRK,d1
	blt.s	.kn
	cmp.w	#ID_NOSHIELD-1,d1
	bge.s	.kn
.ky:	moveq	#1,d1
	rts
.kn:	moveq	#0,d1
	rts
.wide:	bsr	dp_cargoitem		; the wide test used to settle (Z clear = of the kind)
	tst.w	d6
	bne.s	.w2
	tst.w	d1
	rts
.w2:	cmp.w	#2,d6
	bne.s	.w3
	cmp.w	#ID_NOSHIELD,d1
	blt.s	.kn
	cmp.w	#ID_NOTHING,d1
	bge.s	.kn
	bra.s	.ky
.w3:	cmp.w	#ID_DIRK,d1
	blt.s	.kn
	cmp.w	#ID_NOSHIELD,d1
	bge.s	.kn
	bra.s	.ky

; journey.pas adjustwanderer(ofs d0): the alien ship moves (combat when close and hostile)
adjustwanderer:
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
	lea	ONEALIEN_RELX(a3),a0	; all within 500 and a reason to fight: combat
	moveq	#3-1,d2
.cl:	move.w	(a0)+,d0
	bpl.s	.cp
	neg.w	d0
.cp:	cmp.w	#500,d0
	bge.s	.far
	dbf	d2,.cl
	cmp.w	#WNDACT_ATTACK,GS_ACTION(a6)
	beq	notported		; initiatecombat
	cmp.w	#WNDORDER_ATTACK,ONEALIEN_ORDERS(a3)
	beq	notported
	move.w	ONEALIEN_ANGER(a3),d0
	move.w	ONEALIEN_CONGENIALITY(a3),d1
	bsr	calc_anger
	cmp.w	#3,d0
	bgt	notported
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
	PRTLN
	TCOL	63
	PRT	"SECURITY: Evasion successful!"
.na:	clr.w	GS_ACTION(a6)
.x:	movem.l	(sp)+,d3/a3
	rts

; journey.pas movewandering
movewandering:
	move.w	GS_ACTION(a6),d0
	cmp.w	#WNDACT_RETREAT,d0
	beq.s	.r
	cmp.w	#WNDACT_ATTACK,d0
	bne.s	.o
	bsr.s	.ofs			; closer: round((accelmax div 4)*(100-dmg)/100)
	bsr	adjustwanderer
	bra.s	.o
.r:	bsr.s	.ofs			; away: round(-(accelmax div 4)*(100-dmg)/100)
	neg.w	d0
	bsr	adjustwanderer
.o:	move.w	GS_SHIP+SHIP_WANDERING+ONEALIEN_ORDERS(a6),d0
	cmp.w	#WNDORDER_ATTACK,d0
	bne.s	.o2
	cmp.w	#WNDACT_MASKING,GS_ACTION(a6)
	bne.s	.a30
	moveq	#12,d0			; 5-random(12)
	bsr	mt_random
	neg.w	d0
	addq.w	#5,d0
	bra	adjustwanderer
.a30:	moveq	#30,d0
	bra	adjustwanderer
.o2:	cmp.w	#WNDORDER_RETREAT,d0
	bne.s	.o3
	moveq	#-70,d0
	cmp.w	#WNDACT_MASKING,GS_ACTION(a6)
	bne	adjustwanderer
	moveq	#-50,d0
	bra	adjustwanderer
.o3:	cmp.w	#WNDORDER_NONE,d0
	bne.s	.x
	moveq	#-30,d0
	bra	adjustwanderer
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

	section	data
jy_msg:		dc.w	500		; journey.pas: msg := 500
jy_mode:	dc.b	"MAIN",0
jy_fn_song:	dc.b	"SOUND",92,"SECTOR.MOD",0
jy_s_quit:	dc.b	20,"Do you want to quit?"
jy_s_compromised: dc.b	53,"SECURITY: Shield integrity compromised...needs repair"
jy_s_unstable:	dc.b	28,"SECURITY: Shield unstable..."
jy_s_failadjust: dc.b	24,"Failed to adjust shield."
jy_alertcol:	dc.b	48,112,80,0
jy_slash:	dc.b	1,"/"
jy_space:	dc.b	1," "
jy_colon:	dc.b	1,":"
	even
jy_cubefaces:	dc.b	11,"Psychometry"
		dc.b	11,"Engineering"
		dc.b	11,"  Science  "
		dc.b	11," Security  "
		dc.b	11,"Astrogation"
		dc.b	11,"  Medical  "
jy_menunames:	dc.b	11," Psy Eval  ",11,"Planet Comm",11,"Planet Comm",11," Psy Eval  ",11," Ship Hail "
		dc.b	11," Ship Hail ",11,"Crew Status",11," Research  ",11,"Crew Comm  "
		dc.b	11," Dmg Ctrl  ",11," Configure ",11,"Bot Control",11,"  Shields  ",11," Ship Logs "
		dc.b	11," Creation  ",11,"  Weapons  ",11," Research  ",11,"   Cargo   "
		dc.b	11,"Short Range",11,"Planet Scan",11,"Planet Scan",11,"Long Range ",11,"Planet Scan"
		dc.b	11,"Planet Scan",11,"System Info",11," Research  ",11," Star Logs "
		dc.b	11,"  Retreat  ",11,"  Retreat  ",11,"  Drones   ",11,"  Shields  ",11,"  Masking  "
		dc.b	11,"  Attack   ",11,"  Weapons  ",11," Research  ",11,"  Attack   "
		dc.b	11," Star Map  ",11,"Quick Stats",11,"Ship Status",11,"Sector Map ",11,"  Target   "
		dc.b	11,"  Target   ",11,"History Map",11," Research  ",11,"Local Info "
		dc.b	11,"  Options  ",11," Save Game ",11,"  Encode   ",11,"Time Burst ",11," Load Game "
		dc.b	11,"  Decode   ",11,"Clear Scrn ",11," Research  ",11,"Quit to DOS"
; keys: Q A Z T G B rotate to faces 0-5; W E R S D F X C V: processcube(cube*9 + 0..8)
jy_keys:	dc.b	'Q',1,'A',2,'Z',3,'T',4,'G',5,'B',6
		dc.b	'W',$80,'E',$81,'R',$82,'S',$83,'D',$84,'F',$85,'X',$86,'C',$87,'V',$88,0
	even
; the right-hand panels by viewmode 2-11
jy_panels:	dc.l	displayweaponinfo,displaysysteminfo,displayshieldopts,displaydamagecontrol
		dc.l	displayoptions,displaylogs,displaysystem,displayshipinfo,displayconfigure
		dc.l	displaybotinfo
; the shield panel's mouse rows: lo, hi, viewindex, sets shieldopt (1)
jy_shdrows:	dc.w	61,68,1,0, 70,74,1,1, 79,86,2,0, 88,92,2,1, 97,104,3,0, 106,110,3,1, -1
jy_eventsystems: dc.w	211,12,129,13,182,15,31,14,98,16,138,17,229,20,28,24,182,14,119,10000
		dc.w	182,10002,14,25,-1

	section	bss
jy_cubecols:	ds.b	21*77*2		; DATA\CUBE.DAT (read at start-up)
jy_cuberows:	ds.b	20*67*2
jy_oldcube:	ds.w	1
jy_clickcode_v:	ds.w	1
jy_shadow:	ds.b	1
	even
jy_s1:		ds.b	32
jy_num:		ds.b	12
jy_time:	ds.b	32
