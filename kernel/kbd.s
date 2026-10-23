; kbd.s - IKBD mouse, keyboard, software mouse cursor. Part of kernel.s.
;
; kbd_mouse_xy      out: d0.w = x (0-319), d1.w = y (0-199)
; kbd_mouse_status  out: d0.b = buttons pressed since the last call (bit 0 left, bit 1 right),
;                   then clears them (= original mouse_get_status)
; kbd_mouse_move    in: d0.w = x, d1.w = y (original move_mouse)
; kbd_keypressed    out: d0.b = 1 if a key is waiting (Z clear), else 0  trashes: d0-d2/a0-a2
; kbd_readkey       out: d0.b = key; extended keys (arrows, F-keys) return 0 then the scan
;                   code on the next call, like the DOS/SDL version  trashes: d0-d2/a0-a2
; kbd_cursor_set    in: a0 = 256 bytes, 16x16 game colour indices, 255 = transparent
;                   (original mousesetcursor; the game takes these from weapicon.dta)
;                   The cursor is mapped through each band's LUT (one variant per band), so
;                   it keeps its colours across raster splits; rebuilt when LUTs change.
; kbd_cursor_show / kbd_cursor_hide  (original mouseshow / mousehide)
; The cursor is drawn by the VBL on the displayed screen with save-under; drawing code
; must hide it while drawing under it (as the original did with mousehide/mouseshow).

KBD_VAR		equ	16*2+16*4*2	; one cursor variant: 16 mask words + 16 x 4 plane words

	section	text
kbd_init:
	move.w	#160,kbd_mx
	move.w	#100,kbd_my
	move.l	sys_kbdv,a0
	move.l	16(a0),kbd_oldmouse
	move.l	#kbd_mouse_handler,16(a0)
	lea	kbd_default_cursor,a0
	bsr	kbd_cursor_set
	rts

kbd_exit:
	bsr	kbd_cursor_hide
	move.l	sys_kbdv,a0
	move.l	kbd_oldmouse,16(a0)
	rts

; called by TOS's IKBD code, a0 = relative mouse packet ($F8-$FB, dx, dy)
kbd_mouse_handler:
	tst.w	scr_vtime		; scripted runs in virtual time: only the script moves it
	bne.s	.ign
	movem.l	d0-d1,-(sp)
	move.b	(a0),d0
	moveq	#0,d1
	btst	#1,d0			; left button
	beq.s	.nl
	moveq	#1,d1
.nl:	btst	#0,d0			; right button
	beq.s	.nr
	or.b	#2,d1
.nr:	move.b	kbd_mbuttons,d0
	not.b	d0
	and.b	d1,d0			; newly pressed
	or.b	d0,kbd_mclick
	move.b	d1,kbd_mbuttons
	move.b	1(a0),d0
	ext.w	d0
	add.w	kbd_mx,d0
	bpl.s	.x0
	moveq	#0,d0
.x0:	cmp.w	#SCR_W-1,d0
	ble.s	.x1
	move.w	#SCR_W-1,d0
.x1:	move.w	d0,kbd_mx
	move.b	2(a0),d0
	ext.w	d0
	add.w	kbd_my,d0
	bpl.s	.y0
	moveq	#0,d0
.y0:	cmp.w	#SCR_H-1,d0
	ble.s	.y1
	move.w	#SCR_H-1,d0
.y1:	move.w	d0,kbd_my
	movem.l	(sp)+,d0-d1
.ign:	rts

kbd_mouse_xy:
	tst.w	scr_vtime		; (the Linux oracle reads the position without a script step)
	bne.s	.v
	bsr	scr_tick
.v:	move.w	kbd_mx,d0
	move.w	kbd_my,d1
	rts

kbd_mouse_status:
	bsr	scr_poll
	DI
	move.b	kbd_mclick,d0
	clr.b	kbd_mclick
	EI
	rts

kbd_mouse_move:
	move.w	d0,kbd_mx
	move.w	d1,kbd_my
	rts

kbd_keypressed:
	bsr	scr_poll
	tst.b	scr_key
	bne.s	.yes
	tst.b	kbd_pending
	bne.s	.yes
	move.w	#2,-(sp)
	BIOS	BI_BCONSTAT,4
	tst.w	d0
	beq.s	.no
.yes:	moveq	#1,d0
	rts
.no:	moveq	#0,d0
	rts

kbd_readkey:
	move.b	kbd_pending,d0
	beq.s	.scr
	clr.b	kbd_pending
	rts
.scr:	move.b	scr_key,d0		; scripted key?
	beq.s	.read
	clr.b	scr_key
	cmp.b	#$ff,d0
	bne.s	.x
	move.b	scr_ext,kbd_pending	; extended: 0 now, scan code next
	moveq	#0,d0
	rts
.read:	move.w	#2,-(sp)
	BIOS	BI_BCONIN,4
	tst.b	d0
	bne.s	.x
	swap	d0			; ASCII 0: extended key, scan code next time
	move.b	d0,kbd_pending
	moveq	#0,d0
.x:	rts

; ---------------------------------------------------------------
; cursor: keep the source icon, build one mask+planes variant per band
kbd_cursor_set:
	lea	kbd_cur_src,a1
	moveq	#256/4-1,d0
.cp:	move.l	(a0)+,(a1)+
	dbf	d0,.cp
	move.w	#1,kbd_cur_ready
	; fall through
kbd_cursor_build:
	tst.w	kbd_cur_ready
	beq	.none
	movem.l	d3-d7/a3-a4,-(sp)
	move.w	kbd_cur_on,-(sp)
	bsr	kbd_cursor_hide
	lea	kbd_cur_var,a2		; 4 x (16 mask words + 64 plane words)
	lea	vid_luts,a3
	moveq	#4-1,d6			; bands
.band:	lea	kbd_cur_src,a0
	lea	32(a2),a4		; planes after the 16 mask words
	moveq	#16-1,d5		; rows
.row:	moveq	#0,d1			; mask
	moveq	#0,d2			; plane 0 (high word) / plane 1 (low word)
	moveq	#0,d3			; plane 2 / plane 3
	moveq	#16-1,d4
.px:	add.w	d1,d1
	add.l	d2,d2
	add.l	d3,d3
	and.l	#$fffefffe,d2		; drop the bit carried from the low word into the high one
	and.l	#$fffefffe,d3
	moveq	#0,d0
	move.b	(a0)+,d0
	cmp.b	#255,d0
	beq.s	.tr
	move.b	0(a3,d0.w),d0		; slot in this band
	addq.w	#1,d1
	btst	#0,d0
	beq.s	.p1
	bset	#16,d2
.p1:	btst	#1,d0
	beq.s	.p2
	addq.w	#1,d2
.p2:	btst	#2,d0
	beq.s	.p3
	bset	#16,d3
.p3:	btst	#3,d0
	beq.s	.tr
	addq.w	#1,d3
.tr:	dbf	d4,.px
	move.w	d1,(a2)+
	move.l	d2,(a4)+
	move.l	d3,(a4)+
	dbf	d5,.row
	lea	64*2(a2),a2		; skip this variant's planes
	lea	256(a3),a3
	dbf	d6,.band
	move.w	(sp)+,d0
	beq.s	.x
	bsr	kbd_cursor_show
.x:	movem.l	(sp)+,d3-d7/a3-a4
.none:	rts

kbd_cursor_show:
	move.w	#1,kbd_cur_on
	rts

kbd_cursor_hide:
	DI
	clr.w	kbd_cur_on
	bsr	kbd_cur_restore
	EI
	rts

; VBL: restore under the old position, draw at the current one (on the shown screen)
kbd_vbl:
	tst.w	kbd_cur_on
	beq.s	.x
	tst.l	kbd_save_at		; already drawn, same place, same screen: nothing to do
	beq.s	.draw
	move.l	vid_shown,d0
	cmp.l	kbd_save_scr,d0
	bne.s	.draw
	move.l	kbd_mx,d0		; (x and y as one long)
	cmp.l	kbd_drawn,d0
	beq.s	.x
.draw:	move.l	kbd_mx,kbd_drawn
	movem.l	d0-d7/a0-a5,-(sp)
	bsr	kbd_cur_restore
	bsr	kbd_cur_draw
	movem.l	(sp)+,d0-d7/a0-a5
.x:	rts

kbd_cur_restore:
	move.l	kbd_save_at,d0
	beq.s	.x
	clr.l	kbd_save_at
	; restore on the screen it was drawn on, shown or not: after a flip that screen is the
	; back buffer, and main code only draws into it once vid_flip has returned (after this VBL)
	move.l	d0,a0
	lea	kbd_save,a1
	move.w	kbd_save_rows,d1
	subq.w	#1,d1
.r:	move.l	(a1)+,(a0)
	move.l	(a1)+,4(a0)
	move.l	(a1)+,8(a0)
	move.l	(a1)+,12(a0)
	lea	SCR_BPL(a0),a0
	dbf	d1,.r
.x:	rts

kbd_cur_draw:
	move.w	kbd_mx,d0
	move.w	kbd_my,d1
	move.w	#SCR_H,d7
	sub.w	d1,d7			; rows that fit
	cmp.w	#16,d7
	ble.s	.r1
	moveq	#16,d7
.r1:	move.w	d0,d6
	and.w	#15,d6			; shift
	lsr.w	#4,d0			; group 0-19
	move.l	vid_shown,a0
	mulu	#SCR_BPL,d1
	add.l	d1,a0
	lsl.w	#3,d0
	add.w	d0,a0
	moveq	#0,d5			; second group usable?
	cmp.w	#19*8,d0
	beq.s	.one
	moveq	#1,d5
.one:	move.l	vid_shown,kbd_save_scr
	move.w	d7,kbd_save_rows
	move.l	a0,kbd_save_at
	lea	kbd_save,a1
	moveq	#0,d3			; row 0..15
	subq.w	#1,d7
.row:	move.w	kbd_my,d0		; this row's band -> variant
	add.w	d3,d0
	lea	vid_line_band,a2
	moveq	#0,d2
	move.b	0(a2,d0.w),d2
	mulu	#KBD_VAR,d2
	lea	kbd_cur_var,a2
	add.w	d2,a2
	move.w	d3,d2
	add.w	d2,d2
	lea	32(a2),a3		; planes of this variant
	add.w	d2,a2			; mask word of this row
	lsl.w	#2,d2
	add.w	d2,a3			; 4 plane words of this row
	addq.w	#1,d3
	move.l	(a0),(a1)+		; save 16 bytes (2 groups)
	move.l	4(a0),(a1)+
	move.l	8(a0),(a1)+
	move.l	12(a0),(a1)+
	moveq	#0,d1
	move.w	(a2),d1
	swap	d1
	lsr.l	d6,d1			; mask: high word -> group 0, low word -> group 1
	not.l	d1
	moveq	#4-1,d4
	move.l	a0,a4
.pl:	moveq	#0,d2
	move.w	(a3)+,d2
	swap	d2
	lsr.l	d6,d2
	swap	d1
	swap	d2
	and.w	d1,(a4)			; group 0 (high words)
	or.w	d2,(a4)
	swap	d1
	swap	d2
	tst.w	d5
	beq.s	.n2
	and.w	d1,8(a4)		; group 1 (low words)
	or.w	d2,8(a4)
.n2:	addq.l	#2,a4
	dbf	d4,.pl
	lea	SCR_BPL(a0),a0
	dbf	d7,.row
	rts

	section	data
; default cursor: arrow (the game replaces it with its own from weapicon.dta)
kbd_default_cursor:			; game colours: 0 outline, 31 fill, 255 transparent
	dc.b	0,0,255,255,255,255,255,255,255,255,255,255,255,255,255,255
	dc.b	0,31,0,255,255,255,255,255,255,255,255,255,255,255,255,255
	dc.b	0,31,31,0,255,255,255,255,255,255,255,255,255,255,255,255
	dc.b	0,31,31,31,0,255,255,255,255,255,255,255,255,255,255,255
	dc.b	0,31,31,31,31,0,255,255,255,255,255,255,255,255,255,255
	dc.b	0,31,31,31,31,31,0,255,255,255,255,255,255,255,255,255
	dc.b	0,31,31,31,31,31,31,0,255,255,255,255,255,255,255,255
	dc.b	0,31,31,31,31,31,31,31,0,255,255,255,255,255,255,255
	dc.b	0,31,31,31,31,31,0,0,0,0,255,255,255,255,255,255
	dc.b	0,31,31,0,31,31,0,255,255,255,255,255,255,255,255,255
	dc.b	0,31,0,255,0,31,31,0,255,255,255,255,255,255,255,255
	dc.b	0,0,255,255,0,31,31,0,255,255,255,255,255,255,255,255
	dc.b	255,255,255,255,255,0,31,31,0,255,255,255,255,255,255,255
	dc.b	255,255,255,255,255,0,31,31,0,255,255,255,255,255,255,255
	dc.b	255,255,255,255,255,255,0,0,255,255,255,255,255,255,255,255
	dc.b	255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
	even

	section	bss
kbd_oldmouse:	ds.l	1
kbd_save_at:	ds.l	1
kbd_save_scr:	ds.l	1
kbd_mx:		ds.w	1		; kbd_mx/kbd_my must stay together (read as one long)
kbd_my:		ds.w	1
kbd_drawn:	ds.l	1
kbd_cur_on:	ds.w	1
kbd_save_rows:	ds.w	1
kbd_cur_ready:	ds.w	1
kbd_cur_src:	ds.b	256
kbd_cur_var:	ds.b	4*KBD_VAR
kbd_save:	ds.b	16*16
kbd_mbuttons:	ds.b	1
kbd_mclick:	ds.b	1
kbd_pending:	ds.b	1
	even
