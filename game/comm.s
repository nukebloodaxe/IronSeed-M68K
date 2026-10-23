; comm.s - comm.pas for MAIN.PRG (alien contact): checkwandering so far.
;
; checkwandering  when no alien ship is about: the contact record of the current planet (read
;                 into alien); if it is angry, an attacking ship (not ported yet)

	section	text
checkwandering:
	movem.l	d3/a3,-(sp)
	cmp.w	#16000,GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6)
	blt	.x
	clr.w	-(sp)			; reset(confile)
	pea	cm_fn_contacts
	GEMDOS	GD_FOPEN,8
	move.w	d0,d3
	bmi	fatal
.r:	pea	cm_rec			; repeat read(confile, alien) until alien.id = curplan or EOF
	move.l	#ALIEN_SIZEOF,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FREAD,12
	cmp.l	#ALIEN_SIZEOF,d0
	bne.s	.e
	lea	cm_rec,a0
	lea	GS_ALIEN(a6),a1
	moveq	#ALIEN_SIZEOF/2-1,d0
.c:	move.w	(a0)+,(a1)+
	dbf	d0,.c
	move.w	GS_ALIEN+ALIEN_ID(a6),d0
	cmp.w	GS_CURPLAN(a6),d0
	bne.s	.r
.e:	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
	move.w	GS_ALIEN+ALIEN_ID(a6),d0
	cmp.w	GS_CURPLAN(a6),d0
	bne.s	.x
	move.w	GS_ALIEN+ALIEN_ANGER(a6),d1
	ble.s	.x
	move.w	GS_ALIEN+ALIEN_CONGENIALITY(a6),d0	; congeniality/anger < 0.7
	muls	#10,d0
	muls	#7,d1
	cmp.l	d1,d0
	bge.s	.x
	bra	notported		; createwandering(WNDORDER_ATTACK)
.x:	movem.l	(sp)+,d3/a3
	rts

	section	data
cm_fn_contacts:	dc.b	"TEMP",92,"CONTACTS.DTA",0
	even

	section	bss
cm_rec:		ds.b	ALIEN_SIZEOF
	even
