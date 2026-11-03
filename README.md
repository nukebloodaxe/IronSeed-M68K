ironseed-ste
============
Iron Seed is a science-fiction DOS game from 1994, which was both developed and published by Channel 7.
Gameplay is real-time, featuring trading, diplomacy, and strategy.

This repository is a port of the game to the **Atari STE**, written in pure 68000 assembler from the
Free Pascal source in [ironseed_fpc](https://github.com/nukebloodaxe/ironseed_fpc), screen by screen. The
whole game is ported: the intro, crew generation, the bridge, planets and stars, exploration and probes,
comms and trade with every race, the sector map, combat, the crew screens, inventory and creation, the
easter eggs and the ending. Game logic is checked against the Linux build of ironseed_fpc, which serves as
a reference oracle: the same input scripts run on both, and state dumps and screenshots are compared
(53 game sessions, from crew generation to winning the game).  This is indeed an AI-aided project, using Claude.

By Nuke Bloodaxe M68K Ports.

Running it
==========
You need an **STE or Mega STE with 4 MB of RAM and TOS 1.62 or later**, and either a hard disk (or SD-card
adapter / emulated GEMDOS drive) or nine 720 KB floppy disks. It runs in Hatari and Steem SSE.

- **Hard disk:** copy the `IRONSEED` folder to a partition, add one music pack's `MUSIC` folder to it
  (optional, recommended), double-click `IS.PRG`.
- **Floppies:** write `IRONSEED1.ST` - `IRONSEED9.ST` to 720 KB disks (9 is the save disk; leave it
  writable) and boot disk 1. The game asks for the other disks by number.
- **Music packs:** every song pre-rendered for streaming from disk, which leaves the 68000 free for the
  game. `6258 Hz` (about 56 MB) is the STE mixer's own sound, rendered exactly; `12517 Hz` (about 112 MB)
  is interpolated and brighter. Without a pack, the music is mixed in real time from the MOD files
  (the floppy version always does this).
- **Mega STE:** set 16 MHz with the cache on before starting; every screen runs faster.

`README.TXT` in the game folder is the player's guide (installation, floppies, options, the hardware check).

What is different on the STE
============================
- **Colours:** 64 on screen out of the STE's 4096, as four raster bands of 16 colours (Timer B
  splits). Each screen has its own band design, fitted offline on the original's 256-colour pictures;
  the bridge has a design per kind of orbit, dialogs get theirs fitted at run time, and a checkerboard
  dither is used where it helps (the bridge's viewscreen, the crew portraits, the psychometry cylinder).
- **Speed:** the PC game assumed a 386. Everything that affects game state is computed exactly as the
  original does (FPC's Mersenne Twister, a bit-exact software FPU for Pascal reals and x87 sin/cos), with
  the heavy loops rewritten for the 68000. Most screens now run at the original's own frame pace on an
  8 MHz STE.
- **Options panel additions (saved with the game):**
  - *Probes Std / 1994*: the Free Pascal version's planet probes, or the original 1994 behaviour (one
    scan category per probe trip; anomalies fetched by a probe).
  - *Stars Std / Fast*: a star's surface from the original random walks (about 15 s at 8 MHz), or from
    a quicker generator (about 4 s; same kind of star, different pattern).
- Ordering a jump to the planet or star the ship already orbits gets a reply from Science instead of
  flying there again.
- **Keys:** the PC keys work as before; Ctrl-ClrHome stands for Ctrl-End.
- **Music panning** follows the 1994 DOS game's player (DMP), so songs are centred as the composers
  intended.

Real hardware
=============
Everything so far is verified in emulators. `HWCHECK.PRG` (in the game folder and on the floppy save disk)
runs the game's own kernel through the checks an emulator cannot settle: raster split timing under load,
with the mixer and during disk reads, the hard disk's read speed and whether the music stream keeps up,
the keyboard mappings, and the floppy drive's speed and disk-change detection. It writes `HWCHECK.TXT`;
reports from real STEs and Mega STEs are very welcome. See [docs/HWCHECK.md](docs/HWCHECK.md).

Building
========
Prerequisites (Debian/Ubuntu names):
- `vasmm68k_mot` - [vasm](http://sun.hasenbraten.de/vasm/) built with `make CPU=m68k SYNTAX=mot`
- Python 3 with `numpy` and `pillow`
- `fpc` (the build generates a few constants by compiling small Pascal programs)
- a checkout of [ironseed_fpc](https://github.com/nukebloodaxe/ironseed_fpc) for the original data
  files (`IRONSEED_SRC`, default `/root/ironseed_fpc`)
- for testing: `hatari`, a TOS 1.62 ROM image (not included: `rom/tos162us.img` or `ISTE_ROM`), and
  `libsdl1.2-dev libsdl-mixer1.2-dev` to build the Linux oracle

```sh
tools/mkgame.sh OUT/IRONSEED                       # the hard disk folder with the 6258 Hz MUSIC pack
NOMUSIC=1 tools/mkgame.sh OUT/IRONSEED             # without the pack
MUSICRATE=12517 MUSICINTERP=1 tools/mkgame.sh DIR  # the 12517 Hz pack
tools/mkfloppy.sh OUT/floppy                       # the nine floppy images
tools/asm.sh kit/hwcheck.s OUT/HWCHECK.PRG         # the hardware check alone
```

Testing
=======
- `tests/run_tests.sh` - kernel tests (bands, text, sound mixer bit-exact against `tools/modref.py`, the
  music stream, inflate, the software FPU, sin/cos), the intro, crew generation against the oracle, and
  `tools/reglint.sh` (a register-usage checker over the assembler listings).
- `tests/check_main.sh m1 ... m53` - the game sessions in `oracle/scripts`, run on the Linux oracle and
  in Hatari, compared dump by dump and screen by screen. The oracle is ironseed_fpc with
  `oracle/0001-Oracle-hooks-for-the-Atari-STE-port.patch` applied (scripted input, virtual time, state dumps).
- `tests/st/` - sessions for the port's own features (no oracle), `tests/floppy/` - the floppy version.

Repository layout
=================
```
kernel/   the kernel shared by all programs: video and raster bands, keyboard/mouse, DMA sound, MOD
          replay, the music stream, files and the floppy layer, inflate, FPC's random, software FPU
game/     the programs: IS.PRG (launcher), INTRO.PRG, CREWGEN.PRG, MAIN.PRG (one module per original unit)
kit/      HWCHECK.PRG, the real-hardware check
tools/    data converters, band fitting, music renderer, floppy builder, test and profiling tools
tests/    kernel tests, oracle comparisons, ST-only sessions
oracle/   the patch for the Linux reference build and the input scripts
assets/   inputs not in ironseed_fpc (README.TXT, logos, bridge designs)
spikes/   Phase 0 experiments (raster split, c2p, mixer timing)
docs/     PLAN.md (design, measurements, history), ABI.md (assembler conventions), HWCHECK.md
```
`HANDOFF.md` is the working log: where the port stands and how each piece fits.

Credits and licence
===================
Iron Seed (c) 1994 Channel 7. The Free Pascal version: [ironseed_fpc](https://github.com/nukebloodaxe/ironseed_fpc),
with ongoing fixes by Mnalis and contributors. This port is released under the GNU General Public
License v3, as ironseed_fpc is; the game's data files come from that repository.
