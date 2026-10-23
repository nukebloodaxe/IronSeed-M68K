; crewtick.s - crewtick.pas for MAIN.PRG: the game clock's tick (GameTick): ship power, the
; engineering teams' repairs, the crew's stress, sanity, skills and experience, the date; and
; weird.pas tickpending, utils.pas addxp. Jobs other than repairs (building, installing,
; disassembling, research), insanity's messages, the planet bots' day and crew messages in the
; background (showchar) are not ported yet (notported).
;
; gametick   in: d0.b background, d1.w ticks                      trashes: d0-d2/a0-a2
; addxp      in: d0.w crew 1-6, d1.l amount, d2.w drawmode (1: print the message)
; resetcrew  crewtick.pas ResetCrew

JOBTYPE_REPAIR	equ	0
DMG_POWER	equ	1

	section	text
resetcrew:
	move.w	#-1,ct_lastalienid
	rts

gametick:
	movem.l	d3-d4,-(sp)
	move.b	d0,ct_bg
	move.w	d1,d3
	move.w	d3,d0
	move.b	ct_bg,d1
	bsr	tickpending
.t:	tst.w	d3
	ble	.x
	subq.w	#1,d3
	bsr	ct_shiptick
	bsr	ct_engtick
	bsr	ct_sectick
	lea	GS_SHIP+SHIP_STARDATE(a6),a0	; stardate[5] += 5
	addq.w	#5,8(a0)
	cmp.w	#99,8(a0)
	ble.s	.t
	bsr	ct_researchtick
	bsr	ct_sanitytick
	bsr	ct_psytick
	bsr	ct_medtick
	lea	GS_SHIP+SHIP_STARDATE(a6),a0
	moveq	#0,d0			; stardate[4] += stardate[5] div 100; [5] := [5] mod 100
	move.w	8(a0),d0
	divu	#100,d0
	add.w	d0,6(a0)
	swap	d0
	move.w	d0,8(a0)
	cmp.w	#19,6(a0)
	ble.s	.t
	bsr	ct_daytick
	lea	GS_SHIP+SHIP_STARDATE(a6),a0
	moveq	#0,d0			; [2] += [4] div 20; [4] := [4] mod 20
	move.w	6(a0),d0
	divu	#20,d0
	add.w	d0,2(a0)
	swap	d0
	move.w	d0,6(a0)
	cmp.w	#19,2(a0)
	ble.s	.t
	moveq	#0,d0			; [1] += [2] div 20; [2] := [2] mod 20
	move.w	2(a0),d0
	divu	#20,d0
	add.w	d0,(a0)
	swap	d0
	move.w	d0,2(a0)
	cmp.w	#19,(a0)
	ble	.t
	moveq	#0,d0			; [3] += [1] div 20; [1] := [1] mod 20
	move.w	(a0),d0
	divu	#20,d0
	add.w	d0,4(a0)
	swap	d0
	move.w	d0,(a0)
	bra	.t
.x:	movem.l	(sp)+,d3-d4
	rts

; a0 := ship.crew[d0] (1-6)
ct_crew:
	move.w	d0,-(sp)
	subq.w	#1,d0
	mulu	#CREW_SIZEOF,d0
	lea	GS_SHIP+SHIP_CREW(a6),a0
	add.w	d0,a0
	move.w	(sp)+,d0
	rts

; CrewMessage(colour d0, crew d1, msg a0)
ct_message:
	tst.b	ct_bg
	bne	notported		; showchar
	movem.l	d3-d4/a3,-(sp)
	move.l	a0,a3
	move.w	d1,d3
	move.w	GS_TCOLOR(a6),d4
	move.w	d0,GS_TCOLOR(a6)
	bsr	println
	lea	ct_s,a0			; crewtitles[crew] + ': ' + msg
	move.w	d3,d0
	mulu	#12,d0
	lea	us_crewtitles,a1
	add.w	d0,a1
	bsr	pstr_cpy
	lea	ct_s,a0
	lea	ct_colon,a1
	bsr	pstr_cat
	lea	ct_s,a0
	move.l	a3,a1
	bsr	pstr_cat
	lea	ct_s,a0
	bsr	print
	move.w	d4,GS_TCOLOR(a6)
	movem.l	(sp)+,d3-d4/a3
	rts

; SanityTest(crew d0, difficulty d1): out d0.w = 1 passed (Z clear)
ct_sanitytest:
	bsr	ct_crew
	moveq	#0,d2
	move.b	CREW_SAN(a0),d2
	bra.s	ct_test
; PerformanceTest(crew d0, difficulty d1)
ct_perftest:
	bsr	ct_crew
	moveq	#0,d2
	move.b	CREW_PERF(a0),d2
	; fall through: random(x+dif) < x, x >= 5, dif >= 1 (an expression: FPC's int64 random)
ct_test:
	cmp.w	#5,d2
	bgt.s	.a
	moveq	#5,d2
.a:	tst.w	d1
	bgt.s	.b
	moveq	#1,d1
.b:	move.w	d2,-(sp)
	move.w	d2,d0
	add.w	d1,d0
	bsr	mt_random64
	cmp.w	(sp)+,d0
	blt.s	.y
	moveq	#0,d0
	rts
.y:	moveq	#1,d0
	rts

; CrewStress(crew d0, difficulty d1)
ct_stress:
	move.w	d0,-(sp)
	bsr	ct_crew
	moveq	#0,d2
	move.b	CREW_PERF(a0),d2
	sub.w	d2,d1
	bsr	ct_sanitytest
	move.w	(sp)+,d1
	tst.w	d0
	bne.s	.x
	move.w	d1,d0
	bsr	ct_crew
	cmp.b	#99,CREW_STATUS(a0)
	bhs.s	.x
	addq.b	#1,CREW_STATUS(a0)
.x:	rts

; SkillTest(crew d0, difficulty d1, learn d2): out d0.w = 1 passed
ct_skilltest:
	movem.l	d3-d6,-(sp)
	move.w	d0,d3
	move.w	d1,d4
	move.w	d2,d5
	bsr	ct_crew
	moveq	#0,d6
	move.b	CREW_SKILL(a0),d6	; ski
	cmp.w	#5,d6
	bgt.s	.a
	moveq	#5,d6
.a:	move.w	d4,d1			; dif
	bgt.s	.b
	moveq	#1,d1
.b:	move.w	d1,-(sp)
	move.w	d6,d0			; random(ski + dif): FPC's int64 random
	add.w	d1,d0
	bsr	mt_random64
	move.w	(sp)+,d1
	cmp.w	d6,d0
	bge.s	.f
	move.w	d3,d0			; passed: CrewStress(crew, 0)
	moveq	#0,d1
	bsr	ct_stress
	moveq	#1,d6
	bra.s	.l
.f:	sub.w	d6,d1			; failed: CrewStress(crew, abs(dif-ski))
	bpl.s	.ab
	neg.w	d1
.ab:	move.w	d3,d0
	bsr	ct_stress
	moveq	#0,d6
.l:	move.w	#1000,d0		; if random(1000) < learn then addxp(crew, difficulty, not bg)
	bsr	mt_random
	cmp.w	d5,d0
	bge.s	.x
	move.w	d3,d0
	move.w	d4,d1
	ext.l	d1
	moveq	#1,d2
	tst.b	ct_bg
	beq.s	.ad
	moveq	#0,d2
.ad:	bsr	addxp
.x:	move.w	d6,d0
	movem.l	(sp)+,d3-d6
	rts

; ShipTick: secondary power
ct_shiptick:
	lea	GS_SHIP(a6),a1
	cmp.w	#ID_REFLECTIVEHULL,SHIP_SHIELD(a1)
	bgt	notported		; a powered shield draws from the battery
	cmp.w	#31980,SHIP_BATTERY(a1)
	bge.s	.full
	moveq	#100,d0			; += round((100-damages[POWER])/4) (banker's on .5)
	sub.b	SHIP_DAMAGES+DMG_POWER-1(a1),d0
	and.w	#$ff,d0
	move.w	d0,d1
	lsr.w	#2,d0
	and.w	#3,d1
	cmp.w	#2,d1
	blt.s	.r
	bgt.s	.u
	btst	#0,d0
	beq.s	.r
.u:	addq.w	#1,d0
.r:	add.w	d0,SHIP_BATTERY(a1)
	bra.s	.n
.full:	move.w	#32000,SHIP_BATTERY(a1)
.n:	tst.w	SHIP_BATTERY(a1)
	bpl.s	.x
	moveq	#94,d0
	moveq	#0,d1
	lea	ct_s_power,a0
	bsr	ct_message
	clr.w	GS_SHIP+SHIP_SHIELDLEVEL(a6)
	clr.w	GS_SHIP+SHIP_BATTERY(a6)
.x:	rts

; EngTick: the three engineering teams (repairs; other jobs not ported)
ct_engtick:
	movem.l	d3-d7/a3,-(sp)
	moveq	#1,d7			; j
.team:	move.w	d7,d0
	subq.w	#1,d0
	lsl.w	#3,d0
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a3
	add.w	d0,a3
	tst.w	TEAM_JOBTYPE(a3)
	bne	notported		; install, remove, build, disassemble, research
	move.w	TEAM_JOB(a3),d6
	cmp.w	#8,d6
	beq	.hull
	tst.w	d6
	ble	.next
	cmp.w	#7,d6
	bgt	.next
	subq.w	#5,TEAM_TIMELEFT(a3)	; a system: repair one point now and then
	moveq	#4,d0
	bsr	mt_random
	tst.w	d0
	bne	.next
	bsr	ct_eng2
	beq	.next
	lea	GS_SHIP+SHIP_DAMAGES-1(a6),a0
	tst.b	0(a0,d6.w)
	beq.s	.z
	subq.b	#1,0(a0,d6.w)
	cmp.w	#5,TEAM_TIMELEFT(a3)
	ble.s	.z
	subq.w	#5,TEAM_TIMELEFT(a3)
.z:	lea	GS_SHIP+SHIP_DAMAGES-1(a6),a0
	tst.b	0(a0,d6.w)
	bne	.next
	moveq	#0,d4			; the next job: nextjob d4, nexttime d5
	moveq	#0,d5
	moveq	#1,d3
.nj:	cmp.w	#8,d3
	bne.s	.nd
	move.w	GS_SHIP+SHIP_HULLINTEGRITY(a6),d0
	cmp.w	GS_SHIP+SHIP_HULLMAX(a6),d0
	bge.s	.nd
	moveq	#8,d4			; (no break: i = 8 is the last anyway)
	move.w	GS_SHIP+SHIP_HULLMAX(a6),d5
	sub.w	d0,d5
	mulu	#30,d5
	bra.s	.nn
.nd:	lea	GS_SHIP+SHIP_DAMAGES-1(a6),a0	; damages[i] (i = 8: the byte after the array,
	moveq	#0,d0			; shieldopt[1], as the original reads it)
	move.b	0(a0,d3.w),d0
	beq.s	.nn
	move.w	d3,d4
	move.w	d0,d5
	mulu	#70,d5
	bra.s	.nf
.nn:	addq.w	#1,d3
	cmp.w	#8,d3
	ble.s	.nj
.nf:	bsr	ct_others		; the other teams on the same repair follow
	move.w	d5,TEAM_TIMELEFT(a3)
	move.w	d6,d0			; repairname[job] + ' repaired, sir!'
	subq.w	#1,d0
	mulu	#16,d0
	lea	ct_repairname,a1
	add.w	d0,a1
	lea	ct_s2,a0
	bsr	pstr_cpy
	lea	ct_s2,a0
	lea	ct_s_repaired,a1
	bsr	pstr_cat
	moveq	#31,d0
	moveq	#2,d1
	lea	ct_s2,a0
	bsr	ct_message
	move.w	d4,TEAM_JOB(a3)
	bra	.next
.hull:	subq.w	#5,TEAM_TIMELEFT(a3)	; the hull: one point now and then
	moveq	#2,d0
	bsr	mt_random
	tst.w	d0
	bne	.next
	bsr	ct_eng2
	beq	.next
	move.w	GS_SHIP+SHIP_HULLINTEGRITY(a6),d0
	cmp.w	GS_SHIP+SHIP_HULLMAX(a6),d0
	bge.s	.hz
	addq.w	#1,GS_SHIP+SHIP_HULLINTEGRITY(a6)
	cmp.w	#5,TEAM_TIMELEFT(a3)
	ble.s	.hz
	subq.w	#5,TEAM_TIMELEFT(a3)
.hz:	move.w	GS_SHIP+SHIP_HULLINTEGRITY(a6),d0
	cmp.w	GS_SHIP+SHIP_HULLMAX(a6),d0
	bne.s	.next
	moveq	#0,d4
	moveq	#0,d5
	moveq	#1,d3
.hj:	lea	GS_SHIP+SHIP_DAMAGES-1(a6),a0
	moveq	#0,d0
	move.b	0(a0,d3.w),d0
	beq.s	.hn
	move.w	d3,d4
	move.w	d0,d5
	mulu	#70,d5
	bra.s	.hf
.hn:	addq.w	#1,d3
	cmp.w	#7,d3
	ble.s	.hj
.hf:	bsr	ct_others
	moveq	#31,d0
	moveq	#2,d1
	lea	ct_s_hull,a0
	bsr	ct_message
	move.w	d4,TEAM_JOB(a3)
	move.w	d5,TEAM_TIMELEFT(a3)
.next:	addq.w	#1,d7
	cmp.w	#3,d7
	ble	.team
	movem.l	(sp)+,d3-d7/a3
	rts

; two engineering skill tests (both must pass; the second only after the first): Z clear if both
ct_eng2:
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
.x:	rts

; the teams i <> j (d7) repairing the same job (d6) take nextjob d4, nexttime d5
ct_others:
	lea	GS_SHIP+SHIP_ENGRTEAM(a6),a0
	moveq	#1,d0
.l:	cmp.w	d7,d0
	beq.s	.n
	tst.w	TEAM_JOBTYPE(a0)
	bne.s	.n
	cmp.w	TEAM_JOB(a0),d6
	bne.s	.n
	move.w	d5,TEAM_TIMELEFT(a0)
	move.w	d4,TEAM_JOB(a0)
.n:	addq.l	#TEAM_SIZEOF,a0
	addq.w	#1,d0
	cmp.w	#3,d0
	ble.s	.l
	rts

ct_sectick:
	move.w	GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6),d0
	cmp.w	ct_lastalienid,d0
	beq.s	.x
	move.w	d0,ct_lastalienid
	cmp.w	#16000,d0
	bge.s	.x
	move.w	#191,d0
	moveq	#4,d1
	lea	ct_s_alien,a0
	bra	ct_message
.x:	rts

; PsyTick: the crew's stress fades now and then
ct_psytick:
	movem.l	d3-d4,-(sp)
	moveq	#1,d3
.l:	move.w	d3,d0
	bsr	ct_crew
	moveq	#0,d4
	move.b	CREW_STATUS(a0),d4	; d := -status
	beq.s	.n
	moveq	#2,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.n
	moveq	#1,d0			; SkillTest(1, 99-abs(d), 10)
	moveq	#99,d1
	sub.w	d4,d1
	moveq	#10,d2
	bsr	ct_skilltest
	tst.w	d0
	beq.s	.n
	move.w	d3,d0
	bsr	ct_crew
	subq.b	#1,CREW_STATUS(a0)
.n:	addq.w	#1,d3
	cmp.w	#6,d3
	ble.s	.l
	movem.l	(sp)+,d3-d4
	rts

; ComputeSkill / ComputePerformance / ComputeSanity (crew d0): out d0.w, 0-99
;   round(0.4 phy - 0.2 emo + 0.6 men), round(0.6 phy + 0.4 emo - 0.2 men),
;   round(-0.2 phy + 0.6 emo + 0.4 men) (multiples of 0.2: never a tie)
ct_computeskill:
	lea	ct_wskill,a1
	bra.s	ct_compute
ct_computeperf:
	lea	ct_wperf,a1
	bra.s	ct_compute
ct_computesanity:
	lea	ct_wsan,a1
ct_compute:
	bsr	ct_crew
	moveq	#0,d0
	move.b	CREW_PHY(a0),d0
	muls	(a1)+,d0
	moveq	#0,d1
	move.b	CREW_EMO(a0),d1
	muls	(a1)+,d1
	add.l	d1,d0
	moveq	#0,d1
	move.b	CREW_MEN(a0),d1
	muls	(a1)+,d1
	add.l	d1,d0
	bsr	pas_rnd10
	tst.l	d0
	bpl.s	.p
	moveq	#0,d0
.p:	cmp.w	#99,d0
	ble.s	.x
	moveq	#99,d0
.x:	rts

; MedTick: sanity, performance and skill drift towards their computed values
ct_medtick:
	movem.l	d3-d5,-(sp)
	moveq	#1,d3
.l:	moveq	#0,d5			; the three fields
.f:	move.w	d3,d0
	lea	ct_meds,a0
	move.w	d5,d1
	lsl.w	#2,d1
	move.l	0(a0,d1.w),a0
	jsr	(a0)			; computed value
	move.w	d0,d4
	move.w	d3,d0
	bsr	ct_crew
	lea	ct_medoff,a1
	move.b	0(a1,d5.w),d1
	ext.w	d1
	moveq	#0,d2
	move.b	0(a0,d1.w),d2
	sub.w	d2,d4			; d := computed - current
	beq.s	.n
	moveq	#2,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.n
	moveq	#6,d0			; SkillTest(6, 99-abs(d), 10)
	move.w	d4,d1
	bpl.s	.ab
	neg.w	d1
.ab:	neg.w	d1
	add.w	#99,d1
	moveq	#10,d2
	bsr	ct_skilltest
	tst.w	d0
	beq.s	.n
	move.w	d3,d0
	bsr	ct_crew
	lea	ct_medoff,a1
	move.b	0(a1,d5.w),d1
	ext.w	d1
	tst.w	d4
	bmi.s	.dec
	addq.b	#1,0(a0,d1.w)
	bra.s	.n
.dec:	subq.b	#1,0(a0,d1.w)
.n:	addq.w	#1,d5
	cmp.w	#3,d5
	bne.s	.f
	addq.w	#1,d3
	cmp.w	#6,d3
	ble	.l
	movem.l	(sp)+,d3-d5
	rts

; ResearchTick: researchers learn; the others rest
ct_researchtick:
	movem.l	d3-d5,-(sp)
	moveq	#1,d3
.l:	btst	d3,GS_SHIP+SHIP_RESEARCH(a6)
	beq.s	.rest
	move.w	d3,d0			; addxp(i, 5 + PerformanceRange(i, 5), not bg)
	bsr	ct_crew
	moveq	#0,d4
	move.b	CREW_PERF(a0),d4	; random(per) - random(dif): per >= 5, dif 5
	cmp.w	#5,d4
	bgt.s	.p
	moveq	#5,d4
.p:	move.w	d4,d0
	bsr	mt_random
	move.w	d0,d4
	moveq	#5,d0
	bsr	mt_random
	sub.w	d0,d4
	addq.w	#5,d4
	move.w	d3,d0
	move.w	d4,d1
	ext.l	d1
	moveq	#1,d2
	tst.b	ct_bg
	beq.s	.ad
	moveq	#0,d2
.ad:	bsr	addxp
	bra.s	.n
.rest:	moveq	#5-1,d5			; 5 x: if status > 0 and PerformanceTest(i, 99-status): dec
.s:	move.w	d3,d0
	bsr	ct_crew
	moveq	#0,d1
	move.b	CREW_STATUS(a0),d1
	beq.s	.sn
	neg.w	d1
	add.w	#99,d1
	move.w	d3,d0
	bsr	ct_perftest
	tst.w	d0
	beq.s	.sn
	move.w	d3,d0
	bsr	ct_crew
	subq.b	#1,CREW_STATUS(a0)
.sn:	dbf	d5,.s
	move.w	d3,d0			; if san < ComputeSanity(i) and PerformanceTest(i, 99-status)
	bsr	ct_computesanity
	move.w	d0,d4
	move.w	d3,d0
	bsr	ct_crew
	moveq	#0,d0
	move.b	CREW_SAN(a0),d0
	cmp.w	d4,d0
	bge.s	.n
	moveq	#0,d1
	move.b	CREW_STATUS(a0),d1
	neg.w	d1
	add.w	#99,d1
	move.w	d3,d0
	bsr	ct_perftest
	tst.w	d0
	beq.s	.n
	move.w	d3,d0
	bsr	ct_crew
	addq.b	#1,CREW_SAN(a0)
.n:	addq.w	#1,d3
	cmp.w	#6,d3
	ble	.l
	movem.l	(sp)+,d3-d5
	rts

; SanityTick: stress wears sanity down
ct_sanitytick:
	move.l	d3,-(sp)
	moveq	#1,d3
.l:	move.w	d3,d0
	bsr	ct_crew
	moveq	#0,d1
	move.b	CREW_STATUS(a0),d1
	move.w	d3,d0
	bsr	ct_sanitytest
	tst.w	d0
	bne.s	.n
	move.w	d3,d0
	bsr	ct_crew
	tst.b	CREW_SAN(a0)
	beq.s	.z
	subq.b	#1,CREW_SAN(a0)
	bra.s	.n
.z:	tst.b	CREW_PERF(a0)
	beq.s	.z2
	subq.b	#1,CREW_PERF(a0)
.z2:	tst.b	CREW_SKILL(a0)
	beq.s	.z3
	subq.b	#1,CREW_SKILL(a0)
.z3:	tst.b	CREW_PERF(a0)
	beq	notported		; SanityFailure
	tst.b	CREW_SKILL(a0)
	beq	notported
.n:	addq.w	#1,d3
	cmp.w	#6,d3
	ble.s	.l
	move.l	(sp)+,d3
	rts

; DayTick: the bots on the planets of this system (not ported: stops if there are any)
ct_daytick:
	move.w	GS_CURPLAN(a6),d0
	subq.w	#1,d0
	mulu	#PLANET_SIZEOF,d0
	move.l	GS_TEMPPLAN(a6),a0
	move.b	PLANET_SYSTEM(a0,d0.l),d1
	move.w	#1000-1,d0
.l:	cmp.b	PLANET_SYSTEM(a0),d1
	bne.s	.n
	tst.b	PLANET_BOTS(a0)
	bne	notported
.n:	lea	PLANET_SIZEOF(a0),a0
	dbf	d0,.l
	rts

; ---------------------------------------------------------------
; utils.pas addxp(crewnum d0, amount d1.l, drawmode d2)
addxp:
	movem.l	d3-d5/a3,-(sp)
	move.w	d0,d3
	move.w	d2,d5
	bsr	ct_crew
	move.l	a0,a3
	cmp.l	#25000000,CREW_XP(a3)
	bgt	.x
	add.l	d1,CREW_XP(a3)
	moveq	#0,d4
	move.b	CREW_LEVEL(a3),d4	; oldlvl
	move.w	d4,d0			; i
	cmp.w	#20,d4
	beq.s	.c
	move.l	CREW_XP(a3),d1
	lea	ct_levels,a0
	moveq	#0,d0
.lv:	move.l	(a0)+,d2
	beq.s	.c			; (end: level 20)
	cmp.l	d2,d1
	blt.s	.c
	addq.w	#1,d0
	bra.s	.lv
.c:	cmp.w	d4,d0
	beq.s	.x
	move.b	d0,CREW_LEVEL(a3)
	move.w	GS_TCOLOR(a6),-(sp)
	move.w	#31,GS_TCOLOR(a6)
	cmp.w	#1,d5
	bne	notported		; showchar
	bsr	println
	lea	ct_s,a0
	move.w	d3,d0
	mulu	#12,d0
	lea	us_crewtitles,a1
	add.w	d0,a1
	bsr	pstr_cpy
	lea	ct_s,a0
	lea	ct_s_kb,a1
	bsr	pstr_cat
	lea	ct_s,a0
	bsr	print
	cmp.b	#99,CREW_MEN(a3)
	bhs.s	.m
	addq.b	#1,CREW_MEN(a3)
.m:	cmp.b	#99,CREW_EMO(a3)
	bhs.s	.e
	addq.b	#1,CREW_EMO(a3)
.e:	cmp.b	#99,CREW_PHY(a3)
	bhs.s	.p
	addq.b	#1,CREW_PHY(a3)
.p:	move.w	(sp)+,GS_TCOLOR(a6)
.x:	movem.l	(sp)+,d3-d5/a3
	rts

; weird.pas tickpending(ticks d0, background d1.b): pending logs whose time has come
tickpending:
	movem.l	d3-d5,-(sp)
	move.w	d0,d4
	move.b	d1,d5
	moveq	#0,d3			; i
.l:	cmp.w	#128,d3
	bge.s	.x
	lea	GS_LOGPENDING(a6),a0
	move.w	d3,d0
	lsl.w	#2,d0
	add.w	d0,a0
	tst.w	LOGPENDING_LOG(a0)
	bmi.s	.x
	sub.w	d4,LOGPENDING_TIME(a0)
	bgt.s	.n
	tst.b	d5
	beq.s	.run
	clr.w	LOGPENDING_TIME(a0)
	bra.s	.n
.run:	move.w	LOGPENDING_LOG(a0),d0
	bsr	event
	lea	GS_LOGPENDING(a6),a0	; remove entry i: the rest moves up
	move.w	d3,d0
	addq.w	#1,d0
.mv:	cmp.w	#128,d0
	bge.s	.end
	move.w	d0,d1
	lsl.w	#2,d1
	move.l	0(a0,d1.w),-4(a0,d1.w)
	tst.w	LOGPENDING_LOG(a0,d1.w)
	bmi.s	.end
	addq.w	#1,d0
	bra.s	.mv
.end:	move.w	#-1,127*4+LOGPENDING_LOG(a0)
	subq.w	#1,d3
.n:	addq.w	#1,d3
	bra.s	.l
.x:	movem.l	(sp)+,d3-d5
	rts

	section	data
ct_wskill:	dc.w	4,-2,6
ct_wperf:	dc.w	6,4,-2
ct_wsan:	dc.w	-2,6,4
ct_meds:	dc.l	ct_computesanity,ct_computeperf,ct_computeskill
ct_medoff:	dc.b	CREW_SAN,CREW_PERF,CREW_SKILL,0
ct_levels:	dc.l	1000,3000,4000,7000,11000,18000,29000,47000,76000,123000,200000
		dc.l	350000,500000,650000,800000,950000,1100000,1250000,1400000,1550000,0
ct_colon:	dc.b	2,": "
ct_s_kb:	dc.b	27,": Increased knowledge base."
ct_s_power:	dc.b	50,"Secondary power failure...Shields powering down..."
ct_s_alien:	dc.b	33,"Alien vessel sighted on scanners!"
ct_s_hull:	dc.b	26,"Hull damage repaired, sir!"
ct_s_repaired:	dc.b	15," repaired, sir!"
	even
ct_repairname:	dc.b	12,"Power Supply",0,0,0
		dc.b	14,"Shield Control",0
		dc.b	15,"Weapons Control"
		dc.b	6,"Engine",0,0,0,0,0,0,0,0,0
		dc.b	13,"Life Support ",0,0
		dc.b	14,"Communications",0
		dc.b	11,"Computer AI",0,0,0,0
		dc.b	11,"Hull Damage",0,0,0,0
ct_lastalienid:	dc.w	-1

	section	bss
ct_bg:		ds.b	1
	even
ct_s:		ds.b	100
ct_s2:		ds.b	40
