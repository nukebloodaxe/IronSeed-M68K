; pmac.i - macros for MAIN.PRG's ported Pascal: drawing calls with constant arguments and inline
; Pascal strings, so a line of the original stays about one line here. Include at the top (macros
; only). Every macro keeps d3-d7/a3-a6 (the ABI's preserved set) and trashes d0-d2/a0-a2.

; an inline Pascal string (length byte + text) in the data section; a0 = its address
PLEA	macro
	lea	.ps\@,a0
	section	data
.ps\@:	dc.b	.pe\@-.ps\@-1,\1
.pe\@:
	even
	section	text
	endm

; printxy(x, y, 'text')  (data.pas printxy into the shadow, GS_TCOLOR on GS_BKCOLOR)
PXY	macro
	lea	.ps\@,a0
	move.w	#\1,d0
	move.w	#\2,d1
	bsr	printxy
	section	data
.ps\@:	dc.b	.pe\@-.ps\@-1,\3
.pe\@:
	even
	section	text
	endm

; printxy(x, y, string at label)
PXYS	macro
	lea	\3,a0
	move.w	#\1,d0
	move.w	#\2,d1
	bsr	printxy
	endm

; journey.pas print('text') / println
PRT	macro
	lea	.ps\@,a0
	bsr	print
	section	data
.ps\@:	dc.b	.pe\@-.ps\@-1,\1
.pe\@:
	even
	section	text
	endm
PRTLN	macro
	bsr	println
	endm

TCOL	macro
	move.w	#\1,GS_TCOLOR(a6)
	endm
BKCOL	macro
	move.w	#\1,GS_BKCOLOR(a6)
	endm
; bkcolor := 179 if word variable \1 (a GS offset) = \2, else 5 (the panels' highlighted row)
BKSEL	macro
	move.w	#5,GS_BKCOLOR(a6)
	cmp.w	#\2,\1(a6)
	bne.s	.bk\@
	move.w	#179,GS_BKCOLOR(a6)
.bk\@:
	endm

; setcolor(c); line(x1,y1,x2,y2)
LINE	macro
	movem.l	d3-d4,-(sp)
	move.w	#\1,d0
	move.w	#\2,d1
	move.w	#\3,d2
	move.w	#\4,d3
	move.w	#\5,d4
	bsr	ms_line
	movem.l	(sp)+,d3-d4
	endm
; screen[y,x] := c   (PSET x,y,c)
PSET	macro
	move.w	#\1,d0
	move.w	#\2,d1
	move.w	#\3,d2
	bsr	ms_pset
	endm
; for i := y1 to y2 do scr_fillchar(screen[i,x1], x2-x1+1, c)   (BAR x1,y1,x2,y2,c)
BAR	macro
	movem.l	d3-d4,-(sp)
	move.w	#\1,d0
	move.w	#\2,d1
	move.w	#\3,d2
	move.w	#\4,d3
	move.w	#\5,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
	endm
; plainfadearea(x1,y1,x2,y2,alt)
FADE	macro
	movem.l	d3-d4,-(sp)
	move.w	#\1,d0
	move.w	#\2,d1
	move.w	#\3,d2
	move.w	#\4,d3
	move.w	#\5,d4
	bsr	plainfadearea
	movem.l	(sp)+,d3-d4
	endm
; graybutton / revgraybutton(x1,y1,x2,y2)
GRAYB	macro
	move.l	d3,-(sp)
	move.w	#\1,d0
	move.w	#\2,d1
	move.w	#\3,d2
	move.w	#\4,d3
	bsr	graybutton
	move.l	(sp)+,d3
	endm
RGRAYB	macro
	move.l	d3,-(sp)
	move.w	#\1,d0
	move.w	#\2,d1
	move.w	#\3,d2
	move.w	#\4,d3
	bsr	revgraybutton
	move.l	(sp)+,d3
	endm
; showpanel(buttons) with the three button numbers
SHOWPANEL macro
	move.w	#\1,d0
	move.w	#\2,d1
	move.w	#\3,d2
	bsr	showpanel
	endm
; delay(tslice * n)
DELAYTS	macro
	move.w	GS_TSLICE(a6),d0
	mulu	#\1,d0
	bsr	delay
	endm
; floating point: push the double at GS offset / label, pop into it
FLDG	macro
	lea	\1(a6),a0
	bsr	fp_ldd
	endm
FSTG	macro
	lea	\1(a6),a0
	bsr	fp_std
	endm
FLDI	macro
	move.l	#\1,d0
	bsr	fp_ldi
	endm
FLDX	macro
	lea	\1,a0
	bsr	fp_ldx
	endm
; genericrightside(buttons) with the three button numbers
SHOWPANEL_GR macro
	move.w	#\1,d0
	move.w	#\2,d1
	move.w	#\3,d2
	bsr	genericrightside
	endm
