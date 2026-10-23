; trade.s - comm2.pas trade for MAIN.PRG: bartering with an alien race (conversation event
; 20001). The lower part of the screen (rows 111-199) becomes trade.cpr's panel: the aliens'
; goods on the left, barter for one, offer cargo (each item's worth from its parts), accept
; when the offer is worth enough, reject to take it back. The alien keeps animating above.
; The band design of the race's screen (COMAn/COMGn) covers the panel too (tools/mkcomm.py).
;
; trade                                                 trashes: d0-d2/a0-a2

	section	text
trade:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	td_readydata
	bsr	td_mainloop
	bsr	td_removedata
	movem.l	(sp)+,d3-d7/a3-a5
	rts

td_readydata:
	moveq	#1,d0			; wait(1)
	bsr	wait
	bsr	orc_dump		; loadscreen(trade, backgr)
	bsr	mem_mark
	move.l	d0,td_mark
	move.l	#89*320,d0		; (the shown rows 111-199 kept for removedata2)
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,td_save
	move.l	#64000,d0		; trade.cpr (chunky; no palette)
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,a3
	move.w	#111,d1
	moveq	#0,d0
	bsr	ms_addr
	move.l	td_save,a1
	move.w	#89*320/4-1,d0
.sv:	move.l	(a0)+,(a1)+
	dbf	d0,.sv
	lea	td_s_trade,a0
	move.l	a3,a1
	bsr	cm_loadchk
	move.w	#111,d1			; scrto_move(backgr^[111], screen[111, 0], (200-111)*320)
	moveq	#0,d0
	bsr	ms_addr
	move.l	a3,a1
	add.l	#111*320,a1
	move.w	#89*320/4-1,d0
.cp:	move.l	(a1)+,(a0)+
	dbf	d0,.cp
	moveq	#0,d0
	move.w	#111,d1
	move.w	#319,d2
	move.w	#199,d3
	bsr	ms_dirty
	bsr	orc_dump		; loadscreen(current3, backgr)
	bsr	mouseshow
	clr.w	td_mode
	move.w	#1,td_tradeindex
	clr.w	td_cargoindex
	sf	td_done
	move.l	#CREATEARRAY_SIZEOF,d0	; new(cr): creation.dta
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,td_cr
	move.l	a0,a1
	lea	fn_creation,a0
	move.l	#CREATEARRAY_SIZEOF,d0
	bsr	fil_load
	bcs	fatal
	lea	td_alienstuff,a0	; fillchar(alienstuff^, 0)
	moveq	#20-1,d0
.z:	clr.w	(a0)+
	dbf	d0,.z
	moveq	#13,d0			; for j := 1 to 8+random(13)
	bsr	mt_random
	addq.w	#8,d0
	move.w	d0,d7
	lea	td_alienstuff,a3
	cmp.w	#1007,GS_ALIEN+ALIEN_ID(a6)
	bne.s	.g
.junk:	move.w	#ID_WORTHLESS_JUNK,(a3)+
	subq.w	#1,d7
	bne.s	.junk
	bra.s	.dl
.g:	moveq	#5,d0			; random(5) = 0 and hi(techmin) >= 4: a component
	bsr	mt_random
	tst.w	d0
	bne.s	.g2
	cmp.b	#4,GS_ALIEN+ALIEN_TECHMIN(a6)
	blo.s	.g2
	moveq	#19,d0
	bsr	mt_random
	add.w	#ID_UNKNOWN_COMPONENT+1,d0
	bra.s	.gs
.g2:	cmp.w	#9,GS_ALIEN+ALIEN_CONINDEX(a6)	; the Guild: random(4) = 0: an upgrade kit
	bne.s	.g3
	moveq	#4,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.g3
	moveq	#5,d0
	bsr	mt_random
	add.w	#ID_REINFORCE_HULL,d0
	bra.s	.gs
.g3:	moveq	#19,d0			; else a material
	bsr	mt_random
	add.w	#ID_UNKNOWN_MATERIAL+1,d0
.gs:	move.w	d0,(a3)+
	subq.w	#1,d7
	bne.s	.g
.dl:	bra	td_displayleftlist

td_removedata:
	bsr	mousehide
	bsr	orc_dump		; loadscreen(current2, backgr)
	move.w	#111,d1			; the rows from before
	moveq	#0,d0
	bsr	ms_addr
	move.l	td_save,a1
	move.w	#89*320/4-1,d0
.cp:	move.l	(a1)+,(a0)+
	dbf	d0,.cp
	moveq	#0,d0
	move.w	#111,d1
	move.w	#319,d2
	move.w	#199,d3
	bsr	ms_dirty
	bsr	orc_dump		; loadscreen(current3, backgr)
	move.w	#3,GS_BKCOLOR(a6)
	move.l	td_mark,d0
	bra	mem_release

; a0 = cargo[] record of item d0 (searched from 1, as the original)
td_cargorec:
	lea	GS_CARGO(a6),a0
.l:	cmp.w	CARGO_INDEX(a0),d0
	beq.s	.x
	lea	CARGO_SIZEOF(a0),a0
	bra.s	.l
.x:	rts

; rows d0..d1 of x d2 .. d2+d3-1 in 0
td_clear:
	movem.l	d3-d4,-(sp)
	exg	d0,d2			; x1, y1, x2, y2
	exg	d1,d3
	move.w	d1,d4			; (width)
	move.w	d2,d1
	move.w	d0,d2
	add.w	d4,d2
	subq.w	#1,d2
	moveq	#0,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
	rts

; the cargo slot item test: d0 = ship.cargo[x]; Z clear = shown (0 < c < ID_ARTIFACT_OFFSET)
td_shown:
	tst.w	d0
	ble.s	.no
	cmp.w	#ID_ARTIFACT_OFFSET,d0
	bge.s	.no
	moveq	#1,d0
	rts
.no:	moveq	#0,d0
	rts

; a0 = ship.cargo[x] slot address for d0 (1-250; 0 = the word before: ship.orbiting)
td_slot:
	add.w	d0,d0
	lea	GS_SHIP+SHIP_CARGO-2(a6),a0
	add.w	d0,a0
	rts

; one line of the left list in cargo mode: slot x d3 at row y d4 (140+y*6)
td_cargoline:
	movem.l	d5/a3,-(sp)
	move.w	d3,d0
	bsr	td_slot
	move.w	(a0),d0
	bsr	td_cargorec
	move.l	a0,a3
	move.w	d3,d0			; str(numcargo:3) + ' ' + name
	add.w	d0,d0
	lea	GS_SHIP+SHIP_NUMCARGO-2(a6),a0
	move.w	0(a0,d0.w),d0
	lea	td_s,a0
	moveq	#3,d1
	bsr	td_str
	lea	td_s,a0
	moveq	#0,d0
	move.b	(a0),d0
	move.b	#' ',1(a0,d0.w)
	addq.b	#1,(a0)
	lea	CARGO_NAME(a3),a1
	bsr	pstr_cat
	lea	td_s,a0
	moveq	#0,d0
	move.w	d4,d1
	bsr	td_row
	bsr	printxy
	move.w	CARGO_INDEX(a3),d0	; ' ' + str(getworth) at 115 - 5*length
	bsr	td_getworth
	lea	td_s2+1,a0
	move.b	#' ',(a0)
	lea	td_s,a0
	moveq	#0,d1
	bsr	td_str
	moveq	#0,d5
	move.b	td_s,d5
	lea	td_s2,a0
	move.b	#1,(a0)
	lea	td_s,a1
	bsr	pstr_cat
	move.w	d5,d0
	mulu	#5,d0
	neg.w	d0
	add.w	#115,d0
	move.w	d4,d1
	bsr	td_row
	lea	td_s2,a0
	bsr	printxy
	movem.l	(sp)+,d5/a3
	rts
td_row:	mulu	#6,d1			; d1 := 140+y*6
	add.w	#140,d1
	rts

; str(d0:width d1) into a0 (Pascal string, right-aligned in at least width characters)
td_str:
	movem.l	d3/a3,-(sp)
	move.l	a0,a3
	move.w	d1,d3
	lea	td_num+8,a1
	move.w	d0,d2
	ext.l	d0
	bpl.s	.p
	neg.l	d0
.p:	moveq	#0,d1
.d:	divu	#10,d0
	swap	d0
	add.b	#'0',d0
	move.b	d0,-(a1)
	addq.w	#1,d1
	clr.w	d0
	swap	d0
	tst.w	d0
	bne.s	.d
	tst.w	d2
	bpl.s	.s
	move.b	#'-',-(a1)
	addq.w	#1,d1
.s:	move.w	d3,d0			; leading spaces
	sub.w	d1,d0
	ble.s	.c
	add.w	d0,d1
	subq.w	#1,d0
.sp:	move.b	#' ',-(a1)
	dbf	d0,.sp
.c:	move.b	d1,(a3)+
	subq.w	#1,d1
.cc:	move.b	(a1)+,(a3)+
	dbf	d1,.cc
	movem.l	(sp)+,d3/a3
	rts

td_displayleftlist:
	movem.l	d3-d4,-(sp)
	bsr	mousehide
	tst.w	td_mode
	bne	.cargo
	tst.w	td_tradeindex
	bne.s	.a
	moveq	#4,d2			; nothing: rows 141-183, x 4.. (121)
	moveq	#121,d3
	move.w	#141,d0
	move.w	#183,d1
	bsr	td_clear
	bra	.x
.a:	move.w	td_tradeindex,d3	; x := tradeindex; y := 2
	moveq	#2,d4
.al:	bsr	td_astuff
	tst.w	d0
	ble.s	.an
	move.w	#6,GS_BKCOLOR(a6)
	cmp.w	td_tradeindex,d3
	beq.s	.ab
	clr.w	GS_BKCOLOR(a6)
.ab:	addq.w	#1,d4
	bsr	td_aline
.an:	addq.w	#1,d3
	cmp.w	#6,d4
	beq.s	.ae
	cmp.w	#20,d3
	ble.s	.al
.ae:	bsr	td_cleartail
	move.w	td_tradeindex,d3	; x := tradeindex-1; y := 3; bkcolor := 0
	subq.w	#1,d3
	moveq	#3,d4
	clr.w	GS_BKCOLOR(a6)
.bl:	tst.w	d3
	ble.s	.bn
	bsr	td_astuff
	tst.w	d0
	ble.s	.bn
	subq.w	#1,d4
	bsr	td_aline
.bn:	subq.w	#1,d3
	tst.w	d4
	beq.s	.be
	tst.w	d3
	bpl.s	.bl
.be:	bsr	td_clearhead
	bra	.x
.cargo:	tst.w	td_cargoindex
	bne.s	.c
	moveq	#4,d2
	moveq	#121,d3
	move.w	#141,d0
	move.w	#183,d1
	bsr	td_clear
	bra	.x
.c:	move.w	td_cargoindex,d3
	moveq	#2,d4
.cl:	move.w	d3,d0
	bsr	td_slot
	move.w	(a0),d0
	bsr	td_shown
	beq.s	.cn
	move.w	#6,GS_BKCOLOR(a6)
	cmp.w	td_cargoindex,d3
	beq.s	.cb
	clr.w	GS_BKCOLOR(a6)
.cb:	addq.w	#1,d4
	bsr	td_cargoline
.cn:	addq.w	#1,d3
	cmp.w	#6,d4
	beq.s	.ce
	cmp.w	#250,d3
	ble.s	.cl
.ce:	bsr	td_cleartail
	move.w	td_cargoindex,d3
	subq.w	#1,d3
	moveq	#3,d4
	clr.w	GS_BKCOLOR(a6)
.dl:	tst.w	d3
	ble.s	.dn
	move.w	d3,d0
	bsr	td_slot
	move.w	(a0),d0
	bsr	td_shown
	beq.s	.dn
	subq.w	#1,d4
	bsr	td_cargoline
.dn:	subq.w	#1,d3
	tst.w	d4
	beq.s	.de
	tst.w	d3
	bpl.s	.dl
.de:	bsr	td_clearhead
.x:	bsr	mouseshow
	movem.l	(sp)+,d3-d4
	rts
; if y < 6: rows 147+y*6 .. 183 cleared (x 4, 121 wide); if y > 0 (the upper part): rows 141 ..
; 140+y*6
td_cleartail:
	cmp.w	#6,d4
	bge.s	.x
	move.w	d4,d0
	mulu	#6,d0
	add.w	#147,d0
	move.w	#183,d1
	moveq	#4,d2
	moveq	#121,d3
	movem.l	d3,-(sp)
	bsr	td_clear
	movem.l	(sp)+,d3
.x:	rts
td_clearhead:
	tst.w	d4
	ble.s	.x
	move.w	d4,d1
	mulu	#6,d1
	add.w	#140,d1
	move.w	#141,d0
	moveq	#4,d2
	move.l	d3,-(sp)
	moveq	#121,d3
	bsr	td_clear
	move.l	(sp)+,d3
.x:	rts
; d0 := alienstuff^[x d3] (x may be 0 or 21: the words around the array)
td_astuff:
	move.w	d3,d0
	add.w	d0,d0
	lea	td_alienstuff-2,a0
	move.w	0(a0,d0.w),d0
	rts
; printxy(0, 140+y*6, '    '+cargo[i].name) for alienstuff^[x d3], y d4
td_aline:
	bsr	td_astuff
	bsr	td_cargorec
	lea	CARGO_NAME(a0),a1
	lea	td_s,a0
	move.l	#$04202020,(a0)
	move.b	#' ',4(a0)
	bsr	pstr_cat
	moveq	#0,d0
	move.w	d4,d1
	bsr	td_row
	lea	td_s,a0
	bra	printxy

td_displayrightlist:
	movem.l	d3-d4,-(sp)
	bsr	mousehide
	tst.w	td_stuffindex
	bne.s	.a
	move.w	#194,d2
	moveq	#101,d3
	move.w	#141,d0
	move.w	#183,d1
	bsr	td_clear
	bra	.x
.a:	move.w	td_stuffindex,d3
	moveq	#2,d4
.al:	bsr	td_tstuff
	tst.w	d0
	ble.s	.an
	move.w	#6,GS_BKCOLOR(a6)
	cmp.w	td_stuffindex,d3
	beq.s	.ab
	clr.w	GS_BKCOLOR(a6)
.ab:	addq.w	#1,d4
	bsr	td_tline
.an:	addq.w	#1,d3
	cmp.w	#6,d4
	beq.s	.ae
	cmp.w	#20,d3
	ble.s	.al
.ae:	cmp.w	#6,d4
	bge.s	.h
	move.w	d4,d0
	mulu	#6,d0
	add.w	#147,d0
	move.w	#183,d1
	move.w	#194,d2
	move.l	d3,-(sp)
	moveq	#101,d3
	bsr	td_clear
	move.l	(sp)+,d3
.h:	move.w	td_stuffindex,d3
	subq.w	#1,d3
	moveq	#3,d4
	clr.w	GS_BKCOLOR(a6)
.bl:	tst.w	d3
	ble.s	.bn
	bsr	td_tstuff
	tst.w	d0
	ble.s	.bn
	subq.w	#1,d4
	bsr	td_tline
.bn:	subq.w	#1,d3
	tst.w	d4
	beq.s	.be
	tst.w	d3
	bpl.s	.bl
.be:	tst.w	d4
	ble.s	.x
	move.w	d4,d1
	mulu	#6,d1
	add.w	#140,d1
	move.w	#141,d0
	move.w	#194,d2
	moveq	#101,d3
	bsr	td_clear
.x:	bsr	mouseshow
	movem.l	(sp)+,d3-d4
	rts
td_tstuff:
	move.w	d3,d0
	add.w	d0,d0
	lea	td_tradestuff-2,a0
	move.w	0(a0,d0.w),d0
	rts
td_tline:				; printxy(190, 140+y*6, cargo[i].name)
	bsr	td_tstuff
	bsr	td_cargorec
	lea	CARGO_NAME(a0),a0
	move.w	#190,d0
	move.w	d4,d1
	bsr	td_row
	bra	printxy

; subcursor2 / addcursor2 / subcursor3 / addcursor3
td_cargook:				; slot d0: Z set = skipped (0 or > ID_LAST_ELEMENT)
	move.l	a0,-(sp)
	bsr	td_slot
	move.w	(a0),d0
	move.l	(sp)+,a0
	tst.w	d0
	beq.s	.x
	cmp.w	#ID_LAST_ELEMENT,d0
	bgt.s	.sk
	moveq	#1,d0
	rts
.sk:	moveq	#0,d0
.x:	rts
td_sub2:
	move.l	d3,-(sp)
	bsr.s	td_sub2_
	move.l	(sp)+,d3
	rts
td_sub2_:
	tst.w	td_mode
	bne.s	.c
	subq.w	#1,td_tradeindex
.a1:	move.w	td_tradeindex,d0
	ble.s	.a2
	move.w	d0,d3
	bsr	td_astuff
	tst.w	d0
	bne.s	.d
	subq.w	#1,td_tradeindex
	bra.s	.a1
.a2:	move.w	#1,td_tradeindex
.a3:	move.w	td_tradeindex,d3
	cmp.w	#21,d3
	bge.s	.a4
	bsr	td_astuff
	tst.w	d0
	bne.s	.d
	addq.w	#1,td_tradeindex
	bra.s	.a3
.a4:	clr.w	td_tradeindex
	bra.s	.d
.c:	subq.w	#1,td_cargoindex
.c1:	move.w	td_cargoindex,d0
	ble.s	.c2
	bsr	td_cargook
	bne.s	.d
	subq.w	#1,td_cargoindex
	bra.s	.c1
.c2:	move.w	#1,td_cargoindex
.c3:	move.w	td_cargoindex,d0
	cmp.w	#251,d0
	bge.s	.c4
	bsr	td_cargook
	bne.s	.d
	addq.w	#1,td_cargoindex
	bra.s	.c3
.c4:	clr.w	td_cargoindex
.d:	bra	td_displayleftlist

td_add2:
	move.l	d3,-(sp)
	bsr.s	td_add2_
	move.l	(sp)+,d3
	rts
td_add2_:
	tst.w	td_mode
	bne.s	.c
	addq.w	#1,td_tradeindex
.a1:	move.w	td_tradeindex,d3
	cmp.w	#21,d3
	bge.s	.a2
	bsr	td_astuff
	tst.w	d0
	bne.s	.d
	addq.w	#1,td_tradeindex
	bra.s	.a1
.a2:	move.w	#20,td_tradeindex
.a3:	move.w	td_tradeindex,d3
	ble.s	.d
	bsr	td_astuff
	tst.w	d0
	bne.s	.d
	subq.w	#1,td_tradeindex
	bra.s	.a3
.c:	addq.w	#1,td_cargoindex
.c1:	move.w	td_cargoindex,d0
	cmp.w	#251,d0
	bge.s	.c2
	bsr	td_cargook
	bne.s	.d
	addq.w	#1,td_cargoindex
	bra.s	.c1
.c2:	move.w	#250,td_cargoindex
.c3:	move.w	td_cargoindex,d0
	ble.s	.d
	bsr	td_cargook
	bne.s	.d
	subq.w	#1,td_cargoindex
	bra.s	.c3
.d:	bra	td_displayleftlist

td_sub3:
	move.l	d3,-(sp)
	bsr.s	td_sub3_
	move.l	(sp)+,d3
	rts
td_sub3_:
	tst.w	td_mode
	beq.s	.x
	subq.w	#1,td_stuffindex
.a1:	move.w	td_stuffindex,d3
	ble.s	.a2
	bsr	td_tstuff
	tst.w	d0
	bne.s	.d
	subq.w	#1,td_stuffindex
	bra.s	.a1
.a2:	move.w	#1,td_stuffindex
.a3:	move.w	td_stuffindex,d3
	cmp.w	#21,d3
	bge.s	.a4
	bsr	td_tstuff
	tst.w	d0
	bne.s	.d
	addq.w	#1,td_stuffindex
	bra.s	.a3
.a4:	clr.w	td_stuffindex
.d:	bra	td_displayrightlist
.x:	rts

td_add3:
	move.l	d3,-(sp)
	bsr.s	td_add3_
	move.l	(sp)+,d3
	rts
td_add3_:
	tst.w	td_mode
	beq.s	.x
	addq.w	#1,td_stuffindex
.a1:	move.w	td_stuffindex,d3
	cmp.w	#21,d3
	bge.s	.a2
	bsr	td_tstuff
	tst.w	d0
	bne.s	.d
	addq.w	#1,td_stuffindex
	bra.s	.a1
.a2:	move.w	#20,td_stuffindex
.a3:	move.w	td_stuffindex,d3
	ble.s	.d
	bsr	td_tstuff
	tst.w	d0
	bne.s	.d
	subq.w	#1,td_stuffindex
	bra.s	.a3
.d:	bra	td_displayrightlist
.x:	rts

; getworth(item d0) -> d0.w
td_getworth:
	movem.l	d3-d5/a3,-(sp)
	move.w	d0,d3
	moveq	#0,d4			; worth
	moveq	#0,d5			; i (1: made of parts)
	cmp.w	#ID_UNKNOWN_COMPONENT,d3
	bne.s	.u1
	moveq	#27,d4
.u1:	cmp.w	#ID_UNKNOWN_MATERIAL,d3
	bne.s	.u2
	moveq	#9,d4
.u2:	cmp.w	#ID_WORTHLESS_JUNK,d3
	bne.s	.u3
	moveq	#1,d4
.u3:	cmp.w	#ID_FIRST_ELEMENT,d3
	blt.s	.w
	cmp.w	#ID_LAST_ELEMENT,d3
	bgt.s	.w
	moveq	#3,d4
	bra.s	.do
.w:	moveq	#4,d1
	cmp.w	#ID_DIRK,d3
	blt.s	.do
	cmp.w	#1499,d3
	ble.s	.pt
	moveq	#6,d1
	cmp.w	#ID_LAST_SHIELD,d3
	ble.s	.pt
	moveq	#4,d1
	cmp.w	#ID_NOTHING,d3
	blt.s	.do
	cmp.w	#2999,d3
	ble.s	.pt
	moveq	#3,d1
	cmp.w	#3001,d3
	blt.s	.do
	cmp.w	#3999,d3
	ble.s	.pt
	moveq	#2,d1
	cmp.w	#4001,d3
	blt.s	.do
	cmp.w	#ID_WORTHLESS_JUNK,d3
	beq.s	.do
	cmp.w	#4999,d3
	bgt.s	.do
.pt:	move.w	d1,d4
	move.l	td_cr,a3		; while cr^[i].index <> item do inc(i)
.f:	cmp.w	CREATION_INDEX(a3),d3
	beq.s	.ff
	lea	CREATION_SIZEOF(a3),a3
	bra.s	.f
.ff:	moveq	#3-1,d5
	lea	CREATION_PARTS(a3),a3
.p:	move.w	(a3)+,d0
	cmp.w	#ID_FIRST_ELEMENT,d0
	blt.s	.r
	addq.w	#1,d4
	bra.s	.pn
.r:	bsr	td_getworth
	add.w	d0,d4
.pn:	dbf	d5,.p
.do:	move.w	d4,d0
	movem.l	(sp)+,d3-d5/a3
	rts

td_barterfor:
	movem.l	d3-d4,-(sp)
	cmp.w	#1,td_mode
	beq	.x
	tst.w	td_tradeindex
	beq	.x
	move.w	#1,td_mode
	tst.w	td_cargoindex
	bne.s	.c
	bsr	td_add2
.c:	move.w	td_tradeindex,d3
	bsr	td_astuff
	bsr	td_cargorec
	lea	CARGO_NAME(a0),a1	; item_name := cargo[i].name
	lea	td_s3,a0
	moveq	#0,d0
	move.b	(a1),d0
.cn:	move.b	(a1)+,(a0)+
	dbf	d0,.cn
	bsr	mousehide
	bsr	td_displayleftlist
	bsr	mouseshow
	lea	td_tradestuff,a0	; fillchar(tradestuff^, 0)
	moveq	#20-1,d0
.z:	clr.w	(a0)+
	dbf	d0,.z
	move.w	td_tradeindex,d3
	bsr	td_astuff
	bsr	td_getworth
	move.w	d0,d4
	move.w	GS_ALIEN+ALIEN_ANGER(a6),d0	; alienworth := round(alienworth*0.33*i)
	move.w	GS_ALIEN+ALIEN_CONGENIALITY(a6),d1
	bsr	calc_anger
	move.w	d0,d3
	FX87
	move.w	d4,d0
	bsr	fp_ldw
	FLDX	gx_0_33
	bsr	fp_mul
	move.w	d3,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	FSSE
	move.w	d0,td_alienworth
	bsr	mousehide		; printxy(93, 127, item_name + '(' + str(alienworth) + ')')
	lea	td_s3,a0
	moveq	#0,d0
	move.b	(a0),d0
	move.b	#'(',1(a0,d0.w)
	addq.b	#1,(a0)
	move.w	td_alienworth,d0
	lea	td_s,a0
	moveq	#0,d1
	bsr	td_str
	lea	td_s3,a0
	lea	td_s,a1
	bsr	pstr_cat
	lea	td_s3,a0
	moveq	#0,d0
	move.b	(a0),d0
	move.b	#')',1(a0,d0.w)
	addq.b	#1,(a0)
	moveq	#93,d0
	moveq	#127,d1
	bsr	printxy
	bsr	mouseshow
	clr.w	td_tradeworth
.x:	movem.l	(sp)+,d3-d4
	rts

td_reject:
	movem.l	d3,-(sp)
	tst.w	td_mode
	beq.s	.x
	clr.w	td_mode
	bsr	mousehide
	bsr	td_clroffer
	lea	td_tradestuff,a0	; addcargo2 each offered item back
	moveq	#0,d3
.l:	move.w	0(a0,d3.w),d0
	ble.s	.n
	move.l	a0,-(sp)
	st	d1
	bsr	addcargo2
	move.l	(sp)+,a0
.n:	addq.w	#2,d3
	cmp.w	#40,d3
	bne.s	.l
	BAR	131,158,187,164,0
	bsr	td_displayleftlist
	bsr	mouseshow
.x:	movem.l	(sp)+,d3
	rts
td_clroffer:				; rows 128-133 x 97-217, rows 141-183 x 194-294 in 0
	BAR	97,128,217,133,0
	BAR	194,141,294,183,0
	rts

td_accept:
	tst.w	td_mode
	beq	.x
	move.w	td_tradeworth,d0
	cmp.w	td_alienworth,d0
	blt	.x
	tst.w	td_tradeindex
	beq	.x
	movem.l	d3,-(sp)
	move.w	td_tradeindex,d3
	bsr	td_astuff
	lea	.kits,a0
.k:	move.w	(a0)+,d1
	bmi.s	.one
	cmp.w	d1,d0
	beq.s	.kit
	addq.l	#6,a0
	bra.s	.k
.kit:	moveq	#3-1,d3
.kl:	move.w	(a0)+,d0
	move.l	a0,-(sp)
	st	d1
	bsr	addcargo
	move.l	(sp)+,a0
	dbf	d3,.kl
	bra.s	.dn
.one:	st	d1
	bsr	addcargo
.dn:	move.w	td_tradeindex,d3
	add.w	d3,d3
	lea	td_alienstuff-2,a0
	clr.w	0(a0,d3.w)
	clr.w	td_mode
	bsr	td_sub2
	bsr	mousehide
	bsr	td_clroffer
	BAR	131,158,187,164,0
	bsr	td_displayleftlist
	bsr	mouseshow
	movem.l	(sp)+,d3
.x:	rts
.kits:	dc.w	ID_REINFORCE_HULL,ID_TORQUE_STANCHION,ID_METAL_WEAVE,ID_GUIDANCE_STRUT
	dc.w	ID_INCREASE_THRUST,ID_DIRK,ID_DIRK,ID_PULSE_LOOM
	dc.w	ID_ADD_CARGO_SPACE,ID_GUIDANCE_STRUT,ID_STRATAMOUNT,ID_TORQUE_STANCHION
	dc.w	ID_INSTALL_GUN_NODE,ID_STASIS_GENERATOR,ID_STASIS_GENERATOR,ID_THYNNE_VORTEX
	dc.w	ID_MIND_ENHANCERS,ID_PROTO_NUTRIENT,ID_CYBERPLASM,ID_BIOSYNTH
	dc.w	-1

td_showworth:
	movem.l	d3-d5,-(sp)
	moveq	#57,d4			; num
	move.w	td_tradeworth,d0
	cmp.w	td_alienworth,d0
	bge.s	.ge
	moveq	#37,d5			; num := round(tradeworth/alienworth*57)
	FSSE
	bsr	fp_ldw
	move.w	td_alienworth,d0
	bsr	fp_ldw
	bsr	fp_div
	FLDI	57
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,d4
	bra.s	.dr
.ge:	moveq	#47,d5
	move.w	td_alienworth,d1
	add.w	d1,d1
	cmp.w	d1,d0
	bge.s	.dr
	moveq	#33,d5
.dr:	bsr	mousehide
	move.w	#158,d3
.r:	move.w	#131,d0			; scr_fillchar(screen[i, 131], num, c); the rest 0
	move.w	d3,d1
	bsr	ms_addr
	move.w	d4,d0
	bra.s	.f1
.f:	move.b	d5,(a0)+
.f1:	dbf	d0,.f
	cmp.w	#57,d4
	bge.s	.n
	move.w	#57,d0
	sub.w	d4,d0
	bra.s	.z1
.z:	clr.b	(a0)+
.z1:	dbf	d0,.z
.n:	addq.w	#1,d3
	cmp.w	#164,d3
	ble.s	.r
	move.w	#131,d0
	move.w	#158,d1
	move.w	#187,d2
	move.w	#164,d3
	bsr	ms_dirty
	bsr	mouseshow
	movem.l	(sp)+,d3-d5
	rts

td_addstuff:
	movem.l	d3,-(sp)
	tst.w	td_mode
	beq.s	.x
	move.w	td_cargoindex,d0
	beq.s	.x
	lea	td_tradestuff,a0	; the first free offer slot
	moveq	#1,d3
.f:	tst.w	(a0)
	beq.s	.ff
	addq.l	#2,a0
	addq.w	#1,d3
	cmp.w	#21,d3
	bne.s	.f
	bra.s	.x
.ff:	move.l	a0,-(sp)
	move.w	td_cargoindex,d0
	bsr	td_slot
	move.l	(sp)+,a1
	move.w	(a0),(a1)		; tradestuff^[i] := ship.cargo[cargoindex]
	move.w	(a0),d0
	bsr	td_getworth
	add.w	d0,td_tradeworth
	move.w	td_cargoindex,d0
	add.w	d0,d0
	lea	GS_SHIP+SHIP_NUMCARGO-2(a6),a0
	subq.w	#1,0(a0,d0.w)
	bne.s	.s
	move.w	td_cargoindex,d0
	bsr	td_slot
	clr.w	(a0)
	move.w	d3,-(sp)
	bsr	td_sub2
	move.w	(sp)+,d3
.s:	move.w	d3,td_stuffindex
	bsr	td_displayrightlist
	bsr	td_showworth
.x:	movem.l	(sp)+,d3
	rts

td_removestuff:
	movem.l	d3,-(sp)
	tst.w	td_mode
	beq.s	.x
	move.w	td_stuffindex,d3
	beq.s	.x
	bsr	td_tstuff
	st	d1
	bsr	addcargo
	move.w	td_stuffindex,d3
	bsr	td_tstuff
	bsr	td_getworth
	sub.w	d0,td_tradeworth
	move.w	td_stuffindex,d3
	add.w	d3,d3
	lea	td_tradestuff-2,a0
	clr.w	0(a0,d3.w)
	bsr	td_sub3
	tst.w	td_cargoindex
	bne.s	.d
	bsr	td_add2
.d:	bsr	td_displayleftlist
	bsr	td_showworth
.x:	movem.l	(sp)+,d3
	rts

; findleftmouse / findrightmouse: y := -3+((mouse.y-141) div 6) steps of the cursor
td_findlr:
	movem.l	d3-d4,-(sp)
	move.l	a0,d4			; (the step routines: up in a0, down in a1)
	move.l	a1,-(sp)
	move.w	d1,d3
	sub.w	#141,d3
	ext.l	d3
	divs	#6,d3
	subq.w	#3,d3
.l:	tst.w	d3
	beq.s	.x
	bpl.s	.dn
	move.l	d4,a0
	jsr	(a0)
	addq.w	#1,d3
	bra.s	.l
.dn:	move.l	(sp),a0
	jsr	(a0)
	subq.w	#1,d3
	bra.s	.l
.x:	addq.l	#4,sp
	movem.l	(sp)+,d3-d4
	rts
td_findleft:
	lea	td_sub2,a0
	lea	td_add2,a1
	bra.s	td_findlr
td_findright:
	lea	td_sub3,a0
	lea	td_add3,a1
	bra.s	td_findlr

td_findmouse:
	movem.l	d3-d4,-(sp)
	bsr	kbd_mouse_status
	tst.b	d0
	beq	.x
	bsr	kbd_mouse_xy
	move.w	d0,d3
	move.w	d1,d4
	lea	.tab,a0			; x ranges -> y ranges -> actions
.r:	move.w	(a0)+,d0
	bmi	.i
	move.w	(a0)+,d1
	move.w	(a0)+,d2		; offset of the y list
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
	move.w	d4,d1
	lea	.tab,a0
	add.w	d2,a0
	jsr	(a0)
.i:	clr.w	GS_IDLETIME(a6)
.x:	movem.l	(sp)+,d3-d4
	rts
.tab:	dc.w	21,90,.y1-.tab,4,20,.y2-.tab,91,124,.y2-.tab,130,139,.y3-.tab
	dc.w	149,171,.y4-.tab,179,188,.y5-.tab,229,246,.y6-.tab,247,261,.y7-.tab
	dc.w	262,265,.y8-.tab,266,297,.y9-.tab,194,228,.y10-.tab,309,319,.y11-.tab,-1
.y1:	dc.w	126,134,.bart-.tab,138,186,.left-.tab,-1
.y2:	dc.w	138,186,.left-.tab,-1
.y3:	dc.w	172,179,.s2-.tab,180,186,.a2-.tab,-1
.y4:	dc.w	149,155,.ad-.tab,167,173,.rm-.tab,-1
.y5:	dc.w	172,179,.s3-.tab,180,186,.a3-.tab,-1
.y6:	dc.w	126,134,.acc-.tab,138,186,.right-.tab,-1
.y7:	dc.w	104,111,.gi-.tab,126,134,.acc-.tab,138,186,.right-.tab,-1
.y8:	dc.w	105,110,.gi-.tab,138,186,.right-.tab,-1
.y9:	dc.w	126,134,.rej-.tab,138,186,.right-.tab,-1
.y10:	dc.w	138,186,.right-.tab,-1
.y11:	dc.w	154,170,.done-.tab,-1
.bart:	tst.w	td_mode
	bne.s	.rt
	bra	td_barterfor
.left:	bra	td_findleft
.s2:	bra	td_sub2
.a2:	bra	td_add2
.ad:	bra	td_addstuff
.rm:	bra	td_removestuff
.s3:	bra	td_sub3
.a3:	bra	td_add3
.acc:	bra	td_accept
.right:	bra	td_findright
.gi:	bra	getinfo
.rej:	bra	td_reject
.done:	st	td_done
.rt:	rts

td_processkey:
	bsr	kbd_readkey
	bsr	cm_upcase
	tst.b	d0
	bne.s	.a
	bsr	kbd_readkey
	cmp.b	#72,d0
	beq	td_sub2
	cmp.b	#80,d0
	beq	td_add2
	cmp.b	#73,d0
	beq	td_sub3
	cmp.b	#81,d0
	beq	td_add3
	bra.s	.x
.a:	cmp.b	#'A',d0
	beq	td_accept
	cmp.b	#'B',d0
	beq	td_barterfor
	cmp.b	#'R',d0
	beq	td_reject
	cmp.b	#'+',d0
	beq	td_addstuff
	cmp.b	#13,d0
	beq	td_addstuff
	cmp.b	#'-',d0
	beq	td_removestuff
	cmp.b	#27,d0
	bne.s	.x
	st	td_done
.x:	rts

td_mainloop:
.l:	bsr	td_findmouse
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	td_processkey
	clr.w	GS_IDLETIME(a6)
.nk:	bsr	cm_batindex
	bsr	animatealien
	move.w	GS_TSLICE(a6),d0	; delay(tslice*6)
	mulu	#6,d0
	bsr	delay
	tst.b	td_done
	beq.s	.l
	bra	td_reject

	section	data
td_s_trade:	dc.b	"TRADE",0
	even
	section	bss
td_mark:	ds.l	1
td_save:	ds.l	1
td_cr:		ds.l	1
td_mode:	ds.w	1
td_tradeindex:	ds.w	1
td_cargoindex:	ds.w	1
td_stuffindex:	ds.w	1
td_alienworth:	ds.w	1
td_tradeworth:	ds.w	1
td_done:	ds.b	1
	even
		ds.w	1		; (alienstuff^[0])
td_alienstuff:	ds.w	20
		ds.w	1		; ([21])
		ds.w	1		; (tradestuff^[0])
td_tradestuff:	ds.w	20
		ds.w	1
td_num:		ds.b	10
td_s:		ds.b	64
td_s2:		ds.b	64
td_s3:		ds.b	64
	even
	section	text
