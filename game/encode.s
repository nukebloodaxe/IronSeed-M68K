; encode.s - saveload.pas encodecrew / decodecrew (the crew's backup chips: ship.encodes) and
; weird.pas lifesupportfailure, for MAIN.PRG. Called from the cube (usecode.pas 47 encode, 50
; decode) and from psychometry's encode button (crew2.pas: encodecrew(181)).
;
; en_encodecrew  in: d0.w = text colour (26 or 181)   trashes: d0-d2/a0-a2
; en_decodecrew                                      trashes: d0-d2/a0-a2
; lifesupportfailure                                 trashes: d0-d2/a0-a2
; en_lifecheck   in: d0.w = 0 encode(26), 1 encode(181), 2 decode: damages[lifesupport] > 39 ->
;                lifesupportfailure, else the dialog

	section	text
en_lifecheck:
	cmp.b	#39,GS_SHIP+SHIP_DAMAGES+DMG_LIFESUPPORT-1(a6)
	bhi.s	lifesupportfailure
	cmp.w	#2,d0
	beq	en_decodecrew
	tst.w	d0
	beq.s	.e26
	move.w	#181,d0
	bra	en_encodecrew
.e26:	moveq	#26,d0
	bra	en_encodecrew

; weird.pas 1297
lifesupportfailure:
	moveq	#6,d0
	lea	en_t_life,a0
	bsr	showchar
	lea	GS_SHIP+SHIP_ENCODES(a6),a0
	moveq	#6-1,d0
.c:	clr.b	CREW_MEN(a0)
	clr.b	CREW_PHY(a0)
	clr.b	CREW_EMO(a0)
	lea	CREW_SIZEOF(a0),a0
	dbf	d0,.c
	rts

; saveload.pas 909 encodecrew(tc)
en_encodecrew:
	movem.l	d3-d7/a3,-(sp)
	move.w	d0,d7			; tc
	move.w	GS_TCOLOR(a6),-(sp)	; t, b
	move.w	GS_BKCOLOR(a6),-(sp)
	st	en_encoding
	bsr	mousehide
	moveq	#1,d0			; compressfile(current2)
	bsr	ms_snap
	move.w	d7,GS_TCOLOR(a6)
	moveq	#0,d6			; alt
	cmp.w	#31,d7
	ble.s	.a
	moveq	#38,d6
.a:	move.w	d6,en_alt
	bsr	en_frame
	moveq	#2,d4			; button(220,138,260,149, 2+alt)
	add.w	d6,d4
	move.w	#220,d0
	move.w	#138,d1
	move.w	#260,d2
	move.w	#149,d3
	bsr	mb_button
	moveq	#2,d4			; button(50,138,110,149, 2+alt)
	add.w	d6,d4
	moveq	#50,d0
	move.w	#138,d1
	moveq	#110,d2
	move.w	#149,d3
	bsr	mb_button
	moveq	#35,d0
	add.w	d6,d0
	move.w	d0,GS_BKCOLOR(a6)
	PXY	107,37,"Encode Crew Member:"
	moveq	#37,d0
	add.w	d6,d0
	move.w	d0,GS_BKCOLOR(a6)
	lea	GS_SHIP+SHIP_CREW(a6),a0	; displaycrew
	bsr	en_list
	PXY	51,140,"Encode All"
	bsr	en_mainloop
	move.w	d0,d5			; src
	cmp.w	#7,d5
	bge.s	.n7
	bsr	en_undocursor
	moveq	#35,d0
	add.w	d6,d0
	move.w	d0,GS_BKCOLOR(a6)
	PXY	107,37,"  Encode to Chip:  "
	moveq	#37,d0
	add.w	d6,d0
	move.w	d0,GS_BKCOLOR(a6)
	move.w	GS_TSLICE(a6),d0	; delay(tslice*10)
	mulu	#10,d0
	bsr	delay
	bsr	mousehide
	lea	GS_SHIP+SHIP_ENCODES(a6),a0	; displayencodes
	bsr	en_list
	bsr	en_mainloop
	cmp.w	#7,d0
	bge.s	.n7
	move.w	en_cursor,d0		; ship.encodes[cursor] := ship.crew[src]
	bsr	en_enc
	move.l	a0,a1
	move.w	d5,d0
	bsr	en_crew
	bsr	en_copy
.n7:	cmp.w	#8,d5			; src = 8: all six
	bne.s	.x
	lea	GS_SHIP+SHIP_CREW(a6),a0
	lea	GS_SHIP+SHIP_ENCODES(a6),a1
	move.w	#6*CREW_SIZEOF-1,d0
.ca:	move.b	(a0)+,(a1)+
	dbf	d0,.ca
.x:	bsr	mousehide
	bsr	orc_dump		; loadscreen(current2)
	moveq	#1,d0
	bsr	ms_unsnap
	bsr	mouseshow
	move.w	(sp)+,GS_BKCOLOR(a6)
	move.w	(sp)+,GS_TCOLOR(a6)
	movem.l	(sp)+,d3-d7/a3
	rts

; saveload.pas 951 decodecrew
en_decodecrew:
	movem.l	d3-d7/a3,-(sp)
	sf	en_encoding
	bsr	mousehide
	moveq	#0,d0			; compressfile(current)
	bsr	ms_snap
	move.w	#26,GS_TCOLOR(a6)
	clr.w	en_alt
	moveq	#0,d6
	bsr	en_frame
	moveq	#2,d4			; button(220,138,260,149,2)
	move.w	#220,d0
	move.w	#138,d1
	move.w	#260,d2
	move.w	#149,d3
	bsr	mb_button
	BKCOL	35
	PXY	107,37,"Decode Crew Member:"
	BKCOL	37
	lea	GS_SHIP+SHIP_ENCODES(a6),a0
	bsr	en_list
	bsr	en_mainloop
	cmp.w	#7,d0
	bge.s	.x
	move.w	en_cursor,d0		; the crew member with the chip's name gets the chip
	bsr	en_enc
	move.l	a0,a3
	moveq	#1,d3
.j:	move.w	d3,d0
	bsr	en_crew
	move.l	a0,a1
	move.l	a3,a2
	moveq	#0,d0			; (shortstrings: length and characters)
	move.b	(a2),d0
.cmp:	cmpm.b	(a1)+,(a2)+
	bne.s	.nj
	dbf	d0,.cmp
	move.l	a0,a1			; crew[j] := encodes[cursor]
	move.l	a3,a0
	bsr	en_copy
	bra.s	.x
.nj:	addq.w	#1,d3
	cmp.w	#6,d3
	ble.s	.j
.x:	bsr	mousehide
	bsr	orc_dump		; loadscreen(current)
	moveq	#0,d0
	bsr	ms_unsnap
	bsr	mouseshow
	movem.l	(sp)+,d3-d7/a3
	rts

; the box and the six rows: button(42,30,270,152,alt), button(50,33+a*15,260,44+a*15,2+alt)
; in: d6 = alt
en_frame:
	move.w	d6,d4
	moveq	#42,d0
	moveq	#30,d1
	move.w	#270,d2
	move.w	#152,d3
	bsr	mb_button
	moveq	#1,d5
.r:	moveq	#2,d4
	add.w	d6,d4
	move.w	d5,d1
	mulu	#15,d1
	add.w	#33,d1
	move.w	d1,d3
	add.w	#11,d3
	moveq	#50,d0
	move.w	#260,d2
	bsr	mb_button
	addq.w	#1,d5
	cmp.w	#6,d5
	ble.s	.r
	rts

; a0 = encodes or crew -> a0 = record d0 (1-6)
en_enc:	lea	GS_SHIP+SHIP_ENCODES-CREW_SIZEOF(a6),a0
	bra.s	en_rec
en_crew: lea	GS_SHIP+SHIP_CREW-CREW_SIZEOF(a6),a0
en_rec:	mulu	#CREW_SIZEOF,d0
	add.l	d0,a0
	rts
; a0 -> a1, one crew record
en_copy:
	moveq	#CREW_SIZEOF-1,d0
.c:	move.b	(a0)+,(a1)+
	dbf	d0,.c
	rts

; displaycrew / displayencodes (the rows; Cancel): a0 = the six records
en_list:
	movem.l	d3/a3,-(sp)
	move.l	a0,a3
	moveq	#1,d3
.l:	move.w	d3,d1			; y = 35 + a*15
	mulu	#15,d1
	add.w	#35,d1
	move.w	d1,en_y
	moveq	#50,d0			; printxy(50, y, name)
	lea	CREW_NAME(a3),a0
	bsr	printxy
	moveq	#0,d0			; str(phy:2)+'/'
	move.b	CREW_PHY(a3),d0
	move.w	#153,d1
	bsr	.num
	moveq	#0,d0
	move.b	CREW_MEN(a3),d0
	move.w	#168,d1
	bsr	.num
	moveq	#0,d0			; str(emo:2)
	move.b	CREW_EMO(a3),d0
	moveq	#2,d1
	lea	en_s,a0
	bsr	int_str
	move.w	#183,d0
	move.w	en_y,d1
	lea	en_s,a0
	bsr	printxy
	move.l	CREW_XP(a3),d0		; str(xp:8)
	moveq	#8,d1
	lea	en_s,a0
	bsr	int_str
	move.w	#200,d0
	move.w	en_y,d1
	lea	en_s,a0
	bsr	printxy
	move.w	#241,d0
	move.w	en_y,d1
	lea	en_t_xp,a0
	bsr	printxy
	lea	CREW_SIZEOF(a3),a3
	addq.w	#1,d3
	cmp.w	#6,d3
	ble	.l
	PXY	221,140,"Cancel"
	movem.l	(sp)+,d3/a3
	rts
.num:	move.w	d1,-(sp)		; str(d0:2)+'/' at (d1, y)
	moveq	#2,d1
	lea	en_s,a0
	bsr	int_str
	lea	en_s,a0
	moveq	#0,d0
	move.b	(a0),d0
	addq.b	#1,(a0)
	move.b	#'/',1(a0,d0.w)
	move.w	(sp)+,d0
	move.w	en_y,d1
	bra	printxy

; mainencloop: out d0.w = cursor (1-6 a row, 7 Cancel, 8 Encode All)
en_mainloop:
	clr.w	en_done
	clr.w	en_cursor
	clr.w	en_lastx
	clr.w	en_lasty
	bsr	mouseshow
.l:	bsr	en_findmouse
	bsr	kbd_keypressed
	tst.b	d0
	beq.s	.nk
	bsr	en_processkey
.nk:	tst.w	en_done
	beq.s	.l
	move.w	en_cursor,d0
	rts

en_undocursor:
	moveq	#-3,d4
	bra.s	en_fadecursor
en_drawcursor:
	moveq	#3,d4
en_fadecursor:
	movem.l	d3-d4,-(sp)
	move.w	en_cursor,d0
	beq.s	.x
	cmp.w	#7,d0
	bge.s	.b
	mulu	#15,d0			; plainfadearea(50,33+cursor*15,260,44+cursor*15,alt)
	add.w	#33,d0
	move.w	d0,d1
	move.w	d0,d3
	add.w	#11,d3
	moveq	#50,d0
	move.w	#260,d2
	bra.s	.f
.b:	bne.s	.b8
	move.w	#220,d0			; 7: (220,138,260,149)
	move.w	#260,d2
	bra.s	.bb
.b8:	cmp.w	#8,d0
	bne.s	.x
	moveq	#50,d0			; 8: (50,138,110,149)
	moveq	#110,d2
.bb:	move.w	#138,d1
	move.w	#149,d3
.f:	bsr	plainfadearea
.x:	movem.l	(sp)+,d3-d4
	rts

en_processkey:
	bsr	en_undocursor
	bsr	kbd_readkey
	tst.b	d0
	bne.s	.asc
	bsr	kbd_readkey
	cmp.b	#72,d0
	bne.s	.dn
	move.w	en_cursor,d0		; up
	bne.s	.u1
	move.w	#1,en_cursor
	bra	.done
.u1:	cmp.w	#1,d0
	ble.s	.u6
	subq.w	#1,en_cursor
	bra	.done
.u6:	move.w	#6,en_cursor
	bra	.done
.dn:	cmp.b	#80,d0
	bne	.done
	cmp.w	#6,en_cursor
	bge.s	.d1
	addq.w	#1,en_cursor
	bra	.done
.d1:	move.w	#1,en_cursor
	bra	.done
.asc:	cmp.b	#'a',d0			; upcase
	blo.s	.up
	cmp.b	#'z',d0
	bhi.s	.up
	sub.b	#32,d0
.up:	cmp.b	#'1',d0
	blo.s	.n7
	cmp.b	#'6',d0
	bhi.s	.n7
	sub.b	#'0',d0
	ext.w	d0
	move.w	d0,en_cursor
	bra.s	.done
.n7:	cmp.b	#'7',d0
	bne.s	.nc
	tst.b	en_encoding
	beq.s	.done
	move.w	#8,en_cursor
	bra.s	.done
.nc:	cmp.b	#'C',d0
	bne.s	.cr
	move.w	#7,en_cursor
	bra.s	.done
.cr:	cmp.b	#13,d0
	bne.s	.es
	tst.w	en_cursor
	beq.s	.done
	move.w	#1,en_done
	bra.s	.done
.es:	cmp.b	#27,d0
	bne.s	.done
	move.w	#7,en_cursor
	move.w	#1,en_done
.done:	bsr	en_drawcursor
	bsr	kbd_mouse_xy
	move.w	d0,en_lastx
	move.w	d1,en_lasty
	rts

en_findmouse:
	movem.l	d3-d5,-(sp)
	bsr	kbd_mouse_status
	moveq	#0,d5			; button
	tst.b	d0
	beq.s	.nb
	moveq	#1,d5
.nb:	bsr	kbd_mouse_xy
	move.w	d0,d3			; x
	move.w	d1,d4			; y
	; if (not button) and (mouse.x=lastx) or (mouse.y=lasty) then exit
	cmp.w	en_lasty,d4
	beq	.x
	tst.w	d5
	bne.s	.go
	cmp.w	en_lastx,d3
	beq	.x
.go:	move.w	#$5555,d0		; (newcursor is a Pascal local the case leaves unset for x 50-110 when
					; decoding: the oracle is built with -gt, locals start as $55 bytes)
	cmp.w	#138,d4
	blo.s	.rows
	cmp.w	#149,d4
	bhi.s	.z
	cmp.w	#220,d3			; 220..260: 7; 50..110: 8 if encoding; else 0
	blo.s	.b8
	cmp.w	#260,d3
	bhi.s	.z
	moveq	#7,d0
	bra.s	.set
.b8:	cmp.w	#50,d3
	blo.s	.z
	cmp.w	#110,d3
	bhi.s	.z
	tst.b	en_encoding
	beq.s	.set
	moveq	#8,d0
	bra.s	.set
.rows:	cmp.w	#48,d4			; 48..59 -> 1, 63..74 -> 2, ... 123..134 -> 6
	blo.s	.z
	move.w	d4,d1
	sub.w	#48,d1
	ext.l	d1
	divu	#15,d1
	swap	d1
	cmp.w	#11,d1			; the gap rows (60-62, ...)
	bhi.s	.z
	swap	d1
	cmp.w	#6,d1
	bge.s	.z
	cmp.w	#49,d3
	bls.s	.z
	cmp.w	#261,d3
	bhs.s	.z
	move.w	d1,d0
	addq.w	#1,d0
	bra.s	.set
.z:	moveq	#0,d0
.set:	move.w	d0,en_newcursor
	cmp.w	en_cursor,d0
	beq.s	.same
	bsr	en_undocursor
	move.w	en_newcursor,en_cursor
	bsr	en_drawcursor
.same:	tst.w	en_newcursor		; a click on one of the 8 buttons
	beq.s	.x
	tst.w	d5
	beq.s	.x
	cmp.w	#8,en_newcursor
	bne.s	.dn
	moveq	#0,d0			; i := 38 if tcolor = 181
	cmp.w	#181,GS_TCOLOR(a6)
	bne.s	.i
	moveq	#38,d0
.i:	move.w	GS_TCOLOR(a6),d1
	lea	en_t_all,a0
	bsr	yesnorequest
	tst.w	d0
	bne.s	.dn
	move.w	#7,en_newcursor		; "no" counts as Cancel
.dn:	move.w	#1,en_done
	move.w	en_newcursor,en_cursor
.x:	movem.l	(sp)+,d3-d5
	rts

	section	data
en_t_life:	dc.b	46,"Life support damage, backup encodes corrupted!"
en_t_xp:	dc.b	2,"XP"
en_t_all:	dc.b	11,"Encode All?"
	even
	section	bss
en_alt:		ds.w	1
en_cursor:	ds.w	1
en_newcursor:	ds.w	1
en_done:	ds.w	1
en_lastx:	ds.w	1
en_lasty:	ds.w	1
en_y:		ds.w	1
en_s:		ds.b	16
en_encoding:	ds.b	1
	even
	section	text
