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
	move.w	d2,ms_end
	move.w	d3,ms_end+2
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
	move.l	ms_end,ms_curx		; cur_x, cur_y := x2, y2
	rts
.put:	move.w	d4,d1			; screen[py,px] := colour (xor colour in xor mode)
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	add.w	d3,a0
	move.b	ms_lcol,d2
	tst.b	ms_xor
	beq.s	.cp
	eor.b	d2,(a0)
	rts
.cp:	move.b	d2,(a0)
	rts

; c_utils.c moveto(x d0, y d1) / lineto(x d0, y d1) (colour d4)
ms_moveto:
	move.w	d0,ms_curx
	move.w	d1,ms_cury
	rts
ms_lineto:
	movem.l	d3,-(sp)
	move.w	d0,d2
	move.w	d1,d3
	move.w	ms_curx,d0
	move.w	ms_cury,d1
	bsr	ms_line
	movem.l	(sp)+,d3
	rts

; c_utils.c circle(x d0, y d1, r d2) in colour d4 (its 0.9 aspect: rows from ct_up/ct_dn)
ms_circle:
	movem.l	d3-d7,-(sp)
	move.w	d0,d5			; x
	move.w	d1,d6			; y
	move.w	d2,d7			; r
	movem.w	d0-d2,-(sp)		; dirty: x-r .. x+r, y-r .. y+r (clipped)
	sub.w	d2,d0
	bpl.s	.d1
	moveq	#0,d0
.d1:	sub.w	d2,d1
	bpl.s	.d2
	moveq	#0,d1
.d2:	move.w	2(sp),d3
	add.w	d2,d3
	cmp.w	#MS_H-1,d3
	ble.s	.d3
	move.w	#MS_H-1,d3
.d3:	move.w	(sp),d2
	add.w	4(sp),d2
	cmp.w	#MS_W-1,d2
	ble.s	.d4
	move.w	#MS_W-1,d2
.d4:	bsr	ms_dirty
	addq.l	#6,sp
	move.b	d4,ms_lcol
	cmp.w	#MC_RMAX,d7		; (Phase 6i) radius <= MC_RMAX: from the kept pixel list
	bhi	.old
	cmp.w	mc_r,d7
	beq.s	.have
	bsr	mc_build
.have:	move.w	mc_n,d3
	beq	.x
	subq.w	#1,d3
	lea	mc_list,a1
	move.w	d5,d0			; the whole circle on the screen: no pixel needs the check
	sub.w	d7,d0
	bmi.s	.slow
	move.w	d5,d0
	add.w	d7,d0
	cmp.w	#MS_W,d0
	bge.s	.slow
	move.w	d6,d0
	add.w	mc_dymin,d0
	bmi.s	.slow
	move.w	d6,d0
	add.w	mc_dymax,d0
	cmp.w	#MS_H,d0
	bge.s	.slow
	move.w	d6,d1
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	add.w	d5,a0
.f:	move.l	(a1)+,d0		; dy * W + dx
	addq.l	#4,a1
	move.b	d4,0(a0,d0.l)
	dbf	d3,.f
	bra	.x
.slow:	addq.l	#4,a1
	move.w	(a1)+,d0
	add.w	d5,d0
	move.w	(a1)+,d1
	add.w	d6,d1
	cmp.w	#MS_W,d0
	bhs.s	.sn
	cmp.w	#MS_H,d1
	bhs.s	.sn
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	move.b	d4,0(a0,d0.w)
.sn:	dbf	d3,.slow
	bra.s	.x
.old:	moveq	#0,d3			; xx
	move.w	d7,d4			; yy
	move.w	d7,d0			; r*r
	mulu	d7,d0
	move.l	d0,ms_rr
	bsr.s	.four
.l:	tst.w	d4			; while yy >= 1
	ble.s	.x
	subq.w	#1,d4
	bsr.s	.inside
	bge.s	.n1
	addq.w	#1,d3
.n1:	bsr.s	.inside
	bge.s	.n2
	addq.w	#1,d4
.n2:	bsr.s	.four
	bra.s	.l
.x:	movem.l	(sp)+,d3-d7
	rts
.inside:				; xx*xx + yy*yy - r*r  (flags: lt = inside)
	move.w	d3,d0
	muls	d3,d0
	move.w	d4,d1
	muls	d4,d1
	add.l	d1,d0
	sub.l	ms_rr,d0
	rts
.four:	lea	ct_up,a1		; (x +- xx, y + up[yy]) and (x +- xx, y + dn[yy])
	move.b	0(a1,d4.w),d1
	ext.w	d1
	add.w	d6,d1
	move.w	d5,d0
	add.w	d3,d0
	bsr.s	.px
	move.w	d5,d0
	sub.w	d3,d0
	bsr.s	.px
	lea	ct_dn,a1
	move.b	0(a1,d4.w),d1
	ext.w	d1
	add.w	d6,d1
	move.w	d5,d0
	add.w	d3,d0
	bsr.s	.px
	move.w	d5,d0
	sub.w	d3,d0
.px:	cmp.w	#MS_W,d0		; (the original asserts inside the screen)
	bhs.s	.pxx
	cmp.w	#MS_H,d1
	bhs.s	.pxx
	move.w	d1,-(sp)
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	move.b	ms_lcol,0(a0,d0.w)
	move.w	(sp)+,d1
.pxx:	rts

; mc_build: circle(0, 0, r = d7)'s pixels in ms_circle's order into mc_list (8 bytes each: dy*W+dx
; long, dx, dy), their dy range.  keeps d5-d7.  trashes d0-d2/a0-a2
MC_RMAX		equ	63
MC_MAX		equ	640
mc_build:
	movem.l	d3-d6,-(sp)
	move.w	d7,mc_r
	clr.w	mc_n
	move.w	#$7fff,mc_dymin
	move.w	#-$7fff,mc_dymax
	lea	mc_list,a2
	moveq	#0,d5
	moveq	#0,d6
	moveq	#0,d3			; xx
	move.w	d7,d4			; yy
	move.w	d7,d0			; r*r
	mulu	d7,d0
	move.l	d0,ms_rr
	bsr.s	.four
.l:	tst.w	d4
	ble.s	.x
	subq.w	#1,d4
	bsr.s	.inside
	bge.s	.n1
	addq.w	#1,d3
.n1:	bsr.s	.inside
	bge.s	.n2
	addq.w	#1,d4
.n2:	bsr.s	.four
	bra.s	.l
.x:	movem.l	(sp)+,d3-d6
	rts
.inside:
	move.w	d3,d0
	muls	d3,d0
	move.w	d4,d1
	muls	d4,d1
	add.l	d1,d0
	sub.l	ms_rr,d0
	rts
.four:	lea	ct_up,a1
	move.b	0(a1,d4.w),d1
	ext.w	d1
	move.w	d3,d0
	bsr.s	.px
	move.w	d3,d0
	neg.w	d0
	bsr.s	.px
	lea	ct_dn,a1
	move.b	0(a1,d4.w),d1
	ext.w	d1
	move.w	d3,d0
	bsr.s	.px
	move.w	d3,d0
	neg.w	d0
.px:	cmp.w	#MC_MAX,mc_n		; (cannot fill: r <= MC_RMAX)
	bhs.s	.pxx
	addq.w	#1,mc_n
	move.w	d1,d2
	muls	#MS_W,d2
	move.w	d0,a0
	add.l	a0,d2
	move.l	d2,(a2)+
	move.w	d0,(a2)+
	move.w	d1,(a2)+
	cmp.w	mc_dymin,d1
	bge.s	.p1
	move.w	d1,mc_dymin
.p1:	cmp.w	mc_dymax,d1
	ble.s	.pxx
	move.w	d1,mc_dymax
.pxx:	rts

; c_utils.c rectangle(x1 d0, y1 d1, x2 d2, y2 d3) in colour d4 (the far corner stays unset)
ms_rect:
	movem.l	d3-d7,-(sp)
	movem.w	d0-d3,ms_bx
	move.b	d4,ms_lcol
	cmp.w	d0,d2			; the dirty box
	bge.s	.a
	exg	d0,d2
.a:	cmp.w	d1,d3
	bge.s	.b
	exg	d1,d3
.b:	bsr	ms_dirty
	movem.w	ms_bx,d0-d3
	move.w	d0,d5			; horizontal: i from min(x1,x2) to max-1: rows y1 and y2
	move.w	d2,d6
	cmp.w	d5,d6
	bge.s	.h
	exg	d5,d6
.h:	cmp.w	d6,d5
	bge.s	.v
	move.w	d5,d0
	move.w	ms_bx+2,d1
	bsr.s	.px
	move.w	d5,d0
	move.w	ms_bx+6,d1
	bsr.s	.px
	addq.w	#1,d5
	bra.s	.h
.v:	move.w	ms_bx+2,d5		; vertical: i from min(y1,y2) to max-1: columns x1 and x2
	move.w	ms_bx+6,d6
	cmp.w	d5,d6
	bge.s	.vl
	exg	d5,d6
.vl:	cmp.w	d6,d5
	bge.s	.x
	move.w	ms_bx,d0
	move.w	d5,d1
	bsr.s	.px
	move.w	ms_bx+4,d0
	move.w	d5,d1
	bsr.s	.px
	addq.w	#1,d5
	bra.s	.vl
.x:	movem.l	(sp)+,d3-d7
	rts
.px:	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	move.b	ms_lcol,0(a0,d0.w)
	rts

; c_utils.c pieslice(x d0, y d1, 0, 360, r d2) in fill colour d4: a full disc,
; v_buf[x+i, y-(int)(j*0.9)] for i, j in -r..r-1 with i*i+j*j <= r*r
ms_disc:
	movem.l	d3-d7,-(sp)
	move.w	d0,d5
	move.w	d1,d6
	move.w	d2,d7
	move.b	d4,ms_lcol
	move.w	d7,d0
	mulu	d7,d0
	move.l	d0,ms_rr
	movem.w	d5-d7,-(sp)		; dirty box: x-r .. x+r-1, y-r .. y+r
	move.w	d5,d0
	sub.w	d7,d0
	move.w	d6,d1
	sub.w	d7,d1
	move.w	d5,d2
	add.w	d7,d2
	move.w	d6,d3
	add.w	d7,d3
	bsr	ms_dirty
	movem.w	(sp)+,d5-d7
	move.w	d7,d3			; j from -r
	neg.w	d3
.j:	cmp.w	d7,d3
	bge.s	.x
	lea	ct_pie+100,a1
	move.b	0(a1,d3.w),d1
	ext.w	d1
	neg.w	d1
	add.w	d6,d1			; row y - (int)(j*0.9)
	mulu	#MS_W,d1
	move.l	ms_buf,a2
	add.l	d1,a2
	add.w	d5,a2			; + x
	move.w	d7,d4			; i from -r
	neg.w	d4
.i:	cmp.w	d7,d4
	bge.s	.jn
	move.w	d4,d0
	muls	d4,d0
	move.w	d3,d1
	muls	d3,d1
	add.l	d1,d0
	cmp.l	ms_rr,d0
	bgt.s	.in
	move.b	ms_lcol,0(a2,d4.w)
.in:	addq.w	#1,d4
	bra.s	.i
.jn:	addq.w	#1,d3
	bra.s	.j
.x:	movem.l	(sp)+,d3-d7
	rts

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
; (Phase 6i) the last answer is kept: crewgen makes each system's planets one consecutive run, so
; planet r is the first of system s when r's system is s and r-1's is not (checked at every use).
findfirstplanet:
	sf	GS_DONE(a6)
	move.l	GS_TEMPPLAN(a6),a0
	cmp.b	mu_ffs,d0
	bne.s	.s
	move.w	mu_ffr,d1		; (0: nothing kept)
	beq.s	.s
	move.w	d1,d2
	mulu	#PLANET_SIZEOF,d2
	lea	-PLANET_SIZEOF(a0,d2.l),a1	; tempplan^[r]
	cmp.b	PLANET_SYSTEM(a1),d0
	bne.s	.s
	cmp.w	#1,d1
	beq.s	.f
	cmp.b	-PLANET_SIZEOF+PLANET_SYSTEM(a1),d0
	bne.s	.f
.s:	moveq	#1,d1
.l:	cmp.b	PLANET_SYSTEM(a0),d0
	beq.s	.k
	cmp.w	#1000,d1
	beq.s	.f
	lea	PLANET_SIZEOF(a0),a0
	addq.w	#1,d1
	bra.s	.l
.k:	move.b	d0,mu_ffs
	move.w	d1,mu_ffr
.f:	move.w	d1,d0
	rts

wait:
	mulu	#1000,d0
	bra	delay

	section	bss
mc_n:		ds.w	1
mc_dymin:	ds.w	1
mc_dymax:	ds.w	1
mc_list:	ds.l	2*MC_MAX
	section	data
mc_r:		dc.w	-1		; ms_circle's kept pixel list: its radius (-1 = none); count, dy range
	section	bss
mu_ffr:		ds.w	1		; findfirstplanet's kept result (0 = none) and system
mu_ffs:		ds.b	1
	even
ms_bx:		ds.w	4
ms_sdx:		ds.w	1
ms_sdy:		ds.w	1
ms_accx:	ds.w	1
ms_accy:	ds.w	1
ms_lcol:	ds.b	1
ms_xor:		ds.b	1		; c_utils.c setwritemode: <> 0 = xorput (ms_line)
	even
ms_curx:	ds.w	1		; c_utils.c cur_x, cur_y (moveto/lineto; line sets them)
ms_cury:	ds.w	1
ms_end:		ds.w	2
ms_rr:		ds.l	1
	even

	section	text
; ---------------------------------------------------------------- cargo (utils.pas)
; utils.pas sortcargo: bubble sort of ship.cargo[] / numcargo[] by item
sortcargo:
	movem.l	d3,-(sp)
.r:	moveq	#0,d3			; changed
	lea	GS_SHIP+SHIP_CARGO(a6),a0
	lea	GS_SHIP+SHIP_NUMCARGO(a6),a1
	move.w	#249-1,d2
.j:	move.w	(a0),d0
	cmp.w	2(a0),d0
	ble.s	.n
	move.w	2(a0),(a0)
	move.w	d0,2(a0)
	move.w	(a1),d0
	move.w	2(a1),(a1)
	move.w	d0,2(a1)
	moveq	#1,d3
.n:	addq.l	#2,a0
	addq.l	#2,a1
	dbf	d2,.j
	tst.w	d3
	bne.s	.r
	movem.l	(sp)+,d3
	rts

; the cargo weight: sum of cargo[i].size * numcargo[j] (artifacts through getartifactname, which
; rewrites cargo[maxcargo]); out d0.l
mu_weight:
	movem.l	d3-d5/a3,-(sp)
	moveq	#0,d5
	lea	GS_SHIP+SHIP_CARGO(a6),a3
	move.w	#250-1,d4
.j:	move.w	(a3)+,d0
	ble.s	.n
	bsr	mu_cargorec		; a0 = cargo[i]
	move.w	CARGO_SIZE(a0),d0
	muls	SHIP_NUMCARGO-SHIP_CARGO-2(a3),d0
	add.l	d0,d5
.n:	dbf	d4,.j
	move.l	d5,d0
	movem.l	(sp)+,d3-d5/a3
	rts
; item d0 -> a0 = its cargo[] record: artifacts are cargo[maxcargo] after getartifactname; else
; i := 1; while (cargo[i].index <> item) and (i < maxcargo) do inc(i)
mu_cargorec:
	cmp.w	#ID_ARTIFACT_OFFSET,d0
	ble.s	.f
	bsr	getartifactname
	lea	GS_CARGO+(MAXCARGO-1)*CARGO_SIZEOF(a6),a0
	rts
.f:	lea	GS_CARGO(a6),a0
	moveq	#1,d1
.l:	cmp.w	CARGO_INDEX(a0),d0
	beq.s	.x
	cmp.w	#MAXCARGO,d1
	bge.s	.x
	lea	CARGO_SIZEOF(a0),a0
	addq.w	#1,d1
	bra.s	.l
.x:	rts

; checkweight(background d0.b): out d0.w = 1 (Z clear) if the cargo fits
checkweight:
	movem.l	d3-d4/a3,-(sp)
	move.b	d0,d4
	bsr	mu_weight
	divs	#10,d0			; (weight is small: fits a word quotient)
	ext.l	d0
	move.w	d0,d3
	cmp.w	GS_SHIP+SHIP_CARGOMAX(a6),d3
	ble	.ok
	tst.b	d4
	beq	.fg
	lea	mu_bb,a3		; printbigbox('Cargo full! '+str1+'/'+str2+' used.', 'Must Jettison Cargo.')
	move.l	a3,a0			; (str1 string[4], str2 string[5])
	lea	.cf,a1
	bsr	pstr_cpy
	move.w	d3,d0
	bsr	mu_wstr
	move.l	a3,a0
	lea	mu_s,a1
	bsr	pstr_cat
	move.l	a3,a0
	lea	.sl,a1
	bsr	pstr_cat
	move.w	GS_SHIP+SHIP_CARGOMAX(a6),d0
	ext.l	d0
	moveq	#0,d1
	lea	mu_s,a0
	bsr	int_str
	cmp.b	#5,mu_s
	bls.s	.s5
	move.b	#5,mu_s
.s5:	move.l	a3,a0
	lea	mu_s,a1
	bsr	pstr_cat
	move.l	a3,a0
	lea	.us,a1
	bsr	pstr_cat
	move.l	a3,a0
	lea	.mj,a1
	bsr	printbigbox
	moveq	#0,d0
	bra	.x
.cf:	dc.b	12,"Cargo full! "
.sl:	dc.b	1,"/"
.us:	dc.b	6," used."
.mj:	dc.b	20,"Must Jettison Cargo."
	even
.fg:
	PRTLN
	TCOL	94
	PRT	"Cargo Full! "
	move.w	d3,d0
	bsr	mu_wstr			; str(weight, str1) (string[4])
	lea	mu_s,a0
	lea	mu_t_slash,a1
	bsr	pstr_cat
	lea	mu_s,a0
	bsr	print
	move.w	GS_SHIP+SHIP_CARGOMAX(a6),d0
	bsr	mu_wstr
	lea	mu_s,a0
	lea	mu_t_used,a1
	bsr	pstr_cat
	lea	mu_s,a0
	bsr	print
	PRTLN
	PRT	"Must jettison cargo."
	moveq	#0,d0
	bra.s	.x
.ok:	moveq	#1,d0
.x:	movem.l	(sp)+,d3-d4/a3
	tst.w	d0
	rts
	section	bss
mu_bb:	ds.b	40
	section	text
mu_wstr:				; str(d0.w) into mu_s, cut to 4 characters (a string[4])
	ext.l	d0
	moveq	#0,d1
	lea	mu_s,a0
	bsr	int_str
	cmp.b	#4,mu_s
	bls.s	.x
	move.b	#4,mu_s
.x:	rts

; addcargo(item d0, force d1.b): out d0.w = 1 (Z clear) if it fitted
addcargo:
	movem.l	d3-d5,-(sp)
	move.w	d0,d3
	move.b	d1,d5
	bsr	mu_weight
	move.l	d0,d4
	move.w	d3,d0
	bsr	mu_cargorec
	move.w	CARGO_SIZE(a0),d0
	ext.l	d0
	add.l	d0,d4
	divs	#10,d4			; weight div 10
	ext.l	d4
	cmp.w	GS_SHIP+SHIP_CARGOMAX(a6),d4
	ble.s	.fits
	cmp.w	#ID_ARTIFACT_OFFSET,d3
	bge.s	.fits
	tst.b	d5
	bne.s	.fits
	PRTLN
	TCOL	94
	PRT	"Cargo Full! "
	move.w	d4,d0
	bsr	mu_wstr
	lea	mu_s,a0
	lea	mu_t_slash,a1
	bsr	pstr_cat
	lea	mu_s,a0
	bsr	print
	move.w	GS_SHIP+SHIP_CARGOMAX(a6),d0
	bsr	mu_wstr
	lea	mu_s,a0
	lea	mu_t_used,a1
	bsr	pstr_cat
	lea	mu_s,a0
	bsr	print
	moveq	#0,d0
	bra	.x
.fits:	moveq	#1,d1			; j: the item's slot (counts >= 255 are cut on the way)
	lea	GS_SHIP+SHIP_CARGO(a6),a0
.j:	cmp.w	(a0),d3
	beq.s	.found
	cmp.w	#255,SHIP_NUMCARGO-SHIP_CARGO(a0)
	blo.s	.jn
	movem.l	d1/a0,-(sp)
	PRTLN
	TCOL	94
	PRT	"Too much of some cargo.  Dumping excess."
	movem.l	(sp)+,d1/a0
	move.w	#254,SHIP_NUMCARGO-SHIP_CARGO(a0)
.jn:	addq.l	#2,a0
	addq.w	#1,d1
	cmp.w	#251,d1
	bne.s	.j
	moveq	#1,d1			; not found: the first free slot
	lea	GS_SHIP+SHIP_NUMCARGO(a6),a0
.f:	tst.w	(a0)
	beq.s	.ff
	addq.l	#2,a0
	addq.w	#1,d1
	cmp.w	#251,d1
	bne.s	.f
	PRTLN
	TCOL	94
	PRT	"No cargo slot available.  Some cargo should be dumped.  Can not store."
	moveq	#0,d0
	bra.s	.x
.ff:	move.w	d3,SHIP_CARGO-SHIP_NUMCARGO(a0)
	move.w	#1,(a0)
	bra.s	.ok
.found:	cmp.w	#254,SHIP_NUMCARGO-SHIP_CARGO(a0)
	bhs.s	.full
	addq.w	#1,SHIP_NUMCARGO-SHIP_CARGO(a0)
.ok:	moveq	#1,d5
	cmp.w	GS_SHIP+SHIP_CARGOMAX(a6),d4
	ble.s	.s
	moveq	#0,d5
.s:	bsr	sortcargo
	move.w	d5,d0
	bra.s	.x
.full:	PRTLN
	TCOL	94
	PRT	"Already have too much of that cargo.  Can not store."
	moveq	#0,d0
.x:	movem.l	(sp)+,d3-d5
	tst.w	d0
	rts

; removecargo(item d0)
removecargo:
	lea	GS_SHIP+SHIP_CARGO(a6),a0	; j := 1; while (j < 250) and (cargo[j] <> item) do inc(j)
	moveq	#1,d1
.l:	cmp.w	(a0),d0
	beq.s	.f
	cmp.w	#250,d1
	bge.s	.f
	addq.l	#2,a0
	addq.w	#1,d1
	bra.s	.l
.f:	cmp.w	(a0),d0
	bne.s	.x			; (not there: the original warns and leaves)
	tst.w	SHIP_NUMCARGO-SHIP_CARGO(a0)
	beq.s	.x
	subq.w	#1,SHIP_NUMCARGO-SHIP_CARGO(a0)
	bne.s	.x
	clr.w	(a0)
.x:	rts

; CargoName(item d0): out a0 = Pascal string (trailing blanks cut; '??n??' if unknown)
cargoname:
	lea	GS_CARGO(a6),a0
	move.w	#MAXCARGO-1,d1
.l:	cmp.w	CARGO_INDEX(a0),d0
	beq.s	.f
	lea	CARGO_SIZEOF(a0),a0
	dbf	d1,.l
	ext.l	d0			; '??'+str(item)+'??'
	moveq	#0,d1
	lea	mu_s2,a0
	bsr	int_str
	lea	mu_s,a0
	lea	mu_t_qq,a1
	bsr	pstr_cpy
	lea	mu_s,a0
	lea	mu_s2,a1
	bsr	pstr_cat
	lea	mu_s,a0
	lea	mu_t_qq,a1
	bsr	pstr_cat
	lea	mu_s,a0
	rts
.f:	move.l	a0,a1			; CARGO_NAME = 0
	lea	mu_s,a0
	bsr	pstr_cpy
	lea	mu_s,a0
.t:	moveq	#0,d0
	move.b	(a0),d0
	beq.s	.x
	cmp.b	#' ',0(a0,d0.w)
	bne.s	.x
	subq.b	#1,(a0)
	bra.s	.t
.x:	rts

; getartifactname(n d0): cargo[maxcargo] := the artifact's name (padded to 20), size, index
getartifactname:
	movem.l	d3/a3,-(sp)
	move.w	d0,d3
	lea	GS_CARGO+(MAXCARGO-1)*CARGO_SIZEOF(a6),a3
	cmp.w	#ID_ART_SHUNT_DRIVE,d3
	bge	.named
	move.l	GS_ARTIFACTS(a6),a1	; artifacts^: array[1..60] of string[10]
	cmp.w	#ID_ARTIFACT2_OFFSET,d3
	ble.s	.a1
	move.w	d3,d0			; [((n-2off-1) div 10)+41] + ' ' + [((n-2off-1) mod 10)+51]
	sub.w	#ID_ARTIFACT2_OFFSET+1,d0
	ext.l	d0
	divu	#10,d0
	move.w	d0,d1
	add.w	#41,d1
	swap	d0
	add.w	#51,d0
	bra.s	.cat
.a1:	move.w	d3,d0			; [(n-off-1) div 20 + 1] + ' ' + [(n-off-1) mod 20 + 21]
	sub.w	#ID_ARTIFACT_OFFSET+1,d0
	ext.l	d0
	divu	#20,d0
	move.w	d0,d1
	addq.w	#1,d1
	swap	d0
	add.w	#21,d0
.cat:	move.w	d0,-(sp)
	subq.w	#1,d1			; first word
	mulu	#11,d1
	move.l	GS_ARTIFACTS(a6),a1
	add.l	d1,a1
	lea	CARGO_NAME(a3),a0
	bsr	pstr_cpy
	cmp.b	#20,CARGO_NAME(a3)	; (name is a string[20])
	bls.s	.c1
	move.b	#20,CARGO_NAME(a3)
.c1:	lea	CARGO_NAME(a3),a0
	lea	mu_t_space,a1
	bsr	mu_cat20
	move.w	(sp)+,d1		; second word
	subq.w	#1,d1
	mulu	#11,d1
	move.l	GS_ARTIFACTS(a6),a1
	add.l	d1,a1
	lea	CARGO_NAME(a3),a0
	bsr	mu_cat20
	moveq	#0,d0			; pad to 20 with blanks
	move.b	CARGO_NAME(a3),d0
.p:	cmp.w	#20,d0
	bge.s	.pd
	addq.w	#1,d0
	move.b	#' ',CARGO_NAME(a3,d0.w)
	bra.s	.p
.pd:	move.b	#20,CARGO_NAME(a3)
	moveq	#0,d0			; size := (n mod 40) + 1
	move.w	d3,d0
	divu	#40,d0
	swap	d0
	addq.w	#1,d0
	move.w	d0,CARGO_SIZE(a3)
	move.w	d3,CARGO_INDEX(a3)
	bra.s	.x
.named:	move.w	d3,d0			; the special artifacts (6900-6910); others keep the old name
	sub.w	#ID_ART_SHUNT_DRIVE,d0
	cmp.w	#10,d0
	bhi.s	.sz
	mulu	#21,d0
	lea	mu_artnames,a1
	add.w	d0,a1
	lea	CARGO_NAME(a3),a0
	bsr	pstr_cpy
.sz:	clr.w	CARGO_SIZE(a3)
	move.w	d3,CARGO_INDEX(a3)
.x:	movem.l	(sp)+,d3/a3
	rts
; pstr_cat limited to 20 characters (cargo names are string[20])
mu_cat20:
	moveq	#0,d0
	move.b	(a0),d0
	moveq	#0,d1
	move.b	(a1)+,d1
	bra.s	.n
.c:	cmp.w	#20,d0
	bge.s	.x
	addq.w	#1,d0
	move.b	(a1)+,0(a0,d0.w)
.n:	dbf	d1,.c
.x:	move.b	d0,(a0)
	rts

; printplanet(x1 d0, y1 d1, num d2, sys d3): the planet's name by its rank among the system's
; orbits ('    Star', 'Primus  ' ...)
printplanet:
	movem.l	d3-d6/a3,-(sp)
	movem.w	d0-d1,-(sp)
	move.w	d2,d5			; num
	move.w	d3,d0
	bsr	findfirstplanet
	move.w	d0,d4			; j
	move.w	d4,d0
	add.w	d5,d0
	bsr	mu_plan
	move.b	PLANET_ORBIT(a0),d6	; tempplan^[j+num].orbit
	moveq	#0,d5			; i
	moveq	#0,d1			; a
	move.w	d3,d0
	mulu	#SYSTEM_SIZEOF,d0
	lea	GS_SYSTEMS-SYSTEM_SIZEOF(a6),a3
	add.l	d0,a3
.l:	move.w	d4,d0
	add.w	d1,d0
	move.w	d1,-(sp)
	bsr	mu_plan
	move.w	(sp)+,d1
	cmp.b	PLANET_ORBIT(a0),d6
	bls.s	.n
	addq.w	#1,d5
.n:	addq.w	#1,d1
	cmp.b	SYSTEM_NUMPLANETS(a3),d1
	bne.s	.l
	movem.w	(sp)+,d0-d1
	cmp.w	#7,d5
	bhi.s	.x			; (no case: s keeps its value)
	mulu	#9,d5
	lea	mu_planetnames,a0
	add.w	d5,a0
	bsr	printxy
.x:	movem.l	(sp)+,d3-d6/a3
	rts
mu_plan:				; a0 := @tempplan^[d0]
	mulu	#PLANET_SIZEOF,d0
	move.l	GS_TEMPPLAN(a6),a0
	lea	-PLANET_SIZEOF(a0),a0
	add.l	d0,a0
	rts

; utils.pas readweaicon(n d0): tempicon^ := weapicon.dta record n
readweaicon:
	mulu	#400,d0
	move.l	weapicons,a0
	add.l	d0,a0
	move.l	GS_TEMPICON(a6),a1
	moveq	#400/4-1,d0
.c:	move.l	(a0)+,(a1)+
	dbf	d0,.c
	rts

	section	data
mu_t_slash:	dc.b	1,"/"
mu_t_used:	dc.b	6," Used."
mu_t_qq:	dc.b	2,"??"
mu_t_space:	dc.b	1," "
mu_planetnames:	dc.b	8,"    Star",8,"Primus  ",8,"Secundus",8,"Tertius ",8,"Quartus "
		dc.b	8,"Pentius ",8,"Quintus ",8,"Septius "
mu_artnames:	dc.b	20,"Shunt Drive         "
		dc.b	20,"Channeler           "
		dc.b	20,"Iron Seed           "
		dc.b	20,"Homing Device       "
		dc.b	20,"Detonator           "
		dc.b	20,"Thermal Plating     "
		dc.b	20,"Ermigen Data Tapes  "
		dc.b	20,"Glyptic Scythe      "
		dc.b	20,"Multi-Imager        "
		dc.b	20,"Ylinth Mutagenics   "
		dc.b	20,"Goolas              "
	even
	section	bss
mu_s:		ds.b	64
mu_s2:		ds.b	16
