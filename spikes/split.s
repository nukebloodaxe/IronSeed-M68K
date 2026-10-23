; split.s - Phase 0 spike: 64 colours on an STE via MFP Timer B palette splits.
; Screen: 16 vertical bars (colour 0..15). Bands of 50 lines each get their own
; 16-colour palette (reds, greens, blues, greys). Any key exits and restores TOS.
; Build: vasmm68k_mot -Ftos -m68000 -devpac -o SPLIT.PRG split.s

TBCR	equ	$fffffa1b	; Timer B control (0 stop, 8 event count)
TBDR	equ	$fffffa21	; Timer B data
IERA	equ	$fffffa07
IMRA	equ	$fffffa13
ISRA	equ	$fffffa0f
PAL	equ	$ffff8240
VEC_VBL	equ	$70
VEC_TB	equ	$120
BANDH	equ	50		; lines per band

	section	text
start:
	; --- screen buffer on a 256-byte boundary
	move.l	#screenbuf+255,d0
	and.l	#$ffffff00,d0
	move.l	d0,scr

	move.w	#4,-(sp)		; Getrez
	trap	#14
	addq.l	#2,sp
	move.w	d0,oldrez
	move.w	#2,-(sp)		; Physbase
	trap	#14
	addq.l	#2,sp
	move.l	d0,oldphys
	move.w	#3,-(sp)		; Logbase
	trap	#14
	addq.l	#2,sp
	move.l	d0,oldlog

	dc.w	$a000			; Line-A init
	dc.w	$a00a			; hide mouse

	move.w	#0,-(sp)		; Setscreen(scr,scr,low)
	move.l	scr,-(sp)
	move.l	scr,-(sp)
	move.w	#5,-(sp)
	trap	#14
	lea	12(sp),sp

	; --- draw: copy the 160-byte bar line to all 200 lines
	move.l	scr,a1
	move.w	#200-1,d1
.line:	lea	barline,a0
	moveq	#160/4-1,d0
.cp:	move.l	(a0)+,(a1)+
	dbf	d0,.cp
	dbf	d1,.line

	; --- supervisor
	clr.l	-(sp)
	move.w	#$20,-(sp)
	trap	#1
	addq.l	#6,sp
	move.l	d0,oldssp

	lea	PAL.w,a0		; save TOS palette
	lea	oldpal,a1
	moveq	#8-1,d0
.sp:	move.l	(a0)+,(a1)+
	dbf	d0,.sp

	move.w	sr,-(sp)
	move.w	#$2700,sr
	move.l	VEC_VBL.w,oldvbl
	move.l	VEC_TB.w,oldtb
	move.b	IERA.w,oldiera
	move.b	IMRA.w,oldimra
	move.b	TBCR.w,oldtbcr
	move.b	TBDR.w,oldtbdr
	clr.b	TBCR.w
	move.l	#tb_handler,VEC_TB.w
	move.l	#vbl_handler,VEC_VBL.w
	bset	#0,IERA.w		; enable + unmask Timer B
	bset	#0,IMRA.w
	move.w	(sp)+,sr

	; --- wait for a key (BIOS is fine from supervisor mode)
.wait:	move.w	#2,-(sp)		; Bconstat(CON)
	move.w	#1,-(sp)
	trap	#13
	addq.l	#4,sp
	tst.w	d0
	beq.s	.wait
	move.w	#2,-(sp)		; Bconin(CON) - eat the key
	move.w	#2,-(sp)
	trap	#13
	addq.l	#4,sp

	; --- restore everything we touched
	move.w	sr,-(sp)
	move.w	#$2700,sr
	clr.b	TBCR.w
	move.b	oldtbdr,TBDR.w
	move.b	oldiera,IERA.w
	move.b	oldimra,IMRA.w
	move.l	oldtb,VEC_TB.w
	move.l	oldvbl,VEC_VBL.w
	move.b	oldtbcr,TBCR.w
	move.w	(sp)+,sr

	lea	oldpal,a0
	lea	PAL.w,a1
	moveq	#8-1,d0
.rp:	move.l	(a0)+,(a1)+
	dbf	d0,.rp

	move.l	oldssp,-(sp)		; back to user mode
	move.w	#$20,-(sp)
	trap	#1
	addq.l	#6,sp

	move.w	oldrez,-(sp)		; Setscreen(old)
	move.l	oldphys,-(sp)
	move.l	oldlog,-(sp)
	move.w	#5,-(sp)
	trap	#14
	lea	12(sp),sp

	dc.w	$a009			; show mouse
	clr.w	-(sp)			; Pterm0
	trap	#1

; --- VBL: band 0 palette, restart Timer B so it counts from the first line
vbl_handler:
	movem.l	d0-d7/a0,-(sp)
	lea	palettes,a0
	movem.l	(a0)+,d0-d7
	movem.l	d0-d7,PAL.w
	move.l	a0,bandptr		; next band
	clr.b	TBCR.w
	move.b	#BANDH,TBDR.w
	move.b	#8,TBCR.w		; event count on display-enable (line ends)
	movem.l	(sp)+,d0-d7/a0
	move.l	oldvbl,-(sp)		; chain to TOS VBL
	rts

; --- Timer B: load the next band's 16 colours
tb_handler:
	move.l	a0,-(sp)
	move.l	bandptr,a0
	move.l	(a0)+,PAL.w
	move.l	(a0)+,PAL+4.w
	move.l	(a0)+,PAL+8.w
	move.l	(a0)+,PAL+12.w
	move.l	(a0)+,PAL+16.w
	move.l	(a0)+,PAL+20.w
	move.l	(a0)+,PAL+24.w
	move.l	(a0)+,PAL+28.w
	move.l	a0,bandptr
	move.l	(sp)+,a0
	bclr	#0,ISRA.w		; software end-of-interrupt
	rte

	section	data
	include	"split_data.i"
	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	; spare band (guards an extra TB hit)

	section	bss
scr:		ds.l	1
oldssp:		ds.l	1
oldphys:	ds.l	1
oldlog:		ds.l	1
oldvbl:		ds.l	1
oldtb:		ds.l	1
bandptr:	ds.l	1
oldrez:		ds.w	1
oldpal:		ds.w	16
oldiera:	ds.b	1
oldimra:	ds.b	1
oldtbcr:	ds.b	1
oldtbdr:	ds.b	1
	even
screenbuf:	ds.b	32000+256
