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
mem_end:	ds.l	1
