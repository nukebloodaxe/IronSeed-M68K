; pic.s - pictures converted by tools/cpr2st.py (.ISP). Part of kernel.s.
;
; pic_load    in: a0 = file name, a1 = destination screen (320x200 pictures only)
;             Sets the picture's bands (palettes) and LUTs, copies the planar image.
;             out: carry set on error.  trashes: d0-d2/a0-a2
; File: 'ISP1', w.w, h.w, BANDS (2 + 4*34 bytes), 4 x 256 LUT bytes, planar data;
;       'ISP2' = the same with 64 rep bytes (vid_set256) after the LUTs.

; pic_show    in: a0 = an ISP1/ISP2 picture already in memory, a1 = destination screen
;             (bands, LUTs, reps, picture: as pic_load). trashes: d0-d2/a0-a2
; pal_load    in: a0 = name of a bands+LUTs file (tools/mkpal.py, 'ISP1' with w = h = 0)
;             sets the bands (at the current fade level) and LUTs. carry set on error.

ISP_BANDS	equ	8
ISP_LUTS	equ	ISP_BANDS+2+4*34
ISP_DATA	equ	ISP_LUTS+1024
ISP_FULL	equ	ISP_DATA+SCR_SIZE
ISP2_FULL	equ	ISP_FULL+64

	section	text
pic_load:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	a1,a5
	move.l	a0,a4
	bsr	mem_mark
	move.l	d0,d7
	move.l	#ISP2_FULL,d0
	bsr	mem_alloc
	bcs	.err
	move.l	a0,a3
	move.l	a4,a0
	move.l	a3,a1
	move.l	#ISP2_FULL,d0
	bsr	fil_load
	bcs	.err
	move.l	d0,d6			; bytes read
	cmp.l	#(320<<16)|200,4(a3)
	bne	.err
	lea	ISP_DATA(a3),a4		; picture data (ISP1)
	cmp.l	#'ISP1',(a3)
	beq.s	.v1
	cmp.l	#'ISP2',(a3)
	bne	.err
	cmp.l	#ISP2_FULL,d6
	bne	.err
	lea	ISP_DATA(a3),a0		; ISP2: rep table, then the picture
	bsr	vid_set_reps
	lea	64(a4),a4
	bra.s	.go
.v1:	cmp.l	#ISP_FULL,d6
	bne	.err
.go:	lea	ISP_BANDS(a3),a0
	bsr	vid_set_bands
	lea	ISP_LUTS(a3),a0
	bsr	vid_set_luts
	move.l	d7,-(sp)
	move.l	a4,a0			; copy 32000 bytes, 40 at a time
	move.l	a5,a1
	move.w	#SCR_SIZE/40-1,d7
.cp:	movem.l	(a0)+,d0-d6/a2-a4
	movem.l	d0-d6/a2-a4,(a1)
	lea	40(a1),a1
	dbf	d7,.cp
	move.l	(sp)+,d7
	move.l	d7,d0
	bsr	mem_release
	movem.l	(sp)+,d3-d7/a3-a5
	and.b	#$fe,ccr
	rts
.err:	move.l	d7,d0
	bsr	mem_release
	movem.l	(sp)+,d3-d7/a3-a5
	or.b	#1,ccr
	rts

pal_load:
	movem.l	d3/a3,-(sp)
	lea	pic_palbuf,a1
	move.l	#ISP_DATA+64,d0
	bsr	fil_load
	bcs.s	.err
	cmp.l	#ISP_DATA,d0
	blo.s	.err
	lea	pic_palbuf,a3
	cmp.l	#'ISP1',(a3)
	beq.s	.ok
	cmp.l	#'ISP2',(a3)
	bne.s	.err
	lea	ISP_DATA(a3),a0
	bsr	vid_set_reps
.ok:
	lea	ISP_BANDS(a3),a0
	bsr	vid_set_bands
	lea	ISP_LUTS(a3),a0
	bsr	vid_set_luts
	movem.l	(sp)+,d3/a3
	and.b	#$fe,ccr
	rts
.err:	movem.l	(sp)+,d3/a3
	or.b	#1,ccr
	rts

	section	bss
pic_palbuf:	ds.b	ISP_DATA+64
	even

	section	text
pic_show:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	a0,a3
	move.l	a1,a5
	lea	ISP_DATA(a3),a4
	cmp.l	#'ISP2',(a3)
	bne.s	.v1
	lea	ISP_DATA(a3),a0
	bsr	vid_set_reps
	lea	64(a4),a4
.v1:	lea	ISP_BANDS(a3),a0
	bsr	vid_set_bands
	lea	ISP_LUTS(a3),a0
	bsr	vid_set_luts
	move.l	a4,a0
	move.l	a5,a1
	move.w	#SCR_SIZE/40-1,d7
.cp:	movem.l	(a0)+,d0-d6/a2-a4
	movem.l	d0-d6/a2-a4,(a1)
	lea	40(a1),a1
	dbf	d7,.cp
	movem.l	(sp)+,d3-d7/a3-a5
	rts
