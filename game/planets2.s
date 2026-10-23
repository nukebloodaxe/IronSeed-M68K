; planets2.s - utils2.pas / journey.pas for MAIN.PRG: the planets that are not spheres of land:
; gas giants (creategasplanet: bands, turbulence, spots; makegasplanet: the turning sphere with
; its own lighting), asteroid fields (makeastoroidfield: weapicon.dta's rocks scattered over the
; background) and gas clouds (makecloud: cos-shaped puffs), drawn over the bridge by
; drawastoroid. readyplanet (utils2.s) calls rp_gas / rp_asteroid / rp_cloud for them.
;
; creategasplanet / makegasplanet / makeastoroidfield / makecloud / drawastoroid  (no arguments)
;                                                       trashes: d0-d2/a0-a2

	section	text
; a0 = landform^[d0 (x 1..240), d1 (y 1..120)]   trashes d0-d1
lf_addr:
	subq.w	#1,d0
	mulu	#LAND_W,d0
	add.w	d1,d0
	subq.w	#1,d0
	move.l	GS_LANDFORM(a6),a0
	add.l	d0,a0
	rts

; ---------------------------------------------------------------- creategasplanet
creategasplanet:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	u2_curplan		; randseed := tempplan^[curplan].seed
	moveq	#0,d0
	move.w	PLANET_SEED(a3),d0
	bsr	mt_setseed
	moveq	#2,d0			; the colours
	bsr	mt_random
	lea	gp_cols,a0
	tst.w	d0
	beq.s	.c2
	move.l	#$00200030,(a0)+	; 32, 48, 64
	move.w	#64,(a0)
	bra.s	.bands
.c2:	move.l	#$00700080,(a0)+	; 112, 128, 96
	move.w	#96,(a0)
.bands:	moveq	#0,d6			; b
	moveq	#1,d5			; a
	moveq	#60,d7			; y1 := 60 downto 1
	moveq	#0,d4			; c
.y:	subq.w	#1,d5
	bne.s	.row
	move.w	d7,d5			; a := (60-abs(y1-60)) div 10 = y1 div 10
	ext.l	d5
	divu	#10,d5
	move.w	d5,d0			; a := a + 6 + random(a+5)  (an expression: random(int64))
	addq.w	#5,d0
	ext.l	d0
	bsr	mt_random64l
	add.w	d0,d5
	addq.w	#6,d5
	cmp.w	d7,d5			; if (a < y1) and (a+5 > y1) then a := y1 shr 1
	bge.s	.b
	move.w	d5,d0
	addq.w	#5,d0
	cmp.w	d7,d0
	ble.s	.b
	move.w	d7,d5
	lsr.w	#1,d5
.b:	moveq	#2,d0			; b := (b + random(2) + 1) mod 3
	bsr	mt_random
	add.w	d0,d6
	addq.w	#1,d6
	ext.l	d6
	divu	#3,d6
	swap	d6
	moveq	#5,d0			; c := cb + 8 + random(5)
	bsr	mt_random
	move.w	d6,d1
	add.w	d1,d1
	lea	gp_cols,a0
	add.w	0(a0,d1.w),d0
	addq.w	#8,d0
	move.w	d0,d4
.row:	moveq	#1,d3			; x1: landform^[x1, y1] and [x1, 121-y1] := c + random(2)
.x:	moveq	#2,d0
	bsr	mt_random
	add.w	d4,d0
	move.w	d0,-(sp)
	move.w	d3,d0
	move.w	d7,d1
	bsr	lf_addr
	move.w	(sp)+,d0
	move.b	d0,(a0)
	moveq	#2,d0
	bsr	mt_random
	add.w	d4,d0
	move.w	d0,-(sp)
	move.w	d3,d0
	moveq	#121,d1
	sub.w	d7,d1
	bsr	lf_addr
	move.w	(sp)+,d0
	move.b	d0,(a0)
	addq.w	#1,d3
	cmp.w	#240,d3
	ble.s	.x
	subq.w	#1,d7
	bne	.y
	; border turbulence: y1 := 3 to 119 (the loop variable moved on by 2 after a swirl row;
	; FPC's loop ends once it reaches the bound)
	moveq	#3,d7
.t:	moveq	#1,d0			; ([1, y1] and $f0) <> ([1, y1-1] and $f0)
	move.w	d7,d1
	bsr	lf_addr
	move.b	(a0),d0
	move.b	-1(a0),d1
	eor.b	d1,d0
	and.b	#$f0,d0
	beq.s	.tn
	moveq	#1,d3			; x1
.tx:	cmp.w	#240,d3
	bgt.s	.td
	moveq	#4,d0			; b := random(4)+1, at most 241-x1
	bsr	mt_random
	addq.w	#1,d0
	move.w	d0,d4
	move.w	d4,d0
	add.w	d3,d0
	cmp.w	#241,d0
	ble.s	.tb
	move.w	#241,d4
	sub.w	d3,d4
.tb:	move.w	d3,d0
	move.w	d7,d1
	move.w	d4,d2
	bsr	gp_makeswirl
	add.w	d4,d3
	bra.s	.tx
.td:	addq.w	#2,d7
.tn:	cmp.w	#119,d7
	bge.s	.sp
	addq.w	#1,d7
	bra.s	.t
.sp:	moveq	#5,d0			; spots: cnt := 6 + random(5)
	bsr	mt_random
	addq.w	#6,d0
	move.w	d0,gp_cnt
	move.w	#1,u2_ii		; (i: utils2's)
.s:	moveq	#3,d0			; c := c? + 2 + random(4)
	bsr	mt_random
	move.w	d0,d6
	moveq	#4,d0
	bsr	mt_random
	add.w	d6,d6
	lea	gp_cols,a0
	add.w	0(a0,d6.w),d0
	addq.w	#2,d0
	move.w	d0,gp_c
	cmp.w	#1,u2_ii		; sz
	bne.s	.sz2
	moveq	#5,d0
	bsr	mt_random
	add.w	#15,d0
	bra.s	.sz
.sz2:	moveq	#6,d0
	bsr	mt_random
	addq.w	#2,d0
.sz:	move.w	d0,d5			; sz
	move.w	d5,d0			; sz2, sz21, sz22
	mulu	d0,d0
	move.w	d0,gp_sz2
	move.w	d5,d0
	subq.w	#1,d0
	mulu	d0,d0
	move.w	d0,gp_sz21
	move.w	d5,d0
	subq.w	#2,d0
	muls	d0,d0
	move.w	d0,gp_sz22
	move.w	#240,d0			; x := random(240)
	bsr	mt_random
	move.w	d0,gp_x
	moveq	#110,d0			; y := random(110-sz-sz) + 5 + sz  (random(int64))
	sub.w	d5,d0
	sub.w	d5,d0
	ext.l	d0
	bsr	mt_random64l
	add.w	d5,d0
	addq.w	#5,d0
	move.w	d0,gp_y
	move.w	d5,d7			; x1 := -sz to sz
	neg.w	d7
.sx:	move.w	d7,d3			; xx := x1 + x, wrapped into 1..240
	add.w	gp_x,d3
	cmp.w	#1,d3
	bge.s	.w1
	add.w	#240,d3
	bra.s	.w2
.w1:	cmp.w	#240,d3
	ble.s	.w2
	sub.w	#240,d3
.w2:	move.w	d7,d0			; d := round(sqrt(sz2 - x1*x1)) (sqrt of an integer: no ties)
	muls	d0,d0
	move.w	gp_sz2,d1
	sub.w	d0,d1
	move.w	d1,d0
	bsr	gp_rsqrt
	move.w	d0,d4			; d
	move.w	d4,d6			; y1 := -d to d
	neg.w	d6
.sy:	move.w	d7,d0			; d2 := x1*x1 + y1*y1
	muls	d0,d0
	move.w	d6,d1
	muls	d1,d1
	add.w	d1,d0
	move.w	d0,-(sp)
	move.w	d3,d0
	move.w	d6,d1
	add.w	gp_y,d1
	bsr	lf_addr
	move.l	a0,a3
	move.w	(sp)+,d0
	cmp.w	gp_sz21,d0
	ble.s	.i2
	moveq	#2,d0			; inc(landform, 1 + random(2))
	bsr	mt_random
	addq.b	#1,d0
	add.b	d0,(a3)
	bra.s	.sn
.i2:	cmp.w	gp_sz22,d0
	ble.s	.i3
	moveq	#2,d0			; c - 1 - random(2)
	bsr	mt_random
	move.w	gp_c,d1
	subq.w	#1,d1
	sub.w	d0,d1
	move.b	d1,(a3)
	bra.s	.sn
.i3:	moveq	#2,d0			; c + random(2)
	bsr	mt_random
	add.w	gp_c,d0
	move.b	d0,(a3)
.sn:	addq.w	#1,d6
	cmp.w	d4,d6
	ble.s	.sy
	addq.w	#1,d7
	cmp.w	d5,d7
	ble	.sx
	addq.w	#1,u2_ii
	move.w	u2_ii,d0
	cmp.w	gp_cnt,d0
	ble	.s
	move.w	gp_cnt,u2_ii		; (the loop variable's last value)
	bsr	mt_randomize
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; round(sqrt(d0.w)) for d0 >= 0 (an integer's root is never k + 0.5)
gp_rsqrt:
	move.w	d0,d1
	moveq	#0,d0			; k := floor(sqrt(n))
.k:	move.w	d0,d2
	addq.w	#1,d2
	mulu	d2,d2
	cmp.w	d1,d2
	bhi.s	.f
	addq.w	#1,d0
	bra.s	.k
.f:	move.w	d0,d2			; n - k*k > k: round up
	mulu	d2,d2
	sub.w	d2,d1
	cmp.w	d0,d1
	ble.s	.x
	addq.w	#1,d0
.x:	rts

; makeswirl(x d0, y d1, sz d2): swaps of landform values around a band border, less random(3)
gp_makeswirl:
	movem.l	d3-d5/a3,-(sp)
	move.w	d0,d3
	move.w	d1,d4
	move.w	d2,d5
	lea	.lo,a3			; y <= 60: the swaps from .lo, else .hi
	cmp.w	#60,d4
	ble.s	.s
	lea	.hi,a3
.s:	subq.w	#2,d5			; sz 2, 3, 4: lists of (dx1,dy1,dx2,dy2) swaps
	cmp.w	#2,d5
	bhi.s	.x
	add.w	d5,d5
	move.w	0(a3,d5.w),d0
	lea	0(a3,d0.w),a3
.l:	move.b	(a3)+,d0		; c := landform^[x+dx1, y+dy1]
	cmp.b	#$7f,d0
	beq.s	.x
	ext.w	d0
	add.w	d3,d0
	move.b	(a3)+,d1
	ext.w	d1
	add.w	d4,d1
	bsr	lf_addr
	move.l	a0,a1			; a1 = first
	move.b	(a3)+,d0
	ext.w	d0
	add.w	d3,d0
	move.b	(a3)+,d1
	ext.w	d1
	add.w	d4,d1
	move.l	a1,-(sp)
	bsr	lf_addr
	move.l	(sp)+,a1		; a0 = second
	move.b	(a1),gp_sw		; c
	move.l	a0,-(sp)
	move.l	a1,-(sp)
	moveq	#3,d0			; first := second - random(3)
	bsr	mt_random
	move.l	(sp)+,a1
	move.l	(sp),a0
	move.b	(a0),d1
	sub.b	d0,d1
	move.b	d1,(a1)
	moveq	#3,d0			; second := c - random(3)
	bsr	mt_random
	move.l	(sp)+,a0
	move.b	gp_sw,d1
	sub.b	d0,d1
	move.b	d1,(a0)
	bra.s	.l
.x:	movem.l	(sp)+,d3-d5/a3
	rts
.lo:	dc.w	.l2-.lo,.l3-.lo,.l4-.lo
.l2:	dc.b	0,-1,1,0,$7f
.l3:	dc.b	0,-1,2,0,1,-1,1,0,$7f
.l4:	dc.b	0,-1,3,0,1,-1,2,0,2,-2,1,1,1,-2,2,1,$7f
	even
.hi:	dc.w	.h2-.hi,.h3-.hi,.h4-.hi
.h2:	dc.b	1,-1,0,0,$7f
.h3:	dc.b	0,0,2,-1,1,-1,1,0,$7f
.h4:	dc.b	0,0,3,-1,1,0,2,-1,2,-2,1,1,1,-2,2,1,$7f
	even

; ---------------------------------------------------------------- makegasplanet
; the gas giant's sphere into planet^ (rows 6..maxspherei: ii := 119*(i-6) div (2*r2-2) + 1;
; alt as makesphere's with 6 at the lit edge; colour := 1 if alt > (v mod 16), else v - alt),
; then planet^ to the screen; c := c+1 (wrapped)
makegasplanet:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	u2_sph,a1
	lea	SPH_ROWS(a1),a1
	moveq	#6,d6			; i
.row:	cmp.w	GS_MAXSPHEREI(a6),d6
	bgt	.done
	move.w	d6,d0			; ii
	subq.w	#6,d0
	mulu	#119,d0
	move.w	GS_R2(a6),d1
	add.w	d1,d1
	subq.w	#2,d1
	divu	d1,d0
	move.l	GS_LANDFORM(a6),a4	; a4 = landform^[1, ii] - ... (column j2: + (j2-1)*120)
	add.w	d0,a4			; (ii = d0+1: offset ii-1 = d0)
	move.w	d6,d0			; ofsy := i + offset; the planet^ row (1-based)
	add.w	GS_OFFSET(a6),d0
	subq.w	#1,d0
	mulu	#120,d0
	move.l	GS_PLANET(a6),a2
	add.l	d0,a2
	move.w	(a1)+,d0		; ofsx := pm[i] + offset
	add.w	GS_OFFSET(a6),d0
	add.w	d0,a2
	move.w	(a1)+,d7		; n
	move.l	a1,a3			; the indices
	move.w	d7,d0
	addq.w	#1,d0
	and.w	#$fffe,d0
	add.w	d0,a1			; (next row)
	moveq	#1,d5			; j (the first kept pixel is j = 1)
	bra.s	.pn
.px:	moveq	#0,d3			; index
	move.b	(a3)+,d3
	move.w	GS_ECL(a6),d4		; alt
	cmp.w	#170,d4
	ble.s	.e2
	cmp.w	#1,d5
	bne.s	.e1
	moveq	#6,d0
	bra.s	.ea
.e1:	move.w	d3,d0			; (index-ecl+186) div 2
	sub.w	d4,d0
	add.w	#186,d0
	bra.s	.ed
.e2:	cmp.w	GS_XW(a6),d3
	bne.s	.e3
	moveq	#6,d0
	bra.s	.ea
.e3:	move.w	d4,d0			; (ecl-index) div 2
	sub.w	d3,d0
.ed:	ext.l	d0
	divs	#2,d0
.ea:	tst.w	d0
	bpl.s	.ap
	moveq	#0,d0
.ap:	move.w	d3,d1			; j2 := index + c, wrapped
	add.w	GS_C(a6),d1
	cmp.w	#240,d1
	ble.s	.j2
	sub.w	#240,d1
.j2:	subq.w	#1,d1
	mulu	#LAND_W,d1
	move.b	0(a4,d1.l),d1		; v
	move.b	d1,d2
	and.w	#15,d2
	cmp.w	d2,d0
	ble.s	.cv
	moveq	#1,d1
	bra.s	.put
.cv:	sub.b	d0,d1
.put:	move.b	d1,(a2)+
	addq.w	#1,d5
.pn:	dbf	d7,.px
	addq.w	#1,d6
	bra	.row
.done:	bsr	mousehide		; planet^ to screen[13.., 28..]
	move.l	GS_PLANET(a6),a1
	moveq	#28,d0
	moveq	#13,d1
	bsr	ms_addr
	moveq	#120-1,d1
.r:	moveq	#120/4-1,d0
	move.l	a0,a2
.c:	move.b	(a1)+,(a2)+
	move.b	(a1)+,(a2)+
	move.b	(a1)+,(a2)+
	move.b	(a1)+,(a2)+
	dbf	d0,.c
	lea	MS_W(a0),a0
	dbf	d1,.r
	moveq	#28,d0
	moveq	#13,d1
	move.w	#147,d2
	move.w	#132,d3
	bsr	ms_dirty
	bsr	mouseshow
	addq.w	#1,GS_C(a6)		; inc(c), wrapped
	cmp.w	#240,GS_C(a6)
	ble.s	.x
	sub.w	#240,GS_C(a6)
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; ---------------------------------------------------------------- asteroid fields
makeastoroidfield:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	u2_curplan
	moveq	#0,d0
	move.w	PLANET_SEED(a3),d0
	bsr	mt_setseed
	moveq	#50,d0			; for b := 0 to 100+random(50)
	bsr	mt_random
	add.w	#100,d0
	move.w	d0,gp_cnt
	clr.w	gp_b
.b:	moveq	#6,d0			; a := random(6); readweaicon(a+80)
	bsr	mt_random
	move.w	d0,d7			; a
	add.w	#80,d0
	bsr	readweaicon
	move.w	#300,d0			; x := random(300)+10
	bsr	mt_random
	add.w	#10,d0
	move.w	d0,gp_x
	moveq	#70,d0			; y := random(70)+25
	bsr	mt_random
	add.w	#25,d0
	move.w	d0,gp_y
	moveq	#5,d0			; if random(5) = 0 then y := y-20+random(40)
	bsr	mt_random
	tst.w	d0
	bne.s	.t3
	moveq	#40,d0
	bsr	mt_random
	add.w	d0,gp_y
	sub.w	#20,gp_y
.t3:	move.w	#190,d0			; t3 := (random(190)+10)/200
	bsr	mt_random
	add.w	#10,d0
	FSSE
	bsr	fp_ldw
	FLDI	200
	bsr	fp_div
	lea	gp_t3,a0
	bsr	fp_std
	moveq	#0,d5			; round(k*t3) for k = 0..19, once
	lea	gp_rt,a3
.rt:	lea	gp_t3,a0
	bsr	fp_ldd
	move.w	d5,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,(a3)+
	addq.w	#1,d5
	cmp.w	#20,d5
	bne.s	.rt
	moveq	#0,d5			; i
.i:	moveq	#0,d6			; j
.j:	move.l	GS_TEMPICON(a6),a0	; if tempicon^[i, a+j] <> 0 (a row of 20 bytes; a+j may run on)
	move.w	d5,d0
	mulu	#20,d0
	add.w	d7,d0
	add.w	d6,d0
	tst.b	0(a0,d0.w)
	beq.s	.jn
	move.w	d5,d0			; backgr^[y+round(i*t3), x+round(j*t3)] := tempicon^[i, j]
	mulu	#20,d0
	add.w	d6,d0
	move.b	0(a0,d0.w),d2
	lea	gp_rt,a1
	move.w	d5,d0
	add.w	d0,d0
	move.w	0(a1,d0.w),d1
	add.w	gp_y,d1
	move.w	d6,d0
	add.w	d0,d0
	move.w	0(a1,d0.w),d0
	add.w	gp_x,d0
	mulu	#320,d1
	ext.l	d0
	add.l	d0,d1
	move.l	GS_BACKGR(a6),a0
	move.b	d2,0(a0,d1.l)
.jn:	addq.w	#1,d6
	cmp.w	#20,d6
	bne.s	.j
	addq.w	#1,d5
	cmp.w	#20,d5
	bne.s	.i
	addq.w	#1,gp_b
	move.w	gp_b,d0
	cmp.w	gp_cnt,d0
	ble	.b
	bsr	gp_toland40		; landform^[j, i] := backgr^[i, j+40]
	bsr	mt_randomize
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; landform^[j, i] := backgr^[i + d0 (rows), j + 40] for i 1..120, j 1..240 (gp_toland40: rows +0,
; gp_toland50: +10)
gp_toland40:
	moveq	#0,d0
	bra.s	gp_toland
gp_toland50:
	moveq	#10,d0
gp_toland:
	movem.l	d3,-(sp)
	move.l	GS_BACKGR(a6),a0
	addq.w	#1,d0			; row i + d0 for i = 1
	mulu	#320,d0
	add.l	d0,a0
	lea	41(a0),a0		; column j + 40 for j = 1
	move.l	GS_LANDFORM(a6),a1
	moveq	#120-1,d1		; i
.i:	move.l	a1,a2
	move.w	#240-1,d2
	move.l	a0,-(sp)
.j:	move.b	(a0)+,(a2)		; landform^[j, i]: stride 120 per j
	lea	LAND_W(a2),a2
	dbf	d2,.j
	move.l	(sp)+,a0
	lea	320(a0),a0
	addq.l	#1,a1
	dbf	d1,.i
	movem.l	(sp)+,d3
	rts

; drawastoroid: main.cpr's transparent pixels (255) take backgr^ at (backgrx, backgry) offsets
drawastoroid:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	mem_mark
	move.l	d0,-(sp)
	move.l	#64000,d0		; new(temp); loadscreen(main, temp)
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,a5
	bsr	orc_dump
	lea	u2_main,a0
	move.l	a5,a1
	bsr	loadchk
	move.l	ms_buf,a3
	moveq	#0,d7			; j
.j:	move.w	d7,d5			; x := j + backgrx, wrapped
	add.w	GS_BACKGRX(a6),d5
	cmp.w	#319,d5
	ble.s	.x1
	sub.w	#320,d5
.x1:	moveq	#0,d6			; i
.i:	move.w	d6,d0
	mulu	#320,d0
	add.w	d7,d0
	cmp.b	#255,0(a5,d0.l)
	bne.s	.in
	move.w	d6,d1			; y := i + backgry, wrapped
	add.w	GS_BACKGRY(a6),d1
	cmp.w	#199,d1
	ble.s	.y1
	sub.w	#200,d1
.y1:	mulu	#320,d1
	add.w	d5,d1
	move.l	GS_BACKGR(a6),a0
	move.b	0(a0,d1.l),0(a3,d0.l)
.in:	addq.w	#1,d6
	cmp.w	#200,d6
	bne.s	.i
	addq.w	#1,d7
	cmp.w	#320,d7
	bne.s	.j
	bsr	ms_dirty_all
	move.l	(sp)+,d0
	bsr	mem_release
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; ---------------------------------------------------------------- gas clouds
makecloud:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	u2_curplan
	moveq	#0,d0
	move.w	PLANET_SEED(a3),d0
	bsr	mt_setseed
	moveq	#25,d0			; count := random(25) + 50
	bsr	mt_random
	add.w	#50,d0
	move.w	d0,gp_cnt
	moveq	#1,d7			; i
.cl:	cmp.w	#1,d7
	bne.s	.o
	moveq	#50,d0			; the first: sz := 50+random(50) at (160, 70)
	bsr	mt_random
	add.w	#50,d0
	move.w	d0,d5
	move.w	#160,gp_x
	move.w	#70,gp_y
	bra.s	.c
.o:	moveq	#50,d0			; sz := 25+random(50)
	bsr	mt_random
	add.w	#25,d0
	move.w	d0,d5
	move.w	#260,d0			; x := sz + 30 + random(260-sz-sz)  (random(int64))
	sub.w	d5,d0
	sub.w	d5,d0
	ext.l	d0
	bsr	mt_random64l
	add.w	d5,d0
	add.w	#30,d0
	move.w	d0,gp_x
	moveq	#120,d0			; y := sz shr 1 + 10 + random(120-sz)  (random(int64))
	sub.w	d5,d0
	ext.l	d0
	bsr	mt_random64l
	move.w	d5,d1
	lsr.w	#1,d1
	add.w	d1,d0
	add.w	#10,d0
	move.w	d0,gp_y
.c:	moveq	#48,d0			; c := (random(48)+32) and $f0
	bsr	mt_random
	add.w	#32,d0
	and.w	#$f0,d0
	move.w	d0,gp_c
	move.w	d5,d6			; xx := -sz to sz
	neg.w	d6
.xx:	move.w	d6,d0			; bl := 7*(sz-abs(xx)) div sz
	bpl.s	.ab
	neg.w	d0
.ab:	neg.w	d0
	add.w	d5,d0
	mulu	#7,d0
	divu	d5,d0
	move.w	d0,gp_bl
	FX87				; y1 := round(cos(xx*1.57/sz)*(sz shr 1))
	move.w	d6,d0
	bsr	fp_ldw
	FLDX	gx_1_57
	bsr	fp_mul
	move.w	d5,d0
	bsr	fp_ldw
	bsr	fp_div
	bsr	fp_cos
	move.w	d5,d0
	lsr.w	#1,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	FSSE
	move.w	d0,d4			; y1
	move.w	d4,d3			; yy := -y1 to y1
	neg.w	d3
.yy:	cmp.w	d4,d3
	bgt	.xn
	moveq	#0,d2			; b
	tst.w	d4
	ble.s	.b0
	move.w	d3,d0			; b := (bl*(y1-abs(yy))^2) div y1 div y1
	bpl.s	.ay
	neg.w	d0
.ay:	neg.w	d0
	add.w	d4,d0
	muls	d0,d0
	muls	gp_bl,d0
	divs	d4,d0
	ext.l	d0
	divs	d4,d0
	move.w	d0,d2
.b0:	move.w	gp_y,d1			; backgr^[y+yy, x+xx]
	add.w	d3,d1
	mulu	#320,d1
	move.w	gp_x,d0
	add.w	d6,d0
	ext.l	d0
	add.l	d0,d1
	move.l	GS_BACKGR(a6),a3
	add.l	d1,a3
	move.b	(a3),d0
	cmp.b	#143,d0			; > 143, or random(7) < b: c or b
	bhi.s	.set
	move.w	d2,-(sp)
	moveq	#7,d0
	bsr	mt_random
	move.w	(sp)+,d2
	cmp.w	d2,d0
	blt.s	.set
	move.b	(a3),d0			; else if (v and $f) < b: (v and $f0) or b
	moveq	#15,d1
	and.b	d0,d1
	cmp.b	d2,d1
	bge.s	.yn
	and.b	#$f0,d0
	or.b	d2,d0
	move.b	d0,(a3)
	bra.s	.yn
.set:	move.w	gp_c,d0
	or.b	d2,d0
	move.b	d0,(a3)
.yn:	addq.w	#1,d3
	bra	.yy
.xn:	addq.w	#1,d6
	cmp.w	d5,d6
	ble	.xx
	addq.w	#1,d7
	cmp.w	gp_cnt,d7
	ble	.cl
	bsr	gp_toland50		; landform^[j, i] := backgr^[i+10, j+40]
	bsr	mt_randomize
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; the background's extras after cloud.cpr was loaded into backgr again: an asteroid field
; (state 6, mode 2) or a gas cloud (state 0, mode 1) of the planet in orbit
gp_extras:
	move.l	a3,-(sp)
	bsr	u2_curplan
	move.b	PLANET_STATE(a3),d0
	move.b	PLANET_MODE(a3),d1
	move.l	(sp)+,a3
	cmp.b	#6,d0
	bne.s	.c
	cmp.b	#2,d1
	beq	makeastoroidfield
	rts
.c:	tst.b	d0
	bne.s	.x
	cmp.b	#1,d1
	beq	makecloud
.x:	rts

; readyplanet's approach countdown: for i := 1 to 200: str(200-i:3) at (90, 170); delay(tslice)
; unless a key waits
gp_countdown:
	move.l	d3,-(sp)
	moveq	#1,d3
.l:	move.w	d3,u2_index
	bsr	u2_count
	bsr	kbd_keypressed
	bne.s	.n
	move.w	GS_TSLICE(a6),d0
	bsr	delay
.n:	addq.w	#1,d3
	cmp.w	#200,d3
	ble.s	.l
	move.w	#201,u2_i		; (i: the loop's)
	move.l	(sp)+,d3
	rts

	section	bss
gp_t3:		ds.l	2
gp_cols:	ds.w	3
gp_cnt:		ds.w	1
gp_b:		ds.w	1
gp_c:		ds.w	1
gp_bl:		ds.w	1
gp_x:		ds.w	1
gp_y:		ds.w	1
gp_sz2:		ds.w	1
gp_sz21:	ds.w	1
gp_sz22:	ds.w	1
gp_rt:		ds.w	20
gp_sw:		ds.b	1
	even
	section	text
