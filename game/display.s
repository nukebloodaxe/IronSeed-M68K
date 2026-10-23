; display.s - display.pas for MAIN.PRG: the right-hand panels of the bridge (options, damage
; control, shields, weapons, system info, logs, the system view, ship info, configure, bots) and
; the viewscreen maps (star map, history map, short and long range scans). Line by line from the
; original into the chunky shadow (mscr.s); reals through fp.s exactly as FPC computes them.
; display.pas's unit variables are dp_*: a, b, i, j, index (index persists: the circle colours of
; the maps and the system view cycle through it, and the list displays use it as a loop variable).
; All routines: in d0.w = com where the original takes one; trash d0-d2/a0-a2.

NEARBYMAX_	equ	20

	section	text
; ---------------------------------------------------------------- small helpers
; a0 := cargo[d0.w].name (cargo[] is 1-based)            trashes d0
dp_cargoname:
	mulu	#CARGO_SIZEOF,d0
	lea	GS_CARGO-CARGO_SIZEOF+CARGO_NAME(a6),a0
	add.l	d0,a0
	rts
; a0 := @weapons[d0.w] (1-based)                          trashes d0
dp_weapon:
	mulu	#WEAPON_SIZEOF,d0
	lea	GS_WEAPONS-WEAPON_SIZEOF(a6),a0
	add.l	d0,a0
	rts
; scr_fillchar(screen[d1,d0], d2, d4.b) for d2 > 0         trashes d0-d2/a0-a2
dp_fill:
	tst.w	d2
	ble.s	.x
	move.l	d3,-(sp)
	add.w	d0,d2
	subq.w	#1,d2
	move.w	d1,d3
	bsr	ms_bar
	move.l	(sp)+,d3
.x:	rts
; the panel's body: for i := 37 to 114 do scr_fillchar(screen[i,166], 113, 5)
dp_clear:
	BAR	166,37,278,114,5
	rts
; a0 := @tempplan^[d0.w] (1-based)                        trashes d0
dp_plan:
	mulu	#PLANET_SIZEOF,d0
	move.l	GS_TEMPPLAN(a6),a0
	lea	-PLANET_SIZEOF(a0),a0
	add.l	d0,a0
	rts
; a0 := @systems[d0.w] (1-based)                          trashes d0
dp_sys:
	mulu	#SYSTEM_SIZEOF,d0
	lea	GS_SYSTEMS-SYSTEM_SIZEOF(a6),a0
	add.l	d0,a0
	rts
; a0 := @nearby[d0.w] (1-based)                           trashes d0
dp_near:
	mulu	#NEARBY_SIZEOF,d0
	lea	GS_NEARBY-NEARBY_SIZEOF(a6),a0
	add.l	d0,a0
	rts
; Pascal str(d0.l:d1.w) into dp_s (the unit's str1/s)        trashes d0-d2/a0-a1
dp_str:
	lea	dp_s,a0
	bra	int_str
; str(d0:2) with a leading '0' for one digit (the dates' months)
dp_str2z:
	ext.l	d0
	moveq	#2,d1
	bsr	dp_str
	cmp.b	#' ',dp_s+1
	bne.s	.x
	move.b	#'0',dp_s+1
.x:	rts

; ---------------------------------------------------------------- options (viewmode 6)
displayoptions:
	movem.l	d3/a3,-(sp)
	lea	GS_SHIP+SHIP_OPTIONS-1(a6),a3	; options[1..10]
	move.w	GS_VIEWINDEX(a6),d1
	cmp.w	#1,d0
	beq.s	.dec
	cmp.w	#6,d0
	beq.s	.dec
	cmp.w	#2,d0
	beq	.inc
	cmp.w	#7,d0
	beq	.inc
	cmp.w	#3,d0
	bne.s	.c4
	subq.w	#1,d1			; 3: up
	bne.s	.vi
	moveq	#9,d1
.vi:	move.w	d1,GS_VIEWINDEX(a6)
	bra	.draw
.c4:	cmp.w	#4,d0
	bne.s	.c5
	addq.w	#1,d1			; 4: down
	cmp.w	#10,d1
	bne.s	.vi
	moveq	#1,d1
	bra.s	.vi
.c5:	cmp.w	#5,d0
	bne	.draw
	st	d0
	bsr	removerightside
	bra	.x
.dec:	cmp.w	#2,d1			; 1, 6: left
	bne.s	.d3
	cmp.b	#1,OPT_TIMESLICE(a3)
	bls.s	.ts
	subq.b	#1,OPT_TIMESLICE(a3)
.ts:	moveq	#0,d0
	move.b	OPT_TIMESLICE(a3),d0
	move.w	d0,GS_TSLICE(a6)
	bra	.draw
.d3:	cmp.w	#3,d1
	bne.s	.d9
	clr.b	OPT_SOUND(a3)
	bsr	stopmod
	bra	.draw
.d9:	cmp.w	#9,d1
	bne.s	.d1
	cmp.b	#1,OPT_VOLUME(a3)
	bls.s	.dv
	subq.b	#1,OPT_VOLUME(a3)
.dv:	bsr	setmodvolume
	bra	.draw
.d1:	cmp.w	#1,d1			; row 1 is the probes option (OPT_PROBES)
	bne.s	.dd
	moveq	#OPT_PROBES,d1
.dd:	tst.b	0(a3,d1.w)
	beq	.draw
	subq.b	#1,0(a3,d1.w)
	bra	.draw
.inc:	cmp.w	#1,d1			; 2, 7: right
	bne.s	.i2
	moveq	#OPT_PROBES,d1		; row 1: the probes option, 0 -> 1 below
	bra	.ie
.i2:	cmp.w	#2,d1
	bne.s	.i4
	cmp.b	#250,OPT_TIMESLICE(a3)
	bhs.s	.ts
	addq.b	#1,OPT_TIMESLICE(a3)
	bra.s	.ts
.i4:	cmp.w	#4,d1
	bne.s	.i5
	cmp.b	#2,OPT_DIFFICULTY(a3)
	bhs	.draw
	addq.b	#1,OPT_DIFFICULTY(a3)
	bra	.draw
.i5:	cmp.w	#5,d1
	bne.s	.i7
	cmp.b	#2,OPT_MSGS(a3)
	bhs	.draw
	addq.b	#1,OPT_MSGS(a3)
	bra	.draw
.i7:	cmp.w	#7,d1
	bne.s	.i9
	cmp.b	#2,OPT_FONT_(a3)
	bhs	.draw
	addq.b	#1,OPT_FONT_(a3)
	bra	.draw
.i9:	cmp.w	#9,d1
	bne.s	.ie
	cmp.b	#64,OPT_VOLUME(a3)
	bhs	.dv
	addq.b	#1,OPT_VOLUME(a3)
	bra	.dv
.ie:	tst.b	0(a3,d1.w)		; else: 0 -> 1
	bne.s	.draw
	move.b	#1,0(a3,d1.w)
.draw:	TCOL	191
	bsr	mousehide
	BKSEL	GS_VIEWINDEX,1
	tst.b	OPT_PROBES(a3)		; (the original: the screen saver's Off/On)
	bne.s	.ss
	PXY	246,37," Std"
	bra.s	.o2
.ss:	PXY	246,37,"1994"
.o2:	BKSEL	GS_VIEWINDEX,2
	moveq	#0,d0
	move.b	OPT_TIMESLICE(a3),d0
	moveq	#3,d1
	bsr	dp_str
	PXYS	251,46,dp_s
	BKSEL	GS_VIEWINDEX,3
	cmp.b	#1,OPT_SOUND(a3)
	bne.s	.so
	PXY	251,55," On"
	bra.s	.o4
.so:	PXY	251,55,"Off"
.o4:	BKSEL	GS_VIEWINDEX,4
	move.b	OPT_DIFFICULTY(a3),d0	; (another value keeps the last s: never happens)
	lea	dp_diff,a1
	bsr	.pick
	PXYS	251,64,dp_s
	BKSEL	GS_VIEWINDEX,5
	move.b	OPT_MSGS(a3),d0
	lea	dp_msgs,a1
	bsr	.pick
	PXYS	246,73,dp_s
	BKSEL	GS_VIEWINDEX,6
	cmp.b	#1,OPT_ANIMATION(a3)
	bne.s	.an
	PXY	251,82," On"
	bra.s	.o7
.an:	PXY	251,82,"Off"
.o7:	BKSEL	GS_VIEWINDEX,7
	move.b	OPT_FONT_(a3),d0
	lea	dp_fonts,a1
	bsr	.pick
	PXYS	241,91,dp_s
	BKSEL	GS_VIEWINDEX,8
	cmp.b	#1,OPT_AUTOSAVE(a3)
	bne.s	.au
	PXY	251,100," On"
	bra.s	.o9
.au:	PXY	251,100,"Off"
.o9:	moveq	#0,d0
	move.b	OPT_VOLUME(a3),d0
	moveq	#3,d1
	bsr	dp_str
	BKSEL	GS_VIEWINDEX,9
	PXYS	251,109,dp_s
	bsr	mouseshow
	BKCOL	3
.x:	movem.l	(sp)+,d3/a3
	rts
.pick:	cmp.b	#2,d0			; s := table[d0] (6-byte entries), if 0..2
	bhi.s	.px
	ext.w	d0
	mulu	#6,d0
	add.w	d0,a1
	lea	dp_s,a0
	bra	pstr_cpy
.px:	rts

; modplay setmodvolume: setmodvolumeto(options[OPT_VOLUME]) - the LMC1992's master volume (on the
; ST it carries the effects too: they are mixed into the music's DMA stream)
setmodvolume:
	moveq	#0,d0
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_VOLUME-1(a6),d0
	bra	snd_master

; ---------------------------------------------------------------- damage control (viewmode 5)
; the "Engineering Team n" heading (dp_s), its frame lines and column titles
dp_dmg_team:
	BKCOL	5
	TCOL	191
	lea	teamdata+15*14,a0	; printxy(186,109,teamdata[15])
	move.w	#186,d0
	moveq	#109,d1
	bsr	printxy
	; fall through
dp_dmg_title:				; printxy(168,27,'Engineering Team '+str(n:2)+' ')  (n in dp_s)
	lea	dp_s2,a0
	lea	dp_t_engteam,a1
	bsr	pstr_cpy
	lea	dp_s2,a0
	lea	dp_s,a1
	bsr	pstr_cat
	lea	dp_s2,a0
	lea	dp_t_space,a1
	bsr	pstr_cat
	PXYS	168,27,dp_s2
	rts
dp_dmg_level2:				; the screen changes for team level 2 (com 2 and 6-8)
	bsr	dp_clear
	PSET	165,63,10
	PSET	165,90,10
	PSET	279,64,2
	PSET	279,91,2
	LINE	166,45,278,45,10
	LINE	165,44,278,44,2
	PSET	165,44,6
	PSET	279,45,6
	move.w	GS_VIEWINDEX(a6),d0
	ext.l	d0
	moveq	#2,d1
	bsr	dp_str
	bsr	dp_dmg_team
	TCOL	186
	PXY	243,37,"Damage"
	PXY	161,37,"Team"
	PXY	186,37,"Option"
	rts
; with ship.engrteam[d0] do case job of 1..7: if damages[job]=0 then job:=0; 8: if hull full
; then job:=0; end; if job=0 then timeleft:=0
dp_team_check:
	lea	GS_SHIP+SHIP_ENGRTEAM-TEAM_SIZEOF(a6),a0
	mulu	#TEAM_SIZEOF,d0
	add.l	d0,a0
	move.w	TEAM_JOB(a0),d0
	beq.s	.z
	cmp.w	#7,d0
	bhi.s	.h
	lea	GS_SHIP+SHIP_DAMAGES-1(a6),a1
	tst.b	0(a1,d0.w)
	bne.s	.c
	bra.s	.j0
.h:	cmp.w	#8,d0
	bne.s	.c
	move.w	GS_SHIP+SHIP_HULLINTEGRITY(a6),d0
	cmp.w	GS_SHIP+SHIP_HULLMAX(a6),d0
	bne.s	.c
.j0:	clr.w	TEAM_JOB(a0)
.z:	clr.w	TEAM_TIMELEFT(a0)
.c:	rts
; team d0 changed job by the cursor: case job of 0: timeleft:=0; 1..7: if damages[job]>0
; then timeleft := damages[job]*70+random(30); 8: if hull<hullmax then timeleft :=
; (hullmax-hull)*30+random(40)
dp_team_time:
	move.l	a3,-(sp)
	lea	GS_SHIP+SHIP_ENGRTEAM-TEAM_SIZEOF(a6),a3
	mulu	#TEAM_SIZEOF,d0
	add.l	d0,a3
	move.w	TEAM_JOB(a3),d0
	bne.s	.n0
	clr.w	TEAM_TIMELEFT(a3)
	bra.s	.x
.n0:	cmp.w	#7,d0
	bhi.s	.h
	lea	GS_SHIP+SHIP_DAMAGES-1(a6),a0
	moveq	#0,d1
	move.b	0(a0,d0.w),d1
	beq.s	.x
	mulu	#70,d1
	move.w	d1,-(sp)
	moveq	#30,d0
	bsr	mt_random
	add.w	(sp)+,d0
	move.w	d0,TEAM_TIMELEFT(a3)
	bra.s	.x
.h:	cmp.w	#8,d0
	bne.s	.x
	move.w	GS_SHIP+SHIP_HULLMAX(a6),d1
	sub.w	GS_SHIP+SHIP_HULLINTEGRITY(a6),d1
	ble.s	.x
	mulu	#30,d1
	move.w	d1,-(sp)
	moveq	#40,d0
	bsr	mt_random
	add.w	(sp)+,d0
	move.w	d0,TEAM_TIMELEFT(a3)
.x:	move.l	(sp)+,a3
	rts
; printxy(159+6*viewindex, 46+job*7, ' ') on bkcolor 5 (the team's old marker)
dp_team_unmark:
	BKCOL	5
	move.w	GS_VIEWINDEX(a6),d0
	move.w	d0,d1
	mulu	#TEAM_SIZEOF,d1
	lea	GS_SHIP+SHIP_ENGRTEAM-TEAM_SIZEOF(a6),a0
	move.w	TEAM_JOB(a0,d1.w),d1
	mulu	#7,d1
	add.w	#46,d1
	mulu	#6,d0
	add.w	#159,d0
	lea	dp_t_space,a0
	bra	printxy
; a0 := @ship.engrteam[viewindex]
dp_team:
	move.w	GS_VIEWINDEX(a6),d0
	mulu	#TEAM_SIZEOF,d0
	lea	GS_SHIP+SHIP_ENGRTEAM-TEAM_SIZEOF(a6),a0
	add.l	d0,a0
	rts

displaydamagecontrol:
	movem.l	d3-d5/a3,-(sp)
	move.w	d0,d3
	bsr	mousehide
	cmp.w	#1,d3
	bne	.c2
	cmp.w	#2,GS_VIEWLEVEL(a6)	; 1: back to the team list
	bne	.draw
	move.w	#1,GS_VIEWLEVEL(a6)
	bsr	dp_clear
	PSET	165,44,10
	PSET	279,45,2
	LINE	166,63,278,63,2
	LINE	166,90,278,90,2
	LINE	166,64,278,64,10
	LINE	166,91,278,91,10
	PSET	165,63,6
	PSET	165,90,6
	PSET	279,64,6
	PSET	279,91,6
	move.w	GS_VIEWINDEX(a6),d0
	bsr	dp_team_check
	TCOL	191
	BKCOL	5
	PXY	168,27,"Damage Control Teams"
	bra	.draw
.c2:	cmp.w	#2,d3
	bne.s	.c3
	cmp.w	#1,GS_VIEWLEVEL(a6)	; 2: into the team's options
	bne	.draw
	bsr	dp_team
	cmp.w	#9,TEAM_JOB(a0)
	bge	.draw
	move.w	#2,GS_VIEWLEVEL(a6)
	bsr	dp_dmg_level2
	bra	.draw
.c3:	cmp.w	#3,d3
	bne.s	.c4
	cmp.w	#1,GS_VIEWLEVEL(a6)	; 3: up
	bne.s	.u2
	move.w	GS_VIEWINDEX(a6),d0
	subq.w	#1,d0
	bne.s	.u1
	moveq	#3,d0
.u1:	move.w	d0,GS_VIEWINDEX(a6)
	bra	.draw
.u2:	bsr	dp_team
	tst.w	TEAM_JOBTYPE(a0)
	bne	.draw
	move.l	a0,a3
	bsr	dp_team_unmark
	move.w	TEAM_JOB(a3),d0
	subq.w	#1,d0
	bpl.s	.u3
	moveq	#8,d0
.u3:	move.w	d0,TEAM_JOB(a3)
	move.w	GS_VIEWINDEX(a6),d0
	bsr	dp_team_time
	bra	.draw
.c4:	cmp.w	#4,d3
	bne.s	.c5
	cmp.w	#1,GS_VIEWLEVEL(a6)	; 4: down
	bne.s	.d2
	move.w	GS_VIEWINDEX(a6),d0
	addq.w	#1,d0
	cmp.w	#4,d0
	bne.s	.u1
	moveq	#1,d0
	bra.s	.u1
.d2:	bsr	dp_team
	tst.w	TEAM_JOBTYPE(a0)
	bne	.draw
	move.l	a0,a3
	bsr	dp_team_unmark
	move.w	TEAM_JOB(a3),d0
	addq.w	#1,d0
	cmp.w	#9,d0
	bne.s	.u3
	moveq	#0,d0
	bra.s	.u3
.c5:	cmp.w	#5,d3
	bne.s	.c6
	st	d0
	bsr	removerightside
	bsr	mouseshow
	bra	.x
.c6:	cmp.w	#6,d3
	blt	.draw
	cmp.w	#8,d3
	bgt	.draw
	cmp.w	#1,GS_VIEWLEVEL(a6)	; 6-8: a team
	bne.s	.c6b
	move.w	d3,d0
	subq.w	#5,d0
	move.w	d0,GS_VIEWINDEX(a6)
	move.w	#2,GS_VIEWLEVEL(a6)
	bsr	dp_dmg_level2
	bra.s	.draw
.c6b:	cmp.w	#2,GS_VIEWLEVEL(a6)
	bne.s	.draw
	BKCOL	5
	TCOL	191
	lea	teamdata+15*14,a0
	move.w	#186,d0
	moveq	#109,d1
	bsr	printxy
	move.w	d3,d0
	subq.w	#5,d0
	ext.l	d0
	moveq	#2,d1
	bsr	dp_str
	bsr	dp_dmg_title
	move.w	GS_VIEWINDEX(a6),d0
	bsr	dp_team_check
	move.w	d3,d0
	subq.w	#5,d0
	move.w	d0,GS_VIEWINDEX(a6)
.draw:	TCOL	191
	BKCOL	5
	cmp.w	#1,GS_VIEWLEVEL(a6)
	bne	.lv2
	BKSEL	GS_VIEWINDEX,1
	PXY	163,39,"Engineering Team 1"
	BKSEL	GS_VIEWINDEX,2
	PXY	163,66,"Engineering Team 2"
	BKSEL	GS_VIEWINDEX,3
	PXY	163,93,"Engineering Team 3"
	moveq	#1,d3			; for j := 1 to 3 do line(168,20+27*j,258,20+27*j) in 184
.ln:	move.w	d3,d1
	mulu	#27,d1
	add.w	#20,d1
	move.w	#168,d0
	move.w	#258,d2
	movem.l	d3-d4,-(sp)
	move.w	d1,d3
	move.w	#184,d4
	bsr	ms_line
	movem.l	(sp)+,d3-d4
	addq.w	#1,d3
	cmp.w	#4,d3
	bne.s	.ln
	BKCOL	5
	moveq	#1,d3			; the three teams
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a3
.tm:	move.w	d3,d5
	mulu	#27,d5			; 22+j*27 / 28+j*27
	tst.w	TEAM_JOB(a3)
	bne.s	.busy
	lea	dp_s2,a0		; teamdata[0]+'        '
	lea	teamdata,a1
	bsr	pstr_cpy
	lea	dp_s2,a0
	lea	dp_t_8sp,a1
	bsr	pstr_cat
	bra.s	.pt
.busy:	move.w	TEAM_JOBTYPE(a3),d0	; s := 'Repair ' ... by jobtype
	mulu	#10,d0
	lea	dp_jobtypes,a1
	add.w	d0,a1
	lea	dp_s2,a0
	bsr	pstr_cpy
	move.w	TEAM_JOB(a3),d0		; i := the teamdata line of the job
	moveq	#10,d1
	cmp.w	#100,d0
	bls.s	.i0
	cmp.w	#1499,d0
	bls.s	.ii
	moveq	#9,d1
	cmp.w	#1999,d0
	bls.s	.ii
	moveq	#11,d1
	cmp.w	#2999,d0
	bls.s	.ii
	moveq	#12,d1
	cmp.w	#3999,d0
	bls.s	.ii
	moveq	#13,d1
	cmp.w	#4999,d0
	bls.s	.ii
	moveq	#14,d1
	cmp.w	#ID_LAST_ARTIFACT,d0
	bls.s	.ii
	moveq	#-1,d1			; (out of the case: i keeps its value - not reachable)
	bra.s	.ii
.i0:	move.w	d0,d1
.ii:	move.w	d1,d0
	mulu	#14,d0
	lea	teamdata,a1
	add.w	d0,a1
	lea	dp_s2,a0
	bsr	pstr_cat
.pt:	move.w	#169,d0
	move.w	d5,d1
	add.w	#22,d1
	lea	dp_s2,a0
	bsr	printxy
	move.w	TEAM_TIMELEFT(a3),d0
	bne.s	.tl
	PLEA	"Completed  "
	bra.s	.ptl
.tl:	bpl.s	.min
	TCOL	94
	PLEA	"Overdue    "
	move.w	#175,d0
	move.w	d5,d1
	add.w	#28,d1
	bsr	printxy
	TCOL	191
	bra.s	.nt
.min:	ext.l	d0
	moveq	#6,d1
	bsr	dp_str
	lea	dp_s,a0
	lea	dp_t_mins,a1
	bsr	pstr_cat
	lea	dp_s,a0
.ptl:	move.w	#175,d0
	move.w	d5,d1
	add.w	#28,d1
	bsr	printxy
.nt:	lea	TEAM_SIZEOF(a3),a3
	addq.w	#1,d3
	cmp.w	#4,d3
	bne	.tm
	bra	.done
.lv2:	cmp.w	#2,GS_VIEWLEVEL(a6)
	bne	.done
	bsr	dp_team
	move.l	a0,a3
	move.w	#5,GS_BKCOLOR(a6)
	tst.w	TEAM_JOB(a3)
	bne.s	.b0
	move.w	#179,GS_BKCOLOR(a6)
.b0:	lea	teamdata,a0
	move.w	#186,d0
	moveq	#46,d1
	bsr	printxy
	moveq	#1,d3			; the seven systems with their damage
.sy:	move.w	#5,GS_BKCOLOR(a6)
	cmp.w	TEAM_JOB(a3),d3
	bne.s	.b1
	move.w	#179,GS_BKCOLOR(a6)
.b1:	lea	GS_SHIP+SHIP_DAMAGES-1(a6),a0
	moveq	#0,d0
	move.b	0(a0,d3.w),d0
	moveq	#3,d1
	bsr	dp_str
	move.w	d3,d0
	mulu	#14,d0
	lea	teamdata,a0
	add.w	d0,a0
	move.w	d3,d1
	mulu	#7,d1
	add.w	#46,d1
	move.w	d1,d5
	move.w	#186,d0
	bsr	printxy
	lea	dp_s,a0
	move.w	#258,d0
	move.w	d5,d1
	bsr	printxy
	addq.w	#1,d3
	cmp.w	#8,d3
	bne.s	.sy
	move.w	#5,GS_BKCOLOR(a6)
	cmp.w	#8,TEAM_JOB(a3)
	bne.s	.b8
	move.w	#179,GS_BKCOLOR(a6)
.b8:	move.w	GS_SHIP+SHIP_HULLMAX(a6),d0
	sub.w	GS_SHIP+SHIP_HULLINTEGRITY(a6),d0
	ext.l	d0
	moveq	#4,d1
	bsr	dp_str
	lea	teamdata+8*14,a0
	move.w	#186,d0
	move.w	#102,d1
	bsr	printxy
	PXYS	253,102,dp_s
	BAR	170,46,186,114,5	; the markers' column
	moveq	#1,d3
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a3
.mk:	moveq	#9,d1			; job row (9: not a repair)
	cmp.w	#JOBTYPE_REPAIR,TEAM_JOBTYPE(a3)
	bgt.s	.m9
	move.w	TEAM_JOB(a3),d1
.m9:	mulu	#7,d1
	add.w	#46,d1
	move.w	d3,d0
	mulu	#6,d0
	add.w	#159,d0
	TCOL	61
	BKCOL	5
	move.w	d3,d2			; chr(j+48)
	add.b	#'0',d2
	move.b	d2,dp_s1+1
	move.b	#1,dp_s1
	lea	dp_s1,a0
	bsr	printxy
	lea	TEAM_SIZEOF(a3),a3
	addq.w	#1,d3
	cmp.w	#4,d3
	bne.s	.mk
.done:	bsr	mouseshow
	BKCOL	3
.x:	movem.l	(sp)+,d3-d5/a3
	rts

; ---------------------------------------------------------------- shields (viewmode 4)
; showshdicon(shd d0)
showshdicon:
	cmp.w	#ID_NOSHIELD,d0
	bne.s	.ic
	BAR	172,89,191,108,0
	rts
.ic:	cmp.w	#1519,d0
	bhi.s	.x
	sub.w	#ID_SHIELDS_OFFSET+2,d0	; readweaicon(shd-ID_SHIELDS_OFFSET-2)
	bsr	readweaicon
	move.w	#172,d0			; 20 rows of 20 at (172,89)
	moveq	#89,d1
	bra	dp_icon_put
.x:	rts

; copy tempicon (20x20, row-major [i][j] = row i) to the shadow at (d0,d1)
dp_icon_put:
	movem.l	d3/a3,-(sp)
	move.w	d0,d3
	movem.w	d0-d1,-(sp)
	bsr	ms_addr
	move.l	GS_TEMPICON(a6),a1
	moveq	#20-1,d1
.r:	moveq	#20-1,d0
	move.l	a0,a2
.c:	move.b	(a1)+,(a2)+
	dbf	d0,.c
	lea	MS_W(a0),a0
	dbf	d1,.r
	movem.w	(sp)+,d0-d1
	move.w	d0,d2
	add.w	#19,d2
	move.w	d1,d3
	add.w	#19,d3
	bsr	ms_dirty
	movem.l	(sp)+,d3/a3
	rts

; the shield/weapon statistics frame (setupshieldinfo and setupweaponinfo share it)
dp_statframe:
	LINE	166,53,278,53,10
	LINE	166,83,278,83,10
	LINE	220,53,220,81,10
	LINE	166,52,278,52,2
	LINE	166,82,278,82,2
	LINE	219,54,219,82,2
	PSET	279,53,6
	PSET	279,83,6
	PSET	165,52,6
	PSET	165,82,6
	PSET	220,82,6
	PSET	219,53,6
	RGRAYB	204,86,271,111
	rts
dp_ppie:
	PXY	194,87,"P"
	PXY	194,93,"P"
	PXY	193,99,"I"
	PXY	194,105,"E"
	rts

; setupshieldinfo(shd d0)
setupshieldinfo:
	move.l	d3,-(sp)
	move.w	d0,d3
	bsr	dp_clear
	LINE	168,44,232,44,184
	RGRAYB	171,88,192,109
	bsr	dp_statframe
	cmp.w	#3,GS_VIEWLEVEL(a6)
	bge.s	.t
	PXY	163,37,"Active Shield"
	bra.s	.l
.t:	PXY	163,37,"Target Shield"
.l:	PXY	163,54,"Sys Damage"
	PXY	163,61,"Max Energy"
	PXY	163,68,"Protection"
	PXY	163,75,"Cargo Size"
	bsr	dp_ppie
	move.w	d3,d0
	bsr	showshdicon
	move.l	(sp)+,d3
	rts

; the four damage-type bars of weapon/shield record a0 (dmgtypes[1..4]) at x 205, rows 83+i+j*6
dp_dmgbars:
	movem.l	d3-d6/a3,-(sp)
	move.l	a0,a3
	moveq	#1,d3			; j
.j:	moveq	#0,d0			; y := round(dmgtypes[j]*0.66)  (x87)
	move.b	WEAPON_DMGTYPES-1(a3,d3.w),d0
	FX87
	bsr	fp_ldi
	FLDX	gx_0_66
	bsr	fp_mul
	bsr	fp_rnd
	move.w	d0,d5			; y
	moveq	#-2,d6			; i
.i:	move.w	#100,d4			; x := 100-i (i > 0) or 100+i
	tst.w	d6
	ble.s	.p
	sub.w	d6,d4
	bra.s	.q
.p:	add.w	d6,d4
.q:	move.w	d3,d1			; row 83+i+j*6
	mulu	#6,d1
	add.w	#83,d1
	add.w	d6,d1
	move.w	d1,-(sp)
	move.w	#205,d0
	move.w	d5,d2
	bsr	dp_fill
	move.w	(sp)+,d1
	cmp.w	#66,d5
	bge.s	.n
	move.w	#205,d0
	add.w	d5,d0
	moveq	#66,d2
	sub.w	d5,d2
	move.w	d4,-(sp)
	moveq	#0,d4
	bsr	dp_fill
	move.w	(sp)+,d4
.n:	addq.w	#1,d6
	cmp.w	#4,d6
	bne.s	.i
	addq.w	#1,d3
	cmp.w	#5,d3
	bne	.j
	FSSE
	movem.l	(sp)+,d3-d6/a3
	rts

; displayshieldinfo(shd d0)
displayshieldinfo:
	movem.l	d3/a3,-(sp)
	move.w	d0,d3
	TCOL	31
	cmp.w	#ID_NOSHIELD,d3
	ble.s	.nn
	move.w	d3,d0
	sub.w	#ID_SHIELDS_OFFSET,d0
	bsr	dp_cargoname
	move.w	#174,d0
	moveq	#45,d1
	bsr	printxy
	bra.s	.dm
.nn:	PXY	174,45,"None                "
.dm:	moveq	#0,d0
	move.b	GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6),d0
	beq.s	.dn
	moveq	#5,d1
	bsr	dp_str
	lea	dp_s,a0
	lea	dp_t_pct3,a1
	bsr	pstr_cat
	PXYS	218,54,dp_s
	bra.s	.en
.dn:	PXY	218,54,"      None"
.en:	cmp.w	#ID_NOSHIELD,d3
	ble.s	.none
	move.w	d3,d0
	sub.w	#ID_SHIELDS_OFFSET,d0
	bsr	dp_weapon
	move.l	a0,a3
	move.w	WEAPON_ENERGY(a3),d0
	ext.l	d0
	moveq	#5,d1
	bsr	dp_str
	lea	dp_s,a0
	lea	dp_t_gw,a1
	bsr	pstr_cat
	PXYS	218,61,dp_s
	move.w	WEAPON_DAMAGE(a3),d0
	ext.l	d0
	moveq	#5,d1
	bsr	dp_str
	lea	dp_s,a0
	lea	dp_t_gj,a1
	bsr	pstr_cat
	PXYS	218,68,dp_s
	move.l	a3,a0
	bsr	dp_dmgbars
	bra.s	.cg
.none:	PXY	218,61,"      None"
	PXY	218,68,"      None"
	BAR	205,87,269,110,2
.cg:	cmp.w	#ID_REFLECTIVEHULL,d3	; cargo size of a powered shield
	ble.s	.cn
	lea	GS_CARGO+CARGO_INDEX(a6),a0	; j := 1; while cargo[j].index <> shd do inc(j)
	moveq	#1,d1
.f:	cmp.w	(a0),d3
	beq.s	.fd
	lea	CARGO_SIZEOF(a0),a0
	addq.w	#1,d1
	bra.s	.f
.fd:	cmp.w	#114,d1
	bge.s	.x
	move.w	CARGO_SIZE-CARGO_INDEX(a0),d0
	ext.l	d0
	divs	#10,d0
	ext.l	d0
	moveq	#5,d1
	bsr	dp_str
	lea	dp_s,a0
	lea	dp_t_cum,a1
	bsr	pstr_cat
	PXYS	218,75,dp_s
	bra.s	.x
.cn:	PXY	218,75,"      None"
.x:	movem.l	(sp)+,d3/a3
	rts

; the cargo slot frames of the shield list (removeshieldinfo, the end)
removeshieldinfo:
	move.l	d3,-(sp)
	bsr	dp_clear
	PSET	165,52,10
	PSET	165,82,10
	PSET	279,53,2
	PSET	279,83,2
	SHOWPANEL 9,12,12
	PXY	168,27,"Shield Configuration"
	PXY	163,37,"Active Shield"
	LINE	168,44,232,44,184
	TCOL	31
	move.w	GS_SHIP+SHIP_SHIELD(a6),d0
	cmp.w	#ID_NOSHIELD,d0
	ble.s	.nn
	sub.w	#ID_SHIELDS_OFFSET,d0
	bsr	dp_cargoname
	move.w	#174,d0
	moveq	#45,d1
	bsr	printxy
	bra.s	.t
.nn:	PXY	174,45,"None                "
.t:	TCOL	191
	moveq	#1,d3
.j:	move.w	d3,d1			; y0 = 51+j*18
	mulu	#18,d1
	add.w	#51,d1
	movem.w	d1/d3,-(sp)
	move.w	d1,d3
	move.w	#172,d0
	move.w	#274,d2
	moveq	#2,d4
	bsr	dp_line			; line(172,y0,274,y0) 2
	move.w	(sp),d1
	move.w	#172,d0
	move.w	d0,d2
	move.w	d1,d3
	addq.w	#6,d3
	moveq	#2,d4
	bsr	dp_line			; line(172,y0,172,y0+6) 2
	move.w	(sp),d1
	addq.w	#6,d1
	move.w	#172,d0
	move.w	#273,d2
	move.w	d1,d3
	moveq	#10,d4
	bsr	dp_line			; line(172,y0+6,273,y0+6) 10
	move.w	(sp),d1
	move.w	#274,d0
	move.w	d0,d2
	move.w	d1,d3
	addq.w	#6,d3
	moveq	#10,d4
	bsr	dp_line			; line(274,y0,274,y0+6) 10
	move.w	(sp),d1
	move.w	#274,d0
	moveq	#4,d2
	bsr	ms_pset
	move.w	(sp),d1
	addq.w	#6,d1
	move.w	#172,d0
	moveq	#4,d2
	bsr	ms_pset
	movem.w	(sp)+,d1/d3
	addq.w	#1,d3
	cmp.w	#4,d3
	bne	.j
	move.l	(sp)+,d3
	rts
; ms_line keeping d3/d4 (in: d0-d3 = x1,y1,x2,y2, d4 colour)
dp_line:
	movem.l	d3-d4,-(sp)
	bsr	ms_line
	movem.l	(sp)+,d3-d4
	rts

; is ship.cargo[d0] (1..250) a shield (ID_NOSHIELD..ID_LAST_SHIELD)?  Z clear (d1 <> 0) = yes
dp_isshield:
	add.w	d0,d0
	lea	GS_SHIP+SHIP_CARGO-2(a6),a0
	move.w	0(a0,d0.w),d1
	lsr.w	#1,d0
	cmp.w	#ID_NOSHIELD,d1
	blt.s	.no
	cmp.w	#ID_LAST_SHIELD,d1
	bgt.s	.no
	moveq	#1,d1
	rts
.no:	moveq	#0,d1
	rts
; ship.cargo[d0] (1..250)                                  out d1.w
dp_cargoitem:
	move.w	d0,d1
	add.w	d1,d1
	lea	GS_SHIP+SHIP_CARGO-2(a6),a0
	move.w	0(a0,d1.w),d1
	rts

; the "Installable Shields" level-2 screen
dp_shd_level2:
	bsr	dp_clear
	SHOWPANEL 11,8,12
	PSET	165,52,10
	PSET	165,82,10
	PSET	279,53,2
	PSET	279,83,2
	PXY	170,27,"Installable Shields"
	rts

displayshieldopts:
	movem.l	d3-d7/a3,-(sp)
	move.w	d0,d3
	TCOL	191
	BKCOL	5
	bsr	mousehide
	lea	GS_SHIP+SHIP_SHIELDOPT-1(a6),a3	; shieldopt[1..3]
	cmp.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)
	bne.s	.r1
	moveq	#100,d0
	sub.b	GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6),d0
	move.b	d0,1(a3)
	move.b	d0,2(a3)
	move.b	d0,3(a3)
.r1:	cmp.w	#ID_NOSHIELD,GS_SHIP+SHIP_SHIELD(a6)
	bgt.s	.r2
	clr.b	1(a3)
	clr.b	2(a3)
	clr.b	3(a3)
.r2:	move.w	GS_VIEWINDEX(a6),d7
	cmp.w	#1,d3
	bne	.c2
	tst.w	GS_VIEWLEVEL(a6)	; 1: left
	bne.s	.l3
	cmp.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)
	ble	.draw
	moveq	#0,d0			; dec(shieldopt[vi], min(5, shieldopt[vi]))
	move.b	0(a3,d7.w),d0
	moveq	#5,d1
	cmp.w	d1,d0
	bge.s	.m1
	move.w	d0,d1
.m1:	sub.b	d1,0(a3,d7.w)
	bra	.draw
.l3:	cmp.w	#3,GS_VIEWLEVEL(a6)
	bne	.draw
	move.w	#2,GS_VIEWLEVEL(a6)
	bsr	dp_shd_level2
	bra	.draw
.c2:	cmp.w	#2,d3
	bne.s	.c3
	tst.w	GS_VIEWLEVEL(a6)	; 2: right
	bne.s	.r3
	cmp.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)
	ble	.draw
	moveq	#0,d0			; inc(shieldopt[vi], min(5, 100-shieldopt[vi]))
	move.b	0(a3,d7.w),d0
	moveq	#100,d1
	sub.w	d0,d1
	moveq	#5,d0
	cmp.w	d0,d1
	ble.s	.m2
	move.w	d0,d1
.m2:	add.b	d1,0(a3,d7.w)
	bra	.draw
.r3:	cmp.w	#2,GS_VIEWLEVEL(a6)
	bne	.draw
	tst.w	GS_VIEWINDEX2(a6)
	ble	.draw
	move.w	#3,GS_VIEWLEVEL(a6)
	move.w	GS_VIEWINDEX2(a6),d0
	bsr	dp_cargoitem
	move.w	d1,d0
	bsr	setupshieldinfo
	bra	.draw
.c3:	cmp.w	#3,d3
	bne	.c4
	cmp.w	#1,GS_VIEWLEVEL(a6)	; 3: up
	ble.s	.u1
	move.w	GS_VIEWINDEX2(a6),d4
	subq.w	#1,d4
	bsr	.prevshd
	tst.w	d4
	bne.s	.u0
	move.w	#250,d4
	bsr	.prevshd
.u0:	move.w	d4,GS_VIEWINDEX2(a6)
	bra	.showic
.u1:	subq.w	#1,d7
	bne.s	.u2
	moveq	#3,d7
.u2:	move.w	d7,GS_VIEWINDEX(a6)
	bra	.draw
.prevshd:				; while (d4 > 0) and not shield(cargo[d4]) do dec(d4)
	tst.w	d4
	ble.s	.px
	move.w	d4,d0
	bsr	dp_isshield
	bne.s	.px
	subq.w	#1,d4
	bra.s	.prevshd
.px:	rts
.nextshd:				; while (d4 < 251) and not shield(cargo[d4]) do inc(d4)
	cmp.w	#251,d4
	bge.s	.nx
	move.w	d4,d0
	bsr	dp_isshield
	bne.s	.nx
	addq.w	#1,d4
	bra.s	.nextshd
.nx:	rts
.c4:	cmp.w	#4,d3
	bne.s	.c5
	cmp.w	#1,GS_VIEWLEVEL(a6)	; 4: down
	ble.s	.d1
	move.w	GS_VIEWINDEX2(a6),d4
	addq.w	#1,d4
	bsr	.nextshd
	cmp.w	#251,d4
	bne.s	.d0
	moveq	#1,d4
.d0:	bsr	.nextshd
	cmp.w	#251,d4
	bne.s	.u0
	moveq	#0,d4
	bra.s	.u0
.d1:	addq.w	#1,d7
	cmp.w	#4,d7
	bne.s	.u2
	moveq	#1,d7
	bra.s	.u2
.showic:tst.w	GS_VIEWINDEX2(a6)	; if (viewindex2 > 0) and (viewlevel = 3) then showshdicon
	ble	.draw
	cmp.w	#3,GS_VIEWLEVEL(a6)
	bne	.draw
	move.w	GS_VIEWINDEX2(a6),d0
	bsr	dp_cargoitem
	move.w	d1,d0
	bsr	showshdicon
	bra	.draw
.c5:	cmp.w	#5,d3
	bne.s	.c6
	bsr	mouseshow
	st	d0
	bsr	removerightside
	bra	.x
.c6:	cmp.w	#6,d3
	bne.s	.c7
	tst.w	GS_VIEWLEVEL(a6)
	bne.s	.c6b
	move.w	#1,GS_VIEWLEVEL(a6)
	PXY	165,27,"  Shield Statistics  "
	move.w	GS_SHIP+SHIP_SHIELD(a6),d0
	bsr	setupshieldinfo
	SHOWPANEL 11,7,8
	bra	.draw
.c6b:	clr.w	GS_VIEWLEVEL(a6)
	bsr	removeshieldinfo
	bra	.draw
.c7:	cmp.w	#7,d3
	bne	.c8
	bsr	dp_shieldjob
	BKCOL	5
	TCOL	191
	bra	.draw
.c8:	cmp.w	#8,d3
	bne	.draw
	cmp.w	#1,GS_VIEWLEVEL(a6)
	bne	.draw
	move.w	#2,GS_VIEWLEVEL(a6)
	bsr	dp_shd_level2
	moveq	#1,d4
	bsr	.nextshd
	cmp.w	#251,d4
	bne.s	.c8b
	moveq	#0,d4
.c8b:	move.w	d4,GS_VIEWINDEX2(a6)
.draw:	move.w	GS_VIEWLEVEL(a6),d0
	bne	.dl1
	TCOL	31			; level 0: the modes and their bars
	move.w	GS_SHIP+SHIP_SHIELD(a6),d0
	cmp.w	#ID_NOSHIELD,d0
	ble.s	.n0
	sub.w	#ID_SHIELDS_OFFSET,d0
	bsr	dp_cargoname
	move.w	#174,d0
	moveq	#45,d1
	bsr	printxy
	bra.s	.n1
.n0:	PXY	174,45,"None                "
.n1:	TCOL	191
	moveq	#0,d0
	move.b	GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6),d0
	moveq	#3,d1
	bsr	dp_str
	lea	dp_s2,a0
	lea	dp_t_sysdmg,a1
	bsr	pstr_cpy
	lea	dp_s2,a0
	lea	dp_s,a1
	bsr	pstr_cat
	lea	dp_s2,a0
	lea	dp_t_pct,a1
	bsr	pstr_cat
	PXYS	163,53,dp_s2
	BKSEL	GS_VIEWINDEX,1
	PXY	163,61,"Rest Mode"
	BKSEL	GS_VIEWINDEX,2
	PXY	163,79,"Alert Mode"
	BKSEL	GS_VIEWINDEX,3
	PXY	163,97,"Combat Mode"
	moveq	#1,d4			; the bars: line(173,54+i+j*18,173+shieldopt[j],..) in 40-|i|
.bj:	moveq	#-2,d5
.bi:	move.w	#40,d6
	tst.w	d5
	ble.s	.bp
	sub.w	d5,d6
	bra.s	.bq
.bp:	add.w	d5,d6
.bq:	move.w	d4,d1
	mulu	#18,d1
	add.w	#54,d1
	add.w	d5,d1
	move.w	#173,d0
	moveq	#0,d2
	move.b	0(a3,d4.w),d2
	add.w	#173,d2
	movem.l	d3-d4,-(sp)
	move.w	d1,d3
	move.w	d6,d4
	bsr	ms_line
	movem.l	(sp)+,d3-d4
	addq.w	#1,d5
	cmp.w	#3,d5
	bne.s	.bi
	addq.w	#1,d4
	cmp.w	#4,d4
	bne.s	.bj
	moveq	#1,d4			; bar(174+shieldopt[j],52+j*18,274,57+j*18) in 2 if < 100
.bb:	cmp.b	#100,0(a3,d4.w)
	bhs.s	.bn
	moveq	#0,d0
	move.b	0(a3,d4.w),d0
	add.w	#174,d0
	move.w	d4,d1
	mulu	#18,d1
	add.w	#52,d1
	move.w	#273,d2		; (c_utils.c bar: x2 and y2 excluded)
	movem.l	d3-d4,-(sp)
	move.w	d1,d3
	addq.w	#4,d3
	moveq	#2,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
.bn:	addq.w	#1,d4
	cmp.w	#4,d4
	bne.s	.bb
	bra	.after
.dl1:	cmp.w	#1,d0
	bne.s	.dl2
	move.w	GS_SHIP+SHIP_SHIELD(a6),d0
	bsr	displayshieldinfo
	bra	.after
.dl2:	cmp.w	#2,d0
	bne	.dl3
	move.w	GS_VIEWINDEX2(a6),d0	; the list of installable shields
	ble.s	.l2a
	bsr	dp_cargoitem
	cmp.w	#ID_NOSHIELD,d1
	blt.s	.l2r
	cmp.w	#ID_NOTHING,d1
	blt.s	.l2a
.l2r:	moveq	#4,d0			; displayshieldopts(4) (recursion, as the original)
	bsr	displayshieldopts
	bsr	mousehide		; (the inner call showed the mouse)
.l2a:	move.w	GS_VIEWINDEX2(a6),d4	; x := viewindex2+1; y := 7: the ones after
	addq.w	#1,d4
	moveq	#7,d5
.af:	bsr	.nextshd
	cmp.w	#251,d4
	bge.s	.afn
	addq.w	#1,d5
	move.w	d4,d0
	bsr	dp_cargoitem
	move.w	d1,d0
	sub.w	#ID_SHIELDS_OFFSET,d0
	bsr	dp_cargoname
	move.w	#167,d0
	move.w	d5,d1
	mulu	#6,d1
	add.w	#31,d1
	bsr	printxy
.afn:	addq.w	#1,d4
	cmp.w	#13,d5
	beq.s	.af2
	cmp.w	#250,d4
	ble.s	.af
.af2:	cmp.w	#13,d5
	bge.s	.bf
	move.w	d5,d1			; for j := 38+y*6 to 116: clear
	mulu	#6,d1
	add.w	#38,d1
	move.w	#166,d0
	move.w	#278,d2
	movem.l	d3-d4,-(sp)
	moveq	#116,d3
	moveq	#5,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
.bf:	move.w	GS_VIEWINDEX2(a6),d4	; x := viewindex2; y := 8: this one and the ones before
	moveq	#8,d5
.bl:	bsr	.prevshd
	move.w	#5,GS_BKCOLOR(a6)
	cmp.w	GS_VIEWINDEX2(a6),d4
	bne.s	.bk
	move.w	#179,GS_BKCOLOR(a6)
.bk:	tst.w	d4
	ble.s	.bln
	subq.w	#1,d5
	move.w	d4,d0
	bsr	dp_cargoitem
	move.w	d1,d0
	sub.w	#ID_SHIELDS_OFFSET,d0
	bsr	dp_cargoname
	move.w	#167,d0
	move.w	d5,d1
	mulu	#6,d1
	add.w	#31,d1
	bsr	printxy
.bln:	subq.w	#1,d4
	cmp.w	#1,d5
	beq.s	.bl2
	tst.w	d4
	bge.s	.bl
.bl2:	cmp.w	#1,d5
	ble	.after
	move.w	d5,d3			; for j := 37 to 31+y*6: clear
	mulu	#6,d3
	add.w	#31,d3
	move.w	#166,d0
	moveq	#37,d1
	move.w	#278,d2
	move.l	d4,-(sp)
	moveq	#5,d4
	bsr	ms_bar
	move.l	(sp)+,d4
	bra.s	.after
.dl3:	cmp.w	#3,d0
	bne.s	.after
	move.w	GS_VIEWINDEX2(a6),d0
	bsr	dp_cargoitem
	cmp.w	#ID_NOSHIELD,d1
	blt.s	.l3r
	cmp.w	#ID_NOTHING,d1
	blt.s	.l3a
.l3r:	moveq	#4,d0
	bsr	displayshieldopts
	bsr	mousehide
.l3a:	move.w	GS_VIEWINDEX2(a6),d0
	ble.s	.after
	bsr	dp_cargoitem
	move.w	d1,d0
	bsr	displayshieldinfo
.after:	bsr	mouseshow
	BKCOL	3
	cmp.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)	; engineering / shield checks
	ble.s	.x
	moveq	#0,d0
	move.b	GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6),d0
	cmp.w	#25,d0
	ble.s	.lev
	TCOL	94
	PRTLN
	clr.w	GS_SHIP+SHIP_SHIELDLEVEL(a6)
	cmp.b	#59,GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6)
	bls.s	.uns
	PRT	"COMPUTER: Shield integrity compromised...needs repair."
	bra.s	.x
.uns:	PRT	"Shield unstable..."
	moveq	#40,d0
	bsr	mt_random
	add.w	#20,d0
	moveq	#0,d1
	move.b	GS_SHIP+SHIP_DAMAGES+DMG_SHIELD-1(a6),d1
	cmp.w	d1,d0
	bge.s	.lev
	PRT	"COMPUTER: Failed to adjust shield."
	bra.s	.x
.lev:	move.w	GS_ALERT(a6),d0		; shieldlevel := shieldopt[alert+1]
	cmp.w	#2,d0
	bhi.s	.x
	moveq	#0,d1
	move.b	1(a3,d0.w),d1
	move.w	d1,GS_SHIP+SHIP_SHIELDLEVEL(a6)
.x:	movem.l	(sp)+,d3-d7/a3
	rts

; displayshieldopts com 7: remove the shield, install one, or say why not
dp_shieldjob:
	movem.l	d3-d4/a3,-(sp)
	moveq	#0,d3			; i := 1 if a team is installing/removing a shield
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a0
	moveq	#3-1,d1
.t:	move.w	TEAM_JOBTYPE(a0),d0
	cmp.w	#JOBTYPE_INSTALL,d0
	blt.s	.tn
	cmp.w	#JOBTYPE_REMOVE,d0
	bgt.s	.tn
	move.w	TEAM_JOB(a0),d0
	cmp.w	#ID_NOSHIELD,d0
	blt.s	.tn
	cmp.w	#ID_LAST_SHIELD,d0
	bgt.s	.tn
	moveq	#1,d3
.tn:	lea	TEAM_SIZEOF(a0),a0
	dbf	d1,.t
	tst.w	d3
	beq.s	.n1
	TCOL	94
	BKCOL	3
	PRTLN
	PRT	"ENGINEERING: Already working on a shield."
	bra	.x
.n1:	cmp.w	#1,GS_VIEWLEVEL(a6)
	bne	.inst
	cmp.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)
	ble	.inst
	bsr	mouseshow		; remove
	PLEA	"Remove this shield?"
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq	.mh
	bsr	dp_freeteam
	cmp.w	#4,d4
	bne.s	.rm
	PRTLN
	TCOL	94
	PRT	"ENGINEERING: No team available."
	bra	.mh
.rm:	move.w	GS_SHIP+SHIP_SHIELD(a6),d0
	st	d1
	bsr	addcargo
	move.w	GS_SHIP+SHIP_SHIELD(a6),TEAM_JOB(a3)
	move.w	#JOBTYPE_REMOVE,TEAM_JOBTYPE(a3)
	move.w	#1000,TEAM_TIMELEFT(a3)
	move.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)
	bsr	mousehide
	move.w	#ID_REFLECTIVEHULL,d0
	bsr	showshdicon
	bsr	mouseshow
	clr.b	GS_SHIP+SHIP_SHIELDOPT(a6)
	clr.b	GS_SHIP+SHIP_SHIELDOPT+1(a6)
	clr.b	GS_SHIP+SHIP_SHIELDOPT+2(a6)
	bra	.mh
.inst:	cmp.w	#1,GS_VIEWLEVEL(a6)
	ble	.x
	tst.w	GS_VIEWINDEX2(a6)
	ble	.x
	cmp.w	#ID_REFLECTIVEHULL,GS_SHIP+SHIP_SHIELD(a6)
	bgt.s	.old
	bsr	mouseshow
	PLEA	"Install this shield?"
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq.s	.mh
	bsr	dp_freeteam
	cmp.w	#4,d4
	bne.s	.in
	PRTLN
	TCOL	94
	PRT	"ENGINEERING: No team available."
	bra.s	.mh
.in:	move.w	GS_VIEWINDEX2(a6),d0
	bsr	dp_cargoitem
	move.w	d1,TEAM_JOB(a3)
	move.w	d1,d0
	bsr	removecargo
	move.w	#JOBTYPE_INSTALL,TEAM_JOBTYPE(a3)
	move.w	#1000,TEAM_TIMELEFT(a3)
.mh:	bsr	mousehide
	bra.s	.x
.old:	TCOL	94
	BKCOL	3
	PRTLN
	PRT	"ENGINEERING: We must remove the old shield first."
.x:	movem.l	(sp)+,d3-d4/a3
	rts
; j := 1; while (ship.engrteam[j].job <> 0) and (j < 4) do inc(j): d4 = j, a3 = @engrteam[j]
dp_freeteam:
	moveq	#1,d4
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a3
.l:	tst.w	TEAM_JOB(a3)
	beq.s	.x
	cmp.w	#4,d4
	bge.s	.x
	addq.w	#1,d4
	lea	TEAM_SIZEOF(a3),a3
	bra.s	.l
.x:	rts

; ---------------------------------------------------------------- weapons (viewmode 2)
setupweaponinfo:
	bsr	dp_clear
	RGRAYB	171,88,192,109
	bsr	dp_statframe
	cmp.w	#3,GS_VIEWLEVEL(a6)
	bge.s	.t
	PXY	163,37,"Active Weapon"
	bra.s	.l
.t:	PXY	163,37,"Target Shield"
.l:	PXY	175,54,"Range"
	PXY	163,61,"Max Energy"
	PXY	173,68,"Damage"
	PXY	163,75,"Cargo Size"
	bra	dp_ppie

; displayweaponstats(weap d0)
displayweaponstats:
	movem.l	d3/a3,-(sp)
	move.w	d0,d3
	TCOL	31
	tst.w	d3
	bgt.s	.nm
	moveq	#58,d0			; cargo[58].name
.nm:	bsr	dp_cargoname
	move.w	#174,d0
	moveq	#45,d1
	bsr	printxy
	tst.w	d3
	ble	.none
	move.w	d3,d0
	bsr	dp_weapon
	move.l	a0,a3
	move.l	WEAPON_RANGE(a3),d0	; str((range div 1000):3)+' KKM  '
	divs	#1000,d0
	ext.l	d0
	moveq	#3,d1
	bsr	dp_str
	lea	dp_s,a0
	lea	dp_t_kkm,a1
	bsr	pstr_cat
	PXYS	228,54,dp_s
	move.w	WEAPON_ENERGY(a3),d0
	ext.l	d0
	moveq	#5,d1
	bsr	dp_str
	lea	dp_s,a0
	lea	dp_t_gw,a1
	bsr	pstr_cat
	PXYS	218,61,dp_s
	move.w	WEAPON_DAMAGE(a3),d0
	ext.l	d0
	moveq	#4,d1
	bsr	dp_str
	lea	dp_s,a0
	lea	dp_t_gj,a1
	bsr	pstr_cat
	PXYS	223,68,dp_s
	move.w	d3,d1			; j := index of cargo with weap+ID_DIRK-1
	add.w	#ID_DIRK-1,d1
	lea	GS_CARGO+CARGO_INDEX(a6),a0
	moveq	#1,d0
.f:	cmp.w	(a0),d1
	beq.s	.fd
	lea	CARGO_SIZEOF(a0),a0
	addq.w	#1,d0
	bra.s	.f
.fd:	cmp.w	#114,d0
	bge.s	.bars
	move.w	CARGO_SIZE-CARGO_INDEX(a0),d0
	ext.l	d0
	divs	#10,d0
	ext.l	d0
	moveq	#5,d1
	bsr	dp_str
	lea	dp_s,a0
	lea	dp_t_cum,a1
	bsr	pstr_cat
	PXYS	218,75,dp_s
.bars:	move.l	a3,a0
	bsr	dp_dmgbars
	bra.s	.x
.none:	PXY	218,54,"       None"
	PXY	218,61,"       None"
	PXY	218,68,"       None"
	PXY	218,75,"       None"
	BAR	205,87,270,110,2
.x:	movem.l	(sp)+,d3/a3
	rts

; getweaponicons(x1 d0, y1 d1, weap d2, node d3): b := -1 / 1 (dp_b); out d0.w = dp_b
; (an installing team at the node: the box in 84; no weapon: in 5; else readweaicon(weap-1))
getweaponicons:
	movem.l	d3-d4,-(sp)
	move.w	#-1,dp_b
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a0
	moveq	#3-1,d4
.t:	cmp.w	#ID_DIRK,TEAM_JOB(a0)
	blt.s	.tn
	cmp.w	#ID_NOSHIELD-1,TEAM_JOB(a0)
	bge.s	.tn
	cmp.w	#JOBTYPE_INSTALL,TEAM_JOBTYPE(a0)
	bne.s	.tn
	move.w	TEAM_EXTRA(a0),d0
	and.w	#15,d0
	cmp.w	d3,d0
	bne.s	.tn
	moveq	#84,d4			; a team is installing at this node
	bra.s	.bar
.tn:	lea	TEAM_SIZEOF(a0),a0
	dbf	d4,.t
	tst.w	d2
	bne.s	.rd
	moveq	#5,d4			; no weapon
.bar:	move.w	dp_wx,d0
	move.w	dp_wy,d1
	move.w	d0,d2
	add.w	#19,d2
	move.w	d1,d3
	add.w	#19,d3
	bsr	ms_bar
	moveq	#-1,d0
	bra.s	.x
.rd:	move.w	#1,dp_b
	move.w	d2,d0
	subq.w	#1,d0
	bsr	readweaicon
	moveq	#1,d0
.x:	movem.l	(sp)+,d3-d4
	rts

; the four ways to show a weapon icon: in d0 x1, d1 y1, d2 weap, d3 node
showweaponicon:				; rows as stored
	bsr.s	dp_wicon
	bmi.s	.x
	move.w	dp_wx,d0
	move.w	dp_wy,d1
	bra	dp_icon_put
.x:	rts
revshowweaponicon:			; rows upside down: scrto_move(tempicon^[19-i], screen[y1+i,x1])
	bsr.s	dp_wicon
	bmi.s	.x
	moveq	#2,d0
	bra	dp_icon_xform
.x:	rts
sideshowweaponicon:			; screen[y1+j, x1+i] := tempicon^[i,j] (transposed)
	bsr.s	dp_wicon
	bmi.s	.x
	moveq	#1,d0
	bra	dp_icon_xform
.x:	rts
backshowweaponicon:			; screen[y1+j, x1+19-i] := tempicon^[i,j]
	bsr.s	dp_wicon
	bmi.s	.x
	moveq	#3,d0
	bra	dp_icon_xform
.x:	rts
dp_wicon:
	move.w	d0,dp_wx
	move.w	d1,dp_wy
	bsr	getweaponicons
	tst.w	d0
	rts
; draw tempicon at (dp_wx, dp_wy) transformed: d0 = 1 transposed, 2 flipped rows, 3 transposed
; and mirrored
dp_icon_xform:
	movem.l	d3-d5,-(sp)
	move.w	d0,d5
	move.l	GS_TEMPICON(a6),a1
	moveq	#0,d3			; i (source row)
.i:	moveq	#0,d4			; j (source column)
.j:	move.w	d3,d0			; source [i,j] = i*20+j
	mulu	#20,d0
	add.w	d4,d0
	move.b	0(a1,d0.w),d2
	cmp.w	#2,d5
	beq.s	.f
	move.w	dp_wx,d0		; transposed: (x1+i, y1+j), or x1+19-i
	cmp.w	#3,d5
	bne.s	.t1
	add.w	#19,d0
	sub.w	d3,d0
	bra.s	.t2
.t1:	add.w	d3,d0
.t2:	move.w	dp_wy,d1
	add.w	d4,d1
	bra.s	.p
.f:	move.w	dp_wx,d0		; flipped: row 19-i of the source at row i: (x1+j, y1+19-i)
	add.w	d4,d0
	move.w	dp_wy,d1
	add.w	#19,d1
	sub.w	d3,d1
.p:	movem.l	d1/a1,-(sp)
	bsr	chk_pset
	movem.l	(sp)+,d1/a1
	addq.w	#1,d4
	cmp.w	#20,d4
	bne.s	.j
	addq.w	#1,d3
	cmp.w	#20,d3
	bne.s	.i
	move.w	dp_wx,d0
	move.w	dp_wy,d1
	move.w	d0,d2
	add.w	#19,d2
	move.w	d1,d3
	add.w	#19,d3
	bsr	ms_dirty
	movem.l	(sp)+,d3-d5
	rts

; d0 := the next gun node from d0 that has a weapon (0 or 11 when none): helpers
dp_gun:					; d1.w = ship.gunnodes[d0] (1-based bytes)
	lea	GS_SHIP+SHIP_GUNNODES-1(a6),a0
	moveq	#0,d1
	move.b	0(a0,d0.w),d1
	rts

displayweaponinfo:
	movem.l	d3-d5,-(sp)
	move.w	d0,d3
	TCOL	191
	BKCOL	5
	bsr	mousehide
	cmp.w	#1,d3
	bne.s	.c2
	cmp.w	#1,GS_VIEWLEVEL(a6)
	bne	.draw
	PXY	168,27,"Gun Node Information"
	clr.w	GS_VIEWLEVEL(a6)
	bsr	dp_clear
	PSET	165,52,10
	PSET	165,82,10
	PSET	279,53,2
	PSET	279,83,2
	bra	.draw
.c2:	cmp.w	#2,d3
	bne.s	.c3
	tst.w	GS_VIEWLEVEL(a6)
	bne	.draw
	tst.w	GS_VIEWINDEX(a6)
	ble	.draw
	bsr	setupweaponinfo
	bsr	.icon
	PXY	165,27," Weapons Information "
	move.w	#1,GS_VIEWLEVEL(a6)
	bra	.draw
.icon:	move.w	GS_VIEWINDEX(a6),d0	; showweaponicon(172,89,gunnodes[viewindex],viewindex)
	bsr	dp_gun
	move.w	d1,d2
	move.l	d3,-(sp)
	move.w	GS_VIEWINDEX(a6),d3
	move.w	#172,d0
	moveq	#89,d1
	bsr	showweaponicon
	move.l	(sp)+,d3
	rts
.c3:	cmp.w	#3,d3
	bne.s	.c4
	move.w	GS_VIEWINDEX(a6),d4
	ble	.draw
	subq.w	#1,d4
.u:	tst.w	d4			; while (vi > 0) and (gunnodes[vi] = 0) do dec(vi)
	ble.s	.u1
	move.w	d4,d0
	bsr	dp_gun
	tst.w	d1
	bne.s	.u1
	subq.w	#1,d4
	bra.s	.u
.u1:	tst.w	d4
	bne.s	.set
	moveq	#10,d4
.u2:	tst.w	d4
	ble.s	.set
	move.w	d4,d0
	bsr	dp_gun
	tst.w	d1
	bne.s	.set
	subq.w	#1,d4
	bra.s	.u2
.set:	move.w	d4,GS_VIEWINDEX(a6)
	cmp.w	#1,GS_VIEWLEVEL(a6)
	bne	.draw
	tst.w	d4
	ble	.draw
	bsr	.icon
	bra	.draw
.c4:	cmp.w	#4,d3
	bne.s	.c5
	move.w	GS_VIEWINDEX(a6),d4
	ble	.draw
	addq.w	#1,d4
	bsr	.dn
	cmp.w	#11,d4
	bne.s	.set
	moveq	#1,d4
	bsr	.dn
	cmp.w	#11,d4
	bne.s	.set
	moveq	#0,d4
	bra.s	.set
.dn:	cmp.w	#11,d4			; while (vi < 11) and (gunnodes[vi] = 0) do inc(vi)
	bge.s	.dx
	move.w	d4,d0
	bsr	dp_gun
	tst.w	d1
	bne.s	.dx
	addq.w	#1,d4
	bra.s	.dn
.dx:	rts
.c5:	cmp.w	#5,d3
	bne.s	.draw
	st	d0
	bsr	removerightside
	bsr	mouseshow
	bra	.x
.draw:	tst.w	GS_VIEWLEVEL(a6)
	bne.s	.l1
	moveq	#1,d5			; y
	moveq	#1,d4			; j
.l:	move.w	#5,GS_BKCOLOR(a6)
	cmp.w	GS_VIEWINDEX(a6),d4
	bne.s	.lb
	move.w	#179,GS_BKCOLOR(a6)
.lb:	move.w	d4,d0
	bsr	dp_gun
	tst.w	d1
	beq.s	.ln
	move.w	d1,d0
	bsr	dp_cargoname
	move.w	d5,d1
	mulu	#7,d1
	add.w	#31,d1
	move.w	#167,d0
	bsr	printxy
	addq.w	#1,d5
.ln:	addq.w	#1,d4
	cmp.w	#11,d4
	bne.s	.l
	bra.s	.d
.l1:	cmp.w	#1,GS_VIEWLEVEL(a6)
	bne.s	.d
	move.w	GS_VIEWINDEX(a6),d0
	bsr	dp_gun
	move.w	d1,d0
	bsr	displayweaponstats
.d:	bsr	mouseshow
	BKCOL	3
.x:	movem.l	(sp)+,d3-d5
	rts

; ---------------------------------------------------------------- the viewscreen maps (viewmode2)
; checkscandamages: out d0.w = 1 (Z clear) when the scanners work; else the screen is noise
checkscandamages:
	movem.l	d3-d5,-(sp)
	moveq	#0,d0
	move.b	GS_SHIP+SHIP_DAMAGES+DMG_CPU-1(a6),d0
	cmp.w	#59,d0
	bgt.s	.noise
	move.w	d0,d5
	moveq	#40,d0			; damages[CPU] > 20+random(40)
	bsr	mt_random
	add.w	#20,d0
	cmp.w	d0,d5
	bgt.s	.noise
	moveq	#1,d0
	bra	.x
.noise:	bsr	mousehide
	move.w	GS_GLOWINDEX(a6),d0	; a := glowindex mod 2
	ext.l	d0
	divs	#2,d0
	swap	d0
	move.w	d0,dp_a
	moveq	#0,d3			; i 0..52
.i:	move.w	d3,d4			; row i*2+18+a: random(16) per pixel 28..142
	add.w	d4,d4
	add.w	#18,d4
	add.w	dp_a,d4
	move.w	#28,d5
.j:	moveq	#16,d0
	bsr	mt_random
	move.w	d0,d2
	move.w	d5,d0
	move.w	d4,d1
	bsr	ms_addr
	move.b	d2,(a0)
	addq.w	#1,d5
	cmp.w	#143,d5
	bne.s	.j
	move.w	#28,d0			; row i*2+19-a: 115 in 5
	move.w	d3,d1
	add.w	d1,d1
	add.w	#19,d1
	sub.w	dp_a,d1
	moveq	#115,d2
	move.l	d4,-(sp)
	moveq	#5,d4
	bsr	dp_fill
	move.l	(sp)+,d4
	addq.w	#1,d3
	cmp.w	#53,d3
	bne.s	.i
	move.w	#28,d0
	moveq	#18,d1
	move.w	#142,d2
	move.w	#124,d3
	bsr	ms_dirty
	bsr	mouseshow
	moveq	#0,d0
.x:	movem.l	(sp)+,d3-d5
	tst.w	d0
	rts
; the scans run only if: (damages[CPU] = 0) or checkscandamages.  out: Z set = stop
dp_scanok:
	tst.b	GS_SHIP+SHIP_DAMAGES+DMG_CPU-1(a6)
	beq.s	.ok
	bra	checkscandamages
.ok:	moveq	#1,d0
	rts

; t1 := t1 + 0.049 (if t1 < 0 then t1 := 0 first); if t1 > 6.28: t1 := t1 - 6.28, nearby :=
; nearbybackup  (the rotation of the star and history maps)
dp_rotstep:
	FSSE
	FLDG	GS_T1
	bsr	fp_tst
	bpl.s	.p
	clr.l	GS_T1(a6)
	clr.l	GS_T1+4(a6)
.p:	FX87
	FLDG	GS_T1
	FLDX	gx_0_049
	bsr	fp_add
	FSTG	GS_T1
	FLDG	GS_T1
	FLDX	gx_6_28
	bsr	fp_cmp			; t1 > 6.28 ?
	ble.s	.x
	FLDG	GS_T1
	FLDX	gx_6_28
	bsr	fp_sub
	FSTG	GS_T1
	lea	GS_NEARBYBACKUP(a6),a0
	lea	GS_NEARBY(a6),a1
	move.w	#NEARBYARRAY_SIZEOF/2-1,d0
.c:	move.w	(a0)+,(a1)+
	dbf	d0,.c
.x:	FSSE
	rts
; rotate nearby[a0] by one step (x87) and project it: x1, y1 (GS), d0.w = round(x1), d1.w = round(y1)
dp_rotproj:
	move.l	a3,-(sp)
	move.l	a0,a3
	move.l	NEARBY_X(a3),GS_X1(a6)	; x1 := nearby.x; y1 := nearby.z
	move.l	NEARBY_X+4(a3),GS_X1+4(a6)
	move.l	NEARBY_Z(a3),GS_Y1(a6)
	move.l	NEARBY_Z+4(a3),GS_Y1+4(a6)
	FX87
	FLDG	GS_X1			; nearby.x := 0.99879974*x1 - 0.048980394*y1
	FLDX	gx_0_99879974
	bsr	fp_mul
	FLDG	GS_Y1
	FLDX	gx_0_048980394
	bsr	fp_mul
	bsr	fp_sub
	lea	NEARBY_X(a3),a0
	bsr	fp_std
	FLDG	GS_X1			; nearby.z := 0.048980394*x1 + 0.99879974*y1
	FLDX	gx_0_048980394
	bsr	fp_mul
	FLDG	GS_Y1
	FLDX	gx_0_99879974
	bsr	fp_mul
	bsr	fp_add
	lea	NEARBY_Z(a3),a0
	bsr	fp_std
	move.l	a3,a0
	move.l	(sp)+,a3
	; fall through
; project nearby[a0]: x1 := 85+(x*480/(500-z)); y1 := 70+(y*480/(500-z)) (SSE); d0/d1 = round
dp_project:
	move.l	a3,-(sp)
	move.l	a0,a3
	FSSE
	lea	NEARBY_X(a3),a0
	bsr	fp_ldd
	FLDI	480
	bsr	fp_mul
	FLDI	500
	lea	NEARBY_Z(a3),a0
	bsr	fp_ldd
	bsr	fp_sub
	bsr	fp_div
	FLDI	85
	bsr	fp_add
	FSTG	GS_X1
	lea	NEARBY_Y(a3),a0
	bsr	fp_ldd
	FLDI	480
	bsr	fp_mul
	FLDI	500
	lea	NEARBY_Z(a3),a0
	bsr	fp_ldd
	bsr	fp_sub
	bsr	fp_div
	FLDI	70
	bsr	fp_add
	FSTG	GS_Y1
	FLDG	GS_X1
	bsr	fp_rnd
	move.w	d0,GS_X(a6)
	FLDG	GS_Y1
	bsr	fp_rnd
	move.w	d0,GS_Y(a6)
	move.w	d0,d1
	move.w	GS_X(a6),d0
	move.l	(sp)+,a3
	rts
; the target's circle: if index < 0 then index := 0; cycle index 0..8; project nearby[target];
; setcolor(80+index); circle(x, y, 6)
dp_targetcircle:
	move.l	d4,-(sp)
	bsr	dp_cycle
	move.w	GS_TARGET(a6),d0
	bsr	dp_near
	bsr	dp_project
	moveq	#6,d2
	moveq	#80,d4
	add.w	dp_index,d4
	bsr	ms_circle
	move.l	(sp)+,d4
	rts
dp_cycle:				; if index<0 then index:=0; if index>7 then index:=0 else inc(index)
	move.w	dp_index,d0
	bpl.s	.p
	moveq	#0,d0
.p:	cmp.w	#7,d0
	ble.s	.i
	moveq	#-1,d0
.i:	addq.w	#1,d0
	move.w	d0,dp_index
	rts
; starmapscreen^[y,x] := c (y 18..123, x 27..143: offset (y-18)*117 + x-27, as the original's)
dp_smpset:
	sub.w	#18,d1
	mulu	#117,d1
	sub.w	#27,d0
	ext.l	d0
	add.l	d0,d1
	move.l	GS_STARMAPSCREEN(a6),a0
	move.b	d2,0(a0,d1.l)
	rts
; scrto_move(starmapscreen^[i,27], screen[i,27], 116) for i := 18 to 123
dp_smcopy:
	move.l	GS_STARMAPSCREEN(a6),a1
	moveq	#27,d0
	moveq	#18,d1
	bsr	ms_addr
	moveq	#106-1,d1
.r:	moveq	#116-1,d0
	move.l	a0,a2
	move.l	a1,-(sp)
.c:	move.b	(a1)+,(a2)+
	dbf	d0,.c
	move.l	(sp)+,a1
	lea	117(a1),a1
	lea	MS_W(a0),a0
	dbf	d1,.r
	move.l	d3,-(sp)
	moveq	#27,d0
	moveq	#18,d1
	move.w	#142,d2
	moveq	#123,d3
	bsr	ms_dirty
	move.l	(sp)+,d3
	rts

displaystarmap:
	movem.l	d3-d5/a3,-(sp)
	bsr	dp_scanok
	beq	.x
	move.l	GS_STARMAPSCREEN(a6),a0	; fillchar(starmapscreen^, 12402, 5)
	move.w	#12402/2-1,d0
.f:	move.w	#$0505,(a0)+
	dbf	d0,.f
	bsr	dp_rotstep
	moveq	#1,d3			; j
.j:	move.w	d3,d0
	bsr	dp_near
	tst.w	NEARBY_INDEX(a0)
	beq	.n
	move.l	a0,a3
	bsr	dp_rotproj
	move.w	NEARBY_INDEX(a3),d0	; colours by systems[].mode (others keep c1, c2)
	bsr	dp_sys
	move.b	SYSTEM_MODE(a0),d0
	cmp.b	#1,d0
	bne.s	.m2
	move.w	#127,dp_c1
	move.w	#118,dp_c2
	bra.s	.m
.m2:	cmp.b	#2,d0
	bne.s	.m3
	move.w	#95,dp_c1
	move.w	#86,dp_c2
	bra.s	.m
.m3:	cmp.b	#3,d0
	bne.s	.m
	move.w	#31,dp_c1
	move.w	#12,dp_c2
.m:	move.w	GS_X(a6),d4
	move.w	GS_Y(a6),d5
	move.w	d4,d0
	move.w	d5,d1
	move.w	dp_c1,d2
	bsr	dp_smpset
	move.w	d4,d0
	move.w	d5,d1
	addq.w	#1,d1
	move.w	dp_c2,d2
	bsr	dp_smpset
	move.w	d4,d0
	move.w	d5,d1
	subq.w	#1,d1
	move.w	dp_c2,d2
	bsr	dp_smpset
	move.w	d4,d0
	addq.w	#1,d0
	move.w	d5,d1
	move.w	dp_c2,d2
	bsr	dp_smpset
	move.w	d4,d0
	subq.w	#1,d0
	move.w	d5,d1
	move.w	dp_c2,d2
	bsr	dp_smpset
.n:	addq.w	#1,d3
	cmp.w	#NEARBYMAX_+1,d3
	bne	.j
	bsr	mousehide
	bsr	dp_smcopy
	tst.w	GS_TARGET(a6)
	ble.s	.nt
	bsr	dp_targetcircle
.nt:	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d5/a3
	rts

displayhistorymap:
	movem.l	d3-d5/a3,-(sp)
	bsr	dp_scanok
	beq	.x
	bsr	dp_cycle
	bsr	dp_rotstep
	bsr	mousehide
	BAR	27,18,142,123,5
	clr.w	dp_i
	moveq	#1,d3
.j:	move.w	d3,d0
	bsr	dp_near
	tst.w	NEARBY_INDEX(a0)
	beq.s	.n
	move.l	a0,a3
	bsr	dp_rotproj
	move.w	NEARBY_INDEX(a3),d0
	bsr	dp_sys
	tst.w	SYSTEM_VISITS(a0)
	beq.s	.pt
	moveq	#80,d4
	add.w	dp_index,d4
	move.w	GS_X(a6),d0
	move.w	GS_Y(a6),d1
	tst.w	dp_i
	bne.s	.lt
	bsr	ms_moveto
	move.w	#1,dp_i
	bra.s	.pt
.lt:	bsr	ms_lineto
.pt:	move.w	GS_X(a6),d0
	move.w	GS_Y(a6),d1
	moveq	#22,d2
	bsr	ms_pset
.n:	addq.w	#1,d3
	cmp.w	#NEARBYMAX_+1,d3
	bne.s	.j
	tst.w	GS_TARGET(a6)
	ble.s	.nt
	move.w	GS_TARGET(a6),d0	; (index already cycled above: just the circle)
	bsr	dp_near
	bsr	dp_project
	moveq	#6,d2
	moveq	#80,d4
	add.w	dp_index,d4
	bsr	ms_circle
.nt:	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d5/a3
	rts

; the planet icon column for tempplan^[a0] (displayshortscan / displaysystem): out d0.w = a
; (randseed := seed; the original's case on state/mode/psize)
dp_planicon:
	movem.l	d3/a3,-(sp)
	move.l	a0,a3
	moveq	#0,d0			; randseed := seed (a word)
	move.w	PLANET_SEED(a3),d0
	bsr	mt_seed
	moveq	#0,d3
	move.b	PLANET_STATE(a3),d3
	bne.s	.s15
	cmp.b	#1,PLANET_MODE(a3)	; 0: gas
	bne.s	.s0b
	moveq	#3,d0
	bsr	mt_random
	mulu	#10,d0
	bra	.x
.s0b:	cmp.b	#3,PLANET_MODE(a3)
	bhi	.keep
	move.b	PLANET_PSIZE(a3),d1
	cmp.b	#1,d1
	bhi.s	.s0c
	move.w	#170,d0
	bra	.x
.s0c:	cmp.b	#3,d1
	bhi.s	.s0d
	moveq	#3,d0
	bsr	mt_random
	mulu	#10,d0
	add.w	#250,d0
	bra	.x
.s0d:	cmp.b	#4,d1
	bne	.keep
	moveq	#2,d0
	bsr	mt_random
	mulu	#10,d0
	add.w	#150,d0
	bra	.x
.s15:	cmp.w	#5,d3
	bhi.s	.s6
	move.b	PLANET_PSIZE(a3),d1
	moveq	#0,d2
	move.b	PLANET_WATER(a3),d2
	cmp.b	#1,d1
	bhi.s	.s1c
	move.w	#190,d0
	cmp.w	#25,d2
	ble	.x
	move.w	#180,d0
	bra	.x
.s1c:	cmp.b	#3,d1
	bhi.s	.s1d
	divu	#10,d2			; 240-(water div 10)*10
	mulu	#10,d2
	move.w	#240,d0
	sub.w	d2,d0
	bra	.x
.s1d:	cmp.b	#4,d1
	bne.s	.keep
	divu	#7,d2			; 140-(water div 7)*10
	mulu	#10,d2
	move.w	#140,d0
	sub.w	d2,d0
	bra.s	.x
.s6:	cmp.w	#6,d3
	bne.s	.s7
	cmp.b	#1,PLANET_MODE(a3)
	bne.s	.s6r
	move.b	PLANET_PSIZE(a3),d1
	move.w	#180,d0
	cmp.b	#1,d1
	bls.s	.x
	move.w	#200,d0
	cmp.b	#3,d1
	bls.s	.x
	moveq	#80,d0
	cmp.b	#4,d1
	beq.s	.x
	bra.s	.keep
.s6r:	moveq	#3,d0
	bsr	mt_random
	mulu	#10,d0
	bra.s	.x
.s7:	cmp.w	#7,d3
	bne.s	.z
	move.b	PLANET_MODE(a3),d1
	moveq	#60,d0
	cmp.b	#1,d1
	beq.s	.x
	moveq	#50,d0
	cmp.b	#2,d1
	beq.s	.x
	moveq	#70,d0
	cmp.b	#3,d1
	beq.s	.x
.keep:	move.w	dp_a,d0			; (no case matched: a keeps its value)
	bra.s	.x
.z:	moveq	#0,d0			; else a := 0
.x:	move.w	d0,dp_a
	movem.l	(sp)+,d3/a3
	rts
; draw planicons^[i, a+b] (10x10, non-zero pixels) at (d0 x, d1 y), a = dp_a
dp_planicon_put:
	movem.l	d3-d5,-(sp)
	move.w	d0,d4
	move.w	d1,d5
	move.l	GS_PLANICONS(a6),a1	; planicons^: array[0..9, 0..319] of byte
	add.w	dp_a,a1
	moveq	#0,d3			; i (row)
.i:	move.w	d4,d0
	move.w	d5,d1
	add.w	d3,d1
	bsr	ms_addr
	moveq	#0,d2			; b
.b:	move.b	0(a1,d2.w),d0
	beq.s	.n
	move.b	d0,0(a0,d2.w)
.n:	addq.w	#1,d2
	cmp.w	#10,d2
	bne.s	.b
	lea	320(a1),a1
	addq.w	#1,d3
	cmp.w	#10,d3
	bne.s	.i
	move.w	d4,d0
	move.w	d5,d1
	move.w	d4,d2
	add.w	#9,d2
	move.w	d5,d3
	add.w	#9,d3
	bsr	ms_dirty
	movem.l	(sp)+,d3-d5
	rts

; ar := x/sin(arctan(x/z)); br := ar/2; t2 := arctan(z/(2*x)): from integer x d0, z d1 (the
; scans; GS_X, GS_Z must hold the same x, z for the t2 half). Exactly FPC's: x/z by SSE, fpatan
; and fsin, then x / that on the x87; br by SSE; z/(2*x) by SSE, fpatan.
dp_ellipse:
	bsr.s	dp_ellipse_ab
	bra.s	dp_ellipse_t2
dp_ellipse_ab:
	move.w	d1,-(sp)
	move.w	d0,-(sp)
	FSSE
	bsr	fp_ldw
	move.w	2(sp),d0
	bsr	fp_ldw
	bsr	fp_div
	bsr	fp_atan
	bsr	fp_sin
	FX87
	move.w	(sp),d0
	bsr	fp_ldw
	bsr	fp_divr			; x / sin(...)
	FSTG	GS_AR
	FSSE
	FLDG	GS_AR
	FLDI	2
	bsr	fp_div
	FSTG	GS_BR
	addq.l	#4,sp
	rts
dp_ellipse_t2:
	FSSE
	move.w	GS_Z(a6),d0
	bsr	fp_ldw
	move.w	GS_X(a6),d0
	ext.l	d0
	add.l	d0,d0
	bsr	fp_ldi
	bsr	fp_div
	bsr	fp_atan
	FSTG	GS_T2
	rts
; computegraph's signaly from dist d3, tech d4 (all SSE)
dp_signaly:
	FSSE
	move.w	d4,d0
	bsr	fp_ldw
	FLDI	30
	bsr	fp_div
	move.w	d4,d0
	bsr	fp_ldw
	FLDI	30
	bsr	fp_div
	bsr	fp_mul
	bsr	fp_rnd
	bsr	fp_ldi
	moveq	#9,d0
	sub.w	d3,d0
	bsr	fp_ldw
	FLDI	7
	bsr	fp_div
	bsr	fp_mul
	moveq	#0,d0
	move.b	GS_SHIP+SHIP_CREW+2*CREW_SIZEOF+CREW_LEVEL(a6),d0
	bsr	fp_ldi
	bsr	fp_mul
	bra	fp_rnd
; round((tech d0 - 40)/30*98)
dp_signalx:
	FSSE
	sub.w	#40,d0
	bsr	fp_ldw
	FLDI	30
	bsr	fp_div
	FLDI	98
	bsr	fp_mul
	bra	fp_rnd

; x1 := 85 + (ar*cos(t1+t2))/d0 ; y1 := 70 + (br*sin(t1+t2)+y)/514 (x87, t1+t2 by SSE);
; x, y := round; out d0/d1
dp_scanpos:
	move.w	d0,-(sp)
	FSSE
	FLDG	GS_T1
	FLDG	GS_T2
	bsr	fp_add
	lea	dp_tmpd,a0
	bsr	fp_std
	FX87
	lea	dp_tmpd,a0
	bsr	fp_ldd
	bsr	fp_cos
	FLDG	GS_AR
	bsr	fp_mul
	move.w	(sp)+,d0
	bsr	fp_ldw
	bsr	fp_div
	FLDI	85
	bsr	fp_add
	FSTG	GS_X1
	lea	dp_tmpd,a0
	bsr	fp_ldd
	bsr	fp_sin
	FLDG	GS_BR
	bsr	fp_mul
	move.w	GS_Y(a6),d0
	bsr	fp_ldw
	bsr	fp_add
	FLDI	514
	bsr	fp_div
	FLDI	70
	bsr	fp_add
	FSTG	GS_Y1
	FSSE
	FLDG	GS_X1
	bsr	fp_rnd
	move.w	d0,GS_X(a6)
	FLDG	GS_Y1
	bsr	fp_rnd
	move.w	d0,GS_Y(a6)
	move.w	d0,d1
	move.w	GS_X(a6),d0
	rts

displayshortscan:
	movem.l	d3-d5/a3,-(sp)
	bsr	dp_scanok
	beq	.x
	FX87				; t1 := t1 + 0.02; if t1 > 6.28 then t1 := 0
	FLDG	GS_T1
	FLDX	gx_0_02
	bsr	fp_add
	FSTG	GS_T1
	FLDG	GS_T1
	FLDX	gx_6_28
	bsr	fp_cmp
	ble.s	.t
	clr.l	GS_T1(a6)
	clr.l	GS_T1+4(a6)
.t:	FSSE
	bsr	mousehide
	BAR	27,18,143,123,5
	tst.b	GS_SHOWPLANET(a6)
	beq	.alien
	move.w	GS_CURPLAN(a6),d0	; the planet
	move.w	d0,dp_j
	bsr	dp_plan
	move.l	a0,a3
	moveq	#0,d0			; x := (psize+1)*2000; y := 0; z := (orbit+1)*2000
	move.b	PLANET_PSIZE(a3),d0
	addq.w	#1,d0
	mulu	#2000,d0
	move.w	d0,GS_X(a6)
	clr.w	GS_Y(a6)
	moveq	#0,d1
	move.b	PLANET_ORBIT(a3),d1
	addq.w	#1,d1
	mulu	#2000,d1
	move.w	d1,GS_Z(a6)
	bsr	dp_ellipse
	move.w	#370,d0
	bsr	dp_scanpos
	move.w	d0,d4
	move.w	d1,d5
	move.l	a3,a0
	bsr	dp_planicon
	move.w	d4,d0
	move.w	d5,d1
	bsr	dp_planicon_put
.alien:	move.w	#39,dp_j		; j := 39 (88 when the alien is close)
	cmp.w	#16000,GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6)
	bge	.ring
	lea	GS_SHIP+SHIP_WANDERING(a6),a3
	move.w	ONEALIEN_RELX(a3),d0
	move.w	d0,GS_X(a6)
	move.w	ONEALIEN_RELY(a3),d1
	move.w	d1,GS_Y(a6)
	move.w	ONEALIEN_RELZ(a3),d2
	move.w	d2,GS_Z(a6)
	bsr	.abs3
	cmp.w	#8000,d0
	bgt	.ring
	cmp.w	#8000,d1
	bgt	.ring
	cmp.w	#8000,d2
	bgt	.ring
	cmp.w	#3000,d0
	bge.s	.far
	cmp.w	#3000,d1
	bge.s	.far
	cmp.w	#3000,d2
	bge.s	.far
	move.w	#88,dp_j
.far:	tst.w	GS_Z(a6)		; if z = 0 then goto error
	beq	.ring
	move.w	GS_X(a6),d0		; ar := x/sin(arctan(x/z)); br := ar/2
	move.w	GS_Z(a6),d1
	bsr	dp_ellipse_ab
	tst.w	GS_X(a6)		; if x = 0 then goto error
	beq	.ring
	bsr	dp_ellipse_t2
	move.w	#380,d0
	bsr	dp_scanpos
	move.w	d0,d4
	move.w	d1,d5
	move.w	d4,d0
	move.w	d5,d1
	moveq	#95,d2
	bsr	ms_pset
	lea	dp_alienpix,a3		; the six 63s around it
	moveq	#6-1,d3
.ap:	move.w	d4,d0
	add.w	(a3)+,d0
	move.w	d5,d1
	add.w	(a3)+,d1
	moveq	#63,d2
	bsr	ms_pset
	dbf	d3,.ap
.ring:	bsr	dp_cycle		; the ring: circle(85,70, |round(x1)-85|) for x = z = 5000
	move.w	#5000,GS_X(a6)
	clr.w	GS_Y(a6)
	move.w	#5000,GS_Z(a6)
	move.w	#5000,d0
	move.w	#5000,d1
	bsr	dp_ellipse
	FSSE				; x1 := 85+(ar*cos(t1+t2))/360 (x87)
	FLDG	GS_T1
	FLDG	GS_T2
	bsr	fp_add
	lea	dp_tmpd,a0
	bsr	fp_std
	FX87
	lea	dp_tmpd,a0
	bsr	fp_ldd
	bsr	fp_cos
	FLDG	GS_AR
	bsr	fp_mul
	FLDI	360
	bsr	fp_div
	FLDI	85
	bsr	fp_add
	FSTG	GS_X1
	FSSE
	FLDG	GS_X1
	bsr	fp_rnd
	move.w	d0,GS_X(a6)
	sub.w	#85,d0
	bpl.s	.ab
	neg.w	d0
.ab:	move.w	d0,d2
	moveq	#85,d0
	moveq	#70,d1
	move.w	dp_j,d4
	add.w	dp_index,d4
	bsr	ms_circle
	bsr	mouseshow
	BKCOL	3
.x:	movem.l	(sp)+,d3-d5/a3
	rts
.abs3:	tst.w	d0
	bpl.s	.a1
	neg.w	d0
.a1:	tst.w	d1
	bpl.s	.a2
	neg.w	d1
.a2:	tst.w	d2
	bpl.s	.a3
	neg.w	d2
.a3:	rts
; display.pas computegraph: the long range scan's signal graph
computegraph:
	movem.l	d3-d6,-(sp)
	moveq	#9,d3			; dist
	lea	GS_SHIP+SHIP_WANDERING(a6),a0
	cmp.w	#16000,ONEALIEN_ALIENID(a0)
	bge.s	.d
	move.w	ONEALIEN_RELX(a0),d3	; max of relx, rely, relz (signed)
	cmp.w	ONEALIEN_RELY(a0),d3
	bge.s	.d1
	move.w	ONEALIEN_RELY(a0),d3
.d1:	cmp.w	ONEALIEN_RELZ(a0),d3
	bge.s	.d2
	move.w	ONEALIEN_RELZ(a0),d3
.d2:	FSSE				; dist := round(dist/2560)
	move.w	d3,d0
	bsr	fp_ldw
	FLDI	2560
	bsr	fp_div
	bsr	fp_rnd
	move.w	d0,d3
.d:	move.w	GS_SHIP+SHIP_WANDERING+ONEALIEN_TECHLEVEL(a6),d0	; tech := hi*10 + lo
	move.w	d0,d4
	lsr.w	#8,d4
	mulu	#10,d4
	and.w	#$ff,d0
	add.w	d0,d4
	; signaly := round((round((tech/30)*(tech/30)))*((9-dist)/7)*ship.crew[3].level)
	bsr	dp_signaly
	move.w	d0,d5
	moveq	#0,d6			; noise
	tst.b	GS_SHOWPLANET(a6)
	beq.s	.nz
	move.w	GS_CURPLAN(a6),d0
	bsr	dp_plan
	moveq	#0,d0
	move.b	PLANET_ORBIT(a0),d0
	moveq	#18,d6
	tst.w	d0
	beq.s	.nz
	lea	dp_noise,a0		; round(exp(abs(orbit-6))/10) by orbit
	move.b	0(a0,d0.w),d6
.nz:	cmp.w	#9,d5
	ble.s	.s9
	moveq	#9,d5
.s9:	move.w	d4,d0			; signalx := round((tech-40)/30*98), at most 98
	bsr	dp_signalx
	cmp.w	#98,d0
	ble.s	.sx
	moveq	#98,d0
.sx:	move.w	d0,dp_sx
	moveq	#36,d4			; for j := 36 to 134: screen[34-random(noise)+round(noise/2), j] := 28
.j:	move.w	d6,d0
	bsr	dp_random		; random(noise) (random(0) = 0)
	moveq	#34,d1
	sub.w	d0,d1
	move.w	d6,d0			; round(noise/2): banker's
	lsr.w	#1,d0
	btst	#0,d6
	beq.s	.r
	btst	#0,d0
	beq.s	.r
	addq.w	#1,d0
.r:	add.w	d0,d1
	move.w	d4,d0
	moveq	#28,d2
	bsr	ms_pset
	addq.w	#1,d4
	cmp.w	#135,d4
	bne.s	.j
	cmp.w	#16000,GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6)
	bge.s	.x
	moveq	#34,d1			; screen[34-signaly, signalx+36] := 31
	sub.w	d5,d1
	move.w	dp_sx,d0
	add.w	#36,d0
	moveq	#31,d2
	bsr	ms_pset
.x:	movem.l	(sp)+,d3-d6
	rts
dp_random:				; random(d0.w) with the generator's l = 0 case (0, one draw)
	bra	mt_random

displaylongscan:
	movem.l	d3-d5,-(sp)
	bsr	dp_scanok
	beq	.x
	bsr	mousehide
	bsr	dp_smcopy
	bsr	computegraph
	bsr	mouseshow
	moveq	#3-1,d3			; three random dots
.d:	move.w	#23000,d0
	bsr	mt_random
	move.w	d0,GS_X(a6)
	move.w	#23000,d0
	bsr	mt_random
	move.w	d0,GS_Y(a6)
	move.w	#23000,d0
	bsr	mt_random
	move.w	d0,GS_Z(a6)
	move.w	GS_X(a6),d0		; x := round((x+z)*0.0006)  (x87)
	ext.l	d0			; (x+z: a longint sum, as FPC evaluates it)
	move.w	GS_Z(a6),d1
	ext.l	d1
	add.l	d1,d0
	lea	gx_0_0006,a0
	bsr	dp_rndmul
	move.w	d0,GS_X(a6)
	move.w	GS_Y(a6),d0
	ext.l	d0			; (x+z: a longint sum, as FPC evaluates it)
	move.w	GS_Z(a6),d1
	ext.l	d1
	add.l	d1,d0
	lea	gx_0_0006,a0
	bsr	dp_rndmul
	move.w	d0,GS_Y(a6)
	moveq	#8,d0
	bsr	mt_random
	addq.w	#5,d0
	move.w	d0,d2
	move.w	GS_X(a6),d0
	add.w	#85,d0
	move.w	GS_Y(a6),d1
	add.w	#86,d1
	bsr	ms_pset
	dbf	d3,.d
	lea	GS_SHIP+SHIP_WANDERING(a6),a0
	cmp.w	#16000,ONEALIEN_ALIENID(a0)
	bge.s	.x
	move.w	ONEALIEN_RELX(a0),GS_X(a6)
	move.w	ONEALIEN_RELY(a0),GS_Y(a6)
	move.w	ONEALIEN_RELZ(a0),GS_Z(a6)
	move.w	GS_X(a6),d0
	ext.l	d0			; (x+z: a longint sum, as FPC evaluates it)
	move.w	GS_Z(a6),d1
	ext.l	d1
	add.l	d1,d0
	lea	gx_0_0007,a0
	bsr	dp_rndmul
	move.w	d0,GS_X(a6)
	move.w	GS_Y(a6),d0
	ext.l	d0			; (x+z: a longint sum, as FPC evaluates it)
	move.w	GS_Z(a6),d1
	ext.l	d1
	add.l	d1,d0
	lea	gx_0_0007,a0
	bsr	dp_rndmul
	move.w	d0,GS_Y(a6)
	moveq	#8,d0			; starmapscreen^[86+y, 85+x] := random(8)+7
	bsr	mt_random
	addq.w	#7,d0
	move.w	d0,d2
	move.w	GS_X(a6),d0
	add.w	#85,d0
	move.w	GS_Y(a6),d1
	add.w	#86,d1
	bsr	dp_smpset
.x:	movem.l	(sp)+,d3-d5
	rts
; d0.w := round(d0.l * extended constant at a0)  (x87)
dp_rndmul:
	move.l	a0,-(sp)
	FX87
	bsr	fp_ldi
	move.l	(sp)+,a0
	bsr	fp_ldx
	bsr	fp_mul
	bsr	fp_rnd
	FSSE
	rts

; ---------------------------------------------------------------- system info (viewmode 3)
; push r = sqrt(sqr(dx/10)+sqr(dy/10)+sqr(dz/10)) (SSE), dx d0, dy d1, dz d2 (words)
dp_dist:
	movem.w	d0-d2,-(sp)
	FSSE
	bsr	fp_ldw
	FLDI	10
	bsr	fp_div
	bsr	fp_sqr
	move.w	2(sp),d0
	bsr	fp_ldw
	FLDI	10
	bsr	fp_div
	bsr	fp_sqr
	bsr	fp_add
	move.w	4(sp),d0
	bsr	fp_ldw
	FLDI	10
	bsr	fp_div
	bsr	fp_sqr
	bsr	fp_add
	bsr	fp_sqrt
	addq.l	#6,sp
	rts
; the date "mm/yyyyy" of a datem d0.w, datey d1.w into dp_s2 (months with a leading 0; the year
; :5 with a leading 0 below 10000)
dp_date:
	move.w	d1,-(sp)
	bsr	dp_str2z
	lea	dp_s2,a0
	lea	dp_s,a1
	bsr	pstr_cpy
	lea	dp_s2,a0
	lea	dp_t_slash,a1
	bsr	pstr_cat
	move.w	(sp),d0
	ext.l	d0
	moveq	#5,d1
	bsr	dp_str
	cmp.w	#10000,(sp)+
	bge.s	.y
	move.b	#'0',dp_s+1
.y:	lea	dp_s2,a0
	lea	dp_s,a1
	bra	pstr_cat

; display.pas genericsysinfo(n d0)
genericsysinfo:
	movem.l	d3/a3,-(sp)
	bsr	dp_sys
	move.l	a0,a3
	move.w	SYSTEM_X(a3),GS_X(a6)
	move.w	SYSTEM_Y(a3),GS_Y(a6)
	move.w	SYSTEM_Z(a3),GS_Z(a6)
	FSSE				; x1 := x/10; y1 := y/10; z1 := z/10; str(..:3:0)
	move.w	GS_X(a6),d0
	bsr	fp_ldw
	FLDI	10
	bsr	fp_div
	FSTG	GS_X1
	move.w	GS_Y(a6),d0
	bsr	fp_ldw
	FLDI	10
	bsr	fp_div
	FSTG	GS_Y1
	lea	dp_s2,a0		; str1+','+str2+','+str3 in dp_s2
	clr.b	(a0)
	FLDG	GS_X1
	bsr	.s30
	lea	dp_t_comma,a1
	lea	dp_s2,a0
	bsr	pstr_cat
	FLDG	GS_Y1
	bsr	.s30
	lea	dp_t_comma,a1
	lea	dp_s2,a0
	bsr	pstr_cat
	move.w	GS_Z(a6),d0
	bsr	fp_ldw
	FLDI	10
	bsr	fp_div
	bsr	.s30
	move.w	GS_X(a6),d0		; x := x-posx ... ; r
	sub.w	GS_SHIP+SHIP_POSX(a6),d0
	move.w	d0,GS_X(a6)
	move.w	GS_Y(a6),d1
	sub.w	GS_SHIP+SHIP_POSY(a6),d1
	move.w	d1,GS_Y(a6)
	move.w	GS_Z(a6),d2
	sub.w	GS_SHIP+SHIP_POSZ(a6),d2
	move.w	d2,GS_Z(a6)
	bsr	dp_dist
	bsr	fp_dup
	bsr	fp_tst
	bne.s	.r
	bsr	fp_pop
	lea	dp_s3,a0
	lea	dp_t_000,a1
	bsr	pstr_cpy
	bra.s	.p
.r:	moveq	#6,d0
	moveq	#2,d1
	lea	dp_s3,a0
	bsr	fp_str
.p:	PXY	167,37,"Location"
	PXYS	214,37,dp_s2
	PXY	167,43,"Distance"
	PXY	164,49,"Star Type"
	PXY	162,55,"Last Visit"
	PXY	172,61,"Visits"
	PXY	169,67,"Planets"
	PXY	172,73,"Sector"
	PXY	163,83,"Notes:"
	PXYS	239,43,dp_s3
	move.b	SYSTEM_MODE(a3),d0
	cmp.b	#1,d0
	bne.s	.m2
	PXY	215,49," Earth Type"
	bra.s	.m
.m2:	cmp.b	#2,d0
	bne.s	.m3
	PXY	215,49,"  Red Giant"
	bra.s	.m
.m3:	cmp.b	#3,d0
	bne.s	.m
	PXY	215,49,"White Dwarf"
.m:	tst.w	SYSTEM_DATEY(a3)
	bne.s	.dt
	PXY	230,55,"   Never"
	bra.s	.v
.dt:	moveq	#0,d0
	move.b	SYSTEM_DATEM(a3),d0
	move.w	SYSTEM_DATEY(a3),d1
	bsr	dp_date
	PXYS	230,55,dp_s2
.v:	move.w	SYSTEM_VISITS(a3),d0
	bne.s	.vn
	PXY	250,61,"None"
	bra.s	.pl
.vn:	ext.l	d0
	moveq	#3,d1
	bsr	dp_str
	PXYS	255,61,dp_s
.pl:	tst.w	SYSTEM_VISITS(a3)
	beq.s	.unk
	moveq	#0,d0
	move.b	SYSTEM_NUMPLANETS(a3),d0
	subq.l	#1,d0
	moveq	#3,d1
	bsr	dp_str
	PXYS	255,67,dp_s
	bra.s	.sec
.unk:	PXY	235,67,"Unknown"
.sec:	moveq	#0,d0			; j := 1 + 1/2/4 for x/y/z > 1250
	cmp.w	#1250,SYSTEM_X(a3)
	ble.s	.s1
	addq.w	#1,d0
.s1:	cmp.w	#1250,SYSTEM_Y(a3)
	ble.s	.s2
	addq.w	#2,d0
.s2:	cmp.w	#1250,SYSTEM_Z(a3)
	ble.s	.s3
	addq.w	#4,d0
.s3:	mulu	#8,d0
	lea	dp_sectors,a0
	add.w	d0,a0
	move.w	#235,d0			; 270 - 7*5
	moveq	#73,d1
	bsr	printxy
	LINE	217,37,217,79,2
	LINE	166,80,278,80,2
	LINE	218,37,218,79,10
	LINE	166,81,278,81,10
	PSET	217,36,6
	PSET	165,80,6
	PSET	218,80,6
	PSET	279,81,6
	movem.l	(sp)+,d3/a3
	rts
.s30:	moveq	#3,d0			; pop -> str(:3:0), appended to dp_s2
	moveq	#0,d1
	lea	dp_s,a0
	bsr	fp_str
	lea	dp_s2,a0
	lea	dp_s,a1
	bra	pstr_cat

; one row of the nearby list: system nearby[d0] at row y d1 (name, distance; red when out of fuel)
dp_sysrow:
	movem.l	d3-d4/a3,-(sp)
	move.w	d1,d4
	bsr	dp_near
	move.w	NEARBY_INDEX(a0),d0
	bsr	dp_sys
	move.l	a0,a3
	move.w	SYSTEM_X(a3),d0		; x, y2, z: the distance
	sub.w	GS_SHIP+SHIP_POSX(a6),d0
	move.w	d0,GS_X(a6)
	move.w	SYSTEM_Y(a3),d1
	sub.w	GS_SHIP+SHIP_POSY(a6),d1
	move.w	SYSTEM_Z(a3),d2
	sub.w	GS_SHIP+SHIP_POSZ(a6),d2
	move.w	d2,GS_Z(a6)
	bsr	dp_dist
	bsr	fp_dup
	lea	dp_s3,a0
	moveq	#6,d0
	moveq	#2,d1
	bsr	fp_str
	move.l	a3,a0
	move.w	#163,d0
	move.w	d4,d1
	bsr	printxy
	move.w	GS_SHIP+SHIP_FUEL(a6),d0	; r > fuel: tcolor 16
	bsr	fp_ldw
	bsr	fp_cmp
	ble.s	.ok
	TCOL	16
	bra.s	.c
.ok:	TCOL	31
.c:	BKCOL	5
	lea	dp_s3,a0
	move.w	#239,d0
	move.w	d4,d1
	bsr	printxy
	movem.l	(sp)+,d3-d4/a3
	rts

displaysysteminfo:
	movem.l	d3-d5,-(sp)
	move.w	d0,d3
	bsr	mousehide
	tst.w	GS_TARGET(a6)
	bne.s	.c0
	cmp.w	#1,GS_VIEWLEVEL(a6)
	bne.s	.c0
	moveq	#1,d3
.c0:	cmp.w	#1,d3
	bne.s	.c2
	tst.w	GS_VIEWLEVEL(a6)
	ble	.draw
	bsr	dp_clear
	PSET	165,80,10
	PSET	279,81,2
	PSET	217,36,10
	subq.w	#1,GS_VIEWLEVEL(a6)
	TCOL	191
	BKCOL	5
	PXY	166,27,"  System        Dist"
	bra	.draw
.c2:	cmp.w	#2,d3
	bne.s	.c3
	tst.w	GS_VIEWLEVEL(a6)
	bne	.draw
	tst.w	GS_TARGET(a6)
	ble	.draw
	addq.w	#1,GS_VIEWLEVEL(a6)
	bsr	dp_clear
	TCOL	191
	BKCOL	5
	PXY	166,27," System Information "
	bra	.draw
.c3:	cmp.w	#3,d3
	bne.s	.c4
	move.w	GS_TARGET(a6),d4
	bgt.s	.u
	move.w	#1,GS_TARGET(a6)
	bra	.draw
.u:	cmp.w	#1,d4
	bne.s	.u2
	moveq	#NEARBYMAX_+1,d4	; from the end: the last that has a system
.u1:	subq.w	#1,d4
	move.w	d4,d0
	bsr	dp_near
	tst.w	NEARBY_INDEX(a0)
	beq.s	.u1
	bra.s	.u3
.u2:	subq.w	#1,d4
.u3:	move.w	d4,GS_TARGET(a6)
	cmp.w	#1,GS_VIEWLEVEL(a6)
	bne	.draw
	bsr	dp_clear
	bra	.draw
.c4:	cmp.w	#4,d3
	bne.s	.c5
	move.w	GS_TARGET(a6),d4
	bgt.s	.d
	move.w	#1,GS_TARGET(a6)
	bra	.draw
.d:	addq.w	#1,d4
	cmp.w	#NEARBYMAX_,d4
	bgt.s	.d1
	move.w	d4,d0
	bsr	dp_near
	tst.w	NEARBY_INDEX(a0)
	bne.s	.u3
.d1:	moveq	#1,d4
	bra.s	.u3
.c5:	cmp.w	#5,d3
	bne.s	.c6
	st	d0
	bsr	removerightside
	bsr	mouseshow
	bra	.x
.c6:	cmp.w	#6,d3
	bne.s	.c7
	tst.w	GS_TARGET(a6)
	ble	.draw
	bsr	readytarget
	bsr	readysysteminfo
	bra	.draw
.c7:	cmp.w	#7,d3
	bne.s	.c8
	tst.b	GS_TARGETREADY(a6)
	beq	.draw
	bsr	mouseshow
	move.w	GS_TARGET(a6),d0
	bsr	dp_near
	move.w	NEARBY_INDEX(a0),d0
	bsr	dp_sys
	move.w	SYSTEM_X(a0),d0
	move.w	SYSTEM_Y(a0),d1
	move.w	SYSTEM_Z(a0),d2
	bsr	engage
	bra	.x
.c8:	cmp.w	#8,d3
	bne.s	.draw
	bsr	mouseshow
	PLEA	"Print all planet info?"
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq.s	.c8n
	bsr	printinfo		; (print.s: TEMP\LPT1)
.c8n:	bsr	mousehide
.draw:	TCOL	191
	BKCOL	5
	tst.w	GS_VIEWLEVEL(a6)
	bne	.l1
	tst.w	GS_TARGET(a6)
	bne.s	.t1
	move.w	#1,GS_TARGET(a6)
.t1:	move.w	GS_TARGET(a6),d4	; the ones after the target
	addq.w	#1,d4
	moveq	#7,d5
.af:	move.w	d4,d0
	bsr	dp_near
	tst.w	NEARBY_INDEX(a0)
	beq.s	.afn
	addq.w	#1,d5
	bsr	.bk
	move.w	d4,d0
	move.w	d5,d1
	mulu	#6,d1
	add.w	#31,d1
	bsr	.row
.afn:	addq.w	#1,d4
	cmp.w	#NEARBYMAX_,d4
	bgt.s	.af2
	cmp.w	#13,d5
	bne.s	.af
.af2:	move.w	d4,dp_index
	cmp.w	#13,d5
	bge.s	.bf
	move.w	d5,d1
	mulu	#6,d1
	add.w	#38,d1
	movem.l	d3-d4,-(sp)
	move.w	#166,d0
	move.w	#278,d2
	moveq	#116,d3
	moveq	#5,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
.bf:	move.w	GS_TARGET(a6),d4	; the target and the ones before
	moveq	#8,d5
.bl:	move.w	d4,d0
	bsr	dp_near
	tst.w	NEARBY_INDEX(a0)
	beq.s	.bln
	subq.w	#1,d5
	bsr	.bk
	move.w	d4,d0
	move.w	d5,d1
	mulu	#6,d1
	add.w	#31,d1
	bsr	.row
.bln:	subq.w	#1,d4
	beq.s	.bl2
	cmp.w	#1,d5
	bne.s	.bl
.bl2:	move.w	d4,dp_index
	cmp.w	#1,d5
	ble	.done
	move.w	d5,d3
	mulu	#6,d3
	add.w	#31,d3
	move.w	#166,d0
	moveq	#37,d1
	move.w	#278,d2
	move.l	d4,-(sp)
	moveq	#5,d4
	bsr	ms_bar
	move.l	(sp)+,d4
	bra.s	.done
.l1:	cmp.w	#1,GS_VIEWLEVEL(a6)
	bne.s	.done
	move.w	GS_TARGET(a6),d0
	bsr	dp_near
	move.w	NEARBY_INDEX(a0),d0
	bsr	genericsysinfo
.done:	bsr	mouseshow
	BKCOL	3
.x:	movem.l	(sp)+,d3-d5
	rts
.bk:	move.w	#5,GS_BKCOLOR(a6)	; if target = index then bkcolor := 179
	cmp.w	GS_TARGET(a6),d4
	bne.s	.bkx
	move.w	#179,GS_BKCOLOR(a6)
.bkx:	rts
.row:	bsr	dp_sysrow		; (printxy(239, row, ...) in dp_sysrow uses the row from d1)
	TCOL	191
	rts

; ---------------------------------------------------------------- planet info (logs level 3)
; the size / state / date / visits / bots lines of planet a3 (displaysystem shares them)
dp_planlines:
	PXY	167,37,"Location"
	PXY	177,43,"Size"
	PXY	174,49,"State"
	PXY	167,55,"Lastdate"
	PXY	173,61,"Visits"
	PXY	178,67,"Bots"
	rts
; d0 := 1 (and the strings) for size/state/... of planet a3; d1 = 1: "Aa.Life" (displaysystem's
; spelling) instead of "Ad.Life"
dp_planfacts:
	move.w	d1,-(sp)
	tst.w	PLANET_VISITS(a3)	; size
	beq.s	.su
	tst.b	PLANET_ORBIT(a3)
	bne.s	.ps
	moveq	#0,d0
	move.b	PLANET_MODE(a3),d0
	subq.w	#1,d0
	cmp.w	#2,d0
	bhi.s	.sk			; (no case: s keeps its value)
	mulu	#8,d0
	lea	dp_starsizes,a1
	bra.s	.sc
.ps:	moveq	#0,d0
	move.b	PLANET_PSIZE(a3),d0
	cmp.w	#4,d0
	bhi.s	.sk
	mulu	#8,d0
	lea	dp_plansizes,a1
.sc:	add.w	d0,a1
	lea	dp_s7,a0
	bsr	pstr_cpy
	bra.s	.sk
.su:	lea	dp_s7,a0
	lea	dp_t_unknown,a1
	bsr	pstr_cpy
.sk:	PXYS	234,43,dp_s7
	tst.w	PLANET_VISITS(a3)	; state
	beq.s	.tu
	moveq	#0,d0
	move.b	PLANET_STATE(a3),d0
	cmp.w	#7,d0
	bhi.s	.tk
	mulu	#8,d0
	lea	dp_states,a1
	cmp.w	#4*8,d0
	bne.s	.tc
	tst.w	(sp)
	beq.s	.tc
	lea	dp_t_aalife-4*8,a1
.tc:	add.w	d0,a1
	lea	dp_s7,a0
	bsr	pstr_cpy
	bra.s	.tk
.tu:	lea	dp_s7,a0
	lea	dp_t_unknown,a1
	bsr	pstr_cpy
.tk:	PXYS	234,49,dp_s7
	tst.w	PLANET_DATEY(a3)	; last date
	bne.s	.dt
	PXY	229,55,"   Never"
	bra.s	.vi
.dt:	moveq	#0,d0
	move.b	PLANET_DATEM(a3),d0
	move.w	PLANET_DATEY(a3),d1
	bsr	dp_date
	PXYS	229,55,dp_s2
.vi:	move.w	PLANET_VISITS(a3),d0	; visits
	bne.s	.vn
	PXY	249,61,"None"
	bra.s	.bo
.vn:	moveq	#0,d1
	move.w	d0,d1
	move.l	d1,d0
	moveq	#4,d1
	bsr	dp_str
	PXYS	249,61,dp_s
.bo:	moveq	#7,d0			; bots
	and.b	PLANET_BOTS(a3),d0
	bne.s	.b1
	PXY	234,67,"   None"
	bra.s	.bx
.b1:	cmp.b	#1,d0
	bne.s	.b2
	PXY	234,67,"Minebot"
	bra.s	.bx
.b2:	cmp.b	#2,d0
	bne.s	.b4
	PXY	234,67,"Factory"
	bra.s	.bx
.b4:	cmp.b	#4,d0
	bne.s	.b5
	PXY	234,67,"Fabrctr"
	bra.s	.bx
.b5:	cmp.b	#5,d0
	bne.s	.bx
	PXY	234,67,"Strmine"
.bx:	addq.l	#2,sp
	rts

genericplanetinfo:
	movem.l	d3-d4/a3,-(sp)
	bsr	dp_planlines
	move.w	GS_VIEWINDEX(a6),d0	; j := findfirstplanet(viewindex); a := j; find orbit viewindex2
	bsr	findfirstplanet
	move.w	d0,dp_j
	move.w	d0,d3
.f:	move.w	d3,d0
	bsr	dp_plan
	moveq	#0,d0
	move.b	PLANET_ORBIT(a0),d0
	cmp.w	GS_VIEWINDEX2(a6),d0
	beq.s	.fd
	addq.w	#1,d3
	bra.s	.f
.fd:	move.w	d3,dp_a
	move.l	a0,a3
	TCOL	61
	move.w	d3,d0			; printplanet(229,37,viewindex,a-j)
	sub.w	dp_j,d0
	move.w	d0,d2
	move.w	#229,d0
	moveq	#37,d1
	move.w	GS_VIEWINDEX(a6),d3
	bsr	printplanet
	TCOL	191
	moveq	#0,d1
	bsr	dp_planfacts
	tst.b	PLANET_ORBIT(a3)	; cache
	beq.s	.nc
	moveq	#0,d0
	lea	PLANET_CACHE(a3),a0
	moveq	#7-1,d1
.cc:	tst.w	(a0)+
	beq.s	.cn
	addq.w	#1,d0
.cn:	dbf	d1,.cc
	move.w	#7,dp_i
	move.w	d0,dp_j
	add.b	#'0',d0
	lea	dp_s,a0
	lea	dp_t_cache,a1
	bsr	pstr_cpy
	move.b	d0,dp_s+9		; 'Cache = '+chr(j+48)+'/7'
	PXYS	167,78,dp_s
	bra.s	.sc
.nc:	PXY	167,78,"           "
.sc:	btst	#0,PLANET_NOTES(a3)
	beq.s	.si
	tst.b	PLANET_ORBIT(a3)
	beq.s	.si
	PXY	167,84,"Scans Complete  "
	bra.s	.life
.si:	tst.b	PLANET_ORBIT(a3)
	bne.s	.sin
	PXY	167,84,"                "
	bra.s	.life
.sin:	PXY	167,84,"Scans Incomplete"
.life:	lea	dp_s3,a0		; str4 := 11 spaces; str1 := 20 spaces
	move.b	#11,(a0)+
	moveq	#11-1,d0
.p4:	move.b	#' ',(a0)+
	dbf	d0,.p4
	lea	dp_s4,a0
	move.b	#20,(a0)+
	moveq	#20-1,d0
.p1:	move.b	#' ',(a0)+
	dbf	d0,.p1
	move.b	PLANET_NOTES(a3),d0
	and.b	#2+32,d0
	beq	.pr
	moveq	#0,d0			; known natives by system
	move.b	PLANET_SYSTEM(a3),d0
	lea	dp_natives,a1
.nt:	move.w	(a1)+,d1
	bmi.s	.gen
	cmp.w	d1,d0
	beq.s	.ntf
	lea	22(a1),a1
	bra.s	.nt
.ntf:	cmp.w	#45,d0			; Ermigen only if not chevent(27)
	bne.s	.ntc
	move.l	a1,-(sp)
	moveq	#27,d0
	bsr	chevent
	move.l	(sp)+,a1
	tst.w	d0
	bne	.pr
.ntc:	lea	dp_s4,a0
	bsr	pstr_cpy
	bra	.pr
.gen:	cmp.b	#6,PLANET_STATE(a3)	; void dwellers
	bne.s	.tl
	cmp.b	#2,PLANET_MODE(a3)
	bne.s	.tl
	lea	dp_s4,a0
	lea	dp_t_void,a1
	bsr	pstr_cpy
	bra	.pr
.tl:	moveq	#-2,d4			; techlvl
	moveq	#0,d1
	move.b	PLANET_MODE(a3),d1
	move.b	PLANET_STATE(a3),d0
	cmp.b	#2,d0
	bne.s	.t3
	cmp.b	#2,d1
	bne.s	.t2b
	moveq	#-1,d4
.t2b:	cmp.b	#3,d1
	bne.s	.tk
	moveq	#0,d4
	bra.s	.tk
.t3:	cmp.b	#3,d0
	bne.s	.t4
	move.w	d1,d4
	subq.w	#1,d4
	bra.s	.tk
.t4:	cmp.b	#4,d0
	bne.s	.t5
	move.w	d1,d4
	addq.w	#2,d4
	bra.s	.tk
.t5:	cmp.b	#5,d0
	bne.s	.tk
	cmp.b	#1,d1
	bne.s	.t5b
	moveq	#0,d4
.t5b:	cmp.b	#2,d1
	bne.s	.tk
	moveq	#-1,d4
.tk:	cmp.w	#-2,d4
	bne.s	.tm1
	lea	dp_s4,a0
	lea	dp_t_nolife,a1
	bsr	pstr_cpy
	bra	.pr
.tm1:	moveq	#0,d0			; randseed := seed
	move.w	PLANET_SEED(a3),d0
	bsr	mt_seed
	cmp.w	#-1,d4
	bne	.t05
	moveq	#0,d0			; j := random(word(state+mode+seed)) mod 3
	move.b	PLANET_STATE(a3),d0
	moveq	#0,d1
	move.b	PLANET_MODE(a3),d1
	add.w	d1,d0
	add.w	PLANET_SEED(a3),d0
	bsr	mt_random
	divu	#3,d0
	swap	d0
	move.w	d0,dp_j
	tst.w	d0
	bne.s	.j1
	moveq	#2,d0
	bsr	mt_random
	lea	dp_t_short,a1
	tst.w	d0
	beq.s	.j0
	lea	dp_t_long,a1
.j0:	lea	dp_s4,a0
	bsr	pstr_cpy
	bra	.pr
.j1:	cmp.w	#1,d0
	bne.s	.j2
	moveq	#2,d0
	bsr	mt_random
	lea	dp_t_simple,a1
	tst.w	d0
	beq.s	.j0
	lea	dp_t_complex,a1
	bra.s	.j0
.j2:	moveq	#3,d0
	bsr	mt_random
	mulu	#12,d0
	lea	dp_t_chaosms,a1
	add.w	d0,a1
	lea	dp_s3,a0
	bsr	pstr_cpy
	lea	dp_t_single,a1
	bra.s	.j0
.t05:	cmp.w	#5,d4			; 0..5: an alien type and a diet
	bhi.s	.pr
	moveq	#11,d0
	bsr	mt_random
	mulu	#13,d0
	lea	alientypes,a1
	add.w	d0,a1
	lea	dp_s3,a0
	bsr	pstr_cpy
	cmp.b	#11,dp_s3		; (str4 is a string[11])
	bls.s	.at
	move.b	#11,dp_s3
.at:	moveq	#5,d0
	bsr	mt_random
	mulu	#22,d0
	lea	dp_diets,a1
	add.w	d0,a1
	bra	.j0
.pr:	PXYS	167,90,dp_s4
	PXYS	170,96,dp_s3
	btst	#1,PLANET_NOTES(a3)
	beq.s	.nce
	PXY	167,104,"Contact Established"
	bra.s	.ln
.nce:	BAR	171,104,265,110,5
.ln:	LINE	217,37,217,73,2
	LINE	165,74,278,74,2
	LINE	218,37,218,73,10
	LINE	166,75,279,75,10
	PSET	218,74,6
	PSET	279,75,6
	PSET	217,36,6
	PSET	165,74,6
	movem.l	(sp)+,d3-d4/a3
	rts

; ---------------------------------------------------------------- ship logs: systems (viewmode 7)
; displaylogs' testmode(index d0): out d0.w = 1 (Z clear) if system index is listed under the
; filter viewindex3 (0 all visited, 1 with cache, 2 with contacts, 3 scans to do)
dp_testmode:
	movem.l	d3-d5/a3,-(sp)
	move.w	d0,d5
	bsr	dp_sys
	move.l	a0,a3
	tst.w	SYSTEM_VISITS(a3)
	beq	.no
	move.w	GS_VIEWINDEX3(a6),d0
	beq	.yes
	move.w	d5,d0			; a := findfirstplanet(index); planets j+a for j 1..numplanets
	bsr	findfirstplanet
	move.w	d0,dp_a
	moveq	#0,d4
	move.b	SYSTEM_NUMPLANETS(a3),d4
	moveq	#1,d3
.j:	cmp.w	d4,d3
	bgt	.no
	move.w	d3,dp_j
	move.w	d3,d0
	add.w	dp_a,d0
	bsr	dp_plan
	move.w	GS_VIEWINDEX3(a6),d0
	cmp.w	#1,d0
	bne.s	.m2
	moveq	#1,d1			; any cache[b] > 0
	lea	PLANET_CACHE(a0),a1
.b:	move.w	d1,dp_b
	tst.w	(a1)+
	bne.s	.yes
	addq.w	#1,d1
	cmp.w	#8,d1
	bne.s	.b
	bra.s	.n
.m2:	cmp.w	#2,d0
	bne.s	.m3
	btst	#1,PLANET_NOTES(a0)
	bne.s	.yes
	bra.s	.n
.m3:	cmp.w	#3,d0
	bne.s	.no			; (other filters: false)
	move.b	PLANET_NOTES(a0),d0
	and.b	#254,d0
	bne.s	.n
	tst.b	PLANET_ORBIT(a0)
	bne.s	.yes
.n:	addq.w	#1,d3
	bra.s	.j
.yes:	moveq	#1,d0
	bra.s	.x
.no:	moveq	#0,d0
.x:	movem.l	(sp)+,d3-d5/a3
	tst.w	d0
	rts
; the level 1-3 screens' frame pixels
dp_logframe:
	bsr	dp_clear
	PSET	165,80,10
	PSET	279,81,2
	PSET	165,74,10
	PSET	279,75,2
	PSET	217,36,10
	rts
; the level 0 title by filter
dp_logtitle:
	move.w	GS_VIEWINDEX3(a6),d0
	cmp.w	#3,d0
	bhi.s	.x
	mulu	#22,d0
	lea	dp_logtitles,a0
	add.w	d0,a0
	move.w	#166,d0
	moveq	#27,d1
	bra	printxy
.x:	rts
; the next orbit with a planet (com 3: down = 0, up = 1 in d0)
dp_logorbit:
	movem.l	d3-d5,-(sp)
	move.w	d0,d5
	move.w	GS_VIEWINDEX(a6),d0
	bsr	findfirstplanet
	move.w	d0,dp_j
	move.w	d0,d4
.r:	move.w	GS_VIEWINDEX2(a6),d0
	tst.w	d5
	beq.s	.dn
	subq.w	#1,d0			; up: if viewindex2 = 0 then 7 else dec
	bpl.s	.s
	moveq	#7,d0
	bra.s	.s
.dn:	addq.w	#1,d0			; down: if viewindex2 = 7 then 0 else inc
	cmp.w	#8,d0
	bne.s	.s
	moveq	#0,d0
.s:	move.w	d0,GS_VIEWINDEX2(a6)
	moveq	#0,d3			; for i := 0 to 7: planet j+i with that orbit in this system?
	moveq	#0,d2
.i:	move.w	d4,d0
	add.w	d3,d0
	bsr	dp_plan
	moveq	#0,d0
	move.b	PLANET_ORBIT(a0),d0
	cmp.w	GS_VIEWINDEX2(a6),d0
	bne.s	.in
	moveq	#0,d0
	move.b	PLANET_SYSTEM(a0),d0
	cmp.w	GS_VIEWINDEX(a6),d0
	bne.s	.in
	moveq	#1,d2
.in:	addq.w	#1,d3
	cmp.w	#8,d3
	bne.s	.i
	move.w	#7,dp_i
	tst.w	d2
	beq.s	.r
	movem.l	(sp)+,d3-d5
	rts

displaylogs:
	movem.l	d3-d5,-(sp)
	move.w	d0,d3
	bsr	mousehide
	TCOL	191
	BKCOL	5
	cmp.w	#1,d3
	bne.s	.c2
	tst.w	GS_VIEWINDEX(a6)	; 1: left
	ble	.chk
	tst.w	GS_VIEWLEVEL(a6)
	ble	.chk
	subq.w	#1,GS_VIEWLEVEL(a6)
	bne.s	.c1f
	BKCOL	5
	TCOL	191
	bsr	dp_logtitle
	SHOWPANEL 23,25,6
.c1f:	bsr	dp_logframe
	bra	.chk
.c2:	cmp.w	#2,d3
	bne.s	.c3
	tst.w	GS_VIEWINDEX(a6)	; 2: right
	ble	.chk
	cmp.w	#3,GS_VIEWLEVEL(a6)
	bge	.chk
	tst.w	GS_VIEWLEVEL(a6)
	bne.s	.c2i
	clr.w	GS_VIEWINDEX2(a6)
	SHOWPANEL 23,25,12
.c2i:	addq.w	#1,GS_VIEWLEVEL(a6)
	bsr	dp_logframe
	bra	.chk
.c3:	cmp.w	#3,d3
	bne.s	.c4
	cmp.w	#2,GS_VIEWLEVEL(a6)	; 3: up
	bge.s	.c3o
	clr.w	GS_VIEWINDEX2(a6)
	move.w	GS_VIEWINDEX(a6),d4
	subq.w	#1,d4
	bsr	.prev
	tst.w	d4
	bgt.s	.c3s
	move.w	#250,d4
	bsr	.prev
.c3s:	move.w	d4,GS_VIEWINDEX(a6)
	bra	.chk
.c3o:	moveq	#1,d0
	bsr	dp_logorbit
	bra	.chk
.prev:	tst.w	d4			; while (vi > 0) and not testmode(vi) do dec(vi)
	ble.s	.px
	move.w	d4,d0
	bsr	dp_testmode
	bne.s	.px
	subq.w	#1,d4
	bra.s	.prev
.px:	rts
.next:	cmp.w	#251,d4			; while (vi < 251) and not testmode(vi) do inc(vi)
	bge.s	.nx
	move.w	d4,d0
	bsr	dp_testmode
	bne.s	.nx
	addq.w	#1,d4
	bra.s	.next
.nx:	rts
.c4:	cmp.w	#4,d3
	bne.s	.c5
	cmp.w	#2,GS_VIEWLEVEL(a6)	; 4: down
	bge.s	.c4o
	clr.w	GS_VIEWINDEX2(a6)
	move.w	GS_VIEWINDEX(a6),d4
	addq.w	#1,d4
	bsr	.next
	cmp.w	#250,d4
	ble.s	.c3s
	moveq	#1,d4
	bsr	.next
	cmp.w	#251,d4
	bne.s	.c3s
	moveq	#0,d4
	bra.s	.c3s
.c4o:	moveq	#0,d0
	bsr	dp_logorbit
	bra	.chk
.c5:	cmp.w	#5,d3
	bne.s	.c6
	st	d0
	bsr	removerightside
	bsr	mouseshow
	bra	.x
.c6:	cmp.w	#6,d3
	bne.s	.c7
	tst.w	GS_VIEWINDEX(a6)	; '1': planet info
	ble.s	.c6l
	cmp.w	#3,GS_VIEWLEVEL(a6)
	beq.s	.c6l
	tst.w	GS_VIEWLEVEL(a6)
	bne.s	.c6f
	clr.w	GS_VIEWINDEX2(a6)
	SHOWPANEL 23,25,12
.c6f:	bsr	dp_logframe
.c6l:	move.w	#3,GS_VIEWLEVEL(a6)
	bra.s	.chk
.c7:	cmp.w	#7,d3
	bne.s	.c8
	tst.b	GS_SHOWPLANET(a6)	; '2': this system
	beq.s	.chk
	move.w	GS_CURPLAN(a6),d0
	bsr	dp_plan
	moveq	#0,d0
	move.b	PLANET_SYSTEM(a0),d0
	move.w	d0,GS_VIEWINDEX(a6)
	bra.s	.chk
.c8:	cmp.w	#8,d3
	bne.s	.chk
	tst.w	GS_VIEWLEVEL(a6)	; '3': the next filter
	bne.s	.chk
	move.w	GS_VIEWINDEX3(a6),d0
	addq.w	#1,d0
	cmp.w	#4,d0
	bne.s	.c8s
	moveq	#0,d0
.c8s:	move.w	d0,GS_VIEWINDEX3(a6)
	bsr	dp_logtitle
.chk:	tst.w	GS_VIEWINDEX(a6)	; a lost position: back to this system (or 1)
	bne.s	.lv
	moveq	#1,d0
	tst.b	GS_SHOWPLANET(a6)
	beq.s	.ch1
	move.w	GS_CURPLAN(a6),d0
	bsr	dp_plan
	moveq	#0,d0
	move.b	PLANET_SYSTEM(a0),d0
.ch1:	move.w	d0,GS_VIEWINDEX(a6)
.lv:	move.w	GS_VIEWLEVEL(a6),d0
	bne	.lv1
	tst.w	GS_VIEWINDEX(a6)	; level 0: the list of systems
	ble	.done
	move.w	GS_VIEWINDEX(a6),d4	; after the selected one
	addq.w	#1,d4
	moveq	#7,d5
.af:	cmp.w	#250,d4
	bgt.s	.afn
	move.w	d4,d0
	bsr	dp_testmode
	beq.s	.afn
	addq.w	#1,d5
	bsr	.bk
	bsr	.name
.afn:	addq.w	#1,d4
	cmp.w	#250,d4
	bgt.s	.af2
	cmp.w	#13,d5
	bne.s	.af
.af2:	move.w	d4,dp_index
	cmp.w	#13,d5
	bge.s	.bf
	move.w	d5,d1
	mulu	#6,d1
	add.w	#38,d1
	movem.l	d3-d4,-(sp)
	move.w	#166,d0
	move.w	#278,d2
	moveq	#116,d3
	moveq	#5,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
.bf:	move.w	GS_VIEWINDEX(a6),d4	; the selected one and those before
	moveq	#8,d5
.bl:	move.w	d4,d0
	bsr	dp_testmode
	beq.s	.bln
	subq.w	#1,d5
	bsr	.bk
	bsr	.name
.bln:	subq.w	#1,d4
	ble.s	.bl2
	cmp.w	#1,d5
	bne.s	.bl
.bl2:	move.w	d4,dp_index
	cmp.w	#1,d5
	ble	.done
	move.w	d5,d3
	mulu	#6,d3
	add.w	#31,d3
	move.w	#166,d0
	moveq	#37,d1
	move.w	#278,d2
	move.l	d4,-(sp)
	moveq	#5,d4
	bsr	ms_bar
	move.l	(sp)+,d4
	bra	.done
.bk:	move.w	#5,GS_BKCOLOR(a6)
	cmp.w	GS_VIEWINDEX(a6),d4
	bne.s	.bkx
	move.w	#179,GS_BKCOLOR(a6)
.bkx:	rts
.name:	move.w	d4,d0			; printxy(163, 31+y*6, systems[index].name)
	bsr	dp_sys
	move.w	#163,d0
	move.w	d5,d1
	mulu	#6,d1
	add.w	#31,d1
	bra	printxy
.lv1:	cmp.w	#1,d0
	bne.s	.lv2
	PXY	166,27,"Ship Logs:System Info"
	move.w	GS_VIEWINDEX(a6),d0
	bsr	genericsysinfo
	bra	.done
.lv2:	cmp.w	#2,d0
	bne.s	.lv3
	PXY	166,27," Ship Logs: Planets  "
	move.w	GS_VIEWINDEX(a6),d0	; the orbits as circles (90 for the selected one)
	bsr	findfirstplanet
	move.w	d0,d4
	moveq	#0,d5			; i
.or:	move.w	d4,d0
	bsr	dp_plan
	moveq	#0,d2
	move.b	PLANET_ORBIT(a0),d2
	moveq	#16,d0
	cmp.w	GS_VIEWINDEX2(a6),d2
	bne.s	.oc
	moveq	#90,d0
.oc:	mulu	#6,d2
	move.l	d4,-(sp)
	move.w	d0,d4
	move.w	#222,d0
	moveq	#75,d1
	bsr	ms_circle
	move.l	(sp)+,d4
	addq.w	#1,d4
	addq.w	#1,d5
	move.w	GS_VIEWINDEX(a6),d0
	bsr	dp_sys
	moveq	#0,d0
	move.b	SYSTEM_NUMPLANETS(a0),d0
	cmp.w	d0,d5
	bne.s	.or
	move.w	d4,dp_j
	move.w	d5,dp_i
	bra.s	.done
.lv3:	cmp.w	#3,d0
	bne.s	.done
	PXY	166,27,"Ship Logs:Planet Info"
	bsr	genericplanetinfo
.done:	bsr	mouseshow
	BKCOL	3
.x:	movem.l	(sp)+,d3-d5
	rts

; ---------------------------------------------------------------- the system view (viewmode 8)
; planet d0 (tempplan index) on its orbit at time t1: x1, y1 (GS doubles); d1.w = 1: the
; original's nudge of seed mod 628 off 0/157/314/471 (not in targetplanet's search loop)
dp_sysplanet:
	movem.l	d3-d4/a3,-(sp)
	move.w	d1,d4
	bsr	dp_plan
	move.l	a0,a3
	moveq	#0,d0			; i := seed mod 628 (seed a word)
	move.w	PLANET_SEED(a3),d0
	divu	#628,d0
	swap	d0
	tst.w	d4
	beq.s	.ni
	tst.w	d0
	beq.s	.inc
	cmp.w	#314,d0
	beq.s	.inc
	cmp.w	#157,d0
	beq.s	.inc
	cmp.w	#471,d0
	bne.s	.ni
.inc:	addq.w	#1,d0
.ni:	move.w	d0,dp_i
	FSSE				; t2 := i/100
	bsr	fp_ldw
	FLDI	100
	bsr	fp_div
	FSTG	GS_T2
	FX87				; x := cos(t2)*orbit; z := sin(t2)*orbit
	FLDG	GS_T2
	bsr	fp_cos
	moveq	#0,d0
	move.b	PLANET_ORBIT(a3),d0
	bsr	fp_ldw
	bsr	fp_mul
	lea	dp_xd,a0
	bsr	fp_std
	FLDG	GS_T2
	bsr	fp_sin
	moveq	#0,d0
	move.b	PLANET_ORBIT(a3),d0
	bsr	fp_ldw
	bsr	fp_mul
	lea	dp_zd,a0
	bsr	fp_std
	FSSE				; if (z <> 0) and (x <> 0)
	lea	dp_zd,a0
	bsr	fp_ldd
	bsr	fp_tst
	beq	.c
	lea	dp_xd,a0
	bsr	fp_ldd
	bsr	fp_tst
	beq	.c
	lea	dp_xd,a0		; ar := (x/sin(arctan(x/z)))*14
	bsr	fp_ldd
	lea	dp_zd,a0
	bsr	fp_ldd
	bsr	fp_div
	bsr	fp_atan
	bsr	fp_sin
	FX87
	lea	dp_xd,a0
	bsr	fp_ldd
	bsr	fp_divr
	FLDI	14
	bsr	fp_mul
	FSTG	GS_AR
	FSSE				; br := ar*5/14
	FLDG	GS_AR
	FLDI	5
	bsr	fp_mul
	FLDI	14
	bsr	fp_div
	FSTG	GS_BR
	lea	dp_zd,a0		; t2 := arctan(z/(2*x))
	bsr	fp_ldd
	FLDI	2
	lea	dp_xd,a0
	bsr	fp_ldd
	bsr	fp_mul
	bsr	fp_div
	bsr	fp_atan
	FSTG	GS_T2
	moveq	#8,d0			; ang := t2 + t1*(8-orbit)  (SSE)
	sub.b	PLANET_ORBIT(a3),d0
	ext.w	d0
	bsr	fp_ldw
	FLDG	GS_T1
	bsr	fp_mul
	FLDG	GS_T2
	bsr	fp_add
	lea	dp_ang,a0
	bsr	fp_std
	FX87				; x1 := 142+cos(ang)*ar; y1 := 65+sin(ang)*br
	lea	dp_ang,a0
	bsr	fp_ldd
	bsr	fp_cos
	FLDG	GS_AR
	bsr	fp_mul
	FLDI	142
	bsr	fp_add
	FSTG	GS_X1
	lea	dp_ang,a0
	bsr	fp_ldd
	bsr	fp_sin
	FLDG	GS_BR
	bsr	fp_mul
	FLDI	65
	bsr	fp_add
	FSTG	GS_Y1
	FSSE
	bra.s	.x
.c:	FSSE				; the star: x1 := 142; y1 := 65
	FLDI	142
	FSTG	GS_X1
	FLDI	65
	FSTG	GS_Y1
.x:	movem.l	(sp)+,d3-d4/a3
	rts
; d0 := round(x1), d1 := round(y1)
dp_rxy:
	FSSE
	FLDG	GS_Y1
	bsr	fp_rnd
	move.w	d0,-(sp)
	FLDG	GS_X1
	bsr	fp_rnd
	move.w	(sp)+,d1
	rts

displaysystem:
	movem.l	d3-d6/a3,-(sp)
	move.w	d0,d3
	TCOL	191
	BKCOL	5
	move.w	GS_VIEWINDEX(a6),GS_C(a6)	; c := viewindex
	cmp.w	#1,d3
	bne.s	.c2
	move.w	GS_VIEWINDEX(a6),d0	; 1: the previous planet
	bne.s	.c1d
	move.w	GS_VIEWINDEX2(a6),d0
	bsr	dp_sys
	moveq	#0,d0
	move.b	SYSTEM_NUMPLANETS(a0),d0
.c1d:	subq.w	#1,d0
	move.w	d0,GS_VIEWINDEX(a6)
	bra.s	.pp
.c2:	cmp.w	#2,d3
	bne.s	.c5
	move.w	GS_VIEWINDEX(a6),d4	; 2: the next
	addq.w	#1,d4
	move.w	GS_VIEWINDEX2(a6),d0
	bsr	dp_sys
	moveq	#0,d0
	move.b	SYSTEM_NUMPLANETS(a0),d0
	cmp.w	d0,d4
	bne.s	.c2s
	moveq	#0,d4
.c2s:	move.w	d4,GS_VIEWINDEX(a6)
.pp:	move.w	#233,d0			; printplanet(233,108,viewindex2,viewindex)
	moveq	#108,d1
	move.w	GS_VIEWINDEX(a6),d2
	move.l	d3,-(sp)
	move.w	GS_VIEWINDEX2(a6),d3
	bsr	printplanet
	move.l	(sp)+,d3
	bra	.draw
.c5:	cmp.w	#5,d3
	bne.s	.c6
	st	d0
	bsr	removesystem
	bra	.x
.c6:	cmp.w	#6,d3
	bne	.c7
	moveq	#11,d0			; orbit the target planet
	bsr	chevent
	tst.w	d0
	bne.s	.go
	TCOL	94
	BKCOL	3
	PRTLN
	PRT	"SCIENCE: Sir, that would not be wise. I suggest we first scan this planet."
	BKCOL	5
	bra	.draw
.go:	move.w	GS_VIEWINDEX2(a6),d0
	bsr	findfirstplanet
	add.w	GS_VIEWINDEX(a6),d0
	move.w	d0,dp_j
	move.w	d0,GS_CURPLAN(a6)
	bsr	dp_plan
	cmp.w	#255,PLANET_VISITS(a0)
	bhs.s	.v
	addq.w	#1,PLANET_VISITS(a0)
.v:	move.w	GS_SHIP+SHIP_STARDATE+2*2(a6),PLANET_DATEY(a0)	; stardate[3]
	move.b	GS_SHIP+SHIP_STARDATE+1(a6),PLANET_DATEM(a0)	; stardate[1] (low byte)
	move.w	GS_VIEWINDEX(a6),GS_SHIP+SHIP_ORBITING(a6)
	st	d0
	bsr	removesystem
	bsr	mousehide
	moveq	#0,d0			; compressfile(current)
	bsr	ms_snap
	BAR	0,0,319,199,0
	bsr	mouseshow
	moveq	#40,d0			; for j := 1 to random(40)+60 do addlotstime(false,true,100+random(100))
	bsr	mt_random
	add.w	#60,d0
	move.w	d0,d4
	moveq	#1,d5
.lt:	cmp.w	d4,d5
	bgt.s	.lte
	move.w	d5,dp_j
	moveq	#100,d0
	bsr	mt_random
	add.w	#100,d0
	move.w	d0,d2
	moveq	#0,d0
	moveq	#1,d1
	bsr	addlotstime
	addq.w	#1,d5
	bra.s	.lt
.lte:	moveq	#-8,d0			; fadefull(-FADEFULL_STEP, FADEFULL_DELAY)
	moveq	#20,d1
	bsr	fadefull
	bsr	mousehide
	bsr	orc_dump		; loadscreen(current): an oracle dump point
	moveq	#0,d0			; loadscreen(current)
	bsr	ms_unsnap
	bsr	mouseshow
	tst.w	GS_VIEWINDEX(a6)
	beq.s	.st
	bsr	readyplanet
	bra.s	.cw
.st:	bsr	readystar
.cw:	bsr	checkwandering
	bra	.x
.c7:	cmp.w	#7,d3
	bne.s	.c8
	move.w	GS_VIEWLEVEL(a6),d0	; 7: info on / off
	btst	#0,d0
	bne.s	.c7o
	addq.w	#1,GS_VIEWLEVEL(a6)
	bra.s	.draw
.c7o:	subq.w	#1,GS_VIEWLEVEL(a6)
.clr:	bsr	mousehide
	BAR	166,37,278,74,5
	bsr	mouseshow
	bra.s	.draw
.c8:	cmp.w	#8,d3
	bne.s	.draw
	cmp.w	#2,GS_VIEWLEVEL(a6)	; 8: animation on / off
	bge.s	.c8o
	addq.w	#2,GS_VIEWLEVEL(a6)
	bra.s	.draw
.c8o:	subq.w	#2,GS_VIEWLEVEL(a6)
	bra.s	.clr
.draw:	bsr	dp_cycle
	btst	#1,GS_VIEWLEVEL+1(a6)	; animating: t1 := t1 + 0.0025 (wraps at 6.28)
	beq.s	.na
	FX87
	FLDG	GS_T1
	FLDX	gx_0_0025
	bsr	fp_add
	FSTG	GS_T1
	FLDG	GS_T1
	FLDX	gx_6_28
	bsr	fp_cmp
	ble.s	.na0
	FLDG	GS_T1
	FLDX	gx_6_28
	bsr	fp_sub
	FSTG	GS_T1
.na0:	FSSE
.na:	clr.w	GS_Y(a6)		; y := 0
	move.w	GS_VIEWINDEX2(a6),d0
	bsr	findfirstplanet
	move.w	d0,dp_j
	bsr	mousehide
	move.w	GS_CX(a6),d0		; erase the old cursor: circle(cx,cy,6) in 5
	move.w	GS_CY(a6),d1
	moveq	#6,d2
	moveq	#5,d4
	bsr	ms_circle
.pl:	move.w	dp_j,d0			; each planet
	moveq	#1,d1
	bsr	dp_sysplanet
	move.w	dp_j,d0
	bsr	dp_plan
	bsr	dp_planicon
	move.w	GS_Y(a6),d0
	cmp.w	GS_VIEWINDEX(a6),d0
	bne.s	.nc
	bsr	dp_rxy			; the cursor: cx := round(x1)+5, cy := round(y1)+5
	addq.w	#5,d0
	addq.w	#5,d1
	move.w	d0,GS_CX(a6)
	move.w	d1,GS_CY(a6)
	moveq	#6,d2
	moveq	#80,d4
	add.w	dp_index,d4
	bsr	ms_circle
.nc:	bsr	dp_rxy
	bsr	dp_planicon_put
	addq.w	#1,dp_j
	addq.w	#1,GS_Y(a6)
	move.w	GS_VIEWINDEX2(a6),d0
	bsr	dp_sys
	moveq	#0,d0
	move.b	SYSTEM_NUMPLANETS(a0),d0
	cmp.w	GS_Y(a6),d0
	bne.s	.pl
	btst	#0,GS_VIEWLEVEL+1(a6)	; the planet's facts
	beq.s	.done
	bsr	dp_planlines
	move.w	GS_VIEWINDEX2(a6),d0
	bsr	findfirstplanet
	add.w	GS_VIEWINDEX(a6),d0
	move.w	d0,dp_a
	bsr	dp_plan
	move.l	a0,a3
	move.w	#229,d0
	moveq	#37,d1
	move.w	GS_VIEWINDEX(a6),d2
	move.l	d3,-(sp)
	move.w	GS_VIEWINDEX2(a6),d3
	bsr	printplanet
	move.l	(sp)+,d3
	moveq	#1,d1
	bsr	dp_planfacts
.done:	bsr	mouseshow
	st	GS_ANYCHANGE(a6)
	BKCOL	3
.x:	movem.l	(sp)+,d3-d6/a3
	rts

; display.pas targetplanet(xt d0, yt d1): the system view's mouse click
targetplanet:
	movem.l	d3-d6,-(sp)
	move.w	d0,d5
	move.w	d1,d6
	move.w	GS_VIEWINDEX2(a6),d0	; erase the selected planet's box
	bsr	findfirstplanet
	add.w	GS_VIEWINDEX(a6),d0
	move.w	d0,dp_j
	bsr	mousehide
	moveq	#1,d1
	bsr	dp_sysplanet
	bsr	dp_rxy
	move.w	d0,d3
	move.w	d1,d4
	subq.w	#2,d0			; for i := 1 to 13: 15 at (x-2, y-2+i)
	subq.w	#1,d1
	move.w	d0,d2
	add.w	#14,d2
	movem.l	d3-d4,-(sp)
	move.w	d1,d3
	add.w	#12,d3
	moveq	#5,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
	move.w	d3,d0			; 5 at (x+3, y+12)
	addq.w	#3,d0
	move.w	d4,d1
	add.w	#12,d1
	moveq	#5,d2
	move.l	d4,-(sp)
	moveq	#5,d4
	bsr	dp_fill
	move.l	(sp)+,d4
	bsr	mouseshow
	move.w	GS_VIEWINDEX2(a6),d0	; find the planet under (xt, yt)
	bsr	findfirstplanet
	move.w	d0,dp_j
	move.w	#-1,GS_Y(a6)
	moveq	#0,d4			; done
.l:	addq.w	#1,GS_Y(a6)
	move.w	dp_j,d0
	moveq	#0,d1
	bsr	dp_sysplanet
	addq.w	#1,dp_j
	FSSE				; abs(x1-xt+5) < 8 and abs(y1-yt+5) < 8
	FLDG	GS_X1
	move.w	d5,d0
	bsr	fp_ldw
	bsr	fp_sub
	FLDI	5
	bsr	fp_add
	bsr	fp_abs
	FLDI	8
	bsr	fp_cmp
	bge.s	.n
	FLDG	GS_Y1
	move.w	d6,d0
	bsr	fp_ldw
	bsr	fp_sub
	FLDI	5
	bsr	fp_add
	bsr	fp_abs
	FLDI	8
	bsr	fp_cmp
	bge.s	.n
	moveq	#1,d4
.n:	tst.w	d4
	bne.s	.f
	move.w	GS_VIEWINDEX2(a6),d0
	bsr	dp_sys
	moveq	#0,d0
	move.b	SYSTEM_NUMPLANETS(a0),d0
	cmp.w	GS_Y(a6),d0
	bne	.l
	bra.s	.x
.f:	TCOL	191
	BKCOL	5
	move.w	GS_Y(a6),GS_VIEWINDEX(a6)
	move.w	#233,d0
	moveq	#108,d1
	move.w	GS_Y(a6),d2
	move.w	GS_VIEWINDEX2(a6),d3
	bsr	printplanet
	BKCOL	3
.x:	movem.l	(sp)+,d3-d6
	rts

; ---------------------------------------------------------------- ship info (viewmode 9)
; loadshipdisplay2(index d0, x1 d1, y1 d2): shippix.dta record index (58 columns of 75)
loadshipdisplay2:
	movem.l	d3-d5,-(sp)
	move.w	d1,d4
	move.w	d2,d5
	move.w	d0,d3
	bsr	dp_shippix		; a0 = the file in memory
	move.w	d3,d0
	mulu	#58*75,d0
	add.l	d0,a0
	move.l	a0,a1
	ext.l	d3			; x2 := x1 + 58*(index div 3)
	divu	#3,d3
	mulu	#58,d3
	add.w	d4,d3
	moveq	#0,d0			; j - x2
.j:	move.w	d3,d1			; column j: screen[y1+i, j] := temp^[j-x2, i]
	add.w	d0,d1
	movem.l	d0/a1,-(sp)
	move.w	d1,d0
	move.w	d5,d1
	bsr	ms_addr
	movem.l	(sp)+,d0/a1
	moveq	#75-1,d1
.i:	move.b	(a1)+,(a0)
	lea	MS_W(a0),a0
	dbf	d1,.i
	addq.w	#1,d0
	cmp.w	#58,d0
	bne.s	.j
	move.w	d3,d0
	move.w	d5,d1
	move.w	d3,d2
	add.w	#57,d2
	move.w	d5,d3
	add.w	#74,d3
	bsr	ms_dirty
	movem.l	(sp)+,d3-d5
	rts
; a0 := DATA\SHIPPIX.DTA (read on first use)
dp_shippix:
	move.l	dp_shippixbuf,d0
	bne.s	.h
	move.l	#9*58*75,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,dp_shippixbuf
	move.l	a0,a1
	lea	dp_fn_shippix,a0
	move.l	#9*58*75,d0
	bsr	load_exact
	move.l	dp_shippixbuf,d0
.h:	move.l	d0,a0
	rts
; displayship2(x1 d0, y1 d1)
displayship2:
	movem.l	d3-d4,-(sp)
	move.w	d0,d3
	move.w	d1,d4
	moveq	#0,d0
	move.b	GS_SHIP+SHIP_SHIPTYPE(a6),d0	; heavyness-1
	subq.w	#1,d0
	move.w	d3,d1
	move.w	d4,d2
	bsr	loadshipdisplay2
	moveq	#2,d0
	add.b	GS_SHIP+SHIP_SHIPTYPE+1(a6),d0	; 2+purpose
	move.w	d3,d1
	move.w	d4,d2
	bsr	loadshipdisplay2
	moveq	#5,d0
	add.b	GS_SHIP+SHIP_SHIPTYPE+2(a6),d0	; 5+vessel
	move.w	d3,d1
	move.w	d4,d2
	bsr	loadshipdisplay2
	movem.l	(sp)+,d3-d4
	rts

displayshipinfo:
	movem.l	d3-d6/a3,-(sp)
	TCOL	191
	BKCOL	5
	bsr	mousehide
	lea	GS_SHIP+SHIP_POSX(a6),a3	; ar := pos/10; str(ar:5:1) at 228, 26/32/38
	moveq	#26,d3
.p:	FSSE
	move.w	(a3)+,d0
	bsr	fp_ldw
	FLDI	10
	bsr	fp_div
	FSTG	GS_AR
	FLDG	GS_AR
	moveq	#5,d0
	moveq	#1,d1
	lea	dp_s,a0
	bsr	fp_str
	lea	dp_s,a0
	move.w	#228,d0
	move.w	d3,d1
	bsr	printxy
	addq.w	#6,d3
	cmp.w	#44,d3
	bne.s	.p
	move.w	GS_SHIP+SHIP_HULLINTEGRITY(a6),d0
	move.w	GS_SHIP+SHIP_HULLMAX(a6),d1
	bsr	.pair
	PXYS	223,44,dp_s2
	move.w	GS_SHIP+SHIP_FUEL(a6),d0
	move.w	GS_SHIP+SHIP_FUELMAX(a6),d1
	bsr	.pair
	PXYS	223,50,dp_s2
	move.w	GS_SHIP+SHIP_BATTERY(a6),d0
	ext.l	d0
	moveq	#5,d1
	bsr	dp_str
	lea	dp_s,a0
	lea	dp_t_32000,a1
	bsr	pstr_cat
	PXYS	218,56,dp_s
	moveq	#0,d5			; cargo_used (a word)
	moveq	#1,d3			; j
	lea	GS_SHIP+SHIP_CARGO(a6),a3
.c:	move.w	(a3)+,d0
	cmp.w	#ID_ARTIFACT_OFFSET,d0
	ble.s	.c1
	bsr	getartifactname
	move.w	#MAXCARGO,dp_i
	bra.s	.c3
.c1:	tst.w	d0
	beq.s	.c3
	lea	GS_CARGO+CARGO_INDEX(a6),a0	; i := index of the item in cargo[]
	moveq	#1,d1
.c2:	cmp.w	(a0),d0
	beq.s	.c2f
	lea	CARGO_SIZEOF(a0),a0
	addq.w	#1,d1
	bra.s	.c2
.c2f:	move.w	d1,dp_i
.c3:	move.w	dp_i,d0
	cmp.w	#MAXCARGO,d0
	bgt.s	.cn
	mulu	#CARGO_SIZEOF,d0
	lea	GS_CARGO-CARGO_SIZEOF+CARGO_SIZE(a6),a0
	move.w	0(a0,d0.l),d0
	move.w	SHIP_NUMCARGO-SHIP_CARGO-2(a3),d1
	mulu	d1,d0
	add.w	d0,d5
.cn:	addq.w	#1,d3
	cmp.w	#251,d3
	bne.s	.c
	moveq	#0,d0
	move.w	d5,d0
	moveq	#5,d1
	bsr	dp_str
	lea	dp_s2,a0
	lea	dp_s,a1
	bsr	pstr_cpy
	lea	dp_s2,a0
	lea	dp_t_slash,a1
	bsr	pstr_cat
	move.w	GS_SHIP+SHIP_CARGOMAX(a6),d0
	ext.l	d0
	moveq	#4,d1
	bsr	dp_str
	lea	dp_s2,a0
	lea	dp_s,a1
	bsr	pstr_cat
	lea	dp_s2,a0
	lea	dp_t_zero,a1
	bsr	pstr_cat
	PXYS	218,62,dp_s2
	move.w	GS_SHIP+SHIP_ACCELMAX(a6),d0
	ext.l	d0
	moveq	#4,d1
	bsr	dp_str
	PXYS	218,68,dp_s
	moveq	#1,d3			; the damage bars
.dj:	moveq	#100,d0			; y := round((100-damages[j])*0.77)  (x87)
	lea	GS_SHIP+SHIP_DAMAGES-1(a6),a0
	moveq	#0,d1
	move.b	0(a0,d3.w),d1
	sub.w	d1,d0
	ext.l	d0
	lea	gx_0_77,a0
	bsr	dp_rndmul
	move.w	d0,d5
	moveq	#-1,d6			; i
.di:	move.w	#100,d4
	tst.w	d6
	ble.s	.dp
	sub.w	d6,d4
	bra.s	.dq
.dp:	add.w	d6,d4
.dq:	move.w	d3,d1			; row 74+7+i+j*4
	lsl.w	#2,d1
	add.w	#81,d1
	add.w	d6,d1
	move.w	d1,-(sp)
	move.w	#197,d0
	move.w	d5,d2
	bsr	dp_fill
	move.w	(sp)+,d1
	cmp.w	#77,d5
	bge.s	.dn
	move.w	#197,d0
	add.w	d5,d0
	moveq	#77,d2
	sub.w	d5,d2
	move.w	d4,-(sp)
	moveq	#2,d4
	bsr	dp_fill
	move.w	(sp)+,d4
.dn:	addq.w	#1,d6
	cmp.w	#3,d6
	bne.s	.di
	addq.w	#1,d3
	cmp.w	#8,d3
	bne.s	.dj
	bsr	mouseshow
	BKCOL	3
	movem.l	(sp)+,d3-d6/a3
	rts
.pair:	move.w	d1,-(sp)		; str(d0:4)+'/'+str(d1:4) in dp_s2
	ext.l	d0
	moveq	#4,d1
	bsr	dp_str
	lea	dp_s2,a0
	lea	dp_s,a1
	bsr	pstr_cpy
	lea	dp_s2,a0
	lea	dp_t_slash,a1
	bsr	pstr_cat
	move.w	(sp)+,d0
	ext.l	d0
	moveq	#4,d1
	bsr	dp_str
	lea	dp_s2,a0
	lea	dp_s,a1
	bra	pstr_cat

; ---------------------------------------------------------------- configure (viewmode 10)
configcursor:
	movem.l	d3-d4,-(sp)
	move.w	GS_VIEWINDEX(a6),d0
	subq.w	#1,d0
	cmp.w	#9,d0
	bhi.s	.x
	lsl.w	#3,d0
	lea	dp_cfgrects,a0
	add.w	d0,a0
	movem.w	(a0),d0-d3
	moveq	#90,d4
	bsr	ms_rect
.x:	movem.l	(sp)+,d3-d4
	rts
; checkloc(l d0): out d0.w = 1 (Z clear) if the ship has gun node l
checkloc:
	lea	GS_SHIP+SHIP_SHIPTYPE(a6),a0
	cmp.w	#1,d0
	bne.s	.l2
	cmp.b	#SHPTYPE_HEAVY,(a0)
	bne.s	.y
	bra.s	.n
.l2:	cmp.w	#3,d0
	bhi.s	.l4
	cmp.w	#2,d0
	blo.s	.n
	cmp.b	#SHPTYPE_LIGHT,(a0)
	bne.s	.y
	bra.s	.n
.l4:	cmp.w	#5,d0
	bhi.s	.l6
	cmp.b	#SHPTYPE_SHUTTLE,1(a0)
	bne.s	.y
	bra.s	.n
.l6:	cmp.w	#7,d0
	bls.s	.y
	cmp.w	#8,d0
	bne.s	.l9
	cmp.b	#SHPTYPE_ASSAULT,1(a0)
	bne.s	.y
	bra.s	.n
.l9:	cmp.w	#9,d0
	bne.s	.l10
	cmp.b	#SHPTYPE_TRANSPORT,2(a0)
	bne.s	.y
	bra.s	.n
.l10:	cmp.w	#10,d0
	bne.s	.n
	cmp.b	#SHPTYPE_CRUISER,2(a0)
	beq.s	.y
.n:	moveq	#0,d0
	rts
.y:	moveq	#1,d0
	rts
; findgunnode(x d0, y d1): viewindex := the node clicked (if the ship has it); i (unit var)
findgunnode:
	move.w	dp_i,d2
	cmp.w	#29,d1
	blt.s	.r2
	cmp.w	#48,d1
	bgt.s	.r2
	lea	dp_gn_top,a0
	bra.s	.cols
.r2:	cmp.w	#60,d1
	blt.s	.r3
	cmp.w	#79,d1
	bgt.s	.r3
	lea	dp_gn_mid,a0
	bra.s	.cols
.r3:	cmp.w	#91,d1
	blt.s	.set
	cmp.w	#110,d1
	bgt.s	.set
	lea	dp_gn_bot,a0
.cols:	move.w	(a0)+,d1		; x ranges: lo, hi, node; lo = -1 ends
	bmi.s	.set
	cmp.w	d1,d0
	blt.s	.cn
	cmp.w	(a0),d0
	bgt.s	.cn
	move.w	2(a0),d2
	bra.s	.set
.cn:	addq.l	#4,a0
	bra.s	.cols
.set:	move.w	d2,dp_i
	tst.w	d2
	ble.s	.x
	move.w	d2,d0
	bsr	checkloc
	beq.s	.x
	move.w	dp_i,GS_VIEWINDEX(a6)
.x:	rts

; is ship.cargo[d0] a weapon (ID_DIRK .. ID_NOSHIELD-1)?  Z clear = yes
dp_isweapon:
	bsr	dp_cargoitem
	cmp.w	#ID_DIRK,d1
	blt.s	.n
	cmp.w	#ID_NOSHIELD,d1
	bge.s	.n
	moveq	#1,d1
	rts
.n:	moveq	#0,d1
	rts

displayconfigure:
	movem.l	d3-d6,-(sp)
	move.w	d0,d3
	TCOL	191
	BKCOL	5
	bsr	mousehide
	tst.w	GS_VIEWLEVEL(a6)
	bne.s	.c
	bsr	configcursor
.c:	cmp.w	#1,d3
	bne.s	.c2
	tst.w	GS_VIEWLEVEL(a6)	; 1: the previous node
	bne	.draw
.c1l:	move.w	GS_VIEWINDEX(a6),d0
	subq.w	#1,d0
	bgt.s	.c1s
	moveq	#10,d0
.c1s:	move.w	d0,GS_VIEWINDEX(a6)
	bsr	checkloc
	beq.s	.c1l
	bra	.draw
.c2:	cmp.w	#2,d3
	bne.s	.c3
	tst.w	GS_VIEWLEVEL(a6)	; 2: the next
	bne	.draw
.c2l:	move.w	GS_VIEWINDEX(a6),d0
	addq.w	#1,d0
	cmp.w	#10,d0
	ble.s	.c2s
	moveq	#0,d0
.c2s:	move.w	d0,GS_VIEWINDEX(a6)
	bsr	checkloc
	beq.s	.c2l
	bra	.draw
.c3:	cmp.w	#3,d3
	bne	.c4
	tst.w	GS_VIEWLEVEL(a6)
	bne.s	.c3w
	move.w	GS_VIEWINDEX(a6),d0	; inc(vi,5); vi := vi div 10; repeat inc(vi) (>10: 0) until checkloc
	addq.w	#5,d0
	ext.l	d0
	divs	#10,d0
	move.w	d0,GS_VIEWINDEX(a6)
	bra.s	.c2l
.c3w:	move.w	GS_VIEWINDEX2(a6),d4	; the previous weapon in cargo
	subq.w	#1,d4
	bsr	.pw
	tst.w	d4
	bgt.s	.wset
	move.w	#250,d4
	bsr	.pw
.wset:	move.w	d4,GS_VIEWINDEX2(a6)
	bra	.draw
.pw:	tst.w	d4
	ble.s	.pwx
	move.w	d4,d0
	bsr	dp_isweapon
	bne.s	.pwx
	subq.w	#1,d4
	bra.s	.pw
.pwx:	rts
.nw:	cmp.w	#251,d4
	bge.s	.nwx
	move.w	d4,d0
	bsr	dp_isweapon
	bne.s	.nwx
	addq.w	#1,d4
	bra.s	.nw
.nwx:	rts
.c4:	cmp.w	#4,d3
	bne.s	.c5
	tst.w	GS_VIEWLEVEL(a6)
	bne.s	.c4w
	move.w	GS_VIEWINDEX(a6),d0	; dec(vi,5); vi := vi div 10; repeat inc(vi) (<1: 10) until checkloc
	subq.w	#5,d0
	ext.l	d0
	divs	#10,d0
	move.w	d0,GS_VIEWINDEX(a6)
.c4l:	move.w	GS_VIEWINDEX(a6),d0
	addq.w	#1,d0
	bgt.s	.c4s
	moveq	#10,d0
.c4s:	move.w	d0,GS_VIEWINDEX(a6)
	bsr	checkloc
	beq.s	.c4l
	bra	.draw
.c4w:	move.w	GS_VIEWINDEX2(a6),d4	; the next weapon in cargo
	addq.w	#1,d4
	bsr	.nw
	cmp.w	#251,d4
	bne.s	.wset
	moveq	#1,d4
	bsr	.nw
	cmp.w	#251,d4
	bne.s	.wset
	moveq	#0,d4
	bra.s	.wset
.c5:	cmp.w	#5,d3
	bne.s	.c6
	st	d0
	bsr	removesystem
	bsr	mouseshow
	bra	.x
.c6:	cmp.w	#6,d3
	bne	.c7
	cmp.w	#1,GS_VIEWLEVEL(a6)
	bne.s	.c6b
	bsr	dp_cfg_ship		; back to the ship
	bra	.draw
.c6b:	move.w	GS_VIEWINDEX(a6),d0	; an empty node: choose a weapon to install
	bsr	dp_gun
	tst.w	d1
	bne	.c6old
	moveq	#0,d4			; a team installing here already?
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a0
	moveq	#3-1,d1
.c6t:	move.w	TEAM_EXTRA(a0),d0
	and.w	#15,d0
	cmp.w	GS_VIEWINDEX(a6),d0
	bne.s	.c6n
	cmp.w	#JOBTYPE_INSTALL,TEAM_JOBTYPE(a0)
	bne.s	.c6n
	cmp.w	#ID_DIRK,TEAM_JOB(a0)
	blt.s	.c6n
	cmp.w	#ID_NOSHIELD-1,TEAM_JOB(a0)
	bge.s	.c6n
	moveq	#1,d4
.c6n:	lea	TEAM_SIZEOF(a0),a0
	dbf	d1,.c6t
	move.w	d4,dp_i
	tst.w	d4
	bne	.c6busy
	move.w	#1,GS_VIEWLEVEL(a6)
	moveq	#1,d4
	bsr	.nw
	cmp.w	#251,d4
	bne.s	.c6v
	moveq	#0,d4
.c6v:	move.w	d4,GS_VIEWINDEX2(a6)
	BAR	16,26,278,114,5
	LINE	165,25,165,114,10
	LINE	164,25,164,115,2
	PSET	165,115,6
	PSET	164,25,6
	PXY	30,27,"Installable Weapons"
	bsr	setupweaponinfo
	SHOWPANEL 11,8,12
	bra	.draw
.c6busy:TCOL	94
	BKCOL	3
	PRTLN
	PRT	"ENGINEERING: Already installing a weapon at that node."
	bra	.draw
.c6old:	TCOL	94
	BKCOL	3
	PRTLN
	PRT	"ENGINEERING: We must remove the old weapon first."
	bra	.draw
.c7:	cmp.w	#7,d3
	bne	.draw
	bsr	dp_cfg_job
	tst.w	d0
	bmi	.x			; (installed: displayconfigure(6) has redrawn; exit)
	BKCOL	5
	TCOL	191
.draw:	tst.w	GS_VIEWLEVEL(a6)
	bne	.l1
	moveq	#1,d5			; level 0: every node's icon, the cursor after each
.n:	move.w	d5,d0
	bsr	checkloc
	beq.s	.nn
	move.w	d5,d0
	subq.w	#1,d0
	mulu	#6,d0
	lea	dp_cfgicons,a0
	add.w	d0,a0
	movem.w	(a0),d0-d1/d6		; x, y, kind
	move.w	d5,d2
	move.w	d0,-(sp)
	move.w	d5,d0
	movem.l	d1/d6,-(sp)
	bsr	dp_gun
	move.w	d1,d2
	movem.l	(sp)+,d1/d6
	move.w	(sp)+,d0
	move.l	d3,-(sp)
	move.w	d5,d3
	cmp.w	#1,d6
	bne.s	.k2
	bsr	sideshowweaponicon
	bra.s	.kd
.k2:	cmp.w	#2,d6
	bne.s	.k3
	bsr	showweaponicon
	bra.s	.kd
.k3:	cmp.w	#3,d6
	bne.s	.k4
	bsr	revshowweaponicon
	bra.s	.kd
.k4:	bsr	backshowweaponicon
.kd:	move.l	(sp)+,d3
.nn:	bsr	configcursor
	addq.w	#1,d5
	cmp.w	#11,d5
	bne.s	.n
	move.w	#10,dp_j
	bra	.done
.l1:	cmp.w	#1,GS_VIEWLEVEL(a6)
	bne	.done
	tst.w	GS_VIEWINDEX2(a6)
	ble	.done
	move.w	GS_VIEWINDEX2(a6),d0	; level 1: the weapons in cargo
	bsr	dp_isweapon
	bne.s	.l1a
	moveq	#4,d0
	bsr	displayconfigure
	bsr	mousehide
.l1a:	tst.w	GS_VIEWINDEX2(a6)
	ble.s	.l1z
	move.w	GS_VIEWINDEX2(a6),d0
	bsr	dp_cargoitem
	sub.w	#ID_DIRK-1,d1
	move.w	d1,d4
	move.w	d4,d0
	bsr	displayweaponstats
	move.w	d4,d2
	bra.s	.l1i
.l1z:	moveq	#0,d0
	bsr	displayweaponstats
	moveq	#0,d2
.l1i:	move.w	#172,d0
	moveq	#89,d1
	move.l	d3,-(sp)
	moveq	#0,d3
	bsr	showweaponicon
	move.l	(sp)+,d3
	move.w	GS_VIEWINDEX2(a6),d4	; after
	addq.w	#1,d4
	moveq	#6,d5
.af:	bsr	.nw
	move.w	#5,GS_BKCOLOR(a6)
	cmp.w	GS_VIEWINDEX2(a6),d4
	bne.s	.afb
	move.w	#179,GS_BKCOLOR(a6)
.afb:	cmp.w	#251,d4
	bge.s	.afn
	addq.w	#1,d5
	bsr	.wname
.afn:	addq.w	#1,d4
	cmp.w	#12,d5
	beq.s	.af2
	cmp.w	#250,d4
	ble.s	.af
.af2:	cmp.w	#12,d5
	bge.s	.bf
	move.w	d5,d1
	mulu	#6,d1
	add.w	#38,d1
	movem.l	d3-d4,-(sp)
	moveq	#30,d0
	move.w	#142,d2
	moveq	#114,d3
	moveq	#5,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
.bf:	move.w	GS_VIEWINDEX2(a6),d4	; before
	moveq	#7,d5
.bl:	bsr	.pw
	move.w	#5,GS_BKCOLOR(a6)
	cmp.w	GS_VIEWINDEX2(a6),d4
	bne.s	.blb
	move.w	#179,GS_BKCOLOR(a6)
.blb:	tst.w	d4
	ble.s	.bln
	subq.w	#1,d5
	bsr	.wname
.bln:	subq.w	#1,d4
	cmp.w	#1,d5
	beq.s	.bl2
	tst.w	d4
	bgt.s	.bl
.bl2:	cmp.w	#1,d5
	ble.s	.done
	move.w	d5,d3
	mulu	#6,d3
	add.w	#31,d3
	moveq	#30,d0
	moveq	#37,d1
	move.w	#142,d2
	move.l	d4,-(sp)
	moveq	#5,d4
	bsr	ms_bar
	move.l	(sp)+,d4
.done:	bsr	mouseshow
	BKCOL	3
.x:	movem.l	(sp)+,d3-d6
	rts
.wname:	move.w	d4,d0			; printxy(30, 31+y*6, cargo[ship.cargo[x]-ID_DIRK+1].name)
	bsr	dp_cargoitem
	move.w	d1,d0
	sub.w	#ID_DIRK-1,d0
	bsr	dp_cargoname
	moveq	#30,d0
	move.w	d5,d1
	mulu	#6,d1
	add.w	#31,d1
	bra	printxy

; displayconfigure com 6 at level 1: back to the ship with its node boxes
dp_cfg_ship:
	clr.w	GS_VIEWLEVEL(a6)
	BAR	16,26,278,114,5
	PSET	279,53,2
	PSET	279,83,2
	PSET	164,25,10
	PSET	165,115,2
	SHOWPANEL 10,7,12
	moveq	#60,d0
	moveq	#33,d1
	bsr	displayship2
	lea	GS_SHIP+SHIP_SHIPTYPE(a6),a0
	cmp.b	#SHPTYPE_HEAVY,(a0)
	beq.s	.s1
	GRAYB	29,59,50,80
.s1:	cmp.b	#SHPTYPE_LIGHT,GS_SHIP+SHIP_SHIPTYPE(a6)
	beq.s	.s2
	GRAYB	64,28,85,49
	GRAYB	64,90,85,111
.s2:	cmp.b	#SHPTYPE_SHUTTLE,GS_SHIP+SHIP_SHIPTYPE+1(a6)
	beq.s	.s3
	GRAYB	107,28,128,49
	GRAYB	107,90,128,111
.s3:	GRAYB	149,28,170,49
	GRAYB	149,90,170,111
	cmp.b	#SHPTYPE_ASSAULT,GS_SHIP+SHIP_SHIPTYPE+1(a6)
	beq.s	.s4
	GRAYB	127,59,148,80
.s4:	cmp.b	#SHPTYPE_TRANSPORT,GS_SHIP+SHIP_SHIPTYPE+2(a6)
	beq.s	.s5
	GRAYB	230,28,251,49
.s5:	cmp.b	#SHPTYPE_CRUISER,GS_SHIP+SHIP_SHIPTYPE+2(a6)
	bne.s	.s6
	GRAYB	230,90,251,111
.s6:	rts

; displayconfigure com 7: remove the node's weapon, or install the chosen one.
; out d0.w = -1 when a weapon was installed (displayconfigure(6) done: the caller exits)
dp_cfg_job:
	movem.l	d3-d4/a3,-(sp)
	tst.w	GS_VIEWLEVEL(a6)
	bne	.inst
	move.w	GS_VIEWINDEX(a6),d0
	bsr	dp_gun
	tst.w	d1
	beq	.x0
	move.w	d1,d3			; (kept across mouseshow)
	bsr	mouseshow		; remove: the weapon's name without trailing blanks
	add.w	#ID_DIRK-1,d3
	moveq	#0,d1			; i := 0; while (i < maxcargo) and (cargo[i].index <> w) do inc(i)
	lea	GS_CARGO-CARGO_SIZEOF+CARGO_INDEX(a6),a0
.f:	cmp.w	#MAXCARGO,d1
	bge.s	.fd
	cmp.w	(a0),d3
	beq.s	.fd
	lea	CARGO_SIZEOF(a0),a0
	addq.w	#1,d1
	bra.s	.f
.fd:	move.w	d1,dp_i
	move.w	d1,d0
	bsr	dp_cargoname
	move.l	a0,a1
	lea	dp_s4,a0
	bsr	pstr_cpy
	lea	dp_s4,a0		; while str1[length] = ' ' do dec(length)
.tr:	moveq	#0,d0
	move.b	(a0),d0
	beq.s	.tq
	cmp.b	#' ',0(a0,d0.w)
	bne.s	.tq
	subq.b	#1,(a0)
	bra.s	.tr
.tq:	lea	dp_s2,a0		; 'Remove '+str1+'?'
	lea	dp_t_remove,a1
	bsr	pstr_cpy
	lea	dp_s2,a0
	lea	dp_s4,a1
	bsr	pstr_cat
	lea	dp_s2,a0
	lea	dp_t_qm,a1
	bsr	pstr_cat
	lea	dp_s2,a0
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq.s	.mh
	bsr	dp_freeteam
	cmp.w	#4,d4
	bne.s	.rm
	PRTLN
	TCOL	94
	PRT	"ENGINEERING: No team available."
	bra.s	.mh
.rm:	move.w	d3,d0
	st	d1
	bsr	addcargo
	move.w	d3,TEAM_JOB(a3)
	move.w	#JOBTYPE_REMOVE,TEAM_JOBTYPE(a3)
	move.w	#1000,TEAM_TIMELEFT(a3)
	move.w	GS_VIEWINDEX(a6),d0
	lea	GS_SHIP+SHIP_GUNNODES-1(a6),a0
	clr.b	0(a0,d0.w)
.mh:	bsr	mousehide
	bra	.x0
.inst:	cmp.w	#1,GS_VIEWLEVEL(a6)
	bne	.x0
	tst.w	GS_VIEWINDEX2(a6)
	ble	.x0
	bsr	mouseshow
	PLEA	"Install this weapon?"
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq.s	.mh
	bsr	dp_freeteam
	cmp.w	#4,d4
	bne.s	.in
	PRTLN
	TCOL	94
	PRT	"ENGINEERING: No team available."
	bra.s	.mh
.in:	move.w	GS_VIEWINDEX2(a6),d0
	bsr	dp_cargoitem
	move.w	d1,TEAM_JOB(a3)
	move.w	GS_VIEWINDEX2(a6),d0	; numcargo - 1, or the slot empties
	add.w	d0,d0
	lea	GS_SHIP+SHIP_NUMCARGO-2(a6),a0
	cmp.w	#1,0(a0,d0.w)
	ble.s	.emp
	subq.w	#1,0(a0,d0.w)
	bra.s	.jt
.emp:	clr.w	0(a0,d0.w)
	lea	GS_SHIP+SHIP_CARGO-2(a6),a0
	clr.w	0(a0,d0.w)
.jt:	move.w	#JOBTYPE_INSTALL,TEAM_JOBTYPE(a3)
	move.w	GS_VIEWINDEX(a6),TEAM_EXTRA(a3)
	move.w	#1000,TEAM_TIMELEFT(a3)
	moveq	#6,d0
	bsr	displayconfigure
	moveq	#-1,d0
	bra.s	.x
.x0:	moveq	#0,d0
.x:	movem.l	(sp)+,d3-d4/a3
	rts

; ---------------------------------------------------------------- bots (viewmode 11)
; usecode.pas showbotstuff: what the chosen bot would gather here (by percentage)
showbotstuff:
	movem.l	d3-d7/a3-a4,-(sp)
	move.w	GS_CURPLAN(a6),d0
	bsr	dp_plan
	move.l	a0,a3
	moveq	#0,d6			; y: the number of bot rows above
	cmp.b	#7,PLANET_STATE(a3)
	beq.s	.st
	move.w	#ID_MINEBOT,d0
	bsr	incargo
	ble.s	.b2
	addq.w	#1,d6
.b2:	move.w	#ID_MANUFACTORY,d0
	bsr	incargo
	ble.s	.b3
	addq.w	#1,d6
.b3:	move.w	#ID_FABRICATOR,d0
	bsr	incargo
	ble.s	.clr
	addq.w	#1,d6
	bra.s	.clr
.st:	move.w	#ID_STARMINER,d0
	bsr	incargo
	ble.s	.clr
	addq.w	#1,d6
.clr:	move.w	d6,d1			; for i := 38+y*6 to 114: clear
	mulu	#6,d1
	add.w	#38,d1
	movem.l	d3-d4,-(sp)
	move.w	#166,d0
	move.w	#278,d2
	moveq	#114,d3
	moveq	#5,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
	btst	#0,PLANET_NOTES(a3)
	bne.s	.info
	move.w	d6,d1
	mulu	#6,d1
	add.w	#37,d1
	move.w	#170,d0
	PLEA	"No info available"
	bsr	printxy
	bra	.x
.info:	moveq	#0,d0
	move.b	PLANET_STATE(a3),d0
	bsr	getstuffamounts
	move.w	GS_VIEWINDEX2(a6),d0	; the list: elements, materials or components
	lea	u2_ele,a4
	moveq	#17,d5			; count
	move.w	#ID_FIRST_ELEMENT,d4	; first id
	moveq	#10,d3			; id step
	cmp.w	#1,d0
	beq.s	.go
	lea	u2_mat,a4
	moveq	#21,d5
	move.w	#ID_UNKNOWN_MATERIAL,d4
	moveq	#1,d3
	cmp.w	#2,d0
	beq.s	.go
	cmp.w	#5,d0
	beq.s	.go
	lea	u2_cmp,a4
	move.w	#ID_UNKNOWN_COMPONENT,d4
	cmp.w	#3,d0
	beq.s	.go
	cmp.w	#4,d0
	bne	.x			; (no list)
.go:	moveq	#0,d7			; total
	move.l	a4,a0
	move.w	d5,d0
	subq.w	#1,d0
.t:	add.w	(a0)+,d7
	dbf	d0,.t
.y:	cmp.w	#13,d6			; while y < 13: the biggest, its share
	bge	.x
	moveq	#0,d1			; mx
	moveq	#0,d2			; j
	moveq	#0,d0
.mx:	move.w	d0,-(sp)
	add.w	d0,d0
	move.w	0(a4,d0.w),d0
	cmp.w	d1,d0
	ble.s	.mn
	move.w	d0,d1
	move.w	(sp),d2
.mn:	move.w	(sp)+,d0
	addq.w	#1,d0
	cmp.w	d5,d0
	bne.s	.mx
	move.w	d2,d0			; ele[j] := 0
	add.w	d0,d0
	clr.w	0(a4,d0.w)
	tst.w	d1
	ble	.yn
	movem.w	d1-d2,-(sp)
	move.w	d1,d0			; str(mx*1000 div total:3, s); s := 'nn.n%'
	mulu	#1000,d0
	divu	d7,d0
	ext.l	d0
	and.l	#$ffff,d0
	moveq	#3,d1
	lea	dp_bs,a0
	bsr	int_str
	lea	dp_bs,a0
	addq.b	#2,(a0)
	move.b	3(a0),4(a0)
	move.b	#'.',3(a0)
	move.b	#'%',5(a0)
	movem.w	(sp)+,d1-d2
	move.w	d1,-(sp)
	move.w	d2,d0			; printxy(163, 37+y*6, CargoName(first + j*step))
	mulu	d3,d0
	add.w	d4,d0
	bsr	cargoname
	move.w	#163,d0
	move.w	d6,d1
	mulu	#6,d1
	add.w	#37,d1
	bsr	printxy
	move.w	(sp)+,d1
	cmp.w	#ID_UNKNOWN_COMPONENT,d4	; components: ' 100%' when it is all
	bne.s	.pc
	cmp.w	d7,d1
	bne.s	.pc
	PLEA	" 100%"
	bra.s	.pp
.pc:	lea	dp_bs,a0
.pp:	move.w	#248,d0
	move.w	d6,d1
	mulu	#6,d1
	add.w	#37,d1
	bsr	printxy
.yn:	addq.w	#1,d6
	bra	.y
.x:	movem.l	(sp)+,d3-d7/a3-a4
	rts

; incargo(item d0) > 0 ?  (flags from d0.w)
dp_has:
	bsr	incargo
	tst.w	d0
	rts
; viewindex2 := the bot after / before (displaybotinfo com 3 / 4 at level 2); d0 = 0 up, 1 down
dp_botcycle:
	movem.l	d3,-(sp)
	move.w	d0,d3
	move.w	GS_CURPLAN(a6),d0
	bsr	dp_plan
	cmp.b	#7,PLANET_STATE(a0)
	beq	.star
	move.w	GS_VIEWINDEX2(a6),d0
	tst.w	d3
	bne.s	.down
	cmp.w	#1,d0			; up: 1 -> fab, else manuf; 2 -> minebot, else fab; else manuf, minebot
	bne.s	.u2
	lea	dp_bc_u1,a1
	bra.s	.try
.u2:	cmp.w	#2,d0
	bne.s	.u3
	lea	dp_bc_u2,a1
	bra.s	.try
.u3:	lea	dp_bc_u3,a1
	bra.s	.try
.down:	cmp.w	#1,d0
	bne.s	.d2
	lea	dp_bc_d1,a1
	bra.s	.try
.d2:	cmp.w	#2,d0
	bne.s	.d3
	lea	dp_bc_d2,a1
	bra.s	.try
.d3:	lea	dp_bc_d3,a1
.try:	move.w	(a1)+,d0		; (item, viewindex2) twice: the first one in cargo wins
	beq.s	.x
	move.w	(a1)+,d3
	move.l	a1,-(sp)
	bsr	dp_has
	move.l	(sp)+,a1
	ble.s	.try
	move.w	d3,GS_VIEWINDEX2(a6)
	bra.s	.x
.star:	move.w	#ID_STARMINER,d0
	bsr	dp_has
	ble.s	.x
	move.w	#5,GS_VIEWINDEX2(a6)
.x:	movem.l	(sp)+,d3
	rts
; cargo[] record of the item d0 (artifacts: getartifactname) -> a0 = name  (displaybotinfo lists)
dp_itemname:
	cmp.w	#ID_ARTIFACT_OFFSET,d0
	ble.s	.c
	bsr	getartifactname
	move.w	#MAXCARGO,dp_i
	lea	GS_CARGO+(MAXCARGO-1)*CARGO_SIZEOF+CARGO_NAME(a6),a0
	rts
.c:	lea	GS_CARGO+CARGO_INDEX(a6),a0
	moveq	#1,d1
.l:	cmp.w	(a0),d0
	beq.s	.f
	lea	CARGO_SIZEOF(a0),a0
	addq.w	#1,d1
	bra.s	.l
.f:	move.w	d1,dp_i
	lea	CARGO_NAME-CARGO_INDEX(a0),a0
	rts

displaybotinfo:
	movem.l	d3-d6/a3,-(sp)
	move.w	d0,d3
	TCOL	191
	BKCOL	5
	bsr	mousehide
	move.w	GS_CURPLAN(a6),d0
	bsr	dp_plan
	move.l	a0,a3			; tempplan^[curplan]
	cmp.w	#3,d3
	bne	.c4
	move.w	GS_VIEWLEVEL(a6),d0	; 3: up
	bne.s	.c3a
	move.w	GS_VIEWINDEX(a6),d4	; the previous cache slot with something
	subq.w	#1,d4
	bsr	.cprev
	tst.w	d4
	bgt.s	.c3s
	moveq	#1,d4
	bsr	.cnext
	cmp.w	#7,d4
	ble.s	.c3s
	moveq	#0,d4
.c3s:	move.w	d4,GS_VIEWINDEX(a6)
	bra	.draw
.c3a:	cmp.w	#2,d0
	bne.s	.c3b
	moveq	#0,d0
	bsr	dp_botcycle
	bsr	showbotstuff
	bra	.draw
.c3b:	move.w	GS_VIEWINDEX2(a6),d4	; the previous cargo slot with something
	subq.w	#1,d4
	bsr	.gprev
	tst.w	d4
	bne.s	.c3c
	move.w	#250,d4
	bsr	.gprev
.c3c:	move.w	d4,GS_VIEWINDEX2(a6)
	bra	.draw
.cprev:	tst.w	d4			; while (cache[vi] = 0) and (vi > 0) do dec(vi)
	ble.s	.cpx
	move.w	d4,d0
	add.w	d0,d0
	tst.w	PLANET_CACHE-2(a3,d0.w)
	bne.s	.cpx
	subq.w	#1,d4
	bra.s	.cprev
.cpx:	rts
.cnext:	cmp.w	#8,d4			; while (cache[vi] = 0) and (vi < 8) do inc(vi)
	bge.s	.cnx
	move.w	d4,d0
	add.w	d0,d0
	tst.w	PLANET_CACHE-2(a3,d0.w)
	bne.s	.cnx
	addq.w	#1,d4
	bra.s	.cnext
.cnx:	rts
.gprev:	tst.w	d4			; while (vi2 > 0) and (ship.cargo[vi2] = 0) do dec(vi2)
	ble.s	.gpx
	move.w	d4,d0
	bsr	dp_cargoitem
	tst.w	d1
	bne.s	.gpx
	subq.w	#1,d4
	bra.s	.gprev
.gpx:	rts
.gnext:	cmp.w	#251,d4			; while (vi2 < 251) and (ship.cargo[vi2] = 0) do inc(vi2)
	bge.s	.gnx
	move.w	d4,d0
	bsr	dp_cargoitem
	tst.w	d1
	bne.s	.gnx
	addq.w	#1,d4
	bra.s	.gnext
.gnx:	rts
.c4:	cmp.w	#4,d3
	bne.s	.c5
	move.w	GS_VIEWLEVEL(a6),d0	; 4: down
	bne.s	.c4a
	move.w	GS_VIEWINDEX(a6),d4
	addq.w	#1,d4
	bsr	.cnext
	cmp.w	#7,d4
	ble	.c3s
	moveq	#7,d4
	bsr	.cprev
	bra	.c3s
.c4a:	cmp.w	#2,d0
	bne.s	.c4b
	moveq	#1,d0
	bsr	dp_botcycle
	bsr	showbotstuff
	bra	.draw
.c4b:	move.w	GS_VIEWINDEX2(a6),d4
	addq.w	#1,d4
	bsr	.gnext
	cmp.w	#251,d4
	bne	.c3c
	moveq	#1,d4
	bsr	.gnext
	cmp.w	#251,d4
	bne	.c3c
	moveq	#0,d4
	bra	.c3c
.c5:	cmp.w	#5,d3
	bne.s	.c6
	st	d0
	bsr	removerightside
	bsr	mouseshow
	bra	.x
.c6:	cmp.w	#6,d3
	bne	.c7
	tst.w	GS_VIEWLEVEL(a6)
	bne	.c6b
	moveq	#1,d4			; a free cache slot?
.c6f:	cmp.w	#8,d4
	bge.s	.c6g
	move.w	d4,d0
	add.w	d0,d0
	tst.w	PLANET_CACHE-2(a3,d0.w)
	beq.s	.c6g
	addq.w	#1,d4
	bra.s	.c6f
.c6g:	move.w	d4,dp_i
	cmp.w	#7,d4
	ble.s	.c6h
	TCOL	94
	BKCOL	3
	PRTLN
	PRT	"ENGINEERING: Cache full."
	TCOL	191
	BKCOL	5
	bra	.draw
.c6h:	move.w	d4,GS_VIEWINDEX(a6)
	moveq	#1,d4
	bsr	.gnext
	move.w	d4,GS_VIEWINDEX2(a6)
	cmp.w	#251,d4
	bne.s	.c6i
	TCOL	94
	BKCOL	3
	PRTLN
	PRT	"ENGINEERING: Nothing in cargo."
	TCOL	191
	BKCOL	5
	clr.w	GS_VIEWLEVEL(a6)
	bra	.draw
.c6i:	PXY	168,27,"    Add to Cache     "
	move.w	#1,GS_VIEWLEVEL(a6)
	BAR	166,37,278,115,5
	SHOWPANEL 11,14,12
	bra	.draw
.c6b:	PXY	169,27,"   Cache Contents    "
	BAR	166,37,278,115,5
	clr.w	GS_VIEWLEVEL(a6)
	SHOWPANEL 14,15,16
	moveq	#1,d4
.c6c:	cmp.w	#8,d4
	bge.s	.c6d
	move.w	d4,d0
	add.w	d0,d0
	tst.w	PLANET_CACHE-2(a3,d0.w)
	bne.s	.c6e
	addq.w	#1,d4
	bra.s	.c6c
.c6d:	moveq	#1,d4
.c6e:	move.w	d4,GS_VIEWINDEX(a6)
	bra	.draw
.c7:	cmp.w	#7,d3
	bne	.c8
	move.w	GS_VIEWLEVEL(a6),d0
	bne.s	.c7b
	move.w	GS_VIEWINDEX(a6),d4	; take from the cache
	ble	.draw
	move.w	d4,d0
	add.w	d0,d0
	move.w	PLANET_CACHE-2(a3,d0.w),d0
	beq	.draw
	BKCOL	3
	sf	d1
	bsr	addcargo
	beq.s	.c7a
	move.w	d4,d0
	add.w	d0,d0
	clr.w	PLANET_CACHE-2(a3,d0.w)
.c7a:	moveq	#3,d0
	bsr	displaybotinfo
	bsr	mousehide
	TCOL	191
	bra	.draw
.c7b:	cmp.w	#1,d0
	bne	.c7c
	PXY	169,27,"   Cache Contents    "	; put into the cache
	BAR	166,37,278,115,5
	clr.w	GS_VIEWLEVEL(a6)
	move.w	GS_VIEWINDEX2(a6),d0
	bsr	dp_cargoitem
	move.w	d1,d0
	bsr	dp_itemname		; (finds cargo[i]: its index is the item)
	move.w	dp_i,d0
	mulu	#CARGO_SIZEOF,d0
	lea	GS_CARGO-CARGO_SIZEOF+CARGO_INDEX(a6),a0
	move.w	0(a0,d0.l),d4
	move.w	GS_VIEWINDEX(a6),d0
	add.w	d0,d0
	move.w	d4,PLANET_CACHE-2(a3,d0.w)
	move.w	d4,d0
	bsr	removecargo
	SHOWPANEL 14,15,16
	bra	.draw
.c7c:	cmp.w	#2,d0
	bne	.draw
	bsr	mouseshow		; send a bot
	move.w	GS_VIEWINDEX2(a6),d0
	bsr	dp_botname
	lea	dp_s2,a0
	lea	dp_t_send,a1
	bsr	pstr_cpy
	lea	dp_s2,a0
	lea	dp_s,a1
	bsr	pstr_cat
	lea	dp_s2,a0
	lea	dp_t_qm,a1
	bsr	pstr_cat
	lea	dp_s2,a0
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq.s	.c7n
	move.b	PLANET_BOTS(a3),d0
	and.b	#$f8,d0
	or.b	GS_VIEWINDEX2+1(a6),d0
	move.b	d0,PLANET_BOTS(a3)
	move.w	GS_VIEWINDEX2(a6),d0
	add.w	#ID_PROBOT,d0
	bsr	removecargo
	BAR	166,37,278,115,5
	clr.w	GS_VIEWLEVEL(a6)
	SHOWPANEL 14,15,16
.c7n:	TCOL	191
	BKCOL	5
	bsr	mousehide
	bra	.draw
.c8:	cmp.w	#8,d3
	bne	.draw
	tst.w	GS_VIEWLEVEL(a6)
	bne	.draw
	moveq	#7,d0
	and.b	PLANET_BOTS(a3),d0
	bne	.c8r
	cmp.b	#7,PLANET_STATE(a3)	; bot info: which bots can go
	beq.s	.c8s
	move.w	#ID_MINEBOT,d0
	bsr	dp_has
	bgt.s	.c8p
	move.w	#ID_MANUFACTORY,d0
	bsr	dp_has
	bgt.s	.c8p
	move.w	#ID_FABRICATOR,d0
	bsr	dp_has
	ble	.c8no
.c8p:	PXY	164,27,"       Bot Info      "
	bsr	dp_clear
	moveq	#4,d4
	move.w	#ID_MINEBOT,d0
	bsr	dp_has
	ble.s	.c8q
	moveq	#1,d4
	bra.s	.c8v
.c8q:	move.w	#ID_MANUFACTORY,d0
	bsr	dp_has
	ble.s	.c8v
	moveq	#2,d4
.c8v:	move.w	d4,GS_VIEWINDEX2(a6)
	move.w	#2,GS_VIEWLEVEL(a6)
	bsr	showbotstuff
	SHOWPANEL 11,16,12
	bra	.draw
.c8s:	move.w	#ID_STARMINER,d0
	bsr	dp_has
	ble.s	.c8no
	PXY	164,27,"       Bot Info      "
	bsr	dp_clear
	moveq	#5,d4
	bra.s	.c8v
.c8no:	TCOL	94
	BKCOL	3
	PRTLN
	PRT	"ENGINEERING: No bots available."
	TCOL	191
	BKCOL	5
	bra	.draw
.c8r:	bsr	mouseshow		; recall the bot
	moveq	#7,d0
	and.b	PLANET_BOTS(a3),d0
	bsr	dp_botname
	lea	dp_s2,a0
	lea	dp_t_recall,a1
	bsr	pstr_cpy
	lea	dp_s2,a0
	lea	dp_s,a1
	bsr	pstr_cat
	lea	dp_s2,a0
	lea	dp_t_qm,a1
	bsr	pstr_cat
	lea	dp_s2,a0
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	tst.w	d0
	beq.s	.c8x
	moveq	#7,d0
	and.b	PLANET_BOTS(a3),d0
	add.w	#ID_PROBOT,d0
	sf	d1
	bsr	addcargo
	beq.s	.c8x
	and.b	#$f8,PLANET_BOTS(a3)
.c8x:	TCOL	191
	BKCOL	5
	bsr	mousehide
.draw:	move.w	GS_VIEWLEVEL(a6),d0
	bne	.l1
	moveq	#0,d5			; level 0: the cache
	moveq	#1,d4
.l0:	move.w	#5,GS_BKCOLOR(a6)
	cmp.w	GS_VIEWINDEX(a6),d4
	bne.s	.l0b
	move.w	#179,GS_BKCOLOR(a6)
.l0b:	move.w	d4,d0
	add.w	d0,d0
	move.w	PLANET_CACHE-2(a3,d0.w),d0
	beq.s	.l0n
	addq.w	#1,d5
	bsr	dp_itemname
	move.w	#167,d0
	move.w	d5,d1
	mulu	#10,d1
	add.w	#32,d1
	bsr	printxy
.l0n:	addq.w	#1,d4
	cmp.w	#8,d4
	bne.s	.l0
	cmp.w	#7,d5
	bge	.done
	move.w	d5,d1
	mulu	#10,d1
	add.w	#42,d1
	movem.l	d3-d4,-(sp)
	move.w	#166,d0
	move.w	#278,d2
	moveq	#114,d3
	moveq	#5,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
	bra	.done
.l1:	cmp.w	#1,d0
	bne	.l2
	move.w	GS_VIEWINDEX2(a6),d4	; level 1: the cargo (after, then before)
	addq.w	#1,d4
	moveq	#6,d5
.af:	bsr	.gnext
	move.w	#5,GS_BKCOLOR(a6)
	cmp.w	GS_VIEWINDEX2(a6),d4
	bne.s	.afb
	move.w	#179,GS_BKCOLOR(a6)
.afb:	cmp.w	#251,d4
	bge.s	.afn
	addq.w	#1,d5
	move.w	d4,d0
	bsr	dp_cargoitem
	move.w	d1,d0
	bsr	dp_itemname
	move.w	#167,d0
	move.w	d5,d1
	mulu	#6,d1
	add.w	#37,d1
	bsr	printxy
.afn:	addq.w	#1,d4
	cmp.w	#12,d5
	beq.s	.af2
	cmp.w	#250,d4
	ble.s	.af
.af2:	cmp.w	#12,d5
	bge.s	.bf
	move.w	d5,d1
	mulu	#6,d1
	add.w	#43,d1
	movem.l	d3-d4,-(sp)
	move.w	#166,d0
	move.w	#278,d2
	moveq	#116,d3
	moveq	#5,d4
	bsr	ms_bar
	movem.l	(sp)+,d3-d4
.bf:	move.w	GS_VIEWINDEX2(a6),d4
	moveq	#7,d5
.bl:	bsr	.gprev
	move.w	#5,GS_BKCOLOR(a6)
	cmp.w	GS_VIEWINDEX2(a6),d4
	bne.s	.blb
	move.w	#179,GS_BKCOLOR(a6)
.blb:	tst.w	d4
	ble.s	.bln
	subq.w	#1,d5
	move.w	d4,d0
	bsr	dp_cargoitem
	move.w	d1,d0
	bsr	dp_itemname
	move.w	#167,d0
	move.w	d5,d1
	mulu	#6,d1
	add.w	#37,d1
	bsr	printxy
.bln:	subq.w	#1,d4
	tst.w	d5
	beq.s	.bl2
	tst.w	d4
	bgt.s	.bl
.bl2:	tst.w	d5
	ble	.done
	move.w	d5,d3
	mulu	#6,d3
	add.w	#37,d3
	move.w	#166,d0
	moveq	#37,d1
	move.w	#278,d2
	move.l	d4,-(sp)
	moveq	#5,d4
	bsr	ms_bar
	move.l	(sp)+,d4
	bra	.done
.l2:	cmp.w	#2,d0
	bne	.done
	moveq	#0,d5			; level 2: the bots to drop
	cmp.b	#7,PLANET_STATE(a3)
	beq.s	.l2s
	move.w	#ID_MINEBOT,d0
	bsr	dp_has
	ble.s	.l2b
	BKSEL	GS_VIEWINDEX2,1
	PLEA	"Drop Minebot"
	bsr	.row
.l2b:	move.w	#ID_MANUFACTORY,d0
	bsr	dp_has
	ble.s	.l2c
	BKSEL	GS_VIEWINDEX2,2
	PLEA	"Drop Manufactory"
	bsr	.row
.l2c:	move.w	#ID_FABRICATOR,d0
	bsr	dp_has
	ble.s	.done
	BKSEL	GS_VIEWINDEX2,4
	PLEA	"Drop Fabricator"
	bsr	.row
	bra.s	.done
.l2s:	move.w	#ID_STARMINER,d0
	bsr	dp_has
	ble.s	.done
	BKSEL	GS_VIEWINDEX2,5
	PLEA	"Drop Starmine"
	bsr	.row
.done:	bsr	mouseshow
	BKCOL	3
.x:	movem.l	(sp)+,d3-d6/a3
	rts
.row:	move.w	#167,d0			; printxy(167, 37+y*6, a0); inc(y)
	move.w	d5,d1
	mulu	#6,d1
	add.w	#37,d1
	bsr	printxy
	addq.w	#1,d5
	rts
; the bot's name for the request: viewindex2 / bots and 7 d0 -> dp_s
dp_botname:
	lea	dp_t_minebot,a1
	cmp.w	#1,d0
	beq.s	.c
	lea	dp_t_manuf,a1
	cmp.w	#2,d0
	beq.s	.c
	lea	dp_t_fabric,a1
	cmp.w	#4,d0
	beq.s	.c
	lea	dp_t_starminer,a1
	cmp.w	#5,d0
	bne.s	.x
.c:	lea	dp_s,a0
	bra	pstr_cpy
.x:	rts

	section	data
dp_t_engteam:	dc.b	17,"Engineering Team "
dp_t_space:	dc.b	1," "
dp_t_8sp:	dc.b	8,"        "
dp_t_mins:	dc.b	5," Mins"
dp_t_pct3:	dc.b	4,"%   "
dp_t_gw:	dc.b	6," GW   "
dp_t_gj:	dc.b	6," GJ   "
dp_t_cum:	dc.b	5," Cu.M"
dp_t_sysdmg:	dc.b	14,"System Damage:"
dp_t_pct:	dc.b	1,"%"
dp_t_kkm:	dc.b	6," KKM  "
dp_t_slash:	dc.b	1,"/"
dp_t_comma:	dc.b	1,","
dp_t_000:	dc.b	6,"  0.00"
dp_t_32000:	dc.b	6,"/32000"
dp_t_zero:	dc.b	1,"0"
dp_t_unknown:	dc.b	7,"Unknown"
dp_t_cache:	dc.b	11,"Cache = ?/7"
dp_t_void:	dc.b	20,"Void Dwellers       "
dp_t_nolife:	dc.b	20,"No Life             "
dp_t_short:	dc.b	20,"Short Chain Proteins"
dp_t_long:	dc.b	20,"Long Chain Proteins "
dp_t_simple:	dc.b	20,"Simple Protoplasms  "
dp_t_complex:	dc.b	20,"Complex Protoplasms "
dp_t_single:	dc.b	20,"Singlecelled        "
dp_t_remove:	dc.b	7,"Remove "
dp_t_qm:	dc.b	1,"?"
dp_t_send:	dc.b	5,"Send "
dp_t_recall:	dc.b	7,"Recall "
dp_t_minebot:	dc.b	7,"minebot"
dp_t_manuf:	dc.b	12,"manufactuary"
dp_t_fabric:	dc.b	10,"fabricator"
dp_t_starminer:	dc.b	9,"starminer"
	even
dp_diff:
	dc.b	3,"Min"
	ds.b	2
	dc.b	3,"Avg"
	ds.b	2
	dc.b	3,"Max"
	ds.b	2
dp_msgs:
	dc.b	4,"None"
	ds.b	1
	dc.b	4,"Some"
	ds.b	1
	dc.b	4," All"
	ds.b	1
dp_fonts:
	dc.b	5," Iron"
	dc.b	5,"Clean"
	dc.b	5,"Block"
teamdata:
	dc.b	13,"Idle         "
	dc.b	13,"Power Supply "
	dc.b	12,"Shield Crtl "
	ds.b	1
	dc.b	12,"Weapons Crtl"
	ds.b	1
	dc.b	13,"Engine       "
	dc.b	13,"Life Support "
	dc.b	13,"Comm.        "
	dc.b	12,"Computer AI "
	ds.b	1
	dc.b	12,"Hull Damage "
	ds.b	1
	dc.b	13,"Shield       "
	dc.b	13,"Weapon       "
	dc.b	13,"Device       "
	dc.b	12,"Component   "
	ds.b	1
	dc.b	12,"Material    "
	ds.b	1
	dc.b	12,"Artifact    "
	ds.b	1
	dc.b	13,"Other        "
dp_jobtypes:
	dc.b	7,"Repair "
	ds.b	2
	dc.b	8,"Install "
	ds.b	1
	dc.b	7,"Remove "
	ds.b	2
	dc.b	7,"Create "
	ds.b	2
	dc.b	8,"Disjoin "
	ds.b	1
	dc.b	9,"Research "
alientypes:
	dc.b	5,"Avian"
	ds.b	7
	dc.b	7,"Monoped"
	ds.b	5
	dc.b	5,"Biped"
	ds.b	7
	dc.b	6,"Triped"
	ds.b	6
	dc.b	9,"Quadraped"
	ds.b	3
	dc.b	7,"Octaped"
	ds.b	5
	dc.b	8,"Aquatics"
	ds.b	4
	dc.b	5,"Fungi"
	ds.b	7
	dc.b	10,"Carniferns"
	ds.b	2
	dc.b	11,"Crystalline"
	ds.b	1
	dc.b	8,"Symbiots"
	ds.b	4
dp_sectors:
	dc.b	7,"  ALPHA"
	dc.b	7,"   BETA"
	dc.b	7,"  GAMMA"
	dc.b	7,"  DELTA"
	dc.b	7,"EPSILON"
	dc.b	7,"   ZETA"
	dc.b	7,"    ETA"
	dc.b	7,"  THETA"
dp_starsizes:
	dc.b	7,"  Giant"
	dc.b	7,"  Large"
	dc.b	7,"   Tiny"
dp_plansizes:
	dc.b	7,"   Tiny"
	dc.b	7,"  Small"
	dc.b	7," Medium"
	dc.b	7,"  Large"
	dc.b	7,"  Giant"
dp_states:
	dc.b	7,"Gaseous"
	dc.b	7," Active"
	dc.b	7," Stable"
	dc.b	7,"Ea.Life"
	dc.b	7,"Ad.Life"
	dc.b	7,"  Dying"
	dc.b	7,"   Dead"
	dc.b	7,"   Star"
dp_t_aalife:	dc.b	7,"Aa.Life"
dp_t_chaosms:
	dc.b	11,"Chaosms    "
	dc.b	11,"Communes   "
	dc.b	11,"Hierarchies"
dp_diets:
	dc.b	20,"Carnivorous         "
	ds.b	1
	dc.b	20,"Herbivorous         "
	ds.b	1
	dc.b	20,"Omnivorous          "
	ds.b	1
	dc.b	20,"Cannibalistic       "
	ds.b	1
	dc.b	20,"Photosynthetic      "
	ds.b	1
dp_logtitles:
	dc.b	21," Ship Logs: Systems  "
	dc.b	21," Ship Logs: Cache    "
	dc.b	21," Ship Logs: Contacts "
	dc.b	21," Ship Logs: Scans    "
	even
dp_natives:
	dc.w	93
	dc.b	20,"Sengzhac            "
	ds.b	1
	dc.w	138
	dc.b	19,"D'phak             "
	ds.b	2
	dc.w	45
	dc.b	20,"Ermigen             "
	ds.b	1
	dc.w	221
	dc.b	20,"Titarian            "
	ds.b	1
	dc.w	78
	dc.b	20,"Quai Pa'loi         "
	ds.b	1
	dc.w	171
	dc.b	20,"Icon                "
	ds.b	1
	dc.w	191
	dc.b	20,"The Guild           "
	ds.b	1
	dc.w	-1
dp_cfgrects:	dc.w	30,60,49,79, 65,29,84,48, 65,91,84,110, 108,29,127,48, 108,91,127,110
		dc.w	150,29,169,48, 150,91,169,110, 128,60,147,79, 231,29,250,48, 231,91,250,110
; per gun node: x, y, how its icon is shown (1 sideshow, 2 show, 3 revshow, 4 backshow)
dp_cfgicons:	dc.w	30,60,1, 65,29,1, 65,91,1, 108,29,2, 108,91,3, 150,29,2, 150,91,3, 128,60,1
		dc.w	231,29,4, 231,91,4
; findgunnode: x ranges (lo, hi, node) per row band, -1 ends
dp_gn_top:	dc.w	65,85,2, 108,128,4, 150,170,6, 230,250,9, -1
dp_gn_mid:	dc.w	30,50,1, 128,148,8, -1
dp_gn_bot:	dc.w	65,85,3, 108,128,5, 150,170,7, 230,250,10, -1
dp_alienpix:	dc.w	-1,-2, -2,-1, -2,-2, 2,1, 1,2, 2,2
; displaybotinfo com 3/4 at level 2: (item, viewindex2) pairs, the first in cargo wins
dp_bc_u1:	dc.w	ID_FABRICATOR,4, ID_MANUFACTORY,2, 0
dp_bc_u2:	dc.w	ID_MINEBOT,1, ID_FABRICATOR,4, 0
dp_bc_u3:	dc.w	ID_MANUFACTORY,2, ID_MINEBOT,1, 0
dp_bc_d1:	dc.w	ID_MANUFACTORY,2, ID_FABRICATOR,4, 0
dp_bc_d2:	dc.w	ID_FABRICATOR,4, ID_MINEBOT,1, 0
dp_bc_d3:	dc.w	ID_MINEBOT,1, ID_MANUFACTORY,2, 0
; computegraph: round(exp(abs(orbit-6))/10) by orbit (orbit 0: 18, the star's noise)
dp_noise:	dc.b	18,15,5,2,1,0,0,0
dp_fn_shippix:	dc.b	"DATA",92,"SHIPPIX.DTA",0
	include	"dptab.i"		; build/: tools/mkdptab.py (circle rows, pieslice rows)
	include	"gconst.i"		; build/: tools/mkgconst.py (the game's extended literals)
	even

	section	bss
dp_s:		ds.b	32
dp_s1:		ds.b	4
dp_s2:		ds.b	80
dp_s3:		ds.b	24
dp_s4:		ds.b	24
dp_s7:		ds.b	10
dp_bs:		ds.b	12
dp_a:		ds.w	1
dp_b:		ds.w	1
dp_i:		ds.w	1
dp_j:		ds.w	1
dp_index:	ds.w	1
dp_c1:		ds.w	1
dp_c2:		ds.w	1
dp_wx:		ds.w	1
dp_wy:		ds.w	1
dp_sx:		ds.w	1
dp_tmpd:	ds.l	2
dp_xd:		ds.l	2
dp_zd:		ds.l	2
dp_ang:		ds.l	2
dp_shippixbuf:	ds.l	1
