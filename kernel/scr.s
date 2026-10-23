; scr.s - scripted input for automated tests (the ST twin of the Linux oracle's
; IRONSEED_INPUT). Part of kernel.s.
;
; scr_open   in: a0 = script file name. If the file exists, input comes from it as well as
;            from the real keyboard/mouse. Call once at program start. trashes d0-d2/a0-a2
;            scr_test (word) stays 1 for the whole run once a script was found.
; scr_tick   advance the script (called by kbd_keypressed / kbd_mouse_status / kbd_mouse_xy)
;
; Script lines (one command each, '#' = comment):
;   wait MS        pause the script for MS milliseconds
;   key C          a key with ASCII C           key #N   ASCII code N (13 = Return, 27 = Esc)
;   key ^N         an extended key: readkey gives 0, then scan code N (72 up, 80 down, 75 left, 77 right)
;   move X Y       put the mouse at X, Y          click X Y   move there and press the left button
;   shot NAME      write C:\NAME.SCR: 32000 screen bytes + the 4-band table (2+4*34 bytes)
;   quit           end the program now (exit code 99)
;   dump NAME      a state dump now (orc_dump; the Linux oracle's 'dump' does the same)
;   args TEXT      (leading lines only) the command tail a test run uses when it was started
;                  without one (Hatari --auto passes none): scr_args, Pascal-style length byte
;   vtime          virtual time from here on (leading lines of a script): tim_delay no longer waits,
;                  it advances a virtual clock that 'wait' counts in, and runs the script; polls
;                  (kbd_keypressed, kbd_mouse_status) run it without advancing time, except that
;                  50 polls without a delay in between (a busy-wait loop) jump to the end of the
;                  current wait. Same rules as the Linux oracle's IRONSEED_VTIME (c_utils.c), so
;                  real-time loops run the same number of times in both (deterministic sessions).
; scr_poll   scr_tick for key/mouse polls (counts polls in virtual time)
; scr_dbg    (debugging) append d0.l to a 256-long ring; every 'shot' also writes it to C:\DBG.BIN
;            (first long: the count so far)               trashes: nothing
; scr_vdelay in: d0.l = ms: tim_delay in virtual time
; A command waits until the program has consumed the previous key or click.

SCR_MAX		equ	4096

	section	text
scr_open:
	lea	scr_buf,a1
	move.l	#SCR_MAX-1,d0
	bsr	fil_load
	bcs	.x
	lea	scr_buf,a0
	clr.b	0(a0,d0.l)		; terminate
	move.l	a0,scr_ptr
	move.w	#1,scr_on
	move.w	#1,scr_test
	clr.l	scr_resume
.lead:	move.l	scr_ptr,a0		; leading "vtime" / "args ..." lines (bytes: lines
	lea	scr_kw_vtime,a1		; may start at odd addresses)
	bsr	scr_kw
	bne.s	.args
	move.w	#1,scr_vtime		; virtual time from the start
	clr.w	kbd_mx			; (and the mouse at 0,0 like the Linux build's dummy SDL mouse)
	clr.w	kbd_my
	bsr	scr_eol
	bra.s	.lead
.args:	lea	scr_kw_args,a1
	bsr	scr_kw
	bne.s	.x
	addq.l	#5,a0
	lea	scr_args+1,a1
	moveq	#0,d0
.ac:	move.b	(a0),d1
	cmp.b	#13,d1
	beq.s	.ae
	cmp.b	#10,d1
	beq.s	.ae
	tst.b	d1
	beq.s	.ae
	move.b	d1,(a1)+
	addq.l	#1,a0
	addq.w	#1,d0
	cmp.w	#120,d0
	bne.s	.ac
.ae:	move.b	d0,scr_args
	clr.b	(a1)
	bsr	scr_eol
	bra.s	.lead
.x:	rts

scr_tick:
	tst.w	scr_on
	beq	.x
	movem.l	d0-d3/a0-a2,-(sp)
	bsr	scr_now
	cmp.l	scr_resume,d0
	blo	.out
	tst.b	scr_key			; previous input not consumed yet
	bne	.out
	tst.b	kbd_mclick
	bne	.out
.line:	move.l	scr_ptr,a0
.skipws:
	move.b	(a0),d0
	beq	.end
	cmp.b	#' ',d0
	bhi.s	.cmd
	addq.l	#1,a0
	bra.s	.skipws
.cmd:	cmp.b	#'#',d0
	beq.s	.nextl
	move.b	(a0),d1			; first letter of the command
	bsr	scr_word		; skip the command word, a0 -> argument
	cmp.b	#'w',d1
	beq	.wait
	cmp.b	#'k',d1
	beq	.key
	cmp.b	#'m',d1
	beq	.move
	cmp.b	#'c',d1
	beq	.click
	cmp.b	#'s',d1
	beq	.shot
	cmp.b	#'q',d1
	beq	.quit
	cmp.b	#'v',d1
	beq	.vtime
	cmp.b	#'d',d1
	beq	.dump
.nextl:	move.b	(a0)+,d0		; unknown or comment: skip to the end of line
	beq.s	.end0
	cmp.b	#10,d0
	bne.s	.nextl
	move.l	a0,scr_ptr
	bra.s	.line
.end0:	subq.l	#1,a0
.end:	move.l	a0,scr_ptr
	clr.w	scr_on
	bra	.out
.dump:	bsr	scr_eol
	bsr	orc_dump
	bra	.line
.vtime:	move.w	#1,scr_vtime
	clr.l	scr_vclock
	clr.l	scr_resume
	bsr	scr_eol
	bra	.line
.wait:	bsr	scr_num
	move.l	d0,d2
	bsr	scr_eol
	bsr	scr_now
	add.l	d2,d0
	move.l	d0,scr_resume
	bra	.out
.key:	move.b	(a0),d0
	cmp.b	#'#',d0
	beq.s	.knum
	cmp.b	#'^',d0
	beq.s	.kext
	move.b	d0,scr_key		; literal character
	clr.b	scr_ext
	addq.l	#1,a0
	bra.s	.kdone
.knum:	addq.l	#1,a0
	bsr	scr_num
	move.b	d0,scr_key
	clr.b	scr_ext
	bra.s	.kdone
.kext:	addq.l	#1,a0
	bsr	scr_num
	move.b	d0,scr_ext		; scan code; key byte = 0 marker
	move.b	#$ff,scr_key		; (non-zero = pending)
.kdone:	bsr	scr_eol
	bra	.out
.move:	st	scr_mouse		; (from now on move_mouse leaves the scripted position, as the oracle)
	bsr	scr_num
	move.w	d0,kbd_mx
	bsr	scr_num
	move.w	d0,kbd_my
	bsr	scr_eol
	bra	.line
.click:	st	scr_mouse
	bsr	scr_num
	move.w	d0,kbd_mx
	bsr	scr_num
	move.w	d0,kbd_my
	bsr	scr_eol
	or.b	#1,kbd_mclick
	bra.s	.out
.shot:	lea	scr_name+3,a1		; "C:\" + NAME + ".SCR"
	moveq	#8-1,d2
.sn:	move.b	(a0),d0
	cmp.b	#' ',d0
	bls.s	.sne
	move.b	d0,(a1)+
	addq.l	#1,a0
	dbf	d2,.sn
.sne:	move.b	#'.',(a1)+
	move.b	#'S',(a1)+
	move.b	#'C',(a1)+
	move.b	#'R',(a1)+
	clr.b	(a1)
	bsr	scr_eol
	move.l	a0,-(sp)
	bsr	scr_shot
	move.l	(sp)+,a0
	bra	.line
.quit:	moveq	#99,d0
	bra	sys_exit
.out:	movem.l	(sp)+,d0-d3/a0-a2
.x:	rts

scr_kw:					; does a0 start with the 4 bytes at a1? (Z set)
	moveq	#4-1,d1
.c:	move.b	(a0,d1.w),d0
	cmp.b	(a1,d1.w),d0
	dbne	d1,.c
	rts

scr_dbg:
	movem.l	d1/a0,-(sp)
	move.l	scr_dbgn,d1
	addq.l	#1,scr_dbgn
	and.w	#255,d1
	lsl.w	#2,d1
	lea	scr_dbgbuf,a0
	move.l	d0,0(a0,d1.w)
	movem.l	(sp)+,d1/a0
	rts

scr_now:				; out: d0.l = script time (ms)  trashes: d1
	tst.w	scr_vtime
	beq	tim_ms
	move.l	scr_vclock,d0
	rts

scr_poll:
	tst.w	scr_vtime
	beq	scr_tick
	addq.w	#1,scr_vpolls
	cmp.w	#50,scr_vpolls
	blo	scr_tick
	move.l	d0,-(sp)
	move.l	scr_resume,d0
	cmp.l	scr_vclock,d0
	bls.s	.n
	move.l	d0,scr_vclock
.n:	move.l	(sp)+,d0
	bra	scr_tick

scr_vdelay:
	add.l	d0,scr_vclock
	clr.w	scr_vpolls
	bra	scr_tick

; skip the current word and the blanks after it (a0)
scr_word:
.w:	move.b	(a0),d0
	cmp.b	#' ',d0
	bls.s	.b
	addq.l	#1,a0
	bra.s	.w
.b:	move.b	(a0),d0
	beq.s	.x
	cmp.b	#' ',d0
	beq.s	.n
	cmp.b	#9,d0
	bne.s	.x
.n:	addq.l	#1,a0
	bra.s	.b
.x:	rts

; decimal number at a0 (leading blanks skipped) -> d0.l, a0 after it
scr_num:
.b:	cmp.b	#' ',(a0)
	bne.s	.d
	addq.l	#1,a0
	bra.s	.b
.d:	moveq	#0,d0
	moveq	#0,d1
.n:	move.b	(a0),d1
	sub.b	#'0',d1
	cmp.b	#9,d1
	bhi.s	.x
	mulu	#10,d0
	add.l	d1,d0
	addq.l	#1,a0
	bra.s	.n
.x:	rts

; move to the start of the next line and store the pointer
scr_eol:
.e:	move.b	(a0),d0
	beq.s	.x
	addq.l	#1,a0
	cmp.b	#10,d0
	bne.s	.e
.x:	move.l	a0,scr_ptr
	rts

; save the shown screen + band table
scr_shot:
	movem.l	d3/a3,-(sp)
	move.w	kbd_cur_on,-(sp)	; without the mouse cursor (like the Linux shots)
	bsr	kbd_cursor_hide
	lea	scr_name,a0
	clr.w	-(sp)
	move.l	a0,-(sp)
	GEMDOS	GD_FCREATE,8
	tst.l	d0
	bmi.s	.x
	move.w	d0,d3
	move.l	vid_phys,-(sp)
	move.l	#SCR_SIZE,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FWRITE,12
	pea	vid_bands_src
	move.l	#2+4*BAND_SIZE,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FWRITE,12
	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
	tst.l	scr_dbgn		; the debug ring, if anything was logged
	beq.s	.x
	clr.w	-(sp)
	pea	scr_fn_dbg
	GEMDOS	GD_FCREATE,8
	move.w	d0,d3
	bmi.s	.x
	pea	scr_dbgn
	move.l	#4+256*4,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FWRITE,12
	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
.x:	tst.w	(sp)+
	beq.s	.h
	bsr	kbd_cursor_show
.h:	movem.l	(sp)+,d3/a3
	rts

	section	data
scr_name:	dc.b	"C:",92,0,0,0,0,0,0,0,0,0,0,0,0,0
scr_fn_dbg:	dc.b	"C:",92,"DBG.BIN",0
scr_kw_vtime:	dc.b	"vtim"
scr_kw_args:	dc.b	"args"
	even

	section	bss
scr_ptr:	ds.l	1
scr_resume:	ds.l	1
scr_on:		ds.w	1
scr_test:	ds.w	1		; a script was given: test run (fixed random seed, state dumps)
scr_vtime:	ds.w	1		; virtual time (script command vtime)
scr_vpolls:	ds.w	1
scr_vclock:	ds.l	1
scr_key:	ds.b	1
scr_ext:	ds.b	1
scr_mouse:	ds.b	1		; the script has placed the mouse (c_utils.c script_mouse)
	even
scr_dbgn:	ds.l	1		; (scr_dbgbuf must follow: written together)
scr_dbgbuf:	ds.l	256
scr_args:	ds.b	128		; command tail from the script (length byte, text, 0)
scr_buf:	ds.b	SCR_MAX
	even
