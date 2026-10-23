; scr.s - scripted input for automated tests (the ST twin of the Linux oracle's
; IRONSEED_INPUT). Part of kernel.s.
;
; scr_open   in: a0 = script file name. If the file exists, input comes from it as well as
;            from the real keyboard/mouse. Call once at program start. trashes d0-d2/a0-a2
; scr_tick   advance the script (called by kbd_keypressed / kbd_mouse_status / kbd_mouse_xy)
;
; Script lines (one command each, '#' = comment):
;   wait MS        pause the script for MS milliseconds
;   key C          a key with ASCII C           key #N   ASCII code N (13 = Return, 27 = Esc)
;   key ^N         an extended key: readkey gives 0, then scan code N (72 up, 80 down, 75 left, 77 right)
;   move X Y       put the mouse at X, Y          click X Y   move there and press the left button
;   shot NAME      write C:\NAME.SCR: 32000 screen bytes + the 4-band table (2+4*34 bytes)
;   quit           end the program now (exit code 99)
; A command waits until the program has consumed the previous key or click.

SCR_MAX		equ	4096

	section	text
scr_open:
	lea	scr_buf,a1
	move.l	#SCR_MAX-1,d0
	bsr	fil_load
	bcs.s	.x
	lea	scr_buf,a0
	clr.b	0(a0,d0.l)		; terminate
	move.l	a0,scr_ptr
	move.w	#1,scr_on
	clr.l	scr_resume
.x:	rts

scr_tick:
	tst.w	scr_on
	beq	.x
	movem.l	d0-d3/a0-a2,-(sp)
	bsr	tim_ms
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
	beq.s	.wait
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
.wait:	bsr	scr_num
	move.l	d0,d2
	bsr	scr_eol
	bsr	tim_ms
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
	bra.s	.out
.move:	bsr	scr_num
	move.w	d0,kbd_mx
	bsr	scr_num
	move.w	d0,kbd_my
	bsr	scr_eol
	bra	.line
.click:	bsr	scr_num
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
.x:	movem.l	(sp)+,d3/a3
	rts

	section	data
scr_name:	dc.b	"C:",92,0,0,0,0,0,0,0,0,0,0,0,0,0
	even

	section	bss
scr_ptr:	ds.l	1
scr_resume:	ds.l	1
scr_on:		ds.w	1
scr_key:	ds.b	1
scr_ext:	ds.b	1
	even
scr_buf:	ds.b	SCR_MAX
	even
