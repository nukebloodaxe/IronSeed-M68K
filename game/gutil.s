; gutil.s - small helpers shared by the game's programs (include after the kernel).
;
; has_arg    in: a0 = command tail text, a1 = word (C string, upper case)  out: d0.w = 1 if present
;            trashes: d0-d2/a0-a2
; int_str    in: d0.l = value, d1.w = width, a0 = destination (Pascal string, room for 12)
;            Pascal str(value:width): right-aligned, '-' for negatives    trashes: d0-d2/a0-a1
; pstr_cat   in: a0 = destination Pascal string, a1 = Pascal string to append  trashes: d0-d1/a0-a2
; pstr_cpy   in: a0 = destination, a1 = source (Pascal strings)            trashes: d0/a0-a1
; pas_rnd10  in: d0.l = n  out: d0.l = round(n / 10) (Pascal round; no ties for the callers,
;            whose n/10 are multiples of 0.2)                              trashes: d1

	section	text
has_arg:
.s:	move.b	(a0),d0
	beq.s	.no
	cmp.b	#13,d0
	beq.s	.no
	move.l	a0,a2
	move.l	a1,d1
.cmp:	move.b	(a1)+,d0
	beq.s	.yes
	move.b	(a2)+,d2
	cmp.b	#'a',d2
	blo.s	.u
	sub.b	#32,d2
.u:	cmp.b	d0,d2
	beq.s	.cmp
	move.l	d1,a1
	addq.l	#1,a0
	bra.s	.s
.yes:	moveq	#1,d0
	rts
.no:	moveq	#0,d0
	rts

int_str:
	movem.l	d3-d4,-(sp)
	move.l	a0,a1			; a1 = string
	lea	gu_digits+24,a0		; digits built backwards
	moveq	#0,d3			; negative?
	tst.l	d0
	bpl.s	.p
	neg.l	d0
	moveq	#1,d3
.p:	moveq	#0,d4			; digit count
.d:	move.l	d0,d2			; 32-bit / 10 in two steps
	clr.w	d2
	swap	d2
	divu	#10,d2			; high word
	move.w	d2,-(sp)
	move.w	d0,d2
	divu	#10,d2			; (remainder:low) / 10
	swap	d2
	add.b	#'0',d2
	move.b	d2,-(a0)
	addq.w	#1,d4
	swap	d2
	move.w	(sp)+,d0
	swap	d0
	move.w	d2,d0
	tst.l	d0
	bne.s	.d
	tst.w	d3
	beq.s	.np
	move.b	#'-',-(a0)
	addq.w	#1,d4
.np:	move.w	d1,d0			; pad to the width
	sub.w	d4,d0
	ble.s	.nopad
	add.w	d0,d4
.pad:	move.b	#' ',-(a0)
	subq.w	#1,d0
	bne.s	.pad
.nopad:	move.b	d4,(a1)+
	subq.w	#1,d4
.cp:	move.b	(a0)+,(a1)+
	dbf	d4,.cp
	movem.l	(sp)+,d3-d4
	rts

pstr_cpy:
	moveq	#0,d0
	move.b	(a1),d0
.c:	move.b	(a1)+,(a0)+
	dbf	d0,.c
	rts

pstr_cat:
	moveq	#0,d0
	move.b	(a0),d0
	moveq	#0,d1
	move.b	(a1)+,d1
	add.b	d1,(a0)
	lea	1(a0,d0.w),a0
	subq.w	#1,d1
	bmi.s	.x
.c:	move.b	(a1)+,(a0)+
	dbf	d1,.c
.x:	rts

pas_rnd10:
	tst.l	d0
	bmi.s	.neg
	addq.l	#5,d0
	divu	#10,d0
	and.l	#$ffff,d0
	rts
.neg:	neg.l	d0
	addq.l	#5,d0
	divu	#10,d0
	and.l	#$ffff,d0
	neg.l	d0
	rts

	section	bss
gu_digits:	ds.b	24
	even
