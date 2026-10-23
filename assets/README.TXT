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

The FINALE slot (if present) is a test position: the ship at the Scavengers'
gate with the Kendar alliance and the faction quests done, a Temporal Anchor
and full thrust. The whole armada attacks at once - it cannot be shot down:
turn on the shields (X), fly away with keypad 7 and keypad - and keep going
until the last cruiser is out of range. Then the ending plays.

Port notes, tools and tests: the ironseed-ste source tree.
