; print.s - saveload.pas printcargo (the cargo list) and printinfo (the planet file), "printed" to the file TEMP\LPT1 (the FPC
; build's loc_tmp()+'LPT1'), lines ending CR LF on the ST (tests/check_main.sh compares with LF).
; The text is built in memory (pr_*) and saved at once.
;
; printcargo, printinfo                trashes: d0-d2/a0-a2
; pr_open / pr_close                   start a text (16 KB, mem_mark'd) / save it to TEMP\LPT1
; pr_pstr a0 / pr_txt (inline, PRS) / pr_int d0.l,d1.w width / pr_tenths d0.l,d1.w width / pr_nl

PRS	macro				; pr_txt: write an inline string
	lea	.ps\@,a0
	bsr	pr_pstr
	section	data
.ps\@:	dc.b	.pe\@-.ps\@-1,\1
.pe\@:
	even
	section	text
	endm

	section	text
pr_open:
	bsr	mem_mark
	move.l	d0,pr_mark
	move.l	#16384,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,pr_buf
	move.l	a0,pr_ptr
	rts
pr_close:
	lea	pr_fn_tmp,a0
	bsr	fil_mkdir
	lea	pr_fn,a0
	move.l	pr_buf,a1
	move.l	pr_ptr,d0
	sub.l	a1,d0
	bsr	fil_save
	move.l	pr_mark,d0
	bra	mem_release
pr_nl:	move.l	pr_ptr,a0
	move.b	#13,(a0)+
	move.b	#10,(a0)+
	move.l	a0,pr_ptr
	rts
; a0 = Pascal string
pr_pstr:
	move.l	pr_ptr,a1
	moveq	#0,d0
	move.b	(a0)+,d0
	bra.s	.e
.c:	move.b	(a0)+,(a1)+
.e:	dbf	d0,.c
	move.l	a1,pr_ptr
	rts
; write(d0.l : d1.w) - an integer right-justified in d1 columns (0: as is)
pr_int:
	lea	pr_s,a0
	bsr	int_str
	lea	pr_s,a0
	bra	pr_pstr
; write((d0.l/10):d1.w:1) - tenths as "q.r" right-justified (exact for integers: the double's
; one-decimal print is the integer's digits)
pr_tenths:
	movem.l	d3-d4,-(sp)
	move.w	d1,d4
	moveq	#0,d3			; sign
	tst.l	d0
	bpl.s	.p
	neg.l	d0
	moveq	#1,d3
.p:	divu	#10,d0			; (|v| < 655360)
	move.l	d0,-(sp)
	and.l	#$ffff,d0
	moveq	#0,d1
	lea	pr_s,a0
	bsr	int_str
	lea	pr_t,a1			; t := ['-'] + q + '.' + r
	moveq	#0,d0
	lea	1(a1),a2
	tst.w	d3
	beq.s	.n
	move.b	#'-',(a2)+
	addq.w	#1,d0
.n:	lea	pr_s,a0
	moveq	#0,d1
	move.b	(a0)+,d1
	add.w	d1,d0
	bra.s	.ce
.cc:	move.b	(a0)+,(a2)+
.ce:	dbf	d1,.cc
	move.b	#'.',(a2)+
	move.l	(sp)+,d1
	swap	d1
	add.b	#'0',d1
	move.b	d1,(a2)+
	addq.w	#2,d0
	move.b	d0,(a1)
	sub.w	d0,d4			; the padding
	ble.s	.w
	move.l	pr_ptr,a0
	subq.w	#1,d4
.sp:	move.b	#' ',(a0)+
	dbf	d4,.sp
	move.l	a0,pr_ptr
.w:	lea	pr_t,a0
	bsr	pr_pstr
	movem.l	(sp)+,d3-d4
	rts

; ---------------------------------------------------------------- printcargo (saveload.pas 1244)
printcargo:
	movem.l	d3-d7/a3,-(sp)
	bsr	mousehide		; tempscr := rows 85..105, x 105..216
	lea	pr_save,a3
	moveq	#85,d3
.sv:	move.w	#105,d0
	move.w	d3,d1
	bsr	ms_addr
	moveq	#112-1,d0
.svc:	move.b	(a0)+,(a3)+
	dbf	d0,.svc
	addq.w	#1,d3
	cmp.w	#105,d3
	ble.s	.sv
	move.w	#105,d0			; graybutton(105,85,215,105)
	moveq	#85,d1
	move.w	#215,d2
	moveq	#105,d3
	bsr	graybutton
	TCOL	191
	clr.w	pr_i			; i := 0; lastx := 0; lasty := 0
	clr.w	pr_lastx
	clr.w	pr_lasty
	BKCOL	5
	PXY	132,92,"PRINTING..."
	bsr	pr_open
	PRS	"IRONSEED CARGO FILE:"
	bsr	pr_nl
	bsr	pr_nl
	PRS	"WEAPONS:"
	bsr	pr_nl
	move.w	#999,d0
	move.w	#ID_NOSHIELD-1,d1
	bsr	pr_partof
	PRS	"SHIELDS:"
	bsr	pr_nl
	move.w	#ID_NOSHIELD-1,d0
	move.w	#1999,d1
	bsr	pr_partof
	PRS	"DEVICES:"
	bsr	pr_nl
	move.w	#1999,d0
	move.w	#2999,d1
	bsr	pr_partof
	PRS	"COMPONENTS:"
	bsr	pr_nl
	move.w	#2999,d0
	move.w	#3999,d1
	bsr	pr_partof
	PRS	"MATERIALS:"
	bsr	pr_nl
	move.w	#3999,d0
	move.w	#4999,d1
	bsr	pr_partof
	PRS	"ELEMENTS:"
	bsr	pr_nl
	move.w	#4999,d0
	move.w	#ID_LAST_ELEMENT,d1
	bsr	pr_partof
	PRS	"ARTIFACTS:"
	bsr	pr_nl
	move.w	#ID_LAST_ELEMENT,d0
	move.w	#ID_LAST_ARTIFACT,d1
	bsr	pr_partof
	PRS	"     NET CARGO SIZE: "
	move.w	pr_i,d0
	ext.l	d0
	moveq	#0,d1
	bsr	pr_tenths
	PRS	" CUBIC METERS"
	bsr	pr_nl
	PRS	" CARGO SLOTS FILLED: "
	move.w	pr_lastx,d0
	ext.l	d0
	moveq	#0,d1
	bsr	pr_int
	PRS	"/250"
	bsr	pr_nl
	PRS	" TOTAL NUMBER ITEMS: "
	move.w	pr_lasty,d0
	ext.l	d0
	moveq	#0,d1
	bsr	pr_int
	bsr	pr_nl
	bsr	pr_nl
	bsr	pr_close
	lea	pr_save,a3		; the rows back
	moveq	#85,d3
.rs:	move.w	#105,d0
	move.w	d3,d1
	bsr	ms_addr
	moveq	#112-1,d0
.rsc:	move.b	(a3)+,(a0)+
	dbf	d0,.rsc
	addq.w	#1,d3
	cmp.w	#105,d3
	ble.s	.rs
	move.w	#105,d0
	moveq	#85,d1
	move.w	#216,d2
	moveq	#105,d3
	bsr	ms_dirty
	bsr	mouseshow
	BKCOL	3
	movem.l	(sp)+,d3-d7/a3
	rts

; printpartof(rangemin d0, rangemax d1): the cargo items in (min, max), with totals
pr_partof:
	movem.l	d3-d7/a3-a4,-(sp)
	move.w	d0,d6			; min
	move.w	d1,d7			; max
	clr.w	pr_c
	clr.w	pr_d
	PRS	"NUM         NAME         SIZE EACH TOTAL SIZE"
	bsr	pr_nl
	PRS	"___ ____________________ _________ __________"
	bsr	pr_nl
	moveq	#1,d3			; j
.j:	move.w	d3,d0
	add.w	d0,d0
	lea	GS_SHIP+SHIP_CARGO-2(a6),a0
	move.w	0(a0,d0.w),d4		; ship.cargo[j]
	lea	GS_SHIP+SHIP_NUMCARGO-2(a6),a0
	move.w	0(a0,d0.w),d5		; ship.numcargo[j]
	cmp.w	d6,d4
	ble	.nj
	cmp.w	d7,d4
	bge	.nj
	move.w	d5,d0			; write(numcargo:3)
	ext.l	d0
	moveq	#3,d1
	bsr	pr_int
	cmp.w	#ID_LAST_ELEMENT,d4
	ble.s	.f
	move.w	d4,d0			; getartifactname; a := maxcargo
	bsr	getartifactname
	lea	GS_CARGO+(MAXCARGO-1)*CARGO_SIZEOF(a6),a3
	bra.s	.got
.f:	lea	GS_CARGO(a6),a3		; a := 1; while (cargo[a].index <> item) and (a < maxcargo)
	moveq	#1,d0
.fl:	cmp.w	CARGO_INDEX(a3),d4
	beq.s	.got
	cmp.w	#MAXCARGO,d0
	bge.s	.got
	lea	CARGO_SIZEOF(a3),a3
	addq.w	#1,d0
	bra.s	.fl
.got:	PRS	" "
	lea	CARGO_NAME(a3),a0	; write(' ', cargo[a].name)
	bsr	pr_pstr
	move.w	CARGO_SIZE(a3),d0	; write((size/10):10:1)
	ext.l	d0
	moveq	#10,d1
	bsr	pr_tenths
	move.w	CARGO_SIZE(a3),d0	; calt := size*numcargo (integer)
	muls	d5,d0
	add.w	d0,pr_d
	add.w	d0,pr_i
	ext.l	d0
	moveq	#11,d1
	bsr	pr_tenths
	bsr	pr_nl
	addq.w	#1,pr_lastx
	add.w	d5,pr_lasty
	add.w	d5,pr_c
.nj:	addq.w	#1,d3
	cmp.w	#250,d3
	ble	.j
	PRS	"TOTAL: "
	move.w	pr_c,d0
	ext.l	d0
	moveq	#0,d1
	bsr	pr_int
	PRS	"   TOTAL SIZE:"
	move.w	pr_d,d0
	ext.l	d0
	moveq	#0,d1
	bsr	pr_tenths
	bsr	pr_nl
	bsr	pr_nl
	bsr	pr_nl
	movem.l	(sp)+,d3-d7/a3-a4
	rts

; ---------------------------------------------------------------- printinfo (saveload.pas 1016)
; The visited planets by sector (x, y, z beyond 1250): each system's name and position, then per
; planet size, state, robots, cache, scans, contact, the scan's top elements (showbotstuff), the
; life found (re-seeding FPC's random from the planet's seed, as the original). Into TEMP\LPT1.
; Locals as the oracle's -gt build: s starts as $55 bytes (never printed before it is set here).
printinfo:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	pr_open
	bsr	mousehide		; tempscr := rows 85..105, x 75..246
	lea	pr_save,a3
	moveq	#85,d3
.sv:	moveq	#75,d0
	move.w	d3,d1
	bsr	ms_addr
	move.w	#172-1,d0
.svc:	move.b	(a0)+,(a3)+
	dbf	d0,.svc
	addq.w	#1,d3
	cmp.w	#105,d3
	ble.s	.sv
	moveq	#75,d0			; graybutton(75,85,245,105); revgraybutton(84,89,236,101)
	moveq	#85,d1
	move.w	#245,d2
	moveq	#105,d3
	bsr	graybutton
	moveq	#84,d0
	moveq	#89,d1
	move.w	#236,d2
	moveq	#101,d3
	bsr	revgraybutton
	clr.w	pi_last			; last := 0; line := 0
	clr.w	pi_line
	clr.w	pi_sec
.sec:	clr.w	pi_b			; b := 0
	moveq	#1,d7			; j
.j:	move.w	d7,d0			; a3 = tempplan^[j]
	subq.w	#1,d0
	mulu	#PLANET_SIZEOF,d0
	move.l	GS_TEMPPLAN(a6),a3
	add.l	d0,a3
	moveq	#0,d0			; a4 = systems[system]
	move.b	PLANET_SYSTEM(a3),d0
	bsr	pi_sys
	moveq	#0,d6			; a := the sector of the planet's system
	cmp.w	#1250,SYSTEM_X(a4)
	ble.s	.ax
	moveq	#1,d6
.ax:	cmp.w	#1250,SYSTEM_Y(a4)
	ble.s	.ay
	addq.w	#2,d6
.ay:	cmp.w	#1250,SYSTEM_Z(a4)
	ble.s	.az
	addq.w	#4,d6
.az:	tst.w	PLANET_VISITS(a3)
	beq	.bar
	cmp.w	pi_sec,d6
	bne	.bar
	bsr	pi_planet		; (a3 planet, a4 its system, d6 = a, d7 = j)
.bar:	lea	pr_bar-1,a0		; for i:=90 to 100 do screen[i, round(j*0.15+85)] := 44
	moveq	#85,d0
	add.b	0(a0,d7.w),d0
	moveq	#90,d1
	bsr	ms_addr
	moveq	#11-1,d0
.bl:	move.b	#44,(a0)
	lea	320(a0),a0
	dbf	d0,.bl
	addq.w	#1,d7
	cmp.w	#1000,d7
	ble	.j
	tst.w	pi_b			; if b > 0 then writeln(ft, form feed)
	beq.s	.nb
	bsr	pi_ff
.nb:	addq.w	#1,pi_sec
	cmp.w	#8,pi_sec
	blt	.sec
	moveq	#85,d0			; (the bar is under the restored rows: mark them anyway)
	moveq	#85,d1
	move.w	#246,d2
	moveq	#105,d3
	bsr	ms_dirty
	move.w	GS_TSLICE(a6),d0	; delay(tslice*3)
	mulu	#3,d0
	bsr	delay
	bsr	pr_close
	lea	pr_save,a3		; the rows back
	moveq	#85,d3
.rs:	moveq	#75,d0
	move.w	d3,d1
	bsr	ms_addr
	move.w	#172-1,d0
.rsc:	move.b	(a3)+,(a0)+
	dbf	d0,.rsc
	addq.w	#1,d3
	cmp.w	#105,d3
	ble.s	.rs
	moveq	#75,d0
	moveq	#85,d1
	move.w	#246,d2
	moveq	#105,d3
	bsr	ms_dirty
	bsr	mouseshow
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; a4 = systems[d0] (1-based)
pi_sys:	subq.w	#1,d0
	mulu	#SYSTEM_SIZEOF,d0
	lea	GS_SYSTEMS(a6),a4
	add.l	d0,a4
	rts

pi_ff:	move.l	pr_ptr,a0		; a form feed line (the original's '^L' strings)
	move.b	#12,(a0)+
	move.l	a0,pr_ptr
	bra	pr_nl

pi_hdr:	PRS	"  SIZE   STATE  ROBOTS CSH      SCANS    CONTACT ELEM. ALIEN LIFEFORM FOUND"
	bsr	pr_nl
	PRS	"______ _______ _______ ___ __________ __________ _____ ____________________"
	bra	pr_nl

; one planet's line(s): a3 = tempplan^[j], a4 = its system, d6 = a, d7 = j
pi_planet:
	tst.w	pi_b			; the sector's heading
	bne.s	.hd
	PRS	"IRONSEED PLANETARY FILE FOR "
	move.w	pi_sec,d0
	mulu	#8,d0
	lea	pi_secnames,a0
	add.w	d0,a0
	bsr	pr_pstr
	PRS	" SECTOR"
	bsr	pr_nl
	bsr	pr_nl
	bsr	pi_hdr
	move.w	#4,pi_line
.hd:	addq.w	#1,pi_b
	addq.w	#1,pi_line
	moveq	#0,d0			; a new system: its name and position
	move.b	PLANET_SYSTEM(a3),d0
	cmp.w	pi_last,d0
	beq	.same
	move.w	d0,pi_last
	bsr	pr_nl
	cmp.w	#54,pi_line
	ble.s	.nh
	bsr	pi_ff			; writeln(ft, form feed): a new printer page
	bsr	pi_hdr
	move.w	#2,pi_line
.nh:	lea	SYSTEM_NAME(a4),a0
	bsr	pr_pstr
	PRS	" ("
	move.w	SYSTEM_X(a4),d0
	ext.l	d0
	moveq	#0,d1
	bsr	pr_tenths
	PRS	","
	move.w	SYSTEM_Y(a4),d0
	ext.l	d0
	moveq	#0,d1
	bsr	pr_tenths
	PRS	","
	move.w	SYSTEM_Z(a4),d0
	ext.l	d0
	moveq	#0,d1
	bsr	pr_tenths
	PRS	")"
	bsr	pr_nl
	addq.w	#2,pi_line
.same:	moveq	#0,d1			; size: orbit 0 by mode, else by psize (no match: s as it was)
	tst.b	PLANET_ORBIT(a3)
	bne.s	.ps
	move.b	PLANET_MODE(a3),d1
	subq.w	#1,d1
	cmp.w	#2,d1
	bhi.s	.sz
	lea	pi_gsize,a0
	bra.s	.ss
.ps:	move.b	PLANET_PSIZE(a3),d1
	cmp.w	#4,d1
	bhi.s	.sz
	lea	pi_psize,a0
.ss:	mulu	#8,d1
	add.w	d1,a0
	bsr	pi_sets
.sz:	bsr	pi_writes
	moveq	#0,d1			; state
	move.b	PLANET_STATE(a3),d1
	cmp.w	#7,d1
	bhi.s	.st
	mulu	#10,d1
	lea	pi_states,a0
	add.w	d1,a0
	bsr	pi_sets
.st:	bsr	pi_writes
	moveq	#0,d1			; robots: 0-2 (other values keep s)
	move.b	PLANET_BOTS(a3),d1
	cmp.w	#2,d1
	bhi.s	.bt
	mulu	#10,d1
	lea	pi_bots,a0
	add.w	d1,a0
	bsr	pi_sets
.bt:	bsr	pi_writes
	tst.b	PLANET_ORBIT(a3)	; the cache: ' n/7' (a := n), or 4 spaces
	beq.s	.c0
	moveq	#0,d6
	lea	PLANET_CACHE(a3),a0
	moveq	#7-1,d0
.cc:	tst.w	(a0)+
	beq.s	.cn
	addq.w	#1,d6
.cn:	dbf	d0,.cc
	lea	pi_s,a0
	move.b	#4,(a0)+
	move.b	#' ',(a0)+
	moveq	#48,d0
	add.b	d6,d0
	move.b	d0,(a0)+
	move.b	#'/',(a0)+
	move.b	#'7',(a0)+
	bra.s	.cw
.c0:	lea	pi_4sp,a0
	bsr	pi_sets
.cw:	bsr	pi_writes
	move.b	PLANET_NOTES(a3),d0	; scans
	tst.b	PLANET_ORBIT(a3)
	beq.s	.cpl
	btst	#0,d0
	beq.s	.inc
.cpl:	PRS	"   Complete"
	bra.s	.ct
.inc:	PRS	" Incomplete"
.ct:	btst	#1,PLANET_NOTES(a3)	; contact
	beq.s	.nc
	PRS	"  Contacted "
	bra.s	.el
.nc:	PRS	"       None "
.el:	tst.b	PLANET_ORBIT(a3)	; elements
	beq.s	.e0
	btst	#0,PLANET_NOTES(a3)
	beq.s	.eu
	bsr	pi_botstuff
	bra.s	.al
.e0:	PRS	"    "
	bra.s	.al
.eu:	PRS	"Unkn."
.al:	move.b	PLANET_NOTES(a3),d0	; the alien life
	and.b	#2+32,d0
	beq	.unk
	clr.b	pi_str4
	moveq	#0,d0			; case tempplan^[a].system (a: the cache count, or the sector;
	move.w	d6,d1			; a = 0 reads before the array: heap bytes in the Linux build,
	beq.s	.r0			; not a race number there - taken as 0)
	subq.w	#1,d1
	mulu	#PLANET_SIZEOF,d1
	move.l	GS_TEMPPLAN(a6),a0
	add.l	d1,a0
	move.b	PLANET_SYSTEM(a0),d0
.r0:	lea	pi_races,a0
.rc:	move.w	(a0)+,d1
	bmi.s	.other
	move.l	(a0)+,a1
	cmp.w	d1,d0
	bne.s	.rc
	cmp.w	#45,d0			; Ermigen only before event 27
	bne.s	.rset
	move.l	a1,-(sp)
	moveq	#27,d0
	bsr	chevent
	move.l	(sp)+,a1
	tst.w	d0
	bne	.wl
.rset:	lea	pi_str1,a0
	bsr	pstr_cpy
	bra	.wl
.other:	cmp.b	#6,PLANET_STATE(a3)	; void dwellers
	bne.s	.tl
	cmp.b	#2,PLANET_MODE(a3)
	bne.s	.tl
	lea	pi_str1,a0
	lea	pi_void,a1
	bsr	pstr_cpy
	bra	.wl
.tl:	moveq	#-2,d5			; techlvl
	move.b	PLANET_STATE(a3),d0
	move.b	PLANET_MODE(a3),d1
	ext.w	d1
	cmp.b	#2,d0
	bne.s	.t3
	cmp.b	#2,d1
	bne.s	.t23
	moveq	#-1,d5
.t23:	cmp.b	#3,d1
	bne.s	.tok
	moveq	#0,d5
	bra.s	.tok
.t3:	cmp.b	#3,d0
	bne.s	.t4
	move.w	d1,d5
	subq.w	#1,d5
	bra.s	.tok
.t4:	cmp.b	#4,d0
	bne.s	.t5
	move.w	d1,d5
	addq.w	#2,d5
	bra.s	.tok
.t5:	cmp.b	#5,d0
	bne.s	.tok
	cmp.b	#1,d1
	bne.s	.t52
	moveq	#0,d5
.t52:	cmp.b	#2,d1
	bne.s	.tok
	moveq	#-1,d5
.tok:	cmp.w	#-2,d5
	bne.s	.tm1
	lea	pi_str1,a0
	lea	pi_none,a1
	bsr	pstr_cpy
	bra	.wl
.tm1:	moveq	#0,d0			; randseed := seed
	move.w	PLANET_SEED(a3),d0
	bsr	mt_setseed
	cmp.w	#-1,d5
	bne	.tlife
	moveq	#0,d0			; a := random(word(state+mode+seed)) mod 3
	move.b	PLANET_STATE(a3),d0
	moveq	#0,d1
	move.b	PLANET_MODE(a3),d1
	add.w	d1,d0
	add.w	PLANET_SEED(a3),d0
	and.l	#$ffff,d0
	bsr	mt_random
	divu	#3,d0
	swap	d0
	move.w	d0,d6
	beq.s	.p0
	cmp.w	#1,d6
	beq.s	.p1
	moveq	#3,d0			; 2: str4 := random(3) of chaosms/communes/hierarchies
	bsr	mt_random
	mulu	#13,d0
	lea	pi_groups,a1
	add.w	d0,a1
	lea	pi_str4,a0
	bsr	pstr_cpy
	lea	pi_single,a1
	bra.s	.p
.p0:	moveq	#2,d0
	bsr	mt_random
	lea	pi_short,a1
	tst.w	d0
	beq.s	.p
	lea	pi_long,a1
	bra.s	.p
.p1:	moveq	#2,d0
	bsr	mt_random
	lea	pi_simple,a1
	tst.w	d0
	beq.s	.p
	lea	pi_complex,a1
.p:	lea	pi_str1,a0
	bsr	pstr_cpy
	bra.s	.wl
.tlife:	moveq	#11,d0			; 0..5: str4 := alientypes[random(11)]; str1 := diet
	bsr	mt_random
	mulu	#13,d0
	lea	alientypes,a1
	add.w	d0,a1
	lea	pi_str4,a0
	bsr	pstr_cpy
	moveq	#5,d0
	bsr	mt_random
	mulu	#16,d0
	lea	pi_diets,a1
	add.w	d0,a1
	lea	pi_str1,a0
	bsr	pstr_cpy
.wl:	tst.b	pi_str4			; str4 cut to fit 20 with str1
	beq.s	.w2
	moveq	#0,d0
	move.b	pi_str1,d0
	moveq	#0,d1
	move.b	pi_str4,d1
	add.w	d0,d1
	addq.w	#1,d1
	cmp.w	#20,d1
	ble.s	.w2
	moveq	#19,d1
	sub.w	d0,d1
	move.b	d1,pi_str4
.w2:	PRS	" "
	lea	pi_str1,a0
	bsr	pr_pstr
	PRS	" "
	lea	pi_str4,a0
	bsr	pr_pstr
	bra.s	.eol
.unk:	tst.b	PLANET_ORBIT(a3)
	beq.s	.eol
	PRS	" Unknown"
.eol:	bra	pr_nl

pi_sets:				; s := the Pascal string at a0 (s keeps its last value otherwise)
	move.l	a0,a1
	lea	pi_s,a0
	bra	pstr_cpy
pi_writes:
	lea	pi_s,a0
	bra	pr_pstr

; showbotstuff(j): the 5 most common elements of the planet's state (scan.dta) as letters A-Q;
; spaces for the rest. (The original's global y counts: GS_Y.)
pi_botstuff:
	movem.l	d3-d5,-(sp)
	tst.b	pi_scanok		; scan.dta once
	bne.s	.ok
	lea	pi_fn_scan,a0
	lea	pi_scan,a1
	move.l	#SCAN_SIZEOF,d0
	bsr	load_exact
	st	pi_scanok
.ok:	lea	pi_scan,a0		; amounts[j] := temp^[j, state]
	moveq	#0,d0
	move.b	PLANET_STATE(a3),d0
	add.w	d0,a0
	lea	pi_amt,a1
	moveq	#17-1,d1
.am:	move.b	(a0),(a1)+
	lea	SCANDATA_SIZEOF(a0),a0
	dbf	d1,.am
	clr.w	GS_Y(a6)		; y := 0
.rep:	addq.w	#1,GS_Y(a6)
	lea	pi_amt,a0		; max := amounts[0]; index := 0; the largest (first of equals)
	moveq	#0,d3
	move.b	(a0),d3
	moveq	#0,d4
	moveq	#0,d5
.mx:	moveq	#0,d0
	move.b	0(a0,d5.w),d0
	cmp.w	d3,d0
	bls.s	.mn
	move.w	d0,d3
	move.w	d5,d4
.mn:	addq.w	#1,d5
	cmp.w	#17,d5
	blt.s	.mx
	tst.w	d3
	beq.s	.done
	move.l	pr_ptr,a1		; write(chr(65+index)); amounts[index] := 0
	moveq	#65,d0
	add.b	d4,d0
	move.b	d0,(a1)+
	move.l	a1,pr_ptr
	clr.b	0(a0,d4.w)
	cmp.w	#5,GS_Y(a6)
	bne.s	.rep
	bra.s	.x
.done:	move.w	GS_Y(a6),d0		; if (max=0) and (y<5) then for j:=y to 5 do write(' ')
	cmp.w	#5,d0
	bge.s	.x
	move.l	pr_ptr,a1
.sp:	move.b	#' ',(a1)+
	addq.w	#1,d0
	cmp.w	#5,d0
	ble.s	.sp
	move.l	a1,pr_ptr
.x:	movem.l	(sp)+,d3-d5
	rts

	section	data
pi_secnames:	dc.b	5,"ALPHA  ",4,"BETA   ",5,"GAMMA  ",5,"DELTA  ",7,"EPSILON",4,"ZETA   ",3,"ETA    ",5,"THETA  "
pi_gsize:	dc.b	6," Giant ",6," Large ",6,"  Tiny "
pi_psize:	dc.b	6,"  Tiny ",6," Small ",6,"Medium ",6," Large ",6," Giant "
pi_states:	dc.b	8," Gaseous ",8,"  Active ",8,"  Stable ",8," Ea.Life ",8," Ad.Life ",8,"   Dying ",8,"    Dead ",8,"    Star "
pi_bots:	dc.b	8,"    None ",8," Minebot ",8," Factory "
pi_4sp:		dc.b	4,"    "
pi_void:	dc.b	13,"Void Dwellers"
pi_none:	dc.b	4,"None"
pi_short:	dc.b	20,"Short Chain Proteins"
pi_long:	dc.b	19,"Long Chain Proteins"
pi_simple:	dc.b	18,"Simple Protoplasms"
pi_complex:	dc.b	19,"Complex Protoplasms"
pi_single:	dc.b	12,"Singlecelled"
pi_groups:	dc.b	7,"Chaosms     ",8,"Communes    ",11,"Hierarchies "
pi_diets:	dc.b	11,"Carnivorous    ",11,"Herbivorous    ",10,"Omnivorous     ",13,"Cannibalistic  ",14,"Photosynthetic "
pi_r93:		dc.b	8,"Sengzhac"
pi_r138:	dc.b	6,"D'phak"
pi_r45:		dc.b	7,"Ermigen"
pi_r221:	dc.b	8,"Titarian"
pi_r78:		dc.b	11,"Quai Pa'loi"
pi_r171:	dc.b	4,"Icon"
pi_r191:	dc.b	9,"The Guild"
pi_fn_scan:	dc.b	"DATA",92,"SCAN.DTA",0
	even
pi_races:	dc.w	93
	dc.l	pi_r93
	dc.w	138
	dc.l	pi_r138
	dc.w	45
	dc.l	pi_r45
	dc.w	221
	dc.l	pi_r221
	dc.w	78
	dc.l	pi_r78
	dc.w	171
	dc.l	pi_r171
	dc.w	191
	dc.l	pi_r191
	dc.w	-1
	include	"prbar.i"
	even
	section	bss
pi_sec:		ds.w	1
pi_b:		ds.w	1
pi_line:	ds.w	1
pi_last:	ds.w	1
pi_s:		ds.b	14
pi_str1:	ds.b	22
pi_str4:	ds.b	22
pi_amt:		ds.b	18
pi_scan:	ds.b	SCAN_SIZEOF
pi_scanok:	ds.b	1
	even
	section	text

	section	data
pr_fn:		dc.b	"TEMP",92,"LPT1",0
pr_fn_tmp:	dc.b	"TEMP",0
	even
	section	bss
pr_mark:	ds.l	1
pr_buf:		ds.l	1
pr_ptr:		ds.l	1
pr_i:		ds.w	1
pr_c:		ds.w	1
pr_d:		ds.w	1
pr_lastx:	ds.w	1
pr_lasty:	ds.w	1
pr_s:		ds.b	32
pr_t:		ds.b	32
pr_save:	ds.b	21*172
	even
	section	text
