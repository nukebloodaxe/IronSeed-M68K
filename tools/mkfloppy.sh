#!/bin/bash
# mkfloppy.sh [OUTDIR] : the floppy version (Phase 8): a game folder without the music packs
# (build/floppy_game, tools/mkgame.sh with NOMUSIC=1), then the 720 KB disk images
# (tools/mkfloppy.py): OUTDIR/IRONSEED1.ST .. IRONSEED8.ST (game) + IRONSEED9.ST (save disk).
# Boot disk 1 (AUTO\IS.PRG); the game asks for the others by number.
# SAVES=DIR: put DIR's SAVEGAME.DIR and SAVEn\ folders on the save disk (the release: the HD game
# folder's, with the FINALE slot).
set -e
R=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-$R/dist/floppy}
G=$R/build/floppy_game
rm -rf "$G"
NOMUSIC=1 "$R/tools/mkgame.sh" "$G" > /dev/null
[ -n "$SAVES" ] && cp -r "$SAVES"/SAVEGAME.DIR "$SAVES"/SAVE[0-9] "$G"/ 2>/dev/null || true
mkdir -p "$OUT"; rm -f "$OUT"/IRONSEED*.ST
python3 -I "$R/tools/mkfloppy.py" "$G" "$OUT"
