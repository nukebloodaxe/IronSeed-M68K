IRON SEED for the Atari STE
===========================

A port of Iron Seed (Channel 7, 1994; the open-source Free Pascal version at
github.com/nukebloodaxe/ironseed_fpc) to the Atari STE, in 68000 assembler.

Needs: an STE (or Mega STE) with 4 MB of RAM and TOS 1.62 or later, a hard
disk (or Hatari with this folder as drive C:). Tested in Hatari (STE, 4 MB,
TOS 1.62 US, 60 Hz); not yet on real hardware.

Start:  copy the IRONSEED folder to the hard disk and run IS.PRG from it.
        (Hatari: hatari --machine ste --memsize 4096 --tos YOUR_TOS.IMG
         --harddrive IRONSEED --gemdos-drive c, then run C:\IS.PRG.)

The title menu: New game (crew generation), Continue (load a game), the
intro, quit. The game is the original's, screen by screen; the keys and the
mouse work as on the PC (F1-F10, Alt-keys, keypad). On an ST keyboard:
Ctrl-ClrHome stands for the PC's Ctrl-End.

Saved games go to SAVE1 ... SAVE8 and SAVEGAME.DIR in this folder.

Options panel (Medical): the first row, "Probes", picks how the planet
probes behave (saved with the game):
  Std   as the Free Pascal version: the probes stay out while any scan
        is incomplete; Retrieve takes an anomaly into the hold at once.
  1994  as the original release: each probe gathers the scan it was
        launched for and comes home when that scan is complete; Retrieve
        sends a free probe to the anomaly and it brings the item back.
(That row was the screen saver, which the Free Pascal version never had
working.) Volume sets the music level; on the STE it goes through the
volume chip, so the sound effects follow it too.

Music: the MUSIC folder holds the songs pre-rendered; they are streamed from
the disk, which leaves the 68000 free for the game (combat runs about 1.8
times faster, the title screen twice as smoothly). Two packs, pick one and
put its MUSIC folder here (the programs follow the rate in the files):
  6258 Hz   about 56 MB   the ST mixer's own sound, rendered exactly
  12517 Hz  about 112 MB  interpolated, brighter (twice the disk reads)
Without the folder - a small disk, or floppies - the programs mix the MOD
files from SOUND in real time as before: same music, slower game.

Arriving at a planet or a star: the "Approaching ..." countdown is the
surface being generated (the original's random walks, exactly). On an 8 MHz
STE that takes about 6 s for a planet and 15 s for a star; a planet seen
again takes about 1 s, and the last four stars visited are remembered.
Ordering a jump to the planet or star the ship already orbits (Alt-0..4,
Alt-N/P, the system view's orbit button) does nothing but get a reply from
Science - the PC version flew there again.

Mega STE: switch it to 16 MHz with the cache on (its control panel) before
starting. Every screen then runs faster - in Hatari with a 16 MHz CPU the
bridge's planet turns at the PC game's own pace, the planet exploration
runs more than twice as fast and a star takes about 7 s. (Not yet tried on
a real Mega STE.)

Colours: the STE shows 16 colours per band of lines, where the PC had 256.
When a dialog opens over a screen (save, load, yes/no, crew messages, the
crew chips), it appears at once and its colours settle a moment later: the
bands under it get a palette chosen for what is on the screen. The planet
exploration map has a palette per planet type, and the bridge's viewscreen
one per kind of orbit (each planet type, gas giants, gas clouds, asteroid
fields, each kind of star), fitted on the original game's own pictures.

The FINALE slot (if present) is a test position: the ship at the Scavengers'
gate with the Kendar alliance and the faction quests done, a Temporal Anchor
and full thrust. The whole armada attacks at once - it cannot be shot down:
turn on the shields (X), fly away with keypad 7 and keypad - and keep going
until the last cruiser is out of range. Then the ending plays.

Port notes, tools and tests: the ironseed-ste source tree (HANDOFF.md).
