; kts.s - sound test: play C:\SONG.MOD through the kernel mixer, capture the output,
; measure the CPU cost. Writes C:\SND.RAW (captured stereo pairs) and C:\SND.TXT:
; longs: pairs captured, 200 Hz ticks elapsed, ticks inside snd_vbl, busy-loop count.
; RATE = 0 (12517 Hz) or 1 (6258 Hz); SECS = seconds to capture.
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"
	ifnd	RATE
RATE	equ	1
	endc
	ifnd	SFX
SFX	equ	0			; 1: also play C:\SFX.SAM at 9000 Hz about 2 s in
	endc
	ifnd	NOSND
NOSND	equ	0
	endc
	ifnd	NOMOD
NOMOD	equ	0
	endc
SECS	equ	6

	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	move.w	#RATE,d0
	bsr	snd_set_rate
	lea	fn_mod,a0		; load the MOD
	bsr	fil_size
	bcs	.fail
	move.l	d0,d6
	bsr	mem_alloc
	bcs	.fail
	move.l	a0,a5
	lea	fn_mod,a0
	move.l	a5,a1
	move.l	d6,d0
	bsr	fil_load
	bcs	.fail
	move.l	a5,a0
	bsr	mod_init
	bcs	.fail
	ifne	NOMOD
	move.l	#(12517>>RATE)*SECS*2,d0
	endc
	ifne	SFX
	moveq	#1,d0
	bsr	snd_sfx_room
	lea	fn_sfx,a0
	lea	sfxsmp,a1
	bsr	snd_sfx_load
	bcs	.fail
	endc
	move.l	#CAPBYTES,d0		; capture buffer
	bsr	mem_alloc
	bcs	.fail
	move.l	a0,capbuf
	move.l	#CAPBYTES,d0
	bsr	snd_capture
	ifne	NOSND
	bsr	snd_exit		; baseline: no sound work at all
	move.l	#4000,d6
	endc
	move.l	HZ200.w,t0
	ifeq	NOMOD
	bsr	mod_start
	endc
	moveq	#0,d5			; busy loop: count iterations until the capture is full
.busy:	addq.l	#1,d5
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
	ifne	NOSND
	move.l	HZ200.w,d0		; no capture: run 6 s by the clock
	sub.l	t0,d0
	cmp.l	#1200,d0
	blo.s	.busy
	else
	move.l	snd_cap,d0
	cmp.l	snd_capend,d0
	blo.s	.busy
	endc
	bsr	mod_stop
	move.l	HZ200.w,d0
	sub.l	t0,d0
	move.l	snd_cap,d1
	sub.l	capbuf,d1
	lsr.l	#1,d1
	move.l	d1,res
	move.l	d0,res+4
	bsr	snd_cpu
	move.l	d0,res+8
	move.l	d5,res+12
	move.l	snd_sfxlog,res+16
	lea	fn_raw,a0
	move.l	capbuf,a1
	move.l	#CAPBYTES,d0
	bsr	fil_save
	lea	fn_txt,a0
	lea	res,a1
	moveq	#20,d0
	bsr	fil_save
	moveq	#0,d0
	bra	sys_exit
.fail:	moveq	#1,d0
	bra	sys_exit

	include	"kernel.s"

CAPBYTES equ	(12517>>RATE)*SECS*2

	section	data
fn_mod:	dc.b	"C:\SONG.MOD",0
fn_raw:	dc.b	"C:\SND.RAW",0
fn_txt:	dc.b	"C:\SND.TXT",0
fn_sfx:	dc.b	"C:\SFX.SAM",0
	even
	section	bss
capbuf:	ds.l	1
t0:	ds.l	1
res:	ds.l	5
sfxdone: ds.w	1
sfxsmp:	ds.b	SMP_SIZE
