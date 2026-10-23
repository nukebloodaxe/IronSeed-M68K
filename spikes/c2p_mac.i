; c2p_mac.i - pixel macros for c2p.i (include before code)

; one pixel: shift accumulator, OR in this pixel's 4 plane bits
PIX	macro
	moveq	#0,d0
	move.b	(a0)+,d0
	add.l	d6,d6
	add.w	d0,d0
	add.w	d0,d0
	or.l	0(a1,d0.w),d6
	endm

PIX8	macro
	moveq	#0,d6
	PIX
	PIX
	PIX
	PIX
	PIX
	PIX
	PIX
	PIX
	endm

