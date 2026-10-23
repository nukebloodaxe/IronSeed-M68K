; sys.s - start-up, shutdown, crash handling. Part of kernel.s.
;
; sys_init   in: a0 = basepage (from 4(sp) at program entry)
;            out: supervisor mode on the kernel stack, a6 = GS (global state),
;                 low resolution, screen = vid_scr[0], mouse hidden, memory pool
;                 ready, all interrupts installed (VBL, Timer B, wrappers, IKBD).
;            Never returns on failure (prints a message and exits).
; sys_exit   in: d0.w = exit code. Restores everything and terminates. Never returns.

KSTACK		equ	8192		; kernel (supervisor) stack
POOL_KEEP	equ	64*1024		; leave this much to GEMDOS when taking the pool

	section	text
sys_init:
	move.l	(sp)+,a2		; our return address (stack is about to change)
	move.l	a0,sys_basepage
	lea	sys_ustack_top,sp	; user-mode stack in our BSS (before Mshrink frees the old one)
	; Mshrink(0, basepage, needed) - basepage+text+data+bss
	move.l	$0c(a0),d0
	add.l	$14(a0),d0
	add.l	$1c(a0),d0
	add.l	#$100,d0
	move.l	d0,-(sp)
	move.l	a0,-(sp)
	clr.w	-(sp)
	GEMDOS	$4a,12
	move.l	a2,-(sp)

	; save the screen setup
	XBIOS	XB_PHYSBASE,2
	move.l	d0,sys_oldphys
	XBIOS	XB_LOGBASE,2
	move.l	d0,sys_oldlog
	XBIOS	XB_GETREZ,2
	move.w	d0,sys_oldrez

	; memory pool: largest free block minus a reserve for GEMDOS
	move.l	#-1,-(sp)
	GEMDOS	GD_MALLOC,6
	sub.l	#POOL_KEEP,d0
	cmp.l	#256*1024,d0
	blt	.nomem
	move.l	d0,mem_pool_size
	move.l	d0,-(sp)
	GEMDOS	GD_MALLOC,6
	tst.l	d0
	beq	.nomem
	move.l	d0,mem_pool
	bsr	mem_init

	; two screens, 256-byte aligned
	move.l	#vid_screens+255,d0
	and.l	#$ffffff00,d0
	move.l	d0,vid_scr		; three screens (triple buffering, see vid_flip)
	add.l	#SCR_SIZE,d0
	move.l	d0,vid_scr+4
	add.l	#SCR_SIZE,d0
	move.l	d0,vid_scr+8
	dc.w	$a000			; Line-A: hide the GEM mouse
	dc.w	$a00a
	move.w	#0,-(sp)		; Setscreen(scr0, scr0, low)
	move.l	vid_scr,-(sp)
	move.l	vid_scr,-(sp)
	XBIOS	XB_SETSCREEN,12

	XBIOS	XB_KBDVBASE,2
	move.l	d0,sys_kbdv

	; supervisor mode, kernel stack
	clr.l	-(sp)
	GEMDOS	GD_SUPER,6
	move.l	d0,sys_oldssp
	move.l	(sp)+,a2		; return address, from the user stack
	lea	sys_kstack_top,sp
	move.l	a2,-(sp)

	lea	gs,a6
	move.b	$484.w,sys_oldconterm
	bclr	#0,$484.w		; no bell
	bclr	#2,$484.w		; no key click

	DI
	; save vectors and MFP state
	move.l	VEC_BUSERR.w,sys_oldvec
	move.l	VEC_ADDRERR.w,sys_oldvec+4
	move.l	VEC_ILLEGAL.w,sys_oldvec+8
	move.l	VEC_ZERODIV.w,sys_oldvec+12
	move.l	VEC_VBL.w,sys_oldvec+16
	move.l	VEC_TIMERC.w,sys_oldvec+20
	move.l	VEC_ACIA.w,sys_oldvec+24
	move.l	VEC_TIMERB.w,sys_oldvec+28
	move.b	MFP_IERA.w,sys_oldmfp
	move.b	MFP_IMRA.w,sys_oldmfp+1
	move.b	MFP_TBCR.w,sys_oldmfp+2
	move.b	MFP_TBDR.w,sys_oldmfp+3
	lea	VID_PAL.w,a0
	lea	sys_oldpal,a1
	moveq	#8-1,d0
.sp:	move.l	(a0)+,(a1)+
	dbf	d0,.sp
	move.l	#sys_crash_bus,VEC_BUSERR.w
	move.l	#sys_crash_addr,VEC_ADDRERR.w
	move.l	#sys_crash_ill,VEC_ILLEGAL.w
	move.l	#sys_crash_div,VEC_ZERODIV.w
	move.w	#1,sys_active
	EI

	bsr	tim_init
	bsr	vid_init		; VBL, Timer B, wrappers
	bsr	kbd_init		; IKBD mouse hook
	bsr	snd_init
	rts

.nomem:	lea	sys_msg_nomem,a0
	bra	sys_fatal_user

; ---------------------------------------------------------------
sys_exit:
	move.w	d0,sys_exitcode
	bsr	sys_restore
	move.l	sys_oldssp,-(sp)	; back to user mode
	GEMDOS	GD_SUPER,6
	bsr	sys_restore_screen
	move.w	sys_exitcode,-(sp)
	move.w	#GD_PTERM,-(sp)
	trap	#1

; sys_restore: undo everything sys_init/vid/kbd/snd changed (supervisor mode).
sys_restore:
	tst.w	sys_active
	beq	.x
	clr.w	sys_active
	bsr	snd_exit
	bsr	kbd_exit
	DI
	clr.b	MFP_TBCR.w
	move.b	sys_oldmfp+3,MFP_TBDR.w
	move.b	sys_oldmfp,MFP_IERA.w
	move.b	sys_oldmfp+1,MFP_IMRA.w
	move.l	sys_oldvec,VEC_BUSERR.w
	move.l	sys_oldvec+4,VEC_ADDRERR.w
	move.l	sys_oldvec+8,VEC_ILLEGAL.w
	move.l	sys_oldvec+12,VEC_ZERODIV.w
	move.l	sys_oldvec+16,VEC_VBL.w
	move.l	sys_oldvec+20,VEC_TIMERC.w
	move.l	sys_oldvec+24,VEC_ACIA.w
	move.l	sys_oldvec+28,VEC_TIMERB.w
	move.b	sys_oldmfp+2,MFP_TBCR.w
	EI
	lea	sys_oldpal,a0
	lea	VID_PAL.w,a1
	moveq	#8-1,d0
.rp:	move.l	(a0)+,(a1)+
	dbf	d0,.rp
	move.b	sys_oldconterm,$484.w
.x:	rts

; user mode: old screen + mouse back
sys_restore_screen:
	move.w	sys_oldrez,-(sp)
	move.l	sys_oldphys,-(sp)
	move.l	sys_oldlog,-(sp)
	XBIOS	XB_SETSCREEN,12
	dc.w	$a000
	dc.w	$a009
	rts

; ---------------------------------------------------------------
; Crash handlers: restore the machine, then report the exception and the PC.
; 68000 bus/address error frames have 8 extra bytes before SR/PC.
sys_crash_bus:
	move.w	#2,sys_crashno
	addq.l	#8,sp
	bra.s	sys_crash
sys_crash_addr:
	move.w	#3,sys_crashno
	move.l	2(sp),sys_crashaddr	; faulting access address
	addq.l	#8,sp
	bra.s	sys_crash
sys_crash_ill:
	move.w	#4,sys_crashno
	bra.s	sys_crash
sys_crash_div:
	move.w	#5,sys_crashno
sys_crash:
	move.w	#$2700,sr
	move.l	2(sp),sys_crashpc
	movem.l	d0-d7/a0-a7,sys_crashregs
	lea	6(sp),a0		; the stack above the frame (return addresses for tools/st_fatal.py)
	lea	sys_crashstk,a1
	moveq	#64-1,d0
.cs:	move.l	(a0)+,(a1)+
	dbf	d0,.cs
	lea	sys_kstack_top,sp
	bsr	sys_restore
	move.w	#$2300,sr
	move.l	sys_oldssp,-(sp)
	GEMDOS	GD_SUPER,6
	bsr	sys_restore_screen
	; message: "Crash: exception n at PC xxxxxx (text+yyyyyy)"
	lea	sys_msgbuf,a1
	lea	sys_msg_crash,a0
	bsr	sys_strcpy
	move.w	sys_crashno,d0
	add.b	#'0',d0
	move.b	d0,(a1)+
	lea	sys_msg_atpc,a0
	bsr	sys_strcpy
	move.l	sys_crashpc,d0
	bsr	sys_hex6
	lea	sys_msg_text,a0
	bsr	sys_strcpy
	move.l	sys_crashpc,d0
	move.l	sys_basepage,a0
	sub.l	8(a0),d0		; - text base
	bsr	sys_hex6
	lea	sys_msg_addr,a0
	bsr	sys_strcpy
	move.l	sys_crashaddr,d0
	bsr	sys_hex6
	lea	sys_msg_tail,a0
	bsr	sys_strcpy
	clr.b	(a1)
	lea	sys_msgbuf,a0
	bsr	sys_dumpcrash
	bra	sys_fatal_user

; a0 = message; user mode; print, wait for a key, exit with -1
sys_fatal_user:
	move.l	a0,-(sp)
	GEMDOS	GD_CCONWS,6
	move.w	#2,-(sp)
	BIOS	BI_BCONIN,4
	move.w	#-1,-(sp)
	move.w	#GD_PTERM,-(sp)
	trap	#1

; write the crash message and registers to C:\CRASH.TXT (for headless runs)
sys_dumpcrash:
	movem.l	d0-d2/a0-a2,-(sp)
	move.l	a0,a2
	clr.w	-(sp)
	pea	sys_fn_crash
	GEMDOS	GD_FCREATE,8
	tst.w	d0
	bmi.s	.x
	move.w	d0,d2
	move.l	a2,a0
	moveq	#-1,d1
.len:	addq.l	#1,d1
	tst.b	(a0)+
	bne.s	.len
	move.l	a2,-(sp)
	move.l	d1,-(sp)
	move.w	d2,-(sp)
	GEMDOS	GD_FWRITE,12
	move.l	sys_basepage,a0
	move.l	8(a0),sys_crashtb
	pea	sys_crashregs
	pea	64+256+4.w
	move.w	d2,-(sp)
	GEMDOS	GD_FWRITE,12
	move.w	d2,-(sp)
	GEMDOS	GD_FCLOSE,4
.x:	movem.l	(sp)+,d0-d2/a0-a2
	rts

sys_strcpy:				; a0 -> a1, a1 left after the copy
.c:	move.b	(a0)+,(a1)+
	bne.s	.c
	subq.l	#1,a1
	rts

sys_hex6:				; d0.l -> 6 hex digits at a1
	moveq	#6-1,d2
	rol.l	#8,d0
.h:	rol.l	#4,d0
	move.b	d0,d1
	and.w	#15,d1
	move.b	.dig(pc,d1.w),(a1)+
	dbf	d2,.h
	rts
.dig:	dc.b	"0123456789ABCDEF"

	section	data
sys_msg_nomem:	dc.b	"Iron Seed: not enough memory (needs 4 MB).",13,10,0
sys_msg_crash:	dc.b	13,10,"Iron Seed crashed: exception ",0
sys_msg_atpc:	dc.b	" at PC $",0
sys_msg_text:	dc.b	" (text+$",0
sys_msg_addr:	dc.b	"), access $",0
sys_msg_tail:	dc.b	13,10,"Press a key.",13,10,0
sys_fn_crash:	dc.b	"C:\CRASH.TXT",0
	even

	section	bss
sys_basepage:	ds.l	1
sys_oldphys:	ds.l	1
sys_oldlog:	ds.l	1
sys_oldssp:	ds.l	1
sys_kbdv:	ds.l	1
sys_oldvec:	ds.l	8
sys_crashpc:	ds.l	1
sys_crashaddr:	ds.l	1
sys_crashregs:	ds.l	16
sys_crashstk:	ds.l	64
sys_crashtb:	ds.l	1
sys_oldrez:	ds.w	1
sys_active:	ds.w	1
sys_exitcode:	ds.w	1
sys_crashno:	ds.w	1
sys_oldpal:	ds.w	16
sys_oldmfp:	ds.b	4
sys_oldconterm:	ds.b	1
	even
sys_msgbuf:	ds.b	128
		ds.b	2048
sys_ustack_top:
		ds.b	KSTACK
sys_kstack_top:
gs:		ds.b	GS_SIZEOF
	even
