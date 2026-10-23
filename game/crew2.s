; crew2.s - crew2.pas for MAIN.PRG: psychometry (the cube's Psy Eval): a crew member's skill,
; performance and sanity bars (ideal and actual), the stats tank recoloured per crew member, the
; three stats traded against each other with the +/- buttons, the graph display (opened and
; closed by sliding the portrait aside), the rising bubbles, the clock running. Mode PSYCHE
; (tools/mkmain.py: psyche.cpr; indices 96-127 and 128-159 change at run time: own slots).
; The encode button: encodecrew(181) / lifesupportfailure (encode.s).
;
; psyche      crew2.pas psyche                                       trashes: d0-d2/a0-a2
; pushrand / poprand   utils.pas PushRand / PopRand

MAXBUBBLES	equ	50

	section	text
pushrand:
	move.l	d0,-(sp)
	bsr	mt_getseed
	move.l	d0,c2r_randsave
	move.l	(sp)+,d0
	rts
poprand:
	move.l	d0,-(sp)
	move.l	c2r_randsave,d0
	bsr	mt_setseed
	move.l	(sp)+,d0
	rts

psyche:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	pushrand
	bsr	ps_readydata
	bsr	poprand
	bsr	ps_mainloop
	bsr	pushrand
	bsr	removedata
	bsr	poprand
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; a0 = ship.crew[crewindex]
ps_crew:
	move.w	ps_crewindex,d0
	bra	ct_crew

; showportrait(n d0) at screen[110.., 210..]
ps_showportrait:
	move.l	d3,-(sp)
	move.w	d0,d3
	bsr	orc_dump		; loadscreen(image nn)
	bsr	mb_portraits
	move.w	d3,d0
	subq.w	#1,d0
	mulu	#70*70,d0
	move.l	mb_pics,a1
	add.l	d0,a1
	moveq	#110,d3
.r:	move.w	#210,d0
	move.w	d3,d1
	bsr	ms_addr
	moveq	#70/2-1,d0
.c:	move.b	(a1)+,(a0)+
	move.b	(a1)+,(a0)+
	dbf	d0,.c
	addq.w	#1,d3
	cmp.w	#180,d3
	bne.s	.r
	move.w	#210,d0
	moveq	#110,d1
	move.w	#279,d2
	move.w	#179,d3
	bsr	ms_dirty
	move.l	(sp)+,d3
	rts

; screen[y d1, x d0] += d2.b, marked
ps_add:
	movem.w	d0-d2,-(sp)
	bsr	ms_addr
	movem.w	(sp)+,d0-d2
	add.b	d2,(a0)
	move.w	d3,-(sp)
	move.w	d0,d2
	move.w	d1,d3
	bsr	ms_dirty
	move.w	(sp)+,d3
	rts

ps_erasebubbles:
	movem.l	d3/a3,-(sp)
	bsr	mousehide
	lea	ps_bubbles,a3
	moveq	#MAXBUBBLES,d3
.l:	move.w	(a3),d1
	beq.s	.n
	move.w	2(a3),d0
	moveq	#3,d2
	bsr	ps_add
.n:	clr.l	(a3)+
	dbf	d3,.l
	bsr	mouseshow
	movem.l	(sp)+,d3/a3
	rts

ps_movebubbles:
	movem.l	d3/a3,-(sp)
	bsr	mousehide
	lea	ps_bubbles,a3
	moveq	#MAXBUBBLES,d3
.l:	move.w	(a3),d1
	beq.s	.n
	move.w	2(a3),d0
	moveq	#3,d2
	bsr	ps_add
.n:	moveq	#90,d0			; if random(90) = 0: a new one at the bottom
	bsr	mt_random
	tst.w	d0
	bne.s	.mv
	moveq	#6,d0
	bsr	mt_random
	add.w	#159,d0
	move.w	d0,(a3)
	moveq	#32,d0
	bsr	mt_random
	add.w	#45,d0
	move.w	d0,2(a3)
	bra.s	.d
.mv:	subq.w	#1,(a3)			; up, and sideways
	moveq	#2,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.lf
	cmp.w	#76,2(a3)
	bge.s	.lf
	addq.w	#1,2(a3)
	bra.s	.t
.lf:	cmp.w	#45,2(a3)
	ble.s	.t
	subq.w	#1,2(a3)
.t:	cmp.w	#85,(a3)		; at the top: again further down
	bgt.s	.d
	moveq	#36,d0
	bsr	mt_random
	add.w	#129,d0
	move.w	d0,(a3)
	moveq	#32,d0
	bsr	mt_random
	add.w	#45,d0
	move.w	d0,2(a3)
.d:	move.w	(a3),d1			; dec(screen[...], 3)
	move.w	2(a3),d0
	moveq	#-3,d2
	bsr	ps_add
	addq.l	#4,a3
	dbf	d3,.l
	bsr	mouseshow
	movem.l	(sp)+,d3/a3
	rts

ps_newbubbles:
	lea	ps_bubbles,a0
	moveq	#MAXBUBBLES,d0
.c:	clr.l	(a0)+
	dbf	d0,.c
	bra	ps_movebubbles

; gradientbar(x, y, w, h, c, cr, b, l) - the arguments in ps_gb (8 words)
ps_gradientbar:
	movem.l	d3-d7,-(sp)
	movem.w	ps_gb,d0-d7		; x y w h c cr b l
	move.w	d6,d0			; m := b*w div l, clamped to 0..w
	muls	d2,d0
	divs	d7,d0
	tst.w	d0
	bpl.s	.m1
	moveq	#0,d0
.m1:	cmp.w	d2,d0
	ble.s	.m2
	move.w	d2,d0
.m2:	move.w	d0,ps_m
	moveq	#0,d6			; xx
.c:	cmp.w	ps_m,d6
	bge.s	.z
	cmp.w	#1,ps_m			; cc := c + xx*cr div (m-1) (m > 1), else c + cr
	ble.s	.c1
	move.w	d6,d0
	muls	ps_gb+10,d0
	move.w	ps_m,d1
	subq.w	#1,d1
	divs	d1,d0
	add.w	ps_gb+8,d0
	bra.s	.c2
.c1:	move.w	ps_gb+8,d0
	add.w	ps_gb+10,d0
.c2:	move.w	d0,d4
	bsr.s	.col
	addq.w	#1,d6
	bra.s	.c
.z:	cmp.w	ps_gb+4,d6		; the rest of the width: 0
	bge.s	.x
	moveq	#0,d4
	bsr.s	.col
	addq.w	#1,d6
	bra.s	.z
.x:	movem.l	(sp)+,d3-d7
	rts
.col:	move.w	ps_gb,d0		; column x+xx, rows y .. y+h-1, colour d4
	add.w	d6,d0
	move.w	ps_gb+2,d1
	move.w	d0,d2
	move.w	d1,d3
	add.w	ps_gb+6,d3
	subq.w	#1,d3
	bra	ms_bar

; drawgraphs: randseed := crewindex^3; the ideal/actual bars; colors[96..127] from the stats
ps_drawgraphs:
	movem.l	d3-d7,-(sp)
	move.w	ps_crewindex,d0
	move.w	d0,d1
	muls	d0,d1
	muls	d0,d1
	move.l	d1,d0
	bsr	mt_setseed
	move.w	ps_crewindex,d0		; skill
	bsr	ct_computeskill
	bsr	ps_clamp
	move.w	d0,d3			; iski
	bsr	ps_crew
	moveq	#0,d0
	move.b	CREW_SKILL(a0),d0
	bsr	ps_clamp
	move.w	d0,d5			; rski
	moveq	#20,d0
	move.w	d3,d1
	move.w	d5,d2
	bsr	ps_bars
	move.w	ps_crewindex,d0		; performance
	bsr	ct_computeperf
	bsr	ps_clamp
	move.w	d0,d3
	bsr	ps_crew
	moveq	#0,d0
	move.b	CREW_PERF(a0),d0
	bsr	ps_clamp
	move.w	d0,d6			; rper
	moveq	#28,d0
	move.w	d3,d1
	move.w	d6,d2
	bsr	ps_bars
	move.w	ps_crewindex,d0		; sanity
	bsr	ct_computesanity
	bsr	ps_clamp
	move.w	d0,d3
	bsr	ps_crew
	moveq	#0,d0
	move.b	CREW_SAN(a0),d0
	bsr	ps_clamp
	move.w	d0,d7			; rsan
	moveq	#36,d0
	move.w	d3,d1
	move.w	d7,d2
	bsr	ps_bars
	lea	GS_COLORS+96*3(a6),a0	; colors[i] := r*((i-96)*2+1) div 99 for i = 96..127
	moveq	#0,d4
.p:	move.w	d4,d1
	add.w	d1,d1
	addq.w	#1,d1
	move.w	d5,d0
	mulu	d1,d0
	divu	#99,d0
	move.b	d0,(a0)+
	move.w	d6,d0
	mulu	d1,d0
	divu	#99,d0
	move.b	d0,(a0)+
	move.w	d7,d0
	mulu	d1,d0
	divu	#99,d0
	move.b	d0,(a0)+
	addq.w	#1,d4
	cmp.w	#32,d4
	bne.s	.p
	lea	GS_COLORS(a6),a0	; (shown at once: the original's next fadestep)
	bsr	vid_set256
	movem.l	(sp)+,d3-d7
	rts
ps_clamp:				; d0 := max(min(99, d0), 1)
	cmp.w	#99,d0
	ble.s	.a
	moveq	#99,d0
.a:	cmp.w	#1,d0
	bge.s	.b
	moveq	#1,d0
.b:	rts
; the two bars at row d0: ideal d1 (2 rows, 137+22), actual d2 (1 row, 105+22)
ps_bars:
	movem.l	d3-d4,-(sp)
	move.w	d0,d3
	move.w	d2,d4
	lea	ps_gb,a0
	move.w	#179,(a0)+
	move.w	d3,(a0)+
	move.w	#241-179+1,(a0)+
	move.w	#2,(a0)+
	move.w	#137,(a0)+
	move.w	#22,(a0)+
	move.w	d1,(a0)+
	move.w	#99,(a0)+
	bsr	ps_gradientbar
	lea	ps_gb+2,a0
	addq.w	#2,d3
	move.w	d3,(a0)+
	addq.l	#2,a0
	move.w	#1,(a0)+
	move.w	#105,(a0)+
	addq.l	#2,a0
	move.w	d4,(a0)+
	bsr	ps_gradientbar
	movem.l	(sp)+,d3-d4
	rts

ps_displayblips:
	move.l	d3,-(sp)
	moveq	#1,d3
.l:	moveq	#104,d2
	cmp.w	ps_crewindex,d3
	bne.s	.c
	moveq	#63,d2
.c:	cmp.w	#3,d3
	bgt.s	.r
	move.w	d3,d1			; screen[j*4+159, 289..290]
	lsl.w	#2,d1
	add.w	#159,d1
	move.w	#289,d0
	bra.s	.p
.r:	move.w	d3,d1			; screen[j*4+147, 294..295]
	lsl.w	#2,d1
	add.w	#147,d1
	move.w	#294,d0
.p:	movem.w	d0-d2,-(sp)
	bsr	ms_pset
	movem.w	(sp)+,d0-d2
	addq.w	#1,d0
	bsr	ms_pset
	addq.w	#1,d3
	cmp.w	#6,d3
	ble.s	.l
	move.w	d3,ps_j
	move.l	(sp)+,d3
	rts

; drawprimarystats(num d0): the four columns at x 297, 299, 301, 303 (rows ..145)
ps_drawprimary:
	movem.l	d3-d7/a3,-(sp)
	bsr	ct_crew
	move.l	a0,a3
	BAR	297,111,303,145,0
	FSSE
	moveq	#0,d0
	move.b	CREW_PHY(a3),d0
	move.w	#297,d1
	moveq	#95,d2
	moveq	#23,d3
	bsr	.col
	moveq	#0,d0
	move.b	CREW_MEN(a3),d0
	move.w	#299,d1
	moveq	#63,d2
	moveq	#14,d3
	bsr	.col
	moveq	#0,d0
	move.b	CREW_EMO(a3),d0
	move.w	#301,d1
	move.w	#207,d2
	moveq	#14,d3
	bsr	.col
	moveq	#0,d0
	move.b	CREW_STATUS(a3),d0
	move.w	#303,d1
	moveq	#31,d2
	moveq	#23,d3
	bsr	.col
	movem.l	(sp)+,d3-d7/a3
	rts
; value d0, x d1, col start d2, range d3: col := c; cs := r/(part*v) (v > 0) else 1;
; for y := 145-round(part*v) to 145: screen[y, x] := round(col); col := col - cs
.col:	move.w	d0,d4
	move.w	d1,d5
	move.w	d2,d0
	bsr	fp_ldw
	lea	ps_col,a0
	bsr	fp_std
	tst.w	d4
	ble.s	.c1
	move.w	d3,d0
	bsr	fp_ldw
	lea	ps_part,a0
	bsr	fp_ldd
	move.w	d4,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_div
	bra.s	.c2
.c1:	FLDI	1
.c2:	lea	ps_cs,a0
	bsr	fp_std
	lea	ps_part,a0		; y from 145-round(part*v)
	bsr	fp_ldd
	move.w	d4,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	move.w	#145,d6
	sub.w	d0,d6
.y:	cmp.w	#145,d6
	bgt.s	.yx
	lea	ps_col,a0
	bsr	fp_ldd
	bsr	fp_rnd
	move.w	d0,d2
	move.w	d5,d0
	move.w	d6,d1
	bsr	ms_pset
	lea	ps_col,a0
	bsr	fp_ldd
	lea	ps_cs,a0
	bsr	fp_ldd
	bsr	fp_sub
	lea	ps_col,a0
	bsr	fp_std
	addq.w	#1,d6
	bra.s	.y
.yx:	rts

; printxy(241 - round(length(s)*2.5), y d1, a0 = s)
ps_pcentre:
	movem.l	d1/a0,-(sp)
	moveq	#0,d0
	move.b	(a0),d0
	mulu	#5,d0			; length*2.5 = length*5/2, banker's at .5
	lsr.w	#1,d0
	bcc.s	.e
	btst	#0,d0
	beq.s	.e
	addq.w	#1,d0
.e:	neg.w	d0
	add.w	#241,d0
	movem.l	(sp)+,d1/a0
	bra	printxy

ps_jobline:				; clear rows 81-88 x 210-280; jobs[crewindex] at y 81
	BAR	210,81,280,88,0
	move.w	ps_crewindex,d0
	subq.w	#1,d0
	mulu	#14,d0
	lea	ps_jobs,a0
	add.w	d0,a0
	moveq	#81,d1
	bra	ps_pcentre

ps_redraw1:
	movem.l	d3/a3,-(sp)
	bsr	mousehide
	bsr	ps_crew
	moveq	#0,d0
	move.b	CREW_INDEX(a0),d0
	bsr	ps_showportrait
	bsr	ps_jobline
	bsr	ps_drawgraphs
	bsr	ps_crew			; s := the name's first word (from the 6th character for 18, 25, 26)
	move.l	a0,a3
	moveq	#1,d0
	move.b	CREW_INDEX(a3),d1
	cmp.b	#18,d1
	beq.s	.i6
	cmp.b	#25,d1
	beq.s	.i6
	cmp.b	#26,d1
	bne.s	.i1
.i6:	moveq	#6,d0
.i1:	move.w	d0,d1			; j := i; while s[j] <> ' ' do inc(j)
.w:	cmp.b	#' ',CREW_NAME(a3,d1.w)
	beq.s	.we
	addq.w	#1,d1
	bra.s	.w
.we:	move.w	d1,ps_j
	lea	ps_s,a0			; s := copy(s, i, j-i)
	sub.w	d0,d1
	move.b	d1,(a0)+
	lea	CREW_NAME(a3,d0.w),a1
	bra.s	.ce
.cl:	move.b	(a1)+,(a0)+
.ce:	dbf	d1,.cl
	TCOL	95
	BKCOL	255
	lea	ps_s,a0
	moveq	#111,d1
	bsr	ps_pcentre
	TCOL	191
	BKCOL	0
	bsr	ps_displayblips
	move.w	ps_crewindex,d0
	bsr	ps_drawprimary
	bsr	mouseshow
	movem.l	(sp)+,d3/a3
	rts

; drawstats(num): the graph display: a polyline from (145, 145)
ps_drawstats:
	movem.l	d3-d7/a3,-(sp)
	bsr	ps_crew
	moveq	#0,d5
	move.b	CREW_PHY(a0),d5
	move.w	d5,ps_a
	moveq	#0,d6
	move.b	CREW_MEN(a0),d6
	moveq	#0,d7
	move.b	CREW_EMO(a0),d7
	move.w	#145,d0			; moveto(145, 145)
	move.w	#145,d1
	bsr	ms_moveto
	FSSE
	lea	ps_h,a3
	move.w	d5,d0
	bsr.s	.rh
	move.w	d6,d0
	bsr.s	.rh
	move.w	d7,d0
	bsr.s	.rh
	lea	ps_h,a0
	moveq	#3-1,d1
.ng:	move.w	(a0)+,d0
	neg.w	d0
	move.w	d0,(a3)+
	dbf	d1,.ng
	move.w	#147,d3			; j: 147, 150, ... 285 (the loop's inc(j, 2))
.j:	moveq	#6,d0
	bsr	mt_random
	add.w	d0,d0
	lea	ps_h,a0
	move.w	0(a0,d0.w),d1
	move.w	d1,ps_i
	add.w	#145,d1
	move.w	d3,d4
	sub.w	#16,d4
	and.w	#31,d4
	add.w	#128,d4
	move.w	d3,d0
	bsr	ms_lineto
	addq.w	#3,d3
	cmp.w	#285,d3
	ble.s	.j
	move.w	#285,ps_j
	movem.l	(sp)+,d3-d7/a3
	rts
.rh:	bsr	fp_ldw
	lea	ps_part,a0
	bsr	fp_ldd
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,(a3)+
	rts

ps_redraw2:
	bsr	mousehide
	BAR	145,110,285,180,0
	bsr	ps_jobline
	bsr	ps_drawgraphs
	bsr	ps_displayblips
	move.w	ps_crewindex,d0
	bsr	ps_drawprimary
	move.w	ps_crewindex,d0
	bsr	ps_drawstats
	bra	mouseshow

ps_redraw:				; redraw1 or redraw2 by psychemode
	tst.w	ps_mode
	beq	ps_redraw1
	bra	ps_redraw2

ps_adjustgraph:
	subq.w	#1,ps_graphindex
	bne.s	.n
	move.w	#31,ps_graphindex
.n:	move.w	ps_graphindex,d1
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
	move.w	d1,ps_i
	move.w	#32,ps_j
	rts

; the portrait slides away: rows 99-190, columns shifted by one per step (60 steps)
ps_closedisplay:
	movem.l	d3-d5,-(sp)
	BAR	145,110,285,180,0
	moveq	#60,d5			; a: 60 downto 1: screen[i, j] := screen[i, j-1], j = 217-a downto 194-a
.a:	moveq	#99,d3
.r:	move.w	#217,d0
	sub.w	d5,d0
	move.w	d3,d1
	bsr	ms_addr
	addq.l	#1,a0
	moveq	#24-1,d0
.c:	move.b	-2(a0),-(a0)
	dbf	d0,.c
	addq.w	#1,d3
	cmp.w	#190,d3
	ble.s	.r
	move.w	#193,d0
	sub.w	d5,d0
	moveq	#99,d1
	move.w	#217,d2
	sub.w	d5,d2
	move.w	#190,d3
	bsr	ms_dirty
	move.w	GS_TSLICE(a6),d0
	ext.l	d0
	divs	#5,d0
	bsr	delay
	subq.w	#1,d5
	bne.s	.a
	move.w	d5,ps_a
	movem.l	(sp)+,d3-d5
	bra	ps_redraw1

ps_opendisplay:
	movem.l	d3-d5,-(sp)
	BAR	210,110,280,180,0
	moveq	#1,d5			; a: 1 to 60: screen[i, j] := screen[i, j+1], j = 194-a to 217-a
.a:	moveq	#99,d3
.r:	move.w	#194,d0
	sub.w	d5,d0
	move.w	d3,d1
	bsr	ms_addr
	moveq	#24-1,d0
.c:	move.b	1(a0),(a0)+
	dbf	d0,.c
	addq.w	#1,d3
	cmp.w	#190,d3
	ble.s	.r
	move.w	#194,d0
	sub.w	d5,d0
	moveq	#99,d1
	move.w	#218,d2
	sub.w	d5,d2
	move.w	#190,d3
	bsr	ms_dirty
	move.w	GS_TSLICE(a6),d0
	ext.l	d0
	divs	#5,d0
	bsr	delay
	addq.w	#1,d5
	cmp.w	#60,d5
	ble.s	.a
	move.w	d5,ps_a
	movem.l	(sp)+,d3-d5
	bra	ps_redraw2

ps_drawcursor:
	movem.l	d3-d4,-(sp)
	bsr	mousehide
	moveq	#63,d4
	tst.w	ps_mode
	beq.s	.a
	moveq	#95,d4
.a:	move.w	#176,d0
	moveq	#43,d1
	move.w	#176,d2
	moveq	#46,d3
	bsr	ms_bar
	moveq	#63,d4
	cmp.w	#1,ps_mode
	beq.s	.b
	moveq	#95,d4
.b:	move.w	#243,d0
	moveq	#43,d1
	move.w	#243,d2
	moveq	#46,d3
	bsr	ms_bar
	bsr	mouseshow
	movem.l	(sp)+,d3-d4
	rts

; altphy / altmen / altemo (alt d0 = 1 or -1): trade one stat for the other two
; generic: d0 alt, a1 = offsets: the traded stat, the other two (CREW_ offsets)
ps_alt:
	movem.l	d3-d5,-(sp)
	move.w	d0,d3
	move.b	(a1)+,d4		; t
	move.b	(a1)+,d5		; u (the one tested first against 99 / 0)
	move.b	(a1),d2			; v
	ext.w	d4
	ext.w	d5
	ext.w	d2
	bsr	ps_crew
	cmp.w	#1,d3
	bne.s	.m
	cmp.b	#2,0(a0,d4.w)		; alt 1: t >= 2, u < 99, v < 99: t -= 2; u++, v++
	blo.s	.x
	cmp.b	#99,0(a0,d5.w)
	beq.s	.x
	cmp.b	#99,0(a0,d2.w)
	beq.s	.x
	subq.b	#2,0(a0,d4.w)
	addq.b	#1,0(a0,d5.w)
	addq.b	#1,0(a0,d2.w)
	bra.s	.x
.m:	cmp.b	#97,0(a0,d4.w)		; alt -1: t <= 97, u > 0, v > 0: t += 2; u--, v--
	bhi.s	.x
	tst.b	0(a0,d5.w)
	beq.s	.x
	tst.b	0(a0,d2.w)
	beq.s	.x
	addq.b	#2,0(a0,d4.w)
	subq.b	#1,0(a0,d5.w)
	subq.b	#1,0(a0,d2.w)
.x:	movem.l	(sp)+,d3-d5
	rts
; altphy: men traded; tested emo, phy (alt 1) / emo, phy (alt -1); changes phy, emo
ps_altphy:
	lea	.o,a1
	bra.s	ps_alt
.o:	dc.b	CREW_MEN,CREW_EMO,CREW_PHY
	even
ps_altmen:
	lea	.o,a1
	bra.s	ps_alt
.o:	dc.b	CREW_EMO,CREW_PHY,CREW_MEN
	even
ps_altemo:
	lea	.o,a1
	bra	ps_alt
.o:	dc.b	CREW_PHY,CREW_EMO,CREW_MEN
	even

ps_readydata:
	movem.l	d3,-(sp)
	move.l	GS_T1(a6),GS_OLDT1(a6)	; oldt1 := t1
	move.l	GS_T1+4(a6),GS_OLDT1+4(a6)
	bsr	mousehide
	moveq	#0,d0			; compressfile(current)
	bsr	ms_snap
	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	lea	ps_fn_mod,a0		; playmod(true, PSYEVAL.MOD)
	bsr	playmod
	bsr	orc_dump		; loadscreen(psyche)
	lea	ps_mode_name,a0
	bsr	ms_load
	bcs	fatal
	FSSE				; part := 34/100
	FLDI	34
	FLDI	100
	bsr	fp_div
	lea	ps_part,a0
	bsr	fp_std
	bsr	ps_newbubbles
	move.w	#31,ps_graphindex
	clr.w	ps_mode
	move.w	#1,ps_crewindex
	TCOL	191
	BKCOL	0
	bsr	ps_drawcursor
	bsr	ps_adjustgraph
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	bsr	ps_redraw1
	bsr	mouseshow
	sf	GS_DONE(a6)
	movem.l	(sp)+,d3
	rts

ps_prev:
	bsr	ps_erasebubbles
	subq.w	#1,ps_crewindex
	bgt.s	.r
	move.w	#6,ps_crewindex
.r:	bsr	ps_redraw
	bra	ps_newbubbles
ps_next:
	bsr	ps_erasebubbles
	addq.w	#1,ps_crewindex
	cmp.w	#6,ps_crewindex
	ble.s	.r
	move.w	#1,ps_crewindex
.r:	bsr	ps_redraw
	bra	ps_newbubbles

ps_toclosed:				; psychemode 1 -> 0
	clr.w	ps_mode
	bsr	ps_drawcursor
	bsr	ps_closedisplay
	bsr	mousehide
	BAR	299,111,301,145,0
	bra	mouseshow
ps_toopen:
	move.w	#1,ps_mode
	bsr	ps_drawcursor
	bra	ps_opendisplay

ps_processkey:
	bsr	kbd_readkey
	tst.b	d0
	bne.s	.a
	bsr	kbd_readkey
	cmp.b	#72,d0
	bne.s	.d
	bsr	ps_prev
	bra.s	.x
.d:	cmp.b	#80,d0
	bne.s	.x
	bsr	ps_next
	bra.s	.x
.a:	cmp.b	#'1',d0
	bne.s	.e
	cmp.w	#1,ps_mode
	bne.s	.o
	bsr	ps_toclosed
	bra.s	.x
.o:	bsr	ps_toopen
	bra.s	.x
.e:	cmp.b	#'`',d0			; bossmode
	bne.s	.eb
	bsr	bossmode
	bra.s	.x
.eb:	cmp.b	#27,d0			; (#10 heap stats: not on the ST)
	bne.s	.x
	st	GS_DONE(a6)
.x:	clr.w	GS_IDLETIME(a6)
	rts

ps_findmouse:
	movem.l	d3-d4,-(sp)
	bsr	kbd_mouse_status
	tst.b	d0
	beq	.x
	bsr	kbd_mouse_xy
	move.w	d0,d3
	move.w	d1,d4
	cmp.w	#157,d4			; 157..175: done (x 296..306)
	blt.s	.y18
	cmp.w	#175,d4
	bgt	.c2
	cmp.w	#295,d3
	ble	.c2
	cmp.w	#307,d3
	bge	.c2
	st	GS_DONE(a6)
	bra	.c2
.y18:	moveq	#18,d0			; the +/- rows: 18-24 men, 26-32 phy, 34-40 emo
	lea	ps_altmen,a3
	cmp.w	#24,d4
	ble	.pm
	moveq	#26,d0
	lea	ps_altphy,a3
	cmp.w	#32,d4
	ble.s	.pm
	moveq	#34,d0
	lea	ps_altemo,a3
	cmp.w	#40,d4
	ble.s	.pm
	cmp.w	#41,d4
	blt	.c2
	cmp.w	#48,d4
	bgt	.c2
	cmp.w	#179,d3			; 41..48: the display / crew buttons
	blt	.c2
	cmp.w	#205,d3
	bgt.s	.b2
	tst.w	ps_mode
	beq	.c2
	bsr	ps_toclosed
	bra	.c2
.b2:	cmp.w	#207,d3
	blt	.c2
	cmp.w	#241,d3
	bgt.s	.b3
	cmp.w	#1,ps_mode
	beq	.c2
	bsr	ps_toopen
	bra	.c2
.b3:	cmp.w	#262,d3
	blt	.c2
	cmp.w	#280,d3
	bgt.s	.b4
	bsr	ps_prev
	bra	.c2
.b4:	cmp.w	#286,d3
	blt	.c2
	cmp.w	#304,d3
	bgt	.c2
	bsr	ps_next
	bra	.c2
.pm:	cmp.w	d0,d4
	blt	.c2
	cmp.w	#250,d3
	blt	.c2
	cmp.w	#259,d3
	bgt.s	.mi
	moveq	#1,d0
	jsr	(a3)
	bsr	ps_redraw
	bra.s	.c2
.mi:	cmp.w	#307,d3
	blt.s	.c2
	cmp.w	#316,d3
	bgt.s	.c2
	moveq	#-1,d0
	jsr	(a3)
	bsr	ps_redraw
.c2:	cmp.w	#22,d4			; the encode button: x 12..19, y 22..60
	blt.s	.i
	cmp.w	#60,d4
	bgt.s	.i
	cmp.w	#11,d3
	ble.s	.i
	cmp.w	#20,d3
	bge.s	.i
	moveq	#1,d0			; lifesupportfailure or encodecrew(181)
	bsr	en_lifecheck
.i:	clr.w	GS_IDLETIME(a6)
.x:	movem.l	(sp)+,d3-d4
	rts

ps_mainloop:
.l:	st	GS_PALETTEDIRTY(a6)	; palettedirty := true; fadestep(FADESTEP_STEP)
	moveq	#8,d0
	bsr	fadestep
	bsr	pushrand
	bsr	ps_findmouse
	bsr	poprand
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	ps_processkey
.nk:	addq.w	#1,GS_IDLETIME(a6)
	cmp.w	#MAXIDLE,GS_IDLETIME(a6)
	bne.s	.ni
	bsr	screensaver
.ni:	bsr	pushrand
	bsr	ps_adjustgraph
	bsr	poprand
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	cmp.w	#8,GS_BATINDEX(a6)
	bge.s	.b0
	addq.w	#1,GS_BATINDEX(a6)
	bra.s	.dl
.b0:	clr.w	GS_BATINDEX(a6)
	bsr	addtime2
	bsr	pushrand
	bsr	mousehide
	move.w	ps_crewindex,d0
	bsr	ps_drawprimary
	bsr	ps_drawgraphs
	bsr	mouseshow
	bsr	poprand
.dl:	move.w	GS_TSLICE(a6),d0	; delay(tslice*FADE_TSLICE_MUL_CREW2)
	mulu	#6,d0
	bsr	delay
	bsr	ps_movebubbles
	tst.b	GS_DONE(a6)
	beq	.l
	rts

	section	data
ps_mode_name:	dc.b	"PSYCHE",0
ps_fn_mod:	dc.b	"SOUND",92,"PSYEVAL.MOD",0
ps_jobs:				; string[13] each
	dc.b	11,"Psychometry  "
	dc.b	11,"Engineering  "
	dc.b	11,"  Science    "
	dc.b	10," Security    "
	dc.b	11,"Astrogation  "
	dc.b	11,"  Medical    "
	even
	section	bss
c2r_randsave:	ds.l	1
ps_part:	ds.l	2
ps_col:		ds.l	2
ps_cs:		ds.l	2
ps_gb:		ds.w	8
ps_h:		ds.w	6
ps_m:		ds.w	1
ps_mode:	ds.w	1
ps_crewindex:	ds.w	1
ps_graphindex:	ds.w	1
ps_i:		ds.w	1
ps_j:		ds.w	1
ps_a:		ds.w	1
ps_bubbles:	ds.l	MAXBUBBLES+1	; [i, 1] = y, [i, 2] = x
ps_s:		ds.b	32
	even
	section	text
