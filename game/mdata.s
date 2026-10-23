; mdata.s - data.pas / modplay.pas / utils_.pas routines MAIN.PRG uses: the palette fades on
; GS_FADELEVEL (0-64) and GS_COLORS, music. Include after mscr.s.
;
; fadestep     in: d0.w step: data.pas fadestep (fadelevel += step, clamped; the screen shows
;              colors * fadelevel / 64: the kernel fade level fadelevel/4 over the bands)
; fadefull     in: d0.w step, d1.w slice (ms): data.pas fadefull
; fadestopmod  in: d0.w step, d1.w slice: data.pas fadestopmod (fade out, music off)
; set256colors in: a0 = 768-byte palette: the bands take it (vid_set256) at full brightness
; playmod      in: a0 = file name: modplay.pas playmod (nothing when the sound option is off)
; stopmod      modplay.pas stopmod: (volume ramp: volume+1 steps of delay(10)) then silence
; haltmod      silence
; playing      out: d0.w = 1 while music plays (Z clear)
; printxy      in: d0.w x1, d1.w y1, a0 = Pascal string: data.pas printxy into the shadow
; (all trash d0-d2/a0-a2)

	section	text
fadestep:
	tst.b	GS_PALETTEDIRTY(a6)
	bne.s	.go
	tst.w	d0
	beq.s	.x
	bpl.s	.up
	tst.w	GS_FADELEVEL(a6)
	beq.s	.x
	bra.s	.go
.up:	cmp.w	#64,GS_FADELEVEL(a6)
	beq.s	.x
.go:	add.w	GS_FADELEVEL(a6),d0
	bpl.s	.p
	moveq	#0,d0
.p:	cmp.w	#64,d0
	ble.s	.m
	moveq	#64,d0
.m:	move.w	d0,GS_FADELEVEL(a6)
	lsr.w	#2,d0
	bsr	vid_set_fade
	sf	GS_PALETTEDIRTY(a6)
.x:	rts

fadefull:
	movem.l	d3-d4,-(sp)
	move.w	d0,d3
	move.w	d1,d4
	tst.w	d3
	bpl.s	.in
.out:	tst.w	GS_FADELEVEL(a6)
	ble.s	.x
	move.w	d3,d0
	bsr	fadestep
	move.w	d4,d0
	bsr	delay
	bra.s	.out
.in:	cmp.w	#64,GS_FADELEVEL(a6)
	bge.s	.x
	move.w	d3,d0
	bsr	fadestep
	move.w	d4,d0
	bsr	delay
	bra.s	.in
.x:	movem.l	(sp)+,d3-d4
	rts

fadestopmod:
	movem.l	d3-d4,-(sp)
	tst.w	d0
	bmi.s	.n
	neg.w	d0
.n:	move.w	d0,d3
	move.w	d1,d4
.l:	tst.w	GS_FADELEVEL(a6)
	ble.s	.x
	move.w	d3,d0
	bsr	fadestep
	move.w	d4,d0			; (setmodvolumeto: no master volume on the ST yet)
	bsr	delay
	bra.s	.l
.x:	bsr	haltmod
	movem.l	(sp)+,d3-d4
	rts

set256colors:
	bsr	vid_set256
	moveq	#16,d0
	bra	vid_set_fade

playmod:
	tst.b	GS_SHIP+SHIP_OPTIONS+OPT_SOUND-1(a6)
	beq.s	.x
	bsr	mod_load
.x:	rts

stopmod:
	move.l	d3,-(sp)
	moveq	#0,d3
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_VOLUME-1(a6),d3
.v:	moveq	#10,d0
	bsr	delay
	dbf	d3,.v
	move.l	(sp)+,d3
haltmod:
	bra	mod_stop

playing:
	move.w	mod_on,d0
	rts

; modplay pausemod / continuemod: the replay stops ticking (silence) and goes on where it was
pausemod:
	move.w	mod_on,md_paused
	clr.w	mod_on
	rts
continuemod:
	tst.w	md_paused
	beq.s	.x
	move.w	md_paused,mod_on
	clr.w	md_paused
.x:	rts
	section	bss
md_paused:	ds.w	1
	section	text

printxy:
	bra	ms_print

; data.pas fadein: 47 steps up to colors (delay(tslice div 2) each unless a key is waiting),
; then set256colors(colors), fadelevel := 64
fadein:
	move.l	d3,-(sp)
	moveq	#1,d3
.l:	move.w	d3,d0			; level a*16/47 (the original's steps of colors/47)
	lsl.w	#4,d0
	ext.l	d0
	divu	#47,d0
	bsr	vid_set_fade
	bsr	kbd_keypressed
	bne.s	.k
	move.w	GS_TSLICE(a6),d0
	lsr.w	#1,d0
	bsr	delay
.k:	addq.w	#1,d3
	cmp.w	#47,d3
	ble.s	.l
	lea	GS_COLORS(a6),a0
	bsr	set256colors
	move.w	#64,GS_FADELEVEL(a6)
	move.l	(sp)+,d3
	rts

; data.pas fading: 47 steps down to black, fadelevel := 0
fading:
	move.l	d3,-(sp)
	moveq	#46,d3
.l:	move.w	d3,d0
	lsl.w	#4,d0
	ext.l	d0
	divu	#47,d0
	bsr	vid_set_fade
	bsr	kbd_keypressed
	bne.s	.k
	move.w	GS_TSLICE(a6),d0
	lsr.w	#1,d0
	bsr	delay
.k:	subq.w	#1,d3
	bpl.s	.l
	moveq	#0,d0
	bsr	vid_set_fade
	clr.w	GS_FADELEVEL(a6)
	move.l	(sp)+,d3
	rts
