; txt.s - the game's 4x6 shaded font (port of data.pas printxy). Part of kernel.s.
;
; txt_print   in: d0.w x1, d1.w y1, a0 = Pascal string (length byte + chars)
;             colours from the globals tcolor (top row; each row 2 darker, as the
;             original) and bkcolor (255 = transparent); font = ship.options[OPT_FONT].
;             Glyph pixels at x1+5.., rows y1+1..y1+6, 5 pixels per character.
;             trashes: d0-d2/a0-a2
; txt_set_flat  in: d0.w = 1: every row in tcolor (intro.pas printxy2), 0: shaded (printxy)
; txt_set_font  in: a0 = font table (3 bytes per glyph), or 0 for the game font chosen in
;               ship.options[OPT_FONT]. txt_font_intro selects intro.pas's font, which also
;               draws chr(1)/chr(2) as the two halves of a (c) sign (glyphs 83/84; chr(2)
;               moves one pixel left, as in intro.pas printxy).
; Needs GS_TCOLOR, GS_BKCOLOR, GS_SHIP, SHIP_OPTIONS (layout.i).

OPT_FONT	equ	7

	section	text
txt_print:
	movem.l	d3-d7/a3-a5,-(sp)
	moveq	#0,d7
	move.b	(a0)+,d7		; length
	beq	.done
	subq.w	#1,d7
	move.l	a0,a5			; chars
	move.w	d0,d6
	addq.w	#5,d6			; x of the first glyph column (x1+4+1)
	move.w	d1,d5			; y1
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
	add.w	d0,a4			; this font
.char:	moveq	#0,d0
	move.b	(a5)+,d0
	cmp.l	#txt_font_intro,a4	; intro font: chr(1) / chr(2) = (c) sign
	bne.s	.nc
	cmp.b	#1,d0
	bne.s	.c2
	moveq	#83,d0
	bra.s	.gl
.c2:	cmp.b	#2,d0
	bne.s	.nc
	moveq	#84,d0
	subq.w	#1,d6
	bra.s	.gl
.nc:	bsr	txt_letter		; d0 -> glyph index 1..82
.gl:
	subq.w	#1,d0
	mulu	#3,d0
	lea	0(a4,d0.w),a3		; 3 glyph bytes
	moveq	#0,d4			; row 0..5
.row:	move.w	d4,d0
	lsr.w	#1,d0
	move.b	0(a3,d0.w),d0		; byte with this row pair
	btst	#0,d4
	bne.s	.lo
	lsr.b	#4,d0
.lo:	and.w	#15,d0
	add.w	d0,d0			; 4 glyph bits + an empty gap column = 5-pixel field
	move.w	d5,d1
	add.w	d4,d1
	addq.w	#1,d1			; y = y1 + 1 + row
	move.w	GS_TCOLOR(a6),d2
	move.w	d4,d3
	add.w	d3,d3
	tst.w	txt_flat
	bne.s	.flat
	sub.w	d3,d2			; tcolor - 2*row
.flat:
	bsr	txt_row
	addq.w	#1,d4
	cmp.w	#6,d4
	bne.s	.row
	addq.w	#5,d6
	dbf	d7,.char
.done:	movem.l	(sp)+,d3-d7/a3-a5
	rts

txt_set_font:
	move.l	a0,txt_fontptr
	rts

txt_set_flat:
	move.w	d0,txt_flat
	rts

; d0.b = char -> d0.w = glyph index (printxy's case statement)
txt_letter:
	cmp.b	#'a',d0
	blo.s	.u
	cmp.b	#'z',d0
	bhi.s	.other
	sub.w	#40,d0
	rts
.u:	cmp.b	#'A',d0
	blo.s	.p
	cmp.b	#'Z',d0
	bhi.s	.other
	sub.w	#36,d0
	rts
.p:	cmp.b	#' ',d0
	blo.s	.other
	cmp.b	#'"',d0
	bhi.s	.q
	sub.w	#31,d0
	rts
.q:	cmp.b	#'%',d0
	bne.s	.r
	moveq	#55,d0
	rts
.r:	cmp.b	#$27,d0			; '''
	blo.s	.other
	cmp.b	#'?',d0
	bhi.s	.other
	sub.w	#35,d0
	rts
.other:	moveq	#1,d0
	rts

; one 5-pixel row: d0.w = field (bit 4 = leftmost pixel), d1.w = y, d2.w = fg colour,
; d6.w = x of the leftmost pixel. bkcolor from GS. Uses d0-d3/a0-a2 + saves nothing else.
txt_row:
	movem.l	d4-d7,-(sp)
	bsr	vid_lut_y		; a1 = LUT
	and.w	#$ff,d2
	move.b	0(a1,d2.w),d2		; fg slot
	move.w	GS_BKCOLOR(a6),d3
	cmp.w	#255,d3
	bhs.s	.nobk
	move.b	0(a1,d3.w),d3		; bg slot
	moveq	#%11111,d5		; touched pixels: all 5
	bra.s	.pos
.nobk:	moveq	#0,d5			; transparent: only the glyph pixels
	move.w	d0,d5
	moveq	#0,d3
.pos:	move.l	gfx_target,a0
	mulu	#SCR_BPL,d1
	add.l	d1,a0
	move.w	d6,d1
	lsr.w	#4,d1
	move.w	d1,d7			; group
	lsl.w	#3,d1
	add.w	d1,a0
	move.w	d6,d1
	and.w	#15,d1
	neg.w	d1
	add.w	#27,d1			; shift = 27 - (x & 15)
	moveq	#0,d4
	move.w	d0,d4
	lsl.l	d1,d4			; fg bits (long: high word = group, low word = next group)
	and.l	#$ffff,d5
	lsl.l	d1,d5			; touched bits
	move.l	d5,d6
	eor.l	d4,d6			; bg bits = touched & ~fg
	not.l	d5			; keep mask
	moveq	#4-1,d1
.pl:	moveq	#0,d0			; bits to set in this plane
	lsr.b	#1,d2
	bcc.s	.nf
	or.l	d4,d0
.nf:	lsr.b	#1,d3
	bcc.s	.nb
	or.l	d6,d0
.nb:	swap	d5
	swap	d0
	and.w	d5,(a0)
	or.w	d0,(a0)
	swap	d5
	swap	d0
	cmp.w	#19,d7
	beq.s	.edge
	and.w	d5,8(a0)
	or.w	d0,8(a0)
.edge:	addq.l	#2,a0
	dbf	d1,.pl
	movem.l	(sp)+,d4-d7
	rts

	section	bss
txt_fontptr:	ds.l	1
txt_flat:	ds.w	1

	section	data
	include	"font.i"
	even
