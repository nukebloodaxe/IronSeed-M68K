; c2pbench.s - Phase 0 spike: chunky (1 byte/pixel, 320x200) -> STE low-res planes,
; with a 256->16 colour LUT per 50-line band, while the 64-colour Timer B split runs.
; Method: per 8 pixels, shift-accumulate one bit per plane into the 4 bytes of a
; long (table entry per chunky value), then MOVEP.L writes the 4 plane bytes.
; Writes C:\C2P.BIN (timings in 200 Hz ticks), C:\SCR.BIN (screen), C:\CHK.BIN (chunky).
; Build: vasmm68k_mot -Ftos -m68000 -devpac -nosym -o C2PBENCH.PRG c2pbench.s

TBCR	equ	$fffffa1b
TBDR	equ	$fffffa21
IERA	equ	$fffffa07
IMRA	equ	$fffffa13
ISRA	equ	$fffffa0f
PAL	equ	$ffff8240
HZ200	equ	$4ba
BANDH	equ	50
NFULL	equ	10		; full-frame iterations
NDIFF	equ	50		; diff-frame iterations

	include	"c2p_mac.i"

	section	text
start:
	move.l	#screenbuf+255,d0
	and.l	#$ffffff00,d0
	move.l	d0,scr
	dc.w	$a000
	dc.w	$a00a
	move.w	#0,-(sp)
	move.l	scr,-(sp)
	move.l	scr,-(sp)
	move.w	#5,-(sp)
	trap	#14
	lea	12(sp),sp

	clr.l	-(sp)
	move.w	#$20,-(sp)
	trap	#1
	addq.l	#6,sp
	move.l	d0,oldssp

	bsr	build_luts
	bsr	fill_chunky
	bsr	split_on

	; ---- full frames
	move.l	HZ200.w,d7
	moveq	#NFULL-1,d5
.f:	move.l	d5,-(sp)
	lea	chunky,a0
	move.l	scr,a2
	bsr	c2p_full
	move.l	(sp)+,d5
	dbf	d5,.f
	move.l	HZ200.w,d0
	sub.l	d7,d0
	move.l	d0,results

	; prev := chunky
	lea	chunky,a0
	lea	prev,a1
	move.w	#64000/4-1,d0
.cp:	move.l	(a0)+,(a1)+
	dbf	d0,.cp

	; ---- diff frames, 10 % of 16-pixel groups changed each time
	move.l	HZ200.w,d7
	moveq	#0,d5
.d:	move.l	d5,-(sp)
	move.w	d5,d0
	bsr	touch10
	lea	chunky,a0
	move.l	scr,a2
	bsr	c2p_diff
	move.l	(sp)+,d5
	addq.w	#1,d5
	cmp.w	#NDIFF,d5
	bne.s	.d
	move.l	HZ200.w,d0
	sub.l	d7,d0
	move.l	d0,results+4

	; ---- the touch cost alone (to subtract)
	move.l	HZ200.w,d7
	moveq	#0,d5
.t:	move.w	d5,d0
	bsr	touch10
	addq.w	#1,d5
	cmp.w	#NDIFF,d5
	bne.s	.t
	move.l	HZ200.w,d0
	sub.l	d7,d0
	move.l	d0,results+8

	; ---- diff frames with nothing changed (first resync prev with chunky)
	lea	chunky,a0
	move.l	scr,a2
	bsr	c2p_diff
	move.l	HZ200.w,d7
	moveq	#NDIFF-1,d5
.z:	move.l	d5,-(sp)
	lea	chunky,a0
	move.l	scr,a2
	bsr	c2p_diff
	move.l	(sp)+,d5
	dbf	d5,.z
	move.l	HZ200.w,d0
	sub.l	d7,d0
	move.l	d0,results+12

	; ---- dirty-map frames: touch 10 % + mark dirty, convert only marked groups
	move.l	HZ200.w,t0
	moveq	#0,d5
.m:	move.l	d5,-(sp)
	move.w	d5,d0
	bsr	touch10
	move.w	(sp),d0
	bsr	mark10
	lea	chunky,a0
	move.l	scr,a2
	bsr	c2p_dirty
	move.l	(sp)+,d5
	addq.w	#1,d5
	cmp.w	#NDIFF,d5
	bne.s	.m
	move.l	HZ200.w,d0
	sub.l	t0,d0
	move.l	d0,results+16

	move.l	HZ200.w,d7		; touch + mark cost alone
	moveq	#0,d5
.n:	move.w	d5,d0
	bsr	touch10
	move.w	d5,d0
	bsr	mark10
	bsr	clear_dirty
	addq.w	#1,d5
	cmp.w	#NDIFF,d5
	bne.s	.n
	move.l	HZ200.w,d0
	sub.l	d7,d0
	move.l	d0,results+20

	; the touch-only pass left chunky != screen; convert once more so they match
	lea	chunky,a0
	move.l	scr,a2
	bsr	c2p_full

	lea	fn_res,a0
	lea	results,a1
	move.l	#24,d0
	bsr	save
	lea	fn_scr,a0
	move.l	scr,a1
	move.l	#32000,d0
	bsr	save
	lea	fn_chk,a0
	lea	chunky,a1
	move.l	#64000,d0
	bsr	save

.wait:	move.w	#2,-(sp)
	move.w	#1,-(sp)
	trap	#13
	addq.l	#4,sp
	tst.w	d0
	beq.s	.wait
	move.w	#2,-(sp)
	move.w	#2,-(sp)
	trap	#13
	addq.l	#4,sp

	bsr	split_off
	move.l	oldssp,-(sp)
	move.w	#$20,-(sp)
	trap	#1
	addq.l	#6,sp
	dc.w	$a009
	clr.w	-(sp)
	trap	#1

; ------------------------------------------------------------------
; c2p_diff: like c2p_full, but only 16-pixel groups that differ from 'prev'
; are converted (and copied into prev). Trashes d0-d6/a0-a4.
c2p_diff:
	lea	luttabs,a1
	lea	prev,a4
	move.l	a4,d4
	sub.l	a0,d4			; d4 = prev - chunky
	moveq	#BANDH,d3
	move.w	#200-1,d5
.line:	moveq	#20-1,d1
.grp:	move.l	a0,a3
	cmpm.l	(a4)+,(a0)+
	bne.s	.dif
	cmpm.l	(a4)+,(a0)+
	bne.s	.dif
	cmpm.l	(a4)+,(a0)+
	bne.s	.dif
	cmpm.l	(a4)+,(a0)+
	bne.s	.dif
	addq.l	#8,a2
	dbf	d1,.grp
	bra	.eol
.dif:	move.l	a3,a0			; rewind, copy group into prev
	lea	0(a3,d4.l),a4
	move.l	(a0)+,(a4)+
	move.l	(a0)+,(a4)+
	move.l	(a0)+,(a4)+
	move.l	(a0)+,(a4)+
	move.l	a3,a0
	PIX8
	movep.l	d6,0(a2)
	PIX8
	movep.l	d6,1(a2)
	addq.l	#8,a2
	dbf	d1,.grp
.eol:	subq.w	#1,d3
	bne.s	.same
	lea	1024(a1),a1
	moveq	#BANDH,d3
.same:	dbf	d5,.line
	rts

; c2p_dirty: convert only groups whose bit is set in dirtymap (one long per
; line, group g = bit 31-g), then clear the map. Trashes d0-d7/a0-a2/a5.
c2p_dirty:
	lea	luttabs,a1
	lea	dirtymap,a5
	moveq	#BANDH,d3
	move.w	#200-1,d5
.line:	move.l	(a5),d7
	bne.s	.some
	lea	320(a0),a0		; clean line: skip
	lea	160(a2),a2
	bra	.eol
.some:	clr.l	(a5)
	moveq	#20-1,d1
.grp:	add.l	d7,d7
	bcs.s	.cv
	lea	16(a0),a0
	addq.l	#8,a2
	dbf	d1,.grp
	bra	.eol
.cv:	PIX8
	movep.l	d6,0(a2)
	PIX8
	movep.l	d6,1(a2)
	addq.l	#8,a2
	dbf	d1,.grp
.eol:	addq.l	#4,a5
	subq.w	#1,d3
	bne.s	.same
	lea	1024(a1),a1
	moveq	#BANDH,d3
.same:	dbf	d5,.line
	rts

; mark10: set dirty bits for the groups touch10 changed (g = k, k+10, ...)
mark10:
	ext.l	d0
	divu	#10,d0
	swap	d0
	and.l	#$ffff,d0		; d0 = first group
	lea	dirtymap,a0
.lp:	move.l	d0,d1
	divu	#20,d1			; d1.w = line, high word = column
	move.w	d1,d2
	lsl.w	#2,d2
	swap	d1
	moveq	#31,d3
	sub.w	d1,d3
	move.l	0(a0,d2.w),d1
	bset	d3,d1
	move.l	d1,0(a0,d2.w)
	add.l	#10,d0
	cmp.l	#4000,d0
	blt.s	.lp
	rts

clear_dirty:
	lea	dirtymap,a0
	move.w	#200-1,d0
.c:	clr.l	(a0)+
	dbf	d0,.c
	rts

; touch10: change every 10th 16-pixel group (groups g = d0 mod 10 ...), 400 groups.
touch10:
	ext.l	d0
	divu	#10,d0
	swap	d0			; d0.w = iteration mod 10
	lea	chunky,a0
	mulu	#16,d0
	add.l	d0,a0
	move.w	#400-1,d1
.lp:	add.b	#16,(a0)
	lea	160(a0),a0		; 10 groups x 16 bytes
	dbf	d1,.lp
	rts

; save: a0 = name, a1 = buffer, d0 = length
save:	movem.l	d0/a1,-(sp)
	clr.w	-(sp)
	move.l	a0,-(sp)
	move.w	#$3c,-(sp)		; Fcreate
	trap	#1
	addq.l	#8,sp
	movem.l	(sp)+,d1/a1
	move.w	d0,d3
	bmi.s	.x
	move.l	a1,-(sp)
	move.l	d1,-(sp)
	move.w	d3,-(sp)
	move.w	#$40,-(sp)		; Fwrite
	trap	#1
	lea	12(sp),sp
	move.w	d3,-(sp)
	move.w	#$3e,-(sp)		; Fclose
	trap	#1
	addq.l	#4,sp
.x:	rts

; ---- Timer B split (as in split.s)
split_on:
	lea	PAL.w,a0
	lea	oldpal,a1
	moveq	#8-1,d0
.sp:	move.l	(a0)+,(a1)+
	dbf	d0,.sp
	move.w	sr,-(sp)
	move.w	#$2700,sr
	move.l	$70.w,oldvbl
	move.l	$120.w,oldtb
	move.b	IERA.w,oldiera
	move.b	IMRA.w,oldimra
	clr.b	TBCR.w
	move.l	#tb_handler,$120.w
	move.l	#vbl_handler,$70.w
	bset	#0,IERA.w
	bset	#0,IMRA.w
	move.w	(sp)+,sr
	rts

split_off:
	move.w	sr,-(sp)
	move.w	#$2700,sr
	clr.b	TBCR.w
	move.b	oldiera,IERA.w
	move.b	oldimra,IMRA.w
	move.l	oldtb,$120.w
	move.l	oldvbl,$70.w
	move.w	(sp)+,sr
	lea	oldpal,a0
	lea	PAL.w,a1
	moveq	#8-1,d0
.rp:	move.l	(a0)+,(a1)+
	dbf	d0,.rp
	rts

vbl_handler:
	movem.l	d0-d7/a0,-(sp)
	lea	palettes,a0
	movem.l	(a0)+,d0-d7
	movem.l	d0-d7,PAL.w
	move.l	a0,bandptr
	clr.b	TBCR.w
	move.b	#BANDH,TBDR.w
	move.b	#8,TBCR.w
	movem.l	(sp)+,d0-d7/a0
	move.l	oldvbl,-(sp)
	rts

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
	bclr	#0,ISRA.w
	rte

	include	"c2p.i"

	section	data
	include	"split_data.i"
	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
fn_res:	dc.b	"C:\C2P.BIN",0
fn_scr:	dc.b	"C:\SCR.BIN",0
fn_chk:	dc.b	"C:\CHK.BIN",0
	even

	section	bss
scr:		ds.l	1
oldssp:		ds.l	1
oldvbl:		ds.l	1
oldtb:		ds.l	1
bandptr:	ds.l	1
results:	ds.l	6
dirtymap:	ds.l	200
t0:		ds.l	1
oldpal:		ds.w	16
oldiera:	ds.b	1
oldimra:	ds.b	1
	even
luttabs:	ds.l	4*256
chunky:		ds.b	64000
prev:		ds.b	64000
screenbuf:	ds.b	32000+256
