; mod.s - ProTracker/FastTracker MOD replay (4, 6, 8 channels). Part of kernel.s.
; A line-by-line port of tools/modref.py (the reference); keep the two in step.
;
; mod_init    in: a0 = MOD file in memory (the caller keeps it until mod_stop)
;             out: carry set if the format is not supported or memory ran out.
;             Builds padded mixing copies of the samples (mem_alloc) and resets the song.
;             trashes: d0-d2/a0-a2
; mod_start   start playback (the mixer in snd.s calls mod_tick as samples are used)
; mod_stop    silence
; mod_tick    one tick of the replay. trashes: d0-d7/a0-a5 (called from snd_fill only)

SMP_ADDR	equ	0	; l  mixing copy (data up to the loop end + padding)
SMP_LEN		equ	4	; l
SMP_LS		equ	8	; l
SMP_LL		equ	12	; l  0 = not looped
SMP_VOL		equ	16	; w
SMP_SIZE	equ	20

CH_SMP		equ	0	; l  -> sample entry, 0 = none
CH_POS		equ	4	; l
CH_PERIOD	equ	8	; w
CH_OUTPER	equ	10	; w
CH_VOL		equ	12	; w
CH_FRAC		equ	14	; w
CH_PTARGET	equ	16	; w
CH_PSPEED	equ	18	; w
CH_VIBPOS	equ	20	; w
CH_VIBSPD	equ	22	; w
CH_VIBDEP	equ	24	; w
CH_EFF		equ	26	; w
CH_PRM		equ	28	; w
CH_OFFSET	equ	30	; w
CH_NSMP		equ	32	; w
CH_NPER		equ	34	; w
CH_DELAY	equ	36	; w
CH_ON		equ	38	; b
CH_SIDE		equ	39	; b
CH_SIZE		equ	40

MOD_PAD		equ	2600	; > longest run of sample bytes one mixing chunk can read

	section	text
; ---------------------------------------------------------------
mod_init:
	movem.l	d3-d7/a3-a5,-(sp)
	clr.w	mod_on
	move.l	a0,a5			; file
	move.l	1080(a5),d0		; signature
	moveq	#4,d1
	cmp.l	#'M.K.',d0
	beq.s	.fmt
	cmp.l	#'M!K!',d0
	beq.s	.fmt
	cmp.l	#'FLT4',d0
	beq.s	.fmt
	moveq	#6,d1
	cmp.l	#'6CHN',d0
	beq.s	.fmt
	moveq	#8,d1
	cmp.l	#'8CHN',d0
	bne	.err
.fmt:	move.w	d1,mod_ch
	move.w	d1,d0
	lsl.w	#8,d0
	move.w	d0,mod_patsize		; 64 rows * ch * 4 bytes
	moveq	#0,d0
	move.b	950(a5),d0
	move.w	d0,mod_npos
	lea	952(a5),a0
	move.l	a0,mod_order
	moveq	#0,d2			; highest pattern number in all 128 entries
	moveq	#128-1,d1
.hp:	move.b	(a0)+,d0
	cmp.b	d2,d0
	bls.s	.nh
	move.b	d0,d2
.nh:	dbf	d1,.hp
	and.l	#$ff,d2
	addq.w	#1,d2
	lea	1084(a5),a0
	move.l	a0,mod_pat
	mulu	mod_patsize,d2
	add.l	d2,a0
	move.l	a0,mod_src		; first sample's data in the file
	lea	mod_smp,a3
	lea	20(a5),a4		; sample headers, 30 bytes each
	moveq	#31-1,d7
.smp:	moveq	#0,d3
	move.w	22(a4),d3
	add.l	d3,d3			; length in bytes
	moveq	#0,d4
	move.b	25(a4),d4		; volume
	cmp.w	#64,d4
	bls.s	.v
	moveq	#64,d4
.v:	move.w	d4,SMP_VOL(a3)
	moveq	#0,d5
	move.w	26(a4),d5
	add.l	d5,d5			; loop start
	moveq	#0,d6
	move.w	28(a4),d6
	add.l	d6,d6			; loop length
	cmp.l	#2,d6
	bhi.s	.lp
	moveq	#0,d6
.lp:	move.l	d5,d0			; ls + ll > len: clamp ll
	add.l	d6,d0
	cmp.l	d3,d0
	bls.s	.lok
	move.l	d3,d6
	sub.l	d5,d6
	bpl.s	.lok
	moveq	#0,d6
.lok:	move.l	d3,SMP_LEN(a3)
	move.l	d5,SMP_LS(a3)
	move.l	d6,SMP_LL(a3)
	move.l	d3,d4			; bytes taken from the file: all, or up to the loop end
	tst.l	d6
	beq.s	.nl
	move.l	d5,d4
	add.l	d6,d4
.nl:	move.l	d4,d0
	add.l	#MOD_PAD,d0
	bsr	mem_alloc
	bcs	.err
	move.l	a0,SMP_ADDR(a3)
	move.l	mod_src,a1
	move.l	a0,a2
	move.l	d4,d1
	beq.s	.pad
	subq.l	#1,d1
.cp:	move.b	(a1)+,(a2)+
	subq.l	#1,d1
	bpl.s	.cp
.pad:	move.w	#MOD_PAD-1,d1
	tst.l	d6
	bne.s	.cyc
.z:	clr.b	(a2)+
	dbf	d1,.z
	bra.s	.next
.cyc:	lea	0(a0,d5.l),a1		; loop start in the copy
	move.l	d6,d2
.cy:	move.b	(a1)+,(a2)+
	subq.l	#1,d2
	bne.s	.cy2
	lea	0(a0,d5.l),a1
	move.l	d6,d2
.cy2:	dbf	d1,.cy
.next:	add.l	d3,mod_src		; next sample in the file
	lea	SMP_SIZE(a3),a3
	lea	30(a4),a4
	dbf	d7,.smp
	bsr	mod_reset
	movem.l	(sp)+,d3-d7/a3-a5
	and.b	#$fe,ccr
	rts
.err:	movem.l	(sp)+,d3-d7/a3-a5
	or.b	#1,ccr
	rts

mod_reset:
	lea	mod_chans,a0
	move.w	#8*CH_SIZE/2-1,d0
.c:	clr.w	(a0)+
	dbf	d0,.c
	lea	mod_chans,a0		; sides L R R L L R R L
	lea	mod_sides,a1
	moveq	#8-1,d0
.s:	move.b	(a1)+,CH_SIDE(a0)
	lea	CH_SIZE(a0),a0
	dbf	d0,.s
	move.w	#6,mod_speed
	move.w	#125,mod_bpm
	clr.w	mod_tickn
	clr.w	mod_row
	clr.w	mod_pos
	move.w	#-1,mod_jump
	move.w	#-1,mod_brk
	clr.l	mod_tickacc
	clr.w	mod_tickleft
	rts

mod_start:
	move.w	#1,mod_on
	rts
mod_stop:
	clr.w	mod_on
	rts

; ---------------------------------------------------------------
; trigger: a3 = channel, d0.l = offset. trashes d0-d2/a0
mod_trigger:
	move.l	d0,CH_POS(a3)
	clr.w	CH_FRAC(a3)
	clr.b	CH_ON(a3)
	move.l	CH_SMP(a3),d1
	beq.s	.x
	move.l	d1,a0
	move.l	SMP_LEN(a0),d1
	beq.s	.x
	cmp.l	d1,d0
	bhs.s	.x
	st	CH_ON(a3)
	move.l	SMP_LL(a0),d1		; looped and started past the loop end: wrap into the loop
	beq.s	.x
	move.l	SMP_LS(a0),d2
	add.l	d1,d2
	cmp.l	d2,d0
	blo.s	.x
	sub.l	SMP_LS(a0),d0		; ls + (off - ls) mod ll
	divu	d1,d0			; (offsets and loops are < 64 KB)
	clr.w	d0
	swap	d0
	add.l	SMP_LS(a0),d0
	move.l	d0,CH_POS(a3)
.x:	rts

; apply_note: a3 = channel, d4 = smp, d5 = per, d6 = eff, d7 = prm (all words)
mod_apply_note:
	tst.w	d4
	beq.s	.nos
	cmp.w	#31,d4
	bhi.s	.nos
	move.w	d4,d0
	subq.w	#1,d0
	mulu	#SMP_SIZE,d0
	lea	mod_smp,a0
	add.l	d0,a0
	move.l	a0,CH_SMP(a3)
	move.w	SMP_VOL(a0),CH_VOL(a3)
.nos:	cmp.w	#3,d6
	beq.s	.porta
	cmp.w	#5,d6
	bne.s	.notp
.porta:	tst.w	d5
	beq.s	.pt2
	move.w	d5,CH_PTARGET(a3)
.pt2:	cmp.w	#3,d6
	bne.s	.vib
	tst.w	d7
	beq.s	.vib
	move.w	d7,CH_PSPEED(a3)
	bra.s	.vib
.notp:	tst.w	d5
	beq.s	.vib
	move.w	d5,CH_PERIOD(a3)
	clr.w	CH_VIBPOS(a3)
	moveq	#0,d0
	cmp.w	#9,d6
	bne.s	.trig
	tst.w	d7
	beq.s	.off
	move.w	d7,d0
	lsl.w	#8,d0
	move.w	d0,CH_OFFSET(a3)
.off:	moveq	#0,d0
	move.w	CH_OFFSET(a3),d0
.trig:	bsr	mod_trigger
.vib:	cmp.w	#4,d6
	bne.s	.x
	move.w	d7,d0
	lsr.w	#4,d0
	beq.s	.vd
	move.w	d0,CH_VIBSPD(a3)
.vd:	move.w	d7,d0
	and.w	#15,d0
	beq.s	.x
	move.w	d0,CH_VIBDEP(a3)
.x:	rts

; ---------------------------------------------------------------
mod_tick:
	tst.w	mod_tickn
	bne.s	.t
	bsr	mod_row_
	bra.s	.adv
.t:	bsr	mod_ticks
.adv:	addq.w	#1,mod_tickn
	move.w	mod_tickn,d0
	cmp.w	mod_speed,d0
	blo	.len
	clr.w	mod_tickn
	tst.w	mod_brk
	bpl.s	.jb
	tst.w	mod_jump
	bpl.s	.jb
	addq.w	#1,mod_row
	cmp.w	#64,mod_row
	blo.s	.wrap
	clr.w	mod_row
	addq.w	#1,mod_pos
	bra.s	.wrap
.jb:	move.w	mod_jump,d0
	bpl.s	.j1
	move.w	mod_pos,d0
	addq.w	#1,d0
.j1:	move.w	d0,mod_pos
	move.w	mod_brk,d0
	bpl.s	.b1
	moveq	#0,d0
.b1:	move.w	d0,mod_row
	move.w	#-1,mod_brk
	move.w	#-1,mod_jump
.wrap:	move.w	mod_pos,d0
	cmp.w	mod_npos,d0
	blo.s	.r64
	clr.w	mod_pos
.r64:	cmp.w	#64,mod_row
	blo.s	.len
	clr.w	mod_row
.len:	move.w	mod_bpm,d0		; tick length (16.16, fraction carried)
	lsl.w	#2,d0
	move.l	snd_ticktab,a0
	move.l	0(a0,d0.w),d0
	add.l	mod_tickacc,d0
	move.l	d0,d1
	swap	d1
	move.w	d1,mod_tickleft
	and.l	#$ffff,d0
	move.l	d0,mod_tickacc
	rts

; tick 0: read the row
mod_row_:
	move.l	mod_order,a0
	move.w	mod_pos,d0
	moveq	#0,d1
	move.b	0(a0,d0.w),d1		; pattern
	mulu	mod_patsize,d1
	move.l	mod_pat,a4
	add.l	d1,a4
	move.w	mod_row,d1
	mulu	mod_ch,d1
	lsl.l	#2,d1
	add.l	d1,a4			; first cell of the row
	lea	mod_chans,a3
	move.w	mod_ch,d2
	subq.w	#1,d2
	move.w	d2,mod_cnt
.ch:	moveq	#0,d4			; smp
	moveq	#0,d5			; per
	moveq	#0,d6			; eff
	moveq	#0,d7			; prm
	move.b	(a4),d4
	and.b	#$f0,d4
	move.b	2(a4),d0
	lsr.b	#4,d0
	or.b	d0,d4
	move.b	(a4),d5
	and.w	#15,d5
	lsl.w	#8,d5
	move.b	1(a4),d5
	move.b	2(a4),d6
	and.w	#15,d6
	move.b	3(a4),d7
	addq.l	#4,a4
	move.w	d6,CH_EFF(a3)
	move.w	d7,CH_PRM(a3)
	cmp.w	#$e,d6			; EDx with x > 0: delay the whole note
	bne.s	.nd
	move.w	d7,d0
	and.w	#$f0,d0
	cmp.w	#$d0,d0
	bne.s	.nd
	move.w	d7,d0
	and.w	#15,d0
	beq.s	.nd
	move.w	d4,CH_NSMP(a3)
	move.w	d5,CH_NPER(a3)
	move.w	d0,CH_DELAY(a3)
	bra	.nextc
.nd:	bsr	mod_apply_note
	; tick-0 effects
	cmp.w	#$c,d6
	bne.s	.e1
	move.w	d7,d0
	cmp.w	#64,d0
	bls.s	.c1
	moveq	#64,d0
.c1:	move.w	d0,CH_VOL(a3)
	bra	.eend
.e1:	cmp.w	#$f,d6
	bne.s	.e2
	tst.w	d7
	beq	.eend
	cmp.w	#32,d7
	bhs.s	.bpm
	move.w	d7,mod_speed
	bra	.eend
.bpm:	move.w	d7,mod_bpm
	bra	.eend
.e2:	cmp.w	#$d,d6
	bne.s	.e3
	move.w	d7,d0
	lsr.w	#4,d0
	mulu	#10,d0
	move.w	d7,d1
	and.w	#15,d1
	add.w	d1,d0
	move.w	d0,mod_brk
	bra	.eend
.e3:	cmp.w	#$b,d6
	bne.s	.e4
	move.w	d7,mod_jump
	bra	.eend
.e4:	cmp.w	#8,d6
	bne.s	.e5
	cmp.w	#128,d7
	shs	CH_SIDE(a3)		; $ff = right
	and.b	#1,CH_SIDE(a3)
	bra	.eend
.e5:	cmp.w	#$e,d6
	bne	.eend
	move.w	d7,d0
	lsr.w	#4,d0			; x
	move.w	d7,d1
	and.w	#15,d1			; y
	cmp.w	#1,d0
	bne.s	.e52
	move.w	CH_PERIOD(a3),d2
	sub.w	d1,d2
	cmp.w	#113,d2
	bge.s	.e51
	moveq	#113,d2
.e51:	move.w	d2,CH_PERIOD(a3)
	bra.s	.eend
.e52:	cmp.w	#2,d0
	bne.s	.e5a
	move.w	CH_PERIOD(a3),d2
	add.w	d1,d2
	cmp.w	#856,d2
	ble.s	.e53
	move.w	#856,d2
.e53:	move.w	d2,CH_PERIOD(a3)
	bra.s	.eend
.e5a:	cmp.w	#$a,d0
	bne.s	.e5b
	add.w	d1,CH_VOL(a3)
	cmp.w	#64,CH_VOL(a3)
	bls.s	.eend
	move.w	#64,CH_VOL(a3)
	bra.s	.eend
.e5b:	cmp.w	#$b,d0
	bne.s	.e5c
	sub.w	d1,CH_VOL(a3)
	bpl.s	.eend
	clr.w	CH_VOL(a3)
	bra.s	.eend
.e5c:	cmp.w	#$c,d0
	bne.s	.eend
	tst.w	d1
	bne.s	.eend
	clr.w	CH_VOL(a3)
.eend:	move.w	CH_PERIOD(a3),CH_OUTPER(a3)
.nextc:	lea	CH_SIZE(a3),a3
	subq.w	#1,mod_cnt
	bpl	.ch
	rts

; ticks 1..speed-1
mod_ticks:
	lea	mod_chans,a3
	move.w	mod_ch,d0
	subq.w	#1,d0
	move.w	d0,mod_cnt
.ch:	move.w	CH_EFF(a3),d6
	move.w	CH_PRM(a3),d7
	move.w	d7,d4
	lsr.w	#4,d4			; x
	move.w	d7,d5
	and.w	#15,d5			; y
	move.w	CH_PERIOD(a3),CH_OUTPER(a3)
	tst.w	d6
	bne.s	.n0
	tst.w	d7
	beq	.vibt
	moveq	#0,d0			; arpeggio: tick % 3
	move.w	mod_tickn,d0
	divu	#3,d0
	swap	d0
	tst.w	d0
	beq	.vibt
	move.w	d4,d1
	cmp.w	#1,d0
	beq.s	.ar1
	move.w	d5,d1
.ar1:	lea	mod_periods,a0		; find the period in the table
	moveq	#0,d2
	move.w	CH_PERIOD(a3),d0
.ar2:	cmp.w	(a0)+,d0
	beq.s	.ar3
	addq.w	#1,d2
	cmp.w	#36,d2
	bne.s	.ar2
	bra	.vibt			; not a table note: no arpeggio
.ar3:	add.w	d1,d2
	cmp.w	#35,d2
	bls.s	.ar4
	moveq	#35,d2
.ar4:	add.w	d2,d2
	lea	mod_periods,a0
	move.w	0(a0,d2.w),CH_OUTPER(a3)
	bra	.vibt
.n0:	cmp.w	#1,d6
	bne.s	.n1
	move.w	CH_PERIOD(a3),d0
	sub.w	d7,d0
	cmp.w	#113,d0
	bge.s	.s1
	moveq	#113,d0
.s1:	move.w	d0,CH_PERIOD(a3)
	move.w	d0,CH_OUTPER(a3)
	bra	.vibt
.n1:	cmp.w	#2,d6
	bne.s	.n2
	move.w	CH_PERIOD(a3),d0
	add.w	d7,d0
	cmp.w	#856,d0
	ble.s	.s2
	move.w	#856,d0
.s2:	move.w	d0,CH_PERIOD(a3)
	move.w	d0,CH_OUTPER(a3)
	bra.s	.vibt
.n2:	cmp.w	#3,d6
	beq.s	.tp
	cmp.w	#5,d6
	bne.s	.vibt
.tp:	move.w	CH_PTARGET(a3),d1
	beq.s	.tp3
	move.w	CH_PERIOD(a3),d0
	cmp.w	d1,d0
	bge.s	.tpdn
	add.w	CH_PSPEED(a3),d0	; up to the target
	cmp.w	d1,d0
	ble.s	.tp2
	move.w	d1,d0
	bra.s	.tp2
.tpdn:	beq.s	.tp3
	sub.w	CH_PSPEED(a3),d0
	cmp.w	d1,d0
	bge.s	.tp2
	move.w	d1,d0
.tp2:	move.w	d0,CH_PERIOD(a3)
.tp3:	move.w	CH_PERIOD(a3),CH_OUTPER(a3)
.vibt:	cmp.w	#4,d6
	beq.s	.vb
	cmp.w	#6,d6
	bne.s	.vs
.vb:	move.w	CH_VIBPOS(a3),d0
	move.w	d0,d1
	and.w	#31,d1
	lea	mod_sine,a0
	moveq	#0,d2
	move.b	0(a0,d1.w),d2
	mulu	CH_VIBDEP(a3),d2
	lsr.l	#7,d2
	btst	#5,d0
	beq.s	.vp
	neg.w	d2
.vp:	add.w	CH_PERIOD(a3),d2
	move.w	d2,CH_OUTPER(a3)
	add.w	CH_VIBSPD(a3),d0
	and.w	#63,d0
	move.w	d0,CH_VIBPOS(a3)
.vs:	cmp.w	#5,d6			; volume slide for 5, 6, A
	beq.s	.vsl
	cmp.w	#6,d6
	beq.s	.vsl
	cmp.w	#$a,d6
	bne.s	.ee
.vsl:	tst.w	d4
	beq.s	.vdn
	add.w	d4,CH_VOL(a3)
	cmp.w	#64,CH_VOL(a3)
	bls.s	.ee
	move.w	#64,CH_VOL(a3)
	bra.s	.ee
.vdn:	sub.w	d5,CH_VOL(a3)
	bpl.s	.ee
	clr.w	CH_VOL(a3)
.ee:	cmp.w	#$e,d6
	bne	.nextc
	cmp.w	#9,d4
	bne.s	.ec
	tst.w	d5
	beq	.nextc
	moveq	#0,d0
	move.w	mod_tickn,d0
	divu	d5,d0
	swap	d0
	tst.w	d0
	bne	.nextc
	moveq	#0,d0
	bsr	mod_trigger
	bra	.nextc
.ec:	cmp.w	#$c,d4
	bne.s	.ed
	cmp.w	mod_tickn,d5
	bne	.nextc
	clr.w	CH_VOL(a3)
	bra	.nextc
.ed:	cmp.w	#$d,d4
	bne.s	.nextc
	move.w	mod_tickn,d0
	cmp.w	CH_DELAY(a3),d0
	bne.s	.nextc
	move.w	CH_NSMP(a3),d4
	move.w	CH_NPER(a3),d5
	moveq	#0,d6
	moveq	#0,d7
	bsr	mod_apply_note
	move.w	CH_PERIOD(a3),CH_OUTPER(a3)
.nextc:	lea	CH_SIZE(a3),a3
	subq.w	#1,mod_cnt
	bpl	.ch
	rts

	section	data
mod_sides:	dc.b	0,1,1,0,0,1,1,0
mod_sine:	dc.b	0,24,49,74,97,120,141,161,180,197,212,224,235,244,250,253
		dc.b	255,253,250,244,235,224,212,197,180,161,141,120,97,74,49,24
	even
mod_periods:	dc.w	856,808,762,720,678,640,604,570,538,508,480,453
		dc.w	428,404,381,360,339,320,302,285,269,254,240,226
		dc.w	214,202,190,180,170,160,151,143,135,127,120,113

	section	bss
mod_order:	ds.l	1
mod_pat:	ds.l	1
mod_src:	ds.l	1
mod_tickacc:	ds.l	1
mod_on:		ds.w	1
mod_ch:		ds.w	1
mod_patsize:	ds.w	1
mod_npos:	ds.w	1
mod_speed:	ds.w	1
mod_bpm:	ds.w	1
mod_tickn:	ds.w	1
mod_row:	ds.w	1
mod_pos:	ds.w	1
mod_jump:	ds.w	1
mod_brk:	ds.w	1
mod_tickleft:	ds.w	1
mod_cnt:	ds.w	1
mod_smp:	ds.b	31*SMP_SIZE
mod_chans:	ds.b	8*CH_SIZE
	even
