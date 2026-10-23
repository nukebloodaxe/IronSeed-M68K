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
; ms_flush     convert the dirty spans to the shown screen (cursor kept off meanwhile), clear
;              them                                                       trashes: d0-d2/a0-a2
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
; mousehide / mouseshow   the original's: hide; flush + show
; delay        in: d0.w ms: flush, then tim_delay (the original's delay)  trashes: d0-d2/a0-a2
; ms_psetp     in: d0.w x, d1.w y, d2.b colour: the shadow pixel and the planar one at once,
;              nothing marked (for pixel-by-pixel effects; the cursor must be hidden) trashes: d0-d2/a0-a1
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
	and.w	#$fff8,d0		; whole cells: the flush takes its fast path
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

ms_flush:
	bsr	snd_poll
	tst.w	ms_any
	beq	.none
	movem.l	d3-d4/a3-a4,-(sp)
	move.w	kbd_cur_on,-(sp)
	beq.s	.off
	bsr	ms_curhit		; the cursor is only taken off if a dirty span meets it
	bne.s	.hide
	clr.w	kbd_cur_on		; (else the VBL only leaves it alone meanwhile: it stays drawn)
	bra.s	.off
.hide:	bsr	kbd_cursor_hide
.off:	lea	ms_x1,a3
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
	move.w	(a4),d2
	sub.w	d0,d2
	addq.w	#1,d2			; count
	move.w	#$7fff,(a3)
	move.w	#-1,(a4)
	move.w	d3,d1
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	add.w	d0,a0
	move.w	d3,d1
	bsr	gfx_c4_span
.n:	addq.l	#2,a3
	addq.l	#2,a4
	addq.w	#1,d3
	cmp.w	d4,d3
	ble.s	.y
	clr.w	ms_any
	move.w	#MS_H,ms_ymin
	move.w	#-1,ms_ymax
	tst.w	(sp)+
	beq.s	.x
	bsr	kbd_cursor_show
.x:	movem.l	(sp)+,d3-d4/a3-a4
.none:	rts

; ms_curhit: Z clear if the cursor's drawn rectangle (32 pixels from its group, kbd_save_rows
; lines; on another screen than the flush's target: always) meets a dirty span.
; trashes d0-d4/a0-a1
ms_curhit:
	move.l	kbd_save_at,d0
	beq.s	.no			; not drawn
	move.l	kbd_save_scr,d1
	cmp.l	gfx_target,d1
	bne.s	.yes
	sub.l	d1,d0
	divu	#SCR_BPL,d0		; y0; the remainder: the byte in the line
	move.l	d0,d3
	swap	d3
	lsr.w	#3,d3
	lsl.w	#4,d3			; x left
	move.w	d3,d4
	add.w	#31,d4			; x right
	move.w	d0,d1			; last line
	add.w	kbd_save_rows,d1
	subq.w	#1,d1
	cmp.w	ms_ymax,d1
	ble.s	.l1
	move.w	ms_ymax,d1
.l1:	cmp.w	ms_ymin,d0
	bge.s	.l2
	move.w	ms_ymin,d0
.l2:	sub.w	d0,d1			; lines - 1
	bmi.s	.no
	lea	ms_x1,a0
	lea	ms_x2,a1
	add.w	d0,d0
	add.w	d0,a0
	add.w	d0,a1
.y:	cmp.w	(a0)+,d4		; x1 <= right and x2 >= left: it meets
	blt.s	.n
	cmp.w	(a1),d3
	ble.s	.yes
.n:	addq.l	#2,a1
	dbf	d1,.y
.no:	moveq	#0,d0
	rts
.yes:	moveq	#1,d0
	rts

ms_addr:
	mulu	#MS_W,d1
	move.l	ms_buf,a0
	add.l	d1,a0
	add.w	d0,a0
	rts

ms_load:
	movem.l	d3/a3,-(sp)
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
	bsr	kbd_cursor_hide		; (the caller shows it again)
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

MS_SNAP		equ	MS_W*MS_H+SCR_SIZE+(2+4*BAND_SIZE)+1024+64+64+768

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
	tst.w	(sp)+
	beq.s	.x
	bsr	kbd_cursor_show
.x:	movem.l	(sp)+,d3/a3
	rts

ms_unsnap:
	movem.l	d3/a3,-(sp)
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

mousehide:
	bra	kbd_cursor_hide

mouseshow:
	bsr	ms_flush
	bra	kbd_cursor_show

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

	section	data
ms_path:	dc.b	"DATA",92,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	even

	section	bss
ms_buf:		ds.l	1
ms_snaps:	ds.l	3
ms_color:	ds.w	1		; graph.setcolor's colour (rectangle, circle in explore)
ms_any:		ds.w	1
ms_ymin:	ds.w	1		; first and last line marked dirty since the last flush
ms_ymax:	ds.w	1
ms_x1:		ds.w	MS_H
ms_x2:		ds.w	MS_H
