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
; kbd_cursor_soft   (Phase 6h; MAIN's mousehide) a hide for code that draws only into a
;                   shadow: the cursor stays drawn and keeps following the mouse; the VBL
;                   takes it off only when no kbd_cursor_shownow comes within KBD_SOFTV
;                   frames (a long hidden stretch). Writers of the planar screen still use
;                   kbd_cursor_hide (or take kbd_cur_on away meanwhile, like ms_flush).
;                   trashes: d0
; kbd_cursor_shownow  (MAIN's mouseshow) ends a soft hide; shown at once (not at the next
;                   VBL) when it was off.  trashes: d0-d2/a0-a2
; kbd_cursor_drawnow  main code: draw it now at the mouse position (kbd_cur_on must be 0
;                   and the cursor not drawn; the caller sets kbd_cur_on afterwards).
;                   trashes: d0-d2/a0-a2

LA_GCURX	equ	-602		; Line-A: GEM's mouse position
LA_GCURY	equ	-600
KBD_VAR		equ	16*2+16*4*2	; one cursor variant: 16 mask words + 16 x 4 plane words
KBD_SOFTV	equ	50		; frames a soft hide may last before the VBL hides it

	section	text
kbd_init:
	dc.w	$a000			; start where GEM's mouse is (Line-A GCURX/GCURY, in the
	move.l	a0,kbd_linea		; desktop's resolution): programs then hand the position on
	move.w	LA_GCURX(a0),d0		; (desktop -> intro -> crewgen -> main -> desktop) and the
	move.w	LA_GCURY(a0),d1		; pointer never jumps - in Hatari's windowed mode a jump leaves
	move.w	sys_oldrez,d2		; the host pointer offset, so parts of the screen cannot be reached
	beq.s	.lo
	asr.w	#1,d0			; medium/high: 640 wide
	cmp.w	#2,d2
	bne.s	.lo
	asr.w	#1,d1			; high: 400 lines
.lo:	tst.w	d0
	bpl.s	.x0
	moveq	#0,d0
.x0:	cmp.w	#SCR_W-1,d0
	ble.s	.x1
	move.w	#SCR_W-1,d0
.x1:	tst.w	d1
	bpl.s	.y0
	moveq	#0,d1
.y0:	cmp.w	#SCR_H-1,d1
	ble.s	.y1
	move.w	#SCR_H-1,d1
.y1:	move.w	d0,kbd_mx
	move.w	d1,kbd_my
	move.l	sys_kbdv,a0
	move.l	16(a0),kbd_oldmouse
	move.l	#kbd_mouse_handler,16(a0)
	move.l	#kbd_cur_var,kbd_cur_vp
	lea	kbd_default_cursor,a0
	bsr	kbd_cursor_set
	rts

kbd_exit:
	bsr	kbd_cursor_hide
	move.l	sys_kbdv,a0
	move.l	kbd_oldmouse,16(a0)
	rts

; kbd_tos_sync (supervisor, after the old resolution is back; sys_restore_screen via Supexec):
; hand our mouse position and "no buttons pressed" back to GEM by feeding TOS's own mouse
; handler relative packets, so the VDI, its clamping and the AES all follow as for a real move.
; Without it GEM's pointer comes back where the program was started, and GEM may still think a
; button is down (the release of the double-click that started us went to our handler).
kbd_tos_sync:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	kbd_linea,d0
	beq	.x
	tst.l	kbd_oldmouse
	beq	.x
	move.w	kbd_mx,d6		; target in the desktop's resolution
	move.w	kbd_my,d7
	move.w	sys_oldrez,d0
	beq.s	.lo
	add.w	d6,d6
	cmp.w	#2,d0
	bne.s	.lo
	add.w	d7,d7
.lo:	moveq	#16-1,d5		; at most 16 packets (127 pixels each)
	move.w	sr,-(sp)
	move.w	#$2600,sr		; as from the IKBD interrupt: no real packets in between
.lp:	move.l	kbd_linea,a0
	move.w	d6,d0
	sub.w	LA_GCURX(a0),d0
	move.w	d7,d1
	sub.w	LA_GCURY(a0),d1
	moveq	#127,d2
	cmp.w	d2,d0
	ble.s	.a
	move.w	d2,d0
.a:	cmp.w	d2,d1
	ble.s	.b
	move.w	d2,d1
.b:	neg.w	d2
	cmp.w	d2,d0
	bge.s	.c
	move.w	d2,d0
.c:	cmp.w	d2,d1
	bge.s	.d
	move.w	d2,d1
.d:	cmp.w	#15,d5			; the first packet always goes (it releases the buttons)
	beq.s	.go
	tst.w	d0
	bne.s	.go
	tst.w	d1
	beq.s	.done
.go:	lea	kbd_pkt,a0
	move.b	#$f8,(a0)		; relative mouse, no buttons
	move.b	d0,1(a0)
	move.b	d1,2(a0)
	move.l	kbd_oldmouse,a1
	movem.l	d5-d7,-(sp)
	jsr	(a1)
	movem.l	(sp)+,d5-d7
	dbf	d5,.lp
.done:	move.w	(sp)+,sr
.x:	movem.l	(sp)+,d0-d7/a0-a6
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
	tst.b	scr_mouse		; a script's mouse stays where the script put it (the oracle's
	bne.s	.x			; mouse_get_x/y return the scripted position after a move/click)
	move.w	d0,kbd_mx
	move.w	d1,kbd_my
.x:	rts

kbd_keypressed:
	bsr	snd_poll
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
	cmp.b	#$77,d0			; Ctrl-ClrHome stands for the PC's Ctrl-End (117; the ST has no End)
	bne.s	.f10
	moveq	#117,d0
.f10:	cmp.b	#$44,d0			; Ctrl-F10 (103): TOS gives F10's own code, so ask for Ctrl
	bne.s	.pend
	move.b	d0,-(sp)
	move.w	#-1,-(sp)
	BIOS	BI_KBSHIFT,4
	move.b	d0,d1
	move.b	(sp)+,d0
	btst	#2,d1
	beq.s	.pend
	moveq	#103,d0
.pend:	move.b	d0,kbd_pending
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
	lea	kbd_cur_var,a2		; build into the set not in use (4 x (16 mask words + 64 plane
	cmp.l	kbd_cur_vp,a2		; words)), then swap at once: no hide, so an animated cursor
	bne.s	.set			; (the ship logs change it every pass) never flickers
	lea	kbd_cur_var2,a2
.set:	move.l	a2,-(sp)
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
	move.l	(sp)+,a2		; (before DI: it pushes sr)
	DI
	move.l	a2,kbd_cur_vp
	move.l	#-1,kbd_drawn		; the VBL redraws it (restore + draw) with the new set
	EI
	movem.l	(sp)+,d3-d7/a3-a4
.none:	rts

kbd_cursor_show:
	move.w	#1,kbd_cur_on
	rts

kbd_cursor_hide:
	ifd	CURSTAT			; (who takes a drawn cursor off: tag 251 = return address)
	tst.w	kbd_cur_on
	beq.s	.ns
	move.l	d0,-(sp)
	move.l	4(sp),d0
	and.l	#$ffffff,d0
	or.l	#251<<24,d0
	tst.l	kbd_save_at
	bne.s	.lg
	sub.l	#6<<24,d0		; (245: it was on but not drawn)
.lg:	bsr	scr_dbg
	move.l	(sp)+,d0
.ns:
	endif
	DI
	clr.w	kbd_cur_on
	bsr	kbd_cur_restore
	EI
	rts

kbd_cursor_soft:
	tst.w	kbd_soft
	bne.s	.x			; (the first hide of a stretch counts)
	move.l	vid_frames,kbd_soft_t
	move.w	#1,kbd_soft
.x:	rts

kbd_cursor_shownow:
	clr.w	kbd_soft
	tst.w	kbd_cur_on
	bne.s	.x			; on: the VBL keeps it
	bsr	kbd_cursor_drawnow
	move.w	#1,kbd_cur_on
.x:	rts

kbd_cursor_drawnow:
	tst.l	kbd_save_at
	bne.s	.x
	movem.l	d3-d7/a3-a4,-(sp)
	move.l	kbd_mx,kbd_drawn	; (x and y as one long: the VBL then sees it in place)
	bsr	kbd_cur_draw
	movem.l	(sp)+,d3-d7/a3-a4
.x:	rts

; VBL: restore under the old position, draw at the current one (on the shown screen)
kbd_vbl:
	ifd	CURSTAT			; (measuring builds: frames with the cursor on the screen)
	bsr.s	.v
	addq.l	#1,kbd_st_n
	tst.w	kbd_cur_on
	bne.s	.son
	addq.l	#1,kbd_st_off
	move.l	54(sp),d0		; (the interrupted PC: tag 244)
	and.l	#$ffffff,d0
	or.l	#244<<24,d0
	bsr	scr_dbg
.son:	tst.l	kbd_save_at
	beq.s	.sx
	addq.l	#1,kbd_st_v
.sx:	rts
.v:
	endif
	tst.w	kbd_cur_on
	beq	.x
	tst.w	kbd_soft		; a soft hide that lasts: take the cursor off now
	beq.s	.vis
	move.l	vid_frames,d0
	sub.l	kbd_soft_t,d0
	cmp.l	#KBD_SOFTV,d0
	blo.s	.vis
	clr.w	kbd_soft
	clr.w	kbd_cur_on
	ifd	CURSTAT
	addq.l	#1,kbd_st_to
	endif
	movem.l	d1/a0-a1,-(sp)
	bsr	kbd_cur_restore
	movem.l	(sp)+,d1/a0-a1
	rts
.vis:	tst.l	kbd_save_at		; already drawn, same place, same screen: nothing to do
	beq.s	.draw
	move.l	vid_shown,d0
	cmp.l	kbd_save_scr,d0
	bne.s	.draw
	move.l	kbd_mx,d0		; (x and y as one long)
	cmp.l	kbd_drawn,d0
	beq.s	.x
.draw:	move.l	kbd_mx,d1		; (x, y: one snapshot for the check and the draw)
	move.w	kbd_busy,d0		; ms_flush converts line d0-1 meanwhile: never draw over it
	beq.s	.go			; (it tries again next frame)
	subq.w	#1,d0
	sub.w	d1,d0
	cmp.w	#16,d0
	blo.s	.x
.go:	move.l	d1,kbd_drawn
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

kbd_cur_draw:				; at kbd_drawn (the position the caller took: x, y)
	move.w	kbd_drawn,d0
	move.w	kbd_drawn+2,d1
	move.w	d1,kbd_save_y		; (for ms_flush: the drawn rectangle's top line and left x)
	moveq	#-16,d2
	and.w	d0,d2
	move.w	d2,kbd_save_x
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
.row:	move.w	kbd_drawn+2,d0		; this row's band -> variant
	add.w	d3,d0
	lea	vid_line_band,a2
	moveq	#0,d2
	move.b	0(a2,d0.w),d2
	mulu	#KBD_VAR,d2
	move.l	kbd_cur_vp,a2
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
kbd_soft:	ds.w	1		; a soft hide is running (kbd_cursor_soft)
kbd_busy:	ds.w	1		; line+1 that main code is writing (ms_flush), 0 = none: the
					; VBL does not move the cursor onto it
kbd_save_x:	ds.w	1		; the drawn cursor's left x (its first group) and top line
kbd_save_y:	ds.w	1
kbd_soft_t:	ds.l	1		; its first frame (vid_frames)
	ifd	CURSTAT
kbd_st_n:	ds.l	1		; frames since the last script shot
kbd_st_v:	ds.l	1		; of those, frames with the cursor drawn
kbd_st_to:	ds.l	1		; soft hides that timed out
kbd_st_off:	ds.l	1		; frames with kbd_cur_on clear
	endif
kbd_save_rows:	ds.w	1
kbd_cur_ready:	ds.w	1
kbd_cur_src:	ds.b	256
kbd_cur_var:	ds.b	4*KBD_VAR
kbd_cur_var2:	ds.b	4*KBD_VAR		; (the other set: kbd_cursor_build swaps)
kbd_cur_vp:	ds.l	1		; the set the VBL draws with
kbd_save:	ds.b	16*16
kbd_mbuttons:	ds.b	1
kbd_mclick:	ds.b	1
kbd_pending:	ds.b	1
	even
kbd_linea:	ds.l	1		; Line-A variables (GEM's mouse position)
kbd_pkt:	ds.b	4
