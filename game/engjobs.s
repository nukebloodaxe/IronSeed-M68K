; engjobs.s - crewtick.pas's engineering jobs other than repairs and installs (EngBuildFinish,
; EngDisassembleFinish, research) for MAIN.PRG, and utils2.pas addgunnode and
; dothatartifactthing. Called from crewtick.s ct_engtick with a3 = the team, d7 = its number.
;
; ct_buildjob / ct_decomposejob / ct_researchjob   (a3, d7)          trashes: d0-d2/a0-a2
; addgunnode     utils2.pas addgunnode                               trashes: d0-d2/a0-a2
; dothatartifactthing  in: d0.w artifact                             trashes: d0-d2/a0-a2

	section	text
; the progress of a build / decompose / research: timeleft -= 5, and 5 or 10 more for skill
ej_progress:
	subq.w	#5,TEAM_TIMELEFT(a3)
	moveq	#2,d0
	moveq	#40,d1
	moveq	#10,d2
	bsr	ct_skilltest
	tst.w	d0
	beq.s	.x
	moveq	#2,d0
	moveq	#40,d1
	moveq	#10,d2
	bsr	ct_skilltest
	tst.w	d0
	beq.s	.f
	sub.w	#10,TEAM_TIMELEFT(a3)
	rts
.f:	subq.w	#5,TEAM_TIMELEFT(a3)
.x:	rts

; addcargo2 in the background, addcargo otherwise (item d0, forced)
ej_addcargo:
	st	d1
	tst.b	ct_bg
	bne	addcargo2
	bra	addcargo

; CrewMessage(31, engineering, a0)
ej_msg:
	moveq	#31,d0
	moveq	#2,d1
	bra	ct_message

; ej_msg with prefix a0 + CargoName(d0) + suffix a1
ej_msgname:
	movem.l	a3-a4,-(sp)
	move.l	a0,a3
	move.l	a1,a4
	bsr	cargoname		; a0 = the name (mu_s)
	move.l	a0,a1
	lea	ej_s2,a0
	bsr	pstr_cpy
	lea	ej_s,a0
	move.l	a3,a1
	bsr	pstr_cpy
	lea	ej_s,a0
	lea	ej_s2,a1
	bsr	pstr_cat
	lea	ej_s,a0
	move.l	a4,a1
	bsr	pstr_cat
	lea	ej_s,a0
	movem.l	(sp)+,a3-a4
	bra.s	ej_msg

ct_buildjob:
	movem.l	d3-d6,-(sp)
	bsr	ej_progress
	tst.w	TEAM_TIMELEFT(a3)
	bgt	.x
	bsr	rebuildcargoreserve
	move.w	TEAM_JOB(a3),d6
	cmp.w	#ID_FUEL_NODULES,d6
	bne.s	.n1
	move.w	GS_SHIP+SHIP_FUELMAX(a6),GS_SHIP+SHIP_FUEL(a6)
	move.w	#1002,d0
	bsr	event
	bra	.done
.n1:	cmp.w	#ID_REINFORCE_HULL,d6
	bne.s	.n2
	move.w	GS_SHIP+SHIP_HULLMAX(a6),d0
	add.w	#25,d0
	cmp.w	#5000,d0
	ble.s	.h
	move.w	d6,d0
	bsr	ej_addcargo
	bra	.done
.h:	add.w	#15,GS_SHIP+SHIP_HULLMAX(a6)
	lea	ej_t_hull,a0
	bsr	ej_msg
	bra	.done
.n2:	cmp.w	#ID_INCREASE_THRUST,d6
	bne.s	.n3
	move.w	GS_SHIP+SHIP_ACCELMAX(a6),d0
	add.w	#10,d0
	cmp.w	#1100,d0
	ble.s	.t
	move.w	d6,d0
	bsr	ej_addcargo
	bra	.done
.t:	add.w	#10,GS_SHIP+SHIP_ACCELMAX(a6)
	lea	ej_t_thrust,a0
	bsr	ej_msg
	bra	.done
.n3:	cmp.w	#ID_ADD_CARGO_SPACE,d6
	bne.s	.n4
	moveq	#0,d0
	move.w	GS_SHIP+SHIP_CARGOMAX(a6),d0
	add.l	#75,d0
	cmp.l	#20000,d0
	ble.s	.c
	move.w	d6,d0
	bsr	ej_addcargo
	bra	.done
.c:	add.w	#75,GS_SHIP+SHIP_CARGOMAX(a6)
	lea	ej_t_cargo,a0
	bsr	ej_msg
	bra	.done
.n4:	cmp.w	#ID_INSTALL_GUN_NODE,d6
	bne.s	.n5
	bsr	addgunnode
	lea	ej_t_node,a0
	bsr	ej_msg
	bra	.done
.n5:	cmp.w	#ID_MIND_ENHANCERS,d6
	bne	.other
	lea	GS_SHIP+SHIP_CREW(a6),a0	; the crew member with the lowest stat
	moveq	#0,d3
	move.b	CREW_MEN(a0),d3		; a
	moveq	#1,d4			; b
	moveq	#1,d5
.mi:	move.w	d5,d0
	bsr	ct_crew
	moveq	#0,d0
	move.b	CREW_EMO(a0),d0
	cmp.w	d3,d0
	bge.s	.m1
	move.w	d0,d3
	move.w	d5,d4
.m1:	move.b	CREW_PHY(a0),d0
	cmp.w	d3,d0
	bge.s	.m2
	move.w	d0,d3
	move.w	d5,d4
.m2:	move.b	CREW_MEN(a0),d0
	cmp.w	d3,d0
	bge.s	.m3
	move.w	d0,d3
	move.w	d5,d4
.m3:	addq.w	#1,d5
	cmp.w	#6,d5
	ble.s	.mi
	move.w	d4,d0			; +15 (to 99) on the stat that is lowest: emo, phy or men
	bsr	ct_crew
	lea	CREW_EMO(a0),a1
	cmp.b	(a1),d3
	beq.s	.mp
	lea	CREW_PHY(a0),a1
	cmp.b	(a1),d3
	beq.s	.mp
	lea	CREW_MEN(a0),a1
	cmp.b	(a1),d3
	bne.s	.mn
.mp:	add.b	#15,(a1)
	cmp.b	#99,(a1)
	bls.s	.mn
	move.b	#99,(a1)
.mn:	move.w	d4,d0			; s := the name, trailing blanks cut
	bsr	ct_crew
	lea	CREW_NAME(a0),a1
	lea	ej_s2,a0
	bsr	pstr_cpy
	lea	ej_s2,a0
	moveq	#0,d0
	move.b	(a0),d0
.mt:	cmp.b	#' ',0(a0,d0.w)
	bne.s	.mte
	subq.w	#1,d0
	bra.s	.mt
.mte:	move.b	d0,(a0)
	lea	ej_s,a0
	lea	ej_t_mind,a1
	bsr	pstr_cpy
	lea	ej_s,a0
	lea	ej_s2,a1
	bsr	pstr_cat
	lea	ej_s,a0
	lea	ej_t_dot,a1
	bsr	pstr_cat
	moveq	#31,d0
	move.w	d4,d1
	lea	ej_s,a0
	bsr	ct_message
	bra.s	.done
.other:	move.w	d6,d0			; an item: into the hold; part of a bigger build: go on with it
	bsr	ej_addcargo
	move.w	TEAM_EXTRA(a3),d5
	beq.s	.done
	cmp.w	d6,d5
	beq.s	.done
	clr.w	TEAM_JOBTYPE(a3)
	clr.w	TEAM_TIMELEFT(a3)
	clr.w	TEAM_JOB(a3)
	bsr	rebuildcargoreserve
	move.b	ct_bg,d0		; StartBuild(background, extra, extra, team)
	move.w	d5,d1
	move.w	d5,d2
	move.w	d7,d3
	bsr	startbuild
	lea	ej_t_parts,a0
	tst.w	d0
	beq.s	.sb
	lea	ej_t_expert,a0
	cmp.w	#-1,d0
	beq.s	.sb
	cmp.w	#-3,d0
	beq.s	.sb
	lea	ej_t_internal,a0
	cmp.w	#-2,d0
	bne.s	.x
.sb:	move.w	d5,d0
	lea	ej_t_dot,a1
	bsr	ej_msgname
	bra.s	.x
.done:	clr.w	TEAM_JOBTYPE(a3)
	clr.w	TEAM_TIMELEFT(a3)
	cmp.w	#ID_MIND_ENHANCERS,TEAM_JOB(a3)
	beq.s	.z
	move.w	TEAM_JOB(a3),d0
	lea	ej_t_synth,a0
	lea	ej_t_compl,a1
	bsr	ej_msgname
.z:	clr.w	TEAM_JOB(a3)
.x:	movem.l	(sp)+,d3-d6
	rts

ct_decomposejob:
	movem.l	d3-d4,-(sp)
	bsr	ej_progress
	tst.w	TEAM_TIMELEFT(a3)
	bgt	.x
	move.w	TEAM_JOB(a3),d0		; EngDisassembleFinish: its three parts into the hold
	lea	cr_create+CREATION_SIZEOF,a0
	tst.b	cr_read			; (creation.dta: the creation screen reads it once; else now)
	bne.s	.r
	st	cr_read
	movem.l	d0/a0,-(sp)
	lea	cr_fn_create,a0
	lea	cr_create+CREATION_SIZEOF,a1
	move.l	#CREATEARRAY_SIZEOF,d0
	bsr	load_exact
	lea	cr_fn_item,a0
	lea	cr_iteminfo,a1
	move.l	#TOTALCREATION*II_SIZE,d0
	bsr	load_exact
	movem.l	(sp)+,d0/a0
.r:	moveq	#1,d1
.f:	cmp.w	CREATION_INDEX(a0),d0
	beq.s	.ff
	lea	CREATION_SIZEOF(a0),a0
	addq.w	#1,d1
	cmp.w	#TOTALCREATION,d1
	ble.s	.f
	bra	fatal			; ('Disassemble error!')
.ff:	move.l	a0,-(sp)
	moveq	#3-1,d4
	lea	CREATION_PARTS(a0),a0
	move.l	a0,(sp)
.p:	move.l	(sp),a0
	move.w	(a0)+,d0
	move.l	a0,(sp)
	bsr	ej_addcargo
	dbf	d4,.p
	addq.l	#4,sp
	clr.w	TEAM_TIMELEFT(a3)
	clr.w	TEAM_JOB(a3)
	clr.w	TEAM_JOBTYPE(a3)
	lea	ej_t_disasm,a0
	bsr	ej_msg
.x:	movem.l	(sp)+,d3-d4
	rts

ct_researchjob:
	move.l	d3,-(sp)
	bsr	ej_progress
	tst.w	TEAM_TIMELEFT(a3)
	bgt.s	.x
	cmp.w	#ID_ART_SHUNT_DRIVE,TEAM_JOB(a3)	; (the shunt drive waits for the bridge)
	bne.s	.go
	tst.b	ct_bg
	bne.s	.x
.go:	clr.w	TEAM_TIMELEFT(a3)
	clr.w	TEAM_JOBTYPE(a3)
	lea	ej_t_research,a0
	bsr	ej_msg
	move.w	TEAM_JOB(a3),d0
	bsr	dothatartifactthing
	clr.w	TEAM_JOB(a3)
.x:	move.l	(sp)+,d3
	rts

; ---------------------------------------------------------------- utils2.pas
addgunnode:
	movem.l	d3-d5/a3,-(sp)
	move.w	GS_TCOLOR(a6),-(sp)
	lea	GS_SHIP+SHIP_GUNNODES(a6),a0	; old := gunnodes
	lea	ej_old,a1
	moveq	#10-1,d0
.o:	move.b	(a0)+,(a1)+
	dbf	d0,.o
	lea	GS_SHIP+SHIP_SHIPTYPE-1(a6),a3
	cmp.b	#SHPTYPE_STATEGIC,SHPTYP_HEAVYNESS(a3)
	bne.s	.lt
	cmp.b	#SHPTYPE_STORM,SHPTYP_PURPOSE(a3)
	bne.s	.pu
	cmp.b	#SHPTYPE_CRUISER,SHPTYP_VESSEL(a3)
	bne.s	.ve
	move.w	#ID_INSTALL_GUN_NODE,d0	; at the maximum already
	st	d1
	bsr	addcargo2
	addq.l	#2,sp
	bra	.x
.ve:	addq.b	#1,SHPTYP_VESSEL(a3)
	bra.s	.re
.pu:	addq.b	#1,SHPTYP_PURPOSE(a3)
	bra.s	.re
.lt:	cmp.b	#SHPTYPE_LIGHT,SHPTYP_HEAVYNESS(a3)
	bne.s	.st
	move.b	#SHPTYPE_HEAVY,SHPTYP_HEAVYNESS(a3)
	bra.s	.re
.st:	move.b	#SHPTYPE_STATEGIC,SHPTYP_HEAVYNESS(a3)
.re:	lea	GS_SHIP+SHIP_GUNNODES(a6),a0	; the old nodes again, in the new layout's places
	moveq	#10-1,d0
.z:	clr.b	(a0)+
	dbf	d0,.z
	moveq	#0,d4			; j
	moveq	#1,d5			; i
.i:	lea	ej_old-1,a0
	tst.b	0(a0,d5.w)
	beq.s	.n
.r:	addq.w	#1,d4
	move.w	d4,d0
	bsr	checkloc
	beq.s	.r
	lea	ej_old-1,a0
	lea	GS_SHIP+SHIP_GUNNODES-1(a6),a1
	move.b	0(a0,d5.w),0(a1,d4.w)
.n:	addq.w	#1,d5
	cmp.w	#10,d5
	ble.s	.i
	cmp.w	#10,GS_VIEWMODE(a6)
	bne.s	.t
	tst.b	GS_DONE(a6)
	beq.s	.t
	sf	d0
	bsr	cleanright
	bsr	readyconfigure
.t:	move.w	(sp)+,GS_TCOLOR(a6)
.x:	movem.l	(sp)+,d3-d5/a3
	rts

dothatartifactthing:
	movem.l	d3-d4,-(sp)
	move.w	d0,d3
	cmp.w	#ID_ART_SHUNT_DRIVE,d3
	bge	.big
	move.w	#1000,d0		; a := random(1000)
	bsr	mt_random
	move.w	d0,d4
	cmp.w	#50,d4
	blt	.l1
	cmp.w	#99,d4
	bgt.s	.l2
	moveq	#5,d0			; fuel capacity
	bsr	mt_random
	addq.w	#1,d0
	mulu	#10,d0
	add.w	GS_SHIP+SHIP_FUELMAX(a6),d0
	cmp.w	#1500,d0
	ble.s	.f
	move.w	#1500,d0
.f:	move.w	d0,GS_SHIP+SHIP_FUELMAX(a6)
	lea	ej_t_fuel,a0
	bra	.sc2
.l2:	cmp.w	#699,d4
	bgt	.none
	move.w	d4,d0			; an insight: crew a div 100 gains xp*random(15)+6 /100
	ext.l	d0
	divu	#100,d0
	move.w	d0,d4
	bsr	ct_crew
	move.l	CREW_XP(a0),d0
	move.l	d0,-(sp)
	moveq	#15,d0
	bsr	mt_random
	addq.w	#6,d0
	move.l	(sp)+,d1
	bsr	ej_mul32		; t := t*i
	FSSE				; t := round(t/100)
	bsr	fp_ldi
	FLDI	100
	bsr	fp_div
	bsr	fp_rnd
	move.l	d0,d1
	move.w	d4,d0
	moveq	#2,d2
	bsr	addxp
	move.w	d4,d0
	lea	ej_t_insight,a0
	bsr	showchar
	bra	.x
.l1:	cmp.w	#1,d4
	bne.s	.l3
	moveq	#20,d0			; thrust
	bsr	mt_random
	addq.w	#1,d0
	mulu	#5,d0
	add.w	GS_SHIP+SHIP_ACCELMAX(a6),d0
	cmp.w	#1100,d0
	ble.s	.a
	move.w	#1100,d0
.a:	move.w	d0,GS_SHIP+SHIP_ACCELMAX(a6)
	lea	ej_t_thrust2,a0
	bra.s	.sc2
.l3:	cmp.w	#2,d4
	bne.s	.none
	moveq	#40,d0			; hull
	bsr	mt_random
	add.w	#11,d0
	mulu	#10,d0
	add.w	GS_SHIP+SHIP_HULLMAX(a6),d0
	cmp.w	#30000,d0
	bls.s	.h
	move.w	#30000,d0
.h:	move.w	d0,GS_SHIP+SHIP_HULLMAX(a6)
	lea	ej_t_hull2,a0
	bra.s	.sc2
.none:	lea	ej_t_nothing,a0
.sc2:	moveq	#2,d0
	bsr	showchar
	bra	.x
.big:	bne.s	.b2			; the shunt drive
	moveq	#36,d0
	bsr	chevent
	tst.w	d0
	bne	.x
	move.w	#ID_ART_SHUNT_DRIVE,d0	; addcargo(shunt drive, true); viewmode(2) := 0
	st	d1
	bsr	addcargo
	clr.w	GS_VIEWMODE(a6)
	clr.w	GS_VIEWMODE2(a6)
	lea	GS_SHIP+SHIP_OPTIONS+OPT_AUTOSAVE-1(a6),a0	; no autosave on this journey
	move.b	(a0),-(sp)
	clr.b	(a0)
	move.w	#2500,d0		; redoscreen(random(2500) x3): FPC draws the arguments right to
	bsr	mt_random		; left (z, y, x: seen in the oracle's code)
	move.w	d0,-(sp)
	move.w	#2500,d0
	bsr	mt_random
	move.w	d0,-(sp)
	move.w	#2500,d0
	bsr	mt_random
	move.w	(sp)+,d1
	move.w	(sp)+,d2
	bsr	redoscreen
	move.b	(sp)+,GS_SHIP+SHIP_OPTIONS+OPT_AUTOSAVE-1(a6)
	lea	GS_SHIP+SHIP_OPTIONS+OPT_MSGS-1(a6),a0	; showchar(2, 'Whoops! ...') with messages on
	move.b	(a0),-(sp)
	move.b	#2,(a0)
	moveq	#2,d0
	lea	ej_t_whoops,a0
	bsr	showchar
	move.b	(sp)+,GS_SHIP+SHIP_OPTIONS+OPT_MSGS-1(a6)
	moveq	#36,d0
	bsr	event
	bra	.x
.b2:	cmp.w	#ID_ART_THERMAL_PLATING,d3
	bne.s	.b3
	lea	ej_t_thermo,a0
	bsr	ej_forcedchar
	moveq	#18,d0
	bsr	event
	bra.s	.x
.b3:	cmp.w	#ID_ART_ERMIGEN_DATA_TAPES,d3
	bne.s	.b4
	moveq	#30,d0
	bsr	event
	bra.s	.x
.b4:	move.w	d3,d0			; another: back into the hold
	st	d1
	bsr	addcargo
	lea	ej_t_noinfo,a0
	bsr	ej_forcedchar
.x:	movem.l	(sp)+,d3-d4
	rts
; showchar(2, a0) with the messages option forced to 2
ej_forcedchar:
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_MSGS-1(a6),-(sp)
	move.b	#2,GS_SHIP+SHIP_OPTIONS+OPT_MSGS-1(a6)
	moveq	#2,d0
	bsr	showchar
	move.b	(sp)+,GS_SHIP+SHIP_OPTIONS+OPT_MSGS-1(a6)
	rts
; d0.l := d1.l * d0.w (signed long times small word; low 32 bits)
ej_mul32:
	move.l	d2,-(sp)
	move.l	d1,d2
	swap	d2
	mulu	d0,d2			; high part
	swap	d2
	clr.w	d2
	mulu	d0,d1			; low part
	add.l	d2,d1
	move.l	d1,d0
	move.l	(sp)+,d2
	rts

	section	data
ej_t_hull:	dc.b	17,9,"Hull reinforced."
ej_t_thrust:	dc.b	23,"Acceleration increased."
ej_t_cargo:	dc.b	22,"Cargo space increased."
ej_t_node:	dc.b	22,"Weapon Node Assembled."
ej_t_mind:	dc.b	27,"Mind Drugs administered to "
ej_t_dot:	dc.b	1,"."
ej_t_parts:	dc.b	30,"Insufficent parts to continue "
ej_t_expert:	dc.b	32,"Insufficent expertise to finish "
ej_t_internal:	dc.b	32,"Internal error trying to build: "
ej_t_synth:	dc.b	13,"Synthesis of "
ej_t_compl:	dc.b	16," completed, sir!"
ej_t_disasm:	dc.b	29,"Disassmebling completed, sir!"
ej_t_research:	dc.b	33,"Artifact research completed, sir!"
ej_t_fuel:	dc.b	31,"We have improved fuel capacity."
ej_t_insight:	dc.b	42,"The artifact analysis has been insightful."
ej_t_thrust2:	dc.b	35,"We have improved thrust efficiency."
ej_t_hull2:	dc.b	35,"We have improved hull distribution."
ej_t_nothing:	dc.b	20,"Nothing new learned."
ej_t_thermo:	dc.b	34,"We can create Thermal ThermoPlast!"
ej_t_noinfo:	dc.b	37,"No new information from the artifact."
	even
	section	bss
ej_old:		ds.b	10
ej_s:		ds.b	256
ej_s2:		ds.b	256
	even
	section	text

	section	data
ej_t_whoops:	dc.b	50,"Whoops! Didn't know the Shunt Drive would do that!"
	even
	section	text
