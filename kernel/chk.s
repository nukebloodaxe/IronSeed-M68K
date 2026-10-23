; chk.s - a chunky window: one rectangle of the screen kept as game colour indices, for drawing
; that reads pixels back or changes them by index arithmetic (saveload.pas's dialogs use
; plainfadearea for their cursor). Draw into the window, then chk_show the rows that changed:
; they go to gfx_target through each line's LUT. Part of kernel.s.
;
; chk_open   in: a0 = buffer (w * h bytes), d0.w x0, d1.w y0, d2.w w, d3.w h (screen position)
; chk_bar    in: d0.w x1, d1.w y1, d2.w x2, d3.w y2 (screen coordinates, inclusive), d4.b colour
;            trashes: d0-d2/a0-a2
; chk_pset   in: d0.w x, d1.w y, d2.b colour                              trashes: d0-d2/a0
; chk_get    in: d0.w x, d1.w y   out: d0.w = index                       trashes: d1/a0
; chk_print  in: d0.w x1, d1.w y1, a0 = Pascal string: data.pas printxy (tcolor/bkcolor from GS,
;            the game font of txt_print, shaded unless txt_set_flat)      trashes: d0-d2/a0-a2
; chk_fade   in: d0.w x1, d1.w y1, d2.w x2, d3.w y2, d4.w alt: utils.pas plainfadearea
;            (every index + alt, mod 256)                                 trashes: d0-d2/a0-a2
; chk_show   in: d1.w y1, d2.w y2: window rows y1..y2 (screen lines) to gfx_target, whole width
;            (hide the mouse cursor first, as for any drawing)            trashes: d0-d2/a0-a2
; No clipping: callers stay inside the window, as the original stayed inside the screen.

	section	text
chk_open:
	move.l	a0,chk_buf
	move.w	d0,chk_x0
	move.w	d1,chk_y0
	move.w	d2,chk_w
	move.w	d3,chk_h
	rts

; a0 = address of (d0, d1)   trashes: d1
chk_addr:
	move.w	d1,-(sp)
	sub.w	chk_y0,d1
	mulu	chk_w,d1
	move.l	chk_buf,a0
	add.l	d1,a0
	move.w	d0,d1
	sub.w	chk_x0,d1
	add.w	d1,a0
	move.w	(sp)+,d1
	rts

chk_pset:
	move.w	d1,-(sp)
	bsr.s	chk_addr
	move.b	d2,(a0)
	move.w	(sp)+,d1
	rts

chk_get:
	bsr.s	chk_addr
	moveq	#0,d0
	move.b	(a0),d0
	rts

chk_bar:
	movem.l	d3-d5,-(sp)
	cmp.w	d1,d3
	bge.s	.y
	exg	d1,d3
.y:	cmp.w	d0,d2
	bge.s	.x
	exg	d0,d2
.x:	bsr.s	chk_addr
	sub.w	d0,d2			; columns - 1
	sub.w	d1,d3			; rows - 1
	move.w	chk_w,d5
	sub.w	d2,d5
	subq.w	#1,d5			; skip to the next row
.r:	move.w	d2,d1
.c:	move.b	d4,(a0)+
	dbf	d1,.c
	add.w	d5,a0
	dbf	d3,.r
	movem.l	(sp)+,d3-d5
	rts

chk_fade:
	movem.l	d3-d5,-(sp)
	bsr.s	chk_addr
	sub.w	d0,d2
	sub.w	d1,d3
	move.w	chk_w,d5
	sub.w	d2,d5
	subq.w	#1,d5
.r:	move.w	d2,d1
.c:	add.b	d4,(a0)+
	dbf	d1,.c
	add.w	d5,a0
	dbf	d3,.r
	movem.l	(sp)+,d3-d5
	rts

chk_show:
	movem.l	d3-d4,-(sp)
	move.w	d1,d3
	move.w	d2,d4
.l:	move.w	d3,d1
	moveq	#0,d0
	bsr.s	chk_addr_row
	move.w	chk_x0,d0
	move.w	d3,d1
	move.w	chk_w,d2
	bsr	gfx_chunky_span
	addq.w	#1,d3
	cmp.w	d4,d3
	ble.s	.l
	movem.l	(sp)+,d3-d4
	rts
chk_addr_row:				; a0 = start of window row d1
	sub.w	chk_y0,d1
	mulu	chk_w,d1
	move.l	chk_buf,a0
	add.l	d1,a0
	rts

chk_print:
	movem.l	d3-d7/a3-a5,-(sp)
	moveq	#0,d7
	move.b	(a0)+,d7
	beq	.done
	subq.w	#1,d7
	move.l	a0,a5
	move.w	d1,d5			; y1
	addq.w	#1,d5			; first glyph row
	move.w	d0,d6
	addq.w	#5,d6			; first glyph column
	move.l	txt_fontptr,d0
	beq.s	.game
	move.l	d0,a4
	bra.s	.char
.game:	moveq	#0,d0
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_FONT-1(a6),d0
	cmp.w	#2,d0
	bls.s	.f
	moveq	#0,d0
.f:	mulu	#82*3,d0
	lea	txt_font,a4
	add.w	d0,a4
.char:	moveq	#0,d0
	move.b	(a5)+,d0
	bsr	txt_letter
	subq.w	#1,d0
	mulu	#3,d0
	lea	0(a4,d0.w),a3		; glyph
	move.w	d6,d0
	move.w	d5,d1
	bsr	chk_addr		; a0 = top-left glyph pixel
	moveq	#0,d4			; row
.row:	move.w	d4,d0
	lsr.w	#1,d0
	move.b	0(a3,d0.w),d0
	btst	#0,d4
	bne.s	.lo
	lsr.b	#4,d0
.lo:	move.w	GS_TCOLOR(a6),d2
	tst.w	txt_flat
	bne.s	.fl
	sub.w	d4,d2
	sub.w	d4,d2			; tcolor - 2*row
.fl:	move.w	GS_BKCOLOR(a6),d3
	moveq	#4-1,d1
.px:	btst	#3,d0
	beq.s	.bg
	move.b	d2,(a0)+
	bra.s	.nx
.bg:	cmp.w	#255,d3
	bhs.s	.tr
	move.b	d3,(a0)+
	bra.s	.nx
.tr:	addq.l	#1,a0
.nx:	add.b	d0,d0
	dbf	d1,.px
	cmp.w	#255,d3			; the gap column
	bhs.s	.ng
	move.b	d3,(a0)
.ng:	subq.l	#4,a0
	add.w	chk_w,a0
	addq.w	#1,d4
	cmp.w	#6,d4
	bne.s	.row
	addq.w	#5,d6
	dbf	d7,.char
.done:	movem.l	(sp)+,d3-d7/a3-a5
	rts

	section	bss
chk_buf:	ds.l	1
chk_x0:		ds.w	1
chk_y0:		ds.w	1
chk_w:		ds.w	1
chk_h:		ds.w	1
