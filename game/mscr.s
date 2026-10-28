; mscr.s - MAIN.PRG's screen: a chunky shadow of the whole screen (the original's screen[]: game
; palette indices) and a list of dirty spans per line, flushed to the shown planar screen through
; the band LUTs (gfx_c4_span). The game code is the original's, line by line: it draws into the
; shadow (kernel chk_* routines, chk_open on the whole 320x200 shadow, or direct byte writes) and
; marks what it changed; the flush happens where the original showed its drawing: mouseshow,
; delay, the end of a frame. Include after the kernel.
;
; ms_init      allocate the shadow, chk_open it, draw into vid_phys    trashes: d0-d2/a0-a2
; ms_dirty     in: d0.w x1, d1.w y1, d2.w x2, d3.w y2 (inclusive): mark  trashes: d0-d2/a0-a1
; ms_dirty_all mark the whole screen                                     trashes: d0-d2/a0-a1
; ms_flush     convert the dirty spans to the shown screen, clear them (the cursor stays drawn;
;              only lines under it are converted with it off, then it is drawn again at once)                                                       trashes: d0-d2/a0-a2
; ms_addr      in: d0.w x, d1.w y   out: a0 = shadow address              trashes: d1
; ms_load      in: a0 = mode name (C string, "LOG"): DATA\NAME.ISP (bands, LUTs, reps, planar
;              picture -> pic_show on the shown screen) and DATA\NAME.CHK (64000 indices -> the
;              shadow; a palette after them goes to GS_COLORS, as loadscreen sets colors from a
;              .cpr that has one); nothing dirty afterwards. carry set on error
;              trashes: d0-d2/a0-a2
; ms_snap      in: d0.w slot (0-2: current, current2, current3): keep the whole screen state (shadow, shown planar screen,
;              bands, LUTs, reps, keep mask, GS_COLORS) - the original's compressfile(current)
; ms_unsnap    in: d0.w slot: put it back (loadscreen(current)); the bands come back at the
;              current fade level                                         trashes: d0-d2/a0-a2
; ms_pset      in: d0.w x, d1.w y, d2.b colour (marks)                    trashes: d0-d2/a0-a1
; ms_bar       in: d0-d3 = x1,y1,x2,y2, d4.b colour (scr_fillchar rows; marks) trashes: d0-d2/a0-a2
; ms_print     in: d0.w x1, d1.w y1, a0 = Pascal string: printxy (marks)  trashes: d0-d2/a0-a2
; ms_fade      in: d0-d3 = x1,y1,x2,y2, d4.w alt: plainfadearea (marks)   trashes: d0-d2/a0-a2
; mousehide / mouseshow   the original's: hide; flush + show. Phase 6h: mousehide is soft (the
;              cursor stays while the game draws into the shadow: kernel kbd_cursor_soft);
;              mousehidep really hides it, for code that writes the planar screen itself
; delay        in: d0.w ms: flush, then tim_delay (the original's delay)  trashes: d0-d2/a0-a2
; ms_psetp     in: d0.w x, d1.w y, d2.b colour: the shadow pixel and the planar one at once,
;              nothing marked (for pixel-by-pixel effects; hide the cursor with mousehidep) trashes: d0-d2/a0-a1
; ms_psetq     in: d0.w x, d1.w y, d2.b colour: shadow + planar pixel through the line's LUT, no
;              marks (sprinkles; cursor off: mousehidep)              trashes: d0-d2/a0-a1
; ms_vscroll   in: d0.w x1, d1.w y1, d2.w x2, d3.w y2 (inclusive), d4.w dir: the same row move on
;              the shown planar screen as the caller then makes in the shadow (dir 1: row y takes
;              row y+1, y1 up to y2; -1: row y takes row y-1, y2 down to y1), which it does not mark.
;              Flushes first; a row whose source line has another LUT (a band split between them)
;              is marked dirty instead. A scroll costs a planar copy, not a conversion.
;              trashes: d0-d2/a0-a2

MS_W		equ	320
MS_H		equ	200

	section	text
ms_init:
	move.l	#MS_W*MS_H,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,ms_buf
	move.l	a0,orc_scrbuf		; (state dumps carry the shadow: tools/screen_cmp.py)
	moveq	#0,d0
	moveq	#0,d1
	move.w	#MS_W,d2
	move.w	#MS_H,d3
	bsr	chk_open
	moveq	#0,d0			; both snapshot buffers now (the pool is a stack)
	bsr	ms_slot
	moveq	#1,d0
	bsr	ms_slot
	moveq	#2,d0
	bsr	ms_slot
	ifd	CURSTAT			; (the shot's check: a planar screen converted from the shadow)
	move.l	#SCR_SIZE,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,ms_vbuf
	move.l	#ms_verify,scr_shot_hook
	endif
	move.l	vid_phys,a0
	bsr	gfx_set_target
	; fall through: nothing dirty
ms_clean:
	lea	ms_x1,a0
	lea	ms_x2,a1
	move.w	#MS_H-1,d0
.c:	move.w	#$7fff,(a0)+
	move.w	#-1,(a1)+
	dbf	d0,.c
	clr.w	ms_any
	move.w	#MS_H,ms_ymin		; the dirty lines' range: none
	move.w	#-1,ms_ymax
	rts

ms_dirty_all:				; (keeps d3, as documented)
	move.w	d3,-(sp)
	moveq	#0,d0
	moveq	#0,d1
	move.w	#MS_W-1,d2
	move.w	#MS_H-1,d3
	bsr.s	ms_dirty
	move.w	(sp)+,d3
	rts
ms_dirty:
	move.w	d3,-(sp)
	tst.w	d1			; rows clipped to the screen (a bad caller must not make the
	bpl.s	.y1			; flush walk lines that do not exist)
	moveq	#0,d1
.y1:	cmp.w	#MS_H-1,d3
	ble.s	.y2
	move.w	#MS_H-1,d3
.y2:	and.w	#$fff8,d0		; whole cells: the flush takes its fast path
	or.w	#7,d2
	lea	ms_x1,a0
	lea	ms_x2,a1
	add.w	d1,d1
	add.w	d1,a0
	add.w	d1,a1
	lsr.w	#1,d1
	sub.w	d1,d3			; rows - 1
	bmi.s	.x
	cmp.w	ms_ymin,d1		; the range of dirty lines (the flush walks only those)
	bge.s	.ya
	move.w	d1,ms_ymin
.ya:	add.w	d3,d1
	cmp.w	ms_ymax,d1
	ble.s	.r
	move.w	d1,ms_ymax
.r:	cmp.w	(a0),d0
	bge.s	.n1
	move.w	d0,(a0)
.n1:	addq.l	#2,a0
	cmp.w	(a1),d2
	ble.s	.n2
	move.w	d2,(a1)
.n2:	addq.l	#2,a1
	dbf	d3,.r
	move.w	#1,ms_any
.x:	move.w	(sp)+,d3
	rts

ms_flush:				; (Phase 6h) the cursor stays on the screen: lines under it wait
	bsr	snd_poll		; for a second pass that takes it off for just those lines and
	tst.w	ms_any			; draws it again at once; meanwhile the VBL may move it, but
	beq	.none			; never onto the line being converted (kbd_busy)
	movem.l	d3-d5/a3-a4,-(sp)
	clr.w	ms_defer
	lea	ms_x1,a3
	lea	ms_x2,a4
	move.w	ms_ymin,d3		; y: the dirty range only
	add.w	d3,a3
	add.w	d3,a3
	add.w	d3,a4
	add.w	d3,a4
	move.w	ms_ymax,d4
.y:	move.w	(a3),d0
	cmp.w	#$7fff,d0
	beq.s	.n
	tst.w	kbd_cur_on
	beq.s	.cv			; off: nothing drawn (the VBL draws nothing either)
	move.w	d3,d1
	addq.w	#1,d1
	move.w	d1,kbd_busy		; first: from here the VBL leaves this line alone
	bsr	ms_curline		; is the drawn cursor on it, over the span?
	beq.s	.cv
	st	ms_defer		; yes: the parts beside it now, its 32 pixels in the second pass
	movem.w	d1-d2,-(sp)		; (left, right: whole groups, so the parts share no word with it)
	move.w	(a3),d0
	cmp.w	d1,d0
	bge.s	.nl
	move.w	d1,(a3)
	move.w	d1,d2
	subq.w	#1,d2
	bsr	ms_conv			; x1 .. left-1
.nl:	move.w	2(sp),d0
	cmp.w	(a4),d0
	bge.s	.nr
	move.w	(a4),d2
	move.w	d0,(a4)
	addq.w	#1,d0
	bsr	ms_conv			; right+1 .. x2
.nr:	addq.l	#4,sp
	bra.s	.n
.cv:	bsr	ms_span
.n:	addq.l	#2,a3
	addq.l	#2,a4
	addq.w	#1,d3
	cmp.w	d4,d3
	ble.s	.y
	clr.w	kbd_busy
	tst.w	ms_defer
	beq.s	.done
	ifd	CURSTAT
	addq.l	#1,kbd_st_p2
	endif
	move.w	kbd_cur_on,d5		; the lines under the cursor: off, convert, on again
	clr.w	kbd_cur_on
	bsr	kbd_cur_restore
	lea	ms_x1,a3
	lea	ms_x2,a4
	move.w	ms_ymin,d3
	add.w	d3,a3
	add.w	d3,a3
	add.w	d3,a4
	add.w	d3,a4
.y2:	cmp.w	#$7fff,(a3)
	beq.s	.n2
	bsr	ms_span
.n2:	addq.l	#2,a3
	addq.l	#2,a4
	addq.w	#1,d3
	cmp.w	d4,d3
	ble.s	.y2
	tst.w	d5
	beq.s	.done
	bsr	kbd_cursor_drawnow
	move.w	d5,kbd_cur_on
.done:	clr.w	ms_any
	move.w	#MS_H,ms_ymin
	move.w	#-1,ms_ymax
	movem.l	(sp)+,d3-d5/a3-a4
.none:	rts

	ifd	CURSTAT
; ms_verify (CURSTAT builds; kernel scr_shot calls it with the cursor off): flush, convert the
; whole shadow into ms_vbuf and compare it with the planar screen - tag 242 = differing longs
; (cursor debris, a stale save-under), tag 241 = the first one's byte offset.
ms_verify:
	movem.l	d3-d4/a3,-(sp)
	bsr	ms_flush
	move.l	gfx_target,-(sp)
	move.l	ms_vbuf,gfx_target
	moveq	#0,d3
.l:	move.w	d3,d1
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	moveq	#0,d0
	move.w	#MS_W,d2
	move.w	d3,d1
	bsr	gfx_c4_span
	addq.w	#1,d3
	cmp.w	#MS_H,d3
	bne.s	.l
	move.l	(sp)+,gfx_target
	move.l	ms_vbuf,a0
	move.l	vid_phys,a1
	moveq	#0,d4
	moveq	#-1,d3
	move.w	#SCR_SIZE/4-1,d2
.c:	cmpm.l	(a0)+,(a1)+
	beq.s	.n
	addq.l	#1,d4
	tst.l	d3
	bpl.s	.n
	move.l	a1,d3
	sub.l	vid_phys,d3
	subq.l	#4,d3
.n:	dbf	d2,.c
	move.l	d4,d0
	or.l	#242<<24,d0
	bsr	scr_dbg
	move.l	d3,d0
	and.l	#$ffffff,d0
	or.l	#241<<24,d0
	bsr	scr_dbg
	movem.l	(sp)+,d3-d4/a3
	rts
	endif

; ms_span: line d3, (a3)/(a4) = its span: convert it and clear it.  trashes: d0-d2/a0-a2
; ms_conv: line d3, x d0..d2: convert.  trashes: d0-d2/a0-a2
ms_span:
	move.w	(a3),d0
	move.w	(a4),d2
	move.w	#$7fff,(a3)
	move.w	#-1,(a4)
ms_conv:
	sub.w	d0,d2
	addq.w	#1,d2			; count
	move.w	d3,d1
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	add.w	d0,a0
	move.w	d3,d1
	bra	gfx_c4_span

; ms_curline: Z clear if the drawn cursor (32 pixels from its group, kbd_save_rows lines) covers
; line d3 within its span (a3)/(a4); a cursor on another screen than the flush's target never
; does.  out: d0 (Z), d1.w = the cursor's left x, d2.w = its right x (when it does)
; trashes: d0-d2/a0
ms_curline:
	DI				; (one consistent rectangle: the VBL may move it)
	move.l	kbd_save_at,d0
	beq.s	.no
	move.l	kbd_save_scr,a0
	cmp.l	gfx_target,a0
	bne.s	.no
	move.w	d3,d0
	sub.w	kbd_save_y,d0		; line - top
	cmp.w	kbd_save_rows,d0
	bhs.s	.no			; (unsigned: above or below)
	move.w	kbd_save_x,d1
	move.w	d1,d2
	add.w	#31,d2
	cmp.w	(a3),d2			; x1 <= right and x2 >= left: it meets
	blt.s	.no
	cmp.w	(a4),d1
	bgt.s	.no
	EI
	moveq	#1,d0
	rts
.no:	EI
	moveq	#0,d0
	rts

ms_addr:
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	add.w	d0,a0
	rts

ms_load:
	movem.l	d3/a3,-(sp)
	sf	rf_on			; (a whole design replaces a dialog's refit: refit.s)
	sf	gfx_pnobuild
	move.w	#-1,ms_design		; (a mode's own design: not one of u2_design's)
	lea	ms_path+5,a1		; "DATA\" + name + ".ISP"
.cp:	move.b	(a0)+,(a1)+
	bne.s	.cp
	subq.l	#1,a1
	move.l	a1,a3
	move.b	#'.',(a3)+
	move.b	#'I',(a3)+
	move.b	#'S',(a3)+
	move.b	#'P',(a3)+
	clr.b	(a3)
	subq.l	#4,a3
	bsr	mem_mark
	move.l	d0,d3
	move.l	#ISP_DATA+64+32000,d0
	bsr	mem_alloc
	bcs	.err
	move.l	a0,a1
	move.l	a0,-(sp)
	lea	ms_path,a0
	move.l	#ISP_DATA+64+32000,d0
	bsr	fil_load
	move.l	(sp)+,a0
	bcs.s	.err
	move.l	a0,-(sp)
	bsr	kbd_cursor_hide		; (the caller shows it again; trashes a0 when the cursor
	move.l	(sp)+,a0		; was drawn: pic_show read the screen - reglint)
	move.l	vid_phys,a1
	bsr	pic_show
	move.l	d3,d0
	bsr	mem_release
	move.b	#'C',1(a3)		; ".CHK"
	move.b	#'H',2(a3)
	move.b	#'K',3(a3)
	lea	ms_path,a0
	move.l	ms_buf,a1
	move.l	#MS_W*MS_H,d0
	bsr	fil_load
	bcs.s	.err2
	lea	ms_path,a0		; the palette, if there is one
	bsr	fil_size
	cmp.l	#MS_W*MS_H+768,d0
	bne.s	.np
	move.l	ms_buf,a0		; (read the whole file again into the shadow + a buffer)
	bsr	ms_loadpal
.np:	bsr	ms_clean
	movem.l	(sp)+,d3/a3
	and.b	#$fe,ccr
	rts
.err:	move.l	d3,d0
	bsr	mem_release
.err2:	movem.l	(sp)+,d3/a3
	or.b	#1,ccr
	rts

MS_SNAP		equ	MS_W*MS_H+SCR_SIZE+(2+4*BAND_SIZE)+1024+64+64+768+2	; (+ ms_design)

ms_snap:
	movem.l	d3/a3,-(sp)
	move.w	d0,d3
	bsr	ms_flush		; (the planar copy must show what the shadow holds)
	move.w	kbd_cur_on,-(sp)	; (and not the mouse cursor)
	bsr	kbd_cursor_hide
	move.w	d3,d0
	bsr	ms_slot
	move.l	a0,a3
	move.l	ms_buf,a0		; shadow
	move.l	a3,a1
	move.w	#MS_W*MS_H/4-1,d0
.c1:	move.l	(a0)+,(a1)+
	dbf	d0,.c1
	move.l	vid_phys,a0		; planar
	move.w	#SCR_SIZE/4-1,d0
.c2:	move.l	(a0)+,(a1)+
	dbf	d0,.c2
	lea	vid_bands_src,a0
	move.w	#(2+4*BAND_SIZE)/2-1,d0
.c3:	move.w	(a0)+,(a1)+
	dbf	d0,.c3
	lea	vid_luts,a0
	move.w	#1024/4-1,d0
.c4:	move.l	(a0)+,(a1)+
	dbf	d0,.c4
	lea	vid_reps,a0
	moveq	#64/4-1,d0
.c5:	move.l	(a0)+,(a1)+
	dbf	d0,.c5
	lea	vid_keep,a0
	moveq	#64/4-1,d0
.c6:	move.l	(a0)+,(a1)+
	dbf	d0,.c6
	lea	GS_COLORS(a6),a0
	move.w	#768/4-1,d0
.c7:	move.l	(a0)+,(a1)+
	dbf	d0,.c7
	move.w	ms_design,(a1)+
	tst.w	(sp)+
	beq.s	.x
	bsr	kbd_cursor_show
.x:	movem.l	(sp)+,d3/a3
	rts

; ms_loaddesign(a0 = path of an ISP header, e.g. DATA\LAND3.ISP; Phase 6j): another band design for
; the screen as it is - reps, bands, LUTs, the colours from GS_COLORS (vid_set256: the fade level
; stays). The caller marks the lines whose design changed. carry set: no such file (nothing
; changed).  trashes: d0-d2/a0-a2
ms_loaddesign:
	movem.l	d3/a3,-(sp)
	move.l	a0,-(sp)
	bsr	mem_mark
	move.l	d0,d3
	move.l	#ISP_DATA+64,d0
	bsr	mem_alloc
	move.l	(sp)+,a1
	bcs.s	.no
	move.l	a0,a3
	exg	a0,a1			; a0 = path, a1 = buffer
	move.l	#ISP_DATA+64,d0
	bsr	fil_load
	bcs.s	.no
	lea	ISP_DATA(a3),a0
	bsr	vid_set_reps
	lea	ISP_BANDS(a3),a0
	bsr	vid_set_bands
	lea	ISP_LUTS(a3),a0
	bsr	vid_set_luts
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	move.l	d3,d0
	bsr	mem_release
	movem.l	(sp)+,d3/a3
	andi.b	#$fe,ccr
	rts
.no:	move.l	d3,d0
	bsr	mem_release
	movem.l	(sp)+,d3/a3
	ori.b	#1,ccr
	rts

ms_unsnap:
	movem.l	d3/a3,-(sp)
	sf	rf_on			; (the snapshot's design replaces a dialog's refit)
	sf	gfx_pnobuild
	bsr	ms_slot
	move.l	a0,a3
	move.l	ms_buf,a1		; shadow
	move.w	#MS_W*MS_H/4-1,d0
.c1:	move.l	(a0)+,(a1)+
	dbf	d0,.c1
	move.l	a0,a3			; planar: after the palette is set (below)
	lea	SCR_SIZE(a0),a0
	move.l	a0,-(sp)		; band table
	lea	2+4*BAND_SIZE(a0),a0
	lea	1024(a0),a0
	bsr	vid_set_reps
	bsr	vid_set_keep
	move.l	a0,-(sp)		; colours
	move.l	4(sp),a0
	bsr	vid_set_bands
	move.l	4(sp),a0
	lea	2+4*BAND_SIZE(a0),a0
	bsr	vid_set_luts
	move.l	(sp)+,a0
	lea	GS_COLORS(a6),a1
	move.w	#768/4-1,d0
.c7:	move.l	(a0)+,(a1)+
	dbf	d0,.c7
	move.w	(a0)+,ms_design
	addq.l	#4,sp
	bsr	kbd_cursor_hide
	move.l	a3,a0
	move.l	vid_phys,a1
	move.w	#SCR_SIZE/4-1,d0
.c2:	move.l	(a0)+,(a1)+
	dbf	d0,.c2
	bsr	ms_clean
	movem.l	(sp)+,d3/a3
	rts

ms_slot:				; d0.w slot -> a0 = its buffer (allocated on first use)
	lsl.w	#2,d0
	lea	ms_snaps,a1
	add.w	d0,a1
	move.l	(a1),d0
	bne.s	.have
	move.l	a1,-(sp)
	move.l	#MS_SNAP,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	(sp)+,a1
	move.l	a0,(a1)
	rts
.have:	move.l	d0,a0
	rts

; read NAME.CHK's palette (bytes 64000-64767, ms_path) into GS_COLORS
ms_loadpal:
	movem.l	d3,-(sp)
	clr.w	-(sp)
	pea	ms_path
	GEMDOS	GD_FOPEN,8
	move.w	d0,d3
	bmi.s	.x
	clr.w	-(sp)			; Fseek(64000, h, 0)
	move.w	d3,-(sp)
	move.l	#MS_W*MS_H,-(sp)
	GEMDOS	GD_FSEEK,10
	pea	GS_COLORS(a6)
	move.l	#768,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FREAD,12
	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
.x:	movem.l	(sp)+,d3
	rts

ms_pset:
	movem.l	d0-d3,-(sp)
	bsr	chk_pset
	movem.l	(sp)+,d0-d3
	move.w	d0,d2
	move.w	d3,-(sp)
	move.w	d1,d3
	bsr	ms_dirty
	move.w	(sp)+,d3
	rts

ms_bar:
	movem.l	d0-d3,-(sp)
	bsr	chk_bar
	movem.l	(sp)+,d0-d3
	bra	ms_dirty

ms_fade:
	movem.l	d0-d3,-(sp)
	bsr	chk_fade
	movem.l	(sp)+,d0-d3
	bra	ms_dirty

ms_print:
	movem.l	d0-d1/a0,-(sp)
	bsr	chk_print
	movem.l	(sp)+,d0-d1/a0
	move.w	d3,-(sp)
	moveq	#0,d2
	move.b	(a0),d2			; x2 = x1 + 4 + 5*len
	mulu	#5,d2
	add.w	d0,d2
	addq.w	#4,d2
	cmp.w	#MS_W-1,d2
	ble.s	.w
	move.w	#MS_W-1,d2
.w:	move.w	d1,d3
	addq.w	#6,d3
	cmp.w	#MS_H-1,d3
	ble.s	.h
	move.w	#MS_H-1,d3
.h:	bsr	ms_dirty
	move.w	(sp)+,d3
	rts

mousehide:				; (Phase 6h) the game draws into the shadow only: the cursor
	bra	kbd_cursor_soft		; stays (kernel kbd.s: off after KBD_SOFTV frames)
mousehidep:				; for code that writes the planar screen itself
	bra	kbd_cursor_hide

mouseshow:
	bsr	ms_flush
	bra	kbd_cursor_shownow

ms_psetp:
	move.w	d1,-(sp)
	move.w	d0,-(sp)
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	move.b	d2,0(a0,d0.w)
	move.w	(sp)+,d0
	move.w	(sp)+,d1
	move.l	gfx_target,-(sp)
	move.l	vid_phys,gfx_target
	bsr	gfx_pset
	move.l	(sp)+,gfx_target
	rts

; ms_psetq: the shadow pixel and the planar one at once, straight through the line's LUT (no
; marks, no flush: the sprinkles' pixel-by-pixel reveal, Phase 6h). The cursor must be off
; (mousehidep).  in: d0.w x, d1.w y, d2.b colour  trashes: d0-d2/a0-a1
ms_psetq:
	move.l	d3,-(sp)
	move.w	d1,d3
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	move.b	d2,0(a0,d0.w)		; the shadow
	lea	vid_line_lut,a0
	move.w	d3,d1
	lsl.w	#2,d1
	move.l	0(a0,d1.w),a0
	and.w	#$ff,d2
	move.b	0(a0,d2.w),d2		; the slot of the line's band
	mulu	#SCR_BPL,d3
	move.l	vid_phys,a0
	add.l	d3,a0
	move.w	d0,d1
	lsr.w	#4,d1
	lsl.w	#3,d1
	add.w	d1,a0			; the group
	not.w	d0
	and.w	#15,d0
	moveq	#0,d1
	bset	d0,d1			; the pixel's bit
	move.w	d1,d0
	not.w	d0
	REPT	4
	lsr.b	#1,d2
	bcc.s	*+6
	or.w	d1,(a0)+
	bra.s	*+4
	and.w	d0,(a0)+
	ENDR
	move.l	(sp)+,d3
	rts

MSVMASK	macro				; one group, 4 planes: dst ^= (src ^ dst) & \1
	REPT	4
	move.w	(a1)+,d0
	move.w	(a0),d2
	eor.w	d2,d0
	and.w	\1,d0
	eor.w	d0,(a0)+
	ENDR
	endm

ms_vscroll:
	movem.l	d3-d7/a3-a4,-(sp)
	move.w	d0,-(sp)		; 2(sp) x1 (after the next push)
	move.w	d2,-(sp)		; 0(sp) x2
	move.w	d1,d6			; y
	move.w	d3,d7
	sub.w	d1,d7			; rows - 1
	bmi	.x
	tst.w	d4
	bpl.s	.up
	move.w	d3,d6			; dir -1: from y2 down
.up:	bsr	ms_flush
	move.w	kbd_cur_on,-(sp)	; 0(sp) cursor, 2(sp) x2, 4(sp) x1
	beq.s	.off
	bsr	kbd_cursor_hide
.off:	move.w	4(sp),d0
	moveq	#15,d1
	and.w	d0,d1
	moveq	#-1,d3
	lsr.w	d1,d3			; left mask
	move.w	2(sp),d2
	moveq	#15,d1
	and.w	d2,d1
	eor.w	#15,d1
	moveq	#-1,d5
	lsl.w	d1,d5			; right mask
	lsr.w	#4,d0
	lsr.w	#4,d2
	sub.w	d0,d2			; groups - 1
	bne.s	.two
	and.w	d5,d3			; one group: both masks
.two:	move.w	d2,a4
	lsl.w	#3,d0
	move.w	d0,a3			; byte offset of the first group
.row:	lea	vid_line_lut,a0
	move.w	d6,d0
	lsl.w	#2,d0
	move.w	d4,d1
	lsl.w	#2,d1
	add.w	d0,d1
	move.l	0(a0,d0.w),d2
	cmp.l	0(a0,d1.w),d2
	beq.s	.copy
	move.w	4(sp),d0		; another LUT: convert this row from the shadow later
	move.w	d6,d1
	move.w	2(sp),d2
	move.w	d3,-(sp)
	move.w	d6,d3
	bsr	ms_dirty
	move.w	(sp)+,d3
	bra	.next
.copy:	move.l	vid_phys,a0
	move.w	d6,d0
	mulu	#SCR_BPL,d0
	add.l	d0,a0
	add.l	a3,a0
	move.w	d4,d0
	muls	#SCR_BPL,d0
	lea	0(a0,d0.l),a1
	move.w	a4,d1
	bne.s	.multi
	MSVMASK	d3
	bra.s	.next
.multi:	MSVMASK	d3
	subq.w	#1,d1
	bra.s	.mf
.mid:	move.l	(a1)+,(a0)+		; whole groups
	move.l	(a1)+,(a0)+
.mf:	dbf	d1,.mid
	MSVMASK	d5
.next:	add.w	d4,d6
	dbf	d7,.row
	tst.w	(sp)+
	beq.s	.x
	bsr	kbd_cursor_show
.x:	addq.l	#4,sp
	movem.l	(sp)+,d3-d7/a3-a4
	rts

delay:
	move.w	d0,-(sp)
	bsr	ms_flush
	move.w	(sp)+,d0
	bra	tim_delay
delayp:					; delay for a main loop's frame (kernel tim_pace: the frame's
	move.w	d0,-(sp)		; own work counts against the wait)
	bsr	ms_flush
	move.w	(sp)+,d0
	bra	tim_pace

	section	data
ms_path:	dc.b	"DATA",92,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	even

	section	bss
ms_buf:		ds.l	1
ms_design:	ds.w	1		; (Phase 6i) the bridge design in use: 0 MAIN, 1-3 MAINSn, -1 another
ms_snaps:	ds.l	3
ms_color:	ds.w	1		; graph.setcolor's colour (rectangle, circle in explore)
ms_any:		ds.w	1
ms_defer:	ds.w	1		; ms_flush: lines under the cursor wait for the second pass
	ifd	CURSTAT
ms_vbuf:	ds.l	1
kbd_st_p2:	ds.l	1
	endif
ms_ymin:	ds.w	1		; first and last line marked dirty since the last flush
ms_ymax:	ds.w	1
ms_x1:		ds.w	MS_H
ms_x2:		ds.w	MS_H
