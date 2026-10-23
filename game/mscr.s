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

MS_W		equ	320
MS_H		equ	200

	section	text
ms_init:
	move.l	#MS_W*MS_H,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,ms_buf
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
	rts

ms_dirty_all:
	moveq	#0,d0
	moveq	#0,d1
	move.w	#MS_W-1,d2
	move.w	#MS_H-1,d3
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
	tst.w	ms_any
	beq.s	.none
	movem.l	d3-d4/a3-a4,-(sp)
	move.w	kbd_cur_on,-(sp)
	beq.s	.off
	bsr	kbd_cursor_hide
.off:	lea	ms_x1,a3
	lea	ms_x2,a4
	moveq	#0,d3			; y
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
	cmp.w	#MS_H,d3
	bne.s	.y
	clr.w	ms_any
	tst.w	(sp)+
	beq.s	.x
	bsr	kbd_cursor_show
.x:	movem.l	(sp)+,d3-d4/a3-a4
.none:	rts

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
ms_x1:		ds.w	MS_H
ms_x2:		ds.w	MS_H
