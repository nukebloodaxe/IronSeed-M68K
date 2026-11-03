# HWCHECK.PRG - the real-hardware check (Phase 8)

Source `kit/hwcheck.s`; built by `tools/mkgame.sh` into the game folder and by `tools/mkfloppy.sh` onto
the save disk (`tools/asm.sh kit/hwcheck.s OUT/HWCHECK.PRG` alone). It is the game's kernel (kernel.s:
the same VBL, Timer B splits, cursor, DMA sound, mixer, stream, files) plus `TBLOG`, which makes the
Timer B handler (kernel vid.s) time every split. Release programs do not define TBLOG and are
byte-identical with it in the tree.

## What it measures
- **Split timing** (vid.s, `vid_tbst`, two sets chosen by `vid_tbsel`: 0 normally, `TBS_SIZE` while
  a disk read runs). After the 16-colour `movem` the handler reads the video counter again: still at
  the split line's start = the write happened in the blank before the line (**on time**); past it =
  the line's first pixels showed the old band's colours, `late` by that many bytes (2 px each,
  `TBS_MAX` the worst, `TBS_BIG` >= 8 bytes). `TBS_ENT` counts splits whose interrupt arrived after
  the line had begun (the IPL was held too long: a hard disk driver, TOS's floppy code). Same
  definition as Phase 0's `tools/ana_jit.py`.
- **CPU**: `cpu_count` = a dbf loop's passes in 0.5 s with the kernel's interrupts on; `CPU_CAL` =
  2946 in Hatari at 8 MHz (16 MHz: 6102 there - Hatari has no wait states at 16 MHz, a real Mega STE's
  cache decides). Mega STE: `$FF8E21` is printed raw (the docs disagree on its bits).
- **Load**: `hw_load` copies 8 KB with 11-register movem.l and does divu/divs (the longest
  instructions, which delay interrupts most) - a game-like worst case. The passes in a test's time give
  "game loop N % of test 1".
- **Mixer** (test 2): SOUND\GAME.MOD through mod_init at the kernel's rate (6258 Hz), `snd_cpu` ticks.
- **Disk** (test 3): MUSIC\GAME.RAW (else any RAW, else the largest DATA file) in 16 KB (the stream's
  ST_CHUNK) and 64 KB Freads, 2 MB or 20 s each; KB/s, the slowest read (5 ms resolution).
- **Stream** (test 4): mod_load of SOUND\NAME.MOD finds MUSIC\NAME.RAW; 40 s with the load and
  `hw_poll` (snd_poll, timed, split set 1 only while a read will happen). The ring (1 MB, 83.7 s at
  6258 Hz) first fills as fast as the disk allows ("filled in"), then `st_minf` is reset: "never
  below" = how far the steady state drops (a slow disk shows here before an underrun does).
- **Keyboard** (test 5): `kbd_readkey` (what the game gets) + the raw IOREC long (scan, char) +
  Kbshift. The checklist: F1, F10, Ctrl+F10 (103), Ctrl+ClrHome (117), Alt+Q, Alt+7 (egg 2), Up,
  ClrHome, keypad 7 / - (raw scan $67 / $4A).
- **Floppy** (test 6): A:\ISDISK.TAB's disk number; the largest file of A:\DATA, A:\SOUND, A:\ in
  16 KB reads with the four bands, then with one band (no Timer B) - do the splits cost the drive
  anything; then a different game disk: read again with TOS's own media-change detection; if the
  number did not change, again with the game's signal (`hw_mediach` = flp.s's flp_force: "changed"
  once).

## Reading a report
- `N splits, all on time` / `OK`: nothing to do.
- `L late (0 by 16+ px, latest 4 px)`, `OK (a few pixels at most)`: a few lines start 2-14 pixels in
  the previous band's colours - invisible in the game (the bands' edges are mostly in dark areas).
- `LATE: band edges may flicker`: something holds the interrupt level - look at which set (between /
  during reads). During hard disk reads: the driver masks interrupts; the stream's reads could then be
  moved to where the screen does not care (the VBL's top border) or split into smaller Freads.
- Stream `never below X s` far below the ring's size, or underruns: the disk is too slow for the pack
  (try the 6258 Hz pack, or no pack).
- Floppy `TOS missed it; the game's signal works`: expected on some drives (no disk-change line);
  the game forces the change after each prompt anyway.

## Hatari reference (STE 4 MB, TOS 1.62 US, 60 Hz, GEMDOS drive, 2.4.1)
```
CPU ~8.0 MHz (loop 2946)            (16 MHz: ~16.5, loop 6102)
[1] 3603 splits, all on time
[2] 3604 splits, all on time; mixer ~25 % of the CPU, game loop 74 % of test 1
[3] reads too fast to time (GEMDOS drive emulation)
[4] ring filled in 0.3 s, then never below 82.4 s, underruns 0; 94 reads; all on time
[5] all keys arrived as the game reads them
[6] disk 3, A:\MAIN.PRG: ~10 KB/s with and without the splits, 10 late by <= 4 px during floppy
    reads; disk change: TOS noticed it
```
Test drivers used: `tools/hdesk.py DIR OUT SCRIPT --auto 'C:\HWCHECK.PRG' --fast-forward on`
(`key 4` sends the character 4: single characters are characters to Hatari, numbers are scan codes;
floppy: `--drive-a true --disk-a A.ST`, `raw hatari-option --disk-a B.ST` to swap).
