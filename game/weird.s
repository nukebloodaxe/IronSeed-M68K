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
	beq.s	.log
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
.other:	cmp.w	#50,d0			; events with no case: nothing more
	blt.s	.np
	cmp.w	#10000,d0
	blt.s	.x
	cmp.w	#10002,d0
	bgt.s	.x
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

; a part of the game that is not ported yet: tell the player, back to the title
notported:
	pea	msg_notported
	GEMDOS	GD_CCONWS,6
	moveq	#3,d0
	bra	sys_exit

	section	data
msg_notported:	dc.b	"This part of the game is not ported yet.",13,10,0
	even
