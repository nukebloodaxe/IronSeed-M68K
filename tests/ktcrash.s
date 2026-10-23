; ktcrash.s - kernel test: an address error must restore the machine and write C:\CRASH.TXT
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"
	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	move.w	#60,d0
	bsr	tim_delay
	lea	1.w,a0
	move.w	(a0),d0			; odd word access -> address error
	moveq	#0,d0
	bra	sys_exit
	include	"kernel.s"
