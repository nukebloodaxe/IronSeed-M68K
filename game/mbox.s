; mbox.s - utils.pas's message boxes for MAIN.PRG: showchar (a crew member's message, with the
; portrait, from work done in the background) and printbox. Both also put the text into the
; text box's memory (shadowprint) and, with the messages option on 2, show a box over whatever
; screen is up and wait for OK / Return / Esc (snapshot slot 2, the original's 'current3').
; The portraits: DATA\PORTRAIT.DAT (image01-30.cpr as 70x70 chunky, tools/mkmain.py), read once.
;
; showchar  in: d0.w crew (0 computer, 1-6), a0 = message (Pascal string)   trashes: d0-d2/a0-a2
; printbox  in: a0 = message                                               trashes: d0-d2/a0-a2

	section	text
; the box colours from the palette (the original tests colors[31,3], colors[32,2], colors[32,1]):
; d0 := one of 5 words at a0 by the case: 0 colors[32,2] = 63; 1 colors[31,3] = 63 and
; colors[32,1] = 0; 2 colors[31,3] = 63; 3 colors[32,1] = 0; 4 the others
mb_pick:
	lea	GS_COLORS+31*3(a6),a1
	moveq	#0,d0
	cmp.b	#63,4(a1)		; colors[32,2]
	beq.s	.p
	moveq	#1,d0
	cmp.b	#63,2(a1)		; colors[31,3]
	beq.s	.r
	moveq	#3,d0
.r:	tst.b	3(a1)			; colors[32,1] = 0 ?
	beq.s	.p
	addq.w	#1,d0
.p:	add.w	d0,d0
	move.w	0(a0,d0.w),d0
	rts

; button(d0-d3, alt d4) into the shadow, marked
mb_button:
	movem.l	d0-d3,-(sp)
	bsr	sl_button
	movem.l	(sp)+,d0-d3
	bra	ms_dirty

; round((170 - length(a0^)*5)/2) + 70 -> d0 (banker's at .5)
mb_centre:
	moveq	#0,d0
	move.b	(a0),d0
	mulu	#5,d0
	neg.w	d0
	add.w	#170,d0
	asr.w	#1,d0			; floor(v/2): v odd -> x.5 -> the even one of floor, floor+1
	bcc.s	.e
	btst	#0,d0
	beq.s	.e
	addq.w	#1,d0
.e:	add.w	#70,d0
	rts

; the OK button's wait: plainfadearea(139, y1, 179, y2, +-3) while the mouse is over it;
; d3 = y1 (110 or 78), d4.b = 0: delay before the checks (showchar), 1: after (printbox)
mb_wait:
	movem.l	d3-d7,-(sp)
	move.w	d3,d6			; y1
	move.w	d3,d7
	add.w	#14,d7			; y2
	move.b	d4,d5
.fl:	bsr	kbd_keypressed		; while fastkeypressed do readkey
	beq.s	.go
	bsr	kbd_readkey
	bra.s	.fl
.go:	moveq	#0,d3			; c
	move.b	#' ',mb_ans
.l:	tst.b	d5
	bne.s	.n1
	bsr	.dly
.n1:	bsr	kbd_mouse_status	; done := mouse.getstatus
	move.b	d0,mb_done
	bsr	kbd_mouse_xy
	tst.w	d3
	bne.s	.c1
	cmp.w	d6,d1			; c = 0 and over the button: light it
	blt.s	.k
	cmp.w	d7,d1
	bgt.s	.k
	cmp.w	#139,d0
	blt.s	.k
	cmp.w	#179,d0
	bgt.s	.k
	moveq	#1,d3
	moveq	#3,d4
	bra.s	.fd
.c1:	cmp.w	d6,d1			; c = 1 and outside: back
	blt.s	.out
	cmp.w	d7,d1
	bgt.s	.out
	cmp.w	#139,d0
	blt.s	.out
	cmp.w	#179,d0
	ble.s	.k
.out:	moveq	#0,d3
	moveq	#-3,d4
.fd:	movem.l	d3,-(sp)
	move.w	#139,d0
	move.w	d6,d1
	move.w	#179,d2
	move.w	d7,d3
	bsr	plainfadearea
	movem.l	(sp)+,d3
.k:	bsr	kbd_keypressed		; if fastkeypressed then ans := readkey
	beq.s	.nk
	bsr	kbd_readkey
	move.b	d0,mb_ans
.nk:	tst.b	d5
	beq.s	.t
	bsr	.dly
.t:	tst.b	mb_done
	beq.s	.t2
	tst.w	d3
	bne.s	.x
.t2:	cmp.b	#27,mb_ans
	beq.s	.x
	cmp.b	#13,mb_ans
	bne	.l
.x:	movem.l	(sp)+,d3-d7
	rts
.dly:	move.w	GS_TSLICE(a6),d0	; delay(tslice*FADE_TSLICE_MUL_UTILS); fadestep(FADESTEP_STEP)
	bsr	delay
	moveq	#8,d0
	bra	fadestep

; ---------------------------------------------------------------- showchar
showchar:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,d7			; n
	move.l	a0,a5			; s1
	move.w	GS_TCOLOR(a6),d6	; oldt
	tst.b	GS_SHIP+SHIP_OPTIONS+OPT_MSGS-1(a6)
	beq	.x
	lea	mb_s1,a0		; (a copy: s1 is cut below)
	move.l	a5,a1
	bsr	pstr_cpy
	lea	mb_s1,a5
	move.w	#31,GS_TCOLOR(a6)
	bsr	shadowprintln
	move.w	d7,d0			; s := crewtitles' heading
	mulu	#13,d0
	lea	mb_heads,a0
	add.w	d0,a0
	bsr	shadowprint
	lea	mb_s2,a0		; ' ' + s1
	move.b	#1,(a0)
	move.b	#' ',1(a0)
	move.l	a5,a1
	bsr	pstr_cat
	lea	mb_s2,a0
	bsr	shadowprint
	clr.b	mb_s2			; s2 := '' (or the part after column 30)
	moveq	#0,d0
	move.b	(a5),d0
	cmp.w	#30,d0
	ble.s	.ns
	moveq	#30,d1			; i := 30; while s1[i] not in ' .?' do dec(i)
.w:	move.b	0(a5,d1.w),d2
	cmp.b	#' ',d2
	beq.s	.wf
	cmp.b	#'.',d2
	beq.s	.wf
	cmp.b	#'?',d2
	beq.s	.wf
	subq.w	#1,d1
	bra.s	.w
.wf:	sub.w	d1,d0			; s2 := copy(s1, i+1, length-i); s1 := copy(s1, 1, i)
	lea	mb_s2,a0
	move.b	d0,(a0)+
	lea	1(a5,d1.w),a1
	bra.s	.c2e
.c2:	move.b	(a1)+,(a0)+
.c2e:	dbf	d0,.c2
	move.b	d1,(a5)
.ns:	move.w	d6,GS_TCOLOR(a6)
	cmp.b	#1,GS_SHIP+SHIP_OPTIONS+OPT_MSGS-1(a6)
	beq	.x
	bsr	mousehide
	moveq	#2,d0			; compressfile(current3)
	bsr	ms_snap
	lea	.tt,a0			; t
	bsr	mb_pick
	move.w	d0,d5
	lea	.of1,a0
	bsr	mb_pick
	move.w	d0,d4			; button(70, 82, 249, 134, ofsc)
	moveq	#70,d0
	moveq	#82,d1
	move.w	#249,d2
	move.w	#134,d3
	bsr	mb_button
	tst.w	d7
	ble	.np
	move.w	#123,d0			; button(123, 8, 196, 81, ofsc)
	moveq	#8,d1
	move.w	#196,d2
	moveq	#81,d3
	bsr	mb_button
	move.w	d7,d0			; n := ship.crew[n].index; loadscreen(image nn)
	bsr	ct_crew
	moveq	#0,d7
	move.b	CREW_INDEX(a0),d7
	bsr	orc_dump
	bsr	mb_portraits
	move.w	d7,d0
	subq.w	#1,d0
	mulu	#70*70,d0
	move.l	mb_pics,a3
	add.l	d0,a3
	move.w	#125,GS_X(a6)		; x := 125; y := 10
	move.w	#10,GS_Y(a6)
	moveq	#0,d3			; i (row)
.pr:	move.w	#125,d0
	moveq	#10,d1
	add.w	d3,d1
	bsr	ms_addr
	moveq	#70-1,d2
.pc:	move.b	(a3)+,d0
	cmp.w	#197,d5
	bne.s	.p26
	cmp.b	#32,d0			; a < 32: a, else a+16
	blo.s	.pw
	add.b	#16,d0
	bra.s	.pw
.p26:	cmp.w	#26,d5
	bne.s	.pw
	cmp.b	#32,d0			; a < 32: a div 2, else ((a mod 32)+32) div 2
	blo.s	.ph
	and.b	#31,d0
	add.b	#32,d0
.ph:	lsr.b	#1,d0
.pw:	move.b	d0,(a0)+
	dbf	d2,.pc
	addq.w	#1,d3
	cmp.w	#70,d3
	bne.s	.pr
	move.w	#125,d0
	moveq	#10,d1
	move.w	#194,d2
	moveq	#79,d3
	bsr	ms_dirty
.np:	lea	.of2,a0			; button(139, 110, 179, 124, ofsc)
	bsr	mb_pick
	move.w	d0,d4
	move.w	#139,d0
	moveq	#110,d1
	move.w	#179,d2
	moveq	#124,d3
	bsr	mb_button
	move.w	d5,GS_TCOLOR(a6)	; tcolor := t
	lea	.bk1,a0
	bsr	mb_pick
	move.w	d0,GS_BKCOLOR(a6)
	move.l	a5,a0			; the two lines, centred
	bsr	mb_centre
	moveq	#87,d1
	move.l	a5,a0
	bsr	printxy
	lea	mb_s2,a0
	bsr	mb_centre
	moveq	#93,d1
	lea	mb_s2,a0
	bsr	printxy
	lea	.bk2,a0
	bsr	mb_pick
	move.w	d0,GS_BKCOLOR(a6)
	PXY	149,114,"OK"
	bsr	mouseshow
	moveq	#110,d3
	moveq	#0,d4
	bsr	mb_wait
	bsr	mousehide
	bsr	orc_dump		; loadscreen(current3)
	moveq	#2,d0
	bsr	ms_unsnap
	bsr	mouseshow
	move.w	d6,GS_TCOLOR(a6)
	clr.w	GS_BKCOLOR(a6)
	move.w	#82,ms_color
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts
.tt:	dc.w	26,26,26,197,182		; t       (by mb_kind)
.of1:	dc.w	-26,0,74,0,74		; ofsc
.of2:	dc.w	-24,2,78,2,78		; ofsc for OK
.bk1:	dc.w	9,35,109,35,109		; bkcolor of the text
.bk2:	dc.w	11,37,115,37,115		; bkcolor of OK

; DATA\PORTRAIT.DAT, read the first time a portrait is needed (memory taken in init_everything)
mb_portraits:
	tst.b	mb_loaded
	bne.s	.x
	lea	mb_fn_pics,a0
	move.l	mb_pics,a1
	move.l	#30*70*70,d0
	bsr	load_exact
	st	mb_loaded
.x:	rts

; ---------------------------------------------------------------- printbox
printbox:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	a0,a5
	tst.b	GS_SHIP+SHIP_OPTIONS+OPT_MSGS-1(a6)
	beq	.x
	move.w	GS_TCOLOR(a6),d6	; oldt
	move.w	#31,GS_TCOLOR(a6)
	bsr	shadowprintln
	move.l	a5,a0
	bsr	shadowprint
	move.w	d6,GS_TCOLOR(a6)
	cmp.b	#1,GS_SHIP+SHIP_OPTIONS+OPT_MSGS-1(a6)
	beq	.x
	lea	.tt,a0			; t (the same tests as showchar's)
	bsr	mb_pick
	move.w	d0,d5
	bsr	mousehide		; tempscr := screen rows 50..102, x 75..246
	lea	mb_save,a3
	moveq	#50,d3
.sv:	moveq	#75,d0
	move.w	d3,d1
	bsr	ms_addr
	move.w	#172-1,d0
.svc:	move.b	(a0)+,(a3)+
	dbf	d0,.svc
	addq.w	#1,d3
	cmp.w	#102,d3
	ble.s	.sv
	lea	.of1,a0			; button(75, 60, 244, 102, ofsc)
	bsr	mb_pick
	move.w	d0,d4
	moveq	#75,d0
	moveq	#60,d1
	move.w	#244,d2
	moveq	#102,d3
	bsr	mb_button
	lea	.of2,a0			; button(139, 78, 179, 92, ofsc)
	bsr	mb_pick
	move.w	d0,d4
	move.w	#139,d0
	moveq	#78,d1
	move.w	#179,d2
	moveq	#92,d3
	bsr	mb_button
	move.w	d5,GS_TCOLOR(a6)
	lea	.bk1,a0
	bsr	mb_pick
	move.w	d0,GS_BKCOLOR(a6)
	move.l	a5,a0			; printxy(round((170-length(s)*5)/2)+70, 65, s)
	bsr	mb_centre
	moveq	#65,d1
	move.l	a5,a0
	bsr	printxy
	lea	.bk2,a0
	bsr	mb_pick
	move.w	d0,GS_BKCOLOR(a6)
	PXY	149,82,"OK"
	bsr	mouseshow
	moveq	#78,d3
	moveq	#1,d4
	bsr	mb_wait
	bsr	mousehide		; rows 60..102 back (the original saved from 50)
	lea	mb_save+10*172,a3
	moveq	#60,d3
.rs:	moveq	#75,d0
	move.w	d3,d1
	bsr	ms_addr
	move.w	#172-1,d0
.rsc:	move.b	(a3)+,(a0)+
	dbf	d0,.rsc
	addq.w	#1,d3
	cmp.w	#102,d3
	ble.s	.rs
	moveq	#75,d0
	moveq	#60,d1
	move.w	#246,d2
	moveq	#102,d3
	bsr	ms_dirty
	bsr	mouseshow
	move.w	d6,GS_TCOLOR(a6)
	clr.w	GS_BKCOLOR(a6)
	move.w	#82,ms_color
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts
.tt:	dc.w	26,26,26,197,182
.of1:	dc.w	-26,0,74,0,74
.of2:	dc.w	-24,2,78,2,78
.bk1:	dc.w	9,35,109,35,109
.bk2:	dc.w	11,37,115,37,115

	section	data
mb_heads:				; showchar's s (string[12])
	dc.b	9,"COMPUTER:   "
	dc.b	12,"PSYCHOMETRY:"
	dc.b	12,"ENGINEERING:"
	dc.b	8,"SCIENCE:    "
	dc.b	9,"SECURITY:   "
	dc.b	12,"ASTROGATION:"
	dc.b	6,"MEDIC:      "
mb_fn_pics:	dc.b	"DATA",92,"PORTRAIT.DAT",0
	even
	section	bss
mb_pics:	ds.l	1
mb_s1:		ds.b	256
mb_s2:		ds.b	256
mb_save:	ds.b	53*172
mb_ans:		ds.b	1
mb_done:	ds.b	1
mb_loaded:	ds.b	1
	even
	section	text
