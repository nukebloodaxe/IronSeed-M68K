; main.s - MAIN.PRG: port of main.pas + starter.pas (the main game). Started by IS.PRG with
; "/playseed" (continue: the load dialog) or "/playseed n" (load slot n, e.g. after crewgen).
; Exit codes as the original: 4 quit to DOS, others back to IS.PRG.
;
; Screen model (game/mscr.s): the original's screen[] is a chunky shadow drawn by the ported code
; line by line and flushed to the planar screen through the band LUTs of the current screen
; design ("mode": DATA\<NAME>.ISP + .CHK, tools/mkmain.py).
; Random numbers: FPC's generator (mt.s) in the original's call order; scripted test runs seed
; 1994 like the oracle build (whose randomize always reseeds 1994).
	include	"hw.i"
	include	"kmac.i"
	include	"layout.i"
	include	"ids.i"			; build/: data.pas's constants (tools/mkids.py)
	include	"pmac.i"		; the ported Pascal's drawing/string macros

OPT_FONT_	equ	7		; (ids.i has OPT_FONT; kept for the older code)
SL_LOAD		equ	1		; saveload.s: with sl_loadgame

	section	text
start:	move.l	4(sp),a0
	bsr	sys_init
	lea	fn_script,a0
	bsr	scr_open
	moveq	#0,d0
	bsr	vid_set_fade
	bsr	ms_init
	bsr	init_everything
	bsr	checkparams
	bsr	readydata
	bra	journeyon

; ---------------------------------------------------------------
; data.pas init_everything + the units' initialisation parts
init_everything:
	move.w	#22,GS_TCOLOR(a6)
	clr.w	GS_BKCOLOR(a6)
	lea	fn_mainpal,a0		; readygraph: colors := main.pal
	lea	GS_COLORS(a6),a1
	move.l	#768,d0
	bsr	load_exact
	move.b	#64,GS_SHIP+SHIP_OPTIONS+OPT_VOLUME-1(a6)
	move.b	#1,GS_SHIP+SHIP_OPTIONS+OPT_SOUND-1(a6)
	clr.w	GS_FADELEVEL(a6)
	lea	files,a3		; memory for the pointer variables (and their files)
.f:	move.l	(a3)+,d0		; size, 0 ends
	beq.s	.x
	move.l	d0,d3
	bsr	mem_alloc
	bcs	fatal
	move.l	(a3)+,d1		; GS offset of the pointer (or 0: a module's own long)
	move.l	(a3)+,a1
	tst.l	d1
	beq.s	.own
	move.l	a0,0(a6,d1.l)
	bra.s	.f
.own:	move.l	a0,(a1)
	bra.s	.f
.x:	add.l	#128,GS_LANDFORM(a6)	; landform's margin
	move.l	GS_SCREEN2(a6),a0	; fillchar(screen2^, 64000, 3)
	move.w	#64000/4-1,d0
.s2:	move.l	#$03030303,(a0)+
	dbf	d0,.s2
	lea	fn_sphere,a0
	move.l	u2_sphere,a1
	move.l	#22000,d0
	bsr	fil_load
	bcs	fatal
	lea	fn_cube,a0		; the cube's rotations
	lea	jy_cubecols,a1
	move.l	#21*77*2+20*67*2,d0
	bsr	load_exact
	bsr	resetcrew
	moveq	#0,d0			; mouse.setmousecursor(0)
	bsr	setmousecursor
	moveq	#0,d0			; FPC's randseed starts at 0 (main never calls randomize first)
	bra	mt_seed

fatal:	pea	msg_fatal
	GEMDOS	GD_CCONWS,6
	moveq	#4,d0
	bra	sys_exit

; the command tail (basepage+$80: length, text), or the script's "args" in test runs
cmdtail:
	move.l	sys_basepage,a0
	lea	$80(a0),a0
	tst.b	(a0)
	bne.s	.x
	tst.b	scr_args
	beq.s	.x
	lea	scr_args,a0
.x:	rts

; starter.pas checkparams: "/playseed" (or "/killseed": the ending, not ported yet)
checkparams:
	bsr	cmdtail
	addq.l	#1,a0
	lea	arg_seed,a1
	bsr	has_arg
	tst.w	d0
	bne.s	.ok
	tst.w	scr_test		; (test runs may start it directly)
	bne.s	.ok
	moveq	#4,d0
	bra	sys_exit
.ok:	move.w	#10,GS_TSLICE(a6)
	rts

; starter.pas readydata: icons, weapons, cargo, artifacts, planet icons; readybuildtimes
readydata:
	lea	fn_icons,a0
	move.l	GS_ICONS(a6),a1
	move.l	#ICONARRAY_SIZEOF,d0
	bsr	load_exact
	lea	fn_weapon,a0
	lea	GS_WEAPONS(a6),a1
	move.l	#WEAPONARRAY_SIZEOF,d0
	bsr	load_exact
	lea	fn_cargo,a0
	lea	GS_CARGO(a6),a1
	move.l	#CARGOARRAY_SIZEOF,d0
	bsr	load_exact
	lea	fn_artifact,a0
	move.l	GS_ARTIFACTS(a6),a1
	move.l	#ARTIFACT_SIZEOF,d0
	bsr	load_exact
	lea	fn_planicon,a0
	move.l	GS_PLANICONS(a6),a1
	move.l	#PLANICON_SIZEOF,d0
	bsr	fil_load		; (the file is longer: read the first record)
	bcs	fatal
	; fall through
; readybuildtimes: build time, parts and levels of every cargo item from creation.dta
readybuildtimes:
	movem.l	d3-d7/a3-a5,-(sp)
	lea	GS_BLDCARGO(a6),a0
	lea	GS_PRTCARGO(a6),a1
	lea	GS_LVLCARGO(a6),a2
	move.w	#MAXCARGO-1,d0
.i:	move.w	#30000,(a0)+
	clr.w	(a1)+
	clr.l	(a1)+
	moveq	#6-1,d1
.l:	move.w	#1,(a2)+
	dbf	d1,.l
	dbf	d0,.i
	bsr	mem_mark
	move.l	d0,-(sp)
	move.l	#CREATEARRAY_SIZEOF,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,a3
	move.l	a0,a1
	lea	fn_creation,a0
	move.l	#CREATEARRAY_SIZEOF,d0
	bsr	load_exact
	move.w	#TOTALCREATION-1,d7
.j:	lea	GS_CARGO+CARGO_INDEX(a6),a4
	moveq	#0,d6			; i-1
.c:	move.w	CREATION_INDEX(a3),d0
	cmp.w	(a4),d0
	beq.s	.hit
	lea	CARGO_SIZEOF(a4),a4
	addq.w	#1,d6
	cmp.w	#MAXCARGO,d6
	bne.s	.c
	bra.s	.nj
.hit:	moveq	#0,d0			; bldcargo[i] := sum of levels
	lea	CREATION_LEVELS(a3),a0
	moveq	#6-1,d1
.s:	add.w	(a0)+,d0
	dbf	d1,.s
	move.w	d6,d1
	add.w	d1,d1
	lea	GS_BLDCARGO(a6),a0
	move.w	d0,0(a0,d1.w)
	move.w	d6,d1
	mulu	#6,d1
	lea	GS_PRTCARGO(a6),a0
	add.w	d1,a0
	lea	CREATION_PARTS(a3),a1
	move.w	(a1)+,(a0)+
	move.l	(a1)+,(a0)+
	move.w	d6,d1
	mulu	#12,d1
	lea	GS_LVLCARGO(a6),a0
	add.w	d1,a0
	lea	CREATION_LEVELS(a3),a1
	move.l	(a1)+,(a0)+
	move.l	(a1)+,(a0)+
	move.l	(a1)+,(a0)+
.nj:	lea	CREATION_SIZEOF(a3),a3
	dbf	d7,.j
	move.l	(sp)+,d0
	bsr	mem_release
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; a0 = name, a1 = buffer, d0.l = exact size; fatal if the file is missing or short
load_exact:
	move.l	d0,-(sp)
	bsr	fil_load
	bcs	fatal
	cmp.l	(sp)+,d0
	bne	fatal
	rts

; ---------------------------------------------------------------
; gmouse.pas setmousecursor(n): cursor n+87 of weapicon.dta (20x20, top-left 16x16)
setmousecursor:
	movem.l	d3/a3,-(sp)
	add.w	#87,d0
	mulu	#WEAPONICON_SIZEOF,d0
	move.l	d0,d3
	lea	fn_weapicon,a0		; read the file once, keep it
	tst.l	weapicons
	bne.s	.have
	move.l	#36000,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,weapicons
	move.l	a0,a1
	lea	fn_weapicon,a0
	move.l	#36000,d0
	bsr	load_exact
.have:	move.l	weapicons,a0
	add.l	d3,a0
	lea	mdefault,a1
	moveq	#16-1,d0
.r:	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	addq.l	#4,a0
	dbf	d0,.r
	lea	mdefault,a0
	bsr	kbd_cursor_set
	movem.l	(sp)+,d3/a3
	rts

; ---------------------------------------------------------------
; starter.pas journeyon
journeyon:
	moveq	#-8,d0			; fadestopmod(-FADEFULL_STEP, FADEFULL_DELAY)
	moveq	#20,d1
	bsr	fadestopmod
	st	GS_PALETTEDIRTY(a6)
	moveq	#-64,d0
	bsr	fadestep
	bsr	mouseshow
	bsr	loadspecial
	tst.w	GS_CURFILENUM(a6)
	bne.s	.loaded
	; loadgamedata(true): the load dialog - not ported yet
	moveq	#3,d0
	bra	sys_exit
.loaded:
	bra	bridge

; loadspecial: load the slot given on the command line ("/playseed n")
loadspecial:
	bsr	cmdtail
	moveq	#0,d1
	move.b	(a0)+,d1		; tail length
	subq.w	#1,d1
	bmi.s	.x
	moveq	#0,d2			; last word's first character
	move.b	#' ',d0
.w:	move.b	(a0)+,d2		; find the second word
	cmp.b	#' ',d2
	beq.s	.sp
	cmp.b	#' ',d0
	bne.s	.nx
	cmp.b	#'/',d2
	beq.s	.nx
	sub.b	#'0',d2			; a word that does not start with '/': j := ord(t[1])-48
	cmp.b	#1,d2
	blt.s	.x
	cmp.b	#8,d2
	bgt.s	.x
	clr.w	GS_CURFILENUM(a6)
	ext.w	d2
	move.w	d2,d0
	bsr	sl_loadgame
	tst.w	GS_CURFILENUM(a6)
	beq.s	.x
	moveq	#10,d0			; event(10); if chevent(12) then event(1001)
	bsr	event
	move.w	#12,d0
	bsr	chevent
	tst.w	d0
	beq.s	.x
	move.w	#1001,d0
	bra	event
.nx:
.sp:	move.b	d2,d0
	dbf	d1,.w
.x:	rts

; ---------------------------------------------------------------
; not ported yet
screensaver:				; weird.pas screensaver (after 750 idle frames)
	clr.w	GS_IDLETIME(a6)
	rts

; ---------------------------------------------------------------
	include	"kernel.s"
	include	"gutil.s"
	include	"mscr.s"
	include	"mdata.s"
	include	"mutils.s"
	include	"saveload.s"
	include	"weird.s"
	include	"comm2.s"
	include	"comm.s"
	include	"utils2.s"
	include	"journey.s"
	include	"usecode.s"
	include	"crewtick.s"
	include	"usecode2.s"
	include	"display.s"
	include	"fp.s"

	section	data
fn_script:	dc.b	"INPUT.MN",0
arg_seed:	dc.b	"/PLAYSEED",0
fn_icons:	dc.b	"DATA",92,"ICONS.VGA",0
fn_mainpal:	dc.b	"DATA",92,"MAIN.PAL",0
fn_weapon:	dc.b	"DATA",92,"WEAPON.DTA",0
fn_cargo:	dc.b	"DATA",92,"CARGO.DTA",0
fn_artifact:	dc.b	"DATA",92,"ARTIFACT.DTA",0
fn_planicon:	dc.b	"DATA",92,"PLANICON.DTA",0
fn_creation:	dc.b	"DATA",92,"CREATION.DTA",0
fn_weapicon:	dc.b	"DATA",92,"WEAPICON.DTA",0
fn_sphere:	dc.b	"DATA",92,"SPHERE.DAT",0
fn_cube:	dc.b	"DATA",92,"CUBE.DAT",0
msg_fatal:	dc.b	"MAIN: a data file is missing or damaged.",13,10,0
	even
; memory for pointer variables: size, GS offset (or 0), own long (when the offset is 0)
files:	dc.l	ICONARRAY_SIZEOF,GS_ICONS,0
	dc.l	ARTIFACT_SIZEOF,GS_ARTIFACTS,0
	dc.l	PLANICON_SIZEOF,GS_PLANICONS,0
	dc.l	PLANARRAY_SIZEOF,GS_TEMPPLAN,0
	dc.l	64000,GS_BACKGR,0
	dc.l	PLAN_SIZEOF,GS_PLANET,0
	dc.l	CUBE_SIZEOF+1,GS_CUBESRC,0
	dc.l	CUBE_SIZEOF+1,GS_CUBETAR,0
	dc.l	64000,GS_SCREEN2,0
	dc.l	TEXTDISPLAY_SIZEOF+1,GS_TEXTDISPLAY,0
	dc.l	COLORDISPLAY_SIZEOF,GS_COLORDISPLAY,0
	dc.l	128+LAND_SIZEOF,GS_LANDFORM,0	; (+128 before: the original writes landform^[0,y])
	dc.l	22000,0,u2_sphere		; DATA\SPHERE.DAT
	dc.l	12402,GS_STARMAPSCREEN,0
	dc.l	400,GS_TEMPICON,0
	dc.l	0

	section	bss
weapicons:	ds.l	1
mdefault:	ds.b	256
