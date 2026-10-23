; pic.s - pictures converted by tools/cpr2st.py (.ISP). Part of kernel.s.
;
; pic_load    in: a0 = file name, a1 = destination screen (320x200 pictures only)
;             Sets the picture's bands (palettes) and LUTs, copies the planar image.
;             out: carry set on error.  trashes: d0-d2/a0-a2
; File: 'ISP1', w.w, h.w, BANDS (2 + 4*34 bytes), 4 x 256 LUT bytes, planar data.

ISP_BANDS	equ	8
ISP_LUTS	equ	ISP_BANDS+2+4*34
ISP_DATA	equ	ISP_LUTS+1024
ISP_FULL	equ	ISP_DATA+SCR_SIZE

	section	text
pic_load:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	a1,a5
	move.l	a0,a4
	bsr	mem_mark
	move.l	d0,d7
	move.l	#ISP_FULL,d0
	bsr	mem_alloc
	bcs.s	.err
	move.l	a0,a3
	move.l	a4,a0
	move.l	a3,a1
	move.l	#ISP_FULL,d0
	bsr	fil_load
	bcs.s	.err
	cmp.l	#ISP_FULL,d0
	bne.s	.err
	cmp.l	#'ISP1',(a3)
	bne.s	.err
	cmp.l	#(320<<16)|200,4(a3)
	bne.s	.err
	lea	ISP_BANDS(a3),a0
	bsr	vid_set_bands
	lea	ISP_LUTS(a3),a0
	bsr	vid_set_luts
	move.l	d7,-(sp)
	lea	ISP_DATA(a3),a0		; copy 32000 bytes, 40 at a time
	move.l	a5,a1
	move.w	#SCR_SIZE/40-1,d7
.cp:	movem.l	(a0)+,d0-d6/a2-a4
	movem.l	d0-d6/a2-a4,(a1)
	lea	40(a1),a1
	dbf	d7,.cp
	move.l	(sp)+,d7
.ok:	move.l	d7,d0
	bsr	mem_release
	movem.l	(sp)+,d3-d7/a3-a5
	and.b	#$fe,ccr
	rts
.err:	move.l	d7,d0
	bsr	mem_release
	movem.l	(sp)+,d3-d7/a3-a5
	or.b	#1,ccr
	rts
