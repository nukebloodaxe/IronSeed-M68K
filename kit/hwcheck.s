; hwcheck.s - Iron Seed STE: the real-hardware check kit (Phase 8). HWCHECK.PRG.
;
; Built on the game's own kernel (the same raster splits, VBL, sound, stream and file code), with
; the Timer B statistics switched on (kernel vid.s, TBLOG). Copy it into the game folder (it looks
; for MUSIC\, SOUND\ and DATA\ beside it) or onto the floppy save disk, run it, choose the tests
; from the menu; Q writes HWCHECK.TXT next to the program (CR LF text) and quits.
;
;  1  raster splits: 20 s of the four bands with the CPU busy (and the mouse moving): every split's
;     palette write is timed against the video counter (on time = still in the blank before the
;     split line; late = the line's first pixels showed the old colours)
;  2  the same with the MOD mixer playing SOUND\GAME.MOD (the game without a MUSIC folder):
;     split timing and the CPU left for the game
;  3  disk read speed: a MUSIC\*.RAW (else the largest DATA file) in 16 KB reads (the stream's
;     chunk) and in 64 KB reads; KB/s, the slowest read, the splits during the reads
;  4  the music stream: 40 s of a MUSIC song through the kernel's stream with the CPU busy: the
;     ring's lowest level, underruns, the slowest read, the splits during and between reads
;  5  keyboard: the keys the ST maps for the PC game (Ctrl-ClrHome = Ctrl-End, Ctrl-F10, Alt keys,
;     F-keys, keypad), raw codes and what the game receives
;  6  floppy drive A: the read speed with the game's interrupts running, and a disk change -
;     whether TOS notices it by itself, and that the game's own "disk changed" signal works
;  A  runs 1-4 one after another
;
; Build: tools/mkkit.sh (or tools/asm.sh kit/hwcheck.s OUT/HWCHECK.PRG).
; Report lines: see docs/HWCHECK.md for how to read them.

TBLOG	equ	1			; kernel vid.s: Timer B statistics
	ifnd	CPU_CAL			; the 8 MHz calibration: cpu_count on a 1040STE at 8 MHz,
CPU_CAL		equ	2946		; 60 Hz, TOS 1.62 (Hatari 2.4.1)
	endc

	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"

KIT_VER		equ	1
LOADBUF		equ	8192		; the busy loop's copy (bytes)
REPMAX		equ	16384		; report buffer
RD_LIMIT	equ	2*1024*1024	; bytes per read-speed pass
RD_TIME		equ	20*200		; at most 20 s per pass
DTA_SIZE	equ	44
CPU_K8		equ	CPU_CAL		; busy-loop count in 0.5 s on an 8 MHz STE (Hatari, see below)
RUN_LOAD	equ	1		; hw_run: the busy loop
RUN_POLL	equ	2		; hw_run: snd_poll between passes (the stream)
ROW_PROG	equ	23		; progress line

	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	bsr	flp_exit		; plain GEMDOS even when started from an Iron Seed floppy
	move.l	#LOADBUF*2,d0		; the busy loop's two buffers
	bsr	mem_alloc
	bcs	quit
	move.l	a0,hw_lbuf
	move.l	#65536,d0		; read buffer
	bsr	mem_alloc
	bcs	quit
	move.l	a0,hw_rbuf
	lea	hw_rep,a0
	move.l	a0,hw_repp
	bsr	con_init
	move.b	#3,con_mode		; screen + report
	bsr	hw_info

menu:	bsr	menu_show
.k:	bsr	getkey
	move.b	#3,con_mode		; the tests: screen + report
	cmp.b	#'1',d0
	beq	.t1
	cmp.b	#'2',d0
	beq	.t2
	cmp.b	#'3',d0
	beq	.t3
	cmp.b	#'4',d0
	beq	.t4
	cmp.b	#'5',d0
	beq	.t5
	cmp.b	#'6',d0
	beq	.t6
	cmp.b	#'A',d0
	beq	.ta
	cmp.b	#'Q',d0
	beq	.q
	cmp.b	#27,d0
	beq	.q
	bra.s	.k
.t1:	bsr	t_splits
	bra	.done
.t2:	bsr	t_mixer
	bra	.done
.t3:	bsr	t_disk
	bra	.done
.t4:	bsr	t_stream
	bra	.done
.t5:	bsr	t_keys
	bra	.done
.t6:	bsr	t_floppy
	bra	.done
.ta:	bsr	t_splits
	tst.w	hw_abort
	bne.s	.done
	bsr	t_mixer
	tst.w	hw_abort
	bne.s	.done
	bsr	t_disk
	tst.w	hw_abort
	bne.s	.done
	bsr	t_stream
.done:	move.b	#1,con_mode
	moveq	#ROW_PROG,d1
	bsr	con_clrrow
	moveq	#24,d1
	moveq	#2,d0
	bsr	con_at
	lea	m_anykey,a0
	bsr	put_s
	bsr	getkey
	bra	menu
.q:	bsr	hw_save
quit:	moveq	#0,d0
	bra	sys_exit

; ---------------------------------------------------------------- menu
menu_show:
	move.b	#1,con_mode
	bsr	con_cls
	lea	m_menu,a0
	bsr	put_s
	rts

; ---------------------------------------------------------------- report file
; Q: write HWCHECK.TXT in the current folder; on failure ask for another try
hw_save:
	move.b	#1,con_mode
.again:	bsr	con_cls
	lea	m_saving,a0
	bsr	put_s
	lea	fn_rep,a0
	lea	hw_rep,a1
	move.l	hw_repp,d0
	sub.l	a1,d0
	bsr	fil_save
	bcs.s	.err
	lea	m_saved,a0
	bsr	put_s
	moveq	#100,d3			; 2 s at 50 Hz (less at 60) to read it
.w:	bsr	vid_vsync
	dbf	d3,.w
	rts
.err:	lea	m_saveerr,a0
	bsr	put_s
	bsr	getkey
	cmp.b	#27,d0
	bne.s	.again
	rts

; ---------------------------------------------------------------- 0: the machine
hw_info:
	bsr	con_cls
	lea	m_title,a0
	bsr	put_s
	; machine from the cookie jar
	lea	m_mach,a0
	bsr	put_s
	move.l	#'_MCH',d0
	bsr	cookie
	bcc.s	.mc
	lea	m_noj,a0		; no jar: a plain ST (TOS < 1.6)
	bsr	put_s
	bra.s	.tos
.mc:	move.l	d0,hw_mch
	lea	m_ste,a0
	cmp.l	#$00010000,d0
	beq.s	.mn
	lea	m_mste,a0
	cmp.l	#$00010010,d0
	beq.s	.mn
	lea	m_stbook,a0
	cmp.l	#$00010008,d0
	beq.s	.mn
	lea	m_st,a0
	tst.l	d0
	beq.s	.mn
	lea	m_other,a0
.mn:	bsr	put_s
	lea	m_mch1,a0
	bsr	put_s
	move.l	hw_mch,d0
	moveq	#8,d1
	bsr	put_hex
	moveq	#')',d0
	bsr	put_c
.tos:	bsr	put_nl
	lea	m_tos,a0		; TOS version, date, country
	bsr	put_s
	move.l	SYSBASE.w,a0
	move.l	8(a0),a3		; os_base: the ROM's header
	move.w	2(a3),d0
	move.w	d0,d3
	lsr.w	#8,d0
	bsr	put_hexn
	moveq	#'.',d0
	bsr	put_c
	moveq	#0,d0
	move.b	d3,d0
	moveq	#2,d1
	bsr	put_hex
	lea	m_tosd,a0
	bsr	put_s
	move.l	$18(a3),d3		; os_gendat: $MMDDYYYY
	move.l	d3,d0
	moveq	#4,d1
	bsr	put_hex			; YYYY
	moveq	#'-',d0
	bsr	put_c
	move.l	d3,d0
	swap	d0
	lsr.w	#8,d0
	moveq	#2,d1
	bsr	put_hex			; MM
	moveq	#'-',d0
	bsr	put_c
	move.l	d3,d0
	swap	d0
	moveq	#2,d1
	bsr	put_hex			; DD
	lea	m_tosc,a0
	bsr	put_s
	move.w	$1c(a3),d0		; os_palmode: country << 1 | PAL
	lsr.w	#1,d0
	and.w	#$7f,d0
	cmp.w	#9,d0
	bls.s	.cn
	moveq	#10,d0
.cn:	lsl.w	#2,d0
	lea	m_countries,a0
	add.w	d0,a0
	bsr	put_s
	bsr	put_nl
	; RAM, refresh
	lea	m_ram,a0
	bsr	put_s
	move.l	$42e.w,d0		; phystop
	moveq	#10,d1
	lsr.l	d1,d0
	bsr	put_dec
	lea	m_kb,a0
	bsr	put_s
	lea	m_60,a0
	btst	#1,VID_SYNC.w
	beq.s	.hz
	lea	m_50,a0
.hz:	bsr	put_s
	; CPU speed
	lea	m_cpu,a0
	bsr	put_s
	bsr	cpu_count
	move.l	d0,hw_cpun
	mulu	#80,d0			; MHz x 10 against the 8 MHz calibration (d0 < 65536)
	move.l	#CPU_K8,d1
	bsr	udiv
	move.l	d0,hw_mhz
	bsr	put_fix1
	lea	m_mhz,a0
	bsr	put_s
	move.l	hw_cpun,d0
	bsr	put_dec
	moveq	#')',d0
	bsr	put_c
	bsr	put_nl
	cmp.l	#$00010010,hw_mch	; Mega STE: the speed/cache register
	bne.s	.nm
	lea	m_8e21,a0
	bsr	put_s
	moveq	#0,d0
	move.b	$ffff8e21.w,d0
	moveq	#2,d1
	bsr	put_hex
	bsr	put_nl
.nm:	lea	m_from,a0		; where it runs
	bsr	put_s
	GEMDOS	$19,2			; Dgetdrv
	add.b	#'A',d0
	bsr	put_c
	moveq	#':',d0
	bsr	put_c
	clr.w	-(sp)			; Dgetpath(buf, 0)
	pea	hw_path
	GEMDOS	$47,8
	lea	hw_path,a0
	tst.b	(a0)
	bne.s	.p
	lea	m_bs,a0
.p:	bsr	put_s
	bsr	put_nl
	lea	m_pool,a0
	bsr	put_s
	bsr	mem_free
	moveq	#10,d1
	lsr.l	d1,d0
	bsr	put_dec
	lea	m_kb,a0
	bsr	put_s
	bsr	put_nl
	; what is beside it
	bsr	find_music
	lea	m_music,a0
	bsr	put_s
	tst.b	hw_rawname
	bne.s	.hm
	lea	m_none,a0
	bsr	put_s
	bra.s	.m2
.hm:	lea	hw_rawname,a0
	bsr	put_s
	lea	m_rate,a0
	bsr	put_s
	move.l	hw_rawrate,d0
	bsr	put_dec
	lea	m_hz,a0
	bsr	put_s
.m2:	bsr	put_nl
	lea	fn_mod,a0
	bsr	fil_size
	lea	m_nomod,a0
	bcs.s	.m3
	lea	m_mod,a0
.m3:	bsr	put_s
	bsr	put_nl
	lea	m_mouse,a0		; screen only
	move.b	#1,con_mode
	bsr	put_s
	move.b	#3,con_mode
	bsr	getkey
	rts

; the cookie d0.l: d0.l = its value, carry set if there is no jar or no such cookie
cookie:	move.l	$5a0.w,d1
	beq.s	.no
	move.l	d1,a0
.l:	move.l	(a0)+,d1
	beq.s	.no
	move.l	(a0)+,d2
	cmp.l	d0,d1
	bne.s	.l
	move.l	d2,d0
	and.b	#$fe,ccr
	rts
.no:	or.b	#1,ccr
	rts

; the busy loop's count in 0.5 s with the kernel's interrupts running (VBL, Timer B, Timer C)
; out: d0.l   trashes: d0-d2
cpu_count:
	move.l	HZ200.w,d1
.e:	cmp.l	HZ200.w,d1		; start on a tick
	beq.s	.e
	move.l	HZ200.w,d1
	add.l	#100,d1
	moveq	#0,d2
.l:	move.w	#99,d0
.i:	dbf	d0,.i
	addq.l	#1,d2
	cmp.l	HZ200.w,d1
	bhi.s	.l
	move.l	d2,d0
	rts

; MUSIC\*.RAW: hw_rawname ("MUSIC\NAME.RAW"), hw_modname ("SOUND\NAME.MOD"), hw_rawrate;
; hw_rawname[0] = 0 when there is none   trashes: d0-d2/a0-a2
find_music:
	clr.b	hw_rawname
	pea	hw_dta			; Fsetdta
	GEMDOS	$1a,6
	clr.w	-(sp)			; Fsfirst("MUSIC\\GAME.RAW"): the bridge's song, else any
	pea	fn_rawgame
	GEMDOS	$4e,8
	tst.l	d0
	beq.s	.fd
	clr.w	-(sp)			; Fsfirst("MUSIC\\*.RAW", 0)
	pea	fn_rawpat
	GEMDOS	$4e,8
	tst.l	d0
	bne	.x
.fd:
	lea	hw_rawname,a1
	lea	s_music,a0
	bsr	strcpy
	lea	hw_dta+30,a0
	bsr	strcpy
	lea	hw_modname,a1		; SOUND\ + the name + .MOD
	lea	s_sound,a0
	bsr	strcpy
	lea	hw_dta+30,a0
.n:	move.b	(a0)+,d0
	cmp.b	#'.',d0
	beq.s	.d
	move.b	d0,(a1)+
	bne.s	.n
	subq.l	#1,a1
.d:	lea	s_dotmod,a0
	bsr	strcpy
	clr.w	-(sp)			; the header's rate: Fopen, Fread 32, Fclose
	pea	hw_rawname
	GEMDOS	GD_FOPEN,8
	tst.l	d0
	bmi.s	.x
	move.w	d0,-(sp)		; (the handle stays on the stack for Fclose)
	pea	hw_hdr
	pea	32.w
	move.w	d0,-(sp)
	GEMDOS	GD_FREAD,12
	GEMDOS	GD_FCLOSE,4
	moveq	#0,d0			; 'ISMU', w version, w rate (snd.s st_open)
	move.w	hw_hdr+6,d0
	move.l	d0,hw_rawrate
.x:	rts

; a0 -> a1 (C string), a1 left on the 0   trashes: a0-a1
strcpy:	move.b	(a0)+,(a1)+
	bne.s	strcpy
	subq.l	#1,a1
	rts

; ---------------------------------------------------------------- the common run loop
; hw_run: d0.w = seconds, d1.w = RUN_LOAD | RUN_POLL; Esc aborts (hw_abort). The progress line
; counts down. out: d0.l = busy-loop passes done   trashes: d0-d2/a0-a2
hw_run:
	movem.l	d3-d7/a3-a4,-(sp)
	move.w	d1,d7
	moveq	#0,d6			; passes
	clr.w	hw_abort
	moveq	#0,d5
	move.w	d0,d5			; seconds left
	move.l	HZ200.w,d4
	mulu	#200,d0
	add.l	d4,d0
	move.l	d0,hw_tend
	move.l	d4,hw_tsec
	bsr	prog_show
.loop:	btst	#0,d7
	beq.s	.nl
	bsr	hw_load
	addq.l	#1,d6
.nl:	btst	#1,d7
	beq.s	.np
	bsr	hw_poll
.np:	move.l	HZ200.w,d0
	sub.l	hw_tsec,d0
	cmp.l	#200,d0
	blo.s	.ns
	add.l	#200,hw_tsec
	subq.w	#1,d5
	bsr	prog_show
	move.w	#2,-(sp)		; Esc?
	BIOS	BI_BCONSTAT,4
	tst.w	d0
	beq.s	.ns
	move.w	#2,-(sp)
	BIOS	BI_BCONIN,4
	cmp.b	#27,d0
	bne.s	.ns
	move.w	#1,hw_abort
	bra.s	.x
.ns:	move.l	HZ200.w,d0
	cmp.l	hw_tend,d0
	blo.s	.loop
.x:	move.l	d6,d0
	movem.l	(sp)+,d3-d7/a3-a4
	rts

; d5.w = seconds left on the progress line (screen only)   trashes: d0-d2/a0-a2
prog_show:
	move.l	con_col,-(sp)		; (col and row)
	move.b	con_mode,-(sp)
	move.b	#1,con_mode
	moveq	#ROW_PROG,d1
	bsr	con_clrrow
	moveq	#2,d0
	moveq	#ROW_PROG,d1
	bsr	con_at
	moveq	#0,d0
	move.w	d5,d0
	bsr	put_dec
	lea	m_left,a0
	bsr	put_s
	move.b	(sp)+,con_mode
	move.l	(sp)+,con_col
	rts

; one pass of CPU load like the game's: a screen-like copy by movem.l (12 registers) and
; divisions (the longest instructions: they delay interrupts most)   trashes: d0-d2/a0-a2
hw_load:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	hw_lbuf,a0
	lea	LOADBUF(a0),a1
	move.w	#LOADBUF/44-1,d7	; (a6 = GS stays: 11 registers)
.c:	movem.l	(a0)+,d0-d6/a2-a5
	movem.l	d0-d6/a2-a5,(a1)
	lea	44(a1),a1
	dbf	d7,.c
	moveq	#16-1,d7
	move.l	#123456789,d0
.d:	divu	#7,d0
	divs	#-3,d0
	ext.l	d0
	add.l	#987654,d0
	dbf	d7,.d
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; snd_poll, timed: the reads it does and the splits during them go to the "during reads" set
; trashes: d0-d2/a0-a2
hw_poll:
	tst.w	st_on			; will it read? (snd_poll's own test)
	beq.s	.x
	tst.w	st_eof
	bne.s	.x
	move.l	st_wr,d0
	sub.l	st_rd,d0
	cmp.l	#ST_RING-ST_CHUNK,d0
	bhi.s	.full
	move.l	HZ200.w,-(sp)
	move.w	#TBS_SIZE,vid_tbsel
	bsr	snd_poll
	clr.w	vid_tbsel
	move.l	HZ200.w,d0
	sub.l	(sp)+,d0
	add.l	d0,hw_rdt
	cmp.l	hw_rdmax,d0
	bls.s	.x
	move.l	d0,hw_rdmax
.x:	rts
.full:	tst.l	hw_filled		; the ring is full for the first time: from here on its
	bne.s	.x			; lowest level shows whether the reads keep up
	move.l	HZ200.w,d0
	sub.l	hw_t0,d0
	addq.l	#1,d0
	move.l	d0,hw_filled
	move.l	#$7fffffff,st_minf
	rts

; Timer B statistics cleared   trashes: d0/a0
tb_clear:
	DI
	lea	vid_tbst,a0
	moveq	#2*TBS_SIZE/2-1,d0
.c:	clr.w	(a0)+
	dbf	d0,.c
	clr.w	vid_tbsel
	EI
	rts

; one set of split statistics as a report line: a0 = the set (vid_tbst or +TBS_SIZE), a1 = label
; "  label: N splits, all on time" / "..., L late (B by 16+ pixels, latest +P pixels), I with the
; interrupt itself late"   trashes: d0-d2/a0-a2
tb_line:
	move.l	a3,-(sp)
	move.l	a0,a3
	lea	m_ind,a0
	bsr	put_s
	move.l	a1,a0
	bsr	put_s
	move.l	TBS_N(a3),d0
	bsr	put_dec
	lea	m_splits,a0
	bsr	put_s
	tst.l	TBS_N(a3)
	beq.s	.x
	tst.l	TBS_LATE(a3)
	bne.s	.late
	lea	m_ontime,a0
	bsr	put_s
	bra.s	.ent
.late:	lea	m_comma,a0
	bsr	put_s
	move.l	TBS_LATE(a3),d0
	bsr	put_dec
	lea	m_late,a0
	bsr	put_s
	move.l	TBS_BIG(a3),d0
	bsr	put_dec
	lea	m_late16,a0
	bsr	put_s
	move.l	TBS_MAX(a3),d0
	add.l	d0,d0			; bytes -> pixels
	bsr	put_dec
	lea	m_latepx,a0
	bsr	put_s
.ent:	tst.l	TBS_ENT(a3)
	beq.s	.x
	lea	m_comma,a0
	bsr	put_s
	move.l	TBS_ENT(a3),d0
	bsr	put_dec
	lea	m_ent,a0
	bsr	put_s
.x:	bsr	put_nl
	move.l	(sp)+,a3
	rts

; the verdict for a set: a0 = the set   trashes: d0-d2/a0-a2
tb_verdict:
	lea	m_ind,a1
	tst.l	TBS_N(a0)
	beq.s	.x
	tst.l	TBS_LATE(a0)
	beq.s	.ok
	tst.l	TBS_BIG(a0)
	bne.s	.bad
	lea	m_vminor,a0
	bra.s	.p
.ok:	lea	m_vok,a0
	bra.s	.p
.bad:	lea	m_vbad,a0
.p:	move.l	a0,-(sp)
	move.l	a1,a0
	bsr	put_s
	move.l	(sp)+,a0
	bsr	put_s
.x:	rts

; ---------------------------------------------------------------- 1: splits
t_splits:
	bsr	con_cls
	lea	m_t1,a0
	bsr	put_s
	move.b	#1,con_mode
	lea	m_t1h,a0
	bsr	put_s
	move.b	#3,con_mode
	bsr	tb_clear
	moveq	#20,d0
	moveq	#RUN_LOAD,d1
	bsr	hw_run
	move.l	d0,hw_base		; passes with no sound: the CPU baseline
	tst.w	hw_abort
	bne.s	.ab
	lea	vid_tbst,a0
	lea	m_lbusy,a1
	bsr	tb_line
	lea	vid_tbst,a0
	bsr	tb_verdict
	rts
.ab:	clr.l	hw_base
	lea	m_aborted,a0
	bra	put_s

; ---------------------------------------------------------------- 2: the mixer
t_mixer:
	bsr	con_cls
	lea	m_t2,a0
	bsr	put_s
	bsr	mem_mark
	move.l	d0,-(sp)
	lea	fn_mod,a0
	bsr	fil_size
	bcs	.nomod
	move.l	d0,d3
	bsr	mem_alloc
	bcs	.nomod
	move.l	a0,a3
	lea	fn_mod,a0
	move.l	a3,a1
	move.l	d3,d0
	bsr	fil_load
	bcs	.nomod
	move.w	snd_defrate,d0		; the mixer's own rate (6258 Hz)
	bsr	snd_set_rate
	move.l	a3,a0
	bsr	mod_init
	bcs	.nomod
	bsr	mod_start
	bsr	snd_cpu
	move.l	d0,d4
	bsr	tb_clear
	moveq	#20,d0
	moveq	#RUN_LOAD,d1
	bsr	hw_run
	move.l	d0,d3
	bsr	snd_cpu
	sub.l	d4,d0
	move.l	d0,d4			; ticks spent mixing
	bsr	mod_stop
	tst.w	hw_abort
	bne	.ab
	lea	vid_tbst,a0
	lea	m_lmix,a1
	bsr	tb_line
	lea	vid_tbst,a0
	bsr	tb_verdict
	lea	m_mixcpu,a0		; the mixer's share of the CPU: ticks spent / 4000
	bsr	put_s
	move.l	d4,d0
	mulu	#10,d0
	move.l	#4000/100,d1
	bsr	udiv
	bsr	put_fix1
	lea	m_pct,a0
	bsr	put_s
	tst.l	hw_base			; free CPU against test 1
	beq.s	.nb
	lea	m_free,a0
	bsr	put_s
	move.l	d3,d0
	mulu	#1000,d0		; (passes < 65536)
	move.l	hw_base,d1
	bsr	udiv
	bsr	put_fix1
	lea	m_free2,a0
	bsr	put_s
.nb:	bsr	put_nl
	bra.s	.x
.nomod:	lea	m_nomod2,a0
	bsr	put_s
	bra.s	.x
.ab:	lea	m_aborted,a0
	bsr	put_s
.x:	move.l	(sp)+,d0
	bsr	mem_release
	rts

; ---------------------------------------------------------------- 3: disk read speed
t_disk:
	bsr	con_cls
	lea	m_t3,a0
	bsr	put_s
	lea	hw_rawname,a0		; the file: a stream file, else the largest of DATA\
	tst.b	(a0)
	bne.s	.f
	lea	fn_datapat,a0
	lea	s_data,a1
	bsr	find_largest
	bcs	.none
	lea	hw_bigname,a0
.f:	move.l	a0,hw_rfile
	lea	m_file,a0
	bsr	put_s
	move.l	hw_rfile,a0
	bsr	put_s
	bsr	put_nl
	move.l	#16384,d0
	bsr	read_pass
	tst.w	hw_abort
	bne.s	.ab
	move.l	#65536,d0
	bsr	read_pass
	tst.w	hw_abort
	bne.s	.ab
	rts
.none:	lea	m_nofile,a0
	bra	put_s
.ab:	lea	m_aborted,a0
	bra	put_s

; one pass over hw_rfile in reads of d0.l bytes: RD_LIMIT bytes (from the start again at the end)
; or RD_TIME, Esc aborts; the report line   trashes: d0-d2/a0-a2
read_pass:
	movem.l	d3-d7/a3,-(sp)
	move.l	d0,d7			; chunk
	moveq	#0,d6			; bytes
	moveq	#0,d5			; ticks inside Fread
	moveq	#0,d4			; slowest read
	clr.w	hw_abort
	bsr	tb_clear
	clr.w	-(sp)
	move.l	hw_rfile,-(sp)
	GEMDOS	GD_FOPEN,8
	tst.l	d0
	bmi	.err
	move.w	d0,d3
	move.l	HZ200.w,a3
	lea	RD_TIME(a3),a3		; give up after this
.rd:	move.l	HZ200.w,-(sp)
	move.w	#TBS_SIZE,vid_tbsel
	move.l	hw_rbuf,-(sp)		; Fread(h, chunk, buf)
	move.l	d7,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FREAD,12
	clr.w	vid_tbsel
	move.l	HZ200.w,d1
	sub.l	(sp)+,d1
	tst.l	d0
	bmi	.rerr
	add.l	d1,d5
	cmp.l	d4,d1
	bls.s	.m
	move.l	d1,d4
.m:	add.l	d0,d6
	cmp.l	d7,d0
	beq.s	.more
	clr.w	-(sp)			; the end: from the start again
	move.w	d3,-(sp)
	clr.l	-(sp)
	GEMDOS	GD_FSEEK,10
.more:	move.w	#2,-(sp)		; Esc?
	BIOS	BI_BCONSTAT,4
	tst.w	d0
	beq.s	.ne
	move.w	#2,-(sp)
	BIOS	BI_BCONIN,4
	cmp.b	#27,d0
	bne.s	.ne
	move.w	#1,hw_abort
	bra.s	.cl
.ne:	cmp.l	#RD_LIMIT,d6
	bhs.s	.cl
	cmp.l	HZ200.w,a3
	bhi	.rd
.cl:	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
	tst.w	hw_abort
	bne	.x
	lea	m_ind,a0		; "  16 KB reads: 2048 KB in 2.3 s = 890.4 KB/s, slowest read 35 ms"
	bsr	put_s
	move.l	d7,d0
	moveq	#10,d1
	lsr.l	d1,d0
	bsr	put_dec
	lea	m_kbreads,a0
	bsr	put_s
	move.l	d6,d0
	moveq	#10,d1
	lsr.l	d1,d0
	bsr	put_dec
	lea	m_kbin,a0
	bsr	put_s
	move.l	d5,d0			; ticks -> s x 10: /20
	moveq	#20,d1
	bsr	udiv
	bsr	put_fix1
	lea	m_s,a0
	bsr	put_s
	tst.l	d5
	beq.s	.fast
	lea	m_eq,a0
	bsr	put_s
	move.l	d6,d0			; KB/s x 10 = bytes / 1024 * 2000 / ticks
	moveq	#10,d1
	lsr.l	d1,d0
	move.l	#2000,d1
	bsr	umul
	move.l	d5,d1
	bsr	udiv
	bsr	put_fix1
	lea	m_kbs,a0
	bsr	put_s
	bra.s	.sl
.fast:	lea	m_tofast,a0
	bsr	put_s
.sl:	lea	m_slow,a0
	bsr	put_s
	move.l	d4,d0
	mulu	#5,d0
	bsr	put_dec
	lea	m_ms,a0
	bsr	put_s
	bsr	put_nl
	lea	vid_tbst+TBS_SIZE,a0
	lea	m_lduring,a1
	bsr	tb_line
	lea	vid_tbst+TBS_SIZE,a0
	bsr	tb_verdict
	bra.s	.x
.rerr:	move.l	d0,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
	move.l	(sp)+,d0
.err:	move.l	d0,-(sp)
	lea	m_rerr,a0
	bsr	put_s
	move.l	(sp)+,d0
	neg.l	d0
	bsr	put_dec
	bsr	put_nl
.x:	movem.l	(sp)+,d3-d7/a3
	rts

; the largest file matching a0 (a pattern), its name = a1 (folder prefix) + the file's name in
; hw_bigname, size in hw_bigsize; carry set if none   trashes: d0-d2/a0-a2
find_largest:
	movem.l	d3/a3,-(sp)
	move.l	a1,a3
	clr.l	hw_bigsize
	clr.b	hw_bigname
	move.l	a0,-(sp)
	pea	hw_dta
	GEMDOS	$1a,6
	move.l	(sp)+,a0
	clr.w	-(sp)
	move.l	a0,-(sp)
	GEMDOS	$4e,8			; Fsfirst
.l:	tst.l	d0
	bne.s	.e
	move.l	hw_dta+26,d0
	cmp.l	hw_bigsize,d0
	bls.s	.n
	move.l	d0,hw_bigsize
	lea	hw_bigname,a1
	move.l	a3,a0
	bsr	strcpy
	lea	hw_dta+30,a0
	bsr	strcpy
.n:	GEMDOS	$4f,2			; Fsnext
	bra.s	.l
.e:	movem.l	(sp)+,d3/a3
	tst.l	hw_bigsize
	beq.s	.no
	and.b	#$fe,ccr
	rts
.no:	or.b	#1,ccr
	rts

; ---------------------------------------------------------------- 4: the stream
t_stream:
	bsr	con_cls
	lea	m_t4,a0
	bsr	put_s
	tst.b	hw_rawname
	beq	.none
	cmp.l	#MOD_REGION,mod_rsize	; (started from an Iron Seed floppy: no ring)
	blo	.none
	lea	m_file,a0
	bsr	put_s
	lea	hw_rawname,a0
	bsr	put_s
	bsr	put_nl
	DI
	move.l	#$7fffffff,st_minf
	clr.l	st_under
	clr.l	st_reads
	clr.w	st_errs
	EI
	clr.l	hw_rdt
	clr.l	hw_rdmax
	clr.l	hw_filled
	move.l	HZ200.w,hw_t0
	bsr	tb_clear
	lea	hw_modname,a0		; the kernel finds MUSIC\NAME.RAW for it
	bsr	mod_load
	bcs	.err
	tst.w	st_on
	beq	.err
	bsr	snd_cpu
	move.l	d0,d4
	move.l	#40,d0
	moveq	#RUN_LOAD|RUN_POLL,d1
	bsr	hw_run
	move.l	d0,d3
	bsr	snd_cpu
	sub.l	d4,d0
	move.l	d0,d4
	bsr	mod_stop
	tst.w	hw_abort
	bne	.ab
	moveq	#0,d1			; bytes a second: rate * 2
	move.w	#12517*2,d1
	tst.w	snd_rate
	beq.s	.r
	move.w	#6258*2,d1
.r:	move.l	d1,hw_bps
	lea	m_fill,a0		; "ring (holds 83.7 s) filled in 3.1 s, then never below 80.1 s"
	bsr	put_s
	move.l	#ST_RING,d0
	move.l	hw_bps,d1
	bsr	sec10
	bsr	put_fix1
	tst.l	hw_filled
	bne.s	.fl
	lea	m_nofill,a0		; never full: the lowest level over the whole run
	bsr	put_s
	bra.s	.lo
.fl:	lea	m_fill2,a0
	bsr	put_s
	move.l	hw_filled,d0		; ticks -> s x 10
	moveq	#20,d1
	bsr	udiv
	bsr	put_fix1
	lea	m_fill3,a0
	bsr	put_s
.lo:	move.l	st_minf,d0
	move.l	hw_bps,d1
	bsr	sec10
	bsr	put_fix1
	lea	m_ringof2,a0
	bsr	put_s
	move.l	st_under,d0
	bsr	put_dec
	lea	m_under,a0
	bsr	put_s
	bsr	put_nl
	lea	m_reads,a0
	bsr	put_s
	move.l	st_reads,d0
	bsr	put_dec
	lea	m_reads2,a0
	bsr	put_s
	move.l	hw_rdt,d0
	mulu	#5,d0
	bsr	put_dec
	lea	m_reads3,a0
	bsr	put_s
	move.l	hw_rdmax,d0
	mulu	#5,d0
	bsr	put_dec
	lea	m_ms,a0
	bsr	put_s
	move.w	st_errs,d0
	beq.s	.ne
	lea	m_rerrs,a0
	bsr	put_s
	moveq	#0,d0
	move.w	st_errs,d0
	bsr	put_dec
.ne:	bsr	put_nl
	lea	vid_tbst,a0
	lea	m_lbetween,a1
	bsr	tb_line
	lea	vid_tbst+TBS_SIZE,a0
	lea	m_lduring,a1
	bsr	tb_line
	lea	vid_tbst,a0		; the verdict: the worse of the two
	move.l	TBS_BIG+TBS_SIZE(a0),d0
	add.l	d0,TBS_BIG(a0)
	move.l	TBS_LATE+TBS_SIZE(a0),d0
	add.l	d0,TBS_LATE(a0)
	move.l	TBS_N+TBS_SIZE(a0),d0
	add.l	d0,TBS_N(a0)
	bsr	tb_verdict
	lea	m_strcpu,a0
	bsr	put_s
	move.l	d4,d0
	mulu	#10,d0
	move.l	#8000/100,d1
	bsr	udiv
	bsr	put_fix1
	lea	m_pct,a0
	bsr	put_s
	tst.l	hw_base
	beq.s	.nb
	lea	m_free,a0
	bsr	put_s
	move.l	d3,d0
	mulu	#1000,d0
	move.l	hw_base,d1
	add.l	d1,d1			; 40 s against 20
	bsr	udiv
	bsr	put_fix1
	lea	m_free2,a0
	bsr	put_s
.nb:	bsr	put_nl
	tst.l	st_under
	bne.s	.vbad
	lea	m_ind,a0
	bsr	put_s
	lea	m_vstr,a0
	bra	put_s
.vbad:	lea	m_ind,a0
	bsr	put_s
	lea	m_vstrb,a0
	bra	put_s
.none:	lea	m_nomusic,a0
	bra	put_s
.err:	lea	m_strerr,a0
	bra	put_s
.ab:	lea	m_aborted,a0
	bra	put_s

; d0.l bytes, d1.l bytes a second -> d0.l = seconds x 10   trashes: d0-d2
sec10:	move.l	d1,-(sp)
	moveq	#10,d1
	bsr	umul
	move.l	(sp)+,d1
	bra	udiv

; ---------------------------------------------------------------- 5: keyboard
KEYS	equ	10			; checklist entries: name, kind, code
K_EXT	equ	0			; the game gets 0 then this code (kbd_readkey)
K_ASC	equ	1			; this character with this raw scan code
t_keys:
	bsr	con_cls
	move.b	#1,con_mode
	lea	m_t5,a0
	bsr	put_s
	lea	hw_kseen,a0
	moveq	#KEYS-1,d0
.z:	clr.b	(a0)+
	dbf	d0,.z
	bsr	keys_list
.l:	bsr	vid_vsync
	move.w	#2,-(sp)
	BIOS	BI_BCONSTAT,4
	tst.w	d0
	beq.s	.l
	move.w	#1,-(sp)		; Iorec(keyboard): the raw long about to be read
	XBIOS	14,4
	move.l	d0,a0
	move.l	(a0),a1			; ibuf
	moveq	#0,d0
	move.w	6(a0),d0		; ibufhd
	addq.w	#4,d0
	cmp.w	4(a0),d0		; ibufsiz
	blo.s	.h
	moveq	#0,d0
.h:	move.l	0(a1,d0.w),hw_kraw
	move.w	#-1,-(sp)
	BIOS	BI_KBSHIFT,4
	move.b	d0,hw_kshift
	bsr	kbd_readkey		; what the game gets
	moveq	#0,d1
	move.b	d0,d1
	moveq	#0,d2			; ext flag
	tst.b	d0
	bne.s	.got
	bsr	kbd_readkey
	moveq	#0,d1
	move.b	d0,d1
	moveq	#1,d2
.got:	move.w	d1,hw_kcode
	move.w	d2,hw_kext
	; tick the checklist
	lea	k_table,a0
	lea	hw_kseen,a1
	moveq	#KEYS-1,d0
.t:	move.b	1(a0),d1		; kind
	move.b	2(a0),d2		; code
	tst.b	d1
	bne.s	.ta
	tst.w	hw_kext
	beq.s	.tn
	cmp.b	hw_kcode+1,d2
	bne.s	.tn
	bra.s	.ty
.ta:	tst.w	hw_kext
	bne.s	.tn
	cmp.b	hw_kcode+1,d2
	bne.s	.tn
	move.b	hw_kraw+1,d1		; raw scan code
	cmp.b	3(a0),d1
	bne.s	.tn
.ty:	st	(a1)
.tn:	addq.l	#1,a1
	add.w	#K_SIZE,a0
	dbf	d0,.t
	bsr	keys_list
	lea	hw_kseen,a0		; all seen: done (after a second to see it)
	moveq	#KEYS-1,d0
.all:	tst.b	(a0)+
	dbeq	d0,.all
	beq.s	.esc
	moveq	#50,d3
.ws:	bsr	vid_vsync
	dbf	d3,.ws
	bra.s	.end
.esc:	tst.w	hw_kext			; Esc ends
	bne	.l
	cmp.w	#27,hw_kcode
	bne	.l
.end:
	; the report: which keys arrived as the game expects
	move.b	#2,con_mode
	lea	m_t5r,a0
	bsr	put_s
	lea	k_table,a3
	lea	hw_kseen,a4
	moveq	#KEYS-1,d3
	moveq	#0,d4			; missing
.r:	tst.b	(a4)+
	bne.s	.rn
	addq.w	#1,d4
.rn:	add.w	#K_SIZE,a3
	dbf	d3,.r
	tst.w	d4
	bne.s	.miss
	lea	m_kall,a0
	bsr	put_s
	bra.s	.rx
.miss:	lea	m_kmiss,a0
	bsr	put_s
	lea	k_table,a3
	lea	hw_kseen,a4
	moveq	#KEYS-1,d3
.m:	tst.b	(a4)+
	bne.s	.mn
	lea	K_NAME(a3),a0
	bsr	put_s
	moveq	#' ',d0
	bsr	put_c
.mn:	add.w	#K_SIZE,a3
	dbf	d3,.m
	bsr	put_nl
.rx:	move.b	#3,con_mode
	rts

; the checklist and the last key (screen only)   trashes: d0-d2/a0-a2
keys_list:
	movem.l	d3/a3-a4,-(sp)
	lea	k_table,a3
	lea	hw_kseen,a4
	moveq	#0,d3
.l:	moveq	#4,d0
	moveq	#4,d1
	add.w	d3,d1
	bsr	con_at
	lea	m_kno,a0
	tst.b	(a4)+
	beq.s	.n
	lea	m_kok,a0
.n:	bsr	put_s
	lea	K_NAME(a3),a0
	bsr	put_s
	add.w	#K_SIZE,a3
	addq.w	#1,d3
	cmp.w	#KEYS,d3
	bne.s	.l
	moveq	#16,d1			; the last key
	bsr	con_clrrow
	moveq	#17,d1
	bsr	con_clrrow
	tst.l	hw_kraw
	beq	.x
	moveq	#2,d0
	moveq	#16,d1
	bsr	con_at
	lea	m_kraw,a0
	bsr	put_s
	move.l	hw_kraw,d0		; scan code
	swap	d0
	moveq	#2,d1
	bsr	put_hex
	lea	m_kasc,a0
	bsr	put_s
	moveq	#0,d0
	move.b	hw_kraw+3,d0
	moveq	#2,d1
	bsr	put_hex
	lea	m_kshf,a0
	bsr	put_s
	moveq	#0,d0
	move.b	hw_kshift,d0
	moveq	#2,d1
	bsr	put_hex
	moveq	#2,d0
	moveq	#17,d1
	bsr	con_at
	lea	m_kgame,a0
	bsr	put_s
	lea	m_kext,a0
	tst.w	hw_kext
	bne.s	.e
	lea	m_kchr,a0
.e:	bsr	put_s
	moveq	#0,d0
	move.w	hw_kcode,d0
	bsr	put_dec
.x:	movem.l	(sp)+,d3/a3-a4
	rts

; ---------------------------------------------------------------- 6: floppy
t_floppy:
	bsr	con_cls
	lea	m_t6,a0
	bsr	put_s
	move.l	ETV_CRITIC.w,hw_oldcrit	; errors come back (no alert boxes), and the game's
	move.l	HDV_MEDIACH.w,hw_oldmc	; "disk changed" signal (flp.s) on demand
	move.l	#hw_critic,ETV_CRITIC.w
	move.l	#hw_mediach,HDV_MEDIACH.w
	clr.w	hw_force
	move.b	#1,con_mode
	lea	m_fins1,a0
	bsr	put_s
	move.b	#3,con_mode
	bsr	getkey
	cmp.b	#27,d0
	beq	.skip
	bsr	read_isdisk
	move.w	d0,hw_disk1
	bpl.s	.d1
	lea	m_fnodisk,a0
	bsr	put_s
	bra	.x
.d1:	lea	m_fdisk,a0
	bsr	put_s
	moveq	#0,d0
	move.w	hw_disk1,d0
	bsr	put_dec
	bsr	put_nl
	clr.b	hw_bigname		; the largest file on it: \DATA, \SOUND, the root
	clr.l	hw_bigsize
	lea	fn_adata,a0
	lea	s_adata,a1
	bsr	find_more
	lea	fn_asound,a0
	lea	s_asound,a1
	bsr	find_more
	lea	fn_aroot,a0
	lea	s_aroot,a1
	bsr	find_more
	tst.b	hw_bigname
	beq.s	.nf
	lea	hw_bigname,a0
	lea	hw_fname,a1
	bsr	strcpy
	lea	hw_fname,a0
	move.l	a0,hw_rfile
	lea	m_file,a0
	bsr	put_s
	lea	hw_fname,a0
	bsr	put_s
	bsr	put_nl
	move.l	#16384,d0		; the game reads files whole: a 16 KB pass is close enough
	bsr	read_pass
	tst.w	hw_abort
	bne	.x
	lea	m_fnosplit,a0		; the same with one band (no Timer B): do the splits cost
	bsr	put_s			; the drive anything?
	lea	hw_band1,a0
	bsr	vid_set_bands
	move.l	#16384,d0
	bsr	read_pass
	lea	hw_bands,a0
	bsr	vid_set_bands
	tst.w	hw_abort
	bne	.x
.nf:	move.b	#1,con_mode
	lea	m_fins2,a0
	bsr	put_s
	move.b	#3,con_mode
	bsr	getkey
	cmp.b	#27,d0
	beq	.x
	bsr	read_isdisk		; TOS's own media-change detection
	move.w	d0,hw_disk2
	lea	m_fchg,a0
	bsr	put_s
	move.w	hw_disk2,d0
	bmi.s	.f2
	cmp.w	hw_disk1,d0
	beq.s	.f2
	lea	m_fyes,a0		; noticed by itself
	bsr	put_s
	moveq	#0,d0
	move.w	hw_disk2,d0
	bsr	put_dec
	bsr	put_nl
	bra.s	.x
.f2:	move.w	#1,hw_force		; the game's way: "changed" once after its prompt
	bsr	read_isdisk
	move.w	d0,hw_disk3
	bmi.s	.f3
	cmp.w	hw_disk1,d0
	beq.s	.same
	lea	m_fno,a0
	bsr	put_s
	moveq	#0,d0
	move.w	hw_disk3,d0
	bsr	put_dec
	bsr	put_nl
	bra.s	.x
.same:	lea	m_fsame,a0
	bsr	put_s
	bra.s	.x
.f3:	lea	m_fnone2,a0
	bsr	put_s
	bra.s	.x
.skip:	lea	m_skipped,a0
	bsr	put_s
.x:	GEMDOS	$19,2			; started from drive A (the save disk): it back for the report
	tst.w	d0
	bne.s	.r
	move.b	#1,con_mode
	lea	m_fback,a0
	bsr	put_s
	bsr	getkey
	move.w	#1,hw_force
	move.b	#3,con_mode
.r:	move.l	hw_oldcrit,ETV_CRITIC.w
	move.l	hw_oldmc,HDV_MEDIACH.w
	rts

; A:\ISDISK.TAB's disk number: d0.w (1-15), -1 if none   trashes: d0-d2/a0-a2
read_isdisk:
	clr.l	hw_hdr
	clr.w	-(sp)
	pea	fn_isdisk
	GEMDOS	GD_FOPEN,8
	tst.l	d0
	bmi.s	.no
	move.w	d0,-(sp)		; (for Fclose)
	pea	hw_hdr
	pea	8.w
	move.w	d0,-(sp)
	GEMDOS	GD_FREAD,12
	GEMDOS	GD_FCLOSE,4
	cmp.l	#'ISD1',hw_hdr
	bne.s	.no
	move.w	hw_hdr+4,d0
	rts
.no:	moveq	#-1,d0
	rts

; like find_largest but keeps the best so far (hw_bigname/hw_bigsize)   trashes: d0-d2/a0-a2
find_more:
	movem.l	d3/a3,-(sp)
	move.l	a1,a3
	move.l	a0,-(sp)
	pea	hw_dta
	GEMDOS	$1a,6
	move.l	(sp)+,a0
	clr.w	-(sp)
	move.l	a0,-(sp)
	GEMDOS	$4e,8
.l:	tst.l	d0
	bne.s	.e
	move.l	hw_dta+26,d0
	cmp.l	hw_bigsize,d0
	bls.s	.n
	move.l	d0,hw_bigsize
	lea	hw_bigname,a1
	move.l	a3,a0
	bsr	strcpy
	lea	hw_dta+30,a0
	bsr	strcpy
.n:	GEMDOS	$4f,2
	bra.s	.l
.e:	movem.l	(sp)+,d3/a3
	rts

hw_critic:
	move.w	4(sp),d0
	ext.l	d0
	rts
hw_mediach:
	tst.w	4(sp)			; drive A only
	bne.s	.old
	tst.w	hw_force
	beq.s	.old
	clr.w	hw_force
	moveq	#2,d0			; changed
	rts
.old:	move.l	hw_oldmc,-(sp)
	rts

; ---------------------------------------------------------------- keys
; wait for a key: d0.b = its character in upper case (0 for keys without one)  trashes: d0-d2/a0-a2
getkey:
.f:	move.w	#2,-(sp)		; old keys away
	BIOS	BI_BCONSTAT,4
	tst.w	d0
	beq.s	.w
	move.w	#2,-(sp)
	BIOS	BI_BCONIN,4
	bra.s	.f
.w:	bsr	vid_vsync
	move.w	#2,-(sp)
	BIOS	BI_BCONSTAT,4
	tst.w	d0
	beq.s	.w
	move.w	#2,-(sp)
	BIOS	BI_BCONIN,4
	cmp.b	#'a',d0
	blo.s	.x
	cmp.b	#'z',d0
	bhi.s	.x
	sub.b	#32,d0
.x:	rts

; ---------------------------------------------------------------- arithmetic
; d0.l / d1.l unsigned -> d0.l quotient (d1 = 0: d0 = 0)   trashes: d1-d2
udiv:	movem.l	d3-d4,-(sp)
	tst.l	d1
	beq.s	.z
	moveq	#0,d2			; remainder
	moveq	#32-1,d3
.l:	add.l	d0,d0
	addx.l	d2,d2
	cmp.l	d1,d2
	blo.s	.n
	sub.l	d1,d2
	addq.l	#1,d0
.n:	dbf	d3,.l
	movem.l	(sp)+,d3-d4
	rts
.z:	moveq	#0,d0
	movem.l	(sp)+,d3-d4
	rts

; d0.l * d1.l (low 32 bits)   trashes: d1-d2
umul:	move.l	d3,-(sp)
	move.l	d0,d2
	mulu	d1,d2			; lo*lo
	move.l	d0,d3
	swap	d3
	mulu	d1,d3			; hi(a)*lo(b)
	swap	d1
	mulu	d0,d1			; lo(a)*hi(b)
	add.l	d3,d1
	swap	d1
	clr.w	d1
	add.l	d2,d1
	move.l	d1,d0
	move.l	(sp)+,d3
	rts

; ---------------------------------------------------------------- the console
; 40 x 25 characters of the 8x8 system font in plane 0 (colour 1) of the shown screen; a ruler
; of colour 15 at x 0-15 on every line shows the bands' first pixels (a late split shows there).
; Columns 2-39 hold text. con_mode: bit 0 the screen, bit 1 the report (CR LF).
con_init:
	dc.w	$a000			; Line-A: the 8x8 font
	move.l	4(a1),a0
	move.l	76(a0),con_font
	move.w	80(a0),con_fontw
	lea	hw_bands,a0
	bsr	vid_set_bands
	moveq	#16,d0
	bsr	vid_set_fade
	bra	con_cls

con_cls:
	move.l	vid_phys,a0
	bsr	vid_clear
	move.l	vid_phys,a0
	move.w	#SCR_H-1,d0
.r:	move.l	#-1,(a0)
	move.l	#-1,4(a0)
	lea	SCR_BPL(a0),a0
	dbf	d0,.r
	moveq	#2,d0
	moveq	#0,d1
	bra	con_at

; d0.w = column, d1.w = row   trashes: nothing else
con_at:	move.w	d0,con_col
	move.w	d1,con_row
	rts

; clear text row d1.w (columns 2-39)   trashes: d0-d2/a0
con_clrrow:
	move.l	vid_phys,a0
	mulu	#8*SCR_BPL,d1
	add.l	d1,a0
	moveq	#8-1,d1
.r:	lea	8(a0),a1
	moveq	#19-1,d0
.c:	clr.w	(a1)
	addq.l	#8,a1
	dbf	d0,.c
	lea	SCR_BPL(a0),a0
	dbf	d1,.r
	rts

put_nl:	moveq	#10,d0
	; fall through
; d0.b = character (10 = new line)   keeps every register
put_c:	movem.l	d0-d2/a0-a2,-(sp)
	btst	#1,con_mode
	beq.s	.scr
	move.l	hw_repp,a0
	cmp.l	#hw_rep+REPMAX-2,a0
	bhs.s	.scr
	cmp.b	#10,d0
	bne.s	.rc
	move.b	#13,(a0)+
.rc:	move.b	d0,(a0)+
	move.l	a0,hw_repp
.scr:	btst	#0,con_mode
	beq.s	.x
	cmp.b	#10,d0
	beq.s	.nl
	move.w	con_col,d1
	cmp.w	#40,d1
	blo.s	.in
	bsr	.nlscr			; wrap (screen only), indented
	move.w	#6,con_col
	move.w	con_col,d1
.in:
	move.w	con_row,d2
	mulu	#8*SCR_BPL,d2
	move.l	vid_phys,a2
	add.l	d2,a2
	move.w	d1,d2			; column -> byte: (c/2)*8 + (c&1)
	lsr.w	#1,d2
	lsl.w	#3,d2
	btst	#0,d1
	beq.s	.e
	addq.w	#1,d2
.e:	add.w	d2,a2
	move.l	con_font,a1
	and.w	#$ff,d0
	add.w	d0,a1
	moveq	#8-1,d2
.r:	move.b	(a1),(a2)
	add.w	con_fontw,a1
	lea	SCR_BPL(a2),a2
	dbf	d2,.r
	addq.w	#1,con_col
.x:	movem.l	(sp)+,d0-d2/a0-a2
	rts
.nl:	bsr.s	.nlscr
	bra.s	.x
.nlscr:	move.w	#2,con_col		; next row (scrolls)   trashes: d1/a0-a1
	addq.w	#1,con_row
	cmp.w	#25,con_row
	blo.s	.nr
	move.w	#24,con_row		; scroll up one text row (rows 0-23 <- 1-24)
	move.l	vid_phys,a0
	lea	8*SCR_BPL(a0),a1
	move.w	#(24*8*SCR_BPL)/4-1,d1
.s:	move.l	(a1)+,(a0)+
	dbf	d1,.s
	movem.l	d0/d2,-(sp)
	moveq	#24,d1
	bsr	con_clrrow
	movem.l	(sp)+,d0/d2
.nr:	rts

; a0 = C string   trashes: a0
put_s:	move.l	d0,-(sp)
.l:	move.b	(a0)+,d0
	beq.s	.x
	bsr	put_c
	bra.s	.l
.x:	move.l	(sp)+,d0
	rts

; d0.l unsigned decimal   trashes: d0-d2/a0
put_dec:
	lea	con_num+12,a0
	clr.b	-(a0)
.l:	moveq	#0,d2			; d0 / 10 (32 bits by two divu)
	swap	d0
	move.w	d0,d2
	divu	#10,d2
	move.w	d2,d0
	swap	d0
	move.w	d0,d2
	divu	#10,d2
	move.w	d2,d0
	swap	d2
	add.b	#'0',d2
	move.b	d2,-(a0)
	tst.l	d0
	bne.s	.l
	bra	put_s

; d0.l = tenths: "12.3"   trashes: d0-d2/a0
put_fix1:
	moveq	#10,d1
	move.l	d0,-(sp)
	bsr	udiv
	bsr	put_dec
	moveq	#'.',d0
	bsr	put_c
	move.l	(sp)+,d0
	move.l	d0,d1			; d0 mod 10
	moveq	#10,d2
.m:	cmp.l	d2,d1
	blo.s	.d
	sub.l	d2,d1
	bra.s	.m
.d:	move.b	d1,d0
	add.b	#'0',d0
	bra	put_c

; d0.l in d1.w hex digits   trashes: d0-d2/a0
put_hex:
	lea	con_num+12,a0
	clr.b	-(a0)
	subq.w	#1,d1
.l:	move.b	d0,d2
	and.b	#15,d2
	add.b	#'0',d2
	cmp.b	#'9',d2
	bls.s	.d
	addq.b	#7,d2
.d:	move.b	d2,-(a0)
	lsr.l	#4,d0
	dbf	d1,.l
	bra	put_s
; d0.b as hex without a leading zero (TOS's major version)   trashes: d0-d2/a0
put_hexn:
	moveq	#1,d1
	cmp.b	#16,d0
	blo	put_hex
	moveq	#2,d1
	bra	put_hex

	include	"kernel.s"


	section	data
hw_bands:	dc.w	4
		dc.w	0
		STECOL	0,0,5
		STECOL	15,15,15
		dcb.w	13,0
		STECOL	15,2,2		; ruler: band 0 red
		dc.w	50
		STECOL	0,5,0
		STECOL	15,15,15
		dcb.w	13,0
		STECOL	2,15,2		; band 1 green
		dc.w	100
		STECOL	5,0,0
		STECOL	15,15,15
		dcb.w	13,0
		STECOL	4,4,15		; band 2 blue
		dc.w	150
		STECOL	4,4,4
		STECOL	15,15,15
		dcb.w	13,0
		STECOL	15,15,2		; band 3 yellow

hw_band1:	dc.w	1		; one band: no Timer B (the floppy comparison)
		dc.w	0
		STECOL	0,0,5
		STECOL	15,15,15
		dcb.w	13,0
		STECOL	15,15,15

k_table:					; name (K_NAME), kind, code, raw scan
K_NAME	equ	4
K_SIZE	equ	20
		dc.b	0,K_EXT,$3b,0,"F1",0
		dcb.b	K_SIZE-7,0
		dc.b	0,K_EXT,$44,0,"F10",0
		dcb.b	K_SIZE-8,0
		dc.b	0,K_EXT,103,0,"Ctrl+F10",0
		dcb.b	K_SIZE-13,0
		dc.b	0,K_EXT,117,0,"Ctrl+ClrHome",0
		dcb.b	K_SIZE-17,0
		dc.b	0,K_EXT,$10,0,"Alt+Q",0
		dcb.b	K_SIZE-10,0
		dc.b	0,K_EXT,$7e,0,"Alt+7",0
		dcb.b	K_SIZE-10,0
		dc.b	0,K_EXT,$48,0,"Up arrow",0
		dcb.b	K_SIZE-13,0
		dc.b	0,K_EXT,$47,0,"ClrHome",0
		dcb.b	K_SIZE-12,0
		dc.b	0,K_ASC,'7',$67,"Keypad 7",0
		dcb.b	K_SIZE-13,0
		dc.b	0,K_ASC,'-',$4a,"Keypad -",0
		dcb.b	K_SIZE-13,0

fn_rep:		dc.b	"HWCHECK.TXT",0
fn_mod:		dc.b	"SOUND",92,"GAME.MOD",0
fn_rawpat:	dc.b	"MUSIC",92,"*.RAW",0
fn_rawgame:	dc.b	"MUSIC",92,"GAME.RAW",0
fn_datapat:	dc.b	"DATA",92,"*.*",0
fn_isdisk:	dc.b	"A:",92,"ISDISK.TAB",0
fn_adata:	dc.b	"A:",92,"DATA",92,"*.*",0
fn_asound:	dc.b	"A:",92,"SOUND",92,"*.*",0
fn_aroot:	dc.b	"A:",92,"*.*",0
s_adata:	dc.b	"A:",92,"DATA",92,0
s_asound:	dc.b	"A:",92,"SOUND",92,0
s_aroot:	dc.b	"A:",92,0
s_music:	dc.b	"MUSIC",92,0
s_sound:	dc.b	"SOUND",92,0
s_data:		dc.b	"DATA",92,0
s_dotmod:	dc.b	".MOD",0

m_menu:		dc.b	"IRON SEED STE - HARDWARE CHECK",10,10
		dc.b	"1  Raster splits (20 s)",10
		dc.b	"2  Splits + music mixer (20 s)",10
		dc.b	"3  Disk read speed",10
		dc.b	"4  Music stream from disk (40 s)",10
		dc.b	"5  Keyboard keys",10
		dc.b	"6  Floppy drive A",10
		dc.b	"A  Run 1-4 one after another",10
		dc.b	"Q  Save HWCHECK.TXT and quit",10,10
		dc.b	"Esc stops a running test.",10
		dc.b	"Watch the coloured strip on the",10
		dc.b	"left: each colour must change on",10
		dc.b	"one straight line (lines 50, 100,",10
		dc.b	"150), never with a jagged edge.",0
m_title:	dc.b	"Iron Seed STE hardware check, kit 1",10,0
m_mach:		dc.b	"Machine: ",0
m_noj:		dc.b	"ST (no cookie jar)",0
m_ste:		dc.b	"STE",0
m_mste:		dc.b	"Mega STE",0
m_stbook:	dc.b	"ST Book",0
m_st:		dc.b	"ST",0
m_other:	dc.b	"not an STE",0
m_mch1:		dc.b	" (_MCH $",0
m_tos:		dc.b	"TOS ",0
m_tosd:		dc.b	" of ",0
m_tosc:		dc.b	", ",0
m_countries:	dc.b	"US",0,0,"DE",0,0,"FR",0,0,"UK",0,0,"ES",0,0,"IT",0,0,"SE",0,0
		dc.b	"CHf",0,"CHd",0,"TR",0,0,"?? ",0
m_ram:		dc.b	"RAM ",0
m_kb:		dc.b	" KB",0
m_60:		dc.b	", 60 Hz",10,0
m_50:		dc.b	", 50 Hz",10,0
m_cpu:		dc.b	"CPU ~",0
m_mhz:		dc.b	" MHz (loop ",0
m_8e21:		dc.b	"$FF8E21 = $",0
m_from:		dc.b	"Run from ",0
m_bs:		dc.b	92,0
m_pool:		dc.b	"Free memory ",0
m_music:	dc.b	"Music: ",0
m_none:		dc.b	"no MUSIC folder",0
m_rate:		dc.b	" at ",0
m_hz:		dc.b	" Hz",0
m_mod:		dc.b	"SOUND",92,"GAME.MOD found",0
m_nomod:	dc.b	"no SOUND",92,"GAME.MOD",0
m_mouse:	dc.b	10,"Press a key for the menu.",10,0
m_left:		dc.b	" s left (Esc stops)",0
m_anykey:	dc.b	"Press a key.",0
m_ind:		dc.b	"  ",0
m_comma:	dc.b	", ",0
m_splits:	dc.b	" splits",0
m_ontime:	dc.b	", all on time",0
m_late:		dc.b	" late (",0
m_late16:	dc.b	" by 16+ px, latest ",0
m_latepx:	dc.b	" px)",0
m_ent:		dc.b	" with a late interrupt",0
m_vok:		dc.b	"OK",10,0
m_vminor:	dc.b	"OK (a few pixels at most)",10,0
m_vbad:		dc.b	"LATE: band edges may flicker",10,0
m_aborted:	dc.b	"  stopped (Esc)",10,0
m_t1:		dc.b	10,"[1] Raster splits, CPU busy, 20 s",10,0
m_t1h:		dc.b	"Move the mouse around meanwhile.",10,0
m_lbusy:	dc.b	"",0
m_t2:		dc.b	10,"[2] Splits + MOD mixer (GAME.MOD), 20 s",10,0
m_lmix:		dc.b	"",0
m_mixcpu:	dc.b	"  mixer ",0
m_strcpu:	dc.b	"  sound ",0
m_pct:		dc.b	" % of the CPU",0
m_free:		dc.b	", game loop ",0
m_free2:	dc.b	" % of test 1",0
m_nomod2:	dc.b	"  no SOUND",92,"GAME.MOD: skipped",10,0
m_t3:		dc.b	10,"[3] Disk read speed",10,0
m_file:		dc.b	"  file ",0
m_nofile:	dc.b	"  no file to read: skipped",10,0
m_kbreads:	dc.b	" KB reads: ",0
m_kbin:		dc.b	" KB in ",0
m_s:		dc.b	" s",0
m_eq:		dc.b	" = ",0
m_kbs:		dc.b	" KB/s",0
m_tofast:	dc.b	" (too fast to time)",0
m_slow:		dc.b	", slowest ",0
m_ms:		dc.b	" ms",0
m_rerr:		dc.b	"  read error ",0
m_lduring:	dc.b	"during reads: ",0
m_lbetween:	dc.b	"between reads: ",0
m_t4:		dc.b	10,"[4] Music stream, CPU busy, 40 s",10,0
m_fill:		dc.b	"  ring (holds ",0
m_fill2:	dc.b	" s) filled in ",0
m_fill3:	dc.b	" s, then never below ",0
m_nofill:	dc.b	" s) never filled, lowest ",0
m_ringof2:	dc.b	" s,",10,"  underruns ",0
m_under:	dc.b	" pairs",0
m_reads:	dc.b	"  ",0
m_reads2:	dc.b	" reads, ",0
m_reads3:	dc.b	" ms reading, slowest ",0
m_rerrs:	dc.b	", read errors ",0
m_vstr:		dc.b	"OK: the music never ran dry",10,0
m_vstrb:	dc.b	"UNDERRUN: the music had gaps",10,0
m_nomusic:	dc.b	"  no MUSIC folder: skipped",10,0
m_strerr:	dc.b	"  the stream did not start",10,0
m_t5:		dc.b	"[5] Keyboard - press each key",10
		dc.b	"(Esc ends early):",10,0
m_t5r:		dc.b	10,"[5] Keyboard: ",0
m_kall:		dc.b	"all keys arrived as the game reads them",10,0
m_kmiss:	dc.b	"not seen: ",0
m_kno:		dc.b	" .. ",0
m_kok:		dc.b	" ok ",0
m_kraw:		dc.b	"scan $",0
m_kasc:		dc.b	" char $",0
m_kshf:		dc.b	" shift $",0
m_kgame:	dc.b	"the game gets ",0
m_kext:		dc.b	"0 then ",0
m_kchr:		dc.b	"character ",0
m_t6:		dc.b	10,"[6] Floppy drive A",10,0
m_fins1:	dc.b	"Put an Iron Seed game disk (1-8)",10
		dc.b	"in drive A, press a key (Esc: skip)",10,0
m_fins2:	dc.b	"Now put in a DIFFERENT Iron Seed",10
		dc.b	"game disk, press a key (Esc: skip)",10,0
m_fnodisk:	dc.b	"  no Iron Seed disk in drive A",10,0
m_fdisk:	dc.b	"  disk ",0
m_fchg:		dc.b	"  disk change: ",0
m_fyes:		dc.b	"TOS noticed it, disk ",0
m_fno:		dc.b	"TOS missed it; the game's signal works, disk ",0
m_fsame:	dc.b	"the same disk again?",10,0
m_fnone2:	dc.b	"no Iron Seed disk read",10,0
m_fnosplit:	dc.b	"  without the raster splits:",10,0
m_fback:	dc.b	"Put the disk HWCHECK was started",10
		dc.b	"from back in drive A, press a key.",10,0
m_skipped:	dc.b	"  skipped",10,0
m_saving:	dc.b	"Writing HWCHECK.TXT ...",10,0
m_saved:	dc.b	"Done. Please send HWCHECK.TXT.",10,0
m_saveerr:	dc.b	"Could not write HWCHECK.TXT here.",10
		dc.b	"Write-protected disk? Fix it and",10
		dc.b	"press a key, Esc quits without it.",10,0
	even

	section	bss
hw_lbuf:	ds.l	1
hw_rbuf:	ds.l	1
hw_repp:	ds.l	1
hw_mch:		ds.l	1
hw_cpun:	ds.l	1
hw_mhz:		ds.l	1
hw_base:	ds.l	1
hw_tend:	ds.l	1
hw_tsec:	ds.l	1
hw_rdt:		ds.l	1
hw_rdmax:	ds.l	1
hw_filled:	ds.l	1		; ticks until the ring was first full (0: not yet)
hw_t0:		ds.l	1
hw_bps:		ds.l	1
hw_rfile:	ds.l	1
hw_rawrate:	ds.l	1
hw_bigsize:	ds.l	1
hw_kraw:	ds.l	1
hw_oldcrit:	ds.l	1
hw_oldmc:	ds.l	1
hw_hdr:		ds.b	32
hw_abort:	ds.w	1
hw_kcode:	ds.w	1
hw_kext:	ds.w	1
hw_force:	ds.w	1
hw_disk1:	ds.w	1
hw_disk2:	ds.w	1
hw_disk3:	ds.w	1
con_col:	ds.w	1
con_row:	ds.w	1
con_fontw:	ds.w	1
con_font:	ds.l	1
con_mode:	ds.b	1
hw_kshift:	ds.b	1
hw_kseen:	ds.b	KEYS
	even
con_num:	ds.b	12
hw_dta:		ds.b	DTA_SIZE
hw_path:	ds.b	128
hw_rawname:	ds.b	32
hw_modname:	ds.b	32
hw_bigname:	ds.b	64
hw_fname:	ds.b	64
hw_rep:		ds.b	REPMAX
