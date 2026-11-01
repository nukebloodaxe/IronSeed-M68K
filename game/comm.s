; comm.s - comm.pas for MAIN.PRG (alien contact): the wandering alien ships so far.
;
; checkwandering  when no alien ship is about: the contact record of the current planet (read
;                 into alien); if it is angry, an attacking ship
; getspecial      in: d0.w n, d1.w contactindex: alien := contact0.dta record n (n = 13: only
;                 the id); alien.id := contactindex
; addtofile       alien appended to TEMP\CONTACTS.DTA unless its id is there
; createwandering in: d0.w order (WNDORDER_*): ship.wandering from alien
; calc_anger      in: d0.w anger, d1.w congeniality  out: d0.w 1-5

	section	text
checkwandering:
	movem.l	d3/a3,-(sp)
	cmp.w	#16000,GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6)
	blt	.x
	clr.w	-(sp)			; reset(confile)
	pea	cm_fn_contacts
	FDOS	GD_FOPEN,8
	move.w	d0,d3
	bmi	fatal
.r:	pea	cm_rec			; repeat read(confile, alien) until alien.id = curplan or EOF
	move.l	#ALIEN_SIZEOF,-(sp)
	move.w	d3,-(sp)
	FDOS	GD_FREAD,12
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
	FDOS	GD_FCLOSE,4
	move.w	GS_ALIEN+ALIEN_ID(a6),d0
	cmp.w	GS_CURPLAN(a6),d0
	bne.s	.x
	tst.w	GS_ALIEN+ALIEN_ANGER(a6)
	ble.s	.x
	FSSE				; congeniality/anger (a real) < 0.7 (extended)
	move.w	GS_ALIEN+ALIEN_CONGENIALITY(a6),d0
	bsr	fp_ldw
	move.w	GS_ALIEN+ALIEN_ANGER(a6),d0
	bsr	fp_ldw
	bsr	fp_div
	lea	cm_r,a0
	bsr	fp_std
	lea	cm_r,a0
	bsr	fp_ldd
	FLDX	gx_0_7
	bsr	fp_cmp
	bge.s	.x
	moveq	#WNDORDER_ATTACK,d0
	bsr	createwandering
.x:	movem.l	(sp)+,d3/a3
	rts

; comm.pas calc_anger(anger d0, congeniality d1): 1 afraid, 2 indifferent, 3 friendly, 4 angry,
; 5 violent (r := congeniality/anger, a real; compared with the extended 0.3 / 0.7)
calc_anger:
	tst.w	d0
	bne.s	.r
	moveq	#1,d0
	cmp.w	#20,d1
	ble.s	.x
	moveq	#3,d0
.x:	rts
.r:	movem.l	d3,-(sp)
	move.w	d0,d3
	FSSE
	move.w	d1,d0
	bsr	fp_ldw
	move.w	d3,d0
	bsr	fp_ldw
	bsr	fp_div
	lea	cm_r,a0
	bsr	fp_std
	lea	cm_r,a0
	bsr	fp_ldd
	FLDX	gx_0_3
	bsr	fp_cmp
	bge.s	.n3
	moveq	#5,d0
	bra.s	.o
.n3:	lea	cm_r,a0
	bsr	fp_ldd
	FLDX	gx_0_7
	bsr	fp_cmp
	bge.s	.n7
	moveq	#4,d0
	bra.s	.o
.n7:	lea	cm_r,a0
	bsr	fp_ldd
	bsr	fp_rnd
	cmp.l	#1,d0
	bne.s	.n1
	moveq	#2,d0
	bra.s	.o
.n1:	moveq	#3,d0
.o:	movem.l	(sp)+,d3
	rts

; comm.pas getspecial(n d0, contactindex d1)
getspecial:
	movem.l	d3-d4,-(sp)
	move.w	d1,d4
	cmp.w	#13,d0
	beq.s	.id
	move.w	d0,d3
	clr.w	-(sp)			; contact0.dta record n-1
	pea	cm_fn_contact0
	FDOS	GD_FOPEN,8
	move.w	d0,d1
	bmi	fatal
	move.w	d1,-(sp)		; (the handle, for the close)
	clr.w	-(sp)
	move.w	d1,-(sp)
	move.w	d3,d0
	subq.w	#1,d0
	mulu	#ALIEN_SIZEOF,d0
	move.l	d0,-(sp)
	FDOS	GD_FSEEK,10
	pea	GS_ALIEN(a6)
	move.l	#ALIEN_SIZEOF,-(sp)
	move.w	4+4(sp),-(sp)
	FDOS	GD_FREAD,12
	cmp.l	#ALIEN_SIZEOF,d0
	bne	fatal
	FDOS	GD_FCLOSE,4		; (the handle pushed above)
.id:	move.w	d4,GS_ALIEN+ALIEN_ID(a6)
	movem.l	(sp)+,d3-d4
	rts

; comm.pas addtofile: append alien to TEMP\CONTACTS.DTA unless a record with its id is there
addtofile:
	movem.l	d3-d4,-(sp)
	move.w	#2,-(sp)		; read/write
	pea	cm_fn_contacts
	FDOS	GD_FOPEN,8
	move.w	d0,d3
	bmi	fatal
.r:	pea	cm_rec
	move.l	#ALIEN_SIZEOF,-(sp)
	move.w	d3,-(sp)
	FDOS	GD_FREAD,12
	cmp.l	#ALIEN_SIZEOF,d0
	bne.s	.end			; (end of file: append)
	move.w	cm_rec+ALIEN_ID,d0
	cmp.w	GS_ALIEN+ALIEN_ID(a6),d0
	bne.s	.r
	bra.s	.cl			; already there
.end:	move.w	#2,-(sp)		; Fseek(0, h, 2): the end
	move.w	d3,-(sp)
	clr.l	-(sp)
	FDOS	GD_FSEEK,10
	pea	GS_ALIEN(a6)
	move.l	#ALIEN_SIZEOF,-(sp)
	move.w	d3,-(sp)
	FDOS	GD_FWRITE,12
.cl:	move.w	d3,-(sp)
	FDOS	GD_FCLOSE,4
	movem.l	(sp)+,d3-d4
	rts

; comm.pas createwandering(order d0)
createwandering:
	movem.l	d3-d6/a3,-(sp)
	lea	GS_SHIP+SHIP_WANDERING(a6),a3
	move.w	d0,ONEALIEN_ORDERS(a3)
	move.w	GS_ALIEN+ALIEN_TECHMIN(a6),d0
	move.w	d0,ONEALIEN_TECHLEVEL(a3)
	moveq	#0,d4			; x := hi(techmin); y := lo(techmin)
	move.w	d0,d4
	lsr.w	#8,d4
	moveq	#0,d5
	move.b	d0,d5
	moveq	#4,d0			; i := 5+random(4)
	bsr	mt_random
	addq.w	#5,d0
	move.w	d0,d6
.l:	addq.w	#1,d5			; repeat inc(y) ... dec(i) until (i = 0) or (techlevel = techmax)
	cmp.w	#9,d5
	ble.s	.n
	addq.w	#1,d4
	moveq	#0,d5
	cmp.w	#6,d4
	ble.s	.n
	moveq	#6,d4
.n:	subq.w	#1,d6
	beq.s	.d
	move.w	ONEALIEN_TECHLEVEL(a3),d0
	cmp.w	GS_ALIEN+ALIEN_TECHMAX(a6),d0
	bne.s	.l
.d:	move.w	d6,cm_i
	lsl.w	#8,d4			; techlevel := x*256+y
	add.w	d5,d4
	move.w	d4,ONEALIEN_TECHLEVEL(a3)
	moveq	#11,d0			; congeniality := abs(alien.congeniality+random(11)-5)
	bsr	mt_random
	add.w	GS_ALIEN+ALIEN_CONGENIALITY(a6),d0
	subq.w	#5,d0
	bpl.s	.c
	neg.w	d0
.c:	move.w	d0,ONEALIEN_CONGENIALITY(a3)
	moveq	#11,d0			; anger := abs(alien.anger+random(11)-5)
	bsr	mt_random
	add.w	GS_ALIEN+ALIEN_ANGER(a6),d0
	subq.w	#5,d0
	bpl.s	.a
	neg.w	d0
.a:	move.w	d0,ONEALIEN_ANGER(a3)
	move.w	GS_ALIEN+ALIEN_ID(a6),ONEALIEN_ALIENID(a3)
	move.w	ONEALIEN_ORDERS(a3),d0	; where it turns up
	move.w	#3000,d3
	move.w	#10000,d4
	cmp.w	#WNDORDER_ATTACK,d0
	beq.s	.p
	move.w	#5000,d3
	move.w	#12000,d4
	cmp.w	#WNDORDER_RETREAT,d0
	beq.s	.p
	move.w	#3000,d3
	move.w	#2000,d4
	cmp.w	#WNDORDER_NONE,d0
	bne.s	.x
.p:	bsr.s	.coord
	move.w	d0,ONEALIEN_RELX(a3)
	bsr.s	.coord
	move.w	d0,ONEALIEN_RELY(a3)
	bsr.s	.coord
	move.w	d0,ONEALIEN_RELZ(a3)
.x:	movem.l	(sp)+,d3-d6/a3
	rts
.coord:	move.w	d4,d0			; base + random(range), negated if random(2) = 1
	bsr	mt_random
	add.w	d3,d0
	move.w	d0,-(sp)
	moveq	#2,d0
	bsr	mt_random
	move.w	d0,d1
	move.w	(sp)+,d0
	cmp.w	#1,d1
	bne.s	.cx
	neg.w	d0
.cx:	rts

	section	data
cm_fn_contacts:	dc.b	"TEMP",92,"CONTACTS.DTA",0
cm_fn_contact0:	dc.b	"DATA",92,"CONTACT0.DTA",0
	even

	section	bss
cm_rec:		ds.b	ALIEN_SIZEOF
cm_r:		ds.l	2
cm_i:		ds.w	1
	even
