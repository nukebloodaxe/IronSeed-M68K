; crewgen.s - CREWGEN.PRG: port of crewgen.pas (crew and ship selection for a new game).
; Started by IS.PRG with "/makeseed". Exit codes as the original: 3 back to the title (Esc at
; the ship, F1, Alt-Q), 48+n after saving the new game in slot n (IS.PRG then starts MAIN).
;
; Screen modes (tools/mkcrewgen.py -> DATA\CGMODES.DAT): the screen shows different things
; at different times, so it has one band design per mode, each with its own picture of the
; background (char.cpr): SHIP (level 0), CREW (levels 1-6; colours 128-159 cycle on own
; slots), SAVE (the save dialog over the crew screen; the frozen graph re-mapped by
; vid_lut_remap) and EGG (the easter egg). setmode switches bands, LUTs and background; the
; code redraws what the original had on the screen at that moment.
; Everything else is the original's logic, line by line, with FPC's random generator (mt.s),
; so the game state matches the Linux build exactly (tests: oracle dumps, saved files).
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"
	include	"cgdata.i"

CG_SHIP		equ	0
CG_CREW		equ	1
CG_SAVE		equ	2
CG_EGG		equ	3
TITLE_X		equ	141
PORT_SIZE	equ	70*70
SHIP_PART	equ	75*58
ANI_FRAME	equ	35*48
CREWREC		equ	CREWDATA_SIZEOF
CREW_DTA_SIZE	equ	30*CREWDATA_SIZEOF
SYSSET_SIZE	equ	250*12
DESC_LEN	equ	53		; string[52]

	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	lea	fn_script,a0
	bsr	scr_open
	moveq	#0,d0
	bsr	vid_set_fade
	move.l	sys_basepage,a0		; checkparams: "/makeseed" or halt(4)
	lea	$81(a0),a0
	lea	arg_seed,a1
	bsr	has_arg
	tst.w	d0
	bne.s	.ok
	tst.w	scr_test		; (test runs may start it directly)
	bne.s	.ok
	moveq	#4,d0
	bra	sys_exit
.ok:	move.w	#3,exitcode			; code:=3; tslice:=10; randomize
	move.w	#10,GS_TSLICE(a6)
	bsr	mt_randomize
	bsr	load_all
	bsr	readydata
	bsr	mainloop
	bsr	mod_stop		; stopmod; fading; mousehide
	moveq	#16,d0
	moveq	#0,d1
	move.w	#47*5,d2
	bsr	vid_fade_ms
	bsr	kbd_cursor_hide
	move.w	exitcode,d0
	bra	sys_exit

; ---------------------------------------------------------------
load_all:
	lea	files,a3
.f:	move.l	(a3)+,d0		; size, 0 ends
	beq.s	.x
	move.l	d0,d3
	bsr	mem_alloc
	bcs	fatal
	move.l	(a3)+,a1		; pointer variable
	move.l	a0,(a1)
	move.l	(a3)+,d1		; file name, or 0: just memory
	beq.s	.f
	move.l	a0,a1
	move.l	d1,a0
	move.l	d3,d0
	bsr	fil_load
	bcs	fatal
	cmp.l	d3,d0
	bne	fatal
	bra.s	.f
.x:	rts

fatal:	pea	msg_fatal
	GEMDOS	GD_CCONWS,6
	moveq	#4,d0
	bra	sys_exit

; ---------------------------------------------------------------
; readydata (crewgen.pas 960)
readydata:
	clr.w	toggle
	bsr	initcrew
	lea	fn_mod,a0		; playmod(true, CHARGEN.MOD)
	bsr	mod_load
	bsr	orc_dump		; loadscreen(char)
	move.l	cgd,a0
	lea	CGD_PALCHAR(a0),a0
	lea	GS_COLORS(a6),a1
	move.w	#768/4-1,d0
.p:	move.l	(a0)+,(a1)+
	dbf	d0,.p
	moveq	#CG_SHIP,d0
	bsr	setmode
	moveq	#30,d0			; the ball, lowered
	bsr	drawball
	move.l	cgd,a0			; the cursor from the picture (its area is cleared)
	lea	CGD_CURSOR(a0),a0
	bsr	kbd_cursor_set
	bsr	showtitle
	bsr	raiseball
	bsr	drawship
	bsr	kbd_cursor_hide
	bsr	displayship2
	moveq	#0,d0			; fadein
	moveq	#16,d1
	move.w	#47*5,d2
	bsr	vid_fade_ms
	bra	kbd_cursor_show

; initcrew (crewgen.pas 793)
initcrew:
	movem.l	d3-d7/a3-a5,-(sp)
	clr.w	quit
	clr.w	crewnum
	clr.w	inputlevel
	move.w	#191,GS_TCOLOR(a6)
	clr.w	GS_BKCOLOR(a6)
	lea	GS_SHIP+SHIP_CREW(a6),a0
	moveq	#6-1,d0
.cr:	moveq	#20-1,d1		; fillchar(name,20,ord(' ')) - from the length byte on
	move.l	a0,a1
.sp:	move.b	#' ',(a1)+
	dbf	d1,.sp
	move.b	#50,CREW_PHY(a0)
	move.b	#50,CREW_MEN(a0)
	move.b	#50,CREW_EMO(a0)
	clr.b	CREW_STATUS(a0)
	clr.l	CREW_XP(a0)
	clr.b	CREW_LEVEL(a0)
	clr.b	CREW_INDEX(a0)
	clr.b	CREW_SAN(a0)
	clr.b	CREW_PERF(a0)
	clr.b	CREW_SKILL(a0)
	lea	CREW_SIZEOF(a0),a0
	dbf	d0,.cr
	lea	GS_SHIP(a6),a3
	move.b	#1,SHIP_SHIPTYPE(a3)
	move.b	#1,SHIP_SHIPTYPE+1(a3)
	move.b	#1,SHIP_SHIPTYPE+2(a3)
	lea	SHIP_GUNNODES(a3),a0
	moveq	#10-1,d0
.g:	clr.b	(a0)+
	dbf	d0,.g
	lea	SHIP_CARGO(a3),a0	; cargo, numcargo (500 bytes each), engrteam
	move.w	#(500+500)/2-1,d0
.c:	clr.w	(a0)+
	dbf	d0,.c
	lea	SHIP_ENGRTEAM(a3),a0
	moveq	#3*TEAM_SIZEOF/2-1,d0
.e:	clr.w	(a0)+
	dbf	d0,.e
	lea	SHIP_DAMAGES(a3),a0
	lea	init_damages,a1
	moveq	#7-1,d0
.d:	move.b	(a1)+,(a0)+
	dbf	d0,.d
	moveq	#30,d0			; engrteam[1]: timeleft := damages[CPU]*70 + random(30)
	bsr	mt_random
	add.w	#22*70,d0
	move.w	d0,SHIP_ENGRTEAM+TEAM_TIMELEFT(a3)
	move.w	#7,SHIP_ENGRTEAM+TEAM_JOB(a3)
	clr.w	SHIP_ENGRTEAM+TEAM_JOBTYPE(a3)
	lea	SHIP_EVENTS(a3),a0	; fillchar(events,50,255); fillchar(events[50],15,0)
	moveq	#50-1,d0
.ev:	move.b	#255,(a0)+
	dbf	d0,.ev
	moveq	#15-1,d0
.ev0:	clr.b	(a0)+
	dbf	d0,.ev0
	clr.b	SHIP_RESEARCH(a3)
	move.w	#2001,SHIP_CARGO(a3)	; probot x2, minebot, manufactory, dirk
	move.w	#2,SHIP_NUMCARGO(a3)
	move.w	#2002,SHIP_CARGO+2(a3)
	move.w	#1,SHIP_NUMCARGO+2(a3)
	move.w	#2003,SHIP_CARGO+4(a3)
	move.w	#1,SHIP_NUMCARGO+4(a3)
	move.w	#1000,SHIP_CARGO+6(a3)
	move.w	#1,SHIP_NUMCARGO+6(a3)
	lea	SHIP_OPTIONS(a3),a0
	lea	init_options,a1
	moveq	#10-1,d0
.o:	move.b	(a1)+,(a0)+
	dbf	d0,.o
	move.w	#166,SHIP_POSX(a3)
	move.w	#226,SHIP_POSY(a3)
	move.w	#33,SHIP_POSZ(a3)
	move.w	#1,SHIP_ORBITING(a3)
	move.w	#15,SHIP_SHIELDLEVEL(a3)
	move.w	#1500,SHIP_SHIELD(a3)
	move.w	#3784,SHIP_STARDATE+4(a3)
	move.w	#2,SHIP_STARDATE(a3)
	move.w	#3,SHIP_STARDATE+2(a3)
	move.w	#8,SHIP_STARDATE+6(a3)
	move.w	#75,SHIP_STARDATE+8(a3)
	clr.b	SHIP_SHIELDOPT(a3)
	clr.b	SHIP_SHIELDOPT+1(a3)
	clr.b	SHIP_SHIELDOPT+2(a3)
	clr.b	SHIP_ARMED(a3)
	move.w	#32000,SHIP_WANDERING+ONEALIEN_ALIENID(a3)
	; the systems and their planets
.rep:	move.l	planets,a0		; fillchar(planets^,sizeof(planarray),0)
	move.w	#PLANARRAY_SIZEOF/4-1,d0
.z:	clr.l	(a0)+
	dbf	d0,.z
	moveq	#0,d6			; curplan
	moveq	#1,d7			; j (system)
.sys:	lea	GS_SYSTEMS(a6),a3
	move.w	d7,d0
	subq.w	#1,d0
	mulu	#SYSTEM_SIZEOF,d0
	add.w	d0,a3			; systems[j]
	lea	s_unknown,a1
	moveq	#13-1,d0
.nm:	move.b	(a1)+,(a3)+
	dbf	d0,.nm
	lea	-13(a3),a3
	move.l	oldsys,a0
	move.w	d7,d0
	subq.w	#1,d0
	mulu	#12,d0
	add.w	d0,a0
	move.w	(a0)+,SYSTEM_X(a3)
	move.w	(a0)+,SYSTEM_Y(a3)
	move.w	(a0)+,SYSTEM_Z(a3)
	moveq	#3,d0			; numplanets:=random(3)+3
	bsr	mt_random
	addq.b	#3,d0
	cmp.w	#145,d7			; Oban
	bne.s	.no
	moveq	#3,d0
.no:	move.b	d0,SYSTEM_NUMPLANETS(a3)
	clr.w	SYSTEM_VISITS(a3)
	clr.w	SYSTEM_DATEY(a3)
	clr.b	SYSTEM_DATEM(a3)
	clr.b	SYSTEM_NOTES(a3)
	clr.l	radii
	clr.l	radii+4
	moveq	#1,d5			; i (planet)
.pl:	moveq	#0,d0
	move.b	SYSTEM_NUMPLANETS(a3),d0
	cmp.w	d0,d5
	bgt	.nsys
	addq.w	#1,d6
	cmp.w	#1000,d6
	bgt	.planerror
	move.l	planets,a4
	move.w	d6,d0
	subq.w	#1,d0
	mulu	#PLANET_SIZEOF,d0
	add.l	d0,a4			; planets^[curplan]
	cmp.w	#1,d5
	bne.s	.orb
	clr.b	PLANET_ORBIT(a4)
	bra.s	.orbd
.orb:	moveq	#7,d0			; repeat a:=random(7)+1 until radii[a]=0
	bsr	mt_random
	addq.w	#1,d0
	lea	radii,a0
	tst.b	0(a0,d0.w)
	bne.s	.orb
	move.b	#1,0(a0,d0.w)
	move.b	d0,PLANET_ORBIT(a4)
.orbd:	move.b	d7,PLANET_SYSTEM(a4)
	moveq	#50,d0
	bsr	mt_random
	move.b	d0,PLANET_WATER(a4)
	move.w	#64000,d0
	bsr	mt_random
	move.w	d0,PLANET_SEED(a4)
	moveq	#5,d0
	bsr	mt_random
	move.b	d0,PLANET_PSIZE(a4)
	clr.b	PLANET_BOTS(a4)		; cache, dates, visits, notes: already 0
	cmp.w	#145,d7
	bne.s	.st
	cmp.w	#1,d5
	beq.s	.st
	move.b	#3,PLANET_MODE(a4)
	move.l	#2000,PLANET_AGE(a4)
	cmp.w	#2,d5
	bne.s	.ob3
	move.b	#5,PLANET_STATE(a4)
	move.b	#4,PLANET_ORBIT(a4)
	bra.s	.std
.ob3:	move.b	#2,PLANET_STATE(a4)
	move.b	#2,PLANET_ORBIT(a4)
	bra.s	.std
.st:	move.l	a4,a0
	move.w	d5,d0
	bsr	setstate
.std:	cmp.w	#1,d5
	bne.s	.np
	move.b	PLANET_MODE(a4),SYSTEM_MODE(a3)
.np:	addq.w	#1,d5
	bra	.pl
.nsys:	addq.w	#1,d7
	cmp.w	#250,d7
	ble	.sys
.planerror:
	cmp.w	#400,d6			; until (curplan>400) and (curplan<1001)
	ble	.rep
	cmp.w	#1001,d6
	bge	.rep
	lea	GS_SYSTEMS+144*SYSTEM_SIZEOF(a6),a3	; Oban
	lea	s_oban,a1
	moveq	#13-1,d0
.ob:	move.b	(a1)+,(a3)+
	dbf	d0,.ob
	lea	-13(a3),a3
	move.w	#3784,SYSTEM_DATEY(a3)
	move.b	#2,SYSTEM_DATEM(a3)
	move.w	#1,SYSTEM_VISITS(a3)
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; setstate (crewgen.pas 714): a0 = planet, d0.w = spot
setstate:
	movem.l	d3/a3,-(sp)
	move.l	a0,a3
	cmp.w	#1,d0
	bne.s	.n1
	moveq	#7,d0			; age:=random(7); mode 1 (0-3), 2 (4-5), 3; state:=7
	bsr	mt_random
	move.l	d0,PLANET_AGE(a3)
	moveq	#1,d1
	cmp.w	#3,d0
	ble.s	.m1
	moveq	#2,d1
	cmp.w	#5,d0
	ble.s	.m1
	moveq	#3,d1
.m1:	move.b	d1,PLANET_MODE(a3)
	move.b	#7,PLANET_STATE(a3)
	bra	.x
.n1:	moveq	#7,d0			; state:=random(7)
	bsr	mt_random
	move.b	d0,PLANET_STATE(a3)
	add.w	d0,d0
	move.w	.tab(pc,d0.w),d0
	jmp	.tab(pc,d0.w)
.tab:	dc.w	.s0-.tab,.s1-.tab,.s2-.tab,.s3-.tab,.s4-.tab,.s5-.tab,.s6-.tab
.s0:	moveq	#5,d0
	bsr	mt_random
	move.l	d0,PLANET_AGE(a3)
	moveq	#1,d3			; 0-1, 2-3, else
	cmp.w	#1,d0
	ble	.set
	moveq	#2,d3
	cmp.w	#3,d0
	ble	.set
	moveq	#3,d3
	bra	.set
.s1:	moveq	#11,d0
	bsr	mt_random
	move.l	d0,PLANET_AGE(a3)
	moveq	#1,d3			; 0-4, 5-8, else
	cmp.w	#4,d0
	ble	.set
	moveq	#2,d3
	cmp.w	#8,d0
	ble	.set
	moveq	#3,d3
	bra	.set
.s2:	move.w	#64000,d0		; age:=random(64000)*7812
	bsr	mt_random
	mulu	#7812,d0
	move.l	d0,PLANET_AGE(a3)
	moveq	#3,d3
	cmp.l	#350000000,d0
	bgt	.set
	moveq	#2,d3
	cmp.l	#200000000,d0
	bgt	.set
	moveq	#1,d3
	bra.s	.set
.s3:	move.w	#15001,d0		; age:=random(15001)*1000
	bsr	mt_random
	mulu	#1000,d0
	move.l	d0,PLANET_AGE(a3)
	moveq	#3,d3
	cmp.l	#150005000,d0
	bgt.s	.set
	moveq	#2,d3
	cmp.l	#150000000,d0
	bgt.s	.set
	moveq	#1,d3
	bra.s	.set
.s4:	move.w	#5000,d0
	bsr	mt_random
	move.l	d0,PLANET_AGE(a3)
	moveq	#3,d3
	cmp.w	#3000,d0
	bgt.s	.set
	moveq	#2,d3
	cmp.w	#2000,d0
	bgt.s	.set
	moveq	#1,d3
	bra.s	.set
.s5:	move.w	#5000,d0
	bsr	mt_random
	move.l	d0,PLANET_AGE(a3)
	moveq	#3,d3
	cmp.w	#5500,d0
	bgt.s	.set
	moveq	#2,d3
	cmp.w	#1500,d0
	bgt.s	.set
	moveq	#1,d3
	bra.s	.set
.s6:	moveq	#100,d0			; age:=random(100)*1000 (never > 100000);
	bsr	mt_random		; if random(2)=0 then mode:=3; mode:=1
	mulu	#1000,d0
	move.l	d0,PLANET_AGE(a3)
	moveq	#2,d0
	bsr	mt_random
	moveq	#1,d3
.set:	move.b	d3,PLANET_MODE(a3)
	move.w	#2000,d0		; age:=random(2000)
	bsr	mt_random
	move.l	d0,PLANET_AGE(a3)
.x:	movem.l	(sp)+,d3/a3
	rts

; ---------------------------------------------------------------
; setmode: d0.w = CG_*: bands, LUTs, reps and that mode's background; keeps the cursor hidden
; (callers show it). Draws the toggle switch in its current state.
setmode:
	move.l	a3,-(sp)
	move.w	d0,cg_mode
	mulu	#CGM_MODE,d0
	move.l	cgm,a3
	lea	6(a3,d0.l),a3
	bsr	kbd_cursor_hide
	move.l	a3,a0
	move.l	vid_phys,a1
	bsr	pic_show
	move.l	a3,a0
	add.l	#CGM_MODE-64,a0
	bsr	vid_set_keep
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	cmp.w	#CG_SAVE,cg_mode
	bne.s	.ns
	move.w	#128,d0			; the graph's colours, frozen
	moveq	#32,d1
	bsr	vid_lut_remap
.ns:	cmp.w	#CG_EGG,cg_mode
	beq.s	.x
	bsr	draw_switch
.x:	move.l	(sp)+,a3
	rts

; the background of the current mode (planar)
mode_bg:
	move.w	cg_mode,d0
	mulu	#CGM_MODE,d0
	move.l	cgm,a0
	add.l	d0,a0
	lea	6+ISP_DATA+64(a0),a0
	rts

; toggle switch at 247-253 x 107-112: the picture's pixels, -144 when on (plainfadearea)
draw_switch:
	movem.l	d3-d4/a3,-(sp)
	move.l	cgd,a3
	lea	CGD_SWITCH(a3),a3
	moveq	#0,d4
	tst.w	toggle
	beq.s	.off
	move.w	#-144,d4
.off:	moveq	#0,d3
.r:	lea	sw_row,a0
	moveq	#7-1,d0
.c:	move.b	(a3)+,d1
	add.b	d4,d1
	move.b	d1,(a0)+
	dbf	d0,.c
	lea	sw_row,a0
	move.w	#247,d0
	move.w	#107,d1
	add.w	d3,d1
	moveq	#7,d2
	bsr	gfx_chunky_span
	addq.w	#1,d3
	cmp.w	#6,d3
	bne.s	.r
	movem.l	(sp)+,d3-d4/a3
	rts

toggleswitch:
	bsr	kbd_cursor_hide
	not.w	toggle
	bsr	draw_switch
	bra	kbd_cursor_show

; ---------------------------------------------------------------
; the ball (charani.dta): d0.w = frame 0-30 at 22, 81 (48 x 35): the pre-rendered planar frame
; of the current mode (DATA\CGANI.DAT, groups 1-4 = x 16-79)
drawball:
	movem.l	d3-d7/a3,-(sp)
	move.w	d0,ballframe
	move.w	cg_mode,d1
	mulu	#31,d1
	add.w	d1,d0
	mulu	#35*32,d0
	move.l	cga,a0
	add.l	d0,a0
	move.l	gfx_target,a1
	lea	81*SCR_BPL+8(a1),a1
	moveq	#35-1,d0
.r:	movem.l	(a0)+,d1-d7/a3
	movem.l	d1-d7/a3,(a1)
	lea	SCR_BPL(a1),a1
	dbf	d0,.r
	movem.l	(sp)+,d3-d7/a3
	rts

lowerball:
	move.l	d3,-(sp)
	bsr	kbd_cursor_hide
	moveq	#0,d3
.l:	move.w	d3,d0
	bsr	drawball
	move.w	GS_TSLICE(a6),d0
	bsr	tim_delay
	addq.w	#1,d3
	cmp.w	#30,d3
	ble.s	.l
	bsr	kbd_cursor_show
	move.l	(sp)+,d3
	rts

raiseball:
	move.l	d3,-(sp)
	bsr	kbd_cursor_hide
	moveq	#30,d3
.l:	move.w	d3,d0
	bsr	drawball
	move.w	GS_TSLICE(a6),d0
	bsr	tim_delay
	dbf	d3,.l
	bsr	kbd_cursor_show
	move.l	(sp)+,d3
	rts

; ---------------------------------------------------------------
; showtitle (crewgen.pas 564)
showtitle:
	bsr	kbd_cursor_hide
	move.w	inputlevel,d0
	bsr	print_title
	bra	kbd_cursor_show
print_title:				; d0.w = level (0-6)
	move.l	d3,-(sp)
	move.w	d0,d3
	move.w	GS_BKCOLOR(a6),title_bk
	lea	s_shipsel,a0
	tst.w	d3
	beq.s	.p
	lea	s_crewsel,a0
.p:	move.w	#141,d0
	moveq	#100,d1
	bsr	txt_fast
	move.w	d3,d0
	mulu	#12,d0
	lea	leveltitles,a0
	add.w	d0,a0
	move.w	#149,d0
	moveq	#106,d1
	bsr	txt_fast
	move.l	(sp)+,d3
	rts

; ---------------------------------------------------------------
; calculateship (crewgen.pas 371)
calculateship:
	lea	GS_SHIP+SHIP_SHIPTYPE(a6),a0
	lea	shipdata,a1
	clr.w	SD_CARGO(a1)
	moveq	#0,d0
	move.b	(a0),d0			; heavyness
	subq.w	#1,d0
	mulu	#8,d0
	lea	tab_heavy,a2
	add.w	d0,a2
	move.w	(a2)+,SD_GUNS(a1)
	move.w	(a2)+,SD_MASS(a1)
	move.w	(a2)+,SD_FUEL(a1)
	move.w	(a2)+,SD_HULL(a1)
	cmp.b	#2,(a0)
	bne.s	.p
	add.w	#50,SD_CARGO(a1)
.p:	moveq	#0,d0
	move.b	1(a0),d0		; purpose: guns, mass, fuel, cargo, hull
	subq.w	#1,d0
	mulu	#10,d0
	lea	tab_purpose,a2
	add.w	d0,a2
	move.w	(a2)+,d0
	add.w	d0,SD_GUNS(a1)
	move.w	(a2)+,d0
	add.w	d0,SD_MASS(a1)
	move.w	(a2)+,d0
	add.w	d0,SD_FUEL(a1)
	move.w	(a2)+,d0
	add.w	d0,SD_CARGO(a1)
	move.w	(a2)+,d0
	add.w	d0,SD_HULL(a1)
	moveq	#0,d0
	move.b	2(a0),d0		; vessel: guns, mass, cargo, hull
	subq.w	#1,d0
	lsl.w	#3,d0
	lea	tab_vessel,a2
	add.w	d0,a2
	move.w	(a2)+,d0
	add.w	d0,SD_GUNS(a1)
	move.w	(a2)+,d0
	add.w	d0,SD_MASS(a1)
	move.w	(a2)+,d0
	add.w	d0,SD_CARGO(a1)
	move.w	(a2)+,d0
	add.w	d0,SD_HULL(a1)
	move.l	#270000,d0		; accel:=270000 div mass
	divu	SD_MASS(a1),d0
	move.w	d0,SD_ACCEL(a1)
	rts

; drawship (crewgen.pas 443)
drawship:
	movem.l	d3-d5/a3,-(sp)
	bsr	kbd_cursor_hide
	bsr	calculateship
	move.w	GS_BKCOLOR(a6),panel_bk
	moveq	#30,d0			; clear 30-260 x 122-127
	moveq	#122,d1
	move.w	#260,d2
	moveq	#127,d3
	moveq	#0,d4
	bsr	gfx_bar
	lea	GS_SHIP+SHIP_SHIPTYPE(a6),a3
	lea	strbuf,a0		; shipnames[h-1]+' '+shipnames[p+2]+' '+shipnames[v+5]
	moveq	#0,d0
	move.b	(a3),d0
	subq.w	#1,d0
	bsr	shipname
	move.l	a1,-(sp)
	lea	strbuf,a0
	move.l	(sp)+,a1
	bsr	pstr_cpy
	lea	strbuf,a0
	lea	s_space,a1
	bsr	pstr_cat
	moveq	#0,d0
	move.b	1(a3),d0
	addq.w	#2,d0
	bsr	shipname
	lea	strbuf,a0
	bsr	pstr_cat
	lea	strbuf,a0
	lea	s_space,a1
	bsr	pstr_cat
	moveq	#0,d0
	move.b	2(a3),d0
	addq.w	#5,d0
	bsr	shipname
	lea	strbuf,a0
	bsr	pstr_cat
	moveq	#0,d0			; x = 131 - round(length(s)*2.5)
	move.b	strbuf,d0
	mulu	#5,d0
	move.w	d0,d1
	lsr.w	#1,d0
	btst	#0,d1
	beq.s	.r
	btst	#0,d0			; x.5: to even
	beq.s	.r
	addq.w	#1,d0
.r:	neg.w	d0
	add.w	#131,d0
	moveq	#122,d1
	lea	strbuf,a0
	bsr	txt_fast
	lea	shiplines,a3		; label x, value x, y, value width, field, suffix
.l:	move.w	(a3)+,d5		; y, 0 ends
	beq.s	.x
	move.w	(a3)+,d0		; label
	move.w	d5,d1
	move.l	(a3)+,a0
	bsr	txt_fast
	lea	shipdata,a0		; value
	add.w	(a3)+,a0
	move.w	(a3)+,d1		; width
	move.w	(a0),d0
	ext.l	d0
	lea	strbuf,a0
	bsr	int_str
	move.l	(a3)+,a1
	lea	strbuf,a0
	bsr	pstr_cat
	move.w	(a3)+,d0
	move.w	d5,d1
	lea	strbuf,a0
	bsr	txt_fast
	bra.s	.l
.x:	bsr	kbd_cursor_show
	movem.l	(sp)+,d3-d5/a3
	rts

shipname:				; d0.w = 0-8 -> a1 = shipnames[d0]
	mulu	#10,d0
	lea	shipnames,a1
	add.w	d0,a1
	rts

; displayship2(121,13) (display.pas 2123): the three parts of shippix.dta, pre-composed
; (DATA\CGSHIP.DAT: 27 ships x 75 rows x groups 7-18)
displayship2:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	GS_SHIP+SHIP_SHIPTYPE(a6),a0
	moveq	#0,d0			; (h-1)*9 + (p-1)*3 + v-1
	move.b	(a0),d0
	mulu	#9,d0
	moveq	#0,d1
	move.b	1(a0),d1
	mulu	#3,d1
	add.w	d1,d0
	moveq	#0,d1
	move.b	2(a0),d1
	add.w	d1,d0
	sub.w	#9+3+1,d0
	mulu	#75*96,d0
	move.l	cgs,a0
	add.l	d0,a0
	move.l	gfx_target,a1
	lea	13*SCR_BPL+7*8(a1),a1
	move.w	#$007f,d6		; x 121-127 of group 7, x 288-294 of group 18: only
	move.w	#$fe00,d7		; the ship's 174 columns change (as the original)
	moveq	#75-1,d0
.r:	move.w	d6,d1
	bsr.s	.mask
	movem.l	(a0)+,d1-d5/a2-a5	; groups 8-17: 80 bytes
	movem.l	d1-d5/a2-a5,(a1)
	movem.l	(a0)+,d1-d5/a2-a5
	movem.l	d1-d5/a2-a5,36(a1)
	move.l	(a0)+,72(a1)
	move.l	(a0)+,76(a1)
	lea	80(a1),a1
	move.w	d7,d1
	bsr.s	.mask
	lea	SCR_BPL-96(a1),a1
	dbf	d0,.r
	movem.l	(sp)+,d3-d7/a3-a5
	rts
.mask:	move.w	d1,d2			; one group: (a1) := (a1) & ~m | (a0) & m
	not.w	d2
	rept	4
	move.w	(a0)+,d3
	and.w	d1,d3
	and.w	d2,(a1)
	or.w	d3,(a1)+
	endr
	rts

; addship / subship (crewgen.pas 476): step through the 27 combinations
addship:
	moveq	#1,d0
	bra.s	stepship
subship:
	moveq	#-1,d0
stepship:
	lea	GS_SHIP+SHIP_SHIPTYPE(a6),a0
	moveq	#0,d1			; i:=(h-1)*9+(p-1)*3+v-1
	move.b	(a0),d1
	subq.w	#1,d1
	mulu	#9,d1
	moveq	#0,d2
	move.b	1(a0),d2
	subq.w	#1,d2
	mulu	#3,d2
	add.w	d2,d1
	moveq	#0,d2
	move.b	2(a0),d2
	add.w	d2,d1
	subq.w	#1,d1
	add.w	d0,d1
	bpl.s	.lo
	moveq	#26,d1
.lo:	cmp.w	#26,d1
	ble.s	.hi
	moveq	#0,d1
.hi:	ext.l	d1
	divu	#9,d1			; h:=1+i div 9 ...
	move.b	d1,(a0)
	addq.b	#1,(a0)
	swap	d1
	ext.l	d1
	divu	#3,d1
	move.b	d1,1(a0)
	addq.b	#1,1(a0)
	swap	d1
	addq.b	#1,d1
	move.b	d1,2(a0)
	bsr	drawship
	bsr	kbd_cursor_hide
	bsr	displayship2
	bra	kbd_cursor_show

; ---------------------------------------------------------------
; addcursor / subcursor (crewgen.pas 514)
addcursor:
	tst.w	inputlevel
	beq	addship
	movem.l	d3-d4,-(sp)
	bsr	jobbit			; d3 = 1 shl (7-inputlevel)
.rep:	addq.w	#1,crewnum
.w:	cmp.w	#31,crewnum		; while (crewnum<31) and (job and bit = 0) do inc
	bge.s	.wd
	bsr	jobof
	and.w	d3,d0
	bne.s	.wd
	addq.w	#1,crewnum
	bra.s	.w
.wd:	bsr	isfree			; d4 = found
	cmp.w	#31,crewnum
	bne.s	.until
	move.w	#1,crewnum
.w2:	cmp.w	#31,crewnum
	bge.s	.wd2
	bsr	jobof
	and.w	d3,d0
	bne.s	.wd2
	addq.w	#1,crewnum
	bra.s	.w2
.wd2:	bsr	isfree
.until:	tst.w	d4
	beq.s	.rep
	movem.l	(sp)+,d3-d4
	bra	drawcrew

subcursor:
	tst.w	inputlevel
	beq	subship
	movem.l	d3-d4,-(sp)
	bsr	jobbit
.rep:	subq.w	#1,crewnum
.w:	tst.w	crewnum			; while (crewnum>0) and (job and bit = 0) do dec
	ble.s	.wd
	bsr	jobof
	and.w	d3,d0
	bne.s	.wd
	subq.w	#1,crewnum
	bra.s	.w
.wd:	bsr	isfree
	tst.w	crewnum
	bgt.s	.until
	move.w	#30,crewnum
.w2:	tst.w	crewnum
	ble.s	.wd2
	bsr	jobof
	and.w	d3,d0
	bne.s	.wd2
	subq.w	#1,crewnum
	bra.s	.w2
.wd2:	bsr	isfree
.until:	tst.w	d4
	beq.s	.rep
	movem.l	(sp)+,d3-d4
	bra	drawcrew

jobbit:					; d3.w = 1 shl (7-inputlevel)
	moveq	#7,d0
	sub.w	inputlevel,d0
	moveq	#0,d3
	bset	d0,d3
	rts
jobof:					; d0.w = crewdata^[crewnum].jobtype   a0 = record
	move.w	crewnum,d0
	subq.w	#1,d0
	mulu	#CREWREC,d0
	move.l	crewdata,a0
	add.l	d0,a0
	move.w	CREWDATA_JOBTYPE(a0),d0
	rts
isfree:					; d4.w = 1 unless ship.crew[1..inputlevel].index = crewnum
	moveq	#1,d4
	lea	GS_SHIP+SHIP_CREW+CREW_INDEX(a6),a0
	move.w	inputlevel,d1
	subq.w	#1,d1
	bmi.s	.x
.l:	moveq	#0,d0
	move.b	(a0),d0
	cmp.w	crewnum,d0
	bne.s	.n
	moveq	#0,d4
.n:	lea	CREW_SIZEOF(a0),a0
	dbf	d1,.l
.x:	rts

; drawcrew (crewgen.pas 352)
drawcrew:
	movem.l	d3-d5/a3-a4,-(sp)
	bsr	kbd_cursor_hide
	bsr	jobof
	move.l	a0,a3			; crewdata^[crewnum]
	bsr	crewslot		; a4 = ship.crew[inputlevel]
	move.b	crewnum+1,CREW_INDEX(a4)
	moveq	#0,d0			; name := (copies length+1 bytes, like FPC)
	move.b	(a3),d0
.nm:	move.b	0(a3,d0.w),0(a4,d0.w)
	dbf	d0,.nm
	move.b	CREWDATA_PHY+1(a3),CREW_PHY(a4)
	move.b	CREWDATA_MEN+1(a3),CREW_MEN(a4)
	move.b	CREWDATA_EMO+1(a3),CREW_EMO(a4)
	move.b	CREWDATA_LEVEL+1(a3),CREW_LEVEL(a4)
	move.w	#191,GS_TCOLOR(a6)
	clr.w	GS_BKCOLOR(a6)
	bsr	crewtext
	move.w	inputlevel,d0
	bsr	drawstats
	move.w	crewnum,d0
	bsr	showportrait
	bsr	kbd_cursor_show
	movem.l	(sp)+,d3-d5/a3-a4
	rts

crewslot:				; a4 = ship.crew[inputlevel]
	move.w	inputlevel,d0
	subq.w	#1,d0
	mulu	#CREW_SIZEOF,d0
	lea	GS_SHIP+SHIP_CREW(a6),a4
	add.w	d0,a4
	rts

crewtext:				; name at 0,120 and the ten description lines (a3 = record)
	movem.l	d3/a3,-(sp)
	move.w	GS_BKCOLOR(a6),panel_bk
	moveq	#0,d0
	moveq	#120,d1
	move.l	a3,a0
	bsr	txt_fast
	lea	CREWDATA_DESC(a3),a3
	moveq	#0,d3
.d:	moveq	#0,d0
	move.w	d3,d1
	mulu	#6,d1
	add.w	#130,d1
	move.l	a3,a0
	bsr	txt_fast
	lea	DESC_LEN(a3),a3
	addq.w	#1,d3
	cmp.w	#10,d3
	bne.s	.d
	movem.l	(sp)+,d3/a3
	rts

; drawstats (crewgen.pas 198): d0.w = crew slot. Keeps the line ends for redraws.
drawstats:
	movem.l	d3-d7/a3,-(sp)
	subq.w	#1,d0
	mulu	#CREW_SIZEOF,d0
	lea	GS_SHIP+SHIP_CREW(a6),a0
	add.w	d0,a0
	moveq	#0,d5
	move.b	CREW_PHY(a0),d5		; a
	moveq	#0,d6
	move.b	CREW_MEN(a0),d6		; b
	moveq	#0,d7
	move.b	CREW_EMO(a0),d7		; c
	bsr	graph_clear
	lea	graph_ys,a3
	move.w	#121,d3			; j
.j:	addq.w	#2,d3			; inc(j,2); if j>295 then exit
	cmp.w	#295,d3
	bgt.s	.x
	moveq	#6,d0
	bsr	mt_random
	move.w	d0,d1
	cmp.w	#3,d1
	blt.s	.v
	subq.w	#3,d1
.v:	move.w	d5,d2			; a, b or c
	tst.w	d1
	beq.s	.r
	move.w	d6,d2
	cmp.w	#1,d1
	beq.s	.r
	move.w	d7,d2
.r:	mulu	#36,d2			; round(v*36/100) (no ties)
	add.w	#50,d2
	ext.l	d2
	divu	#100,d2
	cmp.w	#3,d0
	blt.s	.pos
	neg.w	d2
.pos:	add.w	#51,d2
	move.w	d2,(a3)+
	move.w	d3,d0
	move.w	d2,d1
	bsr	graph_line
	addq.w	#1,d3			; (the for loop's own step)
	bra.s	.j
.x:	move.l	a3,d0
	sub.l	#graph_ys,d0
	lsr.w	#1,d0
	move.w	d0,graph_n
	movem.l	(sp)+,d3-d7/a3
	rts

graph_clear:				; clear 121-295 x 14-88, pen to 121,50
	move.l	d4,-(sp)
	move.l	d3,-(sp)
	moveq	#121,d0
	moveq	#14,d1
	move.w	#295,d2
	moveq	#88,d3
	moveq	#0,d4
	bsr	gfx_bar
	move.w	#121,gfx_pen
	move.w	#50,gfx_pen+2
	move.l	(sp)+,d3
	move.l	(sp)+,d4
	rts

graph_line:				; lineto(d0 = j, d1 = y) in colour (j-16) mod 32 + 128
	move.l	d4,-(sp)
	move.w	d0,d4
	sub.w	#16,d4
	and.w	#31,d4
	add.w	#128,d4
	bsr	gfx_lineto
	move.l	(sp)+,d4
	rts

graph_redraw:
	movem.l	d3/a3,-(sp)
	bsr	graph_clear
	lea	graph_ys,a3
	move.w	graph_n,d3
	beq.s	.x
	subq.w	#1,d3
	move.w	#123,d0
.l:	move.w	d0,-(sp)
	move.w	(a3)+,d1
	bsr	graph_line
	move.w	(sp)+,d0
	addq.w	#3,d0
	dbf	d3,.l
.x:	movem.l	(sp)+,d3/a3
	rts

; showportrait (crewgen.pas 177): d0.w = crew 1-30, even rows then odd rows
showportrait:
	movem.l	d3-d4/a3,-(sp)
	move.w	d0,port_shown
	bsr	orc_dump		; loadscreen(image??)
	move.w	port_shown,d0
	bsr	portrait_ptr
	move.l	a0,a3
	moveq	#0,d4			; 0: even rows, 1: odd rows
.pass:	moveq	#0,d3
.r:	move.w	d3,d1
	add.w	d1,d1
	add.w	d4,d1			; row
	move.w	d1,d0
	mulu	#70,d0
	lea	0(a3,d0.l),a0
	addq.w	#7,d1
	moveq	#13,d0
	moveq	#70,d2
	bsr	gfx_chunky_span
	move.w	GS_TSLICE(a6),d0	; delay(tslice div 7)
	ext.l	d0
	divu	#7,d0
	bsr	tim_delay
	addq.w	#1,d3
	cmp.w	#35,d3
	bne.s	.r
	addq.w	#1,d4
	cmp.w	#2,d4
	bne.s	.pass
	movem.l	(sp)+,d3-d4/a3
	rts

portrait_ptr:				; d0.w = crew 1-32 -> a0
	subq.w	#1,d0
	mulu	#PORT_SIZE,d0
	move.l	cgd,a0
	add.l	#CGD_PORT,a0
	add.l	d0,a0
	rts

portrait_full:				; the current portrait at once (redraws)
	movem.l	d3/a3,-(sp)
	move.w	port_shown,d0
	beq.s	.x
	bsr	portrait_ptr
	move.l	a0,a3
	moveq	#0,d3
.r:	move.l	a3,a0
	moveq	#13,d0
	moveq	#7,d1
	add.w	d3,d1
	moveq	#70,d2
	bsr	gfx_chunky_span
	lea	70(a3),a3
	addq.w	#1,d3
	cmp.w	#70,d3
	bne.s	.r
.x:	movem.l	(sp)+,d3/a3
	rts

; ---------------------------------------------------------------
cleartext:				; clear 4-263 x 120-196
	movem.l	d3-d4,-(sp)
	moveq	#4,d0
	moveq	#120,d1
	move.w	#263,d2
	move.w	#196,d3
	moveq	#0,d4
	bsr	gfx_bar
	movem.l	(sp)+,d3-d4
	rts

; addlevel (crewgen.pas 584)
addlevel:
	bsr	lowerball
	bsr	kbd_cursor_hide
	bsr	cleartext
	tst.w	inputlevel
	bne.s	.n0
	moveq	#CG_CREW,d0		; (ST) level 0 -> 1: the crew screen's colours
	bsr	setmode
	moveq	#30,d0
	bsr	drawball
	bsr	showtitle		; (as it was: Ship Selection)
	bsr	kbd_cursor_hide
.n0:	bsr	kbd_cursor_show
	addq.w	#1,inputlevel
	cmp.w	#7,inputlevel
	beq	savedata
	clr.w	crewnum
	bsr	addcursor
	bsr	showtitle
	bra	raiseball

; sublevel (crewgen.pas 603)
sublevel:
	move.w	inputlevel,d0
	bne.s	.n0
	move.w	#1,quit
	rts
.n0:	cmp.w	#1,d0
	bne.s	.n1
	bsr	lowerball
	bsr	kbd_cursor_hide
	moveq	#CG_SHIP,d0		; (ST) back to the ship screen's colours: the portrait
	bsr	setmode			; stays until the bird returns, row by row
	bsr	portrait_full
	bsr	graph_redraw		; (and the graph until the ship covers it)
	moveq	#30,d0
	bsr	drawball
	bsr	showtitle
	bsr	kbd_cursor_hide
	bsr	bird_rows
	bsr	cleartext
	bsr	kbd_cursor_show
	clr.w	inputlevel
	clr.w	port_shown
	clr.w	graph_n
	bsr	raiseball
	bra.s	.cur
.n1:	bsr	lowerball
	bsr	kbd_cursor_hide
	bsr	cleartext
	bsr	kbd_cursor_show
	subq.w	#1,inputlevel
	bsr	raiseball
.cur:	move.w	#31,crewnum
	bsr	subcursor
	bra	showtitle

bird_rows:				; birdpic back, even rows then odd rows (from the background)
	movem.l	d3-d4,-(sp)
	moveq	#0,d4
.pass:	moveq	#0,d3
.r:	bsr	mode_bg
	move.w	d3,d1
	add.w	d1,d1
	add.w	d4,d1
	addq.w	#7,d1
	move.w	d1,-(sp)
	moveq	#13,d0
	moveq	#82,d2
	move.w	(sp)+,d1
	move.l	d3,-(sp)
	move.w	d1,d3
	bsr	gfx_copy_rect
	move.l	(sp)+,d3
	move.w	GS_TSLICE(a6),d0
	ext.l	d0
	divu	#7,d0
	bsr	tim_delay
	addq.w	#1,d3
	cmp.w	#35,d3
	bne.s	.r
	addq.w	#1,d4
	cmp.w	#2,d4
	bne.s	.pass
	movem.l	(sp)+,d3-d4
	rts

; ---------------------------------------------------------------
; getxp (crewgen.pas 251): d0.w = level -> d0.l
getxp:
	add.w	d0,d0
	add.w	d0,d0
	lea	tab_xp,a0
	move.l	0(a0,d0.w),-(sp)
	move.w	#500,d0
	bsr	mt_random
	add.l	(sp)+,d0
	rts

; savedata (crewgen.pas 268)
savedata:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	GS_SHIP(a6),a3
	lea	shipdata,a4
	move.w	SD_FUEL(a4),SHIP_FUELMAX(a3)
	moveq	#20,d0
	bsr	mt_random
	add.w	#100,d0
	move.w	d0,SHIP_FUEL(a3)
	move.w	SD_GUNS(a4),SHIP_GUNMAX(a3)
	move.w	SD_ACCEL(a4),SHIP_ACCELMAX(a3)
	clr.w	SHIP_BATTERY(a3)
	move.w	SD_HULL(a4),d0
	move.w	d0,SHIP_HULLMAX(a3)
	move.w	SD_CARGO(a4),d1
	mulu	#10,d1
	move.w	d1,SHIP_CARGOMAX(a3)
	mulu	#9,d0			; round(hullmax*0.9): hullmax is a multiple of 10
	divu	#10,d0
	move.w	d0,SHIP_HULLINTEGRITY(a3)
	lea	SHIP_CREW(a3),a4
	lea	SHIP_ENCODES(a3),a5
	moveq	#6-1,d7
.cr:	moveq	#0,d0
	move.b	CREW_LEVEL(a4),d0
	bsr	getxp
	move.l	d0,CREW_XP(a4)
	moveq	#0,d3
	move.b	CREW_PHY(a4),d3
	moveq	#0,d4
	move.b	CREW_MEN(a4),d4
	moveq	#0,d5
	move.b	CREW_EMO(a4),d5
	move.w	d4,d0			; perf:=round(men*0.6+phy*0.4-emo*0.2)
	move.w	d3,d1
	move.w	d5,d2
	bsr	.mix
	move.b	d0,CREW_PERF(a4)
	move.w	d3,d0			; skill:=round(phy*0.6+emo*0.4-men*0.2)
	move.w	d5,d1
	move.w	d4,d2
	bsr	.mix
	move.b	d0,CREW_SKILL(a4)
	move.w	d5,d0			; san:=round(emo*0.6+men*0.4-phy*0.2)
	move.w	d4,d1
	move.w	d3,d2
	bsr	.mix
	move.b	d0,CREW_SAN(a4)
	moveq	#CREW_SIZEOF/2-1,d0	; encodes[j]:=crew[j]
.cp:	move.w	(a4)+,(a5)+
	dbf	d0,.cp
	dbf	d7,.cr
	lea	fn_tempdir,a0		; tmp contacts.dta, empty
	bsr	fil_mkdir
	lea	fn_tmpcon,a0
	lea	strbuf,a1
	moveq	#0,d0
	bsr	fil_save
	; savegamedata(160,191) over the crew screen
	bsr	kbd_cursor_hide
	moveq	#CG_SAVE,d0
	bsr	setmode
	bsr	redraw_crew
	bsr	kbd_cursor_show
	move.w	#160,d0
	move.w	#191,d1
	bsr	sl_savegamedata
	move.w	d0,d7
	bsr	kbd_cursor_hide		; the original put back what was under the dialog
	moveq	#CG_CREW,d0
	bsr	setmode
	bsr	redraw_crew
	bsr	kbd_cursor_show
	tst.w	d7
	bne.s	.saved
	movem.l	(sp)+,d3-d7/a3-a5
	bra	sublevel
.saved:	move.w	#1,quit
	move.w	GS_CURFILENUM(a6),d0	; code:=curfilenum+48
	add.w	#48,d0
	move.w	d0,exitcode
	move.w	GS_CURFILENUM(a6),d0	; PLANETS.DTA
	lea	fn_planets,a1
	move.l	planets,a2
	move.l	#PLANARRAY_SIZEOF,d1
	bsr	sl_write
	move.w	GS_CURFILENUM(a6),d0	; CONTACTS.DTA (empty)
	lea	fn_contacts,a1
	lea	strbuf,a2
	moveq	#0,d1
	bsr	sl_write
	lea	GS_EVENTS(a6),a0	; events := 0; logpending[].log := -1; logs := -1
	move.w	#EVENTARRAY_SIZEOF/4-1,d0
.ev:	clr.l	(a0)+
	dbf	d0,.ev
	lea	GS_LOGPENDING+LOGPENDING_LOG(a6),a0
	moveq	#128-1,d0
.lp:	move.w	#-1,(a0)
	addq.l	#LOGPENDING_SIZEOF,a0
	dbf	d0,.lp
	lea	GS_LOGS(a6),a0
	move.w	#256-1,d0
.lg:	move.w	#-1,(a0)+
	dbf	d0,.lg
	lea	save_more,a3
.f:	move.w	(a3)+,d0
	bmi.s	.x
	lea	0(a6,d0.w),a2
	moveq	#0,d1
	move.w	(a3)+,d1
	move.l	(a3)+,a1
	move.w	GS_CURFILENUM(a6),d0
	bsr	sl_write
	bra.s	.f
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts
; round((6*d0 + 4*d1 - 2*d2) / 10)
.mix:	mulu	#6,d0
	lsl.w	#2,d1
	add.w	d1,d0
	add.w	d2,d2
	sub.w	d2,d0
	ext.l	d0
	bra	pas_rnd10

; the crew screen's contents (after a mode switch): ball, title, portrait, graph
redraw_crew:
	move.w	ballframe,d0
	bsr	drawball
	move.w	inputlevel,d0
	cmp.w	#6,d0
	ble.s	.t
	moveq	#6,d0
.t:	move.w	GS_BKCOLOR(a6),-(sp)
	move.w	title_bk,GS_BKCOLOR(a6)
	bsr	print_title
	move.w	(sp)+,GS_BKCOLOR(a6)
	bsr	portrait_full
	bra	graph_redraw

; ---------------------------------------------------------------
; mainloop (crewgen.pas 692): colours 128-159 cycle; mouse and keys
mainloop:
	movem.l	d3-d5,-(sp)
	moveq	#0,d5			; i2
	bsr	calculateship
.loop:	subq.w	#1,d5
	bgt.s	.i2
	moveq	#31,d5
.i2:	move.w	d5,d3			; i
	lea	GS_COLORS+128*3(a6),a0
	moveq	#32-1,d4
.j:	addq.w	#1,d3
	cmp.w	#31,d3
	ble.s	.c
	moveq	#0,d3
.c:	move.w	d3,d0			; colors[j+128]:=colors[i*2+64]
	mulu	#6,d0
	lea	GS_COLORS+64*3(a6),a1
	add.w	d0,a1
	move.b	(a1)+,(a0)+
	move.b	(a1)+,(a0)+
	move.b	(a1)+,(a0)+
	dbf	d4,.j
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	move.w	GS_TSLICE(a6),d0	; delay(tslice*3)
	mulu	#3,d0
	bsr	tim_delay
	bsr	findmouse
	bsr	kbd_keypressed
	tst.b	d0
	beq.s	.nk
	bsr	processkey
.nk:	tst.w	quit
	beq.s	.loop
	movem.l	(sp)+,d3-d5
	rts

findmouse:
	bsr	kbd_mouse_status
	tst.b	d0
	beq	.x
	bsr	kbd_mouse_xy
	cmp.w	#132,d1
	blo.s	.t
	cmp.w	#138,d1
	bhi.s	.s
	cmp.w	#279,d0
	bls.s	.x
	cmp.w	#311,d0
	bhs.s	.x
	bra	addlevel
.s:	cmp.w	#140,d1
	blo.s	.x
	cmp.w	#146,d1
	bhi.s	.u
	cmp.w	#279,d0
	bls.s	.x
	cmp.w	#311,d0
	bhs.s	.x
	bra	sublevel
.u:	cmp.w	#150,d1
	blo.s	.x
	cmp.w	#160,d1
	bhi.s	.d
	cmp.w	#281,d0
	bls.s	.x
	cmp.w	#296,d0
	bhs.s	.x
	bra	subcursor
.d:	cmp.w	#162,d1
	blo.s	.x
	cmp.w	#172,d1
	bhi.s	.x
	cmp.w	#281,d0
	bls.s	.x
	cmp.w	#296,d0
	bhs.s	.x
	bra	addcursor
.t:	cmp.w	#107,d1
	blo.s	.x
	cmp.w	#112,d1
	bhi.s	.x
	cmp.w	#246,d0
	bls.s	.x
	cmp.w	#254,d0
	bhs.s	.x
	bra	toggleswitch
.x:	rts

processkey:
	bsr	kbd_readkey
	tst.b	d0
	bne.s	.asc
	bsr	kbd_readkey
	cmp.b	#59,d0			; F1 / Alt-Q
	beq.s	.quit
	cmp.b	#16,d0
	beq.s	.quit
	cmp.b	#80,d0
	beq	addcursor
	cmp.b	#72,d0
	beq	subcursor
	cmp.b	#84,d0			; Shift-F1
	bne.s	.x
	tst.w	toggle
	bne	easteregg1
	rts
.quit:	move.w	#1,quit
	rts
.asc:	cmp.b	#13,d0
	beq	addlevel
	cmp.b	#27,d0
	beq	sublevel
.x:	rts

; ---------------------------------------------------------------
; easteregg1 (crewgen.pas 62)
easteregg1:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	kbd_cursor_hide
	move.w	cg_mode,egg_mode
	lea	GS_COLORS(a6),a0	; compressfile(current): the palette is all we need back
	lea	egg_pal,a1
	move.w	#768/4-1,d0
.sv:	move.l	(a0)+,(a1)+
	dbf	d0,.sv
	move.w	#5,GS_BKCOLOR(a6)
	moveq	#16,d0			; fading
	moveq	#0,d1
	move.w	#47*5,d2
	bsr	vid_fade_ms
	move.l	cgd,a0			; loadpal(main.pal)
	lea	CGD_PALMAIN(a0),a0
	lea	GS_COLORS(a6),a1
	move.w	#768/4-1,d0
.mp:	move.l	(a0)+,(a1)+
	dbf	d0,.mp
	move.l	#320*200,d0		; the noise: 64000 x random(16) (pre-rendered; the
	bsr	mt_skip			; generator advances as the original's did)
	moveq	#CG_EGG,d0		; (the noise and graybutton(5,23,315,165) are the
	bsr	setmode			; mode's background)
	lea	egg_win,a0		; graybutton(80,158,240,172) in a chunky window: it fades
	moveq	#80,d0
	move.w	#158,d1
	move.w	#161,d2
	moveq	#15,d3
	bsr	chk_open
	moveq	#80,d0
	move.w	#158,d1
	move.w	#240,d2
	move.w	#172,d3
	moveq	#5,d4
	bsr	chk_bar
	moveq	#80,d0
	move.w	#172,d1
	move.w	#240,d2
	move.w	#172,d3
	moveq	#2,d4
	bsr	chk_bar
	moveq	#80,d0
	move.w	#158,d1
	move.w	#240,d2
	move.w	#158,d3
	moveq	#10,d4
	bsr	chk_bar
	move.w	#240,d0
	move.w	#158,d1
	move.w	#240,d2
	move.w	#172,d3
	moveq	#2,d4
	bsr	chk_bar
	moveq	#80,d0
	move.w	#158,d1
	moveq	#80,d2
	move.w	#172,d3
	moveq	#10,d4
	bsr	chk_bar
	move.w	#240,d0
	move.w	#158,d1
	moveq	#6,d2
	bsr	chk_pset
	moveq	#80,d0
	move.w	#172,d1
	moveq	#6,d2
	bsr	chk_pset
	move.w	#188,GS_TCOLOR(a6)
	moveq	#53,d0
	move.w	#142,d1
	lea	s_egg1,a0
	bsr	txt_fast
	move.w	#92,GS_TCOLOR(a6)
	moveq	#91,d0
	move.w	#162,d1
	lea	s_egg2,a0
	bsr	chk_print
	move.w	#158,d1
	move.w	#172,d2
	bsr	chk_show
	; the crew of every department
	moveq	#1,d6			; i
	moveq	#1,d7			; j
.dep:	cmp.w	#4,d7
	bne.s	.d1
	moveq	#1,d6
.d1:	move.w	#92,GS_TCOLOR(a6)
	moveq	#7,d0
	cmp.w	#4,d7
	blt.s	.d2
	move.w	#160,d0
.d2:	move.w	d0,d5			; x
	move.w	d6,d1
	mulu	#6,d1
	add.w	#20,d1
	move.w	d7,d2
	mulu	#12,d2
	lea	crewtitles,a0
	add.w	d2,a0
	bsr	txt_fast
	move.w	#22,GS_TCOLOR(a6)
	addq.w	#1,d6
	moveq	#7,d4			; bit 7-j
	sub.w	d7,d4
	move.l	crewdata,a3
	moveq	#30-1,d3
.k:	move.w	CREWDATA_JOBTYPE(a3),d0
	btst	d4,d0
	beq	.nk
	move.w	d6,d1			; y = 20 + i*6
	mulu	#6,d1
	add.w	#20,d1
	move.w	d1,-(sp)
	move.w	d5,d0
	addq.w	#6,d0
	move.l	a3,a0
	bsr	txt_fast
	lea	strbuf,a0		; str(phy)+'/'+str(men)+'/'+str(emo)
	move.w	CREWDATA_PHY(a3),d0
	ext.l	d0
	moveq	#0,d1
	bsr	int_str
	lea	strbuf,a0
	lea	s_slash,a1
	bsr	pstr_cat
	lea	strbuf2,a0
	move.w	CREWDATA_MEN(a3),d0
	ext.l	d0
	moveq	#0,d1
	bsr	int_str
	lea	strbuf,a0
	lea	strbuf2,a1
	bsr	pstr_cat
	lea	strbuf,a0
	lea	s_slash,a1
	bsr	pstr_cat
	lea	strbuf2,a0
	move.w	CREWDATA_EMO(a3),d0
	ext.l	d0
	moveq	#0,d1
	bsr	int_str
	lea	strbuf,a0
	lea	strbuf2,a1
	bsr	pstr_cat
	move.w	(sp)+,d1
	move.w	d5,d0
	add.w	#101,d0
	lea	strbuf,a0
	bsr	txt_fast
	addq.w	#1,d6
.nk:	lea	CREWREC(a3),a3
	dbf	d3,.k
	addq.w	#1,d7
	cmp.w	#6,d7
	ble	.dep
	bsr	kbd_cursor_show
	moveq	#0,d6			; c
	moveq	#16,d0			; set256colors(colors)
	bsr	vid_set_fade
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
.loop:	move.w	#200,d3			; 200-215 from colors[random(22)], 216-231 black
	moveq	#22,d4
	bsr	egg_flicker
	move.w	GS_TSLICE(a6),d0
	lsr.w	#1,d0
	bsr	tim_delay
	bsr	kbd_mouse_status
	move.b	d0,d7			; done
	bsr	kbd_mouse_xy
	tst.w	d6
	bne.s	.c1
	cmp.w	#145+12,d1		; (c=0) and (y>157) and (y<173) and (x>79) and (x<241)
	bls.s	.ck
	cmp.w	#161+12,d1
	bhs.s	.ck
	cmp.w	#79,d0
	bls.s	.ck
	cmp.w	#241,d0
	bhs.s	.ck
	moveq	#1,d6
	moveq	#3,d4
	bsr	egg_fade
	bra.s	.ck
.c1:	cmp.w	#146+12,d1		; (c=1) and outside
	blo.s	.out
	cmp.w	#160+12,d1
	bhi.s	.out
	cmp.w	#80,d0
	blo.s	.out
	cmp.w	#240,d0
	bls.s	.ck
.out:	moveq	#0,d6
	moveq	#-3,d4
	bsr	egg_fade
.ck:	bsr	kbd_keypressed
	tst.b	d0
	beq.s	.nk2
	bsr	kbd_readkey
.nk2:	move.w	#216,d3			; 216-231 from colors[random(16)], 200-215 black
	moveq	#16,d4
	bsr	egg_flicker
	move.w	GS_TSLICE(a6),d0
	lsr.w	#1,d0
	addq.w	#5,d0
	bsr	tim_delay
	tst.b	d7
	beq	.loop
	tst.w	d6
	beq	.loop
	; loadscreen(current): palette and picture back
	bsr	kbd_cursor_hide
	lea	egg_pal,a0
	lea	GS_COLORS(a6),a1
	move.w	#768/4-1,d0
.rp:	move.l	(a0)+,(a1)+
	dbf	d0,.rp
	bsr	orc_dump
	move.w	egg_mode,d0
	bsr	setmode
	bsr	redraw_all
	move.w	#3,GS_BKCOLOR(a6)
	move.w	#191,GS_TCOLOR(a6)
	bsr	kbd_cursor_show
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; d3.w = first index of the flickering half (200 or 216), d4.w = random range
egg_flicker:
	movem.l	d5/a3,-(sp)
	lea	GS_COLORS+200*3(a6),a3
	cmp.w	#200,d3
	beq.s	.a
	moveq	#16-1,d5		; 200-215 black (colors[0]) first
.k0:	move.b	GS_COLORS(a6),(a3)+
	move.b	GS_COLORS+1(a6),(a3)+
	move.b	GS_COLORS+2(a6),(a3)+
	dbf	d5,.k0
.a:	moveq	#16-1,d5
.r:	move.w	d4,d0
	bsr	mt_random
	mulu	#3,d0
	lea	GS_COLORS(a6,d0.w),a0
	move.b	(a0)+,(a3)+
	move.b	(a0)+,(a3)+
	move.b	(a0)+,(a3)+
	dbf	d5,.r
	cmp.w	#200,d3
	bne.s	.set
	moveq	#16-1,d5		; then 216-231 black
.k1:	move.b	GS_COLORS(a6),(a3)+
	move.b	GS_COLORS+1(a6),(a3)+
	move.b	GS_COLORS+2(a6),(a3)+
	dbf	d5,.k1
.set:	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	movem.l	(sp)+,d5/a3
	rts

egg_fade:				; plainfadearea(80,158,240,172,d4)
	movem.l	d3-d4,-(sp)
	bsr	kbd_cursor_hide
	moveq	#80,d0
	move.w	#158,d1
	move.w	#240,d2
	move.w	#172,d3
	bsr	chk_fade
	move.w	#158,d1
	move.w	#172,d2
	bsr	chk_show
	bsr	kbd_cursor_show
	movem.l	(sp)+,d3-d4
	rts

; everything on the screen in the main loop, after the easter egg
redraw_all:
	movem.l	d3/a3,-(sp)
	move.w	GS_BKCOLOR(a6),-(sp)
	move.w	ballframe,d0
	bsr	drawball
	move.w	title_bk,GS_BKCOLOR(a6)
	move.w	inputlevel,d0
	bsr	print_title
	move.w	panel_bk,GS_BKCOLOR(a6)
	tst.w	inputlevel
	bne.s	.crew
	bsr	drawship
	bsr	kbd_cursor_hide
	bsr	displayship2
	bra.s	.x
.crew:	bsr	jobof
	move.l	a0,a3
	bsr	crewtext
	bsr	graph_redraw
	bsr	portrait_full
.x:	move.w	(sp)+,GS_BKCOLOR(a6)
	movem.l	(sp)+,d3/a3
	rts

	include	"kernel.s"
	include	"gutil.s"
	include	"saveload.s"

; ---------------------------------------------------------------
	section	data
fn_script:	dc.b	"INPUT.CG",0
arg_seed:	dc.b	"/MAKESEED",0
fn_cgm:		dc.b	"DATA",92,"CGMODES.DAT",0
fn_cgd:		dc.b	"DATA",92,"CGDATA.DAT",0
fn_cga:		dc.b	"DATA",92,"CGANI.DAT",0
fn_cgs:		dc.b	"DATA",92,"CGSHIP.DAT",0
fn_crew:	dc.b	"DATA",92,"CREW.DTA",0
fn_sysset:	dc.b	"DATA",92,"SYSSET.DTA",0
fn_mod:		dc.b	"SOUND",92,"CHARGEN.MOD",0
fn_tempdir:	dc.b	"TEMP",0
fn_tmpcon:	dc.b	"TEMP",92,"CONTACTS.DTA",0
fn_planets:	dc.b	"PLANETS.DTA",0
fn_contacts:	dc.b	"CONTACTS.DTA",0
msg_fatal:	dc.b	"CREWGEN: a data file is missing or damaged.",13,10,0
s_unknown:	dc.b	12,"UNKNOWN     "
s_oban:		dc.b	12,"OBAN        "
s_shipsel:	dc.b	14,"Ship Selection"
s_crewsel:	dc.b	14,"Crew Selection"
s_space:	dc.b	1," "
s_slash:	dc.b	1,"/"
s_egg1:		dc.b	41,"Welcome to the Channel 7 Easter Egg Hunt!"
s_egg2:		dc.b	26,"DON'T TOUCH THIS BUTTON!!!"
s_guns:		dc.b	16,"Gun Emplacements"
s_fuel:		dc.b	12,"Maximum Fuel"
s_cargo:	dc.b	14,"Cargo Capacity"
s_mass:		dc.b	9,"Ship Mass"
s_accel:	dc.b	16,"Max Acceleration"
s_hull:		dc.b	19,"Maximum Hull Points"
s_none:		dc.b	0
s_kg:		dc.b	3," Kg"
s_units:	dc.b	6," Units"
s_mt:		dc.b	3," Mt"
s_mss:		dc.b	8," M/S Sqr"
s_pts:		dc.b	4," Pts"
	even
leveltitles:				; 12 bytes each (string[11])
	dc.b	11,"           "
	dc.b	11,"Psychometry"
	dc.b	11,"Engineering"
	dc.b	11,"  Science  "
	dc.b	11," Security  "
	dc.b	11,"Navigation "
	dc.b	11,"  Medical  "
crewtitles:				; data.pas crewtitles (string[11])
	dc.b	8,"COMPUTER   "
	dc.b	11,"PSYCHOMETRY"
	dc.b	11,"ENGINEERING"
	dc.b	7,"SCIENCE    "
	dc.b	8,"SECURITY   "
	dc.b	11,"ASTROGATION"
	dc.b	7,"MEDICAL    "
shipnames:				; data.pas shipnames (string[9])
	dc.b	5,"Heavy    "
	dc.b	5,"Light    "
	dc.b	9,"Strategic"
	dc.b	7,"Shuttle  "
	dc.b	7,"Assault  "
	dc.b	5,"Storm    "
	dc.b	9,"Transport"
	dc.b	7,"Frigate  "
	dc.b	7,"Cruiser  "
	even
init_damages:	dc.b	25,15,2,3,16,55,22
init_options:	dc.b	1,20,1,1,2,1,0,1,64,0
	even
SD_GUNS		equ	0
SD_CARGO	equ	2
SD_FUEL		equ	4
SD_MASS		equ	6
SD_ACCEL	equ	8
SD_HULL		equ	10
tab_heavy:	dc.w	2,334,200,200		; guns, mass, maxfuel, hullmax
		dc.w	1,334,250,150		; (+50 cargo)
		dc.w	3,501,200,100
tab_purpose:	dc.w	3,501,350,50,700	; guns, mass, fuel, cargo, hull
		dc.w	4,668,300,100,600
		dc.w	5,835,300,50,600
tab_vessel:	dc.w	0,0,100,100		; guns, mass, cargo, hull
		dc.w	1,167,50,100
		dc.w	2,330,50,0
tab_xp:		dc.l	0,1000,3000,4000,7000,11000,18000,0,0,0
shiplines:	; y, label x, label, value offset, width, suffix, value x
		dc.w	132,20
		dc.l	s_guns
		dc.w	SD_GUNS,2
		dc.l	s_none
		dc.w	230
		dc.w	143,30
		dc.l	s_fuel
		dc.w	SD_FUEL,4
		dc.l	s_kg
		dc.w	205
		dc.w	154,25
		dc.l	s_cargo
		dc.w	SD_CARGO,4
		dc.l	s_units
		dc.w	190
		dc.w	165,35
		dc.l	s_mass
		dc.w	SD_MASS,4
		dc.l	s_mt
		dc.w	205
		dc.w	176,20
		dc.l	s_accel
		dc.w	SD_ACCEL,4
		dc.l	s_mss
		dc.w	180
		dc.w	187,15
		dc.l	s_hull
		dc.w	SD_HULL,4
		dc.l	s_pts
		dc.w	200
		dc.w	0
save_more:	dc.w	GS_EVENTS,EVENTARRAY_SIZEOF
		dc.l	fn_events
		dc.w	GS_LOGS,LOGARRAY_SIZEOF
		dc.l	fn_logs
		dc.w	GS_LOGPENDING,LOGPENDINGARRAY_SIZEOF
		dc.l	fn_pending
		dc.w	-1
fn_events:	dc.b	"EVENTS.DTA",0
fn_logs:	dc.b	"LOGS.DTA",0
fn_pending:	dc.b	"PENDING.DTA",0
	even
files:		dc.l	CGM_SIZE,cgm,fn_cgm
		dc.l	CGD_SIZE,cgd,fn_cgd
		dc.l	CREW_DTA_SIZE,crewdata,fn_crew
		dc.l	SYSSET_SIZE,oldsys,fn_sysset
		dc.l	CGA_SIZE,cga,fn_cga
		dc.l	CGS_SIZE,cgs,fn_cgs
		dc.l	PLANARRAY_SIZEOF,planets,0
		dc.l	0

	section	bss
cgm:		ds.l	1
cgd:		ds.l	1
cga:		ds.l	1
cgs:		ds.l	1
crewdata:	ds.l	1
oldsys:		ds.l	1
planets:	ds.l	1
exitcode:		ds.w	1
quit:		ds.w	1
toggle:		ds.w	1
inputlevel:	ds.w	1
crewnum:	ds.w	1
cg_mode:	ds.w	1
egg_mode:	ds.w	1
ballframe:	ds.w	1
port_shown:	ds.w	1
title_bk:	ds.w	1
panel_bk:	ds.w	1
graph_n:	ds.w	1
graph_ys:	ds.w	64
shipdata:	ds.w	6
radii:		ds.b	8
sw_row:		ds.b	8
strbuf:		ds.b	64
strbuf2:	ds.b	16
egg_pal:	ds.b	768
egg_win:	ds.b	161*15
	even
