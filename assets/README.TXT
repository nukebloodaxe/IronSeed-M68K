IRON SEED for the Atari STE
===========================

A port of Iron Seed (Channel 7, 1994; the open-source Free Pascal version at
github.com/nukebloodaxe/ironseed_fpc) to the Atari STE, in 68000 assembler,
by Nuke Bloodaxe M68K Ports.

Needs: an STE or Mega STE with 4 MB of RAM and TOS 1.62 or later, and
either a hard disk (or SD card / emulated drive) or nine 720 KB floppies.
Tested in Hatari (STE, 4 MB, TOS 1.62 US, 60 Hz) and Steem SSE; real
hardware reports are welcome (see HWCHECK below).


INSTALLING ON A HARD DISK
-------------------------
1. Copy the IRONSEED folder to a hard disk partition. The folder name can
   be anything; the programs find their files beside them. Keep the folder
   as it is: IS.PRG, INTRO.PRG, CREWGEN.PRG, MAIN.PRG, HWCHECK.PRG, DATA\,
   SOUND\ and (optional) MUSIC\.
2. Music (optional, recommended): copy ONE music pack's MUSIC folder into
   the IRONSEED folder (IRONSEED\MUSIC\*.RAW). Two packs; pick one:
     6258 Hz   about 56 MB   the ST mixer's own sound, rendered exactly
     12517 Hz  about 112 MB  interpolated, brighter (twice the disk reads)
   The programs read the rate from the files. Without a MUSIC folder the
   music is mixed from SOUND\ in real time: the same songs, but the game
   runs slower (combat about half speed, the title screen less smooth).
3. Start IS.PRG (double-click it on the desktop). It must be started from
   its own folder; that is what the desktop does.

Disk space: the game itself is about 15 MB; with the 6258 Hz pack about
71 MB, with the 12517 Hz pack about 127 MB. TOS 1.62 needs your hard disk
driver's "big" partitions for that much (AHDI 5, HDDRIVER, PPDRIVER, ICD
and the SD card adapters' drivers all make them); the folder must be on
one partition. Copying the MUSIC folder is quickest from a PC onto the
card or disk image, if your setup allows it; the Atari desktop copies it
too, only slowly.

Memory: the game uses nearly all of 4 MB. Leave out memory-hungry
accessories and AUTO-folder programs (RAM disks, big disk caches); if a
program says "not enough memory", start without them. HWCHECK.PRG shows
the free memory.

Mega STE: set 16 MHz with the cache on (control panel) before starting:
every screen then runs faster. The game itself also runs at 8 MHz.

Emulators: Hatari - hatari --machine ste --memsize 4096 --tos YOUR_TOS.IMG
--harddrive IRONSEED --gemdos-drive c, then run C:\IS.PRG. Steem SSE -
give it the folder as a GEMDOS hard drive; use a real folder, not a link
to one (Steem's drive emulation can fail on links: programs then open the
desktop's Show/Print dialog instead of running).

Saved games go to SAVE1 ... SAVE8 and SAVEGAME.DIR in the game folder;
they are the same files as on the floppy save disk, so you can move games
between the two.


THE FLOPPY VERSION
------------------
IRONSEED1.ST - IRONSEED8.ST are the game, IRONSEED9.ST the save disk
(write them to 720 KB double-sided disks, or use the images in an
emulator). Boot from disk 1: the game starts by itself (or run IS.PRG on
disk 1 from the desktop). Leave disks 1-8 write-protected; the save disk
must not be. When the game needs another disk it says which: "Please
insert Iron Seed disk N" (or the save disk); put it in drive A and press a
key or click. Esc there cancels (a game would then stop with an error -
only for when no disk can be found). Loading and saving go to the save
disk. On the floppies the music is mixed in real time from the MOD files
(the pre-rendered packs do not fit), and a disk never changes for the
music alone: a song on another disk starts once that disk is in. The
bridge, once seen, stays in memory, so coming back to it from another
screen needs no disk. Disk 1 holds the intro, 2 the crew generation and
combat, 3 the main program and the bridge, 4 the screens used most
(exploration, logs, crew, creation), 5 the ending; the sector map and the
alien races' contacts are spread over the others.

To move from floppies to a hard disk, use the hard disk folder (the game
on the floppies is packed); copy SAVEGAME.DIR and the SAVEn folders from
the save disk into it to keep your games.


PLAYING
-------
The title menu: New game (crew generation), Continue (load a game), the
intro, quit. The game is the original's, screen by screen; the keys and the
mouse work as on the PC (F1-F10, Alt-keys, keypad). On an ST keyboard:
Ctrl-ClrHome stands for the PC's Ctrl-End.

Options panel (Medical): the first row, "Probes", picks how the planet
probes behave (saved with the game):
  Std   as the Free Pascal version: the probes stay out while any scan
        is incomplete; Retrieve takes an anomaly into the hold at once.
  1994  as the original release: each probe gathers the scan it was
        launched for and comes home when that scan is complete; Retrieve
        sends a free probe to the anomaly and it brings the item back.
(That row was the screen saver, which the Free Pascal version never had
working.) Volume sets the music level; on the STE it goes through the
volume chip, so the sound effects follow it too. The last row, "Stars",
picks how a star's surface is made when the ship arrives (saved with the
game; it changes nothing else in the game):
  Std   the original's random walks, exactly the PC's star (about 15 s)
  Fast  a quicker generator: a star of the same kind, but not the PC's
        own pattern (about 4 s)

Arriving at a planet or a star: the "Approaching ..." countdown is the
surface being generated (the original's random walks, exactly). On an 8 MHz
STE that takes about 6 s for a planet and 15 s for a star (4 s with Stars
set to Fast); a planet seen again takes about 1 s, and the last four stars
visited are remembered.
Ordering a jump to the planet or star the ship already orbits (Alt-0..4,
Alt-N/P, the system view's orbit button) does nothing but get a reply from
Science - the PC version flew there again.

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


HWCHECK - THE HARDWARE CHECK
----------------------------
HWCHECK.PRG (in the game folder, and on the floppy save disk) tests what
an emulator cannot tell us, using the game's own screen, sound and disk
code. Run it from where it lies, choose tests from its menu, then Q: it
writes HWCHECK.TXT beside itself (a short text report - please send it).
  1  the raster splits (the four colour bands) with the CPU busy; move
     the mouse meanwhile. Watch the coloured strip on the left: each
     colour must change on one straight line.
  2  the same with the music mixer playing (needs SOUND\GAME.MOD)
  3  the disk's read speed (a MUSIC file, else the largest DATA file)
  4  the music stream for 40 s (needs a MUSIC folder): whether the disk
     keeps the music fed while the game runs, and whether disk reads
     disturb the colour bands
  5  the keyboard: the keys the ST maps for the PC game (Ctrl-ClrHome,
     Ctrl-F10, Alt keys, keypad); it ends when all are ticked, or on Esc
  6  floppy drive A: read speed with and without the colour bands, and a
     disk change (asks for two different Iron Seed game disks)
  A  runs 1 to 4 one after another (about 2 minutes)
Each test ends with OK or a warning. Esc stops a running test.

Port notes, tools and tests: the ironseed-ste source tree (HANDOFF.md).
