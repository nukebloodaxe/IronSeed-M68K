; egg.s - weird.pas's easter eggs in MAIN.PRG (easteregg2-6) and the default song.
;   easteregg2  Alt-7 on the bridge: the Channel 7 noise screen with the two portraits
;   easteregg3  Ctrl-F10: the song chooser (sets defaultsong, which mainloop plays)
;   easteregg4  Ctrl-End: repair hull / fill fuel / repair damages / recharge battery
;   easteregg5  the status lights clicked bottom to top (journey.pas clickcode): add a Dirk, a
;               reflective hull, components, materials
;   easteregg6  bossmode: '7' with the button held: intro3 and explosions, then halt(3)
; Screen designs from tools/mkegg.py: EGGN (the noise screen: 200-215 / 216-231 flicker on own
; slots), EGG3, EGG6; DATA\EGG.DAT holds image31/image32 already put through egg 2's transform.
; The noise is drawn with the game's generator (64000 x random(16), FPC's order) so the state
; stays in step with the original's.
; (all: trashes d0-d2/a0-a2)

	section	text
; ---------------------------------------------------------------
; the common start of eggs 2, 4, 5: mousehide; compressfile(current2); bkcolor := 5; fading;
; scr_fillchar(screen, 0); the noise; the Channel 7 box
eg_noisescreen:
	movem.l	d3-d5/a3,-(sp)
	bsr	mousehide
	moveq	#1,d0
	bsr	ms_snap
	BKCOL	5
	bsr	fading
	lea	eg_m_n,a0
	bsr	ms_load
	bcs	fatal
	move.l	ms_buf,a3		; for i := 0 to 199 do for j := 0 to 319 do
	moveq	#0,d3			;   screen[i,j] := random(16) + 200 + (i mod 2)*16
.row:	move.w	#200,d5
	btst	#0,d3
	beq.s	.ev
	move.w	#216,d5
.ev:	move.w	#320-1,d4
.px:	bsr	mt_u32			; random(16) = the top nibble of the next number
	rol.l	#4,d0
	and.w	#15,d0
	add.w	d5,d0
	move.b	d0,(a3)+
	dbf	d4,.px
	addq.w	#1,d3
	cmp.w	#200,d3
	bne.s	.row
	bsr	ms_dirty_all
	GRAYB	40,53,280,153
	TCOL	47
	GRAYB	110,25,210,61
	PXY	134,30,"Channel 7"
	PXY	116,50,"Destiny: Virtual"
	movem.l	(sp)+,d3-d5/a3
	rts

; the common end: fading; mousehide; loadscreen(current2); set256colors(colors); bkcolor := d0
eg_end:
	move.w	d0,-(sp)
	bsr	fading
	bsr	mousehide
	bsr	orc_dump
	moveq	#1,d0
	bsr	ms_unsnap
	lea	GS_COLORS(a6),a0
	bsr	set256colors
	move.w	(sp)+,GS_BKCOLOR(a6)
	bra	mouseshow

; ---------------------------------------------------------------
; the common loop of eggs 2, 4, 5 (until done and c = 1); a0 = the click handler (or 0), called
; with d3.w = x, d4.w = y when the button was pressed
eg_loop:
	movem.l	d3-d7/a3,-(sp)
	move.l	a0,a3
	moveq	#0,d6			; c
	lea	GS_COLORS(a6),a0	; set256colors(colors)
	bsr	set256colors
.l:	move.w	#200,d3			; 200-215 := colors[random(22)], 216-231 := colors[0]
	moveq	#22,d4
	bsr	eg_flicker
	move.w	GS_TSLICE(a6),d0	; delay(tslice div 2)
	lsr.w	#1,d0
	bsr	delay
	bsr	kbd_mouse_status	; done := mouse.getstatus
	move.b	d0,d7
	bsr	eg_hover		; the button's highlight (c in d6)
	tst.b	d7
	beq.s	.nd
	move.l	a3,d0
	beq.s	.nd
	bsr	kbd_mouse_xy
	move.w	d0,d3
	move.w	d1,d4
	jsr	(a3)
.nd:	bsr	kbd_keypressed		; if fastkeypressed then readkey
	tst.b	d0
	beq.s	.nk
	bsr	kbd_readkey
.nk:	move.w	#216,d3			; 216-231 := colors[random(16)], 200-215 := colors[0]
	moveq	#16,d4
	bsr	eg_flicker
	move.w	GS_TSLICE(a6),d0	; delay(tslice div 2 + 7)
	lsr.w	#1,d0
	addq.w	#7,d0
	bsr	delay
	tst.b	d7
	beq.s	.l
	tst.w	d6
	beq.s	.l
	movem.l	(sp)+,d3-d7/a3
	rts

; c (d6.w) and the hover over the button (80,146)-(240,160) at y offset eg_by (0 or 20)
eg_hover:
	movem.l	d3-d4,-(sp)
	bsr	kbd_mouse_xy
	sub.w	eg_by,d1
	tst.w	d6
	bne.s	.c1
	cmp.w	#145,d1			; (c=0) and (y>145) and (y<161) and (x>79) and (x<241)
	bls.s	.x
	cmp.w	#161,d1
	bhs.s	.x
	cmp.w	#79,d0
	bls.s	.x
	cmp.w	#241,d0
	bhs.s	.x
	moveq	#1,d6
	moveq	#3,d4
	bra.s	.f
.c1:	cmp.w	#146,d1			; (c=1) and ((y<146) or (y>160) or (x<80) or (x>240))
	blo.s	.out
	cmp.w	#160,d1
	bhi.s	.out
	cmp.w	#80,d0
	blo.s	.out
	cmp.w	#240,d0
	bls.s	.x
.out:	moveq	#0,d6
	moveq	#-3,d4
.f:	moveq	#80,d0			; mousehide; plainfadearea(80,146,240,160,+-3); mouseshow
	move.w	#146,d1
	add.w	eg_by,d1
	move.w	#240,d2
	move.w	d1,d3
	add.w	#14,d3
	bsr	plainfadearea
.x:	movem.l	(sp)+,d3-d4
	rts

; d3.w = first index of the lit half (200 or 216), d4.w = random range (22 or 16); then
; set256colors(colors)
eg_flicker:
	movem.l	d5/a3,-(sp)
	lea	GS_COLORS+200*3(a6),a3
	cmp.w	#200,d3
	beq.s	.a
	moveq	#16-1,d5		; 200-215 black (colors[0]) first
.k0:	move.b	GS_COLORS(a6),(a3)+
	move.b	GS_COLORS+1(a6),(a3)+
	move.b	GS_COLORS+2(a6),(a3)+
	dbf	d5,.k0
.a:	moveq	#16-1,d5
.r:	move.w	d4,d0
	bsr	mt_random
	mulu	#3,d0
	lea	GS_COLORS(a6,d0.w),a0
	move.b	(a0)+,(a3)+
	move.b	(a0)+,(a3)+
	move.b	(a0)+,(a3)+
	dbf	d5,.r
	cmp.w	#200,d3
	bne.s	.set
	moveq	#16-1,d5		; then 216-231 black
.k1:	move.b	GS_COLORS(a6),(a3)+
	move.b	GS_COLORS+1(a6),(a3)+
	move.b	GS_COLORS+2(a6),(a3)+
	dbf	d5,.k1
.set:	lea	GS_COLORS(a6),a0
	bsr	set256colors
	movem.l	(sp)+,d5/a3
	rts

; ---------------------------------------------------------------
; weird.pas 487 easteregg2
easteregg2:
	movem.l	d3-d4/a3,-(sp)
	clr.w	eg_by
	bsr	eg_noisescreen
	TCOL	188
	PXY	139,70,"Welcome"
	PXY	141,80,"To The"
	PXY	134,90,"Channel 7"
	PXY	134,100,"Easteregg"
	PXY	144,110,"Hunt!"
	TCOL	92
	GRAYB	80,146,240,160
	RGRAYB	49,68,120,139
	RGRAYB	200,68,271,139
	PXY	91,150,"DON'T TOUCH THIS BUTTON!!!"
	bsr	eg_data			; new(portrait)
	bsr	orc_dump		; loadscreen(image31, portrait)
	moveq	#50,d0
	bsr	eg_portrait
	bsr	orc_dump		; loadscreen(image32, portrait)
	move.w	#201,d0
	bsr	eg_portrait
	bsr	mouseshow
	sub.l	a0,a0
	bsr	eg_loop
	moveq	#3,d0
	bsr	eg_end
	movem.l	(sp)+,d3-d4/a3
	rts

; the next 70x70 portrait of EGG.DAT (eg_pp) to screen[69.., d0]
eg_portrait:
	move.w	#69,d1
	bsr	ms_addr
	move.l	eg_pp,a1
	moveq	#70-1,d1
.r:	moveq	#70-1,d0
.c:	move.b	(a1)+,(a0)+
	dbf	d0,.c
	lea	MS_W-70(a0),a0
	dbf	d1,.r
	move.l	a1,eg_pp
	rts

eg_data:
	lea	eg_fn_dat,a0
	lea	eg_pics,a1
	move.l	#2*70*70,d0
	bsr	fil_load
	bcs	fatal
	move.l	#eg_pics,eg_pp
	rts

; ---------------------------------------------------------------
; weird.pas 675 easteregg4
easteregg4:
	movem.l	d3-d4,-(sp)
	clr.w	eg_by
	bsr	eg_noisescreen
	TCOL	188
	PXY	56,130,"Welcome To The Channel 7 Easteregg Hunt!"
	TCOL	92
	bsr	eg_buttons
	PXY	57,84,"Repair Hull Damage"
	PXY	67,104,"Fill Fuel Tank"
	PXY	174,84,"Repair Damages"
	PXY	169,104,"Recharge Battery"
	bsr	mouseshow
	lea	eg_click4,a0
	bsr	eg_loop
	moveq	#3,d0
	bsr	eg_end
	movem.l	(sp)+,d3-d4
	rts

eg_buttons:
	GRAYB	80,146,240,160
	PXY	91,150,"DON'T TOUCH THIS BUTTON!!!"
	GRAYB	56,80,156,95
	GRAYB	163,80,263,95
	GRAYB	56,100,156,115
	GRAYB	163,100,263,115
	rts

; which of the four buttons is at x d3, y d4: d0.w = 0 (56-156, 80-95), 1 (56-156, 100-115),
; 2 (163-263, 80-95), 3 (163-263, 100-115), -1 none
eg_which:
	moveq	#-1,d0
	moveq	#0,d1
	cmp.w	#56,d3
	blo.s	.x
	cmp.w	#156,d3
	bls.s	.y
	moveq	#2,d1
	cmp.w	#163,d3
	blo.s	.x
	cmp.w	#263,d3
	bhi.s	.x
.y:	cmp.w	#80,d4
	blo.s	.x
	cmp.w	#95,d4
	bls.s	.ok
	addq.w	#1,d1
	cmp.w	#100,d4
	blo.s	.x
	cmp.w	#115,d4
	bhi.s	.x
.ok:	move.w	d1,d0
.x:	tst.w	d0
	rts

eg_click4:
	bsr	eg_which
	bmi.s	.x
	bne.s	.n0
	move.w	GS_SHIP+SHIP_HULLMAX(a6),GS_SHIP+SHIP_HULLINTEGRITY(a6)
	rts
.n0:	cmp.w	#1,d0
	bne.s	.n1
	move.w	GS_SHIP+SHIP_FUELMAX(a6),GS_SHIP+SHIP_FUEL(a6)
	rts
.n1:	cmp.w	#2,d0
	bne.s	.n2
	lea	GS_SHIP+SHIP_DAMAGES(a6),a0	; for j := 1 to 7 do ship.damages[j] := 0
	moveq	#7-1,d0
.d:	clr.b	(a0)+
	dbf	d0,.d
	rts
.n2:	move.w	#32000,GS_SHIP+SHIP_BATTERY(a6)
.x:	rts

; ---------------------------------------------------------------
; weird.pas 756 easteregg5
easteregg5:
	movem.l	d3-d4,-(sp)
	clr.w	eg_by
	bsr	eg_noisescreen
	TCOL	188
	PXY	56,130,"Welcome To The Channel 7 Easteregg Hunt!"
	TCOL	92
	bsr	eg_buttons
	PXY	77,84,"Add a Dirk"
	PXY	54,104,"Add Reflective Hull"
	PXY	177,84,"Add Component"
	PXY	179,104,"Add Material"
	bsr	mouseshow
	lea	eg_click5,a0
	bsr	eg_loop
	moveq	#0,d0
	bsr	eg_end
	movem.l	(sp)+,d3-d4
	rts

eg_click5:
	bsr	eg_which
	bmi.s	.x
	add.w	d0,d0
	move.w	.tab(pc,d0.w),d3	; the item
	moveq	#5,d4			; and how many may be in the hold already
	cmp.w	#2,d0
	ble.s	.n
	moveq	#16,d4
.n:	move.w	d3,d0			; if incargo(item) < n then addcargo2(item, true)
	bsr	incargo
	cmp.w	d4,d0
	bge.s	.x
	move.w	d3,d0
	st	d1
	bra	addcargo2
.x:	rts
.tab:	dc.w	ID_DIRK,ID_REFLECTIVEHULL,ID_UNKNOWN_COMPONENT,ID_UNKNOWN_MATERIAL

; ---------------------------------------------------------------
; weird.pas 573 easteregg3: the song chooser
easteregg3:
	movem.l	d3-d7/a3,-(sp)
	bsr	mousehide
	moveq	#0,d0			; compressfile(current)
	bsr	ms_snap
	TCOL	92
	BKCOL	5
	lea	eg_m_3,a0		; graybutton(0,0,319,199): the mode's picture
	bsr	ms_load
	bcs	fatal
	GRAYB	80,166,240,180
	PXY	91,170,"DON'T TOUCH THIS BUTTON!!!"
	PXY	113,5,"Set Default Song"
	moveq	#0,d5			; for j := 0 to 3
.gb:	move.w	d5,d7
	mulu	#34,d7
	moveq	#5,d6
.gx:	move.w	d6,d0			; graybutton(x, 35+j*34, x+100, 47+j*34) for x = 5, 109, 213
	moveq	#35,d1
	add.w	d7,d1
	move.w	d6,d2
	add.w	#100,d2
	move.l	d3,-(sp)
	moveq	#47,d3
	add.w	d7,d3
	bsr	graybutton
	move.l	(sp)+,d3
	add.w	#104,d6
	cmp.w	#213,d6
	bls.s	.gx
	addq.w	#1,d5
	cmp.w	#3,d5
	bls.s	.gb
	TCOL	22
	PXY	30,38,"Sengzhac"
	PXY	35,72,"D'Pahk"
	PXY	40,106,"Aard"
	PXY	33,140,"Ermigen"
	PXY	134,38,"Titarian"
	PXY	125,72,"Quai Pa'Loi"
	PXY	130,106,"Scavengers"
	PXY	144,140,"Icon"
	PXY	236,38,"The Guild"
	PXY	229,72,"Phaedor Moch"
	PXY	226,106,"Void Dwellers"
	PXY	241,140,"Generic"
	TCOL	188
	PXY	56,183,"Welcome To The Channel 7 Easteregg Hunt!"
	moveq	#0,d6			; c
	PXY	130,155,"/  "
	PXY	175,155,"/63"
	bsr	mouseshow
	move.w	#20,eg_by		; (the button is 20 lower here)
.l:	PXY	120,155,"  "		; s2 := '  '; printxy(120,155,s2); printxy(165,155,s2)
	PXY	165,155,"  "
	bsr	ms_flush		; (drawn straight to the screen in the original)
	bsr	kbd_mouse_status	; done := mouse.getstatus
	move.b	d0,d7
	bsr	eg_hover
	tst.b	d7
	beq.s	.nd
	bsr	kbd_mouse_xy
	bsr	eg_song			; s
	beq.s	.nd
	move.l	a0,a3			; playmod(true, loc_sound()+s)
	lea	eg_path+6,a1
	moveq	#0,d0
	move.b	(a0)+,d0
	subq.w	#1,d0
.cp:	move.b	(a0)+,(a1)+
	dbf	d0,.cp
	clr.b	(a1)
	lea	eg_path,a0
	bsr	playmod
	bsr	mousehide		; s2 := '  '; printxy(130,155,'/'+s2)
	PXY	130,155,"/  "
	bsr	mouseshow
	lea	GS_DEFAULTSONG(a6),a1	; defaultsong := s
	moveq	#13-1,d0
.ds:	move.b	(a3)+,(a1)+
	dbf	d0,.ds
.nd:	bsr	kbd_keypressed		; if fastkeypressed then readkey
	tst.b	d0
	beq.s	.nk
	bsr	kbd_readkey
.nk:	tst.b	d7
	beq	.l
	tst.w	d6
	beq	.l
	clr.w	eg_by
	bsr	fading
	bsr	mousehide
	bsr	orc_dump		; loadscreen(current)
	moveq	#0,d0
	bsr	ms_unsnap
	lea	GS_COLORS(a6),a0
	bsr	set256colors
	bsr	mouseshow
	movem.l	(sp)+,d3-d7/a3
	rts

; the song under x d0, y d1: a0 = its name (string[12], 13 bytes), Z set if none
eg_song:
	moveq	#0,d2			; column
	cmp.w	#5,d0
	blo.s	.no
	cmp.w	#105,d0
	bls.s	.y
	moveq	#4,d2
	cmp.w	#109,d0
	blo.s	.no
	cmp.w	#209,d0
	bls.s	.y
	moveq	#8,d2
	cmp.w	#213,d0
	blo.s	.no
	cmp.w	#313,d0
	bhi.s	.no
.y:	lea	.rows(pc),a0		; 35..47, 69..81, 103..115, 137..149
	moveq	#4-1,d0
.r:	cmp.w	(a0)+,d1
	blo.s	.nr
	cmp.w	(a0),d1
	bls.s	.hit
.nr:	addq.l	#2,a0
	addq.w	#1,d2
	dbf	d0,.r
.no:	moveq	#0,d0
	rts
.hit:	mulu	#13,d2
	lea	eg_songs,a0
	add.w	d2,a0
	moveq	#1,d0
	rts
.rows:	dc.w	35,47,69,81,103,115,137,149

; ---------------------------------------------------------------
; weird.pas 837 easteregg6 (from bossmode): intro3 and explosions until a key, then halt(3)
easteregg6:
.k:	bsr	kbd_keypressed		; while fastkeypressed do readkey
	tst.b	d0
	beq.s	.f
	bsr	kbd_readkey
	bra.s	.k
.f:	bsr	fading
	bsr	mousehide
	bsr	orc_dump		; loadscreen(intro3) (colors from its palette)
	lea	eg_m_6,a0
	bsr	ms_load
	bcs	fatal
	lea	eg_fn_sam,a0
	lea	eg_sample,a1
	bsr	snd_sfx_load
	bcs	fatal
	bsr	eg_boom			; soundeffect(explode3.sam, 9500)
	bsr	fadein
	bsr	mouseshow
.l:	bsr	kbd_mouse_status	; repeat if mouse.getstatus then soundeffect(...)
	tst.b	d0
	beq.s	.nb
	bsr	eg_boom
.nb:	bsr	kbd_keypressed		; until fastkeypressed
	tst.b	d0
	beq.s	.l
	bsr	stopmod
	bsr	fading
	moveq	#3,d0			; closegraph; halt(3)
	bra	sys_exit

eg_boom:
	tst.b	GS_SHIP+SHIP_OPTIONS+OPT_SOUND-1(a6)
	beq.s	.x
	lea	eg_sample,a0
	move.w	#9500,d0
	bra	snd_sfx_play
.x:	rts

; ---------------------------------------------------------------
	section	data
eg_m_n:		dc.b	"EGGN",0
eg_m_3:		dc.b	"EGG3",0
eg_m_6:		dc.b	"EGG6",0
eg_fn_dat:	dc.b	"DATA",92,"EGG.DAT",0
eg_fn_sam:	dc.b	"SOUND",92,"EXPLODE3.SAM",0
eg_path:	dc.b	"SOUND",92,"SENGZHAC.MOD",0,0
	even
eg_songs:	dc.b	12,"SENGZHAC.MOD"	; weird.pas easteregg3's case, by column then row
		dc.b	8,"DPAK.MOD    "
		dc.b	8,"AARD.MOD    "
		dc.b	11,"ERMIGEN.MOD "
		dc.b	12,"TITARIAN.MOD"
		dc.b	8,"QUAI.MOD    "
		dc.b	11,"SCAVENG.MOD "
		dc.b	8,"ICON.MOD    "
		dc.b	9,"GUILD.MOD   "
		dc.b	10,"PHADOR.MOD  "
		dc.b	8,"VOID.MOD    "
		dc.b	10,"SECTOR.MOD  "
	even

	section	bss
eg_by:		ds.w	1
eg_pp:		ds.l	1
eg_sample:	ds.b	SMP_SIZE
eg_pics:	ds.b	2*70*70
	even
	section	text
