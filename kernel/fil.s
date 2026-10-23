; fil.s - files (GEMDOS; main code only, never from interrupts). Part of kernel.s.
;
; fil_load   in: a0 = name (C string), a1 = buffer, d0.l = max bytes
;            out: d0.l = bytes read; carry set + d0 = TOS error if it failed
;            trashes: d0-d2/a0-a2
; fil_save   in: a0 = name, a1 = data, d0.l = bytes   out: carry set on error
; fil_size   in: a0 = name   out: d0.l = size (carry set if missing)

	section	text
fil_load:
	movem.l	d3-d4/a3,-(sp)
	move.l	a1,a3
	move.l	d0,d4
	clr.w	-(sp)			; Fopen(name, read)
	move.l	a0,-(sp)
	GEMDOS	GD_FOPEN,8
	tst.l	d0
	bmi.s	.err
	move.w	d0,d3
	move.l	a3,-(sp)		; Fread(h, max, buf)
	move.l	d4,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FREAD,12
	move.l	d0,d4
	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
	move.l	d4,d0
	bmi.s	.err
	movem.l	(sp)+,d3-d4/a3
	and.b	#$fe,ccr
	rts
.err:	movem.l	(sp)+,d3-d4/a3
	or.b	#1,ccr
	rts

fil_save:
	movem.l	d3-d4/a3,-(sp)
	move.l	a1,a3
	move.l	d0,d4
	clr.w	-(sp)			; Fcreate(name, 0)
	move.l	a0,-(sp)
	GEMDOS	GD_FCREATE,8
	tst.l	d0
	bmi.s	.err
	move.w	d0,d3
	move.l	a3,-(sp)
	move.l	d4,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FWRITE,12
	move.l	d0,d4
	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
	tst.l	d4
	bmi.s	.err
	movem.l	(sp)+,d3-d4/a3
	and.b	#$fe,ccr
	rts
.err:	movem.l	(sp)+,d3-d4/a3
	or.b	#1,ccr
	rts

fil_size:
	move.l	d3,-(sp)
	clr.w	-(sp)
	move.l	a0,-(sp)
	GEMDOS	GD_FOPEN,8
	tst.l	d0
	bmi.s	.err
	move.w	d0,d3
	move.w	#2,-(sp)		; Fseek(0, h, end)
	move.w	d3,-(sp)
	clr.l	-(sp)
	GEMDOS	GD_FSEEK,10
	move.l	d0,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
	move.l	(sp)+,d0
	move.l	(sp)+,d3
	and.b	#$fe,ccr
	rts
.err:	move.l	(sp)+,d3
	or.b	#1,ccr
	rts
