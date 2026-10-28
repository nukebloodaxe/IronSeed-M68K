; mem.s - memory pool. Part of kernel.s. One GEMDOS Malloc at start-up (TOS 1.x
; allows only ~20 fragments per process); a stack-like allocator on top of it.
;
; mem_alloc    in: d0.l = bytes   out: a0 = block (16-byte aligned), carry set if out of memory
;              trashes: d0-d1
; mem_mark     out: d0.l = current top (pass to mem_release)
; mem_release  in: d0.l = mark - frees everything allocated after mem_mark
; mem_free     out: d0.l = bytes left

	section	text
mem_init:
	move.l	mem_pool,d0
	add.l	#15,d0
	and.w	#$fff0,d0
	move.l	d0,mem_top
	move.l	mem_pool,d0
	add.l	mem_pool_size,d0
	move.l	d0,mem_end
	ifd	POOLFILL		; test builds: garbage in the pool, as RAM after a cold boot on
	move.l	mem_top,a0		; other emulators / real machines (Hatari starts with zeros)
	move.l	#$9e3779b9,d1
.pf:	move.l	d1,(a0)+
	rol.l	#5,d1
	add.l	#$7f4a7c15,d1
	cmp.l	mem_end,a0
	blo.s	.pf
	endc
	rts

mem_alloc:
	move.l	mem_top,a0
	add.l	#15,d0
	and.w	#$fff0,d0
	move.l	a0,d1
	add.l	d0,d1
	cmp.l	mem_end,d1
	bhi.s	.full
	move.l	d1,mem_top
	ifd	MEMHI			; (test builds: the pool's high-water mark)
	cmp.l	mem_hi,d1
	bls.s	.h
	move.l	d1,mem_hi
.h:
	endif
	and.b	#$fe,ccr		; carry clear
	rts
.full:	sub.l	a0,a0
	or.b	#1,ccr
	rts

mem_mark:
	move.l	mem_top,d0
	rts

mem_release:
	move.l	d0,mem_top
	rts

mem_free:
	move.l	mem_end,d0
	sub.l	mem_top,d0
	rts

	section	bss
mem_pool:	ds.l	1
mem_pool_size:	ds.l	1
mem_top:	ds.l	1
	ifd	MEMHI
mem_hi:		ds.l	1
	endif
mem_end:	ds.l	1
