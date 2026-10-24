; comm2.s - comm2.pas computerlogs for MAIN.PRG: the ship logs screen ("Access file": the list of
; logs received and the text of each). Mode LOG (tools/mkmain.py: DATA\LOG.ISP/.CHK, the
; cursor frames in DATA\LOGCUR.DAT are the picture's own, as the original takes them from it).
;
; computerlogs  in: d0.w n: show the log screen at log n (0: the list); returns to the
;               screen that was shown (snapshot)                       trashes: d0-d2/a0-a2
; printxy2      in: d0.w x1, d1.w y1, a0 = string of glyph codes (chr(200) toggles bright):
;               comm2.pas printxy2 into the shadow (tcolor, bkcolor)   trashes: d0-d2/a0-a2

MAXLOGENTRIES	equ	256
TITLE_SIZE	equ	52		; titlebody: id.w, string[49] (+ pad)
LOGPAGE		equ	25*50		; computerlogtype: 25 x string[49]

	section	text
computerlogs:
	movem.l	d3-d7/a3-a5,-(sp)
	moveq	#0,d7			; initialdraw
	clr.w	c2_logindex
	tst.w	d0
	ble.s	.rd
	lea	GS_LOGS(a6),a0		; logindex := position of n in logs[]
	moveq	#0,d1
.f:	cmp.w	(a0)+,d0
	beq.s	.hit
	addq.w	#1,d1
	cmp.w	#MAXLOGENTRIES,d1
	bne.s	.f
	bra.s	.rd
.hit:	move.w	d1,c2_logindex
	moveq	#1,d7
.rd:	move.w	d0,-(sp)
	move.w	d7,d0
	bsr	c2_readydata
	bsr	c2_mainloop
	move.w	(sp)+,d0
	bsr	c2_removedata
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; readydata(initialdraw d0.w)
c2_readydata:
	movem.l	d3/a3,-(sp)
	move.w	d0,d3
	moveq	#0,d0			; compressfile(current2): keep the screen
	bsr	ms_snap
	bsr	mousehide
	moveq	#-8,d0			; fadestopmod(-FADEFULL_STEP, FADEFULL_DELAY)
	moveq	#20,d1
	bsr	fadestopmod
	lea	c2_fn_mod,a0		; playmod(true, CREWEVAL.MOD)
	bsr	playmod
	bsr	orc_dump		; loadscreen(log)
	lea	c2_mode,a0
	bsr	ms_load
	bcs	fatal
	clr.w	c2_index
	sf	c2_qmode
	bsr	mem_mark
	move.l	d0,c2_mark
	move.l	#MAXLOGENTRIES*TITLE_SIZE,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,c2_titles
	move.l	#LOGPAGE+2,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,c2_l
	move.l	c2_titles,a1		; titles: as many records as the file has (<= 256)
	lea	c2_fn_titles,a0
	move.l	#MAXLOGENTRIES*TITLE_SIZE,d0
	bsr	fil_load
	bcs	fatal
	divu	#TITLE_SIZE,d0
	move.w	d0,c2_ntitles
	beq	fatal
	lea	c2_fn_cur,a0		; the 7 cursor frames: the original copies them from the picture
	lea	c2_tmpm,a1		; (rows 120-135, x 9+17j), but LOG.CHK has the text area cleared
	move.l	#7*256,d0		; (mkmain.py), so they come from DATA\LOGCUR.DAT (the same pixels)
	bsr	fil_load
	bcs	fatal
	lea	c2_tmpm,a0		; mousesetcursor(tmpm^[0])
	bsr	kbd_cursor_set
	bsr	c2_cleartext15		; for i:=15 to 170 do scr_fillchar(screen[i,8],246,0)
	bsr	c2_displaylist
	bsr	mouseshow
	tst.w	d3
	beq.s	.x
	st	c2_qmode
	moveq	#63,d0
	bsr	c2_light
	bsr	c2_cleartext15
	bsr	c2_getlog
.x:	sf	c2_done
	movem.l	(sp)+,d3/a3
	rts

c2_cleartext15:
	moveq	#15,d1
	move.w	#170,d0
	bra.s	c2_clear
c2_cleartext14:				; rows 14-173 (the list/read toggles)
	moveq	#14,d1
	move.w	#173,d0
c2_clear:				; rows d1..d0, x 8-253 in 0
	movem.l	d3-d4,-(sp)
	move.w	d0,d3
	moveq	#8,d0
	move.w	#253,d2
	moveq	#0,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
	rts

; the '?' light: screen[42..50, 311..312] := d0
c2_light:
	movem.l	d3-d4,-(sp)
	move.w	d0,d4
	move.w	#311,d0
	moveq	#42,d1
	move.w	#312,d2
	moveq	#50,d3
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
	rts

; removedata(n d0.w)
c2_removedata:
	move.w	d3,-(sp)
	move.w	d0,d3
	move.l	c2_mark,d0		; dispose(tmpm, l, titles)
	bsr	mem_release
	bsr	mousehide
	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	moveq	#3,d0			; mouse.setmousecursor(random(3))
	bsr	mt_random
	bsr	setmousecursor
	bsr	orc_dump		; loadscreen(current2)
	moveq	#0,d0
	bsr	ms_unsnap
	move.w	#3,GS_BKCOLOR(a6)
	tst.w	d3
	bne.s	.n
	moveq	#0,d0			; displaytextbox(false); textindex := 25
	bsr	displaytextbox
	move.w	#25,GS_TEXTINDEX(a6)
.n:	bsr	mouseshow
	st	GS_ANYCHANGE(a6)
	move.w	(sp)+,d3
	rts

; ---------------------------------------------------------------
c2_mainloop:
.l:	moveq	#8,d0			; fadestep(FADESTEP_STEP)
	bsr	fadestep
	bsr	c2_findmouse
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	c2_processkey
.nk:	addq.w	#1,GS_IDLETIME(a6)
	cmp.w	#MAXIDLE,GS_IDLETIME(a6)
	bne.s	.ni
	bsr	screensaver
.ni:	move.w	c2_index,d0		; animated cursor
	addq.w	#1,d0
	cmp.w	#7,d0
	bne.s	.i
	moveq	#0,d0
.i:	move.w	d0,c2_index
	move.w	c2_index,d0		; mousehide; mousesetcursor; mouseshow - kbd_cursor_set swaps
	lsl.w	#8,d0			; the frame in at once, so no hide (it made the cursor flicker)
	lea	c2_tmpm,a0
	add.w	d0,a0
	bsr	kbd_cursor_set
	bsr	ms_flush		; (mouseshow's flush)
	move.w	GS_TSLICE(a6),d0	; delay(tslice*FADE_TSLICE_MUL_COMM2)
	mulu	#6,d0
	bsr	delayp			; (paced: the frame's work counts)
	tst.b	c2_done
	beq.s	.l
	rts

c2_processkey:
	bsr	kbd_readkey
	tst.b	d0
	bne.s	.a
	bsr	kbd_readkey		; extended
	cmp.b	#72,d0
	bne.s	.d
	bsr	c2_subcursor
	bra.s	.x
.d:	cmp.b	#80,d0
	bne.s	.x
	bsr	c2_addcursor
	bra.s	.x
.a:	cmp.b	#'?',d0
	beq.s	.q
	cmp.b	#'/',d0
	beq.s	.q
	cmp.b	#'`',d0			; bossmode
	bne.s	.nb
	bsr	bossmode
	bra.s	.x
.nb:	cmp.b	#27,d0
	bne.s	.x			; (#10 heap stats: not on the ST)
	st	c2_done
	bra.s	.x
.q:	bsr	c2_toggle
.x:	clr.w	GS_IDLETIME(a6)
	rts

; '?' / the light button: list <-> read mode (c2_toggle174: the button at x 306-308 clears
; one more row, 174, when switching to read mode)
c2_toggle174:
	move.w	#174,c2_last
	bra.s	c2_tog
c2_toggle:
	move.w	#173,c2_last
c2_tog:	bsr	mousehide
	tst.b	c2_qmode
	beq.s	.toread
	sf	c2_qmode
	moveq	#79,d0
	bsr	c2_light
	bsr	c2_cleartext14
	bsr	mouseshow
	bra	c2_displaylist
.toread:
	st	c2_qmode
	moveq	#63,d0
	bsr	c2_light
	moveq	#14,d1
	move.w	c2_last,d0
	bsr	c2_clear
	bsr	mouseshow
	bra	c2_getlog

c2_findmouse:
	bsr	kbd_mouse_status
	tst.b	d0
	beq	.x
	bsr	kbd_mouse_xy
	move.w	d0,d2			; x
	move.w	d1,d3			; y
	cmp.w	#11,d2
	blt	.n1
	cmp.w	#211,d2
	bgt	.n1
	; 11..211: a title in the list -> read it
	tst.b	c2_qmode
	bne	.done
	cmp.w	#13,d3
	ble	.done
	cmp.w	#170,d3
	bge	.done
	move.w	d3,d0			; i := ((y-14) div 6) - 13
	sub.w	#14,d0
	ext.l	d0
	divs	#6,d0
	sub.w	#13,d0
	move.w	d0,d4
.up:	tst.w	d4
	ble.s	.dn
	move.w	c2_logindex,d0		; if (logs[logindex+1]>-1) and (logindex<255) then inc
	cmp.w	#MAXLOGENTRIES-1,d0
	bge.s	.u1
	add.w	d0,d0
	lea	GS_LOGS+2(a6),a1
	tst.w	0(a1,d0.w)
	bmi.s	.u1
	addq.w	#1,c2_logindex
.u1:	subq.w	#1,d4
	bra.s	.up
.dn:	tst.w	d4
	bge.s	.go
	tst.w	c2_logindex
	ble.s	.d1
	subq.w	#1,c2_logindex
.d1:	addq.w	#1,d4
	bra.s	.dn
.go:	bsr	mousehide
	moveq	#63,d0
	bsr	c2_light
	tst.b	c2_qmode
	bne.s	.g1
	bsr	c2_cleartext14
.g1:	bsr	mouseshow
	st	c2_qmode
	bsr	c2_getlog
	bra	.done
.n1:	cmp.w	#309,d2			; 309..316, 13 < y < 33: done
	blt.s	.n2
	cmp.w	#316,d2
	bgt	.done
	cmp.w	#13,d3
	ble	.done
	cmp.w	#33,d3
	bge	.done
	st	c2_done
	bra.s	.done
.n2:	cmp.w	#262,d2			; 262..270: the arrows
	blt.s	.n3
	cmp.w	#270,d2
	bgt.s	.n3
	cmp.w	#91,d3
	blt.s	.done
	cmp.w	#101,d3
	bgt.s	.a2
	bsr	c2_subcursor
	bra.s	.done
.a2:	cmp.w	#105,d3
	blt.s	.done
	cmp.w	#115,d3
	bgt.s	.done
	bsr	c2_addcursor
	bra.s	.done
.n3:	cmp.w	#306,d2			; 306..308: done (14..32) or the toggle (39..54)
	blt.s	.n4
	cmp.w	#308,d2
	bgt.s	.done
	cmp.w	#14,d3
	blt.s	.done
	cmp.w	#32,d3
	bgt.s	.t3
	st	c2_done
	bra.s	.done
.t3:	cmp.w	#39,d3
	blt.s	.done
	cmp.w	#54,d3
	bgt.s	.done
	bsr	c2_toggle174
	bra.s	.done
.n4:	cmp.w	#299,d2			; 299..305, 38 < y < 55: the toggle
	blt.s	.done
	cmp.w	#305,d2
	bgt.s	.done
	cmp.w	#38,d3
	ble.s	.done
	cmp.w	#55,d3
	bge.s	.done
	bsr	c2_toggle
.done:	clr.w	GS_IDLETIME(a6)
.x:	rts

c2_subcursor:
	tst.w	c2_logindex
	ble.s	.x
	subq.w	#1,c2_logindex
	bra.s	c2_show
.x:	rts

c2_addcursor:
	move.w	c2_logindex,d0		; if (logs[logindex+1]>=0) and (logindex<255)
	add.w	d0,d0
	lea	GS_LOGS+2(a6),a1
	tst.w	0(a1,d0.w)
	bmi.s	.x
	cmp.w	#MAXLOGENTRIES-1,c2_logindex
	bge.s	.x
	addq.w	#1,c2_logindex
	bra.s	c2_show
.x:	rts

c2_show:
	tst.b	c2_qmode
	beq	c2_displaylist
	bra	c2_getlog

; ---------------------------------------------------------------
; getlogindex(log d0.w) -> a0 = its title record (d0.w = its index)
c2_title:
	move.l	c2_titles,a0
	moveq	#0,d1
.l:	cmp.w	(a0),d0
	beq.s	.f
	lea	TITLE_SIZE(a0),a0
	addq.w	#1,d1
	cmp.w	c2_ntitles,d1
	bne.s	.l
	bra	fatal			; errorhandler('data/titles.dta : n')
.f:	move.w	d1,d0
	rts

; displaylist: 12 titles above the current one, the current one highlighted, the rest below
c2_displaylist:
	movem.l	d3-d5,-(sp)
	bsr	mousehide
	move.w	#79,GS_TCOLOR(a6)
	clr.w	GS_BKCOLOR(a6)
	moveq	#13,d3			; y
	move.w	c2_logindex,d4
	subq.w	#1,d4			; i
	bmi.s	.top
.u:	subq.w	#1,d3
	move.w	d4,d0
	add.w	d0,d0
	lea	GS_LOGS(a6),a1
	move.w	0(a1,d0.w),d0
	bsr	c2_title
	lea	2(a0),a0
	move.w	d3,d1
	mulu	#6,d1
	add.w	#14,d1
	moveq	#6,d0
	bsr	printxy2
	subq.w	#1,d4
	bmi.s	.top
	tst.w	d3
	bne.s	.u
.top:	tst.w	d3			; if y>0 then clear rows 14 .. y*6+14
	ble.s	.t2
	moveq	#8,d0
	moveq	#14,d1
	move.w	#253,d2
	move.w	d3,d3
	mulu	#6,d3
	add.w	#14,d3
	moveq	#0,d4
	bsr	ms_bar
.t2:	moveq	#12,d3
	move.w	c2_logindex,d4
.d:	addq.w	#1,d3
	clr.w	GS_BKCOLOR(a6)
	cmp.w	c2_logindex,d4
	bne.s	.b
	move.w	#9,GS_BKCOLOR(a6)
.b:	move.w	d4,d0
	add.w	d0,d0
	lea	GS_LOGS(a6),a1
	move.w	0(a1,d0.w),d0
	bsr	c2_title
	lea	2(a0),a0
	move.w	d3,d1
	mulu	#6,d1
	add.w	#14,d1
	moveq	#6,d0
	bsr	printxy2
	addq.w	#1,d4
	cmp.w	#MAXLOGENTRIES,d4
	beq.s	.e
	cmp.w	#25,d3
	beq.s	.e
	move.w	d4,d0
	add.w	d0,d0
	lea	GS_LOGS(a6),a1
	tst.w	0(a1,d0.w)
	bpl.s	.d
.e:	cmp.w	#25,d3			; if y<25 then clear rows y*6+21 .. 170
	bge.s	.x
	moveq	#8,d0
	move.w	d3,d1
	mulu	#6,d1
	add.w	#21,d1
	move.w	#253,d2
	move.w	#170,d3
	moveq	#0,d4
	bsr	ms_bar
.x:	bsr	mouseshow
	movem.l	(sp)+,d3-d5
	rts

; getlog: the title and the 25 lines of the current log
c2_getlog:
	movem.l	d3-d4/a3,-(sp)
	bsr	mousehide
	move.w	#79,GS_TCOLOR(a6)
	clr.w	GS_BKCOLOR(a6)
	move.w	c2_logindex,d0		; loadlog(getlogindex(logs[logindex]))
	add.w	d0,d0
	lea	GS_LOGS(a6),a1
	move.w	0(a1,d0.w),d0
	bsr	c2_title
	move.l	a0,a3
	bsr	c2_loadlog
	lea	2(a3),a0		; printxy2(6,15,title)
	moveq	#6,d0
	moveq	#15,d1
	bsr	printxy2
	move.l	c2_l,a3
	moveq	#0,d3
.j:	move.l	a3,a0
	moveq	#6,d0
	move.w	d3,d1
	mulu	#6,d1
	add.w	#22,d1
	bsr	printxy2
	lea	50(a3),a3
	addq.w	#1,d3
	cmp.w	#25,d3
	bne.s	.j
	bsr	mouseshow
	movem.l	(sp)+,d3-d4/a3
	rts

; loadlog(record d0.w) from LOG.DTA
c2_loadlog:
	move.l	d3,-(sp)
	mulu	#LOGPAGE,d0
	move.l	d0,-(sp)
	clr.w	-(sp)
	pea	c2_fn_log
	GEMDOS	GD_FOPEN,8
	move.w	d0,d3
	bmi	fatal
	move.l	(sp)+,d0
	clr.w	-(sp)
	move.w	d3,-(sp)
	move.l	d0,-(sp)
	GEMDOS	GD_FSEEK,10
	move.l	c2_l,-(sp)
	move.l	#LOGPAGE,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FREAD,12
	cmp.l	#LOGPAGE,d0
	bne	fatal
	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
	move.l	(sp)+,d3
	rts

; ---------------------------------------------------------------
printxy2:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	a0,a5
	move.w	GS_TCOLOR(a6),d7	; t
	addq.w	#4,d0			; x1 := x1 + 4
	move.w	d0,d5
	move.w	d1,d6			; y1
	movem.w	d0-d1,-(sp)		; clear the line: rows y1+1..y1+6, x1+1 .. +245
	addq.w	#1,d0
	addq.w	#1,d1
	move.w	d0,d2
	add.w	#5*49-1,d2
	move.w	d1,d3
	addq.w	#5,d3
	move.w	GS_BKCOLOR(a6),d4
	bsr	ms_bar
	movem.w	(sp)+,d0-d1
	moveq	#0,d0			; the game font
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_FONT_-1(a6),d0
	cmp.w	#2,d0
	bls.s	.f
	moveq	#0,d0
.f:	mulu	#82*3,d0
	lea	txt_font-3,a4		; glyph 1 at offset 0
	add.w	d0,a4
	moveq	#0,d4
	move.b	(a5)+,d4		; length
	bra	.next
.char:	moveq	#0,d0
	move.b	(a5)+,d0
	move.w	d7,d2			; tcolor := t, or 31 when bright
	tst.b	c2_bright
	beq.s	.nb
	moveq	#31,d2
.nb:	cmp.b	#200,d0
	bne.s	.glyph
	not.b	c2_bright
	bra	.next
.glyph:	mulu	#3,d0
	lea	0(a4,d0.w),a3		; glyph bytes
	move.w	d5,d0
	addq.w	#1,d0
	move.w	d6,d1
	addq.w	#1,d1
	bsr	ms_addr			; a0 = (x1+1, y1+1)
	move.w	GS_BKCOLOR(a6),d3
	sub.l	a2,a2			; row 0-5
.row:	move.w	a2,d0
	lsr.w	#1,d0
	move.b	0(a3,d0.w),d0
	move.w	a2,d1
	btst	#0,d1
	bne.s	.lo
	lsr.b	#4,d0
.lo:	moveq	#4-1,d1
.px:	btst	#3,d0
	beq.s	.bg
	move.b	d2,(a0)+
	bra.s	.nx
.bg:	cmp.w	#255,d3
	bhs.s	.tr
	move.b	d3,(a0)+
	bra.s	.nx
.tr:	addq.l	#1,a0
.nx:	add.b	d0,d0
	dbf	d1,.px
	lea	MS_W-4(a0),a0
	subq.w	#2,d2			; dec(tcolor,2) per row
	addq.w	#1,a2
	cmp.w	#6,a2
	bne.s	.row
	addq.w	#5,d5			; x1 := x1 + 5; the gap column in bkcolor
	cmp.w	#255,d3
	bhs.s	.next
	move.w	d5,d0
	move.w	d6,d1
	addq.w	#1,d1
	bsr	ms_addr
	moveq	#6-1,d0
.gap:	move.b	d3,(a0)
	lea	MS_W(a0),a0
	dbf	d0,.gap
.next:	dbf	d4,.char
	move.w	d7,GS_TCOLOR(a6)
	movem.l	(sp)+,d3-d7/a3-a5
	rts

	section	data
c2_mode:	dc.b	"LOG",0
c2_fn_mod:	dc.b	"SOUND",92,"CREWEVAL.MOD",0
c2_fn_titles:	dc.b	"DATA",92,"TITLES.DTA",0
c2_fn_cur:	dc.b	"DATA",92,"LOGCUR.DAT",0
c2_fn_log:	dc.b	"DATA",92,"LOG.DTA",0
	even

	section	bss
c2_mark:	ds.l	1
c2_titles:	ds.l	1
c2_l:		ds.l	1
c2_ntitles:	ds.w	1
c2_logindex:	ds.w	1
c2_index:	ds.w	1
c2_last:	ds.w	1
c2_qmode:	ds.b	1
c2_done:	ds.b	1
c2_bright:	ds.b	1
	even
c2_tmpm:	ds.b	7*256
