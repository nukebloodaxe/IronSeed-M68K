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
;            the game font of txt_print, shaded unless txt_set_flat)  out: Z set when no pixel
;            changed (Phase 6k: known only for an opaque background)  trashes: d0-d2/a0-a2
; chk_fade   in: d0.w x1, d1.w y1, d2.w x2, d3.w y2, d4.w alt: utils.pas plainfadearea
;            (every index + alt, mod 256)                                 trashes: d0-d2/a0-a2
; chk_show   in: d1.w y1, d2.w y2: window rows y1..y2 (screen lines) to gfx_target, whole width
;            (hide the mouse cursor first, as for any drawing)            trashes: d0-d2/a0-a2
; No clipping: callers stay inside the window, as the original stayed inside the screen.

CHKPE	macro				; one glyph row at an even address (a1): written where it differs
	move.w	(a3)+,d0
	move.l	0(a2,d0.w),d1
	cmp.l	(a1),d1
	beq.s	.e\@
	move.l	d1,(a1)
	moveq	#1,d4
.e\@:	cmp.b	4(a1),d3		; the gap column
	beq.s	.g\@
	move.b	d3,4(a1)
	moveq	#1,d4
.g\@:	add.w	d5,a1
	endm
CHKPO	macro				; the same at an odd address: byte, word, byte
	move.w	(a3)+,d0
	move.l	0(a2,d0.w),d1
	move.l	d1,d2
	cmp.b	3(a1),d2
	bne.s	.w\@
	lsr.l	#8,d2
	cmp.w	1(a1),d2
	bne.s	.w\@
	swap	d2
	cmp.b	(a1),d2
	beq.s	.e\@
.w\@:	move.b	d1,3(a1)
	lsr.l	#8,d1
	move.w	d1,1(a1)
	swap	d1
	move.b	d1,(a1)
	moveq	#1,d4
.e\@:	cmp.b	4(a1),d3
	beq.s	.g\@
	move.b	d3,4(a1)
	moveq	#1,d4
.g\@:	add.w	d5,a1
	endm

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
	bra.s	.fnt
.game:	moveq	#0,d0
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_FONT-1(a6),d0
	cmp.w	#2,d0
	bls.s	.f
	moveq	#0,d0
.f:	mulu	#82*3,d0
	lea	txt_font,a4
	add.w	d0,a4
.fnt:	cmp.w	#255,GS_BKCOLOR(a6)	; (Phase 6k) opaque text on even rows: whole rows at once
	bhs.s	.char
	btst	#0,chk_w+1
	bne.s	.char
	bra	chk_printf
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
	moveq	#1,d0			; (Z clear: changed, as far as this path knows)
.done:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; chk_printf (Phase 6k): chk_print's fast path for an opaque background (bkcolor < 255) and an
; even window width - the same pixels. Per call a table of the 16 patterns of each glyph row
; (6 x 16 longs: the four pixels in the row's colour or bkcolor); per font a table of every
; character's six rows as offsets into it (chk_xfont, rebuilt when the font changes); each row
; is then one table read and one long (or, at an odd address, byte + word + byte) write, + the
; gap column. Entered from chk_print with its registers pushed: d7 = length-1, a5 = the text,
; d5 = first glyph row, d6 = first glyph column, a4 = the font.
chk_printf:
	cmp.l	chk_xfp,a4
	beq.s	.fok
	bsr	chk_xbuild
.fok:	move.w	GS_BKCOLOR(a6),d0	; the rows' patterns
	bsr	chk_rep4
	move.l	d0,d3			; bkcolor x 4
	move.w	GS_TCOLOR(a6),d0	; (the same colours as the last call: the table is still right)
	cmp.w	chk_pkey,d0
	bne.s	.nk
	move.w	GS_BKCOLOR(a6),d0
	cmp.w	chk_pkey+2,d0
	bne.s	.nk
	move.w	txt_flat,d0
	cmp.w	chk_pkey+4,d0
	beq.s	.tok
.nk:	move.w	GS_TCOLOR(a6),chk_pkey
	move.w	GS_BKCOLOR(a6),chk_pkey+2
	move.w	txt_flat,chk_pkey+4
	movem.w	d5-d6,-(sp)
	lea	chk_ptab,a1
	move.w	GS_TCOLOR(a6),d4
	moveq	#6-1,d5
.tr:	move.w	d4,d0
	bsr	chk_rep4
	eor.l	d3,d0			; (fg ^ bk) x 4
	lea	chk_pmask,a0
	moveq	#16-1,d1
.tn:	move.l	(a0)+,d6
	and.l	d0,d6
	eor.l	d3,d6
	move.l	d6,(a1)+
	dbf	d1,.tn
	tst.w	txt_flat
	bne.s	.tf
	subq.w	#2,d4			; tcolor - 2*row
.tf:	dbf	d5,.tr
	movem.w	(sp)+,d5-d6
.tok:	move.w	d6,d0
	move.w	d5,d1
	bsr	chk_addr		; a0 = top-left pixel of the first glyph
	move.w	chk_w,d5
	lea	chk_ptab,a2
	lea	chk_xfont,a4
	moveq	#0,d4			; (anything changed: ms_print marks only then)
.ch:	moveq	#0,d0
	move.b	(a5)+,d0
	lsl.w	#2,d0			; char * 12: its six rows
	move.w	d0,d1
	add.w	d0,d0
	add.w	d1,d0
	lea	0(a4,d0.w),a3
	move.l	a0,a1
	move.w	a1,d0
	btst	#0,d0
	bne	.odd
	rept	6
	CHKPE
	endr
	addq.l	#5,a0
	dbf	d7,.ch
	bra	.x
.odd:
	rept	6
	CHKPO
	endr
	addq.l	#5,a0
	dbf	d7,.ch
.x:	tst.w	d4			; Z: nothing changed
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; d0.b -> d0.l = that byte four times   trashes: d1
chk_rep4:
	and.w	#$ff,d0
	move.w	d0,d1
	lsl.w	#8,d1
	or.w	d1,d0
	move.w	d0,d1
	swap	d0
	move.w	d1,d0
	rts

; chk_xbuild: chk_xfont for the font at a4: per character code (txt_letter's glyph) its six rows
; as row*64 + nibble*4 (offsets into chk_ptab).  trashes: d0-d2/a0-a1
chk_xbuild:
	movem.l	d3-d4,-(sp)
	move.l	a4,chk_xfp
	lea	chk_xfont,a1
	moveq	#0,d3			; character code
.c:	move.w	d3,d0
	bsr	txt_letter
	subq.w	#1,d0
	mulu	#3,d0
	lea	0(a4,d0.w),a0		; glyph
	moveq	#0,d4			; row
.r:	move.w	d4,d0
	lsr.w	#1,d0
	move.b	0(a0,d0.w),d0
	btst	#0,d4
	bne.s	.lo
	lsr.b	#4,d0
.lo:	and.w	#15,d0
	lsl.w	#2,d0
	move.w	d4,d1
	lsl.w	#6,d1
	add.w	d1,d0
	move.w	d0,(a1)+
	addq.w	#1,d4
	cmp.w	#6,d4
	bne.s	.r
	addq.w	#1,d3
	cmp.w	#256,d3
	bne.s	.c
	movem.l	(sp)+,d3-d4
	rts

	section	data
chk_pmask:				; per nibble: $ff in the bytes of its set pixels (bit 3 = first)
	dc.l	$00000000,$000000ff,$0000ff00,$0000ffff,$00ff0000,$00ff00ff,$00ffff00,$00ffffff
	dc.l	$ff000000,$ff0000ff,$ff00ff00,$ff00ffff,$ffff0000,$ffff00ff,$ffffff00,$ffffffff
chk_xfp:	dc.l	0		; the font chk_xfont was built for
chk_pkey:	dc.w	-1,-1,-1	; tcolor, bkcolor, txt_flat chk_ptab was built for

	section	bss
chk_ptab:	ds.l	6*16
chk_xfont:	ds.w	256*6
chk_buf:	ds.l	1
chk_x0:		ds.w	1
chk_y0:		ds.w	1
chk_w:		ds.w	1
chk_h:		ds.w	1
