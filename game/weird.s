; weird.s - weird.pas for MAIN.PRG: events and logs.
;
; event      in: d0.w n: weird.pas event (sets the event, adds the log and shows it, gives the
;            cargo ...). Cases whose code is not ported yet stop the program (notported).
; setevent / clearevent   in: d0.w n                                   trashes: d0-d2/a0-a1
; addlog     in: d0.w n: set the event, append the log, show it (computerlogs)
; (event/addlog trash d0-d2/a0-a2)

	section	text
setevent:
	cmp.w	#8192,d0
	bge.s	.x
	move.w	d0,d1
	lsr.w	#3,d1
	lea	GS_EVENTS(a6),a0
	moveq	#7,d2
	and.w	d0,d2
	bset	d2,0(a0,d1.w)
	cmp.w	#50,d0			; ship.events bitmap for events 50-499
	blt.s	.x
	cmp.w	#500,d0
	bge.s	.x
	sub.w	#50,d0
	move.w	d0,d1
	lsr.w	#3,d1
	and.w	#7,d0
	lea	GS_SHIP+SHIP_EVENTS+50(a6),a0
	bset	d0,0(a0,d1.w)
.x:	rts

clearevent:
	cmp.w	#8192,d0
	bge.s	.x
	move.w	d0,d1
	lsr.w	#3,d1
	lea	GS_EVENTS(a6),a0
	moveq	#7,d2
	and.w	d0,d2
	bclr	d2,0(a0,d1.w)
	cmp.w	#50,d0
	blt.s	.x
	cmp.w	#500,d0
	bge.s	.x
	sub.w	#50,d0
	move.w	d0,d1
	lsr.w	#3,d1
	and.w	#7,d0
	lea	GS_SHIP+SHIP_EVENTS+50(a6),a0
	bclr	d0,0(a0,d1.w)
.x:	rts

addlog:
	move.w	d3,-(sp)
	move.w	d0,d3
	bsr	setevent
	lea	GS_LOGS(a6),a0		; first free (-1) entry
.f:	tst.w	(a0)+
	bpl.s	.f
	move.w	d3,-2(a0)
	cmp.w	#50,d3			; old style log/events for n < 50
	bge.s	.c
	lea	GS_SHIP+SHIP_EVENTS(a6),a0
.e:	cmp.b	#255,(a0)+
	bne.s	.e
	move.b	d3,-1(a0)
.c:	move.w	d3,d0
	move.w	(sp)+,d3
	bra	computerlogs

event:
	movem.l	d3-d4,-(sp)
	move.w	d0,d3
	bsr	chevent
	bne	.x
	tst.w	d3			; not for logs 0-49 / 1000-1999
	bmi.s	.set
	cmp.w	#50,d3
	blt.s	.case
.set:	cmp.w	#1000,d3
	blt.s	.set2
	cmp.w	#1999,d3
	ble.s	.case
.set2:	move.w	d3,d0
	bsr	setevent
.case:	move.w	d3,d0
	cmp.w	#10,d0			; 0..9 alien races, plain logs
	blt	.log
	cmp.w	#12,d0
	beq	.e12
	cmp.w	#11,d0
	beq	.log
	cmp.w	#13,d0
	beq.s	.log
	cmp.w	#15,d0
	beq.s	.log
	cmp.w	#16,d0
	beq.s	.log
	cmp.w	#18,d0
	beq.s	.log
	cmp.w	#21,d0
	beq.s	.e21
	cmp.w	#22,d0
	beq.s	.e22
	cmp.w	#27,d0
	beq.s	.e27
	cmp.w	#42,d0
	beq.s	.log
	cmp.w	#1103,d0
	beq.s	.log
	lea	.plain,a0		; 10,23,30..35,37,38,41,44: addlog(n)
.pl:	move.w	(a0)+,d1
	bmi.s	.nl
	cmp.w	d1,d0
	beq.s	.log
	bra.s	.pl
.nl:	cmp.w	#1000,d0		; 1000..1102, 1104..1999
	blt.s	.other
	cmp.w	#1999,d0
	ble.s	.log
.other:	lea	wd_events,a0		; the cases with more to them
.oe:	move.w	(a0)+,d1
	bmi.s	.none
	move.l	(a0)+,a1
	cmp.w	d1,d0
	bne.s	.oe
	jsr	(a1)
	bra.s	.x
.none:	cmp.w	#29,d0			; ("Log #29 ain't suppose to happen!")
	beq.s	.np
	bra.s	.x
.np:	bsr	notported
	bra.s	.x
.e21:	moveq	#36,d0
	bra.s	.cond
.e22:	moveq	#21,d0
	bra.s	.cond
.e27:	moveq	#25,d0
.cond:	bsr	chevent
	beq.s	.x
	move.w	d3,d0
.log:	bsr	addlog
.x:	movem.l	(sp)+,d3-d4
	rts
.e12:	lea	.notes,a0		; second buoy: systems become known
.n12:	move.w	(a0)+,d0
	beq.s	.l12
	mulu	#SYSTEM_SIZEOF,d0
	lea	GS_SYSTEMS-SYSTEM_SIZEOF+SYSTEM_NOTES(a6),a1
	bset	#0,0(a1,d0.w)
	bra.s	.n12
.l12:	moveq	#12,d0
	bsr	addlog
	move.w	#1001,d0
	bsr	event
	bra.s	.x
.plain:	dc.w	10,23,30,31,32,33,34,35,37,38,41,44,-1
.notes:	dc.w	145,211,115,18,199,103,216,105,93,0

; ---------------------------------------------------------------- the events' own actions (d3 = n)
wd_ac:					; addcargo(d0, true)
	st	d1
	bra	addcargo
wd_e14:	moveq	#14,d0			; trojan gate
	bsr	addlog
	move.w	#2389,d0
	move.w	#1695,d1
	move.w	#1314,d2
	bra	redoscreen
wd_e17:	move.w	#ID_ART_THERMAL_PLATING,d0	; derelict
	bsr	wd_ac
	moveq	#4-1,d3
.c:	move.w	#ID_UNKNOWN_COMPONENT,d0
	bsr	wd_ac
	dbf	d3,.c
	move.w	#ID_UNKNOWN_MATERIAL,d0
	bsr	wd_ac
	moveq	#17,d0
	bra	addlog
wd_e19:	moveq	#63,d0			; nova
	moveq	#63,d1
	moveq	#63,d2
	bsr	wd_blast
	moveq	#19,d0
	bra	addlog
wd_e20:	move.w	#ID_ART_SHUNT_DRIVE,d0	; shunt ship
	bsr	wd_ac
	moveq	#20,d0
	bra	addlog
wd_e24:	move.w	#ID_ART_DETONATOR,d0	; in the temple
	bsr	incargo
	tst.w	d0
	ble.s	.x
	moveq	#42,d0
	bsr	chevent
	beq.s	.x
	move.w	#ID_ART_DETONATOR,d0
	bsr	removecargo
	move.w	#ID_ART_CHANNELER,d0
	bsr	wd_ac
	move.w	#ID_ART_IRON_SEED,d0
	bsr	wd_ac
	move.w	#ID_ART_HOMING_DEVICE,d0
	bsr	wd_ac
	moveq	#24,d0
	bra	addlog
.x:	rts
wd_e25:	move.w	#ID_ART_HOMING_DEVICE,d0	; the pirate base
	bsr	incargo
	tst.w	d0
	ble.s	.x
	moveq	#24,d0
	bsr	chevent
	beq.s	.x
	move.w	#ID_STASIS_GENERATOR,d0
	bsr	removecargo
	move.w	#ID_ART_HOMING_DEVICE,d0
	bsr	removecargo
	move.w	#ID_ART_SHUNT_DRIVE,d0
	bsr	wd_ac
	moveq	#3,d0			; for j := 1 to random(3): an artifact of either kind
	bsr	mt_random
	move.w	d0,d3
	bra.s	.n
.l:	moveq	#2,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.a2
	move.w	#400,d0
	bsr	mt_random
	add.w	#1+ID_ARTIFACT_OFFSET,d0
	bra.s	.ad
.a2:	moveq	#100,d0
	bsr	mt_random
	add.w	#1+ID_ARTIFACT2_OFFSET,d0
.ad:	bsr	wd_ac
.n:	dbf	d3,.l
	moveq	#3-1,d3
.c:	move.w	#ID_UNKNOWN_COMPONENT,d0
	bsr	wd_ac
	dbf	d3,.c
	moveq	#25,d0
	bra	addlog
.x:	rts
wd_e26:	moveq	#24,d0			; piracy
	bsr	chevent
	beq.s	.x
	move.w	#ID_ART_SHUNT_DRIVE,d0
	bsr	removecargo
	moveq	#26,d0
	bra	addlog
.x:	rts
wd_e28:	moveq	#30,d0			; the Ermigen data tapes
	bsr	chevent
	beq.s	.x
	move.w	#ID_ART_ERMIGEN_DATA_TAPES,d0
	bsr	wd_ac
	moveq	#28,d0
	bsr	addlog
	move.l	GS_TEMPPLAN(a6),a0	; erase the notes on system 45's star
	move.w	#1000-1,d0
.p:	cmp.b	#45,PLANET_SYSTEM(a0)
	bne.s	.pn
	tst.b	PLANET_ORBIT(a0)
	bne.s	.pn
	clr.b	PLANET_NOTES(a0)
.pn:	lea	PLANET_SIZEOF(a0),a0
	dbf	d0,.p
.x:	rts
wd_e36:	move.w	#ID_ART_SHUNT_DRIVE,d0
	bra.s	wd_cl
wd_e39:	move.w	#ID_ART_DETONATOR,d0
	bra.s	wd_cl
wd_e40:	move.w	#ID_ART_GLYPTIC_SCYTHE,d0
	bra.s	wd_cl
wd_e45:	move.w	#ID_DOOM_GATE,d0
	bra.s	wd_cl
wd_e46:	move.w	#ID_THAUMATURGE,d0
	bra.s	wd_cl
wd_e48:	move.w	#ID_ART_MULTI_IMAGER,d0
	bra.s	wd_cl
wd_e49:	move.w	#ID_ART_YLINTH_MUTAGENICS,d0
wd_cl:	bsr	wd_ac			; addcargo(item, true); addlog(n)
	move.w	d3,d0
	bra	addlog
wd_e43:	move.w	#ID_ART_YLINTH_MUTAGENICS,d0
	bra.s	wd_rl
wd_e47:	move.w	#ID_ART_SHUNT_DRIVE,d0
wd_rl:	bsr	removecargo		; removecargo(item); addlog(n)
	move.w	d3,d0
	bra	addlog
wd_e10000:
	bsr	println			; Phaedor Moch
	TCOL	94
	PRT	"SECURITY: Scanners detect alien ship."
	moveq	#10,d0			; startphaedormoch
	move.w	#1010,d1
	bsr	getspecial
	bsr	addtofile
	moveq	#WNDORDER_RETREAT,d0
	bsr	createwandering
	TCOL	94
	PRTLN
	PRT	"SCIENCE: Perhaps we should initiate contact, Laird."
	rts
wd_e10001:
	move.w	#ID_ART_MULTI_IMAGER,d0
	bra	removecargo
wd_e10002:				; the scavenger armada: combat until the end (or quit)
	lea	.ev(pc),a0
.c:	moveq	#0,d0
	move.b	(a0)+,d0
	beq.s	.all
	move.l	a0,-(sp)
	bsr	chevent
	move.l	(sp)+,a0
	bne.s	.c
	cmp.b	#34,-1(a0)		; (34 or 30)
	bne.s	.rep
	addq.l	#1,a0
	moveq	#30,d0
	move.l	a0,-(sp)
	bsr	chevent
	move.l	(sp)+,a0
	bne.s	.c
	bra.s	.rep
.all:	bsr	wd_startarmada
	bra	endgame
.rep:	bsr	wd_startarmada
	tst.b	GS_QUIT(a6)
	beq.s	.rep
	rts
.ev:	dc.b	45,46,31,34,47,48,21,23,0
	even
wd_startarmada:
	moveq	#7,d0
	move.w	#1007,d1
	bsr	getspecial
	bsr	addtofile
	moveq	#WNDORDER_ATTACK,d0
	bsr	createwandering
	bra	initiatecombat

; weird.pas blast(c1 d0, c2 d1, c3 d2): 63 steps of colors towards (c1,c2,c3) (colors itself
; moves: each step from the last), then the palette comes back
wd_blast:
	movem.l	d3-d7/a3,-(sp)
	movem.w	d0-d2,wd_c
	lea	GS_COLORS(a6),a0	; temppal := colors
	lea	wd_temppal,a1
	move.w	#768/4-1,d0
.s:	move.l	(a0)+,(a1)+
	dbf	d0,.s
	moveq	#1,d3			; a
.a:	lea	GS_COLORS(a6),a3
	move.w	#256-1,d4
.j:	lea	wd_c,a0
	moveq	#3-1,d5
.g:	moveq	#0,d6			; colors[j,g] += round(a*(c-colors[j,g])/63): no ties
	move.b	(a3),d6
	move.w	(a0)+,d7
	sub.w	d6,d7
	muls	d3,d7			; a*d
	add.l	d7,d7			; floor((2*a*d + 63) / 126)
	add.l	#63,d7
	divs	#126,d7
	bpl.s	.p
	swap	d7			; (floor for negatives: the remainder's sign)
	tst.w	d7
	swap	d7
	beq.s	.p
	subq.w	#1,d7
.p:	add.b	d7,(a3)+
	dbf	d5,.g
	dbf	d4,.j
	lea	GS_COLORS(a6),a0
	bsr	set256colors
	move.w	GS_TSLICE(a6),d0
	lsl.w	#2,d0
	bsr	delay
	addq.w	#1,d3
	cmp.w	#64,d3
	bne.s	.a
	lea	GS_COLORS(a6),a0
	bsr	set256colors
	lea	wd_temppal,a0
	lea	GS_COLORS(a6),a1
	move.w	#768/4-1,d0
.r:	move.l	(a0)+,(a1)+
	dbf	d0,.r
	movem.l	(sp)+,d3-d7/a3
	rts

; a part of the game that is not ported yet: tell the player, back to the title
notported:
	pea	msg_notported
	GEMDOS	GD_CCONWS,6
	moveq	#3,d0
	bra	sys_exit

	section	data
wd_events:	dc.w	14
		dc.l	wd_e14
		dc.w	17
		dc.l	wd_e17
		dc.w	19
		dc.l	wd_e19
		dc.w	20
		dc.l	wd_e20
		dc.w	24
		dc.l	wd_e24
		dc.w	25
		dc.l	wd_e25
		dc.w	26
		dc.l	wd_e26
		dc.w	28
		dc.l	wd_e28
		dc.w	36
		dc.l	wd_e36
		dc.w	39
		dc.l	wd_e39
		dc.w	40
		dc.l	wd_e40
		dc.w	43
		dc.l	wd_e43
		dc.w	45
		dc.l	wd_e45
		dc.w	46
		dc.l	wd_e46
		dc.w	47
		dc.l	wd_e47
		dc.w	48
		dc.l	wd_e48
		dc.w	49
		dc.l	wd_e49
		dc.w	10000
		dc.l	wd_e10000
		dc.w	10001
		dc.l	wd_e10001
		dc.w	10002
		dc.l	wd_e10002
		dc.w	-1
msg_notported:	dc.b	"This part of the game is not ported yet.",13,10,0
	even

	section	bss
wd_c:		ds.w	3
wd_temppal:	ds.b	768

	section	text
; weird.pas bossmode (the FPC build's: the text-mode screens are commented out): music paused,
; the palette black, until a key or a click; delay(150); the keys read ('7' with the button held:
; easteregg6 - not ported); colors back, music on
bossmode:
	bsr	pausemod
	lea	wd_black,a0
	bsr	set256colors
.w:	bsr	kbd_keypressed		; repeat until fastkeypressed or mouse.getstatus
	tst.b	d0
	bne.s	.k
	bsr	kbd_mouse_status
	tst.b	d0
	beq.s	.w
.k:	move.w	#150,d0
	bsr	delay
.d:	bsr	kbd_keypressed		; while fastkeypressed do (upcase(readkey) = '7') and button: egg 6
	tst.b	d0
	beq.s	.e
	bsr	kbd_readkey
	cmp.b	#'7',d0
	bne.s	.d
	bsr	kbd_mouse_status
	tst.b	d0
	beq.s	.d
	bra	notported		; (easteregg6)
.e:	lea	GS_COLORS(a6),a0
	bsr	set256colors
	bra	continuemod
	section	bss
wd_black:	ds.b	768
	section	text
