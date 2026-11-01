; inflate.s - raw deflate decoder (RFC 1951), written for the floppy version (Phase 8). Part of
; kernel.s. Data packed by tools/mkfloppy.py (Python's zlib, raw deflate) is decoded straight
; into its destination: back-references read the output itself, so no window is kept.
;
; inf_inflate  in: a0 = deflate data, a1 = output   out: a1 = output end; carry set on a bad
;              block type (data that is not ours)   trashes: d0-d2/a0-a2
;
; Huffman codes up to INF_FB (9) bits come from a lookup table indexed by the next 9 stream bits
; (entry = symbol << 4 | length, 0 = longer); longer ones are decoded canonically a bit at a time
; (counts per length, symbols in order). Bits are read LSB first through d7, a 32-bit buffer
; holding d6 bits (refilled a byte at a time to at least 16; it may read up to 3 bytes beyond the
; data). Inside, every routine may trash d0-d5/a2-a4 (saved once at the entry); a0 (input), a1
; (output), d6/d7 (bits) and a5 belong to the decoder.
INF_FB	equ	10

; d7 holds at least 16 bits (trashes d0)
INF_FILL	macro
	cmp.w	#16,d6
	bge.s	.f\@
.r\@:	moveq	#0,d0
	move.b	(a0)+,d0
	lsl.l	d6,d0
	or.l	d0,d7
	addq.w	#8,d6
	cmp.w	#16,d6
	blt.s	.r\@
.f\@:
	endm

; at least 16 bits in d7, two bytes at a time (trashes d0)
INF_FILL2	macro
	cmp.w	#16,d6
	bge.s	.f\@
	moveq	#0,d0
	move.b	1(a0),d0
	lsl.w	#8,d0
	move.b	(a0),d0
	addq.l	#2,a0
	lsl.l	d6,d0
	or.l	d0,d7
	add.w	#16,d6
.f\@:
	endm

; one bit into C/X (trashes d0)
INF_BIT	macro
	INF_FILL
	subq.w	#1,d6			; (before the shift: subq sets X and C too)
	lsr.l	#1,d7
	endm

	section	text
inf_inflate:
	movem.l	d3-d7/a3-a5,-(sp)
	moveq	#0,d6			; no bits yet
	moveq	#0,d7
.block:	INF_BIT
	scs	inf_last
	moveq	#2,d0
	bsr	inf_bits		; BTYPE
	tst.w	d0
	beq.s	.stored
	cmp.w	#1,d0
	beq.s	.fixed
	cmp.w	#2,d0
	beq.s	.dyn
	movem.l	(sp)+,d3-d7/a3-a5
	or.b	#1,ccr
	rts
.fixed:	bsr	inf_fixed
	bra.s	.codes
.dyn:	bsr	inf_dynamic
.codes:	bsr	inf_codes
.next:	tst.b	inf_last
	beq.s	.block
	movem.l	(sp)+,d3-d7/a3-a5
	and.b	#$fe,ccr
	rts
.stored:	move.w	d6,d0			; to the byte boundary
	and.w	#7,d0
	lsr.l	d0,d7
	sub.w	d0,d6
	moveq	#16,d0			; LEN; NLEN skipped
	bsr	inf_bits
	move.w	d0,-(sp)
	moveq	#16,d0
	bsr	inf_bits
	move.w	(sp)+,d1
	bra.s	.sc
.sl:	tst.w	d6			; whole bytes still in the buffer first
	beq.s	.sm
	move.b	d7,(a1)+
	lsr.l	#8,d7
	subq.w	#8,d6
	bra.s	.sc
.sm:	move.b	(a0)+,(a1)+
.sc:	dbf	d1,.sl
	bra.s	.next

; d0.w = n (0-16) bits, LSB first -> d0.l  trashes: d1-d2
inf_bits:
	move.w	d0,d2
	beq.s	.z
	INF_FILL
	moveq	#1,d1
	lsl.l	d2,d1
	subq.l	#1,d1
	and.l	d7,d1			; the n low bits
	lsr.l	d2,d7
	sub.w	d2,d6
	move.l	d1,d0
	rts
.z:	moveq	#0,d0
	rts

; one symbol. in: a2 = counts (16 words, [0] unused), a3 = symbols (words), the fast table at
; a2 + INF_TAB  out: d0.w = symbol  trashes: d1-d5/a4
INF_TAB	equ	32+2*288		; (a code's counts, symbols, then its fast table)
inf_decode:
	INF_FILL
	move.w	d7,d0
	and.w	#(1<<INF_FB)-1,d0
	add.w	d0,d0
	lea	INF_TAB(a2),a4
	move.w	0(a4,d0.w),d0		; symbol << 4 | length
	beq.s	.slow
	moveq	#15,d1
	and.w	d0,d1
	lsr.l	d1,d7
	sub.w	d1,d6
	lsr.w	#4,d0
	rts
.slow:	moveq	#0,d1			; code
	moveq	#0,d2			; first code of this length
	moveq	#0,d3			; index of its first symbol
	lea	2(a2),a4
	moveq	#15-1,d5
.l:	INF_BIT
	addx.w	d1,d1			; code = code*2 + bit
	move.w	(a4)+,d4		; count[len]
	move.w	d1,d0
	sub.w	d2,d0			; code - first
	cmp.w	d4,d0
	blo.s	.got
	add.w	d4,d3			; index += count
	add.w	d4,d2
	add.w	d2,d2			; first = (first + count) * 2
	dbf	d5,.l
	moveq	#0,d0			; (not ours)
	rts
.got:	add.w	d3,d0
	add.w	d0,d0
	move.w	0(a3,d0.w),d0
	rts

; counts and symbols from code lengths. in: a5 = lengths (bytes), d0.w = n,
; a2 = counts (16 words), a3 = symbols (words)  trashes: d0-d4/a4
inf_build:
	move.l	a0,-(sp)
	move.w	d0,inf_n
	move.l	a2,a4			; counts := 0
	moveq	#16-1,d1
.c0:	clr.w	(a4)+
	dbf	d1,.c0
	move.l	a5,a0
	move.w	d0,d3
	subq.w	#1,d3			; n - 1
	move.w	d3,d1
.cn:	moveq	#0,d2
	move.b	(a0)+,d2
	add.w	d2,d2
	addq.w	#1,0(a2,d2.w)
	dbf	d1,.cn
	clr.w	(a2)			; (length 0: no code)
	lea	inf_offs+2,a4		; offs[len] = count[1] + .. + count[len-1]
	lea	2(a2),a0
	moveq	#0,d2
	moveq	#15-1,d1
.of:	move.w	d2,(a4)+
	add.w	(a0)+,d2
	dbf	d1,.of
	move.l	a5,a0			; symbols in order of length, then of value
	moveq	#0,d4
.sy:	moveq	#0,d2
	move.b	(a0)+,d2
	beq.s	.sn
	add.w	d2,d2
	lea	inf_offs,a4
	move.w	0(a4,d2.w),d1
	addq.w	#1,0(a4,d2.w)
	add.w	d1,d1
	move.w	d4,0(a3,d1.w)
.sn:	addq.w	#1,d4
	dbf	d3,.sy
	; the fast table: every code of length <= 9, bit-reversed, at every index it begins
	lea	INF_TAB(a2),a4
	move.w	#(1<<INF_FB)-1,d1
.tz:	clr.w	(a4)+
	dbf	d1,.tz
	lea	inf_next+2,a4		; next code per length (canonical): code = (code + count) << 1
	moveq	#0,d2
	lea	2(a2),a0
	moveq	#15-1,d1
.nc:	move.w	d2,(a4)+
	add.w	(a0)+,d2
	add.w	d2,d2
	dbf	d1,.nc
	move.l	a5,a0
	moveq	#0,d4			; symbol
	move.w	inf_n,d3
	subq.w	#1,d3
.ts:	moveq	#0,d2
	move.b	(a0)+,d2		; length
	beq.s	.tn
	move.w	d2,d1
	add.w	d1,d1
	lea	inf_next,a4
	move.w	0(a4,d1.w),d0		; its code
	addq.w	#1,0(a4,d1.w)
	cmp.w	#INF_FB,d2
	bhi.s	.tn
	move.l	d3,-(sp)
	moveq	#0,d1			; reversed
	move.w	d2,d3
	subq.w	#1,d3
.rv:	lsr.w	#1,d0
	addx.w	d1,d1
	dbf	d3,.rv
	move.w	d4,d0			; entry: symbol << 4 | length
	lsl.w	#4,d0
	or.w	d2,d0
	moveq	#1,d3			; step = 1 << length
	lsl.w	d2,d3
	add.w	d1,d1
	add.w	d3,d3
	lea	INF_TAB(a2),a4
.tf:	move.w	d0,0(a4,d1.w)
	add.w	d3,d1
	cmp.w	#2<<INF_FB,d1
	blo.s	.tf
	move.l	(sp)+,d3
.tn:	addq.w	#1,d4
	dbf	d3,.ts
	move.l	(sp)+,a0
	rts

; the fixed codes (BTYPE 1)
inf_fixed:
	lea	inf_lens,a4
	move.w	#144-1,d0
.a:	move.b	#8,(a4)+
	dbf	d0,.a
	moveq	#112-1,d0
.b:	move.b	#9,(a4)+
	dbf	d0,.b
	moveq	#24-1,d0
.c:	move.b	#7,(a4)+
	dbf	d0,.c
	moveq	#8-1,d0
.d:	move.b	#8,(a4)+
	dbf	d0,.d
	moveq	#30-1,d0
.e:	move.b	#5,(a4)+
	dbf	d0,.e
	lea	inf_lens,a5
	move.w	#288,d0
	lea	inf_lcnt,a2
	lea	inf_lsym,a3
	bsr	inf_build
	lea	inf_lens+288,a5
	moveq	#30,d0
	lea	inf_dcnt,a2
	lea	inf_dsym,a3
	bra	inf_build

; the dynamic codes (BTYPE 2): their lengths, themselves coded
inf_dynamic:
	moveq	#5,d0
	bsr	inf_bits
	add.w	#257,d0
	move.w	d0,inf_nlen
	moveq	#5,d0
	bsr	inf_bits
	addq.w	#1,d0
	move.w	d0,inf_ndist
	moveq	#4,d0
	bsr	inf_bits
	addq.w	#4,d0
	move.w	d0,d5			; ncode
	lea	inf_clen,a4		; the code length code's lengths: 0, then 3 bits each in order
	moveq	#19-1,d0
.z:	clr.b	(a4)+
	dbf	d0,.z
	lea	inf_order,a3
	subq.w	#1,d5
.o:	moveq	#3,d0
	bsr	inf_bits
	moveq	#0,d1
	move.b	(a3)+,d1
	lea	inf_clen,a4
	move.b	d0,0(a4,d1.w)
	dbf	d5,.o
	lea	inf_clen,a5
	moveq	#19,d0
	lea	inf_lcnt,a2
	lea	inf_lsym,a3
	bsr	inf_build
	move.w	inf_nlen,d0		; the lengths of both codes (count and index in memory:
	add.w	inf_ndist,d0		; inf_decode trashes d1-d5)
	move.w	d0,inf_tot
	lea	inf_lens,a5
	clr.w	inf_idx
.ln:	move.w	inf_idx,d0
	cmp.w	inf_tot,d0
	bhs	.lx
	lea	inf_lcnt,a2
	lea	inf_lsym,a3
	bsr	inf_decode
	cmp.w	#16,d0
	bhs.s	.rep
	move.w	inf_idx,d1
	move.b	d0,0(a5,d1.w)
	addq.w	#1,inf_idx
	bra.s	.ln
.rep:	move.w	d0,-(sp)
	cmp.w	#16,d0
	bne.s	.r17
	moveq	#2,d0			; 16: the last length 3-6 times
	bsr	inf_bits
	addq.w	#3,d0
	move.w	inf_idx,d1
	move.b	-1(a5,d1.w),d2
	bra.s	.fill
.r17:	cmp.w	#17,d0
	bne.s	.r18
	moveq	#3,d0			; 17: 0 3-10 times
	bsr	inf_bits
	addq.w	#3,d0
	moveq	#0,d2
	bra.s	.fill
.r18:	moveq	#7,d0			; 18: 0 11-138 times
	bsr	inf_bits
	add.w	#11,d0
	moveq	#0,d2
.fill:	addq.l	#2,sp
	move.w	inf_idx,d1
	add.w	d0,inf_idx
	subq.w	#1,d0
.f:	move.b	d2,0(a5,d1.w)
	addq.w	#1,d1
	dbf	d0,.f
	bra	.ln
.lx:	lea	inf_lens,a5
	move.w	inf_nlen,d0
	lea	inf_lcnt,a2
	lea	inf_lsym,a3
	bsr	inf_build
	lea	inf_lens,a5
	add.w	inf_nlen,a5
	move.w	inf_ndist,d0
	lea	inf_dcnt,a2
	lea	inf_dsym,a3
	bra	inf_build

; the block's data: literals, length/distance pairs, until 256, inlined: a5 = the literal/length
; code's fast table, a2 = the distance code's; extra bits through inf_mask.
inf_codes:
	lea	inf_lcnt+INF_TAB,a5
	lea	inf_dcnt+INF_TAB,a2
.l:	INF_FILL2
	move.w	d7,d0
	and.w	#(1<<INF_FB)-1,d0
	add.w	d0,d0
	move.w	0(a5,d0.w),d0		; symbol << 4 | length
	beq	.slow
	moveq	#15,d1
	and.w	d0,d1
	lsr.l	d1,d7
	sub.w	d1,d6
	lsr.w	#4,d0
	cmp.w	#256,d0
	bhs.s	.ld
	move.b	d0,(a1)+
	bra.s	.l
.ld:	beq	.x			; 256: the end of the block
	sub.w	#257,d0			; the length: base + extra bits
	add.w	d0,d0
	lea	inf_lbase,a4
	move.w	0(a4,d0.w),d4
	lea	inf_lext,a4
	move.w	0(a4,d0.w),d1
	beq.s	.d
	INF_FILL2
	add.w	d1,d1
	lea	inf_mask,a4
	move.w	0(a4,d1.w),d0
	and.w	d7,d0
	add.w	d0,d4
	lsr.w	#1,d1
	lsr.l	d1,d7
	sub.w	d1,d6
.d:	INF_FILL2			; the distance code
	move.w	d7,d0
	and.w	#(1<<INF_FB)-1,d0
	add.w	d0,d0
	move.w	0(a2,d0.w),d0
	beq	.dslow
	moveq	#15,d1
	and.w	d0,d1
	lsr.l	d1,d7
	sub.w	d1,d6
	lsr.w	#4,d0
.dg:	add.w	d0,d0			; the distance: base + extra bits (up to 13)
	lea	inf_dbase,a4
	moveq	#0,d5
	move.w	0(a4,d0.w),d5
	lea	inf_dext,a4
	move.w	0(a4,d0.w),d1
	beq.s	.cp
	INF_FILL2
	add.w	d1,d1
	lea	inf_mask,a4
	move.w	0(a4,d1.w),d0
	and.w	d7,d0
	add.w	d0,d5			; (d5's upper word is 0: distances fit in 16 bits)
	lsr.w	#1,d1
	lsr.l	d1,d7
	sub.w	d1,d6
.cp:	move.l	a1,a4
	sub.l	d5,a4
	subq.w	#1,d4
.c:	move.b	(a4)+,(a1)+
	dbf	d4,.c
	bra	.l
.slow:	move.l	a2,-(sp)		; a code longer than INF_FB bits (canonical)
	lea	inf_lcnt,a2
	lea	inf_lsym,a3
	bsr	inf_decode
	move.l	(sp)+,a2
	cmp.w	#256,d0
	bhs	.ld
	move.b	d0,(a1)+
	bra	.l
.dslow:	move.l	a2,-(sp)		; (inf_decode trashes d1-d5: the length is in d4)
	move.w	d4,-(sp)
	lea	inf_dcnt,a2
	lea	inf_dsym,a3
	bsr	inf_decode
	move.w	(sp)+,d4
	move.l	(sp)+,a2
	bra	.dg
.x:	rts

	section	data
inf_order:	dc.b	16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15
	even
inf_lbase:	dc.w	3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258
inf_lext:	dc.w	0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0
inf_dbase:	dc.w	1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073
		dc.w	4097,6145,8193,12289,16385,24577
inf_dext:	dc.w	0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13
inf_mask:	dc.w	0,1,3,7,15,31,63,127,255,511,1023,2047,4095,8191,16383,32767

	section	bss
inf_lcnt:	ds.w	16		; (counts, symbols, fast table: INF_TAB)
inf_lsym:	ds.w	288
		ds.w	1<<INF_FB
inf_dcnt:	ds.w	16
inf_dsym:	ds.w	288
		ds.w	1<<INF_FB
inf_next:	ds.w	16
inf_n:		ds.w	1
inf_offs:	ds.w	16
inf_nlen:	ds.w	1
inf_ndist:	ds.w	1
inf_idx:	ds.w	1
inf_tot:	ds.w	1
inf_lens:	ds.b	320
inf_clen:	ds.b	20
inf_last:	ds.b	1
	even
