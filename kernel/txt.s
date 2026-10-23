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
; txt_mask    in: a0 = Pascal string: renders it once (current font) into a 1-bit mask
;             for txt_mdraw. trashes: d0-d2/a0-a2
; txt_mdraw   in: d0.w x1, d1.w y1, d2.w colour: the masked string at x1, y1 exactly as
;             txt_print draws it flat (txt_set_flat 1) and transparent (bkcolor 255), but
;             ~20x faster: for text drawn again and again (writestr2's trails).
;             trashes: d0-d2/a0-a2
;  txt_fast   in: d0.w x1, d1.w y1, a0 = Pascal string: exactly txt_print (shaded or flat,
;             bkcolor opaque or 255 transparent), but a whole row of the string at a time from
;             a txt_mask mask: ~5x faster for long lines. trashes: d0-d2/a0-a2
; Needs GS_TCOLOR, GS_BKCOLOR, GS_SHIP, SHIP_OPTIONS (layout.i).

	ifnd	OPT_FONT
OPT_FONT	equ	7
	endif

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

; ---------------------------------------------------------------
; mask: 6 rows x TXT_MW words; bit index = pixel - (x1+4) (one spare column on the left for
; chr(2)'s step back), MSB first in each word.
TXT_MW		equ	82		; 255 chars x 5 + 2 bits, + 1 spare word for the shift
txt_mask:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	txt_mbuf,a1		; clear
	move.w	#6*TXT_MW/2-1,d0
.cl:	clr.l	(a1)+
	dbf	d0,.cl
	moveq	#0,d7
	move.b	(a0)+,d7
	move.w	d7,d0			; words used: (5*len + 2 + 15) / 16, + 1 for the shift
	mulu	#5,d0
	add.w	#2+15,d0
	lsr.w	#4,d0
	addq.w	#1,d0
	move.w	d0,txt_mwords
	tst.w	d7
	beq	.done
	subq.w	#1,d7
	move.l	a0,a5
	moveq	#1,d6			; bit position of the first glyph column
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
	cmp.l	#txt_font_intro,a4
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
.nc:	bsr	txt_letter
.gl:	subq.w	#1,d0
	mulu	#3,d0
	lea	0(a4,d0.w),a3
	move.w	d6,d1			; word offset and shift of this column
	lsr.w	#4,d1
	add.w	d1,d1
	lea	txt_mbuf,a2
	add.w	d1,a2
	move.w	d6,d5
	and.w	#15,d5
	neg.w	d5
	add.w	#27,d5			; shift = 27 - (pos & 15)
	moveq	#0,d4			; row
.row:	move.w	d4,d0
	lsr.w	#1,d0
	move.b	0(a3,d0.w),d0
	btst	#0,d4
	bne.s	.lo
	lsr.b	#4,d0
.lo:	and.l	#15,d0
	beq.s	.nr
	add.w	d0,d0
	lsl.l	d5,d0
	or.l	d0,(a2)
.nr:	lea	2*TXT_MW(a2),a2
	addq.w	#1,d4
	cmp.w	#6,d4
	bne.s	.row
	addq.w	#5,d6
	dbf	d7,.char
.done:	movem.l	(sp)+,d3-d7/a3-a5
	rts

txt_mdraw:
	movem.l	d3-d7/a3-a5,-(sp)
	addq.w	#4,d0			; mask bit 0 = x1 + 4
	move.w	d0,d6
	and.w	#15,d6			; shift
	lsr.w	#4,d0
	move.w	d0,d7			; first group
	move.w	d2,d5			; colour
	and.w	#$ff,d5
	lea	txt_mbuf,a3
	move.w	d1,d4
	addq.w	#1,d4			; y = y1 + 1
	moveq	#6-1,d3
.row:	move.w	d4,d1
	bsr	vid_lut_y
	move.b	0(a1,d5.w),d2		; slot
	move.l	gfx_target,a0
	move.w	d4,d0			; y * 160
	lsl.w	#5,d0
	move.w	d0,d1
	add.w	d0,d0
	add.w	d0,d0
	add.w	d1,d0
	add.w	d0,a0
	move.w	d7,d0
	lsl.w	#3,d0
	add.w	d0,a0			; first group
	move.l	a3,a2
	move.w	txt_mwords,d1
	subq.w	#1,d1
	move.w	d7,a4			; group number (edge test)
	moveq	#0,d0			; prev:cur
.grp:	swap	d0
	move.w	(a2)+,d0
	move.l	d0,a5
	lsr.l	d6,d0			; low word = this group's pixels
	tst.w	d0
	beq.s	.next
	cmp.w	#20,a4
	bhs.s	.next
	btst	#0,d2
	beq.s	.c0
	or.w	d0,(a0)
	bra.s	.p1
.c0:	not.w	d0
	and.w	d0,(a0)
	not.w	d0
.p1:	btst	#1,d2
	beq.s	.c1
	or.w	d0,2(a0)
	bra.s	.p2
.c1:	not.w	d0
	and.w	d0,2(a0)
	not.w	d0
.p2:	btst	#2,d2
	beq.s	.c2
	or.w	d0,4(a0)
	bra.s	.p3
.c2:	not.w	d0
	and.w	d0,4(a0)
	not.w	d0
.p3:	btst	#3,d2
	beq.s	.c3
	or.w	d0,6(a0)
	bra.s	.next
.c3:	not.w	d0
	and.w	d0,6(a0)
.next:	move.l	a5,d0
	addq.l	#8,a0
	addq.w	#1,a4
	dbf	d1,.grp
	lea	2*TXT_MW(a3),a3
	addq.w	#1,d4
	dbf	d3,.row
	movem.l	(sp)+,d3-d7/a3-a5
	rts

txt_fast:
	movem.l	d3-d7/a3-a5,-(sp)
	movem.w	d0-d1,-(sp)
	moveq	#0,d7
	move.b	(a0),d7			; length
	bsr	txt_mask
	; touched pixels (bkcolor): bits 1 .. 5*len of the same layout
	lea	txt_tbuf,a1
	move.w	txt_mwords,d0
	subq.w	#1,d0
.tc:	clr.w	(a1)+
	dbf	d0,.tc
	move.w	GS_BKCOLOR(a6),d0
	cmp.w	#255,d0
	bhs.s	.not
	mulu	#5,d7			; bits 1 .. 5*len
	moveq	#1,d0
	lea	txt_tbuf,a1
.tb:	cmp.w	d7,d0
	bgt.s	.not
	move.w	d0,d1
	lsr.w	#4,d1
	add.w	d1,d1
	move.w	d0,d2
	and.w	#15,d2
	not.w	d2			; bit 15 - (pos & 15) (MSB first)
	and.w	#15,d2
	move.w	0(a1,d1.w),d3
	bset	d2,d3
	move.w	d3,0(a1,d1.w)
	addq.w	#1,d0
	bra.s	.tb
.not:	movem.w	(sp)+,d0-d1
	addq.w	#4,d0			; mask bit 0 = x1 + 4
	move.w	d0,d6
	and.w	#15,d6			; shift
	lsr.w	#4,d0
	move.w	d0,d7			; first group
	move.w	d1,d4
	addq.w	#1,d4			; y = y1 + 1
	lea	txt_mbuf,a3
	moveq	#0,d3			; row
.row:	move.w	d4,d1
	bsr	vid_lut_y
	move.w	GS_TCOLOR(a6),d0
	tst.w	txt_flat
	bne.s	.fl
	sub.w	d3,d0
	sub.w	d3,d0
.fl:	and.w	#$ff,d0
	move.b	0(a1,d0.w),d5		; fg slot
	move.w	GS_BKCOLOR(a6),d0
	moveq	#0,d2			; bg slot (unused when transparent)
	cmp.w	#255,d0
	bhs.s	.nb
	move.b	0(a1,d0.w),d2
.nb:	lsl.w	#8,d2
	move.b	d5,d2
	move.w	d2,txt_fb		; bg slot << 8 | fg slot
	move.l	gfx_target,a0
	move.w	d4,d0			; y * 160
	lsl.w	#5,d0
	move.w	d0,d1
	add.w	d0,d0
	add.w	d0,d0
	add.w	d1,d0
	add.w	d0,a0
	move.w	d7,d0
	lsl.w	#3,d0
	add.w	d0,a0
	move.l	a3,a2			; glyph mask row
	lea	txt_tbuf,a5		; touched mask
	move.w	txt_mwords,d1
	subq.w	#1,d1
	move.w	d7,a4			; group number
	moveq	#0,d0			; prev:cur glyph
	moveq	#0,d5			; prev:cur touched
.grp:	swap	d0
	move.w	(a2)+,d0
	swap	d5
	move.w	(a5)+,d5
	movem.l	d0/d5,-(sp)
	lsr.l	d6,d0			; glyph bits of this group
	lsr.l	d6,d5			; touched bits
	or.w	d0,d5			; written = touched | glyph
	beq	.next
	cmp.w	#20,a4
	bhs	.next
	move.w	d5,d2		; background bits = written & ~glyph, kept in d0's high word
	not.w	d0
	and.w	d0,d2
	not.w	d0
	swap	d0
	move.w	d2,d0
	swap	d0
	not.w	d5			; keep mask
	move.w	txt_fb,d2		; bg slot << 8 | fg slot
	rept	4
	and.w	d5,(a0)
	btst	#0,d2
	beq.s	*+4
	or.w	d0,(a0)
	btst	#8,d2
	beq.s	*+8
	swap	d0
	or.w	d0,(a0)
	swap	d0
	addq.l	#2,a0
	lsr.w	#1,d2
	endr
	subq.l	#8,a0
.next:	movem.l	(sp)+,d0/d5
	addq.l	#8,a0
	addq.w	#1,a4
	dbf	d1,.grp
	lea	2*TXT_MW(a3),a3
	addq.w	#1,d4
	addq.w	#1,d3
	cmp.w	#6,d3
	bne	.row
	movem.l	(sp)+,d3-d7/a3-a5
	rts

	section	bss
txt_fontptr:	ds.l	1
txt_flat:	ds.w	1
txt_mwords:	ds.w	1
txt_mbuf:	ds.w	6*TXT_MW
txt_tbuf:	ds.w	TXT_MW
txt_fb:		ds.w	1

	section	data
	include	"font.i"
	even
