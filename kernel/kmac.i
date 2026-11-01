; kmac.i - kernel macros (include at the top of every program, after hw.i).

; TOS calls: push arguments first (last C argument first), then
;   GEMDOS fn,bytes   - bytes = total stack to pop INCLUDING the function word
GEMDOS	macro
	move.w	#\1,-(sp)
	trap	#1
	lea	\2(sp),sp
	endm
; (Phase 8) file calls: Fopen, Fcreate, Fclose, Fread, Fwrite, Fseek, Dcreate, Fdelete go
; through the kernel's flp_dos (flp.s: the floppy version; trap #1 otherwise)
FDOS	macro
	move.w	#\1,-(sp)
	jsr	flp_dos
	lea	\2(sp),sp
	endm
BIOS	macro
	move.w	#\1,-(sp)
	trap	#13
	lea	\2(sp),sp
	endm
XBIOS	macro
	move.w	#\1,-(sp)
	trap	#14
	lea	\2(sp),sp
	endm

; critical section (keep short - it delays the raster splits)
DI	macro
	move.w	sr,-(sp)
	move.w	#$2700,sr
	endm
EI	macro
	move.w	(sp)+,sr
	endm

; STE colour from 4-bit r,g,b (0-15): LSB of each nibble goes to bit 3
STECOL	macro
	dc.w	((((\1)&1)<<3)|((\1)>>1))<<8|((((\2)&1)<<3)|((\2)>>1))<<4|((((\3)&1)<<3)|((\3)>>1))
	endm

; fp.s precision: FSSE = double expressions (SSE, 53 bits), FX87 = x87 expressions (64 bits)
FSSE	macro
	clr.w	fp_mode
	endm
FX87	macro
	move.w	#1,fp_mode
	endm
