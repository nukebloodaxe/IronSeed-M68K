; cargtool2.s - cargtool.pas's creation screen (included by cargtool.s). Mode TECH1.
; createinfo^ is DATA\CREATION.DTA (123 x creationtype); its entries 0 and 124 (read by the
; original's cursor loops at their ends) are zeros here.

	section	text
; a0 = createinfo^[d0] (0..124)
cr_info:
	mulu	#CREATION_SIZEOF,d0
	lea	cr_create,a0
	add.l	d0,a0
	rts
; d0 = number of crew j with level >= levels[j] (a0 = a creation record)
cr_levelsok:
	lea	GS_SHIP+SHIP_CREW+CREW_LEVEL(a6),a1
	moveq	#0,d0
	moveq	#6-1,d1
	movem.l	d2/a0,-(sp)
	lea	CREATION_LEVELS(a0),a0
.l:	move.b	(a1),d2
	cmp.b	(a0)+,d2
	blo.s	.n
	addq.w	#1,d0
.n:	lea	CREW_SIZEOF(a1),a1
	dbf	d1,.l
	movem.l	(sp)+,d2/a0
	rts
; the creation list's class of item d0: sets cr_drawit if filters[] allows it; d1 := tcolor
; (0..2999 devices: filters[3], 47; components: [2], 79; materials 4000..4999: [1], 143)
; artifacts count as devices when d2.b is set (the cargo view)
cr_classify:
	moveq	#-1,d1
	tst.w	d0
	bmi.s	.x
	cmp.w	#2999,d0
	ble.s	.dev
	cmp.w	#3999,d0
	ble.s	.cmp
	cmp.w	#4999,d0
	ble.s	.mat
	tst.b	d2
	beq.s	.x
	cmp.w	#ID_ARTIFACT_OFFSET,d0
	blt.s	.x
	cmp.w	#ID_LAST_ARTIFACT,d0
	ble.s	.dev
.x:	rts
.dev:	moveq	#47,d1
	tst.b	cr_filters+2
	bra.s	.set
.cmp:	moveq	#79,d1
	tst.b	cr_filters+1
	bra.s	.set
.mat:	move.w	#143,d1
	tst.b	cr_filters
.set:	beq.s	.x
	st	cr_drawit
	rts

; inccursor / deccursor
cr_inccursor:
	moveq	#1,d0
	bra.s	cr_movecursor
cr_deccursor:
	moveq	#-1,d0
cr_movecursor:
	movem.l	d3-d4,-(sp)
	move.w	d0,d3			; step
	sf	cr_drawit
	tst.w	ct2_mode_
	bne.s	.cg
.d:	add.w	d3,ct2_index		; devices: until (all levels) and drawit, or out of the list
	move.w	ct2_index,d0
	bsr	cr_info
	bsr	cr_levelsok
	move.w	d0,d4
	move.w	CREATION_INDEX(a0),d0
	sf	d2
	bsr	cr_classify
	cmp.w	#6,d4
	bne.s	.dn
	tst.b	cr_drawit
	bne	.e
.dn:	tst.w	d3
	bmi.s	.dd
	move.w	cr_max,d0
	cmp.w	ct2_index,d0
	bge.s	.d
	bra.s	.e
.dd:	cmp.w	#1,ct2_index
	bge.s	.d
	bra.s	.e
.cg:	add.w	d3,ct2_index		; cargo: the next slot with something in it
.cw:	move.w	ct2_index,d0
	tst.w	d3
	bmi.s	.cwd
	cmp.w	#251,d0
	bge.s	.cc
	bsr	ct2_num
	tst.w	d0
	bne.s	.cc
	addq.w	#1,ct2_index
	bra.s	.cw
.cwd:	tst.w	d0
	ble.s	.cc
	bsr	ct2_num
	tst.w	d0
	bne.s	.cc
	subq.w	#1,ct2_index
	bra.s	.cw
.cc:	move.w	ct2_index,d0
	bsr	ct2_cargo
	st	d2
	bsr	cr_classify
	tst.b	cr_drawit
	bne.s	.e
	tst.w	d3
	bmi.s	.cd
	cmp.w	#250,ct2_index
	ble.s	.cg
	bra.s	.e
.cd:	cmp.w	#1,ct2_index
	bge.s	.cg
.e:	tst.b	cr_qmode		; if qmode and (viewteam > 0): viewteam := 0, the bar cleared
	beq.s	.x
	tst.w	cr_viewteam
	ble.s	.x
	clr.w	cr_viewteam
	bsr	cr_clearbar
.x:	st	GS_ANYCHANGE(a6)
	movem.l	(sp)+,d3-d4
	rts
cr_clearbar:				; rows 77..80, x 222..298 := 0
	movem.l	d3-d4,-(sp)
	move.w	#222,d0
	moveq	#77,d1
	move.w	#298,d2
	moveq	#80,d3
	moveq	#0,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
	rts
cr_clearparts:				; the three part boxes and the project name
	movem.l	d3-d5,-(sp)
	moveq	#0,d5
.j:	move.w	d5,d1			; rows j*21+40 .. +13, x 131..209
	mulu	#21,d1
	add.w	#40,d1
	move.w	d1,d3
	add.w	#13,d3
	move.w	#131,d0
	move.w	#209,d2
	moveq	#0,d4
	bsr	ms_bar
	addq.w	#1,d5
	cmp.w	#2,d5
	ble.s	.j
	move.w	#221,d0			; rows 59..72, x 221..299
	moveq	#59,d1
	move.w	#299,d2
	moveq	#72,d3
	moveq	#0,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d5
	rts

cr_adjustteams:
	movem.l	d3-d4,-(sp)
	bsr	mousehide
	moveq	#1,d3
.a:	move.w	d3,d0
	subq.w	#1,d0
	lsl.w	#3,d0
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a0
	tst.w	TEAM_JOB(a0,d0.w)
	seq	d4
	move.w	#204,d0			; job = 0 and the light is 95: anychange
	move.w	d3,d1
	mulu	#10,d1
	add.w	#114,d1
	bsr	ms_addr
	tst.b	d4
	beq.s	.c
	cmp.b	#95,(a0)
	bne.s	.c
	st	GS_ANYCHANGE(a6)
.c:	moveq	#95,d2
	tst.b	d4
	beq.s	.p
	moveq	#60,d2
.p:	move.b	d2,(a0)+
	move.b	d2,(a0)+
	move.b	d2,(a0)+
	move.b	d2,(a0)+
	move.w	#204,d0
	move.w	d3,d1
	mulu	#10,d1
	add.w	#114,d1
	move.w	#207,d2
	move.w	d3,-(sp)
	move.w	d1,d3
	bsr	ms_dirty
	move.w	(sp)+,d3
	addq.w	#1,d3
	cmp.w	#3,d3
	ble.s	.a
	bsr	mouseshow
	movem.l	(sp)+,d3-d4
	rts

cr_drawfilters2:
	movem.l	d3-d5,-(sp)
	bsr	mousehide
	moveq	#1,d5
.b:	moveq	#95,d4
	lea	cr_filters-1,a0
	tst.b	0(a0,d5.w)
	beq.s	.c
	moveq	#60,d4
.c:	moveq	#51,d0			; screen[114+b*11, 51..54]
	move.w	d5,d1
	mulu	#11,d1
	add.w	#114,d1
	moveq	#54,d2
	move.w	d1,d3
	bsr	ms_bar
	addq.w	#1,d5
	cmp.w	#3,d5
	ble.s	.b
	bsr	mouseshow
	movem.l	(sp)+,d3-d5
	rts

; split a name (a0, string[19] semantics: at most 19 characters) at its first space:
; cr_s1 := the first word, cr_s2 := the rest without trailing spaces
cr_split:
	movem.l	d3/a3,-(sp)
	move.l	a0,a3
	moveq	#0,d3
	move.b	(a3),d3			; s: string[19] := name (cut to 19)
	cmp.w	#19,d3
	ble.s	.l
	moveq	#19,d3
.l:	lea	cr_sn,a0
	move.b	d3,(a0)
	moveq	#20-1,d0		; (the characters: all 20, as the copy into s takes them)
	lea	1(a3),a1
	lea	1(a0),a0
.c:	move.b	(a1)+,(a0)+
	dbf	d0,.c
	lea	cr_sn,a3
	moveq	#1,d0			; i := 1; while (i < 19) and (s[i] <> ' ') do inc(i)
.i:	cmp.w	#19,d0
	bge.s	.ie
	cmp.b	#' ',0(a3,d0.w)
	beq.s	.ie
	addq.w	#1,d0
	bra.s	.i
.ie:	move.w	d0,d1			; s1 := copy(s, 0, i-1) = the first i-1 characters
	subq.w	#1,d1
	cmp.w	d3,d1
	ble.s	.c1
	move.w	d3,d1
.c1:	lea	cr_s1,a0
	move.b	d1,(a0)+
	lea	1(a3),a1
	bra.s	.c2e
.c2:	move.b	(a1)+,(a0)+
.c2e:	dbf	d1,.c2
	move.w	d0,d1			; s2 := copy(s, i+1, 19-i)
	addq.w	#1,d1			; index i+1
	moveq	#19,d2
	sub.w	d0,d2			; count
	move.w	d3,d0
	sub.w	d1,d0
	addq.w	#1,d0			; length - index + 1 left
	bpl.s	.k
	moveq	#0,d0
.k:	cmp.w	d0,d2
	ble.s	.k2
	move.w	d0,d2
.k2:	tst.w	d2
	bpl.s	.k3
	moveq	#0,d2
.k3:	lea	cr_s2,a0
	move.b	d2,(a0)+
	lea	0(a3,d1.w),a1
	move.w	d2,d0
	bra.s	.c3e
.c3:	move.b	(a1)+,(a0)+
.c3e:	dbf	d0,.c3
	lea	cr_s2,a0		; i := length(s2); while (i > 1) and (s2[i] = ' ') do dec(i)
	moveq	#0,d0
	move.b	(a0),d0
.t:	cmp.w	#1,d0
	ble.s	.te
	cmp.b	#' ',0(a0,d0.w)
	bne.s	.te
	subq.w	#1,d0
	bra.s	.t
.te:	move.b	d0,(a0)
	movem.l	(sp)+,d3/a3
	rts
; printxy(x0 + round((78 - length(a0^)*5)/2), y d1, a0)
cr_pcentre:
	movem.l	d1/a0,-(sp)
	moveq	#0,d1
	move.b	(a0),d1
	mulu	#5,d1
	neg.w	d1
	add.w	#78,d1			; v, rounded v/2 (banker's at .5, symmetric)
	move.w	d1,d2
	bpl.s	.p
	neg.w	d2
.p:	lsr.w	#1,d2
	bcc.s	.e
	btst	#0,d2
	beq.s	.e
	addq.w	#1,d2
.e:	tst.w	d1
	bpl.s	.q
	neg.w	d2
.q:	add.w	d2,d0
	movem.l	(sp)+,d1/a0
	bra	printxy

cr_displaybreakdown:
	movem.l	d3-d7/a3,-(sp)
	move.w	d0,d7			; item
	beq	.x
	move.w	d7,cr_lastinfo
	bsr	mousehide
	TCOL	28
	cmp.w	#ID_ARTIFACT_OFFSET,d7
	ble.s	.c
	move.w	d7,d0
	bsr	getartifactname
	lea	GS_CARGO+(MAXCARGO-1)*CARGO_SIZEOF+CARGO_NAME(a6),a0
	bra.s	.s
.c:	moveq	#1,d6			; a: the item in createinfo^
.ca:	move.w	d6,d0
	bsr	cr_info
	cmp.w	CREATION_INDEX(a0),d7
	beq.s	.cf
	cmp.w	#TOTALCREATION,d6
	bge	fatal			; ('creation array overflow')
	addq.w	#1,d6
	bra.s	.ca
.cf:	move.w	d6,cr_a
	lea	CREATION_NAME(a0),a0
.s:	bsr	cr_split
	move.w	#217,d0
	moveq	#59,d1
	lea	cr_s1,a0
	bsr	cr_pcentre
	move.w	#217,d0
	moveq	#65,d1
	lea	cr_s2,a0
	bsr	cr_pcentre
	cmp.w	#ID_ARTIFACT_OFFSET,d7
	bge	.art
	move.w	#-1,d5			; k (unused unless device view without a team)
	tst.w	ct2_mode_
	bne.s	.nk
	tst.w	cr_viewteam
	bne.s	.nk
	move.w	d7,d0
	bsr	ct2_buildstock
	move.w	d0,d5
.nk:	moveq	#1,d4			; j
.j:	move.w	cr_a,d0
	bsr	cr_info
	move.w	d4,d1
	add.w	d1,d1
	move.w	CREATION_PARTS-2(a0,d1.w),d3	; i := parts[j]
	tst.w	ct2_mode_
	bne.s	.t26
	tst.w	cr_viewteam
	bne.s	.t26
	moveq	#95,d0
	tst.w	d5
	bmi.s	.tc
	move.w	d4,d1			; case (k shr (j+j-2)) and 3
	add.w	d1,d1
	subq.w	#2,d1
	move.w	d5,d2
	lsr.w	d1,d2
	and.w	#3,d2
	beq.s	.tc
	moveq	#63,d0
	cmp.w	#1,d2
	beq.s	.tc
	moveq	#127,d0
	cmp.w	#2,d2
	beq.s	.tc
	move.w	GS_TCOLOR(a6),d0	; (3: unchanged)
	bra.s	.tc
.t26:	moveq	#26,d0
.tc:	move.w	d0,GS_TCOLOR(a6)
	move.w	d3,d0			; the part's name, in two lines
	bsr	ct2_cargorec
	lea	CARGO_NAME(a0),a0
	bsr	cr_split
	move.w	#127,d0
	move.w	d4,d1
	mulu	#21,d1
	add.w	#19,d1
	lea	cr_s1,a0
	bsr	cr_pcentre
	move.w	#127,d0
	move.w	d4,d1
	mulu	#21,d1
	add.w	#25,d1
	lea	cr_s2,a0
	bsr	cr_pcentre
	addq.w	#1,d4
	cmp.w	#3,d4
	ble	.j
	bra.s	.m
.art:	PXY	146,61,"Research"
	PXY	146,67,"Artifact"
.m:	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d7/a3
	rts

; weaponinfo(n d0): the weapon's figures, damage bars and icon at the top
cr_weaponinfo:
	movem.l	d3-d7/a3,-(sp)
	move.w	d0,d7
	TCOL	31
	BKCOL	1
	move.w	d7,d0
	subq.w	#1,d0
	mulu	#CARGO_SIZEOF,d0
	lea	GS_CARGO+CARGO_NAME(a6),a0
	add.w	d0,a0
	move.w	#127,d0
	moveq	#2,d1
	bsr	printxy
	TCOL	95
	move.w	d7,d0
	subq.w	#1,d0
	mulu	#WEAPON_SIZEOF,d0
	lea	GS_WEAPONS(a6),a3
	add.w	d0,a3
	move.l	WEAPON_RANGE(a3),d0	; str((range div 1000):3)
	divs	#1000,d0
	ext.l	d0
	moveq	#3,d1
	lea	cr_s1,a0
	bsr	int_str
	lea	cr_t_range,a0
	lea	cr_s1,a1
	lea	cr_t_kkm,a2
	moveq	#11,d1
	bsr	.line
	move.w	WEAPON_ENERGY(a3),d0
	ext.l	d0
	moveq	#4,d1
	lea	cr_s1,a0
	bsr	int_str
	lea	cr_t_energy,a0
	lea	cr_s1,a1
	lea	cr_t_gw,a2
	moveq	#17,d1
	bsr	.line
	move.w	WEAPON_DAMAGE(a3),d0
	ext.l	d0
	moveq	#4,d1
	lea	cr_s1,a0
	bsr	int_str
	lea	cr_t_damage,a0
	lea	cr_s1,a1
	lea	cr_t_gj,a2
	moveq	#23,d1
	bsr	.line
	PXY	230,5,"PSION"
	PXY	230,11,"PRTCL"
	PXY	230,17,"INRTL"
	PXY	230,23,"ENRGY"
	moveq	#1,d6			; j: the bars (x, y are data.pas's)
.b:	moveq	#0,d0			; x := round(dmgtypes[j]/2) (banker's)
	move.b	WEAPON_DMGTYPES-1(a3,d6.w),d0
	lsr.w	#1,d0
	bcc.s	.bx
	btst	#0,d0
	beq.s	.bx
	addq.w	#1,d0
.bx:	move.w	d0,GS_X(a6)
	moveq	#-1,d5			; i
.bi:	moveq	#100,d4			; y := 100-i (i > 0) else 100+i
	tst.w	d5
	ble.s	.bp
	sub.w	d5,d4
	bra.s	.bq
.bp:	add.w	d5,d4
.bq:	move.w	d4,GS_Y(a6)
	move.w	d6,d1			; row 1+i+j*6
	mulu	#6,d1
	add.w	d5,d1
	addq.w	#1,d1
	move.w	GS_X(a6),d2
	beq.s	.b0
	move.w	#260,d0			; scr_fillchar(screen[row, 260], x, y)
	add.w	#259,d2
	move.w	d1,d3
	movem.w	d1,-(sp)
	bsr	ms_bar
	movem.w	(sp)+,d1
.b0:	cmp.w	#50,GS_X(a6)
	bge.s	.bn
	move.w	#260,d0			; scr_fillchar(screen[row, 260+x], 50-x, 0)
	add.w	GS_X(a6),d0
	move.w	#309,d2
	move.w	d1,d3
	moveq	#0,d4
	bsr	ms_bar
.bn:	addq.w	#1,d5
	cmp.w	#4,d5
	ble.s	.bi
	move.w	d5,cr_i
	addq.w	#1,d6
	cmp.w	#4,d6
	ble	.b
	move.w	d7,d0			; the icon: readweaicon(n-1) (n < 59) else n-2
	subq.w	#1,d0
	cmp.w	#59,d7
	blt.s	.ic
	subq.w	#1,d0
.ic:	bsr	readweaicon
	move.l	GS_TEMPICON(a6),a1
	moveq	#9,d3
.ir:	move.w	#210,d0
	move.w	d3,d1
	bsr	ms_addr
	moveq	#20/2-1,d0
.irc:	move.b	(a1)+,(a0)+
	move.b	(a1)+,(a0)+
	dbf	d0,.irc
	addq.w	#1,d3
	cmp.w	#28,d3
	ble.s	.ir
	move.w	#210,d0
	moveq	#9,d1
	move.w	#229,d2
	moveq	#28,d3
	bsr	ms_dirty
	BKCOL	0
	movem.l	(sp)+,d3-d7/a3
	rts
.line:	move.w	d1,-(sp)		; printxy(127, y d1, a0^ + a1^ + a2^)
	movem.l	a1-a2,-(sp)
	move.l	a0,a1
	lea	cr_s2,a0
	bsr	pstr_cpy
	move.l	(sp),a1
	lea	cr_s2,a0
	bsr	pstr_cat
	move.l	4(sp),a1
	lea	cr_s2,a0
	bsr	pstr_cat
	addq.l	#8,sp
	move.w	(sp)+,d1
	move.w	#127,d0
	lea	cr_s2,a0
	bra	printxy

cr_getinfo:
	movem.l	d3-d7/a3,-(sp)
	tst.w	ct2_index
	beq	.x
	tst.w	ct2_mode_
	bne.s	.cg
	move.w	ct2_index,d0
	bsr	cr_info
	move.w	CREATION_INDEX(a0),d7	; index
	bra	.rd
.cg:	move.w	ct2_index,d0
	bsr	ct2_cargo
	move.w	d0,d7
	cmp.w	#ID_ARTIFACT_OFFSET,d7
	ble.s	.u
	bsr	getartifactname
.u:	cmp.w	#ID_UNKNOWN_COMPONENT,d7
	beq.s	.ident
	cmp.w	#ID_UNKNOWN_MATERIAL,d7
	bne	.rd
.ident:	move.w	ct2_index,d3		; identify the unknowns: each becomes index+random(20)+1
	add.w	d3,d3
	lea	GS_SHIP+SHIP_CARGO-2(a6),a0
	clr.w	0(a0,d3.w)
	lea	GS_SHIP+SHIP_NUMCARGO-2(a6),a0
	move.w	0(a0,d3.w),d4		; i
	clr.w	0(a0,d3.w)
	move.w	d4,cr_i
	moveq	#1,d5
.id:	cmp.w	d4,d5
	bgt.s	.ide
	moveq	#20,d0
	bsr	mt_random
	add.w	d7,d0
	addq.w	#1,d0
	st	d1
	bsr	addcargo
	addq.w	#1,d5
	bra.s	.id
.ide:	move.w	ct2_index,d0
	bsr	ct2_cargo
	move.w	d0,d7
	st	GS_ANYCHANGE(a6)
	subq.w	#1,ct2_index
	bsr	cr_inccursor
	bsr	cr_outofrange
	beq.s	.rd
	clr.w	ct2_index
	bsr	cr_inccursor
	bsr	cr_outofrange
	beq.s	.rd
	clr.w	ct2_index
.rd:	moveq	#0,d6			; i: the item's iteminfo record (the file is read in order)
	tst.w	d7
	ble.s	.rn
	lea	cr_iteminfo,a3
.r:	addq.w	#1,d6
	lea	cr_ii,a1		; iteminfo^ := record i
	moveq	#II_SIZE/2-1,d0
.rc:	move.w	(a3)+,(a1)+
	dbf	d0,.rc
	cmp.w	cr_ii,d7
	beq.s	.rn
	cmp.w	#TOTALCREATION,d6
	bne.s	.r
.rn:	move.w	d6,cr_i
	TCOL	24
	BKCOL	165
	bsr	mousehide
	tst.w	ct2_mode_
	bne.s	.n1
	move.w	ct2_index,d0
	bsr	cr_info
	lea	CREATION_NAME(a0),a0
	bra.s	.n2
.n1:	move.w	ct2_index,d0
	bsr	ct2_cargo
	cmp.w	#ID_ARTIFACT_OFFSET,d0
	ble.s	.n3
	lea	GS_CARGO+(MAXCARGO-1)*CARGO_SIZEOF+CARGO_NAME(a6),a0
	bra.s	.n2
.n3:	bsr	ct2_cargorec
	lea	CARGO_NAME(a0),a0
.n2:	moveq	#1,d0
	move.w	#160,d1
	bsr	printxy
	TCOL	18
	BKCOL	2
	cmp.w	#TOTALCREATION,d6
	bne.s	.inf
	cmp.w	cr_ii,d7
	beq.s	.inf
	movem.l	d3-d4,-(sp)		; rows 175..195, x 6..145 := 2
	moveq	#6,d0
	move.w	#175,d1
	move.w	#145,d2
	move.w	#195,d3
	moveq	#2,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
	lea	cr_t_fab,a0
	cmp.w	#ID_ARTIFACT_OFFSET,d7
	blt.s	.fb
	lea	cr_t_unk,a0
.fb:	moveq	#1,d0
	move.w	#169,d1
	bsr	printxy
	bra.s	.ie
.inf:	moveq	#0,d3
.il:	move.w	d3,d0
	mulu	#29,d0
	lea	cr_ii+2,a0
	add.w	d0,a0
	move.w	d3,d1
	mulu	#6,d1
	add.w	#169,d1
	moveq	#1,d0
	bsr	printxy
	addq.w	#1,d3
	cmp.w	#3,d3
	ble.s	.il
.ie:	BKCOL	0
	tst.w	cr_viewteam
	bne.s	.w
	bsr	cr_clearparts
	move.w	d7,d0
	bsr	cr_displaybreakdown
.w:	cmp.w	#ID_DIRK,d7
	blt.s	.cl
	cmp.w	#ID_NOSHIELD,d7
	bge.s	.sh
	move.w	d7,d0
	sub.w	#ID_DIRK-1,d0
	bsr	cr_weaponinfo
	bra.s	.m
.sh:	cmp.w	#ID_NOTHING,d7
	bge.s	.cl
	move.w	d7,d0
	sub.w	#ID_SHIELDS_OFFSET,d0
	bsr	cr_weaponinfo
	bra.s	.m
.cl:	movem.l	d3-d4,-(sp)		; rows 3..29, x 132..311 := 1
	move.w	#132,d0
	moveq	#3,d1
	move.w	#311,d2
	moveq	#29,d3
	moveq	#1,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
.m:	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d7/a3
	rts
; Z clear (d0 = 1) if the cursor is past its list (devices: > maxcreation, cargo: > 250)
cr_outofrange:
	move.w	ct2_index,d1
	moveq	#0,d0
	tst.w	ct2_mode_
	bne.s	.c
	cmp.w	cr_max,d1
	ble.s	.x
	moveq	#1,d0
	rts
.c:	cmp.w	#250,d1
	ble.s	.x
	moveq	#1,d0
.x:	tst.w	d0
	rts

; the devices list: 7 entries above the cursor, 8 below (rows 22..118, x 11..110)
cr_devline:				; entry d0 = x: d0 = 1 if drawn (i = 6 and drawit); sets tcolor
	movem.l	d3-d4/a3,-(sp)
	move.w	d0,d3
	sf	cr_drawit
	bsr	cr_info
	move.l	a0,a3
	bsr	cr_levelsok
	move.w	d0,d4
	move.w	CREATION_INDEX(a3),d0
	sf	d2
	bsr	cr_classify
	tst.w	d1
	bmi.s	.t
	move.w	d1,GS_TCOLOR(a6)
.t:	moveq	#0,d0
	cmp.w	#6,d4
	bne.s	.x
	tst.b	cr_drawit
	beq.s	.x
	moveq	#1,d0
.x:	movem.l	(sp)+,d3-d4/a3
	rts
cr_partsok:				; a3 = creation record: tcolor 31 if its parts are in the hold
	movem.l	d3-d4,-(sp)		; (else 16 when colorcode is off)
	moveq	#0,d3			; k
	move.w	CREATION_PARTS(a3),d4
	moveq	#3-1,d1
	lea	CREATION_PARTS(a3),a0
.k:	cmp.w	(a0)+,d4
	bne.s	.kn
	addq.w	#1,d3
.kn:	dbf	d1,.k
	move.w	d4,d0
	bsr	incargo
	cmp.w	d3,d0
	blt.s	.no
	move.w	CREATION_PARTS+2(a3),d0
	bsr	incargo
	tst.w	d0
	beq.s	.no
	move.w	CREATION_PARTS+4(a3),d0
	bsr	incargo
	tst.w	d0
	beq.s	.no
	TCOL	31
	bra.s	.x
.no:	tst.b	cr_colorcode
	bne.s	.x
	TCOL	16
.x:	movem.l	(sp)+,d3-d4
	rts
cr_displaydevices:
	movem.l	d3-d5/a3,-(sp)
	sf	GS_ANYCHANGE(a6)
	tst.b	cr_qmode
	beq.s	.q
	tst.w	ct2_index
	ble.s	.q
	bsr	cr_getinfo
.q:	move.w	ct2_index,GS_X(a6)
	move.w	#9,GS_Y(a6)
	bsr	mousehide
	tst.w	GS_X(a6)
	ble.s	.e1
.l1:	move.w	GS_X(a6),d0
	bsr	cr_devline
	tst.w	d0
	beq.s	.n1
	subq.w	#1,GS_Y(a6)
	BKCOL	0
	cmp.w	#8,GS_Y(a6)
	bne.s	.b1
	BKCOL	6
.b1:	move.w	GS_X(a6),d0
	bsr	cr_info
	move.l	a0,a3
	bsr	cr_partsok
	lea	CREATION_NAME(a3),a0
	bsr	cr_print6
.n1:	subq.w	#1,GS_X(a6)
	cmp.w	#1,GS_Y(a6)
	beq.s	.e1
	cmp.w	#1,GS_X(a6)
	bge.s	.l1
.e1:	cmp.w	#1,GS_Y(a6)
	ble.s	.c1
	moveq	#22,d1			; rows 22 .. y*6+16
	move.w	GS_Y(a6),d3
	mulu	#6,d3
	add.w	#16,d3
	bsr	cr_clearlist
.c1:	move.w	ct2_index,d0
	addq.w	#1,d0
	move.w	d0,GS_X(a6)
	move.w	#8,GS_Y(a6)
	BKCOL	0
.l2:	move.w	GS_X(a6),d0
	bsr	cr_devline
	tst.w	d0
	beq.s	.n2
	move.w	cr_max,d0
	cmp.w	GS_X(a6),d0
	blt.s	.n2
	addq.w	#1,GS_Y(a6)
	move.w	GS_X(a6),d0
	bsr	cr_info
	move.l	a0,a3
	bsr	cr_partsok
	lea	CREATION_NAME(a3),a0
	bsr	cr_print6
.n2:	addq.w	#1,GS_X(a6)
	cmp.w	#16,GS_Y(a6)
	beq.s	.e2
	move.w	cr_max,d0
	cmp.w	GS_X(a6),d0
	bge.s	.l2
.e2:	cmp.w	#16,GS_Y(a6)
	bge.s	.m
	move.w	GS_Y(a6),d1		; rows y*6+23 .. 118
	mulu	#6,d1
	add.w	#23,d1
	moveq	#118,d3
	bsr	cr_clearlist
.m:	bsr	mouseshow
	movem.l	(sp)+,d3-d5/a3
	rts
cr_print6:				; printxy(6, 16+y*6, a0)
	move.w	GS_Y(a6),d1
	mulu	#6,d1
	add.w	#16,d1
	moveq	#6,d0
	bra	printxy
cr_clearlist:				; rows d1..d3, x 11..110 := 0
	cmp.w	d3,d1
	bgt.s	.x
	movem.l	d3-d4,-(sp)
	moveq	#11,d0
	moveq	#110,d2
	moveq	#0,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
.x:	rts

; the cargo list of the creation screen (decompose)
cr_cargoline:				; slot d0 (1..251): d0 = 1 if drawn; a0 = the name; sets tcolor
	movem.l	d3,-(sp)
	move.w	d0,d3
	sf	cr_drawit
	bsr	ct2_cargo
	st	d2
	bsr	cr_classify
	tst.w	d1
	bmi.s	.t
	move.w	d1,GS_TCOLOR(a6)
.t:	tst.b	cr_colorcode
	bne.s	.c
	TCOL	31
.c:	moveq	#0,d0
	tst.b	cr_drawit
	beq.s	.x
	move.w	d3,d0
	bsr	ct2_cargo
	cmp.w	#ID_ARTIFACT_OFFSET,d0
	ble.s	.i
	bsr	getartifactname
	lea	GS_CARGO+(MAXCARGO-1)*CARGO_SIZEOF+CARGO_NAME(a6),a0
	bra.s	.y
.i:	bsr	ct2_cargorec
	lea	CARGO_NAME(a0),a0
.y:	moveq	#1,d0
.x:	movem.l	(sp)+,d3
	rts
cr_displaycargo:
	movem.l	d3-d5,-(sp)
	sf	GS_ANYCHANGE(a6)
	move.w	ct2_index,d0
	bsr	ct2_cargo
	tst.w	d0
	bne.s	.a
	bsr	cr_inccursor
.a:	tst.b	cr_qmode
	beq.s	.q
	tst.w	ct2_index
	ble.s	.q
	bsr	cr_getinfo
.q:	tst.w	ct2_index
	bne.s	.go
	moveq	#22,d1
	moveq	#118,d3
	bsr	cr_clearlist
	bra	.x
.go:	move.w	#9,GS_Y(a6)
	move.w	ct2_index,GS_X(a6)
	TCOL	31
	bsr	mousehide
.l1:	move.w	GS_X(a6),d3		; while (x > 0) and (numcargo[x] = 0) do dec(x)
.w1:	tst.w	d3
	ble.s	.w1e
	move.w	d3,d0
	bsr	ct2_num
	tst.w	d0
	bne.s	.w1e
	subq.w	#1,d3
	bra.s	.w1
.w1e:	move.w	d3,GS_X(a6)
	sf	cr_drawit
	tst.w	d3
	ble.s	.z1
	move.w	d3,d0
	bsr	cr_cargoline
	tst.w	d0
	beq.s	.n1
	subq.w	#1,GS_Y(a6)
	BKCOL	0
	cmp.w	#8,GS_Y(a6)
	bne.s	.b1
	BKCOL	6
.b1:	bsr	cr_print6
	bra.s	.n1
.z1:	tst.b	cr_colorcode		; (x = 0: no case, but the colour rule)
	bne.s	.n1
	TCOL	31
.n1:	subq.w	#1,GS_X(a6)
	cmp.w	#1,GS_Y(a6)
	beq.s	.e1
	cmp.w	#1,GS_X(a6)
	bge.s	.l1
.e1:	cmp.w	#1,GS_Y(a6)
	ble.s	.c1
	moveq	#22,d1
	move.w	GS_Y(a6),d3
	mulu	#6,d3
	add.w	#16,d3
	bsr	cr_clearlist
.c1:	move.w	ct2_index,d0
	addq.w	#1,d0
	move.w	d0,GS_X(a6)
	move.w	#8,GS_Y(a6)
	BKCOL	0
.l2:	move.w	GS_X(a6),d3		; while (x < 251) and (numcargo[x] = 0) do inc(x)
.w2:	cmp.w	#251,d3
	bge.s	.w2e
	move.w	d3,d0
	bsr	ct2_num
	tst.w	d0
	bne.s	.w2e
	addq.w	#1,d3
	bra.s	.w2
.w2e:	move.w	d3,GS_X(a6)
	move.w	d3,d0
	bsr	cr_cargoline
	tst.w	d0
	beq.s	.n2
	cmp.w	#251,GS_X(a6)
	bge.s	.n2
	addq.w	#1,GS_Y(a6)
	bsr	cr_print6
.n2:	addq.w	#1,GS_X(a6)
	cmp.w	#16,GS_Y(a6)
	beq.s	.e2
	cmp.w	#250,GS_X(a6)
	ble.s	.l2
.e2:	cmp.w	#16,GS_Y(a6)
	bge.s	.m
	move.w	GS_Y(a6),d1
	mulu	#6,d1
	add.w	#23,d1
	moveq	#118,d3
	bsr	cr_clearlist
.m:	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d5
	rts

cr_displayteaminfo:
	movem.l	d3-d7/a3,-(sp)
	move.w	d0,d7			; team
	TCOL	31
	bsr	cr_adjustteams
	move.w	d7,d0
	subq.w	#1,d0
	lsl.w	#3,d0
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a3
	add.w	d0,a3
	tst.w	TEAM_JOB(a3)
	bne.s	.j
	bsr	mousehide
	bsr	cr_clearparts
	bsr	cr_clearbar
	clr.w	cr_viewteam
	bsr	mouseshow
	bra	.x
.j:	bsr	mousehide
	move.w	TEAM_JOB(a3),d0
	cmp.w	ct2_teamjob,d0
	beq.s	.t
	bsr	cr_clearparts
	bsr	cr_clearbar
	move.w	TEAM_JOB(a3),ct2_teamjob
.t:	move.w	TEAM_JOBTYPE(a3),d0
	cmp.w	#JOBTYPE_REPAIR,d0
	bne.s	.t1
	PXY	233,62,"Repairing"
	bra.s	.t5
.t1:	cmp.w	#JOBTYPE_INSTALL,d0
	bne.s	.t2
	PXY	231,62,"Installing"
	bra.s	.t5
.t2:	cmp.w	#JOBTYPE_REMOVE,d0
	bne.s	.t3
	PXY	236,62,"Removing"
	bra.s	.t5
.t3:	cmp.w	#JOBTYPE_RESEARCH,d0
	bne.s	.t5
	PXY	236,62,"Research"
.t5:	cmp.w	#JOBTYPE_CREATE,TEAM_JOBTYPE(a3)
	bge.s	.cr
	bsr	cr_clearbar
	bsr	mouseshow
	bra	.x
.cr:	cmp.w	#JOBTYPE_RESEARCH,TEAM_JOBTYPE(a3)
	bge.s	.pb
	move.w	TEAM_JOB(a3),d0
	bsr	cr_displaybreakdown
.pb:	FSSE				; b := 76 - round(timeleft/GetBuildTime(job)*76)
	move.w	TEAM_TIMELEFT(a3),d0
	bsr	fp_ldw
	move.w	TEAM_JOB(a3),d0
	bsr	getbuildtime
	bsr	fp_ldw
	bsr	fp_div
	FLDI	76
	bsr	fp_mul
	bsr	fp_rnd
	moveq	#76,d6
	sub.w	d0,d6			; b
	bne.s	.b1
	moveq	#1,d6
.b1:	moveq	#0,d5			; j: 0..b: a := round(15/b*j+48), rows 77..80 at x j+222
.bj:	FLDI	15
	move.w	d6,d0
	bsr	fp_ldw
	bsr	fp_div
	move.w	d5,d0
	bsr	fp_ldw
	bsr	fp_mul
	FLDI	48
	bsr	fp_add
	bsr	fp_rnd
	move.w	d0,cr_a
	move.w	d0,d4
	move.w	d5,d0
	add.w	#222,d0
	moveq	#77,d1
	move.w	d0,d2
	moveq	#80,d3
	bsr	ms_bar
	addq.w	#1,d5
	cmp.w	d6,d5
	ble.s	.bj
	move.w	d5,cr_j
	cmp.w	#76,d6			; if b < 76: rows 77..80 from b+223, 75-b bytes := 0
	bge.s	.m
	move.w	d6,d0
	add.w	#223,d0
	moveq	#77,d1
	move.w	#297,d2
	moveq	#80,d3
	moveq	#0,d4
	cmp.w	d0,d2
	blt.s	.m
	bsr	ms_bar
.m:	bsr	mouseshow
	st	GS_ANYCHANGE(a6)
.x:	movem.l	(sp)+,d3-d7/a3
	rts

; go2(team d0): take the cargo item apart (decompose) or research the artifact
cr_go2:
	movem.l	d3-d7/a3,-(sp)
	move.w	d0,d7
	move.w	ct2_index,d0
	bsr	ct2_cargo
	move.w	d0,d6			; the item
	cmp.w	#ID_UNKNOWN_COMPONENT,d6
	beq.s	.unk
	cmp.w	#ID_UNKNOWN_MATERIAL,d6
	bne.s	.k
.unk:	bsr	cr_getinfo
	bsr	cr_displaycargo
	bra	.x
.k:	cmp.w	#ID_ARTIFACT_OFFSET,d6
	bge.s	.t
	move.w	d6,d0
	bsr	cr_displaybreakdown
.t:	move.w	d7,d0
	subq.w	#1,d0
	lsl.w	#3,d0
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a3
	add.w	d0,a3
	move.w	d6,TEAM_JOB(a3)
	move.w	#JOBTYPE_DECOMPOSE,TEAM_JOBTYPE(a3)
	cmp.w	#ID_ARTIFACT_OFFSET,d6
	blt.s	.dc
	move.w	#JOBTYPE_RESEARCH,TEAM_JOBTYPE(a3)
	moveq	#5,d0			; timeleft := ID_ARTIFACT_OFFSET + random(5)*100
	bsr	mt_random
	mulu	#100,d0
	add.w	#ID_ARTIFACT_OFFSET,d0
	move.w	d0,TEAM_TIMELEFT(a3)
	bra.s	.n
.dc:	moveq	#1,d0			; timeleft := sum of 100*levels[j] of its creation entry
.dl:	move.w	d0,-(sp)
	bsr	cr_info
	move.w	(sp)+,d1
	cmp.w	CREATION_INDEX(a0),d6
	beq.s	.df
	move.w	d1,d0
	addq.w	#1,d0
	bra.s	.dl
.df:	move.w	d1,cr_i
	moveq	#0,d0
	moveq	#6-1,d1
	lea	CREATION_LEVELS(a0),a0
.ds:	moveq	#0,d2
	move.b	(a0)+,d2
	mulu	#100,d2
	add.w	d2,d0
	dbf	d1,.ds
	move.w	d0,TEAM_TIMELEFT(a3)
	move.w	#6,cr_j
.n:	move.w	ct2_index,d0		; dec(numcargo); if 0: the slot emptied, the cursor moved
	add.w	d0,d0
	lea	GS_SHIP+SHIP_NUMCARGO-2(a6),a0
	add.w	d0,a0
	subq.w	#1,(a0)
	bne.s	.v
	clr.w	SHIP_CARGO-SHIP_NUMCARGO(a0)
	bsr	cr_deccursor
	tst.w	ct2_index
	bgt.s	.v1
	bsr	cr_inccursor
.v1:	cmp.w	#250,ct2_index
	ble.s	.v
	clr.w	ct2_index
.v:	clr.w	ct2_teamjob
	move.w	d7,cr_viewteam
	bsr	cr_adjustteams
.x:	movem.l	(sp)+,d3-d7/a3
	rts

; go(team d0)
cr_go:
	movem.l	d3-d7/a3,-(sp)
	move.w	d0,d7
	tst.w	ct2_index
	beq	.x
	bsr	mousehide
	TCOL	31
	bsr	cr_clearparts
	bsr	mouseshow
	move.w	d7,d0			; the team is busy: just view it
	subq.w	#1,d0
	lsl.w	#3,d0
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a0
	tst.w	TEAM_JOB(a0,d0.w)
	ble.s	.free
	move.w	d7,cr_viewteam
	bra	.x
.free:	clr.w	cr_viewteam
	tst.w	ct2_mode_
	beq.s	.dev
	move.w	d7,d0
	bsr	cr_go2
	bra	.x
.dev:	move.w	ct2_index,d0
	bsr	cr_info
	move.w	CREATION_INDEX(a0),d6	; the item
	cmp.w	#ID_FUEL_NODULES,d6	; things that do not go into the hold: no weight check
	beq.s	.w
	cmp.w	#ID_MIND_ENHANCERS,d6
	beq.s	.w
	cmp.w	#ID_REINFORCE_HULL,d6
	blt.s	.cw
	cmp.w	#ID_ADD_CARGO_SPACE,d6
	ble.s	.w
.cw:	cmp.w	#ID_UNKNOWN_COMPONENT,d6
	blt.s	.cw2
	cmp.w	#ID_LAST_ELEMENT,d6
	ble.s	.w
.cw2:	st	d0
	bsr	checkweight
	beq	.x
.w:	move.w	d6,d0
	bsr	cr_displaybreakdown
	move.w	d6,d0			; i := CheckBuildStock(item)
	bsr	ct2_buildstock
	move.w	d0,d5
	move.w	d5,d1
	and.w	#$03,d1
	beq.s	.i0
	move.w	d5,d1
	and.w	#$0c,d1
	beq.s	.i0
	move.w	d5,d1
	and.w	#$30,d1
	beq.s	.i0
	tst.w	d5
	bmi.s	.res
	st	d0			; i := StartBuild(True, item, item, team)
	move.w	d6,d1
	move.w	d6,d2
	move.w	d7,d3
	bsr	startbuild
	move.w	d0,d5
	bra.s	.res
.i0:	moveq	#0,d5
.res:	move.w	d5,cr_i
	cmp.w	#1,d5
	beq	.ok
	TCOL	92
	movem.l	d3-d4,-(sp)
	move.w	#221,d0
	moveq	#59,d1
	move.w	#299,d2
	moveq	#72,d3
	moveq	#0,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
	bsr	cr_clearbar
	tst.w	d5
	bne.s	.r1
	PXY	226,59,"Insufficient"
	PXY	244,65,"Parts"
	bra	.x
.r1:	cmp.w	#-1,d5
	bne.s	.r2
	PXY	226,59,"Insufficient"
	PXY	244,65,"Level"
	bra.s	.x
.r2:	cmp.w	#-2,d5
	bne.s	.r3
	PXY	226,59,"  Internal  "
	PXY	244,65,"Error"
	bra.s	.x
.r3:	cmp.w	#-3,d5
	bne.s	.ok
	PXY	226,59,"Insufficient"
	PXY	228,65," Knowledge "
	bra.s	.x
.ok:	move.w	d7,cr_viewteam
	bsr	cr_adjustteams
	st	GS_ANYCHANGE(a6)
.x:	movem.l	(sp)+,d3-d7/a3
	rts

; findcursor: the clicked line of the list
cr_findcursor:
	move.l	d3,-(sp)
	bsr	kbd_mouse_xy
	sub.w	#16,d1
	ext.l	d1
	divs	#6,d1
	move.w	d1,GS_Y(a6)
	cmp.w	#8,d1
	beq.s	.x
	clr.w	cr_histidx		; HistoryClear
	lea	cr_history,a0
	moveq	#32-1,d0
.hc:	clr.w	(a0)+
	dbf	d0,.hc
	subq.w	#8,GS_Y(a6)
.l:	tst.w	GS_Y(a6)
	bpl.s	.dn
	bsr	cr_deccursor
	tst.w	ct2_index
	bgt.s	.u1
	bsr	cr_inccursor
.u1:	addq.w	#1,GS_Y(a6)
	bra.s	.c
.dn:	bsr	cr_inccursor
	subq.w	#1,GS_Y(a6)
.c:	bsr	cr_outofrange
	beq.s	.u
	bsr	cr_deccursor
	clr.w	GS_Y(a6)
.u:	tst.w	GS_Y(a6)
	beq.s	.x
	tst.w	ct2_index
	bgt.s	.l
.x:	move.l	(sp)+,d3
	rts

cr_setfilter:				; setfilter(n d0)
	lea	cr_filters-1,a0
	eor.b	#1,0(a0,d0.w)
	tst.w	ct2_index
	ble.s	.i
	subq.w	#1,ct2_index
.i:	bsr	cr_inccursor
	bsr	cr_outofrange
	beq.s	.d
	clr.w	ct2_index
	bsr	cr_inccursor
	bsr	cr_outofrange
	beq.s	.d
	clr.w	ct2_index
.d:	bsr	cr_drawfilters2
	st	GS_ANYCHANGE(a6)
	rts

; the mode lights: screen[6, 95..98] and screen[14, 95..98]
cr_modelights:				; d0 = colour of row 6, d1 = of row 14
	movem.l	d3-d4,-(sp)
	move.w	d1,-(sp)
	move.w	d0,d4
	moveq	#95,d0
	moveq	#6,d1
	moveq	#98,d2
	moveq	#6,d3
	bsr	ms_bar
	move.w	(sp)+,d4
	moveq	#95,d0
	moveq	#14,d1
	moveq	#98,d2
	moveq	#14,d3
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
	rts
cr_firstfree:				; go(a) for the first free team (a := 1.. until job = 0 or a = 4)
	moveq	#0,d1
.a:	addq.w	#1,d1
	cmp.w	#4,d1
	beq.s	.x
	move.w	d1,d0
	subq.w	#1,d0
	lsl.w	#3,d0
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a0
	tst.w	TEAM_JOB(a0,d0.w)
	bne.s	.a
.x:	move.w	d1,cr_a
	cmp.w	#4,d1
	bge.s	.n
	move.w	d1,d0
	bra	cr_go
.n:	rts
cr_setdevicemode:
	tst.w	ct2_mode_
	beq.s	.go
	bsr	mousehide
	moveq	#63,d0
	moveq	#95,d1
	bsr	cr_modelights
	bsr	mouseshow
	clr.w	ct2_mode_
	clr.w	ct2_index
	bsr	cr_inccursor
	move.w	cr_max,d0
	cmp.w	ct2_index,d0
	bge.s	.x
	bra	cr_deccursor
.go:	tst.w	ct2_index
	bne	cr_firstfree
.x:	rts
cr_setcargomode:
	cmp.w	#1,ct2_mode_
	beq.s	.go
	bsr	mousehide
	moveq	#95,d0
	moveq	#63,d1
	bsr	cr_modelights
	bsr	mouseshow
	move.w	#1,ct2_mode_
	clr.w	ct2_index
	bsr	cr_inccursor
	cmp.w	#250,ct2_index
	ble.s	.x
	bra	cr_deccursor
.go:	tst.w	ct2_index
	bne	cr_firstfree
.x:	rts
cr_setcolorcode:
	movem.l	d3-d4,-(sp)
	bsr	mousehide
	moveq	#95,d4
	not.b	cr_colorcode
	beq.s	.f
	moveq	#63,d4
.f:	moveq	#69,d0
	move.w	#125,d1
	moveq	#72,d2
	move.w	#125,d3
	bsr	ms_bar
	bsr	mouseshow
	st	GS_ANYCHANGE(a6)
	movem.l	(sp)+,d3-d4
	rts
cr_toggleq:
	movem.l	d3-d4,-(sp)
	bsr	mousehide
	not.b	cr_qmode
	moveq	#95,d4
	tst.b	cr_qmode
	beq.s	.f
	moveq	#63,d4
	st	GS_ANYCHANGE(a6)
.f:	moveq	#33,d0			; rows 6..14, x 33..34
	moveq	#6,d1
	moveq	#34,d2
	moveq	#14,d3
	bsr	ms_bar
	bsr	mouseshow
	movem.l	(sp)+,d3-d4
	rts
cr_setpartcursor:			; setpartcursor(index d0)
	tst.w	d0
	beq.s	.x
	move.w	d0,d2
	moveq	#1,d1
.l:	cmp.w	cr_max,d1
	bgt.s	.x
	move.w	d1,d0
	bsr	cr_info
	cmp.w	CREATION_INDEX(a0),d2
	beq.s	.f
	addq.w	#1,d1
	bra.s	.l
.f:	move.w	d1,ct2_index
	st	GS_ANYCHANGE(a6)
.x:	rts
cr_setinfocursor:			; setinfocursor(part d0)
	move.l	d3,-(sp)
	move.w	d0,d3
	tst.w	ct2_mode_
	bne	.x
	tst.w	ct2_index
	beq.s	.x
	tst.w	cr_lastinfo
	beq.s	.x
	moveq	#1,d1			; i: lastinfo's entry (i < maxcreation)
.l:	cmp.w	cr_max,d1
	bge.s	.f
	move.w	d1,d0
	bsr	cr_info
	move.w	cr_lastinfo,d0
	cmp.w	CREATION_INDEX(a0),d0
	beq.s	.f
	addq.w	#1,d1
	bra.s	.l
.f:	move.w	d1,d0
	bsr	cr_info
	add.w	d3,d3
	move.w	CREATION_PARTS-2(a0,d3.w),d3
	cmp.w	#ID_FIRST_ELEMENT,d3
	bge.s	.x
	move.w	cr_lastinfo,d0		; HistoryPush(lastinfo)
	cmp.w	#32,cr_histidx
	blt.s	.hp
	lea	cr_history,a0
	moveq	#31-1,d1
.hs:	move.w	2(a0),(a0)+
	dbf	d1,.hs
	move.w	d0,cr_history+31*2
	bra.s	.sp
.hp:	addq.w	#1,cr_histidx
	move.w	cr_histidx,d1
	add.w	d1,d1
	lea	cr_history-2,a0
	move.w	d0,0(a0,d1.w)
.sp:	move.w	d3,d0
	bsr	cr_setpartcursor
.x:	move.l	(sp)+,d3
	rts
cr_historypop:				; out d0
	move.w	cr_histidx,d1
	ble.s	.z
	add.w	d1,d1
	lea	cr_history-2,a0
	move.w	0(a0,d1.w),d0
	subq.w	#1,cr_histidx
	rts
.z:	moveq	#0,d0
	rts

cr_up:					; deccursor; if cargoindex < 1 then inccursor
	bsr	cr_deccursor
	tst.w	ct2_index
	bgt.s	.x
	bra	cr_inccursor
.x:	rts
cr_down:				; inccursor; past the list: deccursor
	bsr	cr_inccursor
	bsr	cr_outofrange
	beq.s	.x
	bra	cr_deccursor
.x:	rts

; findcreationmouse: columns (x ranges), each with its rows (y ranges) and actions
cr_findmouse:
	movem.l	d3-d4/a3,-(sp)
	bsr	kbd_mouse_status
	tst.b	d0
	beq	.x
	bsr	kbd_mouse_xy
	move.w	d0,d3
	move.w	d1,d4
	lea	cr_mtab,a3
.c:	move.w	(a3)+,d0		; x1 (-1: end)
	bmi.s	.i
	move.w	(a3)+,d1		; x2
	move.l	(a3)+,a0		; its row table
	cmp.w	d0,d3
	blt.s	.c
	cmp.w	d1,d3
	bgt.s	.c
.r:	move.w	(a0)+,d0		; y1 (-1: end)
	bmi.s	.i
	move.w	(a0)+,d1
	move.l	(a0)+,a1
	cmp.w	d0,d4
	blt.s	.r
	cmp.w	d1,d4
	bgt.s	.r
	move.w	d3,d0
	jsr	(a1)
.i:	clr.w	GS_IDLETIME(a6)
.x:	movem.l	(sp)+,d3-d4/a3
	rts
; the actions (d0 = mouse.x)
cr_m_inc:
	bra	cr_down
cr_m_f1:
	moveq	#1,d0
	bra	cr_setfilter
cr_m_f2:
	moveq	#2,d0
	bra	cr_setfilter
cr_m_f3:
	moveq	#3,d0
	bra	cr_setfilter
cr_m_color70:				; (only right of x 70)
	cmp.w	#70,d0
	ble.s	.x
	bra	cr_setcolorcode
.x:	rts
cr_m_done:
	st	GS_DONE(a6)
	rts
cr_m_i1:
	moveq	#1,d0
	bra	cr_setinfocursor
cr_m_i2:
	moveq	#2,d0
	bra	cr_setinfocursor
cr_m_i3:
	moveq	#3,d0
	bra	cr_setinfocursor
cr_m_go1:
	moveq	#1,d0
	bra	cr_go
cr_m_go2:
	moveq	#2,d0
	bra	cr_go
cr_m_go3:
	moveq	#3,d0
	bra	cr_go
cr_m_hist:
	bsr	cr_historypop
	bra	cr_setpartcursor

cr_processkey:
	bsr	kbd_readkey
	tst.b	d0
	beq	.ext
	cmp.b	#'a',d0
	blo.s	.u
	cmp.b	#'z',d0
	bhi.s	.u
	sub.b	#32,d0
.u:	cmp.b	#'1',d0
	blt.s	.k1
	cmp.b	#'3',d0
	bgt.s	.k1
	sub.b	#'0',d0
	ext.w	d0
	bsr	cr_setfilter
	bra	.x
.k1:	cmp.b	#'?',d0
	beq.s	.q
	cmp.b	#'/',d0
	bne.s	.k2
.q:	bsr	cr_toggleq
	bra	.x
.k2:	cmp.b	#27,d0
	bne.s	.k3
	st	GS_DONE(a6)
	bra	.x
.k3:	moveq	#1,d1
	cmp.b	#'Q',d0
	beq.s	.go
	moveq	#2,d1
	cmp.b	#'W',d0
	beq.s	.go
	moveq	#3,d1
	cmp.b	#'E',d0
	beq.s	.go
	cmp.b	#'C',d0
	bne.s	.k4
	bsr	cr_setcolorcode
	bra	.x
.k4:	cmp.b	#'`',d0			; bossmode
	bne.s	.k4b
	bsr	bossmode
	bra	.x
.k4b:	cmp.b	#13,d0			; (#10 heap stats: not on the ST)
	bne.s	.x
	tst.w	ct2_mode_
	bne.s	.cm
	bsr	cr_setdevicemode
	bra.s	.x
.cm:	bsr	cr_setcargomode
	bra.s	.x
.go:	move.w	d1,d0
	bsr	cr_go
	bra.s	.x
.ext:	bsr	kbd_readkey
	cmp.b	#80,d0
	bne.s	.e1
	bsr	cr_down
	bra.s	.x
.e1:	cmp.b	#72,d0
	bne.s	.e2
	bsr	cr_up
	bra.s	.x
.e2:	moveq	#113,d1
	cmp.b	#81,d0
	beq.s	.mv
	moveq	#22,d1
	cmp.b	#73,d0
	beq.s	.mv
	cmp.b	#59,d0
	bne.s	.e3
	bsr	cr_setdevicemode
	bra.s	.x
.e3:	cmp.b	#60,d0
	bne.s	.x
	bsr	cr_setcargomode
	bra.s	.x
.mv:	move.w	d1,-(sp)		; move_mouse(mouse.x, y); findcursor
	bsr	kbd_mouse_xy
	move.w	(sp)+,d1
	bsr	kbd_mouse_move
	bsr	cr_findcursor
.x:	clr.w	GS_IDLETIME(a6)
	rts

; adjuststatlights: five little bars swinging with sin(t1 + a/2)
cr_adjuststatlights:
	movem.l	d3-d7,-(sp)
	FX87				; t1 := t1 + 0.45; if t1 = 6.28 then t1 := 0
	FLDG	GS_T1
	FLDX	gx_0_45
	bsr	fp_add
	FSTG	GS_T1
	FLDG	GS_T1
	FLDX	gx_6_28
	bsr	fp_cmp
	bne.s	.n
	clr.l	GS_T1(a6)
	clr.l	GS_T1+4(a6)
.n:	bsr	mousehide
	moveq	#0,d7			; a
.a:	FSSE				; j := abs(round(5*sin(t1 + a/2)))
	move.w	d7,d0
	bsr	fp_ldw
	FLDX	gx_0_5d
	bsr	fp_mul
	FLDG	GS_T1
	bsr	fp_add
	lea	cr_tmpd,a0
	bsr	fp_std
	FX87
	lea	cr_tmpd,a0
	bsr	fp_ldd
	bsr	fp_sin
	FLDI	5
	bsr	fp_mul
	bsr	fp_rnd
	FSSE
	tst.l	d0
	bpl.s	.ab
	neg.l	d0
.ab:	move.w	d0,d6			; j
	move.w	d6,cr_j
	moveq	#31,d0			; x := 31 - a
	sub.w	d7,d0
	move.w	d0,GS_X(a6)
	moveq	#0,d5			; i: 0..j: dec(x, 2); screen[134-i, a*3+219..220] := x
.i:	cmp.w	d6,d5
	bgt.s	.ie
	subq.w	#2,GS_X(a6)
	move.w	GS_X(a6),d2
	bsr	.px
	addq.w	#1,d5
	bra.s	.i
.ie:	cmp.w	#5,d6			; if j < 5: i := j to 5: 0
	bge.s	.na
	move.w	d6,d5
.z:	moveq	#0,d2
	bsr	.px
	addq.w	#1,d5
	cmp.w	#5,d5
	ble.s	.z
.na:	move.w	d5,cr_i
	addq.w	#1,d7
	cmp.w	#4,d7
	ble	.a
	move.w	d7,cr_a
	bsr	mouseshow
	movem.l	(sp)+,d3-d7
	rts
.px:	move.w	d7,d0			; screen[134-i, a*3+219] and +220 := d2
	mulu	#3,d0
	add.w	#219,d0
	move.w	#134,d1
	sub.w	d5,d1
	movem.w	d0-d2,-(sp)
	bsr	ms_pset
	movem.w	(sp)+,d0-d2
	addq.w	#1,d0
	bra	ms_pset

cr_readydata:
	movem.l	d3,-(sp)
	move.w	#TOTALCREATION-1,cr_max	; maxcreation (the last only after event 18)
	moveq	#18,d0
	bsr	chevent
	tst.w	d0
	beq.s	.m
	move.w	#TOTALCREATION,cr_max
.m:	bsr	mousehide
	moveq	#0,d0			; quicksavescreen(current)
	bsr	ms_snap
	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	lea	cr_fn_mod,a0		; playmod(true, COMPONT.MOD)
	bsr	playmod
	bsr	orc_dump		; loadscreen(tech1)
	lea	cr_mode,a0
	bsr	ms_load
	bcs	fatal
	bsr	cr_drawfilters2
	sf	GS_DONE(a6)
	BKCOL	0
	clr.w	cr_lastinfo
	clr.w	ct2_mode_
	clr.w	ct2_index
	move.l	GS_T1(a6),GS_OLDT1(a6)
	move.l	GS_T1+4(a6),GS_OLDT1+4(a6)
	TCOL	31
	tst.b	cr_read			; creation.dta and iteminfo.dta (read once)
	bne.s	.rd
	st	cr_read
	lea	cr_fn_create,a0
	lea	cr_create+CREATION_SIZEOF,a1
	move.l	#CREATEARRAY_SIZEOF,d0
	bsr	load_exact
	lea	cr_fn_item,a0
	lea	cr_iteminfo,a1
	move.l	#TOTALCREATION*II_SIZE,d0
	bsr	load_exact
.rd:	moveq	#63,d0
	moveq	#95,d1
	bsr	cr_modelights
	moveq	#95,d4			; the info light
	tst.b	cr_qmode
	beq.s	.ql
	moveq	#63,d4
.ql:	moveq	#33,d0
	moveq	#6,d1
	moveq	#34,d2
	moveq	#14,d3
	bsr	ms_bar
	tst.b	cr_colorcode
	beq.s	.cc
	moveq	#69,d0
	move.w	#125,d1
	moveq	#72,d2
	move.w	#125,d3
	moveq	#63,d4
	bsr	ms_bar
.cc:	clr.w	cr_viewteam
	bsr	cr_inccursor
	bsr	mouseshow
	movem.l	(sp)+,d3
	rts

cr_mainloop:
.l:	moveq	#8,d0
	bsr	fadestep
	bsr	cr_findmouse
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	cr_processkey
.nk:	addq.w	#1,GS_IDLETIME(a6)
	cmp.w	#MAXIDLE,GS_IDLETIME(a6)
	bne.s	.ni
	bsr	screensaver
.ni:	cmp.w	#8,GS_BATINDEX(a6)
	bge.s	.b0
	addq.w	#1,GS_BATINDEX(a6)
	bra.s	.st
.b0:	clr.w	GS_BATINDEX(a6)
	bsr	addtime2
.st:	bsr	cr_adjuststatlights
	move.w	cr_viewteam,d0
	ble.s	.at
	bsr	cr_displayteaminfo
	bra.s	.ch
.at:	bsr	cr_adjustteams
.ch:	tst.b	GS_ANYCHANGE(a6)
	beq.s	.dl
	tst.w	ct2_mode_
	bne.s	.dc
	bsr	cr_displaydevices
	bra.s	.dl
.dc:	bsr	cr_displaycargo
.dl:	move.w	GS_TSLICE(a6),d0	; delay(tslice*FADE_TSLICE_MUL_CARGCREAT)
	mulu	#FADE_MUL_CARGCREAT,d0
	bsr	delay
	tst.b	GS_DONE(a6)
	beq	.l
	rts

creation:
	movem.l	d3-d7/a3-a5,-(sp)
	tst.b	cr_filters		; no filter on: all on
	bne.s	.r
	tst.b	cr_filters+1
	bne.s	.r
	tst.b	cr_filters+2
	bne.s	.r
	move.b	#1,cr_filters
	move.b	#1,cr_filters+1
	move.b	#1,cr_filters+2
.r:	bsr	cr_readydata
	bsr	cr_displaydevices
	bsr	cr_mainloop
	bsr	ct2_removedata
	movem.l	(sp)+,d3-d7/a3-a5
	rts

	section	data
; findcreationmouse's columns: x1, x2, row table; rows: y1, y2, action
cr_mtab:
	dc.w	10,19
	dc.l	.r1
	dc.w	20,31
	dc.l	.r2
	dc.w	32,37
	dc.l	.r3
	dc.w	38,48
	dc.l	.r4
	dc.w	49,92
	dc.l	.r5
	dc.w	93,99
	dc.l	.r6
	dc.w	100,110
	dc.l	.r7
	dc.w	120,125
	dc.l	.r8
	dc.w	130,151
	dc.l	.r9
	dc.w	152,212
	dc.l	.r10
	dc.w	221,299
	dc.l	.r11
	dc.w	-1
.r1:	dc.w	3,10
	dc.l	cr_up
	dc.w	11,18
	dc.l	cr_m_inc
	dc.w	22,118
	dc.l	cr_findcursor
	dc.w	122,129
	dc.l	cr_m_f1
	dc.w	133,140
	dc.l	cr_m_f2
	dc.w	144,151
	dc.l	cr_m_f3
	dc.w	-1
.r2:	dc.w	3,18
	dc.l	cr_toggleq
	dc.w	22,118
	dc.l	cr_findcursor
	dc.w	123,129
	dc.l	cr_m_f1
	dc.w	133,140
	dc.l	cr_m_f2
	dc.w	144,151
	dc.l	cr_m_f3
	dc.w	-1
.r3:	dc.w	22,118
	dc.l	cr_findcursor
	dc.w	122,129
	dc.l	cr_m_f1
	dc.w	133,140
	dc.l	cr_m_f2
	dc.w	144,151
	dc.l	cr_m_f3
	dc.w	-1
.r4:	dc.w	3,10
	dc.l	cr_setdevicemode
	dc.w	11,18
	dc.l	cr_setcargomode
	dc.w	22,118
	dc.l	cr_findcursor
	dc.w	122,129
	dc.l	cr_m_f1
	dc.w	133,140
	dc.l	cr_m_f2
	dc.w	144,151
	dc.l	cr_m_f3
	dc.w	-1
.r5:	dc.w	3,10
	dc.l	cr_setdevicemode
	dc.w	11,18
	dc.l	cr_setcargomode
	dc.w	22,118
	dc.l	cr_findcursor
	dc.w	122,129
	dc.l	cr_m_color70
	dc.w	-1
.r6:	dc.w	22,118
	dc.l	cr_findcursor
	dc.w	122,129
	dc.l	cr_setcolorcode
	dc.w	-1
.r7:	dc.w	3,18
	dc.l	cr_m_done
	dc.w	22,118
	dc.l	cr_findcursor
	dc.w	122,129
	dc.l	cr_setcolorcode
	dc.w	-1
.r8:	dc.w	44,49
	dc.l	cr_m_i1
	dc.w	65,70
	dc.l	cr_m_i2
	dc.w	86,91
	dc.l	cr_m_i3
	dc.w	-1
.r9:	dc.w	40,53
	dc.l	cr_m_i1
	dc.w	61,74
	dc.l	cr_m_i2
	dc.w	82,95
	dc.l	cr_m_i3
	dc.w	-1
.r10:	dc.w	40,53
	dc.l	cr_m_i1
	dc.w	61,74
	dc.l	cr_m_i2
	dc.w	82,95
	dc.l	cr_m_i3
	dc.w	120,128
	dc.l	cr_m_go1
	dc.w	130,138
	dc.l	cr_m_go2
	dc.w	140,148
	dc.l	cr_m_go3
	dc.w	-1
.r11:	dc.w	59,72
	dc.l	cr_m_hist
	dc.w	-1
cr_mode:	dc.b	"TECH1",0
cr_fn_mod:	dc.b	"SOUND",92,"COMPONT.MOD",0
cr_fn_create:	dc.b	"DATA",92,"CREATION.DTA",0
cr_fn_item:	dc.b	"DATA",92,"ITEMINFO.DTA",0
cr_t_range:	dc.b	8," Range: "
cr_t_kkm:	dc.b	4," KKM"
cr_t_energy:	dc.b	7,"Energy:"
cr_t_gw:	dc.b	3," GW"
cr_t_damage:	dc.b	7,"Damage:"
cr_t_gj:	dc.b	3," GJ"
cr_t_fab:	dc.b	27,"Fabricated Material        "
cr_t_unk:	dc.b	27,"Unknown Alien Artifact     "
	even
gx_0_5d:	dc.w	$3ffe		; 0.5 (exact; the a/2 of adjuststatlights: a*0.5 on SSE)
	dc.l	$80000000,$00000000
cr_filters:	dc.b	1,1,1		; (the unit's initialisation: filters, qmode, colorcode)
cr_qmode:	dc.b	$ff
cr_colorcode:	dc.b	$ff
	even
	section	bss
cr_create:	ds.b	(TOTALCREATION+2)*CREATION_SIZEOF	; [0] and [124] stay zero
cr_iteminfo:	ds.b	TOTALCREATION*II_SIZE
cr_ii:		ds.b	II_SIZE		; iteminfo^
cr_history:	ds.w	32
cr_histidx:	ds.w	1
cr_tmpd:	ds.l	2
cr_max:		ds.w	1		; maxcreation
cr_viewteam:	ds.w	1
cr_lastinfo:	ds.w	1
cr_i:		ds.w	1
cr_j:		ds.w	1
cr_a:		ds.w	1
cr_sn:		ds.b	22
cr_s1:		ds.b	32
cr_s2:		ds.b	64
cr_drawit:	ds.b	1
cr_read:	ds.b	1
	even
	section	text
