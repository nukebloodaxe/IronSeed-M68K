; crewinfo.s - crewinfo.pas for MAIN.PRG: the crew status screen (the cube's Crew Status): each
; crew member's portrait, name, description, experience and level, sanity bar and the
; colour-cycled stats graph; the arrows step through the six. Mode CHAR2 (tools/mkmain.py:
; char2.cpr; the graph's 32 cycling indices 128-159 share 6 own slots). Also utils2.pas
; removedata (the way back to the bridge after such a screen).
;
; crewstats     crewinfo.pas crewstats                              trashes: d0-d2/a0-a2
; removedata    utils2.pas removedata                               trashes: d0-d2/a0-a2

CI_MSG		equ	9*40		; msgarraytype [0..8, 0..8, 0..39]
CI_LMSG		equ	5*16		; littlemsgarraytype [0..7, 0..4, 0..15]

	section	text
crewstats:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	ci_readydata
	bsr	ci_mainloop
	bsr	removedata
	movem.l	(sp)+,d3-d7/a3-a5
	rts

removedata:
	bsr	mousehide
	moveq	#-8,d0			; fadestopmod(-FADEFULL_STEP, FADEFULL_DELAY)
	moveq	#20,d1
	bsr	fadestopmod
	moveq	#3,d0			; mouse.setmousecursor(random(3))
	bsr	mt_random
	bsr	setmousecursor
	bsr	orc_dump		; loadscreen(current)
	moveq	#0,d0
	bsr	ms_unsnap
	bsr	showresearchlights
	move.w	#3,GS_BKCOLOR(a6)
	moveq	#0,d0
	bsr	displaytextbox
	move.w	#25,GS_TEXTINDEX(a6)
	bsr	mouseshow
	st	GS_ANYCHANGE(a6)
	move.l	GS_OLDT1(a6),GS_T1(a6)	; t1 := oldt1
	move.l	GS_OLDT1+4(a6),GS_T1+4(a6)
	rts

; showportrait(n d0): loadscreen(image nn) to screen[16.., 220..]
ci_showportrait:
	move.l	d3,-(sp)
	move.w	d0,d3
	bsr	orc_dump
	bsr	mb_portraits
	move.w	d3,d0
	subq.w	#1,d0
	mulu	#70*70,d0
	move.l	mb_pics,a1
	add.l	d0,a1
	moveq	#16,d3
.r:	move.w	#220,d0
	move.w	d3,d1
	bsr	ms_addr
	moveq	#70/2-1,d0
.c:	move.b	(a1)+,(a0)+
	move.b	(a1)+,(a0)+
	dbf	d0,.c
	addq.w	#1,d3
	cmp.w	#86,d3
	bne.s	.r
	move.w	#220,d0
	moveq	#16,d1
	move.w	#289,d2
	moveq	#85,d3
	bsr	ms_dirty
	move.l	(sp)+,d3
	rts

; displaylevel(x d0): five lights on row 101 (y is data.pas's)
ci_displaylevel:
	move.l	d3,-(sp)
	move.w	d0,d3
	move.w	#309,GS_Y(a6)
	moveq	#5-1,d1
.l:	subq.w	#8,GS_Y(a6)
	moveq	#124,d2
	btst	#0,d3
	beq.s	.p
	moveq	#92,d2
.p:	move.w	GS_Y(a6),d0
	move.w	d1,-(sp)
	moveq	#101,d1
	bsr	ms_pset
	move.w	(sp)+,d1
	lsr.w	#1,d3
	dbf	d1,.l
	move.l	(sp)+,d3
	rts

; drawstats(num d0): the graph: a polyline from (16, 50) through random choices of the six stat heights
ci_drawstats:
	movem.l	d3-d7/a3,-(sp)
	bsr	ct_crew
	moveq	#0,d5
	move.b	CREW_PHY(a0),d5
	move.w	d5,ci_a			; a := phy (the unit's a)
	moveq	#0,d6
	move.b	CREW_MEN(a0),d6
	moveq	#0,d7
	move.b	CREW_EMO(a0),d7
	BAR	16,14,200,88,0
	lea	ci_holo,a1		; the hologram back
	moveq	#35,d3
.h:	moveq	#84,d0
	move.w	d3,d1
	bsr	ms_addr
	moveq	#36-1,d0
.hc:	move.b	(a1)+,(a0)+
	dbf	d0,.hc
	addq.w	#1,d3
	cmp.w	#63,d3
	ble.s	.h
	moveq	#16,d0			; moveto(16, 50)
	moveq	#50,d1
	bsr	ms_moveto
	FSSE				; the six heights round(stat*part), part = 36/100
	lea	ci_h,a3
	move.w	d5,d0
	bsr.s	.rh
	move.w	d6,d0
	bsr.s	.rh
	move.w	d7,d0
	bsr.s	.rh
	lea	ci_h,a0
	move.w	(a0)+,d0
	neg.w	d0
	move.w	d0,(a3)+
	move.w	(a0)+,d0
	neg.w	d0
	move.w	d0,(a3)+
	move.w	(a0)+,d0
	neg.w	d0
	move.w	d0,(a3)+
	moveq	#19,d3			; j: 19, 22, ... 199 (the loop's own inc(j, 2))
.j:	moveq	#6,d0			; d := random(6)
	bsr	mt_random
	add.w	d0,d0
	lea	ci_h,a0
	move.w	0(a0,d0.w),d1
	move.w	d1,ci_i
	add.w	#51,d1
	move.w	d3,d4			; setcolor((j-16) mod 32 + 128)
	sub.w	#16,d4
	and.w	#31,d4
	add.w	#128,d4
	move.w	d3,d0
	bsr	ms_lineto
	addq.w	#3,d3
	cmp.w	#200,d3
	ble.s	.j
	move.w	#202,ci_j
	movem.l	(sp)+,d3-d7/a3
	rts
.rh:	bsr	fp_ldw
	lea	ci_part,a0
	bsr	fp_ldd
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,(a3)+
	rts

ci_displaycursor:
	move.l	d3,-(sp)
	moveq	#1,d3
.l:	moveq	#104,d2
	cmp.w	ci_crewindex,d3
	bne.s	.c
	moveq	#63,d2
.c:	cmp.w	#3,d3
	bgt.s	.r
	move.w	d3,d1			; screen[j*3+139, 303..304]
	mulu	#3,d1
	add.w	#139,d1
	move.w	#303,d0
	bra.s	.p
.r:	move.w	d3,d1			; screen[j*3+130, 310..311]
	mulu	#3,d1
	add.w	#130,d1
	move.w	#310,d0
.p:	movem.w	d0-d2,-(sp)
	bsr	ms_pset
	movem.w	(sp)+,d0-d2
	addq.w	#1,d0
	bsr	ms_pset
	addq.w	#1,d3
	cmp.w	#6,d3
	ble.s	.l
	move.w	d3,ci_j
	move.l	(sp)+,d3
	rts

ci_redraw:
	movem.l	d3-d7/a3,-(sp)
	bsr	mousehide
	move.w	ci_crewindex,d0
	bsr	ci_drawstats
	move.w	ci_crewindex,d0		; crewdata := crew.dta record ship.crew[crewindex].index
	bsr	ct_crew
	moveq	#0,d0
	move.b	CREW_INDEX(a0),d0
	move.w	d0,d7
	subq.w	#1,d0
	mulu	#CREWDATA_SIZEOF,d0
	lea	ci_crewdata,a3
	add.l	d0,a3
	move.w	d7,d0
	bsr	ci_showportrait
	lea	ci_s,a0			; s := name, trailing spaces cut (down to 1)
	lea	CREWDATA_NAME(a3),a1
	bsr	pstr_cpy
	lea	ci_s,a0
	moveq	#20,d0
.t:	cmp.w	#1,d0
	ble.s	.tc
	cmp.b	#' ',0(a0,d0.w)
	bne.s	.tc
	subq.w	#1,d0
	bra.s	.t
.tc:	move.b	d0,(a0)
	BAR	121,103,239,108,0
	moveq	#0,d0			; printxy(121 + (120-length*6) div 2, 103, s)
	move.b	ci_s,d0
	mulu	#6,d0
	neg.w	d0
	add.w	#120,d0
	ext.l	d0
	divs	#2,d0
	add.w	#121,d0
	moveq	#103,d1
	lea	ci_s,a0
	bsr	printxy
	moveq	#0,d3			; the description
.d:	move.w	d3,d0
	mulu	#53,d0
	lea	CREWDATA_DESC(a3),a0
	add.w	d0,a0
	move.w	d3,d1
	mulu	#6,d1
	add.w	#130,d1
	moveq	#0,d0
	bsr	printxy
	addq.w	#1,d3
	cmp.w	#9,d3
	ble.s	.d
	move.w	#10,ci_a
	move.w	ci_crewindex,d0		; str(xp:10, s), leading spaces of 1-7 -> '0'
	bsr	ct_crew
	move.l	CREW_XP(a0),d0
	moveq	#10,d1
	lea	ci_s,a0
	bsr	int_str
	lea	ci_s+1,a0
	moveq	#7-1,d0
.z:	cmp.b	#' ',(a0)
	bne.s	.zn
	move.b	#'0',(a0)
.zn:	addq.l	#1,a0
	dbf	d0,.z
	move.w	#198,d0
	moveq	#120,d1
	lea	ci_s,a0
	bsr	printxy
	move.w	ci_crewindex,d0		; str(level:2, s); displaylevel(level); printxy(154, 120, s)
	bsr	ct_crew
	moveq	#0,d0
	move.b	CREW_LEVEL(a0),d0
	move.w	d0,d3
	moveq	#2,d1
	lea	ci_s,a0
	bsr	int_str
	move.w	d3,d0
	bsr	ci_displaylevel
	move.w	#154,d0
	moveq	#120,d1
	lea	ci_s,a0
	bsr	printxy
	move.w	ci_crewindex,d0		; the sanity bar
	bsr	ct_crew
	moveq	#0,d7
	move.b	CREW_SAN(a0),d7		; j
	bne.s	.s1
	moveq	#1,d7
.s1:	cmp.w	#100,d7
	ble.s	.s2
	moveq	#100,d7
.s2:	move.w	d7,ci_j
	FX87				; t1 := 25/(j*0.68)
	move.w	d7,d0
	bsr	fp_ldw
	FLDX	gx_0_68
	bsr	fp_mul
	FLDI	25
	bsr	fp_divr
	FSTG	GS_T1
	move.w	d7,d0			; for i := 26 to 26+round(j*0.68)
	bsr	fp_ldw
	FLDX	gx_0_68
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,d6
	add.w	#26,d6
	FSSE
	moveq	#26,d3
.sb:	cmp.w	d6,d3
	bgt.s	.sbe
	move.w	d3,d0			; round((i-26)*t1)+70
	sub.w	#26,d0
	bsr	fp_ldw
	FLDG	GS_T1
	bsr	fp_mul
	bsr	fp_rnd
	add.w	#70,d0
	move.w	d0,d2
	move.w	#309,d0
	move.w	d3,d1
	move.w	d2,-(sp)
	bsr	ms_pset
	move.w	(sp)+,d2
	move.w	#310,d0
	move.w	d3,d1
	bsr	ms_pset
	addq.w	#1,d3
	bra.s	.sb
.sbe:	cmp.w	#100,d7			; if j < 100: rows 27+round(j*0.67) .. 94 := 0
	bge.s	.sx
	FX87
	move.w	d7,d0
	bsr	fp_ldw
	FLDX	gx_0_67
	bsr	fp_mul
	bsr	fp_rnd
	FSSE
	add.w	#27,d0
	cmp.w	#94,d0
	bgt.s	.sx
	move.w	d0,d1
	move.w	#309,d0
	move.w	#310,d2
	moveq	#94,d3
	moveq	#0,d4
	bsr	ms_bar
.sx:	FSSE
	bsr	ci_displaycursor
	bsr	mouseshow
	movem.l	(sp)+,d3-d7/a3
	rts

; adjustgraph: colors[128..159] := colors[64..95] rotated by graphindex
ci_adjustgraph:
	subq.w	#1,ci_graphindex
	bne.s	.n
	move.w	#31,ci_graphindex
.n:	move.w	ci_graphindex,d1	; i
	lea	GS_COLORS+128*3(a6),a1
	moveq	#32-1,d2
.l:	addq.w	#1,d1
	cmp.w	#31,d1
	ble.s	.k
	moveq	#0,d1
.k:	move.w	d1,d0
	mulu	#3,d0
	lea	GS_COLORS+64*3(a6),a0
	add.w	d0,a0
	move.b	(a0)+,(a1)+
	move.b	(a0)+,(a1)+
	move.b	(a0)+,(a1)+
	dbf	d2,.l
	move.w	d1,ci_i
	move.w	#32,ci_j
	rts

ci_readydata:
	movem.l	d3-d7/a3,-(sp)
	move.l	GS_T1(a6),GS_OLDT1(a6)	; oldt1 := t1
	move.l	GS_T1+4(a6),GS_OLDT1+4(a6)
	bsr	mousehide
	moveq	#0,d0			; compressfile(current)
	bsr	ms_snap
	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	lea	ci_fn_mod,a0		; playmod(true, CREWCOMM.MOD)
	bsr	playmod
	bsr	orc_dump		; loadscreen(char2)
	lea	ci_mode,a0
	bsr	ms_load
	bcs	fatal
	tst.b	ci_crewread		; crew.dta (read once)
	bne.s	.cf
	st	ci_crewread
	lea	ci_crewdata,a1
	lea	ci_fn_crew,a0
	move.l	#30*CREWDATA_SIZEOF,d0
	bsr	load_exact
.cf:	lea	ci_msgs,a3		; msgs^[a, i] := screen[(a div 3)*10+145+i, (a mod 3)*40+10], 40 bytes
	moveq	#0,d3
.m:	moveq	#0,d4
.m2:	move.w	d3,d0
	ext.l	d0
	divu	#3,d0
	move.w	d0,d1
	mulu	#10,d1
	add.w	#145,d1
	add.w	d4,d1
	swap	d0
	mulu	#40,d0
	add.w	#10,d0
	bsr	ms_addr
	moveq	#40-1,d0
.m3:	move.b	(a0)+,(a3)+
	dbf	d0,.m3
	addq.w	#1,d4
	cmp.w	#8,d4
	ble.s	.m2
	addq.w	#1,d3
	cmp.w	#8,d3
	ble.s	.m
	lea	ci_lmsgs,a3		; littlemsgs^[a, i] := screen[(a div 2)*10+145+i, (a mod 2)*20+130], 16
	moveq	#0,d3
.l:	moveq	#0,d4
.l2:	move.w	d3,d1
	lsr.w	#1,d1
	mulu	#10,d1
	add.w	#145,d1
	add.w	d4,d1
	moveq	#1,d0
	and.w	d3,d0
	mulu	#20,d0
	add.w	#130,d0
	bsr	ms_addr
	moveq	#16-1,d0
.l3:	move.b	(a0)+,(a3)+
	dbf	d0,.l3
	addq.w	#1,d4
	cmp.w	#4,d4
	ble.s	.l2
	addq.w	#1,d3
	cmp.w	#7,d3
	ble.s	.l
	lea	ci_mcursor,a3		; mcursor^[a, i] := screen[i+180, 10+a*17], 16
	moveq	#0,d3
.c:	moveq	#0,d4
.c2:	move.w	d3,d0
	mulu	#17,d0
	add.w	#10,d0
	move.w	d4,d1
	add.w	#180,d1
	bsr	ms_addr
	moveq	#16-1,d0
.c3:	move.b	(a0)+,(a3)+
	dbf	d0,.c3
	addq.w	#1,d4
	cmp.w	#15,d4
	ble.s	.c2
	addq.w	#1,d3
	cmp.w	#6,d3
	ble.s	.c
	BAR	4,130,265,196,0
	lea	ci_holo,a3		; holo^ := screen[35..63, 84..119]
	moveq	#35,d3
.h:	moveq	#84,d0
	move.w	d3,d1
	bsr	ms_addr
	moveq	#36-1,d0
.h2:	move.b	(a0)+,(a3)+
	dbf	d0,.h2
	addq.w	#1,d3
	cmp.w	#63,d3
	ble.s	.h
	FSSE				; part := 36/100
	FLDI	36
	FLDI	100
	bsr	fp_div
	lea	ci_part,a0
	bsr	fp_std
	move.w	#1,ci_graphindex
	bsr	ci_adjustgraph
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	move.w	#1,ci_crewindex
	clr.w	ci_mouseindex
	bsr	ci_displaycursor
	TCOL	170
	BKCOL	0
	bsr	ci_redraw
	bsr	mouseshow
	sf	GS_DONE(a6)
	move.w	#32,ci_msgindex
	movem.l	(sp)+,d3-d7/a3
	rts

ci_findmouse:
	move.l	d3,-(sp)
	bsr	kbd_mouse_status
	tst.b	d0
	beq.s	.x
	move.w	ci_crewindex,d3		; before
	bsr	kbd_mouse_xy
	cmp.w	#280,d0
	blt.s	.n
	cmp.w	#297,d0
	bgt.s	.d
	cmp.w	#146,d1
	blt.s	.n
	cmp.w	#160,d1
	bgt.s	.u2
	bsr	ci_prev
	bra.s	.n
.u2:	cmp.w	#162,d1
	blt.s	.n
	cmp.w	#176,d1
	bgt.s	.n
	bsr	ci_next
	bra.s	.n
.d:	cmp.w	#302,d0
	blt.s	.n
	cmp.w	#311,d0
	bgt.s	.n
	cmp.w	#154,d1
	ble.s	.n
	cmp.w	#170,d1
	bge.s	.n
	st	GS_DONE(a6)
.n:	cmp.w	ci_crewindex,d3
	beq.s	.i
	bsr	ci_redraw
.i:	clr.w	GS_IDLETIME(a6)
.x:	move.l	(sp)+,d3
	rts
ci_prev:
	subq.w	#1,ci_crewindex
	bgt.s	.x
	move.w	#6,ci_crewindex
.x:	rts
ci_next:
	addq.w	#1,ci_crewindex
	cmp.w	#6,ci_crewindex
	ble.s	.x
	move.w	#1,ci_crewindex
.x:	rts

ci_processkey:
	move.l	d3,-(sp)
	bsr	kbd_readkey
	move.w	ci_crewindex,d3
	cmp.b	#27,d0
	bne.s	.e
	st	GS_DONE(a6)
	bra.s	.n
.e:	cmp.b	#'`',d0			; bossmode
	bne.s	.eb
	bsr	bossmode
	bra.s	.n
.eb:	tst.b	d0
	bne.s	.n
	bsr	kbd_readkey
	cmp.b	#72,d0
	bne.s	.e2
	bsr	ci_prev
	bra.s	.n
.e2:	cmp.b	#80,d0
	bne.s	.n
	bsr	ci_next
.n:	cmp.w	ci_crewindex,d3
	beq.s	.i
	bsr	ci_redraw
.i:	clr.w	GS_IDLETIME(a6)
	move.l	(sp)+,d3
	rts

; displaymsg / displaylittlemsgs
ci_displaymsg:
	move.l	d3,-(sp)
	moveq	#9,d0
	bsr	mt_random
	move.w	d0,ci_a
	bsr	mousehide		; (before a1 is set: it trashes a1)
	move.w	ci_a,d0
	mulu	#CI_MSG,d0
	lea	ci_msgs,a1
	add.w	d0,a1
	moveq	#0,d3
.r:	move.w	#273,d0
	move.w	d3,d1
	add.w	#122,d1
	bsr	ms_addr
	moveq	#40-1,d0
.c:	move.b	(a1)+,(a0)+
	dbf	d0,.c
	addq.w	#1,d3
	cmp.w	#8,d3
	ble.s	.r
	move.w	d3,ci_i
	move.w	#273,d0
	moveq	#122,d1
	move.w	#312,d2
	move.w	#130,d3
	bsr	ms_dirty
	bsr	mouseshow
	move.l	(sp)+,d3
	rts
ci_displaylittlemsgs:
	movem.l	d3-d4,-(sp)
	moveq	#8,d0
	bsr	mt_random
	move.w	d0,ci_a
	bsr	mousehide		; (before a1 is set: it trashes a1)
	move.w	ci_a,d0
	mulu	#CI_LMSG,d0
	lea	ci_lmsgs,a1
	add.w	d0,a1
	move.w	#273,d4
	btst	#0,ci_msgindex+1
	beq.s	.e
	move.w	#296,d4
.e:	moveq	#0,d3
.r:	move.w	d4,d0
	move.w	d3,d1
	add.w	#133,d1
	bsr	ms_addr
	moveq	#16-1,d0
.c:	move.b	(a1)+,(a0)+
	dbf	d0,.c
	addq.w	#1,d3
	cmp.w	#4,d3
	ble.s	.r
	move.w	d3,ci_i
	move.w	d4,d0
	move.w	#133,d1
	move.w	d4,d2
	add.w	#15,d2
	move.w	#137,d3
	bsr	ms_dirty
	bsr	mouseshow
	movem.l	(sp)+,d3-d4
	rts

ci_mainloop:
.l:	st	GS_PALETTEDIRTY(a6)	; palettedirty := true; fadestep(FADESTEP_STEP)
	moveq	#8,d0
	bsr	fadestep
	bsr	ci_findmouse
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	ci_processkey
.nk:	addq.w	#1,GS_IDLETIME(a6)
	cmp.w	#MAXIDLE,GS_IDLETIME(a6)
	bne.s	.ni
	bsr	screensaver
.ni:	bsr	ci_adjustgraph
	lea	GS_COLORS(a6),a0	; (the cycling colours: the original's palette is set by fadestep)
	bsr	vid_set256
	cmp.w	#6,ci_mouseindex	; the cursor's animation
	bge.s	.m0
	addq.w	#1,ci_mouseindex
	bra.s	.m1
.m0:	clr.w	ci_mouseindex
.m1:	bsr	mousehide
	move.w	ci_mouseindex,d0
	lsl.w	#8,d0
	lea	ci_mcursor,a0
	add.w	d0,a0
	bsr	kbd_cursor_set
	bsr	mouseshow
	cmp.w	#32,ci_msgindex
	bge.s	.g0
	addq.w	#1,ci_msgindex
	bra.s	.g1
.g0:	clr.w	ci_msgindex
.g1:	tst.w	ci_msgindex
	bne.s	.lm
	bsr	ci_displaymsg
	bra.s	.dl
.lm:	bsr	ci_displaylittlemsgs
.dl:	move.w	GS_TSLICE(a6),d0	; delay(tslice*FADE_TSLICE_MUL_CREWINFO)
	mulu	#7,d0
	bsr	delayp			; (paced: the frame's work counts)
	tst.b	GS_DONE(a6)
	beq	.l
	rts

	section	data
ci_mode:	dc.b	"CHAR2",0
ci_fn_mod:	dc.b	"SOUND",92,"CREWCOMM.MOD",0
ci_fn_crew:	dc.b	"DATA",92,"CREW.DTA",0
	even
	section	bss
ci_crewdata:	ds.b	30*CREWDATA_SIZEOF
	even
ci_crewread:	ds.b	1
	even
ci_part:	ds.l	2
ci_h:		ds.w	6
ci_crewindex:	ds.w	1
ci_graphindex:	ds.w	1
ci_msgindex:	ds.w	1
ci_mouseindex:	ds.w	1
ci_i:		ds.w	1
ci_j:		ds.w	1
ci_a:		ds.w	1
ci_s:		ds.b	32
ci_holo:	ds.b	29*36
ci_msgs:	ds.b	9*CI_MSG
ci_lmsgs:	ds.b	8*CI_LMSG
ci_mcursor:	ds.b	7*256
	even
	section	text
