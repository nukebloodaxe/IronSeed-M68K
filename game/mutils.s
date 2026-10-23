; mutils.s - utils.pas (and c_utils.c line) for MAIN.PRG, drawing into the chunky shadow (mscr.s).
;
; chevent       in: d0.w n  out: d0.w = 1 if event n happened (Z clear)     trashes: d0-d1/a0
; ms_line       in: d0-d3 = x1,y1,x2,y2, d4.b colour: c_utils.c line()      trashes: d0-d2/a0-a2
; plainfadearea in: d0-d3 = x1,y1,x2,y2, d4.w alt (mousehide/show around)  trashes: d0-d2/a0-a2
; graybutton / revgraybutton  in: d0-d3 = x1,y1,x2,y2                       trashes: d0-d2/a0-a2
; colorarea     in: d0-d3 = x1,y1,x2,y2, d4.w alt, d5.w index (1-4)        trashes: d0-d2/a0-a2
; incargoindex  in: d0.w item  out: d0.w = slot 1-250 or 0                 trashes: d0-d1/a0
; incargo       in: d0.w item  out: d0.w = numcargo - rescargo (0 if none)  trashes: d0-d1/a0
; incargoreal / incargores   (the same for numcargo / rescargo)
; rebuildcargoreserve        utils.pas RebuildCargoReserve                  trashes: d0-d2/a0-a2
; findfirstplanet in: d0.w system  out: d0.w = first planet index of it     trashes: d0-d1/a0
; wait          in: d0.w seconds: delay(s*1000)

	section	text
chevent:
	tst.w	d0
	bmi.s	.yes
	cmp.w	#19999,d0
	bgt.s	.yes
	cmp.w	#8192,d0
	bge.s	.no
	move.w	d0,d1
	lsr.w	#3,d1
	lea	GS_EVENTS(a6),a0
	and.w	#7,d0
	btst	d0,0(a0,d1.w)
	beq.s	.no
.yes:	moveq	#1,d0
	rts
.no:	moveq	#0,d0
	rts

; ---------------------------------------------------------------
ms_line:
	movem.l	d0-d4,-(sp)		; dirty: the bounding box
	cmp.w	d0,d2
	bge.s	.a
	exg	d0,d2
.a:	cmp.w	d1,d3
	bge.s	.b
	exg	d1,d3
.b:	bsr	ms_dirty
	movem.l	(sp)+,d0-d4
	movem.l	d3-d7,-(sp)
	move.b	d4,ms_lcol
	move.w	d2,d5
	sub.w	d0,d5			; dx
	moveq	#1,d6
	tst.w	d5
	bgt.s	.sx
	moveq	#-1,d6
.sx:	move.w	d6,ms_sdx
	tst.w	d5
	bpl.s	.ax
	neg.w	d5
.ax:	move.w	d3,d6
	sub.w	d1,d6			; dy
	moveq	#1,d7
	tst.w	d6
	bgt.s	.sy
	moveq	#-1,d7
.sy:	move.w	d7,ms_sdy
	tst.w	d6
	bpl.s	.ay
	neg.w	d6
.ay:	move.w	d0,d3
	move.w	d1,d4
	move.w	d6,d7
	lsr.w	#1,d7
	move.w	d7,ms_accx
	move.w	d5,d7
	lsr.w	#1,d7
	move.w	d7,ms_accy
	bsr.s	.put
	cmp.w	d6,d5
	blt.s	.vert
	move.w	d5,d7
	bra.s	.hn
.hl:	move.w	ms_accy,d0
	add.w	d6,d0
	cmp.w	d5,d0
	blt.s	.h1
	sub.w	d5,d0
	add.w	ms_sdy,d4
.h1:	move.w	d0,ms_accy
	add.w	ms_sdx,d3
	bsr.s	.put
.hn:	dbf	d7,.hl
	bra.s	.x
.vert:	move.w	d6,d7
	bra.s	.vn
.vl:	move.w	ms_accx,d0
	add.w	d5,d0
	cmp.w	d6,d0
	blt.s	.v1
	sub.w	d6,d0
	add.w	ms_sdx,d3
.v1:	move.w	d0,ms_accx
	add.w	ms_sdy,d4
	bsr.s	.put
.vn:	dbf	d7,.vl
.x:	movem.l	(sp)+,d3-d7
	rts
.put:	move.w	d3,d0
	move.w	d4,d1
	move.b	ms_lcol,d2
	bra	chk_pset

plainfadearea:
	movem.l	d0-d4,-(sp)
	bsr	mousehide
	movem.l	(sp)+,d0-d4
	bsr	ms_fade
	bra	mouseshow

; utils.pas graybutton
graybutton:
	movem.l	d3-d7,-(sp)
	movem.w	d0-d3,ms_bx
	moveq	#5,d4			; rows y1..y2 in 5
	bsr	ms_bar
	movem.w	ms_bx,d0-d3
	move.w	d3,d1			; row y2 in 2
	moveq	#2,d4
	bsr	ms_bar
	movem.w	ms_bx,d0-d3
	move.w	d1,d3			; row y1 in 10
	moveq	#10,d4
	bsr	ms_bar
	movem.w	ms_bx,d0-d3
	move.w	d2,d0			; line(x2,y1,x2,y2) in 2
	moveq	#2,d4
	bsr	ms_line
	movem.w	ms_bx,d0-d3
	move.w	d0,d2			; line(x1,y1,x1,y2) in 10
	moveq	#10,d4
	bsr	ms_line
	movem.w	ms_bx,d0-d3
	move.w	d2,d0			; screen[y1,x2] := 6
	moveq	#6,d2
	bsr	ms_pset
	movem.w	ms_bx,d0-d3
	move.w	d3,d1			; screen[y2,x1] := 6
	moveq	#6,d2
	bsr	ms_pset
	movem.l	(sp)+,d3-d7
	rts

; utils.pas revgraybutton
revgraybutton:
	movem.l	d3-d7,-(sp)
	movem.w	d0-d3,ms_bx
	move.w	d3,d1			; row y2 in 10
	moveq	#10,d4
	bsr	ms_bar
	movem.w	ms_bx,d0-d3
	move.w	d1,d3			; row y1 in 2
	moveq	#2,d4
	bsr	ms_bar
	movem.w	ms_bx,d0-d3
	move.w	d2,d0			; line(x2,y1,x2,y2) in 10
	moveq	#10,d4
	bsr	ms_line
	movem.w	ms_bx,d0-d3
	move.w	d0,d2			; line(x1,y1,x1,y2) in 2
	moveq	#2,d4
	bsr	ms_line
	movem.w	ms_bx,d0-d3
	move.w	d2,d0			; screen[y1,x2] := 4
	moveq	#4,d2
	bsr	ms_pset
	movem.w	ms_bx,d0-d3
	move.w	d3,d1			; screen[y2,x1] := 4
	moveq	#4,d2
	bsr	ms_pset
	movem.l	(sp)+,d3-d7
	rts

; utils.pas colorarea: non-zero pixels - statcolors[index] + alt; statcolors[index] := alt
colorarea:
	movem.l	d3-d7/a3,-(sp)
	movem.w	d0-d3,ms_bx
	bsr	mousehide
	movem.w	ms_bx,d0-d3
	bsr	ms_dirty
	lea	GS_STATCOLORS-1(a6),a3
	add.w	d5,a3
	move.b	d4,d7
	sub.b	(a3),d7			; alt - statcolors[index] (mod 256)
	movem.w	ms_bx,d0-d3
	bsr	ms_addr			; a0 = (x1, y1)
	sub.w	d0,d2			; columns - 1
	sub.w	ms_bx+2,d3		; rows - 1
	move.w	#MS_W,d6
	sub.w	d2,d6
	subq.w	#1,d6
.r:	move.w	d2,d1
.c:	tst.b	(a0)
	beq.s	.z
	add.b	d7,(a0)
.z:	addq.l	#1,a0
	dbf	d1,.c
	add.w	d6,a0
	dbf	d3,.r
	bsr	mouseshow
	move.b	d4,(a3)
	movem.l	(sp)+,d3-d7/a3
	rts

; ---------------------------------------------------------------
incargoindex:
	lea	GS_SHIP+SHIP_CARGO(a6),a0
	moveq	#1,d1
.l:	cmp.w	(a0)+,d0
	beq.s	.f
	addq.w	#1,d1
	cmp.w	#251,d1
	bne.s	.l
	moveq	#0,d0
	rts
.f:	move.w	d1,d0
	rts

incargoreal:
	bsr.s	incargoindex
	beq.s	.x
	add.w	d0,d0
	lea	GS_SHIP+SHIP_NUMCARGO-2(a6),a0
	move.w	0(a0,d0.w),d0
.x:	rts

incargo:
	bsr.s	incargoindex
	beq.s	.x
	add.w	d0,d0
	lea	GS_SHIP+SHIP_NUMCARGO-2(a6),a0
	move.w	0(a0,d0.w),d1
	lea	GS_RESCARGO-2(a6),a0
	sub.w	0(a0,d0.w),d1
	move.w	d1,d0
.x:	rts

incargores:
	bsr.s	incargoindex
	beq.s	.x
	add.w	d0,d0
	lea	GS_RESCARGO-2(a6),a0
	move.w	0(a0,d0.w),d0
.x:	rts

; AddCargoReserves(item d0, team d1, first d2.b): out d0.w = team
addcargoreserves:
	movem.l	d3-d6/a3,-(sp)
	move.w	d0,d3			; item
	move.w	d1,d4			; team
	move.b	d2,d5			; first
	tst.w	d3
	bne.s	.n0
	moveq	#-1,d0			; no stock
	bra.s	.out
.n0:	tst.w	d4
	ble.s	.nt
	move.w	d4,d0			; ship.engrteam[team].job = item: this team is working on it
	subq.w	#1,d0
	lsl.w	#3,d0
	lea	GS_SHIP+SHIP_ENGRTEAM+TEAM_JOB(a6),a0
	cmp.w	0(a0,d0.w),d3
	bne.s	.nt
	moveq	#0,d0
	bra.s	.out
.nt:	tst.b	d5
	bne.s	.ns
	move.w	d3,d0
	bsr	incargo
	tst.w	d0
	ble.s	.ns
	move.w	d3,d0			; in stock: reserve one
	bsr	incargoindex
	add.w	d0,d0
	lea	GS_RESCARGO-2(a6),a0
	addq.w	#1,0(a0,d0.w)
	move.w	d4,d0
	bra.s	.out
.ns:	lea	GS_CARGO+CARGO_INDEX(a6),a0	; i := the item's cargo entry
	moveq	#0,d6
.ci:	cmp.w	(a0),d3
	beq.s	.cf
	lea	CARGO_SIZEOF(a0),a0
	addq.w	#1,d6
	cmp.w	#MAXCARGO,d6
	bne.s	.ci
	moveq	#-1,d0			; doesn't exist
	bra.s	.out
.cf:	mulu	#6,d6			; reserve the 3 sub parts
	lea	GS_PRTCARGO(a6),a3
	add.w	d6,a3
	moveq	#3-1,d6
.p:	move.w	(a3)+,d0
	move.w	d4,d1
	moveq	#0,d2
	bsr	addcargoreserves
	move.w	d0,d4
	dbf	d6,.p
	move.w	d4,d0
.out:	movem.l	(sp)+,d3-d6/a3
	rts

rebuildcargoreserve:
	movem.l	d3/a3,-(sp)
	lea	GS_RESCARGO(a6),a0
	move.w	#250-1,d0
.c:	clr.w	(a0)+
	dbf	d0,.c
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a3
	moveq	#1,d3
.t:	cmp.w	#3,TEAM_JOBTYPE(a3)	; JOBTYPE_CREATE
	bne.s	.n
	move.w	TEAM_EXTRA(a3),d0
	beq.s	.n
	cmp.w	TEAM_JOB(a3),d0
	beq.s	.n
	move.w	d3,d1
	st	d2
	bsr	addcargoreserves
.n:	addq.l	#TEAM_SIZEOF,a3
	addq.w	#1,d3
	cmp.w	#3,d3
	ble.s	.t
	movem.l	(sp)+,d3/a3
	rts

; utils.pas findfirstplanet(sys): first i with tempplan^[i].system = sys
findfirstplanet:
	sf	GS_DONE(a6)
	move.l	GS_TEMPPLAN(a6),a0
	moveq	#1,d1
.l:	cmp.b	PLANET_SYSTEM(a0),d0
	beq.s	.f
	cmp.w	#1000,d1
	beq.s	.f
	lea	PLANET_SIZEOF(a0),a0
	addq.w	#1,d1
	bra.s	.l
.f:	move.w	d1,d0
	rts

wait:
	mulu	#1000,d0
	bra	delay

	section	bss
ms_bx:		ds.w	4
ms_sdx:		ds.w	1
ms_sdy:		ds.w	1
ms_accx:	ds.w	1
ms_accy:	ds.w	1
ms_lcol:	ds.b	1
	even
