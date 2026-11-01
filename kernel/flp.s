; flp.s - the floppy version (Phase 8). Part of kernel.s.
;
; Every file call of the kernel and the programs goes through flp_dos (kmac.i FDOS: Fopen,
; Fcreate, Fclose, Fread, Fwrite, Fseek, Dcreate, Fdelete). Unless the program was started from
; a floppy (drive A or B) whose root holds ISDISK.TAB (tools/mkfloppy.py), flp_dos is just
; trap #1. On the floppies:
;  - a data file not on the disk in the drive (the table says on which disks each file is)
;    brings up a prompt for the disk ("Please insert Iron Seed disk N"), then the call again;
;    music (table flag 2) never asks: mod_load remembers it and snd_poll starts it once its
;    disk is in the drive (mod.s mod_deferit / mod_retry)
;  - SAVEGAME.DIR and SAVEn\ are on the save disk (marker \ISSAVE.ID); a write that fails
;    there asks again (write-protected?); Esc in a prompt gives the caller the error
;  - TEMP\ (CONTACTS.DTA, LPT1) lives in RAM files
;  - files with table flag 1 (the bridge, the contact screen's own files) are kept in a RAM
;    cache once read (FLP_CACHE bytes, set by the program; MAIN), so going back to the bridge
;    never needs a swap
;  - the size of the music region drops to FLP_REGION (no stream ring on the floppies)
; The prompt takes over the display (one band, black/white, own screen) without touching the
; program's screens and puts them back. hdv_mediach tells TOS the disk changed after a prompt;
; etv_critic returns the error (no alert boxes). flp_exit (sys_restore) puts both back.
;
; flp_init   (sys_init, supervisor, before snd_init)
; flp_exit   (sys_restore)
; flp_dos    in: the GEMDOS call's word and arguments on the stack below the return address
;            out: d0.l as GEMDOS  trashes: d0-d2/a0-a2

	ifnd	FLP_CACHE
FLP_CACHE	equ	0
	endc
FLP_REGION	equ	704*1024	; > VOID.MOD's 640 KB (file + padded samples)
FLP_TEMP	equ	48*1024+2*20*1024
FLP_FH		equ	$7000		; first RAM file handle
FLP_NH		equ	6		; open RAM files at once
FLP_NF		equ	24		; RAM files (TEMP + cache)
RF_NAME		equ	0		; 32 bytes, upper case
RF_BASE		equ	32
RF_SIZE		equ	36
RF_CAP		equ	40		; 0: read-only (cache)
RF_USED		equ	44		; w
RF_SIZEOF	equ	46
TE_MASK		equ	0		; table entry: w disks, w flags, name
TE_FLAGS	equ	2
TE_NAME		equ	4
TF_KEEP		equ	1
TF_MUSIC	equ	2
HDV_MEDIACH	equ	$47e
ETV_CRITIC	equ	$404

	section	text
flp_init:
	movem.l	d3-d4,-(sp)
	clr.w	flp_on
	move.l	#MOD_REGION,mod_rsize
	GEMDOS	$19,2			; Dgetdrv
	cmp.w	#2,d0
	bcc	.x
	move.w	d0,flp_drv
	clr.w	-(sp)
	pea	flp_fn_tab
	GEMDOS	GD_FOPEN,8
	move.l	d0,d3
	bmi	.x
	move.w	#2,-(sp)		; size
	move.w	d3,-(sp)
	clr.l	-(sp)
	GEMDOS	GD_FSEEK,10
	move.l	d0,d4
	clr.w	-(sp)
	move.w	d3,-(sp)
	clr.l	-(sp)
	GEMDOS	GD_FSEEK,10
	move.l	d4,d0
	bsr	mem_alloc
	bcs	.cl
	move.l	a0,flp_tab
	move.l	a0,-(sp)
	move.l	d4,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FREAD,12
	cmp.l	d4,d0
	bne	.cl
	move.l	flp_tab,a0
	cmp.l	#'ISD1',(a0)
	bne	.cl
	move.w	4(a0),flp_cur
	move.w	6(a0),flp_count
	move.w	8(a0),flp_save
	move.l	#FLP_TEMP,d0		; RAM for TEMP\ and the cache
	bsr	mem_alloc
	bcs	.cl
	move.l	a0,flp_ttop
	add.l	#FLP_TEMP,a0
	move.l	a0,flp_tend
	move.l	#FLP_CACHE+16,d0
	bsr	mem_alloc
	bcs.s	.cl
	move.l	a0,flp_ctop
	add.l	#FLP_CACHE,a0
	move.l	a0,flp_cend
	move.w	#1,flp_on
	move.l	#FLP_REGION,mod_rsize
	dc.w	$a000			; the 8x8 system font for the prompt
	move.l	4(a1),a0
	move.l	76(a0),flp_font
	move.w	80(a0),flp_fontw
	DI
	move.l	HDV_MEDIACH.w,flp_oldmc
	move.l	#flp_mediach,HDV_MEDIACH.w
	move.l	ETV_CRITIC.w,flp_oldcrit
	move.l	#flp_critic,ETV_CRITIC.w
	EI
.cl:	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
.x:	movem.l	(sp)+,d3-d4
	rts

flp_exit:
	tst.w	flp_on
	beq.s	.x
	clr.w	flp_on
	move.l	flp_oldmc,HDV_MEDIACH.w
	move.l	flp_oldcrit,ETV_CRITIC.w
.x:	rts

; hdv_mediach(dev): "changed" once after a prompt, else TOS's own answer
flp_mediach:
	move.w	4(sp),d0
	cmp.w	flp_drv,d0
	bne.s	.old
	tst.w	flp_force
	beq.s	.old
	clr.w	flp_force
	moveq	#2,d0
	rts
.old:	move.l	flp_oldmc,-(sp)
	rts

; etv_critic(error, dev): give the error back (no alert box over the game)
flp_critic:
	move.w	4(sp),d0
	ext.l	d0
	rts

; ---------------------------------------------------------------
flp_dos:
	tst.w	flp_on
	bne.s	.f
	move.l	(sp)+,flp_ret
	trap	#1
	move.l	flp_ret,-(sp)
	rts
.f:	movem.l	d3-d7/a3-a5,-(sp)
	lea	36(sp),a5		; a5 -> the function word, arguments from 2(a5)
	move.w	(a5),d0
	cmp.w	#GD_FREAD,d0
	beq	flp_read
	cmp.w	#GD_FWRITE,d0
	beq	flp_write
	cmp.w	#GD_FSEEK,d0
	beq	flp_seek
	cmp.w	#GD_FCLOSE,d0
	beq	flp_close
	move.l	2(a5),a3		; the others: a name
	bsr	flp_class
	cmp.w	#GD_FOPEN,(a5)
	beq	flp_open
	cmp.w	#GD_FCREATE,(a5)
	beq	flp_create
	cmp.w	#GD_DCREATE,(a5)
	beq	flp_dcreate
	cmp.w	#GD_FDELETE,(a5)
	beq	flp_delete
flp_raw:				; the call itself (up to 12 bytes of arguments)
	bsr.s	flp_trap
flp_ret0:
	movem.l	(sp)+,d3-d7/a3-a5
	rts
flp_trap:
	move.l	10(a5),-(sp)
	move.l	6(a5),-(sp)
	move.l	2(a5),-(sp)
	move.w	(a5),-(sp)
	trap	#1
	lea	14(sp),sp
	rts
flp_err33:
	moveq	#-33,d0
	bra.s	flp_ret0

; a3 = name  out: d0.w = 0 not ours (drive given), 1 TEMP\, 2 the save disk, 3 data (a4 = table
; entry), 4 not on the floppies   trashes: d0-d2/a0-a2/a4
flp_class:
	moveq	#0,d0
	move.l	a3,a0
.c:	move.b	(a0)+,d1
	beq.s	.nc
	cmp.b	#':',d1
	bne.s	.c
	rts
.nc:	lea	flp_s_temp,a1
	bsr	flp_prefix
	beq.s	.temp
	lea	flp_s_dir,a1
	bsr	flp_prefix
	beq.s	.save
	lea	flp_s_save,a1
	bsr	flp_prefix
	bne.s	.tab
	move.b	4(a3),d1		; SAVEn\
	sub.b	#'0',d1
	cmp.b	#9,d1
	bhi.s	.tab
.save:	moveq	#2,d0
	rts
.temp:	moveq	#1,d0
	rts
.tab:	move.l	flp_tab,a4
	lea	10(a4),a4
	move.w	flp_count,d2
	bra.s	.ne
.e:	lea	TE_NAME(a4),a1
	move.l	a3,a0
.cmp:	move.b	(a0)+,d0
	cmp.b	#'a',d0
	blo.s	.u
	cmp.b	#'z',d0
	bhi.s	.u
	sub.b	#32,d0
.u:	move.b	(a1)+,d1
	cmp.b	d0,d1
	bne.s	.next
	tst.b	d0
	bne.s	.cmp
	moveq	#3,d0
	rts
.next:	lea	TE_NAME(a4),a1		; skip this entry's name
.sk:	tst.b	(a1)+
	bne.s	.sk
	move.l	a1,d0
	addq.l	#1,d0
	and.w	#$fffe,d0
	move.l	d0,a4
.ne:	dbf	d2,.e
	moveq	#4,d0
	rts

; Z set if a3's name starts with a1's (upper case; "TEMP" also matches TEMP itself)
flp_prefix:
	move.l	a3,a0
.l:	move.b	(a1)+,d1
	beq.s	.y
	move.b	(a0)+,d0
	cmp.b	#'a',d0
	blo.s	.u
	cmp.b	#'z',d0
	bhi.s	.u
	sub.b	#32,d0
.u:	cmp.b	d0,d1
	beq.s	.l
	cmp.b	#92,d1			; "TEMP\" against "TEMP"
	bne.s	.n
	tst.b	d0
	bne.s	.n
.y:	moveq	#0,d0
	rts
.n:	moveq	#1,d0
	rts

; ---------------------------------------------------------------
; Fopen(a3, 6(a5) mode)
flp_open:
	cmp.w	#1,d0
	beq	flp_ropen
	cmp.w	#2,d0
	bne.s	.n2
	bsr	flp_needsave
	bcs	flp_err33
	bra	flp_raw
.n2:	cmp.w	#3,d0
	bne	flp_trapx
	move.w	TE_FLAGS(a4),d0		; kept in the cache?
	and.w	#TF_KEEP,d0
	beq.s	.disk
	tst.w	6(a5)
	bne.s	.disk
	bsr	flp_cfind
	bcs.s	.disk
	bsr	flp_hnew
	bcc	flp_ret0
.disk:	bsr	flp_ondisk		; the right disk in the drive (or music: give up)
	bcs	flp_ret0
	bsr	flp_trap
	move.l	d0,d5
	bmi.s	.fail
	move.w	TE_MASK(a4),d1		; on success: this disk is known when the file is on one
	bsr	flp_one
	beq.s	.many
	move.w	d1,flp_cur
	bra.s	.kn
.many:	move.w	flp_cur,d1		; on several: the known one stays if it is among them
	bsr	flp_bit
	and.w	TE_MASK(a4),d1
	bne.s	.kn
	clr.w	flp_cur
.kn:	clr.w	flp_notm
	move.l	d5,d0
	move.w	TE_FLAGS(a4),d1
	and.w	#TF_KEEP,d1
	beq	flp_ret0
	tst.w	6(a5)
	bne	flp_ret0
	bsr	flp_cadd		; read it into the cache (d0 = handle); a RAM handle if it fits
	bra	flp_ret0
.fail:	move.w	TE_MASK(a4),d1		; not here: those disks are not in the drive
	or.w	d1,flp_notm
	clr.w	flp_cur
	bra.s	.disk
flp_trapx:
	cmp.w	#4,d0
	beq	flp_err33
	bra	flp_raw

; the disk for table entry a4 in the drive: prompts until it is (the caller then tries the
; call); carry set (d0 = -33) on Esc, or for music not in the drive
flp_ondisk:
.l:	move.w	TE_MASK(a4),d1
	move.w	flp_cur,d0
	beq.s	.unk
	move.w	d0,d1			; known disk: in the mask?
	bsr	flp_bit
	and.w	TE_MASK(a4),d1
	bne.s	.ok
	bra.s	.ask
.unk:	not.w	d1			; unknown: only if it may still be there
	or.w	flp_notm,d1
	not.w	d1
	bne.s	.ok
.ask:	move.w	TE_FLAGS(a4),d0
	and.w	#TF_MUSIC,d0
	bne.s	.no
	move.w	TE_MASK(a4),d1		; the first of its disks - one with the song waiting for its
	tst.b	mod_defer		; disk if it can (a screen asks for its song first: mod.s)
	beq.s	.f0
	move.l	mod_defent,a0
	move.w	TE_MASK(a0),d0
	and.w	d1,d0
	beq.s	.f0
	move.w	d0,d1
.f0:	moveq	#0,d0
.f:	addq.w	#1,d0
	lsr.w	#1,d1
	bcc.s	.f
	bsr	flp_prompt
	bcc.s	.l
.no:	moveq	#-33,d0
	or.b	#1,ccr
	rts
.ok:	and.b	#$fe,ccr
	rts

; d1.w = disk n (1-16) -> d1.w = its mask bit   trashes: d0
flp_bit:
	move.w	d1,d0
	moveq	#0,d1
	subq.w	#1,d0
	bmi.s	.x
	bset	d0,d1
.x:	rts

; d1.w = mask: Z clear and d1.w = the disk if one bit only   trashes: d0/d2
flp_one:
	moveq	#0,d0
	moveq	#0,d2
.l:	addq.w	#1,d0
	lsr.w	#1,d1
	bcc.s	.n
	tst.w	d2
	bne.s	.m
	move.w	d0,d2
.n:	tst.w	d1
	bne.s	.l
	move.w	d2,d1
	rts
.m:	moveq	#0,d1
	rts

; the save disk in the drive (marker \ISSAVE.ID): carry set on Esc
flp_needsave:
	move.w	flp_cur,d0
	cmp.w	flp_save,d0
	beq.s	.ok
.l:	clr.w	-(sp)
	pea	flp_fn_save
	GEMDOS	GD_FOPEN,8
	tst.l	d0
	bmi.s	.ask
	move.w	d0,-(sp)
	GEMDOS	GD_FCLOSE,4
	move.w	flp_save,flp_cur
	clr.w	flp_notm
.ok:	and.b	#$fe,ccr
	rts
.ask:	moveq	#0,d0
	bsr	flp_prompt
	bcc.s	.l
	rts

; Fcreate(a3, attr)
flp_create:
	cmp.w	#1,d0
	beq	flp_rcreate
	cmp.w	#2,d0
	bne	flp_trapx
.l:	bsr	flp_needsave
	bcs	flp_ret0
	bsr	flp_trap
	tst.l	d0
	bpl	flp_ret0
	moveq	#-1,d0			; cannot write: write-protected or full?
	bsr	flp_prompt
	bcc.s	.l
	moveq	#-13,d0
	bra	flp_ret0

; Dcreate(a3)
flp_dcreate:
	cmp.w	#1,d0
	bne.s	.n
	moveq	#0,d0			; TEMP: there
	bra	flp_ret0
.n:	cmp.w	#2,d0
	bne	flp_trapx
	bsr	flp_needsave
	bcs	flp_ret0
	bra	flp_raw

; Fdelete(a3)
flp_delete:
	cmp.w	#1,d0
	bne.s	.n
	bsr	flp_rfind
	bcs	flp_err33
	clr.w	RF_USED(a0)
	moveq	#0,d0
	bra	flp_ret0
.n:	cmp.w	#2,d0
	bne	flp_trapx
	bsr	flp_needsave
	bcs	flp_ret0
	bra	flp_raw

; ---------------------------------------------------------------- RAM files
; a RAM handle d0.w -> a1 = its slot (carry set if not a RAM handle)
flp_hslot:
	sub.w	#FLP_FH,d0
	bcs.s	.no
	cmp.w	#FLP_NH,d0
	bcc.s	.no
	lsl.w	#3,d0
	lea	flp_hand,a1
	add.w	d0,a1
	tst.l	(a1)
	beq.s	.no
	and.b	#$fe,ccr
	rts
.no:	or.b	#1,ccr
	rts

; a new handle on RAM file a0: d0.l = handle (carry set: none free)
flp_hnew:
	lea	flp_hand,a1
	moveq	#0,d0
.l:	tst.l	(a1)
	beq.s	.f
	addq.l	#8,a1
	addq.w	#1,d0
	cmp.w	#FLP_NH,d0
	blo.s	.l
	or.b	#1,ccr
	rts
.f:	move.l	a0,(a1)
	clr.l	4(a1)
	add.l	#FLP_FH,d0
	and.b	#$fe,ccr
	rts

; the RAM file named a3 (TEMP or cache): a0 (carry set if none)
flp_rfind:
	lea	flp_files,a0
	moveq	#FLP_NF-1,d2
.l:	tst.w	RF_USED(a0)
	beq.s	.n
	lea	RF_NAME(a0),a1
	move.l	a3,a2
.c:	move.b	(a2)+,d0
	cmp.b	#'a',d0
	blo.s	.u
	cmp.b	#'z',d0
	bhi.s	.u
	sub.b	#32,d0
.u:	cmp.b	(a1)+,d0
	bne.s	.n
	tst.b	d0
	bne.s	.c
	and.b	#$fe,ccr
	rts
.n:	lea	RF_SIZEOF(a0),a0
	dbf	d2,.l
	or.b	#1,ccr
	rts

; a free RAM file slot named a3: a0 (carry set if none or the name is too long)
flp_rnew:
	lea	flp_files,a0
	moveq	#FLP_NF-1,d2
.l:	tst.w	RF_USED(a0)
	beq.s	.f
	lea	RF_SIZEOF(a0),a0
	dbf	d2,.l
.no:	or.b	#1,ccr
	rts
.f:	move.l	a3,a2
	lea	RF_NAME(a0),a1
	moveq	#31,d2
.c:	move.b	(a2)+,d0
	cmp.b	#'a',d0
	blo.s	.u
	cmp.b	#'z',d0
	bhi.s	.u
	sub.b	#32,d0
.u:	move.b	d0,(a1)+
	beq.s	.ok
	dbf	d2,.c
	bra.s	.no
.ok:	clr.l	RF_SIZE(a0)
	and.b	#$fe,ccr
	rts

flp_ropen:
	bsr	flp_rfind
	bcs	flp_err33
	bsr	flp_hnew
	bcc	flp_ret0
	moveq	#-35,d0			; (ENHNDL)
	bra	flp_ret0

flp_rcreate:
	bsr	flp_rfind
	bcc.s	.tr
	bsr	flp_rnew
	bcs.s	.full
	move.l	#20*1024,d1		; a buffer: CONTACTS.DTA 48 KB, others 20 KB, kept for
	lea	flp_s_cont,a1		; the file (a later Fcreate truncates it)
	move.l	a3,a2
.cm:	move.b	(a1)+,d0
	cmp.b	(a2)+,d0
	bne.s	.sz
	tst.b	d0
	bne.s	.cm
	move.l	#48*1024,d1
.sz:	move.l	flp_ttop,a1
	add.l	d1,a1
	cmp.l	flp_tend,a1
	bhi.s	.full
	move.l	flp_ttop,RF_BASE(a0)
	move.l	a1,flp_ttop
	move.l	d1,RF_CAP(a0)
	move.w	#1,RF_USED(a0)
.tr:	tst.l	RF_CAP(a0)
	beq.s	.full
	clr.l	RF_SIZE(a0)
	bsr	flp_hnew
	bcc	flp_ret0
	moveq	#-35,d0
	bra	flp_ret0
.full:	moveq	#-39,d0
	bra	flp_ret0

; Fread(2(a5) h, 4(a5) count, 8(a5) buffer)
flp_read:
	move.w	2(a5),d0
	bsr	flp_hslot
	bcs	flp_raw
	move.l	(a1),a0
	move.l	RF_SIZE(a0),d0
	sub.l	4(a1),d0		; left
	cmp.l	4(a5),d0
	bls.s	.n
	move.l	4(a5),d0
.n:	move.l	d0,d3
	move.l	RF_BASE(a0),a0
	add.l	4(a1),a0
	add.l	d3,4(a1)
	move.l	8(a5),a1
	move.l	d3,d0
	bsr	fil_copy
	move.l	d3,d0
	bra	flp_ret0

; Fwrite(h, count, buffer)
flp_write:
	move.w	2(a5),d0
	bsr	flp_hslot
	bcs	flp_raw
	move.l	(a1),a0
	move.l	RF_CAP(a0),d0
	bne.s	.w
	moveq	#-36,d0			; (EACCDN: the cache is read-only)
	bra	flp_ret0
.w:	sub.l	4(a1),d0		; room
	cmp.l	4(a5),d0
	bls.s	.n
	move.l	4(a5),d0
.n:	move.l	d0,d3
	move.l	a0,a4
	move.l	RF_BASE(a0),a0
	add.l	4(a1),a0
	add.l	d3,4(a1)
	move.l	4(a1),d0
	cmp.l	RF_SIZE(a4),d0
	bls.s	.s
	move.l	d0,RF_SIZE(a4)
.s:	move.l	a0,a1
	move.l	8(a5),a0
	move.l	d3,d0
	bsr	fil_copy
	move.l	d3,d0
	bra	flp_ret0

; Fseek(2(a5) offset, 6(a5) h, 8(a5) mode)
flp_seek:
	move.w	6(a5),d0
	bsr	flp_hslot
	bcs	flp_raw
	move.l	(a1),a0
	move.l	2(a5),d0
	move.w	8(a5),d1
	beq.s	.set
	subq.w	#1,d1
	bne.s	.end
	add.l	4(a1),d0
	bra.s	.set
.end:	add.l	RF_SIZE(a0),d0
.set:	tst.l	d0
	bmi.s	.rng
	cmp.l	RF_SIZE(a0),d0
	bhi.s	.rng
	move.l	d0,4(a1)
	bra	flp_ret0
.rng:	moveq	#-64,d0
	bra	flp_ret0

flp_close:
	move.w	2(a5),d0
	bsr	flp_hslot
	bcs	flp_raw
	clr.l	(a1)
	moveq	#0,d0
	bra	flp_ret0

; ---------------------------------------------------------------- cache
; the cached copy of a3: a0 (carry set if none)
flp_cfind:
	bsr	flp_rfind
	bcs.s	.x
	tst.l	RF_CAP(a0)		; (a TEMP file of the same name: not the cache)
	beq.s	.x
	or.b	#1,ccr
.x:	rts

; d0 = the handle just opened on a3: read the whole file into the cache and give a RAM handle
; instead (d0); left as it is when it does not fit
flp_cadd:
	move.l	d0,d3
	move.w	#2,-(sp)
	move.w	d3,-(sp)
	clr.l	-(sp)
	GEMDOS	GD_FSEEK,10
	move.l	d0,d4			; size
	clr.w	-(sp)
	move.w	d3,-(sp)
	clr.l	-(sp)
	GEMDOS	GD_FSEEK,10
	tst.l	d4
	ble	.keep
	move.l	flp_ctop,d0
	add.l	d4,d0
	cmp.l	flp_cend,d0
	bhi.s	.keep
	bsr	flp_rnew
	bcs.s	.keep
	move.l	a0,a4
	move.l	flp_ctop,-(sp)
	move.l	d4,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FREAD,12
	cmp.l	d4,d0
	bne.s	.rew
	move.l	flp_ctop,RF_BASE(a4)
	move.l	d4,RF_SIZE(a4)
	clr.l	RF_CAP(a4)
	move.w	#1,RF_USED(a4)
	move.l	d4,d0
	addq.l	#1,d0
	and.w	#$fffe,d0
	add.l	d0,flp_ctop
	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
	move.l	a4,a0
	bsr	flp_hnew
	bcs.s	.reopen
	rts
.reopen:				; (no RAM handle free: the real file again)
	clr.w	-(sp)
	move.l	a3,-(sp)
	GEMDOS	GD_FOPEN,8
	rts
.rew:	clr.w	-(sp)			; read failed: back to the start, the caller reads it
	move.w	d3,-(sp)
	clr.l	-(sp)
	GEMDOS	GD_FSEEK,10
.keep:	move.l	d3,d0
	rts

; ---------------------------------------------------------------- the prompt
; d0.w = disk n (1-15), 0 = the save disk, -1 = a write on the save disk failed.
; Shows the request over the display until a key or the left button; carry set on Esc.
; Afterwards TOS is told the disk changed (hdv_mediach).  trashes: d0-d2/a0-a2
flp_prompt:
	movem.l	d3-d4/a3,-(sp)
	move.w	d0,d3
	ifd	FLPNF			; (test builds: tell the Hatari driver, NatFeats NF_STDERR;
	bsr	flp_nf			; a3 = the file asked for)
	move.w	d3,d0
	endc
	moveq	#50,d4			; let a pending flip or palette land (at most 1 s)
.w:	tst.l	vid_pending
	bne.s	.ws
	tst.l	vid_palnext
	beq.s	.wd
.ws:	bsr	vid_vsync
	dbf	d4,.w
.wd:	bsr	mem_mark
	move.l	d0,-(sp)
	move.l	#SCR_SIZE,d0
	bsr	mem_alloc
	bcc.s	.buf
	move.l	vid_spare,a0
.buf:	move.l	a0,a3
	bsr	vid_clear
	lea	flp_m_save,a0		; the lines
	lea	flp_m_ins2,a1
	tst.w	d3
	beq.s	.t
	bpl.s	.d
	lea	flp_m_werr,a0
	lea	flp_m_wer2,a1
	bra.s	.t
.d:	lea	flp_m_disk,a0
	move.w	d3,d0
	add.b	#'0',d0
	move.b	d0,flp_m_dn		; (disks 1-9)
.t:	move.l	a1,-(sp)
	moveq	#88,d1
	bsr	flp_line
	move.l	(sp)+,a0
	move.w	flp_drv,d0
	add.b	#'A',d0
	move.b	d0,flp_m_drv
	moveq	#100,d1
	bsr	flp_line
	lea	flp_m_esc,a0
	moveq	#120,d1
	bsr	flp_line
	DI				; one band, black and white, this screen
	move.l	vid_cur,flp_oldcur
	move.l	#flp_bands,vid_cur
	move.l	a3,d0
	bsr	flp_base
	EI
.fk:	bsr	flp_key			; old keys and clicks away (the real keyboard and mouse
	bpl.s	.fk			; only: a test script's input is left to the program)
	clr.b	kbd_mclick
.wait:	bsr	vid_vsync
	btst	#0,kbd_mclick
	bne.s	.go
	bsr	flp_key
	bmi.s	.wait
	move.b	d0,d4
.k:	cmp.b	#27,d4
	beq.s	.esc
.go:	moveq	#0,d4
	bra.s	.back
.esc:	moveq	#1,d4
.back:	clr.b	kbd_mclick
	DI
	move.l	flp_oldcur,vid_cur
	move.l	vid_written,d0
	bsr	flp_base
	EI
	move.l	(sp)+,d0
	bsr	mem_release
	move.w	#1,flp_force		; TOS: the disk changed
	clr.w	flp_cur
	clr.w	flp_notm
	tst.w	d4
	beq.s	.ok
	movem.l	(sp)+,d3-d4/a3
	or.b	#1,ccr
	rts
.ok:	movem.l	(sp)+,d3-d4/a3
	and.b	#$fe,ccr
	rts

	ifd	FLPNF
; d0.w = the prompt's code: "FLP-PROMPT n" on Hatari's stderr   trashes: d0-d2/a0-a2
flp_nf:
	lea	flp_nfmsg+11,a0
	move.b	#'S',(a0)		; save disk
	tst.w	d0
	beq.s	.c
	move.b	#'W',(a0)		; write error
	tst.w	d0
	bmi.s	.c
	add.b	#'0',d0
	move.b	d0,(a0)
.c:	lea	flp_nfmsg+13,a1		; + the name
	move.l	a3,a0
	moveq	#40,d1
.n:	move.b	(a0)+,(a1)+
	dbeq	d1,.n
	move.b	#10,-1(a1)
	clr.b	(a1)
	pea	flp_nfid
	bsr.s	.id
	addq.l	#4,sp
	pea	flp_nfmsg
	move.l	d0,-(sp)
	bsr.s	.call
	addq.l	#8,sp
	rts
.id:	dc.w	$7300			; NF_ID (arguments above a return address)
	rts
.call:	dc.w	$7301			; NF_CALL
	rts
	endc

; a key from TOS: d0.w = its ASCII code (0 for keys without one), N set if none
flp_key:
	move.w	#2,-(sp)
	BIOS	BI_BCONSTAT,4
	tst.w	d0
	beq.s	.no
	move.w	#2,-(sp)
	BIOS	BI_BCONIN,4
	and.w	#$ff,d0
	rts
.no:	moveq	#-1,d0
	rts

; video base := d0.l (STE: high, mid, then low - writing high or mid clears low)  trashes: d0-d1
flp_base:
	move.l	d0,d1
	swap	d0
	move.b	d0,VID_BASEH.w
	move.w	d1,d0
	lsr.w	#8,d0
	move.b	d0,VID_BASEM.w
	move.b	d1,VID_BASEL.w
	rts

; the C string a0 centred on line d1 of screen a3 in plane 0 (colour 1)   trashes: d0-d2/a0-a2
flp_line:
	move.l	a0,a1			; length
.n:	tst.b	(a1)+
	bne.s	.n
	sub.l	a0,a1
	subq.w	#1,a1
	moveq	#40,d0
	sub.w	a1,d0
	lsr.w	#1,d0			; first column
	mulu	#SCR_BPL,d1
	move.l	a3,a2
	add.l	d1,a2
.c:	moveq	#0,d1
	move.b	(a0)+,d1
	beq.s	.x
	move.l	flp_font,a1
	add.w	d1,a1
	move.w	d0,d1			; column -> byte: (c/2)*8 + (c&1)
	lsr.w	#1,d1
	lsl.w	#3,d1
	btst	#0,d0
	beq.s	.e
	addq.w	#1,d1
.e:	movem.l	d0/a2,-(sp)
	add.w	d1,a2
	moveq	#8-1,d2
.r:	move.b	(a1),(a2)
	add.w	flp_fontw,a1
	lea	SCR_BPL(a2),a2
	dbf	d2,.r
	movem.l	(sp)+,d0/a2
	addq.w	#1,d0
	bra.s	.c
.x:	rts

	section	data
flp_fn_tab:	dc.b	92,"ISDISK.TAB",0
flp_fn_save:	dc.b	92,"ISSAVE.ID",0
flp_s_temp:	dc.b	"TEMP",92,0
flp_s_dir:	dc.b	"SAVEGAME.DIR",0
flp_s_save:	dc.b	"SAVE",0
flp_s_cont:	dc.b	"TEMP",92,"CONTACTS.DTA",0
flp_m_disk:	dc.b	"Please insert Iron Seed disk "
flp_m_dn:	dc.b	"1",0
flp_m_save:	dc.b	"Please insert the Iron Seed save disk",0
flp_m_ins2:	dc.b	"in drive "
flp_m_drv:	dc.b	"A and press a key.",0
flp_m_werr:	dc.b	"The save disk cannot be written.",0
flp_m_wer2:	dc.b	"Write-protected? Fix it, press a key.",0
flp_m_esc:	dc.b	"(Esc: cancel)",0
	ifd	FLPNF
flp_nfid:	dc.b	"NF_STDERR",0
flp_nfmsg:	dc.b	"FLP-PROMPT x "
		ds.b	44
	endc
	even
flp_bands:	dc.w	1,0
		dc.w	$000,$fff,$888,$fff,$fff,$fff,$fff,$fff
		dc.w	$fff,$fff,$fff,$fff,$fff,$fff,$fff,$fff

	section	bss
flp_ret:	ds.l	1
flp_tab:	ds.l	1
flp_font:	ds.l	1
flp_oldmc:	ds.l	1
flp_oldcrit:	ds.l	1
flp_oldcur:	ds.l	1
flp_ttop:	ds.l	1
flp_tend:	ds.l	1
flp_ctop:	ds.l	1
flp_cend:	ds.l	1
flp_hand:	ds.l	2*FLP_NH
flp_files:	ds.b	RF_SIZEOF*FLP_NF
	even
flp_on:		ds.w	1
flp_drv:	ds.w	1
flp_cur:	ds.w	1		; the disk known to be in the drive (0: unknown)
flp_notm:	ds.w	1		; disks known not to be in the drive
flp_save:	ds.w	1
flp_count:	ds.w	1
flp_force:	ds.w	1
flp_fontw:	ds.w	1
	even
