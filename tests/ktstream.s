; ktstream.s - the music stream (snd.s st_open/snd_poll): plays C:\SOUND\TEST.MOD through
; mod_load1, which finds C:\MUSIC\TEST.RAW (tests/check_stream.py makes it), captures the
; DMA ring's input and writes C:\SND.RAW + C:\SND.TXT (longs: pairs captured, sfx start pair,
; underrun pairs, chunks read, stream byte at the capture start; word mod_on, word 0, long
; busy-loop iterations in SECS seconds - with NOPLAY (no sound at all) the CPU baseline).
; MEASURE = 1: no capture, a poll every 64 iterations; NOSTREAM = 1: the mixer plays TEST.MOD. Build with -DST_RING=65536 so the ring wraps.
; ONCE = 1: play once; SFX = 1: C:\SFX.SAM at 9000 Hz about 2 s in. SECS = seconds to capture.
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"
	ifnd	ONCE
ONCE	equ	0
	endc
	ifnd	SFX
SFX	equ	0
	endc
	ifnd	SECS
SECS	equ	14
	endc

	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	ifne	SFX
	lea	fn_sfx,a0
	lea	sfxsmp,a1
	bsr	snd_sfx_load
	bcs	.fail
	endc
	move.l	#CAPBYTES,d0		; capture buffer
	bsr	mem_alloc
	bcs	.fail
	move.l	a0,capbuf
	ifnd	NOMUSIC
	lea	fn_mod,a0
	moveq	#ONCE,d0
	bsr	mod_load1
	bcs	.fail
	endc
	ifnd	NOSTREAM
	ifnd	NOMUSIC
	tst.w	st_on
	beq	.fail
	endc
	endc
	move.l	capbuf,a0
	move.l	#CAPBYTES,d0
	ifd	MEASURE
	moveq	#0,d0			; measuring: no capture (it forces the effects path)
	endc
	DI				; capture from here: the stream byte it starts at
	move.l	st_rd,res+16
	bsr	snd_capture
	EI
	ifd	NOPLAY
	bsr	snd_exit		; CPU baseline: no sound work at all
	endc
	move.l	HZ200.w,t0
	moveq	#0,d5
.busy:	addq.l	#1,d5			; free CPU: iterations in SECS seconds
	ifd	MEASURE
	moveq	#63,d0
	and.w	d5,d0
	bne.s	.np
	endc
	bsr	snd_poll
.np:		; a game polls from delay/keys/flip
	moveq	#100,d0
.b:	dbf	d0,.b
	ifne	SFX
	tst.w	sfxdone
	bne.s	.sd
	move.l	HZ200.w,d0
	sub.l	t0,d0
	cmp.l	#400,d0
	blo.s	.sd
	move.w	#1,sfxdone
	lea	sfxsmp,a0
	move.w	#9000,d0
	bsr	snd_sfx_play
.sd:
	endc
	move.l	HZ200.w,d0
	sub.l	t0,d0
	cmp.l	#SECS*200,d0
	blo	.busy
	move.l	snd_cap,d0
	cmp.l	snd_capend,d0
	blo	.busy
	move.l	d5,res+24
	move.w	mod_on,res+20
	bsr	mod_stop
	move.l	snd_cap,d1
	sub.l	capbuf,d1
	lsr.l	#1,d1
	move.l	d1,res
	move.l	snd_sfxlog,res+4
	move.l	st_under,res+8
	move.l	st_reads,res+12
	lea	fn_raw,a0
	move.l	capbuf,a1
	move.l	#CAPBYTES,d0
	bsr	fil_save
	lea	fn_txt,a0
	lea	res,a1
	moveq	#28,d0
	bsr	fil_save
	moveq	#0,d0
	bra	sys_exit
.fail:	moveq	#1,d0
	bra	sys_exit

	include	"kernel.s"

CAPBYTES equ	6258*SECS*2

	section	data
fn_mod:	dc.b	"SOUND\TEST.MOD",0
fn_raw:	dc.b	"C:\SND.RAW",0
fn_txt:	dc.b	"C:\SND.TXT",0
fn_sfx:	dc.b	"C:\SFX.SAM",0
	even
	section	bss
capbuf:	ds.l	1
t0:	ds.l	1
res:	ds.l	7
sfxdone: ds.w	1
sfxsmp:	ds.b	SMP_SIZE
