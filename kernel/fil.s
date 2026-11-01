; fil.s - files (GEMDOS; main code only, never from interrupts). Part of kernel.s.
;
; fil_load   in: a0 = name (C string), a1 = buffer, d0.l = max bytes
;            out: d0.l = bytes read; carry set + d0 = TOS error if it failed
;            trashes: d0-d2/a0-a2
; fil_save   in: a0 = name, a1 = data, d0.l = bytes   out: carry set on error
; fil_size   in: a0 = name   out: d0.l = size (carry set if missing)
; fil_mkdir  in: a0 = folder name: Dcreate (an existing folder is not an error)
;            trashes: d0-d2/a0-a2
; fil_loadat in: a0 = name, a1 = buffer, d0.l = offset, d1.l = bytes  (Phase 8: a part of a
;            file, packed or not)  out: carry set + d0 = TOS error if it failed  trashes: d0-d2/a0-a2
;
; Phase 8 (the floppy version): a file may be packed by tools/mkfloppy.py - FIL_HDR bytes:
; 'ISZ1', l unpacked size, l delta start (0: none; from there the bytes are deltas, the MODs'
; samples), then raw deflate (kernel inflate.s). fil_size gives the unpacked size, fil_load and
; fil_loadat the unpacked bytes: the packed data and, for a part, the whole file are unpacked
; in temporary pool blocks (mem_mark/mem_release; the packed bytes go to fil_tmp instead when
; fil_tmpn is enough - mod_load's music region). Unpacked files load as before.
FIL_HDR		equ	12

	section	text
fil_load:
	movem.l	d3-d5/a3-a4,-(sp)
	move.l	a1,a3
	move.l	d0,d4			; max
	clr.w	-(sp)			; Fopen(name, read)
	move.l	a0,-(sp)
	FDOS	GD_FOPEN,8
	tst.l	d0
	bmi	.err
	move.w	d0,d3
	bsr	fil_hdr			; packed?
	bne.s	.pk
	move.l	a3,-(sp)		; Fread(h, max, buf)
	move.l	d4,-(sp)
	move.w	d3,-(sp)
	FDOS	GD_FREAD,12
	move.l	d0,d4
	move.w	d3,-(sp)
	FDOS	GD_FCLOSE,4
	move.l	d4,d0
	bmi.s	.err
	movem.l	(sp)+,d3-d5/a3-a4
	and.b	#$fe,ccr
	rts
.pk:	bsr	mem_mark		; packed: unpack (into a temporary block if only a part is
	move.l	d0,d5			; wanted), then the part
	move.l	a3,a4
	move.l	fil_usize,d0
	cmp.l	d0,d4
	bhs.s	.whole
	bsr	mem_alloc
	bcs.s	.nomem
	move.l	a0,a4
.whole:	move.l	a4,a1
	bsr	fil_unpack		; (closes the file)
	bcs.s	.uerr
	cmp.l	a3,a4
	beq.s	.done
	move.l	a4,a0			; the part
	move.l	a3,a1
	move.l	d4,d0
	bsr	fil_copy
.done:	move.l	d5,d0
	bsr	mem_release
	move.l	fil_usize,d0
	cmp.l	d0,d4
	bhs.s	.ok
	move.l	d4,d0
.ok:	movem.l	(sp)+,d3-d5/a3-a4
	and.b	#$fe,ccr
	rts
.nomem:	move.w	d3,-(sp)
	FDOS	GD_FCLOSE,4
	moveq	#-39,d0			; (ENSMEM)
.uerr:	move.l	d0,-(sp)
	move.l	d5,d0
	bsr	mem_release
	move.l	(sp)+,d0
.err:	movem.l	(sp)+,d3-d5/a3-a4
	or.b	#1,ccr
	rts

; fil_hdr: d3.w = an open handle: read FIL_HDR bytes; packed -> Z clear, fil_usize/fil_delta/
; fil_psize set (the file positioned after the header); not packed -> Z set, back at 0.
; trashes: d0-d2/a0-a2
fil_hdr:
	pea	fil_h
	pea	FIL_HDR
	move.w	d3,-(sp)
	FDOS	GD_FREAD,12
	cmp.l	#FIL_HDR,d0
	bne.s	.no
	cmp.l	#'ISZ1',fil_h
	bne.s	.no
	move.l	fil_h+4,fil_usize
	move.l	fil_h+8,fil_delta
	move.w	#2,-(sp)		; the packed size: Fseek(0, h, end) - FIL_HDR, back after the header
	move.w	d3,-(sp)
	clr.l	-(sp)
	FDOS	GD_FSEEK,10
	sub.l	#FIL_HDR,d0
	move.l	d0,fil_psize
	clr.w	-(sp)
	move.w	d3,-(sp)
	pea	FIL_HDR
	FDOS	GD_FSEEK,10
	moveq	#1,d0			; Z clear
	rts
.no:	clr.w	-(sp)			; Fseek(0, h, start)
	move.w	d3,-(sp)
	clr.l	-(sp)
	FDOS	GD_FSEEK,10
	moveq	#0,d0			; Z set
	rts

; fil_unpack: d3.w = the open handle after fil_hdr (packed), a1 = output (fil_usize bytes):
; the packed bytes into a temporary block, inflated, the deltas undone; the file closed.
; out: carry set + d0 = TOS error  trashes: d0-d2/a0-a2
fil_unpack:
	movem.l	d4/a3-a4,-(sp)
	move.l	a1,a4
	move.l	fil_psize,d0
	addq.l	#4,d0			; (inflate may read 3 bytes beyond)
	move.l	fil_tmp,a0		; the caller's spare room (mod_load: the music region)?
	cmp.l	fil_tmpn,d0
	bls.s	.tmp
	bsr	mem_alloc
	bcs.s	.nomem
.tmp:	move.l	a0,a3
	move.l	a3,-(sp)
	move.l	fil_psize,-(sp)
	move.w	d3,-(sp)
	FDOS	GD_FREAD,12
	move.l	d0,d4
	move.w	d3,-(sp)
	FDOS	GD_FCLOSE,4
	move.l	d4,d0
	bmi.s	.err
	move.l	a3,a0
	move.l	a4,a1
	bsr	inf_inflate
	bcs.s	.bad
	move.l	fil_delta,d0		; the deltas (a MOD's samples)
	beq.s	.ok
	move.l	fil_usize,d1
	sub.l	d0,d1
	bls.s	.ok
	lea	0(a4,d0.l),a0
	moveq	#0,d0
.dl:	add.b	(a0),d0
	move.b	d0,(a0)+
	subq.l	#1,d1
	bne.s	.dl
.ok:	movem.l	(sp)+,d4/a3-a4
	and.b	#$fe,ccr
	rts
.nomem:	move.w	d3,-(sp)
	FDOS	GD_FCLOSE,4
	moveq	#-39,d0
	bra.s	.err
.bad:	moveq	#-65,d0			; (EINTRN: not our data)
.err:	movem.l	(sp)+,d4/a3-a4
	or.b	#1,ccr
	rts

; a0 -> a1, d0.l bytes  trashes: d0-d1/a0-a1
fil_copy:
	bra.s	.c
.l:	move.b	(a0)+,(a1)+
.c:	subq.l	#1,d0
	bpl.s	.l
	rts

fil_loadat:
	movem.l	d3-d6/a3-a4,-(sp)
	move.l	a1,a3
	move.l	d0,d5			; offset
	move.l	d1,d4			; bytes
	clr.w	-(sp)
	move.l	a0,-(sp)
	FDOS	GD_FOPEN,8
	tst.l	d0
	bmi	.err
	move.w	d0,d3
	bsr	fil_hdr
	bne.s	.pk
	clr.w	-(sp)			; Fseek(offset, h, start)
	move.w	d3,-(sp)
	move.l	d5,-(sp)
	FDOS	GD_FSEEK,10
	move.l	a3,-(sp)
	move.l	d4,-(sp)
	move.w	d3,-(sp)
	FDOS	GD_FREAD,12
	move.l	d0,d6
	move.w	d3,-(sp)
	FDOS	GD_FCLOSE,4
	move.l	d6,d0
	bmi.s	.err
	movem.l	(sp)+,d3-d6/a3-a4
	and.b	#$fe,ccr
	rts
.pk:	bsr	mem_mark		; packed: the whole file into a temporary block, then the part
	move.l	d0,d6
	move.l	fil_usize,d0
	bsr	mem_alloc
	bcs.s	.nomem
	move.l	a0,a4
	move.l	a4,a1
	bsr	fil_unpack
	bcs.s	.uerr
	lea	0(a4,d5.l),a0
	move.l	a3,a1
	move.l	d4,d0
	bsr	fil_copy
	move.l	d6,d0
	bsr	mem_release
	movem.l	(sp)+,d3-d6/a3-a4
	and.b	#$fe,ccr
	rts
.nomem:	move.w	d3,-(sp)
	FDOS	GD_FCLOSE,4
	moveq	#-39,d0
.uerr:	move.l	d0,-(sp)
	move.l	d6,d0
	bsr	mem_release
	move.l	(sp)+,d0
.err:	movem.l	(sp)+,d3-d6/a3-a4
	or.b	#1,ccr
	rts

fil_save:
	movem.l	d3-d4/a3,-(sp)
	move.l	a1,a3
	move.l	d0,d4
	clr.w	-(sp)			; Fcreate(name, 0)
	move.l	a0,-(sp)
	FDOS	GD_FCREATE,8
	tst.l	d0
	bmi.s	.err
	move.w	d0,d3
	move.l	a3,-(sp)
	move.l	d4,-(sp)
	move.w	d3,-(sp)
	FDOS	GD_FWRITE,12
	move.l	d0,d4
	move.w	d3,-(sp)
	FDOS	GD_FCLOSE,4
	tst.l	d4
	bmi.s	.err
	movem.l	(sp)+,d3-d4/a3
	and.b	#$fe,ccr
	rts
.err:	movem.l	(sp)+,d3-d4/a3
	or.b	#1,ccr
	rts

fil_size:
	move.l	d3,-(sp)
	clr.w	-(sp)
	move.l	a0,-(sp)
	FDOS	GD_FOPEN,8
	tst.l	d0
	bmi.s	.err
	move.w	d0,d3
	bsr	fil_hdr			; (Phase 8) packed: its unpacked size
	beq.s	.raw
	move.w	d3,-(sp)
	FDOS	GD_FCLOSE,4
	move.l	fil_usize,d0
	move.l	(sp)+,d3
	and.b	#$fe,ccr
	rts
.raw:	move.w	#2,-(sp)		; Fseek(0, h, end)
	move.w	d3,-(sp)
	clr.l	-(sp)
	FDOS	GD_FSEEK,10
	move.l	d0,-(sp)
	move.w	d3,-(sp)
	FDOS	GD_FCLOSE,4
	move.l	(sp)+,d0
	move.l	(sp)+,d3
	and.b	#$fe,ccr
	rts
.err:	move.l	(sp)+,d3
	or.b	#1,ccr
	rts

fil_mkdir:
	move.l	a0,-(sp)
	FDOS	GD_DCREATE,6
	rts

	section	bss
fil_h:		ds.l	3		; (Phase 8) a file's first FIL_HDR bytes
fil_usize:	ds.l	1
fil_delta:	ds.l	1
fil_psize:	ds.l	1
fil_tmp:	ds.l	1		; (Phase 8) room for the packed bytes, else the pool
fil_tmpn:	ds.l	1
	section	text
