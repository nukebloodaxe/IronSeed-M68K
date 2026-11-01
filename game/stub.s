; stub.s - a packed program (Phase 8, the floppy version; tools/packprg.py builds it): this
; stub + the program's text, data and relocation table as raw deflate (kernel inflate.s).
; At start: inflate the image high in the TPA, copy a small position-independent finisher
; above it and jump there; the finisher copies text+data down to the basepage, relocates them,
; clears the bss, sets the basepage's lengths and starts the program as TOS would have.
; Assembled with -DP_TLEN=.. -DP_DLEN=.. -DP_BLEN=.. -DP_USIZE=.. (the unpacked image: text,
; data, relocation table) and the payload in build/stub.pk.

	section	text
start:	move.l	4(sp),a5		; basepage
	move.l	sp,d0			; below the stack (TOS puts it at the top of the TPA)
	sub.l	#P_USIZE+fin_end-fin+1024,d0
	and.w	#$fff0,d0
	move.l	d0,a4			; the image goes here
	move.l	a5,d1			; room for the program below it?
	add.l	#256+P_TLEN+P_DLEN+P_BLEN,d1
	cmp.l	d1,d0
	blo.s	.nomem
	lea	payload,a0
	move.l	a4,a1
	bsr	inf_inflate
	bcs.s	.bad
	move.l	a4,a0			; the finisher after the image
	add.l	#P_USIZE+16,a0
	move.l	a0,d0
	and.w	#$fff0,d0
	move.l	d0,a3
	lea	fin(pc),a0
	move.l	a3,a1
	move.w	#(fin_end-fin)/2-1,d0
.cp:	move.w	(a0)+,(a1)+
	dbf	d0,.cp
	move.l	a4,a0			; a0 = image, a5 = basepage
	move.l	#P_TLEN,d5
	move.l	#P_DLEN,d6
	move.l	#P_BLEN,d7
	jmp	(a3)
.nomem:	pea	msg_mem
	bra.s	.msg
.bad:	pea	msg_bad
.msg:	move.w	#9,-(sp)		; Cconws
	trap	#1
	addq.l	#6,sp
	move.w	#7,-(sp)		; Crawcin: let it be read
	trap	#1
	addq.l	#2,sp
	move.w	#-39,-(sp)
	move.w	#$4c,-(sp)		; Pterm(-39)
	trap	#1

; position-independent: a0 = image (text, data, relocation), a5 = basepage, d5/d6/d7 = lengths
fin:	lea	256(a5),a1		; text + data down to the basepage
	move.l	a1,a2			; (a2 = text base)
	move.l	d5,d0
	add.l	d6,d0
	move.l	a0,a3
	add.l	d0,a3			; a3 = the relocation table
	addq.l	#1,d0
	lsr.l	#1,d0
	bra.s	.ce
.c:	move.w	(a0)+,(a1)+
.ce:	subq.l	#1,d0
	bpl.s	.c
	move.l	(a3)+,d0		; relocate: first offset (0 = none), then bytes
	beq.s	.rd
	move.l	a2,d1
	lea	0(a2,d0.l),a0
	add.l	d1,(a0)
	moveq	#0,d0
.r:	move.b	(a3)+,d0
	beq.s	.rd
	cmp.b	#1,d0
	bne.s	.ra
	lea	254(a0),a0
	bra.s	.r
.ra:	add.w	d0,a0
	add.l	d1,(a0)
	bra.s	.r
.rd:	move.l	a2,a0			; bss cleared
	add.l	d5,a0
	add.l	d6,a0
	move.l	d7,d0
	addq.l	#3,d0
	lsr.l	#2,d0
	bra.s	.ze
.z:	clr.l	(a0)+
.ze:	subq.l	#1,d0
	bpl.s	.z
	move.l	a2,8(a5)		; the basepage as TOS fills it
	move.l	d5,12(a5)
	move.l	a2,d0
	add.l	d5,d0
	move.l	d0,16(a5)
	move.l	d6,20(a5)
	add.l	d6,d0
	move.l	d0,24(a5)
	move.l	d7,28(a5)
	moveq	#0,d0
	moveq	#0,d1
	moveq	#0,d2
	sub.l	a0,a0
	sub.l	a1,a1
	jmp	(a2)
	even
fin_end:

	include	"inflate.s"

	section	data
msg_mem:	dc.b	13,10,"Iron Seed: not enough memory to unpack the program.",13,10,0
msg_bad:	dc.b	13,10,"Iron Seed: the program file is damaged.",13,10,0
	even
payload:	incbin	"stub.pk"
		dcb.b	4,0
	even
