; info.s - info.pas for MAIN.PRG: the sector map (the cube's Sector Map, after event 11): the
; stars of one of the eight sectors, rotating in 3-D (keys and buttons turn them), the X-Y side
; view and the X-Z top view with the target's cross-hairs (xor lines), the history view (stars
; and planets explored, scans done), picking a target by mouse or by typing its coordinates,
; and J / the engage button, which leaves and engages (usecode.pas engage) towards it.
; Mode SECTOR (tools/mkmain.py).
;
; sectorinfo                                            trashes: d0-d2/a0-a2

NS_SIZE		equ	NEARBY_SIZEOF		; nearsec^: 38 x (index.w, x, y, z doubles)
OLDSYS_SIZEOF	equ	12			; crewgen.pas oldsystype (sysset.dta)

	section	text
sectorinfo:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	if_readydata
	bsr	if_mainloop
	move.l	GS_OLDT1(a6),GS_T1(a6)	; t1 := oldt1
	move.l	GS_OLDT1+4(a6),GS_T1+4(a6)
	bsr	if_removedata
	tst.b	if_engaging
	beq.s	.x
	movem.w	if_tarx,d0-d2		; engage(tarx, tary, tarz)
	bsr	engage
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; a0 = nearsec^[d0] (1-based)
if_ns:
	subq.w	#1,d0
	mulu	#NS_SIZE,d0
	lea	if_nearsec,a0
	add.l	d0,a0
	rts
; a0 = systems[d0]
if_sys:
	subq.w	#1,d0
	mulu	#SYSTEM_SIZEOF,d0
	lea	GS_SYSTEMS(a6),a0
	add.l	d0,a0
	rts

; double at a0 := (d0.w - d1.w) / 10  (SSE)
if_rel10:
	move.l	a0,-(sp)
	sub.w	d1,d0
	FSSE
	bsr	fp_ldw
	FLDI	10
	bsr	fp_div
	move.l	(sp)+,a0
	bra	fp_std

; d0.w := round(d0.w / d1.w) (SSE: integer / integer is a double)
if_rdiv:
	move.w	d1,-(sp)
	FSSE
	bsr	fp_ldw
	move.w	(sp)+,d0
	bsr	fp_ldw
	bsr	fp_div
	bsr	fp_rnd
	rts

readysector_:
if_readysector:
	movem.l	d3-d7/a3,-(sp)
	move.w	if_sector,d0		; the sector's centre
	move.w	#625,d1
	cmp.w	#4,d0
	ble.s	.z
	subq.w	#4,d0
	move.w	#1875,d1
.z:	move.w	d1,if_cenz
	move.w	#625,d1
	cmp.w	#2,d0
	ble.s	.y
	subq.w	#2,d0
	move.w	#1875,d1
.y:	move.w	d1,if_ceny
	move.w	#625,d1
	cmp.w	#1,d0
	ble.s	.x
	move.w	#1875,d1
.x:	move.w	d1,if_cenx
	lea	if_nearsec,a0		; for j := 1 to 37: nearsec^[j].index := 0
	moveq	#37-1,d0
.cl:	clr.w	NEARBY_INDEX(a0)
	lea	NS_SIZE(a0),a0
	dbf	d0,.cl
	clr.w	if_index
	moveq	#1,d7			; i
.sys:	move.w	d7,d0
	bsr	if_sys
	move.l	a0,a3
	moveq	#1,d6			; j: the system's sector
	cmp.w	#1250,SYSTEM_X(a3)
	ble.s	.s1
	moveq	#2,d6
.s1:	cmp.w	#1250,SYSTEM_Y(a3)
	ble.s	.s2
	addq.w	#2,d6
.s2:	cmp.w	#1250,SYSTEM_Z(a3)
	ble.s	.s3
	addq.w	#4,d6
.s3:	lea	SYSTEM_NAME(a3),a0	; 'OBAN       ' -> 'OBAN        ' (legacy padding)
	lea	.oban,a1
	moveq	#12-1,d0
.ob:	cmpm.b	(a0)+,(a1)+
	dbne	d0,.ob
	bne.s	.nob
	move.b	#12,SYSTEM_NAME(a3)
	move.b	#' ',SYSTEM_NAME+12(a3)
.nob:	cmp.b	#12,SYSTEM_NAME(a3)	; a corrupted name: 'BROKEN nnnn ' and the original's place
	beq.s	.ok
	bsr	if_fixbroken
.ok:	cmp.w	if_sector,d6
	bne.s	.n
	btst	#0,SYSTEM_NOTES(a3)
	beq.s	.n
	addq.w	#1,if_index
	move.w	if_index,d0
	cmp.w	#38,d0
	beq	fatal			; ('Invalid NearSec value.')
	bsr	if_ns
	move.l	a0,a2
	move.w	d7,NEARBY_INDEX(a2)
	move.l	a2,-(sp)
	lea	NEARBY_X(a2),a0
	move.w	SYSTEM_X(a3),d0
	move.w	if_cenx,d1
	bsr	if_rel10
	move.l	(sp),a2
	lea	NEARBY_Y(a2),a0
	move.w	SYSTEM_Y(a3),d0
	move.w	if_ceny,d1
	bsr	if_rel10
	move.l	(sp)+,a2
	lea	NEARBY_Z(a2),a0
	move.w	SYSTEM_Z(a3),d0
	move.w	if_cenz,d1
	bsr	if_rel10
.n:	addq.w	#1,d7
	cmp.w	#250,d7
	ble	.sys
	move.w	d7,if_i
	move.w	d6,if_j
	lea	if_tarxr,a0		; tarxr/yr/zr := (tar - cen)/10
	move.w	if_tarx,d0
	move.w	if_cenx,d1
	bsr	if_rel10
	lea	if_taryr,a0
	move.w	if_tary,d0
	move.w	if_ceny,d1
	bsr	if_rel10
	lea	if_tarzr,a0
	move.w	if_tarz,d0
	move.w	if_cenz,d1
	bsr	if_rel10
	movem.l	(sp)+,d3-d7/a3
	rts
.oban:	dc.b	11,"OBAN       "
	even

; system d7 (a3) with a corrupted name: name 'BROKEN nnnn ', visits/date 0, mode 1, notes 1,
; x/y/z from sysset.dta, numplanets counted (info.pas readysector + fixupcoord)
if_fixbroken:
	movem.l	d3-d4,-(sp)
	lea	SYSTEM_NAME(a3),a0
	move.b	#12,(a0)+
	lea	.br,a1
	moveq	#7-1,d0
.c:	move.b	(a1)+,(a0)+
	dbf	d0,.c
	move.w	d7,d0
	moveq	#4-1,d2
	lea	4(a0),a1
.d:	ext.l	d0
	divu	#10,d0
	swap	d0
	add.b	#'0',d0
	move.b	d0,-(a1)
	clr.w	d0
	swap	d0
	dbf	d2,.d
	move.b	#' ',4(a0)
	clr.w	SYSTEM_VISITS(a3)
	clr.w	SYSTEM_DATEY(a3)
	clr.b	SYSTEM_DATEM(a3)
	move.b	#1,SYSTEM_MODE(a3)
	move.b	#1,SYSTEM_NOTES(a3)
	move.l	#250*OLDSYS_SIZEOF,d0	; sysset.dta: x, y, z (its first three words)
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,a1
	move.l	a0,-(sp)
	lea	if_fn_sysset,a0
	move.l	#250*OLDSYS_SIZEOF,d0
	bsr	fil_load
	bcs	fatal
	move.l	(sp)+,a0
	move.w	d7,d0
	subq.w	#1,d0
	mulu	#OLDSYS_SIZEOF,d0
	add.l	d0,a0
	move.w	(a0)+,SYSTEM_X(a3)
	move.w	(a0)+,SYSTEM_Y(a3)
	move.w	(a0)+,SYSTEM_Z(a3)
	move.l	#250*OLDSYS_SIZEOF,d0	; (released: the pool is a stack)
	neg.l	d0
	add.l	mem_top,d0
	and.w	#$fff0,d0
	move.l	d0,mem_top
	move.l	GS_TEMPPLAN(a6),a0	; numplanets := the planets of the system
	moveq	#0,d1
	move.w	#1000-1,d2
.p:	cmp.b	PLANET_SYSTEM(a0),d7
	bne.s	.pn
	addq.w	#1,d1
.pn:	lea	PLANET_SIZEOF(a0),a0
	dbf	d2,.p
	move.b	d1,SYSTEM_NUMPLANETS(a3)
	movem.l	(sp)+,d3-d4
	rts
.br:	dc.b	"BROKEN "
	even

; ---------------------------------------------------------------- the star map
; the rotation of (a0 = first, a1 = second double) by mode d0 (-1: a := c*a - s*b, b := s*a + c*b;
; 1: a := c*a + s*b, b := -s*a + c*b), x87 (the constants are not doubles)
if_rot:
	movem.l	d3/a3-a4,-(sp)
	move.w	d0,d3
	move.l	a0,a3
	move.l	a1,a4
	lea	GS_X1(a6),a1		; x1 := a; y1 := b
	move.l	(a3),(a1)+
	move.l	4(a3),(a1)
	lea	GS_Y1(a6),a1
	move.l	(a4),(a1)+
	move.l	4(a4),(a1)
	FX87
	FLDX	gx_0_987700794		; a := c*x1 -/+ s*y1
	lea	GS_X1(a6),a0
	bsr	fp_ldd
	bsr	fp_mul
	FLDX	gx_0_156355812
	lea	GS_Y1(a6),a0
	bsr	fp_ldd
	bsr	fp_mul
	tst.w	d3
	bpl.s	.p1
	bsr	fp_sub
	bra.s	.s1
.p1:	bsr	fp_add
.s1:	move.l	a3,a0
	bsr	fp_std
	tst.w	d3			; b := s*x1 + c*y1  /  -s*x1 + c*y1
	bpl.s	.p2
	FLDX	gx_0_156355812
	lea	GS_X1(a6),a0
	bsr	fp_ldd
	bsr	fp_mul
	FLDX	gx_0_987700794
	lea	GS_Y1(a6),a0
	bsr	fp_ldd
	bsr	fp_mul
	bsr	fp_add
	bra.s	.s2
.p2:	FLDX	gx_0_156355812
	bsr	fp_neg
	lea	GS_X1(a6),a0
	bsr	fp_ldd
	bsr	fp_mul
	FLDX	gx_0_987700794
	lea	GS_Y1(a6),a0
	bsr	fp_ldd
	bsr	fp_mul
	bsr	fp_add
.s2:	move.l	a4,a0
	bsr	fp_std
	FSSE
	movem.l	(sp)+,d3/a3-a4
	rts

; x1 := 85 + a0.x*250/(500 - a0.z); y1 := 70 + a0.y*250/(500 - a0.z); d0 := round(x1), d1 :=
; round(y1)  (a0 = the x double; y, z follow at +8, +16)
if_project:
	movem.l	d3/a3,-(sp)
	move.l	a0,a3
	FSSE
	FLDI	85
	move.l	a3,a0
	bsr	fp_ldd
	FLDI	250
	bsr	fp_mul
	FLDI	500
	lea	16(a3),a0
	bsr	fp_ldd
	bsr	fp_sub
	bsr	fp_div
	bsr	fp_add
	lea	GS_X1(a6),a0
	bsr	fp_std
	FLDI	70
	lea	8(a3),a0
	bsr	fp_ldd
	FLDI	250
	bsr	fp_mul
	FLDI	500
	lea	16(a3),a0
	bsr	fp_ldd
	bsr	fp_sub
	bsr	fp_div
	bsr	fp_add
	lea	GS_Y1(a6),a0
	bsr	fp_std
	lea	GS_X1(a6),a0
	bsr	fp_ldd
	bsr	fp_rnd
	move.w	d0,d3
	lea	GS_Y1(a6),a0
	bsr	fp_ldd
	bsr	fp_rnd
	move.w	d0,d1
	move.w	d3,d0
	movem.l	(sp)+,d3/a3
	rts

if_displaysector:
	movem.l	d3-d7/a3,-(sp)
	cmp.b	#59,GS_SHIP+SHIP_DAMAGES+DMG_CPU-1(a6)
	bhi	.static
	moveq	#40,d0			; damages[CPU] > 20+random(40)
	bsr	mt_random
	add.w	#20,d0
	moveq	#0,d1
	move.b	GS_SHIP+SHIP_DAMAGES+DMG_CPU-1(a6),d1
	cmp.w	d0,d1
	bgt	.static
	move.l	GS_STARMAPSCREEN(a6),a0	; fillchar(starmapscreen^, 12402, 0): only displaysector writes
	tst.b	if_smok			; it while the sector map is up, so after the first fill it holds
	beq.s	.full			; zeros and last frame's dots - clearing those is the same fill
	lea	if_dots,a1
	move.w	if_ndots,d0
	bra.s	.zf
.zd:	move.l	(a1)+,d1
	clr.b	0(a0,d1.l)
.zf:	dbf	d0,.zd
	bra.s	.zx
.full:	move.w	#TEMPLATETYPE2_SIZEOF/2-1,d0
.z:	clr.w	(a0)+
	dbf	d0,.z
	st	if_smok
.zx:	clr.w	if_ndots
	lea	if_nmin,a0		; this frame's dots per copied row: first and last column
	moveq	#106-1,d0
.zn:	move.w	#$7fff,(a0)+
	move.w	#-1,212-2(a0)
	dbf	d0,.zn
	moveq	#1,d7			; j
.st:	move.w	d7,d0
	bsr	if_ns
	move.l	a0,a3
	tst.w	NEARBY_INDEX(a3)
	beq	.sn
	move.w	if_rotatemode,d0
	beq.s	.nr
	lea	NEARBY_X(a3),a0		; (x, z)
	lea	NEARBY_Z(a3),a1
	bsr	if_rot
.nr:	lea	NEARBY_X(a3),a0
	bsr	if_project
	move.w	d0,GS_X(a6)
	move.w	d1,GS_Y(a6)
	move.w	NEARBY_INDEX(a3),d0
	bsr	if_sys
	tst.w	if_infoindex
	bne.s	.vis
	move.b	SYSTEM_MODE(a0),d0
	moveq	#127,d1
	cmp.b	#1,d0
	beq.s	.col
	moveq	#95,d1
	cmp.b	#2,d0
	beq.s	.col
	moveq	#31,d1
	cmp.b	#3,d0
	beq.s	.col
	move.w	if_i,d1			; (other modes: i as it was)
	bra.s	.col
.vis:	moveq	#95,d1
	tst.w	SYSTEM_VISITS(a0)
	ble.s	.col
	moveq	#31,d1
.col:	move.w	d1,if_i
	move.w	d1,d2			; starmapscreen^[y, x] := i (and the dot is noted)
	move.w	GS_Y(a6),d1
	sub.w	#18,d1
	move.w	GS_X(a6),d0
	sub.w	#27,d0
	cmp.w	#106,d1			; a copied row and column: the row's span
	bhs.s	.nsp
	cmp.w	#116,d0
	bhs.s	.nsp
	lea	if_nmin,a0
	add.w	d1,a0
	add.w	d1,a0
	cmp.w	(a0),d0
	bge.s	.n1
	move.w	d0,(a0)
.n1:	cmp.w	212(a0),d0
	ble.s	.nsp
	move.w	d0,212(a0)
.nsp:	muls	#117,d1
	ext.l	d0
	add.l	d0,d1
	move.l	GS_STARMAPSCREEN(a6),a0
	move.b	d2,0(a0,d1.l)
	lea	if_dots,a0
	move.w	if_ndots,d0
	addq.w	#1,if_ndots
	lsl.w	#2,d0
	move.l	d1,0(a0,d0.w)
.sn:	addq.w	#1,d7
	cmp.w	#37,d7
	ble	.st
	bsr	mousehide		; rows 18-123 to screen rows 43-148, x 27-142: the map is zeros
	bsr	if_smcopy		; and this frame's dots, so only the columns that are not zero
	move.w	#123,if_i		; on screen or in the map need copying (if_smcopy)
	move.w	if_rotatemode,d0	; the target
	beq.s	.tn
	lea	if_tarxr,a0
	lea	if_tarzr,a1
	bsr	if_rot
.tn:	lea	if_tarxr,a0
	bsr	if_project
	move.w	d0,GS_X(a6)
	move.w	d1,GS_Y(a6)
	add.w	#25,d1			; circle(x, y+25, 4) in 44
	moveq	#4,d2
	moveq	#44,d4
	bsr	ms_circle
	bsr	mouseshow
	bra.s	.x
.static:
	bsr	mousehide		; the noise of a damaged computer
	move.w	GS_GLOWINDEX(a6),d6
	and.w	#1,d6
	moveq	#0,d7			; i
.si:	moveq	#27,d0
	move.w	d7,d1
	add.w	d1,d1
	add.w	#43,d1
	add.w	d6,d1
	bsr	ms_addr
	move.l	a0,a3
	moveq	#27,d5
.sj:	moveq	#16,d0
	bsr	mt_random
	move.b	d0,(a3)+
	addq.w	#1,d5
	cmp.w	#142,d5
	ble.s	.sj
	moveq	#27,d0			; the other row in 0 (115 bytes)
	move.w	d7,d1
	add.w	d1,d1
	add.w	#44,d1
	sub.w	d6,d1
	bsr	ms_addr
	moveq	#115-1,d0
.sz:	clr.b	(a0)+
	dbf	d0,.sz
	addq.w	#1,d7
	cmp.w	#52,d7
	ble.s	.si
	moveq	#27,d0
	moveq	#43,d1
	move.w	#142,d2
	move.w	#149,d3
	bsr	ms_dirty
	move.w	d6,if_index
	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d7/a3
	rts

;  starmapscreen rows 18-123 -> screen rows 43-148, x 27-142 (scrto_move of 116 bytes a row),
; exactly, but per row only between the first and the last column that is not zero on the
; screen (found by scanning: dots, the target circle, the cursor) or in the map (if_nmin/max);
; only that span is marked dirty. Rows with nothing in either are left alone.
if_smcopy:
	movem.l	d3-d7/a3-a5,-(sp)
	moveq	#27,d0
	moveq	#43,d1
	bsr	ms_addr
	move.l	a0,a3			; the screen row (x 27: odd)
	move.l	GS_STARMAPSCREEN(a6),a4	; the map row
	lea	if_nmin,a5
	moveq	#0,d7			; row
.r:	move.w	(a5),d4			; span: the map's dots
	move.w	212(a5),d5
	move.l	a3,a0			; and what is not zero on the screen: column 0 (x 27), then
	tst.b	(a0)+			; columns 1-112 by longs, then 113-115
	beq.s	.b0
	moveq	#0,d4
	tst.w	d5
	bpl.s	.b0
	moveq	#0,d5
.b0:	moveq	#28-1,d1
.o:	move.l	(a0)+,d0
	bne.s	.ol
.on:	dbf	d1,.o
	bra.s	.ot
.ol:	move.w	#28-1+1,d2		; the long's first column: 1 + 4*(27-d1)
	sub.w	d1,d2
	lsl.w	#2,d2
	subq.w	#3,d2
	rol.l	#8,d0			; its bytes, first to last
	tst.b	d0
	bne.s	.ok
	addq.w	#1,d2
	rol.l	#8,d0
	tst.b	d0
	bne.s	.ok
	addq.w	#1,d2
	rol.l	#8,d0
	tst.b	d0
	bne.s	.ok
	addq.w	#1,d2
	rol.l	#8,d0
.ok:	cmp.w	d4,d2			; (d2: the first nonzero byte of this long)
	bge.s	.k1
	move.w	d2,d4
.k1:	move.l	-4(a0),d0		; and its last nonzero byte
	move.w	#28-1+1,d2
	sub.w	d1,d2
	lsl.w	#2,d2			; the long's last column
	tst.b	d0
	bne.s	.lk
	subq.w	#1,d2
	lsr.l	#8,d0
	tst.b	d0
	bne.s	.lk
	subq.w	#1,d2
	lsr.l	#8,d0
	tst.b	d0
	bne.s	.lk
	subq.w	#1,d2
.lk:	cmp.w	d5,d2
	ble.s	.on
	move.w	d2,d5
	bra.s	.on
.ot:	moveq	#113,d2			; columns 113-115
.t3:	tst.b	(a0)+
	beq.s	.t4
	cmp.w	d4,d2
	bge.s	.t5
	move.w	d2,d4
.t5:	cmp.w	d5,d2
	ble.s	.t4
	move.w	d2,d5
.t4:	addq.w	#1,d2
	cmp.w	#116,d2
	bne.s	.t3
.sp:	tst.w	d5			; nothing in the row
	bmi.s	.nx
	move.w	d5,d6
	sub.w	d4,d6			; bytes - 1
	lea	0(a4,d4.w),a1
	lea	0(a3,d4.w),a0
.c:	move.b	(a1)+,(a0)+
	dbf	d6,.c
	move.w	d4,d0
	add.w	#27,d0
	move.w	d7,d1
	add.w	#43,d1
	move.w	d5,d2
	add.w	#27,d2
	move.w	d1,d3
	bsr	ms_dirty
.nx:	lea	MS_W(a3),a3
	lea	117(a4),a4
	addq.l	#2,a5
	addq.w	#1,d7
	cmp.w	#106,d7
	bne	.r
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; ---------------------------------------------------------------- the side views
; d0 := round((d0 - d1)/d2) + d3  (the views' coordinates)
if_coord:
	movem.w	d2-d3,-(sp)
	sub.w	d1,d0
	move.w	d2,d1
	bsr	if_rdiv
	movem.w	(sp)+,d2-d3
	add.w	d3,d0
	rts

; the target's cross-hairs (xor, colour 47) when infoindex = 0
if_crosshairs:
	movem.l	d3-d5,-(sp)
	tst.w	if_infoindex
	bne	.x
	st	ms_xor
	move.w	if_tarx,d0		; x := round((tarx-cenx)/10)+230
	move.w	if_cenx,d1
	moveq	#10,d2
	move.w	#230,d3
	bsr	if_coord
	move.w	d0,d5
	move.w	if_tary,d0		; y := round((tary-ceny)/20)+55
	move.w	if_ceny,d1
	moveq	#20,d2
	moveq	#55,d3
	bsr	if_coord
	move.w	d0,GS_Y(a6)
	move.w	d5,GS_X(a6)
	move.w	d5,d0			; line(x, 20, x, 88)
	moveq	#20,d1
	move.w	d5,d2
	moveq	#88,d3
	moveq	#47,d4
	bsr	ms_line
	move.w	d5,d0			; line(x, 91, x, 158)
	moveq	#91,d1
	move.w	d5,d2
	move.w	#158,d3
	moveq	#47,d4
	bsr	ms_line
	move.w	#160,d0			; line(160, y, 300, y)
	move.w	GS_Y(a6),d1
	move.w	#300,d2
	move.w	d1,d3
	moveq	#47,d4
	bsr	ms_line
	move.w	if_tarz,d0		; y := round((tarz-cenz)/20)+125
	move.w	if_cenz,d1
	moveq	#20,d2
	moveq	#125,d3
	bsr	if_coord
	move.w	d0,GS_Y(a6)
	move.w	#160,d0
	move.w	GS_Y(a6),d1
	move.w	#300,d2
	move.w	d1,d3
	moveq	#47,d4
	bsr	ms_line
	sf	ms_xor
.x:	movem.l	(sp)+,d3-d5
	rts

if_displaytargets:
	bsr	mousehide
	move.w	if_tarx,d0
	move.w	#172,d1
	bsr	.num
	move.w	if_tary,d0
	move.w	#180,d1
	bsr	.num
	move.w	if_tarz,d0
	move.w	#188,d1
	bsr	.num
	bsr	if_crosshairs
	bra	mouseshow
.num:	move.w	d1,-(sp)		; str(v div 10:3) at (42, y)
	ext.l	d0
	divs	#10,d0
	ext.l	d0
	moveq	#3,d1
	lea	if_s,a0
	bsr	int_str
	move.w	(sp)+,d1
	moveq	#42,d0
	lea	if_s,a0
	bra	printxy

if_displaysideview:
	movem.l	d3-d7/a3,-(sp)
	bsr	mousehide
	BAR	160,20,300,88,5
	BAR	160,91,300,158,5
	moveq	#1,d7			; the grid in 3
.g:	move.w	d7,d5
	mulu	#20,d5
	add.w	#160,d5
	move.w	d5,d0
	moveq	#20,d1
	move.w	d5,d2
	moveq	#88,d3
	moveq	#3,d4
	bsr	ms_line
	move.w	d5,d0
	moveq	#91,d1
	move.w	d5,d2
	move.w	#158,d3
	moveq	#3,d4
	bsr	ms_line
	addq.w	#1,d7
	cmp.w	#6,d7
	ble.s	.g
	moveq	#1,d7
.h:	move.w	d7,d5
	mulu	#10,d5
	move.w	#160,d0
	move.w	d5,d1
	add.w	#19,d1
	move.w	#300,d2
	move.w	d1,d3
	moveq	#3,d4
	bsr	ms_line
	move.w	#160,d0
	move.w	d5,d1
	add.w	#90,d1
	move.w	#300,d2
	move.w	d1,d3
	moveq	#3,d4
	bsr	ms_line
	addq.w	#1,d7
	cmp.w	#6,d7
	ble.s	.h
	moveq	#1,d7			; the stars
.s:	move.w	d7,d0
	bsr	if_ns
	move.w	NEARBY_INDEX(a0),d0
	beq	.sn
	bsr	if_sys
	move.l	a0,a3
	move.b	SYSTEM_MODE(a3),d0	; c1 by mode
	moveq	#127,d6
	cmp.b	#1,d0
	beq.s	.c
	moveq	#95,d6
	cmp.b	#2,d0
	beq.s	.c
	moveq	#31,d6
	cmp.b	#3,d0
	beq.s	.c
	move.w	if_c1,d6
.c:	move.w	d6,if_c1
	move.w	SYSTEM_X(a3),d0
	move.w	if_cenx,d1
	moveq	#10,d2
	move.w	#230,d3
	bsr	if_coord
	move.w	d0,d5
	move.w	SYSTEM_Y(a3),d0
	move.w	if_ceny,d1
	moveq	#20,d2
	moveq	#55,d3
	bsr	if_coord
	move.w	d0,d1
	move.w	d5,d0
	move.w	d6,d2
	bsr	ms_pset
	move.w	SYSTEM_Z(a3),d0
	move.w	if_cenz,d1
	moveq	#20,d2
	moveq	#125,d3
	bsr	if_coord
	move.w	d0,d1
	move.w	d1,GS_Y(a6)
	move.w	d5,GS_X(a6)
	move.w	d5,d0
	move.w	d6,d2
	bsr	ms_pset
.sn:	addq.w	#1,d7
	cmp.w	#37,d7
	ble	.s
	TCOL	31
	BKCOL	0
	bsr	if_displaytargets
	bsr	mouseshow
	movem.l	(sp)+,d3-d7/a3
	rts

if_readysideview:
	GRAYB	159,19,301,89
	GRAYB	159,90,301,159
	PXY	170,12,"X-Y  Side View"
	PXY	170,160,"X-Z  Top View"
	bra	if_displaysideview

if_readyhistoryview:
	movem.l	d3-d7/a3,-(sp)
	BKCOL	5
	TCOL	211
	bsr	mousehide
	GRAYB	159,34,301,149
	BAR	159,12,301,33,0
	BAR	159,150,301,166,0
	BAR	179,74,279,85,0
	BAR	179,100,279,111,0
	BAR	179,127,279,138,0
	move.w	if_sector,d0		; printxy(207-round(length*2.5), 37, name+' SECTOR')
	subq.w	#1,d0
	and.w	#7,d0
	mulu	#8,d0
	lea	.names,a1
	add.w	d0,a1
	lea	if_s,a0
	moveq	#0,d0
	move.b	(a1),d0
.cp:	move.b	(a1)+,(a0)+
	dbf	d0,.cp
	lea	if_s,a0
	lea	.sector,a1
	bsr	pstr_cat
	move.w	if_sector,d0
	subq.w	#1,d0
	and.w	#7,d0
	lsl.w	#3,d0
	lea	.names,a0
	moveq	#0,d1
	move.b	0(a0,d0.w),d1
	mulu	#5,d1			; length*2.5, banker's
	lsr.w	#1,d1
	bcc.s	.e
	btst	#0,d1
	beq.s	.e
	addq.w	#1,d1
.e:	move.w	#207,d0
	sub.w	d1,d0
	moveq	#37,d1
	lea	if_s,a0
	bsr	printxy
	PXY	185,49,"Stars"
	PXY	180,55,"Planets"
	PXY	194,64,"Stars Explored"
	RGRAYB	179,74,280,85
	PXY	189,90,"Planets Explored"
	RGRAYB	179,100,280,111
	PXY	191,117,"Scans Completed"
	RGRAYB	179,127,280,138
	moveq	#0,d3			; stars
	moveq	#0,d4			; planets
	moveq	#0,d5			; exploredplanets
	moveq	#0,d6			; exploredstars
	moveq	#0,d7			; scansdone
	moveq	#1,d2			; i
.st:	move.w	d2,d0
	bsr	if_ns
	move.w	NEARBY_INDEX(a0),d0
	ble.s	.sn
	move.w	d2,-(sp)
	move.w	d0,-(sp)
	bsr	findfirstplanet
	move.w	(sp)+,d1		; (the system)
	move.w	d0,-(sp)
	subq.w	#1,d0
	mulu	#PLANET_SIZEOF,d0
	move.l	GS_TEMPPLAN(a6),a3
	add.l	d0,a3
	move.w	(sp)+,d2		; j
.pl:	cmp.b	PLANET_SYSTEM(a3),d1
	bne.s	.pe
	cmp.w	#1001,d2
	bge.s	.pe
	tst.w	PLANET_VISITS(a3)
	beq.s	.nv
	tst.b	PLANET_ORBIT(a3)
	beq.s	.vs
	addq.w	#1,d5
	bra.s	.nv
.vs:	addq.w	#1,d6
.nv:	btst	#0,PLANET_NOTES(a3)
	beq.s	.ns
	addq.w	#1,d7
.ns:	addq.w	#1,d2
	addq.w	#1,d4
	lea	PLANET_SIZEOF(a3),a3
	bra.s	.pl
.pe:	move.w	d2,if_j
	move.w	(sp)+,d2
	addq.w	#1,d3
.sn:	addq.w	#1,d2
	cmp.w	#37,d2
	ble.s	.st
	move.w	d3,d0			; str(stars:3) at (250, 49), planets at (250, 55)
	moveq	#49,d1
	bsr	.n3
	move.w	d4,d0
	moveq	#55,d1
	bsr	.n3
	move.w	d6,d0			; the three bars: round(n/total*100) or 100
	move.w	d3,d1
	moveq	#75,d2
	bsr	.bar
	move.w	d5,d0
	move.w	d4,d1
	moveq	#101,d2
	bsr	.bar
	move.w	d7,d0
	move.w	d4,d1
	move.w	#128,d2
	bsr	.bar
	TCOL	31
	BKCOL	0
	bsr	mouseshow
	bsr	if_displaytargets
	movem.l	(sp)+,d3-d7/a3
	rts
.n3:	move.w	d1,-(sp)
	ext.l	d0
	moveq	#3,d1
	lea	if_s,a0
	bsr	int_str
	move.w	(sp)+,d1
	move.w	#250,d0
	lea	if_s,a0
	bra	printxy
.bar:	movem.l	d3-d5,-(sp)		; d0/d1 as a percentage (100 if d1 = 0): 10 rows from d2
	move.w	d2,d5			; first row
	moveq	#100,d3			; a
	tst.w	d1
	ble.s	.b1
	FSSE
	move.w	d1,-(sp)
	bsr	fp_ldw
	move.w	(sp)+,d0
	bsr	fp_ldw
	bsr	fp_div
	FLDI	100
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,d3
.b1:	moveq	#0,d4			; i: row first+i in colour 83+i (i <= 2) or 89-i
.bl:	move.w	#180,d0
	move.w	d5,d1
	add.w	d4,d1
	bsr	ms_addr
	moveq	#83,d2
	add.w	d4,d2
	cmp.w	#2,d4
	ble.s	.b2
	moveq	#89,d2
	sub.w	d4,d2
.b2:	move.w	d3,d0
	bra.s	.bf1
.bf:	move.b	d2,(a0)+
.bf1:	dbf	d0,.bf
	addq.w	#1,d4
	cmp.w	#9,d4
	ble.s	.bl
	tst.w	d3
	ble.s	.bx
	move.w	#180,d0			; (marked)
	move.w	d5,d1
	move.w	d0,d2
	add.w	d3,d2
	subq.w	#1,d2
	move.w	d5,d3
	add.w	#9,d3
	bsr	ms_dirty
.bx:	movem.l	(sp)+,d3-d5
	rts
.names:	dc.b	5,"ALPHA  ",4,"BETA   ",5,"GAMMA  ",5,"DELTA  "
	dc.b	7,"EPSILON",4,"ZETA   ",3,"ETA    ",5,"THETA  "
.sector:	dc.b	7," SECTOR"
	even

; the sector cursor: plainfadearea(66+j*19, 167+i*10, 82+j*19, 175+i*10, d0)
; (i := 2 for sectors > 4, else 1; j := (sector-1) mod 4, Pascal's: -1 for sector 0)
if_cursor:
	movem.l	d3-d4,-(sp)
	move.w	d0,d4
	moveq	#1,d1
	move.w	if_sector,d0
	cmp.w	#4,d0
	ble.s	.i
	moveq	#2,d1
.i:	subq.w	#1,d0
	ext.l	d0
	divs	#4,d0
	swap	d0			; (remainder, sign of the dividend)
	muls	#19,d0
	mulu	#10,d1
	move.w	d1,d3
	add.w	#175,d3
	add.w	#167,d1
	move.w	d0,d2
	add.w	#82,d2
	add.w	#66,d0
	bsr	plainfadearea
	movem.l	(sp)+,d3-d4
	rts
if_undocursor:
	moveq	#-5,d0
	bra.s	if_cursor
if_drawcursor:
	moveq	#5,d0
	bra.s	if_cursor

; the views after a sector change
if_views:
	tst.w	if_infoindex
	beq	if_displaysideview
	bra	if_readyhistoryview

; rotateit(mode d0)
if_rotateit:
	movem.l	d3/d7/a3,-(sp)
	move.w	d0,d3
	clr.w	if_rotatemode
	moveq	#1,d7
.l:	move.w	d7,d0
	bsr	if_ns
	move.l	a0,a3
	tst.w	NEARBY_INDEX(a3)
	ble.s	.n
	bsr.s	.one
.n:	addq.w	#1,d7
	cmp.w	#37,d7
	ble.s	.l
	lea	if_tarxr-NEARBY_X,a3	; (the target as a nearsec record)
	bsr.s	.one
	movem.l	(sp)+,d3/d7/a3
	bra	if_displaysector
.one:	lea	NEARBY_Y(a3),a0		; modes 0/1: (y, z); 2/3: (x, z); 0, 2: -1; 1, 3: 1
	cmp.w	#2,d3
	blt.s	.yz
	lea	NEARBY_X(a3),a0
.yz:	lea	NEARBY_Z(a3),a1
	moveq	#-1,d0
	btst	#0,d3
	beq.s	.r
	moveq	#1,d0
.r:	bra	if_rot

; the system's name (trimmed from position d1 down) centred at y 24: printxy(74-round(i*2.5), 24)
if_showname:
	movem.l	d3,-(sp)
	move.w	d1,d3
	lea	if_s,a1
	moveq	#13-1,d1
.c:	move.b	(a0)+,(a1)+
	dbf	d1,.c
	lea	if_s,a0
.t:	cmp.b	#' ',0(a0,d3.w)
	bne.s	.te
	subq.w	#1,d3
	bra.s	.t
.te:	move.b	d3,(a0)
	move.w	d3,d1
	mulu	#5,d1
	lsr.w	#1,d1
	bcc.s	.e
	btst	#0,d1
	beq.s	.e
	addq.w	#1,d1
.e:	moveq	#74,d0
	sub.w	d1,d0
	moveq	#24,d1
	bsr	printxy
	movem.l	(sp)+,d3
	rts

if_clearname:
	BAR	40,24,129,30,0
	rts

; the nearest system to the mouse in the side view (axis 2: y, offset GS) or top view (z)
if_findtarget:
	movem.l	d3-d7/a3,-(sp)
	cmp.w	#1,if_infoindex
	beq	.x
	bsr	mousehide
	bsr	if_crosshairs		; (xor: off)
	bsr	kbd_mouse_xy
	move.w	d0,d3			; mouse x
	move.w	d1,d4			; mouse y
	cmp.w	#89,d4
	bge.s	.top
	move.w	d3,d0			; tarx := (x-230)*10+cenx; tary := (y-55)*20+ceny
	sub.w	#230,d0
	muls	#10,d0
	add.w	if_cenx,d0
	move.w	d0,if_tarx
	move.w	d4,d0
	sub.w	#55,d0
	muls	#20,d0
	add.w	if_ceny,d0
	move.w	d0,if_tary
	moveq	#SYSTEM_Y,d5
	lea	if_tary,a3
	bra.s	.near
.top:	cmp.w	#90,d4
	ble	.name
	move.w	d3,d0
	sub.w	#230,d0
	muls	#10,d0
	add.w	if_cenx,d0
	move.w	d0,if_tarx
	move.w	d4,d0
	sub.w	#125,d0
	muls	#20,d0
	add.w	if_cenz,d0
	move.w	d0,if_tarz
	moveq	#SYSTEM_Z,d5
	lea	if_tarz,a3
.near:	move.w	#2500,d6		; minx
	move.w	#2500,d7		; miny
	move.w	#1,if_index
	moveq	#1,d3			; j
.l:	move.w	d3,d0
	bsr	if_ns
	move.w	NEARBY_INDEX(a0),d0
	ble.s	.ln
	bsr	if_sys
	move.w	if_tarx,d0		; abs(tarx-x) + abs(tar2-y) < abs(minx) + abs(miny)
	sub.w	SYSTEM_X(a0),d0
	move.w	d0,d1
	bpl.s	.a1
	neg.w	d1
.a1:	move.w	(a3),d2
	sub.w	0(a0,d5.w),d2
	move.w	d2,d4
	bpl.s	.a2
	neg.w	d4
.a2:	add.w	d4,d1
	move.w	d6,d4
	bpl.s	.a3
	neg.w	d4
.a3:	move.w	d7,-(sp)
	tst.w	d7
	bpl.s	.a4
	neg.w	(sp)
.a4:	add.w	(sp)+,d4
	cmp.w	d4,d1
	bge.s	.ln
	move.w	d0,d6
	move.w	d2,d7
	move.w	d3,if_index
.ln:	addq.w	#1,d3
	cmp.w	#37,d3
	ble.s	.l
	move.w	d3,if_j
	bsr	if_settarget
.name:	bsr	if_clearname
	move.w	if_index,d0
	bsr	if_ns
	move.w	NEARBY_INDEX(a0),d0
	bsr	if_sys
	moveq	#11,d1
	bsr	if_showname
	bsr	if_displaytargets
	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d7/a3
	rts

; tarx/y/z := systems[nearsec^[index].index]; tarxr/yr/zr := nearsec^[index].x/y/z
if_settarget:
	move.w	if_index,d0
	bsr	if_ns
	move.l	a0,a1
	move.w	NEARBY_INDEX(a1),d0
	bsr	if_sys
	move.w	SYSTEM_X(a0),if_tarx
	move.w	SYSTEM_Y(a0),if_tary
	move.w	SYSTEM_Z(a0),if_tarz
	lea	NEARBY_X(a1),a1
	lea	if_tarxr,a0
	moveq	#6-1,d0
.c:	move.l	(a1)+,(a0)+
	dbf	d0,.c
	rts

; findtarget2: the star under the mouse in the 3-D map
if_findtarget2:
	movem.l	d3-d7/a3,-(sp)
	tst.w	if_infoindex
	bne.s	.n
	bsr	mousehide
	bsr	if_crosshairs
	bsr	mouseshow
.n:	bsr	kbd_mouse_xy
	move.w	d0,d6
	move.w	d1,d7
	moveq	#1,d3
.l:	move.w	d3,d0
	bsr	if_ns
	move.l	a0,a3
	tst.w	NEARBY_INDEX(a3)
	beq.s	.ln
	lea	NEARBY_X(a3),a0
	bsr	if_project
	add.w	#25,d1
	move.w	d0,GS_X(a6)
	move.w	d1,GS_Y(a6)
	sub.w	d6,d0
	bpl.s	.a
	neg.w	d0
.a:	cmp.w	#4,d0
	bge.s	.ln
	sub.w	d7,d1
	bpl.s	.b
	neg.w	d1
.b:	cmp.w	#4,d1
	bge.s	.ln
	move.w	d3,if_index
	bsr	if_settarget
.ln:	addq.w	#1,d3
	cmp.w	#37,d3
	ble.s	.l
	move.w	d3,if_j
	bsr	if_clearname
	move.w	if_index,d0
	bsr	if_ns
	move.w	NEARBY_INDEX(a0),d0
	bsr	if_sys
	moveq	#11,d1
	bsr	if_showname
	bsr	if_displaytargets
	movem.l	(sp)+,d3-d7/a3
	rts

; editx / edity / editz: the coordinate d0 (0, 1, 2) typed at row 172 / 180 / 188
if_edit:
	movem.l	d3-d6,-(sp)
	move.w	d0,d6
	moveq	#1,d3			; curx
	TCOL	31
	lea	if_temp,a0		; temp := '   '
	move.l	#$03202020,(a0)
	bsr	mousehide
.l:	moveq	#1,d4			; the three characters, the cursor one on 88
.p:	move.w	#88,GS_BKCOLOR(a6)
	cmp.w	d3,d4
	beq.s	.b
	clr.w	GS_BKCOLOR(a6)
.b:	lea	if_s,a0
	move.b	#1,(a0)
	lea	if_temp,a1
	move.b	0(a1,d4.w),1(a0)
	move.w	d4,d0
	mulu	#5,d0
	add.w	#37,d0
	move.w	d6,d1
	lsl.w	#3,d1
	add.w	#172,d1
	bsr	printxy
	addq.w	#1,d4
	cmp.w	#3,d4
	ble.s	.p
	moveq	#'@',d5			; ans
	bsr	kbd_keypressed
	beq.s	.w
	bsr	kbd_readkey
	move.b	d0,d5
	bra.s	.k
.w:	move.w	GS_TSLICE(a6),d0	; delay(tslice*2)
	add.w	d0,d0
	bsr	delay
.k:	lea	if_temp,a0
	cmp.b	#' ',d5
	beq.s	.ch
	cmp.b	#'0',d5
	blo.s	.bs
	cmp.b	#'9',d5
	bhi.s	.bs
.ch:	move.b	d5,0(a0,d3.w)
	cmp.w	#3,d3
	bge.s	.e
	addq.w	#1,d3
	bra.s	.e
.bs:	cmp.b	#8,d5
	bne.s	.e
	move.b	#' ',0(a0,d3.w)
	cmp.w	#1,d3
	ble.s	.e
	subq.w	#1,d3
.e:	cmp.b	#13,d5
	beq.s	.cr
	cmp.b	#27,d5
	bne	.l
	clr.w	GS_BKCOLOR(a6)
.no:	bsr	if_displaytargets
	bsr	if_displaytargets
	bra	.cl
.cr:	clr.w	GS_BKCOLOR(a6)
	lea	if_temp,a0		; trim; val(temp)
.tr:	moveq	#0,d0
	move.b	(a0),d0
	beq.s	.v
	cmp.b	#' ',0(a0,d0.w)
	bne.s	.v
	subq.b	#1,(a0)
	bra.s	.tr
.v:	bsr	if_val
	bcs.s	.cl			; (error: nothing happens, not even the redraw)
	mulu	#10,d0
	cmp.w	#2500,d0
	ble.s	.c25
	move.w	#2500,d0
.c25:	lea	if_tarx,a0
	add.w	d6,d6
	move.w	d0,0(a0,d6.w)
	bsr	if_undocursor
	moveq	#1,d0			; sector from the target
	cmp.w	#1250,if_tarx
	ble.s	.s1
	moveq	#2,d0
.s1:	cmp.w	#1250,if_tary
	ble.s	.s2
	addq.w	#2,d0
.s2:	cmp.w	#1250,if_tarz
	ble.s	.s3
	addq.w	#4,d0
.s3:	move.w	d0,if_sector
	bsr	if_drawcursor
	bsr	if_readysector
	bsr	if_views
.cl:	bsr	if_clearname
	bsr	mouseshow
	movem.l	(sp)+,d3-d6
	rts

; FPC val(temp, value, error) for the edit fields: leading spaces allowed, then digits to the
; end (empty: an error)  in: a0 = Pascal string  out: d0.w value, carry set on error
if_val:
	moveq	#0,d1
	move.b	(a0)+,d1
	moveq	#0,d0
	subq.w	#1,d1
	bmi.s	.err
.sp:	cmp.b	#' ',(a0)
	bne.s	.d
	addq.l	#1,a0
	dbf	d1,.sp
	bra.s	.err			; (only spaces)
.d:	moveq	#0,d2
	move.b	(a0)+,d2
	sub.b	#'0',d2
	cmp.b	#9,d2
	bhi.s	.err
	mulu	#10,d0
	add.w	d2,d0
	dbf	d1,.d
	and.b	#$fe,ccr
	rts
.err:	or.b	#1,ccr
	rts

; newsec(n d0)
if_newsec:
	move.w	d0,-(sp)
	bsr	if_undocursor
	move.w	(sp)+,if_sector
	bsr	if_drawcursor
	bsr	if_readysector
	bsr	if_cleartar
	bsr	if_views
	bsr	mousehide
	bsr	if_clearname
	bra	mouseshow
if_cleartar:				; tarxr := tarzr := tarzr := 0; tar := cen
	lea	if_tarxr,a0
	moveq	#6-1,d0
.c:	clr.l	(a0)+
	dbf	d0,.c
	move.w	if_cenx,if_tarx
	move.w	if_ceny,if_tary
	move.w	if_cenz,if_tarz
	rts

if_findhome:
	movem.l	d3,-(sp)
	bsr	if_undocursor
	moveq	#1,d0
	cmp.w	#1250,GS_SHIP+SHIP_POSX(a6)
	ble.s	.s1
	moveq	#2,d0
.s1:	cmp.w	#1250,GS_SHIP+SHIP_POSY(a6)
	ble.s	.s2
	addq.w	#2,d0
.s2:	cmp.w	#1250,GS_SHIP+SHIP_POSZ(a6)
	ble.s	.s3
	addq.w	#4,d0
.s3:	move.w	d0,if_sector
	move.w	GS_SHIP+SHIP_POSX(a6),if_tarx
	move.w	GS_SHIP+SHIP_POSY(a6),if_tary
	move.w	GS_SHIP+SHIP_POSZ(a6),if_tarz
	bsr	if_readysector
	bsr	if_views
	bsr	if_displaytargets
	bsr	if_displaytargets
	bsr	if_drawcursor
	bsr	mousehide
	clr.w	if_index		; the system of the planet in orbit among nearsec^
	move.w	GS_CURPLAN(a6),d0
	ble.s	.ni
	bsr	cm_plan
	moveq	#0,d3
	move.b	PLANET_SYSTEM(a0),d3
	moveq	#1,d1
.f:	move.w	d1,d0
	bsr	if_ns
	cmp.w	NEARBY_INDEX(a0),d3
	beq.s	.ff
	addq.w	#1,d1
	cmp.w	#38,d1
	ble.s	.f
	bra.s	.ni
.ff:	move.w	d1,if_index
.ni:	bsr	if_clearname
	lea	.unk,a0
	tst.w	GS_CURPLAN(a6)
	ble.s	.u
	move.w	if_index,d0
	beq.s	.u
	bsr	if_ns
	move.w	NEARBY_INDEX(a0),d0
	bsr	if_sys
.u:	moveq	#12,d1
	bsr	if_showname
	bsr	mouseshow
	movem.l	(sp)+,d3
	rts
.unk:	dc.b	12,"UNKNOWN     "
	even

; the side/history view buttons
if_toside:
	tst.w	if_infoindex
	beq.s	.x
	clr.w	if_infoindex
	FADE	145,177,197,185,5
	FADE	145,187,197,195,-5
	bra	if_readysideview
.x:	rts
if_tohist:
	cmp.w	#1,if_infoindex
	beq.s	.x
	move.w	#1,if_infoindex
	FADE	145,177,197,185,-5
	FADE	145,187,197,195,5
	bra	if_readyhistoryview
.x:	rts
if_engage:
	st	if_engaging
	st	GS_DONE(a6)
	st	GS_TARGETREADY(a6)
	rts

if_processkey:
	bsr	kbd_readkey
	bsr	cm_upcase
	tst.b	d0
	bne.s	.a
	bsr	kbd_readkey
	moveq	#0,d1
	cmp.b	#72,d0
	beq.s	.rot
	moveq	#1,d1
	cmp.b	#80,d0
	beq.s	.rot
	moveq	#2,d1
	cmp.b	#75,d0
	beq.s	.rot
	moveq	#3,d1
	cmp.b	#77,d0
	beq.s	.rot
	cmp.b	#71,d0
	bne.s	.e
	move.w	#-1,if_rotatemode
	bra	.x
.e:	cmp.b	#79,d0
	bne	.x
	move.w	#1,if_rotatemode
	bra	.x
.rot:	move.w	d1,d0
	bsr	if_rotateit
	bra	.x
.a:	cmp.b	#'1',d0
	blo.s	.nn
	cmp.b	#'8',d0
	bhi.s	.nn
	sub.b	#'0',d0
	ext.w	d0
	cmp.w	if_sector,d0
	beq	.x
	move.w	d0,-(sp)		; (as newsec, without clearing the name)
	bsr	if_undocursor
	move.w	(sp)+,if_sector
	bsr	if_drawcursor
	bsr	if_readysector
	bsr	if_cleartar
	bsr	if_views
	bra	.x
.nn:	moveq	#0,d1
	cmp.b	#'X',d0
	beq.s	.ed
	moveq	#1,d1
	cmp.b	#'Y',d0
	beq.s	.ed
	moveq	#2,d1
	cmp.b	#'Z',d0
	beq.s	.ed
	cmp.b	#'J',d0
	bne.s	.pl
	bsr	if_engage
	bra.s	.x
.ed:	move.w	d1,d0
	bsr	if_edit
	bra.s	.x
.pl:	cmp.b	#'+',d0
	bne.s	.mi
	bsr	if_toside
	bra.s	.x
.mi:	cmp.b	#'-',d0
	bne.s	.es
	bsr	if_tohist
	bra.s	.x
.es:	cmp.b	#27,d0
	bne.s	.sp
	st	GS_DONE(a6)
	bra.s	.x
.sp:	cmp.b	#'`',d0			; bossmode
	bne.s	.spb
	bsr	bossmode
	bra.s	.x
.spb:	cmp.b	#' ',d0			; (#10 heap stats: not on the ST)
	bne.s	.x
	clr.w	if_rotatemode
.x:	clr.w	GS_IDLETIME(a6)
	rts

if_findmouse:
	movem.l	d3-d4,-(sp)
	bsr	kbd_mouse_status
	tst.b	d0
	beq	.x
	bsr	kbd_mouse_xy
	move.w	d0,d3
	move.w	d1,d4
	lea	.tab,a0
.r:	move.w	(a0)+,d0
	bmi	.i
	move.w	(a0)+,d1
	move.w	(a0)+,d2
	cmp.w	d0,d3
	blt.s	.r
	cmp.w	d1,d3
	bgt.s	.r
	lea	.tab,a0
	add.w	d2,a0
.y:	move.w	(a0)+,d0
	bmi.s	.i
	move.w	(a0)+,d1
	move.w	(a0)+,d2
	cmp.w	d0,d4
	blt.s	.y
	cmp.w	d1,d4
	bgt.s	.y
	lea	.tab,a0
	add.w	d2,a0
	jsr	(a0)
.i:	clr.w	GS_IDLETIME(a6)
.x:	movem.l	(sp)+,d3-d4
	rts
.tab:	dc.w	43,62,.y1-.tab,66,82,.y2-.tab,85,101,.y3-.tab,104,120,.y4-.tab,123,139,.y5-.tab
	dc.w	27,42,.y6-.tab,63,65,.y6-.tab,83,84,.y6-.tab,102,103,.y6-.tab,121,122,.y6-.tab
	dc.w	140,142,.y6-.tab,145,159,.y7-.tab,160,197,.y8-.tab,205,221,.y9-.tab,223,233,.y10-.tab
	dc.w	235,244,.y11-.tab,246,256,.y12-.tab,258,274,.y13-.tab,282,292,.y14-.tab
	dc.w	300,310,.y15-.tab,2,10,.y16-.tab,-1
.y1:	dc.w	172,178,.ex-.tab,180,186,.ey-.tab,188,194,.ez-.tab,43,147,.t2-.tab,-1
.y2:	dc.w	177,185,.n1-.tab,187,195,.n5-.tab,43,147,.t2-.tab,-1
.y3:	dc.w	177,185,.n2-.tab,187,195,.n6-.tab,43,147,.t2-.tab,-1
.y4:	dc.w	177,185,.n3-.tab,187,195,.n7-.tab,43,147,.t2-.tab,-1
.y5:	dc.w	177,185,.n4-.tab,187,195,.n8-.tab,43,147,.t2-.tab,-1
.y6:	dc.w	43,147,.t2-.tab,-1
.y7:	dc.w	177,185,.side-.tab,187,195,.hist-.tab,-1
.y8:	dc.w	20,160,.t1-.tab,177,185,.side-.tab,187,195,.hist-.tab,-1
.y9:	dc.w	21,158,.t1-.tab,177,185,.rm-.tab,-1
.y10:	dc.w	21,158,.t1-.tab,177,185,.r2-.tab,-1
.y11:	dc.w	21,158,.t1-.tab,170,176,.r0-.tab,178,186,.r00-.tab,188,194,.r1-.tab,-1
.y12:	dc.w	21,158,.t1-.tab,177,185,.r3-.tab,-1
.y13:	dc.w	21,158,.t1-.tab,177,185,.rp-.tab,-1
.y14:	dc.w	178,195,.eng-.tab,21,158,.t1-.tab,-1
.y15:	dc.w	21,158,.t1-.tab,177,195,.done-.tab,-1
.y16:	dc.w	163,197,.home-.tab,-1
.ex:	moveq	#0,d0
	bra	if_edit
.ey:	moveq	#1,d0
	bra	if_edit
.ez:	moveq	#2,d0
	bra	if_edit
.t1:	bra	if_findtarget
.t2:	bra	if_findtarget2
.n1:	moveq	#1,d0
	bra	if_newsec
.n2:	moveq	#2,d0
	bra	if_newsec
.n3:	moveq	#3,d0
	bra	if_newsec
.n4:	moveq	#4,d0
	bra	if_newsec
.n5:	moveq	#5,d0
	bra	if_newsec
.n6:	moveq	#6,d0
	bra	if_newsec
.n7:	moveq	#7,d0
	bra	if_newsec
.n8:	moveq	#8,d0
	bra	if_newsec
.side:	bra	if_toside
.hist:	bra	if_tohist
.rm:	move.w	#-1,if_rotatemode
	rts
.rp:	move.w	#1,if_rotatemode
	rts
.r00:	clr.w	if_rotatemode
	rts
.r0:	moveq	#0,d0
	bra	if_rotateit
.r1:	moveq	#1,d0
	bra	if_rotateit
.r2:	moveq	#2,d0
	bra	if_rotateit
.r3:	moveq	#3,d0
	bra	if_rotateit
.eng:	bra	if_engage
.done:	st	GS_DONE(a6)
	rts
.home:	bra	if_findhome

if_mainloop:
.l:	moveq	#8,d0			; fadestep(FADESTEP_STEP)
	bsr	fadestep
	bsr	if_displaysector
	cmp.w	#8,GS_BATINDEX(a6)
	bge.s	.b0
	addq.w	#1,GS_BATINDEX(a6)
	bra.s	.d
.b0:	clr.w	GS_BATINDEX(a6)
	bsr	addtime2
.d:	move.w	GS_TSLICE(a6),d0	; delay(tslice*FADE_TSLICE_MUL_INFO)
	lsl.w	#3,d0
	bsr	delayp			; (paced: the frame's work counts)
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	if_processkey
.nk:	bsr	if_findmouse
	cmp.w	#MAXIDLE,GS_IDLETIME(a6)
	bne.s	.ni
	bsr	screensaver
.ni:	tst.b	GS_DONE(a6)
	beq.s	.l
	rts

if_readydata:
	bsr	mousehide
	moveq	#0,d0			; compressfile(current)
	bsr	ms_snap
	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	lea	if_fn_mod,a0
	bsr	playmod
	bsr	orc_dump		; loadscreen(sector)
	lea	if_mode,a0
	bsr	ms_load
	bcs	fatal
	sf	if_smok			; (starmapscreen holds what other screens left: fill it once)
	lea	if_nearsec,a0		; new(nearsec) (38: findhome looks at one more)
	move.w	#38*NS_SIZE/2-1,d0
.z:	clr.w	(a0)+
	dbf	d0,.z
	sf	GS_DONE(a6)
	BKCOL	0
	TCOL	31
	move.l	GS_T1(a6),GS_OLDT1(a6)
	move.l	GS_T1+4(a6),GS_OLDT1+4(a6)
	bsr	if_drawcursor
	clr.w	if_infoindex
	move.w	#1,if_rotatemode
	sf	if_engaging
	bsr	if_findhome
	FADE	145,177,197,185,5
	bsr	if_readysideview
	bra	mouseshow

if_removedata:
	bsr	mousehide
	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	moveq	#3,d0			; mouse.setmousecursor(random(3))
	bsr	mt_random
	bsr	setmousecursor
	bsr	orc_dump		; loadscreen(current)
	moveq	#0,d0
	bsr	ms_unsnap
	BKCOL	3
	moveq	#0,d0
	bsr	displaytextbox
	move.w	#25,GS_TEXTINDEX(a6)
	cmp.w	#4,GS_VIEWMODE2(a6)
	bne.s	.f
	bsr	readylongscan
.f:	bsr	fadein
	bsr	mouseshow
	st	GS_ANYCHANGE(a6)
	move.l	GS_OLDT1(a6),GS_T1(a6)
	move.l	GS_OLDT1+4(a6),GS_T1+4(a6)
	rts

	section	data
if_mode:	dc.b	"SECTOR",0
if_fn_mod:	dc.b	"SOUND",92,"GENER1.MOD",0
if_fn_sysset:	dc.b	"DATA",92,"SYSSET.DTA",0
	even

	section	bss
if_dots:	ds.l	40		; this frame's dots in starmapscreen (offsets)
if_nmin:	ds.w	106		; per copied row: first column with a dot
if_nmax:	ds.w	106		; (212 bytes after if_nmin) last column
if_ndots:	ds.w	1
if_smok:	ds.b	1		; starmapscreen = zeros + if_dots
	even
if_tarxr:	ds.l	2		; (tarxr, taryr, tarzr together: rotateit treats them as a record)
if_taryr:	ds.l	2
if_tarzr:	ds.l	2
if_tarx:	ds.w	1		; (tarx, tary, tarz together: movem / indexed)
if_tary:	ds.w	1
if_tarz:	ds.w	1
if_cenx:	ds.w	1
if_ceny:	ds.w	1
if_cenz:	ds.w	1
if_i:		ds.w	1
if_j:		ds.w	1
if_c1:		ds.w	1
if_sector:	ds.w	1
if_index:	ds.w	1
if_infoindex:	ds.w	1
if_rotatemode:	ds.w	1
if_engaging:	ds.b	1
	even
if_temp:	ds.b	4
if_s:		ds.b	32
if_nearsec:	ds.b	38*NS_SIZE
	even
	section	text
