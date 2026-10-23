; hw.i - STE hardware addresses and TOS system variables used by the kernel.
; Sources: atari-st-68k-expertise.md §3-§5, §8; atari-later-machines.md §2.2-2.3; [PB-5 J.2]; HW listing v9.0.

; --- system variables (supervisor only)
HZ200		equ	$4ba		; 200 Hz tick counter (long)
VBCLOCK		equ	$462
PALMODE		equ	$448		; 0 = NTSC 60 Hz
SYSBASE		equ	$4f2

; --- exception / interrupt vectors
VEC_BUSERR	equ	$008
VEC_ADDRERR	equ	$00c
VEC_ILLEGAL	equ	$010
VEC_ZERODIV	equ	$014
VEC_VBL		equ	$070
VEC_TIMERC	equ	$114		; MFP channel 5
VEC_ACIA	equ	$118		; MFP channel 6 (keyboard + MIDI)
VEC_TIMERB	equ	$120		; MFP channel 8

; --- video
VID_BASEH	equ	$ffff8201
VID_BASEM	equ	$ffff8203
VID_BASEL	equ	$ffff820d	; STE
VID_COUNT	equ	$ffff8205	; 8205/07/09 (read with movep.l, then lsr.l #8)
VID_SYNC	equ	$ffff820a	; bit 1: 1 = 50 Hz
VID_LINEOFS	equ	$ffff820f	; STE: extra words per line
VID_HSCROLL	equ	$ffff8265	; STE: pixel scroll 0-15
VID_PAL		equ	$ffff8240
VID_REZ		equ	$ffff8260

; --- MFP 68901
MFP_GPIP	equ	$fffffa01
MFP_AER		equ	$fffffa03
MFP_IERA	equ	$fffffa07
MFP_IERB	equ	$fffffa09
MFP_ISRA	equ	$fffffa0f
MFP_ISRB	equ	$fffffa11
MFP_IMRA	equ	$fffffa13
MFP_IMRB	equ	$fffffa15
MFP_VR		equ	$fffffa17
MFP_TBCR	equ	$fffffa1b
MFP_TBDR	equ	$fffffa21

; --- ACIA (IKBD)
ACIA_CTL	equ	$fffffc00
ACIA_DAT	equ	$fffffc02

; --- DMA sound (STE)
SND_CTL		equ	$ffff8901	; bit 0 play, bit 1 repeat
SND_START	equ	$ffff8903	; 8903/05/07
SND_COUNT	equ	$ffff8909	; 8909/0B/0D
SND_END		equ	$ffff890f	; 890F/11/13
SND_MODE	equ	$ffff8921	; bit 7 mono, bits 1-0 rate
SND_MWDATA	equ	$ffff8922
SND_MWMASK	equ	$ffff8924

; --- blitter
BLT_HALFTONE	equ	$ffff8a00
BLT_SRCXINC	equ	$ffff8a20
BLT_SRCYINC	equ	$ffff8a22
BLT_SRCADDR	equ	$ffff8a24
BLT_ENDMASK1	equ	$ffff8a28
BLT_ENDMASK2	equ	$ffff8a2a
BLT_ENDMASK3	equ	$ffff8a2c
BLT_DSTXINC	equ	$ffff8a2e
BLT_DSTYINC	equ	$ffff8a30
BLT_DSTADDR	equ	$ffff8a32
BLT_XCOUNT	equ	$ffff8a36
BLT_YCOUNT	equ	$ffff8a38
BLT_HOP		equ	$ffff8a3a
BLT_OP		equ	$ffff8a3b
BLT_CTRL	equ	$ffff8a3c	; bit 7 busy, 6 hog, 5 smudge, 3-0 line
BLT_SKEW	equ	$ffff8a3d	; bit 7 FXSR, 6 NFSR, 3-0 skew

; --- GEMDOS / BIOS / XBIOS function numbers
GD_CCONWS	equ	$09
GD_SUPER	equ	$20
GD_FCREATE	equ	$3c
GD_FOPEN	equ	$3d
GD_FCLOSE	equ	$3e
GD_FREAD	equ	$3f
GD_FWRITE	equ	$40
GD_FSEEK	equ	$42
GD_DCREATE	equ	$39
GD_FDELETE	equ	$41
GD_MALLOC	equ	$48
GD_MFREE	equ	$49
GD_PTERM0	equ	$00
GD_PTERM	equ	$4c
BI_BCONSTAT	equ	1
BI_BCONIN	equ	2
BI_KBSHIFT	equ	11
XB_PHYSBASE	equ	2
XB_LOGBASE	equ	3
XB_GETREZ	equ	4
XB_SETSCREEN	equ	5
XB_KBDVBASE	equ	34
XB_KBRATE	equ	35

; --- screen geometry
SCR_W		equ	320
SCR_H		equ	200
SCR_BPL		equ	160		; bytes per line, low res
SCR_SIZE	equ	32000
