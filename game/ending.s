; ending.s - ending.pas endgame for MAIN.PRG: the scavenger armada's end (weird.s) and "/killseed".
; end1-end4: picture (mode ENDnA), fadein, wait(3), halffading (colours 16-255 to half), the
; text design ENDnB switched in, bigprintxy story text, a key, fading. The end5-over-end6 scroll
; (scrollend5: ENDS bands, whole planar rows from ENDSCR.DAT), end5's text (END5B), the credits
; (writestr2 on black: mode CRED, dothefade) and intro2 (INTRO2E) until a key or click; halt(3).
; Data: tools/mkending.py. The texts below are ending.pas's.
;
; endgame   does not return (sys_exit 3)

	section	text
endgame:
	sf	ms_mon			; (Phase 6k: the flush without its mirror - the ending writes the planar screen itself)
	move.w	#30,GS_TSLICE(a6)	; tslice := 30; tcolor := 15; bkcolor := 255
	move.w	#15,GS_TCOLOR(a6)
	move.w	#255,GS_BKCOLOR(a6)
	bsr	fading
	bsr	mousehidep
	bsr	eg_clear		; scr_fillchar(screen, 0)
	lea	eg_mod_dim,a0		; playmod(true, DIMENSIO.MOD)
	bsr	playmod
	lea	eg_text1,a3
	moveq	#1,d3
.s:	move.w	d3,d0			; end1-end4
	move.l	a3,a0
	bsr	eg_scene
	move.l	a0,a3			; (the next scene's text follows)
	addq.w	#1,d3
	cmp.w	#4,d3
	ble.s	.s
	lea	eg_mod_love,a0		; playmod(false, LOVE.MOD)
	moveq	#1,d0			; once (d0 was whatever eg_scene left - reglint)
	bsr	playmod1
	bsr	eg_scrollend5
	move.w	#3000,d0		; wait(3)
	bsr	delay
	bsr	eg_halffading
	lea	eg_m_5b,a0
	bsr	eg_setmode
	move.l	a3,a0
	bsr	eg_texts
	bsr	eg_waitkey
	bsr	fading
	bsr	eg_credits
	bsr	stopmod
	moveq	#3,d0			; closegraph; halt(3)
	bra	sys_exit

; one of end1-end4: d0.w = n, a0 = its texts  out: a0 = after them
eg_scene:
	movem.l	d3/a3,-(sp)
	move.w	d0,d3
	move.l	a0,a3
	bsr	orc_dump		; loadscreen(endN, @screen)
	lea	eg_m_a,a0		; "ENDnA"
	move.b	d3,3(a0)
	add.b	#'0',3(a0)
	bsr	ms_load
	bcs	fatal
	bsr	fadein
	move.w	#3000,d0		; wait(3)
	bsr	delay
	bsr	eg_halffading
	lea	eg_m_b,a0		; (the ST: the text's band design)
	move.b	d3,3(a0)
	add.b	#'0',3(a0)
	bsr	eg_setmode
	move.l	a3,a0
	bsr	eg_texts
	move.l	a0,a3
	bsr	eg_waitkey
	bsr	fading
	move.l	a3,a0
	movem.l	(sp)+,d3/a3
	rts

; bigprintxy(0, y, s) for a list: words y then the Pascal string (even), y = -1 ends
; in: a0   out: a0 = after the list
eg_texts:
	move.l	a3,-(sp)
	move.l	a0,a3
.l:	move.w	(a3)+,d1
	bmi.s	.x
	moveq	#0,d0
	move.l	a3,a0
	moveq	#0,d2
	move.b	(a3),d2
	lea	2(a3,d2.w),a3		; (length byte + text, even)
	move.l	a3,d2
	and.w	#$fffe,d2
	move.l	d2,a3
	bsr	eg_bigprintxy
	bra.s	.l
.x:	move.l	a3,a0
	move.l	(sp)+,a3
	rts

; while fastkeypressed do readkey; while not fastkeypressed do delay(1)
eg_waitkey:
.f:	bsr	kbd_keypressed
	tst.b	d0
	beq.s	.w
	bsr	kbd_readkey
	bra.s	.f
.w:	moveq	#1,d0
	bsr	delay
	bsr	kbd_keypressed
	tst.b	d0
	beq.s	.w
	rts

; screen := 0
eg_clear:
	move.l	ms_buf,a0
	move.w	#64000/16-1,d0
.c:	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	dbf	d0,.c
	bra	ms_dirty_all

; ending.pas bigprintxy(x1 d0, y1 d1, a0 = s): 8x7 big font, row i in tcolor-i, each set pixel's
; right neighbour in (tcolor-i) shr 1 (drawn before the next pixel)
eg_bigprintxy:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	a0,a5
	move.w	d0,d6			; x1
	move.w	d1,d7			; y1
	moveq	#0,d0			; the dirty box: rows y1+1..y1+7, x1+1..x1+8*len+1
	move.b	(a5),d0
	lsl.w	#3,d0
	add.w	d6,d0
	addq.w	#1,d0
	cmp.w	#319,d0
	ble.s	.c
	move.w	#319,d0
.c:	move.w	d0,-(sp)
	moveq	#0,d5
	move.b	(a5)+,d5		; length
	bra	.ne
.ch:	moveq	#0,d0			; letter
	move.b	(a5)+,d0
	bsr	txt_letter
	subq.w	#1,d0
	lsl.w	#3,d0
	lea	eg_bigfont,a4
	add.w	d0,a4			; bigfont[letter]
	move.w	d7,d0			; a2 = screen[y1+1, x1+1]
	addq.w	#1,d0
	mulu	#320,d0
	move.l	ms_buf,a2
	add.l	d0,a2
	add.w	d6,a2
	addq.l	#1,a2
	move.w	GS_TCOLOR(a6),d4	; t
	moveq	#0,d3			; i
.row:	move.l	a2,a0
	move.b	0(a4,d3.w),d0		; the row's bits, a = 7 downto 0
	move.w	d4,d1
	lsr.w	#1,d1
	move.b	d1,eg_t2		; tcolor shr 1
	move.w	d6,d2			; x
	addq.w	#1,d2
	moveq	#8-1,d1
.px:	add.b	d0,d0
	bcc.s	.n
	move.b	d4,(a0)
	cmp.w	#319,d2			; if x+1 < 320 then screen[y, x+1] := tcolor shr 1
	bge.s	.n
	move.b	eg_t2,1(a0)
.n:	addq.l	#1,a0
	addq.w	#1,d2
	dbf	d1,.px
	lea	320(a2),a2
	subq.w	#1,d4			; dec(tcolor)
	addq.w	#1,d3
	cmp.w	#7,d3
	bne.s	.row
	addq.w	#8,d6			; x1 := x1 + 8
.ne:	dbf	d5,.ch
	move.w	(sp)+,d2
	move.w	d7,d1
	addq.w	#1,d1
	move.w	d7,d3
	addq.w	#7,d3
	moveq	#0,d0			; (from x 0: the texts all start at x1 = 0)
	bsr	ms_dirty
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; halffading: 32 steps, colours 16-255 := round(a*colors/64) for a = 63 downto 32, each shown
; (set256colors) with delay(tslice shr 2); then colors := that palette
eg_halffading:
	movem.l	d3-d5/a3,-(sp)
	lea	eg_pal,a0		; temppal := colors
	lea	GS_COLORS(a6),a1
	move.w	#768-1,d0
.cp:	move.b	(a1)+,(a0)+
	dbf	d0,.cp
	moveq	#63,d3			; a
.a:	lea	GS_COLORS+48(a6),a0
	lea	eg_pal+48,a1
	move.w	#768-48-1,d4
.j:	moveq	#0,d0
	move.b	(a0)+,d0
	mulu	d3,d0
	moveq	#64,d1
	bsr	eg_round
	move.b	d0,(a1)+
	dbf	d4,.j
	lea	eg_pal,a0
	bsr	set256colors
	move.w	GS_TSLICE(a6),d0
	lsr.w	#2,d0
	bsr	delay
	subq.w	#1,d3
	cmp.w	#32,d3
	bge.s	.a
	lea	eg_pal,a0		; colors := temppal
	lea	GS_COLORS(a6),a1
	move.w	#768-1,d0
.bk:	move.b	(a0)+,(a1)+
	dbf	d0,.bk
	movem.l	(sp)+,d3-d5/a3
	rts

; round(d0.l / d1.w) with FPC's banker's rounding, d1 a power of two, d0 >= 0  out: d0.w
eg_round:
	move.l	d0,d2
	divu	d1,d2			; (small values: no overflow)
	move.l	d2,d0
	swap	d0			; remainder
	add.w	d0,d0
	cmp.w	d1,d0
	blo.s	.dn			; < .5
	bhi.s	.up
	btst	#0,d2			; = .5: to the even one
	beq.s	.dn
.up:	addq.w	#1,d2
.dn:	moveq	#0,d0
	move.w	d2,d0
	rts

; a band design without touching the shadow or colors: NAME.ISP's bands, LUTs, reps and planar
; picture; then the bands take colors (vid_set256)  in: a0 = name
eg_setmode:
	movem.l	d3/a3,-(sp)
	lea	ms_path+5,a1		; "DATA\" + name + ".ISP"
.cp:	move.b	(a0)+,(a1)+
	bne.s	.cp
	move.b	#'.',-1(a1)
	move.b	#'I',(a1)+
	move.b	#'S',(a1)+
	move.b	#'P',(a1)+
	clr.b	(a1)
	bsr	mem_mark
	move.l	d0,d3
	move.l	#ISP_DATA+64+32000,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,a3
	move.l	a0,a1
	lea	ms_path,a0
	move.l	#ISP_DATA+64+32000,d0
	bsr	fil_load
	bcs	fatal
	bsr	kbd_cursor_hide
	move.l	a3,a0
	move.l	vid_phys,a1
	bsr	pic_show
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	move.l	d3,d0
	bsr	mem_release
	movem.l	(sp)+,d3/a3
	rts

; ending.pas scrollend5: end6 (backgr) on screen, end5 (t) slides down over it, one row per
; delay(tslice shr 2). The ST copies whole planar rows of both pictures, pre-converted through
; each band's LUT (ENDSCR.DAT); the shadow is end5 afterwards.
eg_scrollend5:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	mem_mark
	move.l	d0,-(sp)
	bsr	orc_dump		; loadscreen(end6, backgr)
	lea	eg_c_end6,a0
	move.l	GS_BACKGR(a6),a1
	bsr	loadchk
	move.l	GS_BACKGR(a6),a0	; scrto_move(backgr^, screen)
	move.l	ms_buf,a1
	move.w	#64000/4-1,d0
.cs:	move.l	(a0)+,(a1)+
	dbf	d0,.cs
	move.l	#64000,d0		; new(t); loadscreen(end5, t)
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,a5
	bsr	orc_dump
	lea	eg_c_end5,a0
	move.l	a5,a1
	bsr	loadchk
	move.l	#8*32000,d0		; the planar rows
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,a4
	move.l	a0,a1
	lea	eg_fn_scr,a0
	move.l	#8*32000,d0
	bsr	load_exact
	lea	eg_m_s,a0		; the scroll's bands; planar = end6
	bsr	eg_setmode
	bsr	ms_clean
	bsr	eg_lines		; the band of each line (ENDS's split lines: eg_splits)
	bsr	fadein
	moveq	#0,d7			; rows of end5 shown (k2 div 320)
.k:	addq.w	#1,d7
	move.l	vid_phys,a1
	moveq	#0,d6			; y
	lea	eg_lband,a3
.y:	moveq	#0,d0
	move.b	(a3)+,d0		; band
	mulu	#64000,d0
	lea	0(a4,d0.l),a0		; [band][end5]
	move.w	d6,d1
	cmp.w	d7,d1
	bge.s	.e6
	add.w	#200,d1			; end5 row 200-r+y
	sub.w	d7,d1
	bra.s	.row
.e6:	lea	32000(a0),a0		; end6 row y-r
	sub.w	d7,d1
.row:	mulu	#160,d1
	add.l	d1,a0
	movem.l	(a0)+,d0-d5/a2/a5	; 160 bytes = 5 x 32
	movem.l	d0-d5/a2/a5,(a1)
	movem.l	(a0)+,d0-d5/a2/a5
	movem.l	d0-d5/a2/a5,32(a1)
	movem.l	(a0)+,d0-d5/a2/a5
	movem.l	d0-d5/a2/a5,64(a1)
	movem.l	(a0)+,d0-d5/a2/a5
	movem.l	d0-d5/a2/a5,96(a1)
	movem.l	(a0)+,d0-d5/a2/a5
	movem.l	d0-d5/a2/a5,128(a1)
	lea	160(a1),a1
	addq.w	#1,d6
	cmp.w	#200,d6
	blt.s	.y
	move.w	GS_TSLICE(a6),d0	; delay(b), b = tslice shr 2
	lsr.w	#2,d0
	bsr	delay
	cmp.w	#200,d7
	blt	.k
	bsr	eg_end5			; screen := t (the shadow; the planar already shows it)
	move.l	(sp)+,d0
	bsr	mem_release
	movem.l	(sp)+,d3-d7/a3-a5
	rts
eg_end5:				; (a5 was reused by the row copy: reload end5 into the shadow)
	lea	eg_c_end5,a0
	move.l	ms_buf,a1
	bsr	loadchk
	bra	ms_clean

; eg_lband[y] := the band of line y from the 4 split lines of the current design (vid)
eg_lines:
	lea	eg_lband,a0
	moveq	#0,d0			; y
	moveq	#0,d1			; band
.l:	cmp.w	#3,d1
	beq.s	.s
	move.w	d1,d2
	add.w	d2,d2
	lea	eg_splits,a1
	cmp.w	2(a1,d2.w),d0		; the next band's first line
	blt.s	.s
	addq.w	#1,d1
	bra.s	.l
.s:	move.b	d1,(a0)+
	addq.w	#1,d0
	cmp.w	#200,d0
	blt.s	.l
	rts

; the credits (ending.pas credits), then intro2 until a key or a click
eg_credits:
	movem.l	d3/a3,-(sp)
	lea	eg_credtext,a3
	moveq	#8-1,d3
.c:	lea	fn_mainpal,a0		; loadpal(main.pal)
	lea	GS_COLORS(a6),a1
	move.l	#768,d0
	bsr	load_exact
	move.l	a3,a0
	bsr	eg_writestr2
	move.l	a0,a3
	move.w	#3000,d0		; wait(3)
	bsr	delay
	bsr	fading
	dbf	d3,.c
	bsr	orc_dump		; loadscreen(intro2, @screen)
	lea	eg_m_i2,a0
	bsr	ms_load
	bcs	fatal
	bsr	fadein
.f:	bsr	kbd_keypressed		; while fastkeypressed do readkey
	tst.b	d0
	beq.s	.w
	bsr	kbd_readkey
	bra.s	.f
.w:	moveq	#1,d0			; repeat delay(1) until fastkeypressed or mouse.getstatus
	bsr	delay
	bsr	kbd_keypressed
	tst.b	d0
	bne.s	.x
	bsr	kbd_mouse_status
	tst.b	d0
	beq.s	.w
.x:	bsr	fading
	movem.l	(sp)+,d3/a3
	rts

; writestr2(s1, s2, s3) (three Pascal strings, each even-padded, at a0): converging copies in
; colours 0-31, then dothefade  out: a0 = after the strings
eg_writestr2:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	eg_ws,a1		; s1, s2, s3 and j1, j2, j3 := 156 - (length*5) div 2
	lea	eg_wj,a2
	moveq	#3-1,d1
.s:	move.l	a0,(a1)+
	moveq	#0,d0
	move.b	(a0),d0
	move.w	d0,d2
	mulu	#5,d2
	lsr.w	#1,d2
	neg.w	d2
	add.w	#156,d2
	move.w	d2,(a2)+
	lea	2(a0,d0.w),a0
	move.l	a0,d0
	and.w	#$fffe,d0
	move.l	d0,a0
	dbf	d1,.s
	move.l	a0,-(sp)
	bsr	mousehidep
	lea	eg_m_cred,a0		; scr_fillchar(screen, 0) (the ST: the credits' bands, black)
	bsr	ms_load
	bcs	fatal
	lea	GS_COLORS(a6),a0	; set256colors(colors)
	bsr	set256colors
	move.w	GS_TCOLOR(a6),-(sp)
	moveq	#1,d0
	bsr	txt_set_flat
	moveq	#31,d7			; i
.i:	moveq	#0,d6			; the line: 0,1,2 -> y 90,100,110
.ln:	move.w	d6,d0
	add.w	d0,d0
	lea	eg_wj,a0
	move.w	0(a0,d0.w),d4		; j
	add.w	d0,d0
	lea	eg_ws,a0
	move.l	0(a0,d0.w),a5		; s
	move.w	d6,d5
	mulu	#10,d5
	add.w	#90,d5			; centre y
	moveq	#31,d0
	sub.w	d7,d0
	move.w	d0,GS_TCOLOR(a6)	; 31-i
	move.w	d4,d0			; (j-i, y-i), (j-i, y+i), (j+i, y-i), (j+i, y+i)
	sub.w	d7,d0
	move.w	d5,d1
	sub.w	d7,d1
	bsr.s	.p
	move.w	d4,d0
	sub.w	d7,d0
	move.w	d5,d1
	add.w	d7,d1
	bsr.s	.p
	move.w	d4,d0
	add.w	d7,d0
	move.w	d5,d1
	sub.w	d7,d1
	bsr.s	.p
	move.w	d4,d0
	add.w	d7,d0
	move.w	d5,d1
	add.w	d7,d1
	bsr.s	.p
	addq.w	#1,d6
	cmp.w	#3,d6
	blt.s	.ln
	move.w	GS_TSLICE(a6),d0	; delay(tslice div 2)
	lsr.w	#1,d0
	bsr	delay
	dbf	d7,.i
	moveq	#0,d0
	bsr	txt_set_flat
	move.w	(sp)+,GS_TCOLOR(a6)
	bsr	eg_dothefade
	move.l	(sp)+,a0
	movem.l	(sp)+,d3-d7/a3-a5
	rts
.p:	movem.w	d0-d1,-(sp)		; printxy2(x, y, tcolor, s) = flat transparent print + dirty
	move.l	a5,a0
	bsr	chk_print
	movem.w	(sp)+,d0-d1
	moveq	#0,d2
	move.b	(a5),d2
	mulu	#5,d2
	add.w	d0,d2
	addq.w	#4,d2
	move.w	d1,d3
	addq.w	#6,d3
	bra	ms_dirty

; dothefade: 32 steps: colours 0-30 down to black, 31 to red; delay(round(tslice*1.6)) each
eg_dothefade:
	movem.l	d3-d5,-(sp)
	lea	eg_pal,a0
	lea	GS_COLORS(a6),a1
	move.w	#768-1,d0
.cp:	move.b	(a1)+,(a0)+
	dbf	d0,.cp
	moveq	#31,d3			; a
.a:	lea	GS_COLORS(a6),a3	; j 0-30: round(a*colors/32)
	lea	eg_pal,a4
	moveq	#31*3-1,d4
.j:	moveq	#0,d0
	move.b	(a3)+,d0
	mulu	d3,d0
	moveq	#32,d1
	bsr	eg_round
	move.b	d0,(a4)+
	dbf	d4,.j
	cmp.w	#16,d3			; 31: a > 16: round((a-16)*colors/16), else red := round(63/16*(16-a))
	ble.s	.r
	moveq	#3-1,d4
.k:	moveq	#0,d0
	move.b	(a3)+,d0
	move.w	d3,d1
	sub.w	#16,d1
	mulu	d1,d0
	moveq	#16,d1
	bsr	eg_round
	move.b	d0,(a4)+
	dbf	d4,.k
	bra.s	.sh
.r:	moveq	#16,d0
	sub.w	d3,d0
	mulu	#63,d0
	moveq	#16,d1
	bsr	eg_round
	move.b	d0,(a4)
.sh:	lea	eg_pal,a0
	bsr	set256colors
	move.w	GS_TSLICE(a6),d0	; round(tslice*1.6) (tslice 30: 48)
	mulu	#16,d0
	moveq	#10,d1
	bsr	eg_round10
	bsr	delay
	dbf	d3,.a
	lea	eg_pal,a0		; colors := temppal
	lea	GS_COLORS(a6),a1
	move.w	#768-1,d0
.bk:	move.b	(a0)+,(a1)+
	dbf	d0,.bk
	movem.l	(sp)+,d3-d5
	rts
eg_round10:				; round(d0/10), banker's at .5
	divu	d1,d0
	move.l	d0,d2
	swap	d2
	add.w	d2,d2
	cmp.w	d1,d2
	blo.s	.x
	bhi.s	.u
	btst	#0,d0
	beq.s	.x
.u:	addq.w	#1,d0
.x:	and.l	#$ffff,d0
	rts

	section	data
eg_mod_dim:	dc.b	"SOUND",92,"DIMENSIO.MOD",0
eg_mod_love:	dc.b	"SOUND",92,"LOVE.MOD",0
eg_m_a:		dc.b	"END1A",0
eg_m_b:		dc.b	"END1B",0
eg_m_5b:	dc.b	"END5B",0
eg_m_s:		dc.b	"ENDS",0
eg_m_cred:	dc.b	"CRED",0
eg_m_i2:	dc.b	"INTRO2E",0
eg_c_end5:	dc.b	"END5",0
eg_c_end6:	dc.b	"END6",0
eg_fn_scr:	dc.b	"DATA",92,"ENDSCR.DAT",0
	even
	include	"endtext.i"		; eg_text1..5 (y, string lists), eg_credtext, eg_bigfont (build/)

	section	bss
eg_pal:		ds.b	768
eg_ws:		ds.l	3
eg_wj:		ds.w	3
eg_lband:	ds.b	200
eg_t2:		ds.b	1
	even
	section	text
