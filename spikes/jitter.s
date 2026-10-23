; jitter.s - Phase 0 spike: does the Timer B palette split stay on its line while
;  - DMA sound plays from a ring buffer refilled by a 4-voice mixer in the VBL,
;  - the IKBD sends a joystick packet every frame (ACIA interrupts),
;  - the main loop runs the c2p kernel flat out?
; The Timer B handler logs the video address counter on entry and after its last
; palette write. Writes C:\JIT.BIN for analysis on the host.
; Build: vasmm68k_mot -Ftos -m68000 -devpac -nosym -o JITTER.PRG jitter.s

TBCR	equ	$fffffa1b
TBDR	equ	$fffffa21
IERA	equ	$fffffa07
IMRA	equ	$fffffa13
ISRA	equ	$fffffa0f
PAL	equ	$ffff8240
VCOUNT	equ	$ffff8205	; video address counter hi/mid/lo at 8205/07/09
SNDCTL	equ	$ffff8901
SNDSTRT	equ	$ffff8903	; 8903/05/07
SNDCNT	equ	$ffff8909	; 8909/0B/0D
SNDEND	equ	$ffff890f	; 890F/11/13
SNDMODE	equ	$ffff8921
ACIACTL	equ	$fffffc00
ACIADAT	equ	$fffffc02
BANDH	equ	50
NFRAMES	equ	1500
MIXON	equ	1		; 0 = no mixer (to measure its cost)
RING	equ	2048		; bytes = 1024 stereo sample pairs (~82 ms at 12517 Hz)

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

	move.w	#34,-(sp)		; Kbdvbase
	trap	#14
	addq.l	#2,sp
	move.l	d0,kbdv

	clr.l	-(sp)
	move.w	#$20,-(sp)
	trap	#1
	addq.l	#6,sp
	move.l	d0,oldssp

	bsr	build_luts
	bsr	fill_chunky
	bsr	build_wave
	lea	logbuf,a0
	move.l	a0,logptr

	move.l	kbdv,a0			; hook joystick packets to count them
	move.l	24(a0),oldjoy
	move.l	#joy_hook,24(a0)

	bsr	sound_on
	bsr	split_on

	; ---- main loop: c2p flat out until NFRAMES have been shown
.main:	lea	chunky,a0
	move.l	scr,a2
	bsr	c2p_full
	addq.l	#1,iters
	cmp.w	#NFRAMES,frames
	blo.s	.main

	bsr	split_off
	bsr	sound_off
	move.l	kbdv,a0
	move.l	oldjoy,24(a0)

	move.l	scr,hdr_scr
	move.w	frames,hdr_frames
	move.l	joycnt,hdr_joy
	move.l	iters,hdr_iters
	move.l	logptr,d0
	sub.l	#logbuf,d0
	move.l	d0,hdr_loglen
	lea	fn,a0
	lea	hdr,a1
	move.l	#hdr_end-hdr,d0
	add.l	hdr_loglen,d0
	bsr	save

	move.l	oldssp,-(sp)
	move.w	#$20,-(sp)
	trap	#1
	addq.l	#6,sp
	dc.w	$a009
	clr.w	-(sp)
	trap	#1

; ---- joystick packet hook (called by TOS's ACIA handler, a0 = packet)
joy_hook:
	addq.l	#1,joycnt
	move.l	oldjoy,-(sp)
	rts

; ---- DMA sound: stereo 12517 Hz, repeat over the ring buffer
sound_on:
	clr.b	SNDCTL.w
	move.l	#ring,d0
	move.b	d0,SNDSTRT+4.w
	lsr.l	#8,d0
	move.b	d0,SNDSTRT+2.w
	lsr.l	#8,d0
	move.b	d0,SNDSTRT.w
	move.l	#ring+RING,d0
	move.b	d0,SNDEND+4.w
	lsr.l	#8,d0
	move.b	d0,SNDEND+2.w
	lsr.l	#8,d0
	move.b	d0,SNDEND.w
	move.b	#%00000001,SNDMODE.w	; stereo, 12517 Hz
	clr.w	wpos
	move.b	#3,SNDCTL.w		; play, repeat
	rts

sound_off:
	clr.b	SNDCTL.w
	rts

; ---- mixer, called from the VBL. Fills from wpos up to just behind the DMA
; play position. Voices: 4 saw waves at different pitches, 8.8 phase steps.
; Left = v0+v3, right = v1+v2 (ProTracker's channel panning).
mix_vbl:
	movem.l	d0-d7/a0-a6,-(sp)
	lea	SNDCNT.w,a1
	movep.l	0(a1),d0		; 8909/0B/0D/0F -> bytes 3..0
	lsr.l	#8,d0
	and.l	#$00fffffe,d0
	sub.l	#ring,d0		; play offset
	subq.l	#8,d0			; stay clear of the 4-word DMA FIFO
	bpl.s	.p
	add.l	#RING,d0
.p:	move.w	wpos,d1
	move.w	d0,d2
	sub.w	d1,d2			; bytes to fill
	bpl.s	.q
	add.w	#RING,d2
.q:	lsr.w	#1,d2			; pairs
	move.w	sndlogi,d3
	lea	sndlog,a0
	cmp.w	#NFRAMES*2,d3
	bhs.s	.nl
	move.w	d2,0(a0,d3.w)
	addq.w	#2,sndlogi
.nl:	tst.w	d2
	beq	.done
	lea	ring,a0
	add.w	d1,a0			; write pointer
	lea	ring+RING,a5		; wrap point
	lea	wave,a2
	movem.w	phases,d3-d6
	move.w	steps,a3
	move.w	steps+2,a4
	move.w	steps+4,a6
	move.w	steps+6,d7
	subq.w	#1,d2
.mix:	add.w	a3,d3
	move.w	d3,d0
	lsr.w	#8,d0
	move.b	0(a2,d0.w),d1		; v0
	add.w	d7,d6
	move.w	d6,d0
	lsr.w	#8,d0
	add.b	0(a2,d0.w),d1		; + v3 -> left
	lsl.w	#8,d1
	add.w	a4,d4
	move.w	d4,d0
	lsr.w	#8,d0
	move.b	0(a2,d0.w),d1		; v1
	add.w	a6,d5
	move.w	d5,d0
	lsr.w	#8,d0
	add.b	0(a2,d0.w),d1		; + v2 -> right
	move.w	d1,(a0)+
	cmp.l	a5,a0
	bne.s	.nw
	lea	ring,a0
.nw:	dbf	d2,.mix
	movem.w	d3-d6,phases
	sub.l	#ring,a0
	move.w	a0,wpos
.done:	movem.l	(sp)+,d0-d7/a0-a6
	rts

build_wave:				; saw, -63..+63
	lea	wave,a0
	moveq	#0,d0
.w:	move.w	d0,d1
	lsr.w	#1,d1
	sub.w	#64,d1
	move.b	d1,(a0)+
	addq.w	#1,d0
	cmp.w	#256,d0
	bne.s	.w
	rts

; save: a0 = name, a1 = buffer, d0 = length
save:	movem.l	d0/a1,-(sp)
	clr.w	-(sp)
	move.l	a0,-(sp)
	move.w	#$3c,-(sp)
	trap	#1
	addq.l	#8,sp
	movem.l	(sp)+,d1/a1
	move.w	d0,d3
	bmi.s	.x
	move.l	a1,-(sp)
	move.l	d1,-(sp)
	move.w	d3,-(sp)
	move.w	#$40,-(sp)
	trap	#1
	lea	12(sp),sp
	move.w	d3,-(sp)
	move.w	#$3e,-(sp)
	trap	#1
	addq.l	#4,sp
.x:	rts

; ---- Timer B split
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
	move.l	$114.w,oldtc		; [CG] recipe: let Timer B preempt the
	move.l	$118.w,oldacia		; TOS Timer C and ACIA handlers
	move.l	#tc_wrap,$114.w
	move.l	#acia_wrap,$118.w
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
	move.l	oldtc,$114.w
	move.l	oldacia,$118.w
	move.w	(sp)+,sr
	lea	oldpal,a0
	lea	PAL.w,a1
	moveq	#8-1,d0
.rp:	move.l	(a0)+,(a1)+
	dbf	d0,.rp
	rts

; Lower the CPU mask to 5 before entering TOS's level-6 handlers: the MFP's
; in-service bit still holds back lower channels, but Timer B (channel 8) can now
; interrupt Timer C (5) and the ACIAs (6).
tc_wrap:
	move.w	#$2500,sr
	move.l	oldtc,-(sp)
	rts
acia_wrap:
	move.w	#$2500,sr
	move.l	oldacia,-(sp)
	rts

vbl_handler:
	movem.l	d0-d7/a0,-(sp)
	lea	palettes,a0
	movem.l	(a0)+,d0-d7
	movem.l	d0-d7,PAL.w
	move.l	a0,bandptr
	clr.b	TBCR.w
	move.b	#BANDH-1,TBDR.w		; fire at the end of the line BEFORE the split
	move.b	#8,TBCR.w
	move.l	scr,d0
	add.l	#BANDH*160,d0
	lsl.l	#8,d0
	move.l	d0,target		; counter value (<<8) at the start of the split line
	movem.l	(sp)+,d0-d7/a0
	addq.w	#1,frames
	ifne	MIXON
	bsr	mix_vbl
	endc
	btst	#1,ACIACTL.w		; IKBD load: interrogate joystick
	beq.s	.nk
	move.b	#$16,ACIADAT.w
.nk:	move.l	oldvbl,-(sp)
	rts

; Timer B fires at the end of the line BEFORE the split. Preload the palette,
; then poll the video counter until it reaches the first byte of the split line
; (= that line's left border/blank has begun) and write all 16 colours at once.
tb_handler:
	movem.l	d0-d7/a0-a3,-(sp)
	lea	VCOUNT.w,a1
	movep.l	0(a1),d0		; counter on entry
	move.l	logptr,a2
	cmp.l	#logend,a2
	bhs.s	.n1
	move.l	d0,(a2)+
.n1:	move.l	bandptr,a0
	movem.l	(a0)+,d1-d7/a3		; 16 colours in d1-d7/a3
	move.l	a0,bandptr
	move.l	target,a0
.w:	movep.l	0(a1),d0
	clr.b	d0
	cmp.l	a0,d0
	blo.s	.w
	movem.l	d1-d7/a3,PAL.w
	movep.l	0(a1),d0		; counter after the write
	cmp.l	#logend,a2
	bhs.s	.n2
	move.l	d0,(a2)+
	move.l	a2,logptr
.n2:	clr.b	TBCR.w			; restart: next split BANDH lines on
	move.b	#BANDH-1,TBDR.w
	move.b	#8,TBCR.w
	add.l	#BANDH*160*256,target
	movem.l	(sp)+,d0-d7/a0-a3
	bclr	#0,ISRA.w
	rte

	include	"c2p.i"

	section	data
	include	"split_data.i"
	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.w	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
fn:	dc.b	"C:\JIT.BIN",0
	even
phases:	dc.w	0,0,0,0
steps:	dc.w	$0180,$0233,$02f1,$03c0	; ~ different pitches

	section	bss
scr:		ds.l	1
oldssp:		ds.l	1
oldvbl:		ds.l	1
oldtb:		ds.l	1
oldtc:		ds.l	1
oldacia:	ds.l	1
oldjoy:		ds.l	1
kbdv:		ds.l	1
bandptr:	ds.l	1
logptr:		ds.l	1
target:		ds.l	1
joycnt:		ds.l	1
iters:		ds.l	1
frames:		ds.w	1
wpos:		ds.w	1
sndlogi:	ds.w	1
oldpal:		ds.w	16
oldiera:	ds.b	1
oldimra:	ds.b	1
	even
hdr:
hdr_scr:	ds.l	1
hdr_joy:	ds.l	1
hdr_iters:	ds.l	1
hdr_loglen:	ds.l	1
hdr_frames:	ds.w	1
sndlog:		ds.w	NFRAMES
hdr_end:
logbuf:		ds.l	NFRAMES*4*2
logend:
wave:		ds.b	256
luttabs:	ds.l	4*256
chunky:		ds.b	64000
ring:		ds.b	RING
screenbuf:	ds.b	32000+256
