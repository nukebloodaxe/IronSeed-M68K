; orc.s - state dumps for the oracle comparison (the ST twin of the Linux build's oracledump,
; called where the original calls loadscreen). Only in test runs (scr_test): writes
; C:\Dnnnn.BIN, nnnn = 1, 2, ... with the blocks ship, systems, cargo, rescargo, events, logs,
; logpending, alien, colors (and tempplan when GS_TEMPPLAN is set) in the 68000 layout (tools/oracle_cmp.py reads both). Part of kernel.s.
;
; orc_dump   trashes: d0-d2/a0-a2

	section	text
orc_dump:
	tst.w	scr_test
	beq	.x
	movem.l	d3-d4/a3-a4,-(sp)
	addq.w	#1,orc_seq
	move.w	orc_seq,d0		; name: four decimal digits
	lea	orc_name+8,a0		; digits at 4-7, written backwards
	moveq	#4-1,d1
.dg:	ext.l	d0
	divu	#10,d0
	swap	d0
	add.b	#'0',d0
	move.b	d0,-(a0)
	swap	d0
	dbf	d1,.dg
	clr.w	-(sp)
	pea	orc_name
	GEMDOS	GD_FCREATE,8
	tst.l	d0
	bmi	.out
	move.w	d0,d3
	lea	orc_blocks,a3
.blk:	move.w	(a3)+,d0		; GS offset, -1 ends
	bmi.s	.cl
	move.w	(a3)+,d4		; size
	lea	orc_hdr,a0		; name: Pascal string padded to 24 bytes
	moveq	#24/4-1,d1
.z:	clr.l	(a0)+
	dbf	d1,.z
	lea	orc_hdr,a0
	move.l	a3,a1
	moveq	#-1,d1
.n:	addq.w	#1,d1
	tst.b	(a1)+
	bne.s	.n
	move.b	d1,(a0)+
.nc:	move.b	(a3)+,(a0)+
	bne.s	.nc
	move.l	a3,d1			; skip to even
	addq.l	#1,d1
	and.w	#$fffe,d1
	move.l	d1,a3
	moveq	#0,d1
	move.w	d4,d1
	move.l	d1,orc_hdr+24
	move.w	d0,-(sp)
	pea	orc_hdr
	move.l	#28,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FWRITE,12
	move.w	(sp)+,d0
	lea	0(a6,d0.w),a0
	move.l	a0,-(sp)
	moveq	#0,d1
	move.w	d4,d1
	move.l	d1,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FWRITE,12
	bra.s	.blk
.cl:	move.l	GS_TEMPPLAN(a6),d0	; tempplan^ (the planets), when the program has it
	beq.s	.cl2
	move.l	d0,a4
	lea	orc_hdr,a0
	moveq	#24/4-1,d1
.z2:	clr.l	(a0)+
	dbf	d1,.z2
	lea	orc_hdr,a0
	lea	orc_tp,a1
.t:	move.b	(a1)+,(a0)+
	bne.s	.t
	move.l	#PLANARRAY_SIZEOF,orc_hdr+24
	pea	orc_hdr
	move.l	#28,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FWRITE,12
	move.l	a4,-(sp)
	move.l	#PLANARRAY_SIZEOF,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FWRITE,12
.cl2:	move.l	orc_scrbuf,d0		; the chunky shadow (MAIN.PRG), like the Linux build's screen[]
	beq.s	.cl3
	move.l	d0,a4
	lea	orc_hdr,a0
	moveq	#24/4-1,d1
.z3:	clr.l	(a0)+
	dbf	d1,.z3
	lea	orc_hdr,a0
	lea	orc_sc,a1
.t3:	move.b	(a1)+,(a0)+
	bne.s	.t3
	move.l	#64000,orc_hdr+24
	pea	orc_hdr
	move.l	#28,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FWRITE,12
	move.l	a4,-(sp)
	move.l	#64000,-(sp)
	move.w	d3,-(sp)
	GEMDOS	GD_FWRITE,12
.cl3:	move.w	d3,-(sp)
	GEMDOS	GD_FCLOSE,4
.out:	movem.l	(sp)+,d3-d4/a3-a4
.x:	rts

	section	data
orc_name:	dc.b	"C:",92,"D0000.BIN",0
orc_tp:		dc.b	8,"tempplan",0
orc_sc:		dc.b	6,"screen",0
	even
orc_blocks:
	dc.w	GS_SHIP,SHIP_SIZEOF
	dc.b	"ship",0
	even
	dc.w	GS_SYSTEMS,SYSTEMARRAY_SIZEOF
	dc.b	"systems",0
	even
	dc.w	GS_CARGO,CARGOARRAY_SIZEOF
	dc.b	"cargo",0
	even
	dc.w	GS_RESCARGO,500
	dc.b	"rescargo",0
	even
	dc.w	GS_EVENTS,1024
	dc.b	"events",0
	even
	dc.w	GS_LOGS,512
	dc.b	"logs",0
	even
	dc.w	GS_LOGPENDING,512
	dc.b	"logpending",0
	even
	dc.w	GS_ALIEN,ALIEN_SIZEOF
	dc.b	"alien",0
	even
	dc.w	GS_COLORS,768
	dc.b	"colors",0
	even
	dc.w	GS_NEARBY,NEARBYARRAY_SIZEOF
	dc.b	"nearby",0
	even
	dc.w	GS_T1,8
	dc.b	"t1",0
	even
	dc.w	GS_TARGET,2
	dc.b	"target",0
	even
	dc.w	GS_CURPLAN,2
	dc.b	"curplan",0
	even
	dc.w	GS_VIEWMODE,2
	dc.b	"viewmode",0
	even
	dc.w	GS_VIEWMODE2,2
	dc.b	"viewmode2",0
	even
	dc.w	GS_VIEWLEVEL,2
	dc.b	"viewlevel",0
	even
	dc.w	GS_VIEWINDEX,2
	dc.b	"viewindex",0
	even
	dc.w	GS_VIEWINDEX2,2
	dc.b	"viewindex2",0
	even
	dc.w	GS_ALERT,2
	dc.b	"alert",0
	even
	dc.w	GS_ACTION,2
	dc.b	"action",0
	even
	dc.w	GS_SHOWPLANET,1
	dc.b	"showplanet",0
	even
	dc.w	-1

	section	bss
orc_seq:	ds.w	1
orc_scrbuf:	ds.l	1		; set by a program with a chunky shadow (MAIN: ms_buf)
orc_hdr:	ds.b	28
