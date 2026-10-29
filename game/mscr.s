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
;
; Phase 6k, two spans per line: a mark joins the span it meets (or comes within MS_GAP of), else
; the free one, else the nearer (the exploration's map, zoom window and probe icons share lines).
; Phase 6k, the mirror (ms_mirror: on in the exploration only - where the original redraws much
; that has not changed every frame; on the bridge most of what is flushed has changed and the
; compares cost more than they save): ms_shw holds what the planar screen shows, as indices, for
; every line marked known in ms_shv (1). The flush converts only the 8-pixel cells of a dirty span
; whose shadow differs from the mirror; a line not known (0) is converted whole at its next flush
; and known afterwards (2 while that flush runs). Lines become unknown when the planar screen
; changes behind the shadow: ms_load, ms_unsnap, mousehidep (code that writes the planar screen
; itself), ms_vscroll's rows, a LUT change (the lines of the bands whose LUT changed, found from
; kernel vid_lutgen), u2_approach's clear (ms_inval). ms_psetp/ms_psetq keep the mirror.
; ms_dirtyx marks lines its caller knows changed (makesphere3): converted without comparing.
; With ms_mon = 0 (the default; the ending clears it too) the flush converts every dirty span.

MS_W		equ	320
MS_H		equ	200
MS_SPB		equ	4*MS_H		; ms_x3 - ms_x1: a line's second span
MS_GAP		equ	32		; marks closer than this join a span

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
	sf	ms_mon			; (Phase 6k) the mirror, when there is room for it
	move.l	#MS_W*MS_H,d0
	bsr	mem_alloc
	bcs.s	.nm
	move.l	a0,ms_shw
	sub.l	ms_buf,a0
	move.l	a0,ms_shoff
	st	ms_mok			; (on where a screen asks for it: ms_mirror)
	bsr	ms_inval
.nm:	move.l	vid_phys,a0
	bsr	gfx_set_target
	; fall through: nothing dirty
ms_clean:
	lea	ms_x1,a0
	lea	ms_x2,a1
	move.w	#MS_H-1,d0
.c:	move.w	#$7fff,(a0)
	move.w	#-1,(a1)
	move.w	#$7fff,MS_SPB(a0)
	move.w	#-1,MS_SPB(a1)
	addq.l	#2,a0
	addq.l	#2,a1
	dbf	d0,.c
	lea	ms_xf,a0
	moveq	#MS_H/4-1,d0
.cx:	clr.l	(a0)+
	dbf	d0,.cx
	move.w	#MS_H,ms_xfmin
	move.w	#-1,ms_xfmax
	sf	ms_any2
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
; ms_dirtyx (Phase 6k): ms_dirty for a caller that knows the span changed (makesphere3 compares
; itself): the flush converts its lines without comparing them with the mirror.
ms_dirtyx:
	movem.l	d1/d3,-(sp)
	lea	ms_xf,a0
	tst.w	d1
	bpl.s	.a
	moveq	#0,d1
.a:	cmp.w	#MS_H-1,d3
	ble.s	.b
	move.w	#MS_H-1,d3
.b:	cmp.w	ms_xfmin,d1		; (the range the flush clears)
	bge.s	.b1
	move.w	d1,ms_xfmin
.b1:	cmp.w	ms_xfmax,d3
	ble.s	.b2
	move.w	d3,ms_xfmax
.b2:	sub.w	d1,d3
	bmi.s	.x
	add.w	d1,a0
.c:	st	(a0)+
	dbf	d3,.c
.x:	movem.l	(sp)+,d1/d3
	; fall through
ms_dirty:				; (Phase 6k) two spans per line: a mark joins the span it meets
	movem.l	d3-d4,-(sp)		; (or comes within MS_GAP of), else the free one, else the nearer
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
	bmi	.x
	cmp.w	ms_ymin,d1		; the range of dirty lines (the flush walks only those)
	bge.s	.ya
	move.w	d1,ms_ymin
.ya:	add.w	d3,d1
	cmp.w	ms_ymax,d1
	ble.s	.yb
	move.w	d1,ms_ymax
.yb:	movem.w	d0-d2,-(sp)		; (callers have relied on what the one-span version left in
					; d0-d2: x1 & ~7, the last row, x2 | 7 - combat's cb_xor loop)
.r:	move.w	(a0),d1			; span A
	cmp.w	#$7fff,d1
	beq.s	.sa
	sub.w	#MS_GAP,d1
	cmp.w	d1,d2			; b < x1 - gap: not A
	blt.s	.na
	move.w	(a1),d1
	add.w	#MS_GAP,d1
	cmp.w	d1,d0			; a > x2 + gap: not A
	bgt.s	.na
.ua:	cmp.w	(a0),d0
	bge.s	.u1
	move.w	d0,(a0)
.u1:	cmp.w	(a1),d2
	ble	.nx
	move.w	d2,(a1)
	bra	.nx
.sa:	move.w	d0,(a0)
	move.w	d2,(a1)
	bra	.nx
.na:	move.w	MS_SPB(a0),d1		; span B
	cmp.w	#$7fff,d1
	beq.s	.sb
	sub.w	#MS_GAP,d1
	cmp.w	d1,d2
	blt.s	.far
	move.w	MS_SPB(a1),d1
	add.w	#MS_GAP,d1
	cmp.w	d1,d0
	bgt.s	.far
.ub:	cmp.w	MS_SPB(a0),d0
	bge.s	.u2
	move.w	d0,MS_SPB(a0)
.u2:	cmp.w	MS_SPB(a1),d2
	ble.s	.nx
	move.w	d2,MS_SPB(a1)
	bra.s	.nx
.sb:	move.w	d0,MS_SPB(a0)
	move.w	d2,MS_SPB(a1)
	bra.s	.nx
.far:	move.w	d0,d1			; far from both: the nearer one takes it (the gaps)
	sub.w	(a1),d1			; a - x2 (A's right side)
	bpl.s	.ga
	move.w	(a0),d1
	sub.w	d2,d1			; x1 - b
.ga:	move.w	d0,d4
	sub.w	MS_SPB(a1),d4
	bpl.s	.gb
	move.w	MS_SPB(a0),d4
	sub.w	d2,d4
.gb:	cmp.w	d4,d1
	ble	.ua
	bra.s	.ub
.nx:	addq.l	#2,a0
	addq.l	#2,a1
	dbf	d3,.r
	move.w	#1,ms_any
	movem.w	(sp)+,d0-d2
.x:	movem.l	(sp)+,d3-d4
	rts

ms_flush:				; (Phase 6h) the cursor stays on the screen: lines under it wait
	bsr	snd_poll
	ifd	CNTDBG
	addq.l	#1,ms_cntf
	endif		; for a second pass that takes it off for just those lines and
	tst.w	ms_any			; draws it again at once; meanwhile the VBL may move it, but
	beq	.none			; never onto the line being converted (kbd_busy)
	movem.l	d3-d5/a3-a4,-(sp)
	tst.b	ms_mon
	beq.s	.m0
	move.l	vid_lutgen,d0		; (the mirror: lines of bands whose LUT changed are not known)
	cmp.l	ms_lutgen,d0
	beq.s	.m0
	bsr	ms_lutchk
.m0:	clr.w	ms_defer
	lea	ms_x1,a3
	lea	ms_x2,a4
	move.w	ms_ymin,d3		; y: the dirty range only
	add.w	d3,a3
	add.w	d3,a3
	add.w	d3,a4
	add.w	d3,a4
	move.w	ms_ymax,d4
.y:	cmp.w	#$7fff,(a3)
	bne	.a
	cmp.w	#$7fff,MS_SPB(a3)
	beq	.n
.a:	tst.b	ms_mon
	beq	.e0
	lea	ms_shv,a0
	tst.b	0(a0,d3.w)
	bne	.e0
	move.b	#2,0(a0,d3.w)		; a line not known: all of it now, known afterwards
	st	ms_any2
	clr.w	(a3)
	move.w	#MS_W-1,(a4)
	move.w	#$7fff,MS_SPB(a3)
	move.w	#-1,MS_SPB(a4)
.e0:
	ifd	SPANDBG
	addq.w	#1,ms_dbgn
	cmp.w	#SPANDBG,ms_dbgn
	blo	.sd
	cmp.w	#SPANDBG+400,ms_dbgn
	bhs	.sd
	moveq	#0,d0
	move.w	d3,d0
	lsl.l	#6,d0
	move.w	(a3),d1
	lsr.w	#3,d1
	and.w	#63,d1
	or.w	d1,d0
	lsl.l	#6,d0
	move.w	(a4),d1
	lsr.w	#3,d1
	and.w	#63,d1
	or.w	d1,d0
	lsl.l	#6,d0
	move.w	MS_SPB(a3),d1
	lsr.w	#3,d1
	and.w	#63,d1
	or.w	d1,d0
	or.l	#230<<24,d0
	bsr	scr_dbg
	moveq	#0,d0
	move.w	MS_SPB(a4),d0
	or.l	#231<<24,d0
	bsr	scr_dbg
.sd:
	endif
	bsr	ms_fline		; span A
	lea	MS_SPB(a3),a3
	lea	MS_SPB(a4),a4
	bsr	ms_fline		; span B
	lea	-MS_SPB(a3),a3
	lea	-MS_SPB(a4),a4
.n:	addq.l	#2,a3
	addq.l	#2,a4
	addq.w	#1,d3
	cmp.w	d4,d3
	ble	.y
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
	beq.s	.b2
	bsr	ms_span
.b2:	cmp.w	#$7fff,MS_SPB(a3)
	beq.s	.n2
	lea	MS_SPB(a3),a3
	lea	MS_SPB(a4),a4
	bsr	ms_span
	lea	-MS_SPB(a3),a3
	lea	-MS_SPB(a4),a4
.n2:	addq.l	#2,a3
	addq.l	#2,a4
	addq.w	#1,d3
	cmp.w	d4,d3
	ble.s	.y2
	tst.w	d5
	beq.s	.done
	bsr	kbd_cursor_drawnow
	move.w	d5,kbd_cur_on
.done:	tst.b	ms_any2			; (lines converted whole: known now)
	beq.s	.d0
	sf	ms_any2
	bsr	ms_known
.d0:	move.w	ms_xfmin,d0		; (the lines' "changed" marks: done)
	move.w	ms_xfmax,d1
	sub.w	d0,d1
	bmi.s	.d1
	lea	ms_xf,a0
	add.w	d0,a0
.dx:	clr.b	(a0)+
	dbf	d1,.dx
	move.w	#MS_H,ms_xfmin
	move.w	#-1,ms_xfmax
.d1:	clr.w	ms_any
	move.w	#MS_H,ms_ymin
	move.w	#-1,ms_ymax
	movem.l	(sp)+,d3-d5/a3-a4
.none:	rts

; ms_fline: line d3, (a3)/(a4) = one of its spans (x1 = $7fff: none): convert it now, or - when the
; drawn cursor is on it - the parts beside the cursor now and its 32 pixels in the flush's second
; pass (ms_defer; the span keeps that part).  trashes: d0-d2/a0-a2
ms_fline:
	cmp.w	#$7fff,(a3)
	beq.s	.x
	tst.w	kbd_cur_on
	beq.s	.cv			; off: nothing drawn (the VBL draws nothing either)
	move.w	d3,d1
	addq.w	#1,d1
	move.w	d1,kbd_busy		; first: from here the VBL leaves this line alone
	move.w	d3,d0			; (Phase 6k: a line outside the drawn cursor's 16 rows needs no
	sub.w	kbd_save_y,d0		; closer look - the VBL cannot move it here any more)
	cmp.w	#16,d0
	bhs.s	.cv
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
.x:	rts
.cv:	bra	ms_span

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
	tst.b	ms_mon
	beq.s	ms_conv0
	lea	ms_shv,a0
	cmp.b	#1,0(a0,d3.w)
	bne.s	.cc
	lea	ms_xf,a0		; (known to have changed: no comparing)
	tst.b	0(a0,d3.w)
	beq	ms_convm
.cc:
	movem.w	d0/d2,-(sp)		; a line not known: convert, and the mirror takes it
	bsr.s	ms_conv0
	movem.w	(sp)+,d0/d2
	move.w	d3,d1
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	add.w	d0,a0
	move.l	a0,a1
	add.l	ms_shoff,a1
	sub.w	d0,d2
	lsr.w	#2,d2			; longs - 1 (spans are whole cells)
.cp:	move.l	(a0)+,(a1)+
	dbf	d2,.cp
	rts
ms_conv0:
	sub.w	d0,d2
	addq.w	#1,d2			; count
	move.w	d3,d1
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	add.w	d0,a0
	move.w	d3,d1
	bra	gfx_c4_span

; ms_convm (Phase 6k): line d3 (known), x d0..d2 (whole cells): convert only the runs of cells
; whose shadow differs from the mirror, and copy them into it.  trashes: d0-d2/a0-a2
ms_convm:
	move.w	d3,d1			; first the scan with scratch registers only: most spans are
	mulu	#MS_W,d1		; as shown (nothing saved, nothing called)
	move.l	ms_buf,a0
	add.l	d1,a0
	add.w	d0,a0			; the shadow
	move.l	a0,a1
	add.l	ms_shoff,a1		; the mirror
	move.w	d2,d1
	sub.w	d0,d1
	lsr.w	#3,d1			; cells - 1
	ifd	CNTDBG
	move.w	d1,d2
	addq.w	#1,d2
	ext.l	d2
	add.l	d2,ms_cntc
	endif
.q:	cmpm.l	(a0)+,(a1)+
	bne.s	.q1
	cmpm.l	(a0)+,(a1)+
	bne.s	.q2
	addq.w	#8,d0
	dbf	d1,.q
	rts
.q2:	subq.l	#4,a0			; a changed cell: the runs from here
	subq.l	#4,a1
.q1:	subq.l	#4,a0
	subq.l	#4,a1
	movem.l	d4-d7/a3-a4,-(sp)
	move.l	a0,a3
	move.l	a1,a4
	move.w	d0,d4			; x of the cell
	move.w	d1,d5			; cells left - 1
	bra.s	.r
.s:	cmpm.l	(a3)+,(a4)+		; the same as shown?
	bne.s	.d1
	cmpm.l	(a3)+,(a4)+
	bne.s	.d2
	addq.w	#8,d4
	dbf	d5,.s
	bra.s	.x
.d2:	subq.l	#4,a3			; (back to the cell's start)
	subq.l	#4,a4
.d1:	subq.l	#4,a3
	subq.l	#4,a4
.r:	move.w	d4,d6			; a run from here
	move.l	a3,d7
.e:	move.l	(a3)+,d0
	move.l	(a3)+,d1
	cmp.l	(a4),d0
	bne.s	.ec
	cmp.l	4(a4),d1
	beq.s	.ee
.ec:	move.l	d0,(a4)+
	move.l	d1,(a4)+
	addq.w	#8,d4
	dbf	d5,.e
	bsr.s	.cv			; the run reaches the span's end
	bra.s	.x
.ee:	addq.l	#8,a4			; this cell is as shown: the run ends before it
	bsr.s	.cv
	addq.w	#8,d4
	dbf	d5,.s
.x:	movem.l	(sp)+,d4-d7/a3-a4
	rts
.cv:	move.l	d7,a0			; convert x d6 .. d4-1
	move.w	d6,d0
	move.w	d4,d2
	sub.w	d6,d2
	ifd	CNTDBG
	moveq	#0,d1
	move.w	d2,d1
	add.l	d1,ms_cntv
	endif
	move.w	d3,d1
	bra	gfx_c4_span

; ms_mirror (Phase 6k): d0.b <> 0: the mirror on from here (every line unknown first), 0: off.
; The screens that redraw much that has not changed turn it on (the exploration); on the
; bridge most of what is flushed has changed (the planet) and the compares cost more than they
; save.  trashes: d0-d2/a0-a2
ms_mirror:
	tst.b	d0
	beq.s	.off
	tst.b	ms_mok
	beq.s	.off
	ifnd	NOMIRROR		; (ASMDEFS=-DNOMIRROR=1: never on, for comparisons)
	bsr	ms_flush		; (what is marked goes out the old way)
	bsr.s	ms_inval
	st	ms_mon
	rts
	endif
.off:	sf	ms_mon
	rts

; ms_inval: no line known (the mirror).  trashes: d0/a0
ms_inval:
	lea	ms_shv,a0
	moveq	#MS_H/4-1,d0
.c:	clr.l	(a0)+
	dbf	d0,.c
	rts
; ms_invrows: lines d0..d1 not known.  trashes: d0-d1/a0
ms_invrows:
	lea	ms_shv,a0
	add.w	d0,a0
	sub.w	d0,d1
	bmi.s	.x
.c:	clr.b	(a0)+
	dbf	d1,.c
.x:	rts
; ms_known: the lines a flush converted whole (2) are known (1).  trashes: d0-d1/a0
ms_known:
	lea	ms_shv,a0
	move.w	ms_ymin,d0
	move.w	ms_ymax,d1
	sub.w	d0,d1
	bmi.s	.x
	add.w	d0,a0
.l:	cmp.b	#2,(a0)+
	bne.s	.n
	move.b	#1,-1(a0)
.n:	dbf	d1,.l
.x:	rts
; ms_lutchk: the LUTs changed (vid_lutgen): the lines whose LUT is another one or whose band's
; LUT changed are not known.  trashes: d0-d2/a0-a2
ms_lutchk:
	move.l	vid_lutgen,ms_lutgen
	move.l	d3,-(sp)
	moveq	#0,d3			; changed bands
	lea	vid_luts,a0
	lea	ms_shlut,a1
	moveq	#0,d2
.b:	moveq	#256/4-1,d0
.c:	move.l	(a0)+,d1
	cmp.l	(a1)+,d1
	beq.s	.e
	bset	d2,d3
.e:	dbf	d0,.c
	addq.w	#1,d2
	cmp.w	#4,d2
	blt.s	.b
	lea	vid_luts,a0
	lea	ms_shlut,a1
	move.w	#1024/4-1,d0
.cl:	move.l	(a0)+,(a1)+
	dbf	d0,.cl
	lea	vid_line_lut,a0
	lea	ms_shll,a1
	lea	ms_shv,a2
	move.w	#MS_H-1,d2
.y:	move.l	(a0)+,d0
	cmp.l	(a1),d0
	bne.s	.inv
	sub.l	#vid_luts,d0
	lsr.l	#8,d0			; the band
	btst	d0,d3
	beq.s	.ok
.inv:	clr.b	(a2)
.ok:	move.l	-4(a0),(a1)+
	addq.l	#1,a2
	dbf	d2,.y
	move.l	(sp)+,d3
	rts

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
.np:	bsr	ms_inval		; (the mirror: the planar screen is the picture now)
	bsr	ms_clean
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
	bsr	ms_inval		; (the mirror: the planar screen is the snapshot's)
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
	bsr	ms_tmlook		; (Phase 6l) a1 = the memo entry to keep a copy in, d2.b = $ff:
	tst.b	d2			; the text is there already (nothing to print or mark)
	bne.s	.hit
	move.l	a1,-(sp)
	movem.l	4(sp),d0-d1/a0
	bsr	chk_print
	seq	d2			; $ff: chk_print changed nothing
	move.l	(sp)+,a1
	move.l	a1,d0
	beq.s	.hit
	move.w	d2,-(sp)
	bsr	ms_tmsave
	move.w	(sp)+,d2
.hit:	movem.l	(sp)+,d0-d1/a0
	move.b	d2,-(sp)		; (Phase 6k) the same text where it was: nothing to mark
	move.w	d3,-(sp)
	moveq	#0,d2
	move.b	(a0),d2			; x2 = x1 + 4 + 5*len
	mulu	#5,d2
	add.w	d0,d2
	addq.w	#4,d2
	cmp.w	#MS_W-1,d2
	ble.s	.w
	move.w	#MS_W-1,d2
.w:	tst.b	2(sp)
	beq.s	.mk
	and.w	#$fff8,d0		; (unmarked: d0-d2 as ms_dirty would leave them)
	or.w	#7,d2
	addq.w	#6,d1
	cmp.w	#MS_H-1,d1
	ble.s	.u
	move.w	#MS_H-1,d1
.u:	move.w	(sp)+,d3
	addq.l	#2,sp
	rts
.mk:	move.w	d1,d3
	addq.w	#6,d3
	cmp.w	#MS_H-1,d3
	ble.s	.h
	move.w	#MS_H-1,d3
.h:	bsr	ms_dirty
	move.w	(sp)+,d3
	addq.l	#2,sp
	rts

; ---------------------------------------------------------------- the text memo (Phase 6l)
; The original reprints the same labels every frame (the exploration's info box: ~12 % of its
; frame). chk_print draws a string's characters at (x+5, y+1), 5 pixels each, 6 rows, from the
; string, tcolor, bkcolor, txt_flat and the font alone (over the pixels there when bkcolor is 255).
; So when the shadow's rectangle holds exactly what the same print left there before, printing
; again changes nothing: ms_print skips it (no mark: unchanged pixels need no flush). Entries per
; position (MS_TMN, round robin); a copy of the rectangle is kept only once a print repeats (text
; that changes every time costs the key compare only). Only on MAIN's full-screen chk window.
MS_TMN		equ	16
MS_TML		equ	40		; longest string memoised
MS_TMX		equ	0		; entry: x.w, y.w, tcolor.w, bkcolor.w, flat.w, font.l, opt.b,
MS_TMY		equ	2		; valid.b (the copy), the string (len + MS_TML), the copy
MS_TMTC		equ	4
MS_TMBK		equ	6
MS_TMFL		equ	8
MS_TMFN		equ	10
MS_TMOF		equ	14
MS_TMV		equ	15
MS_TMS		equ	16
MS_TMB		equ	16+MS_TML+2	; (even) copy: 6 rows of (5*len+1)&~1 bytes, + 1 for parity
MS_TMSZ		equ	MS_TMB+6*(5*MS_TML)+2
; ms_tmlook(x d0, y d1, a0 = string) -> d2.b = $ff: skip; else a1 = entry to save the copy in
; after printing (0: none)
; in: d0.w = x, d1.w = y, a0 = string  out: d2.b = skip flag, a1 = entry  trashes: d0-d1/a0/a2
ms_tmlook:
	movem.l	d3-d5/a3,-(sp)
	sub.l	a1,a1
	moveq	#0,d2
	move.l	ms_buf,d3
	cmp.l	chk_buf,d3
	bne	.x
	cmp.w	#MS_W,chk_w
	bne	.x
	tst.l	chk_x0			; (x0 and y0)
	bne	.x
	moveq	#0,d3
	move.b	(a0),d3			; len
	beq	.x
	cmp.w	#MS_TML,d3
	bhi	.x
	cmp.w	#-5,d0			; the rectangle on the screen
	blt	.x
	move.w	d3,d4
	mulu	#5,d4
	add.w	d0,d4
	cmp.w	#MS_W-5,d4		; x + 5 + 5*len <= 320
	bgt	.x
	cmp.w	#-1,d1
	blt	.x
	cmp.w	#MS_H-7,d1		; y + 6 <= 199
	bgt	.x
	lea	ms_tm,a3		; the entry for (x, y)
	moveq	#MS_TMN-1,d4
.f:	cmp.w	MS_TMX(a3),d0
	bne.s	.fn
	cmp.w	MS_TMY(a3),d1
	beq.s	.found
.fn:	lea	MS_TMSZ(a3),a3
	dbf	d4,.f
	move.w	ms_tmnext,d4		; none: the next one (round robin)
	move.w	d4,d5
	addq.w	#1,d5
	and.w	#MS_TMN-1,d5
	move.w	d5,ms_tmnext
	mulu	#MS_TMSZ,d4
	lea	ms_tm,a3
	add.l	d4,a3
	bra	.new
.found:	move.w	GS_TCOLOR(a6),d4	; the same print?
	cmp.w	MS_TMTC(a3),d4
	bne	.new
	move.w	GS_BKCOLOR(a6),d4
	cmp.w	MS_TMBK(a3),d4
	bne	.new
	move.w	txt_flat,d4
	cmp.w	MS_TMFL(a3),d4
	bne.s	.new
	move.l	txt_fontptr,d4
	cmp.l	MS_TMFN(a3),d4
	bne.s	.new
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_FONT-1(a6),d4
	cmp.b	MS_TMOF(a3),d4
	bne.s	.new
	lea	MS_TMS(a3),a1
	move.l	a0,a2
	move.w	d3,d4			; len + 1 bytes
.sc:	cmpm.b	(a2)+,(a1)+
	bne.s	.new
	dbf	d4,.sc
	move.l	a3,a1			; the same print: save a copy after it if there is none yet,
	tst.b	MS_TMV(a3)		; else compare
	beq	.x
	bsr	ms_tmrect		; a0 = the shadow's first byte, a2 = the copy's, d4 = width
	moveq	#6-1,d5
.r:	move.l	a0,-(sp)
	move.l	a2,-(sp)
	move.w	d4,d0
	move.l	a0,d1
	btst	#0,d1
	beq.s	.re
	cmpm.b	(a2)+,(a0)+
	bne.s	.rx
	subq.w	#1,d0
.re:	move.w	d0,d1
	lsr.w	#2,d1
	bra.s	.rl1
.rl:	cmpm.l	(a2)+,(a0)+
	bne.s	.rx
.rl1:	dbf	d1,.rl
	and.w	#3,d0
	bra.s	.rb1
.rb:	cmpm.b	(a2)+,(a0)+
	bne.s	.rx
.rb1:	dbf	d0,.rb
	move.l	(sp)+,a2
	move.l	(sp)+,a0
	lea	MS_W(a0),a0
	add.w	d3,a2			; (the copy's row stride: d3 = (width+1) & ~1)
	dbf	d5,.r
	st	d2			; all equal: skip
	sub.l	a1,a1
	bra.s	.x
.rx:	addq.l	#8,sp			; a difference: print, then keep the new copy
	bra.s	.x
.new:	move.w	d0,MS_TMX(a3)		; a new print here: its key, no copy until it repeats
	move.w	d1,MS_TMY(a3)
	move.w	GS_TCOLOR(a6),MS_TMTC(a3)
	move.w	GS_BKCOLOR(a6),MS_TMBK(a3)
	move.w	txt_flat,MS_TMFL(a3)
	move.l	txt_fontptr,MS_TMFN(a3)
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_FONT-1(a6),MS_TMOF(a3)
	sf	MS_TMV(a3)
	lea	MS_TMS(a3),a1
	move.w	d3,d4
.cs:	move.b	(a0)+,(a1)+
	dbf	d4,.cs
	sub.l	a1,a1
.x:	movem.l	(sp)+,d3-d5/a3
	rts
; a3 = entry (x, y, string set): a0 = the shadow at (x+5, y+1), a2 = the copy (same parity),
; d4 = width 5*len, d3 = the copy's row stride
; in: a3 = entry  out: a0 = shadow, a2 = copy, d3.w = stride, d4.w = width  trashes: d0-d1
ms_tmrect:
	move.w	MS_TMY(a3),d1
	addq.w	#1,d1
	mulu	#MS_W,d1
	move.w	MS_TMX(a3),d0
	addq.w	#5,d0
	ext.l	d0
	add.l	d0,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	lea	MS_TMB(a3),a2
	move.l	a0,d0
	and.w	#1,d0
	add.w	d0,a2
	moveq	#0,d4
	move.b	MS_TMS(a3),d4
	mulu	#5,d4
	move.w	d4,d3
	addq.w	#1,d3
	and.w	#$fffe,d3
	rts
; ms_tmsave(a1 = entry): the rectangle as printed into its copy
; in: a1 = entry  out: -  trashes: d0-d2/a0-a2
ms_tmsave:
	movem.l	d3-d5/a3,-(sp)
	move.l	a1,a3
	bsr	ms_tmrect
	moveq	#6-1,d5
.r:	move.l	a0,a1
	move.w	d4,d0
	subq.w	#1,d0
.b:	move.b	(a1)+,(a2)+		; (a few hundred bytes, once per repeated text)
	dbf	d0,.b
	sub.w	d4,a2
	add.w	d3,a2
	lea	MS_W(a0),a0
	dbf	d5,.r
	st	MS_TMV(a3)
	movem.l	(sp)+,d3-d5/a3
	rts

mousehide:				; (Phase 6h) the game draws into the shadow only: the cursor
	bra	kbd_cursor_soft		; stays (kernel kbd.s: off after KBD_SOFTV frames)
mousehidep:				; for code that writes the planar screen itself
	bsr	ms_inval		; (the mirror: from here the planar screen is not known)
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
	tst.b	ms_mon			; (the mirror follows on a known line)
	beq.s	.nm
	move.w	2(sp),d1
	lea	ms_shv,a1
	tst.b	0(a1,d1.w)
	beq.s	.nm
	add.l	ms_shoff,a0
	move.b	d2,0(a0,d0.w)
.nm:	move.w	(sp)+,d0
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
	tst.b	ms_mon			; (the mirror follows on a known line)
	beq.s	.nm
	lea	ms_shv,a1
	tst.b	0(a1,d3.w)
	beq.s	.nm
	add.l	ms_shoff,a0
	move.b	d2,0(a0,d0.w)
.nm:	lea	vid_line_lut,a0
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
	move.w	d6,d0			; (the mirror: the moved rows are not known)
	move.w	d6,d1
	tst.w	d4
	bmi.s	.vd
	add.w	d7,d1
	bra.s	.vi
.vd:	sub.w	d7,d0
.vi:	bsr	ms_invrows
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
ms_tmnext:	ds.w	1		; (6l) the text memo's next entry
ms_tm:		ds.b	MS_TMN*MS_TMSZ
ms_design:	ds.w	1		; (Phase 6i/6k) the bridge design in use: u2_design's codes (0 MAIN), -1 another
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
ms_x1:		ds.w	MS_H		; per line: span A (x1 = $7fff: none) ...
ms_x2:		ds.w	MS_H
ms_x3:		ds.w	MS_H		; ... and span B (Phase 6k), MS_SPB bytes after A
ms_x4:		ds.w	MS_H
ms_shw:		ds.l	1		; (Phase 6k) the mirror: what the planar screen shows, as indices
ms_shoff:	ds.l	1		; ms_shw - ms_buf
ms_lutgen:	ds.l	1		; vid_lutgen when ms_shlut/ms_shll were taken
ms_shll:	ds.l	MS_H		; vid_line_lut then
ms_shlut:	ds.b	1024		; vid_luts then
ms_shv:		ds.b	MS_H		; per line: 0 not known, 1 known, 2 converted whole by this flush
ms_xf:		ds.b	MS_H		; per line: marked by ms_dirtyx (changed for sure)
ms_mon:		ds.b	1		; the mirror is on
ms_mok:		ds.b	1		; the mirror has its buffer
ms_any2:	ds.b	1		; a flush converted a line not known (ms_known has work)
	even
ms_xfmin:	ds.w	1		; the lines ms_dirtyx marked
ms_xfmax:	ds.w	1
	even
	ifd	SPANDBG
ms_dbgn:	ds.w	1
	endif
	ifd	CNTDBG
ms_cntc:	ds.l	1
ms_cntv:	ds.l	1
ms_cntf:	ds.l	1
	endif
	even
