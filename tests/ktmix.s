; ktmix.s - micro-benchmark: cycles per stereo pair for snd_out and the mixer paths.
; Writes C:\MIX.TXT: longs = 200 Hz ticks for 100 x 1000 pairs of: silent fill, mix GAME (4 ch).
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"
	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	bsr	snd_exit		; keep the VBL out of it
	lea	fn_mod,a0
	bsr	fil_size
	move.l	d0,d6
	bsr	mem_alloc
	move.l	a0,a5
	lea	fn_mod,a0
	move.l	a5,a1
	move.l	d6,d0
	bsr	fil_load
	move.l	a5,a0
	bsr	mod_init
	; 1: silent: 100 x snd_fill(1000) with mod off
	move.l	HZ200.w,t0
	move.w	#100-1,cnt
.s:	move.w	#1000,d0
	bsr	snd_fill
	subq.w	#1,cnt
	bpl	.s
	move.l	HZ200.w,d0
	sub.l	t0,d0
	move.l	d0,res
	; 2: snd_out only
	move.w	#1000,snd_k
	move.l	HZ200.w,t0
	move.w	#100-1,cnt
.o:	move.w	#1000,snd_k
	bsr	snd_out
	subq.w	#1,cnt
	bpl	.o
	move.l	HZ200.w,d0
	sub.l	t0,d0
	move.l	d0,res+4
	; 3: GAME mixing
	bsr	mod_start
	move.l	HZ200.w,t0
	move.w	#100-1,cnt
.m:	move.w	#1000,d0
	bsr	snd_fill
	subq.w	#1,cnt
	bpl	.m
	move.l	HZ200.w,d0
	sub.l	t0,d0
	move.l	d0,res+8
	lea	fn,a0
	lea	res,a1
	moveq	#12,d0
	bsr	fil_save
	moveq	#0,d0
	bra	sys_exit
	include	"kernel.s"
	section	data
fn_mod:	dc.b	"C:\SONG.MOD",0
fn:	dc.b	"C:\MIX.TXT",0
	even
	section	bss
res:	ds.l	3
t0:	ds.l	1
cnt:	ds.w	1
