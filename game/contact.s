; contact.s - comm.pas for MAIN.PRG: the conversation screens.
;   conversewithcrew   the cube's Crew Comm: pick a crew member (mouse / F1-F6), type a subject,
;                      read the answer (charcom.cpr; mode CCOM)
;   continuecontact    the cube's Planet Comm (d0.b = 0) and Ship Hail (d0.b <> 0): the contact
;                      sequence, the alien race's own background, picture, animation, music and
;                      conversation, the info panel, events and gifts (event.dta), trading
;                      (trade.s); "No response..." with the static when nobody answers
; Modes (tools/mkcomm.py): CCOM; COMAn (race n = alien.conindex 1-11), COMGn (n = 30-33: the races
; without a picture), COMNR (no response). The alien screen is composed at run time as the
; original does (COM.CHK + BACKn.CHK + ALIENn.CHK); its bands are set once the race is known.
;
; conversewithcrew                                      trashes: d0-d2/a0-a2
; continuecontact   in: d0.b hail                       trashes: d0-d2/a0-a2
; cm_printxy2       in: d0.w x1, d1.w y1, a0 = glyph-code string; cm_pm/pn/po = m, n, o
;                   (comm.pas printxy2: drawn with bkcolor m, delay(tslice div 3), again on 0)
; addpending        in: d0.w n, d1.w t (weird.pas addpending)

; (MAXCONVERSE: ids.i)

	section	text
; ---------------------------------------------------------------- shared
; delay_blink: up to 8 x delay(tslice), stopping at a key
cm_delay_blink:
	move.l	d3,-(sp)
	moveq	#8-1,d3
.l:	bsr	kbd_keypressed
	bne.s	.x
	move.w	GS_TSLICE(a6),d0
	bsr	delay
	dbf	d3,.l
.x:	move.l	(sp)+,d3
	rts

; clearconvflags: events 500-599 cleared
cm_clearconvflags:
	move.l	d3,-(sp)
	move.w	#500,d3
.l:	move.w	d3,d0
	bsr	clearevent
	addq.w	#1,d3
	cmp.w	#599,d3
	ble.s	.l
	move.l	(sp)+,d3
	rts

; question := 20 spaces (fillchar(question, 21, ' '); question[0] := #20)
cm_clrquestion:
	lea	cm_question,a0
	move.b	#20,(a0)+
	moveq	#20-1,d0
.c:	move.b	#' ',(a0)+
	dbf	d0,.c
	rts

; weird.pas addpending(n d0, t d1)
addpending:
	lea	GS_LOGPENDING(a6),a0
	moveq	#128-1,d2
.l:	cmp.w	LOGPENDING_LOG(a0),d0
	bne.s	.n
	cmp.w	LOGPENDING_TIME(a0),d1
	bge.s	.x
	move.w	d1,LOGPENDING_TIME(a0)
	rts
.n:	tst.w	LOGPENDING_LOG(a0)
	bpl.s	.nx
	move.w	d0,LOGPENDING_LOG(a0)
	move.w	d1,LOGPENDING_TIME(a0)
	rts
.nx:	addq.l	#LOGPENDING_SIZEOF,a0
	dbf	d2,.l
.x:	rts

; ascii -> glyph code (the original's case: ' '..'"' -31, ''''..'?' -35, 'A'..'Z' -36,
; 'a'..'z' -40, else 1); d0.b in/out
cm_glyph:
	cmp.b	#' ',d0
	blo.s	.one
	cmp.b	#'"',d0
	bhi.s	.a
	sub.b	#31,d0
	rts
.a:	cmp.b	#39,d0
	blo.s	.one
	cmp.b	#'?',d0
	bhi.s	.b
	sub.b	#35,d0
	rts
.b:	cmp.b	#'A',d0
	blo.s	.one
	cmp.b	#'Z',d0
	bhi.s	.c
	sub.b	#36,d0
	rts
.c:	cmp.b	#'a',d0
	blo.s	.one
	cmp.b	#'z',d0
	bhi.s	.one
	sub.b	#40,d0
	rts
.one:	moveq	#1,d0
	rts

; comm.pas printxy2(x1, y1, m, n, o, s)
cm_printxy2:
	movem.l	d3-d7/a3-a5,-(sp)
	move.l	a0,a5
	move.w	GS_TCOLOR(a6),-(sp)	; t
	sf	cm_brighter
	addq.w	#4,d0
	move.w	d0,d5			; x1
	move.w	d1,d6			; y1
	moveq	#0,d0			; the game font
	move.b	GS_SHIP+SHIP_OPTIONS+OPT_FONT-1(a6),d0
	mulu	#82*3,d0
	lea	txt_font-3,a4
	add.w	d0,a4
	moveq	#0,d4
	move.b	(a5)+,d4
	bra	.next
.char:	moveq	#0,d7
	move.b	(a5)+,d7		; letter
	cmp.b	#200,d7
	bne.s	.g
	not.b	cm_brighter
	bra	.next
.g:	move.w	cm_pm,GS_BKCOLOR(a6)	; bkcolor := m
	bsr	.tcol
	bsr	.pass
	move.w	d5,d0			; for i := 1 to 6: screen[y1+i, x1+5] := bkcolor
	addq.w	#5,d0
	move.w	d6,d1
	addq.w	#1,d1
	bsr	ms_addr
	move.w	GS_BKCOLOR(a6),d0
	moveq	#6-1,d1
.gp:	move.b	d0,(a0)
	lea	MS_W(a0),a0
	dbf	d1,.gp
	bsr	.mark
	move.w	GS_TSLICE(a6),d0	; delay(tslice div 3)
	ext.l	d0
	divs	#3,d0
	bsr	delay
	clr.w	GS_BKCOLOR(a6)		; bkcolor := 0
	bsr	.tcol
	bsr	.pass
	move.w	d5,d0
	addq.w	#5,d0
	move.w	d6,d1
	addq.w	#1,d1
	bsr	ms_addr
	moveq	#6-1,d1
.gq:	clr.b	(a0)
	lea	MS_W(a0),a0
	dbf	d1,.gq
	bsr	.mark
	addq.w	#5,d5			; x1 := x1 + 5
.next:	dbf	d4,.char
	move.w	(sp)+,GS_TCOLOR(a6)
	movem.l	(sp)+,d3-d7/a3-a5
	rts
.mark:	move.w	d5,d0			; the glyph's cell and gap column marked
	addq.w	#1,d0
	move.w	d6,d1
	addq.w	#1,d1
	move.w	d0,d2
	addq.w	#4,d2
	move.w	d3,-(sp)
	move.w	d1,d3
	addq.w	#5,d3
	bsr	ms_dirty
	move.w	(sp)+,d3
	rts
.tcol:	move.w	cm_po,d0		; tcolor := n if brighter, else o
	tst.b	cm_brighter
	beq.s	.t
	move.w	cm_pn,d0
.t:	move.w	d0,GS_TCOLOR(a6)
	rts
; the glyph d7 at (x1+1.., y1+1..): rows t, t-1, t-3, t-4, t-6, t-7; empty pixels bkcolor
; (< 255); tcolor ends at t-9
.pass:	move.w	d7,d0
	mulu	#3,d0
	lea	0(a4,d0.w),a3
	move.w	d5,d0
	addq.w	#1,d0
	move.w	d6,d1
	addq.w	#1,d1
	bsr	ms_addr
	move.w	GS_TCOLOR(a6),d2
	move.w	GS_BKCOLOR(a6),d3
	moveq	#0,d1			; row
.row:	move.w	d1,-(sp)
	lsr.w	#1,d1
	move.b	0(a3,d1.w),d0
	move.w	(sp),d1
	btst	#0,d1
	bne.s	.lo
	lsr.b	#4,d0
.lo:	moveq	#4-1,d1
.px:	btst	#3,d0
	beq.s	.bg
	move.b	d2,(a0)+
	bra.s	.nx
.bg:	cmp.w	#255,d3
	bhs.s	.tr
	move.b	d3,(a0)+
	bra.s	.nx
.tr:	addq.l	#1,a0
.nx:	add.b	d0,d0
	dbf	d1,.px
	lea	MS_W-4(a0),a0
	move.w	(sp)+,d1
	subq.w	#1,d2			; dec(tcolor, 1) after the even row, 2 after the odd one
	btst	#0,d1
	beq.s	.r1
	subq.w	#1,d2
.r1:	addq.w	#1,d1
	cmp.w	#6,d1
	bne.s	.row
	move.w	d2,GS_TCOLOR(a6)
	rts

; the conversation files of contactindex: CONVnnnn.IND/.DTA (nnnn = contactindex+1) into c, r
cm_loadconversation:
	movem.l	d3,-(sp)
	move.l	cm_c,a0			; fillchar(r^, 0); fillchar(c^, 0)
	move.w	#CONVERSEARRAY_SIZEOF/2-1,d0
.z1:	clr.w	(a0)+
	dbf	d0,.z1
	move.l	cm_rr,a0
	move.w	#RESPONSEARRAY_SIZEOF/2-1,d0
.z2:	clr.w	(a0)+
	dbf	d0,.z2
	move.w	cm_contactindex,d0	; the number, 4 digits
	addq.w	#1,d0
	lea	cm_fn_conv+13,a0
	moveq	#4-1,d2
.dg:	ext.l	d0
	divu	#10,d0
	swap	d0
	add.b	#'0',d0
	move.b	d0,-(a0)
	clr.w	d0
	swap	d0
	dbf	d2,.dg
	lea	cm_fn_conv+14,a0
	move.b	#'I',(a0)+
	move.b	#'N',(a0)+
	move.b	#'D',(a0)+
	lea	cm_fn_conv,a0
	move.l	cm_c,a1
	move.l	#CONVERSEARRAY_SIZEOF,d0
	bsr	fil_load
	bcs	fatal
	lea	cm_fn_conv+14,a0
	move.b	#'D',(a0)+
	move.b	#'T',(a0)+
	move.b	#'A',(a0)+
	lea	cm_fn_conv,a0
	move.l	cm_rr,a1
	move.l	#RESPONSEARRAY_SIZEOF,d0
	bsr	fil_load
	bcs	fatal
	movem.l	(sp)+,d3
	rts

; a0 = c^[d0] / r^[d0] (1-based)
cm_crec:
	subq.w	#1,d0
	mulu	#CONVERSEINDEX_SIZEOF,d0
	move.l	cm_c,a0
	add.l	d0,a0
	rts
cm_rrec:
	subq.w	#1,d0
	mulu	#RESPONSE_SIZEOF,d0
	move.l	cm_rr,a0
	add.l	d0,a0
	rts

; MORE: wait for a key or a click with the word pulsing (parsestatement)
cm_more:
	movem.l	d3,-(sp)
	BAR	15,184,302,188,0
	TCOL	47
	PXY	146,191,"MORE"
	moveq	#47,d3			; i2
	bsr	mouseshow
.l:	moveq	#8,d0			; fadestep(FADESTEP_STEP)
	bsr	fadestep
	move.w	d3,GS_TCOLOR(a6)
	PXY	146,191,"MORE"
	subq.w	#1,d3
	cmp.w	#41,d3
	bne.s	.a
	moveq	#47,d3
.a:	bsr	animatealien
	move.w	GS_TSLICE(a6),d0	; delay(tslice*FADE_TSLICE_MUL_COMM)
	mulu	#5,d0
	bsr	delayp			; (paced: the frame's work counts)
	bsr	kbd_keypressed
	bne.s	.k
	bsr	kbd_mouse_status
	tst.b	d0
	beq.s	.l
.k:	bsr	kbd_keypressed		; while fastkeypressed do readkey
	beq.s	.k2
	bsr	kbd_readkey
	bra.s	.k
.k2:	bsr	mousehide
	BAR	15,141,302,188,0
	PXY	146,191,"    "
	move.w	cm_po,GS_TCOLOR(a6)	; tcolor := s
	movem.l	(sp)+,d3
	rts

; parsestatement(y d0, n d1): r^[n].response with the crew names put in, wrapped at 56 glyphs
; (at a space, glyph 1), printxy2 per line from row 135+y*6; MORE after 7 lines  out: d0.w y
cm_parsestatement:
	movem.l	d3-d7/a3-a5,-(sp)
	move.w	d0,d7			; y
	move.w	d1,d0
	bsr	cm_rrec
	lea	RESPONSE_RESPONSE(a0),a0 ; str1^ := r^[n].response (length+1 bytes)
	lea	cm_str1,a1
	moveq	#0,d0
	move.b	(a0),d0
.c1:	move.b	(a0)+,(a1)+
	dbf	d0,.c1
	lea	cm_str1,a3		; copy into str2, the crew names (#201 + digit) put in
	lea	cm_str2+1,a4
	moveq	#1,d3			; i
	moveq	#0,d5
	move.b	(a3),d5			; length
.cp:	move.b	0(a3,d3.w),d0
	cmp.b	#201,d0
	bne.s	.plain
	addq.w	#1,d3			; a := ord(str1^[i])+35-48
	moveq	#0,d0
	move.b	0(a3,d3.w),d0
	sub.w	#13,d0
	bsr	ct_crew
	moveq	#20,d1			; b := 20; while name[b] = ' ' do dec(b)
.nb:	cmp.b	#' ',CREW_NAME(a0,d1.w)
	bne.s	.nbe
	subq.w	#1,d1
	bne.s	.nb
.nbe:	lea	CREW_NAME+1(a0),a1
	bra.s	.ne
.nc:	move.b	(a1)+,d0
	bsr	cm_glyph
	move.b	d0,(a4)+
.ne:	dbf	d1,.nc
	bra.s	.nn
.plain:	move.b	d0,(a4)+
.nn:	addq.w	#1,d3
	cmp.w	d5,d3
	ble.s	.cp
	move.l	a4,d0
	lea	cm_str2+1,a0
	sub.l	a0,d0
	move.b	d0,cm_str2
.line:	lea	cm_str2,a0		; str1^ := str2^
	lea	cm_str1,a1
	moveq	#0,d0
	move.b	(a0),d0
.c2:	move.b	(a0)+,(a1)+
	dbf	d0,.c2
	sf	d6			; done
	lea	cm_str1,a3
	moveq	#0,d5
	move.b	(a3),d5
	cmp.w	#56,d5
	bls.s	.last
	moveq	#56,d3			; i := 56; while str1^[i] <> #1 do dec(i)
.sp:	cmp.b	#1,0(a3,d3.w)
	beq.s	.spf
	subq.w	#1,d3
	bra.s	.sp
.spf:	move.w	d5,d0			; str2^ := copy(str1^, i+1, length-i)
	sub.w	d3,d0
	lea	cm_str2,a1
	move.b	d0,(a1)+
	lea	1(a3,d3.w),a0
	bra.s	.ce
.cc:	move.b	(a0)+,(a1)+
.ce:	dbf	d0,.cc
	move.w	d3,d0			; str1^[0] := chr(i-1)
	subq.w	#1,d0
	move.b	d0,(a3)
	bra.s	.pr
.last:	st	d6
.pr:	move.w	d7,d0			; printxy2(12, 135+y*6, p, q, s, str1^)
	mulu	#6,d0
	add.w	#135,d0
	move.w	d0,d1
	moveq	#12,d0
	lea	cm_str1,a0
	bsr	cm_printxy2
	addq.w	#1,d7
	cmp.w	#8,d7
	bne.s	.nm
	bsr	cm_more
	moveq	#1,d7
.nm:	tst.b	d6
	beq	.line
	move.w	d7,d0
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; checkstring(p, q, s = cm_pm/pn/po): the subject in question looked up in c^, the answer printed
cm_checkstring:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	mousehide
	BAR	15,135,302,181,0
	BAR	61,182,160,187,0
	move.w	cm_po,GS_TCOLOR(a6)
	lea	cm_question,a0
	moveq	#12,d0
	move.w	#135,d1
	bsr	printxy
	lea	cm_question,a3		; i := 20; while question[i] = ' ' do dec(i)
	moveq	#20,d3
.tr:	cmp.b	#' ',0(a3,d3.w)
	bne.s	.tre
	subq.w	#1,d3
	bne.s	.tr
	bsr	mouseshow		; (nothing typed)
	bra	.x
.tre:	move.b	d3,(a3)			; question[0] := chr(i); to glyph codes ('%' = 55)
	moveq	#1,d4
.gl:	move.b	0(a3,d4.w),d0
	cmp.b	#'%',d0
	bne.s	.g2
	moveq	#55,d0
	bra.s	.g3
.g2:	bsr	cm_glyph
.g3:	move.b	d0,0(a3,d4.w)
	addq.w	#1,d4
	cmp.w	d3,d4
	ble.s	.gl
	lea	cm_key,a0		; #1 + question + #1
	move.b	d3,d0
	addq.b	#2,d0
	move.b	d0,(a0)+
	move.b	#1,(a0)+
	lea	1(a3),a1
	move.w	d3,d0
	subq.w	#1,d0
.kq:	move.b	(a1)+,(a0)+
	dbf	d0,.kq
	move.b	#1,(a0)
	moveq	#0,d7			; index
.find:	addq.w	#1,d7
	move.w	d7,d0
	bsr	cm_crec
	move.l	a0,a4
	lea	CONVERSEINDEX_KEYWORD(a4),a0
	lea	cm_key,a1
	bsr	cm_pos
	move.w	d0,d5			; j
	move.w	CONVERSEINDEX_EVENT(a4),d0
	cmp.w	#-1,d0
	beq.s	.ev
	bsr	chevent
	bne.s	.ev
	moveq	#0,d5
.ev:	tst.w	d5
	bne.s	.found
	tst.w	CONVERSEINDEX_RCODE(a4)
	bne.s	.find
.found:	move.w	d5,cm_j
	bsr	cm_clrquestion
	move.w	#1,cm_cursorx
	tst.w	d5
	bne.s	.yes
	bsr	mouseshow
	bra	.x
.yes:	moveq	#1,d6			; i: the first response with the index
.fr:	move.w	d6,d0
	bsr	cm_rrec
	move.w	RESPONSE_INDEX(a0),d0
	cmp.w	CONVERSEINDEX_INDEX(a4),d0
	beq.s	.frf
	addq.w	#1,d6
	cmp.w	#MAXCONVERSE,d6
	ble.s	.fr
	bra	fatal			; (errorhandler: index not found)
.frf:	move.w	CONVERSEINDEX_RUNEVENT(a4),d0
	cmp.w	#21000,d0
	blt.s	.run
	bsr	cm_run21000
	beq	.ev2
.run:	move.w	CONVERSEINDEX_RCODE(a4),d0
	cmp.w	#1,d0
	bne.s	.r2
	moveq	#1,d0
	move.w	d6,d1
	bsr	cm_parsestatement
	bra.s	.ev2
.r2:	cmp.w	#2,d0
	bne.s	.r3
	moveq	#1,d5			; j := 1; while r^[i+j].index = c^[index].index do inc(j)
.r2l:	move.w	d6,d0
	add.w	d5,d0
	bsr	cm_rrec
	move.w	RESPONSE_INDEX(a0),d0
	cmp.w	CONVERSEINDEX_INDEX(a4),d0
	bne.s	.r2e
	addq.w	#1,d5
	bra.s	.r2l
.r2e:	move.w	d5,d0			; parsestatement(1, i+random(j))
	bsr	mt_random
	add.w	d6,d0
	move.w	d0,d1
	moveq	#1,d0
	bsr	cm_parsestatement
	bra.s	.ev2
.r3:	cmp.w	#3,d0
	bne.s	.ev2
	move.w	d6,d5			; index2
	moveq	#1,d3			; i2
.r3l:	move.w	d3,d0
	move.w	d5,d1
	bsr	cm_parsestatement
	move.w	d0,d3
	addq.w	#1,d5
	move.w	d6,d0
	bsr	cm_rrec
	move.w	RESPONSE_INDEX(a0),d4
	move.w	d5,d0
	bsr	cm_rrec
	cmp.w	RESPONSE_INDEX(a0),d4
	beq.s	.r3l
	PXY	12,182,"Subject:"
.ev2:	move.w	CONVERSEINDEX_RUNEVENT(a4),d0
	cmp.w	#19999,d0
	ble.s	.ms
	cmp.w	#21000,d0
	bge.s	.ms
	bsr	cm_run20000
.ms:	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d7/a3-a5
	rts

; pos(a1 = needle, a0 = haystack) (Pascal strings)  out: d0.w = position or 0
cm_pos:
	movem.l	d3-d4,-(sp)
	moveq	#0,d1
	move.b	(a1)+,d1		; needle length
	moveq	#0,d2
	move.b	(a0)+,d2		; haystack length
	moveq	#1,d3			; start
	sub.w	d1,d2			; last start - 1
	bmi.s	.no
.s:	move.w	d1,d4
	subq.w	#1,d4
	lea	-1(a0,d3.w),a2
	move.l	a1,-(sp)
.c:	cmpm.b	(a1)+,(a2)+
	dbne	d4,.c
	move.l	(sp)+,a1
	beq.s	.yes
	addq.w	#1,d3
	dbf	d2,.s
.no:	moveq	#0,d0
	bra.s	.x
.yes:	move.w	d3,d0
.x:	movem.l	(sp)+,d3-d4
	rts

; run20000event(n d0)
cm_run20000:
	cmp.w	#20000,d0
	bne.s	.n1
	BAR	12,182,211,188,0	; good bye
	move.w	#-1,cm_contactindex
	rts
.n1:	cmp.w	#20001,d0
	bne.s	.n2
	tst.b	GS_ALIEN+ALIEN_WAR(a6)	; trade
	beq	trade
	BAR	12,141,299,181,0
	PXY	12,141,"WE ARE AT WAR!"
	rts
.n2:	cmp.w	#20002,d0
	bne.s	.n3
	BAR	12,182,211,188,0	; attack!
	move.w	#-1,cm_contactindex
	moveq	#WNDORDER_ATTACK,d0
	bsr	createwandering
	lea	GS_SHIP+SHIP_WANDERING(a6),a0
	moveq	#100,d0
	bsr	mt_random
	add.w	#500,d0
	move.w	d0,ONEALIEN_RELX+GS_SHIP+SHIP_WANDERING(a6)
	moveq	#100,d0
	bsr	mt_random
	add.w	#500,d0
	move.w	d0,ONEALIEN_RELY+GS_SHIP+SHIP_WANDERING(a6)
	moveq	#100,d0
	bsr	mt_random
	add.w	#500,d0
	move.w	d0,ONEALIEN_RELZ+GS_SHIP+SHIP_WANDERING(a6)
	rts
.n3:	cmp.w	#20003,d0
	bne.s	.n4
	cmp.w	#100,GS_ALIEN+ALIEN_ANGER(a6)
	bge.s	.if
	addq.w	#1,GS_ALIEN+ALIEN_ANGER(a6)
.if:	tst.b	cm_infomode
	beq.s	.x
.gi:	bsr	getinfo
	bra	getinfo
.n4:	cmp.w	#20004,d0
	bne.s	.n5
	addq.w	#5,GS_ALIEN+ALIEN_ANGER(a6)
	cmp.w	#100,GS_ALIEN+ALIEN_ANGER(a6)
	ble.s	.gi
	move.w	#100,GS_ALIEN+ALIEN_ANGER(a6)
	bra.s	.gi
.n5:	cmp.w	#20005,d0
	bne.s	.n6
	cmp.w	#100,GS_ALIEN+ALIEN_CONGENIALITY(a6)
	bge.s	.if
	addq.w	#1,GS_ALIEN+ALIEN_CONGENIALITY(a6)
	bra.s	.if
.n6:	cmp.w	#20006,d0
	bne.s	.x
	addq.w	#5,GS_ALIEN+ALIEN_CONGENIALITY(a6)
	cmp.w	#100,GS_ALIEN+ALIEN_CONGENIALITY(a6)
	ble.s	.gi
	move.w	#100,GS_ALIEN+ALIEN_CONGENIALITY(a6)
	bra.s	.gi
.x:	rts

; run21000event(n d0): the two gift events  out: Z clear (d0.w = 1) = true
cm_run21000:
	movem.l	d3,-(sp)
	cmp.w	#21001,d0
	bne	.n2
	move.w	#ID_COOLANTS,d0		; Phaedor Moch: a coolant and a radioactive
	bsr	incargo
	tst.w	d0
	ble	.no1
	move.w	#ID_RADIOACTIVES,d0
	bsr	incargo
	tst.w	d0
	ble	.no1
	clr.w	GS_BKCOLOR(a6)
	move.w	cm_po,GS_TCOLOR(a6)
	PXY	12,141,"Give the Phaedor Moch a radioactive and a coolant?"
	bsr	.ask
	beq	.nay
	move.w	#ID_COOLANTS,d0
	bsr	removecargo
	move.w	#ID_RADIOACTIVES,d0
	bsr	removecargo
	move.w	#ID_ART_GLYPTIC_SCYTHE,d0
	st	d1
	bsr	addcargo
	move.w	#1101,d0
	bra	.yes
.no1:	clr.w	GS_BKCOLOR(a6)
	move.w	cm_po,GS_TCOLOR(a6)
	PXY	12,141,"(Eng: We have no radioactives and coolants to spare.)"
	bra	.false
.n2:	cmp.w	#21002,d0
	bne	.false
	move.w	#ID_STRATAMOUNT,d0	; Aard: a stratamount
	bsr	incargo
	tst.w	d0
	ble.s	.no2
	PXY	12,141,"Give the Aard a stratamount?"
	bsr	.ask
	beq.s	.nay
	move.w	#ID_STRATAMOUNT,d0
	bsr	removecargo
	move.w	#ID_BALLISTA,d0
	st	d1
	bsr	addcargo
	move.w	#1102,d0
	bra.s	.yes
.no2:	clr.w	GS_BKCOLOR(a6)
	move.w	cm_po,GS_TCOLOR(a6)
	PXY	12,141,"(Eng: We have no stratamounts to spare.)"
	bra.s	.false
.nay:	PXY	12,147,"No."
.false:	moveq	#0,d0
	movem.l	(sp)+,d3
	rts
.yes:	moveq	#0,d1			; addpending(n, 0); event(500)
	bsr	addpending
	move.w	#500,d0
	bsr	event
	moveq	#1,d0
	movem.l	(sp)+,d3
	rts
.ask:	bsr	mouseshow		; yesnorequest('Give supplies?', 0, 31)
	lea	.q,a0
	moveq	#0,d0
	moveq	#31,d1
	bsr	yesnorequest
	move.w	d0,d3
	bsr	mousehide
	tst.w	d3
	rts
.q:	dc.b	14,"Give supplies?"
	even

; the subject line editing of processkey2/3: key d0.b (upcased)  out: Z set if not one of them
cm_editkey:
	movem.l	d3,-(sp)
	move.b	d0,d3
	cmp.b	#'A',d3
	blo.s	.o
	cmp.b	#'Z',d3
	bls.s	.ins
.o:	cmp.b	#' ',d3
	beq.s	.ins
	cmp.b	#'0',d3
	blo.s	.o2
	cmp.b	#'9',d3
	bls.s	.ins
.o2:	cmp.b	#39,d3
	beq.s	.ins
	cmp.b	#'-',d3
	beq.s	.ins
	cmp.b	#8,d3
	beq.s	.bs
	moveq	#0,d0
	bra.s	.x
.ins:	tst.w	cm_contactindex
	bmi.s	.done
	lea	cm_question,a0
	move.w	cm_cursorx,d1
	cmp.w	#20,d1
	bge.s	.ov
	moveq	#20,d2			; for j := 20 downto cursorx do question[j] := question[j-1]
.sh:	move.b	-1(a0,d2.w),0(a0,d2.w)
	subq.w	#1,d2
	cmp.w	d1,d2
	bge.s	.sh
	move.b	d3,0(a0,d1.w)
	addq.w	#1,cm_cursorx
	bra.s	.pr
.ov:	move.b	d3,0(a0,d1.w)
	bra.s	.pr
.bs:	tst.w	cm_contactindex
	bmi.s	.done
	cmp.w	#1,cm_cursorx
	ble.s	.b1
	subq.w	#1,cm_cursorx
.b1:	bsr	cm_delchar
	move.b	#' ',cm_question+20
.pr:	bsr	cm_showq
.done:	moveq	#1,d0
.x:	movem.l	(sp)+,d3
	tst.w	d0
	rts
; for j := cursorx to 19 do question[j] := question[j+1]
cm_delchar:
	lea	cm_question,a0
	move.w	cm_cursorx,d1
.d:	cmp.w	#19,d1
	bgt.s	.x
	move.b	1(a0,d1.w),0(a0,d1.w)
	addq.w	#1,d1
	bra.s	.d
.x:	rts
cm_showq:				; mousehide; printxy(57, 182, question); mouseshow
	bsr	mousehide
	lea	cm_question,a0
	moveq	#57,d0
	move.w	#182,d1
	bsr	printxy
	bra	mouseshow
; the extended keys of both: right, left, delete (d0.b = scan)  out: Z set if not one of them
cm_editscan:
	tst.w	cm_contactindex
	bmi.s	.no
	cmp.b	#77,d0
	bne.s	.l
	cmp.w	#20,cm_cursorx
	bge.s	.y
	addq.w	#1,cm_cursorx
	bra.s	.y
.l:	cmp.b	#75,d0
	bne.s	.d
	cmp.w	#1,cm_cursorx
	ble.s	.y
	subq.w	#1,cm_cursorx
	bra.s	.y
.d:	cmp.b	#83,d0
	bne.s	.no
	bsr	cm_delchar
	bsr	cm_showq
.y:	moveq	#1,d0
	rts
.no:	moveq	#0,d0
	rts

; the blinking cursor: printxy(cursorx*5+52, 182, question[cursorx]) on bkcolor d0, then 0
cm_blink:
	move.w	d0,GS_BKCOLOR(a6)
	bsr.s	.ch
	bsr	cm_delay_blink
	clr.w	GS_BKCOLOR(a6)
	bsr.s	.ch
	bra	cm_delay_blink
.ch:	lea	cm_ch,a0
	move.b	#1,(a0)
	move.w	cm_cursorx,d1
	lea	cm_question,a1
	move.b	0(a1,d1.w),1(a0)
	move.w	d1,d0
	mulu	#5,d0
	add.w	#52,d0
	move.w	#182,d1
	bra	printxy

; ---------------------------------------------------------------- crew comm
conversewithcrew:
	movem.l	d3-d7/a3-a5,-(sp)
	bsr	cm_clearconvflags
	bsr	cc_ready
	bsr	cc_mainloop
	move.l	cm_mark,d0		; dispose(str2, str1, c, r)
	bsr	mem_release
	bsr	removedata		; (utils2.pas removedata)
	movem.l	(sp)+,d3-d7/a3-a5
	rts

cc_ready:
	bsr	mousehide
	moveq	#0,d0			; compressfile(current)
	bsr	ms_snap
	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	lea	cc_fn_mod,a0
	bsr	playmod
	bsr	orc_dump		; loadscreen(charcom)
	lea	cc_mode,a0
	bsr	ms_load
	bcs	fatal
	move.l	GS_T1(a6),GS_OLDT1(a6)
	move.l	GS_T1+4(a6),GS_OLDT1+4(a6)
	clr.w	GS_BKCOLOR(a6)
	move.w	#170,GS_TCOLOR(a6)
	PXY	12,182,"Converse with crew member:"
	sf	GS_DONE(a6)
	move.w	#-1,cm_contactindex
	move.w	#-1,GS_ALIEN+ALIEN_CONINDEX(a6)
	bsr	cm_clrquestion
	bsr	cm_alloc
	move.w	#1,cm_cursorx
	bsr	cc_names
	bra	mouseshow

cm_alloc:				; new(str1, str2, c, r) (str1/2 are static here)
	bsr	mem_mark
	move.l	d0,cm_mark
	move.l	#CONVERSEARRAY_SIZEOF+CONVERSEINDEX_SIZEOF,d0	; (+1 record: the search may look one past)
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,cm_c
	move.l	#RESPONSEARRAY_SIZEOF+RESPONSE_SIZEOF,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,cm_rr
	rts

; displaycrewnames: the names and the stress bars (t1 := 22/36)
cc_names:
	movem.l	d3-d7/a3,-(sp)
	FSSE
	FLDI	22
	FLDI	36
	bsr	fp_div
	lea	GS_T1(a6),a0
	bsr	fp_std
	moveq	#0,d7			; a
.a:	move.w	d7,d0
	addq.w	#1,d0
	bsr	ct_crew
	move.l	a0,a3
	moveq	#1,d4			; i := 6 for crew 18, 25, 26, else 1
	move.b	CREW_INDEX(a3),d0
	cmp.b	#18,d0
	beq.s	.i6
	cmp.b	#25,d0
	beq.s	.i6
	cmp.b	#26,d0
	bne.s	.i1
.i6:	moveq	#6,d4
.i1:	moveq	#1,d5			; b
.nm:	lea	cm_ch,a0		; printxy((a div 3)*230+12+b*5, (a mod 3)*30+37, name[i])
	move.b	#1,(a0)
	move.b	CREW_NAME(a3,d4.w),1(a0)
	bsr	.xy
	move.w	d5,d2
	mulu	#5,d2
	add.w	d2,d0
	add.w	#12,d0
	bsr	printxy
	addq.w	#1,d4
	addq.w	#1,d5
	cmp.b	#' ',CREW_NAME(a3,d4.w)
	bne.s	.nm
	FX87				; j := round((0.40*men + 0.60*emo - 0.20*phy)*0.36)
	FLDX	gx_0_4
	moveq	#0,d0
	move.b	CREW_MEN(a3),d0
	bsr	fp_ldw
	bsr	fp_mul
	FLDX	gx_0_6
	moveq	#0,d0
	move.b	CREW_EMO(a3),d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_add
	FLDX	gx_0_2
	moveq	#0,d0
	move.b	CREW_PHY(a3),d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_sub
	FLDX	gx_0_36
	bsr	fp_mul
	bsr	fp_rnd
	FSSE
	move.w	d0,d6			; j
	cmp.w	#36,d6
	ble.s	.j1
	moveq	#36,d6
	bra.s	.j2
.j1:	cmp.w	#1,d6
	bge.s	.j2
	moveq	#0,d6
.j2:	moveq	#0,d5			; for b := 0 to j: rows 48/49 := round(t1*b)+73
.b:	cmp.w	d6,d5
	bgt.s	.be
	lea	GS_T1(a6),a0
	bsr	fp_ldd
	move.w	d5,d0
	bsr	fp_ldw
	bsr	fp_mul
	bsr	fp_rnd
	add.w	#73,d0
	move.w	d0,d2
	bsr	.bar
	addq.w	#1,d5
	bra.s	.b
.be:	cmp.w	#34,d6			; if j < 34: b := j+1 to 36 in 0
	bge.s	.n
	move.w	d6,d5
	addq.w	#1,d5
.z:	moveq	#0,d2
	bsr	.bar
	addq.w	#1,d5
	cmp.w	#36,d5
	ble.s	.z
.n:	addq.w	#1,d7
	cmp.w	#6,d7
	bne	.a
	movem.l	(sp)+,d3-d7/a3
	rts
.xy:	move.w	d7,d0			; d0 = (a div 3)*230, d1 = (a mod 3)*30+37
	ext.l	d0
	divu	#3,d0
	move.w	d0,d1
	mulu	#230,d1
	swap	d0
	mulu	#30,d0
	add.w	#37,d0
	exg	d0,d1
	rts
.bar:	move.w	d7,d0			; screen[(a mod 3)*30+48 and +49, (a div 3)*258+b+13] := d2
	ext.l	d0
	divu	#3,d0
	move.w	d0,d1
	mulu	#258,d1
	add.w	d5,d1
	add.w	#13,d1
	swap	d0
	mulu	#30,d0
	add.w	#48,d0
	exg	d0,d1
	movem.w	d0-d2,-(sp)
	bsr	ms_pset
	movem.w	(sp)+,d0-d2
	addq.w	#1,d1
	bra	ms_pset

; the cursor lights of crew member contactindex: pixels with value div 16 = from -> +add
cc_cursorlights:
	movem.l	d3-d6,-(sp)
	move.w	d0,d5			; from (3 or 5)
	move.w	d1,d6			; add (32 or -32)
	move.w	cm_contactindex,d0
	ext.l	d0
	divu	#3,d0
	move.w	d0,d4			; contactindex div 3
	swap	d0
	mulu	#30,d0
	add.w	#37,d0
	move.w	d0,d3			; first row
	mulu	#138,d4
	add.w	#89,d4			; first column
	moveq	#6-1,d2
.r:	move.w	d4,d0
	move.w	d3,d1
	movem.w	d2,-(sp)
	bsr	ms_addr
	movem.w	(sp)+,d2
	moveq	#5-1,d1
.c:	move.b	(a0),d0
	lsr.b	#4,d0
	cmp.b	d5,d0
	bne.s	.n
	add.b	d6,(a0)
.n:	addq.l	#1,a0
	dbf	d1,.c
	addq.w	#1,d3
	dbf	d2,.r
	move.w	d4,d0
	move.w	d3,d1
	subq.w	#6,d1
	move.w	d4,d2
	addq.w	#4,d2
	subq.w	#1,d3
	bsr	ms_dirty
	movem.l	(sp)+,d3-d6
	rts

; showportrait(n d0): loadscreen(image nn); rows 41.. even rows then odd rows, delay each
cc_showportrait:
	movem.l	d3-d4/a3,-(sp)
	move.w	d0,d3
	bsr	orc_dump
	bsr	mb_portraits
	move.w	d3,d0
	subq.w	#1,d0
	mulu	#70*70,d0
	move.l	mb_pics,a3
	add.l	d0,a3
	moveq	#0,d4			; first pass rows 0, 2, .. 68 to 41, 43, ..; then 1, 3, ..
.p:	moveq	#0,d3
.r:	move.w	d3,d1
	add.w	d3,d1
	add.w	d4,d1			; i*2 (+1)
	move.w	d1,d0
	mulu	#70,d0
	lea	0(a3,d0.l),a1
	add.w	#41,d1
	move.w	#126,d0
	movem.w	d1,-(sp)
	bsr	ms_addr
	moveq	#70/2-1,d0
.c:	move.b	(a1)+,(a0)+
	move.b	(a1)+,(a0)+
	dbf	d0,.c
	movem.w	(sp)+,d1
	move.w	#126,d0
	move.w	#195,d2
	move.w	d3,-(sp)
	move.w	d1,d3
	bsr	ms_dirty
	move.w	(sp)+,d3
	move.w	GS_TSLICE(a6),d0	; delay(tslice div 5)
	ext.l	d0
	divs	#5,d0
	bsr	delay
	addq.w	#1,d3
	cmp.w	#35,d3
	bne.s	.r
	addq.w	#1,d4
	cmp.w	#2,d4
	bne.s	.p
	movem.l	(sp)+,d3-d4/a3
	rts

cc_portrait_of:				; d0 := ship.crew[contactindex+1].index
	move.w	cm_contactindex,d0
	addq.w	#1,d0
	bsr	ct_crew
	moveq	#0,d0
	move.b	CREW_INDEX(a0),d0
	rts

; command2(n d0): talk to crew member n (0-5)
cc_command2:
	move.l	d3,-(sp)
	move.w	d0,d3
	bsr	mousehide
	BAR	15,135,292,189,0
	PXY	12,182,"Subject:"
	tst.w	cm_contactindex
	bmi.s	.n
	moveq	#5,d0			; erasecursor
	moveq	#-32,d1
	bsr	cc_cursorlights
.n:	move.w	d3,cm_contactindex
	moveq	#3,d0			; drawcursor: the lights, the portrait
	moveq	#32,d1
	bsr	cc_cursorlights
	bsr	cc_portrait_of
	bsr	cc_showportrait
	bsr	cc_portrait_of		; showportrait again
	bsr	cc_showportrait
	bsr	mouseshow
	bsr	cm_loadconversation
	lea	cm_question,a0		; question := 'HI'
	move.b	#2,(a0)+
	move.b	#'H',(a0)+
	move.b	#'I',(a0)+
	bsr	cc_checkstring
	move.l	(sp)+,d3
	rts

cc_checkstring:				; checkstring(95, 42, 170)
	move.w	#95,cm_pm
	move.w	#42,cm_pn
	move.w	#170,cm_po
	bra	cm_checkstring

cc_findmouse:
	movem.l	d3-d4,-(sp)
	bsr	kbd_mouse_status
	tst.b	d0
	beq	.x
	bsr	kbd_mouse_xy
	move.w	d0,d3
	move.w	d1,d4
	moveq	#0,d0			; rows 30-50, 60-80, 90-110: crew 0/3, 1/4, 2/5
	cmp.w	#30,d4
	blt.s	.o
	cmp.w	#50,d4
	ble.s	.lr
	moveq	#1,d0
	cmp.w	#60,d4
	blt.s	.o
	cmp.w	#80,d4
	ble.s	.lr
	moveq	#2,d0
	cmp.w	#90,d4
	blt.s	.o
	cmp.w	#110,d4
	ble.s	.lr
.o:	cmp.w	#154,d4			; 154..170, x > 309: done
	blt.s	.i
	cmp.w	#170,d4
	bgt.s	.i
	cmp.w	#309,d3
	ble.s	.i
	st	GS_DONE(a6)
	bra.s	.i
.lr:	cmp.w	#9,d3
	blt.s	.i
	cmp.w	#85,d3
	ble.s	.c
	addq.w	#3,d0
	cmp.w	#235,d3
	blt.s	.i
	cmp.w	#311,d3
	bgt.s	.i
.c:	cmp.w	cm_contactindex,d0
	beq.s	.i
	bsr	cc_command2
.i:	clr.w	GS_IDLETIME(a6)
.x:	movem.l	(sp)+,d3-d4
	rts

cc_processkey:
	move.l	d3,-(sp)
	bsr	kbd_readkey
	bsr	cm_upcase
	move.w	#31,GS_TCOLOR(a6)
	move.b	d0,d3
	bsr	cm_editkey
	bne	.x
	tst.b	d3
	bne.s	.cr
	bsr	kbd_readkey		; #0: extended keys
	tst.w	cm_contactindex
	bmi.s	.f
	move.b	d0,d3
	bsr	cm_editscan
	bne.s	.x
	move.b	d3,d0
.f:	cmp.b	#59,d0			; F1-F6: command2(0-5)
	blo.s	.x
	cmp.b	#64,d0
	bhi.s	.x
	sub.b	#59,d0
	ext.w	d0
	bsr	cc_command2
	bra.s	.x
.cr:	cmp.b	#13,d3
	bne.s	.esc
	tst.w	cm_contactindex
	bmi.s	.x
	move.w	cm_contactindex,d3	; old
	bsr	cc_checkstring
	tst.w	cm_contactindex		; good bye: the old one's lights off
	bpl.s	.x
	move.w	d3,cm_contactindex
	moveq	#5,d0
	moveq	#-32,d1
	bsr	cc_cursorlights
	move.w	#-1,cm_contactindex
	bra.s	.x
.esc:	cmp.b	#'`',d3			; bossmode
	bne.s	.eb
	bsr	bossmode
	bra.s	.x
.eb:	cmp.b	#27,d3
	bne.s	.x
	st	GS_DONE(a6)
.x:	clr.w	GS_IDLETIME(a6)
	move.l	(sp)+,d3
	rts

cm_upcase:
	cmp.b	#'a',d0
	blo.s	.x
	cmp.b	#'z',d0
	bhi.s	.x
	sub.b	#32,d0
.x:	rts

cc_mainloop:
.l:	moveq	#8,d0			; fadestep(FADESTEP_STEP)
	bsr	fadestep
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	cc_processkey
.nk:	bsr	cc_findmouse
	bsr	cm_batindex
	tst.w	cm_contactindex
	bmi.s	.nb
	moveq	#95,d0
	bsr	cm_blink
	bra.s	.e
.nb:	bsr	cm_delay_blink
.e:	tst.b	GS_DONE(a6)
	beq.s	.l
	rts

cm_batindex:				; batindex / addtime2, idletime / screensaver
	cmp.w	#8,GS_BATINDEX(a6)
	bge.s	.b0
	addq.w	#1,GS_BATINDEX(a6)
	bra.s	.i
.b0:	clr.w	GS_BATINDEX(a6)
	bsr	addtime2
.i:	addq.w	#1,GS_IDLETIME(a6)
	cmp.w	#MAXIDLE,GS_IDLETIME(a6)
	bne.s	.x
	bsr	screensaver
.x:	rts

; ---------------------------------------------------------------- alien contact
continuecontact:
	movem.l	d3-d7/a3-a5,-(sp)
	move.b	d0,d3
	bsr	cm_clearconvflags
	move.b	d3,d0
	bsr	cm_readydata3
	tst.w	cm_contactindex
	bmi.s	.r
	bsr	cm_mainloop3
.r:	bsr	cm_removedata
	movem.l	(sp)+,d3-d7/a3-a5
	rts

; contactsequence(plan d0, com d1)
cm_contactsequence:
	movem.l	d3-d5,-(sp)
	move.w	d0,d3
	move.w	d1,d4
	bsr	mousehide
	tst.w	d3			; techlvl
	bne.s	.p1
	move.w	GS_ALIEN+ALIEN_TECHMAX(a6),cm_techlvl
	bra.s	.t
.p1:	bmi.s	.p0
	cmp.w	#1000,d3
	bge.s	.p2
	move.w	d3,d0
	bsr	cm_gettechlevel
	bra.s	.t
.p2:	cmp.w	#1000,d3
	beq.s	.p0
	move.w	#1280,cm_techlvl
	bra.s	.t
.p0:	clr.w	cm_techlvl
.t:	cmp.w	#1,cm_techlvl
	bge.s	.ok
	PXY	12,135,"Unintelligible Cypher"
	PXY	12,145,"Contact Failure"
	bsr	mouseshow
	bra	.x
.ok:	moveq	#0,d5			; contactmade
	move.w	cm_eattype,d0
	cmp.b	#4,cm_techlvl		; hi(techlvl) < 4
	bhs.s	.hi
	tst.w	d0
	bne.s	.l1
	moveq	#1,d5
	bra	.cm
.l1:	cmp.w	#1,d0
	bne.s	.l2
	moveq	#5,d5
	tst.w	d4
	beq.s	.cm
	moveq	#3,d5
	cmp.w	#1,d4
	beq.s	.cm
	moveq	#0,d5
	cmp.w	#2,d4
	bne.s	.cm
	moveq	#2,d5
	bra.s	.cm
.l2:	cmp.w	#2,d0
	bne.s	.cm
.r5:	moveq	#5,d0
	bsr	mt_random
	move.w	d0,d5
	bra.s	.cm
.hi:	tst.w	d0
	bne.s	.h1
	tst.w	d4			; eattype 0
	bne.s	.h01
	moveq	#2,d0
	bsr	mt_random
	moveq	#3,d5
	tst.w	d0
	bne.s	.cm
	moveq	#1,d5
	bra.s	.cm
.h01:	cmp.w	#1,d4
	bne.s	.h02
.r22:	moveq	#2,d0
	bsr	mt_random
	addq.w	#2,d0
	move.w	d0,d5
	bra.s	.cm
.h02:	cmp.w	#2,d4
	bne.s	.cm
	moveq	#2,d5
	bra.s	.cm
.h1:	cmp.w	#1,d0
	bne.s	.h2
	moveq	#4,d5
	tst.w	d4
	beq.s	.cm
	cmp.w	#1,d4
	beq.s	.r22
	moveq	#0,d5
	cmp.w	#2,d4
	bne.s	.cm
	moveq	#2,d5
	bra.s	.cm
.h2:	cmp.w	#2,d0
	beq.s	.r5
.cm:	tst.w	d5
	ble.s	.nc
	tst.w	cm_contactindex
	bpl.s	.nc
	move.w	d3,cm_contactindex	; contactindex := plan; notes or 2; setalienstructure
	move.w	d3,d0
	bsr	cm_plan
	or.b	#2,PLANET_NOTES(a0)
	move.w	d5,d0
	bsr	cm_setalienstructure
.nc:	PXY	12,135,"Cypher Acknowledged"
	PXY	12,145,"Awaiting Response"
	tst.w	d5
	ble.s	.nr
	PXY	12,155,"Contact Established"
	bra.s	.ms
.nr:	move.w	#-1,cm_contactindex
.ms:	bsr	mouseshow
.x:	movem.l	(sp)+,d3-d5
	rts

cm_plan:				; a0 = tempplan^[d0]
	subq.w	#1,d0
	mulu	#PLANET_SIZEOF,d0
	move.l	GS_TEMPPLAN(a6),a0
	add.l	d0,a0
	rts

; gettechlevel(plan d0) -> cm_techlvl, cm_eattype
cm_gettechlevel:
	move.l	d3,-(sp)
	move.w	d0,d3
	bsr	gettechnologylevel
	move.w	d0,cm_techlvl
	move.w	d3,d0			; the cases that exit early draw no random numbers
	bsr	cm_plan
	tst.b	PLANET_ORBIT(a0)
	beq.s	.x
	moveq	#0,d0
	move.b	PLANET_SYSTEM(a0),d0
	lea	.six,a1
.s:	move.w	(a1)+,d1
	bmi.s	.r
	cmp.w	d1,d0
	beq.s	.x
	bra.s	.s
.r:	moveq	#9,d0			; i := random(9); eattype := random(3); randomize
	bsr	mt_random
	moveq	#3,d0
	bsr	mt_random
	move.w	d0,cm_eattype
	bsr	mt_randomize
.x:	move.l	(sp)+,d3
	rts
.six:	dc.w	93,138,78,191,171,221,45,-1

; getname(n d0): alien.name := planname.txt record n - tempplan^[n].system
cm_getname:
	movem.l	d3,-(sp)
	move.w	d0,d3
	bsr	cm_plan
	moveq	#0,d0
	move.b	PLANET_SYSTEM(a0),d0
	sub.w	d0,d3
	clr.w	-(sp)
	pea	cm_fn_planname
	FDOS	GD_FOPEN,8
	move.w	d0,d1
	bmi	fatal
	move.w	d1,-(sp)		; (for the close)
	clr.w	-(sp)
	move.w	d1,-(sp)
	move.w	d3,d0
	ext.l	d0
	lsl.l	#4,d0			; string[15] = 16 bytes
	move.l	d0,-(sp)
	FDOS	GD_FSEEK,10
	pea	GS_ALIEN+ALIEN_NAME(a6)
	pea	16
	move.w	4+4(sp),-(sp)
	FDOS	GD_FREAD,12
	cmp.l	#16,d0
	bne	fatal
	FDOS	GD_FCLOSE,4
	movem.l	(sp)+,d3
	rts

; setalienstructure(starting d0)
cm_setalienstructure:
	movem.l	d3-d5,-(sp)
	move.w	d0,d5
	move.w	cm_contactindex,d0
	bsr	cm_plan
	moveq	#0,d0
	move.b	PLANET_SYSTEM(a0),d0
	lea	.spec,a1
.sp:	move.w	(a1)+,d1
	bmi.s	.gen
	move.w	(a1)+,d2
	cmp.w	d1,d0
	bne.s	.sp
	cmp.w	#45,d0
	bne.s	.gs
	move.w	d2,-(sp)
	moveq	#27,d0
	bsr	chevent
	movem.w	(sp)+,d2		; (keeps the flags)
	bne	.add
.gs:	move.w	d2,d0
.gsp:	move.w	cm_contactindex,d1
	bsr	getspecial
	bra	.add
.gen:	cmp.b	#2,PLANET_MODE(a0)
	bne.s	.g2
	cmp.b	#6,PLANET_STATE(a0)
	bne.s	.g2
	moveq	#11,d0
	bra.s	.gsp
.g2:	move.w	cm_techlvl,d0		; conindex := 30 + (hi 3, 4, 5 -> 1, 2, 3; else 0)
	lsr.w	#8,d0
	and.w	#$ff,d0
	moveq	#0,d1
	subq.w	#2,d0
	ble.s	.ci
	cmp.w	#3,d0
	bgt.s	.ci
	move.w	d0,d1
.ci:	add.w	#30,d1
	move.w	d1,GS_ALIEN+ALIEN_CONINDEX(a6)
	move.w	cm_contactindex,d0
	bsr	cm_getname
	moveq	#0,d3			; x := hi(techlvl); y := lo(techlvl) - 5
	move.b	cm_techlvl,d3
	moveq	#0,d4
	move.b	cm_techlvl+1,d4
	subq.w	#5,d4
	bpl.s	.y1
	subq.w	#1,d3
	add.w	#10,d4
.y1:	tst.w	d3
	bpl.s	.y2
	moveq	#0,d3
	moveq	#0,d4
.y2:	move.w	d3,d0
	lsl.w	#8,d0
	add.w	d4,d0
	move.w	d0,GS_ALIEN+ALIEN_TECHMIN(a6)
	moveq	#0,d4			; y := lo(techlvl) + 5
	move.b	cm_techlvl+1,d4
	addq.w	#5,d4
	cmp.w	#9,d4
	ble.s	.y3
	addq.w	#1,d3
	sub.w	#10,d4
.y3:	cmp.w	#5,d3
	ble.s	.y4
	moveq	#5,d3
	moveq	#0,d4
.y4:	move.w	d3,d0
	lsl.w	#8,d0
	add.w	d4,d0
	move.w	d0,GS_ALIEN+ALIEN_TECHMAX(a6)
	move.w	d3,GS_X(a6)
	move.w	d4,GS_Y(a6)
	move.w	cm_contactindex,GS_ALIEN+ALIEN_ID(a6)
	moveq	#40,d0
	bsr	mt_random
	move.w	d0,GS_ALIEN+ALIEN_VICTORY(a6)
	sf	GS_ALIEN+ALIEN_WAR(a6)
	lea	GS_ALIEN(a6),a0
	cmp.w	#1,d5
	bne.s	.s2
	moveq	#3,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.s1
	move.b	#1,GS_ALIEN+ALIEN_WAR(a6)
.s1:	move.w	#15,GS_ALIEN+ALIEN_CONGENIALITY(a6)
	move.w	#30,GS_ALIEN+ALIEN_ANGER(a6)
	moveq	#WNDORDER_ATTACK,d0
	bsr	createwandering
	bra.s	.add
.s2:	moveq	#20,d0
	moveq	#10,d1
	cmp.w	#2,d5
	beq.s	.set
	moveq	#40,d0
	moveq	#0,d1
	cmp.w	#3,d5
	beq.s	.set
	moveq	#20,d0
	moveq	#15,d1
	cmp.w	#4,d5
	beq.s	.set
	cmp.w	#5,d5
	bne.s	.add
	move.w	#5,GS_ALIEN+ALIEN_CONGENIALITY(a6)
	clr.w	GS_ALIEN+ALIEN_ANGER(a6)
	moveq	#WNDORDER_RETREAT,d0
	bsr	createwandering
	bra.s	.add
.set:	move.w	d0,GS_ALIEN+ALIEN_CONGENIALITY(a6)
	move.w	d1,GS_ALIEN+ALIEN_ANGER(a6)
.add:	bsr	addtofile
	movem.l	(sp)+,d3-d5
	rts
.spec:	dc.w	93,1,138,2,45,4,221,5,78,6,171,8,191,9,-1

; read TEMP\CONTACTS.DTA until a record with id > 0 and id = d0 (or the end: the last record
; read stays in the buffer)  in: a0 = buffer  out: Z set = found
cm_findcontact:
	movem.l	d3-d4/a3,-(sp)
	move.w	d0,d4
	move.l	a0,a3
	clr.w	-(sp)
	pea	cm_fn_contacts2
	FDOS	GD_FOPEN,8
	move.w	d0,d3
	bmi	fatal
.r:	pea	cm_rec2
	move.l	#ALIEN_SIZEOF,-(sp)
	move.w	d3,-(sp)
	FDOS	GD_FREAD,12
	cmp.l	#ALIEN_SIZEOF,d0
	bne.s	.end
	lea	cm_rec2,a0
	move.l	a3,a1
	moveq	#ALIEN_SIZEOF/2-1,d0
.c:	move.w	(a0)+,(a1)+
	dbf	d0,.c
	move.w	ALIEN_ID(a3),d0
	ble.s	.r
	cmp.w	d4,d0
	bne.s	.r
	move.w	d3,-(sp)
	FDOS	GD_FCLOSE,4
	moveq	#0,d0
	bra.s	.x
.end:	move.w	d3,-(sp)
	FDOS	GD_FCLOSE,4
	moveq	#1,d0
.x:	movem.l	(sp)+,d3-d4/a3
	tst.w	d0
	rts

; getlocals: contact the aliens of the planet in orbit
cm_getlocals:
	tst.b	GS_SHOWPLANET(a6)
	bne.s	.sp
	move.w	#-1,cm_contactindex
	rts
.sp:	move.w	GS_CURPLAN(a6),d0
	lea	GS_ALIEN(a6),a0
	move.w	#-1,cm_contactindex
	bsr	cm_findcontact
	bne.s	.n
	move.w	GS_CURPLAN(a6),cm_contactindex
.n:	move.w	GS_CURPLAN(a6),d0
	bsr	cm_plan
	cmp.b	#45,PLANET_SYSTEM(a0)
	bne.s	.c
	move.l	a0,-(sp)
	moveq	#27,d0
	bsr	chevent
	move.l	(sp)+,a0
	beq.s	.c
	move.w	#-1,cm_contactindex
	and.b	#$fd,PLANET_NOTES(a0)
.c:	moveq	#3,d0			; contactsequence(curplan, random(3))
	bsr	mt_random
	move.w	d0,d1
	move.w	GS_CURPLAN(a6),d0
	bra	cm_contactsequence

; getship: contact the alien ship about
cm_getship:
	cmp.w	#19999,GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6)
	ble.s	.f
	move.w	#-1,cm_contactindex
	moveq	#3,d0
	bsr	mt_random
	move.w	d0,d1
	moveq	#-1,d0
	bra	cm_contactsequence
.f:	move.w	GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6),d0
	lea	GS_ALIEN(a6),a0
	move.w	#-1,cm_contactindex
	bsr	cm_findcontact
	bne.s	.n
	move.w	GS_ALIEN+ALIEN_ID(a6),cm_contactindex
.n:	st	cm_shipflag
	moveq	#3,d0
	bsr	mt_random
	move.w	d0,d1
	move.w	GS_ALIEN+ALIEN_ID(a6),d0
	bra	cm_contactsequence

; a chunky picture DATA\NAME.CHK (64000 or fewer bytes, + a palette) into a1 (the bytes after
; the picture's rows stay as they were), the palette to GS_COLORS  in: a0 = name
cm_loadchk:
	movem.l	d3-d4/a3,-(sp)
	move.l	a1,a3
	lea	ms_path+5,a1
.cp:	move.b	(a0)+,(a1)+
	bne.s	.cp
	move.b	#'.',-1(a1)
	move.b	#'C',(a1)+
	move.b	#'H',(a1)+
	move.b	#'K',(a1)+
	clr.b	(a1)
	lea	ms_path,a0
	bsr	fil_size
	move.l	d0,d4
	bcs	fatal
	bsr	mem_mark		; (Phase 8) the file in one load into a temporary block (it may
	move.l	d0,-(sp)		; be packed), then the picture and the palette
	move.l	d4,d0
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,-(sp)
	move.l	a0,a1
	lea	ms_path,a0
	move.l	d4,d0
	bsr	fil_load
	bcs	fatal
	move.l	d4,d0			; picture bytes: the size without the palette
	cmp.l	#64000,d0
	bls.s	.np
	sub.l	#768,d0
.np:	move.l	(sp),a0
	move.l	a3,a1
	bsr	fil_copy
	cmp.l	#64000,d4
	bls.s	.cl
	move.l	(sp),a0			; the palette after the picture
	add.l	d4,a0
	sub.w	#768,a0
	lea	GS_COLORS(a6),a1
	move.l	#768,d0
	bsr	fil_copy
.cl:	addq.l	#4,sp
	move.l	(sp)+,d0
	bsr	mem_release
	movem.l	(sp)+,d3-d4/a3
	rts

; loadbackground(n d0)
cm_loadbackground:
	movem.l	d3-d4/a3-a4,-(sp)
	move.w	d0,d3
	bsr	orc_dump		; loadscreen(back nn, backgr)
	move.w	d3,d0			; ((n-1) div 2)+1
	subq.w	#1,d0
	lsr.w	#1,d0
	addq.w	#1,d0
	lea	cm_name+4,a0
	cmp.w	#10,d0
	blt.s	.one
	move.b	#'1',(a0)+
	sub.w	#10,d0
.one:	add.b	#'0',d0
	move.b	d0,(a0)+
	clr.b	(a0)
	lea	cm_name,a0
	move.l	#'BACK',(a0)
	move.l	GS_BACKGR(a6),a1
	bsr	cm_loadchk
	lea	GS_COLORS(a6),a0	; move(colors, p^)
	lea	cm_p,a1
	move.w	#768/4-1,d0
.pc:	move.l	(a0)+,(a1)+
	dbf	d0,.pc
	move.w	d3,d0			; y = 1: the bottom half up
	subq.w	#1,d0
	btst	#0,d0
	beq.s	.c
	move.l	GS_BACKGR(a6),a1
	lea	100*320(a1),a0
	move.w	#8000-1,d0
.mv:	move.l	(a0)+,(a1)+
	dbf	d0,.mv
.c:	bsr	mousehide		; rows 11-110: 255 -> backgr^[i-11, j]
	move.l	GS_BACKGR(a6),a0
	move.l	ms_buf,a1
	lea	11*320(a1),a1
	move.w	#100*320-1,d0
	moveq	#-1,d1
.p:	cmp.b	(a1)+,d1
	bne.s	.pn
	move.b	(a0),-1(a1)
.pn:	addq.l	#1,a0
	dbf	d0,.p
	moveq	#0,d0
	moveq	#11,d1
	move.w	#319,d2
	moveq	#110,d3
	bsr	ms_dirty
	bsr	mouseshow
	movem.l	(sp)+,d3-d4/a3-a4
	rts

; loadalienpic(n d0)
cm_loadalienpic:
	movem.l	d3,-(sp)
	move.w	d0,d3
	move.l	#64000,d0		; new(aliens)
	bsr	mem_alloc
	bcs	fatal
	move.l	a0,cm_aliens
	bsr	orc_dump		; loadscreen(alien n, aliens)
	lea	cm_name,a0
	move.l	#'ALIE',(a0)
	move.w	#'N'*256,4(a0)
	lea	5(a0),a0
	move.w	d3,d0
	cmp.w	#10,d0
	blt.s	.one
	move.b	#'1',(a0)+
	sub.w	#10,d0
.one:	add.b	#'0',d0
	move.b	d0,(a0)+
	clr.b	(a0)
	lea	cm_name,a0
	move.l	cm_aliens,a1
	bsr	cm_loadchk
	lea	cm_p,a0			; colors[0..159] := p^[0..159]
	lea	GS_COLORS(a6),a1
	move.w	#160*3/4-1,d0
.pc:	move.l	(a0)+,(a1)+
	dbf	d0,.pc
	cmp.w	#10,d3
	beq.s	.x
	bsr	mousehide		; rows 11-110, x 0-159: aliens > 0 -> screen[i, j+20]
	move.l	cm_aliens,a0
	move.l	ms_buf,a1
	lea	11*320+20(a1),a1
	moveq	#100-1,d1
.r:	move.w	#160-1,d0
.p:	move.b	(a0)+,d2
	beq.s	.pn
	move.b	d2,(a1)
.pn:	addq.l	#1,a1
	dbf	d0,.p
	lea	160(a0),a0
	lea	160(a1),a1
	dbf	d1,.r
	moveq	#20,d0
	moveq	#11,d1
	move.w	#179,d2
	moveq	#110,d3
	bsr	ms_dirty
	bsr	mouseshow
.x:	movem.l	(sp)+,d3
	rts

; getcontactindex
cm_getcontactindex:
	movem.l	d3,-(sp)
	move.w	GS_ALIEN+ALIEN_CONINDEX(a6),d3
	cmp.w	#29,d3
	ble.s	.race
	move.w	d3,d0			; randseed := conindex; loadbackground(random(19)+1)
	ext.l	d0
	bsr	mt_setseed
	moveq	#19,d0
	bsr	mt_random
	addq.w	#1,d0
	bsr	cm_loadbackground
	lea	cm_fn_probe,a0
	bsr	playmod
	lea	cm_bands,a0		; (the band design COMGn)
	move.l	#'COMG',(a0)
	move.w	d3,d0
	bsr	cm_num
	add.w	#1069,d3
	bra	.ri
.race:	move.w	d3,d0			; randseed := conindex*1131
	muls	#1131,d0
	bsr	mt_setseed
	move.w	d3,d0
	subq.w	#1,d0
	cmp.w	#10,d0
	bhi	fatal			; (conindex 1-11 only)
	add.w	d0,d0
	lea	.songs,a0
	move.w	0(a0,d0.w),d0
	lea	0(a0,d0.w),a1
	lea	cm_fn_song+6,a0
.s:	move.b	(a1)+,(a0)+
	bne.s	.s
	lea	cm_fn_song,a0
	bsr	playmod
.nm:	move.w	d3,d0			; loadbackground(j)
	subq.w	#1,d0
	lea	.backs,a0
	move.b	0(a0,d0.w),d0
	ext.w	d0
	bsr	cm_loadbackground
	cmp.w	#11,d3
	bge.s	.np
	move.w	d3,d0
	bsr	cm_loadalienpic
.np:	lea	cm_bands,a0		; (the band design COMAn)
	move.l	#'COMA',(a0)
	move.w	d3,d0
	bsr	cm_num
	bsr	cm_setbands
	bsr	animatealien
	add.w	#999,d3
	bra.s	.ri2
.ri:	bsr	cm_setbands
.ri2:	bsr	mt_randomize
	move.w	d3,cm_contactindex
	movem.l	(sp)+,d3
	rts
.backs:	dc.b	7,18,9,15,22,17,4,14,2,21,19
	even
.songs:	dc.w	.s1-.songs,.s2-.songs,.s3-.songs,.s4-.songs,.s5-.songs,.s6-.songs
	dc.w	.s7-.songs,.s8-.songs,.s9-.songs,.s10-.songs,.s11-.songs
.s1:	dc.b	"SENGZHAC.MOD",0
.s2:	dc.b	"DPAK.MOD",0
.s3:	dc.b	"AARD.MOD",0
.s4:	dc.b	"ERMIGEN.MOD",0
.s5:	dc.b	"TITARIAN.MOD",0
.s6:	dc.b	"QUAI.MOD",0
.s7:	dc.b	"SCAVENG.MOD",0
.s8:	dc.b	"ICON.MOD",0
.s9:	dc.b	"GUILD.MOD",0
.s10:	dc.b	"PHADOR.MOD",0
.s11:	dc.b	"VOID.MOD",0
	even

; cm_bands+4 := the decimal number d0 (1-2 digits), 0-terminated
cm_num:
	lea	cm_bands+4,a0
	ext.l	d0
	divu	#10,d0
	tst.w	d0
	beq.s	.one
	add.b	#'0',d0
	move.b	d0,(a0)+
.one:	swap	d0
	add.b	#'0',d0
	move.b	d0,(a0)+
	clr.b	(a0)
	rts

; the screen's band design DATA\<cm_bands>.ISP (bands, LUTs, reps), then everything redrawn
cm_setbands:
	lea	ms_path+5,a1
	lea	cm_bands,a0
.cp:	move.b	(a0)+,(a1)+
	bne.s	.cp
	move.b	#'.',-1(a1)
	move.b	#'I',(a1)+
	move.b	#'S',(a1)+
	move.b	#'P',(a1)+
	clr.b	(a1)
	lea	ms_path,a0
	bsr	pal_load
	bcs	fatal
	bra	ms_dirty_all

; getinfo: the info panel on and off
getinfo:
	movem.l	d3/a3,-(sp)
	bsr.s	.go
	movem.l	(sp)+,d3/a3
	rts
.go:	tst.b	cm_infomode
	beq.s	.on
	sf	cm_infomode
	bsr	mousehide		; rows 20-101, x 222-297 from backgr^[i-11]
	moveq	#20,d3
.r:	move.w	#222,d0
	move.w	d3,d1
	bsr	ms_addr
	move.w	d3,d0
	sub.w	#11,d0
	mulu	#320,d0
	move.l	GS_BACKGR(a6),a1
	add.l	d0,a1
	lea	222(a1),a1
	moveq	#76/4-1,d0
.c:	move.b	(a1)+,(a0)+
	move.b	(a1)+,(a0)+
	move.b	(a1)+,(a0)+
	move.b	(a1)+,(a0)+
	dbf	d0,.c
	addq.w	#1,d3
	cmp.w	#101,d3
	ble.s	.r
	move.w	#222,d0
	moveq	#20,d1
	move.w	#297,d2
	moveq	#101,d3
	bsr	ms_dirty
	bra	mouseshow
.on:	tst.w	cm_contactindex
	bmi	.x
	st	cm_infomode
	move.w	#31,GS_TCOLOR(a6)
	move.w	#255,GS_BKCOLOR(a6)
	tst.b	cm_shipflag
	beq.s	.pl
	lea	cm_rec3,a0		; getshipinfo: the ship's record from the contacts
	move.w	GS_SHIP+SHIP_WANDERING+ONEALIEN_ALIENID(a6),d0
	bsr	cm_findcontact
	lea	cm_rec3,a3
	move.l	a3,a0
	bsr	.name
	move.l	a3,a0
	bsr	.name
	PXY	217,30,"Vidcom"
	move.w	ALIEN_ID(a3),d0
	cmp.w	#1000,d0
	ble.s	.kn
	PXY	217,40,"Unknown"
	bra	.tech
.kn:	bsr	.sysname
	bra	.tech
.pl:	lea	GS_ALIEN(a6),a3
	move.l	a3,a0
	bsr	.name
	move.w	GS_CURPLAN(a6),d0
	cmp.w	ALIEN_ID(a3),d0
	bne.s	.sub
	cmp.b	#3,ALIEN_TECHMAX(a3)
	blo.s	.vis
	PXY	217,30,"Radio"
	bra.s	.sn
.vis:	PXY	217,30,"Visual"
	bra.s	.sn
.sub:	PXY	217,30,"Subspace"
.sn:	move.w	GS_CURPLAN(a6),d0
	bsr	.sysname
.tech:	lea	cm_s,a0			; 'Min Tech: h.l'
	move.w	ALIEN_TECHMIN(a3),d0
	bsr	.techs
	lea	cm_s+1,a0
	move.b	#'M',(a0)+
	move.b	#'i',(a0)+
	move.b	#'n',(a0)+
	lea	cm_s,a0
	moveq	#50,d1
	move.w	#217,d0
	bsr	printxy
	lea	cm_s,a0
	move.w	ALIEN_TECHMAX(a3),d0
	bsr	.techs
	lea	cm_s+1,a0
	move.b	#'M',(a0)+
	move.b	#'a',(a0)+
	move.b	#'x',(a0)+
	lea	cm_s,a0
	move.w	#217,d0
	moveq	#60,d1
	bsr	printxy
	PXY	217,70,"Status:"
	tst.b	ALIEN_WAR(a3)
	beq.s	.pe
	PXY	252,70,"War"
	bra.s	.an
.pe:	PXY	252,70,"Peace"
.an:	move.w	ALIEN_ANGER(a3),d0
	move.w	ALIEN_CONGENIALITY(a3),d1
	bsr	calc_anger
	subq.w	#1,d0
	cmp.w	#4,d0
	bhi.s	.x
	mulu	#12,d0
	lea	.moods,a0
	add.w	d0,a0
	move.w	#217,d0
	moveq	#80,d1
	bsr	printxy
.x:	rts
.name:	move.w	#217,d0
	moveq	#20,d1
	bra	printxy
.sysname:				; printxy(217, 40, systems[tempplan^[d0].system].name)
	bsr	cm_plan
	moveq	#0,d0
	move.b	PLANET_SYSTEM(a0),d0
	subq.w	#1,d0
	mulu	#SYSTEM_SIZEOF,d0
	lea	GS_SYSTEMS+SYSTEM_NAME(a6),a0
	add.l	d0,a0
	move.w	#217,d0
	moveq	#40,d1
	bra	printxy
.techs:	move.b	#13,(a0)+		; 'xxx Tech: h.l'
	addq.l	#4,a0
	move.b	#'T',(a0)+
	move.b	#'e',(a0)+
	move.b	#'c',(a0)+
	move.b	#'h',(a0)+
	move.b	#':',(a0)+
	move.b	#' ',(a0)+
	move.w	d0,d1
	lsr.w	#8,d1
	add.b	#'0',d1
	move.b	d1,(a0)+
	move.b	#'.',(a0)+
	add.b	#'0',d0
	move.b	d0,(a0)+
	rts
.moods:	dc.b	6,"Afraid",0,0,0,0,0
	dc.b	11,"Indifferent"
	dc.b	8,"Friendly",0,0,0
	dc.b	5,"Angry",0,0,0,0,0,0
	dc.b	7,"Violent",0,0,0,0
	even

cm_findmouse3:
	movem.l	d3-d4,-(sp)
	bsr	kbd_mouse_status
	tst.b	d0
	beq.s	.x
	bsr	kbd_mouse_xy
	move.w	d0,d3
	move.w	d1,d4
	cmp.w	#308,d3
	blt.s	.i
	cmp.w	#317,d3
	bgt.s	.i2
	cmp.w	#142,d4
	ble.s	.i2
	cmp.w	#169,d4
	bge.s	.i2
	st	GS_DONE(a6)
	bra.s	.i2
.i:	cmp.w	#247,d3
	blt.s	.i2
	cmp.w	#267,d3
	bgt.s	.i2
	cmp.w	#104,d4
	ble.s	.i2
	cmp.w	#111,d4
	bge.s	.i2
	bsr	getinfo
.i2:	clr.w	GS_IDLETIME(a6)
.x:	movem.l	(sp)+,d3-d4
	rts

cm_checkstring3:			; checkstring(47, 55, 28)
	move.w	#47,cm_pm
	move.w	#55,cm_pn
	move.w	#28,cm_po
	bra	cm_checkstring

cm_processkey3:
	move.l	d3,-(sp)
	bsr	kbd_readkey
	bsr	cm_upcase
	move.w	#26,GS_TCOLOR(a6)
	move.b	d0,d3
	bsr	cm_editkey
	bne.s	.x
	tst.b	d3
	bne.s	.cr
	bsr	kbd_readkey		; #0: extended keys
	bsr	cm_editscan
	bra.s	.x
.cr:	cmp.b	#13,d3
	bne.s	.q
	tst.w	cm_contactindex
	bmi.s	.x
	bsr	cm_checkstring3
	bra.s	.x
.q:	cmp.b	#'?',d3
	beq.s	.gi
	cmp.b	#'/',d3
	bne.s	.esc
.gi:	bsr	getinfo
	bra.s	.x
.esc:	cmp.b	#'`',d3			; bossmode
	bne.s	.eb
	bsr	bossmode
	bra.s	.x
.eb:	cmp.b	#27,d3
	bne.s	.x
	st	GS_DONE(a6)
.x:	clr.w	GS_IDLETIME(a6)
	move.l	(sp)+,d3
	rts

cm_mainloop3:
.l:	moveq	#8,d0
	bsr	fadestep
	bsr	cm_findmouse3
	bsr	kbd_keypressed
	beq.s	.nk
	bsr	cm_processkey3
.nk:	bsr	cm_batindex
	tst.w	cm_contactindex
	bmi.s	.nb
	moveq	#47,d0
	bsr	cm_blink
	bra.s	.e
.nb:	bsr	cm_delay_blink
.e:	bsr	animatealien
	tst.b	GS_DONE(a6)
	beq.s	.l
	rts

; ---------------------------------------------------------------- animatealien
; a sprite from aliens^ over backgr^: the parameter block cm_bp = dy, dx, h, w, sy, sx, by
; (screen[dy+i, dx+j] := aliens^[sy+i, sx+j] if > 0, else backgr^[by+i, dx+j])
cm_blit:
	movem.l	d3-d7/a3,-(sp)
	movem.w	cm_bp,d3-d7		; dy dx h w sy (sx, by after)
	move.w	d4,d0
	move.w	d3,d1
	bsr	ms_addr
	move.l	a0,a3			; screen
	move.w	d7,d0
	mulu	#320,d0
	add.w	cm_bp+10,d0
	move.l	cm_aliens,a1
	add.l	d0,a1			; aliens
	move.w	cm_bp+12,d0
	mulu	#320,d0
	add.w	d4,d0
	move.l	GS_BACKGR(a6),a2
	add.l	d0,a2			; backgr
	move.w	d5,d2
	subq.w	#1,d2
.r:	move.w	d6,d1
	subq.w	#1,d1
	moveq	#0,d0
.c:	move.b	0(a1,d0.w),d7
	bne.s	.a
	move.b	0(a2,d0.w),d7
.a:	move.b	d7,0(a3,d0.w)
	addq.w	#1,d0
	dbf	d1,.c
	lea	320(a3),a3
	lea	320(a1),a1
	lea	320(a2),a2
	dbf	d2,.r
	bra.s	cm_blitdirty
; opaque: screen[dy+i, dx..] := aliens^[sy+i, sx..] (w bytes)
cm_blitop:
	movem.l	d3-d7/a3,-(sp)
	movem.w	cm_bp,d3-d7
	move.w	d4,d0
	move.w	d3,d1
	bsr	ms_addr
	move.w	d7,d0
	mulu	#320,d0
	add.w	cm_bp+10,d0
	move.l	cm_aliens,a1
	add.l	d0,a1
	move.w	d5,d2
	subq.w	#1,d2
.r:	move.w	d6,d1
	subq.w	#1,d1
	moveq	#0,d0
.c:	move.b	0(a1,d0.w),0(a0,d0.w)
	addq.w	#1,d0
	dbf	d1,.c
	lea	320(a0),a0
	lea	320(a1),a1
	dbf	d2,.r
cm_blitdirty:
	movem.w	cm_bp,d0-d3		; dy dx h w -> x1 y1 x2 y2
	exg	d0,d1
	add.w	d0,d3
	subq.w	#1,d3
	exg	d2,d3
	add.w	d1,d3
	subq.w	#1,d3
	bsr	ms_dirty
	movem.l	(sp)+,d3-d7/a3
	rts

; BLIT dy,dx,h,w,sy,sx,by (sy/sx may be registers or expressions in words)
BP	macro
	move.w	#\1,cm_bp
	move.w	#\2,cm_bp+2
	move.w	#\3,cm_bp+4
	move.w	#\4,cm_bp+6
	move.w	\5,cm_bp+8
	move.w	\6,cm_bp+10
	move.w	#\7,cm_bp+12
	endm

animatealien:
	movem.l	d3-d4,-(sp)
	bsr	mousehide
	move.w	GS_ALIEN+ALIEN_CONINDEX(a6),d0
	subq.w	#1,d0
	cmp.w	#9,d0
	bhi	.done
	add.w	d0,d0
	move.w	.tab(pc,d0.w),d0
	jmp	.tab(pc,d0.w)
.tab:	dc.w	.a1-.tab,.a2-.tab,.a3-.tab,.a4-.tab,.a5-.tab,.a6-.tab,.a7-.tab,.a8-.tab,.a9-.tab,.a10-.tab
.a1:	cmp.w	#255,cm_indexa
	beq.s	.a1r
	cmp.w	#6,cm_indexa
	bge.s	.a1e
	addq.w	#1,cm_indexa
	move.w	cm_indexa,d0
	mulu	#11,d0
	move.w	d0,d3
	BP	37,85,10,33,d3,#220,26
	bsr	cm_blit
	bra.s	.a1b
.a1e:	move.w	#255,cm_indexa
	bra.s	.a1b
.a1r:	moveq	#20,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.a1b
	clr.w	cm_indexa
.a1b:	cmp.w	#14,cm_indexb
	bge.s	.a1b0
	addq.w	#1,cm_indexb
	move.w	cm_indexb,d0		; ((b-1) mod 7)*20, ((b-1) div 7)*24+160
	subq.w	#1,d0
	ext.l	d0
	divu	#7,d0
	move.w	d0,d4
	mulu	#24,d4
	add.w	#160,d4
	swap	d0
	mulu	#20,d0
	move.w	d0,d3
	BP	88,29,19,23,d3,d4,77
	bra.s	.a1bb
.a1b0:	clr.w	cm_indexb
	BP	88,29,19,23,#77,#9,77
.a1bb:	bsr	cm_blit
	moveq	#20,d0
	bsr	mt_random
	tst.w	d0
	bne	.done
	cmp.w	#7,cm_indexc
	bge.s	.a1c0
	addq.w	#1,cm_indexc
	bra.s	.a1c
.a1c0:	clr.w	cm_indexc
.a1c:	move.w	cm_indexc,d3
	mulu	#23,d3
	BP	89,139,22,43,d3,#260,78
	bsr	cm_blit
	bra	.done
.a2:	move.w	#200,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.a2o
	tst.w	cm_indexa
	beq.s	.a2g
.a2o:	cmp.w	#255,cm_indexa
	beq	.done
	tst.w	cm_indexa
	beq	.done
.a2g:	tst.w	cm_indexb
	beq.s	.a2b
	subq.w	#1,cm_indexb
	bra.s	.a2d
.a2b:	move.w	#3,cm_indexb
	cmp.w	#12,cm_indexa
	bge.s	.a2e
	addq.w	#1,cm_indexa
.a2d:	move.w	cm_indexa,d0		; dec(indexa); the frame; inc(indexa)
	subq.w	#1,d0
	ext.l	d0
	divu	#3,d0
	move.w	d0,d4
	mulu	#38,d4
	add.w	#164,d4
	swap	d0
	mulu	#59,d0
	addq.w	#2,d0
	move.w	d0,d3
	BP	16,140,55,35,d3,d4,5
	bsr	cm_blit
	bra	.done
.a2e:	move.w	#255,cm_indexa
	bra	.done
.a3:	tst.w	cm_indexa
	bne	.done
	bsr	mt_randomize
	move.w	#1000,d0
	bsr	mt_random
	moveq	#5,d0
	bsr	mt_random
	move.w	d0,cm_indexb
	move.w	#1,cm_indexa
	move.w	cm_indexb,d3
	mulu	#30,d3
	BP	20,90,24,24,d3,#170,9
	bsr	cm_blit
	bra	.done
.a4:	cmp.w	#255,cm_indexa
	beq.s	.a4r
	move.w	cm_indexa,d3
	mulu	#13,d3
	BP	23,91,12,57,d3,#170,12
	bsr	cm_blit
	cmp.w	#9,cm_indexa
	bge.s	.a4e
	addq.w	#1,cm_indexa
	bra	.done
.a4e:	move.w	#255,cm_indexa
	bra	.done
.a4r:	moveq	#20,d0
	bsr	mt_random
	tst.w	d0
	bne	.done
	clr.w	cm_indexa
	bra	.done
.a5:	cmp.w	#5,cm_indexa
	bge.s	.a50
	addq.w	#1,cm_indexa
	bra.s	.a5a
.a50:	clr.w	cm_indexa
.a5a:	move.w	cm_indexa,d3
	mulu	#12,d3
	BP	29,94,11,49,d3,#170,0
	bsr	cm_blitop
	moveq	#20,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.a5c
	cmp.w	#4,cm_indexb
	bge.s	.a5b0
	addq.w	#1,cm_indexb
	bra.s	.a5b
.a5b0:	clr.w	cm_indexb
.a5b:	move.w	cm_indexb,d3
	mulu	#28,d3
	BP	41,57,28,26,d3,#220,30
	bsr	cm_blit
.a5c:	moveq	#20,d0
	bsr	mt_random
	tst.w	d0
	bne	.done
	cmp.w	#4,cm_indexc
	bge.s	.a5c0
	addq.w	#1,cm_indexc
	bra.s	.a5cc
.a5c0:	clr.w	cm_indexc
.a5cc:	move.w	cm_indexb,d3		; (the original uses indexb here)
	mulu	#28,d3
	BP	41,155,28,26,d3,#250,30
	bsr	cm_blit
	bra	.done
.a6:	cmp.w	#8,cm_indexa
	bge.s	.a60
	addq.w	#1,cm_indexa
	bra.s	.a6a
.a60:	clr.w	cm_indexa
.a6a:	move.w	cm_indexa,d3
	mulu	#20,d3
	BP	40,81,20,38,d3,#170,19
	bsr	cm_blit
	bra	.done
.a7:	cmp.w	#18,cm_indexa
	bge.s	.a70
	addq.w	#1,cm_indexa
	bra.s	.a7a
.a70:	clr.w	cm_indexa
.a7a:	move.w	cm_indexa,d3
	lsl.w	#2,d3
	BP	27,88,3,21,d3,#180,0
	bsr	cm_blitop
	cmp.w	#6,cm_indexb
	bge.s	.a7b0
	addq.w	#1,cm_indexb
	bra.s	.a7b
.a7b0:	clr.w	cm_indexb
.a7b:	move.w	cm_indexb,d4
	mulu	#21,d4
	BP	77,88,34,21,#120,d4,66
	bsr	cm_blit
	bra	.done
.a8:	cmp.w	#255,cm_indexa
	beq.s	.a8r
	cmp.w	#8,cm_indexa
	bge.s	.a8e
	addq.w	#1,cm_indexa
	move.w	cm_indexa,d3
	mulu	#20,d3
	BP	57,77,20,53,d3,#250,46
	bsr	cm_blit
	bra	.done
.a8e:	move.w	#255,cm_indexa
	bra	.done
.a8r:	moveq	#30,d0
	bsr	mt_random
	tst.w	d0
	bne	.done
	clr.w	cm_indexa
	bra	.done
.a9:	moveq	#15,d0
	bsr	mt_random
	tst.w	d0
	bne	.a9b
	cmp.w	#7,cm_indexa
	bge.s	.a9a0
	addq.w	#1,cm_indexa
	move.w	cm_indexa,d3		; a*25-24, 162
	mulu	#25,d3
	sub.w	#24,d3
	BP	85,53,22,33,d3,#162,74
	bra.s	.a9ab
.a9a0:	clr.w	cm_indexa
	BP	85,53,22,33,#74,#33,74
.a9ab:	bsr	cm_blit
	bra	.done
.a9b:	moveq	#15,d0
	bsr	mt_random
	tst.w	d0
	bne	.done
	cmp.w	#5,cm_indexb
	bge.s	.a9b0
	addq.w	#1,cm_indexb
	move.w	cm_indexb,d3		; b*26-26, 200
	mulu	#26,d3
	sub.w	#26,d3
	BP	62,156,23,13,d3,#200,51
	bra.s	.a9bb
.a9b0:	clr.w	cm_indexb
	BP	62,156,23,13,#51,#136,51
.a9bb:	bsr	cm_blit
	bra	.done
.a10:	moveq	#30,d0
	bsr	mt_random
	tst.w	d0
	bne.s	.a10b
	moveq	#9,d0
	bsr	mt_random
	move.w	d0,cm_indexa
.a10b:	tst.w	cm_indexb
	beq.s	.a10c
	subq.w	#1,cm_indexb
	bra.s	.a10d
.a10c:	move.w	#20,cm_indexb
	cmp.w	#8,cm_indexa
	bge.s	.a100
	addq.w	#1,cm_indexa
	bra.s	.a10d
.a100:	clr.w	cm_indexa
.a10d:	move.w	cm_indexa,d3		; rows a*10+101.., columns 0-49 -> screen[51.., 111..]
	mulu	#10,d3
	add.w	#101,d3
	BP	51,111,9,50,d3,#0,0
	bsr	cm_blitop
.done:	bsr	mouseshow
	movem.l	(sp)+,d3-d4
	rts

; ---------------------------------------------------------------- events
; event.dta record n into cm_t (10 x want.w give.w msg string[255])
cm_readevents:
	movem.l	d3,-(sp)
	move.w	d0,d3
	clr.w	-(sp)
	pea	cm_fn_event
	FDOS	GD_FOPEN,8
	move.w	d0,d1
	bmi	fatal
	move.w	d1,-(sp)
	clr.w	-(sp)
	move.w	d1,-(sp)
	move.w	d3,d0
	mulu	#2600,d0
	move.l	d0,-(sp)
	FDOS	GD_FSEEK,10
	pea	cm_t
	move.l	#2600,-(sp)
	move.w	4+4(sp),-(sp)
	FDOS	GD_FREAD,12
	cmp.l	#2600,d0
	bne	fatal
	FDOS	GD_FCLOSE,4
	movem.l	(sp)+,d3
	rts

; the statement i (d0) of record n (d1) applies?  (not chevent(n*10+50+i), and its want is met)
; out: Z clear = yes; a0 = t^[i]
cm_applies:
	movem.l	d3/a3,-(sp)
	move.w	d0,d3
	mulu	#260,d0
	lea	cm_t,a3
	add.w	d0,a3
	move.w	d1,d0
	mulu	#10,d0
	add.w	#50,d0
	add.w	d3,d0
	bsr	chevent
	bne.s	.no
	move.w	(a3),d0			; want
	cmp.w	#20000,d0
	ble.s	.w2
	sub.w	#20000,d0
	bsr	chevent
	bra.s	.x
.w2:	tst.w	d0
	ble.s	.w3
	bsr	incargo
	tst.w	d0
	bgt.s	.yes
	bra.s	.no
.w3:	bne.s	.no
	tst.w	2(a3)
	bgt.s	.yes
.no:	moveq	#0,d0
	bra.s	.x
.yes:	moveq	#1,d0
.x:	move.l	a3,a0
	movem.l	(sp)+,d3/a3
	tst.w	d0
	rts

; checkotherevents2: the first statement whose want is met, printed (eventflag)
cm_checkotherevents2:
	movem.l	d3-d7/a3,-(sp)
	tst.w	cm_contactindex
	bmi	.x
	move.w	GS_ALIEN+ALIEN_CONINDEX(a6),d7
	subq.w	#1,d7			; n
	cmp.w	#10,d7
	bgt	.x
	move.w	d7,d0
	bsr	cm_readevents
	moveq	#0,d3			; i: 0 up (n < 10) or 9 down (n = 10)
	moveq	#1,d4
	cmp.w	#10,d7
	blt.s	.l
	moveq	#9,d3
	moveq	#-1,d4
.l:	move.w	d3,d0
	move.w	d7,d1
	bsr	cm_applies
	beq.s	.n
	bsr	.print
	bra.s	.x
.n:	add.w	d4,d3
	cmp.w	#9,d3
	bhi.s	.x
	bra.s	.l
.x:	movem.l	(sp)+,d3-d7/a3
	rts
.print:					; printstatement: t^[i].msg wrapped at a space before 56
	move.l	a0,a3
	bsr	mousehide
	BAR	5,127,304,179,0
	lea	4(a3),a0		; str2^ := msg
	lea	cm_str2,a1
	moveq	#0,d0
	move.b	(a0),d0
.c0:	move.b	(a0)+,(a1)+
	dbf	d0,.c0
	moveq	#0,d6			; y
.ln:	lea	cm_str2,a0
	lea	cm_str1,a1
	moveq	#0,d0
	move.b	(a0),d0
.c1:	move.b	(a0)+,(a1)+
	dbf	d0,.c1
	sf	d5
	lea	cm_str1,a3
	moveq	#0,d1
	move.b	(a3),d1
	cmp.w	#56,d1
	bls.s	.last
	moveq	#56,d2
.sp:	cmp.b	#' ',0(a3,d2.w)
	beq.s	.spf
	subq.w	#1,d2
	bra.s	.sp
.spf:	move.w	d1,d0			; str2^ := copy(str1^, j+1, length-j); str1^[0] := chr(j-1)
	sub.w	d2,d0
	lea	cm_str2,a1
	move.b	d0,(a1)+
	lea	1(a3,d2.w),a0
	bra.s	.ce
.cc:	move.b	(a0)+,(a1)+
.ce:	dbf	d0,.cc
	subq.w	#1,d2
	move.b	d2,(a3)
	bra.s	.pr
.last:	st	d5
.pr:	move.w	d6,d1
	mulu	#6,d1
	add.w	#135,d1
	moveq	#12,d0
	lea	cm_str1,a0
	bsr	printxy
	addq.w	#1,d6
	tst.b	d5
	beq.s	.ln
	bsr	mouseshow
	st	cm_eventflag
	rts

; checkotherevents(n d0): the first statement whose want is met happens (its gift, its event,
; the wanted cargo taken)
cm_checkotherevents:
	movem.l	d3-d7/a3,-(sp)
	move.w	d0,d7
	bsr	cm_readevents
	moveq	#0,d3
	moveq	#1,d4
	cmp.w	#10,d7
	blt.s	.l
	moveq	#9,d3
	moveq	#-1,d4
.l:	move.w	d3,d0
	move.w	d7,d1
	bsr	cm_applies
	beq.s	.n
	move.l	a0,a3
	move.w	2(a3),d0		; give
	tst.w	(a3)
	bgt.s	.wg			; (want > 0: give only below 30000)
	cmp.w	#20000,d0		; want = 0
	ble.s	.g
	cmp.w	#30000,d0
	bge.s	.ev
	sub.w	#20000,d0
	bsr	event
	bra.s	.ev
.wg:	cmp.w	#20000,(a3)
	ble.s	.wc
	cmp.w	#20000,d0		; want > 20000: give > 20000 is an event, else cargo
	ble.s	.g
	sub.w	#20000,d0
	bsr	event
	bra.s	.ev
.wc:	cmp.w	#20000,d0		; want = cargo
	ble.s	.g
	cmp.w	#30000,d0
	bge.s	.ev
	sub.w	#20000,d0
	bsr	event
	bra.s	.ev
.g:	tst.w	d0
	ble.s	.ev
	cmp.w	#30000,d0
	bge.s	.ev
	st	d1
	bsr	addcargo
.ev:	move.w	d7,d0			; event(n*10+50+i)
	mulu	#10,d0
	add.w	#50,d0
	add.w	d3,d0
	bsr	event
	move.w	(a3),d0			; want = cargo: removecargo(want)
	ble.s	.x
	cmp.w	#20000,d0
	bgt.s	.x
	bsr	removecargo
	bra.s	.x
.n:	add.w	d4,d3
	cmp.w	#9,d3
	bhi.s	.x
	bra	.l
.x:	movem.l	(sp)+,d3-d7/a3
	rts

; ---------------------------------------------------------------- readydata3 / removedata
cm_readydata3:
	movem.l	d3-d4,-(sp)
	move.b	d0,d4			; hail
	bsr	mousehide
	moveq	#0,d0			; compressfile(current)
	bsr	ms_snap
	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	bsr	orc_dump		; loadscreen(com)
	lea	cm_s_com,a0
	move.l	ms_buf,a1
	bsr	cm_loadchk
	lea	cm_s_nr,a0		; (bands: COMNR until the race is known)
	lea	cm_bands,a1
.bn:	move.b	(a0)+,(a1)+
	bne.s	.bn
	bsr	cm_setbands
	moveq	#0,d3			; the cursor from rows 130-145, x 20-35; those cleared
.cu:	moveq	#20,d0
	move.w	d3,d1
	add.w	#130,d1
	bsr	ms_addr
	lea	cm_tmpm,a1
	move.w	d3,d0
	lsl.w	#4,d0
	add.w	d0,a1
	moveq	#16-1,d0
.cp:	move.b	(a0),(a1)+
	clr.b	(a0)+
	dbf	d0,.cp
	addq.w	#1,d3
	cmp.w	#16,d3
	bne.s	.cu
	lea	cm_tmpm,a0
	bsr	kbd_cursor_set
	sf	GS_DONE(a6)
	clr.w	GS_BKCOLOR(a6)
	move.w	#28,GS_TCOLOR(a6)
	sf	cm_infomode
	bsr	cm_clrquestion
	move.l	GS_T1(a6),GS_OLDT1(a6)
	move.l	GS_T1+4(a6),GS_OLDT1+4(a6)
	move.w	#1,cm_cursorx
	clr.w	cm_indexa
	clr.w	cm_indexb
	move.w	#-1,cm_oldci
	sf	cm_shipflag
	sf	cm_eventflag
	clr.l	cm_aliens
	bsr	cm_alloc
	tst.b	d4
	beq.s	.loc
	bsr	cm_getship
	bra.s	.ms
.loc:	bsr	cm_getlocals
.ms:	bsr	mouseshow
	tst.w	cm_contactindex
	bpl	.contact
	bsr	mousehide		; the static: rows 10-110, 255 -> random(32)+64 (even) / +96 (odd)
	moveq	#10,d3
.sr:	moveq	#0,d0
	move.w	d3,d1
	bsr	ms_addr
	move.l	a0,a1
	move.w	#320-1,d4
.sc:	cmp.b	#255,(a1)+
	bne.s	.sn
	moveq	#32,d0
	bsr	mt_random
	add.w	#64,d0
	btst	#0,d3
	beq.s	.se
	add.w	#32,d0
.se:	move.b	d0,-1(a1)
.sn:	dbf	d4,.sc
	addq.w	#1,d3
	cmp.w	#110,d3
	ble.s	.sr
	bsr	ms_dirty_all
	move.w	#28,GS_TCOLOR(a6)
	clr.w	GS_BKCOLOR(a6)
	PXY	12,170,"No response..."
	bsr	mouseshow
.st:	bsr	cm_findmouse3
	lea	GS_COLORS+64*3(a6),a3	; colors[64..95] := colors[random(32)]
	moveq	#32-1,d3
	bsr	.rnd
	lea	GS_COLORS+96*3(a6),a0	; colors[96..127] := 0
	moveq	#96/4-1,d0
.z1:	clr.l	(a0)+
	dbf	d0,.z1
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	st	GS_PALETTEDIRTY(a6)
	moveq	#8,d0
	bsr	fadestep
	moveq	#5,d0			; delay(FADE_TSLICE_ALIENS)
	bsr	delay
	lea	GS_COLORS+96*3(a6),a3	; colors[96..128] := colors[random(32)]
	moveq	#33-1,d3
	bsr	.rnd
	lea	GS_COLORS+64*3(a6),a0	; colors[64..95] := 0
	moveq	#96/4-1,d0
.z2:	clr.l	(a0)+
	dbf	d0,.z2
	lea	GS_COLORS(a6),a0
	bsr	vid_set256
	st	GS_PALETTEDIRTY(a6)
	moveq	#0,d0
	bsr	fadestep
	bsr	kbd_keypressed
	bne.s	.sk
	tst.b	GS_DONE(a6)
	beq	.st
.sk:	bsr	kbd_keypressed
	beq.s	.sk2
	bsr	kbd_readkey
	bra.s	.sk
.sk2:	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	st	GS_DONE(a6)
	bra	.x
.rnd:	moveq	#32,d0
	bsr	mt_random
	mulu	#3,d0
	lea	GS_COLORS(a6),a0
	add.w	d0,a0
	move.b	(a0)+,(a3)+
	move.b	(a0)+,(a3)+
	move.b	(a0)+,(a3)+
	dbf	d3,.rnd
	rts
.contact:
	move.w	cm_contactindex,cm_oldci
	bsr	mousehide
	PXY	12,182,"Subject:"
	bsr	mouseshow
	bsr	cm_getcontactindex
	bsr	cm_loadconversation
	bsr	cm_checkotherevents2
	tst.b	cm_eventflag
	bne.s	.x
	lea	cm_question,a0		; question := 'HI'
	move.b	#2,(a0)+
	move.b	#'H',(a0)+
	move.b	#'I',(a0)+
	tst.w	cm_contactindex
	bmi.s	.x
	bsr	cm_checkstring3
.x:	movem.l	(sp)+,d3-d4
	rts

cm_removedata:
	movem.l	d3,-(sp)
	move.w	GS_ALIEN+ALIEN_CONINDEX(a6),d3
	subq.w	#1,d3			; n
	move.l	cm_mark,d0		; dispose(aliens, str2, str1, c, r, p)
	bsr	mem_release
	moveq	#-8,d0
	moveq	#20,d1
	bsr	fadestopmod
	bsr	orc_dump		; loadscreen(cloud, backgr)
	lea	u2_cloud,a0
	move.l	GS_BACKGR(a6),a1
	bsr	loadchk
	tst.b	GS_SHOWPLANET(a6)	; an asteroid field / a cloud in backgr again
	beq.s	.np
	bsr	gp_extras
.np:	bsr	mousehide
	moveq	#3,d0			; mouse.setmousecursor(random(3))
	bsr	mt_random
	bsr	setmousecursor
	bsr	orc_dump		; loadscreen(current)
	moveq	#0,d0
	bsr	ms_unsnap
	move.w	#3,GS_BKCOLOR(a6)
	moveq	#0,d0
	bsr	displaytextbox
	move.w	#25,GS_TEXTINDEX(a6)
	bsr	mouseshow
	st	GS_ANYCHANGE(a6)
	move.l	GS_OLDT1(a6),GS_T1(a6)
	move.l	GS_OLDT1+4(a6),GS_T1+4(a6)
	tst.w	cm_oldci
	bmi.s	.x
	tst.w	d3
	bmi.s	.x
	cmp.w	#10,d3
	bgt.s	.x
	move.w	d3,d0
	cmp.w	#9,d0
	blt.s	.ev
	bne.s	.e10
	bra.s	.co
.e10:	moveq	#9,d0
.ev:	bsr	event
.co:	move.w	d3,d0
	bsr	cm_checkotherevents
.x:	movem.l	(sp)+,d3
	rts

	section	data
cc_mode:	dc.b	"CCOM",0
cc_fn_mod:	dc.b	"SOUND",92,"CREWCOMM.MOD",0
cm_fn_conv:	dc.b	"DATA",92,"CONV0000.IND",0
cm_fn_planname:	dc.b	"DATA",92,"PLANNAME.TXT",0
cm_fn_contacts2: dc.b	"TEMP",92,"CONTACTS.DTA",0
cm_fn_event:	dc.b	"DATA",92,"EVENT.DTA",0
cm_fn_probe:	dc.b	"SOUND",92,"PROBE.MOD",0
cm_fn_song:	dc.b	"SOUND",92,"SENGZHAC.MOD",0,0,0,0,0
cm_s_com:	dc.b	"COM",0
cm_s_nr:	dc.b	"COMNR",0
	even

	section	bss
cm_mark:	ds.l	1
cm_c:		ds.l	1
cm_rr:		ds.l	1
cm_aliens:	ds.l	1
cm_contactindex: ds.w	1
cm_oldci:	ds.w	1
cm_techlvl:	ds.w	1
cm_eattype:	ds.w	1
cm_cursorx:	ds.w	1
cm_indexa:	ds.w	1
cm_indexb:	ds.w	1
cm_indexc:	ds.w	1
cm_j:		ds.w	1
cm_pm:		ds.w	1
cm_pn:		ds.w	1
cm_po:		ds.w	1
cm_bp:		ds.w	8
cm_brighter:	ds.b	1
cm_infomode:	ds.b	1
cm_shipflag:	ds.b	1
cm_eventflag:	ds.b	1
cm_question:	ds.b	22
cm_ch:		ds.b	2
cm_key:		ds.b	24
cm_name:	ds.b	12
cm_bands:	ds.b	12
cm_s:		ds.b	16
	even
cm_rec2:	ds.b	ALIEN_SIZEOF
cm_rec3:	ds.b	ALIEN_SIZEOF
cm_str1:	ds.b	256
cm_str2:	ds.b	256
cm_p:		ds.b	768
cm_tmpm:	ds.b	256
cm_t:		ds.b	2600
	even
	section	text
