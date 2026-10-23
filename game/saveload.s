; saveload.s - saveload.pas: the save-game dialog (savegamedata) and savegame. Include after the
; kernel. The dialog is drawn in a chunky window (kernel chk.s) because its cursor works by
; index arithmetic (plainfadearea +-3). The caller restores the screen under the dialog
; afterwards (the original kept a copy in tempscr; the ST redraws its scene instead).
;
; sl_savegamedata  in: d0.w alt, d1.w text (colours)  out: d0.w = 1 saved, 0 cancelled
;                  trashes: d0-d2/a0-a2
; sl_savegame      in: d0.w slot 1-8: SAVEn\SHIP.DTA, SYSTEMS.DTA, EVENTS.DTA, LOGS.DTA,
;                  PENDING.DTA, PLANETS.DTA (from tempplan, when there is one), CONTACTS.DTA
;                  (copy of TEMP\CONTACTS.DTA); sets curfilenum.  trashes: d0-d2/a0-a2
; sl_loadgame      in: d0.w slot 1-8: saveload.pas loadgame (SHIP, SYSTEMS, EVENTS or the
;                  old format's convertevents, LOGS, PENDING; loadplanetinfo: PLANETS.DTA into
;                  tempplan, CONTACTS.DTA filtered into TEMP\CONTACTS.DTA; tslice; cargo
;                  reserves). MAIN.PRG only (needs mutils.s).  trashes: d0-d2/a0-a2
; sl_path          in: d0.w slot, a1 = file name (C string)  out: a0 = "SAVEn\name"
; Files are in the 68000 layout (build/layout.i); SAVEGAME.DIR = 8 x savedirtype (26 bytes:
; name string[20], pad, yearstamp.w, monthstamp.w).

SD_NAME		equ	0
SD_YEAR		equ	22
SD_MONTH	equ	24
SD_SIZE		equ	26
SL_WX		equ	75		; the dialog's window (button 75,40 - 244,140)
SL_WY		equ	40
SL_WW		equ	170
SL_WH		equ	101

	section	text
sl_savegamedata:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,sl_alt
	move.w	d1,sl_text
	ifnd	SL_LOAD			; (MAIN.PRG: the dialog goes into its whole-screen shadow)
	lea	sl_win,a0
	move.w	#SL_WX,d0
	move.w	#SL_WY,d1
	move.w	#SL_WW,d2
	move.w	#SL_WH,d3
	bsr	chk_open
	endc
	bsr	kbd_cursor_hide
	move.w	sl_text,GS_TCOLOR(a6)
	move.w	#75,d0			; button(75,40,244,140,alt)
	moveq	#40,d1
	move.w	#244,d2
	move.w	#140,d3
	move.w	sl_alt,d4
	bsr	sl_button
	moveq	#1,d5			; for a:=1 to 8 do button(85,40+a*10,235,48+a*10,2+alt)
.b:	move.w	d5,d1
	mulu	#10,d1
	add.w	#40,d1
	move.w	d1,d3
	addq.w	#8,d3
	move.w	#85,d0
	move.w	#235,d2
	move.w	sl_alt,d4
	addq.w	#2,d4
	bsr	sl_button
	addq.w	#1,d5
	cmp.w	#8,d5
	ble.s	.b
	move.w	#185,d0			; button(185,130,225,138,2+alt)
	move.w	#130,d1
	move.w	#225,d2
	move.w	#138,d3
	move.w	sl_alt,d4
	addq.w	#2,d4
	bsr	sl_button
	move.w	sl_alt,d0		; bkcolor:=35+alt
	add.w	#35,d0
	move.w	d0,GS_BKCOLOR(a6)
	move.w	#130,d0
	moveq	#41,d1
	lea	sl_s_save,a0
	bsr	chk_print
	move.w	sl_text,d0		; tcolor:=text-5
	subq.w	#5,d0
	move.w	d0,GS_TCOLOR(a6)
.redo:	bsr	sl_loadfilenames
	bsr	sl_displayfilenames
	moveq	#SL_WY,d1
	move.w	#SL_WY+SL_WH-1,d2
	bsr	chk_show
	bsr	sl_mainloop		; choose the slot
	cmp.w	#9,d0
	beq.s	.cancel
	bsr	sl_readname		; edit its name
	tst.w	d0
	bne.s	.named
	bsr	sl_undocursor
	bra.s	.redo
.named:	bsr	kbd_cursor_show
	move.w	sl_cursor,d0
	subq.w	#1,d0
	mulu	#SD_SIZE,d0
	lea	sl_names,a0
	add.w	d0,a0
	move.w	GS_SHIP+SHIP_STARDATE+4(a6),SD_YEAR(a0)	; stardate[3]
	move.w	GS_SHIP+SHIP_STARDATE(a6),SD_MONTH(a0)	; stardate[1]
	bsr	sl_savefilenames
	move.w	sl_cursor,d0
	bsr	sl_savegame
	moveq	#1,d7
	bra.s	.out
.cancel:
	moveq	#0,d7
.out:	bsr	kbd_cursor_hide		; (the caller restores what was under the dialog)
	bsr	kbd_cursor_show
	move.w	#3,GS_BKCOLOR(a6)
	move.w	d7,d0
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; button(x1,y1,x2,y2,alt): d0-d3 corners, d4.w alt (saveload.pas)
sl_button:
	movem.l	d3-d7,-(sp)
	movem.w	d0-d3,sl_bx
	move.w	d4,d7
	add.w	#35,d4			; bar
	bsr	chk_bar
	movem.w	sl_bx,d0-d3		; line(x2,y1,x2,y2) and line(x1,y2,x2,y2) in 32+alt
	move.w	d2,d0
	move.w	d7,d4
	add.w	#32,d4
	bsr	chk_bar
	movem.w	sl_bx,d0-d3
	move.w	d3,d1
	bsr	chk_bar
	movem.w	sl_bx,d0-d3		; line(x1,y1,x2,y1) and line(x1,y1,x1,y2) in 38+alt
	move.w	d1,d3
	move.w	d7,d4
	add.w	#38,d4
	bsr	chk_bar
	movem.w	sl_bx,d0-d3
	move.w	d0,d2
	bsr	chk_bar
	move.w	d7,d2			; screen[y1,x2] and screen[y2,x1] := 36+alt
	add.w	#36,d2
	movem.w	sl_bx,d0-d1
	move.w	sl_bx+4,d0
	bsr	chk_pset
	move.w	sl_bx,d0
	move.w	sl_bx+6,d1
	bsr	chk_pset
	movem.l	(sp)+,d3-d7
	rts

sl_displayfilenames:
	movem.l	d3-d5/a3,-(sp)
	move.w	#85,d0
	move.w	#131,d1
	lea	sl_version,a0
	bsr	chk_print
	move.w	sl_alt,d0		; bkcolor:=37+calt
	add.w	#37,d0
	move.w	d0,GS_BKCOLOR(a6)
	moveq	#1,d5
.a:	move.w	d5,d0			; names^[a]
	subq.w	#1,d0
	mulu	#SD_SIZE,d0
	lea	sl_names,a3
	add.w	d0,a3
	lea	sl_s1,a0		; str(monthstamp:2) + '/' + str(yearstamp:5)
	move.w	SD_MONTH(a3),d0
	ext.l	d0
	moveq	#2,d1
	bsr	int_str
	lea	sl_s1,a0
	lea	sl_slash,a1
	bsr	pstr_cat
	lea	sl_s2,a0
	move.w	SD_YEAR(a3),d0
	ext.l	d0
	moveq	#5,d1
	bsr	int_str
	lea	sl_s1,a0
	lea	sl_s2,a1
	bsr	pstr_cat
	move.w	d5,d4
	mulu	#10,d4
	add.w	#41,d4			; y = 41 + a*10
	move.w	#85,d0
	move.w	d4,d1
	lea	SD_NAME(a3),a0
	bsr	chk_print
	move.w	#187,d0
	move.w	d4,d1
	lea	sl_s1,a0
	bsr	chk_print
	addq.w	#1,d5
	cmp.w	#8,d5
	ble	.a
	move.w	#187,d0
	move.w	#131,d1
	lea	sl_s_cancel,a0
	bsr	chk_print
	movem.l	(sp)+,d3-d5/a3
	rts

sl_loadfilenames:
	lea	sl_fn_dir,a0
	lea	sl_names,a1
	move.l	#8*SD_SIZE,d0
	bsr	fil_load
	bcs.s	.init
	cmp.l	#8*SD_SIZE,d0
	beq.s	.x
.init:	lea	sl_names,a0		; initializenames
	moveq	#8-1,d1
.n:	move.b	#20,(a0)
	moveq	#20-1,d0
	lea	1(a0),a1
.sp:	move.b	#' ',(a1)+
	dbf	d0,.sp
	clr.b	21(a0)
	move.w	#3784,SD_YEAR(a0)
	move.w	#2,SD_MONTH(a0)
	lea	SD_SIZE(a0),a0
	dbf	d1,.n
	bsr	sl_savefilenames
.x:	rts

sl_savefilenames:
	lea	sl_fn_dir,a0
	lea	sl_names,a1
	move.l	#8*SD_SIZE,d0
	bra	fil_save

; mainloop(false) (saveload.pas 405): the slot cursor by mouse and keys; d0.w = cursor (9 = cancel)
sl_mainloop:
	clr.w	sl_done
	bsr	kbd_cursor_show
	move.w	GS_CURFILENUM(a6),sl_cursor
	bsr	sl_drawcursor
	bsr	kbd_mouse_xy
	move.w	d0,sl_lastx
	move.w	d1,sl_lasty
	move.w	#320,d0			; k:=random(320) (only used by the star background)
	bsr	mt_random
	ifd	SL_LOAD
	move.w	d0,sl_k
	move.w	#1,sl_k2		; k2 := 1; mode := 0
	clr.w	sl_mode
	tst.b	sl_stars
	beq.s	.l
	bsr	fadein
	endc
.l:	bsr	sl_findmouse
	bsr	kbd_keypressed
	tst.b	d0
	beq.s	.nk
	bsr	sl_processkey
.nk:
	ifd	SL_LOAD
	tst.b	sl_stars
	beq.s	.ns
	bsr	sl_starstep
.ns:
	endc
	tst.w	sl_done
	beq.s	.l
	move.w	sl_cursor,d0
	rts

	ifd	SL_LOAD
; saveload.pas loadgamedata(tofadein d0.b): the load dialog; tofadein (MAIN started without a
; slot): over the scrolling stars (mode LOADG). out d0.w = 1 a game was loaded (then event(10),
; event(1001) after event 12, as the original)   trashes: d0-d2/a0-a2
sl_loadgamedata:
	movem.l	d3-d7/a3-a5,-(sp)
	move.b	d0,sl_stars
	clr.w	sl_alt			; calt := 0
	move.w	#26,GS_TCOLOR(a6)
	bsr	mousehide
	tst.b	sl_stars
	beq.s	.nm
	lea	sl_mode_loadg,a0	; (the ST: the band design for the stars; a black screen)
	bsr	ms_load
	bcs	fatal
.nm:	bsr	sl_keep			; tempscr := rows 40..140, x 74..245
	move.w	#75,d0			; button(75,40,244,140,0)
	moveq	#40,d1
	move.w	#244,d2
	move.w	#140,d3
	moveq	#0,d4
	bsr	sl_button
	moveq	#1,d5			; button(85,40+a*10,235,48+a*10,2)
.b:	move.w	d5,d1
	mulu	#10,d1
	add.w	#40,d1
	move.w	d1,d3
	addq.w	#8,d3
	move.w	#85,d0
	move.w	#235,d2
	moveq	#2,d4
	bsr	sl_button
	addq.w	#1,d5
	cmp.w	#8,d5
	ble.s	.b
	move.w	#185,d0			; button(185,130,225,138,2)
	move.w	#130,d1
	move.w	#225,d2
	move.w	#138,d3
	moveq	#2,d4
	bsr	sl_button
	bsr	sl_loadfilenames
	move.w	#35,GS_BKCOLOR(a6)
	move.w	#130,d0
	moveq	#41,d1
	lea	sl_s_load,a0
	bsr	chk_print
	bsr	sl_displayfilenames
	tst.b	sl_stars
	beq.s	.go
	bsr	sl_keep
	bsr	orc_dump		; loadscreen(cloud, @screen)
	lea	u2_cloud,a0
	move.l	ms_buf,a1
	bsr	loadchk
	move.l	ms_buf,a0		; backgr^ := screen
	move.l	GS_BACKGR(a6),a1
	move.l	#64000,d1
	bsr	sl_bcopy
	bsr	sl_restore
	bsr	ms_dirty_all
	bra.s	.go2
.go:	moveq	#74,d0			; (the dialog to the screen)
	moveq	#40,d1
	move.w	#245,d2
	move.w	#140,d3
	bsr	ms_dirty
.go2:	bsr	ms_flush
	bsr	sl_mainloop		; result = the slot (9 = cancel)
	move.w	d0,d3
	moveq	#0,d7
	cmp.w	#9,d3
	beq.s	.out
	move.w	d3,d0			; FileExists(SAVEn\SHIP.DTA), else a "cancel"
	lea	sl_fn_ship,a1
	bsr	sl_path
	bsr	fil_size
	bcc.s	.ld
	moveq	#9,d3
	bra.s	.out
.ld:	moveq	#1,d7
	move.w	d3,d0
	bsr	sl_loadgame
.out:	bsr	mousehide
	tst.b	sl_stars
	bne.s	.ns
	bsr	sl_restore
	moveq	#74,d0
	moveq	#40,d1
	move.w	#245,d2
	move.w	#140,d3
	bsr	ms_dirty
.ns:	bsr	mouseshow
	move.w	#3,GS_BKCOLOR(a6)
	tst.w	d7
	beq.s	.x
	moveq	#10,d0			; event(10); if chevent(12) then event(1001)
	bsr	event
	moveq	#12,d0
	bsr	chevent
	tst.w	d0
	beq.s	.x
	move.w	#1001,d0
	bsr	event
.x:	move.w	d7,d0
	sf	sl_stars
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; tempscr := screen rows 40..140, x 74..245 (sl_keep) and back (sl_restore)
sl_keep:
	moveq	#0,d2
	bra.s	sl_kr
sl_restore:
	moveq	#1,d2
sl_kr:	move.l	ms_buf,a0
	lea	40*320+74(a0),a0
	lea	sl_tmp,a1
	tst.w	d2
	beq.s	.k
	exg	a0,a1
.k:	moveq	#101-1,d1
.r:	moveq	#43-1,d0
.c:	move.b	(a0)+,(a1)+		; (74 is even, but keep it simple: 172 bytes)
	move.b	(a0)+,(a1)+
	move.b	(a0)+,(a1)+
	move.b	(a0)+,(a1)+
	dbf	d0,.c
	tst.w	d2
	beq.s	.k2
	lea	320-172(a1),a1
	bra.s	.n
.k2:	lea	320-172(a0),a0
.n:	dbf	d1,.r
	rts

; a0 -> a1, d1.l bytes (longs when both have the same parity)
sl_bcopy:
	tst.l	d1
	beq.s	.x
	move.l	a0,d0
	move.l	a1,d2
	eor.w	d2,d0
	btst	#0,d0
	bne.s	.b
	move.l	a0,d0
	btst	#0,d0
	beq.s	.al
	move.b	(a0)+,(a1)+
	subq.l	#1,d1
.al:	move.l	d1,d0
	lsr.l	#4,d0			; 16 bytes a step
	bra.s	.le
.l:	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
.le:	subq.l	#1,d0
	bpl.s	.l
	and.w	#15,d1
	bra.s	.re
.r:	move.b	(a0)+,(a1)+
.re:	dbf	d1,.r
.x:	rts
.b:	subq.l	#1,d1			; different parity: bytes
.bl:	move.b	(a0)+,(a1)+
	subq.l	#1,d1
	bpl.s	.bl
	rts

; one step of mainloop(true)'s stars: k moves one pixel in one of 8 directions (a new one every
; 15 steps); the screen := backgr rotated by k with the dialog over it; delay(tslice*2)
sl_starstep:
	subq.w	#1,sl_k2
	bne.s	.m
	move.w	#15,sl_k2
	move.w	sl_mode,d0
	addq.w	#1,d0
	and.w	#7,d0
	move.w	d0,sl_mode
	add.w	d0,d0
	lea	.k3,a0
	move.w	0(a0,d0.w),sl_k3
.m:	move.w	sl_k,d0			; k := k + k3 (a word)
	add.w	sl_k3,d0
	cmp.w	#65000,d0
	bls.s	.a
	add.w	#64000,d0
	bra.s	.b
.a:	cmp.w	#64000,d0
	bls.s	.b
	sub.w	#64000,d0
.b:	move.w	d0,sl_k
	bsr	mousehide		; tempscr := the dialog (with its cursor)
	bsr	sl_keep
	bsr	mouseshow
	move.l	GS_BACKGR(a6),a0	; s[k..] := backgr[0..63999-k]
	moveq	#0,d0
	move.w	sl_k,d0
	move.l	ms_buf,a1
	add.l	d0,a1
	move.l	#64000,d1
	sub.l	d0,d1
	bsr	sl_bcopy
	move.l	GS_BACKGR(a6),a0	; s[0..k-1] := backgr[64000-k..]
	add.l	#64000,a0
	moveq	#0,d1
	move.w	sl_k,d1
	sub.l	d1,a0
	move.l	ms_buf,a1
	bsr	sl_bcopy
	bsr	sl_restore
	bsr	mousehide		; screen := s
	bsr	ms_dirty_all
	bsr	mouseshow
	move.w	GS_TSLICE(a6),d0	; delay(b), b = tslice*2
	add.w	d0,d0
	bra	delay
.k3:	dc.w	-320,-319,1,321,320,319,-1,-321
	endc

sl_undocursor:
	moveq	#-3,d4
	bra.s	sl_fadecursor
sl_drawcursor:
	moveq	#3,d4
sl_fadecursor:
	movem.l	d3-d4,-(sp)
	tst.w	sl_cursor
	beq.s	.x
	bsr	kbd_cursor_hide
	move.w	sl_cursor,d0
	cmp.w	#9,d0
	beq.s	.c
	mulu	#10,d0			; plainfadearea(85,40+cursor*10,235,47+cursor*10,alt)
	add.w	#40,d0
	move.w	d0,d1
	move.w	d0,d3
	addq.w	#7,d3
	move.w	#85,d0
	move.w	#235,d2
	bra.s	.f
.c:	move.w	#185,d0			; plainfadearea(185,130,225,138,alt)
	move.w	#130,d1
	move.w	#225,d2
	move.w	#138,d3
.f:	move.w	d3,-(sp)
	move.w	d1,-(sp)
	bsr	chk_fade
	move.w	(sp)+,d1
	move.w	(sp)+,d2
	bsr	chk_show
	bsr	kbd_cursor_show
.x:	movem.l	(sp)+,d3-d4
	rts

sl_processkey:
	bsr	sl_undocursor
	bsr	kbd_readkey
	tst.b	d0
	bne.s	.asc
	bsr	kbd_readkey
	cmp.b	#72,d0
	bne.s	.dn
	move.w	sl_cursor,d0		; up
	bne.s	.u1
	move.w	#1,sl_cursor
	bra	.done
.u1:	cmp.w	#1,d0
	ble.s	.u9
	subq.w	#1,sl_cursor
	bra	.done
.u9:	move.w	#9,sl_cursor
	bra	.done
.dn:	cmp.b	#80,d0
	bne.s	.done
	cmp.w	#9,sl_cursor
	bge.s	.d1
	addq.w	#1,sl_cursor
	bra.s	.done
.d1:	move.w	#1,sl_cursor
	bra.s	.done
.asc:	cmp.b	#'1',d0
	blo.s	.nd
	cmp.b	#'8',d0
	bhi.s	.nd
	sub.b	#'0',d0
	ext.w	d0
	move.w	d0,sl_cursor
	bra.s	.done
.nd:	cmp.b	#'C',d0
	beq.s	.c9
	cmp.b	#'c',d0
	bne.s	.cr
.c9:	move.w	#9,sl_cursor
	bra.s	.done
.cr:	cmp.b	#13,d0
	bne.s	.es
	tst.w	sl_cursor
	beq.s	.done
	move.w	#1,sl_done
	bra.s	.done
.es:	cmp.b	#27,d0
	bne.s	.done
	move.w	#9,sl_cursor
	move.w	#1,sl_done
.done:	bsr	sl_drawcursor
	bsr	kbd_mouse_xy
	move.w	d0,sl_lastx
	move.w	d1,sl_lasty
	rts

sl_findmouse:
	movem.l	d3-d5,-(sp)
	bsr	kbd_mouse_status
	moveq	#0,d5			; button
	tst.b	d0
	beq.s	.nb
	moveq	#1,d5
.nb:	bsr	kbd_mouse_xy
	move.w	d0,d3			; x
	move.w	d1,d4			; y
	; if (not button) and (mouse.x=lastx) or (mouse.y=lasty) then exit
	cmp.w	sl_lasty,d4
	beq	.x
	tst.w	d5
	bne.s	.go
	cmp.w	sl_lastx,d3
	beq	.x
.go:	moveq	#0,d0			; newcursor
	cmp.w	#130,d4
	blo.s	.rows
	cmp.w	#138,d4
	bhi.s	.set
	cmp.w	#184,d3
	bls.s	.set
	cmp.w	#226,d3
	bhs.s	.set
	moveq	#9,d0
	bra.s	.set
.rows:	cmp.w	#50,d4
	blo.s	.set
	move.w	d4,d1
	sub.w	#50,d1			; 50..58 -> 1, 60..68 -> 2, ... 120..128 -> 8
	ext.l	d1
	divu	#10,d1
	swap	d1
	cmp.w	#8,d1			; 9 = the gap row (59, 69, ...)
	beq.s	.set
	swap	d1
	cmp.w	#84,d3
	bls.s	.set
	cmp.w	#236,d3
	bhs.s	.set
	move.w	d1,d0
	addq.w	#1,d0
.set:	cmp.w	sl_cursor,d0
	beq.s	.same
	move.w	d0,-(sp)
	bsr	sl_undocursor
	move.w	(sp)+,sl_cursor
	bsr	sl_drawcursor
.same:	tst.w	sl_cursor
	beq.s	.x
	tst.w	d5
	beq.s	.x
	move.w	#1,sl_done
.x:	movem.l	(sp)+,d3-d5
	rts

; readname (saveload.pas 553): edit names^[cursor].name in place. d0.w = 1 Return, 0 Esc
sl_readname:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	sl_cursor,d0
	subq.w	#1,d0
	mulu	#SD_SIZE,d0
	lea	sl_names,a3
	add.w	d0,a3			; a3 = name (Pascal string[20])
	moveq	#20,d6			; namecur
.w:	cmp.b	#' ',0(a3,d6.w)
	bne.s	.w1
	subq.w	#1,d6
	bra.s	.w
.w1:	cmp.w	#20,d6
	bge.s	.w2
	addq.w	#1,d6
.w2:	moveq	#0,d7			; done
	bsr	kbd_cursor_hide
	moveq	#' ',d5			; ans
.loop:	move.w	sl_cursor,d4
	mulu	#10,d4
	add.w	#41,d4			; y
	move.w	sl_alt,d0		; bkcolor:=40+calt
	add.w	#40,d0
	move.w	d0,GS_BKCOLOR(a6)
	move.w	#85,d0
	move.w	d4,d1
	move.l	a3,a0
	bsr	chk_print
	move.w	#82,GS_BKCOLOR(a6)	; the character at the cursor on blue
	move.b	#1,sl_ch
	move.b	0(a3,d6.w),sl_ch+1
	move.w	d6,d0
	mulu	#5,d0
	add.w	#80,d0
	move.w	d4,d1
	lea	sl_ch,a0
	bsr	chk_print
	move.w	d4,d1
	move.w	d4,d2
	addq.w	#7,d2
	bsr	chk_show
	move.w	GS_TSLICE(a6),d0	; delay(tslice*2)
	add.w	d0,d0
	bsr	tim_delay
	bsr	kbd_keypressed
	tst.b	d0
	beq	.until
	bsr	kbd_readkey
	move.b	d0,d5			; ans
	move.b	d0,d1			; upcase(ans)
	cmp.b	#'a',d1
	blo.s	.uc
	cmp.b	#'z',d1
	bhi.s	.uc
	sub.b	#32,d1
.uc:	tst.b	d1
	bne.s	.nz
	bsr	kbd_readkey		; extended
	cmp.b	#77,d0
	bne.s	.left
	cmp.w	#20,d6
	bge	.until
	addq.w	#1,d6
	bra	.until
.left:	cmp.b	#75,d0
	bne.s	.del
	cmp.w	#1,d6
	ble	.until
	subq.w	#1,d6
	bra	.until
.del:	cmp.b	#83,d0
	bne	.until
	bsr	.remove
	bra	.until
.nz:	cmp.b	#8,d1
	bne.s	.prt
	cmp.w	#1,d6
	ble.s	.bs
	subq.w	#1,d6
.bs:	bsr	.remove
	bra.s	.until
.prt:	cmp.b	#' ',d1			; ' '..'"', ''''..'?', 'A'..'Z', '%'
	blo.s	.esc
	cmp.b	#'"',d1
	bls.s	.ins
	cmp.b	#'%',d1
	beq.s	.ins
	cmp.b	#$27,d1
	blo.s	.esc
	cmp.b	#'?',d1
	bls.s	.ins
	cmp.b	#'A',d1
	blo.s	.esc
	cmp.b	#'Z',d1
	bhi.s	.esc
.ins:	moveq	#20,d0			; for j:=20 downto namecur+1 do name[j]:=name[j-1]
.i:	cmp.w	d6,d0
	ble.s	.i1
	move.b	-1(a3,d0.w),0(a3,d0.w)
	subq.w	#1,d0
	bra.s	.i
.i1:	move.b	d5,0(a3,d6.w)
	cmp.w	#20,d6
	bge.s	.until
	addq.w	#1,d6
	bra.s	.until
.esc:	cmp.b	#27,d1
	bne.s	.until
	moveq	#1,d7
.until:	cmp.b	#13,d5
	beq.s	.end
	tst.w	d7
	beq	.loop
.end:	moveq	#1,d0
	tst.w	d7
	beq.s	.r
	moveq	#0,d0
.r:	move.w	#40,GS_BKCOLOR(a6)
	movem.l	(sp)+,d3-d7/a3-a5
	rts
.remove:				; for j:=namecur to 19 do name[j]:=name[j+1]; name[20]:=' '
	move.w	d6,d0
.r1:	cmp.w	#19,d0
	bgt.s	.r2
	move.b	1(a3,d0.w),0(a3,d0.w)
	addq.w	#1,d0
	bra.s	.r1
.r2:	move.b	#' ',20(a3)
	rts

; ---------------------------------------------------------------
sl_path:
	lea	sl_pathbuf,a0
	move.l	a0,-(sp)
	move.b	#'S',(a0)+
	move.b	#'A',(a0)+
	move.b	#'V',(a0)+
	move.b	#'E',(a0)+
	add.b	#'0',d0
	move.b	d0,(a0)+
	move.b	#92,(a0)+
.c:	move.b	(a1)+,(a0)+
	bne.s	.c
	move.l	(sp)+,a0
	rts

; d0.w slot, a1 = file name, a2 = data, d1.l = bytes
sl_write:
	movem.l	d1/a2,-(sp)
	bsr.s	sl_path
	movem.l	(sp)+,d0/a1
	bra	fil_save

sl_savegame:
	movem.l	d3/a3,-(sp)
	move.w	d0,d3
	lea	sl_pathbuf,a0		; mkdir SAVEn (an existing folder is fine)
	move.l	#'SAVE',(a0)
	add.b	#'0',d0
	move.b	d0,4(a0)
	clr.b	5(a0)
	bsr	fil_mkdir
	lea	sl_files,a3
.f:	move.w	(a3)+,d0		; GS offset, -1 ends
	bmi.s	.pl
	lea	0(a6,d0.w),a2
	moveq	#0,d1
	move.w	(a3)+,d1
	move.l	a3,a1
.n:	tst.b	(a3)+
	bne.s	.n
	move.l	a3,d0
	addq.l	#1,d0
	and.w	#$fffe,d0
	move.l	d0,a3
	move.w	d3,d0
	bsr	sl_write
	bra.s	.f
.pl:	move.w	d3,GS_CURFILENUM(a6)
	move.l	GS_TEMPPLAN(a6),d0	; saveplanetinfo
	beq.s	.con
	move.l	d0,a2
	move.l	#PLANARRAY_SIZEOF,d1
	move.w	d3,d0
	lea	sl_fn_planets,a1
	bsr	sl_write
.con:	bsr	mem_mark		; CONTACTS.DTA := copy of TEMP\CONTACTS.DTA
	move.l	d0,-(sp)
	lea	sl_fn_tmpcon,a0
	bsr	fil_size
	bcs.s	.empty
	move.l	d0,d1
	beq.s	.empty
	move.l	d1,-(sp)
	move.l	d1,d0
	bsr	mem_alloc
	move.l	(sp)+,d1
	bcs.s	.empty
	move.l	a0,a3
	move.l	d1,-(sp)
	lea	sl_fn_tmpcon,a0
	move.l	a3,a1
	move.l	d1,d0
	bsr	fil_load
	move.l	(sp)+,d1
	bcs.s	.empty
	move.l	a3,a2
	bra.s	.wc
.empty:	moveq	#0,d1
	lea	sl_names,a2
.wc:	move.w	d3,d0
	lea	sl_fn_contacts,a1
	bsr	sl_write
	move.l	(sp)+,d0
	bsr	mem_release
	movem.l	(sp)+,d3/a3
	rts

	ifd	SL_LOAD			; MAIN.PRG only
; ---------------------------------------------------------------
sl_read:				; d0.w slot, a1 = name, a2 = buffer, d1.l = bytes; fatal if short
	movem.l	d1/a2,-(sp)
	bsr	sl_path
	movem.l	(sp)+,d0/a1
	move.l	d0,-(sp)
	bsr	fil_load
	bcs.s	.e
	cmp.l	(sp)+,d0
	bne	fatal
	and.b	#$fe,ccr
	rts
.e:	addq.l	#4,sp
	or.b	#1,ccr
	rts

sl_loadgame:
	movem.l	d3-d5/a3,-(sp)
	move.w	d0,d3
	lea	sl_fn_ship,a1
	lea	GS_SHIP(a6),a2
	move.l	#SHIP_SIZEOF,d1
	bsr	sl_read
	bcs	fatal
	move.w	d3,d0
	lea	sl_fn_systems,a1
	lea	GS_SYSTEMS(a6),a2
	move.l	#SYSTEMARRAY_SIZEOF,d1
	bsr	sl_read
	bcs	fatal
	move.w	d3,d0
	lea	sl_fn_events,a1
	lea	GS_EVENTS(a6),a2
	move.l	#EVENTARRAY_SIZEOF,d1
	bsr	sl_read
	bcc.s	.new
	bsr	sl_convertevents
	bra.s	.pl
.new:	move.w	d3,d0
	lea	sl_fn_logs,a1
	lea	GS_LOGS(a6),a2
	move.l	#LOGARRAY_SIZEOF,d1
	bsr	sl_read
	bcs	fatal
	move.w	d3,d0
	lea	sl_fn_pending,a1
	lea	GS_LOGPENDING(a6),a2
	move.l	#LOGPENDINGARRAY_SIZEOF,d1
	bsr	sl_read
	bcs	fatal
.pl:	move.w	d3,GS_CURFILENUM(a6)
	; loadplanetinfo
	move.w	d3,d0
	lea	sl_fn_planets,a1
	move.l	GS_TEMPPLAN(a6),a2
	move.l	#PLANARRAY_SIZEOF,d1
	bsr	sl_read
	bcs	fatal
	lea	sl_fn_tempdir,a0
	bsr	fil_mkdir
	bsr	mem_mark
	move.l	d0,-(sp)
	move.w	d3,d0
	lea	sl_fn_contacts,a1
	bsr	sl_path
	bsr	fil_size
	bcs	fatal
	move.l	d0,d4
	addq.l	#2,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,a3
	move.w	d3,d0
	lea	sl_fn_contacts,a1
	bsr	sl_path
	move.l	a3,a1
	move.l	d4,d0
	bsr	fil_load
	bcs	fatal
	move.l	a3,a0			; keep id > 1000 or planets with notes bit 1
	move.l	a3,a1
	divu	#ALIEN_SIZEOF,d4
	moveq	#0,d5			; bytes kept
	bra.s	.cn
.cl:	move.w	ALIEN_ID(a0),d0
	cmp.w	#1000,d0
	bgt.s	.keep
	subq.w	#1,d0
	mulu	#PLANET_SIZEOF,d0
	move.l	GS_TEMPPLAN(a6),a2
	btst	#1,PLANET_NOTES(a2,d0.l)
	beq.s	.skip
.keep:	moveq	#ALIEN_SIZEOF/2-1,d0
.cp:	move.w	(a0)+,(a1)+
	dbf	d0,.cp
	add.w	#ALIEN_SIZEOF,d5
	bra.s	.cn
.skip:	lea	ALIEN_SIZEOF(a0),a0
.cn:	dbf	d4,.cl
	lea	sl_fn_tmpcon,a0
	move.l	a3,a1
	moveq	#0,d0
	move.w	d5,d0
	bsr	fil_save
	move.l	(sp)+,d0
	bsr	mem_release
	moveq	#0,d0			; tslice := ship.options[OPT_TIMESLICE]
	move.b	GS_SHIP+SHIP_OPTIONS+1(a6),d0
	move.w	d0,GS_TSLICE(a6)
	bsr	rebuildcargoreserve
	bsr	resetcrew
	movem.l	(sp)+,d3-d5/a3
	rts

; saveload.pas convertevents: a save from before EVENTS.DTA existed
sl_convertevents:
	lea	GS_EVENTS(a6),a0
	move.w	#1024/4-1,d0
.e:	clr.l	(a0)+
	dbf	d0,.e
	lea	GS_LOGPENDING+LOGPENDING_LOG(a6),a0
	moveq	#128-1,d0
.p:	move.w	#-1,(a0)
	addq.l	#4,a0
	dbf	d0,.p
	lea	GS_LOGS(a6),a0
	move.w	#256-1,d0
.l:	move.w	#-1,(a0)+
	dbf	d0,.l
	lea	GS_SHIP+SHIP_EVENTS(a6),a1
	lea	GS_LOGS(a6),a2
	moveq	#50-1,d1
.o:	moveq	#0,d0
	move.b	(a1)+,d0
	cmp.w	#50,d0
	bhi.s	.on
	move.w	d0,(a2)+
	move.w	d0,d2
	lsr.w	#3,d2
	and.w	#7,d0
	lea	GS_EVENTS(a6),a0
	bset	d0,0(a0,d2.w)
.on:	dbf	d1,.o
	move.w	#50,d1			; i = 50 .. 50+14*8
.b:	move.w	d1,d0
	sub.w	#50,d0
	move.w	d0,d2
	lsr.w	#3,d2
	and.w	#7,d0
	lea	GS_SHIP+SHIP_EVENTS+50(a6),a0
	btst	d0,0(a0,d2.w)
	beq.s	.bn
	move.w	d1,d2
	lsr.w	#3,d2
	moveq	#7,d0
	and.w	d1,d0
	lea	GS_EVENTS(a6),a0
	bset	d0,0(a0,d2.w)
.bn:	addq.w	#1,d1
	cmp.w	#50+14*8,d1
	ble.s	.b
	rts

	section	data
sl_fn_ship:	dc.b	"SHIP.DTA",0
sl_fn_systems:	dc.b	"SYSTEMS.DTA",0
sl_fn_events:	dc.b	"EVENTS.DTA",0
sl_fn_logs:	dc.b	"LOGS.DTA",0
sl_fn_pending:	dc.b	"PENDING.DTA",0
sl_fn_tempdir:	dc.b	"TEMP",0
	even
	endif

	section	data
sl_s_save:	dc.b	9,"Save Game"
sl_s_load:	dc.b	9,"Load Game"
sl_mode_loadg:	dc.b	"LOADG",0
sl_s_cancel:	dc.b	6,"Cancel"
sl_slash:	dc.b	1,"/"
sl_version:	dc.b	20,"v1.30.0001 STE 0.4  "
sl_fn_dir:	dc.b	"SAVEGAME.DIR",0
sl_fn_planets:	dc.b	"PLANETS.DTA",0
sl_fn_contacts:	dc.b	"CONTACTS.DTA",0
sl_fn_tmpcon:	dc.b	"TEMP",92,"CONTACTS.DTA",0
	even
sl_files:	dc.w	GS_SHIP,SHIP_SIZEOF
		dc.b	"SHIP.DTA",0
		even
		dc.w	GS_SYSTEMS,SYSTEMARRAY_SIZEOF
		dc.b	"SYSTEMS.DTA",0
		even
		dc.w	GS_EVENTS,EVENTARRAY_SIZEOF
		dc.b	"EVENTS.DTA",0
		even
		dc.w	GS_LOGS,LOGARRAY_SIZEOF
		dc.b	"LOGS.DTA",0
		even
		dc.w	GS_LOGPENDING,LOGPENDINGARRAY_SIZEOF
		dc.b	"PENDING.DTA",0
		even
		dc.w	-1

	section	bss
sl_alt:		ds.w	1
sl_k:		ds.w	1
sl_k2:		ds.w	1
sl_k3:		ds.w	1
sl_mode:	ds.w	1
sl_stars:	ds.b	1
	even
sl_text:	ds.w	1
sl_cursor:	ds.w	1
sl_done:	ds.w	1
sl_lastx:	ds.w	1
sl_lasty:	ds.w	1
sl_bx:		ds.w	4
sl_names:	ds.b	8*SD_SIZE
sl_s1:		ds.b	24
sl_s2:		ds.b	24
sl_ch:		ds.b	2
sl_pathbuf:	ds.b	32
	even
sl_win:		ds.b	SL_WW*SL_WH
	ifd	SL_LOAD
sl_tmp:		ds.b	101*172
	endc
	even
